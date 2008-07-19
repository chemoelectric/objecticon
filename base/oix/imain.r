/*
 * File: imain.r
 * Interpreter main program, argument handling, and such.
 * Contents: main, icon_call, icon_setup, resolve, xmfree
 */

#include "../h/version.h"
#include "../h/header.h"
#include "../h/opdefs.h"
#include "../h/modflags.h"


/*
 * Prototypes.
 */
static	void	env_err	(char *msg,char *name,char *val);
void	icon_setup	(int argc, char **argv, int *ip);

#ifdef MacGraph
void MacMain (int argc, char **argv);
void ToolBoxInit (void);
void MenuBarInit (void);
void MouseInfoInit (void);
int GetArgs (char **argv);
#endif					/* MacGraph */

/*
 * The following code is operating-system dependent [@imain.01].  Declarations
 *   that are system-dependent.
 */

#if PORT
/* probably needs something more */
Deliberate Syntax Error
#endif					/* PORT */

#if MACINTOSH
#if MPW
int NoOptions = 0;
#endif					/* MPW */
#endif					/* MACINTOSH */


/* #define DEBUG_LOAD 1 */

/*
 * End of operating-system specific code.
 */

extern int set_up;

/*
 * A number of important variables follow.
 */


extern int_setup;

function{0} deferred_method_stub()
   body {
      runerr(612);       
   }
end

#define NativeDef(f) extern struct b_iproc B##f##;
#include "../h/nativedefs.h"
#undef NativeDef

static struct b_iproc *native_methods[] = {
#define NativeDef(f) &B##f##,
#include "../h/nativedefs.h"
#undef NativeDef
};

static int lookup_field(char *s, dptr field_names, int ftab_rows);

/*
 * Initial icode sequence. This is used to invoke the main procedure with one
 *  argument.  If main returns, the Op_Quit is executed.
 */
word istart[4];
int mterm = Op_Quit;


FILE *finredir, *fouredir, *ferredir;

#if MSWindows

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
        while (*t2 && isspace(*t2)) t2++;
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
                FINDDATA_T fd;
                char *t3 = t2;
                while (*t2 && !isspace(*t2)) t2++;
                if (*t2)
                    *t2++ = '\0';
                strcpy(tmp, t3);
                if (!FINDFIRST(tmp, &fd)) {
                    *avp = realloc(*avp, (rv + 2) * sizeof (char *));
                    (*avp)[rv++] = salloc(t3);
                    (*avp)[rv] = NULL;
                }
                else {
                    int end;
                    strcpy(dir, t3);
                    do {
                        end = strlen(dir)-1;
                        while (end >= 0 && dir[end] != '\\' && dir[end] != '/' &&
                               dir[end] != ':') {
                            dir[end] = '\0';
                            end--;
                        }
                        strcat(dir, FILENAME(&fd));
                        *avp = realloc(*avp, (rv + 2) * sizeof (char *));
                        (*avp)[rv++] = salloc(dir);
                        (*avp)[rv] = NULL;
                    } while (FINDNEXT(&fd));
                    FINDCLOSE(&fd);
                }
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
    xmfree();
#ifdef NTGCC
    _exit(0);
#endif					/* NTGCC */
    return 0;
}
#define main iconx
#define INTMAIN 1
#else
#if WildCards
void ExpandArgv(int *argcp, char ***avp)
{
    int argc = *argcp;
    char **argv = *avp;
    char **newargv;
    FINDDATA_T fd;
    int j,newargc=0;
    for(j=0; j < argc; j++) {
        newargc++;
        if (strchr(argv[j], '*') || strchr(argv[j], '?')) {
            if (FINDFIRST(argv[j], &fd)) {
                while (FINDNEXT(&fd)) newargc++;
                FINDCLOSE(&fd);
            }
        }
    }
    if (newargc == argc) return;

    newargv = malloc((newargc+1) * sizeof (char *));
    newargc = 0;
    for(j=0; j < argc; j++) {
        if (strchr(argv[j], '*') || strchr(argv[j], '?')) {
            if (FINDFIRST(argv[j], &fd)) {
                char dir[MaxPath];
                int end;
                strcpy(dir, argv[j]);
                do {
                    end = strlen(dir)-1;
                    while(end >= 0 && !strchr("\\/:", dir[end])) {
                        dir[end] = '\0';
                        end--;
                    }
                    strcat(dir, FILENAME(&fd));
                    newargv[newargc++] = strdup(dir);
                    newargv[newargc] = NULL;
                } while (FINDNEXT(&fd));
                FINDCLOSE(&fd);
            }
            else {
                newargv[newargc++] = strdup(argv[j]);
            }
        }
        else {
            newargv[newargc++] = strdup(argv[j]);
        }
    }
    *avp = newargv;
    *argcp = newargc;
}
#endif					/* WildCards */
#endif					/* MSWindows */

int main(int argc, char **argv)
{
    int i, slen;

#if WildCards
#ifndef MSWindows
    ExpandArgv(&argc, &argv);
#endif
#endif					/* WildCards */

    /*
     * Look for MultiThread programming environment in which to execute
     * this program, specified by MTENV environment variable.
     */
    {
        char *p = NULL;
        char **new_argv = NULL;
        int i=0, j = 1, k = 1;
        if ((p = getenv("MTENV")) != NULL) {
            for(i=0;p[i];i++)
                if (p[i] == ' ')
                    j++;
            new_argv = (char **)malloc((argc + j) * sizeof(char *));
            new_argv[0] = argv[0];
            for (i=0; p[i]; ) {
                new_argv[k++] = p+i;
                while (p[i] && (p[i] != ' '))
                    i++;
                if (p[i] == ' ')
                    p[i++] = '\0';
            }
            for(i=1;i<argc;i++)
                new_argv[k++] = argv[i];
            argc += j;
            argv = new_argv;
        }
    }

    ipc.opnd = NULL;

    /*
     * Setup Icon interface.  It's done this way to avoid duplication
     *  of code, since the same thing has to be done if calling Icon
     *  is enabled.
     */
    icon_setup(argc, argv, &i);

    if (i < 0) {
        argc++;
        argv--;
        i++;
    }

    while (i--) {			/* skip option arguments */
        argc--;
        argv++;
    }

    if (argc <= 1) {
        error("no icode file specified");
    }

    /*
     * Call icon_init with the name of the icode file to execute.	[[I?]]
     */
    icon_init(argv[1], &argc, argv);

    /*
     *  Point sp at word after b_coexpr block for &main, point ipc at initial
     *	icode segment, and clear the gfp.
     */

    stackend = stack + mstksize/WordSize;
    sp = stack + Wsizeof(struct b_coexpr);

    ipc.opnd = istart;
    *ipc.op++ = Op_Noop;  /* aligns Invoke's operand */	/*	[[I?]] */
    *ipc.op++ = Op_Invoke;				/*	[[I?]] */
    *ipc.opnd++ = 1;
    *ipc.op = Op_Quit;
    ipc.opnd = istart;

    gfp = 0;

    /*
     * Set up expression frame marker to contain execution of the
     *  main procedure.  If failure occurs in this context, control
     *  is transferred to mterm, the address of an Op_Quit.
     */
    efp = (struct ef_marker *)(sp);
    efp->ef_failure.op = &mterm;
    efp->ef_gfp = 0;
    efp->ef_efp = 0;
    efp->ef_ilevel = 1;
    sp += Wsizeof(*efp) - 1;

    pfp = 0;
    ilevel = 0;

/*
 * We have already loaded the
 * icode and initialized things, so it's time to just push main(),
 * build an Icon list for the rest of the arguments, and called
 * interp on a "invoke 1" bytecode.
 */

    /*
     * Check whether resolve() found the main procedure.  If not, this
     * is noted as run-time error 117.  Otherwise, this value is
     * pushed on the stack.
     */
    if (!main_proc)
        fatalerr(117, NULL);
    PushDesc(*main_proc);
    PushNull;
    glbl_argp = (dptr)(sp - 1);

    /*
     * If main() has a parameter, it is to be invoked with one argument, a list
     *  of the command line arguments.  The command line arguments are pushed
     *  on the stack as a series of descriptors and Ollist is called to create
     *  the list.  The null descriptor first pushed serves as Arg0 for
     *  Ollist and receives the result of the computation.
     */
    if (((struct b_proc *)BlkLoc(*main_proc))->nparam > 0) {
        for (i = 2; i < argc; i++) {
            char *tmp;
            slen = strlen(argv[i]);
            PushVal(slen);
            Protect(tmp=alcstr(argv[i],(word)slen), fatalerr(0,NULL));
            PushAVal(tmp);
        }

        Ollist(argc - 2, glbl_argp);
    }


    sp = (word *)glbl_argp + 1;

    glbl_argp = 0;

    set_up = 1;			/* post fact that iconx is initialized */

    /*
     * Start things rolling by calling interp.  This call to interp
     *  returns only if an Op_Quit is executed.	If this happens,
     *  c_exit() is called to wrap things up.
     */
    interp(0,(dptr)NULL); 

    c_exit(EXIT_SUCCESS);
#ifdef INTMAIN
    return 0;
#endif
}

/*
 * icon_setup - handle interpreter command line options.
 */
void icon_setup(int argc, char **argv, int *ip)
{
    struct fileparts *fp;
    *ip = 0;			/* number of arguments processed */

    fp = fparse(argv[0]);

    /*
     * if argv[0] is not a reference to our interpreter, take it as the
     * name of the icode file, and back up for it.
     */
    if (!smatch(fp->name, "oix")) {
        argv--;
        argc++;
        (*ip)--;
    }

    /*
     * Handle command line options.
     */
    while ( argv[1] != 0 && *argv[1] == '-' ) {
        switch ( *(argv[1]+1) ) {

            /*
             * Set stderr to new file if -e option is given.
             */
            case 'e': {
                char *p;
                if ( *(argv[1]+2) != '\0' )
                    p = argv[1]+2;
                else {
                    argv++;
                    argc--;
                    (*ip)++;
                    p = argv[1];
                    if ( !p )
                        error("no file name given for redirection of &errout");
                }
                if (!redirerr(p))
                    syserr("Unable to redirect &errout\n");
                break;
            }
        }
        argc--;
        (*ip)++;
        argv++;
    }
}

/*
 * resolve - perform various fix-ups on the data read from the icode
 *  file.
 */
void resolve(pstate)
    struct progstate *pstate;

{
    word i, j, n_classes, n_fields;
    char *class_start;
    struct b_proc *pp;
    struct b_class *class_blocks, *cb;
    struct class_field *cf;
    dptr dp;
    extern Omkrec();
    register struct progstate *savedstate = curpstate;
    if (pstate) curpstate = pstate;

    /*
     * For each class field info block, relocate the pointer to the
     * defining class and the descriptor.
     */
    for (cf = classfields; cf < eclassfields; cf++) {
        StrLoc(cf->name) = strcons + (uword)StrLoc(cf->name);
        cf->defining_class = (struct b_class*)(code + (int)cf->defining_class);
        if (cf->field_descriptor) {
            cf->field_descriptor = (dptr)(code + (int)cf->field_descriptor);
            /* Follow the same logic as lcode.c */
            if (cf->flags & M_Defer) {
                if (cf->field_descriptor->dword == D_Proc) {
                    /* Resolved to native method, set pointer */
                    pp = (struct b_proc *)native_methods[IntVal(*cf->field_descriptor)];
                    /* Pointer back to the corresponding field */
                    pp->field = cf;
                    BlkLoc(*cf->field_descriptor) = (union block *)pp;
                } else {
                    /* Unresolved, point to stub */
                    cf->field_descriptor->dword = D_Proc;
                    BlkLoc(*cf->field_descriptor) = (union block *)&Bdeferred_method_stub;
                }
            } else if (cf->flags & M_Method) {
                /*
                 * Method in the icode file, relocate the entry point
                 * and the names of the parameters, locals, and static
                 * variables.
                 */
                pp = (struct b_proc *)(code + IntVal(*cf->field_descriptor));
                BlkLoc(*cf->field_descriptor) = (union block *)pp;
                /* Pointer back to the corresponding field */
                pp->field = cf;
                /* Relocate the name */
                StrLoc(pp->pname) = strcons + (uword)StrLoc(pp->pname);
                /* The entry point */
                pp->entryp.icode = code + pp->entryp.ioff;
                /* The variables */
                for (i = 0; i < abs((int)pp->nparam) + pp->ndynam + pp->nstatic; i++)
                    StrLoc(pp->lnames[i]) = strcons + (uword)StrLoc(pp->lnames[i]);
                pp->program = pstate ? pstate:&rootpstate;
            }
        }
#ifdef DEBUG_LOAD
        printf("%8x\t\tClass field struct\n", cf);
        printf("\t%08o\t  Flags\n", cf->flags);
        printf("\t%s\t\t  Fname\n", StrLoc(cf->name));
        printf("\t%8x\t  Defining class\n", cf->defining_class);
        printf("\t%8x\t  Descriptor\n", cf->field_descriptor);
#endif
    }

    n_classes = *classes;
    class_start = (char*)(classes + 1);  /* One word after classes - skip the n_classes field */
    for (i = 0; i < n_classes; ++i) {
        cb = (struct b_class *)class_start;
        StrLoc(cb->name) = strcons + (uword)StrLoc(cb->name);
        cb->program = pstate ? pstate:&rootpstate;
        n_fields = cb->n_class_fields + cb->n_instance_fields;
        cb->supers = (struct b_class **)(code + (int)cb->supers);
        for (j = 0; j < cb->n_supers; ++j) 
            cb->supers[j] = (struct b_class*)(code + (int)cb->supers[j]);
        cb->implemented_classes = (struct b_class **)(code + (int)cb->implemented_classes);
        for (j = 0; j < cb->n_implemented_classes; ++j) 
            cb->implemented_classes[j] = (struct b_class*)(code + (int)cb->implemented_classes[j]);
        cb->fields = (struct class_field **)(code + (int)cb->fields);
        for (j = 0; j < n_fields; ++j) 
            cb->fields[j] = (struct class_field*)(code + (int)cb->fields[j]);
        cb->sorted_fields = (short *)(code + (int)cb->sorted_fields);
        class_start += cb->blksize;
#ifdef DEBUG_LOAD
        printf("%8x\t\t\tClass\n", cb);
        printf("\t%d\t\t\t  Title\n", cb->title);
        printf("\t%d\t\t\t  Fieldtable col\n", cb->fieldtable_col);
        printf("\t%d\t\t\t  N supers\n", cb->n_supers);
        printf("\t%d\t\t\t  N implemented classes\n", cb->n_implemented_classes);
        printf("\t%d\t\t\t  N implemented instance class fields\n", cb->n_instance_fields);
        printf("\t%d\t\t\t  N implemented class fields\n", cb->n_class_fields);
        for (j = 0; j < cb->n_supers; ++j) 
            printf("\t%8x\t\t\t  Superclass %d\n",cb->supers[j], j);
        for (j = 0; j < cb->n_implemented_classes; ++j) 
            printf("\t%8x\t\t\t  Implemented class %d\n",cb->implemented_classes[j], j);
        for (j = 0; j < n_fields; ++j) 
            printf("\t%8x\t\t\t  Field info %d\n",cb->fields[j], j);
        for (j = 0; j < n_fields; ++j) 
            printf("\t%d\t\t\t  Sorted field array\n",cb->sorted_fields[j]);
#endif
    }

    /*
     * Relocate the names of the global variables.
     */
    for (dp = gnames; dp < egnames; dp++)
        StrLoc(*dp) = strcons + (uword)StrLoc(*dp);

    /*
     * Scan the global variable array for procedures and fill in appropriate
     *  addresses.   Also note the main procedure if found.
     */
    main_proc = 0;
    for (j = 0; j < n_globals; j++) {
        switch (globals[j].dword) {
            case D_Class: {
                /* We just need to relocate the vword */
                i = IntVal(globals[j]);
                BlkLoc(globals[j]) = (union block *)((struct b_class *)(code + i));
                break;
            }

            case D_Proc: {
                /*
                 * The second word of the descriptor for procedure variables tells
                 *  where the procedure is.  Negative values are used for built-in
                 *  procedures and positive values are used for Icon procedures.
                 */
                i = IntVal(globals[j]);

                if (i < 0) {
                    /*
                     * globals[j] points to a built-in function; call (bi_)strprc
                     *  to look it up by name in the interpreter's table of built-in
                     *  functions.
                     */
                    if((BlkLoc(globals[j])= (union block *)bi_strprc(gnames+j,0)) == NULL)
                        globals[j] = nulldesc;		/* undefined, set to &null */
                }
                else {

                    /*
                     * globals[j] points to an Icon procedure or a record; i is an offset
                     *  to location of the procedure block in the code section.  Point
                     *  pp at the block and replace BlkLoc(globals[j]).
                     */
                    pp = (struct b_proc *)(code + i);
                    BlkLoc(globals[j]) = (union block *)pp;

                    /*
                     * Relocate the address of the name of the procedure.
                     */
                    StrLoc(pp->pname) = strcons + (uword)StrLoc(pp->pname);

                    if (pp->ndynam == -2) {
                        /*
                         * This procedure is a record constructor.	Make its entry point
                         *	be the entry point of Omkrec().
                         */
                        pp->entryp.ccode = Omkrec;

                        /*
                         * Initialize field names
                         */
                        for (i = 0; i < pp->nfields; i++)
                            StrLoc(pp->lnames[i]) = strcons + (uword)StrLoc(pp->lnames[i]);

                    }
                    else {
                        /*
                         * This is an Icon procedure.  Relocate the entry point and
                         *	the names of the parameters, locals, and static variables.
                         */
                        pp->entryp.icode = code + pp->entryp.ioff;
                        for (i = 0; i < abs((int)pp->nparam)+pp->ndynam+pp->nstatic; i++)
                            StrLoc(pp->lnames[i]) = strcons + (uword)StrLoc(pp->lnames[i]);

                        /*
                         * Is it the main procedure?
                         */
                        if (StrLen(pp->pname) == 4 &&
                            !strncmp(StrLoc(pp->pname), "main", 4))
                            main_proc = &globals[j];
                    }
                    pp->program = pstate ? pstate:&rootpstate;
                }
                break;
            }
        }
    }

    /*
     * Relocate the names of the fields.
     */

    for (dp = fnames; dp < efnames; dp++)
        StrLoc(*dp) = strcons + (uword)StrLoc(*dp);

    curpstate = savedstate;
}

/*
 * Lookup one of the standard fields in the given class.  Returns the
 * corresponding class_field object, or null if not found.
 */
struct class_field *lookup_standard_field(int standard_field_num, struct b_class *class)
{
    struct progstate *p = class->program;
    word fnum = p->StandardFields[standard_field_num];
    int i;
    if (fnum == -1)
        return 0;
    i = p->Ftabp[fnum * (*(p->Records) + *(p->Classes)) + class->fieldtable_col];
    if (i == -1)
        return 0;
    return class->fields[i];
}

static int lookup_global_compare(const void *p1, const void *p2)
{
    return lexcmp((dptr)p1, (dptr)p2);
}

dptr lookup_global(dptr name, struct progstate *prog)
{
    dptr p = (dptr)bsearch(name, prog->Gnames, prog->NGlobals, 
                           sizeof(struct descrip), lookup_global_compare);
    if (!p)
        return 0;

    /* Convert from pointer into names array to pointer into descriptor array */
    return p - (prog->Gnames - prog->Globals);
}



/*
 * Free malloc-ed memory; the main regions then co-expressions.  Note:
 *  this is only correct if all allocation is done by routines that are
 *  compatible with free() -- which may not be the case for all memory.
 */

void xmfree()
{
    register struct b_coexpr **ep, *xep;
    register struct astkblk *abp, *xabp;

    if (mainhead == NULL) return;	/* already xmfreed */
    free((pointer)mainhead->es_actstk);	/* activation block for &main */
    mainhead->es_actstk = NULL;
    mainhead = NULL;

    free((pointer)code);			/* icode */
    code = NULL;
    free((pointer)stack);		/* interpreter stack */
    stack = NULL;
    /*
     * more is needed to free chains of heaps, also a multithread version
     * of this function may be needed someday.
     */
    if (strbase)
        free((pointer)strbase);		/* allocated string region */
    strbase = NULL;
    if (blkbase)
        free((pointer)blkbase);		/* allocated block region */
    blkbase = NULL;
    if (quallist)
        free((pointer)quallist);		/* qualifier list */
    quallist = NULL;

    /*
     * The co-expression blocks are linked together through their
     *  nextstk fields, with stklist pointing to the head of the list.
     *  The list is traversed and each stack is freeing.
     */
    ep = &stklist;
    while (*ep != NULL) {
        xep = *ep;
        *ep = (*ep)->nextstk;
        /*
         * Free the astkblks.  There should always be one and it seems that
         *  it's not possible to have more than one, but nonetheless, the
         *  code provides for more than one.
         */
        for (abp = xep->es_actstk; abp; ) {
            xabp = abp;
            abp = abp->astk_nxt;
            free((pointer)xabp);
        }

        free((pointer)xep);
        stklist = NULL;
    }

}


#ifdef MacGraph
void MouseInfoInit (void)
{
    gMouseInfo.wasDown = false;
}

void ToolBoxInit (void)
{
    InitGraf (&qd.thePort);
    InitFonts ();
    InitWindows ();
    InitMenus ();
    TEInit ();
    InitDialogs (nil);
    InitCursor ();
}

void MenuBarInit (void)
{
    Handle         menuBar;
    MenuHandle     menu;
    OSErr          myErr;
    long           feature;

    menuBar = GetNewMBar (kMenuBar);
    SetMenuBar (menuBar);

    menu = GetMHandle (kAppleMenu);
    AddResMenu (menu, 'DRVR');

    DrawMenuBar ();
}

void EventLoop ( void )
{
    EventRecord event, *eventPtr;
    char theChar;

    gDone = false;
    while ( gDone == false )
    {
        if ( WaitNextEvent ( everyEvent, &event, kSleep, nil ) )
            DoEvent ( &event );
    }
}

void main ()
{
    atexit (EventLoop);
    ToolBoxInit ();
    MenuBarInit ();
    MouseInfoInit ();
    cmlArgs = "";

    EventLoop ();
}
#endif					/* MacGraph */
