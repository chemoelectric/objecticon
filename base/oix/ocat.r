/*
 * File: ocat.r -- caterr, lconcat
 */
"x || y - concatenate strings x and y." 

operator || cat(x, y)
   body {
     if (need_ucs(&x) || need_ucs(&y)) {
         tended struct descrip utf8_x, utf8_y, utf8;

         if (is_ascii_string(&x)) {
             if (!cnv:ucs(y, y))
                 runerr(128, y);

             utf8_y = UcsBlk(y).utf8;

             /*
              *  Optimization 0:  Check for zero-length operands.
              */

             if (StrLen(x) == 0)
                 return y;
             if (StrLen(utf8_y) == 0)
                 return ucs(make_ucs_block(&x, StrLen(x)));

             /*
              *  Optimization 1:  The strings to be concatenated are already
              *   adjacent in memory; no allocation is required.
              */
             if (StrLoc(x) + StrLen(x) == StrLoc(utf8_y))
                 MakeStr(StrLoc(x), StrLen(x) + StrLen(utf8_y), &utf8);

             /*
              * Optimization 2: The end of x is at the end of the string space.
              *  Hence, x was the last string allocated and need not be
              *  re-allocated. y is appended to the string space and the
              *  result is pointed to the start of x.
              */
             else if ((StrLoc(x) + StrLen(x) == strfree) &&
                      (UDiffPtrs(strend,strfree) > StrLen(utf8_y))) {
                 /*
                  * Append y to the end of the string space.
                  */
                 MemProtect(alcstr(StrLoc(utf8_y), StrLen(utf8_y)));
                 MakeStr(StrLoc(x), StrLen(x) + StrLen(utf8_y), &utf8);
             }
             /*
              * Otherwise, allocate space for x and y, and copy them
              *  to the end of the string space.
              */
             else {
                 MakeStrMemProtect(alcstr(NULL, StrLen(x) + StrLen(utf8_y)), 
                                   StrLen(x) + StrLen(utf8_y), &utf8);
                 memcpy(StrLoc(utf8), StrLoc(x), StrLen(x));
                 memcpy(StrLoc(utf8) + StrLen(x), StrLoc(utf8_y), StrLen(utf8_y));
             }
             return ucs(make_ucs_block(&utf8, StrLen(x) + UcsBlk(y).length));
         } else if (is_ascii_string(&y)) {

             if (!cnv:ucs(x, x))
                 runerr(128, x);

             utf8_x = UcsBlk(x).utf8;

             /*
              *  Optimization 0:  Check for zero-length operands.
              */

             if (StrLen(utf8_x) == 0)
                 return ucs(make_ucs_block(&y, StrLen(y)));
             if (StrLen(y) == 0)
                 return x;

             /*
              *  Optimization 1:  The strings to be concatenated are already
              *   adjacent in memory; no allocation is required.
              */
             if (StrLoc(utf8_x) + StrLen(utf8_x) == StrLoc(y))
                 MakeStr(StrLoc(utf8_x), StrLen(utf8_x) + StrLen(y), &utf8);

             /*
              * Optimization 2: The end of x is at the end of the string space.
              *  Hence, x was the last string allocated and need not be
              *  re-allocated. y is appended to the string space and the
              *  result is pointed to the start of x.
              */
             else if ((StrLoc(utf8_x) + StrLen(utf8_x) == strfree) &&
                      (UDiffPtrs(strend,strfree) > StrLen(y))) {
                 /*
                  * Append y to the end of the string space.
                  */
                 MemProtect(alcstr(StrLoc(y), StrLen(y)));
                 MakeStr(StrLoc(utf8_x), StrLen(utf8_x) + StrLen(y), &utf8);
             }
             /*
              * Otherwise, allocate space for x and y, and copy them
              *  to the end of the string space.
              */
             else {
                 MakeStrMemProtect(alcstr(NULL, StrLen(utf8_x) + StrLen(y)), 
                                   StrLen(utf8_x) + StrLen(y), &utf8);
                 memcpy(StrLoc(utf8), StrLoc(utf8_x), StrLen(utf8_x));
                 memcpy(StrLoc(utf8) + StrLen(utf8_x), StrLoc(y), StrLen(y));
             }
             return ucs(make_ucs_block(&utf8, UcsBlk(x).length + StrLen(y)));

         } else {
             if (!cnv:ucs(x, x))
                 runerr(128, x);
             if (!cnv:ucs(y, y))
                 runerr(128, y);

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
             if (StrLoc(utf8_x) + StrLen(utf8_x) == StrLoc(utf8_y))
                 MakeStr(StrLoc(utf8_x), StrLen(utf8_x) + StrLen(utf8_y), &utf8);

             /*
              * Optimization 2: The end of x is at the end of the string space.
              *  Hence, x was the last string allocated and need not be
              *  re-allocated. y is appended to the string space and the
              *  result is pointed to the start of x.
              */
             else if ((StrLoc(utf8_x) + StrLen(utf8_x) == strfree) &&
                      (UDiffPtrs(strend,strfree) > StrLen(utf8_y))) {
                 /*
                  * Append y to the end of the string space.
                  */
                 MemProtect(alcstr(StrLoc(utf8_y), StrLen(utf8_y)));
                 MakeStr(StrLoc(utf8_x), StrLen(utf8_x) + StrLen(utf8_y), &utf8);
             }
             /*
              * Otherwise, allocate space for x and y, and copy them
              *  to the end of the string space.
              */
             else {
                 MakeStrMemProtect(alcstr(NULL, StrLen(utf8_x) + StrLen(utf8_y)), 
                                   StrLen(utf8_x) + StrLen(utf8_y), &utf8);
                 memcpy(StrLoc(utf8), StrLoc(utf8_x), StrLen(utf8_x));
                 memcpy(StrLoc(utf8) + StrLen(utf8_x), StrLoc(utf8_y), StrLen(utf8_y));
             }
             return ucs(make_ucs_block(&utf8, UcsBlk(x).length + UcsBlk(y).length));
         }
     } else {
         tended struct descrip result;

         /* Neither ucs, so both args must be strings */

         if (!cnv:string(x, x))
             runerr(129, x);
         if (!cnv:string(y, y))
             runerr(129, y);

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
             MakeStr(StrLoc(x), StrLen(x) + StrLen(y), &result);
             return result;
         }

         /*
          * Optimization 2: The end of x is at the end of the string space.
          *  Hence, x was the last string allocated and need not be
          *  re-allocated. y is appended to the string space and the
          *  result is pointed to the start of x.
          */
         if ((StrLoc(x) + StrLen(x) == strfree) &&
             (UDiffPtrs(strend,strfree) > StrLen(y))) {
             /*
              * Append y to the end of the string space.
              */
             MemProtect(alcstr(StrLoc(y),StrLen(y)));
             /*
              *  Set the result and return.
              */
             MakeStr(StrLoc(x), StrLen(x) + StrLen(y), &result);
             return result;
         }

         /*
          * Otherwise, allocate space for x and y, and copy them
          *  to the end of the string space.
          */
         MakeStrMemProtect(alcstr(NULL, StrLen(x) + StrLen(y)), StrLen(x) + StrLen(y), &result);
         memcpy(StrLoc(result), StrLoc(x), StrLen(x));
         memcpy(StrLoc(result) + StrLen(x), StrLoc(y), StrLen(y));

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
      tended struct b_list *bp1;          
      struct b_lelem *lp1;           /* Doesn't need to be tended */
      word size1, size2, size3;

      /*
       * Get the size of both lists.
       */
      size1 = ListBlk(x).size;
      size2 = ListBlk(y).size;
      size3 = size1 + size2;

      MemProtect(bp1 = alclist_raw(size3, size3));

      /*
       * Make a copy of both lists in adjacent slots.
       */
      lp1 = (struct b_lelem *) (bp1->listhead);
      cpslots(&x, lp1->lslots, 1, size1);
      cpslots(&y, lp1->lslots + size1, 1, size2);

      BlkLoc(x) = (union block *)bp1;

      EVValD(&x, E_Lcreate);

      return x;
      }
end
