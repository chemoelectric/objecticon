/*
 * File: init.r
 * Initialization, termination, and such.
 */

#include "../h/header.h"
#include "../h/opdefs.h"
#include "../h/modflags.h"

static FILE    *readhdr	(char *name, struct header *hdr);
static void    initptrs (struct progstate *p, struct header *h);
static void    initprogstate(struct progstate *p);
static void    initalloc(struct progstate *p);
static void    handle_monitored_prog_exit();

/*
 * External declarations for operator and function blocks.
 */

#define OpDef(f)  extern struct b_proc Cat(B,f);
#include "../h/odefs.h"
#undef OpDef

#define FncDef(f)  extern struct b_proc Cat(B,f);
#include "../h/fdefs.h"
#undef FncDef

/* 
 * operators table
 */
#define OpDef(f)  Cat(&B,f),
struct b_proc *op_tbl[] = {
#include "../h/odefs.h"
};
#undef OpDef

/*
 * function table
 */

#define FncDef(f)  Cat(&B,f),
struct b_proc *fnc_tbl[] = {
#include "../h/fdefs.h"
};
#undef FncDef

/*
 * A number of important variables follow.
 */

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


struct progstate *progs;        /* list of progstates */

struct tend_desc *tend = NULL;  /* chain of tended descriptors */

struct region rootstring, rootblock;



int op_tbl_sz = ElemCount(op_tbl);
int fnc_tbl_sz = ElemCount(fnc_tbl);


struct progstate *curpstate;
struct progstate rootpstate;


/*
 * Open the icode file and read the header.
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
        if ((cbread = gzread(zfd, codeptr, hdr->icodesize)) != hdr->icodesize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->icodesize,(long)cbread);
            ffatalerr("bad icode file: %s", name);
        }
        gzclose(zfd);
    } else {
        if ((cbread = fread(codeptr, 1, hdr->icodesize, ifile)) != hdr->icodesize) {
            fprintf(stderr,"Tried to read %ld bytes of code, got %ld\n",
                    (long)hdr->icodesize,(long)cbread);
            ffatalerr("bad icode file: %s", name);
        }
    }
#else					/* HAVE_LIBZ */
    if ((cbread = fread(codeptr, 1, hdr->icodesize, ifile)) != hdr->icodesize) {
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
    longlong pmem;
    struct b_coexpr *mainhead;
    double d;

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

    nullptr.dword = D_TendPtr;
    BlkLoc(nullptr) = 0;

    nulldesc.dword = D_Null;
    IntVal(nulldesc) = 0;

    d = 0.0;
    SetReal(d, realzero);
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
    rootstring.size = Max(pmem/200, MinDefStrSpace);
    rootblock.size  = Max(pmem/100, MinDefAbrSize);

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
    env_int(STRSIZE, &rootstring.size, 1, (uword)MaxWord);
    env_int(BLKSIZE, &rootblock.size, 1, (uword)MaxWord); 
    env_int(QLSIZE, &qualsize, 1, (uword)MaxWord);
    env_int(IXCUSHION, &memcushion, 1, (uword)100);	/* max 100 % */
    env_int(IXGROWTH, &memgrowth, 1, (uword)10000);	/* max 100x growth */
    env_int(OICORE, &dodump, 1, (uword)2);


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
     * Allocate and initialize &main.
     */

    Protect(mainhead = alccoexp(), fatalerr(303, NULL));
    mainhead->size = 1;			/* pretend main() does an activation */
    mainhead->main_of = mainhead->creator = mainhead->program = &rootpstate;
    mainhead->activator = mainhead;

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
    while (isdigit((unsigned char)*s)) {
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
    if (set_up) {
        struct ipc_line *pline;
        struct ipc_fname *pfile;

        pline = frame_ipc_line(PF, 1);
        pfile = frame_ipc_fname(PF, 1);

        if (pline && pfile) {
            struct descrip t;
            abbr_fname(&pfile->fname, &t);
            fprintf(stderr, " at line %d in %.*s", (int)pline->line, (int)StrLen(t), StrLoc(t));
        } else
            fprintf(stderr, " at line ? in ?");
    }
    else
        fprintf(stderr, " in startup code");

    fprintf(stderr, "\n");
    vfprintf(stderr, fmt, ap);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(ap);

    if (!set_up) {		/* skip if start-up problem */
        if (dodump)
            abort();
        c_exit(EXIT_FAILURE);
    }
    fprintf(stderr, "Traceback:\n");
    traceback();
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

    if (k_dump && set_up) {
        fprintf(stderr,"\nTermination dump:\n\n");
        fflush(stderr);
        fprintf(stderr,"co-expression #%ld(%ld)\n",
                (long)k_current->id,
                (long)k_current->size);
        fflush(stderr);
        xdisp(k_current->curr_pf,k_level,stderr, curpstate);
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
    p->monitor = 0;
    p->eventmask= nulldesc;
    p->event_queue_head = p->event_queue_tail = 0;
    p->Kywd_err = zerodesc;
    p->Kywd_pos = onedesc;
    p->Kywd_why = emptystr;
    p->Kywd_subject = emptystr;
    p->Kywd_ran = zerodesc;
    MakeInt(500, &p->Kywd_maxlevel);
    p->K_errornumber = 0;
    p->T_errornumber = 0;
    p->Have_errval = 0;
    p->T_have_val = 0;
    p->K_errortext = emptystr;
    p->K_errorvalue = nulldesc;
    p->T_errorvalue = nulldesc;
    p->T_errortext = emptystr;
    p->Coexp_ser = 1;
    p->List_ser = 1;
    p->Set_ser = 1;
    p->Table_ser = 1;
    gettimeofday(&p->start_time, 0);
    p->Lastop = 0;
    p->Xfield = p->Xexpr = p->Xargp = 0;
    p->Xnargs = 0;
    p->Xc_frame = 0;

    p->stringtotal = p->blocktotal = p->stackcurr = p->colluser = 
        p->collstack = p->collstr = p->collblk = 0;

    p->Cplist = cplist_0;
    p->Cpset = cpset_0;
    p->Cptable = cptable_0;
    p->Cnvcset = cnv_cset_0;
    p->Cnvucs = cnv_ucs_0;
    p->Cnvint = cnv_int_0;
    p->Cnvreal = cnv_real_0;
    p->Cnvstr = cnv_str_0;
    p->Cnvtstr = cnv_tstr_0;
    p->Deref = deref_0;
    p->Alccoexp = alccoexp_0;
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
    p->Estatics = (dptr)(p->Code + h->Constants);
    p->NStatics = p->Estatics - p->Statics;
    p->Constants = (dptr)(p->Estatics);
    p->Econstants = (dptr)(p->Code + h->Filenms);
    p->NConstants = p->Econstants - p->Constants;
    p->Filenms = (struct ipc_fname *)(p->Econstants);
    p->Efilenms = (struct ipc_fname *)(p->Code + h->linenums);
    p->Ilines = (struct ipc_line *)(p->Efilenms);
    p->Elines = (struct ipc_line *)(p->Code + h->Strcons);
    p->Strcons = (char *)(p->Elines);
    p->Estrcons = (char *)(p->Code + h->icodesize);
}


#include "initiasm.ri"

static void handle_monitored_prog_exit()
{
    curpstate->exited = 1;
    /* 
     * Decide whether the prog was run via activating its main coexpression,
     * or via the get_event function.
     */
    if (curpstate->monitor)
        curpstate = curpstate->monitor;
}

" load a program corresponding to string s as a co-expression."

function{1} lang_Prog_load(s, arglist, blocksize, stringsize)
   declare {
      tended char *loadstring;
      C_integer bs, ss;
      }
   if !cnv:C_string(s,loadstring) then
      runerr(103,s)
   if !def:C_integer(blocksize, rootblock.size,bs) then
      runerr(101,blocksize)
   if !def:C_integer(stringsize, rootstring.size,ss) then
      runerr(101,stringsize)
    body {
       struct progstate *pstate;
       tended struct b_coexpr *coex;
       struct header hdr;
       FILE *ifile;
       struct b_proc *main_bp;
       struct p_frame *new_pf;

       /*
        * arglist must be a list
        */
       if (!is:null(arglist) && !is:list(arglist))
           runerr(108,arglist);

       /*
        * open the icode file and read the header
        */
       ifile = readhdr(loadstring, &hdr);
       if (ifile == NULL) {
           /* The file couldn't be opened (any format error causes termination) */
           errno2why();
           fail;
       }

       /*
        * Allocate memory for icode and the struct that describes it
        */
       MemProtect(pstate = alcprog(hdr.icodesize));
       MemProtect(coex = alccoexp());
       coex->creator = curpstate;
       coex->main_of = coex->program = pstate;
       coex->activator = coex;

       initprogstate(pstate);
       pstate->Kywd_time_elsewhere = millisec();
       pstate->Kywd_time_out = 0;
       pstate->K_current = pstate->K_main = coex;

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

       CMakeStr(loadstring, &pstate->Kywd_prog);
       MakeInt(hdr.trace, &pstate->Kywd_trc);

       /*
        * Establish pointers to icode data regions.		[[I?]]
        */
       initptrs(pstate, &hdr);
       initalloc(pstate);
       check_version(&hdr, loadstring, ifile);
       read_icode(&hdr, loadstring, ifile, pstate->Code);

       fclose(ifile);

       resolve(pstate);

       pstate->next = progs;
       progs = pstate;

      /*
       * Check whether resolve() found the main procedure.
       */
      if (!pstate->MainProc)
         fatalerr(117, NULL);

       main_bp = (struct b_proc *)BlkLoc(*pstate->MainProc);
       MemProtect(new_pf = alc_p_frame((struct b_proc *)&Bmain_wrapper, 0));
       new_pf->locals->args[0] = *pstate->MainProc;
       coex->sp = (struct frame *)new_pf;
       coex->curr_pf = new_pf;
       coex->start_label = new_pf->ipc = Bmain_wrapper.icode;
       coex->failure_label = 0;

       if (main_bp->nparam) {
           if (is:null(arglist))
               create_list(0, &new_pf->locals->args[1]);
           else
               new_pf->locals->args[1] = arglist;
       }

      result.dword = D_Coexpr;
      BlkLoc(result) = (union block *)coex;

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
     * Relocate the names of the fields.
     */
    for (dp = p->Fnames; dp < p->Efnames; dp++)
        StrLoc(*dp) = p->Strcons + (uword)StrLoc(*dp);

    /*
     * For each class field info block, relocate the pointer to the
     * defining class and the descriptor.
     */
    for (cf = p->ClassFields; cf < p->EClassFields; cf++) {
        cf->defining_class = (struct b_class*)(p->Code + (uword)cf->defining_class);
        if (cf->field_descriptor) {
            cf->field_descriptor = (dptr)(p->Code + (uword)cf->field_descriptor);
            /* Follow the same logic as lcode.c */
            if (cf->flags & M_Defer) {
                int n = IntVal(*cf->field_descriptor);
                if (n == -1) {
                    /* Unresolved, point to stub */
                    BlkLoc(*cf->field_descriptor) = (union block *)&Bdeferred_method_stub;
                } else {
                    dptr fname;
                    /* Resolved to native method, do sanity checks, set pointer */
                    if (n < 0 || n >= ElemCount(native_methods))
                        ffatalerr("Native method index out of range: %d", n);
                    pp = (struct b_proc *)native_methods[n];
                    /* Clone the b_proc for a loaded program; we don't
                     * want to change the original's reference to the
                     * corresponding field (pp->field)
                     */
                    if (p != &rootpstate) 
                        pp = clone_b_proc(pp);
                    fname = &p->Fnames[cf->fnum];
                    /* The field name should match the end of the procedure block's name */
                    if (strncmp(StrLoc(*fname),
                                StrLoc(pp->name) + StrLen(pp->name) - StrLen(*fname),
                                StrLen(*fname)))
                        ffatalerr("Native method name mismatch: %.*s", 
                                  (int)StrLen(*fname), StrLoc(*fname));
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
                StrLoc(pp->name) = p->Strcons + (uword)StrLoc(pp->name);
                /* The entry point */
                pp->icode = (word *)(p->Code + (uword)pp->icode);
                /* The statics */
                if (pp->nstatic == 0)
                    pp->fstatic = 0;
                else
                    pp->fstatic = (dptr)(p->Statics + (uword)pp->fstatic);
                /* The two tables */
                pp->lnames = (dptr)(p->Code + (uword)pp->lnames);
                if (pp->llocs)
                    pp->llocs = (struct loc *)(p->Code + (uword)pp->llocs);
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
                    cb->init_field = (struct class_field *)(p->Code + (uword)cb->init_field);
                if (cb->new_field)
                    cb->new_field = (struct class_field *)(p->Code + (uword)cb->new_field);
                cb->program = p;
                n_fields = cb->n_class_fields + cb->n_instance_fields;
                cb->supers = (struct b_class **)(p->Code + (uword)cb->supers);
                for (i = 0; i < cb->n_supers; ++i) 
                    cb->supers[i] = (struct b_class*)(p->Code + (uword)cb->supers[i]);
                cb->implemented_classes = (struct b_class **)(p->Code + (uword)cb->implemented_classes);
                for (i = 0; i < cb->n_implemented_classes; ++i) 
                    cb->implemented_classes[i] = (struct b_class*)(p->Code + (uword)cb->implemented_classes[i]);
                cb->fields = (struct class_field **)(p->Code + (uword)cb->fields);
                for (i = 0; i < n_fields; ++i) 
                    cb->fields[i] = (struct class_field*)(p->Code + (uword)cb->fields[i]);
                cb->sorted_fields = (short *)(p->Code + (uword)cb->sorted_fields);
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
                c->fnums = (word *)(p->Code + (uword)c->fnums);
                if (c->field_locs)
                    c->field_locs = (struct loc *)(p->Code + (uword)c->field_locs);
                c->sorted_fields = (short *)(p->Code + (uword)c->sorted_fields);
                /*
                 * Relocate the name and loc'ns
                 */
                StrLoc(c->name) = p->Strcons + (uword)StrLoc(c->name);
                if (c->field_locs) {
                    for (i = 0; i < c->n_fields; i++) 
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
                    if (n < 0 || n >= fnc_tbl_sz)
                        ffatalerr("Builtin function index out of range: %d", n);
                    BlkLoc(p->Globals[j]) = (union block *)fnc_tbl[n];
                    if (!eq(&p->Gnames[j], &fnc_tbl[n]->name))
                        ffatalerr("Builtin function index name mismatch: %.*s", 
                                  (int)StrLen(p->Gnames[j]), StrLoc(p->Gnames[j]));
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
                    StrLoc(pp->name) = p->Strcons + (uword)StrLoc(pp->name);

                    /* The statics */
                    if (pp->nstatic == 0)
                        pp->fstatic = 0;
                    else
                        pp->fstatic = (dptr)(p->Statics + (uword)pp->fstatic);

                    /*
                     * This is an Icon procedure.  Relocate the entry point and
                     *	the names of the parameters, locals, and static variables.
                     */
                    pp->icode = (word *)(p->Code + (uword)pp->icode);
                    pp->lnames = (dptr)(p->Code + (uword)pp->lnames);
                    if (pp->llocs)
                        pp->llocs = (struct loc *)(p->Code + (uword)pp->llocs);
                    for (i = 0; i < abs((int)pp->nparam) + pp->ndynam + pp->nstatic; i++) {
                        StrLoc(pp->lnames[i]) = p->Strcons + (uword)StrLoc(pp->lnames[i]);
                        if (pp->llocs)
                            StrLoc(pp->llocs[i].fname) = p->Strcons + (uword)StrLoc(pp->llocs[i].fname);
                    }

                    /*
                     * Is it the main procedure?
                     */
                    if (StrLen(pp->name) == 4 &&
                        !strncmp(StrLoc(pp->name), "main", 4))
                        p->MainProc = &p->Globals[j];

                    pp->program = p;
                }
                break;
            }
        }
    }

    /*
     * Relocate descriptors in the constants table, and their blocks for non-strings.
     */
    for (j = 0; j < p->NConstants; j++) {
        if (Qual(p->Constants[j]))
            StrLoc(p->Constants[j]) = p->Strcons + (uword)StrLoc(p->Constants[j]);
        else {
            union block *b;
            i = IntVal(p->Constants[j]);
            b = (union block *)(p->Code + i);
            BlkLoc(p->Constants[j]) = (union block *)b;
            if (p->Constants[j].dword == D_Ucs) {
                struct b_ucs *ub = (struct b_ucs *)b;
                /* Relocate the utf8 string */
                StrLoc(ub->utf8) = p->Strcons + (uword)StrLoc(ub->utf8);
            } else if (p->Constants[j].dword == D_Lrgint) {
                struct descrip id;
                dptr sd = (dptr)((word *)b + 1);
                StrLoc(*sd) = p->Strcons + (uword)StrLoc(*sd);
                /* Convert the string data to an integer */
                if (!cnv:integer(*sd, id)) {
                    ffatalerr("Couldn't convert large integer constant: %.*s", 
                        (int)StrLen(*sd), StrLoc(*sd));
                }
                /* It could be either a simple integer or a large int. */
                if (id.dword == D_Integer)
                    p->Constants[j] = id;
                else {
                    /* It must be a large int; copy the block from the block region to the heap
                     * since constants are not swept during collection.
                     */
                    MemProtect(BlkLoc(p->Constants[j]) = malloc(BlkLoc(id)->bignum.blksize));
                    memcpy(BlkLoc(p->Constants[j]), BlkLoc(id), BlkLoc(id)->bignum.blksize);
                }
            }
        }
    }

    /*
     * Relocate the names of the files in the ipc->filename table.
     */
    for (fnptr = p->Filenms; fnptr < p->Efilenms; ++fnptr)
        StrLoc(fnptr->fname) = p->Strcons + (uword)StrLoc(fnptr->fname);
}





#ifdef MSWindows

/*
 * CmdParamToArgv() - convert a command line to an argv array.  Return argc.
 * Called for both input processing (e.g. in WinMain()) and in output
 * (e.g. in mswinsystem()).  Behavior differs in that output does not
 * remove double quotes from quoted arguments, otherwise receiving process
 * (if a win32 process) would lose quotedness.
 */
int CmdParamToArgv(char *s, char ***avp, int dequote)
{
    char tmp[MaxPath], dir[MaxPath];
    char *t=salloc(s), *t2=t;
    int rv=0, i=0;
    FILE *f=NULL;

    *avp = malloc(2 * sizeof(char *));
    (*avp)[rv] = NULL;


    while (*t2) {
        while (*t2 && isspace((unsigned char)*t2)) t2++;
        switch (*t2) {
            case '\0': break;
            case '"': {
                char *t3, c = '\0';
                if (dequote) t3 = ++t2;			/* skip " */
                else t3 = t2++;

                while (*t2 && (*t2 != '"')) t2++;
                if (*t2 && !dequote) t2++;
                if (c = *t2) {
                    *t2++ = '\0';
                }
                *avp = realloc(*avp, (rv + 2) * sizeof (char *));
                (*avp)[rv++] = salloc(t3);
                (*avp)[rv] = NULL;
                if(!dequote && c) *--t2 = c;

                break;
	    }
            default: {
                char *t3 = t2;
                while (*t2 && !isspace((unsigned char)*t2)) t2++;
                if (*t2)
                    *t2++ = '\0';
                strcpy(tmp, t3);
		*avp = realloc(*avp, (rv + 2) * sizeof (char *));
		(*avp)[rv++] = salloc(t3);
		(*avp)[rv] = NULL;
                break;
	    }
        }
    }
    free(t);
    return rv;
}

char *lognam;
char tmplognam[128];

void MSStartup(HINSTANCE hInstance, HINSTANCE hPrevInstance)
{
    WNDCLASS wc;
    if (!hPrevInstance) {
        wc.style = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc = WndProc;
        wc.cbClsExtra = 0;
        wc.cbWndExtra = 0;
        wc.hInstance  = hInstance;
        wc.hIcon      = NULL;
        wc.hCursor    = NULL;
        wc.hbrBackground = GetStockObject(WHITE_BRUSH);
        wc.lpszMenuName = NULL;
        wc.lpszClassName = "oix";
        RegisterClass(&wc);
    }
}

int iconx(int argc, char **argv);

jmp_buf mark_sj;

int_PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPSTR lpszCmdLine, int nCmdShow)
{
    int argc;
    char **argv;

    mswinInstance = hInstance;
    ncmdShow = nCmdShow;

    argc = CmdParamToArgv(GetCommandLine(), &argv, 1);
    MSStartup(hInstance, hPrevInstance);
    if (setjmp(mark_sj) == 0)
        iconx(argc,argv);
    while (--argc>=0)
        free(argv[argc]);
    free(argv);
    wfreersc();
#ifdef NTGCC
    _exit(0);
#endif					/* NTGCC */
    return 0;
}
#define main iconx
#endif					/* MSWindows */

int main(int argc, char **argv)
{
    int i;
    struct fileparts *fp;
    struct b_proc *main_bp;
    struct p_frame *frame;

#if MSWIN32
    WSADATA cData;
    WSAStartup(MAKEWORD(2, 0), &cData);
#endif

    fp = fparse(argv[0]);

    /*
     * if argv[0] is not a reference to our interpreter, take it as the
     * name of the icode file, and back up for it.
     */
    if (!smatch(fp->name, "oix")) {
        argv--;
        argc++;
    }

    if (argc < 2) 
        startuperr("no icode file specified");

    /*
     * Call icon_init with the name of the icode file to execute.	[[I?]]
     */
    icon_init(argv[1]);

    /*
     * Check whether resolve() found the main procedure.  If not, exit.
     */
    if (!main_proc)
        fatalerr(117, NULL);

    main_bp = (struct b_proc *)BlkLoc(*main_proc);

    MemProtect(frame = alc_p_frame((struct b_proc *)&Bmain_wrapper, 0));
    frame->locals->args[0] = *main_proc;
    /*
     * Only create an args list if main has a parameter; otherwise args[1]
     * is just left as &null.
     */
    if (main_bp->nparam) {
        tended struct descrip args;
        create_list(argc - 2, &args);
        for (i = 2; i < argc; i++) {
            struct descrip t;
            CMakeStr(argv[i], &t);
            list_put(&args, &t);
        }
        frame->locals->args[1] = args;
    }
    k_current->sp = (struct frame *)frame;
    k_current->curr_pf = frame;
    k_current->start_label = frame->ipc = frame->proc->icode;
    k_current->failure_label = 0;
    set_up = 1;			/* post fact that iconx is initialized */
    interp();
    c_exit(EXIT_SUCCESS);

    return 0;
}





/*
 * The rest of the functions here are just debugging utilities.
 */



int valid_addr(void *p) 
{
#ifdef HAVE__ETEXT
  extern char _etext;
  return (p != NULL) && ((char*) p > &_etext);
#else
  return 1;
#endif
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
    fflush(f);
}

void print_vword(FILE *f, dptr d) {
    if (Qual(*d)) {
        fprintf(f, "%p -> ", StrLoc(*d));
        outimage(f, d, 1);
    } else if (is:struct_var(*d)) {
        /* D_StructVar (with an offset) */
        fprintf(f, "%p+%lu -> ", BlkLoc(*d), (unsigned long)(WordSize*Offset(*d)));
        print_desc(f, OffsetVarLoc(*d));
    } else {
        switch (d->dword) {
            case D_NamedVar : {
                /* D_NamedVar (pointer to another descriptor) */
                fprintf(f, "%p -> ", VarLoc(*d));
                print_desc(f, VarLoc(*d));
                break;
            }
            case D_Tvsubs : {
                struct b_tvsubs *p = (struct b_tvsubs *)BlkLoc(*d);
                fprintf(f, "%p -> sub=%ld+:%ld ssvar=", p, (long)p->sspos, (long)p->sslen);
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
            case D_Kywdany : {
                fprintf(f, "%p -> ", VarLoc(*d));
                print_desc(f, VarLoc(*d));
                break;
            }

            case D_TendPtr : {
                fprintf(f, "%p", BlkLoc(*d));
                break;
            }

            case D_Null : {
                fputs("0", f); 
                break;
            }

            case D_Integer : {
                fprintf(f, "%ld", (long)d->vword.integer); 
                break;
            }

            case D_Lelem :
            case D_Selem :
            case D_Telem :
            case D_Slots :
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
        fprintf(f, "%ld", (long)d->dword);
    } else if (is:struct_var(*d)) {
        /* D_StructVar (with an offset) */
        fprintf(f, "D_StructVar off:%lu", (unsigned long)Offset(*d));
    } else {
        switch (d->dword) {
            case D_TendPtr : fputs("D_TendPtr", f); break;
            case D_NamedVar : fputs("D_NamedVar", f); break;
            case D_Tvsubs : fputs("D_Tvsubs", f); break;
            case D_Tvtbl : fputs("D_Tvtbl", f); break;
            case D_Kywdint : fputs("D_Kywdint", f); break;
            case D_Kywdpos : fputs("D_Kywdpos", f); break;
            case D_Kywdsubj : fputs("D_Kywdsubj", f); break;
            case D_Kywdstr : fputs("D_Kywdstr", f); break;
            case D_Kywdany : fputs("D_Kywdany", f); break;
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

void showcurrstack()
{
    if (!k_current) {
        printf("curpstate=%p k_current is 0\n",curpstate);
        return;
    }    
    printf("k_current= %p k_current->sp=%p k_current->curr_pf=%p\n",
           k_current, k_current->sp, k_current->curr_pf);
    showstack(k_current);
}

void showstack(struct b_coexpr *c)
{
    struct frame *f;
    f = c->sp;
    while (f) {
        struct descrip tmp;
        int i;
        if (f == c->sp)
            printf("SP-> ");
        if (f == (struct frame *)c->curr_pf)
            printf("PF-> ");
        printf("Frame %p type=%c, size=%d\n", f, 
               f->type == C_FRAME_TYPE ? 'C':'P', 
               f->size);
        printf("\tvalue="); print_desc(stdout, &f->value); printf("\n");
        printf("\tfailure_label=%p\n", f->failure_label);
        tmp.dword = D_Proc;
        BlkLoc(tmp) = (union block *)f->proc;
        printf("\tproc="); print_vword(stdout, &tmp); printf("\n");
        printf("\tparent_sp=%p\n", f->parent_sp);
        printf("\texhausted=%d\n", f->exhausted);
        switch (f->type) {
            case C_FRAME_TYPE: {
                struct c_frame *cf = (struct c_frame *)f;
                printf("\tpc=%p\n", cf->pc);
                printf("\tnargs=%d\n", cf->nargs);
                for (i = 0; i < cf->nargs; ++i) {
                    printf("\targs[%d]=", i); print_desc(stdout, &cf->args[i]); printf("\n");
                }
                for (i = 0; i < f->proc->ntend; ++i) {
                    printf("\ttend[%d]=", i); print_desc(stdout, &cf->tend[i]); printf("\n");
                }
                break;
            }
            case P_FRAME_TYPE: {
                struct p_frame *pf = (struct p_frame *)f;
                printf("\tipc=%p (offset %ld)\n", pf->ipc, (long)DiffPtrsBytes(pf->ipc, pf->code_start));
                printf("\tcode_start=%p\n", pf->code_start);
                printf("\tcaller=%p\n", pf->caller);
                for (i = 0; i < f->proc->nclo; ++i) {
                    printf("\tclo[%d]=%p\n", i, pf->clo[i]);
                }
                for (i = 0; i < f->proc->ntmp; ++i) {
                    printf("\ttmp[%d]=", i); print_desc(stdout, &pf->tmp[i]); printf("\n");
                }
                for (i = 0; i < f->proc->nlab; ++i) {
                    printf("\tlab[%d]=%p\n", i, pf->lab[i]);
                }
                for (i = 0; i < f->proc->nmark; ++i) {
                    printf("\tmark[%d]=%p\n", i, pf->mark[i]);
                }
                printf("\tlocals=%p, size=%d\n", pf->locals, pf->locals->size);
                for (i = 0; i < f->proc->ndynam; ++i) {
                    printf("\t   locals.dynamic[%d]=", i); print_desc(stdout, &pf->locals->dynamic[i]); printf("\n");
                }
                for (i = 0; i < abs(f->proc->nparam); ++i) {
                    printf("\t   locals.args[%d]=", i); print_desc(stdout, &pf->locals->args[i]); printf("\n");
                }
                printf("\t   locals.low - high=%p-%p\n", pf->locals->low, pf->locals->high);
                printf("\t   locals.refcnt=%d\n", pf->locals->refcnt);
                printf("\t   locals.seen=%d\n", pf->locals->seen);
                break;
            }
            default:
                syserr("Unknown frame type");
        }
        f = f->parent_sp;

    }
    printf("------bottom of stack--------\n");
    fflush(stdout);
}
