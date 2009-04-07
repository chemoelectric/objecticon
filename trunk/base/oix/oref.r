/*
 * File: oref.r
 *  Contents: bang, random, sect, subsc
 */

"!x - generate successive values from object x."

operator{*} ! bang(underef x -> dx)
   body {
      register C_integer i, j;
      tended union block *ep;

   type_case dx of {
     string : {
            char ch;
            EVValD(&dx, E_Stringbang);
            if (is:variable(x)) {
                for (i = 1; i <= StrLen(dx); i++) {
                    suspend tvsubs(&x, i, (word)1);
                    deref(&x, &dx);
                    if (!is:string(dx)) 
                        runerr(103, dx);
                }
            } else {
                for (i = 1; i <= StrLen(dx); i++) {
                    ch = *(StrLoc(dx) + i - 1);
                    suspend string(1, &allchars[ch & 0xFF]);
                }
            }
     }

      list: {
#if E_Lsub
            word xi = 0;
#endif					/* E_Lsub */
            EVValD(&dx, E_Lbang);

            /*
             * x is a list.  Chain through each list element block and for
             * each one, suspend with a variable pointing to each
             * element contained in the block.
             */
            for (ep = BlkLoc(dx)->list.listhead;
		 BlkType(ep) == T_Lelem;
                 ep = ep->lelem.listnext){
               for (i = 0; i < ep->lelem.nused; i++) {
                  j = ep->lelem.first + i;
                  if (j >= ep->lelem.nslots)
                     j -= ep->lelem.nslots;

#if E_Lsub
		  ++xi;
		  EVVal(xi, E_Lsub);
#endif					/* E_Lsub */

                  suspend struct_var(&ep->lelem.lslots[j], ep);
                  }
               }
         }

      table: {
            struct b_tvtbl *tp;
            struct hgstate state;

            EVValD(&dx, E_Tbang);

            /*
             * x is a table.  Chain down the element list in each bucket
             * and suspend a variable pointing to each element in turn.
             */
	    for (ep = hgfirst(BlkLoc(dx), &state); ep != 0;
	       ep = hgnext(BlkLoc(dx), &state, ep)) {

                  EVValD(&ep->telem.tval, E_Tval);

		  MemProtect(tp = alctvtbl(&dx, &ep->telem.tref, ep->telem.hashnum));
		  suspend tvtbl(tp);
                  }
            }

      set: {
            struct hgstate state;
            EVValD(&dx, E_Sbang);
            /*
             *  This is similar to the method for tables except that a
             *  value is returned instead of a variable.
             */
	    for (ep = hgfirst(BlkLoc(dx), &state); ep != 0;
	       ep = hgnext(BlkLoc(dx), &state, ep)) {
                  EVValD(&ep->selem.setmem, E_Sval);
                  suspend ep->selem.setmem;
                  }
	    }

      cset: {
            EVValD(&dx, E_Csetbang);
            for (i = 0; i < BlkLoc(dx)->cset.n_ranges; i++) {
               int from, to;
               from = BlkLoc(dx)->cset.range[i].from;
               to = BlkLoc(dx)->cset.range[i].to;
               for (j = from; j <= to; ++j) {
                   if (j < 256)
                       suspend string(1, &allchars[j]);
                   else
                       suspend ucs(make_one_char_ucs_block(j));
               }
            }
         }

     ucs: {
          EVValD(&dx, E_Ucsbang);
          if (is:variable(x)) {
              for (i = 1; i <= BlkLoc(dx)->ucs.length; i++) {
                  suspend tvsubs(&x, i, (word)1);
                  deref(&x, &dx);
                  if (!is:ucs(dx)) 
                      runerr(128, dx);
              }
          } else {
              tended char *p = StrLoc(BlkLoc(dx)->ucs.utf8);
              for (i = 1; i <= BlkLoc(dx)->ucs.length; i++) {
                  tended struct descrip utf8;
                  StrLoc(utf8) = p;
                  StrLen(utf8) = UTF8_SEQ_LEN(*p);
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

            j = BlkLoc(dx)->record.constructor->n_fields;
            for (i = 0; i < j; i++) {
	       EVVal(i+1, E_Rsub);
               suspend struct_var(&BlkLoc(dx)->record.fields[i], 
                  (struct b_record *)BlkLoc(dx));
               }
            }

       default: {
           if (cnv:tmp_string(dx,dx)) {
               char ch;
               /*
                * A (converted or non-variable) string is being banged.
                * Loop through the string suspending simple one character
                *  substrings.
                */
               for (i = 1; i <= StrLen(dx); i++) {
                  ch = *(StrLoc(dx) + i - 1);
                  suspend string(1, &allchars[ch & 0xFF]);
                  }
            }
         else
            runerr(116, dx);
      }
   }
   fail;
   }
end      


#define RandVal (RanScale*(k_random=(RandA*k_random+RandC)&0x7FFFFFFFL))

"?x - produce a randomly selected element of x."

operator{0,1} ? random(underef x -> dx)
   body{
   type_case dx of {
      string: {
            C_integer val;
            double rval;

            if ((val = StrLen(dx)) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            if (is:variable(x))
                return tvsubs(&x, (word)rval + 1, (word)1);
            else
                return string(1, StrLoc(dx)+(word)rval);
         }

      ucs: {
            C_integer val;
            double rval;
            word i;

            if ((val = BlkLoc(dx)->ucs.length) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            i = (word)rval + 1;
            if (is:variable(x))
               return tvsubs(&x, i, (word)1);
            else
                return ucs(make_ucs_substring(&BlkLoc(dx)->ucs, i, 1));
       }

      cset: {
             C_integer val;
             double rval;
             word i;
             int k, ch;
             if ((val = BlkLoc(dx)->cset.size) == 0)
                 fail;
             rval = RandVal;
             rval *= val;
             i = (word)rval + 1;
             k = cset_range_of_pos(&BlkLoc(dx)->cset, i);
             ch = BlkLoc(dx)->cset.range[k].from + i - 1 - BlkLoc(dx)->cset.range[k].index;
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
            C_integer val;
            double rval;
            register C_integer i, j;
            union block *bp;     /* doesn't need to be tended */
            if ((val = BlkLoc(dx)->list.size) == 0)
               fail;
            rval = RandVal;
            rval *= val;
            i = (word)rval + 1;

            EVValD(&dx, E_Lrand);
            EVVal(i, E_Lsub);

            j = 1;
            /*
             * Work down chain list of list blocks and find the block that
             *  contains the selected element.
             */
            bp = BlkLoc(dx)->list.listhead;
            while (i >= j + bp->lelem.nused) {
               j += bp->lelem.nused;
               bp = bp->lelem.listnext;
               if (BlkType(bp) == T_List)
                  syserr("list reference out of bounds in random");
               }
            /*
             * Locate the appropriate element and return a variable
             * that points to it.
             */
            i += bp->lelem.first - j;
            if (i >= bp->lelem.nslots)
               i -= bp->lelem.nslots;
            return struct_var(&bp->lelem.lslots[i], bp);
         }

      table: {
          /*
           * x is a table.  Set n to a random number in the range [1,*x],
           *  failing if the table is empty.
           */
            C_integer val;
            double rval;
            register C_integer i, j, n;
            union block *ep, *bp;   /* doesn't need to be tended */
	    struct b_slots *seg;
	    struct b_tvtbl *tp;

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
			MemProtect(tp = alctvtbl(&dx, &ep->telem.tref, ep->telem.hashnum));
			return tvtbl(tp);
			}
            syserr("table reference out of bounds in random");
         }

      set: {
         /*
          * x is a set.  Set n to a random number in the range [1,*x],
          *  failing if the set is empty.
          */
            C_integer val;
            double rval;
            register C_integer i, j, n;
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
                  for (ep = seg->hslots[j]; ep != NULL; ep = ep->telem.clink)
                     if (--n <= 0) {
			EVValD(&ep->selem.setmem, E_Selem);
                        return ep->selem.setmem;
			}
            syserr("set reference out of bounds in random");
         }

      record: {
         /*
          * x is a record.  Set val to a random number in the range
          *  [1,*x] (*x is the number of fields), failing if the
          *  record has no fields.
          */
            C_integer val;
            double rval;
            struct b_record *rec;  /* doesn't need to be tended */

            rec = (struct b_record *)BlkLoc(dx);
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
          double rval;
          C_integer v;

          if (!cnv:integer(dx,dx))
              runerr(113, dx);

          if (Type(dx) == T_Lrgint) {
              if (bigrand(&dx, &result) == Error)  /* alcbignum failed */
	          runerr(0);
              return result;
          }

          v = IntVal(dx);
          /*
           * x is an integer, be sure that it's non-negative.
           */
          if (v < 0) 
              runerr(205, dx);

          /*
           * val contains the integer value of x. If val is 0, return
           *	a real in the range [0,1), else return an integer in the
           *	range [1,val].
           */
          if (v == 0) {
              rval = RandVal;
              return C_double rval;
          }
          else {
              rval = RandVal;
              rval *= v;
              return C_integer (long)rval + 1;
          }
      }
   }
}
end

"x[i:j] - form a substring or list section of x."

operator{0,1} [:] sect(underef x -> dx, i, j)
    /*
    * If it isn't a C integer, but is a large integer, fail on
    * the out-of-range index.
    */
   if !cnv:C_integer(i) then {
      if cnv : integer(i) then inline { fail; }
      runerr(101, i)
   }
   if !cnv:C_integer(j) then {
      if cnv : integer(j) then inline { fail; }
      runerr(101, j)
   }

   body {
      int use_trap = 0;

      type_case dx of {
      list: {
         C_integer t;

         i = cvpos((long)i, (long)BlkLoc(dx)->list.size);
         if (i == CvtFail)
            fail;
         j = cvpos((long)j, (long)BlkLoc(dx)->list.size);
         if (j == CvtFail)
            fail;
         if (i > j) {
            t = i;
            i = j;
            j = t;
            }
         if (cplist(&dx, &result, i, j) == Error)
	    runerr(0);
         return result;
      }

     ucs: {
         C_integer t;
         if (is:variable(x))
               use_trap = 1;

         i = cvpos((long)i, BlkLoc(dx)->ucs.length);
         if (i == CvtFail)
             fail;
         j = cvpos((long)j, BlkLoc(dx)->ucs.length);
         if (j == CvtFail)
             fail;
         if (i > j) { 			/* convert section to substring */
             t = i;
             i = j;
             j = t - j;
         }
         else
             j = j - i;
   
         if (use_trap) 
             return tvsubs(&x, i, j);
         else 
             return ucs(make_ucs_substring(&BlkLoc(dx)->ucs, i, j));

      }       

     cset: {
         C_integer t;
         int k, last;

         i = cvpos((long)i, BlkLoc(dx)->cset.size);
         if (i == CvtFail)
             fail;
         j = cvpos((long)j, BlkLoc(dx)->cset.size);
         if (j == CvtFail)
             fail;
         if (i > j) { 			/* convert section to substring */
             t = i;
             i = j;
             j = t - j;
         }
         else
             j = j - i;

         if (j == 0)
             return emptystr;

         /* Search for the last char, see if it's < 256 */
         last = i + j - 1;
         k = cset_range_of_pos(&BlkLoc(dx)->cset, last);
         if (BlkLoc(dx)->cset.range[k].from + last - 1 - BlkLoc(dx)->cset.range[k].index < 256) {
             cset_to_str(&BlkLoc(dx)->cset, i, j, &result);
             return result;
         } else
             return ucs(cset_to_ucs_block(&BlkLoc(dx)->cset, i, j));
      }       

    default: {
         C_integer t;

        /*
         * x should be a string. If x is a variable, we must create a
         *  substring trapped variable.
         */
         if (is:variable(x) && is:string(dx))
             use_trap = 1;
         else if (!cnv:string(dx,dx))
             runerr(131, dx);

         i = cvpos((long)i, (long)StrLen(dx));
         if (i == CvtFail)
            fail;
         j = cvpos((long)j, (long)StrLen(dx));
         if (j == CvtFail)
            fail;
         if (i > j) { 			/* convert section to substring */
            t = i;
            i = j;
            j = t - j;
            }
         else
            j = j - i;
   
         if (use_trap)
            return tvsubs(&x, i, j);
         else
            return string(j, StrLoc(dx)+i-1);
       }
     }
   }
end

"x[y] - access yth character or element of x."

operator{0,1} [] subsc(underef x -> dx,y)
 body {
   int use_trap = 0;
   C_integer yi;

   type_case dx of {
      list: {
         word i, j;
         register union block *bp; /* doesn't need to be tended */
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
          lp = (struct b_list *)BlkLoc(dx);
          i = cvpos(yi, (long)lp->size);
          if (i == CvtFail || i > lp->size)
              fail;

          EVValD(&dx, E_Lref);
          EVVal(i, E_Lsub);

          /*
           * Locate the list-element block containing the desired
           *  element.
           */
          bp = lp->listhead;
          j = 1;
          /*
           * y is in range, so bp can never be null here. if it was, a memory
           * violation would occur in the code that follows, anyhow, so
           * exiting the loop on a NULL bp makes no sense.
           */
          while (i >= j + bp->lelem.nused) {
              j += bp->lelem.nused;
              bp = bp->lelem.listnext;
          }

          /*
           * Locate the desired element and return a pointer to it.
           */
          i += bp->lelem.first - j;
          if (i >= bp->lelem.nslots)
              i -= bp->lelem.nslots;
          return struct_var(&bp->lelem.lslots[i], bp);
       }


      table: {
         /*
          * x is a table.  Return a table element trapped variable
	  *  representing the result; defer actual lookup until later.
          */
            uword hn;
	    struct b_tvtbl *tp;

            EVValD(&dx, E_Tref);
            EVValD(&y, E_Tsub);

	    hn = hash(&y);
            MemProtect(tp = alctvtbl(&dx, &y, hn));
            return tvtbl(tp);
         }

      record: {
         /*
          * x is a record.  Convert y to an integer and be sure that it
          *  it is in range as a field number.
          */
         if (!cnv:C_integer(y,yi)) {
            register union block *bp;  /* doesn't need to be tended */
            register struct b_constructor *bp2; /* doesn't need to be tended */
            register word i;

            if (!cnv:tmp_string(y,y))
               runerr(101,y);

            bp = BlkLoc(dx);
            bp2 = BlkLoc(dx)->record.constructor;
            i = lookup_record_field_by_name(bp2, &y);
            if (i < 0)
               fail;

            EVValD(&dx, E_Rref);
            EVVal(i+1, E_Rsub);

            /*
             * Found the field, return a pointer to it.
             */
            return struct_var(&bp->record.fields[i], bp);
         } else {
            word i;
            register union block *bp; /* doesn't need to be tended */

            bp = BlkLoc(dx);
            i = cvpos(yi, (word)(bp->record.constructor->n_fields));
            if (i == CvtFail || i > bp->record.constructor->n_fields)
               fail;

            EVValD(&dx, E_Rref);
            EVVal(i, E_Rsub);

            /*
             * Locate the appropriate field and return a pointer to it.
             */
            return struct_var(&bp->record.fields[i-1], bp);
         }
       }

     ucs: {
        word i;
        if (is:variable(x))
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
        i = cvpos(yi, BlkLoc(dx)->ucs.length);
        if (i == CvtFail || i > BlkLoc(dx)->ucs.length)
            fail;
        if (use_trap)
            /*
             * x is a string, make a substring trapped variable for the
             * one character substring selected and return it.
             */
            return tvsubs(&x, i, (word)1);
        else
            return ucs(make_ucs_substring(&BlkLoc(dx)->ucs, i, 1));
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

         i = cvpos(yi, BlkLoc(dx)->cset.size);
         if (i == CvtFail || i > BlkLoc(dx)->cset.size)
             fail;
         k = cset_range_of_pos(&BlkLoc(dx)->cset, i);
         ch = BlkLoc(dx)->cset.range[k].from + i - 1 - BlkLoc(dx)->cset.range[k].index;
         if (ch < 256)
             return string(1, &allchars[ch]);
         else
             return ucs(make_one_char_ucs_block(ch));
       }

      default: {
         char ch;
         word i;

         /*
          * dx must either be a string or be convertible to one. Decide
          *  whether a substring trapped variable can be created.
          */
         if (is:variable(x) && is:string(dx))
            use_trap = 1;
         else if (!cnv:tmp_string(dx,dx))
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
         i = cvpos(yi, StrLen(dx));
         if (i == CvtFail || i > StrLen(dx))
             fail;
         if (use_trap) {
             /*
              * x is a string, make a substring trapped variable for the
              * one character substring selected and return it.
              */
             return tvsubs(&x, i, (word)1);
         }
         else {
             /*
              * x was converted to a string, so it cannot be assigned
              * back into. Just return a string containing the selected
              * character.
              */
             ch = *(StrLoc(dx)+i-1);
             return string(1, &allchars[ch & 0xFF]);
         }
      }
    }
  }
end
