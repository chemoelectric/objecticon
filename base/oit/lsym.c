/*
 * lsym.c -- functions for symbol table manipulation.
 */

#include "link.h"
#include "lsym.h"
#include "lmem.h"

/*
 * Prototypes.
 */

int nfields = 0;		/* number of fields in field table */


/*
 * putglobal - make a global symbol table entry.
 */
struct gentry *putglobal(char *name, int flag, struct lfile *lf, struct loc *pos)
{
    int i = hasher(name, lghash);
    struct gentry *p = lghash[i];
    while (p && p->name != name)
        p = p->g_blink;
    if (p)
        quit("Attempted to add an global which already existed:%s", name);
    p = Alloc(struct gentry);
    p->g_blink = lghash[i];
    lghash[i] = p;
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
    return p;
}

/*
 * glocate - lookup identifier in global symbol table, return NULL
 *  if not present.
 */
struct gentry *glocate(char *name)
{
    struct gentry *p = lghash[hasher(name, lghash)];
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

struct fentry *flocate(char *name)
{
    int i = hasher(name, lfhash);
    struct fentry *fp = lfhash[i];
    while (fp && fp->name != name)
        fp = fp->b_next;
    return fp;
}

struct lclass_field *lookup_field(struct lclass *class, char *fname)
{
    int i = hasher(fname, class->field_hash);
    struct lclass_field *cf = class->field_hash[i];
    while (cf && cf->name != fname)
        cf = cf->b_next;
    return cf;
}

struct lclass_field_ref *lookup_implemented_field_ref(struct lclass *class, char *fname)
{
    int i = hasher(fname, class->implemented_field_hash);
    struct lclass_field_ref *cf = class->implemented_field_hash[i];
    while (cf && cf->field->name != fname)
        cf = cf->b_next;
    return cf;
}

struct lclass_field *lookup_implemented_field(struct lclass *class, char *fname)
{
    struct lclass_field_ref *cf = lookup_implemented_field_ref(class, fname);
    if (cf)
        return cf->field;
    else
        return 0;
}
