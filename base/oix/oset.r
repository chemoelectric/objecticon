/*
 * File: oset.r
 *  Contents: compl, diff, inter, union
 */

"~x - complement cset x."

operator{1} ~ compl(x)
   /*
    * x must be a cset.
    */
   if !cnv:cset(x) then
      runerr(104, x)

   abstract {
      return cset
      }
   body {
       struct rangeset *rs = init_rangeset();
       struct b_cset *blk;
       int i, prev = 0;
       for (i = 0; i < BlkLoc(x)->cset.n_ranges; ++i) {
           int from = BlkLoc(x)->cset.range[i].from;
           int to = BlkLoc(x)->cset.range[i].to;
           if (from > prev)
               add_range(rs, prev, from - 1);
           prev = to + 1;
       }
       if (prev <= MAX_CODE_POINT)
           add_range(rs, prev, MAX_CODE_POINT);
       blk = rangeset_to_block(rs);
       free_rangeset(rs);
       return cset(blk);
      }
end


"x -- y - difference of csets x and y or of sets x and y."

operator{1} -- diff(x,y)
   if is:set(x) && is:set(y) then {
      abstract {
         return type(x)
         }
      body {
	 int res;
         register int i;
         register word slotnum;
         tended union block *srcp, *tstp, *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         struct b_selem *np;
         union block **hook;

         /*
          * Make a new set based on the size of x.
          */
         dstp = hmake(T_Set, (word)0, BlkLoc(x)->set.size);
         if (dstp == NULL)
            runerr(0);
         /*
          * For each element in set x if it is not in set y
          *  copy it directly into the result set.
	  *
	  * np always has a new element ready for use.  We get one in advance,
	  *  and stay one ahead, because hook can't be tended.
          */
         srcp = BlkLoc(x);
         tstp = BlkLoc(y);
         MemProtect(np = alcselem(&nulldesc, (uword)0));

         for (i = 0; i < HSegs && (seg = srcp->set.hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  memb(tstp, &ep->setmem, ep->hashnum, &res);
                  if (res == 0) {
                     hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem(&nulldesc, (uword)0));
                     }
                  ep = (struct b_selem *)ep->clink;
                  }
               }
	 dealcblk((union block *)np);
         if (TooSparse(dstp))
            hshrink(dstp);
         Desc_EVValD(dstp, E_Screate, D_Set);
         return set(dstp);
         }
      }
   else {
      if !cnv:cset(x) then
         runerr(120, x)
      if !cnv:cset(y) then
         runerr(120, y)
      abstract {
         return cset
         }
      body {
          struct rangeset *y_comp = init_rangeset();
          struct rangeset *rs = init_rangeset();
          struct b_cset *blk;
          int i_x, i_y, prev = 0;
          /*
           * Calculate ~y
           */
          for (i_y = 0; i_y < BlkLoc(y)->cset.n_ranges; ++i_y) {
              int from = BlkLoc(y)->cset.range[i_y].from;
              int to = BlkLoc(y)->cset.range[i_y].to;
              if (from > prev)
                  add_range(y_comp, prev, from - 1);
              prev = to + 1;
          }
          if (prev <= MAX_CODE_POINT)
              add_range(y_comp, prev, MAX_CODE_POINT);

          /*
           * Calculate x ** ~y
           */
          i_x = i_y = 0;
          while (i_x < BlkLoc(x)->cset.n_ranges &&
                 i_y < y_comp->n_ranges) {
              int from_x = BlkLoc(x)->cset.range[i_x].from;
              int to_x = BlkLoc(x)->cset.range[i_x].to;
              int from_y = y_comp->range[i_y].from;
              int to_y = y_comp->range[i_y].to;
              if (to_x < to_y) {
                  add_range(rs, Max(from_x, from_y), to_x);
                  ++i_x;
              }
              else {
                  add_range(rs, Max(from_x, from_y), to_y);
                  ++i_y;
              }
          }
          blk = rangeset_to_block(rs);
          free_rangeset(rs);
          free_rangeset(y_comp);
          return cset(blk);
         }
      }
end


"x ** y - intersection of csets x and y or of sets x and y."

operator{1} ** inter(x,y)
   if is:set(x) && is:set(y) then {
      abstract {
         return new set(store[type(x).set_elem] ** store[type(y).set_elem])
         }
      body {
	 int res;
         register int i;
         register word slotnum;
         tended union block *srcp, *tstp, *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         struct b_selem *np;
         union block **hook;

         /*
          * Make a new set the size of the smaller argument set.
          */
         dstp = hmake(T_Set, (word)0,
            Min(BlkLoc(x)->set.size, BlkLoc(y)->set.size));
         if (dstp == NULL)
            runerr(0);
         /*
          * Using the smaller of the two sets as the source
          *  copy directly into the result each of its elements
          *  that are also members of the other set.
	  *
	  * np always has a new element ready for use.  We get one in advance,
	  *  and stay one ahead, because hook can't be tended.
          */
         if (BlkLoc(x)->set.size <= BlkLoc(y)->set.size) {
            srcp = BlkLoc(x);
            tstp = BlkLoc(y);
            }
         else {
            srcp = BlkLoc(y);
            tstp = BlkLoc(x);
            }
         MemProtect(np = alcselem(&nulldesc, (uword)0));
         for (i = 0; i < HSegs && (seg = srcp->set.hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  memb(tstp, &ep->setmem, ep->hashnum, &res);
                  if (res != 0) {
                     hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem(&nulldesc, (uword)0));
                     }
                  ep = (struct b_selem *)ep->clink;
                  }
               }
	 dealcblk((union block *)np);
         if (TooSparse(dstp))
            hshrink(dstp);
         Desc_EVValD(dstp, E_Screate, D_Set);
         return set(dstp);
         }
      }
   else {

      if !cnv:cset(x) then
         runerr(120, x)
      if !cnv:cset(y) then
         runerr(120, y)
      abstract {
         return cset
         }

      body {
          struct rangeset *rs = init_rangeset();
          struct b_cset *blk;
          int i_x, i_y;
          i_x = i_y = 0;
          while (i_x < BlkLoc(x)->cset.n_ranges &&
                 i_y < BlkLoc(y)->cset.n_ranges) {
              int from_x = BlkLoc(x)->cset.range[i_x].from;
              int to_x = BlkLoc(x)->cset.range[i_x].to;
              int from_y = BlkLoc(y)->cset.range[i_y].from;
              int to_y = BlkLoc(y)->cset.range[i_y].to;
              if (to_x < to_y) {
                  add_range(rs, Max(from_x, from_y), to_x);
                  ++i_x;
              }
              else {
                  add_range(rs, Max(from_x, from_y), to_y);
                  ++i_y;
              }
          }
          blk = rangeset_to_block(rs);
          free_rangeset(rs);
          return cset(blk);
         }
      }
end


"x ++ y - union of csets x and y or of sets x and y."

operator{1} ++ union(x,y)
   if is:set(x) && is:set(y) then {
      abstract {
         return new set(store[type(x).set_elem] ++ store[type(y).set_elem])
         }
      body {
	 int res;
	 register int i;
	 register word slotnum;
         struct descrip d;
         tended union block *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         tended struct b_selem *np;
         union block **hook;

         /*
          * Ensure that x is the larger set; if not, swap.
          */
         if (BlkLoc(y)->set.size > BlkLoc(x)->set.size) {
	    d = x;
	    x = y;
	    y = d;
	    }
         /*
          * Copy x and ensure there's room for *x + *y elements.
          */
         if (cpset(&x, &result, BlkLoc(x)->set.size + BlkLoc(y)->set.size)
            == Error) {
            runerr(0);
            }

         if(!(reserve(Blocks,BlkLoc(y)->set.size*(2*sizeof(struct b_selem))))){
            runerr(0);
            }
         /*
          * Copy each element from y into the result, if not already there.
	  *
	  * np always has a new element ready for use.  We get one in
	  *  advance, and stay one ahead, because hook can't be tended.
          */
         dstp = BlkLoc(result);
         MemProtect(np = alcselem(&nulldesc, (uword)0));
         for (i = 0; i < HSegs && (seg = BlkLoc(y)->set.hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
                  if (res == 0) {
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem(&nulldesc, (uword)0));
                     }
                  ep = (struct b_selem *)ep->clink;
                  }
               }
	 dealcblk((union block *)np);
         if (TooCrowded(dstp)) {	/* if the union got too big, enlarge */
            hgrow(dstp);
            }
         return result;
	 }
      }
   else {
      if !cnv:cset(x) then
         runerr(120, x)
      if !cnv:cset(y) then
         runerr(120, y)
      abstract {
         return cset
         }

      body {
          struct rangeset *rs = init_rangeset();
          struct b_cset *blk;
          int i;
          for (i = 0; i < BlkLoc(x)->cset.n_ranges; ++i) {
              add_range(rs, 
                        BlkLoc(x)->cset.range[i].from,
                        BlkLoc(x)->cset.range[i].to);
          }
          for (i = 0; i < BlkLoc(y)->cset.n_ranges; ++i) {
              add_range(rs, 
                        BlkLoc(y)->cset.range[i].from,
                        BlkLoc(y)->cset.range[i].to);
          }
          blk = rangeset_to_block(rs);
          free_rangeset(rs);
          return cset(blk);
         }
      }
end
