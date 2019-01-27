/*
 * File: oasgn.r
 */

static void tvtbl_asgn	(dptr dest, dptr src);
static int subs_asgn	(dptr dest, dptr src);
static int same_string  (dptr x, dptr y);
static int overlap      (struct b_tvsubs *tv1, struct b_tvsubs *tv2);


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
      kywdhandler: {
           if (!is:null(y) && !is:coexpr(y))
               runerr(118, y);
           *VarLoc(x) = y;
         }
      kywdint:  {
            if (!cnv:C_integer(y, IntVal(*VarLoc(x))))
               runerr(101, y);
	}
      kywdpos: {
            word i;
            dptr sub;

            if (!cnv:C_integer(y, i)) {
               /* Fail on bigint */
               if (cnv:integer(y,y))
                   fail;
               runerr(101, y);
            }

            sub = VarLoc(x)+1;
            if (is:string(*sub))
                i = cvpos(i, StrLen(*sub));
            else
                i = cvpos(i, UcsBlk(*sub).length);

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
      if (same_string(&x, &y)) {
         word adj;
         /*
          * See comments in :=: below.
          */
         if (overlap(&TvsubsBlk(x), &TvsubsBlk(y)))
             fail;
         adj = TvsubsBlk(x).sslen;
         GeneralAsgn(x, dy)
         if (TvsubsBlk(y).sspos > TvsubsBlk(x).sspos)
             TvsubsBlk(y).sspos += TvsubsBlk(x).sslen - adj;
         adj = TvsubsBlk(y).sslen;
         GeneralAsgn(y, dx)
         if (TvsubsBlk(x).sspos > TvsubsBlk(y).sspos)
             TvsubsBlk(x).sspos += TvsubsBlk(y).sslen - adj;

         suspend x;

         /*
          * As above, but with dx, dy exchanged.
          */
         if (overlap(&TvsubsBlk(x), &TvsubsBlk(y)))
             fail;
         adj = TvsubsBlk(x).sslen;
         GeneralAsgn(x, dx)
         if (TvsubsBlk(y).sspos > TvsubsBlk(x).sspos)
             TvsubsBlk(y).sspos += TvsubsBlk(x).sslen - adj;
         adj = TvsubsBlk(y).sslen;
         GeneralAsgn(y, dy)
         if (TvsubsBlk(x).sspos > TvsubsBlk(y).sspos)
             TvsubsBlk(x).sspos += TvsubsBlk(y).sslen - adj;
      } else {
          /*
           * Do x := y, then y := x
           */
          GeneralAsgn(x, dy)
          GeneralAsgn(y, dx)

          suspend x;

          /*
           * If resumed, the assignments are undone.
           */
          GeneralAsgn(x, dx)
          GeneralAsgn(y, dy)
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
      if (same_string(&x, &y)) {
         word adj;
         /*
          * x and y are both substrings of the same string, check
          * whether substrings overlap (in which case fail), and
          * adjust substring positions as necessary after each
          * assignment, since the variable pointed to will have
          * changed its contents.
          */
         if (overlap(&TvsubsBlk(x), &TvsubsBlk(y)))
             fail;
         adj = TvsubsBlk(x).sslen;
         GeneralAsgn(x, dy)
         if (TvsubsBlk(y).sspos > TvsubsBlk(x).sspos)
             TvsubsBlk(y).sspos += TvsubsBlk(x).sslen - adj;
         adj = TvsubsBlk(y).sslen;
         GeneralAsgn(y, dx)
         if (TvsubsBlk(x).sspos > TvsubsBlk(y).sspos)
             TvsubsBlk(x).sspos += TvsubsBlk(y).sslen - adj;
      } else {
          /*
           * Do x := y, then y := x
           */
          GeneralAsgn(x, dy)
          GeneralAsgn(y, dx)
      }

      return x;
   }
end

/*
 * subs_asgn - perform assignment to a substring. Leave the updated substring
 *  in dest in case it is needed as the result of the assignment.
 */
static int subs_asgn(dptr dest, dptr src)
   {
   tended struct descrip deststr, srcstr, rsltstr;
   tended struct b_tvsubs *tvsub;
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

       if (is_ascii_string(src)) {
           srcstr = *src;

           /*
            * Check for various cases where we don't need to construct a new utf8 string.
            */
           if (tvsub->sslen == 0 && StrLen(srcstr) == 0) {
               rsltstr = deststr;
           } else if (prelen == 0 && StrLen(srcstr) == 0) {
               MakeStr(StrLoc(UcsBlk(deststr).utf8) + poststrt, postlen, &utf8_new);
               MakeDesc(D_Ucs, make_ucs_block(&utf8_new, 
                                              UcsBlk(deststr).length - tvsub->sslen), &rsltstr);
           } else if (postlen == 0 && StrLen(srcstr) == 0) {
               MakeStr(StrLoc(UcsBlk(deststr).utf8), prelen, &utf8_new);
               MakeDesc(D_Ucs, make_ucs_block(&utf8_new, 
                                              UcsBlk(deststr).length - tvsub->sslen), &rsltstr);
           } else if (prelen == 0 && postlen == 0) {
               MakeDesc(D_Ucs, make_ucs_block(src, StrLen(srcstr)), &rsltstr);
           } else {
               /*
                * Form the result string.
                *  Start by allocating space for the entire result.
                */
               len = prelen + StrLen(srcstr) + postlen;
               MakeStrMemProtect(alcstr(NULL, len), len, &utf8_new);

               /*
                * Copy the three sections into the reserved space.
                */
               memcpy(StrLoc(utf8_new), 
                      StrLoc(UcsBlk(deststr).utf8), 
                      prelen);
               memcpy(StrLoc(utf8_new) + prelen, 
                      StrLoc(srcstr), 
                      StrLen(srcstr));
               memcpy(StrLoc(utf8_new) + prelen + StrLen(srcstr), 
                      StrLoc(UcsBlk(deststr).utf8) + poststrt, 
                      postlen);

               MakeDesc(D_Ucs, make_ucs_block(&utf8_new,
                                              UcsBlk(deststr).length - tvsub->sslen + StrLen(srcstr)), &rsltstr);
           }
           newsslen = StrLen(srcstr);

       } else {
           if (!cnv:ucs(*src, srcstr))
               ReturnErrVal(128, *src, Error);
       
           /*
            * Check for various cases where we don't need to construct a new utf8 string.
            */
           if (tvsub->sslen == 0 && UcsBlk(srcstr).length == 0) {
               rsltstr = deststr;
           } else if (prelen == 0 && UcsBlk(srcstr).length == 0) {
               MakeStr(StrLoc(UcsBlk(deststr).utf8) + poststrt, postlen, &utf8_new);
               MakeDesc(D_Ucs, make_ucs_block(&utf8_new, 
                                              UcsBlk(deststr).length - tvsub->sslen), &rsltstr);
           } else if (postlen == 0 && UcsBlk(srcstr).length == 0) {
               MakeStr(StrLoc(UcsBlk(deststr).utf8), prelen, &utf8_new);
               MakeDesc(D_Ucs, make_ucs_block(&utf8_new, 
                                              UcsBlk(deststr).length - tvsub->sslen), &rsltstr);
           } else if (prelen == 0 && postlen == 0) {
               rsltstr = srcstr;
           } else {
               /*
                * Form the result string.
                *  Start by allocating space for the entire result.
                */
               len = prelen + StrLen(UcsBlk(srcstr).utf8) + postlen;
               MakeStrMemProtect(alcstr(NULL, len), len, &utf8_new);

               /*
                * Copy the three sections into the reserved space.
                */
               memcpy(StrLoc(utf8_new), 
                      StrLoc(UcsBlk(deststr).utf8), 
                      prelen);
               memcpy(StrLoc(utf8_new) + prelen, 
                      StrLoc(UcsBlk(srcstr).utf8), 
                      StrLen(UcsBlk(srcstr).utf8));
               memcpy(StrLoc(utf8_new) + prelen + StrLen(UcsBlk(srcstr).utf8), 
                      StrLoc(UcsBlk(deststr).utf8) + poststrt, 
                      postlen);

               MakeDesc(D_Ucs, make_ucs_block(&utf8_new,
                                              UcsBlk(deststr).length - tvsub->sslen + UcsBlk(srcstr).length), &rsltstr);
           }
           newsslen = UcsBlk(srcstr).length;
       }
   } else {
       /*
        * Be sure that the variable in the trapped variable points
        *  to a string and that the string is big enough to contain
        *  the substring.
        */
       prelen = tvsub->sspos - 1;
       poststrt = prelen + tvsub->sslen;
       postlen = StrLen(deststr) - poststrt;
       if (poststrt > StrLen(deststr))
           ReturnErrNum(205, Error);

       /* deststr must be a string, so ensure src is too */
       if (!cnv:string(*src, srcstr))
           ReturnErrVal(129, *src, Error);

       /*
        * Check for various cases where we don't need to construct a new string.
        */
       if (tvsub->sslen == 0 && StrLen(srcstr) == 0) {
           rsltstr = deststr;
       } else if (prelen == 0 && StrLen(srcstr) == 0) {
           MakeStr(StrLoc(deststr) + poststrt, postlen, &rsltstr);
       } else if (postlen == 0 && StrLen(srcstr) == 0) {
           MakeStr(StrLoc(deststr), prelen, &rsltstr);
       } else if (prelen == 0 && postlen == 0) {
           rsltstr = srcstr;
       } else {
           /*
            * Form the result string.
            *  Start by allocating space for the entire result.
            */
           len = prelen + StrLen(srcstr) + postlen;
           MakeStrMemProtect(alcstr(NULL, len), len, &rsltstr);

           /*
            * Copy the three sections into the reserved space.
            */
           memcpy(StrLoc(rsltstr), StrLoc(deststr), prelen);
           memcpy(StrLoc(rsltstr) + prelen, StrLoc(srcstr), StrLen(srcstr));
           memcpy(StrLoc(rsltstr) + prelen + StrLen(srcstr), StrLoc(deststr) + poststrt, postlen);
       }
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
         tended struct descrip tmp = tvsub->ssvar;
         tvtbl_asgn(&tmp, &rsltstr);
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
static void tvtbl_asgn(dptr dest, dptr src)
   {
   struct b_telem *te;
   union block **slot;
   struct b_table *tp;
   int res;

   /*
    * Allocate te now (even if we may not need it)
    * because slot cannot be tended.
    */
   MemProtect(te = alctelem());

   /*
    * First see if reference is in the table; if it is, just update
    *  the value.  Otherwise, allocate a new table entry.
    */
   slot = memb(TvtblBlk(*dest).clink, &TvtblBlk(*dest).tref, TvtblBlk(*dest).hashnum, &res);

   if (res) {
      /*
       * Do not need new te, just update existing entry.
       */
      dealcblk((union block *) te);
      (*slot)->telem.tval = *src;
      }
   else {
      /*
       * Link te into table, fill in entry.
       */
      tp = (struct b_table *) TvtblBlk(*dest).clink;
      tp->size++;

      te->clink = *slot;
      *slot = (union block *) te;

      te->hashnum = TvtblBlk(*dest).hashnum;
      te->tref = TvtblBlk(*dest).tref;
      te->tval = *src;
      
      if (TooCrowded(tp))		/* grow hash table if now too full */
         hgrow((union block *)tp);
      }
   }

/*
 * Return true iff the extent of the given substrings overlap.
 */
static int overlap(struct b_tvsubs *tv1, struct b_tvsubs *tv2)
{
    if (tv1->sspos > tv2->sspos)
        return (tv1->sspos < tv2->sspos + tv2->sslen);
    else if (tv2->sspos > tv1->sspos)
        return (tv2->sspos < tv1->sspos + tv1->sslen);
    else /* Same pos'ns, overlap if both are non-zero length */
        return (tv1->sslen > 0 && tv2->sslen > 0);
}

/*
 * Return true if both x and y are tvsubs, and their contained
 * variable refer to the same string.
 */
static int same_string(dptr x, dptr y)
{
    struct b_tvtbl *tx, *ty;

    if (!is:tvsubs(*x) || !is:tvsubs(*y))
        return 0;

    /* Caters for any type of var other than tvsubs */
    if (EqlDesc(TvsubsBlk(*x).ssvar, TvsubsBlk(*y).ssvar))
        return 1;

    if (!is:tvtbl(TvsubsBlk(*x).ssvar) || !is:tvtbl(TvsubsBlk(*y).ssvar))
        return 0;

    tx = &TvtblBlk(TvsubsBlk(*x).ssvar);
    ty = &TvtblBlk(TvsubsBlk(*y).ssvar);

    /*
     * The two tvtbls must refer to the same table and have an
     * equivalent (===) key.
     */

    if (tx->clink != ty->clink)
        return 0;

    return equiv(&tx->tref, &ty->tref);
}
