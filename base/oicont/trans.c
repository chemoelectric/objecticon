/*
 * trans.c - main control of the translation process.
 */

#include "icont.h"
#include "tsym.h"
#include "tree.h"
#include "ttoken.h"
#include "tmain.h"
#include "tmem.h"
#include "package.h"

/*
 * Prototypes.
 */

static	void	trans1		(char *filename);

int tfatals;			/* number of fatal errors in file */
int afatals;			/* total number of fatal errors */
int twarnings;			/* number of warning errors in file */
int awarnings;			/* total number of warning errors */
int nocode;			/* non-zero to suppress code generation */
int in_line;			/* current input line number */
int incol;			/* current input column number */
int peekc;			/* one-character look ahead */

int yyparse();

/*
 * tfatal produces a translator error message.  The location of the
 * error is found in tok_loc.
 */
void tfatal(char *fmt, ...)
{
    va_list argp;
    if (File(&tok_loc))
        fprintf(stderr, "File %s; ", abbreviate(File(&tok_loc)));
    fprintf(stderr, "Line %d # ", Line(&tok_loc));
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    tfatals++;
    nocode++;
}

/*
 * tfatal_at produces the error message given, and associates it with
 * source location of node.
 */
void tfatal_at(struct node *n, char *fmt, ...)
{
    va_list argp;
    if (n) {
        if (File(n))
            fprintf(stderr, "File %s; ", abbreviate(File(n)));
        fprintf(stderr, "Line %d # ", Line(n));
    }
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr, "\n");
    va_end(argp);
    tfatals++;
    nocode++;
}

/*
 * twarn_at produces the warning message given, and associates it with
 * source location of node.
 */
void twarn_at(struct node *n, char *fmt, ...)
{
    va_list argp;
    if (n) {
        if (File(n))
            fprintf(stderr, "File %s; ", abbreviate(File(n)));
        fprintf(stderr, "Line %d # ", Line(n));
    }
    fprintf(stderr, "Warning :");
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr, "\n");
    va_end(argp);
    twarnings++;
}

/*
 * tsyserr is called for fatal errors.  The message s is produced and the
 *  translator exits.
 */
void tsyserr(char *s)
{
    if (tok_loc.n_file)
        fprintf(stderr, "File %s; ", tok_loc.n_file);
    fprintf(stderr, "Line %d # %s\n", in_line, s);
    exit(EXIT_FAILURE);
}

/*
 * translate the parameters contained in the list, returning an error/warning count
 */
void trans(struct file_param *trans_files, int *fatals, int *warnings)
{
    struct file_param *p;

    tmalloc();			/* allocate memory for translation */

    awarnings = afatals = 0;

    for (p = trans_files; p; p = p->next) {
        trans1(p->name);	/* translate each file in turn */
        afatals += tfatals;
        awarnings += twarnings;
    }

    /*
     * Save any modifications to the package database.
     */
    save_package_db();

    tmfree();			/* free memory used for translation */

    *fatals = afatals;
    *warnings = awarnings;
}

static void check_dottedident(struct node *pos, char *s)
{
    char *d = rindex(s, '.'), *t = s;
    if (!d)
        return;
    zero_sbuf(&join_sbuf);
    while (t != d)
        AppChar(join_sbuf, *t++);
    t = str_install(&join_sbuf);
    if (t == package_name || t == default_string || lookup_import(t))
        return;
    twarn_at(pos, "Reference to unimported package: '%s'", t);
}

static void check_dottedidents()
{
    struct tgentry *gp;
    struct tinvocable *iv;
    for (gp = gfirst; gp; gp = gp->g_next) {
        if (gp->class) {
            struct tclass_super *cs;
            for (cs = gp->class->supers; cs; cs = cs->next)
                check_dottedident(cs->pos, cs->name);
        }
    }
    for (iv = tinvocables; iv; iv = iv->next)
        check_dottedident(iv->pos, iv->name);
}

static void check_unused()
{
    struct tlentry *l;
    for (curr_func = functions; curr_func; curr_func = curr_func->next) {
        for (l = curr_func->lfirst; l; l = l->l_next) {
            if ((l->l_flag & (F_Static | F_Dynamic)) && !l->seen) {
                if (curr_func->global)
                    twarn_at(l->pos,
                             "Unused local variable: '%s' in procedure %s", 
                             l->l_name, curr_func->global->g_name);
                else
                    twarn_at(l->pos,
                             "Unused local variable: '%s' in method %s.%s", 
                             l->l_name, 
                             curr_func->field->class->global->g_name,
                             curr_func->field->name);
            }
        }
    }
}

/*
 * translate one file.
 */
static void trans1(char *filename)
{
    char outname[MaxFileName];	/* buffer for constructing file name */

    twarnings = tfatals = 0;	/* reset error/warning counts */
    nocode = 0;			/* allow code generation */
    in_line = 1;			/* start with line 1, column 0 */
    incol = 0;
    peekc = 0;			/* clear character lookahead */

    if (!ppinit(filename,lpath,m4pre))
        quitf("cannot open %s",filename);

    if (strcmp(filename,"-") == 0) {
        filename = "stdin";
    }

    makename(outname, SourceDir, filename, USuffix);

    if (pponly) {
        ppecho();
        return;
    }

    if (neweronly && !newer_than(filename, outname)) {
        report("%s is up-to-date", filename);
        return;
    }

    report(filename);

    tok_loc.n_file = fullname(filename);
    in_line = 1;

    tminit();				/* Initialize data structures */
    yyparse();				/* Parse the input */

    if (!tfatals) {
        check_unused();
        check_dottedidents();

        ucodefile = fopen(outname, WriteBinary);
        if (!ucodefile)
            quitf("cannot create %s", outname);

        output_code();

        fclose(ucodefile);

        /*
         * Update the package database if needed.
         */
        if (package_name)
            ensure_file_in_package(filename, package_name);
    }

    tmfilefree();
}

