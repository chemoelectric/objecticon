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
static int ntcase = 0;                 /* Running count of tcase tables */

/*
 * Array sizes for various linker tables that can be expanded with realloc().
 */
static size_t maxcode	= 100000;        /* code space */
static size_t nsize       = 10000;         /* ipc/line num. assoc. table */
static size_t fnmsize     = 100;           /* ipc/file name assoc. table */

static struct ipc_fname *fnmtbl;	/* table associating ipc with file name */
static struct ipc_line *lntable;	/* table associating ipc with line number */
static struct ipc_fname *fnmfree;	/* free pointer for ipc/file name table */
static struct ipc_line *lnfree;	/* free pointer for ipc/line number table */
static char *codeb;			/* generated code space */
static char *codep;			/* free pointer for code space */

static char *curr_file,         /* Current file name */
            *last_fnmtbl_filen; /* Last file name entered into fnmtbl above */
static int curr_line,
           last_lntable_line;

/* Linked list of constants in the constant descriptors table */
static struct centry *const_desc_first, *const_desc_last;
int const_desc_count;  

/* Some defs from rlrgint.r */
#define B            ((word)1 << DigitBits)
#define lo(d)        ((d) & (B - 1))
#define hi(d)        ((uword)(d) >> DigitBits)
#define DIG(b,i)     (&(b)->digits[(b)->msd+(i)])
#undef ceil
#define ceil(x)      ((word)((x) + 1.01))
#define ln(n)        (log((double)n))
#define bdzero(dest,l)  memset(dest, '\0', (l) * sizeof(DIGIT))

/*
 * Prototypes.
 */

static int      nalign(int n);
static void	align		(void);
static void labout(int i, char *desc);
static void	flushcode	(void);
static void	lemitproc       (void);
static void	lemitcode       (void);
static int      has_op_create(void);
static void	patchrefs       (void);
static void     lemitcon(struct centry *ce);
static void outword(word oword);
static struct centry *inst_sdescrip(char *s);


static DIGIT muli1	(DIGIT *u, word k, int c, DIGIT *w, word n);
static struct b_bignum * bigradix(char *input, int input_len);


static word pc = 0;		/* simulated program counter */


#define CodeCheck(n) if ((long)codep + (n) > (long)((long)codeb + maxcode)) \
codeb = (char *) expand_table(codeb, &codep, &maxcode, 1,                   \
                          (n), "code buffer");


static void writescript(void);
static word cnv_op(int n);
static void gentables(void);
static void synch_file(void);
static void synch_line(void);
static void *expand_table(void * table,      /* table to be realloc()ed */
                          void * tblfree,    /* reference to table free pointer if there is one */
                          size_t *size, /* size of table */
                          int unit_size,      /* number of bytes in a unit of the table */
                          int min_units,      /* the minimum number of units that must be allocated. */
                          char *tbl_name);     /* name of the table */

struct strconst {
    char *s;
    word len;
    word offset;
    struct strconst *next, *b_next;
};

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
    word ipc;             /* offset of instruction into code region */
    char *fname;          /* file name */
};

struct ipc_line {
    word ipc;           /* offset of instruction into code region */
    int line;           /* line number */
};

static struct strconst *first_strconst, *last_strconst, *strconst_hash[128];
static int strconst_offset;
static struct centry *constblock_hash[128];
static void outshortx(short s, char *fmt, ...);
static void outwordx(word oword, char *fmt, ...);
static void outwordz(word oword, char *fmt, ...);
static void outstr(struct strconst *sp, char *fmt, ...);
static void outsdescrip(struct centry *ce, char *fmt, ...);

#if WordBits == 32
#define WordFmt "%08lx"
#else
#define WordFmt "%016lx"
#endif

#define ShortFmt "%04lx"

static struct header hdr;

static int get_tcaseno(struct ir_tcaseinit *x)
{
    if (x->no < 0)
        x->no = ntcase++;
    return x->no;
}

static void out_op(word op)
{
    outwordx(op, op_names[op]);
}

static void word_field(word w, char *desc)
{
    if (Dflag)
        fprintf(dbgfile, WordFmt ":   " WordFmt "    #    %s=%ld\n", (long)pc, (long)w, desc, (long)w);
    outword(w);
}

static void emit_ir_var(struct ir_var *v, char *desc)
{
    if (!v) {
        outwordx(Op_Nil, "   %s=nil", desc);
        return;
    }

    switch (v->type) {
        case CONST: {
            struct centry *ce = v->con;
            if (ce->c_flag & F_IntLit) {
                word ival;
                memcpy(&ival, ce->data, sizeof(word));
                outwordx(Op_Int, "   %s=int", desc);
                outwordx(ival, "      %d", ival);
#if RealInDesc
            } else if (ce->c_flag & F_RealLit) {
                word ival;
                double dval;
                memcpy(&ival, ce->data, sizeof(word));
                memcpy(&dval, ce->data, sizeof(double));
                outwordx(Op_Real, "   %s=real", desc);
                outwordx(ival, "      %.*g", Precision, dval);
#endif
            } else {
                outwordx(Op_Const, "   %s=const", desc);
                outwordx(ce->desc_no, "      %d", ce->desc_no);
            }
            break;
        }
        case WORD: {
            outwordx(Op_Int, "   %s=int", desc);
            outwordx(v->w, "      %ld", (long)v->w);
            break;
        }
        case KNULL: {
            outwordx(Op_Knull, "   %s=null", desc);
            break;
        }
        case LOCAL: {
            struct lentry *le = v->local;
            if (le->l_flag & F_Static) {
                outwordx(Op_Static, "   %s=static", desc);
                outwordx(le->l_val.index, "      %d  (%s)", le->l_val.index, le->name);
            } else if (le->l_flag & F_Argument) {
                outwordx(Op_FrameVar, "   %s=framevar", desc);
                outwordx(le->l_val.index, "      %d (%s)", le->l_val.index, le->name);
            } else {
                outwordx(Op_FrameVar, "   %s=framevar", desc);
                outwordx(curr_lfunc->narguments + le->l_val.index, "      %d  (%s)", 
                         curr_lfunc->narguments + le->l_val.index, le->name);
            }
            break;
        }
        case GLOBAL: {
            struct gentry *ge = v->global;
            if ((ge->g_flag & (F_Builtin|F_Proc|F_Record|F_Class)) == 0)
                outwordx(Op_Global, "   %s=global", desc);
            else
                outwordx(Op_NamedGlobal, "   %s=namedglobal", desc);
            outwordx(ge->g_index, "      %d (%s)", ge->g_index, ge->name);
            break;
        }
        case TMP: {
            outwordx(Op_Tmp, "   %s=tmp", desc);
            outwordx(v->index, "      %d", v->index);
            break;
        }
        default: {
            quit("emit_ir_var:Unknown type");
        }
    }
}

static struct centry *inst_sdescrip(char *s)
{
    int i;
    struct centry *p;

    /*
     * Search for an existing entry with the same string data
     */
    i = hasher(s, constblock_hash);
    p = constblock_hash[i];
    while (p && (p->data != s || p->c_flag != F_StrLit))
        p = p->b_next;
    if (!p) {
        /*
         * Create a new centry and add it
         */
        p = Alloc(struct centry);
        p->c_flag = F_StrLit;
        p->data = s;
        p->length = strlen(s);
        p->b_next = constblock_hash[i];
        constblock_hash[i] = p;
        /*
         * Add to constant descriptor table list and set desc_no
         */
        if (const_desc_last) {
            const_desc_last->d_next = p;
            const_desc_last = p;
        } else
            const_desc_first = const_desc_last = p;
        p->desc_no = const_desc_count++;
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

static void gencode_func(struct lfunction *f);
static void gencode(void);

void generate_code()
{
    int i;

    /*
     * Open the output file.
     */
    outfile = fopen(ofile, WriteBinary);
    if (outfile == NULL)
        quit("cannot create %s",ofile);

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
    curr_file = last_fnmtbl_filen = 0;
    curr_line = last_lntable_line = 0;

    /*
     * Initialize some dynamically-sized tables.
     */
    lnfree = lntable = safe_calloc(nsize, sizeof(struct ipc_line));
    fnmfree = fnmtbl = safe_calloc(fnmsize, sizeof(struct ipc_fname));
    codep = codeb = safe_calloc(maxcode, 1);

    /*
     * This ensures empty strings point to the start of the string region,
     * which is a bit tidier than pointing to some arbitrary offset.
     */
    inst_strconst(empty_string, 0);

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
                if (me->func && !(me->flag & (M_Defer | M_Abstract | M_Native))) 
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
    fnmfree->fname = curr_file;
    fnmfree++;
}

static void synch_line()
{
    if (loclevel == 0)
        return;

    /*
     * Avoid adjacent entries with the same name.
     */
    if (curr_line == last_lntable_line)
        return;

    if (lnfree >= &lntable[nsize])
        lntable  = (struct ipc_line *)expand_table(lntable, &lnfree, &nsize,
                                               sizeof(struct ipc_line), 1, "line number table");
    last_lntable_line = curr_line;
    lnfree->ipc = pc;
    lnfree->line = curr_line;
    lnfree++;
}


/* Same as in rstructs.h */
#if !RealInDesc
struct b_real {			/* real block */
    word title;			/*   T_Real */
#if DOUBLE_HAS_WORD_ALIGNMENT
    double realval;		/*   value */
#else
    word realval[DoubleWords];
#endif
};
#endif

struct b_bignum {		/* large integer block */
    word title;			/*   T_Lrgint */
    word blksize;		/*   block size */
    word msd, lsd;		/*   most and least significant digits */
    int sign;			/*   sign; 0 positive, 1 negative */
    DIGIT digits[1];		/*   digits */
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

#if RealInDesc
    if (ce->c_flag & F_RealLit)
        return;
#endif

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
        struct b_bignum *bn;
        word *p;
        ce->pc = pc;
        bn = bigradix(ce->data, ce->length);
        if (!bn)
            quit("unable to parse bignum data");
        if (bn->blksize % WordSize != 0)
            quit("bigint blksize wrong");
        outwordx(T_Lrgint, "T_Lrgint");
        outwordx(bn->blksize, "   Blksize");
        p = ((word *)bn) + 2;
        for (i = 2; i < bn->blksize / sizeof(word); ++i)
            outwordx(*p++, "   Large integer data");
        free(bn);
    } else if (ce->c_flag & F_RealLit) {
#if !RealInDesc
        static struct b_real d;
        int i;
        word *p;
        double dval;
        ce->pc = pc;
        d.title = T_Real;
        memcpy(&d.realval, ce->data, sizeof(double));
        memcpy(&dval, ce->data, sizeof(double));
        outwordx(T_Real, "T_Real");
        p = (word *)&d + 1;
        outwordx(*p++, "   Double data (%.*g)", Precision, dval);
        for (i = 2; i < sizeof(d) / sizeof(word); ++i)
            outwordx(*p++, "   Double data");
#endif
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

        outwordx(T_Cset, "T_Cset");
        outwordx((CsetSize + 4 + 3 * npair) * WordSize, "   Block size");
        outwordx(size, "   Cset size");
        for (i = 0; i < CsetSize; ++i)
            outwordx(csbuf[i], "   Binary map");
        outwordx(npair, "   Npair");
        x = 0;
        for (i = 0; i < npair; ++i) {
            outwordx(x, "   Index");
            outwordx(pair[i].from, "   From");
            outwordx(pair[i].to, "   To");
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

        outwordx(T_Ucs, "T_Ucs");
        outwordx((7 + n_offs) * WordSize, "   Block size");
        outwordx(length, "   Length");
        outstr(utf8, "   UTF8 string");
        outwordx(n_offs, "   N indexed");
        outwordx(index_step, "   Index step");

        /* This mirrors the loop in fmisc.r (get_ucs_off) */
        p = utf8->s;
        i = 0;
        while (i < length - 1) {
            p += UTF8_SEQ_LEN(*p);
            ++i;
            if (i % index_step == 0) {
                outwordx(p - utf8->s,   "Off of char %d", i);
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
            word t, off;
            memcpy(&t, &codeb[p - basepc], WordSize);
            off = chunk->pc - p;
            memcpy(&codeb[p - basepc], &off, WordSize);
            p = t;
        }
    }
}

static int has_op_create()
{
    int i, j;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        chunk = chunks[i];
        if (!chunk)
            continue;
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            if (ir->op == Ir_Create)
                return 1;
        }
    }
    return 0;
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
            fprintf(dbgfile, "# Chunk %d\n", i);
        for (j = 0; j < chunk->n_inst; ++j) {
            struct ir *ir = chunk->inst[j];
            struct lnode *n = ir->node;
            if (n) {
                curr_file = n->loc.file;
                curr_line = n->loc.line;
                synch_file();
                synch_line();
            }

            switch (ir->op) {
                case Ir_Goto: {
                    struct ir_goto *x = (struct ir_goto *)ir;
                    out_op(Op_Goto);
                    labout(x->dest, "dest");
                    break;
                }
                case Ir_IGoto: {
                    struct ir_igoto *x = (struct ir_igoto *)ir;
                    out_op(Op_IGoto);
                    word_field(x->no, "labno");
                    break;
                }
                case Ir_EnterInit: {
                    struct ir_enterinit *x = (struct ir_enterinit *)ir;
                    out_op(Op_EnterInit);
                    labout(x->dest, "dest");
                    break;
                }
                case Ir_Fail: {
                    out_op(Op_Fail);
                    break;
                }
                case Ir_SysErr: {
                    out_op(Op_SysErr);
                    break;
                }
                case Ir_Suspend: {
                    struct ir_suspend *x = (struct ir_suspend *)ir;
                    out_op(Op_Suspend);
                    emit_ir_var(x->val, "val");
                    break;
                }
                case Ir_Return: {
                    struct ir_return *x = (struct ir_return *)ir;
                    out_op(Op_Return);
                    emit_ir_var(x->val, "val");
                    break;
                }
                case Ir_Mark: {
                    struct ir_mark *x = (struct ir_mark *)ir;
                    out_op(Op_Mark);
                    word_field(x->no, "no");
                    break;
                }
                case Ir_Unmark: {
                    struct ir_unmark *x = (struct ir_unmark *)ir;
                    out_op(Op_Unmark);
                    word_field(x->no, "no");
                    break;
                }
                case Ir_Move: {
                    struct ir_move *x = (struct ir_move *)ir;
                    out_op(Op_Move);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->rhs, "rhs");
                    break;
                }
                case Ir_Deref: {
                    struct ir_deref *x = (struct ir_deref *)ir;
                    out_op(Op_Deref);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->rhs, "rhs");
                    break;
                }
                case Ir_MoveLabel: {
                    struct ir_movelabel *x = (struct ir_movelabel *)ir;
                    out_op(Op_MoveLabel);
                    word_field(x->destno, "destno");
                    labout(x->lab, "lab");
                    break;
                }
                case Ir_Op: {
                    struct ir_op *x = (struct ir_op *)ir;
                    word op = cnv_op(x->operation);
                    out_op(op);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    if (x->arg2)
                        emit_ir_var(x->arg2, "arg2");
                    if (x->arg3)
                        emit_ir_var(x->arg3, "arg3");
                    if (x->operation == Uop_Subsc ||
                        x->operation == Uop_Random ||
                        x->operation == Uop_Sect)
                        word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_MgOp: {
                    struct ir_mgop *x = (struct ir_mgop *)ir;
                    word op = cnv_op(x->operation);
                    out_op(op);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    if (x->arg2)
                        emit_ir_var(x->arg2, "arg2");
                    break;
                }
                case Ir_OpClo: {
                    struct ir_opclo *x = (struct ir_opclo *)ir;
                    word op = cnv_op(x->operation);
                    out_op(op);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    if (x->arg2)
                        emit_ir_var(x->arg2, "arg2");
                    if (x->arg3)
                        emit_ir_var(x->arg3, "arg3");
                    word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_KeyOp: {
                    struct ir_keyop *x = (struct ir_keyop *)ir;
                    out_op(Op_Keyop);
                    word_field(x->keyword, "keyword");
                    emit_ir_var(x->lhs, "lhs");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    out_op(Op_Keyclo);
                    word_field(x->keyword, "keyword");
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_Invoke: {
                    struct ir_invoke *x = (struct ir_invoke *)ir;
                    int i;
                    out_op(Op_Invoke);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->expr, "expr");
                    word_field(x->argc, "argc");
                    word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    for (i = 0; i < x->argc; ++i) 
                        emit_ir_var(x->args[i], "arg");
                    break;
                }
                case Ir_Invokef: {
                    struct ir_invokef *x = (struct ir_invokef *)ir;
                    int i;
                    out_op(Op_Invokef);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->expr, "expr");
                    outwordx(x->ftab_entry->field_id, "   field number=%ld (%s)", (long)x->ftab_entry->field_id, x->ftab_entry->name); 
                    word_field(0, "inline cache");
                    word_field(0, "inline cache");
                    word_field(x->argc, "argc");
                    word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    for (i = 0; i < x->argc; ++i) 
                        emit_ir_var(x->args[i], "arg");
                    break;
                }
                case Ir_Apply: {
                    struct ir_apply *x = (struct ir_apply *)ir;
                    out_op(Op_Apply);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    emit_ir_var(x->arg2, "arg2");
                    word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_Applyf: {
                    struct ir_applyf *x = (struct ir_applyf *)ir;
                    out_op(Op_Applyf);
                    word_field(x->clo, "clo");
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->arg1, "arg1");
                    outwordx(x->ftab_entry->field_id, "   field number=%ld (%s)", (long)x->ftab_entry->field_id, x->ftab_entry->name); 
                    word_field(0, "inline cache");
                    word_field(0, "inline cache");
                    emit_ir_var(x->arg2, "arg2");
                    word_field(x->rval, "rval");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_Field: {
                    struct ir_field *x = (struct ir_field *)ir;
                    out_op(Op_Field);
                    emit_ir_var(x->lhs, "lhs");
                    emit_ir_var(x->expr, "expr");
                    outwordx(x->ftab_entry->field_id, "   field number=%ld (%s)", (long)x->ftab_entry->field_id, x->ftab_entry->name); 
                    word_field(0, "inline cache");
                    word_field(0, "inline cache");
                    break;
                }
                case Ir_Resume: {
                    struct ir_resume *x = (struct ir_resume *)ir;
                    out_op(Op_Resume);
                    word_field(x->clo, "clo");
                    break;
                }
                case Ir_ScanSwap: {
                    struct ir_scanswap *x = (struct ir_scanswap *)ir;
                    out_op(Op_ScanSwap);
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }
                case Ir_ScanSave: {
                    struct ir_scansave *x = (struct ir_scansave *)ir;
                    out_op(Op_ScanSave);
                    emit_ir_var(x->new_subject, "new_subject");
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }
                case Ir_ScanRestore: {
                    struct ir_scanrestore *x = (struct ir_scanrestore *)ir;
                    out_op(Op_ScanRestore);
                    word_field(x->tmp_subject->index, "tmp_subject");
                    word_field(x->tmp_pos->index, "tmp_pos");
                    break;
                }
                case Ir_MakeList: {
                    struct ir_makelist *x = (struct ir_makelist *)ir;
                    int i;
                    out_op(Op_MakeList);
                    emit_ir_var(x->lhs, "lhs");
                    word_field(x->argc, "argc");
                    for (i = 0; i < x->argc; ++i) 
                        emit_ir_var(x->args[i], "arg");
                    break;
                }
                case Ir_Create: {
                    struct ir_create *x = (struct ir_create *)ir;
                    out_op(Op_Create);
                    emit_ir_var(x->lhs, "lhs");
                    labout(x->start_label, "start");
                    break;
                }
                case Ir_Coret: {
                    struct ir_coret *x = (struct ir_coret *)ir;
                    out_op(Op_Coret);
                    emit_ir_var(x->value, "value");
                    break;
                }
                case Ir_Cofail: {
                    out_op(Op_Cofail);
                    break;
                }
                case Ir_Limit: {
                    struct ir_limit *x = (struct ir_limit *)ir;
                    out_op(Op_Limit);
                    emit_ir_var(x->limit, "limit");
                    break;
                }
                case Ir_TCaseInit: {
                    struct ir_tcaseinit *x = (struct ir_tcaseinit *)ir;
                    out_op(Op_TCaseInit);
                    word_field(get_tcaseno(x), "no");
                    word_field(x->def, "def");
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    out_op(Op_TCaseInsert);
                    word_field(get_tcaseno(x->tci), "no");
                    emit_ir_var(x->val, "val");
                    word_field(x->entry, "entry");
                    break;
                }
                case Ir_TCaseChoose: {
                    struct ir_tcasechoose *x = (struct ir_tcasechoose *)ir;
                    int i;
                    out_op(Op_TCaseChoose);
                    word_field(get_tcaseno(x->tci), "no");
                    emit_ir_var(x->val, "val");
                    word_field(x->tblc, "tblc");
                    for (i = 0; i < x->tblc; ++i)
                        labout(x->tbl[i], "dest");
                    break;
                }
                case Ir_TCaseChoosex: {
                    struct ir_tcasechoosex *x = (struct ir_tcasechoosex *)ir;
                    int i;
                    out_op(Op_TCaseChoosex);
                    word_field(get_tcaseno(x->tci), "no");
                    emit_ir_var(x->val, "val");
                    word_field(x->labno, "labno");
                    word_field(x->tblc, "tblc");
                    for (i = 0; i < x->tblc; ++i)
                        labout(x->tbl[i], "dest");
                    break;
                }
                default: {
                    quit("lemitcode: illegal ir opcode(%d)\n", ir->op);
                    break;
                }
            }
        }
    }
    out_op(Op_EndProc);
}


static void lemitproc()
{
    char *p;
    int size, ap;
    struct lentry *le;
    struct centry *ce;

    size = (19*WordSize) + WordSize * (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics);
    if (loclevel > 1)
        size += 2*WordSize * (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics);

    if (curr_lfunc->proc)
        p = curr_lfunc->proc->name;
    else
        p = curr_lfunc->method->name;

    ce = inst_sdescrip(p);

    outwordx(T_Proc, "T_Proc");
    outwordx(P_Proc, "   Type");
    outwordx(curr_lfunc->narguments, "   Num args");
    outwordx(curr_lfunc->vararg, "   Vararg flag");
    outwordx(0, "   Field");
    outsdescrip(ce, "   Procedure name (%s)", p);
    outwordx(curr_lfunc->pc + size, "   Entry point");
    outwordx(has_op_create(), "   Creates flag");
    outwordx(curr_lfunc->ndynamic, "   Num dynamic");
    outwordx(curr_lfunc->nstatics, "   Num static");
    outwordx(nstatics, "   First static");
    outwordx(0, "   Owning prog");
    outwordx(n_clo, "   Num closures");
    outwordx(n_tmp, "   Num temporaries");
    outwordx(n_lab, "   Num labels");
    outwordx(n_mark, "   Num marks");
    outwordx(curr_lfunc->defined->package_id, "   Package id");

    /*
     * Pointers to the tables that follow.
     */
    ap = pc + 2 * WordSize;
    outwordz(ap, "   Pointer to local names array");
    ap += (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics) * WordSize;
    if (loclevel > 1) {
        outwordz(ap, "   Pointer to local locations array");
        ap += (curr_lfunc->narguments + curr_lfunc->ndynamic + curr_lfunc->nstatics) * 2 * WordSize;
    } else
        outwordz(0, "   Pointer to local locations array");

    /*
     * Names array.  Loop through the list of locals three times to get the output
     * in the correct order.
     */
    if (Dflag)
        fprintf(dbgfile, "# Local names array\n");
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Argument) {
            ce = inst_sdescrip(le->name);
            outsdescrip(ce, "Local name (arg %s)", le->name);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Dynamic) {
            ce = inst_sdescrip(le->name);
            outsdescrip(ce, "Local name (dynamic %s)", le->name);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Static) {
            ce = inst_sdescrip(le->name);
            le->l_val.index = nstatics++;
            outsdescrip(ce, "Local name (static %s)", le->name);
        }
    }

    if (loclevel > 1) {
        /*
         * Local locations
         */
        if (Dflag)
            fprintf(dbgfile, "# Local locations array\n");
        for (le = curr_lfunc->locals; le; le = le->next) {
            if (le->l_flag & F_Argument) {
                ce = inst_sdescrip(le->pos.file);
                outsdescrip(ce, "File %s", le->pos.file);
                outwordx(le->pos.line, "Line %d", le->pos.line);
            }
        }
        for (le = curr_lfunc->locals; le; le = le->next) {
            if (le->l_flag & F_Dynamic) {
                ce = inst_sdescrip(le->pos.file);
                outsdescrip(ce, "File %s", le->pos.file);
                outwordx(le->pos.line, "Line %d", le->pos.line);
            }
        }
        for (le = curr_lfunc->locals; le; le = le->next) {
            if (le->l_flag & F_Static) {
                ce = inst_sdescrip(le->pos.file);
                outsdescrip(ce, "File %s", le->pos.file);
                outwordx(le->pos.line, "Line %d", le->pos.line);
            }
        }
    }

    /* Check our calculations were right */
    if (ap != pc)
        quit("I got my sums wrong(d): %d != %d", ap, pc);

    if (curr_lfunc->pc + size != pc)
        quit("I got my sums wrong(e): %d != %d", curr_lfunc->pc + size, pc);
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
    struct centry *ce;
    word p;

    if (cl->pc != pc)
        quit("I got my sums wrong(a): %d != %d", pc, cl->pc);
    
    name = cl->global->name;
    ce = inst_sdescrip(name);

    n_fields = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;

    if (Dflag)
        fprintf(dbgfile, "\n# class %s\n", name);

    outwordx(T_Class, "T_Class");		/* type code */
    outwordx(0, "   Owning prog");
    outwordx(cl->global->defined->package_id, "   Package id");
    outwordx(0, "   Instance id counter");
    outwordx(Uninitialized, "   Initialization state");
    outwordx(cl->flag, "   Flags");
    outwordx(cl->n_supers, "   Nsupers");
    outwordx(cl->n_implemented_classes, "   Nimplemented");
    outwordx(cl->n_implemented_instance_fields, "   Ninstancefields");
    outwordx(cl->n_implemented_class_fields, "   Nclassfields");
    outsdescrip(ce, "   Class name");

    i = hasher(init_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != init_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;

    outwordz(p, "   Pointer to init field");

    i = hasher(new_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != new_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;

    outwordz(p, "   Pointer to new field");

    /*
     * Pointers to the tables that follow.
     */

    ap = pc + 4 * WordSize;
    outwordz(ap, "   Pointer to superclass array");
    ap += cl->n_supers * WordSize;
    outwordz(ap, "   Pointer to implemented classes array");
    ap += cl->n_implemented_classes * WordSize;
    outwordz(ap, "   Pointer to field info array");
    ap += n_fields * WordSize;
    outwordz(ap, "   Pointer to field sort array");
    ap += n_fields * sizeof(short);
    ap += nalign(ap);

    /*
     * Superclass array.
     */
    for (cr = cl->resolved_supers; cr; cr = cr->next)
        outwordz(cr->class->pc, "   Pointer to superclass %s", cr->class->global->name);

    /*
     * Implemented classes array.  They are sorted by ascending class id number.
     */
    ic_sort = sorted_implemented_classes(cl);
    for (i = 0; i < cl->n_implemented_classes; ++i)
        outwordz(ic_sort[i]->pc, "   Pointer to implemented class %s", ic_sort[i]->global->name);
    free(ic_sort);

    /* 
     * An array of pointers to the field info of each field 
     */
    if (Dflag)
        fprintf(dbgfile, "# Field info array\n");

    for (fr = cl->implemented_instance_fields; fr; fr = fr->next)
        outwordz(fr->field->ipc, "   Info for field %s", fr->field->name);
    for (fr = cl->implemented_class_fields; fr; fr = fr->next)
        outwordz(fr->field->ipc, "   Info for field %s", fr->field->name);

    /* 
     * The sorted fields table.
     */
    sortf = sorted_fields(cl);
    if (Dflag)
        fprintf(dbgfile, "# Sorted fields array\n");

    for (i = 0; i < n_fields; ++i)
        outshortx((short)sortf[i].n, "   Field %s (fnum=%d)", sortf[i].fp->name, sortf[i].fp->field_id);
    free(sortf);

    align();

    /* Check our calculations were right */
    if (ap != pc)
        quit("I got my sums wrong(b): %d != %d", ap, pc);
    if (cl->pc + cl->size != pc)
        quit("I got my sums wrong(c): %d != %d", cl->pc + cl->size, pc);

    flushcode();
}

static void genclasses(void)
{
    struct lclass *cl;
    struct lclass_field *cf;
    int x, n_classes = 0, n_fields = 0;
    struct centry *ce;

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
                cf->dpc = pc;
                outwordx(D_Null, "D_Null, Static var %s.%s", cl->global->name, cf->name);
                outwordx(0, "");
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
            if (cf->flag & (M_Defer | M_Abstract | M_Native)) {
                /* Deferred method, perhaps resolved to native method */
                cf->dpc = pc;
                outwordx(D_Proc, "D_Proc, Deferred method %s.%s", cl->global->name, cf->name);
                outwordx(cf->func->native_method_id, "   Native method id");
            } else if (cf->flag & M_Method) {
                /* Method, with definition in the icode file  */
                cf->dpc = pc;
                outwordx(D_Proc, "D_Proc, Method %s.%s", cl->global->name, cf->name);
                outwordz(cf->func->pc, "   Block");
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
        x += WordSize * 2 * n_fields;        /* The optional classfieldlocs table */

    for (cl = lclasses; cl; cl = cl->next) {
        int n_fields = cl->n_implemented_class_fields + cl->n_implemented_instance_fields;
        cl->pc = x;
        cl->size = WordSize * (16 +
                               1 + 
                               cl->n_supers +
                               cl->n_implemented_classes +
                               n_fields) + 
            sizeof(short) * n_fields;

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
            if (Dflag)
                fprintf(dbgfile, "# Field info for %s.%s\n", cl->global->name, cf->name);
            outwordx(cf->ftab_entry->field_id, "Fnum");
            outwordx(cf->flag, "Flags");
            outwordz(cf->class->pc, "Defining class");
            outwordz(cf->dpc, "Pointer to descriptor");
        }
    }

    align();
    hdr.ClassFieldLocs = pc;
    if (Dflag)
        fprintf(dbgfile, "\n# class field location table\n");
    if (loclevel > 1) {
        for (cl = lclasses; cl; cl = cl->next) {
            for (cf = cl->fields; cf; cf = cf->next) {
                ce = inst_sdescrip(cf->pos.file);
                outsdescrip(ce, "File %s", cf->pos.file);
                outwordx(cf->pos.line, "Line %d", cf->pos.line);
            }
        }
    }

    align();
    hdr.Classes = pc;

    if (Dflag)
        fprintf(dbgfile, "\n");

    outwordx(n_classes, "Num class blocks");

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
    struct strconst *sp;
    struct ipc_fname *fnptr;
    struct ipc_line *lnptr;
    struct centry *ce;
    word w;

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

    if (Dflag)
        fprintf(dbgfile, "\n");

    outwordx(nrecords, "Num constructor blocks");

    for (rec = lrecords; rec; rec = rec->next) {
        struct field_sort_item *sortf;
        int ap, size;
        s = rec->global->name;
        rec->pc = pc;
        ce = inst_sdescrip(s);
        size = 9 * WordSize + rec->nfields * (WordSize + sizeof(short));
        if (loclevel > 1)
            size += rec->nfields * 2 * WordSize;
        size += nalign(size);

        if (Dflag)
            fprintf(dbgfile, "\n# constructor %s\n", s);

        outwordx(T_Constructor, "T_Constructor");		/* type code */
        outwordx(0, "   Owning prog");
        outwordx(rec->global->defined->package_id, "   Package id");
        outwordx(0, "   Instance id counter");
        outwordx(rec->nfields, "   Num fields");
        outsdescrip(ce, "   Name of record");

        /*
         * Pointers to the three tables that follow.
         */
        ap = pc + 3 * WordSize;
        outwordz(ap, "   Pointer to fnums array");
        ap += rec->nfields * WordSize;
        if (loclevel > 1) {
            outwordz(ap, "   Pointer to field_locs array");
            ap += rec->nfields * 2 * WordSize;
        } else
            outwordz(0, "   Pointer to field_locs array");
        outwordz(ap, "   Pointer to field sort array");
        ap += rec->nfields * sizeof(short);
        ap += nalign(ap);

        /*
         * Field nums
         */
        if (Dflag)
            fprintf(dbgfile, "# Fnums array\n");
        for (fd = rec->fields; fd; fd = fd->next) 
            outwordx(fd->ftab_entry->field_id, "   Fnum %d", fd->ftab_entry->field_id);

        /*
         * Field locations, if selected
         */
        if (loclevel > 1) {
            if (Dflag)
                fprintf(dbgfile, "# Field locations array\n");
            for (fd = rec->fields; fd; fd = fd->next) {
                ce = inst_sdescrip(fd->pos.file);
                outsdescrip(ce, "File %s", fd->pos.file);
                outwordx(fd->pos.line, "Line %d", fd->pos.line);
            }
        }

        /* 
         * The sorted fields table.
         */
        sortf = sorted_record_fields(rec);
        if (Dflag) 
            fprintf(dbgfile, "# Sorted fields array\n");

        for (i = 0; i < rec->nfields; ++i)
            outshortx((short)sortf[i].n, "   Field %s (fnum=%d)", sortf[i].fp->name, sortf[i].fp->field_id);
        free(sortf);

        align();

        /* Check our calculations were right */
        if (ap != pc)
            quit("I got my sums wrong(d): %d != %d", ap, pc);
        if (rec->pc + size != pc)
            quit("I got my sums wrong(e): %d != %d", rec->pc + size, pc);

        flushcode();
    }

    /*
     * Output descriptors for field names.
     */
    align();
    if (Dflag)
        fprintf(dbgfile, "\n# Field names table\n");
    hdr.Fnames = pc;
    for (fp = lffirst; fp; fp = fp->next) {
        ce = inst_sdescrip(fp->name);
        outsdescrip(ce, "Field %s", fp->name);
    }
    flushcode();

    /*
     * Output global variable descriptors.
     */
    hdr.Globals = pc;
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable descriptors\n");
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->g_flag & F_Builtin) {		/* function */
            outwordx(D_Proc, "D_Proc, global %s", gp->name);
            outwordx(-gp->builtin->builtin_id - 1, "   Builtin id (%d)", -gp->builtin->builtin_id - 1);
        }
        else if (gp->g_flag & F_Proc) {		/* Icon procedure */
            outwordx(D_Proc, "D_Proc, global %s", gp->name);
            outwordz(gp->func->pc, "   Block");
        }
        else if (gp->g_flag & F_Record) {		/* record constructor */
            outwordx(D_Constructor, "D_Constructor, global %s", gp->name);
            outwordz(gp->record->pc, "   Block");
        }
        else if (gp->g_flag & F_Class) {		/* class */
            outwordx(D_Class, "D_Class, global %s", gp->name);
            outwordz(gp->class->pc, "   Block");
        }
        else {					/* simple global variable */
            outwordx(D_Null, "D_Null, global %s", gp->name);
            outwordx(0, "");
        }
    }
    flushcode();

    /*
     * Output descriptors for global variable names.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable names\n");
    hdr.Gnames = pc;
    for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
        ce = inst_sdescrip(gp->name);
        outsdescrip(ce, "%s", gp->name);
    }
    flushcode();

    /*
     * Output bitmap for global variable package flags.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable package flag bitmap\n");
    hdr.GpackageFlags = pc;
    w = i = 0;
    for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
        if (gp->g_flag & F_Package)
            w |= ((word)1 << i);
        ++i;
        if (i == WordBits) {
            outwordx(w, "map");
            w = i = 0;
        }
    }
    if (i > 0)
        outwordx(w, "map");
    flushcode();

    /*
     * Output locations for global variables.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable locations\n");
    hdr.Glocs = pc;
    if (loclevel > 1) {
        for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
            if (gp->g_flag & F_Builtin) {
                outwordx(0, "%s: Builtin", gp->name);
                outwordx(0, "");
            } else {
                ce = inst_sdescrip(gp->pos.file);
                outsdescrip(ce, "%s File %s", gp->name, gp->pos.file);
                outwordx(gp->pos.line, "Line %d", gp->pos.line);
            }
        }
    }
    flushcode();

    /*
     * Output a null descriptor for each static variable.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Static variable null descriptors\n");
    hdr.Statics = pc;
    for (i = 0; i < nstatics; ++i) {
        outwordx(D_Null, "D_Null");
        outwordx(0, "");
    }
    flushcode();

    /*
     * Output a null descriptor for each tcase table.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# TCase table null descriptors\n");
    hdr.TCaseTables = pc;
    for (i = 0; i < ntcase; ++i) {
        outwordx(D_Null, "D_Null");
        outwordx(0, "");
    }
    flushcode();

    if (Dflag)
        fprintf(dbgfile, "\n# File names table\n");
    hdr.Filenms = pc;
    for (fnptr = fnmtbl; fnptr < fnmfree; fnptr++) {
        ce = inst_sdescrip(fnptr->fname);
        outwordx(fnptr->ipc, "IPC");
        outsdescrip(ce, "   File %s", fnptr->fname);
    }
    flushcode();

    if (Dflag)
        fprintf(dbgfile, "\n# Line number table\n");
    hdr.linenums = pc;
    for (lnptr = lntable; lnptr < lnfree; lnptr++) {
        outwordx(lnptr->ipc, "IPC");
        outwordx(lnptr->line, "   Line %d", lnptr->line);        
    }
    flushcode();

    if (Dflag)
        fprintf(dbgfile, "\n# Constant descriptors\n");
    hdr.Constants = pc;
    i = 0;
    for (ce = const_desc_first; ce; ce = ce->d_next) {
        if (Dflag)
            fprintf(dbgfile, "# Entry %04x\n", i++);
        if (ce->c_flag & F_IntLit) {
            word ival;
            memcpy(&ival, ce->data, sizeof(word));
            outwordx(D_Integer, "D_Integer");
            outwordx(ival, "   %ld", (long)ival);
        } else if (ce->c_flag & F_StrLit) {
            struct strconst *sp = inst_strconst(ce->data, ce->length);
            outstr(sp, "String");
        } else if (ce->c_flag & F_LrgintLit) {
            outwordx(D_Lrgint, "D_Lrgint");
            outwordz(ce->pc, "   Block");
        } else if (ce->c_flag & F_RealLit) {
            outwordx(D_Real, "D_Real");
            outwordz(ce->pc, "   Block");
        } else if (ce->c_flag & F_CsetLit) {
            outwordx(D_Cset, "D_Cset");
            outwordz(ce->pc, "   Block");
        } else if (ce->c_flag & F_UcsLit) {
            outwordx(D_Ucs, "D_Ucs");
            outwordz(ce->pc, "   Block");
        } else
            quit("unknown constant type");
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
                fprintf(dbgfile, "# Offset %04lx\n", (long)sp->offset);
                for (i = 0; i < sp->len; ++i) {
                    if (i == 0)
                        fprintf(dbgfile, WordFmt ":    ", (long)pc);
                    else if (i % 8 == 0) {
                        t[j] = 0;
                        fprintf(dbgfile, "   %s\n" WordFmt ":    ", t, (long)pc + i);
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
    flushcode();

    /*
     * Output icode file header.
     */
    hdr.icodesize = pc;
    strcpy((char *)hdr.config,IVersion);

    if (Dflag) {
        fprintf(dbgfile, "\n");
        fprintf(dbgfile, "icodesize:        " WordFmt "\n", (long)hdr.icodesize);
        fprintf(dbgfile, "class statics:    " WordFmt "\n", (long)hdr.ClassStatics);
        fprintf(dbgfile, "class methods:    " WordFmt "\n", (long)hdr.ClassMethods);
        fprintf(dbgfile, "class fields:     " WordFmt "\n", (long)hdr.ClassFields);
        fprintf(dbgfile, "class field locs: " WordFmt "\n", (long)hdr.ClassFieldLocs);
        fprintf(dbgfile, "classes:          " WordFmt "\n", (long)hdr.Classes);
        fprintf(dbgfile, "records:          " WordFmt "\n", (long)hdr.Records);
        fprintf(dbgfile, "fnames:           " WordFmt "\n", (long)hdr.Fnames);
        fprintf(dbgfile, "globals:          " WordFmt "\n", (long)hdr.Globals);
        fprintf(dbgfile, "gnames:           " WordFmt "\n", (long)hdr.Gnames);
        fprintf(dbgfile, "gpackageflags:    " WordFmt "\n", (long)hdr.GpackageFlags);
        fprintf(dbgfile, "glocs:            " WordFmt "\n", (long)hdr.Glocs);
        fprintf(dbgfile, "statics:          " WordFmt "\n", (long)hdr.Statics);
        fprintf(dbgfile, "tcasetables:      " WordFmt "\n", (long)hdr.TCaseTables);
        fprintf(dbgfile, "filenms:          " WordFmt "\n", (long)hdr.Filenms);
        fprintf(dbgfile, "linenums:         " WordFmt "\n", (long)hdr.linenums);
        fprintf(dbgfile, "constants:        " WordFmt "\n", (long)hdr.Constants);
        fprintf(dbgfile, "strcons:          " WordFmt "\n", (long)hdr.Strcons);
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
        report("  Global names    %7ld", (long)(hdr.GpackageFlags - hdr.Gnames));
        report("  Global pk flags %7ld", (long)(hdr.Glocs - hdr.GpackageFlags));
        report("  Global locs     %7ld", (long)(hdr.Statics - hdr.Glocs));
        report("  Statics         %7ld", (long)(hdr.TCaseTables - hdr.Statics));
        report("  TCaseTables     %7ld", (long)(hdr.Filenms - hdr.TCaseTables));
        report("  Filenms         %7ld", (long)(hdr.linenums - hdr.Filenms));
        report("  Linenums        %7ld", (long)(hdr.Constants - hdr.linenums));
        report("  Constants       %7ld", (long)(hdr.Strcons - hdr.Constants));
        report("  Strings         %7ld", (long)(hdr.icodesize - hdr.Strcons));
        report("  Total           %7ld", (long)tsize);
    }
}

/*
 * align() outputs zeroes as padding until pc is a multiple of WordSize.
 */
static void align()
{
    int i, n = pc % WordSize;
    if (n == 0)
        return;

    n = WordSize - n;
    if (Dflag) {
        for (i = 0; i < n; ++i)
            fprintf(dbgfile, WordFmt ":   00          # Padding byte\n", (long)pc + i);
    }
    CodeCheck(n);
    for (i = 0; i < n; ++i)
        *codep++ = 0;
    pc += n;
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

static void outstr(struct strconst *sp, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, WordFmt ":   " WordFmt "    # ", (long)pc, (long)sp->len);
        vfprintf(dbgfile, fmt, ap);
        fprintf(dbgfile, "\n" WordFmt ": S+" WordFmt "    #    \"%s\"\n", 
                         (long)pc + WordSize, (long)sp->offset, sp->s);
        va_end(ap);
    }

    CodeCheck(2 * WordSize);
    memcpy(codep, &sp->len, WordSize);
    codep += WordSize;
    memcpy(codep, &sp->offset, WordSize);
    codep += WordSize;
    pc += 2 * WordSize;
}


/*
 * wordout(i) outputs i as a word that is used by the runtime system
 *  WordSize bytes must be moved from &oword[0] to &codep[0].
 */
static void outwordx(word oword, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, WordFmt ":   " WordFmt "    # ", (long)pc, (long)oword);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    outword(oword);
}

static void outshortx(short s, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, WordFmt ":   " ShortFmt "        # ", (long)pc, (long)s);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    CodeCheck(sizeof(short));
    memcpy(codep, &s, sizeof(short));
    codep += sizeof(short);
    pc += sizeof(short);
}

static void outwordz(word oword, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, WordFmt ": Z+" WordFmt "    # ", (long)pc, (long)oword);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    outword(oword);
}

static void outsdescrip(struct centry *ce, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, WordFmt ": C[" WordFmt "]   # ", (long)pc, (long)ce->desc_no);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    outword(ce->desc_no);
}

/*
 * wordout(i) outputs i as a word that is used by the runtime system
 *  WordSize bytes must be moved from &oword[0] to &codep[0].
 */
static void outword(word oword)
{
    CodeCheck(WordSize);
    memcpy(codep, &oword, WordSize);
    codep += WordSize;
    pc += WordSize;
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

static void labout(int i, char *desc)
{
    struct chunk *chunk = chunks[i];
    word t = pc;
    if (Dflag)
        fprintf(dbgfile, WordFmt ":   " WordFmt "    #    %s=chunk %d\n", (long)pc, (long)0, desc, i);
    if (!chunk)
        quit("Missing chunk: %d\n", i);
    outword(chunk->refs);
    chunk->refs = t;
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
    new_size = *size * 2;
    if (new_size - *size < min_units)
        new_size = *size + min_units;
    num_bytes = new_size * unit_size;

    if (tblfree != NULL)
        free_offset = DiffPtrs(*(char **)tblfree,  (char *)table);

    if ((new_tbl = (char *)realloc(table, (unsigned)num_bytes)) == 0)
        quit("out of memory for %s", tbl_name);

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

        case Uop_Union:
            opcode = Op_Union;
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

        case Uop_Bactivate:
            opcode = Op_Activate;
            break;

        case Uop_Sect:                  /* section operation x[a:b] */
            opcode = Op_Sect;
            break;

        default:
            quit("cnv_op: undefined operator");
    }

    return opcode;
}

static void writescript()
{
#if UNIX
    char script[2048];
    /*
     *  Generate a shell header that searches for iconx in this order:
     *     a.  location specified by OIX environment variable
     *         (if specified, this MUST work, else the script exits)
     *     b.  location specified in script
     *         (as generated by oit or as patched later)
     *     c.  oix in $PATH
     */
    snprintf(script, sizeof(script),
             "%s\n%s%s%s\n\n%s\n%s\n%s%s%s\n\n%s",
             "#!/bin/sh",
             "OIXBIN=\"", oixloc, "\"",
             "[ -n \"$OIX\" ] && exec \"$OIX\" \"$0\" \"$@\"",
             "[ -x \"$OIXBIN\" ] && exec \"$OIXBIN\" \"$0\" \"$@\"",
             "exec ",
             "oix",
             " \"$0\" \"$@\"",
             IcodeDelim "\n");
    scriptsize = strlen(script);
    /* write header */
    if (fwrite(script, scriptsize, 1, outfile) != 1)
        quit("cannot write header to icode file");
#elif MSWIN32
   char *hdr = findexe("win32header");
   FILE *f;
   int c;
   if (!hdr)
      quit("Couldn't find win32header header file on PATH");
   if (!(f = fopen(hdr, ReadBinary)))
      quit("Tried to open win32header to build .exe, but couldn't");
   scriptsize = 0;
   while ((c = fgetc(f)) != EOF) {
      fputc(c, outfile);
      ++scriptsize;
   }
   fputs("\n" IcodeDelim "\n", outfile);
   scriptsize += strlen("\n" IcodeDelim "\n");
   fclose(f);
#elif PLAN9
    char script[2048];
    sprintf(script, "#!/bin/rc\n"
		"exec oix $0 $*\n"
                IcodeDelim "\n");
    scriptsize = strlen(script);
    /* write header */
    if (fwrite(script, scriptsize, 1, outfile) != 1)
        quit("cannot write header to icode file");
#endif
}


struct b_bignum * bigradix(char *input, int input_len)
{
    struct b_bignum *b;   /* Doesn't need to be tended */
    DIGIT *bd;
    word len;
    int r, c;
    char *s, *end_s;     /* Don't need to be tended */
    word size;

    /* Extract radix, setting r and adjusting input and input_len */
    s = input;
    end_s = s + input_len;
    r = 0;
    while (s < end_s) {
        if (*s == 'r' || *s == 'R') {
            if (r == 0 || r < 2 || r > 36)
                return 0;
            input_len -= (s + 1 - input);
            input = s + 1;
            break;
        }
        r = r * 10 + (*s - '0');
        ++s;
    }
    if (s == end_s)
        r = 10;

    /* printf("r=%d len=%d s='%.*s'\n",r,input_len,input_len,input); */

    s = input;
    len = ceil(input_len * ln(r) / ln(B));

    /* See ralc.r : MemProtect(b = alcbignum(len)); */
    size = sizeof(struct b_bignum) + ((len - 1) * sizeof(DIGIT));
    size = (size + WordSize - 1) & -WordSize;
    b = safe_malloc(size);
    b->blksize = size;
    b->msd = b->sign = 0;
    b->lsd = len - 1;

    bd = DIG(b,0);

    bdzero(bd, len);

    for (c = ((s < end_s) ? *s++ : ' '); isalnum((unsigned char)c);
         c = ((s < end_s) ? *s++ : ' ')) {
        c = isdigit((unsigned char)c) ? (c)-'0' : 10+(((c)|(040))-'a');
        if (c >= r)
            return 0;
        muli1(bd, (word)r, c, bd, len);
    }

    /*
     * Skip trailing white space and make sure there is nothing else left
     *  in the string. Note, if we have already reached end-of-string,
     *  c has been set to a space.
     */
    while (isspace((unsigned char)c) && s < end_s)
        c = *s++;
    if (!isspace((unsigned char)c))
        return 0;

    /* see mkdesc() */
    while (b->msd != b->lsd && *DIG(b,0) == 0)
        b->msd++;

    return b;
}

/*
 *  (u,n) * k + c -> (w,n)
 *
 *  k in 0 .. B-1
 *  returns carry, 0 .. B-1
 */

static DIGIT muli1(DIGIT *u, word k, int c, DIGIT *w, word n)
{
    uword dig, carry;
    word i;

    carry = c;
    for (i = n; --i >= 0; ) {
        dig = (uword)k * u[i] + carry;
        w[i] = lo(dig);
        carry = hi(dig);
    }
    return carry;
}
