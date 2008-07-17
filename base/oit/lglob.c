/*
 * lglob.c -- routines for processing globals.
 */

#include "icont.h"
#include "link.h"
#include "ucode.h"
#include "lmem.h"
#include "lsym.h"
#include "resolve.h"
#include "util.h"

#include "../h/opdefs.h"

/*
 * Prototypes.
 */

static void	reference(struct gentry *gp);
static double   parse_real(char *data);
static long     parse_int(char *data);

int fieldtable_cols = 0;		/* number of records in program */

/*
 * readglob reads the global information from lf
 */
void readglob(struct lfile *lf)
{
    char *id;
    int n, k;
    char *package, *name;
    struct gentry *gp;
    struct lclass *curr_class = 0;
    struct lfunction *curr_func = 0;
    struct lrecord *curr_record = 0;
    struct ucode_op *uop;
    struct loc pos;

    uop = uin_expectop();
    if (uop->opcode != Op_Version)
        quitf("ucode file %s has no version identification", lf->lf_name);
    id = uin_str();		/* get version number of ucode */
    if (strcmp(id, UVersion))
        quitf("version mismatch in ucode file %s - got %s instead of %s", lf->lf_name, id, UVersion);

    while (1) {
        uop = uin_expectop();
        switch (uop->opcode) {
            case Op_Filen:
                pos.file = join(lf->lf_name, "(", last_pathelem(uin_str()), ")", 0);
                break;

            case Op_Line:
                pos.line = uin_short();
                break;

            case Op_Declend:
                lf->declend_offset = ftell(ucodefile);
                return;

            case Op_Package:
                lf->package = uin_str();
                break;

            case Op_Import:		/* import the named package */
                package = uin_str();
                alsoimport(package, &pos);	/*  (maybe) import the files in the package */
                n = uin_short();        /* qualified flag */
                add_fimport(lf, package, n, &pos);  /* Add it to the lfile structure's list of imports */
                break;

            case Op_Importsym:          /* symbol in a qualified import */
                name = uin_str();
                add_fimport_symbol(lf, name, &pos);
                break;

            case Op_Class:
                k = uin_word();	/* get flags */
                name = uin_fqid(lf->package);
                gp = glocate(name);
                if (gp) {
                    lfatal(&pos, 
                            "class %s declared elsewhere in %s, line %d", 
                            name, gp->pos.file, gp->pos.line);
                    curr_class = 0;
                } else {
                    gp = putglobal(name, F_Class, lf, &pos);
                    curr_class = New(struct lclass);
                    curr_class->defined = lf;
                    curr_class->global = gp;
                    curr_class->flag = k;
                    gp->class = curr_class;
                    if (lclass_last) {
                        lclass_last->next = curr_class;
                        lclass_last = curr_class;
                    } else 
                        lclasses = lclass_last = curr_class;
                }
                curr_record = 0;
                break;

            case Op_Super:
                name = uin_str();
                if (curr_class)
                    add_super(curr_class, name, &pos);
                break;

            case Op_Classfield:
                k = uin_word();	/* get flags */
                name = uin_str();
                if (curr_class) {
                    if (k & M_Method) {
                        add_method(lf, curr_class, name, k, &pos);
                        curr_func = curr_class->last_field->func;
                    } else
                        add_field(curr_class, name, k, &pos);
                }
                break;

            case Op_Nargs:
                n = uin_short();
                if (curr_func)
                    curr_func->nargs = n;
                break;

            case Op_Recordfield:
                name = uin_str();
                if (curr_record)
                    add_record_field(curr_record, name, &pos);
                break;

            case Op_Record:	/* a record declaration */
                name = uin_fqid(lf->package);	/* record name */
                gp = glocate(name);
                if (gp) {
                    lfatal(&pos, 
                            "record %s declared elsewhere in %s, line %d", 
                            name, gp->pos.file, gp->pos.line);
                    curr_record = 0;
                } else {
                    gp = putglobal(name, F_Record, lf, &pos);
                    curr_record = New(struct lrecord);
                    gp->record = curr_record;
                }
                curr_class = 0;
                break;

            case Op_Trace:		/* turn on tracing */
                trace = -1;
                break;

            case Op_Procdecl:
                name = uin_fqid(lf->package);	/* get variable name */
                gp = glocate(name);
                if (gp)
                    lfatal(&pos, 
                            "procedure %s declared elsewhere in %s, line %d", 
                            name, gp->pos.file, gp->pos.line);
                else
                    gp = putglobal(name, F_Proc, lf, &pos);
                curr_func = gp->func = New(struct lfunction);
                curr_func->defined = lf;
                curr_func->proc = gp;
                break;

            case Op_Local:
                k = uin_word();
                name = uin_str();
                if (curr_func)
                    add_local(curr_func, name, k, &pos);
                break;

            case Op_Con: {
                int len;
                char *data;
                union xval gg;
                k = uin_word();
                data = uin_bin(&len);
                if (k & F_IntLit) {
                    long m = parse_int(data);
                    if (m < 0) { 		/* negative indicates integer too big */
                        gg.sval = data;	        /* convert to a string */
                        add_constant(curr_func, F_StrLit, len, &gg);
                    }
                    else {			/* integer  is small enough */
                        gg.ival = m;
                        add_constant(curr_func, k, 0, &gg);
                    }
                }
                else if (k & F_RealLit) {
                    gg.rval = parse_real(data);
                    add_constant(curr_func, k, 0, &gg);
                }
                else if (k & F_StrLit) {
                    gg.sval = data;
                    add_constant(curr_func, k, len, &gg);
                }
                else if (k & F_CsetLit) {
                    gg.sval = data;
                    add_constant(curr_func, k, len, &gg);
                }
                else
                    quit("illegal constant");
                break;
            }

            case Op_Global:
                name = uin_fqid(lf->package);	/* get variable name */
                gp = glocate(name);
                if (gp)
                    lfatal(&pos, 
                            "global %s declared elsewhere in %s, line %d", 
                            name, gp->pos.file, gp->pos.line);
                else
                    putglobal(name, 0, lf, &pos);
                break;

            case Op_Invocable:	/* "invocable" declaration */
                name = uin_str();	/* get name */
                if (name[0] == '0')
                    strinv = 1;	/* name of "0" means "invocable all" */
                else
                    addinvk(name, lf, &pos);
                break;

            case Op_Link:		/* link the named file */
                name = uin_str();	/* get the name and */
                alsolink(name, &pos);	/*  put it on the list of files to link */
                break;

            default:
                quitf("ill-formed global file %s",lf->lf_name);
        }
    }
}

static void resolve_locals_impl(struct lfunction *f)
{
    struct lentry *e;
    struct centry *c;

    /*
     * Resolve each identifier encountered.
     */
    for (e = f->locals; e; e = e->next)
        resolve_local(f, e);

    /*
     * Turn the lists into arrays so that they may be conveniently
     * indexed when encountered in code generation.
     */
    if (f->nlocals > 0) {
        int i = 0;
        f->local_table = calloc(f->nlocals, sizeof(struct lentry *));
        for (e = f->locals; e; e = e->next)
            f->local_table[i++] = e;
    }
    if (f->nconstants > 0) {
        int i = 0;
        f->constant_table = calloc(f->nconstants, sizeof(struct centry *));
        for (c = f->constants; c; c = c->next)
            f->constant_table[i++] = c;
    }
}

/*
 * Resolve symbols encountered in procedures and methods.
 */
void resolve_locals()
{
    struct gentry *gp;
    /*
     * Resolve local references in functions.
     */
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->func)
            resolve_locals_impl(gp->func);
        else if (gp->class) {
            struct lclass_field *lf;
            for (lf = gp->class->fields; lf; lf = lf->next) {
                if (lf->func)
                    resolve_locals_impl(lf->func);
            }
        }
    }
}

/*
 * Scan symbols used in procedures/methods to determine which global
 * symbols can be reached from "main" (or any other declared invocable
 * functions), and which can be discarded.
 *
 */
void scanrefs()
{
    struct gentry *gp, **gpp, *gmain;
    struct linvocable *inv;
    struct lclass *cp, **cpp;

    /*
     * If "invocable all" specified, we keep all globals.
     */
    if (strinv)
        return;

    /*
     * Mark every global as unreferenced; search for main.
     */
    gmain = 0;
    for (gp = lgfirst; gp; gp = gp->g_next) {
        gp->g_flag |= F_Unref;
        if (gp->name == main_string)
            gmain = gp;
    }

    if (!gmain) {
        lfatal(0, "No main procedure found");
        return;
    }

    /*
     * Clear the F_Unref flag for referenced globals, starting with main()
     * and marking references within procedures recursively.
     */
    reference(gmain);

    /*
     * Reference (recursively) every global declared to be "invocable".
     */
    for (inv = linvocables; inv; inv = inv->iv_link)
        reference(inv->resolved);

    /*
     * Rebuild the global list to include only referenced globals.
     * Note that the global hash is rebuilt below when the global
     * table is sorted.
     */
    gpp = &lgfirst;
    while ((gp = *gpp)) {
        if (gp->g_flag & F_Unref) {
            if (verbose > 2) {
                char *t;
                if (gp->g_flag & F_Proc)
                    t = "procedure";
                else if (gp->g_flag & F_Record)
                    t = "record   ";
                else if (gp->g_flag & F_Class)
                    t = "class    ";
                else
                    t = "global   ";
                if (!(gp->g_flag & F_Builtin))
                    report("Discarding %s %s", t, gp->name);
            }
            *gpp = gp->g_next;
        }
        else {
            /*
             *  The global is used.
             */
            gpp = &gp->g_next;
        }
    }

    /*
     * Rebuild the list of classes.
     */
    cpp = &lclasses;
    while ((cp = *cpp)) {
        if (cp->global->g_flag & F_Unref)
            *cpp = cp->next;
        else
            cpp = &cp->next;
    }
}

/*
 * Mark a single global as referenced, and traverse all references
 * within it (if it is a class/procedure).
 */
static void reference(struct gentry *gp)
{
    struct lentry *le;
    struct lclass_field *lm;
    struct lclass_ref *sup;

    if (gp->g_flag & F_Unref) {
        gp->g_flag &= ~F_Unref;
        if (gp->func) {
            for (le = gp->func->locals; le; le = le->next) {
                if ((le->l_flag & (F_Global | F_Unref)) == F_Global)
                    reference(le->l_val.global);
            }
        } else if (gp->class) {
            /* Mark all vars in all the methods */
            for (lm = gp->class->fields; lm; lm = lm->next) {
                if (lm->func) {
                    for (le = lm->func->locals; le; le = le->next) {
                        if ((le->l_flag & (F_Global | F_Unref)) == F_Global)
                            reference(le->l_val.global);
                    }
                }
            }
            /* Mark all the superclasses */
            for (sup = gp->class->resolved_supers; sup; sup = sup->next) 
                reference(sup->class->global);
        }
    }
}

static int add_fieldtable_entry(char *name, int column_num, int field_num)
{
    struct fentry *fp;
    int i = hasher(name, lfhash), j;
    fp = lfhash[i];
    while (fp && fp->name != name)
        fp = fp->b_next;
    if (!fp) {
        fp = New(struct fentry);
        fp->name = name;
        fp->field_id = nfields++;
        /* Allocate and init the data for this row */
        fp->rowdata = malloc(fieldtable_cols * sizeof(int));
        if (!fp->rowdata)
            quit("Out of memory");
        for (j = 0; j < fieldtable_cols; ++j)
            fp->rowdata[j] = -1;
        fp->b_next = lfhash[i];
        lfhash[i] = fp;
        if (lflast) {
            lflast->next = fp;
            lflast = fp;
        } else
            lffirst = lflast = fp;
    }
    if (fp->rowdata[column_num] != -1)
        quit("Unexpected fieldtable clash");

    fp->rowdata[column_num] = field_num;
    return fp->field_id;
}

void build_fieldtable()
{
    struct gentry *gp;
    struct lfield *fd;
    struct lclass_field_ref *fr; 

    /* Set the fieldtable column numbers for a record/class */
    fieldtable_cols = 0;
    for (gp = lgfirst; gp; gp = gp->g_next) {
        if (gp->record)
            gp->record->fieldtable_col = fieldtable_cols++;
        else if (gp->class)
            gp->class->fieldtable_col = fieldtable_cols++;
    }

    for (gp = lgfirst; gp; gp = gp->g_next) {
        int i = 0;
        if (gp->record) {
            for (fd = gp->record->fields; fd; fd = fd->next) {
                add_fieldtable_entry(fd->name, gp->record->fieldtable_col, i++);
            }
        } else if (gp->class) {
            for (fr = gp->class->implemented_instance_fields; fr; fr = fr->next)
                fr->field->fnum = add_fieldtable_entry(fr->field->name, gp->class->fieldtable_col, i++);
            for (fr = gp->class->implemented_class_fields; fr; fr = fr->next)
                fr->field->fnum = add_fieldtable_entry(fr->field->name, gp->class->fieldtable_col, i++);
        }
    }
}

static int global_sort_compare(const void *p1, const void *p2)
{
    struct gentry *f1, *f2;
    f1 = *((struct gentry **)p1);
    f2 = *((struct gentry **)p2);
    return strcmp(f1->name, f2->name);
}

void sort_global_table()
{
    struct gentry **a, *gp;
    int i = 0, n = 0;
    for (gp = lgfirst; gp; gp = gp->g_next)
        ++n;
    a = calloc(n, sizeof(struct gentry *));
    for (gp = lgfirst; gp; gp = gp->g_next)
        a[i++] = gp;
    qsort(a, n, sizeof(struct gentry *), global_sort_compare);

    lgfirst = lglast = 0;
    clear(lghash);
    for (i = 0; i < n; ++i) {
        struct gentry *p = a[i];
        int h = hasher(p->name, lghash);
        p->g_index = i;
        p->g_blink = lghash[h];
        p->g_next = 0;
        lghash[h] = p;
        if (lglast) {
            lglast->g_next = p;
            lglast = p;
        } else 
            lgfirst = lglast = p;
    }
    free(a);
}

/*
 * getreal - get an Icon real number from infile, and return it.
 */
static double parse_real(char *data)
{
    double n;
    register int c, d, e;
    int esign;
    register char *s, *ep, *p = data;
    char cbuf[128];

    s = cbuf;
    d = 0;
    while ((c = *p++) == '0')
        ;
    while (c >= '0' && c <= '9') {
        *s++ = c;
        d++;
        c = *p++;
    }
    if (c == '.') {
        if (s == cbuf)
            *s++ = '0';
        *s++ = c;
        while ((c = *p++) >= '0' && c <= '9')
            *s++ = c;
    }
    ep = s;
    if (c == 'e' || c == 'E') {
        *s++ = c;
        if ((c = *p++) == '+' || c == '-') {
            esign = (c == '-');
            *s++ = c;
            c = *p++;
        }
        else
            esign = 0;
        e = 0;
        while (c >= '0' && c <= '9') {
            e = e * 10 + c - '0';
            *s++ = c;
            c = *p++;
        }
        if (esign) e = -e;
        e += d - 1;
        if (abs(e) >= LogHuge)
            *ep = '\0';
    }
    *s = '\0';
    n = atof(cbuf);
    return n;
}

#define tonum(c)    (isdigit(c) ? (c - '0') : ((c & 037) + 9))

/*
 *  Get integer, but if it's too large for a long, return -1.
 */
static long parse_int(char *data)
{
    register int c;
    int over = 0;
    double result = 0;
    long lresult = 0;
    double radix;
    char *p = data;

    while ((c = *p++) >= '0' && c <= '9') {
        result = result * 10 + (c - '0');
        lresult = lresult * 10 + (c - '0');
        if (result <= MinLong || result >= MaxLong) {
            over = 1;			/* flag overflow */
            result = 0;			/* reset to avoid fp exception */
        }
    }
    if (c == 'r' || c == 'R') {
        radix = result;
        lresult = 0;
        result = 0;
        while ((c = *p++) != 0) {
            if (isdigit(c) || isalpha(c))
                c = tonum(c);
            else
                break;
            result = result * radix + c;
            lresult = lresult * radix + c;
            if (result <= MinLong || result >= MaxLong) {
                over = 1;			/* flag overflow */
                result = 0;			/* reset to avoid fp exception */
            }
        }
    }

    if (!over)
        return lresult;			/* integer is small enough */
    else {				/* integer is too large */
        return -1;			/* indicate integer is too big */
    }
}

