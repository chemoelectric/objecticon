#include "../h/opdefs.h"
#include "../h/opnames.h"

#define OPCODES 0

word *curr_op_addr;

void push_frame(struct frame *f)
{
    f->parent_sp = k_current->sp;
    k_current->sp = f;
}

void push_p_frame(struct p_frame *f)
{
    f->parent_sp = k_current->sp;
    SP = (struct frame *)f;
    PF = f;
}

void push_c_frame(struct c_frame *f)
{
    f->parent_sp = k_current->sp;
    SP = (struct frame *)f;
}

void pop_to(struct frame *f)
{
    while (SP != f) {
        struct frame *t = SP;
        SP = SP->parent_sp;
        if (!SP)
            syserr("Op_Unmark target not found on stack");
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

dptr get_dptr()
{
    word op = GetWord;
#if OPCODES
    fprintf(stderr, "\top=%d(%s)\n", op, op_names[op]);
#endif
    switch (op) {
        case Op_Nil: {
            return 0;
        }
        case Op_Static: {
            return &CurrProc->fstatic[GetWord];
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
            fprintf(stderr, "Invalid opcode in get_dptr: %d (%s)\n", op, op_names[op]);
            exit(1);
        }
    }
}

void move_descrip(dptr dest)
{
    word op = GetWord;
#if OPCODES
    fprintf(stderr, "\top=%d(%s)\n", op, op_names[op]);
#endif
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
            *dest = CurrProc->fstatic[GetWord];
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
            fprintf(stderr, "Invalid opcode in move_descrip: %d (%s)\n", op, op_names[op]);
            exit(1);
        }
    }
}

void get_deref(dptr dest)
{
    word op = GetWord;
#if OPCODES
    fprintf(stderr, "\top=%d(%s)\n", op, op_names[op]);
#endif
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
            *dest = CurrProc->fstatic[GetWord];
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
            fprintf(stderr, "Invalid opcode in get_descrip: %d (%s)\n", op, op_names[op]);
            exit(1);
        }
    }
}

void get_variable(dptr dest)
{
    word op = GetWord;
#if OPCODES
    fprintf(stderr, "\top=%d(%s)\n", op, op_names[op]);
#endif
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
            MakeNamedVar(&CurrProc->fstatic[GetWord], dest);
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
            fprintf(stderr, "Invalid opcode in get_variable: %d (%s)\n", op, op_names[op]);
            exit(1);
        }
    }
}

static void do_op(int op, int nargs)
{
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp = opblks[op];
    int i;
    lhs = get_dptr();
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_c_frame(cf);
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    cf->failure_label = get_addr();
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        Ipc = cf->failure_label;
    pop_to(cf->parent_sp);
}

static void do_opclo(int op, int nargs)
{
    struct c_frame *cf;
    struct b_proc *bp = opblks[op];
    int i;
    word clo;
    clo = GetWord;
    MemProtect(cf = alc_c_frame(bp, nargs));
    push_c_frame(cf);
    if (bp->underef) {
        for (i = 0; i < nargs; ++i)
            get_variable(&cf->args[i]);
    } else {
        for (i = 0; i < nargs; ++i)
            get_deref(&cf->args[i]);
    }
    cf->failure_label = get_addr();
    PF->clo[clo] = (struct frame *)cf;
    if (!bp->ccode(cf)) {
        pop_to(cf->parent_sp);
        Ipc = cf->failure_label;
    }
}

static void do_keyop()
{
    dptr lhs;
    struct c_frame *cf;
    struct b_proc *bp;

    bp = keyblks[GetWord];
    lhs = get_dptr();

    MemProtect(cf = alc_c_frame(bp, 0));
    push_c_frame(cf);
    cf->failure_label = get_addr();
    if (bp->ccode(cf)) {
        if (lhs)
            *lhs = cf->value;
    } else
        Ipc = cf->failure_label;
    pop_to(cf->parent_sp);
}


void interp2()
{
    word op;
    for (;;) {
        curr_op_addr = Ipc;
        op = GetWord;
#if OPCODES
        fprintf(stderr, "ipc:%p(%d)  ", Ipc, (char*)Ipc - curpstate->Code - WordSize);
        fprintf(stderr, "op=%d(%s)\n", op, op_names[op]);fflush(stderr);
#endif
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
                move_descrip(get_dptr());
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

            case Op_Toby: {
                do_opclo(op, 3);
                break;
            }

            case Op_Keyop: {
                do_keyop();
                break;
            }

            case Op_Resume: {
                word clo;
                struct frame *f;

                clo = GetWord;
                f = PF->clo[clo];
                switch (f->type) {
                    case C_FRAME_TYPE: {
                        if (!f->proc->ccode(f)) {
                            pop_to(f->parent_sp);
                            Ipc = f->failure_label;
                        }
                        break;
                    }
                    case P_FRAME_TYPE: {
                        PF = (struct p_frame *)f;
                        break;
                    }
                    default:
                        syserr("Unknown frame type");
                }
                break;
            }

            case Op_Fail: {
                struct p_frame *t = PF;
                PF = PF->caller;
                if (!PF)
                    return;
                Ipc = t->failure_label;
                pop_to(t->parent_sp);
                break;
            }

            case Op_Succeed: {
                move_descrip(&PF->value);
                PF = PF->caller;
                if (!PF)
                    return;
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
                word s, p;
                dptr new_subject;
                new_subject = get_dptr();
                s = GetWord;
                p = GetWord;
                PF->tmp[s] = curpstate->Kywd_subject;
                PF->tmp[p] = curpstate->Kywd_pos;
                curpstate->Kywd_subject = *new_subject;
                MakeInt(1, &curpstate->Kywd_pos);
                break;
            }

            case Op_Invoke: {
                do_invoke2();
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

            case Op_CreateObject: {
                dptr t = get_dptr();
                dptr d = get_dptr();
                struct b_class *class0 = (struct b_class*)BlkLoc(*d);
                struct b_object *object0; /* Doesn't need to be tended */
                MemProtect(object0 = alcobject(class0));
                t->dword = D_Object;
                BlkLoc(*t) = (union block *)object0;
                break;
            }

            default: {
                fprintf(stderr, "Unimplemented opcode %d (%s)\n", op, op_names[op]);
                exit(1);
            }
        }
    }
}
