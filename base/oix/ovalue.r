/*
 * File: ovalue.r
 */

"\\x - test x for nonnull value."

operator \ nonnull(underef x -> dx)
   /*
    * If the dereferenced value dx is not null, the pre-dereferenced
    *  x is returned, otherwise, the function fails.
    */
   if is:null(dx) then
      body {
         fail;
         }
   else {
      body {
         return x;
         }
      }
end



"/x - test x for null value."

operator / null(underef x -> dx)
   /*
    * If the dereferenced value dx is null, the pre-derefereneced value
    *  x is returned, otherwise, the function fails.
    */
   if is:null(dx) then {
      body {
         return x;
         }
      }
   else
      body {
         fail;
      }
end


".x - produce value of x."

operator . value(x)
  body {
     return x;
     }
end


"x & y - produce value of y."

operator & conj(underef x, underef y)
   body {
      return y;
      }
end
