#include "../h/opdefs.h"
#include "../h/opnames.h"

static void coact_ex(void);
static void cofail_ex(void);
static void coact_handler(void);
static void get_child_prog_result(void);
static void activate_child_prog(void);
static void do_cofail(void);
static void do_activate(void);
static void do_opclo(int nargs);
static void do_keyop(void);
static void do_keyclo(void);
static void do_makelist(void);
static void do_create(void);
static void do_coret(void);
static void do_limit(void);
static void do_scansave(void);
static void do_tcaseinit2(void);
static void do_tcaseinsert(void);
static void do_tcasechoose2(void);
static void do_tcaseinit1(void);
static void do_tcasechoose1(void);
static void pop_from_prog_event_queue(struct progstate *prog, dptr res);
static void fatalerr_139(void);
static void check_timer(void);
static void check_location(void);


#include "interpiasm.ri"

word curr_op;  /* Last op read in interpreter loop */

struct b_coexpr *k_current;        /* Always == curpstate->K_current */
struct p_frame *curr_pf;           /* Always == curpstate->K_current->curr_pf */
word *ipc;                         /* Notionally curpstate->K_current->curr_pf->ipc, synchronized whenever
                                    * curr_pf is changed */
struct c_frame *curr_cf;           /* currently executing c frame */

/*
 * An invariant should also be maintained in the interpreter loop (but
 * not necessarily in a native C method) :-
 * 
 *       curpstate == get_current_program_of(k_current)
 * This is maintained by set_curpstate, switch_to and set_curr_pf below.
 */

void synch_ipc()
{
    curr_pf->ipc = ipc;
}

/*
 * Switch programs; this is called to switch during program monitoring.
 */
void set_curpstate(struct progstate *p)
{
    if (get_current_program_of(p->K_current) != p)
        fatalerr(636, NULL);
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
    k_current->failure_label = 0;
}

/*
 * Like switch_to, but jump to the coexpression's failure label.
 */
void fail_to(struct b_coexpr *ce)
{
    curr_pf->ipc = ipc;
    curpstate = get_current_program_of(ce);
    k_current = curpstate->K_current = ce;
    curr_pf = k_current->curr_pf;
    ipc = k_current->failure_label;
    k_current->failure_label = 0;
}

/*
 * Change the current p_frame to a new value.
 */
void set_curr_pf(struct p_frame *pf)
{
    struct progstate *p = pf->proc->program;
    if (!p) 
        p = pf->creator;
    curr_pf->ipc = ipc;
    /* Check whether we are changing to a different program. */
    if (p != curpstate) {
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
            int rc;
            struct progstate *p, *q;
            struct class_field *field;
            curr_cf = (struct c_frame *)f;
            field = curr_cf->proc->field;
            /*
             * A native method should run with curpstate set to its
             * enclosing class's defining program.
             */
            p = field ? field->defining_class->program : curpstate;
            Desc_EVValD(curr_cf->proc, E_Pcall, D_Proc);
            if (field && k_trace) {
                /*
                 * Same logic as below, but with tracing.
                 */   
                struct p_frame *old_curr_pf = curr_pf;
                k_trace--;
                c_call_trace(curr_cf);
                if (p == curpstate)
                    rc = curr_cf->proc->ccode(curr_cf);
                else {
                    q = curpstate;
                    p->K_current = k_current;
                    curpstate = p;
                    rc = curr_cf->proc->ccode(curr_cf);
                    if (curr_pf == old_curr_pf) {
                        if (q->K_current != k_current) syserr("C code changed k_current");
                        curpstate = q;
                    }
                }
                if (rc) {
                    /*
                     * If curr_pf != old_curr_pf, then the c function
                     * has pushed a frame, called tail_invoke_frame,
                     * and returned.  So we don't output the return
                     * value here; that is done when we get a
                     * Op_C[Return/Suspend/Fail].
                     */
                    if (k_trace && curr_pf == old_curr_pf) {
                        k_trace--;
                        c_return_trace(curr_cf);
                    }
                } else {
                    if (k_trace) {
                        k_trace--;
                        c_fail_trace(curr_cf);
                    }
                    ipc = f->failure_label;
                    pop_to(f->parent_sp);
                }
            } else {
                if (p == curpstate)
                    rc = curr_cf->proc->ccode(curr_cf);
                else {
                    struct p_frame *old_curr_pf = curr_pf;
                    q = curpstate;
                    p->K_current = k_current;
                    curpstate = p;
                    rc = curr_cf->proc->ccode(curr_cf);
                    /*
                     * If curr_pf != old_curr_pf, then the c function
                     * has pushed a frame, called tail_invoke_frame,
                     * and returned.  So we stay in procstate p while the
                     * pushed frame runs.  We return to procstate q when
                     * Op_C[Return/Suspend/Fail] calls set_curr_pf.
                     */
                    if (curr_pf == old_curr_pf) {
                        if (q->K_current != k_current) syserr("C code changed k_current");
                        curpstate = q;
                    }
                }
                if (!rc) {
                    ipc = f->failure_label;
                    pop_to(f->parent_sp);
                }
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
                 * If tracing is on, generate a message.
                 */   
                if (k_trace) {
                    k_trace--;
                    call_trace(pf);
                }
                if (++k_level > k_maxlevel) {
                    struct descrip t;
                    /* Some info for ttrace... */
                    curr_op = Op_Invoke;
                    MakeDesc(D_Proc, pf->proc, &t);
                    xexpr = &t;
                    err_msg(311, NULL);
                    break;
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
            syserr("Invalid opcode in get_dptr: %d (%s)", op, op_names[op]);
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
#if RealInDesc
        case Op_Real: {
            MakeReal(GetReal, dest);
            break;
        }
#endif
        case Op_Knull: {
            *dest = nulldesc;
            break;
        }
        case Op_Kyes: {
            *dest = yesdesc;
            break;
        }
        case Op_Const:
        case Op_Static:
        case Op_GlobalVal:
        case Op_Global: {
            *dest = *(dptr)GetAddr;
            break;
        }
        case Op_FrameVar: {
            *dest = curr_pf->fvars->desc[GetWord];
            break;
        }
        case Op_Self: {
            *dest = curr_pf->fvars->desc[0];
            break;
        }
        case Op_Tmp: {
            deref(&curr_pf->tmp[GetWord], dest);
            break;
        }

        default: {
            syserr("Invalid opcode in get_deref: %d (%s)", op, op_names[op]);
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
#if RealInDesc
        case Op_Real: {
            MakeReal(GetReal, dest);
            break;
        }
#endif
        case Op_Knull: {
            *dest = nulldesc;
            break;
        }
        case Op_Kyes: {
            *dest = yesdesc;
            break;
        }
        case Op_GlobalVal:
        case Op_Const: {
            *dest = *(dptr)GetAddr;
            break;
        }
        case Op_Static:
        case Op_Global: {
            MakeVarDesc(D_NamedVar, (dptr)GetAddr, dest);
            break;
        }
        case Op_FrameVar: {
            MakeVarDesc(D_NamedVar, &curr_pf->fvars->desc[GetWord], dest);
            break;
        }
        case Op_Self: {
            *dest = curr_pf->fvars->desc[0];
            break;
        }
        case Op_Tmp: {
            *dest = curr_pf->tmp[GetWord];
            break;
        }

        default: {
            syserr("Invalid opcode in get_variable: %d (%s)", op, op_names[op]);
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
        case Op_GlobalVal:
        case Op_Global:
        case Op_Int:
#if RealInDesc
        case Op_Real:
#endif
        case Op_FrameVar:
        case Op_Tmp: {
            ipc++;
            break;
        }
        case Op_Self:
        case Op_Kyes:
        case Op_Knull: {
            break;
        }
        default: {
            syserr("Invalid opcode in skip_descrip: %d (%s)", op, op_names[op]);
        }
    }
}

void do_key_features(void) { syserr("Dummy func"); }

#define KDef(p,n) do_key_##p,
void (*keyword_qfuncs[])(void) = {
    NULL,
#include "../h/kdefs.h"
};
#undef KDef

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
    void (*f)(void) = keyword_qfuncs[GetWord];
    f();
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
    tended struct descrip tmp;
    if (dest) {
        create_list(argc, dest);
        for (i = 0; i < argc; ++i) {
            get_deref(&tmp);
            list_put(dest, &tmp);
        }
        EVValD(dest, E_Lcreate);
    } else {
        for (i = 0; i < argc; ++i)
            get_deref(&tmp);
    }
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
    coex->level = 1;
    coex->failure_label = coex->start_label = coex->base_pf->ipc = start_label;
    coex->curr_pf = coex->base_pf;
    coex->sp = (struct frame *)coex->base_pf;
    MakeDesc(D_Coexpr, coex, lhs);
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
    failure_label = GetAddr;
    if (!is:coexpr(arg2)) {
        xarg1 = &arg1;
        xarg2 = &arg2;
        err_msg(118, &arg2);
        return;
    }
    pf = get_current_user_frame_of(&CoexprBlk(arg2));
    if (!pf) {
        xarg1 = &arg1;
        xarg2 = &arg2;
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
    fail_to(k_current->activator);
}

static void coact_ex()
{
    dptr lhs, val, ce, activator;
    word *failure_label;
    struct p_frame *upf;

    lhs = get_dptr();
    val = get_dptr();          /* Val */
    ce = get_dptr();           /* Coexp */
    activator = get_dptr();    /* Activator */
    failure_label = GetAddr;

    /* Dereference against the calling user frame, since val is potentially a variable
     * from that frame, rather than curr_pf
     */
    upf = get_current_user_frame();
    if (get_current_user_frame_of(&CoexprBlk(*ce))->fvars != upf->fvars)
        retderef(val, upf->fvars);

    EVValD(ce, E_Coact);

    if (k_trace) {
        --k_trace;
        trace_coact(k_current, &CoexprBlk(*ce), val);
    }

    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Perform the switch with the various option possibilities */
    if (!is:null(*activator))
        CoexprBlk(*ce).activator = &CoexprBlk(*activator);
    switch_to(&CoexprBlk(*ce));
    if (k_current->tvalloc)
        *k_current->tvalloc = *val;
}

function coact(underef val, ce, activator)
    body {
        struct p_frame *pf;

        /*
         * Target defaults to &source.
         */
        if (is:null(ce)) {
            MakeDesc(D_Coexpr, k_current->activator, &ce);
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

        MemProtect(pf = alc_p_frame(&Bcoact_impl, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = val;
        pf->tmp[1] = ce;
        pf->tmp[2] = activator;
        tail_invoke_frame((struct frame *)pf);
        return;
    }
end

static void cofail_ex()
{
    dptr lhs, ce, activator;
    word *failure_label;

    lhs = get_dptr();
    ce = get_dptr();           /* Coexp */
    activator = get_dptr();    /* Activator */
    failure_label = GetAddr;

    EVValD(ce, E_Cofail);

    if (k_trace) {
        --k_trace;
        trace_cofail(k_current, &CoexprBlk(*ce));
    }

    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Perform the switch with the various option possibilities */
    if (!is:null(*activator))
        CoexprBlk(*ce).activator = &CoexprBlk(*activator);
    fail_to(&CoexprBlk(*ce));
}

function cofail(ce, activator)
    body {
        struct p_frame *pf;

        /*
         * Target defaults to &source.
         */
        if (is:null(ce)) {
            MakeDesc(D_Coexpr, k_current->activator, &ce);
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
         * As we're failing, the target must have a failure label.
         */
        if (!CoexprBlk(ce).failure_label)
            runerr(135, ce);

        MemProtect(pf = alc_p_frame(&Bcofail_impl, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = ce;
        pf->tmp[1] = activator;
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
        MakeDesc(D_Coexpr, k_current, &pf->tmp[2]);
        tail_invoke_frame((struct frame *)pf);
        return;
    }
end

static void fatalerr_139()
{
    tended struct descrip d;
    MakeDesc(D_Coexpr, k_current, &d);
    fatalerr(139, &d);
}

static void coact_handler()
{
    EVValD(&kywd_handler, E_Coact);

    if (k_trace) {
        --k_trace;
        trace_cofail_to_handler(k_current, &CoexprBlk(kywd_handler));
    }

    k_current->tvalloc = 0;
    /* If someone transmits failure to this coexpression, just act as though resumed */
    k_current->failure_label = ipc;

    /* The handler must have an activator, since we don't set it */
    if (!CoexprBlk(kywd_handler).activator) {
        tended struct descrip d;
        /* Use a copy since fatalerr sets kywd_handler to nulldesc. */
        d = kywd_handler;
        fatalerr(140, &d);
    }

    /* Fail to the handler coexpression */
    fail_to(&CoexprBlk(kywd_handler));
}

void activate_handler(void)
{
    struct p_frame *pf;
    MemProtect(pf = alc_p_frame(&Bactivate_handler_impl, 0));
    push_frame((struct frame *)pf);
    tail_invoke_frame((struct frame *)pf);
}

void push_fatalerr_139_frame(void)
{
    struct p_frame *pf;
    MemProtect(pf = alc_p_frame(&Bcall_fatalerr_139, 0));
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
        xarg1 = limit;
        err_msg(101, limit);
        return;
    }
    MakeInt(tmp, limit);
    if (tmp < 0) {
        xarg1 = limit;
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
        xarg1 = &new_subject;
        err_msg(129, &new_subject);
        return;
    }
    curr_pf->tmp[s] = curpstate->Kywd_subject;
    curr_pf->tmp[p] = curpstate->Kywd_pos;
    curpstate->Kywd_subject = new_subject;
    MakeInt(1, &curpstate->Kywd_pos);
    EVValD(&new_subject, E_Scan);
}

static void do_tcaseinit2(void)
{
    dptr tbl = (dptr)GetAddr;
    word d = GetWord;
    create_table(0, d, tbl);
    MakeInt(d, &TableBlk(*tbl).defvalue);
}

static void do_tcaseinsert(void)
{
    tended struct descrip val;
    dptr tbl = (dptr)GetAddr;
    struct descrip entry;
    get_deref(&val);
    /*
     * The next word is an address or an offset, depending on whether
     * this is a tcaseinsert1 or tcaseinsert2 instruction.
     */
    MakeInt(GetWord, &entry);
    table_insert(tbl, &val, &entry, 0);
}

static void do_tcasechoose2(void)
{
    tended struct descrip val;
    uword hn;
    word off, labno;
    int res;
    union block **dp1;
    dptr tbl = (dptr)GetAddr;
    get_deref(&val);
    labno = GetWord;
    ++ipc;            /* tblc */
    hn = hash(&val);
    dp1 = memb(BlkLoc(*tbl), &val, hn, &res);
    if (res)
        off = IntVal((*dp1)->telem.tval);
    else
        off = IntVal(TableBlk(*tbl).defvalue);
    curr_pf->lab[labno] = (word *)ipc[2 * off + 1];
    ipc = (word *)ipc[2 * off];
}

static void do_tcaseinit1(void)
{
    dptr tbl = (dptr)GetAddr;
    word size = GetWord;
    word d = GetWord;   /* An address */
    create_table(0, size, tbl);
    MakeInt(d, &TableBlk(*tbl).defvalue);
}

static void do_tcasechoose1(void)
{
    tended struct descrip val;
    uword hn;
    int res;
    union block **dp1;
    dptr tbl = (dptr)GetAddr;
    get_deref(&val);
    ++ipc;            /* tblc */
    hn = hash(&val);
    dp1 = memb(BlkLoc(*tbl), &val, hn, &res);
    if (res)
        ipc = (word *)IntVal((*dp1)->telem.tval);
    else
        ipc = (word *)IntVal(TableBlk(*tbl).defvalue);
}

static void check_timer(void)
{
    static int check_count;
    if (Testb(E_Timer, curpstate->eventmask->bits)) {
        struct timeval tp;
        if (++check_count < 100)
            return;
        check_count = 0;
        if (gettimeofday(&tp, 0) == 0) {
            word diff;
            diff = 1000 * (tp.tv_sec - curpstate->last_tick.tv_sec) +
                (tp.tv_usec - curpstate->last_tick.tv_usec) / 1000;
            if (diff >= curpstate->timer_interval) {
                add_to_prog_event_queue(&nulldesc, E_Timer);
                curpstate->last_tick = tp;
            }
        }
    }
}

static void check_location(void)
{
    if (InRange(curpstate->Code, ipc, curpstate->Ecode)) {
        if (Testb(E_File, curpstate->eventmask->bits) &&
            (!curpstate->Current_fname_ptr ||
             ipc < curpstate->Current_fname_ptr->ipc ||
             (curpstate->Current_fname_ptr + 1 < curpstate->Efilenms &&
              ipc >= (curpstate->Current_fname_ptr + 1)->ipc)))
        {
            /* 
             * We remember not only the last ipc_fname, but also the
             * string it pointed to, since the ipc_fname can change to
             * another one with an identical string.
             */
            curpstate->Current_fname_ptr = find_ipc_fname(ipc, curpstate);
            if (curpstate->Current_fname_ptr &&
                curpstate->Current_fname_ptr->fname != curpstate->Current_fname)
            {
                curpstate->Current_fname = curpstate->Current_fname_ptr->fname;
                add_to_prog_event_queue(curpstate->Current_fname, E_File);
            }
        }

        if (Testb(E_Line, curpstate->eventmask->bits) &&
            (!curpstate->Current_line_ptr ||
                ipc < curpstate->Current_line_ptr->ipc ||
             (curpstate->Current_line_ptr + 1 < curpstate->Elines &&
              ipc >= (curpstate->Current_line_ptr + 1)->ipc)))
        {
            curpstate->Current_line_ptr = find_ipc_line(ipc, curpstate);
            if (curpstate->Current_line_ptr) {
                struct descrip v;
                MakeInt(curpstate->Current_line_ptr->line, &v);
                add_to_prog_event_queue(&v, E_Line);
            }
        }
    }
}

void interp()
{
    for (;;) {
        /*
         * Set curr_inst before doing the monitor checks; this works
         * better with traceback, &line etc when used in conjunction
         * with Pcall, Line, File events and so on (in particular, a
         * new p_frame that's just been pushed, curr_inst would be 0).
         */
        curr_pf->curr_inst = ipc;

        if (curpstate->monitor) {
            check_timer();
            check_location();
            if (curpstate->event_queue_head) {
                /* Switch to parent program */
                set_curpstate(curpstate->monitor);
            }
        }

        curr_op = GetWord;
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
            case Op_Deref: {
                get_deref(get_dptr());
                break;
            }
            case Op_MoveLabel: {
                word i = GetWord;
                curr_pf->lab[i] = GetAddr;
                break;
            }

            /* Monogenic binary ops */
            case Op_Cat: {
                do_op_cat();
                break;
            }
            case Op_Diff: {
                do_op_diff();
                break;
            }
            case Op_Div: {
                do_op_div();
                break;
            }
            case Op_Inter: {
                do_op_inter();
                break;
            }
            case Op_Lconcat: {
                do_op_lconcat();
                break;
            }
            case Op_Minus: {
                do_op_minus();
                break;
            }
            case Op_Mod: {
                do_op_mod();
                break;
            }
            case Op_Mult: {
                do_op_mult();
                break;
            }
            case Op_Plus: {
                do_op_plus();
                break;
            }
            case Op_Power: {
                do_op_power();
                break;
            }
            case Op_Union: {
                do_op_union();
                break;
            }

            /* Binary ops */
            case Op_Eqv: {
                do_op_eqv();
                break;
            }
            case Op_Lexeq: {
                do_op_lexeq();
                break;
            }
            case Op_Lexge: {
                do_op_lexge();
                break;
            }
            case Op_Lexgt: {
                do_op_lexgt();
                break;
            }
            case Op_Lexle: {
                do_op_lexle();
                break;
            }
            case Op_Lexlt: {
                do_op_lexlt();
                break;
            }
            case Op_Lexne: {
                do_op_lexne();
                break;
            }
            case Op_Neqv: {
                do_op_neqv();
                break;
            }
            case Op_Numeq: {
                do_op_numeq();
                break;
            }
            case Op_Numge: {
                do_op_numge();
                break;
            }
            case Op_Numgt: {
                do_op_numgt();
                break;
            }
            case Op_Numle: {
                do_op_numle();
                break;
            }
            case Op_Numlt: {
                do_op_numlt();
                break;
            }
            case Op_Numne:  {
                do_op_numne();
                break;
            }
            case Op_Asgn:
            case Op_Asgn1: {
                do_op_asgn();
                break;
            }
            case Op_Swap:
            case Op_Swap1: {
                do_op_swap();
                break;
            }
            case Op_Subsc: {
                do_op_subsc();
                break;
            }

            /* Monogenic unary ops */
            case Op_Value: {
                do_op_value();
                break;
            }
            case Op_Size: {
                do_op_size();
                break;
            }
            case Op_Refresh: {
                do_op_refresh();
                break;
            }
            case Op_Number: {
                do_op_number();
                break;
            }
            case Op_Compl: {
                do_op_compl();
                break;
            }
            case Op_Neg: {
                do_op_neg();
                break;
            }

            /* Unary ops */
            case Op_Null: {
                do_op_null();
                break;
            }
            case Op_Nonnull:{
                do_op_nonnull();
                break;
            }
            case Op_Random: {
                do_op_random();
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
                do_op_sect();
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
                if (k_trace && ((struct c_frame *)t->parent_sp)->proc->field) {
                    k_trace--;
                    c_return_trace((struct c_frame *)t->parent_sp);
                }
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
                if (k_trace && ((struct c_frame *)t->parent_sp)->proc->field) {
                    k_trace--;
                    c_return_trace((struct c_frame *)t->parent_sp);
                }
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
                if (k_trace && ((struct c_frame *)t->parent_sp)->proc->field) {
                    k_trace--;
                    c_fail_trace((struct c_frame *)t->parent_sp);
                }
                /* Pop off this frame AND the parent C frame */
                pop_to(t->parent_sp->parent_sp);
                break;
            }

            case Op_Fail: {
                struct p_frame *t = curr_pf;
                set_curr_pf(curr_pf->caller);
                ipc = t->failure_label;
                Desc_EVValD(t->proc, E_Pfail, D_Proc);
                if (t->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        fail_trace(t);
                    }
                }
                pop_to(t->parent_sp);
                break;
            }

            case Op_Suspend: {
                struct p_frame *t = curr_pf;
                tended struct descrip tmp;
                get_variable(&tmp);
                retderef(&tmp, curr_pf->fvars);
                if (curr_pf->lhs)
                    *curr_pf->lhs = tmp;
                set_curr_pf(curr_pf->caller);
                Desc_EVValD(t->proc, E_Psusp, D_Proc);
                if (t->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        suspend_trace(t, &tmp);
                    }
                }
                break;
            }

            case Op_Return: {
                struct p_frame *t = curr_pf;
                tended struct descrip tmp;
                get_variable(&tmp);
                retderef(&tmp, curr_pf->fvars);
                if (curr_pf->lhs)
                    *curr_pf->lhs = tmp;
                curr_pf->exhausted = 1;
                /* Pop any frames below the returning procedure frame */
                pop_to((struct frame *)curr_pf);
                set_curr_pf(curr_pf->caller);
                Desc_EVValD(t->proc, E_Pret, D_Proc);
                if (t->proc->program) {
                    --k_level;
                    if (k_trace) {
                        k_trace--;
                        return_trace(t, &tmp);
                    }
                }
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
                exit(EXIT_FAILURE);
                break; /* Not reached */
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

            case Op_TCaseInit2: {
                do_tcaseinit2();
                break;
            }

            case Op_TCaseInsert2: {
                do_tcaseinsert();
                break;
            }

            case Op_TCaseChoose2: {
                do_tcasechoose2();
                break;
            }

            case Op_TCaseInit1: {
                do_tcaseinit1();
                break;
            }

            case Op_TCaseInsert1: {
                do_tcaseinsert();
                break;
            }

            case Op_TCaseChoose1: {
                do_tcasechoose1();
                break;
            }

            case Op_Exit: {
                /* The main procedure has returned/failed */
                return;
            }

            default: {
                syserr("Unimplemented opcode %d (%s)", (int)curr_op, op_names[curr_op]);
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
    if (prog->event_queue_head)
        pop_from_prog_event_queue(prog, res);
    else  if (prog->exited)
       ipc = failure_label;
    else
        /* Could happen if two programs tried to monitor one another */
        fatalerr(636, NULL);
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
    e = safe_malloc(sizeof(struct prog_event));
    if (curpstate->event_queue_tail) {
        curpstate->event_queue_tail->next = e;
        curpstate->event_queue_tail = e;
    } else
        curpstate->event_queue_head = curpstate->event_queue_tail = e;
    MakeStr(&allchars[event & 0xFF], 1, &e->eventcode);
    e->eventval = *value;
    e->next = 0;
}
