/*
 * File: oarith.r
 *
 * The arithmetic operators all follow a canonical conversion
 * protocol encapsulated in the macro ArithOp.
 */

#begdef ArithOp(icon_op, func_name, c_func, int_op, c_op)

operator icon_op func_name(x, y)
   body {
      tended struct descrip ix, iy, iresult;
      /* Avoid function calls to conversion funcs if possible. */
      if (IsCInteger(x) && IsCInteger(y)) {
          word w;
          /* Optimistically try the basic c function; if it overflows
           * then use the bigint function instead. */
          w = c_func(IntVal(x), IntVal(y));
          if (over_flow) {
              int_op(x, y, iresult);
          } else
              MakeInt(w, &iresult);
          return iresult;
      } else if (cnv:(exact)integer(x, ix) && cnv:(exact)integer(y, iy)) {
          int_op(ix, iy, iresult);
          return iresult;
      } else {
          double dx, dy, dresult;
          if (!cnv:C_double(x, dx))
              runerr(102, x);
          if (!cnv:C_double(y, dy))
              runerr(102, y);
          c_op(dx, dy, dresult);
          if (!isfinite(dresult))
              runerr(204);
          return C_double dresult;
      }
   }
end

#enddef

/*
 * x / y
 */
#begdef IntDivide(x,y,result)
{
   if (bigsign(&y) == 0)
      runerr(201);  /* Divide fix */
   bigdiv(&x,&y,&result);
}
#enddef
#begdef RealDivide(x,y,result)
{
   if (y == 0.0)
      runerr(201);
   result = x / y;
}
#enddef
ArithOp( / , div , div3, IntDivide , RealDivide)

/*
 * x - y
 */
#define IntSub(x,y,result) bigsub(&x,&y,&result);
#define RealSub(x,y,result) result = x - y;
ArithOp( - , minus , sub, IntSub , RealSub)


/*
 * x % y
 */
#begdef IntMod(x,y,result)
{
   if (bigsign(&y) == 0)
      runerr(202);
   bigmod(&x,&y,&result);
}
#enddef
#begdef RealMod(x,y,result)
{
   if (y == 0.0)
      runerr(202);
   result = fmod(x, y);
   /* result must have the same sign as x */
   if (x < 0.0) {
      if (result > 0.0) {
         result -= Abs(y);
         }
      }
   else if (result < 0.0) {
      result += Abs(y);
      }
}
#enddef
ArithOp( % , mod , mod3, IntMod , RealMod)

/*
 * x * y
 */
#define IntMpy(x,y,result) bigmul(&x,&y,&result);
#define RealMpy(x,y,result) result = x * y;
ArithOp( * , mult , mul, IntMpy , RealMpy)


/*
 * x + y
 */
#define IntAdd(x,y,result) bigadd(&x,&y,&result);
#define RealAdd(x,y,result) result = x + y;
ArithOp( + , plus , add, IntAdd , RealAdd)


"-x - negate x."

operator - neg(x)
   body {
      tended struct descrip ix, iresult;
      if (IsCInteger(x)) {
          word w;
          w = neg(IntVal(x));
          if (over_flow)
              bigneg(&x, &iresult);
          else
              MakeInt(w, &iresult);
          return iresult;
      } else if (cnv:(exact)integer(x, ix)) {
          bigneg(&ix, &iresult);
          return iresult;
      } else {
          double dx;
          if (!cnv:C_double(x, dx))
              runerr(102, x);
          return C_double -dx;
      }
   }
end


"+x - convert x to a number."
/*
 *  Operational definition: generate runerr if x is not numeric.
 */
operator + number(x)
   if cnv:(exact) integer(x) then {
       body {
          return x;
          }
      }
   else if cnv:real(x) then {
       body {
          return x;
          }
      }
   else
      runerr(102, x)
end


"x ^ y - raise x to the y power."

operator ^ power(x, y)
   if cnv:(exact)integer(y) then {
      if cnv:(exact)integer(x) then {
	 body {
            tended struct descrip result;
	    if (bigpow(&x, &y, &result) == Error)
	       runerr(0);
	    return result;
	    }
	 }
      else {
	 if !cnv:C_double(x) then
	    runerr(102, x)
	 body {
            tended struct descrip result;
	    if ( bigpowri ( x, &y, &result ) == Error )
	       runerr(0);
	    return result;
	    }
	 }
      }
   else {
      if !cnv:C_double(x) then
	 runerr(102, x)
      if !cnv:C_double(y) then
	 runerr(102, y)
      body {
         double r;
	 if (x == 0.0 && y < 0.0)
	     runerr(209);
	 if (x < 0.0)
	    runerr(206);
         r = pow(x,y);
         if (!isfinite(r))
             runerr(204);
         return C_double r;
	 }
      }
end
