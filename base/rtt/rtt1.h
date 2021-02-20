#include "preproc.h"
#include "pproto.h"

#define IndentInc 3
#define MaxCol 80

/*
 * cfile is used to create a list of cfiles created from a source file.
 */
struct cfile {
   char *name;
   struct cfile *next;
   };

/*
 * srcfile is an entry of dependants of a source file.
 */
struct srcfile {
   char *name;
   struct cfile *dependents;
   struct srcfile *next;
   };


/*
 * The lexical analyzer recognizes 3 states. Operators are treated differently
 *  in each state.
 */
#define DfltLex  0    /* Covers most input. */
#define OpHead   1    /* In head of an operator definition. */
#define TypeComp 2    /* In abstract type computation */

extern int lex_state;      /* state of operator recognition */
extern FILE *out_file;     /* output file */
extern int def_fnd;        /* C input defines something concrete */
extern char *inclname;     /* include file to be included by C compiler */
extern char *importedhname;  /* include file to be included with -x option */
extern char *cname;        /* current C filename */
extern int enable_out;     /* enable output of C code */
extern int importing;       /* input file is to form a library module using
                            * imported oisymbols structure */
extern int subsid;         /* file is susbidiary to other object or executable */

/*
 * The symbol table is used by the lexical analyser to decide whether an
 *  identifier is an ordinary identifier, a typedef name, or a reserved
 *  word. It is used by the parse tree builder to decide whether an
 *  identifier is an ordinary C variable, a tended variable, a parameter
 *  to a run-time routine, or the special variable "result".
 */
struct sym_entry {
   int tok_id;	       /* Ident, TokType, or identification of reserved word */
   char *image;		/* image of symbol */
   int id_type;		/* OtherDcl, TndDesc, TndStr, TndBlk, Label, RtParm,
                           DrfPrm */
   union {
      struct {			/* RtParm: */
         int param_num;		/*   parameter number */
         int cur_loc;		/*   PrmTend, PrmCStr, PrmInt, or PrmDbl */
         int non_tend;		/*   non-tended locations used */
         int parm_mod;          /*   something may have modified it */
         struct sym_entry *next;
         } param_info;
      struct {                  /* TndDesc, TndStr, TndBlk: */
         struct node *init;     /*   initial value from declaration */
         char *blk_name;	/*   TndBlk: struct name of block */
         struct sym_entry *next;
         } tnd_var;
      struct {			/* OtherDcl from "declare {...}" or in C code: */
         struct node *tqual;	/*   storage class, type qualifier list */
         struct node *dcltor;	/*   declarator */
         struct node *init;     /*   initial value from declaration */
         struct sym_entry *next;
         } declare_var;
      } u;
   int typ_indx;             /* index into arrays of type information */
   int t_indx;		/* index into tended array */
   int il_indx;		/* index used in in-line code */
   int f_indx;          /* index in function sym list */
   int nest_lvl;	/* 0 - reserved word, 1 - global, >= 2 - local */
   int may_mod;         /* may be modified in particular piece of code */
   int ref_cnt;
   struct sym_entry *next;
   struct sym_entry *fnext;
   };

/*
 * Path-specific parameter information must be saved and merged for
 *  branching and joining of paths.
 */
struct parminfo {
   int cur_loc;
   int parm_mod;
   };

/*
 * A list is maintained of information needed to initialize tended descriptors.
 */
struct init_tend {
   int t_indx;         /* index into tended array */
   int init_typ;       /* TndDesc, TndStr, TndBlk */
   struct node *init;  /* initial value from declaration */
   int nest_lvl;            /* level of nesting of current use of tended slot */
   int in_use;              /* tended slot is being used in current scope */
   struct init_tend *next;
   };


extern int op_type;                /* Function, Keyword, Operator, or OrdFunc */
extern char *op_name;              /* Name of curr func/keyword/op */
extern char *op_sym;               /* For an op, its symbol (eg ">=") */
extern int op_generator;           /* Does this op generate a sequence */
extern char *fname;                /* current source file name */
extern struct token *comment;      /* descriptive comment for current oper */
extern char *progname;
extern struct sym_entry *params;   /* current list of parameters */
extern struct sym_entry *decl_lst; /* declarations from "declare {...}" */
extern struct init_tend *tend_lst; /* list of allocated tended slots */
extern word lbl_num;               /* next unused label number */
extern struct sym_entry *v_len;    /* symbol entry for size of varargs */
extern int il_indx;                /* next index into data base symbol table */
extern struct sym_entry *ffirst,
                        *flast;    /* symbols declared in this function */

/*
 * lvl_entry keeps track of what is happening at a level of nested declarations.
 */
struct lvl_entry {
   int nest_lvl;
   int kind_dcl;	/* IsTypedef, TndDesc, TndStr, TndBlk, or OtherDcl */
   char *blk_name;      /* for TndBlk, the struct name of the block */
   int parms_done;      /* level consists of parameter list which is complete */
   struct sym_entry *tended; /* symbol table entries for tended variables */
   struct lvl_entry *next;
   };

extern struct lvl_entry *dcl_stk; /* stack of declaration contexts */

/*
 * Definitions for use in parse tree nodes.
 */

#define PrimryNd  1 /* simply a token */
#define PrefxNd   2 /* a prefix expression */
#define PstfxNd   3 /* a postfix expression */
#define BinryNd   4 /* a binary expression (not necessarily infix) */
#define TrnryNd   5 /* an expression with 3 subexpressions */
#define QuadNd    6 /* an expression with 4 subexpressions */
#define LstNd     7 /* list of declaration parts */
#define CommaNd   8 /* arg lst, declarator lst, or init lst, not comma op */
#define StrDclNd  9 /* structure field declaration */
#define PreSpcNd 10 /* prefix expression that needs a space after it */
#define ConCatNd 11 /* two ajacent pieces of code with no other syntax */
#define SymNd    12 /* a symbol (identifier) node */
#define ExactCnv 13 /* (exact)integer or (exact)C_integer conversion */
#define CompNd   14 /* compound statement */
#define AbstrNd  15 /* abstract type computation */
#define IcnTypNd 16 /* name of an Icon type */

#define NewNode(size) safe_zalloc((unsigned int)\
    (sizeof(struct node) + (size-1) * sizeof(union field)))

union field {
   struct node *child;
   struct sym_entry *sym;   /* used with SymNd & CompNd*/
   };

struct node {
   int nd_id;
   struct token *tok;
   union field u[1]; /* actual size varies with node type */
   };

/*
 * implement contains information about the implementation of an operation.
 */
#define NoRsltSeq  -1L	     /* no result sequence: {} */
#define UnbndSeq   -2L       /* unbounded result sequence: {*} */

/*
 * These codes are shared between the data base and rtt. They are defined
 *  here, though not all are used by the data base.
 */
#define TndDesc   1  /* a tended descriptor */
#define TndStr    2  /* a tended character pointer */
#define TndBlk    3  /* a tended block pointer */
#define OtherDcl  4  /* a declaration that is not special */
#define IsTypedef 5  /* a typedef */
#define VArgLen   6  /* identifier for length of variable parm list */
#define Label     8  /* label */

#define RtParm   16  /* undereferenced parameter of run-time routine */
#define DrfPrm   32  /* dereferenced parameter of run-time routine */
#define VarPrm   64  /* variable part of parm list (with RtParm or DrfPrm) */
#define PrmMark 128  /* flag - used while recognizing params of body fnc */
#define ByRef   256  /* flag - parameter to body function passed by reference */

/*
 * The following manifest constants are used to describe types, conversions,
 *   and returned values. Non-negative numbers are reserved for types described
 *   in the type specification system.
 */
#define TypAny    -1
#define TypEmpty  -2
#define TypVar    -3
#define TypCInt   -4
#define TypCDbl   -5
#define TypCStr   -6
#define TypEInt   -7
#define TypECInt  -8
#define TypStrOrUcs -11
#define TypNamedVar -12
#define TypStructVar -13
#define RetDesc  -14
#define RetNVar  -15
#define RetSVar  -16
#define RetNone  -17


/*
 * The parameter value of a run-time operation may be in one of several
 *  different locations depending on what conversions have been done to it.
 *  These codes are shared by rtt and iconc.
 */
#define PrmTend    1   /* in tended location */
#define PrmCStr    3   /* converted to C string: tended location */
#define PrmInt     4   /* converted to C int: non-tended location */
#define PrmDbl     8   /* converted to C double: non-tended location */

/*
 * Kind of RLT return statement supported.
 */
#define TRetNone  0   /* does not support an RTL return statement */
#define TRetBlkP  1   /* block pointer */
#define TRetDescP 2   /* descriptor pointer */
#define TRetCharP 3   /* character pointer */
#define TRetCInt  4   /* C integer */
#define TRetSpcl  5   /* RLT return statement has special form & semenatics */

/*
 * Codes for dereferencing needs.
 */
#define DrfNone  0  /* not a variable type */
#define DrfGlbl  1  /* treat as a global variable */
#define DrfCnst  2  /* type of values in variable doesn't change */
#define DrfSpcl  3  /* special dereferencing: trapped variable */

/*
 * Information about an Icon type.
 */
struct icon_type {
   char *id;		/* name of type */
   int support_new;	/* supports RTL "new" construct */
   int deref;		/* dereferencing needs */
   int rtl_ret;		/* kind of RTL return supported if any */
   char *typ;		/* for variable: initial type */
   int num_comps;	/* for aggregate: number of type components */
   int compnts;		/* for aggregate: index of first component */
   char *abrv;		/* abreviation used for type tracing */
   char *cap_id;	/* name of type with first character capitalized */
   };

/*
 * Information about a component of an aggregate type.
 */
struct typ_compnt {
   char *id;		/* name of component */
   int n;		/* position of component within type aggragate */
   int var;		/* flag: this component is an Icon-level variable */
   int aggregate;	/* index of type that owns the component */
   char *abrv;		/* abreviation used for type tracing */
   };

extern int num_typs;                 /* number of types in table */
extern struct icon_type icontypes[]; /* table of icon types */

/*
 * Type inference needs to know where most of the standard types
 *  reside. Some have special uses outside operations written in
 *  RTL code, such as the null type for initializing variables, and
 *  others have special semantics, such as trapped variables.
 */
extern int str_typ;                  /* index of string type */
extern int int_typ;                  /* index of integer type */
extern int rec_typ;                  /* index of record type */
extern int proc_typ;                 /* index of procedure type */
extern int coexp_typ;                /* index of co-expression type */
extern int stv_typ;                  /* index of sub-string trapped var type */
extern int ttv_typ;                  /* index of table-elem trapped var type */
extern int null_typ;                 /* index of null type */
extern int cset_typ;                 /* index of cset type */
extern int real_typ;                 /* index of real type */
extern int ucs_typ;                  /* index of ucs type */
extern int list_typ;                 /* index of list type */
extern int tbl_typ;                  /* index of table type */

extern int num_cmpnts;                 /* number of aggregate components */
extern struct typ_compnt typecompnt[]; /* table of aggregate components */
extern int str_var;                    /* index of trapped string variable */
extern int trpd_tbl;                   /* index of trapped table */
extern int lst_elem;                   /* index of list element */
extern int tbl_val;                    /* index of table element value */
extern int tbl_dflt;                   /* index of table default */

#include "rttproto.h"
