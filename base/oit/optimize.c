#include "icont.h"
#include "link.h"
#include "ltree.h"
#include "ucode.h"
#include "tsym.h"
#include "lsym.h"
#include "lmem.h"
#include "lglob.h"
#include "keyword.h"

enum literaltype { NUL, FAIL, CSET, STRING, UCS, INTEGER, REAL };

struct literal {
    int type;
    union {
        struct {
            char *s;
            int len;
        } str;
        word i;
        double d;
        struct rangeset *rs;
    } u;
};


#define CvtFail        -2
#define Less           -1
#define Equal           0
#define Greater         1
#define Failed		-5
#define Succeeded	-7

static word cvpos(word pos, word len);
static word cvpos_item(word pos, word len);
static int cvslice(word *i, word *j, word len);
static int changes(struct lnode *n);
static int lexcmp(struct literal *x, struct literal *y);
static int equiv(struct literal *x, struct literal *y);

static int cnv_ucs(struct literal *s);
static int need_ucs(struct literal *s);
static int cnv_cset(struct literal *s);
static int cnv_string(struct literal *s);
static int get_literal_cset(struct lnode *n, struct literal *l);
static int cnv_eint(struct literal *s);
static int cnv_int(struct literal *s);
static int cnv_real(struct literal *s);

static int get_literal(struct lnode *n, struct literal *res);
static void free_literal(struct literal *l);

static void fold_simple1(struct lnode *n);
static void fold_simple2(struct lnode *n);
static void fold_simplen(struct lnode *n);
static void fold_limit(struct lnode *n);
static void fold_value(struct lnode *n);
static void fold_number(struct lnode *n);
static void fold_field(struct lnode *n);
static void fold_null(struct lnode *n);
static void fold_nonnull(struct lnode *n);
static void fold_if(struct lnode *n);
static void fold_ifelse(struct lnode *n);
static void fold_until(struct lnode *n);
static void fold_untildo(struct lnode *n);
static void fold_not(struct lnode *n);
static void fold_alt(struct lnode *n);
static void fold_conj(struct lnode *n);
static void fold_lexeq(struct lnode *n);
static void fold_lexge(struct lnode *n);
static void fold_lexgt(struct lnode *n);
static void fold_lexle(struct lnode *n);
static void fold_lexlt(struct lnode *n);
static void fold_lexne(struct lnode *n);
static void fold_numeq(struct lnode *n);
static void fold_numge(struct lnode *n);
static void fold_numgt(struct lnode *n);
static void fold_numle(struct lnode *n);
static void fold_numlt(struct lnode *n);
static void fold_numne(struct lnode *n);
static void fold_size(struct lnode *n);
static void fold_cat(struct lnode *n);
static void fold_compl(struct lnode *n);
static void fold_union(struct lnode *n);
static void fold_inter(struct lnode *n);
static void fold_diff(struct lnode *n);
static void fold_subsc(struct lnode *n);
static void fold_neg(struct lnode *n);
static void fold_sect(struct lnode *n, int op);
static void fold_div(struct lnode *n);
static void fold_mod(struct lnode *n);
static void fold_mult(struct lnode *n);
static void fold_minus(struct lnode *n);
static void fold_plus(struct lnode *n);
static void fold_power(struct lnode *n);
static void fold_eqv(struct lnode *n);
static void fold_neqv(struct lnode *n);
static void fold_case(struct lnode *n);
static void fold_to(struct lnode *n);
static void fold_toby(struct lnode *n);
static void fold_invoke(struct lnode *n);
static void fold_apply(struct lnode *n);
static void fold_keyword(struct lnode *n);
static void fold_return(struct lnode *n);

static struct rangeset *rangeset_union(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_inter(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_diff(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_compl(struct rangeset *x);
static int cset_range_of_pos(struct rangeset *rs, word pos, int *count);
static int cset_size(struct rangeset *rs);
static int ucs_length(char *utf8, int utf8_len);
static int numeric_via_string(struct literal *src);

static struct str_buf opt_sbuf;

static struct rangeset *k_ascii_rangeset;
static struct rangeset *k_cset_rangeset;
static struct rangeset *k_lcase_rangeset;
static struct rangeset *k_letters_rangeset;
static struct rangeset *k_ucase_rangeset;
static struct rangeset *k_uset_rangeset;
static struct rangeset *k_digits_rangeset;

static int fold_consts(struct lnode *n)
{
    switch (n->op) {
        case Uop_To: {
            fold_to(n);
            break;
        }

        case Uop_Toby: {
            fold_toby(n);
            break;
        }

        case Uop_Field: {
            fold_field(n);
            break;
        }

        case Uop_Value: {
            fold_value(n);
            break;
        }

        case Uop_Number: {
            fold_number(n);
            break;
        }

        case Uop_Null: {
            fold_null(n);
            break;
        }

        case Uop_Nonnull: {
            fold_nonnull(n);
            break;
        }

        case Uop_Case:
        case Uop_Casedef: {
            fold_case(n);
            break;
        }

        case Uop_Mutual:
        case Uop_List: {
            fold_simplen(n);
            break;
        }

        case Uop_Invoke: {
            fold_invoke(n);
            break;
        }

        case Uop_Apply: {
            fold_apply(n);
            break;
        }

        case Uop_Power: {
            fold_power(n);
            break;
        }

        case Uop_Bactivate: 
        case Uop_Lconcat:
        case Uop_Everydo:
        case Uop_Suspenddo:
        case Uop_Whiledo:
        case Uop_Scan: {
            fold_simple2(n);
            break;
        }

        case Uop_Limit: {
            fold_limit(n);
            break;
        }

        case Uop_Eqv: {
            fold_eqv(n);
            break;
        }

        case Uop_Neqv: {
            fold_neqv(n);
            break;
        }

        case Uop_If: {
            fold_if(n);
            break;
        }

        case Uop_Ifelse: {
            fold_ifelse(n);
            break;
        }

        case Uop_Until: {
            fold_until(n);
            break;
        }

        case Uop_Untildo: {
            fold_untildo(n);
            break;
        }

        case Uop_Not: {
            fold_not(n);
            break;
        }

        case Uop_Alt: {
            fold_alt(n);
            break;
        }

        case Uop_Uactivate:
        case Uop_Every:
        case Uop_Suspendexpr:
        case Uop_While:
        case Uop_Bang:
        case Uop_Random:
        case Uop_Tabmat:
        case Uop_Rptalt: {
            fold_simple1(n);
            break;
        }

        case Uop_Linkexpr: 
        case Uop_Succeedexpr: 
        case Uop_Returnexpr: {
            fold_return(n);
            break;
        }

        case Uop_Conj: {
            fold_conj(n);
            break;
        }

        case Uop_Lexeq: {
            fold_lexeq(n);
            break;
        }

        case Uop_Lexge: {
            fold_lexge(n);
            break;
        }

        case Uop_Lexgt: {
            fold_lexgt(n);
            break;
        }

        case Uop_Lexle: {
            fold_lexle(n);
            break;
        }

        case Uop_Lexlt: {
            fold_lexlt(n);
            break;
        }

        case Uop_Lexne: {
            fold_lexne(n);
            break;
        }

        case Uop_Numeq: {
            fold_numeq(n);
            break;
        }

        case Uop_Numge: {
            fold_numge(n);
            break;
        }

        case Uop_Numgt: {
            fold_numgt(n);
            break;
        }

        case Uop_Numle: {
            fold_numle(n);
            break;
        }

        case Uop_Numlt: {
            fold_numlt(n);
            break;
        }

        case Uop_Numne: {
            fold_numne(n);
            break;
        }

        case Uop_Size: {
            fold_size(n);
            break;
        }

        case Uop_Compl: {
            fold_compl(n);
            break;
        }

        case Uop_Cat: {
            fold_cat(n);
            break;
        }
            
        case Uop_Union: {
            fold_union(n);
            break;
        }

        case Uop_Inter: {
            fold_inter(n);
            break;
        }

        case Uop_Diff: {
            fold_diff(n);
            break;
        }

        case Uop_Subsc: {
            fold_subsc(n);
            break;
        }

        case Uop_Neg: {
            fold_neg(n);
            break;
        }

        case Uop_Sect: 
        case Uop_Sectm:
        case Uop_Sectp: {
            fold_sect(n, n->op);
            break;
        }

        case Uop_Div: {
            fold_div(n);
            break;
        }

        case Uop_Mod: {
            fold_mod(n);
            break;
        }

        case Uop_Mult: {
            fold_mult(n);
            break;
        }

        case Uop_Minus: {
            fold_minus(n);
            break;
        }

        case Uop_Plus: {
            fold_plus(n);
            break;
        }

        case Uop_Keyword: {
            fold_keyword(n);
            break;
        }
    }
    return 1;
}

/*
 * Either return a matching existing const in curr_vfunc, or add a new
 * one.
 */
static struct centry *new_constant(int flags, char *data, int len)
{
    struct centry *c;
    for (c = curr_vfunc->constants; c; c = c->next) {
        if (flags == c->c_flag && data == c->data)
            return c;
    }
    return add_constant(curr_vfunc, flags, data, len);
}

/*
 * Tidy the functions' local and constant lists by removing entries
 * made redundant by dead code elimination and constant folding.
 * Unreferenced constants are removed, as are unreferenced global
 * references in the local list.  scanrefs() can then be called again
 * to eliminate no-longer needed globals from the global list.
 */
static int tidy_lists(struct lnode *n)
{
    switch (n->op) {
        case Uop_Start: {
            struct centry *c;
            struct lentry *l;
            for (c = curr_vfunc->constants; c; c = c->next)
                c->ref = 0;
            for (l = curr_vfunc->locals; l; l = l->next)
                l->ref = 0;
            break;
        }

        case Uop_Global: {
            struct lnode_global *x = (struct lnode_global *)n;
            if (x->local)  /* The local ref will be null for a resolved class field */
                x->local->ref = 1;
            break;
        }

        case Uop_Const: {
            struct lnode_const *x = (struct lnode_const *)n;
            x->con->ref = 1;
            break;
        }

        case Uop_End: {
            struct centry **cp, *c;
            struct lentry **lp, *l;
            cp = &curr_vfunc->constants;
            while ((c = *cp)) {
                if (c->ref)
                    cp = &c->next;
                else
                    *cp = c->next;
            }
            lp = &curr_vfunc->locals;
            while ((l = *lp)) {
                if (l->ref || !(l->l_flag & F_Global))
                    lp = &l->next;
                else
                    *lp = l->next;
            }
            break;
        }
    }
    return 1;
}

static int changes(struct lnode *n)
{
    while (n->parent) {
        /*printf("%s\n",ucode_op_table[n->parent->op].name);*/
        switch (n->parent->op) {
            case Uop_To: 
            case Uop_Toby: 
            case Uop_Neg:
            case Uop_Tabmat:
            case Uop_Size:
            case Uop_Random:
            case Uop_Bang:
            case Uop_Number:
            case Uop_Value:
            case Uop_Field:
            case Uop_Invoke:
            case Uop_Apply:
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
            case Uop_Div:
            case Uop_Mult:
            case Uop_Union:
            case Uop_Scan:
            case Uop_Bactivate:
            case Uop_While:
            case Uop_Whiledo: 
            case Uop_Repeat: 
            case Uop_Every: 
            case Uop_Everydo: 
            case Uop_Until: 
            case Uop_Untildo:
                return 0;

            case Uop_Subsc:
            case Uop_Asgn:
            case Uop_Rasgn:
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
            case Uop_Augactivate: 
            case Uop_Augapply:
            case Uop_Augscan: {
                struct lnode_2 *x = (struct lnode_2 *)n->parent;
                return x->child1 == n;
            }

            case Uop_Rswap:
            case Uop_Swap: {
                struct lnode_2 *x = (struct lnode_2 *)n->parent;
                return x->child1 == n || x->child2 == n;
            }

            case Uop_Sect: 
            case Uop_Sectm:
            case Uop_Sectp: {
                struct lnode_3 *x = (struct lnode_3 *)n->parent;
                return x->child1 == n;
            }

            case Uop_Breakexpr: 
            case Uop_Create: 
            case Uop_Suspendexpr: 
            case Uop_Returnexpr: {
                /* x->child should = n */
                return 1;
            }

            case Uop_Suspenddo: {
                struct lnode_2 *x = (struct lnode_2 *)n;
                return x->child1 == n;
            }

            case Uop_Case:
            case Uop_Casedef: {
                int i;
                struct lnode_case *x = (struct lnode_case *)n->parent;
                if (x->expr == n)
                    return 0;
                for (i = 0; i < x->n; ++i) {
                    if (x->selector[i] == n)
                        return 0;
                }
                /* n must be one of the clauses, so continue up */
                break;
            } 

            case Uop_If: {
                struct lnode_2 *x = (struct lnode_2 *)n->parent;
                if (x->child1 == n)
                    return 0;
                break;
            }

            case Uop_Ifelse: {
                struct lnode_3 *x = (struct lnode_3 *)n->parent;
                if (x->child1 == n)
                    return 0;
                break;
            }
        }
        n = n->parent;
    }
    return 0;
}

static struct lclass *vclass;

static int visit_init_assign(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct lnode_field *y;
    struct lnode_global *z;
    struct lclass_field *f;

    if (x->child1->op != Uop_Field)
        return 1;

    /*
     * Check the assign is at the top level in the method; eg not something like
     * if ... then CONST := 100
     */
    if (!(n->parent == 0 || (n->parent->op == Uop_Slist && n->parent->parent == 0)))
        return 1;

    y = (struct lnode_field *)x->child1;
    if (y->child->op != Uop_Global)
        return 1;
    z = (struct lnode_global *)y->child;
    if (z->global->class != vclass)
        return 1;
    f = lookup_field(vclass, y->fname);
    if (!f)
        return 1;
    if ((f->flag & (M_Static | M_Const)) != (M_Static | M_Const))
        return 1;

    if (x->child2->op == Uop_Const) {
        struct centry *ce = ((struct lnode_const *)x->child2)->con;
        if (f->const_flag == NOT_SEEN) {
            f->const_val = ce;
            f->const_flag = SET_CONST;
        } else
            f->const_flag = OTHER;
        /* Return 0 so that we don't traverse the lhs (and call visit_init_field below) */
        return 0;
    } else if (x->child2->op == Uop_Keyword) {
        int k = ((struct lnode_keyword *)x->child2)->num;
        if (k == K_NULL) {
            if (f->const_flag == NOT_SEEN)
                f->const_flag = SET_NULL;
            else
                f->const_flag = OTHER;
            return 0;
        } else if (k == K_YES) {
            if (f->const_flag == NOT_SEEN)
                f->const_flag = SET_YES;
            else
                f->const_flag = OTHER;
            return 0;
        }
    }
    return 1;
}

static int visit_init_field(struct lnode *n)
{
    struct lnode_field *x = (struct lnode_field *)n;
    struct lclass_field *f;
    f = lookup_field(vclass, x->fname);
    if (f && ((f->flag & (M_Static | M_Const)) == (M_Static | M_Const))) {
        if (changes(n))
            f->const_flag = OTHER;
    }
    return 0;
}

static int visit_init_method(struct lnode *n)
{
    switch (n->op) {
        case Uop_Asgn: {
            return visit_init_assign(n);
        }
        case Uop_Field: {
            return visit_init_field(n);
        }
    }
    return 1;
}

static void compute_class_consts(void)
{
    if (verbose > 3)
        fprintf(stderr, "Static constant analysis:\n\n");
    for (vclass = lclasses; vclass; vclass = vclass->next) {
        struct lclass_field *f = lookup_field(vclass, init_string);
        if (f) {
            visitfunc_post(f->func, fold_consts);
            visitfunc_pre(f->func, visit_init_method);
        }
        if (verbose > 3) {
            struct lclass_field *cf;
            fprintf(stderr, "Class %s\n", vclass->global->name);
            for (cf = vclass->fields; cf; cf = cf->next) {
                if ((cf->flag & (M_Static | M_Const)) == (M_Static | M_Const)) {
                    fprintf(stderr, "\tStatic constant %s: ", cf->name);
                    switch (cf->const_flag) {
                        case NOT_SEEN: fprintf(stderr, "NOT_SEEN\n"); break;
                        case SET_NULL: fprintf(stderr, "SET_NULL\n"); break;
                        case SET_YES: fprintf(stderr, "SET_YES\n"); break;
                        case SET_CONST: fprintf(stderr, "SET_CONST\n"); break;
                        case OTHER: fprintf(stderr, "OTHER\n"); break;
                    }
                }
            }
        }
    }
}

static void init_rangesets(void)
{
    k_ascii_rangeset = init_rangeset();
    add_range(k_ascii_rangeset, 0, 127);

    k_cset_rangeset = init_rangeset();
    add_range(k_cset_rangeset, 0, 255);

    k_lcase_rangeset = init_rangeset();
    add_range(k_lcase_rangeset, 'a', 'z');

    k_letters_rangeset = init_rangeset();
    add_range(k_letters_rangeset, 'A', 'Z');
    add_range(k_letters_rangeset, 'a', 'z');

    k_ucase_rangeset = init_rangeset();
    add_range(k_ucase_rangeset, 'A', 'Z');

    k_uset_rangeset = init_rangeset();
    add_range(k_uset_rangeset, 0, MAX_CODE_POINT);
                
    k_digits_rangeset = init_rangeset();
    add_range(k_digits_rangeset, '0', '9');
}

void optimize()
{
    init_rangesets();
    compute_class_consts();
    visit_post(fold_consts);
    visit_post(tidy_lists);
    if (!strinv) {
        if (methinv)
            scanrefs();
        else
            scanrefs2();
    }
}

static int cnv_eint(struct literal *s)
{
    switch (s->type) {
        case INTEGER: {
            return 1;
        }
        case REAL: {
            return 0;
        }
        default: {
            return numeric_via_string(s) && cnv_eint(s);
        }
    }

    return 0;
}

static int cnv_int(struct literal *s)
{
    switch (s->type) {
        case INTEGER: {
            return 1;
        }
        case REAL: {
            /* Same tests as realtobig() that would return a normal int. */
            if (isfinite(s->u.d) && 
                s->u.d >= Max(MinWord,-Big) && s->u.d <= Min(MaxWord,Big)) {
                s->type = INTEGER;
                s->u.i = (word)s->u.d;
                return 1;
            } else
                return 0;
        }
        default: {
            return numeric_via_string(s) && cnv_int(s);
        }
    }

    return 0;
}

static int cnv_real(struct literal *s)
{
    switch (s->type) {
        case INTEGER: {
            s->type = REAL;
            s->u.d = (double)s->u.i;
            return 1;
        }
        case REAL: {
            return 1;
        }
        default: {
            return numeric_via_string(s) && cnv_real(s);
        }
    }

    return 0;
}

static int cnv_string(struct literal *s)
{
    switch (s->type) {
        case STRING: {
            return 1;
        }
        case UCS: {
            s->type = STRING;
            return 1;
        }
        case CSET: {
            int npair = s->u.rs->n_ranges;
            if (npair == 0 || s->u.rs->range[npair - 1].to < 256) {
                int i, j;
                zero_sbuf(&opt_sbuf);
                for (i = 0; i < npair; ++i) {
                    word from, to;
                    from = s->u.rs->range[i].from;
                    to = s->u.rs->range[i].to;
                    for (j = from; j <= to; ++j) 
                        AppChar(opt_sbuf, j);
                }
                free_rangeset(s->u.rs);
                s->type = STRING;
                s->u.str.len = CurrLen(opt_sbuf);
                s->u.str.s = str_install(&opt_sbuf);
                return 1;
            }
            break;
        }
        case INTEGER: {
            char *t = word2cstr(s->u.i);
            s->type = STRING;
            s->u.str.len = strlen(t);
            s->u.str.s = intern(t);
            return 1;
        }
        case REAL: {
            char *t = double2cstr(s->u.d);
            s->type = STRING;
            s->u.str.len = strlen(t);
            s->u.str.s = intern(t);
            return 1;
        }
    }

    return 0;
}

static int cnv_ucs(struct literal *s)
{
    switch (s->type) {
        case UCS: {
            return 1;
        }
        case CSET: {
            int i, j, npair = s->u.rs->n_ranges;
            zero_sbuf(&opt_sbuf);
            for (i = 0; i < npair; ++i) {
                word from, to;
                from = s->u.rs->range[i].from;
                to = s->u.rs->range[i].to;
                for (j = from; j <= to; ++j) {
                    char buf[MAX_UTF8_SEQ_LEN];
                    int n = utf8_seq(j, buf);
                    append_n(&opt_sbuf, buf, n);
                }
            }
            free_rangeset(s->u.rs);
            s->type = UCS;
            s->u.str.len = CurrLen(opt_sbuf);
            s->u.str.s = str_install(&opt_sbuf);
            return 1;
        }
        default: {
            char *s1, *e1;
            if (!cnv_string(s))
                return 0;
            /* Check valid utf8 */
            s1 = s->u.str.s;
            e1 = s1 + s->u.str.len;
            while (s1 < e1) {
                int i = utf8_check(&s1, e1);
                if (i < 0 || i > MAX_CODE_POINT)
                    return 0;
            }
            s->type = UCS;    /* Valid, so just change the type */
            return 1;
        }
    }

    return 0;
}


static int cnv_cset(struct literal *s)
{
    switch (s->type) {
        case CSET: {
            return 1;
        }
        case UCS: {
            char *p, *e;
            struct rangeset *rs;
            p = s->u.str.s;
            e = p + s->u.str.len;
            rs = init_rangeset();
            while (p < e) {
                int i = utf8_iter(&p);
                add_range(rs, i, i);
            }
            s->type = CSET;
            s->u.rs = rs;
            return 1;
        }
        default: {
            word i;
            char *p;
            struct rangeset *rs;
            if (!cnv_string(s))
                return 0;
            rs = init_rangeset();
            p = s->u.str.s;
            i = s->u.str.len;
            while (i--) {
                int j = *p++ & 0xff;
                add_range(rs, j, j);
            }
            s->type = CSET;
            s->u.rs = rs;
            return 1;
        }
    }
    return 0;
}

static int need_ucs(struct literal *s)
{
    switch (s->type) {
        case UCS: {
            return 1;
        }
        case CSET: {
            int npair = s->u.rs->n_ranges;
            if (npair == 0 || s->u.rs->range[npair - 1].to < 256)
                return 0;
            else
                return 1;
        }
        default: {
            return 0;
        }
    }
}

static struct rangeset *rangeset_diff(struct rangeset *x, struct rangeset *y)
{
    struct rangeset *rs, *y_comp;
    word i_x, i_y, prev = 0;

    y_comp = init_rangeset();
    rs = init_rangeset();
    /*
     * Calculate ~y
     */
    for (i_y = 0; i_y < y->n_ranges; ++i_y) {
        word from = y->range[i_y].from;
        word to = y->range[i_y].to;
        if (from > prev)
            add_range(y_comp, prev, from - 1);
        prev = to + 1;
    }
    if (prev <= MAX_CODE_POINT)
        add_range(y_comp, prev, MAX_CODE_POINT);

    /*
     * Calculate x ** ~y
     */
    i_x = i_y = 0;
    while (i_x < x->n_ranges &&
           i_y < y_comp->n_ranges) {
        word from_x = x->range[i_x].from;
        word to_x = x->range[i_x].to;
        word from_y = y_comp->range[i_y].from;
        word to_y = y_comp->range[i_y].to;
        if (to_x < to_y) {
            add_range(rs, Max(from_x, from_y), to_x);
            ++i_x;
        }
        else {
            add_range(rs, Max(from_x, from_y), to_y);
            ++i_y;
        }
    }
    free_rangeset(y_comp);
    return rs;
}

static struct rangeset *rangeset_union(struct rangeset *x, struct rangeset *y)
{
    struct rangeset *rs;
    int i;
    rs = init_rangeset();
    for (i = 0; i < x->n_ranges; ++i) 
        add_range(rs, x->range[i].from, x->range[i].to);
          
    for (i = 0; i < y->n_ranges; ++i) 
        add_range(rs, y->range[i].from, y->range[i].to);

    return rs;
}

static struct rangeset *rangeset_inter(struct rangeset *x, struct rangeset *y)
{
    struct rangeset *rs;
    word i_x, i_y;
    rs = init_rangeset();
    i_x = i_y = 0;
    while (i_x < x->n_ranges &&
           i_y < y->n_ranges) {
        word from_x = x->range[i_x].from;
        word to_x = x->range[i_x].to;
        word from_y = y->range[i_y].from;
        word to_y = y->range[i_y].to;
        if (to_x < to_y) {
            add_range(rs, Max(from_x, from_y), to_x);
            ++i_x;
        }
        else {
            add_range(rs, Max(from_x, from_y), to_y);
            ++i_y;
        }
    }
    return rs;
}

static struct rangeset *rangeset_compl(struct rangeset *x)
{
    struct rangeset *rs;
    word i, prev = 0;
    rs = init_rangeset();
    for (i = 0; i < x->n_ranges; ++i) {
        word from = x->range[i].from;
        word to = x->range[i].to;
        if (from > prev)
            add_range(rs, prev, from - 1);
        prev = to + 1;
    }
    if (prev <= MAX_CODE_POINT)
        add_range(rs, prev, MAX_CODE_POINT);
    return rs;
}

static void fold_to(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    if (!get_literal(x->child2, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
}

static void fold_toby(struct lnode *n)
{
    struct lnode_3 *x = (struct lnode_3 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    if (!get_literal(x->child2, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    if (!get_literal(x->child3, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
}

static int is_repeatable(struct lnode *n)
{
    switch (n->op) {
        case Uop_Keyword: {
            int k = ((struct lnode_keyword *)n)->num;
            switch (k) {
                case K_NULL:
                case K_YES:
                case K_FAIL:
                    return 1;
                default:
                    return 0;
            }
        }
        case Uop_Empty:
        case Uop_Const: 
            return 1;
        case Uop_Global: {
            struct lnode_global *x = (struct lnode_global *)n;
            return (x->global->g_flag & (F_Builtin|F_Proc|F_Record|F_Class)) != 0;
        }

        case Uop_List: 
        case Uop_Mutual:
        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            for (i = 0; i < x->n; ++i) {
                if (!is_repeatable(x->child[i]))
                    return 0;
            }
            return 1;
        }

        case Uop_Random:
            return 0;

        case Uop_Value:
        case Uop_Nonnull:
        case Uop_Bang:
        case Uop_Refresh:
        case Uop_Number:
        case Uop_Compl:
        case Uop_Neg:
        case Uop_Tabmat:
        case Uop_Size:
        case Uop_Repeat: 
        case Uop_While: 
        case Uop_Null: 
        case Uop_Until: 
        case Uop_Every: 
        case Uop_Rptalt: 
        case Uop_Not: {		
            struct lnode_1 *x = (struct lnode_1 *)n;
            return is_repeatable(x->child);
        }

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
        case Uop_Union:
        case Uop_Conj: 
        case Uop_If: 
        case Uop_Whiledo: 
        case Uop_Alt: 
        case Uop_Untildo: 
        case Uop_Everydo: 
        case Uop_Limit:
        case Uop_To: 
        case Uop_Scan: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            return is_repeatable(x->child1) && is_repeatable(x->child2);
        }

        case Uop_Toby: 
        case Uop_Sect:
        case Uop_Sectp:
        case Uop_Sectm:
        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            return is_repeatable(x->child1) && is_repeatable(x->child2) && is_repeatable(x->child3);
        }

        case Uop_Field: { 			/* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            struct lclass_field_ref *ref;
            if (!get_class_field_ref(x, 0, &ref))
                return 0;
            return (ref->field->flag & M_Static) && (ref->field->flag & (M_Method | M_Const));
        }

        case Uop_Asgn:
        case Uop_Rasgn:
        case Uop_Rswap:
        case Uop_Swap:
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
        case Uop_Augapply:
        case Uop_Augscan:
        case Uop_Augactivate: 
        case Uop_Suspendexpr: 
        case Uop_Suspenddo: 
        case Uop_Succeedexpr: 
        case Uop_Linkexpr: 
        case Uop_Returnexpr: 
        case Uop_Breakexpr: 
        case Uop_Create: 
        case Uop_Uactivate: 
        case Uop_Bactivate: 
        case Uop_Local: 
        case Uop_Next:
        case Uop_End:
        case Uop_Break:
        case Uop_Suspend:
        case Uop_Return:
        case Uop_Link:
        case Uop_Fail:
        case Uop_CoInvoke:                      /* e{x1, x2.., xn} */
        case Uop_Invoke:                       /* e(x1, x2.., xn) */
        case Uop_Apply:			/* application e!l */
        case Uop_Case:			/* case expression */
        case Uop_Casedef:
            return 0;

        default:
            quit("is_repeatable: illegal opcode(%d)", n->op);

    }
    return 0;
}

static int is_repeatable_case(struct lnode_case *x)
{
    int i;
    for (i = 0; i < x->n; ++i) {
        if (!is_repeatable(x->selector[i]))
            return 0;
    }
    return 1;
}

static void fold_case(struct lnode *n)
{
    struct lnode_case *x = (struct lnode_case *)n;
    struct literal l;
    int i;

    if (is_repeatable_case(x)) {
        x->use_tcase = 1;
        if (verbose > 3)
            fprintf(stderr, "Case at %s:%d will use tcase optimization\n", n->loc.file,n->loc.line);
    } else {
        if (verbose > 3)
            fprintf(stderr, "Case at %s:%d won't use tcase optimization\n", n->loc.file,n->loc.line);
    }

    if (get_literal(x->expr, &l)) {
        if (l.type == FAIL) {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
            free_literal(&l);
            return;
        }
        free_literal(&l);
    }

    for (i = 0; i < x->n; ++i) {
        if (get_literal(x->selector[i], &l)) {
            if (l.type == FAIL)
                replace_node(x->clause[i], (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
            free_literal(&l);
        }
    }
}

static void fold_simple1(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_simple2(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_limit(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    if (cnv_int(&l)) {
        if (l.u.i == 0) 
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        else if (l.u.i > 0) {
            struct literal l2;
            if (get_literal(x->child2, &l2)) {
                /* lit \ n -> lit if n>0 */
                replace_node(n, (struct lnode*)x->child2);
                free_literal(&l2);
            }
        }
    }
    free_literal(&l);
}

static void fold_invoke(struct lnode *n)
{
    struct lnode_invoke *x = (struct lnode_invoke *)n;
    struct literal l;
    int i;
    if (!get_literal(x->expr, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    for (i = 0; i < x->n; ++i) {
        if (!get_literal(x->child[i], &l))
            return;
        if (l.type == FAIL) {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
            free_literal(&l);
            break;
        }
        free_literal(&l);
    }
}

static void fold_apply(struct lnode *n)
{
    struct lnode_apply *x = (struct lnode_apply *)n;
    struct literal l;
    if (!get_literal(x->expr, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    if (!get_literal(x->args, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_simplen(struct lnode *n)
{
    struct lnode_n *x = (struct lnode_n *)n;
    int i;
    for (i = 0; i < x->n; ++i) {
        struct literal l;
        if (!get_literal(x->child[i], &l))
            return;
        if (l.type == FAIL) {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
            free_literal(&l);
            break;
        }
        free_literal(&l);
    }
}

static void fold_size(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    word len = -1;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    switch (l.type) {
        case STRING: {
            len = l.u.str.len;
            break;
        }
        case UCS: {
            len = ucs_length(l.u.str.s, l.u.str.len);
            break;
        }
        case CSET: {
            len = cset_size(l.u.rs);
            break;
        }
        default: {
            if (!cnv_string(&l))
                break;
            len = l.u.str.len;
            break;
        }
    }
    if (len >= 0) {
        replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 new_constant(F_IntLit, 
                                              intern_n((char *)&len, sizeof(word)), 
                                              sizeof(word))));
    }
    free_literal(&l);
}

static int get_literal_cset(struct lnode *n, struct literal *l)
{
    if (!get_literal(n, l))
        return 0;
    if (l->type == FAIL)
        return 1;
    if (!cnv_cset(l)) {
        free_literal(l);
        return 0;
    }
    return 1;
}

static void fold_cat(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    word i;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    zero_sbuf(&opt_sbuf);
    for (i = 0; i < l1.u.str.len; ++i)
        AppChar(opt_sbuf, l1.u.str.s[i]);
    for (i = 0; i < l2.u.str.len; ++i)
        AppChar(opt_sbuf, l2.u.str.s[i]);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                          str_install(&opt_sbuf),
                                          l1.u.str.len + l2.u.str.len)));
}

static void fold_compl(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct rangeset *rs;
    struct literal l;
    int len;
    if (!get_literal_cset(x->child, &l))
        return;

    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }

    rs = rangeset_compl(l.u.rs);
    len = rs->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(F_CsetLit, 
                                          intern_n((char *)rs->range, len),
                                          len)));
    free_rangeset(rs);
    free_literal(&l);
}

static void fold_union(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    struct rangeset *r3;
    int len;

    if (!get_literal_cset(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    r3 = rangeset_union(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(F_CsetLit, 
                                          intern_n((char *)r3->range, len),
                                          len)));
    free_literal(&l1);
    free_literal(&l2);
    free_rangeset(r3);
}

static void fold_inter(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    struct rangeset *r3;
    int len;

    if (!get_literal_cset(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    r3 = rangeset_inter(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(F_CsetLit, 
                                          intern_n((char *)r3->range, len),
                                          len)));
    free_literal(&l1);
    free_literal(&l2);
    free_rangeset(r3);
}

static void fold_diff(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    struct rangeset *r3;
    int len;

    if (!get_literal_cset(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    r3 = rangeset_diff(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(F_CsetLit, 
                                          intern_n((char *)r3->range, len),
                                          len)));
    free_literal(&l1);
    free_literal(&l2);
    free_rangeset(r3);
}

static void fold_neg(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;

    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }

    if (cnv_eint(&l)) {
        word w2 = neg(l.u.i);
        if (!over_flow) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w2, sizeof(word)), 
                                                  sizeof(word))));
        }
    } else if (cnv_real(&l)) {
        double d2 = -l.u.d;
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child->loc,
                                 new_constant(F_RealLit, 
                                              intern_n((char *)&d2, sizeof(double)), 
                                              sizeof(double))));
    }

    free_literal(&l);
}

static void fold_null(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == NUL)
        replace_node(n, x->child);
    else
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_nonnull(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == NUL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    else
        replace_node(n, x->child);
    free_literal(&l);
}

static void fold_if(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    else
        replace_node(n, x->child2);
    free_literal(&l);
}

static void fold_ifelse(struct lnode *n)
{
    struct lnode_3 *x = (struct lnode_3 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, x->child3);
    else
        replace_node(n, x->child2);
    free_literal(&l);
}

static void fold_until(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type != FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_untildo(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type != FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_not(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_NULL));
    else
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    free_literal(&l);
}

static void fold_alt(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode*)x->child2);
        free_literal(&l);
        return;
    }
    if (!get_literal(x->child2, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode*)x->child1);
    free_literal(&l);
}

static void fold_conj(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n; 
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    free_literal(&l);
    if (!get_literal(x->child2, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    else
        replace_node(n, (struct lnode*)x->child2);

    free_literal(&l);
}

static void fold_lexeq(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) == Equal) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_lexne(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) != Equal) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_lexge(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) != Less) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_lexgt(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) == Greater) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_lexle(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) != Greater) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_lexlt(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (need_ucs(&l1) || need_ucs(&l2)) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    } else {
        if (!cnv_string(&l1) || !cnv_string(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }

    if (lexcmp(&l1, &l2) == Less) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 new_constant(l2.type == STRING ? F_StrLit:F_UcsLit, 
                                              l2.u.str.s,
                                              l2.u.str.len)));
    } else 
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numeq(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i == l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d == l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numge(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i >= l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d >= l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numgt(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i > l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d > l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numle(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i <= l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d <= l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numlt(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i < l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d < l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_numne(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i != l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d != l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&l2.u.d, sizeof(double)), 
                                                  sizeof(double))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_div(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = div3(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l2.u.d != 0.0) {
            double d = l1.u.d / l2.u.d;
            if (isfinite(d))
                replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_RealLit, 
                                                  intern_n((char *)&d, sizeof(double)), 
                                                  sizeof(double))));
        }
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_mult(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = mul(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d * l2.u.d;
        if (isfinite(d))
            replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 new_constant(F_RealLit, 
                                              intern_n((char *)&d, sizeof(double)), 
                                              sizeof(double))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_minus(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = sub(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d - l2.u.d;
        if (isfinite(d))
            replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 new_constant(F_RealLit, 
                                              intern_n((char *)&d, sizeof(double)), 
                                              sizeof(double))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_plus(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = add(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d + l2.u.d;
        if (isfinite(d))
            replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 new_constant(F_RealLit, 
                                              intern_n((char *)&d, sizeof(double)), 
                                              sizeof(double))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_power(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    /* Don't do anything other than check for fail... */
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_mod(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = mod3(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_return(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_0(Uop_Fail, &n->loc));
    free_literal(&l);
}

static void fold_value(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    replace_node(n, (struct lnode*)x->child);
    free_literal(&l);
}

static void replace_cset_keyword(struct lnode *n, struct rangeset *rs)
{
    int len;
    len = rs->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             new_constant(F_CsetLit, 
                                          intern_n((char *)rs->range, len),
                                          len)));
}

static void fold_keyword(struct lnode *n)
{
    struct lnode_keyword *x = (struct lnode_keyword *)n;

    switch (x->num) {
        case K_NO: {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_NULL));
            break;
        }

        case K_ASCII:
            replace_cset_keyword(n, k_ascii_rangeset);
            break;

        case K_CSET:
            replace_cset_keyword(n, k_cset_rangeset);
            break;

        case K_LCASE:
            replace_cset_keyword(n, k_lcase_rangeset);
            break;

        case K_LETTERS:
            replace_cset_keyword(n, k_letters_rangeset);
            break;

        case K_UCASE:
            replace_cset_keyword(n, k_ucase_rangeset);
            break;

        case K_USET:
            replace_cset_keyword(n, k_uset_rangeset);
            break;

        case K_DIGITS:
            replace_cset_keyword(n, k_digits_rangeset);
            break;
    }
}

static void fold_number(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l);
        return;
    }
    if (l.type == INTEGER || l.type == REAL) {
        replace_node(n, (struct lnode*)x->child);
        free_literal(&l);
        return;
    }
    if (cnv_eint(&l)) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child->loc,
                                 new_constant(F_IntLit, 
                                              intern_n((char *)&l.u.i, sizeof(word)), 
                                              sizeof(word))));
    } else if (cnv_real(&l)) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child->loc,
                                 new_constant(F_RealLit, 
                                              intern_n((char *)&l.u.d, sizeof(double)), 
                                              sizeof(double))));
    }

    free_literal(&l);
}

static void fold_field(struct lnode *n)
{
    struct lnode_field *x = (struct lnode_field *)n;
    struct lclass_field *f;
    struct lclass_field_ref *ref;
    struct literal l;

    if (get_literal(x->child, &l)) {
        if (l.type == FAIL) {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
            free_literal(&l);
            return;
        }
        free_literal(&l);
    }

    if (!get_class_field_ref(x, 0, &ref))
        return;
    f = ref->field;

    if ((f->flag & (M_Static | M_Const)) != (M_Static | M_Const))
        return;

    if (curr_vfunc->method &&
        curr_vfunc->method->name == init_string && curr_vfunc->method->class == f->class)
        return;

    if (!check_access(curr_vfunc, f))
        return;

    switch (f->const_flag) {
        case SET_NULL: {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_NULL));
            break;
        }
        case SET_YES: {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_YES));
            break;
        }
        case SET_CONST: {
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(f->const_val->c_flag,
                                                  f->const_val->data,
                                                  f->const_val->length)));
            break;
        }
    }
}

static void fold_subsc(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    word i;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (!cnv_int(&l2)) {
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    switch (l1.type) {
        case UCS: {
            int len = ucs_length(l1.u.str.s, l1.u.str.len);
            char *p = l1.u.str.s, *t;
            i = cvpos_item(l2.u.i, len);
            if (i == CvtFail) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            p = l1.u.str.s;
            while (i-- > 1) 
                p += UTF8_SEQ_LEN(*p);
            t = p;
            p += UTF8_SEQ_LEN(*p);
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_UcsLit, 
                                                  intern_n(t, p - t),
                                                  p - t)));
            break;
        }
        case CSET: {
            int k, ch, count, len = cset_size(l1.u.rs);
            i = cvpos_item(l2.u.i, len);
            if (i == CvtFail) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            k = cset_range_of_pos(l1.u.rs, i, &count);
            ch = l1.u.rs->range[k].from + i - 1 - count;
            if (ch < 256) {
                char t = ch;
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         new_constant(F_StrLit, 
                                                      intern_n(&t, 1),
                                                      1)));
            } else {
                char buf[MAX_UTF8_SEQ_LEN];
                int m = utf8_seq(ch, buf);
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         new_constant(F_UcsLit, 
                                                      intern_n(buf, m),
                                                      m)));
            }
            break;
        }
        default: {
            char t;
            if (!cnv_string(&l1))
                break;
            i = cvpos_item(l2.u.i, l1.u.str.len);
            if (i == CvtFail) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            t = l1.u.str.s[i - 1];
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_StrLit, 
                                                  intern_n(&t, 1),
                                                  1)));
            break;
        }
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_sect(struct lnode *n, int op)
{
    struct lnode_3 *x = (struct lnode_3 *)n;
    word i, j, l;
    struct literal l1, l2, l3;

    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (!get_literal(x->child3, &l3)) {
        free_literal(&l1);
        free_literal(&l2);
        return;
    }
    if (l3.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        free_literal(&l3);
        return;
    }

    if (!cnv_int(&l2) || !cnv_int(&l3)) {
        free_literal(&l1);
        free_literal(&l2);
        free_literal(&l3);
        return;
    }

    i = l2.u.i;
    j = l3.u.i;
    if (op == Uop_Sectm)
        j = i - j;
    else if (op == Uop_Sectp)
        j += i;

    switch (l1.type) {
        case UCS: {
            int len = ucs_length(l1.u.str.s, l1.u.str.len);
            char *start = l1.u.str.s, *end;
            if (!cvslice(&i, &j, len)) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            l = j - i;

            while (i-- > 1) 
                start += UTF8_SEQ_LEN(*start);
            end = start;
            while (l-- > 0)
                end += UTF8_SEQ_LEN(*end);

            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_UcsLit, 
                                                  intern_n(start, end - start),
                                                  end - start)));
            break;
        }
        case CSET: {
            int k, ch, count, len = cset_size(l1.u.rs), type;
            word last, from, to, m, out_len;
            if (!cvslice(&i, &j, len)) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            l = j - i;

            if (l == 0) {
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         new_constant(F_StrLit, 
                                                      empty_string,
                                                      0)));
                break;
            }

            /* Search for the last char, see if it's < 256 */
            last = j - 1;
            k = cset_range_of_pos(l1.u.rs, last, &count);
            ch = l1.u.rs->range[k].from + last - 1 - count;

            k = cset_range_of_pos(l1.u.rs, i, &count); /* The first row of interest */
            --i;
            i -= count;       /* Offset into first range */
            zero_sbuf(&opt_sbuf);
            if (ch < 256) {
                type = F_StrLit;
                for (; l > 0 && k < l1.u.rs->n_ranges; ++k) {
                    from = l1.u.rs->range[k].from;
                    to = l1.u.rs->range[k].to;
                    for (m = i + from; l > 0 && m <= to; ++m) {
                        AppChar(opt_sbuf, m);
                        --l;
                    }
                    i = 0;
                }
            } else {
                type = F_UcsLit;
                for (; l > 0 && k < l1.u.rs->n_ranges; ++k) {
                    from = l1.u.rs->range[k].from;
                    to = l1.u.rs->range[k].to;
                    for (m = i + from; l > 0 && m <= to; ++m) {
                        char buf[MAX_UTF8_SEQ_LEN];
                        int n = utf8_seq(m, buf);
                        append_n(&opt_sbuf, buf, n);
                        --l;
                    }
                    i = 0;
                }
            }
            /* Ensure we found right num of chars. */
            if (l)
                quit("fold_sect: inconsistent parameters");
            out_len = CurrLen(opt_sbuf);
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(type,
                                                  str_install(&opt_sbuf),
                                                  out_len)));
            break;
        }
        default: {
            if (!cnv_string(&l1))
                break;
            if (!cvslice(&i, &j, l1.u.str.len)) {
                replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
                break;
            }
            l = j - i;

            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     new_constant(F_StrLit, 
                                                  intern_n(l1.u.str.s + i - 1, l),
                                                  l)));
            break;
        }
    }
    free_literal(&l1);
    free_literal(&l2);
    free_literal(&l3);
}

static void fold_eqv(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (equiv(&l1, &l2))
        replace_node(n, (struct lnode*)x->child2);
    else
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));

    free_literal(&l1);
    free_literal(&l2);
}

static void fold_neqv(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (l1.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        return;
    }
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    if (l2.type == FAIL) {
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
        free_literal(&l1);
        free_literal(&l2);
        return;
    }

    if (equiv(&l1, &l2))
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    else
        replace_node(n, (struct lnode*)x->child2);

    free_literal(&l1);
    free_literal(&l2);
}

static word cvpos(word pos, word len)
{
    /*
     * Make sure the position is within range.
     */
    if (pos < -len || pos > len + 1)
        return CvtFail;
    /*
     * If the position is greater than zero, just return it.  Otherwise,
     *  convert the zero/negative position.
     */
    if (pos > 0)
        return pos;
    return (len + pos + 1);
}

static word cvpos_item(word pos, word len)
{
   /*
    * Make sure the position is within range.
    */
   if (pos < -len || pos > len || pos == 0)
      return CvtFail;
   /*
    * If the position is greater than zero, just return it.  Otherwise,
    *  convert the negative position.
    */
   if (pos > 0)
      return pos;
   return (len + pos + 1);
}

static int cvslice(word *i, word *j, word len)
{
    word p1, p2;
    p1 = cvpos(*i, len);
    if (p1 == CvtFail)
        return 0;
    p2 = cvpos(*j, len);
    if (p2 == CvtFail)
        return 0;
    if (p1 > p2) {
        *i = p2;
        *j = p1;
    } else {
        *i = p1;
        *j = p2;
    }
    return 1;
}

static int cset_range_of_pos(struct rangeset *rs, word pos, int *count)
{
    int i, k;
    --pos;
    k = 0;
    for (i = 0; i < rs->n_ranges; ++i) {
        int sz = rs->range[i].to - rs->range[i].from + 1;
        if (k <= pos && pos < k + sz) {
            if (count)
                *count = k;
            return i;
        }
        k += sz;
    }
    quit("Invalid index to cset_range_of_pos");
    /* Not reached */
    return 0;
}

static int cset_size(struct rangeset *rs)
{
    int i, len = 0;
    for (i = 0; i < rs->n_ranges; ++i)
        len += rs->range[i].to - rs->range[i].from + 1;
    return len;
}

static int ucs_length(char *utf8, int utf8_len)
{
    int len = 0;
    char *e = utf8 + utf8_len;
    while (utf8 < e) {
        utf8 += UTF8_SEQ_LEN(*utf8);
        ++len;
    }
    return len;
}

static int get_literal(struct lnode *n, struct literal *l)
{
    if (n->op == Uop_Const) {
        struct centry *ce = ((struct lnode_const *)n)->con;
        if (ce->c_flag == F_StrLit) {
            l->type = STRING;
            l->u.str.s = ce->data;
            l->u.str.len = ce->length;
            return 1;
        }
        if (ce->c_flag == F_UcsLit) {
            l->type = UCS;
            l->u.str.s = ce->data;
            l->u.str.len = ce->length;
            return 1;
        }
        if (ce->c_flag == F_CsetLit) {
            struct range *pair = safe_zalloc(ce->length);
            int i, npair = ce->length / sizeof(struct range);
            memcpy(pair, ce->data, ce->length);
            l->type = CSET;
            l->u.rs = init_rangeset();
            for (i = 0; i < npair; ++i)
                add_range(l->u.rs, pair[i].from, pair[i].to);
            free(pair);
            return 1;
        }
        if (ce->c_flag == F_IntLit) {
            l->type = INTEGER;
            memcpy(&l->u.i, ce->data, sizeof(word));
            return 1;
        }
        if (ce->c_flag == F_RealLit) {
            l->type = REAL;
            memcpy(&l->u.d, ce->data, sizeof(double));
            return 1;
        }
    }
    else if (n->op == Uop_Keyword) {
        int k = ((struct lnode_keyword *)n)->num;
        switch (k) {
            case K_NULL: {
                l->type = NUL;
                return 1;
            }
            case K_FAIL: {
                l->type = FAIL;
                return 1;
            }
        }
    }
    return 0;
}

static void free_literal(struct literal *l)
{
    if (l->type == CSET) {
        free_rangeset(l->u.rs);
        l->u.rs = 0;
    }
    l->type = NUL;
}

static int lexcmp(struct literal *x, struct literal *y)
{
    char *s1, *s2;
    word minlen;
    word l1, l2;

    /*
     * Get length and starting address of both strings.
     */
    l1 = x->u.str.len;
    s1 = x->u.str.s;
    l2 = y->u.str.len;
    s2 = y->u.str.s;

    /*
     * Set minlen to length of the shorter string.
     */
    minlen = Min(l1, l2);

    /*
     * Compare as many bytes as are in the smaller string.  If an
     *  inequality is found, compare the differing bytes.
     */
    while (minlen--) {
        unsigned char c1, c2;
        c1 = *s1++;
        c2 = *s2++;
        if (c1 != c2)
            return (c1 > c2) ? Greater : Less;
    }

    /*
     * The strings compared equal for the length of the shorter.
     */
    if (l1 == l2)
        return Equal;
    return (l1 > l2) ? Greater : Less;
}

static int equiv(struct literal *x, struct literal *y)
{
    if (x->type != y->type)
        return 0;
    switch (x->type) {
        case NUL:
            return 1;
        case CSET: {
            int i;
            if (x->u.rs->n_ranges != y->u.rs->n_ranges)
                return 0;
            for (i = 0; i < x->u.rs->n_ranges; ++i)
                if (x->u.rs->range[i].from != y->u.rs->range[i].from ||
                    x->u.rs->range[i].to != y->u.rs->range[i].to)
                    return 0;
            return 1;
        }
        case UCS:
        case STRING: {
            if (x->u.str.len != y->u.str.len)
                return 0;
            return memcmp(x->u.str.s, y->u.str.s, x->u.str.len) == 0;
        }
        case INTEGER:
            return x->u.i == y->u.i;
        case REAL:
            return x->u.d == y->u.d;
    }
    quit("Bad type to equiv()");
    return 0;
}

/*
 * Simplified form of the function in cnv.r
 */
static int numeric_via_string(struct literal *src)
{
   char *s, *end_s;
   char msign = '+';    /* sign of mantissa */
   word lresult = 0;	/* integer result */
   int digits = 0;	/* number of digits seen */
   double d;

   if (!cnv_string(src))
       return 0;

   s = src->u.str.s;
   end_s = s + src->u.str.len;

   /*
    * Skip leading white space.
    */
   while (s < end_s && oi_isspace(*s))
       ++s;

   /*
    * Check for sign.
    */
   if (s < end_s && (*s == '+' || *s == '-'))
      msign = *s++;

   /*
    * Get integer part
    */
   over_flow = 0;
   while (s < end_s && oi_isdigit(*s)) {
       if (!over_flow) {
           lresult = mul(lresult, 10);
           if (!over_flow)
               lresult = add(lresult, *s - '0');
       }
       ++digits;
       ++s;
   }

   /* Don't handle non-decimal cases */
   if (s < end_s && (*s == 'r' || *s == 'R'))
       return 0;

   /* Trailing whitespace; if we're then at the end it's a decimal
    * integer */
   while (s < end_s && oi_isspace(*s))
       ++s;

   if (s == end_s) {
       /* Check we had some digits */
       if (!digits)
           return 0;
       /* Base 10 integer or large integer */
       if (over_flow) {
           return 0;
       } else {
           src->type = INTEGER;
           src->u.i = (msign == '+' ? lresult : -lresult);
           return 1;
       }
   }

   d = strtod(src->u.str.s, &s);
   if (!isfinite(d))
       return 0;

   /* Check only spaces remain. */
   while (s < end_s && oi_isspace(*s))
       ++s;
   if (s < end_s)
       return 0;

   src->type = REAL;
   src->u.d = d;
   return 1;
}
