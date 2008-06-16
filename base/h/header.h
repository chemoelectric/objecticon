/*
 * Interpreter code file header - this is written at the start of
 *  an icode file after the start-up program.
 */
struct header {
    word hsize;			/* size of interpreter code */
    word trace;			/* initial value of &trace */

    word ClassStatics;          /* class field descriptors */
    word ClassFields;           /* class field info */
    word Classes;               /* class info */
    word Records;               /* record info */
    word Ftab;			/* location of record/field table */
    word StandardFields;        /* location of standard field number table */
    word Fnames;		/* location of names of fields */
    word Globals;		/* location of global variables */
    word Gnames;		/* location of names of globals */
    word Statics;		/* location of static variables in procs/methods */
    word Strcons;		/* location of identifier table */
    word Filenms;		/* location of ipc/file name table */

    word linenums;		/* location of ipc/line number table */
    word config[16];		/* icode version */

#ifdef FieldTableCompression
    short FtabWidth;		/* width of field table entries, 1 | 2 | 4 */
    short FoffWidth;		/* width of field offset entries, 1 | 2 | 4 */
    word Nfields;		/* number of field names */
    word Fo;			/* The start of the Fo array */
    word Bm;			/* The start of the Bm array */
#endif					/* FieldTableCompression */

};
