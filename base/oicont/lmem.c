/*
 * lmem.c -- memory initialization and allocation; also parses arguments.
 */

#include "icont.h"
#include "link.h"
#include "package.h"
#include "lmem.h"
#include "util.h"
#include "tmain.h"

#include "../h/rmacros.h"

/*
 * Memory initialization
 */

struct gentry *lghash[LGHASH_SIZE];	/* hash area for global table */
struct fentry *lfhash[LFHASH_SIZE];	/* hash area for field table */

/* files to link, and a hash table for them */
struct lfile *lfile_hash[LFILE_HASH_SIZE], *lfiles = 0, *lfiles_last = 0;
struct lpackage *lpackage_hash[LPACKAGE_HASH_SIZE];
struct lclass *lclasses = 0, *lclass_last = 0;
struct linvocable *linvocables = 0, *last_linvocable = 0;

struct ipc_fname *fnmtbl;	/* table associating ipc with file name */
struct ipc_line *lntable;	/* table associating ipc with line number */

word *labels;			/* label table */
char *codeb;			/* generated code space */

struct ipc_fname *fnmfree;	/* free pointer for ipc/file name table */
struct ipc_line *lnfree;	/* free pointer for ipc/line number table */
word lsfree;			/* free index for string space */
char *codep;			/* free pointer for code space */

struct fentry *lffirst;		/* first field table entry */
struct fentry *lflast;		/* last field table entry */
struct gentry *lgfirst;		/* first global table entry */
struct gentry *lglast;		/* last global table entry */

struct str_buf link_sbuf;
struct str_buf llex_sbuf;

/*
 * Array sizes for various linker tables that can be expanded with realloc().
 */
int nsize	= 1000;	    /* ipc/line num. assoc. table */
int maxcode	= 15000;    /* code space */
int fnmsize	= 10;	    /* ipc/file name assoc. table */
int maxlabels	= 500;	    /* maximum num of labels/proc */

/*
 * linit - scan the command line arguments and initialize data structures.
 */
void linit()
{
    init_sbuf(&link_sbuf);
    init_sbuf(&llex_sbuf);

    init_package_db();
    load_package_db_from_ipath();

    lfiles = lfiles_last = 0;		/* Zero queue of files to link. */
    clear(lfile_hash);

    clear(lpackage_hash);

    /*
     * Allocate the various data structures that are used by the linker.
     */

    lnfree = lntable  = (struct ipc_line*)tcalloc(nsize,sizeof(struct ipc_line));

    fnmtbl = (struct ipc_fname *) tcalloc(fnmsize, sizeof(struct ipc_fname));
    fnmfree = fnmtbl;

    labels  = (word *) tcalloc(maxlabels, sizeof(word));
    codep = codeb = (char *) tcalloc(maxcode, 1);

    lffirst = lflast = 0;
    lgfirst = lglast = 0;

    lclasses = lclass_last = 0;

    /*
     * Zero out the hash tables.
     */
    clear(lghash);
    clear(lfhash);
}


/*
 * dumplfiles - print the list of files to link.  Used for debugging only.
 */

void dumplfiles()
{
    struct lfile *p;
    fprintf(stderr,"lfiles:\n");
    for (p = lfiles; p; p = p->next)
        fprintf(stderr,"'%s'\n",p->lf_name);
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
    while (x && x->lf_name != ifile)
        x = x->b_next;
    if (x)
        return;
    x = New(struct lfile);
    x->b_next = lfile_hash[i];
    lfile_hash[i] = x;
    x->lf_name = ifile;
    if (lfiles_last) {
        lfiles_last->next = x;
        lfiles_last = x;
    } else {
        lfiles = lfiles_last = x;
    }
}

/*
 * alsolink - create an lfile structure for the named file and add it to the
 *  end of the list of files (lfiles) to generate link instructions for.
 */
void alsolink(char *name, struct lfile *lf, struct loc *pos)
{
    char file[MaxFileName], *cdir, *ifile;
    struct fileparts *fps;

    if (!pathfind(file, ipath, name, USuffix)) {
        lfatal(pos, "cannot resolve link reference: %s", name);
        return;
    }

    /* Get the canonicalized directory */
    fps = fparse(file);
    cdir = canonicalize(fps->dir);
    if (!cdir) {
        lfatal(pos, "directory of link file doesn't exist:%s", file);
        return;
    }

    /* Get the full filename interned */
    ifile = join_strs(&link_sbuf, 3, cdir, fps->name, fps->ext);

    /* Add it to the link list if not already there. */
    ensure_lfile(ifile);
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

    /* No, so note it as done, and use the package db to scan all the
     * files in the package, and add them to the lfiles list.
     */
    x = New(struct lpackage);
    x->b_next = lpackage_hash[i];
    lpackage_hash[i] = x;
    x->name = package;
    for (pd = package_dirs; pd; pd = pd->next) {
        if ((pk = lookup_package(pd, package))) {
            /* Check for duplicate package on the path */
            if (found) {
                lfatal(pos, 
                        "located package '%s' in multiple directories: %s and %s", 
                        package, found, pd->path);
                return;
            }
            found = pd->path;
            for (pf = pk->files; pf; pf = pf->next)
                ensure_lfile(join_strs(&link_sbuf, 3, pd->path, pf->name, USuffix));
        }
    }
    /* Check if we found it */
    if (!found)
        lfatal(pos, "cannot resolve package '%s'", package);
}

/*
 * addinvk adds an "invokable" name to the list.
 */
void addinvk(char *name, struct lfile *lf, struct loc *pos)
{
    struct linvocable *p = New(struct linvocable);
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

    free( lntable);   lntable = NULL;
    free( fnmtbl);   fnmtbl = NULL;
    free( labels);   labels = NULL;
    free( codep);   codep = NULL;

    for (fp = lffirst; fp; fp = fp1) {
        free(fp->rowdata);
        fp1 = fp->next;
        free(fp);
    }
    lffirst = lflast = 0;

    for (gp = lgfirst; gp; gp = gp1) {
        if (gp->class)
            free(gp->class);
        gp1 = gp->g_next;
        free(gp);
    }
    lgfirst = 0;
    lglast = 0;
    lclasses = lclass_last = 0;

    for (i = 0; i < asize(lpackage_hash); ++i) {
        for (lp = lpackage_hash[i]; lp; lp = lp1) {
            lp1 = lp->b_next;
            free(lp);
        }
    }
    clear(lpackage_hash);

    for (lf = lfiles; lf != NULL; lf = nlf) {
        nlf = lf->next;
        free(lf);
    }
    lfiles = 0;
}

void add_super(struct lclass *x, char *name, struct loc *pos)
{
    int i = hasher(name, x->super_hash);
    struct lclass_super *cs = x->super_hash[i];
    while (cs && cs->name != name)
        cs = cs->b_next;
    if (cs) 
        quitf("duplicate superclass: %s", name);
    cs = New(struct lclass_super);
    cs->b_next = x->super_hash[i];
    x->super_hash[i] = cs;
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
        quitf("duplicate class field: %s", name);
    cf = New(struct lclass_field);
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
    struct lfunction *f = New(struct lfunction);
    add_field(x, name, flag, pos);
    x->last_field->func = f;
    f->defined = lf;
    f->method = x->last_field;
}

void add_fimport(struct lfile *lf, char *package, int qualified, struct loc *pos)
{
    int i = hasher(package, lf->import_hash);
    struct fimport *fimp = New(struct fimport);
    fimp->b_next = lf->import_hash[i];
    lf->import_hash[i] = fimp;
    fimp->name = package;
    fimp->pos = *pos;
    fimp->qualified = qualified;
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
    struct fimport_symbol *x = New(struct fimport_symbol);
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
    struct lfield *x = New(struct lfield);
    ++lr->nfields;
    x->name = name;
    x->pos = *pos;
    if (lr->last_field) {
        lr->last_field->next = x;
        lr->last_field = x;
    } else
        lr->fields = lr->last_field = x;
}
