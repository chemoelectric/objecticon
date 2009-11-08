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


"proc(x,i) - convert x to a procedure if possible; use i to resolve "
"ambiguous string names."

function proc(x,i,c)

   if is:proc(x) then {
      body {
         return x;
         }
      }

   else if cnv:tmp_string(x) then {
      /*
       * i must be 0, 1, 2, or 3; it defaults to 1.
       */
      if !def:C_integer(i, 1) then
         runerr(101, i)
      body {
         if (i < 0 || i > 3) {
            irunerr(205, i);
            errorfail;
            }
         }   

      body {
         struct b_proc *prc;

	 struct progstate *prog;

         if (is:null(c))
             prog = curpstate;
         else if (is:coexpr(c))
             prog = get_current_program_of(&CoexprBlk(c));
         else
             runerr(118, c);

         /*
          * Attempt to convert Arg0 to a procedure descriptor using i to
          *  discriminate between procedures with the same names.  If i
          *  is zero, only check builtins and ignore user procedures.
          *  Fail if the conversion isn't successful.
          */
	 if (i == 0)
            prc = bi_strprc(&x, 0);
	 else 
             prc = strprc(&x, i, prog);

         if (prc == NULL)
            fail;
         else
            return proc(prc);
         }
      }
   else {
      body {
         fail;
         }
      }
end
