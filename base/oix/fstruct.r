/*
 * File: fstruct.r
 *  Contents: delete, get, key, insert, list, member, pop, pull, push, put,
 *  set, table
 */

"delete(s, x1,..., xN) - delete elements x1..N from set, table, or list s if it is there"
" (always succeeds and returns s)."

function{1} delete(s, x[n])
   abstract {
      return type(s) ** (set ++ table ++ list)
      }

   /*
    * The technique and philosophy here are the same
    *  as used in insert - see comment there.
    */
   type_case s of {
      set:
         body {
            register uword hn;
            register union block **pd;
            int res, argc;

	    for (argc = 0; argc < n; argc++) {
	       hn = hash(x+argc);
	       pd = memb(BlkLoc(s), x + argc, hn, &res);
	       if (res == 1) {
		  /*
		   * The element is there so delete it.
		   */
		  *pd = (*pd)->selem.clink;
		  (BlkLoc(s)->set.size)--;
		  }
	       EVValD(&s, E_Sdelete);
	       EVValD(x+argc, E_Sval);
	       }
            return s;
	    }
      table:
         body {
            register union block **pd;
            register uword hn;
            int res, argc;

	    for (argc = 0; argc < n; argc++) {
	       hn = hash(x+argc);
	       pd = memb(BlkLoc(s), x+argc, hn, &res);
	       if (res == 1) {
		  /*
		   * The element is there so delete it.
		   */
		  *pd = (*pd)->telem.clink;
		  (BlkLoc(s)->table.size)--;
		  }
	       EVValD(&s, E_Tdelete);
	       EVValD(x+argc, E_Tsub);
	       }
            return s;
            }
      list:
         body {
	    tended struct b_list *hp; /* work in progress */
	    tended struct descrip d;
            C_integer cnv_x;
	    int i, size, argc;

	    for (argc = 0; argc < n; argc++) {

	       if (!cnv:C_integer(x[argc], cnv_x)) runerr(101, x[argc]);

	       hp = (struct b_list *)BlkLoc(s);
	       size = hp->size;
	       for (i = 1; i <= size; i++) {
		  c_get(hp, &d);
		  if (i != cnv_x)
		     c_put(&s, &d);
		  }
	       EVValD(&s, E_Ldelete);
	       EVVal(cnv_x, E_Lsub);
	       }
	    return s;
	    }
      default:
         runerr(122, s)
      }
end


/*
 * c_get - convenient C-level access to the get function
 *  returns 0 on failure, otherwise fills in res
 */
int c_get(hp, res)
struct b_list *hp;
struct descrip *res;
{
   register word i;
   register struct b_lelem *bp;

   /*
    * Fail if the list is empty.
    */
   if (hp->size <= 0)
      return 0;

   /*
    * Point bp at the first list block.  If the first block has no
    *  elements in use, point bp at the next list block.
    */
   bp = (struct b_lelem *) hp->listhead;
   if (bp->nused <= 0) {
      bp = (struct b_lelem *) bp->listnext;
      hp->listhead = (union block *) bp;
      bp->listprev = (union block *) hp;
      }

   /*
    * Locate first element and assign it to result for return.
    */
   i = bp->first;
   *res = bp->lslots[i];

   /*
    * Set bp->first to new first element, or 0 if the block is now
    *  empty.  Decrement the usage count for the block and the size
    *  of the list.
    */
   if (++i >= bp->nslots)
      i = 0;
   bp->first = i;
   bp->nused--;
   hp->size--;

   return 1;
}

#begdef GetOrPop(get_or_pop)
#get_or_pop "(x) - " #get_or_pop " an element from the left end of list x."
/*
 * get(L) - get an element from end of list L.
 *  Identical to pop(L).
 */
function{0,1} get_or_pop(x,i)
   if !def:C_integer(i, 1L) then
      runerr(101, i)

   type_case x of {
      list: {
	 abstract {
	    return store[type(x).lst_elem]
	    }

	 body {
	    int j;
	    EVValD(&x, E_Lget);
	    for(j=0;j<i;j++)
	       if (!c_get((struct b_list *)BlkLoc(x), &result)) fail;
	    return result;
	    }
	 }
      default:
	 runerr(108, x)
      }
end
#enddef

GetOrPop(get) /* get(x) - get an element from the left end of list x. */
GetOrPop(pop) /* pop(x) - pop an element from the left end of list x. */


"key(T) - generate successive keys (entry values) from table T."

function{*} key(t)
   type_case t of {
      table: {
	 abstract {
	    return store[type(t).tbl_key]
	 }
	 inline {
	    tended union block *ep;
	    struct hgstate state;

	    EVValD(&t, E_Tkey);
	    for (ep = hgfirst(BlkLoc(t), &state); ep != 0;
		 ep = hgnext(BlkLoc(t), &state, ep)) {
	       EVValD(&ep->telem.tref, E_Tsub);
	       suspend ep->telem.tref;
            }
	    fail;
	    }
      }
      list: {
	 abstract { return integer }
	 inline {
	    C_integer i, sz = ((struct b_list *)BlkLoc(t))->size;
	    for(i=1; i<=sz; i++) suspend C_integer i;
	    fail;
	    }
	 }
      record: {
	 abstract { return string }
	 inline {
	    C_integer i, sz = BlkLoc(t)->record.constructor->n_fields;
	    for(i=0; i<sz; i++)
	       suspend BlkLoc(t)->record.constructor->field_names[i];
	    fail;
	    }
	 }
      default: {
         runerr(124, t)
      }
   }
end


"insert(s, x1, ..., xN) - insert elements x1..N into set or table s if not already there."
" If s is a table, the assigned value for element xi is x(i+1)."
" (always succeeds and returns s)."

function{1} insert(s, x[n])
   type_case s of {

      set: {
         abstract {
            store[type(s).set_elem] = type(x).lst_elem
            return type(s)
            }

         body {
            tended union block *bp, *bp2;
            register uword hn;
            int res, argc;
            struct b_selem *se;
            register union block **pd;

	    for(argc=0;argc<n;argc++) {
	       bp = BlkLoc(s);
	       hn = hash(x+argc);
	       /*
		* If x is a member of set s then res will have the value 1,
		*  and pd will have a pointer to the pointer
		*  that points to that member.
		*  If x is not a member of the set then res will have
		*  the value 0 and pd will point to the pointer
		*  which should point to the member - thus we know where
		*  to link in the new element without having to do any
		*  repetitive looking.
		*/

	       /* get this now because can't tend pd */
	       Protect(se = alcselem(x+argc, hn), runerr(0));

	       pd = memb(bp, x+argc, hn, &res);
	       if (res == 0) {
		  /*
		   * The element is not in the set - insert it.
		   */
		  addmem((struct b_set *)bp, se, pd);
		  if (TooCrowded(bp))
		     hgrow(bp);
		  }
	       else
		  deallocate((union block *)se);

	       EVValD(&s, E_Sinsert);
	       EVValD(x+argc, E_Sval);
	       }
            return s;
            }
         }

         list: {
            abstract {
                store[type(s).lst_elem] = type(x).lst_elem
                    return type(s)
                    }
            body {
                tended struct b_list *hp; /* work in progress */
                tended struct descrip d;
                C_integer cnv_x;
                word i, j, size, argc;

                for(argc=0;argc<n;argc+=2) {
                    hp = (struct b_list *)BlkLoc(s);
                    /*
                     * Make sure that subscript x is in range.
                     */
                    if (!cnv:C_integer(x[argc], cnv_x)) {
                        if (cnv:integer(x[argc],x[argc])) fail;
                        runerr(101, x[argc]);
                    }
                    size = hp->size;
                    i = cvpos((long)cnv_x, size);
                    if (i == CvtFail || i > size + 1)
                        fail;
                    if (i == size + 1) {
                        /*
                         * Put the element to insert on the back
                         */
                        if (argc+1 < n)
                            c_put(&s, x+argc+1);
                        else
                            c_put(&s, &nulldesc);
                    } else { /* i <= size */
                        /*
                         * Perform i-1 rotations so that the position to be inserted
                         * is at the front/back
                         */
                        for (j = 1; j < i; j++) {
                            c_get(hp, &d);
                            c_put(&s, &d);
                        }

                        /*
                         * Put the element to insert on the back
                         */
                        if (argc+1 < n)
                            c_put(&s, x+argc+1);
                        else
                            c_put(&s, &nulldesc);

                        /*
                         * Perform size - (i-1) more rotations to slide everything back
                         * where it was originally
                         */
                        for (j = i; j <= size; j++) {
                            c_get(hp, &d);
                            c_put(&s, &d);
                        }
                    }
                }
                return s;
            }
        }
      table: {
         abstract {
            store[type(s).tbl_key] = type(x).lst_elem
            store[type(s).tbl_val] = type(x).lst_elem
            return type(s)
            }

         body {
            tended union block *bp, *bp2;
            union block **pd;
            struct b_telem *te;
            register uword hn;
            int res, argc;

            bp = BlkLoc(s);

	    for(argc=0; argc<n; argc+=2) {

	       hn = hash(x+argc);

	       /* get this now because can't tend pd */
	       Protect(te = alctelem(), runerr(0));

	       pd = memb(bp, x+argc, hn, &res);	/* search table for key */
	       if (res == 0) {
		  /*
		   * The element is not in the table - insert it.
		   */
		  bp->table.size++;
		  te->clink = *pd;
		  *pd = (union block *)te;
		  te->hashnum = hn;
		  te->tref = x[argc];
		  if (argc+1 < n)
		     te->tval = x[argc+1];
		  else
		     te->tval = nulldesc;
		  if (TooCrowded(bp))
		     hgrow(bp);
		  }
	       else {
		  /*
		   * We found an existing entry; just change its value.
		   */
		  deallocate((union block *)te);
		  te = (struct b_telem *) *pd;
		  if (argc+1 < n)
		     te->tval = x[argc+1];
		  else
		     te->tval = nulldesc;
		  }

	       EVValD(&s, E_Tinsert);
	       EVValD(x+argc, E_Tsub);
	       }
            return s;
            }
         }
      default:
         runerr(122, s);
      }
end


"list(i, x) - create a list of size i, with initial value x."

function{1} list(n, x)
   if !def:C_integer(n, 0L) then
      runerr(101, n)

   abstract {
      return new list(type(x))
      }

   body {
      tended struct b_list *hp;
      register word i, size;
      word nslots;
      register struct b_lelem *bp; /* does not need to be tended */

      nslots = size = n;

      /*
       * Ensure that the size is positive and that the list-element block 
       *  has at least MinListSlots slots.
       */
      if (size < 0) {
         irunerr(205, n);
         errorfail;
         }
      if (nslots == 0)
         nslots = MinListSlots;

      /*
       * Allocate the list-header block and a list-element block.
       *  Note that nslots is the number of slots in the list-element
       *  block while size is the number of elements in the list.
       */
      Protect(hp = alclist_raw(size, nslots), runerr(0));
      bp = (struct b_lelem *)hp->listhead;

      /*
       * Initialize each slot.
       */
      for (i = 0; i < size; i++)
         bp->lslots[i] = x;

      Desc_EVValD(hp, E_Lcreate, D_List);

      /*
       * Return the new list.
       */
      return list(hp);
      }
end

"member(x1, x2) - returns x1 if x2 is a member of set or table x2 but fails"
" otherwise."

function{0,1} member(s, x)
   type_case s of {

      set: {
         abstract {
            return type(x) ** store[type(s).set_elem]
            }
         inline {
            int res;
            register uword hn;

            EVValD(&s, E_Smember);
            EVValD(&x, E_Sval);

            hn = hash(&x);
            memb(BlkLoc(s), &x, hn, &res);
            if (res==1)
               return x;
            else
               fail;
            }
         }
      table: {
         abstract {
            return type(x) ** store[type(s).tbl_key]
            }
         inline {
            int res;
            register uword hn;

            EVValD(&s, E_Tmember);
            EVValD(&x, E_Tsub);

            hn = hash(&x);
            memb(BlkLoc(s), &x, hn, &res);
            if (res == 1)
               return x;
            else
               fail;
            }
         }
      list: {
	 abstract {
	    return store[type(x).lst_elem]
	    }
	 inline {
            int size, i;
	    C_integer cnv_x;
	    size = ((struct b_list *)BlkLoc(s))->size;
            if (!(cnv:C_integer(x, cnv_x))) 
                fail;
            i = cvpos(cnv_x, size);
            if (i == CvtFail || i > size)
                fail;
            else
                return x;
	    }
	 }

      default:
         runerr(122, s)
      }
end



"pull(L,n) - pull an element from end of list L."

function{0,1} pull(x,n)
   if !def:C_integer(n, 1L) then
      runerr(101, n)
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)
   abstract {
      return store[type(x).lst_elem]
      }

   body {
      register word i, j;
      register struct b_list *hp;
      register struct b_lelem *bp;

      for(j=0;j<n;j++) {
	 EVValD(&x, E_Lpull);

	 /*
	  * Point at list header block and fail if the list is empty.
	  */
	 hp = (struct b_list *) BlkLoc(x);
	 if (hp->size <= 0)
	    fail;

	 /*
	  * Point bp at the last list element block.  If the last block has no
	  *  elements in use, point bp at the previous list element block.
	  */
	 bp = (struct b_lelem *) hp->listtail;
	 if (bp->nused <= 0) {
	    bp = (struct b_lelem *) bp->listprev;
	    hp->listtail = (union block *) bp;
	    bp->listnext = (union block *) hp;
	    }

	 /*
	  * Set i to position of last element and assign the element to
	  *  result for return.  Decrement the usage count for the block
	  *  and the size of the list.
	  */
	 i = bp->first + bp->nused - 1;
	 if (i >= bp->nslots)
	    i -= bp->nslots;
	 result = bp->lslots[i];
	 bp->nused--;
	 hp->size--;
	 }
      return result;
      }
end


/*
 * c_push - C-level, nontending push operation
 */
void c_push(l, val)
dptr l;
dptr val;
{
   register word i = 0;
   register struct b_lelem *bp; /* does not need to be tended */
   static int two = 2;		/* some compilers generate bad code for
				   division by a constant that's a power of 2*/
   /*
    * Point bp at the first list-element block.
    */
   bp = (struct b_lelem *) BlkLoc(*l)->list.listhead;

   /*
    * If the first list-element block is full, allocate a new
    *  list-element block, make it the first list-element block,
    *  and make it the previous block of the former first list-element
    *  block.
    */
   if (bp->nused >= bp->nslots) {
      /*
       * Set i to the size of block to allocate.
       */
      i = BlkLoc(*l)->list.size / two;
      if (i < MinListSlots)
         i = MinListSlots;
#ifdef MaxListSlots
      if (i > MaxListSlots)
         i = MaxListSlots;
#endif					/* MaxListSlots */

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i, (word)0, (word)0)) == NULL) {
         i /= 4;
         if (i < MinListSlots)
            fatalerr(0, NULL);
         }

      BlkLoc(*l)->list.listhead->lelem.listprev = (union block *) bp;
      bp->listprev = BlkLoc(*l);
      bp->listnext = BlkLoc(*l)->list.listhead;
      BlkLoc(*l)->list.listhead = (union block *) bp;
      }

   /*
    * Set i to position of new first element and assign val to
    *  that element.
    */
   i = bp->first - 1;
   if (i < 0)
      i = bp->nslots - 1;
   bp->lslots[i] = *val;
   /*
    * Adjust value of location of first element, block usage count,
    *  and current list size.
    */
   bp->first = i;
   bp->nused++;
   BlkLoc(*l)->list.size++;
   }



"push(L, x1, ..., xN) - push x onto beginning of list L."

function{1} push(x, vals[n])
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)
   abstract {
      store[type(x).lst_elem] = type(vals)
      return type(x)
      }

   body {
      tended struct b_list *hp;
      dptr dp;
      register word i, val, num;
      register struct b_lelem *bp; /* does not need to be tended */
      static int two = 2;	/* some compilers generate bad code for
				   division by a constant that's a power of 2*/

      if (n == 0) {
	 dp = &nulldesc;
	 num = 1;
	 }
      else {
	 dp = vals;
	 num = n;
	 }

      for (val = 0; val < num; val++) {
	 /*
	  * Point hp at the list-header block and bp at the first
	  *  list-element block.
	  */
	 hp = (struct b_list *) BlkLoc(x);
	 bp = (struct b_lelem *) hp->listhead;

	 /*
	  * Initialize i so it's 0 if first list-element.
	  */
	 i = 0;			/* block isn't full */

	 /*
	  * If the first list-element block is full, allocate a new
	  *  list-element block, make it the first list-element block,
	  *  and make it the previous block of the former first list-element
	  *  block.
	  */
	 if (bp->nused >= bp->nslots) {
	    /*
	     * Set i to the size of block to allocate.
	     */
	    i = hp->size / two;
	    if (i < MinListSlots)
	       i = MinListSlots;
#ifdef MaxListSlots
	    if (i > MaxListSlots)
	       i = MaxListSlots;
#endif					/* MaxListSlots */

	    /*
	     * Allocate a new list element block.  If the block can't
	     *  be allocated, try smaller blocks.
	     */
	    while ((bp = alclstb(i, (word)0, (word)0)) == NULL) {
	       i /= 4;
	       if (i < MinListSlots)
		  runerr(0);
	       }

	    hp->listhead->lelem.listprev = (union block *) bp;
	    bp->listprev = (union block *) hp;
	    bp->listnext = hp->listhead;
	    hp->listhead = (union block *) bp;
	    }

	 /*
	  * Set i to position of new first element and assign val to
	  *  that element.
	  */
	 i = bp->first - 1;
	 if (i < 0)
	    i = bp->nslots - 1;
	 bp->lslots[i] = dp[val];
	 /*
	  * Adjust value of location of first element, block usage count,
	  *  and current list size.
	  */
	 bp->first = i;
	 bp->nused++;
	 hp->size++;
	 }

      EVValD(&x, E_Lpush);

      /*
       * Return the list.
       */
      return x;
      }
end


/*
 * c_put - C-level, nontending list put function
 */
void c_put(struct descrip *l, struct descrip *val)
{
   register word i = 0;
   register struct b_lelem *bp;  /* does not need to be tended */
   static int two = 2;		/* some compilers generate bad code for
				   division by a constant that's a power of 2*/

   /*
    * Point hp at the list-header block and bp at the last
    *  list-element block.
    */
   bp = (struct b_lelem *) BlkLoc(*l)->list.listtail;
   
   /*
    * If the last list-element block is full, allocate a new
    *  list-element block, make it the last list-element block,
    *  and make it the next block of the former last list-element
    *  block.
    */
   if (bp->nused >= bp->nslots) {
      /*
       * Set i to the size of block to allocate.
       */
      i = ((struct b_list *)BlkLoc(*l))->size / two;
      if (i < MinListSlots)
         i = MinListSlots;
#ifdef MaxListSlots
      if (i > MaxListSlots)
         i = MaxListSlots;
#endif					/* MaxListSlots */

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i, (word)0, (word)0)) == NULL) {
         i /= 4;
         if (i < MinListSlots)
            fatalerr(0, NULL);
         }

      ((struct b_list *)BlkLoc(*l))->listtail->lelem.listnext =
	(union block *) bp;
      bp->listprev = ((struct b_list *)BlkLoc(*l))->listtail;
      bp->listnext = BlkLoc(*l);
      ((struct b_list *)BlkLoc(*l))->listtail = (union block *) bp;
      }

   /*
    * Set i to position of new last element and assign val to
    *  that element.
    */
   i = bp->first + bp->nused;
   if (i >= bp->nslots)
      i -= bp->nslots;
   bp->lslots[i] = *val;

   /*
    * Adjust block usage count and current list size.
    */
   bp->nused++;
   ((struct b_list *)BlkLoc(*l))->size++;
}


"put(L, x1, ..., xN) - put elements onto end of list L."

function{1} put(x, vals[n])
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)
   abstract {
      store[type(x).lst_elem] = type(vals)
      return type(x)
      }

   body {
      tended struct b_list *hp;
      dptr dp;
      register word i, val, num;
      register struct b_lelem *bp;  /* does not need to be tended */
      static int two = 2;	/* some compilers generate bad code for
				   division by a constant that's a power of 2*/
      if (n == 0) {
	 dp = &nulldesc;
	 num = 1;
	 }
      else {
	 dp = vals;
	 num = n;
	 }

      /*
       * Point hp at the list-header block and bp at the last
       *  list-element block.
       */
      for(val = 0; val < num; val++) {

	 hp = (struct b_list *)BlkLoc(x);
	 bp = (struct b_lelem *) hp->listtail;
   
	 i = 0;			/* block isn't full */

	 /*
	  * If the last list-element block is full, allocate a new
	  *  list-element block, make it the last list-element block,
	  *  and make it the next block of the former last list-element
	  *  block.
	  */
	 if (bp->nused >= bp->nslots) {
	    /*
	     * Set i to the size of block to allocate.
	     *  Add half the size of the present list, subject to
	     *  minimum and maximum and including enough space for
	     *  the rest of this call to put() if called with varargs.
	     */
	    i = hp->size / two;
	    if (i < MinListSlots)
	       i = MinListSlots;
	    if (i < n - val)
	       i = n - val;
#ifdef MaxListSlots
	    if (i > MaxListSlots)
	       i = MaxListSlots;
#endif					/* MaxListSlots */
	    /*
	     * Allocate a new list element block.  If the block can't
	     *  be allocated, try smaller blocks.
	     */
	    while ((bp = alclstb(i, (word)0, (word)0)) == NULL) {
	       i /= 4;
	       if (i < MinListSlots)
		  runerr(0);
	       }

	    hp->listtail->lelem.listnext = (union block *) bp;
	    bp->listprev = hp->listtail;
	    bp->listnext = (union block *) hp;
	    hp->listtail = (union block *) bp;
	    }

	 /*
	  * Set i to position of new last element and assign val to
	  *  that element.
	  */
	 i = bp->first + bp->nused;
	 if (i >= bp->nslots)
	    i -= bp->nslots;
	 bp->lslots[i] = dp[val];

	 /*
	  * Adjust block usage count and current list size.
	  */
	 bp->nused++;
	 hp->size++;

	 }

      EVValD(&x, E_Lput);

      /*
       * Return the list.
       */
      return x;
      }
end

/*
 * C language set insert.  pps must point to a tended block pointer.
 * pe can't be tended, so allocate before, and deallocate if unused.
 * returns: 0 = yes it was inserted, -1 = runtime error, 1 = already there.
 */
#begdef C_SETINSERT(ps, pd, res)
{
   register uword hn;
   union block **pe;
   struct b_selem *ne;			/* does not need to be tended */
   tended struct descrip d;

   d = *pd;
   if ((ne = alcselem(&nulldesc, (uword)0))) {
      pe = memb(ps, &d, hn = hash(&d), &res);
      if (res==0) {
         ne->setmem = d;			/* add new element */
         ne->hashnum = hn;
         addmem((struct b_set *)ps, ne, pe);
         }
      else deallocate((union block *)ne);
      }
   else res = -1;
   res = 0;
}
#enddef

int c_setinsert(union block **pps, dptr pd)
{
   int rv;
   C_SETINSERT(*pps, pd, rv);
   return rv;
}

"set(x1,...,xN) - create a set with given members."
" If any parameter is a list, its"
" elements are added rather than the list itself."

function{1} set(x[n])

   len_case n of {
      0: {
         abstract {
            return new set(empty_type)
            }
         inline {
            register union block * ps;
            ps = hmake(T_Set, (word)0, (word)0);
            if (ps == NULL)
               runerr(0);
	    Desc_EVValD(ps, E_Screate, D_Set);
            return set(ps);
            }
         }

      default: {
         abstract {
            return new set(type(x)) /* ?? */
/*            return new set(store[type(x).lst_elem]) /* should be anything */
            }

         body {
            tended union block *pb, *ps;
            word i, j;
	    int arg, res;

	    /*
	     * Make a set.
             */
            if (is:list(x[0])) i = BlkLoc(x[0])->list.size;
            else i = n;
            ps = hmake(T_Set, (word)0, i);
            if (ps == NULL) {
               runerr(0);
               }

	    for (arg = 0; arg < n; arg++) {
	      if (is:list(x[arg])) {
		pb = BlkLoc(x[arg]);
                if(!(reserve(Blocks,
                     pb->list.size*(2*sizeof(struct b_selem))))){
                   runerr(0);
                   }
		/*
		 * Chain through each list block and for
		 *  each element contained in the block
		 *  insert the element into the set if not there.
		 */
		for (pb = pb->list.listhead;
		     pb && (BlkType(pb) == T_Lelem);
		     pb = pb->lelem.listnext) {
		  for (i = 0; i < pb->lelem.nused; i++) {
#ifdef Graphics
            if (!pollctr--) {
               pollctr = pollevent();
	       }	       
#endif					/* Graphics */
		    j = pb->lelem.first + i;
		    if (j >= pb->lelem.nslots)
		      j -= pb->lelem.nslots;
		    C_SETINSERT(ps, &pb->lelem.lslots[j], res);
                    if (res == -1) {
                       runerr(0);
                       }
                    }
		}
	      }
	      else {
		if (c_setinsert(&ps, & (x[arg])) == -1) {
                   runerr(0);
                   }
	      }
	    }
	    Desc_EVValD(ps, E_Screate, D_Set);
            return set(ps);
	    }
         }
      }
end


"table(x) - create a table with default value x."

function{1} table(x)
   abstract {
      return new table(empty_type, empty_type, type(x))
      }
   inline {
      union block *bp;
   
      bp = hmake(T_Table, (word)0, (word)0);
      if (bp == NULL)
         runerr(0);
      bp->table.defvalue = x;
      Desc_EVValD(bp, E_Tcreate, D_Table);
      return table(bp);
      }
end


"constructor(label, field, field...) - produce a new record constructor"

function{1} constructor(s, x[n])
   abstract {
      return constructor
	}
   if !cnv:string(s) then runerr(103,s)
   inline {
      int i;
      struct b_constructor *bp;
      for(i=0;i<n;i++)
         if (!is:string(x[i])) runerr(103, x[i]);
      bp = dynrecord(&s, x, n);
      if (bp == NULL) syserr("out of memory in constructor()");
      return constructor(bp);
      }
end

function{1} constructorof(r)
   if !is:record(r) then
       runerr(107, r)
    body {
       return constructor(BlkLoc(r)->record.constructor);
    }
end

"keyof(s, x) - given a table or list s and a value x, generate the keys k such that s[k] === x"

function{*} keyof(s,x)
   declare {
      tended union block *ep;
   }
   type_case s of {
      list: {
	 abstract {
	    return integer
	    }
	 body {
            C_integer index = 1, i, j;
            for (ep = BlkLoc(s)->list.listhead;
		 BlkType(ep) == T_Lelem;
                 ep = ep->lelem.listnext){
               for (i = 0; i < ep->lelem.nused; i++) {
                  j = ep->lelem.first + i;
                  if (j >= ep->lelem.nslots)
                     j -= ep->lelem.nslots;
                  if (equiv(&ep->lelem.lslots[j], &x))
                     suspend C_integer index;
                  index++;
               }
            }
            fail;
         }
      }
      table: {
	 abstract {
	    return store[type(s).tbl_key]
	 }
	 inline {
	    struct hgstate state;
	    for (ep = hgfirst(BlkLoc(s), &state); ep != 0;
		 ep = hgnext(BlkLoc(s), &state, ep)) {
               if (equiv(&ep->telem.tval, &x))
                  suspend ep->telem.tref;
            }
	    fail;
         }
      }
      default:
         runerr(127, s)
   }
end
