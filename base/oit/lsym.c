/*
 * lsym.c -- functions for symbol table manipulation.
 */

#include "link.h"
#include "lsym.h"
#include "lmem.h"
#include "util.h"

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
        quitf("Attempted to add an global which already existed:%s", name);
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

void add_local(struct lfunction *func, char *name, int flags, struct loc *pos)
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
    ++func->nlocals;
}

void add_constant(struct lfunction *func, int flags, char *data, int len)
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

    ++func->nconstants;
}

struct fentry *flocate(char *name)
{
    int i = hasher(name, lfhash);
    struct fentry *fp = lfhash[i];
    while (fp && fp->name != name)
        fp = fp->b_next;
    return fp;
}

/*
 * blocate - search for a function. The search is linear to make
 *  it easier to add/delete functions. If found, returns index+1 for entry.
 */

/*
 * Lookup a method, given in the form class:method.  Returns 0 if not
 * found.
 */
struct lclass_field *lookup_method(char *class, char *method)
{
    struct gentry *gl;
    struct lclass *cl;
    struct lclass_field *cf;
    int i;

    /* Lookup the class in the global table. */
    gl = glocate(class);
    if (!gl)
        return 0;
    cl = gl->class;
    if (!cl)
        return 0;
    /* Lookup the method in the class's method table */
    i = hasher(method, cl->field_hash);
    cf = cl->field_hash[i];
    while (cf && cf->name != method)
        cf = cf->b_next;
    /* Check it's a method and not a variable */
    if (!cf || !cf->func)
        return 0;
    return cf;
}
