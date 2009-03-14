/*
 * File: rmisc.r
 *  Contents: deref, eq, getvar, hash, outimage,
 *  qtos, pushact, popact, topact, [dumpact], 
 *  findline, findfile, getimage
 *  sig_rsm, cmd_line, varargs.
 *
 *  Integer overflow checking.
 */

/*
 * Prototypes.
 */

static void	listimage
   (FILE *f,struct b_list *lp, int noimage);
static char *	csname		(dptr dp);


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
    register dptr dp;
    register dptr np;
    register int i;
    struct b_proc *bp;
    struct pf_marker *t_pfp;
    dptr t_argp;

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
                    VarLoc(*vp) = &kywd_dmp;
                    return Succeeded;
                }
                break;
            }
            case 6 : {
                if (strncmp(t,"error",5) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &p->Kywd_err;
                    return Succeeded;
                }
                if (strncmp(t,"trace",5) == 0) {
                    vp->dword = D_Kywdint;
                    VarLoc(*vp) = &p->Kywd_trc;
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
                if (strncmp(t,"subject",7) == 0) {
                    vp->dword = D_Kywdsubj;
                    VarLoc(*vp) = &p->Kywd_subject;
                    return Succeeded;
                }
                break;
            }
            case 9 : {
                if (strncmp(t,"progname",8) == 0) {
                    vp->dword = D_Kywdstr;
                    VarLoc(*vp) = &p->Kywd_prog;
                    return Succeeded;
                }
                break;
            }
            case 10 : {
                if (strncmp(t,"eventcode",9) == 0) {
                    vp->dword = D_Var;
                    VarLoc(*vp) = &p->eventcode;
                    return Succeeded;
                }
                break;
            }
            case 11 : {
                if (strncmp(t,"eventvalue",10) == 0) {
                    vp->dword = D_Var;
                    VarLoc(*vp) = &p->eventval;
                    return Succeeded;
                }
                break;
            }
            case 12 : {
                if (strncmp(t,"eventsource",11) == 0) {
                    vp->dword = D_Var;
                    VarLoc(*vp) = &p->eventsource;
                    return Succeeded;
                }
                break;
            }
        }
        return Failed;
    }

    /*
     * Look for the variable the name with the local identifiers,
     *  parameters, and static names in each Icon procedure frame on the
     *  stack. If not found among the locals, check the global variables.
     *  If a variable with name is found, variable() returns a variable
     *  descriptor that points to the corresponding value descriptor. 
     *  If no such variable exits, it fails.
     */
    if (p == curpstate) {
        t_pfp = pfp;
        t_argp = argp;
    }
    else {
        t_pfp = BlkLoc(p->K_current)->coexpr.es_pfp;
        t_argp = BlkLoc(p->K_current)->coexpr.es_argp;
    }

    /*
     *  If no procedure has been called (as can happen with icon_call(),
     *  dont' try to find local identifier.
     */
    if (t_pfp && t_argp) {
        dp = t_argp;
        bp = (struct b_proc *)BlkLoc(*dp);	/* get address of procedure block */
   
        np = bp->lnames;		/* Check the formal parameter names. */


        for (i = abs((int)bp->nparam); i > 0; i--) {
            dp++;

            if (eq(s,np)) {
                vp->dword = D_Var;
                VarLoc(*vp) = (dptr)dp;
                return ParamName;
            }
            np++;
        }

        dp = &t_pfp->pf_locals[0];

        for (i = (int)bp->ndynam; i > 0; i--) { /* Check the local dynamic names. */
            if (eq(s,np)) {
                vp->dword = D_Var;
                VarLoc(*vp) = (dptr)dp;
                return LocalName;
            }
            np++;
            dp++;
        }

        dp = bp->fstatic; /* Check the local static names. */
        for (i = (int)bp->nstatic; i > 0; i--) {
            if (eq(s,np)) {
                vp->dword = D_Var;
                VarLoc(*vp) = (dptr)dp;
                return StaticName;
            }
            np++;
            dp++;
        }
    }

    /* Check the global variable names. */
    if ((dp = lookup_global(s, p))) {
        vp->dword    =  D_Var;
        VarLoc(*vp) =  dp;
        return GlobalName;
    }
    return Failed;
}

/*
 * hash - compute hash value of arbitrary object for table and set accessing.
 */

uword hash(dp)
dptr dp;
   {
   register char *s;
   register uword i;
   register word j, n;
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
	    struct b_bignum *b = &BlkLoc(*dp)->bignumblk;

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
            GetReal(dp,r);
            i = r * 1129.27586206896558;
            break;

         /*
          * The hash value of a cset is based on a convoluted combination
          *  of all its range values.
          */
         case T_Cset:
            i = 0;
            for (j = 0; j < BlkLoc(*dp)->cset.n_ranges; j++) {
                i += BlkLoc(*dp)->cset.range[j].from;
                i *= 37;			/* better distribution */
                i += BlkLoc(*dp)->cset.range[j].to;
                i *= 37;			/* better distribution */
               }
            i %= 1048583;		/* scramble the bits */
            break;

         /*
          * The hash value of a list, set, table, or record is its id,
          *   hashed like an integer.
          */
         case T_List:
            i = (13255 * BlkLoc(*dp)->list.id) >> 10;
            break;

         case T_Set:
            i = (13255 * BlkLoc(*dp)->set.id) >> 10;
            break;

         case T_Table:
            i = (13255 * BlkLoc(*dp)->table.id) >> 10;
            break;

         case T_Record:
            i = (13255 * BlkLoc(*dp)->record.id) >> 10;
            break;

         case T_Object:
            i = (13255 * BlkLoc(*dp)->object.id) >> 10;
            break;

         case T_Class:
	    dp = &(BlkLoc(*dp)->class.name);
	    goto hashstring;

         case T_Constructor:
	    dp = &(BlkLoc(*dp)->constructor.name);
	    goto hashstring;

         case T_Cast:
            i = (13255 * BlkLoc(*dp)->cast.object->id) >> 10;
            break;
 
         case T_Methp:
            i = (13255 * BlkLoc(*dp)->methp.object->id) >> 10;
            break;

	 case T_Ucs:
	    dp = &(BlkLoc(*dp)->ucs.utf8);
	    goto hashstring;

	 case T_Proc:
	    dp = &(BlkLoc(*dp)->proc.pname);
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
    if (c < 128 && isprint(c)) {
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
            case LineFeed:			/* new line */
                if (b) strncpy(b, "\\n", 2);
                return 2;

            case CarriageReturn:		/* carriage return b */
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

void outimage(f, dp, noimage)
FILE *f;
dptr dp;
int noimage;
   {
   word i, j, k;
   char *s;
   union block *bp;
   char *csn;
   FILE *fd;
   struct descrip q;
   double rresult;
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
             fwrite(cbuf, 1, n, f);
         }
         if (i > StringLimit)
             fprintf(f, "...");
         putc('"', f);
         }

      ucs: {
         i = BlkLoc(*dp)->ucs.length;
         s = StrLoc(BlkLoc(*dp)->ucs.utf8);
         j = Min(i, StringLimit);
         fprintf(f, "u\"");
         while (j-- > 0) {
             int n;
             k = utf8_iter(&s);
             n = ucs_charstr(k, cbuf);
             fwrite(cbuf, 1, n, f);
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
         char s[30];
         struct descrip rd;

         GetReal(dp,rresult);
         rtos(rresult, &rd, s);
         fprintf(f, "%s", StrLoc(rd));
         }

      cset: {
         /*
	  * Check for a predefined cset; use keyword name if found.
	  */
	 if ((csn = csname(dp)) != NULL) {
	    fprintf(f, csn);
	    return;
	    }
         putc('\'', f);
         j = StringLimit;
         for (i = 0; i < BlkLoc(*dp)->cset.n_ranges; ++i) {
             int from, to, n;
             from = BlkLoc(*dp)->cset.range[i].from;
             to = BlkLoc(*dp)->cset.range[i].to;
             if (cset_do_range(from, to)) {
                 if (j <= 0) {
                     fprintf(f, "...");
                     i = BlkLoc(*dp)->cset.n_ranges;
                     break;
                 }
                 n = cset_charstr(from, cbuf);
                 fwrite(cbuf, 1, n, f);
                 putc('-', f);
                 n = cset_charstr(to, cbuf);
                 fwrite(cbuf, 1, n, f);
                 j -= 2;
             } else {
                 int k;
                 for (k = from; k <= to; ++k) {
                     if (j-- <= 0) {
                         fprintf(f, "...");
                         i = BlkLoc(*dp)->cset.n_ranges;
                         break;
                     }
                     n = cset_charstr(k, cbuf);
                     fwrite(cbuf, 1, n, f);
                 }
             }
         }
         putc('\'', f);
        }


     class: {
           /* produce "class " + the class name */
         i = StrLen(BlkLoc(*dp)->class.name);
         s = StrLoc(BlkLoc(*dp)->class.name);
         fprintf(f, "class ");
         fwrite(s, 1, i, f);
         }

     constructor: {
           /* produce "constructor " + the type name */
         i = StrLen(BlkLoc(*dp)->constructor.name);
         s = StrLoc(BlkLoc(*dp)->constructor.name);
         fprintf(f, "constructor ");
         fwrite(s, 1, i, f);
         }

      proc: {
         struct class_field *field = BlkLoc(*dp)->proc.field;
         if (field) {
             /*
              * Produce "method classname.fieldname"
              */
             fprintf(f, "method ");
             dp = &field->defining_class->name;
             i = StrLen(*dp);
             s = StrLoc(*dp);
             fwrite(s, 1, i, f);
             fprintf(f, ".");
             dp = &field->name;
             i = StrLen(*dp);
             s = StrLoc(*dp);
             fwrite(s, 1, i, f);
         } else {
             /*
              * Produce one of:
              *  "procedure name"
              *  "function name"
              */
             i = StrLen(BlkLoc(*dp)->proc.pname);
             s = StrLoc(BlkLoc(*dp)->proc.pname);
             if (BlkLoc(*dp)->proc.program)
                 fprintf(f, "procedure ");
             else
                 fprintf(f, "function ");
             fwrite(s, 1, i, f);
         }
      }
      list: {
         /*
          * listimage does the work for lists.
          */
         listimage(f, (struct b_list *)BlkLoc(*dp), noimage);
         }

      table: {
         /*
          * Print "table#m(n)" where n is the size of the table.
          */
         fprintf(f, "table#%ld(%ld)", (long)BlkLoc(*dp)->table.id,
            (long)BlkLoc(*dp)->table.size);
         }

      set: {
	/*
         * print "set#m(n)" where n is the cardinality of the set
         */
	fprintf(f,"set#%ld(%ld)",(long)BlkLoc(*dp)->set.id,
           (long)BlkLoc(*dp)->set.size);
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
             struct b_proc *proc;
             bp = BlkLoc(*dp);
             proc = bp->methp.proc;
             field = proc->field;
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
             i = StrLen(bp->object.class->name);
             s = StrLoc(bp->object.class->name);
             fprintf(f, "object ");
             fwrite(s, 1, i, f);
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
         i = StrLen(bp->record.constructor->name);
         s = StrLoc(bp->record.constructor->name);
         fprintf(f, "record ");
         fwrite(s, 1, i, f);
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
            (long)((struct b_coexpr *)BlkLoc(*dp))->id,
            (long)((struct b_coexpr *)BlkLoc(*dp))->size);
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
            fflush(f);
            }
         else if (is:variable(bp->tvsubs.ssvar)) {
            dp = (dptr)((word *)VarLoc(bp->tvsubs.ssvar) + Offset(bp->tvsubs.ssvar));
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
             if (bp->tvsubs.sspos + bp->tvsubs.sslen - 1 > BlkLoc(*dp)->ucs.length)
                 return;
             utf8_substr(&BlkLoc(*dp)->ucs,
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
                 fwrite(cbuf, 1, n, f);
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
         else if (VarLoc(*dp) == &kywd_trc)
            fprintf(f, "&trace = ");
         else if (VarLoc(*dp) == &kywd_dmp)
            fprintf(f, "&dump = ");
         else if (VarLoc(*dp) == &kywd_err)
            fprintf(f, "&error = ");
         outimage(f, VarLoc(*dp), noimage);
         }

      kywdevent: {
         if (VarLoc(*dp) == &curpstate->eventsource)
            fprintf(f, "&eventsource = ");
         else if (VarLoc(*dp) == &curpstate->eventcode)
            fprintf(f, "&eventcode = ");
         else if (VarLoc(*dp) == &curpstate->eventval)
            fprintf(f, "&eventval = ");
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

      default: { 
         if (is:variable(*dp)) {
            /*
             * *d is a variable.  Print "variable =", dereference it, and 
             *  call outimage to handle the value.
             */
            fprintf(f, "(variable = ");
            dp = (dptr)((word *)VarLoc(*dp) + Offset(*dp));
            outimage(f, dp, noimage);
            putc(')', f);
            }
         else if (Type(*dp) == T_External)
            fprintf(f, "external(%d)",((struct b_external *)BlkLoc(*dp))->blksize);
         else if (Type(*dp) <= MaxType)
            fprintf(f, "%s", blkname[Type(*dp)]);
         else
            syserr("outimage: unknown type");
         }
      }
   }


/*
 * listimage - print an image of a list.
 */

static void listimage(f, lp, noimage)
FILE *f;
struct b_list *lp;
int noimage;
   {
   register word i, j;
   register struct b_lelem *bp;
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
 * pushact - push actvtr on the activator stack of ce
 */
int pushact(ce, actvtr)
struct b_coexpr *ce, *actvtr;
{
   struct astkblk *abp = ce->es_actstk;

   abp->arec[0].activator = actvtr;
   return Succeeded;
}

/*
 * popact - pop the most recent activator from the activator stack of ce
 *  and return it.
 */
struct b_coexpr *popact(ce)
struct b_coexpr *ce;
{


   struct astkblk *abp = ce->es_actstk;

   return abp->arec[0].activator;


}

/*
 * topact - return the most recent activator of ce.
 */
struct b_coexpr *topact(ce)
struct b_coexpr *ce;
{
   struct astkblk *abp = ce->es_actstk;
   
   return abp->arec[0].activator;
}


/*
 * dumpact - dump an activator stack
 */
void dumpact(ce)
struct b_coexpr *ce;
{
   struct astkblk *abp = ce->es_actstk;
   struct actrec *arp;
   int i;

   if (abp)
      fprintf(stderr, "Ce %ld ", (long)ce->id);
   while (abp) {
      fprintf(stderr, "--- Activation stack block (%x) --- nact = %d\n",
         abp, abp->nactivators);
      for (i = abp->nactivators; i >= 1; i--) {
         arp = &abp->arec[i-1];
         /*for (j = 1; j <= arp->acount; j++)*/
         fprintf(stderr, "co-expression_%ld(%d)\n", (long)(arp->activator->id),
            arp->acount);
         }
      abp = abp->astk_nxt;
      }
}


/*
 * findline - find the source line number associated with the ipc
 */
struct ipc_line *find_ipc_line(word *ipc, struct progstate *p)
{
   uword ipc_offset;
   int size, l, r, m;
   
   if (!InRange(p->Code,ipc,p->Ecode))
      return 0;
   ipc_offset = DiffPtrs((char *)ipc,(char *)p->Code);
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

int findline(word *ipc)
{
    struct ipc_line *p = find_ipc_line(ipc, curpstate);
    return p ? p->line : 0;
}

struct ipc_fname *find_ipc_fname(word *ipc, struct progstate *p)
{
   uword ipc_offset;
   int size, l, r, m;

   if (!InRange(p->Code,ipc,p->Ecode))
       return 0;

   ipc_offset = DiffPtrs((char *)ipc,(char *)p->Code);

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
 * findfile - find source file name associated with the ipc
 */
dptr findfile(word *ipc)
{
    struct ipc_fname *p = find_ipc_fname(ipc, curpstate);
    return p ? &p->fname : 0;
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
 * getimage(dp1,dp2) - return string image of object dp1 in dp2.
 */

int getimage(dp1,dp2)
dptr dp1, dp2;
   {
   register word len;
   int i, j;
   tended char *s;
   tended struct descrip source = *dp1;    /* the source may move during gc */
   register union block *bp;
   char sbuf[64];
   char cbuf[CHAR_CVT_LEN];
   FILE *fd;

   type_case source of {
      string: {
         s = StrLoc(source);
         i = StrLen(source);
         len = 2;  /* quotes */
         while (i-- > 0)
             len += str_charstr(*s++ & 0xff, 0);
	 MemProtect(StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("\"", 1);
         s = StrLoc(source);
         i = StrLen(source);
         while (i-- > 0) {
             int n = str_charstr(*s++ & 0xff, cbuf);
             alcstr(cbuf, n);
         }
         alcstr("\"", 1);
         }

      ucs: {
         s = StrLoc(BlkLoc(source)->ucs.utf8);
         i = BlkLoc(source)->ucs.length;
         len = 3;  /* u"" */
         while (i-- > 0) {
             j = utf8_iter(&s);
             len += ucs_charstr(j, 0);
         }
	 MemProtect(StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;

         alcstr("u\"", 2);
             
         s = StrLoc(BlkLoc(source)->ucs.utf8);
         i = BlkLoc(source)->ucs.length;
         while (i-- > 0) {
             int n;
             j = utf8_iter(&s);
             n = ucs_charstr(j, cbuf);
             alcstr(cbuf, n);
         }

         alcstr("\"", 1);
         }

      null: {
         StrLoc(*dp2) = "&null";
         StrLen(*dp2) = 5;
         }

     class: {
           /* produce "class " + the class name */
         len = 6 + StrLen(BlkLoc(source)->class.name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("class ", 6);
         alcstr(StrLoc(BlkLoc(source)->class.name), StrLen(BlkLoc(source)->class.name));
       }

     constructor: {
          /* produce "constructor " + the type name */
         len = 12 + StrLen(BlkLoc(source)->constructor.name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("constructor ", 12);
         alcstr(StrLoc(BlkLoc(source)->constructor.name), StrLen(BlkLoc(source)->constructor.name));
       }

      integer: {
         if (Type(source) == T_Lrgint) {
            word slen;
            word dlen;
            struct b_bignum *blk = &BlkLoc(source)->bignumblk;

            slen = blk->lsd - blk->msd;
            dlen = slen * NB * 0.3010299956639812 	/* 1 / log2(10) */
               + log((double)blk->digits[blk->msd]) * 0.4342944819032518 + 0.5;
							/* 1 / ln(10) */
            if (dlen >= MaxDigits) {
               sprintf(sbuf,"integer(~10^%ld)",(long)dlen);
	       len = strlen(sbuf);
               MemProtect(StrLoc(*dp2) = alcstr(sbuf,len));


               StrLen(*dp2) = len;
               }
	    else bigtos(&source,dp2);
	    }
         else
            cnv: string(source, *dp2);
	 }

      real: {
         cnv:string(source, *dp2);
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
	    return Succeeded;
	    }
	 /*
	  * Otherwise, describe it in terms of the character membership.
	  */
         len = 2;   /* 2 quotes */
         for (i = 0; i < BlkLoc(source)->cset.n_ranges; ++i) {
             from = BlkLoc(source)->cset.range[i].from;
             to = BlkLoc(source)->cset.range[i].to;
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
         for (i = 0; i < BlkLoc(source)->cset.n_ranges; ++i) {
             int n;
             from = BlkLoc(source)->cset.range[i].from;
             to = BlkLoc(source)->cset.range[i].to;
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
         struct class_field *field = BlkLoc(source)->proc.field;
         if (field) {
             /*
              * Produce "method classname.fieldname"
              */
             dptr field_name = &field->name;
             struct b_class *field_class = field->defining_class;
             len = StrLen(field_class->name) + StrLen(*field_name) + 8;
             MemProtect (StrLoc(*dp2) = reserve(Strings, len));
             StrLen(*dp2) = len;
             /* No need to refresh pointers, everything is static data */
             alcstr("method ", 7);
             alcstr(StrLoc(field_class->name),StrLen(field_class->name));
             alcstr(".", 1);
             alcstr(StrLoc(*field_name),StrLen(*field_name));
         } else {
             char *type;
             /*
              * Produce one of:
              *  "procedure name"
              *  "function name"
              *
              */
             if (BlkLoc(source)->proc.program)
                 type = "procedure ";
             else
                 type = "function ";

             len = strlen(type) + StrLen(BlkLoc(source)->proc.pname);
             MemProtect (StrLoc(*dp2) = reserve(Strings, len));
             StrLen(*dp2) = len;
             alcstr(type, strlen(type));
             alcstr(StrLoc(BlkLoc(source)->proc.pname), StrLen(BlkLoc(source)->proc.pname));
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
          *  "record name_m(n)"	-- under construction
          * where n is the number of fields.
          */
         struct b_constructor *rec_const;
         bp = BlkLoc(*dp1);
         rec_const = bp->record.constructor;
         sprintf(sbuf, "#%ld(%ld)", (long)bp->record.id, (long)rec_const->n_fields);
         len = 7 + strlen(sbuf) + StrLen(rec_const->name);
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         /* No need to refresh pointer, rec_const is static */
         alcstr("record ", 7);
         alcstr(StrLoc(rec_const->name),StrLen(rec_const->name));
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
           len = StrLen(obj_class->name) + StrLen(cast_class->name) + strlen(sbuf) + 13;

           MemProtect (StrLoc(*dp2) = reserve(Strings, len));
           StrLen(*dp2) = len;
           /* No need to refresh pointers, everything is static data */
           alcstr("cast(object ", 12);
           alcstr(StrLoc(obj_class->name),StrLen(obj_class->name));
           alcstr(sbuf, strlen(sbuf));
           alcstr(StrLoc(cast_class->name),StrLen(cast_class->name));
           alcstr(")", 1);
       }

     methp: {
           struct b_object *obj;
           struct class_field *field;
           dptr field_name;
           struct b_class *field_class, *obj_class;
           struct b_proc *proc;
           bp = BlkLoc(*dp1);
           obj = bp->methp.object;
           obj_class = obj->class;
           sprintf(sbuf, "#%ld(%ld),", (long)obj->id, (long)obj_class->n_instance_fields);
           proc = bp->methp.proc;
           field = proc->field;
           if (field) {
               /*
                * Produce:
                *  "methp(object objectname#m(n),method classname.fieldname)"
                */
               field_name = &field->name;
               field_class = field->defining_class;
               len = StrLen(obj_class->name) + StrLen(field_class->name) + StrLen(*field_name) + strlen(sbuf) + 22;
               MemProtect (StrLoc(*dp2) = reserve(Strings, len));
               StrLen(*dp2) = len;
               /* No need to refresh pointers, everything is static data */
               alcstr("methp(object ", 13);
               alcstr(StrLoc(obj_class->name),StrLen(obj_class->name));
               alcstr(sbuf, strlen(sbuf));
               alcstr("method ", 7);
               alcstr(StrLoc(field_class->name),StrLen(field_class->name));
               alcstr(".", 1);
               alcstr(StrLoc(*field_name),StrLen(*field_name));
               alcstr(")", 1);
           } else {
               char *type;
               /*
                * Produce:
                *  "methp(object objectname#m(n),procedure procname)"
                *  OR
                *  "methp(object objectname#m(n),function procname)"
                */
               if (proc->program)
                   type = "procedure ";
               else
                   type = "function ";
               len = StrLen(obj_class->name) + StrLen(proc->pname) + strlen(sbuf) + strlen(type) + 14;
               MemProtect (StrLoc(*dp2) = reserve(Strings, len));
               StrLen(*dp2) = len;
               /* No need to refresh pointers, everything is static data */
               alcstr("methp(object ", 13);
               alcstr(StrLoc(obj_class->name),StrLen(obj_class->name));
               alcstr(sbuf, strlen(sbuf));
               alcstr(type, strlen(type));
               alcstr(StrLoc(proc->pname),StrLen(proc->pname));
               alcstr(")", 1);
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
           len = 7 + strlen(sbuf) + StrLen(obj_class->name);
           MemProtect (StrLoc(*dp2) = reserve(Strings, len));
           StrLen(*dp2) = len;
           /* No need to refresh pointer, obj_class is static */
           alcstr("object ", 7);
           alcstr(StrLoc(obj_class->name),StrLen(obj_class->name));
           alcstr(sbuf, strlen(sbuf));
       }

      coexpr: {
         /*
          * Produce:
          *  "co-expression#m (n)"
          *  where m is the number of the co-expressions and n is the
          *  number of results that have been produced.
          */

         sprintf(sbuf, "#%ld(%ld)", (long)BlkLoc(source)->coexpr.id,
            (long)BlkLoc(source)->coexpr.size);
         len = strlen(sbuf) + 13;
	 MemProtect (StrLoc(*dp2) = reserve(Strings, len));
         StrLen(*dp2) = len;
         alcstr("co-expression", 13);
         alcstr(sbuf, strlen(sbuf));
         }

      default:
        if (Type(*dp1) == T_External) {
           /*
            * For now, just produce "external(n)". 
            */
           sprintf(sbuf, "external(%ld)", (long)BlkLoc(*dp1)->externl.blksize);
           len = strlen(sbuf);
           MemProtect(StrLoc(*dp2) = alcstr(sbuf, len));
           StrLen(*dp2) = len;
           }
         else {
	    ReturnErrVal(123, source, Error);
            }
      }
   return Succeeded;
   }

/*
 * csname(dp) -- return the name of a predefined cset matching dp.
 */
static char *csname(dp)
dptr dp;
{
    int n = BlkLoc(*dp)->cset.size;
    struct b_cset_range *r = &BlkLoc(*dp)->cset.range[0];
    
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

extern int over_flow;

word add(a, b)
word a, b;
{
   if ((a ^ b) >= 0 && (a >= 0 ? b > MaxLong - a : b < MinLong - a)) {
      over_flow = 1;
      return 0;
      }
   else {
     over_flow = 0;
     return a + b;
     }
}

word sub(a, b)
word a, b;
{
   if ((a ^ b) < 0 && (a >= 0 ? b < a - MaxLong : b > a - MinLong)) {
      over_flow = 1;
      return 0;
      }
   else {
      over_flow = 0;
      return a - b;
      }
}

word mul(a, b)
word a, b;
{
   if (b != 0) {
      if ((a ^ b) >= 0) {
	 if (a >= 0 ? a > MaxLong / b : a < MaxLong / b) {
            over_flow = 1;
	    return 0;
            }
	 }
      else if (b != -1 && (a >= 0 ? a > MinLong / b : a < MinLong / b)) {
         over_flow = 1;
	 return 0;
         }
      }

   over_flow = 0;
   return a * b;
}

/* MinLong / -1 overflows; need div3 too */

word mod3(a, b)
word a, b;
{
   word retval;

   switch ( b )
   {
      case 0:
	 over_flow = 1; /* Not really an overflow, but definitely an error */
	 return 0;

      case MinLong:
	 /* Handle this separately, since -MinLong can overflow */
	 retval = ( a > MinLong ) ? a : 0;
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

word div3(a, b)
word a, b;
{
   if ( ( b == 0 ) ||	/* Not really an overflow, but definitely an error */
        ( b == -1 && a == MinLong ) ) {
      over_flow = 1;
      return 0;
      }

   over_flow = 0;
   return ( a - mod3 ( a, b ) ) / b;
}

/* MinLong / -1 overflows; need div3 too */

word neg(a)
word a;
{
   if (a == MinLong) {
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
void retderef(valp, low, high)
dptr valp;
word *low;
word *high;
   {
   struct b_tvsubs *tvb;
   word *loc;

   if (Type(*valp) == T_Tvsubs) {
      tvb = (struct b_tvsubs *)BlkLoc(*valp);
      /* Check if the tvsubs actually contains a variable - it may contain
       * a ucs descriptor as a result of, eg, return (ucs("abc") ? move(2))
       */
      if (!is:variable(tvb->ssvar))
          return;
      loc = (word *)VarLoc(tvb->ssvar);
   }
   else if (valp->dword & F_Typecode) {
       return;   /* tvtbl, or one of the keyword variable types */
   } else {
       /* Must be D_Var */
       loc = (word *)VarLoc(*valp) + Offset(*valp);
   }

   if (InRange(low, loc, high))
      deref(valp, valp);
}

#if MSWIN32
#ifndef NTGCC
int strcasecmp(char *s1, char *s2)
{
   while (*s1 && *s2) {
      if (tolower(*s1) != tolower(*s2))
         return tolower(*s1) - tolower(*s2);
      s1++; s2++;
      }
   return tolower(*s1) - tolower(*s2);
}

int strncasecmp(char *s1, char *s2, int n)
{
   int i, j;
   for(i=0;i<n;i++) {
      j = tolower(s1[i]) - tolower(s2[i]);
      if (j) return j;
      if (s1[i] == '\0') return 0; /* terminate if both at end-of-string */
      }
   return 0;
}
#endif					/* NTGCC */
#endif					/* MSWIN32 */

/*
 * Create a descriptor for an empty list, with initial number of slots.
 */
void create_list(uword nslots, dptr d) 
{
   struct b_list *hp;
 
   if (nslots == 0)
      nslots = MinListSlots;
   MemProtect(hp = alclist(0, nslots));
 
   d->dword = D_List;
   d->vword.bptr = (union  block *)hp;
}

/*
 * Allocate a string and initialize it based on the given
 * null-terminated C string.  The result is stored in the
 * given dptr.  If s is null, nulldesc is written to d.
 */
void cstr2string(char *s, dptr d) 
{
    char *a;
    int n;

    if (!s) {
        *d = nulldesc;
        return;
    }
    n = strlen(s);
    MemProtect(a = alcstr(s, n));
    MakeStr(a, n, d);
}

/*
 * Allocate a string and initialize it based on the given pointer and
 * length.  The result is stored in the given dptr.  If s is null,
 * nulldesc is written to d.
 */
void bytes2string(char *s, int len, dptr d) 
{
    char *a;

    if (!s) {
        *d = nulldesc;
        return;
    }
    MemProtect(a = alcstr(s, len));
    MakeStr(a, len, d);
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
static int sicmp(const void *sip1, const void *sip2)
{
    return strcmp(((stringint *)sip1)->s, ((stringint *)sip2)->s);
}

/*
 * string-integer lookup function: given a string, return its integer
 */
int stringint_str2int(stringint * sip, char *s)
{
    stringint key;
    stringint * p;
    key.s = s;
    p = (stringint *)bsearch((char *)&key,(char *)(sip+1),sip[0].i,sizeof(key),sicmp);
    if (p) return p->i;
    return -1;
}

/*
 * string-integer inverse function: given an integer, return its string
 */
char *stringint_int2str(stringint * sip, int i)
{
    register stringint * sip2 = sip+1;
    for(;sip2<=sip+sip[0].i;sip2++) if (sip2->i == i) return sip2->s;
    return NULL;
}

stringint *stringint_lookup(stringint *sip, char *s)
{
    stringint key;
    key.s = s;
    return (stringint *)bsearch((char *)&key,(char *)(sip+1),sip[0].i,sizeof(key),sicmp);
}

/*
 * Set &why to an error message based on errno.
 */
void errno2why()
{
    char *msg = 0;
    char buff[32];
    int len;

    #ifdef HAVE_STRERROR
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
    cstr2string(s, &kywd_why);
}

/*
 * Set &why using a printf-style format.
 */
void whyf(char *fmt, ...)
{
    char buff[128];
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
    register char *s1;
    MemProtect(s1 = malloc(strlen(s) + 1));
    return strcpy(s1, s);
}

