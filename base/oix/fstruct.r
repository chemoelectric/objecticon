/*
 * File: fstruct.r
 */


"delete(s,x) - delete element x from set or table or list s if it is there"
" (always succeeds and returns s)."

function delete(s,x)
   body {

   type_case s of {
     set: {
            set_del(&s, &x);
            EVValD(&s, E_Sdelete);
            EVValD(&x, E_Sval);
            return s;
         }

     table: {
            table_del(&s, &x);
            EVValD(&s, E_Tdelete);
            EVValD(&x, E_Tsub);
            return s;
         }
     list: {
            word cnv_x, i, size;

            /*
             * Make sure that subscript x is in range.
             */
            if (!cnv:C_integer(x, cnv_x)) {
                if (cnv:integer(x, x)) 
                    fail;
                runerr(101, x);
            }
            size = ListBlk(s).size;
            i = cvpos((long)cnv_x, size);
            if (i == CvtFail || i > size)
                fail;

            list_del(&s, i);
            EVValD(&s, E_Ldelete);
            EVVal(cnv_x, E_Lsub);
	    return s;
         }

      default:
          runerr(122, s);
     }
   }
end


#begdef GetOrPop(get_or_pop)
#get_or_pop "(x) - " #get_or_pop " an element from the left end of list x."
/*
 * get(L) - get an element from end of list L.
 *  Identical to pop(L,i).
 */
function get_or_pop(x)
   if !is:list(x) then
      runerr(108, x)
   body {
     tended struct descrip result;
     EVValD(&x, E_Lget);
     if (!list_get(&x, &result)) 
         fail;
     return result;
   }
end
#enddef

GetOrPop(get) /* get(x) - get an element from the left end of list x. */
GetOrPop(pop) /* pop(x) - pop an element from the left end of list x. */


"key(T) - generate successive keys (entry values) from table T."

function key(t)
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

"keyval(T) - generate alternate keys and their corresponding values (as variables)"
"      from table T."

function keyval(t)
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
           suspend struct_var(&ep->telem.tval, ep);
       }
       fail;
   }
end


"insert(s, x, y) - insert element x into set or table or list s if not already there"
" if s is a table or list, the assigned value for element x is y."
" (always succeeds and returns s)."

function insert(s, x, y)
    body {
      type_case s of {

      set: {
            set_insert(&s, &x);
            EVValD(&s, E_Sinsert);
            EVValD(&x, E_Sval);
            return s;
         }

      list: {
            word cnv_x, i, size;

            /*
             * Make sure that subscript x is in range.
             */
            if (!cnv:C_integer(x, cnv_x)) {
                if (cnv:integer(x, x)) 
                    fail;
                runerr(101, x);
            }
            size = ListBlk(s).size;
            i = cvpos((long)cnv_x, size);
            if (i == CvtFail || i > size + 1)
                fail;
            if (i == size + 1) {
                /*
                 * Put the element to insert on the back
                 */
                list_put(&s, &y);
            } else  /* i <= size */
                list_insert(&s, i, &y);
            EVValD(&s, E_Linsert);
            EVVal(cnv_x, E_Lsub);
            return s;
        }
      table: {
            table_insert(&s, &x, &y);
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

function list(n, x)
   if !def:C_integer(n, 0L) then
      runerr(101, n)

   body {
      tended struct b_list *hp;
      word i, size, nslots;
      struct b_lelem *bp; /* does not need to be tended */

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


"member(s, x) - if x is a set, return x if it is a member of s; if x is a table "
" return s[x] (a variable) if x is a key of s.  Fails otherwise."

function member(s, x)
   body {
     type_case s of {
        set: {
            int res;
            register uword hn;

            EVValD(&s, E_Smember);
            EVValD(&x, E_Sval);

            hn = hash(&x);
            memb(BlkLoc(s), &x, hn, &res);
            if (res == 1)
               return x;
            else
               fail;
         }
      table: {
            int res;
            register uword hn;
            union block **p;
            register union block *bp; /* doesn't need to be tended */

            EVValD(&s, E_Tmember);
            EVValD(&x, E_Tsub);

            hn = hash(&x);
            p = memb(BlkLoc(s), &x, hn, &res);
            if (res == 1) {
               bp = *p;
               return struct_var(&bp->telem.tval, bp);
            } else
               fail;
      }

      default:
          runerr(133, s);
    }
  }
end


"pull(L) - pull an element from end of list L."

function pull(x)
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)

   body {
     tended struct descrip result;
     EVValD(&x, E_Lpull);
     if (!list_pull(&x, &result)) 
         fail;
     return result;
   }
end


"push(L, val) - push value onto beginning of list L."

function push(x, val)
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)

   body {
      list_push(&x, &val);
      EVValD(&x, E_Lpush);
      /*
       * Return the list.
       */
      return x;
   }
end


"put(L, val) - put element onto end of list L."

function put(x, val)
   /*
    * x must be a list.
    */
   if !is:list(x) then
      runerr(108, x)

   body {
      list_put(&x, &val);
      EVValD(&x, E_Lput);

      /*
       * Return the list.
       */
      return x;
   }
end

"set(x1,...,xN) - create a set with given members."

function set(x[n])
   body {
     tended struct descrip result;
     tended union block *ps;
     int argc;

     /*
      * Make a set.
      */
     MemProtect(ps = hmake(T_Set, 0, n));
     result.dword = D_Set;
     BlkLoc(result) = ps;

     for (argc = 0; argc < n; argc++)
         set_insert(&result, &x[argc]);

     EVValD(&result, E_Screate);

     return result;
   }
end


"table(x,k1,v1,k2,v2...) - create a table with default value x, and initial mappings"
"                          v[0]->v[1], v[2]->v[3] etc."
function table(x, v[n])
   body {
      tended struct descrip result;
      tended union block *bp;
      int argc;
   
      MemProtect(bp = hmake(T_Table, 0, n/2));
      bp->table.defvalue = x;
      result.dword = D_Table;
      BlkLoc(result) = bp;

      if (n % 2 != 0)
          runerr(134);

      for(argc = 0; argc < n; argc += 2)
          table_insert(&result, &v[argc], &v[argc + 1]);

      EVValD(&result, E_Tcreate);
      return result;
   }
end


"keyof(s, x) - given a table or list s and a value x, generate the keys k such that s[k] === x"

function keyof(s,x)
   body {
      type_case s of {
        list: {
            struct lgstate state;
            tended struct b_lelem *le;
            for (le = lgfirst(&ListBlk(s), &state); le;
                 le = lgnext(&ListBlk(s), &state, le)) {
                if (equiv(&le->lslots[state.result], &x))
                  suspend C_integer state.listindex;
            }
            fail;
         }

        table: {
	    struct hgstate state;
            tended union block *ep;
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
