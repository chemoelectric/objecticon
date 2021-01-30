/*
 * File: omisc.r
 */

/*
 * ^x - create a refreshed copy of a co-expression.
 */
operator ^ refresh(x)
   if !is:coexpr(x) then
       runerr(118, x)

   body {
       tended struct b_coexpr *coex;

       if (CoexprBlk(x).main_of)	/* &main cannot be refreshed */
           runerr(215, x);

       MemProtect(coex = alccoexp());
       MemProtect(coex->base_pf = alc_p_frame(CoexprBlk(x).base_pf->proc, CoexprBlk(x).base_pf->fvars));
       coex->main_of = 0;
       coex->tvalloc = 0;
       coex->level = 1;
       coex->failure_label = coex->start_label = coex->base_pf->ipc = CoexprBlk(x).start_label;
       coex->curr_pf = coex->base_pf;
       coex->sp = (struct frame *)coex->base_pf;
       return coexpr(coex);
      }

end


function cocopy(x)
   if !is:coexpr(x) then
       runerr(118, x)

   body {
       tended struct b_coexpr *coex;
       dptr dp1, dp2;

       if (CoexprBlk(x).main_of)	/* &main cannot be copied */
           runerr(216, x);

       MemProtect(coex = alccoexp());
       MemProtect(coex->base_pf = alc_p_frame(CoexprBlk(x).base_pf->proc, 0));
       coex->main_of = 0;
       coex->tvalloc = 0;
       coex->level = 1;
       coex->failure_label = coex->start_label = coex->base_pf->ipc = CoexprBlk(x).start_label;
       coex->curr_pf = coex->base_pf;
       coex->sp = (struct frame *)coex->base_pf;
       if (CoexprBlk(x).base_pf->fvars) {
           dp1 = CoexprBlk(x).base_pf->fvars->desc;
           dp2 = coex->base_pf->fvars->desc;
           while (dp1 < CoexprBlk(x).base_pf->fvars->desc_end)
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
      default: {
         /*
          * Try to convert it to a string.
          */
         if (!cnv:string(x,x))
            runerr(112, x);	/* no notion of size */
         return C_integer StrLen(x);
      }
   }
 }
end


"=x - tab(match(x)).  Reverses effects if resumed."

operator = tabmat(x)
   body {
      char *ssub;
      word i, j;
      tended struct descrip sub;

      /*
       * Make a copy of &pos.
       */
      i = k_pos;

      if (is:ucs(k_subject)) {
          /*
           * If x is a simple ascii string, we can avoid a conversion to ucs.
           */
          if (is_ascii_string(&x)) {
              /*
               * Fail if &subject[&pos:0] is not of sufficient length to contain x.
               */
              j = UcsBlk(k_subject).length - i + 1;
              if (j < StrLen(x))
                  fail;

              /*
               * Compare x to &subject[&pos+:*x]
               */
              ssub = ucs_utf8_ptr(&UcsBlk(k_subject), i);
              if (StrMemcmp(ssub, x) != 0)
                  fail;

              /*
               * Increment &pos to tab over the matched string.
               */
              k_pos += StrLen(x);

              /*
               * Suspend the matched string.
               */
              if (_lhs) {
                  MakeStr(ssub, StrLen(x), &sub);
                  suspend ucs(make_ucs_block(&sub, StrLen(x)));
              } else
                  suspend;

          } else {

              /*
               * x must be a ucs.
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
               * Compare x to &subject[&pos+:*x]
               */
              ssub = ucs_utf8_ptr(&UcsBlk(k_subject), i);
              if (SubStrLen(ssub, UcsBlk(k_subject).utf8) < StrLen(UcsBlk(x).utf8) ||
                  StrMemcmp(ssub, UcsBlk(x).utf8) != 0)
                  fail;

              /*
               * Increment &pos to tab over the matched string.
               */
              k_pos += UcsBlk(x).length;

              /*
               * Suspend the matched string.
               */
              if (_lhs) {
                  MakeStr(ssub, StrLen(UcsBlk(x).utf8), &sub);
                  suspend ucs(make_ucs_block(&sub, UcsBlk(x).length));
              } else
                  suspend;
          }

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
           * Compare x to &subject[&pos+:*x]
           */
          ssub = StrLoc(k_subject) + i - 1;
          if (StrMemcmp(ssub, x) != 0)
              fail;

          /*
           * Increment &pos to tab over the matched string.
           */
          k_pos += StrLen(x);

          /*
           * Suspend the matched string.
           */
          suspend string(StrLen(x), ssub);
      }

      /*
       * tabmat has been resumed, restore &pos and fail.  Note that the type of
       * &subject may have changed since we suspended.
       */

      if (is:string(k_subject))
          j = StrLen(k_subject);
      else
          j = UcsBlk(k_subject).length;

      if (i > j + 1)
          Irunerr(205, i);
      else 
          k_pos = i;

      fail;
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
        if (by0 == 0)
           runerr(211);

        if (by0 > 0) {
            if (to0 <= MaxWord - by0) {
                while (from0 <= to0) {
                    suspend C_integer from0;
                    from0 += by0;
                }
            } else {
                while (from0 <= to0) {
                    suspend C_integer from0;
                    if (from0 <= MaxWord - by0)
                        from0 += by0;
                    else
                        break;
                }
            }
        } else {     /* by < 0 */
            if (to0 >= MinWord - by0) {
                while (from0 >= to0) {
                    suspend C_integer from0;
                    from0 += by0;
                }
            } else {
                while (from0 >= to0) {
                    suspend C_integer from0;
                    if (from0 >= MinWord - by0)
                        from0 += by0;
                    else
                        break;
                }
            }
        }
        fail;
   }
   else if (cnv:(exact)integer(by,by1) && cnv:(exact)integer(from,from1) && cnv:integer(to,to1)) {
       int sn = bigsign(&by1);
       if (sn == 0)
           runerr(211);

       if (sn > 0) {
           while (bigcmp(&from1, &to1) <= 0) {
               suspend from1;
               bigadd(&from1, &by1, &from1);
           }
       } else {
           while (bigcmp(&from1, &to1) >= 0) {
               suspend from1;
               bigadd(&from1, &by1, &from1);
           }
       }
       fail;
   }
   else if (cnv:C_double(from,from2) && cnv:C_double(to,to2) && cnv:C_double(by,by2)) {
       if (by2 == 0)
           runerr(211);

       if (by2 > 0)
           while (from2 <= to2) {
               suspend C_double from2;
               from2 += by2;
           }
       else
           while (from2 >= to2) {
               suspend C_double from2;
               from2 += by2;
           }
       fail;
   }
   else runerr(102);
  }
end
