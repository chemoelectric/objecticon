/*
 * File: fstruct.r
 *  Contents: delete, get, key, insert, list, member, pop, pull, push, put,
 *  set, table
 */


"delete(x1,x2) - delete element x2 from set or table or list x1 if it is there"
" (always succeeds and returns x1)."

function{1} delete(s,x)
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
function{0,1} get_or_pop(x)
   if !is:list(x) then
      runerr(108, x)
   body {
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
            set_insert(&s, &x);
            EVValD(&s, E_Sinsert);
            EVValD(&x, E_Sval);
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
      EVValD(&x, E_Lpull);
     if (!list_pull(&x, &result)) 
         fail;
     return result;
   }
end


"push(L, val) - push value onto beginning of list L."

function{1} push(x, val)
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

function{1} put(x, val)
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

function{1} set(x[n])
   body {
     tended union block *ps;
     int argc;

     /*
      * Make a set.
      */
     MemProtect(ps = hmake(T_Set, 0, n));
     result.dword = D_Set;
     result.vword.bptr = ps;

     for (argc = 0; argc < n; argc++)
         set_insert(&result, &x[argc]);

     EVValD(&result, E_Screate);

     return result;
   }
end


"table(x,k1,v1,k2,v2...) - create a table with default value x, and initial mappings"
"                          v[0]->v[1], v[2]->v[3] etc."
function{1} table(x, v[n])
   body {
      tended union block *bp;
      int argc;
   
      MemProtect(bp = hmake(T_Table, 0, n/2));
      bp->table.defvalue = x;
      result.dword = D_Table;
      result.vword.bptr = bp;

      for(argc = 0; argc < n; argc += 2) {
          if (argc + 1 < n)
              table_insert(&result, &v[argc], &v[argc + 1]);
          else
              table_insert(&result, &v[argc], &nulldesc);
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
