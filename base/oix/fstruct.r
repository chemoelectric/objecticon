/*
 * File: fstruct.r
 *  Contents: delete, get, key, insert, list, member, pop, pull, push, put,
 *  set, table
 */

"delete(x1,x2) - delete element x2 from set or table or list x1 if it is there"
" (always succeeds and returns x1)."

function{1} delete(s,x)
   body {

   /*
    * The technique and philosophy here are the same
    *  as used in insert - see comment there.
    */
   type_case s of {
     set: {
            register uword hn;
            register union block **pd;
            int res;

            hn = hash(&x);
            pd = memb(BlkLoc(s), &x, hn, &res);
            if (res == 1) {
		  /*
		   * The element is there so delete it.
		   */
		  *pd = (*pd)->selem.clink;
		  (BlkLoc(s)->set.size)--;
            }
            EVValD(&s, E_Sdelete);
            EVValD(&x, E_Sval);
            return s;
         }

     table: {

            register union block **pd;
            register uword hn;
            int res;

            hn = hash(&x);
            pd = memb(BlkLoc(s), &x, hn, &res);
            if (res == 1) {
		  /*
		   * The element is there so delete it.
		   */
		  *pd = (*pd)->telem.clink;
		  (BlkLoc(s)->table.size)--;
            }
            EVValD(&s, E_Tdelete);
            EVValD(&x, E_Tsub);
            return s;
         }
     list: {
            C_integer cnv_x;
	    word i, size;

            /*
             * Make sure that subscript x is in range.
             */
            if (!cnv:C_integer(x, cnv_x)) {
                if (cnv:integer(x, x)) 
                    fail;
                runerr(101, x);
            }
            size = BlkLoc(s)->list.size;
            i = cvpos((long)cnv_x, size);
            if (i == CvtFail || i > size)
                fail;

            c_list_delete(&s, i);
            EVValD(&s, E_Ldelete);
            EVVal(cnv_x, E_Lsub);
	    return s;
         }

      default:
          runerr(122, s);
     }
   }
end


/*
 * c_get - convenient C-level access to the get function
 *  returns 0 on failure, otherwise fills in res
 */
int c_get(dptr l, dptr res)
{
   word i;
   struct b_list *hp = (struct b_list *)BlkLoc(*l);
   struct b_lelem *bp;

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
 *  Identical to pop(L,i).
 */
function{0,1} get_or_pop(x)
   if !is:list(x) then
      runerr(108, x)
   body {
     EVValD(&x, E_Lget);
     if (!c_get(&x, &result)) 
         fail;
     return result;
   }
end
#enddef

GetOrPop(get) /* get(x) - get an element from the left end of list x. */
GetOrPop(pop) /* pop(x) - pop an element from the left end of list x. */


"key(T) - generate successive keys (entry values) from table T."

function{*} key(t)
   if !is:table(t) then
         runerr(124, t)
   body {
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
end


"insert(x1, x2, x3) - insert element x2 into set or table or list x1 if not already there"
" if x1 is a table or list, the assigned value for element x2 is x3."
" (always succeeds and returns x1)."

function{1} insert(s, x, y)
    body {
      type_case s of {

      set: {
            tended union block *bp, *bp2;
            register uword hn;
            int res;
            struct b_selem *se;
            register union block **pd;

            bp = BlkLoc(s);
            hn = hash(&x);
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
            MemProtect(se = alcselem());

            pd = memb(bp, &x, hn, &res);
            if (res == 0) {
                /*
                 * The element is not in the set - insert it.
                 */
                se->setmem = x;
                se->hashnum = hn;
                addmem((struct b_set *)bp, se, pd);
                if (TooCrowded(bp))
                    hgrow(bp);
            }
            else
                dealcblk((union block *)se);

            EVValD(&s, E_Sinsert);
            EVValD(&x, E_Sval);
            return s;
         }

         list: {
                tended struct b_list *hp; /* work in progress */
                tended struct descrip d;
                C_integer cnv_x;
                word i, size;

                hp = (struct b_list *)BlkLoc(s);
                /*
                 * Make sure that subscript x is in range.
                 */
                if (!cnv:C_integer(x, cnv_x)) {
                    if (cnv:integer(x, x)) 
                        fail;
                    runerr(101, x);
                }
                size = hp->size;
                i = cvpos((long)cnv_x, size);
                if (i == CvtFail || i > size + 1)
                    fail;
                if (i == size + 1) {
                    /*
                     * Put the element to insert on the back
                     */
                    c_put(&s, &y);
                } else  /* i <= size */
                    c_list_insert(&s, i, &y);
                EVValD(&s, E_Linsert);
                EVVal(cnv_x, E_Lsub);
                return s;
        }
      table: {
            tended union block *bp, *bp2;
            union block **pd;
            struct b_telem *te;
            register uword hn;
            int res;

            bp = BlkLoc(s);
            hn = hash(&x);

            /* get this now because can't tend pd */
            MemProtect(te = alctelem());

            pd = memb(bp, &x, hn, &res);	/* search table for key */
            if (res == 0) {
                /*
                 * The element is not in the table - insert it.
                 */
                bp->table.size++;
                te->clink = *pd;
                *pd = (union block *)te;
                te->hashnum = hn;
                te->tref = x;
                te->tval = y;
                if (TooCrowded(bp))
                    hgrow(bp);
            }
            else {
                /*
                 * We found an existing entry; just change its value.
                 */
                dealcblk((union block *)te);
                te = (struct b_telem *) *pd;
                te->tval = y;
            }
            EVValD(&s, E_Tinsert);
            EVValD(&x, E_Tsub);
            return s;
         }

      default:
         runerr(122, s);
    }
  }
end


"list(i, x) - create a list of size i, with initial value x."

function{1} list(n, x)
   if !def:C_integer(n, 0L) then
      runerr(101, n)

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
      MemProtect(hp = alclist_raw(size, nslots));
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
   body {
     type_case s of {
        set: {
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
      table: {
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

      default:
          runerr(133, s);
    }
  }
end



"pull(L) - pull an element from end of list L."

function{0,1} pull(x)
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)

   body {
      register word i;
      register struct b_list *hp;
      register struct b_lelem *bp;

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
      i = BlkLoc(*l)->list.size / 2;
      if (i < MinListSlots)
         i = MinListSlots;

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i)) == NULL) {
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



"push(L, x1, ..., xN) - push values onto beginning of list L."

function{1} push(x, vals[n])
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)

   body {
      tended struct b_list *hp;
      dptr dp;
      register word i, val, num;
      register struct b_lelem *bp; /* does not need to be tended */

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
	    i = hp->size / 2;
	    if (i < MinListSlots)
	       i = MinListSlots;

	    /*
	     * Allocate a new list element block.  If the block can't
	     *  be allocated, try smaller blocks.
	     */
	    while ((bp = alclstb(i)) == NULL) {
	       i /= 4;
	       if (i < MinListSlots)
                   fatalerr(0, NULL);
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


static void listdump(dptr d)
{
    union block *b;
    struct b_list *l = (struct b_list *)BlkLoc(*d);
    word i;
    return;
    fprintf(stderr, "list at %p size=%ld head=%p tail=%p\n", l, (long)l->size, l->listhead, l->listtail);
    for (b = l->listhead; 
         BlkType(b) == T_Lelem;
         b = b->lelem.listnext) {
        struct b_lelem *e = (struct b_lelem *)b;
        fprintf(stderr, "\telement block at %p nslots=%ld first=%ld used=%ld prev=%p next=%p\n",
                e, (long)e->nslots, (long)e->first, (long)e->nused, e->listprev, e->listnext);

        for (i = 0; i < e->nused; i++) {
            word j = e->first + i;
            if (j >= e->nslots)
                j -= e->nslots;
            fprintf(stderr, "\t\tSlot %ld = ", (long)j);
            print_desc(stderr, &e->lslots[j]);
            fprintf(stderr, "\n");
        }
    }
    fflush(stderr);
}

void c_list_insert(dptr l, word pos, dptr val)
{
    word i, j, k;
    tended struct b_list *lb;
    tended struct b_lelem *le, *le2;

    listdump(l);

    lb = (struct b_list *)BlkLoc(*l);

    if (pos < 1 || pos > lb->size)
        syserr("Invalid pos to c_list_insert");
    --pos;

    le = (struct b_lelem *)lb->listhead;

    while (pos >= le->nused) {
        pos -= le->nused;
        le = (struct b_lelem *)le->listnext;
    }
    if (le->nused < le->nslots) {
        /*fprintf(stderr, "Insert at block %p pos=%d\n",le,pos);fflush(stderr);*/
        /* Decrement first */
        --le->first;
        if (le->first < 0)
            le->first = le->nslots - 1;
        j = le->first;
        for (i = 0; i < pos; ++i) {
            k = j + 1;
            if (k >= le->nslots)
                k = 0;
            le->lslots[j] = le->lslots[k];
            j = k;
        }
        le->lslots[j] = *val;
        ++le->nused;
    } else {
        /*
         * Allocate a new list element block.
         */
        i = Min(le->nslots + MinListSlots, 2 * le->nslots);
        MemProtect(le2 = alclstb(i));

        /* Copy elements to the new one, inserting the new one in the right place. */
        j = le->first;
        k = 0;
        for (i = 0; i < le->nused; ++i) {
            if (i == pos)
                le2->lslots[k++] = *val;
            le2->lslots[k++] = le->lslots[j++];
            if (j >= le->nslots)
                j = 0;
        }
        le2->listprev = le->listprev;
        le2->listnext = le->listnext;
        le2->first = 0;
        le2->nused = le->nused + 1;
        if (lb->listhead == (union block *)le)
            lb->listhead = (union block *)le2;
        else
            le->listprev->lelem.listnext = (union block *)le2;
        if (lb->listtail == (union block *)le)
            lb->listtail = (union block *)le2;
        else
            le->listnext->lelem.listprev = (union block *)le2;
    }

    ++lb->size;
    listdump(l);
}

void c_list_delete(dptr l, word pos)
{
    word i, j, k, n;
    struct b_list *lb;
    struct b_lelem *le;

    lb = (struct b_list *)BlkLoc(*l);

    if (pos < 1 || pos > lb->size)
        syserr("Invalid pos to c_list_delete");
    --pos;

    le = (struct b_lelem *)lb->listhead;

    while (pos >= le->nused) {
        pos -= le->nused;
        le = (struct b_lelem *)le->listnext;
    }
    j = le->first + pos;
    if (j >= le->nslots)
        j -= le->nslots;
    n = le->nused - pos - 1;
    for (i = 0; i < n; ++i) {
        k = j + 1;
        if (k >= le->nslots)
            k = 0;
        le->lslots[j] = le->lslots[k];
        j = k;
    }
    --le->nused;

    /* Unlink this block if empty and not the only block */
    if (le->nused == 0 && 
        !(lb->listhead == (union block *)le &&
          lb->listtail == (union block *)le)) {
        if (lb->listhead == (union block *)le)
            lb->listhead = le->listnext;
        else
            le->listprev->lelem.listnext = le->listnext;

        if (lb->listtail == (union block *)le)
            lb->listtail = le->listprev;
        else
            le->listnext->lelem.listprev = le->listprev;
    }

    --lb->size;    
    listdump(l);

}


/*
 * c_put - C-level, nontending list put function
 */
void c_put(dptr l, dptr val)
{
   register word i = 0;
   register struct b_lelem *bp;  /* does not need to be tended */

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
      i = ((struct b_list *)BlkLoc(*l))->size / 2;
      if (i < MinListSlots)
         i = MinListSlots;

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i)) == NULL) {
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

   body {
      tended struct b_list *hp;
      dptr dp;
      register word i, val, num;
      register struct b_lelem *bp;  /* does not need to be tended */

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
	    i = hp->size / 2;
	    if (i < MinListSlots)
	       i = MinListSlots;
	    if (i < n - val)
	       i = n - val;

	    /*
	     * Allocate a new list element block.  If the block can't
	     *  be allocated, try smaller blocks.
	     */
	    while ((bp = alclstb(i)) == NULL) {
	       i /= 4;
	       if (i < MinListSlots)
                   fatalerr(0, NULL);
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

"set(x1,...,xN) - create a set with given members."

function{1} set(x[n])
   body {
     tended union block *pb, *ps;
     struct b_selem *ne;			/* does not need to be tended */
     union block **pe;
     register uword hn;
     int res, argc;

     /*
      * Make a set.
      */
     MemProtect(ps = hmake(T_Set, (word)0, n));
     result.dword = D_Set;
     result.vword.bptr = ps;

     for (argc = 0; argc < n; argc++) {
         hn = hash(&x[argc]);
         /* get this now because can't tend pe */
         MemProtect(ne = alcselem());
         pe = memb(ps, &x[argc], hn, &res);
         if (res == 0) {
             ne->setmem = x[argc];
             ne->hashnum = hn;
             addmem((struct b_set *)ps, ne, pe);
         } else
             dealcblk((union block *)ne);
     }

     EVValD(&result, E_Screate);

     return result;
   }
end


"table(x,k1,v1,k2,v2...) - create a table with default value x, and initial mappings"
"v[0]->v[1], v[2]->v[3] etc."
function{1} table(x, v[n])
   body {
      tended union block *bp, *bp2;
      union block **pd;
      struct b_telem *te;
      register uword hn;
      int res, argc;
   
      MemProtect(bp = hmake(T_Table, (word)0, (word)n));
      bp->table.defvalue = x;
      result.dword = D_Table;
      result.vword.bptr = bp;

      for(argc = 0; argc < n; argc += 2) {

          hn = hash(v + argc);

          /* get this now because can't tend pd */
          MemProtect(te = alctelem());

          pd = memb(bp, v + argc, hn, &res);	/* search table for key */
          if (res == 0) {
              /*
               * The element is not in the table - insert it.
               */
              bp->table.size++;
              te->clink = *pd;
              *pd = (union block *)te;
              te->hashnum = hn;
              te->tref = v[argc];
              if (argc + 1 < n)
                  te->tval = v[argc + 1];
              else
                  te->tval = nulldesc;
              if (TooCrowded(bp))
                  hgrow(bp);
          }
          else {
              /*
               * We found an existing entry; just change its value.
               */
              dealcblk((union block *)te);
              te = (struct b_telem *) *pd;
              if (argc+1 < n)
                  te->tval = v[argc + 1];
              else
                  te->tval = nulldesc;
          }
      }

      EVValD(&result, E_Tcreate);

      return result;
   }
end


"keyof(s, x) - given a table or list s and a value x, generate the keys k such that s[k] === x"

function{*} keyof(s,x)
   body {
      tended union block *ep;
      type_case s of {
        list: {
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

        table: {
	    struct hgstate state;
	    for (ep = hgfirst(BlkLoc(s), &state); ep != 0;
		 ep = hgnext(BlkLoc(s), &state, ep)) {
               if (equiv(&ep->telem.tval, &x))
                  suspend ep->telem.tref;
            }
	    fail;
         }

          default:
              runerr(127, s);
      }
   }
end
