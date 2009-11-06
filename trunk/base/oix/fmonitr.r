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
   p->Alccoexp =
      ((Testb((word)(E_Coexpr),bits)) ? alccoexp_1:alccoexp_0);
   p->Alccset =
      ((Testb((word)(E_Cset), bits)) ? alccset_1 : alccset_0);
   p->Alcsegment =
      ((Testb((word)(E_Slots), bits)) ? alcsegment_1 : alcsegment_0);
   p->Alcreal =
      ((Testb((word)(E_Real), bits)) ? alcreal_1 : alcreal_0);
   p->Alcrecd =
      ((Testb((word)(E_Record), bits)) ? alcrecd_1 : alcrecd_0);
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
       p->GeneralAccess = general_access_1;
   } else {
       p->GeneralAccess = general_access_1;
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
       p->GeneralInvokef = general_invokef_1;
   } else {
       p->GeneralInvokef = general_invokef_0;
   }

   if ((Testb((word)(E_Objectcreate), bits)) ||
       (Testb((word)(E_Rcreate), bits)))
   {
       p->GeneralCall = general_call_1;
   } else {
       p->GeneralCall = general_call_0;
   }

#endif
}


/*
 * Prototypes.
 */


#define evforget()


char typech[MaxType+1];	/* output character for each type */

int noMTevents;			/* don't produce events in EVAsgn */


#if UNIX
/*
 * Global state used by EVTick()
 */
word oldsum = 0;
#endif					/* UNIX */




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
   }

