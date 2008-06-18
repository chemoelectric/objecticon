/*
 * tmain.c - main program for translator and linker.
 */

#include "icont.h"
#include "tmain.h"
#include "trans.h"
#include "ucode.h"
#include "lcompres.h"
#include "link.h"
#include "tmem.h"
#include "tlex.h"
#include "util.h"

int warnings = 0;           /* count of warnings */
int errors = 0;		    /* translator and linker errors */

int silent	=0;	/* -s: suppress info messages? */
int m4pre	=0;	/* -m: use m4 preprocessor? [UNIX] */
int uwarn	=0;	/* -u: warn about undefined ids? */
int trace	=0;	/* -t: initial &trace value */
int pponly	=0;	/* -E: preprocess only */
int strinv	=0;	/* -f s: allow full string invocation */
int verbose	=1;	/* -v n: verbosity of commentary */
int neweronly	=0;	/* -n: only translate .icn if newer than .u */
int Dflag       =0;     /* -L: link debug */
int Zflag	=1;	/* -Z disables icode-gz compression */

/*
 * Some convenient interned strings.
 */
char *main_string;
char *default_string;
char *self_string;
char *new_string;
char *init_string;
char *all_string;
char *package_marker_string;

#if MSDOS
int makeExe	=1;	/* -X: create .exe instead of .icx */
long fileOffsetOfStuffThatGoesInICX = 0; /* remains 0 -f -X is not used */
#endif					/* MSDOS */

/*
 * Variables related to command processing.
 */
#if defined(MSWindows) && !defined(NTGCC)
char *progname	="wicont";	/* program name for diagnostics */
#else
char *progname	="icont";	/* program name for diagnostics */
#endif					/* MSWindows */

#if defined(MSWindows) && defined(MSVC)
int Gflag	=1;	/* -G: enable graphics (write wiconx)*/
#else					/* MSWindows && MSVC */
int Gflag	=0;	/* -G: enable graphics (write wiconx)*/
#endif					/* MSWindows && MSVC */

struct str_buf join_sbuf;

/*
 * Files and related globals.
 */
char *lpath;			/* search path for $include */
char *ipath;			/* search path for linking */
FILE *ucodefile	= 0;	        /* current ucode output file */
char *ofile = 0;         	/* name of linker output file */
char *iconxloc;			/* path to iconx */
long hdrsize;			/* size of iconx header */

#if MACINTOSH
   #if THINK_C
      #include "console.h"
      #include "config.h"
      #include "cpuconf.h"
      #include "macgraph.h"
      #include <AppleEvents.h>
      #include <GestaltEqu.h>
      /* #include <Values.h> */

      #define MAXLONG  (0x7fffffff)
      
      /* #define kSleep MAXLONG */
      #define kGestaltMask 1L

      /* Global */
      Boolean gDone;
      Boolean g_cOption;
   #endif    /* THINK_C */
#endif    /* MACINTOSH */

#if NT
   extern FILE *pathOpen(char *, char *);
#endif

#ifdef MSWindows
   #ifdef NTConsole
      #define int_PASCAL int PASCAL
      #define LRESULT_CALLBACK LRESULT CALLBACK
      #include <windows.h>
      #include "../h/filepat.h"
   #endif				/* NTConsole */
#endif					/* MSWindows */

/*
 * Prototypes.
 */

static	void	execute	(char *ofile,char *efile,char * *args);
static	void	usage (void);
char *libpath (char *prog, char *envname);

#if MACINTOSH
   #if THINK_C
      pascal void  MaxApplZone ( void );
      void         IncreaseStackSize ( Size extraBytes );
      
      void         ToolBoxInit ( void );
      void         EventInit ( void );
      void         EventLoop ( void );
      void         DoEvent ( EventRecord *eventPtr );
      pascal OSErr DoOpenDoc ( AppleEvent theAppleEvent,
                         AppleEvent reply,
                               long refCon );
      pascal OSErr DoQuitApp ( AppleEvent theAppleEvent,
                         AppleEvent reply,
                               long refCon );
      OSErr        GotRequiredParams ( AppleEvent *appleEventPtr );
      void      MacMain ( int argc, char **argv );

      void DoMouseDown (EventRecord *eventPtr);
      void HandleMenuChoice (long menuChoice);
      void HandleAppleChoice (short item);
      void HandleFileChoice (short item);
      void HandleOptionsChoice (short item);
      void MenuBarInit (void);
   #endif					/* THINK_C */
#endif					/* MACINTOSH */

/*
 * The following code is operating-system dependent [@tmain.01].  Include
 *  files and such.
 */

#if PORT
   Deliberate syntax error
#endif					/* PORT */

#if ARM || MVS || UNIX || VM || VMS
   /* nothing is needed */
#endif					/* ARM || ... */

#if MSDOS
   char pathToIconDOS[129];
#endif					/* MSDOS */

#if ATARI_ST
   char *patharg;
#endif					/* ATARI_ST */

#if MACINTOSH
   #if MPW
      #include <CursorCtl.h>
      void SortOptions();
   #endif				/* MPW */
#endif					/* MACINTOSH */

#if OS2
   #include <process.h>
#endif					/* OS2 */
/*
 * End of operating-system specific code.
 */

#if IntBits == 16
   #ifdef strlen
   #undef strlen			/* pre-defined in some contexts */
   #endif				/* strlen */
#endif					/* Intbits == 16 */

/*
 *  Define global variables.
 */

int bundleiconx = 0;

char patchpath[MaxPath+18] = "%PatchStringHere->";

struct file_param *trans_files = 0, *last_trans_file = 0, 
                  *link_files = 0, *last_link_file = 0,
                  *remove_files = 0, *last_remove_file = 0;

static void add_trans_file(char *s)
{
    struct file_param *p = New(struct file_param);
    p->name = intern_using(&join_sbuf, s);
    if (last_trans_file) {
        last_trans_file->next = p;
        last_trans_file = p;
    } else
        trans_files = last_trans_file = p;
}

static void add_link_file(char *s)
{
    struct file_param *p = New(struct file_param);
    p->name = intern_using(&join_sbuf, s);
    if (last_link_file) {
        last_link_file->next = p;
        last_link_file = p;
    } else
        link_files = last_link_file = p;
}

static void add_remove_file(char *s)
{
    struct file_param *p = New(struct file_param);
    p->name = intern_using(&join_sbuf, s);
    if (last_remove_file) {
        last_remove_file->next = p;
        last_remove_file = p;
    } else
        remove_files = last_remove_file = p;
}

/*
 * getopt() variables
 */
extern int optind;		/* index into parent argv vector */
extern int optopt;		/* character checked for validity */
extern char *optarg;		/* argument associated with option */


#ifndef NTConsole
#ifdef MSWindows
int icont(int argc, char **argv);
#define int_PASCAL int PASCAL
#define LRESULT_CALLBACK LRESULT CALLBACK
#undef lstrlen
#include <windows.h>
#define lstrlen longstrlen

int CmdParamToArgv(char *s, char ***avp)
   {
   char tmp[MaxPath], dir[MaxPath];
   char *t, *t2;
   int rv=0, i;
   FILE *f;
   t = intern_using(&join_sbuf, s);
   t2 = t;
   *avp = malloc(2 * sizeof(char *));
   (*avp)[rv] = NULL;

   while (*t2) {
      while (*t2 && isspace(*t2)) t2++;
      switch (*t2) {
	 case '\0': break;
	 case '"': {
	    char *t3 = ++t2;			/* skip " */
            while (*t2 && (*t2 != '"')) t2++;
            if (*t2)
	       *t2++ = '\0';
	    *avp = realloc(*avp, (rv + 2) * sizeof (char *));
	    (*avp)[rv++] = intern_using(&join_sbuf, t3);
            (*avp)[rv] = NULL;
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
	       (*avp)[rv++] = intern_using(&join_sbuf, t3);
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
	          (*avp)[rv++] = intern_using(&join_sbuf, dir);
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


LRESULT_CALLBACK WndProc	(HWND, UINT, WPARAM, LPARAM);
char *lognam;
char tmplognam[128];
extern FILE *flog;

void MSStartup(int argc, char **argv, HINSTANCE hInstance, HINSTANCE hPrevInstance)
   {
   WNDCLASS wc;
   char *tnam;

   /*
    * Select log file name.  Might make this a command-line option.
    * Default to "WICON.LOG".  The log file is used by Wi to report
    * translation errors and jump to the offending source code line.
    */
   if ((lognam = getenv("WICONLOG")) == NULL) {
      if (((lognam = getenv("TEMP")) != NULL) &&
	  (lognam = malloc(strlen(lognam) + 13)) != NULL) {
	 strcpy(lognam, getenv("TEMP"));
	 strcat(lognam, "\\");
	 strcat(lognam, "winicon.log");
         }
      else
	 lognam = "winicon.log";
      }
   if (flog = fopen(lognam, "r")) {
      fclose(flog);
      flog = NULL;
      remove(lognam);
      }
   lognam = strdup(lognam);
   flog = NULL;
   tnam = _tempnam("C:\\TEMP", "wi");
   if (tnam != NULL) {
      strcpy(tmplognam, tnam);
      flog = fopen(tmplognam, "w");
      free(tnam);
   }
   if (flog == NULL) {
      fprintf(stderr, "unable to open logfile");
      exit(EXIT_FAILURE);
      }

   if (!hPrevInstance) {
#if NT
      wc.style = CS_HREDRAW | CS_VREDRAW;
#else					/* NT */
      wc.style = 0;
#endif					/* NT */
#ifdef NTConsole
      wc.lpfnWndProc = DefWindowProc;
#else					/* NTConsole */
      wc.lpfnWndProc = WndProc;
#endif					/* NTConsole */
      wc.cbClsExtra = 0;
      wc.cbWndExtra = 0;
      wc.hInstance  = hInstance;
      wc.hIcon      = NULL;
      wc.hCursor    = LoadCursor(NULL, IDC_ARROW);
      wc.hbrBackground = GetStockObject(WHITE_BRUSH);
      wc.lpszMenuName = NULL;
      wc.lpszClassName = "iconx";
      RegisterClass(&wc);
      }
   }

HINSTANCE mswinInstance;
int ncmdShow;

jmp_buf mark_sj;

int_PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                   LPSTR lpszCmdParam, int nCmdShow)
   {
   int argc;
   char **argv;

   mswinInstance = hInstance;
   ncmdShow = nCmdShow;
   argc = CmdParamToArgv(GetCommandLine(), &argv);
   MSStartup(argc, argv, hInstance, hPrevInstance);
#if BORLAND_286
   _InitEasyWin();
#endif					/* BORLAND_286 */
   if (setjmp(mark_sj) == 0)
      icont(argc,argv);
   while (--argc>=0)
      free(argv[argc]);
   free(argv);
   wfreersc();
   return 0;
}

#define main icont
#endif					/* MSWindows */
#endif					/* NTConsole */

static void report_errors(int f)
{
    char buff[64];
    *buff = 0;
    if (errors > 0) {
        if (errors == 1)
            strcpy(buff, "1 error");
        else 
            sprintf(buff, "%d errors", errors);
    } else if (f)
        strcpy(buff, "No errors");

    if (warnings > 0) {
        if (*buff)
            strcat(buff, ", ");
        if (warnings == 1)
            strcat(buff, "1 warning");
        else 
            sprintf(buff + strlen(buff), "%d warnings", warnings);
    }
    if (*buff)
        report("%s", buff);
}

static int ldbg(int argc, char **argv);
static void init_strings();


/*
 *  main program
 */

int main(int argc, char **argv)
{
    int nolink = 0;			/* suppress linking? */
    char *efile = NULL;			/* stderr file */
    int c;
    char ch;
    struct fileparts *fp;
    struct file_param *rptr;
    static char buf[MaxFileName];  /* file name construction buffers */

    init_strings();

    if (strlen(*argv) >= 4 && !strcmp(*argv + strlen(*argv) - 4, "udis"))
        return udis(argc, argv);

    if (strlen(*argv) >= 4 && !strcmp(*argv + strlen(*argv) - 4, "ldbg"))
        return ldbg(argc, argv);

    if ((int)strlen(patchpath) > 18)
        iconxloc = patchpath+18;	/* use stated iconx path if patched */
    else
        iconxloc = relfile(argv[0],
#if defined(MSVC) && defined(MSWindows)
                           "/../wiconx"
#else					/* MSWindows */
                           "/../oiconx"
#endif					/* MSVC && MSWindows */
            );
    /*
     * Process options. NOTE: Keep Usage definition in sync with getopt() call.
     */
#define Usage "[-cBstuEG] [-f s] [-o ofile] [-v i]"	/* omit -e from doc */
    while ((c = getopt(argc,argv, "cBe:f:no:stuGv:ELZ")) != EOF) {
        switch (c) {
            case 'n':
                neweronly = 1;
                break;
            case 'B':
                bundleiconx = 1;
                break;
            case 'C':			/* Ignore: compiler only */
                break;
            case 'E':			/* -E: preprocess only */
                pponly = 1;
                nolink = 1;
                break;

            case 'L':			/* -L: enable linker debugging */

#ifdef DeBugLinker
                Dflag = 1;
#endif					/* DeBugLinker */

                break;

            case 'G':			/* -G: enable graphics */
                Gflag = 1;
                break;

            case 'S':			/* -S */
                fprintf(stderr, "Warning, -S option is obsolete\n");
                break;

#if MSDOS
            case 'X':			/* -X */
                makeExe = 1;
                break;
            case 'I':			/* -C */
                makeExe = 0;
                break;
#endif					/* MSDOS */

            case 'V':
                printf("%s\n", Version);
                exit(0);
                break;
            case 'c':			/* -c: compile only (no linking) */
                nolink = 1;
                break;
            case 'e':			/* -e file: redirect stderr */
                efile = optarg;
                break;
            case 'f':			/* -f features: enable features */
                if (strchr(optarg, 's') || strchr(optarg, 'a'))
                    strinv = 1;		/* this is the only icont feature */
                break;

            case 'm':			/* -m: preprocess using m4(1) [UNIX] */
                m4pre = 1;
                break;

            case 'o':			/* -o file: name output file */
                ofile = optarg;
                break;

            case 'r':			/* Ignore: compiler only */
                break;
            case 's':			/* -s: suppress informative messages */
                silent = 1;
                verbose = 0;
                break;
            case 't':			/* -t: turn on procedure tracing */
                trace = -1;
                break;
            case 'u':			/* -u: warn about undeclared ids */
                uwarn = 1;
                break;
            case 'v':			/* -v n: set verbosity level */
                if (sscanf(optarg, "%d%c", &verbose, &ch) != 1)
                    quitf("bad operand to -v option: %s",optarg);
                if (verbose == 0)
                    silent = 1;
                break;
            case 'Z':
                /* add flag to say "don't compress". noop unless HAVE_LIBZ */
                Zflag = 0;
                break;

            default:
            case 'x':			/* -x illegal until after file list */
                usage();
        }
    }

#if MSDOS && !NT
    /*
     * Define pathToIconDOS as a global accessible from inside
     * separately-compiled compilation units.
     */
    if( makeExe ){
        char *pathCursor;

        strcpy (pathToIconDOS, argv[0]);
        pathCursor = (char *)strrchr (pathToIconDOS, '\\');
        if (!pathCursor) {
            fprintf (stderr,
                     "Can't understand what directory icont was run from.\n");
            exit(EXIT_FAILURE);
        }
        strcpy( ++pathCursor, (makeExe==1) ?  "ixhdr.exe" : "iconx.exe");
    }
#endif                                  /* MSDOS && !NT */

    /*
     * Scan file name arguments.
     */
    while (optind < argc)  {
        if (strcmp(argv[optind],"-x") == 0)	/* stop at -x */
            break;
        else if (strcmp(argv[optind],"-") == 0) {
            add_trans_file("-");      /* "-" means standard input */
            add_link_file("stdin.u");
            add_remove_file("stdin.u");
        }
        else {
            fp = fparse(argv[optind]);		/* parse file name */
            if (*fp->ext == '\0' || smatch(fp->ext, SourceSuffix)) {
                makename(buf, SourceDir, argv[optind],  SourceSuffix);
                add_trans_file(buf);
                makename(buf, SourceDir, argv[optind], USuffix);
                add_link_file(buf);
                add_remove_file(buf);
            }
            else if (smatch(fp->ext, USuffix)) {
                makename(buf, TargetDir, argv[optind], USuffix);
                add_link_file(buf);
            }
            else
                quitf("bad argument %s", argv[optind]);
        }
        optind++;
    }

    if (!link_files)
        usage();				/* error -- no files named */

    ipath = libpath(argv[0], IPATH);	/* set library search paths */
    lpath = libpath(argv[0], LPATH);

    /*
     * Translate .icn files to make .u files.
     */
    if (trans_files) {
        if (!pponly)
            report("Translating:");
        trans(trans_files, &errors, &warnings);
        report_errors(1);
        if (errors > 0)			/* exit if errors seen */
            exit(EXIT_FAILURE);
    }

    /*
     * Link .u files to make an executable.
     */
    if (nolink) {			/* exit if no linking wanted */
        exit(EXIT_SUCCESS);
    }

#if MSDOS
    {
        if (ofile == NULL)  {                /* if no -o file, synthesize a name */
            ofile = intern_using(&join_sbuf, makename(buf,TargetDir,lfiles[0],
                                    makeExe ? ".exe" : IcodeSuffix));
        }
        else {                             /* add extension if necessary */
            fp = fparse(ofile);
            if (*fp->ext == '\0' && *IcodeSuffix != '\0') /* if no ext given */
                ofile = intern_using(&join_sbuf, makename(buf,NULL,ofile,
                                        makeExe ? ".exe" : IcodeSuffix));
        }
    }
#else                                   /* MSDOS */

    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
        ofile = intern_using(&join_sbuf, makename(buf,SourceDir,link_files->name,IcodeSuffix));
    } else {				/* add extension in necessary */
        fp = fparse(ofile);
        if (*fp->ext == '\0' && *IcodeSuffix != '\0') /* if no ext given */
            ofile = intern_using(&join_sbuf, makename(buf,NULL,ofile,IcodeSuffix));
    }

#endif					/* MSDOS */

    report("Linking:");
    ilink(link_files, ofile, &errors, &warnings);	/* link .u files to make icode file */

#if HAVE_LIBZ
    /*
     * we have linked together a bunch of files to make an icode,
     * now call file_comp() to compress it
     */
    if (Zflag) {
#if NT
#define stat _stat
#endif					/* NT */
        struct stat buf;
        int i = stat(ofile, &buf);
        if (i==0 && buf.st_size > 1000000 && file_comp(ofile)) {
            report("error during icode compression");
        }
    }
#endif					/* HAVE_LIBZ */

#if NT
    if (!bundleiconx)
        bundleiconx = !stricmp(".exe", ofile+strlen(ofile)-4);
#endif

    /*
     * prepend iconx if we generated an executable and specified to bundle
     */
    if (!errors && bundleiconx) {
        FILE *f, *f2;
        char tmp[MaxPath], *iconx;
        strcpy(tmp, ofile);
        strcpy(tmp+strlen(tmp)-4, ".bat");
        rename(ofile, tmp);

#if UNIX
        iconx = "iconx";
#endif
#if NT
        if (Gflag) iconx="wiconx.exe";
        else
            iconx = "iconx.exe";
#endif					/* NT */
        if ((f = pathOpen(iconx, ReadBinary)) == NULL) {
            report("Tried to open %s to build .exe, but couldn't",iconx);
            errors++;
        }
        else {
            f2 = fopen(ofile, WriteBinary);
            while ((c = fgetc(f)) != EOF) {
                fputc(c, f2);
	    }
            fclose(f);
            if ((f = fopen(tmp, ReadBinary)) == NULL) {
                report("tried to read .bat to append to .exe, but couldn't");
                errors++;
	    }
            else {
                while ((c = fgetc(f)) != EOF) {
                    fputc(c, f2);
                }
                fclose(f);
	    }
            fclose(f2);
            setexe(ofile);
            unlink(tmp);
        }
    }

    /*
     * Finish by removing intermediate files.
     *  Execute the linked program if so requested and if there were no errors.
     */

#if MACINTOSH
#if MPW
    /* Set file type to TEXT so it will be executable as a script. */
    setfile(ofile,'TEXT','ICOD');
#endif					/* MPW */
#endif					/* MACINTOSH */

    /* delete intermediate files */
    for (rptr = remove_files; rptr; rptr = rptr->next)
        remove(rptr->name);

    report_errors(0);

    if (errors > 0) {			/* exit if linker errors seen */
        remove(ofile);
        exit(EXIT_FAILURE);
    }

#if !(MACINTOSH && MPW)
    if (optind < argc)  {
        report("Executing");
        execute (ofile, efile, argv+optind+1);
    }
#endif					/* !(MACINTOSH && MPW) */

    exit(EXIT_SUCCESS);
}

/*
 * execute - execute iconx to run the icon program
 */
static void execute(char *ofile, char *efile, char **args)
   {

#if !(MACINTOSH && MPW)
   int n;
   char **argv, **p;

   for (n = 0; args[n] != NULL; n++)	/* count arguments */
      ;
   p = argv = (char **)alloc((unsigned int)((n + 5) * sizeof(char *)));

#if !UNIX	/* exec the file, not iconx; stderr already redirected  */
   *p++ = iconxloc;			/* set iconx pathname */
   if (efile != NULL) {			/* if -e given, copy it */
      *p++ = "-e";
      *p++ = efile;
      }
#endif					/* UNIX */

   *p++ = ofile;			/* pass icode file name */

#if AMIGA && LATTICE
   *p = *args;
   while (*p++) {
      *p = *args;
      args++;
   }
#else					/* AMIGA && LATTICE */
#ifdef MSWindows
#ifndef NTConsole
   {
      char cmdline[256], *tmp;

      strcpy(cmdline, "wiconx ");
      if (efile != NULL) {
         strcat(cmdline, "-e ");
         strcat(cmdline, efile);
         strcat(cmdline, " ");
      }
   strcat(cmdline, ofile);
   strcat(cmdline, " ");
   while ((tmp = *args++) != NULL) {	/* copy args into argument vector */
      strcat(cmdline, tmp);
      strcat(cmdline, " ");
   }

   WinExec(cmdline, SW_SHOW);
   return;
   }
#endif					/* NTConsole */
#endif					/* MSWindows */

   while ((*p++ = *args++) != 0)      /* copy args into argument vector */
      ;
#endif					/* AMIGA && LATTICE */

   *p = NULL;

/*
 * The following code is operating-system dependent [@tmain.03].  It calls
 *  iconx on the way out.
 */

#if PORT
   /* something is needed */
Deliberate Syntax Error
#endif					/* PORT */

#if ATARI_ST || MACINTOSH
      fprintf(stderr,"-x not supported\n");
      fflush(stderr);
#endif					/* ATARI_ST || ... */

#if MSDOS
      /* No special handling is needed for an .exe files, since iconx
       * recognizes it from the extension andfrom internal .exe data.
       */
#if MICROSOFT || TURBO || BORLAND_286 || BORLAND_386
      execvp(iconxloc,argv);	/* execute with path search */
#endif					/* MICROSOFT || ... */

#if INTEL_386 || ZTC_386 || HIGHC_386 || WATCOM || SCCX_MX
      fprintf(stderr,"-x not supported\n");
      fflush(stderr);
#endif					/* INTEL_386 || ... */

#endif					/* MSDOS */

#if UNIX
      /*
       * Just execute the file.  It knows how to find iconx.
       * First, though, must redirect stderr if requested.
       */
      if (efile != NULL) {
         close(fileno(stderr));
         if (strcmp(efile, "-") == 0)
            dup(fileno(stdout));
         else if (freopen(efile, "w", stderr) == NULL)
            quitf("could not redirect stderr to %s\n", efile);
         }
      execv(ofile, argv);
      quitf("could not execute %s", ofile);
#endif					/* UNIX */

#if VMS
      execv(iconxloc,argv);
#endif					/* VMS */

/*
 * End of operating-system specific code.
 */

   quitf("could not run %s",iconxloc);

#else					/* !(MACINTOSH && MPW) */
   printf("-x not supported\n");
#endif					/* !(MACINTOSH && MPW) */

   }

void report(char *fmt, ...)
{
    va_list argp;
    if (silent)
        return;
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
}

/*
 * Print an error message if called incorrectly.  The message depends
 *  on the legal options for this system.
 */
static void usage()
   {
#if MVS || VM
   fprintf(stderr,"usage: %s %s file ... <-x args>\n", progname, Usage);
#elif MPW
   fprintf(stderr,"usage: %s %s file ...\n", progname, Usage);
#else
   fprintf(stderr,"usage: %s %s file ... [-x args]\n", progname, Usage);
#endif					/* MVS || VM || MPW */
   exit(EXIT_FAILURE);
   }



#if MACINTOSH
#if THINK_C

/*
 * IncreaseStackSize - increases stack size by extraBytes
 */
void IncreaseStackSize (Size extraBytes)
{
   SetApplLimit ( GetApplLimit() - extraBytes );
}

/*
 * ToolBoxInit - initializes mac toolbox
 */
void ToolBoxInit ( void )
{
   InitGraf ( &qd.thePort );
   InitFonts ();
   InitWindows ();
   InitMenus ();
   TEInit ();
   InitDialogs ( nil );
   InitCursor ();
}

/*-------------- code for display graphics ----------------------*/

/*
 * DoEvent - handles AppleEvent by passing eventPtr to AEProcessAppleEvent
 *           Command-Q key sequence results exit of the program
 */
void DoEvent ( EventRecord *eventPtr )
{
   char theChar;

   switch ( eventPtr->what )
   {
      case mouseDown:        DoMouseDown (eventPtr);
                             break;
/*
      case kHighLevelEvent : AEProcessAppleEvent ( eventPtr );
                             break;
 */
      case keyDown:
      case autoKey:          theChar = eventPtr->message & charCodeMask;
                             if ( (eventPtr->modifiers & cmdKey) != 0)
                                HandleMenuChoice (MenuKey (theChar));
                             break;
   }
}

/*
 * DoMouseDown -
 */
void DoMouseDown (EventRecord *eventPtr)
{
   WindowPtr whichWindow;
   short thePart;
   long menuChoice;

   thePart = FindWindow (eventPtr->where, &whichWindow);
   switch (thePart) {
      case inMenuBar:
         menuChoice = MenuSelect (eventPtr->where);
         HandleMenuChoice (menuChoice);
         break;
      }
}

/*
 * HandleMenuChoice -
 */
void HandleMenuChoice (long menuChoice)
{
   short menu;
   short item;

   if (menuChoice != 0) {
      menu = HiWord (menuChoice);
      item = LoWord (menuChoice);

      switch (menu) {
         case kAppleMenu:
            HandleAppleChoice (item);
            break;
         case kFileMenu:
            HandleFileChoice (item);
            break;
         case kOptionsMenu:
            HandleOptionsChoice (item);
            break;
         }
      HiliteMenu (0);
      }
}

void HandleAppleChoice (short item)
{
   MenuHandle  appleMenu;
   Str255      accName;
   short       accNumber;

   switch (item) {
      case kAboutMItem:
         SysBeep (20);
         break;
         /* ******************* open a dialog box **************** */
      default:
         appleMenu = GetMHandle (kAppleMenu);
         GetItem (appleMenu, item, accName);
         accNumber = OpenDeskAcc (accName);
         break;
      }
}

void HandleFileChoice (short item)
{
   StandardFileReply fileReply;
   SFTypeList typeList;
   short numTypes;
   char *fileName;
   int argc;
   char **argv;
   MenuHandle menu;

   switch (item) {
      case kQuitMItem:
         gDone = true;
         abort ();
         break;
      case kCompileMItem:
         typeList[0] = 'TEXT';
         numTypes = 1;
         StandardGetFile (nil, numTypes, typeList, &fileReply);
         if (fileReply.sfGood) {
            fileName = PtoCstr (fileReply.sfFile.name);
            menu = GetMHandle (kFileMenu);
            DisableItem (menu, kCompileMItem);
            menu = GetMHandle (kOptionsMenu);
            DisableItem (menu, 0);
            }
         else
            break;

         if (g_cOption)
            argc = 3;
         else
            argc = 2;

         argv = malloc (sizeof (*argv) * argc);
         argv[0] = malloc (strlen ("ICONT") + 1);
         strcpy (argv[0], "ICONT");

         if (g_cOption) {
            argv[1] = malloc (strlen ("-c") + 1);
            strcpy (argv[1], "-c");
            }

         argv[argc-1] = malloc (strlen(fileName) + 1);
         strcpy (argv[argc-1], fileName);

         MacMain (argc, argv);
         break;
      }
}

void HandleOptionsChoice (short item)
{
   MenuHandle menu;

   switch (item) {
      case k_cMItem:
         g_cOption = !g_cOption;
         menu = GetMHandle (kOptionsMenu);
         CheckItem (menu, item, g_cOption);
         break;
      }
}

/*------------------  End of display graphics code ------------------------*/

void MenuBarInit (void)
{
   Handle         menuBar;
   MenuHandle     menu;
   OSErr          myErr;
   long           feature;

   g_cOption = false;

   menuBar = GetNewMBar (kMenuBar);
   SetMenuBar (menuBar);

   menu = GetMHandle (kAppleMenu);
   AddResMenu (menu, 'DRVR');

   menu = GetMHandle (kOptionsMenu);
   CheckItem (menu, k_cMItem, g_cOption);

   DrawMenuBar ();
}

/*
 * EventInit - calls Gestalt to check if AppleEvent is available, if so,
 *   install OpenDocument and QuitApplication handler routines
 */
void EventInit ( void )
{
   OSErr err;
   long  feature;

   err = Gestalt ( gestaltAppleEventsAttr, &feature );

   if ( err != noErr ) {
      printf ("Problem in calling Gestalt.");
      return;
      }
   else {
      if ( ! ( feature & (kGestaltMask << gestaltAppleEventsPresent ) ) ) {
         printf ("Apple events not available!");
         return;
         }
      }

   err = AEInstallEventHandler (kCoreEventClass,
                                kAEOpenDocuments,
            (AEEventHandlerUPP)   DoOpenDoc,
                                0L,
                                false );

   if ( err != noErr )
      printf ("kAEOpenDocuments Apple Event not available!");

   err = AEInstallEventHandler (kCoreEventClass,
                                kAEQuitApplication,
             (AEEventHandlerUPP)  DoQuitApp,
                                0L,
                                false );
   if ( err != noErr )
      printf ("kAEQuitApplication Apple Event not available!");
}

/*
 * EventLoop - waits for an event to be processed
 */
void EventLoop ( void )
{
   EventRecord event;

   gDone = false;
   while ( gDone == false ) {
      if ( WaitNextEvent ( everyEvent, &event, kSleep, nil ) )
         DoEvent ( &event );
      }
}

/*
 * DoOpenDoc - called by AEProcessAppleEvent (a ToolBox routine)
 *
 *    Calls AECountItems to retrieve number of files is to be processed
 *    and enters a loop to process each file.  Sets gDone to true
 *    to terminate program.
 */
pascal OSErr DoOpenDoc ( AppleEvent theAppleEvent,
                         AppleEvent reply,
                               long refCon )
{
   AEDescList fileSpecList;
   FSSpec     file;
   OSErr      err;
   DescType   type;
   Size       actual;
   long       count;
   AEKeyword  keyword;
   long       i;

   int        argc;
   char       **argv;

   char       *fileName;

   err = AEGetParamDesc ( &theAppleEvent,
                          keyDirectObject,
                          typeAEList,
                          &fileSpecList );
   if ( err != noErr ) {
      printf ("Error AEGetParamDesc");
      return ( err );
      }

   err = GotRequiredParams ( &theAppleEvent );
   if ( err != noErr ) {
      printf ("Error GotRequiredParams");
      return ( err );
      }

   err = AECountItems ( &fileSpecList, &count );
   if ( err != noErr ) {
      printf ("Error AECountItems");
      return ( err );
      }

   argc = count + 1;
   argv = malloc (sizeof (*argv) * (argc + 1));
   argv[0] = malloc (strlen("ICONT") + 1);
   strcpy (argv[0], "ICONT");

   for ( i = 1; i <= count; i++ ) {
      err = AEGetNthPtr ( &fileSpecList,
                          i,
                          typeFSS,
                          &keyword,
                          &type,
                          (Ptr) &file,
                          sizeof (FSSpec),
                          &actual );
      if ( err != noErr ) {
         printf ("Error AEGetNthPtr");
         return ( err );
	 }

      fileName = PtoCstr (file.name);
      argv[i] = malloc(strlen(fileName) + 1);
      strcpy (argv[i], fileName);
      }
   MacMain (argc, argv);
   gDone = true;
   return ( noErr );
}

/*
 * DoQuitApp - called by AEProcessAppleEvent (a ToolBox routine)
 *             sets gDone to true to terminate program
 */
pascal OSErr DoQuitApp ( AppleEvent theAppleEvent,
                         AppleEvent reply,
                               long refCon )
{
   OSErr err = noErr;
   gDone = true;
   return err;
}

/*
 * GotRequiredParams - check if all required parameters are retrieved
 */
OSErr GotRequiredParams ( AppleEvent *appleEventPtr )
{
    DescType returnedType;
    Size     actualSize;
    OSErr    err;

    err = AEGetAttributePtr ( appleEventPtr,
                              keyMissedKeywordAttr,
                              typeWildCard,
                              &returnedType,
                              nil,
                              0,
                              &actualSize );
    if ( err == errAEDescNotFound )
        return noErr;
    else
        if (err == noErr )
            return errAEEventNotHandled;
        else
            return err;
}

#endif               /* THINK_C */
#endif               /* MACINTOSH */

/*
 * quit - immediate exit with error message
 */

void quit(char *msg)
{
    quitf(msg,"");
}

/*
 * quitf - immediate exit with message format and argument
 */
void quitf(char *fmt, ...)
{
    va_list argp;
    extern char *progname;
    va_start(argp, fmt);
    fprintf(stderr,"%s: ",progname);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    if (ofile)
        remove(ofile);			/* remove bad icode file */
    exit(EXIT_FAILURE);
}

void init_strings()
{
    init_str();
    init_sbuf(&join_sbuf);
    main_string = spec_str("main");
    default_string = spec_str("default");
    self_string = spec_str("self");
    new_string = spec_str("new");
    init_string = spec_str("init");
    all_string = spec_str("all");
    package_marker_string = spec_str(">package");
}

#include "tree.h"
#include "../h/lexdef.h"

extern struct toktab toktab[];
extern int nlflag;

static int ldbg(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: ldbg srcfile\n");
        exit(1);
    }

    lpath = libpath("oicont", LPATH);
    tmalloc();			/* allocate memory for translation */

    if (!ppinit(argv[1],lpath,0))
        quitf("cannot open %s", argv[1]);

    while (1) {
        yylex();
        if (nlflag)
            printf("\n");
        if (!yylval)
            break;
        switch (yylval->n_type) {
            case N_Id:
                printf("%s ", Str0(yylval));
                break;
            case N_Res: {
                int i;
                for (i = 0;; ++i) {
                    if (toktab[i].t_type == 0)
                        exit(-1);
                    if (toktab[i].t_type == Val0(yylval))
                        break;
                }
                printf("%s ", toktab[i].t_word);
                break;
            }
            case N_Int:
                printf("%ld ", Val0(yylval));
                break;
            case N_Real:
                printf("%s ", Str0(yylval));
                break;
            case N_Str:
                printf("\"%s\" ", Str0(yylval));
                break;
            case N_Cset:
                printf("\'%s\' ", Str0(yylval));
                break;
            case N_Op: {
                int i;
                for (i = 0;; ++i) {
                    if (optab[i].tok.t_type == 0)
                        exit(-1);
                    if (optab[i].tok.t_type == Val0(yylval))
                        break;
                }
                printf("%s ",optab[i].tok.t_word);
                break;
            }
        }
    }
}
