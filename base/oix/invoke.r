/*
 * invoke.r - contains invoke, apply
 */

#include "../h/opdefs.h"
#include "../h/modflags.h"

static struct frame *push_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self);
static void ensure_class_initialized();

static void simple_access();
static void create_raw_object();
static void handle_access_failure();
static void skip_args(int argc, dptr args);
static void set_class_state();
static void check_if_uninitialized();
static void for_class_supers();
static void set_object_state();
static void invoke_class_init();


#include "invokeiasm.ri"

static struct frame *push_frame_for_proc(struct b_proc *bp, int argc, dptr args, dptr self)
{
    int i, j;
    
    if (bp->icode) {
        /* Icon procedure */
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame(bp, 0));
        push_frame((struct frame *)pf);
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
                    else {
                        /* This must be done via a tended temporary */
                        tmp = *get_element(args, j);
                        list_put(&l, &tmp);
                    }
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
            /* Params i ... abs_nparam - 2 are already initialized to nulldesc by alc_p_frame */
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
            /* Remaining args (i ... bp->nparam-1) are already set to nulldesc */
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
        push_frame((struct frame *)cf);

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
        /* Remaining args (i ... want-1) are already set to nulldesc */

        return (struct frame *)cf;
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

    clo = GetWord;
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    get_deref(&args);
    rval = GetWord;
    failure_label = get_addr();
    MakeInt(fno, &query);

    type_case args of {
      list: {
            argc = BlkLoc(args)->list.size;
        }
      record: {
            argc = BlkLoc(args)->record.constructor->n_fields;
        }
      default: {
            xexpr = &expr;
            xfield = &query;
            xargp = &args;
            err_msg(126, &args);
            Ipc = failure_label;
            return;
      }
    }

    general_invokef(clo, &expr, &query, ic, argc, &args, rval, failure_label);
}

void do_invokef()
{
    word clo, argc, rval;
    tended struct descrip expr;
    word fno;
    struct inline_field_cache *ic;
    word *failure_label;
    struct descrip query;

    clo = GetWord;
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    argc = GetWord;
    rval = GetWord;
    failure_label = get_addr();
    MakeInt(fno, &query);

    general_invokef(clo, &expr, &query, ic, argc, 0, rval, failure_label);
}

void do_invoke()
{
    word clo, argc, rval;
    tended struct descrip expr;
    word *failure_label;
    clo = GetWord;
    get_deref(&expr);
    argc = GetWord;
    rval = GetWord;
    failure_label = get_addr();

    general_call(clo, &expr, argc, 0, rval, failure_label);
}

void do_apply()
{
    word clo, argc, rval;
    tended struct descrip expr, args;
    word *failure_label;

    clo = GetWord;
    get_deref(&expr);
    get_deref(&args);
    rval = GetWord;
    failure_label = get_addr();

    type_case args of {
      list: {
            argc = BlkLoc(args)->list.size;
        }
      record: {
            argc = BlkLoc(args)->record.constructor->n_fields;
        }
      default: {
            xexpr = &expr;
            xargp = &args;
            err_msg(126, &args);
            Ipc = failure_label;
            return;
      }
    }

    general_call(clo, &expr, argc, &args, rval, failure_label);
}

/* Skip unwanted params */
static void skip_args(int argc, dptr args)
{
    int i; 
    if (!args) {
        for (i = 0; i < argc; ++i)
            get_deref(&trashcan);
    }
}

static void check_if_uninitialized()
{
    dptr class0 = get_dptr();  /* Class */
    word *a = get_addr();
    if (BlkLoc(*class0)->class.init_state != Uninitialized)
        Ipc = a;
    /*printf("check_if_uninitialized\n");*/
}

static void set_class_state()
{
    dptr class0 = get_dptr();  /* Class */
    struct descrip val;
    get_deref(&val);      /* Value */
    BlkLoc(*class0)->class.init_state = IntVal(val);
    /*printf("set_class_state to %d\n", IntVal(val));*/
}

static void set_object_state()
{
    dptr obj = get_dptr();  /* Object */
    struct descrip val;
    get_deref(&val);      /* Value */
    BlkLoc(*obj)->object.init_state = IntVal(val);
    /*printf("set_class_state to %d\n", IntVal(val));*/
}

static void for_class_supers()
{
    dptr class0 = get_dptr();  /* Class */
    dptr i = get_dptr();       /* Index */
    dptr res = get_dptr();     /* Result */
    word *a = get_addr();      /* Branch when done */
    /*printf("for_class_supers (i=%d of %d)\n", IntVal(*i), BlkLoc(*class0)->class.n_supers);*/

    if (IntVal(*i) < BlkLoc(*class0)->class.n_supers) {
        res->dword = D_Class;
        BlkLoc(*res) = (union block *)BlkLoc(*class0)->class.supers[IntVal(*i)];
        IntVal(*i)++;
    } else
        Ipc = a;
}

static void invoke_class_init()
{
    dptr d = get_dptr();  /* Class */
    word *failure_label = get_addr(); /* Failure label */
    struct b_class *class0 = (struct b_class *)BlkLoc(*d);
    struct class_field *init_field;

    /*printf("invoke_class_init %p\n", class0);*/
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
    if (BlkLoc(*d)->class.init_state != Uninitialized)
        return;
    MemProtect(pf = alc_p_frame((struct b_proc *)&Bensure_class_initialized, 0));
    push_frame((struct frame *)pf);
    pf->locals->args[0] = *d;
    pf->failure_label = Ipc;
    tail_invoke_frame((struct frame *)pf);
}

#begdef invoke_macro(general_call,invoke_methp,invoke_misc,invoke_proc,construct_object,construct_record,e_objectcreate,e_rcreate)

static void construct_record(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void construct_object(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_methp(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_proc(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
static void invoke_misc(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);

void general_call(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    type_case *expr of {
      class: {
            construct_object(clo, expr, argc, args, rval, failure_label);
        }

      constructor: {
            construct_record(clo, expr, argc, args, rval, failure_label);
        }

      methp: {
            invoke_methp(clo, expr, argc, args, rval, failure_label);
        }

      proc: {
            invoke_proc(clo, expr, argc, args, rval, failure_label);
        }

     default: {
            invoke_misc(clo, expr, argc, args, rval, failure_label);
        }
    }
}

void construct_object(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    struct class_field *new_field;
    struct b_class *class0 = (struct b_class*)BlkLoc(*expr);
    struct p_frame *pf;

    new_field = class0->new_field;
    if (new_field) {
        struct frame *new_f;
        struct b_proc *bp = (struct b_proc *)BlkLoc(*new_field->field_descriptor);

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
            Ipc = failure_label;
            return;
        }

        MemProtect(pf = alc_p_frame((struct b_proc *)&Bconstruct_object, 0));
        push_frame((struct frame *)pf);
        /* Arg0 is the class */
        pf->locals->args[0] = *expr;
        /* Arg1 is the allocated new object object */
        /*test_collect(15,0);*/
        MemProtect(BlkLoc(pf->locals->args[1]) = (union block *)alcobject(class0));
        pf->locals->args[1].dword = D_Object; 
        BlkLoc(pf->locals->args[1])->object.init_state = Initializing;

        /* Allocate a frame for the "new" method.  It is invoked from
         * within construct_object */
        new_f = push_frame_for_proc(bp, argc, args, &pf->locals->args[1]);

        /* Set up a mark and closure for the new method.  They are used with Op_Resume and Op_Unmark
         * in construct_object's code to invoke the new method.
         */
        pf->mark[0] = (struct frame *)pf;
        pf->clo[0] = new_f;
    } else {
        skip_args(argc, args);
        MemProtect(pf = alc_p_frame((struct b_proc *)&Bconstruct_object0, 0));
        push_frame((struct frame *)pf);
        /* Arg0 is the class */
        pf->locals->args[0] = *expr;
        /* Arg 1 is a new object */
        MemProtect(BlkLoc(pf->locals->args[1]) = (union block *)alcobject(class0));
        pf->locals->args[1].dword = D_Object; 
    }

    curr_pf->clo[clo] = (struct frame *)pf;
    pf->failure_label = failure_label;
    EVValD(expr, e_objectcreate);
    tail_invoke_frame((struct frame *)pf);
}

static void construct_record(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct p_frame *pf;
    struct b_constructor *con = (struct b_constructor *)BlkLoc(*expr);
    int i;
    tended struct descrip tmp;

    MemProtect(pf = alc_p_frame((struct b_proc *)&Bgenerate_arg, 0));
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
            if (i < con->n_fields) {
                /* Must be in two steps since get_deref can trigger a gc */
                get_deref(&tmp);
                BlkLoc(pf->locals->args[0])->record.fields[i] = tmp;
            } else
                get_deref(&trashcan);
        }
    }

    curr_pf->clo[clo] = (struct frame *)pf;
    pf->failure_label = failure_label;
    EVValD(expr, e_rcreate);
    tail_invoke_frame((struct frame *)pf);
}

static void invoke_proc(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct b_proc *bp = (struct b_proc *)BlkLoc(*expr);
    struct frame *f;
    f = push_frame_for_proc(bp, argc, args, 0);
    curr_pf->clo[clo] = f;
    f->failure_label = failure_label;
    f->rval = rval;
    tail_invoke_frame(f);
}


static void invoke_methp(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label) 
{
    struct b_proc *bp = BlkLoc(*expr)->methp.proc;
    tended struct descrip tmp;
    struct frame *f;
    tmp.dword = D_Object;
    BlkLoc(tmp) = (union block *)BlkLoc(*expr)->methp.object;
    f = push_frame_for_proc(bp, argc, args, &tmp);
    curr_pf->clo[clo] = f;
    f->failure_label = failure_label;
    f->rval = rval;
    tail_invoke_frame(f);
}

static void invoke_misc(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label)
{
    word iexpr;
    tended struct descrip sexpr;

    if (cnv:C_integer(*expr, iexpr)) {
        struct p_frame *pf;

        /* Integer expression; return nth argument */

        int i = cvpos(iexpr, argc);
        if (i == CvtFail || i > argc) {
            Ipc = failure_label;
            return;
        }
        MemProtect(pf = alc_p_frame((struct b_proc *)&Bgenerate_arg, 0));
        push_frame((struct frame *)pf);
        if (args)
            pf->locals->args[0] = *get_element(args, i);
        else {
            int j;
            for (j = 1; j <= argc; ++j) {
                if (i == j)
                    get_deref(&pf->locals->args[0]);
                else
                    get_deref(&trashcan);
            }
        }
        curr_pf->clo[clo] = (struct frame *)pf;
        pf->failure_label = failure_label;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    if (cnv:string(*expr, sexpr)) {
        /*
         * Is it a global class or procedure (or record)?
         */
        dptr p = lookup_global(&sexpr, curpstate);
        if (p) {
            type_case *p of {
              proc:
              constructor:
              class: {
                    general_call(clo, p, argc, args, rval, failure_label);
                    return;
                }
            }
        } else {
            struct b_proc *bp;
            /*
             * Is it a builtin or an operator?
             */
            if ((bp = bi_strprc(&sexpr, argc))) {
                struct frame *f;
                f = push_frame_for_proc(bp, argc, args, 0);
                curr_pf->clo[clo] = f;
                f->failure_label = failure_label;
                f->rval = rval;
                tail_invoke_frame(f);
                return;
            }
        }
    }

    /*
     * Fell through - not a string or not convertible to something invocable.
     */
    skip_args(argc, args);
    xexpr = expr;
    xargp = 0;
    err_msg(106, expr);
    Ipc = failure_label;
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
    word *failure_label;
    struct descrip query;

    lhs = get_dptr();
    get_deref(&expr);
    fno = GetWord;
    ic = get_inline_field_cache();
    failure_label = get_addr();
    MakeInt(fno, &query);

    general_access(lhs, &expr, &query, ic, 0, failure_label);
}

#begdef AccessErr(err_num)
   do {
       if (just_fail) {
           t_errornumber = err_num;
           t_errorvalue = nulldesc;
           t_have_val = 0;
       } else {
           xexpr = expr;
           xargp = 0;
           xfield = query;
           err_msg(err_num, expr);
       }
       Ipc = failure_label;
       return;
   } while (0)
#enddef


#begdef access_macro(general_access, cast_access,instance_access,class_access,record_access,e_objectref,e_objectsub,e_castref,e_castsub,e_classref,e_classsub,e_rref,e_rsub)

static void record_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                          int just_fail, word *failure_label);
static void instance_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                            int just_fail, word *failure_label);
static void cast_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                        int just_fail, word *failure_label);
static void class_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                         int just_fail, word *failure_label);


void general_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                    int just_fail, word *failure_label)
{
    type_case *expr of {
      record: {
            record_access(lhs, expr, query, ic, just_fail, failure_label);
      }

      cast: {
            cast_access(lhs, expr, query, ic, just_fail, failure_label);
      }

      class: {
            class_access(lhs, expr, query, ic, just_fail, failure_label);
      }

      object: {
            instance_access(lhs, expr, query, ic, just_fail, failure_label);
      }
      default: {
          xexpr = expr;
          xargp = 0;
          xfield = query;
          err_msg(624, expr);
          Ipc = failure_label;
          return;
      }
   }
}

static void cast_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                        int just_fail, word *failure_label)
{
    struct b_methp *mp;   /* Doesn't need to be tended */
    struct b_class *obj_class, *cast_class;
    struct class_field *cf;
    int i, ac;

    cast_class = BlkLoc(*expr)->cast.class;
    obj_class = BlkLoc(*expr)->cast.object->class;

    /* Lookup in the cast's class */
    i = lookup_class_field(cast_class, query, ic);
    if (i < 0)
        AccessErr(207);

    cf = cast_class->fields[i];

    if (cf->flags & M_Static) 
        AccessErr(601);

    if (!(cf->flags & M_Method)) 
        AccessErr(628);

    /* Can't access new except whilst initializing */
    if ((cf->flags & M_Special) && BlkLoc(*expr)->cast.object->init_state != Initializing) 
        AccessErr(622);

    ac = check_access(cf, obj_class);
    if (ac == Error) 
        AccessErr(0);

    /*
     * Instance method.
     */
    MemProtect(mp = alcmethp());
    mp->object = BlkLoc(*expr)->cast.object;
    mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
    lhs->dword = D_Methp;
    BlkLoc(*lhs) = (union block *)mp;

    EVValD(expr, e_castref);
    EVVal(i + 1, e_castsub);
}

static void class_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                         int just_fail, word *failure_label)
{
    struct b_class *class0 = &BlkLoc(*expr)->class;
    struct class_field *cf;
    dptr dp;
    int i, ac;

    if (class0->init_state == Uninitialized) {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame((struct b_proc *)&Binitialize_class_and_repeat, 0));
        push_frame((struct frame *)pf);
        pf->locals->args[0] = *expr;
        pf->failure_label = failure_label;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        AccessErr(207);

    cf = class0->fields[i];

    /* Can only access a static field (var or meth) via the class */
    if (!(cf->flags & M_Static)) 
        AccessErr(600);

    /* Can't access static init method via a field */
    if (cf->flags & M_Special) 
        AccessErr(621);

    dp = cf->field_descriptor;
    ac = check_access(cf, 0);

    if (ac == Succeeded &&
        !(cf->flags & M_Method) &&        /* Don't return a ref to a static method */
        (!(cf->flags & M_Const) ||
              (class0->init_state == Initializing &&
               ic &&                      /* No Class.get(..) := ... */
               class0->init_field &&       /* .. and must be in init() method */
               get_current_user_proc() == &BlkLoc(*class0->init_field->field_descriptor)->proc)))
    {
        lhs->dword = D_NamedVar;
        VarLoc(*lhs) = dp;
    } else if (ac == Succeeded || (cf->flags & M_Readable))
        *lhs = *dp;
    else 
        AccessErr(0);

    EVValD(expr, e_classref);
    EVVal(i + 1, e_classsub);
}

static void instance_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                            int just_fail, word *failure_label)
{
    struct b_class *class0;
    struct b_methp *mp;  /* Doesn't need to be tended */
    struct class_field *cf;
    int i, ac;

    class0 = BlkLoc(*expr)->object.class;

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        AccessErr(207);

    cf = class0->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static) 
        AccessErr(601);

    if (cf->flags & M_Method) {
        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && BlkLoc(*expr)->object.init_state != Initializing) 
            AccessErr(601);

        ac = check_access(cf, class0);
        if (ac == Error) 
            AccessErr(0);

        /*
         * Instance method.  Return a method pointer.
         */
        MemProtect(mp = alcmethp());
        mp->object = &BlkLoc(*expr)->object;
        mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
        lhs->dword = D_Methp;
        BlkLoc(*lhs) = (union block *)mp;
    } else {
        ac = check_access(cf, class0);
        if (ac == Succeeded &&
            (!(cf->flags & M_Const) || BlkLoc(*expr)->object.init_state == Initializing))
        {
            /* Return a pointer to the field */
            lhs->dword = D_StructVar + 
                          ((word *)(&BlkLoc(*expr)->object.fields[i]) - (word *)BlkLoc(*expr));
            BlkLoc(*lhs) = BlkLoc(*expr);
        } else if (ac == Succeeded || (cf->flags & M_Readable))
            *lhs = BlkLoc(*expr)->object.fields[i];
        else 
            AccessErr(0);
    }

    EVValD(expr, e_objectref);
    EVVal(i + 1, e_objectsub);
}

static void record_access(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic,
                          int just_fail, word *failure_label)
{
    struct b_constructor *recdef = BlkLoc(*expr)->record.constructor;

    int i = lookup_record_field(recdef, query, ic);
    if (i < 0) 
        AccessErr(207);

    /*
     * Return a pointer to the descriptor for the appropriate field.
     */
    lhs->dword = D_StructVar + ((word *)(&BlkLoc(*expr)->record.fields[i]) - (word *)BlkLoc(*expr));
    BlkLoc(*lhs) = BlkLoc(*expr);

    EVValD(expr, e_rref);
    EVVal(i + 1, e_rsub);
}

#enddef

access_macro(general_access_0, cast_access_0,instance_access_0,class_access_0,record_access_0,0,0,0,0,0,0,0,0)

access_macro(general_access_1, cast_access_1,instance_access_1,class_access_1,record_access_1,E_Objectref,E_Objectsub,E_Castref,E_Castsub,E_Classref,E_Classsub,E_Rref,E_Rsub)


#begdef InvokefErr(err_num)
   do {
       skip_args(argc, args);
       xexpr = expr;
       xargp = 0;
       xfield = query;
       err_msg(err_num, expr);
       Ipc = failure_label;
       return;
   } while (0)
#enddef

#begdef invokef_macro(general_invokef, cast_invokef,instance_invokef,class_invokef,record_invokef,e_objectref,e_objectsub,e_castref,e_castsub,e_classref,e_classsub,e_rref,e_rsub)

static void class_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);
static void cast_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);
static void instance_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);
static void record_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label);


void general_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                     int argc, dptr args, word rval, word *failure_label)
{
    type_case *expr of {
      object: {
            instance_invokef(clo, expr, query, ic, argc, args, rval, failure_label);
      }
      class: {
            class_invokef(clo, expr, query, ic, argc, args, rval, failure_label);
        }
      cast: {
            cast_invokef(clo, expr, query, ic, argc, args, rval, failure_label);
        }
      record: {
            record_invokef(clo, expr, query, ic, argc, args, rval, failure_label);
        }
      default: {
          skip_args(argc, args);
          xexpr = expr;
          xfield = query;
          xargp = 0;
          err_msg(624, expr);
          Ipc = failure_label;
          return;
      }
    }
}

static void class_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                          int argc, dptr args, word rval, word *failure_label)
{
    struct b_class *class0 = &BlkLoc(*expr)->class;
    struct class_field *cf;
    int i, ac;

    if (class0->init_state == Uninitialized) {
        struct p_frame *pf;
        MemProtect(pf = alc_p_frame((struct b_proc *)&Binitialize_class_and_repeat, 0));
        push_frame((struct frame *)pf);
        pf->locals->args[0] = *expr;
        pf->failure_label = failure_label;
        tail_invoke_frame((struct frame *)pf);
        return;
    }

    i = lookup_class_field(class0, query, ic);
    if (i < 0) 
        InvokefErr(207);

    cf = class0->fields[i];

    /* Can only access a static field (var or meth) via the class */
    if (!(cf->flags & M_Static)) 
        InvokefErr(600);

    /* Can't access static init method via a field */
    if (cf->flags & M_Special) 
        InvokefErr(621);

    ac = check_access(cf, 0);
    if (!(ac == Succeeded || (cf->flags & M_Readable))) 
        InvokefErr(0);

    EVValD(expr, e_classref);
    EVVal(i + 1, e_classsub);

    curr_op = Op_Invoke; /* In case of error, ttrace acts like Op_Invoke */
    general_call(clo, cf->field_descriptor, argc, args, rval, failure_label);
}

static void record_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                           int argc, dptr args, word rval, word *failure_label)
{
    struct b_constructor *recdef = BlkLoc(*expr)->record.constructor;
    tended struct descrip tmp;
    int i;

    i = lookup_record_field(recdef, query, ic);
    if (i < 0) 
        InvokefErr(207);

    EVValD(expr, e_rref);
    EVVal(i + 1, e_rsub);

    /* Copy field to a tended descriptor */
    tmp = BlkLoc(*expr)->record.fields[i];
    curr_op = Op_Invoke; /* In case of error, ttrace acts like Op_Invoke */
    general_call(clo, &tmp, argc, args, rval, failure_label);
}


static void cast_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                         int argc, dptr args, word rval, word *failure_label)
{
    struct b_class *obj_class, *cast_class;
    struct class_field *cf;
    int i, ac;
    struct frame *f;
    tended struct descrip tmp;

    cast_class = BlkLoc(*expr)->cast.class;
    obj_class = BlkLoc(*expr)->cast.object->class;

    /* Lookup in the cast's class */
    i = lookup_class_field(cast_class, query, ic);
    if (i < 0) 
        InvokefErr(207);

    cf = cast_class->fields[i];

    if (cf->flags & M_Static) 
        InvokefErr(601);

    if (!(cf->flags & M_Method)) 
        InvokefErr(628);

    /* Can't access new except whilst initializing */
    if ((cf->flags & M_Special) && BlkLoc(*expr)->cast.object->init_state != Initializing) 
        InvokefErr(622);

    ac = check_access(cf, obj_class);
    if (ac == Error) 
        InvokefErr(0);

    EVValD(expr, e_castref);
    EVVal(i + 1, e_castsub);

    /* Create the "self" parameter in a tended descriptor */
    tmp.dword = D_Object;
    BlkLoc(tmp) = (union block *)BlkLoc(*expr)->cast.object;
    f = push_frame_for_proc(&BlkLoc(*cf->field_descriptor)->proc, 
                            argc, args, &tmp);
    curr_pf->clo[clo] = f;
    f->failure_label = failure_label;
    f->rval = rval;
    tail_invoke_frame(f);
}

static void instance_invokef(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                             int argc, dptr args, word rval, word *failure_label)
{
    struct b_class *class0;
    struct class_field *cf;
    int i, ac;
    tended struct descrip tmp;

    class0 = BlkLoc(*expr)->object.class;

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
        if ((cf->flags & M_Special) && BlkLoc(*expr)->object.init_state != Initializing) 
            InvokefErr(622);

        ac = check_access(cf, class0);
        if (ac == Error) 
            InvokefErr(0);

        EVValD(expr, e_objectref);
        EVVal(i + 1, e_objectsub);

        /* Create the "self" param in a tended descriptor */
        tmp.dword = D_Object;
        BlkLoc(tmp) = (union block *)&BlkLoc(*expr)->object;
        f = push_frame_for_proc(&BlkLoc(*cf->field_descriptor)->proc, 
                                argc, args, &tmp);
        curr_pf->clo[clo] = f;
        f->failure_label = failure_label;
        f->rval = rval;
        tail_invoke_frame(f);
    } else {
        ac = check_access(cf, class0);
        if (!(ac == Succeeded || (cf->flags & M_Readable))) 
            InvokefErr(0);

        EVValD(expr, e_objectref);
        EVVal(i + 1, e_objectsub);

        /* Copy field to a tended descriptor */
        tmp = BlkLoc(*expr)->object.fields[i];
        curr_op = Op_Invoke; /* In case of error, ttrace acts like Op_Invoke */
        general_call(clo, &tmp, argc, args, rval, failure_label);
    }
}
#enddef

invokef_macro(general_invokef_0, cast_invokef_0,instance_invokef_0,class_invokef_0,record_invokef_0,0,0,0,0,0,0,0,0)

invokef_macro(general_invokef_1, cast_invokef_1,instance_invokef_1,class_invokef_1,record_invokef_1,E_Objectref,E_Objectsub,E_Castref,E_Castsub,E_Classref,E_Classsub,E_Rref,E_Rsub)


static void simple_access()
{
    dptr lhs, expr, query;
    struct descrip just_fail;
    word *a;
    lhs = get_dptr();
    expr = get_dptr();
    query = get_dptr();
    get_deref(&just_fail);
    a = get_addr();
    general_access(lhs, expr, query, 0, IntVal(just_fail), a);
}

static void handle_access_failure()
{
    struct p_frame *t = curr_pf;
    struct descrip quiet;
    get_deref(&quiet);
    if (is:null(quiet))
        whyf("%s (error %d)", lookup_err_msg(t_errornumber), t_errornumber);
    /* Act as though this frame AND the parent c_frame (ie the getf call) have failed */
    set_curr_pf(curr_pf->caller);
    Ipc = t->parent_sp->failure_label;
    pop_to(t->parent_sp->parent_sp);
}

function{1} lang_Class_get(obj, field)
   body {
      struct p_frame *pf;
      MemProtect(pf = alc_p_frame((struct b_proc *)&Bget_impl, 0));
      push_frame((struct frame *)pf);
      pf->locals->args[0] = obj;
      pf->locals->args[1] = field;
      tail_invoke_frame((struct frame *)pf);
      return nulldesc;
   }
end

function{0,1} lang_Class_getf(obj, field, quiet)
   body {
      struct p_frame *pf;
      MemProtect(pf = alc_p_frame((struct b_proc *)&Bgetf_impl, 0));
      push_frame((struct frame *)pf);
      pf->locals->args[0] = obj;
      pf->locals->args[1] = field;
      pf->locals->args[2] = quiet;
      tail_invoke_frame((struct frame *)pf);
      return nulldesc;
  }
end

static void create_raw_object()
{
    dptr lhs, c;
    tended struct b_object *obj;
    lhs = get_dptr();
    c = get_dptr();
    MemProtect(obj = alcobject(&BlkLoc(*c)->class));
    obj->init_state = Initializing;
    lhs->dword = D_Object;
    BlkLoc(*lhs) = (union block *)obj;
}

function{1} lang_Class_create_raw(c)
   if !is:class(c) then
       runerr(603, c)
    body {
      struct p_frame *pf;
      MemProtect(pf = alc_p_frame((struct b_proc *)&Blang_Class_create_raw_impl, 0));
      push_frame((struct frame *)pf);
      pf->locals->args[0] = c;
      tail_invoke_frame((struct frame *)pf);
      return nulldesc;
    }
end

function{0} lang_Class_complete_raw(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       BlkLoc(o)->object.init_state = Initialized;
       fail;
    }
end

function{1} lang_Class_ensure_initialized(c)
   if !is:class(c) then
       runerr(603, c)
    body {
      struct p_frame *pf;
      /* Avoid creating a frame if we don't need to */
      if (BlkLoc(c)->class.init_state != Uninitialized)
          return c;
      MemProtect(pf = alc_p_frame((struct b_proc *)&Blang_Class_ensure_initialized_impl, 0));
      push_frame((struct frame *)pf);
      pf->locals->args[0] = c;
      tail_invoke_frame((struct frame *)pf);
      return nulldesc;
   }
end
