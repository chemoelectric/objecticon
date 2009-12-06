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
   type_case x of {
      null:
      string:
      ucs:
      cset:
      integer:
      real:
      proc:
      methp:
      cast:
      object:
      class:
      constructor:
      coexpr: {
            /*
             * Copy the null value, integers, long integers, reals, files,
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
            cplist(&x, &result, (word)1, ListBlk(x).size + 1);
            return result;
            }
      table: {
            cptable(&x, &result, TableBlk(x).size);
	    return result;
         }

      set: {
            /*
             * Pass the buck to cpset to copy a set.
             */
            cpset(&x, &result, SetBlk(x).size);
	    return result;
         }

      record: {
            /*
             * Note, these pointers don't need to be tended, because they are
             *  not used until after allocation is complete.
             */
            struct b_record *new_rec;
            tended struct b_record *old_rec;
            dptr d1, d2;
            int i;

            /*
             * Allocate space for the new record and copy the old
             *	one into it.
             */
            old_rec = &RecordBlk(x);
            i = old_rec->constructor->n_fields;

            /* #%#% param changed ? */
            MemProtect(new_rec = alcrecd(old_rec->constructor));
            d1 = new_rec->fields;
            d2 = old_rec->fields;
            while (i--)
               *d1++ = *d2++;
	    Desc_EVValD(new_rec, E_Rcreate, D_Record);
            return record(new_rec);
         }

      default:  {
            runerr(123,x);
         }
      }
   }
end


"errorclear() - clear error condition."

function errorclear()
   body {
      k_errornumber = 0;
      k_errortext = emptystr;
      k_errorvalue = nulldesc;
      have_errval = 0;
      return nulldesc;
      }
end


/*
 * the bitwise operators are identical enough to be expansions
 *  of a macro.
 */

#begdef  bitop(func_name, c_op, operation)
#func_name "(i,j) - produce bitwise " operation " of i and j."
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
      if ((Type(i)==T_Lrgint) || (Type(j)==T_Lrgint)) {
         big_ ## c_op(i, j);
      }
      else
          MakeInt(IntVal(i) c_op IntVal(j), &result);

      /*
       * Process any optional additonal params.
       */
      for (k = 0; k < n; ++k) {
          if (!cnv:integer(a[k], a[k]))
              runerr(101, a[k]);
          if ((Type(result) == T_Lrgint) || (Type(a[k]) == T_Lrgint)) {
              big_ ## c_op(result, a[k]);
          }
          else
              MakeInt(IntVal(result) c_op IntVal(a[k]), &result);
      }

      return result;
   }
end
#enddef

#define bitand &
#define bitor  |
#define bitxor ^
#begdef big_bitand(x,y)
{
    bigand(&x, &y, &result);
}
#enddef
#begdef big_bitor(x,y)
{
    bigor(&x, &y, &result);
}
#enddef
#begdef big_bitxor(x,y)
{
    bigxor(&x, &y, &result);
}
#enddef

bitop(iand, bitand, "AND")          /* iand(i,j) bitwise "and" of i and j */
bitop(ior,  bitor, "inclusive OR")  /* ior(i,j) bitwise "or" of i and j */
bitop(ixor, bitxor, "exclusive OR") /* ixor(i,j) bitwise "xor" of i and j */


"icom(i) - produce bitwise complement (one's complement) of i."

function icom(i)
   /*
    * i must be an integer
    */
   if !cnv:integer(i) then
      runerr(101, i)

   body {
      if (Type(i) == T_Lrgint) {
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
      getimage(&x,&result);
      return result;
      }
end


"ishift(i,j) - produce i shifted j bit positions (left if j<0, right if j>0)."

function ishift(i,j)

   if !cnv:integer(i) then
      runerr(101, i)
   if !cnv:integer(j) then
      runerr(101, j)

   body {
      uword ci;			 /* shift in 0s, even if negative */
      C_integer cj;
      if (Type(j) == T_Lrgint)
         runerr(101,j);
      cj = IntVal(j);
      if (Type(i) == T_Lrgint || cj >= WordBits
      || ((ci=(uword)IntVal(i))!=0 && cj>0 && (ci >= (1<<(WordBits-cj-1))))) {
         bigshift(&i, &j, &result);
         return result;
         }
      /*
       * Check for a shift of WordSize or greater; handle specially because
       *  this is beyond C's defined behavior.  Otherwise shift as requested.
       */
      if (cj >= WordBits)
         return C_integer 0;
      if (cj <= -WordBits)
         return C_integer ((IntVal(i) >= 0) ? 0 : -1);
      if (cj >= 0)
         return C_integer ci << cj;
      if (IntVal(i) >= 0)
         return C_integer ci >> -cj;
      /*else*/
         return C_integer ~(~ci >> -cj);	/* sign extending shift */
      }
end


/*
 * Common code for runerr, fatalerr
 */
#begdef ERRFUNC()
{
    word err_num;
    char *s;
    int j;

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

    if (IntVal(kywd_err) != 0) {
        IntVal(kywd_err)--;
        errorfail;
    }

    s = StrLoc(k_errortext);
    j = StrLen(k_errortext);
    if (k_errornumber > 0)
        fprintf(stderr, "\nRun-time error %d\n", k_errornumber);
    else 
        fprintf(stderr, "\nRun-time error: ");
    while (j-- > 0)
        fputc(*s++, stderr);
    fputc('\n', stderr);

    if (have_errval) {
        fprintf(stderr, "offending value: ");
        outimage(stderr, &k_errorvalue, 0);
        putc('\n', stderr);
    }

    fprintf(stderr, "Traceback:\n");
    traceback();
    fflush(stderr);

    if (dodump > 1)
        abort();

    c_exit(EXIT_FAILURE);

    errorfail;
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
      IntVal(kywd_err) = 0;
      ERRFUNC();
   }
end

function syserr(msg)
   if !cnv:string(msg) then
      runerr(103, msg)

   body {
      char *s = StrLoc(msg);
      int i = StrLen(msg);
      struct ipc_line *pline;
      struct ipc_fname *pfile;

      pline = frame_ipc_line(curr_pf, 1);
      pfile = frame_ipc_fname(curr_pf, 1);

      fprintf(stderr, "\nIcon-level internal error: ");
      while (i-- > 0)
          fputc(*s++, stderr);
      fputc('\n', stderr);
      if (pline && pfile) {
          struct descrip t;
          abbr_fname(pfile->fname, &t);
          fprintf(stderr, "File %.*s; Line %d\n", (int)StrLen(t), StrLoc(t), (int)pline->line);
      } else
          fprintf(stderr, "File ?; Line ?\n");

      fprintf(stderr, "Traceback:\n");
      traceback();
      fflush(stderr);

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
        if (by0 == 0) {
            irunerr(211, by0);
            errorfail;
        }

        if (by0 > 0) {
            for (;;) {
                word t;
                suspend C_integer from0;
                t = from0 + by0;
                if (t <= from0)
                    break;
                from0 = t;
            }
        } else {
            for (;;) {
                word t;
                suspend C_integer from0;
                t = from0 + by0;
                if (t >= from0)
                    break;
                from0 = t;
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
       word sn = bigcmp(&by1, &zerodesc);
       if (sn == 0) {
           runerr(211, by1);
           errorfail;
       }
       for (;;) {
           suspend from1;
           bigadd(&from1, &by1, &from1);
       }
       fail;
   }
   else if (cnv:C_double(from,from2) && cnv:C_double(by,by2)) {
       if (by2 == 0) {
           irunerr(211, (int)by2);
           errorfail;
       }
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
   type_case x of {
      list:     return C_integer ListBlk(x).id;
      set:      return C_integer SetBlk(x).id;
      table:    return C_integer TableBlk(x).id;
      record:   return C_integer RecordBlk(x).id;
      object:   return C_integer ObjectBlk(x).id;
      coexpr:   return C_integer CoexprBlk(x).id;
      default:  runerr(123,x);
    }
  }
end

"sort(x,i) - sort structure x by method i (for tables)"

function sort(t, i)
   type_case t of {
      list: {
         body {
            register word size;

            /*
             * Sort the list by copying it into a new list and then using
             *  qsort to sort the descriptors.  (That was easy!)
             */
            size = ListBlk(t).size;
            cplist(&t, &result, (word)1, size + 1);
            qsort((char *)ListBlk(result).listhead->lelem.lslots,
               (int)size, sizeof(struct descrip),(QSortFncCast) anycmp);

            Desc_EVValD(BlkLoc(result), E_Lcreate, D_List);
            return result;
            }
         }

      record: {
         body {
            register dptr d1;
            register word size;
            tended struct b_list *lp;
            struct b_record *bp;
            register int i;
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
               qsort((char *)lp->listhead->lelem.lslots,(int)size,
                     sizeof(struct descrip),(QSortFncCast)anycmp);
               }

            Desc_EVValD(lp, E_Lcreate, D_List);
            return list(lp);
            }
         }

      set: {
         body {
            register dptr d1;
            register word size;
            register int j, k;
            tended struct b_list *lp;
            struct b_set *bp;
            union block *ep;
            register struct b_slots *seg;
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
                     for (ep= seg->hslots[k]; ep != NULL; ep= ep->telem.clink)
                        *d1++ = ep->selem.setmem;
               qsort((char *)lp->listhead->lelem.lslots,(int)size,
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
            register dptr d1;
            register word size;
            register int j, k, n;
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
                        d1->dword = D_List;
                        BlkLoc(*d1) = (union block *)tp;
                        }
               /*
                * Sort the resulting two-element list using the sorting
                *  function determined by i.
                */
               if (i == 1)
                  qsort((char *)lp->listhead->lelem.lslots, (int)size,
                        sizeof(struct descrip), (QSortFncCast)trefcmp);
               else
                  qsort((char *)lp->listhead->lelem.lslots, (int)size,
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
               qsort((char *)lp->listhead->lelem.lslots, (int)size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)trcmp3);
            else
               qsort((char *)lp->listhead->lelem.lslots, (int)size / 2,
                     (2 * sizeof(struct descrip)),(QSortFncCast)tvcmp4);
            break; /* from case 3 or 4 */
               }

            default: {
               irunerr(205, i);
               errorfail;
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

#ifdef DeBug
   if (d1->dword != D_List || d2->dword != D_List)
      syserr("trefcmp: internal consistency check fails.");
#endif					/* DeBug */

   return (anycmp(&(ListBlk(*d1).listhead->lelem.lslots[0]),
                  &(ListBlk(*d2).listhead->lelem.lslots[0])));
   }

/*
 * tvalcmp(d1,d2) - compare two-element lists on second field.
 */

static int tvalcmp(dptr d1, dptr d2)
   {

#ifdef DeBug
   if (d1->dword != D_List || d2->dword != D_List)
      syserr("tvalcmp: internal consistency check fails.");
#endif					/* DeBug */

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
   if (i == 0) {
       irunerr(205, i);
       errorfail;
   }

   type_case t of {
      list: {
         word size;

         /*
          * Sort the list by copying it into a new list and then using
          *  qsort to sort the descriptors.  (That was easy!)
          */
         size = ListBlk(t).size;
         cplist(&t, &result, (word)1, size + 1);
         sort_field = i;
         qsort((char *)ListBlk(result).listhead->lelem.lslots,
               (int)size, sizeof(struct descrip),(QSortFncCast) nthcmp);

         Desc_EVValD(BlkLoc(result), E_Lcreate, D_List);
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
             qsort((char *)lp->listhead->lelem.lslots,(int)size,
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
                     for (ep = seg->hslots[k]; ep != NULL; ep= ep->telem.clink)
                         *d1++ = ep->selem.setmem;
             sort_field = i;
             qsort((char *)lp->listhead->lelem.lslots,(int)size,
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
        i = cvpos((long)sort_field, (long)(bp->record.constructor->n_fields));
        if (i != CvtFail && i <= bp->record.constructor->n_fields)
            rv = &bp->record.fields[i-1];
    }
    else if (d->dword == D_List) {
        struct b_list *lp;
        /*
         * Find the nth element of a list.
         */
        lp = &ListBlk(*d);
        i = cvpos ((long)sort_field, (long)lp->size);
        if (i != CvtFail && i <= lp->size) {
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
      string:      LitStr("string", &result);    
      null:        LitStr("null", &result);      
      integer:     LitStr("integer", &result);   
      real:        LitStr("real", &result);      
      cset:        LitStr("cset", &result);      
      proc:        LitStr("procedure", &result); 
      list:        LitStr("list", &result);      
      table:       LitStr("table", &result);     
      set:         LitStr("set", &result);       
      class:       LitStr("class", &result);       
      constructor: LitStr("constructor", &result);       
      record:      LitStr("record", &result);    
      object:      LitStr("object", &result);    
      methp:       LitStr("methp", &result);    
      cast:        LitStr("cast", &result);    
      ucs:         LitStr("ucs", &result);    
      coexpr:      LitStr("co-expression", &result); 
      default:     runerr(123,x);
   }
   return result;
  }
end


"cast(o,c) - cast object o to class c."

function cast(o,c)
   if !is:object(o) then
       runerr(602, o)
   if !is:class(c) then
       runerr(603, c)
   body {
      struct b_cast *p;
      /* 
       * Check the cast makes sense, ie it is to a class the object
       * implements 
       */
      if (!class_is(ObjectBlk(o).class, &ClassBlk(c)))
          runerr(604, c);
      MemProtect(p = alccast());
      p->object = &ObjectBlk(o);
      p->class = &ClassBlk(c);
      return cast(p);
      }
end

/*
 * Lookup a pointer into the utf8 string for the given ucs block at
 * unicode char position n (zero-based).  n may be b->length in which
 * case a pointer just past the end of the utf8 string is returned;
 * otherwise n must be >= 0 and < b->length.  For each ucs block, there
 * are (b->length-1)/b->index_step offset slots.  off[x] gives the
 * offset of unicode char ((x+1) * b->index_step).  For example if 
 * b->index_step = 8, then for a length of 20 there are two offset entries
 * for unicode chars 8 and 16 (zero based).
 */
static char *get_ucs_off(struct b_ucs *b, word n)
{
    word d, i;
    char *p = StrLoc(b->utf8);

    /*
     * Special case of looking up just past the end of the last char.
     */
    if (n == b->length)
        return p + StrLen(b->utf8);

    /*
     * In the first step range, there is no offset to use.
     */
    if (n < b->index_step) {
        while (n-- > 0)
            p += UTF8_SEQ_LEN(*p);
        return p;
    }

    /*
     * Get the index into off before n
     */
    d = n / b->index_step - 1;

    /*
     * Now b->index_step <= n < b->length.  Hence d >= 0.
     * Also, n <= b->length-1 and so
     * d = n/b->index_step - 1 <= (b->length-1)/b->step - 1 < (b->length-1)/b->step,
     * the number of offset slots allocated.
     */

    /*
     * Have we indexed this one already?  If so start at the offset and
     * move forwards.
     */
    if (d < b->n_off_indexed) {
        word r = n % b->index_step;
        p += b->off[d];
        while (r-- > 0)
            p += UTF8_SEQ_LEN(*p);
        return p;
    }

    /*
     * Otherwise start at the last offset calculated (if any) and move
     * forward, saving all the intermediate offset points.
     */
    if (b->n_off_indexed > 0) {
        p += b->off[b->n_off_indexed - 1];
        i = b->n_off_indexed * b->index_step;
    } else
        i = 0;
    /* I: i/b->index_step = b->n_off_indexed */
    while (i < n) {
        p += UTF8_SEQ_LEN(*p);
        ++i;
        /* After incrementing i, ((i-1)/b->index_step) = b->n_off_indexed
         * But i <= n < b->length, so 
         *       ((i-1)/b->index_step) < ((b->length-1)/b->index_step)
         *  so   b->n_off_indexed < ((b->length-1)/b->index_step), the allocated size.
         */
        if (i % b->index_step == 0)
            b->off[b->n_off_indexed++] = p - StrLoc(b->utf8);
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
    word index_step, n_offs;

    if (length == 0)
        return emptystr_ucs;
    index_step = calc_ucs_index_step(length);
    n_offs = (length - 1) / index_step;
    MemProtect(p = alcucs(n_offs));
    p->index_step = index_step;
    p->utf8 = *utf8;
    p->length = length;
    p->n_off_indexed = 0;
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
    MemProtect(StrLoc(s) = alcstr(utf8, n));
    StrLen(s) = n;
    return make_ucs_block(&s, 1);
}

/*
 * Helper function to make a new ucs block which is a substring of the
 * given ucs block.
 */
struct b_ucs *make_ucs_substring(struct b_ucs *b, word pos, word len)
{
    tended struct descrip utf8;
    if (len == 0)
        return emptystr_ucs;
    utf8_substr(b, pos, len, &utf8);
    return make_ucs_block(&utf8, len);
}

/*
 * Given a ucs block, this function returns the utf8 substring correspoding to
 * the slice pos:len.  No allocation is done.  pos,len must be a valid range
 * for the string.
 */
void utf8_substr(struct b_ucs *b, word pos, word len, dptr res)
{
    char *p, *q;
    word first, last;

    if (len == 0) {
        *res = emptystr;
        return;
    }

    first = pos - 1;
    last = first + len - 1;

    if (len < 0 || first < 0 || last < 0 || first >= b->length || last >= b->length)
        syserr("Invalid pos/len to uf8_substr");

    p = get_ucs_off(b, first);
    StrLoc(*res) = p;
    if (last / b->index_step > first / b->index_step) {
        q = get_ucs_off(b, last + 1);
    } else {
        q = p;
        while (len-- > 0)
            q += UTF8_SEQ_LEN(*q);
    }
    StrLen(*res) = q - p;
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

    MemProtect(StrLoc(utf8) = reserve(Strings, utf8_len));
    StrLen(utf8) = utf8_len;

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

void cset_to_str(struct b_cset *b, word pos, word len, dptr res)
{
    int i;
    word j, from, to, out_len;
    static char c[256];

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
                syserr("attempt to convert cset_to_str with chars > 255");
        }
        pos = 0;
    }
    /* Ensure we found len chars. */
    if (len)
        syserr("cset_to_str inconsistent parameters");
    MemProtect(StrLoc(*res) = alcstr(c, out_len));
    StrLen(*res) = out_len;
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


function lang_Text_create_cset(x[n])
   body {
     struct rangeset *rs;
     tended struct b_cset *b;
     word from, to;
     int i;

     MemProtect(rs = init_rangeset());
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
                         whyf("Invalid codepoint:%ld", (long)to);
                         free_rangeset(rs);
                         fail;
                     }
                     if (from == -1)
                         from = to;
                     else {
                         MemProtect(add_range(rs, from, to));
                         from = -1;
                     }
                 }
             }
             if (from != -1)
                 MemProtect(add_range(rs, from, from));
             ++i;
         } else {
             if (!cnv:C_integer(x[i], from)) {
                 free_rangeset(rs);
                 runerr(101, x[i]);
             }
             if (from < 0 || from > MAX_CODE_POINT) {
                 whyf("Invalid codepoint:%ld", (long)from);
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
                     whyf("Invalid codepoint:%ld", (long)to);
                     free_rangeset(rs);
                     fail;
                 }
                 MemProtect(add_range(rs, from, to));
                 ++i;
             } else
                 MemProtect(add_range(rs, from, from));
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
      runerr(120, c)
   if !cnv:C_integer(i) then
      runerr(101, i)
   if !cnv:C_integer(j) then
      runerr(101, j)
   body {
       struct rangeset *rs;
       tended struct b_cset *blk;
       word len;

       i = cvpos(i, CsetBlk(c).size);
       if (i == CvtFail)
           fail;
       j = cvpos(j, CsetBlk(c).size);
       if (j == CvtFail)
           fail;
       if (i > j) {
           word t = i;
           i = j;
           len = t - j;
       }
       else
           len = j - i;

       MemProtect(rs = init_rangeset());
       if (len > 0) {
           int a, pos, from, to, l0;
           a = cset_range_of_pos(&CsetBlk(c), i);    /* First range of interest */
           pos = i - 1 - CsetBlk(c).range[a].index;  /* Offset into that range */
           for (; len > 0 && a < CsetBlk(c).n_ranges; ++a) {
               from = CsetBlk(c).range[a].from;
               to = CsetBlk(c).range[a].to;
               l0 = to - from - pos + 1;
               if (l0 <= len) {
                   MemProtect(add_range(rs, from + pos, to));
                   len -= l0;
               } else {
                   MemProtect(add_range(rs, from + pos, len + from + pos - 1));
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
   if !def:C_integer(i, 1) then
      runerr(101, i)
   if !def:C_integer(j, 0) then
      runerr(101, j)
   body {
       word len;

       type_case x of {
         cset: {
            int a, b, pos, from, to;

            i = cvpos(i, CsetBlk(x).size);
            if (i == CvtFail)
                fail;
            j = cvpos(j, CsetBlk(x).size);
            if (j == CvtFail)
                fail;
            if (i > j) {
                word t = i;
                i = j;
                len = t - j;
            } else
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
            tended char *p;

            i = cvpos(i, UcsBlk(x).length);
            if (i == CvtFail)
                fail;
            j = cvpos(j, UcsBlk(x).length);
            if (j == CvtFail)
                fail;
            if (i > j) {
                C_integer t = i;
                i = j;
                len = t - j;
            } else
                len = j - i;

            if (len == 0)
                fail;

            p = ucs_utf8_ptr(&UcsBlk(x), i);
            while (len-- > 0)
                suspend C_integer utf8_iter(&p);

            fail;
         }

         default : {
            tended char *p;

            if (!cnv:string(x,x))
                runerr(132, x);

            i = cvpos(i, StrLen(x));
            if (i == CvtFail)
                fail;
            j = cvpos(j, StrLen(x));
            if (j == CvtFail)
                fail;
            if (i > j) {
                C_integer t = i;
                i = j;
                len = t - j;
            } else
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

