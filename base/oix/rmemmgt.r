/*
 * File: rmemmgt.r
 *  Contents: block description arrays, memory initialization,
 *   garbage collection, dump routines
 */


/*
 * Prototypes
 */
static void postqual		(dptr dp);
static void markptr		(union block **ptr);
static void sweep		(struct b_coexpr *ce);
static void sweep_stk	(struct b_coexpr *ce);
static void reclaim		(void);
static void cofree		(void);
static void scollect		(void);
static int  qlcmp		(dptr  *q1,dptr  *q2);
static void adjust		(void);
static void compact		(void);
static void markprogram	(struct progstate *pstate);

/*
 * Variables
 */

static dptr *quallist;                 /* string qualifier list */
static dptr *qualfree;                 /* qualifier list free pointer */
static dptr *equallist;                /* end of qualifier list */
static int do_checkstack;

int collecting;                        /* flag indicating whether collection in progress */


/*
 * Allocated block size table (sizes given in bytes).  A size of -1 is used
 *  for types that have no blocks; a size of 0 indicates that the
 *  second word of the block contains the size; a value greater than
 *  0 is used for types with constant sized blocks.
 */

int bsizes[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
     0,                       /* T_Lrgint (2), large integer */
     sizeof(struct b_real),   /* T_Real (3), real number */
     0,                       /* T_Cset (4), cset */
     0,                       /* T_Constructor (5), record constructor */
     0,                       /* T_Proc (6), procedure block */
     0,                       /* T_Record (7), record block */
     sizeof(struct b_list),   /* T_List (8), list header block */
     0,                       /* T_Lelem (9), list element block */
     sizeof(struct b_set),    /* T_Set (10), set header block */
     sizeof(struct b_selem),  /* T_Selem (11), set element block */
     sizeof(struct b_table),  /* T_Table (12), table header block */
     sizeof(struct b_telem),  /* T_Telem (13), table element block */
     sizeof(struct b_tvtbl),  /* T_Tvtbl (14), table element trapped variable */
     0,                       /* T_Slots (15), set/table hash block */
     sizeof(struct b_tvsubs), /* T_Tvsubs (16), substring trapped variable */
     0,                       /* T_Refresh (17), refresh block */
    -1,                       /* T_Coexpr (18), co-expression block */
     0,                       /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     0,                       /* T_Class (25), class */
     0,                       /* T_Object (26), object */
     sizeof(struct b_cast),   /* T_Cast (27), cast */
     sizeof(struct b_methp),  /* T_Methp (28), method pointer */
    };

/*
 * Table of offsets (in bytes) to first descriptor in blocks.  -1 is for
 *  types not allocated, 0 for blocks with no descriptors.
 */
int firstd[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
     0,                       /* T_Lrgint (2), large integer */
     0,                       /* T_Real (3), real number */
     0,                       /* T_Cset (4), cset */
    -1,                       /* T_Constructor (5), record constructor */
    -1,                       /* T_Proc (6), procedure block */
     4*WordSize,              /* T_Record (7), record block */
     0,                       /* T_List (8), list header block */
     7*WordSize,              /* T_Lelem (9), list element block */
     0,                       /* T_Set (10), set header block */
     3*WordSize,              /* T_Selem (11), set element block */
     (4+HSegs)*WordSize,      /* T_Table (12), table header block */
     3*WordSize,              /* T_Telem (13), table element block */
     3*WordSize,              /* T_Tvtbl (14), table element trapped variable */
     0,                       /* T_Slots (15), set/table hash block */
     3*WordSize,              /* T_Tvsubs (16), substring trapped variable */

     (4+Wsizeof(struct pf_marker))*WordSize, /* T_Refresh (17), refresh block */

    -1,                       /* T_Coexpr (18), co-expression block */
     3*WordSize,              /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     -1,                      /* T_Class (25), class, just contains static data in icode */
     5*WordSize,              /* T_Object (26), object */
     0,                       /* T_Cast (27), cast */
     0,                       /* T_Methp (28), methp */
    };

/*
 * Table of offsets (in bytes) to first pointer in blocks.  -1 is for
 *  types not allocated, 0 for blocks with no pointers.
 */
int firstp[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
     0,                       /* T_Lrgint (2), large integer */
     0,                       /* T_Real (3), real number */
     0,                       /* T_Cset (4), cset */
     0,                       /* T_Constructor (5), record constructor */
     0,                       /* T_Proc (6), procedure block */
     3*WordSize,              /* T_Record (7), record block */
     4*WordSize,              /* T_List (8), list header block */
     2*WordSize,              /* T_Lelem (9), list element block */
     4*WordSize,              /* T_Set (10), set header block */
     1*WordSize,              /* T_Selem (11), set element block */
     4*WordSize,              /* T_Table (12), table header block */
     1*WordSize,              /* T_Telem (13), table element block */
     1*WordSize,              /* T_Tvtbl (14), table element trapped variable */
     2*WordSize,              /* T_Slots (15), set/table hash block */
     0,                       /* T_Tvsubs (16), substring trapped variable */
     0,                       /* T_Refresh (17), refresh block */
    -1,                       /* T_Coexpr (18), co-expression block */
     0,                       /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     -1,                      /* T_Class (25), class, just contains static data in icode */
     0,                       /* T_Object (26), object, just a pointer to the class, which is static */
     1*WordSize,              /* T_Cast (27), cast */
     1*WordSize,              /* T_Methp (28), methp */
    };

/*
 * Table of number of pointers in blocks.  -1 is for types not allocated and
 *  types without pointers, 0 for pointers through the end of the block.
 */
int ptrno[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
    -1,                       /* T_Lrgint (2), large integer */
    -1,                       /* T_Real (3), real number */
    -1,                       /* T_Cset (4), cset */
    -1,                       /* T_Constructor (5), record constructor */
    -1,                       /* T_Proc (6), procedure block */
     1,                       /* T_Record (7), record block */
     2,                       /* T_List (8), list header block */
     2,                       /* T_Lelem (9), list element block */
     HSegs,                   /* T_Set (10), set header block */
     1,                       /* T_Selem (11), set element block */
     HSegs,                   /* T_Table (12), table header block */
     1,                       /* T_Telem (13), table element block */
     1,                       /* T_Tvtbl (14), table element trapped variable */
     0,                       /* T_Slots (15), set/table hash block */
    -1,                       /* T_Tvsubs (16), substring trapped variable */
    -1,                       /* T_Refresh (17), refresh block */
    -1,                       /* T_Coexpr (18), co-expression block */
    -1,                       /* T_Ucs (19), unicode string */
    -1,                       /* T_Kywdint (20), integer keyword variable */
    -1,                       /* T_Kywdpos (21), keyword &pos */
    -1,                       /* T_Kywdsubj (22), keyword &subject */
    -1,                       /* T_Kywdstr (23), string keyword variable */
    -1,                       /* T_Kywdany (24), event keyword variable */
    -1,                       /* T_Class (25), class */
    -1,                       /* T_Object (26), object */
     1,                       /* T_Cast (27), cast */
     1,                       /* T_Methp (28), method pointer */
    };

/*
 * Table of number of descriptors in blocks.  -1 is for types not allocated and
 *  types without descriptors, 0 for descriptors through the end of the block.
 */
int descno[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
    -1,                       /* T_Lrgint (2), large integer */
    -1,                       /* T_Real (3), real number */
    -1,                       /* T_Cset (4), cset */
    -1,                       /* T_Constructor (5), record constructor */
    -1,                       /* T_Proc (6), procedure block */
     0,                       /* T_Record (7), record block */
    -1,                       /* T_List (8), list header block */
     0,                       /* T_Lelem (9), list element block */
    -1,                       /* T_Set (10), set header block */
     0,                       /* T_Selem (11), set element block */
     0,                       /* T_Table (12), table header block */
     0,                       /* T_Telem (13), table element block */
     0,                       /* T_Tvtbl (14), table element trapped variable */
    -1,                       /* T_Slots (15), set/table hash block */
     0,                       /* T_Tvsubs (16), substring trapped variable */
     0,                       /* T_Refresh (17), refresh block */
    -1,                       /* T_Coexpr (18), co-expression block */
     1,                       /* T_Ucs (19), unicode string */
    -1,                       /* T_Kywdint (20), integer keyword variable */
    -1,                       /* T_Kywdpos (21), keyword &pos */
    -1,                       /* T_Kywdsubj (22), keyword &subject */
    -1,                       /* T_Kywdstr (23), string keyword variable */
    -1,                       /* T_Kywdany (24), event keyword variable */
    -1,                       /* T_Class (25), class, just contains static data in icode */
     0,                       /* T_Object (26), object */
    -1,                       /* T_Cast (27), cast */
    -1,                       /* T_Methp (28), methp */
};

/*
 * Table of block names used by debugging functions.
 */
char *blkname[] = {
   "illegal object",                    /* T_Null (0), not block */
   "illegal object",                    /* T_Integer (1), not block */
   "large integer",                     /* T_Largint (2) */
   "real number",                       /* T_Real (3) */
   "cset",                              /* T_Cset (4) */
   "constructor",                       /* T_Constructor (5), record constructor */
   "procedure",                         /* T_Proc (6) */
   "record",                            /* T_Record (7) */
   "list",                              /* T_List (8) */
   "list element",                      /* T_Lelem (9) */
   "set",                               /* T_Set (10) */
   "set element",                       /* T_Selem (11) */
   "table",                             /* T_Table (12) */
   "table element",                     /* T_Telem (13) */
   "table element trapped variable",    /* T_Tvtbl (14) */
   "hash block",                        /* T_Slots (15) */
   "substring trapped variable",        /* T_Tvsubs (16) */
   "refresh block",                     /* T_Refresh (17) */
   "co-expression",                     /* T_Coexpr (18) */
   "ucs",                               /* T_Ucs (19), unicode string */
   "integer keyword variable",          /* T_Kywdint (20) */
   "&pos",                              /* T_Kywdpos (21) */
   "&subject",                          /* T_Kywdsubj (22) */
   "illegal object",                    /* T_Kywdstr (23) */
   "illegal object",                    /* T_Kywdany (24) */
   "class",                             /* T_Class (25) */
   "object",                            /* T_Object (26) */
   "cast",                              /* T_Cast (27) */
   "methp",                             /* T_Methp (28) */
   };

/*
 * Sizes of hash chain segments.
 *  Table size must equal or exceed HSegs.
 */
uword segsize[] = {
   ((uword)HSlots),			/* segment 0 */
   ((uword)HSlots),			/* segment 1 */
   ((uword)HSlots) << 1,		/* segment 2 */
   ((uword)HSlots) << 2,		/* segment 3 */
   ((uword)HSlots) << 3,		/* segment 4 */
   ((uword)HSlots) << 4,		/* segment 5 */
   ((uword)HSlots) << 5,		/* segment 6 */
   ((uword)HSlots) << 6,		/* segment 7 */
   ((uword)HSlots) << 7,		/* segment 8 */
   ((uword)HSlots) << 8,		/* segment 9 */
   ((uword)HSlots) << 9,		/* segment 10 */
   ((uword)HSlots) << 10,		/* segment 11 */
   };

#define PostDescrip(d) \
   if (Qual(d)) \
      postqual(&(d)); \
   else if (Pointer(d))\
      markptr(&BlkLoc(d));

/*
 * collect - do a garbage collection of currently active regions.
 */

void collect(int region)
   {
   struct b_coexpr *cp;
   struct progstate *prog;

#if defined(HAVE_GETRLIMIT) && defined(HAVE_SETRLIMIT)
   {
       struct rlimit rl;

       getrlimit(RLIMIT_STACK , &rl);
       /*
        * Grow the C stack, proportional to the block region. Seems crazy large,
        * but garbage collection uses stack proportional heap size.  May want to
        * move this whole #if block so it is only performed when the heap grows.
        */
       if (rl.rlim_cur < curblock->size) {
           rl.rlim_cur = curblock->size;
           setrlimit(RLIMIT_STACK , &rl);
       }
   }
#endif

#if E_Collect
   if (!noMTevents)
      EVVal((word)region,E_Collect);
#endif					/* E_Collect */

   switch (region) {
      case User:
         curpstate->colluser++;
         break;
      case Static:
         curpstate->collstat++;
         break;
      case Strings:
         curpstate->collstr++;
         break;
      case Blocks:  
         curpstate->collblk++;
         break;
       default:
         syserr("invalid argument to collect");
         break;
   }

   curpstate->statcount = 0;

   collecting = 1;

   /*
    * Sync the values (used by sweep) in the coexpr block for &current
    *  with the current values.
    */
   cp = k_current;
   cp->es_tend = tend;
   cp->es_pfp = pfp;
   cp->es_gfp = gfp;
   cp->es_efp = efp;
   cp->es_sp = sp;

   /*
    * First time through init quallist
    */
    if (!quallist) {
        Protect(quallist = malloc(qualsize), fatalerr(304, NULL));
        equallist = (dptr *)((char *)quallist + qualsize);
    }

   /*
    * Reset qualifier list.
    */
   qualfree = quallist;

   /*
    * Check for stack overflow if we are collecting from outside the system C stack.
    */
   do_checkstack = (k_current != rootpstate.K_main);

   for (prog = progs; prog; prog = prog->next)
       markprogram(prog);

   /*
    * Mark the cached s2 and s3 strings for map.
    */
   PostDescrip(maps2);                  /*  caution: the cached arguments of */
                                        /*  map may not be strings. */
   PostDescrip(maps3);
   PostDescrip(maps2u);
   PostDescrip(maps3u);

#ifdef Graphics
   /*
    * Mark file and list values for windows
    */
   {
     wsp ws;

     for (ws = wstates; ws ; ws = ws->next) {
         PostDescrip(ws->listp);
     }
   }
#endif					/* Graphics */

   /*
    * Mark the globals and the statics.
    */


   reclaim();

   /*
    * Turn off all the marks in all the block regions everywhere
    */
   { struct region *br;
   for (br = curblock->Gnext; br; br = br->Gnext) {
      char *source = br->base, *free = br->free;
      uword NoMark = (uword) ~F_Mark;
      while (source < free) {
	 BlkType(source) &= NoMark;
         source += BlkSize(source);
         }
      }
   for (br = curblock->Gprev; br; br = br->Gprev) {
      char *source = br->base, *free = br->free;
      uword NoMark = (uword) ~F_Mark;
      while (source < free) {
	 BlkType(source) &= NoMark;
         source += BlkSize(source);
         }
      }
   }

#ifdef EventMon
   if (!noMTevents) {
      mmrefresh();
      EVValD(&nulldesc, E_EndCollect);
      }
#endif					/* instrument allocation events */

   collecting = 0;
   }

/*
 * markprogram - traverse pointers out of a program state structure
 */

static void markprogram(pstate)
struct progstate *pstate;
   {
   struct descrip *dp;

   PostDescrip(pstate->eventmask);
   PostDescrip(pstate->opcodemask);
   PostDescrip(pstate->valuemask);
   PostDescrip(pstate->eventcode);
   PostDescrip(pstate->eventval);
   PostDescrip(pstate->eventsource);

   /* Kywd_err, &error, always an integer */
   /* Kywd_pos, &pos, always an integer */
   PostDescrip(pstate->Kywd_subject);
   PostDescrip(pstate->Kywd_prog);
   PostDescrip(pstate->Kywd_why);
   /* Kywd_ran, &random, always an integer */
   /* Kywd_trc, &trace, always an integer */

   /*
    * Mark the globals and the statics.
    */
   for (dp = pstate->Globals; dp < pstate->Eglobals; dp++)
      PostDescrip(*dp);

   for (dp = pstate->Statics; dp < pstate->Estatics; dp++)
      PostDescrip(*dp);

   for (dp = pstate->ClassStatics; dp < pstate->EClassStatics; dp++)
      PostDescrip(*dp);

   PostDescrip(pstate->K_errorvalue);
   PostDescrip(pstate->K_errortext);
   PostDescrip(pstate->T_errorvalue);
   PostDescrip(pstate->T_errortext);

   markptr((union block **)&pstate->K_main);
   markptr((union block **)&pstate->K_current);
}


/*
 * postqual - mark a string qualifier.  Strings outside the string space
 *  are ignored.
 */

static void postqual(dp)
dptr dp;
   {
   char *newqual;

   if (InRange(strbase,StrLoc(*dp),strfree + 1)) { 

      /*
       * The string is in the string space.  Add it to the string qualifier
       *  list, but before adding it, expand the string qualifier list if
       *  necessary.
       */
      if (qualfree >= equallist) {
	 /* reallocate a new qualifier list that's twice as large */
         Protect(newqual = realloc(quallist, 2 * qualsize), fatalerr(304, NULL));
         quallist = (dptr *)newqual;
         qualfree = (dptr *)(newqual + qualsize);
         qualsize *= 2;
         equallist = (dptr *)(newqual + qualsize);

         }
      *qualfree++ = dp;
      }
   }


static void markptr(union block **ptr)
{
    register dptr dp, lastdesc;
    register char *block, *endblock = 0;
    word type0, fdesc;
    int numptr, numdesc;
    register union block **ptr1, **lastptr;

    if (do_checkstack && DiffPtrsBytes(&type0, sp) < 4096)
        fatalerr(310, NULL);

    /*
     * Get the block to which ptr points.
     */
    block = (char *)*ptr;

    if (InRange(blkbase,block,blkfree)) {
        type0 = BlkType(block);
        if ((uword)type0 <= MaxType) {
            /*
             * The type is valid, which indicates that this block has not
             *  been marked.  Point endblock to the byte past the end
             *  of the block.
             */
            endblock = block + BlkSize(block);
        }

        /*
         * Add ptr to the back chain for the block and point the
         *  block (via the type field) to ptr.
         */
        *ptr = (union block *)type0;
        BlkType(block) = (uword)ptr;

        if ((uword)type0 <= MaxType) {
            /*
             * The block was not marked; process pointers and descriptors
             *  within the block.
             */
            if ((fdesc = firstp[type0]) > 0) {
                /*
                 * The block contains pointers; mark each pointer.
                 */
                ptr1 = (union block **)(block + fdesc);
                numptr = ptrno[type0];
                if (numptr > 0)
                    lastptr = ptr1 + numptr;
                else
                    lastptr = (union block **)endblock;
                for (; ptr1 < lastptr; ptr1++)
                    if (*ptr1 != NULL)
                        markptr(ptr1);
            }
            if ((fdesc = firstd[type0]) > 0) {
                /*
                 * The block contains descriptors; mark each descriptor.
                 */
                dp = (dptr)(block + fdesc);
                numdesc = descno[type0];
                if (numdesc > 0)
                    lastdesc = dp + numdesc;
                else
                    lastdesc = (dptr)endblock;
                for (; dp < lastdesc; dp++)
                    PostDescrip(*dp);
            }
        }
    }

    else if ((unsigned int)BlkType(block) == T_Coexpr) {
        struct b_coexpr *cp;

        /*
         * dp points to a co-expression block that has not been
         *  marked.  Point the block to dp.  Sweep the interpreter
         *  stack in the block.  Then mark the block for the
         *  activating co-expression and the refresh block.
         */
        BlkType(block) = (uword)ptr;
        cp = (struct b_coexpr *)block;

        sweep(cp);

        /*
         * Mark the activator of this co-expression.
         */
        if (cp->es_activator)
            markptr((union block **)&cp->es_activator);

        if (cp->freshblk)
            markptr((union block **)&cp->freshblk);
    }

    else {
        struct region *rp;

        /*
         * Look for this block in other allocated block regions.
         */
        for (rp = curblock->Gnext;rp;rp = rp->Gnext)
            if (InRange(rp->base,block,rp->free)) break;

        if (rp == NULL)
            for (rp = curblock->Gprev;rp;rp = rp->Gprev)
                if (InRange(rp->base,block,rp->free)) break;

        /*
         * If this block is not in a block region, its something else
         *  like a procedure block.
         */
        if (rp == NULL)
            return;

        /*
         * Get this block's type field; return if it is marked
         */
        type0 = BlkType(block);
        if ((uword)type0 > MaxType)
            return;

        /*
         * this is an unmarked block outside the (collecting) block region;
         * process pointers and descriptors within the block.
         *
         * The type is valid, which indicates that this block has not
         *  been marked.  Point endblock to the byte past the end
         *  of the block.
         */
        endblock = block + BlkSize(block);

        BlkType(block) |= F_Mark;			/* mark the block */

        if ((fdesc = firstp[type0]) > 0) {
            /*
             * The block contains pointers; mark each pointer.
             */
            ptr1 = (union block **)(block + fdesc);
            numptr = ptrno[type0];
            if (numptr > 0)
                lastptr = ptr1 + numptr;
            else
                lastptr = (union block **)endblock;
            for (; ptr1 < lastptr; ptr1++)
                if (*ptr1 != NULL)
                    markptr(ptr1);
        }
        if ((fdesc = firstd[type0]) > 0) {
            /*
             * The block contains descriptors; mark each descriptor.
             */
            dp = (dptr)(block + fdesc);
            numdesc = descno[type0];
            if (numdesc > 0)
                lastdesc = dp + numdesc;
            else
                lastdesc = (dptr)endblock;
            for (; dp < lastdesc; dp++)
                PostDescrip(*dp);
        }
    }
}


/*
 * sweep - sweep the chain of tended descriptors for a co-expression
 *  marking the descriptors.
 */

static void sweep(ce)
struct b_coexpr *ce;
{
    register struct tend_desc *tp;
    register int i;

    for (tp = ce->es_tend; tp != NULL; tp = tp->previous) {
        for (i = 0; i < tp->num; ++i) {
            /* We need an extra test for a null BlkLoc, since we may have an
             * uninitialized tended block pointer (set to nullptr)
             */
            if (Qual(tp->d[i]))
                postqual(&tp->d[i]);
            else if (Pointer(tp->d[i]) && BlkLoc(tp->d[i]))
                markptr(&BlkLoc(tp->d[i]));
        }
    }
    sweep_stk(ce);
}

/*
 * sweep_stk - sweep the stack, marking all descriptors there.  Method
 *  is to start at a known point, specifically, the frame that the
 *  fp points to, and then trace back along the stack looking for
 *  descriptors and local variables, marking them when they are found.
 *  The sp starts at the first frame, and then is moved down through
 *  the stack.  Procedure, generator, and expression frames are
 *  recognized when the sp is a certain distance from the fp, gfp,
 *  and efp respectively.
 *
 * Sweeping problems can be manifested in a variety of ways due to
 *  the "if it can't be identified it's a descriptor" methodology.
 */

static void sweep_stk(ce)
struct b_coexpr *ce;
   {
   register word *s_sp;
   register struct pf_marker *fp;
   register struct gf_marker *s_gfp;
   register struct ef_marker *s_efp;
   word nargs, type0 = 0, gsize = 0;

   /* The stack pointer may be null if a gc has been triggerred between allocating the
    * coexpression block and the refresh block (alcrefresh) - see Ocreate in lmisc.r
    */
   if (ce->es_sp == 0)
       return;

   fp = ce->es_pfp;
   s_gfp = ce->es_gfp;
   if (s_gfp != 0) {
      type0 = s_gfp->gf_gentype;
      if (type0 == G_Psusp)
         gsize = Wsizeof(*s_gfp);
      else
         gsize = Wsizeof(struct gf_smallmarker);
      }
   s_efp = ce->es_efp;
   s_sp =  ce->es_sp;
   nargs = 0;                           /* Nargs counter is 0 initially. */

   if (fp == 0) {
       /*
        * The argument list of an un-started program
        */
       PostDescrip(*(dptr)(s_sp - 1));
   }

   while ((fp != 0 || nargs)) {         /* Keep going until current fp is
                                            0 and no arguments are left. */
      if (s_sp == (word *)fp + Vwsizeof(*pfp) - 1) {
                                        /* sp has reached the upper
                                            boundary of a procedure frame,
                                            process the frame. */
         s_efp = fp->pf_efp;            /* Get saved efp out of frame */
         s_gfp = fp->pf_gfp;            /* Get save gfp */
         if (s_gfp != 0) {
            type0 = s_gfp->gf_gentype;
            if (type0 == G_Psusp)
               gsize = Wsizeof(*s_gfp);
            else
               gsize = Wsizeof(struct gf_smallmarker);
            }
         s_sp = (word *)fp - 1;         /* First argument descriptor is
                                            first word above proc frame */
         nargs = fp->pf_nargs;
         fp = fp->pf_pfp;
         }
      else if (s_gfp != NULL && s_sp == (word *)s_gfp + gsize - 1) {
                                        /* The sp has reached the lower end
                                            of a generator frame, process
                                            the frame.*/
         if (type0 == G_Psusp)
            fp = s_gfp->gf_pfp;
         s_sp = (word *)s_gfp - 1;
         s_efp = s_gfp->gf_efp;
         s_gfp = s_gfp->gf_gfp;
         if (s_gfp != 0) {
            type0 = s_gfp->gf_gentype;
            if (type0 == G_Psusp)
               gsize = Wsizeof(*s_gfp);
            else
               gsize = Wsizeof(struct gf_smallmarker);
            }
         nargs = 1;
         }
      else if (s_sp == (word *)s_efp + Wsizeof(*s_efp) - 1) {
                                            /* The sp has reached the upper
                                                end of an expression frame,
                                                process the frame. */
         s_gfp = s_efp->ef_gfp;         /* Restore gfp, */
         if (s_gfp != 0) {
            type0 = s_gfp->gf_gentype;
            if (type0 == G_Psusp)
               gsize = Wsizeof(*s_gfp);
            else
               gsize = Wsizeof(struct gf_smallmarker);
            }
         s_efp = s_efp->ef_efp;         /*  and efp from frame. */
         s_sp -= Wsizeof(*s_efp);       /* Move past expression frame marker. */
         }
      else {                            /* Assume the sp is pointing at a
                                            descriptor. */
         PostDescrip(*(dptr)(s_sp - 1));
         s_sp -= 2;                     /* Move past descriptor. */
         if (nargs)                     /* Decrement argument count if in an*/
            nargs--;                    /*  argument list. */
         }
      }
   }

/*
 * reclaim - reclaim space in the allocated memory regions. The marking
 *   phase has already been completed.
 */

static void reclaim()
   {
   /*
    * Collect available co-expression blocks.
    */
   cofree();

   /*
    * Collect the string space leaving it where it is.
    */
   scollect();

   /*
    * Adjust the blocks
    */
   adjust();

   /*
    * Compact the block region.
    */
   compact();
   }

/*
 * cofree - collect co-expression blocks.  This is done after
 *  the marking phase of garbage collection and the stacks that are
 *  reachable have pointers to data blocks, rather than T_Coexpr,
 *  in their type field.
 */

static void cofree()
   {
   register struct b_coexpr **ep, *xep;

   /*
    * The co-expression blocks are linked together through their
    *  nextstk fields, with stklist pointing to the head of the list.
    *  The list is traversed and each stack that was not marked
    *  is freed.  Note that the root progstate's main is the last
    *  on the list, and will always be marked (as are all &main
    *  co-expressions).
    */
   ep = &stklist;
   while (*ep != NULL) {
       if (BlkType(*ep) == T_Coexpr) {
           /* Only free blocks allocated by the program doing the collecting */
           if ((*ep)->creator == curpstate) {
               /* Deduct memory freed - the size must be stksize as we never release programs (see alccoexp) */
               (*ep)->creator->statcurr -= stksize;
               xep = *ep;
               *ep = (*ep)->nextstk;
         #ifdef HAVE_COCLEAN
               coclean(xep->cstate);
         #endif                         /* CoClean */
               free(xep);
           } else
               ep = &(*ep)->nextstk;
       }
       else {
           BlkType(*ep) = T_Coexpr;
           ep = &(*ep)->nextstk;
       }
   }
}

/*
 * scollect - collect the string space.  quallist is a list of pointers to
 *  descriptors for all the reachable strings in the string space.  For
 *  ease of description, it is referred to as if it were composed of
 *  descriptors rather than pointers to them.
 */

static void scollect()
   {
   register char *source, *dest;
   register dptr *qptr;
   char *cend;

   if (qualfree <= quallist) {
      /*
       * There are no accessible strings.  Thus, there are none to
       *  collect and the whole string space is free.
       */
      strfree = strbase;
      return;
      }
   /*
    * Sort the pointers on quallist in ascending order of string
    *  locations.
    */
   qsort((char *)quallist, (int)(DiffPtrs((char *)qualfree,(char *)quallist)) /
     sizeof(dptr *), sizeof(dptr), (QSortFncCast)qlcmp);
   /*
    * The string qualifiers are now ordered by starting location.
    */
   dest = strbase;
   source = cend = StrLoc(**quallist);

   /*
    * Loop through qualifiers for accessible strings.
    */
   for (qptr = quallist; qptr < qualfree; qptr++) {
      if (StrLoc(**qptr) > cend) {

         /*
          * qptr points to a qualifier for a string in the next clump.
          *  The last clump is moved, and source and cend are set for
          *  the next clump.
          */
         while (source < cend)
            *dest++ = *source++;
         source = cend = StrLoc(**qptr);
         }
      if ((StrLoc(**qptr) + StrLen(**qptr)) > cend)
         /*
          * qptr is a qualifier for a string in this clump; extend
          *  the clump.
          */
         cend = StrLoc(**qptr) + StrLen(**qptr);
      /*
       * Relocate the string qualifier.
       */
      StrLoc(**qptr) = StrLoc(**qptr) + DiffPtrs(dest,source);
      }

   /*
    * Move the last clump.
    */
   while (source < cend)
      *dest++ = *source++;
   strfree = dest;
   }

/*
 * qlcmp - compare the location fields of two string qualifiers for qsort.
 */

static int qlcmp(dptr *q1, dptr *q2)
   {
#if IntBits == WordBits
   return (int)DiffPtrs(StrLoc(**q1),StrLoc(**q2));
#else
   long l = (long)DiffPtrs(StrLoc(**q1),StrLoc(**q2));
   if (l < 0)
      return -1;
   else if (l > 0)
      return 1;
   else
      return 0;
#endif

   }

/*
 * adjust - adjust pointers into the block region.  (Phase II of
 * garbage collection.)
 */

static void adjust()
   {
   register union block **nxtptr, **tptr;
   register char *source = blkbase, *dest;

   /*
    * Start dest at source.
    */
   dest = source;

   /*
    * Loop through to the end of allocated block region, moving source
    *  to each block in turn and using the size of a block to find the
    *  next block.
    */
   while (source < blkfree) {
      if ((uword)(nxtptr = (union block **)BlkType(source)) > MaxType) {

         /*
          * The type field of source is a back pointer.  Traverse the
          *  chain of back pointers, changing each block location from
          *  source to dest.
          */
         while ((uword)nxtptr > MaxType) {
            tptr = nxtptr;
            nxtptr = (union block **) *nxtptr;
            *tptr = (union block *)dest;
            }
         BlkType(source) = (uword)nxtptr | F_Mark;
         dest += BlkSize(source);
         }
      source += BlkSize(source);
      }
   }

/*
 * compact - compact good blocks in the block region. (Phase III of garbage
 *  collection.)
 */

static void compact()
   {
   register word size;
   register char *source = blkbase, *dest;

   /*
    * Start dest at source.
    */
   dest = source;

   /*
    * Loop through to end of allocated block space, moving source
    *  to each block in turn, using the size of a block to find the next
    *  block.  If a block has been marked, it is copied to the
    *  location pointed to by dest and dest is pointed past the end
    *  of the block, which is the location to place the next saved
    *  block.  Marks are removed from the saved blocks.
    */
   while (source < blkfree) {
      size = BlkSize(source);
      if (BlkType(source) & F_Mark) {
         BlkType(source) &= ~F_Mark;
         if (source != dest)
             memmove(dest, source, size);
         dest += size;
         }
      source += size;
      }

   /*
    * dest is the location of the next free block.  Now that compaction
    *  is complete, point blkfree to that location.
    */
   blkfree = dest;
   }



/*
 * descr - dump a descriptor.  Used only for debugging.
 */

void descr(dp)
dptr dp;
   {
   int i;

   fprintf(stderr,"%08lx: ",(long)dp);
   if (Qual(*dp))
      fprintf(stderr,"%15s","qualifier");

   else if (Var(*dp))
      fprintf(stderr,"%15s","variable");
   else {
      i =  Type(*dp);
      switch (i) {
         case T_Null:
            fprintf(stderr,"%15s","null");
            break;
         case T_Integer:
            fprintf(stderr,"%15s","integer");
            break;
         default:
            fprintf(stderr,"%15s",blkname[i]);
         }
      }
   fprintf(stderr," %08lx %08lx\n",(long)dp->dword,(long)IntVal(*dp));
   }

/*
 * blkdump - dump the allocated block region.  Used only for debugging.
 *   NOTE:  Not adapted for multiple regions.
 */

void blkdump()
   {
   register char *blk;
   register word type0, size, fdesc;
   register dptr ndesc;

   fprintf(stderr,
      "\nDump of allocated block region.  base:%08lx free:%08lx max:%08lx\n",
         (long)blkbase,(long)blkfree,(long)blkend);
   fprintf(stderr,"  loc     type              size  contents\n");

   for (blk = blkbase; blk < blkfree; blk += BlkSize(blk)) {
      type0 = BlkType(blk);
      size = BlkSize(blk);
      fprintf(stderr," %08lx   %15s   %4ld\n",(long)blk,blkname[type0],
         (long)size);
      if ((fdesc = firstd[type0]) > 0)
         for (ndesc = (dptr)(blk + fdesc);
               ndesc < (dptr)(blk + size); ndesc++) {
            fprintf(stderr,"                                 ");
            descr(ndesc);
            }
      fprintf(stderr,"\n");
      }
   fprintf(stderr,"end of block region.\n");
   }

void show_regions()
{
   struct region *br;

   printf("Type            Addr         Size         Base         End          Free     End-Free\n");

   br = curblock;
   while (br->Gprev)
       br = br->Gprev;
   for (; br; br = br->Gnext) {
       printf("Block   %12p %12ld %12p %12p %12p %12ld\n",
              br, (long)br->size, br->base, br->end, br->free, (long)(br->end-br->free));
   }

   br = curstring;
   while (br->Gprev)
       br = br->Gprev;
   for (; br; br = br->Gnext) {
       printf("String  %12p %12ld %12p %12p %12p %12ld\n",
              br, (long)br->size, br->base, br->end, br->free, (long)(br->end-br->free));
   }
}


longlong physicalmemorysize()
{
#if UNIX
#define TAG "MemTotal: "
    FILE *f = fopen("/proc/meminfo", "r");
    longlong i = 0;
    if (f) {
        char buf[80], *p;
        while (fgets(buf, 80, f)) {
            if (!strncmp(TAG, buf, strlen(TAG))) {
                p = buf+strlen(TAG);
                while (isspace(*p)) p++;
                i = atol(p);
                while (isdigit(*p)) p++;
                while (isspace(*p)) p++;
                if (!strncmp(p, "kB",2)) i *= 1024;
                else if (!strncmp(p, "MB", 2)) i *= 1024 * 1024;
                break;
	    }
        }
        fclose(f);
    }
    return i;
#elif MSWIN32
    MEMORYSTATUS ms;
    GlobalMemoryStatus(&ms);
    return ms.dwTotalPhys;
#else					/* MSWIN32 */
    return 0;
#endif					/* MSWIN32 */
}
