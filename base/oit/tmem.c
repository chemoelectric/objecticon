/*
 * tmem.c -- memory initialization and allocation for the translator.
 */

#include "icont.h"
#include "tmem.h"
#include "tlex.h"
#include "tsym.h"
#include "util.h"
#include "tmain.h"
#include "trans.h"
#include "package.h"

struct tgentry *ghash[GHASH_SIZE];	/* hash area for global table */
struct tgentry *gfirst;		/* first global table entry */
struct tgentry *glast;		/* last global table entry */

char *package_name = 0;
struct tfunction *functions = 0, *curr_func = 0;
struct tclass *classes = 0, *curr_class = 0;
struct timport *import_hash[64], *imports = 0, *last_import = 0, *curr_import = 0;
struct link *links = 0, *last_link = 0;
struct tinvocable *tinvocables = 0, *last_tinvocable = 0;

static void free_class_hashes(struct tclass *c);
static void free_function_hash(struct tfunction *f);

/*
 * tmalloc - allocate memory for the translator
 */

void tmalloc()
{
    init_package_db();
}

/*
 * meminit - clear tables for use in translating the next file
 */
void tminit()
{
    gfirst = glast = 0;
    clear(ghash);
    classes = curr_class = 0;
    package_name = 0;
    imports = last_import = curr_import = 0;
    clear(import_hash);
    links = last_link = 0;
    tinvocables = last_tinvocable = 0;
}

/*
 * Clear allocations used in translating one file.
 */
void tmfilefree()
{
    struct tfunction *f, *ft;
    struct tclass *c, *ct;
    struct timport *im, *tim;
    struct link *li, *tli;
    struct tinvocable *iv, *tiv;

    for (f = functions; f; f = ft) {
        free_function_hash(f);
        ft = f->next;
        free(f);
    }
    functions = curr_func = 0;

    for (c = classes; c; c = ct) {
        free_class_hashes(c);
        ct = c->next;
        free(c);
    }
    classes = curr_class = 0;

    for (im = imports; im; im = tim) {
        tim = im->next;
        free(im);
    }
    curr_import = imports = last_import = 0;
    clear(import_hash);

    for (li = links; li; li = tli) {
        tli = li->next;
        free(li);
    }
    links = last_link = 0;

    for (iv = tinvocables; iv; iv = tiv) {
        tiv = iv->next;
        free(tiv);
    }
    tinvocables = last_tinvocable = 0;
}

static void free_function_hash(struct tfunction *f)
{
    struct tlentry *lptr, *lptr1;
    struct tcentry *cptr, *cptr1;
    int i;

    /*
     * Clear local table, freeing entries.
     */
    for (i = 0; i < asize(f->lhash); i++) {
        for (lptr = f->lhash[i]; lptr != NULL; lptr = lptr1) {
            lptr1 = lptr->l_blink;
            free(lptr);
        }
        f->lhash[i] = NULL;
    }
    f->lfirst = NULL;
    f->llast = NULL;

    /*
     * Clear constant table, freeing entries.
     */
    for (i = 0; i < asize(f->chash); i++) {
        for (cptr = f->chash[i]; cptr != NULL; cptr = cptr1) {
            cptr1 = cptr->c_blink;
            free(cptr);
        }
        f->chash[i] = NULL;
    }
    f->cfirst = NULL;
    f->clast = NULL;
}

static void free_class_hashes(struct tclass *c)
{
    struct tclass_field *f1, *f2;
    struct tclass_super *s1, *s2;

    for (f1 = c->fields; f1; f1 = f2) {
        f2 = f1->b_next;
        free(f1);
    }
    for (s1 = c->supers; s1; s1 = s2) {
        s2 = s1->b_next;
        free(s1);
    }
}

/*
 * tmfree - free memory used by the translator
 */
void tmfree()
{
    struct tgentry *gp, *gp1;

    /*
     * Free global table entries.
     */
    for (gp = gfirst; gp != NULL; gp = gp1) {
        gp1 = gp->g_next;
        free((char *)gp);
    }
    gfirst = glast = 0;

    free_package_db();
}

void next_function(int flag)
{
    struct tfunction *f = New(struct tfunction);
    f->flag = flag;
    if (curr_func) {
        curr_func->next = f;
        curr_func = f;
    } else {
        curr_func = functions = f;
    }
}

void next_class(char *name, int flag, struct node *n)
{
    struct tclass *c = New(struct tclass);
    c->flag = flag;
    if (curr_class) {
        curr_class->next = c;
        curr_class = c;
    } else {
        curr_class = classes = c;
    }
    c->global = next_global(name, F_Class | F_Global, n);
    c->global->class = c;
}

void next_super(char *name, struct node *n)
{
    int i = hasher(name, curr_class->super_hash);
    struct tclass_super *cs = curr_class->super_hash[i];
    while (cs && cs->name != name)
        cs = cs->b_next;
    if (cs)
        tfatal("duplicate superclass: %s", name);
    cs = New(struct tclass_super);
    cs->b_next = curr_class->super_hash[i];
    curr_class->super_hash[i] = cs;
    cs->name = name;
    cs->pos = n;
    if (curr_class->curr_super) {
        curr_class->curr_super->next = cs;
        curr_class->curr_super = cs;
    } else
        curr_class->supers = curr_class->curr_super = cs;
}

void check_flags(int flag, struct node *n)
{
    int x = 0;
    if (flag & M_Public)
        ++x;
    if (flag & M_Private)
        ++x;
    if (flag & M_Package)
        ++x;
    if (flag & M_Protected)
        ++x;
    if (x != 1)
        tfatal_at(n, "A field must specify exactly one of public, "
                "private, protected or package: field %s in class %s", 
                curr_class->curr_field->name, curr_class->global->g_name);

    if (flag & M_Method) {
        if ((flag & (M_Static | M_Final)) == (M_Static | M_Final))
            tfatal_at(n, "A static method cannot be final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & M_Final) && (curr_class->flag & M_Final))
            tfatal_at(n, "A method cannot be final in a class marked final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if (flag & M_Const)
            tfatal_at(n, "A method cannot be const: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if (flag & M_Readable)
            tfatal_at(n, "A method cannot be readable: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);
    } else {
        if (flag & M_Final)
            tfatal_at(n, "A class variable cannot be final: field %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & (M_Public | M_Readable)) == (M_Public | M_Readable))
            tfatal_at(n, "A class variable cannot be public and readable: field %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);
    }
}

void next_field(char *name, int flag, struct node *n)
{
    int i = hasher(name, curr_class->field_hash);
    struct tclass_field *cv = curr_class->field_hash[i];
    while (cv && cv->name != name)
        cv = cv->b_next;
    if (cv)
        tfatal("duplicate class field: %s", name);
    cv = New(struct tclass_field);
    cv->b_next = curr_class->field_hash[i];
    curr_class->field_hash[i] = cv;
    cv->name = name;
    /*
     * Check for new/init fields.
     */
    if (name == init_string) {
        flag |= M_Special;
        if ((flag & (M_Method | M_Static | M_Private)) != (M_Method | M_Static | M_Private))
            tfatal_at(n, "The init field must be a private static method");
    } else if (name == new_string) {
        flag |= M_Special;
        if ((flag & (M_Method | M_Static)) != M_Method)
            tfatal_at(n, "The new field must be a non-static method");
    }
    cv->flag = flag;
    cv->pos = n;
    cv->class = curr_class;
    if (curr_class->curr_field) {
        curr_class->curr_field->next = cv;
        curr_class->curr_field = cv;
    } else 
        curr_class->fields = curr_class->curr_field = cv;
}

void next_method(char *name, int flag, struct node *n)
{
    flag |= M_Method;
    next_field(name, flag, n);
    check_flags(flag, n);
    next_function(F_Method);
    curr_class->curr_field->f = curr_func;
    curr_func->field = curr_class->curr_field;
    if (!(flag & M_Static)) {
        put_local(self_string, F_Argument, n, 1);
        curr_func->nargs = 1;
    }
}

void next_procedure(char *name, struct node *n)
{
    next_function(F_Proc);
    curr_func->global = next_global(name, F_Proc | F_Global, n);
    curr_func->global->func = curr_func;
}

struct timport *lookup_import(char *s)
{
    int i = hasher(s, import_hash);
    struct timport *x = import_hash[i];
    while (x && x->name != s)
        x = x->b_next;
    return x;
}

void set_package(char *s)
{
    if (package_name)
        tfatal("duplicate package declaration: %s", s);
    if (functions || classes)
        tfatal("package declaration must precede procedure/class declarations");
    package_name = s;
}

void next_import(char *s, int qualified, struct node *n)
{
    int i = hasher(s, import_hash);
    struct timport *x = import_hash[i];
    if (functions || classes)
        tfatal("import declaration must precede procedure/class declarations");
    while (x && x->name != s)
        x = x->b_next;
    if (x) {
        /* Can only have duplicate import declarations if both are qualified */
        if (!qualified)
            tfatal("duplicate import: %s", s);
        else if (!x->qualified)
            tfatal("package already imported as an unqualified import: %s", s);
        curr_import = x;
        return;
    }
    x = New(struct timport);
    x->b_next = import_hash[i];
    import_hash[i] = x;
    x->name = s;
    x->qualified = qualified;
    x->pos = n;
    if (last_import) {
        last_import->next = x;
        last_import = x;
    } else {
        imports = last_import = x;
    }
    curr_import = last_import;
}

void add_import_symbol(char *s, struct node *n) 
{
    int i = hasher(s, curr_import->symbol_hash);
    struct timport_symbol *x = curr_import->symbol_hash[i];
    while (x && x->name != s)
        x = x->b_next;
    if (x)
        tfatal("duplicate imported symbol: %s", s);
    x = New(struct timport_symbol);
    x->b_next = curr_import->symbol_hash[i];
    curr_import->symbol_hash[i] = x;
    x->name = s;
    x->pos = n;
    if (curr_import->last_symbol) {
        curr_import->last_symbol->next = x;
        curr_import->last_symbol = x;
    } else {
        curr_import->symbols = curr_import->last_symbol = x;
    }
}

void add_link(char *s, struct node *n) 
{
    struct link *i = New(struct link);
    i->name = s;
    i->pos = n;
    if (last_link) {
        last_link->next = i;
        last_link = i;
    } else {
        links = last_link = i;
    }
}

/*
 *  adds an "invocable" name to the list.
 *  x==1 if name is an identifier; otherwise it is a string literal.
 */
void add_invocable(char *name, int x, struct node *n)
{
    struct tinvocable *p;

    if (x == 1) {
        if (name == all_string)
            name = "0";			/* "0" represents "all" */
    }
    else if (!isalpha(name[1]) && (name[1] != '_'))
        return;				/* if operator, ignore */

    p = New(struct tinvocable);
    p->name = name;
    p->pos = n;
    if (last_tinvocable) {
        last_tinvocable->next = p;
        last_tinvocable = p;
    } else
        tinvocables = last_tinvocable = p;
}

static void dottedid2string_impl(struct node *n)
{
    char *s;
    switch (TType(n)) {
        case N_Id: 
            s = Str0(n);
            while (*s)
                AppChar(join_sbuf, *s++);
            break;
        case N_Dottedid:
            dottedid2string_impl(Tree0(n));
            AppChar(join_sbuf, '.');
            dottedid2string_impl(Tree1(n));
            break;
    }
}

/*
 * Convert a dotted id node (which may just be an id node) to a
 * string.
 */
char *dottedid2string(struct node *n)
{
    if (TType(n) == N_Id)
        return Str0(n);
    zero_sbuf(&join_sbuf);
    dottedid2string_impl(n);
    return str_install(&join_sbuf);
}

/*
 * A dotted id (or just an id) has been encountered as an expression.  This
 * function converts it to another node.  There are three possibilities:
 * 1) The node is an Id node (no dots) - just putloc and return it.
 * 
 * Otherwise the node is of the form (leftstuff).ID, so...
 * 
 * 2) leftstuff is identified as a package (either this file's package or one
 * imported by it).  This means the whole thing is an identifier, so create
 * a single flat id node, and putloc it.
 * 3) leftstuff is not a package, therefore it must be a field access.  But leftstuff
 * must still be converted, so call recursively.
 */
struct node *convert_dottedidentexpr(struct node *n)
{
    char *ls;
    struct tlentry *l;
    if (TType(n) == N_Id) {
        l = put_local(Str0(n), 0, n, 0);
        l->seen = 1;
        Val0(n) = l->l_index;
        return n;
    }
    ls = dottedid2string(Tree0(n));
    if (ls == package_name || ls == default_string || lookup_import(ls)) {
        struct node *r = IdNode(join_strs(&join_sbuf, 3, ls, ".", Str0(Tree1(n))));
        Line(r) = Line(n);
        File(r) = File(n);
        l = put_local(Str0(r), 0, r, 0);
        l->seen = 1;
        Val0(r) = l->l_index;
        return r;
    } else
        return tree4(N_Field, n, convert_dottedidentexpr(Tree0(n)), Tree1(n));
}
