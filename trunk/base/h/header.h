/*
 * Interpreter code file header - this is written at the start of
 *  an icode file after the start-up program.
 */
struct header {
    word icodesize;		/* size of interpreter code */
    word ClassStatics;          /* class field descriptors (statics) */
    word ClassMethods;          /* class field descriptors (methods) */
    word ClassFields;           /* class field info */
    word ClassFieldLocs;        /* class field location info */
    word Classes;               /* class info */
    word Records;               /* record info */
    word Fnames;		/* location of names of fields */
    word Globals;		/* location of global variables */
    word Gnames;		/* location of names of globals */
    word Glocs;                 /* location of positions of globals */
    word Statics;		/* location of static variables in procs/methods */
    word Constants;             /* location of constant descriptors */
    word Strcons;		/* location of identifier table */
    word Filenms;		/* location of ipc/file name table */
    word linenums;		/* location of ipc/line number table */
    word config[16];		/* icode version */
};
