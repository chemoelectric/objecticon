/*
 * File: rcomp.r
 */

static int uwordcmp(uword i, uword j);
static int classcmp(struct b_class *c1, struct b_class *c2);
static int fieldcmp(struct class_field *f1, struct class_field *f2);
static int objectcmp(struct b_object *o1, struct b_object *o2);
static int constructorcmp(struct b_constructor *c1, struct b_constructor *c2);
static int recordcmp(struct b_record *r1, struct b_record *r2);
static int proccmp(struct b_proc *p1, struct b_proc *p2);
static int methpcmp(struct b_methp *m1, struct b_methp *m2);
static int progcmp(struct progstate *p1, struct progstate *p2);

/*
 * anycmp - compare any two objects.
 */

int anycmp(dptr dp1, dptr dp2)
{
   int o1, o2;

   /*
    * Identical descriptors must always compare Equal.
    */
   if (EqlDesc(*dp1,*dp2))
       return Equal;

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

   type_case *dp1 of {
      string:
         /*
          * dp1 and dp2 are strings, use lexcmp to compare them.
          */
         return lexcmp(dp1,dp2);

      integer:
         return bigcmp(dp1, dp2);

      coexpr:
         /*
          * Collate on co-expression id.
          */
         return uwordcmp(CoexprBlk(*dp1).id, CoexprBlk(*dp2).id);

      cset: {
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

      list:
         /*
          * Collate on list id.
          */
         return uwordcmp(ListBlk(*dp1).id, ListBlk(*dp2).id);

      null:
         return Equal;

      proc:
         return proccmp(&ProcBlk(*dp1), &ProcBlk(*dp2));

      ucs:
         /*
          * Collate on utf8 data.
          */
         return lexcmp(&(UcsBlk(*dp1).utf8), &(UcsBlk(*dp2).utf8));

      real: {
         double rres1, rres2, rresult;
         DGetReal(*dp1,rres1);
         DGetReal(*dp2,rres2);
         rresult = rres1 - rres2;
         if (rresult == 0.0)
            return Equal;
         return ((rresult > 0.0) ? Greater : Less);
      }

      class:
         return classcmp(&ClassBlk(*dp1), &ClassBlk(*dp2));

      constructor:
         return constructorcmp(&ConstructorBlk(*dp1), &ConstructorBlk(*dp2));

      record:
         return recordcmp(&RecordBlk(*dp1), &RecordBlk(*dp2));

      object:
         return objectcmp(&ObjectBlk(*dp1), &ObjectBlk(*dp2));

      methp:
         return methpcmp(&MethpBlk(*dp1), &MethpBlk(*dp2));

      weakref:
         /*
          * Collate on id.
          */
         return uwordcmp(WeakrefBlk(*dp1).id, WeakrefBlk(*dp2).id);

      set:
         /*
          * Collate on set id.
          */
         return uwordcmp(SetBlk(*dp1).id, SetBlk(*dp2).id);

      table:
         /*
          * Collate on table id.
          */
         return uwordcmp(TableBlk(*dp1).id, TableBlk(*dp2).id);

      default: {
	 syserr("anycmp: unknown datatype.");
	 /*NOTREACHED*/
	 return 0;  /* avoid gcc warning */
      }
   }
}


/*
 * order(x) - return collating number for object x.
 */

int order(dptr dp)
{
   type_case *dp of {
     null:        return 0;
     integer:     return 1;
     real:        return 2;
     string:      return 3;
     cset:        return 4;
     constructor: return 5;
     coexpr:      return 6;
     proc:        return 7;
     list:        return 8;
     set:         return 9;
     table:       return 10;
     record:      return 11;
     ucs:         return 12;
     class:       return 13;
     object:      return 14;
     methp:       return 15;
     weakref:     return 16;
     default: {
	 syserr("order: unknown datatype.");
	 /*NOTREACHED*/
	 return 0;  /* avoid gcc warning */
     }
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
   word l1, l2;

   /*
    * Get length and starting address of both strings.
    */
   l1 = StrLen(*dp1);
   s1 = StrLoc(*dp1);
   l2 = StrLen(*dp2);
   s2 = StrLoc(*dp2);

   if (s1 != s2) {
       /*
        * Set minlen to length of the shorter string.
        */
       word minlen = Min(l1, l2);

       /*
        * Compare as many bytes as are in the smaller string.  If an
        *  inequality is found, compare the differing bytes.
        */
       while (minlen--)
           if (*s1++ != *s2++)
               return ((*--s1 & 0377) > (*--s2 & 0377) ?
                       Greater : Less);
   }

   /*
    * The strings compared equal for the length of the shorter.
    */
   if (l1 == l2)
      return Equal;
   return (l1 > l2) ? Greater : Less;

}

/*
 * Compare two unsigned words.
 */
static int uwordcmp(uword i, uword j)
{
    if (i == j)
      return Equal;
   return (i > j) ? Greater : Less;
}

static int progcmp(struct progstate *p1, struct progstate *p2)
{
    if (p1 == p2)
      return Equal;
    return uwordcmp(p1->K_main->id, p2->K_main->id);
}

static int classcmp(struct b_class *c1, struct b_class *c2)
{
    int i;
    /*
     * Collate on class name and program.
     */
    if (c1 == c2)
        return Equal;
    i = lexcmp(c1->name, c2->name);
    if (i == Equal)
        i = progcmp(c1->program, c2->program);
    return i;
}

static int objectcmp(struct b_object *o1, struct b_object *o2)
{
    int i;
    /*
     * Collate on class, object id
     */
    if (o1 == o2)
        return Equal;
    i = classcmp(o1->class, o2->class);
    if (i == Equal)
        i = uwordcmp(o1->id, o2->id);
    return i;
}

static int constructorcmp(struct b_constructor *c1, struct b_constructor *c2)
{
    int i;
    /*
     * Collate on record type name and program.
     */
    if (c1 == c2)
        return Equal;
    i =  lexcmp(c1->name, c2->name);
    if (i == Equal)
        i = progcmp(c1->program, c2->program);
    return i;
}

static int recordcmp(struct b_record *r1, struct b_record *r2)
{
    int i;
    /*
     * Collate on constructor, record id
     */
    if (r1 == r2)
        return Equal;
    i = constructorcmp(r1->constructor, r2->constructor);
    if (i == Equal)
        i = uwordcmp(r1->id, r2->id);
    return i;
}

static int methpcmp(struct b_methp *m1, struct b_methp *m2)
{
    int i;
    /*
     * Collate on object, proc.
     */
    if (m1 == m2)
        return Equal;
    i = objectcmp(m1->object, m2->object);
    if (i == Equal)
        i = proccmp(m1->proc, m2->proc);
    return i;
}

static int fieldcmp(struct class_field *f1, struct class_field *f2)
{
    int i;
    /*
     * Collate on class, fnum
     */
    if (f1 == f2)
        return Equal;
    i = classcmp(f1->defining_class, f2->defining_class);
    if (i == Equal)
        i = uwordcmp(f1->fnum, f2->fnum);
    return i;
}

static int proccmp(struct b_proc *p1, struct b_proc *p2)
{
    int i;
    struct progstate *prog1, *prog2;

    if (p1 == p2)
        return Equal;

    /*
     * Try to resolve on name
     */
    i =  lexcmp(p1->name, p2->name);
    if (i != Equal)
        return i;

    /*
     * If either or both are class fields, collate on the field.
     */
    if (p1->field && !p2->field)
        return Less;
    if (!p1->field && p2->field)
        return Greater;
    if (p1->field && p2->field)
        return fieldcmp(p1->field, p2->field);

    /*
     * Neither are class fields.
     * If either or both are in programs, collate on that.
     */
    prog1 = (p1->type == P_Proc) ? ((struct p_proc *)p1)->program : 0;
    prog2 = (p2->type == P_Proc) ? ((struct p_proc *)p2)->program : 0;
    if (prog1 && !prog2)
        return Less;
    if (!prog1 && prog2)
        return Greater;
    if (prog1 && prog2)
        return progcmp(prog1, prog2);

    /*
     * Now both have same name, neither a class field, neither in a program.
     * In desperation, collate on address of block.
     */
    return uwordcmp((uword)p1, (uword)p2);
}

