#include "icont.h"
#include "link.h"
#include "ltree.h"
#include "ucode.h"
#include "tsym.h"
#include "lsym.h"
#include "lmem.h"

static struct loc curr_loc;
static struct lfunction *curr_lfunc = 0;
static struct lfile *lf;

struct lnode *lnode_0(int op)
{
    struct lnode *n = Alloc(struct lnode);
    n->op = op;
    n->loc = curr_loc;
    return n;
}

struct lnode_1 *lnode_1(int op, struct lnode *c)
{
    struct lnode_1 *n = Alloc(struct lnode_1);
    n->op = op;
    n->loc = curr_loc;
    n->child = c;
    c->parent = (struct lnode *)n;
    return n;
}

struct lnode_2 *lnode_2(int op, struct lnode *c1, struct lnode *c2)
{
    struct lnode_2 *n = Alloc(struct lnode_2);
    n->op = op;
    n->loc = curr_loc;
    n->child1 = c1;
    c1->parent = (struct lnode *)n;
    n->child2 = c2;
    c2->parent = (struct lnode *)n;
    return n;
}

struct lnode_3 *lnode_3(int op, struct lnode *c1, struct lnode *c2, struct lnode *c3)
{
    struct lnode_3 *n = Alloc(struct lnode_3);
    n->op = op;
    n->loc = curr_loc;
    n->child1 = c1;
    c1->parent = (struct lnode *)n;
    n->child2 = c2;
    c2->parent = (struct lnode *)n;
    n->child3 = c3;
    c3->parent = (struct lnode *)n;
    return n;
}

struct lnode_n *lnode_n(int op, int x)
{
    struct lnode_n *n = Alloc(struct lnode_n);
    n->op = op;
    n->loc = curr_loc;
    n->n = x;
    n->child = safe_alloc(x * sizeof(struct lnode *));
    return n;
}

struct lnode_field *lnode_field(struct lnode *c, char *fname)
{
    struct lnode_field *n = Alloc(struct lnode_field);
    n->op = Uop_Field;
    n->loc = curr_loc;
    n->child = c;
    c->parent = (struct lnode *)n;
    n->fname = fname;
    return n;
}

struct lnode_invoke *lnode_invoke(struct lnode *expr, int x)
{
    struct lnode_invoke *n = Alloc(struct lnode_invoke);
    n->op = Uop_Invoke;
    n->loc = curr_loc;
    n->n = x;
    n->expr = expr;
    n->child = safe_alloc(x * sizeof(struct lnode *));
    return n;
}

struct lnode_apply *lnode_apply(struct lnode *expr, struct lnode *args)
{
    struct lnode_apply *n = Alloc(struct lnode_apply);
    n->op = Uop_Apply;
    n->loc = curr_loc;
    n->expr = expr;
    n->args = args;
    return n;
}

struct lnode_keyword *lnode_keyword(int num)
{
    struct lnode_keyword *n = Alloc(struct lnode_keyword);
    n->op = Uop_Keyword;
    n->loc = curr_loc;
    n->num = num;
    return n;
}

struct lnode_local *lnode_local(struct lentry *local)
{
    struct lnode_local *n = Alloc(struct lnode_local);
    n->op = Uop_Local;
    n->loc = curr_loc;
    n->local = local;
    return n;
}

struct lnode_con *lnode_con(int op, struct centry *con)
{
    struct lnode_con *n = Alloc(struct lnode_con);
    n->op = op;
    n->loc = curr_loc;
    n->con = con;
    return n;
}

struct lnode_global *lnode_global(struct gentry *global)
{
    struct lnode_global *n = Alloc(struct lnode_global);
    n->op = Uop_Global;
    n->loc = curr_loc;
    n->global = global;
    return n;
}

struct lnode_case *lnode_case(int op, struct lnode *expr, int x)
{
    struct lnode_case *n = Alloc(struct lnode_case);
    n->op = op;
    n->loc = curr_loc;
    n->expr = expr;
    n->n = x;
    n->selector = safe_alloc(x * sizeof(struct lnode *));
    n->clause = safe_alloc(x * sizeof(struct lnode *));
    return n;
}


struct lnode *buildtree()
{
    struct ucode_op *uop;
    int op;

    while (1) {
        if (!(uop = uin_op()))
            quitf("nodecode: unexpected eof");
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
        case Uop_Fail:
        case Uop_Next:
            return (struct lnode *)lnode_0(op);

        case Uop_Slist: {
            int n = uin_16(), i;
            struct lnode_n *x = lnode_n(op, n);
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
        case Uop_Unions:
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
        case Uop_Alt: 
        case Uop_Conj: 
        case Uop_Scan:
        case Uop_Augscan:
        case Uop_Bactivate:
        case Uop_Augactivate:
        case Uop_Augconj: 
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Untildo: 
        case Uop_Suspenddo:
        case Uop_To:
        case Uop_Limit:
        case Uop_Everydo: {
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            return (struct lnode *)lnode_2(op, c1, c2);
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
        case Uop_Activate:
        case Uop_Create:
        case Uop_Suspend:
        case Uop_Until: 
        case Uop_Return: 
        case Uop_Break: {
            struct lnode *c = buildtree();
            return (struct lnode *)lnode_1(op, c);
        }

        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Toby:
        case Uop_Ifelse: {
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            struct lnode *c3 = buildtree();
            return (struct lnode *)lnode_3(op, c1, c2, c3);
        }

        case Uop_Field: {			/* field reference */
            char *s = uin_str();
            struct lnode *c = buildtree();
            return (struct lnode *)lnode_field(c, s);
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            int i, n = uin_16();
            struct lnode *e = buildtree();
            struct lnode_invoke *x = lnode_invoke(e, n);
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
            struct lnode_n *x = lnode_n(op, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                x->child[i] = y;
                y->parent = (struct lnode *)x;
            }
            return (struct lnode *)x;
        }

        case Uop_Apply: {			/* application e!l */
            struct lnode *c1 = buildtree();
            struct lnode *c2 = buildtree();
            return (struct lnode *)lnode_apply(c1, c2);
        }

        case Uop_Keyword: {			/* keyword reference */
            char *s = uin_str();
            return (struct lnode *)lnode_keyword(klookup(s));
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            int n = uin_16(), i;
            struct lnode *expr = buildtree();
            struct lnode_case *x = lnode_case(op, expr, n);
            for (i = 0; i < n; ++i) {
                struct lnode *y = buildtree();
                struct lnode *z = buildtree();
                x->selector[i] = y;
                y->parent = (struct lnode *)x;
                x->clause[i] = z;
                z->parent = (struct lnode *)x;
            }
            if (op == Uop_Casedef)        /* evaluate default clause */
                x->def = buildtree();
            return (struct lnode *)x;
        }

        case Uop_Int: 
        case Uop_Lrgint: 
        case Uop_Ucs: 
        case Uop_Cset: 
        case Uop_Real: 
        case Uop_Str: {
            int k = uin_16();
            struct centry *ce = curr_lfunc->constants;
            while (k--)
                ce = ce->next;
            return (struct lnode *)lnode_con(op, ce);
        }

        case Uop_Var: {
            int k, flags;
            struct lentry *lp = curr_lfunc->locals;
            k = uin_16();
            while (k--)
                lp = lp->next;
            flags = lp->l_flag;
            if (flags & F_Global)
                return (struct lnode *)lnode_global(lp->l_val.global);
            else if (flags & F_Field) {
                struct lnode *y;
                if (lp->l_val.field->flag & M_Static)  /* Ref to class var, eg Class.CONST */
                    y = (struct lnode *)lnode_global(lp->l_val.field->class->global);
                else                                   /* inst var, "self" is the 0th argument */
                    y = (struct lnode *)lnode_local(curr_lfunc->locals);
                return (struct lnode *)lnode_field(y, lp->l_val.field->name);
            }
            else
                return (struct lnode *)lnode_local(lp);
        }

        default:
            quitf("nodecode: illegal opcode(%d): %s in file %s\n", op, uop->name, lf->name);
    }

    /* Not reached */
    return 0;
}

static void loadtree_for(struct lfunction *f)
{
    curr_lfunc = f;
    curr_lfunc->initial = buildtree();
    curr_lfunc->body = buildtree();
    curr_lfunc->end = buildtree();
}

static void loadtree()
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
            quitf("cannot open .u for %s", inname);
        fseek(ucodefile, lf->declend_offset, SEEK_SET);
        loadtree();
        fclose(ucodefile);
    }
}
