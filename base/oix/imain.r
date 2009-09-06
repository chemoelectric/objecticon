/*
 * File: imain.r
 * Interpreter main program, argument handling, and such.
 * Contents: main, icon_call, icon_setup, resolve
 */

#include "../h/version.h"
#include "../h/header.h"
#include "../h/opdefs.h"


/* #define DEBUG_LOAD 1  */

/*
 * End of operating-system specific code.
 */

/*
 * A number of important variables follow.
 */

function{0} deferred_method_stub(a[n])
   body {
      runerr(612);       
   }
end


/*
 * Initial icode sequence. This is used to invoke the main procedure with one
 *  argument.  If main returns, the Op_Quit is executed.
 */
word istart[4];
word mterm = Op_Quit;

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
    int i, want_arg;
    struct fileparts *fp;

#if MSWIN32
    WSADATA cData;
    WSAStartup(MAKEWORD(2, 0), &cData);
#endif

    ipc = NULL;

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
     *  Point sp at word after b_coexpr block for &main, point ipc at initial
     *	icode segment, and clear the gfp.
     */

    stackend = stack + mstksize/WordSize;
    sp = stack + Wsizeof(struct b_coexpr);

    gfp = 0;

    /*
     * Set up expression frame marker to contain execution of the
     *  main procedure.  If failure occurs in this context, control
     *  is transferred to mterm, the address of an Op_Quit.
     */
    efp = (struct ef_marker *)(sp);
    efp->ef_failure = &mterm;
    efp->ef_gfp = 0;
    efp->ef_efp = 0;
    efp->ef_ilevel = 1;
    sp += Wsizeof(*efp) - 1;

    pfp = 0;
    ilevel = 0;

    /*
     * Check whether resolve() found the main procedure.  If not, exit.
     */
    if (!main_proc)
        fatalerr(117, NULL);

    /*
     * We have already loaded the icode and initialized things, so
     * it's time to just push main(), and the arguments in a list if
     * they're wanted, and call interp on a invoke bytecode.
     */
    PushDesc(*main_proc);

    /*
     * We avoid passing an arg to main if possible, so that we don't create
     * a list unnecessarily.
     */
    if (((struct b_proc *)BlkLoc(*main_proc))->nparam) {
        tended struct descrip args;
        create_list(argc - 2, &args);
        for (i = 2; i < argc; i++) {
            struct descrip t;
            CMakeStr(argv[i], &t);
            list_put(&args, &t);
        }
        PushDesc(args);
        want_arg = 1;
    } else
        want_arg = 0;

    argp = 0;

    set_up = 1;			/* post fact that iconx is initialized */

    ipc = istart;
    *ipc++ = Op_Invoke;				/*	[[I?]] */
    *ipc++ = want_arg;  /* Number of args to pass to main proc (1 or 0) */
    *ipc = Op_Quit;
    ipc = istart;

    /*
     * Start things rolling by calling interp.  This call to interp
     *  returns only if an Op_Quit is executed.	If this happens,
     *  c_exit() is called to wrap things up.
     */
    interp(0,(dptr)NULL); 

    c_exit(EXIT_SUCCESS);

    return 0;
}


dptr lookup_global(dptr name, struct progstate *prog)
{
    dptr p = (dptr)bsearch(name, prog->Gnames, prog->NGlobals, 
                           sizeof(struct descrip), 
                           (BSearchFncCast)lexcmp);
    if (!p)
        return 0;

    /* Convert from pointer into names array to pointer into descriptor array */
    return prog->Globals + (p - prog->Gnames);
}

struct loc *lookup_global_loc(dptr name, struct progstate *prog)
{
    dptr p;

    /* Check if the table was compiled into the icode */
    if (prog->Glocs == prog->Eglocs)
        return 0;

    p = (dptr)bsearch(name, prog->Gnames, prog->NGlobals, 
                      sizeof(struct descrip), 
                      (BSearchFncCast)lexcmp);
    if (!p)
        return 0;

    /* Convert from pointer into names array to pointer into location array */
    return prog->Glocs + (p - prog->Gnames);
}



