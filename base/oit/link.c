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
#include "ltree.h"
#include "optimize.h"
#include "ir.h"

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
#ifndef XWindows
#include <sys/types.h>
#endif				/* XWindows */
#include <sys/stat.h>
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

FILE *infile;                           /* input file (.u) */
FILE *outfile;                          /* interpreter code output file */

FILE *dbgfile;                          /* debug file */
static char *dbgname;                   /* debug file name */

char *inname;                           /* input file name */

int lfatals = 0;                                /* number of errors encountered */
int lwarnings = 0;                      /* number of warnings encountered */

struct lfunction *curr_lfunc;

/*
 *  ilink - link a number of files, returning error and warning counts
 */
void ilink(struct file_param *link_files, int *fatals, int *warnings)
{
    struct lfile *lf;
    struct file_param *p;

    linit();				/* initialize memory structures */
    for (p = link_files; p; p = p->next)
        paramlink(p->name);  /* make initial list of files */

    /*
     * Phase I: load global information contained in .u files into
     *  data structures.
     *
     * The list of files to link is maintained as a queue with lfiles
     * as the base.  lf moves along the list.  Each file is processed
     * in turn.  The .u file is opened and readglob is called to
     * process it.  When the end of the list is reached, lf becomes
     * NULL and the loop is terminated, completing phase I.  Note that
     * link and import instructions in the .u file cause files to be
     * added to list of files to link.
     */
    for (lf = lfiles; lf; lf = lf->next) {
        inname = lf->name;
        ucodefile = fopen(inname, ReadBinary);
        if (!ucodefile)
            quitf("cannot open %s",inname);
        readglob(lf);
        fclose(ucodefile);
    }

    if (lfatals > 0) {
        *warnings = lwarnings;
        *fatals = lfatals;
        return;
    }

    /*
     * Open the .ux file if debugging is on.
     */
    if (Dflag) {
        dbgname = intern(makename(TargetDir, lfiles->name, UXSuffix));
        dbgfile = fopen(dbgname, WriteText);
        if (dbgfile == NULL)
            quitf("cannot create %s", dbgname);
    }

    /* Phase 1a - resolve invocables, superclass identifiers */
    if (!strinv)
        resolve_invocables();
    resolve_supers();
    compute_inheritance();

    /* Resolve identifiers encountered in procedures and methods */
    resolve_locals();

    if (lfatals > 0) {
        *warnings = lwarnings;
        *fatals = lfatals;
        return;
    }
    check_unused_imports();

    /* Phase II:  suppress unreferenced procs, unless "invocable all". */
    if (!strinv)
        scanrefs();

    loadtrees();

    if (Olevel > 0)
        optimize();

    sort_global_table();
    build_fieldtable();
    resolve_native_methods();

    if (verbose > 3)
        dumpstate();

    /* Phase III: generate code. */
    generate_code();

    lmfree();
    *warnings = lwarnings;
    *fatals = lfatals;
    if (lfatals == 0)
        setexe(ofile);
}

char *function_name(struct lfunction *f)
{
    if (f->proc)
        return join("procedure ", 
                    f->proc->name,
                    0);
    else
        return join("method ",
                    f->method->class->global->name, 
                    ".",
                    f->method->name,
                    0);
}

/*
 * lfatal - issue a fatal linker error message.
 */
void lfatal(struct lfile *lf, struct loc *pos, char *fmt, ...)
{
    va_list argp;
    if (lf)
        fprintf(stderr, "%s:\n", lf->name);
    if (pos) {
        if (pos->file)
            fprintf(stderr, "File %s; ", abbreviate(pos->file));
        if (pos->line)
            fprintf(stderr, "Line %d # ", pos->line);
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
void lwarn(struct lfile *lf, struct loc *pos, char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    if (lf)
        fprintf(stderr, "%s:\n", lf->name);
    if (pos) {
        if (pos->file)
            fprintf(stderr, "File %s; ", abbreviate(pos->file));
        if (pos->line)
            fprintf(stderr, "Line %d # ", pos->line);
    }
    fprintf(stderr, "Warning: ");
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
            /*
             * We only output a warning for the stem if strinv is off,
             * because an import will have an effect if "invocable
             * all" is on.  Also since "stem unused => symbols unused",
             * we don't check the symbols if we output a warning for
             * the stem.
             */
            if (!fp->used && !strinv)
                lwarn(lf, &fp->pos, "Unused import: %s", fp->name);
            else if (fp->qualified) {
                for (fis = fp->symbols; fis; fis = fis->next) {
                    if (!fis->used)
                        lwarn(lf, &fis->pos, "Unused import symbol: %s", fis->name);
                }
            }
        }
    }
}

char *f_flag2str(int flag)
{
    static char buff[256];
    *buff = 0;
    if (flag & F_Global) strcat(buff, "F_Global ");
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
    if (flag & F_LrgintLit) strcat(buff, "F_LrgintLit ");
    if (flag & F_Method) strcat(buff, "F_Method ");
    if (flag & F_UcsLit) strcat(buff, "F_UcsLit ");
    if (*buff)
        buff[strlen(buff) - 1] = 0;
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
    if (*buff)
        buff[strlen(buff) - 1] = 0;
    return buff;
}

static char *const_flag2str(int flag)
{
    switch (flag) {
        case NOT_SEEN: return "NOT_SEEN";
        case SET_NULL: return "SET_NULL";
        case SET_CONST: return "SET_CONST";
        case OTHER: return "OTHER";
        default: return "?";
    }
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
    struct lfield *lfd;
    struct linvocable *inv;
    int i;

    fprintf(stderr, "Invocables, strinv=%d\n", strinv);
    for (inv = linvocables; inv; inv = inv->iv_link) {
        if (inv->resolved)
            fprintf(stderr, "\t%s -> %s\n", inv->iv_name, inv->resolved->name);
        else
            fprintf(stderr, "\t%s (unresolved)\n", inv->iv_name);
    }

    fprintf(stderr, "File list\n---------\n");
    for (lf = lfiles; lf; lf = lf->next) {
        if (lf->package)
            fprintf(stderr, "file %s package %s u2off=%d\n",lf->name,lf->package,lf->declend_offset);
        else
            fprintf(stderr, "file %s u2off=%d\n",lf->name,lf->declend_offset);
        for (fp = lf->imports; fp; fp = fp->next) {
            if (fp->qualified) {
                fprintf(stderr, "\timport %s (qualified)\n",fp->name);
                for (fis = fp->symbols; fis; fis = fis->next)
                    fprintf(stderr, "\t\t%s\n",fis->name);
            } else
                fprintf(stderr, "\timport %s (unqualified)\n",fp->name);
        }
    }
    fprintf(stderr, "Globals\n---------\n");
    for (gl = lgfirst; gl; gl = gl->g_next) {
        fprintf(stderr, "name %s id=%d flag=%s\n", gl->name, gl->g_index, f_flag2str(gl->g_flag));
        if (gl->func) {
            fprintf(stderr, "\tnargs=%d nstatics=%d\n", gl->func->nargs,
                gl->func->nstatics);
            for (le = gl->func->locals; le; le = le->next) {
                if (le->l_flag & F_Global)
                    fprintf(stderr, "\tlocal %s %s global=%s\n", le->name,
                           f_flag2str(le->l_flag),
                           le->l_val.global->name);
                else if (le->l_flag & F_Static)
                    fprintf(stderr, "\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                else if (le->l_flag & (F_Argument|F_Dynamic))
                    fprintf(stderr, "\tlocal %s %s index=%d\n", le->name,
                           f_flag2str(le->l_flag), le->l_val.index);
                else
                    fprintf(stderr, "\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
            }
            for (ce = gl->func->constants; ce; ce = ce->next) {
                fprintf(stderr, "\tconst %s len=%d ", f_flag2str(ce->c_flag),ce->length);
                fprintf(stderr, "val=");
                for (i = 0; i < ce->length; ++i)
                    putc(ce->data[i], stderr);
                fprintf(stderr, "\n");
            }
        }
        if (gl->class) {
            cl = gl->class;
            fprintf(stderr, "\tclass defined in %s   flags=%s\n", 
                   cl->global->defined->name,m_flag2str(cl->flag));
            fprintf(stderr, "\tSource super names:\n");
            for (sup = cl->supers; sup; sup = sup->next)
                fprintf(stderr, "\t\t%s\n", sup->name);
            fprintf(stderr, "\tResolved supers:\n");
            for (rsup = cl->resolved_supers; rsup; rsup = rsup->next)
                fprintf(stderr, "\t\t%s\n", rsup->class->global->name);
            fprintf(stderr, "\tImplemented classes:\n");
            for (imp = cl->implemented_classes; imp; imp = imp->next)
                fprintf(stderr, "\t\t%s\n", imp->class->global->name);
            fprintf(stderr, "\tImplemented fields (instance):\n");
            for (vr = cl->implemented_instance_fields; vr; vr = vr->next)
                fprintf(stderr, "\t\t%s from %s\n", vr->field->name,
                       vr->field->class->global->name);
            fprintf(stderr, "\tImplemented fields (class):\n");
            for (vr = cl->implemented_class_fields; vr; vr = vr->next)
                fprintf(stderr, "\t\t%s from %s\n", vr->field->name,
                       vr->field->class->global->name);
            fprintf(stderr, "\tDefined fields:\n");
            for (me = cl->fields; me; me = me->next) {
                fprintf(stderr, "\t\t%s %s\n", me->name, m_flag2str(me->flag));
                if (me->flag == (M_Public | M_Static | M_Const)) {
                    fprintf(stderr, "\t\t\tconst_flag=%s\n", const_flag2str(me->const_flag));
                }
                if (me->func) {
                    fprintf(stderr, "\t\t\tMethod numargs=%d nstatics=%d\n", me->func->nargs,
                        me->func->nstatics);
                    for (le = me->func->locals; le; le = le->next) {
                        if (le->l_flag & F_Global)
                            fprintf(stderr, "\t\t\tlocal %s %s global=%s\n", le->name,
                                   f_flag2str(le->l_flag),
                                   le->l_val.global->name);
                        else if (le->l_flag & F_Static)
                            fprintf(stderr, "\t\t\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                        else if (le->l_flag & (F_Argument|F_Dynamic))
                            fprintf(stderr, "\t\t\tlocal %s %s index=%d\n", le->name,
                                   f_flag2str(le->l_flag), le->l_val.index);
                        else if (le->l_flag & (F_Field))
                            fprintf(stderr, "\t\t\tlocal %s %s field=%s\n", le->name,
                                   f_flag2str(le->l_flag), le->l_val.field->name);
                        else
                            fprintf(stderr, "\t\t\tlocal %s %s\n", le->name, f_flag2str(le->l_flag));
                    }
                    for (ce = me->func->constants; ce; ce = ce->next) {
                        fprintf(stderr, "\t\t\tconst %s len=%d ", f_flag2str(ce->c_flag),ce->length);
                        fprintf(stderr, "val=");
                        for (i = 0; i < ce->length; ++i)
                            putc(ce->data[i], stderr);
                        fprintf(stderr, "\n");
                    }
                }
            }
        }
        if (gl->record) {
            for (lfd = gl->record->fields; lfd; lfd = lfd->next) {
                fprintf(stderr, "\tfield %s\n", lfd->name);
            }
        }
    }
    fflush(stderr);
}
