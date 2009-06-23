/*
 *  fmonitr.r -- event, EvGet
 *
 *   This file contains execution monitoring code, used only if EventMon
 *   (event monitoring) or some of its constituent events is defined.
 *   There used to be a separate virtual machine with all events defined,
 *   but the current setup allows specific events to be defined, and the
 *   source is moving towards a setup in which monitoring is unified into
 *   the main virtual machine.
 *
 *   The built-in functions are defined for all MultiThread interpreters.
 *
 *   When EventMon is undefined, most of the "MMxxxx" and "EVxxxx"
 *   entry points are defined as null macros in monitor.h.  See
 *   monitor.h for important definitions.
 */



void assign_event_functions(struct progstate *p, struct descrip cs)
{
   word *bits = BlkLoc(cs)->cset.bits;
   p->eventmask = cs;
#ifdef EventMon
   /*
    * Most instrumentation functions depend on a single event.
    */
   p->Cplist =
      ((Testb((word)(E_Lcreate), bits)) ? cplist_1 : cplist_0);
   p->Cpset =
      ((Testb((word)(E_Screate), bits)) ? cpset_1 : cpset_0);
   p->Cptable =
      ((Testb((word)(E_Tcreate), bits)) ? cptable_1 : cptable_0);
   p->Deref =
      ((Testb((word)(E_Deref), bits)) ? deref_1 : deref_0);
   p->Alcbignum =
      ((Testb((word)(E_Lrgint),bits)) ? alcbignum_1:alcbignum_0);
   p->Alccset =
      ((Testb((word)(E_Cset), bits)) ? alccset_1 : alccset_0);
   p->Alcsegment =
      ((Testb((word)(E_Slots), bits)) ? alcsegment_1 : alcsegment_0);
   p->Alcreal =
      ((Testb((word)(E_Real), bits)) ? alcreal_1 : alcreal_0);
   p->Alcrecd =
      ((Testb((word)(E_Record), bits)) ? alcrecd_1 : alcrecd_0);
   p->Alcrefresh =
      ((Testb((word)(E_Refresh), bits)) ? alcrefresh_1 : alcrefresh_0);
   p->Alcselem =
      ((Testb((word)(E_Selem), bits)) ? alcselem_1 : alcselem_0);
   p->Alcstr =
      ((Testb((word)(E_String), bits)) ? alcstr_1 : alcstr_0);
   p->Alcsubs =
      ((Testb((word)(E_Tvsubs), bits)) ? alcsubs_1 : alcsubs_0);
   p->Alctelem =
      ((Testb((word)(E_Telem), bits)) ? alctelem_1 : alctelem_0);
   p->Alctvtbl =
      ((Testb((word)(E_Tvtbl), bits)) ? alctvtbl_1 : alctvtbl_0);
   p->Dealcblk =
      ((Testb((word)(E_BlkDeAlc), bits)) ? dealcblk_1 : dealcblk_0);
   p->Dealcstr =
      ((Testb((word)(E_StrDeAlc), bits)) ? dealcstr_1 : dealcstr_0);
   p->Alcobject =
      ((Testb((word)(E_Object), bits)) ? alcobject_1 : alcobject_0);
   p->Alccast =
      ((Testb((word)(E_Cast), bits)) ? alccast_1 : alccast_0);
   p->Alcmethp =
      ((Testb((word)(E_Methp), bits)) ? alcmethp_1 : alcmethp_0);
   p->Alcucs =
      ((Testb((word)(E_Ucs), bits)) ? alcucs_1 : alcucs_0);

   /*
    * A few functions enable more than one event code.
    */
   p->Alchash =
      (((Testb((word)(E_Table), bits)) ||
	(Testb((word)(E_Set), bits)))
       ? alchash_1 : alchash_0);
   p->Reserve =
      (((Testb((word)(E_TenureString), bits)) ||
	(Testb((word)(E_TenureBlock), bits)))
       ? reserve_1 : reserve_0);

   /*
    * Multiple functions all triggered by same events
    */
   if ((Testb((word)(E_List), bits)) ||
       (Testb((word)(E_Lelem), bits))) {
      p->Alclist_raw = alclist_raw_1;
      p->Alclist = alclist_1;
      p->Alclstb = alclstb_1;
      }
   else {
      p->Alclist_raw = alclist_raw_0;
      p->Alclist = alclist_0;
      p->Alclstb = alclstb_0;
      }

   if ((Testb((word)(E_Aconv), bits)) ||
       (Testb((word)(E_Tconv), bits)) ||
       (Testb((word)(E_Nconv), bits)) ||
       (Testb((word)(E_Sconv), bits)) ||
       (Testb((word)(E_Fconv), bits))) {

      p->Cnvcset = cnv_cset_1;
      p->Cnvucs = cnv_ucs_1;
      p->Cnvint = cnv_int_1;
      p->Cnvreal = cnv_real_1;
      p->Cnvstr = cnv_str_1;
      p->Cnvtstr = cnv_tstr_1;
      }
   else {
      p->Cnvcset = cnv_cset_0;
      p->Cnvucs = cnv_ucs_0;
      p->Cnvint = cnv_int_0;
      p->Cnvreal = cnv_real_0;
      p->Cnvstr = cnv_str_0;
      p->Cnvtstr = cnv_tstr_0;
      }

   if ((Testb((word)(E_Objectref), bits)) ||
       (Testb((word)(E_Objectsub), bits)) ||
       (Testb((word)(E_Castref), bits)) ||
       (Testb((word)(E_Castsub), bits)) ||
       (Testb((word)(E_Classref), bits)) ||
       (Testb((word)(E_Classsub), bits)) ||
       (Testb((word)(E_Rref), bits)) ||
       (Testb((word)(E_Rsub), bits))) 
   {
       p->FieldAccess = field_access_1;
       p->InvokefAccess = invokef_access_1;
   } else {
       p->FieldAccess = field_access_0;
       p->InvokefAccess = invokef_access_0;
   }

   if ((Testb((word)(E_Ecall), bits)) ||
       (Testb((word)(E_Pcall), bits)) ||
       (Testb((word)(E_Objectcreate), bits)) ||
       (Testb((word)(E_Rcreate), bits)))
   {
       p->Invoke = invoke_1;
   } else {
       p->Invoke = invoke_0;
   }

   /*
    * interp() is the monster case:
    * We should replace 30 membership tests with a cset intersection.
    * Heck, we should redo the event codes so any bit in one
    * particular word means: "use the instrumented interp".
    */
   if (Testb((word)(E_Intcall), bits) ||
       Testb((word)(E_Fsusp), bits) ||
       Testb((word)(E_Osusp), bits) ||
       Testb((word)(E_Bsusp), bits) ||
       Testb((word)(E_Ocall), bits) ||
       Testb((word)(E_Ofail), bits) ||
       Testb((word)(E_Tick), bits) ||
       Testb((word)(E_Line), bits) ||
       Testb((word)(E_Fname), bits) ||
       Testb((word)(E_Opcode), bits) ||
       Testb((word)(E_Fcall), bits) ||
       Testb((word)(E_Prem), bits) ||
       Testb((word)(E_Erem), bits) ||
       Testb((word)(E_Intret), bits) ||
       Testb((word)(E_Psusp), bits) ||
       Testb((word)(E_Ssusp), bits) ||
       Testb((word)(E_Pret), bits) ||
       Testb((word)(E_Efail), bits) ||
       Testb((word)(E_Sresum), bits) ||
       Testb((word)(E_Fresum), bits) ||
       Testb((word)(E_Oresum), bits) ||
       Testb((word)(E_Eresum), bits) ||
       Testb((word)(E_Presum), bits) ||
       Testb((word)(E_Pfail), bits) ||
       Testb((word)(E_Ffail), bits) ||
       Testb((word)(E_Frem), bits) ||
       Testb((word)(E_Orem), bits) ||
       Testb((word)(E_Fret), bits) ||
       Testb((word)(E_Oret), bits)
       )
      p->Interp = interp_1;
   else
      p->Interp = interp_0;
#endif
}

/*
 * EvGet(eventmask, valuemask, flag) - user function for reading event streams.
 * Installs cset eventmask (and optional table valuemask) in the event source,
 * then activates it.
 * EvGet returns the code of the matched token.  These keywords are also set:
 *    &eventcode     token code
 *    &eventvalue    token value
 */

"evget(c,flag) - read through the next event token having a code matched "
" by cset c."

function{0,1} lang_Prog_get_event(cs,vmask,flag)
   if !def:cset(cs,*k_cset) then
      runerr(104,cs)
   if !is:null(vmask) then
      if !is:table(vmask) then
         runerr(124,vmask)

   body {
      tended struct descrip dummy;
      struct progstate *p = NULL;

      /*
       * Be sure an eventsource is available
       */
      if (!is:coexpr(curpstate->eventsource))
         runerr(118,curpstate->eventsource);
      if (!is:null(vmask))
         BlkLoc(curpstate->eventsource)->coexpr.program->valuemask = vmask;

      /*
       * If our event source is a child of ours, assign its event mask.
       */
      p = BlkLoc(curpstate->eventsource)->coexpr.program;
      if (p->parent == curpstate) {
	 if (BlkLoc(p->eventmask) != BlkLoc(cs)) {
	    assign_event_functions(p, cs);
	    }
	 }

      /*
       * Loop until we read an event allowed.
       */
      while (1) {
         /*
          * Activate the event source to produce the next event.
          */
	 dummy = cs;
	 if (mt_activate(&dummy, &curpstate->eventcode,
			 (struct b_coexpr *)BlkLoc(curpstate->eventsource)) ==
	     A_Cofail) fail;
	 deref(&curpstate->eventcode, &curpstate->eventcode);
	 if (!is:string(curpstate->eventcode) ||
	     StrLen(curpstate->eventcode) != 1) {
	    /*
	     * this event is out-of-band data; return or reject it
	     * depending on whether flag is null.
	     */
	    if (!is:null(flag))
	       return curpstate->eventcode;
	    else continue;
	    }

#if E_Cofail || E_Coret
	 switch(*StrLoc(curpstate->eventcode)) {
	 case E_Cofail: case E_Coret: {
	    if (BlkLoc(curpstate->eventsource)->coexpr.id == 1) {
	       fail;
	       }
	    }
	    }
#endif					/* E_Cofail || E_Coret */

	 return curpstate->eventcode;
	 }
      }
end

/*
 * Prototypes.
 */


#define evforget()


char typech[MaxType+1];	/* output character for each type */

int noMTevents;			/* don't produce events in EVAsgn */

#if UNIX && E_Tick
union tickerdata ticker;
unsigned long oldtick;
#endif					/* UNIX && E_Tick */

#if UNIX
/*
 * Global state used by EVTick()
 */
word oldsum = 0;
#endif					/* UNIX */


static char scopechars[] = "+:^-";

/*
 * Special event function for E_Assign & E_Deref;
 * allocates out of monitor's heap.
 */
void EVVariable(dptr dx, int eventcode)
{
   int i;
   dptr procname = NULL;
   struct progstate *parent = curpstate->parent;
   struct region *rp = curpstate->stringregion;

   if (dx == argp) {
      /*
       * we are dereferencing a result, argp is not the procedure.
       * is this a stable state to leave the TP in?
       */
      actparent(eventcode);
      return;
      }

   procname = &((&BlkLoc(*argp)->proc)->name);
   /*
    * call get_name, allocating out of the monitor if necessary.
    */
   curpstate->stringregion = parent->stringregion;
   parent->stringregion = rp;
   noMTevents++;
   i = get_name(dx,&(parent->eventval));

   if (i == GlobalName) {
      if (reserve(Strings, StrLen(parent->eventval) + 1) == NULL) {
	 fprintf(stderr, "failed to reserve %ld bytes for global\n",
		 (long)StrLen(parent->eventval)+1);
	 syserr("monitoring out-of-memory error");
	 }
      StrLoc(parent->eventval) =
	 alcstr(StrLoc(parent->eventval), StrLen(parent->eventval));
      alcstr("+",1);
      StrLen(parent->eventval)++;
      }
   else if ((i == StaticName) || (i == LocalName) || (i == ParamName)) {
      if (!reserve(Strings, StrLen(parent->eventval) + StrLen(*procname) + 1)) {
	 fprintf(stderr,"failed to reserve %ld bytes for %d, %ld+%ld\n",
                 (long)StrLen(parent->eventval)+(long)StrLen(*procname)+1, i,
		 (long)StrLen(parent->eventval), (long)StrLen(*procname));
	 syserr("monitoring out-of-memory error");
	 }
      StrLoc(parent->eventval) =
	 alcstr(StrLoc(parent->eventval), StrLen(parent->eventval));
      alcstr(scopechars+i,1);
      alcstr(StrLoc(*procname), StrLen(*procname));
      StrLen(parent->eventval) += StrLen(*procname) + 1;
      }
   else if (i == Failed) {
      /* parent->eventval = *dx; */
      }
   else if (i == Error) {
      syserr("get_name error in EVVariable");
      }

   parent->stringregion = curpstate->stringregion;
   curpstate->stringregion = rp;
   noMTevents--;
   actparent(eventcode);
}


/*
 *  EVInit() - initialization.
 */

void EVInit()
   {
   int i;

   /*
    * Initialize the typech array, which is used if either file-based
    * or MT-based event monitoring is enabled.
    */

   for (i = 0; i <= MaxType; i++)
      typech[i] = '?';	/* initialize with error character */

#ifdef EventMon
   typech[T_Lrgint]  = E_Lrgint;	/* long integer */
   typech[T_Real]    = E_Real;		/* real number */
   typech[T_Cset]    = E_Cset;		/* cset */
   typech[T_Record]  = E_Record;	/* record block */
   typech[T_Tvsubs]  = E_Tvsubs;	/* substring trapped variable */
   typech[T_List]    = E_List;		/* list header block */
   typech[T_Lelem]   = E_Lelem;		/* list element block */
   typech[T_Table]   = E_Table;		/* table header block */
   typech[T_Telem]   = E_Telem;		/* table element block */
   typech[T_Tvtbl]   = E_Tvtbl;		/* table elem trapped variable*/
   typech[T_Set]     = E_Set;		/* set header block */
   typech[T_Selem]   = E_Selem;		/* set element block */
   typech[T_Slots]   = E_Slots;		/* set/table hash slots */
   typech[T_Coexpr]  = E_Coexpr;	/* co-expression block (static) */
   typech[T_Refresh] = E_Refresh;	/* co-expression refresh block */
   typech[T_Object]  = E_Object;        /* object */
   typech[T_Cast ]   = E_Cast;          /* cast */
   typech[T_Methp]   = E_Methp;         /* method pointer */
   typech[T_Ucs]     = E_Ucs;	        /* ucs block */
#endif

   /*
    * codes used elsewhere but not shown here:
    *    in the static region: E_Alien = alien (malloc block)
    *    in the static region: E_Free = free
    *    in the string region: E_String = string
    */

#if UNIX
   /*
    * Call profil(2) to enable program counter profiling.  We use the smallest
    *  allowable scale factor in order to minimize the number of counters;
    *  we assume that the text of iconx does not exceed 256K and so we use
    *  four bins.  One of these four bins will be incremented every system
    *  clock tick (typically 4 to 20 ms).
    *
    *  Take your local profil(2) man page with a grain of salt.  All the
    *  systems we tested really maintain 16-bit counters despite what the
    *  man pages say.
    *  Some also say that a scale factor of two maps everything to one counter;
    *  that is believed to be a no-longer-correct statement dating from the
    *  days when the maximum program size was 64K.
    *
    *  The reference to EVInit below just obtains an arbitrary address within
    *  the text segment.
    */
#ifdef HaveProfil
   profil(ticker.s, sizeof(ticker.s), (int) EVInit & ~0x3FFFF, 2);
#endif					/* HaveProfil*/
#endif					/* UNIX */

   }


#ifdef EventMon

/*
 * mmrefresh() - redraw screen, initially or after garbage collection.
 */

void mmrefresh()
{
    char *p = NULL;
    word n;

    /*
     * If the monitor is asking for E_EndCollect events, then it
     * can handle these memory allocation "redraw" events.
     */
    if (!is:null(curpstate->eventmask) &&
        Testb((word)(E_EndCollect), BlkLoc(curpstate->eventmask)->cset.bits)) {
        for (p = blkbase; p < blkfree; p += n) {
            n = BlkSize(p);
            RealEVVal(n, typech[(int)BlkType(p)]);	/* block region */
        }
        EVVal(DiffPtrs(strfree, strbase), E_String);	/* string region */
    }
}

#endif
