/*
 * External declarations for the run-time system.
 */

/*
 * External declarations common to the compiler and interpreter.
 */

extern struct c_proc *op_tbl[]; /* operators available for string invocation */
extern int op_tbl_sz;           /* number of operators in op_tbl */
extern struct c_proc *fnc_tbl[]; /* builtin functions */
extern int fnc_tbl_sz;           /* sizeof of fnc_tbl */
extern struct c_proc *keyword_tbl[]; /* keyword functions */
extern int keyword_tbl_sz;           /* sizeof of keyword_tbl */
extern struct c_proc *opblks[];  /* maps opcode to corresponding operator blocks */
extern struct c_proc *keyblks[];  /* maps keyword number to corresponding function blocks */
extern word dodump;		/* termination dump */
extern int set_up;
extern long starttime;          /* used with millisec() for calculating &time */
extern int collecting;          /* non-zero whilst a GC is taking place */
extern int collected;           /* global collection count of all collections */
extern uword stacklim;          /* limit of stack use which may trigger a GC */
extern word stackcushion;       /* % factor to apply to total stack usage to avoid GC thrashing */

extern uword coexp_ser;         /* Serial numbers for object creation */
extern uword list_ser;
extern uword set_ser;
extern uword table_ser;
extern uword weakref_ser;
extern uword methp_ser;

extern char *allchars;          /* array for making one-character strings */
extern char *blkname[];		/* print names for block types. */
extern char *currend;		/* current end of memory region */
extern int bsizes[];		/* sizes of blocks */
extern int firstd[];		/* offset (words) of first descrip. */
extern uword segsize[];		/* size of hash bucket segment */

#define OGHASH_SIZE 32
extern struct other_global *og_hash[OGHASH_SIZE];

extern struct progstate *progs; /* list of progstates */
extern struct b_cset *emptycs;   /* '' */
extern struct b_cset *blankcs;   /* ' ' */
extern struct b_cset *lparcs;    /* '(' */
extern struct b_cset *rparcs;    /* ')' */

extern struct descrip blank;	/* blank */
extern struct descrip emptystr;	/* empty string */

extern struct descrip nullptr;	/* descriptor with null block pointer */
extern struct descrip lcase;	/* lowercase string */
extern struct descrip nulldesc;	/* &null value */
extern struct descrip yesdesc;	/* &yes value */
extern struct descrip onedesc;	/* one */
extern struct descrip ucase;	/* uppercase string */
extern struct descrip zerodesc;	/* zero */
extern struct descrip minusonedesc;	/* -ve one */
extern struct descrip thousanddesc;	/* 1000 */
extern struct descrip milliondesc;	/* 1000000 */
extern struct descrip billiondesc;	/* 10^9 */
extern struct descrip defaultwindowlabel;	/* ucs string, the default window label */

extern struct c_proc Bdeferred_method_stub;  /* Deferred method block */

extern word memcushion;		/* memory region cushion factor */
extern word memgrowth;		/* memory region growth factor */
extern double defaultfontsize;  /* default font size */
extern char *defaultfont;       /* default font spec */
extern double defaultleading;   /* default leading */
extern word defaultipver;       /* default ip version for dns lookup */

extern struct tend_desc *tendedlist;  /* chain of tended descriptors */

extern struct descrip csetdesc;		/* cset descriptor */
extern struct descrip rzerodesc;	/* real 0.0 descriptor */

extern struct sdescrip fdf;             /* string "fd" */
extern struct sdescrip ptrf;            /* string "ptr" */
extern struct sdescrip dsclassname;     /* string "io.DescStream" */


/*
 * External declarations for the interpreter.
 */
   
extern word *ipc;			/* interpreter program counter */
extern struct b_cset *k_ascii;	/* value of &ascii */
extern struct b_cset *k_cset;	/* value of &cset */
extern struct b_cset *k_uset;	/* value of &uset */
extern struct b_cset *k_digits;	/* value of &lcase */
extern struct b_cset *k_lcase;	/* value of &lcase */
extern struct b_cset *k_letters;	/* value of &letters */
extern struct b_cset *k_ucase;	/* value of &ucase */
extern struct b_ucs *emptystr_ucs;     /* ucs empty string */
extern struct b_ucs *blank_ucs;        /* ucs blank string */

extern struct progstate *curpstate;
extern struct b_coexpr *k_current;
extern struct p_frame *curr_pf;
extern word *ipc;
extern struct c_frame *curr_cf;           /* currently executing c frame */

extern struct progstate rootpstate;

extern struct oisymbols oiexported;
   
extern word curr_op;
extern dptr xexpr;
extern dptr xfield;
extern dptr xargp;
extern int xnargs;
extern dptr xarg1, xarg2, xarg3;   /* Operator args */

/*
 * graphics
 */
extern char c1list[], c2list[], c3list[], c4list[];
