/*
 * invoke.r - contains invoke, apply
 */

#include "../h/opdefs.h"
#include "../h/modflags.h"

static struct frame *construct_record2(dptr expr, int argc, dptr args);
static struct frame *construct_object2(dptr expr, int argc, dptr args);
static struct frame *invoke_proc2(dptr expr, int argc, dptr args);
static struct frame *get_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self);
static void ensure_class_initialized();


void do_invoke2()
{
    word clo, argc;
    dptr expr;
    struct frame *f;
    word *failure_label;
    clo = GetWord;
    expr = get_dptr();
    argc = GetWord;
    failure_label = get_addr();

    type_case *expr of {
      class: {
            f = construct_object2(expr, argc, 0);
        }

      constructor: {
            f =  construct_record2(expr, argc, 0);
        }

      methp: {
            /*return invoke_methp(nargs, newargp, cargp_ptr, nargs_ptr);*/
        }

      proc: {
            f = invoke_proc2(expr, argc, 0);
        }

     default: {
         /*return invoke_misc(nargs, newargp, cargp_ptr, nargs_ptr);*/
        }
    }

    if (!f) {
        err_msg(0, NULL);
        Ipc = failure_label;
        return;
    }

    PF->clo[clo] = f;

    tail_invoke_frame(f, failure_label);
}

void do_apply()
{
    word clo, argc;
    dptr expr, args;
    struct frame *f;
    word *failure_label;

    clo = GetWord;
    expr = get_dptr();
    args = get_dptr();
    failure_label = get_addr();

    type_case *args of {
      list: {
            argc = BlkLoc(*args)->list.size;
        }
      record: {
            argc = BlkLoc(*args)->record.constructor->n_fields;
        }
      default: {
            err_msg(126, args);
            Ipc = failure_label;
      }
    }

    type_case *expr of {
      class: {
            f = construct_object2(expr, argc, args);
        }

      constructor: {
            f =  construct_record2(expr, argc, args);
        }

      methp: {
            /*return invoke_methp(nargs, newargp, cargp_ptr, nargs_ptr);*/
        }

      proc: {
            f = invoke_proc2(expr, argc, args);
        }

     default: {
         /*return invoke_misc(nargs, newargp, cargp_ptr, nargs_ptr);*/
        }
    }

    if (!f) {
        err_msg(0, NULL);
        Ipc = failure_label;
        return;
    }

    PF->clo[clo] = f;

    tail_invoke_frame(f, failure_label);
}


static void check_if_uninitialized()
{
    dptr class0 = get_dptr();  /* Class */
    word *a = get_addr();
    if (BlkLoc(*class0)->class.init_state != Uninitialized)
        Ipc = a;
    printf("check_if_uninitialized\n");
}

static void set_class_state()
{
    dptr class0 = get_dptr();  /* Class */
    struct descrip val;
    get_deref(&val);      /* Value */
    BlkLoc(*class0)->class.init_state = IntVal(val);
    printf("set_class_state to %d\n", IntVal(val));
}

void dump_code(int n)
{
    int i;
    for (i = 0; i < n; ++i) {
        printf("%d (%p) = %d\n", i, &PF->code_start[i], PF->code_start[i]);
    }
}

static void for_class_supers()
{
    dptr class0 = get_dptr();  /* Class */
    dptr i = get_dptr();       /* Index */
    dptr res = get_dptr();     /* Result */
    word *a = get_addr();      /* Branch when done */
    printf("for_class_supers (i=%d of %d)\n", IntVal(*i), BlkLoc(*class0)->class.n_supers);
    /*showstack();*/
    if (IntVal(*i) < BlkLoc(*class0)->class.n_supers) {
        res->dword = D_Class;
        BlkLoc(*res) = (union block *)BlkLoc(*class0)->class.supers[IntVal(*i)];
        IntVal(*i) += 1;
    } else
        Ipc = a;
}

static void invoke_class_init()
{
    dptr d = get_dptr();  /* Class */
    word *failure_label = get_addr(); /* Failure label */
    struct b_class *class0 = (struct b_class *)BlkLoc(*d);
    struct class_field *init_field;

    printf("invoke_class_init %p\n", class0);
    init_field = class0->init_field;
    if (init_field && init_field->defining_class == class0) {
        struct b_proc *bp;
        struct frame *f;
        /*
         * Check the initial function is a static method.
         */
        if ((init_field->flags & (M_Method | M_Static)) != (M_Method | M_Static))
            syserr("init field not a static method");
        bp = (struct b_proc *)BlkLoc(*init_field->field_descriptor);
        f = get_frame_for_proc(bp, 0, 0, 0);
        push_frame(f);
        tail_invoke_frame(f, failure_label);
    }
}


#include "invokeiasm.ri"

static void ensure_class_initialized()
{
    struct p_frame *pf;
    dptr d = get_dptr();
    printf("ensure_class_initialized ");print_desc(stdout,d);printf("\n");
    MemProtect(pf = alc_p_frame((struct b_proc *)&Bensure_class_initialized, 0));
    push_frame((struct frame *)pf);
    pf->failure_label = Ipc;
    pf->locals->args[0] = *d;
    pf->caller = PF;
    PF = pf;
    Ipc = pf->proc->icode;
}


static struct frame *construct_object2(dptr expr, int argc, dptr args)
{
    struct class_field *new_field;
    struct b_class *class0 = (struct b_class*)BlkLoc(*expr);
    struct p_frame *pf;
    int i;

    new_field = class0->new_field;
    if (new_field) {
        struct frame *new_f;
        struct b_proc *bp = (struct b_proc *)BlkLoc(*new_field->field_descriptor);

        /*
         * Check the constructor function is a non-static method.
         */
        if ((new_field->flags & (M_Method | M_Static)) != M_Method)
            syserr("new field not a non-static method");

        if (check_access(new_field, class0) == Error)
            return 0;

        MemProtect(pf = alc_p_frame((struct b_proc *)&Bconstruct_object, 0));
        push_frame((struct frame *)pf);
        /* Arg0 is the class */
        pf->locals->args[0] = *expr;
        /* Arg1 is the allocated new object object */
        MemProtect(BlkLoc(pf->locals->args[1]) = (union block *)alcobject(class0));
        pf->locals->args[1].dword = D_Object; 

        /* Allocate a frame for the "new" method.  It is invoked from
         * within construct_object */
        new_f = get_frame_for_proc(bp, argc, args, &pf->locals->args[1]);

        /* Set up a mark and closure for the new method.  They are used with Op_Resume and Op_Unmark
         * in construct_object's code to invoke the new method.
         */
        pf->mark[0] = (struct frame *)pf;
        pf->clo[0] = new_f;
    } else {
        if (args) {
            /* Skip unwanted params */
            for (i = 0; i < argc; ++i)
                get_deref(&trashcan);
        }
        MemProtect(pf = alc_p_frame((struct b_proc *)&Bconstruct_object0, 0));
        push_frame((struct frame *)pf);
        /* Arg0 is the class */
        pf->locals->args[0] = *expr;
        /* Arg 1 is a new object */
        MemProtect(BlkLoc(pf->locals->args[1]) = (union block *)alcobject(class0));
        pf->locals->args[1].dword = D_Object; 
    }
    return (struct frame *)pf;
}

static struct frame *construct_record2(dptr expr, int argc, dptr args)
{
    struct p_frame *pf;
    struct b_constructor *con = (struct b_constructor *)BlkLoc(*expr);
    int i;

    MemProtect(pf = alc_p_frame((struct b_proc *)&Bconstruct_record, 0));
    push_frame((struct frame *)pf);

    MemProtect(BlkLoc(pf->locals->args[0]) = (union block *)alcrecd(con));
    pf->locals->args[0].dword = D_Record;

    if (args) {
        for (i = 0; i < argc; ++i) {
            if (i < con->n_fields)
                BlkLoc(pf->locals->args[0])->record.fields[i] = *get_element(args, i + 1);
            else
                break;
        }
    } else {
        for (i = 0; i < argc; ++i) {
            if (i < con->n_fields)
                get_deref(&BlkLoc(pf->locals->args[0])->record.fields[i]);
            else
                get_deref(&trashcan);
        }
    }

    return (struct frame *)pf;
}

static struct frame *get_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self)
{
    int i, j;
    
    if (bp->icode) {
        /* Icon procedure */
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame(bp, 0));
        if (self) {
            pf->locals->args[0] = *self;
            i = 1;
        } else
            i = 0;
        if (bp->nparam < 0) {
            /* Varargs, last param is a list */
            tended struct descrip tmp, l;
            int abs_nparam = -bp->nparam;
            create_list(Max(0, argc - abs_nparam + 1 + i), &l);
            if (args) {
                for (j = 1; j <= argc; ++j) {
                    if (i < abs_nparam - 1)
                        pf->locals->args[i++] = *get_element(args, j);
                    else
                        list_put(&l, get_element(args, j));
                }
            } else {
                for (j = 0; j < argc; ++j) {
                    if (i < abs_nparam - 1)
                        get_deref(&pf->locals->args[i++]);
                    else {
                        get_deref(&tmp);
                        list_put(&l, &tmp);
                    }
                }
            }
            while (i < abs_nparam - 1)
                pf->locals->args[i++] = nulldesc;
            pf->locals->args[abs_nparam - 1] = l;
        } else {
            if (args) {
                for (j = 1; j <= argc; ++j) {
                    if (i < bp->nparam)
                        pf->locals->args[i++] = *get_element(args, j);
                    else
                        break;
                }
            } else {
                for (j = 0; j < argc; ++j) {
                    if (i < bp->nparam)
                        get_deref(&pf->locals->args[i++]);
                    else
                        get_deref(&trashcan);
                }
            }
            while (i < bp->nparam)
                pf->locals->args[i++] = nulldesc;
        }
        return (struct frame *)pf;
    } else {
        /* Builtin */
        struct c_frame *cf;
        int want;

        if (self)
            i = 1;
        else
            i = 0;

        if (bp->nparam < 0)
            want = Max(argc + i, -bp->nparam - 1);
        else
            want = Max(argc + i, bp->nparam);

        MemProtect(cf = alc_c_frame(bp, want));

        if (self)
            cf->args[0] = *self;

        if (args) {
            for (j = 1; j <= argc; ++j) {
                cf->args[i++] = *get_element(args, j);
            }
        } else {
            if (bp->underef) {
                for (j = 0; j < argc; ++j)
                    get_variable(&cf->args[i++]);
            } else {
                for (j = 0; j < argc; ++j)
                    get_deref(&cf->args[i++]);
            }
        }
        while (i < want)
            cf->args[i++] = nulldesc;

        return (struct frame *)cf;
    }
}





static struct frame *invoke_proc2(dptr expr, int argc, dptr args)
{
    struct b_proc *bp = (struct b_proc *)BlkLoc(*expr);
    struct frame *f;
    f = get_frame_for_proc(bp, argc, args, 0);
    push_frame(f);
    return f;
}












#begdef invoke_macro(invoke_methp,invoke_misc,invoke_proc,construct_object,construct_record,invoke,e_ecall,e_pcall,e_objectcreate,e_rcreate)


static int invoke_methp(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int invoke_misc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int invoke_proc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int construct_object(int nargs, dptr newargp);
static int construct_record(int nargs, dptr newargp);
static dptr do_new_invoke(dptr top);








/*
 * invoke -- Perform setup for invocation.  
 */
int invoke(int nargs, dptr *cargp_ptr, int *nargs_ptr)
{
    register dptr newargp;

    /*
     * Point newargp at Arg0 and dereference it.
     */
    newargp = (dptr )(sp - 1) - nargs;
    /* These pointers are used for the stacktrace on error */
    xnargs = nargs;
    xargp = newargp;
    Deref(newargp[0]);
    CheckStack;

    type_case *newargp of {
      class: {
            return construct_object(nargs, newargp);
        }

      constructor: {
            return construct_record(nargs, newargp);
        }

      methp: {
            return invoke_methp(nargs, newargp, cargp_ptr, nargs_ptr);
        }

      proc: {
            return invoke_proc(nargs, newargp, cargp_ptr, nargs_ptr);
        }

     default: {
            return invoke_misc(nargs, newargp, cargp_ptr, nargs_ptr);
         
        }
    }
}

static int invoke_methp(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr)
{
    struct b_methp *mp = &BlkLoc(*newargp)->methp;
    int i;

    /*
     * Shift all the parameters down one to make room for the object
     * param.
     */
    for (i = nargs; i > 0; i--) {
        newargp[i + 1] = newargp[i];
    }

    /*
     * Overwrite the D_Methp with the field's proc descriptor.
     */
    newargp[0].dword = D_Proc;
    BlkLoc(newargp[0]) = (union block *)mp->proc;

    /*
     * Insert the object parameter (ie, the thing given to the
     * self param in the method).
     */
    newargp[1].dword = D_Object;
    BlkLoc(newargp[1]) = (union block *)mp->object;

    sp += 2;
    ++nargs;
    ++xnargs;
    return invoke_proc(nargs, newargp, cargp_ptr, nargs_ptr);
}

int invoke_misc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr)
{
    C_integer tmp;
    int i;

    /*
     * Arg0 is not a procedure.
     */

    if (cnv:C_integer(newargp[0], tmp)) {
        MakeInt(tmp,&newargp[0]);

        /*
         * Arg0 is an integer, select result.
         */
        i = cvpos(IntVal(newargp[0]), (word)nargs);
        if (i == CvtFail || i > nargs)
            return I_Fail;

        newargp[0] = newargp[i];

        sp = (word *)newargp + 1;
        return I_Continue;
    }
    else {
        /*
         * Can Arg0 be converted to a string?
         */
        if (cnv:tmp_string(newargp[0],newargp[0])) {
            /*
             * Is it a global class or procedure (or record)?
             */
            dptr p = lookup_global(newargp, curpstate);
            if (p) {
                type_case *p of {
                    class: {
                        *newargp = *p;
                        return construct_object(nargs, newargp);
                    }
                    proc: {
                        *newargp = *p;
                        return invoke_proc(nargs, newargp, cargp_ptr, nargs_ptr);
                    }
                    constructor: {
                        *newargp = *p;
                        return construct_record(nargs, newargp);
                    }
                }
            } else {
                struct b_proc *tmp;
                /*
                 * Is it a builtin or an operator?
                 */
                if ((tmp = bi_strprc(newargp, (C_integer)nargs))) {
                    BlkLoc(newargp[0]) = (union block *)tmp;
                    newargp[0].dword = D_Proc;
                    return invoke_proc(nargs, newargp, cargp_ptr, nargs_ptr);
                }
            }
        }

        /*
         * Fell through - not a string or not convertible to something invocable.
         */
        ReturnErrNum(106, Error);
    }
}

/*
 * newargp[0] is now a descriptor suitable for invocation.
 */
int invoke_proc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr)
{
    register struct pf_marker *newpfp;
    register word *newsp = sp;
    tended struct descrip arg_sv;
    register word i;
    struct b_proc *proc0;
    int nparam;

    /* 
     * Dereference the supplied arguments.
     */
    proc0 = (struct b_proc *)BlkLoc(newargp[0]);
    if (!proc0->underef)	/* if set, don't reference arguments */
        for (i = 1; i <= nargs; i++)
            Deref(newargp[i]);

    /*
     * Adjust the argument list to conform to what the routine being invoked
     *  expects (proc0->nparam).  If nparam is less than 0, the number of
     *  arguments is variable. For functions (program = 0) with a
     *  variable number of arguments, nothing need be done.  For Icon procedures
     *  with a variable number of arguments, arguments beyond abs(nparam) are
     *  put in a list which becomes the last argument.  For fix argument
     *  routines, if too many arguments were supplied, adjusting the stack
     *  pointer is all that is necessary. If too few arguments were supplied,
     *  null descriptors are pushed for each missing argument.
     */

    proc0 = (struct b_proc *)BlkLoc(newargp[0]);
    nparam = (int)proc0->nparam;

    if (nparam >= 0) {
        if (nargs > nparam)
            newsp -= (nargs - nparam) * 2;
        else if (nargs < nparam) {
            i = nparam - nargs;
            while (i--) {
                *++newsp = D_Null;
                *++newsp = 0;
            }
        }
        nargs = nparam;
        xnargs = nargs;
    }
    else {
        if (proc0->program) { /* this is a procedure */
            int lelems, absnparam = abs(nparam);
            dptr llargp;

            if (nargs < absnparam - 1) {
                i = absnparam - 1 - nargs;
                while (i--) {
                    *++newsp = D_Null;
                    *++newsp = 0;
                }
                nargs = absnparam - 1;
            }

            lelems = nargs - (absnparam - 1);
            llargp = &newargp[absnparam];
            arg_sv = llargp[-1];
#ifdef CHECK
            Ollist(lelems, &llargp[-1]);
#endif
            llargp[0] = llargp[-1];
            llargp[-1] = arg_sv;
            newsp = (word *)llargp + 1;
            nargs = absnparam;
        }
    }

    if (!proc0->program) {
        /*
         * A function is being invoked, so nothing else here needs to be done.
         */

        if (nargs < abs(nparam) - 1) {
            i = abs(nparam) - 1 - nargs;
            while (i--) {
                *++newsp = D_Null;
                *++newsp = 0;
            }
            nargs = abs(nparam) - 1;
        }

        *nargs_ptr = nargs;
        *cargp_ptr = newargp;
        sp = newsp;

        EVVal((word)Op_Invoke,e_ecall);

        if (nparam < 0)
            return I_Vararg;
        else
            return I_Builtin;
    }


    /*
     * Build the procedure frame.
     */
    newpfp = (struct pf_marker *)(newsp + 1);
    newpfp->pf_nargs = nargs;
    newpfp->pf_argp = argp;
    newpfp->pf_pfp = pfp;
    newpfp->pf_ilevel = ilevel;
    newpfp->pf_scan = NULL;

    newpfp->pf_ipc = ipc;
    newpfp->pf_gfp = gfp;
    newpfp->pf_efp = efp;

    argp = newargp;
    pfp = newpfp;
    newsp += Vwsizeof(*pfp);

    /*
     * If tracing is on, use ctrace to generate a message.
     */   
    if (k_trace) {
        k_trace--;
        ctrace(proc0, nargs, &newargp[1]);
    }
   
    /*
     * Point ipc at the icode entry point of the procedure being invoked.
     */
    ipc = proc0->icode;

    /*
     * Enter the program state of the procedure being invoked
     * and save from/to states in the procedure frame.
     */
    newpfp->pf_from = curpstate;
    newpfp->pf_to = proc0->program;
    CHANGEPROGSTATE(newpfp->pf_to);

    efp = 0;
    gfp = 0;

    /*
     * Push a null descriptor on the stack for each dynamic local.
     */
    for (i = proc0->ndynam; i > 0; i--) {
        *++newsp = D_Null;
        *++newsp = 0;
    }
    sp = newsp;

    k_level++;

    EVValD(newargp, e_pcall);

    return I_Continue;
}

static int construct_object(int nargs, dptr newargp)
{
    struct class_field *new_field;
    struct b_class *class0;
    struct b_object *object0; /* Doesn't need to be tended */

    class0 = (struct b_class*)BlkLoc(*newargp);
    ensure_initialized(class0);

    new_field = class0->new_field;
    if (!new_field) {
        /*
         * No constructor function, so just put the object in Arg0.
         */
        MemProtect(object0 = alcobject(class0));
        newargp[0].dword = D_Object;
        BlkLoc(newargp[0]) = (union block *)object0;
    } else {
        /*
         * Check the constructor function is a non-static method.
         */
        if ((new_field->flags & (M_Method | M_Static)) != M_Method)
            syserr("new field not a non-static method");

        if (check_access(new_field, class0) == Error)
            return Error;

        MemProtect(object0 = alcobject(class0));

        /*
         * Copy the new object over the class parameter, and push the
         * new() procedure.  The custom opcode Op_CopyArgs2 will copy these
         * args into correct order for an invoke.
         */
        newargp[0].dword = D_Object;
        BlkLoc(newargp[0]) = (union block *)object0;
        PushDesc(*new_field->field_descriptor);

        /*
         * Call the new method.
         */
        object0->init_state = Initializing;
        if (!do_new_invoke(newargp)) {
            BlkLoc(newargp[0])->object.init_state = Initialized;
            return I_Fail;
        }
    }

    /*
     * Set the init flag
     */
    BlkLoc(newargp[0])->object.init_state = Initialized;

    sp = (word *)newargp + 1;

    EVValD(newargp, e_objectcreate);

    return I_Continue;
}

static int construct_record(int nargs, dptr newargp)
{
    struct b_constructor *con;
    struct b_record *rec;
    int i, n;

    con = (struct b_constructor*)BlkLoc(*newargp);
    MemProtect(rec = alcrecd(con));
    newargp[0].dword = D_Record;
    BlkLoc(newargp[0]) = (union block *)rec;
    n = Min(nargs, con->n_fields);
    for (i = 0; i < n; ++i) {
        Deref(newargp[i + 1]);
        rec->fields[i] = newargp[i + 1];
    }

    sp = (word *)newargp + 1;

    EVValD(newargp, e_rcreate);

    return I_Continue;
}


#enddef

invoke_macro(invoke_methp_0,invoke_misc_0,invoke_proc_0,construct_object_0,construct_record_0,invoke_0,0,0,0,0)
invoke_macro(invoke_methp_1,invoke_misc_1,invoke_proc_1,construct_object_1,construct_record_1,invoke_1,E_Ecall,E_Pcall,E_Objectcreate,E_Rcreate)


void ensure_initialized(struct b_class *class0)
{
    struct class_field *init_field;
    dptr pp;
    int i;

    if (class0->init_state != Uninitialized)
        return;
    class0->init_state = Initializing;

    /*
     * Initialize any superclasses first.
     */
    for (i = 0; i < class0->n_supers; ++i)
        ensure_initialized(class0->supers[i]);

    /*
     * Look for an init method defined in this class; if not found,
     * then return.
     */
    init_field = class0->init_field;
    if (init_field && init_field->defining_class == class0) {
        /*
         * Check the initial function is a static method.
         */
        if ((init_field->flags & (M_Method | M_Static)) != (M_Method | M_Static))
            syserr("init field not a static method");

        /*
         * Push the init method on the stack, call it, restore stack.
         */
        sp += 2;
        pp = (dptr)(sp - 1);
        *pp = *init_field->field_descriptor;
        do_invoke(pp);
        sp -= 2;
    }
    class0->init_state = Initialized;
}

/*
 * Invoke the given Icon procedure, which must be a pointer into the
 * stack.  The arguments to the procedure come after the procedure on
 * the stack.
 * 
 * The result is returned as a dptr, which will be null if the
 * procedure failed.  This pointer lies just below the interpreter
 * stack pointer, so it should be dereferenced and copied elsewhere if
 * it needs to be kept around.
 * 
 * See call_icon() for a convenient interface to this function.
 *
 */
dptr do_invoke(dptr proc)
{
    word ibuf[11];
    int retval;
    word *saved_ipc = ipc;
    word saved_lastop = lastop;      /* We save these three in case we are in a function */
    dptr saved_xargp = xargp;        /* (lastop==Op_Invoke) which calls runerr() after this */
    word saved_xnargs = xnargs;      /* function returns. */

    word *wp;
    dptr ret;
    int ncopy = (sp + 1 - (word*)proc) / 2;

    wp = ibuf;
    *wp++ = Op_Mark;   
    *wp++ = 8 * WordSize;
    *wp++ = Op_CopyArgs;
    *wp++ = ncopy;
    *wp++ = Op_Invoke;  
    *wp++ = ncopy - 1;
    *wp++ = Op_IpcRef;
    *wp++ = (word)ipc;
    *wp++ = Op_Eret;
    *wp++ = Op_Trapret;
    *wp++ = Op_Trapfail;

    ipc = ibuf;
    retval = interp(0, NULL);

    if (retval == A_Trapret) {
        ret = (dptr)(sp - 1);
        sp -= 2;
    } else
        ret = 0;

    ipc = saved_ipc;
    lastop = saved_lastop;
    xargp = saved_xargp;
    xnargs = saved_xnargs;

    return ret;
}

/*
 * This is a convenient function to call a given icon procedure.  The
 * arguments are provided as varargs, terminated with a null pointer.
 * Each should be a dptr.  
 * 
 * The result is returned as a dptr, which will be null if the
 * procedure failed.  This pointer lies just below the interpreter
 * stack pointer, so it should be dereferenced and copied elsewhere if
 * it needs to be kept around.
 */
dptr call_icon(dptr proc, ...)
{
    dptr res;
    va_list ap;
    va_start(ap, proc);
    res = call_icon_va(proc, ap);
    va_end(ap);
    return res;
}

#passthru #define _DPTR dptr

/*
 * This is used to implement the above function.  It pushes the
 * procedure and all the arguments onto the stack, and then calls
 * do_invoke.
 */
dptr call_icon_va(dptr proc, va_list ap)
{
    dptr a, res, dp = (dptr)(sp + 1);
    PushDesc(*proc);
    for (;;) {
        a = va_arg(ap, _DPTR);
        if (!a)
            break;
        PushDesc(*a);
    }
    res = do_invoke(dp);
    sp = (word *)dp - 1;
    return res;
}

/*
 * Custom invoke for calling new() during object construction.
 */
static dptr do_new_invoke(dptr top)
{
    word ibuf[11];
    int retval;
    word *saved_ipc = ipc;
    word *wp;
    dptr ret;
    int ncopy = (sp + 1 - (word*)top) / 2;

    wp = ibuf;
    *wp++ = Op_Mark;   
    *wp++ = 8 * WordSize;
    *wp++ = Op_CopyArgs2;
    *wp++ = ncopy;
    *wp++ = Op_Invoke;  
    *wp++ = ncopy - 1;
    *wp++ = Op_IpcRef;
    *wp++ = (word)ipc;
    *wp++ = Op_Eret;
    *wp++ = Op_Trapret;
    *wp++ = Op_Trapfail;

    ipc = ibuf;
    retval = interp(0, NULL);

    if (retval == A_Trapret) {
        ret = (dptr)(sp - 1);
        sp -= 2;
    } else
        ret = 0;

    ipc = saved_ipc;

    return ret;
}
