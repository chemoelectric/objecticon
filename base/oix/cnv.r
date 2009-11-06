/*
 * cnv.r -- Conversion routines:
 *
 * cnv_c_dbl, cnv_c_int, cnv_c_str, cnv_cset, cnv_ec_int,
 * cnv_eint, cnv_int, cnv_real, cnv_str, cnv_tcset, cnv_tstr, deref,
 * getdbl, strprc, bi_strprc
 *
 * Service routines: itos, ston, radix, cvpos
 *
 * Philosophy: certain redundancy is present which could be avoided,
 * and nested conversion calls are avoided due to the importance of
 * minimizing these routines' costs.
 *
 * Assumed: the C compiler must handle assignments of C integers to
 * C double variables and vice-versa.  Hopefully production C compilers
 * have managed to eliminate bugs related to these assignments.
 */


/*
 * Prototypes for static functions.
 */
static void itos (C_integer num, dptr dp, char *s);
static int ston (dptr sp, union numeric *result);

static int cset2str(dptr src, dptr dest)
{
    struct b_cset *c = &BlkLoc(*src)->cset;  /* Doesn't need to be tended */
    if (c->n_ranges == 0 || c->range[c->n_ranges - 1].to < 256) {
        cset_to_str(c, 1, c->size, dest);
        return 1;
    } else
        return 0;
}

/*
 * cnv_c_dbl - cnv:C_double(*s, *d), convert a value directly into a C double
 */
int cnv_c_dbl(s, d)
dptr s;
double *d;
   {
   tended struct descrip result, cnvstr;

   union numeric numrc;

   type_case *s of {
      real: {
         GetReal(BlkLoc(*s)->real, *d);
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
          s = &BlkLoc(*s)->ucs.utf8;
         }
      cset: {
        if (!cset2str(s, &cnvstr))
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
         result.dword = D_Lrgint;
	 BlkLoc(result) = (union block *)numrc.big;
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

/*
 * cnv_c_int - cnv:C_integer(*s, *d), convert a value directly into a C_integer
 */
int cnv_c_int(s, d)
dptr s;
C_integer *d;
   {
   tended struct descrip cnvstr, result;
   union numeric numrc;

   type_case *s of {
      integer: {

         if (Type(*s) == T_Lrgint) {
            return 0;
            }

         *d = IntVal(*s);
         return 1;
         }
      real: {
         double dbl;
         GetReal(BlkLoc(*s)->real,dbl);
         if (dbl > MaxWord || dbl < MinWord) {
            return 0;
            }
         *d = dbl;
         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &BlkLoc(*s)->ucs.utf8;
         }
      cset: {
        if (!cset2str(s, &cnvstr))
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
      case T_Integer: {
         *d = numrc.integer;
         return 1;
	 }
      case T_Real: {
         double dbl = numrc.real;
         if (dbl > MaxWord || dbl < MinWord) {
            return 0;
            }
         *d = dbl;
         return 1;
         }
      default:
         return 0;
      }
   }

/*
 * cnv_c_str - cnv:C_string(*s, *d), convert a value into a C (and Icon) string
 */
int cnv_c_str(s, d)
dptr s;
dptr d;
   {
   /*
    * Get the string to the end of the string region and append a '\0'.
    */

   if (!is:string(*s)) {
      if (!cnv_str(s, d)) {
         return 0;
         }
      }
   else {
      *d = *s;
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
      register word slen = StrLen(*d);
      register char *sp, *dp;
      MemProtect(dp = alcstr(NULL,slen+1));
      StrLen(*d) = StrLen(*d)+1;
      sp = StrLoc(*d);
      StrLoc(*d) = dp;
      while (slen-- > 0)
         *dp++ = *sp++;
      *dp = '\0';
      }

   return 1;
   }


#begdef cnv_cset_macro(f,e_aconv,e_tconv,e_nconv,e_sconv,e_fconv)
/*
 * cnv_cset - cnv:cset(*s, *d), convert to a cset
 */
int f(dptr s, dptr d)
   {
   tended struct descrip str;

   EVValD(s, e_aconv);
   EVValD(&csetdesc, e_tconv);

   if (is:cset(*s)) {
      *d = *s;
      EVValD(s, e_nconv);
      return 1;
      }

   if (is:ucs(*s)) {
       char *s1;
       struct rangeset *rs;
       int l = BlkLoc(*s)->ucs.length;
       MemProtect(rs = init_rangeset());
       s1 = StrLoc(BlkLoc(*s)->ucs.utf8);
       while (l-- > 0) {
           int i = utf8_iter(&s1);
           MemProtect(add_range(rs, i, i));
       }
       d->dword = D_Cset;
       BlkLoc(*d) = (union block *)rangeset_to_block(rs);
       free_rangeset(rs);
       return 1;
   }

   if (cnv:string(*s, str)) {
       C_integer l;
       char *s1;        /* does not need to be tended */
       struct rangeset *rs;
       MemProtect(rs = init_rangeset());
       s1 = StrLoc(str);
       l = StrLen(str);
       while(l--) {
           int i = *s1++ & 0xff;
           MemProtect(add_range(rs, i, i));
       }
       d->dword = D_Cset;
       BlkLoc(*d) = (union block *)rangeset_to_block(rs);
       free_rangeset(rs);
       return 1;
     }

     return 0;

  }
#enddef

cnv_cset_macro(cnv_cset_0,0,0,0,0,0)
cnv_cset_macro(cnv_cset_1,E_Aconv,E_Tconv,E_Nconv,E_Sconv,E_Fconv)

#begdef cnv_ucs_macro(f,e_aconv,e_tconv,e_nconv,e_sconv,e_fconv)
/*
 * cnv_ucs - cnv:ucs(*s, *d), convert to a ucs
 */
int f(dptr s, dptr d)
{
    tended struct descrip str;

    if (is:ucs(*s)) {
        *d = *s;
        return 1;
    }
    if (is:cset(*s)) {
        tended struct b_ucs *p;
        p = cset_to_ucs_block(&BlkLoc(*s)->cset, 1, BlkLoc(*s)->cset.size);
        d->dword = D_Ucs;
        BlkLoc(*d) = (union block *)p;
        return 1;
    }

    if (cnv:string(*s, str)) {
        tended struct b_ucs *p;
        char *s1, *e1;
        word n = 0;

        s1 = StrLoc(str);
        e1 = s1 + StrLen(str);

        while (s1 < e1) {
            char *t = s1;
            int i = utf8_check(&s1, e1);
            ++n;
            if (i < 0 || i > MAX_CODE_POINT) {
                whyf("Invalid utf-8 at sequence beginning at char %d", 1 + (t - StrLoc(str)));
                return 0;
            }
        }
        p = make_ucs_block(&str, n);
        d->dword = D_Ucs;
        BlkLoc(*d) = (union block *)p;
        return 1;
    }

    return 0;
}
#enddef

cnv_ucs_macro(cnv_ucs_0,0,0,0,0,0)
cnv_ucs_macro(cnv_ucs_1,E_Aconv,E_Tconv,E_Nconv,E_Sconv,E_Fconv)

/*
 * cnv_str_or_ucs - cnv:string_or_ucs(*s, *d), convert to a string or ucs type
 */
int cnv_str_or_ucs(dptr s, dptr d)
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
        return cnv_str(s, d) || cnv_ucs(s, d);
      }
     default: {
        return cnv_str(s, d);
      }
   }
}

/*
 * cnv_ec_int - cnv:(exact)C_integer(*s, *d), convert to an exact C integer
 */
int cnv_ec_int(s, d)
dptr s;
C_integer *d;
   {
   tended struct descrip cnvstr; /* tended since ston allocates blocks */
   union numeric numrc;

   type_case *s of {
      integer: {

         if (Type(*s) == T_Lrgint) {
            return 0;
            }
         *d = IntVal(*s);
         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &BlkLoc(*s)->ucs.utf8;
         }
      cset: {
        if (!cset2str(s, &cnvstr))
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
   if (ston(s, &numrc) == T_Integer) {
      *d = numrc.integer;
      return 1;
      }
   else {
      return 0;
      }
   }

/*
 * cnv_eint - cnv:(exact)integer(*s, *d), convert to an exact integer
 */
int cnv_eint(s, d)
dptr s, d;
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
          s = &BlkLoc(*s)->ucs.utf8;
         }
      cset: {
       if (!cset2str(s, &cnvstr))
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
         d->dword = D_Lrgint;
	 BlkLoc(*d) = (union block *)numrc.big;
         return 1;

      default:
         return 0;
      }
   }

#begdef cnv_int_macro(f,e_aconv,e_tconv,e_nconv,e_fconv,e_sconv)
/*
 * cnv_int - cnv:integer(*s, *d), convert to integer
 */
int f(s, d)
dptr s, d;
   {
   tended struct descrip cnvstr; /* tended since ston allocates blocks */
   union numeric numrc;

   EVValD(s, e_aconv);
   EVValD(&zerodesc, e_tconv);

   type_case *s of {
      integer: {
         *d = *s;
         EVValD(s, e_nconv);
         return 1;
         }
      real: {
         double dbl;
         GetReal(BlkLoc(*s)->real,dbl);
         if (dbl > MaxWord || dbl < MinWord) {

            if (realtobig(s, d) == Succeeded) {
               EVValD(d, e_sconv);
               return 1;
               }
            else {
               EVValD(s, e_fconv);
               return 0;
               }
	    }
         MakeInt((word)dbl,d);
         EVValD(d, e_sconv);
         return 1;
         }
      string: {
         /* fall through */
         }
      ucs: {
          s = &BlkLoc(*s)->ucs.utf8;
         }
      cset: {
        if (!cset2str(s, &cnvstr))
            return 0;
        s = &cnvstr;
        }
      default: {
         EVValD(s, e_fconv);
         return 0;
         }
      }

   /*
    * s is now a string.
    */
   switch( ston(s, &numrc) ) {

      case T_Lrgint:
         d->dword = D_Lrgint;
	 BlkLoc(*d) = (union block *)numrc.big;
         EVValD(d, e_sconv);
	 return 1;

      case T_Integer:
         MakeInt(numrc.integer,d);
         EVValD(d, e_sconv);
         return 1;
      case T_Real: {
         double dbl = numrc.real;
         if (dbl > MaxWord || dbl < MinWord) {

            if (realtobig(s, d) == Succeeded) {
               EVValD(d, e_sconv);
               return 1;
               }
            else {
               EVValD(s, e_fconv);
               return 0;
               }
	    }
         MakeInt((word)dbl,d);
         EVValD(d, e_sconv);
         return 1;
         }
      default:
         EVValD(s, e_fconv);
         return 0;
      }
   }
#enddef

cnv_int_macro(cnv_int_0,0,0,0,0,0)
cnv_int_macro(cnv_int_1,E_Aconv,E_Tconv,E_Nconv,E_Fconv,E_Sconv)

#begdef cnv_real_macro(f,e_aconv,e_tconv,e_sconv,e_fconv)
/*
 * cnv_real - cnv:real(*s, *d), convert to real
 */
int f(dptr s, dptr d)
   {
   double dbl;

   EVValD(s, e_aconv);
   EVValD(&rzerodesc, e_tconv);

   if (cnv_c_dbl(s, &dbl)) {
      MemProtect(BlkLoc(*d) = (union block *)alcreal(dbl));
      d->dword = D_Real;
      EVValD(d, e_sconv);
      return 1;
      }
   else
      EVValD(s, e_fconv);
      return 0;
   }
#enddef

cnv_real_macro(cnv_real_0,0,0,0,0)
cnv_real_macro(cnv_real_1,E_Aconv,E_Tconv,E_Sconv,E_Fconv)


#begdef cnv_str_macro(f, e_aconv, e_tconv, e_nconv, e_sconf, e_fconv)
/*
 * cnv_str - cnv:string(*s, *d), convert to a string
 */
int f(dptr s, dptr d)
   {
   char sbuf[MaxCvtLen];

   EVValD(s, e_aconv);
   EVValD(&emptystr, e_tconv);

   type_case *s of {
      string: {
         *d = *s;
         EVValD(s, e_nconv);
         return 1;
         }
     ucs: {
           *d = BlkLoc(*s)->ucs.utf8;
           return 1;
       }
      integer: {

         if (Type(*s) == T_Lrgint) {
            word slen;
            word dlen;
            slen = (BlkLoc(*s)->bignum.lsd - BlkLoc(*s)->bignum.msd +1);
            dlen = slen * NB * 0.3010299956639812;	/* 1 / log2(10) */
	    bigtos(s,d);
            return 1;
          }
         else
            itos(IntVal(*s), d, sbuf);
       }
      real: {
         double res;
         GetReal(BlkLoc(*s)->real, res);
         rtos(res, d, sbuf);
         }
     cset: {
         return cset2str(s, d);
      }

      default: {
         EVValD(s, e_fconv);
         return 0;
         }
      }
   MemProtect(StrLoc(*d) = alcstr(StrLoc(*d), StrLen(*d)));
   EVValD(d, e_sconv);
   return 1;
   }
#enddef

cnv_str_macro(cnv_str_0,0,0,0,0,0)
cnv_str_macro(cnv_str_1,E_Aconv,E_Tconv,E_Nconv,E_Sconv,E_Fconv)


#begdef cnv_tstr_macro(f,e_aconv,e_tconv,e_nconv,e_sconv,e_fconv)
/*
 * cnv_tstr - cnv:tmp_string(*s, *d), convert to a temporary string
 */
int f(char *sbuf, dptr s, dptr d)
   {
   type_case *s of {
      string:
         *d = *s;
      ucs:
         *d = BlkLoc(*s)->ucs.utf8;
      integer: {
         if (Type(*s) == T_Lrgint) {
            word slen;
            word dlen;

            slen = (BlkLoc(*s)->bignum.lsd - BlkLoc(*s)->bignum.msd +1);
            dlen = slen * NB * 0.3010299956639812;	/* 1 / log2(10) */
	    bigtos(s,d);
           }
         else
            itos(IntVal(*s), d, sbuf);
      }
      real: {
         double res;
         GetReal(BlkLoc(*s)->real, res);
         rtos(res, d, sbuf);
         }
     cset: {
        if (!cset2str(s, d))
           return 0;
      }
      default:
         return 0;
      }
   return 1;
   }
#enddef

static void deref_tvsubs(dptr s, dptr d)
{
    tended union block *bp;
    tended struct descrip v;

    /*
     * A substring trapped variable is being dereferenced.
     *  Point bp to the trapped variable block and v to
     *  the string.
     */
    bp = BlkLoc(*s);
    deref(&bp->tvsubs.ssvar, &v);
    type_case v of {
      string: {
            if (bp->tvsubs.sspos + bp->tvsubs.sslen - 1 > StrLen(v))
                fatalerr(205, NULL);
            /*
             * Make a descriptor for the substring by getting the
             *  length and pointing into the string.
             */
            StrLen(*d) = bp->tvsubs.sslen;
            StrLoc(*d) = StrLoc(v) + bp->tvsubs.sspos - 1;
        }
      ucs: {
            if (bp->tvsubs.sspos + bp->tvsubs.sslen - 1 > BlkLoc(v)->ucs.length)
                fatalerr(205, NULL);
            d->dword = D_Ucs;
            BlkLoc(*d) = (union block *)make_ucs_substring(&BlkLoc(v)->ucs, 
                                                           bp->tvsubs.sspos, 
                                                           bp->tvsubs.sslen);
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
    union block *bp;
    union block **ep;
    int res;

    /*
     * Look up the element in the table.
     */
    bp = BlkLoc(*s);
    ep = memb(bp->tvtbl.clink,&bp->tvtbl.tref,bp->tvtbl.hashnum,&res);
    if (res == 1)
        *d = (*ep)->telem.tval;			/* found; use value */
    else
        *d = bp->tvtbl.clink->table.defvalue;	/* nope; use default */
}

cnv_tstr_macro(cnv_tstr_0,0,0,0,0,0)
cnv_tstr_macro(cnv_tstr_1,E_Aconv,E_Tconv,E_Nconv,E_Sconv,E_Fconv)

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
 * getdbl - return as a double the value inside a real block.
 */
double getdbl(dp) 
dptr dp;
   {
   double d;
   GetReal(BlkLoc(*dp)->real, d);
   return d;
   }

/*
 * dp_pnmcmp - do a string comparison of a descriptor to the procedure 
 *   name in a pstrnm struct; used in call to bsearch().
 */
static int dp_pnmcmp(dptr dp, struct b_proc **e)
{
    return lexcmp(dp, (*e)->name);
}

/*
 * bi_strprc - convert a string to a (built-in) function or operator.
 */
struct b_proc *bi_strprc(s, arity)
dptr s;
C_integer arity;
   {
   C_integer i;
   struct b_proc **pp;

   if (!StrLen(*s))
      return NULL;

   /*
    * See if the string represents an operator. In this case the arity
    *  of the operator must match the one given.
    */
   if (!isalpha((unsigned char)*StrLoc(*s)) && *StrLoc(*s) != '&') {
      for (i = 0; i < op_tbl_sz; ++i)
          if (eq(s, op_tbl[i]->name) && arity == op_tbl[i]->nparam)
	    return op_tbl[i];
      return NULL;
      }

   /*
    * See if the string represents a built-in function.
    */
   pp = (struct b_proc **)bsearch(s, fnc_tbl, fnc_tbl_sz,
                                  sizeof(struct b_proc *), 
                                  (BSearchFncCast)dp_pnmcmp);
   if (pp)
       return *pp;

   /*
    * See if the string represents a keyword function.
    */
   pp = (struct b_proc **)bsearch(s, keyword_tbl, keyword_tbl_sz,
                                  sizeof(struct b_proc *), 
                                  (BSearchFncCast)dp_pnmcmp);
   if (pp)
       return *pp;

   return NULL;
   }

/*
 * strprc - convert a string to a procedure.
 */
struct b_proc *strprc(dptr s, C_integer arity, struct progstate *p)
   {
   dptr t;

   /*
    * See if the string is the name of a global variable.
    */
   if ((t = lookup_global(s, p))) {
       if (is:proc(*t))
           return (struct b_proc *)BlkLoc(*t);
       else
           return 0;
   }

   return bi_strprc(s,arity);
   }

/*
 * Service routines
 */

/*
 * itos - convert the integer num into a string using s as a buffer and
 *  making q a descriptor for the resulting string.
 */

static void itos(num, dp, s)
C_integer num;
dptr dp;
char *s;
   {
   register char *p;

   p = s + MaxCvtLen - 1;

   *p = '\0';
   if (num >= 0L)
      do {
	 *--p = num % 10L + '0';
	 num /= 10L;
	 } while (num != 0L);
   else {
      if (num == MinWord) {      /* max negative value */
	 p -= strlen (MinWordStr);
	 strcpy (p, MinWordStr);
         }
      else {
	num = -num;
	do {
	   *--p = '0' + (num % 10L);
	   num /= 10L;
	   } while (num != 0L);
	*--p = '-';
	}
      }

   StrLen(*dp) = s + MaxCvtLen - 1 - p;
   StrLoc(*dp) = p;
   }


/*
 * ston - convert a string to a numeric quantity if possible.
 * Returns a typecode or CvtFail.  Its answer is in the dptr,
 * unless its a double, in which case its in the union numeric
 * (we do this to avoid allocating a block for a real
 * that will later be used directly as a C_double).
 */
static int ston(sp, result)
dptr sp;
union numeric *result;
   {
   register char *s = StrLoc(*sp), *end_s;
   register int c;
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
   while (isspace((unsigned char)c))
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
   while (isdigit((unsigned char)c)) {
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
      int rv;
      rv = bigradix((int)msign, (int)mantissa, s, end_s, result);
      if (rv == Error)
         fatalerr(0, NULL);
      return rv;
      }

   /*
    * Get fractional part of mantissa.
    */
   if (c == '.') {
      realflag++;
      c = (s < end_s) ? *s++ : ' ';
      while (isdigit((unsigned char)c)) {
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
      if (!isdigit((unsigned char)c))
	 return CvtFail;
      while (isdigit((unsigned char)c)) {
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
   while (isspace((unsigned char)c) && s < end_s)
      c = *s++;
   if (!isspace((unsigned char)c))
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
         int rv;
         rv = bigradix((int)msign, 10, ssave, end_s, result);
         if (rv == Error)
            fatalerr(0, NULL);
         return rv;
         }

   if (!realflag)
      return CvtFail;		/* don't promote to real if integer format */

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
 *  given length.
 */

word cvpos(pos, len)
long pos;
register long len;
   {
   register word p;

   /*
    * Make sure the position is in the range of an int. (?)
    */
   if ((long)(p = pos) != pos)
      return CvtFail;
   /*
    * Make sure the position is within range.
    */
   if (p < -len || p > len + 1)
      return CvtFail;
   /*
    * If the position is greater than zero, just return it.  Otherwise,
    *  convert the zero/negative position.
    */
   if (pos > 0)
      return p;
   return (len + p + 1);
   }

double dblZero = 0.0;

/*
 * rtos - convert the real number n into a string using s as a buffer and
 *  making a descriptor for the resulting string.
 */
void rtos(double n, dptr dp, char *s)
   {
   char *p;
   s++; 				/* leave room for leading zero */
   sprintf(s, "%.*g", Precision, n + dblZero);   /* format, avoiding -0 */

   /*
    * Now clean up possible messes.
    */
   while (*s == ' ')			/* delete leading blanks */
      s++;
   if (*s == '.') {			/* prefix 0 to initial period */
      s--;
      *s = '0';
      }
   else if (!strchr(s, '.') && !strchr(s, 'e') && !strchr(s, 'E'))
         strcat(s, ".0");		/* if no decimal point or exp. */
   if (s[strlen(s) - 1] == '.')		/* if decimal point is at end ... */
      strcat(s, "0");

   /* Convert e+0dd -> e+dd */
   if ((p = strchr(s, 'e')) && p[2] == '0' && isdigit(p[3]) && isdigit(p[4]))
      strcpy(p + 2, p + 3);

   StrLen(*dp) = strlen(s);
   StrLoc(*dp) = s;
   }
