/*
 * File: fstranl.r
 * String analysis functions: any,bal,find,many,match,upto
 *
 * str_anal is a macro for performing the standard conversions and
 *  defaulting for string analysis functions. It takes as arguments the
 *  parameters for subject, beginning position, and ending position. It
 *  produces declarations for these 3 names prepended with cnv_. These
 *  variables will contain the converted versions of the arguments.
 */
#begdef str_anal(s, i, j)
   declare {
      C_integer cnv_ ## i;
      C_integer cnv_ ## j;
      int slen;
      }

   body {   

   if (is:null(s)) {
      s = k_subject;
      if (is:null(i))
         cnv_ ## i = k_pos;
   } else {
      if (!cnv:string_or_ucs(s,s))
         runerr(129,s);
      if (is:null(i))
         cnv_ ## i = 1;
   }

   type_case s of {
      string: slen = StrLen(s);
      ucs: slen = UcsBlk(s).length;
      default: runerr(129,s);
   }
      
   if (!is:null(i)) {
      if (cnv:C_integer(i,cnv_ ## i)) {
         if ((cnv_ ## i = cvpos(cnv_ ## i, slen)) == CvtFail)
            fail;
      }
      else
         runerr(101,i);
   }

   if (is:null(j))
       cnv_ ## j = slen + 1;
   else if (cnv:C_integer(j,cnv_ ## j)) {
       if ((cnv_ ## j = cvpos(cnv_ ## j, slen)) == CvtFail)
          fail;
       if (cnv_ ## i > cnv_ ## j) {
          register C_integer tmp;
          tmp = cnv_ ## i;
          cnv_ ## i = cnv_ ## j;
          cnv_ ## j = tmp;
       }
   }
   else
       runerr(101,j);


   }
#enddef


"any(c,s,i1,i2) - produces min(i1,i2)+1 if s[min(i1,i2)] is contained "
"in c and i1 ~= i2, but fails otherwise."

function any(c,s,i,j)
   str_anal( s, i, j )
   if !cnv:cset(c) then
      runerr(104,c)
   body {
      if (cnv_i == cnv_j)
         fail;
      if (is:string(s)) {
         if (!Testb(StrLoc(s)[cnv_i-1], CsetBlk(c).bits))
            fail;
      } else {
          if (!in_cset(&CsetBlk(c), ucs_char(&UcsBlk(s), cnv_i)))
            fail;
      }
      return C_integer cnv_i+1;
      }
end


"bal(c1,c2,c3,s,i1,i2) - generates the sequence of integer positions in s up to"
" a character of c1 in s[i1:i2] that is balanced with respect to characters in"
" c2 and c3, but fails if there is no such position."

function bal(c1,c2,c3,s,i,j)
   str_anal( s, i, j )
   if !def:cset(c1, *k_cset) then
      runerr(104,c1)
   if !def:cset(c2, *lparcs) then
      runerr(104,c2)
   if !def:cset(c3, *rparcs) then
      runerr(104,c3)

   body {
      C_integer cnt;

      /*
       * Loop through characters in s[i:j].  When a character in c2
       * is found, increment cnt; when a character in c3 is found, decrement
       * cnt.  When cnt is 0 there have been an equal number of occurrences
       * of characters in c2 and c3, i.e., the string to the left of
       * i is balanced.  If the string is balanced and the current character
       * (s[i]) is in c, suspend with i.  Note that if cnt drops below
       *  zero, bal fails.
       */
      cnt = 0;

      if (is:string(s)) {
          while (cnv_i < cnv_j) {
              char c = StrLoc(s)[cnv_i-1];
              if (cnt == 0 && Testb(c, CsetBlk(c1).bits)) {
                  suspend C_integer cnv_i;
              }
              if (Testb(c, CsetBlk(c2).bits))
                  cnt++;
              else if (Testb(c, CsetBlk(c3).bits))
                  cnt--;
              if (cnt < 0)
                  fail;
              cnv_i++;
          }
      } else {
          tended char *p = ucs_utf8_ptr(&UcsBlk(s), cnv_i);
          while (cnv_i < cnv_j) {
              int c = utf8_iter(&p);
              if (cnt == 0 && in_cset(&CsetBlk(c1), c))
                  suspend C_integer cnv_i;
              if (in_cset(&CsetBlk(c2), c))
                  cnt++;
              else if (in_cset(&CsetBlk(c3), c))
                  cnt--;
              if (cnt < 0)
                  fail;
              cnv_i++;
          }
      }

      /*
       * Eventually fail.
       */
      fail;
      }
end


"find(s1,s2,i1,i2) - generates the sequence of positions in s2 at which "
"s1 occurs as a substring in s2[i1:i2], but fails if there is no such position."

function find(s1,s2,i,j)
   str_anal( s2, i, j )

   body {
      char *str1, *str2;
      C_integer s1_len, l, term;

      if (is:string(s2)) {
          if (!cnv:string(s1,s1))
              runerr(103,s1);

          /*
           * Loop through s2[i:j] trying to find s1 at each point, stopping
           * when the remaining portion s2[i:j] is too short to contain s1.
           * Optimize me!
           */
          s1_len = StrLen(s1);
          term = cnv_j - s1_len;
          while (cnv_i <= term) {
              str1 = StrLoc(s1);
              str2 = StrLoc(s2) + cnv_i - 1;
              l    = s1_len;

              /*
               * Compare strings on a byte-wise basis; if the end is reached
               * before inequality is found, suspend with the position of the
               * string.
               */
              do {
                  if (l-- <= 0) {
                      suspend C_integer cnv_i;
                      break;
                  }
              } while (*str1++ == *str2++);
              cnv_i++;
          }
      } else {
          if (!cnv:ucs(s1,s1))
              runerr(128,s1);

          /*
           * Loop through s2[i:j] trying to find s1 at each point, stopping
           * when the remaining portion s2[i:j] is too short to contain s1.
           * Optimize me!
           */
          s1_len = UcsBlk(s1).length;
          term = cnv_j - s1_len;
          while (cnv_i <= term) {
              str1 = StrLoc(UcsBlk(s1).utf8);
              str2 = ucs_utf8_ptr(&UcsBlk(s2), cnv_i);
              l    = s1_len;

              /*
               * Compare strings on a byte-wise basis; if the end is reached
               * before inequality is found, suspend with the position of the
               * string.
               */
              do {
                  if (l-- <= 0) {
                      suspend C_integer cnv_i;
                      break;
                  }
              } while (utf8_iter(&str1) == utf8_iter(&str2));
              cnv_i++;
          }
      }

      fail;
   }
end


"many(c,s,i1,i2) - produces the position in s after the longest initial "
"sequence of characters in c in s[i1:i2] but fails if there is none."

function many(c,s,i,j)
   str_anal( s, i, j )
   if !cnv:cset(c) then
      runerr(104,c)
   body {
      C_integer start_i = cnv_i;
      /*
       * Move i along s[i:j] until a character that is not in c is found
       *  or the end of the string is reached.
       */
      if (is:string(s)) {
          while (cnv_i < cnv_j) {
              if (!Testb(StrLoc(s)[cnv_i-1], CsetBlk(c).bits))
                  break;
              cnv_i++;
          }
      } else {
          char *p = ucs_utf8_ptr(&UcsBlk(s), cnv_i);
          while (cnv_i < cnv_j) {
              int ch = utf8_iter(&p);
              if (!in_cset(&CsetBlk(c), ch))
                  break;
              cnv_i++;
          }
      }

      /*
       * Fail if no characters in c were found; otherwise
       *  return the position of the first character not in c.
       */
      if (cnv_i == start_i)
         fail;
      return C_integer cnv_i;
      }
end


"match(s1,s2,i1,i2) - produces i1+*s1 if s1==s2[i1+:*s1], but fails otherwise."

function match(s1,s2,i,j)
   str_anal( s2, i, j )
   body {
      char *str1, *str2;

      if (is:string(s2)) {
          if (!cnv:tmp_string(s1,s1))
              runerr(103,s1);

          /*
           * Cannot match unless s2[i:j] is as long as s1.
           */
          if (cnv_j - cnv_i < StrLen(s1))
              fail;

          /*
           * Compare s1 with s2[i:j] for *s1 characters; fail if an
           *  inequality is found.
           */
          str1 = StrLoc(s1);
          str2 = StrLoc(s2) + cnv_i - 1;
          for (cnv_j = StrLen(s1); cnv_j > 0; cnv_j--)
              if (*str1++ != *str2++)
                  fail;

          /*
           * Return position of end of matched string in s2.
           */
          return C_integer cnv_i + StrLen(s1);
      } else {
          if (!cnv:ucs(s1,s1))
              runerr(128,s1);

          /*
           * Cannot match unless s2[i:j] is as long as s1.
           */
          if (cnv_j - cnv_i < UcsBlk(s1).length)
              fail;

          /*
           * Compare s1 with s2[i:j] for *s1 characters; fail if an
           *  inequality is found.
           */
          str1 = StrLoc(UcsBlk(s1).utf8);
          str2 = ucs_utf8_ptr(&UcsBlk(s2), cnv_i);
          for (cnv_j = UcsBlk(s1).length; cnv_j > 0; cnv_j--)
              if (utf8_iter(&str1) != utf8_iter(&str2))
                  fail;

          /*
           * Return position of end of matched string in s2.
           */
          return C_integer cnv_i + UcsBlk(s1).length;
      }
   }
end


"upto(c,s,i1,i2) - generates the sequence of integer positions in s up to a "
"character in c in s[i2:i2], but fails if there is no such position."

function upto(c,s,i,j)
   str_anal( s, i, j )
   if !cnv:cset(c) then
      runerr(104,c)
   body {
      if (is:string(s)) {
          /*
           * Look through s[i:j] and suspend position of each occurrence of
           * of a character in c.
           */
          while (cnv_i < cnv_j) {
              char ch = StrLoc(s)[cnv_i-1];
              if (Testb(ch, CsetBlk(c).bits)) 
                  suspend C_integer cnv_i;

              cnv_i++;
          }
      } else {
          tended char *p = ucs_utf8_ptr(&UcsBlk(s), cnv_i);
          /*
           * Look through s[i:j] and suspend position of each occurrence of
           * of a character in c.
           */
          while (cnv_i < cnv_j) {
              int ch = utf8_iter(&p);
              if (in_cset(&CsetBlk(c), ch))
                  suspend C_integer cnv_i;

              cnv_i++;
          }
      }

      /*
       * Eventually fail.
       */
      fail;
      }
end
