/*
 * File: fmisc.r
 */

static word sort_field;		/* field number, set by sort function */
static dptr nth (dptr d);
static int tvcmp4  (struct dpair *dp1,struct dpair *dp2);
static int trcmp3  (struct dpair *dp1,struct dpair *dp2);
static int trefcmp (dptr d1,dptr d2);
static int tvalcmp (dptr d1,dptr d2);
static int nthcmp  (dptr d1,dptr d2);
static word get_ucs_slot(struct b_ucs *b, word i);
static void set_ucs_slot(struct b_ucs *b, word i, word n);
static void ensure_ucs_slot(struct b_ucs *b, word d);
static word get_ucs_n_slots(struct b_ucs *b);


"char(i) - produce a string consisting of character i."

function char(i)
   if !cnv:C_integer(i) then
      runerr(101,i)
   body {
      if (i < 0 || i > 255)
          fail;
      return string(1, &allchars[i & 0xFF]);
   }
end


"collect() - call garbage collector."

function collect()
   body {
      collect(User);
      return nulldesc;
      }
end


"copy(x) - make a copy of object x."

function copy(x)
 body {
   tended struct descrip result;
   type_case x of {
      null:
      yes:
      string:
      ucs:
      cset:
      integer:
      real:
      proc:
      methp:
      object:
      class:
      constructor:
      weakref:
      coexpr: {
            /*
             * Copy the null value, integers, long integers, reals,
             *	csets, procedures, and such by copying the descriptor.
             *	Note that for integers, this results in the assignment
             *	of a value, for the other types, a pointer is directed to
             *	a data block.
             */
            return x;
            }

      list: {
            /*
             * Pass the buck to cplist to copy a list.
             */
            cplist(&x, &result, 1, ListBlk(x).size);
            EVValD(&result, E_Lcreate);
            return result;
            }
      table: {
            cptable(&x, &result, TableBlk(x).size);
            EVValD(&result, E_Tcreate);
	    return result;
         }

      set: {
            /*
             * Pass the buck to cpset to copy a set.
             */
            cpset(&x, &result, SetBlk(x).size);
            EVValD(&result, E_Screate);
	    return result;
         }

      record: {
            tended struct b_record *new_rec;
            /*
             * Allocate space for the new record and copy the old one
             * into it.
             */
            MemProtect(new_rec = alcrecd(RecordBlk(x).constructor));
            memcpy(new_rec->fields, 
                   RecordBlk(x).fields, 
                   RecordBlk(x).constructor->n_fields * sizeof(struct descrip));
            Desc_EVValD(new_rec, E_Rcreate, D_Record);
            return record(new_rec);
         }

      default:  {
            runerr(123,x);
         }
      }
   }
end



/*
 * the bitwise operators are identical enough to be expansions
 *  of a macro.
 */

#begdef  bitop(func_name, op)
function func_name(i, j, a[n])
   /*
    * i and j must be integers
    */
   if !cnv:integer(i) then
      runerr(101,i)
   if !cnv:integer(j) then
      runerr(101,j)

   body {
      int k ;
      tended struct descrip result;
      op(i, j, result);

      /*
       * Process any optional additonal params.
       */
      for (k = 0; k < n; ++k) {
          if (!cnv:integer(a[k], a[k]))
              runerr(101, a[k]);
          op(result, a[k], result);
      }

      return result;
   }
end
#enddef

#define bitand(x,y,result) bigand(&x, &y, &result);
#define bitor(x,y,result) bigor(&x, &y, &result);
#define bitxor(x,y,result) bigxor(&x, &y, &result);

bitop(iand, bitand)          /* iand(i,j) bitwise "and" of i and j */
bitop(ior,  bitor)  /* ior(i,j) bitwise "or" of i and j */
bitop(ixor, bitxor) /* ixor(i,j) bitwise "xor" of i and j */


"icom(i) - produce bitwise complement (one's complement) of i."

function icom(i)
   /*
    * i must be an integer
    */
   if !cnv:integer(i) then
      runerr(101, i)

   body {
      if (IsLrgint(i)) {
         tended struct descrip result;
         bigsub(&minusonedesc, &i, &result);
         return result;
         }
      else
      return C_integer ~IntVal(i);
      }
end


"image(x) - return string image of object x."
/*
 *  All the interesting work happens in getimage()
 */
function image(x)
   body {
      tended struct descrip result;
      getimage(&x,&result);
      return result;
      }
end


"ishift(i,j) - produce i shifted j bit positions (left if j<0, right if j>0)."

function ishift(i,j)

   if !cnv:integer(i) then
      runerr(101, i)
   if !cnv:C_integer(j) then
      runerr(101, j)

   body {
       tended struct descrip result;
       bigshift(&i, j, &result);
       return result;
    }
end


/*
 * Common code for runerr, fatalerr
 */
#begdef ERRFUNC()
{
    word err_num;

    if (cnv:C_integer(i, err_num)) {
        char *em;
        if (err_num <= 0)
            runerr(205, i);
        k_errornumber = err_num;
        em = lookup_err_msg(k_errornumber);
        if (em)
            CMakeStr(em, &k_errortext);
        else
            k_errortext = emptystr;
    } else if (cnv:string(i,i)) {
        k_errornumber = -1;
        k_errortext = i;
    } else
        runerr(170, i);

    if (n == 0) {
        k_errorvalue = nulldesc;
        have_errval = 0;
    }
    else {
        k_errorvalue = x[0];
        have_errval = 1;
    }
    k_errorcoexpr = k_current;

    if (!is:null(kywd_handler)) {
        activate_handler();
        return;
    }

    if (k_errornumber > 0)
        fprintf(stderr, "\nRun-time error %d\n", k_errornumber);
    else 
        fprintf(stderr, "\nRun-time error: ");
    putstr(stderr, &k_errortext);
    fputc('\n', stderr);

    if (have_errval) {
        fprintf(stderr, "Offending value: ");
        outimage(stderr, &k_errorvalue, 0);
        putc('\n', stderr);
    }

    if (curpstate->monitor &&
        Testb(E_Error, curpstate->eventmask->bits)) {
        traceback(k_current, 1, 1);
        add_to_prog_event_queue(&nulldesc, E_Error);
        curpstate->exited = 1;
        push_fatalerr_139_frame();
        return;
    }

    checkfatalrecurse();
    traceback(k_current, 1, 1);

    if (dodump > 1)
        abort();

    c_exit(EXIT_FAILURE);
    /* Not reached */
    fail;
}
#enddef

"runerr(i,x) - produce runtime error i with value x."

function runerr(i, x[n])
   body {
      ERRFUNC();
   }
end

"fatalerr(i,x) - same as runerr, but disable error conversion first."

function fatalerr(i, x[n])
   body {
      kywd_handler = nulldesc;
      curpstate->monitor = 0;
      ERRFUNC();
   }
end

function syserr(msg)
   if !cnv:string(msg) then
      runerr(103, msg)

   body {
      fprintf(stderr, "\nIcon-level internal error: %.*s\n", StrF(msg));
      print_location(stderr, curr_pf);

      checkfatalrecurse();
      traceback(k_current, 1, 1);

      if (dodump > 1)
          abort();

      c_exit(EXIT_FAILURE);
      fail;
   }
end


"seq(i, j) - generate i, i+j, i+2*j, ... ."

function seq(from, by)
   body {
    word by0, from0;
    tended struct descrip by1, from1;
    double by2, from2;
    if (is:null(from))
        from = onedesc;
    if (is:null(by))
        by = onedesc;

    if (cnv:(exact)C_integer(by, by0) && cnv:(exact)C_integer(from, from0)) {
        /*
         * by must not be zero.
         */
        if (by0 == 0)
           runerr(211);

        if (by0 > 0) {
            for (;;) {
                suspend C_integer from0;
                if (from0 <= MaxWord - by0)
                    from0 += by0;
                else
                    break;
            }
        } else {     /* by < 0 */
            for (;;) {
                suspend C_integer from0;
                if (from0 >= MinWord - by0)
                    from0 += by0;
                else
                    break;
            }
        }
        MakeInt(from0, &from1);
        MakeInt(by0, &by1);
        for (;;) {
            bigadd(&from1, &by1, &from1);
            suspend from1;
        }
        fail;
   }
   else if (cnv:(exact)integer(by,by1) && cnv:(exact)integer(from,from1)) {
       if (bigsign(&by1) == 0)
           runerr(211);

       for (;;) {
           suspend from1;
           bigadd(&from1, &by1, &from1);
       }
       fail;
   }
   else if (cnv:C_double(from,from2) && cnv:C_double(by,by2)) {
       if (by2 == 0)
           runerr(211);

       for (;;) {
           suspend C_double from2;
           from2 += by2;
       }
       fail;
   }
   else runerr(102);
  }
end


"serial(x) - return serial number of structure."

function serial(x)
 body {
   uword id;
   tended struct descrip result;
   type_case x of {
      list:     id = ListBlk(x).id;
      set:      id = SetBlk(x).id;
      table:    id = TableBlk(x).id;
      record:   id = RecordBlk(x).id;
      object:   id = ObjectBlk(x).id;
      coexpr:   id = CoexprBlk(x).id;
      methp:    id = MethpBlk(x).id;
      weakref:  id = WeakrefBlk(x).id;
      default:  runerr(123,x);
    }
    convert_from_uword(id, &result);
    return result;
  }
end

"sort(x,i) - sort structure x by method i (for tables)"

function sort(t, i)
   type_case t of {
      list: {
         body {
            word size;
            tended struct descrip result;

            /*
             * Sort the list by copying it into a new list and then using
             *  qsort to sort the descriptors.  (That was easy!)
             */
            size = ListBlk(t).size;
            cplist(&t, &result, 1, size);
            qsort(ListBlk(result).listhead->lelem.lslots,
                  size, sizeof(struct descrip),(QSortFncCast) anycmp);

            EVValD(&result, E_Lcreate);
            return result;
            }
         }

      record: {
         body {
            dptr d1;
            word size;
            tended struct b_list *lp;
            struct b_record *bp;
            int i;
            /*
             * Create a list the size of the record, copy each element into
             * the list, and then sort the list using qsort as in list
             * sorting and return the sorted list.
             */
            size = RecordBlk(t).constructor->n_fields;

            MemProtect(lp = alclist_raw(size, size));

            bp = &RecordBlk(t);  /* need not be tended if not set until now */

            if (size > 0) {  /* only need to sort non-empty records */
               d1 = lp->listhead->lelem.lslots;
               for (i = 0; i < size; i++)
                  *d1++ = bp->fields[i];
               qsort(lp->listhead->lelem.lslots,size,
                     sizeof(struct descrip),(QSortFncCast)anycmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      set: {
         body {
            dptr d1;
            word size;
            int j, k;
            tended struct b_list *lp;
            struct b_set *bp;
            union block *ep;
            struct b_slots *seg;
            /*
             * Create a list the size of the set, copy each element into
             * the list, and then sort the list using qsort as in list
             * sorting and return the sorted list.
             */
            size = SetBlk(t).size;

            MemProtect(lp = alclist(size, size));

            bp = &SetBlk(t);  /* need not be tended if not set until now */

            if (size > 0) {  /* only need to sort non-empty sets */
               d1 = lp->listhead->lelem.lslots;
               for (j=0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
                  for (k = segsize[j] - 1; k >= 0; k--)
                     for (ep= seg->hslots[k]; BlkType(ep) == T_Selem; ep= ep->telem.clink)
                        *d1++ = ep->selem.setmem;
               qsort(lp->listhead->lelem.lslots,size,
                     sizeof(struct descrip),(QSortFncCast)anycmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      table: {
         if !def:C_integer(i, 1) then
            runerr(101, i)
         body {
            dptr d1;
            word size;
            int j, k, n;
	    tended struct b_table *bp;
            tended struct b_list *lp, *tp;
            tended union block *ep;
	    tended struct b_slots *seg;

            switch ((int)i) {

            /*
             * Cases 1 and 2 are as in early versions of Icon
             */
               case 1:
               case 2:
		      {
               /*
                * The list resulting from the sort will have as many elements
                *  as the table has, so get that value and also make a valid
                *  list block size out of it.
                */
               size = TableBlk(t).size;

	       /*
		* Make sure, now, that there's enough room for all the
		*  allocations we're going to need.
		*/
	       MemProtect(reserve(Blocks, (word)(sizeof(struct b_list)
		  + sizeof(struct b_lelem) + (size - 1) * sizeof(struct descrip)
		  + size * sizeof(struct b_list)
		  + size * (sizeof(struct b_lelem) + sizeof(struct descrip)))));

               /*
                * Point bp at the table header block of the table to be sorted
                *  and point lp at a newly allocated list
                *  that will hold the the result of sorting the table.
                */
               bp = &TableBlk(t);
               MemProtect(lp = alclist(size, size));

               /*
                * If the table is empty, there is no need to sort anything.
                */
               if (size <= 0)
                  break;
               /*
                * Traverse the element chain for each table bucket.  For each
                *  element, allocate a two-element list and put the table
                *  entry value in the first element and the assigned value in
                *  the second element.  The two-element list is assigned to
                *  the descriptor that d1 points at.  When this is done, the
                *  list of two-element lists is complete, but unsorted.
                */

               n = 0;				/* list index */
               for (j = 0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
                  for (k = segsize[j] - 1; k >= 0; k--)
                     for (ep= seg->hslots[k];
			  BlkType(ep) == T_Telem;
			  ep = ep->telem.clink){
                        MemProtect(tp = alclist_raw(2, 2));
                        tp->listhead->lelem.lslots[0] = ep->telem.tref;
                        tp->listhead->lelem.lslots[1] = ep->telem.tval;
                        d1 = &lp->listhead->lelem.lslots[n++];
                        MakeDesc(D_List, tp, d1);
                        }
               /*
                * Sort the resulting two-element list using the sorting
                *  function determined by i.
                */
               if (i == 1)
                  qsort(lp->listhead->lelem.lslots, size,
                        sizeof(struct descrip), (QSortFncCast)trefcmp);
               else
                  qsort(lp->listhead->lelem.lslots, size,
                        sizeof(struct descrip), (QSortFncCast)tvalcmp);
               break;		/* from cases 1 and 2 */
               }
            /*
             * Cases 3 and 4 were introduced in Version 5.10.
             */
               case 3 :
               case 4 :
                       {
            /*
             * The list resulting from the sort will have twice as many
             *  elements as the table has, so get that value and also make
             *  a valid list block size out of it.
             */
            size = TableBlk(t).size * 2;

            /*
             * Point bp at the table header block of the table to be sorted
             *  and point lp at a newly allocated list
             *  that will hold the the result of sorting the table.
             */
            bp = &TableBlk(t);
            MemProtect(lp = alclist(size, size));

            /*
             * If the table is empty there's no need to sort anything.
             */
            if (size <= 0)
               break;

            /*
             * Point d1 at the start of the list elements in the new list
             * element block in preparation for use as an index into the list.
             */
            d1 = lp->listhead->lelem.lslots;
            /*
             * Traverse the element chain for each table bucket.  For each
             *  table element copy the the entry descriptor and the value
             *  descriptor into adjacent descriptors in the lslots array
             *  in the list element block.
             *  When this is done we now need to sort this list.
             */

            for (j = 0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
               for (k = segsize[j] - 1; k >= 0; k--)
                  for (ep = seg->hslots[k];
		       BlkType(ep) == T_Telem;
		       ep = ep->telem.clink) {
                     *d1++ = ep->telem.tref;
                     *d1++ = ep->telem.tval;
                     }
            /*
             * Sort the resulting two-element list using the
             *  sorting function determined by i.
             */
            if (i == 3)
               qsort(lp->listhead->lelem.lslots, size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)trcmp3);
            else
               qsort(lp->listhead->lelem.lslots, size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)tvcmp4);
            break; /* from case 3 or 4 */
               }

            default: {
               Irunerr(205, i);
               }

            } /* end of switch statement */

            /*
             * Make result point at the sorted list.
             */

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      default:
         runerr(115, t);		/* structure expected */
      }
end

/*
 * trefcmp(d1,d2) - compare two-element lists on first field.
 */

static int trefcmp(dptr d1, dptr d2)
   {
   return (anycmp(&(ListBlk(*d1).listhead->lelem.lslots[0]),
                  &(ListBlk(*d2).listhead->lelem.lslots[0])));
   }

/*
 * tvalcmp(d1,d2) - compare two-element lists on second field.
 */

static int tvalcmp(dptr d1, dptr d2)
   {
   return (anycmp(&(ListBlk(*d1).listhead->lelem.lslots[1]),
      &(ListBlk(*d2).listhead->lelem.lslots[1])));
   }

/*
 * The following two routines are used to compare descriptor pairs in the
 *  experimental table sort.
 *
 * trcmp3(dp1,dp2)
 */
static int trcmp3(struct dpair *dp1, struct dpair *dp2)
{
   return (anycmp(&((*dp1).dr),&((*dp2).dr)));
}

/*
 * tvcmp4(dp1,dp2)
 */
static int tvcmp4(struct dpair *dp1, struct dpair *dp2)
{
    return (anycmp(&((*dp1).dv),&((*dp2).dv)));
}


"sortf(x,i) - sort list or set x on field i of each member"

function sortf(t, i)
  if !def:C_integer(i, 1) then
     runerr (101, i)

  body {
   if (i == 0)
       Irunerr(205, i);

   type_case t of {
      list: {
         word size;
         tended struct descrip result;

         /*
          * Sort the list by copying it into a new list and then using
          *  qsort to sort the descriptors.  (That was easy!)
          */
         size = ListBlk(t).size;
         cplist(&t, &result, 1, size);
         sort_field = i;
         qsort(ListBlk(result).listhead->lelem.lslots,
               size, sizeof(struct descrip),(QSortFncCast) nthcmp);

         EVValD(&result, E_Lcreate);
         return result;
      }

      record: {
         dptr d1;
         word size;
         tended struct b_list *lp;
         struct b_record *bp;
         int j;

         /*
          * Create a list the size of the record, copy each element into
          * the list, and then sort the list using qsort as in list
          * sorting and return the sorted list.
          */
         size = RecordBlk(t).constructor->n_fields;

         MemProtect(lp = alclist_raw(size, size));

         bp = &RecordBlk(t);  /* need not be tended if not set until now */

         if (size > 0) {  /* only need to sort non-empty records */
             d1 = lp->listhead->lelem.lslots;
             for (j = 0; j < size; j++)
                 *d1++ = bp->fields[j];
             sort_field = i;
             qsort(lp->listhead->lelem.lslots,size,
                   sizeof(struct descrip),(QSortFncCast)nthcmp);
         }

         Desc_EVValD(lp, E_Lcreate, D_List);
         return list(lp);
       }

      set: {
         dptr d1;
         word size;
         int j, k;
         tended struct b_list *lp;
         union block *ep;
         struct b_set *bp;
         struct b_slots *seg;

         /*
          * Create a list the size of the set, copy each element into
          * the list, and then sort the list using qsort as in list
          * sorting and return the sorted list.
          */
         size = SetBlk(t).size;

         MemProtect(lp = alclist(size, size));

         bp = &SetBlk(t);  /* need not be tended if not set until now */

         if (size > 0) {  /* only need to sort non-empty sets */
             d1 = lp->listhead->lelem.lslots;
             for (j = 0; j < HSegs && (seg = bp->hdir[j]) != NULL; j++)
                 for (k = segsize[j] - 1; k >= 0; k--)
                     for (ep = seg->hslots[k]; BlkType(ep) == T_Selem; ep= ep->telem.clink)
                         *d1++ = ep->selem.setmem;
             sort_field = i;
             qsort(lp->listhead->lelem.lslots,size,
                   sizeof(struct descrip),(QSortFncCast)nthcmp);
         }

         Desc_EVValD(lp, E_Lcreate, D_List);
         return list(lp);
       }

      default:
         runerr(125, t);	/* list, record, or set expected */
      }
  }
end


/*
 * nthcmp(d1,d2) - compare two descriptors on their nth fields.
 */
static int nthcmp(dptr d1, dptr d2)
   {
   int t1, t2, rv;
   dptr e1, e2;

   t1 = Type(*d1);
   t2 = Type(*d2);
   if (t1 == t2 && (t1 == T_Record || t1 == T_List)) {
      e1 = nth(d1);		/* get nth field, or NULL if none such */
      e2 = nth(d2);
      if (e1 == NULL) {
         if (e2 != NULL)
            return -1;		/* no-nth-field is < any nth field */
         }
      else if (e2 == NULL)
	 return 1;		/* any nth field is > no-nth-field */
      else {
	 /*
	  *  Both had an nth field.  If they're unequal, that decides.
	  */
         rv = anycmp(nth(d1), nth(d2));
         if (rv != 0)
            return rv;
         }
      }
   /*
    * Comparison of nth fields was either impossible or indecisive.
    *  Settle it by comparing the descriptors directly.
    */
   return anycmp(d1, d2);
   }

/*
 * nth(d) - return the nth field of d, if any.  (sort_field is "n".)
 */
static dptr nth(dptr d)
{
    word i;
    dptr rv;

    rv = NULL;
    if (d->dword == D_Record) {
        union block *bp;
        /*
         * Find the nth field of a record.
         */
        bp = BlkLoc(*d);
        i = cvpos_item(sort_field, bp->record.constructor->n_fields);
        if (i != CvtFail)
            rv = &bp->record.fields[i-1];
    }
    else if (d->dword == D_List) {
        struct b_list *lp;
        /*
         * Find the nth element of a list.
         */
        lp = &ListBlk(*d);
        i = cvpos_item(sort_field, lp->size);
        if (i != CvtFail) {
            struct b_lelem *le;
            word pos;
            le = get_lelem_for_index(lp, i, &pos);
            if (!le)
                syserr("Failed to find lelem for valid index");
            pos += le->first;
            if (pos >= le->nslots)
                pos -= le->nslots;
            rv = &le->lslots[pos];
        }
    }
    return rv;
}


"type(x) - return type of x as a string."

function type(x)
   body {
      type_case x of {
         string:      return C_string "string";
         null:        return C_string "null";
         yes:         return C_string "yes";
         integer:     return C_string "integer";
         real:        return C_string "real";
         cset:        return C_string "cset";
         proc:        return C_string "procedure";
         list:        return C_string "list";
         table:       return C_string "table";
         set:         return C_string "set";
         class:       return C_string "class";
         constructor: return C_string "constructor";
         record:      return C_string "record";
         object:      return C_string "object";
         methp:       return C_string "methp";
         ucs:         return C_string "ucs";
         coexpr:      return C_string "co-expression";
         weakref:     return C_string "weakref";
         default:     runerr(123,x);
      }
   }
end

#if 0
static int debug = 0;

static void print_ucs(struct b_ucs *b)
{
    word i, n_slots;
    n_slots = get_ucs_n_slots(b);
    fprintf(stderr, "Length in ucs chars: " WordFmt "\n", b->length);
    fprintf(stderr, "UTF-8 length: " WordFmt "\n", StrLen(b->utf8));
    fprintf(stderr, "Index step: " WordFmt "\n", b->index_step);
    fprintf(stderr, "Index len in offsets: " WordFmt "\n", n_slots);
    if (n_slots > 0)
        fprintf(stderr, "Index len in words: " WordFmt "\n", 
                (b->blksize - sizeof(struct b_ucs)) / sizeof(word) + 1);
    fprintf(stderr, "Offset bits: " WordFmt "\n", b->offset_bits);
    fprintf(stderr, "Offset to UTF-8 ratio: %.2f%%\n", 
            (float)(100.0 * n_slots * (b->offset_bits)/8) / StrLen(b->utf8));
    fprintf(stderr, "N left indexed: " WordFmt "\n", b->n_off_l_indexed);
    for (i = 0; i < b->n_off_l_indexed; ++i)
        fprintf(stderr, "\t" WordFmt " -> icon char " WordFmt " -> off " WordFmt "\n", i, 
                (b->index_step * (i + 1) + 1), get_ucs_slot(b, i));
    fprintf(stderr, "N right indexed: " WordFmt "\n", b->n_off_r_indexed);
    if (b->n_off_l_indexed != n_slots || b->n_off_r_indexed != n_slots) {
        for (i = n_slots - b->n_off_r_indexed; i < n_slots; ++i)
            fprintf(stderr, "\t" WordFmt " -> icon char " WordFmt " -> off " WordFmt "\n", i, 
                    (b->index_step * (i + 1) + 1), get_ucs_slot(b, i));
    }
}
#endif

static word get_ucs_n_slots(struct b_ucs *b)
{
    return (b->length - 1) / b->index_step;
}

static word get_ucs_slot(struct b_ucs *b, word i)
{
    switch (b->offset_bits) {
        case 8: {
            unsigned char *p = (unsigned char *)(b->off);
            return (word)p[i];
        }
        case 16: {
            uint16_t *p = (uint16_t *)(b->off);
            return (word)p[i];
        }
#if WordBits == 32
        case 32: {
            return b->off[i];
        }
#else
        case 32: {
            uint32_t *p = (uint32_t *)(b->off);
            return (word)p[i];
        }
        case 64: {
            return b->off[i];
        }
#endif
        default: {
            syserr("Invalid offset_bits");
            return 0;
        }
    }

}

static void set_ucs_slot(struct b_ucs *b, word i, word n)
{
    switch (b->offset_bits) {
        case 8: {
            unsigned char *p = (unsigned char *)(b->off);
            p[i] = (unsigned char)n;
            break;
        }
        case 16: {
            uint16_t *p = (uint16_t *)(b->off);
            p[i] = (uint16_t)n;
            break;
        }
#if WordBits == 32
        case 32: {
            b->off[i] = n;
            break;
        }
#else
        case 32: {
            uint32_t *p = (uint32_t *)(b->off);
            p[i] = (uint32_t)n;
            break;
        }
        case 64: {
            b->off[i] = n;
            break;
        }
#endif
        default: {
            syserr("Invalid offset_bits");
            break;
        }
    }
}

/*
 * Ensure that the offset slot number d is calculated.
 */
static void ensure_ucs_slot(struct b_ucs *b, word d)
{
    word i, nd, n_slots;
    char *p;

    /*
     * The number of offset slots allocated.
     */
    n_slots = get_ucs_n_slots(b);

    /*
     * Check if we've already calculated this offset.
     */
    if (d < b->n_off_l_indexed || d >= n_slots - b->n_off_r_indexed)
        return;

    p = StrLoc(b->utf8);

    /*
     * nd is the ucs index corresponding to slot d.  Note it is a
     * multiple of b->index_step, so we will fill it in on the
     * last iteration of the while loops below, when i == nd.
     */
    nd = (d + 1) * b->index_step;

    /*
     * Decide whether to expand the left or right index blocks.
     */
    if (d - (b->n_off_l_indexed - 1) > (n_slots - b->n_off_r_indexed) - d) {
        /*
         * Iterate from the rightmost calculated offset (if any) and
         * move left, saving all the intermediate offset points.
         */
        if (b->n_off_r_indexed > 0) {
            p += get_ucs_slot(b, n_slots - b->n_off_r_indexed);
            i = (n_slots - b->n_off_r_indexed + 1) * b->index_step;
        } else {
            p += StrLen(b->utf8);
            i = b->length;
        }
        while (i > nd) {
            utf8_rev_iter0(&p);
            --i;
            if (i % b->index_step == 0)
                set_ucs_slot(b, n_slots - ++b->n_off_r_indexed, p - StrLoc(b->utf8));
        }
    } else {
        /*
         * Start at the last offset calculated (if any) and move
         * forward, saving all the intermediate offset points.
         */
        if (b->n_off_l_indexed > 0) {
            p += get_ucs_slot(b, b->n_off_l_indexed - 1);
            i = b->n_off_l_indexed * b->index_step;
        } else
            i = 0;
        while (i < nd) {
            p += UTF8_SEQ_LEN(*p);
            ++i;
            if (i % b->index_step == 0)
                set_ucs_slot(b, b->n_off_l_indexed++, p - StrLoc(b->utf8));
        }
    }

    /*
     * Just to keep the fields correct, note if the left and right
     * extents have joined.
     */
    if (b->n_off_l_indexed + b->n_off_r_indexed == n_slots)
        b->n_off_r_indexed = b->n_off_l_indexed = n_slots;
}

/*
 * Lookup a pointer into the utf8 string for the given ucs block at
 * unicode char position n (zero-based).  n may be b->length in which
 * case a pointer just past the end of the utf8 string is returned;
 * otherwise n must be >= 0 and < b->length.  For each ucs block (with
 * non-ascii chars), there are (b->length-1)/b->index_step offset
 * slots.  off[x] gives the offset of unicode char ((x+1) *
 * b->index_step).  For example if b->index_step = 8, then for a
 * length of 20 there are two offset entries for unicode chars 8 and
 * 16 (zero based).
 */
static char *get_ucs_off(struct b_ucs *b, word n)
{
    word d, l, r, n_slots;
    char *p = StrLoc(b->utf8);

    /*
     * Special case of looking up just past the end of the last char.
     */
    if (n == b->length)
        return p + StrLen(b->utf8);

    /*
     * Special case of looking up the first char.
     */
    if (n == 0)
        return p;

    /*
     * If the index_step is 0, it means the utf8 string is ascii, so
     * we can use direct indexing.
     */
    if (b->index_step == 0)
        return p + n;

    /*
     * The number of offset slots allocated.
     */
    n_slots = get_ucs_n_slots(b);

    /*
     * Get the index into off before n.  May be -1, if n is to the
     * left of the first slot, or there are no slots.
     */
    d = n / b->index_step - 1;

    /*
     * Calculate l, the distance to the known position to the left of
     * n; either the offset to the left or the start of the string.
     */
    if (d >= 0)
        l = n % b->index_step;
    else
        l = n;

    /*
     * Similarly calculate r, the distance to the known position to
     * the right.  Either the next offset along from n, or the end of
     * the string.
     */
    if (d + 1 < n_slots)
        r = b->index_step - l;
    else
        r = b->length - n;

    /*
     * Now decide whether to iterate leftwards or rightwards.
     */
    if (l < r) {
        /*
         * Go right l positions from the starting point.
         */
        if (d >= 0) {
            ensure_ucs_slot(b, d);
            p += get_ucs_slot(b, d);
        }
        while (l-- > 0)
            p += UTF8_SEQ_LEN(*p);
    } else {
        /*
         * Go left r positions from the starting point.
         */
        if (d + 1 < n_slots) {
            ensure_ucs_slot(b, d + 1);
            p += get_ucs_slot(b, d + 1);
        } else
            p += StrLen(b->utf8);
        while (r-- > 0)
            utf8_rev_iter0(&p);
    }
    return p;
}

/*
 * Allocate and initialize a ucs block given a utf8 string and a
 * unicode length.  The utf8 string must be valid and have length
 * unicode chars in it; utf8 must also point to a tended or stack
 * descriptor.
 */
struct b_ucs *make_ucs_block(dptr utf8, word length)
{
    struct b_ucs *p;                   /* Doesn't need to be tended */
    word index_step, n_offs, offset_bits, n_off_words;
    if (length == 0)
        return emptystr_ucs;
    calc_ucs_index_settings(StrLen(*utf8), length, &index_step, &n_offs, &offset_bits, &n_off_words);
    MemProtect(p = alcucs(n_off_words));
    p->index_step = index_step;
    p->utf8 = *utf8;
    p->length = length;
    p->n_off_l_indexed = p->n_off_r_indexed = 0;
    p->offset_bits = offset_bits;
    return p;
}

/*
 * Convenient function to build a one-char ucs block for the
 * given code point.
 */
struct b_ucs *make_one_char_ucs_block(int i)
{
    tended struct descrip s;
    char utf8[MAX_UTF8_SEQ_LEN];
    int n;
    if (i < 0 || i > MAX_CODE_POINT)
        syserr("Bad codepoint to make_one_char_ucs_block");
    n = utf8_seq(i, utf8);
    MakeStrMemProtect(alcstr(utf8, n), n, &s);
    return make_ucs_block(&s, 1);
}

/*
 * Helper function to make a new ucs block which is a substring of the
 * given ucs block.  NB pos is one-based.
 */
struct b_ucs *make_ucs_substring(struct b_ucs *b, word pos, word len)
{
    char *p, *q;
    word first, last;
    tended struct descrip utf8;
    if (len == 0)
        return emptystr_ucs;
    if (pos == 1 && len == b->length)
        return b;

    first = pos - 1;
    last = first + len - 1;

    if (len < 0 || first < 0 || last < 0 || first >= b->length || last >= b->length)
        syserr("Invalid pos/len to make_ucs_substring");

    p = get_ucs_off(b, first);
    if (b->index_step == 0 || last / b->index_step > first / b->index_step)
        q = get_ucs_off(b, last + 1);
    else {
        word i = len;
        q = p;
        while (i-- > 0)
            q += UTF8_SEQ_LEN(*q);
    }
    MakeStr(p, q - p, &utf8);
    return make_ucs_block(&utf8, len);
}

/*
 * Given a ucs block, this function returns (in res) the utf8
 * substring corresponding to the slice pos:len.  No allocation is
 * done.  pos,len must be a valid range for the string.  NB pos is
 * one-based.
 */
void utf8_substr(struct b_ucs *b, word pos, word len, dptr res)
{
    char *p, *q;
    word first, last;

    if (len == 0) {
        *res = emptystr;
        return;
    }
    if (pos == 1 && len == b->length) {
        *res = b->utf8;
        return;
    }

    first = pos - 1;
    last = first + len - 1;

    if (len < 0 || first < 0 || last < 0 || first >= b->length || last >= b->length)
        syserr("Invalid pos/len to uf8_substr");

    p = get_ucs_off(b, first);
    if (b->index_step == 0 || last / b->index_step > first / b->index_step)
        q = get_ucs_off(b, last + 1);
    else {
        q = p;
        while (len-- > 0)
            q += UTF8_SEQ_LEN(*q);
    }
    MakeStr(p, q - p, res);
}

/*
 * Given a ucs block, this function returns the unicode character
 * at the requested position.  NB pos is one-based.
 */
int ucs_char(struct b_ucs *b, word pos)
{
    char *p;
    --pos;  /* Make pos zero-based */
    if (pos < 0 || pos >= b->length)
        syserr("Invalid pos to ucs_char");
    p = get_ucs_off(b, pos);
    return utf8_iter(&p);
}

/*
 * Given a ucs block, this function returns a pointer into the utf8
 * string for the given unicode character.  NB pos is one-based, but
 * may be b->length + 1, in which case the char just after the end of
 * the utf8 string is returned (it may not be dereferenced).
 */
char *ucs_utf8_ptr(struct b_ucs *b, word pos)
{
    --pos;  /* Make pos zero-based */
    if (pos < 0 || pos > b->length)
        syserr("Invalid pos to ucs_utf8_ptr");
    return get_ucs_off(b, pos);
}

/*
 * Compare n bytes of memory from s1 and s2 for equality.  This is
 * rather like memcmp, but will never read beyond the first different
 * byte of either string.
 */
int mem_eq(char *s1, char *s2, word n)
{
    while (n--)
        if (*s1++ != *s2++)
            return 0;
    return 1;
}

/*
 * Compare the contents of string s with t using mem_eq().
 */
int str_mem_eq(dptr s, char *t)
{
    return mem_eq(StrLoc(*s), t, StrLen(*s));
}

/*
 * Convert a rangeset to a newly allocated b_cset block.
 */
struct b_cset *rangeset_to_block(struct rangeset *rs)
{
    struct b_cset *blk;
    int i, j;

    MemProtect(blk = alccset(rs->n_ranges));
    blk->n_ranges = rs->n_ranges;
    blk->size = 0;
    memset(blk->bits, 0, sizeof(blk->bits));
    for (i = 0; i < blk->n_ranges; ++i) {
        blk->range[i].from = rs->range[i].from;
        blk->range[i].to = rs->range[i].to;
        blk->range[i].index = blk->size;
        blk->size += blk->range[i].to - blk->range[i].from + 1;
        for (j = blk->range[i].from; j <= blk->range[i].to; ++j) {
            if (j > 0xff)
                break;
            Setb(j, blk->bits);
        }
    }
    return blk;
}

/*
 * Test whether character (code point) c is in the given cset block.
 */
int in_cset(struct b_cset *b, int c)
{
    int l, r, m;
    if (c < 256)
        return Testb(c, b->bits);
    l = 0;
    r = b->n_ranges - 1;
    while (l <= r) {
        m = (l + r) / 2;
        if (c < b->range[m].from)
            r = m - 1;
        else if (c > b->range[m].to)
            l = m + 1;
        else  /* c >= b->range[m].from && c <= b->range[m].to */
            return 1;
    }
    return 0;
}

/*
 * Return the index of the range which contains the given index (one-based),
 * which must be valid.
 */
int cset_range_of_pos(struct b_cset *b, word pos)
{
    int l, r, m;
    l = 0;
    r = b->n_ranges - 1;
    --pos;
    /* Common case of looking up first pos */
    if (pos == 0 && b->n_ranges > 0)
        return 0;
    while (l <= r) {
        m = (l + r) / 2;
        if (pos < b->range[m].index)
            r = m - 1;
        else if (pos > b->range[m].index + b->range[m].to - b->range[m].from)
            l = m + 1;
        else /* b->range[m].index <= pos <= b->range[m].index + b->range[m].to - b->range[m].from */
            return m;
    }
    syserr("Invalid index to cset_range_of_pos");
    /* Not reached */
    return 0;
}

/*
 * Create a ucs block consisting of the characters from the given cset,
 * in the range pos:len.
 */
struct b_ucs *cset_to_ucs_block(struct b_cset *b0, word pos, word len)
{
    char buf[MAX_UTF8_SEQ_LEN];
    tended struct b_cset *b = b0;
    tended struct descrip utf8;
    int i, first;
    word j, l0, p0, from, to, utf8_len;

    if (len == 0)
        return emptystr_ucs;

    first = cset_range_of_pos(b, pos);  /* The first row of interest */
    --pos;  /* Make zero-based */

    /*
     * Calcuate utf8 length
     */

    l0 = len;
    i = first;
    p0 = pos - b->range[i].index;   /* Offset into first range */
    utf8_len = 0;
    for (; l0 > 0 && i < b->n_ranges; ++i) {
        from = b->range[i].from;
        to = b->range[i].to;
        for (j = p0 + from; l0 > 0 && j <= to; ++j) {
            utf8_len += utf8_seq(j, 0);
            --l0;
        }
        p0 = 0;
    }
    /* Ensure we found len chars. */
    if (l0)
        syserr("cset_to_ucs_block inconsistent parameters");

    MakeStrMemProtect(reserve(Strings, utf8_len), utf8_len, &utf8);

    /*
     * Same loop again, to build utf8 string.
     */
    l0 = len;
    i = first;
    p0 = pos - b->range[i].index;
    for (; l0 > 0 && i < b->n_ranges; ++i) {
        from = b->range[i].from;
        to = b->range[i].to;
        for (j = p0 + from; l0 > 0 && j <= to; ++j) {
            int n = utf8_seq(j, buf);
            alcstr(buf, n);
            --l0;
        }
        p0 = 0;
    }

    return make_ucs_block(&utf8, len);
}

/*
 * Convert part of a cset block to a newly allocated string, storing
 * the result in res.
 */
void cset_to_string(struct b_cset *b, word pos, word len, dptr res)
{
    int i;
    word j, from, to, out_len;
    char c[256];

    if (len == 0) {
        *res = emptystr;
        return;
    }

    i = cset_range_of_pos(b, pos);  /* The first row of interest */
    --pos;
    pos -= b->range[i].index;       /* Offset into first range */
    out_len = 0;
    for (; len > 0 && i < b->n_ranges; ++i) {
        from = b->range[i].from;
        to = b->range[i].to;
        for (j = pos + from; len > 0 && j <= to; ++j) {
            if (j < 256) {
                c[out_len++] = (char)j;
                --len;
            } else
                syserr("attempt to convert cset_to_string with chars > 255");
        }
        pos = 0;
    }
    /* Ensure we found len chars. */
    if (len)
        syserr("cset_to_string inconsistent parameters");
    MakeStrMemProtect(alcstr(c, out_len), out_len, res);
}

"uchar(i) - produce a ucs consisting of character i."

function uchar(i)

   if !cnv:C_integer(i) then
      runerr(101,i)
   body {
      if (i < 0 || i > MAX_CODE_POINT)
          fail;
      return ucs(make_one_char_ucs_block(i));
   }
end

function lang_Text_utf8_seq(i)

   if !cnv:C_integer(i) then
      runerr(101,i)
   body {
      int n;
      char utf8[MAX_UTF8_SEQ_LEN], *a;
      if (i < 0 || i > MAX_CODE_POINT)
          fail;
      n = utf8_seq(i, utf8);
      MemProtect(a = alcstr(utf8, n));
      return string(n, a);
   }
end

function lang_Text_caseless_compare(s1, s2)
   body {
      if (EqlDesc(s1,s2))
          return C_integer Equal;
      if (is:string(s1) && is:string(s2))
          return C_integer caseless_lexcmp(&s1, &s2);
      if (is:ucs(s1) && is:ucs(s2))
          return C_integer caseless_lexcmp(&UcsBlk(s1).utf8, &UcsBlk(s2).utf8);
      return C_integer anycmp(&s1, &s2);
   }
end

function lang_Text_consistent_compare(s1, s2)
   body {
      if (EqlDesc(s1,s2))
          return C_integer Equal;
      if (is:string(s1) && is:string(s2))
          return C_integer consistent_lexcmp(&s1, &s2);
      if (is:ucs(s1) && is:ucs(s2))
          return C_integer consistent_lexcmp(&UcsBlk(s1).utf8, &UcsBlk(s2).utf8);
      return C_integer anycmp(&s1, &s2);
   }
end

function lang_Text_create_cset(x[n])
   body {
     struct rangeset *rs;
     tended struct b_cset *b;
     word from, to;
     int i;

     rs = init_rangeset();
     i = 0;
     while (i < n) {
         if (is:list(x[i])) {
             union block *pb = BlkLoc(x[i]);
             int j, k;
             /*
              * Chain through each list block and add the ranges
              */
             from = -1;
             for (pb = pb->list.listhead;
                  pb && (BlkType(pb) == T_Lelem);
                  pb = pb->lelem.listnext) {
                 for (j = 0; j < pb->lelem.nused; j++) {
                     k = pb->lelem.first + j;
                     if (k >= pb->lelem.nslots)
                         k -= pb->lelem.nslots;
                     if (!cnv:C_integer(pb->lelem.lslots[k], to)) {
                         free_rangeset(rs);
                         runerr(101, pb->lelem.lslots[k]);
                     }
                     if (to < 0 || to > MAX_CODE_POINT) {
                         whyf("Invalid codepoint:" WordFmt, to);
                         free_rangeset(rs);
                         fail;
                     }
                     if (from == -1)
                         from = to;
                     else {
                         add_range(rs, from, to);
                         from = -1;
                     }
                 }
             }
             if (from != -1)
                 add_range(rs, from, from);
             ++i;
         } else {
             if (!cnv:C_integer(x[i], from)) {
                 free_rangeset(rs);
                 runerr(101, x[i]);
             }
             if (from < 0 || from > MAX_CODE_POINT) {
                 whyf("Invalid codepoint:" WordFmt, from);
                 free_rangeset(rs);
                 fail;
             }
             ++i;
             if (i < n) {
                 if (!cnv:C_integer(x[i], to)) {
                     free_rangeset(rs);
                     runerr(101, x[i]);
                 }
                 if (to < 0 || to > MAX_CODE_POINT) {
                     whyf("Invalid codepoint:" WordFmt, to);
                     free_rangeset(rs);
                     fail;
                 }
                 add_range(rs, from, to);
                 ++i;
             } else
                 add_range(rs, from, from);
         }
     }
     b = rangeset_to_block(rs);
     free_rangeset(rs);
     return cset(b);
   }
end

function lang_Text_get_ord_range(c)
   if !cnv:cset(c) then
      runerr(120, c)
   body {
       int i;
       for (i = 0; i < CsetBlk(c).n_ranges; ++i) {
           suspend C_integer CsetBlk(c).range[i].from;
           suspend C_integer CsetBlk(c).range[i].to;
       }
       fail;
   }
end

function lang_Text_slice(c, i, j)
   if !cnv:cset(c) then
      runerr(104, c)
    /* Same error check as in operator [:] */
   if !cnv:C_integer(i) then {
      if cnv : integer(i) then body { fail; }
      runerr(101, i)
   }
   if !cnv:C_integer(j) then {
      if cnv : integer(j) then body { fail; }
      runerr(101, j)
   }
   body {
       struct rangeset *rs;
       tended struct b_cset *blk;
       word len;

       if (!cvslice(&i, &j, CsetBlk(c).size))
          fail;
       len = j - i;

       rs = init_rangeset();
       if (len > 0) {
           int a, pos, from, to, l0;
           a = cset_range_of_pos(&CsetBlk(c), i);    /* First range of interest */
           pos = i - 1 - CsetBlk(c).range[a].index;  /* Offset into that range */
           for (; len > 0 && a < CsetBlk(c).n_ranges; ++a) {
               from = CsetBlk(c).range[a].from;
               to = CsetBlk(c).range[a].to;
               l0 = to - from - pos + 1;
               if (l0 <= len) {
                   add_range(rs, from + pos, to);
                   len -= l0;
               } else {
                   add_range(rs, from + pos, len + from + pos - 1);
                   len = 0;
               }
               pos = 0;
           }
           if (len)
               syserr("slice_cset inconsistent parameters");
       }
       
       blk = rangeset_to_block(rs);
       free_rangeset(rs);
       return cset(blk);
   }
end

function lang_Text_is_ascii_string(s)
   body {
    if (is_ascii_string(&s))
        return s;
    else
        fail;
  }
end

function lang_Text_has_ord(c, x)
   if !cnv:cset(c) then
      runerr(120, c)
   if !cnv:C_integer(x) then
      runerr(101, x)
   body {
    int l, r, m;
    struct b_cset *b = &CsetBlk(c);
    l = 0;
    r = b->n_ranges - 1;
    while (l <= r) {
        m = (l + r) / 2;
        if (x < b->range[m].from)
            r = m - 1;
        else if (x > b->range[m].to)
            l = m + 1;
        else  /*  b->range[m].from <= x <= b->range[m].to */
            return C_integer b->range[m].index + x - b->range[m].from + 1;
    }
    fail;
   }
end


"ord(c) - generate the code points in a cset, ucs or string for the range of entries i:j"

function ord(x, i, j)
    /* Similar error check as in operator [:] */
   if !def:C_integer(i, 1) then {
      if cnv : integer(i) then body { fail; }
      runerr(101, i)
   }
   if !def:C_integer(j, 0) then {
      if cnv : integer(j) then body { fail; }
      runerr(101, j)
   }
   body {
       word len;
       tended char *p;

       type_case x of {
         cset: {
            int a, b, pos, from, to;

            if (!cvslice(&i, &j, CsetBlk(x).size))
                fail;
            len = j - i;

            if (len == 0)
                fail;

            a = cset_range_of_pos(&CsetBlk(x), i);    /* First range of interest */
            pos = i - 1 - CsetBlk(x).range[a].index;  /* Offset into that range */
            for (; len > 0 && a < CsetBlk(x).n_ranges; ++a) {
                from = CsetBlk(x).range[a].from;
                to = CsetBlk(x).range[a].to;
                for (b = pos + from; len > 0 && b <= to; ++b) {
                    suspend C_integer b;
                    --len;
                }
                pos = 0;
            }
            if (len)
                syserr("ords inconsistent parameters");
            fail;
         }

         ucs : {
            if (!cvslice(&i, &j, UcsBlk(x).length))
                fail;
            len = j - i;

            if (len == 0)
                fail;

            p = ucs_utf8_ptr(&UcsBlk(x), i);
            while (len-- > 0)
                suspend C_integer utf8_iter(&p);

            fail;
         }

         default : {
            if (!cnv:string(x,x))
                runerr(132, x);

            if (!cvslice(&i, &j, StrLen(x)))
                fail;
            len = j - i;

            if (len == 0)
                fail;

            p = StrLoc(x) + i - 1;
            while (len-- > 0)
                suspend C_integer (*p++) & 0xff;

            fail;
         }         
      }
   }
end

