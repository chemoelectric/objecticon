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

"!x - generate successive values from object x."

operator ! bang(underef x -> dx)
   body {
      word i, j;
      tended union block *ep;

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
                suspend struct_var(&le->lslots[state.result], le);
            }
         }

      table: {
            struct hgstate state;

            EVValD(&dx, E_Tbang);

            /*
             * x is a table.  Chain down the element list in each bucket
             * and suspend a variable pointing to each element in turn.
             */
	    for (ep = hgfirst(BlkLoc(dx), &state); ep;
                 ep = hgnext(BlkLoc(dx), &state, ep)) {
                  EVValD(&ep->telem.tval, E_Tval);
                  suspend struct_var(&ep->telem.tval, ep);
                  }
            }

      set: {
            struct hgstate state;
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
                   if (j < 256)
                       suspend string(1, &allchars[j]);
                   else
                       suspend ucs(make_one_char_ucs_block(j));
               }
            }
         }

     ucs: {
          if (is:variable(x)) {
              if (_rval) {
                  for (i = 1; i <= UcsBlk(dx).length; i++) {
                      suspend ucs(make_ucs_substring(&UcsBlk(dx), i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
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
              tended char *p = StrLoc(UcsBlk(dx).utf8);
              for (i = 1; i <= UcsBlk(dx).length; i++) {
                  tended struct descrip utf8;
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
               suspend struct_var(&RecordBlk(dx).fields[i], 
                  &RecordBlk(dx));
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
                * A (converted or non-variable) string is being banged.
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
   type_case dx of {
      string: {
            word val;
            double rval;

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
            word val, i;
            double rval;

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
             word val, i;
             double rval;
             int k, ch;
             if ((val = CsetBlk(dx).size) == 0)
                 fail;
             rval = RandVal;
             rval *= val;
             i = (word)rval + 1;
             k = cset_range_of_pos(&CsetBlk(dx), i);
             ch = CsetBlk(dx).range[k].from + i - 1 - CsetBlk(dx).range[k].index;
             if (ch < 256)
                 return string(1, &allchars[ch]);
             else
                 return ucs(make_one_char_ucs_block(ch));
         }

      list: {
         /*
          * x is a list.  Set i to a random number in the range [1,*x],
          *  failing if the list is empty.
          */
            word val, i, j;
            double rval;
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
            return struct_var(&le->lslots[j], le);
         }

      table: {
          /*
           * x is a table.  Set n to a random number in the range [1,*x],
           *  failing if the table is empty.
           */
            double rval;
            word val, i, j, n;
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
                        return struct_var(&ep->telem.tval, ep);
			}
            syserr("Table reference out of bounds in random");
         }

      set: {
         /*
          * x is a set.  Set n to a random number in the range [1,*x],
          *  failing if the set is empty.
          */
            double rval;
            word val, i, j, n;
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
            word val;
            double rval;
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
            return struct_var(&rec->fields[(word)rval], rec);
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
          return struct_var(&le->lslots[j], le);
       }

      table: {

            EVValD(&dx, E_Tref);
            EVValD(&y, E_Tsub);

            if (_rval) {
                int res;
                union block **p;
                union block *bp;
                /*
                 * Rval, so lookup now and return element or default
                 * value.
                 */
                p = memb(BlkLoc(dx), &y, hash(&y), &res);
                if (res) {
                    bp = *p;
                    return struct_var(&bp->telem.tval, bp);
                } else
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
         return struct_var(&RecordBlk(dx).fields[i], &RecordBlk(dx));
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
         if (ch < 256)
             return string(1, &allchars[ch]);
         else
             return ucs(make_one_char_ucs_block(ch));
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
  }
end


function back(underef x -> dx)
 body {
   word i, j;
   tended union block *ep;

   type_case dx of {
     string : {
            if (is:variable(x)) {
                if (_rval) {
                    for (i = StrLen(dx); i > 0; i--) {
                        if (i > StrLen(dx)) {
                            i = StrLen(dx);
                            if (i == 0)
                                break;
                        }
                        suspend string(1, StrLoc(dx) + i - 1);
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                } else {
                    for (i = StrLen(dx); i > 0; i--) {
                        if (i > StrLen(dx)) {
                            i = StrLen(dx);
                            if (i == 0)
                                break;
                        }
                        suspend tvsubs(make_tvsubs(&x, i, 1));
                        deref(&x, &dx);
                        if (!is:string(dx)) 
                            runerr(103, dx);
                    }
                }
            } else {
                for (i = StrLen(dx); i > 0; i--)
                    suspend string(1, StrLoc(dx) + i - 1);
           }
      }

      list: {
            struct lgstate state;
            tended struct b_lelem *le;

            EVValD(&dx, E_Lbang);

            for (le = lglast(&ListBlk(dx), &state); le;
                 le = lgprev(&ListBlk(dx), &state, le)) {
                EVVal(state.listindex, E_Lsub);
                suspend struct_var(&le->lslots[state.result], le);
            }
         }

      cset: {
            for (i = CsetBlk(dx).n_ranges - 1; i >= 0; i--) {
               word from, to;
               from = CsetBlk(dx).range[i].from;
               to = CsetBlk(dx).range[i].to;
               for (j = to; j >= from; --j) {
                   if (j < 256)
                       suspend string(1, &allchars[j]);
                   else
                       suspend ucs(make_one_char_ucs_block(j));
               }
            }
         }

     ucs: {
          if (is:variable(x)) {
              if (_rval) {
                  for (i = UcsBlk(dx).length; i > 0; i--) {
                      if (i > UcsBlk(dx).length) {
                          i = UcsBlk(dx).length;
                          if (i == 0)
                              break;
                      }
                      suspend ucs(make_ucs_substring(&UcsBlk(dx), i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                  }
              } else {
                  for (i = UcsBlk(dx).length; i > 0; i--) {
                      if (i > UcsBlk(dx).length) {
                          i = UcsBlk(dx).length;
                          if (i == 0)
                              break;
                      }
                      suspend tvsubs(make_tvsubs(&x, i, 1));
                      deref(&x, &dx);
                      if (!is:ucs(dx)) 
                          runerr(128, dx);
                  }
              }
          } else {
              tended char *p = StrLoc(UcsBlk(dx).utf8) +
                  StrLen(UcsBlk(dx).utf8);
              for (i = UcsBlk(dx).length; i > 0; i--) {
                  tended struct descrip utf8;
                  utf8_rev_iter0(&p);
                  MakeStr(p, UTF8_SEQ_LEN(*p), &utf8);
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

            for (i = RecordBlk(dx).constructor->n_fields - 1; i >= 0; i--) {
	       EVVal(i+1, E_Rsub);
               suspend struct_var(&RecordBlk(dx).fields[i], 
                  &RecordBlk(dx));
               }
            }

       default: {
           if (cnv:string(dx,dx)) {
               /*
                * A (converted or non-variable) string is being banged.
                * Loop through the string suspending simple one character
                *  substrings.
                */
               for (i = StrLen(dx); i > 0; i--)
                  suspend string(1, StrLoc(dx) + i - 1);
            }
         else
            runerr(116, dx);
      }
   }
   fail;
   }
end      
