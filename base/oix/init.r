/*
 * File: init.r
 * Initialization, termination, and such.
 * Contents: readhdr, init/icon_init, envset, env_int,
 *  fpe_trap, inttrag, segvtrap, error, syserr, c_exit, err,
 *  fatalerr, pstrnmcmp, datainit, [loadicode]
 */

#include "../h/header.h"

static	FILE	*readhdr	(char *name, struct header *hdr);

/*
 * Prototypes.
 */


/*
 * The following code is operating-system dependent [@init.01].  Declarations
 *   that are system-dependent.
 */

#if PORT
/* probably needs something more */
Deliberate Syntax Error
#endif					/* PORT */

/*
 * End of operating-system specific code.
 */

#passthru #define OpDef(p,n,s,u) int Cat(O,p) (dptr cargp);
#passthru #include "../h/odefs.h"
#passthru #undef OpDef

/*
 * External declarations for operator blocks.
 */

#passthru #define OpDef(f,nargs,sname,underef)  \
    {                                           \
    T_Proc,                                     \
    Vsizeof(struct b_proc),                     \
    Cat(O,f),                                   \
    nargs,                                      \
    -1,                                         \
    underef,                                    \
    0,                                          \
    0,                                          \
    0,                                          \
    0,                                          \
    {sizeof(sname)-1,sname}},
#passthru static struct b_iproc init_op_tbl[] = {
#passthru #include "../h/odefs.h"
#passthru   };
#undef OpDef

/*
 * A number of important variables follow.
 */

int line_info;				/* flag: line information is available */
char *file_name = NULL;			/* source file for current execution point */
struct b_proc *op_tbl;			/* operators available for string invocation */


word mstksize = MStackSize;		/* initial size of main stack */
word stksize = StackSize;		/* co-expression stack size */

int k_level = 0;			/* &level */


int set_up = 0;				/* set-up switch */

char *currend = NULL;			/* current end of memory region */


word qualsize = QualLstSize;		/* size of quallist for fixed regions */

word memcushion = RegionCushion;	/* memory region cushion factor */
word memgrowth = RegionGrowth;		/* memory region growth factor */

uword stattotal = 0;			/* cumulative total static allocation */

int dodump;				/* if nonzero, core dump on error */
int noerrbuf;				/* if nonzero, do not buffer stderr */

struct descrip maps2;			/* second cached argument of map */
struct descrip maps3;			/* third cached argument of map */
struct descrip maps2u;			/* second cached argument of map */
struct descrip maps3u;			/* third cached argument of map */


struct b_coexpr *stklist;	/* base of co-expression block list */
struct progstate *progs;        /* list of progstates */

struct tend_desc *tend = NULL;  /* chain of tended descriptors */

struct region rootstring, rootblock;



int op_tbl_sz = ElemCount(init_op_tbl);
struct pf_marker *pfp = NULL;		/* Procedure frame pointer */


struct progstate *curpstate;		/* lastop accessed in program state */
struct progstate rootpstate;

word *stack;				/* Interpreter stack */
word *stackend; 			/* End of interpreter stack */


/*
 * Open the icode file and read the header.
 * Used by icon_init() as well as MultiThread's loadicode()
 */
static FILE *readhdr(char *name, struct header *hdr)
{
    FILE *ifile;
    int n = strlen(IcodeDelim);
    char buf[200];

    ifile = fopen(name, ReadBinary);
    if (ifile == NULL)
        return NULL;

    for (;;) {
        if (fgets(buf, sizeof buf-1, ifile) == NULL)
            error("can't find header marker in interpreter file %s", name);
        if (strncmp(buf, IcodeDelim, n) == 0)
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), ifile) != sizeof(*hdr))
        error("can't read interpreter file header in file %s", name);

    return ifile;
}

/*
 * Make sure the version number of the icode matches the interpreter version.
 * The string must equal IVersion or IVersion || "Z".
 */
void check_version(struct header *hdr, char *name,FILE *fname)
{
    if (strncmp((char *)hdr->config,IVersion, strlen(IVersion)) ||
        ((((char *)hdr->config)[strlen(IVersion)]) &&
         strcmp(((char *)hdr->config)+strlen(IVersion), "Z"))
        ) {
        fprintf(stderr,"icode version mismatch in %s\n", name);
        fprintf(stderr,"\ticode version: %s\n",(char *)hdr->config);
        fprintf(stderr,"\texpected version: %s\n",IVersion);
        fclose(fname);
        error("cannot run %s", name);
    }
}

static void read_icode(struct header *hdr, char *name, FILE *ifile, char *codeptr)
{
    word cbread;
#ifdef HAVE_LIBZ
    if (strchr((char *)(hdr->config), 'Z')) { /* to decompress */
        gzFile zfd;
        int tmp = open(name, O_RDONLY);
        lseek(tmp,ftell(ifile),SEEK_SET);
        zfd = gzdopen(tmp, "r");
        if ((cbread = gzlongread(codeptr, sizeof(char), (long)hdr->hsize, zfd)) !=
            hdr->hsize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->hsize,(long)cbread);
            error("bad icode file: %s", name);
        }
        gzclose(zfd);
    } else {
        if ((cbread = longread(codeptr, sizeof(char), (long)hdr->hsize, ifile)) !=
            hdr->hsize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->hsize,(long)cbread);
            error("bad icode file: %s", name);
        }
    }
#else					/* HAVE_LIBZ */
    if ((cbread = longread(codeptr, sizeof(char), (long)hdr->hsize, ifile)) !=
        hdr->hsize) {
        fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                (long)hdr->hsize,(long)cbread);
        error("bad icode file: %s", name);
    }
#endif					/* HAVE_LIBZ */
}

#passthru #define _INT int
static struct b_cset *make_static_cset_block(int n_ranges, ...)
{
    struct b_cset *b;
    uword blksize;
    int i, j;
    va_list argp;
    va_start(argp, n_ranges);
    blksize = sizeof(struct b_cset) + ((n_ranges - 1) * sizeof(struct b_cset_range));
    MemProtect(b = calloc(blksize, 1));
    b->blksize = blksize;
    b->n_ranges = n_ranges;
    b->size = 0;
    for (i = 0; i < n_ranges; ++i) {
        b->range[i].from = va_arg(argp, _INT);
        b->range[i].to = va_arg(argp, _INT);
        b->range[i].index = b->size;
        b->size += b->range[i].to - b->range[i].from + 1;
        for (j = b->range[i].from; j <= b->range[i].to; ++j) {
            if (j > 0xff)
                break;
            Setb(j, b->bits);
        }
    }
    va_end(argp);
    return b;
}


/*
 * init/icon_init - initialize memory and prepare for Icon execution.
 */

void icon_init(char *name)
{
    struct header hdr;
    FILE *ifile = 0;
    char *t;

    /*
     * Initializations that cannot be performed statically (at least for
     * some compilers).					[[I?]]
     */

    MakeStr(" ", 1, &blank);
    MakeStr("", 0, &emptystr);
    MakeStr("abcdefghijklmnopqrstuvwxyz", 26, &lcase);
    MakeStr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 26, &ucase);
    MakeStr("r", 1, &letr);
    MakeInt(0, &zerodesc);
    MakeInt(1, &onedesc);
    MakeInt(-1, &minusonedesc);
    MakeInt(0, &kywd_dmp);

    nullptr.dword = F_Ptr | F_Nqual;
    BlkLoc(nullptr) = 0;

    nulldesc.dword = D_Null;
    IntVal(nulldesc) = 0;

    rzerodesc.dword = D_Real;
    BlkLoc(rzerodesc) = (union block *)&realzero;

    maps2 = nulldesc;
    maps3 = nulldesc;
    maps2u = nulldesc;
    maps3u = nulldesc;

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

    MemProtect(emptystr_ucs = calloc(sizeof(struct b_ucs), 1));
    emptystr_ucs->utf8 = emptystr;
    emptystr_ucs->length = 0;
    emptystr_ucs->n_off_indexed = 0;
    emptystr_ucs->index_step = 0;

    MemProtect(blank_ucs = calloc(sizeof(struct b_ucs), 1));
    blank_ucs->utf8 = blank;
    blank_ucs->length = 1;
    blank_ucs->n_off_indexed = 0;
    blank_ucs->index_step = 4;

    csetdesc.dword = D_Cset;
    BlkLoc(csetdesc) = (union block *)k_cset;

    /*
     * initialize root pstate
     */
    curpstate = &rootpstate;
    progs = &rootpstate;
    rootpstate.next = NULL;
    rootpstate.parentdesc = nulldesc;
    rootpstate.eventmask= nulldesc;
    rootpstate.opcodemask = nulldesc;
    rootpstate.eventcount = zerodesc;
    rootpstate.valuemask = nulldesc;
    rootpstate.eventcode= nulldesc;
    rootpstate.eventval = nulldesc;
    rootpstate.eventsource = nulldesc;
    rootpstate.Glbl_argp = NULL;
    rootpstate.Kywd_err = zerodesc;
    rootpstate.Kywd_pos = onedesc;
    rootpstate.ksub = emptystr;
    rootpstate.Kywd_why = emptystr;
    rootpstate.Kywd_ran = zerodesc;
    rootpstate.K_errornumber = 0;
    rootpstate.T_errornumber = 0;
    rootpstate.Have_errval = 0;
    rootpstate.T_have_val = 0;
    rootpstate.K_errortext = emptystr;
    rootpstate.K_errorvalue = nulldesc;
    rootpstate.T_errorvalue = nulldesc;
    rootpstate.T_errortext = emptystr;

    rootpstate.Coexp_ser = 2;
    rootpstate.List_ser  = 1;
    rootpstate.Set_ser   = 1;
    rootpstate.Table_ser = 1;
    rootpstate.Kywd_time_elsewhere = 0;
    rootpstate.Kywd_time_out = 0;
    rootpstate.stringregion = &rootstring;
    rootpstate.blockregion = &rootblock;

    rootpstate.Cplist = cplist_0;
    rootpstate.Cpset = cpset_0;
    rootpstate.Cptable = cptable_0;
    rootpstate.EVstralc = EVStrAlc_0;
    rootpstate.Interp = interp_0;
    rootpstate.Cnvcset = cnv_cset_0;
    rootpstate.Cnvucs = cnv_ucs_0;
    rootpstate.Cnvint = cnv_int_0;
    rootpstate.Cnvreal = cnv_real_0;
    rootpstate.Cnvstr = cnv_str_0;
    rootpstate.Cnvtstr = cnv_tstr_0;
    rootpstate.Deref = deref_0;
    rootpstate.Alcbignum = alcbignum_0;
    rootpstate.Alccset = alccset_0;
    rootpstate.Alchash = alchash_0;
    rootpstate.Alcsegment = alcsegment_0;
    rootpstate.Alclist_raw = alclist_raw_0;
    rootpstate.Alclist = alclist_0;
    rootpstate.Alclstb = alclstb_0;
    rootpstate.Alcreal = alcreal_0;
    rootpstate.Alcrecd = alcrecd_0;
    rootpstate.Alcobject = alcobject_0;
    rootpstate.Alccast = alccast_0;
    rootpstate.Alcmethp = alcmethp_0;
    rootpstate.Alcucs = alcucs_0;
    rootpstate.Alcrefresh = alcrefresh_0;
    rootpstate.Alcselem = alcselem_0;
    rootpstate.Alcstr = alcstr_0;
    rootpstate.Alcsubs = alcsubs_0;
    rootpstate.Alctelem = alctelem_0;
    rootpstate.Alctvtbl = alctvtbl_0;
    rootpstate.Deallocate = deallocate_0;
    rootpstate.Reserve = reserve_0;

    rootstring.size = MaxStrSpace;
    rootblock.size  = MaxAbrSize;

    { long l, onepercent;
        if ((l = physicalmemorysize())) {
            onepercent = l / 100;
            if (rootstring.size < onepercent) rootstring.size = onepercent;
            if (rootblock.size < onepercent) rootblock.size = onepercent;
	}
    }


    op_tbl = (struct b_proc*)init_op_tbl;

#ifdef Double
    if (sizeof(struct size_dbl) != sizeof(double))
        syserr("Icon configuration does not handle double alignment");
#endif					/* Double */


    /*
     * Catch floating-point traps and memory faults.
     */

/*
 * The following code is operating-system dependent [@init.02].  Set traps.
 */

#if PORT
    /* probably needs something */
    Deliberate Syntax Error
#endif					/* PORT */

#if UNIX
/*RPP   signal(SIGSEGV, SigFncCast segvtrap); */
    signal(SIGFPE, SigFncCast fpetrap);
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

    if (!name)
        error("No interpreter file supplied");

    t = findexe(name);
    if (!t)
        error("Not found on PATH: %s", name);

    name = salloc(t);

    ifile = readhdr(name, &hdr);
    if (ifile == NULL) 
        error("cannot open interpreter file %s", name);

    CMakeStr(name, &rootpstate.Kywd_prog);
    MakeInt(hdr.trace, &rootpstate.Kywd_trc);

    /*
     * Examine the environment and make appropriate settings.    [[I?]]
     */
    envset();

    /*
     * Convert stack sizes from words to bytes.
     */

    stksize *= WordSize;
    mstksize *= WordSize;

#if IntBits == 16
    if (mstksize > MaxBlock)
        fatalerr(316, NULL);
    if (stksize > MaxBlock)
        fatalerr(318, NULL);
#endif					/* IntBits == 16 */

    /*
     * Allocate memory for various regions.
     */
    initalloc(hdr.hsize,&rootpstate);

    /*
     * Establish pointers to icode data regions.		[[I?]]
     */
    ecode = code + hdr.ClassStatics;
    classstatics = (dptr)(code + hdr.ClassStatics);
    eclassstatics = (dptr)(code + hdr.ClassMethods);
    classmethods = (dptr)(code + hdr.ClassMethods);
    eclassmethods = (dptr)(code + hdr.ClassFields);
    classfields = (struct class_field *)(code + hdr.ClassFields);
    eclassfields = (struct class_field *)(code + hdr.Classes);
    classes = (word *)(code + hdr.Classes);
    records = (word *)(code + hdr.Records);
    fnames = (dptr)(code + hdr.Fnames);
    globals = efnames = (dptr)(code + hdr.Globals);
    gnames = eglobals = (dptr)(code + hdr.Gnames);
    statics = egnames = (dptr)(code + hdr.Statics);
    estatics = (dptr)(code + hdr.Filenms);
    filenms = (struct ipc_fname *)estatics;
    efilenms = (struct ipc_fname *)(code + hdr.linenums);
    ilines = (struct ipc_line *)efilenms;
    elines = (struct ipc_line *)(code + hdr.Strcons);
    strcons = (char *)elines;
    estrcons = (char *)(code + hdr.hsize);
    n_globals = eglobals - globals;
    n_statics = estatics - statics;

    /*
     * Allocate stack and initialize &main.
     */

    Protect(stack = malloc(mstksize), fatalerr(303, NULL));
    mainhead = (struct b_coexpr *)stack;

    mainhead->title = T_Coexpr;
    mainhead->id = 1;
    mainhead->size = 1;			/* pretend main() does an activation */
    mainhead->nextstk = NULL;
    mainhead->es_tend = NULL;
    mainhead->freshblk = nulldesc;	/* &main has no refresh block. */
					/*  This really is a bug. */
    mainhead->program = &rootpstate;

    MemProtect(mainhead->es_actstk = alcactiv());
    pushact(mainhead, mainhead);

    /*
     * Point &main at the co-expression block for the main procedure and set
     *  k_current, the pointer to the current co-expression, to &main.
     */
    k_main.dword = D_Coexpr;
    BlkLoc(k_main) = (union block *) mainhead;
    k_current = k_main;
    check_version(&hdr, name, ifile);
    read_icode(&hdr, name, ifile, code);
    fclose(ifile);

    /*
     * Initialize the event monitoring system, if configured.
     */

    EVInit();

    /*
     * Resolve references from icode to run-time system.
     */
    resolve(&rootpstate);

/*
 * The following code is operating-system dependent [@init.03].  Allocate and
 *  assign a buffer to stderr if possible.
 */

#if PORT
    /* probably nothing */
    Deliberate Syntax Error
#endif					/* PORT */

#if UNIX


        if (noerrbuf)
            setbuf(stderr, NULL);
        else {
            char *buf;
            Protect(buf = malloc(BUFSIZ), fatalerr(305, NULL));
            setbuf(stderr, buf);
        }
#endif					/* UNIX */

#if MSWIN32
    if (noerrbuf)
        setbuf(stderr, NULL);
    else {
#ifndef MSWindows
        char *buf;
        Protect(buf = malloc(BUFSIZ), fatalerr(305, NULL));
        setbuf(stderr, buf);
#endif					/* MSWindows */
    }
#endif					/* MSWIN32 */

/*
 * End of operating-system specific code.
 */

    /*
     * Start timing execution.
     */
    millisec();
}

/*
 * Service routines related to getting things started.
 */


/*
 * Check for environment variables that Icon uses and set system
 *  values as is appropriate.
 */
void envset()
{
    register char *p;

    if ((p = getenv("NOERRBUF")) != NULL)
        noerrbuf++;
    env_int(TRACE, &k_trace, 0, (uword)0);
    env_int(COEXPSIZE, &stksize, 1, (uword)MaxUnsigned);
    env_int(STRSIZE, &ssize, 1, (uword)MaxBlock);
    env_int(HEAPSIZE, &abrsize, 1, (uword)MaxBlock);
#ifndef BSD_4_4_LITE
    env_int(BLOCKSIZE, &abrsize, 1, (uword)MaxBlock);    /* synonym */
#endif					/* BSD_4_4_LITE */
    env_int(BLKSIZE, &abrsize, 1, (uword)MaxBlock);      /* synonym */
    env_int(MSTKSIZE, &mstksize, 1, (uword)MaxUnsigned);
    env_int(QLSIZE, &qualsize, 1, (uword)MaxBlock);
    env_int("IXCUSHION", &memcushion, 1, (uword)100);	/* max 100 % */
    env_int("IXGROWTH", &memgrowth, 1, (uword)10000);	/* max 100x growth */

/*
 * The following code is operating-system dependent [@init.04].  Check any
 *  system-dependent environment variables.
 */

#if PORT
    /* nothing to do */
    Deliberate Syntax Error
#endif					/* PORT */

/*
 * End of operating-system specific code.
 */

    if ((p = getenv(ICONCORE)) != NULL && *p != '\0') {

/*
 * The following code is operating-system dependent [@init.05].  Set trap to
 *  give dump on abnormal termination if ICONCORE is set.
 */

#if PORT
        /* can't handle */
        Deliberate Syntax Error
#endif					/* PORT */

#if UNIX
        signal(SIGSEGV, SIG_DFL);
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */
        dodump++;
    }
}

/*
 * env_int - get the value of an integer-valued environment variable.
 */
void env_int(name, variable, non_neg, limit)
    char *name;
    word *variable;
    int non_neg;
    uword limit;
{
    char *value;
    char *s;
    register uword n = 0;
    register uword d;
    int sign = 1;

    if ((value = getenv(name)) == NULL || *value == '\0')
        return;

    s = value;
    if (*s == '-') {
        if (non_neg)
            error("environment variable out of range: %s=%s", name, value);
        sign = -1;
        ++s;
    }
    else if (*s == '+')
        ++s;
    while (isdigit(*s)) {
        d = *s++ - '0';
        /*
         * See if 10 * n + d > limit, but do it so there can be no overflow.
         */
        if ((d > (uword)(limit / 10 - n) * 10 + limit % 10) && (limit > 0))
            error("environment variable out of range: %s=%s", name, value);
        n = n * 10 + d;
    }
    if (*s != '\0')
        error("environment variable not numeric: %s=%s", name, value);
    *variable = sign * n;
}

/*
 * Termination routines.
 */

/*
 * Produce run-time error 204 on floating-point traps.
 */

void fpetrap()
{
    fatalerr(204, NULL);
}

/*
 * Produce run-time error 320 on ^C interrupts. Not used at present,
 *  since malfunction may occur during traceback.
 */
void inttrap()
{
    fatalerr(320, NULL);
}

/*
 * Produce run-time error 302 on segmentation faults.
 */
void segvtrap()
{
    static int n = 0;

    if (n != 0) {			/* only try traceback once */
        fprintf(stderr, "[Traceback failed]\n");
        exit(1);
    }
    n++;

    fatalerr(302, NULL);
}

/*
 * error - print error message; used only in startup code.
 */
void error(char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr, "error in startup code\n");
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    if (dodump)
        abort();
    c_exit(EXIT_FAILURE);
}

/*
 * syserr - print s as a system error.
 */
void syserr(char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr, "System error");
    if (pfp == NULL)
        fprintf(stderr, " in startup code");
    else {
        dptr fn = findfile(ipc.opnd);
        if (fn)
            fprintf(stderr, " at line %ld in %.*s", (long)findline(ipc.opnd), StrLen(*fn), StrLoc(*fn));
        else
            fprintf(stderr, " at line %ld in ?", (long)findline(ipc.opnd));
    }
    fprintf(stderr, "\n");
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);

    if (pfp == NULL) {		/* skip if start-up problem */
        if (dodump)
            abort();
        c_exit(EXIT_FAILURE);
    }
    fprintf(stderr, "Traceback:\n");
    tracebk(pfp, glbl_argp);
    fflush(stderr);

    if (dodump)
        abort();

    c_exit(EXIT_FAILURE);
}


/*
 * c_exit(i) - flush all buffers and exit with status i.
 */
void c_exit(i)
    int i;
{


#if E_Exit
    if (curpstate != NULL)
        EVVal((word)i, E_Exit);
#endif					/* E_Exit */
    if (curpstate != NULL && curpstate->parent != NULL) {
        /* might want to get to the lterm somehow, instead */
        while (0&&(struct b_coexpr*)BlkLoc(k_current) != curpstate->parent->Mainhead) {
            struct descrip dummy;
            co_chng(curpstate->parent->Mainhead, NULL, &dummy, A_Cofail, 1);
        }
    }

    if (k_dump && set_up) {
        fprintf(stderr,"\nTermination dump:\n\n");
        fflush(stderr);
        fprintf(stderr,"co-expression #%ld(%ld)\n",
                (long)BlkLoc(k_current)->coexpr.id,
                (long)BlkLoc(k_current)->coexpr.size);
        fflush(stderr);
        xdisp(pfp,glbl_argp,k_level,stderr);
    }

#ifdef MSWindows
    PostQuitMessage(0);
    while (wstates != NULL) pollevent();
#endif					/* MSWindows */

    exit(i);

}


/*
 * err() is called if an erroneous situation occurs in the virtual
 *  machine code.  It is typed as int to avoid declaration problems
 *  elsewhere.
 */
int err()
{
    syserr("call to 'err'\n");
    return 1;		/* unreachable; make compilers happy */
}

/*
 * fatalerr - disable error conversion and call run-time error routine.
 */
void fatalerr(n, v)
    int n;
    dptr v;
{
    IntVal(kywd_err) = 0;
    err_msg(n, v);
}

/*
 * pstrnmcmp - compare names in two pstrnm structs; used for qsort.
 */
int pstrnmcmp(a,b)
    struct pstrnm *a, *b;
{
    return strcmp(a->pstrep, b->pstrep);
}

/*
 * Initialize a loaded program.  Unicon programs will have an
 * interesting icodesize; non-Unicon programs will send a fake
 * icodesize (nonzero, perhaps good if longword-aligned) to alccoexp.
 */
struct b_coexpr *initprogram(word icodesize, word stacksize,
			     word stringsiz, word blocksiz)
{
    struct b_coexpr *coexp;
    struct progstate *pstate;

    MemProtect(coexp = alccoexp(icodesize, stacksize));
    pstate = coexp->program;

    /*
     * Initialize values.
     */
    pstate->hsize = icodesize;
    pstate->parent= NULL;
    pstate->next = progs;
    progs = pstate;
    pstate->parentdesc= nulldesc;
    pstate->eventmask= nulldesc;
    pstate->opcodemask= nulldesc;
    pstate->eventcount = zerodesc;
    pstate->valuemask= nulldesc;
    pstate->eventcode= nulldesc;
    pstate->eventval = nulldesc;
    pstate->eventsource = nulldesc;
    pstate->Kywd_why = emptystr;
    pstate->Glbl_argp = NULL;
    pstate->Kywd_err = zerodesc;
    pstate->Kywd_pos = onedesc;
    pstate->ksub = emptystr;
    pstate->Kywd_ran = zerodesc;
    pstate->Line_num = pstate->Lastline = 0;
    pstate->Lastop = 0;
    pstate->Xargp = NULL;
    pstate->Xnargs = 0;
    pstate->K_errornumber = 0;
    pstate->T_errornumber = 0;
    pstate->Have_errval = 0;
    pstate->T_have_val = 0;
    pstate->K_errortext = emptystr;
    pstate->K_errorvalue = nulldesc;
    pstate->T_errorvalue = nulldesc;
    pstate->T_errortext = emptystr;
    pstate->Kywd_time_elsewhere = millisec();
    pstate->Kywd_time_out = 0;
    pstate->Mainhead= ((struct b_coexpr *)pstate)-1;
    pstate->K_main.dword = D_Coexpr;
    BlkLoc(pstate->K_main) = (union block *) pstate->Mainhead;

    pstate->Coexp_ser = 2;
    pstate->List_ser = 1;
    pstate->Set_ser = 1;
    pstate->Table_ser = 1;

    pstate->stringtotal = pstate->blocktotal =
        pstate->colltot     = pstate->collstat   =
        pstate->collstr     = pstate->collblk    = 0;

    MemProtect(pstate->stringregion = malloc(sizeof(struct region)));
    MemProtect(pstate->blockregion  = malloc(sizeof(struct region)));
    pstate->stringregion->size = stringsiz;
    pstate->blockregion->size = blocksiz;

    /*
     * the local program region list starts out with this region only
     */
    pstate->stringregion->prev = NULL;
    pstate->blockregion->prev = NULL;
    pstate->stringregion->next = NULL;
    pstate->blockregion->next = NULL;
    /*
     * the global region list links this region with curpstate's
     */
    pstate->stringregion->Gprev = curpstate->stringregion;
    pstate->blockregion->Gprev = curpstate->blockregion;
    pstate->stringregion->Gnext = curpstate->stringregion->Gnext;
    pstate->blockregion->Gnext = curpstate->blockregion->Gnext;
    if (curpstate->stringregion->Gnext)
        curpstate->stringregion->Gnext->Gprev = pstate->stringregion;
    curpstate->stringregion->Gnext = pstate->stringregion;
    if (curpstate->blockregion->Gnext)
        curpstate->blockregion->Gnext->Gprev = pstate->blockregion;
    curpstate->blockregion->Gnext = pstate->blockregion;
    initalloc(0, pstate);

    pstate->Cplist = cplist_0;
    pstate->Cpset = cpset_0;
    pstate->Cptable = cptable_0;
    pstate->EVstralc = EVStrAlc_0;
    pstate->Interp = interp_0;
    pstate->Cnvcset = cnv_cset_0;
    pstate->Cnvucs = cnv_ucs_0;
    pstate->Cnvint = cnv_int_0;
    pstate->Cnvreal = cnv_real_0;
    pstate->Cnvstr = cnv_str_0;
    pstate->Cnvtstr = cnv_tstr_0;
    pstate->Deref = deref_0;
    pstate->Alcbignum = alcbignum_0;
    pstate->Alccset = alccset_0;
    pstate->Alchash = alchash_0;
    pstate->Alcsegment = alcsegment_0;
    pstate->Alclist_raw = alclist_raw_0;
    pstate->Alclist = alclist_0;
    pstate->Alclstb = alclstb_0;
    pstate->Alcreal = alcreal_0;
    pstate->Alcrecd = alcrecd_0;
    pstate->Alcobject = alcobject_0;
    pstate->Alccast = alccast_0;
    pstate->Alcmethp = alcmethp_0;
    pstate->Alcucs = alcucs_0;
    pstate->Alcrefresh = alcrefresh_0;
    pstate->Alcselem = alcselem_0;
    pstate->Alcstr = alcstr_0;
    pstate->Alcsubs = alcsubs_0;
    pstate->Alctelem = alctelem_0;
    pstate->Alctvtbl = alctvtbl_0;
    pstate->Deallocate = deallocate_0;
    pstate->Reserve = reserve_0;

    return coexp;
}

/*
 * loadicode - initialize memory particular to a given icode file
 */
struct b_coexpr * loadicode(name, bs, ss, stk)
    char *name;
    C_integer bs, ss, stk;
{
    struct b_coexpr *coexp;
    struct progstate *pstate;
    struct header hdr;
    FILE *ifile = NULL;

    /*
     * open the icode file and read the header
     */
    ifile = readhdr(name,&hdr);
    if (ifile == NULL)
        return NULL;

    /*
     * Allocate memory for icode and the struct that describes it
     */
    coexp = initprogram(hdr.hsize, stk, ss, bs);

    pstate = coexp->program;
    pstate->K_current.dword = D_Coexpr;

    CMakeStr(name, &pstate->Kywd_prog);
    MakeInt(hdr.trace, &pstate->Kywd_trc);

    /*
     * might want to override from TRACE environment variable here.
     */

    /*
     * Establish pointers to icode data regions.		[[I?]]
     */
    pstate->Code    = (char *)(pstate + 1);
    pstate->Ecode    = (char *)(pstate->Code + hdr.ClassStatics);
    pstate->ClassStatics = (dptr)(pstate->Code + hdr.ClassStatics);
    pstate->EClassStatics = (dptr)(pstate->Code + hdr.ClassMethods);
    pstate->ClassMethods = (dptr)(pstate->Code + hdr.ClassMethods);
    pstate->EClassMethods = (dptr)(pstate->Code + hdr.ClassFields);
    pstate->ClassFields = (struct class_field *)(pstate->Code + hdr.ClassFields);
    pstate->EClassFields = (struct class_field *)(pstate->Code + hdr.Classes);
    pstate->Classes = (word *)(pstate->Code + hdr.Classes);
    pstate->Records = (word *)(pstate->Code + hdr.Records);
    pstate->Fnames  = (dptr)(pstate->Code + hdr.Fnames);
    pstate->Globals = pstate->Efnames = (dptr)(pstate->Code + hdr.Globals);
    pstate->Gnames  = pstate->Eglobals = (dptr)(pstate->Code + hdr.Gnames);
    pstate->NGlobals = pstate->Eglobals - pstate->Globals;
    pstate->Statics = pstate->Egnames = (dptr)(pstate->Code + hdr.Statics);
    pstate->Estatics = (dptr)(pstate->Code + hdr.Filenms);
    pstate->NStatics = pstate->Estatics - pstate->Statics;
    pstate->Filenms = (struct ipc_fname *)(pstate->Estatics);
    pstate->Efilenms = (struct ipc_fname *)(pstate->Code + hdr.linenums);
    pstate->Ilines = (struct ipc_line *)(pstate->Efilenms);
    pstate->Elines = (struct ipc_line *)(pstate->Code + hdr.Strcons);
    pstate->Strcons = (char *)(pstate->Elines);

    check_version(&hdr, name, ifile);
    read_icode(&hdr, name, ifile, pstate->Code);

    fclose(ifile);

    /*
     * Resolve references from icode to run-time system.
     * The first program has this done in icon_init after
     * initializing the event monitoring system.
     */
    resolve(pstate);

    return coexp;
}

void showicode()
{
    struct progstate *p;

    printf("Addr    Name        Glbl_argp        Code       &main\t&current\n");
    for (p = progs; p; p = p->next) {
        printf("%p %-10s %10p %p-%p\t%p\t%p\n", 
               p, 
               cstr(&p->Kywd_prog), 
               p->Glbl_argp, p->Code, p->Ecode,
               p->Mainhead,
               p->K_current.vword.bptr);
    }
}

void checkcoexps(char *s) {
    struct b_coexpr *p = (struct b_coexpr *)BlkLoc(k_current);
    if (p->program != curpstate) {
        printf("CORRUPT at %s\n",s);
        fflush(stdout);
        showcoexps();
        exit(1);
    }

/*     printf("OKAY at %s\n",s); */
}

void showcoexps()
{
    struct b_coexpr *p;
    struct b_coexpr *curr = (struct b_coexpr *)(curpstate->K_current.vword.bptr);

    printf("Coexpression\tprogram\tsize\tes_sp\tC sp\tS Low\tS High\tUsed\n");

    p = rootpstate.Mainhead;
    printf("%p\t\t%p\t%d\t%p\t%x\n",
           p,
           p->program,
           p->size,
           p->es_sp,
           p->cstate[0]);

    for (p = stklist; p; p = p->nextstk) {
        printf("%p\t\t%p\t%d\t%p\t%x\t%p\t%x\t%d\n",
               p,
               p->program,
               p->size,
               p->es_sp,
               p->cstate[0],
               (word *)((char *)p + sizeof(struct b_coexpr)),
               ((word)((char *)p + stksize - WordSize) &~((word)WordSize*StackAlign-1)),
               ((word)((char *)p + stksize - WordSize) &~((word)WordSize*StackAlign-1)) - (word)(p->cstate[0])
            );
    }
    printf("curpstate=%p rootpstate=%p &main=%p &current=%p\n", 
           curpstate, 
           &rootpstate,
           curpstate->K_main.vword.bptr,
           curpstate->K_current.vword.bptr);
    printf("ilevel=%d ISP=%p\n", ilevel,sp);

    fflush(stdout);
}

static int isvar(word *p) {
    struct descrip *d = (struct descrip *)p;
    return (d->dword & (F_Var | F_Nqual | F_Ptr | F_Typecode)) == D_Var;
}

static int isdescrip(word *p){
    struct descrip *d = (struct descrip *)p;
    word i = d->dword;

    if (Qual(*d))
        return InRange(strcons, StrLoc(*d), estrcons) || InRange(strbase, StrLoc(*d), strfree);

    if (isvar(p))
        return 1;

    return (i==D_Null || i==D_Integer || i==D_Lrgint || i==D_Real ||
            i==D_Cset || i==D_Proc || i==D_Record || i==D_List ||
            i==D_Lelem || i==D_Set || i==D_Selem || i==D_Table || i==D_Telem ||
            i==D_Tvtbl || i==D_Slots || i==D_Tvsubs || i==D_Refresh || i==D_Coexpr ||
            i==D_External || i==D_Kywdint || i==D_Kywdpos || i==D_Kywdsubj ||
            i==D_Kywdstr || i==D_Kywdevent || i==D_Class || i==D_Object || i==D_Cast || 
            i==D_Constructor || i==D_Methp);
}

char *cstr(struct descrip *sd) {
    static char res[256];
    int n = StrLen(*sd);
    if (n > 255)
        n = 255;
    memcpy(res, StrLoc(*sd), n);
    res[n] = 0;
    return res;
}

static char* vword2str(dptr d) {
    static char res[1024];

    if (!(d->dword & F_Nqual)) {
        return cstr(d);
    }

    if (d->dword & F_Typecode) {
        switch(d->dword & TypeMask) {
            case T_Null: return "0";
            case T_Integer: sprintf(res, "%d", d->vword.integr); break;
            case T_Proc: {
                struct b_proc *p = (struct b_proc*)BlkLoc(*d);
                sprintf(res, "%s() prog:%p", cstr(&p->pname), p->program);
                break;
            }
            case T_Class: {
                struct b_class *p = (struct b_class*)BlkLoc(*d);
                sprintf(res, "class %s prog:%p", cstr(&p->name), p->program);
                break;
            }
            case T_Constructor: {
                struct b_constructor *p = (struct b_constructor*)BlkLoc(*d);
                sprintf(res, "constructor %s prog:%p", cstr(&p->name), p->program);
                break;
            }
            case T_Object: {
                struct b_object *p = (struct b_object*)BlkLoc(*d);
                sprintf(res, "object %p %s(%d)", BlkLoc(*d), cstr(&p->class->name), p->id);
                break;
            }
            case T_Cast: {
                struct b_cast *p = (struct b_cast*)BlkLoc(*d);
                sprintf(res, "cast ");
                strcat(res, cstr(&p->object->class->name));
                strcat(res, ",");
                strcat(res, cstr(&p->class->name));
                break;
            }
            case T_Methp: {
                struct b_methp *p = (struct b_methp*)BlkLoc(*d);
                sprintf(res, "methp %s(%d),", cstr(&p->object->class->name), p->object->id);
                strcat(res, cstr(&p->proc->pname));
                break;
            }
            case T_Ucs:{
                struct b_ucs *p = (struct b_ucs*)BlkLoc(*d);
                sprintf(res, "ucs(%d,%s)", p->length,cstr(&p->utf8));
                break;
            }
            case T_Tvsubs:{
                struct b_tvsubs *p = (struct b_tvsubs*)BlkLoc(*d);
                sprintf(res, "ssvar=%s", tostring(&p->ssvar));
                break;
            }

            case T_Lrgint:
            case T_Real: 
            case T_Cset: 
            case T_Record:
            case T_List: 
            case T_Lelem:
            case T_Set: 
            case T_Selem:
            case T_Table:
            case T_Telem:
            case T_Coexpr: {
                sprintf(res, "bptr=%p", BlkLoc(*d));
                break;
            }

            case T_Tvtbl: return "";
            case T_Slots: return "";
            case T_Refresh: return "";
            case T_External: return "";
            case T_Kywdint: return "";
            case T_Kywdpos: return "";
            case T_Kywdsubj: return "";
            case T_Kywdstr: return "";
            case T_Kywdevent: return "";
            default:return "?";
        }
    } else if (d->dword & F_Var) 
        sprintf(res, "bptr=%p", BlkLoc(*d));
    else
        return "?";

    return res;
}

char* dword2str(dptr d) {
    static char buff[32], offset[32];
    char *s = buff, *t;
    if (d->dword & F_Nqual)
        *s++ = 'n';
    else {
        /* String */
        sprintf(buff, "%d", d->dword);
        return buff;
    }
    if (d->dword & F_Var)
        *s++ = 'v';
    if (d->dword & F_Typecode)
        *s++ = 't';
    if (d->dword & F_Ptr)
        *s++ = 'p';
    *s = 0;
    if (d->dword & F_Typecode) {
        switch(d->dword & TypeMask) {
            case T_Null: t = "T_Null"; break;
            case T_Integer: t = "T_Integer"; break;
            case T_Lrgint: t = "T_Lrgint"; break;
            case T_Real: t = "T_Real"; break;
            case T_Cset: t = "T_Cset"; break;
            case T_Proc: t = "T_proc"; break;
            case T_Record: t = "T_Record"; break;
            case T_List: t = "T_List"; break;
            case T_Lelem: t = "T_Lelem"; break;
            case T_Set: t = "T_Set"; break;
            case T_Selem: t = "T_Selem"; break;
            case T_Table: t = "T_Table"; break;
            case T_Telem: t = "T_Telem"; break;
            case T_Tvtbl: t = "T_Tvtbl"; break;
            case T_Slots: t = "T_Slots"; break;
            case T_Tvsubs: t = "T_Tvsubs"; break;
            case T_Refresh: t = "T_Refresh"; break;
            case T_Coexpr: t = "T_Coexpr"; break;
            case T_External: t = "T_External"; break;
            case T_Kywdint: t = "T_Kywdint"; break;
            case T_Kywdpos: t = "T_Kywdpos"; break;
            case T_Kywdsubj: t = "T_Kywdsubj"; break;
            case T_Kywdstr: t = "T_Kywdstr"; break;
            case T_Kywdevent: t = "T_Kywdevent"; break;
            case T_Class: t = "T_Class"; break;
            case T_Object: t = "T_Object"; break;
            case T_Cast: t = "T_Cast"; break;
            case T_Methp: t = "T_Methp"; break;
            case T_Constructor: t = "T_Constructor"; break;
            case T_Ucs: t = "T_Ucs"; break;
            default: return "?";
        }
        strcat(buff, " ");
        strcat(buff, t);
    }
    else if (d->dword & F_Var) {
        sprintf(offset, " off:%d", d->dword & OffsetMask);
        strcat(buff, offset);
    }

    return buff;
}

char *tostring(dptr d) {
    static char res[1096];
    sprintf(res, "D:%s V:%s", dword2str(d), vword2str(d));
    return res;
}

static int isframe_pf(struct pf_marker *pf, word *p);
static int isframe_ef(struct ef_marker *ef, word *p);
static int isframe_gf(struct gf_marker *gf, word *p);

enum frames { not=0, PF, EF, GF };

static int isframe(word *p) {
    int i;
    if ((i = isframe_pf(pfp,p)) ||
        (i = isframe_ef(efp,p)) ||
        (i = isframe_gf(gfp,p)))
        return i;
    return 0;
}

static int isframe_pf(struct pf_marker *pf, word *p) {
    int i;
    if (!pf)
        return 0;
    if (p == (word*)pf)
        return PF;
    if ((i = isframe_pf(pf->pf_pfp,p)) ||
        (i = isframe_ef(pf->pf_efp,p)) ||
        (i = isframe_gf(pf->pf_gfp,p)))
        return i;
    return 0;
}

static int isframe_ef(struct ef_marker *ef, word *p) {
    int i;
    if (!ef)
        return 0;
    if (p == (word*)ef)
        return EF;
    if ((i = isframe_ef(ef->ef_efp,p)) ||
        (i = isframe_gf(ef->ef_gfp,p)))
        return i;
    return 0;
}    

static int isframe_gf(struct gf_marker *gf, word *p) 
{
    int i;
    if (!gf)
        return 0;
    if (p == (word*)gf)
        return GF;
    if ((i = isframe_ef(gf->gf_efp,p)) ||
        (i = isframe_gf(gf->gf_gfp,p)))
/*        (i = isframe_pf(gf->gf_pfp,p))) */
        return i;
    return 0;
}    

static int is_progstate(word *x)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if ((word*)p == x)
            return 1;
    }
    return 0;
}

char *ptr(void *p) {
    if (p == pfp)
        return "pfp->";
    else if (p == efp)
        return "efp->";
    else if (p == gfp)
        return "gfp->";
    else if (p == sp)
        return "sp->";
    else if (p == glbl_argp)
        return "argp->";
    else
        return "";
}

void showstack()
{
    struct b_coexpr *c;
    word *p;

    printf("Stack sp=%p efp=%p gfp=%p pfp=%p ipc=%p\n",sp,efp,gfp,pfp,ipc.op);
    c = (struct b_coexpr *)BlkLoc(k_current);
    if (!c) {
        printf("curpstate=%p k_current=%p BlkLoc(k_current) is 0\n",curpstate,&k_current);
        return;
    }    
    printf("kcurr->\t%p\tcoex\ttitle=%d\n", c, c->title);
    printf("\t\t\tsize=%d\n",c->size);
    printf("\t\t\tid=%d\n",c->id);
    printf("\t\t\tnextstk=%p\n",c->nextstk);
    printf("\t\t\tes_pfp=%p\n",c->es_pfp);
    printf("\t\t\tes_efp=%p\n",c->es_efp);
    printf("\t\t\tes_gfp=%p\n",c->es_gfp);
    printf("\t\t\tes_ipc=%p\n",c->es_ipc.op);
    printf("\t\t\tes_ilevel=%d\n",c->es_ilevel);
    printf("\t\t\tprogram=%p\n",c->program);

    p = (word*)c + Wsizeof(struct b_coexpr);
    if (is_progstate(p)) {
        struct progstate *t = (struct progstate*)p;
        printf("\t%p\tprog\tparent=%p\n", t, t->parent);
        printf("\t\t\tnext=%p\n",t->next);
        printf("\t\t\tCode=%p\n",t->Code);
        printf("\t\t\tEcode=%p\n",t->Ecode);
        printf("\t\t\tRecords=%p\n",t->Records);
        p += sizeof(struct progstate)/sizeof(word);
        if (p == (word*)t->Code) {
            printf("\t%p\tcode\thsize=%ld\n",p,t->hsize);
            p += t->hsize / WordSize;
            /* Pad.. see corresponding code in fmisc.r */
            if (t->hsize % WordSize)
                ++p;
        }
    }
    while (p <= sp) {
        int ft = isframe(p);
        if (ft == GF) {
            struct gf_marker *t = (struct gf_marker*)p;
            printf("%s\t%p\tgfp\tgf_gentype=%d\n",ptr(p),p,t->gf_gentype);
            printf("\t\t\tgf_efp=%p\n",t->gf_efp);
            printf("\t\t\tgf_gfp=%p\n",t->gf_gfp);
            printf("%s\t\t\tgf_ipc=%p\n",ptr(&t->gf_ipc.op),t->gf_ipc.op);
            /* Is it a small marker or not */
            if (t->gf_gentype == G_Psusp) {
                printf("\t\t\tgf_pfp=%p\n",t->gf_pfp);
                printf("%s\t\t\tgf_argp=%p\n",ptr(&t->gf_argp),t->gf_argp);
                p += sizeof(struct gf_marker)/sizeof(word);
            } else {
                p += sizeof(struct gf_smallmarker)/sizeof(word);
            }
        } else if (ft == EF) {
            struct ef_marker *t = (struct ef_marker*)p;
            printf("%s\t%p\tefp\tef_failure=%p\n",ptr(p),p,t->ef_failure.op);
            printf("\t\t\tef_efp=%p\n",t->ef_efp);
            printf("\t\t\tef_gfp=%p\n",t->ef_gfp);
            printf("%s\t\t\tef_ilevel=%d\n",ptr(&t->ef_ilevel),t->ef_ilevel);
            p += sizeof(struct ef_marker)/sizeof(word);
        } else if (ft == PF) {
            struct pf_marker *t = (struct pf_marker*)p;
            printf("%s\t%p\tpfp\tn_args=%d\n",ptr(p),p,t->pf_nargs);
            printf("\t\t\tpf_pfp=%p\n",t->pf_pfp);
            printf("\t\t\tpf_efp=%p\n",t->pf_efp);
            printf("\t\t\tpf_gfp=%p\n",t->pf_gfp);
            printf("\t\t\tpf_argp=%p\n",t->pf_argp);
            printf("\t\t\tpf_ipc=%p\n",t->pf_ipc.op);
            printf("\t\t\tpf_ilevel=%d\n",t->pf_ilevel);
            printf("\t\t\tpf_scan=%p\n",t->pf_scan);
            printf("\t\t\tpf_from=%p\n",t->pf_from);
            printf("%s\t\t\tpf_to=%p\n",ptr(&t->pf_to),t->pf_to);
            p += (sizeof(struct pf_marker)-sizeof(struct descrip))/sizeof(word);
        } else if (isdescrip(p)) {
            dptr d = (dptr)p;
            if (isvar(p)) {
                struct descrip tmp;
                char *t;
                deref(d, &tmp);
                t = tostring(&tmp);
                printf("%s\t%p\tdescrip\t%s\n", ptr(p), p, dword2str(d));
                printf("%s\t\t\t%s->%s\n", ptr(&d->vword), vword2str(d), t);
            } else {
                printf("%s\t%p\tdescrip\t%s\n", ptr(p), p, dword2str(d));
                printf("%s\t\t\t%s\n", ptr(&d->vword), vword2str(d));
            }
            p += sizeof(struct descrip)/sizeof(word);
        } else {
            printf("%s\t%p\t?\t%x\n",ptr(p),p,*p);
            ++p;
        }
    }
    printf("--------\n");
    fflush(stdout);
}

struct progstate *findprogramforicode(inst x)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->Code, x.op, p->Ecode))
            return p;
    }
    return NULL;
}


