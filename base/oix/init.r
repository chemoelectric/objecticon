/*
 * File: init.r
 * Initialization, termination, and such.
 */

#include "../h/header.h"
#include "../h/opdefs.h"
#include "../h/opnames.h"

static FILE *readhdr_strict(char *name, struct header *hdr);
static FILE *readhdr_liberal(char *name, struct header *hdr);
static dptr get_main(struct progstate *prog);
static int check_version(struct header *hdr);
static void read_icode(struct header *hdr, char *name, FILE *ifile, char *codeptr);
static void initptrs (struct progstate *p, struct header *h);
static void initprogstate(struct progstate *p);
static void initregion(struct region *r);
static void handle_prog_exit(void);
static void relocate_code(struct progstate *ps, word *c);
static void conv_addr(void);
static void conv_var(void);
static struct b_cset *make_static_cset_block(int n_ranges, ...);
static struct b_ucs *make_static_ucs_block(char *utf8);
static void resolve(struct progstate *p);
static void quick_resolve(struct progstate *p);
static void slow_resolve(struct progstate *p);


/*
 * External declarations for operator and function blocks.
 */

#define OpDef(f)  extern struct c_proc B##f;
#include "../h/odefs.h"
#undef OpDef

#define FncDef(f)  extern struct c_proc B##f;
#include "../h/fdefs.h"
#undef FncDef

#define KDef(p,n) extern struct c_proc L##p;
#include "../h/kdefs.h"
#undef KDef

/* 
 * Operators table (sorted at startup into name/arity order).
 */
#define OpDef(f)  &B##f,
struct c_proc *op_tbl[] = {
#include "../h/odefs.h"
};
#undef OpDef

/*
 * Function table
 */
#define FncDef(f)  &B##f,
struct c_proc *fnc_tbl[] = {
#include "../h/fdefs.h"
};
#undef FncDef

/*
 * Keyword table
 */
#define KDef(p,n) &L##p,
struct c_proc *keyword_tbl[] = {
#include "../h/kdefs.h"
};
#undef KDef

/*
 * Map from opcode to procedure block
 */
struct c_proc *opblks[] = {
	NULL,
#define OpDef(p) &B##p,
#include "../h/odefs.h"
#undef OpDef
   };

/*
 * Map from keyword number to procedure block
 */
struct c_proc *keyblks[] = {
    NULL,
#define KDef(p,n) &L##p,
#include "../h/kdefs.h"
#undef KDef
};

/*
 * Deferred and removed method stubs.
 */

function optional_method_stub()
   body {
      runerr(612);
   }
end

function native_method_stub()
   body {
      runerr(629);
   }
end

function abstract_method_stub()
   body {
      runerr(614);
   }
end

function removed_method_stub()
   body {
      runerr(628);
   }
end

/*
 * Various constant descriptors, initialised in init.r
 */

struct descrip nullptr;                 /* descriptor with null block pointer */
struct descrip blank; 			/* one-character blank string */
struct descrip emptystr; 		/* zero-length empty string */
struct descrip lcase;			/* string of lowercase letters */
struct descrip nulldesc;           	/* &null value */
struct descrip yesdesc;           	/* &yes value */
struct descrip onedesc;              	/* integer 1 */
struct descrip ucase;			/* string of uppercase letters */
struct descrip zerodesc;              	/* integer 0 */
struct descrip minusonedesc;           	/* integer -1 */
struct descrip thousanddesc;	        /* 1000 */
struct descrip milliondesc;	        /* 1000000 */
struct descrip billiondesc;	        /* 10^9 */
struct descrip defaultwindowlabel;	/* ucs string, the default window label */

struct b_cset *emptycs;   /* '' */
struct b_cset *blankcs;   /* ' ' */
struct b_cset *lparcs;    /* '(' */
struct b_cset *rparcs;    /* ')' */

/*
 * Descriptors used by event monitoring.
 */
struct descrip csetdesc;
struct descrip rzerodesc;

struct b_cset *k_ascii;	        /* value of &ascii */
struct b_cset *k_cset;	        /* value of &cset */
struct b_cset *k_uset;	        /* value of &uset */
struct b_cset *k_digits;	/* value of &lcase */
struct b_cset *k_lcase;	        /* value of &lcase */
struct b_cset *k_letters;	/* value of &letters */
struct b_cset *k_ucase;	        /* value of &ucase */

struct b_ucs *emptystr_ucs;     /* ucs empty string */
struct b_ucs *blank_ucs;        /* ucs blank string */

/*
 * An array of all characters for use in making one-character strings.
 */
char *allchars = 
    "\000\001\002\003\004\005\006\007"
    "\010\011\012\013\014\015\016\017"
    "\020\021\022\023\024\025\026\027"
    "\030\031\032\033\034\035\036\037"
    "\040\041\042\043\044\045\046\047"
    "\050\051\052\053\054\055\056\057"
    "\060\061\062\063\064\065\066\067"
    "\070\071\072\073\074\075\076\077"
    "\100\101\102\103\104\105\106\107"
    "\110\111\112\113\114\115\116\117"
    "\120\121\122\123\124\125\126\127"
    "\130\131\132\133\134\135\136\137"
    "\140\141\142\143\144\145\146\147"
    "\150\151\152\153\154\155\156\157"
    "\160\161\162\163\164\165\166\167"
    "\170\171\172\173\174\175\176\177"
    "\200\201\202\203\204\205\206\207"
    "\210\211\212\213\214\215\216\217"
    "\220\221\222\223\224\225\226\227"
    "\230\231\232\233\234\235\236\237"
    "\240\241\242\243\244\245\246\247"
    "\250\251\252\253\254\255\256\257"
    "\260\261\262\263\264\265\266\267"
    "\270\271\272\273\274\275\276\277"
    "\300\301\302\303\304\305\306\307"
    "\310\311\312\313\314\315\316\317"
    "\320\321\322\323\324\325\326\327"
    "\330\331\332\333\334\335\336\337"
    "\340\341\342\343\344\345\346\347"
    "\350\351\352\353\354\355\356\357"
    "\360\361\362\363\364\365\366\367"
    "\370\371\372\373\374\375\376\377";


/*
 * A number of important variables follow.
 */

int set_up = 0;				/* set-up switch */
word starttime;                         /* used with millisec() for calculating &time */
char *currend = NULL;			/* current end of memory region */
word memcushion = RegionCushion;	/* memory region cushion factor */
word memgrowth = RegionGrowth;		/* memory region growth factor */
double defaultfontsize = DefaultFontSize;
char *defaultfont = DefaultFont;
double defaultleading = DefaultLeading;
word defaultipver = DefaultIPVer;                  /* default ip version for dns lookup */

word dodump = 1;			/* if zero never core dump;
                                         * if 1 core dump on C-level internal error (call to syserr)
                                         * if 2 core dump on all errors
                                         */

uword coexp_ser = 1;                     /* Serial numbers for object creation */
uword list_ser = 1;
uword set_ser = 1;
uword table_ser = 1;
uword weakref_ser = 1;
uword methp_ser = 1;

struct progstate *progs;                 /* list of progstates */
struct tend_desc *tendedlist = NULL;     /* chain of tended descriptors */
struct region rootstring, rootblock;
struct progstate *curpstate = &rootpstate;
struct progstate rootpstate;

int op_tbl_sz = ElemCount(op_tbl);
int fnc_tbl_sz = ElemCount(fnc_tbl);
int keyword_tbl_sz = ElemCount(keyword_tbl);

#include "exported.ri"

/*
 * Check the version number of the icode matches the interpreter version.
 * The string must equal IVersion or IVersion || "Z".
 */
static int check_version(struct header *hdr)
{
    return strncmp((char *)hdr->Config, IVersion, strlen(IVersion)) == 0 && 
        ((((char *)hdr->Config)[strlen(IVersion)]) == 0 ||
         strcmp(((char *)hdr->Config) + strlen(IVersion), "Z") == 0);
}

/*
 * For sorting/searching op_tbl
 */
static int opcmp1(struct c_proc *p, dptr name, int arity)
{
    int i;
    i = lexcmp(p->name, name);
    if (i == 0)
        i = p->nparam - arity;
    return i;
}

static int opcmp2(struct c_proc **p1, struct c_proc **p2)
{
    return opcmp1(*p1, (*p2)->name, (*p2)->nparam);
}

/*
 * Lookup an operator with the given name (eg "+"), and arity (1-3).
 */
struct c_proc *lookup_operator(dptr name, int arity)
{
    int i, l, r, m;
    l = 0;
    r = op_tbl_sz - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = opcmp1(op_tbl[m], name, arity);
        if (i > 0)
            r = m - 1;
        else if (i < 0)
            l = m + 1;
        else  /* i == 0 */
            return op_tbl[m];
    }
    return NULL;
}

/*
 * proc_name_cmp - do a string comparison of a descriptor to the procedure 
 *   name in a c_proc struct; used in call to bsearch().
 */
static int proc_name_cmp(dptr dp, struct c_proc **e)
{
    return lexcmp(dp, (*e)->name);
}

struct c_proc *lookup_function(dptr name)
{
    struct c_proc **p;
    p = bsearch(name, fnc_tbl, fnc_tbl_sz,
                sizeof(struct c_proc *), 
                (BSearchFncCast)proc_name_cmp);
    return p ? *p : NULL;
}

struct c_proc *lookup_keyword(dptr name)
{
      struct c_proc **p;
      p = bsearch(name, keyword_tbl, keyword_tbl_sz,
                  sizeof(struct c_proc *), 
                  (BSearchFncCast)proc_name_cmp);
      return p ? *p : NULL;
}


/*
 * Get the global descriptor for the main procedure in prog, or signal
 * a fatal error if it is not found.
 */
static dptr get_main(struct progstate *prog)
{
    static struct sdescrip ms = {4, "main"};
    dptr t;
    if ((t = lookup_named_global((dptr)&ms, 1, prog)) && is:proc(*t))
        return t;
    fatalerr(117, NULL);
    return 0;           /* Not reached */
}

/*
 * Open the icode file and read the header, stopping with a fatal
 * error on a problem.
 */
static FILE *readhdr_strict(char *name, struct header *hdr)
{
    FILE *ifile;
    char buf[200];

    ifile = fopen(name, ReadBinary);
    if (ifile == NULL)
        ffatalerr("Can't open interpreter file %s: %s", name, get_system_error());

    for (;;) {
        if (fgets(buf, sizeof(buf), ifile) == NULL)
            ffatalerr("Can't find header marker in interpreter file %s", name);
        if (match_delim(buf))
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), ifile) != sizeof(*hdr))
        ffatalerr("Can't read interpreter file header in file %s", name);

    if (!check_version(hdr)) {
        fprintf(stderr, "Icode version mismatch in %s\n", name);
        fprintf(stderr, "\tIcode version: %s\n", (char *)hdr->Config);
        fprintf(stderr, "\tExpected version: %s\n", IVersion);
        ffatalerr("Cannot run %s", name);
    }

    return ifile;
}

/*
 * Open the icode file and read the header, returning null and setting
 * &why on an error.
 */
static FILE *readhdr_liberal(char *name, struct header *hdr)
{
    FILE *ifile;
    char buf[200];

    ifile = fopen(name, ReadBinary);
    if (ifile == NULL) {
        errno2why();
        return NULL;
    }

    for (;;) {
        if (fgets(buf, sizeof(buf), ifile) == NULL) {
            LitWhy("Can't find header marker");
            fclose(ifile);
            return NULL;
        }
        if (match_delim(buf))
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), ifile) != sizeof(*hdr)) {
        LitWhy("Can't read interpreter file header");
        fclose(ifile);
        return NULL;
    }

    if (!check_version(hdr)) {
        whyf("Version mismatch (%s -vs- %s)", (char *)hdr->Config, IVersion);
        fclose(ifile);
        return NULL;
    }

    return ifile;
}

static void read_icode(struct header *hdr, char *name, FILE *ifile, char *codeptr)
{
    word cbread;
#if HAVE_LIBZ
    if (strchr((char *)(hdr->Config), 'Z')) { /* to decompress */
        gzFile zfd;
#if MSWIN32
        int tmp = open(name, O_RDONLY | O_BINARY, 0);
#else
        int tmp = open(name, O_RDONLY);
#endif
        lseek(tmp, ftell(ifile), SEEK_SET);
        zfd = gzdopen(tmp, "r");
        if ((cbread = gzread(zfd, codeptr, hdr->IcodeSize)) != hdr->IcodeSize) {
            fprintf(stderr,"Tried to read " WordFmt " bytes of code, got " WordFmt "\n",
                    hdr->IcodeSize, cbread);
            ffatalerr("Bad icode file: %s", name);
        }
        gzclose(zfd);
    } else {
        if ((cbread = fread(codeptr, 1, hdr->IcodeSize, ifile)) != hdr->IcodeSize) {
            fprintf(stderr,"Tried to read " WordFmt " bytes of code, got " WordFmt "\n",
                    hdr->IcodeSize, cbread);
            ffatalerr("Bad icode file: %s", name);
        }
    }
#else					/* HAVE_LIBZ */
    if ((cbread = fread(codeptr, 1, hdr->IcodeSize, ifile)) != hdr->IcodeSize) {
        fprintf(stderr,"Tried to read " WordFmt " bytes of code, got " WordFmt "\n",
                hdr->IcodeSize, cbread);
        ffatalerr("Bad icode file: %s", name);
    }
#endif					/* HAVE_LIBZ */
}

#passthru #define _INT int
static struct b_cset *make_static_cset_block(int n_ranges, ...)
{
    struct b_cset *b;
    uword blksize;
    int i, j;
    va_list ap;
    va_start(ap, n_ranges);
    blksize = sizeof(struct b_cset) + ((n_ranges - 1) * sizeof(struct b_cset_range));
    b = safe_zalloc(blksize);
    b->title = T_Cset;
    b->blksize = blksize;
    b->n_ranges = n_ranges;
    b->size = 0;
    for (i = 0; i < n_ranges; ++i) {
        b->range[i].from = va_arg(ap, _INT);
        b->range[i].to = va_arg(ap, _INT);
        b->range[i].index = b->size;
        b->size += b->range[i].to - b->range[i].from + 1;
        for (j = b->range[i].from; j <= b->range[i].to; ++j) {
            if (j > 0xff)
                break;
            Setb(j, b->bits);
        }
    }
    va_end(ap);
    return b;
}

static struct b_ucs *make_static_ucs_block(char *utf8)
{
    word index_step, n_offs, offset_bits, n_off_words, length;
    uword blksize;
    char *t;
    struct b_ucs *b;
    word utf8_len;
    t = utf8;
    utf8_len = strlen(utf8);
    length = 0;
    while (*t) {
        t += UTF8_SEQ_LEN(*t);
        ++length;
    }
    calc_ucs_index_settings(utf8_len, length, &index_step, &n_offs, &offset_bits, &n_off_words);
    blksize = sizeof(struct b_ucs) + ((n_off_words - 1) * sizeof(word));
    b = safe_zalloc(blksize);
    b->title = T_Ucs;
    b->blksize = blksize;
    b->index_step = index_step;
    MakeStr(utf8, utf8_len, &b->utf8);
    b->length = length;
    b->n_off_l_indexed = b->n_off_r_indexed = 0;
    b->offset_bits = offset_bits;
    return b;
}

/*
 * env_int - get the value of an integer-valued environment variable.
 */
void env_int(char *name, int *variable, int min, int max)
{
    int t;
    char *value, ch;
    if ((value = getenv_nn(name)) == NULL)
        return;
    if (sscanf(value, "%d%c", &t, &ch) != 1)
        ffatalerr("Environment variable not numeric: %s=%s", name, value);
    if (t < min || t > max)
        ffatalerr("Environment variable out of range: %s=%s", name, value);
    *variable = t;
}

/*
 * env_word - get the value of an word-valued environment variable.
 */
void env_word(char *name, word *variable, word min, word max)
{
    word t;
    char *value, ch;
    if ((value = getenv_nn(name)) == NULL)
        return;
    if (sscanf(value, WordFmt "%c", &t, &ch) != 1)
        ffatalerr("Environment variable not numeric: %s=%s", name, value);
    if (t < min || t > max)
        ffatalerr("Environment variable out of range: %s=%s", name, value);
    *variable = t;
}

/*
 * env_uword - get the value of an uword-valued environment variable.
 */
void env_uword(char *name, uword *variable, uword min, uword max)
{
    uword t;
    char *value, ch;
    if ((value = getenv_nn(name)) == NULL)
        return;
    if (sscanf(value, UWordFmt "%c", &t, &ch) != 1)
        ffatalerr("Environment variable not numeric: %s=%s", name, value);
    if (t < min || t > max)
        ffatalerr("Environment variable out of range: %s=%s", name, value);
    *variable = t;
}

/*
 * env_double - get the value of a double-valued environment variable.
 */
void env_double(char *name, double *variable, double min, double max)
{
    double t;
    char *value, ch;
    if ((value = getenv_nn(name)) == NULL)
        return;
    if (sscanf(value, "%lf%c", &t, &ch) != 1)
        ffatalerr("Environment variable not numeric: %s=%s", name, value);
    if (t < min || t > max)
        ffatalerr("Environment variable out of range: %s=%s", name, value);
    *variable = t;
}

/*
 * env_string - get the value of a string environment variable.  If it
 * is present, it is saved and assigned to the variable.
 */
void env_string(char *name, char **variable)
{
    char *value;
    if ((value = getenv_nn(name)) == NULL)
        return;
    *variable = salloc(value);
}

/*
 * Termination routines.
 */


/*
 * syserr - print s as a system error.
 */
void syserr(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "System error");
    if (set_up) {
        struct ipc_line *pline;
        struct ipc_fname *pfile;

        pline = frame_ipc_line(curr_pf);
        pfile = frame_ipc_fname(curr_pf);

        if (pline && pfile) {
            struct descrip t;
            abbr_fname(pfile->fname, &t);
            fputs(" at ", stderr);
            begin_link(stderr, pfile->fname, pline->line);
            fprintf(stderr, "line " WordFmt " in %.*s", pline->line, StrF(t));
            end_link(stderr);
        } else
            fprintf(stderr, " at line ? in ?");
    }
    else
        fprintf(stderr, " in startup code");

    fputc('\n', stderr);
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    fflush(stderr);
    va_end(ap);

    if (set_up && !collecting) 		/* skip if start-up problem or collecting */
        traceback(k_current, 1, 1);

    if (dodump)
        abort();
    c_exit(EXIT_FAILURE);
}


/*
 * c_exit(i) - flush all buffers and exit with status i.
 */
void c_exit(int i)
{
    if (set_up && k_dump) {
        fprintf(stderr,"\nTermination dump:\n\n");
        fflush(stderr);
        xdisp(k_current, -1, stderr);
    }

#if MSWIN32
    PostQuitMessage(0);
#endif					/* MSWIN32 */

    exit(i);
}

/*
 * Check for fatal error recursion; this could happen if memory ran
 * out during printing of the traceback.
 */
void checkfatalrecurse(void)
{
    static int in_fatal = 0;
    if (in_fatal) {
        fprintf(stderr, "Recursive fatal errors - exiting.\n");
        c_exit(EXIT_FAILURE);
    }
    in_fatal = 1;
}

/*
 * fatalerr - disable error conversion and call run-time error routine.
 */
void fatalerr(int n, dptr v)
{
    kywd_handler = nulldesc;
    curpstate->monitor = 0;
    err_msg(n, v);
    /* Not reached */
}

/*
 * ffatalerr - like fatalerr, but takes an arbitrary format string
 * rather than an error number and value.
 */
void ffatalerr(char *fmt, ...)
{
    char *s;
    va_list ap;
    va_start(ap, fmt);
    s = salloc(buffvprintf(fmt, ap));
    va_end(ap);
    CMakeStr(s, &t_errortext);
    fatalerr(-1, 0);
    /* Not reached */
}

/*
 * initregion - initialization routine to allocate memory region
 */

static void initregion(struct region *r)
{
    Protect(r->free = r->base = padded_malloc(r->size), fatalerr(314, NULL));
    r->end = r->base + r->size;
}


static void initprogstate(struct progstate *p)
{
    p->monitor = 0;
    p->eventmask= emptycs;
    p->timer_interval = 1000;
    p->event_queue_head = p->event_queue_tail = 0;
    p->Kywd_handler = nulldesc;
    p->Kywd_pos = onedesc;
    p->Kywd_why = emptystr;
    p->Kywd_subject = emptystr;
    p->Kywd_ran = zerodesc;
    p->Kywd_trace = zerodesc;
    p->Kywd_dump = zerodesc;
    MakeInt(500, &p->Kywd_maxlevel);
    p->K_errornumber = 0;
    p->T_errornumber = 0;
    p->Have_errval = 0;
    p->T_have_val = 0;
    p->K_errortext = emptystr;
    p->K_errorvalue = nulldesc;
    p->K_errorcoexpr = 0;
    p->T_errorvalue = nulldesc;
    p->T_errortext = emptystr;
    gettimeofday(&p->start_time, 0);
    gettimeofday(&p->last_tick, 0);

    p->stringtotal = p->blocktotal = p->stackcurr = p->collected_user = 
        p->collected_stack = p->collected_string = p->collected_block = 0;

    p->Alccoexp = alccoexp_0;
    p->Alcbignum = alcbignum_0;
    p->Alccset = alccset_0;
    p->Alchash = alchash_0;
    p->Alcsegment = alcsegment_0;
    p->Alclist_raw = alclist_raw_0;
    p->Alclist = alclist_0;
    p->Alclstb = alclstb_0;
#if !RealInDesc
    p->Alcreal = alcreal_0;
#endif
    p->Alcrecd = alcrecd_0;
    p->Alcobject = alcobject_0;
    p->Alcmethp = alcmethp_0;
    p->Alcweakref = alcweakref_0;
    p->Alcucs = alcucs_0;
    p->Alcselem = alcselem_0;
    p->Alcstr = alcstr_0;
    p->Alcsubs = alcsubs_0;
    p->Alctelem = alctelem_0;
    p->Alctvtbl = alctvtbl_0;
    p->Dealcblk = dealcblk_0;
    p->Dealcstr = dealcstr_0;
    p->Reserve = reserve_0;
    p->GeneralCall = general_call_0;
    p->GeneralAccess = general_access_0;
    p->GeneralInvokef = general_invokef_0;
}

#define Relocate(w) w += p->Offset

static void initptrs(struct progstate *p, struct header *h)
{
    p->IcodeSize = h->IcodeSize;
    p->Offset = DiffPtrsBytes(p->Code, h->Base);
    if (p->Offset) {
        Relocate(h->ClassStatics);
        Relocate(h->ClassMethods);
        Relocate(h->ClassFields);
        Relocate(h->ClassFieldLocs);
        Relocate(h->Classes);
        Relocate(h->Records);
        Relocate(h->Fnames);
        Relocate(h->Globals);
        Relocate(h->Gnames);
        Relocate(h->Gflags);
        Relocate(h->Glocs);
        Relocate(h->Statics);
        Relocate(h->Snames);
        Relocate(h->TCaseTables);
        Relocate(h->Constants);
        Relocate(h->Strcons);
        Relocate(h->AsciiStrcons);
        Relocate(h->Filenms);
        Relocate(h->Linenums);
    }
    p->Ecode = (char *)h->ClassStatics;
    p->ClassStatics = (dptr)p->Ecode;
    p->ClassMethods = p->EClassStatics = (dptr)h->ClassMethods;
    p->EClassMethods = (dptr)h->ClassFields;
    p->ClassFields = (struct class_field *)p->EClassMethods;
    p->EClassFields = (struct class_field *)h->ClassFieldLocs;
    p->ClassFieldLocs = (struct loc *)p->EClassFields;
    p->EClassFieldLocs = (struct loc *)h->Classes;
    p->Fnames  = (dptr *)h->Fnames;
    p->Efnames = (dptr *)h->Globals;
    p->Globals = (dptr)p->Efnames;
    p->Eglobals = (dptr)h->Gnames;
    p->Gnames = (dptr *)p->Eglobals;
    p->Egnames = (dptr *)h->Gflags;
    p->Gflags = (char *)p->Egnames;
    p->Egflags = (char *)h->Glocs;
    p->Glocs = (struct loc *)p->Egflags;
    p->Eglocs = (struct loc *)h->Statics;
    p->NGlobals = p->Eglobals - p->Globals;
    p->Statics = (dptr)p->Eglocs;
    p->Estatics = (dptr)h->Snames;
    p->NStatics = p->Estatics - p->Statics;
    p->Snames = (dptr *)p->Estatics;
    p->Esnames = (dptr *)h->TCaseTables;
    p->TCaseTables = (dptr)p->Esnames;
    p->ETCaseTables = (dptr)h->Filenms;
    p->NTCaseTables = p->ETCaseTables - p->TCaseTables;
    p->Filenms = (struct ipc_fname *)p->ETCaseTables;
    p->Efilenms = (struct ipc_fname *)h->Linenums;
    p->Ilines = (struct ipc_line *)p->Efilenms;
    p->Elines = (struct ipc_line *)h->Constants;
    p->Constants = (dptr)p->Elines;
    p->Econstants = (dptr)h->Strcons;
    p->NConstants = p->Econstants - p->Constants;
    p->Strcons = (char *)p->Econstants;
    p->AsciiStrcons = (char *)h->AsciiStrcons;
    p->Estrcons = (char *)(p->Code + h->IcodeSize);
}


#include "initiasm.ri"

static void handle_prog_exit()
{
    curpstate->exited = 1;
    /* If we have a monitor, switch back to it */
    if (curpstate->monitor)
        set_curpstate(curpstate->monitor);
}

" load a program corresponding to string s as a co-expression."

function lang_Prog_load(loadstring, arglist, blocksize, stringsize)
   if !cnv:C_string(loadstring) then
      runerr(103, loadstring)
   if !def:C_integer(blocksize, rootblock.size) then
      runerr(101, blocksize)
   if !def:C_integer(stringsize, rootstring.size) then
      runerr(101, stringsize)
    body {
       struct progstate *pstate;
       tended struct descrip result;
       tended struct b_coexpr *coex;
       struct header hdr;
       FILE *ifile;
       dptr main_proc;
       struct p_frame *new_pf;

       /*
        * arglist must be a list
        */
       if (!is:null(arglist) && !is:list(arglist))
           runerr(108,arglist);

       /*
        * open the icode file and read the header
        */
       ifile = readhdr_liberal(loadstring, &hdr);
       if (ifile == NULL)
           fail;

       /*
        * Allocate memory for icode and the struct that describes it
        */
       MemProtect(pstate = alcprog(hdr.Base, hdr.IcodeSize));
       MemProtect(coex = alccoexp());

       /*
        * Add to chain of progs.  Do this now since pstate has some
        * tended variables in it (K_current, K_main, Kywd_prog).
        */
       coex->main_of = pstate;
       coex->activator = coex;

       initprogstate(pstate);
       pstate->next = progs;
       progs = pstate;

       pstate->K_current = pstate->K_main = coex;

       if (stringsize <= 0) {
           pstate->stringregion = curpstate->stringregion;
       } else {
           pstate->stringregion = safe_malloc(sizeof(struct region));
           pstate->stringregion->size = stringsize;
           pstate->stringregion->compacted = 0;
           /*
            * the local program region list starts out with this region only
            */
           pstate->stringregion->prev = NULL;
           pstate->stringregion->next = NULL;
           /*
            * the global region list links this region with curpstate's
            */
           pstate->stringregion->Gprev = curpstate->stringregion;
           pstate->stringregion->Gnext = curpstate->stringregion->Gnext;
           if (curpstate->stringregion->Gnext)
               curpstate->stringregion->Gnext->Gprev = pstate->stringregion;
           curpstate->stringregion->Gnext = pstate->stringregion;
           initregion(pstate->stringregion);
       }

       if (blocksize <= 0) {
           pstate->blockregion = curpstate->blockregion;
       } else {
           pstate->blockregion = safe_malloc(sizeof(struct region));
           pstate->blockregion->size = blocksize;
           pstate->blockregion->compacted = 0;
           /*
            * the local program region list starts out with this region only
            */
           pstate->blockregion->prev = NULL;
           pstate->blockregion->next = NULL;
           /*
            * the global region list links this region with curpstate's
            */
           pstate->blockregion->Gprev = curpstate->blockregion;
           pstate->blockregion->Gnext = curpstate->blockregion->Gnext;
           if (curpstate->blockregion->Gnext)
               curpstate->blockregion->Gnext->Gprev = pstate->blockregion;
           curpstate->blockregion->Gnext = pstate->blockregion;
           initregion(pstate->blockregion);
       }

       CMakeStr(loadstring, &pstate->Kywd_prog);

       /*
        * Establish pointers to icode data regions.		[[I?]]
        */
       initptrs(pstate, &hdr);
       read_icode(&hdr, loadstring, ifile, pstate->Code);
       fclose(ifile);

       resolve(pstate);

       main_proc = get_main(pstate);
       {
           /*
            * Allocate the top frame in the new program; this ensures
            * set_curr_pf into this frame sets curpstate correctly.
            */
           struct progstate *t = curpstate;
           curpstate = pstate;
           MemProtect(new_pf = alc_p_frame(&Bmain_wrapper, 0));
           curpstate = t;
       }
       new_pf->tmp[0] = *main_proc;
       coex->sp = (struct frame *)new_pf;
       coex->base_pf = coex->curr_pf = new_pf;
       coex->start_label = new_pf->ipc = Bmain_wrapper.icode;
       coex->failure_label = 0;
       coex->tvalloc = 0;
       coex->level = 0;

       if (ProcBlk(*main_proc).nparam) {
           if (is:null(arglist))
               create_list(0, &new_pf->tmp[1]);
           else
               new_pf->tmp[1] = arglist;
       }

       MakeDesc(D_Coexpr, coex, &result);

      return result;
      }
end

#define NativeDef(class,field,func) extern struct c_proc B##func##;
#include "../h/nativedefs.h"
#undef NativeDef

static struct c_proc *native_methods[] = {
#define NativeDef(class,field,func) &B##func##,
#include "../h/nativedefs.h"
#undef NativeDef
};

#undef Relocate
#define Relocate(ptr) ptr = (void *)((char *)(ptr) + p->Offset)

/*
 * resolve - perform various fix-ups on the data read from the icode
 *  file.
 */
static void resolve(struct progstate *p)
{
    /* printf("%s\n",p->Offset?"slow":"quick"); */
    if (p->Offset)
        slow_resolve(p);
    else
        quick_resolve(p);
}

static void slow_resolve(struct progstate *p)
{
    word i, j, n_fields;
    struct p_proc *pp;
    struct c_proc *cp;
    struct class_field *cf;
    dptr *dpp;
    struct ipc_fname *fnptr;
    struct ipc_line *lineptr;
    struct loc *lp;

    /*
     * Relocate descriptors in the constants table, and their blocks for non-strings.
     */
    for (j = 0; j < p->NConstants; j++) {
        if (Qual(p->Constants[j]))
            Relocate(StrLoc(p->Constants[j]));
        else {
            Relocate(BlkLoc(p->Constants[j]));
            if (p->Constants[j].dword == D_Ucs) {
                struct b_ucs *ub = &UcsBlk(p->Constants[j]);
                /* Relocate the utf8 string */
                Relocate(StrLoc(ub->utf8));
            }
        }
    }

    /*
     * Relocate the names of the fields.
     */
    for (dpp = p->Fnames; dpp < p->Efnames; dpp++)
        Relocate(*dpp);

    /*
     * For each class field info block, relocate the pointer to the
     * defining class and the descriptor.
     */
    for (cf = p->ClassFields; cf < p->EClassFields; cf++) {
        Relocate(cf->defining_class);
        if (cf->field_descriptor) {
            Relocate(cf->field_descriptor);
            /* Follow the same logic as lcode.c */
            if (cf->flags & M_Method) {
                if (cf->flags & M_Removed) {
                    BlkLoc(*cf->field_descriptor) = (union block *)&Bremoved_method_stub;
                } else if (cf->flags & M_Native) {
                    int n = IntVal(*cf->field_descriptor);
                    if (n == -1) {
                        /* Unresolved, point to stub */
                        BlkLoc(*cf->field_descriptor) = (union block *)&Bnative_method_stub;
                    } else {
                        struct descrip t;
                        /* Resolved to native method, do sanity checks, set pointer */
                        if (n < 0 || n >= ElemCount(native_methods))
                            ffatalerr("Native method index out of range: %d", n);
                        cp = (struct c_proc *)native_methods[n];
                        /* Clone the c_proc if we're using this block
                         * already in another program; we don't want
                         * to change the original's reference to the
                         * corresponding field (cp->field)
                         */
                        if (cp->field)
                            cp = (struct c_proc *)clone_b_proc((struct b_proc *)cp);
                        t = *p->Fnames[cf->fnum];
                        /* The field name should match the end of the procedure block's name */
                        if (strncmp(StrLoc(t),
                                    StrLoc(*cp->name) + StrLen(*cp->name) - StrLen(t),
                                    StrLen(t)))
                            ffatalerr("Native method name mismatch: %.*s", 
                                      (int)StrLen(t), StrLoc(t));
                        /* Pointer back to the corresponding field */
                        cp->field = cf;
                        BlkLoc(*cf->field_descriptor) = (union block *)cp;
                    }
                } else if (cf->flags & M_Optional)
                    BlkLoc(*cf->field_descriptor) = (union block *)&Boptional_method_stub;
                else if (cf->flags & M_Abstract)
                    BlkLoc(*cf->field_descriptor) = (union block *)&Babstract_method_stub;
                else {
                    /*
                     * Method in the icode file, relocate the entry point
                     * and the names of the parameters, locals, and static
                     * variables.
                     */
                    Relocate( BlkLoc(*cf->field_descriptor) );
                    pp = (struct p_proc *)&ProcBlk(*cf->field_descriptor);
                    /* Pointer back to the corresponding field (could equally Relocate this one). */
                    pp->field = cf;
                    /* Relocate the name */
                    Relocate(pp->name);
                    /* The entry point */
                    Relocate(pp->icode);
                    relocate_code(p, pp->icode);
                    /* The statics */
                    if (pp->fstatic)
                        Relocate(pp->fstatic);
                    /* The two tables */
                    Relocate(pp->lnames);
                    if (pp->llocs)
                        Relocate(pp->llocs);
                    /* The variables */
                    for (i = 0; i < pp->nparam + pp->ndynam + pp->nstatic; i++) {
                        Relocate(pp->lnames[i]);
                        if (pp->llocs)
                            Relocate(pp->llocs[i].fname);
                    }
                    pp->program = p;
                }
            }
        }
    }

    /*
     * Relocate the field location file names.
     */
    for (lp = p->ClassFieldLocs; lp < p->EClassFieldLocs; lp++)
        Relocate(lp->fname);

    /*
     * Relocate the names of the global variables.
     */
    for (dpp = p->Gnames; dpp < p->Egnames; dpp++)
        Relocate(*dpp);

    /*
     * Relocate the names of the static variables.
     */
    for (dpp = p->Snames; dpp < p->Esnames; dpp++)
        Relocate(*dpp);

    /*
     * Relocate the location file names of the global variables.
     */
    for (lp = p->Glocs; lp < p->Eglocs; lp++)
        if (lp->fname)    /* Null implies builtin */
            Relocate(lp->fname);

    /*
     * Scan the global variable array and relocate all blocks, and
     * create the table of named globals.
     */
    for (j = 0; j < p->NGlobals; j++) {
        switch (p->Globals[j].dword) {
            case D_Class: {
                struct b_class *cb;
                Relocate(BlkLoc(p->Globals[j]));
                cb = &ClassBlk(p->Globals[j]);
                Relocate(cb->name);
                if (cb->init_field)
                    Relocate(cb->init_field);
                if (cb->new_field)
                    Relocate(cb->new_field);
                cb->program = p;
                n_fields = cb->n_class_fields + cb->n_instance_fields;
                Relocate(cb->supers);
                for (i = 0; i < cb->n_supers; ++i) 
                    Relocate(cb->supers[i]);
                Relocate(cb->implemented_classes);
                for (i = 0; i < cb->n_implemented_classes; ++i) 
                    Relocate(cb->implemented_classes[i]);
                Relocate(cb->fields);
                for (i = 0; i < n_fields; ++i) 
                    Relocate(cb->fields[i]);
                Relocate(cb->sorted_fields);
                break;
            }
            case D_Constructor: {
                struct b_constructor *c;
                Relocate(BlkLoc(p->Globals[j]));
                c = &ConstructorBlk(p->Globals[j]);
                c->program = p;
                Relocate(c->fnums);
                if (c->field_locs)
                    Relocate(c->field_locs);
                Relocate(c->sorted_fields);
                /*
                 * Relocate the name and loc'ns
                 */
                Relocate(c->name);
                if (c->field_locs) {
                    for (i = 0; i < c->n_fields; i++) 
                        Relocate(c->field_locs[i].fname);
                }
                break;
            }
            case D_Proc: {
                if (p->Gflags[j] & G_Builtin) {
                    /*
                     * It is a builtin function.  Calculate the index and carry out
                     * some sanity checks on it.
                     */
                    int n = IntVal(p->Globals[j]);
                    if (n < 0 || n >= fnc_tbl_sz)
                        ffatalerr("Builtin function index out of range: %d", n);
                    BlkLoc(p->Globals[j]) = (union block *)fnc_tbl[n];
                    if (!equiv(p->Gnames[j], fnc_tbl[n]->name))
                        ffatalerr("Builtin function index name mismatch: %.*s", 
                                  (int)StrLen(*p->Gnames[j]), StrLoc(*p->Gnames[j]));
                }
                else {
                    /*
                     * p->Globals[j] points to an Icon procedure.
                     */
                    Relocate(BlkLoc(p->Globals[j]));
                    pp = (struct p_proc *)&ProcBlk(p->Globals[j]);

                    /*
                     * Relocate the address of the name of the procedure.
                     */
                    Relocate(pp->name);

                    /* The statics */
                    if (pp->fstatic)
                        Relocate(pp->fstatic);

                    /*
                     * This is an Icon procedure.  Relocate the entry point and
                     *	the names of the parameters, locals, and static variables.
                     */
                    Relocate(pp->icode);
                    relocate_code(p, pp->icode);
                    Relocate(pp->lnames);
                    if (pp->llocs)
                        Relocate(pp->llocs);
                    for (i = 0; i < pp->nparam + pp->ndynam + pp->nstatic; i++) {
                        Relocate(pp->lnames[i]);
                        if (pp->llocs)
                            Relocate(pp->llocs[i].fname);
                    }
                    pp->program = p;
                }
                break;
            }
            case D_Null: {
                dptr_list_add(&p->global_vars, &p->Globals[j]);
                break;
            }
            default: {
                ffatalerr("Invalid descriptor in global table");
                break;
            }
        }
    }

    /*
     * Relocate the names of the files in the ipc->filename table and the ipc offsets.
     */
    for (fnptr = p->Filenms; fnptr < p->Efilenms; ++fnptr) {
        Relocate(fnptr->fname);
        Relocate(fnptr->ipc);
    }

    /*
     * Relocate the ipc offsets in the linenumber table.
     */
    for (lineptr = p->Ilines; lineptr < p->Elines; ++lineptr)
        Relocate(lineptr->ipc);
}

/*
 * A simplified but much faster version of slow_resolve, which we can use if Offset == 0.
 */
static void quick_resolve(struct progstate *p)
{
    word j;
    struct p_proc *pp;
    struct c_proc *cp;
    struct class_field *cf;

    for (cf = p->ClassFields; cf < p->EClassFields; cf++) {
        if (cf->field_descriptor) {
            /* Follow the same logic as lcode.c */
            if (cf->flags & M_Method) {
                if (cf->flags & M_Removed) {
                    BlkLoc(*cf->field_descriptor) = (union block *)&Bremoved_method_stub;
                } else if (cf->flags & M_Native) {
                    int n = IntVal(*cf->field_descriptor);
                    if (n == -1) {
                        /* Unresolved, point to stub */
                        BlkLoc(*cf->field_descriptor) = (union block *)&Bnative_method_stub;
                    } else {
                        struct descrip t;
                        /* Resolved to native method, do sanity checks, set pointer */
                        if (n < 0 || n >= ElemCount(native_methods))
                            ffatalerr("Native method index out of range: %d", n);
                        cp = (struct c_proc *)native_methods[n];
                        /* Clone the c_proc if we're using this block
                         * already in another program; we don't want
                         * to change the original's reference to the
                         * corresponding field (cp->field)
                         */
                        if (cp->field)
                            cp = (struct c_proc *)clone_b_proc((struct b_proc *)cp);
                        t = *p->Fnames[cf->fnum];
                        /* The field name should match the end of the procedure block's name */
                        if (strncmp(StrLoc(t),
                                    StrLoc(*cp->name) + StrLen(*cp->name) - StrLen(t),
                                    StrLen(t)))
                            ffatalerr("Native method name mismatch: %.*s", 
                                      (int)StrLen(t), StrLoc(t));
                        /* Pointer back to the corresponding field */
                        cp->field = cf;
                        BlkLoc(*cf->field_descriptor) = (union block *)cp;
                    }
                } else if (cf->flags & M_Optional)
                    BlkLoc(*cf->field_descriptor) = (union block *)&Boptional_method_stub;
                else if (cf->flags & M_Abstract)
                    BlkLoc(*cf->field_descriptor) = (union block *)&Babstract_method_stub;
                else {
                    pp = (struct p_proc *)&ProcBlk(*cf->field_descriptor);
                    pp->program = p;
                }
            }
        }
    }

    for (j = 0; j < p->NGlobals; j++) {
        switch (p->Globals[j].dword) {
            case D_Class: {
                ClassBlk(p->Globals[j]).program = p;
                break;
            }
            case D_Constructor: {
                ConstructorBlk(p->Globals[j]).program = p;
                break;
            }
            case D_Proc: {
                if (p->Gflags[j] & G_Builtin) {
                    /*
                     * It is a builtin function.  Calculate the index and carry out
                     * some sanity checks on it.
                     */
                    int n = IntVal(p->Globals[j]);
                    if (n < 0 || n >= fnc_tbl_sz)
                        ffatalerr("Builtin function index out of range: %d", n);
                    BlkLoc(p->Globals[j]) = (union block *)fnc_tbl[n];
                    if (!equiv(p->Gnames[j], fnc_tbl[n]->name))
                        ffatalerr("Builtin function index name mismatch: %.*s", 
                                  (int)StrLen(*p->Gnames[j]), StrLoc(*p->Gnames[j]));
                }
                else {
                    /*
                     * p->Globals[j] points to an Icon procedure.
                     */
                    pp = (struct p_proc *)&ProcBlk(p->Globals[j]);
                    pp->program = p;
                }
                break;
            }
            case D_Null: {
                dptr_list_add(&p->global_vars, &p->Globals[j]);
                break;
            }
            default: {
                ffatalerr("Invalid descriptor in global table");
                break;
            }
        }
    }
}

int main(int argc, char **argv)
{
    int i;
    struct fileparts *fp;
    dptr main_proc;
    struct p_frame *frame;
    struct header hdr;
    FILE *ifile = 0;
    char *t, *name;
    uint64_t pmem;
    double d;

#if MSWIN32
    int hide_console = 0;
    WSADATA cData;
    WSAStartup(MAKEWORD(2, 2), &cData);
    /* Set binary mode on stdin, stdout and stderr */
    _setmode(0, _O_BINARY);
    _setmode(1, _O_BINARY);
    _setmode(2, _O_BINARY);
    env_int("OI_HIDE_CONSOLE", &hide_console, 0, 1);
    if (hide_console) {
        HWND w;
        w = GetConsoleWindow();
        if (w)
            ShowWindow(w, SW_HIDE);
    }
#endif

    fp = fparse(argv[0]);

    /*
     * if argv[0] is not a reference to our interpreter, take it as the
     * name of the icode file, and back up for it.
     */
    if (strcasecmp(fp->name, "oix") != 0) {
        argv--;
        argc++;
    }

    if (argc < 2) 
        ffatalerr("No icode file specified");

    name = argv[1];

    /*
     * Initializations that cannot be performed statically (at least for
     * some compilers).					[[I?]]
     */
    qsort(op_tbl, op_tbl_sz, sizeof(struct c_proc *),(QSortFncCast)opcmp2);

    LitStr(" ", &blank);
    LitStr("", &emptystr);
    LitStr("abcdefghijklmnopqrstuvwxyz", &lcase);
    LitStr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", &ucase);
    MakeInt(0, &zerodesc);
    MakeInt(1, &onedesc);
    MakeInt(-1, &minusonedesc);
    MakeInt(1000000000, &billiondesc);
    MakeInt(1000000, &milliondesc);
    MakeInt(1000, &thousanddesc);

    MakeDesc(D_TendPtr, 0, &nullptr);
    MakeDesc(D_Null, 0, &nulldesc);
    MakeDesc(D_Yes, 0, &yesdesc);

#if !RealInDesc
    {
        static struct b_real realzero;
        BlkLoc(rzerodesc) = (union block *)&realzero;
    }
#endif
    d = 0.0;
    DSetReal(d, rzerodesc);
    rzerodesc.dword = D_Real;

    k_cset = make_static_cset_block(1, 0, 255);
    k_uset = make_static_cset_block(1, 0, MAX_CODE_POINT);
    k_ascii = make_static_cset_block(1, 0, 127);
    k_digits = make_static_cset_block(1, '0', '9');
    k_lcase = make_static_cset_block(1, 'a', 'z');
    k_ucase = make_static_cset_block(1, 'A', 'Z');
    k_letters = make_static_cset_block(2, 'A', 'Z', 'a', 'z');
    lparcs = make_static_cset_block(1, '(', '(');
    rparcs = make_static_cset_block(1, ')', ')');
    blankcs = make_static_cset_block(1, ' ', ' ');
    emptycs = make_static_cset_block(0);

    emptystr_ucs = make_static_ucs_block("");
    blank_ucs = make_static_ucs_block(" ");
    MakeDesc(D_Ucs, make_static_ucs_block("Object Icon"), &defaultwindowlabel);
    MakeDesc(D_Cset, k_cset, &csetdesc);

    /*
     * Initialize root pstate.
     */
    progs = &rootpstate;
    initprogstate(&rootpstate);

    rootpstate.stringregion = &rootstring;
    rootpstate.blockregion = &rootblock;

    pmem = physicalmemorysize();
    if (pmem == 0)  /* If unknown, assume 2GB */
        pmem = (uint64_t)2 * 1024 * 1024 * 1024;

    rootstring.size = Min(Max(pmem / 256, MinDefStrSpace), MaxDefStrSpace);
    rootblock.size  = Min(Max(WordSize * (pmem / 1024), MinDefAbrSize), MaxDefAbrSize);

    t = findexe(name);
    if (!t)
        ffatalerr("Not found on PATH: %s", name);

    name = salloc(t);

    ifile = readhdr_strict(name, &hdr);

    CMakeStr(name, &rootpstate.Kywd_prog);

    /*
     * Examine the environment and make appropriate settings.    [[I?]]
     */
    env_word(TRACE, &k_trace, MinWord, MaxWord);
    env_word("OI_MAX_LEVEL", &k_maxlevel, 16, MaxWord);
    env_uword("OI_STRING_SIZE", &rootstring.size, 1024, MaxUWord);
    env_uword("OI_BLOCK_SIZE", &rootblock.size, 1024, MaxUWord); 
    env_word("OI_MEM_CUSHION", &memcushion, 0, 100);   /* max 100 % */
    env_word("OI_MEM_GROWTH", &memgrowth, 0, 10000);   /* max 100x growth */
    env_word("OI_CORE", &dodump, 0, 2);
    stacklim = rootblock.size / 2;
    env_uword("OI_STACK_LIMIT", &stacklim, 1024, MaxUWord);
    env_word("OI_STACK_CUSHION", &stackcushion, 0, 10000);
    env_double("OI_FONT_SIZE", &defaultfontsize, MIN_FONT_SIZE, 1e32);
    env_double("OI_LEADING", &defaultleading, 0.0, 1e32);
    env_word("OI_IP_VERSION", &defaultipver, 0, 64);
    if (!(defaultipver == 4 || defaultipver == 6 || defaultipver == 46 || defaultipver == 64 || defaultipver == 0))
        ffatalerr("Environment variable has invalid value: OI_IP_VERSION=" WordFmt, defaultipver);
    env_string("OI_FONT", &defaultfont);

    Protect(rootpstate.Code = icode_alloc((void *)hdr.Base, hdr.IcodeSize), fatalerr(315, NULL));

    /*
     * Establish pointers to icode data regions.		[[I?]]
     */
    initptrs(&rootpstate, &hdr);


    /*
     * Allocate memory for block & string regions.
     */
    initregion(rootpstate.stringregion);
    initregion(rootpstate.blockregion);

    /*
     * Allocate and initialize &main.
     */

    Protect(k_current = alccoexp(), fatalerr(303, NULL));
    rootpstate.K_current = rootpstate.K_main = k_current;
    k_current->level = 0;
    k_current->main_of = &rootpstate;
    k_current->activator = k_current;
    k_current->failure_label = 0;
    k_current->tvalloc = 0;

    read_icode(&hdr, name, ifile, code);
    fclose(ifile);

    /*
     * Resolve references from icode to run-time system.
     */
    resolve(&rootpstate);

    /*
     * Start timing execution.
     */
    starttime = millisec();

    main_proc = get_main(&rootpstate);

    MemProtect(frame = alc_p_frame(&Bmain_wrapper, 0));
    frame->tmp[0] = *main_proc;
    /*
     * Only create an args list if main has a parameter; otherwise args[1]
     * is just left as &null.
     */
    if (ProcBlk(*main_proc).nparam) {
        tended struct descrip args;
        create_list(argc - 2, &args);
        for (i = 2; i < argc; i++) {
            struct descrip t;
            CMakeStr(argv[i], &t);
            list_put(&args, &t);
        }
        frame->tmp[1] = args;
    }
    k_current->sp = (struct frame *)frame;
    curr_pf = k_current->curr_pf = k_current->base_pf = frame;
    ipc = k_current->start_label = frame->ipc = frame->proc->icode;

    set_up = 1;			/* post fact that iconx is initialized */
    interp();
    c_exit(EXIT_SUCCESS);

    return 0;
}

static word *pc;
static struct progstate *prog;

static void conv_addr()
{
    *pc += prog->Offset;
    ++pc;
}

static void conv_var()
{
    switch (*pc++) {
        case Op_Self:
        case Op_Knull:
        case Op_Kyes:
        case Op_Nil: {
            break;
        }
        case Op_Static:
        case Op_GlobalVal:
        case Op_Global:
        case Op_Const: {
            conv_addr();
            break;
        }

        case Op_Int:
#if RealInDesc
        case Op_Real:
#endif
        case Op_FrameVar:
        case Op_Tmp: {
            ++pc;
            break;
        }

        default: {
            syserr("Invalid opcode in conv_var: %d", (int)pc[-1]);
            break;
        }
    }
}

static void relocate_code(struct progstate *ps, word *c)
{
    prog = ps;
    pc = c;
    for (;;) {
        switch (*pc++) {
            case Op_Goto: {
                conv_addr();
                break;
            }
            case Op_IGoto:
            case Op_Mark:
            case Op_Unmark: {
                ++pc;
                break;
            }
            case Op_Deref:
            case Op_Move: {
                conv_var();
                conv_var();
                break;
            }

            case Op_MoveLabel: {
                ++pc;
                conv_addr();
                break;
            }

            /* Monogenic binary ops */
            case Op_Asgn1: 
            case Op_Swap1:
            case Op_Cat: 
            case Op_Diff:
            case Op_Div:
            case Op_Inter:
            case Op_Lconcat:
            case Op_Minus:
            case Op_Mod:
            case Op_Mult:
            case Op_Plus:
            case Op_Power:
            case Op_Union: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                break;
            }

            /* Binary ops */
            case Op_Asgn:
            case Op_Activate:
            case Op_Eqv:
            case Op_Lexeq:
            case Op_Lexge:
            case Op_Lexgt:
            case Op_Lexle:
            case Op_Lexlt:
            case Op_Lexne:
            case Op_Neqv:
            case Op_Numeq:
            case Op_Numge:
            case Op_Numgt:
            case Op_Numle:
            case Op_Numlt:
            case Op_Numne: 
            case Op_Swap: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Subsc: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                ++pc;        /* rval */
                conv_addr(); /* failure label */
                break;
            }

            /* Monogenic unary ops */
            case Op_Value:
            case Op_Size:
            case Op_Refresh:
            case Op_Number:
            case Op_Compl:
            case Op_Neg: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                break;
            }

            /* Unary ops */
            case Op_Nonnull:
            case Op_Null: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_addr(); /* failure label */
                break;
            }
            case Op_Random: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                ++pc;        /* rval */
                conv_addr(); /* failure label */
                break;
            }

            /* Unary closures */
            case Op_Tabmat:
            case Op_Bang: {
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                ++pc;        /* rval */
                conv_addr(); /* failure label */
                break;
            }

            /* Binary closures */
            case Op_Rasgn:
            case Op_Rswap:{
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                ++pc;        /* rval */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Toby: {
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                conv_var();  /* arg3 */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Sect: {
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                conv_var();  /* arg3 */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Keyop: {
                ++pc;            /* keyword */
                conv_var();  /* lhs */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Keyclo: {
                pc += 2;         /* keyword, clo */
                conv_var();  /* lhs */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Resume: {
                ++pc;            /* clo */
                break;
            }

            case Op_Pop: {
                break;
            }

            case Op_PopRepeat: {
                break;
            }

            case Op_Fail: {
                break;
            }

            case Op_Return:
            case Op_Suspend: {
                conv_var();  /* val */
                break;
            }

            case Op_ScanSwap: {
                pc += 2;
                break;
            }

            case Op_ScanRestore: {
                pc += 2;
                break;
            }

            case Op_ScanSave: {
                conv_var();  /* val */
                pc += 2;     /* tmp indices */
                break;
            }

            case Op_Limit: {
                conv_var();  /* limit */
                break;
            }

            case Op_Invoke: {
                word n;
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* expr */
                n = *pc++;       /* argc */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                while (n--)
                    conv_var();  /* arg */
                break;
            }

            case Op_Apply: {
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                conv_var();  /* arg2 */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                break;
            }

            case Op_Invokef: {
                word n;
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* expr */
                pc += 3;         /* fnum, inline cache */
                n = *pc++;       /* argc */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                while (n--)
                    conv_var();  /* arg */
                break;
            }

            case Op_Applyf: {
                ++pc;            /* clo */
                conv_var();  /* lhs */
                conv_var();  /* arg1 */
                pc += 3;         /* fnum, inline cache */
                conv_var();  /* arg2 */
                ++pc;            /* rval */
                conv_addr(); /* failure label */
                break;
            }

            case Op_EnterInit: {
                conv_addr();
                break;
            }

            case Op_Custom: {
                ++pc;
                break;
            }

            case Op_Halt: {
                break;
            }

            case Op_SysErr: {
                break;
            }

            case Op_MakeList: {
                int n;
                conv_var();  /* lhs */
                n = *pc++;       /* argc */
                while (n--)
                    conv_var();  /* arg */
                break;
            }

            case Op_Field: {
                conv_var();  /* lhs */
                conv_var();  /* expr */
                pc += 3;         /* fnum, inline cache */
                break;
            }

            case Op_Create: {
                conv_var();  /* lhs */
                conv_addr(); /* start label */
                break;
            }

            case Op_Coret: {
                conv_var();  /* value */
                break;
            }

            case Op_Cofail: {
                break;
            }

            case Op_TCaseInit: {
                conv_addr();
                ++pc;          /* size */
                conv_addr();   /* def */
                break;
            }

            case Op_TCaseInsert: {
                conv_addr();
                conv_var();  /* val */
                conv_addr();   /* entry */
                break;
            }

            case Op_TCaseChoose: {
                conv_addr();
                conv_var();  /* val */
                break;
            }

            case Op_Exit: {
                break;
            }

            case Op_EndProc: {
                return;
            }

            default: {
                syserr("relocate_code: Unimplemented opcode %d (%s)", (int)pc[-1], op_names[pc[-1]]);
                break; /* Not reached */
            }
        }
    }
}
