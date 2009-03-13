/*
 * Run-time data structures.
 */

/*
 * Structures common to the compiler and interpreter.
 */


/*
 * Descriptor
 */

struct descrip {		/* descriptor */
    word dword;			/*   type field */
    union {
        word integr;		/*   integer value */
        char *sptr;		/*   pointer to character string */
        union block *bptr;	/*   pointer to a block */
        dptr descptr;		/*   pointer to a descriptor */
    } vword;
};

struct sdescrip {
    word length;		/*   length of string */
    char *string;		/*   pointer to string */
};

struct si_ {
    char *s;
    int i;
};
typedef struct si_ stringint;


/*
 * structure supporting dynamic record types
 */
struct b_constructor_list {
    struct b_constructor *this;
    struct b_constructor_list *next;
};

/*
 * Location in a source file
 */
struct loc {
    struct descrip fname;       /* File name */
    int line;                   /* Line number */
};

struct b_bignum {		/* large integer block */
    word title;			/*   T_Lrgint */
    word blksize;		/*   block size */
    word msd, lsd;		/*   most and least significant digits */
    int sign;			/*   sign; 0 positive, 1 negative */
    DIGIT digits[1];		/*   digits */
};

struct b_real {			/* real block */
    word title;			/*   T_Real */
    double realval;		/*   value */
};

struct b_cset_range {
    word index,                 /* Index (zero-based) of first element */
        from,                   /* First element in range */
        to;                     /* Last element, >= first */
};

struct b_cset {			/* cset block */
    word title;			/*   T_Cset */
    word blksize;		/*   block size */
    word size;			/*   size of cset */
    unsigned int bits[CsetSize];		/*   array of bits */
    word n_ranges;
    struct b_cset_range range[1];
};

struct b_lelem {		/* list-element block */
    word title;			/*   T_Lelem */
    word blksize;		/*   size of block */
    union block *listprev;	/*   previous list-element block */
    union block *listnext;	/*   next list-element block */
    word nslots;		/*   total number of slots */
    word first;			/*   index of first used slot */
    word nused;			/*   number of used slots */
    struct descrip lslots[1];	/*   array of slots */
};

struct b_list {			/* list-header block */
    word title;			/*   T_List */
    word size;			/*   current list size */
    word id;			/*   identification number */
    union block *listhead;	/*   pointer to first list-element block */
    union block *listtail;	/*   pointer to last list-element block */
};

struct b_proc {			/* procedure block */
    word title;			/*   T_Proc */
    word blksize;		/*   size of block */

    union {			/*   entry points for */
        int (*ccode)();	        /*     C routines */
        uword ioff;		/*     and icode as offset */
        pointer icode;		/*     and icode as absolute pointer */
    } entryp;

    word nparam;		/*   number of parameters */
    word ndynam;		/*   number of dynamic locals; < 0 => builtin function */
    word nstatic;		/*   number of static locals */
    dptr fstatic;		/*   pointer to first static, or null if there are none */
    struct progstate *program;  /*   program in which this procedure resides */
    word package_id;            /*   package id of package in which this proc resides; 0=not in 
                                 *     a package; 1=lang; >1=other package */
    struct class_field *field;  /*   For a method defined in the icode, a pointer to the 
                                 *   corresponding class_field.  For all other types of b_proc
                                 *   this is null. */
    struct descrip pname;	/*   procedure name (string qualifier) */
    dptr lnames;                /*   list of local names (qualifiers) */
    struct loc *llocs;	        /*   locations of local names, or null if not available */
};

struct b_constructor {		/* constructor block */
    word title;			/*   T_Constructor */
    word blksize;		/*   size of block */
    struct progstate *program;  /*   program in which this constructor resides */
    word package_id;            /*   Package id of this constructor's package - see b_proc above */
    word instance_ids;          /*   Sequence for instance ids */
    word n_fields;
    struct descrip name;	/*   record type name (string qualifier) */
    dptr field_names;           /* Pointers to field names array */
    struct loc *field_locs;     /* Source location of fields or null if not available */
    short *sorted_fields;       /* An array of indices giving the order sorted by name */
};

struct b_record {		/* record block */
    word title;			/*   T_Record */
    word blksize;		/*   size of block */
    word id;			/*   identification number */
    struct b_constructor *constructor;	/*   pointer to record constructor */
    struct descrip fields[1];	/*   fields */
};

/*
 * This struct represents a field in a class.  If a subclass inherits
 * a field, then the subclass and parent class will both point to the
 * same instance.
 */
struct class_field {
    struct descrip name;               /* Field name (string qualifier) */
    word fnum;                         /* Field number */
    word flags;
    struct b_class *defining_class;
    dptr field_descriptor;             /* Pointer to descriptor; null if an instance field */
};

struct b_class {                 /* block representing a class - always static, never allocated */
    word title;                  /* T_Class */
    word blksize;
    struct progstate *program;   /* Program in which this class resides */
    word package_id;             /* Package id of this class's package - see b_proc above */
    word instance_ids;           /* Sequence for instance ids */
    word init_state;             /* State of initialization */
    word flags;                  /* Modifier flags from the source code */
    word n_supers;               /* Number of supers */
    word n_implemented_classes;  /* Number of implemented classes */
    word n_instance_fields;      /* Number of instance fields */
    word n_class_fields;         /* Number of class fields (statics & methods) */
    struct descrip name;	 /*  Class name (string qualifier) */
    struct class_field *init_field; /* Pointer to "init" field, or null if absent */
    struct class_field *new_field;  /* Pointer to "new" field, or null if absent */
    struct b_class **supers;     /* Array of pointers to supers */
    struct b_class **implemented_classes;  /* Array of pointers to implemented classes, sorted by 
                                            * ascending address to allow binary search */
    struct class_field **fields;  /* Pointers to field info; one for each field */
    short *sorted_fields;       /* An array of indices into fields, giving the order sorted by
                                 * field number (and hence also sorted by name) */
};

struct b_object {		/* object block */
    word title;			/*   T_Object */
    word blksize;		/*   size of block */
    word id;			/*   identification number */
    word init_state;            /*   state of initialization */
    struct b_class *class;	/*   pointer to class, being the type of this instance */
    struct descrip fields[1];	/*   instance fields */
};

struct b_cast {                 /* object cast */
    word title;                 /*   T_Cast */
    struct b_object *object;	/*   the thing being cast */
    struct b_class *class;	/*   the target class */
};

/*
 * Block for a method pointer.
 */
struct b_methp {                /* method pointer */
    word title;                 /*   T_Methp */
    struct b_object *object;	/*   the instance */
    struct b_proc *proc;	/*   the method */
};

/*
 * Unicode character string.
 */
struct b_ucs {
    word title;                 /*   T_Ucs */
    word blksize;		/*   block size */
    word length;                /*   unicode string length */
    struct descrip utf8;	/*   the utf-8 representation */
    word n_off_indexed;         /*   how many offsets entries have already been calculated */
    word index_step;            /*   how many unicode chars between offset entries */
    word off[1];                /*   offsets: ((length-1) / index_step) are allocated */
};

struct b_selem {		/* set-element block */
    word title;			/*   T_Selem */
    union block *clink;		/*   hash chain link */
    uword hashnum;		/*   hash number */
    struct descrip setmem;	/*   the element */
};

/*
 * A set header must be a proper prefix of a table header,
 *  and a set element must be a proper prefix of a table element.
 */
struct b_set {			/* set-header block */
    word title;			/*   T_Set */
    word size;			/*   size of the set */
    word id;			/*   identification number */
    word mask;			/*   mask for slot num, equals n slots - 1 */
    struct b_slots *hdir[HSegs];	/*   directory of hash slot segments */
};

struct b_table {		/* table-header block */
    word title;			/*   T_Table */
    word size;			/*   current table size */
    word id;			/*   identification number */
    word mask;			/*   mask for slot num, equals n slots - 1 */
    struct b_slots *hdir[HSegs];	/*   directory of hash slot segments */
    struct descrip defvalue;	/*   default table element value */
};

struct b_slots {		/* set/table hash slots */
    word title;			/*   T_Slots */
    word blksize;		/*   size of block */
    union block *hslots[HSlots];	/*   array of slots (HSlots * 2^n entries) */
};

struct b_telem {		/* table-element block */
    word title;			/*   T_Telem */
    union block *clink;		/*   hash chain link */
    uword hashnum;		/*   for ordering chain */
    struct descrip tref;		/*   entry value */
    struct descrip tval;		/*   assigned value */
};

struct b_tvsubs {		/* substring trapped variable block */
    word title;			/*   T_Tvsubs */
    word sslen;			/*   length of substring */
    word sspos;			/*   position of substring */
    struct descrip ssvar;	/*   variable that substring is from */
};

struct b_tvtbl {		/* table element trapped variable block */
    word title;			/*   T_Tvtbl */
    union block *clink;		/*   pointer to table header block */
    uword hashnum;		/*   hash number */
    struct descrip tref;		/*   entry value */
};

struct b_external {		/* external block */
    word title;			/*   T_External */
    word blksize;		/*   size of block */
    word exdata[1];		/*   words of external data */
};

struct astkblk {		  /* co-expression activator-stack block */
    int nactivators;		  /*   number of valid activator entries in
				   *    this block */
    struct astkblk *astk_nxt;	  /*   next activator block */
    struct actrec {		  /*   activator record */
        word acount;		  /*     number of calls by this activator */
        struct b_coexpr *activator; /*     the activator itself */
    } arec[ActStkBlkEnts];
};

/*
 * Structure for keeping set/table generator state across a suspension.
 */
struct hgstate {		/* hashed-structure generator state */
    int segnum;			/* current segment number */
    word slotnum;		/* current slot number */
    word tmask;			/* structure mask before suspension */
    word sgmask[HSegs];		/* mask in use when the segment was created */
    uword sghash[HSegs];		/* hashnum in process when seg was created */
};


/*
 * Structure for chaining tended descriptors.
 */
struct tend_desc {
    struct tend_desc *previous;
    int num;
    struct descrip d[1]; /* actual size of array indicated by num */
};

/*
 * Structure for mapping string names of functions and operators to block
 * addresses.
 */
struct pstrnm {
    char *pstrep;
    struct b_proc *pblock;
};

struct dpair {
    struct descrip dr;
    struct descrip dv;
};

struct inline_field_cache {
    union block *class;
    int index;
};

struct inline_global_cache {
    struct progstate *program;
    dptr global;
};

/*
 * Allocated memory region structure.  Each program has linked lists of
 * string and block regions.
 */
struct region {
    word  size;				/* allocated region size in bytes */
    char *base;				/* start of region */
    char *end;				/* end of region */
    char *free;				/* free pointer */
    struct region *prev, *next;		/* forms a linked list of regions */
    struct region *Gprev, *Gnext;	/* global (all programs) lists */
};

#ifdef Double
/*
 * Data type the same size as a double but without alignment requirements.
 */
struct size_dbl {
    char s[sizeof(double)];
};
#endif					/* Double */

union numeric {			/* long integers or real numbers */
    long integer;
    double real;
    struct b_bignum *big;
};


/*
 * Structures for the interpreter.
 */

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
    word ipc;		  /* offset of instruction into code region */
    struct descrip fname; /* file name string descriptor */
};

struct ipc_line {
    word ipc;		/* offset of instruction into code region */
    int line;		/* line number */
};

/*
 * Program state encapsulation.  This consists of the VARIABLE parts of
 * many global structures.
 */
struct progstate {
    long hsize;				/* size of icode, 0 = C|Python|... */
    struct progstate *parent;
    struct progstate *next;
    struct descrip parentdesc;		/* implicit "&parent" */
    struct descrip eventmask;		/* implicit "&eventmask" */
    struct descrip opcodemask;		/* implicit "&opcodemask" */
    struct descrip eventcount;		/* implicit "&eventcount" */
    struct descrip valuemask;
    struct descrip eventcode;		/* &eventcode */
    struct descrip eventval;		/* &eventval */
    struct descrip eventsource;		/* &eventsource */
    dptr Glbl_argp;			/* global argp */

    /*
     * trapped variable keywords' values
     */
    struct descrip Kywd_err;
    struct descrip Kywd_pos;
    struct descrip Kywd_subject;
    struct descrip Kywd_prog;
    struct descrip Kywd_why;
    struct descrip Kywd_ran;
    struct descrip Kywd_trc;
    struct b_coexpr *Mainhead;
    char *Code;
    char *Ecode;

    dptr ClassStatics, EClassStatics;
    dptr ClassMethods, EClassMethods;
    struct class_field *ClassFields, *EClassFields;
    struct loc *ClassFieldLocs, *EClassFieldLocs;
    word *Classes;
    word *Records;
    dptr Fnames, Efnames;
    dptr Globals, Eglobals;
    dptr Gnames, Egnames;
    struct loc *Glocs, *Eglocs;
    dptr Statics, Estatics;
    int NGlobals, NStatics;
    char *Strcons, *Estrcons;
    struct ipc_fname *Filenms, *Efilenms;
    struct ipc_line *Ilines, *Elines;
    struct ipc_line * Current_line_ptr;
    struct ipc_fname * Current_fname_ptr;
    dptr MainProc;

    word Coexp_ser;			/* this program's serial numbers */
    word List_ser;
    word Set_ser;
    word Table_ser;

    word Kywd_time_elsewhere;		/* &time spent in other programs */
    word Kywd_time_out;			/* &time at last program switch out */

    uword stringtotal;			/* cumulative total allocation */
    uword blocktotal;			/* cumulative total allocation */
    word colltot;			/* total number of collections */
    word collstat;			/* number of static collect requests */
    word collstr;			/* number of string collect requests */
    word collblk;			/* number of block collect requests */
    struct region *stringregion;
    struct region *blockregion;

    word Lastop;

    dptr Xargp;
    word Xnargs;
    struct descrip Value_tmp;

    struct descrip K_current;
    int K_errornumber;
    struct descrip K_errortext;
    struct descrip K_errorvalue;
    int Have_errval;
    struct descrip T_errortext;
    int T_errornumber;
    int T_have_val;
    struct descrip T_errorvalue;

    struct descrip K_main;

    /*
     * Function Instrumentation Fields.
     */
    int (*Cplist)(dptr, dptr, word, word);
    int (*Cpset)(dptr, dptr, word);
    int (*Cptable)(dptr, dptr, word);
    int (*Interp)(int,dptr);
    int (*Cnvcset)(dptr,dptr);
    int (*Cnvucs)(dptr,dptr);
    int (*Cnvint)(dptr,dptr);
    int (*Cnvreal)(dptr,dptr);
    int (*Cnvstr)(dptr,dptr);
    int (*Cnvtstr)(char *,dptr,dptr);
    void (*Deref)(dptr,dptr);
    struct b_bignum * (*Alcbignum)(word);
    struct b_cset * (*Alccset)();
    union block * (*Alchash)(int);
    struct b_slots * (*Alcsegment)(word);
    struct b_list *(*Alclist_raw)(uword,uword);
    struct b_list *(*Alclist)(uword,uword);
    struct b_lelem *(*Alclstb)(uword,uword,uword);
    struct b_real *(*Alcreal)(double);
    struct b_record *(*Alcrecd)(struct b_constructor *);
    struct b_object *(*Alcobject)(struct b_class *);
    struct b_cast *(*Alccast)();
    struct b_methp *(*Alcmethp)();
    struct b_ucs *(*Alcucs)();
    struct b_refresh *(*Alcrefresh)(word *, int, int);
    struct b_selem *(*Alcselem)(dptr, uword);
    char *(*Alcstr)(char *, word);
    struct b_tvsubs *(*Alcsubs)(word, word, dptr);
    struct b_telem *(*Alctelem)(void);
    struct b_tvtbl *(*Alctvtbl)(dptr, dptr, uword);
    void (*Dealcblk)(union block *);
    void (*Dealcstr)(char *);
    char * (*Reserve)(int, word);
};


/*
 * Frame markers
 */
struct ef_marker {		/* expression frame marker */
    inst ef_failure;		/*   failure ipc */
    struct ef_marker *ef_efp;	/*   efp */
    struct gf_marker *ef_gfp;	/*   gfp */
    word ef_ilevel;		/*   ilevel */
};

struct pf_marker {		/* procedure frame marker */
    word pf_nargs;		/*   number of arguments */
    struct pf_marker *pf_pfp;	/*   saved pfp */
    struct ef_marker *pf_efp;	/*   saved efp */
    struct gf_marker *pf_gfp;	/*   saved gfp */
    dptr pf_argp;		/*   saved argp */
    inst pf_ipc;			/*   saved ipc */
    word pf_ilevel;		/*   saved ilevel */
    dptr pf_scan;		/*   saved scanning environment */
    struct progstate *pf_from;
    struct progstate *pf_to;
    struct descrip pf_locals[1];	/*   descriptors for locals */
};

struct gf_marker {		/* generator frame marker */
    word gf_gentype;		/*   type */
    struct ef_marker *gf_efp;	/*   efp */
    struct gf_marker *gf_gfp;	/*   gfp */
    inst gf_ipc;			/*   ipc */
    struct pf_marker *gf_pfp;	/*   pfp */
    dptr gf_argp;		/*   argp */
};

/*
 * Generator frame marker dummy -- used only for sizing "small"
 *  generator frames where procedure information need not be saved.
 *  The first five members here *must* be identical to those for
 *  gf_marker.
 */
struct gf_smallmarker {		/* generator frame marker */
    word gf_gentype;		/*   type */
    struct ef_marker *gf_efp;	/*   efp */
    struct gf_marker *gf_gfp;	/*   gfp */
    inst gf_ipc;			/*   ipc */
};

/*
 * b_iproc blocks are used to statically initialize information about
 *  functions.	They are identical to b_proc blocks except for
 *  the pname field which is a sdescrip (simple/string descriptor) instead
 *  of a descrip.  This is done because unions cannot be initialized.
 */
	
struct b_iproc {		/* procedure block */
    word ip_title;		/*   T_Proc */
    word ip_blksize;		/*   size of block */
    int (*ip_entryp)();		/*   entry point (code) */
    word ip_nparam;		/*   number of parameters */
    word ip_ndynam;		/*   number of dynamic locals */
    word ip_nstatic;		/*   number of static locals */
    dptr ip_fstatic;		/*   pointer to first static */
    struct progstate *ip_program;/*   not set */
    word package_id;
    struct class_field *field;  /*   For a method, a pointer to the corresponding class_field */
    struct sdescrip ip_pname;	/*   procedure name (string qualifier) */
    dptr ip_lnames;	        /*   list of local names (qualifiers) */
    struct loc *ip_llocs;	/*   locations of local names */
};

struct b_coexpr {		/* co-expression stack block */
    word title;			/*   T_Coexpr */
    word size;			/*   number of results produced */
    word id;			/*   identification number */
    struct b_coexpr *nextstk;	/*   pointer to next allocated stack */
    struct pf_marker *es_pfp;	/*   current pfp */
    struct ef_marker *es_efp;	/*   efp */
    struct gf_marker *es_gfp;	/*   gfp */
    struct tend_desc *es_tend;	/*   current tended pointer */
    dptr es_argp;		/*   argp */
    inst es_ipc;			/*   ipc */
    word es_ilevel;		/*   interpreter level */
    word *es_sp;			/*   sp */
    dptr tvalloc;		/*   where to place transmitted value */
    struct descrip freshblk;	/*   refresh block pointer */
    struct astkblk *es_actstk;	/*   pointer to activation stack structure */
    word cstate[CStateSize];	/*   C state information */
    struct progstate *program;
};

struct b_refresh {		/* co-expression block */
    word title;			/*   T_Refresh */
    word blksize;		/*   size of block */
    word *ep;			/*   entry point */
    word numlocals;		/*   number of locals */
    struct pf_marker pfmkr;	/*   marker for enclosing procedure */
    struct descrip elems[1];	/*   arguments and locals, including Arg0 */
};


union block {			/* general block */
    struct b_real realblk;
    struct b_cset cset;
    struct b_proc proc;
    struct b_list list;
    struct b_lelem lelem;
    struct b_table table;
    struct b_telem telem;
    struct b_set set;
    struct b_selem selem;
    struct b_record record;
    struct b_tvsubs tvsubs;
    struct b_tvtbl tvtbl;
    struct b_refresh refresh;
    struct b_coexpr coexpr;
    struct b_external externl;
    struct b_slots slots;
    struct b_class class;
    struct b_object object;
    struct b_cast cast;
    struct b_methp methp;
    struct b_constructor constructor;
    struct b_ucs ucs;
    struct b_bignum bignumblk;
};

union tickerdata { 			/* clock ticker -- keep in sync w/ fmonitor.r */
   unsigned short s[16];	/* 16 counters */
   unsigned long l[8];		/* 8 longs are easier to check */
};
