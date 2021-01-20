/*
 * lsym.c -- functions for symbol table manipulation.
 */

#include "link.h"
#include "lsym.h"
#include "lmem.h"

static uword lghash_func(struct gentry *p) { return hashptr(p->name); }
static DefineHash(, struct gentry) lghash = { 200, lghash_func };

/*
 * Prototypes.
 */

int nfields = 0;		/* number of fields in field table */


/*
 * putglobal - make a global symbol table entry.
 */
struct gentry *putglobal(char *name, int flag, struct lfile *lf, struct loc *pos)
{
    struct gentry *p;
    if (glocate(name))
        quit("Attempted to add an global which already existed: %s", name);
    p = Alloc(struct gentry);
    if (lglast) {
        lglast->g_next = p;
        lglast = p;
    } else {
        lgfirst = lglast = p;
    }
    p->name = name;
    p->pos = *pos;
    p->defined = lf;
    p->g_flag = flag | F_Global;
    add_to_hash(&lghash, p);
    return p;
}

/*
 * glocate - lookup identifier in global symbol table, return NULL
 *  if not present.
 */
struct gentry *glocate(char *name)
{
    struct gentry *p;
    p = Bucket(lghash, hashptr(name));
    while (p && p->name != name)
        p = p->g_blink;
    return p;
}

struct lentry *add_local(struct lfunction *func, char *name, int flags, struct loc *pos)
{
    struct lentry *lp = Alloc(struct lentry);
    if (func->local_last) {
        func->local_last->next = lp;
        func->local_last = lp;
    } else
        func->locals = func->local_last = lp;
    lp->name = name;
    lp->pos = *pos;
    lp->l_flag = flags;
    if (flags & F_Vararg)
        func->vararg = 1;
    return lp;
}

struct centry *add_constant(struct lfunction *func, int flags, char *data, int len)
{
    struct centry *p = Alloc(struct centry);
    p->c_flag = flags;
    p->data = data;
    p->length = len;

    if (func->constant_last) {
        func->constant_last->next = p;
        func->constant_last = p;
    } else
        func->constants = func->constant_last = p;
    return p;
}

struct lclass_field *lookup_field(struct lclass *class, char *fname)
{
    struct lclass_field *cf;
    cf = Bucket(class->field_hash, hashptr(fname));
    while (cf && cf->name != fname)
        cf = cf->b_next;
    return cf;
}

struct lclass_field_ref *lookup_implemented_field_ref(struct lclass *class, char *fname)
{
    struct lclass_field_ref *fr;
    fr = Bucket(class->implemented_field_hash, hashptr(fname));
    while (fr && fr->field->name != fname)
        fr = fr->b_next;
    return fr;
}

struct lclass_field *lookup_implemented_field(struct lclass *class, char *fname)
{
    struct lclass_field_ref *cf = lookup_implemented_field_ref(class, fname);
    if (cf)
        return cf->field;
    else
        return 0;
}
