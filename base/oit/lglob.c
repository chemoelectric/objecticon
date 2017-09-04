/*
 * lglob.c -- routines for processing globals.
 */

#include "icont.h"
#include "link.h"
#include "ucode.h"
#include "lmem.h"
#include "lsym.h"
#include "resolve.h"
#include "tmain.h"
#include "ltree.h"

#include "../h/opdefs.h"

/*
 * Prototypes.
 */

static void	reference(struct gentry *gp);

struct package_id {
    char *name;
    int id;
    struct package_id *b_next;
};

#define PACKAGE_ID_HASH_SIZE 128
struct package_id *package_id_hash[PACKAGE_ID_HASH_SIZE];

int get_package_id(char *s)
{
    int i = hasher(s, package_id_hash);
    struct package_id *x = package_id_hash[i];
    static int next_package_id = 1;
    while (x && x->name != s)
        x = x->b_next;
    if (!x) {
        x = Alloc(struct package_id);
        x->b_next = package_id_hash[i];
        package_id_hash[i] = x;
        x->name = s;
        x->id = next_package_id++;
    }
    return x->id;
}

/*
 * readglob reads the global information from lf
 */
void readglob(struct lfile *lf)
{
    char *id;
    int n, k, f;
    char *package, *name;
    struct gentry *gp;
    struct lclass *curr_class = 0;
    struct lfunction *curr_func = 0;
    struct lrecord *curr_record = 0;
    struct ucode_op *uop;
    struct loc pos;

    uop = uin_expectop();
    if (uop->opcode != Uop_Version)
        quit("ucode file %s has no version identification", lf->name);
    id = uin_str();		/* get version number of ucode */
    if (strcmp(id, UVersion))
        quit("version mismatch in ucode file %s - got %s instead of %s", lf->name, id, UVersion);

    while (1) {
        uop = uin_expectop();
        switch (uop->opcode) {
            case Uop_Filen:
                pos.file = uin_str();
                break;

            case Uop_Line:
                pos.line = uin_16();
                break;

            case Uop_Declend:
                lf->declend_offset = ftell(ucodefile);
                return;

            case Uop_Package:
                lf->package = uin_str();
                lf->package_id = get_package_id(lf->package);
                break;

            case Uop_Import:		/* import the named package */
                package = uin_str();
                alsoimport(package, lf, &pos);	/*  (maybe) import the files in the package */
                n = uin_16();        /* import mode */
                add_fimport(lf, package, n, &pos);  /* Add it to the lfile structure's list of imports */
                break;

            case Uop_Importsym:          /* symbol in a qualified import */
                name = uin_str();
                add_fimport_symbol(lf, name, &pos);
                break;

            case Uop_PkClass:
            case Uop_Class:
                k = uin_32();	/* get flags */
                name = uin_fqid(lf->package);
                gp = glocate(name);
                if (gp) {
                    lfatal2(lf, &pos, &gp->pos, "",
                            "class %s declared elsewhere at ", name);
                    curr_class = 0;
                } else {
                    f = F_Class;
                    if (uop->opcode == Uop_PkClass) f |= F_Package;
                    gp = putglobal(name, f, lf, &pos);
                    curr_class = Alloc(struct lclass);
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

            case Uop_Super:
                name = uin_str();
                if (curr_class)
                    add_super(curr_class, name, &pos);
                break;

            case Uop_Classfield:
                k = uin_32();	/* get flags */
                name = uin_str();
                if (curr_class) {
                    if (k & M_Method) {
                        add_method(lf, curr_class, name, k, &pos);
                        curr_func = curr_class->last_field->func;
                    } else
                        add_field(curr_class, name, k, &pos);
                }
                break;

            case Uop_Recordfield:
                name = uin_str();
                if (curr_record)
                    add_record_field(curr_record, name, &pos);
                break;

            case Uop_PkRecord:
            case Uop_Record:	/* a record declaration */
                name = uin_fqid(lf->package);	/* record name */
                gp = glocate(name);
                if (gp) {
                    lfatal2(lf, &pos, &gp->pos, "",
                            "record %s declared elsewhere at ", name);
                    curr_record = 0;
                } else {
                    f = F_Record;
                    if (uop->opcode == Uop_PkRecord) f |= F_Package;
                    gp = putglobal(name, f, lf, &pos);
                    curr_record = Alloc(struct lrecord);
                    curr_record->global = gp;
                    gp->record = curr_record;
                    if (lrecord_last) {
                        lrecord_last->next = curr_record;
                        lrecord_last = curr_record;
                    } else 
                        lrecords = lrecord_last = curr_record;
                }
                curr_class = 0;
                break;

            case Uop_PkProcdecl:
            case Uop_Procdecl:
                name = uin_fqid(lf->package);	/* get variable name */
                gp = glocate(name);
                if (gp)
                    lfatal2(lf, &pos, &gp->pos, "",
                           "procedure %s declared elsewhere at ", name);
                else {
                    f = F_Proc;
                    if (uop->opcode == Uop_PkProcdecl) f |= F_Package;
                    gp = putglobal(name, f, lf, &pos);
                }
                curr_func = gp->func = Alloc(struct lfunction);
                curr_func->defined = lf;
                curr_func->proc = gp;
                break;

            case Uop_Local:
                k = uin_32();
                name = uin_str();
                if (curr_func)
                    add_local(curr_func, name, k, &pos);
                break;

            case Uop_Sdata: {
                int len;
                char *data;
                k = uin_32();
                data = uin_sbin(&len);
                if (curr_func)
                    add_constant(curr_func, k, data, len);
                break;
            }

            case Uop_Ldata: {
                int len;
                char *data;
                k = uin_32();
                data = uin_lbin(&len);
                if (curr_func)
                    add_constant(curr_func, k, data, len);
                break;
            }

            case Uop_PkGlobal:
            case Uop_PkRdGlobal:
            case Uop_Global:
                name = uin_fqid(lf->package);	/* get variable name */
                gp = glocate(name);
                if (gp)
                    lfatal2(lf, &pos, &gp->pos, "",
                            "global %s declared elsewhere at ", name);
                else {
                    f = 0;
                    switch (uop->opcode) {
                        case Uop_PkGlobal: f = F_Package; break;
                        case Uop_PkRdGlobal: f = F_Package|F_Readable; break;
                        case Uop_Global: f = 0; break;
                    }
                    gp = putglobal(name, f, lf, &pos);
                }
                break;

            case Uop_Invocable:	/* "invocable" declaration */
                name = uin_str();	/* get name */
                if (name[0] == '0')
                    strinv = 1;	/* name of "0" means "invocable all" */
                else
                    addinvk(name, lf, &pos);
                break;

            default:
                quit("ill-formed global file %s",lf->name);
        }
    }
}

static void resolve_locals_impl(struct lfunction *f)
{
    struct lentry *e;

    /*
     * Resolve each identifier encountered.
     */
    for (e = f->locals; e; e = e->next)
        resolve_local(f, e);
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
    struct lrecord *rp, **rpp;
    struct lfile *lf, **lfp;

    /*
     * Mark every global as unreferenced; search for main.
     */
    gmain = 0;
    for (gp = lgfirst; gp; gp = gp->g_next) {
        gp->ref = 0;
        if (gp->name == main_string)
            gmain = gp;
    }

    if (!gmain) {
        lfatal(0, 0, "No main procedure found");
        return;
    }

    for (lf = lfiles; lf; lf = lf->next)
        lf->ref = 0;

    /*
     * Set the ref flag for referenced globals, starting with main()
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
        if (gp->ref) {
            /*
             *  The global is used.
             */
            if (gp->defined)
                gp->defined->ref = 1;     /* Mark the file as used */
            gpp = &gp->g_next;
        }
        else {
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
    }

    /*
     * Rebuild the list of classes.
     */
    cpp = &lclasses;
    while ((cp = *cpp)) {
        if (cp->global->ref)
            cpp = &cp->next;
        else
            *cpp = cp->next;
    }

    /*
     * Rebuild the list of records.
     */
    rpp = &lrecords;
    while ((rp = *rpp)) {
        if (rp->global->ref)
            rpp = &rp->next;
        else
            *rpp = rp->next;
    }

    /*
     * Rebuild the list of files.
     */
    lfp = &lfiles;
    while ((lf = *lfp)) {
        if (lf->ref)
            lfp = &lf->next;
        else {
            if (verbose > 2) 
                report("Discarding file      %s", lf->name);
            *lfp = lf->next;
        }
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

    if (gp->ref)
        return;

    gp->ref = 1;
    if (gp->func) {
        for (le = gp->func->locals; le; le = le->next) {
            if (le->l_flag & F_Global)
                reference(le->l_val.global);
        }
    } else if (gp->class) {
        /* Mark all vars in all the methods */
        for (lm = gp->class->fields; lm; lm = lm->next) {
            if (lm->func) {
                for (le = lm->func->locals; le; le = le->next) {
                    if (le->l_flag & F_Global)
                        reference(le->l_val.global);
                }
            }
        }
        /* Mark all the superclasses */
        for (sup = gp->class->resolved_supers; sup; sup = sup->next) 
            reference(sup->class->global);
    }
}

static struct fentry *add_fieldtable_entry(char *name)
{
    struct fentry *fp;
    int i = hasher(name, lfhash);
    fp = lfhash[i];
    while (fp && fp->name != name)
        fp = fp->b_next;
    if (!fp) {
        fp = Alloc(struct fentry);
        fp->name = name;
        nfields++;
        fp->b_next = lfhash[i];
        lfhash[i] = fp;
        if (lflast) {
            lflast->next = fp;
            lflast = fp;
        } else
            lffirst = lflast = fp;
    }
    return fp;
}

static int fieldtable_sort_compare(struct fentry **p1, struct fentry **p2)
{
    return strcmp((*p1)->name, (*p2)->name);
}

static int add_field_use(struct lnode *n)
{
    switch (n->op) {
        case Uop_Field: {
            struct lnode_field *x = (struct lnode_field *)n;
            x->ftab_entry = add_fieldtable_entry(x->fname);
            break;
        }
    }
    return 1;
}

void build_fieldtable()
{
    struct lfield *fd;
    struct lclass_field *cf; 
    struct fentry *fp;
    struct fentry **a;
    struct lrecord *rec;
    struct lclass *cl;
    int i = 0;

    /*
     * Build the field table, counting the total number of entries.
     */
    nfields = 0;
    for (rec = lrecords; rec; rec = rec->next)
        for (fd = rec->fields; fd; fd = fd->next)
            fd->ftab_entry = add_fieldtable_entry(fd->name);
    for (cl = lclasses; cl; cl = cl->next)
        for (cf = cl->fields; cf; cf = cf->next)
            cf->ftab_entry = add_fieldtable_entry(cf->name);

    visit_post(add_field_use);

    /*
     * Now create a sorted index of the field table.
     */
    a = safe_calloc(nfields, sizeof(struct fentry *));
    for (fp = lffirst; fp; fp = fp->next)
        a[i++] = fp;
    qsort(a, nfields, sizeof(struct fentry *), (QSortFncCast)fieldtable_sort_compare);

    /*
     * Finally set the field numbers for each fentry and rebuild the
     * linked list.
     */
    lffirst = lflast = 0;
    for (i = 0; i < nfields; ++i) {
        fp = a[i];
        fp->field_id = i;
        fp->next = 0;
        if (lflast) {
            lflast->next = fp;
            lflast = fp;
        } else
            lffirst = lflast = fp;
    }

    free(a);
}

static int global_sort_compare(struct gentry **p1, struct gentry **p2)
{
    return strcmp((*p1)->name, (*p2)->name);
}

void sort_global_table()
{
    struct gentry **a, *gp;
    int i = 0, n = 0;
    for (gp = lgfirst; gp; gp = gp->g_next)
        ++n;
    a = safe_calloc(n, sizeof(struct gentry *));
    for (gp = lgfirst; gp; gp = gp->g_next)
        a[i++] = gp;
    qsort(a, n, sizeof(struct gentry *), (QSortFncCast)global_sort_compare);

    lgfirst = lglast = 0;
    ArrClear(lghash);
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

struct native_method { 
    char *class, *field;
};

struct native_method native_methods[] = {
#define NativeDef(class,field,func) {#class,#field},
#include "../h/nativedefs.h"
#undef NativeDef
};

/*
 * Go through the list of native methods, resolving them to class
 * fields.  The native_method_id field is set to the index number for
 * any found.
 */
void resolve_native_methods()
{
    int n;
    char *class_name = "";
    struct lclass *cl = 0;
    
    for (n = 0; n < ElemCount(native_methods); ++n) {
        if (strcmp(class_name, native_methods[n].class)) {
            struct gentry *gl;
            class_name = intern(native_methods[n].class);
            gl = glocate(class_name);
            if (gl)
                cl = gl->class;
            else
                cl = 0;
        }
        if (cl) {
            /* Lookup the method in the class's method table */
            char *method_name = intern(native_methods[n].field);
            int i = hasher(method_name, cl->field_hash);
            struct lclass_field *cf = cl->field_hash[i];
            while (cf && cf->name != method_name)
                cf = cf->b_next;
            /* Check it's a native method and not a variable */
            if (cf && (cf->flag & M_Native))
                cf->func->native_method_id = n;
        }
    }
}


