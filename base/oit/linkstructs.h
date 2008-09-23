/*
 * The data structures used during linking.
 */

#ifndef _LINKSTRUCTS_H
#define _LINKSTRUCTS_H 1

/*
 * Location in a file
 */
struct loc {
    char *file;
    int line;
};

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
    word ipc;           /* offset of instruction into code region */
    word fname;         /* offset of file name into string region */
};

struct ipc_line {
    word ipc;           /* offset of instruction into code region */
    int line;           /* line number */
};

struct lentry {                 /* local table entry */
    char *name;                 /*   name of variable, in string space */
    struct loc pos;             /*   source line number */
    word l_flag;                /*   variable flags */
    union {                     /*   value field */
        word index;             /*     index number for statics arguments and dynamics */
        struct gentry *global;  /*     global table entry */
        struct lclass_field *field; /* a field in a class's method */
    } l_val;
    struct lentry *next;        /* Next in lfunctions's linked list */
};

struct gentry {                 /* global table entry */
    struct gentry *g_blink;     /*   link for bucket chain */
    char *name;                 /* interned name */
    struct loc pos;                   /* source line number */
    word g_flag;                        /*   variable flags */
    int g_index;                /*   "index" in global table */
    struct lfile *defined;      /* The file this global was defined in (except for F_Builtin) */
    struct lclass *class;       /* pointer to class object for a class */ 
    struct lfunction *func;     /* pointer to function object for a proc */
    struct lrecord *record;
    struct lbuiltin *builtin;
    struct gentry *g_next;      /*   next global in table */
};

struct lbuiltin {
    int builtin_id;
};

struct lrecord {
    int pc;
    int nfields;
    struct lfield *fields, *last_field;
};

struct lfield {
    char *name;
    struct loc pos;
    struct fentry *ftab_entry;           /* Field table entry (gives field number) */
    struct lfield *next;
};

/*
 * xval - holds references to literal constants
 */
union xval {
    long ival;          /* integer */
    double rval;        /*  real */
    char *sval;         /*  pointer into string space of string */
};

struct centry {                 /* constant table entry */
    word c_flag;                /*   type of literal flag */
    union xval c_val;           /*   value field */
    int c_length;               /*   length of literal string */
    word c_pc;                  /*   position in icode of object */
    struct centry *next;        /* Next in lfunctions's linked list */
};

struct fentry {                 /* field table header entry */
    char *name;                 /*   field name, in the string space */
    int field_id;               /*   field id */
    struct fentry *b_next, *next;       /*   next field name in allocation order */
};

struct lclass_super {
    char *name;
    struct loc pos;
    struct lclass_super *b_next, *next;
};

struct lclass_field {
    char *name;
    struct loc pos;                      /* Source line number */
    word flag;
    int dpc;                             /* Address of descriptor, if a static or method */
    int ipc;                             /* Address of info block */
    struct fentry *ftab_entry;           /* Field table entry (gives field number) */
    struct lclass *class;                /* Pointer back to owning class */
    struct lclass_field *b_next, *next;  /* Next and hash links */
    struct lfunction *func;              /* If it's a method */
};

struct lclass {
    word flag;
    struct lclass_super *super_hash[32], *supers, *last_super;
    struct lclass_field *field_hash[32], *fields, *last_field;
    struct gentry *global;      /* Pointer back to global table entry */
    struct lclass *next;        /* Link in the list of all lclass objects */
    int seen;                   /* Flag for computing superclass set */
    int pc;                     /* Location of definition in icode */
    int size;                   /* Computed size of block in icode */
    struct lclass_ref *resolved_supers, *last_resolved_super;
    struct lclass_ref *implemented_classes, *last_implemented_class;
    struct lclass_field_ref *implemented_field_hash[32], 
        *implemented_class_fields, *last_implemented_class_field,        /* Methods & Statics */
        *implemented_instance_fields, *last_implemented_instance_field;  /* All others */
    int n_supers,             /* Some list lengths, useful for code generation */
        n_implemented_classes,           
        n_implemented_class_fields, 
        n_implemented_instance_fields;
};

/*
 * An element in a list of references to l_class objects.
 */
struct lclass_ref {
    struct lclass *class;
    struct lclass_ref *next;
};

/*
 * A reference to a class field.
 */
struct lclass_field_ref {
    struct lclass_field *field;
    int index;      /* Index in class's fields; set on code generation */
    struct lclass_field_ref *next, *b_next;
};

struct lfunction {
    int pc;
    int ndynamic;         /* Count of dynamics */
    int narguments;       /* Count of arguments, always >= 0 even for varargs */
    int nstatics;         /* Count of statics */
    int nargs;            /* Read from the ufile, will be -ve for varargs */
    int nlocals;          /* Number of local symbols - may be any sort */
    int nconstants;       /* Number of constants */
    struct lfile *defined;            /* The file this function was defined in */
    struct lclass_field *method;      /* Pointer to method, if a method */
    struct gentry *proc;              /* Pointer to proc, if a proc */
    struct lentry **local_table, *locals, *local_last;
    struct centry **constant_table, *constants, *constant_last;
};

/*
 * A linked list of files named by link declarations is maintained using
 *  lfile structures.
 */
struct lfile {
    char *name;                           /* name of the file */
    int declend_offset;                      /* file offset of declend */
    char *package;                           /* package of this file, or null */
    int package_id;                          /* id number of package */
    struct fimport *import_hash[64], *imports, *last_import;  /* imports in this file */
    struct lfile *next, *b_next;             /* pointer to next file */
};

/*
 * A list of imports in one particular file.
 */
struct fimport {
    char *name;
    int qualified;
    int used;
    struct loc pos;
    struct fimport_symbol *symbol_hash[64], *symbols, *last_symbol;
    struct fimport *next, *b_next;      /* pointer to next */
};

/*
 * Symbol in an import.
 */
struct fimport_symbol {
    char *name;
    int used;
    struct loc pos;
    struct fimport_symbol *next, *b_next;
};

/*
 * Imports encountered so far; used in alsoimport() to ensure we
 * only add the files from each package once.
 */
struct lpackage {
    char *name;
    struct lpackage *b_next;    /* bucket chain */
};

/*
 * "Invocable" declarations are recorded in a list of linvocable structs.
 */
struct linvocable {
    char *iv_name;               /* name of global */
    struct loc pos;              /* source pos */
    struct gentry *resolved;      /* the resolved entry */
    struct linvocable *iv_link;       /* link to next entry */
    struct lfile *defined;       /* The file this invocable was made in */
};


#endif
