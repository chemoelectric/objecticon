#include "../h/opdefs.h"
#include "../h/opnames.h"

static void coact_ex();
static void get_child_prog_result();
static void activate_child_prog();
static void do_cofail();
static void do_coact();

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
    Desc_EVValD(f->proc, E_Pcall, D_Proc);
    switch (f->type) {
        case C_FRAME_TYPE: {
            curr_cf = (struct c_frame *)f;
            if (!f->proc->ccode(f)) {
                ipc = f->failure_label;
                pop_to(f->parent_sp);
            }
            curr_cf = 0;
            break;
        }
        case P_FRAME_TYPE: {
            struct p_frame *pf = (struct p_frame *)f;
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
    word *code_start = curr_pf->proc->program ? 
        (word *)curr_pf->proc->program->Code : curr_pf->proc->icode;
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
        case Op_Closure: {
            return &curr_pf->clo[GetWord]->value;
        }

        default: {
            syserr("Invalid opcode in get_dptr: %d (%s)\n", op, op_names[op]);
            return 0;
        }
    }
}

/*
 * Get a copy of a descriptor without any alteration to it (no dereferencing or
 * making of variables).
 */
void get_descrip(dptr dest)
{
    word op = GetWord;
    switch (op) {
        case Op_Int: {
            MakeInt(GetWord, dest);
            break;
        }
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
            *dest = curr_pf->tmp[GetWord];
            break;
        }
        case Op_Closure: {
            *dest = curr_pf->clo[GetWord]->value;
            break;
        }

        default: {
            syserr("Invalid opcode in get_descrip: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Like get_descrip, but dereference temporary and closure descriptors
 * (dynamics/args/statics/globals should already be dereferenced).
 */
void get_deref(dptr dest)
{
    word op = GetWord;
    switch (op) {
        case Op_Int: {
            MakeInt(GetWord, dest);
            break;
        }
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
        case Op_Closure: {
            deref(&curr_pf->clo[GetWord]->value, dest);
            break;
        }

        default: {
            syserr("Invalid opcode in get_descrip: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Like get_descrip, but for statics, args, dynamics and globals, rather than
 * copy the descriptor, make a named variable pointer to it instead.
 */
void get_variable(dptr dest)
{
    word op = GetWord;
    switch (op) {
        case Op_Int: {
            MakeInt(GetWord, dest);
            break;
        }
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
        case Op_Closure: {
            *dest = curr_pf->clo[GetWord]->value;
            break;
        }

        default: {
            syserr("Invalid opcode in get_variable: %d (%s)\n", op, op_names[op]);
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
    p->type = C_FRAME_TYPE;
    p->value = nulldesc;
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
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp = opblks[curr_op];
    int i;
    lhs = get_dptr();
    quick_alc_c_frame(cf, bp, nargs);
    push_frame((struct frame *)cf);
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
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        ipc = cf->failure_label;
    curr_cf = 0;
    /* Pop the C frame */
    k_current->sp = cf->parent_sp;
    quick_free_frame(cf);
}

static void do_opclo(int nargs)
{
    struct c_frame *cf;
    struct b_proc *bp = opblks[curr_op];
    int i;
    word clo;
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_frame((struct frame *)cf);
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
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp = keyblks[GetWord];
    lhs = get_dptr();
    quick_alc_c_frame(cf, bp, 0);
    push_frame((struct frame *)cf);
    cf->failure_label = GetAddr;
    Desc_EVValD(bp, E_Pcall, D_Proc);
    curr_cf = cf;
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        ipc = cf->failure_label;
    curr_cf = 0;
    /* Pop the C frame */
    k_current->sp = cf->parent_sp;
    quick_free_frame(cf);
}

static void do_keyclo()
{
    struct c_frame *cf;
    struct b_proc *bp;
    word clo;
    bp = keyblks[GetWord];
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, 0));
    push_frame((struct frame *)cf);
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

static void do_coact()
{
    dptr lhs;
    tended struct descrip arg1, arg2;
    word *failure_label;

    lhs = get_dptr();

    get_descrip(&arg1);   /* Value */
    get_deref(&arg2);     /* Coexp */
    failure_label = GetAddr;
    if (!is:coexpr(arg2)) {
        xargp = &arg1;
        xexpr = &arg2;
        err_msg(118, &arg2);
        ipc = failure_label;
        return;
    }

    if (get_current_user_frame_of(&CoexprBlk(arg2))->fvars != curr_pf->fvars)
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
    get_descrip(&val);

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
    dptr lhs;
    tended struct descrip arg1, arg2, arg3, arg4;
    word *failure_label;

    lhs = get_dptr();
    get_descrip(&arg1);   /* Value */
    get_deref(&arg2);     /* Coexp */
    get_deref(&arg3);     /* Activator */
    get_deref(&arg4);     /* Fail-to flag */
    failure_label = GetAddr;

    if (get_current_user_frame_of(&CoexprBlk(arg2))->fvars != curr_pf->fvars)
        retderef(&arg1, curr_pf->fvars);

    if (curpstate->monitor) {
        if (is:null(arg4))
            EVValD(&arg2, E_Coact);
        else
            EVValD(&arg2, E_Cofail);
    }

    if (k_trace) {
        --k_trace;
        if (is:null(arg4))
            trace_coact(k_current, &CoexprBlk(arg2), &arg1);
        else
            trace_cofail(k_current, &CoexprBlk(arg2));
    }

    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Perform the switch with the various option possibilities */
    if (!is:null(arg3))
        CoexprBlk(arg2).activator = &CoexprBlk(arg3);
    switch_to(&CoexprBlk(arg2));
    if (is:null(arg4)) {
        if (k_current->tvalloc)
            *k_current->tvalloc = arg1;
    } else {
        ipc = k_current->failure_label;
    }
}

function coact(val, ce, activator, failto)
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

        MemProtect(pf = alc_p_frame((struct b_proc *)&Bcoact_impl, 0));
        push_frame((struct frame *)pf);
        pf->fvars->desc[0] = val;
        pf->fvars->desc[1] = ce;
        pf->fvars->desc[2] = activator;
        pf->fvars->desc[3] = failto;
        tail_invoke_frame((struct frame *)pf);
        return nulldesc;
    }
end

/*
 * These two operators allow binary and unary activation operations via
 * string invocation.
 */

operator @ bactivate(val, ce)
    if !is:coexpr(ce) then
       runerr(118, ce)
    body {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame((struct b_proc *)&Bactivate_impl, 0));
        push_frame((struct frame *)pf);
        pf->fvars->desc[0] = val;
        pf->fvars->desc[1] = ce;
        tail_invoke_frame((struct frame *)pf);
        return nulldesc;
    }
end

operator @ uactivate(ce)
    if !is:coexpr(ce) then
       runerr(118, ce)
    body {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame((struct b_proc *)&Bactivate_impl, 0));
        push_frame((struct frame *)pf);
        pf->fvars->desc[0] = nulldesc;
        pf->fvars->desc[1] = ce;
        tail_invoke_frame((struct frame *)pf);
        return nulldesc;
    }
end

static void do_limit()
{
    dptr limit;
    word *failure_label;
    word tmp;

    limit = get_dptr();
    Deref(*limit);
    failure_label = GetAddr;
    if (!cnv:C_integer(*limit, tmp)) {
        xargp = limit;
        err_msg(101, limit);
        ipc = failure_label;
        return;
    }
    MakeInt(tmp, limit);
    if (tmp < 0) {
        xargp = limit;
        err_msg(205, limit);
        ipc = failure_label;
        return;
    }
}

static void do_scansave()
{
    word s, p;
    tended struct descrip new_subject;
    word *failure_label;
    get_deref(&new_subject);
    s = GetWord;
    p = GetWord;
    failure_label = GetAddr;
    if (!cnv:string_or_ucs(new_subject, new_subject)) {
        xargp = &new_subject;
        err_msg(129, &new_subject);
        ipc = failure_label;
        return;
    }
    curr_pf->tmp[s] = curpstate->Kywd_subject;
    curr_pf->tmp[p] = curpstate->Kywd_pos;
    curpstate->Kywd_subject = new_subject;
    MakeInt(1, &curpstate->Kywd_pos);
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
                get_descrip(get_dptr());
                break;
            }
            case Op_MoveVar: {
                get_variable(get_dptr());
                break;
            }
            case Op_MoveLabel: {
                word i = GetWord;
                curr_pf->lab[i] = GetAddr;
                break;
            }

            /* Binary ops */
            case Op_Asgn:
            case Op_Power:
            case Op_Cat:
            case Op_Diff:
            case Op_Eqv:
            case Op_Inter:
            case Op_Subsc:
            case Op_Lconcat:
            case Op_Lexeq:
            case Op_Lexge:
            case Op_Lexgt:
            case Op_Lexle:
            case Op_Lexlt:
            case Op_Lexne:
            case Op_Minus:
            case Op_Mod:
            case Op_Neqv:
            case Op_Numeq:
            case Op_Numge:
            case Op_Numgt:
            case Op_Numle:
            case Op_Numlt:
            case Op_Numne:
            case Op_Plus:
            case Op_Div:
            case Op_Mult:
            case Op_Swap:
            case Op_Unions: {
                do_op(2);
                break;
            }

            /* Unary ops */
            case Op_Value:
            case Op_Nonnull:
            case Op_Refresh:
            case Op_Number:
            case Op_Compl:
            case Op_Neg:
            case Op_Size:
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
                f->failure_label = GetAddr;
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
                /* Set the value in the C frame */
                get_descrip(&t->parent_sp->value);
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
                /* Set the value in the C frame */
                get_descrip(&t->parent_sp->value);
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
                Desc_EVValD(curr_pf->proc, E_Psusp, D_Proc);
                get_descrip(&curr_pf->value);
                retderef(&curr_pf->value, curr_pf->fvars);
                if (curr_pf->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        suspend_trace(curr_pf);
                    }
                }
                set_curr_pf(curr_pf->caller);
                break;
            }

            case Op_Return: {
                Desc_EVValD(curr_pf->proc, E_Pret, D_Proc);
                get_descrip(&curr_pf->value);
                retderef(&curr_pf->value, curr_pf->fvars);
                curr_pf->exhausted = 1;
                if (curr_pf->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        return_trace(curr_pf);
                    }
                }
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
                int (*ccode)() = (int (*)())w;
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

            case Op_Coact: {
                do_coact();
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
       MemProtect(pf = alc_p_frame((struct b_proc *)&Blang_Prog_get_event_impl_impl, 0));
       push_frame((struct frame *)pf);
       pf->fvars->desc[0] = c;
       pf->fvars->desc[1] = res;
       tail_invoke_frame((struct frame *)pf);
       return nulldesc;
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
