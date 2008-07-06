/*
 * invoke.r - contains invoke, apply
 */

#if E_Ecall
#include "../h/opdefs.h"		/* for Op_Invoke eventvalue */
#endif					/* E_Ecall */

#include "../h/modflags.h"
#include "../h/standardfields.h"

static int invoke_methp(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int invoke_misc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int invoke_proc(int nargs, dptr newargp, dptr *cargp_ptr, int *nargs_ptr);
static int construct_object(int nargs, dptr newargp);


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

    type_case *newargp of {
      class: {
            return construct_object(nargs, newargp);
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

    return invoke_proc(nargs + 1, newargp, cargp_ptr, nargs_ptr);
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
        struct b_proc *tmp;
        /*
         * See if Arg0 can be converted to a string that names a procedure
         *  or operator.  If not, generate run-time error 106.
         */
        if (!cnv:tmp_string(newargp[0],newargp[0]) ||
            ((tmp = strprc(newargp, (C_integer)nargs)) == NULL)) {
            err_msg(106, newargp);
            return I_Fail;
        }
        BlkLoc(newargp[0]) = (union block *)tmp;
        newargp[0].dword = D_Proc;
        return invoke_proc(nargs, newargp, cargp_ptr, nargs_ptr);
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
    struct b_proc *proc;
    int nparam;

    /* 
     * Dereference the supplied arguments.
     */
    proc = (struct b_proc *)BlkLoc(newargp[0]);
    if (proc->nstatic >= 0)	/* if negative, don't reference arguments */
        for (i = 1; i <= nargs; i++)
            Deref(newargp[i]);

    /*
     * Adjust the argument list to conform to what the routine being invoked
     *  expects (proc->nparam).  If nparam is less than 0, the number of
     *  arguments is variable. For functions (ndynam = -1) with a
     *  variable number of arguments, nothing need be done.  For Icon procedures
     *  with a variable number of arguments, arguments beyond abs(nparam) are
     *  put in a list which becomes the last argument.  For fix argument
     *  routines, if too many arguments were supplied, adjusting the stack
     *  pointer is all that is necessary. If too few arguments were supplied,
     *  null descriptors are pushed for each missing argument.
     */

    proc = (struct b_proc *)BlkLoc(newargp[0]);
    nparam = (int)proc->nparam;

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
        if (proc->ndynam >= 0) { /* this is a procedure */
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

            Ollist(lelems, &llargp[-1]);

            llargp[0] = llargp[-1];
            llargp[-1] = arg_sv;
            /*
             *  Reload proc pointer in case Ollist triggered a garbage collection.
             */
            proc = (struct b_proc *)BlkLoc(newargp[0]);
            newsp = (word *)llargp + 1;
            nargs = absnparam;
        }
    }

    if (proc->ndynam < 0) {
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

        EVVal((word)Op_Invoke,E_Ecall);

        if ((nparam < 0) || (proc->ndynam == -2))
            return I_Vararg;
        else
            return I_Builtin;
    }


    /*
     * Build the procedure frame.
     */
    newpfp = (struct pf_marker *)(newsp + 1);
    newpfp->pf_nargs = nargs;
    newpfp->pf_argp = glbl_argp;
    newpfp->pf_pfp = pfp;
    newpfp->pf_ilevel = ilevel;
    newpfp->pf_scan = NULL;

    newpfp->pf_ipc = ipc;
    newpfp->pf_gfp = gfp;
    newpfp->pf_efp = efp;

    glbl_argp = newargp;
    pfp = newpfp;
    newsp += Vwsizeof(*pfp);

    /*
     * If tracing is on, use ctrace to generate a message.
     */   
    if (k_trace) {
        k_trace--;
        ctrace(&(proc->pname), nargs, &newargp[1]);
    }
   
    /*
     * Point ipc at the icode entry point of the procedure being invoked.
     */
    ipc.opnd = (word *)proc->entryp.icode;

    /*
     * Enter the program state of the procedure being invoked
     * and save from/to states in the procedure frame.
     */
    newpfp->pf_from = curpstate;
    newpfp->pf_to = proc->program;
    CHANGEPROGSTATE(newpfp->pf_to);

    efp = 0;
    gfp = 0;

    /*
     * Push a null descriptor on the stack for each dynamic local.
     */
    for (i = proc->ndynam; i > 0; i--) {
        *++newsp = D_Null;
        *++newsp = 0;
    }
    sp = newsp;

    k_level++;

    EVValD(newargp, E_Pcall);

    return I_Continue;
}

static int construct_object(int nargs, dptr newargp)
{
    struct pf_marker *newpfp;
    struct class_field *new_field;
    word *newsp = sp, i;
    tended struct descrip arg_sv;
    int nparam;
    struct b_class *class;
    struct b_object *object;

    class = (struct b_class*)BlkLoc(*newargp);
    ensure_initialized(class);

    Protect(object = alcobject(class), fatalerr(0,NULL));

    new_field = lookup_standard_field(NEW_FIELD, class);
    if (!new_field) {
        /*
         * No constructor function, so just put the object in Arg0.
         */
        newargp[0].dword = D_Object;
        BlkLoc(newargp[0]) = (union block *)object;
    } else {
        int ac;

        /*
         * Check the constructor function is a non-static method.
         */
        if ((new_field->flags & (M_Method | M_Static)) != M_Method) {
            err_msg(605, newargp);
            return I_Fail;
        }

        ac = check_access(new_field, class);
        if (ac != 0) {
            err_msg(ac, newargp);
            return I_Fail;
        }

        /*
         * Shift all the parameters down one to make room for the object
         * param.
         */
        for (i = nargs; i > 0; i--) {
            newargp[i + 1] = newargp[i];
        }

        /*
         * Overwrite the D_Class with the "new" method.
         */
        newargp[0] = *new_field->field_descriptor;

        /*
         * Insert the object parameter (ie, the thing given to the
         * self param in the method).
         */
        newargp[1].dword = D_Object;
        BlkLoc(newargp[1]) = (union block *)object;

        sp += 2;

        object->init_state = Initializing;
        if (!do_invoke(newargp)) {
            BlkLoc(newargp[1])->object.init_state = Initialized;
            return I_Fail;
        }

        /*
         * Put the object param (currently in Arg1), into Arg0.
         */
        newargp[0] = newargp[1];
    }

    /*
     * Set the init flag
     */
    BlkLoc(newargp[0])->object.init_state = Initialized;

    sp = (word *)newargp + 1;
    return I_Continue;
}

void ensure_initialized(struct b_class *class)
{
    struct class_field *init_field;
    dptr pp;
    int i;

    if (class->init_state != Uninitialized)
        return;
    class->init_state = Initializing;

    /*
     * Initialize any superclasses first.
     */
    for (i = 0; i < class->n_supers; ++i)
        ensure_initialized(class->supers[i]);

    /*
     * Look for an init method defined in this class; if not found,
     * then return.
     */
    init_field = lookup_standard_field(INIT_FIELD, class);
    if (init_field && init_field->defining_class == class) {
        /*
         * Check the initial function is a static method.
         */
        if ((init_field->flags & (M_Method | M_Static)) != (M_Method | M_Static)) {
            struct descrip d;
            d.dword = D_Class;
            BlkLoc(d) = (union block *)class;
            fatalerr(606, &d);
        }

        /*
         * Push the init method on the stack, call it, restore stack.
         */
        sp += 2;
        pp = (dptr)(sp - 1);
        *pp = *init_field->field_descriptor;
        do_invoke(pp);
        sp -= 2;
    }
    class->init_state = Initialized;
}

#include "../h/opdefs.h"

/*
 * Invoke the given Icon procedure, which must be a pointer into the
 * stack.  The arguments to the procedure come after the procedure on
 * the stack.
 */
dptr do_invoke(dptr proc)
{
    word ibuf[9];
    int i, off, retval;
    inst saved_ipc = ipc;
    word *saved_sp = sp;
    word saved_lastop = lastop;
    dptr saved_xargp = xargp;
    word saved_xnargs = xnargs;
    inst wp;
    dptr ret;
    int ncopy = (sp + 1 - (word*)proc) / 2;
    wp.opnd = ibuf;
    *wp.op++ = Op_Mark;   
    *wp.opnd++ = 3 * 2 * WordSize;
    *wp.op++ = Op_CopyArgs;
    *wp.opnd++ = ncopy;
    *wp.op++ = Op_Invoke;  
    *wp.opnd++ = ncopy - 1;
    *wp.op++ = Op_Eret;
    *wp.op++ = Op_Trapret;
    *wp.op++ = Op_Trapfail;

    ipc.op = (int *)ibuf;
    retval = interp(0, NULL);

    if (retval == A_Trapret) 
        ret = (dptr)(sp - 1);

    ipc = saved_ipc;
    sp = saved_sp;
    lastop = saved_lastop;
    xargp = saved_xargp;
    xnargs = saved_xnargs;

    if (retval == A_Trapret)
        return ret;
    else
        return 0;
}

/*
 * Helper function to push the given proc and args (a null terminated
 * array of dptrs) onto the stack and call do_invoke above.
 */
dptr do_invoke_with(dptr proc, dptr *args)
{
    dptr res, dp = (dptr)(sp + 1);
    PushDesc(*proc);
    while (*args) {
        PushDesc(**args);
        ++args;
    }
    res = do_invoke(dp);
    sp = (word *)dp - 1;
    return res;
}
