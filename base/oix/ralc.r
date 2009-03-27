/*
 * File: ralc.r
 *  Contents: allocation routines
 */

/*
 * Prototypes.
 */
static struct region *findgap	(struct region *curr, word nbytes);
static struct region *newregion	(word nbytes, word stdsize);

extern word alcnum;



/*
 * AlcBlk - allocate a block.
 */
#begdef AlcBlk(var, struct_nm, t_code, nbytes)
{
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
#define AlcFixBlk(var, struct_nm, t_code)\
   AlcBlk(var, struct_nm, t_code, sizeof(struct struct_nm))

/*
 * AlcVarBlk - allocate a variable-length block.
 */
#begdef AlcVarBlk(var, struct_nm, t_code, n_desc)
   {
   uword size;

   /*
    * Variable size blocks are declared with one descriptor, thus
    *  we need add in only n_desc - 1 descriptors.
    */
   size = sizeof(struct struct_nm) + (n_desc - 1) * sizeof(struct descrip);
   AlcBlk(var, struct_nm, t_code, size)
   var->blksize = size;
   }
#enddef


#begdef alcbignum_macro(f,e_lrgint)
/*
 * alcbignum - allocate an n-digit bignum in the block region
 */

struct b_bignum *f(word n)
   {
   register struct b_bignum *blk;
   register uword size;

   size = sizeof(struct b_bignum) + ((n - 1) * sizeof(DIGIT));
   /* ensure whole number of words allocated */
   size = (size + WordSize - 1) & -WordSize;

   EVVal((word)size, e_lrgint);

   AlcBlk(blk, b_bignum, T_Lrgint, size);
   blk->blksize = size;
   blk->msd = blk->sign = 0;
   blk->lsd = n - 1;
   return blk;
   }
#enddef
alcbignum_macro(alcbignum_0,0)
alcbignum_macro(alcbignum_1,E_Lrgint)


/*
 * alccoexp - allocate a co-expression stack block.
 */

/*
 * If this is a new program being loaded, an icodesize>0 gives the
 * hdr.hsize and a stacksize to use; allocate
 * sizeof(progstate) + icodesize + mstksize
 * Otherwise (icodesize==0), allocate a normal stksize...
 * 
 * In either case, the size of the coexpression block consumes part
 * of the stack size.
 */
struct b_coexpr *alccoexp(icodesize, stacksize)
long icodesize, stacksize;

   {
   struct b_coexpr *ep;
   int size;

   if (icodesize > 0)
       size = stacksize + icodesize + sizeof(struct progstate);
   else
       size = stksize;

   EVVal(size, E_Coexpr);

   ep = malloc(size);

   /*
    * If malloc failed or there have been too many co-expression allocations
    * since a collection, attempt to free some co-expression blocks and retry.
    */

   if (ep == NULL || alcnum > AlcMax) {
      collect(Static);
      if (ep == NULL)
          ep = malloc(size);
   }
   if (ep == NULL)
      ReturnErrNum(305, NULL);

   stattotal += size;
   statcurr += size;
   alcnum++;		/* increment allocation count since last g.c. */

   ep->title = T_Coexpr;
   ep->es_activator = NULL;
   ep->size = 0;
   ep->es_efp = NULL;
   ep->es_pfp = NULL;
   ep->es_gfp = NULL;
   ep->es_argp = NULL;
   ep->tvalloc = NULL;
   ep->es_sp = NULL;
   ep->es_tend = NULL;
   ep->freshblk = NULL;
   ep->es_ipc.op = NULL;
   ep->es_ilevel = 0;

   /*
    * Initialize id, and program state to self for &main; 0 for others, which will
    * have that field set by co_init()
    */
   if (icodesize > 0) {
      ep->id = 1;
      ep->program = (struct progstate *)(ep + 1);
      memset(ep->program, 0, sizeof(struct progstate));
   } else {
      ep->id = coexp_ser++;
      ep->program = 0;
   }

   ep->nextstk = stklist;
   stklist = ep;

   return ep;
   }

#begdef alccset_macro(f, e_cset)
/*
 * alccset - allocate a cset in the block region.
 */

struct b_cset *f(word n)
   {
   register struct b_cset *blk;
   register uword size;

   size = sizeof(struct b_cset) + ((n - 1) * sizeof(struct b_cset_range));
   AlcBlk(blk, b_cset, T_Cset, size);
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
   register int i;
   register struct b_set *ps;
   register struct b_table *pt;

   if (tcode == T_Table) {
      EVVal(sizeof(struct b_table), e_table);
      AlcFixBlk(pt, b_table, T_Table);
      ps = (struct b_set *)pt;
      ps->id = table_ser++;
      }
   else {	/* tcode == T_Set */
      EVVal(sizeof(struct b_set), e_set);
      AlcFixBlk(ps, b_set, T_Set);
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
   register struct b_slots *blk;

   size = sizeof(struct b_slots) + WordSize * (nslots - HSlots);
   EVVal(size, e_slots);
   AlcBlk(blk, b_slots, T_Slots, size);
   blk->blksize = size;
   while (--nslots >= 0)
      blk->hslots[nslots] = NULL;
   return blk;
   }
#enddef

alcsegment_macro(alcsegment_0,0)
alcsegment_macro(alcsegment_1,E_Slots)

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
   register struct b_list *blk;
   register struct b_lelem *lblk;
   register word i;

   if (!reserve(Blocks, (word)(sizeof(struct b_list) + sizeof (struct b_lelem)
      + (nslots - 1) * sizeof(struct descrip)))) return NULL;
   EVVal(sizeof (struct b_list), e_list);
   EVVal(sizeof (struct b_lelem) + (nslots-1) * sizeof(struct descrip), e_lelem);
   AlcFixBlk(blk, b_list, T_List)
   AlcVarBlk(lblk, b_lelem, T_Lelem, nslots)
   blk->size = size;
   blk->id = list_ser++;
   blk->listhead = blk->listtail = (union block *)lblk;

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
   register word i = sizeof(struct b_lelem)+(nslots-1)*sizeof(struct descrip);
   register struct b_list *blk;
   register struct b_lelem *lblk;

   if (!reserve(Blocks, (word)(sizeof(struct b_list) + i))) return NULL;
   EVVal(sizeof (struct b_list), e_list);
   EVVal(i, e_lelem);
   AlcFixBlk(blk, b_list, T_List)
   AlcBlk(lblk, b_lelem, T_Lelem, i)
   blk->size = size;
   blk->id = list_ser++;
   blk->listhead = blk->listtail = (union block *)lblk;

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

#begdef alclstb_macro(f,t_lelem)
/*
 * alclstb - allocate a list element block in the block region.
 */

struct b_lelem *f(uword nslots, uword first, uword nused)
   {
   register struct b_lelem *blk;
   register word i;

   AlcVarBlk(blk, b_lelem, T_Lelem, nslots)
   blk->nslots = nslots;
   blk->first = first;
   blk->nused = nused;
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

#begdef alcreal_macro(f,e_real)
/*
 * alcreal - allocate a real value in the block region.
 */

struct b_real *f(double val)
   {
   register struct b_real *blk;

   EVVal(sizeof (struct b_real), e_real);
   AlcFixBlk(blk, b_real, T_Real)

#ifdef Double
/* access real values one word at a time */
   { int *rp, *rq;
     rp = (int *) &(blk->realval);
     rq = (int *) &val;
     *rp++ = *rq++;
     *rp   = *rq;
   }
#else                                   /* Double */
   blk->realval = val;
#endif                                  /* Double */

   return blk;
   }
#enddef

alcreal_macro(alcreal_0,0)
alcreal_macro(alcreal_1,E_Real)

#begdef alcrecd_macro(f,e_record)
/*
 * alcrecd - allocate record with nflds fields in the block region.
 */

struct b_record *f(struct b_constructor *con)
   {
   register struct b_record *blk;
   int i, nflds = con->n_fields;

   EVVal(sizeof(struct b_record) + (nflds-1)*sizeof(struct descrip),e_record);
   AlcVarBlk(blk, b_record, T_Record, nflds)
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
   register struct b_object *blk;
   int i, nflds = class->n_instance_fields;
   EVVal(sizeof(struct b_object) + (nflds-1)*sizeof(struct descrip),e_object);
   AlcVarBlk(blk, b_object, T_Object, nflds);
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


#begdef alccast_macro(f,e_cast)
/*
 * alccast - allocate a cast value in the block region.
 */

struct b_cast *f()
   {
   register struct b_cast *blk;

   EVVal(sizeof (struct b_cast), e_cast);
   AlcFixBlk(blk, b_cast, T_Cast)
   return blk;
   }
#enddef

alccast_macro(alccast_0,0)
alccast_macro(alccast_1,E_Cast)

#begdef alcmethp_macro(f,e_methp)
/*
 * alcmethp - allocate a methp value in the block region.
 */

struct b_methp *f()
   {
   register struct b_methp *blk;

   EVVal(sizeof (struct b_methp), e_methp);
   AlcFixBlk(blk, b_methp, T_Methp)
   return blk;
   }
#enddef

alcmethp_macro(alcmethp_0,0)
alcmethp_macro(alcmethp_1,E_Methp)



#begdef alcucs_macro(f,e_ucs)
/*
 * alcucs - allocate a ucs value in the block region.
 */

struct b_ucs *f(int n)
   {
   register struct b_ucs *blk;
   register uword size;
   size = sizeof(struct b_ucs) + ((n - 1) * sizeof(word));
   EVVal(size,e_ucs);
   AlcBlk(blk, b_ucs, T_Ucs, size);
   blk->blksize = size;
   blk->utf8 = nulldesc;
   return blk;
   }
#enddef

alcucs_macro(alcucs_0,0)
alcucs_macro(alcucs_1,E_Ucs)


/*
 * alcrefresh - allocate a co-expression refresh block.
 */

#begdef alcrefresh_macro(f,e_refresh)

struct b_refresh *f(word *entryx, int na, int nl)
   {
   struct b_refresh *blk;

   EVVal(sizeof(struct b_refresh) + (na+nl)*sizeof(struct descrip),e_refresh);
   AlcVarBlk(blk, b_refresh, T_Refresh, na + nl);
   blk->ep = entryx;
   blk->numlocals = nl;
   return blk;
   }

#enddef

alcrefresh_macro(alcrefresh_0,0)
alcrefresh_macro(alcrefresh_1,E_Refresh)

#begdef alcselem_macro(f,e_selem)
/*
 * alcselem - allocate a set element block.
 */
struct b_selem *f(dptr mbr,uword hn)
   {
   tended struct descrip tmbr = *mbr;
   register struct b_selem *blk;

   EVVal(sizeof(struct b_selem), e_selem);
   AlcFixBlk(blk, b_selem, T_Selem)
   blk->clink = NULL;
   blk->setmem = tmbr;
   blk->hashnum = hn;
   return blk;
   }
#enddef

alcselem_macro(alcselem_0,0)
alcselem_macro(alcselem_1,E_Selem)

#begdef alcstr_macro(f,e_string)
/*
 * alcstr - allocate a string in the string space.
 */

char *f(register char *s, register word slen)
   {
   tended struct descrip ts;
   register char *d;
   char *ofree;

   StrLen(ts) = slen;
   StrLoc(ts) = s;
#if e_string
   if (!noMTevents)
      EVVal(slen, e_string);
#endif					/* E_String */
   s = StrLoc(ts);

   /*
    * Make sure there is enough room in the string space.
    */
   if (DiffPtrs(strend,strfree) < slen) {
      StrLen(ts) = slen;
      StrLoc(ts) = s;
      if (!reserve(Strings, slen))
         return NULL;
      s = StrLoc(ts);
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

struct b_tvsubs *f(word len, word pos, dptr var)
   {
   tended struct descrip tvar = *var;
   register struct b_tvsubs *blk;

   EVVal(sizeof(struct b_tvsubs), e_tvsubs);
   AlcFixBlk(blk, b_tvsubs, T_Tvsubs)
   blk->sslen = len;
   blk->sspos = pos;
   blk->ssvar = tvar;
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
   register struct b_telem *blk;

   EVVal(sizeof (struct b_telem), e_telem);
   AlcFixBlk(blk, b_telem, T_Telem)
   blk->hashnum = 0;
   blk->clink = NULL;
   blk->tref = nulldesc;
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

struct b_tvtbl *f(register dptr tbl, register dptr ref, uword hashnum)
   {
   tended struct descrip ttbl = *tbl;
   tended struct descrip tref = *ref;
   register struct b_tvtbl *blk;

   EVVal(sizeof (struct b_tvtbl), e_tvtbl);
   AlcFixBlk(blk, b_tvtbl, T_Tvtbl)
   blk->hashnum = hashnum;
   blk->clink = BlkLoc(ttbl);
   blk->tref = tref;
   return blk;
   }
#enddef

alctvtbl_macro(alctvtbl_0,0)
alctvtbl_macro(alctvtbl_1,E_Tvtbl)

#begdef dealcblk_macro(f,e_blkdealc)
/*
 * dealcblk - return a block to the heap.
 *
 *  The block must be the one that is at the very end of a block region.
 */
void f (union block *bp)
{
   word nbytes;
   struct region *rp;

   nbytes = BlkSize(bp);
   for (rp = curblock; rp; rp = rp->next)
      if ((char *)bp + nbytes == rp->free)
         break;
   if (!rp)
      for (rp = curblock->prev; rp; rp = rp->prev)
	 if ((char *)bp + nbytes == rp->free)
            break;
   if (!rp)
      syserr ("deallocation botch");
   rp->free = (char *)bp;
   blktotal -= nbytes;
   EVVal(nbytes, e_blkdealc);
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
    EVVal(nbytes, E_StrDeAlc);
}
#enddef

dealcstr_macro(dealcstr_0,0)
dealcstr_macro(dealcstr_1,E_StrDeAlc)



#begdef reserve_macro(f,e_tenurestring,e_tenureblock)
/*
 * reserve -- ensure space in either string or block region.
 *
 *   1. check for space in current region.
 *   2. check for space in older regions.
 *   3. check for space in newer regions.
 *   4. set goal of 10% of size of newest region.
 *   5. collect regions, newest to oldest, until goal met.
 *   6. allocate new region at 200% the size of newest existing.
 *   7. reset goal back to original request.
 *   8. collect regions that were too small to bother with before.
 *   9. search regions, newest to oldest.
 *  10. give up and signal error.
 */

char *f(int region, word nbytes)
{
   struct region **pcurr, *curr, *rp;
   word want, newsize;
   extern int qualfail;

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

   if ((rp = findgap(curr, nbytes)) != 0) {    /* check all regions on chain */
      *pcurr = rp;			/* switch regions */
      return rp->free;
      }

   /*
    * Set "curr" to point to newest region.
    */
   while (curr->next)
      curr = curr->next;

   /*
    * Need to collect garbage.  To reduce thrashing, set a minimum requirement
    *  of 10% of the size of the newest region, and collect regions until that
    *  amount of free space appears in one of them.
    */
   want = (curr->size / 100) * memcushion;
   if (want < nbytes)
      want = nbytes;

   for (rp = curr; rp; rp = rp->prev)
      if (rp->size >= want) {	/* if large enough to possibly succeed */
         *pcurr = rp;
         collect(region);
         if (DiffPtrs(rp->end,rp->free) >= want)
            return rp->free;
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
#if e_tenurestring || e_tenureblock
      if (!noMTevents) {
         if (region == Strings) {
            EVVal(rp->size, e_tenurestring);
            }
         else {
            EVVal(rp->size, e_tenureblock);
            }
         }
#endif					/* e_tenurestring || e_tenureblock */
      return rp->free;
      }

   /*
    * Allocation failed.  Try to continue, probably thrashing all the way.
    *  Collect the regions that weren't collected before and see if any
    *  region has enough to satisfy the original request.
    */
   for (rp = curr; rp; rp = rp->prev)
      if (rp->size < want) {		/* if not collected earlier */
         *pcurr = rp;
         collect(region);
         if (DiffPtrs(rp->end,rp->free) >= want)
            return rp->free;
         }
   if ((rp = findgap(curr, nbytes)) != 0) {
      *pcurr = rp;
      return rp->free;
      }

   /*
    * All attempts failed.
    */
   if (region == Blocks)
      ReturnErrNum(307, 0);
   else if (qualfail)
      ReturnErrNum(304, 0);
   else
      ReturnErrNum(306, 0);
}
#enddef

reserve_macro(reserve_0,0,0)
reserve_macro(reserve_1,E_TenureString,E_TenureBlock)

/*
 * findgap - search region chain for a region having at least nbytes available
 */
static struct region *findgap(curr, nbytes)
struct region *curr;
word nbytes;
   {
   struct region *rp;

   for (rp = curr; rp; rp = rp->prev)
      if (DiffPtrs(rp->end, rp->free) >= nbytes)
         return rp;
   for (rp = curr->next; rp; rp = rp->next)
      if (DiffPtrs(rp->end, rp->free) >= nbytes)
         return rp;
   return NULL;
   }

/*
 * newregion - try to malloc a new region and tenure the old one,
 *  backing off if the requested size fails.
 */
static struct region *newregion(nbytes,stdsize)
word nbytes,stdsize;
{
   uword minSize = MinAbrSize;
   struct region *rp;

#if IntBits == 16
   if ((uword)nbytes > (uword)MaxBlock)
      return NULL;
   if ((uword)stdsize > (uword)MaxBlock)
      stdsize = (uword)MaxBlock;
#endif					/* IntBits == 16 */

   if ((uword)nbytes > minSize)
      minSize = (uword)nbytes;

   rp = malloc(sizeof(struct region));
   if (rp) {
      rp->size = stdsize;
#if IntBits == 16
      if ((rp->size < nbytes) && (nbytes < (unsigned int)MaxBlock))
         rp->size = Min(nbytes+stdsize,(unsigned int)MaxBlock);
#else					/* IntBits == 16 */
      if (rp->size < nbytes)
         rp->size = Max(nbytes+stdsize, nbytes);
#endif					/* IntBits == 16 */

      do {
         rp->free = rp->base = malloc(rp->size);
         if (rp->free != NULL) {
            rp->end = rp->base + rp->size;
            return rp;
            }
         rp->size = (rp->size + nbytes)/2 - 1;
         }
      while (rp->size >= minSize);
      free((char *)rp);
      }
   return NULL;
}
