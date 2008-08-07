#include "rtt.h"

/*#include "../h/filepat.h"		?* added for filepat change */

/*
 * prototypes for static functions.
 */
static void add_tdef (char *name);

char *refpath = 0;

/*
 * The following code is operating-system dependent [@rttmain.02].
 * The relative path to grttin.h and rt.h depends on whether they are
 *  interpreted as relative to where rtt.exe is or where rtt.exe is
 *  invoked.
 */

#if PORT
   /* something is needed */
Deliberate Syntax Error
#endif					/* PORT */

#define GRTTIN_H "grttin.h"
#define RT_H "rt.h"

/*
 * End of operating-system specific code.
 */

static char *ostr = "ECPD:I:U:d:cir:st:h:";

static char *options =
   "[-E] [-C] [-P] [-Dname[=[text]]] [-Uname] [-Ipath] [-dfile]\n    \
[-rpath] [-tname] [-x] [files]";

/*
 *  Note: rtt presently does not process system include files. If this
 *   is needed, it may be necessary to add other options that set
 *   manifest constants in such include files.  See pmain.c for the
 *   stand-alone preprocessor for examples of what's needed.
 */

char *progname = "rtt";
FILE *out_file;
char *inclname;
int def_fnd;


int enable_out = 0;

static FILE *curlst;
static char *cur_src;

extern int line_cntrl;

/*
 * tdefnm is used to construct a list of identifiers that
 *  must be treated by rtt as typedef names.
 */
struct tdefnm {
   char *name;
   struct tdefnm *next;
};

static char *dbname = "rt.db";
static int pp_only = 0;
static char *opt_lst;
static char **opt_args;
static char *in_header;
static char *xin_header;
static struct tdefnm *tdefnm_lst = NULL;

/*
 * getopt() variables
 */
extern int optind;		/* index into parent argv vector */
extern int optopt;		/* character checked for validity */
extern char *optarg;		/* argument associated with option */


int main(argc, argv)
    int argc;
    char **argv;
{
    int c;
    int nopts;
    struct fileparts *fp;

    /*
     * Initialize the string table and indicate that File must be treated
     *  as a typedef name.
     */
    init_str();
    add_tdef("FILE");

    /*
     * By default, the spelling of white space in unimportant (it can
     *  only be significant with the -E option) and #line directives
     *  are required in the output.
     */
    whsp_image = NoSpelling;
    line_cntrl = 1;

    /*
     * opt_lst and opt_args are the options and corresponding arguments
     *  that are passed along to the preprocessor initialization routine.
     *  Their number is at most the number of arguments to rtt.
     */
    opt_lst = (char *)alloc((unsigned)argc);
    opt_args = (char **)alloc((unsigned)(sizeof (char *)) * argc);
    nopts = 0;

    /*
     * Process options.
     */
    while ((c = getopt(argc, argv, ostr)) != EOF)
        switch (c) {
            case 'E': /* run preprocessor only */
                pp_only = 1;
                if (whsp_image == NoSpelling)
                    whsp_image = NoComment;
                break;
            case 'C':  /* retain spelling of white space, only effective with -E */
                whsp_image = FullImage;
                break;
            case 'P': /* do not produce #line directives in output */
                line_cntrl = 0;
                break;
            case 'd': /* -d name: name of data base */
                dbname = optarg;
                break;
            case 'r':  /* -r path: location of include files */
                refpath = optarg;
                break;
            case 'h':  /* -h path: location of initialization header */
                xin_header = optarg;
                break;
            case 't':  /* -t ident : treat ident as a typedef name */
                add_tdef(optarg);
                break;
            case 'D':  /* define preprocessor symbol */
            case 'I':  /* path to search for preprocessor includes */
            case 'U':  /* undefine preprocessor symbol */

                /*
                 * Save these options for the preprocessor initialization routine.
                 */
                opt_lst[nopts] = c;
                opt_args[nopts] = optarg;
                ++nopts;
                break;
            default:
                show_usage();
        }

    if (!refpath)
        refpath = salloc(relfile(argv[0], "/../../base/h/"));

    in_header = alloc(strlen(refpath) + strlen(GRTTIN_H) + 1);
    strcpy(in_header, refpath);
    strcat(in_header, GRTTIN_H);
    normalize(in_header);

    inclname = alloc(strlen(refpath) + strlen(RT_H) + 1);
    strcpy(inclname, refpath);
    strcat(inclname, RT_H);
    normalize(inclname);

    opt_lst[nopts] = '\0';

    /*
     * At least one file name must be given on the command line.
     */
    if (optind == argc)
        show_usage();

    /*
     * Unless the input is only being preprocessed, set up the in-memory data
     *  base (possibly loading it from a file).
     */
    if (!pp_only) {
        fp = fparse(dbname);
        if (*fp->ext == '\0')
            dbname = salloc(makename(SourceDir, dbname, DBSuffix));
        else if (!smatch(fp->ext, DBSuffix))
            err2("bad data base name:", dbname);
        loaddb(dbname);
    }

    /*
     * Scan file name arguments, and translate the files.
     */
    while (optind < argc)  {

#if PatternMatch
        FINDDATA_T fd;

        if (!FINDFIRST(argv[optind], &fd)) {
            fprintf(stderr,"File %s: no match\n", argv[optind]);
            fflush(stderr);
            exit(EXIT_FAILURE);
        }
        do {
            argv[optind] = FILENAME(&fd);
#endif					/* PatternMatch */
            trans(argv[optind]);
#if PatternMatch
        } while (FINDNEXT(&fd));
        FINDCLOSE(&fd);
#endif					/* PatternMatch */
        optind++;
    }


    return EXIT_SUCCESS;
}

/*
 * trans - translate a source file.
 */
void trans(src_file)
    char *src_file;
{
    char *cname;
    struct fileparts *fp;
    struct tdefnm *td;

    cur_src = src_file;

    /*
     * Read standard header file for preprocessor directives and
     * typedefs, but don't write anything to output.
     */
    enable_out = 0;
    init_preproc(in_header, opt_lst, opt_args);
    if (xin_header)
        source(xin_header);
    init_sym();
    for (td = tdefnm_lst; td != NULL; td = td->next)
        sym_add(TypeDefName, td->name, OtherDcl, 1);
    init_lex();
    yyparse();

    enable_out = 1;

    /*
     * Make sure we have a .r file or standard input.
     */
    if (strcmp(cur_src, "-") == 0) {
        source("-"); /* tell preprocessor to read standard input */
        cname = salloc(makename(TargetDir, "stdin", CSuffix));
    }
    else {
        fp = fparse(cur_src);
        if (*fp->ext == '\0')
            cur_src = salloc(makename(SourceDir, cur_src, RttSuffix));
        else if (!smatch(fp->ext, RttSuffix))
            err2("unknown file suffix ", cur_src);
        cur_src = spec_str(cur_src);

        source(cur_src);  /* tell preprocessor to read source file */
        cname = salloc(makename(TargetDir, cur_src, CSuffix));
    }

    if (pp_only)
        output(stdout); /* invoke standard preprocessor output routine */
    else {
        /*
         * For the compiler, non-RTL code is put in a file whose name
         *  is derived from input file name. The flag def_fnd indicates
         *  if anything interesting is put in the file.
         */
        def_fnd = 0;
        if ((out_file = fopen(cname, "w")) == NULL)
            err2("cannot open output file ", cname);
        else
            addrmlst(cname, out_file);
        prologue(); /* output standard comments and preprocessor directives */

        yyparse();  /* translate the input */

        fprintf(out_file, "\n");

        if (rmlst_empty_p() == 0) {
            if (fclose(out_file) != 0)
                err2("cannot close ", cname);
            else	/* can't close it again if we remove it to due an error */
                markrmlst(out_file);
        }
    }
}

/*
 * add_tdef - add identifier to list of typedef names.
 */
static void add_tdef(name)
    char *name;
{
    struct tdefnm *td;

    td = NewStruct(tdefnm);
    td->name = spec_str(name);
    td->next = tdefnm_lst;
    tdefnm_lst = td;
}

/*
 * Add name of file to the output list, and if it contains "interesting"
 *  code, add it to the dependency list in the data base.
 */
void put_c_fl(fname, keep)
    char *fname;
    int keep;
{
    struct fileparts *fp;

    fp = fparse(fname);

    fprintf(curlst, "%s\n", fp->name);
    if (keep)
        add_dpnd(src_lkup(cur_src), fname);
}

/*
 * Print an error message if called incorrectly.
 */
void show_usage()
{
    fprintf(stderr, "usage: %s %s\n", progname, options);
    exit(EXIT_FAILURE);
}
