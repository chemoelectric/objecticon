/*
 * File: oarith.r
 *
 * The arithmetic operators all follow a canonical conversion
 * protocol encapsulated in the macro ArithOp.
 */

#begdef ArithOp(icon_op, func_name, int_op, real_op)

operator icon_op func_name(x, y)
   body {
      tended struct descrip ix, iy, iresult;
      if (is:integer(x) && is:integer(y)) {
          int_op(x, y, iresult);
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
          real_op(dx, dy, dresult);
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
      runerr(204);
   result = x / y;
}
#enddef
ArithOp( / , div , IntDivide , RealDivide)

/*
 * x - y
 */
#define IntSub(x,y,result) bigsub(&x,&y,&result);
#define RealSub(x,y,result) result = x - y;
ArithOp( - , minus , IntSub , RealSub)


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
      runerr(204);
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
ArithOp( % , mod , IntMod , RealMod)

/*
 * x * y
 */
#define IntMpy(x,y,result) bigmul(&x,&y,&result);
#define RealMpy(x,y,result) result = x * y;
ArithOp( * , mult , IntMpy , RealMpy)


/*
 * x + y
 */
#define IntAdd(x,y,result) bigadd(&x,&y,&result);
#define RealAdd(x,y,result) result = x + y;
ArithOp( + , plus , IntAdd , RealAdd)


"-x - negate x."

operator - neg(x)
   if cnv:(exact) integer(x) then {
      body {
         tended struct descrip result;
         bigneg(&x, &result);
	 return result;
         }
      }
   else {
      if !cnv:C_double(x) then
         runerr(102, x)
      body {
         double drslt;
	 drslt = -x;
         return C_double drslt;
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
   else if cnv:C_double(x) then {
       body {
          return C_double x;
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
	 if (x == 0.0 && y < 0.0)
	     runerr(204);
	 if (x < 0.0)
	    runerr(206);
	 return C_double pow(x,y);
	 }
      }
end
