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
       word i, from, to, prev;
       rs = init_rangeset();
       prev = 0;
       for (i = 0; i < CsetBlk(x).n_ranges; ++i) {
           from = CsetBlk(x).range[i].from;
           to = CsetBlk(x).range[i].to;
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
               while (BlkType(ep) == T_Selem) {
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
          word i_x, i_y, m, to_x, to_y, from, to, prev;

          y_comp = init_rangeset();
          rs = init_rangeset();
          /*
           * Calculate ~y
           */
          prev = 0;
          for (i_y = 0; i_y < CsetBlk(y).n_ranges; ++i_y) {
              from = CsetBlk(y).range[i_y].from;
              to = CsetBlk(y).range[i_y].to;
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
              to_x = CsetBlk(x).range[i_x].to;
              to_y = y_comp->range[i_y].to;
              m = Max(CsetBlk(x).range[i_x].from, y_comp->range[i_y].from);
              if (to_x < to_y) {
                  add_range(rs, m, to_x);
                  ++i_x;
              } else {
                  add_range(rs, m, to_y);
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
               while (BlkType(ep) == T_Selem) {
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
          word i_x, i_y, m, to_x, to_y;
          rs = init_rangeset();
          i_x = i_y = 0;
          while (i_x < CsetBlk(x).n_ranges &&
                 i_y < CsetBlk(y).n_ranges) {
              to_x = CsetBlk(x).range[i_x].to;
              to_y = CsetBlk(y).range[i_y].to;
              m = Max(CsetBlk(x).range[i_x].from, CsetBlk(y).range[i_y].from);
              if (to_x < to_y) {
                  add_range(rs, m, to_x);
                  ++i_x;
              } else {
                  add_range(rs, m, to_y);
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
               while (BlkType(ep) == T_Selem) {
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
          word i_x, i_y, from_x, from_y;
          rs = init_rangeset();
          i_x = i_y = 0;
          while (i_x < CsetBlk(x).n_ranges &&
                 i_y < CsetBlk(y).n_ranges) {
              from_x = CsetBlk(x).range[i_x].from;
              from_y = CsetBlk(y).range[i_y].from;
              if (from_x < from_y) {
                  add_range(rs, from_x, CsetBlk(x).range[i_x].to);
                  ++i_x;
              } else {
                  add_range(rs, from_y, CsetBlk(y).range[i_y].to);
                  ++i_y;
              }
          }
          while (i_x < CsetBlk(x).n_ranges) {
              add_range(rs, CsetBlk(x).range[i_x].from, CsetBlk(x).range[i_x].to);
              ++i_x;
          }
          while (i_y < CsetBlk(y).n_ranges) {
              add_range(rs, CsetBlk(y).range[i_y].from, CsetBlk(y).range[i_y].to);
              ++i_y;
          }
          blk = rangeset_to_block(rs);
          free_rangeset(rs);
          return cset(blk);
         }
      }
end
