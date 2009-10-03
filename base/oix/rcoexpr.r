/*
 * File: rcoexpr.r -- co_init, co_chng
 */


/*
 * co_init - use the contents of the refresh block to initialize the
 *  co-expression.
 */
void co_init(sblkp)
struct b_coexpr *sblkp;
{
   register word *newsp;
   register dptr dp, dsp;
   int na, nl, i;
   /*
    * Get pointer to refresh block.
    */
   struct b_refresh *rblkp = sblkp->freshblk;

   na = (rblkp->pfmkr).pf_nargs + 1; /* number of arguments */
   nl = (int)rblkp->numlocals;       /* number of locals */

   /*
    * The interpreter stack starts at word after co-expression stack block.
    *  C stack starts at end of stack region on machines with down-growing C
    *  stacks and somewhere in the middle of the region.
    *
    * The C stack is aligned on a doubleword boundary.	For up-growing
    *  stacks, the C stack starts in the middle of the stack portion
    *  of the static block.  For down-growing stacks, the C stack starts
    *  at the last word of the static block.
    */

   newsp = (word *)((char *)sblkp + sizeof(struct b_coexpr));

   sblkp->cstate[0] = StackAlign((char *)sblkp + xstksize - WordSize);

   sblkp->es_argp = (dptr)newsp;  /* args are first thing on stack */


   /*
    * Copy arguments onto new stack.
    */
   dsp = sblkp->es_argp;
   dp = rblkp->elems;
   for (i = 1; i <=  na; i++)
      *dsp++ = *dp++;

   /*
    * Set up state variables and initialize procedure frame.
    */
   *((struct pf_marker *)dsp) = rblkp->pfmkr;
   sblkp->es_pfp = (struct pf_marker *)dsp;
   sblkp->es_tend = NULL;
   dsp = (dptr)((word *)dsp + Vwsizeof(*pfp));
   sblkp->es_ipc = rblkp->ep;
   sblkp->es_gfp = 0;
   sblkp->es_efp = 0;
   sblkp->es_ilevel = 0;
   sblkp->tvalloc = NULL;
   /* The current program (in which the entry ipc lives) is found in the
    * pf_to field of the current stack frame. */
   sblkp->program = rblkp->pfmkr.pf_to;

   /*
    * Copy locals into the co-expression.
    */
   for (i = 1; i <= nl; i++)
      *dsp++ = *dp++;

   /*
    * Push two null descriptors on the stack.
    */
   *dsp++ = nulldesc;
   *dsp++ = nulldesc;

   sblkp->es_sp = (word *)dsp - 1;

   }

/*
 * co_chng - high-level co-expression context switch.
 */
int co_chng(ncp, valloc, rsltloc, swtch_typ, first)
struct b_coexpr *ncp;
struct descrip *valloc; /* location of value being transmitted */
struct descrip *rsltloc;/* location to put result */
int swtch_typ;          /* A_Coact, A_Coret, A_Cofail, or A_MTEvent */
int first;
{
   static int coexp_act;     /* used to pass signal across activations */
                             /* back to whomever activates, if they care */

   register struct b_coexpr *ccp = k_current;

/* showcoexps();*/
/* showstack(); */

   switch(swtch_typ) {
      /*
       * A_MTEvent does not generate an event.
       */
      case A_MTEvent:
	 break;
      case A_Coact:
         EVValX(ncp,E_Coact);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
	 break;
      case A_Coret:
         EVValX(ncp,E_Coret);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
	 break;
      case A_Cofail:
         EVValX(ncp,E_Cofail);
	 if (!is:null(curpstate->eventmask) && ncp->program == curpstate) {
	    curpstate->parent->eventsource.dword = D_Coexpr;
	    BlkLoc(curpstate->parent->eventsource) = (union block *)ncp;
	    }
	 break;
      }


   /*
    * Determine if we need to transmit a value.
    */
   if (valloc != NULL) {

      /*
       * Determine if we need to dereference the transmitted value. 
       */
#ifdef CHECK
      if (Var(*valloc))
         retderef(valloc, (word *)argp, sp);
#endif
      if (ncp->tvalloc != NULL)
         *ncp->tvalloc = *valloc;
      }
   ncp->tvalloc = NULL;
   ccp->tvalloc = rsltloc;

   /*
    * Save state of current co-expression.
    */
   ccp->es_pfp = pfp;
   ccp->es_argp = argp;
   ccp->es_tend = tend;

   ccp->es_efp = efp;
   ccp->es_gfp = gfp;
   ccp->es_ipc = ipc;
   ccp->es_sp = sp;
   ccp->es_ilevel = ilevel;


      if (k_trace)
	 if (swtch_typ != A_MTEvent)
/*         cotrace(ccp, ncp, swtch_typ, valloc);*/

   /*
    * Establish state for new co-expression.
    */
   pfp = ncp->es_pfp;
   tend = ncp->es_tend;

   efp = ncp->es_efp;
   gfp = ncp->es_gfp;
   ipc = ncp->es_ipc;
   argp = ncp->es_argp;
   sp = ncp->es_sp;
   ilevel = (int)ncp->es_ilevel;

   /*
    * Enter the program state of the co-expression being activated
    */
   curpstate = ncp->program;
   k_current = ncp;


   /*
    * From here on out, A_MTEvent looks like a A_Coact.
    */
   if (swtch_typ == A_MTEvent)
      swtch_typ = A_Coact;

   coexp_act = swtch_typ;

   coswitch(ccp->cstate, ncp->cstate,first);

   return coexp_act;
   }



void dumpcoexp(char*s, struct b_coexpr *p) {
	int i;
	printf("Dump of coexpression %s at %p\n",s,p);
	printf("\ttitle=%ld\n",(long)p->title);
	printf("\tsize=%ld\n",(long)p->size);
	printf("\tid=%ld\n",(long)p->id);
	printf("\tnextstk=%p\n",p->nextstk);
	printf("\tprogram=%p\n",p->program);	
	printf("\tcstate[%d]\n",CStateSize);
	for (i = 0; i < CStateSize; ++i) {
		int w = p->cstate[i];
		printf("\t%p\t%x\n", &p->cstate[i],w);
	}	

	printf("\n----------\n");
	fflush(stdout);
}

/*
 * new_context - determine what function to call to execute the new
 *  co-expression; this completes the context switch.
 */
void new_context(void)
{
       interp(0, 0);
       syserr("interp() returned in new_context().");
}
