#ifndef _PACKAGE_H
#define _PACKAGE_H 1

/*
 * Functions for handling the packages database.
 */

/*
 * A file in a package (without path or the .u extension)
 */
struct package_file {
    struct package_file *b_next;      /* Hash link */
    char *name;
    char *sc_name;                    /* standard-cased name */
    struct package_file *next;
};

/*
 * A package: just a map/list of several files.
 */
struct package {
    struct package *b_next;           /* Hash link */
    char *name;
    DefineHash(, struct package_file) file_hash;
    struct package_file *files, *file_last;
    struct package *next;
};

/*
 * Represents a "packages.txt" file: a path to the file and several
 * packages contained therein.
 */
struct package_dir {
    struct package_dir *b_next;       /* Hash link */
    char *path;
    char *sc_path;                    /* standard-cased path */
    int modflag;
    DefineHash(, struct package) package_hash;
    struct package *packages, *package_last;
    struct package_dir *next;
};

extern struct package_dir *package_dirs, *package_dir_last;

/*
 * Prototypes.
 */
void free_package_db(void);
void save_package_db(void);
struct package *lookup_package(struct package_dir *p, char *s);
void ensure_file_in_package(char *file, char *package);
void load_package_db_from_ipath(void);
void dump_package_db(void);

#endif
