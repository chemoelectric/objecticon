#ifndef _PACKAGE_H
#define _PACKAGE_H 1

/*
 * Functions for handling the packages database.
 */

/*
 * A file in a package (without path or the .u extension)
 */
struct package_file {
    char *name;
    struct package_file *b_next, *next;
};

/*
 * A package: just a map/list of several files.
 */
struct package {
    char *name;
    struct package_file *file_hash[32], *files, *file_last;
    struct package *b_next, *next;
};

/*
 * Represents a "packages.txt" file: a path to the file and several
 * packages contained therein.
 */
struct package_dir {
    char *path;
    int modflag;
    struct package *package_hash[256], *packages, *package_last;
    struct package_dir *b_next, *next;
};

extern struct package_dir *package_dirs, *package_dir_last;

/*
 * Prototypes.
 */
void init_package_db();
void free_package_db();
struct package_dir *create_package_dir(char *path);
struct package_file *create_package_file(char *name);
struct package *create_package(char *name);
struct package_file *lookup_package_file(struct package *p, char *s);
int add_package_file(struct package *p, struct package_file *new);
char *get_packages_file(struct package_dir *d);
int load_package_dir(struct package_dir *dir);
void save_package_db();
struct package_dir *lookup_package_dir(char *s);
int add_package_dir(struct package_dir *new);
struct package *lookup_package(struct package_dir *p, char *s);
int add_package(struct package_dir *p, struct package *new);
void ensure_file_in_package(char *file, char *package);
void load_package_db_from_ipath();
void dump_package_db();

#endif
