/*
 * file: lmisc.r
 *   Contents: [O]create, activate
 */

/*
 * create - return an entry block for a co-expression.
 */

int Ocreate(entryp, cargp)
word *entryp;
register dptr cargp;
   {

   tended struct b_coexpr *sblkp;
   register dptr dp, ndp;
   int na, nl, i;

   struct b_proc *cproc;

   /* cproc is the Icon procedure that create occurs in */
   cproc = (struct b_proc *)BlkLoc(argp[0]);

   /*
    * Calculate number of arguments and number of local variables.
    */
   na = pfp->pf_nargs + 1;  /* includes Arg0 */
   nl = (int)cproc->ndynam;

   /*
    * Get a new co-expression stack and initialize.
    */

   MemProtect(sblkp = alccoexp(0, 0));

   /*
    * Get a refresh block for the new co-expression.
    */
   MemProtect(sblkp->freshblk = alcrefresh(entryp, na, nl));

   /*
    * Copy current procedure frame marker into refresh block.
    */
   sblkp->freshblk->pfmkr = *pfp;
   sblkp->freshblk->pfmkr.pf_pfp = 0;

   /*
    * Copy arguments into refresh block.
    */
   ndp = sblkp->freshblk->elems;
   dp = argp;
   for (i = 1; i <= na; i++)
      *ndp++ = *dp++;

   /*
    * Copy locals into the refresh block.
    */
   dp = &(pfp->pf_locals)[0];
   for (i = 1; i <= nl; i++)
      *ndp++ = *dp++;

   /*
    * Use the refresh block to finish initializing the co-expression stack.
    */
   co_init(sblkp);

   /*
    * Return the new co-expression.
    */
   Arg0.dword = D_Coexpr;
   BlkLoc(Arg0) = (union block *) sblkp;
   Return;

   }

/*
 * activate - activate a co-expression.
 */
int activate(val, ncp, result)
dptr val;
struct b_coexpr *ncp;
dptr result;
   {

   int first;

   /*
    * Set activator in new co-expression.
    */
   if (ncp->es_activator == NULL)
      first = 0;
   else
      first = 1;
   ncp->es_activator = (struct b_coexpr *)BlkLoc(k_current);

   if (co_chng(ncp, val, result, A_Coact, first) == A_Cofail)
      return A_Resume;
   else
      return A_Continue;

   }
