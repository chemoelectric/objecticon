/*
 * rdebug.r - tracebk, get_name, xdisp, ctrace, rtrace, failtrace, strace,
 *   atrace, cotrace
 */

#include "../h/modflags.h"
#include "../h/opdefs.h"

/*
 * Prototypes.
 */
static void keyref    (union block *bp, dptr dp);
static void showline(struct p_frame *pf);
static void showlevel (register int n);
static void ttrace	(void);
static void procname(FILE *f, struct b_proc *p);

static void trace_frame(struct p_frame *pf);

#define LIMIT 100

/*
 * These are set at various strategic points to help give better error
 * messages.
 */
dptr xexpr;
dptr xfield;
dptr xargp;
int xnargs;

struct ipc_line *frame_ipc_line(struct p_frame *pf)
{
    synch_ipc();
    while (pf && !pf->proc->program)
        pf = pf->caller;
    if (!pf)
        return 0;
    return find_ipc_line(pf->curr_inst, pf->proc->program);
}

struct ipc_fname *frame_ipc_fname(struct p_frame *pf)
{
    synch_ipc();
    while (pf && !pf->proc->program)
        pf = pf->caller;
    if (!pf)
        return 0;
    return find_ipc_fname(pf->curr_inst, pf->proc->program);
}

struct frame_chain {
   struct p_frame *frame;
   struct frame_chain *next;
};

struct act_chain {
   struct b_coexpr *coex;
   struct frame_chain *frames;
   int nframes;
   struct act_chain *next;
};

static int in_act_chain(struct act_chain *head, struct b_coexpr *ce)
{
    while (head) {
        if (head->coex == ce)
            return 1;
        head = head->next;
    }
    return 0;
}

void traceback(struct b_coexpr *ce, int with_ttrace)
{
    struct act_chain *head = 0, *ae;
    struct frame_chain *fe;
    int depth = 0;
    struct b_coexpr *ce1 = ce;

    fprintf(stderr, "Traceback:\n");
    while (ce1 && !in_act_chain(head, ce1)) {
        struct p_frame *pf;
        MemProtect(ae = malloc(sizeof(struct act_chain)));
        ae->coex = ce1;
        ae->frames = 0;
        ae->next = head;
        ae->nframes = 0;
        head = ae;
        for (pf = ce1->curr_pf; pf; pf = pf->caller) {
            if (pf->proc->program) {
                MemProtect(fe = malloc(sizeof(struct frame_chain)));
                fe->frame = pf;
                fe->next = ae->frames;
                ae->frames = fe;
                ++ae->nframes;
                ++depth;
            }
        }
        ce1 = ce1->activator;
    }

    if (depth == 0) {
        fflush(stderr);
        return;
    }

    for (ae = head; ae;) {
        struct act_chain *t;
        if (depth - LIMIT < ae->nframes) {
            /* Will print some of this coexpression's calls, so print header */
            if (ae->coex->activator)
                fprintf(stderr,"co-expression#%ld activated by co-expression#%ld\n", 
                        (long)ae->coex->id, (long)ae->coex->activator->id);
            else
                fprintf(stderr,"co-expression#%ld (never activated)\n", (long)ae->coex->id);

            if (depth > LIMIT) {
                if (depth == LIMIT + 1)
                    depth = LIMIT;  /* Avoid printing "1 call omitted" */
                else
                    fprintf(stderr, "   ... %d calls omitted\n", depth - LIMIT);
            }
        }
        for (fe = ae->frames; fe;) {
            struct frame_chain *t;
            if (depth <= LIMIT)
                trace_frame(fe->frame);
            depth--;
            t = fe->next;
            free(fe);
            fe = t;
        }

        t = ae->next;
        free(ae);
        ae = t;
    }

    if (with_ttrace)
        ttrace();
    else if (ce->activator) {
        struct ipc_line *pline;
        struct ipc_fname *pfile;
        pline = frame_ipc_line(ce->curr_pf);
        pfile = frame_ipc_fname(ce->curr_pf);
        if (pfile && pline) {
            struct descrip t;
            abbr_fname(pfile->fname, &t);
            fprintf(stderr, "   at line %d in %.*s", (int)pline->line, (int)StrLen(t), StrLoc(t));
        } else
            fprintf(stderr, "   at ?");
        putc('\n', stderr);
    }

    fflush(stderr);
}

static void trace_frame(struct p_frame *pf)
{
    dptr arg;
    word nargs = pf->proc->nparam;
    struct ipc_line *pline;
    struct ipc_fname *pfile;

    arg = pf->fvars->desc;
    fprintf(stderr, "   ");
    procname(stderr, pf->proc);
    putc('(', stderr);
    while (nargs--) {
        outimage(stderr, arg++, 0);
        if (nargs)
            putc(',', stderr);
    }
    putc(')', stderr);
    
    pline = frame_ipc_line(pf->caller);
    pfile = frame_ipc_fname(pf->caller);
    if (pline && pfile) {
        struct descrip t;
        abbr_fname(pfile->fname, &t);
        fprintf(stderr, " from line %d in %.*s", (int)pline->line, (int)StrLen(t), StrLoc(t));
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
    struct progstate *prog;
    struct p_frame *uf;

    uf = get_current_user_frame();
    arg1 = uf->fvars->desc;
    proc0 = uf->proc;
    /* The locals follow the args in the locals block */
    loc1 = uf->fvars->desc + proc0->nparam;

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
            keyref(BlkLoc(*dp1) ,dp0);
        }

      kywdint: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_ran) {
                  LitStr("&random", dp0);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_trace) {
                  LitStr("&trace", dp0);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_dump) {
                  LitStr("&dump", dp0);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_err) {
                  LitStr("&error", dp0);
                  break;
              }
              else if (VarLoc(*dp1) == &prog->Kywd_maxlevel) {
                  LitStr("&maxlevel", dp0);
                  break;
              }
          }
          if (!prog)
            syserr("name: unknown integer keyword variable");
        }            
      kywdany:
            syserr("name: unknown keyword variable");
            
      kywdstr: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_prog) {
                  LitStr("&progname", dp0);
                  break;
              } else if (VarLoc(*dp1) == &prog->Kywd_why) {
                  LitStr("&why", dp0);
                  break;
              }
          }
          if (!prog)
              syserr("name: unknown string keyword variable");
        }
      kywdpos: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_pos) {
                  LitStr("&pos", dp0);
                  break;
              }
          }
          if (!prog)
              syserr("name: unknown pos keyword variable");
      }

      kywdsubj: {
          for (prog = progs; prog; prog = prog->next) {
              if (VarLoc(*dp1) == &prog->Kywd_subject) {
                  LitStr("&subject", dp0);
                  break;
              }
          }
          if (!prog)
              syserr("name: unknown subject keyword variable");
        }

      named_var: {
            /*
             * Must(?) be a named variable.
             * (When used internally, could be reference to nameless
             * temporary stack variables as occurs for string scanning).
             */
            dp = VarLoc(*dp1);		 /* get address of variable */
            if ((prog = find_global(dp))) {
                *dp0 = *prog->Gnames[dp - prog->Globals]; 		/* global */
                return GlobalName;
            }
            else if ((prog = find_class_static(dp))) {
                /*
                 * Class static field
                 */
                struct class_field *cf = find_class_field_for_dptr(dp, prog);
                struct b_class *c = cf->defining_class;
                dptr fname = c->program->Fnames[cf->fnum];
                int len = 6 + StrLen(*c->name) + 1 + StrLen(*fname);
                MemProtect(StrLoc(*dp0) = reserve(Strings, len));
                StrLen(*dp0) = len;
                alcstr("class ", 6);
                alcstr(StrLoc(*c->name), StrLen(*c->name));
                alcstr(".", 1);
                alcstr(StrLoc(*fname), StrLen(*fname));
                return FieldName;
            }
            else if (InRange(proc0->program->Statics, dp, proc0->program->Estatics)) {
                i = dp - proc0->fstatic;	/* static */
                if (i < 0 || i >= proc0->nstatic)
                    syserr("name: unreferencable static variable");
                i += proc0->nparam + proc0->ndynam;
                *dp0 = *proc0->lnames[i];
                return StaticName;
            }
            else if (InRange(arg1, dp, &arg1[proc0->nparam])) {
                *dp0 = *proc0->lnames[dp - arg1];          /* argument */
                return ParamName;
            }
            else if (InRange(loc1, dp, &loc1[proc0->ndynam])) {
                *dp0 = *proc0->lnames[dp - loc1 + proc0->nparam];
                return LocalName;
            }
            else {
                LitStr("(temp)", dp0);
                return Failed;
            }
        }

      struct_var: {
            /*
             * Must be an element of a structure.
             */
            blkptr = BlkLoc(*dp1);
            varptr = OffsetVarLoc(*dp1);
            switch (BlkType(blkptr)) {
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
                    dptr fname;
                    int len;
                    i = varptr - blkptr->record.fields;
                    fname = c->program->Fnames[c->fnums[i]];
                    sprintf(sbuf,"#%ld", (long)blkptr->record.id);
                    len = 7 + StrLen(*c->name) + strlen(sbuf) + 1 + StrLen(*fname);
                    MemProtect(StrLoc(*dp0) = reserve(Strings, len));
                    StrLen(*dp0) = len;
                    alcstr("record ", 7);
                    alcstr(StrLoc(*c->name), StrLen(*c->name));
                    alcstr(sbuf, strlen(sbuf));
                    alcstr(".", 1);
                    alcstr(StrLoc(*fname), StrLen(*fname));
                    break;
                }
                case T_Object: { 		/* object */
                    struct b_class *c = blkptr->object.class;
                    dptr fname;
                    int len;
                    i = varptr - blkptr->object.fields;
                    fname =  c->program->Fnames[c->fields[i]->fnum];
                    sprintf(sbuf,"#%ld", (long)blkptr->object.id);
                    len = 7 + StrLen(*c->name) + strlen(sbuf) + 1 + StrLen(*fname);
                    MemProtect(StrLoc(*dp0) = reserve(Strings, len));
                    StrLen(*dp0) = len;
                    alcstr("object ", 7);
                    alcstr(StrLoc(*c->name), StrLen(*c->name));
                    alcstr(sbuf, strlen(sbuf));
                    alcstr(".", 1);
                    alcstr(StrLoc(*fname), StrLen(*fname));
                    break;
                }
                case T_Telem: 		/* table */
                    keyref(blkptr,dp0);
                    break;
                default:		/* none of the above */
                    LitStr("(struct)", dp0);
                    return Failed;
            }
        }

        default: {
            LitStr("(non-variable)", dp0);
            return Failed;
        }
    }
    return Succeeded;
}


/*
 * keyref(bp,dp) -- print name of subscripted table
 */
static void keyref(bp, dp)
    union block *bp;
    dptr dp;
{
    tended struct descrip td;
    char sbuf[64];
    int len;

    getimage(&(bp->telem.tref), &td);

    if (BlkType(bp) == T_Tvtbl)
        bp = bp->tvtbl.clink;
    else
        while(BlkType(bp) == T_Telem)
            bp = bp->telem.clink;
    sprintf(sbuf, "table#%ld[", (long)bp->table.id);
    len = strlen(sbuf) + StrLen(td) + 1;
    MemProtect (StrLoc(*dp) = reserve(Strings, len));
    StrLen(*dp) = len;
    alcstr(sbuf, strlen(sbuf));
    alcstr(StrLoc(td), StrLen(td));
    alcstr("]", 1);
}

static void cotrace_line(struct b_coexpr *from)
{
    struct p_frame *pf = get_current_user_frame_of(from);
    showline(pf);
    showlevel(k_level);
    procname(stderr, pf->proc);
}

void trace_coact(struct b_coexpr *from, struct b_coexpr *to, dptr val)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#%ld : ", (long)from->id);
    outimage(stderr, val, 0);
    fprintf(stderr, " @ co-expression#%ld\n", (long)to->id);
    fflush(stderr);
}

void trace_coret(struct b_coexpr *from, struct b_coexpr *to, dptr val)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#%ld returned ", (long)from->id);
    outimage(stderr, val, 0);
    fprintf(stderr, " to co-expression#%ld\n", (long)to->id);
    fflush(stderr);
}

void trace_cofail(struct b_coexpr *from, struct b_coexpr *to)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#%ld failed to co-expression#%ld\n", (long)from->id, (long)to->id);
    fflush(stderr);
}

/*
 * showline - print file and line number information.
 */
static void showline(struct p_frame *pf)
{
    struct ipc_line *pline;
    struct ipc_fname *pfile;

    pline = frame_ipc_line(pf);
    pfile = frame_ipc_fname(pf);

    if (pline) {
        if (pfile) {
            struct descrip t;
            char *p;
            int i;
            abbr_fname(pfile->fname, &t);
            i = StrLen(t);
            p = StrLoc(t);
            while (i > 13) {
                p++;
                i--;
            }

            fprintf(stderr, "%-13.*s: %4d  ",i,p, (int)pline->line);
        } else {
            fprintf(stderr, "%-13s: %4d  ","?", (int)pline->line);
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

static void outfield()
{
    if (IntVal(*xfield) < 0 && fnames-efnames < IntVal(*xfield))
        putstr(stderr, efnames[IntVal(*xfield)]);
    else if (0 <= IntVal(*xfield) && IntVal(*xfield) < efnames - fnames)
        putstr(stderr, fnames[IntVal(*xfield)]);
    else
        fprintf(stderr, "field");
}

/*
 * Is a given b_proc an operator or not?
 */
static int is_op(struct b_proc *bp)
{
    int i;
    for (i = 0; i < op_tbl_sz; ++i) {
        if (op_tbl[i] == bp)
            return 1;
    }
    return 0;
}

/*
 * ttrace - show offending expression.
 */
static void ttrace()
{
    struct ipc_line *pline;
    struct ipc_fname *pfile;

    if (curr_op == 0)
        return;

    fprintf(stderr, "   ");

    switch ((int)curr_op) {

        case Op_Keywd:
            fprintf(stderr,"bad keyword reference");
            break;

        case Op_Invokef:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                procname(stderr, curr_cf->proc);
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                putc('(', stderr);
                while (xnargs--) {
                    outimage(stderr, xargp++, 0);
                    if (xnargs)
                        putc(',', stderr);
                }
                putc(')', stderr);
            } else if (xexpr) {
                /* Error to do with the type of expr */
                outimage(stderr, xexpr, 0);
                fprintf(stderr, " . ");
                outfield();
                fprintf(stderr," ( .. )");
            }
            break;

        case Op_Applyf:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                procname(stderr, curr_cf->proc);
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                fprintf(stderr," ! [ ");
                while (xnargs--) {
                    outimage(stderr, xargp++, 0);
                    if (xnargs)
                        putc(',', stderr);
                }
                fprintf(stderr," ]");
            } else if (xexpr) {
                /* Error to do with the type of expr */
                outimage(stderr, xexpr, 0);
                fprintf(stderr, " . ");
                outfield();
                fprintf(stderr, " ! ");
                if (xargp)
                    outimage(stderr, xargp, 0);
                else
                    fprintf(stderr, " [ .. ]");
            }
            break;

        case Op_Apply:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                procname(stderr, curr_cf->proc);
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                fprintf(stderr," ! [ ");
                while (xnargs--) {
                    outimage(stderr, xargp++, 0);
                    if (xnargs)
                        putc(',', stderr);
                }
                fprintf(stderr," ]");
            } else if (xexpr) {
                /* Error to do with the type of expr */
                outimage(stderr, xexpr, 0);
                fprintf(stderr, " ! ");
                if (xargp)
                    outimage(stderr, xargp, 0);
                else
                    fprintf(stderr, " [ .. ]");
            }
            break;

        case Op_Invoke:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                procname(stderr, curr_cf->proc);
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                putc('(', stderr);
                while (xnargs--) {
                    outimage(stderr, xargp++, 0);
                    if (xnargs)
                        putc(',', stderr);
                }
                putc(')', stderr);
            } else if (xexpr) {
                /* Error to do with the type of expr */
                outimage(stderr, xexpr, 0);
                fprintf(stderr," ( .. )");
            }
            break;

        case Op_Toby:
            xargp = curr_cf->args;
            putc('{', stderr);
            outimage(stderr, xargp++, 0);
            fprintf(stderr, " to ");
            outimage(stderr, xargp++, 0);
            fprintf(stderr, " by ");
            outimage(stderr, xargp, 0);
            putc('}', stderr);
            break;

        case Op_Subsc:
            xargp = curr_cf->args;
            putc('{', stderr);
            outimage(stderr, xargp++, 0);
            putc('[', stderr);
            outimage(stderr, xargp, 0);
            putc(']', stderr);

            putc('}', stderr);
            break;

        case Op_Sect:
            xargp = curr_cf->args;
            putc('{', stderr);
            outimage(stderr, xargp++, 0);

            putc('[', stderr);

            outimage(stderr, xargp++, 0);
            putc(':', stderr);
            outimage(stderr, xargp, 0);

            putc(']', stderr);

            putc('}', stderr);
            break;

        case Op_ScanSave:
            putc('{', stderr);
            outimage(stderr, xargp, 0);
            fputs(" ? ..}", stderr);
            break;

        case Op_Coact:
            putc('{', stderr);
            outimage(stderr, xargp, 0);
            fprintf(stderr, " @ ");
            outimage(stderr, xexpr, 0);
            putc('}', stderr);
            break;

        case Op_Create:
            fprintf(stderr,"{create ..}");
            break;

        case Op_Field:
            putc('{', stderr);
            outimage(stderr, xexpr, 0);
            fprintf(stderr, " . ");
            outfield();
            putc('}', stderr);
            break;

        case Op_Limit:
            fprintf(stderr, "limit counter: ");
            outimage(stderr, xargp, 0);
            break;

        default: {
            struct b_proc *bp;

            /*
             * Have we come here from a C operator/function?
             */
            if (!curr_cf)
                break;

            bp = curr_cf->proc;

            /* 
             * It may be an operator (0-2 args) or a function.
             */
            if (is_op(bp)) {
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                putc('{', stderr);
                if (xnargs == 0)
                    putstr(stderr, bp->name);
                else if (xnargs == 1) {
                    putstr(stderr, bp->name);
                    putc(' ', stderr);
                    outimage(stderr, xargp, 0);
                } else {
                    outimage(stderr, xargp++, 0);
                    putc(' ', stderr);
                    putstr(stderr, bp->name);
                    putc(' ', stderr);
                    outimage(stderr, xargp, 0);
                }
                putc('}', stderr);
            } else {
                /* Not an operator, perhaps a function being resumed. */
                procname(stderr, bp);
                xnargs = curr_cf->nargs;
                xargp = curr_cf->args;
                putc('(', stderr);
                while (xnargs--) {
                    outimage(stderr, xargp++, 0);
                    if (xnargs)
                        putc(',', stderr);
                }
                putc(')', stderr);
            }
        }
    }
	 
    pline = frame_ipc_line(curr_pf);
    pfile = frame_ipc_fname(curr_pf);
    if (pfile && pline) {
        struct descrip t;
        abbr_fname(pfile->fname, &t);
        fprintf(stderr, " from line %d in %.*s", (int)pline->line, (int)StrLen(t), StrLoc(t));
    } else
        fprintf(stderr, " from ?");

    putc('\n', stderr);

    fflush(stderr);
}


/*
 * ctrace - a procedure p being called; produce a trace message.
 */
void call_trace(struct p_frame *pf)
{
    int nargs;
    dptr args;

    showline(pf->caller);
    showlevel(k_level);

    procname(stderr, pf->proc);
    if (pf->curr_inst) {
        fprintf(stderr, " resumed\n");
    } else {
        putc('(', stderr);
        nargs = pf->proc->nparam;
        args = pf->fvars->desc;
        while (nargs--) {
            outimage(stderr, args++, 0);
            if (nargs)
                putc(',', stderr);
        }
        fprintf(stderr, ")\n");
    }
    fflush(stderr);
}

/*
 * procedure frame pf is failing; produce a trace message.
 */

void fail_trace(struct p_frame *pf)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, pf->proc);
    fprintf(stderr, " failed");
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * procedure frame pf is suspending; produce a trace message.
 */

void suspend_trace(struct p_frame *pf)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, pf->proc);
    fprintf(stderr, " suspended ");
    outimage(stderr, &pf->value, 0);
    putc('\n', stderr);
    fflush(stderr);
}


/*
 * procedure frame pf is returning; produce a trace message.
 */

void return_trace(struct p_frame *pf)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, pf->proc);
    fprintf(stderr, " returned ");
    outimage(stderr, &pf->value, 0);
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * Service routine to display variables in given number of
 *  procedure calls to file f.
 */

void xdisp(struct b_coexpr *ce, int count, FILE *f)
{
    dptr *np;
    int n;
    struct b_proc *bp;
    word nglobals;
    dptr dp;
    struct p_frame *pf, *upf;
    struct progstate *p;

    fprintf(f,"co-expression#%ld(%ld)\n\n", (long)ce->id, (long)ce->size);
    pf = ce->curr_pf;

    /* The user pf will be null on a termination dump */
    upf = get_current_user_frame_of(ce);
    if (upf)
        p = upf->proc->program;
    else if (ce->main_of)
        p = ce->main_of;
    else
        p = curpstate;

    while (count && pf) {
        if (!pf->proc->program) {
            /* Skip any non-user procedures on the stack */
            pf = pf->caller;
            continue;
        }

        bp = pf->proc;   /* get addr of procedure block */

        /*
         * Print procedure name.
         */
        procname(f, bp);
        fprintf(f, " local identifiers:\n");

        /*
         * Print arguments.
         */
        np = bp->lnames;
        dp = pf->fvars->desc;
        for (n = bp->nparam; n > 0; n--) {
            fprintf(f, "   ");
            putstr(f, *np);
            fprintf(f, " = ");
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        /*
         * Print locals; they follow the arguments in the frame_vars block
         */
        for (n = bp->ndynam; n > 0; n--) {
            fprintf(f, "   ");
            putstr(f, *np);
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
            putstr(f, *np);
            fprintf(f, " = ");
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        --count;
        pf = pf->caller;
    }

    /*
     * Print globals.
     */

    nglobals = p->Eglobals - p->Globals;

    fprintf(f, "\nglobal identifiers:\n");
    for (n = 0; n < nglobals; n++) {
        fprintf(f, "   ");
        putstr(f, p->Gnames[n]);
        fprintf(f, " = ");
        outimage(f, &p->Globals[n], 0);
        putc('\n', f);
    }
    fflush(f);
}

static void procname(FILE *f, struct b_proc *p)
{
    if (p->field) {
        putstr(f, p->field->defining_class->name);
        putc('.', f);
        putstr(f, p->field->defining_class->program->Fnames[p->field->fnum]);
    } else
        putstr(f, p->name);
}
