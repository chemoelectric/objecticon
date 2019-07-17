/*
 * File: rmemmgt.r
 */


/*
 * Prototypes
 */
static void qual_clear   (void);
static void postqual     (dptr dp);
static void qual_dispose (void);
static void markptr      (union block **ptr);
static void sweep_tended (void);
static void reclaim      (void);
static void scollect     (void);
static int  qlcmp        (dptr  *q1,dptr  *q2);
static void adjust       (void);
static void compact      (void);
static void mark_program (struct progstate *pstate);
static void sweep_stack  (struct frame *f);
static void unmark_region(struct region *br);
static void free_stack   (struct b_coexpr *c);
static union block **stk_get(void);
static void stk_add(union block **ptr);
static void stk_clear(void);
static void stk_dispose(void);
static void stk_markptrs(void);
static void do_weakrefs(void);
static void mark_others(void);


/* string qualifier list */
static struct {
   uword listsize;
   dptr *list, *elist, *free;
} qual;

int collecting;                        /* flag indicating whether collection in progress */
int collected;                         /* global collection count of all collections */

static struct b_weakref *weakrefs;     /* head of list of weakrefs encountered during mark phase */

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
#if RealInDesc
     -1,                      /* T_Real (3), real number, not block */
#else
     sizeof(struct b_real),   /* T_Real (3), real number */
#endif
     0,                       /* T_Cset (4), cset */
     sizeof(struct b_constructor), /* T_Constructor (5), record constructor */
     sizeof(struct b_proc),        /* T_Proc (6), procedure block */
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
     sizeof(struct b_methp),  /* T_Methp (17), method pointer */
     sizeof(struct b_coexpr), /* T_Coexpr (18), co-expression block */
     0,                       /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     sizeof(struct b_class),  /* T_Class (25), class */
     0,                       /* T_Object (26), object */
     -1,                      /* T_Kywdhandler (27), error handler keyword variable */
     sizeof(struct b_weakref),/* T_Weakref (28), weak reference block */
    -1,                       /* T_Yes (29), not block */
    };

/*
 * Table of offsets (in bytes) to first descriptor in blocks.  -1 is for
 *  types not allocated, 0 for blocks with no descriptors.
 */
int firstd[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
     0,                       /* T_Lrgint (2), large integer */
#if RealInDesc
     -1,                      /* T_Real (3), real number, not block */
#else
     0,                       /* T_Real (3), real number */
#endif
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
     2*WordSize,              /* T_Tvtbl (14), table element trapped variable */
     0,                       /* T_Slots (15), set/table hash block */
     3*WordSize,              /* T_Tvsubs (16), substring trapped variable */
     0,                       /* T_Methp (17), methp */
    -1,                       /* T_Coexpr (18), co-expression block */
     3*WordSize,              /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     -1,                      /* T_Class (25), class, just contains static data in icode */
     5*WordSize,              /* T_Object (26), object */
     -1,                      /* T_Kywdhandler (27), error handler keyword variable */
     0,                       /* T_Weakref (28), weak reference block */
    -1,                       /* T_Yes (29), not block */
    };

/*
 * Table of offsets (in bytes) to first pointer in blocks.  -1 is for
 *  types not allocated, 0 for blocks with no pointers.
 */
int firstp[] = {
    -1,                       /* T_Null (0), not block */
    -1,                       /* T_Integer (1), not block */
     0,                       /* T_Lrgint (2), large integer */
#if RealInDesc
     -1,                      /* T_Real (3), real number, not block */
#else
     0,                       /* T_Real (3), real number */
#endif
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
     2*WordSize,              /* T_Methp (17), methp */
    -1,                       /* T_Coexpr (18), co-expression block */
     0,                       /* T_Ucs (19), unicode string */
     -1,                      /* T_Kywdint (20), integer keyword variable */
     -1,                      /* T_Kywdpos (21), keyword &pos */
     -1,                      /* T_Kywdsubj (22), keyword &subject */
     -1,                      /* T_Kywdstr (23), string keyword variable */
     -1,                      /* T_Kywdany (24), event keyword variable */
     -1,                      /* T_Class (25), class, just contains static data in icode */
     0,                       /* T_Object (26), object, just a pointer to the class, which is static */
     -1,                      /* T_Kywdhandler (27), error handler keyword variable */
     0,                       /* T_Weakref (28), weak reference block */
    -1,                       /* T_Yes (29), not block */
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
     1,                       /* T_Methp (17), method pointer */
    -1,                       /* T_Coexpr (18), co-expression block */
    -1,                       /* T_Ucs (19), unicode string */
    -1,                       /* T_Kywdint (20), integer keyword variable */
    -1,                       /* T_Kywdpos (21), keyword &pos */
    -1,                       /* T_Kywdsubj (22), keyword &subject */
    -1,                       /* T_Kywdstr (23), string keyword variable */
    -1,                       /* T_Kywdany (24), event keyword variable */
    -1,                       /* T_Class (25), class */
    -1,                       /* T_Object (26), object */
    -1,                       /* T_Kywdhandler (27), error handler keyword variable */
    -1,                       /* T_Weakref (28), weak reference block */
    -1,                       /* T_Yes (29), not block */
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
    -1,                       /* T_Methp (17), methp */
    -1,                       /* T_Coexpr (18), co-expression block */
     1,                       /* T_Ucs (19), unicode string */
    -1,                       /* T_Kywdint (20), integer keyword variable */
    -1,                       /* T_Kywdpos (21), keyword &pos */
    -1,                       /* T_Kywdsubj (22), keyword &subject */
    -1,                       /* T_Kywdstr (23), string keyword variable */
    -1,                       /* T_Kywdany (24), event keyword variable */
    -1,                       /* T_Class (25), class, just contains static data in icode */
     0,                       /* T_Object (26), object */
    -1,                       /* T_Kywdhandler (27), error handler keyword variable */
    -1,                       /* T_Weakref (28), weak reference block */
    -1,                       /* T_Yes (29), not block */
};

/*
 * Table of block names used by debugging functions.
 */
char *blkname[] = {
   "illegal object",                    /* T_Null (0), not block */
   "illegal object",                    /* T_Integer (1), not block */
   "large integer",                     /* T_Largint (2) */
#if RealInDesc
   "illegal object",                    /* T_Real (3), not block */
#else
   "real number",                       /* T_Real (3) */
#endif
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
   "methp",                             /* T_Methp (17) */
   "co-expression",                     /* T_Coexpr (18) */
   "ucs",                               /* T_Ucs (19), unicode string */
   "integer keyword variable",          /* T_Kywdint (20) */
   "&pos",                              /* T_Kywdpos (21) */
   "&subject",                          /* T_Kywdsubj (22) */
   "illegal object",                    /* T_Kywdstr (23) */
   "illegal object",                    /* T_Kywdany (24) */
   "class",                             /* T_Class (25) */
   "object",                            /* T_Object (26) */
   "&handler",                          /* T_Kywdhandler (27), error handler keyword variable */
   "weak reference",                    /* T_Weakref (28), weak reference block */
   "illegal object",                    /* T_Yes (29), not block */
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
      stk_add(&BlkLoc(d));


 /*
  * A table of additional descriptors which are traversed during
  * garbage collection.
  */
struct dptr_list *og_hash[OGHASH_SIZE];

#if 0
static void dump_gc_global()
{
    int i;
    struct dptr_list *dl;
    for (i = 0; i < ElemCount(og_hash); ++i) {
        printf("Bucket %d\n", i);
        for (dl = og_hash[i]; dl; dl = dl->next) {
            printf("\tEntry %p = ", dl->dp);
            print_desc(stdout, dl->dp);
            printf("\n");
        }
    }
    printf("=============\n");
}
#endif

void dptr_list_add(struct dptr_list **head, dptr d)
{
    struct dptr_list *dl;
    dl = safe_malloc(sizeof(struct dptr_list));
    dl->dp = d;
    dl->next = *head;
    *head = dl;
}

void dptr_list_rm(struct dptr_list **head, dptr d)
{
    struct dptr_list *dl;
    while ((dl = *head) && dl->dp != d)
        head = &dl->next;
    if (!dl)
        syserr("dptr_list_rm: dptr not found in list");
    *head = dl->next;
    free(dl);
}

void add_gc_global(dptr d)
{
    int i = ptrhasher(d, og_hash);
    dptr_list_add(&og_hash[i], d);
}

void del_gc_global(dptr d)
{
    int i = ptrhasher(d, og_hash);
    dptr_list_rm(&og_hash[i], d);
}

static void mark_others()
{
   struct dptr_list *dl;
   int i;
   for (i = 0; i < ElemCount(og_hash); ++i)
       for (dl = og_hash[i]; dl; dl = dl->next)
           PostDescrip(*dl->dp);
}

/*
 * collect - do a garbage collection of currently active regions.
 */

void collect(int region)
{
   struct progstate *prog;
   struct region *br;

   EVVal((word)region,E_Collect);

   switch (region) {
      case User:
         curpstate->collected_user++;
         break;
      case Strings:
         curpstate->collected_string++;
         break;
      case Blocks:  
         curpstate->collected_block++;
         break;
      case Stack:  
         curpstate->collected_stack++;
         break;
       default:
         syserr("invalid argument to collect");
         break;
   }

   collecting = 1;
   ++collected;

   /*
    * Reset qualifier list.
    */
   qual_clear();

   /*
    * Reset/init stk
    */
   stk_clear();

   weakrefs = 0;

   for (prog = progs; prog; prog = prog->next)
       mark_program(prog);

   stk_add((union block **)&k_current);

   /*
    * Sweep the tended list on the C stack.
    */
   sweep_tended();

   /* Mark any other global descriptors which have been noted. */
   mark_others();

   /* Process all block ptrs */
   stk_markptrs();

   /* Process weakref list */
   do_weakrefs();

   reclaim();

   /*
    * Turn off all the marks in all the block regions everywhere.  We
    * also release any stack frames of unmarked coexpression blocks we
    * encounter.
    */
   for (br = curblock->Gnext; br; br = br->Gnext)
       unmark_region(br);
   for (br = curblock->Gprev; br; br = br->Gprev)
       unmark_region(br);

   /* Free memory used by the pointer stack and the qualifier list. */
   stk_dispose();
   qual_dispose();

   collecting = 0;

   EVValD(&nulldesc, E_EndCollect);

}

static void free_stack(struct b_coexpr *c)
{
    struct frame *f = c->sp;
    while (f) {
        struct frame *t = f;
        f = f->parent_sp;
        free_frame(t);
    }
}

static void unmark_region(struct region *br)
{
    char *source = br->base, *free = br->free;
    while (source < free) {
        if (BlkType(source) == T_Coexpr) {
            /* Free the unreferenced coexpression's stack */
            struct b_coexpr *c = (struct b_coexpr *)source;
            if (c->sp) {
                free_stack(c);
                c->sp = 0;
                c->curr_pf = c->base_pf = 0;
            }
        } else
            BlkType(source) &= ~F_Mark;
        source += BlkSize(source);
    }
}


/*
 * mark_program - traverse pointers out of a program state structure
 */

static void mark_program(struct progstate *pstate)
{
    struct descrip *dp;
    struct prog_event *pe;
    struct dptr_list *dl;

    stk_add((union block **)&pstate->eventmask);
    for (pe = pstate->event_queue_head; pe; pe = pe->next) {
        PostDescrip(pe->eventcode);
        PostDescrip(pe->eventval);
    }

    /* Kywd_err, &error, always an integer */
    /* Kywd_pos, &pos, always an integer */
    PostDescrip(pstate->Kywd_handler);
    PostDescrip(pstate->Kywd_subject);
    PostDescrip(pstate->Kywd_prog);
    PostDescrip(pstate->Kywd_why);
    /* Kywd_ran, &random, always an integer */
    /* Kywd_trace, &trace, always an integer */

    /*
     * Mark the globals and the statics.
     */
    for (dl = pstate->global_vars; dl; dl = dl->next)
        PostDescrip(*dl->dp);

    for (dp = pstate->Statics; dp < pstate->Estatics; dp++)
        PostDescrip(*dp);

    for (dp = pstate->TCaseTables; dp < pstate->ETCaseTables; dp++)
        PostDescrip(*dp);

    for (dp = pstate->ClassStatics; dp < pstate->EClassStatics; dp++)
        PostDescrip(*dp);

    PostDescrip(pstate->K_errorvalue);
    PostDescrip(pstate->K_errortext);
    PostDescrip(pstate->T_errorvalue);
    PostDescrip(pstate->T_errortext);
    if (pstate->K_errorcoexpr)
        stk_add((union block **)&pstate->K_errorcoexpr);

    stk_add((union block **)&pstate->K_main);
    stk_add((union block **)&pstate->K_current);
}

static void qual_clear()
{
   /*
    * First time through init qual.list
    */
    if (!qual.list) {
        qual.listsize = 1024;
        Protect(qual.list = malloc(qual.listsize * sizeof(dptr)), fatalerr(304, NULL));
        qual.elist = qual.list + qual.listsize;
    }

   qual.free = qual.list;
}

static void qual_dispose()
{
    free(qual.list);
    qual.list = qual.elist = qual.free = 0;
    qual.listsize = 0;
}

/*
 * postqual - mark a string qualifier.  Strings outside the string space
 *  are ignored.
 */
static void postqual(dptr dp)
{
    if (InRange(strbase,StrLoc(*dp),strfree + 1)) { 

        /*
         * The string is in the string space.  Add it to the string qualifier
         *  list, but before adding it, expand the string qualifier list if
         *  necessary.
         */
        if (qual.free == qual.elist) {
            /* reallocate a new qualifier list that's twice as large */
            Protect(qual.list = realloc(qual.list, 2 * qual.listsize * sizeof(dptr)), fatalerr(304, NULL));
            qual.free = qual.list + qual.listsize;
            qual.listsize *= 2;
            qual.elist = qual.list + qual.listsize;
        }
        *qual.free++ = dp;
    }
}

/*
 * Structure for holding a stack of union block ** items.
 */
static struct {
   uword bufsize;
   union block ***buf, ***ebuf, ***top;
} stk;

/* Get from stack, assumes it's not empty */
static union block **stk_get()
{
    return *--stk.top;
}

/* Reset pointer stack */
static void stk_clear()
{
    if (!stk.buf) {
        stk.bufsize = 1024;
        Protect(stk.buf = malloc(stk.bufsize * sizeof(union block **)), fatalerr(306, NULL));
        stk.ebuf = stk.buf + stk.bufsize;
    }
    stk.top = stk.buf;
}

/* Add to pointer stack */
static void stk_add(union block **ptr)
{
    if (stk.top == stk.ebuf) {
        Protect(stk.buf = realloc(stk.buf, stk.bufsize * 2 * sizeof(union block **)), fatalerr(306, NULL));
        stk.top = stk.buf + stk.bufsize;
        stk.bufsize *= 2;
        stk.ebuf = stk.buf + stk.bufsize;
    }
    *stk.top++ = ptr;
}

/* Process pointers in stack until it's empty */
static void stk_markptrs()
{
    while (stk.top != stk.buf)
        markptr(stk_get());
}

/* Free the memory used by the stack */
static void stk_dispose()
{
    free(stk.buf);
    stk.buf = stk.ebuf = stk.top = 0;
    stk.bufsize = 0;
}

static void do_weakrefs()
{
    while (weakrefs) {
        struct b_weakref *t = weakrefs;
        union block **ptr = &BlkLoc(t->val);
        char *block = (char *)*ptr;
        word type0 = BlkType(block);
        if ((uword)type0 > MaxType) {
            /*
             * The block was marked, so it remains referenced.  If in
             * the collecting region, add the pointer to the pointer
             * list as we would have done if we had processed it
             * earlier in markptr().
             */
            if (InRange(blkbase, block, blkfree)) {
                *ptr = (union block *)type0;
                BlkType(block) = (uword)ptr;
            }
        } else {
            /*
             * The block was not marked, therefore this is the last
             * reference to it, so we delete that reference.
             */
            t->val = nulldesc;
        }
        weakrefs = weakrefs->chain;
        t->chain = 0;
    }
}

static void markptr(union block **ptr)
{
    dptr dp, lastdesc;
    char *block, *endblock = 0;
    word type0, fdesc;
    int numptr, numdesc;
    union block **ptr1, **lastptr;

    /*
     * Get the block to which ptr points.
     */
    block = (char *)*ptr;

    if (InRange(blkbase, block, blkfree)) {
        type0 = BlkType(block);
        if ((uword)type0 > MaxType) {
            /*
             * The type is not valid, which indicates that this block
             * has been marked.  Just add ptr to the back chain for
             * the block and point the block (via the type field) to
             * ptr.
             */
            *ptr = (union block *)type0;
            BlkType(block) = (uword)ptr;
            return;
        }

        /*
         * The type is valid, which indicates that this block has not
         * been marked.  Point endblock to the byte past the end
         * of the block.
         */
        endblock = block + BlkSize(block);

        /*
         * Add ptr to the back chain for the block and point the
         *  block (via the type field) to ptr.
         */
        *ptr = (union block *)type0;
        BlkType(block) = (uword)ptr;
    }
    else {
        struct region *rp;

        /*
         * Look for this block in other allocated block regions.
         */
        for (rp = curblock->Gnext;rp;rp = rp->Gnext)
            if (InRange(rp->base, block, rp->free)) break;

        if (rp == NULL)
            for (rp = curblock->Gprev;rp;rp = rp->Gprev)
                if (InRange(rp->base, block, rp->free)) break;

        /*
         * If this block is not in a block region, it's something else
         * like a procedure block.
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
         * This is an unmarked block outside the (collecting) block region;
         * process pointers and descriptors within the block.
         *
         * The type is valid, which indicates that this block has not
         * been marked.  Point endblock to the byte past the end
         * of the block.
         */
        endblock = block + BlkSize(block);

        BlkType(block) |= F_Mark;			/* mark the block */
    }

    /*
     * If we have fallen through to here, we have a block in a block
     * region, which has not yet been processed.
     */
    switch (type0) {
        case T_Coexpr: {
            struct b_coexpr *cp = (struct b_coexpr *)block;
            /*
             * Mark the activator of this co-expression.
             */
            if (cp->activator)
                stk_add((union block **)&cp->activator);
            /*
             * Mark its stack
             */
            sweep_stack(cp->sp);
            break;
        }
        case T_Weakref: {
            struct b_weakref *wr = (struct b_weakref *)block;
            /*
             * If it's a "dead" weakref, do nothing, otherwise add the
             * block to the list of weakrefs; they are processed last.
             */
            if (!is:null(wr->val)) {
                wr->chain = weakrefs;
                weakrefs = wr;
            }
            break;
        }
        default: {
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
                        stk_add(ptr1);
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
            break;
        }
    }
}

static void sweep_stack(struct frame *f)
{
    int i;
    while (f) {
        switch (f->type) {
            case C_Frame: {
                struct c_frame *cf = (struct c_frame *)f;
                for (i = 0; i < cf->nargs; ++i)
                    PostDescrip(cf->args[i]);
                for (i = 0; i < cf->proc->ntend; ++i)
                    PostDescrip(cf->tend[i]);
                break;
            }
            case P_Frame: {
                struct p_frame *pf = (struct p_frame *)f;
                struct frame_vars *l = pf->fvars;
                for (i = 0; i < pf->proc->ntmp; ++i)
                    PostDescrip(pf->tmp[i]);
                if (l && l->seen != collected) {
                    dptr d;
                    l->seen = collected;
                    for (d = l->desc; d < l->desc_end; ++d)
                        PostDescrip(*d);
                }
                break;
            }
            default:
                syserr("Unknown frame type");
        }

        f = f->parent_sp;
    }
}


/*
 * sweep - sweep the chain of tended descriptors
 */

static void sweep_tended()
{
    struct tend_desc *tp;
    int i;

    for (tp = tendedlist; tp != NULL; tp = tp->previous) {
        for (i = 0; i < tp->num; ++i) {
            PostDescrip(tp->d[i]);
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
 * scollect - collect the string space.  qual.list is a list of pointers to
 *  descriptors for all the reachable strings in the string space.  For
 *  ease of description, it is referred to as if it were composed of
 *  descriptors rather than pointers to them.
 */

static void scollect()
{
    char *source, *dest;
    dptr *qptr;
    char *cend;
    uword size;

    ++curstring->compacted;

    if (qual.free == qual.list) {
        /*
         * There are no accessible strings.  Thus, there are none to
         *  collect and the whole string space is free.
         */
        strfree = strbase;
        return;
    }
    /*
     * Sort the pointers on qual.list in ascending order of string
     *  locations.
     */
    qsort(qual.list, qual.free - qual.list, sizeof(dptr), (QSortFncCast)qlcmp);

    /*
     * The string qualifiers are now ordered by starting location.
     */
    dest = strbase;
    source = cend = StrLoc(**qual.list);

    /*
     * Loop through qualifiers for accessible strings.
     */
    for (qptr = qual.list; qptr < qual.free; qptr++) {
        if (StrLoc(**qptr) > cend) {

            /*
             * qptr points to a qualifier for a string in the next clump.
             *  The last clump is moved, and source and cend are set for
             *  the next clump.
             */
            size = UDiffPtrs(cend, source);
            if (source != dest)
                memmove(dest, source, size);
            dest += size;
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
        StrLoc(**qptr) += DiffPtrs(dest,source);
    }

    /*
     * Move the last clump.
     */
    size = UDiffPtrs(cend, source);
    if (source != dest)
        memmove(dest, source, size);
    dest += size;

    strfree = dest;
}

/*
 * qlcmp - compare the location fields of two string qualifiers for qsort.
 */

static int qlcmp(dptr *q1, dptr *q2)
{
#if IntBits == WordBits
    return DiffPtrs(StrLoc(**q1),StrLoc(**q2));
#else
    word l = DiffPtrs(StrLoc(**q1),StrLoc(**q2));
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
    union block **nxtptr, **tptr;
    char *source = blkbase, *dest;

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
    uword size;
    char *source = blkbase, *dest;

    ++curblock->compacted;

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
        } else {
            if (BlkType(source) == T_Coexpr) {
                /* Free the coexpression's stack */
                free_stack((struct b_coexpr *)source);
            }
        }
        source += size;
    }

    /*
     * dest is the location of the next free block.  Now that compaction
     *  is complete, point blkfree to that location.
     */
    blkfree = dest;
}


void show_regions()
{
   struct region *br;

   printf("Type            Addr         Size         Base         End          Free     End-Free\n");

   br = curblock;
   while (br->Gprev)
       br = br->Gprev;
   for (; br; br = br->Gnext) {
       printf("Block   %12p %12" UWordFmtCh " %12p %12p %12p %12" UWordFmtCh "\n",
              br, br->size, br->base, br->end, br->free, (uword)(br->end-br->free));
   }

   br = curstring;
   while (br->Gprev)
       br = br->Gprev;
   for (; br; br = br->Gnext) {
       printf("String  %12p %12" UWordFmtCh " %12p %12p %12p %12" UWordFmtCh "\n",
              br, br->size, br->base, br->end, br->free, (uword)(br->end-br->free));
   }
}


uint64_t physicalmemorysize()
{
#if UNIX
#define TAG "MemTotal: "
    FILE *f = fopen("/proc/meminfo", "r");
    uint64_t i = 0;
    if (f) {
        char buf[80], *p;
        while (fgets(buf, sizeof(buf), f)) {
            if (!strncmp(TAG, buf, strlen(TAG))) {
                p = buf+strlen(TAG);
                while (oi_isspace(*p)) p++;
                i = atol(p);
                while (oi_isdigit(*p)) p++;
                while (oi_isspace(*p)) p++;
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

void test_collect(int time_interval, long call_interval, int quiet)
{
    static long secs;
    static long call_count, sampled_interval;
    struct timeval tp;

    ++call_count;

    if (sampled_interval)
        call_interval = sampled_interval;

    if (call_interval > 0) {
        if (call_count == call_interval) {
            if (!quiet)
                fprintf(stderr, "test_collect: collection start at call_count=%ld\n", call_count);fflush(stderr);
            collect(User);
            if (!quiet)
                fprintf(stderr, "test_collect: collection end\n");fflush(stderr);
            call_count = 0;
        }
        return;
    }

    if (gettimeofday(&tp, 0) < 0) {
        fprintf(stderr, "test_collect: gettimeofday failed\n");fflush(stderr);
        return;
    }
    if (secs == 0) {
        secs = tp.tv_sec + time_interval;
        return;
    }
    if (tp.tv_sec > secs) {
        sampled_interval = call_count + 1;
    }
}
