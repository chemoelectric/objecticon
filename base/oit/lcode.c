/*
 * lcode.c -- linker routines to parse .u1 files and produce icode.
 */

#include "icont.h"
#include "link.h"
#include "keyword.h"
#include "ucode.h"
#include "lcode.h"
#include "util.h"
#include "lmem.h"
#include "lsym.h"
#include "tsym.h"
#include "lglob.h"

#include "../h/opdefs.h"
#include "../h/header.h"
#include "../h/rmacros.h"

int nstatics = 0;               /* Running count of static variables */

/*
 * Array sizes for various linker tables that can be expanded with realloc().
 */
int maxcode	= 15000;        /* code space */
int maxlabels	= 500;	        /* maximum num of labels/proc */
int nsize       = 1000;         /* ipc/line num. assoc. table */
int fnmsize     = 10;           /* ipc/file name assoc. table */

struct ipc_fname *fnmtbl;	/* table associating ipc with file name */
struct ipc_line *lntable;	/* table associating ipc with line number */
struct ipc_fname *fnmfree;	/* free pointer for ipc/file name table */
struct ipc_line *lnfree;	/* free pointer for ipc/line number table */
word *labels;			/* label table */
char *codeb;			/* generated code space */
char *codep;			/* free pointer for code space */

static char *curr_file,         /* Current file name from an Op_Filen */
            *last_fnmtbl_filen; /* Last file name entered into fnmtbl above */
static int curr_line;           /* Current line from an Op_Line */

static void gencode(struct lfile *lf);
static void gentables(void);
static void skip_proc();
static void synch_file();
static void synch_line();

struct unref {
    char *name;
    int num;
    struct unref *next, *b_next;
};

struct strconst {
    char *s;
    int len;
    int offset;
    struct strconst *next, *b_next;
};

struct unref *first_unref, *unref_hash[128];
struct strconst *first_strconst, *last_strconst, *strconst_hash[128];
int strconst_offset;

struct header hdr;

static struct unref *get_unref(char *s)
{
    int i = hasher(s, unref_hash);
    struct unref *p = unref_hash[i];
    while (p && p->name != s)
        p = p->b_next;
    if (!p) {
        p = Alloc(struct unref);
        p->b_next = unref_hash[i];
        unref_hash[i] = p;
        p->name = s;
        p->num = (first_unref ? (first_unref->num - 1) : -1);
        p->next = first_unref;
        first_unref = p;
    }
    return p;
}

static struct strconst *inst_strconst(char *s, int len)
{
    int i = hasher(s, strconst_hash);
    struct strconst *p = strconst_hash[i];
    while (p && p->s != s)
        p = p->b_next;
    if (!p) {
        p = Alloc(struct strconst);
        p->b_next = strconst_hash[i];
        strconst_hash[i] = p;
        p->s = s;
        p->len = len;
        p->offset = strconst_offset;
        /* We include the zero added by str_install (strtbl.c) 
         * when the string was interned */
        strconst_offset += p->len + 1;  
        if (last_strconst) {
            last_strconst->next = p;
            last_strconst = p;
        } else
            first_strconst = last_strconst = p;
    }
    return p;
}

static struct strconst *inst_c_strconst(char *s)
{
    return inst_strconst(s, strlen(s));
}

void generate_code()
{
    struct lfile *lf;

    nstatics = 0;
    strconst_offset = 0;
    first_strconst = last_strconst = 0;
    ArrClear(strconst_hash);
    first_unref = 0;
    ArrClear(unref_hash);
    curr_file = last_fnmtbl_filen = 0;
    curr_line = 0;

    /*
     * Initialize some dynamically-sized tables.
     */
    lnfree = lntable = safe_calloc(nsize, sizeof(struct ipc_line));
    fnmfree = fnmtbl = safe_calloc(fnmsize, sizeof(struct ipc_fname));
    labels  = safe_calloc(maxlabels, sizeof(word));
    codep = codeb = safe_calloc(maxcode, 1);

    /*
     * Loop through input files and generate code for each.
     */
    for (lf = lfiles; lf; lf = lf->next) {
        inname = lf->name;
        ucodefile = fopen(inname, ReadBinary);
        if (!ucodefile)
            quitf("cannot open .u for %s", inname);
        fseek(ucodefile, lf->declend_offset, SEEK_SET);
        gencode(lf);
        fclose(ucodefile);
    }

    gentables();		/* Generate record, field, global, global names,
                                   static, and identifier tables. */

    /*
     * Free the tables allocated above.
     */
    free(lntable);   
    lntable = 0;
    free(fnmtbl);   
    fnmtbl = 0;
    free(labels);
    labels = 0;
    free(codep);
    codep = 0;
}

/*
 * Prototypes.
 */

static int      nalign(int n);
static void	align		(void);
static void	backpatch	(int lab);
static void	clearlab	(void);
static void	flushcode	(void);
static void	intout		(int oint);
static void	lemit		(int op,char *name);
static void     lemitcon(struct centry *ce);
static void	lemitin		(int op,word offset,int n,char *name);
static void	lemitint	(int op,long i,char *name);
static void	lemitl		(int op,int lab,char *name);
static void	lemitn		(int op,word n,char *name);
static void	lemitproc       (struct lfunction *func);
static void	lemitr		(int op,word loc,char *name);
static void	misalign	(void);
static void	outblock	(char *addr,int count);
static void	wordout		(word oword);
static void	shortout	(short o);

static void	dumpblock	(char *addr,int count);


word pc = 0;		/* simulated program counter */

#define outword(n)	wordout((word)(n))
#define outop(n)	intout((int)(n))
#define outchar(n)	charout((unsigned char)(n))
#define outshort(n)	shortout((short)(n))
#define CodeCheck(n) if ((long)codep + (n) > (long)((long)codeb + maxcode)) \
codeb = (char *) expand_table(codeb, &codep, &maxcode, 1,                   \
                          (n), "code buffer");

/*
 * gencode - read .u1 file, resolve variable references, and generate icode.
 *  Basic process is to read each line in the file and take some action
 *  as dictated by the opcode.	This action sometimes involves parsing
 *  of arguments and usually culminates in the call of the appropriate
 *  lemit* routine.
 */
static void gencode(struct lfile *lf)
{
    int k, op, lab, in_proc;
    int flags;
    char *name;
    struct centry *cp;
    struct lentry *lp;
    struct gentry *gp;
    struct fentry *fp;
    struct lfunction *curr_func = 0;
    struct strconst *sp;
    struct ucode_op *uop;

    /*
     * This variable notes whether we are within a wanted
     * procedure/method; will not be for the Op_Filen/Op_Line between
     * the Op_End of one proc and the beginning of the next.
     */
    in_proc = 0;

    while ((uop = uin_op())) {
        op = uop->opcode;
        name = uop->name;
        switch (op) {

            /* Ternary operators. */

            case Op_Toby:
            case Op_Sect:

                /* Binary operators. */

            case Op_Asgn:
            case Op_Cat:
            case Op_Diff:
            case Op_Div:
            case Op_Eqv:
            case Op_Inter:
            case Op_Lconcat:
            case Op_Lexeq:
            case Op_Lexge:
            case Op_Lexgt:
            case Op_Lexle:
            case Op_Lexlt:
            case Op_Lexne:
            case Op_Minus:
            case Op_Mod:
            case Op_Mult:
            case Op_Neqv:
            case Op_Numeq:
            case Op_Numge:
            case Op_Numgt:
            case Op_Numle:
            case Op_Numlt:
            case Op_Numne:
            case Op_Plus:
            case Op_Power:
            case Op_Rasgn:
            case Op_Rswap:
            case Op_Subsc:
            case Op_Swap:
            case Op_Unions:

                /* Unary operators. */

            case Op_Bang:
            case Op_Compl:
            case Op_Neg:
            case Op_Nonnull:
            case Op_Null:
            case Op_Number:
            case Op_Random:
            case Op_Refresh:
            case Op_Size:
            case Op_Tabmat:
            case Op_Value:

                /* Instructions. */

            case Op_Bscan:
            case Op_Ccase:
            case Op_Coact:
            case Op_Cofail:
            case Op_Coret:
            case Op_Dup:
            case Op_Efail:
            case Op_Eret:
            case Op_Escan:
            case Op_Esusp:
            case Op_Limit:
            case Op_Lsusp:
            case Op_Pfail:
            case Op_Pnull:
            case Op_Pop:
            case Op_Pret:
            case Op_Psusp:
            case Op_Push1:
            case Op_Pushn1:
            case Op_Sdup:
            case Op_Apply:
                lemit(op, name);
                break;

            case Op_Chfail:
            case Op_Create:
            case Op_Goto:
            case Op_Init:
                lab = uin_short();
                lemitl(op, lab, name);
                break;

            case Op_Cset:
            case Op_Real:
                k = uin_short();
                lemitr(op, curr_func->constant_table[k]->c_pc, name);
                break;

            case Op_Field: {
                char *s = uin_str();
                fp = flocate(s);
                if (fp)
                    lemitn(op, (word)(fp->field_id), name);
                else {
                    /* Get or create an unref record */
                    struct unref *p = get_unref(s);
                    lemitn(op, (word) p->num, name);
                }
                if (Dflag) {
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                }
                outword(0);
                outword(0);
                break;
            }

            case Op_Int: {
                long i;
                k = uin_short();
                cp = curr_func->constant_table[k];
                /*
                 * Check to see if a large integers has been converted to a string.
                 *  If so, generate the code for +s.
                 */
                if (cp->c_flag & F_StrLit) {
                    lemit(Op_Pnull,"pnull");
                    sp = inst_strconst(cp->c_val.sval, cp->c_length);
                    lemitin(Op_Str, sp->offset, sp->len, "str");
                    lemit(Op_Number,"number");
                    break;
                }
                i = (long)cp->c_val.ival;
                lemitint(op, i, name);
                break;
            }

            case Op_Invoke:
                k = uin_short();
                lemitn(op, (word)k, name);
                break;

            case Op_Keywd: {
                char *s = uin_str();
                k = klookup(s);
                switch (k) {
                    case 0:
                        lfatal(lf, 0, "invalid keyword: %s", s);	
                        break;
                    case K_FAIL:
                        lemit(Op_Efail,"efail");
                        break;
                    case K_NULL:
                        lemit(Op_Pnull,"pnull");
                        break;
                    default:
                        lemitn(op, (word)k, name);
                }
                break;
            }

            case Op_Llist:
                k = uin_word();
                lemitn(op, (word)k, name);
                break;

            case Op_Lab:
                lab = uin_short();

                if (Dflag)
                    fprintf(dbgfile, "L%d:\n", lab);
                backpatch(lab);
                break;

            case Op_Mark:
                lab = uin_short();
                lemitl(op, lab, name);
                break;

            case Op_Mark0:
                lemit(op, name);
                break;

            case Op_Str:
                k = uin_short();
                cp = curr_func->constant_table[k];
                sp = inst_strconst(cp->c_val.sval, cp->c_length);
                lemitin(op, sp->offset, sp->len, name);
                break;
        
            case Op_Unmark:
                lemit(Op_Unmark, name);
                break;

            case Op_Var:
                k = uin_short();
                lp = curr_func->local_table[k];
                flags = lp->l_flag;
                if (flags & F_Global)
                    lemitn(Op_Global, (word)(lp->l_val.global->g_index),
                           "global");
                else if (flags & F_Static)
                    lemitn(Op_Static, lp->l_val.index, "static");
                else if (flags & F_Argument)
                    lemitn(Op_Arg, lp->l_val.index, "arg");
                else if (flags & F_Field) {
                    fp = flocate(lp->name);
                    if (!fp)
                        quitf("Couldn't find class field in field table:%s", lp->name);
                    lemit(Op_Pnull,"pnull");
                    if (lp->l_val.field->flag & M_Static)  /* Ref to class var, eg Class.CONST */
                        lemitn(Op_Global, (word)(lp->l_val.field->class->global->g_index), "global");
                    else
                        lemitn(Op_Arg, 0, "arg");          /* inst var, "self" is the 0th argument */
                    lemitn(Op_Field, (word)(fp->field_id), "field");
                    if (Dflag) {
                        fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                        fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                    }
                    outword(0);
                    outword(0);
                } else
                    lemitn(Op_Local, lp->l_val.index, "local");
                break;

                /* Declarations. */

            case Op_Proc: {
                char *s = uin_fqid(lf->package);
                if ((gp = glocate(s))) {
                    /*
                     * Initialize for wanted procedure.
                     */
                    synch_file();
                    synch_line();
                    in_proc = 1;
                    clearlab();
                    align();
                    if (Dflag)
                        fprintf(dbgfile, "\n# procedure %s\n", s);

                    curr_func = gp->func;
                    for (cp = curr_func->constants; cp; cp = cp->next) {
                        cp->c_pc = pc;
                        lemitcon(cp);
                    }
                    curr_func->pc = pc;
                    lemitproc(curr_func);
                }
                else {
                    in_proc = 0;
                    skip_proc();
                }
                break;
            }

            case Op_Method: {
                char *class, *meth;
                struct lclass_field *method;
                class = uin_fqid(lf->package);
                meth = uin_str();
                if ((method = lookup_method(class, meth))) {
                    /*
                     * Initialize for wanted method.
                     */
                    synch_file();
                    synch_line();
                    in_proc = 1;
                    clearlab();
                    align();
                    if (Dflag)
                        fprintf(dbgfile, "\n# method %s.%s\n", class, meth);

                    curr_func = method->func;
                    for (cp = curr_func->constants; cp; cp = cp->next) {
                        cp->c_pc = pc;
                        lemitcon(cp);
                    }
                    curr_func->pc = pc;
                    lemitproc(curr_func);
                }
                else {
                    in_proc = 0;
                    skip_proc();
                }
                break;
            }

            case Op_Local:
                break;

            case Op_Con:
                break;

            case Op_Filen:
                curr_file = uin_str();
                if (in_proc)
                    synch_file();
                break;

            case Op_Line:
                curr_line = uin_short();
                if (in_proc)
                    synch_line();
                break;

            case Op_End:
                flushcode();
                in_proc = 0;
                break;

            default:
                quitf("gencode: illegal opcode(%d): %s\n", op, name);
        }
    }
}

/*
 * Skip unreferenced procedure.
 */
void skip_proc()
{
    int op;
    struct ucode_op *uop;
    while (1) {
        uop = uin_expectop();
        op = uop->opcode;
        switch (op) {
            case Op_End:
                return;
            case Op_Filen:
                curr_file = uin_str();
                break;
            case Op_Line:
                curr_line = uin_short();
                break;
            default:
                uin_skip(op);
        }
    }
}

void synch_file()
{
    struct strconst *sp;

    /*
     * Avoid adjacent entries with the same name.
     */
    if (curr_file == last_fnmtbl_filen)
        return;

    if (fnmfree >= &fnmtbl[fnmsize])
        fnmtbl = (struct ipc_fname *) expand_table(fnmtbl, &fnmfree,
                                               &fnmsize, sizeof(struct ipc_fname), 1, "file name table");
    last_fnmtbl_filen = curr_file;
    fnmfree->ipc = pc;
    sp = inst_c_strconst(intern(last_pathelem(curr_file)));
    fnmfree->fname = sp->offset;
    fnmfree++;
}

void synch_line()
{
    if (lnfree >= &lntable[nsize])
        lntable  = (struct ipc_line *)expand_table(lntable, &lnfree, &nsize,
                                               sizeof(struct ipc_line), 1, "line number table");
    lnfree->ipc = pc;
    lnfree->line = curr_line;
    lnfree++;
}



/*
 *  lemit - emit opcode.
 *  lemitl - emit opcode with reference to program label.
 *	for a description of the chaining and backpatching for labels.
 *  lemitn - emit opcode with integer argument.
 *  lemitr - emit opcode with pc-relative reference.
 *  lemitin - emit opcode with reference to identifier table & integer argument.
 *  lemitint - emit word opcode with integer argument.
 *  lemitcon - emit constant table entry.
 *  lemitproc - emit procedure block.
 *
 * The lemit* routines call out* routines to effect the "outputting" of icode.
 *  Note that the majority of the code for the lemit* routines is for debugging
 *  purposes.
 */

static void lemit(op, name)
    int op;
    char *name;
{

    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t\t\t\t# %s\n", (long)pc, op, name);

    outop(op);
}

static void lemitl(op, lab, name)
    int op, lab;
    char *name;
{
    misalign();

    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\tL%d\t\t\t# %s\n", (long)pc, op, lab, name);

    if (lab >= maxlabels)
        labels  = (word *) expand_table(labels, NULL, &maxlabels, sizeof(word),
                                    lab - maxlabels + 1, "labels");
    outop(op);
    if (labels[lab] <= 0) {		/* forward reference */
        outword(labels[lab]);
        labels[lab] = WordSize - pc;	/* add to front of reference chain */
    }
    else					/* output relative offset */

    outword(labels[lab] - (pc + WordSize));
}

static void lemitn(op, n, name)
    int op;
    word n;
    char *name;
{
    misalign();

    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t%ld\t\t\t# %s\n", (long)pc, op, (long)n,
                name);

    outop(op);
    outword(n);
}


static void lemitr(op, loc, name)
    int op;
    word loc;
    char *name;
{
    misalign();

    loc -= pc + ((IntBits/ByteBits) + WordSize);
    if (Dflag) {
        if (loc >= 0)
            fprintf(dbgfile, "%ld:\t%d\t*+%ld\t\t\t# %s\n",(long) pc, op,
                    (long)loc, name);
        else
            fprintf(dbgfile, "%ld:\t%d\t*-%ld\t\t\t# %s\n",(long) pc, op,
                    (long)-loc, name);
    }

    outop(op);
    outword(loc);
}

static void lemitin(op, offset, n, name)
    int op, n;
    word offset;
    char *name;
{
    misalign();

    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t%d,S+%ld\t\t\t# %s\n", (long)pc, op, n,
                (long)offset, name);

    outop(op);
    outword(n);
    outword(offset);
}

/*
 * lemitint can have some pitfalls.  outword is used to output the
 *  integer and this is picked up in the interpreter as the second
 *  word of a short integer.  The integer value output must be
 *  the same size as what the interpreter expects.  See op_int and op_intx
 *  in interp.s
 */
static void lemitint(op, i, name)
    int op;
    long i;
    char *name;
{
    misalign();

    if (Dflag)
        fprintf(dbgfile,"%ld:\t%d\t%ld\t\t\t# %s\n",(long)pc,op,(long)i,name);

    outop(op);
    outword(i);
}

static void lemitcon(struct centry *ce)
{
    union {
        char ovly[1];  /* Array used to overlay l and f on a bytewise basis. */
        long l;
        double f;
    } x;

    if (ce->c_flag & F_RealLit) {

#ifdef Double
/* access real values one word at a time */
        {  int *rp, *rq;
            rp = (int *) &(x.f);
            rq = (int *) &(ce->c_val.rval);
            *rp++ = *rq++;
            *rp	= *rq;
        }
#else					/* Double */
        x.f = ce->c_val.rval;
#endif					/* Double */

        if (Dflag) {
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# real(%g)", (long)pc, T_Real, x.f);
            dumpblock(x.ovly,sizeof(double));
        }

        outword(T_Real);

#ifdef Double
#if WordBits != 64
        /* fill out real block with an empty word */
        outword(0);
        if (Dflag)
	    fprintf(dbgfile,"\t0\t\t\t\t\t# padding\n");
#endif				/* WordBits != 64 */
#endif					/* Double */

        outblock(x.ovly,sizeof(double));
    }
    else if (ce->c_flag & F_CsetLit) {
        int i, j, x;
        int csbuf[CsetSize];
        int npair = ce->c_length / sizeof(struct range);
        int size = 0;
        struct range *pair = safe_alloc(ce->c_length);
        memcpy(pair, ce->c_val.sval, ce->c_length);
        for (i = 0; i < CsetSize; i++)
            csbuf[i] = 0;
        for (i = 0; i < npair; ++i) {
            size += pair[i].to - pair[i].from + 1;
            for (j = pair[i].from; j <= pair[i].to; ++j) {
                if (j > 0xff)
                    break;
                Setb(j, csbuf);
            }
        }
        if (Dflag) {
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Cset\n",(long) pc, T_Cset);
            fprintf(dbgfile, "\t%d\t\t\t\t# Block size\n", (CsetSize + 4 + 3 * npair) * WordSize);
            fprintf(dbgfile, "\t%d\t\t\t\t# Cset size\n", size);
            for (i = 0; i < CsetSize; ++i)
                fprintf(dbgfile, "\t%08x\t\t\t#    Binary map\n", csbuf[i]);
            fprintf(dbgfile, "\t%d\t\t\t\t# Npair\n", npair);
            x = 0;
            for (i = 0; i < npair; ++i) {
                fprintf(dbgfile, "\t%d\t\t\t\t#    Index\n", x);
                fprintf(dbgfile, "\t%d\t\t\t\t#    From\n", pair[i].from);
                fprintf(dbgfile, "\t%d\t\t\t\t#    To\n", pair[i].to);
                x += pair[i].to - pair[i].from + 1;
            }
        }

        outword(T_Cset);
        outword((CsetSize + 4 + 3 * npair) * WordSize);
        outword(size);		   /* cset size */
        for (i = 0; i < CsetSize; ++i)
            outword(csbuf[i]);
        outword(npair);
        x = 0;
        for (i = 0; i < npair; ++i) {
            outword(x);
            outword(pair[i].from);
            outword(pair[i].to);
            x += pair[i].to - pair[i].from + 1;
        }

        free(pair);
    }
}

static void lemitproc(struct lfunction *func)
{
    char *p;
    int size;
    struct lentry *le;
    struct strconst *sp;

    /*
     * FncBlockSize = sizeof(BasicFncBlock) +
     *  sizeof(descrip)*(# of args + # of dynamics + # of statics).
     */
    if (abs(func->nargs) != func->narguments)
        quitf("Mismatch between ufile's nargs and narguments");

    size = (12*WordSize) + (2*WordSize) * (func->narguments + func->ndynamic + func->nstatics);
    if (func->proc)
        p = func->proc->name;
    else
        p = func->method->name;

    sp = inst_c_strconst(p);

    if (Dflag) {
        fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Proc\n", (long)pc, T_Proc); /* type code */
        fprintf(dbgfile, "\t%d\t\t\t\t# Block size\n", size);			/* size of block */
        fprintf(dbgfile, "\tZ+%ld\t\t\t\t# Entry point\n",(long)(pc+size));	/* entry point */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num args\n", func->nargs);	/* # arguments */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num dynamic\n", func->ndynamic);	/* # dynamic locals */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num static\n", func->nstatics);	/* # static locals */
        fprintf(dbgfile, "\t%d\t\t\t\t# First static\n", nstatics);		/* first static */
        fprintf(dbgfile, "\t0\n");		        /* owning prog space */
        fprintf(dbgfile, "\t%d\t\t\t\t# Package id\n", func->defined->package_id);       /* package id */
        fprintf(dbgfile, "\t0\n");		        /* field */
        fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n",	/* name of procedure */
                sp->len, sp->offset, p);
    }

    outword(T_Proc);
    outword(size);
    outword(pc + size - 2*WordSize); /* Have to allow for the two words
                			that we've already output. */
    outword(func->nargs);
    outword(func->ndynamic);
    outword(func->nstatics);
    outword(nstatics);
    outword(0);
    outword(func->defined->package_id);
    outword(0);
    outword(sp->len);          /* procedure name: length & offset */
    outword(sp->offset);

    /*
     * Output string descriptors for argument names by looping through
     *  all locals, and picking out those with F_Argument set.
     */
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Argument) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }

    /*
     * Output string descriptors for local variable names.
     */
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Dynamic) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }

    /*
     * Output string descriptors for static variable names, and set their
     * index numbers.
     */
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Static) {
            sp = inst_c_strconst(le->name);
            le->l_val.index = nstatics++;
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }
}

struct field_sort_item {
    int n;
    struct fentry *fp;
};

static int field_sort_compare(const void *p1, const void *p2)
{
    struct field_sort_item *f1, *f2;
    f1 = (struct field_sort_item *)p1;
    f2 = (struct field_sort_item *)p2;
    return f1->fp->field_id - f2->fp->field_id;
}

static struct field_sort_item *sorted_fields(struct lclass *cl)
{
    struct lclass_field_ref *fr;
    int n = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;
    struct field_sort_item *a = safe_calloc(n, sizeof(struct field_sort_item));
    int i = 0;
    for (fr = cl->implemented_instance_fields; fr; fr = fr->next, ++i) {
        a[i].n = fr->index = i;
        a[i].fp = fr->field->ftab_entry;
    }
    for (fr = cl->implemented_class_fields; fr; fr = fr->next, ++i) {
        a[i].n = fr->index = i;
        a[i].fp = fr->field->ftab_entry;
    }
    qsort(a, n, sizeof(struct field_sort_item), field_sort_compare);
    return a;
}

static struct field_sort_item *sorted_record_fields(struct lrecord *cl)
{
    struct lfield *lf;
    struct field_sort_item *a = safe_calloc(cl->nfields, sizeof(struct field_sort_item));
    int i = 0;
    for (lf = cl->fields; lf; lf = lf->next, ++i) {
        a[i].n = i;
        a[i].fp = lf->ftab_entry;
    }
    qsort(a, cl->nfields, sizeof(struct field_sort_item), field_sort_compare);
    return a;
}

static void genclass(struct lclass *cl)
{
    struct lclass_ref *cr;
    struct lclass_field_ref *fr;
    struct field_sort_item *sortf;
    char *name;
    int i, ap, n_fields;
    struct strconst *sp;
    word p;

    if (cl->pc != pc)
        quitf("I got my sums wrong(a): %d != %d", pc, cl->pc);
    
    name = cl->global->name;
    sp = inst_c_strconst(name);

    n_fields = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;

    if (Dflag) {
        fprintf(dbgfile, "\n# class %s\n", name);
        fprintf(dbgfile, "%ld:\n", (long)pc);
        fprintf(dbgfile, "\t%d\t\t\t\t# T_Class\n", T_Class);
        fprintf(dbgfile, "\t%d\t\t\t\t# Block size\n", cl->size);
        fprintf(dbgfile, "\t0\t\t\t\t# Owning prog\n");
        fprintf(dbgfile, "\t0\t\t\t\t# is() lookup table\n");
        fprintf(dbgfile, "\t%d\t\t\t\t# Class id\n", cl->id);
        fprintf(dbgfile, "\t%d\t\t\t\t# Package id\n", cl->global->defined->package_id);
        fprintf(dbgfile, "\t0\t\t\t\t# Instance ids counter\n");
        fprintf(dbgfile, "\t%d\t\t\t\t# Initialization state\n", Uninitialized);
        fprintf(dbgfile, "\t%08o\t\t\t# Flags\n", cl->flag);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nsupers\n", cl->n_supers);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nimplemented\n", cl->n_implemented_classes);
        fprintf(dbgfile, "\t%d\t\t\t\t# Ninstancefields\n", cl->n_implemented_instance_fields);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nclassfields\n", cl->n_implemented_class_fields);
        fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, name);
    }
    outword(T_Class);		/* type code */
    outword(cl->size);
    outword(0);
    outword(0);
    outword(cl->id);
    outword(cl->global->defined->package_id);
    outword(0);
    outword(Uninitialized);
    outword(cl->flag);
    outword(cl->n_supers);
    outword(cl->n_implemented_classes);
    outword(cl->n_implemented_instance_fields);
    outword(cl->n_implemented_class_fields);
    outword(sp->len);		/* name of class: size and offset */
    outword(sp->offset);

    i = hasher(init_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != init_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;
    if (Dflag)
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to init field\n", p);
    outword(p);

    i = hasher(new_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != new_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;
    if (Dflag)
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to new field\n", p);
    outword(p);

    /*
     * Pointers to the tables that follow.
     */
    if (Dflag) {
        ap = pc + 4 * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to superclass array\n", ap);
        ap += cl->n_supers * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to implemented classes array\n", ap);
        ap += cl->n_implemented_classes * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field info array\n", ap);
        ap += n_fields * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field sort array\n", ap);
    }

    ap = pc + 4 * WordSize;
    outword(ap);
    ap += cl->n_supers * WordSize;
    outword(ap);
    ap += cl->n_implemented_classes * WordSize;
    outword(ap);
    ap += n_fields * WordSize;
    outword(ap);
    ap += n_fields * ShortSize;
    ap += nalign(ap);

    /*
     * Superclass array.
     */
    if (Dflag) {
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Superclass array\n", (long)pc);
        for (cr = cl->resolved_supers; cr; cr = cr->next)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Pointer to superclass\n", cr->class->pc);
    }
    for (cr = cl->resolved_supers; cr; cr = cr->next)
        outword(cr->class->pc);

    /*
     * Implemented classes array.
     */
    if (Dflag) {
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Implemented classes array\n", (long)pc);
        for (cr = cl->implemented_classes; cr; cr = cr->next)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Pointer to implemented class\n", cr->class->pc);
    }
    for (cr = cl->implemented_classes; cr; cr = cr->next)
        outword(cr->class->pc);

    /* 
     * An array of pointers to the field info of each field 
     */
    if (Dflag) {
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Field info array\n", (long)pc);
        for (fr = cl->implemented_instance_fields; fr; fr = fr->next)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Info for field %s\n", 
                    fr->field->ipc, fr->field->name);
        for (fr = cl->implemented_class_fields; fr; fr = fr->next)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Info for field %s\n", 
                    fr->field->ipc, fr->field->name);
    }
    for (fr = cl->implemented_instance_fields; fr; fr = fr->next)
        outword(fr->field->ipc);
    for (fr = cl->implemented_class_fields; fr; fr = fr->next)
        outword(fr->field->ipc);

    /* 
     * The sorted fields table.
     */
    sortf = sorted_fields(cl);
    if (Dflag) {
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Sorted fields array\n", (long)pc);
        for (i = 0; i < n_fields; ++i)
            fprintf(dbgfile, "\t%d\t\t\t\t#   Field %s (fnum=%d)\n", 
                    sortf[i].n, 
                    sortf[i].fp->name,
                    sortf[i].fp->field_id);
    }
    for (i = 0; i < n_fields; ++i)
        outshort(sortf[i].n);
    free(sortf);

    if (Dflag) 
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Padding bytes (%d)\n", (long)pc, nalign(pc));

    align();

    /* Check our calculations were right */
    if (ap != pc)
        quitf("I got my sums wrong(b): %d != %d", ap, pc);
    if (cl->pc + cl->size != pc)
        quitf("I got my sums wrong(c): %d != %d", cl->pc + cl->size, pc);
}

static void genclasses()
{
    struct lclass *cl;
    struct lclass_field *cf;
    int x, n_classes = 0, n_fields = 0;
    struct strconst *sp;

    align();
    hdr.ClassStatics = pc;

    /*
     * Output descriptors for class variables :-
     *   static class variables get a null descriptor
     *   class instance variables don't get an entry
     *   defer methods get a proc descriptor with the 
     *      native method number (-1 if unresolved) in the vword
     *   other methods get a proc descriptor pointing to the b_proc
     */
    if (Dflag)
        fprintf(dbgfile, "\n# class static and method descriptors\n");
    for (cl = lclasses; cl; cl = cl->next) {
        cl->id = n_classes;
        for (cf = cl->fields; cf; cf = cf->next) {
            if (cf->flag & M_Defer) {
                /* Deferred method, perhaps resolved to native method */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%06o\tN+%d\t\t# Deferred method %s.%s\n",
                            (long)pc, D_Proc, cf->func->native_method_id, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Proc);
                outword(cf->func->native_method_id);
            } else if (cf->flag & M_Method) {
                /* Method, with definition in the icode file  */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%06o\tZ+%d\t\t# Method %s.%s\n",
                            (long)pc, D_Proc, cf->func->pc, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Proc);
                outword(cf->func->pc);
            } else if (cf->flag & M_Static) {
                /* Null descriptor */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t0\t0\t\t\t# Static var %s.%s\n", 
                            (long)pc, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Null);
                outword(0);
            }
            ++n_fields;
        }
        ++n_classes;
    }

    align();
    hdr.ClassFields = pc;

    /* 
     * Firstly work out the "address" each class will have, so we can forward
     * reference them.
     */
    x = pc + WordSize * (1 + 6 * n_fields);  /* The size of the class
                                              * field table plus the
                                              * n_classes entry */
    for (cl = lclasses; cl; cl = cl->next) {
        int n_fields = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;
        cl->pc = x;
        cl->size = WordSize * (20 +
                               1 + 
                               cl->n_supers +
                               cl->n_implemented_classes +
                               n_fields) + 
            ShortSize * n_fields;

        cl->size += nalign(cl->size);
        x += cl->size;
    }

    /*
     * Output the class field info table
     */
    if (Dflag)
        fprintf(dbgfile, "\n# class field info table\n");
    for (cl = lclasses; cl; cl = cl->next) {
        for (cf = cl->fields; cf; cf = cf->next) {
            cf->ipc = pc;
            sp = inst_c_strconst(cf->name);
            if (Dflag) {
                fprintf(dbgfile, "%ld:\t\t\t\t\t# Field info for %s.%s\n", 
                        (long)pc, cl->global->name, cf->name);
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   Name %s\n", sp->len, sp->offset, cf->name);
                fprintf(dbgfile, "\t%d\t\t\t#   Fnum\n", cf->ftab_entry->field_id);
                fprintf(dbgfile, "\t%08o\t\t\t#   Flags\n", cf->flag);
                fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Defining class\n", cf->class->pc);
                fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Pointer to descriptor\n", cf->dpc);

            }
            outword(sp->len);		/* name of field: size and offset */
            outword(sp->offset);
            outword(cf->ftab_entry->field_id);
            outword(cf->flag);
            outword(cf->class->pc);
            outword(cf->dpc);
        }
    }

    align();
    hdr.Classes = pc;
    if (Dflag) {
        fprintf(dbgfile,"\n%ld:\t%d\t\t\t\t# num class blocks\n", (long)pc, n_classes);
    }
    outword(n_classes);

    for (cl = lclasses; cl; cl = cl->next)
        genclass(cl);
}

/*
 * gentables - generate interpreter code for global, static,
 *  identifier, and record tables, and built-in procedure blocks.
 */
static void gentables()
{
    int i, nrecords;
    char *s;
    struct gentry *gp;
    struct lrecord *rec;
    struct fentry *fp;
    struct lfield *fd;
    struct unref *up;
    struct strconst *sp;

    if (Dflag) {
        fprintf(dbgfile,"\n\n# global tables\n");
    }

    genclasses();

    /* Count how many records we have. */
    nrecords = 0;
    for (rec = lrecords; rec; rec = rec->next)
        ++nrecords;

    /*
     * Output record constructor procedure blocks.
     */
    align();
    hdr.Records = pc;

    if (Dflag) {
        fprintf(dbgfile,"\n%ld:\t%d\t\t\t\t# num record blocks\n",(long)pc,nrecords);
    }

    outword(nrecords);
    for (rec = lrecords; rec; rec = rec->next) {
        struct field_sort_item *sortf;
        int ap, size;
        s = rec->global->name;
        rec->pc = pc;
        sp = inst_c_strconst(s);
        size = 9 * WordSize + rec->nfields * (2 * WordSize + ShortSize);
        size += nalign(size);
        if (Dflag) {
            fprintf(dbgfile, "\n# constructor %s\n", s);
            fprintf(dbgfile, "%ld:\n", (long)pc);
            fprintf(dbgfile, "\t%d\t\t\t\t# T_Constructor\n", T_Constructor);
            fprintf(dbgfile, "\t%d\n", size);
            fprintf(dbgfile, "\t0\n");
            fprintf(dbgfile, "\t0\n");
            fprintf(dbgfile, "\t%d\n", rec->nfields);
            fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, s);
        }

        outword(T_Constructor);		/* type code */
        outword(size);
        outword(0);			/* progstate (filled in by interp)*/
        outword(0);			/* serial number counter */
        outword(rec->nfields);		/* number of fields */
        outword(sp->len);		/* name of record: size and offset */
        outword(sp->offset);

        /*
         * Pointers to the two tables that follow.
         */
        if (Dflag) {
            ap = pc + 2 * WordSize;
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field_names array\n", ap);
            ap += rec->nfields * 2 * WordSize;
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field sort array\n", ap);
        }
        ap = pc + 2 * WordSize;
        outword(ap);
        ap += rec->nfields * 2 * WordSize;
        outword(ap);
        ap += rec->nfields * ShortSize;
        ap += nalign(ap);

        /*
         * Field names
         */
        if (Dflag)
            fprintf(dbgfile, "%ld:\t\t\t\t\t# Field names array\n", (long)pc);
        for (fd = rec->fields; fd; fd = fd->next) {
            sp = inst_c_strconst(fd->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, fd->name);
            outword(sp->len);
            outword(sp->offset);
        }

        /* 
         * The sorted fields table.
         */
        sortf = sorted_record_fields(rec);
        if (Dflag) {
            fprintf(dbgfile, "%ld:\t\t\t\t\t# Sorted fields array\n", (long)pc);
            for (i = 0; i < rec->nfields; ++i)
                fprintf(dbgfile, "\t%d\t\t\t\t#   Field %s (fnum=%d)\n", 
                        sortf[i].n, 
                        sortf[i].fp->name,
                        sortf[i].fp->field_id);
        }
        for (i = 0; i < rec->nfields; ++i)
            outshort(sortf[i].n);
        free(sortf);

        if (Dflag) {
            fprintf(dbgfile, "%ld:\t\t\t\t\t# Padding bytes (%d)\n", (long)pc, nalign(pc));
        }
        align();

        /* Check our calculations were right */
        if (ap != pc)
            quitf("I got my sums wrong(d): %d != %d", ap, pc);
        if (rec->pc + size != pc)
            quitf("I got my sums wrong(e): %d != %d", rec->pc + size, pc);
    }

    /*
     * Output descriptors for field names.
     */
    align();
    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Field names table\n", (long)pc);
    hdr.Fnames = pc;
    for (fp = lffirst; fp; fp = fp->next) {
        sp = inst_c_strconst(fp->name);
        if (Dflag)
            fprintf(dbgfile, "%ld:\t%d\tS+%d\t\t\t#   %s\n", (long)pc, sp->len, sp->offset, fp->name);
        outword(sp->len);      /* name of field: length & offset */
        outword(sp->offset);
    }
    for(up = first_unref; up; up = up->next) {
        sp = inst_c_strconst(up->name);
        if (Dflag)
            fprintf(dbgfile, "%ld:\t%d\tS+%d\t\t\t# Unref field %s\n",
                    (long)pc, sp->len, sp->offset, up->name);
        outword(sp->len);
        outword(sp->offset);
    }

    /*
     * Output global variable descriptors.
     */
    hdr.Globals = pc;
    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Global variable descriptors\n", (long)pc);
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->g_flag & F_Builtin) {		/* function */

            if (Dflag)
                fprintf(dbgfile, "%ld:\t%06lo\t%d\t\t#   %s\n",
                        (long)pc, (long)D_Proc, -gp->builtin->builtin_id - 1, gp->name);
            outword(D_Proc);
            outword(-gp->builtin->builtin_id - 1);
        }
        else if (gp->g_flag & F_Proc) {		/* Icon procedure */

            if (Dflag)
                fprintf(dbgfile, "%ld:\t%06lo\tZ+%ld\t\t#   %s\n",
                        (long)pc,(long)D_Proc, (long)gp->func->pc, gp->name);

            outword(D_Proc);
            outword(gp->func->pc);
        }
        else if (gp->g_flag & F_Record) {		/* record constructor */

            if (Dflag)
                fprintf(dbgfile, "%ld:\t%06lo\tZ+%ld\t\t#   %s\n",
                        (long)pc, (long)D_Constructor, (long)gp->record->pc, gp->name);

            outword(D_Constructor);
            outword(gp->record->pc);
        }
        else if (gp->g_flag & F_Class) {		/* class */

            if (Dflag)
                fprintf(dbgfile, "%ld:\t%06lo\tZ+%ld\t\t#   %s\n",
                        (long)pc, (long)D_Class, (long)gp->class->pc, gp->name);

            outword(D_Class);
            outword(gp->class->pc);
        }
        else {					/* simple global variable */
            if (Dflag)
                fprintf(dbgfile, "%ld:\t%06lo\t0\t\t#   %s\n",(long)pc,
                        (long)D_Null, gp->name);

            outword(D_Null);
            outword(0);
        }
    }

    /*
     * Output descriptors for global variable names.
     */
    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Global variable name descriptors\n", (long)pc);
    hdr.Gnames = pc;
    for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
        sp = inst_c_strconst(gp->name);
        if (Dflag)
            fprintf(dbgfile, "%ld:\t%d\tS+%d\t\t\t#   %s\n",
                    (long)pc, sp->len, sp->offset, gp->name);

        outword(sp->len);
        outword(sp->offset);
    }

    /*
     * Output a null descriptor for each static variable.
     */
    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Static variable null descriptors\n", (long)pc);
    hdr.Statics = pc;
    for (i = 0; i < nstatics; ++i) {

        if (Dflag)
            fprintf(dbgfile, "%ld:\t0\t0\n", (long)pc);

        outword(D_Null);
        outword(0);
    }
    flushcode();

    /*
     * Output the string constant table and the two tables associating icode
     *  locations with source program locations.  Note that the calls to write
     *  really do all the work.
     */

    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Filenms table\n", (long)pc);
    hdr.Filenms = pc;
    if (longwrite((char *)fnmtbl, (long)((char *)fnmfree - (char *)fnmtbl),
                  outfile) < 0)
        quit("cannot write icode file");

    if (Dflag) {
        int k = 0;
        struct ipc_fname *ptr;
        for (ptr = fnmtbl; ptr < fnmfree; ptr++) {
            fprintf(dbgfile, "%ld:\t%03d\tS+%03d\t\t\t#   Str offset %d\n",
                    (long)(pc + k), ptr->ipc, ptr->fname, ptr->fname);
            k = k + 8;
        }
        putc('\n', dbgfile);
    }


    pc += (char *)fnmfree - (char *)fnmtbl;

    hdr.linenums = pc;
    if (longwrite((char *)lntable, (long)((char *)lnfree - (char *)lntable),
                  outfile) < 0)
        quit("cannot write icode file");

    if (Dflag) {
        int k = 0;
        struct ipc_line *ptr;
        for (ptr = lntable; ptr < lnfree; ptr++) {
            fprintf(dbgfile, "%ld:\t%03d\tl:%03d\n", (long)(pc + k),
                    ptr->ipc, 
                    ptr->line);
            k = k + 8;
        }
        putc('\n', dbgfile);
    }


    pc += (char *)lnfree - (char *)lntable;

    if (Dflag)
        fprintf(dbgfile, "\n# string constants table\n");

    hdr.Strcons = pc;
    for (sp = first_strconst; sp; sp = sp->next) {
        if (Dflag) {
            char *s = sp->s, t[9];
            int i, j = 0;
            for (i = 0; i < sp->len + 1; ++i) {
                if (i == 0)
                    fprintf(dbgfile, "%ld:(+%d)\t", (long)pc, sp->offset);
                else if (i % 8 == 0) {
                    t[j] = 0;
                    fprintf(dbgfile, "   %s\n%ld:\t\t", t, (long)pc + i);
                    j = 0;
                }
                fprintf(dbgfile, " %02x", s[i]);
                t[j++] = isprint(s[i]) ? s[i] : ' ';
            }
            t[j] = 0;
            while (i % 8 != 0) {
                fprintf(dbgfile, "   ");
                ++i;
            }
            fprintf(dbgfile, "   %s\n", t);
        }
        if (longwrite(sp->s, sp->len + 1, outfile) < 0)
            quit("cannot write icode file");
        pc += sp->len + 1;
    }

    /*
     * Output icode file header.
     */
    hdr.hsize = pc;
    strcpy((char *)hdr.config,IVersion);
    hdr.trace = trace;


    if (Dflag) {
        fprintf(dbgfile, "\n");
        fprintf(dbgfile, "hsize:            %ld\n", (long)hdr.hsize);
        fprintf(dbgfile, "trace:            %ld\n", (long)hdr.trace);
        fprintf(dbgfile, "class statics:    %ld\n", (long)hdr.ClassStatics);
        fprintf(dbgfile, "class fields:     %ld\n", (long)hdr.ClassFields);
        fprintf(dbgfile, "classes:          %ld\n", (long)hdr.Classes);
        fprintf(dbgfile, "records:          %ld\n", (long)hdr.Records);
        fprintf(dbgfile, "fnames:           %ld\n", (long)hdr.Fnames);
        fprintf(dbgfile, "globals:          %ld\n", (long)hdr.Globals);
        fprintf(dbgfile, "gnames:           %ld\n", (long)hdr.Gnames);
        fprintf(dbgfile, "statics:          %ld\n", (long)hdr.Statics);
        fprintf(dbgfile, "filenms:          %ld\n", (long)hdr.Filenms);
        fprintf(dbgfile, "linenums:         %ld\n", (long)hdr.linenums);
        fprintf(dbgfile, "strcons:          %ld\n", (long)hdr.Strcons);
        fprintf(dbgfile, "config:           %s\n", (char*)hdr.config);
    }

    fseek(outfile, hdrsize, 0);

    if (longwrite((char *)&hdr, (long)sizeof(hdr), outfile) < 0)
        quit("cannot write icode file");

    if (verbose > 1) {
        word tsize = sizeof(hdr) + hdr.hsize;
        report("  Bootstrap       %7ld", hdrsize);
        tsize += hdrsize;
        report("  Header          %7ld", (long)sizeof(hdr));
        report("  Procedures      %7ld", (long)hdr.ClassStatics);
        report("  Class statics   %7ld", (long)(hdr.ClassFields - hdr.ClassStatics));
        report("  Class fields    %7ld", (long)(hdr.Classes - hdr.ClassFields));
        report("  Classes         %7ld", (long)(hdr.Records - hdr.Classes));
        report("  Records         %7ld", (long)(hdr.Fnames - hdr.Records));
        report("  Field names     %7ld", (long)(hdr.Globals - hdr.Fnames));
        report("  Globals         %7ld", (long)(hdr.Gnames  - hdr.Globals));
        report("  Global names    %7ld", (long)(hdr.Statics - hdr.Gnames));
        report("  Statics         %7ld", (long)(hdr.Filenms - hdr.Statics));
        report("  Linenums        %7ld", (long)(hdr.Strcons - hdr.Filenms));
        report("  Strings         %7ld", (long)(hdr.hsize - hdr.Strcons));
        report("  Total           %7ld", (long)tsize);
    }
}

/*
 * align() outputs zeroes as padding until pc is a multiple of WordSize.
 */
static void align()
{
    static word x = 0;

    if (pc % WordSize != 0)
        outblock((char *)&x, (int)(WordSize - (pc % WordSize)));
}

/*
 * How many bytes would align() output, with the given location
 */
static int nalign(int n)
{
    if (n % WordSize != 0)
        return WordSize - (n % WordSize);
    else
        return 0;
}

/*
 * misalign() outputs a Noop instruction for padding if pc + sizeof(int)
 *  is not a multiple of WordSize.  This is for operations that output
 *  an int opcode followed by an operand that needs to be word-aligned.
 */
static void misalign()
{
    if ((pc + IntBits/ByteBits) % WordSize != 0)
        lemit(Op_Noop, "noop [pad]");
}

/*
 * intout(i) outputs i as an int that is used by the runtime system
 *  IntBits/ByteBits bytes must be moved from &word[0] to &codep[0].
 */
static void intout(oint)
    int oint;
{
    int i;
    union {
        int i;
        char c[IntBits/ByteBits];
    } u;

    CodeCheck(IntBits/ByteBits);
    u.i = oint;

    for (i = 0; i < IntBits/ByteBits; i++)
        codep[i] = u.c[i];

    codep += IntBits/ByteBits;
    pc += IntBits/ByteBits;
}

/*
 * wordout(i) outputs i as a word that is used by the runtime system
 *  WordSize bytes must be moved from &oword[0] to &codep[0].
 */
static void wordout(oword)
    word oword;
{
    int i;
    union {
        word i;
        char c[WordSize];
    } u;

    CodeCheck(WordSize);
    u.i = oword;

    for (i = 0; i < WordSize; i++)
        codep[i] = u.c[i];

    codep += WordSize;
    pc += WordSize;
}

static void shortout(short s)
{
    int i;
    union {
        short i;
        char c[ShortSize];
    } u;

    CodeCheck(ShortSize);
    u.i = s;

    for (i = 0; i < ShortSize; i++)
        codep[i] = u.c[i];

    codep += ShortSize;
    pc += ShortSize;
}


/*
 * outblock(a,i) output i bytes starting at address a.
 */
static void outblock(addr,count)
    char *addr;
    int count;
{
    CodeCheck(count);
    pc += count;
    while (count--)
        *codep++ = *addr++;
}

/*
 * dumpblock(a,i) dump contents of i bytes at address a, used only
 *  in conjunction with -L.
 */
static void dumpblock(addr, count)
    char *addr;
    int count;
{
    int i;
    for (i = 0; i < count; i++) {
        if ((i & 7) == 0)
            fprintf(dbgfile,"\n\t");
        fprintf(dbgfile," %03o",(0377 & (unsigned)addr[i]));
    }
    putc('\n',dbgfile);
}

/*
 * flushcode - write buffered code to the output file.
 */
static void flushcode()
{
    if (codep > codeb)
        if (longwrite(codeb, DiffPtrs(codep,codeb), outfile) < 0)
            quit("cannot write icode file");
    codep = codeb;
}

/*
 * clearlab - clear label table to all zeroes.
 */
static void clearlab()
{
    int i;

    for (i = 0; i < maxlabels; i++)
        labels[i] = 0;
}

/*
 * backpatch - fill in all forward references to lab.
 */
static void backpatch(lab)
    int lab;
{
    word p, r;
    char *q;
    char *cp, *cr;
    int j;

    if (lab >= maxlabels)
        labels  = (word *) expand_table(labels, NULL, &maxlabels, sizeof(word),
                                    lab - maxlabels + 1, "labels");

    p = labels[lab];
    if (p > 0)
        quit("multiply defined label in ucode");
    while (p < 0) {		/* follow reference chain */

        r = pc - (WordSize - p);	/* compute relative offset */
        q = codep - (pc + p);	/* point to word with address */
        cp = (char *) &p;		/* address of integer p       */
        cr = (char *) &r;		/* address of integer r       */
        for (j = 0; j < WordSize; j++) {	  /* move bytes from word pointed to */
            *cp++ = *q;			  /* by q to p, and move bytes from */
            *q++ = *cr++;			  /* r to word pointed to by q */
        }			/* moves integers at arbitrary addresses */
    }
    labels[lab] = pc;
}

void idump(s)		/* dump code region */
    char *s;
{
    int *c;

    fprintf(stderr,"\ndump of code region %s:\n",s);
    for (c = (int *)codeb; c < (int *)codep; c++)
        fprintf(stderr,"%ld: %d\n",(long)c, (int)*c);
    fflush(stderr);
}

