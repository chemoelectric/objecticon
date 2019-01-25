/*
 * tsym.c -- functions for symbol table management.
 */

#include "icont.h"
#include "tsym.h"
#include "tmem.h"
#include "keyword.h"
#include "ucode.h"
#include "tree.h"
#include "tmain.h"
#include "trans.h"
#include "ttoken.h"

/*
 * Prototypes.
 */

static struct	tcentry *alclit	(struct tcentry *blink, char *name, int len,int flag);
static struct	tcentry *clookup	(char *id,int flag);
static void unop(int op);
static void augop(int op);

/*
 * Keyword table.
 */

struct keyent {
    char *keyname;
    int keyid;
};

#define KDef(p,n) { #p, n },
static struct keyent keytab[] = {
#include "../h/kdefs.h"
};

/*
 * Names of builtin functions.
 */
static char *builtin_table[] = {
#define FncDef(p) #p,
#include "../h/fdefs.h"
#undef FncDef
};

static int builtin_table_cmp(char *key, char **item)
{
    return strcmp(key, *item);
}

static void binop(int op);


/*
 * install - put an identifier into the global or local symbol table.
 *  The basic idea here is to look in the right table and install
 *  the identifier if it isn't already there.  Some semantic checks
 *  are performed.
 */
void install(char *name, struct node *n)
{
    switch (idflag) {
        case F_Global:	/* a variable in a global declaration */
            next_global(name, idflag, n);
            break;

        case F_Static:	/* static declaration */
        case F_Dynamic:	/* local declaration (possibly implicit?) */
        case F_Argument:	/* formal parameter */
            put_local(name, idflag, n, 1);
            break;

        case F_Class:
            next_field(name, modflag, n);
            break;

        case F_Importsym:
            add_import_symbol(name, n);
            break;

        default:
            quit("install: Unrecognized symbol table flag %d.", idflag);
    }
}

void check_globalflag(struct node *n)
{
    if ((globalflag & (F_Package | F_Readable)) == F_Readable)
        tfatal_at(n, "A readable global must be declared package readable");
}

struct tgentry *next_global(char *name, int flag, struct node *n)
{
    int i = hasher(name, ghash);
    struct tgentry *x = ghash[i];
    while (x && x->g_name != name)
        x = x->g_blink;
    if (x)
        tfatal_at(n, "Global redeclaration: %s previously declared at line %d", name, Line(x->pos));

    if (bsearch(name, builtin_table, ElemCount(builtin_table), 
                sizeof(char *), (BSearchFncCast)builtin_table_cmp)) 
        tfatal_at(n, package_name ? 
                          "Package symbol uses name of builtin function" :
                          "Global symbol uses name of builtin function");

    x = FAlloc(struct tgentry);
    x->g_blink = ghash[i];
    ghash[i] = x;
    x->g_name = name;
    x->pos = n;
    x->g_flag = flag | globalflag;
    if (glast) {
        glast->g_next = x;
        glast = x;
    } else
        gfirst = glast = x;
    return x;
}

/*
 * Create, or return an existing, local symbol entry.
 */
struct tlentry *put_local(char *name, int flag, struct node *n, int unique)
{
    int i = hasher(name, curr_func->lhash);
    struct tlentry *x = curr_func->lhash[i];
    while (x && x->l_name != name)
        x = x->l_blink;
    if (x) {
        if (unique)
            tfatal_at(n, "Local redeclaration: %s previously declared at line %d", name, Line(x->pos));
        return x;
    }
    x = FAlloc(struct tlentry);
    x->l_blink = curr_func->lhash[i];
    curr_func->lhash[i] = x;
    x->l_name = name;
    x->pos = n;
    x->l_flag = flag;
    if (curr_func->llast) {
        x->l_index = curr_func->llast->l_index + 1;
        curr_func->llast->l_next = x;
        curr_func->llast = x;
    } else {
        x->l_index = 0;
        curr_func->lfirst = curr_func->llast = x;
    }
    return x;
}


/*
 * putlit makes a constant symbol table entry and returns the table "index"
 *  of the constant.  alclit does the work if there is a collision.
 */
int putlit(char *id, int idtype, int len)
{
    struct tcentry *ptr;
    int i = hasher(id, curr_func->chash);
    if ((ptr = clookup(id,idtype)) == NULL) {   /* add to head of hash chain */
        ptr = curr_func->chash[i];
        curr_func->chash[i] = alclit(ptr, id, len, idtype);
        return curr_func->chash[i]->c_index;
    }
    return ptr->c_index;
}

/*
 * clookup looks up id in constant symbol table and returns pointer to
 *  to it if found or NULL if not present.
 */
static struct tcentry *clookup(char *id, int flag)
{
    struct tcentry *ptr;

    ptr = curr_func->chash[hasher(id, curr_func->chash)];
    while (ptr != NULL && (ptr->c_name != id || ptr->c_flag != flag))
        ptr = ptr->c_blink;

    return ptr;
}

static int keytab_cmp(char *key, struct keyent *item)
{
    return strcmp(key, item->keyname);
}

/*
 * klookup looks up keyword named by id in keyword table and returns
 *  its number (keyid).
 */
int klookup(char *id)
{
    struct keyent *ke = bsearch(id, keytab, ElemCount(keytab), 
                                ElemSize(keytab), 
                                (BSearchFncCast)keytab_cmp);
    if (!ke)
        return 0;

    return ke->keyid;
}

/*
 * alclit allocates a constant symbol table entry, fills in fields with
 *  specified values and returns the new entry.  
 */
static struct tcentry *alclit(struct tcentry *blink, char *name, int len, int flag)
{
    struct tcentry *cp;

    cp = FAlloc(struct tcentry);
    cp->c_blink = blink;
    cp->c_name = name;
    cp->c_length = len;
    cp->c_flag = flag;
    if (curr_func->cfirst == NULL) {
        curr_func->cfirst = cp;
        cp->c_index = 0;
    }
    else {
        curr_func->clast->c_next = cp;
        cp->c_index = curr_func->clast->c_index + 1;
    }
    curr_func->clast = cp;
    return cp;
}

static char *curr_file;
static int curr_line;

void ensure_pos(struct node *x)
{
    if (File(x) != curr_file) {
        uout_op(Uop_Filen);
        uout_str(File(x));
        curr_file = File(x);
        curr_line = 0;
    }
    if (Line(x) != curr_line) {
        uout_op(Uop_Line);
        uout_16(Line(x));
        curr_line = Line(x);
    }
}

void reset_pos()
{
    curr_file = 0;
    curr_line = 0;
}

/*
 * lout dumps local tables of a function f
 */
static void fout(struct tfunction *f)
{
    struct tlentry *lp;
    struct tcentry *cp;

    for (lp = f->lfirst; lp; lp = lp->l_next) {
        ensure_pos(lp->pos);
        uout_op(Uop_Local);
        uout_32(lp->l_flag);
        uout_str(lp->l_name);
    }

    for (cp = f->cfirst; cp; cp = cp->c_next) {
        if (cp->c_length > 0xff) {
            uout_op(Uop_Ldata);
            uout_32(cp->c_flag);
            uout_lbin(cp->c_length, cp->c_name);
        } else {
            uout_op(Uop_Sdata);
            uout_32(cp->c_flag);
            uout_sbin(cp->c_length, cp->c_name);
        }
    }
}

static void clout(struct tclass *class)
{
    struct tclass_super *cs;
    struct tclass_field *cf;

    ensure_pos(class->global->pos);
    uout_op((class->global->g_flag & F_Package) ? Uop_PkClass : Uop_Class);
    uout_32(class->flag);
    uout_str(class->global->g_name);

    for (cs = class->supers; cs; cs = cs->next) {
        ensure_pos(cs->pos);
        uout_op(Uop_Super);
        uout_str(cs->name);
    }
   
    for (cf = class->fields; cf; cf = cf->next) {
        ensure_pos(cf->pos);
        uout_op(Uop_Classfield);
        uout_32(cf->flag);
        uout_str(cf->name);
        if (cf->f)
            fout(cf->f);
    }
}

static void recout(struct tfunction *rec)
{
    struct tlentry *lp;
    ensure_pos(rec->global->pos);
    uout_op((rec->global->g_flag & F_Package) ? Uop_PkRecord : Uop_Record);
    uout_str(rec->global->g_name);
    for (lp = rec->lfirst; lp; lp = lp->l_next) {
        ensure_pos(lp->pos);
        uout_op(Uop_Recordfield);
        uout_str(lp->l_name);
    }
}

static void procout(struct tfunction *proc)
{
    ensure_pos(proc->global->pos);
    uout_op((proc->global->g_flag & F_Package) ? Uop_PkProcdecl : Uop_Procdecl);
    uout_str(proc->global->g_name);
    fout(proc);
}


static int in_create, in_loop;

/*
 * This list is either empty, has one node other than
 * an N_Elist, or has the following structure.
 *               n
 *             /   \
 *          ....    tN
 *           n
 *         /   \
 *        n     t3
 *      /   \
 *    t1     t2
 *
 */
static int elist_len(nodeptr t)
{
    int n;
    if (TType(t) == N_Empty)
        return 0;
    n = 1;
    while (TType(t) == N_Elist) {
        ++n;
        t = Tree0(t);
    }
    return n;
}

static void nodegen(nodeptr t)
{
    if (TType(t) != N_Empty)
        ensure_pos(t);

    switch (TType(t)) {
        case N_Empty: 
            uout_op(Uop_Empty);
            break;

        case N_Int:			/* integer literal */
        case N_Real:			/* real literal */
        case N_Cset:			/* cset literal */
        case N_Ucs:			/* ucs literal */
        case N_Lrgint:			/* large integer literal */
        case N_Str:			/* string literal */
            uout_op(Uop_Const);
            uout_16((int)Val0(t));
            break;

        case N_Id:			/* identifier */
            ensure_pos(t);
            uout_op(Uop_Var);
            uout_16(Val0(t));
            break;

        case N_Binop:			/*  binary operator */
            binop(Val0(Tree0(t)));
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            break;

        case N_Augop:			/*  augmented assignment operator */
            augop(Val0(Tree0(t)));
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            break;

        case N_Sect: {			/* section operation */
            switch (Val0(Tree0(t))) {
                case COLON: uout_op(Uop_Sect); break;
                case PCOLON: uout_op(Uop_Sectp); break;
                case MCOLON: uout_op(Uop_Sectm); break;
            }
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            nodegen(Tree3(t));
            break;
        }

        case N_Clist: {
            /* Don't traverse the default clause as this is done at the end by N_Case. */
            if (TType(Tree0(t)) != N_Cdef)
                nodegen(Tree0(t));
            if (TType(Tree1(t)) != N_Cdef)
                nodegen(Tree1(t));
            break;
        }

        case N_Ccls: {
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            break;
        }

        case N_Case: {
            nodeptr case_default = 0;
            nodeptr u = Tree1(t);
            int len = 0;
            /*
             * Search for the case_default and count the number of non-default clauses.
             */
            while (TType(u) == N_Clist) {
                if (TType(Tree1(u)) == N_Cdef) {
                    if (case_default)
                        tfatal_at(case_default, "More than one default clause");
                    case_default = Tree1(u);
                } else
                    ++len;
                u = Tree0(u);
            }
            if (TType(u) == N_Cdef) {
                if (case_default)
                    tfatal_at(case_default, "More than one default clause");
                case_default = u;
            } else if (TType(u) == N_Ccls) 
                ++len;

            if (case_default)
                uout_op(Uop_Casedef);
            else
                uout_op(Uop_Case);
            uout_16(len);
            nodegen(Tree0(t));        /* The control expression */
            if (len > 0)
                nodegen(Tree1(t));
            if (case_default)
                nodegen(Tree1(case_default));
            break;
        }

        case N_Apply: {			/* application */
            uout_op(Uop_Apply);
            nodegen(Tree0(t));
            nodegen(Tree1(t));

            break;
        }

        case N_Invoke: {			/* invocation */
            int len = elist_len(Tree1(t));
            uout_op(Uop_Invoke);
            uout_16(len);
            nodegen(Tree0(t));
            if (len > 0)
                nodegen(Tree1(t));
            break;
        }

        case N_CoInvoke: {			/* f{x,y...} invocation */
            int len = elist_len(Tree1(t));
            uout_op(Uop_CoInvoke);
            uout_16(len);
            nodegen(Tree0(t));
            if (len > 0) {
                int x = in_loop;
                in_loop = 0;
                ++in_create;
                nodegen(Tree1(t));
                --in_create;
                in_loop = x;
            }
            break;
        }

        case N_Mutual: {			/* (...) invocation */
            int len = elist_len(Tree0(t));
            uout_op(Uop_Mutual);
            uout_16(len);
            if (len > 0)
                nodegen(Tree0(t));
            break;
        }

        case N_Key: {			/* keyword reference */
            uout_op(Uop_Keyword);
            uout_16(Val0(t));
            break;
        }

        case N_Limit: {			/* limitation */
            uout_op(Uop_Limit);
            nodegen(Tree1(t));
            nodegen(Tree0(t));
            break;
        }

        case N_Elist: {                /* expression list, see elist_len above for format */
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            break;
        }

        case N_List: {			/* list construction */
            int len = elist_len(Tree0(t));
            uout_op(Uop_List);
            uout_16(len);
            if (len > 0)
                nodegen(Tree0(t));
            break;
        }

        case N_To: {
            uout_op(Uop_To);
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            break;
        }

        case N_ToBy: {
            uout_op(Uop_Toby);
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            break;
        }

        case N_Create: {			/* create expression */
            int x = in_loop;
            uout_op(Uop_Create);
            in_loop = 0;
            ++in_create;
            nodegen(Tree0(t));
            --in_create;
            in_loop = x;
            break;
        }

        case N_Subsc: {             /* a[i, j, k, ...] */
            int len = elist_len(Tree1(t));
            uout_op(Uop_Subsc);
            uout_16(len);
            nodegen(Tree0(t));
            if (len > 0)
                nodegen(Tree1(t));
            break;
        }

        case N_Slist:	{		/* semicolon-separated expr list */
            int len = 1;
            nodeptr u = t;
            while (TType(u) == N_Slist) {
                ++len;
                u = Tree1(u);
            }

            uout_op(Uop_Slist);
            uout_16(len);

            u = t;
            while (TType(u) == N_Slist) {
                nodegen(Tree0(u));
                u = Tree1(u);
            }
            nodegen(u);

            break;
        }

        case N_Not: {			/* not expression */
            uout_op(Uop_Not);
            nodegen(Tree0(t));
            break;
        }

        case N_Fail: {
            if (in_create)
                tfatal_at(t, "Invalid context for fail");
            uout_op(Uop_Fail);
            break;
        }

        case N_Next: {			/* next expression */
            if (!in_loop)
                tfatal_at(t, "Invalid context for next");
            uout_op(Uop_Next);
            break;
        }

        case N_Return: {
            if (in_create)
                tfatal_at(t, "Invalid context for return");
            uout_op(Uop_Return);
            break;
        }

        case N_Returnexpr: {
            if (in_create)
                tfatal_at(t, "Invalid context for return");
            uout_op(Uop_Returnexpr);
            nodegen(Tree1(t));
            break;
        }

        case N_Succeed: {
            if (in_create)
                tfatal_at(t, "Invalid context for succeed");
            uout_op(Uop_Succeed);
            break;
        }

        case N_Succeedexpr: {
            if (in_create)
                tfatal_at(t, "Invalid context for succeed");
            uout_op(Uop_Succeedexpr);
            nodegen(Tree1(t));
            break;
        }

        case N_Link: {
            if (in_create || !curr_func->field)
                tfatal_at(t, "Invalid context for link");
            uout_op(Uop_Link);
            break;
        }

        case N_Linkexpr: {
            if (in_create || !curr_func->field)
                tfatal_at(t, "Invalid context for link");
            uout_op(Uop_Linkexpr);
            nodegen(Tree1(t));
            break;
        }

        case N_Alt: {
            uout_op(Uop_Alt);
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            break;
        }

        case N_Unop: {              /* unary operator */
            unop(Val0(Tree0(t)));
            nodegen(Tree1(t));
            break;
        }

        case N_Field: {			/* field reference */
            uout_op(Uop_Field);
            uout_str(Str0(Tree1(t)));
            nodegen(Tree0(t));
            break;
        }

        case N_Break: {			/* break */
            if (!in_loop)
                tfatal_at(t, "Invalid context for break");
            uout_op(Uop_Break);
            break;
        }

        case N_Breakexpr: {			/* break expression */
            if (!in_loop)
                tfatal_at(t, "Invalid context for break");
            uout_op(Uop_Breakexpr);
            --in_loop;
            nodegen(Tree0(t));
            ++in_loop;
            break;
        }

        case N_If: {
            uout_op(Uop_If);
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            break;
        }

        case N_Ifelse: {
            uout_op(Uop_Ifelse);
            nodegen(Tree0(t));
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            break;
        }

        case N_Repeat: {
            uout_op(Uop_Repeat);
            ++in_loop;
            nodegen(Tree1(t));
            --in_loop;
            break;
        }

        case N_While: {
            ++in_loop;
            uout_op(Uop_While);
            nodegen(Tree1(t));
            --in_loop;
            break;
        }

        case N_Whiledo: {
            ++in_loop;
            uout_op(Uop_Whiledo);
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            --in_loop;
            break;
        }

        case N_Until: {
            ++in_loop;
            uout_op(Uop_Until);
            nodegen(Tree1(t));
            --in_loop;
            break;
        }

        case N_Untildo: {
            ++in_loop;
            uout_op(Uop_Untildo);
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            --in_loop;
            break;
        }

        case N_Every: {
            ++in_loop;
            uout_op(Uop_Every);
            nodegen(Tree1(t));
            --in_loop;
            break;
        }

        case N_Everydo: {
            ++in_loop;
            uout_op(Uop_Everydo);
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            --in_loop;
            break;
        }

        case N_Suspend: {
            if (in_create)
                tfatal_at(t, "Invalid context for suspend");
            ++in_loop;
            uout_op(Uop_Suspend);
            --in_loop;
            break;
        }

        case N_Suspendexpr: {
            if (in_create)
                tfatal_at(t, "Invalid context for suspend");
            ++in_loop;
            uout_op(Uop_Suspendexpr);
            nodegen(Tree1(t));
            --in_loop;
            break;
        }

        case N_Suspenddo: {
            if (in_create)
                tfatal_at(t, "Invalid context for suspend");
            ++in_loop;
            uout_op(Uop_Suspenddo);
            nodegen(Tree1(t));
            nodegen(Tree2(t));
            --in_loop;
            break;
        }

        default: {
            quit("nodegen: Unknown node type:%d",TType(t));
        }
    }
}

static void binop(int op)
{
    switch (op) {
        case ASSIGN:
            uout_op(Uop_Asgn);
            break;

        case CARET:
            uout_op(Uop_Power);
            break;

        case CONCAT:
            uout_op(Uop_Cat);
            break;

        case DIFF:
            uout_op(Uop_Diff);
            break;

        case EQUIV:
            uout_op(Uop_Eqv);
            break;

        case INTER:
            uout_op(Uop_Inter);
            break;

        case LCONCAT:
            uout_op(Uop_Lconcat);
            break;

        case SEQ:
            uout_op(Uop_Lexeq);
            break;

        case SGE:
            uout_op(Uop_Lexge);
            break;

        case SGT:
            uout_op(Uop_Lexgt);
            break;

        case SLE:
            uout_op(Uop_Lexle);
            break;

        case SLT:
            uout_op(Uop_Lexlt);
            break;

        case SNE:
            uout_op(Uop_Lexne);
            break;

        case MINUS:
            uout_op(Uop_Minus);
            break;

        case MOD:
            uout_op(Uop_Mod);
            break;

        case NEQUIV:
            uout_op(Uop_Neqv);
            break;

        case NMEQ:
            uout_op(Uop_Numeq);
            break;

        case NMGE:
            uout_op(Uop_Numge);
            break;

        case NMGT:
            uout_op(Uop_Numgt);
            break;

        case NMLE:
            uout_op(Uop_Numle);
            break;

        case NMLT:
            uout_op(Uop_Numlt);
            break;

        case NMNE:
            uout_op(Uop_Numne);
            break;

        case PLUS:
            uout_op(Uop_Plus);
            break;

        case REVASSIGN:
            uout_op(Uop_Rasgn);
            break;

        case REVSWAP:
            uout_op(Uop_Rswap);
            break;

        case SLASH:
            uout_op(Uop_Div);
            break;

        case STAR:
            uout_op(Uop_Mult);
            break;

        case SWAP:
            uout_op(Uop_Swap);
            break;

        case UNION:
            uout_op(Uop_Union);
            break;

        case AND:
            uout_op(Uop_Conj);
            break;

        case AT:
            uout_op(Uop_Bactivate);
            break;

        case QMARK:
            uout_op(Uop_Scan);
            break;

        default:
            quit("binop: Undefined binary operator: %d", op);
    }
}

static void augop(int op)
{
    switch (op) {
        case AUGCARET:
            uout_op(Uop_Augpower);
            break;

        case AUGCONCAT:
            uout_op(Uop_Augcat);
            break;

        case AUGDIFF:
            uout_op(Uop_Augdiff);
            break;

        case AUGEQUIV:
            uout_op(Uop_Augeqv);
            break;

        case AUGINTER:
            uout_op(Uop_Auginter);
            break;

        case AUGLCONCAT:
            uout_op(Uop_Auglconcat);
            break;

        case AUGSEQ:
            uout_op(Uop_Auglexeq);
            break;

        case AUGSGE:
            uout_op(Uop_Auglexge);
            break;

        case AUGSGT:
            uout_op(Uop_Auglexgt);
            break;

        case AUGSLE:
            uout_op(Uop_Auglexle);
            break;

        case AUGSLT:
            uout_op(Uop_Auglexlt);
            break;

        case AUGSNE:
            uout_op(Uop_Auglexne);
            break;

        case AUGMINUS:
            uout_op(Uop_Augminus);
            break;

        case AUGMOD:
            uout_op(Uop_Augmod);
            break;

        case AUGNEQUIV:
            uout_op(Uop_Augneqv);
            break;

        case AUGNMEQ:
            uout_op(Uop_Augnumeq);
            break;

        case AUGNMGE:
            uout_op(Uop_Augnumge);
            break;

        case AUGNMGT:
            uout_op(Uop_Augnumgt);
            break;

        case AUGNMLE:
            uout_op(Uop_Augnumle);
            break;

        case AUGNMLT:
            uout_op(Uop_Augnumlt);
            break;

        case AUGNMNE:
            uout_op(Uop_Augnumne);
            break;

        case AUGPLUS:
            uout_op(Uop_Augplus);
            break;

        case AUGSLASH:
            uout_op(Uop_Augdiv);
            break;

        case AUGSTAR:
            uout_op(Uop_Augmult);
            break;

        case AUGUNION:
            uout_op(Uop_Augunion);
            break;

        case AUGAND:
            uout_op(Uop_Augconj);
            break;

        case AUGAT:
            uout_op(Uop_Augactivate);
            break;

        case AUGQMARK:
            uout_op(Uop_Augscan);
            break;

        case AUGBANG:
            uout_op(Uop_Augapply);
            break;

        default:
            quit("augop: Undefined binary operator: %d", op);
    }
}

/*
 * unop is the back-end code emitter for unary operators.  It emits
 *  the operations represented by the token op.
 */
static void unop(int op)
{
    switch (op) {
        case DOT:			/* unary . operator */
            uout_op(Uop_Value);
            break;

        case BACKSLASH:		/* unary \ operator */
            uout_op(Uop_Nonnull);
            break;

        case BANG:		/* unary ! operator */
            uout_op(Uop_Bang);
            break;

        case CARET:		/* unary ^ operator */
            uout_op(Uop_Refresh);
            break;

        case UNION:		/* two unary + operators */
            uout_op(Uop_Number);
            uout_op(Uop_Number);
            break;

        case PLUS:		/* unary + operator */
            uout_op(Uop_Number);
            break;

        case NEQUIV:		/* unary ~ and three = operators */
            uout_op(Uop_Compl);
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            break;

        case SNE:		/* unary ~ and two = operators */
            uout_op(Uop_Compl);
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            break;

        case NMNE:		/* unary ~ and = operators */
            uout_op(Uop_Compl);
            uout_op(Uop_Tabmat);
            break;

        case TILDE:		/* unary ~ operator (cset compl) */
            uout_op(Uop_Compl);
            break;

        case DIFF:		/* two unary - operators */
            uout_op(Uop_Neg);
            uout_op(Uop_Neg);
            break;

        case MINUS:		/* unary - operator */
            uout_op(Uop_Neg);
            break;

        case EQUIV:		/* three unary = operators */
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            break;

        case SEQ:		/* two unary = operators */
            uout_op(Uop_Tabmat);
            uout_op(Uop_Tabmat);
            break;

        case NMEQ:		/* unary = operator */
            uout_op(Uop_Tabmat);
            break;

        case INTER:		/* two unary * operators */
            uout_op(Uop_Size);
            uout_op(Uop_Size);
            break;

        case STAR:		/* unary * operator */
            uout_op(Uop_Size);
            break;

        case QMARK:		/* unary ? operator */
            uout_op(Uop_Random);
            break;

        case SLASH:		/* unary / operator */
            uout_op(Uop_Null);
            break;

        case AT:
            uout_op(Uop_Uactivate);
            break;

        case BAR:
        case CONCAT:
        case LCONCAT:
            uout_op(Uop_Rptalt);
            break;

        default:
            quit("unop: Undefined unary operator: %d", op);
    }
}

void output_code()
{
    struct tgentry *gp;
    struct tinvocable *iv;
    struct timport *im;
    struct timport_symbol *ims;

    uout_op(Uop_Version);
    uout_str(UVersion);

    reset_pos();

    if (package_name) {
        uout_op(Uop_Package);
        uout_str(package_name);
    }

    for (im = imports; im; im = im->next) {
        ensure_pos(im->pos);
        uout_op(Uop_Import);
        uout_str(im->name);
        uout_16(im->mode);
        for (ims = im->symbols; ims; ims = ims->next) {
            ensure_pos(ims->pos);
            uout_op(Uop_Importsym);
            uout_str(ims->name);
        }
    }

    for (iv = tinvocables; iv; iv = iv->next) {
        ensure_pos(iv->pos);
        uout_op(Uop_Invocable);
        uout_str(iv->name);
    }

    for (gp = gfirst; gp; gp = gp->g_next) {
        switch (gp->g_flag & (F_Global|F_Class|F_Proc|F_Record)) {
            case F_Global:
                ensure_pos(gp->pos);
                switch (gp->g_flag & (F_Package|F_Readable)) {
                    case 0 : uout_op(Uop_Global); break;
                    case F_Package : uout_op(Uop_PkGlobal); break;
                    case F_Package|F_Readable : uout_op(Uop_PkRdGlobal); break;
                }
                uout_str(gp->g_name);
                break;
            case F_Global|F_Class:
                clout(gp->class);
                break;
            case F_Global|F_Proc:
                procout(gp->func);
                break;
            case F_Global|F_Record:
                recout(gp->func);
                break;
        }
    }
    uout_op(Uop_Declend);

    reset_pos();

    for (curr_func = functions; curr_func; curr_func = curr_func->next) {
        switch (curr_func->flag) {
            case F_Proc: {
                report("  %s", curr_func->global->g_name);
                ensure_pos(curr_func->global->pos);
                uout_op(Uop_Proc);
                uout_str(curr_func->global->g_name);
                nodegen(Tree1(curr_func->code));
                nodegen(Tree2(curr_func->code));
                ensure_pos(Tree3(curr_func->code));
                uout_op(Uop_End);
                break;
            }
            case F_Method: {
                if (!(curr_func->field->flag & (M_Optional | M_Abstract | M_Native))) {
                    report("  %s.%s", curr_func->field->class->global->g_name, curr_func->field->name);
                    ensure_pos(curr_func->field->pos);
                    uout_op(Uop_Method);
                    uout_str(curr_func->field->class->global->g_name);
                    uout_str(curr_func->field->name);
                    nodegen(Tree1(curr_func->code));
                    nodegen(Tree2(curr_func->code));
                    ensure_pos(Tree3(curr_func->code));
                    uout_op(Uop_End);
                }
                break;
            }
        }
    }
}

