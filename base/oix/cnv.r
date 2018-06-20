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
static int numeric_via_string (dptr sp, dptr result);


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
    if (IsCInteger(*s)) {
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
    if (IsCInteger(*s)) {
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


static int cnv_c_dbl_impl(dptr s, double *d)
   {
   tended struct descrip num;

   type_case *s of {
      real: {
         DGetReal(*s, *d);
         return 1;
         }
      integer: {
         if (IsLrgint(*s))
             return bigtoreal(s, d);
         else {
            *d = IntVal(*s);
            return 1;
            }
         }
      default: {
        if (numeric_via_string(s, &num))
            return cnv_c_dbl_impl(&num, d);
        else
           return 0;
        }
     }
  }

static int cnv_c_int_impl(dptr s, word *d)
{
   tended struct descrip tmp;

   if (cnv_int_impl(s, &tmp) && IsCInteger(tmp)) {
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

   type_case *s of {
     cset: {
      *d = *s;
      return 1;
      }

     ucs: {
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

     default: {
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
        } else
           return 0;
     }
   }
 }

static int cnv_ucs_impl(dptr s, dptr d)
{
   tended struct descrip str;

   type_case *s of {
     ucs: {
        *d = *s;
        return 1;
     }

     cset: {
        MakeDesc(D_Ucs, cset_to_ucs_block(&CsetBlk(*s), 1, CsetBlk(*s).size), d);
        return 1;
     }

     default: {
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
        } else
            return 0;
     }
   }
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

   if (cnv_eint_impl(s, &tmp) && IsCInteger(tmp)) {
       *d = IntVal(tmp);
       return 1;
   } else
       return 0;
}

static int cnv_eint_impl(dptr s, dptr d)
   {
   tended struct descrip num;

   type_case *s of {
      integer: {
         *d = *s;
         return 1;
         }
      real: {
         return 0;
         }
      default: {
         if (numeric_via_string(s, &num) )
            return cnv_eint_impl(&num, d);
         else
           return 0;
        }
      }
   }

static int cnv_int_impl(dptr s, dptr d)
   {
   tended struct descrip num;

   type_case *s of {
      integer: {
         *d = *s;
         return 1;
         }
      real: {
         double dbl;
         DGetReal(*s,dbl);
         return realtobig(dbl, d);
         }
      default: {
         if (numeric_via_string(s, &num) )
             return cnv_int_impl(&num, d);
         else
            return 0;
         }
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
         if (IsLrgint(*s))
	    bigtos(s, d);
         else
            cstr2string(word2cstr(IntVal(*s)), d);
         return 1;
       }
      real: {
         double res;
         DGetReal(*s, res);
         cstr2string(double2cstr(res), d);
         return 1;
         }
      cset: {
           struct b_cset *c = &CsetBlk(*s);  /* Doesn't need to be tended */
           if (c->n_ranges == 0 || c->range[c->n_ranges - 1].to < 256) {
               cset_to_string(c, 1, c->size, d);
               return 1;
           } else
               return 0;
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
 * Try to convert an arbitrary descriptor to a numeric by first trying
 * to convert it to a string, and then, if successful, trying to parse
 * that string to get a numeric.  Returns 0 if either stage
 * fails.  On success result will contain either a real descriptor, a
 * large integer block descriptor or a normal integer descriptor.
 */
static int numeric_via_string(dptr src, dptr result)
   {
   static struct staticstr buf = {64};
   tended struct descrip str;
   char *s, *end_s, *ep;
   char msign = '+';    /* sign of mantissa */
   word lresult = 0;	/* integer result */
   char *ssave;         /* holds original ptr for bigradix */
   int digits = 0;	/* number of digits seen */
   double d;

   if (!cnv_str_impl(src, &str))
       return 0;

   s = StrLoc(str);
   end_s = s + StrLen(str);

   /*
    * Skip leading white space.
    */
   while (s < end_s && oi_isspace(*s))
       ++s;

   /*
    * Check for sign.
    */
   if (s < end_s && (*s == '+' || *s == '-'))
      msign = *s++;

   ssave = s;   /* set pointer to beginning of digits in case it's needed */

   /*
    * Get integer part
    */
   over_flow = 0;
   while (s < end_s && oi_isdigit(*s)) {
       if (!over_flow) {
           lresult = mul(lresult, 10);
           if (!over_flow)
               lresult = add(lresult, *s - '0');
       }
       ++digits;
       ++s;
   }

   /*
    * Check for based integer.
    */
   if (s < end_s && (*s == 'r' || *s == 'R')) {
      if (over_flow || lresult < 2 || lresult > 36)
	 return 0;
      ++s; /* move over R */
      MakeStr(s, end_s - s, &str);
      return bigradix(msign, lresult, &str, result);
      }


   while (s < end_s && oi_isspace(*s))
       ++s;

   if (s == end_s) {
       /* Check we had some digits */
       if (!digits)
           return 0;
       /* Base 10 integer or large integer */
       if (over_flow) {
           MakeStr(ssave, end_s - ssave, &str);
           return bigradix(msign, 10, &str, result);
       } else {
           MakeInt(msign == '+' ? lresult : -lresult, result);
           return 1;
       }
   }

   ssreserve(&buf, StrLen(str) + 1);
   memcpy(buf.s, StrLoc(str), StrLen(str));
   buf.s[StrLen(str)] = 0;
   d = strtod(buf.s, &ep);
   if (!isfinite(d))
       return 0;

   /*
    * Check only spaces remain.  We don't check that *ep is null,
    * since the icon string may have contained an invalid \0
    * character.
    */
   s = StrLoc(str) + (ep - buf.s);
   while (s < end_s && oi_isspace(*s))
       ++s;
   if (s < end_s)
       return 0;

   MakeReal(d, result);
   return 1;
   }

/*
 * cvpos - convert position to strictly positive position
 *  given length.  The returned value is >= 1 and <= len+1,
 *  or CvtFail on failure.
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
 * returned value is >= 1 and <= len, or CvtFail on failure.
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
 * position, j the higher.  Returns a boolean value.
 */
int cvslice(word *i, word *j, word len)
{
    word p1, p2;
    p1 = cvpos(*i, len);
    if (p1 == CvtFail)
        return 0;
    p2 = cvpos(*j, len);
    if (p2 == CvtFail)
        return 0;
    if (p1 > p2) {
        *i = p2;
        *j = p1;
    } else {
        *i = p1;
        *j = p2;
    }
    return 1;
}
