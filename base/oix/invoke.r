/*
 * invoke.r - contains invoke, apply
 */

#include "../h/opdefs.h"

static struct frame *push_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self);
static void simple_access(void);
static void create_raw_instance(void);
static void handle_access_failure(void);
static void skip_args(int argc, dptr args);
static void set_class_state(void);
static void check_if_uninitialized(void);
static void for_class_supers(void);
static void set_object_state(void);
static void invoke_class_init(void);
static void ensure_class_initialized(void);
static int check_access_ic(struct class_field *cf, struct b_class *instance_class, struct inline_field_cache *ic);


#include "invokeiasm.ri"

static struct frame *push_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self)
{
    int i, j;

    switch (bp->type) {
        case P_Proc: {
            /* Icon procedure */
            struct p_proc *pp = (struct p_proc *)bp;
            struct p_frame *pf;
            MemProtect(pf = alc_p_frame(pp, 0));
            push_frame((struct frame *)pf);
            if (self) {
                pf->fvars->desc[0] = *self;
                i = 1;
            } else
                i = 0;
            if (pp->vararg) {
                /* Varargs, last param is a list */
                tended struct descrip tmp, l;
                create_list(Max(0, argc - pp->nparam + 1 + i), &l);
                if (args) {
                    type_case *args of {
                      list: {
                            struct lgstate state;
                            tended struct b_lelem *le;
                            le = lgfirst(&ListBlk(*args), &state);
                            for (j = 0; j < argc; ++j) {
                                if (i < pp->nparam - 1)
                                    pf->fvars->desc[i++] = le->lslots[state.result];
                                else {
                                    /* This must be done via a tended temporary */
                                    tmp = le->lslots[state.result];
                                    list_put(&l, &tmp);
                                }
                                le = lgnext(&ListBlk(*args), &state, le);
                            }
                        }
                      record: {
                            for (j = 0; j < argc; ++j) {
                                if (i < pp->nparam - 1)
                                    pf->fvars->desc[i++] = RecordBlk(*args).fields[j];
                                else {
                                    /* This must be done via a tended temporary */
                                    tmp = RecordBlk(*args).fields[j];
                                    list_put(&l, &tmp);
                                }
                            }
                        }
                        default: syserr("Unexpected type");
                    }
                } else {
                    for (j = 0; j < argc; ++j) {
                        if (i < pp->nparam - 1)
                            get_deref(&pf->fvars->desc[i++]);
                        else {
                            get_deref(&tmp);
                            list_put(&l, &tmp);
                        }
                    }
                }
                /* Params i ... pp->nparam - 2 are already initialized to nulldesc by alc_p_frame */
                pf->fvars->desc[pp->nparam - 1] = l;
            } else {
                if (args) {
                    type_case *args of {
                      list: {
                            struct lgstate state;
                            struct b_lelem *le = lgfirst(&ListBlk(*args), &state); /* Needn't be tended */
                            for (j = 0; j < argc; ++j) {
                                if (i < pp->nparam)
                                    pf->fvars->desc[i++] = le->lslots[state.result];
                                else
                                    break;
                                le = lgnext(&ListBlk(*args), &state, le);
                            }
                        }
                      record: {
                            for (j = 0; j < argc; ++j) {
                                if (i < pp->nparam)
                                    pf->fvars->desc[i++] = RecordBlk(*args).fields[j];
                                else
                                    break;
                            }
                        }
                        default: syserr("Unexpected type");
                    }
                } else {
                    for (j = 0; j < argc; ++j) {
                        if (i < pp->nparam)
                            get_deref(&pf->fvars->desc[i++]);
                        else
                            skip_descrip();
                    }
                }
                /* Remaining args (i ... pp->nparam-1) are already set to nulldesc */
            }
            return (struct frame *)pf;
        }
        case C_Proc: {
            /* Builtin */
            struct c_proc *cp = (struct c_proc *)bp;
            struct c_frame *cf;
            int want;

            if (self)
                i = 1;
            else
                i = 0;

            if (cp->vararg)
                want = Max(argc + i, cp->nparam - 1);
            else
                want = Max(argc + i, cp->nparam);

            MemProtect(cf = alc_c_frame(cp, want));
            push_frame((struct frame *)cf);

            if (self)
                cf->args[0] = *self;

            if (args) {
                type_case *args of {
                  list: {
                        struct lgstate state;
                        struct b_lelem *le = lgfirst(&ListBlk(*args), &state); /* Needn't be tended */
                        for (j = 0; j < argc; ++j) {
                            cf->args[i++] = le->lslots[state.result];
                            le = lgnext(&ListBlk(*args), &state, le);
                        }
                    }
                  record: {
                        for (j = 0; j < argc; ++j)
                            cf->args[i++] = RecordBlk(*args).fields[j];
                    }
                    default: syserr("Unexpected type");
                }
            } else {
                if (cp->underef) {
                    for (j = 0; j < argc; ++j)
                        get_variable(&cf->args[i++]);
                } else {
                    for (j = 0; j < argc; ++j)
                        get_deref(&cf->args[i++]);
                }
            }
            /* Remaining args (i ... want-1) are already set to nulldesc */

            return (struct frame *)cf;
        }
        default: {
            syserr("Unknown proc type");
            return 0;  /* Not reached */
        }
    }
}

void do_applyf()
{
    word clo, argc, rval;
    tended struct descrip expr, args;
    word fno;
    struct inline_field_cache *ic;
    word *failure_label;
    struct descrip query;
    dptr lhs;

    clo = GetWord;
    lhs = get_dptr();
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    get_deref(&args);
    rval = GetWord;
    failure_label = GetAddr;
    MakeInt(fno, &query);

    type_case args of {
      list: {
            argc = ListBlk(args).size;
        }
      record: {
            argc = RecordBlk(args).constructor->n_fields;
        }
      default: {
            xexpr = &expr;
            xfield = &query;
            xargp = &args;
            err_msg(126, &args);
            return;
      }
    }

    general_invokef(clo, lhs, &expr, &query, ic, argc, &args, rval, failure_label);
}

void do_invokef()
{
    word clo, argc, rval;
    tended struct descrip expr;
    word fno;
    struct inline_field_cache *ic;
    word *failure_label;
    struct descrip query;
    dptr lhs;

    clo = GetWord;
    lhs = get_dptr();
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    argc = GetWord;
    rval = GetWord;
    failure_label = GetAddr;
    MakeInt(fno, &query);

    general_invokef(clo, lhs, &expr, &query, ic, argc, 0, rval, failure_label);
}

void do_invoke()
{
    word clo, argc, rval;
    tended struct descrip expr;
    word *failure_label;
    dptr lhs;

    clo = GetWord;
    lhs = get_dptr();
    get_deref(&expr);
    argc = GetWord;
    rval = GetWord;
    failure_label = GetAddr;

    general_call(clo, lhs, &expr, argc, 0, rval, failure_label);
}

void do_apply()
{
    word clo, argc, rval;
    tended struct descrip expr, args;
    word *failure_label;
    dptr lhs;

    clo = GetWord;
    lhs = get_dptr();
    get_deref(&expr);
    get_deref(&args);
    rval = GetWord;
    failure_label = GetAddr;

    type_case args of {
      list: {
            argc = ListBlk(args).size;
        }
      record: {
            argc = RecordBlk(args).constructor->n_fields;
        }
      default: {
            xexpr = &expr;
            xargp = &args;
            err_msg(126, &args);
            return;
      }
    }

    general_call(clo, lhs, &expr, argc, &args, rval, failure_label);
}

/* Skip unwanted params */
static void skip_args(int argc, dptr args)
{
    int i; 
    if (!args) {
        for (i = 0; i < argc; ++i)
            skip_descrip();
    }
}

static void check_if_uninitialized()
{
    dptr class0 = get_dptr();  /* Class */
    word *a = GetAddr;
    if (ClassBlk(*class0).init_state != Uninitialized)
        ipc = a;
}

static void set_class_state()
{
    dptr class0 = get_dptr();  /* Class */
    struct descrip val;
    get_deref(&val);      /* Value */
    ClassBlk(*class0).init_state = IntVal(val);
}

static void set_object_state()
{
    dptr obj = get_dptr();  /* Object */
    struct descrip val;
    get_deref(&val);      /* Value */
    ObjectBlk(*obj).init_state = IntVal(val);
}

static void for_class_supers()
{
    dptr class0 = get_dptr();  /* Class */
    dptr i = get_dptr();       /* Index */
    dptr res = get_dptr();     /* Result */
    word *a = GetAddr;      /* Branch when done */

    if (IntVal(*i) < ClassBlk(*class0).n_supers) {
        MakeDesc(D_Class, ClassBlk(*class0).supers[IntVal(*i)], res);
        IntVal(*i)++;
    } else
        ipc = a;
}

static void invoke_class_init()
{
    dptr d = get_dptr();  /* Class */
    word *failure_label = GetAddr; /* Failure label */
    struct b_class *class0 = &ClassBlk(*d);
    struct class_field *init_field;

    init_field = class0->init_field;
    if (init_field && init_field->defining_class == class0) {
        struct b_proc *bp;
        struct frame *f;
        /*
         * Check the initial function is a static method.
         */
        if ((init_field->flags & (M_Method | M_Static)) != (M_Method | M_Static))
            syserr("init field not a static method");
        bp = &ProcBlk(*init_field->field_descriptor);
        f = push_frame_for_proc(bp, 0, 0, 0);
        f->failure_label = failure_label;
        tail_invoke_frame(f);
    }
}

static void ensure_class_initialized()
{
    struct p_frame *pf;
    dptr d = get_dptr();
    /* Avoid creating a frame if we don't need to */
    if (ClassBlk(*d).init_state != Uninitialized)
        return;
    MemProtect(pf = alc_p_frame(&Bensure_class_initialized_impl, 0));
    push_frame((struct frame *)pf);
    pf->tmp[0] = *d;
    pf->failure_label = ipc;
    tail_invoke_frame((struct frame *)pf);
}

/*
 * This function wraps check_access(), and uses the given
 * inline_field_cache to avoid calls to that function if possible.
 * There are two cases :-
 * 
 * 1.  if instance_class == 0, then the following are prerequisites
 *        cf must be static, ie cf->flags & M_Static == M_Static, and
 *        ic->class->fields[ic->index] == cf
 *     it follows that check_access(cf, instance_class) is equivalent to
 *                     check_access(ic->class->fields[ic->index], 0)
 * 
 * 2.  if instance_class != 0, then the following are prerequisites
 *        cf must be non-static, ie cf->flags & M_Static == 0, and
 *        ic->class->fields[ic->index] == cf, and
 *        ic->class == instance_class
 *     it follows that check_access(cf, instance_class) is equivalent to
 *                     check_access(ic->class->fields[ic->index], ic->class)
 * 
 * In either case, a former non-Error result can be cached in ic,
 * since the check_access call just depends on the fields of ic.
 * Error returns aren't cached, since they set t_errornumber.
 * 
 * It is important of course that ic->access is reset to 0 whenever
 * the other fields are set.
 */
static int check_access_ic(struct class_field *cf, struct b_class *instance_class, struct inline_field_cache *ic)
{
    int ac;
    if (ic) {
        if (ic->access)
            return ic->access;
        ac = check_access(cf, instance_class);
        if (ac != Error)
            ic->access = ac;
        return ac;
    } else
        return check_access(cf, instance_class);
}

#begdef invoke_macro(general_call,invoke_methp,invoke_misc,invoke_proc,construct_object,construct_record,e_objectcreate,e_rcreate)

static void construct_record(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void construct_object(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_methp(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_proc(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_misc(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);

void general_call(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    type_case *expr of {
      class: {
            construct_object(clo, lhs, expr, argc, args, rval, failure_label);
        }

      constructor: {
            construct_record(clo, lhs, expr, argc, args, rval, failure_label);
        }

      methp: {
            invoke_methp(clo, lhs, expr, argc, args, rval, failure_label);
        }

      proc: {
            invoke_proc(clo, lhs, expr, argc, args, rval, failure_label);
        }

     default: {
         invoke_misc(clo, lhs, expr, argc, args, rval, failure_label);
        }
    }
}

void construct_object(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    struct class_field *new_field;
    struct b_class *class0 = &ClassBlk(*expr);
    struct p_frame *pf;

    if (class0->flags & M_Abstract) {
        xexpr = expr;
        xargp = 0;
        skip_args(argc, args);
        err_msg(605, expr);
        return;
    }

    new_field = class0->new_field;

    if (new_field) {
        struct frame *new_f;
        struct b_proc *bp = &ProcBlk(*new_field->field_descriptor);

        /*
         * Check the constructor function is a non-static method.
         */
        if ((new_field->flags & (M_Method | M_Static)) != M_Method)
            syserr("new field not a non-static method");

        if (check_access(new_field, class0) == Error) {
            xexpr = expr;
            xargp = 0;
            skip_args(argc, args);
            err_msg(0, NULL);
            return;
        }

        MemProtect(pf = alc_p_frame(&Bconstruct_object_impl, 0));
        push_frame((struct frame *)pf);
        pf->lhs = lhs;
        /* Arg0 is the class */
        pf->tmp[0] = *expr;
        /* Arg1 is the allocated new object object */
        MakeDescMemProtect(D_Object, alcobject(class0), &pf->tmp[1]);
        ObjectBlk(pf->tmp[1]).init_state = Initializing;

        /* Allocate a frame for the "new" method.  It is invoked from
         * within construct_object_impl.  The failure label is exported from
         * construct_object_impl.
         */
        new_f = push_frame_for_proc(bp, argc, args, &pf->tmp[1]);
        new_f->failure_label = construct_object_impl_NewFail;

        /* Set up a closure for the new method.  It is used with
         * Op_Resume in construct_object_impl's code to invoke the new
         * method.
         */
        pf->clo[0] = new_f;
    } else {
        skip_args(argc, args);
        MemProtect(pf = alc_p_frame(&Bconstruct_object0_impl, 0));
        push_frame((struct frame *)pf);
        pf->lhs = lhs;
        /* Arg0 is the class */
        pf->tmp[0] = *expr;
        /* Arg 1 is a new object */
        MakeDescMemProtect(D_Object, alcobject(class0), &pf->tmp[1]);
    }

    curr_pf->clo[clo] = (struct frame *)pf;
    pf->failure_label = failure_label;
    EVValD(expr, e_objectcreate);
    tail_invoke_frame((struct frame *)pf);
}

static void construct_record(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct p_frame *pf;
    struct b_constructor *con = &ConstructorBlk(*expr);
    int i;
    tended struct descrip tmp;

    MemProtect(pf = alc_p_frame(&Bgenerate_arg, 0));
    push_frame((struct frame *)pf);
    pf->lhs = lhs;

    MakeDescMemProtect(D_Record, alcrecd(con), &pf->tmp[0]);

    if (args) {
       type_case *args of {
          list: {
               struct lgstate state;
               struct b_lelem *le = lgfirst(&ListBlk(*args), &state); /* Needn't be tended */
               for (i = 0; i < argc; ++i) {
                   if (i < con->n_fields)
                       RecordBlk(pf->tmp[0]).fields[i] = le->lslots[state.result];
                   else
                       break;
                   le = lgnext(&ListBlk(*args), &state, le);
               }
          }
          record: {
             for (i = 0; i < argc; ++i) {
                 if (i < con->n_fields)
                     RecordBlk(pf->tmp[0]).fields[i] = RecordBlk(*args).fields[i];
                 else
                     break;
             }
          }
          default: syserr("Unexpected type");
       }
    } else {
        for (i = 0; i < argc; ++i) {
            if (i < con->n_fields) {
                /* Must be in two steps since get_deref can trigger a gc */
                get_deref(&tmp);
                RecordBlk(pf->tmp[0]).fields[i] = tmp;
            } else
                skip_descrip();
        }
    }

    curr_pf->clo[clo] = (struct frame *)pf;
    pf->failure_label = failure_label;
    EVValD(expr, e_rcreate);
    tail_invoke_frame((struct frame *)pf);
}

static void invoke_proc(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct b_proc *bp = &ProcBlk(*expr);
    struct frame *f;
    f = push_frame_for_proc(bp, argc, args, 0);
    curr_pf->clo[clo] = f;
    f->lhs = lhs;
    f->failure_label = failure_label;
    f->rval = rval;
    tail_invoke_frame(f);
}


static void invoke_methp(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct b_proc *bp = MethpBlk(*expr).proc;
    tended struct descrip tmp;
    struct frame *f;
    MakeDesc(D_Object, MethpBlk(*expr).object, &tmp);
    f = push_frame_for_proc(bp, argc, args, &tmp);
    curr_pf->clo[clo] = f;
    f->lhs = lhs;
    f->failure_label = failure_label;
    f->rval = rval;
    tail_invoke_frame(f);
}

static void invoke_misc(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    word iexpr;
    tended struct descrip sexpr;

    if (cnv:C_integer(*expr, iexpr)) {
        struct p_frame *pf;

        /* Integer expression; return nth argument */

        int i = cvpos_item(iexpr, argc);
        if (i == CvtFail) {
            ipc = failure_label;
            return;
        }
        MemProtect(pf = alc_p_frame(&Bgenerate_arg, 0));
        push_frame((struct frame *)pf);
        pf->lhs = lhs;
        if (args)
            pf->tmp[0] = *get_element(args, i);
        else {
            int j;
            for (j = 1; j <= argc; ++j) {
                if (i == j)
                    get_variable(&pf->tmp[0]);
                else
                    skip_descrip();
            }
        }
        curr_pf->clo[clo] = (struct frame *)pf;
        pf->failure_label = failure_label;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    if (cnv:string(*expr, sexpr)) {
        struct b_proc *bp;
        /*
         * Is it a global class or procedure (or record)?
         */
        dptr p = lookup_named_global(&sexpr, 0, curpstate);
        if (p) {
            /* p must be a proc, class or constructor */
            general_call(clo, lhs, p, argc, args, rval, failure_label);
            return;
        }
        /*
         * Is it a builtin or an operator?
         */
        if ((bp = string_to_proc(&sexpr, argc, 0))) {
            struct frame *f;
            f = push_frame_for_proc(bp, argc, args, 0);
            curr_pf->clo[clo] = f;
            f->lhs = lhs;
            f->failure_label = failure_label;
            f->rval = rval;
            tail_invoke_frame(f);
            return;
        }
    }

    /*
     * Fell through - not a string or not convertible to something invocable.
     */
    skip_args(argc, args);
    xexpr = expr;
    xargp = 0;
    err_msg(106, expr);
}

#enddef

invoke_macro(general_call_0, invoke_methp_0,invoke_misc_0,invoke_proc_0,construct_object_0,construct_record_0,0,0)
invoke_macro(general_call_1, invoke_methp_1,invoke_misc_1,invoke_proc_1,construct_object_1,construct_record_1,E_Objectcreate,E_Rcreate)


void do_field()
{
    dptr lhs;
    tended struct descrip expr;
    word fno;
    struct inline_field_cache *ic;
    struct descrip query;

    lhs = get_dptr();
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    MakeInt(fno, &query);

    general_access(lhs, &expr, &query, ic, 0);
}

#begdef AccessErr(err_num)
   do {
       if (failure_label) {
           if (err_num) {
               t_errornumber = err_num;
               t_errorvalue = nulldesc;
               t_have_val = 0;
           }
           ipc = failure_label;
       } else {
           /* Non-null ic means we have an Op_Field, rather than
            * Class.get(), which comes here via an Op_Custom
            * instruction, for which the x* fields are ignored anyway;
            * but it is tidier to leave them as null rather than set
            * them to nonsense values.
            */
           if (ic) {
               xexpr = expr;
               xargp = 0;
               xfield = query;
           }
           err_msg(err_num, expr);
       }
       return;
   } while (0)
#enddef


#begdef access_macro(general_access, instance_access,class_access,record_access,e_objectref,e_objectsub,e_classref,e_classsub,e_rref,e_rsub)

static void record_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                          word *failure_label);
static void instance_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                            word *failure_label);
static void class_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                         word *failure_label);


void general_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                    word *failure_label)
{
    type_case *expr of {
      record: {
            record_access(lhs, expr, query, ic, failure_label);
      }

      class: {
            class_access(lhs, expr, query, ic, failure_label);
      }

      object: {
            instance_access(lhs, expr, query, ic, failure_label);
      }
      default: {
          /* See comment in AccessErr above. */
          if (ic) {
              xexpr = expr;
              xargp = 0;
              xfield = query;
          }
          err_msg(624, expr);
          return;
      }
   }
}

static void class_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                         word *failure_label)
{
    struct b_class *class0 = &ClassBlk(*expr);
    struct class_field *cf;
    int i, ac;

    if (class0->init_state == Uninitialized) {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame(&Binitialize_class_and_repeat, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = *expr;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        AccessErr(207);

    cf = class0->fields[i];

    if (cf->flags & M_Static) {
        dptr dp;

        /* Can't access static init method via a field */
        if (cf->flags & M_Special) 
            AccessErr(621);

        dp = cf->field_descriptor;
        ac = check_access_ic(cf, 0, ic);
        if (ac == Succeeded &&
            !(cf->flags & M_Method) &&           /* Don't return a ref to a static method */
            (!(cf->flags & M_Const) ||
             (class0->init_state == Initializing &&
              ic &&                              /* No Class.get(..) := ... */
              class0 == cf->defining_class &&    /* No initializing a superclass's field */
              class0->init_field &&              /* .. and must be in init() method */
              (struct b_proc *)get_current_user_proc() == &ProcBlk(*class0->init_field->field_descriptor))))
        {
            if (lhs)
                MakeVarDesc(D_NamedVar, dp, lhs);
        } else if (ac == Error)
            AccessErr(0);
        else {
            if (lhs)
                *lhs = *dp;
        } 
    } else {
        dptr self;
        struct b_class *self_class;
        struct p_frame *pf;

        /* Cannot access an instance field via the class */
        if (!(cf->flags & M_Method)) 
            AccessErr(600);

        pf = get_current_user_frame();
        /* We must be in an instance method */
        if (!pf->proc->field || (pf->proc->field->flags & M_Static))
            AccessErr(606);

        self = &pf->fvars->desc[0];
        if (!is:object(*self))
            syserr("self is not an object");
        self_class = ObjectBlk(*self).class;

        /* 
         * Check the invocation makes sense, ie the method is in a
         * class the object (self) implements
         */
        if (!class_is(self_class, cf->defining_class))
            AccessErr(607);

        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && ObjectBlk(*self).init_state != Initializing) 
            AccessErr(622);

        ac = check_access(cf, self_class);
        if (ac == Error) 
            AccessErr(0);

        /*
         * Return a method pointer.
         */
        if (lhs) {
            struct b_methp *mp;  /* Doesn't need to be tended */
            MemProtect(mp = alcmethp());
            mp->object = &ObjectBlk(*self);
            mp->proc = &ProcBlk(*cf->field_descriptor);
            MakeDesc(D_Methp, mp, lhs);
        }
    }

    EVValD(expr, e_classref);
    EVVal(i + 1, e_classsub);
}

static void instance_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                            word *failure_label)
{
    struct b_class *class0;
    struct class_field *cf;
    int i, ac;

    class0 = ObjectBlk(*expr).class;

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        AccessErr(207);

    cf = class0->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static) 
        AccessErr(601);

    if (cf->flags & M_Method) {
        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && ObjectBlk(*expr).init_state != Initializing) 
            AccessErr(622);

        ac = check_access_ic(cf, class0, ic);
        if (ac == Error) 
            AccessErr(0);

        /*
         * Instance method.  Return a method pointer.
         */
        if (lhs) {
            struct b_methp *mp;  /* Doesn't need to be tended */
            MemProtect(mp = alcmethp());
            mp->object = &ObjectBlk(*expr);
            mp->proc = &ProcBlk(*cf->field_descriptor);
            MakeDesc(D_Methp, mp, lhs);
        }
    } else {
        ac = check_access_ic(cf, class0, ic);
        if (ac == Succeeded &&
            (!(cf->flags & M_Const) || ObjectBlk(*expr).init_state == Initializing))
        {
            /* Return a pointer to the field */
            if (lhs) {
                lhs->dword = D_StructVar + 
                    ((word *)(&ObjectBlk(*expr).fields[i]) - (word *)BlkLoc(*expr));
                BlkLoc(*lhs) = BlkLoc(*expr);
            }
        } else if (ac == Error)
            AccessErr(0);
        else {
            if (lhs)
                *lhs = ObjectBlk(*expr).fields[i];
        } 
    }

    EVValD(expr, e_objectref);
    EVVal(i + 1, e_objectsub);
}

static void record_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic,
                          word *failure_label)
{
    struct b_constructor *recdef = RecordBlk(*expr).constructor;

    int i = lookup_record_field(recdef, query, ic);
    if (i < 0) 
        AccessErr(207);

    /*
     * Return a pointer to the descriptor for the appropriate field.
     */
    if (lhs) {
        lhs->dword = D_StructVar + ((word *)(&RecordBlk(*expr).fields[i]) - (word *)BlkLoc(*expr));
        BlkLoc(*lhs) = BlkLoc(*expr);
    }

    EVValD(expr, e_rref);
    EVVal(i + 1, e_rsub);
}

#enddef

access_macro(general_access_0,instance_access_0,class_access_0,record_access_0,0,0,0,0,0,0)

access_macro(general_access_1,instance_access_1,class_access_1,record_access_1,E_Objectref,E_Objectsub,E_Classref,E_Classsub,E_Rref,E_Rsub)


#begdef InvokefErr(err_num)
   do {
       skip_args(argc, args);
       xexpr = expr;
       xargp = 0;
       xfield = query;
       err_msg(err_num, expr);
       return;
   } while (0)
#enddef

#begdef invokef_macro(general_invokef,instance_invokef,class_invokef,record_invokef,e_objectref,e_objectsub,e_classref,e_classsub,e_rref,e_rsub)

static void class_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);
static void instance_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);
static void record_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);


void general_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                     int argc, dptr args, word rval, word *failure_label)
{
    type_case *expr of {
      object: {
            instance_invokef(clo, lhs, expr, query, ic, argc, args, rval, failure_label);
      }
      class: {
            class_invokef(clo, lhs, expr, query, ic, argc, args, rval, failure_label);
        }
      record: {
            record_invokef(clo, lhs, expr, query, ic, argc, args, rval, failure_label);
        }
      default: {
          skip_args(argc, args);
          xexpr = expr;
          xfield = query;
          xargp = 0;
          err_msg(624, expr);
          return;
      }
    }
}

static void class_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                          int argc, dptr args, word rval, word *failure_label)
{
    struct b_class *class0 = &ClassBlk(*expr);
    struct class_field *cf;
    int i, ac;

    if (class0->init_state == Uninitialized) {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame(&Binitialize_class_and_repeat, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = *expr;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        InvokefErr(207);

    cf = class0->fields[i];

    if (cf->flags & M_Static) {
        /* Can't access static init method via a field */
        if (cf->flags & M_Special) 
            InvokefErr(621);

        ac = check_access_ic(cf, 0, ic);
        if (ac == Error)
            InvokefErr(0);

        EVValD(expr, e_classref);
        EVVal(i + 1, e_classsub);

        curr_op = Op_Invoke; /* In case of error, xtrace acts like Op_Invoke */
        general_call(clo, lhs, cf->field_descriptor, argc, args, rval, failure_label);
    } else {
        struct frame *f;
        dptr self;
        struct p_frame *pf;
        struct b_class *self_class;

        /* Cannot access an instance field via the class */ 
       if (!(cf->flags & M_Method)) 
            InvokefErr(600);

        pf = get_current_user_frame();
        /* We must be in an instance method */
        if (!pf->proc->field || (pf->proc->field->flags & M_Static))
            InvokefErr(606);

        self = &pf->fvars->desc[0];
        if (!is:object(*self))
            syserr("self is not an object");
        self_class = ObjectBlk(*self).class;

        /* 
         * Check the invocation makes sense, ie the method is in a
         * class the object (self) implements
         */
        if (!class_is(self_class, cf->defining_class))
            InvokefErr(607);

        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && ObjectBlk(*self).init_state != Initializing) 
            InvokefErr(622);

        ac = check_access(cf, self_class);
        if (ac == Error) 
            InvokefErr(0);

        EVValD(expr, e_classref);
        EVVal(i + 1, e_classsub);

        f = push_frame_for_proc(&ProcBlk(*cf->field_descriptor), 
                                argc, args, self);
        curr_pf->clo[clo] = f;
        f->lhs = lhs;
        f->failure_label = failure_label;
        f->rval = rval;
        tail_invoke_frame(f);
    }
}

static void record_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                           int argc, dptr args, word rval, word *failure_label)
{
    struct b_constructor *recdef = RecordBlk(*expr).constructor;
    tended struct descrip tmp;
    int i;

    i = lookup_record_field(recdef, query, ic);
    if (i < 0) 
        InvokefErr(207);

    EVValD(expr, e_rref);
    EVVal(i + 1, e_rsub);

    /* Copy field to a tended descriptor */
    tmp = RecordBlk(*expr).fields[i];
    curr_op = Op_Invoke; /* In case of error, xtrace acts like Op_Invoke */
    general_call(clo, lhs, &tmp, argc, args, rval, failure_label);
}

static void instance_invokef(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label)
{
    struct b_class *class0;
    struct class_field *cf;
    int i, ac;
    tended struct descrip tmp;

    class0 = ObjectBlk(*expr).class;

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        InvokefErr(207);

    cf = class0->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static) 
        InvokefErr(601);

    if (cf->flags & M_Method) {
        struct frame *f;

        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && ObjectBlk(*expr).init_state != Initializing) 
            InvokefErr(622);

        ac = check_access_ic(cf, class0, ic);
        if (ac == Error) 
            InvokefErr(0);

        EVValD(expr, e_objectref);
        EVVal(i + 1, e_objectsub);

        /* Create the "self" param in a tended descriptor */
        MakeDesc(D_Object, &ObjectBlk(*expr), &tmp);
        f = push_frame_for_proc(&ProcBlk(*cf->field_descriptor), 
                                argc, args, &tmp);
        curr_pf->clo[clo] = f;
        f->lhs = lhs;
        f->failure_label = failure_label;
        f->rval = rval;
        tail_invoke_frame(f);
    } else {
        ac = check_access_ic(cf, class0, ic);
        if (ac == Error)
            InvokefErr(0);

        EVValD(expr, e_objectref);
        EVVal(i + 1, e_objectsub);

        /* Copy field to a tended descriptor */
        tmp = ObjectBlk(*expr).fields[i];
        curr_op = Op_Invoke; /* In case of error, xtrace acts like Op_Invoke */
        general_call(clo, lhs, &tmp, argc, args, rval, failure_label);
    }
}
#enddef

invokef_macro(general_invokef_0,instance_invokef_0,class_invokef_0,record_invokef_0,0,0,0,0,0,0)

invokef_macro(general_invokef_1,instance_invokef_1,class_invokef_1,record_invokef_1,E_Objectref,E_Objectsub,E_Classref,E_Classsub,E_Rref,E_Rsub)


static void simple_access()
{
    dptr lhs, expr, query;
    word *a;
    lhs = get_dptr();
    expr = get_dptr();
    query = get_dptr();
    a = GetAddr;
    general_access(lhs, expr, query, 0, a);
}

static void handle_access_failure()
{
    whyf("%s (error %d)", lookup_err_msg(t_errornumber), t_errornumber);
}

function lang_Class_get(obj, field)
   body {
      struct p_frame *pf;
      CheckField(field);
      MemProtect(pf = alc_p_frame(&Bget_impl, 0));
      push_frame((struct frame *)pf);
      pf->tmp[0] = obj;
      pf->tmp[1] = field;
      tail_invoke_frame((struct frame *)pf);
      return;
   }
end

function lang_Class_getf(obj, field)
   body {
      struct p_frame *pf;
      CheckField(field);
      MemProtect(pf = alc_p_frame(&Bgetf_impl, 0));
      push_frame((struct frame *)pf);
      pf->tmp[0] = obj;
      pf->tmp[1] = field;
      tail_invoke_frame((struct frame *)pf);
      return;
  }
end

function lang_Class_getq(obj, field)
   body {
      struct p_frame *pf;
      CheckField(field);
      MemProtect(pf = alc_p_frame(&Bgetq_impl, 0));
      push_frame((struct frame *)pf);
      pf->tmp[0] = obj;
      pf->tmp[1] = field;
      tail_invoke_frame((struct frame *)pf);
      return;
  }
end

static void create_raw_instance()
{
    dptr lhs, c;
    tended struct b_object *obj;
    lhs = get_dptr();
    c = get_dptr();
    MemProtect(obj = alcobject(&ClassBlk(*c)));
    obj->init_state = Initializing;
    /* lhs is never null */
    MakeDesc(D_Object, obj, lhs);
    EVValD(lhs, E_Objectcreate);
}

function lang_Class_create_raw_instance_of(c)
   if !is:class(c) then
       runerr(603, c)
    body {
      struct p_frame *pf;
      if (ClassBlk(c).flags & M_Abstract)
          runerr(605, c);
      MemProtect(pf = alc_p_frame(&Blang_Class_create_raw_instance_of_impl, 0));
      push_frame((struct frame *)pf);
      pf->tmp[0] = c;
      tail_invoke_frame((struct frame *)pf);
      return;
    }
end

function lang_Class_create_raw_instance()
    body {
       struct p_proc *caller_proc; 
       struct b_class *cl;
       tended struct descrip result;
       caller_proc = get_current_user_proc();
       if (!caller_proc->field)
           runerr(627);
       cl = caller_proc->field->defining_class;
       if (cl->init_state == Uninitialized)
           syserr("In method of Uninitialized class");
       if (cl->flags & M_Abstract)
           Blkrunerr(605, cl, D_Class);
       MakeDescMemProtect(D_Object, alcobject(cl), &result);
       ObjectBlk(result).init_state = Initializing;
       EVValD(&result, E_Objectcreate);
       return result;
    }
end

function lang_Class_complete_raw_instance(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       ObjectBlk(o).init_state = Initialized;
       return o;
    }
end

function lang_Class_create_instance()
    body {
       struct p_proc *caller_proc; 
       struct b_class *cl;
       tended struct descrip result;
       caller_proc = get_current_user_proc();
       if (!caller_proc->field)
           runerr(627);
       cl = caller_proc->field->defining_class;
       if (cl->init_state == Uninitialized)
           syserr("In method of Uninitialized class");
       if (cl->flags & M_Abstract)
           Blkrunerr(605, cl, D_Class);
       MakeDescMemProtect(D_Object, alcobject(cl), &result);
       ObjectBlk(result).init_state = Initialized;
       EVValD(&result, E_Objectcreate);
       return result;
    }
end

function lang_Class_ensure_initialized(c)
   if !is:class(c) then
       runerr(603, c)
    body {
      struct p_frame *pf;
      struct descrip ret;
      /* Return class Class */
      MakeDesc(D_Class, curr_cf->proc->field->defining_class, &ret);
      /* Avoid creating a frame if we don't need to */
      if (ClassBlk(c).init_state != Uninitialized)
          return ret;
      MemProtect(pf = alc_p_frame(&Blang_Class_ensure_initialized_impl, 0));
      push_frame((struct frame *)pf);
      pf->tmp[0] = c;
      pf->tmp[1] = ret;
      tail_invoke_frame((struct frame *)pf);
      return;
   }
end

/*
 * This operator allows the binary apply (!) operation via string invocation.
 */

operator ! apply(fun, args)
    body {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame(&Bapply_impl, 0));
        push_frame((struct frame *)pf);
        pf->tmp[0] = fun;
        pf->tmp[1] = args;
        for (;;) {
            tail_invoke_frame((struct frame *)pf);
            suspend;
        }
        /* Not reached */
        fail;
    }
end
