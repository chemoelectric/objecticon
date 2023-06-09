#include "tmain.h"
#include "icont.h"
#include "package.h"

struct package_dir *package_dirs, *package_dir_last;

static uword package_dir_hash_func(struct package_dir *p) { return hashptr(p->sc_path); }
static DefineHash(, struct package_dir) package_dir_hash = { 10, package_dir_hash_func };

static struct package_dir *create_package_dir(char *path, char *sc_path);
static struct package_file *create_package_file(char *name, char *sc_name);
static struct package *create_package(char *name);
static struct package_file *lookup_package_file(struct package *p, char *s);
static int add_package_file(struct package *p, struct package_file *new);
static char *get_packages_file(struct package_dir *d);
static int load_package_dir(struct package_dir *dir);
static struct package_dir *lookup_package_dir(char *s);
static int add_package_dir(struct package_dir *new);
static int add_package(struct package_dir *p, struct package *new);

void free_package_db()
{
    struct package_dir *pd, *tpd;
    struct package *pk, *tpk;
    struct package_file *pf, *tpf;

    for (pd = package_dirs; pd; pd = tpd) {
        for (pk = pd->packages; pk; pk = tpk) {
            for (pf = pk->files; pf; pf = tpf) {
                tpf = pf->next;
                free(pf);
            }
            tpk = pk->next;
            free_hash(&pk->file_hash);
            free(pk);
        }
        tpd = pd->next;
        free_hash(&pd->package_hash);
        free(pd);
    }
    free_hash(&package_dir_hash);
    package_dirs = package_dir_last = 0;
}

static uword package_hash_func(struct package *p) { return hashptr(p->name); }

static struct package_dir *create_package_dir(char *path, char *sc_path)
{
    struct package_dir *p = Alloc(struct package_dir);
    p->path = path;
    p->sc_path = sc_path;
    p->package_hash.init = 10;
    p->package_hash.hash = package_hash_func;
    return p;
}

static struct package_file *create_package_file(char *name, char *sc_name)
{
    struct package_file *p = Alloc(struct package_file);
    p->name = name;
    p->sc_name = sc_name;
    return p;
}

static uword package_file_hash_func(struct package_file *p) { return hashptr(p->sc_name); }

static struct package *create_package(char *name)
{
    struct package *p = Alloc(struct package);
    p->name = name;
    p->file_hash.init = 4;
    p->file_hash.hash = package_file_hash_func;
    return p;
}

/*
 * Lookup the package_file for the given file, which is an interned
 * string.
 */
static struct package_file *lookup_package_file(struct package *p, char *s)
{
    struct package_file *x;
    x = Bucket(p->file_hash, hashptr(s));
    while (x && x->sc_name != s)
        x = x->b_next;
    return x;
}

static int add_package_file(struct package *p, struct package_file *new)
{
    struct package_file *x;
    x = lookup_package_file(p, new->sc_name);
    if (x)
        return 0;
    if (p->file_last) {
        p->file_last->next = new;
        p->file_last = new;
    } else {
        p->files = p->file_last = new;
    }
    add_to_hash(&p->file_hash, new);
    return 1;
}

static char *get_packages_file(struct package_dir *d)
{
    return join(d->path, "packages.txt", NullPtr);
}

static char *read_package_line(FILE *f)
{
    int c;
    static struct str_buf sb;
    zero_sbuf(&sb);
    /* Read upto end of line */
    for(;;) {
        c = getc(f);
        if (c == EOF)
            return 0;
        if (c == '\n')
            break;
        AppChar(sb, (char)c);
    }
    return str_install(&sb);
}

/*
 * Try to load the list of files for a package dir from packages.txt.  Returns 1 on
 * success, 0 if packages.txt didn't exist, and quits on a corrupt file.
 */
static int load_package_dir(struct package_dir *dir)
{
    struct package *pack = 0;
    struct package_file *pf = 0;
    char *fn = get_packages_file(dir);
    FILE *f = fopen(fn, ReadBinary);

    if (!f)
        return 0;

    for (;;) {
        char *s = read_package_line(f);
        if (!s)
            break;
        if (s == package_marker_string) {
            s = read_package_line(f);
            if (!s)
                quit("%s corrupt - package name expected following package", fn);
            pack = create_package(s);
            if (!add_package(dir, pack))
                quit("%s corrupt - duplicate package entry", fn);
        } else {
            if (!pack)
                quit("%s corrupt - package expected", fn);
            pf = create_package_file(s, intern_standard_case(s));
            if (!add_package_file(pack, pf))
                quit("%s corrupt - duplicate file entry", fn);
        }
    }

    if (ferror(f) != 0)
        equit("Failed to read package file %s", fn);

    fclose(f);
    dir->modflag = 0;
    return 1;
}

/*
 * Save the given package_dir to its packages.txt file in its directory.
 */
static void save_package_dir(struct package_dir *dir)
{
    char *fn = get_packages_file(dir);
    FILE *f = fopen(fn, WriteBinary);
    struct package *pk;
    struct package_file *pf;
    if (!f)
        equit("Unable to open package file %s", fn);
    for (pk = dir->packages; pk; pk = pk->next) {
        fprintf(f, ">package\n%s\n", pk->name);
        for (pf = pk->files; pf; pf = pf->next)
            fprintf(f, "%s\n", pf->name);
    }
    dir->modflag = 0;
    fflush(f);
    if (ferror(f) != 0)
        equit("Failed to write to package file %s", fn);
    fclose(f);
}

/*
 * Save any modified parts of the database to their respective files.
 */
void save_package_db()
{
    struct package_dir *pd;
    for (pd = package_dirs; pd; pd = pd->next) {
        if (pd->modflag)
            save_package_dir(pd);
    }
}

/*
 * Lookup the package_dir for the given path, which is an interned
 * standard-cased string.
 */
static struct package_dir *lookup_package_dir(char *s)
{
    struct package_dir *x;
    x = Bucket(package_dir_hash, hashptr(s));
    while (x && x->sc_path != s)
        x = x->b_next;
    return x;
}

static int add_package_dir(struct package_dir *new)
{
    struct package_dir *x;
    x = lookup_package_dir(new->sc_path);
    if (x)
        return 0;
    if (package_dir_last) {
        package_dir_last->next = new;
        package_dir_last = new;
    } else {
        package_dirs = package_dir_last = new;
    }
    add_to_hash(&package_dir_hash, new);
    return 1;
}

struct package *lookup_package(struct package_dir *p, char *s)
{
    struct package *x;
    x = Bucket(p->package_hash, hashptr(s));
    while (x && x->name != s)
        x = x->b_next;
    return x;
}

static int add_package(struct package_dir *p, struct package *new)
{
    struct package *x;
    x = lookup_package(p, new->name);
    if (x)
        return 0;
    if (p->package_last) {
        p->package_last->next = new;
        p->package_last = new;
    } else {
        p->packages = p->package_last = new;
    }
    add_to_hash(&p->package_hash, new);
    return 1;
}

void ensure_file_in_package(char *file, char *ipackage)
{
    struct fileparts *fps;
    char *sc_idir, *idir, *sc_iname, *iname;
    struct package_dir *pd;
    struct package *pk;
    struct package_file *pf;

    fps = fparse(canonicalize(file));

    /* Intern the bits */
    iname = intern(fps->name);
    idir = intern(fps->dir);
    sc_idir = intern_standard_case(idir);
    sc_iname = intern_standard_case(iname);
    pd = lookup_package_dir(sc_idir);
    if (!pd) {
        /*
         * Create a new instance, try to load its contents from the packages.txt file,
         * and add it to the database.
         */
        pd = create_package_dir(idir, sc_idir);
        load_package_dir(pd);
        if (!add_package_dir(pd))
            quit("Unexpected failure to add new package dir");
    }

    pk = lookup_package(pd, ipackage);
    if (!pk) {
        /* Create a new one */
        pk = create_package(ipackage);
        if (!add_package(pd, pk))
            quit("Unexpected failure to add new package");
    }

    pf = lookup_package_file(pk, sc_iname);
    if (!pf) {
        /* Create a new one */
        pf = create_package_file(iname, sc_iname);
        if (!add_package_file(pk, pf))
            quit("Unexpected failure to add new package file");
        /* Flag the file as needing to be saved. */
        pd->modflag = 1;
    }
}

static void load_path_impl(char *dir)
{
    struct package_dir *pd;
    char *idir, *sc_idir;

    idir = intern(canonicalize(dir));
    sc_idir = intern_standard_case(idir);

    /* Have we seen it yet?  If so, just ignore. */
    pd = lookup_package_dir(sc_idir);
    if (pd)
        return;

    /*
     * Create a new instance, try to load its contents from the packages.txt file,
     * and add it to the database.
     */
    pd = create_package_dir(idir, sc_idir);
    load_package_dir(pd);
    if (!add_package_dir(pd))
        quit("Unexpected failure to add new package dir");
}

/*
 * Initialise the packages db from the packages.txt files found in the
 * current directory, and the OI_PATH (if defined).
 */
void load_package_db_from_ipath()
{
    char *s = getenv_nn("OI_PATH");

    /* Load anything in the CD.  The empty string passed to canonicalize will
     * return the CD with a trailing separator. */
    load_path_impl("");
    
    /* And anything on the OI_PATH */
    if (!s)
        return;
    for (;;) {
        char *e = pathelem(&s);
        if (!e)
            break;
        load_path_impl(intern(e));
    }
}

/*
 * Debug function.
 */
void dump_package_db()
{
    struct package_dir *pd;
    struct package *pk;
    struct package_file *pf;

    for (pd = package_dirs; pd; pd = pd->next) {
        printf("Package dir: path=%s  mod=%d\n", pd->path, pd->modflag);
        for (pk = pd->packages; pk; pk = pk->next) {
            printf("\tPackage: %s\n", pk->name);
            for (pf = pk->files; pf; pf = pf->next) {
                printf("\t\tFile: %s\n", pf->name);
            }
        }
    }
}
