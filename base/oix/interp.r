/*
 * File: interp.r
 *  The interpreter proper.
 */

#include "../h/opdefs.h"

extern fptr fncentry[];
extern word istart[4]; extern int mterm;

/*
 * Prototypes for static functions.
 */
#if E_Prem || E_Erem
static struct ef_marker *vanq_bound (struct ef_marker *efp_v,
                                      struct gf_marker *gfp_v);
static void vanq_proc (struct ef_marker *efp_v, struct gf_marker *gfp_v);
#endif

/*
 * The following code is operating-system dependent [@interp.01]. Declarations.
 */

#if PORT
Deliberate Syntax Error
#endif					/* PORT */

#if MSWIN32 || UNIX
   /* nothing needed */
#endif					

/*
 * End of operating-system specific code.
 */


/*
 * Istate variables.
 */
struct ef_marker *efp;		/* Expression frame pointer */
struct gf_marker *gfp;		/* Generator frame pointer */
inst ipc;			/* Interpreter program counter */
word *sp = NULL;		/* Stack pointer */


int ilevel;			/* Depth of recursion in interp() */
struct descrip eret_tmp;	/* eret value during unwinding */

int coexp_act;			/* last co-expression action */


/*
 * Macros for use inside the main loop of the interpreter.
 */

#define E_Misc    -1
#define E_Operator 0
#define E_Function 1

/*
 * Setup_Op sets things up for a call to the C function for an operator.
 */
#begdef Setup_Op(nargs,e)
   lastev = E_Operator;
   value_tmp.dword = D_Proc;
   value_tmp.vword.bptr = (union block *)&op_tbl[lastop - 1];
   lastdesc = value_tmp;
   InterpEVValD(&value_tmp, e);
   rargp = (dptr)(rsp - 1) - nargs;
   xargp = rargp;
   ExInterp;
#enddef					/* Setup_Op */

/*
 * Setup_Arg sets things up for a call to the C function.
 *  It is the same as Setup_Op, except the latter is used only
 *  operators.
 */
#begdef Setup_Arg(nargs)
   lastev = E_Misc;
   rargp = (dptr)(rsp - 1) - nargs;
   xargp = rargp;
   ExInterp;
#enddef					/* Setup_Arg */

#begdef Call_Cond
   if ((*(optab[lastop]))(rargp) == A_Resume) {
     InterpEVValD(&lastdesc, e_ofail);
     goto efail_noev;
   }
   rsp = (word *) rargp + 1;
   goto return_term;
#enddef					/* Call_Cond */

/*
 * Call_Gen - Call a generator. A C routine associated with the
 *  current opcode is called. When it terminates, control is
 *  passed to C_rtn_term to deal with the termination condition appropriately.
 */
#begdef Call_Gen
   signal = (*(optab[lastop]))(rargp);
   goto C_rtn_term;
#enddef					/* Call_Gen */

/*
 * GetWord fetches the next icode word.  PutWord(x) stores x at the current
 * icode word.
 */
#define GetWord (*ipc.opnd++)
#define PutWord(x) ipc.opnd[-1] = (x)
#define GetOp (word)(*ipc.op++)
#define PutOp(x) ipc.op[-1] = (x)

/*
 * DerefArg(n) dereferences the nth argument.
 */
#define DerefArg(n)   Deref(rargp[n])

/*
 * For the sake of efficiency, the stack pointer is kept in a register
 *  variable, rsp, in the interpreter loop.  Since this variable is
 *  only accessible inside the loop, and the global variable sp is used
 *  for the stack pointer elsewhere, rsp must be stored into sp when
 *  the context of the loop is left and conversely, rsp must be loaded
 *  from sp when the loop is reentered.  The macros ExInterp and EntInterp,
 *  respectively, handle these operations.  Currently, this register/global
 *  scheme is only used for the stack pointer, but it can be easily extended
 *  to other variables.
 */

#define ExInterp	sp = rsp;
#define EntInterp	rsp = sp;

/*
 * Inside the interpreter loop, PushDesc, PushNull, PushAVal, and
 *  PushVal use rsp instead of sp for efficiency.
 */

#undef PushDesc
#undef PushNull
#undef PushVal
#undef PushAVal
#define PushDesc(d)   {*++rsp=((d).dword); *++rsp=((d).vword.integr);}
#define PushNull   {*++rsp = D_Null; *++rsp = 0;}
#define PushVal(v)   {*++rsp = (word)(v);}

/*
 * The following code is operating-system dependent [@interp.02].  Define
 *  PushAVal for computers that store longs and pointers differently.
 */

#if PORT
#define PushAVal(x) PushVal(x)
Deliberate Syntax Error
#endif					/* PORT */

#if UNIX
#define PushAVal(x) PushVal(x)
#endif

#if MSWIN32
#define PushAVal(x) {rsp++; \
		       stkword.stkadr = (char *)(x); \
		       *rsp = stkword.stkint; \
		       }
#endif					/* MSWIN32 */

/*
 * End of operating-system specific code.
 */

static struct descrip unwinder;

#begdef interp_macro(interp_x,e_intcall,e_stack,e_fsusp,e_osusp,e_bsusp,e_ocall,e_ofail,e_tick,e_line,e_opcode,e_fcall,e_prem,e_erem,e_intret,e_psusp,e_ssusp,e_pret,e_efail,e_sresum,e_fresum,e_oresum,e_eresum,e_presum,e_pfail,e_ffail,e_frem,e_orem,e_fret,e_oret,e_literal,e_fname)

/*
 * The main loop of the interpreter.
 */
int interp_x(int fsig,dptr cargp)
   {
   register word opnd;
   register word *rsp;
   register dptr rargp;
   register struct ef_marker *newefp;
   register struct gf_marker *newgfp;
   register word *wd;
   register word *firstwd, *lastwd;
   word *oldsp;
   int type, signal, args;
   extern int (*optab[])();
   extern int (*keytab[])();
   struct b_proc *bproc;
   int lastev = E_Misc;
   struct descrip lastdesc = nulldesc;

   EVVal(fsig, e_intcall);
   EVVal(DiffPtrs(sp, stack), e_stack);


   /* RPP If we're in a coexpression we can estimate the space between the C stack pointer
    * and the Icon stack pointer (sp).  If they get too close, we're in trouble.
    */
   { 
      struct b_coexpr *curr = (struct b_coexpr *)(curpstate->K_current.vword.bptr);
      if (curr != rootpstate.Mainhead) {
          if ((char*)(&bproc) - (char*)sp < 5000)
              fatalerr(308, NULL);
      }
   }

#ifdef Graphics
   if (!pollctr--) {
      pollctr = pollevent();
      }
#endif					/* Graphics */
/*printf("INTERP csp=%x ilevel=%d local=%d\n",get_sp(),ilevel,(((char*)(&fsig)))-(char*)(&lastdesc));*/

   ilevel++;
   EntInterp;
   switch (fsig) {
   case G_Csusp: case G_Fsusp: case G_Osusp:
#if 0
      value_tmp = *(dptr)(rsp - 1);	/* argument? */
#else
      value_tmp = cargp[0];
#endif
      Deref(value_tmp);
      if (fsig == G_Fsusp) {
	 InterpEVValD(&value_tmp, e_fsusp);
	 }
      else if (fsig == G_Osusp) {
	 InterpEVValD(&value_tmp, e_osusp);
	 }
      else {
	 InterpEVValD(&value_tmp, e_bsusp);
	 }

      oldsp = rsp;

      /*
       * Create the generator frame.
       */
      newgfp = (struct gf_marker *)(rsp + 1);
      newgfp->gf_gentype = fsig;
      newgfp->gf_gfp = gfp;
      newgfp->gf_efp = efp;
      newgfp->gf_ipc = ipc;
      rsp += Wsizeof(struct gf_smallmarker);

      /*
       * Region extends from first word after the marker for the generator
       *  or expression frame enclosing the call to the now-suspending
       *  routine to the first argument of the routine.
       */
      if (gfp != 0) {
	 if (gfp->gf_gentype == G_Psusp)
	    firstwd = (word *)gfp + Wsizeof(*gfp);
	 else
	    firstwd = (word *)gfp + Wsizeof(struct gf_smallmarker);
	 }
      else
	 firstwd = (word *)efp + Wsizeof(*efp);
      lastwd = (word *)cargp + 1;

      /*
       * Copy the portion of the stack with endpoints firstwd and lastwd
       *  (inclusive) to the top of the stack.
       */
      for (wd = firstwd; wd <= lastwd; wd++)
	 *++rsp = *wd;
      gfp = newgfp;
      }
/*
 * Top of the interpreter loop.
 */

   for (;;) {

#if UNIX && e_tick
      if (ticker.l[0] + ticker.l[1] + ticker.l[2] + ticker.l[3] +
	  ticker.l[4] + ticker.l[5] + ticker.l[6] + ticker.l[7] != oldtick) {
	 /*
	  * Record a Tick event reflecting a clock advance.
	  *
	  *  The interpreter main loop has detected a change in the
	  *  profile counters. This means that the system clock has
	  *  ticked.  Record an event and update the records.
	  */
	 word sum, nticks;
	 ExInterp;
	 oldtick = ticker.l[0] + ticker.l[1];
	 sum = ticker.s[0] + ticker.s[1] + ticker.s[2] + ticker.s[3];
	 nticks = sum - oldsum;
	 EVVal(nticks, e_tick);
	 oldsum = sum;
	 EntInterp;
	 }
#endif					/* UNIX && e_tick */

      /*
       * File and linenumber change events
       */

#if e_fname
      if (!is:null(curpstate->eventmask) && (
              Testb((word)(E_Fname), BlkLoc(curpstate->eventmask)->cset.bits))) {
          if (InRange(code, ipc.opnd, ecode)) {
              uword ipc_offset = DiffPtrs((char *)ipc.opnd, (char *)code);
              if (!current_fname_ptr ||
                  ipc_offset < current_fname_ptr->ipc ||
                  (current_fname_ptr + 1 < efilenms && ipc_offset >= current_fname_ptr[1].ipc)) {

                  current_fname_ptr = find_ipc_fname(ipc.opnd, curpstate);
                  if (current_fname_ptr) {
                      InterpEVValD(&current_fname_ptr->fname, e_fname);
                      /* Ensure a fname change is always followed by a line number event (if
                       * requested)
                       */
                      current_line_ptr = 0;
                  }
              }
          }
      }
#endif

#if e_line
      if (!is:null(curpstate->eventmask) && (
              Testb((word)(E_Line), BlkLoc(curpstate->eventmask)->cset.bits))) {
          if (InRange(code, ipc.opnd, ecode)) {
              uword ipc_offset = DiffPtrs((char *)ipc.opnd, (char *)code);
              if (!current_line_ptr ||
                  ipc_offset < current_line_ptr->ipc ||
                  (current_line_ptr + 1 < elines && ipc_offset >= current_line_ptr[1].ipc)) {

                  if(current_line_ptr &&
                     current_line_ptr + 2 < elines &&
                     current_line_ptr[1].ipc < ipc_offset &&
                     ipc_offset < current_line_ptr[2].ipc) {
                      current_line_ptr ++;
                  } 
                  else {
                      current_line_ptr = find_ipc_line(ipc.opnd, curpstate);
                  }
                  if (current_line_ptr)
                      InterpEVVal(current_line_ptr->line, e_line);
              }
          }
      }
#endif					/* e_line */

      lastop = GetOp;		/* Instruction fetch */


/*
 * The following code is operating-system dependent [@interp.03].  Check
 *  for external event.
 */
#if PORT
Deliberate Syntax Error
#endif					/* PORT */

#if MSWIN32 || UNIX
   /* nothing to do */
#endif					

/*
 * End of operating-system specific code.
 */

#if e_opcode
      /*
       * If we've asked for ALL opcode events, or specifically for this one
       * generate an MT-style event.
       */
      if ((!is:null(curpstate->eventmask) &&
	   Testb((word)(E_Opcode), BlkLoc(curpstate->eventmask)->cset.bits)) &&
	  (is:null(curpstate->opcodemask) ||
	   Testb((word)(lastop), BlkLoc(curpstate->opcodemask)->cset.bits))) {
	 ExInterp;
	 MakeInt(lastop, &(curpstate->parent->eventval));
	 actparent(E_Opcode);
	 EntInterp
	 }
#endif					/* E_Opcode */
/*
if (BlkLoc(k_current) != BlkLoc(k_main)) {
printf("%d %d\n",getfree(),(int)lastop); 
showcoexps();
fflush(stdout);
*/


      switch ((int)lastop) {		/*
				 * Switch on opcode.  The cases are
				 * organized roughly by functionality
				 * to make it easier to find things.
				 * For some C compilers, there may be
				 * an advantage to arranging them by
				 * likelihood of selection.
				 */

				/* ---Constant construction--- */

	 case Op_Cset:		/* cset */
	    PutOp(Op_Acset);
	    PushVal(D_Cset);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    PutWord(opnd);
	    PushAVal(opnd);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Acset: 	/* cset, absolute address */
	    PushVal(D_Cset);
	    PushAVal(GetWord);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

         case Op_Ucs: {		/* ucs */
            struct b_ucs *bp;
	    PutOp(Op_Aucs);
	    PushVal(D_Ucs);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    PutWord(opnd);
	    PushAVal(opnd);
            bp = (struct b_ucs *)opnd;
            if (bp->title < 0) {  /* -ve title means we must resolve the utf8 pointer */
                bp->title = -bp->title;
                StrLoc(bp->utf8) = strcons + (uword)StrLoc(bp->utf8);
            }
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;
         }

	 case Op_Aucs: 	/* ucs, absolute address */
	    PushVal(D_Ucs);
	    PushAVal(GetWord);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Int:		/* integer */
	    PushVal(D_Integer);
	    PushVal(GetWord);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Real:		/* real */
	    PutOp(Op_Areal);
	    PushVal(D_Real);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    PushAVal(opnd);
	    PutWord(opnd);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Areal: 	/* real, absolute address */
	    PushVal(D_Real);
	    PushAVal(GetWord);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Str:		/* string */
	    PutOp(Op_Astr);
	    PushVal(GetWord)
	    opnd = (word)strcons + GetWord;
	    PutWord(opnd);
	    PushAVal(opnd);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

	 case Op_Astr:		/* string, absolute address */
	    PushVal(GetWord);
	    PushAVal(GetWord);
	    InterpEVValD((dptr)(rsp-1), e_literal);
	    break;

				/* ---Variable construction--- */

	 case Op_Arg:		/* argument */
	    PushVal(D_Var);
	    PushAVal(&glbl_argp[GetWord + 1]);
	    break;

	 case Op_Global:	/* global */
	    PutOp(Op_Aglobal);
	    PushVal(D_Var);
	    opnd = GetWord;
	    PushAVal(&globals[opnd]);
	    PutWord((word)&globals[opnd]);
	    break;

	 case Op_Aglobal:	/* global, absolute address */
	    PushVal(D_Var);
	    PushAVal(GetWord);
	    break;

	 case Op_Local: 	/* local */
	    PushVal(D_Var);
	    PushAVal(&pfp->pf_locals[GetWord]);
	    break;

	 case Op_Static:	/* static */
	    PutOp(Op_Astatic);
	    PushVal(D_Var);
	    opnd = GetWord;
	    PushAVal(&statics[opnd]);
	    PutWord((word)&statics[opnd]);
	    break;

	 case Op_Astatic:	/* static, absolute address */
	    PushVal(D_Var);
	    PushAVal(GetWord);
	    break;


				/* ---Operators--- */

				/* Unary operators */

	 case Op_Compl: 	/* ~e */
	 case Op_Neg:		/* -e */
	 case Op_Number:	/* +e */
	 case Op_Refresh:	/* ^e */
	 case Op_Size:		/* *e */
	    Setup_Op(1, e_ocall);
	    DerefArg(1);
	    Call_Cond;

	 case Op_Value: 	/* .e */
            Setup_Op(1, e_ocall);
            DerefArg(1);
            Call_Cond;

	 case Op_Nonnull:	/* \e */
	 case Op_Null:		/* /e */
	    Setup_Op(1, e_ocall);
	    Call_Cond;

	 case Op_Random:	/* ?e */
	    PushNull;
	    Setup_Op(2, e_ocall)
	    Call_Cond

				/* Generative unary operators */

	 case Op_Tabmat:	/* =e */
	    Setup_Op(1, e_ocall);
	    DerefArg(1);
	    Call_Gen;

	 case Op_Bang:		/* !e */
	    PushNull;
	    Setup_Op(2, e_ocall);
	    Call_Gen;

				/* Binary operators */

	 case Op_Cat:		/* e1 || e2 */
	 case Op_Diff:		/* e1 -- e2 */
	 case Op_Div:		/* e1 / e2 */
	 case Op_Inter: 	/* e1 ** e2 */
	 case Op_Lconcat:	/* e1 ||| e2 */
	 case Op_Minus: 	/* e1 - e2 */
	 case Op_Mod:		/* e1 % e2 */
	 case Op_Mult:		/* e1 * e2 */
	 case Op_Power: 	/* e1 ^ e2 */
	 case Op_Unions:	/* e1 ++ e2 */
	 case Op_Plus:		/* e1 + e2 */
	 case Op_Eqv:		/* e1 === e2 */
	 case Op_Lexeq: 	/* e1 == e2 */
	 case Op_Lexge: 	/* e1 >>= e2 */
	 case Op_Lexgt: 	/* e1 >> e2 */
	 case Op_Lexle: 	/* e1 <<= e2 */
	 case Op_Lexlt: 	/* e1 << e2 */
	 case Op_Lexne: 	/* e1 ~== e2 */
	 case Op_Neqv:		/* e1 ~=== e2 */
	 case Op_Numeq: 	/* e1 = e2 */
	 case Op_Numge: 	/* e1 >= e2 */
	 case Op_Numgt: 	/* e1 > e2 */
	 case Op_Numle: 	/* e1 <= e2 */
	 case Op_Numne: 	/* e1 ~= e2 */
	 case Op_Numlt: 	/* e1 < e2 */
	    Setup_Op(2, e_ocall);
	    DerefArg(1);
	    DerefArg(2);
	    Call_Cond;

	 case Op_Asgn:		/* e1 := e2 */
	    Setup_Op(2, e_ocall);
	    Call_Cond;

	 case Op_Swap:		/* e1 :=: e2 */
	    PushNull;
	    Setup_Op(3, e_ocall);
	    Call_Cond;

	 case Op_Subsc: 	/* e1[e2] */
	    PushNull;
	    Setup_Op(3, e_ocall);
	    Call_Cond;
				/* Generative binary operators */

	 case Op_Rasgn: 	/* e1 <- e2 */
	    Setup_Op(2, e_ocall);
	    Call_Gen;

	 case Op_Rswap: 	/* e1 <-> e2 */
	    PushNull;
	    Setup_Op(3, e_ocall);
	    Call_Gen;

				/* Conditional ternary operators */

	 case Op_Sect:		/* e1[e2:e3] */
	    PushNull;
	    Setup_Op(4, e_ocall);
	    Call_Cond;
				/* Generative ternary operators */

	 case Op_Toby:		/* e1 to e2 by e3 */
	    Setup_Op(3, e_ocall);
	    DerefArg(1);
	    DerefArg(2);
	    DerefArg(3);
	    Call_Gen;

         case Op_Noop:		/* no-op */

#ifdef Graphics
           if (!pollctr--) { 
	       ExInterp;
               pollctr = pollevent();
	       EntInterp;
	       }	       
#endif					/* Graphics */

            break;


				/* ---String Scanning--- */

	 case Op_Bscan: 	/* prepare for scanning */
	    PushDesc(k_subject);
	    PushVal(D_Integer);
	    PushVal(k_pos);
	    Setup_Arg(2);

	    signal = Obscan(2,rargp);

	    goto C_rtn_term;

	 case Op_Escan: 	/* exit from scanning */
	    Setup_Arg(1);

	    signal = Oescan(1,rargp);

	    goto C_rtn_term;

				/* ---Other Language Operations--- */

         case Op_Apply: {	/* apply, a.k.a. binary bang */
            union block *bp;
            int i, j;

            value_tmp = *(dptr)(rsp - 1);	/* argument */
            Deref(value_tmp);
            switch (Type(value_tmp)) {
               case T_List: {
                  rsp -= 2;				/* pop it off */
                  bp = BlkLoc(value_tmp);
                  args = (int)bp->list.size;


                  for (bp = bp->list.listhead;
		       BlkType(bp) == T_Lelem;
                     bp = bp->lelem.listnext) {
                        for (i = 0; i < bp->lelem.nused; i++) {
                           j = bp->lelem.first + i;
                           if (j >= bp->lelem.nslots)
                              j -= bp->lelem.nslots;
                           PushDesc(bp->lelem.lslots[j])
                           }
                        }
		  goto invokej;
		  }

               case T_Record: {
                  rsp -= 2;		/* pop it off */
                  bp = BlkLoc(value_tmp);
                  args = bp->record.constructor->n_fields;
                  for (i = 0; i < args; i++) {
                     PushDesc(bp->record.fields[i])
                     }
                  goto invokej;
                  }

               default: {		/* illegal type for invocation */
                  xargp = (dptr)(rsp - 3);
                  err_msg(126, &value_tmp);
                  goto efail;
                  }
               }
	    }

	 case Op_Invoke: {	/* invoke */
            args = (int)GetWord;

invokej:
	    {
            int nargs;
	    dptr carg;

	    ExInterp;
	    type = invoke(args, &carg, &nargs);
	    EntInterp;
	    if (type == I_Fail)
	       goto efail_noev;
	    if (type == I_Continue)
	       break;
	    else {

               rargp = carg;		/* valid only for Vararg or Builtin */

#ifdef Graphics
	       /*
		* Do polling here
		*/
	       pollctr >>= 1;
               if (!pollctr) {
	          ExInterp;
                  pollctr = pollevent();
	          EntInterp;
	          }	       
#endif					/* Graphics */

	       lastev = E_Function;
	       lastdesc = *rargp;
	       InterpEVValD(rargp, e_fcall);

	       bproc = (struct b_proc *)BlkLoc(*rargp);

	       /* ExInterp not needed since no change since last EntInterp */
	       if (type == I_Vararg) {
	          int (*bfunc)();
                  bfunc = bproc->entryp.ccode;
		  signal = (*bfunc)(nargs,rargp);
                  }
	       else
                  {
                  int (*bfunc)();
                  bfunc = bproc->entryp.ccode;
		  signal = (*bfunc)(rargp);
                  }
	       goto C_rtn_term;
	       }
	    }
	    break;
	    }

	 case Op_Keywd: 	/* keyword */

            PushNull;
            opnd = GetWord;
            Setup_Arg(0);

	    signal = (*(keytab[(int)opnd]))(rargp);
	    goto C_rtn_term;

	 case Op_Llist: 	/* construct list */
	    opnd = GetWord;

            value_tmp.dword = D_Proc;
            value_tmp.vword.bptr = (union block *)&mt_llist;
            lastev = E_Operator;
	    lastdesc = value_tmp;
            InterpEVValD(&value_tmp, e_ocall);
            rargp = (dptr)(rsp - 1) - opnd;
            xargp = rargp;
            ExInterp;

	    {
	    int i;
	    for (i=1;i<=opnd;i++)
               DerefArg(i);
	    }

	    signal = Ollist((int)opnd,rargp);

	    goto C_rtn_term;

				/* ---Marking and Unmarking--- */

	 case Op_Mark:		/* create expression frame marker */
	    PutOp(Op_Amark);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    PutWord(opnd);
	    newefp = (struct ef_marker *)(rsp + 1);
	    newefp->ef_failure.opnd = (word *)opnd;
	    goto mark;

	 case Op_Amark: 	/* mark with absolute fipc */
	    newefp = (struct ef_marker *)(rsp + 1);
	    newefp->ef_failure.opnd = (word *)GetWord;
mark:
	    newefp->ef_gfp = gfp;
	    newefp->ef_efp = efp;
	    newefp->ef_ilevel = ilevel;
	    rsp += Wsizeof(*efp);
	    efp = newefp;
	    gfp = 0;
	    break;

	 case Op_Mark0: 	/* create expression frame with 0 ipl */
mark0:
	    newefp = (struct ef_marker *)(rsp + 1);
	    newefp->ef_failure.opnd = 0;
	    newefp->ef_gfp = gfp;
	    newefp->ef_efp = efp;
	    newefp->ef_ilevel = ilevel;
	    rsp += Wsizeof(*efp);
	    efp = newefp;
	    gfp = 0;
	    break;

	 case Op_Unmark:	/* remove expression frame */

#if e_prem || e_erem
	    ExInterp;
            vanq_bound(efp, gfp);
	    EntInterp;
#endif					/* E_Prem || E_Erem */

	    gfp = efp->ef_gfp;
	    rsp = (word *)efp - 1;

	    /*
	     * Remove any suspended C generators.
	     */
Unmark_uw:
	    if (efp->ef_ilevel < ilevel) {
	       --ilevel;
	       ExInterp;
	       EVVal(A_Unmark_uw, e_intret);
               EVVal(DiffPtrs(sp, stack), e_stack);
	       return A_Unmark_uw;
	       }

	    efp = efp->ef_efp;
	    break;

				/* ---Suspensions--- */

	 case Op_Esusp: {	/* suspend from expression */

	    /*
	     * Create the generator frame.
	     */
	    oldsp = rsp;
	    newgfp = (struct gf_marker *)(rsp + 1);
	    newgfp->gf_gentype = G_Esusp;
	    newgfp->gf_gfp = gfp;
	    newgfp->gf_efp = efp;
	    newgfp->gf_ipc = ipc;
	    gfp = newgfp;
	    rsp += Wsizeof(struct gf_smallmarker);

	    /*
	     * Region extends from first word after enclosing generator or
	     *	expression frame marker to marker for current expression frame.
	     */
	    if (efp->ef_gfp != 0) {
	       newgfp = (struct gf_marker *)(efp->ef_gfp);
	       if (newgfp->gf_gentype == G_Psusp)
		  firstwd = (word *)efp->ef_gfp + Wsizeof(*gfp);
	       else
		  firstwd = (word *)efp->ef_gfp +
		     Wsizeof(struct gf_smallmarker);
		}
	    else
	       firstwd = (word *)efp->ef_efp + Wsizeof(*efp);
	    lastwd = (word *)efp - 1;
	    efp = efp->ef_efp;

	    /*
	     * Copy the portion of the stack with endpoints firstwd and lastwd
	     *	(inclusive) to the top of the stack.
	     */
	    for (wd = firstwd; wd <= lastwd; wd++)
	       *++rsp = *wd;
	    PushVal(oldsp[-1]);
	    PushVal(oldsp[0]);
	    break;
	    }

	 case Op_Lsusp: {	/* suspend from limitation */
	    struct descrip sval;

	    /*
	     * The limit counter is contained in the descriptor immediately
	     *	prior to the current expression frame.	lval is established
	     *	as a pointer to this descriptor.
	     */
	    dptr lval = (dptr)((word *)efp - 2);

	    /*
	     * Decrement the limit counter and check it.
	     */
	    if (--IntVal(*lval) > 0) {
	       /*
		* The limit has not been reached, set up stack.
		*/
	       sval = *(dptr)(rsp - 1);	/* save result */

	       /*
		* Region extends from first word after enclosing generator or
		*  expression frame marker to the limit counter just prior to
		*  to the current expression frame marker.
		*/
	       if (efp->ef_gfp != 0) {
		  newgfp = (struct gf_marker *)(efp->ef_gfp);
		  if (newgfp->gf_gentype == G_Psusp)
		     firstwd = (word *)efp->ef_gfp + Wsizeof(*gfp);
		  else
		     firstwd = (word *)efp->ef_gfp +
			Wsizeof(struct gf_smallmarker);
		  }
	       else
		  firstwd = (word *)efp->ef_efp + Wsizeof(*efp);
	       lastwd = (word *)efp - 3;
	       if (gfp == 0)
		  gfp = efp->ef_gfp;
	       efp = efp->ef_efp;

	       /*
		* Copy the portion of the stack with endpoints firstwd and lastwd
		*  (inclusive) to the top of the stack.
		*/
	       rsp -= 2;		/* overwrite result */
	       for (wd = firstwd; wd <= lastwd; wd++)
		  *++rsp = *wd;
	       PushDesc(sval);		/* push saved result */
	       }
	    else {
	       /*
		* Otherwise, the limit has been reached.  Instead of
		*  suspending, remove the current expression frame and
		*  replace the limit counter with the value on top of
		*  the stack (which would have been suspended had the
		*  limit not been reached).
		*/
	       *lval = *(dptr)(rsp - 1);

#if e_prem || e_erem
	       ExInterp;
               vanq_bound(efp, gfp);
	       EntInterp;
#endif					/* E_Prem || E_Erem */

	       gfp = efp->ef_gfp;

	       /*
		* Since an expression frame is being removed, inactive
		*  C generators contained therein are deactivated.
		*/
Lsusp_uw:
	       if (efp->ef_ilevel < ilevel) {
		  --ilevel;
		  ExInterp;
                  EVVal(A_Lsusp_uw, e_intret);
                  EVVal(DiffPtrs(sp, stack), e_stack);
		  return A_Lsusp_uw;
		  }
	       rsp = (word *)efp - 1;
	       efp = efp->ef_efp;
	       }
	    break;
	    }

	 case Op_Psusp: {	/* suspend from procedure */

	    /*
	     * An Icon procedure is suspending a value.  Determine if the
	     *	value being suspended should be dereferenced and if so,
	     *	dereference it. If tracing is on, strace is called
	     *  to generate a message.  Appropriate values are
	     *	restored from the procedure frame of the suspending procedure.
	     */

	    struct descrip tmp;
            dptr svalp;
	    struct b_proc *sproc;

#if e_psusp
            value_tmp = *(dptr)(rsp - 1);	/* argument */
            Deref(value_tmp);
            InterpEVValD(&value_tmp, E_Psusp);
#endif					/* E_Psusp */

	    svalp = (dptr)(rsp - 1);
	    if (Var(*svalp)) {
               ExInterp;
               retderef(svalp, (word *)glbl_argp, sp);
               EntInterp;
               }

	    /*
	     * Create the generator frame.
	     */
	    oldsp = rsp;
	    newgfp = (struct gf_marker *)(rsp + 1);
	    newgfp->gf_gentype = G_Psusp;
	    newgfp->gf_gfp = gfp;
	    newgfp->gf_efp = efp;
	    newgfp->gf_ipc = ipc;
	    newgfp->gf_argp = glbl_argp;
	    newgfp->gf_pfp = pfp;
	    gfp = newgfp;
	    rsp += Wsizeof(*gfp);

	    /*
	     * Region extends from first word after the marker for the
	     *	generator or expression frame enclosing the call to the
	     *	now-suspending procedure to Arg0 of the procedure.
	     */
	    if (pfp->pf_gfp != 0) {
	       newgfp = (struct gf_marker *)(pfp->pf_gfp);
	       if (newgfp->gf_gentype == G_Psusp)
		  firstwd = (word *)pfp->pf_gfp + Wsizeof(*gfp);
	       else
		  firstwd = (word *)pfp->pf_gfp +
		     Wsizeof(struct gf_smallmarker);
	       }
	    else
	       firstwd = (word *)pfp->pf_efp + Wsizeof(*efp);
	    lastwd = (word *)glbl_argp - 1;
	       efp = efp->ef_efp;

	    /*
	     * Copy the portion of the stack with endpoints firstwd and lastwd
	     *	(inclusive) to the top of the stack.
	     */
	    for (wd = firstwd; wd <= lastwd; wd++)
	       *++rsp = *wd;
	    PushVal(oldsp[-1]);
	    PushVal(oldsp[0]);
	    --k_level;
	    if (k_trace) {
               k_trace--;
	       sproc = (struct b_proc *)BlkLoc(*glbl_argp);
	       strace(&(sproc->pname), svalp);
	       }

	    /*
	     * If the scanning environment for this procedure call is in
	     *	a saved state, switch environments.
	     */
	    if (pfp->pf_scan != NULL) {
	       InterpEVValD(&k_subject, e_ssusp);
	       tmp = k_subject;
	       k_subject = *pfp->pf_scan;
	       *pfp->pf_scan = tmp;

	       tmp = *(pfp->pf_scan + 1);
	       IntVal(*(pfp->pf_scan + 1)) = k_pos;
	       k_pos = IntVal(tmp);
	       }

	    efp = pfp->pf_efp;
	    ipc = pfp->pf_ipc;
	    glbl_argp = pfp->pf_argp;
            CHANGEPROGSTATE(pfp->pf_from);
	    pfp = pfp->pf_pfp;

	    break;
	    }

				/* ---Returns--- */

	 case Op_Eret: {	/* return from expression */
	    /*
	     * Op_Eret removes the current expression frame, leaving the
	     *	original top of stack value on top.
	     */
	    /*
	     * Save current top of stack value in global temporary (no
	     *	danger of reentry).
	     */
	    eret_tmp = *(dptr)&rsp[-1];
	    gfp = efp->ef_gfp;
Eret_uw:
	    /*
	     * Since an expression frame is being removed, inactive
	     *	C generators contained therein are deactivated.
	     */
	    if (efp->ef_ilevel < ilevel) {
	       --ilevel;
	       ExInterp;
               EVVal(A_Eret_uw, e_intret);
               EVVal(DiffPtrs(sp, stack), e_stack);
	       return A_Eret_uw;
	       }
	    rsp = (word *)efp - 1;
	    efp = efp->ef_efp;
	    PushDesc(eret_tmp);
	    break;
	    }


	 case Op_Pret: {	/* return from procedure */
	   struct descrip oldargp;

	    /*
	     * An Icon procedure is returning a value.	Determine if the
	     *	value being returned should be dereferenced and if so,
	     *	dereference it.  If tracing is on, rtrace is called to
	     *	generate a message.  Inactive generators created after
	     *	the activation of the procedure are deactivated.  Appropriate
	     *	values are restored from the procedure frame.
	     */
	    struct b_proc *rproc;
	    rproc = (struct b_proc *)BlkLoc(*glbl_argp);
            oldargp = *glbl_argp;
#if e_prem || e_erem
	    ExInterp;
            vanq_proc(efp, gfp);
	    EntInterp;
	    /* used to InterpEVValD(argp,E_Pret); here */
#endif					/* E_Prem || E_Erem */

	    *glbl_argp = *(dptr)(rsp - 1);
	    if (Var(*glbl_argp)) {
               ExInterp;
               retderef(glbl_argp, (word *)glbl_argp, sp);
               EntInterp;
               }

	    --k_level;
	    if (k_trace) {
               k_trace--;
	       rtrace(&(rproc->pname), glbl_argp);
               }
Pret_uw:
	    if (pfp->pf_ilevel < ilevel) {
	       --ilevel;
	       ExInterp;

               EVVal(A_Pret_uw, e_intret);
               EVVal(DiffPtrs(sp, stack), e_stack);
	       unwinder = oldargp;
	       return A_Pret_uw;
	       }
	   
	   if (!is:proc(oldargp) && is:proc(unwinder))
	      oldargp = unwinder;
	    rsp = (word *)glbl_argp + 1;
	    efp = pfp->pf_efp;
	    gfp = pfp->pf_gfp;
	    ipc = pfp->pf_ipc;
	    glbl_argp = pfp->pf_argp;
            CHANGEPROGSTATE(pfp->pf_from);
	    pfp = pfp->pf_pfp;
#if e_pret
            value_tmp = *(dptr)(rsp - 1);	/* argument */
            Deref(value_tmp);
            InterpEVValD(&value_tmp, E_Pret);
#endif					/* E_Pret */

	    break;
	    }

				/* ---Failures--- */

	 case Op_Efail:
efail:
            InterpEVVal((word)-1, e_efail);
efail_noev:
	    /*
	     * Failure has occurred in the current expression frame.
	     */
	    if (gfp == 0) {
	       /*
		* There are no suspended generators to resume.
		*  Remove the current expression frame, restoring
		*  values.
		*
		* If the failure ipc is 0, propagate failure to the
		*  enclosing frame by branching back to efail.
		*  This happens, for example, in looping control
		*  structures that fail when complete.
		*/

	      if (efp == 0) {
		 break;
	         }

	       ipc = efp->ef_failure;
	       gfp = efp->ef_gfp;
	       rsp = (word *)efp - 1;
	       efp = efp->ef_efp;

	       if (ipc.op == 0)
		  goto efail;
	       break;
	       }

	    else {
	       /*
		* There is a generator that can be resumed.  Make
		*  the stack adjustments and then switch on the
		*  type of the generator frame marker.
		*/
	       struct descrip tmp;
	       register struct gf_marker *resgfp = gfp;

	       type = (int)resgfp->gf_gentype;

	       if (type == G_Psusp) {
		  glbl_argp = resgfp->gf_argp;
		  if (k_trace) {	/* procedure tracing */
                     k_trace--;
		     ExInterp;
		     atrace(&(((struct b_proc *)BlkLoc(*glbl_argp))->pname));
		     EntInterp;
		     }
		  }
	       ipc = resgfp->gf_ipc;
	       efp = resgfp->gf_efp;
	       gfp = resgfp->gf_gfp;
	       rsp = (word *)resgfp - 1;
	       if (type == G_Psusp) {
		  pfp = resgfp->gf_pfp;

		  /*
		   * If the scanning environment for this procedure call is
		   *  supposed to be in a saved state, switch environments.
		   */
		  if (pfp->pf_scan != NULL) {
		     tmp = k_subject;
		     k_subject = *pfp->pf_scan;
		     *pfp->pf_scan = tmp;

		     tmp = *(pfp->pf_scan + 1);
		     IntVal(*(pfp->pf_scan + 1)) = k_pos;
		     k_pos = IntVal(tmp);
		     InterpEVValD(&k_subject, e_sresum);
		     }

                  CHANGEPROGSTATE(pfp->pf_to);

		  ++k_level;		/* adjust procedure level */
		  }

	       switch (type) {
		  case G_Fsusp:
		     ExInterp;
                     EVVal((word)0, e_fresum);
		     --ilevel;
                     EVVal(A_Resume, e_intret);
                     EVVal(DiffPtrs(sp, stack), e_stack);
		     return A_Resume;

		  case G_Osusp:
		     ExInterp;
                     EVVal((word)0, e_oresum);
		     --ilevel;
                     EVVal(A_Resume, e_intret);
                     EVVal(DiffPtrs(sp, stack), e_stack);
		     return A_Resume;

		  case G_Csusp:
		     ExInterp;
                     EVVal((word)0, e_eresum);
		     --ilevel;
                     EVVal(A_Resume, e_intret);
                     EVVal(DiffPtrs(sp, stack), e_stack);
		     return A_Resume;

		  case G_Esusp:
                     InterpEVVal((word)0, e_eresum);
		     goto efail_noev;

		  case G_Psusp:		/* resuming a procedure */
                     InterpEVValD(glbl_argp, e_presum);
		     break;
		  }

	       break;
	       }

	 case Op_Pfail: {	/* fail from procedure */
#if e_pfail || e_prem || e_erem
	    ExInterp;
#if e_prem || e_erem
            vanq_proc(efp, gfp);
#endif					/* E_Prem || E_Erem */
            EVValD(glbl_argp, e_pfail);
	    EntInterp;
#endif					/* E_Pfail || E_Prem || E_Erem */

	    /*
	     * An Icon procedure is failing.  Generate tracing message if
	     *	tracing is on.	Deactivate inactive C generators created
	     *	after activation of the procedure.  Appropriate values
	     *	are restored from the procedure frame.
	     */

	    --k_level;
	    if (k_trace) {
               k_trace--;
	       failtrace(&(((struct b_proc *)BlkLoc(*glbl_argp))->pname));
               }
Pfail_uw:

	    if (pfp->pf_ilevel < ilevel) {
	       --ilevel;
	       ExInterp;
               EVVal(A_Pfail_uw, e_intret);
               EVVal(DiffPtrs(sp, stack), e_stack);
	       return A_Pfail_uw;
	       }

	    efp = pfp->pf_efp;
	    gfp = pfp->pf_gfp;
	    ipc = pfp->pf_ipc;
	    glbl_argp = pfp->pf_argp;
            CHANGEPROGSTATE(pfp->pf_from);
	    pfp = pfp->pf_pfp;

	    goto efail_noev;
	    }
				/* ---Odds and Ends--- */

	 case Op_Ccase: 	/* case clause */
	    PushNull;
	    PushVal(((word *)efp)[-2]);
	    PushVal(((word *)efp)[-1]);
	    break;

	 case Op_Chfail:	/* change failure ipc */
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    efp->ef_failure.opnd = (word *)opnd;
	    break;

	 case Op_Dup:		/* duplicate descriptor */
	    PushNull;
	    rsp[1] = rsp[-3];
	    rsp[2] = rsp[-2];
	    rsp += 2;
	    break;

	 case Op_Field: 	/* e1.e2 */
	    PushVal(D_Integer);
	    PushVal(GetWord);
	    Setup_Arg(2);
ExInterp;
	    signal = Ofield(2,rargp);
EntInterp;

	    goto C_rtn_term;

	 case Op_Goto:		/* goto */
	    PutOp(Op_Agoto);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;
	    PutWord(opnd);
	    ipc.opnd = (word *)opnd;
	    break;

	 case Op_Agoto: 	/* goto absolute address */
	    opnd = GetWord;
	    ipc.opnd = (word *)opnd;
	    break;

	 case Op_Init:		/* initial */
	    *--ipc.op = Op_Goto;
	    opnd = sizeof(*ipc.op) + sizeof(*rsp);
	    opnd += (word)ipc.opnd;
	    ipc.opnd = (word *)opnd;
	    break;

	 case Op_Limit: 	/* limit */
	    Setup_Arg(0);

	    if (Olimit(0,rargp) == A_Resume) {

	       /*
		* limit has failed here; could generate an event for it,
		*  but not an Ofail since limit is not an operator and
		*  no Ocall was ever generated for it.
		*/
	       goto efail_noev;
	       }
	    else {
	       /*
		* limit has returned here; could generate an event for it,
		*  but not an Oret since limit is not an operator and
		*  no Ocall was ever generated for it.
		*/
	       rsp = (word *) rargp + 1;
	       }
	    goto mark0;

	 case Op_Pnull: 	/* push null descriptor */
	    PushNull;
	    break;

	 case Op_Pop:		/* pop descriptor */
	    rsp -= 2;
	    break;

	 case Op_Push1: 	/* push integer 1 */
	    PushVal(D_Integer);
	    PushVal(1);
	    break;

	 case Op_Pushn1:	/* push integer -1 */
	    PushVal(D_Integer);
	    PushVal(-1);
	    break;

	 case Op_Sdup:		/* duplicate descriptor */
	    rsp += 2;
	    rsp[-1] = rsp[-3];
	    rsp[0] = rsp[-2];
	    break;

					/* --- calling Icon from C --- */
         case Op_CopyArgs: {
            int i; 
            dptr d;
            opnd = GetWord;
            d = ((dptr)efp) - opnd;
            for (i = 0; i < opnd; ++i) {
                *++rsp = (d->dword);
                *++rsp =(d->vword.integr);
                ++d;
            }
            break;
         }         

         case Op_Trapret:
            ilevel--;
            ExInterp;
            return A_Trapret;
         
         case Op_Trapfail:
            ilevel--;
            ExInterp;
            return A_Trapfail;

					/* ---Co-expressions--- */

	 case Op_Create:	/* create */

	    PushNull;
	    Setup_Arg(0);
	    opnd = GetWord;
	    opnd += (word)ipc.opnd;

	    signal = Ocreate((word *)opnd, rargp);

	    goto C_rtn_term;

	 case Op_Coact: {	/* @e */

            struct b_coexpr *ncp;
            dptr dp;

            ExInterp;
            dp = (dptr)(sp - 1);
            xargp = dp - 2;

            Deref(*dp);
            if (dp->dword != D_Coexpr) {
               err_msg(118, dp);
               goto efail;
               }

            ncp = (struct b_coexpr *)BlkLoc(*dp);

            signal = activate((dptr)(sp - 3), ncp, (dptr)(sp - 3));
            EntInterp;
            if (signal == A_Resume)
               goto efail_noev;
            else
               rsp -= 2;
            break;
	    }

	 case Op_Coret: {	/* return from co-expression */

            struct b_coexpr *ncp;

            ExInterp;
            ncp = popact((struct b_coexpr *)BlkLoc(k_current));

            ++BlkLoc(k_current)->coexpr.size;
            co_chng(ncp, (dptr)&sp[-1], NULL, A_Coret, 1);
            EntInterp;
            break;

	    }

	 case Op_Cofail: {	/* fail from co-expression */

            struct b_coexpr *ncp;

            ExInterp;
            ncp = popact((struct b_coexpr *)BlkLoc(k_current));

            co_chng(ncp, NULL, NULL, A_Cofail, 1);
            EntInterp;
            break;

	    }
         case Op_Quit:		/* quit */


	    goto interp_quit;


	 default: {
	    char buf[50];

	    sprintf(buf, "unimplemented opcode: %ld (0x%08x)\n",
               (long)lastop, lastop);
	    syserr(buf);
	    }
	 }
	 continue;

C_rtn_term:
	 EntInterp;

	 switch (signal) {

	    case A_Resume:
	    if (lastev == E_Function) {
	       InterpEVValD(&lastdesc, e_ffail);
	       lastev = E_Misc;
	       }
	    else if (lastev == E_Operator) {
	       InterpEVValD(&lastdesc, e_ofail);
	       lastev = E_Misc;
	       }
	       goto efail_noev;

	    case A_Unmark_uw:		/* unwind for unmark */
	       if (lastev == E_Function) {
		  InterpEVValD(&lastdesc, e_frem);
		  lastev = E_Misc;
		  }
	       else if (lastev == E_Operator) {
		  InterpEVValD(&lastdesc, e_orem);
		  lastev = E_Misc;
		  }
	       goto Unmark_uw;

	    case A_Lsusp_uw:		/* unwind for lsusp */
	       if (lastev == E_Function) {
		  InterpEVValD(&lastdesc, e_frem);
		  lastev = E_Misc;
		  }
	       else if (lastev == E_Operator) {
		  InterpEVValD(&lastdesc, e_orem);
		  lastev = E_Misc;
		  }
	       goto Lsusp_uw;

	    case A_Eret_uw:		/* unwind for eret */
	       if (lastev == E_Function) {
		  InterpEVValD(&lastdesc, e_frem);
		  lastev = E_Misc;
		  }
	       else if (lastev == E_Operator) {
		  InterpEVValD(&lastdesc, e_orem);
		  lastev = E_Misc;
		  }
	       goto Eret_uw;

	    case A_Pret_uw:		/* unwind for pret */
	       if (lastev == E_Function) {
		  InterpEVVal(&lastdesc, e_frem);
		  lastev = E_Misc;
		  }
	       else if (lastev == E_Operator) {
		  InterpEVVal(&lastdesc, e_orem);
		  lastev = E_Misc;
		  }
	       goto Pret_uw;

	    case A_Pfail_uw:		/* unwind for pfail */
	       if (lastev == E_Function) {
		  InterpEVValD(&lastdesc, e_frem);
		  lastev = E_Misc;
		  }
	       else if (lastev == E_Operator) {
		  InterpEVValD(&lastdesc, e_orem);
		  lastev = E_Misc;
		  }
	       goto Pfail_uw;
	    }

	 rsp = (word *)rargp + 1;	/* set rsp to result */

return_term:
         if (lastev == E_Function) {
#if e_fret
	    value_tmp = *(dptr)(rsp - 1);	/* argument */
	    Deref(value_tmp);
	    InterpEVValD(&value_tmp, e_fret);
#endif					/* E_Fret */
	    lastev = E_Misc;
	    }
         else if (lastev == E_Operator) {
#if e_oret
	    value_tmp = *(dptr)(rsp - 1);	/* argument */
	    Deref(value_tmp);
	    InterpEVValD(&value_tmp, e_oret);
#endif					/* E_Oret */
	    lastev = E_Misc;
	    }

	 continue;
	 }

interp_quit:
   --ilevel;
   if (ilevel != 0)
      syserr("interp: termination with inactive generators.");

   /*NOTREACHED*/
   return 0;	/* avoid gcc warning */
   }
#enddef

interp_macro(interp_0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
interp_macro(interp_1,E_Intcall,E_Stack,E_Fsusp,E_Osusp,E_Bsusp,E_Ocall,E_Ofail,E_Tick,E_Line,E_Opcode,E_Fcall,E_Prem,E_Erem,E_Intret,E_Psusp,E_Ssusp,E_Pret,E_Efail,E_Sresum,E_Fresum,E_Oresum,E_Eresum,E_Presum,E_Pfail,E_Ffail,E_Frem,E_Orem,E_Fret,E_Oret,E_Literal,E_Fname)

#if E_Prem || E_Erem
/*
 * vanq_proc - monitor the removal of suspended operations from within
 *   a procedure.
 */
static void vanq_proc(efp_v, gfp_v)
struct ef_marker *efp_v;
struct gf_marker *gfp_v;
   {

   if (is:null(curpstate->eventmask))
      return;

   /*
    * Go through all the bounded expression of the procedure.
    */
   while ((efp_v = vanq_bound(efp_v, gfp_v)) != NULL) {
      gfp_v = efp_v->ef_gfp;
      efp_v = efp_v->ef_efp;
      }
   }

/*
 * vanq_bound - monitor the removal of suspended operations from
 *   the current bounded expression and return the expression frame
 *   pointer for the bounded expression.
 */
static struct ef_marker *vanq_bound(efp_v, gfp_v)
struct ef_marker *efp_v;
struct gf_marker *gfp_v;
   {

   if (is:null(curpstate->eventmask))
      return efp_v;

   while (gfp_v != 0) {		/* note removal of suspended operations */
      switch ((int)gfp_v->gf_gentype) {
         case G_Psusp:
            EVValD(gfp_v->gf_argp, E_Prem);
            break;
	 /* G_Fsusp and G_Osusp handled in-line during unwinding */
         case G_Esusp:
            EVVal((word)0, E_Erem);
            break;
         }

      if (((int)gfp_v->gf_gentype) == G_Psusp) {
         vanq_proc(gfp_v->gf_efp, gfp_v->gf_gfp);
         efp_v = gfp_v->gf_pfp->pf_efp;           /* efp before the call */
         gfp_v = gfp_v->gf_pfp->pf_gfp;           /* gfp before the call */
         }
      else {
         efp_v = gfp_v->gf_efp;
         gfp_v = gfp_v->gf_gfp;
         }
      }

   return efp_v;
   }
#endif					/* E_Prem || E_Erem */

/*
 * activate some other co-expression from an arbitrary point in
 * the interpreter.
 */
int mt_activate(tvalp,rslt,ncp)
dptr tvalp, rslt;
register struct b_coexpr *ncp;
{
   register struct b_coexpr *ccp = (struct b_coexpr *)BlkLoc(k_current);
   int first, rv;
   dptr savedtvalloc = NULL;

   /*
    * Set activator in new co-expression.
    */
   if (ncp->es_actstk == NULL) {
      MemProtect(ncp->es_actstk = alcactiv());
      /*
       * If no one ever explicitly activates this co-expression, fail to
       * the implicit activator.
       */
      ncp->es_actstk->arec[0].activator = ccp;
      first = 0;
      }
   else
      first = 1;

   if(ccp->tvalloc) {
     if (InRange(blkbase,ccp->tvalloc,blkfree)) {
       fprintf(stderr,
	       "Multiprogram garbage collection disaster in mt_activate()!\n");
       fflush(stderr);
       exit(1);
     }
     savedtvalloc = ccp->tvalloc;
   }

   ccp->program->Kywd_time_out = millisec();

   rv = co_chng(ncp, tvalp, rslt, A_MTEvent, first);

   ccp->program->Kywd_time_elsewhere +=
      millisec() - ccp->program->Kywd_time_out;

   if ((savedtvalloc != NULL) && (savedtvalloc != ccp->tvalloc)) {
#if 0
      fprintf(stderr,"averted co-expression disaster in activate\n");
#endif
      ccp->tvalloc = savedtvalloc;
      }

   /*
    * flush any accumulated ticks
    */
#if UNIX && E_Tick
   if (ticker.l[0] + ticker.l[1] + ticker.l[2] + ticker.l[3] +
       ticker.l[4] + ticker.l[5] + ticker.l[6] + ticker.l[7] != oldtick) {
      word sum, nticks;

      oldtick = ticker.l[0] + ticker.l[1] + ticker.l[2] + ticker.l[3] +
       ticker.l[4] + ticker.l[5] + ticker.l[6] + ticker.l[7];
      sum = ticker.s[0] + ticker.s[1] + ticker.s[2] + ticker.s[3] +
	 ticker.s[4] + ticker.s[5] + ticker.s[6] + ticker.s[7] +
	    ticker.s[8] + ticker.s[9] + ticker.s[10] + ticker.s[11] +
	       ticker.s[12] + ticker.s[13] + ticker.s[14] + ticker.s[15];
      nticks = sum - oldsum;
      oldsum = sum;
      }
#endif					/* UNIX && E_Tick */

   return rv;
}


/*
 * activate the "&parent" co-expression from anywhere, if there is one
 */
void actparent(event)
int event;
   {
   struct progstate *parent = curpstate->parent;

   curpstate->eventcount.vword.integr++;
   StrLen(parent->eventcode) = 1;
   StrLoc(parent->eventcode) = (char *)&allchars[event & 0xFF];
   mt_activate(&(parent->eventcode), NULL,
	       (struct b_coexpr *)curpstate->parent->Mainhead);
   }


/**
static void validateprogstate(struct progstate *p)
{
    if (!InRange(p->Code, ipc.op, p->Ecode) &&
        !InRange(((char *)istart), ipc.op,((char *)istart)+sizeof(istart)) &&
        ipc.op != &mterm) {
        printf("<<<<<No p=%p ipc=%p\n",p,ipc.op);
    }
}
*/


void changeprogstate(struct progstate *p)
{
/*    printf("changing state from %lx to %lx\n",curpstate,p);   */
/*    this test doesn't really work now because the icode could be in a dynamically
      alloced array created in do_invoke (invoke.r) */
/*    validateprogstate(p); */
    p->Glbl_argp = glbl_argp;
    p->K_current = k_current;
    ENTERPSTATE(p);
    BlkLoc(k_current)->coexpr.program = curpstate;
}

