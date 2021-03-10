#include "icont.h"
#include "link.h"
#include "lsym.h"
#include "lmem.h"
#include "resolve.h"
#include "tmain.h"

struct lclass_ref_list
{
    struct lclass_ref *first, *last;
};

static void merge(struct lclass *cl, struct lclass *super);
static void check_overrides(struct lclass *cl);
static void add_lclass_ref(struct lclass_ref_list *l, struct lclass *c);
static int is_empty(struct lclass_ref_list **arg);
static void check_head_del(struct lclass_ref_list *l, struct lclass *v);
static int tail_search(struct lclass_ref_list **arg, struct lclass *h);
static int merge1_c3(struct lclass_ref_list *res, struct lclass_ref_list **arg);
static int merge_c3(struct lclass_ref_list *res, struct lclass_ref_list **arg);
static struct lclass_ref_list *linearize_c3(struct lclass *base, struct lclass *cl);

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

static int other_package(struct lfile *lf, struct gentry *gl)
{
    return lf->package_id != 1 &&
        (gl->defined->package_id != lf->package_id);
}

static struct gentry *check_package_access(struct lfile *lf, struct gentry *gl)
{
    if (gl &&
        (gl->g_flag & (F_Package|F_Readable)) == F_Package &&
        other_package(lf, gl))
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
            abs = join(fp->name, ".", name, NullPtr);
            return check_package_access(lf, glocate(abs));
        }
        case I_Some: {
            is = lookup_fimport_symbol(fp, name);
            if (!is)
                return 0;
            abs = join(fp->name, ".", name, NullPtr);
            gl = check_package_access(lf, glocate(abs));
            if (!gl)
                return 0;
            is->used = 1;
            return gl;
        }
        case I_Except: {
            abs = join(fp->name, ".", name, NullPtr);
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
        rres_found = glocate(join(lf->package, ".", name, NullPtr));
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
        cfr = lookup_implemented_field_ref(class, lp->name);
        if (cfr) {
            /*
             * If we're in a static method, then the field (method or
             * var) must also be static.
             */
            if ((func->method->flag & M_Static) && !(cfr->field->flag & M_Static))
                lfatal(func->defined, &lp->pos,
                       "Can't implicitly reference a non-static field '%s' from static %s", 
                       cfr->field->name, function_name(func));

            else if (cfr->static_redef && func->method->class != cfr->field->class) {
                lfatal2(func->defined, &lp->pos, &cfr->field->pos, ") and must be explicitly referenced",
                       "Static field '%s' was overridden in %s (", 
                        cfr->field->name,
                        cfr->field->class->global->name
                        );
                print_see_also(cfr->static_redef->class);
            } else {
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
    struct lclass *cl;
    struct gentry *rsup;
    struct lclass_super *sup;
    struct lclass_ref *el;

    for (cl = lclasses; cl; cl = cl->next) {
        for (sup = cl->supers; sup; sup = sup->next) {
            rsup = resolve_super(cl, sup);
            if (rsup) {
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

static void check_overrides(struct lclass *cl)
{
    struct lclass_field_ref *fr;
    for (fr = cl->implemented_class_fields; fr; fr = fr->next) {
        if (fr->field->flag & M_Override && !fr->overrode) {
            lfatal(fr->field->class->global->defined,
                   &fr->field->pos,
                   "Method %s in class %s marked override, but didn't override another method",
                   fr->field->name,
                   fr->field->class->global->name);
        }
    }
}

static void merge(struct lclass *cl, struct lclass *super)
{
    struct lclass_field *f;
    struct lclass_ref *cr;

    if (cl != super) {
        /* Check that the superclass isn't final */
        if (super->flag & M_Final)
            lfatal(cl->global->defined,
                   &cl->global->pos,
                   "Class %s cannot inherit from %s, which is marked final", 
                   cl->global->name, super->global->name);
        /* Check that the superclass isn't protected and in another package */
        if ((super->flag & M_Protected) &&
            other_package(cl->global->defined, super->global))
            lfatal(cl->global->defined,
                   &cl->global->pos,
                   "Class %s cannot inherit from %s, which is marked protected and is in a different package", 
                   cl->global->name, super->global->name);
    }

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
        struct lclass_field_ref *fr;
        fr = lookup_implemented_field_ref(cl, f->name);
        if (fr) {
            /* Found, check consistency.  Both old (fr) and new field
             * (f) must be static, OR both old and new fields must be
             * instance methods (ie classic method overriding).
             */
            if (!( (f->flag & M_Static) && (fr->field->flag & M_Static)) &&
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
                        "Method %s encountered in class %s overrides a final method in class %s (",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name
                    );
                if (fr->field->class != cl)
                    print_see_also(cl);
            } else if (((f->flag & (M_Method | M_Static | M_Package)) == (M_Method | M_Package)) &&
                       other_package(f->class->global->defined, fr->field->class->global)) {
                lfatal2(fr->field->class->global->defined,
                        &fr->field->pos, &f->pos, ")",
                        "Method %s encountered in class %s overrides a package method in a class from another package, %s (",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name
                    );
                if (fr->field->class != cl)
                    print_see_also(cl);
            } else if (((f->flag & (M_Method | M_Static | M_Private)) == (M_Method | M_Private))) {
                lfatal2(fr->field->class->global->defined,
                        &fr->field->pos, &f->pos, ")",
                        "Method %s encountered in class %s overrides a private method in class %s (",
                        f->name,
                        fr->field->class->global->name,
                        f->class->global->name
                    );
                if (fr->field->class != cl)
                    print_see_also(cl);
            }

            /*
             * Set the static_redef field of the existing field
             * reference if we have overridden a static, so that later
             * implicit uses of the field are reported as errors.
             */
            if ( (f->flag & M_Static) && (fr->field->flag & M_Static) &&
                 /* On errors, note the first redefinition */
                !fr->static_redef)
            {
                fr->static_redef = f;
            }

            /*
             * Check override flags for an overridden instance method.
             */
            if (((fr->field->flag & (M_Method | M_Static)) == M_Method) &&
                ((f->flag & (M_Method | M_Static)) == M_Method)) 
            {
                if (fr->field->flag & M_Override) {
                    fr->overrode = 1;
                } else {
                    lfatal2(fr->field->class->global->defined,
                            &fr->field->pos, &f->pos, ") without setting override modifier",
                            "Method %s in class %s overrides a method in class %s (",
                            f->name,
                            fr->field->class->global->name,
                            f->class->global->name
                        );
                    if (fr->field->class != cl)
                        print_see_also(cl);
                }
            }
        } else {
            /* Not found, so add it */
            fr = Alloc(struct lclass_field_ref);
            fr->field = f;
            add_to_hash(&cl->implemented_field_hash, fr);
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

static int seen_no = 0;
static struct membuff c3_mb = {"C3 calculation membuff", 64000, 0,0,0 };
#define C3Alloc(type)   mb_zalloc(&c3_mb, sizeof(type))
#define C3Alloc1(type)   mb_alloc(&c3_mb, sizeof(type))

void compute_inheritance()
{
    struct lclass *cl;
    struct lrecord *rec;
    for (cl = lclasses; cl; cl = cl->next) {
        if (!cl->implemented_classes) {
            /* Flag value for checking if a class has been seen.  Doing it this way saves
             * setting all flags to zero each time.  */
            ++seen_no;
            linearize_c3(cl, cl);
            mb_clear(&c3_mb);
        }
        check_overrides(cl);
        if (cl->n_implemented_class_fields + cl->n_implemented_instance_fields > 0xffff)
            lfatal(cl->global->defined,
                   &cl->global->pos,
                   "Class %s has too many fields", 
                   cl->global->name);

    }
    mb_free(&c3_mb);

    for (rec = lrecords; rec; rec = rec->next) {
        if (rec->nfields > 0xffff)
            lfatal(rec->global->defined,
                   &rec->global->pos,
                   "Record %s has too many fields", 
                   rec->global->name);
    }
}

/*
 * Add a class to the end of the given list.
 */
static void add_lclass_ref(struct lclass_ref_list *l, struct lclass *c)
{
    struct lclass_ref *v = C3Alloc1(struct lclass_ref);
    v->class = c;
    v->next = 0;
    if (l->last) {
        l->last->next = v;
        l->last = v;
    } else
        l->first = l->last = v;
}

/*
 * Check if all of the lists in the given array of lists are empty.
 */
static int is_empty(struct lclass_ref_list **arg)
{
    for (; *arg; ++arg) {
        if ((*arg)->first)
            return 0;
    }
    return 1;
}

/*
 * Delete v from l, if it is the first element.
 */
static void check_head_del(struct lclass_ref_list *l, struct lclass *v)
{
    if (l->first && l->first->class == v) {
        if (l->first == l->last)
            l->first = l->last = 0;
        else
            l->first = l->first->next;
    }
}

/*
 * Check if class h is in the tail of any lists in the array arg.
 */
static int tail_search(struct lclass_ref_list **arg, struct lclass *h)
{
    for (; *arg; ++arg) {
        if ((*arg)->first) {
            struct lclass_ref *x;
            for (x = (*arg)->first->next; x; x = x->next)
                if (x->class == h)
                    return 1;
        }
    }
    return 0;
}

static int merge1_c3(struct lclass_ref_list *res, struct lclass_ref_list **arg)
{
    struct lclass_ref_list **a;
    for (a = arg; *a; ++a) {
        if ((*a)->first) {
            struct lclass *h = (*a)->first->class;
            if (!tail_search(arg, h)) {
                add_lclass_ref(res, h);
                for (a = arg; *a; ++a)
                    check_head_del(*a, h);
                return 1;
            }
        }
    }
    return 0;
}

static int merge_c3(struct lclass_ref_list *res, struct lclass_ref_list **arg)
{
    while (!is_empty(arg)) {
        if (!merge1_c3(res, arg))
            return 0;
    }
    return 1;
}

static struct lclass_ref_list *linearize_c3(struct lclass *base, struct lclass *cl)
{
    struct lclass_ref_list *res, **arg;
    struct lclass_ref *sup, *p;
    int i, narg;

    res = C3Alloc(struct lclass_ref_list);
    if (cl->implemented_classes) {
        for (p = cl->implemented_classes; p; p = p->next)
            add_lclass_ref(res, p->class);
        return res;
    }

    add_lclass_ref(res, cl);
    if (cl->seen == seen_no) {
        lfatal(cl->global->defined, &cl->global->pos,
               "Failed to compute inheritance list (circular inheritance on class %s)", cl->global->name);
        if (base != cl)
            print_see_also(base);
    } else {
        /* The recursive result of the supers plus this class's list of supers plus a null terminator. */
        narg = cl->n_supers + 2;
        arg = mb_alloc(&c3_mb, narg * sizeof(struct lclass_ref_list));

        i = 0;
        cl->seen = seen_no;
        for (sup = cl->resolved_supers; sup; sup = sup->next)
            arg[i++] = linearize_c3(base, sup->class);
        cl->seen = 0;

        arg[i] = C3Alloc(struct lclass_ref_list);
        for (sup = cl->resolved_supers; sup; sup = sup->next)
            add_lclass_ref(arg[i], sup->class);
        ++i;
        arg[i++] = 0;
        if (i != narg)
            quit("I got my supers counting wrong.");

        if (!merge_c3(res, arg)) {
            lfatal(cl->global->defined, &cl->global->pos,
                   "Failed to compute inheritance list for class %s", cl->global->name);
            if (base != cl)
                print_see_also(base);
        }
    }

    for (p = res->first; p; p = p->next)
        merge(cl, p->class);

    return res;
}

static struct gentry *resolve_invocable(struct linvocable *inv)
{
    if (*inv->iv_name == '.')
        return 0;
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
