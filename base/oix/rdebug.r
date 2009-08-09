/*
 * rdebug.r - tracebk, get_name, xdisp, ctrace, rtrace, failtrace, strace,
 *   atrace, cotrace
 */

#include "../h/modflags.h"

/*
 * Prototypes.
 */
static int  keyref    (union block *bp, dptr dp);
static void showline  (dptr f, int l);
static void showlevel (register int n);
static void ttrace	(void);
static void xtrace(word nargs, dptr arg, int pline, dptr pfile);
static void procname(FILE *f, struct b_proc *p);


#define LIMIT 100

/*
 * tracebk - print a trace of procedure calls.
 */
void tracebk(struct pf_marker *lcl_pfp,  dptr argp)
{
    int depth;
    struct pf_marker *origpfp = pfp;
    dptr arg;

    /*
     * Chain back through the procedure frame markers, looking for the
     *  first one, while building a foward chain of pointers through
     *  the expression frame pointers.
     */
    depth = 0;
    for (pfp->pf_efp = NULL; pfp->pf_pfp != NULL; pfp = pfp->pf_pfp) {
        ++depth;
        (pfp->pf_pfp)->pf_efp = (struct ef_marker *)pfp;
    }

    /* Now start from the base procedure frame marker, producing a listing
     *  of the procedure calls up through the last one.
     */
    if (depth > LIMIT) {
        if (depth == LIMIT + 1)
            --depth;      /* Avoid printing "1 calls omitted" */
        else
            fprintf(stderr, "   ... %d calls omitted\n", depth-LIMIT);
    }

    while (pfp) {
        if (depth <= LIMIT) {
            arg = &((dptr)pfp)[-(pfp->pf_nargs) - 1];
            xtrace(pfp->pf_nargs, &arg[0], findline(pfp->pf_ipc), findfile(pfp->pf_ipc));
            /*
             * On the last call, show both the call and the offending expression.
             */
            if (pfp == origpfp) {
                ttrace();
                break;
            }
        }
        --depth;
        pfp = (struct pf_marker *)(pfp->pf_efp);
    }
}

/*
 * xtrace - procedure *bp is being called with nargs arguments, the first
 *  of which is at arg; produce a trace message.
 */
static void xtrace(nargs, arg, pline, pfile)
    word nargs;
    dptr arg;
    int pline;
    dptr pfile;
{
    fprintf(stderr, "   ");
    if (BlkLoc(*arg) == NULL)
        fprintf(stderr, "????");
    else {
        if (is:proc(*arg))
            procname(stderr, (struct b_proc *)BlkLoc(*arg));
        else
            outimage(stderr, arg, 0);
        arg++;
        putc('(', stderr);
        while (nargs--) {
            outimage(stderr, arg++, 0);
            if (nargs)
                putc(',', stderr);
        }
        putc(')', stderr);
    }
	 
    if (pline != 0) {
        if (pfile) {
            struct descrip t;
            abbr_fname(pfile, &t);
            fprintf(stderr, " from line %d in %.*s", pline, (int)StrLen(t), StrLoc(t));
        } else
            fprintf(stderr, " from line %d in ?", pline);
    }
    putc('\n', stderr);
    fflush(stderr);
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

static struct class_field *find_class_field_for_dptr(dptr d, struct progstate *prog)
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

static struct progstate *find_global(dptr s)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->Globals, s, p->Eglobals)) {
            return p;
        }
    }
    return 0;
}

static struct progstate *find_class_static(dptr s)
{
    struct progstate *p;
    for (p = progs; p; p = p->next) {
        if (InRange(p->ClassStatics, s, p->EClassStatics)) {
            return p;
        }
    }
    return 0;
}

/*
 * get_name -- function to get print name of variable.
 */
int get_name(dptr dp1, dptr dp0)
{
    dptr dp, varptr;
    tended union block *blkptr;
    dptr arg1;                           /* 1st parameter */
    dptr loc1;                           /* 1st local */
    struct b_proc *proc0;                 /* address of procedure block */
    char sbuf[100];			/* buffer; might be too small */
    char *s, *s2;
    word i, j, k;
    int t;
    struct progstate *prog;

    arg1 = &argp[1];
    loc1 = pfp->pf_locals;
    proc0 = CallerProc;

    type_case *dp1 of {
      tvsubs: {
            blkptr = BlkLoc(*dp1);
            get_name(&(blkptr->tvsubs.ssvar),dp0);
            sprintf(sbuf,"[%ld:%ld]",(long)blkptr->tvsubs.sspos,
                    (long)blkptr->tvsubs.sspos+blkptr->tvsubs.sslen);
            k = StrLen(*dp0);
            j = strlen(sbuf);

            /*
             * allocate space for both the name and the subscript image,
             *  and then copy both parts into the allocated space
             */
            MemProtect(s = alcstr(NULL, k + j));
            s2 = StrLoc(*dp0);
            StrLoc(*dp0) = s;
            StrLen(*dp0) = j + k;
            for (i = 0; i < k; i++)
                *s++ = *s2++;
            s2 = sbuf;
            for (i = 0; i < j; i++)
                *s++ = *s2++;
        }

      tvtbl: {
            t = keyref(BlkLoc(*dp1) ,dp0);
            if (t == Error)
                return Error;
        }

      kywdint:
        if (VarLoc(*dp1) == &kywd_ran) {
            LitStr("&random", dp0);
        }
        else if (VarLoc(*dp1) == &kywd_trc) {
            LitStr("&trace", dp0);
        }
        else if (VarLoc(*dp1) == &kywd_dmp) {
            LitStr("&dump", dp0);
        }
        else if (VarLoc(*dp1) == &kywd_err) {
            LitStr("&error", dp0);
        }
        else
            syserr("name: unknown integer keyword variable");
            
      kywdany:
        if (VarLoc(*dp1) == &curpstate->eventsource) {
            LitStr("&eventsource", dp0);
        }
        else if (VarLoc(*dp1) == &curpstate->eventval) {
            LitStr("&eventvalue", dp0);
        }
        else if (VarLoc(*dp1) == &curpstate->eventcode) {
            LitStr("&eventcode", dp0);
        }
        else
            syserr("name: unknown event keyword variable");
            
      kywdstr: {
          if (VarLoc(*dp1) == &kywd_prog) {
              LitStr("&progname", dp0);
          } else if (VarLoc(*dp1) == &kywd_why) {
              LitStr("&why", dp0);
          }
        }
      kywdpos: {
            LitStr("&pos", dp0);
        }

      kywdsubj: {
            LitStr("&subject", dp0);
        }

        default:
            if (DVar(*dp1)) {
                /*
                 * Must(?) be a named variable.
                 * (When used internally, could be reference to nameless
                 * temporary stack variables as occurs for string scanning).
                 */
                dp = VarLoc(*dp1);		 /* get address of variable */
                if ((prog = find_global(dp))) {
                    *dp0 = prog->Gnames[dp - prog->Globals]; 		/* global */
                    return GlobalName;
                }
                else if ((prog = find_class_static(dp))) {
                    /*
                     * Class static field
                     */
                    struct class_field *cf = find_class_field_for_dptr(dp, prog);
                    struct b_class *c = cf->defining_class;
                    dptr fname = &c->program->Fnames[cf->fnum];
                    sprintf(sbuf,"class %.*s.%.*s", (int)StrLen(c->name), StrLoc(c->name), 
                            (int)StrLen(*fname), StrLoc(*fname));
                    i = strlen(sbuf);
                    MemProtect(StrLoc(*dp0) = alcstr(sbuf,i));
                    StrLen(*dp0) = i;
                    return FieldName;
                }
                else if (InRange(proc0->program->Statics, dp, proc0->program->Estatics)) {
                    i = dp - proc0->fstatic;	/* static */
                    if (i < 0 || i >= proc0->nstatic)
                        syserr("name: unreferencable static variable");
                    i += abs((int)proc0->nparam) + (int)proc0->ndynam;
                    *dp0 = proc0->lnames[i];
                    return StaticName;
                }
                else if (InRange(arg1, dp, &arg1[abs((int)proc0->nparam)])) {
                    *dp0 = proc0->lnames[dp - arg1];          /* argument */
                    return ParamName;
                }
                else if (InRange(loc1, dp, &loc1[proc0->ndynam])) {
                    *dp0 = proc0->lnames[dp - loc1 + abs((int)proc0->nparam)];
                    return LocalName;
                }
                else {
                    LitStr("(temp)", dp0);
                    return Failed;
                }
            }
            else if (DOffsetVar(*dp1)) {
                /*
                 * Must be an element of a structure.
                 */
                blkptr = (union block *)BlkLoc(*dp1);
                varptr = OffsetVarLoc(*dp1);
                switch ((int)BlkType(blkptr)) {
                    case T_Lelem: 		/* list */
                        i = varptr - &blkptr->lelem.lslots[blkptr->lelem.first] + 1;
                        if (i < 1)
                            i += blkptr->lelem.nslots;
                        while (BlkType(blkptr->lelem.listprev) == T_Lelem) {
                            blkptr = blkptr->lelem.listprev;
                            i += blkptr->lelem.nused;
                        }
                        sprintf(sbuf,"list#%ld[%ld]",
                                (long)blkptr->lelem.listprev->list.id, (long)i);
                        i = strlen(sbuf);
                        MemProtect(StrLoc(*dp0) = alcstr(sbuf,i));
                        StrLen(*dp0) = i;
                        break;
                    case T_Record: { 		/* record */
                        struct b_constructor *c = blkptr->record.constructor;
                        dptr fn = c->program->Fnames;
                        i = varptr - blkptr->record.fields;
                        sprintf(sbuf,"record %.*s#%ld.%.*s", (int)StrLen(c->name), StrLoc(c->name),
                                (long)blkptr->record.id,
                                (int)StrLen(fn[c->fnums[i]]), StrLoc(fn[c->fnums[i]]));
                        i = strlen(sbuf);
                        MemProtect(StrLoc(*dp0) = alcstr(sbuf,i));
                        StrLen(*dp0) = i;
                        break;
                    }
                    case T_Object: { 		/* object */
                        struct b_class *c = blkptr->object.class;
                        dptr fname;
                        i = varptr - blkptr->object.fields;
                        fname =  &c->program->Fnames[c->fields[i]->fnum];
                        sprintf(sbuf,"object %.*s#%ld.%.*s", (int)StrLen(c->name), StrLoc(c->name),
                                (long)blkptr->object.id,
                                (int)StrLen(*fname), StrLoc(*fname));
                        i = strlen(sbuf);
                        MemProtect(StrLoc(*dp0) = alcstr(sbuf,i));
                        StrLen(*dp0) = i;
                        break;
                    }
                    case T_Telem: 		/* table */
                        t = keyref(blkptr,dp0);
                        if (t == Error)
                            return Error;
                        break;
                    default:		/* none of the above */
                        LitStr("(struct)", dp0);
                        return Failed;

                }
            } else {
                LitStr("(non-variable)", dp0);
                return Failed;
            }
    }
    return Succeeded;
}


/*
 * keyref(bp,dp) -- print name of subscripted table
 */
static int keyref(bp, dp)
    union block *bp;
    dptr dp;
{
    char *s, *s2;
    char sbuf[256];			/* buffer; might be too small */
    int len;

    if (getimage(&(bp->telem.tref),dp) == Error)
        return Error;	

    /*
     * Allocate space, and copy the image surrounded by "table_n[" and "]"
     */
    s2 = StrLoc(*dp);
    len = StrLen(*dp);
    if (BlkType(bp) == T_Tvtbl)
        bp = bp->tvtbl.clink;
    else
        while(BlkType(bp) == T_Telem)
            bp = bp->telem.clink;
    sprintf(sbuf, "table#%ld[", (long)bp->table.id);
    { char * dest = sbuf + strlen(sbuf);
        strncpy(dest, s2, len);
        dest[len] = '\0';
    }
    strcat(sbuf, "]");
    len = strlen(sbuf);
    MemProtect(s = alcstr(sbuf, len));
    StrLoc(*dp) = s;
    StrLen(*dp) = len;
    return Succeeded;
}

/*
 * cotrace -- a co-expression context switch; produce a trace message.
 */
void cotrace(ccp, ncp, swtch_typ, valloc)
    struct b_coexpr *ccp;
    struct b_coexpr *ncp;
    int swtch_typ;
    dptr valloc;
{
    --k_trace;

    /*
     * Compute the ipc of the instruction causing the context switch.
     */
    showline(findfile(ipc), findline(ipc));
    /* argp can be 0 when we come back from a loaded program. */
    if (argp) {
        showlevel(k_level);
        procname(stderr, (struct b_proc *)BlkLoc(*argp));
    } else {
        showlevel(k_level);
        fprintf(stderr, "?");
    }

    fprintf(stderr,"; co-expression#%ld ", (long)ccp->id);
    switch (swtch_typ) {
        case A_Coact:
            fprintf(stderr,": ");
            outimage(stderr, valloc, 0);
            fprintf(stderr," @ ");
            break;
        case A_Coret:
            fprintf(stderr,"returned ");
            outimage(stderr, valloc, 0);
            fprintf(stderr," to ");
            break;
        case A_Cofail:
            fprintf(stderr,"failed to ");
            break;
    }
    fprintf(stderr,"co-expression#%ld\n", (long)ncp->id);
    fflush(stderr);
}

/*
 * showline - print file and line number information.
 */
static void showline(dptr f, int l)
{
    if (l > 0) {
        if (f) {
            struct descrip t;
            char *p;
            int i;
            abbr_fname(f, &t);
            i = StrLen(t);
            p = StrLoc(t);
            while (i > 13) {
                p++;
                i--;
            }

            fprintf(stderr, "%-13.*s: %4d  ",i,p, l);
        } else {
            fprintf(stderr, "%-13s: %4d  ","?", l);
        }

    } else
        fprintf(stderr, "             :       ");
    
}
    
/*
 * showlevel - print "| " n times.
 */
static void showlevel(n)
    register int n;
{
    while (n-- > 0) {
        putc('|', stderr);
        putc(' ', stderr);
    }
}


#include "../h/opdefs.h"


    extern struct b_proc *opblks[];

    
/*
 * ttrace - show offending expression.
 */
static void ttrace()
{
    word nargs;

    fprintf(stderr, "   ");

    switch ((int)lastop) {

        case Op_Keywd:
            fprintf(stderr,"bad keyword reference");
            break;

        case Op_Invokef:
            nargs = xnargs;
            outimage(stderr, xargp, 0);
            fprintf(stderr, " . ");
            if (xfno < 0 && fnames-efnames < xfno)
                putstr(stderr, &efnames[xfno]);
            else if (0 <= xfno && xfno < efnames - fnames)
                putstr(stderr, &fnames[xfno]);
            else
                fprintf(stderr, "field");
            putc('(', stderr);
            while (nargs--) {
                outimage(stderr, ++xargp, 0);
                if (nargs)
                    putc(',', stderr);
            }
            putc(')', stderr);
            break;

        case Op_Applyf:
            outimage(stderr, xargp++, 0);
            fprintf(stderr, " . ");
            if (xfno < 0 && fnames-efnames < xfno)
                putstr(stderr, &efnames[xfno]);
            else if (0 <= xfno && xfno < efnames - fnames)
                putstr(stderr, &fnames[xfno]);
            else
                fprintf(stderr, "field");
            fprintf(stderr," ! ");
            outimage(stderr, xargp, 0);
            break;

        case Op_Invoke:
            nargs = xnargs;
            if (is:proc(*xargp))   /* Will happen if a builtin proc calls runnerr */
                procname(stderr, (struct b_proc *)BlkLoc(*xargp));
            else
                outimage(stderr, xargp, 0);
            putc('(', stderr);
            while (nargs--) {
                outimage(stderr, ++xargp, 0);
                if (nargs)
                    putc(',', stderr);
            }
            putc(')', stderr);
            break;

        case Op_Toby:
            putc('{', stderr);
            outimage(stderr, ++xargp, 0);
            fprintf(stderr, " to ");
            outimage(stderr, ++xargp, 0);
            fprintf(stderr, " by ");
            outimage(stderr, ++xargp, 0);
            putc('}', stderr);
            break;

        case Op_Subsc:
            putc('{', stderr);
            outimage(stderr, ++xargp, 0);
            putc('[', stderr);
            outimage(stderr, ++xargp, 0);
            putc(']', stderr);

            putc('}', stderr);
            break;

        case Op_Sect:
            putc('{', stderr);
            outimage(stderr, ++xargp, 0);

            putc('[', stderr);

            outimage(stderr, ++xargp, 0);
            putc(':', stderr);
            outimage(stderr, ++xargp, 0);

            putc(']', stderr);

            putc('}', stderr);
            break;

        case Op_Bscan:
            putc('{', stderr);
            outimage(stderr, xargp, 0);
            fputs(" ? ..}", stderr);
            break;

        case Op_Coact:
            putc('{', stderr);
            outimage(stderr, ++xargp, 0);
            fprintf(stderr, " @ ");
            outimage(stderr, ++xargp, 0);
            putc('}', stderr);
            break;

        case Op_Apply:
            outimage(stderr, xargp, 0);
            fprintf(stderr," ! ");
            outimage(stderr, ++xargp, 0);
            break;

        case Op_Create:
            fprintf(stderr,"{create ..}");
            break;

        case Op_Field:
            putc('{', stderr);
            outimage(stderr, ++xargp, 0);
            fprintf(stderr, " . ");
            ++xargp;
            if (IntVal(*xargp) < 0 && fnames-efnames < IntVal(*xargp))
                putstr(stderr, &efnames[IntVal(*xargp)]);
            else if (0 <= IntVal(*xargp) && IntVal(*xargp) < efnames - fnames)
                putstr(stderr, &fnames[IntVal(*xargp)]);
            else
                fprintf(stderr, "field");

            putc('}', stderr);
            break;

        case Op_Limit:
            fprintf(stderr, "limit counter: ");
            outimage(stderr, xargp, 0);
            break;

        case Op_Llist:

            fprintf(stderr,"[ ... ]");
            break;

   
        default: {
            struct b_proc *bp;
            /* 
             * opblks are only defined for the operator instructions, the last of
             * which is Op_Value (see opdefs.h and odefs.h) 
             */
            if (lastop > Op_Value)
                break;
            bp = opblks[lastop];
            nargs = abs((int)bp->nparam);
            putc('{', stderr);
            if (lastop == Op_Bang || lastop == Op_Random)
                goto oneop;
            if (abs((int)bp->nparam) >= 2) {
                outimage(stderr, ++xargp, 0);
                putc(' ', stderr);
                putstr(stderr, &(bp->name));
                putc(' ', stderr);
            }
            else
              oneop:
                putstr(stderr, &(bp->name));
            outimage(stderr, ++xargp, 0);
            putc('}', stderr);
        }
    }
	 
    if (ipc != NULL) {
        dptr fn = findfile(ipc);
        if (fn) {
            struct descrip t;
            abbr_fname(fn, &t);
            fprintf(stderr, " from line %d in %.*s", findline(ipc), (int)StrLen(t), StrLoc(t));
        } else
            fprintf(stderr, " from line %d in ?", findline(ipc));
    }

    putc('\n', stderr);

    fflush(stderr);
}


/*
 * ctrace - procedure p is being called with nargs arguments, the first
 *  of which is at arg; produce a trace message.
 */
void ctrace(struct b_proc *p, int nargs, dptr arg)
{
    showline(findfile(ipc), findline(ipc));
    showlevel(k_level);

    procname(stderr, p);
    putc('(', stderr);
    while (nargs--) {
        outimage(stderr, arg++, 0);
        if (nargs)
            putc(',', stderr);
    }
    putc(')', stderr);
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * rtrace - procedure p is returning *rval; produce a trace message.
 */

void rtrace(struct b_proc *p, dptr rval)
{
    showline(findfile(ipc), findline(ipc));
    showlevel(k_level);
    procname(stderr, p);
    fprintf(stderr, " returned ");
    outimage(stderr, rval, 0);
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * failtrace - procedure p is failing; produce a trace message.
 */

void failtrace(struct b_proc *p)
{
    showline(findfile(ipc), findline(ipc));
    showlevel(k_level);
    procname(stderr, p);
    fprintf(stderr, " failed");
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * strace - procedure p is suspending *rval; produce a trace message.
 */

void strace(struct b_proc *p, dptr rval)
{
    showline(findfile(ipc), findline(ipc));
    showlevel(k_level);
    procname(stderr, p);
    fprintf(stderr, " suspended ");
    outimage(stderr, rval, 0);
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * atrace - procedure p is being resumed; produce a trace message.
 */

void atrace(struct b_proc *p)
{
    showline(findfile(ipc), findline(ipc));
    showlevel(k_level);
    procname(stderr, p);
    fprintf(stderr, " resumed");
    putc('\n', stderr);
    fflush(stderr);
}


/*
 * Service routine to display variables in given number of
 *  procedure calls to file f.
 */

void xdisp(struct pf_marker *fp,
          dptr dp,
          int count,
          FILE *f,
          struct progstate *p)
{
    register dptr np;
    register int n;
    struct b_proc *bp;
    word nglobals;

    while (count--) {		/* go back through 'count' frames */
        if (fp == NULL)
            break;       /* needed because &level is wrong in co-expressions */

        bp = (struct b_proc *)BlkLoc(*dp++); /* get addr of procedure block */
        /* #%#% was: no post-increment there, but *pre*increment dp below */

        /*
         * Print procedure name.
         */
        procname(f, bp);
        fprintf(f, " local identifiers:\n");

        /*
         * Print arguments.
         */
        np = bp->lnames;
        for (n = abs((int)bp->nparam); n > 0; n--) {
            fprintf(f, "   ");
            putstr(f, np);
            fprintf(f, " = ");
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        /*
         * Print locals.
         */
        dp = &fp->pf_locals[0];
        for (n = bp->ndynam; n > 0; n--) {
            fprintf(f, "   ");
            putstr(f, np);
            fprintf(f, " = ");
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        /*
         * Print statics.
         */
        dp = bp->fstatic;
        for (n = bp->nstatic; n > 0; n--) {
            fprintf(f, "   ");
            putstr(f, np);
            fprintf(f, " = ");
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        dp = fp->pf_argp;
        fp = fp->pf_pfp;
    }

    /*
     * Print globals.
     */

    nglobals = p->Eglobals - p->Globals;

    fprintf(f, "\nglobal identifiers:\n");
    for (n = 0; n < nglobals; n++) {
        fprintf(f, "   ");
        putstr(f, &p->Gnames[n]);
        fprintf(f, " = ");
        outimage(f, &p->Globals[n], 0);
        putc('\n', f);
    }
    fflush(f);
}

static void procname(FILE *f, struct b_proc *p)
{
    if (p->field) {
        putstr(f, &p->field->defining_class->name);
        putc('.', f);
        putstr(f, &p->field->defining_class->program->Fnames[p->field->fnum]);
    } else
        putstr(f, &p->name);
}
