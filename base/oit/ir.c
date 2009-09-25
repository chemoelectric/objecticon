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
int ir_start;
static int hi_clo, hi_tmp, hi_lab, hi_mark;

static int augop(int n);
static void print_ir_var(struct ir_var *v);
static void optimize_goto();
static void optimize_goto1(int i);
static void renumber_ir();

struct membuff ir_func_mb = {"Per func IR membuff", 64000, 0,0,0 };
#define IRAlloc(type)   mb_alloc(&ir_func_mb, sizeof(type))

struct ir_stack *new_stack()
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

static struct chunk *chunk(int id, int n, ...)
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
    va_start(argp, n);
    chunk->n_inst = 0;
    for (i = 0; i < n; ++i) {
        struct ir *inst = va_arg(argp, struct ir *);
        if (inst)
            chunk->inst[chunk->n_inst++] = inst;
    }
    va_end(argp);
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

static struct ir_movelabel *ir_movelabel(struct lnode *n, int lab, int destno)
{
    struct ir_movelabel *res = IRAlloc(struct ir_movelabel);
    res->node = n;
    res->op = Ir_MoveLabel;
    res->lab = lab;
    res->destno = destno;
    return res;
}

static struct ir_deref *ir_deref(struct lnode *n, struct ir_var *src, struct ir_var *dest)
{
    struct ir_deref *res = IRAlloc(struct ir_deref);
    res->node = n;
    res->op = Ir_Deref;
    res->src = src;
    res->dest = dest;
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

static struct ir_mark *cond_ir_mark(int c, struct lnode *n, int no)
{
    if (c)
        return ir_mark(n, no);
    else
        return 0;
}

static struct ir_unmark *ir_unmark(struct lnode *n, int no)
{
    struct ir_unmark *res = IRAlloc(struct ir_unmark);
    res->node = n;
    res->op = Ir_Unmark;
    res->no = no;
    return res;
}

static struct ir_unmark *cond_ir_unmark(int c, struct lnode *n, int no)
{
    if (c)
        return ir_unmark(n, no);
    else
        return 0;
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

static struct ir_binop *ir_binop(struct lnode *n,
                                 struct ir_var *lhs,
                                 int operation,
                                 struct ir_var *arg1,
                                 struct ir_var *arg2,
                                 int rval,
                                 int fail_label) 
{
    struct ir_binop *res = IRAlloc(struct ir_binop);
    res->node = n;
    res->op = Ir_BinOp;
    res->lhs = lhs;
    res->operation = operation;
    res->arg1 = arg1;
    res->arg2 = arg2;
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

static struct ir_binclo *ir_binclo(struct lnode *n,
                                   int clo,
                                   int operation,
                                   struct ir_var *arg1,
                                   struct ir_var *arg2,
                                   int rval,
                                   int fail_label) 
{
    struct ir_binclo *res = IRAlloc(struct ir_binclo);
    res->node = n;
    res->op = Ir_BinClo;
    res->clo = clo;
    res->operation = operation;
    res->arg1 = arg1;
    res->arg2 = arg2;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_keyclo *ir_keyclo(struct lnode *n,
                                   int clo,
                                   int keyword,
                                   int rval,
                                   int fail_label) 
{
    struct ir_keyclo *res = IRAlloc(struct ir_keyclo);
    res->node = n;
    res->op = Ir_KeyClo;
    res->clo = clo;
    res->keyword = keyword;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_invoke *ir_invoke(struct lnode *n,
                                   int clo,
                                   struct ir_var *expr,
                                   int argc,
                                   struct ir_var **args,
                                   int fail_label) 
{
    struct ir_invoke *res = IRAlloc(struct ir_invoke);
    res->node = n;
    res->op = Ir_Invoke;
    res->clo = clo;
    res->expr = expr;
    res->argc = argc;
    res->args = args;
    res->fail_label = fail_label;
    return res;
}

static struct ir_unop *ir_unop(struct lnode *n,
                               struct ir_var *lhs,
                               int operation,
                               struct ir_var *arg,
                               int rval,
                               int fail_label) 
{
    struct ir_unop *res = IRAlloc(struct ir_unop);
    res->node = n;
    res->op = Ir_UnOp;
    res->lhs = lhs;
    res->operation = operation;
    res->arg = arg;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_unclo *ir_unclo(struct lnode *n,
                                 int clo,
                                 int operation,
                                 struct ir_var *arg,
                                 int rval,
                                 int fail_label) 
{
    struct ir_unclo *res = IRAlloc(struct ir_unclo);
    res->node = n;
    res->op = Ir_UnClo;
    res->clo = clo;
    res->operation = operation;
    res->arg = arg;
    res->rval = rval;
    res->fail_label = fail_label;
    return res;
}

static struct ir_resumevalue *ir_resumevalue(struct lnode *n,
                                             struct ir_var *lhs,
                                             int clo,
                                             int fail_label) 
{
    struct ir_resumevalue *res = IRAlloc(struct ir_resumevalue);
    res->node = n;
    res->op = Ir_ResumeValue;
    res->lhs = lhs;
    res->clo = clo;
    res->fail_label = fail_label;
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

static struct ir_var *make_closure(struct ir_stack *st)
{
    struct ir_var *v = IRAlloc(struct ir_var);
    v->type = CLOSURE;
    v->index = st->clo++;
    if (v->index > hi_clo)
        hi_clo = v->index;
    return v;
}

static struct ir_var *get_var(struct lnode *n, struct ir_stack *st, struct ir_var *target)
{
    if (n->op == Uop_Const)
        return make_const(n);

    if (n->op == Uop_Local)
        return make_local(n);

    if (n->op == Uop_Global)
        return make_global(n);

    if (target)
        return target;
    return make_tmp(st);
}

static int is_rval(int op, int arg, int parent)
{
    switch (op) {

        case Uop_Asgn:
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
    res->node = n;
    switch (n->op) {
        case Uop_End:
            chunk(res->start, 1, ir_fail(n));
            break;

        case Uop_Empty: {
            n = (struct lnode *)lnode_keyword(&n->loc, K_NULL);
            ir_traverse(n, st, target, bounded, rval);
            break;
        }

        case Uop_Keyword: {
            struct lnode_keyword *x = (struct lnode_keyword *)n;
            switch (x->num) {
                case K_FAIL: {
                    chunk(res->start, 1, ir_goto(n, res->failure));
                    chunk(res->resume, 1, ir_goto(n, res->failure)); /* Should never be invoked */
                    break;
                }

                case K_FEATURES: {
                    struct ir_var *clo;
                    clo = make_closure(st);
                    chunk(res->start, 3,
                          ir_keyclo(n, clo->index, x->num, rval, res->failure),
                          ir_move(n, target, clo, 0),
                          ir_goto(n, res->success));
                    chunk(res->resume, 2, 
                          ir_resumevalue(n, target, clo->index, res->failure),
                          ir_goto(n, res->success));
                    res->uses_stack = 1;
                    break;
                }

                default: {
                    chunk(res->start, 2,
                          ir_keyop(n, target, x->num, rval, res->failure),
                          ir_goto(n, res->success));
                    chunk(res->resume, 1, 
                          ir_goto(n, res->failure));
                    break;
                }
            }
            break;
        }

        case Uop_Local: {
            struct ir_var *v = make_local(n);
            if (target && target->type != TMP)
                target = 0;
            chunk(res->start, 2, 
                  ir_move(n, target, v, rval),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, res->failure));
            break;
        }

        case Uop_Global: {
            struct ir_var *v = make_global(n);
            if (target && target->type != TMP)
                target = 0;
            chunk(res->start, 2, 
                  ir_move(n, target, v, rval),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, res->failure));
            break;
        }

        case Uop_Const: {
            struct ir_var *v = make_const(n);
            if (target && target->type == CONST)
                target = 0;
            chunk(res->start, 2, 
                  ir_move(n, target, v, 0),
                  ir_goto(n, res->success));
            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, res->failure));
            break;
        }

        case Uop_Toby: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            int to_mk, by_mk, clo_mk, clo, clo_fail;
            struct ir_var *fv, *tv, *bv;
            struct ir_info *from, *to, *by;

            to_mk = make_mark(st);
            by_mk = make_mark(st);
            clo_mk = make_mark(st);

            clo_fail = get_extra_chunk();
            fv = get_var(x->child1, st, 0);
            tv = get_var(x->child2, st, 0);
            bv = get_var(x->child3, st, target);

            from = ir_traverse(x->child1, st, fv, 0, 1);
            to = ir_traverse(x->child2, st, tv, 0, 1);
            by = ir_traverse(x->child3, st, bv, 0, 1);

            clo = make_closure(st);

            chunk(res->start, 1, ir_goto(n, from->start));
            chunk(res->resume, 2, 
                  ir_resumevalue(n, target, clo->index, clo_fail),
                  ir_goto(n, res->success));

            chunk(from->success, 2, 
                  cond_ir_mark(to->uses_stack, n, to_mk), 
                  ir_goto(n, to->start));
            chunk(from->failure, 1, ir_goto(n, res->failure));

            chunk(to->success, 2, 
                  cond_ir_mark(by->uses_stack, n, by_mk), 
                  ir_goto(n, by->start));
            chunk(to->failure, 2, 
                  cond_ir_unmark(to->uses_stack, n, to_mk),
                  ir_goto(n, from->resume));

            chunk(to->success, 2, 
                  cond_ir_mark(by->uses_stack, n, by_mk), 
                  ir_goto(n, by->start));

            break;
        }

        case Uop_Asgn:
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
            struct ir_var *lv, *rv, *tmp;
            struct ir_info *left, *right;
            struct ir_stack *tst;
            int mk;
            int aaop;

            aaop = augop(n->op);
            lv = get_var(x->child1, st, 0);
            rv = get_var(x->child2, st, target);
            if (aaop)
                tmp = target ? target : make_tmp(st);
            mk = make_mark(st);
            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            tst = branch_stack(st);
            right = ir_traverse(x->child2, tst, rv, 0, is_rval(n->op, 2, rval));
            union_stack(st, tst);
            chunk(res->start, 1, ir_goto(n, left->start));
            chunk(left->success, 2, 
                  cond_ir_mark(right->uses_stack, n, mk), 
                  ir_goto(n, right->start));
            chunk(left->failure, 1, ir_goto(n, res->failure));
            chunk(right->failure, 2, 
                  cond_ir_unmark(right->uses_stack, n, mk),
                  ir_goto(n, left->resume));

            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, right->resume));

            if (aaop) {
                chunk(right->success, 3, 
                      ir_binop(n, tmp, aaop, lv, rv, 1, right->resume),
                      ir_binop(n, target, Uop_Asgn, lv, tmp, rval, right->resume),
                      ir_goto(n, res->success));

            } else {
                chunk(right->success, 2, 
                      ir_binop(n, target, n->op, lv, rv, rval, right->resume),
                      ir_goto(n, res->success));
            }

            res->uses_stack = (left->uses_stack || right->uses_stack);
            break;
        }

        case Uop_Apply:
        case Uop_Rasgn:
        case Uop_Rswap:{
            struct lnode_2 *x = (struct lnode_2 *)n;
            struct ir_var *lv, *rv, *clo;
            struct ir_info *left, *right;
            struct ir_stack *tst;
            int mk;

            clo = make_closure(st);
            lv = get_var(x->child1, st, 0);
            rv = get_var(x->child2, st, target);
            mk = make_mark(st);
            left = ir_traverse(x->child1, st, lv, 0, is_rval(n->op, 1, rval));
            tst = branch_stack(st);
            right = ir_traverse(x->child2, tst, rv, 0, is_rval(n->op, 2, rval));
            union_stack(st, tst);
            chunk(res->start, 1, ir_goto(n, left->start));
            chunk(left->success, 2, 
                  cond_ir_mark(right->uses_stack, n, mk), 
                  ir_goto(n, right->start));
            chunk(left->failure, 1, ir_goto(n, res->failure));
            chunk(right->failure, 2, 
                  cond_ir_unmark(right->uses_stack, n, mk),
                  ir_goto(n, left->resume));

            chunk(res->resume, 2, 
                  ir_resumevalue(n, target, clo->index, right->resume),
                  ir_goto(n, res->success));

            chunk(right->success, 3, 
                  ir_binclo(n, clo->index, n->op, lv, rv, rval, right->resume),
                  ir_move(n, target, clo, 0),
                  ir_goto(n, res->success));

            res->uses_stack = 1;

            break;
        }

        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            struct ir_stack **tiu;
            struct ir_info **info;
            int mk;

            if (x->n < 2)
                quitf("got slist with < 2 elements");

            mk = make_mark(st);
            tiu = mb_alloc(&ir_func_mb, (x->n - 1) * sizeof(struct ir_stack *));
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            for (i = 0; i < x->n - 1; ++i) {
                tiu[i] = branch_stack(st);
                info[i] = ir_traverse(x->child[i], tiu[i], 0, 1, 1);
            }
            info[x->n - 1] = ir_traverse(x->child[x->n - 1], st, target, bounded, rval);

            chunk(res->start, 2, 
                  cond_ir_mark(info[0]->uses_stack, n, mk), 
                  ir_goto(n, info[0]->start));
            if (!bounded) {
                chunk(res->resume, 1, ir_goto(n, info[x->n - 1]->resume));
            }

            for (i = 0; i < x->n - 2; ++i) {
                chunk(info[i]->success, 3,
                      cond_ir_unmark(info[i]->uses_stack, n, mk),
                      cond_ir_mark(info[i + 1]->uses_stack, n, mk),
                      ir_goto(n, info[i + 1]->start));
                chunk(info[i]->failure, 3,
                      cond_ir_unmark(info[i]->uses_stack, n, mk),
                      cond_ir_mark(info[i + 1]->uses_stack, n, mk),
                      ir_goto(n, info[i + 1]->start));
            }

            i = x->n - 2;
            chunk(info[i]->success, 2,
                  cond_ir_unmark(info[i]->uses_stack, n, mk),
                  ir_goto(n, info[i + 1]->start));
            chunk(info[i]->failure, 2,
                  cond_ir_unmark(info[i]->uses_stack, n, mk),
                  ir_goto(n, info[i + 1]->start));

            i = x->n - 1;
            chunk(info[i]->success, 1, ir_goto(n, res->success));
            chunk(info[i]->failure, 1, ir_goto(n, res->failure));
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
            chunk(res->start, 1, ir_goto(n, operand->start));
            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, operand->resume));
            chunk(operand->success, 2,
                  ir_unop(n, target, n->op, v, rval, operand->resume),
                  ir_goto(n, res->success));
            chunk(operand->failure, 1, ir_goto(n, res->failure));
            res->uses_stack = operand->uses_stack;
            break;
        }

        case Uop_Tabmat:	/* unary = operator */
        case Uop_Bang: {	/* unary ! operator */
            struct lnode_1 *x = (struct lnode_1 *)n;
            struct ir_var *v, *clo;
            struct ir_info *operand;
            clo = make_closure(st);
            v = get_var(x->child, st, target);
            operand = ir_traverse(x->child, st, v, 0, is_rval(n->op, 1, rval));
            chunk(res->start, 1, ir_goto(n, operand->start));
            chunk(res->resume, 2, 
                  ir_resumevalue(n, target, clo->index, operand->resume),
                  ir_goto(n, res->success));
            chunk(operand->success, 3, 
                  ir_unclo(n, clo->index, n->op, v, rval, operand->resume),
                  ir_move(n, target, clo, 0),
                  ir_goto(n, res->success));
            chunk(operand->failure, 1, ir_goto(n, res->failure));
            res->uses_stack = 1;
            break;
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            struct ir_var *clo, *fn, **args;
            struct ir_info *expr, **info;
            int i;
            int *mks;
            clo = make_closure(st);
            fn = make_tmp(st);
            args = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_var *));
            mks = mb_alloc(&ir_func_mb, x->n * sizeof(int));
            info = mb_alloc(&ir_func_mb, x->n * sizeof(struct ir_info *));
            for (i = 0; i < x->n; ++i)
                args[i] = get_var(x->child[i], st, 0);
            expr = ir_traverse(x->expr, st, fn, 0, 1);
            for (i = 0; i < x->n; ++i) {
                info[i] = ir_traverse(x->child[i], st, args[i], 0, 0);
                if (info[i]->uses_stack)
                    mks[i] = make_mark(st);
            }
            chunk(res->start, 1, 
                  ir_goto(n, expr->start));
            chunk(expr->failure, 1, ir_goto(n, res->failure));

            if (x->n == 0) {
                chunk(res->resume, 2,
                      ir_resumevalue(n, target, clo->index, expr->resume),
                      ir_goto(n, res->success));
                chunk(expr->success, 4,
                      ir_deref(n, fn, fn),
                      ir_invoke(n, clo->index, fn, x->n, args, expr->resume),
                      ir_move(n, target, clo, 0),
                      ir_goto(n, res->success));
            } else if (x->n == 1) {
                chunk(res->resume, 2,
                      ir_resumevalue(n, target, clo->index, info[0]->resume),
                      ir_goto(n, res->success));
                chunk(expr->success, 2,
                      cond_ir_mark(info[0]->uses_stack, n, mks[0]),
                      ir_goto(n, info[0]->start));
                chunk(info[0]->success, 4,
                      ir_deref(n, fn, fn),
                      ir_invoke(n, clo->index, fn, x->n, args, info[0]->resume),
                      ir_move(n, target, clo, 0),
                      ir_goto(n, res->success));
                chunk(info[0]->failure, 2,
                      cond_ir_unmark(info[0]->uses_stack, n, mks[0]),
                      ir_goto(n, expr->resume));
            } else { /* x->n > 1 */
                chunk(res->resume, 2,
                      ir_resumevalue(n, target, clo->index, info[x->n - 1]->resume),
                      ir_goto(n, res->success));
                chunk(expr->success, 2,
                      cond_ir_mark(info[0]->uses_stack, n, mks[0]),
                      ir_goto(n, info[0]->start));

                /* First one */
                chunk(info[0]->success, 2,
                      cond_ir_mark(info[1]->uses_stack, n, mks[1]),
                      ir_goto(n, info[1]->start));
                chunk(info[0]->failure, 2,
                      cond_ir_unmark(info[0]->uses_stack, n, mks[0]),
                      ir_goto(n, expr->resume));

                /* Middle ones */
                for (i = 1; i < x->n - 1; ++i) {
                    chunk(info[i]->success, 3,
                          cond_ir_unmark(info[i]->uses_stack, n, mks[i]),
                          cond_ir_mark(info[i + 1]->uses_stack, n, mks[i + 1]),
                          ir_goto(n, info[i + 1]->start));
                    chunk(info[i]->failure, 2,
                          cond_ir_unmark(info[i]->uses_stack, n, mks[i]),
                          ir_goto(n, info[i - 1]->resume));
                }

                /* Last one */
                i = x->n - 1;
                chunk(info[i]->success, 4,
                      ir_deref(n, fn, fn),
                      ir_invoke(n, clo->index, fn, x->n, args, info[x->n - 1]->resume),
                      ir_move(n, target, clo, 0),
                      ir_goto(n, res->success));
                chunk(info[i]->failure, 2,
                      cond_ir_unmark(info[i]->uses_stack, n, mks[i]),
                      ir_goto(n, info[i - 1]->resume));
            }

            res->uses_stack = 1;
            break;
        }

        case Uop_If: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int if_mk;
            struct ir_stack *if_st, *then_st;
            struct ir_info *expr, *then;

            if_mk = make_mark(st);

            if_st = branch_stack(st);
            expr = ir_traverse(x->child1, if_st, 0, 1, 1);

            then_st = branch_stack(st);
            then = ir_traverse(x->child2, then_st, target, bounded, rval);

            union_stack(st, then_st);

            chunk(res->start, 2,
                  cond_ir_mark(expr->uses_stack, n, if_mk),
                  ir_goto(n, expr->start));
            if (!bounded)
                chunk(res->resume, 1, ir_goto(n, expr->resume));
            chunk(expr->success, 2,
                  cond_ir_unmark(expr->uses_stack, n, if_mk),
                  ir_goto(n, then->start));
            chunk(expr->failure, 2,
                  cond_ir_unmark(expr->uses_stack, n, if_mk),
                  ir_goto(n, res->failure));
            chunk(then->success, 1, ir_goto(n, res->success));
            chunk(then->failure, 1, ir_goto(n, res->failure));
            res->uses_stack = then->uses_stack;
            break;
        }

        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            int if_mk;
            struct ir_stack *if_st, *then_st, *else_st;
            struct ir_info *expr, *then, *els;
            int tl;
            if (!bounded)
                tl = make_tmploc(st);
            if_mk = make_mark(st);

            if_st = branch_stack(st);
            expr = ir_traverse(x->child1, if_st, 0, 1, 1);

            then_st = branch_stack(st);
            then = ir_traverse(x->child2, then_st, target, bounded, rval);

            else_st = branch_stack(st);
            els = ir_traverse(x->child3, else_st, target, bounded, rval);

            union_stack(st, then_st);
            union_stack(st, else_st);

            chunk(res->start, 2,
                  cond_ir_mark(expr->uses_stack, n, if_mk),
                  ir_goto(n, expr->start));
            if (bounded) {
                chunk(expr->success, 2,
                      cond_ir_unmark(expr->uses_stack, n, if_mk),
                      ir_goto(n, then->start));
                chunk(expr->failure, 2,
                      cond_ir_unmark(expr->uses_stack, n, if_mk),
                      ir_goto(n, els->start));
            } else {
                chunk(expr->success, 3,
                      cond_ir_unmark(expr->uses_stack, n, if_mk),
                      ir_movelabel(n, tl, then->resume),
                      ir_goto(n, then->start));
                chunk(expr->failure, 2,
                      cond_ir_unmark(expr->uses_stack, n, if_mk),
                      ir_movelabel(n, tl, els->resume),
                      ir_goto(n, els->start));
                chunk(res->resume, 1, ir_igoto(n, tl));
            }

            chunk(then->success, 1, ir_goto(n, res->success));
            chunk(then->failure, 1, ir_goto(n, res->failure));
            chunk(els->success, 1, ir_goto(n, res->success));
            chunk(els->failure, 1, ir_goto(n, res->failure));

            res->uses_stack = then->uses_stack || els->uses_stack;
            break;
        }

        default:
            quitf("ir_traverse: illegal opcode(%d): %s in file %s\n", n->op, 
                  ucode_op_table[n->op].name, n->loc.file);
    }
    return res;
}

void generate_ir()
{
    struct ir_info *init = 0, *body = 0, *end;
    hi_chunk = -1;
    ir_start = 0;
    chunk_id_seq = 1;
    memset(chunks, 0, n_chunks_alloc * sizeof(struct chunk *));
    mb_clear(&ir_func_mb);
    hi_clo = hi_tmp = hi_lab = hi_mark = -1;

    if (curr_lfunc->initial->op != Uop_Empty)
        init = ir_traverse(curr_lfunc->initial, new_stack(), 0, 1, 1);

    if (curr_lfunc->body->op != Uop_Empty)
        body = ir_traverse(curr_lfunc->body, new_stack(), 0, 1, 1);

    end = ir_traverse(curr_lfunc->end, 0, 0, 1, 1);   /* Get the Uop_End */

    if (init) {
        if (body) {
            chunk(ir_start, 2, ir_enterinit(0, body->start), 
                                  ir_goto(0, init->start));
            chunk(init->success, 1, ir_goto(0, body->start));
            chunk(init->failure, 1, ir_goto(0, body->start));
            chunk(body->success, 1, ir_goto(0, end->start));
            chunk(body->failure, 1, ir_goto(0, end->start));
        }
        else {
            chunk(ir_start, 2, ir_enterinit(0, end->start), 
                                  ir_goto(0, init->start));
            chunk(init->success, 1, ir_goto(0, end->start));
            chunk(init->failure, 1, ir_goto(0, end->start));
        }
    } else {
        if (body) {
            chunk(ir_start, 1, ir_goto(0, body->start));
            chunk(body->success, 1, ir_goto(0, end->start));
            chunk(body->failure, 1, ir_goto(0, end->start));
        } else
            chunk(ir_start, 1, ir_goto(0, end->start));
    }
    optimize_goto();
    renumber_ir();
    dump_ir();
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
        case CLOSURE: {
            fprintf(stderr, "{closure %d}", v->index);
            break;
        }
        default: {
            fprintf(stderr, "{???}");
            break;
        }
    }
}

void dump_ir()
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        fprintf(stderr, "Chunk %d\n", chunk->id);
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_Goto: {
                    struct ir_goto *x = (struct ir_goto *)ir;
                    fprintf(stderr, "\tIr_Goto %d\n", x->dest);
                    break;
                }
                case Ir_IGoto: {
                    struct ir_igoto *x = (struct ir_igoto *)ir;
                    fprintf(stderr, "\tIr_IGoto %d\n", x->no);
                    break;
                }
                case Ir_EnterInit: {
                    struct ir_enterinit *x = (struct ir_enterinit *)ir;
                    fprintf(stderr, "\tIr_EnterInit %d\n", x->dest);
                    break;
                }
                case Ir_Fail: {
                    fprintf(stderr, "\tIr_Fail\n");
                    break;
                }
                case Ir_Mark: {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    fprintf(stderr, "\tIr_Mark %d\n", x->no);
                    break;
                }
                case Ir_Unmark: {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    fprintf(stderr, "\tIr_Unmark %d\n", x->no);
                    break;
                }
                case Ir_Move: {
                    struct ir_move *x = (struct ir_move *)ir;
                    fprintf(stderr, "\tIr_Move ");
                    print_ir_var(x->lhs);
                    fprintf(stderr, " <- ");
                    print_ir_var(x->rhs);
                    fprintf(stderr, ", rval=%d\n", x->rval);
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    fprintf(stderr, "\tIr_MoveLabel %d -> %d\n", x->lab, x->destno);
                    break;
                }
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    fprintf(stderr, "\tIr_Deref");
                    print_ir_var(x->src);
                    fprintf(stderr, " -> ");
                    print_ir_var(x->dest);
                    fprintf(stderr, "\n");
                    break;
                }
                case Ir_BinOp: {
                    struct ir_binop *x = (struct ir_binop *)ir;
                    fprintf(stderr, "\tIr_BinOp ");
                    print_ir_var(x->lhs);
                    fprintf(stderr, " <- ");
                    print_ir_var(x->arg1);
                    fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                    print_ir_var(x->arg2);
                    fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                    break;
                }
                case Ir_BinClo: {
                    struct ir_binclo *x = (struct ir_binclo *)ir;
                    fprintf(stderr, "\tIr_BinClo clo=%d, ", x->clo);
                    print_ir_var(x->arg1);
                    fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                    print_ir_var(x->arg2);
                    fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                    break;
                }
                case Ir_UnOp: {
                    struct ir_unop *x = (struct ir_unop *)ir;
                    fprintf(stderr, "\tIr_UnOp ");
                    print_ir_var(x->lhs);
                    fprintf(stderr, " <- %s ", ucode_op_table[x->operation].name);
                    print_ir_var(x->arg);
                    fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                    break;
                }
                case Ir_UnClo: {
                    struct ir_unclo *x = (struct ir_unclo *)ir;
                    fprintf(stderr, "\tIr_UnClo clo=%d, ", x->clo);
                    fprintf(stderr, " %s ", ucode_op_table[x->operation].name);
                    print_ir_var(x->arg);
                    fprintf(stderr, ", rval=%d fail_label=%d\n", x->rval, x->fail_label);
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    fprintf(stderr, "\tIr_KeyOp ");
                    print_ir_var(x->lhs);
                    fprintf(stderr, " <- keyword=%d rval=%d fail_label=%d\n", 
                            x->keyword, x->rval, x->fail_label);
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    fprintf(stderr, "\tIr_KeyClo clo=%d, keyword=%d fail_label=%d\n", 
                            x->clo, x->keyword, x->fail_label);
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    fprintf(stderr, "\tIr_Invoke");
                    fprintf(stderr, " clo=%d, ", x->clo);
                    print_ir_var(x->expr);
                    fprintf(stderr, "(");
                    for (i = 0; i < x->argc; ++i) {
                        print_ir_var(x->args[i]);
                        fprintf(stderr, ",");
                    }
                    fprintf(stderr, ")");
                    fprintf(stderr, ", fail_label=%d\n", x->fail_label);
                    break;
                }
                case Ir_ResumeValue: {
                    struct ir_resumevalue *x = (struct ir_resumevalue *)ir;
                    fprintf(stderr, "\tIr_ResumeValue");
                    print_ir_var(x->lhs);
                    fprintf(stderr, ", clo=%d fail_label=%d\n", x->clo, x->fail_label);
                    break;
                }
                default: {
                    fprintf(stderr, "\t???\n");
                    break;
                }
            }
        }
    }
}

static int augop(int n)
{
    int opcode = 0;

    switch (n) {

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
    if (!v)
        return;
    switch (v->type) {
        case TMP: {
            renumber_tmp(&v->index);
            break;
        }
        case CLOSURE: {
            renumber_clo(&v->index);
            break;
        }
    }
}

static void optimize_goto_chain(int *lab)
{
    static int marker = 0;
    struct chunk *chunk;
    if (*lab < 0)
        return;
    ++marker;
    while (1) {
        chunk = chunks[*lab];
        if (!chunk || chunk->n_inst == 0 || chunk->inst[0]->op != Ir_Goto || chunk->circle == marker)
            break;
        *lab = ((struct ir_goto *)chunk->inst[0])->dest;
        chunk->circle = marker;        
    }
}

static void optimize_goto()
{
    int i;
    optimize_goto1(ir_start);
    /* Eliminate unseen ones */
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (chunk && !chunk->seen)
            chunks[i] = 0;
    }
}

static void optimize_goto1(int i)
{
    int j;
    struct chunk *chunk;
    if (i < 0)
        return;
    chunk = chunks[i];
    if (!chunk || chunk->seen)
        return;
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
            case Ir_BinOp: {
                struct ir_binop *x = (struct ir_binop *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_BinClo: {
                struct ir_binclo *x = (struct ir_binclo *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_UnOp: {
                struct ir_unop *x = (struct ir_unop *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
            case Ir_UnClo: {
                struct ir_unclo *x = (struct ir_unclo *)ir;
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
            case Ir_ResumeValue: {
                struct ir_resumevalue *x = (struct ir_resumevalue *)ir;
                optimize_goto_chain(&x->fail_label);
                optimize_goto1(x->fail_label);
                break;
            }
        }
    }
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

                case Ir_EnterInit:
                case Ir_Fail:
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
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    renumber_var(x->src);
                    renumber_var(x->dest);
                    break;
                }
                case Ir_BinOp: {
                    struct ir_binop *x = (struct ir_binop *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    break;
                }
                case Ir_BinClo: {
                    struct ir_binclo *x = (struct ir_binclo *)ir;
                    renumber_var(x->arg1);
                    renumber_var(x->arg2);
                    renumber_clo(&x->clo);
                    break;
                }
                case Ir_UnOp: {
                    struct ir_unop *x = (struct ir_unop *)ir;
                    renumber_var(x->lhs);
                    renumber_var(x->arg);
                    break;
                }
                case Ir_UnClo: {
                    struct ir_unclo *x = (struct ir_unclo *)ir;
                    renumber_var(x->arg);
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
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    renumber_clo(&x->clo);
                    renumber_var(x->expr);
                    for (i = 0; i < x->argc; ++i)
                        renumber_var(x->args[i]);
                    break;
                }
                case Ir_ResumeValue: {
                    struct ir_resumevalue *x = (struct ir_resumevalue *)ir;
                    renumber_var(x->lhs);
                    renumber_clo(&x->clo);
                    break;
                }
                default: {
                    quitf("renumber: illegal ir opcode(%d)\n", ir->op);
                    break;
                }
            }
        }
    }
}
