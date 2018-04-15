/*
 * def.r -- defaulting conversion routines.
 */

/*
 * DefConvert - macro for general form of defaulting conversion.
 */
#begdef DefConvert(default, dftype, destype, converter, body)
int default(dptr s, dftype df, destype d)
   {
   if (is:null(*s)) {
      body
      return 1;
      }
   else
      return converter(s,d); /* I really mean cnv:type */
   }
#enddef

/*
 * def_c_dbl - def:C_double(*s, df, *d), convert to C double with a
 *  default value. Default is of type C double; if used, just copy to
 *  destination.
 */

#begdef C_DblAsgn
   *d = df;
#enddef

DefConvert(def_c_dbl, double, double *, cnv_c_dbl, C_DblAsgn)

/*
 * def_c_int - def:C_integer(*s, df, *d), convert to word with a
 *  default value. Default type word; if used, just copy to
 *  destination.
 */
#begdef C_IntAsgn
   *d = df;
#enddef

DefConvert(def_c_int, word, word *, cnv_c_int, C_IntAsgn)

/*
 * def_c_str - def:C_string(*s, df, *d), convert to (tended) C string with
 *  a default value. Default is of type "char *"; if used, point destination
 *  descriptor to it.
 */

#begdef C_StrAsgn
   CMakeStr(df, d);
#enddef

DefConvert(def_c_str, char *, dptr, cnv_c_str, C_StrAsgn)

/*
 * def_cset - def:cset(*s, *df, *d), convert to cset with a default value.
 *  Default is of type "struct b_cset *"; if used, point destination descriptor
 *  to it.
 */

#begdef CsetAsgn
  MakeDesc(D_Cset, df, d);
#enddef

DefConvert(def_cset, struct b_cset *, dptr, cnv_cset, CsetAsgn)

/*
 * def_ucs - def:ucs(*s, *df, *d), convert to ucs with a default value.
 *  Default is of type "struct b_ucs *"; if used, point destination descriptor
 *  to it.
 */

#begdef UcsAsgn
  MakeDesc(D_Ucs, df, d);
#enddef

DefConvert(def_ucs, struct b_ucs *, dptr, cnv_ucs, UcsAsgn)

/*
 * def_ec_int - def:(exact)C_integer(*s, df, *d), convert to C Integer
 *  with a default value, but disallow conversions from reals. Default
 *  is of type C_Integer; if used, just copy to destination.
 */

#begdef EC_IntAsgn
   *d = df;
#enddef

DefConvert(def_ec_int, word, word *, cnv_ec_int, EC_IntAsgn)

/*
 * def_eint - def:(exact)integer(*s, df, *d), convert to word
 *  with a default value, but disallow conversions from reals. Default
 *  is of type C_Integer; if used, assign it to the destination descriptor.
 */

#begdef EintAsgn
   MakeInt(df, d);
#enddef

DefConvert(def_eint, word, dptr, cnv_eint, EintAsgn)

/*
 * def_int - def:integer(*s, df, *d), convert to integer with a default
 *  value. Default is of type word; if used, assign it to the
 *  destination descriptor.
 */

#begdef IntAsgn
   MakeInt(df, d);
#enddef

DefConvert(def_int, word, dptr, cnv_int, IntAsgn)

/*
 * def_real - def:real(*s, df, *d), convert to real with a default value.
 *  Default is of type double; if used, allocate real block and point
 *  destination descriptor to it.
 */

#begdef RealAsgn
   MakeReal(df,d);
#enddef

DefConvert(def_real, double, dptr, cnv_real, RealAsgn)

/*
 * def_str - def:string(*s, *df, *d), convert to string with a default
 *  value. Default is of type "struct descrip *"; if used, copy the
 *  decriptor value to the destination.
 */

#begdef StrAsgn
   *d = *df;
#enddef

DefConvert(def_str, dptr, dptr, cnv_str, StrAsgn)


/*
 * def_string_or_ucs - def:string_or_ucs(*s, *df, *d), convert to string/ucs with a default
 *  value. Default is of type "struct descrip *"; if used, copy the
 *  decriptor value to the destination.
 */

#begdef StrOrUcsAsgn
   *d = *df;
#enddef

DefConvert(def_str_or_ucs, dptr, dptr, cnv_str_or_ucs, StrOrUcsAsgn)
