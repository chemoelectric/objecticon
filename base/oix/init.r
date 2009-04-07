/*
 * File: init.r
 * Initialization, termination, and such.
 * Contents: readhdr, init/icon_init, envset, env_int,
 *  fpe_trap, inttrag, error, syserr, c_exit, err,
 *  fatalerr, pstrnmcmp, datainit, [loadicode]
 */

#include "../h/header.h"
#include "../h/opdefs.h"
#include "../h/modflags.h"

static FILE    *readhdr	(char *name, struct header *hdr);
static void    initptrs (struct progstate *p, struct header *h);
static void    initprogstate(struct progstate *p);
static void    initalloc(struct progstate *p);

#passthru #define OpDef(p,n,s,u) int Cat(O,p) (dptr cargp);
#passthru #include "../h/odefs.h"
#passthru #undef OpDef

/*
 * External declarations for operator blocks.
 */

#passthru #define OpDef(f,nargs,sname,underef)  \
    {                                           \
    T_Proc,                                     \
    sizeof(struct b_proc),                     \
    Cat(O,f),                                   \
    nargs,                                      \
    0,                                         \
    underef,                                    \
    0,0,0,0,  \
    {sizeof(sname)-1,sname},                    \
    0,0},
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
word coexprlim;                          /* number of coexpression allocations before a GC is triggered */

int k_level = 0;			/* &level */


int set_up = 0;				/* set-up switch */

char *currend = NULL;			/* current end of memory region */


word qualsize = QualLstSize;		/* size of quallist for fixed regions */

word memcushion = RegionCushion;	/* memory region cushion factor */
word memgrowth = RegionGrowth;		/* memory region growth factor */

word dodump = 1;			/* if zero never core dump;
                                         * if 1 core dump on C-level internal error (call to syserr)
                                         * if 2 core dump on all errors
                                         */

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
dptr argp;			        /* global argp */


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
            ffatalerr("can't find header marker in interpreter file %s", name);
        if (strncmp(buf, IcodeDelim, n) == 0)
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), ifile) != sizeof(*hdr))
        ffatalerr("can't read interpreter file header in file %s", name);

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
        ffatalerr("cannot run %s", name);
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
        if ((cbread = gzlongread(codeptr, sizeof(char), (long)hdr->icodesize, zfd)) !=
            hdr->icodesize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->icodesize,(long)cbread);
            ffatalerr("bad icode file: %s", name);
        }
        gzclose(zfd);
    } else {
        if ((cbread = longread(codeptr, sizeof(char), (long)hdr->icodesize, ifile)) !=
            hdr->icodesize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->icodesize,(long)cbread);
            ffatalerr("bad icode file: %s", name);
        }
    }
#else					/* HAVE_LIBZ */
    if ((cbread = longread(codeptr, sizeof(char), (long)hdr->icodesize, ifile)) !=
        hdr->icodesize) {
        fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                (long)hdr->icodesize,(long)cbread);
        ffatalerr("bad icode file: %s", name);
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
    Protect(b = calloc(blksize, 1), startuperr("Insufficient memory"));
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


/*
 * init/icon_init - initialize memory and prepare for Icon execution.
 */

void icon_init(char *name)
{
    struct header hdr;
    FILE *ifile = 0;
    char *t;
    long pmem;
    struct b_coexpr *mainhead;

    /*
     * Initializations that cannot be performed statically (at least for
     * some compilers).					[[I?]]
     */

    LitStr(" ", &blank);
    LitStr("", &emptystr);
    LitStr("abcdefghijklmnopqrstuvwxyz", &lcase);
    LitStr("ABCDEFGHIJKLMNOPQRSTUVWXYZ", &ucase);
    LitStr("r", &letr);
    MakeInt(0, &zerodesc);
    MakeInt(1, &onedesc);
    MakeInt(-1, &minusonedesc);
    MakeInt(1000000, &milliondesc);
    MakeInt(1000, &thousanddesc);
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

    Protect(emptystr_ucs = calloc(sizeof(struct b_ucs), 1), startuperr("Insufficient memory"));
    emptystr_ucs->utf8 = emptystr;
    emptystr_ucs->length = 0;
    emptystr_ucs->n_off_indexed = 0;
    emptystr_ucs->index_step = 0;

    Protect(blank_ucs = calloc(sizeof(struct b_ucs), 1), startuperr("Insufficient memory"));
    blank_ucs->utf8 = blank;
    blank_ucs->length = 1;
    blank_ucs->n_off_indexed = 0;
    blank_ucs->index_step = 4;

    csetdesc.dword = D_Cset;
    BlkLoc(csetdesc) = (union block *)k_cset;

    /*
     * Initialize root pstate.  After this, we can use ffatalerr() rather than startuperr()
     */
    curpstate = &rootpstate;
    progs = &rootpstate;
    initprogstate(&rootpstate);

    rootpstate.Kywd_time_elsewhere = 0;
    rootpstate.Kywd_time_out = 0;
    rootpstate.stringregion = &rootstring;
    rootpstate.blockregion = &rootblock;

    pmem = physicalmemorysize();
    rootstring.size = Max(pmem/200, MaxStrSpace);
    rootblock.size  = Max(pmem/100, MaxAbrSize);

    op_tbl = (struct b_proc*)init_op_tbl;

#ifdef Double
    if (sizeof(struct size_dbl) != sizeof(double))
        syserr("Icon configuration does not handle double alignment");
#endif					/* Double */

    /*
     * Catch floating-point traps
     */
#if UNIX
    signal(SIGFPE, fpetrap);
#endif					/* UNIX */

    if (!name)
        ffatalerr("No interpreter file supplied");

    t = findexe(name);
    if (!t)
        ffatalerr("Not found on PATH: %s", name);

    name = salloc(t);

    ifile = readhdr(name, &hdr);
    if (ifile == NULL) 
        ffatalerr("cannot open interpreter file %s", name);

    CMakeStr(name, &rootpstate.Kywd_prog);
    MakeInt(hdr.trace, &rootpstate.Kywd_trc);

    /*
     * Examine the environment and make appropriate settings.    [[I?]]
     */
    if (getenv(NOERRBUF))
        noerrbuf++;
    env_int(TRACE, &k_trace, 0, (uword)0);
    env_int(STKSIZE, &stksize, 1, (uword)MaxWord);
    env_int(STRSIZE, &rootstring.size, 1, (uword)MaxWord);
    env_int(BLKSIZE, &rootblock.size, 1, (uword)MaxWord); 
    env_int(MSTKSIZE, &mstksize, 1, (uword)MaxWord);
    env_int(QLSIZE, &qualsize, 1, (uword)MaxWord);
    env_int(IXCUSHION, &memcushion, 1, (uword)100);	/* max 100 % */
    env_int(IXGROWTH, &memgrowth, 1, (uword)10000);	/* max 100x growth */
    env_int(OICORE, &dodump, 1, (uword)2);

    /*
     * Ensure stack sizes are multiples of WordSize.
     */
    stksize &= ~(WordSize - 1);
    mstksize &= ~(WordSize - 1);

    coexprlim = Max((pmem/200) / stksize, CoexprLim);
    env_int(COEXPRLIM, &coexprlim, 1, (uword)MaxWord);

    Protect(rootpstate.Code = malloc(hdr.icodesize), fatalerr(315, NULL));

    /*
     * Establish pointers to icode data regions.		[[I?]]
     */
    initptrs(&rootpstate, &hdr);


    /*
     * Allocate memory for block & string regions.
     */
    initalloc(&rootpstate);

    /*
     * Allocate stack and initialize &main.
     */

    Protect(stack = malloc(mstksize), fatalerr(303, NULL));
    mainhead = (struct b_coexpr *)stack;

    mainhead->title = T_Coexpr;
    mainhead->id = 1;
    mainhead->size = 1;			/* pretend main() does an activation */
    mainhead->nextstk = NULL;
    stklist = mainhead;
    mainhead->es_tend = NULL;
    mainhead->freshblk = NULL;	/* &main has no refresh block. */
					/*  This really is a bug. */
    mainhead->main_of = mainhead->creator = mainhead->program = &rootpstate;
    mainhead->es_activator = mainhead;

    /*
     * Point &main at the co-expression block for the main procedure and set
     *  k_current, the pointer to the current co-expression, to &main.
     */
    k_current = k_main = mainhead;

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

    if (noerrbuf)
        setbuf(stderr, NULL);
    else {
        char *buf;
        MemProtect(buf = malloc(BUFSIZ));
        setbuf(stderr, buf);
    }

    /*
     * Start timing execution.
     */
    millisec();
}

/*
 * Service routines related to getting things started.
 */


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
            ffatalerr("environment variable out of range: %s=%s", name, value);
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
            ffatalerr("environment variable out of range: %s=%s", name, value);
        n = n * 10 + d;
    }
    if (*s != '\0')
        ffatalerr("environment variable not numeric: %s=%s", name, value);
    *variable = sign * n;
}

/*
 * Termination routines.
 */

/*
 * Produce run-time error 204 on floating-point traps.
 */

void fpetrap(int n)
{
    fatalerr(204, NULL);
}

/*
 * error - print error message; used only in startup code.
 */
void startuperr(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "error in startup code\n");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(ap);
    if (dodump > 1)
        abort();
    c_exit(EXIT_FAILURE);
}


/*
 * syserr - print s as a system error.
 */
void syserr(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "System error");
    if (pfp == NULL)
        fprintf(stderr, " in startup code");
    else {
        dptr fn = findfile(ipc);
        if (fn) {
            struct descrip t;
            abbr_fname(fn, &t);
            fprintf(stderr, " at line %ld in %.*s", (long)findline(ipc), (int)StrLen(t), StrLoc(t));
        } else
            fprintf(stderr, " at line %ld in ?", (long)findline(ipc));
    }
    fprintf(stderr, "\n");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(ap);

    if (pfp == NULL) {		/* skip if start-up problem */
        if (dodump)
            abort();
        c_exit(EXIT_FAILURE);
    }
    fprintf(stderr, "Traceback:\n");
    tracebk(pfp, argp);
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
        while (0&&k_current != curpstate->parent->K_main) {
            struct descrip dummy;
            co_chng(curpstate->parent->K_main, 
                    NULL, &dummy, A_Cofail, 1);
        }
    }

    if (k_dump && set_up) {
        fprintf(stderr,"\nTermination dump:\n\n");
        fflush(stderr);
        fprintf(stderr,"co-expression #%ld(%ld)\n",
                (long)k_current->id,
                (long)k_current->size);
        fflush(stderr);
        xdisp(pfp,argp,k_level,stderr, curpstate);
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
void fatalerr(int n, dptr v)
{
    IntVal(kywd_err) = 0;
    err_msg(n, v);
}

/*
 * ffatalerr - like fatalerr, but takes an arbitrary format string
 * rather than an error number and value.
 */
void ffatalerr(char *fmt, ...)
{
    static char buff[128];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buff, sizeof(buff), fmt, ap);
    CMakeStr(buff, &t_errortext);
    IntVal(kywd_err) = 0;
    err_msg(-1, 0);
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
    MemProtect(coexp = alcprog(hdr.icodesize, stk));
    pstate = coexp->program;
    pstate->parent = curpstate;
    pstate->next = progs;
    progs = pstate;
    initprogstate(pstate);
    pstate->Kywd_time_elsewhere = millisec();
    pstate->Kywd_time_out = 0;
    pstate->K_current = pstate->K_main = coexp;

    MemProtect(pstate->stringregion = malloc(sizeof(struct region)));
    MemProtect(pstate->blockregion  = malloc(sizeof(struct region)));
    pstate->stringregion->size = ss;
    pstate->blockregion->size = bs;

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

    CMakeStr(name, &pstate->Kywd_prog);
    MakeInt(hdr.trace, &pstate->Kywd_trc);

    /*
     * might want to override from TRACE environment variable here.
     */

    /*
     * Establish pointers to icode data regions.		[[I?]]
     */
    pstate->Code    = (char *)(pstate + 1);
    initptrs(pstate, &hdr);
    initalloc(pstate);
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

/*
 * initalloc - initialization routine to allocate string/block memory regions
 */

static void initalloc(struct progstate *p)
{
    struct region *ps, *pb;

    ps = p->stringregion;
    Protect(ps->free = ps->base = malloc(ps->size), fatalerr(313, NULL));
    ps->end = ps->base + ps->size;

    pb = p->blockregion;
    Protect(pb->free = pb->base = malloc(pb->size), fatalerr(314, NULL));
    pb->end = pb->base + pb->size;
}


static void initprogstate(struct progstate *p)
{
    p->eventmask= nulldesc;
    p->opcodemask= nulldesc;
    p->eventcount = zerodesc;
    p->valuemask= nulldesc;
    p->eventcode= nulldesc;
    p->eventval = nulldesc;
    p->eventsource = nulldesc;
    p->Kywd_err = zerodesc;
    p->Kywd_pos = onedesc;
    p->Kywd_why = emptystr;
    p->Kywd_subject = emptystr;
    p->Kywd_ran = zerodesc;
    p->K_errornumber = 0;
    p->T_errornumber = 0;
    p->Have_errval = 0;
    p->T_have_val = 0;
    p->K_errortext = emptystr;
    p->K_errorvalue = nulldesc;
    p->T_errorvalue = nulldesc;
    p->T_errortext = emptystr;
    p->Coexp_ser = 2;
    p->List_ser = 1;
    p->Set_ser = 1;
    p->Table_ser = 1;
    gettimeofday(&p->start_time, 0);
    p->Lastop = 0;
    p->Xargp = NULL;
    p->Xnargs = 0;
    p->Xexpr = nulldesc;
    p->Xfno = 0;
    p->Value_tmp = nulldesc;

    p->stringtotal = p->blocktotal = p->stattotal = p->statcurr =
        p->colltot = p->collstat = p->collstr = p->collblk = 0;
    p->statcount = 0;

    p->Cplist = cplist_0;
    p->Cpset = cpset_0;
    p->Cptable = cptable_0;
    p->Interp = interp_0;
    p->Cnvcset = cnv_cset_0;
    p->Cnvucs = cnv_ucs_0;
    p->Cnvint = cnv_int_0;
    p->Cnvreal = cnv_real_0;
    p->Cnvstr = cnv_str_0;
    p->Cnvtstr = cnv_tstr_0;
    p->Deref = deref_0;
    p->Alcbignum = alcbignum_0;
    p->Alccset = alccset_0;
    p->Alchash = alchash_0;
    p->Alcsegment = alcsegment_0;
    p->Alclist_raw = alclist_raw_0;
    p->Alclist = alclist_0;
    p->Alclstb = alclstb_0;
    p->Alcreal = alcreal_0;
    p->Alcrecd = alcrecd_0;
    p->Alcobject = alcobject_0;
    p->Alccast = alccast_0;
    p->Alcmethp = alcmethp_0;
    p->Alcucs = alcucs_0;
    p->Alcrefresh = alcrefresh_0;
    p->Alcselem = alcselem_0;
    p->Alcstr = alcstr_0;
    p->Alcsubs = alcsubs_0;
    p->Alctelem = alctelem_0;
    p->Alctvtbl = alctvtbl_0;
    p->Dealcblk = dealcblk_0;
    p->Dealcstr = dealcstr_0;
    p->Reserve = reserve_0;
}

static void initptrs(struct progstate *p, struct header *h)
{
    p->icodesize = h->icodesize;
    p->Ecode = (char *)(p->Code + h->ClassStatics);
    p->ClassStatics = (dptr)(p->Ecode);
    p->ClassMethods = p->EClassStatics = (dptr)(p->Code + h->ClassMethods);
    p->EClassMethods = (dptr)(p->Code + h->ClassFields);
    p->ClassFields = (struct class_field *)(p->EClassMethods);
    p->EClassFields = (struct class_field *)(p->Code + h->ClassFieldLocs);
    p->ClassFieldLocs = (struct loc *)(p->EClassFields);
    p->EClassFieldLocs = (struct loc *)(p->Code + h->Classes);
    p->Classes = (word *)(p->EClassFieldLocs);
    p->Records = (word *)(p->Code + h->Records);
    p->Fnames  = (dptr)(p->Code + h->Fnames);
    p->Globals = p->Efnames = (dptr)(p->Code + h->Globals);
    p->Gnames  = p->Eglobals = (dptr)(p->Code + h->Gnames);
    p->Egnames = (dptr)(p->Code + h->Glocs);
    p->Glocs = (struct loc *)(p->Egnames);
    p->Eglocs = (struct loc *)(p->Code + h->Statics);
    p->NGlobals = p->Eglobals - p->Globals;
    p->Statics = (dptr)(p->Eglocs);
    p->Estatics = (dptr)(p->Code + h->Filenms);
    p->NStatics = p->Estatics - p->Statics;
    p->Filenms = (struct ipc_fname *)(p->Estatics);
    p->Efilenms = (struct ipc_fname *)(p->Code + h->linenums);
    p->Ilines = (struct ipc_line *)(p->Efilenms);
    p->Elines = (struct ipc_line *)(p->Code + h->Strcons);
    p->Strcons = (char *)(p->Elines);
    p->Estrcons = (char *)(p->Code + h->icodesize);
}




" load a program corresponding to string s as a co-expression."

function{1} lang_Prog_load(s,arglist,
                           blocksize, stringsize, stacksize)
   declare {
      tended char *loadstring;
      C_integer _bs_, _ss_, _stk_;
      }
   if !cnv:C_string(s,loadstring) then
      runerr(103,s)
   if !def:C_integer(blocksize, rootblock.size,_bs_) then
      runerr(101,blocksize)
   if !def:C_integer(stringsize, rootstring.size,_ss_) then
      runerr(101,stringsize)
   if !def:C_integer(stacksize,mstksize,_stk_) then
      runerr(101,stacksize)
   abstract {
      return coexpr
      }
   body {
      word *stack;
      struct progstate *pstate;
      register struct b_coexpr *sblkp;
      struct ef_marker *newefp;
      register word *savedsp;

      /*
       * Fragments of pseudo-icode to get loaded programs started,
       * and to handle termination.
       */
      static word pstart[7];
      static word *lterm;

      word *tipc;

      tipc = pstart;
      *tipc++ = Op_Invoke;
      *tipc++ = 1;
      *tipc++ = Op_Coret;
      *tipc++ = Op_Efail;

      lterm = (word *)(tipc);

      *tipc++ = Op_Cofail;
      *tipc++ = Op_Agoto;
      *tipc = (word)lterm;

      /*
       * arglist must be a list
       */
      if (!is:null(arglist) && !is:list(arglist))
         runerr(108,arglist);

      stack = (word *)(sblkp = loadicode(loadstring, _bs_,_ss_,_stk_));
      if (!stack) {
          /* The file couldn't be opened (any format error causes termination) */
          errno2why();
          fail;
      }
      pstate = sblkp->program;

      savedsp = sp;
      sp = stack + Wsizeof(struct b_coexpr)
        + Wsizeof(struct progstate) + pstate->icodesize/WordSize;

      if (pstate->icodesize % WordSize) 
          sp++;

#ifdef UpStack
      sblkp->cstate[0] =
         ((word)((char *)sblkp + (_stk_ - (sizeof(*sblkp)+sizeof(struct progstate)+pstate->icodesize))/2)
            &~((word)WordSize*StackAlign-1));
#else					/* UpStack */
      sblkp->cstate[0] =
	((word)((char *)sblkp + _stk_ - WordSize + sizeof(struct progstate) + pstate->icodesize)
           &~((word)WordSize*StackAlign-1));
#endif					/* UpStack */

      sblkp->es_argp = NULL;
      sblkp->es_gfp = NULL;

      /*
       * Set up expression frame marker to contain execution of the
       *  main procedure.  If failure occurs in this context, control
       *  is transferred to lterm, the address of an ...
       */
      newefp = (struct ef_marker *)sp;
      newefp->ef_failure = lterm;
      newefp->ef_gfp = 0;
      newefp->ef_efp = 0;
      newefp->ef_ilevel = ilevel;
      sp += Wsizeof(*newefp) - 1;   /* SP now points to last word of efp */
      sblkp->es_efp = newefp;

      /*
       * Check whether resolve() found the main procedure.  If not, this
       * is noted as run-time error 117.  Otherwise, this value is
       * pushed on the stack.
       */
      if (!pstate->MainProc)
         fatalerr(117, NULL);

      PushDesc(*pstate->MainProc);

      /*
       * Create a list from arguments using Ollist and push a descriptor
       * onto new stack.  Then create procedure frame on new stack.  Push
       * two new null descriptors, and set sblkp->es_sp when all finished.
       */
      if (!is:null(arglist)) {
         PushDesc(arglist);
         }
      else {
         PushNull;
         {
         dptr tmpargp = (dptr) (sp - 1);
         Ollist(0, tmpargp);
         sp = (word *)tmpargp + 1;
         }
         }
      sblkp->es_sp = (word *)sp;
      sblkp->es_ipc = pstart;

      result.dword = D_Coexpr;
      BlkLoc(result) = (union block *)sblkp;

      sp = savedsp;

      return result;
      }
end

#define NativeDef(class,field,func) extern struct b_iproc B##func##;
#include "../h/nativedefs.h"
#undef NativeDef

static struct b_iproc *native_methods[] = {
#define NativeDef(class,field,func) &B##func##,
#include "../h/nativedefs.h"
#undef NativeDef
};

/*
 * resolve - perform various fix-ups on the data read from the icode
 *  file.
 */
void resolve(struct progstate *p)
{
    word i, j, n_fields;
    struct b_proc *pp;
    struct class_field *cf;
    dptr dp;
    struct ipc_fname *fnptr;
    struct loc *lp;

    /*
     * For each class field info block, relocate the pointer to the
     * defining class and the descriptor.
     */
    for (cf = p->ClassFields; cf < p->EClassFields; cf++) {
        StrLoc(cf->name) = p->Strcons + (uword)StrLoc(cf->name);
        cf->defining_class = (struct b_class*)(p->Code + (int)cf->defining_class);
        if (cf->field_descriptor) {
            cf->field_descriptor = (dptr)(p->Code + (int)cf->field_descriptor);
            /* Follow the same logic as lcode.c */
            if (cf->flags & M_Defer) {
                int n = IntVal(*cf->field_descriptor);
                if (n == -1) {
                    /* Unresolved, point to stub */
                    BlkLoc(*cf->field_descriptor) = (union block *)&Bdeferred_method_stub;
                } else {
                    /* Resolved to native method, do sanity checks, set pointer */
                    if (n < 0 || n >= ElemCount(native_methods))
                        ffatalerr("Native method index out of range: %d", n);
                    pp = (struct b_proc *)native_methods[n];

                    /* The field name should match the end of the procedure block's name */
                    if (strncmp(StrLoc(cf->name),
                                StrLoc(pp->pname) + StrLen(pp->pname) - StrLen(cf->name),
                                StrLen(cf->name)))
                        ffatalerr("Native method name mismatch: %s", StrLoc(cf->name));

                    /* Pointer back to the corresponding field */
                    pp->field = cf;
                    BlkLoc(*cf->field_descriptor) = (union block *)pp;
                }
            } else if (cf->flags & M_Method) {
                /*
                 * Method in the icode file, relocate the entry point
                 * and the names of the parameters, locals, and static
                 * variables.
                 */
                pp = (struct b_proc *)(p->Code + IntVal(*cf->field_descriptor));
                BlkLoc(*cf->field_descriptor) = (union block *)pp;
                /* Pointer back to the corresponding field */
                pp->field = cf;
                /* Relocate the name */
                StrLoc(pp->pname) = p->Strcons + (uword)StrLoc(pp->pname);
                /* The entry point */
                pp->entryp.icode = p->Code + pp->entryp.ioff;
                /* The statics */
                if (pp->nstatic == 0)
                    pp->fstatic = 0;
                else
                    pp->fstatic = (dptr)(p->Statics + (int)pp->fstatic);
                /* The two tables */
                pp->lnames = (dptr)(p->Code + (int)pp->lnames);
                if (pp->llocs)
                    pp->llocs = (struct loc *)(p->Code + (int)pp->llocs);
                /* The variables */
                for (i = 0; i < abs((int)pp->nparam) + pp->ndynam + pp->nstatic; i++) {
                    StrLoc(pp->lnames[i]) = p->Strcons + (uword)StrLoc(pp->lnames[i]);
                    if (pp->llocs)
                        StrLoc(pp->llocs[i].fname) = p->Strcons + (uword)StrLoc(pp->llocs[i].fname);
                }
                pp->program = p;
            }
        }
#ifdef DEBUG_LOAD
        printf("%8x\t\tClass field struct\n", cf);
        printf("\t%08o\t  Flags\n", cf->flags);
        printf("\t%.*s\t\t  Fname\n", StrLen(cf->name), StrLoc(cf->name));
        printf("\t%8x\t  Defining class\n", cf->defining_class);
        printf("\t%8x\t  Descriptor\n", cf->field_descriptor);
#endif
    }

    /*
     * Relocate the field location file names.
     */
    for (lp = p->ClassFieldLocs; lp < p->EClassFieldLocs; lp++)
        StrLoc(lp->fname) = p->Strcons + (uword)StrLoc(lp->fname);

    /*
     * Relocate the names of the global variables.
     */
    for (dp = p->Gnames; dp < p->Egnames; dp++)
        StrLoc(*dp) = p->Strcons + (uword)StrLoc(*dp);

    /*
     * Relocate the location file names of the global variables.
     */
    for (lp = p->Glocs; lp < p->Eglocs; lp++)
        StrLoc(lp->fname) = p->Strcons + (uword)StrLoc(lp->fname);

    /*
     * Scan the global variable array and relocate all blocks. Also
     * note the main procedure if found.
     */
    p->MainProc = 0;
    for (j = 0; j < p->NGlobals; j++) {
        switch (p->Globals[j].dword) {
            case D_Class: {
                struct b_class *cb;
                i = IntVal(p->Globals[j]);
                cb = (struct b_class *)(p->Code + i);
                BlkLoc(p->Globals[j]) = (union block *)cb;
                StrLoc(cb->name) = p->Strcons + (uword)StrLoc(cb->name);
                if (cb->init_field)
                    cb->init_field = (struct class_field *)(p->Code + (int)cb->init_field);
                if (cb->new_field)
                    cb->new_field = (struct class_field *)(p->Code + (int)cb->new_field);
                cb->program = p;
                n_fields = cb->n_class_fields + cb->n_instance_fields;
                cb->supers = (struct b_class **)(p->Code + (int)cb->supers);
                for (i = 0; i < cb->n_supers; ++i) 
                    cb->supers[i] = (struct b_class*)(p->Code + (int)cb->supers[i]);
                cb->implemented_classes = (struct b_class **)(p->Code + (int)cb->implemented_classes);
                for (i = 0; i < cb->n_implemented_classes; ++i) 
                    cb->implemented_classes[i] = (struct b_class*)(p->Code + (int)cb->implemented_classes[i]);
                cb->fields = (struct class_field **)(p->Code + (int)cb->fields);
                for (i = 0; i < n_fields; ++i) 
                    cb->fields[i] = (struct class_field*)(p->Code + (int)cb->fields[i]);
                cb->sorted_fields = (short *)(p->Code + (int)cb->sorted_fields);
#ifdef DEBUG_LOAD
                printf("%8x\t\t\tClass\n", cb);
                printf("\t%d\t\t\t  Title\n", cb->title);
                printf("\t%d\t\t\t  N supers\n", cb->n_supers);
                printf("\t%d\t\t\t  N implemented classes\n", cb->n_implemented_classes);
                printf("\t%d\t\t\t  N implemented instance class fields\n", cb->n_instance_fields);
                printf("\t%d\t\t\t  N implemented class fields\n", cb->n_class_fields);
                for (i = 0; i < cb->n_supers; ++i) 
                    printf("\t%8x\t\t\t  Superclass %d\n",cb->supers[i], i);
                for (i = 0; i < cb->n_implemented_classes; ++i) 
                    printf("\t%8x\t\t\t  Implemented class %d\n",cb->implemented_classes[i], i);
                for (i = 0; i < n_fields; ++i) 
                    printf("\t%8x\t\t\t  Field info %d\n",cb->fields[i], i);
                for (i = 0; i < n_fields; ++i) 
                    printf("\t%d\t\t\t  Sorted field array\n",cb->sorted_fields[i]);
#endif
                break;
            }

            case D_Constructor: {
                struct b_constructor *c;
                i = IntVal(p->Globals[j]);
                c = (struct b_constructor *)(p->Code + i);
                BlkLoc(p->Globals[j]) = (union block *)c;
                c->program = p;
                c->field_names = (struct descrip *)(p->Code + (int)c->field_names);
                if (c->field_locs)
                    c->field_locs = (struct loc *)(p->Code + (int)c->field_locs);
                c->sorted_fields = (short *)(p->Code + (int)c->sorted_fields);
                /*
                 * Relocate the name and fields
                 */
                StrLoc(c->name) = p->Strcons + (uword)StrLoc(c->name);
                for (i = 0; i < c->n_fields; i++) {
                    StrLoc(c->field_names[i]) = p->Strcons + (uword)StrLoc(c->field_names[i]);
                    if (c->field_locs)
                        StrLoc(c->field_locs[i].fname) = p->Strcons + (uword)StrLoc(c->field_locs[i].fname);
                }
                break;
            }
            case D_Proc: {
                /*
                 * The second word of the descriptor for procedure variables tells
                 *  where the procedure is.  Negative values are used for built-in
                 *  procedures and positive values are used for Icon procedures.
                 */
                i = IntVal(p->Globals[j]);
                if (i < 0) {
                    /*
                     * It is a builtin function.  Calculate the index and carry out
                     * some sanity checks on it.
                     */
                    int n = -1 - i;
                    if (n < 0 || n >= pnsize)
                        ffatalerr("Builtin function index out of range: %d", n);
                    BlkLoc(p->Globals[j]) = (union block *)pntab[n].pblock;
                    if (!eq(&p->Gnames[j], &pntab[n].pblock->pname))
                        ffatalerr("Builtin function index name mismatch: %s", StrLoc(p->Gnames[j]));
                }
                else {

                    /*
                     * p->Globals[j] points to an Icon procedure; i is an offset
                     *  to location of the procedure block in the code section.  Point
                     *  pp at the block and replace BlkLoc(p->Globals[j]).
                     */
                    pp = (struct b_proc *)(p->Code + i);
                    BlkLoc(p->Globals[j]) = (union block *)pp;

                    /*
                     * Relocate the address of the name of the procedure.
                     */
                    StrLoc(pp->pname) = p->Strcons + (uword)StrLoc(pp->pname);

                    /* The statics */
                    if (pp->nstatic == 0)
                        pp->fstatic = 0;
                    else
                        pp->fstatic = (dptr)(p->Statics + (int)pp->fstatic);

                    /*
                     * This is an Icon procedure.  Relocate the entry point and
                     *	the names of the parameters, locals, and static variables.
                     */
                    pp->entryp.icode = p->Code + pp->entryp.ioff;
                    pp->lnames = (dptr)(p->Code + (int)pp->lnames);
                    if (pp->llocs)
                        pp->llocs = (struct loc *)(p->Code + (int)pp->llocs);
                    for (i = 0; i < abs((int)pp->nparam) + pp->ndynam + pp->nstatic; i++) {
                        StrLoc(pp->lnames[i]) = p->Strcons + (uword)StrLoc(pp->lnames[i]);
                        if (pp->llocs)
                            StrLoc(pp->llocs[i].fname) = p->Strcons + (uword)StrLoc(pp->llocs[i].fname);
                    }

                    /*
                     * Is it the main procedure?
                     */
                    if (StrLen(pp->pname) == 4 &&
                        !strncmp(StrLoc(pp->pname), "main", 4))
                        p->MainProc = &p->Globals[j];

                    pp->program = p;
                }
                break;
            }
        }
    }

    /*
     * Relocate the names of the fields.
     */
    for (dp = p->Fnames; dp < p->Efnames; dp++)
        StrLoc(*dp) = p->Strcons + (uword)StrLoc(*dp);

    /*
     * Relocate the names of the files in the ipc->filename table.
     */
    for (fnptr = p->Filenms; fnptr < p->Efilenms; ++fnptr)
        StrLoc(fnptr->fname) = p->Strcons + (uword)StrLoc(fnptr->fname);
}

/*
 * The rest of the functions here are just debugging utilities.
 */

void *get_csp()
{
    int dummy = 0;
    unsigned long l;
    l = (long)&dummy;
    return (void*)l;
}

void checkstack()
{
    static int worst = MaxInt;
    long free;
    if (curpstate->K_current == rootpstate.K_main)
        return;
    free = (char*)get_csp() - (char*)sp;
    if (free < worst) {
        fprintf(stderr, "A new low in stack space: %ld\n",free);
        fflush(stderr);
        worst = free;
    }
}

void showcoexps()
{
    struct b_coexpr *p;
    struct progstate *q;
    void *csp = get_csp();

    printf("Coexpressions\n");
    printf("Coexp       program     main_of     size        es_sp       C sp        ipc         pfp         argp\n");
    printf("----------------------------------------------------------------------------------------------------\n");
    for (p = stklist; p; p = p->nextstk) {
        printf("%-12p%-12p%-12p%-12d%-12p%-12p%-12p%-12p%-12p\n",
               p,
               p->program,
               p->main_of,
               p->size,
               p->es_sp,
               (char*)p->cstate[0],
               p->es_ipc,
               p->es_pfp,
               p->es_argp);
    }

    printf("\nProgstates\n");
    printf("Addr        Code        Ecode       &main       &current    Name\n");
    printf("----------------------------------------------------------------------------\n");
    for (q = progs; q; q = q->next) {
        printf("%-12p%-12p%-12p%-12p%-12p%s\n", 
               q, 
               q->Code, 
               q->Ecode,
               q->K_main,
               q->K_current,
               cstr(&q->Kywd_prog));
    }

    printf("\nVariables\n");
    printf("curpstate=%p rootpstate=%p &main=%p &current=%p\n", 
           curpstate, 
           &rootpstate,
           curpstate->K_main,
           curpstate->K_current);

    if (curpstate->K_current != rootpstate.K_main)
        printf("ilevel=%d ISP=%p CSP=%p (clearance %d)\n", ilevel,sp, csp, (char*)csp - (char*)sp);
    else
        printf("ilevel=%d ISP=%p CSP=%p\n", ilevel,sp, csp);

    fflush(stdout);
}

int valid_addr(void *p) 
{
  extern char _etext;
  return (p != NULL) && ((char*) p > &_etext);
}

static int isdescrip(word *p){
    struct descrip *d = (struct descrip *)p;
    word i = d->dword;

    if (Qual(*d))
        return StrLen(*d) == 0 || valid_addr(StrLoc(*d));

    if (i==D_Null || i==D_Integer)
        return 1;

    if (DVar(*d) || i==D_Lrgint || i==D_Real ||
            i==D_Cset || i==D_Proc || i==D_Record || i==D_List ||
            i==D_Lelem || i==D_Set || i==D_Selem || i==D_Table || i==D_Telem ||
            i==D_Tvtbl || i==D_Slots || i==D_Tvsubs || i==D_Refresh || i==D_Coexpr ||
            i==D_Kywdint || i==D_Kywdpos || i==D_Kywdsubj ||
            i==D_Kywdstr || i==D_Kywdevent || i==D_Class || i==D_Object || i==D_Cast ||
            i==D_Constructor || i==D_Methp || i==D_Ucs)
        return valid_addr(BlkLoc(*d));

    return 0;
}

char *binstr(unsigned int n)
{
    static char res[33];
    int i;
    res[32] = 0;
    for (i = 0; i < 32; ++i) {
        res[31-i] = '0'+(n&1);
        n>>=1;
    }
    return res;
}

char *cstr(struct descrip *sd) 
{
    static char res[256];
    int n = StrLen(*sd);
    if (n > 255)
        n = 255;
    memcpy(res, StrLoc(*sd), n);
    res[n] = 0;
    return res;
}

void print_desc(FILE *f, dptr d) {
    putc('{', f);
    print_dword(f, d);
    fputs(", ", f); 
    print_vword(f, d);
    putc('}', f);
}

void print_vword(FILE *f, dptr d) {
    if (Qual(*d)) {
        fprintf(f, "%p -> ", StrLoc(*d));
        outimage(f, d, 1);
    } else if (DVar(*d)) {
        /* D_Var (with an offset) */
        fprintf(f, "D_Var off:%d", Offset(*d));
        fprintf(f, "%p+%d -> ", VarLoc(*d), Offset(*d));
        print_desc(f, (dptr)((word*)VarLoc(*d) + Offset(*d)));
    } else {
        switch (d->dword) {
            case D_Tvsubs : {
                struct b_tvsubs *p = (struct b_tvsubs *)BlkLoc(*d);
                fprintf(f, "%p -> sub=%d+:%d ssvar=", p, p->sspos, p->sslen);
                print_desc(f, &p->ssvar);
                break;
            }

            case D_Tvtbl : {
                struct b_tvtbl *p = (struct b_tvtbl *)BlkLoc(*d);
                fprintf(f, "%p -> tref=", p);
                print_desc(f, &p->tref);
                break;
            }

            case D_Kywdint :
            case D_Kywdpos :
            case D_Kywdsubj :
            case D_Kywdstr :
            case D_Kywdevent : {
                fprintf(f, "%p -> ", VarLoc(*d));
                print_desc(f, VarLoc(*d));
                break;
            }

            case D_Null : {
                fputs("0", f); 
                break;
            }

            case D_Integer : {
                fprintf(f, "%d", d->vword.integr); 
                break;
            }

            case D_Lelem :
            case D_Selem :
            case D_Telem :
            case D_Slots :
            case D_Refresh :

            case D_Proc : {
                struct b_proc *p = (struct b_proc*)BlkLoc(*d);
                fprintf(f, "%p -> prog:%p=", p, p->program);
                outimage(f, d, 1);
                break;
            }

            case D_Class : {
                struct b_class *p = (struct b_class*)BlkLoc(*d);
                fprintf(f, "%p -> prog:%p=", p, p->program);
                outimage(f, d, 1);
                break;
            }

            case D_Constructor : {
                struct b_constructor *p = (struct b_constructor*)BlkLoc(*d);
                fprintf(f, "%p -> prog:%p=", p, p->program);
                outimage(f, d, 1);
                break;
            }

            case D_List :
            case D_Set : 
            case D_Table :
            case D_Record :
            case D_Coexpr :
            case D_Lrgint :
            case D_Real :
            case D_Cset :
            case D_Methp :
            case D_Ucs :
            case D_Cast :
            case D_Object : {
                fprintf(f, "%p -> ", BlkLoc(*d));
                outimage(f, d, 1);
                break;
            }

            default : fputs("?", f); 
        }
    }
}

void print_dword(FILE *f, dptr d) {
    if (Qual(*d)) {
        /* String */
        fprintf(f, "%d", d->dword);
    } else if (DVar(*d)) {
        /* D_Var (with an offset) */
        fprintf(f, "D_Var off:%d", Offset(*d));
    } else {
        switch (d->dword) {
            case D_Tvsubs : fputs("D_Tvsubs", f); break;
            case D_Tvtbl : fputs("D_Tvtbl", f); break;
            case D_Kywdint : fputs("D_Kywdint", f); break;
            case D_Kywdpos : fputs("D_Kywdpos", f); break;
            case D_Kywdsubj : fputs("D_Kywdsubj", f); break;
            case D_Kywdstr : fputs("D_Kywdstr", f); break;
            case D_Kywdevent : fputs("D_Kywdevent", f); break;
            case D_Null : fputs("D_Null", f); break;
            case D_Integer : fputs("D_Integer", f); break;
            case D_Lrgint : fputs("D_Lrgint", f); break;
            case D_Real : fputs("D_Real", f); break;
            case D_Cset : fputs("D_Cset", f); break;
            case D_Proc : fputs("D_Proc", f); break;
            case D_Record : fputs("D_Record", f); break;
            case D_List : fputs("D_List", f); break;
            case D_Lelem : fputs("D_Lelem", f); break;
            case D_Set : fputs("D_Set", f); break;
            case D_Selem : fputs("D_Selem", f); break;
            case D_Table : fputs("D_Table", f); break;
            case D_Telem : fputs("D_Telem", f); break;
            case D_Slots : fputs("D_Slots", f); break;
            case D_Refresh : fputs("D_Refresh", f); break;
            case D_Coexpr : fputs("D_Coexpr", f); break;
            case D_Class : fputs("D_Class", f); break;
            case D_Object : fputs("D_Object", f); break;
            case D_Cast : fputs("D_Cast", f); break;
            case D_Constructor : fputs("D_Constructor", f); break;
            case D_Methp : fputs("D_Methp", f); break;
            case D_Ucs : fputs("D_Ucs", f); break;
            default : fputs("?", f);
        }
    }
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
    else if (p == argp)
        return "argp->";
    else
        return "";
}

void showstack()
{
    struct b_coexpr *c;
    word *p;

    printf("Stack sp=%p efp=%p gfp=%p pfp=%p ipc=%p\n",sp,efp,gfp,pfp,ipc);
    c = k_current;
    if (!c) {
        printf("curpstate=%p k_current is 0\n",curpstate);
        return;
    }    
    printf("kcurr->\t%p\tcoex\ttitle=%d\n", c, c->title);
    printf("\t\t\tsize=%d\n",c->size);
    printf("\t\t\tid=%d\n",c->id);
    printf("\t\t\tnextstk=%p\n",c->nextstk);
    printf("\t\t\tes_pfp=%p\n",c->es_pfp);
    printf("\t\t\tes_efp=%p\n",c->es_efp);
    printf("\t\t\tes_gfp=%p\n",c->es_gfp);
    printf("\t\t\tes_ipc=%p\n",c->es_ipc);
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
            printf("\t%p\tcode\ticodesize=%ld\n",p,(long)t->icodesize);
            p += t->icodesize / WordSize;
            /* Pad.. see corresponding code in fmisc.r */
            if (t->icodesize % WordSize)
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
            printf("%s\t\t\tgf_ipc=%p\n",ptr(&t->gf_ipc),t->gf_ipc);
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
            printf("%s\t%p\tefp\tef_failure=%p\n",ptr(p),p,t->ef_failure);
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
            printf("\t\t\tpf_ipc=%p\n",t->pf_ipc);
            printf("\t\t\tpf_ilevel=%d\n",t->pf_ilevel);
            printf("\t\t\tpf_scan=%p\n",t->pf_scan);
            printf("\t\t\tpf_from=%p\n",t->pf_from);
            printf("%s\t\t\tpf_to=%p\n",ptr(&t->pf_to),t->pf_to);
            p += (sizeof(struct pf_marker)-sizeof(struct descrip))/sizeof(word);
        } else if (isdescrip(p)) {
            dptr d = (dptr)p;
            printf("%s\t%p\tdescrip\t", ptr(p), p);
            print_dword(stdout, d);
            putc('\n', stdout);
            printf("%s\t\t\t", ptr(&d->vword));
            print_vword(stdout, d);
            putc('\n', stdout);
            p += sizeof(struct descrip)/sizeof(word);
        } else {
            printf("%s\t%p\t?\t%x\n",ptr(p),p,*p);
            ++p;
        }
    }
    printf("--------\n");
    fflush(stdout);
}

struct progstate *findprogramforicode(word *x)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->Code, x, p->Ecode))
            return p;
    }
    return NULL;
}


