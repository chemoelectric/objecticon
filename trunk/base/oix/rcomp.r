/*
 * File: rcomp.r
 *  Contents: anycmp, equiv, lexcmp
 */

/*
 * anycmp - compare any two objects.
 */

int anycmp(dp1,dp2)
dptr dp1, dp2;
   {
   register int o1, o2;
   register long v1, v2, lresult;
   int iresult;
   double rres1, rres2, rresult;

   /*
    * Get a collating number for dp1 and dp2.
    */
   o1 = order(dp1);
   o2 = order(dp2);

   /*
    * If dp1 and dp2 aren't of the same type, compare their collating numbers.
    */
   if (o1 != o2)
      return (o1 > o2 ? Greater : Less);

   if (o1 == 3)
      /*
       * dp1 and dp2 are strings, use lexcmp to compare them.
       */
      return lexcmp(dp1,dp2);

   switch (Type(*dp1)) {


      case T_Integer:
	 if (Type(*dp2) != T_Lrgint) {
            v1 = IntVal(*dp1);
            v2 = IntVal(*dp2);
            if (v1 < v2)
               return Less;
            else if (v1 == v2)
               return Equal;
            else
               return Greater;
            }
	 /* if dp2 is a Lrgint, flow into next case */

      case T_Lrgint:
	 lresult = bigcmp(dp1, dp2);
	 if (lresult == 0)
	    return Equal;
	 return ((lresult > 0) ? Greater : Less);


      case T_Coexpr:
         /*
          * Collate on co-expression id.
          */
         lresult = (BlkLoc(*dp1)->coexpr.id - BlkLoc(*dp2)->coexpr.id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Cset: {
          int i = 0, j = 0;
          while (i < BlkLoc(*dp1)->cset.n_ranges &&
                 j < BlkLoc(*dp2)->cset.n_ranges) {
              int from1 = BlkLoc(*dp1)->cset.range[i].from;
              int to1 = BlkLoc(*dp1)->cset.range[i].to;
              int from2 = BlkLoc(*dp2)->cset.range[j].from;
              int to2 = BlkLoc(*dp2)->cset.range[j].to;
              if (from1 < from2)
                  return Less;
              if (from2 < from1)
                  return Greater;
              if (to1 < to2)
                  ++i;
              else if (to2 < to1)
                  ++j;
              else {
                  ++i;
                  ++j;
              }
          }
          if (i < BlkLoc(*dp1)->cset.n_ranges)
              return Greater;
          if (j < BlkLoc(*dp2)->cset.n_ranges)
              return Less;
          return Equal;
      }

      case T_List:
         /*
          * Collate on list id.
          */
         lresult = (BlkLoc(*dp1)->list.id - BlkLoc(*dp2)->list.id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Null:
         return Equal;

      case T_Proc:
         /*
          * Collate on procedure name.
          */
         return lexcmp(&(BlkLoc(*dp1)->proc.name),
            &(BlkLoc(*dp2)->proc.name));

      case T_Ucs:
         /*
          * Collate on utf8 data.
          */
         return lexcmp(&(BlkLoc(*dp1)->ucs.utf8),
            &(BlkLoc(*dp2)->ucs.utf8));

      case T_Real:
         GetReal(dp1,rres1);
         GetReal(dp2,rres2);
         rresult = rres1 - rres2;
	 if (rresult == 0.0)
	    return Equal;
	 return ((rresult > 0.0) ? Greater : Less);

      case T_Class:
          /*
           * Collate on class name.
           */
         return lexcmp(&(BlkLoc(*dp1)->class.name), &(BlkLoc(*dp2)->class.name));

      case T_Constructor:
          /*
           * Collate on type name.
           */
         return lexcmp(&(BlkLoc(*dp1)->constructor.name), &(BlkLoc(*dp2)->constructor.name));

      case T_Record:
         /*
          * Collate on record id within record name.
          */
         iresult = lexcmp(&(BlkLoc(*dp1)->record.constructor->name),
            &(BlkLoc(*dp2)->record.constructor->name));
         if (iresult == Equal) {
            lresult = (BlkLoc(*dp1)->record.id - BlkLoc(*dp2)->record.id);
            if (lresult > 0)	/* coded this way because of code-generation */
               return Greater;  /* bug in MSC++ 7.0A;  do not change. */
            else if (lresult < 0)
               return Less;
            else
               return Equal;
            }
        return iresult;

      case T_Object:
         /*
          * Collate on object id within class name.
          */
         iresult = lexcmp(&(BlkLoc(*dp1)->object.class->name),
                          &(BlkLoc(*dp2)->object.class->name));
         if (iresult == Equal) {
            lresult = (BlkLoc(*dp1)->object.id - BlkLoc(*dp2)->object.id);
            if (lresult > 0)	/* coded this way because of code-generation */
               return Greater;  /* bug in MSC++ 7.0A;  do not change. */
            else if (lresult < 0)
               return Less;
            else
               return Equal;
            }
        return iresult;

      case T_Cast:
         /*
          * Collate on cast class name within cast object id within cast object class name.
          */
          iresult = lexcmp(&(BlkLoc(*dp1)->cast.object->class->name),
                           &(BlkLoc(*dp2)->cast.object->class->name));
          if (iresult == Equal) {
              lresult = (BlkLoc(*dp1)->cast.object->id - BlkLoc(*dp2)->cast.object->id);
              if (lresult > 0)	/* coded this way because of code-generation */
                  iresult = Greater;  /* bug in MSC++ 7.0A;  do not change. */
              else if (lresult < 0)
                  iresult = Less;
              else
                  iresult = Equal;
              if (iresult == Equal) {
                  return lexcmp(&(BlkLoc(*dp1)->cast.class->name),
                                &(BlkLoc(*dp2)->cast.class->name));
              }
          }
          return iresult;

      case T_Methp:
         /*
          * Collate on methp proc name within methp object id within methp object class name.
          */
          iresult = lexcmp(&(BlkLoc(*dp1)->methp.object->class->name),
                           &(BlkLoc(*dp2)->methp.object->class->name));
          if (iresult == Equal) {
              lresult = (BlkLoc(*dp1)->methp.object->id - BlkLoc(*dp2)->methp.object->id);
              if (lresult > 0)	/* coded this way because of code-generation */
                  iresult = Greater;  /* bug in MSC++ 7.0A;  do not change. */
              else if (lresult < 0)
                  iresult = Less;
              else
                  iresult = Equal;
              if (iresult == Equal) {
                  return lexcmp(&(BlkLoc(*dp1)->methp.proc->name),
                                &(BlkLoc(*dp2)->methp.proc->name));
              }
          }
          return iresult;

      case T_Set:
         /*
          * Collate on set id.
          */
         lresult = (BlkLoc(*dp1)->set.id - BlkLoc(*dp2)->set.id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Table:
         /*
          * Collate on table id.
          */
         lresult = (BlkLoc(*dp1)->table.id - BlkLoc(*dp2)->table.id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      default:
	 syserr("anycmp: unknown datatype.");
	 /*NOTREACHED*/
	 return 0;  /* avoid gcc warning */
      }
   }

/*
 * order(x) - return collating number for object x.
 */

int order(dp)
dptr dp;
   {
   if (Qual(*dp))
      return 3; 	     /* string */
   switch (Type(*dp)) {
      case T_Null:
	 return 0;
      case T_Integer:
	 return 1;

      case T_Lrgint:
	 return 1;

      case T_Real:
	 return 2;

      /* string: return 3 (see above) */

      case T_Cset:
	 return 4;
      case T_Constructor:
         return 5;
      case T_Coexpr:
	 return 6;
      case T_Proc:
	 return 7;
      case T_List:
	 return 8;
      case T_Set:
	 return 9;
      case T_Table:
	 return 10;
      case T_Record:
	 return 11;
      case T_Ucs:
         return 12;
      case T_Class:
         return 13;
      case T_Object:
         return 14;
      case T_Cast:
         return 15;
      case T_Methp:
         return 16;
      default:
	 syserr("order: unknown datatype.");
	 /*NOTREACHED*/
	 return 0;  /* avoid gcc warning */
      }
   }

/*
 * equiv - test equivalence of two objects.
 */

int equiv(dp1, dp2)
dptr dp1, dp2;
   {
   register int result;
   register word i;
   register char *s1, *s2;
   double rres1, rres2;

   result = 0;

      /*
       * If the descriptors are identical, the objects are equivalent.
       */
   if (EqlDesc(*dp1,*dp2))
      result = 1;
   else if (Qual(*dp1) && Qual(*dp2)) {

      /*
       *  If both are strings of equal length, compare their characters.
       */

      if ((i = StrLen(*dp1)) == StrLen(*dp2)) {


	 s1 = StrLoc(*dp1);
	 s2 = StrLoc(*dp2);
	 result = 1;
	 while (i--)
	   if (*s1++ != *s2++) {
	      result = 0;
	      break;
	      }

	 }
      }
   else if (dp1->dword == dp2->dword)
      switch (Type(*dp1)) {
	 /*
	  * For integers and reals, just compare the values.
	  */
	 case T_Integer:
	    result = (IntVal(*dp1) == IntVal(*dp2));
	    break;

	 case T_Lrgint:
	    result = (bigcmp(dp1, dp2) == 0);
	    break;


	 case T_Real:
            GetReal(dp1, rres1);
            GetReal(dp2, rres2);
            result = (rres1 == rres2);
	    break;

          case T_Ucs:
              /* Compare the utf8 strings */
              result = equiv(&BlkLoc(*dp1)->ucs.utf8, &BlkLoc(*dp2)->ucs.utf8);
              break;

          case T_Cset: {
	    /*
	     * Compare the ranges.
	     */
             result = (BlkLoc(*dp1)->cset.n_ranges == BlkLoc(*dp2)->cset.n_ranges);
             if (result) {
                 for (i = 0; i < BlkLoc(*dp1)->cset.n_ranges; i++) {
                     if (BlkLoc(*dp1)->cset.range[i].from != BlkLoc(*dp2)->cset.range[i].from ||
                         BlkLoc(*dp1)->cset.range[i].to != BlkLoc(*dp2)->cset.range[i].to) {
                         result = 0;
                         break;
                     }
                 }
             }
          }
	}
   else
      /*
       * dp1 and dp2 are of different types, so they can't be
       *  equivalent.
       */
      result = 0;

   return result;
   }

/*
 * lexcmp - lexically compare two strings.
 */

int lexcmp(dp1, dp2)
dptr dp1, dp2;
   {


   register char *s1, *s2;
   register word minlen;
   word l1, l2;

   /*
    * Get length and starting address of both strings.
    */
   l1 = StrLen(*dp1);
   s1 = StrLoc(*dp1);
   l2 = StrLen(*dp2);
   s2 = StrLoc(*dp2);

   /*
    * Set minlen to length of the shorter string.
    */
   minlen = Min(l1, l2);

   /*
    * Compare as many bytes as are in the smaller string.  If an
    *  inequality is found, compare the differing bytes.
    */
   while (minlen--)
      if (*s1++ != *s2++)
         return ((*--s1 & 0377) > (*--s2 & 0377) ?
                 Greater : Less);
   /*
    * The strings compared equal for the length of the shorter.
    */
   if (l1 == l2)
      return Equal;
   else if (l1 > l2)
      return Greater;
   else
      return Less;

   }
