/*
 * lmem.c -- memory initialization and allocation; also parses arguments.
 */

#include "icont.h"
#include "link.h"
#include "package.h"
#include "lmem.h"
#include "tmain.h"
#include "lglob.h"

#include "../h/rmacros.h"

/*
 * Memory initialization
 */

struct gentry *lghash[LGHASH_SIZE];	/* hash area for global table */
struct fentry *lfhash[LFHASH_SIZE];	/* hash area for field table */

/* files to link, and a hash table for them */
struct lfile *lfile_hash[LFILE_HASH_SIZE], *lfiles, *lfiles_last;
struct lpackage *lpackage_hash[LPACKAGE_HASH_SIZE];
struct lclass *lclasses, *lclass_last;
struct lrecord *lrecords, *lrecord_last;
struct linvocable *linvocables, *last_linvocable;

struct fentry *lffirst;		/* first field table entry */
struct fentry *lflast;		/* last field table entry */
struct gentry *lgfirst;		/* first global table entry */
struct gentry *lglast;		/* last global table entry */


/*
 * linit - scan the command line arguments and initialize data structures.
 */
void linit()
{
    init_package_db();
    load_package_db_from_ipath();
    /*
     * Ensure "lang" is package id number 1.
     */
    get_package_id(lang_string);
}


/*
 * dumplfiles - print the list of files to link.  Used for debugging only.
 */

void dumplfiles()
{
    struct lfile *p;
    fprintf(stderr,"lfiles:\n");
    for (p = lfiles; p; p = p->next)
        fprintf(stderr,"'%s'\n",p->name);
    fflush(stderr);
}

/*
 * Given a linkfile, create a new lfile structure and add it to the
 * list of lfiles if it isn't already in the list.
 */
static void ensure_lfile(char *ifile)
{
    int i = hasher(ifile, lfile_hash);
    struct lfile *x = lfile_hash[i];
    while (x && x->name != ifile)
        x = x->b_next;
    if (x)
        return;

    if (verbose > 2)
        report("Linking file %s", ifile);

    x = Alloc(struct lfile);
    x->b_next = lfile_hash[i];
    lfile_hash[i] = x;
    x->name = ifile;
    if (lfiles_last) {
        lfiles_last->next = x;
        lfiles_last = x;
    } else {
        lfiles = lfiles_last = x;
    }
}

/*
 * Link a ufile given on the command line (or implied from a .icn
 * file).
 */
void paramlink(char *name)
{
    ensure_lfile(intern(canonicalize(name)));
}

void alsoimport(char *package, struct lfile *lf, struct loc *pos)
{
    struct package_dir *pd;
    struct package *pk;
    struct package_file *pf;
    char *found = 0;

    /* Have we done this one yet? */
    int i = hasher(package, lpackage_hash);
    struct lpackage *x = lpackage_hash[i];
    while (x && x->name != package)
        x = x->b_next;
    if (x)
        return;

    if (verbose > 2)
        report("Importing package %s", package);

    /* No, so note it as done, and use the package db to scan all the
     * files in the package, and add them to the lfiles list.
     */
    x = Alloc(struct lpackage);
    x->b_next = lpackage_hash[i];
    lpackage_hash[i] = x;
    x->name = package;
    for (pd = package_dirs; pd; pd = pd->next) {
        if ((pk = lookup_package(pd, package))) {
            /* Check for duplicate package on the path */
            if (found) {
                lfatal(lf, pos, 
                       "located package '%s' in multiple directories: %s and %s", 
                       package, found, pd->path);
                return;
            }
            found = pd->path;
            for (pf = pk->files; pf; pf = pf->next)
                ensure_lfile(join(pd->path, pf->name, USuffix, NULL));
        }
    }
    /* Check if we found it */
    if (!found)
        lfatal(lf, pos, "cannot resolve package '%s'", package);
}

/*
 * addinvk adds an "invokable" name to the list.
 */
void addinvk(char *name, struct lfile *lf, struct loc *pos)
{
    struct linvocable *p = Alloc(struct linvocable);
    p->iv_name = name;
    p->defined = lf;
    p->pos = *pos;
    if (last_linvocable) {
        last_linvocable->iv_link = p;
        last_linvocable = p;
    } else
        linvocables = last_linvocable = p;
}


/*
 * lmfree - free memory used by the linker
 */
void lmfree()
{
    struct fentry *fp, *fp1;
    struct gentry *gp, *gp1;
    struct lpackage *lp, *lp1;
    struct lfile *lf, *nlf;
    int i;

    for (fp = lffirst; fp; fp = fp1) {
        fp1 = fp->next;
        free(fp);
    }
    lffirst = lflast = 0;

    for (gp = lgfirst; gp; gp = gp1) {
        if (gp->class)
            free(gp->class);
        else if (gp->record)
            free(gp->record);
        else if (gp->func)
            free(gp->func);
        gp1 = gp->g_next;
        free(gp);
    }
    lgfirst = 0;
    lglast = 0;
    lclasses = lclass_last = 0;
    lrecords = lrecord_last = 0;

    for (i = 0; i < ElemCount(lpackage_hash); ++i) {
        for (lp = lpackage_hash[i]; lp; lp = lp1) {
            lp1 = lp->b_next;
            free(lp);
        }
    }
    ArrClear(lpackage_hash);

    for (lf = lfiles; lf != NULL; lf = nlf) {
        nlf = lf->next;
        free(lf);
    }
    lfiles = 0;
}

void add_super(struct lclass *x, char *name, struct loc *pos)
{
    struct lclass_super *cs;
    cs = Alloc(struct lclass_super);
    cs->name = name;
    cs->pos = *pos;
    if (x->last_super) {
        x->last_super->next = cs;
        x->last_super = cs;
    } else
        x->supers = x->last_super = cs;
}

void add_field(struct lclass *x, char *name, int flag, struct loc *pos)
{
    int i = hasher(name, x->field_hash);
    struct lclass_field *cf = x->field_hash[i];
    while (cf && cf->name != name)
        cf = cf->b_next;
    if (cf) 
        quit("Duplicate class field: %s", name);
    cf = Alloc(struct lclass_field);
    cf->b_next = x->field_hash[i];
    x->field_hash[i] = cf;
    cf->name = name;
    cf->pos = *pos;
    cf->flag = flag;
    cf->class = x;
    if (x->last_field) {
        x->last_field->next = cf;
        x->last_field = cf;
    } else
        x->fields = x->last_field = cf;
}

void add_method(struct lfile *lf, struct lclass *x, char *name, int flag, struct loc *pos)
{
    struct lfunction *f = Alloc(struct lfunction);
    add_field(x, name, flag, pos);
    x->last_field->func = f;
    f->defined = lf;
    f->method = x->last_field;
    f->native_method_id = -1;
}

void add_fimport(struct lfile *lf, char *package, int mode, struct loc *pos)
{
    int i = hasher(package, lf->import_hash);
    struct fimport *fimp = Alloc(struct fimport);
    fimp->b_next = lf->import_hash[i];
    lf->import_hash[i] = fimp;
    fimp->name = package;
    fimp->pos = *pos;
    fimp->mode = mode;
    if (lf->last_import) {
        lf->last_import->next = fimp;
        lf->last_import = fimp;
    } else
        lf->imports = lf->last_import = fimp;
}

struct fimport *lookup_fimport(struct lfile *lf, char *package)
{
    int i = hasher(package, lf->import_hash);
    struct fimport *x = lf->import_hash[i];
    while (x && x->name != package)
        x = x->b_next;
    return x;
}

/*
 * Add the given symbol to the hash of the last package.
 */
void add_fimport_symbol(struct lfile *lf, char *symbol, struct loc *pos)
{
    int i = hasher(symbol, lf->last_import->symbol_hash);
    struct fimport_symbol *x = Alloc(struct fimport_symbol);
    x->b_next = lf->last_import->symbol_hash[i];
    lf->last_import->symbol_hash[i] = x;
    x->name = symbol;
    x->pos = *pos;
    if (lf->last_import->last_symbol) {
        lf->last_import->last_symbol->next = x;
        lf->last_import->last_symbol = x;
    } else {
        lf->last_import->symbols = lf->last_import->last_symbol = x;
    }
}

/*
 * Given an import, lookup a symbol in its hashtable.
 */
struct fimport_symbol *lookup_fimport_symbol(struct fimport *p, char *symbol)
{
    int i = hasher(symbol, p->symbol_hash);
    struct fimport_symbol *x = p->symbol_hash[i];
    while (x && x->name != symbol)
        x = x->b_next;
    return x;
}

void add_record_field(struct lrecord *lr, char *name, struct loc *pos)
{
    struct lfield *x = Alloc(struct lfield);
    ++lr->nfields;
    x->name = name;
    x->pos = *pos;
    if (lr->last_field) {
        lr->last_field->next = x;
        lr->last_field = x;
    } else
        lr->fields = lr->last_field = x;
}
