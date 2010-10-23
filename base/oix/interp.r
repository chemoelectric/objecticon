#include "../h/opdefs.h"
#include "../h/opnames.h"

static void coact_ex(void);
static void coact_handler();
static void get_child_prog_result(void);
static void activate_child_prog(void);
static void do_cofail(void);
static void do_activate(void);
static void do_op(int nargs);
static void do_mgop(int nargs);
static void do_opclo(int nargs);
static void do_keyop(void);
static void do_keyclo(void);
static void do_makelist(void);
static void do_create(void);
static void do_coret(void);
static void do_limit(void);
static void do_scansave(void);
static void pop_from_prog_event_queue(struct progstate *prog, dptr res);
static void fatalerr_139(void);


#include "interpiasm.ri"

word curr_op;  /* Last op read in interpreter loop */

struct progstate *curpstate;
struct b_coexpr *k_current;        /* Always == curpstate->K_current */
struct p_frame *curr_pf;           /* Always == curpstate->K_current->curr_pf */
word *ipc;                         /* Notionally curpstate->K_current->curr_pf->ipc, synchronized whenever
                                    * curr_pf is changed */
struct c_frame *curr_cf;           /* currently executing c frame */

void synch_ipc()
{
    curr_pf->ipc = ipc;
}

/*
 * Switch programs; this is called to switch during program monitoring.
 */
void set_curpstate(struct progstate *p)
{
    curr_pf->ipc = ipc;
    curpstate = p;
    k_current = p->K_current;
    curr_pf = k_current->curr_pf;
    ipc = curr_pf->ipc;
}

/*
 * Switch co-expressions.
 */
void switch_to(struct b_coexpr *ce)
{
    curr_pf->ipc = ipc;
    curpstate = get_current_program_of(ce);
    k_current = curpstate->K_current = ce;
    curr_pf = k_current->curr_pf;
    ipc = curr_pf->ipc;
}

/*
 * Change the current p_frame to a new value.
 */
void set_curr_pf(struct p_frame *pf)
{
    struct progstate *p = pf->proc->program;
    curr_pf->ipc = ipc;
    /* Check whether we are changing to a different program. */
    if (p && p != curpstate) {
        p->K_current = k_current;
        curpstate = p;
    }
    curr_pf = k_current->curr_pf = pf;
    ipc = curr_pf->ipc;
}

void tail_invoke_frame(struct frame *f)
{
    switch (f->type) {
        case C_Frame: {
            curr_cf = (struct c_frame *)f;
            Desc_EVValD(curr_cf->proc, E_Pcall, D_Proc);
            if (!curr_cf->proc->ccode(curr_cf)) {
                ipc = f->failure_label;
                pop_to(f->parent_sp);
            }
            curr_cf = 0;
            break;
        }
        case P_Frame: {
            struct p_frame *pf = (struct p_frame *)f;
            Desc_EVValD(pf->proc, E_Pcall, D_Proc);
            pf->caller = curr_pf;
            if (pf->proc->program) {
                /*
                 * If tracing is on, use ctrace to generate a message.
                 */   
                if (k_trace) {
                    k_trace--;
                    call_trace(pf);
                }
                if (++k_level > k_maxlevel) {
                    struct descrip t;
                    /* Some info for ttrace... */
                    curr_op = Op_Invoke;
                    t.dword = D_Proc;
                    BlkLoc(t) = (union block *)pf->proc;
                    xexpr = &t;
                    fatalerr(311, NULL);
                }
            }
            set_curr_pf(pf);
            break;
        }
        default:
            syserr("Unknown frame type");
    }
}

void push_frame(struct frame *f)
{
    f->parent_sp = k_current->sp;
    k_current->sp = f;
}

void pop_to(struct frame *f)
{
    while (k_current->sp != f) {
        struct frame *t = k_current->sp;
        k_current->sp = t->parent_sp;
        if (!k_current->sp)
            syserr("pop_to: target not found on stack");
        free_frame(t);
    }
}

word get_offset(word *w)
{
    struct p_proc *pp = curr_pf->proc;
    word *code_start = pp->program ? (word *)pp->program->Code : pp->icode;
    return DiffPtrsBytes(w, code_start);
}

struct inline_field_cache *get_inline_field_cache()
{
    struct inline_field_cache *t = (struct inline_field_cache *)ipc;
    ipc += 2;
    return t;
}

/*
 * Return a pointer to the read descriptor.
 */
dptr get_dptr()
{
    word op = GetWord;
    switch (op) {
        case Op_Nil: {
            return 0;
        }
        case Op_Static:
        case Op_Global: {
            return (dptr)GetAddr;
        }
        case Op_FrameVar: {
            return &curr_pf->fvars->desc[GetWord];
        }
        case Op_Tmp: {
            return &curr_pf->tmp[GetWord];
        }

        default: {
            syserr("Invalid opcode in get_dptr: %d (%s)\n", op, op_names[op]);
            return 0;
        }
    }
}

/*
 * Get a descriptor, but dereference temporary descriptors
 * (dynamics/args/statics/globals should never be variables).
 */
void get_deref(dptr dest)
{
    word op = GetWord;
    switch (op) {
        case Op_Int: {
            MakeInt(GetWord, dest);
            break;
        }
#if REAL_IN_DESC
        case Op_Real: {
            MakeReal(GetReal, dest);
            break;
        }
#endif
        case Op_Knull: {
            *dest = nulldesc;
            break;
        }
        case Op_Const:
        case Op_Static:
        case Op_Global: {
            *dest = *(dptr)GetAddr;
            break;
        }
        case Op_FrameVar: {
            *dest = curr_pf->fvars->desc[GetWord];
            break;
        }
        case Op_Tmp: {
            deref(&curr_pf->tmp[GetWord], dest);
            break;
        }

        default: {
            syserr("Invalid opcode in get_deref: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Get a descriptor, but make a named variable rather than copying
 * dynamics/args/statics/globals.
 */
void get_variable(dptr dest)
{
    word op = GetWord;
    switch (op) {
        case Op_Int: {
            MakeInt(GetWord, dest);
            break;
        }
#if REAL_IN_DESC
        case Op_Real: {
            MakeReal(GetReal, dest);
            break;
        }
#endif
        case Op_Knull: {
            *dest = nulldesc;
            break;
        }
        case Op_Const: {
            *dest = *(dptr)GetAddr;
            break;
        }
        case Op_Static:
        case Op_Global: {
            MakeNamedVar((dptr)GetAddr, dest);
            break;
        }
        case Op_FrameVar: {
            MakeNamedVar(&curr_pf->fvars->desc[GetWord], dest);
            break;
        }
        case Op_Tmp: {
            *dest = curr_pf->tmp[GetWord];
            break;
        }

        default: {
            syserr("Invalid opcode in get_variable: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Skip over a variable.
 */
void skip_descrip()
{
    word op = GetWord;
    switch (op) {
        case Op_Const:
        case Op_Static:
        case Op_Global:
        case Op_Int:
#if REAL_IN_DESC
        case Op_Real:
#endif
        case Op_FrameVar:
        case Op_Tmp: {
            ipc++;
            break;
        }
        case Op_Knull: {
            break;
        }
        default: {
            syserr("Invalid opcode in skip_descrip: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * A quick version of alc_c_frame which allocates on the C stack using
 * alloca, instead of malloc.  It is used for operators whose frames
 * are allocated and then immediately deallocated after the operator
 * is called (do_op and do_keyop).
 */

#begdef quick_alc_c_frame(p, pb, argc)
{
    char *t;
    int size, i;
    size = pb->framesize + (argc + pb->ntend) * sizeof(struct descrip);
#ifdef HAVE_ALLOCA
    p = alloca(size);
#else
    MemProtect(p = malloc(size));
#endif
    p->size = size;
    p->creator = 0;
    p->type = C_Frame;
    p->lhs = 0;
    p->proc = pb;
    p->parent_sp = 0;
    p->failure_label = 0;
    p->rval = 0;
    p->exhausted = 0;
    p->pc = 0;
    p->nargs = argc;
    t = (char *)p + pb->framesize;
    if (argc) {
        p->args = (dptr)t;
        for (i = 0; i < argc; ++i)
            p->args[i] = nulldesc;
        t += argc * sizeof(struct descrip);
    } else
        p->args = 0;
    if (pb->ntend) {
        p->tend = (dptr)t;
        for (i = 0; i < pb->ntend; ++i)
            p->tend[i] = nulldesc;
    } else
        p->tend = 0;
}
#enddef

#begdef quick_free_frame(p)
#ifndef HAVE_ALLOCA
    free(p);
#endif
#enddef

static void do_op(int nargs)
{
    struct c_frame *cf;
    struct c_proc *bp = opblks[curr_op];
    int i;
    quick_alc_c_frame(cf, bp, nargs);
    push_frame((struct frame *)cf);
    cf->lhs = get_dptr();
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    cf->rval = GetWord;
    cf->failure_label = GetAddr;
    Desc_EVValD(bp, E_Pcall, D_Proc);
    curr_cf = cf;
    if (!bp->ccode(cf))
        ipc = cf->failure_label;
    curr_cf = 0;
    /* Pop the C frame */
    k_current->sp = cf->parent_sp;
    quick_free_frame(cf);
}

static void do_mgop(int nargs)
{
    struct c_frame *cf;
    struct c_proc *bp = opblks[curr_op];
    int i;
    quick_alc_c_frame(cf, bp, nargs);
    push_frame((struct frame *)cf);
    cf->lhs = get_dptr();
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    cf->rval = GetWord;
    Desc_EVValD(bp, E_Pcall, D_Proc);
    curr_cf = cf;
    if (!bp->ccode(cf))
        syserr("Monogenic op failed");
    curr_cf = 0;
    /* Pop the C frame */
    k_current->sp = cf->parent_sp;
    quick_free_frame(cf);
}

static void do_opclo(int nargs)
{
    struct c_frame *cf;
    struct c_proc *bp = opblks[curr_op];
    int i;
    word clo;
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_frame((struct frame *)cf);
    cf->lhs = get_dptr();
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    cf->rval = GetWord;
    cf->failure_label = GetAddr;
    curr_pf->clo[clo] = (struct frame *)cf;
    tail_invoke_frame((struct frame *)cf);
}

static void do_keyop()
{
    struct c_frame *cf;
    struct c_proc *bp = keyblks[GetWord];
    quick_alc_c_frame(cf, bp, 0);
    push_frame((struct frame *)cf);
    cf->lhs = get_dptr();
    cf->failure_label = GetAddr;
    Desc_EVValD(bp, E_Pcall, D_Proc);
    curr_cf = cf;
    if (!bp->ccode(cf))
        ipc = cf->failure_label;
    curr_cf = 0;
    /* Pop the C frame */
    k_current->sp = cf->parent_sp;
    quick_free_frame(cf);
}

static void do_keyclo()
{
    struct c_frame *cf;
    struct c_proc *bp;
    word clo;
    bp = keyblks[GetWord];
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, 0));
    push_frame((struct frame *)cf);
    cf->lhs = get_dptr();
    cf->failure_label = GetAddr;
    curr_pf->clo[clo] = (struct frame *)cf;
    tail_invoke_frame((struct frame *)cf);
}

static void do_makelist()
{
    dptr dest = get_dptr();
    word argc = GetWord;
    int i;
    create_list(argc, dest);
    for (i = 0; i < argc; ++i) {
        tended struct descrip tmp;
        get_deref(&tmp);
        list_put(dest, &tmp);
    }
    EVValD(dest, E_Lcreate);
}

static void do_create()
{
    dptr lhs;
    word *start_label;
    tended struct b_coexpr *coex;
    lhs = get_dptr();
    start_label = GetAddr;
    MemProtect(coex = alccoexp());
    MemProtect(coex->base_pf = alc_p_frame(curr_pf->proc, curr_pf->fvars));
    coex->main_of = 0;
    coex->tvalloc = 0;
    coex->size = 0;
    coex->level = 1;
    coex->failure_label = coex->start_label = coex->base_pf->ipc = start_label;
    coex->curr_pf = coex->base_pf;
    coex->sp = (struct frame *)coex->base_pf;
    lhs->dword = D_Coexpr;
    BlkLoc(*lhs) = (union block *)coex;
    EVValD(lhs, E_Cocreate);
}

static void do_activate()
{
    dptr lhs;
    tended struct descrip arg1, arg2;
    word *failure_label;
    struct p_frame *pf;

    lhs = get_dptr();

    get_variable(&arg1);   /* Value */
    get_deref(&arg2);      /* Coexp */
    ipc++;                 /* rval */
    failure_label = GetAddr;
    if (!is:coexpr(arg2)) {
        xargp = &arg1;
        xexpr = &arg2;
        err_msg(118, &arg2);
        return;
    }
    pf = get_current_user_frame_of(&CoexprBlk(arg2));
    if (!pf) {
        xargp = &arg1;
        xexpr = &arg2;
        err_msg(138, &arg2);
        return;
    }

    if (pf->fvars != curr_pf->fvars)
        retderef(&arg1, curr_pf->fvars);

    EVValD(&arg2, E_Coact);

    if (k_trace) {
        --k_trace;
        trace_coact(k_current, &CoexprBlk(arg2), &arg1);
    }

    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Set the target's activator, switch to the target and set its transmitted value */
    CoexprBlk(arg2).activator = k_current;
    switch_to(&CoexprBlk(arg2));
    if (k_current->tvalloc)
        *k_current->tvalloc = arg1;
}

static void do_coret()
{
    tended struct descrip val;
    get_variable(&val);

    if (get_current_user_frame_of(k_current->activator)->fvars != curr_pf->fvars)
        retderef(&val, curr_pf->fvars);

    Desc_EVValD(k_current->activator, E_Coret, D_Coexpr);

    if (k_trace) {
        --k_trace;
        trace_coret(k_current, k_current->activator, &val);
    }

    /* If someone transmits failure to this coexpression, just act as though resumed */
    k_current->failure_label = ipc;

    /* Any transmitted value is discarded */
    k_current->tvalloc = 0;

    /* Increment the results counter */
    ++k_current->size;

    /* Switch to the target and set the transmitted value */
    switch_to(k_current->activator);
    if (k_current->tvalloc)
        *k_current->tvalloc = val;
}

static void do_cofail()
{
    Desc_EVValD(k_current->activator, E_Cofail, D_Coexpr);

    if (k_trace) {
        --k_trace;
        trace_cofail(k_current, k_current->activator);
    }

    /* If someone transmits failure to this coexpression, just act as though resumed */
    k_current->failure_label = ipc;

    /* Any transmitted value is discarded */
    k_current->tvalloc = 0;

    /* Switch to the target and jump to its failure label */
    switch_to(k_current->activator);
    ipc = k_current->failure_label;
}

static void coact_ex()
{
    dptr lhs, val, ce, activator, failto;
    word *failure_label;
    struct p_frame *upf;

    lhs = get_dptr();
    val = get_dptr();          /* Val */
    ce = get_dptr();           /* Coexp */
    activator = get_dptr();    /* Activator */
    failto = get_dptr();       /* Fail-to flag */
    failure_label = GetAddr;

    /* Dereference against the calling user frame, since val is potentially a variable
     * from that frame, rather than curr_pf
     */
    upf = get_current_user_frame();
    if (get_current_user_frame_of(&CoexprBlk(*ce))->fvars != upf->fvars)
        retderef(val, upf->fvars);

    if (curpstate->monitor) {
        if (is:null(*failto))
            EVValD(ce, E_Coact);
        else
            EVValD(ce, E_Cofail);
    }

    if (k_trace) {
        --k_trace;
        if (is:null(*failto))
            trace_coact(k_current, &CoexprBlk(*ce), val);
        else
            trace_cofail(k_current, &CoexprBlk(*ce));
    }

    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Perform the switch with the various option possibilities */
    if (!is:null(*activator))
        CoexprBlk(*ce).activator = &CoexprBlk(*activator);
    switch_to(&CoexprBlk(*ce));
    if (is:null(*failto)) {
        if (k_current->tvalloc)
            *k_current->tvalloc = *val;
    } else {
        ipc = k_current->failure_label;
    }
}

function coact(underef val, ce, activator, failto)
    body {
        struct p_frame *pf;

        /*
         * Target defaults to &source.
         */
        if (is:null(ce)) {
            ce.dword = D_Coexpr;
            BlkLoc(ce) = (union block *)k_current->activator;
        } else if (!is:coexpr(ce))
            runerr(118, ce);

        /*
         * As in all activations, the target must have a user pframe,
         * which it will have unless it's a freshly loaded (or exited)
         * prog.
         */
        if (!get_current_user_frame_of(&CoexprBlk(ce)))
            runerr(138, ce);

        if (is:null(activator)) {
            /* 
             * The target must already have an activator if we won't set it.
             */
            if (!CoexprBlk(ce).activator)
                runerr(137, ce);
        } else {
            if (!is:coexpr(activator))
                runerr(118, activator);
            /*
             * The activator must itself have an activator, since the target may return
             * to it.
             */
            if (!CoexprBlk(activator).activator)
                runerr(136, activator);
        }

        /*
         * If we're failing, the target must have a failure label.
         */
        if (!is:null(failto) && !CoexprBlk(ce).failure_label)
            runerr(135, ce);

        MemProtect(pf = alc_p_frame(&Bcoact_impl, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = val;
        pf->tmp[1] = ce;
        pf->tmp[2] = activator;
        pf->tmp[3] = failto;
        tail_invoke_frame((struct frame *)pf);
        return;
    }
end

/*
 * This operator allows the activation operation via string invocation.
 */

operator @ activate(underef val, ce)
    if !is:coexpr(ce) then
       runerr(118, ce)
    body {
        struct p_frame *pf;
        if (!get_current_user_frame_of(&CoexprBlk(ce)))
            runerr(138, ce);
        MemProtect(pf = alc_p_frame(&Bcoact_impl, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = val;
        pf->tmp[1] = ce;
        pf->tmp[2].dword = D_Coexpr;
        BlkLoc(pf->tmp[2]) = (union block *)k_current;
        tail_invoke_frame((struct frame *)pf);
        return;
    }
end

static void fatalerr_139()
{
    tended struct descrip d;
    d.dword = D_Coexpr;
    BlkLoc(d) = (union block *)k_current;
    fatalerr(139, &d);
}

static void coact_handler()
{
    word *failure_label;
    failure_label = GetAddr;

    if (curpstate->monitor)
        EVValD(&kywd_handler, E_Coact);

    if (k_trace) {
        --k_trace;
        trace_cofail_to_handler(k_current, &CoexprBlk(kywd_handler));
    }

    k_current->tvalloc = 0;
    k_current->failure_label = failure_label;

    /* The handler must have an activator, since we don't set it */
    if (!CoexprBlk(kywd_handler).activator)
        fatalerr(140, &kywd_handler);

    /* Fail to the handler coexpression */
    switch_to(&CoexprBlk(kywd_handler));
    ipc = k_current->failure_label;
}

void activate_handler(void)
{
    struct p_frame *pf;
    MemProtect(pf = alc_p_frame(&Bactivate_handler_impl, 0));
    push_frame((struct frame *)pf);
    tail_invoke_frame((struct frame *)pf);
}

static void do_limit()
{
    dptr limit;
    word tmp;

    limit = get_dptr();
    Deref(*limit);
    if (!cnv:C_integer(*limit, tmp)) {
        xargp = limit;
        err_msg(101, limit);
        return;
    }
    MakeInt(tmp, limit);
    if (tmp < 0) {
        xargp = limit;
        err_msg(205, limit);
        return;
    }
    EVValD(limit, E_Limit);
}

static void do_scansave()
{
    word s, p;
    tended struct descrip new_subject;
    get_deref(&new_subject);
    s = GetWord;
    p = GetWord;
    if (!cnv:string_or_ucs(new_subject, new_subject)) {
        xargp = &new_subject;
        err_msg(129, &new_subject);
        return;
    }
    curr_pf->tmp[s] = curpstate->Kywd_subject;
    curr_pf->tmp[p] = curpstate->Kywd_pos;
    curpstate->Kywd_subject = new_subject;
    MakeInt(1, &curpstate->Kywd_pos);
    EVValD(&new_subject, E_Scan);
}

void interp()
{
    for (;;) {
        if (curpstate->event_queue_head) {
            /* Switch to parent program */
            set_curpstate(curpstate->monitor);
        }
        curr_pf->curr_inst = ipc;
        curr_op = GetWord;
        /*printf("ipc=%p(%d) curr_op=%d (%s)\n", ipc,get_offset(ipc),(int)curr_op, op_names[curr_op]);fflush(stdout);*/
        switch (curr_op) {
            case Op_Goto: {
                word *w = GetAddr;
                ipc = w;
                break;
            }
            case Op_IGoto: {
                ipc = curr_pf->lab[*ipc]; 
                break;
            }
            case Op_Mark: {
                curr_pf->mark[GetWord] = k_current->sp;
                break;
            }
            case Op_Unmark: {
                pop_to(curr_pf->mark[GetWord]);
                break;
            }
            case Op_Move: {
                get_variable(get_dptr());
                break;
            }
            case Op_MoveLabel: {
                word i = GetWord;
                curr_pf->lab[i] = GetAddr;
                break;
            }

            /* Monogenic binary ops */
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
            case Op_Unions: {
                do_mgop(2);
                break;
            }

            /* Binary ops */
            case Op_Asgn:
            case Op_Eqv:
            case Op_Subsc:
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
            case Op_Swap: {
                do_op(2);
                break;
            }

            /* Monogenic unary ops */
            case Op_Value:
            case Op_Size:
            case Op_Refresh:
            case Op_Number:
            case Op_Compl:
            case Op_Neg: {
                do_mgop(1);
                break;
            }

            /* Unary ops */
            case Op_Nonnull:
            case Op_Random:
            case Op_Null: {
                do_op(1);
                break;
            }

            /* Unary closures */
            case Op_Tabmat:
            case Op_Bang: {
                do_opclo(1);
                break;
            }

            /* Binary closures */
            case Op_Rasgn:
            case Op_Rswap:{
                do_opclo(2);
                break;
            }

            case Op_Toby: {
                do_opclo(3);
                break;
            }

            case Op_Sect: {
                do_op(3);
                break;
            }

            case Op_Keyop: {
                do_keyop();
                break;
            }

            case Op_Keyclo: {
                do_keyclo();
                break;
            }

            case Op_Resume: {
                word clo;
                struct frame *f;
                clo = GetWord;
                f = curr_pf->clo[clo];
                if (f->exhausted) {
                    /* Just go to failure label and dispose of the frame */
                    ipc = f->failure_label;
                    pop_to(f->parent_sp);
                } else
                    tail_invoke_frame(f);
                break;
            }

            case Op_Pop: {
                struct p_frame *t = curr_pf;
                set_curr_pf(curr_pf->caller);
                pop_to(t->parent_sp);
                break;
            }

            case Op_PopRepeat: {
                struct p_frame *t = curr_pf;
                set_curr_pf(curr_pf->caller);
                pop_to(t->parent_sp);
                ipc = curr_pf->curr_inst;
                break;
            }

            /*
             * Act as though the parent C frame had returned the given value.
             */
            case Op_CReturn: {
                struct p_frame *t = curr_pf;
                /* Set the value in the C frame's lhs */
                if (t->parent_sp->lhs)
                    get_variable(t->parent_sp->lhs);
                else
                    skip_descrip();
                set_curr_pf(curr_pf->caller);
                /* Pop off this frame, leaving the C frame */
                pop_to(t->parent_sp);
                break;
            }

            /*
             * Act as though the parent C frame had suspended the given value.
             * This is just like returning, except we don't pop off the frame.
             */
            case Op_CSuspend: {
                struct p_frame *t = curr_pf;
                /* Set the value in the C frame's lhs */
                if (t->parent_sp->lhs)
                    get_variable(t->parent_sp->lhs);
                else
                    skip_descrip();
                set_curr_pf(curr_pf->caller);
                break;
            }

            /*
             * Act as though the parent C frame had failed.
             */
            case Op_CFail: {
                struct p_frame *t = curr_pf;
                set_curr_pf(curr_pf->caller);
                /* Goto the failure_label stored in the C frame */
                ipc = t->parent_sp->failure_label;
                /* Pop off this frame AND the parent C frame */
                pop_to(t->parent_sp->parent_sp);
                break;
            }

            case Op_Fail: {
                struct p_frame *t = curr_pf;
                Desc_EVValD(t->proc, E_Pfail, D_Proc);
                if (curr_pf->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        fail_trace(curr_pf);
                    }
                }
                set_curr_pf(curr_pf->caller);
                ipc = t->failure_label;
                pop_to(t->parent_sp);
                break;
            }

            case Op_Suspend: {
                tended struct descrip tmp;
                Desc_EVValD(curr_pf->proc, E_Psusp, D_Proc);
                get_variable(&tmp);
                retderef(&tmp, curr_pf->fvars);
                if (curr_pf->lhs)
                    *curr_pf->lhs = tmp;
                if (curr_pf->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        suspend_trace(curr_pf, &tmp);
                    }
                }
                set_curr_pf(curr_pf->caller);
                break;
            }

            case Op_Return: {
                tended struct descrip tmp;
                Desc_EVValD(curr_pf->proc, E_Pret, D_Proc);
                get_variable(&tmp);
                retderef(&tmp, curr_pf->fvars);
                if (curr_pf->lhs)
                    *curr_pf->lhs = tmp;
                curr_pf->exhausted = 1;
                if (curr_pf->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        return_trace(curr_pf, &tmp);
                    }
                }
                /* Pop any frames below the returning procedure frame */
                pop_to((struct frame *)curr_pf);
                set_curr_pf(curr_pf->caller);
                break;
            }

            case Op_ScanSwap: {
                word s, p;
                struct descrip tmp;
                s = GetWord;
                p = GetWord;
                tmp = curpstate->Kywd_subject;
                curpstate->Kywd_subject = curr_pf->tmp[s];
                curr_pf->tmp[s] = tmp;
                tmp = curpstate->Kywd_pos;
                curpstate->Kywd_pos = curr_pf->tmp[p];
                curr_pf->tmp[p] = tmp;
                break;
            }

            case Op_ScanRestore: {
                word s, p;
                s = GetWord;
                p = GetWord;
                curpstate->Kywd_subject = curr_pf->tmp[s];
                curpstate->Kywd_pos = curr_pf->tmp[p];
                break;
            }

            case Op_ScanSave: {
                do_scansave();
                break;
            }

            case Op_Limit: {
                do_limit();
                break;
            }

            case Op_Invoke: {
                do_invoke();
                break;
            }

            case Op_Apply: {
                do_apply();
                break;
            }

            case Op_Invokef: {
                do_invokef();
                break;
            }

            case Op_Applyf: {
                do_applyf();
                break;
            }

            case Op_EnterInit: {
                ++ipc;
                /* Change Op_EnterInit to an Op_Goto */
                ipc[-2] = Op_Goto;
                break;
            }

            case Op_Custom: {
                word w = GetWord;
                void (*ccode)(void) = (void (*)(void))w;
	        ccode();
                break;
            }

            case Op_Halt: {
                showcurrstack();
                fprintf(stderr, "Halt instruction reached\n");
                exit(1);
            }

            case Op_SysErr: {
                showcurrstack();
                syserr("Op_SysErr instruction reached");
                break; /* Not reached */
            }

            case Op_MakeList: {
                do_makelist();
                break;
            }

            case Op_Field: {
                do_field();
                break;
            }

            case Op_Create: {
                do_create();
                break;
            }

            case Op_Activate: {
                do_activate();
                break;
            }

            case Op_Coret: {
                do_coret();
                break;
            }

            case Op_Cofail: {
                do_cofail();
                break;
            }

            case Op_Exit: {
                /* The main procedure has returned/failed */
                return;
            }

            default: {
                syserr("Unimplemented opcode %d (%s)\n", (int)curr_op, op_names[curr_op]);
                break; /* Not reached */
            }
        }
    }
}

static void activate_child_prog()
{
    dptr ce = get_dptr();
    struct progstate *prog = CoexprBlk(*ce).main_of;
    prog->monitor = curpstate;
    set_curpstate(prog);
}

static void pop_from_prog_event_queue(struct progstate *prog, dptr res)
{
    ObjectBlk(*res).fields[0] = prog->event_queue_head->eventcode;
    ObjectBlk(*res).fields[1] = prog->event_queue_head->eventval;
    Deref(ObjectBlk(*res).fields[1]);
    if (prog->event_queue_head == prog->event_queue_tail) {
        free(prog->event_queue_head);
        prog->event_queue_head = prog->event_queue_tail = 0;
    } else {
        struct prog_event *t = prog->event_queue_head;
        prog->event_queue_head = prog->event_queue_head->next;
        free(t);
    }
}

static void get_child_prog_result()
{
    struct progstate *prog;
    dptr ce = get_dptr();
    dptr res = get_dptr();
    word *failure_label = GetAddr;

    prog = CoexprBlk(*ce).main_of;
    prog->monitor = 0;
    if (prog->exited) {
       ipc = failure_label;
       return;
    }
    if (!prog->event_queue_head)
        syserr("Expected a prog event in the queue");

    pop_from_prog_event_queue(prog, res);
}

function lang_Prog_get_event_impl(c, res)
   if !is:coexpr(c) then
      runerr(118,c)
   body {
       struct progstate *prog = CoexprBlk(c).main_of;
       struct p_frame *pf;
       if (!prog)
           runerr(632, c);
       if (prog == curpstate || prog->monitor)
           runerr(633, c);
       if (prog->event_queue_head) {
           pop_from_prog_event_queue(prog, &res);
           return res;
       }
       if (prog->exited)
           fail;
       MemProtect(pf = alc_p_frame(&Blang_Prog_get_event_impl_impl, 0));
       push_frame((struct frame *)pf);
       pf->tmp[0] = c;
       pf->tmp[1] = res;
       tail_invoke_frame((struct frame *)pf);
       return;
   }
end

void add_to_prog_event_queue(dptr value, int event)
{
    struct prog_event *e;
    /* Do nothing if no-one is monitoring this program */
    if (!curpstate->monitor)
        return;
    MemProtect(e = malloc(sizeof(struct prog_event)));
    if (curpstate->event_queue_tail) {
        curpstate->event_queue_tail->next = e;
        curpstate->event_queue_tail = e;
    } else
        curpstate->event_queue_head = curpstate->event_queue_tail = e;
    StrLen(e->eventcode) = 1;
    StrLoc(e->eventcode) = &allchars[event & 0xFF];
    e->eventval = *value;
    e->next = 0;
}
