/*
 * File: omisc.r
 */

"^x - create a refreshed copy of a co-expression."
/*
 * ^x - return an entry block for co-expression x from the refresh block.
 */
operator ^ refresh(x)
   if !is:coexpr(x) then
       runerr(118, x)

   body {
       tended struct b_coexpr *curr, *coex;

       curr = &CoexprBlk(x);

       if (curr->main_of)	/* &main cannot be refreshed */
           runerr(215, x);

       MemProtect(coex = alccoexp());
       MemProtect(coex->base_pf = alc_p_frame(curr->base_pf->proc, curr->base_pf->fvars));
       coex->main_of = 0;
       coex->tvalloc = 0;
       coex->size = 0;
       coex->level = 1;
       coex->failure_label = coex->start_label = coex->base_pf->ipc = curr->start_label;
       coex->curr_pf = coex->base_pf;
       coex->sp = (struct frame *)coex->base_pf;
       return coexpr(coex);
      }

end


function cocopy(x)
   if !is:coexpr(x) then
       runerr(118, x)

   body {
       tended struct b_coexpr *curr, *coex;
       dptr dp1, dp2;

       curr = &CoexprBlk(x);

       if (curr->main_of)	/* &main cannot be copied */
           runerr(216, x);

       MemProtect(coex = alccoexp());
       MemProtect(coex->base_pf = alc_p_frame(curr->base_pf->proc, 0));
       coex->main_of = 0;
       coex->tvalloc = 0;
       coex->size = 0;
       coex->level = 1;
       coex->failure_label = coex->start_label = coex->base_pf->ipc = curr->start_label;
       coex->curr_pf = coex->base_pf;
       coex->sp = (struct frame *)coex->base_pf;
       if (curr->base_pf->fvars) {
           dp1 = curr->base_pf->fvars->desc;
           dp2 = coex->base_pf->fvars->desc;
           while (dp1 < curr->base_pf->fvars->desc_end)
               *dp2++ = *dp1++;
       }
       return coexpr(coex);
      }

end



"*x - return size of string or object x."

operator * size(x)
  body {
   type_case x of {
      string: return C_integer StrLen(x);
      ucs:    return C_integer UcsBlk(x).length;
      list:   return C_integer ListBlk(x).size;
      table:  return C_integer TableBlk(x).size;
      set:    return C_integer SetBlk(x).size;
      cset:   return C_integer CsetBlk(x).size;
      record: return C_integer RecordBlk(x).constructor->n_fields;
      coexpr: return C_integer CoexprBlk(x).size;
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

operator = tabmat(x)
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
          j = UcsBlk(k_subject).length - i + 1;
          if (j < UcsBlk(x).length)
              fail;

          /*
           * Get pointers to x (s1) and &subject (s2).  Compare them on a byte-wise
           *  basis and fail if s1 doesn't match s2 for *s1 characters.
           */
          s1 = StrLoc(UcsBlk(x).utf8);
          s2 = ucs_utf8_ptr(&UcsBlk(k_subject), i);
          l = UcsBlk(x).length;
          while (l-- > 0) {
              if (utf8_iter(&s1) != utf8_iter(&s2))
                  fail;
          }

          /*
           * Increment &pos to tab over the matched string and suspend the
           *  matched string.
           */
          l = UcsBlk(x).length;
          k_pos += l;

          suspend x;

          /*
           * tabmat has been resumed, restore &pos and fail.
           */
          if (i > UcsBlk(k_subject).length + 1)
              runerr(205, kywd_pos);
          else {
              k_pos = i;
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

          suspend x;

          /*
           * tabmat has been resumed, restore &pos and fail.
           */
          if (i > StrLen(k_subject) + 1)
              runerr(205, kywd_pos);
          else 
              k_pos = i;

          fail;
      }
   }
end


"i to j by k - generate successive values."

operator ... toby(from, to, by)
   body {
    word by0, from0, to0;
    tended struct descrip by1, from1, to1;
    double by2, from2, to2;
    if (cnv:(exact)C_integer(by,by0) && cnv:(exact)C_integer(from,from0) && cnv:C_integer(to,to0)) {
        /*
         * by must not be zero.
         */
        if (by0 == 0) {
            irunerr(211, by0);
            errorfail;
        }

        if (by0 > 0) {
            if (to0 + by0 > to0) {
                while (from0 <= to0) {
                    suspend C_integer from0;
                    from0 += by0;
                }
            } else {
                word t;
                while (from0 <= to0) {
                    suspend C_integer from0;
                    t = from0;
                    from0 += by0;
                    if (from0 < t)
                        break;
                }
            }
        } else {     /* by < 0 */
            if (to0 + by0 < to0) {
                while (from0 >= to0) {
                    suspend C_integer from0;
                    from0 += by0;
                }
            } else {
                word t;
                while (from0 >= to0) {
                    suspend C_integer from0;
                    t = from0;
                    from0 += by0;
                    if (from0 > t)
                        break;
                }
            }
        }
        fail;
   }
   else if (cnv:(exact)integer(by,by1) && cnv:(exact)integer(from,from1) && cnv:integer(to,to1)) {
       word sn = bigcmp(&by1, &zerodesc);
       if (sn == 0) {
           runerr(211, by1);
           errorfail;
       }
       if (sn > 0) {
           for ( ; bigcmp(&from1, &to1) <= 0;) {
               suspend from1;
               bigadd(&from1, &by1, &from1);
           }
       } else {
           for ( ; bigcmp(&from1, &to1) >= 0;) {
               suspend from1;
               bigadd(&from1, &by1, &from1);
           }
       }
       fail;
   }
   else if (cnv:C_double(from,from2) && cnv:C_double(to,to2) && cnv:C_double(by,by2)) {
       if (by2 == 0) {
           irunerr(211, (int)by2);
           errorfail;
       }
       if (by2 > 0)
           for ( ; from2 <= to2; from2 += by2) {
               suspend C_double from2;
           }
       else
           for ( ; from2 >= to2; from2 += by2) {
               suspend C_double from2;
           }
       fail;
   }
   else runerr(102);
  }
end



