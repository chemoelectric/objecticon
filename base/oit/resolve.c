#include <stdio.h>

#include "icont.h"
#include "link.h"
#include "lsym.h"
#include "lmem.h"
#include "util.h"
#include "resolve.h"
#include "tmain.h"

static void merge(struct lclass *cl, struct lclass *super);

/*
 * Just like glocate, but if the symbol is not found then it checks
 * for a builtin function as well.
 */
static struct gentry *gb_locate(char *name)
{
    struct gentry *gl = glocate(name);
    int bn;
    if (!gl && (bn = blocate(name))) {	
        struct loc bl = {"Builtin", 0};
        /* Builtin function, add to global table so we see it next time */
        gl = putglobal(name, F_Builtin | F_Proc, 0, &bl);
        gl->builtin = New(struct lbuiltin);
        gl->builtin->builtin_id = bn;
    }
    return gl;
}

static struct gentry *rres_found, *rres_ambig;

static void print_clash()
{
    fprintf(stderr, "\t\t%s (%s: Line %d)\n", 
            rres_found->name, abbreviate(rres_found->pos.file), rres_found->pos.line);
    fprintf(stderr, "\t\t%s (%s: Line %d)\n", 
            rres_ambig->name, abbreviate(rres_ambig->pos.file), rres_ambig->pos.line);
}

/*
 * Resolve the given name in the given file to a global entry.  There
 * are three possible results, as indicated by the variables
 * rres_found and rres_ambig, namely no match (neither set), exactly
 * one match (rres_found set), or an ambiguous match (both set).
 */
static void resolve_global(struct lfile *lf, char *name)
{
    char *abs, *dot;
    struct fimport *fp;
    struct gentry *gl;

    rres_found = rres_ambig = 0;

    /*
     * Easy case is if it's an absolute specification.
     */
    if ((dot = rindex(name, '.'))) {
        char *t, *package;
        /* 
         * Get the package name 
         */
        zero_sbuf(&link_sbuf);
        for (t = name; t != dot; ++t)
            AppChar(link_sbuf, *t);
        package = str_install(&link_sbuf);
        /*
         * If the package is "default", just convert the name to its
         * unqualified form.  Otherwise if it's not in the file's
         * package, note the corresponding import (if any) as used.
         * There may be no corresponding import if we have a super or
         * an invocable that was specified as a fully qualified
         * symbol, but without a matching import; however this will
         * have generated a warning on translation.
         */
        if (package == default_string)
            name = intern_using(&link_sbuf, dot + 1);
        else if (lf->package != package) {
            struct fimport *im = lookup_fimport(lf, package);
            if (im)
                im->used = 1;
        }
        rres_found = gb_locate(name);
        return;
    }

    /*
     * If we are in a package, try that first, otherwise try the
     * toplevel first.
     */
    if (lf->package)
        rres_found = glocate(join_strs(&link_sbuf, 3, lf->package, ".", name));
    else
        rres_found = gb_locate(name);

    /*
     * Now try the imports in turn.
     */
    for (fp = lf->imports; fp; fp = fp->next) {
        struct fimport_symbol *is = 0;
        /*
         * If it's unqualified, or has the symbol...
         */
        if (!fp->qualified || (is = lookup_fimport_symbol(fp, name))) {
            abs = join_strs(&link_sbuf, 3, fp->name, ".", name);
            gl = glocate(abs);
            if (gl) {
                fp->used = 1;
                if (is)
                    is->used = 1;
                if (rres_found) {
                    rres_ambig = gl;
                    return;
                }
                rres_found = gl;
            }
        }
    }

    /*
     * If not found yet, and not tried already, try as a unqualified
     * top level symbol.
     */
    if (lf->package && !rres_found)
        rres_found = gb_locate(name);
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
            lp->l_val.offset = ++func->argoff;
        else if (lp->l_flag & F_Dynamic)			/* local dynamic */
            lp->l_val.offset = ++func->dynoff;
        else if (lp->l_flag & F_Static) {			/* local static */
            /* Note that the staticid field is set later, during code generation */
            ++func->nstatics;
        } else
            quit("putlocal: unknown flags");
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
                lfatal(&lp->pos,
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
        lfatal(&lp->pos,
                "Symbol '%s' resolves to multiple targets in %s :-", 
                lp->name, function_name(func));
        print_clash();
        return;
    }
    if (!rres_found) {
        lfatal(&lp->pos,
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
    resolve_global(class->defined, super->name);
    if (rres_ambig) {
        lfatal(&super->pos,
                "Superclass of class %s, '%s', resolves to multiple targets:-", 
                class->global->name, super->name);
        print_clash();
        return 0;
    }
    if (!rres_found) {
        lfatal(&super->pos,
                "Couldn't resolve superclass of class %s: '%s'",
                class->global->name, super->name);
        return 0;
    }
    if (!rres_found->class) {
        lfatal(&super->pos,
                "Superclass of %s, '%s', is not a class",
                class->global->name, super->name);
        return 0;
    }
    return rres_found;
}

void resolve_supers()
{
    struct lclass *cl;
    struct gentry *rsup;
    struct lclass_super *sup;
    struct lclass_ref *el;

    for (cl = lclasses; cl; cl = cl->next) {
        for (sup = cl->supers; sup; sup = sup->next) {
            rsup = resolve_super(cl, sup);
            if (rsup) {
                el = New(struct lclass_ref);
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

    /* Reset all seen flags of all classes */
    for (x = lclasses; x; x = x->next)
        x->seen = 0;

    /* Init the queue with the class to resolve */
    queue_last = queue = New(struct lclass_ref);
    queue->class = cl;

    /* Carry out a breadth first traversal of the class hierarchy */
    for (;;) {
        /* When the queue is empty, we've finished */
        if (!queue)
            return;

        /* Pop one of the front */
        t = queue;
        x = queue->class;
        queue = queue->next;
        if (!queue)
            queue_last = 0;
        free(t);
        
        /* If we've seen it, just go round again */
        if (x->seen)
            continue;

        /* Check that the superclass isn't final */
        if (x != cl && (x->flag & M_Final))
            lfatal(&cl->global->pos,
                    "Class %s cannot inherit from %s, which is marked final", 
                    cl->global->name, x->global->name);

        /* We have an implemented superclass, so merge methods etc into our
         * class.
         */
        x->seen = 1;
        merge(cl, x);

        /* And add all its unseen supers to the queue */
        for (t = x->resolved_supers; t; t = t->next) {
            if (t->class->seen)
                continue;
            u = New(struct lclass_ref);
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
    cr = New(struct lclass_ref);
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
                       && ((f->flag & (M_Method | M_Static)) == M_Method)))
                lfatal(&fr->field->pos,
                        "Inheritance clash: field '%s' encountered in class %s and class %s (in file '%s', line %d)",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name,
                        abbreviate(f->pos.file),
                        f->pos.line
                    );
            /*
             * If the new field is final, then fr cannot override it.  Note that the translator
             * ensures only non-static methods can be marked final.
             */
            else if (f->flag & M_Final)
                lfatal(&fr->field->pos,
                        "Field %s encountered in class %s overrides a final field in class %s (in file '%s', line %d)",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name,
                        abbreviate(f->pos.file),
                        f->pos.line
                    );
        } else {
            /* Not found, so add it */
            fr = New(struct lclass_field_ref);
            fr->field = f;
            fr->b_next = cl->implemented_field_hash[i];
            cl->implemented_field_hash[i] = fr;
            if (f->flag & (M_Method | M_Static)) {
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
        lfatal(&inv->pos, "Invocable '%s' resolves to multiple targets:-", inv->iv_name);
        print_clash();
        return 0;
    }
    if (!rres_found) {
        lfatal(&inv->pos, "Couldn't resolve invocable '%s'", inv->iv_name);
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

