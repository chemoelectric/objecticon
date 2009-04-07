#ifndef _TREE_H
#define _TREE_H 1

/*
 * Structure of a tree node.
 */

typedef	struct node	*nodeptr;
#define YYSTYPE nodeptr

union field {
   long n_val;		/* integer-valued fields */
   char *n_str;		/* string-valued fields */
   nodeptr n_ptr;	/* subtree pointers */
   };

struct node {
   int n_type;			/* node type */
   char *n_file;		/* name of file containing source program */
   int n_line;			/* line number in source program */
   int n_col;			/* column number in source program */
   union field n_field[1];      /* variable-content fields */
   };

#define NewNode(size) safe_alloc(sizeof(struct node) + (size-1) * sizeof(union field))

/*
 * Macros to access fields of parse tree nodes.
 */

#define TType(t)	(t)->n_type
#define File(t)		(t)->n_file
#define Line(t)		(t)->n_line
#define Col(t)		(t)->n_col
#define Tree0(t)	(t)->n_field[0].n_ptr
#define Tree1(t)	(t)->n_field[1].n_ptr
#define Tree2(t)	(t)->n_field[2].n_ptr
#define Tree3(t)	(t)->n_field[3].n_ptr
#define Val0(t)		(t)->n_field[0].n_val
#define Val1(t)		(t)->n_field[1].n_val
#define Val2(t)		(t)->n_field[2].n_val
#define Val3(t)		(t)->n_field[3].n_val
#define Val4(t)		(t)->n_field[4].n_val
#define Str0(t)		(t)->n_field[0].n_str
#define Str1(t)		(t)->n_field[1].n_str
#define Str2(t)		(t)->n_field[2].n_str
#define Str3(t)		(t)->n_field[3].n_str

/*
 * External declarations.
 */

extern nodeptr yylval;		/* parser's current token value */
extern struct node tok_loc;     /* "model" token holding current location */

/*
 * Node types.
 */

#define N_Activat	 1		/* activation control structure */
#define N_Alt		 2		/* alternation operator */
#define N_Augop		 3		/* augmented operator */
#define N_Bar		 4		/* generator control structure */
#define N_Binop		 5		/* other binary operator */
#define N_Break		 6		/* break statement */
#define N_Case		 7		/* case statement */
#define N_Ccls		 8		/* case clause */
#define N_Clist		 9		/* list of case clauses */
#define N_Conj		10		/* conjunction operator */
#define N_Create	11		/* create control structure */
#define N_Cset		12		/* cset literal */
#define N_Ucs 		13		/* ucs literal */
#define N_Elist		14		/* list of expressions */
#define N_Empty		15		/* empty expression or statement */
#define N_Field		16		/* record field reference */
#define N_Id		17		/* identifier token */
#define N_If		18		/* if-then-else statement */
#define N_Int		19		/* integer literal */
#define N_Invok		20		/* invocation */
#define N_Key		21		/* keyword */
#define N_Limit		22		/* LIMIT control structure */
#define N_List		23		/* [ ... ] style list */
#define N_Loop		24		/* while, until, every, or repeat */
#define N_Not		25		/* not prefix control structure */
#define N_Next		26		/* next statement */
#define N_Op		27		/* operator token */
#define N_Proc		28		/* procedure */
#define N_Real		29		/* real literal */
#define N_Res		30		/* reserved word token */
#define N_Ret		31		/* fail, return, or succeed */
#define N_Scan		32		/* scan-using statement */
#define N_Sect		33		/* s[i:j] (section) */
#define N_Slist		34		/* list of statements */
#define N_Str		35		/* string literal */
#define N_Susp		36		/* suspend statement */
#define N_To		37		/* TO operator */
#define N_ToBy		38		/* TO-BY operator */
#define N_Unop		39		/* unary operator */
#define N_Apply		40		/* procedure application */
#define N_Dottedid      41              /* dotted identifier structure */
#define N_Lrgint	42		/* large integer literal */

/*
 * Macros for constructing basic nodes.
 */

#define CsetNode(a,b)		i_str_leaf(N_Cset,&tok_loc,a,b) 
#define UcsNode(a,b)		i_str_leaf(N_Ucs,&tok_loc,a,b) 
#define IdNode(a)		c_str_leaf(N_Id,&tok_loc,a) 
#define IntNode(a)		i_str_leaf(N_Int,&tok_loc,a,sizeof(word)) 
#define OpNode(a)		int_leaf(N_Op,&tok_loc,optab[a].tok.t_type) 
#define RealNode(a)		i_str_leaf(N_Real,&tok_loc,a,sizeof(double)) 
#define ResNode(a)		int_leaf(N_Res,&tok_loc,a) 
#define StrNode(a,b)		i_str_leaf(N_Str,&tok_loc,a,b) 
#define LrgintNode(a,b)		i_str_leaf(N_Lrgint,&tok_loc,a,b) 

struct  node *tree1             (int type);
struct  node *tree2             (int type,struct node *loc_model);
struct  node *tree3             (int type,struct node *loc_model,struct node *c);
struct  node *tree4             (int type,struct node *loc_model,struct node *c,struct node *d);
struct  node *tree5             (int type,struct node *loc_model,
                                   struct node *c,struct node *d,
                                   struct node *e);
struct  node *tree6             (int type,struct node *loc_model,
                                   struct node *c, struct node *d,
                                   struct node *e,struct node *f);
struct node *buildarray         (struct node *a,struct node *lb,
                                        struct node *e, struct node *rb);
struct  node *int_leaf          (int type,struct node *loc_model,int c);
struct  node *c_str_leaf        (int type,struct node *loc_model, char *c);
struct  node *i_str_leaf        (int type,struct node *loc_model,char *c,int d);

#endif
