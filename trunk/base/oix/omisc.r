/*
 * File: omisc.r
 *  Contents: refresh, size, tabmat, toby, to, llist
 */

"^x - create a refreshed copy of a co-expression."
/*
 * ^x - return an entry block for co-expression x from the refresh block.
 */
operator{1} ^ refresh(x)
   if !is:coexpr(x) then
       runerr(118, x)

   body {
      register struct b_coexpr *sblkp;

      if (BlkLoc(x)->coexpr.freshblk == NULL)	/* &main cannot be refreshed */
         runerr(215, x);

      /*
       * Get a new co-expression stack and initialize.
       */
      MemProtect(sblkp = alccoexp());
      sblkp->freshblk = BlkLoc(x)->coexpr.freshblk;

      /*
       * Use refresh block to finish initializing the new co-expression.
       */
      co_init(sblkp);

      return coexpr(sblkp);
      }

end


"*x - return size of string or object x."

operator{1} * size(x)
  body {
   type_case x of {
      string: return C_integer StrLen(x);
      ucs:    return C_integer BlkLoc(x)->ucs.length;
      list:   return C_integer BlkLoc(x)->list.size;
      table:  return C_integer BlkLoc(x)->table.size;
      set:    return C_integer BlkLoc(x)->set.size;
      cset:   return C_integer BlkLoc(x)->cset.size;
      record: return C_integer BlkLoc(x)->record.constructor->n_fields;
      coexpr: return C_integer BlkLoc(x)->coexpr.size;
      default: {
         /*
          * Try to convert it to a string.
          */
         if (!cnv:tmp_string(x,x))
            runerr(112, x);	/* no notion of size */
         return C_integer StrLen(x);
      }
   }
 }
end


"=x - tab(match(x)).  Reverses effects if resumed."

operator{*} = tabmat(x)
   body {
      register word l;
      char *s1, *s2;
      C_integer i, j;
      /*
       * Make a copy of &pos.
       */
      i = k_pos;

      if (is:ucs(k_subject)) {
          /*
           * x must be a string.
           */
          if (!cnv:ucs(x,x))
              runerr(128, x);

          /*
           * Fail if &subject[&pos:0] is not of sufficient length to contain x.
           */
          j = BlkLoc(k_subject)->ucs.length - i + 1;
          if (j < BlkLoc(x)->ucs.length)
              fail;

          /*
           * Get pointers to x (s1) and &subject (s2).  Compare them on a byte-wise
           *  basis and fail if s1 doesn't match s2 for *s1 characters.
           */
          s1 = StrLoc(BlkLoc(x)->ucs.utf8);
          s2 = ucs_utf8_ptr(&BlkLoc(k_subject)->ucs, i);
          l = BlkLoc(x)->ucs.length;
          while (l-- > 0) {
              if (utf8_iter(&s1) != utf8_iter(&s2))
                  fail;
          }

          /*
           * Increment &pos to tab over the matched string and suspend the
           *  matched string.
           */
          l = BlkLoc(x)->ucs.length;
          k_pos += l;

          EVVal(k_pos, E_Spos);

          suspend x;

          /*
           * tabmat has been resumed, restore &pos and fail.
           */
          if (i > BlkLoc(k_subject)->ucs.length + 1)
              runerr(205, kywd_pos);
          else {
              k_pos = i;
              EVVal(k_pos, E_Spos);
          }
          fail;
      } else {
          /*
           * x must be a string.
           */
          if (!cnv:string(x,x))
              runerr(103, x);

          /*
           * Fail if &subject[&pos:0] is not of sufficient length to contain x.
           */
          j = StrLen(k_subject) - i + 1;
          if (j < StrLen(x))
              fail;

          /*
           * Get pointers to x (s1) and &subject (s2).  Compare them on a byte-wise
           *  basis and fail if s1 doesn't match s2 for *s1 characters.
           */
          s1 = StrLoc(x);
          s2 = StrLoc(k_subject) + i - 1;
          l = StrLen(x);
          while (l-- > 0) {
              if (*s1++ != *s2++)
                  fail;
          }

          /*
           * Increment &pos to tab over the matched string and suspend the
           *  matched string.
           */
          l = StrLen(x);
          k_pos += l;

          EVVal(k_pos, E_Spos);

          suspend x;

          /*
           * tabmat has been resumed, restore &pos and fail.
           */
          if (i > StrLen(k_subject) + 1)
              runerr(205, kywd_pos);
          else {
              k_pos = i;
              EVVal(k_pos, E_Spos);
          }
          fail;
      }
   }
end


"i to j by k - generate successive values."

operator{*} ... toby(from, to, by)
   declare {
    tended struct descrip by1, from1, to1;
   }
   if cnv:(exact)C_integer(by) && cnv:(exact)C_integer(from) && cnv:C_integer(to) then {
       inline {
           /*
            * by must not be zero.
            */
           if (by == 0) {
	       irunerr(211, by);
	       errorfail;
           }
           /*
            * Count up or down (depending on relationship of from and to)
            *  and suspend each value in sequence, failing
            *  when the limit has been exceeded.
            */
           if (by > 0)
	       for ( ; from <= to; from += by) {
                   suspend C_integer from;
               }
           else
	       for ( ; from >= to; from += by) {
                   suspend C_integer from;
               }
           fail;
       }
   }
   else if cnv:(exact)integer(by,by1) && cnv:(exact)integer(from,from1)  && cnv:integer(to,to1) then {
       inline {
           tended struct descrip t;
           word sn = bigcmp(&by1, &zerodesc);
           if (sn == 0) {
	       runerr(211, by1);
	       errorfail;
           }
           if (sn > 0) {
               for ( ; bigcmp(&from1, &to1) <= 0; from1 = t) {
                   suspend from1;
                   bigadd(&from1, &by1, &t);
               }
           } else {
               for ( ; bigcmp(&from1, &to1) >= 0; from1 = t) {
                   suspend from1;
                   bigadd(&from1, &by1, &t);
               }
           }
           fail;
       }
   }
   else if cnv:C_double(from) && cnv:C_double(to) && cnv:C_double(by) then {
       inline {
           if (by == 0) {
               irunerr(211, (int)by);
               errorfail;
           }
           if (by > 0)
               for ( ; from <= to; from += by) {
                   suspend C_double from;
               }
           else
               for ( ; from >= to; from += by) {
                   suspend C_double from;
               }
           fail;
       }
   }
   else runerr(102)
end


" [x1, x2, ... ] - create an explicitly specified list."

operator{1} [...] llist(elems[n])
   body {
      tended struct b_list *hp;
      word nslots;

      nslots = n;
      if (nslots == 0)
         nslots = MinListSlots;
   
      /*
       * Allocate the list and a list block.
       */
      MemProtect(hp = alclist_raw(n, nslots));
   
      /*
       * Assign each argument to a list element.
       */
      memmove(hp->listhead->lelem.lslots, elems, n * sizeof(struct descrip));

/*  Not quite right -- should be after list() returns in case it fails */
      Desc_EVValD(hp, E_Lcreate, D_List);

      return list(hp);
      }
end
