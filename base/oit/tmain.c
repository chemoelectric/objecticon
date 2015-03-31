/*
 * tmain.c - main program for translator and linker.
 */

#include "icont.h"
#include "tmain.h"
#include "membuff.h"
#include "trans.h"
#include "ucode.h"
#include "link.h"
#include "tmem.h"
#include "tlex.h"
#include "ipp.h"
#include "../h/header.h"

static int warnings = 0;           /* count of warnings */
static int errors = 0;		    /* translator and linker errors */

int m4pre	=0;	/* -m: use m4 preprocessor? [UNIX] */
int pponly	=0;	/* -E: preprocess only */
int strinv	=0;	/* -f s: allow full string invocation */
int verbose	=1;	/* -v n: verbosity of commentary, 0 = silent */
int Iflag       =0;     /* -I: produce listing of raw and optimized intermediate code */
int neweronly	=0;	/* -n: only translate .icn if newer than .u */
int Dflag       =0;     /* -L: link debug */
int Zflag	=0;	/* -Z: icode-gz compression */
int Bflag       =0;     /* -B: bundle iconx in output file */
int loclevel	=1;	/* -l n: amount of location info in icode 0 = none, 1 = trace info (default), 
                         *       2 = trace & symbol info */
int Olevel      =1;     /* -O n: optimisation */
int nolink      =0;	/* suppress linking? */

/*
 * Some convenient interned strings.
 */
char *main_string;
char *default_string;
char *self_string;
char *new_string;
char *init_string;
char *empty_string;
char *all_string;
char *lang_string;
char *stdin_string;
char *package_marker_string;
char *ascii_string;
char *utf8_string;
char *iso_8859_1_string;

/*
 * Variables related to command processing.
 */
static char *progname;	/* program name for diagnostics */

/*
 * Files and related globals.
 */
FILE *ucodefile	= 0;	        /* current ucode output file */
char *ofile = 0;         	/* name of linker output file */
char *oixloc;			/* path to iconx */
long scriptsize;		/* size of iconx header script */

/*
 * Prototypes.
 */

#if HAVE_LIBZ
static void file_comp(void);
#endif
static void bundle_iconx(void);
static void execute(char **args);
static void usage(void);
static void long_usage(void);
static void remove_intermediate_files(void);


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

void add_remove_file(char *s)
{
    struct file_param *p = Alloc(struct file_param);
    p->name = intern(s);
    if (last_remove_file) {
        last_remove_file->next = p;
        last_remove_file = p;
    } else
        remove_files = last_remove_file = p;
}


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
static void init_strings(void);

static void remove_intermediate_files()
{
    struct file_param *rptr;
    /* delete intermediate files */
    for (rptr = remove_files; rptr; rptr = rptr->next)
        remove(rptr->name);
}

/*
 *  main program
 */

int main(int argc, char **argv)
{
    int c;
    char ch;
    struct fileparts *fp;

    progname = *argv;

    init_strings();

    /*
     * Check for alternate uses, udis and ldbg.
     */
    fp = fparse(*argv);
    if (smatch(fp->name, "udis"))
        return udis(argc, argv);
    if (smatch(fp->name, "ldbg"))
        return ldbg(argc, argv);

    oixloc = findexe("oix");
    if (!oixloc)
        quit("Couldn't find oix on PATH");
    oixloc = intern(canonicalize(oixloc));

    if (argc == 1)
        long_usage();

    /*
     * Process options. NOTE: Keep Usage definition in sync with getopt() call.
     */
#define Usage "[-cBfmnsELIZTV] [-o ofile] [-v i] [-l i] [-O i]"	/* omit -e from doc */
    while ((c = oi_getopt(argc,argv, "cBfmno:sv:ELIZTVl:O:")) != EOF) {
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

            case 'I':			/* -I: dump intermediate code */
                Iflag = 1;
                break;

            case 'V':
                printf("%s\n", Version);
                exit(0);
                break;

            case 'c':			/* -c: compile only (no linking) */
                nolink = 1;
                break;

            case 'f':			/* -f : full invocation */
                strinv = 1;		
                break;

            case 'm':			/* -m: preprocess using m4(1) [UNIX] */
                m4pre = 1;
                break;

            case 'o':			/* -o file: name output file */
                ofile = oi_optarg;
                break;

            case 's':			/* -s: suppress informative messages */
                verbose = 0;
                break;

            case 'v':			/* -v n: set verbosity level */
                if (sscanf(oi_optarg, "%d%c", &verbose, &ch) != 1)
                    quit("bad operand to -v option: %s",oi_optarg);
                break;

            case 'l':			/* -l n: source location store level */
                if (sscanf(oi_optarg, "%d%c", &loclevel, &ch) != 1)
                    quit("bad operand to -l option: %s",oi_optarg);
                break;

            case 'O':			/* -O n: optimisation level */
                if (sscanf(oi_optarg, "%d%c", &Olevel, &ch) != 1)
                    quit("bad operand to -O option: %s",oi_optarg);
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
    while (oi_optind < argc)  {
        if (strcmp(argv[oi_optind],"-x") == 0)	/* stop at -x */
            break;
        else if (strcmp(argv[oi_optind],"-") == 0) {
            add_trans_file("stdin");      /* "-" means standard input */
            add_link_file("stdin.u");
        }
        else {
            fp = fparse(argv[oi_optind]);		/* parse file name */
            if (*fp->ext == '\0' || smatch(fp->ext, SourceSuffix)) {
                char *t;
                add_trans_file(makename(0, argv[oi_optind],  SourceSuffix));
                t = makename(0, argv[oi_optind], USuffix);
                add_link_file(t);
            }
            else if (smatch(fp->ext, USuffix))
                add_link_file(makename(0, argv[oi_optind], USuffix));
            else
                quit("bad argument %s", argv[oi_optind]);
        }
        oi_optind++;
    }

    if (!link_files)
        usage();				/* error -- no files named */

    /*
     * Translate .icn files to make .u files.
     */
    if (trans_files) {
        if (!pponly)
            report("Translating:");
        trans(trans_files, &errors, &warnings);
        report_errors(1);
        if (errors > 0)	{		/* exit if errors seen */
            remove_intermediate_files();
            exit(EXIT_FAILURE);
        }
    }

    /*
     * Link .u files to make an executable.
     */
    if (nolink) {			/* exit if no linking wanted */
        exit(EXIT_SUCCESS);
    }

#if MSWIN32
    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
       ofile = intern(makename(0,link_files->name, ".exe"));
    } else {				/* add extension in necessary */
        fp = fparse(ofile);
        if (*fp->ext == '\0') /* if no ext given */
	   ofile = intern(makename(0,ofile, ".exe"));
    }
#else                                   /* MSWIN32 */

    if (ofile == NULL)  {		/* if no -o file, synthesize a name */
        ofile = intern(makename(0,link_files->name,""));
    }

#endif					/* MSWIN32 */

    report("Linking:");
    ilink(link_files, &errors, &warnings);	/* link .u files to make icode file */

    if (!errors) {
#if HAVE_LIBZ
        /*
         * Optional gz compression
         */
        if (Zflag)
            file_comp();
#endif					/* HAVE_LIBZ */
        /*
         * Optional bundling of iconx executable in output
         */
        if (Bflag)
            bundle_iconx();
    }

    /*
     * Finish by removing intermediate files.
     *  Execute the linked program if so requested and if there were no errors.
     */

    remove_intermediate_files();

    report_errors(0);

    if (errors > 0) {			/* exit if linker errors seen */
        remove(ofile);
        exit(EXIT_FAILURE);
    }

    if (oi_optind < argc)  {
        report("Executing:");
        execute(argv + oi_optind + 1);
    }

    exit(EXIT_SUCCESS);
}

/*
 * execute - execute iconx to run the icon program
 */
static void execute(char **args)
{
#if MSWIN32
   int n, len;
   char *cmd, **p, *cp;
   STARTUPINFOA siStartupInfo; 
   PROCESS_INFORMATION piProcessInfo; 

   memset(&siStartupInfo, 0, sizeof(siStartupInfo)); 
   memset(&piProcessInfo, 0, sizeof(piProcessInfo)); 
   siStartupInfo.cb = sizeof(siStartupInfo); 

   len = strlen(ofile) + 4;
   for (p = args; *p; p++)
      len += strlen(*p) + 4;

   cp = cmd = safe_alloc(len + 1);

   cp += sprintf(cmd, "\"%s\" ", ofile);
   for (p = args; *p; p++)
      cp += sprintf(cp, "\"%s\" ", *p);

   /*printf("cmd=%s\n",cmd);fflush(stdout);*/
   if (!CreateProcess(oixloc, cmd, NULL, NULL, FALSE, 0, NULL, NULL, 
		      &siStartupInfo, &piProcessInfo)) {
      quit("CreateProcess failed GetLastError=%d\n",GetLastError());
   }
   WaitForSingleObject(piProcessInfo.hProcess, INFINITE);
   CloseHandle( piProcessInfo.hProcess );
   CloseHandle( piProcessInfo.hThread );
#else
   int n;
   char **argv, **p;

   for (n = 0; args[n] != NULL; n++)	/* count arguments */
      ;
   p = argv = safe_alloc((n + 5) * sizeof(char *));
   *p++ = ofile;			/* pass icode file name */

   while ((*p++ = *args++) != 0)      /* copy args into argument vector */
      ;

   *p = NULL;
   execv(ofile, argv);
   quit("could not execute %s", ofile);
#endif
}

static void bundle_iconx()
{
    FILE *f, *f2;
    int c;
    char *tmp = intern(makename(0, ofile, ".tmp"));
    rename(ofile, tmp);

    if (!(f = fopen(oixloc, ReadBinary)))
        quit("Tried to open oix to build .exe, but couldn't");

    if (!(f2 = fopen(ofile, WriteBinary)))
        quit("Couldn't reopen output file %s", ofile);

    while ((c = fgetc(f)) != EOF)
        fputc(c, f2);

    fclose(f);
    if (!(f = fopen(tmp, ReadBinary))) 
        quit("tried to read %s to append to exe, but couldn't",tmp);

    while ((c = fgetc(f)) != EOF)
        fputc(c, f2);

    fclose(f);

    fclose(f2);
    setexe(ofile);
    unlink(tmp);
}

#if HAVE_LIBZ

static void file_comp() 
{
    gzFile f; 
    FILE *finput, *foutput;
    struct header *hdr;
    int n, c;
    char buf[200], *tmp = intern(makename(0, ofile, ".tmp"));
  
    hdr = safe_alloc(sizeof(struct header));
    
    /* use fopen() to open the target file then read the header and add "z" to the hdr->config. */
    
    if (!(finput = fopen(ofile, ReadBinary)))
        quit("Can't open the file to compress: %s",ofile);
    
    if (!(foutput = fopen(tmp, WriteBinary)))
        quit("Can't open the temp compression file: %s",tmp);

    n = strlen(IcodeDelim);
    for (;;) {
        if (fgets(buf, sizeof(buf) - 1, finput) == NULL)
            quit("Compression - Reading Error: Check if the file is executable Icon");
        fputs(buf, foutput);
        if (strncmp(buf, IcodeDelim, n) == 0)
            break;
    }

    if (fread((char *)hdr, sizeof(char), sizeof(*hdr), finput) != sizeof(*hdr))
        quit("gz compressor can't read the header, compression");
    
    /* Turn on the Z flag */
    strcat((char *)hdr->config,"Z");

    /* write the modified header into a new file */
    
    if (fwrite((char *)hdr, sizeof(char), sizeof(*hdr), foutput) != sizeof(*hdr))
        quit("failed to write header to temp compression file");
    
    /* close the new file */
  
    fclose(foutput);
    
    /* use gzopen() to open the new file */
    
    if (!(f = gzopen(tmp, AppendBinary)))
        quit("Compression Error: can not open output file %s", tmp);
    
    /*
     * read the rest of the target file and write the compressed data into
     * the new file
     */
    
    while((c = fgetc(finput)) != EOF) {
        gzputc(f, c);
        if (ferror(finput))
            quit("Compression - Error occurs while reading!");
    }
   
    /* close both files */
    fclose(finput);
    gzclose(f);
    
    if (unlink(ofile))
        quit("can't remove old %s, compressed version left in %s",
              ofile, tmp);

    if (rename(tmp, ofile))
        quit("can't rename compressed %s back to %s", tmp, ofile);

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
   fprintf(stderr,"run %s with no options or arguments for full option details\n", progname);
   exit(EXIT_FAILURE);
}

static void long_usage()
{
    fprintf(stderr,"-n      Only translate a .icn to a .u file if it is out-of-date\n"
                   "-B      Bundle the oix executable in the output\n"
                   "-m      Preprocess using m4\n"
                   "-Z      Use zlib compression on the icode file\n"
                   "-c      Stop after producing ucode files.\n"
                   "-f      Enable full string invocation by preserving unreferenced globals during linking\n"
                   "        (equivalent to 'invocable all' in a source file).\n"
                   "-o file Write the executable program to the specified file.\n"
                   "-s      Suppress informative messages during translation and linking (equivalent to\n"
                   "        '-v 0')\n"
                   "-O i    Optimization level during linking. 1 means do optimizations, 0 means don't\n"
                   "        (default is 1).\n"
                   "-v i    Set verbosity level of informative messages to i.\n"
                   "-l i    Configure the amount of source location info to store in the icode. 0 means none,\n"
                   "        1 means store location info for procedure call and stack tracebacks (the default,\n"
                   "        1, adds about 10%% more space compared to option 0) and 2 means additionally\n"
                   "        store location info of all symbols (costs another 5%% of space).\n"
                   "-L      During linking, output a '.ux' file giving information about the icode file.\n"
                   "        This is only useful if you are interested in the virtual machine instructions used\n"
                   "        by oix.\n"
                   "-I      During code generation, output a dump of the intermediate code, both in its raw\n"
                   "        and optimized state.  This is only useful if you are interested in the internals\n"
                   "        of oit.\n"
                   "-E      Direct the results of preprocessing to standard output and inhibit further\n"
                   "        processing.\n"
                   "-V      Announce version and configuration information on standard error.\n");
    exit(EXIT_SUCCESS);
}

/*
 * quitf - immediate exit with message format and argument
 */
void quit(char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr,"%s: ",progname);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    remove_intermediate_files();
    if (ofile)
        remove(ofile);			/* remove bad icode file */
    exit(EXIT_FAILURE);
}

#if UNIX
void begin_link(FILE *f, char *fname, int line)
{
    char *s;
    if (!is_flowterm_tty(f))
        return;
    fputs("\x1b[!\"file://", f);
    if ((s = get_hostname()))
        fputs(s, f);
    for (s = fname; *s; ++s) {
        if (strchr(URL_UNRESERVED, *s))
            fputc(*s, f);
        else
            fprintf(f, "%%%02x", *s & 0xff);
    }
    if (line)
        fprintf(f, "?line=%d", line);
    fputs("\"L", f);
}

void end_link(FILE *f)
{
    if (is_flowterm_tty(f))
        fputs("\x1b[!L", f);
}
#else
void begin_link(FILE *f, char *fname, int line) {}
void end_link(FILE *f) {}
#endif

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
    empty_string = spec_str("");
    init_string = spec_str("init");
    all_string = spec_str("all");
    lang_string = spec_str("lang");
    stdin_string = spec_str("stdin");
    package_marker_string = spec_str(">package");
    ascii_string = spec_str("ASCII");
    utf8_string = spec_str("UTF-8");
    iso_8859_1_string = spec_str("ISO-8859-1");
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

    if (!ppinit(argv[1],0))
        quit("cannot open %s", argv[1]);

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

