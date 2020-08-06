#include "icont.h"
#include "link.h"
#include "keyword.h"
#include "ucode.h"
#include "lcode.h"
#include "lmem.h"
#include "lsym.h"
#include "tsym.h"
#include "lglob.h"
#include "ltree.h"
#include "ir.h"

static int n_chunks_alloc;
static int chunk_id_seq;
struct chunk **chunks;
int hi_chunk;
static int hi_clo, hi_tmp, hi_lab, hi_mark;
static int tcaseinit_id_seq, mark_id_seq, tmp_id_seq;

static struct ir_info *scan_stack;
static struct ir_info *loop_stack;

static int augop(int n);
static void print_ir_var(struct ir_var *v);
static void delete_ir(struct chunk *chunk, int i);
static void edit_marks(int old, int new, int no);
static int optimize_goto(void);
static int peephole1(void);
static int peephole_optimizations(void);
static int mark_check(void);
static int fold_tmps(void);
static void optimize_goto1(int i);
static void renumber_ir(void);
static int get_extra_chunk(void);
static struct ir_var *make_tmp(struct ir_stack *st);
static int make_tmploc(struct ir_stack *st);
static struct mark_pair *make_mark(struct ir_stack *st);
static void init_scan(struct ir_info *info, struct ir_stack *st);
static void print_chunk(struct chunk *chunk);
static int asgn_may_fail(struct lnode *n, int);
static void move_chunk(int old, int new);
static void unref(struct chunk *chunk);
static int last_invoke_arg_rval(struct lnode_invoke *x);
static void optimize(void);
static void edit_labels(int old, int new);
static int is_an_exit(struct ir *ir);
static void remove_unseen_chunks(void);
static void sanity_check(void);
static void sum_seen(int *res);

static int traverse_level;

typedef void (*visit_vars_func)(struct chunk *chunk, struct ir *ir, struct ir_var *v, int lhs);
static void visit_vars(visit_vars_func v);

struct membuff ir_func_mb = {"Per func IR membuff", 64000, 0,0,0 };
#define IRAlloc(type)   mb_zalloc(&ir_func_mb, sizeof(type))
#define IRAlloc1(type)   mb_alloc(&ir_func_mb, sizeof(type))

#define chunk1(lab, I1) chunk(__LINE__, #lab, lab, 1, I1)
#define chunk2(lab, I1, I2) chunk(__LINE__, #lab, lab, 2, I1, I2)
#define chunk3(lab, I1, I2, I3) chunk(__LINE__, #lab, lab, 3, I1, I2, I3)
#define chunk4(lab, I1, I2, I3, I4) chunk(__LINE__, #lab, lab, 4, I1, I2, I3, I4)
#define chunk5(lab, I1, I2, I3, I4, I5) chunk(__LINE__, #lab, lab, 5, I1, I2, I3, I4, I5)
#define OptIns(cond, inst) ((cond) ? (inst):0)

static void indentf(char *fmt, ...)
{
    int i;
    va_list argp;
    va_start(argp, fmt);
    for (i = 0; i < traverse_level; ++i)
        putc('\t', stderr);
    vfprintf(stderr, fmt, argp);
    va_end(argp);
}

struct ir_stack *new_stack(void)
{
    return IRAlloc(struct ir_stack);
}

struct ir_stack *branch_stack(struct ir_stack *st)
{
    struct ir_stack *res = IRAlloc1(struct ir_stack);
    *res = *st;
    return res;
}

static void union_stack(struct ir_stack *x, struct ir_stack *y)
{
    if (y->clo > x->clo)
        x->clo = y->clo;

    if (y->tmp > x->tmp)
        x->tmp = y->tmp;

    if (y->lab > x->lab)
        x->lab = y->lab;

    if (y->mark > x->mark)
        x->mark = y->mark;
}

static void init_loop(struct ir_info *info, struct ir_stack *st, struct ir_var *target, int bounded, int rval)
{
    struct loop_info *l = IRAlloc1(struct loop_info);
    info->loop = l;
    l->continue_tmploc = make_tmploc(st);
    l->next_chunk = get_extra_chunk();
    l->loop_st = branch_stack(st);
    l->loop_mk = make_mark(l->loop_st);
    l->st = st;
    l->target = target;
    l->bounded = bounded;
    l->rval = rval;
    l->scan_stack = scan_stack;
    l->next = 0;
    l->has_break = l->has_next = l->next_fails_flag = 0;
}

static void init_scan(struct ir_info *info, struct ir_stack *st)
{
    struct scan_info *l = IRAlloc1(struct scan_info);
    info->scan = l;
    l->old_subject = make_tmp(st);
    l->old_pos = make_tmp(st);
    l->next = 0;
}

static void push_scan(struct ir_info *info)
{
    info->scan->next = scan_stack;
    scan_stack = info;
}

static void pop_scan(void)
{
    scan_stack = scan_stack->scan->next;
}

static void push_loop(struct ir_info *info)
{
    info->loop->next = loop_stack;
    loop_stack = info;
}

static struct ir_info *pop_loop(void)
{
    struct ir_info *t = loop_stack;
    loop_stack = loop_stack->loop->next;
    return t;
}

static struct chunk *chunk(int line, char *desc, int id, int n, ...)
{
    va_list argp;
    struct chunk *chunk;
    int i;
    if (id >= n_chunks_alloc) {
        int t = (id + 1) * 2;
        chunks = safe_realloc(chunks, t * sizeof(struct chunk *));
        for (i = n_chunks_alloc; i < t; ++i)
            chunks[i] = 0;
        n_chunks_alloc = t;
    }
    if (id > hi_chunk)
        hi_chunk = id;
    chunk = mb_alloc(&ir_func_mb, sizeof(struct chunk) + (n - 1) * sizeof(struct ir *));
    chunks[id] = chunk;
    chunk->id = id;
    chunk->line = line;
    chunk->desc = desc;
    chunk->joined_above = chunk->joined_below = chunk->seen =
        chunk->n_inst = chunk->circle = chunk->pc = chunk->refs = 0;
    va_start(argp, n);
    for (i = 0; i < n; ++i) {
        struct ir *inst = va_arg(argp, struct ir *);
        if (inst)
            chunk->inst[chunk->n_inst++] = inst;
    }
    va_end(argp);
    /*
     * Check we have a valid last instruction.
     */
    if (chunk->n_inst == 0)
        quit("Empty chunk allocated from line %d", line);
    switch (chunk->inst[chunk->n_inst - 1]->op) {
        case Ir_Goto:
        case Ir_IGoto:
        case Ir_Fail:
        case Ir_Return:
        case Ir_TCaseChoose:
        case Ir_SysErr:
            break;
        default:
            quit("Invalid last instruction for chunk allocated from line %d", line);
    }
    if (Iflag)
        print_chunk(chunk);
    return chunk;
}

static struct ir_info *ir_info(struct lnode *node)
{
    struct ir_info *res = IRAlloc1(struct ir_info);
    res->desc = 0;
    res->start = chunk_id_seq++;
    res->success = chunk_id_seq++;
    res->resume = chunk_id_seq++;
    res->failure = chunk_id_seq++;
    res->node = node;
    res->uses_stack = 0;
    res->scan = 0;
    res->loop = 0;
    return res;
}

static struct ir_var *ir_var(int type)
{
    struct ir_var *v = IRAlloc1(struct ir_var);
    v->type = type;
    v->index = v->w = v->renumbered = 0;
    v->con = 0;
    v->local = 0;
    v->global = 0;
    return v;
}

static int get_extra_chunk()
{
    return chunk_id_seq++;
}

static struct ir_goto *ir_goto(struct lnode *n, int dest)
{
    struct ir_goto *res = IRAlloc1(struct ir_goto);
    res->node = n;
    res->op = Ir_Goto;
    res->dest = dest;
    return res;
}

static struct ir_igoto *ir_igoto(struct lnode *n, int no)
{
    struct ir_igoto *res = IRAlloc1(struct ir_igoto);
    res->node = n;
    res->op = Ir_IGoto;
    res->no = no;
    return res;
}

static struct ir_scanswap *ir_scanswap(struct lnode *n, struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scanswap *res = IRAlloc1(struct ir_scanswap);
    res->node = n;
    res->op = Ir_ScanSwap;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_scansave *ir_scansave(struct lnode *n, struct ir_var *new_subject,
                                       struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scansave *res = IRAlloc1(struct ir_scansave);
    res->node = n;
    res->op = Ir_ScanSave;
    res->new_subject = new_subject;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_scanrestore *ir_scanrestore(struct lnode *n, struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scanrestore *res = IRAlloc1(struct ir_scanrestore);
    res->node = n;
    res->op = Ir_ScanRestore;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_move *ir_move(struct lnode *n, struct ir_var *lhs, struct ir_var *rhs)
{
    struct ir_move *res;
    if (!lhs)
        return 0;
    res = IRAlloc1(struct ir_move);
    res->node = n;
    res->op = Ir_Move;
    res->lhs = lhs;
    res->rhs = rhs;
    return res;
}

static struct ir_deref *ir_deref(struct lnode *n, struct ir_var *lhs, struct ir_var *rhs)
{
    struct ir_deref *res;
    if (!lhs)
        return 0;
    res = IRAlloc1(struct ir_deref);
    res->node = n;
    res->op = Ir_Deref;
    res->lhs = lhs;
    res->rhs = rhs;
    return res;
}

static struct ir_movelabel *ir_movelabel(struct lnode *n, int destno, int lab)
{
    struct ir_movelabel *res = IRAlloc1(struct ir_movelabel);
    res->node = n;
    res->op = Ir_MoveLabel;
    res->lab = lab;
    res->destno = destno;
    return res;
}

static struct ir_makelist *ir_makelist(struct lnode *n, struct ir_var *lhs, int argc, struct ir_var **args)
{
    struct ir_makelist *res;
    /*
     * Note that we must still have a makelist instruction even if lhs
     * is nil, since it dereferences its arguments, which may cause a
     * runtime error.  If the list is empty obviously this doesn't
     * apply.
     */
    if (!lhs && argc == 0)
        return 0;
    res = IRAlloc1(struct ir_makelist);
    res->node = n;
    res->op = Ir_MakeList;
    res->lhs = lhs;
    res->argc = argc;
    res->args = args;
    return res;
}

static struct ir_create *ir_create(struct lnode *n, struct ir_var *lhs, int start_label)
{
    struct ir_create *res = IRAlloc1(struct ir_create);
    res->node = n;
    res->op = Ir_Create;
    res->lhs = lhs;
    res->start_label = start_label;
    return res;
}

static struct ir_coret *ir_coret(struct lnode *n, struct ir_var *value)
{
    struct ir_coret *res = IRAlloc1(struct ir_coret);
    res->node = n;
    res->op = Ir_Coret;
    res->value = value;
    return res;
}

static struct ir *ir_cofail(struct lnode *n)
{
    struct ir *res = IRAlloc1(struct ir);
    res->node = n;
    res->op = Ir_Cofail;
    return res;
}

static struct ir_mark *ir_mark(struct lnode *n, struct mark_pair *mp)
{
    struct ir_mark *res = IRAlloc1(struct ir_mark);
    res->node = n;
    res->op = Ir_Mark;
    res->no = mp->no;
    res->id = mp->id;
    return res;
}

static struct ir_unmark *ir_unmark(struct lnode *n, struct mark_pair *mp)
{
    struct ir_unmark *res = IRAlloc1(struct ir_unmark);
    res->node = n;
    res->op = Ir_Unmark;
    res->no = mp->no;
    res->id = mp->id;
    return res;
}

static struct ir_enterinit *ir_enterinit(struct lnode *n, int dest)
{
    struct ir_enterinit *res = IRAlloc1(struct ir_enterinit);
    res->node = n;
    res->op = Ir_EnterInit;
    res->dest = dest;
    return res;
}

static struct ir *ir_fail(struct lnode *n)
{
    struct ir *res = IRAlloc1(struct ir);
    res->node = n;
    res->op = Ir_Fail;
    return res;
}

static struct ir *ir_syserr(struct lnode *n)
{
    struct ir *res = IRAlloc1(struct ir);
    res->node = n;
    res->op = Ir_SysErr;
    return res;
}

static struct ir_suspend *ir_suspend(struct lnode *n, struct ir_var *val)
{
    struct ir_suspend *res = IRAlloc1(struct ir_suspend);
    res->node = n;
    res->val = val;
    res->op = Ir_Suspend;
    return res;
}

static struct ir_return *ir_return(struct lnode *n, struct ir_var *val)
{
    struct ir_return *res = IRAlloc1(struct ir_return);
    res->node = n;
    res->val = val;
    res->op = Ir_Return;
    return res;
}

static struct ir_op *ir_op(struct lnode *n,
                           struct ir_var *lhs,
                           int operation,
                           struct ir_var *arg1,
                           struct ir_var *arg2,
                           struct ir_var *arg3,
                           int rval,
                           int fail_label) 
{
    struct ir_op *res = IRAlloc1(struct ir_op);
    res->node = n;
    res->op = Ir_Op;
    res->lhs = lhs;
    res->operation = operation;
    res->arg1 = arg1;
    res->arg2 = arg2;
    res->arg3 = arg3;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_mgop *ir_mgop(struct lnode *n,
                               struct ir_var *lhs,
                               int operation,
                               struct ir_var *arg1,
                               struct ir_var *arg2,
                               int rval)
{
    struct ir_mgop *res = IRAlloc1(struct ir_mgop);
    res->node = n;
    res->op = Ir_MgOp;
    res->lhs = lhs;
    res->operation = operation;
    res->arg1 = arg1;
    res->arg2 = arg2;
    res->rval = rval;
    return res;
}

static struct ir_keyop *ir_keyop(struct lnode *n,
                                 struct ir_var *lhs,
                                 int keyword,
                                 int rval,
                                 int fail_label) 
{
    struct ir_keyop *res = IRAlloc1(struct ir_keyop);
    res->node = n;
    res->op = Ir_KeyOp;
    res->lhs = lhs;
    res->keyword = keyword;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_opclo *ir_opclo(struct lnode *n,
                                 int clo,
                                 struct ir_var *lhs,
                                 int operation,
                                 struct ir_var *arg1,
                                 struct ir_var *arg2,
                                 struct ir_var *arg3,
                                 int rval,
                                 int fail_label) 
{
    struct ir_opclo *res = IRAlloc1(struct ir_opclo);
    res->node = n;
    res->op = Ir_OpClo;
    res->clo = clo;
    res->lhs = lhs;
    res->operation = operation;
    res->arg1 = arg1;
    res->arg2 = arg2;
    res->arg3 = arg3;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_keyclo *ir_keyclo(struct lnode *n,
                                   int clo,
                                   struct ir_var *lhs,
                                   int keyword,
                                   int rval,
                                   int fail_label) 
{
    struct ir_keyclo *res = IRAlloc1(struct ir_keyclo);
    res->node = n;
    res->op = Ir_KeyClo;
    res->clo = clo;
    res->lhs = lhs;
    res->keyword = keyword;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_invoke *ir_invoke(struct lnode *n,
                                   int clo,
                                   struct ir_var *lhs,
                                   struct ir_var *expr,
                                   int argc,
                                   struct ir_var **args,
                                   int rval,
                                   int fail_label) 
{
    struct ir_invoke *res = IRAlloc1(struct ir_invoke);
    res->node = n;
    res->op = Ir_Invoke;
    res->clo = clo;
    res->lhs = lhs;
    res->expr = expr;
    res->argc = argc;
    res->args = args;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_apply *ir_apply(struct lnode *n,
                                 int clo,
                                 struct ir_var *lhs,
                                 struct ir_var *arg1,
                                 struct ir_var *arg2,
                                 int rval,
                                 int fail_label) 
{
    struct ir_apply *res = IRAlloc1(struct ir_apply);
    res->node = n;
    res->op = Ir_Apply;
    res->clo = clo;
    res->lhs = lhs;
    res->arg1 = arg1;
    res->arg2 = arg2;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_invokef *ir_invokef(struct lnode *n,
                                     int clo,
                                     struct ir_var *lhs,
                                     struct ir_var *expr,
                                     struct fentry *ftab_entry,
                                     int argc,
                                     struct ir_var **args,
                                     int rval,
                                     int fail_label) 
{
    struct ir_invokef *res = IRAlloc1(struct ir_invokef);
    res->node = n;
    res->op = Ir_Invokef;
    res->clo = clo;
    res->lhs = lhs;
    res->expr = expr;
    res->ftab_entry = ftab_entry;
    res->argc = argc;
    res->args = args;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_applyf *ir_applyf(struct lnode *n,
                                   int clo,
                                   struct ir_var *lhs,
                                   struct ir_var *arg1,
                                   struct fentry *ftab_entry,
                                   struct ir_var *arg2,
                                   int rval,
                                   int fail_label) 
{
    struct ir_applyf *res = IRAlloc1(struct ir_applyf);
    res->node = n;
    res->op = Ir_Applyf;
    res->clo = clo;
    res->lhs = lhs;
    res->arg1 = arg1;
    res->ftab_entry = ftab_entry;
    res->arg2 = arg2;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_field *ir_field(struct lnode *n,
                                 struct ir_var *lhs,
                                 struct ir_var *expr,
                                 struct fentry *ftab_entry)
{
    struct ir_field *res = IRAlloc1(struct ir_field);
    res->node = n;
    res->op = Ir_Field;
    res->lhs = lhs;
    res->expr = expr;
    res->ftab_entry = ftab_entry;
    return res;
}

static struct ir_resume *ir_resume(struct lnode *n,
                                   int clo)
{
    struct ir_resume *res = IRAlloc1(struct ir_resume);
    res->node = n;
    res->op = Ir_Resume;
    res->clo = clo;
    return res;
}

static struct ir_limit *ir_limit(struct lnode *n, struct ir_var *limit)
{
    struct ir_limit *res = IRAlloc1(struct ir_limit);
    res->node = n;
    res->op = Ir_Limit;
    res->limit = limit;
    return res;
}

static struct ir_tcaseinit *ir_tcaseinit(struct lnode *n, int size, int def)
{
    struct ir_tcaseinit *res = IRAlloc1(struct ir_tcaseinit);
    res->node = n;
    res->op = Ir_TCaseInit;
    res->size = size;
    res->def = def;
    res->no = -1;
    res->id = tcaseinit_id_seq++;
    return res;
}

static struct ir_tcaseinsert *ir_tcaseinsert(struct lnode *n, struct ir_tcaseinit *tci, struct ir_var *val, int entry)
{
    struct ir_tcaseinsert *res = IRAlloc1(struct ir_tcaseinsert);
    res->node = n;
    res->op = Ir_TCaseInsert;
    res->tci = tci;
    res->val = val;
    res->entry = entry;
    return res;
}

static struct ir_tcasechoose *ir_tcasechoose(struct lnode *n, struct ir_tcaseinit *tci, struct ir_var *val)
{
    struct ir_tcasechoose *res = IRAlloc1(struct ir_tcasechoose);
    res->node = n;
    res->op = Ir_TCaseChoose;
    res->tci = tci;
    res->val = val;
    return res;
}

static struct ir_var *make_tmp(struct ir_stack *st)
{
    struct ir_var *v = ir_var(TMP);
    v->index = st->tmp++;
    v->tmp_id = tmp_id_seq++;
    if (v->index > hi_tmp)
        hi_tmp = v->index;
    return v;
}

static struct ir_var *make_word(word w)
{
    struct ir_var *v = ir_var(WORD);
    v->w = w;
    return v;
}

static struct ir_var *make_self(void)
{
    struct ir_var *v;
    if (curr_lfunc->method->flag & M_Static) {
        v = ir_var(GLOBAL);
        v->global = curr_lfunc->method->class->global;
    } else {
        /* "self" is the first in the locals list */
        v = ir_var(LOCAL);
        v->local = curr_lfunc->locals;
    }
    return v;
}

static struct ir_var *make_knull(void)
{
    return ir_var(KNULL);
}

static struct ir_var *make_kyes(void)
{
    return ir_var(KYES);
}

static int make_tmploc(struct ir_stack *st)
{
    int i = st->lab++;
    if (i > hi_lab)
        hi_lab = i;
    return i;
}

static struct mark_pair *make_mark(struct ir_stack *st)
{
    struct mark_pair *m = IRAlloc1(struct mark_pair);
    int i = st->mark++;
    if (i > hi_mark)
        hi_mark = i;
    m->no = i;
    m->id = mark_id_seq++;
    return m;
}

static int make_closure(struct ir_stack *st)
{
    int i = st->clo++;
    if (i > hi_clo)
        hi_clo = i;
    return i;
}

static struct ir_var *make_const(struct lnode *n)
{
    struct ir_var *v = ir_var(CONST);
    v->con = ((struct lnode_const *)n)->con;
    return v;
}

static struct ir_var *make_local(struct lnode *n)
{
    struct ir_var *v = ir_var(LOCAL);
    v->local = ((struct lnode_local *)n)->local;
    return v;
}

static struct ir_var *make_global(struct lnode *n)
{
    struct ir_var *v = ir_var(GLOBAL);
    v->global = ((struct lnode_global *)n)->global;
    v->local = ((struct lnode_global *)n)->local;
    return v;
}

/*
 * Return true if the given global is a package readable which is
 * readonly (ie we are in another package, and not lang).
 */
int is_readable_global(struct gentry *ge)
{
    return (ge->g_flag & F_Readable) &&
            curr_lfunc->defined->package_id != 1 &&
            ge->defined->package_id != curr_lfunc->defined->package_id;
}

/*
 * Return true if the given local is the class instance self variable.
 */
int is_self(struct lentry *le)
{
    return curr_lfunc->method &&
           !(curr_lfunc->method->flag & M_Static) &&
           (le->l_flag & F_Argument) && le->l_val.index == 0;
}

static int is_assignable_var(struct lnode *n)
{
    switch (n->op) {
        case Uop_Local: {
            struct lentry *le = ((struct lnode_local *)n)->local;
            return !is_self(le);
        }
        case Uop_Global: {
            struct gentry *ge = ((struct lnode_global *)n)->global;
            if ((ge->g_flag & (F_Builtin|F_Proc|F_Record|F_Class)) == 0)
                return !is_readable_global(ge);
            else
                return 0;
        }
    }
    return 0;
}

static struct ir_var *get_var(struct lnode *n, struct ir_stack *st)
{
    switch (n->op) {
        case Uop_Keyword: {
            switch (((struct lnode_keyword *)n)->num) {
                case K_NULL: return make_knull();
                case K_YES: return make_kyes();
            }
            break;
        }
        case Uop_Empty:
            return make_knull();
        case Uop_Const:
            return make_const(n);
        case Uop_Local:
            return make_local(n);
        case Uop_Global:
            /* Package readable globals must use a temp, since they
             * are dereferenced on a move, but may change (see notes). */
            if (!is_readable_global(((struct lnode_global *)n)->global))
                return make_global(n);
    }
    return make_tmp(st);
}

static int is_rval(int op, int arg, int parent)
{
    switch (op) {

        case Uop_Asgn:
        case Uop_Bactivate:
        case Uop_Augactivate:
        case Uop_Augapply:
        case Uop_Augpower:
        case Uop_Augcat:
        case Uop_Augdiff:
        case Uop_Augeqv:
        case Uop_Auginter:
        case Uop_Auglconcat:
        case Uop_Auglexeq:
        case Uop_Auglexge:
        case Uop_Auglexgt:
        case Uop_Auglexle:
        case Uop_Auglexlt:
        case Uop_Auglexne:
        case Uop_Augminus:
        case Uop_Augmod:
        case Uop_Augneqv:
        case Uop_Augnumeq:
        case Uop_Augnumge:
        case Uop_Augnumgt:
        case Uop_Augnumle:
        case Uop_Augnumlt:
        case Uop_Augnumne:
        case Uop_Augplus:
        case Uop_Rasgn:
        case Uop_Augdiv:
        case Uop_Augmult:
        case Uop_Augunion:

        case Uop_To:
        case Uop_Eqv:
        case Uop_Lexeq:
        case Uop_Lexge:
        case Uop_Lexgt:
        case Uop_Lexle:
        case Uop_Lexlt:
        case Uop_Lexne:
        case Uop_Neqv:
        case Uop_Numeq:
        case Uop_Numge:
        case Uop_Numgt:
        case Uop_Numle:
        case Uop_Numlt:
        case Uop_Numne:

        case Uop_Cat:
        case Uop_Diff:
        case Uop_Div:
        case Uop_Inter:
        case Uop_Lconcat:
        case Uop_Minus:
        case Uop_Mod:
        case Uop_Mult:
        case Uop_Plus:
        case Uop_Power:
        case Uop_Union:

        case Uop_Subsc: {
            return (arg == 2);
        }

        case Uop_Toby:
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm: {
            return (arg == 3);
        }


        case Uop_Rswap:
        case Uop_Swap: {
            return 0;
        }

        /* Unary monogenic operators */
        case Uop_Value:		/* unary . operator */
        case Uop_Size:		/* unary * operator */
        case Uop_Refresh:	/* unary ^ operator */
        case Uop_Number:	/* unary + operator */
        case Uop_Compl:		/* unary ~ operator (cset compl) */
        case Uop_Neg:		/* unary - operator */

        case Uop_Tabmat:	/* unary = operator */
            return 1;

        case Uop_Bang:
        case Uop_Random:
        case Uop_Null:
        case Uop_Nonnull: {
            return parent;
        }

        default:
            quit("Invalid opcode to is_rval %d", op);
    }
    /* Not reached */
    return 0;
}

static struct ir_info *ir_traverse(struct lnode *n, struct ir_stack *st, struct ir_var *target, int bounded, int rval)
{
    struct ir_info *res = ir_info(n);
    if (Iflag) {
        indentf("uop = %s (bounded=%d rval=%d, target=", ucode_op_table[n->op].name, bounded, rval);
        print_ir_var(target);
        fprintf(stderr, ") {\n");
    }
    ++traverse_level;
    switch (n->op) {
        case Uop_End: {
            chunk1(res->start, ir_fail(n));
            break;
        }
        case Uop_Empty: {
            if (target && target->type == KNULL)
                target = 0;
            chunk2(res->start,
                  ir_move(n, target, make_knull()),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Keyword: {
            struct lnode_keyword *x = (struct lnode_keyword *)n;
            switch (x->num) {
                case K_FAIL: {
                    chunk1(res->start, ir_goto(n, res->failure));
                    if (!bounded)
                        chunk1(res->resume, ir_syserr(n));
                    break;
                }

                case K_NULL: {
                    if (target && target->type == KNULL)
                        target = 0;
                    chunk2(res->start, 
                          ir_move(n, target, make_knull()),
                          ir_goto(n, res->success));
                    if (!bounded)
                        chunk1(res->resume, ir_goto(n, res->failure));
                    break;
                }

                case K_YES: {
                    if (target && target->type == KYES)
                        target = 0;
                    chunk2(res->start, 
                          ir_move(n, target, make_kyes()),
                          ir_goto(n, res->success));
                    if (!bounded)
                        chunk1(res->resume, ir_goto(n, res->failure));
                    break;
                }

                case K_FEATURES: {
                    int clo = make_closure(st);
                    chunk2(res->start,
                           ir_keyclo(n, clo, target, x->num, rval, res->failure),
                           ir_goto(n, res->success));
                    if (!bounded)
                        chunk2(res->resume, 
                               ir_resume(n, clo),
                               ir_goto(n, res->success));
                    res->uses_stack = 1;
                    break;
                }

                default: {
                    chunk2(res->start,
                          ir_keyop(n, target, x->num, rval, res->failure),
                          ir_goto(n, res->success));
                    if (!bounded)
                        chunk1(res->resume, 
                               ir_goto(n, res->failure));
                    break;
                }
            }
            break;
        }

        case Uop_Local: {
            struct lnode_local *x = (struct lnode_local *)n;
            if (target && target->type == LOCAL) {
                if (target->local != x->local)
                    quit("Local target points to wrong var");
                target = 0;
            }
            chunk2(res->start, 
                  ir_move(n, target, make_local(n)),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Global: {
            struct lnode_global *x = (struct lnode_global *)n;
            if (target && target->type == GLOBAL) {
                if (target->global != x->global)
                    quit("Global target points to wrong var");
                target = 0;
            }
            chunk2(res->start, 
                  ir_move(n, target, make_global(n)),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Const: {
            struct lnode_const *x = (struct lnode_const *)n;
            if (target && target->type == CONST) {
                if (target->con != x->con)
                    quit("Const target points to wrong constant");
                target = 0;
            }
            chunk2(res->start, 
                  ir_move(n, target, make_const(n)),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Scan: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *body;
            struct ir_var *lv;

            init_scan(res, st);
            lv = get_var(x->child1, st);
            expr = ir_traverse(x->child1, st, lv, 0, 1);
            push_scan(res);
            body = ir_traverse(x->child2, st, target, bounded, rval);
            pop_scan();

            chunk1(res->start, ir_goto(n, expr->start));
            if (!bounded) {
                chunk2(res->resume, 
                      ir_scanswap(n, res->scan->old_subject, res->scan->old_pos),
                      ir_goto(n, body->resume));
            }
            chunk2(expr->success,
                   ir_scansave(n, lv, res->scan->old_subject, res->scan->old_pos),
                   ir_goto(n, body->start));
            chunk1(expr->failure, ir_goto(n, res->failure));

            chunk2(body->failure,
                  ir_scanrestore(n, res->scan->old_subject, res->scan->old_pos),
                  ir_goto(n, expr->resume));
            chunk2(body->success,
                   bounded ? 
                      (struct ir *)ir_scanrestore(n, res->scan->old_subject, res->scan->old_pos) :
                      (struct ir *)ir_scanswap(n, res->scan->old_subject, res->scan->old_pos),
                   ir_goto(n, res->success));

            res->uses_stack = (expr->uses_stack || body->uses_stack);
            break;
        }

        case Uop_Augscan: {                     /* scanning expression */
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *body;
            struct ir_var *lv, *rv;
            int av, af;

            init_scan(res, st);
            lv = get_var(x->child1, st);
            rv = make_tmp(st);

            av = is_assignable_var(x->child1);
            af = asgn_may_fail(x->child1, 0);

            expr = ir_traverse(x->child1, st, lv, 0, 0);
            push_scan(res);
            body = ir_traverse(x->child2, st, rv, bounded && (av || !af), rval);
            pop_scan();

            chunk1(res->start, ir_goto(n, expr->start));
            if (!bounded) {
                chunk2(res->resume, 
                      ir_scanswap(n, res->scan->old_subject, res->scan->old_pos),
                      ir_goto(n, body->resume));
            }
            chunk2(expr->success,
                   ir_scansave(n, lv, res->scan->old_subject, res->scan->old_pos),
                   ir_goto(n, body->start));
            chunk1(expr->failure, ir_goto(n, res->failure));

            chunk2(body->failure,
                   ir_scanrestore(n, res->scan->old_subject, res->scan->old_pos),
                   ir_goto(n, expr->resume));
            /* Use deref, move instead of assign if possible */
            if (av)
                chunk4(body->success,
                       ir_deref(n, lv, rv),
                       ir_move(n, target, lv),
                       bounded ?
                            (struct ir *)ir_scanrestore(n, res->scan->old_subject, res->scan->old_pos) :
                            (struct ir *)ir_scanswap(n, res->scan->old_subject, res->scan->old_pos),
                       ir_goto(n, res->success));
            else
                chunk3(body->success,
                       af ? (struct ir *)ir_op(n, target, Uop_Asgn, lv, rv, 0, rval, body->resume) :
                            (struct ir *)ir_mgop(n, target, Uop_Asgn1, lv, rv, rval),
                       bounded ?
                            (struct ir *)ir_scanrestore(n, res->scan->old_subject, res->scan->old_pos) :
                            (struct ir *)ir_scanswap(n, res->scan->old_subject, res->scan->old_pos),
                       ir_goto(n, res->success));

            res->uses_stack = (expr->uses_stack || body->uses_stack);
            break;
        }

        case Uop_Toby: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            struct ir_var *fv, *tv, *bv;
            struct ir_info *from, *to, *by;
            int clo;

            fv = get_var(x->child1, st);
            tv = get_var(x->child2, st);
            bv = get_var(x->child3, st);

            from = ir_traverse(x->child1, st, fv, 0, is_rval(n->op, 1, rval));
            to = ir_traverse(x->child2, st, tv, 0, is_rval(n->op, 2, rval));
            by = ir_traverse(x->child3, st, bv, 0, is_rval(n->op, 3, rval));

            clo = make_closure(st);

            chunk1(res->start, ir_goto(n, from->start));
            if (!bounded)
                chunk2(res->resume, 
                       ir_resume(n, clo),
                       ir_goto(n, res->success));

            chunk1(from->success, ir_goto(n, to->start));
            chunk1(from->failure, ir_goto(n, res->failure));

            chunk1(to->success, ir_goto(n, by->start));
            chunk1(to->failure, ir_goto(n, from->resume));

            chunk2(by->success, 
                   ir_opclo(n, clo, target, n->op, fv, tv, bv, rval, by->resume),
                   ir_goto(n, res->success));
            chunk1(by->failure, ir_goto(n, to->resume));

            res->uses_stack = 1;

            break;
        }

        case Uop_To: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *fv, *tv, *one;
            struct ir_info *from, *to;
            int clo;

            fv = get_var(x->child1, st);
            tv = get_var(x->child2, st);
            one = make_word(1);

            from = ir_traverse(x->child1, st, fv, 0, is_rval(n->op, 1, rval));
            to = ir_traverse(x->child2, st, tv, 0, is_rval(n->op, 2, rval));

            clo = make_closure(st);

            chunk1(res->start, ir_goto(n, from->start));
            if (!bounded)
                chunk2(res->resume, 
                       ir_resume(n, clo),
                       ir_goto(n, res->success));

            chunk1(from->success, ir_goto(n, to->start));
            chunk1(from->failure, ir_goto(n, res->failure));

            chunk2(to->success, 
                   ir_opclo(n, clo, target, Uop_Toby, fv, tv, one, rval, to->resume),
                   ir_goto(n, res->success));
            chunk1(to->failure, ir_goto(n, from->resume));

            res->uses_stack = 1;

            break;
        }

        case Uop_Augcat:
        case Uop_Augdiff:
        case Uop_Augdiv:
        case Uop_Auginter:
        case Uop_Auglconcat:
        case Uop_Augminus:
        case Uop_Augmod:
        case Uop_Augmult:
        case Uop_Augplus:
        case Uop_Augpower:
        case Uop_Augunion: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv, *tmp = 0;
            struct ir_info *left, *right;
            int aaop, af;

            aaop = augop(n->op);
            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            /*
             * Optimisation v op:= expr, where v is local or global,
             * just put the result of v op expr straight into v.
             */
            if (is_assignable_var(x->child1)) {
                right = ir_traverse(x->child2, st, rv, bounded, is_rval(n->op, 2, rval));
                chunk1(res->start, ir_goto(n, right->start));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, right->resume));
                chunk1(right->success, ir_goto(n, res->success));
                chunk1(right->failure, ir_goto(n, res->failure));
                chunk3(right->success, 
                       ir_mgop(n, lv, aaop, lv, rv, 1),
                       ir_move(n, target, lv),
                       ir_goto(n, res->success));
                res->uses_stack = right->uses_stack;
                break;
            }

            tmp = make_tmp(st);

            af = asgn_may_fail(x->child1, 0);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, bounded && !af, is_rval(n->op, 2, rval));
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk3(right->success, 
                   ir_mgop(n, tmp, aaop, lv, rv, 1),
                   af ? (struct ir *)ir_op(n, target, Uop_Asgn, lv, tmp, 0, rval, right->resume) :
                        (struct ir *)ir_mgop(n, target, Uop_Asgn1, lv, tmp, rval),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Cat:
        case Uop_Diff:
        case Uop_Div:
        case Uop_Inter:
        case Uop_Lconcat:
        case Uop_Minus:
        case Uop_Mod:
        case Uop_Mult:
        case Uop_Plus:
        case Uop_Power:
        case Uop_Union: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;

            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, bounded, is_rval(n->op, 2, rval));
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk2(right->success, 
                   ir_mgop(n, target, n->op, lv, rv, rval),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Augactivate:
        case Uop_Augeqv:
        case Uop_Auglexeq:
        case Uop_Auglexge:
        case Uop_Auglexgt:
        case Uop_Auglexle:
        case Uop_Auglexlt:
        case Uop_Auglexne:
        case Uop_Augneqv:
        case Uop_Augnumeq:
        case Uop_Augnumge:
        case Uop_Augnumgt:
        case Uop_Augnumle:
        case Uop_Augnumlt:
        case Uop_Augnumne: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv, *tmp = 0;
            struct ir_info *left, *right;
            int aaop, af;

            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            aaop = augop(n->op);

            /*
             * Optimisation v op:= expr, where v is local or global,
             * and op doesn't return a variable, just put the result
             * of v op expr straight into v.
             */
            if (n->op != Uop_Augactivate &&
                is_assignable_var(x->child1)) {
                right = ir_traverse(x->child2, st, rv, 0, is_rval(n->op, 2, rval));
                chunk1(res->start, ir_goto(n, right->start));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, right->resume));
                chunk1(right->success, ir_goto(n, res->success));
                chunk1(right->failure, ir_goto(n, res->failure));
                chunk3(right->success, 
                       ir_op(n, lv, aaop, lv, rv, 0, 1, right->resume),
                       ir_move(n, target, lv),
                       ir_goto(n, res->success));
                res->uses_stack = right->uses_stack;
                break;
            }

            tmp = make_tmp(st);
            af = asgn_may_fail(x->child1, 0);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, 0, is_rval(n->op, 2, rval));
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk3(right->success, 
                   ir_op(n, tmp, aaop, lv, rv, 0, 1, right->resume),
                   af ? (struct ir *)ir_op(n, target, Uop_Asgn, lv, tmp, 0, rval, right->resume) :
                        (struct ir *)ir_mgop(n, target, Uop_Asgn1, lv, tmp, rval),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Asgn: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int af;

            /*
             * Optimisation: v := e1 op e2, where v is local or global,
             * and op is something that doesn't return a variable.  We
             * just put the result of op straight into v.
             */
            if (is_assignable_var(x->child1) &&
                (
                    x->child2->op == Uop_Const ||
                    x->child2->op == Uop_Cat ||
                    x->child2->op == Uop_Diff ||
                    x->child2->op == Uop_Div ||
                    x->child2->op == Uop_Inter ||
                    x->child2->op == Uop_Lconcat ||
                    x->child2->op == Uop_Minus ||
                    x->child2->op == Uop_Mod ||
                    x->child2->op == Uop_Mult ||
                    x->child2->op == Uop_Plus ||
                    x->child2->op == Uop_Power ||
                    x->child2->op == Uop_Union ||
                    x->child2->op == Uop_Value ||
                    x->child2->op == Uop_Size ||
                    x->child2->op == Uop_Refresh ||
                    x->child2->op == Uop_Number ||
                    x->child2->op == Uop_Compl ||
                    x->child2->op == Uop_Neg ||
                    x->child2->op == Uop_Eqv ||
                    x->child2->op == Uop_Lexeq ||
                    x->child2->op == Uop_Lexge ||
                    x->child2->op == Uop_Lexgt ||
                    x->child2->op == Uop_Lexle ||
                    x->child2->op == Uop_Lexlt ||
                    x->child2->op == Uop_Lexne ||
                    x->child2->op == Uop_Neqv ||
                    x->child2->op == Uop_Numeq ||
                    x->child2->op == Uop_Numge ||
                    x->child2->op == Uop_Numgt ||
                    x->child2->op == Uop_Numle ||
                    x->child2->op == Uop_Numlt ||
                    x->child2->op == Uop_Numne))
             {
                lv = get_var(x->child1, st);
                right = ir_traverse(x->child2, st, lv, bounded, 1);
                chunk1(res->start, ir_goto(n, right->start));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, right->resume));
                chunk2(right->success, 
                       ir_move(n, target, lv),
                       ir_goto(n, res->success));
                chunk1(right->failure, ir_goto(n, res->failure));
                res->uses_stack = right->uses_stack;
                break;
            }

            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            /*
             * Optimisation: v := expr, where v is local or global.
             * Just use deref to put the result of expr into v.
             */
            if (is_assignable_var(x->child1))
            {
                right = ir_traverse(x->child2, st, rv, bounded, 1);
                chunk1(res->start, ir_goto(n, right->start));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, right->resume));
                chunk3(right->success, 
                       ir_deref(n, lv, rv),
                       ir_move(n, target, lv),
                       ir_goto(n, res->success));
                chunk1(right->failure, ir_goto(n, res->failure));
                res->uses_stack = right->uses_stack;
                break;
            }

            af = asgn_may_fail(x->child1, 0);

            left = ir_traverse(x->child1, st, lv, 0, 0);
            right = ir_traverse(x->child2, st, rv, bounded && !af, 1);
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk2(right->success, 
                   af ? (struct ir *)ir_op(n, target, Uop_Asgn, lv, rv, 0, rval, right->resume) :
                        (struct ir *)ir_mgop(n, target, Uop_Asgn1, lv, rv, rval),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Swap: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int af;

            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            af = (asgn_may_fail(x->child1, 1) || asgn_may_fail(x->child2, 1));

            left = ir_traverse(x->child1, st, lv, 0, 0);
            right = ir_traverse(x->child2, st, rv, bounded && !af, 0);
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk2(right->success, 
                   af ? (struct ir *)ir_op(n, target, Uop_Swap, lv, rv, 0, rval, right->resume) :
                        (struct ir *)ir_mgop(n, target, Uop_Swap1, lv, rv, rval),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Bactivate:
        case Uop_Eqv:
        case Uop_Subsc:
        case Uop_Lexeq:
        case Uop_Lexge:
        case Uop_Lexgt:
        case Uop_Lexle:
        case Uop_Lexlt:
        case Uop_Lexne:
        case Uop_Neqv:
        case Uop_Numeq:
        case Uop_Numge:
        case Uop_Numgt:
        case Uop_Numle:
        case Uop_Numlt:
        case Uop_Numne: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;

            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, 0, is_rval(n->op, 2, rval));
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            chunk2(right->success, 
                   ir_op(n, target, n->op, lv, rv, 0, rval, right->resume),
                   ir_goto(n, res->success));

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Apply: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int clo;
            struct fentry *ftab_entry = 0;

            clo = make_closure(st);
            if (x->child1->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->child1;
                lv = get_var(y->child, st);
                rv = get_var(x->child2, st);
                left = ir_traverse(y->child, st, lv, 0, 0);
                ftab_entry = y->ftab_entry;
            } else {
                lv = get_var(x->child1, st);
                rv = get_var(x->child2, st);
                left = ir_traverse(x->child1, st, lv, 0, 0);
            }
            right = ir_traverse(x->child2, st, rv, 0, 1);

            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk2(res->resume, 
                       ir_resume(n, clo),
                       ir_goto(n, res->success));

            if (ftab_entry)
                chunk2(right->success, 
                       ir_applyf(n, clo, target, lv, ftab_entry, rv, rval, right->resume),
                       ir_goto(n, res->success));
            else
                chunk2(right->success, 
                       ir_apply(n, clo, target, lv, rv, rval, right->resume),
                       ir_goto(n, res->success));

            res->uses_stack = 1;

            break;
        }

        case Uop_Augapply: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv, *tmp;
            struct ir_info *left, *right;
            int clo, xc, av, af;

            clo = make_closure(st);
            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);
            tmp = make_tmp(st);

            av = is_assignable_var(x->child1);
            af = asgn_may_fail(x->child1, 0);

            left = ir_traverse(x->child1, st, lv, 0, 0);
            right = ir_traverse(x->child2, st, rv, 0, 1);

            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            xc = get_extra_chunk();

            /*
             * Optimisation v !:= expr where v is local or global.
             * Note that we still need a temporary variable since the
             * procedure being applied may return a variable, which we
             * must dereference.
             */
            if (av) {
                if (!bounded)
                    chunk2(res->resume, 
                           ir_resume(n, clo),
                           ir_goto(n, xc));

                chunk2(right->success, 
                       ir_apply(n, clo, tmp, lv, rv, 1, right->resume),
                       ir_goto(n, xc));

                chunk3(xc, 
                       ir_deref(n, lv, tmp),
                       ir_move(n, target, lv),
                       ir_goto(n, res->success));
            } else {
                /* Needed regardless of bounded, if := can fail */
                if (!bounded || af)
                    chunk2(res->resume, 
                           ir_resume(n, clo),
                           ir_goto(n, xc));

                chunk2(right->success, 
                       ir_apply(n, clo, tmp, lv, rv, 1, right->resume),
                       ir_goto(n, xc));

                chunk2(xc, 
                       af ? (struct ir *)ir_op(n, target, Uop_Asgn, lv, tmp, 0, rval, res->resume) :
                            (struct ir *)ir_mgop(n, target, Uop_Asgn1, lv, tmp, rval),
                       ir_goto(n, res->success));
            }

            res->uses_stack = 1;

            break;
        }

        case Uop_Rasgn:
        case Uop_Rswap:{
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int clo = make_closure(st);
            lv = get_var(x->child1, st);
            rv = get_var(x->child2, st);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, 0, is_rval(n->op, 2, rval));

            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk2(res->resume, 
                       ir_resume(n, clo),
                       ir_goto(n, res->success));

            chunk2(right->success, 
                   ir_opclo(n, clo, target, n->op, lv, rv, 0, rval, right->resume),
                   ir_goto(n, res->success));

            res->uses_stack = 1;

            break;
        }

        case Uop_Sectp:                 /* section operation x[a+:b] */
        case Uop_Sectm: {               /* section operation x[a-:b] */
            struct lnode_3 *x = (struct lnode_3 *)n;
            struct ir_var *v1, *v2, *v3, *tmp;
            struct ir_info *e1, *e2, *e3;
            int aop;

            v1 = get_var(x->child1, st);
            v2 = get_var(x->child2, st);
            v3 = get_var(x->child3, st);
            tmp = make_tmp(st);

            e1 = ir_traverse(x->child1, st, v1, 0, is_rval(n->op, 1, rval));
            e2 = ir_traverse(x->child2, st, v2, 0, is_rval(n->op, 2, rval));
            e3 = ir_traverse(x->child3, st, v3, 0, is_rval(n->op, 3, rval));

            chunk1(res->start, ir_goto(n, e1->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e3->resume));

            chunk1(e1->success, ir_goto(n, e2->start));
            chunk1(e1->failure, ir_goto(n, res->failure));

            chunk1(e2->success, ir_goto(n, e3->start));
            chunk1(e2->failure, ir_goto(n, e1->resume));

            if (n->op == Uop_Sectp)
                aop = Uop_Plus;
            else
                aop = Uop_Minus;
            chunk3(e3->success, 
                   ir_mgop(n, tmp, aop, v2, v3, 1),
                   ir_op(n, target, Uop_Sect, v1, v2, tmp, rval, e3->resume),
                   ir_goto(n, res->success));
            chunk1(e3->failure, ir_goto(n, e2->resume));

            res->uses_stack = (e1->uses_stack || e2->uses_stack || e3->uses_stack);

            break;
        }

        case Uop_Sect: {                  /* section operation x[a:b] */
            struct lnode_3 *x = (struct lnode_3 *)n;
            struct ir_var *v1, *v2, *v3;
            struct ir_info *e1, *e2, *e3;

            v1 = get_var(x->child1, st);
            v2 = get_var(x->child2, st);
            v3 = get_var(x->child3, st);

            e1 = ir_traverse(x->child1, st, v1, 0, is_rval(n->op, 1, rval));
            e2 = ir_traverse(x->child2, st, v2, 0, is_rval(n->op, 1, rval));
            e3 = ir_traverse(x->child3, st, v3, 0, is_rval(n->op, 1, rval));

            chunk1(res->start, ir_goto(n, e1->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e3->resume));

            chunk1(e1->success, ir_goto(n, e2->start));
            chunk1(e1->failure, ir_goto(n, res->failure));

            chunk1(e2->success, ir_goto(n, e3->start));
            chunk1(e2->failure, ir_goto(n, e1->resume));

            chunk2(e3->success, 
                  ir_op(n, target, n->op, v1, v2, v3, rval, e3->resume),
                  ir_goto(n, res->success));
            chunk1(e3->failure, ir_goto(n, e2->resume));

            res->uses_stack = (e1->uses_stack || e2->uses_stack || e3->uses_stack);

            break;
        }

        case Uop_Every: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_stack *expr_st;
            struct ir_info *expr;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            expr_st = branch_stack(res->loop->loop_st);
            res->loop->next_fails_flag = 1;
            expr = ir_traverse(x->child, expr_st, 0, 0, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break, ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk1(expr->success, 
                  ir_goto(n, expr->resume));
            chunk1(expr->failure, 
                  ir_goto(n, res->failure));
            break;
        }

        case Uop_Everydo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_stack *body_expr_st;
            struct ir_info *expr, *body;
            struct mark_pair * body_mk;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            body_expr_st = branch_stack(res->loop->loop_st);
            body_mk = make_mark(body_expr_st);

            res->loop->next_fails_flag = 1;
            expr = ir_traverse(x->child1, body_expr_st, 0, 0, 1);
            res->loop->next_fails_flag = 0;
            body = ir_traverse(x->child2, body_expr_st, 0, 1, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break, ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, body_mk),
                       ir_goto(n, expr->resume));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(expr->success, 
                   OptIns(body->uses_stack || res->loop->has_next, ir_mark(n, body_mk)),
                   ir_goto(n, body->start));
            chunk1(expr->failure, 
                  ir_goto(n, res->failure));

            chunk2(body->success, 
                   OptIns(body->uses_stack, ir_unmark(n, body_mk)),
                   ir_goto(n, expr->resume));
            chunk1(body->failure, 
                  ir_goto(n, expr->resume));

            break;
        }

        case Uop_While: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);
            expr = ir_traverse(x->child, branch_stack(res->loop->loop_st), 0, 1, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break || res->loop->has_next || expr->uses_stack, 
                          ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, res->loop->loop_mk),
                       ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(expr->success, 
                   OptIns(expr->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            chunk1(expr->failure, 
                  ir_goto(n, res->failure));
            break;
        }

        case Uop_Whiledo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *body;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            expr = ir_traverse(x->child1, branch_stack(res->loop->loop_st), 0, 1, 1);
            body = ir_traverse(x->child2, branch_stack(res->loop->loop_st), 0, 1, 1);

            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break || res->loop->has_next || expr->uses_stack || body->uses_stack, 
                          ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, res->loop->loop_mk),
                       ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(expr->success, 
                   OptIns(expr->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, body->start));
            chunk1(expr->failure, 
                  ir_goto(n, res->failure));

            chunk2(body->success, 
                   OptIns(body->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            chunk1(body->failure, 
                  ir_goto(n, expr->start));

            break;
        }

        case Uop_Until: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);
            expr = ir_traverse(x->child, branch_stack(res->loop->loop_st), 0, 1, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break || res->loop->has_next || expr->uses_stack, 
                          ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, res->loop->loop_mk),
                       ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(expr->failure, 
                   OptIns(expr->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            chunk1(expr->success, 
                  ir_goto(n, res->failure));
            break;
        }

        case Uop_Untildo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *body;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            expr = ir_traverse(x->child1, branch_stack(res->loop->loop_st), 0, 1, 1);
            body = ir_traverse(x->child2, branch_stack(res->loop->loop_st), 0, 1, 1);

            pop_loop();

            chunk2(res->start, 
                  OptIns(res->loop->has_break || res->loop->has_next || 
                         expr->uses_stack || body->uses_stack, 
                         ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, res->loop->loop_mk),
                       ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(expr->failure, 
                   OptIns(expr->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, body->start));
            chunk1(expr->success, 
                  ir_goto(n, res->failure));

            chunk2(body->success, 
                   OptIns(body->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            chunk1(body->failure, 
                  ir_goto(n, expr->start));

            break;
        }

        case Uop_Suspenddo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_stack *body_expr_st;
            struct ir_info *expr, *body;
            struct ir_var *v;
            struct mark_pair * body_mk;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            body_expr_st = branch_stack(res->loop->loop_st);
            v = get_var(x->child1, body_expr_st);
            body_mk = make_mark(body_expr_st);

            res->loop->next_fails_flag = 1;
            expr = ir_traverse(x->child1, body_expr_st, v, 0, 0);
            res->loop->next_fails_flag = 0;
            body = ir_traverse(x->child2, body_expr_st, 0, 1, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break, ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, body_mk),
                       ir_goto(n, expr->resume));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk5(expr->success, 
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       ir_suspend(n, v),
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       OptIns(body->uses_stack || res->loop->has_next, ir_mark(n, body_mk)),
                       ir_goto(n, body->start));
            } else {
                chunk3(expr->success, 
                       ir_suspend(n, v),
                       OptIns(body->uses_stack || res->loop->has_next, ir_mark(n, body_mk)),
                       ir_goto(n, body->start));
            }
            chunk1(expr->failure, 
                   ir_goto(n, res->failure));

            chunk2(body->success, 
                   OptIns(body->uses_stack, ir_unmark(n, body_mk)),
                   ir_goto(n, expr->resume));
            chunk1(body->failure, 
                  ir_goto(n, expr->resume));

            break;
        }

        case Uop_Suspend: {
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->failure));

            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk4(res->start, 
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       ir_suspend(n, make_knull()),
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       ir_goto(n, res->failure));
            } else {
                chunk2(res->start, 
                       ir_suspend(n, make_knull()),
                       ir_goto(n, res->failure));
            }
            break;
        }

        case Uop_Suspendexpr: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_stack *expr_st;
            struct ir_info *expr;
            struct ir_var *v;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            expr_st = branch_stack(res->loop->loop_st);
            v = get_var(x->child, expr_st);

            res->loop->next_fails_flag = 1;
            expr = ir_traverse(x->child, expr_st, v, 0, 0);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break, ir_mark(n, res->loop->loop_mk)),
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk4(expr->success, 
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       ir_suspend(n, v),
                       ir_scanswap(n, t->scan->old_subject, t->scan->old_pos),
                       ir_goto(n, expr->resume));
            } else {
                chunk2(expr->success, 
                       ir_suspend(n, v),
                       ir_goto(n, expr->resume));
            }
            chunk1(expr->failure, 
                   ir_goto(n, res->failure));

            break;
        }

        case Uop_Repeat: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *body;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);
            body = ir_traverse(x->child, branch_stack(res->loop->loop_st), 0, 1, 1);
            pop_loop();

            chunk2(res->start, 
                   OptIns(res->loop->has_break || res->loop->has_next || body->uses_stack, 
                          ir_mark(n, res->loop->loop_mk)),
                  ir_goto(n, body->start));
            if (res->loop->has_next)
                chunk2(res->loop->next_chunk, 
                       ir_unmark(n, res->loop->loop_mk),
                       ir_goto(n, body->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, res->loop->continue_tmploc));

            chunk2(body->success, 
                   OptIns(body->uses_stack, ir_unmark(n, res->loop->loop_mk)),
                   ir_goto(n, body->start));
            chunk1(body->failure, 
                  ir_goto(n, body->start));
            break;
        }

        case Uop_Break: {
            if (!loop_stack)
                quit("Break without corresponding loop");

            if (scan_stack != loop_stack->loop->scan_stack) {
                /* A scan is within the loop, and the break is within the scan.  Find the
                 * first scan within the loop, ie the one above loop_stack->loop->scan_stack in the stack */
                struct ir_info *t = scan_stack;
                while (t->scan->next != loop_stack->loop->scan_stack)
                    t = t->scan->next;

                if (loop_stack->loop->bounded) {
                    chunk4(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_scanrestore(n, t->scan->old_subject, 
                                         t->scan->old_pos),
                           ir_move(n, loop_stack->loop->target, make_knull()),
                           ir_goto(n, loop_stack->success));
                } else {
                    chunk5(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_scanrestore(n, t->scan->old_subject, 
                                         t->scan->old_pos),
                           ir_movelabel(n, loop_stack->loop->continue_tmploc, loop_stack->failure),
                           ir_move(n, loop_stack->loop->target, make_knull()),
                           ir_goto(n, loop_stack->success));
                }

            } else {
                if (loop_stack->loop->bounded) {
                    chunk3(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_move(n, loop_stack->loop->target, make_knull()),
                           ir_goto(n, loop_stack->success));
                } else {
                    chunk4(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_movelabel(n, loop_stack->loop->continue_tmploc, loop_stack->failure),
                           ir_move(n, loop_stack->loop->target, make_knull()),
                           ir_goto(n, loop_stack->success));
                }
            }
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            loop_stack->loop->has_break = 1;
            break;
        }

        case Uop_Breakexpr: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *cur_loop, *saved_scan_stack, *expr;
            struct ir_stack *expr_st;

            if (!loop_stack)
                quit("Break without corresponding loop");

            cur_loop = pop_loop();
            saved_scan_stack = scan_stack;
            scan_stack = cur_loop->loop->scan_stack;

            expr_st = branch_stack(cur_loop->loop->loop_st);
            expr = ir_traverse(x->child, expr_st, 
                               cur_loop->loop->target, 
                               bounded && cur_loop->loop->bounded, cur_loop->loop->rval);
            union_stack(cur_loop->loop->st, expr_st);

            /* Don't use push_loop here since x->child may have pushed something on the stack */
            loop_stack = cur_loop;
            scan_stack = saved_scan_stack;

            if (scan_stack != cur_loop->loop->scan_stack) {
                /* A scan is within the loop, and the break is within the scan.  Find the
                 * first scan within the loop, ie the one above cur_loop->loop->scan_stack in the stack */
                struct ir_info *t = scan_stack;
                while (t->scan->next != cur_loop->loop->scan_stack)
                    t = t->scan->next;

                if (cur_loop->loop->bounded) {
                    chunk3(res->start, 
                          ir_unmark(n, cur_loop->loop->loop_mk),
                          ir_scanrestore(n, t->scan->old_subject, 
                                         t->scan->old_pos),
                          ir_goto(n, expr->start));
                } else {
                    chunk4(res->start, 
                          ir_unmark(n, cur_loop->loop->loop_mk),
                          ir_scanrestore(n, t->scan->old_subject, 
                                         t->scan->old_pos),
                          ir_movelabel(n, cur_loop->loop->continue_tmploc, expr->resume),
                          ir_goto(n, expr->start));
                }

            } else {
                if (cur_loop->loop->bounded) {
                    chunk2(res->start, 
                          ir_unmark(n, cur_loop->loop->loop_mk),
                          ir_goto(n, expr->start));
                } else {
                    chunk3(res->start, 
                          ir_unmark(n, cur_loop->loop->loop_mk),
                          ir_movelabel(n, cur_loop->loop->continue_tmploc, expr->resume),
                          ir_goto(n, expr->start));
                }
            }
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            chunk1(expr->success, ir_goto(n, cur_loop->success));
            chunk1(expr->failure, ir_goto(n, cur_loop->failure));
            cur_loop->loop->has_break = 1;
            if (expr->uses_stack)
                cur_loop->uses_stack = 1;
            break;
        }

        case Uop_Next: {                        /* next expression */
            if (!loop_stack)
                quit("Next without corresponding loop");

            if (loop_stack->loop->next_fails_flag) {
                /*
                 * A next within the generator (but not the body) of
                 * an every or suspend loop just fails.
                 */
                chunk1(res->start, ir_goto(n, res->failure));
                if (!bounded)
                    chunk1(res->resume, ir_syserr(n));
            } else {
                if (scan_stack != loop_stack->loop->scan_stack) {
                    /* A scan is within the loop, and the next is within the scan.  Find the
                     * first scan within the loop, ie the one above loop_stack->loop->scan_stack in the stack */
                    struct ir_info *t = scan_stack;
                    while (t->scan->next != loop_stack->loop->scan_stack)
                        t = t->scan->next;
                    chunk2(res->start, 
                           ir_scanrestore(n, t->scan->old_subject, 
                                          t->scan->old_pos),
                           ir_goto(n, loop_stack->loop->next_chunk));
                } else
                    chunk1(res->start, 
                           ir_goto(n, loop_stack->loop->next_chunk));
                if (!bounded)
                    chunk1(res->resume, 
                           ir_syserr(n));
                loop_stack->loop->has_next = 1;
            }
            break;
        }

        case Uop_Link:                          /* link */
        case Uop_Return: {                      /* return */
            struct ir_var *v;

            v = (n->op == Uop_Link ? make_self() : make_knull());

            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk2(res->start, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_return(n, v));
            } else {
                chunk1(res->start, 
                       ir_return(n, v));
            }

            break;
        }

        case Uop_Returnexpr: {                      /* return expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            struct ir_var *v;
            struct ir_stack *tst;

            tst = branch_stack(st);
            v = get_var(x->child, tst);

            expr = ir_traverse(x->child, tst, v, 1, 0);

            chunk1(res->start, 
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            /*
             * Note that there is no point in marking/unmarking expr,
             * since the return instruction will clean up the stack,
             * leaving just the returning P frame at the top.
             */
            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk2(expr->success, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_return(n, v));
                chunk2(expr->failure, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_fail(n));
            } else {
                chunk1(expr->success, 
                       ir_return(n, v));
                chunk1(expr->failure, 
                       ir_fail(n));
            }

            break;
        }

        case Uop_Linkexpr:                           /* link expression */
        case Uop_Succeedexpr: {                      /* succeed expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v;
            struct ir_info *expr;

            v = (n->op == Uop_Linkexpr ? make_self() : make_knull());

            expr = ir_traverse(x->child, branch_stack(st), 0, 1, 0);

            chunk1(res->start, 
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            /*
             * Note that there is no point in marking/unmarking expr,
             * since the return instruction will clean up the stack,
             * leaving just the returning P frame at the top.
             */
            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk2(expr->success, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_return(n, v));
                chunk2(expr->failure, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_fail(n));
            } else {
                chunk1(expr->success, 
                       ir_return(n, v));
                chunk1(expr->failure, 
                       ir_fail(n));
            }

            break;
        }

        case Uop_Alt: {               /* Alternation */
            struct lnode *n1;
            int count, i;
            struct ir_info **info;
            struct ir_stack *expr_st, *tst;
            int tl;

            tl = make_tmploc(st);

            /*
             * We generate code for a tree of Uop_Alts all in one go.  If they
             * were done as binary ops then we would need a tmp label for each
             * Uop_Alt, and resuming the last one would have to igoto over the
             * whole chain of labels.
             * 
             * Firstly, count how many alts are in the tree, whose structure is
             * 
             *               '|'
             *               / \
             *             e1  '|'
             *                 / \
             *                e2 ...
             *                     '|'
             *                     / \
             *                  en-1  en
             *                   
             */
            count = 1;
            n1 = n;
            while (n1->op == Uop_Alt) {
                ++count;
                n1 = ((struct lnode_2 *)n1)->child2;
            }

            info = mb_alloc(&ir_func_mb, count * sizeof(struct ir_info *));
            expr_st = branch_stack(st);

            /* Traverse elements 1..count-1 */
            n1 = n;
            i = 0;
            while (n1->op == Uop_Alt) {
                struct lnode_2 *x = (struct lnode_2 *)n1;
                tst = branch_stack(expr_st);
                info[i] = ir_traverse(x->child1, tst, target, bounded, rval);
                if (info[i]->uses_stack)
                    res->uses_stack = 1;
                union_stack(st, tst);
                ++i;
                n1 = ((struct lnode_2 *)n1)->child2;
            }
            /* Now do the last one (the rightmost node in the diagram above) */
            tst = branch_stack(expr_st);
            info[i] = ir_traverse(n1, tst, target, bounded, rval);
            if (info[i]->uses_stack)
                res->uses_stack = 1;
            union_stack(st, tst);
            
            chunk2(res->start, 
                   OptIns(!bounded, ir_movelabel(n, tl, info[0]->resume)),
                   ir_goto(n, info[0]->start));

            if (!bounded)
                chunk1(res->resume, ir_igoto(n, tl));

            for (i = 0; i < count - 1; ++i) {
                chunk1(info[i]->success, 
                       ir_goto(n, res->success));
                chunk2(info[i]->failure, 
                       OptIns(!bounded, ir_movelabel(n, tl, info[i + 1]->resume)),
                       ir_goto(n, info[i + 1]->start));
            }
            /* Last one, i == count - 1 */
            chunk1(info[i]->success, 
                   ir_goto(n, res->success));
            chunk1(info[i]->failure, 
                   ir_goto(n, res->failure));
            break;
        }

        case Uop_Conj: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *e1, *e2;

            e1 = ir_traverse(x->child1, st, 0, 0, 1);
            e2 = ir_traverse(x->child2, st, target, bounded, rval);
            chunk1(res->start, ir_goto(n, e1->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e2->resume));
            chunk1(e1->success, ir_goto(n, e2->start));
            chunk1(e1->failure, ir_goto(n, res->failure));
            chunk1(e2->success, ir_goto(n, res->success));
            chunk1(e2->failure, ir_goto(n, e1->resume));

            res->uses_stack = e1->uses_stack || e2->uses_stack;
            break;
        }

        case Uop_Field: {                       /* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            struct ir_info *e;
            struct ir_var *t;

            t = get_var(x->child, st);
            e = ir_traverse(x->child, st, t, 0, 1);

            chunk1(res->start, ir_goto(n, e->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e->resume));
            chunk2(e->success, 
                   ir_field(n, target, t, x->ftab_entry),
                   ir_goto(n, res->success));
            chunk1(e->failure, ir_goto(n, res->failure));

            res->uses_stack = e->uses_stack;

            break;
        }

        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            struct ir_info **info;
            struct ir_stack *list_st;
            int need_mark;
            struct mark_pair *mk;

            if (x->n < 2)
                quit("Got slist with < 2 elements");

            list_st = branch_stack(st);
            mk = make_mark(list_st);
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            need_mark = 0;  /* Set to 1 if any of child[0]...[n-2] uses stack */
            for (i = 0; i < x->n - 1; ++i) {
                info[i] = ir_traverse(x->child[i], branch_stack(list_st), 0, 1, 1);
                if (info[i]->uses_stack)
                    need_mark = 1;
            }
            /* i == x->n - 1 */
            info[i] = ir_traverse(x->child[i], st, target, bounded, rval);
            chunk2(res->start, 
                   OptIns(need_mark, ir_mark(n, mk)), 
                   ir_goto(n, info[0]->start));
            if (!bounded) 
                chunk1(res->resume, ir_goto(n, info[i]->resume));

            for (i = 0; i < x->n - 1; ++i) {
                chunk2(info[i]->success,
                       OptIns(info[i]->uses_stack, ir_unmark(n, mk)),
                       ir_goto(n, info[i + 1]->start));
                chunk1(info[i]->failure,
                      ir_goto(n, info[i + 1]->start));
            }
            /* i == x->n - 1 */
            chunk1(info[i]->success, ir_goto(n, res->success));
            chunk1(info[i]->failure, ir_goto(n, res->failure));
            res->uses_stack = info[i]->uses_stack;

            break;
        }

        /* Unary monogenic operators */
        case Uop_Value:		/* unary . operator */
        case Uop_Size:		/* unary * operator */
        case Uop_Refresh:	/* unary ^ operator */
        case Uop_Number:	/* unary + operator */
        case Uop_Compl:		/* unary ~ operator (cset compl) */
        case Uop_Neg: {		/* unary - operator */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v;
            struct ir_info *operand;
            v = get_var(x->child, st);
            operand = ir_traverse(x->child, st, v, bounded, is_rval(n->op, 1, rval));
            chunk1(res->start, ir_goto(n, operand->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, operand->resume));
            /*
             * Optimisation: unary . can be done with the deref
             * instruction, rather than as an operator.  Note that we
             * must have a target; deref with a nil target is a no-op,
             * whilst the . operator will deref its argument (which
             * may give an error), and then throw it away.
             */
            if (n->op == Uop_Value && target)
                chunk2(operand->success,
                       ir_deref(n, target, v),
                       ir_goto(n, res->success));
            else
                chunk2(operand->success,
                       ir_mgop(n, target, n->op, v, 0, rval),
                       ir_goto(n, res->success));
            chunk1(operand->failure, ir_goto(n, res->failure));
            res->uses_stack = operand->uses_stack;
            break;
        }

        case Uop_Nonnull:	/* unary \ operator */
        case Uop_Random:	/* unary ? operator */
        case Uop_Null: {	/* unary / operator */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v;
            struct ir_info *operand;
            v = get_var(x->child, st);
            operand = ir_traverse(x->child, st, v, 0, is_rval(n->op, 1, rval));
            chunk1(res->start, ir_goto(n, operand->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, operand->resume));
            chunk2(operand->success,
                  ir_op(n, target, n->op, v, 0, 0, rval, operand->resume),
                  ir_goto(n, res->success));
            chunk1(operand->failure, ir_goto(n, res->failure));
            res->uses_stack = operand->uses_stack;
            break;
        }

        case Uop_Tabmat:	/* unary = operator */
        case Uop_Bang: {	/* unary ! operator */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v;
            struct ir_info *operand;
            int clo = make_closure(st);
            v = get_var(x->child, st);
            operand = ir_traverse(x->child, st, v, 0, is_rval(n->op, 1, rval));
            chunk1(res->start, ir_goto(n, operand->start));
            if (!bounded) 
                chunk2(res->resume, 
                       ir_resume(n, clo),
                       ir_goto(n, res->success));
            chunk2(operand->success, 
                   ir_opclo(n, clo, target, n->op, v, 0, 0, rval, operand->resume),
                   ir_goto(n, res->success));
            chunk1(operand->failure, ir_goto(n, res->failure));
            res->uses_stack = 1;
            break;
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            struct ir_var *fn, **args;
            struct ir_info *expr, **info;
            int i, arv, clo;
            struct fentry *ftab_entry = 0;

            /*
             * Generate special code for the case N(a1, a2, ....) where N is an integer literal.
             */
            if (x->expr->op == Uop_Const && x->n > 1 && ((struct lnode_const *)x->expr)->con->c_flag == F_IntLit) {
                word w;
                memcpy(&w, ((struct lnode_const *)x->expr)->con->data, sizeof(word));
                w = cvpos_item(w, x->n);
                info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
                for (i = 0; i < x->n - 1; ++i) {
                    if (i + 1 == w)
                        info[i] = ir_traverse(x->child[i], st, target, 0, 0);
                    else
                        info[i] = ir_traverse(x->child[i], st, 0, 0, 1);
                    if (info[i]->uses_stack)
                        res->uses_stack = 1;
                }
                /* i == x->n - 1 */
                if (i + 1 == w)
                    info[i] = ir_traverse(x->child[i], st, target, bounded, rval);
                else
                    info[i] = ir_traverse(x->child[i], st, 0, bounded, 1);
                if (info[i]->uses_stack)
                    res->uses_stack = 1;

                chunk1(res->start, ir_goto(n, info[0]->start));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, info[i]->resume));

                /* First one */
                chunk1(info[0]->success,
                       ir_goto(n, info[1]->start));
                chunk1(info[0]->failure,
                       ir_goto(n, res->failure));

                /* Middle ones */
                for (i = 1; i < x->n - 1; ++i) {
                    chunk1(info[i]->success, ir_goto(n, info[i + 1]->start));
                    chunk1(info[i]->failure, ir_goto(n, info[i - 1]->resume));
                }

                /* Last one, i == x->n - 1 */
                if (w == CvtFail)
                    chunk1(info[i]->success,  ir_goto(n, info[i]->resume));
                else
                    chunk1(info[i]->success, ir_goto(n, res->success));
                chunk1(info[i]->failure, ir_goto(n, info[i - 1]->resume));

                break;
            }

            arv = last_invoke_arg_rval(x);
            clo = make_closure(st);
            args = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_var *));
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            if (x->expr->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->expr;
                fn = get_var(y->child, st);
                for (i = 0; i < x->n; ++i)
                    args[i] = get_var(x->child[i], st);
                expr = ir_traverse(y->child, st, fn, 0, 0);
                ftab_entry = y->ftab_entry;
            } else {
                fn = get_var(x->expr, st);
                for (i = 0; i < x->n; ++i)
                    args[i] = get_var(x->child[i], st);
                expr = ir_traverse(x->expr, st, fn, 0, 0);
            }
            for (i = 0; i < x->n; ++i) 
                info[i] = ir_traverse(x->child[i], st, args[i], 0, arv && (i == x->n - 1));

            chunk1(res->start, ir_goto(n, expr->start));
            chunk1(expr->failure, ir_goto(n, res->failure));

            if (x->n == 0) {
                if (!bounded)
                    chunk2(res->resume,
                           ir_resume(n, clo),
                           ir_goto(n, res->success));
                if (ftab_entry)
                    chunk2(expr->success,
                           ir_invokef(n, clo, target, fn, ftab_entry, x->n, args, rval, expr->resume),
                           ir_goto(n, res->success));
                else
                    chunk2(expr->success,
                           ir_invoke(n, clo, target, fn, x->n, args, rval, expr->resume),
                           ir_goto(n, res->success));

            } else if (x->n == 1) {
                if (!bounded)
                    chunk2(res->resume,
                           ir_resume(n, clo),
                           ir_goto(n, res->success));
                chunk1(expr->success,
                       ir_goto(n, info[0]->start));
                if (ftab_entry)
                    chunk2(info[0]->success,
                           ir_invokef(n, clo, target, fn, ftab_entry, x->n, args, rval, info[0]->resume),
                           ir_goto(n, res->success));
                else
                    chunk2(info[0]->success,
                           ir_invoke(n, clo, target, fn, x->n, args, rval, info[0]->resume),
                           ir_goto(n, res->success));
                chunk1(info[0]->failure,
                       ir_goto(n, expr->resume));
            } else { /* x->n > 1 */
                if (!bounded)
                    chunk2(res->resume,
                           ir_resume(n, clo),
                           ir_goto(n, res->success));
                chunk1(expr->success,
                       ir_goto(n, info[0]->start));

                /* First one */
                chunk1(info[0]->success,
                       ir_goto(n, info[1]->start));
                chunk1(info[0]->failure,
                       ir_goto(n, expr->resume));

                /* Middle ones */
                for (i = 1; i < x->n - 1; ++i) {
                    chunk1(info[i]->success,
                           ir_goto(n, info[i + 1]->start));
                    chunk1(info[i]->failure,
                           ir_goto(n, info[i - 1]->resume));
                }

                /* Last one, i == x->n - 1 */
                if (ftab_entry)
                    chunk2(info[i]->success,
                           ir_invokef(n, clo, target, fn, ftab_entry, x->n, args, rval, info[i]->resume),
                           ir_goto(n, res->success));
                else
                    chunk2(info[i]->success,
                           ir_invoke(n, clo, target, fn, x->n, args, rval, info[i]->resume),
                           ir_goto(n, res->success));
                chunk1(info[i]->failure,
                       ir_goto(n, info[i - 1]->resume));
            }

            res->uses_stack = 1;
            break;
        }

        case Uop_Mutual: {                      /* (e1,...,en) */
            struct lnode_n *x = (struct lnode_n *)n;
            struct ir_info **info;
            int i;

            if (x->n < 2)
                quit("Got mutual with < 2 elements");

            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            for (i = 0; i < x->n - 1; ++i) {
                info[i] = ir_traverse(x->child[i], st, 0, 0, 1);
                if (info[i]->uses_stack)
                    res->uses_stack = 1;
            }
            /* i == x->n - 1 */
            info[i] = ir_traverse(x->child[i], st, target, bounded, rval);
            if (info[i]->uses_stack)
                res->uses_stack = 1;

            chunk1(res->start, ir_goto(n, info[0]->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, info[i]->resume));

            /* First one */
            chunk1(info[0]->success,
                   ir_goto(n, info[1]->start));
            chunk1(info[0]->failure,
                   ir_goto(n, res->failure));

            /* Middle ones */
            for (i = 1; i < x->n - 1; ++i) {
                chunk1(info[i]->success, ir_goto(n, info[i + 1]->start));
                chunk1(info[i]->failure, ir_goto(n, info[i - 1]->resume));
            }

            /* Last one, i == x->n - 1 */
            chunk1(info[i]->success, ir_goto(n, res->success));
            chunk1(info[i]->failure, ir_goto(n, info[i - 1]->resume));

            break;
        }

        case Uop_List: {                        /* list construction */
            struct lnode_n *x = (struct lnode_n *)n;
            struct ir_var **args;
            struct ir_info **info;
            int i;

            args = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_var *));
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));

            for (i = 0; i < x->n; ++i)
                args[i] = get_var(x->child[i], st);

            for (i = 0; i < x->n; ++i) {
                info[i] = ir_traverse(x->child[i], st, args[i], 0, i == x->n - 1);
                if (info[i]->uses_stack)
                    res->uses_stack = 1;
            }

            if (x->n == 0) {
                chunk2(res->start,
                       ir_makelist(n, target, x->n, args),
                       ir_goto(n, res->success));
                chunk1(res->resume,
                       ir_goto(n, res->failure));
            } else if (x->n == 1) {
                chunk1(res->start, ir_goto(n, info[0]->start));
                chunk1(res->resume, ir_goto(n, info[0]->resume));
                chunk2(info[0]->success,
                       ir_makelist(n, target, x->n, args),
                       ir_goto(n, res->success));
                chunk1(info[0]->failure, ir_goto(n, res->failure));
            } else { /* x->n > 1 */
                chunk1(res->start, ir_goto(n, info[0]->start));
                chunk1(res->resume, ir_goto(n, info[x->n - 1]->resume));

                /* First one */
                chunk1(info[0]->success,
                      ir_goto(n, info[1]->start));
                chunk1(info[0]->failure,
                      ir_goto(n, res->failure));

                /* Middle ones */
                for (i = 1; i < x->n - 1; ++i) {
                    chunk1(info[i]->success,
                          ir_goto(n, info[i + 1]->start));
                    chunk1(info[i]->failure,
                          ir_goto(n, info[i - 1]->resume));
                }

                /* Last one, i == x->n - 1 */
                chunk2(info[i]->success,
                       ir_makelist(n, target, x->n, args),
                       ir_goto(n, res->success));
                chunk1(info[i]->failure,
                      ir_goto(n, info[i - 1]->resume));
            }

            break;
        }

        case Uop_If: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct mark_pair *expr_mk;
            struct ir_stack *expr_st, *then_st;
            struct ir_info *expr, *then;

            expr_st = branch_stack(st);
            expr_mk = make_mark(expr_st);

            expr = ir_traverse(x->child1, expr_st, 0, 1, 1);

            then_st = branch_stack(st);
            then = ir_traverse(x->child2, then_st, target, bounded, rval);

            union_stack(st, then_st);

            chunk2(res->start,
                   OptIns(expr->uses_stack, ir_mark(n, expr_mk)),
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, then->resume));
            chunk2(expr->success,
                   OptIns(expr->uses_stack, ir_unmark(n, expr_mk)),
                   ir_goto(n, then->start));
            chunk1(expr->failure,
                  ir_goto(n, res->failure));
            chunk1(then->success, ir_goto(n, res->success));
            chunk1(then->failure, ir_goto(n, res->failure));
            res->uses_stack = then->uses_stack;
            break;
        }

        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            struct mark_pair *expr_mk;
            struct ir_stack *expr_st, *then_st, *else_st;
            struct ir_info *expr, *then, *els;
            int tl;

            tl = make_tmploc(st);
            expr_st = branch_stack(st);
            expr_mk = make_mark(expr_st);
            expr = ir_traverse(x->child1, expr_st, 0, 1, 1);

            then_st = branch_stack(st);
            then = ir_traverse(x->child2, then_st, target, bounded, rval);

            else_st = branch_stack(st);
            els = ir_traverse(x->child3, else_st, target, bounded, rval);

            union_stack(st, then_st);
            union_stack(st, else_st);

            chunk2(res->start,
                   OptIns(expr->uses_stack, ir_mark(n, expr_mk)),
                   ir_goto(n, expr->start));

            chunk3(expr->success,
                   OptIns(expr->uses_stack, ir_unmark(n, expr_mk)),
                   OptIns(!bounded, ir_movelabel(n, tl, then->resume)),
                   ir_goto(n, then->start));
            chunk2(expr->failure,
                   OptIns(!bounded, ir_movelabel(n, tl, els->resume)),
                   ir_goto(n, els->start));
            if (!bounded)
                chunk1(res->resume, ir_igoto(n, tl));

            chunk1(then->success, ir_goto(n, res->success));
            chunk1(then->failure, ir_goto(n, res->failure));
            chunk1(els->success, ir_goto(n, res->success));
            chunk1(els->failure, ir_goto(n, res->failure));

            res->uses_stack = then->uses_stack || els->uses_stack;
            break;
        }

        case Uop_Case:                  /* case expression */
        case Uop_Casedef: {
            struct lnode_case *x = (struct lnode_case *)n;
            struct ir_var *e, **var;
            struct ir_info *expr, *def = 0, **selector, **clause;
            struct ir_stack *case_st, *clause_st, *expr_st;
            int i, tl, xc, need_mark;
            struct mark_pair *mk;

            selector = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            clause = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            var = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_var *));
            tl = make_tmploc(st);

            if (x->use_tcase) {
                xc = get_extra_chunk();

                /* Stack for the expression and selectors */
                case_st = branch_stack(st);
                e = get_var(x->expr, case_st);

                /* The mark is only needed for the expression, not the selectors */
                expr_st = branch_stack(case_st);
                mk = make_mark(expr_st);

                expr = ir_traverse(x->expr, expr_st, e, 1, 1);
                clause_st = branch_stack(st);

                for (i = 0; i < x->n; ++i) {                /* The n non-default cases */
                    struct ir_stack *tst, *sst;
                    sst = branch_stack(case_st);
                    var[i] = get_var(x->selector[i], sst);
                    selector[i] = ir_traverse(x->selector[i], sst, var[i], 0, 1);
                    tst = branch_stack(st);
                    clause[i] = ir_traverse(x->clause[i], tst, target, bounded, rval);
                    union_stack(clause_st, tst);
                    if (clause[i]->uses_stack)
                        res->uses_stack = 1;
                }
                if (n->op == Uop_Casedef) {        /* evaluate default clause */
                    def = ir_traverse(x->def, st, target, bounded, rval);
                    if (def->uses_stack)
                        res->uses_stack = 1;
                }

                union_stack(st, clause_st);

                chunk2(res->start,
                       OptIns(expr->uses_stack, ir_mark(n, mk)),
                       ir_goto(n, expr->start));
                if (!bounded)
                    chunk1(res->resume, ir_igoto(n, tl));

                chunk1(expr->failure,
                       ir_goto(n, res->failure));

                if (x->n == 0) {
                    /* Must have a default clause if no other clauses */
                    chunk3(expr->success,
                           OptIns(expr->uses_stack, ir_unmark(n, mk)),
                           OptIns(!bounded, ir_movelabel(n, tl, def->resume)), 
                           ir_goto(n, def->start));
                } else {
                    if (bounded) {
                        struct ir_tcaseinit *ci;
                        if (def)
                            ci = ir_tcaseinit(n, x->n, def->start);
                        else
                            ci = ir_tcaseinit(n, x->n, res->failure);
                        chunk4(expr->success,
                               OptIns(expr->uses_stack, ir_unmark(n, mk)),
                               ir_enterinit(n, xc), 
                               ci,
                               ir_goto(n, selector[0]->start));

                        for (i = 0; i < x->n; ++i) {
                            chunk2(selector[i]->success,
                                   ir_tcaseinsert(n, ci, var[i], clause[i]->start),
                                   ir_goto(n, selector[i]->resume));

                            if (i < x->n - 1)
                                chunk1(selector[i]->failure,
                                       ir_goto(n, selector[i + 1]->start));
                            else
                                chunk1(selector[i]->failure,
                                       ir_goto(n, xc));

                            chunk1(clause[i]->success,
                                   ir_goto(n, res->success));
                            chunk1(clause[i]->failure,
                                   ir_goto(n, res->failure));
                        }
                        chunk1(xc,
                               ir_tcasechoose(n, ci, e));

                    } else {
                        struct ir_tcaseinit *ci;
                        int *tbl = mb_alloc(&ir_func_mb, x->n * sizeof(int));

                        for (i = 0; i < x->n; ++i) {
                            tbl[i] = get_extra_chunk();
                            chunk2(tbl[i],
                                   ir_movelabel(n, tl, clause[i]->resume),
                                   ir_goto(n, clause[i]->start));
                        }

                        if (def) {
                            int def2 = get_extra_chunk();
                            chunk2(def2,
                                   ir_movelabel(n, tl, def->resume),
                                   ir_goto(n, def->start));
                            ci = ir_tcaseinit(n, x->n, def2);
                        } else
                            ci = ir_tcaseinit(n, x->n, res->failure);

                        chunk4(expr->success,
                               OptIns(expr->uses_stack, ir_unmark(n, mk)),
                               ir_enterinit(n, xc), 
                               ci,
                               ir_goto(n, selector[0]->start));

                        for (i = 0; i < x->n; ++i) {
                            chunk2(selector[i]->success,
                                   ir_tcaseinsert(n, ci, var[i], tbl[i]),
                                   ir_goto(n, selector[i]->resume));

                            if (i < x->n - 1)
                                chunk1(selector[i]->failure,
                                       ir_goto(n, selector[i + 1]->start));
                            else
                                chunk1(selector[i]->failure,
                                       ir_goto(n, xc));

                            chunk1(clause[i]->success,
                                   ir_goto(n, res->success));
                            chunk1(clause[i]->failure,
                                   ir_goto(n, res->failure));
                        }
                        chunk1(xc,
                               ir_tcasechoose(n, ci, e));
                    }
                }
                if (def) {
                    chunk1(def->success,
                           ir_goto(n, res->success));
                    chunk1(def->failure,
                           ir_goto(n, res->failure));
                }
            } else {
                /* Stack for the expression and selectors */
                case_st = branch_stack(st);

                /* Mark used for both expression and selectors */
                mk = make_mark(case_st);
                e = get_var(x->expr, case_st);

                expr_st = branch_stack(case_st);

                expr = ir_traverse(x->expr, expr_st, e, 1, 1);

                /* Set to 1 if the expression or any selector uses stack */
                need_mark = expr->uses_stack;

                clause_st = branch_stack(st);
                for (i = 0; i < x->n; ++i) {                /* The n non-default cases */
                    struct ir_stack *tst, *sst;
                    sst = branch_stack(case_st);
                    var[i] = get_var(x->selector[i], sst);
                    selector[i] = ir_traverse(x->selector[i], sst, var[i], 0, 1);
                    if (selector[i]->uses_stack)
                        need_mark = 1;
                    tst = branch_stack(st);
                    clause[i] = ir_traverse(x->clause[i], tst, target, bounded, rval);
                    union_stack(clause_st, tst);
                    if (clause[i]->uses_stack)
                        res->uses_stack = 1;
                }
                if (n->op == Uop_Casedef) {        /* evaluate default clause */
                    def = ir_traverse(x->def, st, target, bounded, rval);
                    if (def->uses_stack)
                        res->uses_stack = 1;
                }

                union_stack(st, clause_st);

                chunk2(res->start,
                       OptIns(need_mark, ir_mark(n, mk)),
                       ir_goto(n, expr->start));
                if (!bounded)
                    chunk1(res->resume, ir_igoto(n, tl));

                chunk1(expr->failure,
                       ir_goto(n, res->failure));
                if (x->n == 0) {
                    /* Must have a default clause if no other clauses */
                    chunk3(expr->success,
                           OptIns(expr->uses_stack, ir_unmark(n, mk)),
                           OptIns(!bounded, ir_movelabel(n, tl, def->resume)), 
                           ir_goto(n, def->start));
                } else {
                    chunk2(expr->success,
                           OptIns(expr->uses_stack, ir_unmark(n, mk)),
                           ir_goto(n, selector[0]->start));
                    for (i = 0; i < x->n; ++i) {
                        chunk4(selector[i]->success,
                               ir_op(n, 0, Uop_Eqv, e, var[i], 0, 1, selector[i]->resume),
                               OptIns(selector[i]->uses_stack, ir_unmark(n, mk)),
                               OptIns(!bounded, ir_movelabel(n, tl, clause[i]->resume)), 
                               ir_goto(n, clause[i]->start));

                        if (i < x->n - 1)
                            chunk1(selector[i]->failure,
                                   ir_goto(n, selector[i + 1]->start));
                        else if (def)
                            chunk2(selector[i]->failure,
                                   OptIns(!bounded, ir_movelabel(n, tl, def->resume)), 
                                   ir_goto(n, def->start));
                        else
                            chunk1(selector[i]->failure,
                                   ir_goto(n, res->failure));

                        chunk1(clause[i]->success,
                               ir_goto(n, res->success));

                        chunk1(clause[i]->failure,
                               ir_goto(n, res->failure));
                    }
                }
                if (def) {
                    chunk1(def->success,
                           ir_goto(n, res->success));
                    chunk1(def->failure,
                           ir_goto(n, res->failure));
                }
            }
            break;
        }

        case Uop_Rptalt: {                      /* repeated alternation */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;

            if (bounded) {
                expr = ir_traverse(x->child, st, target, bounded, rval);
                chunk1(res->start, ir_goto(n, expr->start));
                chunk1(expr->success, ir_goto(n, res->success));
                chunk1(expr->failure, ir_goto(n, res->failure));
            } else {
                int tl = make_tmploc(st);
                expr = ir_traverse(x->child, st, target, bounded, rval);
                chunk1(res->resume, ir_goto(n, expr->resume));
                chunk2(res->start, 
                       ir_movelabel(n, tl, res->failure),
                       ir_goto(n, expr->start));
                chunk2(expr->success, 
                       ir_movelabel(n, tl, res->start),
                       ir_goto(n, res->success));
                chunk1(expr->failure, ir_igoto(n, tl));
            }

            res->uses_stack = expr->uses_stack;
            break;
        }

        case Uop_Not: {                 /* not expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            struct ir_stack *not_st;
            struct mark_pair *mk;

            not_st = branch_stack(st);
            mk = make_mark(not_st);
            expr = ir_traverse(x->child, not_st, target, 1, 1);

            chunk2(res->start, 
                   OptIns(expr->uses_stack, ir_mark(n, mk)),
                   ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            chunk2(expr->success, 
                   OptIns(expr->uses_stack, ir_unmark(n, mk)),
                   ir_goto(n, res->failure));
            chunk2(expr->failure, 
                   ir_move(n, target, make_knull()),
                   ir_goto(n, res->success));
            break;
        }

        case Uop_Limit: {                       /* limitation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *limit;
            struct ir_var *t;
            struct mark_pair *mk;

            /* Generate nicer code for the common case expr \ 1 */
            if (x->child1->op == Uop_Const &&
                ((struct lnode_const *)x->child1)->con->c_flag == F_IntLit) {
                word w;
                memcpy(&w, ((struct lnode_const *)x->child1)->con->data, sizeof(word));
                if (w == 1) {
                    /* expr \ 1.  In contrast to the general case, treat expr as bounded */
                    mk = make_mark(st);
                    expr = ir_traverse(x->child2, st, target, 1, rval);
                    chunk2(res->start, 
                           OptIns(expr->uses_stack, ir_mark(n, mk)),
                           ir_goto(n, expr->start));
                    chunk2(expr->success, 
                           OptIns(expr->uses_stack, ir_unmark(n, mk)),
                           ir_goto(n, res->success));
                    chunk1(expr->failure, ir_goto(n, res->failure));
                    if (!bounded)
                        chunk1(res->resume, ir_goto(n, res->failure));
                    break;
                }
            }

            /* General case */

            t = make_tmp(st);
            mk = make_mark(st);

            limit = ir_traverse(x->child1, st, t, 0, 1);
            expr = ir_traverse(x->child2, st, target, bounded, rval);

            chunk1(res->start, ir_goto(n, limit->start));
            if (!bounded) {
                int xc = get_extra_chunk();
                chunk3(res->resume, 
                       ir_op(n, 0, Uop_Numgt, t, make_word(1), 0, 1, xc),  /* if t<=1 goto xc */
                       ir_mgop(n, t, Uop_Minus, t, make_word(1), 1),  /* else --t; resume expr */
                       ir_goto(n, expr->resume));
                chunk2(xc, 
                       OptIns(expr->uses_stack, ir_unmark(n, mk)),
                       ir_goto(n, limit->resume));
            }
            chunk1(expr->failure, ir_goto(n, limit->resume));
            chunk1(limit->failure, ir_goto(n, res->failure));
            chunk1(expr->success, ir_goto(n, res->success));
            chunk4(limit->success, 
                   ir_limit(n, t),
                   ir_op(n, 0, Uop_Numgt, t, make_word(0), 0, 1, limit->resume),  /* Check for expr \ 0 */
                   OptIns(!bounded && expr->uses_stack, ir_mark(n, mk)),
                   ir_goto(n, expr->start));

            res->uses_stack = (limit->uses_stack || expr->uses_stack);
            break;
        }

        case Uop_Create: {                      /* create expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            struct ir_stack *tst;
            struct ir_var *t;
            if (!target) {
                chunk1(res->start, ir_goto(n, res->success));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, res->failure));
                break;
            }
            
            /* A coexpression executes in its own fresh stack frame */
            tst = new_stack();
            t = make_tmp(tst);
            expr = ir_traverse(x->child, tst, t, 0, 0);
            union_stack(st, tst);

            chunk2(res->start, 
                   ir_create(n, target, expr->start),
                   ir_goto(n, res->success));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));

            chunk2(expr->success, 
                   ir_coret(n, t),
                   ir_goto(n, expr->resume));
            chunk2(expr->failure, 
                   ir_cofail(n),
                   ir_goto(n, expr->failure));
            break;
        }

        case Uop_Uactivate: {                    /* unary co-expression activation */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            struct ir_var *e;

            e = get_var(x->child, st);
            expr = ir_traverse(x->child, st, e, 0, 1);
            chunk1(res->start, ir_goto(n, expr->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, expr->resume));
            chunk1(expr->failure, ir_goto(n, res->failure));
            chunk2(expr->success, 
                   ir_op(n, target, Uop_Bactivate, make_knull(), e, 0, rval, expr->resume),
                   ir_goto(n, res->success));
            res->uses_stack = expr->uses_stack;
            break;
        }

        case Uop_Fail: {
            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk2(res->start, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_fail(n));
            } else
                chunk1(res->start, ir_fail(n));
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));
            break;
        }

        default:
            quit("ir_traverse: Illegal opcode(%d): %s in file %s\n", n->op, 
                  ucode_op_table[n->op].name, n->loc.file);
    }
    if (Iflag)
        indentf("uses_stack=%d\n", res->uses_stack);
    --traverse_level;
    if (Iflag)
        indentf("}\n");
    return res;
}

void generate_ir()
{
    struct ir_info *init = 0, *body = 0, *end;
    struct lnode *n;
    struct mark_pair *init_mk = 0;

    hi_chunk = -1;
    chunk_id_seq = 1;
    memset(chunks, 0, n_chunks_alloc * sizeof(struct chunk *));
    mb_clear(&ir_func_mb);
    hi_clo = hi_tmp = hi_lab = hi_mark = -1;
    tcaseinit_id_seq = tmp_id_seq = mark_id_seq = 0;

    if (Iflag) {
        fprintf(stderr, "\nGenerating ir tree for ");
        if (curr_lfunc->method)
            fprintf(stderr, "method %s.%s\n", 
                    curr_lfunc->method->class->global->name, curr_lfunc->method->name);
        else
            fprintf(stderr, "procedure %s\n",  curr_lfunc->proc->name);
    }


    if (curr_lfunc->initial->op != Uop_Empty) {
        struct ir_stack *init_st = new_stack();
        init_mk = make_mark(init_st);
        init = ir_traverse(curr_lfunc->initial, init_st, 0, 1, 1);
    }

    if (curr_lfunc->body->op != Uop_Empty)
        body = ir_traverse(curr_lfunc->body, new_stack(), 0, 1, 1);

    end = ir_traverse(curr_lfunc->end, 0, 0, 1, 1);   /* Get the Uop_End */
    n = curr_lfunc->start;
    /* Note there is no point marking the body or a lone init block, since the end
     * block will simply cause failure, popping the whole procedure frame.
     */
    if (init) {
        if (body) {
            chunk3(0, 
                   ir_enterinit(n, body->start), 
                   OptIns(init->uses_stack, ir_mark(n, init_mk)),
                   ir_goto(n, init->start));
            chunk2(init->success, 
                   OptIns(init->uses_stack, ir_unmark(n, init_mk)),
                   ir_goto(n, body->start));
            chunk1(init->failure, ir_goto(n, body->start));
            chunk1(body->success, ir_goto(n, end->start));
            chunk1(body->failure, ir_goto(n, end->start));
        }
        else {
            chunk2(0, ir_enterinit(n, end->start), 
                                  ir_goto(n, init->start));
            chunk1(init->success, ir_goto(n, end->start));
            chunk1(init->failure, ir_goto(n, end->start));
        }
    } else {
        if (body) {
            chunk1(0, ir_goto(n, body->start));
            chunk1(body->success, ir_goto(n, end->start));
            chunk1(body->failure, ir_goto(n, end->start));
        } else
            chunk1(0, ir_goto(n, end->start));
    }

    optimize();
    sanity_check();
    renumber_ir();
    if (Iflag) {
        fprintf(stderr, "** Optimized code for ");
        if (curr_lfunc->method)
            fprintf(stderr, "method %s.%s\n", 
                    curr_lfunc->method->class->global->name, curr_lfunc->method->name);
        else
            fprintf(stderr, "procedure %s\n",  curr_lfunc->proc->name);
        dump_ir();
        fprintf(stderr, "** End of optimized code\n");
    }
}

static void optimize()
{
    int i, mod;
    optimize_goto1(0);
    remove_unseen_chunks();
    chunks[0]->joined_above = 1;
    for (i = 1;; ++i) {
        if (Iflag)
            fprintf(stderr, "Optimization pass %d\n", i);
        mod = 0;
        if (optimize_goto())
            ++mod;
        if (fold_tmps())
            ++mod;
        if (peephole_optimizations())
            ++mod;
        if (mark_check())
            ++mod;
        if (mod <= 1)
            break;
    }
}

static void print_ir_var(struct ir_var *v)
{
    if (!v) {
        fprintf(stderr, "{null}");
        return;
    }

    switch (v->type) {
        case CONST: {
            struct centry *ce = v->con;
            fprintf(stderr, "{const %s len=%d}", f_flag2str(ce->c_flag),ce->length);
            break;
        }
        case WORD: {
            fprintf(stderr, "{word " WordFmt "}", v->w);
            break;
        }
        case KNULL: {
            fprintf(stderr, "{&null}");
            break;
        }
        case KYES: {
            fprintf(stderr, "{&yes}");
            break;
        }
        case LOCAL: {
            struct lentry *le = v->local;
            fprintf(stderr, "{local %s %s}", le->name, f_flag2str(le->l_flag));
            break;
        }
        case GLOBAL: {
            struct gentry *ge = v->global;
            fprintf(stderr, "{global %s %s}", ge->name, f_flag2str(ge->g_flag));
            break;
        }
        case TMP: {
            fprintf(stderr, "{tmp %d (id %d)}", v->index, v->tmp_id);
            break;
        }
        default: {
            fprintf(stderr, "{???}");
            break;
        }
    }
}

static void print_chunk(struct chunk *chunk)
{
    int j;
    indentf("Chunk %d %s (line %d) seen=%d, joined above=%d, below=%d\n", chunk->id, chunk->desc,
            chunk->line, chunk->seen, chunk->joined_above, chunk->joined_below);
    for (j = 0; j < chunk->n_inst; ++j) {
        struct ir *ir = chunk->inst[j];
        switch (ir->op) {
            case Ir_Goto: {
                struct ir_goto *x = (struct ir_goto *)ir;
                indentf("\tIr_Goto %d\n", x->dest);
                break;
            }
            case Ir_IGoto: {
                struct ir_igoto *x = (struct ir_igoto *)ir;
                indentf("\tIr_IGoto %d\n", x->no);
                break;
            }
            case Ir_EnterInit: {
                struct ir_enterinit *x = (struct ir_enterinit *)ir;
                indentf("\tIr_EnterInit %d\n", x->dest);
                break;
            }
            case Ir_Fail: {
                indentf("\tIr_Fail\n");
                break;
            }
            case Ir_Suspend: {
                struct ir_suspend *x = (struct ir_suspend *)ir;
                indentf("\tIr_Suspend ");
                print_ir_var(x->val);
                fputc('\n', stderr);
                break;
            }
            case Ir_Return: {
                struct ir_return *x = (struct ir_return *)ir;
                indentf("\tIr_Return ");
                print_ir_var(x->val);
                fputc('\n', stderr);
                break;
            }
            case Ir_Mark: {
                struct ir_mark *x = (struct ir_mark *)ir;
                indentf("\tIr_Mark %d (id %d)\n", x->no, x->id);
                break;
            }
            case Ir_Unmark: {
                struct ir_unmark *x = (struct ir_unmark *)ir;
                indentf("\tIr_Unmark %d (id %d)\n", x->no, x->id);
                break;
            }
            case Ir_Move: {
                struct ir_move *x = (struct ir_move *)ir;
                indentf("\tIr_Move ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->rhs);
                fputc('\n', stderr);
                break;
            }
            case Ir_Deref: {
                struct ir_deref *x = (struct ir_deref *)ir;
                indentf("\tIr_Deref ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->rhs);
                fputc('\n', stderr);
                break;
            }
            case Ir_MoveLabel: {
                struct ir_movelabel *x = (struct ir_movelabel *)ir;
                indentf("\tIr_MoveLabel %d <- %d\n", x->destno, x->lab);
                break;
            }
            case Ir_ScanSwap: {
                struct ir_scanswap *x = (struct ir_scanswap *)ir;
                indentf("\tIr_ScanSwap tmp_subject=");
                print_ir_var(x->tmp_subject);
                fprintf(stderr, ", tmp_pos=");
                print_ir_var(x->tmp_pos);
                fputc('\n', stderr);
                break;
            }
            case Ir_ScanRestore: {
                struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                indentf("\tIr_ScanRestore tmp_subject=");
                print_ir_var(x->tmp_subject);
                fprintf(stderr, ", tmp_pos=");
                print_ir_var(x->tmp_pos);
                fputc('\n', stderr);
                break;
            }
            case Ir_ScanSave: {
                struct ir_scansave *x = (struct ir_scansave *)ir;
                indentf("\tIr_ScanSave new_subject=");
                print_ir_var(x->new_subject);
                fprintf(stderr, " tmp_subject=");
                print_ir_var(x->tmp_subject);
                fprintf(stderr, ", tmp_pos=");
                print_ir_var(x->tmp_pos);
                fputc('\n', stderr);
                break;
            }
            case Ir_Op: {
                struct ir_op *x = (struct ir_op *)ir;
                indentf("\tIr_Op ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->arg1);
                fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                if (x->arg2) {
                    print_ir_var(x->arg2);
                }
                if (x->arg3) {
                    fprintf(stderr, ", ");
                    print_ir_var(x->arg3);
                }
                fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                break;
            }
            case Ir_MgOp: {
                struct ir_mgop *x = (struct ir_mgop *)ir;
                indentf("\tIr_MgOp ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->arg1);
                fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                if (x->arg2) {
                    print_ir_var(x->arg2);
                }
                fprintf(stderr, ", rval=%d\n", x->rval);
                break;
            }
            case Ir_OpClo: {
                struct ir_opclo *x = (struct ir_opclo *)ir;
                indentf("\tIr_OpClo clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", ");
                print_ir_var(x->arg1);
                fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                if (x->arg2) {
                    print_ir_var(x->arg2);
                }
                if (x->arg3) {
                    fprintf(stderr, ", ");
                    print_ir_var(x->arg3);
                }
                fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                break;
            }
            case Ir_KeyOp: {
                struct ir_keyop *x = (struct ir_keyop *)ir;
                indentf("\tIr_KeyOp ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- keyword=%d rval=%d fail_label=%d\n", 
                        x->keyword, x->rval, x->fail_label);
                break;
            }
            case Ir_KeyClo: {
                struct ir_keyclo *x = (struct ir_keyclo *)ir;
                indentf("\tIr_KeyClo");
                fprintf(stderr, " clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", keyword=%d fail_label=%d\n", 
                        x->keyword, x->fail_label);
                break;
            }
            case Ir_Invoke: {
                struct ir_invoke *x = (struct ir_invoke *)ir;
                int i;
                indentf("\tIr_Invoke");
                fprintf(stderr, " clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", ");
                print_ir_var(x->expr);
                fprintf(stderr, "(");
                for (i = 0; i < x->argc; ++i) {
                    print_ir_var(x->args[i]);
                    if (i < x->argc - 1)
                        fprintf(stderr, ",");
                }
                fprintf(stderr, ")");
                fprintf(stderr, ", fail_label=%d\n", x->fail_label);
                break;
            }
            case Ir_Apply: {
                struct ir_apply *x = (struct ir_apply *)ir;
                indentf("\tIr_Apply clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", ");
                print_ir_var(x->arg1);
                fprintf(stderr, " ! ");
                print_ir_var(x->arg2);
                fprintf(stderr, ", fail_label=%d\n", x->fail_label);
                break;
            }
            case Ir_Invokef: {
                struct ir_invokef *x = (struct ir_invokef *)ir;
                int i;
                indentf("\tIr_Invokef");
                fprintf(stderr, " clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", ");
                print_ir_var(x->expr);
                fprintf(stderr, " . %s(", x->ftab_entry->name);
                for (i = 0; i < x->argc; ++i) {
                    print_ir_var(x->args[i]);
                    if (i < x->argc - 1)
                        fprintf(stderr, ",");
                }
                fprintf(stderr, ")");
                fprintf(stderr, ", fail_label=%d\n", x->fail_label);
                break;
            }
            case Ir_Applyf: {
                struct ir_applyf *x = (struct ir_applyf *)ir;
                indentf("\tIr_Applyf clo=%d, ", x->clo);
                fprintf(stderr, " lhs=");
                print_ir_var(x->lhs);
                fprintf(stderr, ", ");
                print_ir_var(x->arg1);
                fprintf(stderr, " . %s ! ", x->ftab_entry->name);
                print_ir_var(x->arg2);
                fprintf(stderr, ", fail_label=%d\n", x->fail_label);
                break;
            }
            case Ir_Field: {
                struct ir_field *x = (struct ir_field *)ir;
                indentf("\tIr_Field ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->expr);
                fprintf(stderr, " . %s", x->ftab_entry->name);
                fputc('\n', stderr);
                break;
            }
            case Ir_Resume: {
                struct ir_resume *x = (struct ir_resume *)ir;
                indentf("\tIr_Resume");
                fprintf(stderr, ", clo=%d\n", x->clo);
                break;
            }
            case Ir_MakeList: {
                struct ir_makelist *x = (struct ir_makelist *)ir;
                int i;
                indentf("\tIr_MakeList ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- [");
                for (i = 0; i < x->argc; ++i) {
                    print_ir_var(x->args[i]);
                    if (i < x->argc - 1)
                        fprintf(stderr, ",");
                }
                fprintf(stderr, "]\n");
                break;
            }
            case Ir_Create: {
                struct ir_create *x = (struct ir_create *)ir;
                indentf("\tIr_Create ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- create start_label=%d\n", x->start_label);
                break;
            }
            case Ir_Coret: {
                struct ir_coret *x = (struct ir_coret *)ir;
                indentf("\tIr_Coret ");
                print_ir_var(x->value);
                fputc('\n', stderr);
                break;
            }
            case Ir_Cofail: {
                indentf("\tIr_Cofail\n");
                break;
            }
            case Ir_Limit: {
                struct ir_limit *x = (struct ir_limit *)ir;
                indentf("\tIr_Limit ");
                print_ir_var(x->limit);
                fputc('\n', stderr);
                break;
            }
            case Ir_TCaseInit: {
                struct ir_tcaseinit *x = (struct ir_tcaseinit *)ir;
                indentf("\tIr_TCaseInit size=%d def=%d", x->size, x->def);
                fputc('\n', stderr);
                break;
            }
            case Ir_TCaseInsert: {
                struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                indentf("\tIr_TCaseInsert tci=%d", x->tci->id);
                fprintf(stderr, " val=");
                print_ir_var(x->val);
                fprintf(stderr, ", entry=%d\n", x->entry);
                break;
            }
            case Ir_TCaseChoose: {
                struct ir_tcasechoose *x = (struct ir_tcasechoose *)ir;
                indentf("\tIr_TCaseChoose tci=%d", x->tci->id);
                fprintf(stderr, " val=");
                print_ir_var(x->val);
                fputc('\n', stderr);
                break;
            }
            case Ir_SysErr: {
                indentf("\tIr_SysErr\n");
                break;
            }
            default: {
                indentf("\t???\n");
                break;
            }
        }
    }
}

void dump_ir()
{
    int i;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (chunk)
            print_chunk(chunk);
    }
}

static int augop(int n)
{
    switch (n) {
        case Uop_Augactivate:
            return Uop_Bactivate;

        case Uop_Augpower:
            return Uop_Power;

        case Uop_Augcat:
            return Uop_Cat;

        case Uop_Augdiff:
            return Uop_Diff;

        case Uop_Augeqv:
            return Uop_Eqv;

        case Uop_Auginter:
            return Uop_Inter;

        case Uop_Auglconcat:
            return Uop_Lconcat;

        case Uop_Auglexeq:
            return Uop_Lexeq;

        case Uop_Auglexge:
            return Uop_Lexge;

        case Uop_Auglexgt:
            return Uop_Lexgt;

        case Uop_Auglexle:
            return Uop_Lexle;

        case Uop_Auglexlt:
            return Uop_Lexlt;

        case Uop_Auglexne:
            return Uop_Lexne;

        case Uop_Augminus:
            return Uop_Minus;

        case Uop_Augmod:
            return Uop_Mod;

        case Uop_Augneqv:
            return Uop_Neqv;

        case Uop_Augnumeq:
            return Uop_Numeq;

        case Uop_Augnumge:
            return Uop_Numge;

        case Uop_Augnumgt:
            return Uop_Numgt;

        case Uop_Augnumle:
            return Uop_Numle;

        case Uop_Augnumlt:
            return Uop_Numlt;

        case Uop_Augnumne:
            return Uop_Numne;

        case Uop_Augplus:
            return Uop_Plus;

        case Uop_Augdiv:
            return Uop_Div;

        case Uop_Augmult:
            return Uop_Mult;

        case Uop_Augunion:
            return Uop_Union;

        default:
            quit("Invalid opcode to augop");
    }
    /* Not reached */
    return 0;
}

static void unref(struct chunk *chunk)
{
    if (--chunk->seen < 0)
        quit("Unexpected -ve seen count after unref (chunk %d)", chunk->id);
}

static void delete_ir(struct chunk *chunk, int i)
{
    while (i < chunk->n_inst - 1) {
        chunk->inst[i] = chunk->inst[i + 1];
        ++i;
    }
    --chunk->n_inst;
}

/*
 * Change all marks and unmarks with ID old, setting ID to new and
 * index number to no.
 */
static void edit_marks(int old, int new, int no)
{
    int i, j;
    struct chunk *chunk;
    struct ir *ir;
    for (i = 0; i <= hi_chunk; ++i) {
        chunk = chunks[i];
        if (chunk) {
            for (j = 0; j < chunk->n_inst; ++j) {
                ir = chunk->inst[j];
                if (ir->op == Ir_Unmark) {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    if (x->id == old) {
                        x->id = new;
                        x->no = no;
                    }
                }
                else if (ir->op == Ir_Mark) {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    if (x->id == old) {
                        x->id = new;
                        x->no = no;
                    }
                }
            }
        }
    }
}

/*
 * Test if ir is a return or fail, or goes to a one-instruction chunk
 * which is a return or a fail.
 */
static int is_an_exit(struct ir *ir)
{
    struct chunk *chunk;
    if (ir->op == Ir_Return || ir->op == Ir_Fail)
        return 1;
    if (ir->op != Ir_Goto)
        return 0;
    chunk = chunks[((struct ir_goto *)ir)->dest];
    return (chunk->n_inst == 1 &&
            (chunk->inst[0]->op == Ir_Return || chunk->inst[0]->op == Ir_Fail));
}

static void sanity_check()
{
    int i, *a;
    struct chunk *chunk1, *chunk2;

    a = mb_zalloc(&ir_func_mb, sizeof(int) * (hi_chunk + 1));
    a[0] = 1;
    sum_seen(a);

    chunk1 = 0;
    for (i = 0; i <= hi_chunk; ++i) {
        chunk2 = chunks[i];
        if (i == 0) {
            if (!chunk2)
                quit("Chunk 0 null");
            if (!chunk2->joined_above)
                quit("Chunk 0 joined above not set");
        }

        if (chunk2) {
            if (chunk2->id != i)
                quit("Wrong chunk id: %d", i);

            if (chunk2->seen != a[i])
                quit("Seen count wrong chunk %d (should be %d)", i, a[i]);

            if (chunk2->seen == 0 && !chunk2->joined_above)
                quit("Unreachable chunk");

            if (chunk1) {
                if (chunk2->joined_above != chunk1->joined_below)
                    quit("joined flags wrong");
                if (chunk2->n_inst > 0) {
                    int op;
                    op = chunk2->inst[chunk2->n_inst - 1]->op;
                    if (op == Ir_Goto || op == Ir_IGoto || op == Ir_Fail ||
                        op == Ir_Return || op == Ir_TCaseChoose ||
                        op == Ir_SysErr) {
                        if (chunk2->joined_below)
                            quit("joined below flag wrong");
                    } else
                        if (!chunk2->joined_below)
                            quit("joined below flag wrong");
                }
            }
            chunk1 = chunk2;
        } else {
            if (a[i] != 0)
                quit("Null chunk with seen %d", i);
        }
    }
}

static int peephole1()
{
    int i, j1, j2;
    struct chunk *chunk1, *chunk2;
    struct ir *ir1, *ir2;

    ir1 = 0;
    chunk1 = 0;
    j1 = -1;

    for (i = 0; i <= hi_chunk; ++i) {
        chunk2 = chunks[i];
        if (!chunk2)
            continue;

        /*
         * Delete empty chunks.  This keeps things tidy, and makes the
         * trailing goto optimisation below possible (it would need a
         * separate loop otherwise).
         * 
         * It may also allow further optimisations (eg if the chunk
         * after the empty one were fail or return, a goto to it would
         * be noted by is_an_exit above after the deletion).
         */
        if (chunk2->n_inst == 0) {
            int k;
            /*
             * Look for next chunk after the empty one.
             */
            k = i + 1;
            while (k <= hi_chunk && !chunks[k])
                ++k;
            if (k > hi_chunk || !chunk2->joined_below || !chunks[k]->joined_above)
                quit("Strange empty chunk %d", i);

            if (i == 0) {
                /*
                 * chunk2 is the first chunk; this slot must not be
                 * empty, so move k to 0.
                 */
                if (Iflag)
                    fprintf(stderr, "Replace empty chunk 0 with %d\n", k);

                move_chunk(k, 0);
                chunks[0]->seen += chunk2->seen;
                /* The first chunk is always joined above. */
                chunks[0]->joined_above = 1;
            } else {
                /*
                 * chunk2 is not the first chunk, so references to
                 * chunk2 are changed to chunk k, and chunk2 is
                 * deleted.
                 */
                if (Iflag)
                    fprintf(stderr, "Edit references and remove empty chunk %d (to %d)\n", i, k);

                edit_labels(i, k);
                chunks[k]->seen += chunk2->seen;

                /* This may change from 1 to 0, since chunk2 wasn't
                 * necessarily joined_above before. */
                chunks[k]->joined_above = chunk2->joined_above;
                chunks[i] = 0;
            }

            return 1;
        }

        if (i > 0 &&
            chunk2->n_inst == 1 &&
            chunk2->inst[0]->op == Ir_Goto &&
            chunk2->seen > 0) 
        {
            /*
             * This chunk is a lone goto with label references.
             *
             * Redirect the references to the goto's target, ie
             * 
             *           chunk i     goto X
             *           ...
             *           chunk j     ...
             *                       goto i   ->  goto X
             * 
             * If chunk i is not joined above, it can then be deleted.
             * 
             */
            int dest = ((struct ir_goto *)chunk2->inst[0])->dest;
            if (dest != i) {       /* Check for a looping chunk. */
                if (chunk2->joined_below)
                    quit("Odd lone goto");

                if (Iflag)
                    fprintf(stderr, "Edit references to lone goto block %d (to %d)\n", i, dest);
                edit_labels(i, dest);
                chunks[dest]->seen += chunk2->seen;
                if (chunk2->joined_above)
                    chunk2->seen = 0;
                else {
                    if (Iflag)
                        fprintf(stderr, "Delete lone goto block %d\n", i);
                    /* Unref, since we're deleting this goto, which is a reference to dest */
                    unref(chunks[dest]);
                    chunks[i] = 0;
                }
                return 1;
            }
        }

        for (j2 = 0; j2 < chunk2->n_inst; ++j2) {
            ir2 = chunk2->inst[j2];
            if (ir1) {
                /*
                 * Eliminate redundant trailing goto :-
                 * 
                 *    chunk1  : A
                 *              goto chunk2
                 * 
                 *      ... null slots ...
                 * 
                 *    chunk2: B
                 * 
                 * We just delete the redundant trailing goto from
                 * chunk1.
                 * 
                 * We know that there are no empty chunks in between,
                 * since these are removed by an optimization above.
                 * This is important, since if there were an
                 * intermediate empty chunk, the following would leave
                 * its joined_above flag wrong (0 instead of 1).
                 * 
                 */
                if (ir1->op == Ir_Goto &&
                    ((struct ir_goto *)ir1)->dest == i) {
                    if (! (j1 == chunk1->n_inst - 1 ) || chunk1->joined_below || chunk2->joined_above)
                        quit("Odd goto");

                    if (Iflag)
                        fprintf(stderr, "Removing trailing goto from chunk %d\n", chunk1->id);

                    --chunk1->n_inst;
                    unref(chunk2);
                    chunk1->joined_below = chunk2->joined_above = 1;
                    return 1;
                }


                /*
                 * Transform  unmark x   to   unmark y
                 *            unmark y
                 * 
                 *            unmark x   to   return
                 *            return
                 * 
                 *            unmark x   to   fail
                 *            fail
                 */
                if (ir1->op == Ir_Unmark &&
                    (ir2->op == Ir_Unmark || is_an_exit(ir2)))
                {
                    if (Iflag)
                        fprintf(stderr, "Delete redundant unmark from chunk %d\n", chunk1->id);
                    delete_ir(chunk1, j1);
                    return 1;
                }

                /*
                 * Transform  unmark x   to   unmark x
                 *            mark x
                 * 
                 *            unmark x   to   unmark z
                 *            mark y
                 * 
                 * Both instructions must be in the same chunk (so
                 * there is no jump to the second).  If the two
                 * instructions have different numbers then a new one
                 * is allocated.
                 */
                if (ir1->op == Ir_Unmark && ir2->op == Ir_Mark && chunk1 == chunk2)
                {
                    struct ir_unmark *u1 = (struct ir_unmark *)ir1;
                    struct ir_mark *u2 = (struct ir_mark *)ir2;
                    if (Iflag)
                        fprintf(stderr, "Delete redundant mark from chunk %d\n", chunk2->id);
                    if (u1->no == u2->no) {
                        delete_ir(chunk2, j2);
                        edit_marks(u2->id, u1->id, u1->no);
                        return 1;
                    } else {
                        int new = ++hi_mark;
                        delete_ir(chunk2, j2);
                        edit_marks(u1->id, u1->id, new);
                        edit_marks(u2->id, u1->id, new);
                        return 1;
                    }
                }

                /*
                 * Transform  mark x   to   mark z
                 *            mark y
                 * 
                 * Both instructions must be in the same chunk (so
                 * there is no jump to the second).
                 * 
                 * A new mark number, z, is allocated, and all
                 * relevant instructions are merged into that number,
                 * with x's ID.
                 */
                if (ir1->op == Ir_Mark && ir2->op == Ir_Mark && chunk1 == chunk2)
                {
                    struct ir_mark *u1 = (struct ir_mark *)ir1;
                    struct ir_mark *u2 = (struct ir_mark *)ir2;
                    int new = ++hi_mark;
                    if (Iflag)
                        fprintf(stderr, "Delete duplicate mark from chunk %d\n", chunk2->id);
                    delete_ir(chunk2, j2);
                    edit_marks(u1->id, u1->id, new);
                    edit_marks(u2->id, u1->id, new);
                    return 1;
                }
            }
            ir1 = ir2;
            chunk1 = chunk2;
            j1 = j2;
        }
    }
    return 0;
}

static int peephole_optimizations()
{
    int mod;
    mod = 0;
    while (peephole1())
        mod = 1;
    return mod;
}

/*
 * Eliminate unwanted mark instructions, namely those with no matching
 * unmark.  First, a table of id numbers is set up, and each unmark
 * instruction is noted.  A second pass eliminates those mark
 * instructions for which no matching unmark was seen.
 * 
 * We also check for errors: duplicate marks and orphaned unmarks.
 */
static int mark_check()
{
    int i, j, k, mod, *t;
    struct chunk *chunk;
    struct ir *ir;

    t = mb_zalloc(&ir_func_mb, sizeof(int) * mark_id_seq);
    mod = 0;

    for (i = 0; i <= hi_chunk; ++i) {
        chunk = chunks[i];
        if (chunk) {
            for (j = 0; j < chunk->n_inst; ++j) {
                ir = chunk->inst[j];
                if (ir->op == Ir_Unmark) {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    t[x->id] = 1;
                }
            }
        }
    }

    for (i = 0; i <= hi_chunk; ++i) {
        chunk = chunks[i];
        if (chunk) {
            j = 0;
            while (j < chunk->n_inst) {
                ir = chunk->inst[j];
                if (ir->op == Ir_Mark) {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    switch (t[x->id]) {
                        case 0: {
                            /* Mark with no corresponding unmark */
                            if (Iflag)
                                fprintf(stderr, "Delete redundant mark from chunk %d\n", chunk->id);
                            mod = 1;
                            delete_ir(chunk, j);
                            /* Still check for a duplicate mark. */
                            t[x->id] = 2;
                            /* Repeat loop with same j. */
                            continue;
                        }
                        case 1: {
                            /* Mark with a corresponding unmark; set to 2 to note a match and check for
                             * duplicates. */
                            t[x->id] = 2;
                            break;
                        }
                        case 2: {
                            quit("Duplicate mark instruction, id=%d", x->id);
                            break;
                        }
                    }
                }
                ++j;
            }
        }
    }

    /*
     * If any entry in the table is still 1, then it means we've seen
     * an unmark, but no corresponding mark.
     */
    for (k = 0; k < mark_id_seq; ++k) {
        if (t[k] == 1)
            quit("Orphaned unmark instruction detected, id=%d", k);
    }

    return mod;
}

/*
 * Visitor funcs for fold_tmps()
 */

static int search_id, search_count;

static void search_tmp_lhs(struct chunk *chunk, struct ir *ir, struct ir_var *v, int lhs)
{
    if (v->type == TMP && v->tmp_id == search_id && lhs)
        search_count++;
}

static struct ir_var *search_repl;

static void replace_tmp_rhs(struct chunk *chunk, struct ir *ir, struct ir_var *v, int lhs)
{
    if (v->type == TMP && v->tmp_id == search_id) {
        if (Iflag)
            fprintf(stderr, "Replacing tmp usage in chunk %d\n", chunk->id);
        *v = *search_repl;
    }
}

static int tmp_foldable(struct ir_var *v)
{
    if (v->type == TMP)
        return 0;

    if (v->type != GLOBAL)
        return 1;

    return !is_readable_global(v->global);
}

/*
 * Search for ir_vars which are frame temp vars, and can be folded.
 * These will be assigned to once only, with a move instruction.
 */
static int fold_tmps()
{
    int i, j, mod;
    struct chunk *chunk;
    struct ir *ir;
    mod = 0;
    for (i = 0; i <= hi_chunk; ++i) {
        chunk = chunks[i];
        if (chunk) {
            for (j = 0; j < chunk->n_inst; ++j) {
                ir = chunk->inst[j];
                if (ir->op == Ir_Move) {
                    struct ir_move *x = (struct ir_move *)ir;
                    /*
                     * Any move with a temp on the lhs and not a temp
                     * on the rhs (in fact tmp <- tmp never seems to
                     * arise anyway).
                     */
                    if (x->lhs->type == TMP && tmp_foldable(x->rhs)) {
                        /*
                         * Now search for how often this lhs appears
                         * as a lhs anywhere.
                         */
                        search_id = x->lhs->tmp_id;
                        search_count = 0;
                        visit_vars(search_tmp_lhs);
                        if (search_count == 0)
                            quit("Couldn't find tmp_id lhs");
                        if (search_count == 1) {
                            /*
                             * The lhs count is one (ie this move
                             * instruction).  So the temporary can be
                             * replaced with this instruction's rhs
                             * wherever it is used.
                             */
                            search_repl = x->rhs;
                            if (Iflag) {
                                fprintf(stderr, "Delete unwanted tmp (id %d) in chunk %d with ", search_id, i);
                                print_ir_var(search_repl);
                                fputc('\n', stderr);
                            }
                            delete_ir(chunk, j);
                            visit_vars(replace_tmp_rhs);
                            /* Decrement j so we see the next instruction after deleting this one. */
                            --j;
                            mod = 1;
                        }
                    }
                }
            }
        }
    }
    return mod;
}

/*
 * Visitor function for ir_vars.
 */
#undef CHECK
#define CHECK(a, b) if (a) v(chunk, ir, a, b)

static void visit_vars(visit_vars_func v)
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_Mark:
                case Ir_Unmark:
                case Ir_IGoto:
                case Ir_Goto:
                case Ir_SysErr:
                case Ir_EnterInit:
                case Ir_Fail:
                case Ir_Cofail:
                case Ir_TCaseInit:
                case Ir_MoveLabel:
                case Ir_Resume:
                    break;

                case Ir_Suspend: {
                    struct ir_suspend *x = (struct ir_suspend *)ir;
                    CHECK(x->val, 0);
                    break;
                }
                case Ir_Return: {
                    struct ir_return *x = (struct ir_return *)ir;
                    CHECK(x->val, 0);
                    break;
                }
                case Ir_Move: {
                    struct ir_move *x = (struct ir_move *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->rhs, 0);
                    break;
                }
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->rhs, 0);
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->arg1, 0);
                    CHECK(x->arg2, 0);
                    CHECK(x->arg3, 0);
                    break;
                }
                case Ir_MgOp: {
                    struct ir_mgop *x = (struct ir_mgop *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->arg1, 0);
                    CHECK(x->arg2, 0);
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->arg1, 0);
                    CHECK(x->arg2, 0);
                    CHECK(x->arg3, 0);
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    CHECK(x->lhs, 1);
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    CHECK(x->lhs, 1);
                    break;
                }
                case Ir_ScanSwap: {
                    struct ir_scanswap *x = (struct ir_scanswap *)ir;
                    CHECK(x->tmp_subject, 1);
                    CHECK(x->tmp_pos, 1);
                    break;
                }
                case Ir_ScanSave: {
                    struct ir_scansave *x = (struct ir_scansave *)ir;
                    CHECK(x->new_subject, 1);
                    CHECK(x->tmp_subject, 1);
                    CHECK(x->tmp_pos, 1);
                    break;
                }
                case Ir_ScanRestore: {
                    struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                    CHECK(x->tmp_subject, 0);
                    CHECK(x->tmp_pos, 0);
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    CHECK(x->lhs, 1);
                    CHECK(x->expr, 0);
                    for (i = 0; i < x->argc; ++i)
                        CHECK(x->args[i], 0);
                    break;
                }
                case Ir_Apply: {
                    struct ir_apply *x = (struct ir_apply *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->arg1, 0);
                    CHECK(x->arg2, 0);
                    break;
                }
                case Ir_Invokef: {
                    struct ir_invokef *x = (struct ir_invokef *)ir;
                    int i;
                    CHECK(x->lhs, 1);
                    CHECK(x->expr, 0);
                    for (i = 0; i < x->argc; ++i)
                        CHECK(x->args[i], 0);
                    break;
                }
                case Ir_Applyf: {
                    struct ir_applyf *x = (struct ir_applyf *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->arg1, 0);
                    CHECK(x->arg2, 0);
                    break;
                }
                case Ir_Field: {
                    struct ir_field *x = (struct ir_field *)ir;
                    CHECK(x->lhs, 1);
                    CHECK(x->expr, 0);
                    break;
                }
                case Ir_MakeList: {
                    struct ir_makelist *x = (struct ir_makelist *)ir;
                    int i;
                    CHECK(x->lhs, 1);
                    for (i = 0; i < x->argc; ++i)
                        CHECK(x->args[i], 0);
                    break;
                }
                case Ir_Create: {
                    struct ir_create *x = (struct ir_create *)ir;
                    CHECK(x->lhs, 1);
                    break;
                }
                case Ir_Coret: {
                    struct ir_coret *x = (struct ir_coret *)ir;
                    CHECK(x->value, 0);
                    break;
                }
                case Ir_Limit: {
                    struct ir_limit *x = (struct ir_limit *)ir;
                    CHECK(x->limit, 1);
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    CHECK(x->val, 0);
                    break;
                }
                case Ir_TCaseChoose: {
                    struct ir_tcasechoose *x = (struct ir_tcasechoose *)ir;
                    CHECK(x->val, 0);
                    break;
                }

                default: {
                    quit("visit_vars: Illegal ir opcode(%d)", ir->op);
                    break;
                }
            }
        }
    }
}

static void remove_unseen_chunks()
{
    int i;
    /* Eliminate unseen ones */
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (chunk && !chunk->seen) {
            if (Iflag)
                fprintf(stderr, "Eliminating untraversed chunk %d (line %d)\n", i, chunk->line);
            chunks[i] = 0;
        }
    }
}

static int optimize_goto()
{
    int i, j, mod;
    struct chunk *chunk, *other;

    mod = 0;
    /* Merge chunks where possible */
    i = 0;
    while (i <= hi_chunk) {
        chunk = chunks[i];
        /*
         * If we have
         *    chunk i: A
         *             goto j
         *    ...
         *    chunk j: B
         *             T
         * and j is movable and only referenced once (by chunk i), delete chunk j and 
         * transform chunk i to :-
         *    chunk i: A
         *             B
         *             T
         * and then repeat the loop for chunk i again.
         */
        if (chunk &&
            chunk->n_inst > 0 && 
            chunk->inst[chunk->n_inst - 1]->op == Ir_Goto &&
            (other = chunks[j = ((struct ir_goto *)(chunk->inst[chunk->n_inst - 1]))->dest]) &&
            other->seen == 1 &&
            i != j &&
            !other->joined_above && !other->joined_below &&
            other->n_inst > 0)
        {
            struct chunk *new;
            if (Iflag)
                fprintf(stderr, "Merge chunk %d into %d\n", j, i);
            if (chunk->joined_below)
                quit("Unexpected joined_below");
            new = mb_alloc(&ir_func_mb, sizeof(struct chunk) + 
                           (chunk->n_inst + other->n_inst - 2) * sizeof(struct ir *));
            new->id = chunk->id;
            new->desc = chunk->desc;
            new->line = chunk->line;
            new->n_inst = chunk->n_inst - 1 + other->n_inst;
            new->seen = chunk->seen;
            new->joined_above = chunk->joined_above;
            new->joined_below = 0;  /* Since other isn't joined below */
            new->circle = new->pc = new->refs = 0;
            memcpy(new->inst, chunk->inst, (chunk->n_inst - 1) * sizeof(struct ir *));
            memcpy(new->inst + chunk->n_inst - 1, other->inst, other->n_inst * sizeof(struct ir *));
            chunks[j] = 0;
            chunks[i] = new;
            mod = 1;
        } else
            ++i;
    }

    /* Move chunks to eliminate gotos */
    for (i = 0; i <= hi_chunk; ++i) {
        chunk = chunks[i];
        /*
         * Look for :-
         *    chunk i: A
         *             goto j
         *    ...
         *    chunk j: B
         *             T
         * 
         *  With j not joined above.  Unlike the previous
         *  optimisation, we don't mind if there are other references
         *  to chunk j elsewhere.
         */
        if (chunk &&
            chunk->n_inst > 0 && 
            chunk->inst[chunk->n_inst - 1]->op == Ir_Goto &&
            (other = chunks[j = ((struct ir_goto *)(chunk->inst[chunk->n_inst - 1]))->dest]) &&
            i != j &&
            !other->joined_above)
        {
            /*
             * Now try one of two moves.  Firstly, if chunk j is
             * movable, and slot i+1 is free, move j to i+1 :-
             * 
             *    chunk   i: A
             *    chunk i+1: B
             *               T
             *    ...
             *    chunk j:   deleted
             * 
             * OR, if chunk i is movable, and j-1 is free, move i to
             * j-1 :-
             * 
             *    chunk i:   deleted
             *    ...
             *    chunk j-1: A
             *    chunk   j: B
             *               T
             * 
             * After the move both blocks are joined.
             */
            if (chunk->joined_below)
                quit("Unexpected joined_below");

            /*
             * Now !other->joined_above && !chunk->joined_below.
             */

            if (!other->joined_below && i < hi_chunk && !chunks[i + 1]) {
                if (Iflag)
                    fprintf(stderr, "Move chunk %d to %d\n", j, i + 1);
                move_chunk(j, i + 1);
                --chunk->n_inst;                   /* Remove the trailing goto */
                other->joined_above = chunk->joined_below = 1;   /* Join both blocks */
                unref(other);
                mod = 1;
            } else if (!chunk->joined_above && j > 0 && !chunks[j - 1]) {
                if (Iflag)
                    fprintf(stderr, "Move chunk %d to %d\n", i, j - 1);
                move_chunk(i, j - 1);
                --chunk->n_inst;
                other->joined_above = chunk->joined_below = 1;
                unref(other);
                mod = 1;
            }
        }
    }

    return mod;
}

static void optimize_goto_chain(int *lab)
{
    static int marker = 0;
    struct chunk *chunk;
    int start = *lab;
    ++marker;
    while (1) {
        if (*lab < 0)
            quit("Negative label");
        chunk = chunks[*lab];
        if (!chunk || chunk->n_inst == 0)
            quit("Optimize goto chain dead end at chunk %d, start was %d", *lab, start);
        if (chunk->inst[0]->op != Ir_Goto || chunk->circle == marker)
            break;
        *lab = ((struct ir_goto *)chunk->inst[0])->dest;
        chunk->circle = marker;        
    }
}

static void optimize_goto1(int i)
{
    int j;
    struct chunk *chunk;
    chunk = chunks[i];
    if (!chunk)
        return;
    if (chunk->seen) {
        ++chunk->seen;
        return;
    }
    chunk->seen = 1;
    for (j = 0; j < chunk->n_inst; ++j) {
        struct ir *ir = chunk->inst[j];
        switch (ir->op) {
            case Ir_Goto: {
                struct ir_goto *x = (struct ir_goto *)ir;
                optimize_goto_chain(&x->dest);
                optimize_goto1(x->dest);
                break;
            }
            case Ir_EnterInit: {
                struct ir_enterinit *x = (struct ir_enterinit *)ir;
                optimize_goto_chain(&x->dest);
                optimize_goto1(x->dest);
                break;
            }
            case Ir_MoveLabel: {
                struct ir_movelabel *x = (struct ir_movelabel *)ir;
                optimize_goto_chain(&x->lab);
                optimize_goto1(x->lab);
                break;
            }
            case Ir_Op: {
                struct ir_op *x = (struct ir_op *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_OpClo: {
                struct ir_opclo *x = (struct ir_opclo *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_KeyOp: {
                struct ir_keyop *x = (struct ir_keyop *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_KeyClo: {
                struct ir_keyclo *x = (struct ir_keyclo *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_Invoke: {
                struct ir_invoke *x = (struct ir_invoke *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_Apply: {
                struct ir_apply *x = (struct ir_apply *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_Invokef: {
                struct ir_invokef *x = (struct ir_invokef *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_Applyf: {
                struct ir_applyf *x = (struct ir_applyf *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_Create: {
                struct ir_create *x = (struct ir_create *)ir;
                optimize_goto_chain(&x->start_label);
                optimize_goto1(x->start_label);
                break;
            }
            case Ir_TCaseInit: {
                struct ir_tcaseinit *x = (struct ir_tcaseinit *)ir;
                optimize_goto_chain(&x->def);
                optimize_goto1(x->def);
                break;
            }
            case Ir_TCaseInsert: {
                struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                optimize_goto_chain(&x->entry);
                optimize_goto1(x->entry);
                break;
            }
        }
    }
}

int n_clo, n_tmp, n_lab, n_mark;
static int *m_clo, *m_tmp, *m_lab, *m_mark;

static void renumber_lab(int *x)
{
    if (m_lab[*x] == -1)
        m_lab[*x] = n_lab++;
    *x = m_lab[*x];
}

static void renumber_clo(int *x)
{
    if (m_clo[*x] == -1)
        m_clo[*x] = n_clo++;
    *x = m_clo[*x];
}

static void renumber_tmp(int *x)
{
    if (m_tmp[*x] == -1)
        m_tmp[*x] = n_tmp++;
    *x = m_tmp[*x];
}

static void renumber_mark(int *x)
{
    if (m_mark[*x] == -1)
        m_mark[*x] = n_mark++;
    *x = m_mark[*x];
}

static void renumber_var(struct ir_var *v)
{
    if (!v || v->renumbered)
        return;
    v->renumbered = 1;
    if (v->type == TMP)
        renumber_tmp(&v->index);
}

static void renumber_ir()
{
    int i, j;

    n_clo = n_tmp = n_lab = n_mark = 0;
    m_clo = mb_alloc(&ir_func_mb, sizeof(int) * (hi_clo + 1));
    memset(m_clo, -1, sizeof(int) * (hi_clo + 1));

    m_tmp = mb_alloc(&ir_func_mb, sizeof(int) * (hi_tmp + 1));
    memset(m_tmp, -1, sizeof(int) * (hi_tmp + 1));

    m_lab = mb_alloc(&ir_func_mb, sizeof(int) * (hi_lab + 1));
    memset(m_lab, -1, sizeof(int) * (hi_lab + 1));

    m_mark = mb_alloc(&ir_func_mb, sizeof(int) * (hi_mark + 1));
    memset(m_mark, -1, sizeof(int) * (hi_mark + 1));

    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_IGoto: {
                    struct ir_igoto *x = (struct ir_igoto *)ir;
                    renumber_lab(&x->no);
                    break;
                }

                case Ir_Goto:
                case Ir_SysErr:
                case Ir_EnterInit:
                case Ir_Fail:
                case Ir_Cofail:
                case Ir_TCaseInit:
                    break;

                case Ir_Mark: {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    renumber_mark(&x->no);
                    break;
                }
                case Ir_Unmark: {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    renumber_mark(&x->no);
                    break;
                }
                case Ir_Suspend: {
                    struct ir_suspend *x = (struct ir_suspend *)ir;
                    renumber_var(x->val);
                    break;
                }
                case Ir_Return: {
                    struct ir_return *x = (struct ir_return *)ir;
                    renumber_var(x->val);
                    break;
                }
                case Ir_Move: {
                    struct ir_move *x = (struct ir_move *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->rhs);
                    break;
                }
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->rhs);
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    renumber_lab(&x->destno);
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    renumber_var(x->arg3);
                    break;
                }
                case Ir_MgOp: {
                    struct ir_mgop *x = (struct ir_mgop *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    renumber_var(x->arg3);
                    renumber_clo(&x->clo);
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    renumber_var(x->lhs);
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    renumber_clo(&x->clo);
                    renumber_var(x->lhs);
                    break;
                }
                case Ir_ScanSwap: {
                    struct ir_scanswap *x = (struct ir_scanswap *)ir;
                    renumber_var(x->tmp_subject);
                    renumber_var(x->tmp_pos);
                    break;
                }
                case Ir_ScanSave: {
                    struct ir_scansave *x = (struct ir_scansave *)ir;
                    renumber_var(x->new_subject);
                    renumber_var(x->tmp_subject);
                    renumber_var(x->tmp_pos);
                    break;
                }
                case Ir_ScanRestore: {
                    struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                    renumber_var(x->tmp_subject);
                    renumber_var(x->tmp_pos);
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    renumber_clo(&x->clo);
                    renumber_var(x->lhs);
                    renumber_var(x->expr);
                    for (i = 0; i < x->argc; ++i)
                        renumber_var(x->args[i]);
                    break;
                }
                case Ir_Apply: {
                    struct ir_apply *x = (struct ir_apply *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    renumber_clo(&x->clo);
                    break;
                }
                case Ir_Invokef: {
                    struct ir_invokef *x = (struct ir_invokef *)ir;
                    int i;
                    renumber_clo(&x->clo);
                    renumber_var(x->lhs);
                    renumber_var(x->expr);
                    for (i = 0; i < x->argc; ++i)
                        renumber_var(x->args[i]);
                    break;
                }
                case Ir_Applyf: {
                    struct ir_applyf *x = (struct ir_applyf *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    renumber_clo(&x->clo);
                    break;
                }
                case Ir_Field: {
                    struct ir_field *x = (struct ir_field *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->expr);
                    break;
                }
                case Ir_Resume: {
                    struct ir_resume *x = (struct ir_resume *)ir;
                    renumber_clo(&x->clo);
                    break;
                }
                case Ir_MakeList: {
                    struct ir_makelist *x = (struct ir_makelist *)ir;
                    int i;
                    renumber_var(x->lhs);
                    for (i = 0; i < x->argc; ++i)
                        renumber_var(x->args[i]);
                    break;
                }
                case Ir_Create: {
                    struct ir_create *x = (struct ir_create *)ir;
                    renumber_var(x->lhs);
                    break;
                }
                case Ir_Coret: {
                    struct ir_coret *x = (struct ir_coret *)ir;
                    renumber_var(x->value);
                    break;
                }
                case Ir_Limit: {
                    struct ir_limit *x = (struct ir_limit *)ir;
                    renumber_var(x->limit);
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    renumber_var(x->val);
                    break;
                }
                case Ir_TCaseChoose: {
                    struct ir_tcasechoose *x = (struct ir_tcasechoose *)ir;
                    renumber_var(x->val);
                    break;
                }

                default: {
                    quit("renumber: Illegal ir opcode(%d)", ir->op);
                    break;
                }
            }
        }
    }
}

/*
 * Check whether the given node n might generate a variable which
 * might cause an assign or swap to fail.  The second parameter
 * indicates whether we are considering the swap case, which is more
 * stringent.  For assign, we just need to decide whether &pos can be
 * produced as a variable.  For swap we also need to exclude any
 * subscript variables, since overlapping strings can cause a swap to
 * fail (see oasgn.r).
 * 
 * Returns 1 if n may be failure-inducing, 0 if not.  Exotic cases
 * aren't worth checking, so 1 is returned for many cases which aren't
 * in fact failure-inducing.
 */
static int asgn_may_fail(struct lnode *n, int swap)
{
    switch (n->op) {
        case Uop_Keyword: {
            int k = ((struct lnode_keyword *)n)->num;
            return k == K_POS;
        }

        case Uop_Empty:
        case Uop_Local: 
        case Uop_Global:
        case Uop_Const: 
        case Uop_Field:
            return 0;

        case Uop_Bang:
        case Uop_Random:
        case Uop_Subsc:
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
            return swap;

        case Uop_Nonnull:
        case Uop_Null: {	
            struct lnode_1 *x = (struct lnode_1 *)n;
            return asgn_may_fail(x->child, swap);
        }

        case Uop_Alt: {               /* Alternation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            return asgn_may_fail(x->child1, swap) || asgn_may_fail(x->child2, swap);
        }

        default:
            return 1;
    }
}

/*
 * Change all uses of label old to new.
 */

#undef CHECK
#define CHECK(x) if (x == old) x = new;
static void edit_labels(int old, int new)
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_Goto: {
                    struct ir_goto *x = (struct ir_goto *)ir;
                    CHECK(x->dest);
                    break;
                }
                case Ir_EnterInit: {
                    struct ir_enterinit *x = (struct ir_enterinit *)ir;
                    CHECK(x->dest);
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    CHECK(x->lab);
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Apply: {
                    struct ir_apply *x = (struct ir_apply *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Invokef: {
                    struct ir_invokef *x = (struct ir_invokef *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Applyf: {
                    struct ir_applyf *x = (struct ir_applyf *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Create: {
                    struct ir_create *x = (struct ir_create *)ir;
                    CHECK(x->start_label);
                    break;
                }
                case Ir_TCaseInit: {
                    struct ir_tcaseinit *x = (struct ir_tcaseinit *)ir;
                    CHECK(x->def);
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    CHECK(x->entry);
                    break;
                }
            }
        }
    }
}

static void move_chunk(int old, int new)
{
    edit_labels(old, new);
    chunks[new] = chunks[old];
    chunks[new]->id = new;
    chunks[old] = 0;
}

/*
 * Calculate whether this invocation is one in which the last argument
 * may have rval=1 set.
 */
static int last_invoke_arg_rval(struct lnode_invoke *x)
{
    struct lnode_global *y;
    struct lnode *n;

    n = x->expr;
    if (n->op == Uop_Field) {
        struct lnode_field *x = (struct lnode_field *)n;
        struct lclass_field_ref *ref;

        if (!get_class_field_ref(x, 0, &ref))
            return 0;

        if ((ref->field->flag & (M_Static | M_Method | M_Removed | M_Optional | M_Abstract | M_Native)) != (M_Static | M_Method))
            return 0;

        /* Static method (with body) */
        return 1;
    }

    if (n->op != Uop_Global)
        return 0;
    y = (struct lnode_global *)n;

    /* Constructor invocation */
    if (y->global->class)
        return 1;

    /* Builtin function, not using underef. */
    if (y->global->g_flag & F_Builtin) {
        if (strcmp(y->global->name, "coact") == 0 ||
            strcmp(y->global->name, "back") == 0)
            return 0;
        return 1;
    }

    /* User procedure */
    if (y->global->g_flag & F_Proc)
        return 1;

    return 0;
}

#undef CHECK
#define CHECK(x) res[x]++;
static void sum_seen(int *res)
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_Goto: {
                    struct ir_goto *x = (struct ir_goto *)ir;
                    CHECK(x->dest);
                    break;
                }
                case Ir_EnterInit: {
                    struct ir_enterinit *x = (struct ir_enterinit *)ir;
                    CHECK(x->dest);
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    CHECK(x->lab);
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Apply: {
                    struct ir_apply *x = (struct ir_apply *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Invokef: {
                    struct ir_invokef *x = (struct ir_invokef *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Applyf: {
                    struct ir_applyf *x = (struct ir_applyf *)ir;
                    CHECK(x->fail_label);
                    break;
                }
                case Ir_Create: {
                    struct ir_create *x = (struct ir_create *)ir;
                    CHECK(x->start_label);
                    break;
                }
                case Ir_TCaseInit: {
                    struct ir_tcaseinit *x = (struct ir_tcaseinit *)ir;
                    CHECK(x->def);
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    CHECK(x->entry);
                    break;
                }
            }
        }
    }
}
