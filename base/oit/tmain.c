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

/*
 * Variables related to command processing.
 */
char *progname	="oit";	/* program name for diagnostics */

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

#ifdef MSWindows
   #include "../h/filepat.h"
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

#if MSWindows
   char pathToIconDOS[129];
#endif					/* MSWindows */

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

    init_strings();

    if (strlen(*argv) >= 4 && !strcmp(*argv + strlen(*argv) - 4, "udis"))
        return udis(argc, argv);

    if (strlen(*argv) >= 4 && !strcmp(*argv + strlen(*argv) - 4, "ldbg"))
        return ldbg(argc, argv);

    iconxloc = salloc(relfile(argv[0], "/../oix"));

    /*
     * Process options. NOTE: Keep Usage definition in sync with getopt() call.
     */
#define Usage "[-cBstuE] [-f s] [-o ofile] [-v i]"	/* omit -e from doc */
    while ((c = getopt(argc,argv, "cBe:f:no:stuv:ELZ")) != EOF) {
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

            case 'S':			/* -S */
                fprintf(stderr, "Warning, -S option is obsolete\n");
                break;

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
                char *t;
                add_trans_file(makename(SourceDir, argv[optind],  SourceSuffix));
                t = makename(SourceDir, argv[optind], USuffix);
                add_link_file(t);
                add_remove_file(t);
            }
            else if (smatch(fp->ext, USuffix)) {
                add_link_file(makename(TargetDir, argv[optind], USuffix));
            }
            else
                quitf("bad argument %s", argv[optind]);
        }
        optind++;
    }

    if (!link_files)
        usage();				/* error -- no files named */

    ipath = getenv(IPATH);	/* set library search paths */
    lpath = getenv(LPATH);

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

#if MSWindows
    {
    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
        ofile = intern_using(&join_sbuf, makename(SourceDir,link_files->name,
						  bundleiconx ? ".exe" : ".bat"));
    } else {				/* add extension in necessary */
        fp = fparse(ofile);
        if (*fp->ext == '\0') /* if no ext given */
            ofile = intern_using(&join_sbuf, makename(0,ofile,
						      bundleiconx ? ".exe" : ".bat"));
    }
    }
#else                                   /* MSWindows */

    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
        ofile = intern_using(&join_sbuf, makename(SourceDir,link_files->name,""));
    }

#endif					/* MSWindows */

    report("Linking:");
    ilink(link_files, ofile, &errors, &warnings);	/* link .u files to make icode file */

#ifdef HAVE_LIBZ
    /*
     * we have linked together a bunch of files to make an icode,
     * now call file_comp() to compress it
     */
    if (Zflag) {
#if MSWindows
#define stat _stat
#endif					/* NT */
        struct stat buf;
        int i = stat(ofile, &buf);
        if (i==0 && buf.st_size > 1000000 && file_comp(ofile)) {
            report("error during icode compression");
        }
    }
#endif					/* HAVE_LIBZ */

    /*
     * prepend iconx if we generated an executable and specified to bundle
     */
    if (!errors && bundleiconx) {
        FILE *f, *f2;
        char *tmp = salloc(makename(0, ofile, ".tmp"));
        rename(ofile, tmp);

        if ((f = pathopen("oix", ReadBinary)) == NULL) {
            report("Tried to open oix to build .exe, but couldn't");
            errors++;
        }
        else {
            f2 = fopen(ofile, WriteBinary);
            while ((c = fgetc(f)) != EOF) {
                fputc(c, f2);
	    }
            fclose(f);
            if ((f = fopen(tmp, ReadBinary)) == NULL) {
                report("tried to read %s to append to exe, but couldn't",tmp);
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

   while ((*p++ = *args++) != 0)      /* copy args into argument vector */
      ;

   *p = NULL;

/*
 * The following code is operating-system dependent [@tmain.03].  It calls
 *  iconx on the way out.
 */

#if PORT
   /* something is needed */
Deliberate Syntax Error
#endif					/* PORT */

#if MACINTOSH
      fprintf(stderr,"-x not supported\n");
      fflush(stderr);
#endif

#if MSWindows
      /* No special handling is needed for an .exe files, since iconx
       * recognizes it from the extension andfrom internal .exe data.
       */
      execv(iconxloc,argv);	/* execute with path search */
#endif					/* MSWindows */

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
   fprintf(stderr,"usage: %s %s file ... [-x args]\n", progname, Usage);
   exit(EXIT_FAILURE);
   }


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

    lpath = getenv(LPATH);
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
    return 0;
}
