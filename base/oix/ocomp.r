/*
 * File: ocomp.r
 *  Contents: lexeq, lexge, lexgt, lexle, lexlt, lexne, numeq, numge,
 *		numgt, numle, numlt, numne, eqv, neqv
 */

/*
 * NumComp is a macro that defines the form of a numeric comparisons.
 */
#begdef NumComp(icon_op, func_name, c_op, descript)
"x " #icon_op " y - test if x is numerically " #descript " y."
   operator{0,1} icon_op func_name(x,y)

   arith_case (x, y) of {
      C_integer: {
         abstract {
            return integer
            }
         inline {
            if c_op(x, y)
               return C_integer y;
            fail;
            }
         }
      integer: { /* large integers only */
         abstract {
            return integer
            }
         inline {
            if (big_ ## c_op (x,y)) {
               return y;
   	    }
            fail;
            }
         }
      C_double: {
         abstract {
            return real
            }
         inline {
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
operator{0,1} icon_op func_name(x,y)
   body {
     if (is:ucs(x) || is:ucs(y)) {
         if (!cnv:ucs(x,x))
             runerr(128, x);
         if (!cnv:ucs(y,y))
             runerr(128, y);

         /*
          * lexcmp does the work.
          */
         if (special_test_ucs (lexcmp(&BlkLoc(x)->ucs.utf8, 
                                      &BlkLoc(y)->ucs.utf8) c_comp comp_value))
             return y;
         else
             fail;
     } else {
         if (!cnv:string(x,x))
             runerr(103, x);
         if (!cnv:string(y,y))
             runerr(103, y);

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
        (StrLen(BlkLoc(x)->ucs.utf8) == StrLen(BlkLoc(y)->ucs.utf8)) &&,==, Equal, equal to) 
StrComp(~==, lexne, (StrLen(x) != StrLen(y)) ||, 
        (StrLen(BlkLoc(x)->ucs.utf8) != StrLen(BlkLoc(y)->ucs.utf8)) ||, !=, Equal, not equal to)
StrComp(>>=, lexge, , , !=, Less,    greater than or equal to) 
StrComp(>>,  lexgt, , , ==, Greater, greater than)
StrComp(<<=, lexle, , , !=, Greater, less than or equal to)
StrComp(<<,  lexlt, , , ==, Less,    less than)


"x === y - test equivalence of x and y."

operator{0,1} === eqv(x,y)
   abstract {
      return type(y)
      }
   inline {
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

operator{0,1} ~=== neqv(x,y)
   abstract {
      return type(y)
      }
   inline {
      /*
       * equiv does all the work.
       */
      if (!equiv(&x, &y))
         return y;
      else
         fail;
   }
end
