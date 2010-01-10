/*
 * File: ocomp.r
 */

/*
 * NumComp is a macro that defines the form of a numeric comparisons.
 */
#begdef NumComp(icon_op, func_name, c_op, descript)
"x " #icon_op " y - test if x is numerically " #descript " y."
   operator icon_op func_name(x,y)

   arith_case (x, y) of {
      C_integer: {
         body {
            if c_op(x, y)
               return C_integer y;
            fail;
            }
         }
      integer: { /* large integers only */
         body {
            if (big_ ## c_op (x,y)) {
               return y;
   	    }
            fail;
            }
         }
      C_double: {
         body {
            if c_op (x, y)
               return C_double y;
            fail;
            }
         }
      }
end

#enddef

/*
 * x = y
 */
#define NumEq(x,y) (x == y)
#define big_NumEq(x,y) (bigcmp(&x,&y) == 0)
NumComp( = , numeq, NumEq, equal to)

/*
 * x >= y
 */
#define NumGe(x,y) (x >= y)
#define big_NumGe(x,y) (bigcmp(&x,&y) >= 0)
NumComp( >=, numge, NumGe, greater than or equal to)

/*
 * x > y
 */
#define NumGt(x,y) (x > y)
#define big_NumGt(x,y) (bigcmp(&x,&y) > 0)
NumComp( > , numgt, NumGt,  greater than)

/*
 * x <= y
 */
#define NumLe(x,y) (x <= y)
#define big_NumLe(x,y) (bigcmp(&x,&y) <= 0)
NumComp( <=, numle, NumLe, less than or equal to)

/*
 * x < y
 */
#define NumLt(x,y) (x < y)
#define big_NumLt(x,y) (bigcmp(&x,&y) < 0)
NumComp( < , numlt, NumLt,  less than)

/*
 * x ~= y
 */
#define NumNe(x,y) (x != y)
#define big_NumNe(x,y) (bigcmp(&x,&y) != 0)
NumComp( ~=, numne, NumNe, not equal to)

/*
 * StrComp is a macro that defines the form of a string comparisons.
 */
#begdef StrComp(icon_op, func_name, special_test_str, special_test_ucs, c_comp, comp_value, descript)
"x " #icon_op " y - test if x is lexically " #descript " y."
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
        (StrLen(UcsBlk(x).utf8) == StrLen(UcsBlk(y).utf8)) &&,==, Equal, equal to) 
StrComp(~==, lexne, (StrLen(x) != StrLen(y)) ||, 
        (StrLen(UcsBlk(x).utf8) != StrLen(UcsBlk(y).utf8)) ||, !=, Equal, not equal to)
StrComp(>>=, lexge, , , !=, Less,    greater than or equal to) 
StrComp(>>,  lexgt, , , ==, Greater, greater than)
StrComp(<<=, lexle, , , !=, Greater, less than or equal to)
StrComp(<<,  lexlt, , , ==, Less,    less than)


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
