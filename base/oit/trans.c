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
#include "tlex.h"
#include "ipp.h"

/*
 * Prototypes.
 */

static	void	trans1		(char *filename, struct pp_def *pp_defs);

int tfatals;			/* number of fatal errors in file */
int twarnings;			/* number of warning errors in file */
int in_line;			/* current input line number */
int incol;			/* current input column number */
int peekc;			/* one-character look ahead */

static int afatals;		/* total number of fatal errors */
static int awarnings;		/* total number of warning errors */

int yyparse(void);

/*
 * tfatal produces a translator error message.  The location of the
 * error is found in tok_loc.
 */
void tfatal(char *fmt, ...)
{
    va_list argp;
    if (File(&tok_loc)) {
        begin_link(stderr, File(&tok_loc), Line(&tok_loc));
        fprintf(stderr, "File %s; ", abbreviate(File(&tok_loc)));
    }
    if (Line(&tok_loc))
        fprintf(stderr, "Line %d", Line(&tok_loc));
    if (File(&tok_loc))
        end_link(stderr);
    if (Line(&tok_loc))
        fputs(" # ", stderr);

    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    tfatals++;
}

/*
 * tfatal_at produces the error message given, and associates it with
 * source location of node.
 */
void tfatal_at(struct node *n, char *fmt, ...)
{
    va_list argp;
    if (n) {
        if (File(n)) {
            begin_link(stderr, File(n), Line(n));
            fprintf(stderr, "File %s; ", abbreviate(File(n)));
        }
        if (Line(n))
            fprintf(stderr, "Line %d", Line(n));
        if (File(n))
            end_link(stderr);
        if (Line(n))
            fputs(" # ", stderr);
    }
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr, "\n");
    va_end(argp);
    tfatals++;
}

/*
 * twarn_at produces the warning message given, and associates it with
 * source location of node.
 */
void twarn_at(struct node *n, char *fmt, ...)
{
    va_list argp;
    if (n) {
        if (File(n)) {
            begin_link(stderr, File(n), Line(n));
            fprintf(stderr, "File %s; ", abbreviate(File(n)));
        }
        if (Line(n))
            fprintf(stderr, "Line %d", Line(n));
        if (File(n))
            end_link(stderr);
        if (Line(n))
            fputs(" # ", stderr);
    }
    fprintf(stderr, "Warning: ");
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr, "\n");
    va_end(argp);
    twarnings++;
}

/*
 * translate the parameters contained in the list, returning an error/warning count
 */
void trans(struct file_param *trans_files, struct pp_def *pp_defs, int *fatals, int *warnings)
{
    struct file_param *p;

    tminit();

    awarnings = afatals = 0;

    for (p = trans_files; p; p = p->next) {
        trans1(p->name, pp_defs);	/* translate each file in turn */
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
    static struct str_buf sb;
    char *d = strrchr(s, '.'), *t = s;
    if (!d)
        return;
    zero_sbuf(&sb);
    while (t != d)
        AppChar(sb, *t++);
    t = str_install(&sb);
    if (t == package_name || t == default_string || lookup_import(t))
        return;
    tfatal_at(pos, "Reference to unimported package: '%s'", t);
}

static void check_dottedidents(void)
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

static void check_unused(void)
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
static void trans1(char *filename, struct pp_def *pp_defs)
{
    char *outname;              /* output file name */

    twarnings = tfatals = 0;    /* reset error/warning counts */
    in_line = 1;                /* start with line 1, column 0 */
    incol = 0;
    peekc = 0;                  /* clear character lookahead */

    outname = intern(makename(0, filename, USuffix));

    report("%s:", filename);

    if (neweronly && !newer_than(filename, outname)) {
        report("  up-to-date");
        return;
    }

    if (!ppinit(filename, m4pre))
        equit("cannot open %s",filename);

    while (pp_defs) {
        ppdef(pp_defs->key, pp_defs->value);
        pp_defs = pp_defs->next;
    }

    if (pponly) {
        ppecho();
        return;
    }

    if (filename == stdin_string)
        tok_loc.n_file = filename;
    else
        tok_loc.n_file = intern(canonicalize(filename));

    in_line = 1;

    yyparse();				/* Parse the input */

    if (!tfatals) {
        check_unused();
        check_dottedidents();

        ucodefile = fopen(outname, WriteBinary);
        if (!ucodefile)
            equit("cannot create %s", outname);
        output_code();
        fflush(ucodefile);
        if (ferror(ucodefile) != 0)
            equit("failed to write to ucode file %s", outname);
        fclose(ucodefile);
        if (tfatals)
            /*
             * output_code detected a tfatal error (eg break out of
             * loop) - delete the ucode file.
             */
            remove(outname);
        else if (package_name)
            /*
             * The file is in a package; update the package database
             * if needed, and the ucode file will be kept regardless,
             * even if -c wasn't given.  This helps to avoid having an
             * inconsistent package database, ie with an entry in the
             * packages.txt file with no corresponding .u file.
             */
            ensure_file_in_package(filename, package_name);
        else if (!nolink)
            /*
             * The file is not in a package and the -c option wasn't
             * given, so the ucode file will be removed.
             */
            add_remove_file(outname);
    }

    tmfilefree();
}

