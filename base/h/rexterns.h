/*
 * External declarations for the run-time system.
 */

/*
 * External declarations common to the compiler and interpreter.
 */

extern struct b_proc *op_tbl;   /* operators available for string invocation */
extern int op_tbl_sz;           /* number of operators in op_tbl */
extern int debug_info;		/* flag: debugging information is available */
extern int err_conv;		/* flag: error conversion is supported */
extern int dodump;		/* termination dump */
extern int line_info;		/* flag: line information is available */
extern char *file_name;		/* source file for current execution point */

extern unsigned char allchars[];/* array for making one-character strings */
extern char *blkname[];		/* print names for block types. */
extern char *currend;		/* current end of memory region */
extern dptr *quallist;		/* start of qualifier list */
extern int bsizes[];		/* sizes of blocks */
extern int firstd[];		/* offset (words) of first descrip. */
extern uword segsize[];		/* size of hash bucket segment */
extern int k_level;		/* value of &level */

extern struct b_coexpr *stklist;/* base of co-expression stack list */
extern struct b_cset blankcs;   /* ' ' */
extern struct b_cset lparcs;    /* '(' */
extern struct b_cset rparcs;    /* ')' */
extern struct b_cset fullcs;    /* cset containing all characters */
extern struct descrip blank;	/* blank */
extern struct descrip emptystr;	/* empty string */

extern struct descrip kywd_dmp; /* descriptor for &dump */
extern struct descrip nullptr;	/* descriptor with null block pointer */
extern struct descrip lcase;	/* lowercase string */
extern struct descrip letr;	/* letter "r" */
extern struct descrip maps2;	/* second argument to map() */
extern struct descrip maps3;	/* third argument to map() */
extern struct descrip nulldesc;	/* null value */
extern struct descrip onedesc;	/* one */
extern struct descrip ucase;	/* uppercase string */
extern struct descrip zerodesc;	/* zero */
extern struct descrip minusonedesc;	/* -ve one */

extern struct b_iproc Bdeferred_method_stub;  /* Deferred method block */

extern word mstksize;		/* size of main stack in words */
extern word stksize;		/* size of co-expression stacks in words */
extern word qualsize;		/* size of string qualifier list */
extern word memcushion;		/* memory region cushion factor */
extern word memgrowth;		/* memory region growth factor */
extern uword stattotal;		/* cumulative total of all static allocations */
				/* N.B. not currently set */

extern struct tend_desc *tend;  /* chain of tended descriptors */

/*
 * Externals that are conditional on features.
 */


#ifdef Graphics
   extern int pollctr;
#endif					/* Graphics */

extern char typech[];
extern word oldsum;
extern struct descrip csetdesc;		/* cset descriptor */
extern struct descrip eventdesc;	/* event descriptor */
extern struct b_iproc mt_llist;
extern struct descrip rzerodesc;	/* real descriptor */
extern struct b_real realzero;		/* real zero block */

/*
 * Externals conditional on multithreading.
 */

/* dynamic record types */
extern int longest_dr;
extern struct b_constructor_list **dr_arrays;

/*
 * Externals that differ between compiler and interpreter.
 */
   /*
    * External declarations for the interpreter.
    */
   
   extern inst ipc;			/* interpreter program counter */
   extern int ilevel;			/* interpreter level */
   extern int ntended;			/* number of active tended descriptors*/
   extern struct b_cset k_ascii;	/* value of &ascii */
   extern struct b_cset k_cset;		/* value of &cset */
   extern struct b_cset k_digits;	/* value of &lcase */
   extern struct b_cset k_lcase;	/* value of &lcase */
   extern struct b_cset k_letters;	/* value of &letters */
   extern struct b_cset k_ucase;	/* value of &ucase */
   extern struct descrip tended[];	/* tended descriptors */
   extern struct ef_marker *efp;	/* expression frame pointer */
   extern struct gf_marker *gfp;	/* generator frame pointer */
   extern struct pf_marker *pfp;	/* procedure frame pointer */
   extern word *sp;			/* interpreter stack pointer */
   extern word *stack;			/* interpreter stack base */
   extern word *stackend;		/* end of evaluation stack */
   
   extern struct pstrnm pntab[];
   extern int pnsize;
   
      extern struct progstate *curpstate;
      extern struct progstate rootpstate;
      extern int noMTevents;		/* no MT events during GC */
   

extern stringint attribs[], drawops[];

/*
 * graphics
 */
#ifdef Graphics
   
   extern wbp wbndngs;
   extern wcp wcntxts;
   extern wsp wstates;
   extern int GraphicsLeft, GraphicsUp, GraphicsRight, GraphicsDown;
   extern int GraphicsHome, GraphicsPrior, GraphicsNext, GraphicsEnd;
   extern int win_highwater, canvas_serial, context_serial;
   extern clock_t starttime;		/* start time in milliseconds */


   #ifdef XWindows
      extern struct _wdisplay * wdsplys;
      extern stringint cursorsyms[];
   #endif				/* XWindows */

   #ifdef MSWindows
      extern HINSTANCE mswinInstance;
      extern int ncmdShow;
   #endif				/* MSWindows */

#endif					/* Graphics */

