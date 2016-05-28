/*
 * File: oset.r
 */

"~x - complement cset x."

operator ~ compl(x)
   /*
    * x must be a cset.
    */
   if !cnv:cset(x) then
      runerr(104, x)

   body {
       struct rangeset *rs;
       struct b_cset *blk;
       word i, prev = 0;
       rs = init_rangeset();
       for (i = 0; i < CsetBlk(x).n_ranges; ++i) {
           word from = CsetBlk(x).range[i].from;
           word to = CsetBlk(x).range[i].to;
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

operator -- diff(x,y)
   if is:set(x) && is:set(y) then {
      body {
	 int res;
         int i;
         word slotnum;
         tended union block *srcp, *tstp, *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         struct b_selem *np;
         union block **hook;

         /*
          * Make a new set based on the size of x.
          */
         MemProtect(dstp = hmake(T_Set, (word)0, SetBlk(x).size));

         /*
          * For each element in set x if it is not in set y
          *  copy it directly into the result set.
	  *
	  * np always has a new element ready for use.  We get one in advance,
	  *  and stay one ahead, because hook can't be tended.
          */
         srcp = BlkLoc(x);
         tstp = BlkLoc(y);
         MemProtect(np = alcselem());

         for (i = 0; i < HSegs && (seg = srcp->set.hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  memb(tstp, &ep->setmem, ep->hashnum, &res);
                  if (!res) {
                     hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem());
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
      body {
          struct rangeset *rs, *y_comp;
          struct b_cset *blk;
          word i_x, i_y, prev = 0;

          y_comp = init_rangeset();
          rs = init_rangeset();
          /*
           * Calculate ~y
           */
          for (i_y = 0; i_y < CsetBlk(y).n_ranges; ++i_y) {
              word from = CsetBlk(y).range[i_y].from;
              word to = CsetBlk(y).range[i_y].to;
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
          while (i_x < CsetBlk(x).n_ranges &&
                 i_y < y_comp->n_ranges) {
              word from_x = CsetBlk(x).range[i_x].from;
              word to_x = CsetBlk(x).range[i_x].to;
              word from_y = y_comp->range[i_y].from;
              word to_y = y_comp->range[i_y].to;
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

operator ** inter(x,y)
   if is:set(x) && is:set(y) then {
      body {
	 int res;
         int i;
         word slotnum;
         tended union block *srcp, *tstp, *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         struct b_selem *np;
         union block **hook;

         /*
          * Make a new set the size of the smaller argument set.
          */
         MemProtect(dstp = hmake(T_Set, (word)0,
                                 Min(SetBlk(x).size, SetBlk(y).size)));
         /*
          * Using the smaller of the two sets as the source
          *  copy directly into the result each of its elements
          *  that are also members of the other set.
	  *
	  * np always has a new element ready for use.  We get one in advance,
	  *  and stay one ahead, because hook can't be tended.
          */
         if (SetBlk(x).size <= SetBlk(y).size) {
            srcp = BlkLoc(x);
            tstp = BlkLoc(y);
            }
         else {
            srcp = BlkLoc(y);
            tstp = BlkLoc(x);
            }
         MemProtect(np = alcselem());
         for (i = 0; i < HSegs && (seg = srcp->set.hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  memb(tstp, &ep->setmem, ep->hashnum, &res);
                  if (res) {
                     hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem());
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

      body {
          struct rangeset *rs;
          struct b_cset *blk;
          word i_x, i_y;
          rs = init_rangeset();
          i_x = i_y = 0;
          while (i_x < CsetBlk(x).n_ranges &&
                 i_y < CsetBlk(y).n_ranges) {
              word from_x = CsetBlk(x).range[i_x].from;
              word to_x = CsetBlk(x).range[i_x].to;
              word from_y = CsetBlk(y).range[i_y].from;
              word to_y = CsetBlk(y).range[i_y].to;
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

operator ++ union(x,y)
   if is:set(x) && is:set(y) then {
      body {
	 int res;
	 int i;
	 word slotnum;
         struct descrip d;
         tended union block *dstp;
         tended struct b_slots *seg;
         tended struct b_selem *ep;
         tended struct b_selem *np;
         tended struct descrip result;
         union block **hook;

         /*
          * Ensure that x is the larger set; if not, swap.
          */
         if (SetBlk(y).size > SetBlk(x).size) {
	    d = x;
	    x = y;
	    y = d;
	    }
         /*
          * Copy x and ensure there's room for *x + *y elements.
          */
         cpset(&x, &result, SetBlk(x).size + SetBlk(y).size);

         MemProtect(reserve(Blocks,SetBlk(y).size*(2*sizeof(struct b_selem))));

         /*
          * Copy each element from y into the result, if not already there.
	  *
	  * np always has a new element ready for use.  We get one in
	  *  advance, and stay one ahead, because hook can't be tended.
          */
         dstp = BlkLoc(result);
         MemProtect(np = alcselem());
         for (i = 0; i < HSegs && (seg = SetBlk(y).hdir[i]) != NULL; i++)
            for (slotnum = segsize[i] - 1; slotnum >= 0; slotnum--) {
               ep = (struct b_selem *)seg->hslots[slotnum];
               while (ep != NULL) {
                  hook = memb(dstp, &ep->setmem, ep->hashnum, &res);
                  if (!res) {
		     np->setmem = ep->setmem;
		     np->hashnum = ep->hashnum;
                     addmem(&dstp->set, np, hook);
                     MemProtect(np = alcselem());
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

      body {
          struct rangeset *rs;
          struct b_cset *blk;
          int i;
          rs = init_rangeset();
          for (i = 0; i < CsetBlk(x).n_ranges; ++i) 
              add_range(rs, CsetBlk(x).range[i].from, CsetBlk(x).range[i].to);
          
          for (i = 0; i < CsetBlk(y).n_ranges; ++i) 
              add_range(rs, CsetBlk(y).range[i].from, CsetBlk(y).range[i].to);
          
          blk = rangeset_to_block(rs);
          free_rangeset(rs);
          return cset(blk);
         }
      }
end
