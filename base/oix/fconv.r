/*
 * fconv.r -- abs, cset, integer, numeric, proc, real, string.
 */

"abs(N) - produces the absolute value of N."

function{1} abs(n)
   /*
    * If n is convertible to a (large or small) integer or real,
    * this code returns -n if n is negative
    */
   if cnv:(exact)C_integer(n) then {
      abstract {
         return integer
         }
      inline {
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
      abstract {
         return integer
         }
      inline {
	 if (BlkLoc(n)->bignum.sign == 0)
	    result = n;
	 else {
             bigneg(&n, &result);
	    }
         return result;
         }
      }

   else if cnv:C_double(n) then {
      abstract {
         return real
         }
      inline {

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
function{0,1} t(x)

   if cnv:t(x) then {
      abstract {
         return t
         }
      inline {
         return x;
         }
      }
   else {
      abstract {
         return empty_type
         }
      inline {
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

function{0,1} text(x)
  body {
    if (cnv:string_or_ucs(x,x))
        return x;
    else
        fail;
   }
end


"numeric(x) - produces an integer or real number resulting from the "
"type conversion of x, but fails if the conversion is not possible."

function{0,1} numeric(n)

   if cnv:(exact)integer(n) then {
      abstract {
         return integer
         }
      inline {
         return n;
         }
      }
   else if cnv:real(n) then {
      abstract {
         return real
         }
      inline {
         return n;
         }
      }
   else {
      abstract {
         return empty_type
         }
      inline {
         fail;
         }
      }
end


"proc(x,i) - convert x to a procedure if possible; use i to resolve "
"ambiguous string names."

function{0,1} proc(x,i,c)

   if is:coexpr(x) then {
      if !def:C_integer(i, 1) then
         runerr(101, i)
      abstract {
         return proc
         }
      body {
	 struct b_coexpr *ce = NULL;
	 struct b_proc *bp = NULL;
	 struct pf_marker *fp;
	 dptr dp=NULL;
	 if (BlkLoc(x) != (union block *)k_current) {
	    ce = (struct b_coexpr *)BlkLoc(x);
	    dp = ce->es_argp;
	    fp = ce->es_pfp;
	    if (dp == NULL) fail;
	    }
	 else {
	    fp = pfp;
	    dp = argp;
	    }
	 /* follow upwards, i levels */
	 while (i--) {
	    if (fp == NULL) fail;
	    dp = fp->pf_argp;
	    fp = fp->pf_pfp;
	    }
	 if (fp == NULL) fail;
	 if (dp)
	    bp = (struct b_proc *)BlkLoc(*(dp));
	 else fail;
	 return proc(bp);
	 }
      }

   if is:proc(x) then {
      abstract {
         return proc
         }
      inline {

	 if (!is:null(c)) {
	    struct progstate *p;
	    if (!is:coexpr(c)) runerr(118,c);
	    /*
	     * Test to see whether a given procedure belongs to a given
	     * program.
	     */
	    p = BlkLoc(c)->coexpr.program;
	    if (p != BlkLoc(x)->proc.program)
	       fail;
	    }
         return x;
         }
      }

   else if cnv:tmp_string(x) then {
      /*
       * i must be 0, 1, 2, or 3; it defaults to 1.
       */
      if !def:C_integer(i, 1) then
         runerr(101, i)
      inline {
         if (i < 0 || i > 3) {
            irunerr(205, i);
            errorfail;
            }
         }   

      abstract {
         return proc
         }
      inline {
         struct b_proc *prc;

	 struct progstate *prog;

         if (is:null(c))
             prog = curpstate;
         else if (is:coexpr(c))
             prog = BlkLoc(c)->coexpr.program;
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
      abstract {
         return empty_type
         }
      inline {
         fail;
         }
      }
end
