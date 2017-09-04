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


struct lentry {                 /* local table entry */
    char *name;                 /*   name of variable, in string space */
    struct loc pos;             /*   source line number */
    word l_flag;                /*   variable flags */
    int ref;                    /*   referenced flag */
    union {                     /*   value field */
        int index;             /*     index number for statics arguments and dynamics */
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
    int ref;                    /* referenced flag */
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
    word pc;
    int nfields;
    struct lfield *fields, *last_field;
    struct gentry *global;      /* Pointer back to global table entry */
    struct lrecord *next;        /* Link in the list of all lrecord objects */
};

struct lfield {
    char *name;
    struct loc pos;
    struct fentry *ftab_entry;           /* Field table entry (gives field number) */
    struct lfield *next;
};

struct centry {                 /* constant table entry */
    word c_flag;                /*   type of literal flag */
    char *data;                 /*   raw data read from ufile */
    int length;                 /*   length of raw data */
    int ref;                    /*   referenced flag */
    word pc;                    /* Address of block for lrgint, cset, ucs, real */
    word desc_no;               /* Index in constant descriptor table for non-integer types */
    struct centry *next,        /* Next in lfunctions's linked list */
                  *b_next,      /* Next in hash bucket, used by code generation */
                  *d_next;      /* Next in constant descriptor table */
};

struct fentry {                 /* field table header entry */
    char *name;                 /*   field name, in the string space */
    int field_id;               /*   field id */
    struct fentry *b_next, *next;       /*   next field name in allocation order */
};

struct lclass_super {
    char *name;
    struct loc pos;
    struct lclass_super *next;
};

enum const_val_flag { NOT_SEEN = 0, SET_NULL, SET_CONST, SET_YES, OTHER };

struct lclass_field {
    char *name;
    struct loc pos;                      /* Source line number */
    word flag;
    word dpc;                            /* Address of descriptor, if a static or method */
    word ipc;                            /* Address of info block */
    struct fentry *ftab_entry;           /* Field table entry (gives field number) */
    int const_flag;                      /* Optimisation - constant flag */
    struct centry *const_val;            /* Optimisation - constant value */
    struct lclass *class;                /* Pointer back to owning class */
    struct lclass_field *b_next, *next;  /* Next and hash links */
    struct lfunction *func;              /* If it's a method */
};

struct lclass {
    word flag;
    struct lclass_super *supers, *last_super;
    struct lclass_field *field_hash[32], *fields, *last_field;
    struct gentry *global;      /* Pointer back to global table entry */
    struct lclass *next;        /* Link in the list of all lclass objects */
    int seen;                   /* Flag for computing superclass set */
    word pc;                    /* Location of definition in icode */
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
    struct lclass_field_ref *next, *b_next;
};

struct lfunction {
    word pc;
    int ndynamic;         /* Count of dynamics */
    int narguments;       /* Count of arguments */
    int vararg;           /* Flag set to 1 for vararg function */
    int nstatics;         /* Count of statics */
    int native_method_id; /* For a deferred method, the native method number, or -1 */
    struct lfile *defined;            /* The file this function was defined in */
    struct lclass_field *method;      /* Pointer to method, if a method */
    struct gentry *proc;              /* Pointer to proc, if a proc */
    struct lnode *start;              /* A Uop_Start node to mark the start of the function (useful
                                       * for visitor functions). */
    struct lnode *initial;            /* Ucode tree for initial clause */
    struct lnode *body;               /* Ucode tree for main body */
    struct lnode *end;                /* Ucode tree for end */
    struct lentry *locals, *local_last;
    struct centry *constants, *constant_last;
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
    int ref;                                 /* flag used during scanrefs() */
    struct fimport *import_hash[64], *imports, *last_import;  /* imports in this file */
    struct lfile *next, *b_next;             /* pointer to next file */
};

/*
 * A list of imports in one particular file.
 */
struct fimport {
    char *name;
    int mode;
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
