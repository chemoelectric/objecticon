#include "../h/opdefs.h"
#include "../h/opnames.h"

static void transmit_failure();
static void get_child_prog_result();
static void activate_child_prog();

#include "interpiasm.ri"

#define CHANGEPROGSTATE(p) if (((p)!=curpstate)) { changeprogstate(p); }

static void changeprogstate(struct progstate *p)
{
    p->K_current = k_current;
    curpstate = p;
    k_current->program = curpstate;
}

/*
 * Invoked from a custom fragment.  Act as though the
 * parent C frame had returned the given value.
 */
void set_c_frame_value()
{
    struct p_frame *t = PF;
    dptr res = get_dptr();
    /* Set the value in the C frame */
    SP->parent_sp->value = *res;
    PF = PF->caller;
    /* Pop of this frame, leaving the C frame */
    pop_to(t->parent_sp);
}

/*
 * Invoked from a custom fragment.  Act as though the
 * parent C frame had failed.
 */
void set_c_frame_failure()
{
    struct p_frame *t = PF;
    PF = PF->caller;
    /* Goto the failure_label stored in the C frame */
    Ipc = t->parent_sp->failure_label;
    /* Pop of this frame AND the parent C frame */
    pop_to(t->parent_sp->parent_sp);
}

void revert_PF()
{
    if (PF->proc->program)
        --k_level;

    if (PF->caller->proc->program) {
        /*fprintf(stderr, "Revert:from curpstate=%p kcurrent=%p\n",curpstate, curpstate->K_current);fflush(stderr);*/
        CHANGEPROGSTATE(PF->caller->proc->program);
        /*fprintf(stderr, "       to   curpstate=%p kcurrent=%p\n",curpstate, curpstate->K_current);fflush(stderr);*/
    }

    PF = PF->caller;
}

void tail_invoke_frame(struct frame *f)
{
/*    showcurrstack();*/
    switch (f->type) {
        case C_FRAME_TYPE: {
            if (!f->proc->ccode(f)) {
                Ipc = f->failure_label;
                pop_to(f->parent_sp);
            }
            break;
        }
        case P_FRAME_TYPE: {
            struct p_frame *pf = (struct p_frame *)f;
            pf->caller = PF;
            if (pf->proc->program) {
                /*
                 * If tracing is on, use ctrace to generate a message.
                 */   
                if (k_trace) {
                    k_trace--;
                    call_trace(pf);
                }
                /*fprintf(stderr, "Invoke:from curpstate=%p kcurrent=%p\n",curpstate, curpstate->K_current);fflush(stderr);*/
                CHANGEPROGSTATE(pf->proc->program);
                /*fprintf(stderr, "       to   curpstate=%p kcurrent=%p\n",curpstate, curpstate->K_current);fflush(stderr);*/
                ++k_level;
                /* Todo*/
                if (k_level > 500) {
                    lastop = Op_Exit;
                    fatalerr(311, NULL);
                }
            }
            PF = pf;
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
    while (SP != f) {
        struct frame *t = SP;
        SP = SP->parent_sp;
        if (!SP)
            syserr("pop_to: target not found on stack");
        free_frame(t);
    }
}

word *get_addr()
{
    word w = GetWord;
    return (word *)((char *)PF->code_start + w);
}

word get_offset(word *w)
{
    return DiffPtrsBytes(w, PF->code_start);
}

struct inline_field_cache *get_inline_field_cache()
{
    struct inline_field_cache *t = (struct inline_field_cache *)Ipc;
    Ipc += 2;
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
        case Op_Static: {
            return &curpstate->Statics[GetWord];
        }
        case Op_Arg: {
            return &PF->locals->args[GetWord];
        }
        case Op_Dynamic: {
            return &PF->locals->dynamic[GetWord];
        }
        case Op_Global: {
            return &curpstate->Globals[GetWord];
        }
        case Op_Tmp: {
            return &PF->tmp[GetWord];
        }
        case Op_Closure: {
            return &PF->clo[GetWord]->value;
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
        case Op_Const: {
            *dest = curpstate->Constants[GetWord];
            break;
        }
        case Op_Static: {
            *dest = curpstate->Statics[GetWord];
            break;
        }
        case Op_Arg: {
            *dest = PF->locals->args[GetWord];
            break;
        }
        case Op_Dynamic: {
            *dest = PF->locals->dynamic[GetWord];
            break;
        }
        case Op_Global: {
            *dest = curpstate->Globals[GetWord];
            break;
        }
        case Op_Tmp: {
            *dest = PF->tmp[GetWord];
            break;
        }
        case Op_Closure: {
            *dest = PF->clo[GetWord]->value;
            break;
        }

        default: {
            syserr("Invalid opcode in get_descrip: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Like get_descrip, but dereference temporary and closure descriptors
 * (locals/globals should already be dereferenced).
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
        case Op_Const: {
            *dest = curpstate->Constants[GetWord];
            break;
        }
        case Op_Static: {
            *dest = curpstate->Statics[GetWord];
            break;
        }
        case Op_Arg: {
            *dest = PF->locals->args[GetWord];
            break;
        }
        case Op_Dynamic: {
            *dest = PF->locals->dynamic[GetWord];
            break;
        }
        case Op_Global: {
            *dest = curpstate->Globals[GetWord];
            break;
        }
        case Op_Tmp: {
            deref(&PF->tmp[GetWord], dest);
            break;
        }
        case Op_Closure: {
            deref(&PF->clo[GetWord]->value, dest);
            break;
        }

        default: {
            syserr("Invalid opcode in get_descrip: %d (%s)\n", op, op_names[op]);
        }
    }
}

/*
 * Like get_descrip, but for statics, locals and globals, rather than
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
            *dest = curpstate->Constants[GetWord];
            break;
        }
        case Op_Static: {
            MakeNamedVar(&curpstate->Statics[GetWord], dest);
            break;
        }
        case Op_Arg: {
            MakeNamedVar(&PF->locals->args[GetWord], dest);
            break;
        }
        case Op_Dynamic: {
            MakeNamedVar(&PF->locals->dynamic[GetWord], dest);
            break;
        }
        case Op_Global: {
            MakeNamedVar(&curpstate->Globals[GetWord], dest);
            break;
        }
        case Op_Tmp: {
            *dest = PF->tmp[GetWord];
            break;
        }
        case Op_Closure: {
            *dest = PF->clo[GetWord]->value;
            break;
        }

        default: {
            syserr("Invalid opcode in get_variable: %d (%s)\n", op, op_names[op]);
        }
    }
}

static void do_op(int op, int nargs)
{
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp = opblks[op];
    word *failure_label;
    int i;
    lhs = get_dptr();
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_frame((struct frame *)cf);
    xnargs = nargs;
    xargp =cf->args;
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    failure_label = get_addr();
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        Ipc = failure_label;
    pop_to(cf->parent_sp);
}

static void do_opclo(int op, int nargs)
{
    struct c_frame *cf;
    struct b_proc *bp = opblks[op];
    int i;
    word clo;
    word *failure_label;
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_frame((struct frame *)cf);
    xnargs = nargs;
    xargp = cf->args;
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    failure_label = get_addr();
    PF->clo[clo] = (struct frame *)cf;
    if (!bp->ccode(cf)) {
        pop_to(cf->parent_sp);
        Ipc = failure_label;
    }
}

static void do_keyop()
{
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp;
    word *failure_label;

    bp = keyblks[GetWord];
    lhs = get_dptr();

    MemProtect(cf = alc_c_frame(bp, 0));
    push_frame((struct frame *)cf);
    xnargs = 0;
    xargp = 0;
    failure_label = get_addr();
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        Ipc = failure_label;
    pop_to(cf->parent_sp);
}

static void do_keyclo()
{
    struct c_frame *cf;
    struct b_proc *bp;
    word clo;
    word *failure_label;
    bp = keyblks[GetWord];
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, 0));
    push_frame((struct frame *)cf);
    xnargs = 0;
    xargp = 0;
    failure_label = get_addr();
    PF->clo[clo] = (struct frame *)cf;
    if (!bp->ccode(cf)) {
        pop_to(cf->parent_sp);
        Ipc = failure_label;
    }
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
}

static void do_create()
{
    dptr lhs;
    word *start_label;
    struct p_frame *pf;
    tended struct b_coexpr *coex;
    lhs = get_dptr();
    start_label = get_addr();
    MemProtect(coex = alccoexp());
    coex->program = coex->creator = curpstate;
    coex->main_of = 0;
    MemProtect(pf = alc_p_frame(PF->proc, PF->locals));
    coex->failure_label = coex->start_label = pf->ipc = start_label;
    coex->curr_pf = pf;
    coex->sp = (struct frame *)pf;
    lhs->dword = D_Coexpr;
    BlkLoc(*lhs) = (union block *)coex;
}

void switch_to(struct b_coexpr *ce)
{
    curpstate = ce->program;
    k_current = ce;
}

static void do_coact()
{
    dptr lhs;
    tended struct descrip arg1, arg2;
    word *failure_label;

    lhs = get_dptr();

    get_descrip(&arg1);   /* Value */
    get_deref(&arg2);     /* Coexp */
    failure_label = get_addr();
    if (!is:coexpr(arg2)) {
        xargp = &arg1;
        xexpr = &arg2;
        err_msg(118, &arg2);
        Ipc = failure_label;
        return;
    }

    if (BlkLoc(arg2)->coexpr.curr_pf->locals != PF->locals)
        retderef(&arg1, PF->locals);

    if (k_trace) {
        --k_trace;
        trace_coact(k_current, &BlkLoc(arg2)->coexpr, &arg1);
    }
    /*printf("activating from k_current=%p to coexp=",k_current);print_desc(stdout, &arg2);printf("\n");*/
    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Set the target's activator, switch to the target and set its transmitted value */
    BlkLoc(arg2)->coexpr.activator = k_current;
    switch_to(&BlkLoc(arg2)->coexpr);
    if (k_current->tvalloc)
        *k_current->tvalloc = arg1;
}

static void do_coret()
{
    tended struct descrip val;
    get_descrip(&val);

    if (k_current->activator->curr_pf->locals != PF->locals)
        retderef(&val, PF->locals);

    /*printf("coret FROM %p to %p VAL=",k_current, k_current->activator);print_desc(stdout, val);printf("\n");*/
    if (k_trace) {
        --k_trace;
        trace_coret(k_current, k_current->activator, &val);
    }

    /* If someone transmits failure to this coexpression, just act as though resumed */
    k_current->failure_label = Ipc;

    /* Increment the results counter */
    ++k_current->size;

    /* Switch to the target and set the transmitted value */
    switch_to(k_current->activator);
    if (k_current->tvalloc)
        *k_current->tvalloc = val;
}

void do_cofail()
{
    /*printf("cofail FROM %p to %p",k_current, k_current->activator);printf("\n");*/
    if (k_trace) {
        --k_trace;
        trace_cofail(k_current, k_current->activator);
    }

    /* If someone transmits failure to this coexpression, just act as though resumed */
    k_current->failure_label = Ipc;

    /* Switch to the target and jump to its failure label */
    switch_to(k_current->activator);
    PF->ipc = k_current->failure_label;
}

static void transmit_failure()
{
    tended struct descrip t;
    dptr lhs;
    word *failure_label;
    get_deref(&t);
    lhs = get_dptr();
    failure_label = get_addr();

    if (k_trace) {
        --k_trace;
        trace_cofail(k_current, &BlkLoc(t)->coexpr);
    }
    /*printf("transmitting failure from k_current=%p to coexp=",k_current);print_desc(stdout, &t);printf("\n");*/
    k_current->tvalloc = lhs;
    k_current->failure_label = failure_label;

    /* Switch to the target and go to its failure label */
    BlkLoc(t)->coexpr.activator = k_current;
    switch_to(&BlkLoc(t)->coexpr);
    PF->ipc = k_current->failure_label;
}

"cofail(ce) - transmit a co-expression failure to ce"

function{0,1} cofail(ce)
    body {
      struct p_frame *pf;
      if (is:null(ce)) {
          ce.dword = D_Coexpr;
          BlkLoc(ce) = (union block *)k_current->activator;
      } else if (!is:coexpr(ce))
         runerr(118, ce);

      if (!BlkLoc(ce)->coexpr.failure_label)
         runerr(135, ce);

      MemProtect(pf = alc_p_frame((struct b_proc *)&Bcofail_impl, 0));
      push_frame((struct frame *)pf);
      pf->locals->args[0] = ce;
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
    failure_label = get_addr();
    if (!cnv:C_integer(*limit, tmp)) {
        xargp = limit;
        err_msg(101, limit);
        Ipc = failure_label;
        return;
    }
    MakeInt(tmp, limit);
    if (tmp < 0) {
        xargp = limit;
        err_msg(205, limit);
        Ipc = failure_label;
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
    failure_label = get_addr();
    if (!cnv:string_or_ucs(new_subject, new_subject)) {
        xargp = &new_subject;
        err_msg(129, &new_subject);
        Ipc = failure_label;
        return;
    }
    PF->tmp[s] = curpstate->Kywd_subject;
    PF->tmp[p] = curpstate->Kywd_pos;
    curpstate->Kywd_subject = new_subject;
    MakeInt(1, &curpstate->Kywd_pos);
}

void interp()
{
    word op;
    for (;;) {
        if (curpstate->n_prog_events) {
            /* Switch to parent program */
            curpstate = curpstate->parent;
        }
        PF->curr_inst = Ipc;
        lastop = op = GetWord;
        switch (op) {
            case Op_Goto: {
                Ipc = get_addr();
                break;
            }
            case Op_IGoto: {
                Ipc = PF->lab[*Ipc]; 
                break;
            }
            case Op_Mark: {
                PF->mark[GetWord] = SP;
                break;
            }
            case Op_Unmark: {
                pop_to(PF->mark[GetWord]);
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
                PF->lab[i] = get_addr();
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
                do_op(op, 2);
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
                do_op(op, 1);
                break;
            }

            /* Unary closures */
            case Op_Tabmat:
            case Op_Bang: {
                do_opclo(op, 1);
                break;
            }

            /* Binary closures */
            case Op_Rasgn:
            case Op_Rswap:{
                do_opclo(op, 2);
                break;
            }

            case Op_Toby: {
                do_opclo(op, 3);
                break;
            }

            case Op_Sect: {
                do_op(op, 3);
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
                f = PF->clo[clo];
                f->failure_label = get_addr();
                if (f->exhausted) {
                    /* Just go to failure label and dispose of the frame */
                    Ipc = f->failure_label;
                    pop_to(f->parent_sp);
                } else
                    tail_invoke_frame(f);
                break;
            }

            case Op_Fail: {
                struct p_frame *t = PF;
                revert_PF();
                if (k_trace && t->proc->program) {
                    k_trace--;
                    fail_trace(t);
                }
                Ipc = t->failure_label;
                pop_to(t->parent_sp);
                break;
            }

            case Op_Pop: {
                struct p_frame *t = PF;
                PF = PF->caller;
                pop_to(t->parent_sp);
                break;
            }

            case Op_PopRepeat: {
                struct p_frame *t = PF;
                PF = PF->caller;
                pop_to(t->parent_sp);
                Ipc = PF->curr_inst;
                break;
            }

            case Op_Suspend: {
                struct p_frame *t = PF;
                get_descrip(&PF->value);
                retderef(&PF->value, PF->locals);
                revert_PF();
                if (k_trace && t->proc->program) {
                    k_trace--;
                    suspend_trace(t);
                }
                break;
            }

            case Op_Return: {
                struct p_frame *t = PF;
                get_descrip(&PF->value);
                retderef(&PF->value, PF->locals);
                t->exhausted = 1;
                revert_PF();
                if (k_trace && t->proc->program) {
                    k_trace--;
                    return_trace(t);
                }
                break;
            }

            case Op_Deref: {
                dptr src = get_dptr();
                dptr dest = get_dptr();
                deref(src, dest);
                break;
            }

            case Op_ScanSwap: {
                word s, p;
                struct descrip tmp;
                s = GetWord;
                p = GetWord;
                tmp = curpstate->Kywd_subject;
                curpstate->Kywd_subject = PF->tmp[s];
                PF->tmp[s] = tmp;
                tmp = curpstate->Kywd_pos;
                curpstate->Kywd_pos = PF->tmp[p];
                PF->tmp[p] = tmp;
                break;
            }

            case Op_ScanRestore: {
                word s, p;
                s = GetWord;
                p = GetWord;
                curpstate->Kywd_subject = PF->tmp[s];
                curpstate->Kywd_pos = PF->tmp[p];
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
                get_addr();
                /* Change Op_EnterInit to an Op_Goto */
                Ipc[-2] = Op_Goto;
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
                fprintf(stderr, "Unimplemented opcode %d (%s)\n", op, op_names[op]);
                exit(1);
            }
        }
    }
}

static void activate_child_prog()
{
    dptr ce = get_dptr();
    curpstate = BlkLoc(*ce)->coexpr.main_of;
}

static void get_child_prog_result()
{
    struct progstate *prog;
    dptr ce = get_dptr();
    dptr res = get_dptr();
    word *failure_label = get_addr();

    prog = BlkLoc(*ce)->coexpr.main_of;
    if (prog->exited) {
       Ipc = failure_label;
       return;
    }

    if (!prog->n_prog_events)
        syserr("Expected a prog event in the queue");
    BlkLoc(*res)->object.fields[0] = prog->prog_event_buff[prog->first_prog_event].eventcode;
    BlkLoc(*res)->object.fields[1] = prog->prog_event_buff[prog->first_prog_event].eventval;
    prog->first_prog_event = (prog->first_prog_event + 1) % ElemCount(curpstate->prog_event_buff);
    --prog->n_prog_events;
}

function{0,1} lang_Prog_get_event_impl(c, res)
   if !is:coexpr(c) then
      runerr(118,c)
   body {
       struct progstate *prog = BlkLoc(c)->coexpr.main_of;
       struct p_frame *pf;
       if (!prog)
           runerr(632, c);
       if (prog->parent != curpstate)
           runerr(633, c);
       if (prog->n_prog_events) {
           BlkLoc(res)->object.fields[0] = prog->prog_event_buff[prog->first_prog_event].eventcode;
           BlkLoc(res)->object.fields[1] = prog->prog_event_buff[prog->first_prog_event].eventval;
           prog->first_prog_event = (prog->first_prog_event + 1) % ElemCount(curpstate->prog_event_buff);
           --prog->n_prog_events;
           return res;
       }
       if (prog->exited)
           fail;
       MemProtect(pf = alc_p_frame((struct b_proc *)&Blang_Prog_get_event_impl_impl, 0));
       push_frame((struct frame *)pf);
       pf->locals->args[0] = c;
       pf->locals->args[1] = res;
       tail_invoke_frame((struct frame *)pf);
       return nulldesc;
   }
end

void add_to_prog_event_buff(dptr value, int event)
{
    int i;
    if (curpstate->n_prog_events >= ElemCount(curpstate->prog_event_buff))
        ffatalerr("Prog event buffer overflowed");
    i = (curpstate->first_prog_event + curpstate->n_prog_events) % ElemCount(curpstate->prog_event_buff);
    StrLen(curpstate->prog_event_buff[i].eventcode) = 1;
    StrLoc(curpstate->prog_event_buff[i].eventcode) = &allchars[event & 0xFF];
    curpstate->prog_event_buff[i].eventval = *value;
    ++curpstate->n_prog_events;
}


