/*
 * File: rstruct.r
 */

static void cphash(dptr dp1, dptr dp2, word n, int tcode);

/*
 * addmem - add a new set element block in the correct spot in
 *  the bucket chain.
 */

void addmem(struct b_set *ps,struct b_selem *pe,union block **pl)
   {
   ps->size++;
   pe->clink = *pl;
   *pl = (union block *) pe;
   }

/*
 * cpslots(dp, slotptr, i, size) - copy elements of sublist dp[i+:size]
 *  into an array of descriptors.
 * 
 *  No allocation is done.
 */

void cpslots(dptr dp, dptr slotptr, word i, word size)
   {
   struct b_list *lp;     /* Neither pointer need be tended since no allocation is done. */
   struct b_lelem *le;
   struct lgstate state;
   lp = &ListBlk(*dp);
   for (le = lginit(lp, i, &state); size > 0 && le; le = lgnext(lp, &state, le)) {
      *slotptr++ = le->lslots[state.result];
      size--;
      }
   }

/*
 * cplist(dp1,dp2,i,size) - copy sublist dp1[i+:size] into dp2.
 */
void cplist(dptr dp1, dptr dp2, word i, word size)
   {
   word nslots;
   tended struct b_list *lp2;

   /*
    * Calculate the size of the sublist.
    */
   nslots = size;
   if (nslots == 0)
      nslots = MinListSlots;

   MemProtect(lp2 = alclist(size, nslots));
   cpslots(dp1, lp2->listhead->lelem.lslots, i, size);

   /*
    * Fix type and location fields for the new list.
    */
   MakeDesc(D_List, lp2, dp2);
   }

/*
 * cpset(dp1,dp2,n) - copy set dp1 to dp2, reserving memory for n entries.
 */
void cpset(dptr dp1, dptr dp2, word n)
   {
   cphash(dp1, dp2, n, T_Set);
   }

void cptable(dptr dp1, dptr dp2, word n)
   {
   cphash(dp1, dp2, n, T_Table);
   TableBlk(*dp2).defvalue = TableBlk(*dp1).defvalue;
   }

static void cphash(dptr dp1, dptr dp2, word n, int tcode)
   {
   union block *src;
   tended union block *dst;
   tended struct b_slots *seg;
   tended struct b_selem *ep, *prev;
   struct b_selem *se;
   word slotnum;
   int i;

   /*
    * Make a new set organized like dp1, with room for n elements.
    */
   MemProtect(dst = hmake(tcode, SetBlk(*dp1).mask + 1, n));

   /*
    * Copy the header and slot blocks.
    */
   src = BlkLoc(*dp1);
   dst->set.size = src->set.size;	/* actual set size */
   dst->set.mask = src->set.mask;	/* hash mask */
   for (i = 0; i < HSegs && src->set.hdir[i] != NULL; i++)
      memcpy(dst->set.hdir[i], src->set.hdir[i],
         src->set.hdir[i]->blksize);
   /*
    * Work down the chain of element blocks in each bucket
    *	and create identical chains in new set.
    */
   for (i = 0; i < HSegs && (seg = dst->set.hdir[i]) != NULL; i++)
      for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--)  {
	 prev = NULL;
         for (ep = (struct b_selem *)seg->hslots[slotnum];
	      BlkType(ep) != T_Table && BlkType(ep) != T_Set;
	      ep = (struct b_selem *)ep->clink) {
	    if (tcode == T_Set) {
               MemProtect(se = alcselem());
	       *se = *ep; /* copy set entry */
	       }
	    else {
	       MemProtect(se = (struct b_selem *)alctelem());
	       *(struct b_telem *)se = *(struct b_telem *)ep; /* copy table entry */
	       }
	    se->clink = dst;   /* will be set next time round the loop (unless it's the last item) */
	    if (prev == NULL)
		seg->hslots[slotnum] = (union block *)se;
	    else
		prev->clink = (union block *)se;
	    prev = se;
            }
         /* If the element list was empty, we need to correct the structure pointer to 
            point to the new structure rather than the old one. */
         if (prev == NULL)
             seg->hslots[slotnum] = (union block *)dst;
         }
   MakeDesc(tcode | D_Typecode | F_Ptr, dst, dp2);
   if (TooSparse(dst))
      hshrink(dst);
   }

/*
 * hmake - make a hash structure (Set or Table) with a given number of slots.
 *  If *nslots* is zero, a value appropriate for *nelem* elements is chosen.
 *  A return of NULL indicates allocation failure.
 */
union block *hmake(int tcode, word nslots, word nelem)
   {
   word seg, t, blksize, elemsize;
   tended union block *blk;
   struct b_slots *segp;

   if (nslots == 0)
      nslots = (nelem + MaxHLoad - 1) / MaxHLoad;
   for (seg = t = 0; seg < (HSegs - 1) && (t += segsize[seg]) < nslots; seg++)
      ;
   nslots = ((word)HSlots) << seg;	/* ensure legal power of 2 */
   if (tcode == T_Table) {
      blksize = sizeof(struct b_table);
      elemsize = sizeof(struct b_telem);
      }
   else {	/* T_Set */
      blksize = sizeof(struct b_set);
      elemsize = sizeof(struct b_selem);
      }
   if (!reserve(Blocks, (word)(blksize + (seg + 1) * sizeof(struct b_slots)
      + (nslots - HSlots * (seg + 1)) * sizeof(union block *)
      + nelem * elemsize))) return NULL;
   Protect(blk = alchash(tcode), return NULL);
   for (; seg >= 0; seg--) {
      word j;
      Protect(segp = alcsegment(segsize[seg]), return NULL);
      blk->set.hdir[seg] = segp;
      for (j = 0; j < segsize[seg]; j++)
          segp->hslots[j] = blk;
      }
   blk->set.mask = nslots - 1;
   return blk;
   }

/*
 * hchain - return a pointer to the word that points to the head of the hash
 *  chain for hash number hn in hashed structure s.
 */

/*
 * lookup table for log to base 2; must have powers of 2 through (HSegs-1)/2.
 */
static unsigned char log2h[] = {
   0,1,2,2, 3,3,3,3, 4,4,4,4, 4,4,4,4, 5,5,5,5, 5,5,5,5, 5,5,5,5, 5,5,5,5,
   };

union block **hchain(union block *pb, uword hn)
   {
   struct b_set *ps;
   word slotnum, segnum, segslot;

   ps = (struct b_set *)pb;
   slotnum = hn & ps->mask;
   if (slotnum >= HSlots * sizeof(log2h))
      segnum = log2h[slotnum >> (LogHSlots + HSegs/2)] + HSegs/2;
   else
      segnum = log2h[slotnum >> LogHSlots];
   segslot = hn & (segsize[segnum] - 1);
   return &ps->hdir[segnum]->hslots[segslot];
   }

/*
 * hgfirst - initialize for generating set or table, and return first element.
 */

union block *hgfirst(union block *bp, struct hgstate *s)
   {
   int i;

   s->segnum = 0;				/* set initial state */
   s->slotnum = -1;
   s->tmask = bp->table.mask;
   for (i = 0; i < HSegs; i++)
      s->sghash[i] = s->sgmask[i] = 0;
   return hgnext(bp, s, NULL);	/* get and return first value */
   }

/*
 * hgnext - return the next element of a set or table generation sequence.
 *
 *  We carefully generate each element exactly once, even if the hash chains
 *  are split between calls.  We do this by recording the state of things at
 *  the time of the split and checking past history when starting to process
 *  a new chain.
 *
 *  Elements inserted or deleted between calls may or may not be generated. 
 *
 *  We assume that no structure *shrinks* after its initial creation; they
 *  can only *grow*.
 */

union block *hgnext(union block *bp, struct hgstate *s, union block *ep)
   {
   int i;
   word d, m;
   uword hn;

   /*
    * Check to see if the set or table's hash buckets were split (once or
    *  more) since the last call.  We notice this unless the next entry
    *  has same hash value as the current one, in which case we defer it
    *  by doing nothing now.
    */
   if (bp->table.mask != s->tmask &&
	  (BlkType(ep->selem.clink) == T_Set || BlkType(ep->telem.clink) == T_Table ||
	  ep->telem.clink->telem.hashnum != ep->telem.hashnum)) {
      /*
       * Yes, they did split.  Make a note of the current state.
       */
      hn = ep->telem.hashnum;
      for (i = 1; i < HSegs; i++)
         if ((((word)HSlots) << (i - 1)) > s->tmask) {
   	 /*
   	  * For the newly created segments only, save the mask and
   	  *  hash number being processed at time of creation.
   	  */
   	 s->sgmask[i] = s->tmask;
   	 s->sghash[i] = hn;
         }
      s->tmask = bp->table.mask;
      /*
       * Find the next element in our original segment by starting
       *  from the beginning and skipping through the current hash
       *  number.  We can't just follow the link from the current
       *  element, because it may have moved to a new segment.
       */
      ep = bp->table.hdir[s->segnum]->hslots[s->slotnum];
      while (BlkType(ep) != T_Set && BlkType(ep) != T_Table &&
	     ep->telem.hashnum <= hn)
         ep = ep->telem.clink;
      }

   else {
      /*
       * There was no split, or else if there was we're between items
       *  that have identical hash numbers.  Find the next element in
       *  the current hash chain.
       */
      if (ep != NULL && BlkType(ep) != T_Set && BlkType(ep) != T_Table)	/* NULL on very first call */
         ep = ep->telem.clink;		/* next element in chain, if any */
   }

   /*
    * If we don't yet have an element, search successive slots.
    */
   while (ep == NULL || BlkType(ep) == T_Set || BlkType(ep) == T_Table) {
      /*
       * Move to the next slot and pick the first entry.
       */
      s->slotnum++;
      if (s->slotnum >= segsize[s->segnum]) {
	 s->slotnum = 0;		/* need to move to next segment */
	 s->segnum++;
	 if (s->segnum >= HSegs || bp->table.hdir[s->segnum] == NULL)
	    return 0;			/* return NULL at end of set/table */
         }
      ep = bp->table.hdir[s->segnum]->hslots[s->slotnum];
      /*
       * Check to see if parts of this hash chain were already processed.
       *  This could happen if the elements were in a different chain,
       *  but a split occurred while we were suspended.
       */
      for (i = s->segnum; (m = s->sgmask[i]) != 0; i--) {
         d = (word)(m & s->slotnum) - (word)(m & s->sghash[i]);
         if (d < 0)			/* if all elements processed earlier */
            ep = NULL;			/* skip this slot */
         else if (d == 0) {
            /*
             * This chain was split from its parent while the parent was
             *  being processed.  Skip past elements already processed.
             */
            while (ep != NULL && BlkType(ep) != T_Set && BlkType(ep) != T_Table &&
		   ep->telem.hashnum <= s->sghash[i])
               ep = ep->telem.clink;
            }
         }
      }

   /*
    * Return the element.
    */
   if (ep && (BlkType(ep) == T_Set || BlkType(ep) == T_Table)) ep = NULL;
   return ep;
   }

/*
 * hgrow - split a hashed structure (doubling the buckets) for faster access.
 */

void hgrow(union block *bp)
   {
   union block **tp0, **tp1, *ep;
   word j, newslots, slotnum, segnum;
   tended struct b_set *ps;
   struct b_slots *seg, *newseg;
   union block **curslot;

   ps = (struct b_set *) bp;
   if (ps->hdir[HSegs-1] != NULL)
      return;				/* can't split further */
   newslots = ps->mask + 1;
   Protect(newseg = alcsegment(newslots), return);
   for(j=0; j<newslots; j++) newseg->hslots[j] = bp;

   curslot = newseg->hslots;
   for (segnum = 0; (seg = ps->hdir[segnum]) != NULL; segnum++)
      for (slotnum = 0; slotnum < segsize[segnum]; slotnum++)  {
         tp0 = &seg->hslots[slotnum];	/* ptr to tail of old slot */
         tp1 = curslot++;		/* ptr to tail of new slot */
         for (ep = *tp0;
	      BlkType(ep) != T_Set && BlkType(ep) != T_Table;
	      ep = ep->selem.clink) {
            if ((ep->selem.hashnum & newslots) == 0) {
               *tp0 = ep;		/* element does not move */
               tp0 = &ep->selem.clink;
               }
            else {
               *tp1 = ep;		/* element moves to new slot */
               tp1 = &ep->selem.clink;
               }
            }
	 *tp0 = *tp1 = bp;
         }
   ps->hdir[segnum] = newseg;
   ps->mask = (ps->mask << 1) | 1;
   }

/*
 * hshrink - combine buckets in a set or table that is too sparse.
 *
 *  Call this only for newly created structures.  Shrinking an active structure
 *  can wreak havoc on suspended generators.
 */
void hshrink(union block *bp)
   {
   union block **tp, *ep0, *ep1;
   int topseg, curseg;
   word slotnum;
   tended struct b_set *ps;
   struct b_slots *seg;
   union block **uppslot;

   ps = (struct b_set *)bp;
   topseg = 0;
   for (topseg = 1; topseg < HSegs && ps->hdir[topseg] != NULL; topseg++)
      ;
   topseg--;
   while (TooSparse(ps)) {
      uppslot = ps->hdir[topseg]->hslots;
      ps->hdir[topseg--] = NULL;
      for (curseg = 0; (seg = ps->hdir[curseg]) != NULL; curseg++)
         for (slotnum = 0; slotnum < segsize[curseg]; slotnum++)  {
            tp = &seg->hslots[slotnum];		/* tail pointer */
            ep0 = seg->hslots[slotnum];		/* lower slot entry pointer */
            ep1 = *uppslot++;			/* upper slot entry pointer */
            while (BlkType(ep0) != T_Set && BlkType(ep0) != T_Table &&
		   BlkType(ep1) != T_Set && BlkType(ep1) != T_Table)
               if (ep0->selem.hashnum < ep1->selem.hashnum) {
                  *tp = ep0;
                  tp = &ep0->selem.clink;
                  ep0 = ep0->selem.clink;
                  }
               else {
                  *tp = ep1;
                  tp = &ep1->selem.clink;
                  ep1 = ep1->selem.clink;
                  }
            while (BlkType(ep0) != T_Set && BlkType(ep0) != T_Table) {
               *tp = ep0;
               tp = &ep0->selem.clink;
               ep0 = ep0->selem.clink;
               }
            while (BlkType(ep1) != T_Set && BlkType(ep1) != T_Table) {
               *tp = ep1;
               tp = &ep1->selem.clink;
               ep1 = ep1->selem.clink;
               }
            }
      ps->mask >>= 1;
      }
   }

/*
 * memb - sets res flag to 1 if x is a member of a set or table, 0 if not.
 *  Returns a pointer to the word which points to the element, or which
 *  would point to it if it were there.
 *  int *res is a pointer to integer result flag.
 */

union block **memb(union block *pb, dptr x, uword hn, int *res)
   {
   union block **lp;
   struct b_selem *pe;
   uword eh;

   lp = hchain(pb, hn);
   /*
    * Look for x in the hash chain.
    */
   *res = 0;
   while (1) {
      pe = (struct b_selem *)*lp;
      if (BlkType(pe) == T_Table || BlkType(pe) == T_Set)
          break;
      eh = pe->hashnum;
      if (eh > hn)			/* too far - it isn't there */
         return lp;
      else if ((eh == hn) && (equiv(&pe->setmem, x)))  {
         *res = 1;
         return lp;
         }
      /*
       * We haven't reached the right hashnumber yet or
       *  the element isn't the right one so keep looking.
       */
      lp = &(pe->clink);
      }
   /*
    *  At end of chain - not there.
    */
   return lp;
   }



/*
 * Get the b_lelem in which index (one-based) resides.  Returns null
 * if not found, otherwise returns the element and sets *pos to the
 * notional index (zero-based) in that element (the actual position of
 * the element is (e->first+pos) % e->nslots.
 */
struct b_lelem *get_lelem_for_index(struct b_list *lb, word index, word *pos)
{
    struct b_lelem *le;
    --index;  /* Make zero-based */
    if (index < 0 || index >= lb->size)
        return 0;
    if (index < lb->size / 2) {
        /* Search forwards from beginning of list */
        le = (struct b_lelem *)lb->listhead;
        while (index >= le->nused) {
            index -= le->nused;
            le = (struct b_lelem *)le->listnext;
            /* Wrapped around, shouldn't ever happen since we checked size above... */
            if (BlkType(le) != T_Lelem)
                return 0;
        }
        *pos = index;
    } else {
        word n = lb->size;
        /* Search backwards from end of list */
        le = (struct b_lelem *)lb->listtail;
        while (index < n - le->nused) {
            n -= le->nused;
            le = (struct b_lelem *)le->listprev;
            /* Wrapped around, shouldn't ever happen since we checked size above... */
            if (BlkType(le) != T_Lelem)
                return 0;
        }
        *pos = le->nused - n + index;
    }
    return le;
}

/*
 * Initialize an lgstate structure so that it references element i
 * (one-based) of the given list; returns 0 if i is out of range.
 */
struct b_lelem *lginit(struct b_list *lb, word i, struct lgstate *state)
{
    struct b_lelem *le;
    word pos;
    le = get_lelem_for_index(lb, i, &pos);
    if (!le)
        return 0;
    state->listindex = i;
    state->listsize = lb->size;
    state->changecount = lb->changecount;
    state->blockpos = pos;
    state->result = le->first + pos;
    if (state->result >= le->nslots)
        state->result -= le->nslots;
    return le;
}

struct b_lelem *lgfirst(struct b_list *lb, struct lgstate *state)
{
    return lginit(lb, 1, state);
}

struct b_lelem *lglast(struct b_list *lb, struct lgstate *state)
{
    return lginit(lb, lb->size, state);
}

struct b_lelem *lgnext(struct b_list *lb, struct lgstate *state, struct b_lelem *le)
{
    ++state->listindex;
    if (state->changecount == lb->changecount) {
        /*
         * List structure unchanged, so just move to next element.
         */
        ++state->blockpos;
        if (state->blockpos < le->nused) {
            state->result = le->first + state->blockpos;
            if (state->result >= le->nslots)
                state->result -= le->nslots;
            return le;
        } else {
            /* End of current block; find the next non-empty one and return
             * the first element.
             */
            for (;;) {
                le = (struct b_lelem *)le->listnext;
                if (BlkType(le) != T_Lelem)  /* End of list */
                    return 0;
                if (le->nused > 0) {
                    state->blockpos = 0;
                    state->result = le->first;
                    return le;
                }
            }
        }
    } else {
        /*
         * List structure changed - refresh the state values based on
         * the current list index.
         */
        return lginit(lb, state->listindex, state);
    }
}

struct b_lelem *lgprev(struct b_list *lb, struct lgstate *state, struct b_lelem *le)
{
    --state->listindex;
    if (state->changecount == lb->changecount) {
        /*
         * List structure unchanged, so just move to next element.
         */
        --state->blockpos;
        if (state->blockpos >= 0) {
            state->result = le->first + state->blockpos;
            if (state->result >= le->nslots)
                state->result -= le->nslots;
            return le;
        } else {
            /* End of current block; find the previous non-empty one and return
             * the last element.
             */
            for (;;) {
                le = (struct b_lelem *)le->listprev;
                if (BlkType(le) != T_Lelem)  /* End of list */
                    return 0;
                if (le->nused > 0) {
                    state->blockpos = le->nused - 1;
                    state->result = le->first + state->blockpos;
                    if (state->result >= le->nslots)
                        state->result -= le->nslots;
                    return le;
                }
            }
        }
    } else {
        /*
         * List structure changed - refresh the state values so that
         * the distance of listindex from the end of the list remains
         * the same.
         */
        return lginit(lb, state->listindex + lb->size - state->listsize, state);
    }
}
