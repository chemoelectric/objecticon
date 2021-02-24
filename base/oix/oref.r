/*
 * File: oref.r
 */

#include "../h/opdefs.h"
#include "orefiasm.ri"

/* Helper method to allocate and fill in a b_tvsubs; var must be a pointer
 * to a tended descriptor.
 */
static struct b_tvsubs *make_tvsubs(dptr var, word pos, word len)
{
    struct b_tvsubs *t;
    MemProtect(t = alcsubs());
    t->sslen = len;
    if (is:tvsubs(*var)) {
       t->sspos = pos + TvsubsBlk(*var).sspos - 1;
       t->ssvar = TvsubsBlk(*var).ssvar;
    } else {
       t->sspos = pos;
       t->ssvar = *var;
    }
    return t;
}

/* Some helpful macros for suspending/returning chars in a cset */

#begdef SuspendCh(x)
   do {
    if (x < 256)
       suspend string(1, &allchars[x]);
    else
       suspend ucs(make_one_char_ucs_block(x));
   } while (0)
#enddef

#begdef ReturnCh(x)
   do {
    if (x < 256)
       return string(1, &allchars[x]);
    else
       return ucs(make_one_char_ucs_block(x));
   } while (0)
#enddef


"!x - generate successive values from object x."

operator ! bang(underef x -> dx)
 body {
   word i, j;
   tended union block *ep;
   struct hgstate state;

   type_case dx of {
     string : {
            if (is:variable(x)) {
                if (_rval) {
                    for (i = 1; i <= StrLen(dx); i++) {
                        suspend string(1, StrLoc(dx) + i - 1);
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                } else {
                    for (i = 1; i <= StrLen(dx); i++) {
                        suspend tvsubs(make_tvsubs(&x, i, 1));
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                }
            } else {
                for (i = 1; i <= StrLen(dx); i++) {
                    suspend string(1, StrLoc(dx) + i - 1);
                }
            }
     }

      list: {
            struct lgstate state;
            tended struct b_lelem *le;

            EVValD(&dx, E_Lbang);

            for (le = lgfirst(&ListBlk(dx), &state); le;
                 le = lgnext(&ListBlk(dx), &state, le)) {
                EVVal(state.listindex, E_Lsub);
                SuspendStructVar(le->lslots[state.result], le);
            }
         }

      table: {
            EVValD(&dx, E_Tbang);

            /*
             * x is a table.  Chain down the element list in each bucket
             * and suspend a variable pointing to each element in turn.
             */
	    for (ep = hgfirst(BlkLoc(dx), &state); ep;
                 ep = hgnext(BlkLoc(dx), &state, ep)) {
                  EVValD(&ep->telem.tval, E_Tval);
                  SuspendStructVar(ep->telem.tval, ep);
                  }
            }

      set: {
            EVValD(&dx, E_Sbang);
            /*
             *  This is similar to the method for tables except that a
             *  value is returned instead of a variable.
             */
	    for (ep = hgfirst(BlkLoc(dx), &state); ep;
                 ep = hgnext(BlkLoc(dx), &state, ep)) {
                  EVValD(&ep->selem.setmem, E_Sval);
                  suspend ep->selem.setmem;
                  }
	    }

      cset: {
            for (i = 0; i < CsetBlk(dx).n_ranges; i++) {
               word from, to;
               from = CsetBlk(dx).range[i].from;
               to = CsetBlk(dx).range[i].to;
               for (j = from; j <= to; ++j) {
                   SuspendCh(j);
               }
            }
         }

     ucs: {
          tended char *p;
          tended struct descrip utf8;
          if (is:variable(x)) {
              if (_rval) {
                  tended struct descrip prev;
                  p = 0;
                  prev = dx;
                  for (i = 1; i <= UcsBlk(dx).length; i++) {
                      if (!p)
                          p = ucs_utf8_ptr(&UcsBlk(dx), i);
                      MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                      suspend ucs(make_ucs_block(&utf8, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                      if (EqlDesc(prev, dx))
                          p += StrLen(utf8);
                      else {
                          p = 0;
                          prev = dx;
                      }
                  }
              } else {
                  for (i = 1; i <= UcsBlk(dx).length; i++) {
                      suspend tvsubs(make_tvsubs(&x, i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                  }
              }
          } else {
              p = StrLoc(UcsBlk(dx).utf8);
              for (i = 1; i <= UcsBlk(dx).length; i++) {
                  MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                  p += StrLen(utf8);
                  suspend ucs(make_ucs_block(&utf8, 1));
              }
          }
       }

     record: {
            /*
             * x is a record.  Loop through the fields and suspend
             * a variable pointing to each one.
             */

            EVValD(&dx, E_Rbang);

            j = RecordBlk(dx).constructor->n_fields;
            for (i = 0; i < j; i++) {
	       EVVal(i+1, E_Rsub);
               SuspendStructVar(RecordBlk(dx).fields[i], &RecordBlk(dx));
               }
            }

     coexpr: {
           struct p_frame *pf;
           EVValD(&dx, E_Cobang);

           MemProtect(pf = alc_p_frame(&Bcoexp_bang_impl, 0));
           push_frame((struct frame *)pf);
           pf->tmp[0] = dx;
           for (;;) {
               tail_invoke_frame((struct frame *)pf);
               suspend;
           }
       }

       default: {
           if (cnv:string(dx,dx)) {
               /*
                * A converted string is being banged.
                * Loop through the string suspending simple one character
                *  substrings.
                */
               for (i = 1; i <= StrLen(dx); i++)
                  suspend string(1, StrLoc(dx) + i - 1);
            }
         else
            runerr(116, dx);
      }
   }
   fail;
   }
end      


"?x - produce a randomly selected element of x."

operator ? random(underef x -> dx)
  body{
   word val;
   double rval;

   type_case dx of {
      string: {
            if ((val = StrLen(dx)) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            if (is:variable(x) && !_rval)
                return tvsubs(make_tvsubs(&x, (word)rval + 1, 1));
            else
                return string(1, StrLoc(dx)+(word)rval);
         }

      ucs: {
            word i;

            if ((val = UcsBlk(dx).length) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            i = (word)rval + 1;
            if (is:variable(x) && !_rval)
                return tvsubs(make_tvsubs(&x, i, 1));
            else
                return ucs(make_ucs_substring(&UcsBlk(dx), i, 1));
       }

      cset: {
             word i;
             int k, ch;
             if ((val = CsetBlk(dx).size) == 0)
                 fail;
             rval = RandVal;
             rval *= val;
             i = (word)rval + 1;
             k = cset_range_of_pos(&CsetBlk(dx), i);
             ch = CsetBlk(dx).range[k].from + i - 1 - CsetBlk(dx).range[k].index;
             ReturnCh(ch);
         }

      list: {
         /*
          * x is a list.  Set i to a random number in the range [1,*x],
          *  failing if the list is empty.
          */
            word i, j;
            struct b_lelem *le;     /* doesn't need to be tended */
            if ((val = ListBlk(dx).size) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            i = (word)rval + 1;

            EVValD(&dx, E_Lrand);
            EVVal(i, E_Lsub);

            le = get_lelem_for_index(&ListBlk(dx), i, &j);
            if (!le)
                syserr("List reference out of bounds in random");
            /* j is the logical index in the element block; convert to
             * the actual position. */
            j += le->first;
            if (j >= le->nslots)
                j -= le->nslots;
            ReturnStructVar(le->lslots[j], le);
         }

      table: {
          /*
           * x is a table.  Set n to a random number in the range [1,*x],
           *  failing if the table is empty.
           */
            word i, j, n;
            union block *ep, *bp;   /* doesn't need to be tended */
	    struct b_slots *seg;

            bp = BlkLoc(dx);
            if ((val = bp->table.size) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            n = (word)rval + 1;

            EVValD(&dx, E_Trand);
            EVVal(n, E_Tsub);

            /*
             * Walk down the hash chains to find and return the nth element
	     *  as a variable.
             */
            for (i = 0; i < HSegs && (seg = bp->table.hdir[i]) != NULL; i++)
               for (j = segsize[i] - 1; j >= 0; j--)
                  for (ep = seg->hslots[j];
		       BlkType(ep) == T_Telem;
		       ep = ep->telem.clink)
                     if (--n <= 0) {
                        ReturnStructVar(ep->telem.tval, ep);
			}
            syserr("Table reference out of bounds in random");
         }

      set: {
         /*
          * x is a set.  Set n to a random number in the range [1,*x],
          *  failing if the set is empty.
          */
            word i, j, n;
            union block *bp, *ep;  /* doesn't need to be tended */
	    struct b_slots *seg;

            bp = BlkLoc(dx);
            if ((val = bp->set.size) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            n = (word)rval + 1;

            EVValD(&dx, E_Srand);

            /*
             * Walk down the hash chains to find and return the nth element.
             */
            for (i = 0; i < HSegs && (seg = bp->table.hdir[i]) != NULL; i++)
               for (j = segsize[i] - 1; j >= 0; j--)
                  for (ep = seg->hslots[j]; BlkType(ep) == T_Selem; ep = ep->telem.clink)
                     if (--n <= 0)
                        return ep->selem.setmem;
            syserr("Set reference out of bounds in random");
         }

      record: {
         /*
          * x is a record.  Set val to a random number in the range
          *  [1,*x] (*x is the number of fields), failing if the
          *  record has no fields.
          */
            struct b_record *rec;  /* doesn't need to be tended */

            rec = &RecordBlk(dx);
            if ((val = rec->constructor->n_fields) == 0)
               fail;
            /*
             * Locate the selected element and return a variable
             * that points to it
             */
            rval = RandVal;
            rval *= val;
            EVValD(&dx, E_Rrand);
            EVVal(rval + 1, E_Rsub);
            ReturnStructVar(rec->fields[(word)rval], rec);
         }

      default: {
          tended struct descrip result;

          if (!cnv:integer(dx,dx))
              runerr(113, dx);

          if (bigsign(&dx) < 0)
              runerr(205, dx);
          bigrand(&dx, &result);
          return result;
      }
   }
   fail;       /* Not reached */
}
end

"x[i:j] - form a substring or list section of x."

operator [:] sect(underef x -> dx, i, j)
    /*
    * If it isn't a C integer, but is a large integer, fail on
    * the out-of-range index.
    */
   if !cnv:C_integer(i) then {
      if cnv : integer(i) then body { fail; }
      runerr(101, i)
   }
   if !cnv:C_integer(j) then {
      if cnv : integer(j) then body { fail; }
      runerr(101, j)
   }

   body {
      int use_trap = 0;
      word len;

      type_case dx of {
      list: {
         tended struct descrip result;
         if (!cvslice(&i, &j, ListBlk(dx).size))
             fail;
         len = j - i;
         cplist(&dx, &result, i, len);
         return result;
      }

     ucs: {
         if (is:variable(x) && !_rval)
               use_trap = 1;
         if (!cvslice(&i, &j, UcsBlk(dx).length))
             fail;
         len = j - i;
         if (use_trap) 
             return tvsubs(make_tvsubs(&x, i, len));
         else 
             return ucs(make_ucs_substring(&UcsBlk(dx), i, len));
      }       

     cset: {
         int k, last;
         if (!cvslice(&i, &j, CsetBlk(dx).size))
             fail;
         len = j - i;

         if (len == 0)
             return emptystr;

         /* Search for the last char, see if it's < 256 */
         last = j - 1;
         k = cset_range_of_pos(&CsetBlk(dx), last);
         if (CsetBlk(dx).range[k].from + last - 1 - CsetBlk(dx).range[k].index < 256) {
             tended struct descrip result;
             cset_to_string(&CsetBlk(dx), i, len, &result);
             return result;
         } else
             return ucs(cset_to_ucs_block(&CsetBlk(dx), i, len));
      }       

    default: {
        /*
         * x should be a string. If x is a variable, we must create a
         *  substring trapped variable.
         */
         if (is:variable(x) && is:string(dx) && !_rval)
             use_trap = 1;
         else if (!cnv:string(dx,dx))
             runerr(131, dx);

         if (!cvslice(&i, &j, StrLen(dx)))
             fail;
         len = j - i;
   
         if (use_trap)
            return tvsubs(make_tvsubs(&x, i, len));
         else
            return string(len, StrLoc(dx) + i - 1);
       }
     }
   }
end

"x[y] - access yth character or element of x."

operator [] subsc(underef x -> dx,y)
 body {
   int use_trap = 0;
   word yi;

   type_case dx of {
      list: {
         word i, j;
         struct b_lelem *le;        /* doesn't need to be tended */
         struct b_list *lp;        /* doesn't need to be tended */
         /*
          * Make sure that y is a C integer.
          */
          if (!cnv:C_integer(y,yi)) {
	    /*
	     * If it isn't a C integer, but is a large integer, fail on
	     * the out-of-range index.
	     */
             if (cnv:integer(y,y))
                fail;
	    runerr(101, y);
         }

          /*
           * Make sure that subscript y is in range.
           */
          lp = &ListBlk(dx);
          i = cvpos_item(yi, lp->size);
          if (i == CvtFail)
              fail;

          EVValD(&dx, E_Lref);
          EVVal(i, E_Lsub);

          /*
           * Locate the desired element and return a pointer to it.
           */
          le = get_lelem_for_index(lp, i, &j);
          if (!le)
              syserr("Couldn't find element for valid index in list");
          /* j is the logical index in the element block; convert to
           * the actual position. */
          j += le->first;
          if (j >= le->nslots)
              j -= le->nslots;
          ReturnStructVar(le->lslots[j], le);
       }

      table: {

            EVValD(&dx, E_Tref);
            EVValD(&y, E_Tsub);

            if (_rval) {
                int res;
                union block **p;
                /*
                 * Rval, so lookup now and return element or default
                 * value.
                 */
                p = memb(BlkLoc(dx), &y, hash(&y), &res);
                if (res)
                    return (*p)->telem.tval;
                else
                    return TableBlk(dx).defvalue;
            } else {
                struct b_tvtbl *tp;       /* Doesn't need to be tended */
                /*
                 * Return a table element trapped variable
                 * representing the result; defer actual lookup until
                 * later.
                 */
                MemProtect(tp = alctvtbl());
                tp->clink = BlkLoc(dx);
                tp->tref = y;
                return tvtbl(tp);
            }
      }

      record: {
         word i;
         CheckField(y);
         i = lookup_record_field(RecordBlk(dx).constructor, &y, 0);
         if (i < 0)
             fail;

         EVValD(&dx, E_Rref);
         EVVal(i + 1, E_Rsub);

         /*
          * Found the field, return a pointer to it.
          */
         ReturnStructVar(RecordBlk(dx).fields[i], &RecordBlk(dx));
       }

     ucs: {
        word i;
        if (is:variable(x) && !_rval)
            use_trap = 1;
         /*
          * Make sure that y is a C integer.
          */
        if (!cnv:C_integer(y,yi)) {
	    /*
	     * If it isn't a C integer, but is a large integer, fail on
	     * the out-of-range index.
	     */
	    if (cnv:integer(y,y))
                fail;
            runerr(101, y);
        }

        /*
         * Convert y to a position in x and fail if the position
         *  is out of bounds.
         */
        i = cvpos_item(yi, UcsBlk(dx).length);
        if (i == CvtFail)
            fail;
        if (use_trap)
            /*
             * x is a string, make a substring trapped variable for the
             * one character substring selected and return it.
             */
            return tvsubs(make_tvsubs(&x, i, 1));
        else
            return ucs(make_ucs_substring(&UcsBlk(dx), i, 1));
      }

      cset: {
         word i;
         int k, ch;
         /*
          * Make sure that y is a C integer.
          */
         if (!cnv:C_integer(y,yi)) {
            /*
             * If it isn't a C integer, but is a large integer, fail on
             * the out-of-range index.
             */
            if (cnv:integer(y,y))
                fail;
            runerr(101, y);
         }

         i = cvpos_item(yi, CsetBlk(dx).size);
         if (i == CvtFail)
             fail;
         k = cset_range_of_pos(&CsetBlk(dx), i);
         ch = CsetBlk(dx).range[k].from + i - 1 - CsetBlk(dx).range[k].index;
         ReturnCh(ch);
       }

      default: {
         word i;

         /*
          * dx must either be a string or be convertible to one. Decide
          *  whether a substring trapped variable can be created.
          */
         if (is:variable(x) && is:string(dx) && !_rval)
            use_trap = 1;
         else if (!cnv:string(dx,dx))
            runerr(114, dx);

         /*
          * Make sure that y is a C integer.
          */
         if (!cnv:C_integer(y,yi)) {
	    /*
	     * If it isn't a C integer, but is a large integer, fail on
	     * the out-of-range index.
	     */
            if (cnv:integer(y,y))
                fail;
            runerr(101, y);
         }

         /*
          * Convert y to a position in x and fail if the position
          *  is out of bounds.
          */
         i = cvpos_item(yi, StrLen(dx));
         if (i == CvtFail)
             fail;
         if (use_trap) {
             /*
              * x is a string, make a substring trapped variable for the
              * one character substring selected and return it.
              */
             return tvsubs(make_tvsubs(&x, i, 1));
         }
         else {
             /*
              * x was converted to a string, so it cannot be assigned
              * back into. Just return a string containing the selected
              * character.
              */
             return string(1, StrLoc(dx) + i - 1);
         }
      }
    }
    fail;       /* Not reached */
  }
end


function back(underef x -> dx, n)
   if !def:C_integer(n, 0) then
      runerr(101, n)
 body {
   word i, j;
   tended struct descrip prev;

   type_case dx of {
     string : {
            n = cvpos_item(n - 1, StrLen(dx));
            if (n == CvtFail)
                fail;
            if (is:variable(x)) {
                prev = dx;
                if (_rval) {
                    for (i = n; i > 0; i--) {
                        suspend string(1, StrLoc(dx) + i - 1);
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                        if (!EqlDesc(prev, dx)) {
                            i += StrLen(dx) - StrLen(prev);
                            prev = dx;
                        }
                    }
                } else {
                    for (i = n; i > 0; i--) {
                        suspend tvsubs(make_tvsubs(&x, i, 1));
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                        if (!EqlDesc(prev, dx)) {
                            i += StrLen(dx) - StrLen(prev);
                            prev = dx;
                        }
                    }
                }
            } else {
                for (i = n; i > 0; i--)
                    suspend string(1, StrLoc(dx) + i - 1);
           }
      }

      list: {
            struct lgstate state;
            tended struct b_lelem *le;
            n = cvpos_item(n - 1, ListBlk(dx).size);
            if (n == CvtFail)
                fail;
            for (le = lginit(&ListBlk(dx), n, &state); le;
                 le = lgprev(&ListBlk(dx), &state, le)) {
                SuspendStructVar(le->lslots[state.result], le);
            }
         }

      cset: {
            word from, to;
            n = cvpos_item(n - 1, CsetBlk(dx).size);
            if (n == CvtFail)
                fail;
            i = cset_range_of_pos(&CsetBlk(dx), n);
            from = CsetBlk(dx).range[i].from;
            to = from + n - 1 - CsetBlk(dx).range[i].index;
            for (j = to; j >= from; --j) {
                SuspendCh(j);
            }
            for (i--; i >= 0; i--) {
               from = CsetBlk(dx).range[i].from;
               to = CsetBlk(dx).range[i].to;
               for (j = to; j >= from; --j) {
                   SuspendCh(j);
               }
            }
         }

     ucs: {
          tended char *p;
          tended struct descrip utf8;
          n = cvpos_item(n - 1, UcsBlk(dx).length);
          if (n == CvtFail)
              fail;
          if (is:variable(x)) {
              prev = dx;
              if (_rval) {
                  p = 0;
                  for (i = n; i > 0; i--) {
                      if (!p)
                          p = ucs_utf8_ptr(&UcsBlk(dx), i + 1);
                      utf8_rev_iter0(&p);
                      MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                      suspend ucs(make_ucs_block(&utf8, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                      if (!EqlDesc(prev, dx)) {
                          p = 0;
                          i += UcsBlk(dx).length - UcsBlk(prev).length;
                          prev = dx;
                      }
                  }
              } else {
                  for (i = n; i > 0; i--) {
                      suspend tvsubs(make_tvsubs(&x, i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                      if (!EqlDesc(prev, dx)) {
                          i += UcsBlk(dx).length - UcsBlk(prev).length;
                          prev = dx;
                      }
                  }
              }
          } else {
              p = ucs_utf8_ptr(&UcsBlk(dx), n + 1);
              for (i = n; i > 0; i--) {
                  utf8_rev_iter0(&p);
                  MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                  suspend ucs(make_ucs_block(&utf8, 1));
              }
          }
       }

     record: {
            n = cvpos_item(n - 1, RecordBlk(dx).constructor->n_fields);
            if (n == CvtFail)
                fail;
            for (i = n - 1; i >= 0; i--) {
               SuspendStructVar(RecordBlk(dx).fields[i], &RecordBlk(dx));
               }
            }

       default: {
           if (cnv:string(dx,dx)) {
               n = cvpos_item(n - 1, StrLen(dx));
               if (n == CvtFail)
                   fail;
               for (i = n; i > 0; i--)
                  suspend string(1, StrLoc(dx) + i - 1);
            }
         else
            runerr(116, dx);
      }
   }
   fail;
   }
end      

function forward(underef x -> dx, n)
   if !def:C_integer(n, 1) then
      runerr(101, n)
  body {
   word i, j;

   type_case dx of {
     string : {
            n = cvpos_item(n, StrLen(dx));
            if (n == CvtFail)
                fail;
            if (is:variable(x)) {
                if (_rval) {
                    for (i = n; i <= StrLen(dx); i++) {
                        suspend string(1, StrLoc(dx) + i - 1);
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                } else {
                    for (i = n; i <= StrLen(dx); i++) {
                        suspend tvsubs(make_tvsubs(&x, i, 1));
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                }
            } else {
                for (i = n; i <= StrLen(dx); i++) {
                    suspend string(1, StrLoc(dx) + i - 1);
                }
            }
     }

      list: {
            struct lgstate state;
            tended struct b_lelem *le;
            n = cvpos_item(n, ListBlk(dx).size);
            if (n == CvtFail)
                fail;
            for (le = lginit(&ListBlk(dx), n, &state); le;
                 le = lgnext(&ListBlk(dx), &state, le)) {
                SuspendStructVar(le->lslots[state.result], le);
            }
         }


      cset: {
            word from, to;
            n = cvpos_item(n, CsetBlk(dx).size);
            if (n == CvtFail)
                fail;
            i = cset_range_of_pos(&CsetBlk(dx), n);
            from = CsetBlk(dx).range[i].from + n - 1 - CsetBlk(dx).range[i].index;;
            to = CsetBlk(dx).range[i].to;
            for (j = from; j <= to; ++j) {
                SuspendCh(j);
            }
            for (i++; i < CsetBlk(dx).n_ranges; i++) {
               from = CsetBlk(dx).range[i].from;
               to = CsetBlk(dx).range[i].to;
               for (j = from; j <= to; ++j) {
                   SuspendCh(j);
               }
            }
         }

     ucs: {
          tended char *p;
          tended struct descrip utf8;
          n = cvpos_item(n, UcsBlk(dx).length);
          if (n == CvtFail)
              fail;
          if (is:variable(x)) {
              if (_rval) {
                  tended struct descrip prev;
                  p = 0;
                  prev = dx;
                  for (i = n; i <= UcsBlk(dx).length; i++) {
                      if (!p)
                          p = ucs_utf8_ptr(&UcsBlk(dx), i);
                      MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                      suspend ucs(make_ucs_block(&utf8, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                      if (EqlDesc(prev, dx))
                          p += StrLen(utf8);
                      else {
                          p = 0;
                          prev = dx;
                      }
                  }
              } else {
                  for (i = n; i <= UcsBlk(dx).length; i++) {
                      suspend tvsubs(make_tvsubs(&x, i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                  }
              }
          } else {
              p = ucs_utf8_ptr(&UcsBlk(dx), n);
              for (i = n; i <= UcsBlk(dx).length; i++) {
                  MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
                  p += StrLen(utf8);
                  suspend ucs(make_ucs_block(&utf8, 1));
              }
          }
       }

     record: {
            j = RecordBlk(dx).constructor->n_fields;
            n = cvpos_item(n, j);
            if (n == CvtFail)
                fail;
            for (i = n - 1; i < j; i++) {
               SuspendStructVar(RecordBlk(dx).fields[i], &RecordBlk(dx));
               }
            }

       default: {
           if (cnv:string(dx,dx)) {
               n = cvpos_item(n, StrLen(dx));
               if (n == CvtFail)
                   fail;
               for (i = n; i <= StrLen(dx); i++)
                  suspend string(1, StrLoc(dx) + i - 1);
            }
         else
            runerr(116, dx);
      }
   }
   fail;
   }
end
