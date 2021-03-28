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
         return uwordcmp(CoexprBlk(*dp1).id, CoexprBlk(*dp2).id);

      cset: {
          word i = 0, j = 0;
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
         return uwordcmp(ListBlk(*dp1).id, ListBlk(*dp2).id);

      null:
         return Equal;

      yes:
         return Equal;

      proc:
         return proccmp(&ProcBlk(*dp1), &ProcBlk(*dp2));

      ucs:
         return lexcmp(&(UcsBlk(*dp1).utf8), &(UcsBlk(*dp2).utf8));

      real: {
         double r1, r2;
         DGetReal(*dp1, r1);
         DGetReal(*dp2, r2);
         if (r1 == r2)
            return Equal;
         return (r1 > r2) ? Greater : Less;
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
         return uwordcmp(MethpBlk(*dp1).id, MethpBlk(*dp2).id);

      weakref:
         return uwordcmp(WeakrefBlk(*dp1).id, WeakrefBlk(*dp2).id);

      set:
         return uwordcmp(SetBlk(*dp1).id, SetBlk(*dp2).id);

      table:
         return uwordcmp(TableBlk(*dp1).id, TableBlk(*dp2).id);

      default: {
	 syserr("anycmp: Unknown datatype.");
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
     yes:         return 1;
     integer:     return 2;
     real:        return 3;
     string:      return 4;
     cset:        return 5;
     constructor: return 6;
     coexpr:      return 7;
     proc:        return 8;
     list:        return 9;
     set:         return 10;
     table:       return 11;
     record:      return 12;
     ucs:         return 13;
     class:       return 14;
     object:      return 15;
     methp:       return 16;
     weakref:     return 17;
     default: {
	 syserr("order: Unknown datatype.");
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

      if ((i = StrLen(*dp1)) == StrLen(*dp2))
         result = memcmp(StrLoc(*dp1), StrLoc(*dp2), i) == 0;

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

	 case T_Real: {
            double r1, r2;
            DGetReal(*dp1, r1);
            DGetReal(*dp2, r2);
            result = (r1 == r2);
	    break;
         }

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

#begdef LexCmp(func_name, char_cmp)
int func_name(dptr dp1, dptr dp2)
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
       char_cmp(s1, s2, minlen);
   }

   /*
    * The strings compared equal for the length of the shorter.
    */
   if (l1 == l2)
      return Equal;
   return (l1 > l2) ? Greater : Less;
}
#enddef

/*
 * lexcmp - lexically compare two strings.
 */
#begdef SimpleCharCmp(s1, s2, minlen)
    int i = memcmp(s1, s2, minlen);
    if (i != 0)
       return (i > 0) ? Greater : Less;
#enddef
LexCmp(lexcmp, SimpleCharCmp)

/*
 * Caseless string comparison
 */
#begdef CaselessCharCmp(s1, s2, minlen)
   while (minlen--) {
       unsigned char c1, c2;
       c1 = *s1++;
       c2 = *s2++;
       if (c1 >= 'A' && c1 <= 'Z') c1 += 'a' - 'A';
       if (c2 >= 'A' && c2 <= 'Z') c2 += 'a' - 'A';
       if (c1 != c2)
           return (c1 > c2) ? Greater : Less;
   }
#enddef
LexCmp(caseless_lexcmp, CaselessCharCmp)

/*
 * A caseless lexical comparison on two ucs strings.
 */
int caseless_ucs_lexcmp(struct b_ucs *b1, struct b_ucs *b2)
{
   char *s1, *s2;
   word l1, l2;

   /*
    * Get length and starting address of both strings.
    */
   l1 = b1->length;
   s1 = StrLoc(b1->utf8);
   l2 = b2->length;
   s2 = StrLoc(b2->utf8);

   if (s1 != s2) {
       /*
        * Set minlen to length of the shorter string.
        */
       word minlen = Min(l1, l2);

       /*
        * Compare as many chars as are in the smaller string.  If an
        *  inequality is found, compare the differing chars.
        */
       while (minlen--) {
           int c1, c2;
           c1 = oi_towlower(utf8_iter(&s1));
           c2 = oi_towlower(utf8_iter(&s2));
           if (c1 != c2)
               return (c1 > c2) ? Greater : Less;
       }
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

