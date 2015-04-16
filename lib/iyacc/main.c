#include "defs.h"

char dflag;
char lflag;
char rflag;
char tflag;
char vflag;
char jflag;/*rwj -- for Java!*/
char iflag=1;
char threadflag;/*rwj -- for Java!*/
char *java_semantic_type;/*rwj -- for Java!*/
char *package_name = NULL;

char *symbol_prefix;
char *file_prefix = "y";
char *java_class_name = "YY";/*rwj*/
char *java_extend_name = "Thread";/*rwj*/
char *myname = "yacc";

int lineno;
int outline;

char *action_file_name;
char *code_file_name;
char *defines_file_name;
char *input_file_name = "";
char *output_file_name;
char *text_file_name;
char *union_file_name;
char *verbose_file_name;

FILE *action_file;	/*  a temp file, used to save actions associated    */
			/*  with rules until the parser is written	    */
FILE *code_file;	/*  y.code.c (used when the -r option is specified) */
FILE *defines_file;	/*  y.tab.h					    */
FILE *input_file;	/*  the input file				    */
FILE *output_file;	/*  y.tab.c					    */
FILE *text_file;	/*  a temp file, used to save text until all	    */
			/*  symbols have been defined			    */
FILE *union_file;	/*  a temp file, used to save the union		    */
			/*  definition until all symbol have been	    */
			/*  defined					    */
FILE *verbose_file;	/*  y.output					    */

int nitems;
int nrules;
int nsyms;
int ntokens;
int nvars;

int actions[1024];
int nactions;

int   start_symbol;
char  **symbol_name;
short *symbol_value;
short *symbol_prec;
char  *symbol_assoc;

short *ritem;
short *rlhs;
short *rrhs;
short *rprec;
char  *rassoc;
short **derives;
char *nullable;


void done(int k)
{
    if (action_file) fclose(action_file);
    if (text_file) fclose(text_file);
    if (union_file) fclose(union_file);

    if (action_file_name) unlink(action_file_name);
    if (text_file_name) unlink(text_file_name);
    if (union_file_name)  unlink(union_file_name);

    exit(k);
}


void onintr(int flag)
{
    done(1);
}


void set_signals(void)
{
#ifdef SIGINT
    if (signal(SIGINT, SIG_IGN) != SIG_IGN)
	signal(SIGINT, onintr);
#endif
#ifdef SIGTERM
    if (signal(SIGTERM, SIG_IGN) != SIG_IGN)
	signal(SIGTERM, onintr);
#endif
#ifdef SIGHUP
    if (signal(SIGHUP, SIG_IGN) != SIG_IGN)
	signal(SIGHUP, onintr);
#endif
}


void usage(void)
{
    fprintf(stderr,
     "usage:\n %s [-dlrtvic] [-b file_prefix]  [-p symbol_prefix]  [-k object icon package name]  [-f class_name] filename\n", myname);
    
    exit(1);
}


void getargs(int argc,char **argv)
{
    register int i;
    register char *s;

    if (argc > 0) myname = argv[0];
    for (i = 1; i < argc; ++i)
    {
	s = argv[i];
	if (*s != '-') break;
	switch (*++s)
	{
	case '\0':
	    input_file = stdin;
	    if (i + 1 < argc) usage();
	    return;

	case '-':
	    ++i;
	    goto no_more_options;

	case 'b':
	    if (*++s)
		 file_prefix = s;
	    else if (++i < argc)
		file_prefix = argv[i];
	    else
		usage();
	    continue;

	case 'd':
	    dflag = 1;
	    break;

	case 'l':
	    lflag = 1;
	    break;

	case 'p':
	    if (*++s)
		symbol_prefix = s;
	    else if (++i < argc)
		symbol_prefix = argv[i];
	    else
		usage();
	    continue;

	case 'k':
	    if (*++s)
		package_name = s;
	    else if (++i < argc)
		package_name = argv[i];
	    else
		usage();
	    continue;

	case 'r':
	    rflag = 1;
	    break;

	case 't':
	    tflag = 1;
	    break;

	case 'v':
	    vflag = 1;
	    break;

	case 'j':     /* rwj -- for Java!  */
	    jflag = 1;
            iflag = 0;
	    break;

	case 'i':
	    iflag = 1;
            jflag = 0;
	    break;

	case 'c':
	    iflag = 0;
            jflag = 0;
	    break;

	case 's':     /* rwj -- for Java!  */
	    if (*++s)
		   java_semantic_type = s;
	    else if (++i < argc)
		   java_semantic_type = argv[i];
	    else
		   usage();
	    continue;

	case 'f':     /* rwj -- for Java!  */
	    if (*++s)
		   java_class_name = s;
	    else if (++i < argc)
		   java_class_name = argv[i];
	    else
		   usage();
	    continue;

	case 'x':     /* rwj -- for Java!  */
	    if (*++s)
		   java_extend_name = s;
	    else if (++i < argc)
		   java_extend_name = argv[i];
	    else
		   usage();
	    continue;

	default:
	    usage();
	}

	for (;;)
	{
	    switch (*++s)
	    {
	    case '\0':
		goto end_of_option;

	    case 'd':
		dflag = 1;
		break;

	    case 'l':
		lflag = 1;
		break;

	    case 'r':
		rflag = 1;
		break;

	    case 't':
		tflag = 1;
		break;

	    case 'v':
		vflag = 1;
		break;

	    case 'j':        /* rwj -- for java*/
		jflag = 1;
		break;

	    case 'i': 
		iflag = 1;
		break;

     default:
		usage();
	    }
	}
end_of_option:;
    }

no_more_options:;
    if (i + 1 != argc) usage();
    input_file_name = argv[i];
}


char *allocate(unsigned n)
{
    register char *p;

    p = NULL;
    if (n)
    {
	p = CALLOC(1, n);
	if (!p) no_space();
    }
    return (p);
}

/*
 * salloc - allocate and initialize string
 */
static char *salloc(char *s)
{
    char *s1;
    s1 = (char *)MALLOC(strlen(s) + 1);
    return strcpy(s1, s);
}

void create_file_names(void)
{
    int len;
    int action_file_fd;
    int text_file_fd;
    int union_file_fd;

    action_file_name = salloc(maketemp("yacc.aXXXXXX"));
    text_file_name = salloc(maketemp("yacc.tXXXXXX"));
    union_file_name = salloc(maketemp("yacc.uXXXXXX"));
    if ((action_file_fd = mkstemp(action_file_name)) < 0 ||
	(text_file_fd = mkstemp(text_file_name)) < 0 ||
	(union_file_fd = mkstemp(union_file_name)) < 0) {
      fprintf(stderr, "Couldn't mkstemp\n");
      exit(1);
    }
    close(action_file_fd);
    close(text_file_fd);
    close(union_file_fd);

    if (jflag)/*rwj*/
      {
      len = strlen(java_class_name);

      output_file_name = MALLOC(len + 6);/*for '.java\0' */
      if (output_file_name == 0) no_space();
      strcpy(output_file_name, java_class_name);
      strcpy(output_file_name + len, JAVA_OUTPUT_SUFFIX);
      }

    else if (iflag)
      {
      len = strcspn(input_file_name, ".");

      output_file_name = MALLOC(len + 5);/*for '.icn\0' */
      if (output_file_name == 0) no_space();
      strncpy(output_file_name, input_file_name, len);
      strcpy(output_file_name + len, ICON_OUTPUT_SUFFIX);
      }

    else
      {
      len = strlen(file_prefix);

      output_file_name = MALLOC(len + 7);
      if (output_file_name == 0) no_space();
      strcpy(output_file_name, file_prefix);
      strcpy(output_file_name + len, OUTPUT_SUFFIX);
      }

    if (rflag)
    {
	code_file_name = MALLOC(len + 8);
	if (code_file_name == 0)
	    no_space();
	strcpy(code_file_name, file_prefix);
	strcpy(code_file_name + len, CODE_SUFFIX);
    }
    else
	code_file_name = output_file_name;

    if (dflag) 
    {
        if (iflag)
        {
            defines_file_name = MALLOC(len + 11);
            if (defines_file_name == 0)
                no_space();
            len = strcspn(input_file_name, ".");
            strncpy(defines_file_name, input_file_name, len);
            strcpy(defines_file_name + len, "_tab" ICON_OUTPUT_SUFFIX);
        }
	else
        {
            defines_file_name = MALLOC(len + 7);
            if (defines_file_name == 0)
                no_space();
            strcpy(defines_file_name, file_prefix);
            strcpy(defines_file_name + len, DEFINES_SUFFIX);
        }
    }

    if (vflag)
    {
	verbose_file_name = MALLOC(len + 8);
	if (verbose_file_name == 0)
	    no_space();
	strcpy(verbose_file_name, file_prefix);
	strcpy(verbose_file_name + len, VERBOSE_SUFFIX);
    }
}


void open_files(void)
{
    create_file_names();

    if (input_file == 0)
    {
	input_file = fopen(input_file_name, "r");
	if (input_file == 0)
	    open_error(input_file_name);
    }

    action_file = fopen(action_file_name, "w");
    if (action_file == 0)
	open_error(action_file_name);

    text_file = fopen(text_file_name, "w");
    if (text_file == 0)
	open_error(text_file_name);

    if (vflag)
    {
	verbose_file = fopen(verbose_file_name, "w");
	if (verbose_file == 0)
	    open_error(verbose_file_name);
    }

    if (dflag)
    {
	defines_file = fopen(defines_file_name, "w");
	if (defines_file == 0)
	    open_error(defines_file_name);
	union_file = fopen(union_file_name, "w");
	if (union_file ==  0)
	    open_error(union_file_name);
    }

    output_file = fopen(output_file_name, "w");
    if (output_file == 0)
	open_error(output_file_name);

    if (rflag)
    {
	code_file = fopen(code_file_name, "w");
	if (code_file == 0)
	    open_error(code_file_name);
    }
    else
	code_file = output_file;
}


int main(int argc,char **argv)
{
    set_signals();
    getargs(argc, argv);
    if (iflag) {
        outline = -1;
        lineno  = -1;
    }
    open_files();
    reader();
    lr0();
    lalr();
    make_parser();
    verbose();
    output();
    done(0);
    /*NOTREACHED*/
    return 1;
}
