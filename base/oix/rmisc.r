/*
 * File: rmisc.r
 */

#include "../h/opdefs.h"

/*
 * Prototypes.
 */

static void	listimage
   (FILE *f,struct b_list *lp, int noimage);
static char *	csname		(dptr dp);

static char *proc_kinds[] = { "procedure",
                              "function",
                              "keyword",
                              "operator",
                              "internal"};


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
        int i;

        bp = pf->proc;
        np = bp->lnames;		/* Check the formal parameter names. */

        dp = pf->fvars->desc;
        for (i = bp->nparam; i > 0; i--) {
            if (eq(s, *np)) {
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
    if ((dp = lookup_global(s, p))) {
        vp->dword    =  D_NamedVar;
        VarLoc(*vp) =  dp;
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

         case T_Class:
	    dp = ClassBlk(*dp).name;
	    goto hashstring;

         case T_Constructor:
	    dp = ConstructorBlk(*dp).name;
	    goto hashstring;

         case T_Cast:
            i = (13255 * CastBlk(*dp).object->id) >> 10;
            break;
 
         case T_Methp:
            i = (13255 * MethpBlk(*dp).object->id) >> 10;
            break;

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

/*
 * outimage - print image of *dp on file f.  If noimage is nonzero,
 *  fields of records will not be imaged.
 */

void outimage(FILE *f, dptr dp, int noimage)
   {
   word i, j, k;
   char *s;
   union block *bp;
   char *csn;
   struct descrip q;
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
         fprintf(f, "\"");
         }

      null:
         fprintf(f, "&null");

      integer:

         if (Type(*dp) == T_Lrgint)
            bigprint(f, dp);
         else
            fprintf(f, "%ld", (long)IntVal(*dp));

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
                     i = CsetBlk(*dp).n_ranges;
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
             fprintf(f, "%s ", proc_kinds[get_proc_kind(&ProcBlk(*dp))]);
             putstr(f, ProcBlk(*dp).name);
         }
      }
      list: {
         /*
          * listimage does the work for lists.
          */
         listimage(f, &ListBlk(*dp), noimage);
         }

      table: {
         /*
          * Print "table#m(n)" where n is the size of the table.
          */
         fprintf(f, "table#%ld(%ld)", (long)TableBlk(*dp).id,
            (long)TableBlk(*dp).size);
         }

      set: {
	/*
         * print "set#m(n)" where n is the cardinality of the set
         */
	fprintf(f,"set#%ld(%ld)",(long)SetBlk(*dp).id,
           (long)SetBlk(*dp).size);
        }

     cast: {
             /* Call recursively on the two elements of the cast */
             bp = BlkLoc(*dp);
             fprintf(f, "cast(");
             tdp.dword = D_Object;
             BlkLoc(tdp) = (union block*)bp->cast.object;
             outimage(f, &tdp, noimage);
             fprintf(f, ",");
             tdp.dword = D_Class;
             BlkLoc(tdp) = (union block*)bp->cast.class;
             outimage(f, &tdp, noimage);
             fprintf(f, ")");
     }

     methp: {
             struct class_field *field;
             struct b_proc *proc0;
             bp = BlkLoc(*dp);
             proc0 = bp->methp.proc;
             field = proc0->field;
             fprintf(f, "methp(");
             tdp.dword = D_Object;
             BlkLoc(tdp) = (union block*)bp->methp.object;
             outimage(f, &tdp, noimage);
             fprintf(f, ",");
             tdp.dword = D_Proc;
             BlkLoc(tdp) = (union block*)bp->methp.proc;
             outimage(f, &tdp, noimage);
             fprintf(f, ")");
     }

     object: {
             /*
              * If noimage is nonzero, print "object classname(n)" where n is the
              *  number of fields in the record.  If noimage is zero, print
              *  the image of each field instead of the number of fields.
              */
             bp = BlkLoc(*dp);
             fprintf(f, "object ");
             putstr(f, bp->object.class->name);
             fprintf(f, "#%ld", (long)bp->object.id);
             j = bp->object.class->n_instance_fields;
             if (j <= 0)
                 fprintf(f, "()");
             else if (noimage > 0)
                 fprintf(f, "(%ld)", (long)j);
             else {
                 putc('(', f);
                 i = 0;
                 for (;;) {
                     outimage(f, &bp->object.fields[i], noimage + 1);
                     if (++i >= j)
                         break;
                     putc(',', f);
                 }
                 putc(')', f);
             }
         }

      record: {
         /*
          * If noimage is nonzero, print "record(n)" where n is the
          *  number of fields in the record.  If noimage is zero, print
          *  the image of each field instead of the number of fields.
          */
         bp = BlkLoc(*dp);
         fprintf(f, "record ");
         putstr(f, bp->record.constructor->name);
         fprintf(f, "#%ld", (long)bp->record.id);
         j = bp->record.constructor->n_fields;
         if (j <= 0)
            fprintf(f, "()");
         else if (noimage > 0)
            fprintf(f, "(%ld)", (long)j);
         else {
            putc('(', f);
            i = 0;
            for (;;) {
               outimage(f, &bp->record.fields[i], noimage + 1);
               if (++i >= j)
                  break;
               putc(',', f);
               }
            putc(')', f);
            }
         }

      coexpr: {
         fprintf(f, "co-expression#%ld(%ld)",
            (long)CoexprBlk(*dp).id,
            (long)CoexprBlk(*dp).size);
         }

      tvsubs: {
         /*
          * Produce "v[i+:j] = value" where v is the image of the variable
          *  containing the substring, i is starting position of the substring
          *  j is the length, and value is the string v[i+:j].	If the length
          *  (j) is one, just produce "v[i] = value".
          */
         bp = BlkLoc(*dp);
         if (is:kywdsubj(bp->tvsubs.ssvar)) {
            dp = VarLoc(bp->tvsubs.ssvar);
            fprintf(f, "&subject");
            }
         else if (is:struct_var(bp->tvsubs.ssvar)) {
            dp = OffsetVarLoc(bp->tvsubs.ssvar);
            outimage(f, dp, noimage);
            }
         else if (is:named_var(bp->tvsubs.ssvar)) {
            dp = VarLoc(bp->tvsubs.ssvar);
            outimage(f, dp, noimage);
            }
         else {
            dp = &bp->tvsubs.ssvar;
            outimage(f, dp, noimage);
         }

         if (bp->tvsubs.sslen == 1)
            fprintf(f, "[%ld]", (long)bp->tvsubs.sspos);
         else
            fprintf(f, "[%ld+:%ld]", (long)bp->tvsubs.sspos, (long)bp->tvsubs.sslen);

         if (is:ucs(*dp)) {
             struct descrip utf8_subs;
             if (bp->tvsubs.sspos + bp->tvsubs.sslen - 1 > UcsBlk(*dp).length)
                 return;
             utf8_substr(&UcsBlk(*dp),
                         bp->tvsubs.sspos,
                         bp->tvsubs.sslen,
                         &utf8_subs);
             i = bp->tvsubs.sslen;
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
         else if (Qual(*dp)) {
             if (bp->tvsubs.sspos + bp->tvsubs.sslen - 1 > StrLen(*dp))
                 return;
             StrLen(q) = bp->tvsubs.sslen;
             StrLoc(q) = StrLoc(*dp) + bp->tvsubs.sspos - 1;
             fprintf(f, " = ");
             outimage(f, &q, noimage);
         }

        }

      tvtbl: {
         /*
          * produce "t[s]" where t is the image of the table containing
          *  the element and s is the image of the subscript.
          */
         bp = BlkLoc(*dp);
         tdp.dword = D_Table;
	 BlkLoc(tdp) = bp->tvtbl.clink;
	 outimage(f, &tdp, noimage);
         putc('[', f);
         outimage(f, &bp->tvtbl.tref, noimage);
         putc(']', f);
         }

      kywdint: {
         if (VarLoc(*dp) == &kywd_ran)
            fprintf(f, "&random = ");
         else if (VarLoc(*dp) == &kywd_trace)
            fprintf(f, "&trace = ");
         else if (VarLoc(*dp) == &kywd_dump)
            fprintf(f, "&dump = ");
         else if (VarLoc(*dp) == &kywd_maxlevel)
            fprintf(f, "&maxlevel = ");
         outimage(f, VarLoc(*dp), noimage);
         }

      kywdhandler: {
         fprintf(f, "&handler = ");
         outimage(f, VarLoc(*dp), noimage);
         }

      kywdstr: {
         if (VarLoc(*dp) == &kywd_prog)
            fprintf(f, "&progname = ");
         if (VarLoc(*dp) == &kywd_why)
            fprintf(f, "&why = ");
         outimage(f, VarLoc(*dp), noimage);
         }

      kywdpos: {
         fprintf(f, "&pos = ");
         outimage(f, VarLoc(*dp), noimage);
         }

      kywdsubj: {
         fprintf(f, "&subject = ");
         outimage(f, VarLoc(*dp), noimage);
         }

     struct_var: {
         dptr varptr;
         bp = BlkLoc(*dp);
         varptr = OffsetVarLoc(*dp);
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
                 outimage(f, &TvtblBlk(*dp).tref, noimage);
                 putc(']', f);
                 break;
             }
             case T_Lelem: { 		/* list */
                 /* Find and print the list block and the index */
                 word i = varptr - &bp->lelem.lslots[bp->lelem.first] + 1;
                 if (i < 1)
                     i += bp->lelem.nslots;
                 while (BlkType(bp->lelem.listprev) == T_Lelem) {
                     bp = bp->lelem.listprev;
                     i += bp->lelem.nused;
                 }
                 tdp.dword = D_List;
                 BlkLoc(tdp) = bp->lelem.listprev;
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f,"[%ld]", (long)i);
                 break;
             }
             case T_Object: { 		/* object */
                 struct b_class *c = bp->object.class;
                 dptr fname;
                 i = varptr - bp->object.fields;
                 fname =  c->program->Fnames[c->fields[i]->fnum];
                 tdp.dword = D_Object;
                 BlkLoc(tdp) = bp;
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f," . %.*s", (int)StrLen(*fname), StrLoc(*fname));
                 break;
             }
             case T_Record: { 		/* record */
                 struct b_constructor *c = bp->record.constructor;
                 dptr fname;
                 i = varptr - bp->record.fields;
                 fname = c->program->Fnames[c->fnums[i]];
                 tdp.dword = D_Record;
                 BlkLoc(tdp) = bp;
                 outimage(f, &tdp, noimage + 1);
                 fprintf(f," . %.*s", (int)StrLen(*fname), StrLoc(*fname));
                 break;
             }
             default: {		/* none of the above */
                 fprintf(f, "struct_var");
             }
         }
         fprintf(f, " = ");
         dp = OffsetVarLoc(*dp);
         outimage(f, dp, noimage);
      }
     named_var: {
         fprintf(f, "(variable = ");
         dp = VarLoc(*dp);
         outimage(f, dp, noimage);
         putc(')', f);
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

static void listimage(FILE *f, struct b_list *lp, int noimage)
   {
   word i, j;
   struct b_lelem *bp;
   word size, count;

   bp = (struct b_lelem *) lp->listhead;
   size = lp->size;

   if (noimage > 0 && size > 0) {
      /*
       * Just give indication of size if the list isn't empty.
       */
      fprintf(f, "list#%ld(%ld)", (long)lp->id, (long)size);
      return;
      }

   /*
    * Print [e1,...,en] on f.  If more than ListLimit elements are in the
    *  list, produce the first ListLimit/2 elements, an ellipsis, and the
    *  last ListLimit elements.
    */

   fprintf(f, "list#%ld = [", (long)lp->id);

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
            outimage(f, &bp->lslots[j], noimage+1);
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
   word len;
   int i, j;
   tended char *s;
   union block *bp;
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
               sprintf(sbuf,"integer(~10^%ld)",(long)dlen);
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
             char *type0 = proc_kinds[get_proc_kind(&ProcBlk(*dp1))];
             len = strlen(type0) + 1 + StrLen(*ProcBlk(*dp1).name);
             MemProtect (StrLoc(*dp2) = reserve(Strings, len));
             StrLen(*dp2) = len;
             alcstr(type0, strlen(type0));
             alcstr(" ", 1);
             alcstr(StrLoc(*ProcBlk(*dp1).name), StrLen(*ProcBlk(*dp1).name));
         }
      }

      list: {
         /*
          * Produce:
          *  "list#m(n)"
          * where n is the current size of the list.
          */
         bp = BlkLoc(*dp1);
         sprintf(sbuf, "list#%ld(%ld)", (long)bp->list.id, (long)bp->list.size);
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
         bp = BlkLoc(*dp1);
         sprintf(sbuf, "table#%ld(%ld)", (long)bp->table.id,
            (long)bp->table.size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
         StrLen(*dp2) = len;
         }

      set: {
         /*
          * Produce "set#m(n)" where n is size of the set.
          */
         bp = BlkLoc(*dp1);
         sprintf(sbuf, "set#%ld(%ld)", (long)bp->set.id, (long)bp->set.size);
         len = strlen(sbuf);
         MemProtect(StrLoc(*dp2) = alcstr(sbuf,len));
         StrLen(*dp2) = len;
         }

      record: {
         /*
          * Produce:
          *  "record name_m(n)"
          * where n is the number of fields.
          */
         struct b_constructor *rec_const;
         bp = BlkLoc(*dp1);
         rec_const = bp->record.constructor;
         sprintf(sbuf, "#%ld(%ld)", (long)bp->record.id, (long)rec_const->n_fields);
         len = 7 + strlen(sbuf) + StrLen(*rec_const->name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         /* No need to refresh pointer, rec_const is static */
         alcstr("record ", 7);
         alcstr(StrLoc(*rec_const->name),StrLen(*rec_const->name));
         alcstr(sbuf, strlen(sbuf));
         }

  
     cast: {
           struct b_object *obj;
           struct b_class *cast_class, *obj_class;
           /*
            * Produce:
            *  "cast(object objectname#m(n),class classname)"     
            */
           bp = BlkLoc(*dp1);
           obj = bp->cast.object;
           obj_class = obj->class;
           cast_class = bp->cast.class;

           sprintf(sbuf, "#%ld(%ld),class ", (long)obj->id, (long)obj_class->n_instance_fields);
           len = StrLen(*obj_class->name) + StrLen(*cast_class->name) + strlen(sbuf) + 13;

           MemProtect (StrLoc(*dp2) = reserve(Strings, len));
           StrLen(*dp2) = len;
           /* No need to refresh pointers, everything is static data */
           alcstr("cast(object ", 12);
           alcstr(StrLoc(*obj_class->name),StrLen(*obj_class->name));
           alcstr(sbuf, strlen(sbuf));
           alcstr(StrLoc(*cast_class->name),StrLen(*cast_class->name));
           alcstr(")", 1);
       }

     methp: {
           struct b_object *obj;
           struct class_field *field;
           struct b_class *obj_class;
           struct b_proc *proc0;
           bp = BlkLoc(*dp1);
           obj = bp->methp.object;
           obj_class = obj->class;
           sprintf(sbuf, "#%ld(%ld),", (long)obj->id, (long)obj_class->n_instance_fields);
           proc0 = bp->methp.proc;
           field = proc0->field;
           if (field) {
               /*
                * Produce:
                *  "methp(object objectname#m(n),method classname.fieldname)"
                */
               struct b_class * field_class = field->defining_class;
               dptr field_name = field_class->program->Fnames[field->fnum];
               len = StrLen(*obj_class->name) + StrLen(*field_class->name) + StrLen(*field_name) + strlen(sbuf) + 22;
               MemProtect (StrLoc(*dp2) = reserve(Strings, len));
               StrLen(*dp2) = len;
               /* No need to refresh pointers, everything is static data */
               alcstr("methp(object ", 13);
               alcstr(StrLoc(*obj_class->name),StrLen(*obj_class->name));
               alcstr(sbuf, strlen(sbuf));
               alcstr("method ", 7);
               alcstr(StrLoc(*field_class->name),StrLen(*field_class->name));
               alcstr(".", 1);
               alcstr(StrLoc(*field_name),StrLen(*field_name));
               alcstr(")", 1);
           } else {
               /* No field - it should only be possible to be the deferred method stub here */
               if (proc0 != (struct b_proc *)&Bdeferred_method_stub)
                   syserr("Expected deferred_method_stub");
               len = StrLen(*obj_class->name) + strlen(sbuf) + 29;
               MemProtect (StrLoc(*dp2) = reserve(Strings, len));
               StrLen(*dp2) = len;
               /* No need to refresh pointers, everything is static data */
               alcstr("methp(object ", 13);
               alcstr(StrLoc(*obj_class->name), StrLen(*obj_class->name));
               alcstr(sbuf, strlen(sbuf));
               alcstr("deferred method)", 16);
           }
       }

     object: {
           /*
            * Produce:
            *  "object name#m(n)"     
            * where n is the number of fields.
            */
           struct b_class *obj_class;
           bp = BlkLoc(*dp1);
           obj_class = bp->object.class;   
           sprintf(sbuf, "#%ld(%ld)", (long)bp->object.id, (long)obj_class->n_instance_fields);
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

         sprintf(sbuf, "#%ld(%ld)", (long)CoexprBlk(*dp1).id,
            (long)CoexprBlk(*dp1).size);
         len = strlen(sbuf) + 13;
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("co-expression", 13);
         alcstr(sbuf, strlen(sbuf));
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
static int sicmp(stringint *sip1, stringint *sip2)
{
    return strcmp(sip1->s, sip2->s);
}

/*
 * string-integer lookup function: given a string, return its integer
 */
int stringint_str2int(stringint * sip, char *s)
{
    stringint key;
    stringint * p;
    key.s = s;
    p = (stringint *)bsearch((char *)&key,(char *)(sip+1),sip[0].i,sizeof(key),(BSearchFncCast)sicmp);
    if (p) return p->i;
    return -1;
}

/*
 * string-integer inverse function: given an integer, return its string
 */
char *stringint_int2str(stringint * sip, int i)
{
    stringint * sip2 = sip+1;
    for(;sip2<=sip+sip[0].i;sip2++) if (sip2->i == i) return sip2->s;
    return NULL;
}

stringint *stringint_lookup(stringint *sip, char *s)
{
    stringint key;
    key.s = s;
    return (stringint *)bsearch((char *)&key,(char *)(sip+1),sip[0].i,sizeof(key),(BSearchFncCast)sicmp);
}

/*
 * Set &why to an error message based on errno.
 */
void errno2why()
{
#if PLAN9
    static char buff[ERRMAX];
    rerrstr(buff, sizeof(buff));
    why(buff);
#else
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
#endif
}

/*
 * Set &why to a simple string.
 */
void why(char *s)
{
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


dptr lookup_global(dptr name, struct progstate *prog)
{
    dptr *p = (dptr *)bsearch(name, prog->Gnames, prog->NGlobals, 
                              sizeof(dptr), 
                              (BSearchFncCast)pdptr_cmp);
    if (!p)
        return 0;

    /* Convert from pointer into names array to pointer into descriptor array */
    return prog->Globals + (p - prog->Gnames);
}


struct loc *lookup_global_loc(dptr name, struct progstate *prog)
{
    dptr *p;

    /* Check if the table was compiled into the icode */
    if (prog->Glocs == prog->Eglocs)
        return 0;

    p = (dptr *)bsearch(name, prog->Gnames, prog->NGlobals, 
                        sizeof(dptr), 
                        (BSearchFncCast)pdptr_cmp);
    if (!p)
        return 0;

    /* Convert from pointer into names array to pointer into location array */
    return prog->Glocs + (p - prog->Gnames);
}

static int named_global_cmp(dptr p1, dptr p2)
{
    type_case *p2 of {
      proc: return lexcmp(p1, ProcBlk(*p2).name);
      constructor: return lexcmp(p1, ConstructorBlk(*p2).name);
      class: return lexcmp(p1, ClassBlk(*p2).name);
      default: syserr("named_global_cmp: unknown type");
    }
    /* not reached */
    return 0;
}

dptr lookup_named_global(dptr name, struct progstate *prog)
{
    return (dptr)bsearch(name, prog->NamedGlobals, prog->NNamedGlobals,
                         sizeof(struct descrip),
                         (BSearchFncCast)named_global_cmp);
}


static char c_buff[4096];     /* Buff for conversion to static C strings */

char *buffstr(dptr d)
{
    if (StrLen(*d) >= sizeof(c_buff))
        fatalerr(149, d);
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
            fatalerr(149, d);
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
