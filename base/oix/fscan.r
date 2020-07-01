/*
 * File: fscan.r
 */

"move(i) - move &pos by i, return substring of &subject spanned."
" Reverses effects if resumed."

function move(i)

   if !cnv:C_integer(i) then
      runerr(101, i)

   body {
       word j, oldpos;

      /*
       * Save old &pos.  Local variable j holds &pos before the move.
       */
      oldpos = j = k_pos;

      if (is:string(k_subject)) {
          /*
           * If attempted move is past either end of the string, fail.
           */
          if (i + j <= 0 || i + j > StrLen(k_subject) + 1)
              fail;

          /*
           * Set new &pos.
           */
          k_pos += i;

          /*
           * Make sure i >= 0.
           */
          if (i < 0) {
              j += i;
              i = -i;
          }

          /*
           * Suspend substring of &subject that was moved over.
           */
          suspend string(i, StrLoc(k_subject) + j - 1);
      } else {
          /*
           * If attempted move is past either end of the string, fail.
           */
          if (i + j <= 0 || i + j > UcsBlk(k_subject).length + 1)
              fail;

          /*
           * Set new &pos.
           */
          k_pos += i;

          /*
           * Make sure i >= 0.
           */
          if (i < 0) {
              j += i;
              i = -i;
          }

          /*
           * Suspend substring of &subject that was moved over.
           */
          LazySuspend(ucs(make_ucs_substring(&UcsBlk(k_subject), j, i)));
      }

      /*
       * If move is resumed, restore the old position and fail.  Note that the type of
       * &subject may have changed since we suspended.
       */

      if (is:string(k_subject))
          j = StrLen(k_subject);
      else
          j = UcsBlk(k_subject).length;

      if (oldpos > j + 1)
          Irunerr(205, oldpos);
      else
          k_pos = oldpos;

      fail;
   }
end


"pos(i) - test if &pos is at position i in &subject."

function pos(i)

   if !cnv:C_integer(i) then
      runerr(101, i)

   body {
      if (is:string(k_subject)) {
          /*
           * Fail if &pos is not equivalent to i, return i otherwise.
           */
          if ((i = cvpos(i, StrLen(k_subject))) != k_pos)
              fail;
      } else {
          /*
           * Fail if &pos is not equivalent to i, return i otherwise.
           */
          if ((i = cvpos(i, UcsBlk(k_subject).length)) != k_pos)
              fail;
      }

      return C_integer i;
      }
end


"tab(i) - set &pos to i, return substring of &subject spanned."
"Reverses effects if resumed."

function tab(i)

   if !cnv:C_integer(i) then
      runerr(101, i);

   body {
      word j, t, oldpos;

      if (is:string(k_subject)) {
          /*
           * Convert i to an absolute position.
           */
          i = cvpos(i, StrLen(k_subject));
          if (i == CvtFail)
              fail;

          /*
           * Save old &pos.  Local variable j holds &pos before the tab.
           */
          oldpos = j = k_pos;

          /*
           * Set new &pos.
           */
          k_pos = i;

          /*
           *  Make i the length of the substring &subject[i:j]
           */
          if (j > i) {
              t = j;
              j = i;
              i = t - j;
          }
          else
              i = i - j;

          /*
           * Suspend the portion of &subject that was tabbed over.
           */
          suspend string(i, StrLoc(k_subject) + j - 1);
      } else {
          /*
           * Convert i to an absolute position.
           */
          i = cvpos(i, UcsBlk(k_subject).length);
          if (i == CvtFail)
              fail;

          /*
           * Save old &pos.  Local variable j holds &pos before the tab.
           */
          oldpos = j = k_pos;

          /*
           * Set new &pos.
           */
          k_pos = i;

          /*
           *  Make i the length of the substring &subject[i:j]
           */
          if (j > i) {
              t = j;
              j = i;
              i = t - j;
          }
          else
              i = i - j;

          /*
           * Suspend the portion of &subject that was tabbed over.
           */
          LazySuspend(ucs(make_ucs_substring(&UcsBlk(k_subject), j, i)));
      }

      /*
       * If tab is resumed, restore the old position and fail.  Note that the type of
       * &subject may have changed since we suspended.
       */

      if (is:string(k_subject))
          j = StrLen(k_subject);
      else
          j = UcsBlk(k_subject).length;

      if (oldpos > j + 1)
          Irunerr(205, oldpos);
      else
          k_pos = oldpos;

      fail;
   }
end
