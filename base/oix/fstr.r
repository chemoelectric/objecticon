/*
 * File: fstr.r
 */

static void nxttab(word *col, dptr *tablst, dptr endlst, word *last, word *interval);


"detab(s,i,...) - replace tabs with spaces, with stops at columns indicated."

function detab(s,i[n])
   if !cnv:string_or_ucs(s) then
      runerr(129,s)

   body {
      word last, interval, col, target, j;
      dptr tablst;
      dptr endlst;
      int is_expanded = 0;

      last = 1;
      for (j = 0; j < n; j++) {
          if (!cnv:integer(i[j],i[j]))
              runerr(101,i[j]);
          if (IntVal(i[j]) <= last)
              runerr(210, i[j]);
          last = IntVal(i[j]);
      }
      
      endlst = &i[n];

      if (is:ucs(s)) {
          tended struct descrip utf8;
          word utf8_size, in_count, out_count;
          char *in_p;

          /*
           * Work out the result's length.
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          in_count = out_count = utf8_size = 0;
          in_p = StrLoc(UcsBlk(s).utf8);
          for (in_count = 0; in_count < UcsBlk(s).length; ++in_count) {
              char *pp = in_p;
              int ch = utf8_iter(&in_p);
              if (ch == '\t') {
                  is_expanded = 1;
                  target = col;
                  nxttab(&target, &tablst, endlst, &last, &interval);
                  while (col < target) {
                      utf8_size++;
                      out_count++;
                      col++;
                  }
              } else {
                  utf8_size += in_p - pp;
                  out_count++;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      default:
                          if (ch > 127 || oi_isprint(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }

          /*
           * If no tabs found, return original
           */
          if (!is_expanded)
              return s;

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8);

          /*
           * Do the copy
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          in_count = 0;
          in_p = StrLoc(UcsBlk(s).utf8);
          for (in_count = 0; in_count < UcsBlk(s).length; ++in_count) {
              char *pp = in_p;
              int ch = utf8_iter(&in_p);
              if (ch == '\t') {
                  target = col;
                  nxttab(&target, &tablst, endlst, &last, &interval);
                  while (col < target) {
                      alcstr(" ", 1);
                      col++;
                  }
              } else {
                  alcstr(pp, in_p - pp);
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      default:
                          if (ch > 127 || oi_isprint(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }
          return ucs(make_ucs_block(&utf8, out_count));
      } else {
          char *in, *out, *iend, ch;
          tended struct descrip result;
          word len;

          /*
           * Work out the result's length.
           */
          len = 0;
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          iend = StrLoc(s) + StrLen(s);
          for (in = StrLoc(s); in < iend; ) {
              ch = *in++;
              if (ch == '\t') {
                  is_expanded = 1;
                  target = col;
                  nxttab(&target, &tablst, endlst, &last, &interval);
                  while (col < target) {
                      len++;
                      col++;
                  }
              } else {
                  len++;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      default:
                          if (oi_isprint(ch) || 
                              !oi_isascii(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }

          /*
           * If no tabs found, return original
           */
          if (!is_expanded)
              return s;

          /*
           * Make a descriptor for the result string.
           */
          MakeStrMemProtect(alcstr(NULL, len), len, &result);

          /*
           * Copy the string, expanding tabs.
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          iend = StrLoc(s) + StrLen(s);
          for (in = StrLoc(s), out = StrLoc(result); in < iend; ) {
              ch = *in++;
              if (ch == '\t') {
                  target = col;
                  nxttab(&target, &tablst, endlst, &last, &interval);
                  while (col < target) {
                      *out++ = ' ';
                      col++;
                  }
              } else {
                  *out++ = ch;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      default:
                          if (oi_isprint(ch) || 
                              !oi_isascii(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }
          return result;
      }
   }
end



"entab(s,i,...) - replace spaces with tabs, with stops at columns indicated."

function entab(s,i[n])
   if !cnv:string_or_ucs(s) then
      runerr(129,s)

   body {
      word last, interval, col, target, nt, nt1, j;
      dptr tablst;
      dptr endlst;
      int inserted = 0;

      last = 1;
      for (j = 0; j < n; j++) {
	 if (!cnv:integer(i[j],i[j]))
            runerr(101,i[j]);
         if (IntVal(i[j]) <= last)
            runerr(210, i[j]);
          last = IntVal(i[j]);
      }

      endlst = &i[n];

      if (is:ucs(s)) {
          tended struct descrip utf8;
          word utf8_size, in_count, out_count;
          char *in_p;

          /*
           * Work out the result's length.
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          target = 0;
          in_count = out_count = utf8_size = 0;
          in_p = StrLoc(UcsBlk(s).utf8);
          for (in_count = 0; in_count < UcsBlk(s).length; ++in_count) {
              char *pp = in_p;
              int ch = utf8_iter(&in_p);
              if (ch == ' ') {
                  target = col + 1;
                  while (in_count < UcsBlk(s).length - 1 && *in_p == ' ')
                      in_count++, target++, in_p++;
                  if (target - col > 1) { /* never tab just 1; already copied space */
                      nt = col;
                      nxttab(&nt, &tablst, endlst, &last, &interval);
                      if (nt == col+1) {
                          nt1 = nt;
                          nxttab(&nt1, &tablst, endlst, &last, &interval);
                          if (nt1 > target) {
                              /* keep space to avoid 1-col tab then spaces */
                              utf8_size++;
                              out_count++;
                              col++;	
                              nt = nt1;
                          }
                      }
                      while (nt <= target)  {
                          inserted = 1;
                          /* Add tab */
                          utf8_size++;
                          out_count++;
                          col = nt;
                          nxttab(&nt, &tablst, endlst, &last, &interval);
                      }
                      while (col++ < target) {
                         /* complete gap with spaces */
                          utf8_size++;
                          out_count++;
                      }
                  } else {
                      /* Add space */
                      utf8_size++;
                      out_count++;
                  }
                  col = target;
              } else {
                  utf8_size += in_p - pp;
                  out_count++;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\t':
                          nxttab(&col, &tablst, endlst, &last, &interval);
                          break;
                      case ' ':
                          break;
                      default:
                          if (ch > 127 || oi_isprint(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }

          /*
           * If no tabs inserted, return original
           */
          if (!inserted)
              return s;

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8); 

          /*
           * Do the copy
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          target = 0;
          in_count = 0;
          in_p = StrLoc(UcsBlk(s).utf8);
          for (in_count = 0; in_count < UcsBlk(s).length; ++in_count) {
              char *pp = in_p;
              int ch = utf8_iter(&in_p);
              if (ch == ' ') {
                  target = col + 1;
                  while (in_count < UcsBlk(s).length - 1 && *in_p == ' ')
                      in_count++, target++, in_p++;
                  if (target - col > 1) { /* never tab just 1; already copied space */
                      nt = col;
                      nxttab(&nt, &tablst, endlst, &last, &interval);
                      if (nt == col+1) {
                          nt1 = nt;
                          nxttab(&nt1, &tablst, endlst, &last, &interval);
                          if (nt1 > target) {
                              /* keep space to avoid 1-col tab then spaces */
                              alcstr(" ", 1);
                              col++;	
                              nt = nt1;
                          }
                      }
                      while (nt <= target)  {
                          /* Add tab */
                          alcstr("\t", 1);
                          col = nt;
                          nxttab(&nt, &tablst, endlst, &last, &interval);
                      }
                      while (col++ < target) {
                         /* complete gap with spaces */
                          alcstr(" ", 1);
                      }
                  } else {
                      /* Add space */
                      alcstr(" ", 1);
                  }
                  col = target;
              } else {
                  alcstr(pp, in_p - pp);
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\t':
                          nxttab(&col, &tablst, endlst, &last, &interval);
                          break;
                      case ' ':
                          break;
                      default:
                          if (ch > 127 || oi_isprint(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }
          return ucs(make_ucs_block(&utf8, out_count));
      } else {
          char *in, *out, *iend, ch;
          tended struct descrip result;
          word len;

          /*
           * Work out the result's length.
           */
          len = 0;
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          target = 0;
          iend = StrLoc(s) + StrLen(s);
          for (in = StrLoc(s); in < iend; ) {
              ch = *in++;
              if (ch == ' ') {
                  target = col + 1;
                  while (in < iend && *in == ' ')
                      target++, in++;
                  if (target - col > 1) { /* never tab just 1; already copied space */
                      nt = col;
                      nxttab(&nt, &tablst, endlst, &last, &interval);
                      if (nt == col+1) {
                          nt1 = nt;
                          nxttab(&nt1, &tablst, endlst, &last, &interval);
                          if (nt1 > target) {
                              len++;
                              col++;	/* keep space to avoid 1-col tab then spaces */
                              nt = nt1;
                          }
                      }
                      while (nt <= target)  {
                          inserted = 1;
                          /* Add tab */
                          len++;
                          col = nt;
                          nxttab(&nt, &tablst, endlst, &last, &interval);
                      }
                      while (col++ < target)
                          len++;      /* complete gap with spaces */
                  } else {
                      /* Add space */
                      len++;
                  }
                  col = target;
              } else {
                  len++;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\t':
                          nxttab(&col, &tablst, endlst, &last, &interval);
                          break;
                      default:
                          if (oi_isprint(ch) || 
                              !oi_isascii(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }

          /*
           * If no tabs inserted, return original
           */
          if (!inserted)
              return s;

          /*
           * Make a descriptor for the result string.
           */
          MakeStrMemProtect(alcstr(NULL, len), len, &result); 

          /*
           * Copy the string, looking for runs of spaces.
           */
          last = 1;
          if (n == 0)
              interval = 8;
          tablst = i;
          col = 1;
          target = 0;
          iend = StrLoc(s) + StrLen(s);
          for (in = StrLoc(s), out = StrLoc(result); in < iend; ) {
              ch = *in++;
              if (ch == ' ') {
                  target = col + 1;
                  while (in < iend && *in == ' ')
                      target++, in++;
                  if (target - col > 1) { /* never tab just 1; already copied space */
                      nt = col;
                      nxttab(&nt, &tablst, endlst, &last, &interval);
                      if (nt == col+1) {
                          nt1 = nt;
                          nxttab(&nt1, &tablst, endlst, &last, &interval);
                          if (nt1 > target) {
                              *out++ = ' ';
                              col++;	/* keep space to avoid 1-col tab then spaces */
                              nt = nt1;
                          }
                      }
                      while (nt <= target)  {
                          *out++ = '\t';	/* put tabs to tab positions */
                          col = nt;
                          nxttab(&nt, &tablst, endlst, &last, &interval);
                      }
                      while (col++ < target)
                          *out++ = ' ';		/* complete gap with spaces */
                  } else {
                      /* Add space */
                      *out++ = ' ';
                  }
                  col = target;
              } else {
                  *out++ = ch;
                  switch (ch) {
                      case '\b':
                          col--;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\n':
                      case '\r':
                          col = 1;
                          tablst = i;  /* reset the list of remaining tab stops */
                          last = 1;
                          break;
                      case '\t':
                          nxttab(&col, &tablst, endlst, &last, &interval);
                          break;
                      default:
                          if (oi_isprint(ch) || 
                              !oi_isascii(ch))  /* Assume extended ascii chars are printable */
                              col++;
                  }
              }
          }
          return result;
      }
   }
end

/*
 * nxttab -- helper routine for entab and detab, returns next tab
 *   beyond col
 */

static void nxttab(word *col, dptr *tablst, dptr endlst, word *last, word *interval)
   {
   /*
    * Look for the right tab stop.
    */
   while (*tablst < endlst && *col >= IntVal((*tablst)[0])) {
      ++*tablst;
      if (*tablst == endlst)
         *interval = IntVal((*tablst)[-1]) - *last;
      else {
         *last = IntVal((*tablst)[-1]);
         }
      }
   if (*tablst >= endlst)
      *col = *col + *interval - (*col - *last) % *interval;
   else
      *col = IntVal((*tablst)[0]);
   }

struct mappair { 
    word from, pos;
    int utf8_len;
    char utf8[MAX_UTF8_SEQ_LEN];
};

static int mappair_sort_compare(struct mappair *item1, struct mappair *item2)
{
    if (item1->from == item2->from)
        return item1->pos - item2->pos;
    else
        return item1->from - item2->from;
}

static int mappair_search_compare(int *key, struct mappair *item)
{
    return *key - item->from;
}

"map(s1,s2,s3) - map s1, using s2 and s3."

function map(s1,s2,s3)
   /*
    * s1 must be a string; s2 and s3 default to (string conversions of)
    *  &ucase and &lcase, respectively.
    */
   if !cnv:string_or_ucs(s1) then
      runerr(129,s1)

   body {
      /* Cached 2nd and 3rd arguments */
      static struct descrip maps2,  maps3, maps2u, maps3u;
      static int inited;
      if (!inited) {
          maps2 = nulldesc;
          maps3 = nulldesc;
          maps2u = nulldesc;
          maps3u = nulldesc;
          add_gc_global(&maps2);
          add_gc_global(&maps3);
          add_gc_global(&maps2u);
          add_gc_global(&maps3u);
          inited = 1;
      }

      if (is:null(s2))
         s2 = ucase;
      if (is:null(s3))
         s3 = lcase;

      if (is:ucs(s1)) {
          tended struct descrip utf8;
          static struct staticstr buf = {16 * sizeof(struct mappair)};
          static struct mappair *maptab = 0;
          static word maptab_len = 0;
          char *p1, *p2, *p3;
          word utf8_size, i;

          /*
           * If s2 and s3 are the same as for the last call of map,
           *  the current values in maptab can be used. Otherwise, the
           *  mapping information must be recomputed.
           */
          if (!EqlDesc(maps2u,s2) || !EqlDesc(maps3u,s3)) {
              maps2u = s2;
              maps3u = s3;

              if (!cnv:ucs(s2,s2)) {
                  /* In case &handler is set, note we haven't built maptab */ 
                  maps2u = maps3u = nulldesc;
                  runerr(128,s2);
              }
              if (!cnv:ucs(s3,s3)) {
                  maps2u = maps3u = nulldesc;
                  runerr(128,s3);
              }
              /*
               * s2 and s3 must be of the same length
               */
              if (UcsBlk(s2).length != UcsBlk(s3).length) {
                  maps2u = maps3u = nulldesc;
                  runerr(208);
              }
              maptab_len = UcsBlk(s2).length;
              ssreserve(&buf, maptab_len * sizeof(struct mappair));
              maptab = (struct mappair *)buf.s;

              p2 = StrLoc(UcsBlk(s2).utf8);
              p3 = StrLoc(UcsBlk(s3).utf8);
              for (i = 0; i < maptab_len; ++i) {
                  char *t = p3;
                  maptab[i].pos = i;
                  maptab[i].from = utf8_iter(&p2);
                  p3 += UTF8_SEQ_LEN(*p3);
                  maptab[i].utf8_len = p3 - t;
                  memcpy(maptab[i].utf8, t, p3 - t);
              }

              qsort(maptab, maptab_len, sizeof(struct mappair), (QSortFncCast)mappair_sort_compare);
              /* Now make duplicated entries equate to the last occurence (highest pos) */
              for (i = maptab_len - 1; i > 0; --i) {
                  if (maptab[i].from == maptab[i - 1].from)
                      maptab[i - 1] = maptab[i];
              }
          }

          if (UcsBlk(s1).length == 0)
              return ucs(emptystr_ucs);

          /*
           * Calculate the result's size
           */
          utf8_size = 0;
          p1 = StrLoc(UcsBlk(s1).utf8);
          for (i = 0; i < UcsBlk(s1).length; ++i) {
              char *t = p1;
              int ch = utf8_iter(&p1);
              struct mappair *mp = bsearch(&ch, maptab, maptab_len, 
                                           sizeof(struct mappair), 
                                           (BSearchFncCast)mappair_search_compare);
              if (mp)
                  utf8_size += mp->utf8_len;
              else
                  utf8_size += p1 - t;
          }

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8); 

          /*
           * Build the result
           */
          p1 = StrLoc(UcsBlk(s1).utf8);
          for (i = 0; i < UcsBlk(s1).length; ++i) {
              char *t = p1;
              int ch = utf8_iter(&p1);
              struct mappair *mp = bsearch(&ch, maptab, maptab_len, 
                                           sizeof(struct mappair), 
                                           (BSearchFncCast)mappair_search_compare);
              if (mp)
                  alcstr(mp->utf8, mp->utf8_len);
              else
                  alcstr(t, p1 - t);
          }

          return ucs(make_ucs_block(&utf8, UcsBlk(s1).length));
      } else {
          tended struct descrip result;
          int i;
          word slen;
          char *str1, *str2, *str3;
          static char maptab[256];

          /*
           * If s2 and s3 are the same as for the last call of map,
           *  the current values in maptab can be used. Otherwise, the
           *  mapping information must be recomputed.
           */
          if (!EqlDesc(maps2,s2) || !EqlDesc(maps3,s3)) {
              /* Note we save the arguments before converting to string */
              maps2 = s2;
              maps3 = s3;

              if (!cnv:string(s2,s2)) {
                  /* In case &handler is set, note we haven't built maptab */ 
                  maps2 = maps3 = nulldesc;
                  runerr(103,s2);
              }
              if (!cnv:string(s3,s3)) {
                  maps2 = maps3 = nulldesc;
                  runerr(103,s3);
              }
              /*
               * s2 and s3 must be of the same length
               */
              if (StrLen(s2) != StrLen(s3)) {
                  maps2 = maps3 = nulldesc;
                  runerr(208);
              }

              /*
               * The array maptab is used to perform the mapping.  First,
               *  maptab[i] is initialized with i for i from 0 to 255.
               *  Then, for each character in s2, the position in maptab
               *  corresponding to the value of the character is assigned
               *  the value of the character in s3 that is in the same
               *  position as the character from s2.
               */
              str2 = StrLoc(s2);
              str3 = StrLoc(s3);
              for (i = 0; i <= 255; i++)
                  maptab[i] = i;
              for (slen = 0; slen < StrLen(s2); slen++)
                  maptab[str2[slen]&0377] = str3[slen];
          }

          if (StrLen(s1) == 0) {
              return emptystr;
          }

          /*
           * The result is a string the size of s1; create the result
           *  string, but specify no value for it.
           */
          slen = StrLen(s1);
          MakeStrMemProtect(alcstr(NULL, slen), slen, &result); 
          str1 = StrLoc(s1);
          str2 = StrLoc(result);

          /*
           * Run through the string, using values in maptab to do the
           *  mapping.
           */
          while (slen-- > 0)
              *str2++ = maptab[(*str1++)&0377];

          return result;
      }
    }
end


"repl(s,i) - concatenate i copies of string s."

function repl(s,n)
   if !cnv:string_or_ucs(s) then
      runerr(129,s)

   if !cnv:C_integer(n) then
      runerr(101,n)

   body {
      word slen;

      if (n < 0)
         Irunerr(205,n);


      if (is:ucs(s)) {
          tended struct descrip utf8;
          word utf8_size, i;

          slen = UcsBlk(s).length;
          /*
           * Return an empty string if n is 0 or if s is the empty string.
           */
          if ((n == 0) || (slen==0))
              return ucs(emptystr_ucs);

          /*
           * Make sure the resulting string will not be too long.
           */
          utf8_size = mul(n, StrLen(UcsBlk(s).utf8));
          if (over_flow) 
              Irunerr(205,n);

          /*
           * Make a descriptor for the replicated utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8);

          /*
           * Fill the allocated area with copies of s.
           */
          for (i = 0; i < n; ++i)
              alcstr(StrLoc(UcsBlk(s).utf8), StrLen(UcsBlk(s).utf8));

          return ucs(make_ucs_block(&utf8, n * slen));
      } else {
          word cnt, size;
          char * resloc, * sloc, *floc;
          tended struct descrip result;

          slen = StrLen(s);
          /*
           * Return an empty string if n is 0 or if s is the empty string.
           */
          if ((n == 0) || (slen==0))
              return emptystr;

          /*
           * Make sure the resulting string will not be too long.
           */
          size = mul(n, slen);
          if (over_flow)
              Irunerr(205,n);

          /*
           * Make result a descriptor for the replicated string.
           */
          MemProtect(resloc = alcstr(NULL, size));
          MakeStr(resloc, size, &result);

          /*
           * Fill the allocated area with copies of s.
           */
          sloc = StrLoc(s);
          if (slen == 1)
              memset(resloc, *sloc, size);
          else {
              while (--n >= 0) {
                  floc = sloc;
                  cnt = slen;
                  while (--cnt >= 0)
                      *resloc++ = *floc++;
              }
          }

          return result;
      }
   }
end


"reverse(x) - reverse ucs or string x."

function reverse(s)
   if !cnv:string_or_ucs(s) then
      runerr(129,s)

   body {
       if (is:ucs(s)) {
           tended struct descrip utf8;
           char *p, *q;   /* Don't need to be tended */
           word i;
           MakeStrMemProtect(alcstr(NULL, StrLen(UcsBlk(s).utf8)), StrLen(UcsBlk(s).utf8), &utf8);

           p = StrLoc(UcsBlk(s).utf8);
           q = StrLoc(utf8) + StrLen(utf8);
           i = UcsBlk(s).length;
           while (i-- > 0) {
               int n = UTF8_SEQ_LEN(*p);
               q -= n;
               memcpy(q, p, n);
               p += n;
           }

           return ucs(make_ucs_block(&utf8, UcsBlk(s).length));
       } else {
           tended struct descrip result;
           char c, *floc, *lloc;
           word slen;

           /*
            * Allocate a copy of s.
            */
           slen = StrLen(s);
           MakeStrMemProtect(alcstr(StrLoc(s), slen), slen, &result);

           /*
            * Point floc at the start of s and lloc at the end of s.  Work floc
            *  and sloc along s in opposite directions, swapping the characters
            *  at floc and lloc.
            */
           floc = StrLoc(result);
           lloc = floc + --slen;
           while (floc < lloc) {
               c = *floc;
               *floc++ = *lloc;
               *lloc-- = c;
           }
           return result;
       }
   }
end


"left(s1,i,s2) - pad s1 on right with s2 to length i."

function left(s1,n,s2)
   /*
    * s1 must be a string.  n must be a non-negative integer and defaults
    *  to 1.  s2 must be a string and defaults to a blank.
    */
   if !cnv:string_or_ucs(s1) then
         runerr(129,s1)
   if !def:C_integer(n,1) then
      runerr(101, n)

   body {
      if (n < 0)
         Irunerr(205,n);

      if (is:ucs(s1)) {
          word odd_len, whole_len, utf8_size, i;
          tended struct descrip utf8, odd_utf8;

          if (!def:ucs(s2, *blank_ucs, s2))
              runerr(128, s2);

          /*
           * Simple case if s1 fits exactly.
           */
          if (UcsBlk(s1).length == n)
              return s1;

          /*
           * The padding string is null; make it a blank.
           */
          if (UcsBlk(s2).length == 0)
              MakeDesc(D_Ucs, blank_ucs, &s2);

          /*
           * If we are extracting the left part of a large string (not padding)
           * just construct a substring.
           */
          if (UcsBlk(s1).length > n) 
              return ucs(make_ucs_substring(&UcsBlk(s1), 1, n));

          whole_len = (n - UcsBlk(s1).length) / UcsBlk(s2).length;
          odd_len = (n - UcsBlk(s1).length) % UcsBlk(s2).length;
          /* Last odd_len chars of s2, may be empty string */
          utf8_substr(&UcsBlk(s2), 
                      UcsBlk(s2).length - odd_len + 1,
                      odd_len,
                      &odd_utf8);

          utf8_size = StrLen(UcsBlk(s1).utf8) + 
              StrLen(odd_utf8) +
              StrLen(UcsBlk(s2).utf8) * whole_len;

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8);
          alcstr(StrLoc(UcsBlk(s1).utf8), StrLen(UcsBlk(s1).utf8));
          alcstr(StrLoc(odd_utf8), StrLen(odd_utf8));
          for (i = 0; i < whole_len; ++i)
              alcstr(StrLoc(UcsBlk(s2).utf8), StrLen(UcsBlk(s2).utf8));

          /*
           * The result must have n chars since 
           *  UcsBlk(s1).length + (whole_len * UcsBlk(s2).length + odd_len)
           *  = UcsBlk(s1).length + (n - UcsBlk(s1).length) (see mod calcs above)
           *  = n
           */

          return ucs(make_ucs_block(&utf8, n));
      } else {
          char *s, *st;
          word slen;
          char *sbuf, *s3;

          if (!def:string(s2, blank, s2))
              runerr(103, s2);

          /*
           * The padding string is null; make it a blank.
           */
          if (StrLen(s2) == 0)
              s2 = blank;

          /*
           * If we are extracting the left part of a large string (not padding),
           * just construct a descriptor.
           */
          if (n <= StrLen(s1)) {
              return string(n, StrLoc(s1));
          }

          /*
           * Get n bytes of string space.  Start at the right end of the new
           *  string and copy s2 into the new string as many times as it fits.
           *  Note that s2 is copied from right to left.
           */
          MemProtect(sbuf = alcstr(NULL, n));

          slen = StrLen(s2);
          s3 = StrLoc(s2);
          s = sbuf + n;
          while (s > sbuf) {
              st = s3 + slen;
              while (st > s3 && s > sbuf)
                  *--s = *--st;
          }

          /*
           * Copy up to n bytes of s1 into the new string, starting at the left end
           */
          s = sbuf;
          slen = StrLen(s1);
          st = StrLoc(s1);
          if (slen > n)
              slen = n;
          while (slen-- > 0)
              *s++ = *st++;

          /*
           * Return the new string.
           */
          return string(n, sbuf);
      }

    }
end



"right(s1,i,s2) - pad s1 on left with s2 to length i."

function right(s1,n,s2)
   /*
    * s1 must be a string.  n must be a non-negative integer and defaults
    *  to 1.  s2 must be a string and defaults to a blank.
    */
   if !cnv:string_or_ucs(s1) then
      runerr(129,s1)

   if !def:C_integer(n,1) then
      runerr(101, n)

   body {
      if (n < 0)
         Irunerr(205,n);

      if (is:ucs(s1)) {
          word odd_len, whole_len, utf8_size, i;
          tended struct descrip utf8, odd_utf8;

          if (!def:ucs(s2, *blank_ucs, s2))
              runerr(128, s2);

          /*
           * Simple case if s1 fits exactly.
           */
          if (UcsBlk(s1).length == n)
              return s1;

          /*
           * The padding string is null; make it a blank.
           */
          if (UcsBlk(s2).length == 0)
              MakeDesc(D_Ucs, blank_ucs, &s2);

          /*
           * If we are extracting the right part of a large string (not padding)
           * just construct a substring.
           */
          if (UcsBlk(s1).length > n) 
              return ucs(make_ucs_substring(&UcsBlk(s1), 
                                            UcsBlk(s1).length + 1 - n,
                                            n));

          whole_len = (n - UcsBlk(s1).length) / UcsBlk(s2).length;
          odd_len = (n - UcsBlk(s1).length) % UcsBlk(s2).length;
          /* First odd_len chars of s2, may be empty string */
          utf8_substr(&UcsBlk(s2), 
                      1,
                      odd_len,
                      &odd_utf8);

          utf8_size = StrLen(UcsBlk(s1).utf8) + 
              StrLen(odd_utf8) +
              StrLen(UcsBlk(s2).utf8) * whole_len;

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8);
          for (i = 0; i < whole_len; ++i)
              alcstr(StrLoc(UcsBlk(s2).utf8), StrLen(UcsBlk(s2).utf8));
          alcstr(StrLoc(odd_utf8), StrLen(odd_utf8));
          alcstr(StrLoc(UcsBlk(s1).utf8), StrLen(UcsBlk(s1).utf8));

          /*
           * The result must have n chars since 
           *  UcsBlk(s1).length + (whole_len * UcsBlk(s2).length + odd_len)
           *  = UcsBlk(s1).length + (n - UcsBlk(s1).length) (see mod calcs above)
           *  = n
           */

          return ucs(make_ucs_block(&utf8, n));
      } else {
          char *s, *st;
          word slen;
          char *sbuf, *s3;

          if (!def:string(s2, blank, s2))
              runerr(103, s2);

          /*
           * The padding string is null; make it a blank.
           */
          if (StrLen(s2) == 0)
              s2 = blank;

          /*
           * If we are extracting the right part of a large string (not padding),
           * just construct a descriptor.
           */
          if (n <= StrLen(s1)) {
              return string(n, StrLoc(s1) + StrLen(s1) - n);
          }

          /*
           * Get n bytes of string space.  Start at the left end of the new
           *  string and copy s2 into the new string as many times as it fits.
           */
          MemProtect(sbuf = alcstr(NULL, n));

          slen = StrLen(s2);
          s3 = StrLoc(s2);
          s = sbuf;
          while (s < sbuf + n) {
              st = s3;
              while (st < s3 + slen && s < sbuf + n)
                  *s++ = *st++;
          }

          /*
           * Copy s1 into the new string, starting at the right end and copying
           * s2 from right to left.  If *s1 > n, only copy n bytes.
           */
          s = sbuf + n;
          slen = StrLen(s1);
          st = StrLoc(s1) + slen;
          if (slen > n)
              slen = n;
          while (slen-- > 0)
              *--s = *--st;

          /*
           * Return the new string.
           */
          return string(n, sbuf);
      }
    }
end


"center(s1,i,s2) - pad s1 on left and right with s2 to length i."

function center(s1,n,s2)
   /*
    * s1 must be a string.  n must be a non-negative integer and defaults
    *  to 1.  s2 must be a string and defaults to a blank.
    */
   if !cnv:string_or_ucs(s1) then
      runerr(129,s1)

   if !def:C_integer(n,1) then
      runerr(101, n)

   body {
      if (n < 0)
         Irunerr(205,n);

      if (is:ucs(s1)) {
          word left, right, whole_left_len, odd_left_len,
              whole_right_len, odd_right_len, utf8_size, i;
          tended struct descrip utf8, odd_left_utf8, odd_right_utf8;

          if (!def:ucs(s2, *blank_ucs, s2))
              runerr(128, s2);

          /*
           * Simple case if s1 fits exactly.
           */
          if (UcsBlk(s1).length == n)
              return s1;

          /*
           * The padding string is null; make it a blank.
           */
          if (UcsBlk(s2).length == 0)
              MakeDesc(D_Ucs, blank_ucs, &s2);

          /*
           * If we are extracting the center of a large string (not padding),
           * just construct a substring of length n at pos = 1 + (len-n+1)/2.
           * This is a valid substring since len>n, so len-n+1>1, so pos>2.  Also
           * since len-n+1>1, (len-n+1)/2<(len-n+1), so pos<=(len-n+1),
           * which is a valid start point for a substring of length n.
           */
          if (UcsBlk(s1).length > n)
              return ucs(make_ucs_substring(&UcsBlk(s1), 
                                            1 + (UcsBlk(s1).length - n + 1) / 2,
                                            n));

          left = (n - UcsBlk(s1).length) / 2;
          right = n - UcsBlk(s1).length - left;

          whole_left_len = left / UcsBlk(s2).length;
          odd_left_len = left % UcsBlk(s2).length;

          /* First odd_left_len chars of s2, may be empty string */
          utf8_substr(&UcsBlk(s2), 
                      1,
                      odd_left_len,
                      &odd_left_utf8);

          whole_right_len = right / UcsBlk(s2).length;
          odd_right_len = right % UcsBlk(s2).length;
          /* Last odd_right_len chars of s2, may be empty string */
          utf8_substr(&UcsBlk(s2), 
                      UcsBlk(s2).length - odd_right_len + 1,
                      odd_right_len,
                      &odd_right_utf8);

          utf8_size = StrLen(UcsBlk(s1).utf8) + 
              StrLen(odd_left_utf8) + StrLen(odd_right_utf8) +
              StrLen(UcsBlk(s2).utf8) * (whole_left_len + whole_right_len);

          /*
           * Make a descriptor for the result's utf8 string.
           */
          MakeStrMemProtect(reserve(Strings, utf8_size), utf8_size, &utf8);

          for (i = 0; i < whole_left_len; ++i)
              alcstr(StrLoc(UcsBlk(s2).utf8), StrLen(UcsBlk(s2).utf8));
          alcstr(StrLoc(odd_left_utf8), StrLen(odd_left_utf8));
          alcstr(StrLoc(UcsBlk(s1).utf8), StrLen(UcsBlk(s1).utf8));
          alcstr(StrLoc(odd_right_utf8), StrLen(odd_right_utf8));
          for (i = 0; i < whole_right_len; ++i)
              alcstr(StrLoc(UcsBlk(s2).utf8), StrLen(UcsBlk(s2).utf8));

          /*
           * The result must have n chars since 
           *  UcsBlk(s1).length + (whole_right_len * + UcsBlk(s2).length + odd_right_len) +
           *                           (whole_left_len * UcsBlk(s2).length + odd_left_len) 
           *  = UcsBlk(s1).length + right + left (by mod calcs above)
           *  = n  (since right = n - UcsBlk(s1).length - left by assignment above.)
           */

          return ucs(make_ucs_block(&utf8, n));
      } else {
          char *s, *st;
          word slen;
          char *sbuf, *s3;
          word hcnt;

          if (!def:string(s2,blank,s2))
              runerr(103, s2);

          /*
           * The padding string is null; make it a blank.
           */
          if (StrLen(s2) == 0)
              s2 = blank;

          /*
           * If we are extracting the center of a large string (not padding),
           * just construct a descriptor.
           */
          if (n <= StrLen(s1)) {
              return string(n, StrLoc(s1) + ((StrLen(s1)-n+1)>>1));
          }

          /*
           * Get space for the new string.  Start at the right
           *  of the new string and copy s2 into it from right to left as
           *  many times as will fit in the right half of the new string.
           */
          MemProtect(sbuf = alcstr(NULL, n));

          slen = StrLen(s2);
          s3 = StrLoc(s2);
          hcnt = n / 2;
          s = sbuf + n;
          while (s > sbuf + hcnt) {
              st = s3 + slen;
              while (st > s3 && s > sbuf + hcnt)
                  *--s = *--st;
          }

          /*
           * Start at the left end of the new string and copy s1 into it from
           *  left to right as many time as will fit in the left half of the
           *  new string.
           */
          s = sbuf;
          while (s < sbuf + hcnt) {
              st = s3;
              while (st < s3 + slen && s < sbuf + hcnt)
                  *s++ = *st++;
          }

          slen = StrLen(s1);
          if (n < slen) {
              /*
               * s1 is larger than the field to center it in.  The source for the
               *  copy starts at the appropriate point in s1 and the destination
               *  starts at the left end of of the new string.
               */
              s = sbuf;
              st = StrLoc(s1) + slen/2 - hcnt + (~n&slen&1);
          }
          else {
              /*
               * s1 is smaller than the field to center it in.  The source for the
               *  copy starts at the left end of s1 and the destination starts at
               *  the appropriate point in the new string.
               */
              s = sbuf + hcnt - slen/2 - (~n&slen&1);
              st = StrLoc(s1);
          }
          /*
           * Perform the copy, moving min(*s1,n) bytes from st to s.
           */
          if (slen > n)
              slen = n;
          while (slen-- > 0)
              *s++ = *st++;

          /*
           * Return the new string.
           */
          return string(n, sbuf);
      }
 }
end


"trim(s,c) - trim trailing characters in c from s."

function trim(s,c,ends)

   if !cnv:string_or_ucs(s) then
     runerr(129,s)

   /*
    * c defaults to a cset containing a blank.
    */
   if !def:cset(c, *blankcs) then
      runerr(104, c)

   if !def:C_integer(ends,0) then
      runerr(101, ends)

   body {
      word slen;

      if (is:ucs(s)) {
          char *p, *utf8_start, *utf8_end;
          int ch;
          tended struct descrip utf8;

          slen = UcsBlk(s).length;

          utf8_start = p = StrLoc(UcsBlk(s).utf8);

          /*
           * Left trimming: Start at the beginning of s and then advance StrLoc(s)
           * and decrease the slen until a character that is not in c is found.
           */
          if (ends > -1) {
              while (slen > 0) {
                  utf8_start = p;
                  ch = utf8_iter(&p);
                  if (!in_cset(&CsetBlk(c), ch))
                      break;
                  --slen;
              }
          }

          /*
           * Regular (right) trimming: Start at the end of s and then back up
           * until a character that is not in c is found.
           */
          utf8_end = p = StrLoc(UcsBlk(s).utf8) + StrLen(UcsBlk(s).utf8);
          if (ends < 1) {
              while (slen > 0) {
                  utf8_end = p;
                  ch = utf8_rev_iter(&p);
                  if (!in_cset(&CsetBlk(c), ch))
                      break;
                  --slen;
              }
          }

          if (slen == 0)
              return ucs(emptystr_ucs);

          MakeStr(utf8_start, utf8_end - utf8_start, &utf8);

          return ucs(make_ucs_block(&utf8, slen));
      } else {
          char *sloc;

          slen = StrLen(s);
          /*
           * Left trimming: Start at the beginning of s and then advance StrLoc(s)
           * and decrease the slen until a character that is not in c is found.
           */
          if (ends > -1) {
              sloc = StrLoc(s);
              while (slen > 0 && Testb(*sloc, CsetBlk(c).bits)) {
                  sloc++;
                  slen--;
              }
              StrLoc(s) = sloc;
          }
          /*
           * Regular (right) trimming: Start at the end of s and then back up
           * until a character that is not in c is found.
           */
          if (ends < 1) {
              sloc = StrLoc(s) + slen - 1;
              while (sloc >= StrLoc(s) && Testb(*sloc, CsetBlk(c).bits)) {
                  sloc--;
                  slen--;
              }
          }
          /*
           *  Do the actual trimming by creating a descriptor that
           *  points at a substring of s, but with the length reduced.
           */
          return string(slen, StrLoc(s));
      }
    }
end
