/*
 * tmain.c - main program for translator and linker.
 */

#include "icont.h"
#include "tmain.h"
#include "trans.h"
#include "ucode.h"
#include "link.h"
#include "tmem.h"
#include "tlex.h"
#include "util.h"
#include "../h/header.h"

int warnings = 0;           /* count of warnings */
int errors = 0;		    /* translator and linker errors */

int m4pre	=0;	/* -m: use m4 preprocessor? [UNIX] */
int trace	=0;	/* -t: initial &trace value */
int pponly	=0;	/* -E: preprocess only */
int strinv	=0;	/* -f s: allow full string invocation */
int verbose	=1;	/* -v n: verbosity of commentary, 0 = silent */
int neweronly	=0;	/* -n: only translate .icn if newer than .u */
int Dflag       =0;     /* -L: link debug */
int Zflag	=0;	/* -Z: icode-gz compression */
int Bflag       =0;     /* -B: bundle iconx in output file */

/*
 * Some convenient interned strings.
 */
char *main_string;
char *default_string;
char *self_string;
char *new_string;
char *init_string;
char *all_string;
char *lang_string;
char *package_marker_string;

/*
 * Variables related to command processing.
 */
char *progname	="oit";	/* program name for diagnostics */

/*
 * Files and related globals.
 */
char *lpath;			/* search path for $include */
char *ipath;			/* search path for linking */
FILE *ucodefile	= 0;	        /* current ucode output file */
char *ofile = 0;         	/* name of linker output file */
char *iconxloc;			/* path to iconx */
long hdrsize;			/* size of iconx header */

#ifdef MSWindows
   #include "../h/filepat.h"
#endif					/* MSWindows */

/*
 * Prototypes.
 */

#ifdef HAVE_LIBZ
static void file_comp(char *ofile);
#endif
static void bundle_iconx(char *ofile);
static void execute(char *ofile,char *efile,char * *args);
static void usage(void);

/*
 * The following code is operating-system dependent [@tmain.01].  Include
 *  files and such.
 */

#if PORT
   Deliberate syntax error
#endif					/* PORT */

#if UNIX
   /* nothing is needed */
#endif					

#if MSWindows
   char pathToIconDOS[129];
#endif					/* MSWindows */

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

struct file_param *trans_files = 0, *last_trans_file = 0, 
                  *link_files = 0, *last_link_file = 0,
                  *remove_files = 0, *last_remove_file = 0;

static void add_trans_file(char *s)
{
    struct file_param *p = Alloc(struct file_param);
    p->name = intern(s);
    if (last_trans_file) {
        last_trans_file->next = p;
        last_trans_file = p;
    } else
        trans_files = last_trans_file = p;
}

static void add_link_file(char *s)
{
    struct file_param *p = Alloc(struct file_param);
    p->name = intern(s);
    if (last_link_file) {
        last_link_file->next = p;
        last_link_file = p;
    } else
        link_files = last_link_file = p;
}

static void add_remove_file(char *s)
{
    struct file_param *p = Alloc(struct file_param);
    p->name = intern(s);
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

    /*
     * Check for alternate uses, udis and ldbg.
     */
    fp = fparse(*argv);
    if (smatch(fp->name, "udis"))
        return udis(argc, argv);
    if (smatch(fp->name, "ldbg"))
        return ldbg(argc, argv);

    iconxloc = findexe("oix");
    if (!iconxloc)
        quitf("Couldn't find oix on PATH");
    iconxloc = intern(canonicalize(iconxloc));

    /*
     * Process options. NOTE: Keep Usage definition in sync with getopt() call.
     */
#define Usage "[-cBstuE] [-f s] [-o ofile] [-v i]"	/* omit -e from doc */
    while ((c = getopt(argc,argv, "cBe:fmno:stv:ELZTV")) != EOF) {
        switch (c) {
            case 'n':
                neweronly = 1;
                break;

            case 'B':
                Bflag = 1;
                break;

            case 'E':			/* -E: preprocess only */
                pponly = 1;
                nolink = 1;
                break;

            case 'L':			/* -L: enable linker debugging */
                Dflag = 1;
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

            case 'f':			/* -f : full invocation */
                strinv = 1;		
                break;

            case 'm':			/* -m: preprocess using m4(1) [UNIX] */
                m4pre = 1;
                break;

            case 'o':			/* -o file: name output file */
                ofile = optarg;
                break;

            case 's':			/* -s: suppress informative messages */
                verbose = 0;
                break;

            case 't':			/* -t: turn on procedure tracing */
                trace = -1;
                break;

            case 'v':			/* -v n: set verbosity level */
                if (sscanf(optarg, "%d%c", &verbose, &ch) != 1)
                    quitf("bad operand to -v option: %s",optarg);
                break;

            case 'Z':
                Zflag = 1;
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
        ofile = intern(makename(SourceDir,link_files->name,
						  Bflag ? ".exe" : ".bat"));
    } else {				/* add extension in necessary */
        fp = fparse(ofile);
        if (*fp->ext == '\0') /* if no ext given */
            ofile = intern(makename(0,ofile,
						      Bflag ? ".exe" : ".bat"));
    }
    }
#else                                   /* MSWindows */

    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
        ofile = intern(makename(SourceDir,link_files->name,""));
    }

#endif					/* MSWindows */

    report("Linking:");
    ilink(link_files, ofile, &errors, &warnings);	/* link .u files to make icode file */

    if (!errors) {
#ifdef HAVE_LIBZ
        /*
         * Optional gz compression
         */
        if (Zflag)
            file_comp(ofile);
#endif					/* HAVE_LIBZ */
        /*
         * Optional bundling of iconx executable in output
         */
        if (Bflag)
            bundle_iconx(ofile);
    }

    /*
     * Finish by removing intermediate files.
     *  Execute the linked program if so requested and if there were no errors.
     */

    /* delete intermediate files */
    for (rptr = remove_files; rptr; rptr = rptr->next)
        remove(rptr->name);

    report_errors(0);

    if (errors > 0) {			/* exit if linker errors seen */
        remove(ofile);
        exit(EXIT_FAILURE);
    }

    if (optind < argc)  {
        report("Executing:");
        execute (ofile, efile, argv+optind+1);
    }

    exit(EXIT_SUCCESS);
}

/*
 * execute - execute iconx to run the icon program
 */
static void execute(char *ofile, char *efile, char **args)
   {
   int n;
   char **argv, **p;

   for (n = 0; args[n] != NULL; n++)	/* count arguments */
      ;
   p = argv = safe_alloc((n + 5) * sizeof(char *));

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

/*
 * End of operating-system specific code.
 */

   quitf("could not run %s",iconxloc);

   }

static void bundle_iconx(char *ofile)
{
    FILE *f, *f2;
    int c;
    char *tmp = intern(makename(0, ofile, ".tmp"));
    rename(ofile, tmp);

    if (!(f = fopen(iconxloc, ReadBinary)))
        quitf("Tried to open oix to build .exe, but couldn't");

    if (!(f2 = fopen(ofile, WriteBinary)))
        quitf("Couldn't reopen output file %s", ofile);

    while ((c = fgetc(f)) != EOF)
        fputc(c, f2);

    fclose(f);
    if (!(f = fopen(tmp, ReadBinary))) 
        quitf("tried to read %s to append to exe, but couldn't",tmp);

    while ((c = fgetc(f)) != EOF)
        fputc(c, f2);

    fclose(f);

    fclose(f2);
    setexe(ofile);
    unlink(tmp);
}

#ifdef HAVE_LIBZ

static void file_comp(char *ofile) 
{
    gzFile f; 
    FILE *finput, *foutput;
    struct header *hdr;
    int n, c;
    char buf[200], *tmp = intern(makename(0, ofile, ".tmp"));
  
    hdr = safe_alloc(sizeof(struct header));
    
    /* use fopen() to open the target file then read the header and add "z" to the hdr->config. */
    
    if (!(finput = fopen(ofile, ReadBinary)))
        quitf("Can't open the file to compress: %s",ofile);
    
    if (!(foutput = fopen(tmp, WriteBinary)))
        quitf("Can't open the temp compression file: %s",tmp);

    n = strlen(IcodeDelim);
    for (;;) {
        if (fgets(buf, sizeof(buf) - 1, finput) == NULL)
            quitf("Compression - Reading Error: Check if the file is executable Icon");
        fputs(buf, foutput);
        if (strncmp(buf, IcodeDelim, n) == 0)
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), finput) != sizeof(*hdr))
        quitf("gz compressor can't read the header, compression");
    
    /* Turn on the Z flag */
    strcat((char *)hdr->config,"Z");

    /* write the modified header into a new file */
    
    fwrite((char *)hdr, sizeof(char), sizeof(*hdr), foutput);
    
    /* close the new file */
  
    fclose(foutput);
    
    /* use gzopen() to open the new file */
    
    if (!(f = gzopen(tmp, AppendBinary)))
        quitf("Compression Error: can not open output file %s", tmp);
    
    /*
     * read the rest of the target file and write the compressed data into
     * the new file
     */
    
    while((c = fgetc(finput)) != EOF) {
        gzputc(f, c);
        if (ferror(finput))
            quitf("Compression - Error occurs while reading!");
    }
   
    /* close both files */
    fclose(finput);
    gzclose(f);
    
    if (unlink(ofile))
        quitf("can't remove old %s, compressed version left in %s",
              ofile, tmp);

    if (rename(tmp, ofile))
        quitf("can't rename compressed %s back to %s", tmp, ofile);

    setexe(ofile);
}

#endif

void report(char *fmt, ...)
{
    va_list argp;
    if (verbose == 0)
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

/*
 * The given name is a canonical reference to a source file.  If it
 * exists and represents a file in the current directory, just the
 * last path element is returned.  If it doesn't exist (eg it is a
 * reference from an installed ucode file), the last path element is
 * also returned, to avoid printing a non-existent path.  If however
 * it does exist, but is not in the current directory, the full path
 * is returned.
 */
char *abbreviate(char *name)
{
    char *l = last_pathelem(name);
    if (!access(name, R_OK)) {
        if (strcmp(canonicalize(l), name))
            return name;
        else
            return l;
    } else
        return l;
}

void init_strings()
{
    init_str();
    main_string = spec_str("main");
    default_string = spec_str("default");
    self_string = spec_str("self");
    new_string = spec_str("new");
    init_string = spec_str("init");
    all_string = spec_str("all");
    lang_string = spec_str("lang");
    package_marker_string = spec_str(">package");
}

#include "tree.h"
#include "lexdef.h"

extern struct toktab toktab[];
extern int nlflag;

static int ldbg(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: ldbg srcfile\n");
        exit(1);
    }

    lpath = getenv(LPATH);

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
