/*
 * File: ocat.r -- caterr, lconcat
 */
"x || y - concatenate strings x and y." 

operator || cater(x0, y0)
   body {
     tended struct descrip x, y;

     if (!cnv:string_or_ucs(x0, x))
         runerr(129, x0);
     if (!cnv:string_or_ucs(y0, y))
         runerr(129, y0);

     if (is:ucs(x) || is:ucs(y)) {
         tended struct descrip utf8_x, utf8_y, utf8;

         /*
          * Ensure both x and y are ucs.  Note that a simple
          * cnv:ucs(x) is not sufficient, since x0 may be for example
          * '\xff', and hence x is "\xff".  The former is convertible
          * to ucs, whilst the latter is not.
          */
         if (!is:ucs(x) && !cnv:ucs(x0, x))
             runerr(128, x0);
         if (!is:ucs(y) && !cnv:ucs(y0, y))
             runerr(128, y0);

         utf8_x = UcsBlk(x).utf8;
         utf8_y = UcsBlk(y).utf8;

         /*
          *  Optimization 0:  Check for zero-length operands.
          */

         if (StrLen(utf8_x) == 0)
             return y;
         if (StrLen(utf8_y) == 0)
             return x;

         /*
          *  Optimization 1:  The strings to be concatenated are already
          *   adjacent in memory; no allocation is required.
          */
         if (StrLoc(utf8_x) + StrLen(utf8_x) == StrLoc(utf8_y)) {
             StrLoc(utf8) = StrLoc(utf8_x);
             StrLen(utf8) = StrLen(utf8_x) + StrLen(utf8_y);
         }
         /*
          * Optimization 2: The end of x is at the end of the string space.
          *  Hence, x was the last string allocated and need not be
          *  re-allocated. y is appended to the string space and the
          *  result is pointed to the start of x.
          */
         else if ((StrLoc(utf8_x) + StrLen(utf8_x) == strfree) &&
                  (DiffPtrs(strend,strfree) > StrLen(utf8_y))) {
             /*
              * Append y to the end of the string space.
              */
             MemProtect(alcstr(StrLoc(utf8_y),StrLen(utf8_y)));
             StrLoc(utf8) = StrLoc(utf8_x);
             StrLen(utf8) = StrLen(utf8_x) + StrLen(utf8_y);
         }
         /*
          * Otherwise, allocate space for x and y, and copy them
          *  to the end of the string space.
          */
         else {
             MemProtect(StrLoc(utf8) = alcstr(NULL, StrLen(utf8_x) + StrLen(utf8_y)));
             memcpy(StrLoc(utf8), StrLoc(utf8_x), StrLen(utf8_x));
             memcpy(StrLoc(utf8) + StrLen(utf8_x), StrLoc(utf8_y), StrLen(utf8_y));
             StrLen(utf8) = StrLen(utf8_x) + StrLen(utf8_y);
         }
         return ucs(make_ucs_block(&utf8, UcsBlk(x).length + UcsBlk(y).length));
     } else {
         tended struct descrip result;
         /* Neither ucs, so both args must be strings */

         /*
          *  Optimization 0:  Check for zero-length operands.
          */
         if (StrLen(x) == 0)
             return y;
         if (StrLen(y) == 0)
             return x;

         /*
          *  Optimization 1:  The strings to be concatenated are already
          *   adjacent in memory; no allocation is required.
          */
         if (StrLoc(x) + StrLen(x) == StrLoc(y)) {
             StrLoc(result) = StrLoc(x);
             StrLen(result) = StrLen(x) + StrLen(y);
             return result;
         }

         /*
          * Optimization 2: The end of x is at the end of the string space.
          *  Hence, x was the last string allocated and need not be
          *  re-allocated. y is appended to the string space and the
          *  result is pointed to the start of x.
          */
         if ((StrLoc(x) + StrLen(x) == strfree) &&
             (DiffPtrs(strend,strfree) > StrLen(y))) {
             /*
              * Append y to the end of the string space.
              */
             MemProtect(alcstr(StrLoc(y),StrLen(y)));
             /*
              *  Set the result and return.
              */
             StrLoc(result) = StrLoc(x);
             StrLen(result) = StrLen(x) + StrLen(y);
             return result;
         }

         /*
          * Otherwise, allocate space for x and y, and copy them
          *  to the end of the string space.
          */
         MemProtect(StrLoc(result) = alcstr(NULL, StrLen(x) + StrLen(y)));
         memcpy(StrLoc(result), StrLoc(x), StrLen(x));
         memcpy(StrLoc(result) + StrLen(x), StrLoc(y), StrLen(y));

         /*
          *  Set the length of the result and return.
          */
         StrLen(result) = StrLen(x) + StrLen(y);
         return result;
     }
   }
end


"x ||| y - concatenate lists x and y."

operator ||| lconcat(x, y)
   /*
    * x and y must be lists.
    */
   if !is:list(x) then
      runerr(108, x)
   if !is:list(y) then
      runerr(108, y)


   body {
      register struct b_list *bp1;
      register struct b_lelem *lp1;
      word size1, size2, size3;

      /*
       * Get the size of both lists.
       */
      size1 = ListBlk(x).size;
      size2 = ListBlk(y).size;
      size3 = size1 + size2;

      MemProtect(bp1 = (struct b_list *)alclist_raw(size3, size3));
      lp1 = (struct b_lelem *) (bp1->listhead);

      /*
       * Make a copy of both lists in adjacent slots.
       */
      cpslots(&x, lp1->lslots, (word)1, size1 + 1);
      cpslots(&y, lp1->lslots + size1, (word)1, size2 + 1);

      BlkLoc(x) = (union block *)bp1;

      EVValD(&x, E_Lcreate);

      return x;
      }
end
