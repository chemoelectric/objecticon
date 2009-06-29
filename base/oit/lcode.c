/*
 * lcode.c -- linker routines to parse .u1 files and produce icode.
 */

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

#include "../h/opdefs.h"
#include "../h/header.h"
#include "../h/rmacros.h"

static int nstatics = 0;               /* Running count of static variables */

/*
 * Array sizes for various linker tables that can be expanded with realloc().
 */
static size_t maxcode	= 15000;        /* code space */
static size_t maxlabels	= 500;	        /* maximum num of labels/proc */
static size_t nsize       = 1000;         /* ipc/line num. assoc. table */
static size_t fnmsize     = 10;           /* ipc/file name assoc. table */

static struct ipc_fname *fnmtbl;	/* table associating ipc with file name */
static struct ipc_line *lntable;	/* table associating ipc with line number */
static struct ipc_fname *fnmfree;	/* free pointer for ipc/file name table */
static struct ipc_line *lnfree;	/* free pointer for ipc/line number table */
static word *labels;			/* label table */
static char *codeb;			/* generated code space */
static char *codep;			/* free pointer for code space */

static char *curr_file,         /* Current file name from an Op_Filen */
            *last_fnmtbl_filen; /* Last file name entered into fnmtbl above */
static int curr_line;           /* Current line from an Op_Line */

static struct lfunction *curr_lfunc = 0;

/*
 * Prototypes.
 */

static int      nalign(int n);
static void	align		(void);
static void	labout	(int lab);
static void	cleartables	(void);
static void	flushcode	(void);
static void	lemit		(int op);
static void     lemitcon(struct centry *ce);
static void	lemitin		(int op,word offset,int n);
static void	lemitl		(int op,int lab);
static void	lemitn		(int op,word n);
static void     lemitn2         (int op, word n1, word n2);
static void	lemitproc       (struct lfunction *func);
static void	lemitr		(int op,word loc);
static void	outblock	(char *addr,int count);
static void	wordout		(word oword);
static void	shortout	(short o);

static word pc = 0;		/* simulated program counter */

#define outword(n)	wordout((word)(n))
#define outchar(n)	charout((unsigned char)(n))
#define outshort(n)	shortout((short)(n))
#define CodeCheck(n) if ((long)codep + (n) > (long)((long)codeb + maxcode)) \
codeb = (char *) expand_table(codeb, &codep, &maxcode, 1,                   \
                          (n), "code buffer");


static void writescript();
static void binop(int n);
static int  alclab(int n);
static void gentables(void);
static void synch_file();
static void synch_line();
static void *expand_table(void * table,      /* table to be realloc()ed */
                          void * tblfree,    /* reference to table free pointer if there is one */
                          size_t *size, /* size of table */
                          int unit_size,      /* number of bytes in a unit of the table */
                          int min_units,      /* the minimum number of units that must be allocated. */
                          char *tbl_name);     /* name of the table */
static void unop(int op);

#define INVALID "invalid"
static char *op_names[] = {
    /*   0 */         INVALID,                                    
    /*   1 */         "asgn",
    /*   2 */         "bang",
    /*   3 */         "cat",
    /*   4 */         "compl",
    /*   5 */         "diff",
    /*   6 */         "div",
    /*   7 */         "eqv",
    /*   8 */         "inter",
    /*   9 */         "lconcat",
    /*  10 */         "lexeq",
    /*  11 */         "lexge",
    /*  12 */         "lexgt",
    /*  13 */         "lexle",
    /*  14 */         "lexlt",
    /*  15 */         "lexne",
    /*  16 */         "minus",
    /*  17 */         "mod",
    /*  18 */         "mult",
    /*  19 */         "neg",
    /*  20 */         "neqv",
    /*  21 */         "nonnull",
    /*  22 */         "null",
    /*  23 */         "number",
    /*  24 */         "numeq",
    /*  25 */         "numge",
    /*  26 */         "numgt",
    /*  27 */         "numle",
    /*  28 */         "numlt",
    /*  29 */         "numne",
    /*  30 */         "plus",
    /*  31 */         "power",
    /*  32 */         "random",
    /*  33 */         "rasgn",
    /*  34 */         "refresh",
    /*  35 */         "rswap",
    /*  36 */         "sect",
    /*  37 */         "size",
    /*  38 */         "subsc",
    /*  39 */         "swap",
    /*  40 */         "tabmat",
    /*  41 */         "toby",
    /*  42 */         "unions",
    /*  43 */         "value",
    /*  44 */         "bscan",
    /*  45 */         "ccase",
    /*  46 */         "chfail",
    /*  47 */         "coact",
    /*  48 */         "cofail",
    /*  49 */         "coret",
    /*  50 */         "create",
    /*  51 */         "cset",
    /*  52 */         "dup",
    /*  53 */         "efail",
    /*  54 */         "eret",
    /*  55 */         "escan",
    /*  56 */         "esusp",
    /*  57 */         "field",
    /*  58 */         "goto",
    /*  59 */         "init",
    /*  60 */         "int",
    /*  61 */         "invoke",
    /*  62 */         "keywd",
    /*  63 */         "limit",
    /*  64 */         INVALID,
    /*  65 */         "llist",
    /*  66 */         "lsusp",
    /*  67 */         "mark",
    /*  68 */         "pfail",
    /*  69 */         "pnull",
    /*  70 */         "pop",
    /*  71 */         "pret",
    /*  72 */         "psusp",
    /*  73 */         "push1",
    /*  74 */         "pushn1",
    /*  75 */         "real",
    /*  76 */         "sdup",
    /*  77 */         "str",
    /*  78 */         "unmark",
    /*  79 */         "ucs",
    /*  80 */         INVALID,
    /*  81 */         "arg",
    /*  82 */         "static",
    /*  83 */         "local",
    /*  84 */         "global",
    /*  85 */         "mark0",
    /*  86 */         "quit",
    /*  87 */         "fquit",
    /*  88 */         INVALID,
    /*  89 */         "apply",
    /*  90 */         "invokef",
    /*  91 */         "applyf",
    /*  92 */         INVALID,                                    
    /*  93 */         INVALID,                                    
    /*  94 */         INVALID,                                    
    /*  95 */         INVALID,                                    
    /*  96 */         INVALID,                                    
    /*  97 */         INVALID,                                    
    /*  98 */         "noop",
};

/*
 * Code generator parameters.
 */

#define LoopDepth   20		/* max. depth of nested loops */
#define CreatDepth  10		/* max. depth of nested create statements */

enum looptype { EVERY,LOOP };

/*
 * loopstk structures hold information about nested loops.
 */
struct loopstk {
    int nextlab;			/* label for next exit */
    int breaklab;		/* label for break exit */
    int markcount;		/* number of marks */
    int ltype;			/* loop type */
};

/*
 * creatstk structures hold information about create statements.
 */
struct creatstk {
    int nextlab;			/* previous value of nextlab */
    int breaklab;		/* previous value of breaklab */
};

static int nextlab;		/* next label allocated by alclab() */
static struct loopstk loopstk[LoopDepth];	/* loop stack */
static struct loopstk *loopsp;
static struct creatstk creatstk[CreatDepth]; /* create stack */
static struct creatstk *creatsp;

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

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
    word ipc;             /* offset of instruction into code region */
    struct strconst *sc;  /* installed string */
};

struct ipc_line {
    word ipc;           /* offset of instruction into code region */
    int line;           /* line number */
};

static struct unref *first_unref, *unref_hash[128];
static struct strconst *first_strconst, *last_strconst, *strconst_hash[128];
static int strconst_offset;
static struct centry *constblock_hash[128];

static struct header hdr;

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
        strconst_offset += p->len;
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

static void treecode(struct lnode *n);
static void gencode_func(struct lfunction *f);
static void gencode();

void generate_code()
{
    int i;

    /*
     * Open the output file.
     */
    outfile = fopen(ofile, WriteBinary);
    if (outfile == NULL)
        quitf("cannot create %s",ofile);

    /*
     * Write the bootstrap header to the output file.
     */
    writescript();

    /*
     * Space for the header
     */
    for (i = sizeof(struct header); i--;)
        putc(0, outfile);
    fflush(outfile);
    if (ferror(outfile) != 0)
        quit("unable to write to icode file");

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
     * This ensures empty strings point to the start of the string region,
     * which is a bit tidier than pointing to some arbitrary offset.
     */
    inst_c_strconst(empty_string);

    gencode();

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

    /*
     * Close the .ux file if debugging is on.
     */
    if (Dflag) {
        fclose(dbgfile);
    }

    fclose(outfile);
}


static void treecode(struct lnode *n)
{
    int op;

    curr_file = n->loc.file;
    curr_line = n->loc.line;
    synch_file();
    synch_line();
    op = n->op;

    switch (op) {
        case Uop_Empty:
            lemit(Op_Pnull);
            break;

        case Uop_End:
            lemit(Op_Pfail);
            break;

        case Uop_Slist: {
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            for (i = 0; i < x->n - 1; ++i) {
                int lab = alclab(1);
                lemitl(Op_Mark,lab);
                loopsp->markcount++;
                treecode(x->child[i]);
                loopsp->markcount--;
                lemit(Op_Unmark);
                labout(lab);
            }
            if (x->n > 0)
                treecode(x->child[x->n - 1]);
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
        case Uop_Unions: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            binop(op);
            break;
        }

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
        case Uop_Augunions: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            lemit(Op_Dup);
            treecode(x->child2);
            binop(op);
            lemit(Op_Asgn);
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
        case Uop_Null: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            lemit(Op_Pnull);
            treecode(x->child);
            unop(op);
            break;
        }

        case Uop_Alt: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int lab = alclab(2);
            lemitl(Op_Mark,lab);
            loopsp->markcount++;
            treecode(x->child1);         /* evaluate first alternative */
            loopsp->markcount--;
            lemit(Op_Esusp);                 /*  and suspend with its result */
            lemitl(Op_Goto,lab+1);
            labout(lab);
            treecode(x->child2);         /* evaluate second alternative */
            labout(lab+1);
            break;
        }

        case Uop_Conj: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            treecode(x->child1);
            lemit(Op_Pop);
            treecode(x->child2);
            break;
        }

        case Uop_Augconj: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            lemit(Op_Asgn);
            break;
        }

        case Uop_If: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Mark0);
            loopsp->markcount++;
            treecode(x->child1);
            loopsp->markcount--;
            lemit(Op_Unmark);
            treecode(x->child2);
            break;
        }

        case Uop_Ifelse: {
            struct lnode_3 *x = (struct lnode_3 *)n;
            int lab = alclab(2);
            lemitl(Op_Mark, lab);
            loopsp->markcount++;
            treecode(x->child1);
            loopsp->markcount--;
            lemit(Op_Unmark);
            treecode(x->child2);
            lemitl(Op_Goto, lab+1);
            labout(lab);
            treecode(x->child3);
            labout(lab+1);
            break;
        }

        case Uop_Repeat: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(3);
            loopsp++;
            loopsp->ltype = LOOP;
            loopsp->nextlab = lab + 1;
            loopsp->breaklab = lab + 2;
            loopsp->markcount = 1;
            labout(lab);
            lemitl(Op_Mark, lab);
            treecode(x->child);
            labout(loopsp->nextlab);
            lemit(Op_Unmark);
            lemitl(Op_Goto, lab);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_While: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(3);
            loopsp++;
            loopsp->ltype = LOOP;
            loopsp->nextlab = lab + 1;
            loopsp->breaklab = lab + 2;
            loopsp->markcount = 1;
            labout(lab);
            lemit(Op_Mark0);
            treecode(x->child);
            labout(loopsp->nextlab);
            lemit(Op_Unmark);
            lemitl(Op_Goto, lab);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Whiledo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int lab = alclab(3);
            loopsp++;
            loopsp->ltype = LOOP;
            loopsp->nextlab = lab + 1;
            loopsp->breaklab = lab + 2;
            loopsp->markcount = 1;
            labout(lab);
            lemit(Op_Mark0);
            treecode(x->child1);
            lemit(Op_Unmark);
            lemitl(Op_Mark, lab);
            treecode(x->child2);
            labout(loopsp->nextlab);
            lemit(Op_Unmark);
            lemitl(Op_Goto, lab);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Until: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(4);
            loopsp++;
            loopsp->ltype = LOOP;
            loopsp->nextlab = lab + 2;
            loopsp->breaklab = lab + 3;
            loopsp->markcount = 1;
            labout(lab);
            lemitl(Op_Mark, lab+1);
            treecode(x->child);
            lemit(Op_Unmark);
            lemit(Op_Efail);
            labout(lab+1);
            lemitl(Op_Mark, lab);
            lemit(Op_Pnull);
            labout(loopsp->nextlab);
            lemit(Op_Unmark);
            lemitl(Op_Goto, lab);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Untildo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int lab = alclab(4);
            loopsp++;
            loopsp->ltype = LOOP;
            loopsp->nextlab = lab + 2;
            loopsp->breaklab = lab + 3;
            loopsp->markcount = 1;
            labout(lab);
            lemitl(Op_Mark, lab+1);
            treecode(x->child1);
            lemit(Op_Unmark);
            lemit(Op_Efail);
            labout(lab+1);
            lemitl(Op_Mark, lab);
            treecode(x->child2);
            labout(loopsp->nextlab);
            lemit(Op_Unmark);
            lemitl(Op_Goto, lab);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Every: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(2);
            loopsp++;
            loopsp->ltype = EVERY;
            loopsp->nextlab = lab;
            loopsp->breaklab = lab + 1;
            loopsp->markcount = 1;
            lemit(Op_Mark0);
            treecode(x->child);
            lemit(Op_Pop);
            labout(loopsp->nextlab);
            lemit(Op_Efail);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Everydo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int lab = alclab(2);
            loopsp++;
            loopsp->ltype = EVERY;
            loopsp->nextlab = lab;
            loopsp->breaklab = lab + 1;
            loopsp->markcount = 1;
            lemit(Op_Mark0);
            treecode(x->child1);
            lemit(Op_Pop);
            lemit(Op_Mark0);
            loopsp->ltype = LOOP;
            loopsp->markcount++;
            treecode(x->child2);
            loopsp->markcount--;
            lemit(Op_Unmark);
            labout(loopsp->nextlab);
            lemit(Op_Efail);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Suspend: {
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(2);
            loopsp++;
            loopsp->ltype = EVERY;		/* like every ... do for next */
            loopsp->nextlab = lab;
            loopsp->breaklab = lab + 1;
            loopsp->markcount = 1;
            lemit(Op_Mark0);
            treecode(x->child);
            lemit(Op_Psusp);
            lemit(Op_Pop);
            labout(loopsp->nextlab);
            lemit(Op_Efail);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Suspenddo: {
            struct lnode_2 *x = (struct lnode_2 *)n;
            int lab = alclab(2);
            loopsp++;
            loopsp->ltype = EVERY;		/* like every ... do for next */
            loopsp->nextlab = lab;
            loopsp->breaklab = lab + 1;
            loopsp->markcount = 1;
            lemit(Op_Mark0);
            treecode(x->child1);
            lemit(Op_Psusp);
            lemit(Op_Pop);
            lemit(Op_Mark0);
            loopsp->ltype = LOOP;
            loopsp->markcount++;
            treecode(x->child2);
            loopsp->markcount--;
            lemit(Op_Unmark);
            labout(loopsp->nextlab);
            lemit(Op_Efail);
            labout(loopsp->breaklab);
            loopsp--;
            break;
        }

        case Uop_Return: {			/* return expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            if (x->child->op == Uop_Empty) {
                lemit(Op_Pnull);
                lemit(Op_Pret);
            } else {
                int lab = alclab(1);
                lemitl(Op_Mark, lab);
                loopsp->markcount++;
                treecode(x->child);
                loopsp->markcount--;
                lemit(Op_Pret);
                labout(lab);
                lemit(Op_Pfail);
            }
            break;
        }

        case Uop_Break: {			/* break expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            int i;
            struct loopstk loopsave;
            if (loopsp->breaklab <= 0)
                quit("invalid context for break");
            for (i = 0; i < loopsp->markcount; i++)
                lemit(Op_Unmark);
            loopsave = *loopsp--;
            treecode(x->child);
            *++loopsp = loopsave;
            lemitl(Op_Goto, loopsp->breaklab);
            break;
        }

        case Uop_Next: {			/* next expression */
            int i;
            if (loopsp->nextlab <= 0)
                quit("invalid context for next");
            if (loopsp->ltype != EVERY && loopsp->markcount > 1)
                for (i = 0; i < loopsp->markcount - 1; i++)
                    lemit(Op_Unmark);
            lemitl(Op_Goto, loopsp->nextlab);
            break;
        }

        case Uop_Field: {			/* field reference */
            struct lnode_field *x = (struct lnode_field *)n;
            struct fentry *fp;
            lemit(Op_Pnull);
            treecode(x->child);
            fp = flocate(x->fname);
            if (fp)
                lemitn(Op_Field, (word)(fp->field_id));
            else {
                /* Get or create an unref record */
                struct unref *p = get_unref(x->fname);
                lemitn(Op_Field, (word) p->num);
            }
            if (Dflag) {
                fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
            }
            outword(0);
            outword(0);
            break;
        }

        case Uop_Invoke: {                      /* e(x1, x2.., xn) */
            struct lnode_invoke *x = (struct lnode_invoke *)n;
            int i;
            if (x->expr->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->expr;
                struct fentry *fp;
                treecode(y->child);
                for (i = 0; i < x->n; ++i)
                    treecode(x->child[i]);
                fp = flocate(y->fname);
                if (fp)
                    lemitn2(Op_Invokef, (word)fp->field_id, x->n);
                else {
                    /* Get or create an unref record */
                    struct unref *p = get_unref(y->fname);
                    lemitn2(Op_Invokef, (word)p->num, x->n);
                }
                if (Dflag) {
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                }
                outword(0);
                outword(0);
            } else {
                treecode(x->expr);
                for (i = 0; i < x->n; ++i)
                    treecode(x->child[i]);
                lemitn(Op_Invoke, x->n);
            }
            break;
        }

        case Uop_Mutual: {                      /* (e1,...,en) */
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            lemit(Op_Pushn1);             
            for (i = 0; i < x->n; ++i)
                treecode(x->child[i]);
            lemitn(Op_Invoke, x->n);
            break;
        }

        case Uop_Apply: {			/* application e!l */
            struct lnode_apply *x = (struct lnode_apply *)n;
            /* Check for possible Applyf */
            if (x->expr->op == Uop_Field) {
                struct lnode_field *y = (struct lnode_field *)x->expr;
                struct fentry *fp;
                treecode(y->child);
                treecode(x->args);
                fp = flocate(y->fname);
                if (fp)
                    lemitn(Op_Applyf, (word)fp->field_id);
                else {
                    /* Get or create an unref record */
                    struct unref *p = get_unref(y->fname);
                    lemitn(Op_Applyf, (word)p->num);
                }
                if (Dflag) {
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                    fprintf(dbgfile, "\t0\t\t\t\t# Inline cache\n");
                }
                outword(0);
                outword(0);
            } else {
                treecode(x->expr);
                treecode(x->args);
                lemit(Op_Apply);
            }
            break;
        }

        case Uop_Fail: {			/* fail expression */
            lemit(Op_Pfail);
            break;
        }

        case Uop_Create: {			/* create expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(3);
            creatsp++;
            creatsp->nextlab = loopsp->nextlab;
            creatsp->breaklab = loopsp->breaklab;
            loopsp->nextlab = 0;		/* make break and next illegal */
            loopsp->breaklab = 0;
            lemitl(Op_Goto, lab+2);          /* skip over code for co-expression */
            labout(lab);			/* entry point */
            lemit(Op_Pop);                   /* pop the result from activation */
            lemitl(Op_Mark, lab+1);
            loopsp->markcount++;
            treecode(x->child);		/* traverse code for co-expression */
            loopsp->markcount--;
            lemit(Op_Coret);                 /* return to activator */
            lemit(Op_Efail);                 /* drive co-expression */
            labout(lab+1);		/* loop on exhaustion */
            lemit(Op_Cofail);                /* and fail each time */
            lemitl(Op_Goto, lab+1);
            labout(lab+2);
            lemitl(Op_Create, lab);          /* create entry block */
            loopsp->nextlab = creatsp->nextlab;   /* legalize break and next */
            loopsp->breaklab = creatsp->breaklab;
            creatsp--;
            break;
        }

        case Uop_Activate: {			/* co-expression activation */
            struct lnode_1 *x = (struct lnode_1 *)n;
            lemit(Op_Pnull);
            treecode(x->child);		/* evaluate activate expression */
            lemit(Op_Coact);
            break;
        }

        case Uop_Bactivate: {			/* co-expression activation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            treecode(x->child1);		         /* evaluate result expression */
            treecode(x->child2);       	        /* evaluate activate expression */
            lemit(Op_Coact);
            break;
        }

        case Uop_Augactivate: {			/* co-expression activation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);		         /* evaluate result expression */
            lemit(Op_Sdup);
            treecode(x->child2);       	        /* evaluate activate expression */
            lemit(Op_Coact);
            lemit(Op_Asgn);
            break;
        }

        case Uop_Rptalt: {			/* repeated alternation */
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(1);
            labout(lab);
            lemit(Op_Mark0);         /* fail if expr fails first time */
            loopsp->markcount++;
            treecode(x->child);		/* evaluate first alternative */
            loopsp->markcount--;
            lemitl(Op_Chfail, lab);   /* change to loop on failure */
            lemit(Op_Esusp);                 /* suspend result */
            break;
        }

        case Uop_Not: {			/* not expression */
            struct lnode_1 *x = (struct lnode_1 *)n;
            int lab = alclab(1);
            lemitl(Op_Mark, lab);
            loopsp->markcount++;
            treecode(x->child);
            loopsp->markcount--;
            lemit(Op_Unmark);
            lemit(Op_Efail);
            labout(lab);
            lemit(Op_Pnull);
            break;
        }

        case Uop_Scan: {			/* scanning expression */
            struct lnode_2 *x = (struct lnode_2 *)n;
            treecode(x->child1);
            lemit(Op_Bscan);
            treecode(x->child2);
            lemit(Op_Escan);
            break;
        }

        case Uop_Augscan: {			/* scanning expression */
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            lemit(Op_Sdup);
            lemit(Op_Bscan);
            treecode(x->child2);
            lemit(Op_Escan);
            lemit(Op_Asgn);
            break;
        }

        case Uop_Sect: {        	/* section operation x[a:b] */
            struct lnode_3 *x = (struct lnode_3 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            treecode(x->child3);
            lemit(Op_Sect);
            break;
        }

        case Uop_Sectp: {               /* section operation x[a+:b] */
            struct lnode_3 *x = (struct lnode_3 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            lemit(Op_Dup);
            treecode(x->child3);
            lemit(Op_Plus);
            lemit(Op_Sect);
            break;
        }

        case Uop_Sectm: {              /* section operation x[a-:b] */
            struct lnode_3 *x = (struct lnode_3 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            lemit(Op_Dup);
            treecode(x->child3);
            lemit(Op_Minus);
            lemit(Op_Sect);
            break;
        }

        case Uop_To: {			/* to expression */
            struct lnode_2 *x = (struct lnode_2 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            lemit(Op_Push1);
            lemit(Op_Toby);
            break;
        }

        case Uop_Toby: {			/* to-by expression */
            struct lnode_3 *x = (struct lnode_3 *)n;
            lemit(Op_Pnull);
            treecode(x->child1);
            treecode(x->child2);
            treecode(x->child3);
            lemit(Op_Toby);
            break;
        }

        case Uop_Keyword: {			/* keyword reference */
            struct lnode_keyword *x = (struct lnode_keyword *)n;
            switch (x->num) {
                case 0:
                    quitf("invalid keyword");	
                    break;
                case K_FAIL:
                    lemit(Op_Efail);
                    break;
                case K_NULL:
                    lemit(Op_Pnull);
                    break;
                default:
                    lemitn(Op_Keywd, (word)x->num);
            }
            break;
        }

        case Uop_Limit: {			/* limitation */
            struct lnode_2 *x = (struct lnode_2 *)n;
            treecode(x->child1);
            lemit(Op_Limit);
            loopsp->markcount++;
            treecode(x->child2);
            loopsp->markcount--;
            lemit(Op_Lsusp);
            break;
        }

        case Uop_List: {			/* list construction */
            struct lnode_n *x = (struct lnode_n *)n;
            int i;
            lemit(Op_Pnull);
            for (i = 0; i < x->n; ++i)
                treecode(x->child[i]);
            lemitn(Op_Llist, (word)x->n);
            break;
        }

        case Uop_Case:			/* case expression */
        case Uop_Casedef: {
            struct lnode_case *x = (struct lnode_case *)n;
            int i, lab = alclab(1);
            lemit(Op_Mark0);
            loopsp->markcount++;
            treecode(x->expr);		         /* evaluate control expression */
            loopsp->markcount--;
            lemit(Op_Eret);
            for (i = 0; i < x->n; ++i) {                /* The n non-default cases */
                int clab = alclab(1);
                lemitl(Op_Mark, clab);
                loopsp->markcount++;
                lemit(Op_Ccase);
                treecode(x->selector[i]);		/* evaluate selector */
                lemit(Op_Eqv);
                loopsp->markcount--;
                lemit(Op_Unmark);
                lemit(Op_Pop);
                treecode(x->clause[i]);		/* evaluate expression */
                lemitl(Op_Goto, lab);   /* goto end label */
                labout(clab);		/* label for next clause */
            }
            if (op == Uop_Casedef) {       /* evaluate default clause */
                lemit(Op_Pop);
                treecode(x->def);
	    } else
                lemit(Op_Efail);
            labout(lab);			/* end label */
            break;
        }

        case Uop_Const: {
            struct lnode_const *x = (struct lnode_const *)n;
            switch (x->con->c_flag) {
                case F_IntLit: {
                    word ival;
                    memcpy(&ival, x->con->data, sizeof(word));
                    lemitn(Op_Int, ival);
                    break;
                }
                case F_RealLit: {
                    lemitr(Op_Real, x->con->pc);
                    break;
                }
                case F_StrLit: {
                    struct strconst *sp = inst_strconst(x->con->data, x->con->length);
                    lemitin(Op_Str, sp->offset, sp->len);
                    break;
                }
                case F_CsetLit: {
                    lemitr(Op_Cset, x->con->pc);
                    break;
                }
                case F_UcsLit: {
                    lemitr(Op_Ucs, x->con->pc);
                    break;
                }
                case F_LrgintLit: {
                    struct strconst *sp = inst_strconst(x->con->data, x->con->length);
                    lemit(Op_Pnull);
                    lemitin(Op_Str, sp->offset, sp->len);
                    lemit(Op_Number);
                    break;
                }
                default: {
                    quitf("Unknown constant flag %d", x->con->c_flag);
                }
            }
            break;
        }

        case Uop_Global: {
            struct lnode_global *x = (struct lnode_global *)n;
            lemitn(Op_Global, (word)x->global->g_index);
            break;
        }

        case Uop_Local: {
            struct lnode_local *x = (struct lnode_local *)n;
            int flags = x->local->l_flag;
            if (flags & F_Static)
                lemitn(Op_Static, x->local->l_val.index);
            else if (flags & F_Argument)
                lemitn(Op_Arg, x->local->l_val.index);
            else
                lemitn(Op_Local, x->local->l_val.index);
            break;
        }

        default:
            quitf("treecode: illegal opcode(%d)", op);
    }
}

static void gencode_func(struct lfunction *f)
{
    struct centry *cp;

    /*
     * Initialize for procedure/method.
     */
    curr_lfunc = f;
    synch_file();
    synch_line();
    cleartables();
    align();
    if (Dflag) {
        if (curr_lfunc->method)
            fprintf(dbgfile, "\n# method %s.%s\n", curr_lfunc->method->class->global->name, curr_lfunc->method->name);
        else
            fprintf(dbgfile, "\n# procedure %s\n", curr_lfunc->proc->name);
    }
    for (cp = curr_lfunc->constants; cp; cp = cp->next) 
        lemitcon(cp);

    curr_lfunc->pc = pc;
    lemitproc(curr_lfunc);
    if (curr_lfunc->initial->op != Uop_Empty) {
        int lab = alclab(1);
        lemitl(Op_Init, lab);
        lemitl(Op_Mark, lab);
        treecode(curr_lfunc->initial);
        lemit(Op_Unmark);
        labout(lab);
    }
    if (curr_lfunc->body->op != Uop_Empty) {
        int lab = alclab(1);
        lemitl(Op_Mark, lab);
        treecode(curr_lfunc->body);
        lemit(Op_Unmark);
        labout(lab);
    }
    treecode(curr_lfunc->end);   /* Get the Uop_End */
    flushcode();
}

static void gencode()
{
    struct gentry *gl;
    for (gl = lgfirst; gl; gl = gl->g_next) {
        if (gl->func)
            gencode_func(gl->func);
        else if (gl->class) {
            struct lclass_field *me;
            for (me = gl->class->fields; me; me = me->next) {
                if (me->func && !(me->flag & M_Defer)) 
                    gencode_func(me->func);
            }
        }
    }
}


static void synch_file()
{
    if (loclevel == 0)
        return;

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
    fnmfree->sc = inst_c_strconst(curr_file);
    fnmfree++;
}

static void synch_line()
{
    if (loclevel == 0)
        return;

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
 *	for a description of the chaining and labouting for labels.
 *  lemitn - emit opcode with integer argument.
 *  lemitr - emit opcode with pc-relative reference.
 *  lemitin - emit opcode with reference to identifier table & integer argument.
 *  lemitcon - emit constant table entry.
 *  lemitproc - emit procedure block.
 *
 * The lemit* routines call out* routines to effect the "outputting" of icode.
 *  Note that the majority of the code for the lemit* routines is for debugging
 *  purposes.
 */

static void lemit(int op)
{

    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t\t\t\t# %s\n", (long)pc, op, op_names[op]);

    outword(op);
}

static void lemitl(int op, int lab)
{
    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\tL%d\t\t\t# %s\n", (long)pc, op, lab, op_names[op]);

    if (lab >= maxlabels)
        labels  = (word *) expand_table(labels, NULL, &maxlabels, sizeof(word),
                                    lab - maxlabels + 1, "labels");
    outword(op);
    if (labels[lab] <= 0) {		/* forward reference */
        outword(labels[lab]);
        labels[lab] = WordSize - pc;	/* add to front of reference chain */
    }
    else					/* output relative offset */

    outword(labels[lab] - (pc + WordSize));
}

static void lemitn(int op, word n)
{
    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t%ld\t\t\t# %s\n", (long)pc, op, (long)n, op_names[op]);

    outword(op);
    outword(n);
}

static void lemitn2(int op, word n1, word n2)
{
    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t%ld,%ld\t\t\t# %s\n", (long)pc, op, (long)n1, (long)n2,
                op_names[op]);

    outword(op);
    outword(n1);
    outword(n2);
}

static void lemitr(int op, word loc)
{
    loc -= pc + (2 * WordSize);
    if (Dflag) {
        if (loc >= 0)
            fprintf(dbgfile, "%ld:\t%d\t*+%ld\t\t\t# %s\n",(long) pc, op,
                    (long)loc, op_names[op]);
        else
            fprintf(dbgfile, "%ld:\t%d\t*-%ld\t\t\t# %s\n",(long) pc, op,
                    (long)-loc, op_names[op]);
    }

    outword(op);
    outword(loc);
}

static void lemitin(int op, word offset, int n)
{
    if (Dflag)
        fprintf(dbgfile, "%ld:\t%d\t%d,S+%ld\t\t\t# %s\n", (long)pc, op, n,
                (long)offset, op_names[op]);

    outword(op);
    outword(n);
    outword(offset);
}


static void lemitcon(struct centry *ce)
{
    int i;
    struct centry *p;

    /*
     * Integers and strings don't generate blocks.
     */
    if (ce->c_flag & (F_IntLit | F_LrgintLit | F_StrLit))
        return;

    /*
     * All other types (cset, ucs, real) generate immutable blocks, so
     * see if we've seen one with the same type and data before which
     * we can reuse.
     */

    i = hasher(ce->data, constblock_hash);
    p = constblock_hash[i];
    while (p && (p->data != ce->data || p->c_flag != ce->c_flag))
        p = p->b_next;
    if (p) {
        /*
         * Seen before, so just copy pc from previously output one.
         */
        ce->pc = p->pc;
        return;
    }
    /*
     * Add to hash chain and output
     */
    ce->b_next = constblock_hash[i];
    constblock_hash[i] = ce;
    ce->pc = pc;
    if (ce->c_flag & F_RealLit) {
        if (Dflag) {
            double d;
            memcpy(&d, ce->data, sizeof(double));
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Real (%g)\n",(long) pc, T_Real, d);
            for (i = 0; i < sizeof(double); ++i)
                fprintf(dbgfile, "\t%d\t\t\t\t#    double data\n", ce->data[i] & 0xff);
        }
        outword(T_Real);
        outblock(ce->data, sizeof(double));
    }
    else if (ce->c_flag & F_CsetLit) {
        int i, j, x;
        word csbuf[CsetSize];
        int npair = ce->length / sizeof(struct range);
        int size = 0;
        /* Need to alloc not cast because string data might not be aligned */
        struct range *pair = safe_alloc(ce->length);
        memcpy(pair, ce->data, ce->length);
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
            fprintf(dbgfile, "\t%lu\t\t\t\t# Block size\n", (unsigned long)((CsetSize + 4 + 3 * npair) * WordSize));
            fprintf(dbgfile, "\t%d\t\t\t\t# Cset size\n", size);
            for (i = 0; i < CsetSize; ++i)
                fprintf(dbgfile, "\t%08lx\t\t\t#    Binary map\n", (long)csbuf[i]);
            fprintf(dbgfile, "\t%d\t\t\t\t# Npair\n", npair);
            x = 0;
            for (i = 0; i < npair; ++i) {
                fprintf(dbgfile, "\t%d\t\t\t\t#    Index\n", x);
                fprintf(dbgfile, "\t%ld\t\t\t\t#    From\n", (long)pair[i].from);
                fprintf(dbgfile, "\t%ld\t\t\t\t#    To\n", (long)pair[i].to);
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
    else if (ce->c_flag & F_UcsLit) {
        int index_step, n_offs, length, i;
        struct strconst *utf8;
        char *p, *e;

        /* Install the uft8 data */
        utf8 = inst_strconst(ce->data, ce->length);

        /* Calculate the length in unicode chars */
        p = utf8->s;
        e = p + utf8->len;
        length = 0;
        while (p < e) {
            p += UTF8_SEQ_LEN(*p);
            ++length;
        }

        if (length == 0)
            index_step = n_offs = 0;
        else {
            index_step = calc_ucs_index_step(length);
            n_offs = (length - 1) / index_step;
        }

        if (Dflag) {
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# -T_Ucs\n",(long) pc, -T_Ucs);
            fprintf(dbgfile, "\t%lu\t\t\t\t# Block size\n", (unsigned long)((7 + n_offs) * WordSize));
            fprintf(dbgfile, "\t%d\t\t\t\t# Length\n", length);
            fprintf(dbgfile, "\t%d\tS+%d\t\t\t# UTF8 data\n", utf8->len, utf8->offset);
            fprintf(dbgfile, "\t%d\t\t\t\t# N indexed\n", n_offs);
            fprintf(dbgfile, "\t%d\t\t\t\t# Index step\n", index_step);
        }
        outword(-T_Ucs);             /* -ve title indicates to Op_Ucs in interp.r to resolve offset */
        outword((7 + n_offs) * WordSize);
        outword(length);
        outword(utf8->len);          /* utf8: length & offset */
        outword(utf8->offset);       
        outword(n_offs);
        outword(index_step);

        /* This mirrors the loop in fmisc.r (get_ucs_off) */
        p = utf8->s;
        i = 0;
        while (i < length - 1) {
            p += UTF8_SEQ_LEN(*p);
            ++i;
            if (i % index_step == 0) {
                if (Dflag)
                    fprintf(dbgfile, "\t%ld\t\t\t\t#    Off of char %d\n", (long)(p - utf8->s), i);
                outword(p - utf8->s);
            }
        }
    } else
        quit("illegal constant");

}

static void lemitproc(struct lfunction *func)
{
    char *p;
    int size, ap;
    struct lentry *le;
    struct strconst *sp;

    /*
     * FncBlockSize = sizeof(BasicFncBlock) +
     *  sizeof(descrip)*(# of args + # of dynamics + # of statics).
     */
    if (abs(func->nargs) != func->narguments)
        quitf("Mismatch between ufile's nargs and narguments");

    size = (14*WordSize) + 2*WordSize * (func->narguments + func->ndynamic + func->nstatics);
    if (loclevel > 1)
        size += 3*WordSize * (func->narguments + func->ndynamic + func->nstatics);

    if (func->proc)
        p = func->proc->name;
    else
        p = func->method->name;

    sp = inst_c_strconst(p);

    if (Dflag) {
        fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Proc\n", (long)pc, T_Proc); /* type code */
        fprintf(dbgfile, "\t%d\t\t\t\t# Block size\n", size);			/* size of block */
        fprintf(dbgfile, "\tZ+%ld\t\t\t\t# Entry point\n",(long)(func->pc + size));	/* entry point */
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
    outword(func->pc + size);
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
     * Pointers to the tables that follow.
     */
    if (Dflag) {
        ap = pc + 2 * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to lnames array\n", ap);
        ap += (func->narguments + func->ndynamic + func->nstatics) * 2 * WordSize;
        if (loclevel > 1)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to llocs array\n", ap);
        else
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to llocs array\n", 0);
    }

    ap = pc + 2 * WordSize;
    outword(ap);
    ap += (func->narguments + func->ndynamic + func->nstatics) * 2 * WordSize;
    if (loclevel > 1) {
        outword(ap);
        ap += (func->narguments + func->ndynamic + func->nstatics) * 3 * WordSize;
    } else
        outword(0);

    /*
     * Names array.  Loop through the list of locals three times to get the output
     * in the correct order.
     */
    if (Dflag)
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Local names array\n", (long)pc);
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Argument) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Dynamic) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }
    for (le = func->locals; le; le = le->next) {
        if (le->l_flag & F_Static) {
            sp = inst_c_strconst(le->name);
            le->l_val.index = nstatics++;
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }

    if (loclevel > 1) {
        /*
         * Local locations
         */
        if (Dflag)
            fprintf(dbgfile, "%ld:\t\t\t\t\t# Local locations array\n", (long)pc);
        for (le = func->locals; le; le = le->next) {
            if (le->l_flag & F_Argument) {
                sp = inst_c_strconst(le->pos.file);
                if (Dflag) {
                    fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   File %s\n", sp->len, sp->offset, le->pos.file);
                    fprintf(dbgfile, "\t%d\t\t\t\t#   Line %d\n", le->pos.line, le->pos.line);
                }
                outword(sp->len);
                outword(sp->offset);
                outword(le->pos.line);
            }
        }
        for (le = func->locals; le; le = le->next) {
            if (le->l_flag & F_Dynamic) {
                sp = inst_c_strconst(le->pos.file);
                if (Dflag) {
                    fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   File %s\n", sp->len, sp->offset, le->pos.file);
                    fprintf(dbgfile, "\t%d\t\t\t\t#   Line %d\n", le->pos.line, le->pos.line);
                }
                outword(sp->len);
                outword(sp->offset);
                outword(le->pos.line);
            }
        }
        for (le = func->locals; le; le = le->next) {
            if (le->l_flag & F_Static) {
                sp = inst_c_strconst(le->pos.file);
                if (Dflag) {
                    fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   File %s\n", sp->len, sp->offset, le->pos.file);
                    fprintf(dbgfile, "\t%d\t\t\t\t#   Line %d\n", le->pos.line, le->pos.line);
                }
                outword(sp->len);
                outword(sp->offset);
                outword(le->pos.line);
            }
        }
    }

    /* Check our calculations were right */
    if (ap != pc)
        quitf("I got my sums wrong(d): %d != %d", ap, pc);

    if (func->pc + size != pc)
        quitf("I got my sums wrong(e): %d != %d", func->pc + size, pc);
}

struct field_sort_item {
    int n;
    struct fentry *fp;
};

static int field_sort_compare(struct field_sort_item *p1, struct field_sort_item *p2)
{
    return p1->fp->field_id - p2->fp->field_id;
}

static struct field_sort_item *sorted_fields(struct lclass *cl)
{
    struct lclass_field_ref *fr;
    int n = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;
    struct field_sort_item *a = safe_calloc(n, sizeof(struct field_sort_item));
    int i = 0;
    for (fr = cl->implemented_instance_fields; fr; fr = fr->next, ++i) {
        a[i].n = i;
        a[i].fp = fr->field->ftab_entry;
    }
    for (fr = cl->implemented_class_fields; fr; fr = fr->next, ++i) {
        a[i].n = i;
        a[i].fp = fr->field->ftab_entry;
    }
    qsort(a, n, sizeof(struct field_sort_item), (QSortFncCast)field_sort_compare);
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
    qsort(a, cl->nfields, sizeof(struct field_sort_item), (QSortFncCast)field_sort_compare);
    return a;
}

static int implemented_classes_sort_compare(struct lclass **p1, struct lclass **p2)
{
    return (*p1)->pc - (*p2)->pc;
}

static struct lclass **sorted_implemented_classes(struct lclass *cl)
{
    struct lclass_ref *cr;
    struct lclass **a = safe_calloc(cl->n_implemented_classes, sizeof(struct lclass *));
    int i = 0;
    for (cr = cl->implemented_classes; cr; cr = cr->next, ++i)
        a[i] = cr->class;
    qsort(a, cl->n_implemented_classes, sizeof(struct lclass *), 
          (QSortFncCast)implemented_classes_sort_compare);
    return a;
}

static void genclass(struct lclass *cl)
{
    struct lclass_ref *cr;
    struct lclass_field_ref *fr;
    struct field_sort_item *sortf;
    struct lclass **ic_sort;
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
        fprintf(dbgfile, "\t%d\t\t\t\t# Package id\n", cl->global->defined->package_id);
        fprintf(dbgfile, "\t0\t\t\t\t# Instance ids counter\n");
        fprintf(dbgfile, "\t%d\t\t\t\t# Initialization state\n", Uninitialized);
        fprintf(dbgfile, "\t%08lo\t\t\t# Flags\n", (long)cl->flag);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nsupers\n", cl->n_supers);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nimplemented\n", cl->n_implemented_classes);
        fprintf(dbgfile, "\t%d\t\t\t\t# Ninstancefields\n", cl->n_implemented_instance_fields);
        fprintf(dbgfile, "\t%d\t\t\t\t# Nclassfields\n", cl->n_implemented_class_fields);
        fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, name);
    }
    outword(T_Class);		/* type code */
    outword(cl->size);
    outword(0);
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
        fprintf(dbgfile, "\tZ+%ld\t\t\t\t# Pointer to init field\n", (long)p);
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
        fprintf(dbgfile, "\tZ+%ld\t\t\t\t# Pointer to new field\n", (long)p);
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
     * Implemented classes array.  They are sorted by ascending class id number.
     */
    ic_sort = sorted_implemented_classes(cl);
    if (Dflag) {
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Implemented classes array\n", (long)pc);
        for (i = 0; i < cl->n_implemented_classes; ++i)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Pointer to implemented class %s\n", 
                    ic_sort[i]->pc, ic_sort[i]->global->name);
    }
    for (i = 0; i < cl->n_implemented_classes; ++i)
        outword(ic_sort[i]->pc);
    free(ic_sort);

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
     * Output descriptors for class static variables.  Each gets a
     * null descriptor.  This loop also counts up the number of classes
     * and fields of all types.
     * 
     * Note that statics and methods are put in separate lists in
     * order to help the garbage collector scan faster (methods don't
     * need to be scanned).
     */
    if (Dflag)
        fprintf(dbgfile, "\n# class static descriptors\n");
    for (cl = lclasses; cl; cl = cl->next) {
        for (cf = cl->fields; cf; cf = cf->next) {
            if ((cf->flag & (M_Method | M_Static)) == M_Static) {
                /* Null descriptor */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%06lo\t0\t\t# Static var %s.%s\n", 
                            (long)pc, (long)D_Null, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Null);
                outword(0);
            }
            ++n_fields;
        }
        ++n_classes;
    }

    align();
    hdr.ClassMethods = pc;

    /*
     * Output descriptors for class methods :-
     *   defer methods get a proc descriptor with the 
     *      native method number (-1 if unresolved) in the vword
     *   other methods get a proc descriptor pointing to the b_proc
     */
    if (Dflag)
        fprintf(dbgfile, "\n# class method descriptors\n");
    for (cl = lclasses; cl; cl = cl->next) {
        for (cf = cl->fields; cf; cf = cf->next) {
            if (cf->flag & M_Defer) {
                /* Deferred method, perhaps resolved to native method */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%06lo\tN+%d\t\t# Deferred method %s.%s\n",
                            (long)pc, (long)D_Proc, cf->func->native_method_id, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Proc);
                outword(cf->func->native_method_id);
            } else if (cf->flag & M_Method) {
                /* Method, with definition in the icode file  */
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%06lo\tZ+%d\t\t# Method %s.%s\n",
                            (long)pc, (long)D_Proc, cf->func->pc, cl->global->name, cf->name);
                cf->dpc = pc;
                outword(D_Proc);
                outword(cf->func->pc);
            }
        }
    }


    align();
    hdr.ClassFields = pc;

    /* 
     * Firstly work out the "address" each class will have, so we can forward
     * reference them.
     */
    x = pc + WordSize * (1 + 4 * n_fields);  /* The size of the class
                                              * field table plus the
                                              * n_classes entry */
    if (loclevel > 1)
        x += WordSize * 3 * n_fields;        /* The optional classfieldlocs table */

    for (cl = lclasses; cl; cl = cl->next) {
        int n_fields = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;
        cl->pc = x;
        cl->size = WordSize * (18 +
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
                fprintf(dbgfile, "\t%d\t\t\t\t#   Fnum\n", cf->ftab_entry->field_id);
                fprintf(dbgfile, "\t%08lo\t\t\t#   Flags\n", (long)cf->flag);
                fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Defining class\n", cf->class->pc);
                fprintf(dbgfile, "\tZ+%d\t\t\t\t#   Pointer to descriptor\n", cf->dpc);
            }
            outword(cf->ftab_entry->field_id);
            outword(cf->flag);
            outword(cf->class->pc);
            outword(cf->dpc);
        }
    }

    align();
    hdr.ClassFieldLocs = pc;
    if (Dflag)
        fprintf(dbgfile, "\n# class field location table\n");
    if (loclevel > 1) {
        for (cl = lclasses; cl; cl = cl->next) {
            for (cf = cl->fields; cf; cf = cf->next) {
                sp = inst_c_strconst(cf->pos.file);
                if (Dflag) {
                    fprintf(dbgfile, "%ld:\t\t\t\t\t# Location of %s.%s\n", 
                            (long)pc, cl->global->name, cf->name);
                    fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   File %s\n", sp->len, sp->offset, cf->pos.file);
                    fprintf(dbgfile, "\t%d\t\t\t\t#   Line %d\n", cf->pos.line, cf->pos.line);
                }
                outword(sp->len);		/* filename: size and offset */
                outword(sp->offset);
                outword(cf->pos.line);
            }
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
    struct ipc_fname *fnptr;
    struct ipc_line *lnptr;

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
        size = 11 * WordSize + rec->nfields * (WordSize + ShortSize);
        if (loclevel > 1)
            size += rec->nfields * 3 * WordSize;
        size += nalign(size);
        if (Dflag) {
            fprintf(dbgfile, "\n# constructor %s\n", s);
            fprintf(dbgfile, "%ld:\n", (long)pc);
            fprintf(dbgfile, "\t%d\t\t\t\t# T_Constructor\n", T_Constructor);
            fprintf(dbgfile, "\t%d\n", size);
            fprintf(dbgfile, "\t0\n");
            fprintf(dbgfile, "\t%d\t\t\t\t# Package id\n", rec->global->defined->package_id);
            fprintf(dbgfile, "\t0\n");
            fprintf(dbgfile, "\t%d\n", rec->nfields);
            fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n", sp->len, sp->offset, s);
        }

        outword(T_Constructor);		/* type code */
        outword(size);
        outword(0);			/* progstate (filled in by interp)*/
        outword(rec->global->defined->package_id);  /* Package id */
        outword(0);			/* serial number counter */
        outword(rec->nfields);		/* number of fields */
        outword(sp->len);		/* name of record: size and offset */
        outword(sp->offset);

        /*
         * Pointers to the three tables that follow.
         */
        if (Dflag) {
            ap = pc + 3 * WordSize;
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to fnums array\n", ap);
            ap += rec->nfields * WordSize;
            if (loclevel > 1) {
                fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field_locs array\n", ap);
                ap += rec->nfields * 3 * WordSize;
            } else
                fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field_locs array\n", 0);
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to field sort array\n", ap);
        }
        ap = pc + 3 * WordSize;
        outword(ap);
        ap += rec->nfields * WordSize;
        if (loclevel > 1) {
            outword(ap);
            ap += rec->nfields * 3 * WordSize;
        } else
            outword(0);
        outword(ap);
        ap += rec->nfields * ShortSize;
        ap += nalign(ap);

        /*
         * Field names
         */
        if (Dflag)
            fprintf(dbgfile, "%ld:\t\t\t\t\t# Fnums array\n", (long)pc);
        for (fd = rec->fields; fd; fd = fd->next) {
            if (Dflag)
                fprintf(dbgfile, "\t%d\t\t\t\t#   Fnum\n", fd->ftab_entry->field_id);
            outword(fd->ftab_entry->field_id);
        }

        /*
         * Field locations, if selected
         */
        if (loclevel > 1) {
            if (Dflag)
                fprintf(dbgfile, "%ld:\t\t\t\t\t# Field locations array\n", (long)pc);
            for (fd = rec->fields; fd; fd = fd->next) {
                sp = inst_c_strconst(fd->pos.file);
                if (Dflag) {
                    fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   File %s\n", sp->len, sp->offset, fd->pos.file);
                    fprintf(dbgfile, "\t%d\t\t\t\t#   Line %d\n", fd->pos.line, fd->pos.line);
                }
                outword(sp->len);
                outword(sp->offset);
                outword(fd->pos.line);
            }
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
     * Output locations for global variables.
     */
    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Global variable locations\n", (long)pc);
    hdr.Glocs = pc;
    if (loclevel > 1) {
        for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
            if (gp->g_flag & F_Builtin) {
                if (Dflag) {
                    fprintf(dbgfile, "%ld:\t0\t0\t\t\t#   Builtin\n", (long)pc);
                    fprintf(dbgfile, "%ld:\t0\n", (long)pc);
                }
                outword(D_Null);
                outword(0);
                outword(0);
            } else {
                sp = inst_c_strconst(gp->pos.file);
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%d\tS+%d\t\t\t#   %s\n",
                            (long)pc, sp->len, sp->offset, gp->pos.file);
                outword(sp->len);
                outword(sp->offset);
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t%d\t\t\t\t#      Line %d\n",
                            (long)pc, gp->pos.line, gp->pos.line);
                outword(gp->pos.line);
            }
        }
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

    /*
     * Output the string constant table and the two tables associating icode
     *  locations with source program locations.  Note that the calls to write
     *  really do all the work.
     */

    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# File names table\n", (long)pc);
    hdr.Filenms = pc;
    for (fnptr = fnmtbl; fnptr < fnmfree; fnptr++) {
        if (Dflag)
            fprintf(dbgfile, "%ld:\t%03ld\t%d\tS+%03d\t\t#  File %s\n",
                    (long)pc, (long)fnptr->ipc, fnptr->sc->len, fnptr->sc->offset, fnptr->sc->s);
        outword(fnptr->ipc);
        outword(fnptr->sc->len);
        outword(fnptr->sc->offset);
    }

    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Line number table\n", (long)pc);
    hdr.linenums = pc;
    for (lnptr = lntable; lnptr < lnfree; lnptr++) {
        if (Dflag)
            fprintf(dbgfile, "%ld:\t%03ld\tl:%03d\n", (long)pc, (long)lnptr->ipc, lnptr->line);
        outword(lnptr->ipc);
        outword(lnptr->line);        
    }

    flushcode();
    
    if (Dflag)
        fprintf(dbgfile, "\n# string constants table\n");

    hdr.Strcons = pc;
    for (sp = first_strconst; sp; sp = sp->next) {
        if (sp->len > 0) {
            if (Dflag) {
                char *s = sp->s, t[9];
                int i, j = 0;
                for (i = 0; i < sp->len; ++i) {
                    if (i == 0)
                        fprintf(dbgfile, "%ld:(+%d)\t", (long)pc, sp->offset);
                    else if (i % 8 == 0) {
                        t[j] = 0;
                        fprintf(dbgfile, "   %s\n%ld:\t\t", t, (long)pc + i);
                        j = 0;
                    }
                    fprintf(dbgfile, " %02x", s[i] & 0xff);
                    t[j++] = isprint(s[i]) ? s[i] : ' ';
                }
                t[j] = 0;
                while (i % 8 != 0) {
                    fprintf(dbgfile, "   ");
                    ++i;
                }
                fprintf(dbgfile, "   %s\n", t);
            }
            if (fwrite(sp->s, 1, sp->len, outfile) != sp->len)
                quit("cannot write icode file");
            pc += sp->len;
        }
    }

    /*
     * Output icode file header.
     */
    hdr.icodesize = pc;
    strcpy((char *)hdr.config,IVersion);
    hdr.trace = trace;


    if (Dflag) {
        fprintf(dbgfile, "\n");
        fprintf(dbgfile, "icodesize:        %ld\n", (long)hdr.icodesize);
        fprintf(dbgfile, "trace:            %ld\n", (long)hdr.trace);
        fprintf(dbgfile, "class statics:    %ld\n", (long)hdr.ClassStatics);
        fprintf(dbgfile, "class methods:    %ld\n", (long)hdr.ClassMethods);
        fprintf(dbgfile, "class fields:     %ld\n", (long)hdr.ClassFields);
        fprintf(dbgfile, "class field locs: %ld\n", (long)hdr.ClassFieldLocs);
        fprintf(dbgfile, "classes:          %ld\n", (long)hdr.Classes);
        fprintf(dbgfile, "records:          %ld\n", (long)hdr.Records);
        fprintf(dbgfile, "fnames:           %ld\n", (long)hdr.Fnames);
        fprintf(dbgfile, "globals:          %ld\n", (long)hdr.Globals);
        fprintf(dbgfile, "gnames:           %ld\n", (long)hdr.Gnames);
        fprintf(dbgfile, "glocs:            %ld\n", (long)hdr.Glocs);
        fprintf(dbgfile, "statics:          %ld\n", (long)hdr.Statics);
        fprintf(dbgfile, "filenms:          %ld\n", (long)hdr.Filenms);
        fprintf(dbgfile, "linenums:         %ld\n", (long)hdr.linenums);
        fprintf(dbgfile, "strcons:          %ld\n", (long)hdr.Strcons);
        fprintf(dbgfile, "config:           %s\n", (char*)hdr.config);
    }

    fseek(outfile, scriptsize, 0);

    if (fwrite((char *)&hdr, 1, sizeof(hdr), outfile) != sizeof(hdr))
        quit("cannot write icode file");

    if (verbose > 1) {
        word tsize = sizeof(hdr) + hdr.icodesize;
        report("  Script          %7ld", scriptsize);
        tsize += scriptsize;
        report("  Header          %7ld", (long)sizeof(hdr));
        report("  Procedures      %7ld", (long)hdr.ClassStatics);
        report("  Class statics   %7ld", (long)(hdr.ClassMethods - hdr.ClassStatics));
        report("  Class methods   %7ld", (long)(hdr.ClassFields - hdr.ClassMethods));
        report("  Class fields    %7ld", (long)(hdr.ClassFieldLocs - hdr.ClassFields));
        report("  Class field locs%7ld", (long)(hdr.Classes - hdr.ClassFieldLocs));
        report("  Classes         %7ld", (long)(hdr.Records - hdr.Classes));
        report("  Records         %7ld", (long)(hdr.Fnames - hdr.Records));
        report("  Field names     %7ld", (long)(hdr.Globals - hdr.Fnames));
        report("  Globals         %7ld", (long)(hdr.Gnames  - hdr.Globals));
        report("  Global names    %7ld", (long)(hdr.Glocs - hdr.Gnames));
        report("  Global locs     %7ld", (long)(hdr.Statics - hdr.Glocs));
        report("  Statics         %7ld", (long)(hdr.Filenms - hdr.Statics));
        report("  Filenms         %7ld", (long)(hdr.linenums - hdr.Filenms));
        report("  Linenums        %7ld", (long)(hdr.Strcons - hdr.linenums));
        report("  Strings         %7ld", (long)(hdr.icodesize - hdr.Strcons));
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
 * flushcode - write buffered code to the output file.
 */
static void flushcode()
{
    if (codep > codeb) {
        size_t n = DiffPtrs(codep,codeb);
        if (fwrite(codeb, 1, n, outfile) != n)
            quit("cannot write icode file");
    }
    codep = codeb;
}

/*
 * cleartables - clear some tables to all zeroes.
 */
static void cleartables()
{
    int i;

    for (i = 0; i < maxlabels; i++)
        labels[i] = 0;

    loopsp = loopstk;
    loopsp->nextlab = 0;
    loopsp->breaklab = 0;
    loopsp->markcount = 0;

    creatsp = creatstk;

    nextlab = 1;
}



/*
 * labout - fill in all forward references to lab.
 */
static void labout(int lab)
{
    word p, r;
    char *q;
    char *cp, *cr;
    int j;

    if (Dflag)
        fprintf(dbgfile, "L%d:\n", lab);

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


/*
 * expand_table - realloc a table making it half again larger and zero the
 *   new part of the table.
 */
static void * expand_table(void * table,      /* table to be realloc()ed */
                    void * tblfree,    /* reference to table free pointer if there is one */
                    size_t *size,      /* size of table */
                    int unit_size,      /* number of bytes in a unit of the table */
                    int min_units,      /* the minimum number of units that must be allocated. */
                    char *tbl_name)     /* name of the table */
{
    size_t new_size;
    size_t num_bytes;
    size_t free_offset = 0;
    size_t i;
    char *new_tbl;

    new_size = (*size * 3) / 2;
    if (new_size - *size < min_units)
        new_size = *size + min_units;
    num_bytes = new_size * unit_size;

    if (tblfree != NULL)
        free_offset = DiffPtrs(*(char **)tblfree,  (char *)table);

    if ((new_tbl = (char *)realloc(table, (unsigned)num_bytes)) == 0)
        quitf("out of memory for %s", tbl_name);

    for (i = *size * unit_size; i < num_bytes; ++i)
        new_tbl[i] = 0;

    *size = new_size;
    if (tblfree != NULL)
        *(char **)tblfree = (char *)(new_tbl + free_offset);

    return (void *)new_tbl;
}

static void binop(int n)
{
    int opcode = 0;

    switch (n) {

        case Uop_Asgn:
            opcode = Op_Asgn;
            break;

        case Uop_Augpower:
        case Uop_Power:
            opcode = Op_Power;
            break;

        case Uop_Augcat:
        case Uop_Cat:
            opcode = Op_Cat;
            break;

        case Uop_Augdiff:
        case Uop_Diff:
            opcode = Op_Diff;
            break;

        case Uop_Augeqv:
        case Uop_Eqv:
            opcode = Op_Eqv;
            break;

        case Uop_Auginter:
        case Uop_Inter:
            opcode = Op_Inter;
            break;

        case Uop_Subsc:
            opcode = Op_Subsc;
            break;

        case Uop_Auglconcat:
        case Uop_Lconcat:
            opcode = Op_Lconcat;
            break;

        case Uop_Auglexeq:
        case Uop_Lexeq:
            opcode = Op_Lexeq;
            break;

        case Uop_Auglexge:
        case Uop_Lexge:
            opcode = Op_Lexge;
            break;

        case Uop_Auglexgt:
        case Uop_Lexgt:
            opcode = Op_Lexgt;
            break;

        case Uop_Auglexle:
        case Uop_Lexle:
            opcode = Op_Lexle;
            break;

        case Uop_Auglexlt:
        case Uop_Lexlt:
            opcode = Op_Lexlt;
            break;

        case Uop_Auglexne:
        case Uop_Lexne:
            opcode = Op_Lexne;
            break;

        case Uop_Augminus:
        case Uop_Minus:
            opcode = Op_Minus;
            break;

        case Uop_Augmod:
        case Uop_Mod:
            opcode = Op_Mod;
            break;

        case Uop_Augneqv:
        case Uop_Neqv:
            opcode = Op_Neqv;
            break;

        case Uop_Augnumeq:
        case Uop_Numeq:
            opcode = Op_Numeq;
            break;

        case Uop_Augnumge:
        case Uop_Numge:
            opcode = Op_Numge;
            break;

        case Uop_Augnumgt:
        case Uop_Numgt:
            opcode = Op_Numgt;
            break;

        case Uop_Augnumle:
        case Uop_Numle:
            opcode = Op_Numle;
            break;

        case Uop_Augnumlt:
        case Uop_Numlt:
            opcode = Op_Numlt;
            break;

        case Uop_Augnumne:
        case Uop_Numne:
            opcode = Op_Numne;
            break;

        case Uop_Augplus:
        case Uop_Plus:
            opcode = Op_Plus;
            break;

        case Uop_Rasgn:
            opcode = Op_Rasgn;
            break;

        case Uop_Rswap:
            opcode = Op_Rswap;
            break;

        case Uop_Augdiv:
        case Uop_Div:
            opcode = Op_Div;
            break;

        case Uop_Augmult:
        case Uop_Mult:
            opcode = Op_Mult;
            break;

        case Uop_Swap:
            opcode = Op_Swap;
            break;

        case Uop_Augunions:
        case Uop_Unions:
            opcode = Op_Unions;
            break;

        default:
            quit("binop: undefined binary operator");
    }

    lemit(opcode);
}

/*
 * alclab allocates n labels and returns the first.  For the interpreter,
 *  labels are restarted at 1 for each procedure, while in the compiler,
 *  they start at 1 and increase throughout the entire compilation.
 */
static int alclab(int n)
{
    register int lab;

    lab = nextlab;
    nextlab += n;
    return lab;
}

static void unop(int op)
{
    switch (op) {
        case Uop_Value:			/* unary . operator */
            lemit(Op_Value);
            break;

        case Uop_Nonnull:		/* unary \ operator */
            lemit(Op_Nonnull);
            break;

        case Uop_Bang:		/* unary ! operator */
            lemit(Op_Bang);
            break;

        case Uop_Refresh:		/* unary ^ operator */
            lemit(Op_Refresh);
            break;

        case Uop_Number:		/* unary + operator */
            lemit(Op_Number);
            break;

        case Uop_Compl:		/* unary ~ operator (cset compl) */
            lemit(Op_Compl);
            break;

        case Uop_Neg:		/* unary - operator */
            lemit(Op_Neg);
            break;

        case Uop_Tabmat:		/* unary = operator */
            lemit(Op_Tabmat);
            break;

        case Uop_Size:		/* unary * operator */
            lemit(Op_Size);
            break;

        case Uop_Random:		/* unary ? operator */
            lemit(Op_Random);
            break;

        case Uop_Null:		/* unary / operator */
            lemit(Op_Null);
            break;

        default:
            quit("unopb: undefined unary operator");
    }
}

/*
 * Write a short shell header terminated by \n\f\n\0.
 * Use magic "#!/bin/sh" to ensure that $0 is set when run via $PATH.
 * Pad header to a multiple of 8 characters.
 */
static void writescript()
{
    char script[2048];

#if MSWindows
    /*
     * The NT and Win95 direct execution batch file turns echoing off,
     * launches wiconx, attempts to terminate softly via noop.bat,
     * and terminates the hard way (by exiting the DOS shell) if that
     * fails, rather than fall through and start executing machine code
     * as if it were batch commands.
     */
    snprintf(script, sizeof(script),
             "@echo off\r\n%s %%0 %%1 %%2 %%3 %%4 %%5 %%6 %%7 %%8 %%9\r\n%s%s%s",
             iconxloc,
             "noop.bat\r\n@echo on\r\n",
             "pause missing noop.bat - press ^c or shell will exit\r\n",
             "exit\r\n" IcodeDelim "\r\n");

#endif					/* MSWindows */
#if UNIX
    /*
     *  Generate a shell header that searches for iconx in this order:
     *     a.  location specified by ICONX environment variable
     *         (if specified, this MUST work, else the script exits)
     *     b.  iconx in same directory as executing binary
     *     c.  location specified in script
     *         (as generated by icont or as patched later)
     *     d.  iconx in $PATH
     *
     *  The ugly ${1+"$@"} is a workaround for non-POSIX handling
     *  of "$@" by some shells in the absence of any arguments.
     *  Thanks to the Unix-haters handbook for this trick.
     */
    snprintf(script, sizeof(script),
             "%s\n%s%-72s\n%s\n\n%s\n%s\n%s\n%s%s%s\n\n%s",
             "#!/bin/sh",
             "OIXBIN=", iconxloc,
             "OIXLCL=`echo $0 | sed 's=[^/]*$=oix='`",
             "[ -n \"$OIX\" ] && exec \"$OIX\" $0 ${1+\"$@\"}",
             "[ -x $OIXLCL ] && exec $OIXLCL $0 ${1+\"$@\"}",
             "[ -x $OIXBIN ] && exec $OIXBIN $0 ${1+\"$@\"}",
             "exec ",
             "oix",
             " $0 ${1+\"$@\"}",
             IcodeDelim "\n");
#endif					/* UNIX */

    scriptsize = strlen(script);
    fwrite(script, scriptsize, 1, outfile);	/* write header */
}


