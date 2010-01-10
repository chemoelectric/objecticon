/*
 * fmath.r -- sin, cos, tan, acos, asin, atan, dtor, rtod, exp, log, sqrt
 */

/*
 * Most of the math ops are simple calls to underlying C functions,
 * sometimes with additional error checking to avoid and/or detect
 * various C runtime errors.
 */
#begdef MathOp(funcname,ccode,comment,pre,post)
#funcname "(r)" comment
function funcname(x)

   if !cnv:C_double(x) then
      runerr(102, x)

   body {
      double y;
      pre		/* Pre math-operation range checking */
      errno = 0;
      y = ccode(x);
      post		/* Post math-operation C library error detection */
      return C_double y;
      }
end
#enddef


#define aroundone if (x < -1.0 || x > 1.0) {drunerr(205, x); errorfail;}
#define positive  if (x < 0)               {drunerr(205, x); errorfail;}

#define erange    if (errno == ERANGE)     runerr(204);
#define edom      if (errno == EDOM)       runerr(205);

MathOp(util_Math_sin, sin,  ", x in radians.", ;, ;)
MathOp(util_Math_cos, cos,  ", x in radians.", ;, ;)
MathOp(util_Math_tan, tan,  ", x in radians.", ; , erange)
MathOp(util_Math_acos,acos, ", x in radians.", aroundone, edom)
MathOp(util_Math_asin,asin, ", x in radians.", aroundone, edom)
MathOp(util_Math_exp, exp,  " - e^x.", ; , erange)
MathOp(util_Math_sqrt,sqrt, " - square root of x.", positive, edom)
#define DTOR(x) ((x) * Pi / 180)
#define RTOD(x) ((x) * 180 / Pi)
MathOp(util_Math_dtor,DTOR, " - convert x from degrees to radians.", ; , ;)
MathOp(util_Math_rtod,RTOD, " - convert x from radians to degrees.", ; , ;)



"atan(r1,r2) -- r1, r2  in radians; if r2 is present, produces atan2(r1,r2)."

function util_Math_atan(x,y)

   if !cnv:C_double(x) then
      runerr(102, x)

   if is:null(y) then
      body {
         return C_double atan(x);
         }
   if !cnv:C_double(y) then
      runerr(102, y)
   body {
      return C_double atan2(x,y);
      }
end


"log(r1,r2) - logarithm of r1 to base r2."

function util_Math_log(x,b)

   if !cnv:C_double(x) then
      runerr(102, x)

   body {
      if (x <= 0.0) {
         drunerr(205, x);
         errorfail;
         }
      }
   if is:null(b) then
      body {
         return C_double log(x);
         }
   else {
      if !cnv:C_double(b) then
         runerr(102, b)
      body {
         static double lastbase = 0.0;
         static double divisor;

         if (b <= 1.0) {
            drunerr(205, b);
            errorfail;
            }
         if (b != lastbase) {
            divisor = log(b);
            lastbase = b;
            }
	 x = log(x) / divisor;
         return C_double x;
         }  
      }
end

"max(x,y,...) - return the maximum of the arguments"

function max(argv[argc])
   body {
      int i;
      struct descrip dtmp;
      if (argc == 0) 
          fail;
      dtmp = argv[0];
      for(i = 1; i < argc; i++) {
          if (anycmp(&dtmp, argv+i) < 0) 
              dtmp = argv[i];
      }
      return dtmp;
   }
end


"min(x,y,...) - return the minimum of the arguments"

function min(argv[argc])
   body {
      int i;
      struct descrip dtmp;
      if (argc == 0) 
          fail;
      dtmp = argv[0];
      for(i = 1; i < argc; i++) {
          if (anycmp(&dtmp, argv+i) > 0) 
              dtmp = argv[i];
      }
      return dtmp;
   }
end
