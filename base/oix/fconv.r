/*
 * fconv.r -- abs, cset, integer, numeric, proc, real, string.
 */

"abs(N) - produces the absolute value of N."

function abs(n)
   /*
    * If n is convertible to a (large or small) integer or real,
    * this code returns -n if n is negative
    */
   if cnv:(exact)C_integer(n) then {
      body {
	 C_integer i;

	 if (n >= 0)
	    i = n;
	 else {
	    i = neg(n);
	    if (over_flow) {
               tended struct descrip result;
	       struct descrip tmp;
	       MakeInt(n,&tmp);
	       bigneg(&tmp, &result);
               return result;
	       }
	    }
         return C_integer i;
         }
      }


   else if cnv:(exact)integer(n) then {
      body {
         tended struct descrip result;
	 if (BignumBlk(n).sign == 0)
	    result = n;
	 else {
             bigneg(&n, &result);
	    }
         return result;
         }
      }

   else if cnv:C_double(n) then {
      body {

#if SASC
         return C_double __builtin_fabs(n);
#else
         return C_double Abs(n);
#endif					/* SASC */

         }
      }
   else
      runerr(102,n)
end


/*
 * The convertible types cset, integer, and real are identical
 *  enough to be expansions of a single macro, parameterized by type.
 */
#begdef ReturnYourselfAs(t)
#t "(x) - produces a value of type " #t " resulting from the conversion of x, "
   "but fails if the conversion is not possible."
function t(x)

   if cnv:t(x) then {
      body {
         return x;
         }
      }
   else {
      body {
         fail;
         }
      }
end

#enddef

ReturnYourselfAs(cset)     /* cset(x) - convert to cset or fail */
ReturnYourselfAs(integer)  /* integer(x) - convert to integer or fail */
ReturnYourselfAs(real)     /* real(x) - convert to real or fail */
ReturnYourselfAs(ucs)      /* ucs(x) - convert to ucs or fail */
ReturnYourselfAs(string)   /* string(x) - convert to string or fail */


"text(x) - if x is a string or ucs, it is just returned.  If x is a cset then it is"
"converted to a string if its highest char is < 256; otherwise it is converted"
"to a ucs.  For any other type, normal string conversion is attempted."

function text(x)
  body {
    if (cnv:string_or_ucs(x,x))
        return x;
    else
        fail;
   }
end


"numeric(x) - produces an integer or real number resulting from the "
"type conversion of x, but fails if the conversion is not possible."

function numeric(n)

   if cnv:(exact)integer(n) then {
      body {
         return n;
         }
      }
   else if cnv:real(n) then {
      body {
         return n;
         }
      }
   else {
      body {
         fail;
         }
      }
end


