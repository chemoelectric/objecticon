#include "icont.h"
#include "link.h"
#include "ltree.h"
#include "ucode.h"
#include "tsym.h"
#include "lsym.h"
#include "lmem.h"
#include "keyword.h"

enum literaltype { NUL, FAIL, CSET, STRING, UCS, INT, REAL };

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

static word cvpos(long pos, long len);
static int changes(struct lnode *n);
static int lexcmp(struct literal *x, struct literal *y);

static int cnv_ucs(struct literal *s);
static int cnv_cset(struct literal *s);
static int cnv_string_or_ucs(struct literal *s);
static int cnv_string(struct literal *s);
static int get_literal_string_or_ucs(struct lnode *n, struct literal *l);
static int get_literal_cset(struct lnode *n, struct literal *l);
static int cnv_eint(struct literal *s);
static int cnv_int(struct literal *s);
static int cnv_real(struct literal *s);

static int get_literal(struct lnode *n, struct literal *res);
static void free_literal(struct literal *l);

static void fold_field(struct lnode *n);
static void fold_null(struct lnode *n);
static void fold_nonnull(struct lnode *n);
static void fold_if(struct lnode *n);
static void fold_ifelse(struct lnode *n);
static void fold_while(struct lnode *n);
static void fold_whiledo(struct lnode *n);
static void fold_until(struct lnode *n);
static void fold_untildo(struct lnode *n);
static void fold_not(struct lnode *n);
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

static int get_eword(struct lnode *n, word *);
static int get_word(struct lnode *n, word *);
static int over_flow;
static word add(word a, word b);
static word sub(word a, word b);
static word mul(word a, word b);
static word mod3(word a, word b);
static word div3(word a, word b);
static word neg(word a);

static struct rangeset *rangeset_union(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_inter(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_diff(struct rangeset *r1, struct rangeset *r2);
static struct rangeset *rangeset_compl(struct rangeset *x);
static int cset_range_of_pos(struct rangeset *rs, word pos, int *count);
static int cset_size(struct rangeset *rs);
static int ucs_length(char *utf8, int utf8_len);

static struct str_buf opt_sbuf;

static int fold_consts(struct lnode *n)
{
    switch (n->op) {
        case Uop_Field: {
            fold_field(n);
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

        case Uop_If: {
            fold_if(n);
            break;
        }

        case Uop_Ifelse: {
            fold_ifelse(n);
            break;
        }

        case Uop_Every:
        case Uop_While: {
            fold_while(n);
            break;
        }

        case Uop_Everydo:
        case Uop_Whiledo: {
            fold_whiledo(n);
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
            
        case Uop_Unions: {
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
    }
    return 1;
}

static int tidy_consts(struct lnode *n)
{
    switch (n->op) {
        case Uop_Const: {
            struct centry *c = ((struct lnode_const *)n)->con;
            c->ref = 1;
            break;
        }
        case Uop_End: {
            struct centry **cp, *c;
            cp = &curr_vfunc->constants;
            while ((c = *cp)) {
                if (c->ref)
                    cp = &c->next;
                else
                    *cp = c->next;
            }
            break;
        }
    }
    return 1;
}

static int compute_global_pure(struct lnode *n)
{
    switch (n->op) {
        case Uop_Global: {
            struct lnode_global *x = (struct lnode_global *)n;
            if (changes(n)) {
                if (verbose > 3) {
                    fprintf(stderr,
                            "Pure cleared for %s at %s:%d\n",x->global->name, 
                            n->loc.file, n->loc.line);
                }
                x->global->pure = 0;
            }
            break;
        }
    }
    return 1;
}

static int changes(struct lnode *n)
{
    while (n->parent) {
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
            case Uop_Unions:
            case Uop_Scan:
            case Uop_Bactivate:
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
            case Uop_Augunions: 
            case Uop_Augconj: 
            case Uop_Augactivate: 
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

            case Uop_Break: 
            case Uop_Create: 
            case Uop_Suspend: 
            case Uop_Return: {
                struct lnode_1 *x = (struct lnode_1 *)n->parent;
                return x->child == n;
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

    y = (struct lnode_field *)x->child1;
    if (y->child->op != Uop_Global)
        return 1;
    z = (struct lnode_global *)y->child;
    if (z->global->class != vclass)
        return 1;
    f = lookup_field(vclass, y->fname);
    if (!f)
        return 1;

    if (x->child2->op == Uop_Const) {
        struct c_entry *ce = ((struct lnode_const *)x->child2)->con;
        if (f->flag == (M_Public | M_Static | M_Const)) {
            if (f->const_flag == NOT_SEEN) {
                f->const_val = ce;
                f->const_flag = SET_CONST;
            } else
                f->const_flag = OTHER;
        }
        return 0;
    } else if (x->child2->op == Uop_Keyword) {
        int k = ((struct lnode_keyword *)x->child2)->num;
        if (k == K_NULL) {
            if (f->const_flag == NOT_SEEN)
                f->const_flag = SET_NULL;
            else
                f->const_flag = OTHER;
        }
        return 0;
    } else
        return 1;
}

static int visit_init_field(struct lnode *n)
{
    struct lnode_field *x = (struct lnode_field *)n;
    struct lclass_field *f;
    f = lookup_field(vclass, x->fname);
    if (f && f->flag == (M_Public | M_Static | M_Const)) {
        if (changes(n))
            f->const_flag = OTHER;
    }
    return 0;
}

static int visit_init_method(struct lnode *n)
{
    /*printf("visit %s\n",ucode_op_table[n->op].name);*/
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

static void compute_class_consts()
{
    if (verbose > 3)
        fprintf(stderr, "Public static constant analysis:\n\n");
    for (vclass = lclasses; vclass; vclass = vclass->next) {
        struct lclass_field *f = lookup_field(vclass, init_string);
        if (f) {
            visitfunc_post(f->func, fold_consts);
            visitfunc_pre(f->func, visit_init_method);
        }
        if (verbose > 3) {
            fprintf(stderr, "Class %s pure=%d\n", vclass->global->name, vclass->global->pure);
            struct lclass_field *cf;
            for (cf = vclass->fields; cf; cf = cf->next) {
                if (cf->flag == (M_Public | M_Static | M_Const)) {
                    fprintf(stderr, "\tPublic static constant %s: ", cf->name);
                    switch (cf->const_flag) {
                        case NOT_SEEN: fprintf(stderr, "NOT_SEEN\n"); break;
                        case SET_NULL: fprintf(stderr, "SET_NULL\n"); break;
                        case SET_CONST: fprintf(stderr, "SET_CONST\n"); break;
                        case OTHER: fprintf(stderr, "OTHER\n"); break;
                    }
                }
            }
        }
    }
}

void optimize()
{
    visit_post(compute_global_pure);
    compute_class_consts();
    visit_post(fold_consts);
    visit_post(tidy_consts);
}

static int get_eword(struct lnode *n, word *w)
{
    struct literal t;
    if (!get_literal(n, &t))
        return 0;
    if (!cnv_eint(&t)) {
        free_literal(&t);
        return 0;
    }
    *w = t.u.i;
    return 1;
}

static int get_word(struct lnode *n, word *w)
{
    struct literal t;
    if (!get_literal(n, &t))
        return 0;
    if (!cnv_int(&t)) {
        free_literal(&t);
        return 0;
    }
    *w = t.u.i;
    return 1;
}

/*
 * These are copied from rmisc.r
 */

static word add(word a, word b)
{
   if ((a ^ b) >= 0 && (a >= 0 ? b > MaxWord - a : b < MinWord - a)) {
      over_flow = 1;
      return 0;
      }
   else {
     over_flow = 0;
     return a + b;
     }
}

static word sub(word a, word b)
{
   if ((a ^ b) < 0 && (a >= 0 ? b < a - MaxWord : b > a - MinWord)) {
      over_flow = 1;
      return 0;
      }
   else {
      over_flow = 0;
      return a - b;
      }
}

static word mul(word a, word b)
{
   if (b != 0) {
      if ((a ^ b) >= 0) {
	 if (a >= 0 ? a > MaxWord / b : a < MaxWord / b) {
            over_flow = 1;
	    return 0;
            }
	 }
      else if (b != -1 && (a >= 0 ? a > MinWord / b : a < MinWord / b)) {
         over_flow = 1;
	 return 0;
         }
      }

   over_flow = 0;
   return a * b;
}

/* MinWord / -1 overflows; need div3 too */

static word mod3(word a, word b)
{
   word retval;

   switch ( b )
   {
      case 0:
	 over_flow = 1; /* Not really an overflow, but definitely an error */
	 return 0;

      case MinWord:
	 /* Handle this separately, since -MinWord can overflow */
	 retval = ( a > MinWord ) ? a : 0;
	 break;

      default:
	 /* First, we make b positive */
      	 if ( b < 0 ) b = -b;	

	 /* Make sure retval should have the same sign as 'a' */
	 retval = a % b;
	 if ( ( a < 0 ) && ( retval > 0 ) )
	    retval -= b;
	 break;
      }

   over_flow = 0;
   return retval;
}

static word div3(word a, word b)
{
   if ( ( b == 0 ) ||	/* Not really an overflow, but definitely an error */
        ( b == -1 && a == MinWord ) ) {
      over_flow = 1;
      return 0;
      }

   over_flow = 0;
   return ( a - mod3 ( a, b ) ) / b;
}

static word neg(word a)
{
    if (a == MinWord) {
        over_flow = 1;
        return 0;
    }
    over_flow = 0;
    return -a;
}

static int cnv_eint(struct literal *s)
{
    switch (s->type) {
        case INT: {
            return 1;
        }
        default: {
            char *e;
            long t;
            if (!cnv_string(s))
                return 0;
            if (!*s->u.str.s)  /* Empty string */
                return 0;
            t = strtol(s->u.str.s, &e, 10);
            if (*e)             /* End not reached, so reject */
                return 0;
            if (t < MinWord || t > MaxWord)
                return 0;
            s->type = INT;
            s->u.i = (word)t;
            return 1;
        }
    }

    return 0;
}

static int cnv_int(struct literal *s)
{
    switch (s->type) {
        case INT: {
            return 1;
        }
        case REAL: {
            if (s->u.d <= MinWord || s->u.d <= MaxWord)
                return 0;
            s->type = INT;
            s->u.i = (word)s->u.d;
            return 1;
        }
        default: {
            char *e;
            long t;
            if (!cnv_string(s))
                return 0;
            if (!*s->u.str.s)  /* Empty string */
                return 0;
            t = strtol(s->u.str.s, &e, 10);
            if (*e)             /* End not reached, so reject */
                return 0;
            if (t < MinWord || t > MaxWord)
                return 0;
            s->type = INT;
            s->u.i = (word)t;
            return 1;
        }
    }

    return 0;
}

static int cnv_real(struct literal *s)
{
    switch (s->type) {
        case REAL: {
            return 1;
        }
        default: {
            char *e;
            double t;
            if (!cnv_string(s))
                return 0;
            if (!*s->u.str.s)  /* Empty string */
                return 0;
            errno = 0;
            t = strtod(s->u.str.s, &e);
            if (errno)
                return 0;       /* overflow */
            if (*e)             /* End not reached, so reject */
                return 0;
            s->type = REAL;
            s->u.d = t;
            return 1;
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
        case INT: {
            char buf[32];
            sprintf(buf, "%ld", (long)s->u.i);
            s->type = STRING;
            s->u.str.len = strlen(buf);
            s->u.str.s = intern(buf);
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
            MemProtect(rs = init_rangeset());
            while (p < e) {
                int i = utf8_iter(&p);
                MemProtect(add_range(rs, i, i));
            }
            s->type = CSET;
            s->u.rs = rs;
            return 1;
        }
        default: {
            int i;
            char *p;
            struct rangeset *rs;
            if (!cnv_string(s))
                return 0;
            MemProtect(rs = init_rangeset());
            p = s->u.str.s;
            i = s->u.str.len;
            while (i--) {
                int j = *p++ & 0xff;
                MemProtect(add_range(rs, j, j));
            }
            s->type = CSET;
            s->u.rs = rs;
            return 1;
        }
    }
    return 0;
}

static int cnv_string_or_ucs(struct literal *s)
{
    switch (s->type) {
        case STRING:
        case UCS: {
            return 1;
        }
        case CSET: {
            return cnv_string(s) || cnv_ucs(s);
        }
        default: {
            return cnv_string(s);
        }
    }
    return 0;
}

static struct rangeset *rangeset_diff(struct rangeset *x, struct rangeset *y)
{
    struct rangeset *rs, *y_comp;
    word i_x, i_y, prev = 0;

    MemProtect(y_comp = init_rangeset());
    MemProtect(rs = init_rangeset());
    /*
     * Calculate ~y
     */
    for (i_y = 0; i_y < y->n_ranges; ++i_y) {
        word from = y->range[i_y].from;
        word to = y->range[i_y].to;
        if (from > prev)
            MemProtect(add_range(y_comp, prev, from - 1));
        prev = to + 1;
    }
    if (prev <= MAX_CODE_POINT)
        MemProtect(add_range(y_comp, prev, MAX_CODE_POINT));

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
            MemProtect(add_range(rs, Max(from_x, from_y), to_x));
            ++i_x;
        }
        else {
            MemProtect(add_range(rs, Max(from_x, from_y), to_y));
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
    MemProtect(rs = init_rangeset());
    for (i = 0; i < x->n_ranges; ++i) 
        MemProtect(add_range(rs, x->range[i].from, x->range[i].to));
          
    for (i = 0; i < y->n_ranges; ++i) 
        MemProtect(add_range(rs, y->range[i].from, y->range[i].to));

    return rs;
}

static struct rangeset *rangeset_inter(struct rangeset *x, struct rangeset *y)
{
    struct rangeset *rs;
    word i_x, i_y;
    MemProtect(rs = init_rangeset());
    i_x = i_y = 0;
    while (i_x < x->n_ranges &&
           i_y < y->n_ranges) {
        word from_x = x->range[i_x].from;
        word to_x = x->range[i_x].to;
        word from_y = y->range[i_y].from;
        word to_y = y->range[i_y].to;
        if (to_x < to_y) {
            MemProtect(add_range(rs, Max(from_x, from_y), to_x));
            ++i_x;
        }
        else {
            MemProtect(add_range(rs, Max(from_x, from_y), to_y));
            ++i_y;
        }
    }
    return rs;
}

static struct rangeset *rangeset_compl(struct rangeset *x)
{
    struct rangeset *rs;
    word i, prev = 0;
    MemProtect(rs = init_rangeset());
    for (i = 0; i < x->n_ranges; ++i) {
        word from = x->range[i].from;
        word to = x->range[i].to;
        if (from > prev)
            MemProtect(add_range(rs, prev, from - 1));
        prev = to + 1;
    }
    if (prev <= MAX_CODE_POINT)
        MemProtect(add_range(rs, prev, MAX_CODE_POINT));
    return rs;
}

static void fold_size(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    int len = -1;
    if (!get_literal(x->child, &l))
        return;
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
                                 add_constant(curr_vfunc, 
                                              F_IntLit, 
                                              intern_n((char *)&len, sizeof(word)), 
                                              sizeof(word))));
    }
    free_literal(&l);
}

static int get_literal_cset(struct lnode *n, struct literal *l)
{
    if (!get_literal(n, l))
        return 0;
    if (!cnv_cset(l)) {
        free_literal(l);
        return 0;
    }
    return 1;
}

static int get_literal_string_or_ucs(struct lnode *n, struct literal *l)
{
    if (!get_literal(n, l))
        return 0;
    if (!cnv_string_or_ucs(l)) {
        free_literal(l);
        return 0;
    }
    return 1;
}

static void fold_cat(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    int i;

    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1))
            return;
        if (!cnv_ucs(&l2)) 
            return;
    }
    zero_sbuf(&opt_sbuf);
    for (i = 0; i < l1.u.str.len; ++i)
        AppChar(opt_sbuf, l1.u.str.s[i]);
    for (i = 0; i < l2.u.str.len; ++i)
        AppChar(opt_sbuf, l2.u.str.s[i]);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             add_constant(curr_vfunc, 
                                          l2.type == STRING ? F_StrLit:F_UcsLit, 
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

    rs = rangeset_compl(l.u.rs);
    len = rs->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             add_constant(curr_vfunc, 
                                          F_CsetLit, 
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
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    r3 = rangeset_union(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             add_constant(curr_vfunc, 
                                          F_CsetLit, 
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
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    r3 = rangeset_inter(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             add_constant(curr_vfunc, 
                                          F_CsetLit, 
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
    if (!get_literal_cset(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }

    r3 = rangeset_diff(l1.u.rs, l2.u.rs);
    len = r3->n_ranges * sizeof(struct range);
    replace_node(n, (struct lnode*)
                 lnode_const(&n->loc,
                             add_constant(curr_vfunc, 
                                          F_CsetLit, 
                                          intern_n((char *)r3->range, len),
                                          len)));
    free_literal(&l1);
    free_literal(&l2);
    free_rangeset(r3);
}

static void fold_neg(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    word w, w2;
    if (get_eword(x->child, &w)) {
        w2 = neg(w);
        if (over_flow)
            return;
        replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 add_constant(curr_vfunc, 
                                              F_IntLit, 
                                              intern_n((char *)&w2, sizeof(word)), 
                                              sizeof(word))));
    }
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
}

static void fold_while(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
}

static void fold_whiledo(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type == FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
}

static void fold_until(struct lnode *n)
{
    struct lnode_1 *x = (struct lnode_1 *)n;
    struct literal l;
    if (!get_literal(x->child, &l))
        return;
    if (l.type != FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
}

static void fold_untildo(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    if (!get_literal(x->child1, &l))
        return;
    if (l.type != FAIL)
        replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
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
}

static void fold_lexeq(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) == Equal) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) != Equal) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) != Less) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) == Greater) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) != Greater) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal_string_or_ucs(x->child1, &l1))
        return;
    if (!get_literal_string_or_ucs(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (l1.type == UCS || l2.type == UCS) {
        if (!cnv_ucs(&l1) || !cnv_ucs(&l2)) {
            free_literal(&l1);
            free_literal(&l2);
            return;
        }
    }
    if (lexcmp(&l1, &l2) == Less) {
        replace_node(n, (struct lnode*)
                     lnode_const(&x->child2->loc,
                                 add_constant(curr_vfunc, 
                                              l2.type == STRING ? F_StrLit:F_UcsLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i == l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d == l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i >= l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d >= l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i > l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d > l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i <= l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d <= l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i < l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d < l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        if (l1.u.i != l2.u.i) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&l2.u.i, sizeof(word)), 
                                                  sizeof(word))));
        } else
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_FAIL));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l1.u.d != l2.u.d) {
            replace_node(n, (struct lnode*)
                         lnode_const(&x->child2->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = div3(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        if (l2.u.d != 0.0) {
            double d = l1.u.d / l2.u.d;
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = mul(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d * l2.u.d;
        replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 add_constant(curr_vfunc, 
                                              F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = sub(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d - l2.u.d;
        replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 add_constant(curr_vfunc, 
                                              F_RealLit, 
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
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = add(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    } else if (cnv_real(&l1) && cnv_real(&l2)) {
        double d = l1.u.d + l2.u.d;
        replace_node(n, (struct lnode*)
                     lnode_const(&n->loc,
                                 add_constant(curr_vfunc, 
                                              F_RealLit, 
                                              intern_n((char *)&d, sizeof(double)), 
                                              sizeof(double))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_mod(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l1, l2;
    if (!get_literal(x->child1, &l1))
        return;
    if (!get_literal(x->child2, &l2)) {
        free_literal(&l1);
        return;
    }
    if (cnv_eint(&l1) && cnv_eint(&l2)) {
        word w = mod3(l1.u.i, l2.u.i);
        if (!over_flow)
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_IntLit, 
                                                  intern_n((char *)&w, sizeof(word)), 
                                                  sizeof(word))));
    }
    free_literal(&l1);
    free_literal(&l2);
}

static void fold_field(struct lnode *n)
{
    struct lnode_field *x = (struct lnode_field *)n;
    struct lnode_global *y;
    struct lclass_field *f;

    if (curr_vfunc->method && curr_vfunc->method->name == init_string)
        return;

    if (x->child->op != Uop_Global)
        return;

    y = (struct lnode_global *)x->child;
    if (!y->global->class || !y->global->pure)
        return;

    f = lookup_field(y->global->class, x->fname);
    if (!f)
        return;

    switch (f->const_flag) {
        case SET_NULL: {
            replace_node(n, (struct lnode *)lnode_keyword(&n->loc, K_NULL));
            break;
        }
        case SET_CONST: {
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  f->const_val->c_flag,
                                                  f->const_val->data,
                                                  f->const_val->length)));
            break;
        }
    }
}

static void fold_subsc(struct lnode *n)
{
    struct lnode_2 *x = (struct lnode_2 *)n;
    struct literal l;
    word w, i;

    if (!get_word(x->child2, &w))
        return;

    if (!get_literal(x->child1, &l))
        return;
    switch (l.type) {
        case UCS: {
            int len = ucs_length(l.u.str.s, l.u.str.len);
            char *p = l.u.str.s, *t;
            i = cvpos(w, len);
            if (i == CvtFail || i > len)
                break;
            p = l.u.str.s;
            while (i-- > 1) 
                utf8_iter(&p);
            t = p;
            utf8_iter(&p);
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_UcsLit, 
                                                  intern_n(t, p - t),
                                                  p - t)));
            break;
        }
        case CSET: {
            int k, ch, count, len = cset_size(l.u.rs);
            i = cvpos(w, len);
            if (i == CvtFail || i > len)
                break;

            k = cset_range_of_pos(l.u.rs, i, &count);
            ch = l.u.rs->range[k].from + i - 1 - count;
            if (ch < 256) {
                char t = ch;
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         add_constant(curr_vfunc, 
                                                      F_StrLit, 
                                                      intern_n(&t, 1),
                                                      1)));
            } else {
                char buf[MAX_UTF8_SEQ_LEN];
                int m = utf8_seq(ch, buf);
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         add_constant(curr_vfunc, 
                                                      F_UcsLit, 
                                                      intern_n(buf, m),
                                                      m)));
            }
            break;
        }
        default: {
            if (!cnv_string(&l))
                break;
            char t;
            i = cvpos(w, l.u.str.len);
            if (i == CvtFail || i > l.u.str.len)
                break;
            t = l.u.str.s[i - 1];
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_StrLit, 
                                                  intern_n(&t, 1),
                                                  1)));
            break;
        }
    }
    free_literal(&l);
}

static void fold_sect(struct lnode *n, int op)
{
    struct lnode_3 *x = (struct lnode_3 *)n;
    word i, j, t;
    struct literal l;

    if (!get_word(x->child2, &i))
        return;
    if (!get_word(x->child3, &j))
        return;
    if (op == Uop_Sectm)
        j -= i;
    else if (op == Uop_Sectp)
        j += i;

    if (!get_literal(x->child1, &l))
        return;
    switch (l.type) {
        case UCS: {
            int len = ucs_length(l.u.str.s, l.u.str.len);
            char *start = l.u.str.s, *end;
            i = cvpos(i, len);
            if (i == CvtFail)
                break;
            j = cvpos(j, len);
            if (j == CvtFail)
                break;
            if (i > j) { 			/* convert section to substring */
                t = i;
                i = j;
                j = t - j;
            }
            else
                j = j - i;

            while (i-- > 1) 
                utf8_iter(&start);
            end = start;
            while (j-- > 0)
                utf8_iter(&end);

            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_UcsLit, 
                                                  intern_n(start, end - start),
                                                  end - start)));
            break;
        }
        case CSET: {
            int k, last, ch, count, len = cset_size(l.u.rs), type;
            word from, to, m, out_len;
            i = cvpos(i, len);
            if (i == CvtFail)
                break;
            j = cvpos(j, len);
            if (j == CvtFail)
                break;
            if (i > j) { 			/* convert section to substring */
                t = i;
                i = j;
                j = t - j;
            }
            else
                j = j - i;

            if (j == 0) {
                replace_node(n, (struct lnode*)
                             lnode_const(&n->loc,
                                         add_constant(curr_vfunc, 
                                                      F_StrLit, 
                                                      empty_string,
                                                      0)));
                break;
            }

            /* Search for the last char, see if it's < 256 */
            last = i + j - 1;
            k = cset_range_of_pos(l.u.rs, last, &count);
            ch = l.u.rs->range[k].from + last - 1 - count;

            k = cset_range_of_pos(l.u.rs, i, &count); /* The first row of interest */
            --i;
            i -= count;       /* Offset into first range */
            zero_sbuf(&opt_sbuf);
            if (ch < 256) {
                type = F_StrLit;
                for (; j > 0 && k < l.u.rs->n_ranges; ++k) {
                    from = l.u.rs->range[k].from;
                    to = l.u.rs->range[k].to;
                    for (m = i + from; j > 0 && m <= to; ++m) {
                        AppChar(opt_sbuf, m);
                        --j;
                    }
                    i = 0;
                }
            } else {
                type = F_UcsLit;
                for (; j > 0 && k < l.u.rs->n_ranges; ++k) {
                    from = l.u.rs->range[k].from;
                    to = l.u.rs->range[k].to;
                    for (m = i + from; j > 0 && m <= to; ++m) {
                        char buf[MAX_UTF8_SEQ_LEN];
                        int n = utf8_seq(m, buf);
                        append_n(&opt_sbuf, buf, n);
                        --j;
                    }
                    i = 0;
                }
            }
            /* Ensure we found right num of chars. */
            if (j)
                quit("cset to str inconsistent parameters");
            out_len = CurrLen(opt_sbuf);
            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  type,
                                                  str_install(&opt_sbuf),
                                                  out_len)));
            break;
        }
        default: {
            if (!cnv_string(&l))
                break;
            i = cvpos(i, l.u.str.len);
            if (i == CvtFail)
                break;

            j = cvpos(j, l.u.str.len);
            if (j == CvtFail) 
                break;

            if (i > j) { 			/* convert section to substring */
                t = i;
                i = j;
                j = t - j;
            }
            else
                j = j - i;

            replace_node(n, (struct lnode*)
                         lnode_const(&n->loc,
                                     add_constant(curr_vfunc, 
                                                  F_StrLit, 
                                                  intern_n(l.u.str.s + i - 1, j),
                                                  j)));
            break;
        }
    }
    free_literal(&l);
}

static word cvpos(long pos, long len)
{
    register word p;

    /*
     * Make sure the position is in the range of an int. (?)
     */
    if ((long)(p = pos) != pos)
        return CvtFail;
    /*
     * Make sure the position is within range.
     */
    if (p < -len || p > len + 1)
        return CvtFail;
    /*
     * If the position is greater than zero, just return it.  Otherwise,
     *  convert the zero/negative position.
     */
    if (pos > 0)
        return p;
    return (len + p + 1);
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
        utf8_iter(&utf8);
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
            struct range *pair = safe_alloc(ce->length);
            int i, npair = ce->length / sizeof(struct range);
            memcpy(pair, ce->data, ce->length);
            l->type = CSET;
            MemProtect(l->u.rs = init_rangeset());
            for (i = 0; i < npair; ++i)
                MemProtect(add_range(l->u.rs, pair[i].from, pair[i].to));
            free(pair);
            return 1;
        }
        if (ce->c_flag == F_IntLit) {
            l->type = INT;
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
            case K_ASCII: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 0, 127);
                return 1;
            }
            case K_CSET: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 0, 255);
                return 1;
            }
            case K_DIGITS: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, '0', '9');
                return 1;
            }
            case K_LCASE: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 'a', 'z');
                return 1;
            }
            case K_LETTERS: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 'A', 'Z');
                add_range(l->u.rs, 'a', 'z');
                return 1;
            }
            case K_UCASE: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 'A', 'Z');
                return 1;
            }
            case K_USET: {
                l->type = CSET;
                MemProtect(l->u.rs = init_rangeset());
                add_range(l->u.rs, 0, MAX_CODE_POINT);
                return 1;
            }
            case K_NULL: {
                l->type = NUL;
                return 1;
            }
            case K_FAIL: {
                l->type = FAIL;
                return 1;
            }
            case K_PI: {
                l->type = REAL;
                l->u.d = 3.14159265358979323846264338327950288419716939937511;
                return 1;
            }
            case K_PHI: {
                l->type = REAL;
                l->u.d = 1.618033988749894848204586834365638117720309180;
                return 1;
            }
            case K_E: {
                l->type = REAL;
                l->u.d = 2.71828182845904523536028747135266249775724709369996;
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
    register char *s1, *s2;
    register word minlen;
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
    while (minlen--)
        if (*s1++ != *s2++)
            return ((*--s1 & 0377) > (*--s2 & 0377) ?
                    Greater : Less);
    /*
     * The strings compared equal for the length of the shorter.
     */
    if (l1 == l2)
        return Equal;
    else if (l1 > l2)
        return Greater;
    else
        return Less;
}

