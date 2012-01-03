/*
 * File: rcomp.r
 */

/*
 * anycmp - compare any two objects.
 */

int anycmp(dptr dp1, dptr dp2)
   {
   int o1, o2;
   long lresult;
   int iresult;

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
      case T_Lrgint:
         return bigcmp(dp1, dp2);

      case T_Coexpr:
         /*
          * Collate on co-expression id.
          */
         lresult = (CoexprBlk(*dp1).id - CoexprBlk(*dp2).id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Cset: {
          int i = 0, j = 0;
          while (i < CsetBlk(*dp1).n_ranges &&
                 j < CsetBlk(*dp2).n_ranges) {
              int from1 = CsetBlk(*dp1).range[i].from;
              int to1 = CsetBlk(*dp1).range[i].to;
              int from2 = CsetBlk(*dp2).range[j].from;
              int to2 = CsetBlk(*dp2).range[j].to;
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
          if (i < CsetBlk(*dp1).n_ranges)
              return Greater;
          if (j < CsetBlk(*dp2).n_ranges)
              return Less;
          return Equal;
      }

      case T_List:
         /*
          * Collate on list id.
          */
         lresult = (ListBlk(*dp1).id - ListBlk(*dp2).id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Null:
         return Equal;

      case T_Proc:
         /*
          * Collate on procedure name.
          */
         return lexcmp(ProcBlk(*dp1).name,
                       ProcBlk(*dp2).name);

      case T_Ucs:
         /*
          * Collate on utf8 data.
          */
         return lexcmp(&(UcsBlk(*dp1).utf8),
            &(UcsBlk(*dp2).utf8));

      case T_Real: {
         double rres1, rres2, rresult;
         DGetReal(*dp1,rres1);
         DGetReal(*dp2,rres2);
         rresult = rres1 - rres2;
         if (rresult == 0.0)
            return Equal;
         return ((rresult > 0.0) ? Greater : Less);
      }

      case T_Class:
          /*
           * Collate on class name.
           */
         return lexcmp(ClassBlk(*dp1).name, ClassBlk(*dp2).name);

      case T_Constructor:
          /*
           * Collate on type name.
           */
         return lexcmp(ConstructorBlk(*dp1).name, ConstructorBlk(*dp2).name);

      case T_Record:
         /*
          * Collate on record id within record name.
          */
         iresult = lexcmp(RecordBlk(*dp1).constructor->name,
                          RecordBlk(*dp2).constructor->name);
         if (iresult == Equal) {
            lresult = (RecordBlk(*dp1).id - RecordBlk(*dp2).id);
            if (lresult == 0)
                return Equal;
            return ((lresult > 0) ? Greater : Less);
            }
        return iresult;

      case T_Object:
         /*
          * Collate on object id within class name.
          */
         iresult = lexcmp(ObjectBlk(*dp1).class->name,
                          ObjectBlk(*dp2).class->name);
         if (iresult == Equal) {
            lresult = (ObjectBlk(*dp1).id - ObjectBlk(*dp2).id);
            if (lresult == 0)
                return Equal;
            return ((lresult > 0) ? Greater : Less);
            }
        return iresult;

      case T_Cast:
         /*
          * Collate on cast class name within cast object id within cast object class name.
          */
          iresult = lexcmp(CastBlk(*dp1).object->class->name,
                           CastBlk(*dp2).object->class->name);
          if (iresult == Equal) {
              lresult = (CastBlk(*dp1).object->id - CastBlk(*dp2).object->id);
              if (lresult == 0)
                  return lexcmp(CastBlk(*dp1).class->name,
                                CastBlk(*dp2).class->name);
              return ((lresult > 0) ? Greater : Less);
          }
          return iresult;

      case T_Methp:
         /*
          * Collate on methp proc name within methp object id within methp object class name.
          */
          iresult = lexcmp(MethpBlk(*dp1).object->class->name,
                           MethpBlk(*dp2).object->class->name);
          if (iresult == Equal) {
              lresult = (MethpBlk(*dp1).object->id - MethpBlk(*dp2).object->id);
              if (lresult == 0)
                  return lexcmp(MethpBlk(*dp1).proc->name,
                                MethpBlk(*dp2).proc->name);
              return ((lresult > 0) ? Greater : Less);
          }
          return iresult;

      case T_Weakref:
         /*
          * Collate on id.
          */
         lresult = (WeakrefBlk(*dp1).id - WeakrefBlk(*dp2).id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Set:
         /*
          * Collate on set id.
          */
         lresult = (SetBlk(*dp1).id - SetBlk(*dp2).id);
         if (lresult == 0)
            return Equal;
         return ((lresult > 0) ? Greater : Less);

      case T_Table:
         /*
          * Collate on table id.
          */
         lresult = (TableBlk(*dp1).id - TableBlk(*dp2).id);
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

int order(dptr dp)
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
      case T_Weakref:
         return 17;
      default:
	 syserr("order: unknown datatype.");
	 /*NOTREACHED*/
	 return 0;  /* avoid gcc warning */
      }
   }

/*
 * equiv - test equivalence of two objects.
 */

int equiv(dptr dp1, dptr dp2)
   {
   int result;
   word i;
   char *s1, *s2;
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
            DGetReal(*dp1, rres1);
            DGetReal(*dp2, rres2);
            result = (rres1 == rres2);
	    break;

          case T_Ucs:
              /* Compare the utf8 strings */
              result = equiv(&UcsBlk(*dp1).utf8, &UcsBlk(*dp2).utf8);
              break;

          case T_Cset: {
	    /*
	     * Compare the ranges.
	     */
             result = (CsetBlk(*dp1).n_ranges == CsetBlk(*dp2).n_ranges);
             if (result) {
                 for (i = 0; i < CsetBlk(*dp1).n_ranges; i++) {
                     if (CsetBlk(*dp1).range[i].from != CsetBlk(*dp2).range[i].from ||
                         CsetBlk(*dp1).range[i].to != CsetBlk(*dp2).range[i].to) {
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

int lexcmp(dptr dp1, dptr dp2)
   {


   char *s1, *s2;
   word minlen;
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
   return ( (l1 > l2) ? Greater : Less);

   }
