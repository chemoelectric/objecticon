/*
 * cnv.r -- Conversion routines:
 */

/*
 * Prototypes for static functions.
 */
static int cnv_c_dbl_impl(dptr s, double *d);
static int cnv_c_int_impl(dptr s, word *d);
static int cnv_cset_impl(dptr s, dptr d);
static int cnv_ucs_impl(dptr s, dptr d);
static int cnv_str_or_ucs_impl(dptr s, dptr d);
static int cnv_ec_int_impl(dptr s, word *d);
static int cnv_eint_impl(dptr s, dptr d);
static int cnv_int_impl(dptr s, dptr d);
static int cnv_real_impl(dptr s, dptr d);
static int cnv_str_impl(dptr s, dptr d);
static int ston (dptr sp, union numeric *result);
static int cset2string(dptr src, dptr dest);


/*
 * cnv_c_dbl - cnv:C_double(*s, *d), convert a value directly into a C double
 */
int cnv_c_dbl(dptr s, double *d)
{
    if (is:real(*s)) {
        DGetReal(*s, *d);
        return 1;
    } else {
        EVValD(s, E_CnvCDbl);
        return cnv_c_dbl_impl(s, d);
    }
}

/*
 * cnv_c_int - cnv:C_integer(*s, *d), convert a value directly into a word
 */
int cnv_c_int(dptr s, word *d)
{
    if (s->dword == D_Integer) {
        *d = IntVal(*s);
        return 1;
    } else {
        EVValD(s, E_CnvCInt);
        return cnv_c_int_impl(s, d);
    }
}

/*
 * cnv_cset - cnv:cset(*s, *d), convert to a cset
 */
int cnv_cset(dptr s, dptr d)
{
    if (is:cset(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvCset);
        return cnv_cset_impl(s, d);
    }
}

/*
 * cnv_ucs - cnv:ucs(*s, *d), convert to a ucs
 */
int cnv_ucs(dptr s, dptr d)
{
    if (is:ucs(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvUcs);
        return cnv_ucs_impl(s, d);
    }
}

/*
 * cnv_str_or_ucs - cnv:string_or_ucs(*s, *d), convert to a string or ucs type
 */
int cnv_str_or_ucs(dptr s, dptr d)
{
    if (is:string(*s) || is:ucs(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvStrOrUcs);
        return cnv_str_or_ucs_impl(s, d);
    }
}

/*
 * cnv_ec_int - cnv:(exact)C_integer(*s, *d), convert to an exact C integer
 */
int cnv_ec_int(dptr s, word *d)
{
    if (s->dword == D_Integer) {
        *d = IntVal(*s);
        return 1;
    } else {
        EVValD(s, E_CnvECInt);
        return cnv_ec_int_impl(s, d);
    }
}

/*
 * cnv_eint - cnv:(exact)integer(*s, *d), convert to an exact integer
 */
int cnv_eint(dptr s, dptr d)
{
    if (is:integer(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvEInt);
        return cnv_eint_impl(s, d);
    }
}

/*
 * cnv_int - cnv:integer(*s, *d), convert to integer
 */
int cnv_int(dptr s, dptr d)
{
    if (is:integer(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvInt);
        return cnv_int_impl(s, d);
    }
}

/*
 * cnv_real - cnv:real(*s, *d), convert to real
 */
int cnv_real(dptr s, dptr d)
{
    if (is:real(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvReal);
        return cnv_real_impl(s, d);
    }
}

/*
 * cnv_str - cnv:string(*s, *d), convert to a string
 */
int cnv_str(dptr s, dptr d)
{
    if (is:string(*s)) {
        *d = *s;
        return 1;
    } else {
        EVValD(s, E_CnvStr);
        return cnv_str_impl(s, d);
    }
}

static int cset2string(dptr src, dptr dest)
{
    struct b_cset *c = &CsetBlk(*src);  /* Doesn't need to be tended */
    if (c->n_ranges == 0 || c->range[c->n_ranges - 1].to < 256) {
        cset_to_string(c, 1, c->size, dest);
        return 1;
    } else
        return 0;
}

static int cnv_c_dbl_impl(dptr s, double *d)
   {
   tended struct descrip result, cnvstr;

   union numeric numrc;

   type_case *s of {
      real: {
         DGetReal(*s, *d);
         return 1;
         }
      integer: {

         if (Type(*s) == T_Lrgint) {
            if (bigtoreal(s, d) != Succeeded)
               return 0;
         } else
            *d = IntVal(*s);

         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &UcsBlk(*s).utf8;
         }
      cset: {
        if (!cset2string(s, &cnvstr))
           return 0;
        s = &cnvstr;
        }
      default: {
        return 0;
        }
      }

   /*
    * s is now a string.
    */
   switch( ston(s, &numrc) ) {
      case T_Integer:
         *d = numrc.integer;
         return 1;

      case T_Lrgint:
         MakeDesc(D_Lrgint, numrc.big, &result);
         if (bigtoreal(&result, d) != Succeeded)
             return 0;
         return 1;

      case T_Real:
         *d = numrc.real;
         return 1;
      default:
         return 0;
      }
  }

static int cnv_c_int_impl(dptr s, word *d)
{
   tended struct descrip tmp;

   if (cnv_int_impl(s, &tmp) && Type(tmp) == T_Integer) {
       *d = IntVal(tmp);
       return 1;
   } else
       return 0;
}

/*
 * cnv_c_str - cnv:C_string(*s, *d), convert a value into a C (and Icon) string
 */
int cnv_c_str(dptr s, dptr d)
   {
   /*
    * Get the string to the end of the string region and append a '\0'.
    */

   if (is:string(*s)) {
      *d = *s;
      }
   else {
      EVValD(s, E_CnvCStr);
      if (!cnv_str_impl(s, d)) {
         return 0;
         }
      }

   /*
    * See if the end of d is already at the end of the string region
    * and there is room for one more byte.
    */
   if ((StrLoc(*d) + StrLen(*d) == strfree) && (strfree != strend)) {
      MemProtect(alcstr("\0", 1));
      ++StrLen(*d);
      }
   else {
      word slen = StrLen(*d);
      char *sp, *dp;
      MemProtect(dp = alcstr(NULL, slen + 1));
      ++StrLen(*d);
      sp = StrLoc(*d);
      StrLoc(*d) = dp;
      while (slen-- > 0)
         *dp++ = *sp++;
      *dp = '\0';
      }

   return 1;
   }


static int cnv_cset_impl(dptr s, dptr d)
   {
   tended struct descrip str;


   if (is:cset(*s)) {
      *d = *s;
      return 1;
      }

   if (is:ucs(*s)) {
       char *s1;
       struct rangeset *rs;
       word l = UcsBlk(*s).length;
       rs = init_rangeset();
       s1 = StrLoc(UcsBlk(*s).utf8);
       while (l-- > 0) {
           int i = utf8_iter(&s1);
           add_range(rs, i, i);
       }
       MakeDesc(D_Cset, rangeset_to_block(rs), d);
       free_rangeset(rs);
       return 1;
   }

   if (cnv_str_impl(s, &str)) {
       word l;
       char *s1;        /* does not need to be tended */
       struct rangeset *rs;
       rs = init_rangeset();
       s1 = StrLoc(str);
       l = StrLen(str);
       while(l--) {
           int i = *s1++ & 0xff;
           add_range(rs, i, i);
       }
       MakeDesc(D_Cset, rangeset_to_block(rs), d);
       free_rangeset(rs);
       return 1;
     }

     return 0;

  }

static int cnv_ucs_impl(dptr s, dptr d)
{
    tended struct descrip str;

    if (is:ucs(*s)) {
        *d = *s;
        return 1;
    }
    if (is:cset(*s)) {
        MakeDesc(D_Ucs, cset_to_ucs_block(&CsetBlk(*s), 1, CsetBlk(*s).size), d);
        return 1;
    }

    if (cnv_str_impl(s, &str)) {
        char *s1, *e1;
        word n = 0;

        s1 = StrLoc(str);
        e1 = s1 + StrLen(str);

        while (s1 < e1) {
            int i = utf8_check(&s1, e1);
            ++n;
            if (i < 0 || i > MAX_CODE_POINT) {
                return 0;
            }
        }
        MakeDesc(D_Ucs, make_ucs_block(&str, n), d);
        return 1;
    }

    return 0;
}

static int cnv_str_or_ucs_impl(dptr s, dptr d)
{
   type_case *s of {
     string: {
        *d = *s;
        return 1;
       }
     ucs: {
        *d = *s;
        return 1;
       }
     cset: {
        return cnv_str_impl(s, d) || cnv_ucs_impl(s, d);
      }
     default: {
        return cnv_str_impl(s, d);
      }
   }
}

/*
 * Return 1 if cnv_str_or_ucs above would result in a ucs; return 0
 * otherwise.
 */
int need_ucs(dptr s)
{
   type_case *s of {
     ucs: {
        return 1;
       }
     cset: {
           struct b_cset *c = &CsetBlk(*s);  /* Doesn't need to be tended */
           if (c->n_ranges == 0 || c->range[c->n_ranges - 1].to < 256)
               return 0;
           else
               return 1;
      }
     default: {
         return 0;
      }
   }
}

static int cnv_ec_int_impl(dptr s, word *d)
{
   tended struct descrip tmp;

   if (cnv_eint_impl(s, &tmp) && Type(tmp) == T_Integer) {
       *d = IntVal(tmp);
       return 1;
   } else
       return 0;
}

static int cnv_eint_impl(dptr s, dptr d)
   {
   tended struct descrip cnvstr; /* tended since ston allocates blocks */
   union numeric numrc;

   type_case *s of {
      integer: {
         *d = *s;
         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &UcsBlk(*s).utf8;
         }
      cset: {
       if (!cset2string(s, &cnvstr))
           return 0;
        s = &cnvstr;
        }
      default: {
        return 0;
        }
      }

   /*
    * s is now a string.
    */
   switch (ston(s, &numrc)) {
      case T_Integer:
         MakeInt(numrc.integer, d);
	 return 1;

      case T_Lrgint:
         MakeDesc(D_Lrgint, numrc.big, d);
         return 1;

      default:
         return 0;
      }
   }

static int cnv_int_impl(dptr s, dptr d)
   {
   tended struct descrip cnvstr; /* tended since ston allocates blocks */
   union numeric numrc;

   type_case *s of {
      integer: {
         *d = *s;
         return 1;
         }
      real: {
         double dbl;
         DGetReal(*s,dbl);
         if (dbl > MaxWord || dbl < MinWord) {

            if (realtobig(s, d) == Succeeded) {
               return 1;
               }
            else {
               return 0;
               }
	    }
         MakeInt((word)dbl,d);
         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &UcsBlk(*s).utf8;
         }
      cset: {
        if (!cset2string(s, &cnvstr)) {
           return 0;
        }
        s = &cnvstr;
        }
      default: {
         return 0;
         }
      }

   /*
    * s is now a string.
    */
   switch( ston(s, &numrc) ) {

      case T_Lrgint:
         MakeDesc(D_Lrgint, numrc.big, d);
	 return 1;

      case T_Integer:
         MakeInt(numrc.integer,d);
         return 1;
      case T_Real: {
         double dbl = numrc.real;
         if (dbl > MaxWord || dbl < MinWord) {

            if (realtobig(s, d) == Succeeded) {
               return 1;
               }
            else {
               return 0;
               }
	    }
         MakeInt((word)dbl,d);
         return 1;
         }
      default:
         return 0;
      }
   }

static int cnv_real_impl(dptr s, dptr d)
   {
   double dbl;

   if (is:real(*s)) {
      *d = *s;
      return 1;
   }
   else if (cnv_c_dbl_impl(s, &dbl)) {
      MakeReal(dbl, d);
      return 1;
      }
   else
      return 0;
   }

static int cnv_str_impl(dptr s, dptr d)
   {

   type_case *s of {
      string: {
         *d = *s;
         return 1;
         }
     ucs: {
           *d = UcsBlk(*s).utf8;
           return 1;
       }
      integer: {

         if (Type(*s) == T_Lrgint) {
	    bigtos(s,d);
            return 1;
          }
         else {
            cstr2string(word2cstr(IntVal(*s)), d);
            return 1;
         }
       }
      real: {
         double res;
         DGetReal(*s, res);
         cstr2string(double2cstr(res), d);
         return 1;
         }
     cset: {
           if (cset2string(s, d)) {
               return 1;
           } else {
               return 0;
           }
      }

      default: {
         return 0;
         }
      }
   }


static void deref_tvsubs(dptr s, dptr d)
{
    tended struct b_tvsubs *tvsub;
    tended struct descrip v;

    /*
     * A substring trapped variable is being dereferenced.
     *  Point tvsub to the trapped variable block and v to
     *  the string.
     */
    tvsub = &TvsubsBlk(*s);
    deref(&tvsub->ssvar, &v);
    type_case v of {
      string: {
            if (tvsub->sspos + tvsub->sslen - 1 > StrLen(v))
                fatalerr(205, NULL);
            /*
             * Make a descriptor for the substring by getting the
             *  length and pointing into the string.
             */
            MakeStr(StrLoc(v) + tvsub->sspos - 1, tvsub->sslen, d);
        }
      ucs: {
            if (tvsub->sspos + tvsub->sslen - 1 > UcsBlk(v).length)
                fatalerr(205, NULL);
            MakeDesc(D_Ucs, make_ucs_substring(&UcsBlk(v), 
                                               tvsub->sspos, 
                                               tvsub->sslen),  d);
        }
      default: {
            fatalerr(129, &v);
        }
    }
}

static void deref_tvtbl(dptr s, dptr d)
{
   /*
    * no allocation is done, so nothing need be tended.
    */
    struct b_tvtbl *bp;
    union block **ep;
    int res;

    /*
     * Look up the element in the table.
     */
    bp = &TvtblBlk(*s);
    ep = memb(bp->clink, &bp->tref, bp->hashnum, &res);
    if (res)
        *d = (*ep)->telem.tval;			/* found; use value */
    else
        *d = bp->clink->table.defvalue;	/* nope; use default */
}


#begdef deref_macro(f, e_deref)
/*
 * deref - dereference a descriptor.
 */
void f(dptr s, dptr d)
   {

   EVValD(s, e_deref);

   if (!is:variable(*s))
      *d = *s;
   else type_case *s of {
      named_var:
         *d = *VarLoc(*s);

      struct_var:
         *d = *OffsetVarLoc(*s);

      tvsubs:
         deref_tvsubs(s, d);

      tvtbl:
         deref_tvtbl(s, d);

      kywdint:
      kywdpos:
      kywdsubj:
      kywdany:
      kywdhandler:
      kywdstr:
         *d = *VarLoc(*s);

      default:
         syserr("Unknown variable type");
      }
   }
#enddef

deref_macro(deref_0,0)
deref_macro(deref_1,E_Deref)


/*
 * ston - convert a string to a numeric quantity if possible.
 * Returns a typecode or CvtFail.  Its answer is in the dptr,
 * unless its a double, in which case its in the union numeric
 * (we do this to avoid allocating a block for a real
 * that will later be used directly as a C_double).
 */
static int ston(dptr sp, union numeric *result)
   {
   char *s = StrLoc(*sp), *end_s;
   int c;
   int realflag = 0;	/* indicates a real number */
   char msign = '+';    /* sign of mantissa */
   char esign = '+';    /* sign of exponent */
   double mantissa = 0; /* scaled mantissa with no fractional part */
   word lresult = 0;	/* integer result */
   int scale = 0;	/* number of decimal places to shift mantissa */
   int digits = 0;	/* total number of digits seen */
   int sdigits = 0;	/* number of significant digits seen */
   int exponent = 0;	/* exponent part of real number */
   double fiveto;	/* holds 5^scale */
   double power;	/* holds successive squares of 5 to compute fiveto */
   int err_no;
   char *ssave;         /* holds original ptr for bigradix */

   if (StrLen(*sp) == 0)
      return CvtFail;
   end_s = s + StrLen(*sp);
   c = *s++;

   /*
    * Skip leading white space.
    */
   while (oi_isspace(c))
      if (s < end_s)
         c = *s++;
      else
         return CvtFail;

   /*
    * Check for sign.
    */
   if (c == '+' || c == '-') {
      msign = c;
      c = (s < end_s) ? *s++ : ' ';
      }

   ssave = s - 1;   /* set pointer to beginning of digits in case it's needed */

   /*
    * Get integer part of mantissa.
    */
   while (oi_isdigit(c)) {
      digits++;
      if (mantissa < Big) {
	 mantissa = mantissa * 10 + (c - '0');
         lresult = lresult * 10 + (c - '0');
	 if (mantissa > 0.0)
	    sdigits++;
	 }
      else
	 scale++;
      c = (s < end_s) ? *s++ : ' ';
      }

   /*
    * Check for based integer.
    */
   if (c == 'r' || c == 'R') {
      tended struct descrip sd;
      MakeStr(s, end_s-s, &sd);
      return bigradix((int)msign, (int)mantissa, &sd, result);
      }

   /*
    * Get fractional part of mantissa.
    */
   if (c == '.') {
      realflag++;
      c = (s < end_s) ? *s++ : ' ';
      while (oi_isdigit(c)) {
	 digits++;
	 if (mantissa < Big) {
	    mantissa = mantissa * 10 + (c - '0');
	    lresult = lresult * 10 + (c - '0');
	    scale--;
	    if (mantissa > 0.0)
	       sdigits++;
	    }
         c = (s < end_s) ? *s++ : ' ';
	 }
      }

   /*
    * Check that at least one digit has been seen so far.
    */
   if (digits == 0)
      return CvtFail;

   /*
    * Get exponent part.
    */
   if (c == 'e' || c == 'E') {
      realflag++;
      c = (s < end_s) ? *s++ : ' ';
      if (c == '+' || c == '-') {
	 esign = c;
         c = (s < end_s) ? *s++ : ' ';
	 }
      if (!oi_isdigit(c))
	 return CvtFail;
      while (oi_isdigit(c)) {
	 exponent = exponent * 10 + (c - '0');
         c = (s < end_s) ? *s++ : ' ';
	 }
      scale += (esign == '+') ? exponent : -exponent;
      }

   /*
    * Skip trailing white space and make sure there is nothing else left
    *  in the string. Note, if we have already reached end-of-string,
    *  c has been set to a space.
    */
   while (oi_isspace(c) && s < end_s)
      c = *s++;
   if (!oi_isspace(c))
      return CvtFail;

   /*
    * Test for integer.
    */
   if (!realflag && !scale && mantissa >= MinWord && mantissa <= MaxWord) {
      result->integer = (msign == '+' ? lresult : -lresult);
      return T_Integer;
      }

   /*
    * Test for bignum.
    */
      if (!realflag) {
         tended struct descrip sd;
         MakeStr(ssave, end_s-ssave, &sd);
         return bigradix((int)msign, 10, &sd, result);
         }

   /*
    * Rough tests for overflow and underflow.
    */
   if (sdigits + scale > LogHuge)
      return CvtFail;

   if (sdigits + scale < -LogHuge) {
      result->real = 0.0;
      return T_Real;
      }

   /*
    * Put the number together by multiplying the mantissa by 5^scale and
    *  then using ldexp() to multiply by 2^scale.
    */

   exponent = (scale > 0)? scale : -scale;
   fiveto = 1.0;
   power = 5.0;
   for (;;) {
      if (exponent & 01)
	 fiveto *= power;
      exponent >>= 1;
      if (exponent == 0)
	 break;
      power *= power;
      }
   if (scale > 0)
      mantissa *= fiveto;
   else
      mantissa /= fiveto;

   err_no = 0;
   mantissa = ldexp(mantissa, scale);
   if (err_no > 0 && mantissa > 0)
      /*
       * ldexp caused overflow.
       */
      return CvtFail;

   if (msign == '-')
      mantissa = -mantissa;
   result->real = mantissa;
   return T_Real;
   }


/*
 * cvpos - convert position to strictly positive position
 *  given length.  The returned value is >= 1 and <= len+1
 */

word cvpos(word pos, word len)
{
   /*
    * Make sure the position is within range.
    */
   if (pos < -len || pos > len + 1)
      return CvtFail;
   /*
    * If the position is greater than zero, just return it.  Otherwise,
    *  convert the zero/negative position.
    */
   if (pos > 0)
      return pos;
   return (len + pos + 1);
}

/*
 * As above, but disallow the rightmost position (ie, position zero).  The
 * returned value is >= 1 and <= len
 */
word cvpos_item(word pos, word len)
{
   /*
    * Make sure the position is within range.
    */
   if (pos < -len || pos > len || pos == 0)
      return CvtFail;
   /*
    * If the position is greater than zero, just return it.  Otherwise,
    *  convert the negative position.
    */
   if (pos > 0)
      return pos;
   return (len + pos + 1);
}

/*
 * Convert a slice of the form i:j into the corresponding positions,
 * based on the given len.  On success, i is replaced by the lower
 * position, j the higher.
 */
int cvslice(word *i, word *j, word len)
{
    word p1, p2;
    p1 = cvpos(*i, len);
    if (p1 == CvtFail)
        return Failed;
    p2 = cvpos(*j, len);
    if (p2 == CvtFail)
        return Failed;
    if (p1 > p2) {
        *i = p2;
        *j = p1;
    } else {
        *i = p1;
        *j = p2;
    }
    return Succeeded;
}
