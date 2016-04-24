#include "package.h"
#include "tmain.h"
#include "icont.h"

struct package_dir *package_dir_hash[16], *package_dirs, *package_dir_last;

void init_package_db()
{
    ArrClear(package_dir_hash);
    package_dirs = package_dir_last = 0;
}

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
            free(pk);
        }
        tpd = pd->next;
        free(pd);
    }

    ArrClear(package_dir_hash);
    package_dirs = package_dir_last = 0;
}

struct package_dir *create_package_dir(char *path)
{
    struct package_dir *p = Alloc(struct package_dir);
    p->path = path;
    return p;
}

struct package_file *create_package_file(char *name)
{
    struct package_file *p = Alloc(struct package_file);
    p->name = name;
    return p;
}

struct package *create_package(char *name)
{
    struct package *p = Alloc(struct package);
    p->name = name;
    return p;
}

/*
 * Lookup the package_file for the given file, which is an interned
 * string.
 */
struct package_file *lookup_package_file(struct package *p, char *s)
{
    int i = hasher(s, p->file_hash);
    struct package_file *x = p->file_hash[i];
    while (x && x->name != s)
        x = x->b_next;
    return x;
}

int add_package_file(struct package *p, struct package_file *new)
{
    int i = hasher(new->name, p->file_hash);
    struct package_file *x = p->file_hash[i];
    while (x && x->name != new->name)
        x = x->b_next;
    if (x)
        return 0;
    new->b_next = p->file_hash[i];
    p->file_hash[i] = new;
    if (p->file_last) {
        p->file_last->next = new;
        p->file_last = new;
    } else {
        p->files = p->file_last = new;
    }
    return 1;
}

char *get_packages_file(struct package_dir *d)
{
    return join(d->path, "packages.txt", NULL);
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
int load_package_dir(struct package_dir *dir)
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
            pf = create_package_file(s);
            if (!add_package_file(pack, pf))
                quit("%s corrupt - duplicate file entry", fn);
        }
    }

    if (ferror(f) != 0)
        quit("failed to read package file %s", fn);

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
        quit("Unable to open package file %s", fn);
    for (pk = dir->packages; pk; pk = pk->next) {
        fprintf(f, ">package\n%s\n", pk->name);
        for (pf = pk->files; pf; pf = pf->next)
            fprintf(f, "%s\n", pf->name);
    }
    dir->modflag = 0;
    fflush(f);
    if (ferror(f) != 0)
        quit("failed to write to package file %s", fn);
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
 * string.
 */
struct package_dir *lookup_package_dir(char *s)
{
    int i = hasher(s, package_dir_hash);
    struct package_dir *x = package_dir_hash[i];
    while (x && x->path != s)
        x = x->b_next;
    return x;
}

int add_package_dir(struct package_dir *new)
{
    int i = hasher(new->path, package_dir_hash);
    struct package_dir *x = package_dir_hash[i];
    while (x && x->path != new->path)
        x = x->b_next;
    if (x)
        return 0;
    new->b_next = package_dir_hash[i];
    package_dir_hash[i] = new;
    if (package_dir_last) {
        package_dir_last->next = new;
        package_dir_last = new;
    } else {
        package_dirs = package_dir_last = new;
    }
    return 1;
}

struct package *lookup_package(struct package_dir *p, char *s)
{
    int i = hasher(s, p->package_hash);
    struct package *x = p->package_hash[i];
    while (x && x->name != s)
        x = x->b_next;
    return x;
}

int add_package(struct package_dir *p, struct package *new)
{
    int i = hasher(new->name, p->package_hash);
    struct package *x = p->package_hash[i];
    while (x && x->name != new->name)
        x = x->b_next;
    if (x)
        return 0;
    new->b_next = p->package_hash[i];
    p->package_hash[i] = new;
    if (p->package_last) {
        p->package_last->next = new;
        p->package_last = new;
    } else {
        p->packages = p->package_last = new;
    }
    return 1;
}

void ensure_file_in_package(char *file, char *ipackage)
{
    struct fileparts *fps = fparse(file);
    char *idir, *iname;
    struct package_dir *pd;
    struct package *pk;
    struct package_file *pf;

    idir = intern(canonicalize(fps->dir));
    pd = lookup_package_dir(idir);
    if (!pd) {
        /*
         * Create a new instance, try to load its contents from the packages.txt file,
         * and add it to the database.
         */
        pd = create_package_dir(idir);
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

    /* Intern the filename */
    iname = intern(fps->name);
    pf = lookup_package_file(pk, iname);
    if (!pf) {
        /* Create a new one */
        pf = create_package_file(iname);
        if (!add_package_file(pk, pf))
            quit("Unexpected failure to add new package file");
        /* Flag the file as needing to be saved. */
        pd->modflag = 1;
    }
}

static void load_path_impl(char *dir)
{
    struct package_dir *pd;
    char *idir;

    idir = intern(canonicalize(dir));
    /* Have we seen it yet?  If so, just ignore. */
    pd = lookup_package_dir(idir);
    if (pd)
        return;

    /*
     * Create a new instance, try to load its contents from the packages.txt file,
     * and add it to the database.
     */
    pd = create_package_dir(idir);
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
    char *s = getenv(OI_PATH);

    /* Load anything in the CD.  The empty string passed to canonicalize will
     * return the CD with a trailing separator. */
    load_path_impl("");
    
    /* And anything on the IPATH */
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
