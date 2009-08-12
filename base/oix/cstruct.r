/*
 * A collection of functions for handling lists/sets/tables, most of
 * which are used directly by the icon-level functions (put, insert
 * etc).
 * Note that all dptr's passed to these functions must point to tended
 * descriptors (eg on the stack).
 */



/*
 * Create a descriptor for an empty list, with initial number of slots.
 */
void create_list(uword nslots, dptr d) 
{
   struct b_list *hp;
 
   if (nslots == 0)
      nslots = MinListSlots;
   MemProtect(hp = alclist(0, nslots));
 
   d->dword = D_List;
   d->vword.bptr = (union  block *)hp;
}

int set_del(dptr s, dptr key)
{
    register uword hn;
    register union block **pd;
    int res;

    hn = hash(key);
    pd = memb(BlkLoc(*s), key, hn, &res);
    if (res == 1) {
        /*
         * The element is there so delete it.
         */
        *pd = (*pd)->selem.clink;
        (BlkLoc(*s)->set.size)--;
    }
    return res;
}

int table_del(dptr t, dptr key)
{
    register union block **pd;
    register uword hn;
    int res;

    hn = hash(key);
    pd = memb(BlkLoc(*t), key, hn, &res);
    if (res == 1) {
        /*
         * The element is there so delete it.
         */
        *pd = (*pd)->telem.clink;
        (BlkLoc(*t)->table.size)--;
    }
    return res;
}


/*
 * c_get - convenient C-level access to the get function
 *  returns 0 on failure, otherwise fills in res
 */
int list_get(dptr l, dptr res)
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

void table_insert(dptr t, dptr key, dptr val)
{
    union block **pd;
    struct b_telem *te;
    register uword hn;
    int res;

    hn = hash(key);

    /* get this now because can't tend pd */
    MemProtect(te = alctelem());

    pd = memb(BlkLoc(*t), key, hn, &res);	/* search table for key */
    if (res == 0) {
        /*
         * The element is not in the table - insert it.
         */
        BlkLoc(*t)->table.size++;
        te->clink = *pd;
        *pd = (union block *)te;
        te->hashnum = hn;
        te->tref = *key;
        te->tval = *val;
        if (TooCrowded(BlkLoc(*t)))
            hgrow(BlkLoc(*t));
    }
    else {
        /*
         * We found an existing entry; just change its value.
         */
        dealcblk((union block *)te);
        te = (struct b_telem *) *pd;
        te->tval = *val;
    }
}

void set_insert(dptr s, dptr entry)
{
    register uword hn;
    int res;
    struct b_selem *se;
    register union block **pd;

    hn = hash(entry);
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

    pd = memb(BlkLoc(*s), entry, hn, &res);
    if (res == 0) {
        /*
         * The element is not in the set - insert it.
         */
        se->setmem = *entry;
        se->hashnum = hn;
        addmem((struct b_set *)BlkLoc(*s), se, pd);
        if (TooCrowded(BlkLoc(*s)))
            hgrow(BlkLoc(*s));
    }
    else
        dealcblk((union block *)se);
}

int list_pull(dptr l, dptr res)
{
    word i;
    struct b_list *hp = (struct b_list *) BlkLoc(*l);
    struct b_lelem *bp;

    /*
     * Point at list header block and fail if the list is empty.
     */
    if (hp->size <= 0)
        return 0;

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
    *res = bp->lslots[i];
    bp->nused--;
    hp->size--;

    return 1;
}


void list_push(dptr l, dptr val)
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



/*
 * Debug func
 */
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

void list_insert(dptr l, word pos, dptr val)
{
    word i, j, k;
    tended struct b_list *lb;
    tended struct b_lelem *le, *le2;

    listdump(l);

    lb = (struct b_list *)BlkLoc(*l);

    if (pos < 1 || pos > lb->size)
        syserr("Invalid pos to list_insert");
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
}

void list_del(dptr l, word pos)
{
    word i, j, k, n;
    struct b_list *lb;
    struct b_lelem *le;

    lb = (struct b_list *)BlkLoc(*l);

    if (pos < 1 || pos > lb->size)
        syserr("Invalid pos to list_del");
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
}


void list_put(dptr l, dptr val)
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
