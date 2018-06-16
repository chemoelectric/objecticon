/*
 * Interpreter code file header - this is written at the start of
 *  an icode file after the start-up program.
 */
struct header {
    word Base;                  /* base address of icode */
    word IcodeSize;		/* size of interpreter code */
    word ClassStatics;          /* class field descriptors (statics) */
    word ClassMethods;          /* class field descriptors (methods) */
    word ClassFields;           /* class field info */
    word ClassFieldLocs;        /* class field location info */
    word Classes;               /* class info */
    word Records;               /* record info */
    word Fnames;		/* location of names of fields */
    word Globals;		/* location of global variables */
    word Gnames;		/* location of names of globals */
    word Gflags;                /* location of global flag array */
    word Glocs;                 /* location of positions of globals */
    word Statics;		/* location of static variables in procs/methods */
    word Snames;		/* location of names of statics */
    word TCaseTables;		/* location of tcase tables */
    word Constants;             /* location of constant descriptors */
    word Strcons;		/* location of string table */
    word AsciiStrcons;		/* location of ascii-only part of string table */
    word Filenms;		/* location of ipc/file name table */
    word Linenums;		/* location of ipc/line number table */
    word Config[16];		/* icode version */
};
