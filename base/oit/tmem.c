/*
 * tmem.c -- memory initialization and allocation for the translator.
 */

#include "icont.h"
#include "tmem.h"
#include "tlex.h"
#include "tsym.h"
#include "tmain.h"
#include "trans.h"
#include "package.h"
#include "membuff.h"

struct tgentry *ghash[GHASH_SIZE];	/* hash area for global table */
struct tgentry *gfirst;		/* first global table entry */
struct tgentry *glast;		/* last global table entry */

char *package_name = 0;
struct tfunction *functions = 0, *curr_func = 0;
struct tclass *classes = 0, *curr_class = 0;
struct timport *import_hash[64], *imports = 0, *last_import = 0, *curr_import = 0;
struct tinvocable *tinvocables = 0, *last_tinvocable = 0;

struct membuff file_mb = {"Per file membuff", 64000, 0,0,0 };

/*
 * called once - initialize the translation process
 */
void tminit()
{
    init_package_db();
}

/*
 * called after each file has been translated - reset memory/pointers
 */
void tmfilefree()
{
    functions = curr_func = 0;
    classes = curr_class = 0;
    curr_import = imports = last_import = 0;
    ArrClear(import_hash);
    tinvocables = last_tinvocable = 0;
    gfirst = glast = 0;
    ArrClear(ghash);
    package_name = 0;

    mb_clear(&file_mb);
}

/*
 * called after all files translated, prior to linking.
 */
void tmfree()
{
    free_package_db();
    mb_free(&file_mb);
}

void next_function(int flag)
{
    struct tfunction *f = FAlloc(struct tfunction);
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
    struct tclass *c = FAlloc(struct tclass);
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
        tfatal_at(n, "duplicate superclass: %s", name);
    cs = FAlloc(struct tclass_super);
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

        if ((flag & (M_Static | M_Abstract)) == (M_Static | M_Abstract))
            tfatal_at(n, "A static method cannot be abstract: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & (M_Static | M_Defer)) == (M_Static | M_Defer))
            tfatal_at(n, "A static method cannot be deferred: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & M_Final) && (curr_class->flag & M_Final))
            tfatal_at(n, "A method cannot be final in a class marked final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & M_Abstract) && (curr_class->flag & M_Final))
            tfatal_at(n, "A method cannot be abstract in a class marked final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & M_Defer) && (curr_class->flag & M_Final))
            tfatal_at(n, "A method cannot be deferred in a class marked final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & (M_Abstract | M_Final)) == (M_Abstract | M_Final))
            tfatal_at(n, "An abstract method cannot be final: method %s in class %s", 
                    curr_class->curr_field->name, curr_class->global->g_name);

        if ((flag & (M_Defer | M_Final)) == (M_Defer | M_Final))
            tfatal_at(n, "An deferred method cannot be final: method %s in class %s", 
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
        tfatal_at(n, "duplicate class field: %s", name);
    cv = FAlloc(struct tclass_field);
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

void set_package(char *s, struct node *n)
{
    package_name = s;
}

void next_import(char *s, int qualified, struct node *n)
{
    int i = hasher(s, import_hash);
    struct timport *x = import_hash[i];
    while (x && x->name != s)
        x = x->b_next;
    if (x) {
        /* Can only have duplicate import declarations if both are qualified */
        if (!qualified)
            tfatal_at(n, "duplicate import: %s", s);
        else if (!x->qualified)
            tfatal_at(n, "package already imported as an unqualified import: %s", s);
        curr_import = x;
        return;
    }
    x = FAlloc(struct timport);
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
        tfatal_at(n, "duplicate imported symbol: %s", s);
    x = FAlloc(struct timport_symbol);
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

/*
 *  adds an "invocable" name to the list.
 *  x==1 if name is an identifier; otherwise it is a string literal.
 */
void add_invocable(char *name, int x, struct node *n)
{
    struct tinvocable *p;

    if (x == 1 && name == all_string)
        name = "0";			/* "0" represents "all" */

    p = FAlloc(struct tinvocable);
    p->name = name;
    p->pos = n;
    if (last_tinvocable) {
        last_tinvocable->next = p;
        last_tinvocable = p;
    } else
        tinvocables = last_tinvocable = p;
}

static struct str_buf sb;

static void dottedid2string_impl(struct node *n)
{
    char *s;
    switch (TType(n)) {
        case N_Id: 
            s = Str0(n);
            while (*s)
                AppChar(sb, *s++);
            break;
        case N_Dottedid:
            dottedid2string_impl(Tree0(n));
            AppChar(sb, '.');
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
    zero_sbuf(&sb);
    dottedid2string_impl(n);
    return str_install(&sb);
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
        struct node *r = IdNode(join(ls, ".", Str0(Tree1(n)), NULL));
        Line(r) = Line(n);
        File(r) = File(n);
        l = put_local(Str0(r), 0, r, 0);
        l->seen = 1;
        Val0(r) = l->l_index;
        return r;
    } else
        return tree4(N_Field, n, convert_dottedidentexpr(Tree0(n)), Tree1(n));
}
