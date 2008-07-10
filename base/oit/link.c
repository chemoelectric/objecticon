/*
 * link.c -- linker main program that controls the linking process.
 */

#include "icont.h"
#include "link.h"
#include "lmem.h"
#include "tmain.h"
#include "lglob.h"
#include "resolve.h"
#include "lcode.h"

#include "../h/header.h"

/*
 * Prototype.
 */

static void check_unused_imports();


/*
 * The following code is operating-system dependent [@link.01].  Include
 *  system-dependent files and declarations.
 */

#if PORT
/* nothing to do */
Deliberate Syntax Error
#endif					/* PORT */

#if UNIX
#ifdef CRAY
#define word word_fubar
#include <sys/types.h>
#include <sys/stat.h>
#undef word
#else				/* CRAY */
#ifndef XWindows
#include <sys/types.h>
#endif				/* XWindows */
#include <sys/stat.h>
#endif				/* CRAY */
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

FILE *infile;                           /* input file (.u) */
FILE *outfile;                          /* interpreter code output file */

extern char *ofile;                     /* output file name */

#ifdef DeBugLinker
FILE *dbgfile;                          /* debug file */
static char *dbgname;                   /* debug file name */
#endif                                  /* DeBugLinker */

char *inname;                           /* input file name */

int lineno = 0;                         /* current source line number */
int lfatals = 0;                                /* number of errors encountered */
int lwarnings = 0;                      /* number of warnings encountered */

/*
 *  ilink - link a number of files, returning error and warning counts
 */
void ilink(struct file_param *link_files, char *outname, int *fatals, int *warnings)
{
    int i;
    struct lfile *lf;
    char *filename;			/* name of current input file */
    struct file_param *p;

    linit();				/* initialize memory structures */
    for (p = link_files; p; p = p->next) {
        struct loc l = {p->name, 0};
        alsolink(p->name, 0, &l);  /* make initial list of files */
    }

    /*
     * Phase I: load global information contained in .u files into
     *  data structures.
     *
     * The list of files to link is maintained as a queue with lfiles
     *  as the base.  lf moves along the list.  Each file is processed
     *  in turn by forming .u and .icn names from each file name, each
     *  of which ends in .u1.  The .u file is opened and globals is called
     *  to process it.  When the end of the list is reached, lf becomes
     *  NULL and the loop is terminated, completing phase I.  Note that
     *  link instructions in the .u file cause files to be added to list
     *  of files to link.
     */
    for (lf = lfiles; lf; lf = lf->next) {
        filename = lf->lf_name;
        inname = intern_using(&link_sbuf, makename(SourceDir, filename, USuffix));
        ucodefile = fopen(inname, ReadBinary);
        if (!ucodefile)
            quitf("cannot open %s",inname);
        readglob(lf);
        fclose(ucodefile);
    }

#ifdef DeBugLinker
    /*
     * Open the .ux file if debugging is on.
     */
    if (Dflag) {
        dbgname = intern_using(&link_sbuf, makename(TargetDir, lfiles->lf_name, ".ux"));
        dbgfile = fopen(dbgname, WriteText);
        if (dbgfile == NULL)
            quitf("cannot create %s", dbgname);
    }
#endif					/* DeBugLinker */

    /* Phase 1a - resolve invocables, superclass identifiers */
    if (!strinv)
        resolve_invocables();
    resolve_supers();
    compute_inheritance();
    if (lfatals > 0) {
        *warnings = lwarnings;
        *fatals = lfatals;
        return;
    }

    /* Resolve identifiers encountered in procedures and methods */
    resolve_locals();

    /* Phase II:  suppress unreferenced procs. */
    scanrefs();

    sort_global_table();
    build_fieldtable();

    /* Phase III: generate code. */

    /*
     * Open the output file.
     */
    outfile = fopen(outname, WriteBinary);

/*
 * The following code is operating-system dependent [@link.02].  Set
 *  untranslated mode if necessary.
 */

#if PORT
    /* probably nothing */
    Deliberate Syntax Error
#endif					/* PORT */

/*
 * End of operating-system specific code.
 */

    if (outfile == NULL) {		/* may exist, but can't open for "w" */
        ofile = NULL;			/* so don't delete if it's there */
        quitf("cannot create %s",outname);
    }

    /*
     * Write the bootstrap header to the output file.
     */

    /*
     * Write a short shell header terminated by \n\f\n\0.
     * Use magic "#!/bin/sh" to ensure that $0 is set when run via $PATH.
     * Pad header to a multiple of 8 characters.
     */
    {
        char script[2048];

#if MSWindows
        /*
         * The NT and Win95 direct execution batch file turns echoing off,
         * launches wiconx, attempts to terminate softly via noop.bat,
         * and terminates the hard way (by exiting the DOS shell) if that
         * fails, rather than fall through and start executing machine code
         * as if it were batch commands.
         */
        snprintf(script, sizeof(script),
                "@echo off\r\n%s %%0 %%1 %%2 %%3 %%4 %%5 %%6 %%7 %%8 %%9\r\n%s%s%s",
                iconxloc,
                "noop.bat\r\n@echo on\r\n",
                "pause missing noop.bat - press ^c or shell will exit\r\n",
                "exit\r\n" IcodeDelim "\r\n");

#endif					/* MSWindows */
#if UNIX
        /*
         *  Generate a shell header that searches for iconx in this order:
         *     a.  location specified by ICONX environment variable
         *         (if specified, this MUST work, else the script exits)
         *     b.  iconx in same directory as executing binary
         *     c.  location specified in script
         *         (as generated by icont or as patched later)
         *     d.  iconx in $PATH
         *
         *  The ugly ${1+"$@"} is a workaround for non-POSIX handling
         *  of "$@" by some shells in the absence of any arguments.
         *  Thanks to the Unix-haters handbook for this trick.
         */
        snprintf(script, sizeof(script),
                "%s\n%s%-72s\n%s\n\n%s\n%s\n%s\n%s%s%s\n\n%s",
                "#!/bin/sh",
                "OIXBIN=", iconxloc,
                "OIXLCL=`echo $0 | sed 's=[^/]*$=oix='`",
                "[ -n \"$OIX\" ] && exec \"$OIX\" $0 ${1+\"$@\"}",
                "[ -x $OIXLCL ] && exec $OIXLCL $0 ${1+\"$@\"}",
                "[ -x $OIXBIN ] && exec $OIXBIN $0 ${1+\"$@\"}",
                "exec ",
                "oix",
                " $0 ${1+\"$@\"}",
                IcodeDelim "\n");
#endif					/* UNIX */

        hdrsize = strlen(script);
        fwrite(script, hdrsize, 1, outfile);	/* write header */
    }

    for (i = sizeof(struct header); i--;)
        putc(0, outfile);
    fflush(outfile);
    if (ferror(outfile) != 0)
        quit("unable to write to icode file");

#ifdef DeBugLinker
    if (Dflag)
        dumpstate();
#endif					/* DeBugLinker */
    check_unused_imports();

    generate_code();

#ifdef DeBugLinker
    /*
     * Close the .ux file if debugging is on.
     */
    if (Dflag) {
        fclose(dbgfile);
    }
#endif

    fclose(outfile);
    lmfree();
    *warnings = lwarnings;
    *fatals = lfatals;
    if (lfatals == 0)
        setexe(outname);
}

char *function_name(struct lfunction *f)
{
    if (f->proc)
        return join_strs(&join_sbuf, 2, 
                         "procedure ", 
                         f->proc->name);
    else
        return join_strs(&join_sbuf, 4,
                         "method ",
                         f->method->class->global->name, 
                         ".",
                         f->method->name);
}

/*
 * lfatal - issue a fatal linker error message.
 */
void lfatal(struct loc *pos, char *fmt, ...)
{
    va_list argp;
    if (pos) {
        if (pos->file)
            fprintf(stderr, "%s: ", abbreviate(pos->file));
        if (pos->line)
            fprintf(stderr, "Line %d # :", pos->line);
    }
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    lfatals++;
}

/*
 * warn - issue a warning message.
 */
void lwarn(struct loc *pos, char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    if (pos) {
        if (pos->file)
            fprintf(stderr, "%s: ", abbreviate(pos->file));
        if (pos->line)
            fprintf(stderr, "Line %d # ", pos->line);
    }
    fprintf(stderr, "Warning :");
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    ++lwarnings;
}


/*
 * setexe - mark the output file as executable
 */

void setexe(char *fname)
{

/*
 * The following code is operating-system dependent [@link.03].  It changes the
 *  mode of executable file so that it can be executed directly.
 */

#if PORT
    /* something is needed */
    Deliberate Syntax Error
#endif					/* PORT */

#if MSWindows
    /*
     * can't be made executable
     */
#endif

#if MACINTOSH
#if MPW
    /* Nothing to do here -- file is set to type TEXT
       (so it can be executed as a script) in tmain.c.
    */
#endif				/* MPW */
#endif					/* MACINTOSH */

#if UNIX
    {
        struct stat stbuf;
        int u, r, m;
        /*
         * Set each of the three execute bits (owner,group,other) if allowed by
         *  the current umask and if the corresponding read bit is set; do not
         *  clear any bits already set.
         */
        umask(u = umask(0));		/* get and restore umask */
        if (stat(fname,&stbuf) == 0)  {	/* must first read existing mode */
            r = (stbuf.st_mode & 0444) >> 2;	/* get & position read bits */
            m = stbuf.st_mode | (r & ~u);		/* set execute bits */
            chmod(fname,m);		 /* change file mode */
        }
    }
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */
}

static void check_unused_imports()
{
    struct lfile *lf;
    struct fimport *fp;
    struct fimport_symbol *fis;
    for (lf = lfiles; lf; lf = lf->next) {
        for (fp = lf->imports; fp; fp = fp->next) {
            if (!fp->used)
                lwarn(&fp->pos, "Unused import: %s", fp->name);
            if (fp->qualified) {
                for (fis = fp->symbols; fis; fis = fis->next) {
                    if (!fis->used)
                        lwarn(&fis->pos, "Unused import symbol: %s", fis->name);
                }
            }
        }
    }
}

#ifdef DeBugLinker

static char *f_flag2str(int flag)
{
    static char buff[256];
    *buff = 0;
    if (flag & F_Global) strcat(buff, "F_Global ");
    if (flag & F_Unref) strcat(buff, "F_Unref ");
    if (flag & F_Proc) strcat(buff, "F_Proc ");
    if (flag & F_Record) strcat(buff, "F_Record ");
    if (flag & F_Dynamic) strcat(buff, "F_Dynamic ");
    if (flag & F_Static) strcat(buff, "F_Static ");
    if (flag & F_Builtin) strcat(buff, "F_Builtin ");
    if (flag & F_Argument) strcat(buff, "F_Argument ");
    if (flag & F_IntLit) strcat(buff, "F_IntLit ");
    if (flag & F_RealLit) strcat(buff, "F_RealLit ");
    if (flag & F_StrLit) strcat(buff, "F_StrLit ");
    if (flag & F_CsetLit) strcat(buff, "F_CsetLit ");
    if (flag & F_Class) strcat(buff, "F_Class ");
    if (flag & F_Importsym) strcat(buff, "F_Importsym ");
    if (flag & F_Field) strcat(buff, "F_Field ");
    return buff;
}

static char *m_flag2str(int flag)
{
    static char buff[256];
    *buff = 0;
    if (flag & M_Method) strcat(buff, "M_Method ");
    if (flag & M_Private) strcat(buff, "M_Private ");
    if (flag & M_Public) strcat(buff, "M_Public ");
    if (flag & M_Protected) strcat(buff, "M_Protected ");
    if (flag & M_Package) strcat(buff, "M_Package ");
    if (flag & M_Static) strcat(buff, "M_Static ");
    if (flag & M_Const) strcat(buff, "M_Const ");
    if (flag & M_Readable) strcat(buff, "M_Readable ");
    if (flag & M_Final) strcat(buff, "M_Final ");
    if (flag & M_Defer) strcat(buff, "M_Defer ");
    if (flag & M_Special) strcat(buff, "M_Special ");
    return buff;
}

void dumpstate()
{
    struct lfile *lf;
    struct fimport *fp;
    struct fimport_symbol *fis;
    struct gentry *gl;
    struct lclass *cl;
    struct lclass_field *me;
    struct lclass_super *sup;
    struct lclass_ref *rsup,*imp;
    struct lclass_field_ref *vr; 
    struct lentry *le;
    struct centry *ce;
    struct fentry *fe;
    struct lfield *lfd;
    struct linvocable *inv;
    int i;

    fprintf(dbgfile, "Invocables, strinv=%d\n", strinv);
    for (inv = linvocables; inv; inv = inv->iv_link) {
        if (inv->resolved)
            fprintf(dbgfile, "\t%s -> %s\n", inv->iv_name, inv->resolved->name);
        else
            fprintf(dbgfile, "\t%s (unresolved)\n", inv->iv_name);
    }

    fprintf(dbgfile, "File list\n---------\n");
    for (lf = lfiles; lf; lf = lf->next) {
        if (lf->package)
            fprintf(dbgfile, "file %s package %s u2off=%d\n",lf->lf_name,lf->package,lf->declend_offset);
        else
            fprintf(dbgfile, "file %s u2off=%d\n",lf->lf_name,lf->declend_offset);
        for (fp = lf->imports; fp; fp = fp->next) {
            if (fp->qualified) {
                fprintf(dbgfile, "\timport %s (qualified)\n",fp->name);
                for (fis = fp->symbols; fis; fis = fis->next)
                    fprintf(dbgfile, "\t\t%s\n",fis->name);
            } else
                fprintf(dbgfile, "\timport %s (unqualified)\n",fp->name);
        }
    }
    fprintf(dbgfile, "Globals\n---------\n");
    for (gl = lgfirst; gl; gl = gl->g_next) {
        fprintf(dbgfile, "name %s id=%d flag=%s\n", gl->name, gl->g_index, f_flag2str(gl->g_flag));
        if (gl->func) {
            fprintf(dbgfile, "\tnargs=%d nstatics=%d\n", gl->func->nargs,
                gl->func->nstatics);
            for (le = gl->func->locals; le; le = le->next) {
                if (le->l_flag & F_Global)
                    fprintf(dbgfile, "\tlocal %s %s global=%s\n", le->name,
                           f_flag2str(le->l_flag),
                           le->l_val.global->name);
                else if (le->l_flag & F_Static)
                    fprintf(dbgfile, "\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                else if (le->l_flag & (F_Argument|F_Dynamic))
                    fprintf(dbgfile, "\tlocal %s %s offset=%d\n", le->name,
                           f_flag2str(le->l_flag), le->l_val.offset);
                else
                    fprintf(dbgfile, "\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
            }
            for (ce = gl->func->constants; ce; ce = ce->next) {
                fprintf(dbgfile, "\tconst %s len=%d ", f_flag2str(ce->c_flag),ce->c_length);
                if (ce->c_flag & F_IntLit)
                    fprintf(dbgfile, "val=%ld\n",ce->c_val.ival);
                if (ce->c_flag & F_RealLit)
                    fprintf(dbgfile, "val=%f\n",ce->c_val.rval);
                if (ce->c_flag & (F_CsetLit|F_StrLit)) {
                    fprintf(dbgfile, "val=");
                    for (i = 0; i < ce->c_length; ++i)
                        putc(ce->c_val.sval[i], dbgfile);
                    fprintf(dbgfile, "\n");
                }
            }
        }
        if (gl->class) {
            cl = gl->class;
            fprintf(dbgfile, "\tfieldtable_col=%d class defined in %s   flags=%s\n", 
                   cl->fieldtable_col,cl->defined->lf_name,m_flag2str(cl->flag));
            fprintf(dbgfile, "\tSource super names:\n");
            for (sup = cl->supers; sup; sup = sup->next)
                fprintf(dbgfile, "\t\t%s\n", sup->name);
            fprintf(dbgfile, "\tResolved supers:\n");
            for (rsup = cl->resolved_supers; rsup; rsup = rsup->next)
                fprintf(dbgfile, "\t\t%s\n", rsup->class->global->name);
            fprintf(dbgfile, "\tImplemented classes:\n");
            for (imp = cl->implemented_classes; imp; imp = imp->next)
                fprintf(dbgfile, "\t\t%s\n", imp->class->global->name);
            fprintf(dbgfile, "\tImplemented fields (instance):\n");
            for (vr = cl->implemented_instance_fields; vr; vr = vr->next)
                fprintf(dbgfile, "\t\t%s from %s\n", vr->field->name,
                       vr->field->class->global->name);
            fprintf(dbgfile, "\tImplemented fields (class):\n");
            for (vr = cl->implemented_class_fields; vr; vr = vr->next)
                fprintf(dbgfile, "\t\t%s from %s\n", vr->field->name,
                       vr->field->class->global->name);
            fprintf(dbgfile, "\tDefined fields:\n");
            for (me = cl->fields; me; me = me->next) {
                fprintf(dbgfile, "\t\t%s %s\n", me->name, m_flag2str(me->flag));
                if (me->func) {
                    fprintf(dbgfile, "\t\t\tMethod numargs=%d nstatics=%d\n", me->func->nargs,
                        me->func->nstatics);
                    for (le = me->func->locals; le; le = le->next) {
                        if (le->l_flag & F_Global)
                            fprintf(dbgfile, "\t\t\tlocal %s %s global=%s\n", le->name,
                                   f_flag2str(le->l_flag),
                                   le->l_val.global->name);
                        else if (le->l_flag & F_Static)
                            fprintf(dbgfile, "\t\t\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                        else if (le->l_flag & (F_Argument|F_Dynamic))
                            fprintf(dbgfile, "\t\t\tlocal %s %s offset=%d\n", le->name,
                                   f_flag2str(le->l_flag), le->l_val.offset);
                        else if (le->l_flag & (F_Field))
                            fprintf(dbgfile, "\t\t\tlocal %s %s field=%s\n", le->name,
                                   f_flag2str(le->l_flag), le->l_val.field->name);
                        else
                            fprintf(dbgfile, "\t\t\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                    }
                    for (ce = me->func->constants; ce; ce = ce->next) {
                        fprintf(dbgfile, "\t\t\tconst %s len=%d ", f_flag2str(ce->c_flag),ce->c_length);
                        if (ce->c_flag & F_IntLit)
                            fprintf(dbgfile, "val=%ld\n",ce->c_val.ival);
                        if (ce->c_flag & F_RealLit)
                            fprintf(dbgfile, "val=%f\n",ce->c_val.rval);
                        if (ce->c_flag & (F_CsetLit|F_StrLit)) {
                            fprintf(dbgfile, "val=");
                            for (i = 0; i < ce->c_length; ++i)
                                putc(ce->c_val.sval[i], dbgfile);
                            fprintf(dbgfile, "\n");
                        }
                    }
                }
            }
        }
        if (gl->record) {
            fprintf(dbgfile, "\tfieldtable_col=%d\n", gl->record->fieldtable_col);
            for (lfd = gl->record->fields; lfd; lfd = lfd->next) {
                fprintf(dbgfile, "\tfield %s\n", lfd->name);
            }
        }
    }
    fprintf(dbgfile, "Field table\n---------\n");
    for (fe = lffirst; fe; fe = fe->next) {
        fprintf(dbgfile, "Field %s id=%d\n\t", fe->name, fe->field_id);
        for (i = 0; i < fieldtable_cols; i++) {
            fprintf(dbgfile, "%3d ", fe->rowdata[i]);
        }
        fprintf(dbgfile, "\n");
    }
}

#endif
