/*
 * File: ralc.r
 *  Contents: allocation routines
 */

/*
 * Prototypes.
 */
static struct region *newregion	(uword nbytes, uword stdsize);
static void check_stack_usage(void);

/*
 * AlcBlk - allocate a block.
 */
#begdef AlcBlk(var, struct_nm, t_code, nbytes, event)
{
   EVVal(nbytes, event);

   /*
    * Ensure that there is enough room in the block region.
    */
   if (DiffPtrs(blkend,blkfree) < nbytes && !reserve(Blocks, nbytes))
      return NULL;

   /*
    * Decrement the free space in the block region by the number of bytes
    *  allocated and return the address of the first byte of the allocated
    *  block.
    */
   blktotal += nbytes;
   var = (struct struct_nm *)blkfree;
   blkfree += nbytes;
   var->title = t_code;
}
#enddef

/*
 * AlcFixBlk - allocate a fixed length block.
 */
#define AlcFixBlk(var, struct_nm, t_code, event)                      \
   AlcBlk(var, struct_nm, t_code, sizeof(struct struct_nm), event)

/*
 * AlcVarBlk - allocate a variable-length block.
 */
#begdef AlcVarBlk(var, struct_nm, t_code, n_desc, event)
   {
   uword size;

   /*
    * Variable size blocks are declared with one descriptor, thus
    *  we need add in only n_desc - 1 descriptors.
    */
   size = sizeof(struct struct_nm) + (n_desc - 1) * sizeof(struct descrip);
   AlcBlk(var, struct_nm, t_code, size, event)
   var->blksize = size;
   }
#enddef


/*
 * Alc2Blks - allocate two blocks together.
 */
#begdef Alc2Blks(var1, struct_nm1, t_code1, nbytes1, event1, \
                 var2, struct_nm2, t_code2, nbytes2, event2)
{
   uword nbytes = nbytes1 + nbytes2;

   EVVal(nbytes1, event1);
   EVVal(nbytes2, event2);

   /*
    * Ensure that there is enough room in the block region.
    */
   if (DiffPtrs(blkend,blkfree) < nbytes && !reserve(Blocks, nbytes))
      return NULL;

   blktotal += nbytes;
   var1 = (struct struct_nm1 *)blkfree;
   blkfree += nbytes1;
   var1->title = t_code1;
   var2 = (struct struct_nm2 *)blkfree;
   blkfree += nbytes2;
   var2->title = t_code2;
}
#enddef

#begdef alcbignum_macro(f,e_lrgint)
/*
 * alcbignum - allocate an n-digit bignum in the block region
 */

struct b_bignum *f(word n)
   {
   struct b_bignum *blk;
   uword size;

   size = sizeof(struct b_bignum) + ((n - 1) * sizeof(DIGIT));
   /* ensure whole number of words allocated */
   size = (size + WordSize - 1) & -WordSize;

   AlcBlk(blk, b_bignum, T_Lrgint, size, e_lrgint);
   blk->blksize = size;
   blk->msd = blk->sign = 0;
   blk->lsd = n - 1;
   return blk;
   }
#enddef
alcbignum_macro(alcbignum_0,0)
alcbignum_macro(alcbignum_1,E_Lrgint)

#begdef alccoexp_macro(f,e_coexpr)
/*
 * alccoexp - allocate a co-expression block; called via 
 * create or refresh - for loading progs, see alcprog below.
 */
struct b_coexpr *f()
{
   struct b_coexpr *blk;
   static int check_count;

   if (++check_count % 1024 == 0)
       check_stack_usage();

   AlcFixBlk(blk, b_coexpr, T_Coexpr, e_coexpr)
   blk->id = coexp_ser++;
   blk->sp = 0;
   blk->activator = 0;
   return blk;
}
#enddef
alccoexp_macro(alccoexp_0,0)
alccoexp_macro(alccoexp_1,E_Coexpr)


/*
 * Allocate memory for a loaded program.  The memory allocated
 * consists of two parts, namely the progstate struct and the icode.
 * 
 * Note that this memory is never freed.
 */
struct progstate *alcprog(word icodesize)
{
   struct progstate *prog;
   char *icode;
   word size = icodesize + sizeof(struct progstate);

   EVVal(size, E_Prog);

   /*
    * Allocate the two parts.
    */
   prog = calloc(sizeof(struct progstate), 1);
   if (!prog)
       return 0;
   icode = malloc(icodesize);
   if (!icode) {
       free(prog);
       return 0;
   }
   prog->Code = icode;
   return prog;
}


#begdef alccset_macro(f, e_cset)
/*
 * alccset - allocate a cset in the block region.
 */

struct b_cset *f(word n)
   {
   struct b_cset *blk;
   uword size;

   size = sizeof(struct b_cset) + ((n - 1) * sizeof(struct b_cset_range));
   AlcBlk(blk, b_cset, T_Cset, size, e_cset);
   blk->blksize = size;

   return blk;
   }
#enddef
alccset_macro(alccset_0,0)
alccset_macro(alccset_1,E_Cset)


#begdef alchash_macro(f, e_table, e_set)
/*
 * alchash - allocate a hashed structure (set or table header) in the block
 *  region.
 */
union block *f(int tcode)
   {
   int i;
   struct b_set *ps;
   struct b_table *pt;

   if (tcode == T_Table) {
      AlcFixBlk(pt, b_table, T_Table, e_table);
      pt->defvalue = nulldesc;
      ps = (struct b_set *)pt;
      ps->id = table_ser++;
      }
   else {	/* tcode == T_Set */
      AlcFixBlk(ps, b_set, T_Set, e_set);
      ps->id = set_ser++;
      }
   ps->size = 0;
   ps->mask = 0;
   for (i = 0; i < HSegs; i++)
      ps->hdir[i] = NULL;
   return (union block *)ps;
   }
#enddef

alchash_macro(alchash_0,0,0)
alchash_macro(alchash_1,E_Table,E_Set)

#begdef alcsegment_macro(f,e_slots)
/*
 * alcsegment - allocate a slot block in the block region.
 */

struct b_slots *f(word nslots)
   {
   uword size;
   struct b_slots *blk;

   size = sizeof(struct b_slots) + WordSize * (nslots - HSlots);
   AlcBlk(blk, b_slots, T_Slots, size, e_slots);
   blk->blksize = size;
   while (--nslots >= 0)
      blk->hslots[nslots] = NULL;
   return blk;
   }
#enddef

alcsegment_macro(alcsegment_0,0)
alcsegment_macro(alcsegment_1,E_Slots)

/*
 * Check that we're not asking for a list element block that will have
 * more descriptors than can be addressed with a StructVar.
 */
#begdef CheckSlots(nslots)
{
#if WordBits == 32
if (nslots >= (OffsetMask - sizeof(struct b_lelem) / WordSize) / 2)
    return NULL;
#endif
}
#enddef

#begdef alclist_raw_macro(f,e_list,e_lelem)
/*
 * alclist - allocate a list header block in the block region.
 *  A corresponding list element block is also allocated.
 *  Forces a g.c. if there's not enough room for the whole list.
 *  The "alclstb" code inlined so as to avoid duplicated initialization.
 *
 * alclist_raw() - as per alclist(), except initialization is left to
 * the caller, who promises to initialize first n==size slots w/o allocating.
 */

struct b_list *f(uword size, uword nslots)
   {
   uword i = sizeof(struct b_lelem)+(nslots-1)*sizeof(struct descrip);
   struct b_list *blk;
   struct b_lelem *lblk;

   CheckSlots(nslots);

   Alc2Blks(blk, b_list, T_List, sizeof(struct b_list), e_list,
            lblk, b_lelem, T_Lelem, i, e_lelem)
   blk->size = size;
   blk->id = list_ser++;
   blk->listhead = blk->listtail = (union block *)lblk;
   blk->changecount = 0;

   lblk->blksize = i;
   lblk->nslots = nslots;
   lblk->first = 0;
   lblk->nused = size;
   lblk->listprev = lblk->listnext = (union block *)blk;
   /*
    * Set all elements beyond size to &null.
    */
   for (i = size; i < nslots; i++)
      lblk->lslots[i] = nulldesc;
   return blk;
   }
#enddef

alclist_raw_macro(alclist_raw_0,0,0)
alclist_raw_macro(alclist_raw_1,E_List,E_Lelem)

#begdef alclist_macro(f,e_list,e_lelem)

struct b_list *f(uword size, uword nslots)
{
   uword i = sizeof(struct b_lelem)+(nslots-1)*sizeof(struct descrip);
   struct b_list *blk;
   struct b_lelem *lblk;

   CheckSlots(nslots);

   Alc2Blks(blk, b_list, T_List, sizeof(struct b_list), e_list,
            lblk, b_lelem, T_Lelem, i, e_lelem)
   blk->size = size;
   blk->id = list_ser++;
   blk->listhead = blk->listtail = (union block *)lblk;
   blk->changecount = 0;

   lblk->blksize = i;
   lblk->nslots = nslots;
   lblk->first = 0;
   lblk->nused = size;
   lblk->listprev = lblk->listnext = (union block *)blk;
   /*
    * Set all elements to &null.
    */
   for (i = 0; i < nslots; i++)
      lblk->lslots[i] = nulldesc;
   return blk;
   }
#enddef

alclist_macro(alclist_0,0,0)
alclist_macro(alclist_1,E_List,E_Lelem)

#begdef alclstb_macro(f,e_lelem)
/*
 * alclstb - allocate a list element block in the block region.
 */

struct b_lelem *f(uword nslots)
   {
   struct b_lelem *blk;
   word i;

   AlcVarBlk(blk, b_lelem, T_Lelem, nslots, e_lelem)
   blk->nslots = nslots;
   blk->first = 0;
   blk->nused = 0;
   blk->listprev = NULL;
   blk->listnext = NULL;
   /*
    * Set all elements to &null.
    */
   for (i = 0; i < nslots; i++)
      blk->lslots[i] = nulldesc;
   return blk;
   }
#enddef

alclstb_macro(alclstb_0,0)
alclstb_macro(alclstb_1,E_Lelem)

#if !RealInDesc

#begdef alcreal_macro(f,e_real)
/*
 * alcreal - allocate a real value in the block region.
 */

struct b_real *f(double val)
   {
   struct b_real *blk;

   AlcFixBlk(blk, b_real, T_Real, e_real)
   BSetReal(val, *blk);

   return blk;
   }
#enddef

alcreal_macro(alcreal_0,0)
alcreal_macro(alcreal_1,E_Real)

#endif  /* RealInDesc */

#begdef alcrecd_macro(f,e_record)
/*
 * alcrecd - allocate record with nflds fields in the block region.
 */

struct b_record *f(struct b_constructor *con)
   {
   struct b_record *blk;
   int i, nflds = con->n_fields;

   AlcVarBlk(blk, b_record, T_Record, nflds, e_record)
   blk->constructor = con;
   blk->id = ++con->instance_ids;
   /*
    * Set all fields to null value.
    */
   for (i = 0; i < nflds; ++i)
       blk->fields[i] = nulldesc;
   return blk;
   }
#enddef

alcrecd_macro(alcrecd_0,0)
alcrecd_macro(alcrecd_1,E_Record)


#begdef alcobject_macro(f,e_object)
/*
 * alcobject - allocate object instance of type class
 */

struct b_object *f(struct b_class *class)
   {
   struct b_object *blk;
   int i, nflds = class->n_instance_fields;
   AlcVarBlk(blk, b_object, T_Object, nflds, e_object);
   blk->class = class;
   blk->id = ++class->instance_ids;
   blk->init_state = Uninitialized;
   /*
    * Set all fields to null value.
    */
   for (i = 0; i < nflds; ++i)
       blk->fields[i] = nulldesc;
   return blk;
   }
#enddef

alcobject_macro(alcobject_0,0)
alcobject_macro(alcobject_1,E_Object)


#begdef alcmethp_macro(f,e_methp)
/*
 * alcmethp - allocate a methp value in the block region.
 */

struct b_methp *f()
   {
   struct b_methp *blk;

   AlcFixBlk(blk, b_methp, T_Methp, e_methp)
   blk->id = methp_ser++;
   blk->object = 0;
   blk->proc = 0;
   return blk;
   }
#enddef

alcmethp_macro(alcmethp_0,0)
alcmethp_macro(alcmethp_1,E_Methp)



#begdef alcweakref_macro(f,e_weakref)
/*
 * alcweakref - allocate a weakref value in the block region.
 */

struct b_weakref *f()
   {
   struct b_weakref *blk;

   AlcFixBlk(blk, b_weakref, T_Weakref, e_weakref)
   blk->id = weakref_ser++;
   blk->chain = 0;
   blk->val = nulldesc;
   return blk;
   }
#enddef

alcweakref_macro(alcweakref_0,0)
alcweakref_macro(alcweakref_1,E_Weakref)



#begdef alcucs_macro(f,e_ucs)
/*
 * alcucs - allocate a ucs value in the block region.
 */

struct b_ucs *f(int n)
   {
   struct b_ucs *blk;
   uword size;
   size = sizeof(struct b_ucs) + ((n - 1) * sizeof(word));
   AlcBlk(blk, b_ucs, T_Ucs, size, e_ucs);
   blk->blksize = size;
   blk->utf8 = nulldesc;
   return blk;
   }
#enddef

alcucs_macro(alcucs_0,0)
alcucs_macro(alcucs_1,E_Ucs)



#begdef alcselem_macro(f,e_selem)
/*
 * alcselem - allocate a set element block.
 */
struct b_selem *f()
   {
   struct b_selem *blk;

   AlcFixBlk(blk, b_selem, T_Selem, e_selem)
   blk->clink = NULL;
   blk->hashnum = 0;
   blk->setmem = nulldesc;
   return blk;
   }
#enddef

alcselem_macro(alcselem_0,0)
alcselem_macro(alcselem_1,E_Selem)

#begdef alcstr_macro(f,e_string)
/*
 * alcstr - allocate a string in the string space.
 */

char *f(char *s, word slen)
   {
   tended struct descrip ts;
   char *d;
   char *ofree;

#if e_string
    EVVal(slen, e_string);
#endif					/* E_String */

   /*
    * Make sure there is enough room in the string space.
    */
   if (DiffPtrs(strend,strfree) < slen) {
      if (s) MakeStr(s, slen, &ts);
      if (!reserve(Strings, slen))
         return NULL;
      if (s) s = StrLoc(ts);
   }

   strtotal += slen;

   /*
    * Copy the string into the string space, saving a pointer to its
    *  beginning.  Note that s may be null, in which case the space
    *  is still to be allocated but nothing is to be copied into it.
    */
   ofree = d = strfree;
   if (s) {
      while (slen-- > 0)
         *d++ = *s++;
      }
   else
      d += slen;

   strfree = d;
   return ofree;
   }
#enddef

alcstr_macro(alcstr_0,0)
alcstr_macro(alcstr_1,E_String)

#begdef alcsubs_macro(f, e_tvsubs)
/*
 * alcsubs - allocate a substring trapped variable in the block region.
 */

struct b_tvsubs *f()
{
    struct b_tvsubs *blk;
    AlcFixBlk(blk, b_tvsubs, T_Tvsubs, e_tvsubs)
    blk->sslen = blk->sspos = 0;
    blk->ssvar = nulldesc;
    return blk;
}
#enddef

alcsubs_macro(alcsubs_0,0)
alcsubs_macro(alcsubs_1,E_Tvsubs)

#begdef alctelem_macro(f, e_telem)
/*
 * alctelem - allocate a table element block in the block region.
 */

struct b_telem *f()
   {
   struct b_telem *blk;

   AlcFixBlk(blk, b_telem, T_Telem, e_telem)
   blk->clink = NULL;
   blk->hashnum = 0;
   blk->tref = nulldesc;
   blk->tval = nulldesc;
   return blk;
   }
#enddef

alctelem_macro(alctelem_0,0)
alctelem_macro(alctelem_1,E_Telem)

#begdef alctvtbl_macro(f,e_tvtbl)
/*
 * alctvtbl - allocate a table element trapped variable block in the block
 *  region.
 */

struct b_tvtbl *f()
{
    struct b_tvtbl *blk;
    AlcFixBlk(blk, b_tvtbl, T_Tvtbl, e_tvtbl)
    blk->clink = NULL;
    blk->hashnum = 0;
    blk->tref = nulldesc;
    return blk;
}
#enddef

alctvtbl_macro(alctvtbl_0,0)
alctvtbl_macro(alctvtbl_1,E_Tvtbl)

#begdef dealcblk_macro(f,e_blkdealc)
/*
 * dealcblk - return a block to the heap.
 *
 * The block must be the one that is at the very end of the current
 * block region, ie it must just have been allocated, without any
 * intervening allocation before this call.
 */
void f (union block *bp)
{
   word nbytes = BlkSize(bp);
   if ((char *)bp + nbytes != blkfree)
       syserr("Attempt to dealcblk, but block not at end of current block region");
   blkfree = (char *)bp;
   blktotal -= nbytes;
   EVVal(-nbytes, e_blkdealc);
}
#enddef

dealcblk_macro(dealcblk_0,0)
dealcblk_macro(dealcblk_1,E_BlkDeAlc)



#begdef dealcstr_macro(f,e_strdealc)
/*
 * Return a string (or part of it) just allocated at the end of the
 * current string region.
 */
void f (char *p)
{
    word nbytes;
    if (!InRange(strbase, p, strfree + 1))
        syserr("Attempt to dealcstr, but pointer not in current string region");
    nbytes = DiffPtrs(strfree, p);
    strtotal -= nbytes;
    strfree = p;
    EVVal(-nbytes, E_StrDeAlc);
}
#enddef

dealcstr_macro(dealcstr_0,0)
dealcstr_macro(dealcstr_1,E_StrDeAlc)



#begdef reserve_macro(f,e_tenure)
/*
 * reserve -- ensure space in either string or block region.
 */
char *f(int region, uword nbytes)
{
   struct region **pcurr, *curr, *rp;
   uword want, newsize;

   if (region == Strings)
      pcurr = &curstring;
   else
      pcurr = &curblock;
   curr = *pcurr;

   /*
    * Check for space available now.
    */
   if (DiffPtrs(curr->end, curr->free) >= nbytes)
      return curr->free;		/* quick return: current region is OK */

   /*
    * Set "curr" to point to newest region.
    */
   while (curr->next)
      curr = curr->next;

   /*
    * Check all regions for availability of nbytes.
    */
   for (rp = curr; rp; rp = rp->prev) {
       if (DiffPtrs(rp->end, rp->free) >= nbytes) {
           *pcurr = rp;			/* switch regions */
           return rp->free;
       }
   }

   /*
    * Need to collect garbage.  To reduce thrashing, set a minimum requirement
    *  of 10% of the size of the newest region, and collect regions until that
    *  amount of free space appears in one of them.
    */
   want = (curr->size / 100) * memcushion;
   if (want < nbytes)
      want = nbytes;

   for (rp = curr; rp; rp = rp->prev) {
      if (rp->size >= want) {	/* if large enough to possibly succeed */
         *pcurr = rp;
         collect(region);
         if (DiffPtrs(rp->end, rp->free) >= want)
            return rp->free;
      }
   }

   /*
    * That didn't work.  Allocate a new region with a size based on the
    * newest previous region.
    */
   newsize = (curr->size / 100) * memgrowth;
   if (newsize < nbytes)
      newsize = nbytes;
   if (newsize < MinAbrSize)
      newsize = MinAbrSize;

   if ((rp = newregion(nbytes, newsize)) != 0) {
      rp->prev = curr;
      rp->next = NULL;
      curr->next = rp;
      rp->Gnext = curr;
      rp->Gprev = curr->Gprev;
      if (curr->Gprev) curr->Gprev->Gnext = rp;
      curr->Gprev = rp;
      *pcurr = rp;
      EVVal((word)region,e_tenure);
      return rp->free;
   }

   /*
    * Allocation failed.  Try to continue by satisfying the original request of nbytes.
    */
   for (rp = curr; rp; rp = rp->prev) {
       if (DiffPtrs(rp->end, rp->free) >= nbytes) {
           *pcurr = rp;
           return rp->free;
       }
   }
   for (rp = curr; rp; rp = rp->prev) {
         /* if not collected earlier and if large enough to possibly succeed */
       if (rp->size < want && rp->size >= nbytes) {
           *pcurr = rp;
           collect(region);
           if (DiffPtrs(rp->end, rp->free) >= nbytes)
               return rp->free;
       }
   }

   /*
    * All attempts failed.
    */
   return 0;
}
#enddef

reserve_macro(reserve_0,0)
reserve_macro(reserve_1,E_Tenure)

/*
 * newregion - try to malloc a new region and tenure the old one,
 *  backing off if the requested size fails.
 */
static struct region *newregion(uword nbytes, uword stdsize)
{
   uword minSize = MinAbrSize;
   struct region *rp;

   if (nbytes > minSize)
      minSize = nbytes;

   rp = malloc(sizeof(struct region));
   if (rp) {
      rp->size = stdsize;
      rp->compacted = 0;
      if (rp->size < nbytes)
         rp->size = Max(nbytes+stdsize, nbytes);
      do {
         rp->free = rp->base = malloc(rp->size);
         if (rp->free != NULL) {
            rp->end = rp->base + rp->size;
            return rp;
            }
         rp->size = (rp->size + nbytes)/2 - 1;
         }
      while (rp->size >= minSize);
      free(rp);
      }
   return NULL;
}

/*
 * This function is called regularly during co-expression allocation
 * to ensure that too much unreferenced stack is collected.  This
 * would only be needed for programs that create a very large number
 * of co-expressions compared to other block types.
 */

uword stacklim;
word stackcushion = StackCushion;

static void check_stack_usage()
{
    uword total_stackcurr;
    struct progstate *prog;

    /* Calculate total stack allocated in all progs */
    total_stackcurr = 0;
    for (prog = progs; prog; prog = prog->next)
        total_stackcurr += prog->stackcurr;

    /* Check if level exceeded */
    if (total_stackcurr <= stacklim)
        return;

    /* Do a collection - this will release all unreferenced stack
     * frames in all regions */
    collect(Stack);

    /* Recalculate total stack now allocated */
    total_stackcurr = 0;
    for (prog = progs; prog; prog = prog->next)
        total_stackcurr += prog->stackcurr;

    /* Now total_stackcurr shows how much referenced stack use
     * remains.  To prevent thrashing, don't collect again until at
     * least stackcushion % of that amount is in use.
     */
    stacklim = Max(stacklim, stackcushion * (total_stackcurr / 100));
}

struct p_frame *alc_p_frame(struct p_proc *pb, struct frame_vars *fvars)
{
    struct p_frame *p;
    char *t;
    int i, size, lsize, ndesc;
    size = sizeof(struct p_frame) +
        pb->nclo * sizeof(struct frame *) +
        pb->ntmp * sizeof(struct descrip) +
        pb->nlab * sizeof(word *) + 
        pb->nmark * sizeof(struct frame *);
    ndesc = pb->ndynam + pb->nparam;
    lsize = sizeof(struct frame_vars) + (ndesc - 1) * sizeof(struct descrip);
    if (!fvars && !pb->creates && ndesc)
        p = malloc(size + lsize);
    else
        p = malloc(size);
    if (!p)
        return 0;
    p->size = size;

    t = (char *)(p + 1);
    if (pb->nclo) {
        p->clo = (struct frame **)t;
        for (i = 0; i < pb->nclo; ++i)
            p->clo[i] = 0;
        t += pb->nclo * sizeof(struct frame *);
    } else
        p->clo = 0;
    if (pb->ntmp) {
        p->tmp = (dptr)t;
        for (i = 0; i < pb->ntmp; ++i)
            p->tmp[i] = nulldesc;
        t += pb->ntmp * sizeof(struct descrip);
    } else
        p->tmp = 0;
    if (pb->nlab) {
        p->lab = (word **)t;
        for (i = 0; i < pb->nlab; ++i)
            p->lab[i] = 0;
        t += pb->nlab * sizeof(word *);
    } else
        p->lab = 0;
    if (pb->nmark) {
        p->mark = (struct frame **)t;
        for (i = 0; i < pb->nmark; ++i)
            p->mark[i] = 0;
        t += pb->nmark * sizeof(struct frame *);
    } else
        p->mark = 0;
    p->type = P_Frame;
    p->lhs = 0;
    p->failure_label = 0;
    p->rval = 0;
    p->proc = pb;
    p->parent_sp = 0;
    p->exhausted = 0;
    p->ipc = pb->icode;
    p->curr_inst = 0;
    p->caller = 0;
    if (fvars)
        ++fvars->refcnt;
    else if (ndesc) {
        if (pb->creates) {
            fvars = malloc(lsize);
            if (!fvars) {
                free(p);
                return 0;
            }
        } else  /* !fvars && ndesc && !pb->creates => frame_vars allocated above */
            fvars = (struct frame_vars *)t;
        curpstate->stackcurr += lsize;
        fvars->size = lsize;
        fvars->creator = curpstate;
        for (i = 0; i < ndesc; ++i)
            fvars->desc[i] = nulldesc;
        fvars->desc_end = fvars->desc + ndesc;
        fvars->refcnt = 1;
        fvars->seen = 0;
    } /* else just leave fvars == 0 */
    curpstate->stackcurr += size;
    p->creator = curpstate;
    p->fvars = fvars;
    return p;
}

struct c_frame *alc_c_frame(struct c_proc *pb, int nargs)
{
    struct c_frame *p;
    char *t;
    int size, i;
    size = pb->framesize + (nargs + pb->ntend) * sizeof(struct descrip);
    p = malloc(size);
    if (!p)
        return 0;
    curpstate->stackcurr += size;
    p->size = size;
    p->creator = curpstate;
    p->type = C_Frame;
    p->lhs = 0;
    p->proc = pb;
    p->parent_sp = 0;
    p->failure_label = 0;
    p->rval = 0;
    p->exhausted = 0;
    p->pc = 0;
    p->nargs = nargs;
    t = (char *)p + pb->framesize;
    if (nargs) {
        p->args = (dptr)t;
        for (i = 0; i < nargs; ++i)
            p->args[i] = nulldesc;
        t += nargs * sizeof(struct descrip);
    } else
        p->args = 0;
    if (pb->ntend) {
        p->tend = (dptr)t;
        for (i = 0; i < pb->ntend; ++i)
            p->tend[i] = nulldesc;
    } else
        p->tend = 0;
    return p;
}

void free_frame(struct frame *f)
{
    switch (f->type) {
        case C_Frame: {
            f->creator->stackcurr -= f->size;
            free(f);
            break;
        }
        case P_Frame: {
            struct frame_vars *l = ((struct p_frame *)f)->fvars;
            f->creator->stackcurr -= f->size;
            if (l) {
                if (((struct p_frame *)f)->proc->creates) {
                    --l->refcnt;
                    if (l->refcnt == 0) {
                        l->creator->stackcurr -= l->size;
                        free(l);
                    }
                } else {
                    if (l->refcnt != 1)
                        syserr("Expected refcnt==1 in free_frame");
                    l->creator->stackcurr -= l->size;
                }
            }
            free(f);
            break;
        }
        default:
            syserr("Unknown frame type");
    }
}
