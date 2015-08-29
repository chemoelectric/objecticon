/*
 * File: rmisc.r
 */

#include "../h/modflags.h"
#include "../h/opdefs.h"

/*
 * Prototypes.
 */

static void	listimage(FILE *f, dptr dp, int noimage);
static char *	csname		(dptr dp);

static char *proc_kinds[] = { "procedure",
                              "function",
                              "keyword",
                              "operator",
                              "internal"};

static char *op_arity[] = { NULL,
                            "unary",
                            "binary",
                            "ternary"};


/* 
 * eq - compare two Icon strings for equality
 */
int eq(dptr d1, dptr d2)
{
	char *s1, *s2;
	int i;

	if (StrLen(*d1) != StrLen(*d2))
	   return 0;
	s1 = StrLoc(*d1);
	s2 = StrLoc(*d2);
	for (i = 0; i < StrLen(*d1); i++)
	   if (*s1++ != *s2++) 
	      return 0;
	return 1;
}

/*
 * Compare an Icon string and a C string for equality.
 */
int ceq(dptr dp, char *s)
{
    struct descrip t;
    CMakeStr(s, &t);
    return eq(&t, dp);
}


/*
 * Get variable descriptor from name.  Returns the (integer-encoded) scope
 *  of the variable (Succeeded for keywords), or Failed if the variable
 *  does not exist.
 */
int getvar(dptr s, dptr vp, struct progstate *p)
{
    dptr dp;
    struct p_frame *pf;
    int i;

    if (StrLen(*s) == 0)
        return Failed;
        
    /*
     * Is it a keyword that's a variable?
     */
    if (*StrLoc(*s) == '&') {
        char *t = StrLoc(*s) + 1;
        switch (StrLen(*s)) {
            case 4 : {
                if (strncmp(t,"pos",3) == 0) {
                    vp->dword = D_Kywdpos;
                    VarLoc(*vp) = &p->Kywd_pos;
                    return Succeeded;
                }
                if (strncmp(t,"why",3) == 0) {
                    vp->dword = D_Kywdstr;
                    VarLoc(*vp) = &p->Kywd_why;
                    return Succeeded;
                }
                break;
            }
            case 5 : {
                if (strncmp(t,"dump",4) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &kywd_dump;
                    return Succeeded;
                }
                break;
            }
            case 6 : {
                if (strncmp(t,"trace",5) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &p->Kywd_trace;
                    return Succeeded;
                }
                break;
            }
            case 7 : {
                if (strncmp(t,"random",6) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &p->Kywd_ran;
                    return Succeeded;
                }
                break;
            }
            case 8 : {
                if (strncmp(t,"handler",7) == 0) {
                    vp->dword = D_Kywdhandler;
                    VarLoc(*vp) = &p->Kywd_handler;
                    return Succeeded;
                }
                if (strncmp(t,"subject",7) == 0) {
                    vp->dword = D_Kywdsubj;
                    VarLoc(*vp) = &p->Kywd_subject;
                    return Succeeded;
                }
                break;
            }
            case 9 : {
                if (strncmp(t,"maxlevel",8) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &p->Kywd_maxlevel;
                    return Succeeded;
                }
                if (strncmp(t,"progname",8) == 0) {
                    vp->dword = D_Kywdstr;
                    VarLoc(*vp) = &p->Kywd_prog;
                    return Succeeded;
                }
                break;
            }
        }
        return Failed;
    }

    /*
     *  The first if test here checks whether or not we have a
     *  user pframe.  We won't if this is a newly loaded program that
     *  hasn't been started yet.  In that case, we have no local
     *  variables yet.
     */
    pf = get_current_user_frame_of(p->K_current);
    if (pf) {
        struct p_proc *bp;
        dptr *np;

        bp = pf->proc;
        np = bp->lnames;		/* Check the formal parameter names. */

        dp = pf->fvars->desc;
        for (i = bp->nparam; i > 0; i--) {
            if (eq(s, *np)) {
               /* Don't allow var access to the self argument in an instance method */
               if (bp->field && !(bp->field->flags & M_Static) && i == bp->nparam)
                   return Failed;
                vp->dword = D_NamedVar;
                VarLoc(*vp) = (dptr)dp;
                return ParamName;
            }
            dp++;
            np++;
        }

        for (i = bp->ndynam; i > 0; i--) { /* Check the local dynamic names. */
            if (eq(s, *np)) {
                vp->dword = D_NamedVar;
                VarLoc(*vp) = (dptr)dp;
                return LocalName;
            }
            np++;
            dp++;
        }

        dp = bp->fstatic; /* Check the local static names. */
        for (i = bp->nstatic; i > 0; i--) {
            if (eq(s, *np)) {
                vp->dword = D_NamedVar;
                VarLoc(*vp) = (dptr)dp;
                return StaticName;
            }
            np++;
            dp++;
        }
    }

    /* Check the global variable names. */
    if ((i = lookup_global_index(s, p)) >= 0 && (p->Gflags[i] & (G_Package | G_Const)) == 0) {
        vp->dword    =  D_NamedVar;
        VarLoc(*vp) =  p->Globals + i;
        return GlobalName;
    }
    return Failed;
}

/*
 * hash - compute hash value of arbitrary object for table and set accessing.
 */

uword hash(dptr dp)
   {
   char *s;
   uword i;
   word j, n;
   double r;

   if (Qual(*dp)) {
   hashstring:
      /*
       * Compute the hash value for the string based on a scaled sum
       *  of its first ten characters, plus its length.
       */
      i = 0;
      s = StrLoc(*dp);
      j = n = StrLen(*dp);
      if (j > 10)		/* limit scan to first ten characters */
         j = 10;
      while (j-- > 0) {
         i += *s++ & 0xFF;	/* add unsigned version of next char */
         i *= 37;		/* scale total by a nice prime number */
         }
      i += n;			/* add the (untruncated) string length */
      }

   else {

      switch (Type(*dp)) {
         /*
          * The hash value of an integer is itself times eight times the golden
	  *  ratio.  We do this calculation in fixed point.  We don't just use
	  *  the integer itself, for that would give bad results with sets
	  *  having entries that are multiples of a power of two.
          */
         case T_Integer:
            i = (13255 * (uword)IntVal(*dp)) >> 10;
            break;

         /*
          * The hash value of a bignum is based on its length and its
          *  most and least significant digits.
          */
	 case T_Lrgint:
	    {
	    struct b_bignum *b = &BignumBlk(*dp);

	    i = ((b->lsd - b->msd) << 16) ^ 
		(b->digits[b->msd] << 8) ^ b->digits[b->lsd];
	    }
	    break;

         /*
          * The hash value of a real number is itself times a constant,
          *  converted to an unsigned integer.  The intent is to scramble
	  *  the bits well, in the case of integral values, and to scale up
	  *  fractional values so they don't all land in the same bin.
	  *  The constant below is 32749 / 29, the quotient of two primes,
	  *  and was observed to work well in empirical testing.
          */
         case T_Real:
            DGetReal(*dp,r);
            i = r * 1129.27586206896558;
            break;

         /*
          * The hash value of a cset is based on a convoluted combination
          *  of all its range values.
          */
         case T_Cset:
            i = 0;
            for (j = 0; j < CsetBlk(*dp).n_ranges; j++) {
                i += CsetBlk(*dp).range[j].from;
                i *= 37;			/* better distribution */
                i += CsetBlk(*dp).range[j].to;
                i *= 37;			/* better distribution */
               }
            i %= 1048583;		/* scramble the bits */
            break;

         /*
          * The hash value of a list, set, table, or record is its id,
          *   hashed like an integer.
          */
         case T_List:
            i = (13255 * ListBlk(*dp).id) >> 10;
            break;

         case T_Set:
            i = (13255 * SetBlk(*dp).id) >> 10;
            break;

         case T_Table:
            i = (13255 * TableBlk(*dp).id) >> 10;
            break;

         case T_Record:
            i = (13255 * RecordBlk(*dp).id) >> 10;
            break;

         case T_Object:
            i = (13255 * ObjectBlk(*dp).id) >> 10;
            break;

         case T_Coexpr:
            i = (13255 * CoexprBlk(*dp).id) >> 10;
            break;

         case T_Methp:
            i = (13255 * MethpBlk(*dp).id) >> 10;
            break;

	 case T_Weakref:
            i = (13255 * WeakrefBlk(*dp).id) >> 10;
            break;

         case T_Class:
	    dp = ClassBlk(*dp).name;
	    goto hashstring;

         case T_Constructor:
	    dp = ConstructorBlk(*dp).name;
	    goto hashstring;

	 case T_Ucs:
	    dp = &(UcsBlk(*dp).utf8);
	    goto hashstring;

	 case T_Proc:
	    dp = ProcBlk(*dp).name;
	    goto hashstring;

         default:
            /*
             * For other types, use the type code as the hash
             *  value.
             */
            i = Type(*dp);
            break;
         }
      }

   return i;
   }


#define CHAR_CVT_LEN 10

static int charstr(int c, char *b)
{
    static char cbuf[12];
    if (c < 128 && isprint((unsigned char)c)) {
        /*
         * c is printable, but special case ", ', - and \.
         */
        switch (c) {
            case '"':
                if (b) strncpy(b, "\\\"", 2);
                return 2;
            case '\'':
                if (b) strncpy(b, "\\'", 2);
                return 2;
            case '\\':
                if (b) strncpy(b, "\\\\", 2);
                return 2;
            default:
                if (b) *b = c;
                return 1;
        }
    }

    if (c < 256) {
        /*
         * c is some sort of unprintable character.	If it one of the common
         *  ones, produce a special representation for it, otherwise, produce
         *  its hex value.
         */
        switch (c) {
            case '\b':			/* backspace */
                if (b) strncpy(b, "\\b", 2);
                return 2;

            case '\177':			/* delete */
                if (b) strncpy(b, "\\d", 2);
                return 2;
            case '\33':			/* escape */
                if (b) strncpy(b, "\\e", 2);
                return 2;
            case '\f':			/* form feed */
                if (b) strncpy(b, "\\f", 2);
                return 2;
            case '\n':			/* new line */
                if (b) strncpy(b, "\\n", 2);
                return 2;
            case '\r':     		/* carriage return b */
                if (b) strncpy(b, "\\r", 2);
                return 2;
            case '\t':			/* horizontal tab */
                if (b) strncpy(b, "\\t", 2);
                return 2;
            case '\13':			/* vertical tab */
                if (b) strncpy(b, "\\v", 2);
                return 2;
            default: {				/* hex escape sequence */
                if (b) {
                    sprintf(cbuf, "\\x%02x", c);
                    strncpy(b, cbuf, 4);
                }
                return 4;
            }
        }
    }
    if (c < 65536) {
        if (b) {
            sprintf(cbuf, "\\u%04x", c);
            strncpy(b, cbuf, 6);
        }
        return 6;
    }

    if (b) {
        sprintf(cbuf, "\\U%06x", c);
        strncpy(b, cbuf, 8);
    }
    return 8;
}

static int cset_charstr(int c, char *b)
{
    if (c == '\"') {
        if (b) *b = c;
        return 1;
    }
    if (c == '-') {
        if (b) strncpy(b, "\\-", 2);
        return 2;
    }
    return charstr(c, b);
}

static int str_charstr(int c, char *b)
{
    if (c == '\'') {
        if (b) *b = c;
        return 1;
    }
    return charstr(c, b);
}

static int ucs_charstr(int c, char *b)
{
    static char cbuf[12];
    if (c == '\'') {
        if (b) *b = c;
        return 1;
    }
    if (c > 127 && c < 256) {
        if (b) {
            sprintf(cbuf, "\\u%04x", c);
            strncpy(b, cbuf, 6);
        }
        return 6;
    }

    return charstr(c, b);
}

static int cset_do_range(int from, int to)
{
    if (to - from <= 1)
        return 0;
    if (from < 128 && to < 128)
        return 0;
    return 1;
}

#define StringLimit	16		/* limit on length of imaged string */
#define ListLimit	 6		/* limit on list items in image */

static void kywdout(FILE *f, dptr dp, int noimage)
{
   tended struct descrip tdp;
   getname(dp, &tdp);
   putstr(f, &tdp);
   if (!noimage) {
       fprintf(f, " = ");
       outimage(f, VarLoc(*dp), noimage);
   }
}

/*
 * outimage - print image of *dp on file f.  If noimage is nonzero,
 *  fields of records will not be imaged.
 * dp should point to a tended desc, since this function can do an allocation (see bigprint).
 */

void outimage(FILE *f, dptr dp, int noimage)
   {
   word i, j, k;
   char *s;
   char *csn;
   tended struct descrip tdp;
   char cbuf[CHAR_CVT_LEN];

   type_case *dp of {
      string: {
         /*
          * *dp is a string qualifier.  Print StringLimit characters of it
          *  and denote the presence of additional characters
          *  by terminating the string with "...".
          */
         i = StrLen(*dp);
         s = StrLoc(*dp);
         j = Min(i, StringLimit);
         putc('"', f);
         while (j-- > 0) {
             int n = str_charstr(*s++ & 0xff, cbuf);
             putn(f, cbuf, n);
         }
         if (i > StringLimit)
             fprintf(f, "...");
         putc('"', f);
         }

      ucs: {
         i = UcsBlk(*dp).length;
         s = StrLoc(UcsBlk(*dp).utf8);
         j = Min(i, StringLimit);
         fprintf(f, "u\"");
         while (j-- > 0) {
             int n;
             k = utf8_iter(&s);
             n = ucs_charstr(k, cbuf);
             putn(f, cbuf, n);
         }
         if (i > StringLimit)
             fprintf(f, "...");
         putc('"', f);
         }

      null:
         fprintf(f, "&null");

      integer:

         if (Type(*dp) == T_Lrgint)
            bigprint(f, dp);
         else
            fprintf(f, WordFmt, IntVal(*dp));

      real: {
         double rresult;
         DGetReal(*dp,rresult);
	 fputs(double2cstr(rresult),f);
         }

      cset: {
         /*
	  * Check for a predefined cset; use keyword name if found.
	  */
	 if ((csn = csname(dp)) != NULL) {
	    fputs(csn, f);
	    return;
	    }
         putc('\'', f);
         j = StringLimit;
         for (i = 0; i < CsetBlk(*dp).n_ranges; ++i) {
             int from, to, n;
             from = CsetBlk(*dp).range[i].from;
             to = CsetBlk(*dp).range[i].to;
             if (cset_do_range(from, to)) {
                 if (j <= 0) {
                     fprintf(f, "...");
                     break;
                 }
                 n = cset_charstr(from, cbuf);
                 putn(f, cbuf, n);
                 putc('-', f);
                 n = cset_charstr(to, cbuf);
                 putn(f, cbuf, n);
                 j -= 2;
             } else {
                 int k;
                 for (k = from; k <= to; ++k) {
                     if (j-- <= 0) {
                         fprintf(f, "...");
                         i = CsetBlk(*dp).n_ranges;
                         break;
                     }
                     n = cset_charstr(k, cbuf);
                     putn(f, cbuf, n);
                 }
             }
         }
         putc('\'', f);
        }


     class: {
           /* produce "class " + the class name */
         fprintf(f, "class ");
         putstr(f, ClassBlk(*dp).name);
         }

     constructor: {
           /* produce "constructor " + the type name */
         fprintf(f, "constructor ");
         putstr(f, ConstructorBlk(*dp).name);
         }

      proc: {
         struct class_field *field = ProcBlk(*dp).field;
         if (field) {
             /*
              * Produce "method classname.fieldname"
              */
             fprintf(f, "method ");
             putstr(f, field->defining_class->name);
             fprintf(f, ".");
             putstr(f, field->defining_class->program->Fnames[field->fnum]);
         } else if (&ProcBlk(*dp) == (struct b_proc *)&Bdeferred_method_stub)
             fprintf(f, "deferred method");
         else {
             int kind = get_proc_kind(&ProcBlk(*dp));
             if (kind == Operator)
                 fprintf(f, "%s %s ", proc_kinds[kind], op_arity[ProcBlk(*dp).nparam]);
             else
                 fprintf(f, "%s ", proc_kinds[kind]);
             putstr(f, ProcBlk(*dp).name);
         }
      }
      list: {
         /*
          * listimage does the work for lists.
          */
          listimage(f, dp, noimage);
         }

      table: {
         /*
          * Print "table#m(n)" where n is the size of the table.
          */
         fprintf(f, "table#" UWordFmt "(" WordFmt ")", TableBlk(*dp).id, TableBlk(*dp).size);
         }

      set: {
	/*
         * print "set#m(n)" where n is the cardinality of the set
         */
	fprintf(f,"set#" UWordFmt "(" WordFmt ")", SetBlk(*dp).id, SetBlk(*dp).size);
        }

     methp: {
             fprintf(f, "methp#" UWordFmt "(", MethpBlk(*dp).id);
             tdp.dword = D_Object;
             BlkLoc(tdp) = (union block*)MethpBlk(*dp).object;
             outimage(f, &tdp, noimage);
             fprintf(f, ",");
             tdp.dword = D_Proc;
             BlkLoc(tdp) = (union block*)MethpBlk(*dp).proc;
             outimage(f, &tdp, noimage);
             fprintf(f, ")");
     }

     object: {
             /*
              * If noimage is nonzero, print "object classname(n)" where n is the
              *  number of fields in the record.  If noimage is zero, print
              *  the image of each field instead of the number of fields.
              */
             fprintf(f, "object ");
             putstr(f, ObjectBlk(*dp).class->name);
             fprintf(f, "#" UWordFmt "", ObjectBlk(*dp).id);
             j = ObjectBlk(*dp).class->n_instance_fields;
             if (j <= 0)
                 fprintf(f, "()");
             else if (noimage > 0)
                 fprintf(f, "(" WordFmt ")", j);
             else {
                 putc('(', f);
                 i = 0;
                 for (;;) {
                     tdp = ObjectBlk(*dp).fields[i];
                     outimage(f, &tdp, noimage + 1);
                     if (++i >= j)
                         break;
                     putc(',', f);
                 }
                 putc(')', f);
             }
         }

     weakref: {
             fprintf(f, "weakref#" UWordFmt "", WeakrefBlk(*dp).id);
             tdp = WeakrefBlk(*dp).val;
             if (is:null(tdp))
                 fprintf(f, "()");
             else {
                 putc('(', f);
                 outimage(f, &tdp, noimage);
                 putc(')', f);
             }
     }

      record: {
         /*
          * If noimage is nonzero, print "record(n)" where n is the
          *  number of fields in the record.  If noimage is zero, print
          *  the image of each field instead of the number of fields.
          */
         fprintf(f, "record ");
         putstr(f, RecordBlk(*dp).constructor->name);
         fprintf(f, "#" UWordFmt "", RecordBlk(*dp).id);
         j = RecordBlk(*dp).constructor->n_fields;
         if (j <= 0)
            fprintf(f, "()");
         else if (noimage > 0)
            fprintf(f, "(" WordFmt ")", j);
         else {
            putc('(', f);
            i = 0;
            for (;;) {
               tdp = RecordBlk(*dp).fields[i];
               outimage(f, &tdp, noimage + 1);
               if (++i >= j)
                  break;
               putc(',', f);
               }
            putc(')', f);
            }
         }

      coexpr: {
         fprintf(f, "co-expression#" UWordFmt "(" WordFmt ")",
                 CoexprBlk(*dp).id, CoexprBlk(*dp).size);
         }

      tvsubs: {
         tended struct descrip sv;
         /*
          * Produce "v[i+:j] = value" where v is the image of the variable
          *  containing the substring, i is starting position of the substring
          *  j is the length, and value is the string v[i+:j].	If the length
          *  (j) is one, just produce "v[i] = value".
          */
         sv = TvsubsBlk(*dp).ssvar;
         outimage(f, &sv, noimage+1);

         if (TvsubsBlk(*dp).sslen == 1)
            fprintf(f, "[" WordFmt "]", TvsubsBlk(*dp).sspos);
         else
            fprintf(f, "[" WordFmt "+:" WordFmt "]", TvsubsBlk(*dp).sspos, TvsubsBlk(*dp).sslen);

         if (!noimage) {
             deref(&sv, &tdp);
             if (is:ucs(tdp)) {
                 struct descrip utf8_subs;
                 if (TvsubsBlk(*dp).sspos + TvsubsBlk(*dp).sslen - 1 > UcsBlk(tdp).length)
                     return;
                 utf8_substr(&UcsBlk(tdp),
                             TvsubsBlk(*dp).sspos,
                             TvsubsBlk(*dp).sslen,
                             &utf8_subs);
                 i = TvsubsBlk(*dp).sslen;
                 s = StrLoc(utf8_subs);
                 j = Min(i, StringLimit);
                 fprintf(f, " = u\"");
                 while (j-- > 0) {
                     int n;
                     k = utf8_iter(&s);
                     n = ucs_charstr(k, cbuf);
                     putn(f, cbuf, n);
                 }
                 if (i > StringLimit)
                     fprintf(f, "...");
                 fprintf(f, "\"");
                                         
             }
             else if (Qual(tdp)) {
                 tended struct descrip q;
                 if (TvsubsBlk(*dp).sspos + TvsubsBlk(*dp).sslen - 1 > StrLen(tdp))
                     return;
                 StrLen(q) = TvsubsBlk(*dp).sslen;
                 StrLoc(q) = StrLoc(tdp) + TvsubsBlk(*dp).sspos - 1;
                 fprintf(f, " = ");
                 outimage(f, &q, noimage);
             }
           }

        }

      tvtbl: {
         /*
          * produce "t[s]" where t is the image of the table containing
          *  the element and s is the image of the subscript.
          */
         tdp.dword = D_Table;
	 BlkLoc(tdp) = TvtblBlk(*dp).clink;
	 outimage(f, &tdp, noimage);
         putc('[', f);
         tdp = TvtblBlk(*dp).tref;
         outimage(f, &tdp, noimage);
         putc(']', f);
         }

      kywdint: {
         kywdout(f, dp, noimage);
      }

      kywdhandler: {
         kywdout(f, dp, noimage);
      }

      kywdstr: {
         kywdout(f, dp, noimage);
      }

      kywdpos: {
         kywdout(f, dp, noimage);
      }

      kywdsubj: {
         kywdout(f, dp, noimage);
      }

     struct_var: {
         union block *bp = BlkLoc(*dp);
         dptr varptr = OffsetVarLoc(*dp);
         switch (BlkType(bp)) {
             case T_Telem: { 		/* table */
                 /* Find and print the element's table block */
                 while(BlkType(bp) == T_Telem)
                     bp = bp->telem.clink;
                 tdp.dword = D_Table;
                 BlkLoc(tdp) = bp;
                 outimage(f, &tdp, noimage + 1);
                 /* Print the element key */
                 putc('[', f);
                 tdp = TvtblBlk(*dp).tref;
                 outimage(f, &tdp, noimage);
                 putc(']', f);
                 break;
             }
             case T_Lelem: { 		/* list */
                 /* Find and print the list block and the index */
                 i = varptr - &bp->lelem.lslots[bp->lelem.first] + 1;
                 if (i < 1)
                     i += bp->lelem.nslots;
                 while (BlkType(bp->lelem.listprev) == T_Lelem) {
                     bp = bp->lelem.listprev;
                     i += bp->lelem.nused;
                 }
                 tdp.dword = D_List;
                 BlkLoc(tdp) = bp->lelem.listprev;
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f,"[" WordFmt "]", i);
                 break;
             }
             case T_Object: { 		/* object */
                 struct b_class *c = ObjectBlk(*dp).class;
                 dptr fname;
                 i = varptr - ObjectBlk(*dp).fields;
                 fname =  c->program->Fnames[c->fields[i]->fnum];
                 tdp.dword = D_Object;
                 BlkLoc(tdp) = BlkLoc(*dp);
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f," . %.*s", (int)StrLen(*fname), StrLoc(*fname));
                 break;
             }
             case T_Record: { 		/* record */
                 struct b_constructor *c = RecordBlk(*dp).constructor;
                 dptr fname;
                 i = varptr - RecordBlk(*dp).fields;
                 fname = c->program->Fnames[c->fnums[i]];
                 tdp.dword = D_Record;
                 BlkLoc(tdp) = BlkLoc(*dp);
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f," . %.*s", (int)StrLen(*fname), StrLoc(*fname));
                 break;
             }
             default: {		/* none of the above */
                 fprintf(f, "struct_var");
             }
         }
         if (!noimage) {
             fprintf(f, " = ");
             tdp = *OffsetVarLoc(*dp);
             outimage(f, &tdp, noimage);
         }
      }

     named_var: {
         struct progstate *prog;
         struct p_frame *uf;
         struct p_proc *proc0;                 /* address of procedure block */
         dptr vp;
         if (!noimage)
             fprintf(f, "(variable ");
         vp = VarLoc(*dp);
         uf = get_current_user_frame();
         proc0 = uf->proc;
         if ((prog = find_global(vp))) {
             putstr(f, prog->Gnames[vp - prog->Globals]); 		/* global */
         }
         else if ((prog = find_class_static(vp))) {
             /*
              * Class static field
              */
             struct class_field *cf = find_class_field_for_dptr(vp, prog);
             struct b_class *c = cf->defining_class;
             dptr fname = c->program->Fnames[cf->fnum];
             fprintf(f, "class %.*s . %.*s", 
                     (int)StrLen(*c->name), StrLoc(*c->name),
                     (int)StrLen(*fname), StrLoc(*fname));
         }
         else if ((prog = find_procedure_static(vp))) {
             putstr(f, prog->Snames[vp - prog->Statics]); 		/* static in procedure */
         }
         else if (InRange(uf->fvars->desc, vp, uf->fvars->desc_end)) {
             putstr(f, proc0->lnames[vp - uf->fvars->desc]);          /* argument/local */
         }
         else
             fprintf(f, "(temp)");

         if (!noimage) {
             fprintf(f, " = ");
             tdp = *VarLoc(*dp);
             outimage(f, &tdp, noimage);
             putc(')', f);
         }
     }

      default: { 
         if (Type(*dp) <= MaxType)
            fputs(blkname[Type(*dp)], f);
         else
            syserr("outimage: unknown type");
         }
      }
   }


/*
 * listimage - print an image of a list.
 */

static void listimage(FILE *f, dptr dp, int noimage)
   {
   word i, j;
   tended struct b_lelem *bp;
   tended struct b_list *lp;
   tended struct descrip tdp;
   word size, count;

   lp = &ListBlk(*dp);

   bp = (struct b_lelem *) lp->listhead;
   size = lp->size;

   if (noimage > 0 && size > 0) {
      /*
       * Just give indication of size if the list isn't empty.
       */
      fprintf(f, "list#" UWordFmt "(" WordFmt ")", lp->id, size);
      return;
      }

   /*
    * Print [e1,...,en] on f.  If more than ListLimit elements are in the
    *  list, produce the first ListLimit/2 elements, an ellipsis, and the
    *  last ListLimit elements.
    */

   fprintf(f, "list#" UWordFmt " = [", lp->id);

   count = 1;
   i = 0;
   if (size > 0) {
      for (;;) {
         if (++i > bp->nused) {
            i = 1;
            bp = (struct b_lelem *) bp->listnext;
            }
         if (count <= ListLimit/2 || count > size - ListLimit/2) {
            j = bp->first + i - 1;
            if (j >= bp->nslots)
               j -= bp->nslots;
            tdp = bp->lslots[j];
            outimage(f, &tdp, noimage+1);
            if (count >= size)
               break;
            putc(',', f);
            }
         else if (count == ListLimit/2 + 1)
            fprintf(f, "...,");
         count++;
         }
      }

   putc(']', f);

   }



/*
 * findline - find the source line number associated with the ipc
 */
struct ipc_line *find_ipc_line(word *ipc, struct progstate *p)
{
   uword ipc_offset;
   int size, l, r, m;

   if (!InRange(p->Code, ipc, p->Ecode))
       return 0;

   ipc_offset = DiffPtrsBytes(ipc, p->Code);
   size = p->Elines - p->Ilines;
   l = 0;
   r = size - 1;
   while (l <= r) {
       m = (l + r) / 2;
       if (ipc_offset < p->Ilines[m].ipc)
           r = m - 1;
       else if (m < size - 1 && ipc_offset >= p->Ilines[m + 1].ipc)
           l = m + 1;
       else  /* ipc_offset >= p->Ilines[m].ipc && (m == size - 1 || ipc_offset < p->Ilines[m + 1].ipc) */
           return &p->Ilines[m];
   }
   return 0;
}

struct ipc_fname *find_ipc_fname(word *ipc, struct progstate *p)
{
   uword ipc_offset;
   int size, l, r, m;

   if (!InRange(p->Code, ipc, p->Ecode))
       return 0;

   ipc_offset = DiffPtrsBytes(ipc, p->Code);

   size = p->Efilenms - p->Filenms;
   l = 0;
   r = size - 1;
   while (l <= r) {
       m = (l + r) / 2;
       if (ipc_offset < p->Filenms[m].ipc)
           r = m - 1;
       else if (m < size - 1 && ipc_offset >= p->Filenms[m + 1].ipc)
           l = m + 1;
       else  /* ipc_offset >= p->Filenms[m].ipc && (m == size - 1 || ipc_offset < p->Filenms[m + 1].ipc) */
           return &p->Filenms[m];
   }
   return 0;
}

#if UNIX
void begin_link(FILE *f, dptr fname, word line)
{
    char *s;
    int i;
    if (!is_flowterm_tty(f))
        return;
    fputs("\x1b[!\"file://", f);
    if ((s = get_hostname()))
        fputs(s, f);
    i = StrLen(*fname);
    s = StrLoc(*fname);
    while (i-- > 0) {
        if (strchr(URL_UNRESERVED, *s))
            fputc(*s, f);
        else
            fprintf(f, "%%%02x", *s & 0xff);
        s++;
    }
    if (line)
        fprintf(f, "?line=%d", (int)line);
    fputs("\"L", f);
}

void end_link(FILE *f)
{
    if (is_flowterm_tty(f))
        fputs("\x1b[!L", f);
}
#else
void begin_link(FILE *f, dptr fname, word line) {}
void end_link(FILE *f) {}
#endif

/*
 * Get the last path element of the given filename and put the result
 * into dptr d; eg "/tmp/abc.icn" returns "abc.icn"
 */
void abbr_fname(dptr s, dptr d)
{
    char *p = StrLoc(*s) + StrLen(*s);
    while (--p >= StrLoc(*s)) {
        if (strchr(FILEPREFIX, *p)) {
            ++p;
            MakeStr(p, StrLoc(*s) + StrLen(*s) - p, d);
            return;
        }
    }
    *d = *s;
}

/*
 * getimage(dp1,dp2) - return string image of object dp1 in dp2.  Both
 * pointers must point to tended descriptors.
 */

void getimage(dptr dp1, dptr dp2)
{
   word len, i, j;
   tended char *s;
   char sbuf[64];
   char cbuf[CHAR_CVT_LEN];

   type_case *dp1 of {
      string: {
         s = StrLoc(*dp1);
         i = StrLen(*dp1);
         len = 2;  /* quotes */
         while (i-- > 0)
             len += str_charstr(*s++ & 0xff, 0);
	 MemProtect(StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("\"", 1);
         s = StrLoc(*dp1);
         i = StrLen(*dp1);
         while (i-- > 0) {
             int n = str_charstr(*s++ & 0xff, cbuf);
             alcstr(cbuf, n);
         }
         alcstr("\"", 1);
         }

      ucs: {
         s = StrLoc(UcsBlk(*dp1).utf8);
         i = UcsBlk(*dp1).length;
         len = 3;  /* u"" */
         while (i-- > 0) {
             j = utf8_iter(&s);
             len += ucs_charstr(j, 0);
         }
	 MemProtect(StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;

         alcstr("u\"", 2);
             
         s = StrLoc(UcsBlk(*dp1).utf8);
         i = UcsBlk(*dp1).length;
         while (i-- > 0) {
             int n;
             j = utf8_iter(&s);
             n = ucs_charstr(j, cbuf);
             alcstr(cbuf, n);
         }

         alcstr("\"", 1);
         }

      null: {
           LitStr("&null", dp2);
         }

     class: {
           /* produce "class " + the class name */
         len = 6 + StrLen(*ClassBlk(*dp1).name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("class ", 6);
         alcstr(StrLoc(*ClassBlk(*dp1).name), StrLen(*ClassBlk(*dp1).name));
       }

     constructor: {
          /* produce "constructor " + the type name */
         len = 12 + StrLen(*ConstructorBlk(*dp1).name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("constructor ", 12);
         alcstr(StrLoc(*ConstructorBlk(*dp1).name), StrLen(*ConstructorBlk(*dp1).name));
       }

      integer: {
         if (Type(*dp1) == T_Lrgint) {
            word slen;
            word dlen;
            struct b_bignum *blk = &BignumBlk(*dp1);

            slen = blk->lsd - blk->msd;
            dlen = slen * DigitBits * 0.3010299956639812 	/* 1 / log2(10) */
               + log((double)blk->digits[blk->msd]) * 0.4342944819032518 + 0.5;
							/* 1 / ln(10) */
            if (dlen >= MaxDigits) {
               sprintf(sbuf,"integer(~10^" WordFmt ")", dlen);
	       len = strlen(sbuf);
               MemProtect(StrLoc(*dp2) = alcstr(sbuf,len));


               StrLen(*dp2) = len;
               }
	    else bigtos(dp1,dp2);
	    }
         else
            cnv: string(*dp1, *dp2);
	 }

      real: {
         cnv:string(*dp1, *dp2);
         }

      cset: {
         int from, to;
         char *csn;
         /*
	  * Check for the value of a predefined cset; use keyword name if found.
	  */
	 if ((csn = csname(dp1)) != NULL) {
	    StrLoc(*dp2) = csn;
	    StrLen(*dp2) = strlen(csn);
	    return;
	    }
	 /*
	  * Otherwise, describe it in terms of the character membership.
	  */
         len = 2;   /* 2 quotes */
         for (i = 0; i < CsetBlk(*dp1).n_ranges; ++i) {
             from = CsetBlk(*dp1).range[i].from;
             to = CsetBlk(*dp1).range[i].to;
             if (cset_do_range(from, to))
                 len += cset_charstr(from, 0) + 1 + cset_charstr(to, 0);
             else {
                 for (j = from; j <= to; ++j)
                     len += cset_charstr(j, 0);
             }
         }

	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("'", 1);
         for (i = 0; i < CsetBlk(*dp1).n_ranges; ++i) {
             int n;
             from = CsetBlk(*dp1).range[i].from;
             to = CsetBlk(*dp1).range[i].to;
             if (cset_do_range(from, to)) {
                 n = cset_charstr(from, cbuf);
                 alcstr(cbuf, n);
                 alcstr("-",1);
                 n = cset_charstr(to, cbuf);
                 alcstr(cbuf, n);
             } else {
                 for (j = from; j <= to; ++j) {
                     n = cset_charstr(j, cbuf);
                     alcstr(cbuf, n);
                 }
             }
         }
         alcstr("'", 1);
         }


      proc: {
         struct class_field *field = ProcBlk(*dp1).field;
         if (field) {
             /*
              * Produce "method classname.fieldname"
              */
             struct b_class *field_class = field->defining_class;
             dptr field_name = field_class->program->Fnames[field->fnum];
             len = StrLen(*field_class->name) + StrLen(*field_name) + 8;
             MemProtect (StrLoc(*dp2) = reserve(Strings, len));
             StrLen(*dp2) = len;
             /* No need to refresh pointers, everything is static data */
             alcstr("method ", 7);
             alcstr(StrLoc(*field_class->name),StrLen(*field_class->name));
             alcstr(".", 1);
             alcstr(StrLoc(*field_name),StrLen(*field_name));
         } else if (&ProcBlk(*dp1) == (struct b_proc *)&Bdeferred_method_stub)
             LitStr("deferred method", dp2);
         else {
             int kind = get_proc_kind(&ProcBlk(*dp1));
             char *type0 = proc_kinds[kind];
             if (kind == Operator) {
                 char *arity = op_arity[ProcBlk(*dp1).nparam];
                 len = strlen(type0) + 1 + strlen(arity) + 1 + StrLen(*ProcBlk(*dp1).name);
                 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
                 StrLen(*dp2) = len;
                 alcstr(type0, strlen(type0));
                 alcstr(" ", 1);
                 alcstr(arity, strlen(arity));
                 alcstr(" ", 1);
                 alcstr(StrLoc(*ProcBlk(*dp1).name), StrLen(*ProcBlk(*dp1).name));
             } else {
                 len = strlen(type0) + 1 + StrLen(*ProcBlk(*dp1).name);
                 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
                 StrLen(*dp2) = len;
                 alcstr(type0, strlen(type0));
                 alcstr(" ", 1);
                 alcstr(StrLoc(*ProcBlk(*dp1).name), StrLen(*ProcBlk(*dp1).name));
             }
         }
      }

      list: {
         /*
          * Produce:
          *  "list#m(n)"
          * where n is the current size of the list.
          */
         sprintf(sbuf, "list#" UWordFmt "(" WordFmt ")", ListBlk(*dp1).id, ListBlk(*dp1).size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
         StrLen(*dp2) = len;
         }

      table: {
         /*
          * Produce:
          *  "table#m(n)"
          * where n is the size of the table.
          */
         sprintf(sbuf, "table#" UWordFmt "(" WordFmt ")", TableBlk(*dp1).id, TableBlk(*dp1).size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
         StrLen(*dp2) = len;
         }

      set: {
         /*
          * Produce "set#m(n)" where n is size of the set.
          */
         sprintf(sbuf, "set#" UWordFmt "(" WordFmt ")", SetBlk(*dp1).id, SetBlk(*dp1).size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf,len));
         StrLen(*dp2) = len;
         }

      record: {
         /*
          * Produce:
          *  "record name#m(n)"
          * where n is the number of fields.
          */
         struct b_constructor *rec_const = RecordBlk(*dp1).constructor;
         sprintf(sbuf, "#" UWordFmt "(" WordFmt ")", RecordBlk(*dp1).id, rec_const->n_fields);
         len = 7 + strlen(sbuf) + StrLen(*rec_const->name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         /* No need to refresh pointer, rec_const is static */
         alcstr("record ", 7);
         alcstr(StrLoc(*rec_const->name),StrLen(*rec_const->name));
         alcstr(sbuf, strlen(sbuf));
         }

     methp: {
         /*
          * Produce:
          *  "methp#n(object image,method image)"
          */
         tended struct descrip td1, td2, td3;
         td1.dword = D_Object;
         BlkLoc(td1) = (union block*)MethpBlk(*dp1).object;
         getimage(&td1, &td2);
         td1.dword = D_Proc;
         BlkLoc(td1) = (union block*)MethpBlk(*dp1).proc;
         getimage(&td1, &td3);
         sprintf(sbuf, "methp#" UWordFmt "(", MethpBlk(*dp1).id);
         len = strlen(sbuf) + StrLen(td2) + 1 + StrLen(td3) + 1;
         MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr(sbuf, strlen(sbuf));
         alcstr(StrLoc(td2),StrLen(td2));
         alcstr(",", 1);
         alcstr(StrLoc(td3),StrLen(td3));
         alcstr(")", 1);
     }

     weakref: {
         /*
          * Produce:
          *  "weakref#n(val image) or weakref#n() for a collected val"
          */
         tended struct descrip td1, td2;
         td1 = WeakrefBlk(*dp1).val;
         if (is:null(td1)) {
             sprintf(sbuf, "weakref#" UWordFmt "()", WeakrefBlk(*dp1).id);
             len = strlen(sbuf);
             MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
             StrLen(*dp2) = len;
         } else {
             sprintf(sbuf, "weakref#" UWordFmt "(", WeakrefBlk(*dp1).id);
             getimage(&td1, &td2);
             len = strlen(sbuf) + StrLen(td2) + 1;
             MemProtect (StrLoc(*dp2) = reserve(Strings, len));
             StrLen(*dp2) = len;
             alcstr(sbuf, strlen(sbuf));
             alcstr(StrLoc(td2),StrLen(td2));
             alcstr(")", 1);
         }
     }

     object: {
           /*
            * Produce:
            *  "object name#m(n)"     
            * where n is the number of fields.
            */
           struct b_class *obj_class = ObjectBlk(*dp1).class;   
           sprintf(sbuf, "#" UWordFmt "(" WordFmt ")", ObjectBlk(*dp1).id, obj_class->n_instance_fields);
           len = 7 + strlen(sbuf) + StrLen(*obj_class->name);
           MemProtect (StrLoc(*dp2) = reserve(Strings, len));
           StrLen(*dp2) = len;
           /* No need to refresh pointer, obj_class is static */
           alcstr("object ", 7);
           alcstr(StrLoc(*obj_class->name),StrLen(*obj_class->name));
           alcstr(sbuf, strlen(sbuf));
       }

      coexpr: {
         /*
          * Produce:
          *  "co-expression#m (n)"
          *  where m is the number of the co-expressions and n is the
          *  number of results that have been produced.
          */

         sprintf(sbuf, "co-expression#" UWordFmt "(" WordFmt ")", CoexprBlk(*dp1).id, CoexprBlk(*dp1).size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
         StrLen(*dp2) = len;
         }

      default:
         syserr("Invalid type to getimage");
   }
}

/*
 * csname(dp) -- return the name of a predefined cset matching dp.
 */
static char *csname(dptr dp)
{
    int n = CsetBlk(*dp).size;
    struct b_cset_range *r = &CsetBlk(*dp).range[0];
    
    if (n == 0)
        return NULL;
    /*
     * Check for a cset we recognize using a hardwired decision tree.
     */
    if (n == 52) {
        if (r->from == 'A' && r->to == 'Z' &&
            r[1].from == 'a' && r[1].to == 'z')
            return "&letters";
    }
    else if (n < 52) {
        if (n == 26) {
            if (r->from == 'a' && r->to == 'z')
                return "&lcase";
            if (r->from == 'A' && r->to == 'Z')
                return "&ucase";
        }
        else if (n == 10 && r->from == '0' && r->to == '9')
            return "&digits";
    }
    else /* n > 52 */ {
        if (n == 256 && r->from == 0 && r->to == 255)
            return "&cset";
        if (n == 128 && r->from == 0 && r->to == 127)
	    return "&ascii";
        if (n == 0x110000 && r->from == 0 && r->to == 0x10FFFF)
	    return "&uset";
    }
    return NULL;

}


/*
 * Given a descriptor pointer d from the classstatics area, hunt for
 * the corresponding class_field in the classfields area, ie a
 * class_field cf so that cf->field_descriptor == d.
 * 
 * We can use binary search since the pointers into the classstatics
 * area increase, but the search is complicated by the fact that some
 * of the class_fields aren't static variables; they can be methods or
 * instance fields.
 */

/* Find the nearest index in classfields to m, with a non-null
 * field_descriptor */
static int nearest_with_dptr(int m, int n, struct progstate *prog)
{
    int off;
    for (off = 0; off < n; ++off) {
        if (m + off < n && (prog->ClassFields[m + off].flags & (M_Method | M_Static)) == M_Static)
            return m + off;
        if (m - off >= 0 && (prog->ClassFields[m - off].flags & (M_Method | M_Static)) == M_Static)
            return m - off;
    }    
    syserr("name: no field_descriptors in classfields area");
    return 0; /* Unreachable */
}

struct class_field *find_class_field_for_dptr(dptr d, struct progstate *prog)
{
    int l = 0, m, n = prog->EClassFields - prog->ClassFields, r = n - 1;
    while (l <= r) {
        m = nearest_with_dptr((l + r) / 2, n, prog);
        if (d < prog->ClassFields[m].field_descriptor)
            r = m - 1;
        else if (d > prog->ClassFields[m].field_descriptor)
            l = m + 1;
        else
            return &prog->ClassFields[m];
    }
    syserr("name: no corresponding field_descriptor in classfields area");
    return 0; /* Unreachable */
}

struct progstate *find_global(dptr s)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->Globals, s, p->Eglobals)) {
            return p;
        }
    }
    return 0;
}

struct progstate *find_class_static(dptr s)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->ClassStatics, s, p->EClassStatics)) {
            return p;
        }
    }
    return 0;
}

struct progstate *find_procedure_static(dptr s)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->Statics, s, p->Estatics)) {
            return p;
        }
    }
    return 0;
}

/*
 * keyref(bp,dp) -- print name of subscripted table
 */
static void keyref(dptr dp1, dptr dp2)
{
    tended struct descrip tr, td;
    union block *bp;  /* doesn't need to be tended */
    char sbuf[64];
    int len;

    bp = BlkLoc(*dp1);
    if (BlkType(bp) == T_Tvtbl)
        bp = bp->tvtbl.clink;
    else
        while(BlkType(bp) == T_Telem)
            bp = bp->telem.clink;
    sprintf(sbuf, "table#" UWordFmt "[", bp->table.id);

    tr = TelemBlk(*dp1).tref;
    getimage(&tr, &td);

    len = strlen(sbuf) + StrLen(td) + 1;
    MemProtect (StrLoc(*dp2) = reserve(Strings, len));
    StrLen(*dp2) = len;
    alcstr(sbuf, strlen(sbuf));
    alcstr(StrLoc(td), StrLen(td));
    alcstr("]", 1);
}

/*
 * getname -- function to get print name of variable.
 */
int getname(dptr dp1, dptr dp2)
{
    char sbuf[100];			/* buffer; might be too small */
    word i, len;
    struct progstate *prog;

    type_case *dp1 of {
      tvsubs: {
            tended struct descrip tdp1, tdp2;
            if (TvsubsBlk(*dp1).sslen == 1)
                sprintf(sbuf, "[" WordFmt "]", TvsubsBlk(*dp1).sspos);
            else
                sprintf(sbuf, "[" WordFmt "+:" WordFmt "]", TvsubsBlk(*dp1).sspos, TvsubsBlk(*dp1).sslen);
            tdp1 = TvsubsBlk(*dp1).ssvar;
            getname(&tdp1, &tdp2);
            len = StrLen(tdp2) + strlen(sbuf);
            MemProtect(StrLoc(*dp2) = reserve(Strings, len));
            StrLen(*dp2) = len;
            alcstr(StrLoc(tdp2), StrLen(tdp2));
            alcstr(sbuf, strlen(sbuf));
        }

      tvtbl: {
            keyref(dp1, dp2);
        }

      kywdint: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_ran) {
                  LitStr("&random", dp2);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_trace) {
                  LitStr("&trace", dp2);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_dump) {
                  LitStr("&dump", dp2);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_maxlevel) {
                  LitStr("&maxlevel", dp2);
                  break;
              }
          }
          if (!prog)
            syserr("name: unknown integer keyword variable");
        }            
      kywdany:
        syserr("name: unknown keyword variable");

      kywdhandler: {
        LitStr("&handler", dp2);
        }            
      kywdstr: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_prog) {
                  LitStr("&progname", dp2);
                  break;
              } else if (VarLoc(*dp1) == &prog->Kywd_why) {
                  LitStr("&why", dp2);
                  break;
              }
          }
          if (!prog)
              syserr("name: unknown string keyword variable");
        }
      kywdpos: {
        LitStr("&pos", dp2);
      }

      kywdsubj: {
        LitStr("&subject", dp2);
        }

      named_var: {
            /*
             * Must(?) be a named variable.
             * (When used internally, could be reference to nameless
             * temporary stack variables as occurs for string scanning).
             */
            struct p_frame *uf;
            struct p_proc *proc0;                 /* address of procedure block */
            dptr vp;
            uf = get_current_user_frame();
            proc0 = uf->proc;
            vp = VarLoc(*dp1);		 /* get address of variable */
            if ((prog = find_global(vp))) {
                *dp2 = *prog->Gnames[vp - prog->Globals]; 		/* global */
            }
            else if ((prog = find_class_static(vp))) {
                /*
                 * Class static field
                 */
                struct class_field *cf = find_class_field_for_dptr(vp, prog);
                struct b_class *c = cf->defining_class;
                dptr fname = c->program->Fnames[cf->fnum];
                len = 6 + StrLen(*c->name) + 1 + StrLen(*fname);
                MemProtect(StrLoc(*dp2) = reserve(Strings, len));
                StrLen(*dp2) = len;
                alcstr("class ", 6);
                alcstr(StrLoc(*c->name), StrLen(*c->name));
                alcstr(".", 1);
                alcstr(StrLoc(*fname), StrLen(*fname));
            }
            else if ((prog = find_procedure_static(vp))) {
                *dp2 = *prog->Snames[vp - prog->Statics]; 		/* static in procedure */
            }
            else if (InRange(uf->fvars->desc, vp, uf->fvars->desc_end)) {
                *dp2 = *proc0->lnames[vp - uf->fvars->desc];          /* argument/local */
            }
            else {
                LitStr("(temp)", dp2);
                return Failed;
            }
        }

      struct_var: {
            /*
             * Must be an element of a structure.
             */
            union block *bp = BlkLoc(*dp1);
            dptr varptr = OffsetVarLoc(*dp1);
            switch (BlkType(bp)) {
                case T_Lelem: 		/* list */
                    i = varptr - &bp->lelem.lslots[bp->lelem.first] + 1;
                    if (i < 1)
                        i += bp->lelem.nslots;
                    while (BlkType(bp->lelem.listprev) == T_Lelem) {
                        bp = bp->lelem.listprev;
                        i += bp->lelem.nused;
                    }
                    sprintf(sbuf,"list#" UWordFmt "[" WordFmt "]",
                            bp->lelem.listprev->list.id, i);
                    i = strlen(sbuf);
                    MemProtect(StrLoc(*dp2) = alcstr(sbuf,i));
                    StrLen(*dp2) = i;
                    break;
                case T_Record: { 		/* record */
                    struct b_constructor *c = RecordBlk(*dp1).constructor;
                    dptr fname;
                    i = varptr - RecordBlk(*dp1).fields;
                    fname = c->program->Fnames[c->fnums[i]];
                    sprintf(sbuf,"#" UWordFmt "", RecordBlk(*dp1).id);
                    len = 7 + StrLen(*c->name) + strlen(sbuf) + 1 + StrLen(*fname);
                    MemProtect(StrLoc(*dp2) = reserve(Strings, len));
                    StrLen(*dp2) = len;
                    alcstr("record ", 7);
                    alcstr(StrLoc(*c->name), StrLen(*c->name));
                    alcstr(sbuf, strlen(sbuf));
                    alcstr(".", 1);
                    alcstr(StrLoc(*fname), StrLen(*fname));
                    break;
                }
                case T_Object: { 		/* object */
                    struct b_class *c = ObjectBlk(*dp1).class;
                    dptr fname;
                    i = varptr - ObjectBlk(*dp1).fields;
                    fname =  c->program->Fnames[c->fields[i]->fnum];
                    sprintf(sbuf,"#" UWordFmt "", ObjectBlk(*dp1).id);
                    len = 7 + StrLen(*c->name) + strlen(sbuf) + 1 + StrLen(*fname);
                    MemProtect(StrLoc(*dp2) = reserve(Strings, len));
                    StrLen(*dp2) = len;
                    alcstr("object ", 7);
                    alcstr(StrLoc(*c->name), StrLen(*c->name));
                    alcstr(sbuf, strlen(sbuf));
                    alcstr(".", 1);
                    alcstr(StrLoc(*fname), StrLen(*fname));
                    break;
                }
                case T_Telem: 		/* table */
                    keyref(dp1, dp2);
                    break;
                default:		/* none of the above */
                    LitStr("(struct)", dp2);
                    return Failed;
            }
        }

        default: {
            LitStr("(non-variable)", dp2);
            return Failed;
        }
    }
    return Succeeded;
}


#ifndef AsmOver
/*
 * add, sub, mul, neg with overflow check
 * all return 1 if ok, 0 if would overflow
 */

/*
 *  Note: on some systems an improvement in performance can be obtained by
 *  replacing the C functions that follow by checks written in assembly
 *  language.  To do so, add #define AsmOver to ../h/define.h.  If your
 *  C compiler supports the asm directive, put the new code at the end
 *  of this section under control of #else.  Otherwise put it a separate
 *  file.
 */

word add(word a, word b)
{
   if ((a ^ b) >= 0 && (a >= 0 ? b > MaxWord - a : b < MinWord - a)) {
      over_flow = 1;
      return 0;
      }
   else {
     over_flow = 0;
     return a + b;
     }
}

word sub(word a, word b)
{
   if ((a ^ b) < 0 && (a >= 0 ? b < a - MaxWord : b > a - MinWord)) {
      over_flow = 1;
      return 0;
      }
   else {
      over_flow = 0;
      return a - b;
      }
}

word mul(word a, word b)
{
   if (b != 0) {
      if ((a ^ b) >= 0) {
	 if (a >= 0 ? a > MaxWord / b : a < MaxWord / b) {
            over_flow = 1;
	    return 0;
            }
	 }
      else if (b != -1 && (a >= 0 ? a > MinWord / b : a < MinWord / b)) {
         over_flow = 1;
	 return 0;
         }
      }

   over_flow = 0;
   return a * b;
}

/* MinWord / -1 overflows; need div3 too */

word mod3(word a, word b)
{
   word retval;

   switch ( b )
   {
      case 0:
	 over_flow = 1; /* Not really an overflow, but definitely an error */
	 return 0;

      case MinWord:
	 /* Handle this separately, since -MinWord can overflow */
	 retval = ( a > MinWord ) ? a : 0;
	 break;

      default:
	 /* First, we make b positive */
      	 if ( b < 0 ) b = -b;	

	 /* Make sure retval should have the same sign as 'a' */
	 retval = a % b;
	 if ( ( a < 0 ) && ( retval > 0 ) )
	    retval -= b;
	 break;
      }

   over_flow = 0;
   return retval;
}

word div3(word a, word b)
{
   if ( ( b == 0 ) ||	/* Not really an overflow, but definitely an error */
        ( b == -1 && a == MinWord ) ) {
      over_flow = 1;
      return 0;
      }

   over_flow = 0;
   return ( a - mod3 ( a, b ) ) / b;
}

/* MinWord / -1 overflows; need div3 too */

word neg(word a)
{
   if (a == MinWord) {
      over_flow = 1;
      return 0;
      }
   over_flow = 0;
   return -a;
}
#endif					/* AsmOver */


/*
 * retderef - Dereference local variables and substrings of local
 *  string-valued variables. This is used for return, suspend, and
 *  transmitting values across co-expression context switches.
 */
void retderef(dptr valp, struct frame_vars *fvars)
   {
   struct b_tvsubs *tvb;
   word *loc;

   if (is:tvsubs(*valp)) {
      tvb = &TvsubsBlk(*valp);
      /* 
       * Check to see what the ssvar holds.  It may contain a var
       * which isn't a named var, eg return &why[2].  In such cases it
       * cannot be a local var.
       */
      if (is:named_var(tvb->ssvar)) {
          loc = (word *)VarLoc(tvb->ssvar);
          if (fvars && InRange(fvars->desc, loc, fvars->desc_end))
              deref(valp, valp);
      }
   } else if (is:named_var(*valp)) {
       loc = (word *)VarLoc(*valp);
       if (fvars && InRange(fvars->desc, loc, fvars->desc_end))
           deref(valp, valp);
   }
}

/*
 * Allocate a string and initialize it based on the given
 * null-terminated C string.  The result is stored in the
 * given dptr.  If s is null, nulldesc is written to d.
 */
void cstr2string(char *s, dptr d) 
{
    if (s)
        bytes2string(s, strlen(s), d);
    else
        *d = nulldesc;
}

/*
 * C-level utility to convert a string to ucs; both pointers must
 * point to tended descriptors.  returns 1 on conversion success, 0
 * otherwise.
 */
int string2ucs(dptr str, dptr res)
{
    tended struct b_ucs *p;
    char *s1, *e1;
    word n = 0;

    s1 = StrLoc(*str);
    e1 = s1 + StrLen(*str);

    while (s1 < e1) {
        int i = utf8_check(&s1, e1);
        ++n;
        if (i < 0 || i > MAX_CODE_POINT)
            return 0;
    }
    p = make_ucs_block(str, n);
    res->dword = D_Ucs;
    BlkLoc(*res) = (union block *)p;
    return 1;
}

/*
 * Allocate a string and initialize it based on the given pointer and
 * length.  The result is stored in the given dptr.  If len is zero,
 * s is ignored and emptystr is returned.
 */
void bytes2string(char *s, word len, dptr d) 
{
    char *a;
    if (len == 0)
        *d = emptystr;
    else {
        MemProtect(a = alcstr(s, len));
        MakeStr(a, len, d);
    }
}

/*
 * Catenate the given C strings, terminated by a null pointer.  The
 * resulting string has the string delim between each element.
 */
void cstrs2string(char **s, char *delim, dptr d) 
{
    int n, len = 0;
    for (n = 0; s[n]; ++n)
        len += strlen(s[n]);
    if (n == 0)
        *d = emptystr;
    else {
        int i;
        char *a, *p, *q;
        len += strlen(delim) * (n - 1);
        MemProtect(a = alcstr(0, len));
        p = a;
        for (i = 0; i < n; ++i) {
            if (i > 0) {
                q = delim;
                while (*q)
                    *p++ = *q++;
            }
            q = s[i];
            while (*q)
                *p++ = *q++;
        }
        MakeStr(a, len, d);
    }
}

/*
 * the next section consists of code to deal with string-integer
 * (stringint) symbols.  See rstructs.h.
 */

/*
 * string-integer comparison, for bsearch()
 */
static int sicmp(char *s, stringint *sip)
{
    return strcmp(s, sip->s);
}

/*
 * string-integer lookup function: given a string, return its integer
 */
int stringint_str2int(stringint *sip, char *s)
{
    stringint *p;
    p = stringint_lookup(sip, s);
    return p ? p->i : -1;
}

/*
 * string-integer inverse function: given an integer, return its string
 */
char *stringint_int2str(stringint *sip, int i)
{
    stringint *sip2 = sip + 1;
    for(; sip2 <= sip + sip[0].i; sip2++) 
        if (sip2->i == i) 
            return sip2->s;
    return NULL;
}

stringint *stringint_lookup(stringint *sip, char *s)
{
    return (stringint *)bsearch(s, sip + 1, sip[0].i, sizeof(stringint), (BSearchFncCast)sicmp);
}

/*
 * Set &why to an error message based on errno.
 */
void errno2why()
{
    char *msg = 0;
    char buff[32];
    int len;

    #if HAVE_STRERROR
       msg = strerror(errno);
    #elif HAVE_SYS_NERR && HAVE_SYS_ERRLIST
       if (errno > 0 && errno <= sys_nerr)
           msg = (char *)sys_errlist[errno];
    #endif

    if (!msg)
        msg = "Unknown system error";
    sprintf(buff, " (errno=%d)", errno);

    len = strlen(buff) + strlen(msg);

    MemProtect(StrLoc(kywd_why) = reserve(Strings, len));
    StrLen(kywd_why) = len;
    alcstr(msg, strlen(msg));
    alcstr(buff, strlen(buff));
}

/*
 * Set &why to a simple string.
 */
void why(char *s)
{
    if (s)
        cstr2string(s, &kywd_why);
}

/*
 * Set &why using a printf-style format.
 */
void whyf(char *fmt, ...)
{
    char buff[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buff, sizeof(buff), fmt, ap);
    va_end(ap);
    cstr2string(buff, &kywd_why);
}

/*
 * salloc - allocate and initialize string
 */

char *salloc(char *s)
{
    char *s1;
    MemProtect(s1 = malloc(strlen(s) + 1));
    return strcpy(s1, s);
}

static int pdptr_cmp(dptr p1, dptr *p2)
{
    return lexcmp(p1, *p2);
}

int lookup_global_index(dptr name, struct progstate *prog)
{
    dptr *p = (dptr *)bsearch(name, prog->Gnames, prog->NGlobals, 
                              sizeof(dptr), 
                              (BSearchFncCast)pdptr_cmp);
    if (!p)
        return -1;

    /* Convert from pointer into names array to index */
    return (p - prog->Gnames);
}

int lookup_global(dptr query, struct progstate *prog)
{
    if (is:string(*query))
        return lookup_global_index(query, prog);

    if (query->dword == D_Integer) {
        int nf = prog->NGlobals;
        /*
         * Simple index into globals array, using conventional icon
         * semantics.
         */
        int i = cvpos_item(IntVal(*query), nf);
        if (i == CvtFail)
            return -1;
        return i - 1;
    }

    syserr("Invalid query type to lookup_global");
    /* Not reached */
    return 0;
}

struct loc *lookup_global_loc(dptr name, struct progstate *prog)
{
    int i;

    /* Check if the table was compiled into the icode */
    if (prog->Glocs == prog->Eglocs)
        return 0;

    i = lookup_global_index(name, prog);
    if (i < 0)
        return 0;

    return prog->Glocs + i;
}

dptr lookup_named_global(dptr name, int incl, struct progstate *prog)
{
    int i = lookup_global_index(name, prog);
    if (i < 0 || !(prog->Gflags[i] & G_Const) || (!incl && (prog->Gflags[i] & G_Package)))
        return 0;
    return prog->Globals + i;
}


static char c_buff[4096];     /* Buff for conversion to static C strings */

char *buffstr(dptr d)
{
    if (StrLen(*d) >= sizeof(c_buff))
        fatalerr(159, d);
    memcpy(c_buff, StrLoc(*d), StrLen(*d));
    c_buff[StrLen(*d)] = 0;
    return c_buff;
}

#passthru #define _DPTR dptr
#passthru #define _CHARPP char **
void buffnstr(dptr d, char **s, ...)
{
    int free;
    char *t;
    va_list ap;
    va_start(ap, s);
    t = c_buff;
    free = sizeof(c_buff);
    while (d) {
        if (StrLen(*d) >= free)
            fatalerr(159, d);
        memcpy(t, StrLoc(*d), StrLen(*d));
        *s = t;
        t += StrLen(*d);
        *t++ = 0;
        free -= StrLen(*d) + 1;
        d = va_arg(ap, _DPTR);
        if (!d)
            break;
        s = va_arg(ap, _CHARPP);
    }
    va_end(ap);
}

int isflag(dptr d)
{
    return is:null(*d) || (d->dword == D_Integer && IntVal(*d) == 1);
}

/*
 * Write string data to a temporary file.  The name of the temporary
 * file is returned, which is a pointer to a static buffer.
 */
char *datatofile(dptr data)
{
    word n;
    int c, fd;
    char *p, *path;
    path = maketemp("oi_dataXXXXXX");
    if ((fd = mkstemp(path)) < 0) {
        LitWhy("Couldn't create temp data file");
        return 0;
    }
    n = StrLen(*data);
    p = StrLoc(*data);
    while (n > 0) {
        if ((c = write(fd, p, n)) < 0) {
            LitWhy("Couldn't write to temp data file");
            close(fd);
            return 0;
        }
        p += c;
        n -= c;
    }
    close(fd);
    return path;
}
