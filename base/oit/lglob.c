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

static void reference(struct gentry *gp);
static void rebuild_lists(void);
static void clear_refs(void);
static void reference2(struct gentry *gp);
static void freference(struct lfunction *lf);
static int add_seen_field(struct lnode *n);

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
        quit("Ccode file %s has no version identification", lf->name);
    id = uin_str();		/* get version number of ucode */
    if (strcmp(id, UVersion))
        quit("Version mismatch in ucode file %s - got %s instead of %s", lf->name, id, UVersion);

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
                    if (name == main_string)
                        gmain = gp;
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
                else if (name[0] == '1')  /* name of "1" means "invocable methods" */
                    methinv = 1;
                else
                    addinvk(name, lf, &pos);
                break;

            default:
                quit("Ill-formed global file %s",lf->name);
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
    struct linvocable *inv;

    /*
     * Mark every global and file as unreferenced.
     */
    clear_refs();

    /*
     * Set the ref flag for referenced globals, starting with main()
     * and marking references within procedures recursively.
     */
    reference(gmain);

    /*
     * Reference (recursively) every global declared to be "invocable".
     */
    for (inv = linvocables; inv; inv = inv->iv_link)
        if (*inv->iv_name != '.')
            reference(inv->resolved);

    rebuild_lists();
}

static void rebuild_lists()
{
    struct gentry *gp, **gpp;
    struct lclass *cp, **cpp;
    struct lrecord *rp, **rpp;
    struct lfile *lf, **lfp;

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
    a = safe_malloc(nfields * sizeof(struct fentry *));
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
    a = safe_malloc(n * sizeof(struct gentry *));
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

/*
 * Structure and methods for a table of method lists, indexed by method name.
 */
static struct membuff ref2_mb = {"reference2() function membuff", 64000, 0,0,0 };

static struct method1 *methods[500];

struct method1 {
    char *name;
    struct method2 *list;      /* List of methods called name */
    struct method1 *next;
};

struct method2 {
    struct lclass_field *field;
    struct method2 *next;
};

static void put_method(struct lclass_field *field)
{
    int i = hasher(field->name, methods);
    struct method1 *x = methods[i]; 
    struct method2 *y;
    while (x && x->name != field->name)
        x = x->next;
    if (!x) {
        x = mb_alloc(&ref2_mb, sizeof(struct method1));
        x->name = field->name;
        x->next = methods[i];
        x->list = 0;
        methods[i] = x;
    }
    y = mb_alloc(&ref2_mb, sizeof(struct method2));
    y->field = field;
    y->next = x->list;
    x->list = y;
}

static struct method2 *get_methods_named(char *name)
{
    int i = hasher(name, methods);
    struct method1 *x = methods[i]; 
    while (x && x->name != name)
        x = x->next;
    if (x)
        return x->list;
    else
        return 0;
}

static void mark_all_methods_named(char *name)
{
    struct method2 *y = get_methods_named(name);
    while (y) {
        if (verbose > 4) fprintf(stderr, "Marking method %s (%s:%d)\n", y->field->name, y->field->pos.file, y->field->pos.line);
        y->field->func->sref = 1;
        y = y->next;
    }
}

static int add_seen_field(struct lnode *n)
{
    if (n->op == Uop_Field) {
        struct lnode_field *x = (struct lnode_field *)n;
        struct lclass_field_ref *ref;
        struct lclass_field *f;

        /* Check for the lhs of the field being an explicit class */
        if (get_class_field_ref(x, 0, &ref)) {
            f = ref->field;
            /* If it's a method, mark it as referenced; it will be
             * scanned on the next loop if needed. Otherwise, it
             * is a variable, so just ignore it.  Note that f may
             * be an instance method, being a reference to an
             * overridden method in a superclass (eg
             * "Dialog.new()").
             */
            if (f->func)
                f->func->sref = 1;
        } else {
            /* Something else, so check for all methods with that
             * field name that are accessible from here.
             */
            struct method2 *y = get_methods_named(x->fname);
            while (y) {
                f = y->field;
                if (!f->func->sref) {
                    if (check_access(curr_vfunc, f)) {
                        f->func->sref = 1;
                        if (verbose > 4) {
                            fprintf(stderr, "Marking method %s (%s:%d) accessible from ",
                                    f->name, f->pos.file, f->pos.line);
                            if (curr_vfunc->proc)
                                fprintf(stderr, "procedure %s ", curr_vfunc->proc->name);
                            else
                                fprintf(stderr, "method %s.%s ",
                                        curr_vfunc->method->class->global->name, curr_vfunc->method->name);
                            fprintf(stderr, "(%s:%d)\n", n->loc.file, n->loc.line);
                        }
                    }
                }
                y = y->next;
            }
        }
    }
    return 1;
}

static void freference(struct lfunction *lf)
{
    struct lentry *le;
    if (lf->ref)
        return;
    lf->ref = 1;

    /*
     * Mark all the globals used as referenced.
     */
    for (le = lf->locals; le; le = le->next) {
        if (le->l_flag & F_Global)
            reference2(le->l_val.global);
    }

    /*
     * Note all the field usages.
     */
    visitfunc_post(lf, add_seen_field);
}

static void reference2(struct gentry *gp)
{
    struct lclass_ref *sup;

    if (gp->ref)
        return;
    gp->ref = 1;

    if (gp->func) {
        /*
         * Top level procedure.
         */
        freference(gp->func);
    } else if (gp->class) {
        /* Class; mark all the superclasses.  Note that we don't go through
         * the methods and reference them at this point.
         */
        for (sup = gp->class->resolved_supers; sup; sup = sup->next) 
            reference2(sup->class->global);
    }
}

void scanrefs2()
{
    struct linvocable *inv;
    struct lclass *cp;
    struct lclass_field *lm;
    struct lclass_field_ref *lr;
    int changed;

    /*
     * Reset memory.
     */
    clear_refs();

    /*
     * Note all methods in a table indexed by method name.
     */
    for (cp = lclasses; cp; cp = cp->next) {
        struct lclass_field *lm;
        for (lm = cp->fields; lm; lm = lm->next) {
            if (lm->func && !(lm->flag & (M_Optional | M_Abstract | M_Native)))
                put_method(lm);
        }
    }

    /*
     * "new" and "init" are always used.
     */
    mark_all_methods_named(new_string);
    mark_all_methods_named(init_string);

    /*
     * Start scanning with main.
     */
    reference2(gmain);

    /*
     * Reference invocable declarations
     */
    for (inv = linvocables; inv; inv = inv->iv_link) {
        if (*inv->iv_name == '.')
            /* A field name */
            mark_all_methods_named(intern(inv->iv_name + 1));
        else {
            /* A global; if a class reference all its methods (inherited ones too). */
            reference2(inv->resolved);
            if (inv->resolved->class) {
                for (lr = inv->resolved->class->implemented_class_fields; lr; lr = lr->next) {
                    if (lr->field->func)
                        lr->field->func->sref = 1;
                }
            }
        }
    }

    /*
     * Loop until no changes are made.
     */
    do {
        changed = 0;
        /*
         * For each referenced class, ensure we have referenced all
         * methods with names in the seen set.
         */
        for (cp = lclasses; cp; cp = cp->next) {
            if (cp->global->ref) {
                for (lm = cp->fields; lm; lm = lm->next) {
                    if (lm->func && !lm->func->ref && lm->func->sref) {
                        freference(lm->func);
                        ++changed;
                    }
                }
            }
        }
        if (verbose > 3)
            report("Discard loop made %d changes", changed);
    } while (changed);

    /*
     * Rebuild global lists.
     */
    rebuild_lists();

    /*
     * Mark methods we can remove.
     */
    for (cp = lclasses; cp; cp = cp->next) {
        struct lclass_field *lm;
        for (lm = cp->fields; lm; lm = lm->next) {
            if (lm->func && !lm->func->ref && !(lm->flag & (M_Optional | M_Abstract | M_Native))) {
                if (verbose > 2) 
                    report("Discarding method    %s.%s", cp->global->name, lm->name);
                lm->flag |= M_Removed;
            }
        }
    }

    /*
     * Free memory used in the method table.
     */
    mb_free(&ref2_mb);
    ArrClear(methods);
}

/*
 * Mark every global and file as unreferenced.
 */
static void clear_refs()
{
    struct gentry *gp;
    struct lclass *cp;
    struct lclass_field *lm;
    struct lfile *lf;

    for (gp = lgfirst; gp; gp = gp->g_next) {
        gp->ref = 0;
        if (gp->func)
            gp->func->ref = gp->func->sref = 0;
    }

    for (cp = lclasses; cp; cp = cp->next) {
        for (lm = cp->fields; lm; lm = lm->next) {
            if (lm->func)
                lm->func->ref = lm->func->sref = 0;
        }
    }

    for (lf = lfiles; lf; lf = lf->next)
        lf->ref = 0;
}
