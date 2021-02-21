/*
 * Run-time data structures.
 */

/*
 * Descriptor
 */

struct descrip {		/* descriptor */
    word dword;			/*   type field */
    union {
#if RealInDesc
        double realval;         /*   real value */
#endif
        word integer;		/*   integer value */
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
 * Location in a source file
 */
struct loc {
    dptr fname;                 /* File name */
    word line;                  /* Line number */
};

struct b_bignum {		/* large integer block */
    word title;			/*   T_Lrgint */
    word blksize;		/*   block size */
    word msd, lsd;		/*   most and least significant digits */
    int sign;			/*   sign; 0 positive, 1 negative */
    DIGIT digits[1];		/*   digits */
};

#if !RealInDesc
struct b_real {			/* real block */
    word title;			/*   T_Real */
#if DOUBLE_HAS_WORD_ALIGNMENT
    double realval;		/*   value */
#else
    word realval[DoubleWords];
#endif
};
#endif

struct b_cset_range {
    word index,                 /* Index (zero-based) of first element */
        from,                   /* First element in range */
        to;                     /* Last element, >= first */
};

struct b_cset {			/* cset block */
    word title;			/*   T_Cset */
    word blksize;		/*   block size */
    word size;			/*   size of cset */
    word bits[CsetSize];	/*   array of bits for quick lookup of first 256 chars */
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
    uword id;			/*   identification number */
    word changecount;           /*   count of structure changes (see lgstate) */
    union block *listhead;	/*   pointer to first list-element block */
    union block *listtail;	/*   pointer to last list-element block */
};

#define PROC_BASE \
    word title;			/*   T_Proc */ \
    word type;                  /*   structure type, C_Proc or P_Proc */ \
    word nparam;		/*   number of parameters */ \
    word vararg;                /*      vararg flag */ \
    struct class_field *field;  /*   For a method, a pointer to the corresponding class_field.  The only */ \
                                /*     exception is the deferred method stub, which can be pointed to by */ \
                                /*     many different fields of course. */ \
    dptr name;              	/*   procedure name (pointer to string qualifier) */

struct b_proc {			/* procedure block */
    PROC_BASE
};

struct p_proc {
    PROC_BASE
    word *icode;		/*   pointer to icode */
    word creates;               /*   flag, set if has any create ops in it */
    word ndynam;		/*   number of dynamic locals */
    word nstatic;		/*   number of static locals */
    dptr fstatic;		/*   pointer to first static, or null if there are none */
    struct progstate *program;  /*   program in which this procedure resides; null for Internal kind */
    word nclo;                  /*   count of various elements that make up a frame for this */
    word ntmp;                  /*     procedure */
    word nlab;
    word nmark;
    word package_id;            /*   package id of package in which this proc resides; 0=not in 
                                 *     a package; 1=lang; >1=other package */
    dptr *lnames;               /*   list of local names (qualifiers), null for an Internal kind */
    struct loc *llocs;	        /*   locations of local names, or null if not available */
};

struct c_frame;

struct c_proc {
    PROC_BASE
    int (*ccode)(struct c_frame *); /*   C implementation */
    word framesize;             /*   frame struct size */
    word ntend;                 /*   num tended needed */
    word underef;               /*   underef flag */
};

struct b_constructor {		/* constructor block */
    word title;			/*   T_Constructor */
    struct progstate *program;  /*   program in which this constructor resides */
    word package_id;            /*   Package id of this constructor's package - see b_proc above */
    uword instance_ids;         /*   Sequence for instance ids */
    word n_fields;
    dptr name;           	/*   record type name (pointer to string qualifier) */
    word *fnums;                /* Pointer to array of field numbers array */
    struct loc *field_locs;     /* Source location of fields or null if not available */
    uint16_t *sorted_fields;    /* An array of indices giving the order sorted by name */
};

struct b_record {		/* record block */
    word title;			/*   T_Record */
    word blksize;		/*   size of block */
    uword id;			/*   identification number */
    struct b_constructor *constructor;	/*   pointer to record constructor */
    struct descrip fields[1];	/*   fields */
};

/*
 * This struct represents a field in a class.  If a subclass inherits
 * a field, then the subclass and parent class will both point to the
 * same instance.
 */
struct class_field {
    word fnum;                         /* Field number */
    word flags;
    struct b_class *defining_class;
    dptr field_descriptor;             /* Pointer to descriptor; null if an instance field */
};

struct b_class {                 /* block representing a class - always static, never allocated */
    word title;                  /* T_Class */
    struct progstate *program;   /* Program in which this class resides */
    word package_id;             /* Package id of this class's package - see b_proc above */
    uword instance_ids;          /* Sequence for instance ids */
    word init_state;             /* State of initialization */
    word flags;                  /* Modifier flags from the source code */
    word n_supers;               /* Number of supers */
    word n_implemented_classes;  /* Number of implemented classes */
    word n_instance_fields;      /* Number of instance fields */
    word n_class_fields;         /* Number of class fields (statics & methods) */
    dptr name;             	 /* Class name (pointer to string qualifier) */
    struct class_field *init_field; /* Pointer to "init" field, or null if absent */
    struct class_field *new_field;  /* Pointer to "new" field, or null if absent */
    struct b_class **supers;     /* Array of pointers to supers */
    struct b_class **implemented_classes;  /* Array of pointers to implemented classes, sorted by 
                                            * ascending address to allow binary search */
    struct class_field **fields;  /* Pointers to field info; one for each field */
    uint16_t *sorted_fields;      /* An array of indices into fields, giving the order sorted by
                                   * field number (and hence also sorted by name) */
};

struct b_object {		/* object block */
    word title;			/*   T_Object */
    word blksize;		/*   size of block */
    uword id;			/*   identification number */
    word init_state;            /*   state of initialization */
    struct b_class *class;	/*   pointer to class, being the type of this instance */
    struct descrip fields[1];	/*   instance fields */
};

/*
 * Block for a method pointer.
 */
struct b_methp {                /* method pointer */
    word title;                 /*   T_Methp */
    uword id;			/*   identification number */
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
    word n_off_l_indexed;       /*   how many offsets entries have already been calculated, starting at the left */
    word n_off_r_indexed;       /*   how many offsets entries have already been calculated, starting at the right */
    word offset_bits;           /*   number of bits in an offset; 8, 16, 32 or 64 depending on length of utf8 */
    word index_step;            /*   how many unicode chars between offset entries, zero for ascii-only utf8,
                                 *   since we can then use simple direct indexing. */
    word off[1];                /*   offset data, a packed array of offsets, each entry is offset_bits wide */
};

/*
 * Block for a weak reference.
 */
struct b_weakref {              /* weakref */
    word title;                 /*   T_Weakref */
    uword id;			/*   identification number */
    struct b_weakref *chain;    /*   link used during gc */
    struct descrip val;         /*   the referenced value */
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
    uword id;			/*   identification number */
    word mask;			/*   mask for slot num, equals n slots - 1 */
    struct b_slots *hdir[HSegs];	/*   directory of hash slot segments */
};

struct b_table {		/* table-header block */
    word title;			/*   T_Table */
    word size;			/*   current table size */
    uword id;			/*   identification number */
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
    struct descrip tref;	/*   entry value */
    struct descrip tval;	/*   assigned value */
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
    struct descrip tref;	/*   entry value */
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
 * Structure for keeping list generator state across a suspension.
 */
struct lgstate {		/* list generator state */
    word listindex;		/* notional list index */
    word listsize;              /* last size of subject list */
    word changecount;		/* last changecount of subject list */
    word blockpos;  		/* index in current element block */
    word result;		/* computed position of current element in element block */
};


/*
 * Structure for chaining tended descriptors.
 */
struct tend_desc {
    struct tend_desc *previous;
    int num;
    struct descrip d[1]; /* actual size of array indicated by num */
};


struct dpair {
    struct descrip dr;
    struct descrip dv;
};

struct inline_field_cache {
    union block *class;
#if WordBits == 64
    uint32_t index;
    int32_t  access;
#elif WordBits == 32
    uint16_t index;
    int16_t access;
#endif
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
    uword size;				/* allocated region size in bytes */
    int compacted;                      /* count of how many times compacted */
    char *base;				/* start of region */
    char *end;				/* end of region */
    char *free;				/* free pointer */
    struct region *prev, *next;		/* forms a linked list of regions */
    struct region *Gprev, *Gnext;	/* global (all programs) lists */
};


/*
 * Structures for the interpreter.
 */

/*
 * Declarations for entries in tables associating icode location with
 *  source program location.
 */
struct ipc_fname {
    word *ipc;		  /* pointer into code region */
    dptr fname;           /* file name string descriptor */
};

struct ipc_line {
    word *ipc;		/* pointer into code region */
    word line;		/* line number */
};

/*
 * Structure for holding a list of descriptor pointers.
 */
struct dptr_list {
    struct dptr_list *next;
    dptr dp;
};

struct prog_event {
    struct descrip eventcode;
    struct descrip eventval;
    struct prog_event *next;
};

/*
 * A structure representing a table of pointers to descriptors subject
 * to garbage collection (see rmemmgt.r).
 */
DefineHash(og_table, struct dptr_list);

/*
 * Program state encapsulation.  This consists of the VARIABLE parts of
 * many global structures.
 */
struct progstate {
    word IcodeSize;			/* size of icode */
    struct progstate *next;

    struct progstate *monitor;
    struct b_cset *eventmask;
    struct prog_event *event_queue_head, *event_queue_tail;
    struct timeval last_tick;
    word timer_interval;

    /*
     * trapped variable keywords' values
     */
    struct descrip Kywd_handler;
    struct descrip Kywd_pos;
    struct descrip Kywd_subject;
    struct descrip Kywd_prog;
    struct descrip Kywd_why;
    struct descrip Kywd_ran;
    struct descrip Kywd_trace;
    struct descrip Kywd_dump;
    struct descrip Kywd_maxlevel;
    char *Code;
    char *Ecode;
    word Offset;        /* Amount to add to icode addresses on relocation */

    dptr ClassStatics, EClassStatics;
    dptr ClassMethods, EClassMethods;
    struct class_field *ClassFields, *EClassFields;
    struct loc *ClassFieldLocs, *EClassFieldLocs;
    dptr *Fnames, *Efnames;
    dptr Globals, Eglobals;
    dptr *Gnames, *Egnames;
    char *Gflags, *Egflags;
    struct loc *Glocs, *Eglocs;
    dptr Statics, Estatics;
    dptr *Snames, *Esnames;
    dptr TCaseTables, ETCaseTables;
    dptr Constants, Econstants;
    int NGlobals, NStatics, NConstants, NTCaseTables;
    char *Strcons, *AsciiStrcons, *Estrcons;
    struct ipc_fname *Filenms, *Efilenms;
    struct ipc_line *Ilines, *Elines;
    struct ipc_line *Current_line_ptr;
    struct ipc_fname *Current_fname_ptr;
    dptr Current_fname;
    dptr MainProc;

    struct timeval start_time;          /* time program started */

    uint64_t stringtotal;		/* cumulative total allocation */
    uint64_t blocktotal;		/* cumulative total allocation */

    uword stackcurr;			/* current stack allocation in use (frame
                                         * and local structs) */

    int collected_user;                 /* number of user triggered collections */
    int collected_string;               /* number of string collect requests */
    int collected_block;                /* number of block collect requests */
    int collected_stack;                /* number of stack collect requests */

    struct dptr_list *global_vars;      /* list of pointers to global variables to make */
                                        /* garbage collection quicker */
    struct region *stringregion;
    struct region *blockregion;

    int exited;                         /* set to 1 when the main procedure exits */

    int K_errornumber;
    struct descrip K_errortext;
    struct descrip K_errorvalue;
    struct b_coexpr *K_errorcoexpr;
    int Have_errval;
    struct descrip T_errortext;
    int T_errornumber;
    int T_have_val;
    struct descrip T_errorvalue;

    struct b_coexpr *K_current;
    struct b_coexpr *K_main;

    /*
     * Function Instrumentation Fields.
     */
    struct b_bignum * (*Alcbignum)(word);
    struct b_cset * (*Alccset)(word);
    union block * (*Alchash)(int);
    struct b_slots * (*Alcsegment)(word);
    struct b_list *(*Alclist_raw)(word,word);
    struct b_list *(*Alclist)(word,word);
    struct b_lelem *(*Alclstb)(word);
#if !RealInDesc
    struct b_real *(*Alcreal)(double);
#endif
    struct b_record *(*Alcrecd)(struct b_constructor *);
    struct b_object *(*Alcobject)(struct b_class *);
    struct b_methp *(*Alcmethp)(void);
    struct b_coexpr *(*Alccoexp)(void);
    struct b_ucs *(*Alcucs)(word);
    struct b_selem *(*Alcselem)(void);
    char *(*Alcstr)(char *, word);
    struct b_tvsubs *(*Alcsubs)(void);
    struct b_telem *(*Alctelem)(void);
    struct b_tvtbl *(*Alctvtbl)(void);
    struct b_weakref *(*Alcweakref)(void);
    void (*Dealcblk)(union block *);
    void (*Dealcstr)(char *);
    char * (*Reserve)(int, uword);

    void (*GeneralCall)(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);

    void (*GeneralAccess)(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                          word *failure_label);
    void (*GeneralInvokef)(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                           int argc, dptr args, word rval, word *failure_label);
};

struct b_coexpr {		/* co-expression block */
    word title;			/*   T_Coexpr */
    uword id;			/*   identification number */
    dptr tvalloc;		/*   where to place transmitted value */
    struct b_coexpr *activator; /*   this coexpression's activator */
    struct progstate *main_of;  /*   set to the parent program for all &main co-expressions;
                                 *   null for all others */
    word *start_label;          /*   where to start this coexpression */
    word *failure_label;        /*   where to go on a cofail */
    struct p_frame *curr_pf;    /*   current p_frame */
    struct frame *sp;           /*   top of stack */
    struct p_frame *base_pf;    /*   base of stack */
    word level;                 /*   depth of user recursion (&level) */
};


union block {			/* general block */
#if !RealInDesc
    struct b_real real;
#endif
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
    struct b_coexpr coexpr;
    struct b_slots slots;
    struct b_class class;
    struct b_object object;
    struct b_methp methp;
    struct b_constructor constructor;
    struct b_ucs ucs;
    struct b_bignum bignum;
    struct b_weakref weakref;
};

/*
 * This structure holds the argument and dynamic local variables for a
 * particular p_frame.  It may be referenced by several p_frames if
 * co-expressions are created by the original.
 */
struct frame_vars {
    int size;         /* Size and creator of this allocation */
    struct progstate *creator;
    dptr desc_end;    /* One past the end of the descriptor array */
    int refcnt;       /* How many p_frames reference this block */
    int seen;         /* Seen marker for garbage collection */
    struct descrip desc[1];
};

/*
 * Common elements for both frame types
 */
#define FRAME_BASE \
     int type;          /* Structure type */                            \
     int size;          /* Size and creator of this allocation */ \
     struct progstate *creator; \
     dptr lhs;               /* Place to put result */ \
     word *failure_label;    /* Caller's failure label */  \
     struct frame *parent_sp;  /* Parent in the stack chain */ \
     int rval;               /* Set if source location is an rval (ie cannot be assigned to) */  \
     int exhausted;          /* Set after a return, indicating that a further request for a result */ \
                             /*    would be bound to fail */

#define C_FRAME \
     FRAME_BASE   \
     struct c_proc *proc;    /* Corresponding procedure block */  \
     word pc;        /* C program counter */    \
     int nargs;      /* Number of args; may exceed declared number for a vararg func */ \
     dptr args;      /* Arg array - nargs descriptors */ \
     dptr tend;      /* Tended descriptor array */

struct frame {
    FRAME_BASE
};

struct c_frame {
    C_FRAME
};

struct p_frame {
    FRAME_BASE
    struct p_proc *proc;      /* Corresponding procedure block */        \
    word *ipc;                /* Program counter; note this is only up-to-date when
                               * frames change (see interp.r and the use of the ipc global var.) */
    word *curr_inst;          /* Location of start of current instruction */
    struct p_frame *caller;   /* Parent caller frame */
    struct frame **clo;       /* Closures, ie other frames in the process of producing results */
    dptr tmp;                 /* Temporary descriptor array */
    word **lab;               /* Labels array */
    struct frame **mark;      /* Stack mark array */
    struct frame_vars *fvars; /* Argument and dynamic local descriptor structure - may be shared between
                               * several p_frames. */
};

#include "oisymbols.h"
