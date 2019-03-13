/*
 * rdebug.r - tracebk, get_name, xdisp, ctrace, rtrace, failtrace, strace,
 *   atrace, cotrace
 */

#include "../h/opdefs.h"

/*
 * Prototypes.
 */
static void showline(struct p_frame *pf);
static void showlevel (int n);
static void outfield(void);
static void show_curr_cf(void);
static void show_curr_cf_op(void);
static void show_args(dptr args, int nargs);
static void xtrace	(void);
static void procname(FILE *f, struct b_proc *p);
static void trace_at(struct p_frame *pf);
static void trace_from(struct p_frame *pf);
static void trace_frame(struct p_frame *pf);
static void trace_line(struct p_frame *pf, char *msg, int xdef);

#define LIMIT 100

/*
 * These are set at various strategic points to help give better error
 * messages.
 */
dptr xexpr;
dptr xfield;
dptr xargp;
dptr xarg1, xarg2, xarg3;   /* Operator args */

struct ipc_line *frame_ipc_line(struct p_frame *pf)
{
    while (pf && !pf->proc->program)
        pf = pf->caller;
    if (!pf)
        return 0;
    return find_ipc_line(pf->curr_inst, pf->proc->program);
}

struct ipc_fname *frame_ipc_fname(struct p_frame *pf)
{
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

void traceback(struct b_coexpr *ce, int with_xtrace, int act_chain)
{
    struct act_chain *head = 0, *ae;
    struct frame_chain *fe;
    int depth = 0;

    fprintf(stderr, "Traceback:\n");
    while (ce && !in_act_chain(head, ce)) {
        struct p_frame *pf;
        ae = safe_malloc(sizeof(struct act_chain));
        ae->coex = ce;
        ae->frames = 0;
        ae->next = head;
        ae->nframes = 0;
        head = ae;
        for (pf = ce->curr_pf; pf; pf = pf->caller) {
            if (pf->proc->program) {
                fe = safe_malloc(sizeof(struct frame_chain));
                fe->frame = pf;
                fe->next = ae->frames;
                ae->frames = fe;
                ++ae->nframes;
                ++depth;
            }
        }
        ce = ce->activator;
        if (!act_chain)
            break;
    }

    for (ae = head; ae;) {
        struct act_chain *t;
        if (depth - LIMIT >= ae->nframes) {
            /* Skip entirely */
            depth -= ae->nframes;
            for (fe = ae->frames; fe;) {
                struct frame_chain *t = fe->next;
                free(fe);
                fe = t;
            }
        } else {
            /* Will print some of this coexpression's calls, so print header */
            if (ae->coex->activator)
                fprintf(stderr,"co-expression#" UWordFmt " activated by co-expression#" UWordFmt "\n", 
                        ae->coex->id, ae->coex->activator->id);
            else
                fprintf(stderr,"co-expression#" UWordFmt " (never activated)\n", ae->coex->id);

            if (depth > LIMIT) {
                if (depth == LIMIT + 1)
                    depth = LIMIT;  /* Avoid printing "1 call omitted" */
                else
                    fprintf(stderr, "   ... %d calls omitted\n", depth - LIMIT);
            }
            for (fe = ae->frames; fe;) {
                struct frame_chain *t;
                if (depth <= LIMIT)
                    trace_frame(fe->frame);
                depth--;
                if (!fe->next) {
                    /* Last frame in the coexpression gets an extra line showing the position
                     * or an xtrace showing the current operation and its parameters. */
                    if (ae->next) 
                        trace_at(fe->frame);
                    else {
                        if (with_xtrace)
                            xtrace();
                        else if (ce->activator)
                            trace_at(fe->frame);
                    }
                }
                t = fe->next;
                free(fe);
                fe = t;
            }
        }
        t = ae->next;
        free(ae);
        ae = t;
    }
    fflush(stderr);
}

static void trace_line(struct p_frame *pf, char *msg, int pdef)
{
    struct ipc_line *pline;
    struct ipc_fname *pfile;
    pline = frame_ipc_line(pf);
    pfile = frame_ipc_fname(pf);
    if (pfile && pline) {
        struct descrip t;
        abbr_fname(pfile->fname, &t);
        fputs(msg, stderr);
        begin_link(stderr, pfile->fname, pline->line);
        fprintf(stderr, "line " WordFmt " in %.*s", pline->line, StrF(t));
        end_link(stderr);
    } else if (pdef)
        fprintf(stderr, "%s?", msg);
    putc('\n', stderr);
}

static void trace_at(struct p_frame *pf)
{
    trace_line(pf, "   at ", 1);
}

static void trace_from(struct p_frame *pf)
{
    trace_line(pf, " from ", 1);
}

static void trace_frame(struct p_frame *pf)
{
    fprintf(stderr, "   ");
    procname(stderr, (struct b_proc *)pf->proc);
    show_args(pf->fvars->desc, pf->proc->nparam);
    trace_line(pf->caller, " from ", 0);
}

static void cotrace_line(struct b_coexpr *from)
{
    struct p_frame *pf = get_current_user_frame_of(from);
    showline(pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)pf->proc);
}

void trace_coact(struct b_coexpr *from, struct b_coexpr *to, dptr val)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#" UWordFmt " : ", from->id);
    outimage(stderr, val, 0);
    fprintf(stderr, " @ co-expression#" UWordFmt "\n", to->id);
    fflush(stderr);
}

void trace_coret(struct b_coexpr *from, struct b_coexpr *to, dptr val)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#" UWordFmt " returned ", from->id);
    outimage(stderr, val, 0);
    fprintf(stderr, " to co-expression#" UWordFmt "\n", to->id);
    fflush(stderr);
}

void trace_cofail(struct b_coexpr *from, struct b_coexpr *to)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#" UWordFmt " failed to co-expression#" UWordFmt "\n", from->id, to->id);
    fflush(stderr);
}

void trace_cofail_to_handler(struct b_coexpr *from, struct b_coexpr *to)
{
    cotrace_line(from);
    fprintf(stderr,"; co-expression#" UWordFmt " failed to &handler co-expression#" UWordFmt "\n", from->id, to->id);
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

    if (pline && pfile) {
        struct descrip t;
        char *p;
        int i;
        begin_link(stderr, pfile->fname, pline->line);
        abbr_fname(pfile->fname, &t);
        i = StrLen(t);
        p = StrLoc(t);
        while (i > 13) {
            p++;
            i--;
        }
        fprintf(stderr, "%-13.*s: %4" WordFmtCh "  ", i, p, pline->line);
        end_link(stderr);
    } else
        fprintf(stderr, "             :       ");
}

    
/*
 * showlevel - print "| " n times.
 */
static void showlevel(int n)
{
    while (n-- > 0)
        fputs("| ", stderr);
}


static void outfield()
{
    if (xfield && 0 <= IntVal(*xfield) && IntVal(*xfield) < efnames - fnames)
        putstr(stderr, fnames[IntVal(*xfield)]);
    else
        fprintf(stderr, "field");
}

/*
 * Is a given b_proc an operator or not?
 */
static int is_op(struct c_proc *bp)
{
    int i;
    for (i = 0; i < op_tbl_sz; ++i) {
        if (op_tbl[i] == bp)
            return 1;
    }
    return 0;
}

/*
 * Show a simple argument list.
 */
static void show_args(dptr args, int nargs)
{
    putc('(', stderr);
    while (nargs--) {
        outimage(stderr, args++, 0);
        if (nargs)
            putc(',', stderr);
    }
    putc(')', stderr);
}

/*
 * Show the current C frame's name and arguments.
 */
static void show_curr_cf()
{
    fprintf(stderr, "   ");
    procname(stderr, (struct b_proc *)curr_cf->proc);
    show_args(curr_cf->args, curr_cf->nargs);
}

/*
 * Show the current C frame's name and arguments, in operator (0-2
 * args) format.
 */
static void show_curr_cf_op()
{
    int nargs;
    dptr args;
    nargs = curr_cf->nargs;
    args = curr_cf->args;
    fprintf(stderr, "   {");
    if (nargs == 0)
        putstr(stderr, curr_cf->proc->name);
    else if (nargs == 1) {
        putstr(stderr, curr_cf->proc->name);
        putc(' ', stderr);
        outimage(stderr, args, 0);
    } else {
        outimage(stderr, args++, 0);
        putc(' ', stderr);
        putstr(stderr, curr_cf->proc->name);
        putc(' ', stderr);
        outimage(stderr, args, 0);
    }
    putc('}', stderr);
}

/*
 * xtrace - show offending expression.
 */
static void xtrace()
{
    if (curr_op == 0)
        return;

    switch ((int)curr_op) {

        case Op_Keywd:
            fprintf(stderr,"   bad keyword reference");
            break;

        case Op_Invokef:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                show_curr_cf();
            } else if (xexpr) {
                /* Error to do with the type of expr */
                fprintf(stderr, "   ");
                outimage(stderr, xexpr, 0);
                /* We won't have a field if called from general_call() */
                if (xfield) {
                    fprintf(stderr, " . ");
                    outfield();
                }
                fprintf(stderr," ( .. )");
            }
            break;

        case Op_Applyf:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                show_curr_cf();
            } else if (xexpr) {
                /* Error to do with the type of expr */
                fprintf(stderr, "   ");
                outimage(stderr, xexpr, 0);
                /* We won't have a field if called from general_call() */
                if (xfield) {
                    fprintf(stderr, " . ");
                    outfield();
                }
                fprintf(stderr, " ! ");
                if (xargp)
                    outimage(stderr, xargp, 0);
                else
                    fprintf(stderr, "[ .. ]");
            }
            break;

        case Op_Apply:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                show_curr_cf();
            } else if (xexpr) {
                /* Error to do with the type of expr */
                fprintf(stderr, "   ");
                outimage(stderr, xexpr, 0);
                fprintf(stderr, " ! ");
                if (xargp)
                    outimage(stderr, xargp, 0);
                else
                    fprintf(stderr, "[ .. ]");
            }
            break;

        case Op_Invoke:
            if (curr_cf) {
                /* Will happen if a builtin proc calls runnerr */
                show_curr_cf();
            } else if (xexpr) {
                /* Error to do with the type of expr */
                fprintf(stderr, "   ");
                outimage(stderr, xexpr, 0);
                fprintf(stderr," ( .. )");
            }
            break;

        case Op_Toby:
            xargp = curr_cf->args;
            fprintf(stderr, "   {");
            outimage(stderr, xargp++, 0);
            fprintf(stderr, " to ");
            outimage(stderr, xargp++, 0);
            fprintf(stderr, " by ");
            outimage(stderr, xargp, 0);
            putc('}', stderr);
            break;

        case Op_Subsc:
            if (xarg1 && xarg2) {
                fprintf(stderr, "   {");
                outimage(stderr, xarg1, 0);
                putc('[', stderr);
                outimage(stderr, xarg2, 0);
                putc(']', stderr);
                putc('}', stderr);
            }
            break;

        case Op_Sect:
            if (xarg1 && xarg2 && xarg3) {
                fprintf(stderr, "   {");
                outimage(stderr, xarg1, 0);
                putc('[', stderr);
                outimage(stderr, xarg2, 0);
                putc(':', stderr);
                outimage(stderr, xarg3, 0);
                putc(']', stderr);
                putc('}', stderr);
            }
            break;

        case Op_ScanSave:
            if (xarg1) {
                fprintf(stderr, "   {");
                outimage(stderr, xarg1, 0);
                fputs(" ? ..}", stderr);
            }
            break;

        case Op_Activate:
            if (xarg1 && xarg2) {
                fprintf(stderr, "   {");
                outimage(stderr, xarg1, 0);
                fprintf(stderr, " @ ");
                outimage(stderr, xarg2, 0);
                putc('}', stderr);
            }
            break;

        case Op_Create:
            fprintf(stderr,"   {create ..}");
            break;

        case Op_Field:
            if (xexpr) {
                fprintf(stderr, "   {");
                outimage(stderr, xexpr, 0);
                fprintf(stderr, " . ");
                outfield();
                putc('}', stderr);
            }
            break;

        case Op_Limit:
            if (xarg1) {
                fprintf(stderr, "   limit counter: ");
                outimage(stderr, xarg1, 0);
            }
            break;

        case Op_Cat: 
        case Op_Diff: 
        case Op_Div: 
        case Op_Inter: 
        case Op_Lconcat: 
        case Op_Minus: 
        case Op_Mod: 
        case Op_Mult: 
        case Op_Plus: 
        case Op_Power: 
        case Op_Union: 
        case Op_Eqv: 
        case Op_Lexeq: 
        case Op_Lexge: 
        case Op_Lexgt: 
        case Op_Lexle: 
        case Op_Lexlt: 
        case Op_Lexne: 
        case Op_Neqv: 
        case Op_Numeq: 
        case Op_Numge: 
        case Op_Numgt: 
        case Op_Numle: 
        case Op_Numlt: 
        case Op_Numne:  
            if (xarg1 && xarg2) {
                fputs("   {", stderr);
                outimage(stderr, xarg1, 0);
                fprintf(stderr, " %.*s ", StrF(*opblks[curr_op]->name));
                outimage(stderr, xarg2, 0);
                putc('}', stderr);
            }
            break;

        case Op_Asgn: 
        case Op_Asgn1:
            if (xarg1 && xarg2) {
                fputs("   {", stderr);
                outimage(stderr, xarg1, 0);
                fprintf(stderr, " := ");
                outimage(stderr, xarg2, 0);
                putc('}', stderr);
            }
            break;

        case Op_Swap: 
        case Op_Swap1:
            if (xarg1 && xarg2) {
                fputs("   {", stderr);
                outimage(stderr, xarg1, 0);
                fprintf(stderr, " :=: ");
                outimage(stderr, xarg2, 0);
                putc('}', stderr);
            }
            break;

        case Op_Value: 
        case Op_Size: 
        case Op_Refresh: 
        case Op_Number: 
        case Op_Compl: 
        case Op_Neg: 
        case Op_Null: 
        case Op_Nonnull:
        case Op_Random: 
            if (xarg1) {
                fprintf(stderr, "   {%.*s ", StrF(*opblks[curr_op]->name));
                outimage(stderr, xarg1, 0);
                putc('}', stderr);
            }
            break;

        default:
            /*
             * Have we come here from a C operator/function?
             */
            if (!curr_cf) {
                trace_at(curr_pf);
                return;
            }

            /* 
             * It may be an operator (0-2 args) or perhaps a function being resumed.
             */
            if (is_op(curr_cf->proc))
                show_curr_cf_op();
            else
                show_curr_cf();

            break;
    }

    trace_from(curr_pf);
}


/*
 * ctrace - a procedure p being called; produce a trace message.
 */
void call_trace(struct p_frame *pf)
{
    showline(pf->caller);
    showlevel(k_level);

    procname(stderr, (struct b_proc *)pf->proc);
    if (pf->curr_inst)
        fprintf(stderr, " resumed");
    else
        show_args(pf->fvars->desc, pf->proc->nparam);
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * procedure frame pf is failing; produce a trace message.
 */

void fail_trace(struct p_frame *pf)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)pf->proc);
    fprintf(stderr, " failed");
    putc('\n', stderr);
    fflush(stderr);
}

/*
 * procedure frame pf is suspending; produce a trace message.
 */

void suspend_trace(struct p_frame *pf, dptr val)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)pf->proc);
    fprintf(stderr, " suspended ");
    outimage(stderr, val, 0);
    putc('\n', stderr);
    fflush(stderr);
}


/*
 * procedure frame pf is returning; produce a trace message.
 */

void return_trace(struct p_frame *pf, dptr val)
{
    showline(pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)pf->proc);
    fprintf(stderr, " returned ");
    outimage(stderr, val, 0);
    putc('\n', stderr);
    fflush(stderr);
}



void c_call_trace(struct c_frame *cf)
{
    showline(curr_pf);
    showlevel(k_level);

    procname(stderr, (struct b_proc *)cf->proc);
    if (cf->pc)
        fprintf(stderr, " resumed");
    else
        show_args(cf->args, cf->nargs);
    putc('\n', stderr);
    fflush(stderr);
}

void c_fail_trace(struct c_frame *cf)
{
    showline(curr_pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)cf->proc);
    fprintf(stderr, " failed");
    putc('\n', stderr);
    fflush(stderr);
}

void c_return_trace(struct c_frame *cf)
{
    showline(curr_pf);
    showlevel(k_level);
    procname(stderr, (struct b_proc *)cf->proc);
    if (cf->exhausted)
        fprintf(stderr, " returned ");
    else
        fprintf(stderr, " suspended ");
    if (cf->lhs)
        outimage(stderr, cf->lhs, 0);
    else
        fprintf(stderr, "(value discarded)");
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
    word n;
    struct p_proc *bp;
    dptr dp;
    struct p_frame *pf, *upf;
    struct progstate *p;

    fprintf(f,"co-expression#" UWordFmt "\n\n", ce->id);
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
        procname(f, (struct b_proc *)bp);
        fprintf(f, " local identifiers:\n");

        /*
         * Print arguments.
         */
        np = bp->lnames;
        dp = pf->fvars->desc;
        for (n = bp->nparam; n > 0; n--) {
            fprintf(f, "   %.*s = ", StrF(**np));
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        /*
         * Print locals; they follow the arguments in the frame_vars block
         */
        for (n = bp->ndynam; n > 0; n--) {
            fprintf(f, "   %.*s = ", StrF(**np));
            outimage(f, dp++, 0);
            putc('\n', f);
            np++;
        }

        /*
         * Print statics.
         */
        dp = bp->fstatic;
        for (n = bp->nstatic; n > 0; n--) {
            fprintf(f, "   %.*s = ", StrF(**np));
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
    fprintf(f, "\nglobal identifiers:\n");
    for (n = 0; n < p->NGlobals; n++) {
        fprintf(f, "   %.*s = ", StrF(*p->Gnames[n]));
        outimage(f, &p->Globals[n], 0);
        putc('\n', f);
    }
    fflush(f);
}

static void procname(FILE *f, struct b_proc *p)
{
    if (p->field)
        fprintf(f, "%.*s.%.*s",
                StrF(*p->field->defining_class->name), 
                StrF(*p->field->defining_class->program->Fnames[p->field->fnum]));
    else
        putstr(f, p->name);
}

void print_desc(FILE *f, dptr d) {
    if (!d)
        fprintf(f, "{nil}");
    else {
        putc('{', f);
        print_dword(f, d);
        fputs(", ", f); 
        print_vword(f, d);
        putc('}', f);
    }
    fflush(f);
}

void print_vword(FILE *f, dptr d) {
    if (Qual(*d)) {
        fprintf(f, "%p -> ", StrLoc(*d));
        outimage(f, d, 1);
    } else if (is:struct_var(*d)) {
        /* D_StructVar (with an offset) */
        fprintf(f, "%p+" UWordFmt " -> ", BlkLoc(*d), (uword)(WordSize*Offset(*d)));
        print_desc(f, OffsetVarLoc(*d));
    } else {
        switch (d->dword) {
            case D_NamedVar : {
                /* D_NamedVar (pointer to another descriptor) */
                fprintf(f, "%p -> ", VarLoc(*d));
                print_desc(f, VarLoc(*d));
                break;
            }
            case D_Tvsubs : {
                struct b_tvsubs *p = &TvsubsBlk(*d);
                fprintf(f, "%p -> sub=" WordFmt "+:" WordFmt " ssvar=", p, p->sspos, p->sslen);
                print_desc(f, &p->ssvar);
                break;
            }

            case D_Tvtbl : {
                struct b_tvtbl *p = &TvtblBlk(*d);
                fprintf(f, "clink=%p %p -> tref=", p->clink, p);
                print_desc(f, &p->tref);
                break;
            }

            case D_Kywdint :
            case D_Kywdpos :
            case D_Kywdsubj :
            case D_Kywdstr :
            case D_Kywdhandler:
            case D_Kywdany : {
                fprintf(f, "%p -> ", VarLoc(*d));
                print_desc(f, VarLoc(*d));
                break;
            }

            case D_TendPtr : {
                fprintf(f, "%p", BlkLoc(*d));
                break;
            }

            case D_Yes :
            case D_Null : {
                fputc('0', f); 
                break;
            }

            case D_Integer : {
                fprintf(f, WordFmt, IntVal(*d)); 
                break;
            }

            case D_Lelem :
            case D_Selem :
            case D_Telem :
            case D_Slots : {
                outimage(f, d, 1);
                break;
            }

            case D_Proc : {
                struct b_proc *p = &ProcBlk(*d);
                switch (p->type) {
                    case P_Proc: {
                        fprintf(f, "%p -> prog:%p=", p, ((struct p_proc *)p)->program);
                        break;
                    }
                    case C_Proc: {
                        fprintf(f, "%p -> ", p);
                        break;
                    }
                    default: {
                        syserr("Unknown proc type");
                    }
                }
                outimage(f, d, 1);
                break;
            }

            case D_Class : {
                struct b_class *p = &ClassBlk(*d);
                fprintf(f, "%p -> prog:%p=", p, p->program);
                outimage(f, d, 1);
                break;
            }

            case D_Constructor : {
                struct b_constructor *p = &ConstructorBlk(*d);
                fprintf(f, "%p -> prog:%p=", p, p->program);
                outimage(f, d, 1);
                break;
            }

#if RealInDesc
            case D_Real : {
                fputs(double2cstr(d->vword.realval), f);
                break;
            }
#endif

            case D_List :
            case D_Set : 
            case D_Table :
            case D_Record :
            case D_Coexpr :
            case D_Lrgint :
#if !RealInDesc
            case D_Real :
#endif
            case D_Cset :
            case D_Methp :
            case D_Weakref :
            case D_Ucs :
            case D_Object : {
                fprintf(f, "%p -> ", BlkLoc(*d));
                outimage(f, d, 1);
                break;
            }

            default : fputc('?', f); 
        }
    }
}

void print_dword(FILE *f, dptr d) {
    if (Qual(*d)) {
        /* String */
        fprintf(f, WordFmt, d->dword);
    } else if (is:struct_var(*d)) {
        /* D_StructVar (with an offset) */
        fprintf(f, "D_StructVar off:" UWordFmt "", (uword)Offset(*d));
    } else {
        switch (d->dword) {
            case D_TendPtr : fputs("D_TendPtr", f); break;
            case D_NamedVar : fputs("D_NamedVar", f); break;
            case D_Tvsubs : fputs("D_Tvsubs", f); break;
            case D_Tvtbl : fputs("D_Tvtbl", f); break;
            case D_Kywdint : fputs("D_Kywdint", f); break;
            case D_Kywdpos : fputs("D_Kywdpos", f); break;
            case D_Kywdsubj : fputs("D_Kywdsubj", f); break;
            case D_Kywdstr : fputs("D_Kywdstr", f); break;
            case D_Kywdany : fputs("D_Kywdany", f); break;
            case D_Null : fputs("D_Null", f); break;
            case D_Yes : fputs("D_Yes", f); break;
            case D_Integer : fputs("D_Integer", f); break;
            case D_Lrgint : fputs("D_Lrgint", f); break;
            case D_Real : fputs("D_Real", f); break;
            case D_Cset : fputs("D_Cset", f); break;
            case D_Proc : fputs("D_Proc", f); break;
            case D_Record : fputs("D_Record", f); break;
            case D_List : fputs("D_List", f); break;
            case D_Lelem : fputs("D_Lelem", f); break;
            case D_Set : fputs("D_Set", f); break;
            case D_Selem : fputs("D_Selem", f); break;
            case D_Table : fputs("D_Table", f); break;
            case D_Telem : fputs("D_Telem", f); break;
            case D_Slots : fputs("D_Slots", f); break;
            case D_Coexpr : fputs("D_Coexpr", f); break;
            case D_Class : fputs("D_Class", f); break;
            case D_Object : fputs("D_Object", f); break;
            case D_Constructor : fputs("D_Constructor", f); break;
            case D_Methp : fputs("D_Methp", f); break;
            case D_Weakref : fputs("D_Weakref", f); break;
            case D_Ucs : fputs("D_Ucs", f); break;
            case D_Kywdhandler: fputs("D_Kywdhandler", f); break;
            default : fputc('?', f);
        }
    }
}

/*
 * Given a block, return an appropriate descriptor.  Note that
 * structure sub-blocks for lists, tables and sets are converted to
 * descriptors of their parent structures.
 */
struct descrip block_to_descriptor(union block *ptr)
{
    word d, t = BlkType(ptr);
    struct descrip desc;
    switch (t) {
        case T_Lrgint: d = D_Lrgint; break;
#if !RealInDesc
        case T_Real: d = D_Real; break; 
#endif
        case T_Cset: d = D_Cset; break;
        case T_Constructor: d = D_Constructor; break;
        case T_Proc: d = D_Proc; break;
        case T_Record: d = D_Record; break;
        case T_Lelem: {
            while (BlkType(ptr) == T_Lelem)
                ptr = ptr->lelem.listnext;
            /* fall through */
        }
        case T_List: d = D_List; break;
        case T_Selem: {
            while (BlkType(ptr) == T_Selem)
                ptr = ptr->telem.clink;
            /* fall through */
        }
        case T_Set: d = D_Set; break;
        case T_Telem: {
            while (BlkType(ptr) == T_Telem)
                ptr = ptr->telem.clink;
            /* fall through */
        }
        case T_Table: d = D_Table; break;
        case T_Tvtbl: d = D_Tvtbl; break;
        case T_Slots: return block_to_descriptor(ptr->slots.hslots[0]);
        case T_Tvsubs: d = D_Tvsubs; break;
        case T_Methp: d = D_Methp; break;
        case T_Coexpr: d = D_Coexpr; break;
        case T_Ucs: d = D_Ucs; break;
        case T_Class: d = D_Class; break;
        case T_Object: d = D_Object; break;
        case T_Weakref: d = D_Weakref; break;
        default: {
            syserr("Unknown block type");
            /* Not reached */
            d = 0;
        }
    }
    MakeDesc(d, ptr, &desc);
    return desc;
}

void showcurrstack()
{
    if (!k_current) {
        fprintf(stderr, "curpstate=%p k_current is 0\n",curpstate);
        return;
    }    
    fprintf(stderr, "ipc=%p k_current= %p k_current->sp=%p k_current->curr_pf=%p\n",
           ipc, k_current, k_current->sp, k_current->curr_pf);
    showstack(stderr, k_current);
}

void showstack(FILE *f, struct b_coexpr *c)
{
    struct frame *x;
    fprintf(f, "Stack trace for coexpression %p\n", c);
    x = c->sp;
    while (x) {
        struct descrip tmp;
        int i;
        if (x == c->sp)
            fprintf(f, "SP-> ");
        if (x == (struct frame *)c->curr_pf)
            fprintf(f, "PF-> ");
        fprintf(f, "Frame %p type=%c, size=%d\n", x, 
               x->type == C_Frame ? 'C':'P', 
               x->size);
        fprintf(f, "\tlhs=%p\n",x->lhs);
        fprintf(f, "\tfailure_label=%p\n", x->failure_label);
        fprintf(f, "\tparent_sp=%p\n", x->parent_sp);
        fprintf(f, "\tcreator=%p\n", x->creator);
        fprintf(f, "\texhausted=%d\n", x->exhausted);
        fprintf(f, "\trval=%d\n", x->rval);
        switch (x->type) {
            case C_Frame: {
                struct c_frame *cf = (struct c_frame *)x;
                MakeDesc(D_Proc, cf->proc, &tmp);
                fprintf(f, "\tproc="); print_vword(f, &tmp); fprintf(f, "\n");
                fprintf(f, "\tpc=0x" XWordFmt "\n", cf->pc);
                fprintf(f, "\tnargs=%d\n", cf->nargs);
                for (i = 0; i < cf->nargs; ++i) {
                    fprintf(f, "\targs[%d]=", i); print_desc(f, &cf->args[i]); fprintf(f, "\n");
                }
                for (i = 0; i < cf->proc->ntend; ++i) {
                    fprintf(f, "\ttend[%d]=", i); print_desc(f, &cf->tend[i]); fprintf(f, "\n");
                }
                break;
            }
            case P_Frame: {
                struct p_frame *pf = (struct p_frame *)x;
                dptr *np, dp;
                int j;
                MakeDesc(D_Proc, pf->proc, &tmp);
                fprintf(f, "\tproc="); print_vword(f, &tmp); fprintf(f, "\n");
                fprintf(f, "\tipc=%p\n", pf->ipc);
                fprintf(f, "\tcurr_inst=%p\n", pf->curr_inst);
                fprintf(f, "\tcaller=%p\n", pf->caller);
                for (i = 0; i < pf->proc->nclo; ++i) {
                    fprintf(f, "\tclo[%d]=%p\n", i, pf->clo[i]);
                }
                for (i = 0; i < pf->proc->ntmp; ++i) {
                    fprintf(f, "\ttmp[%d]=", i); print_desc(f, &pf->tmp[i]); fprintf(f, "\n");
                }
                for (i = 0; i < pf->proc->nlab; ++i) {
                    fprintf(f, "\tlab[%d]=%p\n", i, pf->lab[i]);
                }
                for (i = 0; i < pf->proc->nmark; ++i) {
                    fprintf(f, "\tmark[%d]=%p\n", i, pf->mark[i]);
                }
                if (pf->fvars) {
                    fprintf(f, "\tfvars=%p, size=%d\n", pf->fvars, pf->fvars->size);
                    i = 0;
                    np = pf->proc->lnames;
                    dp = pf->fvars->desc;
                    for (j = 0; j < pf->proc->nparam; ++j) {
                        if (np) {
                            fprintf(f, "\t   fvars.desc[%d] (arg %.*s)=", i, StrF(**np)); 
                            ++np;
                        } else
                            fprintf(f, "\t   fvars.desc[%d] (arg %d)=", i, j);
                        print_desc(f, dp++); fprintf(f, "\n");
                        ++i;
                    }
                    for (j = 0; j < pf->proc->ndynam; ++j) {
                        if (np) {
                            fprintf(f, "\t   fvars.desc[%d] (local %.*s)=", i, StrF(**np)); 
                            ++np;
                        } else
                            fprintf(f, "\t   fvars.desc[%d] (local %d)=", i, j);
                        print_desc(f, dp++); fprintf(f, "\n");
                        ++i;
                    }
                    fprintf(f, "\t   fvars.desc-desc_end=%p-%p\n", pf->fvars->desc, pf->fvars->desc_end);
                    fprintf(f, "\t   fvars.refcnt=%d\n", pf->fvars->refcnt);
                    fprintf(f, "\t   fvars.seen=%d\n", pf->fvars->seen);
                } else
                    fprintf(f, "\tfvars=%p\n", pf->fvars);
                break;
            }
            default:
                syserr("Unknown frame type");
        }
        x = x->parent_sp;

    }
    fprintf(f, "------bottom of stack--------\n");
    fflush(f);
}

