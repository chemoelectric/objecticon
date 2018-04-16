/*
 * File: ocomp.r
 */

/*
 * NumComp is a macro that defines the form of a numeric comparisons.
 */
#begdef NumComp(icon_op, func_name, int_op, real_op)

operator icon_op func_name(x,y)
   body {
      tended struct descrip ix, iy;
      /* Avoid function calls to conversion and operator funcs if possible. */
      if (IsCInteger(x) && IsCInteger(y)) {
          if (real_op (IntVal(x), IntVal(y)))
             return y;
      } else if (cnv:(exact)integer(x, ix) && cnv:(exact)integer(y, iy)) {
          if (int_op (ix, iy))
             return iy;
      } else {
          double dx, dy;
          if (!cnv:C_double(x, dx))
              runerr(102, x);
          if (!cnv:C_double(y, dy))
              runerr(102, y);
          if real_op (dx, dy)
               return C_double dy;
      }
      fail;
   }
end
#enddef

/*
 * x = y
 */
#define RealNumEq(x,y) (x == y)
#define IntNumEq(x,y) (bigcmp(&x,&y) == 0)
NumComp( = , numeq, IntNumEq, RealNumEq)

/*
 * x >= y
 */
#define RealNumGe(x,y) (x >= y)
#define IntNumGe(x,y) (bigcmp(&x,&y) >= 0)
NumComp( >=, numge, IntNumGe, RealNumGe)

/*
 * x > y
 */
#define RealNumGt(x,y) (x > y)
#define IntNumGt(x,y) (bigcmp(&x,&y) > 0)
NumComp( > , numgt, IntNumGt, RealNumGt)

/*
 * x <= y
 */
#define RealNumLe(x,y) (x <= y)
#define IntNumLe(x,y) (bigcmp(&x,&y) <= 0)
NumComp( <=, numle, IntNumLe, RealNumLe)

/*
 * x < y
 */
#define RealNumLt(x,y) (x < y)
#define IntNumLt(x,y) (bigcmp(&x,&y) < 0)
NumComp( < , numlt, IntNumLt, RealNumLt)

/*
 * x ~= y
 */
#define RealNumNe(x,y) (x != y)
#define IntNumNe(x,y) (bigcmp(&x,&y) != 0)
NumComp( ~=, numne, IntNumNe, RealNumNe)

/*
 * StrComp is a macro that defines the form of a string comparisons.
 */
#begdef StrComp(icon_op, func_name, special_test_str, special_test_ucs, c_comp, comp_value)

operator icon_op func_name(x, y)
   body {
     if (need_ucs(&x) || need_ucs(&y)) {
         if (!cnv:ucs(x, x))
             runerr(128, x);
         if (!cnv:ucs(y, y))
             runerr(128, y);

         /*
          * lexcmp does the work.
          */
         if (special_test_ucs (lexcmp(&UcsBlk(x).utf8, 
                                      &UcsBlk(y).utf8) c_comp comp_value))
             return y;
         else
             fail;
     } else {
         /* Neither ucs, so both args must be strings */

         if (!cnv:string(x, x))
             runerr(129, x);
         if (!cnv:string(y, y))
             runerr(129, y);

         /*
          * lexcmp does the work.
          */
         if (special_test_str (lexcmp(&x, &y) c_comp comp_value))
             return y;
         else
             fail;

     }
   }
end
#enddef

StrComp(==,  lexeq, (StrLen(x) == StrLen(y)) &&, 
        (StrLen(UcsBlk(x).utf8) == StrLen(UcsBlk(y).utf8)) &&,==, Equal) 
StrComp(~==, lexne, (StrLen(x) != StrLen(y)) ||, 
        (StrLen(UcsBlk(x).utf8) != StrLen(UcsBlk(y).utf8)) ||, !=, Equal)
StrComp(>>=, lexge, , , !=, Less    ) 
StrComp(>>,  lexgt, , , ==, Greater )
StrComp(<<=, lexle, , , !=, Greater )
StrComp(<<,  lexlt, , , ==, Less    )


"x === y - test equivalence of x and y."

operator === eqv(x,y)
   body {
      /*
       * Let equiv do all the work, failing if equiv indicates non-equivalence.
       */
      if (equiv(&x, &y))
         return y;
      else
         fail;
   }
end


"x ~=== y - test inequivalence of x and y."

operator ~=== neqv(x,y)
   body {
      /*
       * equiv does all the work.
       */
      if (!equiv(&x, &y))
         return y;
      else
         fail;
   }
end
