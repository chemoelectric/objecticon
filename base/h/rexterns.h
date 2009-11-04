/*
 * External declarations for the run-time system.
 */

/*
 * External declarations common to the compiler and interpreter.
 */

extern struct b_proc *op_tbl[]; /* operators available for string invocation */
extern int op_tbl_sz;           /* number of operators in op_tbl */
extern struct b_proc *fnc_tbl[]; /* builtin functions */
extern int fnc_tbl_sz;           /* sizeof of fnc_tbl */
extern struct b_proc *opblks[];  /* maps opcode to corresponding operator blocks */
extern struct b_proc *keyblks[];  /* maps keyword number to corresponding function blocks */
extern word dodump;		/* termination dump */
extern int set_up;
extern int collecting;          /* non-zero whilst a GC is taking place */
extern uword stacklim;          /* limit of stack use which may trigger a GC */

extern char *allchars;          /* array for making one-character strings */
extern char *blkname[];		/* print names for block types. */
extern char *currend;		/* current end of memory region */
extern int bsizes[];		/* sizes of blocks */
extern int firstd[];		/* offset (words) of first descrip. */
extern uword segsize[];		/* size of hash bucket segment */
extern int k_level;		/* value of &level */

extern struct progstate *progs; /* list of progstates */
extern struct b_cset *blankcs;   /* ' ' */
extern struct b_cset *lparcs;    /* '(' */
extern struct b_cset *rparcs;    /* ')' */

extern struct descrip blank;	/* blank */
extern struct descrip emptystr;	/* empty string */
extern struct descrip trashcan; /* for any unwanted value */

extern struct descrip nullptr;	/* descriptor with null block pointer */
extern struct descrip lcase;	/* lowercase string */
extern struct descrip maps2;	/* second argument to map() */
extern struct descrip maps3;	/* third argument to map() */
extern struct descrip maps2u;	/* second argument to map(), ucs case */
extern struct descrip maps3u;	/* third argument to map(), ucs case */
extern struct descrip nulldesc;	/* null value */
extern struct descrip onedesc;	/* one */
extern struct descrip ucase;	/* uppercase string */
extern struct descrip zerodesc;	/* zero */
extern struct descrip minusonedesc;	/* -ve one */
extern struct descrip thousanddesc;	/* 1000 */
extern struct descrip milliondesc;	/* 1000000 */

extern struct b_proc Bdeferred_method_stub;  /* Deferred method block */

extern word qualsize;		/* size of string qualifier list */
extern word memcushion;		/* memory region cushion factor */
extern word memgrowth;		/* memory region growth factor */

extern struct tend_desc *tend;  /* chain of tended descriptors */

extern char typech[];
extern word oldsum;
extern struct descrip csetdesc;		/* cset descriptor */
extern struct descrip eventdesc;	/* event descriptor */
extern struct descrip rzerodesc;	/* real 0.0 descriptor */
extern struct b_real realzero;          /* real zero block */



/*
 * External declarations for the interpreter.
 */
   
extern word *ipc;			/* interpreter program counter */
extern int ilevel;			/* interpreter level */
extern int ntended;			/* number of active tended descriptors*/
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
extern int noMTevents;		/* no MT events during GC */
   
extern int over_flow;

extern stringint attribs[], drawops[];

extern word curr_op;
extern dptr xexpr;
extern dptr xfield;
extern dptr xargp;
extern int xnargs;

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

#if UNIX && E_Tick
extern union tickerdata ticker;
extern unsigned long oldtick;
#endif					/* UNIX && E_Tick */

