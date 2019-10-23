/*
 * A collection of functions for handling lists/sets/tables, most of
 * which are used directly by the icon-level functions (put, insert
 * etc).
 * 
 * Note that all dptr's passed to these functions must point to tended
 * descriptors (eg in stack frames).  In particular, they must not
 * point to members of structures, since those structures may move on
 * garbage collection.  So, don't use for example
 * 
 *   list_put(&l, get_element(&x, i)).   Rather, one should use
 * 
 *   tended struct descrip tmp;
 *   tmp = *get_element(&x, i);
 *   list_put(&l, &tmp);
 */


#if 0
/*
 * Debug funcs
 */
static void listdump(dptr d, int all)
{
    union block *b;
    struct b_list *l = &ListBlk(*d);
    word i, j;

    fprintf(stderr, "list at %p size=" WordFmt " head=%p tail=%p\n", l, l->size, l->listhead, l->listtail);
    for (b = l->listhead; 
         BlkType(b) == T_Lelem;
         b = b->lelem.listnext) {
        struct b_lelem *e = (struct b_lelem *)b;
        fprintf(stderr, "\telement block at %p nslots=" WordFmt " first=" WordFmt " used=" WordFmt " prev=%p next=%p\n",
                e, e->nslots, e->first, e->nused, e->listprev, e->listnext);
        if (all) {
            for (i = 0; i < e->nslots; i++) {
                j = i - e->first;
                if (j < 0)
                    j += e->nslots;
                fprintf(stderr, "\t\tSlot " WordFmt " = ", i);
                print_desc(stderr, &e->lslots[i]);
                if (j < e->nused)
                    fprintf(stderr, " (used)\n");
                else
                    fprintf(stderr, " (free)\n");
            }
        } else {
            for (i = 0; i < e->nused; i++) {
                j = e->first + i;
                if (j >= e->nslots)
                    j -= e->nslots;
                fprintf(stderr, "\t\tSlot " WordFmt " = ", j);
                print_desc(stderr, &e->lslots[j]);
                fputc('\n', stderr);
            }
        }
    }
    fflush(stderr);
}

static void setdump(dptr d)
{
    struct b_set *x = &SetBlk(*d);
    int i;
    fprintf(stderr, "set at %p size=" WordFmt " mask=" XWordFmt "\n", x, x->size, x->mask);
    for (i = 0; i < HSegs; ++i) {
        struct b_slots *slot = x->hdir[i];
        fprintf(stderr, "\tslot %d at %p segsize=" UWordFmt "\n", i, slot, segsize[i]);
        if (slot) {
            word j;
            for (j = 0; j < segsize[i]; ++j) {
                struct b_selem *elem = (struct b_selem *)slot->hslots[j];
                fprintf(stderr, "\t\tbucket chain %d at %p\n", j, elem);
                while (BlkType(elem) == T_Selem) {
                    fprintf(stderr, "\t\t\tselem %p hash=" UWordFmt " clink=%p mem=", elem, elem->hashnum, elem->clink);
                    print_desc(stderr, &elem->setmem);
                    fputc('\n', stderr);
                    elem = (struct b_selem *)elem->clink;
                }
            }
        }
    }
    fflush(stderr);
}


static void tabledump(dptr d)
{
    struct b_table *x = &TableBlk(*d);
    int i;
    fprintf(stderr, "table at %p size=" WordFmt " mask=" XWordFmt "\n", x, x->size, x->mask);
    for (i = 0; i < HSegs; ++i) {
        struct b_slots *slot = x->hdir[i];
        fprintf(stderr, "\tslot %d at %p segsize=" UWordFmt "\n", i, slot, segsize[i]);
        if (slot) {
            word j;
            for (j = 0; j < segsize[i]; ++j) {
                union block *elem = slot->hslots[j];
                fprintf(stderr, "\t\tbucket chain %d at %p\n", j, elem);
                while (BlkType(elem) == T_Telem) {
                    struct b_telem *telem = (struct b_telem *)elem;
                    fprintf(stderr, "\t\t\telem %p hash=" UWordFmt "  clink=%p mem=", telem, telem->hashnum, telem->clink);
                    print_desc(stderr, &telem->tref);
                    fprintf(stderr, "->");
                    print_desc(stderr, &telem->tval);
                    fputc('\n', stderr);
                    elem = telem->clink;
                }
            }
        }
    }
    fflush(stderr);
}

#endif

/*
 * Create a descriptor for an empty list, with initial number of slots.
 */
void create_list(word nslots, dptr d) 
{
   if (nslots == 0)
      nslots = MinListSlots;
   MakeDescMemProtect(D_List, alclist(0, nslots), d);
}

void create_table(word nslots, word nelem, dptr d)
{
    MakeDescMemProtect(D_Table, hmake(T_Table, nslots, nelem), d);
}

void create_set(word nslots, word nelem, dptr d)
{
    MakeDescMemProtect(D_Set, hmake(T_Set, nslots, nelem), d);
}

int set_del(dptr s, dptr key)
{
    uword hn;
    union block **pd;
    int res;

    hn = hash(key);
    pd = memb(BlkLoc(*s), key, hn, &res);
    if (res) {
        /*
         * The element is there so delete it.
         */
        *pd = (*pd)->selem.clink;
        (SetBlk(*s).size)--;
    }
    return res;
}

int table_del(dptr t, dptr key)
{
    union block **pd;
    uword hn;
    int res;

    hn = hash(key);
    pd = memb(BlkLoc(*t), key, hn, &res);
    if (res) {
        /*
         * The element is there so delete it.
         */
        *pd = (*pd)->telem.clink;
        (TableBlk(*t).size)--;
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
   struct b_list *hp = &ListBlk(*l);
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
   bp->lslots[i] = nulldesc;

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
   hp->changecount++;

   return 1;
}

void table_insert(dptr t, dptr key, dptr val, int overwrite)
{
    union block **pd;
    struct b_telem *te;
    uword hn;
    int res;

    hn = hash(key);

    /* get this now because can't tend pd */
    MemProtect(te = alctelem());

    pd = memb(BlkLoc(*t), key, hn, &res);	/* search table for key */
    if (!res) {
        /*
         * The element is not in the table - insert it.
         */
        TableBlk(*t).size++;
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
        if (overwrite) {
            te = (struct b_telem *) *pd;
            te->tval = *val;
        }
    }
}

void set_insert(dptr s, dptr entry)
{
    uword hn;
    int res;
    struct b_selem *se;
    union block **pd;

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
    if (!res) {
        /*
         * The element is not in the set - insert it.
         */
        se->setmem = *entry;
        se->hashnum = hn;
        addmem(&SetBlk(*s), se, pd);
        if (TooCrowded(BlkLoc(*s)))
            hgrow(BlkLoc(*s));
    }
    else
        dealcblk((union block *)se);
}

int list_pull(dptr l, dptr res)
{
    word i;
    struct b_list *hp = &ListBlk(*l);
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
    bp->lslots[i] = nulldesc;
    bp->nused--;
    hp->size--;
    hp->changecount++;

    return 1;
}


void list_push(dptr l, dptr val)
{
   word i;
   struct b_lelem *bp; /* does not need to be tended */

   /*
    * Point bp at the first list-element block.
    */
   bp = (struct b_lelem *) ListBlk(*l).listhead;

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
      i = ListBlk(*l).size / 2;
      if (i < MinListSlots)
         i = MinListSlots;

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i)) == NULL) {
         i /= 4;
         if (i < MinListSlots)
            fatalerr(309, NULL);
         }

      ListBlk(*l).listhead->lelem.listprev = (union block *) bp;
      bp->listprev = BlkLoc(*l);
      bp->listnext = ListBlk(*l).listhead;
      ListBlk(*l).listhead = (union block *) bp;
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
   ListBlk(*l).size++;
   ListBlk(*l).changecount++;
   }


void list_insert(dptr l, word index, dptr val)
{
    word i, j, k, pos;
    tended struct b_lelem *le, *le2;

    le = get_lelem_for_index(&ListBlk(*l), index, &pos);
    if (!le)
        syserr("Invalid index to list_insert");

    if (le->nused < le->nslots) {
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
        if (ListBlk(*l).listhead == (union block *)le)
            ListBlk(*l).listhead = (union block *)le2;
        else
            le->listprev->lelem.listnext = (union block *)le2;
        if (ListBlk(*l).listtail == (union block *)le)
            ListBlk(*l).listtail = (union block *)le2;
        else
            le->listnext->lelem.listprev = (union block *)le2;
    }

    ++ListBlk(*l).size;
    ++ListBlk(*l).changecount;
}

void list_del(dptr l, word index)
{
    word pos, i, j, k, n;
    struct b_list *lb;
    struct b_lelem *le;

    lb = &ListBlk(*l);
    le = get_lelem_for_index(lb, index, &pos);
    if (!le)
        syserr("Invalid index to list_del");

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
    le->lslots[j] = nulldesc;
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

    ++lb->changecount;
    --lb->size;    
}


void list_put(dptr l, dptr val)
{
   word i;
   struct b_lelem *bp;  /* does not need to be tended */

   /*
    * Point hp at the list-header block and bp at the last
    *  list-element block.
    */
   bp = (struct b_lelem *) ListBlk(*l).listtail;
   
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
      i = ListBlk(*l).size / 2;
      if (i < MinListSlots)
         i = MinListSlots;

      /*
       * Allocate a new list element block.  If the block can't
       *  be allocated, try smaller blocks.
       */
      while ((bp = alclstb(i)) == NULL) {
         i /= 4;
         if (i < MinListSlots)
            fatalerr(309, NULL);
         }

      ListBlk(*l).listtail->lelem.listnext =
	(union block *) bp;
      bp->listprev = ListBlk(*l).listtail;
      bp->listnext = BlkLoc(*l);
      ListBlk(*l).listtail = (union block *) bp;
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
   ListBlk(*l).size++;
   ListBlk(*l).changecount++;
}

/*
 * Get the given element of the given structure.  i is one-based.
 * Returns a null pointer if i is out of range, or a pointer to the
 * given element otherwise.
 */
dptr get_element(dptr d, word i)
{
    type_case *d of {
      list: {
         struct b_lelem *le;        /* doesn't need to be tended */
         struct b_list *lp;        /* doesn't need to be tended */
         word j;
         lp = &ListBlk(*d);
         i = cvpos_item(i, lp->size);
         if (i == CvtFail)
             return 0;
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
         return &le->lslots[j];
      }

      record: {
         struct b_record *bp;        /* doesn't need to be tended */
         bp = &RecordBlk(*d);
         i = cvpos_item(i, bp->constructor->n_fields);
         if (i == CvtFail)
             return 0;
         return &bp->fields[i - 1];
        }
     default: {
         syserr("Bad type to get_element");
         /* not reached */
         return 0;
     }
   }
}

void list_clear(dptr l)
{
    int i, j;
    struct b_list *x = &ListBlk(*l);
    struct b_lelem *f = (struct b_lelem *)x->listhead;  /* First block is cleared and kept */
    /* Set used elements in block to &null */
    i = f->first;
    for (j = 0; j < f->nused; ++j) {
        f->lslots[i] = nulldesc;
        if (++i >= f->nslots)
            i = 0;
    }
    x->listtail = (union block *)f;
    f->listnext = (union block *)x;
    f->nused = 0;
    ++x->changecount;
    x->size = 0;
}

void set_clear(dptr s)
{
    struct b_set *x = &SetBlk(*s);
    int i;
    for (i = 0; i < HSegs; ++i) {
        struct b_slots *slot = x->hdir[i];
        if (slot) {
            word j;
            for (j = 0; j < segsize[i]; ++j)
                slot->hslots[j] = (union block *)x;
        }
    }
    x->size = 0;
}

void table_clear(dptr t)
{
    struct b_table *x = &TableBlk(*t);
    int i;
    for (i = 0; i < HSegs; ++i) {
        struct b_slots *slot = x->hdir[i];
        if (slot) {
            word j;
            for (j = 0; j < segsize[i]; ++j)
                slot->hslots[j] = (union block *)x;
        }
    }
    x->size = 0;
}

