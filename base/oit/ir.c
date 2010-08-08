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
#include "membuff.h"

static int n_chunks_alloc;
static int chunk_id_seq;
struct chunk **chunks;
int hi_chunk;
static int hi_clo, hi_tmp, hi_lab, hi_mark;

static struct ir_info *scan_stack;
static struct ir_info *loop_stack;

static int augop(int n);
static void print_ir_var(struct ir_var *v);
static void optimize_goto(void);
static void optimize_goto1(int i);
static void renumber_ir(void);
static int get_extra_chunk(void);
static struct ir_var *make_tmp(struct ir_stack *st);
static int make_tmploc(struct ir_stack *st);
static int make_mark(struct ir_stack *st);
static void init_scan(struct ir_info *info, struct ir_stack *st);
static void print_chunk(struct chunk *chunk);

static int traverse_level;

struct membuff ir_func_mb = {"Per func IR membuff", 64000, 0,0,0 };
#define IRAlloc(type)   mb_alloc(&ir_func_mb, sizeof(type))

#define chunk1(lab, I1) chunk(__LINE__, Lit(lab), lab, 1, I1)
#define chunk2(lab, I1, I2) chunk(__LINE__, Lit(lab), lab, 2, I1, I2)
#define chunk3(lab, I1, I2, I3) chunk(__LINE__, Lit(lab), lab, 3, I1, I2, I3)
#define chunk4(lab, I1, I2, I3, I4) chunk(__LINE__, Lit(lab), lab, 4, I1, I2, I3, I4)
#define chunk5(lab, I1, I2, I3, I4, I5) chunk(__LINE__, Lit(lab), lab, 5, I1, I2, I3, I4, I5)
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
    struct ir_stack *res = IRAlloc(struct ir_stack);
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
    struct loop_info *l = IRAlloc(struct loop_info);
    info->loop = l;
    if (bounded)
        l->continue_tmploc = -1;
    else
        l->continue_tmploc = make_tmploc(st);
    l->next_chunk = get_extra_chunk();
    l->loop_st = branch_stack(st);
    l->loop_mk = make_mark(l->loop_st);
    l->st = st;
    l->target = target;
    l->bounded = bounded;
    l->rval = rval;
    l->scan_stack = scan_stack;
}

static void init_scan(struct ir_info *info, struct ir_stack *st)
{
    struct scan_info *l = IRAlloc(struct scan_info);
    info->scan = l;
    l->old_subject = make_tmp(st);
    l->old_pos = make_tmp(st);
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
    va_start(argp, n);
    chunk->n_inst = 0;
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
        quit("empty chunk allocated from line %d", line);
    switch (chunk->inst[chunk->n_inst - 1]->op) {
        case Ir_Goto:
        case Ir_IGoto:
        case Ir_Fail:
        case Ir_Return:
        case Ir_SysErr:
            break;
        default:
            quit("invalid last instruction for chunk allocated from line %d", line);
    }
    if (Iflag)
        print_chunk(chunk);
    return chunk;
}

static struct ir_info *ir_info(struct lnode *node)
{
    struct ir_info *res = IRAlloc(struct ir_info);
    res->start = chunk_id_seq++;
    res->success = chunk_id_seq++;
    res->resume = chunk_id_seq++;
    res->failure = chunk_id_seq++;
    res->node = node;
    return res;
}

static int get_extra_chunk()
{
    return chunk_id_seq++;
}

static struct ir_goto *ir_goto(struct lnode *n, int dest)
{
    struct ir_goto *res = IRAlloc(struct ir_goto);
    res->node = n;
    res->op = Ir_Goto;
    res->dest = dest;
    return res;
}

static struct ir_igoto *ir_igoto(struct lnode *n, int no)
{
    struct ir_igoto *res = IRAlloc(struct ir_igoto);
    res->node = n;
    res->op = Ir_IGoto;
    res->no = no;
    return res;
}

static struct ir_scanswap *ir_scanswap(struct lnode *n, struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scanswap *res = IRAlloc(struct ir_scanswap);
    res->node = n;
    res->op = Ir_ScanSwap;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_scansave *ir_scansave(struct lnode *n, struct ir_var *new_subject,
                                       struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scansave *res = IRAlloc(struct ir_scansave);
    res->node = n;
    res->op = Ir_ScanSave;
    res->new_subject = new_subject;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_scanrestore *ir_scanrestore(struct lnode *n, struct ir_var *tmp_subject, struct ir_var *tmp_pos)
{
    struct ir_scanrestore *res = IRAlloc(struct ir_scanrestore);
    res->node = n;
    res->op = Ir_ScanRestore;
    res->tmp_subject = tmp_subject;
    res->tmp_pos = tmp_pos;
    return res;
}

static struct ir_move *ir_move(struct lnode *n, struct ir_var *lhs, struct ir_var *rhs, int rval)
{
    struct ir_move *res;
    if (!lhs)
        return 0;
    res = IRAlloc(struct ir_move);
    res->node = n;
    res->op = Ir_Move;
    res->lhs = lhs;
    res->rhs = rhs;
    res->rval = rval;
    return res;
}

static struct ir_movelabel *ir_movelabel(struct lnode *n, int destno, int lab)
{
    struct ir_movelabel *res = IRAlloc(struct ir_movelabel);
    res->node = n;
    res->op = Ir_MoveLabel;
    res->lab = lab;
    res->destno = destno;
    return res;
}

static struct ir_makelist *ir_makelist(struct lnode *n, struct ir_var *lhs, int argc, struct ir_var **args)
{
    struct ir_makelist *res;
    if (!lhs)
        return 0;
    res = IRAlloc(struct ir_makelist);
    res->node = n;
    res->op = Ir_MakeList;
    res->lhs = lhs;
    res->argc = argc;
    res->args = args;
    return res;
}

static struct ir_create *ir_create(struct lnode *n, struct ir_var *lhs, int start_label)
{
    struct ir_create *res = IRAlloc(struct ir_create);
    res->node = n;
    res->op = Ir_Create;
    res->lhs = lhs;
    res->start_label = start_label;
    return res;
}

static struct ir_coret *ir_coret(struct lnode *n, struct ir_var *value)
{
    struct ir_coret *res = IRAlloc(struct ir_coret);
    res->node = n;
    res->op = Ir_Coret;
    res->value = value;
    return res;
}

static struct ir *ir_cofail(struct lnode *n)
{
    struct ir *res = IRAlloc(struct ir);
    res->node = n;
    res->op = Ir_Cofail;
    return res;
}

static struct ir_mark *ir_mark(struct lnode *n, int no)
{
    struct ir_mark *res = IRAlloc(struct ir_mark);
    res->node = n;
    res->op = Ir_Mark;
    res->no = no;
    return res;
}

static struct ir_unmark *ir_unmark(struct lnode *n, int no)
{
    struct ir_unmark *res = IRAlloc(struct ir_unmark);
    res->node = n;
    res->op = Ir_Unmark;
    res->no = no;
    return res;
}

static struct ir_enterinit *ir_enterinit(struct lnode *n, int dest)
{
    struct ir_enterinit *res = IRAlloc(struct ir_enterinit);
    res->node = n;
    res->op = Ir_EnterInit;
    res->dest = dest;
    return res;
}

static struct ir *ir_fail(struct lnode *n)
{
    struct ir *res = IRAlloc(struct ir);
    res->node = n;
    res->op = Ir_Fail;
    return res;
}

static struct ir *ir_syserr(struct lnode *n)
{
    struct ir *res = IRAlloc(struct ir);
    res->node = n;
    res->op = Ir_SysErr;
    return res;
}

static struct ir_suspend *ir_suspend(struct lnode *n, struct ir_var *val)
{
    struct ir_suspend *res = IRAlloc(struct ir_suspend);
    res->node = n;
    res->val = val;
    res->op = Ir_Suspend;
    return res;
}

static struct ir_return *ir_return(struct lnode *n, struct ir_var *val)
{
    struct ir_return *res = IRAlloc(struct ir_return);
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
    struct ir_op *res = IRAlloc(struct ir_op);
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

static struct ir_keyop *ir_keyop(struct lnode *n,
                                 struct ir_var *lhs,
                                 int keyword,
                                 int rval,
                                 int fail_label) 
{
    struct ir_keyop *res = IRAlloc(struct ir_keyop);
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
    struct ir_opclo *res = IRAlloc(struct ir_opclo);
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
    struct ir_keyclo *res = IRAlloc(struct ir_keyclo);
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
    struct ir_invoke *res = IRAlloc(struct ir_invoke);
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
    struct ir_apply *res = IRAlloc(struct ir_apply);
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
                                     char *fname,
                                     int argc,
                                     struct ir_var **args,
                                     int rval,
                                     int fail_label) 
{
    struct ir_invokef *res = IRAlloc(struct ir_invokef);
    res->node = n;
    res->op = Ir_Invokef;
    res->clo = clo;
    res->lhs = lhs;
    res->expr = expr;
    res->fname = fname;
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
                                   char *fname,
                                   struct ir_var *arg2,
                                   int rval,
                                   int fail_label) 
{
    struct ir_applyf *res = IRAlloc(struct ir_applyf);
    res->node = n;
    res->op = Ir_Applyf;
    res->clo = clo;
    res->lhs = lhs;
    res->arg1 = arg1;
    res->fname = fname;
    res->arg2 = arg2;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_field *ir_field(struct lnode *n,
                                 struct ir_var *lhs,
                                 struct ir_var *expr,
                                 char *fname)
{
    struct ir_field *res = IRAlloc(struct ir_field);
    res->node = n;
    res->op = Ir_Field;
    res->lhs = lhs;
    res->expr = expr;
    res->fname = fname;
    return res;
}

static struct ir_resume *ir_resume(struct lnode *n,
                                   int clo)
{
    struct ir_resume *res = IRAlloc(struct ir_resume);
    res->node = n;
    res->op = Ir_Resume;
    res->clo = clo;
    return res;
}

static struct ir_limit *ir_limit(struct lnode *n, struct ir_var *limit)
{
    struct ir_limit *res = IRAlloc(struct ir_limit);
    res->node = n;
    res->op = Ir_Limit;
    res->limit = limit;
    return res;
}

static struct ir_var *make_tmp(struct ir_stack *st)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = TMP;
    v->index = st->tmp++;
    if (v->index > hi_tmp)
        hi_tmp = v->index;
    return v;
}

static struct ir_var *make_word(word w)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = WORD;
    v->w = w;
    return v;
}

static struct ir_var *make_knull(void)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = KNULL;
    return v;
}

static int make_tmploc(struct ir_stack *st)
{
    int i = st->lab++;
    if (i > hi_lab)
        hi_lab = i;
    return i;
}

static int make_mark(struct ir_stack *st)
{
    int i = st->mark++;
    if (i > hi_mark)
        hi_mark = i;
    return i;
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
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = CONST;
    v->con = ((struct lnode_const *)n)->con;
    return v;
}

static struct ir_var *make_local(struct lnode *n)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = LOCAL;
    v->local = ((struct lnode_local *)n)->local;
    return v;
}

static struct ir_var *make_global(struct lnode *n)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = GLOBAL;
    v->global = ((struct lnode_global *)n)->global;
    v->local = ((struct lnode_global *)n)->local;
    return v;
}

static struct ir_var *get_var(struct lnode *n, struct ir_stack *st, struct ir_var *target)
{
    switch (n->op) {
        case Uop_Keyword: {
            if (((struct lnode_keyword *)n)->num == K_NULL)
                return make_knull();
            break;
        }
        case Uop_Empty:
            return make_knull();
        case Uop_Const:
            return make_const(n);
        case Uop_Local:
            return make_local(n);
        case Uop_Global:
            return make_global(n);
    }
    if (target)
        return target;
    return make_tmp(st);
}

static int is_rval(int op, int arg, int parent)
{
    switch (op) {

        case Uop_Asgn:
        case Uop_Augactivate:
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
        case Uop_Augunions: {
            return (arg == 2);
        }

        case Uop_Rswap:
        case Uop_Swap: {
            return 0;
        }

        case Uop_Subsc: {
            if (arg == 1)
                return parent;
            break;
        }

        case Uop_Bang:
        case Uop_Random:
        case Uop_Null:
        case Uop_Nonnull: {
            return parent;
        }
    }
    return 1;
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
                  ir_move(n, target, make_knull(), 0),
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
                          ir_move(n, target, make_knull(), 0),
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
            if (target && target->type == LOCAL)
                target = 0;
            chunk2(res->start, 
                  ir_move(n, target, make_local(n), rval),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Global: {
            if (target && target->type == GLOBAL)
                target = 0;
            chunk2(res->start, 
                  ir_move(n, target, make_global(n), rval),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));
            break;
        }

        case Uop_Const: {
            if (target && target->type == CONST)
                target = 0;
            chunk2(res->start, 
                  ir_move(n, target, make_const(n), 0),
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
            lv = get_var(x->child1, st, 0);
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

            init_scan(res, st);
            lv = get_var(x->child1, st, 0);
            rv = target ? target : make_tmp(st);
            expr = ir_traverse(x->child1, st, lv, 0, 0);
            push_scan(res);
            body = ir_traverse(x->child2, st, rv, 0, rval);
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
            chunk3(body->success,
                   ir_op(n, target, Uop_Asgn, lv, rv, 0, rval, body->resume),
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

            fv = get_var(x->child1, st, 0);
            tv = get_var(x->child2, st, 0);
            bv = get_var(x->child3, st, target);

            from = ir_traverse(x->child1, st, fv, 0, 1);
            to = ir_traverse(x->child2, st, tv, 0, 1);
            by = ir_traverse(x->child3, st, bv, 0, 1);

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

            fv = get_var(x->child1, st, 0);
            tv = get_var(x->child2, st, target);
            one = make_word(1);

            from = ir_traverse(x->child1, st, fv, 0, 1);
            to = ir_traverse(x->child2, st, tv, 0, 1);

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

        case Uop_Asgn:
        case Uop_Augactivate:
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
        case Uop_Augdiv:
        case Uop_Augmult:
        case Uop_Augunions:
        case Uop_Power:
        case Uop_Bactivate:
        case Uop_Cat:
        case Uop_Diff:
        case Uop_Eqv:
        case Uop_Inter:
        case Uop_Subsc:
        case Uop_Lconcat:
        case Uop_Lexeq:
        case Uop_Lexge:
        case Uop_Lexgt:
        case Uop_Lexle:
        case Uop_Lexlt:
        case Uop_Lexne:
        case Uop_Minus:
        case Uop_Mod:
        case Uop_Neqv:
        case Uop_Numeq:
        case Uop_Numge:
        case Uop_Numgt:
        case Uop_Numle:
        case Uop_Numlt:
        case Uop_Numne:
        case Uop_Plus:
        case Uop_Div:
        case Uop_Mult:
        case Uop_Swap:
        case Uop_Unions: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv, *tmp = 0;
            struct ir_info *left, *right;
            int aaop;

            aaop = augop(n->op);
            lv = get_var(x->child1, st, 0);
            rv = get_var(x->child2, st, target);
            if (aaop)
                tmp = target ? target : make_tmp(st);

            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            right = ir_traverse(x->child2, st, rv, 0, is_rval(n->op, 2, rval));
            chunk1(res->start, ir_goto(n, left->start));
            chunk1(left->success, ir_goto(n, right->start));
            chunk1(left->failure, ir_goto(n, res->failure));
            chunk1(right->failure, ir_goto(n, left->resume));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, right->resume));

            if (aaop) {
                chunk3(right->success, 
                      ir_op(n, tmp, aaop, lv, rv, 0, 1, right->resume),
                      ir_op(n, target, Uop_Asgn, lv, tmp, 0, rval, right->resume),
                      ir_goto(n, res->success));

            } else {
                chunk2(right->success, 
                      ir_op(n, target, n->op, lv, rv, 0, rval, right->resume),
                      ir_goto(n, res->success));
            }

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Apply: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int clo;
            char *fname = 0;

            clo = make_closure(st);
            if (x->child1->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->child1;
                lv = get_var(y->child, st, 0);
                rv = get_var(x->child2, st, target);
                left = ir_traverse(y->child, st, lv, 0, 1);
                fname = y->fname;
            } else {
                lv = get_var(x->child1, st, 0);
                rv = get_var(x->child2, st, target);
                left = ir_traverse(x->child1, st, lv, 0, 1);
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

            if (fname)
                chunk2(right->success, 
                       ir_applyf(n, clo, target, lv, fname, rv, rval, right->resume),
                       ir_goto(n, res->success));
            else
                chunk2(right->success, 
                       ir_apply(n, clo, target, lv, rv, rval, right->resume),
                       ir_goto(n, res->success));

            res->uses_stack = 1;

            break;
        }

        case Uop_Rasgn:
        case Uop_Rswap:{
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv;
            struct ir_info *left, *right;
            int clo = make_closure(st);
            lv = get_var(x->child1, st, 0);
            rv = get_var(x->child2, st, target);

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

            v1 = get_var(x->child1, st, 0);
            v2 = get_var(x->child2, st, 0);
            v3 = get_var(x->child3, st, target);
            tmp = make_tmp(st);

            e1 = ir_traverse(x->child1, st, v1, 0, 0);
            e2 = ir_traverse(x->child2, st, v2, 0, 1);
            e3 = ir_traverse(x->child3, st, v3, 0, 1);

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
                   ir_op(n, tmp, aop, v2, v3, 0, 1, e3->resume),
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

            v1 = get_var(x->child1, st, 0);
            v2 = get_var(x->child2, st, 0);
            v3 = get_var(x->child3, st, target);

            e1 = ir_traverse(x->child1, st, v1, 0, 0);
            e2 = ir_traverse(x->child2, st, v2, 0, 1);
            e3 = ir_traverse(x->child3, st, v3, 0, 1);

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
            int body_mk;

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
            int body_mk;

            init_loop(res, st, target, bounded, rval);
            push_loop(res);

            body_expr_st = branch_stack(res->loop->loop_st);
            v = get_var(x->child1, body_expr_st, 0);
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
            v = get_var(x->child, expr_st, 0);

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
                quit("break without corresponding loop");

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
                           ir_move(n, loop_stack->loop->target, make_knull(), 0),
                           ir_goto(n, loop_stack->success));
                } else {
                    chunk5(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_scanrestore(n, t->scan->old_subject, 
                                         t->scan->old_pos),
                           ir_movelabel(n, loop_stack->loop->continue_tmploc, loop_stack->failure),
                           ir_move(n, loop_stack->loop->target, make_knull(), 0),
                           ir_goto(n, loop_stack->success));
                }

            } else {
                if (loop_stack->loop->bounded) {
                    chunk3(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_move(n, loop_stack->loop->target, make_knull(), 0),
                           ir_goto(n, loop_stack->success));
                } else {
                    chunk4(res->start, 
                           ir_unmark(n, loop_stack->loop->loop_mk),
                           ir_movelabel(n, loop_stack->loop->continue_tmploc, loop_stack->failure),
                           ir_move(n, loop_stack->loop->target, make_knull(), 0),
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
                quit("break without corresponding loop");

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
                quit("next without corresponding loop");

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

        case Uop_Return: {                      /* return */
            if (!bounded)
                chunk1(res->resume, ir_syserr(n));

            if (scan_stack) {
                struct ir_info *t = scan_stack;
                /* Get bottom of scan stack */
                while (t->scan->next)
                    t = t->scan->next;
                chunk2(res->start, 
                       ir_scanrestore(n, t->scan->old_subject, t->scan->old_pos),
                       ir_return(n, make_knull()));
            } else {
                chunk1(res->start, 
                       ir_return(n, make_knull()));
            }

            break;
        }

        case Uop_Returnexpr: {                      /* return expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            struct ir_var *v;
            struct ir_stack *tst;

            tst = branch_stack(st);
            v = get_var(x->child, tst, 0);

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

        case Uop_Alt: {               /* Alternation */
            struct lnode *n1;
            int count, i;
            struct ir_info **info;
            struct ir_stack *expr_st, *tst;
            int tl = -1;
            if (!bounded)
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

        case Uop_Augconj: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *v1, *v2;
            struct ir_info *e1, *e2;

            v1 = get_var(x->child1, st, 0);
            v2 = get_var(x->child2, st, target);

            e1 = ir_traverse(x->child1, st, v1, 0, 1);
            e2 = ir_traverse(x->child2, st, v2, 0, 0);
            chunk1(res->start, ir_goto(n, e1->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e2->resume));
            chunk1(e1->success, ir_goto(n, e2->start));
            chunk1(e1->failure, ir_goto(n, res->failure));
            chunk2(e2->success, 
                   ir_op(n, target, Uop_Asgn, v1, v2, 0, rval, e2->resume),
                   ir_goto(n, res->success));
            chunk1(e2->failure, ir_goto(n, e1->resume));

            res->uses_stack = e1->uses_stack || e2->uses_stack;
            break;
        }

        case Uop_Field: {                       /* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            struct ir_info *e;
            struct ir_var *t;

            t = get_var(x->child, st, target);
            e = ir_traverse(x->child, st, t, 0, 1);

            chunk1(res->start, ir_goto(n, e->start));
            if (!bounded)
                chunk1(res->resume, ir_goto(n, e->resume));
            chunk2(e->success, 
                   ir_field(n, target, t, x->fname),
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
            int need_mark, mk;

            if (x->n < 2)
                quit("got slist with < 2 elements");

            list_st = branch_stack(st);
            mk = make_mark(list_st);
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            need_mark = 0;  /* Set to 1 if any of child[0]...[n-2] uses stack */
            for (i = 0; i < x->n - 1; ++i) {
                info[i] = ir_traverse(x->child[i], branch_stack(list_st), 0, 1, 1);
                if (info[i]->uses_stack)
                    need_mark = 1;
            }
            info[x->n - 1] = ir_traverse(x->child[x->n - 1], st, target, bounded, rval);

            chunk2(res->start, 
                   OptIns(need_mark, ir_mark(n, mk)), 
                   ir_goto(n, info[0]->start));
            if (!bounded) 
                chunk1(res->resume, ir_goto(n, info[x->n - 1]->resume));

            for (i = 0; i < x->n - 1; ++i) {
                chunk2(info[i]->success,
                       OptIns(info[i]->uses_stack, ir_unmark(n, mk)),
                       ir_goto(n, info[i + 1]->start));
                chunk1(info[i]->failure,
                      ir_goto(n, info[i + 1]->start));
            }

            i = x->n - 1;
            chunk1(info[i]->success, ir_goto(n, res->success));
            chunk1(info[i]->failure, ir_goto(n, res->failure));
            res->uses_stack = info[i]->uses_stack;

            break;
        }

        case Uop_Value:		/* unary . operator */
        case Uop_Nonnull:	/* unary \ operator */
        case Uop_Refresh:	/* unary ^ operator */
        case Uop_Number:	/* unary + operator */
        case Uop_Compl:		/* unary ~ operator (cset compl) */
        case Uop_Neg:		/* unary - operator */
        case Uop_Size:		/* unary * operator */
        case Uop_Random:	/* unary ? operator */
        case Uop_Null: {	/* unary / operator */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v;
            struct ir_info *operand;
            v = get_var(x->child, st, target);
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
            v = get_var(x->child, st, target);
            operand = ir_traverse(x->child, st, v, 0, is_rval(n->op, 1, rval));
            chunk1(res->start, ir_goto(n, operand->start));
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

        case Uop_CoInvoke: {                      /* e{x1, x2.., xn} */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            int i;
            /* Transform into an invoke node: e(create x1, create x2, ... create xn) */
            x->op = Uop_Invoke;
            for (i = 0; i < x->n; ++i)
                x->child[i] = (struct lnode *)lnode_1(Uop_Create, &x->child[i]->loc, x->child[i]);
            /* Fall through */
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            struct ir_var *fn, **args;
            struct ir_info *expr, **info;
            int i;
            char *fname = 0;
            int clo = make_closure(st);
            args = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_var *));
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            if (x->expr->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->expr;
                fn = get_var(y->child, st, 0);
                for (i = 0; i < x->n; ++i)
                    args[i] = get_var(x->child[i], st, 0);
                expr = ir_traverse(y->child, st, fn, 0, 1);
                fname = y->fname;
            } else {
                fn = get_var(x->expr, st, 0);
                for (i = 0; i < x->n; ++i)
                    args[i] = get_var(x->child[i], st, 0);
                expr = ir_traverse(x->expr, st, fn, 0, 1);
            }
            for (i = 0; i < x->n; ++i) 
                info[i] = ir_traverse(x->child[i], st, args[i], 0, 0);

            chunk1(res->start, ir_goto(n, expr->start));
            chunk1(expr->failure, ir_goto(n, res->failure));

            if (x->n == 0) {
                if (!bounded)
                    chunk2(res->resume,
                           ir_resume(n, clo),
                           ir_goto(n, res->success));
                if (fname)
                    chunk2(expr->success,
                           ir_invokef(n, clo, target, fn, fname, x->n, args, rval, expr->resume),
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
                if (fname)
                    chunk2(info[0]->success,
                           ir_invokef(n, clo, target, fn, fname, x->n, args, rval, info[0]->resume),
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

                /* Last one */
                i = x->n - 1;
                if (fname)
                    chunk2(info[i]->success,
                           ir_invokef(n, clo, target, fn, fname, x->n, args, rval, info[x->n - 1]->resume),
                           ir_goto(n, res->success));
                else
                    chunk2(info[i]->success,
                           ir_invoke(n, clo, target, fn, x->n, args, rval, info[x->n - 1]->resume),
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
                quit("got mutual with < 2 elements");

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
                chunk1(res->resume, ir_goto(n, info[x->n - 1]->resume));

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
                args[i] = get_var(x->child[i], st, 0);

            for (i = 0; i < x->n; ++i) {
                info[i] = ir_traverse(x->child[i], st, args[i], 0, 1);
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
            int expr_mk;
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
            int expr_mk;
            struct ir_stack *expr_st, *then_st, *else_st;
            struct ir_info *expr, *then, *els;
            int tl = -1;
            if (!bounded)
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
            struct ir_var *e, *v;
            struct ir_info *expr, *def = 0, **selector, **clause;
            struct ir_stack *case_st, *clause_st;
            int i, need_mark, mk;
            int tl = -1;

            selector = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            clause = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));

            if (!bounded)
                tl = make_tmploc(st);

            /* Stack for the expression and selectors */
            case_st = branch_stack(st);

            mk = make_mark(case_st);
            e = get_var(x->expr, case_st, 0);
            v = target ? target : make_tmp(case_st);

            expr = ir_traverse(x->expr, branch_stack(case_st), e, 1, 1);

            /* Set to 1 if the expression or any selector uses stack */
            need_mark = expr->uses_stack;

            clause_st = branch_stack(st);
            for (i = 0; i < x->n; ++i) {                /* The n non-default cases */
                struct ir_stack *tst;
                selector[i] = ir_traverse(x->selector[i], branch_stack(case_st), v, 0, 1);
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
                           ir_op(n, 0, Uop_Eqv, e, v, 0, 1, selector[i]->resume),
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
            break;
        }

        case Uop_Rptalt: {                      /* repeated alternation */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            int tl = -1;
            if (!bounded)
                tl = make_tmploc(st);

            expr = ir_traverse(x->child, st, target, bounded, rval);

            if (bounded) {
                chunk1(res->start, ir_goto(n, expr->start));
                chunk1(expr->success, ir_goto(n, res->success));
                chunk1(expr->failure, ir_goto(n, res->failure));
            } else {
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
            int mk;

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
                   ir_move(n, target, make_knull(), 0),
                   ir_goto(n, res->success));
            break;
        }

        case Uop_Limit: {                       /* limitation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_info *expr, *limit;
            struct ir_var *t;
            t = make_tmp(st);

            limit = ir_traverse(x->child1, st, t, 0, 1);
            expr = ir_traverse(x->child2, st, target, bounded, rval);

            chunk1(res->start, ir_goto(n, limit->start));
            if (!bounded)
                chunk3(res->resume, 
                       ir_op(n, 0, Uop_Numgt, t, make_word(1), 0, 1, limit->resume),
                       ir_op(n, t, Uop_Minus, t, make_word(1), 0, 1, expr->resume),
                       ir_goto(n, expr->resume));

            chunk1(expr->failure, ir_goto(n, limit->resume));
            chunk1(limit->failure, ir_goto(n, res->failure));
            chunk1(expr->success, ir_goto(n, res->success));
            chunk3(limit->success, 
                   ir_limit(n, t),
                   ir_op(n, 0, Uop_Numgt, t, make_word(0), 0, 1, limit->resume),  /* Check for expr \ 0 */
                   ir_goto(n, expr->start));

            res->uses_stack = (limit->uses_stack || expr->uses_stack);
            break;
        }

        case Uop_Create: {                      /* create expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_info *expr;
            if (!target) {
                chunk1(res->start, ir_goto(n, res->success));
                if (!bounded)
                    chunk1(res->resume, ir_goto(n, res->failure));
                break;
            }
            expr = ir_traverse(x->child, st, target, 0, 0);

            chunk2(res->start, 
                   ir_create(n, target, expr->start),
                   ir_goto(n, res->success));

            if (!bounded)
                chunk1(res->resume, ir_goto(n, res->failure));

            chunk2(expr->success, 
                   ir_coret(n, target),
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

            e = get_var(x->child, st, target);
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
            quit("ir_traverse: illegal opcode(%d): %s in file %s\n", n->op, 
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
    int init_mk = -1;

    hi_chunk = -1;
    chunk_id_seq = 1;
    memset(chunks, 0, n_chunks_alloc * sizeof(struct chunk *));
    mb_clear(&ir_func_mb);
    hi_clo = hi_tmp = hi_lab = hi_mark = -1;

    if (Iflag) {
        if (curr_lfunc->method)
            fprintf(stderr, "\nGenerating ir tree for method %s.%s\n", 
                    curr_lfunc->method->class->global->name, curr_lfunc->method->name);
        else
            fprintf(stderr, "\nGenerating ir tree for procedure %s\n",  curr_lfunc->proc->name);
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

    optimize_goto();
    renumber_ir();
    if (Iflag) {
        fprintf(stderr, "** Optimized code\n");
        dump_ir();
        fprintf(stderr, "** End of optimized code\n");
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
            fprintf(stderr, "{word %ld}", (long)v->w);
            break;
        }
        case KNULL: {
            fprintf(stderr, "{&null}");
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
            fprintf(stderr, "{tmp %d}", v->index);
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
    indentf("Chunk %d %s (line %d)\n", chunk->id, chunk->desc, chunk->line);
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
                fprintf(stderr, "\n");
                break;
            }
            case Ir_Return: {
                struct ir_return *x = (struct ir_return *)ir;
                indentf("\tIr_Return ");
                print_ir_var(x->val);
                fprintf(stderr, "\n");
                break;
            }
            case Ir_Mark: {
                struct ir_mark *x = (struct ir_mark *)ir;
                indentf("\tIr_Mark %d\n", x->no);
                break;
            }
            case Ir_Unmark: {
                struct ir_unmark *x = (struct ir_unmark *)ir;
                indentf("\tIr_Unmark %d\n", x->no);
                break;
            }
            case Ir_Move: {
                struct ir_move *x = (struct ir_move *)ir;
                indentf("\tIr_Move ");
                print_ir_var(x->lhs);
                fprintf(stderr, " <- ");
                print_ir_var(x->rhs);
                fprintf(stderr, ", rval=%d\n", x->rval);
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
                fprintf(stderr, "\n");
                break;
            }
            case Ir_ScanRestore: {
                struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                indentf("\tIr_ScanRestore tmp_subject=");
                print_ir_var(x->tmp_subject);
                fprintf(stderr, ", tmp_pos=");
                print_ir_var(x->tmp_pos);
                fprintf(stderr, "\n");
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
                fprintf(stderr, " . %s(", x->fname);
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
                fprintf(stderr, " . %s ! ", x->fname);
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
                fprintf(stderr, "\n");
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
        if (!chunk)
            continue;
        print_chunk(chunk);
    }
}

static int augop(int n)
{
    int opcode = 0;

    switch (n) {
        case Uop_Augactivate:
            opcode = Uop_Bactivate;
            break;

        case Uop_Augpower:
            opcode = Uop_Power;
            break;

        case Uop_Augcat:
            opcode = Uop_Cat;
            break;

        case Uop_Augdiff:
            opcode = Uop_Diff;
            break;

        case Uop_Augeqv:
            opcode = Uop_Eqv;
            break;

        case Uop_Auginter:
            opcode = Uop_Inter;
            break;

        case Uop_Auglconcat:
            opcode = Uop_Lconcat;
            break;

        case Uop_Auglexeq:
            opcode = Uop_Lexeq;
            break;

        case Uop_Auglexge:
            opcode = Uop_Lexge;
            break;

        case Uop_Auglexgt:
            opcode = Uop_Lexgt;
            break;

        case Uop_Auglexle:
            opcode = Uop_Lexle;
            break;

        case Uop_Auglexlt:
            opcode = Uop_Lexlt;
            break;

        case Uop_Auglexne:
            opcode = Uop_Lexne;
            break;

        case Uop_Augminus:
            opcode = Uop_Minus;
            break;

        case Uop_Augmod:
            opcode = Uop_Mod;
            break;

        case Uop_Augneqv:
            opcode = Uop_Neqv;
            break;

        case Uop_Augnumeq:
            opcode = Uop_Numeq;
            break;

        case Uop_Augnumge:
            opcode = Uop_Numge;
            break;

        case Uop_Augnumgt:
            opcode = Uop_Numgt;
            break;

        case Uop_Augnumle:
            opcode = Uop_Numle;
            break;

        case Uop_Augnumlt:
            opcode = Uop_Numlt;
            break;

        case Uop_Augnumne:
            opcode = Uop_Numne;
            break;

        case Uop_Augplus:
            opcode = Uop_Plus;
            break;

        case Uop_Augdiv:
            opcode = Uop_Div;
            break;

        case Uop_Augmult:
            opcode = Uop_Mult;
            break;

        case Uop_Augunions:
            opcode = Uop_Unions;
            break;
    }

    return opcode;
}

static void optimize_goto_chain(int *lab)
{
    static int marker = 0;
    struct chunk *chunk;
    int start = *lab;
    if (*lab < 0)
        return;
    ++marker;
    while (1) {
        chunk = chunks[*lab];
        if (!chunk || chunk->n_inst == 0)
            quit("Optimize goto chain dead end at chunk %d, start was %d", *lab, start);
        if (chunk->inst[0]->op != Ir_Goto || chunk->circle == marker)
            break;
        *lab = ((struct ir_goto *)chunk->inst[0])->dest;
        chunk->circle = marker;        
    }
}

static void optimize_goto()
{
    int i;
    struct chunk *last;
    optimize_goto1(0);

    /* Eliminate unseen ones */
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (chunk && !chunk->seen) {
            if (Iflag)
                fprintf(stderr, "Elminating untraversed chunk %d (line %d)\n", i, chunk->line);
            chunks[i] = 0;
        }
    }

    /* Merge chunks where possible */
    i = 0;
    while (i <= hi_chunk) {
        struct chunk *chunk, *other;
        int j;
        chunk = chunks[i];
        /*
         * If we have
         *    chunk i: A
         *             goto j
         *    ...
         *    chunk j: B
         *             T
         * and j is only referenced once (by chunk i), delete chunk j and 
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
            other->n_inst > 0)
        {
            struct chunk *new;
            if (Iflag)
                fprintf(stderr, "Merge chunk %d into %d\n", j, i);
            new = mb_alloc(&ir_func_mb, sizeof(struct chunk) + 
                           (chunk->n_inst + other->n_inst - 2) * sizeof(struct ir *));
            new->id = chunk->id;
            new->desc = chunk->desc;
            new->line = chunk->line;
            new->n_inst = chunk->n_inst - 1 + other->n_inst;
            new->seen = chunk->seen;
            memcpy(new->inst, chunk->inst, (chunk->n_inst - 1) * sizeof(struct ir *));
            memcpy(new->inst + chunk->n_inst - 1, other->inst, other->n_inst * sizeof(struct ir *));
            chunks[j] = 0;
            chunks[i] = new;
        } else
            ++i;
    }

    /* Eliminate redundant trailing gotos */
    last = 0;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (chunk) {
            if (last && last->n_inst > 0 && 
                last->inst[last->n_inst - 1]->op == Ir_Goto &&
                ((struct ir_goto *)(last->inst[last->n_inst - 1]))->dest == i) 
            {
                --last->n_inst;
            }

            last = chunk;
        }
    }
    
}

static void optimize_goto1(int i)
{
    int j;
    struct chunk *chunk;
    if (i < 0)
        return;
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
                case Ir_Goto:
                    break;

                case Ir_IGoto: {
                    struct ir_igoto *x = (struct ir_igoto *)ir;
                    renumber_lab(&x->no);
                    break;
                }

                case Ir_SysErr:
                case Ir_EnterInit:
                case Ir_Fail:
                case Ir_Cofail:
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
                default: {
                    quit("renumber: illegal ir opcode(%d)\n", ir->op);
                    break;
                }
            }
        }
    }
}
