#include "icont.h"
#include "link.h"
#include "ltree.h"
#include "ucode.h"
#include "tsym.h"
#include "lsym.h"
#include "lmem.h"
#include "keyword.h"

static struct loc curr_loc;
static struct lfile *lf;

struct lfunction *curr_vfunc;

struct lnode *lnode_0(int op, struct loc *loc)
{
    struct lnode *n = Alloc(struct lnode);
    n->op = op;
    n->loc = *loc;
    return n;
}

struct lnode_1 *lnode_1(int op, struct loc *loc, struct lnode *c)
{
    struct lnode_1 *n = Alloc(struct lnode_1);
    n->op = op;
    n->loc = *loc;
    n->child = c;
    c->parent = (struct lnode *)n;
    return n;
}

struct lnode_2 *lnode_2(int op, struct loc *loc, struct lnode *c1, struct lnode *c2)
{
    struct lnode_2 *n = Alloc(struct lnode_2);
    n->op = op;
    n->loc = *loc;
    n->child1 = c1;
    c1->parent = (struct lnode *)n;
    n->child2 = c2;
    c2->parent = (struct lnode *)n;
    return n;
}

struct lnode_3 *lnode_3(int op, struct loc *loc, struct lnode *c1, struct lnode *c2, struct lnode *c3)
{
    struct lnode_3 *n = Alloc(struct lnode_3);
    n->op = op;
    n->loc = *loc;
    n->child1 = c1;
    c1->parent = (struct lnode *)n;
    n->child2 = c2;
    c2->parent = (struct lnode *)n;
    n->child3 = c3;
    c3->parent = (struct lnode *)n;
    return n;
}

struct lnode_n *lnode_n(int op, struct loc *loc, int x)
{
    struct lnode_n *n = Alloc(struct lnode_n);
    n->op = op;
    n->loc = *loc;
    n->n = x;
    n->child = safe_zalloc(x * sizeof(struct lnode *));
    return n;
}

struct lnode_field *lnode_field(struct loc *loc, struct lnode *c, char *fname)
{
    struct lnode_field *n = Alloc(struct lnode_field);
    n->op = Uop_Field;
    n->loc = *loc;
    n->child = c;
    c->parent = (struct lnode *)n;
    n->fname = fname;
    return n;
}

struct lnode_invoke *lnode_invoke(int op, struct loc *loc, struct lnode *expr, int x)
{
    struct lnode_invoke *n = Alloc(struct lnode_invoke);
    n->op = op;
    n->loc = *loc;
    n->n = x;
    n->expr = expr;
    n->expr->parent = (struct lnode *)n;
    n->child = safe_zalloc(x * sizeof(struct lnode *));
    return n;
}

struct lnode_apply *lnode_apply(struct loc *loc, struct lnode *expr, struct lnode *args)
{
    struct lnode_apply *n = Alloc(struct lnode_apply);
    n->op = Uop_Apply;
    n->loc = *loc;
    n->expr = expr;
    n->expr->parent = (struct lnode *)n;
    n->args = args;
    n->args->parent = (struct lnode *)n;
    return n;
}

struct lnode_keyword *lnode_keyword(struct loc *loc, int num)
{
    struct lnode_keyword *n = Alloc(struct lnode_keyword);
    n->op = Uop_Keyword;
    n->loc = *loc;
    n->num = num;
    return n;
}

struct lnode_local *lnode_local(struct loc *loc, struct lentry *local)
{
    struct lnode_local *n = Alloc(struct lnode_local);
    n->op = Uop_Local;
    n->loc = *loc;
    n->local = local;
    return n;
}

struct lnode_const *lnode_const(struct loc *loc, struct centry *con)
{
    struct lnode_const *n = Alloc(struct lnode_const);
    n->op = Uop_Const;
    n->loc = *loc;
    n->con = con;
    return n;
}

struct lnode_global *lnode_global(struct loc *loc, struct gentry *global, struct lentry *local)
{
    struct lnode_global *n = Alloc(struct lnode_global);
    n->op = Uop_Global;
    n->loc = *loc;
    n->global = global;
    n->local = local;
    return n;
}

struct lnode_case *lnode_case(int op, struct loc *loc, struct lnode *expr, int x)
{
    struct lnode_case *n = Alloc(struct lnode_case);
    n->op = op;
    n->loc = *loc;
    n->expr = expr;
    n->expr->parent = (struct lnode *)n;
    n->n = x;
    n->selector = safe_zalloc(x * sizeof(struct lnode *));
    n->clause = safe_zalloc(x * sizeof(struct lnode *));
    return n;
}

/*
 * Lookup a method, given in the form class:method.  Returns 0 if not
 * found.
 */
static struct lclass_field *lookup_method(char *class, char *method)
{
    struct gentry *gl;
    struct lclass *cl;
    struct lclass_field *cf;

    /* Lookup the class in the global table. */
    gl = glocate(class);
    if (!gl)
        return 0;
    cl = gl->class;
    if (!cl)
        return 0;
    /* Lookup the method in the class's method table */
    cf = lookup_field(cl, method);
    /* Check it's a method and not a variable */
    if (!cf || !cf->func)
        return 0;
    return cf;
}

static struct lnode *buildtree(void)
{
    struct ucode_op *uop;
    int op;

    while (1) {
        if (!(uop = uin_op()))
            quit("buildtree: Unexpected eof");
        op = uop->opcode;
        if (op ==  Uop_Filen) {
            curr_loc.file = uin_str();
        } else if (op == Uop_Line) {
            curr_loc.line = uin_16();
        } else 
            break;
    }

    switch (op) {
        case Uop_Empty:
        case Uop_End:
        case Uop_Return:
        case Uop_Suspend:
        case Uop_Break:
        case Uop_Fail:
        case Uop_Next:
            return (struct lnode *)lnode_0(op, &curr_loc);

        case Uop_Slist: {
            int n = uin_16(), i;
            struct lnode_n *x = lnode_n(op, &curr_loc, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                x->child[i] = y;
                y->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_Asgn:
        case Uop_Power:
        case Uop_Cat:
        case Uop_Diff:
        case Uop_Eqv:
        case Uop_Inter:
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
        case Uop_Rasgn:
        case Uop_Rswap:
        case Uop_Div:
        case Uop_Mult:
        case Uop_Swap:
        case Uop_Union:
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
        case Uop_Augunion: 
        case Uop_Alt: 
        case Uop_Conj: 
        case Uop_Scan:
        case Uop_Augscan:
        case Uop_Augapply:
        case Uop_Bactivate:
        case Uop_Augactivate:
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Untildo: 
        case Uop_Suspenddo:
        case Uop_To:
        case Uop_Limit:
        case Uop_Everydo: {
            struct loc t = curr_loc;
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            return (struct lnode *)lnode_2(op, &t, c1, c2);
        }

        case Uop_Augconj: {
            struct loc t = curr_loc;
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            /* e1 &:= e2 -> e1 := e2 */
            return (struct lnode *)lnode_2(Uop_Asgn, &t, c1, c2);
        }

        case Uop_Value:
        case Uop_Nonnull:
        case Uop_Bang:
        case Uop_Refresh:
        case Uop_Number:
        case Uop_Compl:
        case Uop_Neg:
        case Uop_Tabmat:
        case Uop_Size:
        case Uop_Random:
        case Uop_Null: 
        case Uop_Rptalt:
        case Uop_Not:
        case Uop_Repeat: 
        case Uop_While:
        case Uop_Every:
        case Uop_Uactivate:
        case Uop_Create:
        case Uop_Suspendexpr:
        case Uop_Until: 
        case Uop_Returnexpr: 
        case Uop_Breakexpr: {
            struct loc t = curr_loc;
            struct lnode *c = buildtree();
            return (struct lnode *)lnode_1(op, &t, c);
        }

        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Toby:
        case Uop_Ifelse: {
            struct loc t = curr_loc;
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            struct lnode *c3 = buildtree();
            return (struct lnode *)lnode_3(op, &t, c1, c2, c3);
        }

        case Uop_Field: {			/* field reference */
            struct loc t = curr_loc;
            char *s = uin_str();
            struct lnode *c = buildtree();
            return (struct lnode *)lnode_field(&t, c, s);
        }

        case Uop_Subsc: {                      /* e[x1, x2.., xn] */
            int i, n = uin_16();
            struct loc t = curr_loc;
            struct lnode *e = buildtree();
            struct lnode_2 *x;
            if (n == 0)
                x = lnode_2(op, &t, e, (struct lnode *)lnode_keyword(&t, K_NULL));
            else {
                x = lnode_2(op, &t, e, buildtree());
                for (i = 1; i < n; ++i)
                    x = lnode_2(op, &t, (struct lnode *)x, buildtree());
            }
            return (struct lnode *)x;
        }

        case Uop_CoInvoke: {                    /* e{x1, x2.., xn} */
            int i, n = uin_16();
            struct loc t = curr_loc;
            struct lnode *e = buildtree();
            struct lnode_invoke *x = lnode_invoke(Uop_Invoke, &t, e, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                struct lnode_1 *z = lnode_1(Uop_Create, &y->loc, y);
                x->child[i] = (struct lnode *)z;
                z->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            int i, n = uin_16();
            struct loc t = curr_loc;
            struct lnode *e = buildtree();
            struct lnode_invoke *x = lnode_invoke(op, &t, e, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                x->child[i] = y;
                y->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_List:	                        /* list construction */
        case Uop_Mutual: {                      /* (e1,...,en) */
            int i, n = uin_16();
            struct lnode_n *x = lnode_n(op, &curr_loc, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                x->child[i] = y;
                y->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_Apply: {			/* application e!l */
            struct loc t = curr_loc;
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            return (struct lnode *)lnode_apply(&t, c1, c2);
        }

        case Uop_Keyword: {			/* keyword reference */
            int n = uin_16();
            return (struct lnode *)lnode_keyword(&curr_loc, n);
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            int n = uin_16(), i;
            struct loc t = curr_loc;
            struct lnode *expr = buildtree();
            struct lnode_case *x = lnode_case(op, &t, expr, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                struct lnode *z = buildtree();
                x->selector[i] = y;
                y->parent = (struct lnode *)x;
                x->clause[i] = z;
                z->parent = (struct lnode *)x;
            }
            if (op == Uop_Casedef) {        /* evaluate default clause */
                x->def = buildtree();
                x->def->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_Const: {
            int k = uin_16();
            struct centry *ce = curr_lfunc->constants;
            while (k--)
                ce = ce->next;
            return (struct lnode *)lnode_const(&curr_loc, ce);
        }

        case Uop_Var: {
            int k, flags;
            struct lentry *lp = curr_lfunc->locals;
            k = uin_16();
            while (k--)
                lp = lp->next;
            flags = lp->l_flag;
            if (flags & F_Global)
                return (struct lnode *)lnode_global(&curr_loc, lp->l_val.global, lp);
            else if (flags & F_Field) {
                struct lnode *y;
                if (lp->l_val.field->flag & M_Static)  /* Ref to class var, eg Class.CONST */
                    y = (struct lnode *)lnode_global(&curr_loc, lp->l_val.field->class->global, 0);
                else                                   /* inst var, "self" is the 0th argument */
                    y = (struct lnode *)lnode_local(&curr_loc, curr_lfunc->locals);
                return (struct lnode *)lnode_field(&curr_loc, y, lp->l_val.field->name);
            }
            else
                return (struct lnode *)lnode_local(&curr_loc, lp);
        }

        default:
            quit("buildtree: Illegal opcode(%d): %s in file %s\n", op, uop->name, lf->name);
    }

    /* Not reached */
    return 0;
}

static void loadtree_for(struct lfunction *f)
{
    struct loc *l;
    curr_lfunc = f;
    if (f->proc)
        l = &f->proc->pos;
    else
        l = &f->method->pos;
    curr_lfunc->start = lnode_0(Uop_Start, l);
    curr_lfunc->initial = buildtree();
    curr_lfunc->body = buildtree();
    curr_lfunc->end = buildtree();
}

static void loadtree(void)
{
    struct ucode_op *uop;
    int op;
    struct gentry *gp;
    while ((uop = uin_op())) {
        op = uop->opcode;
        switch (op) {
            case Uop_Proc: {
                char *s = uin_fqid(lf->package);
                if ((gp = glocate(s))) {
                    /*
                     * wanted procedure.
                     */
                    loadtree_for(gp->func);
                }
                break;
            }

            case Uop_Method: {
                char *class, *meth;
                struct lclass_field *method;
                class = uin_fqid(lf->package);
                meth = uin_str();
                if ((method = lookup_method(class, meth))) {
                    loadtree_for(method->func);
                }
                break;
            }

            case Uop_Filen:
                curr_loc.file = uin_str();
                break;

            case Uop_Line:
                curr_loc.line = uin_16();
                break;

            default:
                uin_skip(op);
                break;
        }
    }
}

void loadtrees()
{
    for (lf = lfiles; lf; lf = lf->next) {
        inname = lf->name;
        ucodefile = fopen(inname, ReadBinary);
        if (!ucodefile)
            equit("Cannot open .u for %s", inname);
        fseek(ucodefile, lf->declend_offset, SEEK_SET);
        loadtree();
        if (ferror(ucodefile) != 0)
            equit("Failed to read from ucode file %s", inname);
        fclose(ucodefile);
    }
}

static void visitnode_pre(struct lnode *n, visitf v)
{
    if (!v(n))
        return;

    switch (n->op) {
        case Uop_Start:
        case Uop_Keyword:
        case Uop_Const: 
        case Uop_Global: 
        case Uop_Local: 
        case Uop_Next:
        case Uop_Empty:
        case Uop_End:
        case Uop_Return:
        case Uop_Break:
        case Uop_Suspend:
        case Uop_Fail:
            break;

        case Uop_List: 
        case Uop_Mutual:
        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            for (i = 0; i < x->n; ++i)
                visitnode_pre(x->child[i], v);
            break;
        }

        case Uop_Value:
        case Uop_Nonnull:
        case Uop_Bang:
        case Uop_Refresh:
        case Uop_Number:
        case Uop_Compl:
        case Uop_Neg:
        case Uop_Tabmat:
        case Uop_Size:
        case Uop_Random:
        case Uop_Repeat: 
        case Uop_While: 
        case Uop_Null: 
        case Uop_Until: 
        case Uop_Every: 
        case Uop_Suspendexpr: 
        case Uop_Returnexpr: 
        case Uop_Breakexpr: 
        case Uop_Create: 
        case Uop_Uactivate: 
        case Uop_Rptalt: 
        case Uop_Not: {		
            struct lnode_1 *x = (struct lnode_1 *)n;
            visitnode_pre(x->child, v);
            break;
        }

        case Uop_Asgn:
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
        case Uop_Rasgn:
        case Uop_Rswap:
        case Uop_Div:
        case Uop_Mult:
        case Uop_Swap:
        case Uop_Union:
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
        case Uop_Augunion: 
        case Uop_Conj: 
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Alt: 
        case Uop_Untildo: 
        case Uop_Everydo: 
        case Uop_Suspenddo: 
        case Uop_Bactivate: 
        case Uop_Augactivate: 
        case Uop_Limit:
        case Uop_To: 
        case Uop_Scan:
        case Uop_Augapply:
        case Uop_Augscan: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            visitnode_pre(x->child1, v);
            visitnode_pre(x->child2, v);
            break;
        }

        case Uop_Toby: 
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            visitnode_pre(x->child1, v);
            visitnode_pre(x->child2, v);
            visitnode_pre(x->child3, v);
            break;
        }

        case Uop_Field: {			/* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            visitnode_pre(x->child, v);
            break;
        }

        case Uop_CoInvoke:                      /* e{x1, x2.., xn} */
        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            int i;
            visitnode_pre(x->expr, v);
            for (i = 0; i < x->n; ++i)
                visitnode_pre(x->child[i], v);
            break;
        }

        case Uop_Apply: {			/* application e!l */
            struct lnode_apply *x = (struct lnode_apply *)n;
            visitnode_pre(x->expr, v);
            visitnode_pre(x->args, v);
            break;
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            struct lnode_case *x = (struct lnode_case *)n;
            int i;
            visitnode_pre(x->expr, v);
            for (i = 0; i < x->n; ++i) {
                visitnode_pre(x->selector[i], v);
                visitnode_pre(x->clause[i], v);
            }
            if (n->op == Uop_Casedef)
                visitnode_pre(x->def, v);

            break;
        }


        default:
            quit("visitnode_pre: Illegal opcode(%d)", n->op);
    }
}

static void visitnode_post(struct lnode *n, visitf v)
{
    switch (n->op) {
        case Uop_Start:
        case Uop_Keyword:
        case Uop_Const: 
        case Uop_Global: 
        case Uop_Local: 
        case Uop_Next:
        case Uop_Empty:
        case Uop_End:
        case Uop_Break:
        case Uop_Suspend:
        case Uop_Return:
        case Uop_Fail:
            break;

        case Uop_List: 
        case Uop_Mutual:
        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            for (i = 0; i < x->n; ++i)
                visitnode_post(x->child[i], v);
            break;
        }

        case Uop_Value:
        case Uop_Nonnull:
        case Uop_Bang:
        case Uop_Refresh:
        case Uop_Number:
        case Uop_Compl:
        case Uop_Neg:
        case Uop_Tabmat:
        case Uop_Size:
        case Uop_Random:
        case Uop_Repeat: 
        case Uop_While: 
        case Uop_Null: 
        case Uop_Until: 
        case Uop_Every: 
        case Uop_Suspendexpr: 
        case Uop_Returnexpr: 
        case Uop_Breakexpr: 
        case Uop_Create: 
        case Uop_Uactivate: 
        case Uop_Rptalt: 
        case Uop_Not: {		
            struct lnode_1 *x = (struct lnode_1 *)n;
            visitnode_post(x->child, v);
            break;
        }

        case Uop_Asgn:
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
        case Uop_Rasgn:
        case Uop_Rswap:
        case Uop_Div:
        case Uop_Mult:
        case Uop_Swap:
        case Uop_Union:
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
        case Uop_Augunion: 
        case Uop_Conj: 
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Alt: 
        case Uop_Untildo: 
        case Uop_Everydo: 
        case Uop_Suspenddo: 
        case Uop_Bactivate: 
        case Uop_Augactivate: 
        case Uop_Limit:
        case Uop_To: 
        case Uop_Scan:
        case Uop_Augapply:
        case Uop_Augscan: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            visitnode_post(x->child1, v);
            visitnode_post(x->child2, v);
            break;
        }

        case Uop_Toby: 
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            visitnode_post(x->child1, v);
            visitnode_post(x->child2, v);
            visitnode_post(x->child3, v);
            break;
        }

        case Uop_Field: {			/* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            visitnode_post(x->child, v);
            break;
        }

        case Uop_CoInvoke:                      /* e{x1, x2.., xn} */
        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            int i;
            visitnode_post(x->expr, v);
            for (i = 0; i < x->n; ++i)
                visitnode_post(x->child[i], v);
            break;
        }

        case Uop_Apply: {			/* application e!l */
            struct lnode_apply *x = (struct lnode_apply *)n;
            visitnode_post(x->expr, v);
            visitnode_post(x->args, v);
            break;
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            struct lnode_case *x = (struct lnode_case *)n;
            int i;
            visitnode_post(x->expr, v);
            for (i = 0; i < x->n; ++i) {
                visitnode_post(x->selector[i], v);
                visitnode_post(x->clause[i], v);
            }
            if (n->op == Uop_Casedef)
                visitnode_post(x->def, v);

            break;
        }


        default:
            quit("visitnode_post: Illegal opcode(%d)", n->op);
    }

    v(n);
}

void visitfunc_pre(struct lfunction *f, visitf v)
{
    curr_vfunc = f;
    visitnode_pre(curr_vfunc->start, v);
    visitnode_pre(curr_vfunc->initial, v);
    visitnode_pre(curr_vfunc->body, v);
    visitnode_pre(curr_vfunc->end, v);
}

void visitfunc_post(struct lfunction *f, visitf v)
{
    curr_vfunc = f;
    visitnode_post(curr_vfunc->start, v);
    visitnode_post(curr_vfunc->initial, v);
    visitnode_post(curr_vfunc->body, v);
    visitnode_post(curr_vfunc->end, v);
}

void visit_pre(visitf v)
{
    struct gentry *gl;
    for (gl = lgfirst; gl; gl = gl->g_next) {
        if (gl->func)
            visitfunc_pre(gl->func, v);
        else if (gl->class) {
            struct lclass_field *me;
            for (me = gl->class->fields; me; me = me->next) {
                if (me->func && !(me->flag & (M_Defer | M_Abstract | M_Native))) 
                    visitfunc_pre(me->func, v);
            }
        }
    }
}

void visit_post(visitf v)
{
    struct gentry *gl;
    for (gl = lgfirst; gl; gl = gl->g_next) {
        if (gl->func)
            visitfunc_post(gl->func, v);
        else if (gl->class) {
            struct lclass_field *me;
            for (me = gl->class->fields; me; me = me->next) {
                if (me->func && !(me->flag & (M_Defer | M_Abstract | M_Native))) 
                    visitfunc_post(me->func, v);
            }
        }
    }
}

void replace_node(struct lnode *old, struct lnode *new)
{
    struct lnode *n = old->parent;
    if (verbose > 4) {
        fprintf(stderr, "Replacing node %s with %s at %s:%d\n",
                ucode_op_table[old->op].name,
                ucode_op_table[new->op].name,
                old->loc.file,old->loc.line);
    }
    if (!n) {
        if (curr_vfunc->initial == old)
            curr_vfunc->initial = new;
        else if (curr_vfunc->body == old)
            curr_vfunc->body = new;
        else
            quit("Root node doesn't match curr_vfunc initial or body");
        return;
    }

    new->parent = n;
    switch (n->op) {
        case Uop_Keyword:
        case Uop_Const: 
        case Uop_Global: 
        case Uop_Local: 
        case Uop_Next:
        case Uop_Empty:
        case Uop_End:
        case Uop_Break:
        case Uop_Suspend:
        case Uop_Return:
        case Uop_Fail:
            break;

        case Uop_List: 
        case Uop_Mutual:
        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            for (i = 0; i < x->n; ++i) {
                if (x->child[i] == old) {
                    x->child[i] = new;
                    return;
                }
            }
            break;
        }

        case Uop_Value:
        case Uop_Nonnull:
        case Uop_Bang:
        case Uop_Refresh:
        case Uop_Number:
        case Uop_Compl:
        case Uop_Neg:
        case Uop_Tabmat:
        case Uop_Size:
        case Uop_Random:
        case Uop_Repeat: 
        case Uop_While: 
        case Uop_Null: 
        case Uop_Until: 
        case Uop_Every: 
        case Uop_Suspendexpr: 
        case Uop_Returnexpr: 
        case Uop_Breakexpr: 
        case Uop_Create: 
        case Uop_Uactivate: 
        case Uop_Rptalt: 
        case Uop_Not: {		
            struct lnode_1 *x = (struct lnode_1 *)n;
            if (x->child == old) {
                x->child = new;
                return;
            }
            break;
        }

        case Uop_Asgn:
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
        case Uop_Rasgn:
        case Uop_Rswap:
        case Uop_Div:
        case Uop_Mult:
        case Uop_Swap:
        case Uop_Union:
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
        case Uop_Augunion: 
        case Uop_Conj: 
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Alt: 
        case Uop_Untildo: 
        case Uop_Everydo: 
        case Uop_Suspenddo: 
        case Uop_Bactivate: 
        case Uop_Augactivate: 
        case Uop_Limit:
        case Uop_To: 
        case Uop_Scan:
        case Uop_Augapply:
        case Uop_Augscan: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            if (x->child1 == old) {
                x->child1 = new;
                return;
            }
            if (x->child2 == old) {
                x->child2 = new;
                return;
            }
            break;
        }

        case Uop_Toby: 
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            if (x->child1 == old) {
                x->child1 = new;
                return;
            }
            if (x->child2 == old) {
                x->child2 = new;
                return;
            }
            if (x->child3 == old) {
                x->child3 = new;
                return;
            }
            break;
        }

        case Uop_Field: {			/* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            if (x->child == old) {
                x->child = new;
                return;
            }
            break;
        }

        case Uop_CoInvoke:                      /* e{x1, x2.., xn} */
        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            int i;
            if (x->expr == old) {
                x->expr = new;
                return;
            }
            for (i = 0; i < x->n; ++i) {
                if (x->child[i] == old) {
                    x->child[i] = new;
                    return;
                }
            }

            break;
        }

        case Uop_Apply: {			/* application e!l */
            struct lnode_apply *x = (struct lnode_apply *)n;
            if (x->expr == old) {
                x->expr = new;
                return;
            }
            if (x->args == old) {
                x->args = new;
                return;
            }
            break;
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            struct lnode_case *x = (struct lnode_case *)n;
            int i;
            if (x->expr == old) {
                x->expr = new;
                return;
            }
            for (i = 0; i < x->n; ++i) {
                if (x->selector[i] == old) {
                    x->selector[i] = new;
                    return;
                }
                if (x->clause[i] == old) {
                    x->clause[i] = new;
                    return;
                }
            }
            if (n->op == Uop_Casedef) {
                if (x->def == old) {
                    x->def = new;
                    return;
                }
            }
            break;
        }

        default:
            quit("replace_child: Illegal opcode(%d)", n->op);
    }

    quit("replace_child: Old child node not found in parent node");
}
