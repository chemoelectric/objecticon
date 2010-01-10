/*
 * File: oarith.r
 *
 * The arithmetic operators all follow a canonical conversion
 * protocol encapsulated in the macro ArithOp.
 */

int over_flow = 0;

#begdef ArithOp(icon_op, func_name, c_int_op, c_real_op, c_list_op)

   operator icon_op func_name(x, y)
      declare {
         tended struct descrip lx, ly, result;
	 word irslt;
         }
      arith_case (x, y) of {
         C_integer: {
            body {
               c_int_op(x,y);
               }
            }
         integer: { /* large integers only */
            body {
               big_ ## c_int_op(x,y);
               }
            }
         C_double: {
            body {
               c_real_op(x, y);
               }
            }
         }
end

#enddef

/*
 * x / y
 */

#begdef big_Divide(x,y)
{
   if ( ( Type ( y ) == T_Integer ) && ( IntVal ( y ) == 0 ) )
      runerr(201);  /* Divide fix */

   bigdiv(&x,&y,&result);
   return result;
}
#enddef
#begdef Divide(x,y)
{
   if (y == 0)
      runerr(201);  /* divide fix */

   irslt = div3(x,y);
   if (over_flow) {
      MakeInt(x,&lx);
      MakeInt(y,&ly);
      bigdiv(&lx,&ly,&result);
      return result;
      }
   else return C_integer irslt;
}
#enddef
#begdef RealDivide(x,y)
{
   double z;

   if (y == 0.0)
      runerr(204);

   z = x / y;
#ifdef SUN
   if (z >= HUGE || z <= -HUGE) {
      kill(getpid(), SIGFPE);
   }
#endif
   return C_double z;
}
#enddef


ArithOp( / , divide , Divide , RealDivide, list_add /* bogus */)

/*
 * x - y
 */

#begdef big_Sub(x,y)
{
   bigsub(&x,&y,&result);
   return result;
}
#enddef

#begdef Sub(x,y)
   irslt = sub(x,y);
   if (over_flow) {
      MakeInt(x,&lx);
      MakeInt(y,&ly);
      bigsub(&lx,&ly,&result);
      return result;
      }
   else return C_integer irslt;
#enddef

#define RealSub(x,y) return C_double (x - y);

ArithOp( - , minus , Sub , RealSub, list_add /* bogus */)


/*
 * x % y
 */

#define Abs(x) ((x) > 0 ? (x) : -(x))

#begdef big_IntMod(x,y)
{
   if ( ( Type ( y ) == T_Integer ) && ( IntVal ( y ) == 0 ) ) {
      irunerr(202,0);
      errorfail;
      }
   bigmod(&x,&y,&result);
   return result;
}
#enddef

#begdef IntMod(x,y)
{
   irslt = mod3(x,y);
   if (over_flow) {
      irunerr(202,y);
      errorfail;
      }
   return C_integer irslt;
}
#enddef

#begdef RealMod(x,y)
{
   double d;

   if (y == 0.0)
      runerr(204);

   d = fmod(x, y);
   /* d must have the same sign as x */
   if (x < 0.0) {
      if (d > 0.0) {
         d -= Abs(y);
         }
      }
   else if (d < 0.0) {
      d += Abs(y);
      }
   return C_double d;
}
#enddef

ArithOp( % , mod , IntMod , RealMod, list_add /* bogus */ )

/*
 * x * y
 */

#begdef big_Mpy(x,y)
{
   bigmul(&x,&y,&result);
   return result;
}
#enddef

#begdef Mpy(x,y)
   irslt = mul(x,y);
   if (over_flow) {
      MakeInt(x,&lx);
      MakeInt(y,&ly);
      bigmul(&lx,&ly,&result);
      return result;
      }
   else return C_integer irslt;
#enddef


#define RealMpy(x,y) return C_double ((long double)x * (long double)y);

ArithOp( * , mult , Mpy , RealMpy, list_add /* bogus */ )


"-x - negate x."

operator - neg(x)
   if cnv:(exact)C_integer(x) then {
      body {
	    word i;

	    i = neg(x);
	    if (over_flow) {
               tended struct descrip result;
	       struct descrip tmp;
	       MakeInt(x,&tmp);
	       bigneg(&tmp, &result);
               return result;
               }
         return C_integer i;
         }
      }
   else if cnv:(exact) integer(x) then {
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
   if cnv:(exact)C_integer(x) then {
       body {
          return C_integer x;
          }
      }
   else if cnv:(exact) integer(x) then {
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

/*
 * x + y
 */

#begdef big_Add(x,y)
{
   bigadd(&x,&y,&result);
   return result;
}
#enddef

#begdef Add(x,y)
   irslt = add(x,y);
   if (over_flow) {
      MakeInt(x,&lx);
      MakeInt(y,&ly);
      bigadd(&lx, &ly, &result);
      return result;
      }
   else return C_integer irslt;
#enddef

#define RealAdd(x,y) return C_double (x + y);

ArithOp( + , plus , Add , RealAdd, list_add )



"x ^ y - raise x to the y power."

operator ^ powr(x, y)
   if cnv:(exact)C_integer(y) then {
      if cnv:(exact)integer(x) then {
	 body {
            tended struct descrip ly, result;
	    MakeInt ( y, &ly );
	    if (bigpow(&x, &ly, &result) == Error)
	       runerr(0);
	    return result;
	   }
	 }
      else {
	 if !cnv:C_double(x) then
	    runerr(102, x)
	 body {
            tended struct descrip result;
	    if (ripow( x, y, &result) ==  Error)
	       runerr(0);
	    return result;
	    }
	 }
      }
   else if cnv:(exact)integer(y) then {
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

/*
 * ripow - raise a real number to an integral power.
 */
int ripow(double r, word n, dptr drslt)
   {
   double retval;

   if (r == 0.0 && n <= 0) 
      ReturnErrNum(204, Error);
   if (n < 0) {
      /*
       * r ^ n = ( 1/r ) * ( ( 1/r ) ^ ( -1 - n ) )
       *
       * (-1) - n never overflows, even when n == MinWord.
       */
      n = (-1) - n;
      r = 1.0 / r;
      retval = r;
      }
   else 	
      retval = 1.0;

   /* multiply retval by r ^ n */
   while (n > 0) {
      if (n & 01L)
	 retval *= r;
      r *= r;
      n >>= 1;
      }
   MemProtect(BlkLoc(*drslt) = (union block *)alcreal(retval));
   drslt->dword = D_Real;
   return Succeeded;
   }
