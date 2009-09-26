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
#include "ir.h"

#include "../h/opdefs.h"
#include "../h/opnames.h"
#include "../h/header.h"
#include "../h/rmacros.h"
#undef constants

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

/* Linked list of constants in the constant descriptors table */
static struct centry *const_desc_first, *const_desc_last;
int const_desc_count;  

/*
 * Prototypes.
 */

static int      nalign(int n);
static void	align		(void);
static void labout(int i, char *desc);
static void	cleartables	(void);
static void	flushcode	(void);
static void	lemitproc       ();
static void	lemitcode       ();
static void	patchrefs       ();
static void     lemitcon(struct centry *ce);
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
static word cnv_op(int n);
static void gentables(void);
static void synch_file();
static void synch_line();
static void *expand_table(void * table,      /* table to be realloc()ed */
                          void * tblfree,    /* reference to table free pointer if there is one */
                          size_t *size, /* size of table */
                          int unit_size,      /* number of bytes in a unit of the table */
                          int min_units,      /* the minimum number of units that must be allocated. */
                          char *tbl_name);     /* name of the table */

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

static void word_field(word w, char *desc)
{
    if (Dflag)
        fprintf(dbgfile, "%ld:\t  %s\t%d\n", (long)pc, desc, w);
    outword(w);
}

static void emit_ir_var(struct ir_var *v, char *desc)
{
    if (!v) {
        if (Dflag)
            fprintf(dbgfile, "%ld:\t  %s\tnil\n", (long)pc, desc);
        outword(Op_Nil);
        return;
    }

    switch (v->type) {
        case CONST: {
            struct centry *ce = v->con;
            if (ce->c_flag & F_IntLit) {
                word ival;
                memcpy(&ival, ce->data, sizeof(word));
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t  %s\tint\t\t%d\n", (long)pc, desc, ival);
                outword(Op_Int);
                outword(ival);
            } else {
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t  %s\tconst\t\tC[%d]\n", (long)pc, desc, ce->desc_no);
                outword(Op_Const);
                outword(ce->desc_no);
            }
            break;
        }
        case WORD: {
            if (Dflag)
                fprintf(dbgfile, "%ld:\t  %s\tint\t\t%d\n", (long)pc, desc, v->w);
            outword(Op_Int);
            outword(v->w);
            break;
        }
        case KNULL: {
            if (Dflag)
                fprintf(dbgfile, "%ld:\t  %s\t&null\n", (long)pc, desc);
            outword(Op_Knull);
            break;
        }
        case LOCAL: {
            struct lentry *le = v->local;
            if (le->l_flag & F_Static) {
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t  %s\tstatic\t\t%d\n", (long)pc, desc, le->l_val.index);
                outword(Op_Static);
                outword(le->l_val.index);
            } else if (le->l_flag & F_Argument) {
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t  %s\targ\t\t%d\n", (long)pc, desc, le->l_val.index);
                outword(Op_Arg);
                outword(le->l_val.index);
            } else {
                if (Dflag)
                    fprintf(dbgfile, "%ld:\t  %s\tdynamic\t%d\n", (long)pc, desc, le->l_val.index);
                outword(Op_Dynamic);
                outword(le->l_val.index);
            }
            break;
        }
        case GLOBAL: {
            struct gentry *ge = v->global;
            if (Dflag)
                fprintf(dbgfile, "%ld:\t  %s\tglobal\t%d\n", (long)pc, desc, ge->g_index);
            outword(Op_Global);
            outword(ge->g_index);
            break;
        }
        case TMP: {
            if (Dflag)
                fprintf(dbgfile, "%ld:\t  %s\ttmp\t\t%d\n", (long)pc, desc, v->index);
            outword(Op_Tmp);
            outword(v->index);
            break;
        }
        case CLOSURE: {
            if (Dflag)
                fprintf(dbgfile, "%ld:\t  %s\tclosure\t%d\n", (long)pc, desc, v->index);
            outword(Op_Closure);
            outword(v->index);
            break;
        }
        default: {
            quit("make_varword:Unknown type");
        }
    }
}

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


static void gencode_func(struct lfunction *f)
{
    struct centry *cp;

    /*
     * Initialize for procedure/method.
     */
    curr_lfunc = f;
    generate_ir();
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
    lemitproc();
    lemitcode();
    patchrefs();
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


/* Same as in rstructs.h */
struct b_real {			/* real block */
    word title;			/*   T_Real */
#ifdef DOUBLE_HAS_WORD_ALIGNMENT
    double realval;		/*   value */
#else
    word realval[DoubleWords];
#endif
};

static void lemitcon(struct centry *ce)
{
    int i;
    struct centry *p;

    /*
     * If it's an int don't do anything
     */
    if (ce->c_flag & F_IntLit)
        return;

    /*
     * See if we've seen one with the same type and data before which
     * we can reuse.
     */

    i = hasher(ce->data, constblock_hash);
    p = constblock_hash[i];
    while (p && (p->data != ce->data || p->c_flag != ce->c_flag))
        p = p->b_next;
    if (p) {
        /*
         * Seen before, so just copy desc_no from previously output one.
         */
        ce->desc_no = p->desc_no;
        return;
    }
    /*
     * Add to hash chain and output
     */
    ce->b_next = constblock_hash[i];
    constblock_hash[i] = ce;

    /*
     * Add to constant descriptor table list and set desc_no
     */
    if (const_desc_last) {
        const_desc_last->d_next = ce;
        const_desc_last = ce;
    } else
        const_desc_first = const_desc_last = ce;
    ce->desc_no = const_desc_count++;

    /*
     * Output blocks for large int, real, cset and ucs types, saving the address in ce->pc.
     */

    if (ce->c_flag & F_LrgintLit) {
        struct strconst *str = inst_strconst(ce->data, ce->length);;
        if (Dflag) {
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Lrgint\n",(long) pc, T_Lrgint);
            fprintf(dbgfile, "\t%d\tS+%d\t\t\t#  data\n", str->len, str->offset);
        }
        outword(T_Lrgint);
        outword(str->len);
        outword(str->offset);       
    } else if (ce->c_flag & F_RealLit) {
        static struct b_real d;
        ce->pc = pc;
        d.title = T_Real;
        memcpy(&d.realval, ce->data, sizeof(double));
        if (Dflag) {
            int i;
            word *p;
            double t;
            memcpy(&t, ce->data, sizeof(double));
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Real (%g)\n",(long) pc, T_Real, t);
            p = (word *)&d + 1;
            for (i = 1; i < sizeof(d)/sizeof(word); ++i)
                fprintf(dbgfile, "\t%08lx\t\t\t#    double data\n", (long)(*p++));
        }
        outblock((char *)&d, sizeof(d));
    }
    else if (ce->c_flag & F_CsetLit) {
        int i, j, x;
        word csbuf[CsetSize];
        int npair = ce->length / sizeof(struct range);
        int size = 0;
        /* Need to alloc not cast because string data might not be aligned */
        struct range *pair = safe_alloc(ce->length);
        ce->pc = pc;
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

        ce->pc = pc;
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
            fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Ucs\n",(long) pc, T_Ucs);
            fprintf(dbgfile, "\t%lu\t\t\t\t# Block size\n", (unsigned long)((7 + n_offs) * WordSize));
            fprintf(dbgfile, "\t%d\t\t\t\t# Length\n", length);
            fprintf(dbgfile, "\t%d\tS+%d\t\t\t# UTF8 data\n", utf8->len, utf8->offset);
            fprintf(dbgfile, "\t%d\t\t\t\t# N indexed\n", n_offs);
            fprintf(dbgfile, "\t%d\t\t\t\t# Index step\n", index_step);
        }
        outword(T_Ucs);
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
    }
}

static void patchrefs()
{
    word basepc;
    int i;
    /* Compute the pc corresponding to &codeb[0] */
    basepc = pc - (codep - codeb);
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        word p;
        chunk = chunks[i];
        if (!chunk)
            continue;
        p = chunk->refs;
        while (p) {
            word t;
            memcpy(&t, &codeb[p - basepc], WordSize);
            memcpy(&codeb[p - basepc], &chunk->pc, WordSize);
            p = t;
        }
    }
}

static void lemitcode()
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        chunk->pc = pc;
        if (Dflag)
            fprintf(dbgfile, "%ld:chunk %d\n", (long)pc, i);
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            switch (ir->op) {
                case Ir_Goto: {
                    struct ir_goto *x = (struct ir_goto *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tgoto\t\t%d\n", (long)pc, x->dest);
                    outword(Op_Goto);
                    labout(x->dest, "dest");
                    break;
                }
                case Ir_IGoto: {
                    struct ir_igoto *x = (struct ir_igoto *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tigoto\t\t%d\n", (long)pc, x->no);
                    outword(Op_IGoto);
                    outword(x->no);
                    break;
                }
                case Ir_EnterInit: {
                    struct ir_enterinit *x = (struct ir_enterinit *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tenterinit\t%d\n", (long)pc, x->dest);
                    outword(Op_EnterInit);
                    labout(x->dest, "dest");
                    break;
                }
                case Ir_Fail: {
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tfail\n", (long)pc);
                    outword(Op_Fail);
                    break;
                }
                case Ir_Mark: {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tmark\t\t%d\n", (long)pc, x->no);
                    outword(Op_Mark);
                    outword(x->no);
                    break;
                }
                case Ir_Unmark: {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tunmark\t\t%d\n", (long)pc, x->no);
                    outword(Op_Unmark);
                    outword(x->no);
                    break;
                }
                case Ir_Move: {
                    struct ir_move *x = (struct ir_move *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tmove\n", (long)pc);
                    outword(Op_Move);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->rhs, "rhs");
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tmovelabel\t%d %d\n", (long)pc, x->destno, x->lab);
                    outword(Op_MoveLabel);
                    outword(x->destno);
                    labout(x->lab, "lab");
                    break;
                }
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tderef\n", (long)pc);
                    outword(Op_Deref);
                    emit_ir_var(x->src, "src");
                    emit_ir_var(x->dest, "dest");
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    word op = cnv_op(x->operation);
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\top %s\n", (long)pc, op_names[op]);
                    outword(op);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    if (x->arg2)
                        emit_ir_var(x->arg2, "arg2");
                    if (x->arg3)
                        emit_ir_var(x->arg3, "arg3");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    word op = cnv_op(x->operation);
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\top closure %s\n", (long)pc, op_names[op]);
                    outword(op);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->arg1, "arg1");
                    if (x->arg2)
                        emit_ir_var(x->arg2, "arg2");
                    if (x->arg3)
                        emit_ir_var(x->arg3, "arg3");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tkeyop\n", (long)pc);
                    outword(Op_Keyop);
                    word_field(x->keyword, "keyword");
                    emit_ir_var(x->lhs, "lhs");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tkeyclo\n", (long)pc);
                    outword(Op_Keyclo);
                    word_field(x->keyword, "keyword");
                    word_field(x->clo, "clo");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tinvoke\n", (long)pc);
                    outword(Op_Invoke);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->expr, "expr");
                    word_field(x->argc, "argc");
                    for (i = 0; i < x->argc; ++i) {
                        emit_ir_var(x->args[i], "arg");
                    }
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_Resume: {
                    struct ir_resume *x = (struct ir_resume *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tresume\n", (long)pc);
                    outword(Op_Resume);
                    word_field(x->clo, "clo");
                    break;
                }
                case Ir_ScanSwap: {
                    struct ir_scanswap *x = (struct ir_scanswap *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tscanswap\n", (long)pc);
                    outword(Op_ScanSwap);
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }
                case Ir_ScanSave: {
                    struct ir_scansave *x = (struct ir_scansave *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tscansave\n", (long)pc);
                    outword(Op_ScanSave);
                    emit_ir_var(x->new_subject, "new_subject");
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }
                case Ir_ScanRestore: {
                    struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                    if (Dflag)
                        fprintf(dbgfile, "%ld:\tscanrestore\n", (long)pc);
                    outword(Op_ScanRestore);
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }

                default: {
                    quitf("lemitcode: illegal ir opcode(%d)\n", ir->op);
                    break;
                }
            }
        }
    }
}


static void lemitproc()
{
    char *p;
    int size, ap;
    struct lentry *le;
    struct strconst *sp;

    /*
     * FncBlockSize = sizeof(BasicFncBlock) +
     *  sizeof(descrip)*(# of args + # of dynamics + # of statics).
     */
    if (abs(curr_lfunc->nargs) != curr_lfunc->narguments)
        quitf("Mismatch between ufile's nargs and narguments");

    size = (21*WordSize) + 2*WordSize * (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics);
    if (loclevel > 1)
        size += 3*WordSize * (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics);

    if (curr_lfunc->proc)
        p = curr_lfunc->proc->name;
    else
        p = curr_lfunc->method->name;

    sp = inst_c_strconst(p);

    if (Dflag) {
        fprintf(dbgfile, "%ld:\t%d\t\t\t\t# T_Proc\n", (long)pc, T_Proc); /* type code */
        fprintf(dbgfile, "\t%d\t\t\t\t# Block size\n", size);			/* size of block */
        fprintf(dbgfile, "\tZ+%ld\t\t\t\t# Entry point\n",(long)(curr_lfunc->pc + size));	/* entry point */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num args\n", curr_lfunc->nargs);	/* # arguments */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num dynamic\n", curr_lfunc->ndynamic);	/* # dynamic locals */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num static\n", curr_lfunc->nstatics);	/* # static locals */
        fprintf(dbgfile, "\t%d\t\t\t\t# First static\n", nstatics);		/* first static */
        fprintf(dbgfile, "\t0\n");		        /* owning prog space */
        fprintf(dbgfile, "\t%d\t\t\t\t# Num closures\n", n_clo);
        fprintf(dbgfile, "\t%d\t\t\t\t# Num temporaries\n", n_tmp);
        fprintf(dbgfile, "\t%d\t\t\t\t# Num labels\n", n_lab);
        fprintf(dbgfile, "\t%d\t\t\t\t# Num marks\n", n_mark);
        fprintf(dbgfile, "\t0\n");		        /* framesize */
        fprintf(dbgfile, "\t0\n");		        /* ntend */
        fprintf(dbgfile, "\t0\n");		        /* deref */
        fprintf(dbgfile, "\t%d\t\t\t\t# Package id\n", curr_lfunc->defined->package_id);       /* package id */
        fprintf(dbgfile, "\t0\n");		        /* field */
        fprintf(dbgfile, "\t%d\tS+%d\t\t\t# %s\n",	/* name of procedure */
                sp->len, sp->offset, p);
    }

    outword(T_Proc);
    outword(size);
    outword(curr_lfunc->pc + size);
    outword(curr_lfunc->nargs);
    outword(curr_lfunc->ndynamic);
    outword(curr_lfunc->nstatics);
    outword(nstatics);
    outword(0);
    outword(n_clo);
    outword(n_tmp);
    outword(n_lab);
    outword(n_mark);
    outword(0);
    outword(0);
    outword(0);
    outword(curr_lfunc->defined->package_id);
    outword(0);
    outword(sp->len);          /* procedure name: length & offset */
    outword(sp->offset);

    /*
     * Pointers to the tables that follow.
     */
    if (Dflag) {
        ap = pc + 2 * WordSize;
        fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to lnames array\n", ap);
        ap += (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics) * 2 * WordSize;
        if (loclevel > 1)
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to llocs array\n", ap);
        else
            fprintf(dbgfile, "\tZ+%d\t\t\t\t# Pointer to llocs array\n", 0);
    }

    ap = pc + 2 * WordSize;
    outword(ap);
    ap += (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics) * 2 * WordSize;
    if (loclevel > 1) {
        outword(ap);
        ap += (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics) * 3 * WordSize;
    } else
        outword(0);

    /*
     * Names array.  Loop through the list of locals three times to get the output
     * in the correct order.
     */
    if (Dflag)
        fprintf(dbgfile, "%ld:\t\t\t\t\t# Local names array\n", (long)pc);
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Argument) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Dynamic) {
            sp = inst_c_strconst(le->name);
            if (Dflag)
                fprintf(dbgfile, "\t%d\tS+%d\t\t\t#   %s\n", sp->len, sp->offset, le->name);
            outword(sp->len);
            outword(sp->offset);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
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
        for (le = curr_lfunc->locals; le; le = le->next) {
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
        for (le = curr_lfunc->locals; le; le = le->next) {
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
        for (le = curr_lfunc->locals; le; le = le->next) {
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

    if (curr_lfunc->pc + size != pc)
        quitf("I got my sums wrong(e): %d != %d", curr_lfunc->pc + size, pc);
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
    struct centry *ce;

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

    if (Dflag)
        fprintf(dbgfile, "\n%ld:\t\t\t\t\t# Constant descriptors\n", (long)pc);
    hdr.Constants = pc;
    for (ce = const_desc_first; ce; ce = ce->d_next) {
        if (ce->c_flag & F_IntLit) {
            word ival;
            memcpy(&ival, ce->data, sizeof(word));
            if (Dflag)
                fprintf(dbgfile, "%ld:\tD_Integer\t%ld\n", (long)pc, (long)ival);
            outword(D_Integer);
            outword(ival);
        } else if (ce->c_flag & (F_StrLit | F_LrgintLit)) {
            struct strconst *sp = inst_strconst(ce->data, ce->length);
            if (Dflag)
                fprintf(dbgfile, "%ld:\t%d\tS+%d\n", (long)pc, sp->len, sp->offset);
            outword(sp->len);
            outword(sp->offset);
        } else if (ce->c_flag & F_RealLit) {
            if (Dflag)
                fprintf(dbgfile, "%ld:\tD_Real\tZ+%ld\n", (long)pc, (long)ce->pc);
            outword(D_Real);
            outword(ce->pc);
        } else if (ce->c_flag & F_CsetLit) {
            if (Dflag)
                fprintf(dbgfile, "%ld:\tD_Cset\tZ+%ld\n", (long)pc, (long)ce->pc);
            outword(D_Cset);
            outword(ce->pc);
        } else if (ce->c_flag & F_UcsLit) {
            if (Dflag)
                fprintf(dbgfile, "%ld:\tD_Ucs\tZ+%ld\n", (long)pc, (long)ce->pc);
            outword(D_Ucs);
            outword(ce->pc);
        } else
            quit("unknown constant type");
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
                    t[j++] = isprint((unsigned char)s[i]) ? s[i] : ' ';
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
        fprintf(dbgfile, "constants:        %ld\n", (long)hdr.Constants);
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
        report("  Statics         %7ld", (long)(hdr.Constants - hdr.Statics));
        report("  Constants       %7ld", (long)(hdr.Filenms - hdr.Constants));
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
    CodeCheck(WordSize);
    memcpy(codep, &oword, WordSize);
    codep += WordSize;
    pc += WordSize;
}

static void shortout(short s)
{
    CodeCheck(ShortSize);
    memcpy(codep, &s, ShortSize);
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

static void labout(int i, char *desc)
{
    struct chunk *chunk = chunks[i];
    word t = pc;
    if (Dflag)
        fprintf(dbgfile, "%ld:\t  %s\tChunk %d\n", (long)pc, desc, i);
    outword(chunk->refs);
    chunk->refs = t;
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

static word cnv_op(int n)
{
    word opcode = 0;

    switch (n) {

        case Uop_Asgn:
            opcode = Op_Asgn;
            break;

        case Uop_Power:
            opcode = Op_Power;
            break;

        case Uop_Cat:
            opcode = Op_Cat;
            break;

        case Uop_Diff:
            opcode = Op_Diff;
            break;

        case Uop_Eqv:
            opcode = Op_Eqv;
            break;

        case Uop_Inter:
            opcode = Op_Inter;
            break;

        case Uop_Subsc:
            opcode = Op_Subsc;
            break;

        case Uop_Lconcat:
            opcode = Op_Lconcat;
            break;

        case Uop_Lexeq:
            opcode = Op_Lexeq;
            break;

        case Uop_Lexge:
            opcode = Op_Lexge;
            break;

        case Uop_Lexgt:
            opcode = Op_Lexgt;
            break;

        case Uop_Lexle:
            opcode = Op_Lexle;
            break;

        case Uop_Lexlt:
            opcode = Op_Lexlt;
            break;

        case Uop_Lexne:
            opcode = Op_Lexne;
            break;

        case Uop_Minus:
            opcode = Op_Minus;
            break;

        case Uop_Mod:
            opcode = Op_Mod;
            break;

        case Uop_Neqv:
            opcode = Op_Neqv;
            break;

        case Uop_Numeq:
            opcode = Op_Numeq;
            break;

        case Uop_Numge:
            opcode = Op_Numge;
            break;

        case Uop_Numgt:
            opcode = Op_Numgt;
            break;

        case Uop_Numle:
            opcode = Op_Numle;
            break;

        case Uop_Numlt:
            opcode = Op_Numlt;
            break;

        case Uop_Numne:
            opcode = Op_Numne;
            break;

        case Uop_Plus:
            opcode = Op_Plus;
            break;

        case Uop_Rasgn:
            opcode = Op_Rasgn;
            break;

        case Uop_Rswap:
            opcode = Op_Rswap;
            break;

        case Uop_Div:
            opcode = Op_Div;
            break;

        case Uop_Mult:
            opcode = Op_Mult;
            break;

        case Uop_Swap:
            opcode = Op_Swap;
            break;

        case Uop_Unions:
            opcode = Op_Unions;
            break;

        case Uop_Value:			/* unary . operator */
            opcode = Op_Value;
            break;

        case Uop_Nonnull:		/* unary \ operator */
            opcode = Op_Nonnull;
            break;

        case Uop_Bang:		/* unary ! operator */
            opcode = Op_Bang;
            break;

        case Uop_Refresh:		/* unary ^ operator */
            opcode = Op_Refresh;
            break;

        case Uop_Number:		/* unary + operator */
            opcode = Op_Number;
            break;

        case Uop_Compl:		/* unary ~ operator (cset compl) */
            opcode = Op_Compl;
            break;

        case Uop_Neg:		/* unary - operator */
            opcode = Op_Neg;
            break;

        case Uop_Tabmat:		/* unary = operator */
            opcode = Op_Tabmat;
            break;

        case Uop_Size:		/* unary * operator */
            opcode = Op_Size;
            break;

        case Uop_Random:		/* unary ? operator */
            opcode = Op_Random;
            break;

        case Uop_Null:		/* unary / operator */
            opcode = Op_Null;
            break;

        case Uop_Toby:
            opcode = Op_Toby;
            break;

        default:
            quit("cnv_op: undefined operator");
    }

    return opcode;
}

static void writescript()
{
#if MSWIN32
   char *hdr = findexe("win32header");
   FILE *f;
   int c;
   if (!hdr)
      quitf("Couldn't find win32header header file on PATH");
   if (!(f = fopen(hdr, ReadBinary)))
      quitf("Tried to open win32header to build .exe, but couldn't");
   scriptsize = 0;
   while ((c = fgetc(f)) != EOF) {
      fputc(c, outfile);
      ++scriptsize;
   }
   fputs("\n" IcodeDelim "\n", outfile);
   scriptsize += strlen("\n" IcodeDelim "\n");
   fclose(f);
#endif					/* MSWIN32 */
#if UNIX
    char script[2048];
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
             "OIXBIN=", oixloc,
             "OIXLCL=`echo $0 | sed 's=[^/]*$=oix='`",
             "[ -n \"$OIX\" ] && exec \"$OIX\" $0 ${1+\"$@\"}",
             "[ -x $OIXLCL ] && exec $OIXLCL $0 ${1+\"$@\"}",
             "[ -x $OIXBIN ] && exec $OIXBIN $0 ${1+\"$@\"}",
             "exec ",
             "oix",
             " $0 ${1+\"$@\"}",
             IcodeDelim "\n");
    scriptsize = strlen(script);
    fwrite(script, scriptsize, 1, outfile);	/* write header */
#endif					/* UNIX */
}


