/*
 * File: oasgn.r
 */

static void tvtbl_asgn	(dptr dest, dptr src);
static int subs_asgn	(dptr dest, dptr src);


/*
 * GeneralAsgn - perform the assignment x := y, where x is known to be
 *  a variable and y is has been dereferenced.
 */
#begdef GeneralAsgn(x, y)
{
   EVValD(&x, E_Assign);

   type_case x of {
      named_var: {
           *VarLoc(x) = y;
       }
      struct_var: {
           *OffsetVarLoc(x) = y;
       }
      tvsubs: {
           if (subs_asgn(&x, &y) == Error)
              runerr(0);
        }
      tvtbl: {
           tvtbl_asgn(&x, &y);
         }
      kywdany: {
	    *VarLoc(x) = y;
         }
      kywdint:  {
            word i;

            if (!cnv:C_integer(y, i))
               runerr(101, y);
            IntVal(*VarLoc(x)) = i;
	}
      kywdpos: {
            word i;
            dptr sub;

            if (!cnv:C_integer(y, i))
               runerr(101, y);

            sub = VarLoc(x)+1;
            if (is:string(*sub))
                i = cvpos((long)i, StrLen(*sub));
            else
                i = cvpos((long)i, UcsBlk(*sub).length);

            if (i == CvtFail)
               fail;
	    IntVal(*VarLoc(x)) = i;
         }
      kywdsubj: {
            if (!cnv:string_or_ucs(y, *VarLoc(x)))
               runerr(129, y);
	    IntVal(*(VarLoc(x)-1)) = 1;
         }
      kywdstr: {
         if (!cnv:string_or_ucs(y, *VarLoc(x)))
            runerr(129, y);
      }
      default: {
         syserr("Unknown variable type");
      }
   }


   EVValD(&y, E_Value);

}
#enddef


"x := y - assign y to x."

operator := asgn(underef x, y)

   if !is:variable(x) then
      runerr(111, x)

  body {

      GeneralAsgn(x, y)

      /*
       * The returned result is the variable to which assignment is being
       *  made.
       */
      return x;
   }
end


"x <- y - assign y to x."
" Reverses assignment if resumed."

operator <- rasgn(underef x -> saved_x, y)

   if !is:variable(x) then
      runerr(111, x)

   body {
      GeneralAsgn(x, y)
      suspend x;
      GeneralAsgn(x, saved_x)
      fail;
 }
end


"x <-> y - swap values of x and y."
" Reverses swap if resumed."

operator <-> rswap(underef x -> dx, underef y -> dy)

   if !is:variable(x) then
      runerr(111, x)
   if !is:variable(y) then
      runerr(111, y)

   body {
      tended union block *bp_x, *bp_y;
      word adj1 = 0;
      word adj2 = 0;

      if (is:tvsubs(x) && is:tvsubs(y)) {
         bp_x = BlkLoc(x);
         bp_y = BlkLoc(y);
         if (EqlDesc(bp_x->tvsubs.ssvar, bp_y->tvsubs.ssvar)) {
            /*
             * x and y are both substrings of the same string, set
             *  adj1 and adj2 for use in locating the substrings after
             *  an assignment has been made.  If x is to the right of y,
             *  set adj1 := *x - *y, otherwise if y is to the right of
             *  x, set adj2 := *y - *x.  Note that the adjustment
             *  values may be negative.
             */
            if (bp_x->tvsubs.sspos > bp_y->tvsubs.sspos)
               adj1 = bp_x->tvsubs.sslen - bp_y->tvsubs.sslen;
            else if (bp_y->tvsubs.sspos > bp_x->tvsubs.sspos)
               adj2 = bp_y->tvsubs.sslen - bp_x->tvsubs.sslen;
   	    }
      }

      /*
       * Do x := y
       */
      GeneralAsgn(x, dy)

      if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj2 != 0)
            /*
             * Arg2 is to the right of Arg1 and the assignment Arg1 := Arg2 has
             *  shifted the position of Arg2.  Add adj2 to the position of Arg2
             *  to account for the replacement of Arg1 by Arg2.
             */
            bp_y->tvsubs.sspos += adj2;
      }

      /*
       * Do y := x
       */
       GeneralAsgn(y, dx)

       if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj1 != 0)
            /*
             * Arg1 is to the right of Arg2 and the assignment Arg2 := Arg1
             *  has shifted the position of Arg1.  Add adj2 to the position
             *  of Arg1 to account for the replacement of Arg2 by Arg1.
             */
            bp_x->tvsubs.sspos += adj1;
       }


      suspend x;

      /*
       * If resumed, the assignments are undone.  Note that the string position
       *  adjustments are opposite those done earlier.
       */
      GeneralAsgn(x, dx)
      if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj2 != 0)
           bp_y->tvsubs.sspos -= adj2;
      }

      GeneralAsgn(y, dy)
      if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj1 != 0)
            bp_x->tvsubs.sspos -= adj1;
      }

      fail;
   }
end


"x :=: y - swap values of x and y."

operator :=: swap(underef x -> dx, underef y -> dy)
   /*
    * x and y must be variables.
    */
   if !is:variable(x) then
      runerr(111, x)
   if !is:variable(y) then
      runerr(111, y)

   body {
      tended union block *bp_x, *bp_y;
      word adj1 = 0;
      word adj2 = 0;

      if (is:tvsubs(x) && is:tvsubs(y)) {
         bp_x = BlkLoc(x);
         bp_y = BlkLoc(y);
         if (EqlDesc(bp_x->tvsubs.ssvar, bp_y->tvsubs.ssvar)) {
            /*
             * x and y are both substrings of the same string, set
             *  adj1 and adj2 for use in locating the substrings after
             *  an assignment has been made.  If x is to the right of y,
             *  set adj1 := *x - *y, otherwise if y is to the right of
             *  x, set adj2 := *y - *x.  Note that the adjustment
             *  values may be negative.
             */
            if (bp_x->tvsubs.sspos > bp_y->tvsubs.sspos)
               adj1 = bp_x->tvsubs.sslen - bp_y->tvsubs.sslen;
            else if (bp_y->tvsubs.sspos > bp_x->tvsubs.sspos)
               adj2 = bp_y->tvsubs.sslen - bp_x->tvsubs.sslen;
   	    }
      }

      /*
       * Do x := y
       */
      GeneralAsgn(x, dy)

      if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj2 != 0)
            /*
             * Arg2 is to the right of Arg1 and the assignment Arg1 := Arg2 has
             *  shifted the position of Arg2.  Add adj2 to the position of Arg2
             *  to account for the replacement of Arg1 by Arg2.
             */
            bp_y->tvsubs.sspos += adj2;
      }

      /*
       * Do y := x
       */
      GeneralAsgn(y, dx)

      if (is:tvsubs(x) && is:tvsubs(y)) {
         if (adj1 != 0)
            /*
             * Arg1 is to the right of Arg2 and the assignment Arg2 := Arg1
             *  has shifted the position of Arg1.  Add adj2 to the position
             *  of Arg1 to account for the replacement of Arg2 by Arg1.
             */
            bp_x->tvsubs.sspos += adj1;
      }

      return x;
   }
end

/*
 * subs_asgn - perform assignment to a substring. Leave the updated substring
 *  in dest in case it is needed as the result of the assignment.
 */
int subs_asgn(dptr dest, dptr src)
   {
   tended struct descrip deststr, srcstr, rsltstr;
   tended struct b_tvsubs *tvsub;

   char *s;
   word len;
   word prelen;   /* length of portion of string before substring */
   word poststrt; /* start of portion of string following substring */
   word postlen;  /* length of portion of string following substring */
   word newsslen;

   tvsub = &TvsubsBlk(*dest);
   deref(&tvsub->ssvar, &deststr);

   if (!is:string(deststr) && !is:ucs(deststr))
      ReturnErrVal(129, deststr, Error);

   if (is:ucs(deststr) || need_ucs(src)) {
       tended struct descrip utf8_new;

       if (!cnv:ucs(deststr, deststr))
           ReturnErrVal(128, deststr, Error);

       if (!cnv:ucs(*src, srcstr))
           ReturnErrVal(128, *src, Error);
       
       if (tvsub->sspos + tvsub->sslen - 1 > UcsBlk(deststr).length)
           ReturnErrNum(205, Error);

       if (tvsub->sslen == 0) {
           poststrt = prelen = ucs_utf8_ptr(&UcsBlk(deststr), tvsub->sspos) - 
               StrLoc(UcsBlk(deststr).utf8);
       } else {
           struct descrip utf8_mid;
           utf8_substr(&UcsBlk(deststr),
                       tvsub->sspos,
                       tvsub->sslen,
                       &utf8_mid);
           prelen = StrLoc(utf8_mid) - StrLoc(UcsBlk(deststr).utf8);
           poststrt = prelen + StrLen(utf8_mid);
       }
       postlen = StrLen(UcsBlk(deststr).utf8) - poststrt;
       /*
        * Form the result string.
        *  Start by allocating space for the entire result.
        */
       len = prelen + StrLen(UcsBlk(srcstr).utf8) + postlen;
       MemProtect(StrLoc(utf8_new) = reserve(Strings, len));
       StrLen(utf8_new) = len;

       /*
        * Copy the three sections into the reserved space.
        */
       alcstr(StrLoc(UcsBlk(deststr).utf8), prelen);
       alcstr(StrLoc(UcsBlk(srcstr).utf8), StrLen(UcsBlk(srcstr).utf8));
       alcstr(StrLoc(UcsBlk(deststr).utf8) + poststrt, postlen);

       rsltstr.dword = D_Ucs;
       BlkLoc(rsltstr) = (union block *)
           make_ucs_block(&utf8_new,
                          UcsBlk(deststr).length - tvsub->sslen + UcsBlk(srcstr).length);

       newsslen = UcsBlk(srcstr).length;
   } else {
       /* deststr must be a string, so ensure src is too */
       if (!cnv:string(*src, srcstr))
           ReturnErrVal(129, *src, Error);

       /*
        * Be sure that the variable in the trapped variable points
        *  to a string and that the string is big enough to contain
        *  the substring.
        */
       prelen = tvsub->sspos - 1;
       poststrt = prelen + tvsub->sslen;
       if (poststrt > StrLen(deststr))
           ReturnErrNum(205, Error);

       /*
        * Form the result string.
        *  Start by allocating space for the entire result.
        */
       len = prelen + StrLen(srcstr) + StrLen(deststr) - poststrt;
       MemProtect(s = alcstr(NULL, len));
       StrLoc(rsltstr) = s;
       StrLen(rsltstr) = len;
       /*
        * First, copy the portion of the substring string to the left of
        *  the substring into the string space.
        */
   
       memcpy(StrLoc(rsltstr), StrLoc(deststr), prelen);
   
       /*
        * Copy the string to be assigned into the string space,
        *  effectively concatenating it.
        */
   
       memcpy(StrLoc(rsltstr)+prelen, StrLoc(srcstr), StrLen(srcstr));
   
       /*
        * Copy the portion of the substring to the right of
        *  the substring into the string space, completing the
        *  result.
        */
    
   
       postlen = StrLen(deststr) - poststrt;
   
       memcpy(StrLoc(rsltstr)+prelen+StrLen(srcstr), StrLoc(deststr)+poststrt, postlen);

       newsslen = StrLen(srcstr);
   }

   /*
    * Perform the assignment and update the trapped variable.
    */
   type_case tvsub->ssvar of {
      named_var: {
          *VarLoc(tvsub->ssvar) = rsltstr;
      }
      struct_var: {
          *OffsetVarLoc(tvsub->ssvar) = rsltstr;
      }
      kywdany: {
         *VarLoc(tvsub->ssvar) = rsltstr;
         }
      kywdstr: {
         *VarLoc(tvsub->ssvar) = rsltstr;
         }
      kywdsubj: {
         *VarLoc(tvsub->ssvar) = rsltstr;
         k_pos = 1;
         }
      tvtbl: {
         tvtbl_asgn(&tvsub->ssvar, &rsltstr);
         }
      default: {
         syserr("Unknown variable type");
         }
   }

   tvsub->sslen = newsslen;

   EVVal(tvsub->sslen, E_Ssasgn);
   return Succeeded;
   }

/*
 * tvtbl_asgn - perform an assignment to a table element trapped variable,
 *  inserting the element in the table if needed.
 */
void tvtbl_asgn(dptr dest, dptr src)
   {
   tended struct b_tvtbl *bp;
   tended struct descrip tval;
   struct b_telem *te;
   union block **slot;
   struct b_table *tp;
   int res;

   /*
    * Allocate te now (even if we may not need it)
    * because slot cannot be tended.
    */
   bp = &TvtblBlk(*dest);	/* Save params to tended vars */
   tval = *src;
   MemProtect(te = alctelem());

   /*
    * First see if reference is in the table; if it is, just update
    *  the value.  Otherwise, allocate a new table entry.
    */
   slot = memb(bp->clink, &bp->tref, bp->hashnum, &res);

   if (res == 1) {
      /*
       * Do not need new te, just update existing entry.
       */
      dealcblk((union block *) te);
      (*slot)->telem.tval = tval;
      }
   else {
      /*
       * Link te into table, fill in entry.
       */
      tp = (struct b_table *) bp->clink;
      tp->size++;

      te->clink = *slot;
      *slot = (union block *) te;

      te->hashnum = bp->hashnum;
      te->tref = bp->tref;
      te->tval = tval;
      
      if (TooCrowded(tp))		/* grow hash table if now too full */
         hgrow((union block *)tp);
      }
   }
