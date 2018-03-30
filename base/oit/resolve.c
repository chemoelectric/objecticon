#include "icont.h"
#include "link.h"
#include "lsym.h"
#include "lmem.h"
#include "resolve.h"
#include "tmain.h"

static void merge(struct lclass *cl, struct lclass *super);

/*
 * Names of builtin functions.
 */
static char *builtin_table[] = {
#define FncDef(p) #p,
#include "../h/fdefs.h"
#undef FncDef
};

static int builtin_table_cmp(char *key, char **item)
{
    return strcmp(key, *item);
}

/*
 * Lookup a builtin function name; returns -1 if not found, or the
 * index otherwise.
 */
static int blookup(char *s)
{
    char **p = bsearch(s, builtin_table, ElemCount(builtin_table), 
                       sizeof(char *), (BSearchFncCast)builtin_table_cmp);
    if (!p)
        return -1;

    return p - builtin_table;
}

/*
 * Just like glocate, but if the symbol is not found then it checks
 * for a builtin function as well.
 */
static struct gentry *gb_locate(char *name)
{
    struct gentry *gl = glocate(name);
    int bn;
    if (!gl && (bn = blookup(name)) >= 0) {	
        struct loc bl = {"Builtin", 0};
        /* Builtin function, add to global table so we see it next time */
        gl = putglobal(name, F_Builtin | F_Proc, 0, &bl);
        gl->builtin = Alloc(struct lbuiltin);
        gl->builtin->builtin_id = bn;
    }
    return gl;
}

static struct gentry *rres_found, *rres_ambig;

static void print_clash(void)
{
    fprintf(stderr, "\t%s (", rres_found->name);
    begin_link(stderr, rres_found->pos.file, rres_found->pos.line);
    fprintf(stderr, "File %s; Line %d", 
            abbreviate(rres_found->pos.file), rres_found->pos.line);
    end_link(stderr);
    fprintf(stderr, ")\n\t%s (", rres_ambig->name);
    begin_link(stderr, rres_ambig->pos.file, rres_ambig->pos.line);
    fprintf(stderr, "File %s; Line %d", 
            abbreviate(rres_ambig->pos.file), rres_ambig->pos.line);
    end_link(stderr);
    fputs(")\n", stderr);
}

static void print_see_also(struct lclass *cl)
{
    struct loc *pos = &cl->global->pos;
    fprintf(stderr, "\tSee also class %s (", cl->global->name);
    begin_link(stderr, pos->file, pos->line);
    fprintf(stderr, "File %s; Line %d", 
            abbreviate(pos->file), pos->line);
    end_link(stderr);
    fputs(")\n", stderr);
}

static struct gentry *check_package_access(struct lfile *lf, struct gentry *gl)
{
    if (gl &&
        (gl->g_flag & (F_Package|F_Readable)) == F_Package &&
        lf->package_id != 1 &&
        gl->defined->package_id != lf->package_id)
        gl = 0;
    return gl;
}

static struct gentry *try_import_lookup(struct lfile *lf, struct fimport *fp, char *name)
{
    char *abs;
    struct fimport_symbol *is;
    struct gentry *gl;

    switch (fp->mode) {
        case I_All: {
            abs = join(fp->name, ".", name, NULL);
            return check_package_access(lf, glocate(abs));
        }
        case I_Some: {
            is = lookup_fimport_symbol(fp, name);
            if (!is)
                return 0;
            abs = join(fp->name, ".", name, NULL);
            gl = check_package_access(lf, glocate(abs));
            if (!gl)
                return 0;
            is->used = 1;
            return gl;
        }
        case I_Except: {
            abs = join(fp->name, ".", name, NULL);
            gl = check_package_access(lf, glocate(abs));
            if (!gl)
                return 0;
            is = lookup_fimport_symbol(fp, name);
            if (is) {
                is->used = 1;
                return 0;
            }
            return gl;
        }
        default:
            quit("Illegal fimport mode");
    }
    /* Not reached */
    return 0;
}

/*
 * Resolve the given name in the given file to a global entry.  There
 * are three possible results, as indicated by the variables
 * rres_found and rres_ambig, namely no match (neither set), exactly
 * one match (rres_found set), or an ambiguous match (both set).
 */
static void resolve_global(struct lfile *lf, char *name)
{
    char *dot;
    struct fimport *fp;
    struct gentry *gl;
    static struct str_buf resolve_sbuf;

    rres_found = rres_ambig = 0;

    /*
     * Easy case is if it's an absolute specification.
     */
    if ((dot = strrchr(name, '.'))) {
        char *t, *package;
        /* 
         * Get the package name 
         */
        zero_sbuf(&resolve_sbuf);
        for (t = name; t != dot; ++t)
            AppChar(resolve_sbuf, *t);
        package = str_install(&resolve_sbuf);
        /*
         * If the package is "default", just convert the name to its
         * unqualified form.  Otherwise if it's not in the file's
         * package, note the corresponding import as used.
         */
        if (package == default_string)
            name = intern(dot + 1);
        else if (lf->package != package) {
            struct fimport *im = lookup_fimport(lf, package);
            if (!im)
                quit("Couldn't find import %s in file %s", package, lf->name);
            im->used = 1;
        }
        rres_found = check_package_access(lf, gb_locate(name));
        return;
    }

    /*
     * If we are in a package, try that first, otherwise try the
     * toplevel first.
     */
    if (lf->package)
        rres_found = glocate(join(lf->package, ".", name, NULL));
    else
        rres_found = gb_locate(name);

    /*
     * Now try the imports in turn.
     */
    for (fp = lf->imports; fp; fp = fp->next) {
        /*
         * If it matches the import spec...
         */
        if ((gl = try_import_lookup(lf, fp, name))) {
            fp->used = 1;
            if (rres_found) {
                rres_ambig = gl;
                return;
            }
            rres_found = gl;
        }
    }

    /*
     * If not found yet, and not tried already, try as an unqualified
     * top level symbol, which must be a builtin.
     */
    if (lf->package && !rres_found) {
        gl = gb_locate(name);
        if (gl && gl->g_flag & F_Builtin)
            rres_found = gl;
    }
}

/*
 * Resolve local entry lp in function func.  lp represents a symbol
 * encountered in the the function - it may be an argument, local,
 * static, class field, builtin or global.  This function decides
 * which it is and sets the flags in lp accordingly.
 */
void resolve_local(struct lfunction *func, struct lentry *lp)
{
    struct lclass *class;
    struct lclass_field_ref *cfr;
    int i;

    /*
     * If flags is set, then we already know what sort of local it is
     * - argument, dynamic or static.
     */
    if (lp->l_flag) {
        if (lp->l_flag & F_Argument)			/* procedure argument */
            lp->l_val.index = func->narguments++;
        else if (lp->l_flag & F_Dynamic)			/* local */
            lp->l_val.index = func->ndynamic++;
        else if (lp->l_flag & F_Static) {		/* static */
            /* Note that the static's index number is set later, during code generation */
            ++func->nstatics;
        } else
            quit("resolve_local: Unknown flags");
        return;
    }

    if (func->method) {
        /*
         * It's a method, so we look for a match in the class's fields.
         */
        class = func->method->class;
        i = hasher(lp->name, class->implemented_field_hash);
        cfr = class->implemented_field_hash[i];
        while (cfr && cfr->field->name != lp->name)
            cfr = cfr->b_next;
        if (cfr) {
            /*
             * If we're in a static method, then the field (method or
             * var) must also be static.
             */
            if ((func->method->flag & M_Static) && !(cfr->field->flag & M_Static))
                lfatal(func->defined, &lp->pos,
                       "Can't implicitly reference a non-static field '%s' from static %s", 
                       cfr->field->name, function_name(func));
            else {
                lp->l_flag |= F_Field;
                lp->l_val.field = cfr->field;
            }
            return;
        }
    }

    /*
     * Try it as a global.
     */
    resolve_global(func->defined, lp->name);
    if (rres_ambig) {
        lfatal(func->defined, &lp->pos,
               "Symbol '%s' resolves to multiple targets in %s :-", 
               lp->name, function_name(func));
        print_clash();
        return;
    }
    if (!rres_found) {
        lfatal(func->defined, &lp->pos,
               "Undeclared identifier '%s' in %s", 
               lp->name, function_name(func));
        return;
    }

    /*
     * Successfully found as a global
     */
    lp->l_flag = F_Global;
    if (rres_found->g_flag & F_Builtin)
        lp->l_flag |= F_Builtin;
    lp->l_val.global = rres_found;
}

static struct gentry *resolve_super(struct lclass *class, struct lclass_super *super)
{
    resolve_global(class->global->defined, super->name);
    if (rres_ambig) {
        lfatal(class->global->defined, &super->pos,
               "Superclass of class %s, '%s', resolves to multiple targets:-", 
               class->global->name, super->name);
        print_clash();
        return 0;
    }
    if (!rres_found) {
        lfatal(class->global->defined, &super->pos,
               "Couldn't resolve superclass of class %s: '%s'",
               class->global->name, super->name);
        return 0;
    }
    if (!rres_found->class) {
        lfatal(class->global->defined, &super->pos,
               "Superclass of %s, '%s', is not a class",
               class->global->name, super->name);
        return 0;
    }
    return rres_found;
}

void resolve_supers()
{
    struct lclass *cl, *x;
    struct gentry *rsup;
    struct lclass_super *sup;
    struct lclass_ref *el;

    for (cl = lclasses; cl; cl = cl->next) {
        for (sup = cl->supers; sup; sup = sup->next) {
            rsup = resolve_super(cl, sup);
            if (rsup) {
                x = rsup->class;
                /* Check that the superclass isn't final */
                if (x->flag & M_Final)
                    lfatal(cl->global->defined,
                           &cl->global->pos,
                           "Class %s cannot inherit from %s, which is marked final", 
                           cl->global->name, x->global->name);
                el = Alloc(struct lclass_ref);
                el->class = rsup->class;
                if (cl->last_resolved_super) {
                    cl->last_resolved_super->next = el;
                    cl->last_resolved_super = el;
                } else
                    cl->resolved_supers = cl->last_resolved_super = el;
                ++cl->n_supers;
            }
        }
    }
}

static void compute_impl(struct lclass *cl)
{
    struct lclass_ref *queue = 0, *queue_last = 0, *t, *u;
    struct lclass *x;
    static int seen_no = 0;

    /* Flag value for checking if a class has been seen.  Doing it this way saves
     * setting all flags to zero each time.  */
    ++seen_no;

    /* Init the queue with the class to resolve */
    queue_last = queue = Alloc(struct lclass_ref);
    queue->class = cl;

    /* Carry out a breadth first traversal of the class hierarchy */
    /* When the queue is empty, we've finished */
    while (queue) {
        /* Pop one of the front */
        t = queue;
        x = queue->class;
        queue = queue->next;
        if (!queue)
            queue_last = 0;
        free(t);
        
        /* If we've seen it, just go round again */
        if (x->seen == seen_no)
            continue;

        /* We have an implemented superclass, so merge methods etc into our
         * class.
         */
        x->seen = seen_no;
        merge(cl, x);

        /* And add all its unseen supers to the queue */
        for (t = x->resolved_supers; t; t = t->next) {
            if (t->class->seen == seen_no)
                continue;
            u = Alloc(struct lclass_ref);
            u->class = t->class;
            if (queue_last) {
                queue_last->next = u;
                queue_last = u;
            } else
                queue = queue_last = u;
        }
    }
}

static void merge(struct lclass *cl, struct lclass *super)
{
    struct lclass_ref *cr;
    struct lclass_field *f;

    /* Add a reference to super into the implemented_classes list. */
    cr = Alloc(struct lclass_ref);
    cr->class = super;
    if (cl->last_implemented_class) {
        cl->last_implemented_class->next = cr;
        cl->last_implemented_class = cr;
    } else
        cl->implemented_classes = cl->last_implemented_class = cr;
    ++cl->n_implemented_classes;

    /* Merge in any new fields */
    for (f = super->fields; f; f = f->next) {
        /* Do we already have a field with this name? */
        int i = hasher(f->name, cl->implemented_field_hash);
        struct lclass_field_ref *fr = cl->implemented_field_hash[i];
        while (fr && fr->field->name != f->name)
            fr = fr->b_next;
        if (fr) {
            /* Found, check consistency.  The new field (f) must be
             * static, OR both old and new fields must be instance
             * methods (ie classic method overriding).
             */
            if (!(f->flag & M_Static) &&
                !(((fr->field->flag & (M_Method | M_Static)) == M_Method) 
                  && ((f->flag & (M_Method | M_Static)) == M_Method))) {
                lfatal2(fr->field->class->global->defined,
                        &fr->field->pos, &f->pos, ")",
                        "Inheritance clash: field '%s' encountered in class %s and class %s (",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name
                    );
                if (fr->field->class != cl)
                    print_see_also(cl);
            }
            /*
             * If the new field is final, then fr cannot override it.  Note that the translator
             * ensures only non-static methods can be marked final.
             */
            else if (f->flag & M_Final) {
                lfatal2(fr->field->class->global->defined,
                        &fr->field->pos, &f->pos, ")",
                        "Field %s encountered in class %s overrides a final field in class %s (",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name
                    );
                if (fr->field->class != cl)
                    print_see_also(cl);
            }
        } else {
            /* Not found, so add it */
            fr = Alloc(struct lclass_field_ref);
            fr->field = f;
            fr->b_next = cl->implemented_field_hash[i];
            cl->implemented_field_hash[i] = fr;
            if (f->flag & (M_Method | M_Static)) {
                if (!(cl->flag & M_Abstract) && (f->flag & M_Abstract))
                    lfatal2(cl->global->defined, &cl->global->pos, &f->pos, "), but is not itself declared abstract",
                            "Resolved class %s contains an abstract method %s (",
                            cl->global->name, f->name);

                if (cl->last_implemented_class_field) {
                    cl->last_implemented_class_field->next = fr;
                    cl->last_implemented_class_field = fr;
                } else
                    cl->implemented_class_fields = cl->last_implemented_class_field = fr;
                ++cl->n_implemented_class_fields;
            } else {
                if (cl->last_implemented_instance_field) {
                    cl->last_implemented_instance_field->next = fr;
                    cl->last_implemented_instance_field = fr;
                } else
                    cl->implemented_instance_fields = cl->last_implemented_instance_field = fr;
                ++cl->n_implemented_instance_fields;
            }
        }
    }
}

void compute_inheritance()
{
    struct lclass *cl;
    for (cl = lclasses; cl; cl = cl->next) 
        compute_impl(cl);
}

static struct gentry *resolve_invocable(struct linvocable *inv)
{
    resolve_global(inv->defined, inv->iv_name);
    if (rres_ambig) {
        lfatal(inv->defined, &inv->pos, 
               "Invocable '%s' resolves to multiple targets:-", inv->iv_name);
        print_clash();
        return 0;
    }
    if (!rres_found) {
        lfatal(inv->defined, &inv->pos, 
               "Couldn't resolve invocable '%s'", inv->iv_name);
        return 0;
    }
    return rres_found;
}

void resolve_invocables()
{
    struct linvocable *inv;
    for (inv = linvocables; inv; inv = inv->iv_link)
        inv->resolved = resolve_invocable(inv);
}

void add_functions()
{
#define FncDef(p) gb_locate(intern(#p));
#include "../h/fdefs.h"
#undef FncDef
}
