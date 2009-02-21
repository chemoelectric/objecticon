/*
 * tcode.c -- translator functions for traversing parse trees and generating
 *  code.
 */

#include "tsym.h"
#include "../h/opdefs.h"
#include "ucode.h"
#include "tmain.h"
#include "trans.h"
#include "ttoken.h"

/*
 * Prototypes.
 */

static int	alclab		(int n);
static void	binop		(int op);
static void	uout_lab		(int l);
static int	traverse	(nodeptr t);
static void	unopa		(int op, nodeptr t);
static void	unopb		(int op);

extern int tfatals;
extern int nocode;

/*
 * Code generator parameters.
 */

#define LoopDepth   20		/* max. depth of nested loops */
#define CaseDepth   10		/* max. depth of nested case statements */
#define CreatDepth  10		/* max. depth of nested create statements */

/*
 * loopstk structures hold information about nested loops.
 */
struct loopstk {
    int nextlab;			/* label for next exit */
    int breaklab;		/* label for break exit */
    int markcount;		/* number of marks */
    int ltype;			/* loop type */
};

/*
 * casestk structure hold information about case statements.
 */
struct casestk {
    int endlab;			/* label for exit from case statement */
    nodeptr deftree;		/* pointer to tree for default clause */
};

/*
 * creatstk structures hold information about create statements.
 */
struct creatstk {
    int nextlab;			/* previous value of nextlab */
    int breaklab;		/* previous value of breaklab */
};
static int nextlab;		/* next label allocated by alclab() */

/*
 * codegen - traverse tree t, generating code.
 */

void codegen(nodeptr t)
{
    nextlab = 1;
    traverse(t);
}

/*
 * traverse - traverse tree rooted at t and generate code.  This is just
 *  plug and chug code for each of the node types.
 */

static int traverse(t)
    register nodeptr t;
{
    register int lab, n, i;
    struct loopstk loopsave;
    static struct loopstk loopstk[LoopDepth];	/* loop stack */
    static struct loopstk *loopsp;
    static struct casestk casestk[CaseDepth];	/* case stack */
    static struct casestk *casesp;
    static struct creatstk creatstk[CreatDepth]; /* create stack */
    static struct creatstk *creatsp;

    n = 1;
    switch (TType(t)) {

        case N_Activat:			/* co-expression activation */
            if (Val0(Tree0(t)) == AUGAT) {
                uout_op(Op_Pnull);
	    }
            traverse(Tree2(t));		/* evaluate result expression */
            if (Val0(Tree0(t)) == AUGAT)
                uout_op(Op_Sdup);
            traverse(Tree1(t));		/* evaluate activate expression */
            ensure_pos(t);
            uout_op(Op_Coact);
            if (Val0(Tree0(t)) == AUGAT)
                uout_op(Op_Asgn);
            free(Tree0(t));
            break;

        case N_Alt:			/* alternation */
            lab = alclab(2);
            uout_op(Op_Mark);
            uout_short(lab);
            loopsp->markcount++;
            traverse(Tree0(t));		/* evaluate first alternative */
            loopsp->markcount--;

#ifdef EventMon
            ensure_pos(t);
#endif					/* EventMon */

            uout_op(Op_Esusp);                 /*  and suspend with its result */
            uout_op(Op_Goto);
            uout_short(lab+1);
            uout_lab(lab);
            traverse(Tree1(t));		/* evaluate second alternative */
            uout_lab(lab+1);
            break;

        case N_Augop:			/* augmented assignment */
        case N_Binop:			/*  or a binary operator */
            uout_op(Op_Pnull);
            traverse(Tree1(t));
            if (TType(t) == N_Augop)
                uout_op(Op_Dup);
            traverse(Tree2(t));
            ensure_pos(t);
            binop((int)Val0(Tree0(t)));
            free(Tree0(t));
            break;

        case N_Bar:			/* repeated alternation */
            lab = alclab(1);
            uout_lab(lab);
            uout_op(Op_Mark0);         /* fail if expr fails first time */
            loopsp->markcount++;
            traverse(Tree0(t));		/* evaluate first alternative */
            loopsp->markcount--;
            uout_op(Op_Chfail);
            uout_short(lab);          /* change to loop on failure */
            uout_op(Op_Esusp);                 /* suspend result */
            break;

        case N_Break:			/* break expression */
            if (loopsp->breaklab <= 0)
                tfatal_at(t, "invalid context for break");
            else {
                for (i = 0; i < loopsp->markcount; i++)
                    uout_op(Op_Unmark);
                loopsave = *loopsp--;
                traverse(Tree0(t));
                *++loopsp = loopsave;
                uout_op(Op_Goto);
                uout_short(loopsp->breaklab);
	    }
            break;

        case N_Case:			/* case expression */
            lab = alclab(1);
            casesp++;
            casesp->endlab = lab;
            casesp->deftree = NULL;
            uout_op(Op_Mark0);
            loopsp->markcount++;
            traverse(Tree0(t));		/* evaluate control expression */
            loopsp->markcount--;
            uout_op(Op_Eret);
            traverse(Tree1(t));		/* do rest of case (CLIST) */
            if (casesp->deftree != NULL) { /* evaluate default clause */
                uout_op(Op_Pop);
                traverse(casesp->deftree);
	    }
            else
                uout_op(Op_Efail);
            uout_lab(lab);			/* end label */
            casesp--;
            break;

        case N_Ccls:			/* case expression clause */
            if (TType(Tree0(t)) == N_Res && /* default clause */
                Val0(Tree0(t)) == DEFAULT) {
                if (casesp->deftree != NULL)
                    tfatal_at(t, "more than one default clause");
                else
                    casesp->deftree = Tree1(t);
                free(Tree0(t));
	    }
            else {				/* case clause */
                lab = alclab(1);
                uout_op(Op_Mark);
                uout_short(lab);
                loopsp->markcount++;
                uout_op(Op_Ccase);
                traverse(Tree0(t));		/* evaluate selector */
                ensure_pos(t);
                uout_op(Op_Eqv);
                loopsp->markcount--;
                uout_op(Op_Unmark);
                uout_op(Op_Pop);
                traverse(Tree1(t));		/* evaluate expression */
                uout_op(Op_Goto);
                uout_short(casesp->endlab); /* goto end label */
                uout_lab(lab);		/* label for next clause */
	    }
            break;

        case N_Clist:			/* list of case clauses */
            traverse(Tree0(t));
            traverse(Tree1(t));
            break;

        case N_Conj:			/* conjunction */
            if (Val0(Tree0(t)) == AUGAND) {
                uout_op(Op_Pnull);
	    }
            traverse(Tree1(t));
            if (Val0(Tree0(t)) != AUGAND)
                uout_op(Op_Pop);
            traverse(Tree2(t));
            if (Val0(Tree0(t)) == AUGAND) {
                ensure_pos(t);
                uout_op(Op_Asgn);
	    }
            free(Tree0(t));
            break;

        case N_Create:			/* create expression */
            creatsp++;
            creatsp->nextlab = loopsp->nextlab;
            creatsp->breaklab = loopsp->breaklab;
            loopsp->nextlab = 0;		/* make break and next illegal */
            loopsp->breaklab = 0;
            lab = alclab(3);
            uout_op(Op_Goto);
            uout_short(lab+2);          /* skip over code for co-expression */
            uout_lab(lab);			/* entry point */
            uout_op(Op_Pop);                   /* pop the result from activation */
            uout_op(Op_Mark);
            uout_short(lab+1);
            loopsp->markcount++;
            traverse(Tree0(t));		/* traverse code for co-expression */
            loopsp->markcount--;
            ensure_pos(t);
            uout_op(Op_Coret);                 /* return to activator */
            uout_op(Op_Efail);                 /* drive co-expression */
            uout_lab(lab+1);		/* loop on exhaustion */
            uout_op(Op_Cofail);                /* and fail each time */
            uout_op(Op_Goto);
            uout_short(lab+1);
            uout_lab(lab+2);
            uout_op(Op_Create);
            uout_short(lab);          /* create entry block */
            loopsp->nextlab = creatsp->nextlab;   /* legalize break and next */
            loopsp->breaklab = creatsp->breaklab;
            creatsp--;
            break;

        case N_Cset:			/* cset literal */
            uout_op(Op_Cset);
            uout_short((int)Val0(t));
            break;

        case N_Ucs:			/* ucs literal */
            uout_op(Op_Ucs);
            uout_short((int)Val0(t));
            break;

        case N_Elist:			/* expression list */
            n = traverse(Tree0(t));
            n += traverse(Tree1(t));
            break;

        case N_Empty:			/* a missing expression */
            uout_op(Op_Pnull);
            break;

        case N_Field:			/* field reference */
            uout_op(Op_Pnull);
            traverse(Tree0(t));
            ensure_pos(t);
            uout_op(Op_Field);
            uout_str(Str0(Tree1(t)));
            free(Tree1(t));
            break;

        case N_Id:			/* identifier */
            ensure_pos(t);
            uout_op(Op_Var);
            uout_short(Val0(t));
            break;

        case N_If:			/* if expression */
            if (TType(Tree2(t)) == N_Empty) {
                lab = 0;
                uout_op(Op_Mark0);
	    }
            else {
                lab = alclab(2);
                uout_op(Op_Mark);
                uout_short(lab);
	    }
            loopsp->markcount++;
            traverse(Tree0(t));
            loopsp->markcount--;
            uout_op(Op_Unmark);
            traverse(Tree1(t));
            if (lab > 0) {
                uout_op(Op_Goto);
                uout_short(lab+1);
                uout_lab(lab);
                traverse(Tree2(t));
                uout_lab(lab+1);
	    }
            else
                free(Tree2(t));
            break;

        case N_Int:			/* integer literal */
            uout_op(Op_Int);
            uout_short((int)Val0(t));
            break;


        case N_Apply:			/* application */
            traverse(Tree0(t));
            traverse(Tree1(t));
            uout_op(Op_Apply);
            break;

        case N_Invok:			/* invocation */
            if (TType(Tree0(t)) != N_Empty) {
                traverse(Tree0(t));
            }
            else {
                uout_op(Op_Pushn1);             /* default to -1(e1,...,en) */
                free(Tree0(t));
	    }
            if (TType(Tree1(t)) == N_Empty) {
                n = 0;
                free(Tree1(t));
            }
            else
                n = traverse(Tree1(t));
            ensure_pos(t);
            uout_op(Op_Invoke);
            uout_short(n);
            n = 1;
            break;

        case N_Key:			/* keyword reference */
            ensure_pos(t);
            uout_op(Op_Keywd);
            uout_str(Str0(t));
            break;

        case N_Limit:			/* limitation */
            traverse(Tree1(t));
            ensure_pos(t);
            uout_op(Op_Limit);
            loopsp->markcount++;
            traverse(Tree0(t));
            loopsp->markcount--;
            uout_op(Op_Lsusp);
            break;

        case N_List:			/* list construction */
            uout_op(Op_Pnull);
            if (TType(Tree0(t)) == N_Empty) {
                n = 0;
                free(Tree0(t));
            }
            else
                n = traverse(Tree0(t));
            ensure_pos(t);
            uout_op(Op_Llist);
            uout_word(n);
            n = 1;
            break;

        case N_Loop:			/* loop */
            switch ((int)Val0(Tree0(t))) {
                case EVERY:
                    lab = alclab(2);
                    loopsp++;
                    loopsp->ltype = EVERY;
                    loopsp->nextlab = lab;
                    loopsp->breaklab = lab + 1;
                    loopsp->markcount = 1;
                    uout_op(Op_Mark0);
                    traverse(Tree1(t));
                    uout_op(Op_Pop);
                    if (TType(Tree2(t)) != N_Empty) {   /* every e1 do e2 */
                        uout_op(Op_Mark0);
                        loopsp->ltype = N_Loop;
                        loopsp->markcount++;
                        traverse(Tree2(t));
                        loopsp->markcount--;
                        uout_op(Op_Unmark);
                    }
                    else
                        free(Tree2(t));
                    uout_lab(loopsp->nextlab);
                    uout_op(Op_Efail);
                    uout_lab(loopsp->breaklab);
                    loopsp--;
                    break;

                case REPEAT:
                    lab = alclab(3);
                    loopsp++;
                    loopsp->ltype = N_Loop;
                    loopsp->nextlab = lab + 1;
                    loopsp->breaklab = lab + 2;
                    loopsp->markcount = 1;
                    uout_lab(lab);
                    uout_op(Op_Mark);
                    uout_short(lab);
                    traverse(Tree1(t));
                    uout_lab(loopsp->nextlab);
                    uout_op(Op_Unmark);
                    uout_op(Op_Goto);
                    uout_short(lab);
                    uout_lab(loopsp->breaklab);
                    loopsp--;
                    free(Tree2(t));
                    break;

                case SUSPEND:			/* suspension expression */
                    if (creatsp > creatstk)
                        tfatal_at(t, "invalid context for suspend");
                    lab = alclab(2);
                    loopsp++;
                    loopsp->ltype = EVERY;		/* like every ... do for next */
                    loopsp->nextlab = lab;
                    loopsp->breaklab = lab + 1;
                    loopsp->markcount = 1;
                    uout_op(Op_Mark0);
                    traverse(Tree1(t));
                    ensure_pos(t);
                    uout_op(Op_Psusp);
                    uout_op(Op_Pop);
                    if (TType(Tree2(t)) != N_Empty) { /* suspend e1 do e2 */
                        uout_op(Op_Mark0);
                        loopsp->ltype = N_Loop;
                        loopsp->markcount++;
                        traverse(Tree2(t));
                        loopsp->markcount--;
                        uout_op(Op_Unmark);
                    }
                    else
                        free(Tree2(t));
                    uout_lab(loopsp->nextlab);
                    uout_op(Op_Efail);
                    uout_lab(loopsp->breaklab);
                    loopsp--;
                    break;

                case WHILE:
                    lab = alclab(3);
                    loopsp++;
                    loopsp->ltype = N_Loop;
                    loopsp->nextlab = lab + 1;
                    loopsp->breaklab = lab + 2;
                    loopsp->markcount = 1;
                    uout_lab(lab);
                    uout_op(Op_Mark0);
                    traverse(Tree1(t));
                    if (TType(Tree2(t)) != N_Empty) {
                        uout_op(Op_Unmark);
                        uout_op(Op_Mark);
                        uout_short(lab);
                        traverse(Tree2(t));
                    }
                    else
                        free(Tree2(t));
                    uout_lab(loopsp->nextlab);
                    uout_op(Op_Unmark);
                    uout_op(Op_Goto);
                    uout_short(lab);
                    uout_lab(loopsp->breaklab);
                    loopsp--;
                    break;

                case UNTIL:
                    lab = alclab(4);
                    loopsp++;
                    loopsp->ltype = N_Loop;
                    loopsp->nextlab = lab + 2;
                    loopsp->breaklab = lab + 3;
                    loopsp->markcount = 1;
                    uout_lab(lab);
                    uout_op(Op_Mark);
                    uout_short(lab+1);
                    traverse(Tree1(t));
                    uout_op(Op_Unmark);
                    uout_op(Op_Efail);
                    uout_lab(lab+1);
                    uout_op(Op_Mark);
                    uout_short(lab);
                    traverse(Tree2(t));
                    uout_lab(loopsp->nextlab);
                    uout_op(Op_Unmark);
                    uout_op(Op_Goto);
                    uout_short(lab);
                    uout_lab(loopsp->breaklab);
                    loopsp--;
                    break;
	    }
            free(Tree0(t));
            break;

        case N_Next:			/* next expression */
            if (loopsp < loopstk || loopsp->nextlab <= 0)
                tfatal_at(t, "invalid context for next");
            else {
                if (loopsp->ltype != EVERY && loopsp->markcount > 1)
                    for (i = 0; i < loopsp->markcount - 1; i++)
                        uout_op(Op_Unmark);
                uout_op(Op_Goto);
                uout_short(loopsp->nextlab);
	    }
            break;

        case N_Not:			/* not expression */
            lab = alclab(1);
            uout_op(Op_Mark);
            uout_short(lab);
            loopsp->markcount++;
            traverse(Tree0(t));
            loopsp->markcount--;
            uout_op(Op_Unmark);
            uout_op(Op_Efail);
            uout_lab(lab);
            uout_op(Op_Pnull);
            break;

        case N_Proc:			/* procedure */
            loopsp = loopstk;
            loopsp->nextlab = 0;
            loopsp->breaklab = 0;
            loopsp->markcount = 0;
            casesp = casestk;
            creatsp = creatstk;
            ensure_pos(t);
            if (TType(Tree1(t)) != N_Empty) {
                lab = alclab(1);
                uout_op(Op_Init);
                uout_short(lab);
                uout_op(Op_Mark);
                uout_short(lab);
                traverse(Tree1(t));
                uout_op(Op_Unmark);
                uout_lab(lab);
	    }
            else
                free(Tree1(t));
            if (TType(Tree2(t)) != N_Empty)
                traverse(Tree2(t));
            else
                free(Tree2(t));
            ensure_pos(Tree3(t));
            uout_op(Op_Pfail);
            uout_op(Op_End);
            report("  %s", Str0(Tree0(t)));
            free(Tree0(t));
            free(Tree3(t));
            break;

        case N_Real:			/* real literal */
            uout_op(Op_Real);
            uout_short((int)Val0(t));
            break;

        case N_Ret:			/* return expression */
            if (creatsp > creatstk)
                tfatal_at(t, "invalid context for return or fail");
            if (Val0(Tree0(t)) == FAIL)
                free(Tree1(t));
            else {
                lab = alclab(1);
                uout_op(Op_Mark);
                uout_short(lab);
                loopsp->markcount++;
                traverse(Tree1(t));
                loopsp->markcount--;
                ensure_pos(t);
                uout_op(Op_Pret);
                uout_lab(lab);
	    }
            ensure_pos(t);
            uout_op(Op_Pfail);
            free(Tree0(t));
            break;

        case N_Scan:			/* scanning expression */
            if (Val0(Tree0(t)) == AUGQMARK)
                uout_op(Op_Pnull);
            traverse(Tree1(t));
            if (Val0(Tree0(t)) == AUGQMARK)
                uout_op(Op_Sdup);
            ensure_pos(t);
            uout_op(Op_Bscan);
            traverse(Tree2(t));
            ensure_pos(t);
            uout_op(Op_Escan);
            if (Val0(Tree0(t)) == AUGQMARK)
                uout_op(Op_Asgn);
            free(Tree0(t));
            break;

        case N_Sect:			/* section operation */
            uout_op(Op_Pnull);
            traverse(Tree1(t));
            traverse(Tree2(t));
            if (Val0(Tree0(t)) == PCOLON || Val0(Tree0(t)) == MCOLON)
                uout_op(Op_Dup);
            traverse(Tree3(t));
            ensure_pos(Tree0(t));
            if (Val0(Tree0(t)) == PCOLON)
                uout_op(Op_Plus);
            else if (Val0(Tree0(t)) == MCOLON)
                uout_op(Op_Minus);
            ensure_pos(t);
            uout_op(Op_Sect);
            free(Tree0(t));
            break;

        case N_Slist:			/* semicolon-separated expr list */
            lab = alclab(1);
            uout_op(Op_Mark);
            uout_short(lab);
            loopsp->markcount++;
            traverse(Tree0(t));
            loopsp->markcount--;
            uout_op(Op_Unmark);
            uout_lab(lab);
            traverse(Tree1(t));
            break;

        case N_Str:			/* string literal */
            uout_op(Op_Str);
            uout_short((int)Val0(t));
            break;

        case N_To:			/* to expression */
            uout_op(Op_Pnull);
            traverse(Tree0(t));
            traverse(Tree1(t));
            uout_op(Op_Push1);
            ensure_pos(t);
            uout_op(Op_Toby);
            break;

        case N_ToBy:			/* to-by expression */
            uout_op(Op_Pnull);
            traverse(Tree0(t));
            traverse(Tree1(t));
            traverse(Tree2(t));
            ensure_pos(t);
            uout_op(Op_Toby);
            break;

        case N_Unop:			/* unary operator */
            unopa((int)Val0(Tree0(t)),t);
            traverse(Tree1(t));
            ensure_pos(t);
            unopb((int)Val0(Tree0(t)));
            free(Tree0(t));
            break;

        default:
            tsyserr("traverse: undefined node type");
    }
    free(t);
    return n;
}

/*
 * binop emits code for binary operators.  For non-augmented operators,
 *  the name of operator is emitted.  For augmented operators, an "asgn"
 *  is emitted after the name of the operator.
 */
static void binop(int op)
{
    register int asgn, opcode = 0;

    asgn = 0;
    switch (op) {

        case ASSIGN:
            opcode = Op_Asgn;
            break;

        case AUGCARET:
            asgn++;
        case CARET:
            opcode = Op_Power;
            break;

        case AUGCONCAT:
            asgn++;
        case CONCAT:
            opcode = Op_Cat;
            break;

        case AUGDIFF:
            asgn++;
        case DIFF:
            opcode = Op_Diff;
            break;

        case AUGEQUIV:
            asgn++;
        case EQUIV:
            opcode = Op_Eqv;
            break;

        case AUGINTER:
            asgn++;
        case INTER:
            opcode = Op_Inter;
            break;

        case LBRACK:
            opcode = Op_Subsc;
            break;

        case AUGLCONCAT:
            asgn++;
        case LCONCAT:
            opcode = Op_Lconcat;
            break;

        case AUGSEQ:
            asgn++;
        case SEQ:
            opcode = Op_Lexeq;
            break;

        case AUGSGE:
            asgn++;
        case SGE:
            opcode = Op_Lexge;
            break;

        case AUGSGT:
            asgn++;
        case SGT:
            opcode = Op_Lexgt;
            break;

        case AUGSLE:
            asgn++;
        case SLE:
            opcode = Op_Lexle;
            break;

        case AUGSLT:
            asgn++;
        case SLT:
            opcode = Op_Lexlt;
            break;

        case AUGSNE:
            asgn++;
        case SNE:
            opcode = Op_Lexne;
            break;

        case AUGMINUS:
            asgn++;
        case MINUS:
            opcode = Op_Minus;
            break;

        case AUGMOD:
            asgn++;
        case MOD:
            opcode = Op_Mod;
            break;

        case AUGNEQUIV:
            asgn++;
        case NEQUIV:
            opcode = Op_Neqv;
            break;

        case AUGNMEQ:
            asgn++;
        case NMEQ:
            opcode = Op_Numeq;
            break;

        case AUGNMGE:
            asgn++;
        case NMGE:
            opcode = Op_Numge;
            break;

        case AUGNMGT:
            asgn++;
        case NMGT:
            opcode = Op_Numgt;
            break;

        case AUGNMLE:
            asgn++;
        case NMLE:
            opcode = Op_Numle;
            break;

        case AUGNMLT:
            asgn++;
        case NMLT:
            opcode = Op_Numlt;
            break;

        case AUGNMNE:
            asgn++;
        case NMNE:
            opcode = Op_Numne;
            break;

        case AUGPLUS:
            asgn++;
        case PLUS:
            opcode = Op_Plus;
            break;

        case REVASSIGN:
            opcode = Op_Rasgn;
            break;

        case REVSWAP:
            opcode = Op_Rswap;
            break;

        case AUGSLASH:
            asgn++;
        case SLASH:
            opcode = Op_Div;
            break;

        case AUGSTAR:
            asgn++;
        case STAR:
            opcode = Op_Mult;
            break;

        case SWAP:
            opcode = Op_Swap;
            break;

        case AUGUNION:
            asgn++;
        case UNION:
            opcode = Op_Unions;
            break;

        default:
            tsyserr("binop: undefined binary operator");
    }
    uout_op(opcode);
    if (asgn)
        uout_op(Op_Asgn);
    
}
/*
 * unopa and unopb handle code emission for unary operators. unary operator
 *  sequences that are the same as binary operator sequences are recognized
 *  by the lexical analyzer as binary operators.  For example, ~===x means to
 *  do three tab(match(...)) operations and then a cset complement, but the
 *  lexical analyzer sees the operator sequence as the "neqv" binary
 *  operation.	unopa and unopb unravel tokens of this form.
 *
 * When a N_Unop node is encountered, unopa is called to emit the necessary
 *  number of "pnull" operations to receive the intermediate results.  This
 *  amounts to a pnull for each operation.
 */
static void unopa(op,t)
    int op;
    nodeptr t;
{
    switch (op) {
        case NEQUIV:		/* unary ~ and three = operators */
            uout_op(Op_Pnull);
        case SNE:		/* unary ~ and two = operators */
        case EQUIV:		/* three unary = operators */
            uout_op(Op_Pnull);
        case NMNE:		/* unary ~ and = operators */
        case UNION:		/* two unary + operators */
        case DIFF:		/* two unary - operators */
        case SEQ:		/* two unary = operators */
        case INTER:		/* two unary * operators */
            uout_op(Op_Pnull);
        case BACKSLASH:		/* unary \ operator */
        case BANG:		/* unary ! operator */
        case CARET:		/* unary ^ operator */
        case PLUS:		/* unary + operator */
        case TILDE:		/* unary ~ operator */
        case MINUS:		/* unary - operator */
        case NMEQ:		/* unary = operator */
        case STAR:		/* unary * operator */
        case QMARK:		/* unary ? operator */
        case SLASH:		/* unary / operator */
        case DOT:			/* unary . operator */
            uout_op(Op_Pnull);
            break;
        default:
            tsyserr("unopa: undefined unary operator");
    }
}

/*
 * unopb is the back-end code emitter for unary operators.  It emits
 *  the operations represented by the token op.  For tokens representing
 *  a single operator, the name of the operator is emitted.  For tokens
 *  representing a sequence of operators, recursive calls are used.  In
 *  such a case, the operator sequence is "scanned" from right to left
 *  and unopb is called with the token for the appropriate operation.
 *
 * For example, consider the sequence of calls and code emission for "~===":
 *	unopb(NEQUIV)		~===
 *	    unopb(NMEQ)	=
 *		emits "tabmat"
 *	    unopb(NMEQ)	=
 *		emits "tabmat"
 *	    unopb(NMEQ)	=
 *		emits "tabmat"
 *	    emits "compl"
 */
static void unopb(int op)
{
    int opcode = 0;

    switch (op) {

        case DOT:			/* unary . operator */
            opcode = Op_Value;
            break;

        case BACKSLASH:		/* unary \ operator */
            opcode = Op_Nonnull;
            break;

        case BANG:		/* unary ! operator */
            opcode = Op_Bang;
            break;

        case CARET:		/* unary ^ operator */
            opcode = Op_Refresh;
            break;

        case UNION:		/* two unary + operators */
            unopb(PLUS);
        case PLUS:		/* unary + operator */
            opcode = Op_Number;
            break;

        case NEQUIV:		/* unary ~ and three = operators */
            unopb(NMEQ);
        case SNE:		/* unary ~ and two = operators */
            unopb(NMEQ);
        case NMNE:		/* unary ~ and = operators */
            unopb(NMEQ);
        case TILDE:		/* unary ~ operator (cset compl) */
            opcode = Op_Compl;
            break;

        case DIFF:		/* two unary - operators */
            unopb(MINUS);
        case MINUS:		/* unary - operator */
            opcode = Op_Neg;
            break;

        case EQUIV:		/* three unary = operators */
            unopb(NMEQ);
        case SEQ:		/* two unary = operators */
            unopb(NMEQ);
        case NMEQ:		/* unary = operator */
            opcode = Op_Tabmat;
            break;

        case INTER:		/* two unary * operators */
            unopb(STAR);
        case STAR:		/* unary * operator */
            opcode = Op_Size;
            break;

        case QMARK:		/* unary ? operator */
            opcode = Op_Random;
            break;

        case SLASH:		/* unary / operator */
            opcode = Op_Null;
            break;

        default:
            tsyserr("unopb: undefined unary operator");
    }
    uout_op(opcode);
}

/*
 *  uout_lab(l) - emit "lab" instruction for label l.
 */
static void uout_lab(int l)
{
    uout_op(Op_Lab);
    uout_short(l);
}

/*
 * alclab allocates n labels and returns the first.  For the interpreter,
 *  labels are restarted at 1 for each procedure, while in the compiler,
 *  they start at 1 and increase throughout the entire compilation.
 */
static int alclab(n)
    int n;
{
    register int lab;

    lab = nextlab;
    nextlab += n;
    return lab;
}
