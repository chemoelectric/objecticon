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

#define KDef(p,n) #p,
char *keyword_names[] = {
    NULL,
#include "../h/kdefs.h"
};

static int nstatics = 0;               /* Running count of static variables */
static int ntcase = 0;                 /* Running count of tcase tables */
static long codeoffset;                /* ftell() for start of code */

/*
 * Array sizes for various linker tables that can be expanded with realloc().
 */
static size_t maxcode	= 2000000;        /* code space */
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

/* A list of patches needed for utf8 ucs string locations */
struct utf8_patch {
    word pc;                         /* offset to write patch to */ 
    struct centry *ce;               /* constant entry for the ucs */
    struct strconst *sc;             /* string constant entry giving the offset to patch */
    struct utf8_patch *next;
};
static struct utf8_patch *utf8_patch_list;

struct relocation {
    word pc;                         /* offset to write patch to */ 
    int kind;                        /* type of entry to change */
    word param;                      /* param varies according to kind */
    struct relocation *next;
};
static struct relocation *relocation_list;

enum relocation_kind { NTH_STATIC, NTH_GLOBAL, NTH_CONST, NTH_TCASE, NTH_FIELDINFO, STRCONS_OFFSET };

/*
 * Prototypes.
 */

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
static void gencode_func(struct lfunction *f);
static void gencode(void);
static int is_ascii_string(char *p, int n);
static void add_relocation(word pc, int kind, word param);
static void do_relocations(void);


static DIGIT muli1	(DIGIT *u, word k, int c, DIGIT *w, word n);
static struct b_bignum * bigradix(char *input, int input_len);
static void set_ucs_slot(word *off, word offset_bits, word i, word n);


static word pc = 0;		/* simulated program counter */


#define CodeCheck(n) if (DiffPtrsBytes(codep, codeb) + n > maxcode) \
codeb = (char *) expand_table(codeb, &codep, &maxcode, 1,                   \
                          (n), "code buffer");


static void writescript(void);
static void writescript1(void);
static word cnv_op(int n);
static void genstaticnames(struct lfunction *lf);
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
static int strconst_offset, ascii_offset, ascii_only;
static struct centry *constblock_hash[128];
static void outbytex(char b, char *fmt, ...);
static void outuint16(uint16_t s, char *fmt, ...);
static void outwordx(word oword, char *fmt, ...);
static void outwordz(word oword, char *fmt, ...);
static void outstr(struct strconst *sp, char *fmt, ...);
static void outdptr(struct centry *ce, char *fmt, ...);
static void outwordz_nullable(word oword, char *fmt, ...);
static void tcase_field(struct ir_tcaseinit *x);

#if WordBits == 32
#define PadWordFmt "%08"XWordFmtCh
#define PadUInt16Fmt "%04lx    "
#define PadByteFmt "%02lx      "
#else
#define PadWordFmt "%016"XWordFmtCh
#define PadUInt16Fmt "%04lx            "
#define PadByteFmt "%02lx              "
#endif


static struct header hdr;

static void add_relocation(word pc, int kind, word param)
{
    struct relocation *r;
    r = Alloc1(struct relocation);
    r->pc = pc;
    r->kind = kind;
    r->param = param;
    r->next = relocation_list;
    relocation_list = r;
}

static void out_op(word op)
{
    outwordx(op, op_names[op]);
}

static void word_field(word w, char *desc)
{
    if (Dflag)
        fprintf(dbgfile, PadWordFmt ":   " PadWordFmt "    #    %s=" WordFmt "\n", pc, w, desc, w);
    outword(w);
}

static int get_tcaseno(struct ir_tcaseinit *x)
{
    if (x->no < 0)
        x->no = ntcase++;
    return x->no;
}

static void tcase_field(struct ir_tcaseinit *x)
{
    int i = get_tcaseno(x);
    if (Dflag)
        fprintf(dbgfile, PadWordFmt ": T[" PadWordFmt "]   #    no=%d\n", pc, (word)i, i);
    add_relocation(pc, NTH_TCASE, i);
    outword(0);
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
                outwordx(ival, "      " WordFmt, ival);
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
                if (Dflag)
                    fprintf(dbgfile, PadWordFmt ": C[" PadWordFmt "]   #       " WordFmt "\n", pc, ce->desc_no, ce->desc_no);
                add_relocation(pc, NTH_CONST, ce->desc_no);
                outword(0);
            }
            break;
        }
        case WORD: {
            outwordx(Op_Int, "   %s=int", desc);
            outwordx(v->w, "      " WordFmt, v->w);
            break;
        }
        case KNULL: {
            outwordx(Op_Knull, "   %s=&null", desc);
            break;
        }
        case KYES: {
            outwordx(Op_Kyes, "   %s=&yes", desc);
            break;
        }
        case LOCAL: {
            struct lentry *le = v->local;
            if (le->l_flag & F_Static) {
                outwordx(Op_Static, "   %s=static", desc);
                if (Dflag)
                    fprintf(dbgfile, PadWordFmt ": A[" PadWordFmt "]   #       %d (%s)\n", pc, (word)le->l_val.index, le->l_val.index, le->name);
                add_relocation(pc, NTH_STATIC, le->l_val.index);
                outword(0);
            } else if (le->l_flag & F_Argument) {
                if (is_self(le))
                    outwordx(Op_Self, "   %s=self", desc);
                else {
                    outwordx(Op_FrameVar, "   %s=framevar", desc);
                    outwordx(le->l_val.index, "      %d (%s)", le->l_val.index, le->name);
                }
            } else {
                outwordx(Op_FrameVar, "   %s=framevar", desc);
                outwordx(curr_lfunc->narguments + le->l_val.index, "      %d  (%s)", 
                         curr_lfunc->narguments + le->l_val.index, le->name);
            }
            break;
        }
        case GLOBAL: {
            struct gentry *ge = v->global;
            if ((ge->g_flag & (F_Builtin|F_Proc|F_Record|F_Class)) == 0) {
                if (is_readable_global(ge))
                    outwordx(Op_GlobalVal, "   %s=globalval", desc);
                else 
                    outwordx(Op_Global, "   %s=global", desc);
            } else
                outwordx(Op_GlobalVal, "   %s=globalval", desc);

            if (Dflag)
                fprintf(dbgfile, PadWordFmt ": G[" PadWordFmt "]   #       %d (%s)\n", pc, (word)ge->g_index, ge->g_index, ge->name);
            add_relocation(pc, NTH_GLOBAL, ge->g_index);
            outword(0);
            break;
        }
        case TMP: {
            outwordx(Op_Tmp, "   %s=tmp", desc);
            outwordx(v->index, "      %d", v->index);
            break;
        }
        default: {
            quit("emit_ir_var: Unknown type");
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
        if (is_ascii_string(s, len)) {
            if (!ascii_only)
                quit("Attempted to insert ascii string into strconst table at wrong time");
        } else {
            if (ascii_only)
                quit("Attempted to insert non-ascii string into strconst table at wrong time");
        }

        p = Alloc1(struct strconst);
        p->b_next = strconst_hash[i];
        p->next = 0;
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

void generate_code()
{
    int i;

    /*
     * Open the output file.
     */
    outfile = fopen(ofile, WriteBinary);
    if (outfile == NULL)
        equit("Cannot create %s",ofile);

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
        equit("Unable to write to icode file");

    codeoffset = ftell(outfile);
    if (codeoffset < 0)
        equit("Failed to ftell");

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
    codep = codeb = safe_malloc(maxcode);

    if (baseopt)
#if WordBits == 32
        hdr.Base = (9 + baseopt) * (word)0x10000000;
#elif WordBits == 64
        hdr.Base = (9 + baseopt) * (word)0x100000000;
#endif

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

    /*
     * Close the .ux file if debugging is on.
     */
    if (Dflag) {
        fclose(dbgfile);
    }

    fflush(outfile);
    if (ferror(outfile) != 0)
        equit("Unable to write to icode file");

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
}

static void gencode()
{
    struct lclass *cl;
    struct lclass_field *cf;
    struct gentry *gl;
    int i;

    i = 0;
    for (cl = lclasses; cl; cl = cl->next)
        for (cf = cl->fields; cf; cf = cf->next)
            cf->index = i++;

    for (gl = lgfirst; gl; gl = gl->g_next) {
        if (gl->func)
            gencode_func(gl->func);
        else if (gl->class) {
            struct lclass_field *me;
            for (me = gl->class->fields; me; me = me->next) {
                if (me->func && !(me->flag & (M_Removed | M_Optional | M_Abstract | M_Native))) 
                    gencode_func(me->func);
            }
        }
    }
}

static int is_ascii_string(char *p, int n)
{
    while (n--) {
        if (*p++ & 0x80)
            return 0;
    }
    return 1;
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
            quit("Unable to parse bignum data");
        if (bn->blksize % WordSize != 0)
            quit("Bigint blksize wrong");
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
        struct range *pair = safe_zalloc(ce->length);
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
        word index_step, n_offs, offset_bits, n_off_words, length, i, j, *off;
        char *p, *e;
        struct utf8_patch *patch;

        ce->pc = pc;

        /* Calculate the length in unicode chars */
        p = ce->data;
        e = p + ce->length;
        length = 0;
        while (p < e) {
            p += UTF8_SEQ_LEN(*p);
            ++length;
        }

        calc_ucs_index_settings(ce->length, length, &index_step, &n_offs, &offset_bits, &n_off_words);

        outwordx(T_Ucs, "T_Ucs");
        outwordx((9 + n_off_words) * WordSize, "   Block size");
        outwordx(length, "   Length");

        outwordx(ce->length, "   UTF-8 length");

        /* Add a patch entry to the list - we need to come back later
         * and fill in the utf8 string offset
         */
        patch = Alloc1(struct utf8_patch);
        patch->pc = pc;
        patch->ce = ce;
        patch->sc = 0;
        patch->next = utf8_patch_list;
        utf8_patch_list = patch;

        outwordx(0, "   UTF-8 string");

        outwordx(n_offs, "   N left indexed");
        outwordx(n_offs, "   N right indexed");
        outwordx(offset_bits, "   Offset bits");
        outwordx(index_step, "   Index step");

        /* This mirrors the loop in fmisc.r (get_ucs_off) */
        if (index_step > 0) {
            /* zalloc, since the loop below may not set all of the index bytes */
            off = safe_zalloc(n_off_words * WordSize);
            p = ce->data;
            i = j = 0;
            while (i < length - 1) {
                p += UTF8_SEQ_LEN(*p);
                ++i;
                if (i % index_step == 0)
                    set_ucs_slot(off, offset_bits, j++, p - ce->data);
            }
            for (i = 0; i < n_off_words; ++i)
                outwordx(off[i],   "   Offset data %d", i);
            free(off);
        }
    }
}

static void patchrefs()
{
    int i;
    for (i = 0; i <= hi_chunk; ++i) {
        struct chunk *chunk;
        word p;
        chunk = chunks[i];
        if (!chunk)
            continue;
        p = chunk->refs;
        while (p) {
            word t, off;
            memcpy(&t, &codeb[p], WordSize);
            off = chunk->pc + hdr.Base;
            memcpy(&codeb[p], &off, WordSize);
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
                    outwordx(x->keyword, "   keyword=" WordFmt " (&%s)", x->keyword, keyword_names[x->keyword]);
                    emit_ir_var(x->lhs, "lhs");
                    labout(x->fail_label, "fail");
                    break;
                }
                case Ir_KeyClo: {
                    struct ir_keyclo *x = (struct ir_keyclo *)ir;
                    out_op(Op_Keyclo);
                    outwordx(x->keyword, "   keyword=" WordFmt " (&%s)", x->keyword, keyword_names[x->keyword]);
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
                    tcase_field(x);
                    word_field(x->size, "size");
                    labout(x->def, "def");
                    break;
                }
                case Ir_TCaseInsert: {
                    struct ir_tcaseinsert *x = (struct ir_tcaseinsert *)ir;
                    out_op(Op_TCaseInsert);
                    tcase_field(x->tci);
                    emit_ir_var(x->val, "val");
                    labout(x->entry, "entry");
                    break;
                }
                case Ir_TCaseChoose: {
                    struct ir_tcasechoose *x = (struct ir_tcasechoose *)ir;
                    out_op(Op_TCaseChoose);
                    tcase_field(x->tci);
                    emit_ir_var(x->val, "val");
                    break;
                }
                default: {
                    quit("lemitcode: Illegal ir opcode(%d)\n", ir->op);
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
    int size;
    word ap;
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
    if (curr_lfunc->method) {
        if (Dflag)
            fprintf(dbgfile, PadWordFmt ": F[" PadWordFmt "]   #    Field info %d\n", pc, (word)curr_lfunc->method->index, curr_lfunc->method->index);
        add_relocation(pc, NTH_FIELDINFO, curr_lfunc->method->index);
        outword(0);
    } else
        outwordx(0, "   Field info");
    outdptr(ce, "   Procedure name (%s)", p);
    outwordz(curr_lfunc->pc + size, "   Entry point");
    outwordx(has_op_create(), "   Creates flag");
    outwordx(curr_lfunc->ndynamic, "   Num dynamic");
    outwordx(curr_lfunc->nstatics, "   Num static");
    if (curr_lfunc->nstatics) {
        if (Dflag)
            fprintf(dbgfile, PadWordFmt ": A[" PadWordFmt "]   #    First static (%d)\n", pc, (word)nstatics, nstatics);
        add_relocation(pc, NTH_STATIC, nstatics);
        outword(0);
    } else
        outwordx(0, "   First static (null pointer)");
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
        outwordz_nullable(0, "   Pointer to local locations array");

    /*
     * Names array.  Loop through the list of locals three times to get the output
     * in the correct order.
     */
    if (Dflag)
        fprintf(dbgfile, "# Local names array\n");
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Argument) {
            ce = inst_sdescrip(le->name);
            outdptr(ce, "Local name (arg %s)", le->name);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Dynamic) {
            ce = inst_sdescrip(le->name);
            outdptr(ce, "Local name (dynamic %s)", le->name);
        }
    }
    for (le = curr_lfunc->locals; le; le = le->next) {
        if (le->l_flag & F_Static) {
            ce = inst_sdescrip(le->name);
            le->l_val.index = nstatics++;
            outdptr(ce, "Local name (static %s)", le->name);
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
                outdptr(ce, "File %s", le->pos.file);
                outwordx(le->pos.line, "Line %d", le->pos.line);
            }
        }
        for (le = curr_lfunc->locals; le; le = le->next) {
            if (le->l_flag & F_Dynamic) {
                ce = inst_sdescrip(le->pos.file);
                outdptr(ce, "File %s", le->pos.file);
                outwordx(le->pos.line, "Line %d", le->pos.line);
            }
        }
        for (le = curr_lfunc->locals; le; le = le->next) {
            if (le->l_flag & F_Static) {
                ce = inst_sdescrip(le->pos.file);
                outdptr(ce, "File %s", le->pos.file);
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
    int i, n_fields;
    struct centry *ce;
    word ap, p;

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
    outdptr(ce, "   Class name");

    i = hasher(init_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != init_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;

    outwordz_nullable(p, "   Pointer to init field");

    i = hasher(new_string, cl->implemented_field_hash);
    fr = cl->implemented_field_hash[i];
    while (fr && fr->field->name != new_string)
        fr = fr->b_next;
    if (fr)
        p = fr->field->ipc;
    else
        p = 0;

    outwordz_nullable(p, "   Pointer to new field");

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
    ap += n_fields * sizeof(uint16_t);
    ap = WordRound(ap);

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
        outuint16((uint16_t)sortf[i].n, "   Field %s (fnum=%d)", sortf[i].fp->name, sortf[i].fp->field_id);
    free(sortf);

    align();

    /* Check our calculations were right */
    if (ap != pc)
        quit("I got my sums wrong(b): %d != %d", ap, pc);
    if (cl->pc + cl->size != pc)
        quit("I got my sums wrong(c): %d != %d", cl->pc + cl->size, pc);
}

static void genclasses(void)
{
    struct lclass *cl;
    struct lclass_field *cf;
    int n_fields = 0;
    struct centry *ce;
    word x;

    align();
    hdr.ClassStatics = hdr.Base + pc;

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
        fprintf(dbgfile, "\n# Class static descriptors\n");
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
    }

    align();
    hdr.ClassMethods = hdr.Base + pc;

    /*
     * Output descriptors for class methods :-
     *   defer methods get a proc descriptor with the 
     *      native method number (-1 if unresolved) in the vword
     *   other methods get a proc descriptor pointing to the b_proc
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Class method descriptors\n");
    for (cl = lclasses; cl; cl = cl->next) {
        for (cf = cl->fields; cf; cf = cf->next) {
            if (cf->flag & M_Method) {
                cf->dpc = pc;
                if (cf->flag & M_Removed) {
                    outwordx(D_Proc, "D_Proc, Removed method %s.%s", cl->global->name, cf->name);
                    outwordx(0, "   Method stub");
                } else if (cf->flag & M_Native) {
                    outwordx(D_Proc, "D_Proc, Native method %s.%s", cl->global->name, cf->name);
                    outwordx(cf->func->native_method_id, "   Native method id");
                } else if (cf->flag & (M_Optional | M_Abstract)) {
                    outwordx(D_Proc, "D_Proc, Optional or abstract method %s.%s", cl->global->name, cf->name);
                    outwordx(0, "   Method stub");
                } else {
                    /* Method, with definition in the icode file  */
                    outwordx(D_Proc, "D_Proc, Method %s.%s", cl->global->name, cf->name);
                    outwordz(cf->func->pc, "   Block");
                }
            }
        }
    }


    align();
    hdr.ClassFields = hdr.Base + pc;

    /* 
     * Firstly work out the "address" each class will have, so we can forward
     * reference them.
     */
    x = pc + WordSize * (4 * n_fields);  /* The size of the class
                                          * field table */
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
            sizeof(uint16_t) * n_fields;

        cl->size = WordRound(cl->size);
        x += cl->size;
    }

    /*
     * Output the class field info table
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Class field info table\n");
    for (cl = lclasses; cl; cl = cl->next) {
        for (cf = cl->fields; cf; cf = cf->next) {
            cf->ipc = pc;
            if (Dflag)
                fprintf(dbgfile, "# Field info for %s.%s\n", cl->global->name, cf->name);
            outwordx(cf->ftab_entry->field_id, "Fnum");
            outwordx(cf->flag, "Flags");
            outwordz(cf->class->pc, "Defining class");
            outwordz_nullable(cf->dpc, "Pointer to descriptor");
        }
    }

    align();
    hdr.ClassFieldLocs = hdr.Base + pc;
    if (Dflag)
        fprintf(dbgfile, "\n# Class field location table\n");
    if (loclevel > 1) {
        for (cl = lclasses; cl; cl = cl->next) {
            for (cf = cl->fields; cf; cf = cf->next) {
                ce = inst_sdescrip(cf->pos.file);
                outdptr(ce, "File %s", cf->pos.file);
                outwordx(cf->pos.line, "Line %d", cf->pos.line);
            }
        }
    }

    align();
    hdr.Classes = hdr.Base + pc;

    if (Dflag)
        fprintf(dbgfile, "\n# Class blocks\n");

    for (cl = lclasses; cl; cl = cl->next)
        genclass(cl);
}

static void genstaticnames(struct lfunction *lf)
{
    struct lentry *le;
    struct centry *ce;
    for (le = lf->locals; le; le = le->next) {
        if (le->l_flag & F_Static) {
            ce = inst_sdescrip(le->name);
            outdptr(ce, "Local name (static %s)", le->name);
        }
    }
}

/*
 * gentables - generate interpreter code for global, static,
 *  identifier, and record tables, and built-in procedure blocks.
 */
static void gentables()
{
    int i;
    char *s;
    struct gentry *gp;
    struct lrecord *rec;
    struct fentry *fp;
    struct lfield *fd;
    struct strconst *sp;
    struct ipc_fname *fnptr;
    struct ipc_line *lnptr;
    struct centry *ce;
    struct utf8_patch *pe;

    if (Dflag) {
        fprintf(dbgfile,"\n\n# Global tables\n");
    }

    genclasses();

    /*
     * Output record constructor blocks.
     */
    align();
    hdr.Records = hdr.Base + pc;

    if (Dflag)
        fprintf(dbgfile, "\n# Constructor blocks\n");

    for (rec = lrecords; rec; rec = rec->next) {
        struct field_sort_item *sortf;
        word ap;
        int size;
        s = rec->global->name;
        rec->pc = pc;
        ce = inst_sdescrip(s);
        size = 9 * WordSize + rec->nfields * (WordSize + sizeof(uint16_t));
        if (loclevel > 1)
            size += rec->nfields * 2 * WordSize;
        size = WordRound(size);

        if (Dflag)
            fprintf(dbgfile, "\n# constructor %s\n", s);

        outwordx(T_Constructor, "T_Constructor");		/* type code */
        outwordx(0, "   Owning prog");
        outwordx(rec->global->defined->package_id, "   Package id");
        outwordx(0, "   Instance id counter");
        outwordx(rec->nfields, "   Num fields");
        outdptr(ce, "   Name of record");

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
            outwordz_nullable(0, "   Pointer to field_locs array");
        outwordz(ap, "   Pointer to field sort array");
        ap += rec->nfields * sizeof(uint16_t);
        ap = WordRound(ap);

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
                outdptr(ce, "File %s", fd->pos.file);
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
            outuint16((uint16_t)sortf[i].n, "   Field %s (fnum=%d)", sortf[i].fp->name, sortf[i].fp->field_id);
        free(sortf);

        align();

        /* Check our calculations were right */
        if (ap != pc)
            quit("I got my sums wrong(d): %d != %d", ap, pc);
        if (rec->pc + size != pc)
            quit("I got my sums wrong(e): %d != %d", rec->pc + size, pc);
    }

    /*
     * Output descriptors for field names.
     */
    align();
    if (Dflag)
        fprintf(dbgfile, "\n# Field names table\n");
    hdr.Fnames = hdr.Base + pc;
    for (fp = lffirst; fp; fp = fp->next) {
        ce = inst_sdescrip(fp->name);
        outdptr(ce, "Field %s", fp->name);
    }

    /*
     * Output global variable descriptors.
     */
    hdr.Globals = hdr.Base + pc;
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable descriptors\n");
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->g_flag & F_Builtin) {		/* function */
            outwordx(D_Proc, "D_Proc, global %s", gp->name);
            outwordx(gp->builtin->builtin_id, "   Builtin id (%d)", gp->builtin->builtin_id);
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

    /*
     * Output descriptors for global variable names.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable names\n");
    hdr.Gnames = hdr.Base + pc;
    for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
        ce = inst_sdescrip(gp->name);
        outdptr(ce, "%s", gp->name);
    }

    /*
     * Output global variable flags.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable flags\n");
    hdr.Gflags = hdr.Base + pc;
    for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
        char f = 0;
        if (gp->g_flag & F_Package)
            f |= G_Package;
        if (gp->g_flag & F_Readable)
            f |= G_Readable;
        if (gp->g_flag & (F_Builtin|F_Proc|F_Record|F_Class))
            f |= G_Const;
        if (gp->g_flag & F_Builtin)
            f |= G_Builtin;
        outbytex(f, "Flag %s", gp->name);
    }
    align();

    /*
     * Output locations for global variables.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Global variable locations\n");
    hdr.Glocs = hdr.Base + pc;
    if (loclevel > 1) {
        for (gp = lgfirst; gp != NULL; gp = gp->g_next) {
            if (gp->g_flag & F_Builtin) {
                outwordx(0, "%s: Builtin", gp->name);
                outwordx(0, "");
            } else {
                ce = inst_sdescrip(gp->pos.file);
                outdptr(ce, "%s File %s", gp->name, gp->pos.file);
                outwordx(gp->pos.line, "Line %d", gp->pos.line);
            }
        }
    }

    /*
     * Output a null descriptor for each static variable.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Static variable null descriptors\n");
    hdr.Statics = hdr.Base + pc;
    for (i = 0; i < nstatics; ++i) {
        outwordx(D_Null, "D_Null");
        outwordx(0, "");
    }

    /*
     * Output descriptors for static variable names.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# Static variable names\n");
    hdr.Snames = hdr.Base + pc;
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->func)
            genstaticnames(gp->func);
        else if (gp->class) {
            struct lclass_field *me;
            for (me = gp->class->fields; me; me = me->next) {
                if (me->func && !(me->flag & (M_Removed | M_Optional | M_Abstract | M_Native))) 
                    genstaticnames(me->func);
            }
        }
    }

    /*
     * Output a null descriptor for each tcase table.
     */
    if (Dflag)
        fprintf(dbgfile, "\n# TCase table null descriptors\n");
    hdr.TCaseTables = hdr.Base + pc;
    for (i = 0; i < ntcase; ++i) {
        outwordx(D_Null, "D_Null");
        outwordx(0, "");
    }

    if (Dflag)
        fprintf(dbgfile, "\n# File names table\n");
    hdr.Filenms = hdr.Base + pc;
    for (fnptr = fnmtbl; fnptr < fnmfree; fnptr++) {
        ce = inst_sdescrip(fnptr->fname);
        outwordz(fnptr->ipc, "IPC");
        outdptr(ce, "   File %s", fnptr->fname);
    }

    if (Dflag)
        fprintf(dbgfile, "\n# Line number table\n");
    hdr.Linenums = hdr.Base + pc;
    for (lnptr = lntable; lnptr < lnfree; lnptr++) {
        outwordz(lnptr->ipc, "IPC");
        outwordx(lnptr->line, "   Line %d", lnptr->line);        
    }

    /*
     * Install non-ascii string constants, from the ucs utf-8 strings
     * and all other strings, which are stored in the const descriptor
     * list.
     */
    ascii_only = 0;
    for (pe = utf8_patch_list; pe; pe = pe->next) {
        if (!is_ascii_string(pe->ce->data, pe->ce->length))
            pe->sc = inst_strconst(pe->ce->data, pe->ce->length);
    }
    for (ce = const_desc_first; ce; ce = ce->d_next) {
        if (ce->c_flag & F_StrLit && !is_ascii_string(ce->data, ce->length))
            inst_strconst(ce->data, ce->length);
    }

    /*
     * Now every string inserted must be ascii.
     */
    ascii_offset = strconst_offset;
    ascii_only = 1;

    /*
     * This ensures empty strings point to the start of the ascii string region,
     * which is a bit tidier than pointing to some arbitrary offset.
     */
    inst_strconst(empty_string, 0);

    /*
     * Now the ascii ucs utf8 strings are installed.  The other ascii
     * strings are installed in the for loop below.
     */
    for (pe = utf8_patch_list; pe; pe = pe->next) {
        pe->sc = inst_strconst(pe->ce->data, pe->ce->length);
        add_relocation(pe->pc, STRCONS_OFFSET, pe->sc->offset);
    }

    if (Dflag)
        fprintf(dbgfile, "\n# Constant descriptors\n");
    hdr.Constants = hdr.Base + pc;
    i = 0;
    for (ce = const_desc_first; ce; ce = ce->d_next) {
        if (Dflag)
            fprintf(dbgfile, "# Entry %04x\n", i++);
        if (ce->c_flag & F_IntLit) {
            word ival;
            memcpy(&ival, ce->data, sizeof(word));
            outwordx(D_Integer, "D_Integer");
            outwordx(ival, "   " WordFmt, ival);
        } else if (ce->c_flag & F_StrLit) {
            struct strconst *sp = inst_strconst(ce->data, ce->length);
            outstr(sp, "String");
        } else if (ce->c_flag & F_LrgintLit) {
            outwordx(D_Lrgint, "D_Lrgint");
            outwordz(ce->pc, "   Block");
#if !RealInDesc
        } else if (ce->c_flag & F_RealLit) {
            outwordx(D_Real, "D_Real");
            outwordz(ce->pc, "   Block");
#endif
        } else if (ce->c_flag & F_CsetLit) {
            outwordx(D_Cset, "D_Cset");
            outwordz(ce->pc, "   Block");
        } else if (ce->c_flag & F_UcsLit) {
            outwordx(D_Ucs, "D_Ucs");
            outwordz(ce->pc, "   Block");
        } else
            quit("Unknown constant type");
    }

    hdr.Strcons = hdr.Base + pc;
    hdr.AsciiStrcons = hdr.Strcons + ascii_offset;

    do_relocations();
    flushcode();
    
    if (Dflag)
        fprintf(dbgfile, "\n# String constants table\n");

    for (sp = first_strconst; sp; sp = sp->next) {
        if (sp->len > 0) {
            if (Dflag) {
                char *s = sp->s, t[9];
                int i, j = 0;
                fprintf(dbgfile, "# Offset %04lx\n", (long)sp->offset);
                for (i = 0; i < sp->len; ++i) {
                    if (i == 0)
                        fprintf(dbgfile, PadWordFmt ":    ", pc);
                    else if (i % 8 == 0) {
                        t[j] = 0;
                        fprintf(dbgfile, "   %s\n" PadWordFmt ":    ", t, pc + i);
                        j = 0;
                    }
                    fprintf(dbgfile, " %02x", s[i] & 0xff);
                    t[j++] = oi_isprint(s[i]) ? s[i] : ' ';
                }
                t[j] = 0;
                while (i % 8 != 0) {
                    fprintf(dbgfile, "   ");
                    ++i;
                }
                fprintf(dbgfile, "   %s\n", t);
            }
            if (fwrite(sp->s, 1, sp->len, outfile) != sp->len)
                equit("Cannot write icode file");
            pc += sp->len;
        }
    }

    /*
     * Check for wraparound
     */
    if ((uword)(hdr.Base + pc) < (uword)hdr.Base)
        quit("Code size too big for selected base address");

    /*
     * Output icode file header.
     */
    hdr.IcodeSize = pc;
    strcpy((char *)hdr.Config,IVersion);

    if (Dflag) {
        fprintf(dbgfile, "\n");
        fprintf(dbgfile, "base:             " XWordFmt "\n", hdr.Base);
        fprintf(dbgfile, "icodesize:        " XWordFmt "\n", hdr.IcodeSize);
        fprintf(dbgfile, "class statics:    " XWordFmt "\n", hdr.ClassStatics);
        fprintf(dbgfile, "class methods:    " XWordFmt "\n", hdr.ClassMethods);
        fprintf(dbgfile, "class fields:     " XWordFmt "\n", hdr.ClassFields);
        fprintf(dbgfile, "class field locs: " XWordFmt "\n", hdr.ClassFieldLocs);
        fprintf(dbgfile, "classes:          " XWordFmt "\n", hdr.Classes);
        fprintf(dbgfile, "records:          " XWordFmt "\n", hdr.Records);
        fprintf(dbgfile, "fnames:           " XWordFmt "\n", hdr.Fnames);
        fprintf(dbgfile, "globals:          " XWordFmt "\n", hdr.Globals);
        fprintf(dbgfile, "gnames:           " XWordFmt "\n", hdr.Gnames);
        fprintf(dbgfile, "gflags:           " XWordFmt "\n", hdr.Gflags);
        fprintf(dbgfile, "glocs:            " XWordFmt "\n", hdr.Glocs);
        fprintf(dbgfile, "statics:          " XWordFmt "\n", hdr.Statics);
        fprintf(dbgfile, "snames:           " XWordFmt "\n", hdr.Snames);
        fprintf(dbgfile, "tcasetables:      " XWordFmt "\n", hdr.TCaseTables);
        fprintf(dbgfile, "filenms:          " XWordFmt "\n", hdr.Filenms);
        fprintf(dbgfile, "linenums:         " XWordFmt "\n", hdr.Linenums);
        fprintf(dbgfile, "constants:        " XWordFmt "\n", hdr.Constants);
        fprintf(dbgfile, "strcons:          " XWordFmt "\n", hdr.Strcons);
        fprintf(dbgfile, "asciistrcons:     " XWordFmt "\n", hdr.AsciiStrcons);
        fprintf(dbgfile, "config:           %s\n", (char*)hdr.Config);
    }

    if (fseek(outfile, scriptsize, SEEK_SET) < 0)
        equit("Cannot seek to header location");

    if (fwrite((char *)&hdr, 1, sizeof(hdr), outfile) != sizeof(hdr))
        equit("Cannot write icode file");

    if (verbose > 1) {
        word tsize = sizeof(hdr) + hdr.IcodeSize;
        report("  Script          %7ld", scriptsize);
        tsize += scriptsize;
        report("  Header          %7ld", (long)sizeof(hdr));
        report("  Procedures      %7" WordFmtCh, (hdr.ClassStatics - hdr.Base));
        report("  Class statics   %7" WordFmtCh, (hdr.ClassMethods - hdr.ClassStatics));
        report("  Class methods   %7" WordFmtCh, (hdr.ClassFields - hdr.ClassMethods));
        report("  Class fields    %7" WordFmtCh, (hdr.ClassFieldLocs - hdr.ClassFields));
        report("  Class field locs%7" WordFmtCh, (hdr.Classes - hdr.ClassFieldLocs));
        report("  Classes         %7" WordFmtCh, (hdr.Records - hdr.Classes));
        report("  Records         %7" WordFmtCh, (hdr.Fnames - hdr.Records));
        report("  Field names     %7" WordFmtCh, (hdr.Globals - hdr.Fnames));
        report("  Globals         %7" WordFmtCh, (hdr.Gnames  - hdr.Globals));
        report("  Global names    %7" WordFmtCh, (hdr.Gflags - hdr.Gnames));
        report("  Global flags    %7" WordFmtCh, (hdr.Glocs - hdr.Gflags));
        report("  Global locs     %7" WordFmtCh, (hdr.Statics - hdr.Glocs));
        report("  Statics         %7" WordFmtCh, (hdr.Snames - hdr.Statics));
        report("  Static names    %7" WordFmtCh, (hdr.TCaseTables - hdr.Snames));
        report("  TCaseTables     %7" WordFmtCh, (hdr.Filenms - hdr.TCaseTables));
        report("  Filenms         %7" WordFmtCh, (hdr.Linenums - hdr.Filenms));
        report("  Linenums        %7" WordFmtCh, (hdr.Constants - hdr.Linenums));
        report("  Constants       %7" WordFmtCh, (hdr.Strcons - hdr.Constants));
        report("  Strings         %7" WordFmtCh, (hdr.AsciiStrcons - hdr.Strcons));
        report("  Ascii strings   %7" WordFmtCh, (hdr.IcodeSize + hdr.Base - hdr.AsciiStrcons));
        report("  Total           %7" WordFmtCh, tsize);
    }
}

/*
 * align() outputs zeroes as padding until pc is a multiple of WordSize.
 */
static void align()
{
    int i, n;

    n = WordRound(pc) - pc;
    if (n == 0)
        return;

    if (Dflag) {
        for (i = 0; i < n; ++i)
            fprintf(dbgfile, PadWordFmt ":   " PadByteFmt "    # Padding byte\n", pc + i, (long)0);
    }
    CodeCheck(n);
    for (i = 0; i < n; ++i)
        *codep++ = 0;
    pc += n;
}

static void outstr(struct strconst *sp, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, PadWordFmt ":   " PadWordFmt "    # ", pc, sp->len);
        vfprintf(dbgfile, fmt, ap);
        fprintf(dbgfile, "\n" PadWordFmt ": S+" PadWordFmt "    #    \"%s\"\n", 
                         pc + (int)WordSize, sp->offset, sp->s);
        va_end(ap);
    }

    CodeCheck(2 * WordSize);
    memcpy(codep, &sp->len, WordSize);
    codep += WordSize;
    memset(codep, 0, WordSize);
    codep += WordSize;
    add_relocation(pc + WordSize, STRCONS_OFFSET, sp->offset);
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
        fprintf(dbgfile, PadWordFmt ":   " PadWordFmt "    # ", pc, oword);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    outword(oword);
}

static void outuint16(uint16_t s, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, PadWordFmt ":   " PadUInt16Fmt "    # ", pc, (long)s);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    CodeCheck(sizeof(uint16_t));
    memcpy(codep, &s, sizeof(uint16_t));
    codep += sizeof(uint16_t);
    pc += sizeof(uint16_t);
}

static void outbytex(char b, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, PadWordFmt ":   " PadByteFmt "    # ", pc, (long)b);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    CodeCheck(1);
    *codep++ = b;
    pc++;
}

static void outwordz(word oword, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, PadWordFmt ": Z+" PadWordFmt "    # ", pc, oword);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    outword(oword + hdr.Base);
}

static void outwordz_nullable(word oword, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        if (oword)
            fprintf(dbgfile, PadWordFmt ": Z+" PadWordFmt "    # ", pc, oword);
        else
            fprintf(dbgfile, PadWordFmt ":   " PadWordFmt "    # ", pc, oword);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    if (oword)
        oword += hdr.Base;
    outword(oword);
}

static void outdptr(struct centry *ce, char *fmt, ...)
{
    if (Dflag) {
        va_list ap;
        va_start(ap, fmt);
        fprintf(dbgfile, PadWordFmt ": C[" PadWordFmt "]   # ", pc, ce->desc_no);
        vfprintf(dbgfile, fmt, ap);
        putc('\n', dbgfile);
        va_end(ap);
    }
    add_relocation(pc, NTH_CONST, ce->desc_no);
    outword(0);
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
    size_t n = DiffPtrs(codep,codeb);
    if (fwrite(codeb, 1, n, outfile) != n)
        equit("Cannot write icode file");
    free(codeb);
    codep = codeb = 0;
}


static void labout(int i, char *desc)
{
    struct chunk *chunk = chunks[i];
    word t = pc;
    if (Dflag)
        fprintf(dbgfile, PadWordFmt ":   " PadWordFmt "    #    %s=chunk %d\n", pc, (word)0, desc, i);
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

    if ((new_tbl = realloc(table, num_bytes)) == 0)
        quit("Out of memory for %s", tbl_name);

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

        case Uop_Asgn1:
            opcode = Op_Asgn1;
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

        case Uop_Swap1:
            opcode = Op_Swap1;
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
            quit("cnv_op: Undefined operator");
    }

    return opcode;
}

static void writescript()
{
    if (Bflag) {
        char *script =  "\n" IcodeDelim "\n";
        scriptsize = strlen(script);
        /* write header */
        if (fwrite(script, scriptsize, 1, outfile) != 1)
            equit("Cannot write header to icode file");
    } else
        writescript1();
}

static void writescript1()
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
             "OIX_BIN=\"", oixloc, "\"",
             "[ -n \"$OIX\" ] && exec \"$OIX\" \"$0\" \"$@\"",
             "[ -x \"$OIX_BIN\" ] && exec \"$OIX_BIN\" \"$0\" \"$@\"",
             "exec ",
             "oix",
             " \"$0\" \"$@\"",
             IcodeDelim "\n");
    scriptsize = strlen(script);
    /* write header */
    if (fwrite(script, scriptsize, 1, outfile) != 1)
        equit("Cannot write header to icode file");
#elif MSWIN32
   char *hdr = findoiexe("win32header");
   FILE *f;
   int c, dc, wloc, oixloclen;
   if (!hdr)
      quit("Couldn't find win32header header file in OI_HOME/bin");
   if (!(f = fopen(hdr, ReadBinary)))
      equit("Tried to open win32header to build .exe, but couldn't");
   wloc = dc = scriptsize = 0;
   oixloclen = strlen(oixloc);
   while ((c = fgetc(f)) != EOF) {
       fputc(c, outfile);
       if (!wloc) {
           if (c == '$') {
               if (++dc == oixloclen + 1) {
                   /* Found enough $ chars in a row; go back and
                    * insert the oixloc string.
                    */
                   if (fseek(outfile, -dc, SEEK_END) < 0)
                       equit("Failed to seek");
                   fputs(oixloc, outfile);
                   fputc(0, outfile);
                   wloc = 1;
               }
           } else
               dc = 0;
       }
       ++scriptsize;
   }
   fputs("\n" IcodeDelim "\n", outfile);
   scriptsize += strlen("\n" IcodeDelim "\n");
   if (ferror(f) != 0)
       equit("Unable to read win32header executable");
   fclose(f);
#elif PLAN9
    char script[2048];
    sprintf(script,
            "#!/bin/rc\n"
            "if(~ $#OIX 0) exec oix $0 $*\n"
            "if not exec $OIX $0 $*\n"
            "exit 'interpreter not found'\n"
            IcodeDelim "\n");
    scriptsize = strlen(script);
    /* write header */
    if (fwrite(script, scriptsize, 1, outfile) != 1)
        equit("cannot write header to icode file");
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

    if (r < 2 || r > 36)
        return 0;

    /* printf("r=%d len=%d s='%.*s'\n",r,input_len,input_len,input); */

    s = input;
    len = ceil(input_len * ln(r) / ln(B));

    /* See ralc.r : MemProtect(b = alcbignum(len)); */
    size = sizeof(struct b_bignum) + ((len - 1) * sizeof(DIGIT));
    size = WordRound(size);

    /* zalloc since the structure contains "holes" which aren't initialized below. */
    b = safe_zalloc(size);

    b->blksize = size;
    b->msd = b->sign = 0;
    b->lsd = len - 1;

    bd = DIG(b,0);

    bdzero(bd, len);
    
    while (s < end_s && oi_isalnum(*s)) {
        c = oi_isdigit(*s) ? (*s)-'0' : 10+(((*s)|(040))-'a');
        if (c >= r)
            return 0;
        muli1(bd, (word)r, c, bd, len);
        ++s;
    }

    /* Check for no digits */
    if (s == input)
        return 0;

    /*
     * Skip trailing white space and make sure there is nothing else left
     *  in the string.
     */
    while (s < end_s && oi_isspace(*s))
        ++s;
    if (s < end_s)
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

static void set_ucs_slot(word *off, word offset_bits, word i, word n)
{
    switch (offset_bits) {
        case 8: {
            unsigned char *p = (unsigned char *)(off);
            p[i] = (unsigned char)n;
            break;
        }
        case 16: {
            uint16_t *p = (uint16_t *)(off);
            p[i] = (uint16_t)n;
            break;
        }
#if WordBits == 32
        case 32: {
            off[i] = n;
            break;
        }
#else
        case 32: {
            uint32_t *p = (uint32_t *)(off);
            p[i] = (uint32_t)n;
            break;
        }
        case 64: {
            off[i] = n;
            break;
        }
#endif
        default: {
            quit("Invalid offset_bits");
            break;
        }
    }
}

static void do_relocations()
{
    struct relocation *r;
    word w = 0;
    if (Dflag)
        fprintf(dbgfile, "\n# Relocations\n");
    for (r = relocation_list; r; r = r->next) {
        switch (r->kind) {
            case NTH_STATIC: w = hdr.Statics + r->param * 2 * WordSize; break;
            case NTH_GLOBAL: w = hdr.Globals + r->param * 2 * WordSize; break;
            case NTH_CONST: w = hdr.Constants + r->param * 2 * WordSize; break;
            case NTH_TCASE: w = hdr.TCaseTables + r->param * 2 * WordSize; break;
            case NTH_FIELDINFO: w = hdr.ClassFields + r->param * 4 * WordSize; break;
            case STRCONS_OFFSET: w = hdr.Strcons + r->param ; break;
            default:
                quit("do_relocations: Unknown kind");
        }

        if (Dflag)
            fprintf(dbgfile, PadWordFmt ": " PadWordFmt " (kind=%d)\n", r->pc, w, r->kind);

        memcpy(&codeb[r->pc], &w, WordSize);
    }
}
