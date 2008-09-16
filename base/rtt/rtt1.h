#include "preproc.h"
#include "pproto.h"

#define IndentInc 3
#define MaxCol 80

#define Max(x,y)        ((x)>(y)?(x):(y))


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

#define ForceNl() nl = 1;
extern int nl;  /* flag: a new-line is needed in the output */

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
extern int enable_out;     /* enable output of C code */


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
                           DrfPrm, RsltLoc */
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
      struct {			/* OtherDcl from "declare {...}": */
         struct node *tqual;	/*   storage class, type qualifier list */
         struct node *dcltor;	/*   declarator */
         struct node *init;     /*   initial value from declaration */
         struct sym_entry *next;
         } declare_var;
      int typ_indx;             /* index into arrays of type information */
      word lbl_num;             /* label number used in in-line code */
      int referenced;		/* RsltLoc: is referenced */
      } u;
   int t_indx;		/* index into tended array */
   int il_indx;		/* index used in in-line code */
   int nest_lvl;	/* 0 - reserved word, 1 - global, >= 2 - local */
   int may_mod;         /* may be modified in particular piece of code */
   int ref_cnt;
   struct sym_entry *next;
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
extern char lc_letter;             /* f = function, o = operator, k = keyword */
extern char uc_letter;             /* F = function, O = operator, K = keyword */
extern char prfx1;                 /* 1st char of unique prefix for operation */
extern char prfx2;                 /* 2nd char of unique prefix for operation */
extern char *fname;                /* current source file name */
extern int line;                   /* current source line number */
extern struct implement *cur_impl; /* data base entry for current operator */
extern struct token *comment;      /* descriptive comment for current oper */
extern int n_tmp_str;              /* total number of string buffers needed */
extern int n_tmp_cset;             /* total number of cset buffers needed */
extern int nxt_sbuf;               /* index of next string buffer */
extern int nxt_cbuf;               /* index of next cset buffer */
extern struct sym_entry *params;   /* current list of parameters */
extern struct sym_entry *decl_lst; /* declarations from "declare {...}" */
extern struct init_tend *tend_lst; /* list of allocated tended slots */
extern char *str_rslt;             /* string "result" in string table */
extern word lbl_num;               /* next unused label number */
extern struct sym_entry *v_len;    /* symbol entry for size of varargs */
extern int il_indx;                /* next index into data base symbol table */

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

extern int fnc_ret;  /* RetInt, RetDbl, RetNoVal, or RetSig for current func */

#define NoAbstr  -1001 /* no abstract return statement has been encountered */
#define SomeType -1002 /* assume returned value is consistent with abstr ret */
extern int abs_ret; /* type from abstract return statement */

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

#define NewNode(size) (struct node *)alloc((unsigned int)\
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

#define DoesRet    01	     /* operation (or "body" function) returns */
#define DoesFail   02	     /* operation (or "body" function) fails */
#define DoesSusp   04	     /* operation (or "body" function) suspends */
#define DoesEFail 010        /* fails through error conversion */
#define DoesFThru 020	     /* only "body" functions can "fall through" */

struct implement {
   struct implement *blink;   /* link for bucket chain in hash tables */
   char oper_typ;             /* 'K'=keyword, 'F'=function, 'O'=operator */
   char prefix[2];	      /* prefix to make start of name unique */
   char *name;		      /* function/operator/keyword name */
   char *op;		      /* operator symbol (operators only) */
   int nargs;		      /* number of arguments operation requires */
   int *arg_flgs;             /* array of arg flags: deref/underef, var len*/
   long min_result;	      /* minimum result sequence length */
   long max_result;	      /* maiximum result sequence length */
   int resume;		      /* flag - resumption after last result */
   int ret_flag;	      /* DoesRet, DoesFail, DoesSusp */
   int use_rslt;              /* flag - explicitly uses result location */
   char *comment;	      /* description of operation */
   int ntnds;		      /* size of tnds array */
   struct tend_var *tnds;     /* pointer to array of info about tended vars */
   int nvars;                 /* size of vars array */
   struct ord_var  *vars;     /* pointer to array of info about ordinary vars */
   struct il_code *in_line;    /* inline version of the operation */
   int iconc_flgs;	      /* flags for internal use by the compiler */
   };

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
#define RsltLoc   7  /* the special result location of an operation */
#define Label     8  /* label */
#define RtParm   16  /* undereferenced parameter of run-time routine */
#define DrfPrm   32  /* dereferenced parameter of run-time routine */
#define VarPrm   64  /* variable part of parm list (with RtParm or DrfPrm) */
#define PrmMark 128  /* flag - used while recognizing params of body fnc */
#define ByRef   256  /* flag - parameter to body function passed by reference */

/*
 * Flags to indicate what types are returned from the function implementing
 *  a body. These are unsed in determining the calling conventions 
 *  of the function.
 */
#define RetInt   1  /* body/function returns a C_integer */
#define RetDbl   2  /* body/function returns a C_double */
#define RetOther 4  /* body (not function itself) returns something else */
#define RetNoVal 8  /* function returns no value */
#define RetSig  16  /* function returns a signal */

/*
 * tend_var contains information about a tended variable in the "declare {...}"
 *  action of an operation.
 */
struct tend_var {
   int var_type;           /* TndDesc, TndStr, or TndBlk */
   struct il_c *init;      /* initial value from declaration */
   char *blk_name;         /* TndBlk: struct name of block */
   };

/*
 * ord_var contains information about an ordinary variable in the
 *  "declare {...}" action of an operation.
 */
struct ord_var {
   char *name;        /* name of variable */
   struct il_c *dcl;  /* declaration of variable (includes name) */
   };

/*
 * il_code has information about an action in an operation.
 */
#define IL_If1     1
#define IL_If2     2
#define IL_Tcase1  3
#define IL_Tcase2  4
#define IL_Lcase   5
#define IL_Err1    6
#define IL_Err2    7
#define IL_Lst     8
#define IL_Const   9
#define IL_Bang   10
#define IL_And    11
#define IL_Cnv1   12
#define IL_Cnv2   13
#define IL_Def1   14
#define IL_Def2   15
#define IL_Is     16
#define IL_Var    17
#define IL_Subscr 18
#define IL_Block  19
#define IL_Call   20
#define IL_Abstr  21
#define IL_VarTyp 22
#define IL_Store  23
#define IL_Compnt 24
#define IL_TpAsgn 25
#define IL_Union  26
#define IL_Inter  27
#define IL_New    28
#define IL_IcnTyp 29
#define IL_Acase  30

#define CM_Fields -1

union il_fld {
   struct il_code *fld;
   struct il_c *c_cd;
   int *vect;
   char *s;
   word n;
   };

struct il_code {
   int il_type;
   union il_fld u[1];   /* actual number of fields varies with type */
   };

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
#define TypTStr   -9
#define TypTCset -10
#define RetDesc  -11
#define RetNVar  -12
#define RetSVar  -13
#define RetNone  -14

/*
 * il_c describes a piece of C code.
 */
#define ILC_Ref    1   /* nonmodifying reference to var. in sym. tab. */
#define ILC_Mod    2   /* modifying reference to var. in sym. tab */
#define ILC_Tend   3   /* tended var. local to inline block */
#define ILC_SBuf   4   /* string buffer */
#define ILC_CBuf   5   /* cset buffer */
#define ILC_Ret    6   /* return statement */
#define ILC_Susp   7   /* suspend statement */
#define ILC_Fail   8   /* fail statement */
#define ILC_Goto   9   /* goto */
#define ILC_CGto  10   /* conditional goto */
#define ILC_Lbl   11   /* label */
#define ILC_LBrc  12   /* '{' */
#define ILC_RBrc  13   /* '}' */
#define ILC_Str   14   /* arbitrary string of code */
#define ILC_EFail 15   /* errorfail statement */

#define RsltIndx -1   /* symbol table index for "result" */

struct il_c {
   int il_c_type;
   struct il_c *code[3];
   word n;
   char *s;
   struct il_c *next;
   };
   
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
