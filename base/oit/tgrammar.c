/*
 * tgrammar.c - includes and macros for building the parse tree
 */

#include "../h/define.h"
#include "yacctok.h"

%{
/*
 * These commented directives are passed through the first application
 * of cpp, then turned into real includes in tgram.g by fixgram.icn.
 */
/*#include "icont.h"*/
/*#include "lexdef.h"*/
/*#include "tsym.h"*/
/*#include "tmem.h"*/
/*#include "tree.h"*/
/*#include "tlex.h"*/
/*#include "trans.h"*/
/*#include "keyword.h"*/
/*#undef YYSTYPE*/
/*#define YYSTYPE nodeptr*/
/*#define YYMAXDEPTH 5000*/

/* Avoids some spurious compiler warnings */
/*#define lint 1*/

extern int fncargs[];
int idflag;
int modflag;

#define EmptyNode tree1(N_Empty) 

#define Alt(x1,x2,x3)		$$ = tree4(N_Alt,x2,x1,x3) 
#define Apply(x1,x2,x3)		$$ = tree4(N_Apply,x2,x1,x3) 
#define Arglist1()		/* empty */
#define Arglist2(x)		/* empty */
#define Arglist3(x,y,z)		curr_func->nargs = -curr_func->nargs
#define Bact(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Bamper(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Bassgn(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Baugact(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3) 
#define Baugamper(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3) 
#define Baugcat(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugeq(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugeqv(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugge(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bauggt(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bauglcat(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugle(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bauglt(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugne(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugneqv(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugques(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3) 
#define Baugseq(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugsge(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugsgt(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugsle(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugslt(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Baugsne(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bcaret(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Bcareta(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bcat(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Bdiff(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Bdiffa(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Beq(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Beqv(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bge(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bgt(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Binter(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bintera(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Blcat(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Ble(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Blim(x1,x2,x3)		$$ = tree4(N_Limit,x1,x1,x3) 
#define Blt(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bminus(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bminusa(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bmod(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bmoda(x1,x2,x3)		$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bne(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bneqv(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bplus(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bplusa(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bques(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3) 
#define Brace(x1,x2,x3)		$$ = x2
#define Brack(x1,x2,x3)		$$ = tree3(N_List,x1,x2) 
#define Brassgn(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Break(x1,x2)		$$ = tree3(N_Break,x1,x2) 
#define Brswap(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bseq(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bsge(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bsgt(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bslash(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bslasha(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bsle(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bslt(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bsne(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bstar(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bstara(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Bswap(x1,x2,x3)		$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Bunion(x1,x2,x3)	$$ = tree5(N_Binop,x2,x2,x1,x3)
#define Buniona(x1,x2,x3)	$$ = tree5(N_Augop,x2,x2,x1,x3)
#define Case(x1,x2,x3,x4,x5,x6) $$ = tree4(N_Case,x1,x2,x5) 
#define Caselist(x1,x2,x3)	$$ = tree4(N_Clist,x2,x1,x3) 
#define Cclause0(x1,x2,x3)	$$ = tree4(N_Cdef,x2,x1,x3) 
#define Cclause1(x1,x2,x3)	$$ = tree4(N_Ccls,x2,x1,x3) 

#define Package(x1,x2)          set_package(dottedid2string(x2), x2);
#define Classdcl(x)		
#define Class1(x1,x2)           next_class(Str0(x2),modflag, x2);
#define Super(x)                next_super(dottedid2string(x),x);
#define Importspec1(x)          next_import(dottedid2string(x),0,x);
#define Importspec2(x)          next_import(dottedid2string(x),1,x);idflag = F_Importsym
#define Packagedcl(x)		
#define Importdcl(x)		
#define Dottedident(x1,x2,x3)   $$ = tree4(N_Dottedid,x2,x1,x3)
#define Toplevelident(x1,x2,x3) $$ = tree4(N_Dottedid,x2,IdNode(default_string),x3)
#define Dottedidentexpr(x)      $$ = convert_dottedidentexpr(x)

#define Modifier0()             modflag = 0
#define Modifier1()             modflag |= M_Private
#define Modifier2()             modflag |= M_Public
#define Modifier3()             modflag |= M_Protected
#define Modifier4()             modflag |= M_Package
#define Modifier5()             modflag |= M_Static
#define Modifier6()             modflag |= M_Const
#define Modifier7()             modflag |= M_Readable
#define Modifier8()             modflag |= M_Final
#define Modifier9()             modflag |= M_Defer

#define Classbody0()            modflag = 0; idflag = F_Class
#define Fielddecl1(x)           check_flags(modflag, x)

#define Method1(x)              next_method(Str0(x), modflag, x); \
                                idflag = F_Argument
#define Method2(x1,x2,x3,x4)    curr_func->code = tree6(N_Proc,x1,x1,x2,x3,x4)

#define Cliter(x)		Val0(x) = putlit(Str0(x),F_CsetLit,(int)Val1(x))
#define Uliter(x)		Val0(x) = putlit(Str0(x),F_UcsLit,(int)Val1(x))
#define Colon(x)		$$ = x
#define Compound(x1,x2,x3)	$$ = tree4(N_Slist,x2,x1,x3) 
#define Create(x1,x2)		$$ = tree3(N_Create,x1,x2) 
#define Elst0(x1)		/* empty */
#define Elst1(x1,x2,x3)		$$ = tree4(N_Elist,x2,x1,x3)
#define Every0(x1,x2)		$$ = tree4(N_Every,x1,x1,x2) 
#define Every1(x1,x2,x3,x4)	$$ = tree5(N_Everydo,x1,x1,x2,x4) 
#define Fail(x)			$$ = tree2(N_Fail,x)
#define Field(x1,x2,x3)		$$ = tree4(N_Field,x2,x1,x3)
#define Global0(x)		idflag = F_Global
#define Global1(x1,x2,x3)	/* empty */
#define Globdcl(x)		/* empty */
#define Ident(x)		install(Str0(x),idflag,x)
#define Idlist(x1,x2,x3)	install(Str0(x3),idflag,x3)
#define If0(x1,x2,x3,x4)	$$ = tree4(N_If,x1,x2,x4) 
#define If1(x1,x2,x3,x4,x5,x6)	$$ = tree5(N_Ifelse,x1,x2,x4,x6) 
#define Iliter(x)		if (x->n_type == N_Int)\
                                   Val0(x) = putlit(Str0(x),F_IntLit,(int)Val1(x));\
                                else \
                                   Val0(x) = putlit(Str0(x),F_LrgintLit,(int)Val1(x))
#define Initial1()		$$ = EmptyNode
#define Initial2(x1,x2)    	$$ = x2
#define Invocable(x1,x2)	/* empty */
#define Invocdcl(x1)		/* empty */
#define Invoclist(x1,x2,x3)	/* empty */
#define Invocop1(x1)		add_invocable(dottedid2string(x1),1,x1)
#define Invocop2(x1)		add_invocable(Str0(x1),2,x1)
#define Invocop3(x1,x2,x3)	add_invocable(Str0(x1),3,x1)
#define Invoke(x1,x2,x3,x4)	$$ = tree4(N_Invoke,x2,x1,x3) 
#define Keyword(x1,x2)		if (klookup(Str0(x2)) == 0)\
				   tfatal("invalid keyword: %s",Str0(x2));\
				$$ = c_str_leaf(N_Key,x1,Str0(x2))
#define Kfail(x1,x2)		$$ = c_str_leaf(N_Key,x1,"fail") 
#define Link(x1,x2)		/* empty */
#define Linkdcl(x)		/* empty */
#define Lnkfile1(x)		add_link(Str0(x), x)
#define Lnkfile2(x)		add_link(Str0(x), x)
#define Lnklist(x1,x2,x3)	/* empty */
#define Local(x)		idflag = F_Dynamic
#define Locals1()		/* empty */
#define Locals2(x1,x2,x3)	/* empty */
#define Mcolon(x)		$$ = x
#define Nexpr()			$$ = EmptyNode
#define Next(x)			$$ = tree2(N_Next,x) 
#define Paren(x1,x2,x3)		if ((x2)->n_type == N_Elist)\
 				   $$ = tree3(N_Mutual,x1,x2);\
 				else\
 				   $$ = x2
#define Pcolon(x)		$$ = x
#define Pdco0(x1,x2,x3)		$$ = tree4(N_Invoke,x2,x1,EmptyNode)
#define Pdco1(x1,x2,x3,x4)	$$ = tree4(N_Invoke,x2,x1,x3)
#define Pdcolist0(x)		$$ = tree3(N_Create,x,x) 
#define Pdcolist1(x1,x2,x3)	$$ = tree4(N_Elist,x2,x1,tree3(N_Create,x2,x3))

#define Proc1(x1,x2)            next_procedure(Str0(x2), x2); \
                                idflag = F_Argument
#define Proc2(x1,x2,x3,x4)      curr_func->code = tree6(N_Proc,x1,x1,x2,x3,x4)

#define Procdcl(x)		/* Empty */
#define Progend(x1,x2)		/* Empty */
#define Recdcl(x)		/* Empty */
#define Record1(x1,x2)		next_function(F_Record); idflag = F_Argument
#define Record2(x1,x2,x3,x4,x5,x6) curr_func->global = next_global(Str0(x2),F_Record|F_Global,x2); \
                                curr_func->global->func = curr_func; \
                                $$ = x2
#define Repeat(x1,x2)		$$ = tree4(N_Repeat,x1,x1,x2) 
#define Return(x1,x2)		$$ = tree4(N_Ret,x1,x1,x2) 
#define Rliter(x)		Val0(x) = putlit(Str0(x),F_RealLit,(int)Val1(x))
#define Section(x1,x2,x3,x4,x5,x6) $$ = tree6(N_Sect,x4,x4,x1,x3,x5) 
#define Sliter(x)		Val0(x) = putlit(Str0(x),F_StrLit,(int)Val1(x))
#define Static(x)		idflag = F_Static
#define Subscript(x1,x2,x3,x4)	$$ = buildarray(x1,x2,x3,x4)
#define Suspend0(x1,x2)		$$ = tree4(N_Suspend,x1,x1,x2) 
#define Suspend1(x1,x2,x3,x4)	$$ = tree5(N_Suspenddo,x1,x1,x2,x4) 
#define To0(x1,x2,x3)		$$ = tree4(N_To,x2,x1,x3) 
#define To1(x1,x2,x3,x4,x5)	$$ = tree5(N_ToBy,x2,x1,x3,x5) 
#define Uat(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2) 
#define Ubackslash(x1,x2)	$$ = tree4(N_Unop,x1,x1,x2)
#define Ubang(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Ubar(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2) 
#define Ucaret(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uconcat(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2) 
#define Udiff(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Udot(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uequiv(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uinter(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Ulconcat(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Ulexeq(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Ulexne(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uminus(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Unot(x1,x2)		$$ = tree3(N_Not,x2,x2) 
#define Unotequiv(x1,x2)	$$ = tree4(N_Unop,x1,x1,x2)
#define Until0(x1,x2)		$$ = tree4(N_Until,x1,x1,x2) 
#define Until1(x1,x2,x3,x4)	$$ = tree5(N_Untildo,x1,x1,x2,x4) 
#define Unumeq(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Unumne(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uplus(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uqmark(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uslash(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Ustar(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Utilde(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define Uunion(x1,x2)		$$ = tree4(N_Unop,x1,x1,x2)
#define While0(x1,x2)		$$ = tree4(N_While,x1,x1,x2)
#define While1(x1,x2,x3,x4)	$$ = tree5(N_Whiledo,x1,x1,x2,x4) 
%}

%%
#include "grammar.h"
%%
