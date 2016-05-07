#include "../h/modflags.h"

#if PLAN9
static void stat2list(struct Dir *st, dptr res);
#else
static void stat2list(struct stat *st, dptr res);
#endif

/*
 * Helper method to get a class from a descriptor; if a class
 * descriptor then obviously the block is returned; if an object then
 * the object's class is returned.
 */
static struct b_class *get_class_for(dptr x)
{
    type_case *x of {
      class: 
            return &ClassBlk(*x);
        
      object: 
            return ObjectBlk(*x).class;

     default: 
            ReturnErrVal(620, *x, 0);
    }
#if PLAN9
    return 0;
#endif
}

static struct b_constructor *get_constructor_for(dptr x)
{
    type_case *x of {
      constructor: 
            return &ConstructorBlk(*x);
        
      record: 
            return RecordBlk(*x).constructor;
        
     default: 
            ReturnErrVal(625, *x, 0);
    }
#if PLAN9
    return 0;
#endif
}

static struct b_proc *get_proc_for(dptr x)
{
    type_case *x of {
      proc: 
            return &ProcBlk(*x);
        
      methp: 
            return MethpBlk(*x).proc;
        
     default: 
            ReturnErrVal(631, *x, 0);
    }
#if PLAN9
    return 0;
#endif
}

static struct progstate *get_program_for(dptr x)
{
    type_case *x of {
        null:
             return curpstate;
        coexpr: {
             if (CoexprBlk(*x).main_of)
                return CoexprBlk(*x).main_of;
             else
                ReturnErrVal(632, *x, 0);
        }
        default:
             ReturnErrVal(118, *x, 0);
    }
#if PLAN9
    return 0;
#endif
}

static struct b_coexpr *get_coexpr_for(dptr x)
{
    type_case *x of {
        null:
             return k_current;
        coexpr:
             return &CoexprBlk(*x);
        default:
             ReturnErrVal(118, *x, 0);
    }
#if PLAN9
    return 0;
#endif
}

static void loc_to_list(struct loc *p, dptr res)
{
    struct descrip t;
    create_list(2, res);
    list_put(res, p->fname);
    MakeInt(p->line, &t);
    list_put(res, &t);
}

function classof(o)
    body {
       type_case o of {
         object: return class(ObjectBlk(o).class);
         class: return o; 
         record: return constructor(RecordBlk(o).constructor);
         constructor: return o;
         default: runerr(635, o);
       }       
    }
end

function is(o, target)
    body {
       type_case target of {
         class: {
            if (is:object(o) && class_is(ObjectBlk(o).class, &ClassBlk(target)))
                return target;
            else
                fail;
         }
         constructor: {
            if (is:record(o) && RecordBlk(o).constructor == &ConstructorBlk(target))
                return target;
            else
                fail;
         }
         default: runerr(634, target);
      }
   }
end

/*
 * Evaluate whether target is an implemented class of class.
 */
int class_is(struct b_class *class, struct b_class *target)
{
    int l, r, m;
    word c;

    /* 
     * Different programs never share classes
     */
    if (class->program != target->program)
        return 0;

    l = 0;
    r = (int)class->n_implemented_classes - 1;
    while (l <= r) {
        m = (l + r) / 2;
        c = DiffPtrsBytes(class->implemented_classes[m], target);
        if (c > 0)
            r = m - 1;
        else if (c < 0)
            l = m + 1;
        else
            return 1;
    }
    return 0;
}

convert_to_macro(off_t)
convert_from_macro(off_t)
convert_to_macro(time_t)
convert_from_macro(time_t)
convert_to_macro(mode_t)
convert_from_macro(mode_t)
convert_from_macro(dev_t)
#if UNIX
convert_from_macro(ino_t)
convert_from_macro(blkcnt_t)
convert_to_macro(uid_t)
convert_from_macro(uid_t)
convert_to_macro(gid_t)
convert_from_macro(gid_t)
convert_to_macro(pid_t)
convert_from_macro(pid_t)
#elif PLAN9
convert_to_macro(ulong)
convert_from_macro(ulong)
convert_to_macro(vlong)
convert_from_macro(vlong)
convert_from_macro(uvlong)
convert_from_macro(uint)
#endif
convert_from_macro(ulonglong)
convert_from_macro(uword)

function lang_Prog_get_event_mask(ce)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       return cset(prog->eventmask);
   }
end

function lang_Prog_set_event_mask(cs, ce)
   if !cnv:cset(cs) then 
      runerr(104,cs)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       set_event_mask(prog, &CsetBlk(cs));
       return cs;
   }
end


function errorclear(ce)
   body {
      struct progstate *prog;
      if (!(prog = get_program_for(&ce)))
         runerr(0);
      prog->K_errornumber = 0;
      prog->K_errortext = emptystr;
      prog->K_errorvalue = nulldesc;
      prog->K_errorcoexpr = 0;
      prog->Have_errval = 0;
      return nulldesc;
      }
end

function lang_Prog_get_variable_name(underef v)
   /*
    * v must be a variable
    */
   if !is:variable(v) then
      runerr(111, v);

   body {
      tended struct descrip result;
      getname(&v, &result);
      return result;
   }
end

function lang_Prog_get_variable(s,c)
   if !cnv:string(s) then
      runerr(103, s)

   body {
       int rv;
       struct progstate *prog;
       tended struct descrip result;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       rv = getvar(&s, &result, prog);
       if (rv == Failed)
           fail;

       /* Dereference frame vars unless they're in the frame of the
        * caller of this func */
       if (prog != curpstate && ((rv == LocalName) || (rv == ParamName)))
           Deref(result);

       return result;
   }
end


function lang_Prog_eval_keyword(s,c)
   if !cnv:string(s) then 
      runerr(103, s)

   body {
      struct progstate *p;
      char *t;

       if (!(p = get_program_for(&c)))
          runerr(0);

       if (StrLen(s) > 0 && *StrLoc(s) == '&') {
           t = StrLoc(s) + 1;
           switch (StrLen(s)) {
               case 4 : {
                   if (strncmp(t,"pos",3) == 0) {
                       return kywdpos(&(p->Kywd_pos));
                   }
                   if (strncmp(t,"why",3) == 0) {
                       return kywdstr(&(p->Kywd_why));
                   }
                   break;
               }
               case 5 : {
                   if (strncmp(t,"file",4) == 0) {
                       struct ipc_fname *t = frame_ipc_fname(p->K_current->curr_pf);
                       if (!t)
                           fail;
                       return *t->fname;
                   }
                   if (strncmp(t,"line",4) == 0) {
                       struct ipc_line *t = frame_ipc_line(p->K_current->curr_pf);
                       if (!t)
                           fail;
                       return C_integer t->line;
                   }
                   if (strncmp(t,"dump",4) == 0) {
                       return kywdint(&(p->Kywd_dump));
                   }
                   if (strncmp(t,"main",4) == 0) {
                       return coexpr(p->K_main);
                   }
                   if (strncmp(t,"time",4) == 0) {
                       /*
                        * &time in this program = total time - time spent in other programs
                        */
                       if (p != curpstate)
                           return C_integer p->Kywd_time_out - p->Kywd_time_elsewhere;
                       else
                           return C_integer millisec() - p->Kywd_time_elsewhere;
                   }
                   break;
               }
               case 6 : {
                   if (strncmp(t,"trace",5) == 0) {
                       return kywdint(&(p->Kywd_trace));
                   }
                   if (strncmp(t,"level",5) == 0) {
                       return C_integer p->K_current->level;
                   }
                   break;
               }
               case 7 : {
                   if (strncmp(t,"random",6) == 0) {
                       return kywdint(&(p->Kywd_ran));
                   }
                   if (strncmp(t,"source",6) == 0) {
                       return coexpr(p->K_current->activator);
                   }
                   break;
               }
               case 8 : {
                   if (strncmp(t,"subject",7) == 0) {
                       return kywdsubj(&(p->Kywd_subject));
                   }
                   if (strncmp(t,"current",7) == 0) {
                       return coexpr(p->K_current);
                   }
                   if (strncmp(t,"handler",7) == 0) {
                       return kywdhandler(&(p->Kywd_handler));
                   }
                   break;
               }
               case 9 : {
                   if (strncmp(t,"maxlevel",8) == 0) {
                       return kywdint(&(p->Kywd_maxlevel));
                   }
                   if (strncmp(t,"progname",8) == 0) {
                       return kywdstr(&(p->Kywd_prog));
                   }
                   break;
               }
               case 10: {
                   if (strncmp(t,"errortext",9) == 0) {
                       if (p->K_errornumber == 0)
                           fail;
                       return p->K_errortext;
                   }
                   break;
               }

               case 11 : {
                   if (strncmp(t,"errorvalue",10) == 0) {
                       if (!p->Have_errval)
                           fail;
                       return p->K_errorvalue;
                   }
                   break;
               }
               case 12 : {
                   if (strncmp(t,"errorcoexpr",11) == 0) {
                       if (p->K_errornumber == 0)
                           fail;
                       return coexpr(p->K_errorcoexpr);
                   }
                   if (strncmp(t,"errornumber",11) == 0) {
                       if (p->K_errornumber <= 0)
                           fail;
                       return C_integer p->K_errornumber;
                   }
                   break;
               }
           }
       }
       runerr(637, s);
   }
end

function lang_Prog_get_global_impl(q, c)
   body {
       struct progstate *prog;
       int i;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       CheckField(q);
       i = lookup_global(&q, prog);
       if (i < 0)
           fail;
       if (prog->Gflags[i] & G_Const)
           return prog->Globals[i];
       else
           return named_var(&prog->Globals[i]);
   }
end

function lang_Prog_get_n_globals(c)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       return C_integer prog->NGlobals;
   }
end

function lang_Prog_get_global_flags(q, c)
   body {
       struct progstate *prog;
       int i;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       CheckField(q);
       i = lookup_global(&q, prog);
       if (i < 0)
           fail;
       return C_integer prog->Gflags[i];
   }
end

function lang_Prog_get_global_index(q, c)
   body {
       struct progstate *prog;
       int i;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       CheckField(q);
       i = lookup_global(&q, prog);
       if (i < 0)
           fail;
       return C_integer i + 1;
   }
end

function lang_Prog_get_global_name(q, c)
   body {
       struct progstate *prog;
       int i;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       CheckField(q);
       i = lookup_global(&q, prog);
       if (i < 0)
           fail;
       return *prog->Gnames[i];
   }
end

function lang_Prog_get_functions()
   body {
      int i;

      for (i = 0; i < fnc_tbl_sz; ++i)
          suspend proc(fnc_tbl[i]);

      fail;
   }
end

function lang_Prog_get_operators()
   body {
      int i;

      for (i = 0; i < op_tbl_sz; ++i)
          suspend proc(op_tbl[i]);

      fail;
   }
end

function lang_Prog_get_keywords()
   body {
      int i;

      for (i = 0; i < keyword_tbl_sz; ++i)
          suspend proc(keyword_tbl[i]);

      fail;
   }
end

/*
 * proc_name_cmp - do a string comparison of a descriptor to the procedure 
 *   name in a b_proc struct; used in call to bsearch().
 */
static int proc_name_cmp(dptr dp, struct b_proc **e)
{
    return lexcmp(dp, (*e)->name);
}

function lang_Prog_get_function(s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      struct b_proc **p;
      p = (struct b_proc **)bsearch(&s, fnc_tbl, fnc_tbl_sz,
                                    sizeof(struct b_proc *), 
                                    (BSearchFncCast)proc_name_cmp);
      if (p)
          return proc(*p);
      fail;
   }
end

function lang_Prog_get_operator(s, n)
   if !cnv:string(s) then
      runerr(103, s)
   if !cnv:C_integer(n) then
      runerr(101, n)
   body {
       int i;
       if (n < 1 || n > 3)
           Irunerr(205, n);
       for (i = 0; i < op_tbl_sz; ++i)
           if (eq(&s, op_tbl[i]->name) && n == op_tbl[i]->nparam)
               return proc(op_tbl[i]);
       fail;
   }
end

function lang_Prog_get_keyword(s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      struct b_proc **p;
      p = (struct b_proc **)bsearch(&s, keyword_tbl, keyword_tbl_sz,
                                    sizeof(struct b_proc *), 
                                    (BSearchFncCast)proc_name_cmp);
      if (p)
          return proc(*p);
      fail;
   }
end


function lang_Prog_get_global_location_impl(q, c)
   body {
       struct progstate *prog;
       struct loc *p;
       int i;
       tended struct descrip result;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       CheckField(q);

       if (prog->Glocs == prog->Eglocs) {
           LitWhy("No global location data in icode");
           fail;
       }

       i = lookup_global(&q, prog);
       if (i < 0) {
           LitWhy("Unknown symbol");
           fail;
       }

       p = prog->Glocs + i;

       if (!p->fname) {
           LitWhy("Symbol is builtin, has no location");
           fail;
       }

       loc_to_list(p, &result);
       return result;
   }
end

function lang_Coexpression_get_program(ce)
   body {
       struct b_coexpr *b;
       struct progstate *p;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       /*
        * get_current_program_of() shouldn't be used for k_current in
        * a native method, since tail_invoke_frame will have set
        * curpstate to the enclosing class's defining program.
        */
       if (b == k_current)
           p = curpstate;
       else
           p = get_current_program_of(b);
       return coexpr(p->K_main);
   }
end

function lang_Coexpression_get_activator(ce)
    body {
       struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
        if (!b->activator)
            fail;
        return coexpr(b->activator);
    }
end

function lang_Coexpression_get_level(ce)
    body {
       struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       return C_integer b->level;
    }
end

function lang_Coexpression_is_main(ce)
   body {
       struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       if (b->main_of)
           return ce;
       else
           fail;
   }
end

function lang_Coexpression_print_stack(ce)
    body {
       struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       showstack(stderr, b);
       fail;
    }
end

function display(i, ce)
   if !def:C_integer(i, -1) then
      runerr(101, i)
   body {
      struct b_coexpr *b;
      if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       xdisp(b, i, stderr);
       return nulldesc;
   }
end

function lang_Prog_get_runtime_millis(c)
   body {
       struct progstate *prog;
       struct timeval tp;
       struct descrip ls, lm;
       tended struct descrip lt, result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

      if (gettimeofday(&tp, 0) < 0) {
          errno2why();
          fail;
      }
      MakeInt(tp.tv_sec - prog->start_time.tv_sec, &ls);
      MakeInt((tp.tv_usec - prog->start_time.tv_usec) / 1000, &lm);
      bigmul(&ls, &thousanddesc, &lt);
      bigadd(&lt, &lm, &result);
      return result;
   }
end

function lang_Prog_get_startup_micros(c)
   body {
       struct progstate *prog;
       struct descrip ls, lm;
       tended struct descrip lt, result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       MakeInt(prog->start_time.tv_sec, &ls);
       MakeInt(prog->start_time.tv_usec, &lm);
       bigmul(&ls, &milliondesc, &lt);
       bigadd(&lt, &lm, &result);
       return result;
   }
end

function lang_Prog_get_collection_info_impl(c)
   body {
       struct progstate *prog;
       struct descrip tmp;
       tended struct descrip result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       create_list(4, &result);
       MakeInt(prog->colluser, &tmp);
       list_put(&result, &tmp);
       MakeInt(prog->collstack, &tmp);
       list_put(&result, &tmp);
       MakeInt(prog->collstr, &tmp);
       list_put(&result, &tmp);
       MakeInt(prog->collblk, &tmp);
       list_put(&result, &tmp);
       return result;
   }
end

function lang_Prog_get_global_collection_count()
   body {
       return C_integer collection_count;
   }
end

function lang_Prog_get_allocation_info_impl(c)
   body {
       struct progstate *prog;
       tended struct descrip tmp, result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       create_list(2, &result);
       convert_from_ulonglong(prog->stringtotal, &tmp);
       list_put(&result, &tmp);
       convert_from_ulonglong(prog->blocktotal, &tmp);
       list_put(&result, &tmp);
       return result;
   }
end

function lang_Prog_get_region_info_impl(c)
   body {
       struct progstate *prog;
       struct region *rp;
       tended struct descrip l, tmp, result;
       int n;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       create_list(2, &result);

       n = 0;
       for (rp = prog->stringregion; rp; rp = rp->next)
           ++n;
       for (rp = prog->stringregion->prev; rp; rp = rp->prev)
           ++n;
       create_list(2 * n, &l);
       list_put(&result, &l);
       for (rp = prog->stringregion; rp; rp = rp->next) {
           convert_from_uword(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           convert_from_uword(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }
       for (rp = prog->stringregion->prev; rp; rp = rp->prev) {
           convert_from_uword(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           convert_from_uword(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }

       n = 0;
       for (rp = prog->blockregion; rp; rp = rp->next)
           ++n;
       for (rp = prog->blockregion->prev; rp; rp = rp->prev)
           ++n;
       create_list(2 * n, &l);
       list_put(&result, &l);
       for (rp = prog->blockregion; rp; rp = rp->next) {
           convert_from_uword(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           convert_from_uword(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }
       for (rp = prog->blockregion->prev; rp; rp = rp->prev) {
           convert_from_uword(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           convert_from_uword(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }

       return result;
   }
end

function lang_Prog_get_stack_used(c)
   body {
       struct progstate *prog;
       tended struct descrip result;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       convert_from_uword(prog->stackcurr, &result);
       return result;
   }
end

struct b_proc *string_to_proc(dptr s, int arity, struct progstate *prog)
{
    int i;
    dptr t;
    struct b_proc **pp;

    if (!StrLen(*s))
        return NULL;

   /*
    * See if the string is the name of a global variable in prog.
    */
    if (prog && (t = lookup_named_global(s, 0, prog))) {
       if (is:proc(*t))
           return &ProcBlk(*t);
   }

    /*
     * See if the string represents an operator. In this case the arity
     *  of the operator must match the one given.
     */
    if (arity && !isalpha((unsigned char)*StrLoc(*s)) && (StrLen(*s) == 1 || *StrLoc(*s) != '&')) {
        for (i = 0; i < op_tbl_sz; ++i)
            if (eq(s, op_tbl[i]->name) && arity == op_tbl[i]->nparam)
                return (struct b_proc *)op_tbl[i];
        return 0;
    }

    /*
     * See if the string represents a built-in function.
     */
    pp = (struct b_proc **)bsearch(s, fnc_tbl, fnc_tbl_sz,
                                   sizeof(struct b_proc *), 
                                   (BSearchFncCast)proc_name_cmp);
    if (pp)
        return *pp;

    /*
     * See if the string represents a keyword function.
     */
    pp = (struct b_proc **)bsearch(s, keyword_tbl, keyword_tbl_sz,
                                   sizeof(struct b_proc *), 
                                   (BSearchFncCast)proc_name_cmp);
    if (pp)
        return *pp;

    return 0;
}

function proc(x, n, c)

   if is:proc(x) then {
      body {
         return x;
         }
      }

   else if cnv:string(x) then {
      /*
       * n must be 1, 2, or 3; it defaults to 1.
       */
      if !def:C_integer(n, 1) then
         runerr(101, n)
      body {
         struct b_proc *p;
	 struct progstate *prog;

         if (n < 1 || n > 3)
            Irunerr(205, n);

         if (!(prog = get_program_for(&c)))
             runerr(0);

         p = string_to_proc(&x, n, prog);
         if (p)
             return proc(p);
         else
             fail;
      }
   }
   else {
      body {
         fail;
      }
   }
end

function lang_Class_get_name(c)
    body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return *class0->name;
    }
end

function lang_Class_get_class(c)
    body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return class(class0);
    }
end

function lang_Class_get_program(c)
    body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return coexpr(class0->program->K_main);
    }
end

function lang_Class_get_supers(c)
    body {
        struct b_class *class0;
        word i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class0->n_supers; ++i)
            suspend class(class0->supers[i]);
        fail;
    }
end

function lang_Class_get_implemented_classes(c)
    body {
        struct b_class *class0;
        word i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class0->n_implemented_classes; ++i)
            suspend class(class0->implemented_classes[i]);
        fail;
    }
end

function lang_Class_implements(c, target)
   if !is:class(target) then
       runerr(603, target)
    body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        if (class_is(class0, &ClassBlk(target)))
            return target;
        else
            fail;
    }
end

function lang_Class_get_methp_object(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
       return object(MethpBlk(mp).object);
    }
end

function lang_Class_get_methp_proc(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
        return proc(MethpBlk(mp).proc);
    }
end

function lang_Decode_decode_methp_impl(obj, cl, fn, target)
   if !is:object(obj) then
       runerr(602, obj)
   if !is:class(cl) then
       runerr(603, cl)
   if !is:string(fn) then
      runerr(103, fn)
   if !is:methp(target) then
       runerr(613, target)
    body {
       int i;
       struct class_field *cf;
       struct b_class *class0 = &ClassBlk(cl);

       if (!class_is(ObjectBlk(obj).class, class0)) {
           LitWhy("Object doesn't implement class");
           fail;
       }
       i = lookup_class_field(class0, &fn, 0);
       if (i < 0) {
           LitWhy("Field not found");
           fail;
       }
       cf = class0->fields[i];
       if ((cf->flags & (M_Method | M_Static | M_Special)) != M_Method) {
           LitWhy("Field not a valid instance method");
           fail;
       }
       if (BlkLoc(*cf->field_descriptor) == (union block *)&Bdeferred_method_stub) {
           LitWhy("Field is the deferred method stub");
           fail;
       }
       MethpBlk(target).object = &ObjectBlk(obj);
       MethpBlk(target).proc = &ProcBlk(*cf->field_descriptor);
       return target;
    }
end

function lang_Class_set_methp(mp, obj, p)
   if !is:methp(mp) then
       runerr(613, mp)
   if !is:object(obj) then
       runerr(602, obj)
   if !is:proc(p) then
       runerr(615, p)
    body {
       MethpBlk(mp).object = &ObjectBlk(obj);
       MethpBlk(mp).proc = &ProcBlk(p);
       return mp;
    }
end

function lang_Class_get_field_flags(c, field)
   body {
        struct b_class *class0;
        int i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class0, &field, 0);
        if (i < 0)
            fail;
        return C_integer class0->fields[i]->flags;
     }
end

function lang_Class_get_class_flags(c)
   body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return C_integer class0->flags;
     }
end

function lang_Class_get_field_index(c, field)
   body {
        struct b_class *class0;
        int i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class0, &field, 0);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function lang_Class_get_field_name(c, field)
   body {
        struct b_class *class0;
        int i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class0, &field, 0);
        if (i < 0)
            fail;
        return *class0->program->Fnames[class0->fields[i]->fnum];
     }
end

function lang_Class_get_field_location_impl(c, field)
   body {
        struct b_class *class0;
        int i;
        tended struct descrip result;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        if (class0->program->ClassFieldLocs == class0->program->EClassFieldLocs) {
            LitWhy("No field location data in icode");
            fail;
        }
        i = lookup_class_field(class0, &field, 0);
        if (i < 0) {
            LitWhy("Unknown field");
            fail;
        }
        loc_to_list(&class0->program->ClassFieldLocs[class0->fields[i] - class0->program->ClassFields],
                    &result);
        return result;
     }
end

function lang_Class_get_field_defining_class(c, field)
   body {
        struct b_class *class0;
        int i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class0, &field, 0);
        if (i < 0)
            fail;
        return class(class0->fields[i]->defining_class);
     }
end

function lang_Class_get_n_class_fields(c)
   body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return C_integer class0->n_class_fields;
     }
end

function lang_Class_get_n_instance_fields(c)
   body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return C_integer class0->n_instance_fields;
     }
end

struct b_proc *clone_b_proc(struct b_proc *bp)
{
    struct b_proc *new0;
    switch (bp->type) {
        case P_Proc: {
            new0 = rt_malloc(sizeof(struct p_proc));
            memcpy(new0, bp, sizeof(struct p_proc));
            break;
        }
        case C_Proc: {
            new0 = rt_malloc(sizeof(struct c_proc));
            memcpy(new0, bp, sizeof(struct c_proc));
            break;
        }
        default: {
            syserr("Unknown proc type");
            return 0;  /* Not reached */
        }
    }
    return new0;
}

#if HAVE_LIBDL

static struct b_proc *try_load(void *handle, struct b_class *class0,  struct class_field *cf)
{
    word i;
    char *fq, *p, *t;
    struct b_proc *blk;
    dptr fname;

    fname = class0->program->Fnames[cf->fnum];
    fq = rt_malloc(StrLen(*class0->name) + StrLen(*fname) + 3);
    p = fq;
    *p++ = 'B';
    t = StrLoc(*class0->name);
    for (i = 0; i < StrLen(*class0->name); ++i)
        *p++ = (t[i] == '.') ? '_' : t[i];
    *p++ = '_';
    strncpy(p, StrLoc(*fname), StrLen(*fname));
    p[StrLen(*fname)] = 0;

    blk = (struct b_proc *)dlsym(handle, fq);
    if (!blk) {
        free(fq);
        return 0;
    }

    /* Sanity check. */
    if (blk->title != T_Proc)
        ffatalerr("lang.Class.load_library() - symbol %s not a procedure block\n", fq);

    free(fq);

    return blk;
}

static void *get_handle(char *filename)
{
    static char *curfile;
    static void *handle;
    /*
     * Get a library handle, reusing it over successive calls.
     */
    if (!handle || !curfile || strcmp(filename, curfile) != 0) {
        free(curfile);	/* free the old file name if any */
        curfile = salloc(filename);	/* save the new name */
        handle = dlopen(filename, RTLD_LAZY);	/* get the handle */
    }
    return handle;
}

function lang_Class_load_library(lib)
   if !cnv:C_string(lib) then
      runerr(103, lib)
   body {
        struct p_proc *caller_proc;
        struct b_class *class0;
        word i;
        void *handle;

        caller_proc = get_current_user_proc();
        if (!caller_proc->field)
            runerr(616);
        class0 = caller_proc->field->defining_class;
        if (class0->init_state != Initializing)
            runerr(617);

        handle = get_handle(lib);
        if (!handle) {
            why(dlerror());
            fail;
        }

        for (i = 0; i < class0->n_instance_fields + class0->n_class_fields; ++i) {
            struct class_field *cf = class0->fields[i];
            if ((cf->defining_class == class0) &&
                (cf->flags & M_Native) &&
                BlkLoc(*cf->field_descriptor) == (union block *)&Bdeferred_method_stub) {
                struct b_proc *bp = try_load(handle, class0, cf);
                if (bp) {
                    bp = clone_b_proc(bp);
                    BlkLoc(*cf->field_descriptor) = (union block *)bp;
                    bp->field = cf;
                }
            }
        }

        return nulldesc;
   }
end

function lang_Proc_load(filename, funcname)
    if !cnv:C_string(filename) then
        runerr(103, filename)
    if !cnv:C_string(funcname) then
        runerr(103, funcname)
    body {
       struct b_proc *blk;
       char *tname;
       void *handle;

       handle = get_handle(filename);
       if (!handle) {
           why(dlerror());
           fail;
       }
       /*
        * Load the function.  Diagnose both library and function errors here.
        */
       tname = rt_malloc(strlen(funcname) + 2);
       sprintf(tname, "B%s", funcname);
       blk = (struct b_proc *)dlsym(handle, tname);
       if (!blk) {
           free(tname);
           whyf("Symbol '%s' not found in library", funcname);
           fail;
       }
       /* Sanity check. */
       if (blk->title != T_Proc)
           ffatalerr("lang.Proc.load - symbol %s not a procedure block\n", tname);

       free(tname);
       return proc(blk);
    }
end

#else						/* HAVE_LIBDL */
function lang_Class_load_library(lib)
   body {
     Unsupported;
   }
end

function lang_Proc_load(filename,funcname)
   body {
     Unsupported;
   }
end
#endif						/* HAVE_LIBDL */

function parser_UReader_raw_convert(s)
   if !is:string(s) then
      runerr(103, s)
   body {
       char *p = StrLoc(s);
       if (StrLen(s) == 2) {
           union {
               unsigned char c[2];
               unsigned Integer16 s;
           } i;
           i.c[0] = p[0];
           i.c[1] = p[1];
           return C_integer i.s;
       }
       if (StrLen(s) == 4) {
           union {
               unsigned char c[4];
               unsigned Integer32 w;
           } i;
           i.c[0] = p[0];
           i.c[1] = p[1];
           i.c[2] = p[2];
           i.c[3] = p[3];
           return C_integer i.w;
       }
       fail;
   }
end

#if MSWIN32
function io_WindowsFileSystem_get_roots()
    body {
        tended struct descrip result;
        DWORD n = GetLogicalDrives();
        char t[4], c = 'A';
	strcpy(t, "?:\\");
        while (n) {
	   if (n & 1) {
	      t[0] = c;
	      cstr2string(t, &result);
              suspend result;
	   }
	   n /= 2;
	   ++c;
	}
        fail;
    }
end

function io_WindowsFileSystem_getdcwd(d)
   if !cnv:string(d) then
      runerr(103, d)
   body {
      tended struct descrip result;
      char *p;
      int dir;
      if (StrLen(d) != 1)
	 fail;
      dir = toupper((unsigned char)*StrLoc(d)) - 'A' + 1;
      p = _getdcwd(dir, 0, 32);
      if (!p)
	 fail;
      cstr2string(p, &result);
      free(p);
      return result;
   }
end

#endif

struct sdescrip fdf = {2, "fd"};
struct sdescrip dsclassname = {13, "io.DescStream"};

#begdef GetSelfFd()
int self_fd;
dptr self_fd_dptr;
static struct inline_field_cache self_fd_ic;
self_fd_dptr = c_get_instance_data(&self, (dptr)&fdf, &self_fd_ic);
if (!self_fd_dptr)
    syserr("Missing fd field");
self_fd = (int)IntVal(*self_fd_dptr);
if (self_fd < 0)
    runerr(219, self);
#enddef

#if PLAN9
function io_FileStream_open_impl(path, flags)
   if !cnv:C_string(path) then
      runerr(103, path)
   if !cnv:C_integer(flags) then
      runerr(101, flags)
   body {
       int fd;
       fd = open(path, flags);
       if (fd < 0) {
           errno2why();
           fail;
       }
       return C_integer fd;
   }
end

function io_FileStream_create_impl(path, flags, mode)
   if !cnv:C_string(path) then
      runerr(103, path)
   if !cnv:C_integer(flags) then
      runerr(101, flags)
   if !def:integer(mode, 0664, mode) then
      runerr(101, mode)
   body {
       int fd;
       ulong c_mode;
       if (!convert_to_ulong(&mode, &c_mode))
           runerr(0);
       fd = create(path, flags, c_mode);
       if (fd < 0) {
           errno2why();
           fail;
       }
       return C_integer fd;
   }
end
#else
function io_FileStream_new_impl(path, flags, mode)
   if !cnv:C_string(path) then
      runerr(103, path)
   if !cnv:C_integer(flags) then
      runerr(101, flags)
#if UNIX
   if !def:integer(mode, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) then
      runerr(101, mode)
#else
   if !def:integer(mode, 0664) then
      runerr(101, mode)
#endif
   body {
       int fd;
       mode_t c_mode;
       if (!convert_to_mode_t(&mode, &c_mode))
           runerr(0);
#if MSWIN32
       fd = open(path, flags | O_BINARY, c_mode);
#else
       fd = open(path, flags, c_mode);
#endif
       if (fd < 0) {
           errno2why();
           fail;
       }
       return C_integer fd;
   }
end
#endif

function io_FileStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0)
           Irunerr(205, i);

       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = read(self_fd, StrLoc(s), i);
       if (nread <= 0) {
           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               errno2why();
               fail;
           } else   /* nread == 0 */
               return nulldesc;
       }

       StrLen(s) = nread;
       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(StrLoc(s) + nread);

       return s;
   }
end

function io_FileStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       GetSelfFd();
       if ((rc = write(self_fd, StrLoc(s), StrLen(s))) < 0) {
           errno2why();
           fail;
       }
       return C_integer rc;
   }
end

function io_FileStream_close(self)
   body {
       GetSelfFd();
       if (close(self_fd) < 0) {
           errno2why();
           *self_fd_dptr = minusonedesc;
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return self;
   }
end

function io_FileStream_truncate(self, len)
   if !cnv:integer(len) then
      runerr(101, len)
   body {
#if PLAN9
       struct Dir st;
       GetSelfFd();

       nulldir(&st);
       if (!convert_to_vlong(&len, &st.length))
           runerr(0);

       if (lseek(self_fd, st.length, SEEK_SET) < 0) {
           errno2why();
           fail;
       }
       if (dirfwstat(self_fd, &st) < 0) {
           errno2why();
           fail;
       }
       return self;
#else
       off_t c_len;
       GetSelfFd();

       if (!convert_to_off_t(&len, &c_len))
           runerr(0);

       if (lseek(self_fd, c_len, SEEK_SET) < 0) {
           errno2why();
           fail;
       }

       if (ftruncate(self_fd, c_len) < 0) {
           errno2why();
           fail;
       }
       return self;
#endif
   }
end

function io_FileStream_chdir(self)
   body {
#if UNIX
       GetSelfFd();
       if (fchdir(self_fd) < 0) {
           errno2why();
           fail;
       }
       return self;
#else
     Unsupported;
#endif
   }
end

function io_FileStream_ttyname(self)
   body {
#if UNIX
       tended struct descrip result;
       char *s;
       GetSelfFd();
       s = ttyname(self_fd);
       if (!s) {
           errno2why();
           fail;
       }
       cstr2string(s, &result);
       return result;
#else
       Unsupported;
#endif
   }
end

function io_FileStream_isatty(self)
   body {
#if UNIX
       GetSelfFd();
       if (isatty(self_fd))
           return nulldesc;
       else
           fail;
#else
       Unsupported;
#endif
   }
end

function io_FileStream_seek(self, offset)
   if !cnv:integer(offset) then
      runerr(101, offset)
   body {
       int whence;
       off_t c_offset, rc;
       tended struct descrip t, result;
       GetSelfFd();

       if (bigsign(&offset) > 0) {
           bigsub(&offset, &onedesc, &t);
           offset = t;
           whence = SEEK_SET;
       } else
           whence = SEEK_END;

       if (!convert_to_off_t(&offset, &c_offset))
           runerr(0);
 
       if ((rc = lseek(self_fd, c_offset, whence)) < 0) {
           errno2why();
           fail;
       }
       convert_from_off_t(rc, &t);      
       bigadd(&t, &onedesc, &result);
       return result;
   }
end

function io_FileStream_tell(self)
   body {
       off_t rc;
       tended struct descrip t, result;

       GetSelfFd();
       if ((rc = lseek(self_fd, 0, SEEK_CUR)) < 0) {
           errno2why();
           fail;
       }
       convert_from_off_t(rc, &t);       
       bigadd(&t, &onedesc, &result);
       return result;
   }
end

function io_FileStream_pipe_impl()
   body {
#if UNIX || PLAN9
       int fds[2];
       struct descrip t;
       tended struct descrip result;

       if (pipe(fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      list_put(&result, &t);

      MakeInt(fds[1], &t);
      list_put(&result, &t);

      return result;
#else
      Unsupported;
#endif
   }
end

#if PLAN9
UnsupportedFunc(io_SocketStream_new_impl)
UnsupportedFunc(io_SocketStream_socketpair_impl)
UnsupportedFunc(io_SocketStream_dns_query_4)
UnsupportedFunc(io_SocketStream_dns_query_6)
#else
function io_SocketStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0)
           Irunerr(205, i);
       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = recv(self_fd, StrLoc(s), i, 0);
       if (nread <= 0) {
           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               errno2why();
               fail;
           } else  /* nread == 0 */
               return nulldesc;
       }

       StrLen(s) = nread;

       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(StrLoc(s) + nread);

       return s;
   }
end

function io_SocketStream_new_impl(domain, typ)
   if !def:C_integer(domain, PF_INET) then
      runerr(101, domain)

   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       int sockfd;
       sockfd = socket(domain, typ, 0);
       if (sockfd < 0) {
           errno2why();
           fail;
       }
       return C_integer sockfd;
   }
end

function io_SocketStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       GetSelfFd();
       /* 
        * If possible use MSG_NOSIGNAL so that we get the EPIPE error
        * code, rather than the SIGPIPE signal.  Otherwise, temporarily
        * change the SIGPIPE signal handler to SIG_IGN.
        */
#if HAVE_MSG_NOSIGNAL
       rc = send(self_fd, StrLoc(s), StrLen(s), MSG_NOSIGNAL);
#elif UNIX
       {
       struct sigaction saved, tmp;
       tmp.sa_handler = SIG_IGN;
       sigaction(SIGPIPE, &tmp, &saved);
       rc = send(self_fd, StrLoc(s), StrLen(s), 0);
       sigaction(SIGPIPE, &saved, NULL);
       }
#else
       rc = send(self_fd, StrLoc(s), StrLen(s), 0);
#endif
       if (rc < 0) {
           errno2why();
           fail;
       }
       return C_integer rc;
   }
end

function io_SocketStream_close(self)
   body {
       GetSelfFd();
#if MSWIN32
       if (closesocket(self_fd) < 0) {
#else
       if (close(self_fd) < 0) {
#endif
           errno2why();
           *self_fd_dptr = minusonedesc;
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return self;
   }
end

function io_SocketStream_shutdown(self, how)
   if !cnv:C_integer(how) then
      runerr(101, how)
   body {
       GetSelfFd();
       if (shutdown(self_fd, how) < 0) {
           errno2why();
           fail;
       }
       return self;
   }
end

function io_SocketStream_socketpair_impl(typ)
   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
#if UNIX
       int fds[2];
       struct descrip t;
       tended struct descrip result;

       if (socketpair(AF_UNIX, typ, 0, fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      list_put(&result, &t);

      MakeInt(fds[1], &t);
      list_put(&result, &t);

      return result;
#else
       Unsupported;
#endif
   }
end

#if UNIX
static void getaddrinfo_error2why(int error)
{
    if (error == EAI_SYSTEM)
        errno2why();
    else
        whyf("Name lookup failure: %s", gai_strerror(error));
}
#endif

static struct sockaddr *parse_sockaddr(char *s, int *len)
{
#if UNIX
    if (strncmp(s, "unix:", 5) == 0) {
        static struct sockaddr_un us;
        char *t = s + 5;
        if (strlen(t) >= sizeof(us.sun_path)) {
            LitWhy("Name too long");
            return 0;
        }
        us.sun_family = AF_UNIX;
        strcpy(us.sun_path, t);
        *len = sizeof(us.sun_family) + strlen(us.sun_path);
        return (struct sockaddr *)&us;
    } 
    if (strncmp(s, "inet:", 5) == 0) {
        static struct sockaddr_in iss;
        struct addrinfo hints;
        struct addrinfo *res;
        int error;
        char *t = s + 5, buf[128], *host, *port;
        if (strlen(t) >= sizeof(buf)) {
            LitWhy("Name too long");
            return 0;
        }
        strcpy(buf, t);
        port = strchr(buf, ':');
        if (!port) {
            LitWhy("Bad socket address format (missing :)");
            return 0;
        }
        *port++ = 0;

        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET;
        hints.ai_socktype = SOCK_STREAM;
        if (strcmp(buf, "INADDR_ANY") == 0) {
            hints.ai_flags = AI_PASSIVE;
            host = 0;
        } else
            host = buf;
        error = getaddrinfo(host, port, &hints, &res);
        if (error != 0) {
            getaddrinfo_error2why(error);
            return 0;
        }
        memcpy(&iss, res->ai_addr, res->ai_addrlen);
        freeaddrinfo(res);
        *len = sizeof(iss);
        return (struct sockaddr *)&iss;
    }
    if (strncmp(s, "inet6:", 6) == 0) {
        static struct sockaddr_in6 iss;
        struct addrinfo hints;
        struct addrinfo *res;
        int error;
        char *t = s + 6, buf[128], *host, *port;
        if (strlen(t) >= sizeof(buf)) {
            LitWhy("Name too long");
            return 0;
        }
        strcpy(buf, t);
        if (buf[0] == '[') {
            t = strchr(buf, ']');
            if (!t) {
                LitWhy("Bad socket address format (missing ])");
                return 0;
            }
            host = buf + 1;
            *t++ = 0;
            if (*t != ':') {
                LitWhy("Bad socket address format (missing :)");
                return 0;
            }
            port = t + 1;
        } else {
            host = buf;
            port = strchr(buf, ':');
            if (!port) {
                LitWhy("Bad socket address format (missing :)");
                return 0;
            }
            *port++ = 0;
        }
        memset(&hints, 0, sizeof(hints));
        hints.ai_family = AF_INET6;
        hints.ai_socktype = SOCK_STREAM;
        if (strcmp(host, "INADDR_ANY") == 0) {
            hints.ai_flags = AI_PASSIVE;
            host = 0;
        }
        error = getaddrinfo(host, port, &hints, &res);
        if (error != 0) {
            getaddrinfo_error2why(error);
            return 0;
        }
        memcpy(&iss, res->ai_addr, res->ai_addrlen);
        freeaddrinfo(res);
        *len = sizeof(iss);
        return (struct sockaddr *)&iss;
    }

    LitWhy("Bad socket address format (unknown family)");
    return 0;
#else
    LitWhy("Unsuppoted");
    return 0;
#endif
}

function io_SocketStream_dns_query_4(host)
   if !cnv:C_string(host) then
      runerr(103, host)
   body {
#if UNIX
      struct addrinfo hints;
      struct addrinfo *res, *t;
      tended struct descrip tmp, result;
      int error, n;
      memset(&hints, 0, sizeof(hints));
      hints.ai_family = AF_INET;
      hints.ai_socktype = SOCK_STREAM;
      error = getaddrinfo(host, NULL, &hints, &res);
      if (error != 0) {
          getaddrinfo_error2why(error);
          fail;
      }
      n = 0;
      for (t = res; t; t = t->ai_next)
          ++n;

      create_list(n, &result);
      for (t = res; t; t = t->ai_next) {
          char buf[INET_ADDRSTRLEN];
          struct sockaddr_in *p = (struct sockaddr_in *)t->ai_addr;
          inet_ntop(AF_INET, &p->sin_addr, buf, sizeof(buf));
          cstr2string(buf, &tmp);
          list_put(&result, &tmp);
      }
      freeaddrinfo(res);
      return result;
#else
      Unsupported;
#endif
   }
end

function io_SocketStream_dns_query_6(host)
   if !cnv:C_string(host) then
      runerr(103, host)
   body {
#if UNIX
      struct addrinfo hints;
      struct addrinfo *res, *t;
      tended struct descrip tmp, result;
      int error, n;
      memset(&hints, 0, sizeof(hints));
      hints.ai_family = AF_INET6;
      hints.ai_socktype = SOCK_STREAM;
      error = getaddrinfo(host, NULL, &hints, &res);
      if (error != 0) {
          getaddrinfo_error2why(error);
          fail;
      }
      n = 0;
      for (t = res; t; t = t->ai_next)
          ++n;

      create_list(n, &result);
      for (t = res; t; t = t->ai_next) {
          char buf[INET6_ADDRSTRLEN];
          struct sockaddr_in6 *p = (struct sockaddr_in6 *)t->ai_addr;
          inet_ntop(AF_INET6, &p->sin6_addr, buf, sizeof(buf));
          cstr2string(buf, &tmp);
          list_put(&result, &tmp);
      }
      freeaddrinfo(res);
      return result;
#else
      Unsupported;
#endif
   }
end

function io_SocketStream_connect(self, addr)
   if !cnv:C_string(addr) then
      runerr(103, addr)
   body {
       struct sockaddr *sa;
       int len;
       GetSelfFd();

       sa = parse_sockaddr(addr, &len);
       if (!sa) {
           /* &why already set by parse_sockaddr */
           fail;
       }

       if (connect(self_fd, sa, len) < 0) {
           errno2why();
           fail;
       }

       return self;
   }
end

function io_SocketStream_bind(self, addr)
   if !cnv:C_string(addr) then
      runerr(103, addr)
   body {
       struct sockaddr *sa;
       int optval;
       int len;
       GetSelfFd();

       sa = parse_sockaddr(addr, &len);
       if (!sa) {
           /* &why already set by parse_sockaddr */
           fail;
       }

       /* This prevents a TIME_WAIT expiring connection blocking a server listening on
        * the same port */
       optval = 1;
#if UNIX
       setsockopt(self_fd, SOL_SOCKET, SO_REUSEADDR, &optval, sizeof optval);
#endif
       if (bind(self_fd, sa, len) < 0) {
           errno2why();
           fail;
       }

       return self;
   }
end

function io_SocketStream_listen(self, backlog)
   if !cnv:C_integer(backlog) then
      runerr(101, backlog)

   body {
       GetSelfFd();
       if (listen(self_fd, backlog) < 0) {
           errno2why();
           fail;
       }
       return self;
   }
end

function io_SocketStream_get_peer(self)
   body {
       tended struct descrip result;
       struct sockaddr_in iss;
       socklen_t iss_len;
       char buf[128];
       GetSelfFd();
       iss_len = sizeof(iss);
       if (getpeername(self_fd, (struct sockaddr *)&iss, &iss_len) < 0) {
           errno2why();
           fail;
       }
       snprintf(buf, sizeof(buf), "%s:%u", inet_ntoa(iss.sin_addr), (unsigned)ntohs(iss.sin_port));
       cstr2string(buf, &result);
       return result;
   }
end

function io_SocketStream_accept_impl(self)
   body {
       int sockfd;
       GetSelfFd();

       if ((sockfd = accept(self_fd, 0, 0)) < 0) {
           errno2why();
           fail;
       }

       return C_integer sockfd;
   }
end

#endif  /* PLAN9 */

/*
 * These two are macros since they call runerr (so does FdStaticParam).
 */

#begdef list2fd_set(l, tmpl, s)
{
    tended struct descrip e;

    FD_ZERO(&s);
    if (!is:null(l)) {
        if (!is:list(l))
            runerr(108, l);
        create_list(ListBlk(l).size, &tmpl);
        while (list_get(&l, &e)) {
            FdStaticParam(e, fd);
            list_put(&tmpl, &e);
            FD_SET(fd, &s);
        }
    }
}
#enddef

#begdef fd_set2list(l, tmpl, s)
{
    tended struct descrip e;

    if (!is:null(l)) {
        while (list_get(&tmpl, &e)) {
            FdStaticParam(e, fd);
            if (FD_ISSET(fd, &s)) {
                list_put(&l, &e);
                ++count;
            }
        }
    }
}
#enddef

function io_DescStream_dup2_impl(self, other)
   body {
       GetSelfFd();
       {
           FdStaticParam(other, other_fd);
           if (dup2(self_fd, other_fd) < 0) {
               errno2why();
               fail;
           }
           return self;
       }
   }
end

function io_DescStream_stat_impl(self)
   body {
       tended struct descrip result;
#if PLAN9
       struct Dir *st;
       GetSelfFd();
       if (!(st = dirfstat(self_fd))) {
           errno2why();
           fail;
       }
       stat2list(st, &result);
       free(st);
#else
       struct stat st;
       GetSelfFd();
       if (fstat(self_fd, &st) < 0) {
           errno2why();
           fail;
       }
       stat2list(&st, &result);
#endif
       return result;
   }
end

#if PLAN9
#begdef WstatBody()
{
   tended char *c_name, *c_gid;
   if (!is:null(uid)) {
       LitWhy("Cannot set uid in a wstat");
       fail;
   }
   if (!is:null(atime)) {
       LitWhy("Cannot set atime in a wstat");
       fail;
   }
   nulldir(&st);
   if (!is:null(mode)) {
       if (!cnv:integer(mode, mode))
           runerr(101, mode);
       if (!convert_to_ulong(&mode, &st.mode))
           runerr(0);
   }
   if (!is:null(mtime)) {
       if (!cnv:integer(mtime, mtime))
           runerr(101, mtime);
       if (!convert_to_ulong(&mtime, &st.mtime))
           runerr(0);
   }
   if (!is:null(length)) {
       if (!cnv:integer(length, length))
           runerr(101, length);
       if (!convert_to_vlong(&length, &st.length))
           runerr(0);
   }
   if (!is:null(name)) {
       if (!cnv:C_string(name, c_name))
           runerr(103, name);
   }
   if (!is:null(gid)) {
       if (!cnv:C_string(gid, c_gid))
           runerr(103, gid);
   }
   /* Now safe to put tended strings into struct */
   if (!is:null(name)) 
       st.name = c_name;
   if (!is:null(gid)) 
       st.gid = c_gid;
}
#enddef

function io_DescStream_wstat(self, mode, uid, gid, atime, mtime, length, name)
   body {
       struct Dir st;
       GetSelfFd();
       WstatBody();
       if (dirfwstat(self_fd, &st) < 0) {
           errno2why();
           fail;
       }
       return self;
   }
end
#else
function io_DescStream_wstat(self, mode, uid, gid)
   body {
#if UNIX
       GetSelfFd();
       if (!is:null(mode)) {
           mode_t c_mode;
           if (!cnv:integer(mode, mode))
               runerr(101, mode);
           if (!convert_to_mode_t(&mode, &c_mode))
               runerr(0);
           if (fchmod(self_fd, c_mode) < 0) {
               errno2why();
               fail;
           }
       }
       if (!is:null(uid) || !is:null(gid)) {
           uid_t owner;
           gid_t group;
           if (is:null(uid))
               owner = (uid_t)-1;
           else {
               if (!cnv:integer(uid, uid))
                   runerr(101, uid);
               if (!convert_to_uid_t(&uid, &owner))
                   runerr(0);
           }

           if (is:null(gid))
               group = (gid_t)-1;
           else {
               if (!cnv:integer(gid, gid))
                   runerr(101, gid);
               if (!convert_to_gid_t(&gid, &group))
                   runerr(0);
           }
           if (fchown(self_fd, owner, group) < 0) {
               errno2why();
               fail;
           }
       }
       return self;
#else
        Unsupported;
#endif
   }
end
#endif

function io_DescStream_select(rl, wl, el, timeout)
    body {
#if PLAN9
       Unsupported;
#else
       fd_set rset, wset, eset;
       struct timeval tv, *ptv;
       tended struct descrip rtmp, wtmp, etmp;
       int rc, count;

       list2fd_set(rl, rtmp, rset);
       list2fd_set(wl, wtmp, wset);
       list2fd_set(el, etmp, eset);

       if (is:null(timeout))
           ptv = 0;
       else {
           word t;
           if (!cnv:C_integer(timeout, t))
               runerr(101, timeout);
           tv.tv_sec = t / 1000;
           tv.tv_usec = (t % 1000) * 1000;
           ptv = &tv;
       }

       rc = select(FD_SETSIZE, &rset, &wset, &eset, ptv);
       if (rc < 0) {
           errno2why();
           fail;
       }

       count = 0;
       fd_set2list(rl, rtmp, rset);
       fd_set2list(wl, wtmp, wset);
       fd_set2list(el, etmp, eset);

       if (count != rc) {
           LitWhy("Unexpected mismatch between FD_SETs and list sizes");
           fail;
       }

       return C_integer rc;
#endif
    }
end

function io_DescStream_poll(l, timeout)
   if !is:list(l) then
      runerr(108,l)
   if !def:C_integer(timeout, -1) then
      runerr(101, timeout)
   body {
#if HAVE_POLL
       static struct pollfd *ufds = 0;
       unsigned int nfds;
       int i, rc;
       struct lgstate state;
       tended struct b_lelem *le;
       tended struct descrip result;

       if (ListBlk(l).size % 2 != 0)
           runerr(130);

       nfds = ListBlk(l).size / 2;

       if (nfds > 0)
           ufds = rt_realloc(ufds, nfds * sizeof(struct pollfd));

       le = lgfirst(&ListBlk(l), &state);
       for (i = 0; i < nfds; ++i) {
           word events;
           FdStaticParam(le->lslots[state.result], fd);
           le = lgnext(&ListBlk(l), &state, le);
           if (!cnv:C_integer(le->lslots[state.result], events))
               runerr(101, le->lslots[state.result]);
           ufds[i].fd = fd;
           ufds[i].events = (short)events;
           le = lgnext(&ListBlk(l), &state, le);
       }

       rc = poll(ufds, nfds, timeout);
       if (rc < 0) {
           errno2why();
           fail;
       }

       /* A rc of zero means timeout, and returns &null */
       if (rc == 0)
           return nulldesc;

       create_list(nfds, &result);
       for (i = 0; i < nfds; ++i) {
           struct descrip tmp;
           MakeInt(ufds[i].revents, &tmp);
           list_put(&result, &tmp);
       }

       return result;
#else
       Unsupported;
#endif  /* HAVE_POLL */
   }
end

function io_DescStream_flag(self, on, off)
    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
#if UNIX
        int i;
        GetSelfFd();

        if ((i = fcntl(self_fd, F_GETFL, 0)) < 0) {
           errno2why();
           fail;
        }
        if (on || off) {
            i = (i | on) & (~off);
            if (fcntl(self_fd, F_SETFL, i) < 0) {
                errno2why();
                fail;
            }
        }

        return C_integer i;
#else
        Unsupported;
#endif
    }
end

function io_DescStream_dflag(self, on, off)
    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
#if UNIX
        int i;
        GetSelfFd();

        if ((i = fcntl(self_fd, F_GETFD, 0)) < 0) {
           errno2why();
           fail;
        }
        if (on || off) {
            i = (i | on) & (~off);
            if (fcntl(self_fd, F_SETFD, i) < 0) {
                errno2why();
                fail;
            }
        }

        return C_integer i;
#else
        Unsupported;
#endif
    }
end

#if PLAN9

struct DirData {
   int fd, special;
   struct Dir *st;
   long pos, n;
};
#begdef GetSelfDir()
struct DirData *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (struct DirData*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function io_DirStream_new_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       int fd;
       struct DirData *d;
       fd = open(path, OREAD);
       if (fd < 0) {
           errno2why();
           fail;
       }
       d = rt_malloc(sizeof(struct DirData));
       d->fd = fd;
       d->pos = d->n = 0;
       d->st = 0;
       d->special = 2;
       return C_integer((word)d);
   }
end

function io_DirStream_read_line_impl(self)
   body {
      tended struct descrip result;
      GetSelfDir();
      if (self_dir->special == 2) {
          --self_dir->special;
          return C_string ".";
      }
      if (self_dir->special == 1) {
          --self_dir->special;
          return C_string "..";
      }
      if (self_dir->pos >= self_dir->n) {
          struct Dir *st;
          long n;
          n = dirread(self_dir->fd, &st);
          if (n <= 0) {
              if (n < 0) {
                  errno2why();
                  fail;
              } else  /* n == 0 */
                  return nulldesc;
          }
          free(self_dir->st);
          self_dir->st = st;
          self_dir->pos = 0;
          self_dir->n = n;
      }
      cstr2string(self_dir->st[self_dir->pos++].name, &result);
      return result;
   }
end


function io_DirStream_close(self)
   body {
       GetSelfDir();
       if ((close(self_dir->fd)) < 0) {
           errno2why();
           fail;
       }
       free(self_dir->st);
       free(self_dir);
       *self_dir_dptr = zerodesc;
       return self;
   }
end

#elif UNIX

#begdef GetSelfDir()
DIR *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (DIR*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function io_DirStream_new_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       DIR *dd = opendir(path);
       if (!dd) {
           errno2why();
           fail;
       }
       return C_integer((word)dd);
   }
end

function io_DirStream_read_line_impl(self)
   body {
       struct dirent *de;
       tended struct descrip result;
       GetSelfDir();
       errno = 0;
       de = readdir(self_dir);
       if (!de) {
           if (errno) {
               errno2why();
               fail;
           } else
               return nulldesc;
       }
       cstr2string(de->d_name, &result);
       return result;
   }
end

function io_DirStream_close(self)
   body {
       GetSelfDir();
       if ((closedir(self_dir)) < 0) {
           errno2why();
           *self_dir_dptr = zerodesc;
           fail;
       }
       *self_dir_dptr = zerodesc;
       return self;
   }
end

#elif MSWIN32
enum DirDataStatus { EMPTY, FIRST, MORE };

struct DirData {
   WIN32_FIND_DATA fileData;
   int status;
   HANDLE handle;
};

#begdef GetSelfDir()
struct DirData *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (struct DirData*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function io_DirStream_new_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       struct DirData *fd;
       fd = rt_malloc(sizeof(struct DirData));
       fd->handle = FindFirstFile(path, &fd->fileData);
       if (fd->handle == INVALID_HANDLE_VALUE) {
	  if (GetLastError() == ERROR_FILE_NOT_FOUND) {
	     fd->status = EMPTY;
	     return C_integer((word)fd);
	  }
	  LitWhy("Couldn't open directory");
	  free(fd);
	  fail;
       }
       fd->status = FIRST;
       return C_integer((word)fd);
   }
end

function io_DirStream_read_line_impl(self)
   body {
       tended struct descrip result;
       GetSelfDir();
       if (self_dir->status == EMPTY)
           return nulldesc;
       if (self_dir->status == FIRST) {
	  cstr2string(self_dir->fileData.cFileName, &result);
	  self_dir->status = MORE;
	  return result;
       }
       if (!FindNextFile(self_dir->handle, &self_dir->fileData))
           return nulldesc;
       cstr2string(self_dir->fileData.cFileName, &result);
       return result;
   }
end

function io_DirStream_close(self)
   body {
       GetSelfDir();
       FindClose(self_dir->handle);
       free(self_dir);
       *self_dir_dptr = zerodesc;
       return self;
   }
end

#endif


function io_Files_rename(s1, s2)
   /*
    * Make C-style strings out of s1 and s2
    */
   if !cnv:C_string(s1) then
      runerr(103,s1)
   if !cnv:C_string(s2) then
      runerr(103,s2)

   body {
       if (rename(s1, s2) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function io_Files_hardlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if UNIX
      if (link(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#else
     Unsupported;
#endif
   }
end

function io_Files_symlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if UNIX
      if (symlink(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#else
     Unsupported;
#endif
   }
end

function io_Files_readlink(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
#if UNIX
       int buff_size, rc;
       char *buff;
       buff_size = 32;
       for (;;) {
           MemProtect(buff = alcstr(0, buff_size));
           rc = readlink(s, buff, buff_size);
           if (rc < 0) {
               dealcstr(buff);
               errno2why();
               fail;
           }
           if (rc < buff_size) {
               /* Fitted okay, so deallocate surplus and return */
               dealcstr(buff + rc);
               return string(rc, buff);
           }
           /* Didn't fit (or perhaps did fit exactly) - so deallocate
            * buff, increase buff_size and repeat */
           dealcstr(buff);
           buff_size *= 2;
       }
#else
     Unsupported;
#endif
      }
end

function io_Files_realpath(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
#if UNIX
       tended struct descrip result;
       char *r;
       r = realpath(s, NULL);
       if (!r) {
           errno2why();
           fail;
       }
       cstr2string(r, &result);
       free(r);
       return result;
#else
     Unsupported;
#endif
      }
end

#if UNIX
function io_Files_mkdir(s, mode)
   if !cnv:C_string(s) then
      runerr(103, s)
   if !def:integer(mode, S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH) then
      runerr(101, mode)
   body {
       mode_t c_mode;
       if (!convert_to_mode_t(&mode, &c_mode))
           runerr(0);
      if (mkdir(s, c_mode) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
   }
end
#elif PLAN9
function io_Files_mkdir(s, mode)
   if !cnv:C_string(s) then
      runerr(103, s)
   if !def:integer(mode, 0777, mode) then
      runerr(101, mode)
   body {
      ulong c_mode;
      if (!convert_to_ulong(&mode, &c_mode))
         runerr(0);
      if (mkdir(s, c_mode) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
   }
end
#else
function io_Files_mkdir(s, mode)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
      if (mkdir(s) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
   }
end
#endif

function io_Files_remove(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      if (remove(s) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

function io_Files_rmdir(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      if (rmdir(s) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

function io_Files_truncate(s, len)
   if !cnv:C_string(s) then
      runerr(103,s)
   if !cnv:integer(len) then
      runerr(101, len)
   body {
#if PLAN9
       struct Dir st;
       nulldir(&st);
       if (!convert_to_vlong(&len, &st.length))
           runerr(0);
       if (dirwstat(s, &st) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
#elif HAVE_TRUNCATE
      off_t c_len;
      if (!convert_to_off_t(&len, &c_len))
          runerr(0);
      if (truncate(s, c_len) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
#else
      int fd;
      off_t c_len;
      if (!convert_to_off_t(&len, &c_len))
          runerr(0);
      fd = open(s, O_WRONLY, 0);
      if (fd < 0) {
           errno2why();
           fail;
      }
      if (ftruncate(fd, c_len) < 0) {
           errno2why();
           close(fd);
           fail;
      }
      close(fd);
      return nulldesc;
#endif
   }
end

#if PLAN9
static void stat2list(struct Dir *st, dptr result)
{
   tended struct descrip tmp;
   char mode[13], *user, *group;
   struct passwd *pw;
   struct group *gr;

   create_list(14, result);
   convert_from_uint(st->dev, &tmp);
   list_put(result, &tmp);

   convert_from_ulong(st->mode, &tmp);
   list_put(result, &tmp);
   strcpy(mode, "-----------");
   if (st->mode & DMDIR) mode[0] = 'd';
   else if (st->mode & DMAPPEND) mode[0] = 'a';
   else if(st->mode & DMAUTH) mode[0]='A';
   if (st->mode & DMEXCL) mode[1] = 'l';
   if (st->mode & 0400) mode[2] = 'r';
   if (st->mode & 0200) mode[3] = 'w';
   if (st->mode & 0100) mode[4] = 'x';
   if (st->mode & 0040) mode[5] = 'r';
   if (st->mode & 0020) mode[6] = 'w';
   if (st->mode & 0010) mode[7] = 'x';
   if (st->mode & 0004) mode[8] = 'r';
   if (st->mode & 0002) mode[9] = 'w';
   if (st->mode & 0001) mode[10] = 'x';
   cstr2string(mode, &tmp);
   list_put(result, &tmp);

   convert_from_uint(st->type, &tmp);      /* server type */
   list_put(result, &tmp);

   cstr2string(st->uid, &tmp);
   list_put(result, &tmp);

   cstr2string(st->gid, &tmp);
   list_put(result, &tmp);

   cstr2string(st->muid, &tmp);
   list_put(result, &tmp);

   convert_from_vlong(st->length, &tmp);
   list_put(result, &tmp);

   cstr2string(st->name, &tmp);   /* name */
   list_put(result, &tmp);

   convert_from_ulong(st->atime, &tmp);
   list_put(result, &tmp);
   convert_from_ulong(st->mtime, &tmp);
   list_put(result, &tmp);

   convert_from_uvlong(st->qid.path, &tmp);
   list_put(result, &tmp);

   convert_from_ulong(st->qid.vers, &tmp);
   list_put(result, &tmp);

   MakeInt(st->qid.type, &tmp);
   list_put(result, &tmp);
}

#else

static void stat2list(struct stat *st, dptr result)
{
   tended struct descrip tmp;
   char mode[12];

   create_list(13, result);
   convert_from_dev_t(st->st_dev, &tmp);
   list_put(result, &tmp);
#if UNIX
   convert_from_ino_t(st->st_ino, &tmp);
   list_put(result, &tmp);
#else
   list_put(result, &zerodesc);
#endif
   convert_from_mode_t(st->st_mode, &tmp);
   list_put(result, &tmp);
   strcpy(mode, "----------");
#if UNIX
   if (S_ISLNK(st->st_mode)) mode[0] = 'l';
   else if (S_ISREG(st->st_mode)) mode[0] = '-';
   else if (S_ISDIR(st->st_mode)) mode[0] = 'd';
   else if (S_ISCHR(st->st_mode)) mode[0] = 'c';
   else if (S_ISBLK(st->st_mode)) mode[0] = 'b';
   else if (S_ISFIFO(st->st_mode)) mode[0] = 'p';
   else if (S_ISSOCK(st->st_mode)) mode[0] = 's';

   if (S_IRUSR & st->st_mode) mode[1] = 'r';
   if (S_IWUSR & st->st_mode) mode[2] = 'w';
   if (S_IXUSR & st->st_mode) mode[3] = 'x';
   if (S_IRGRP & st->st_mode) mode[4] = 'r';
   if (S_IWGRP & st->st_mode) mode[5] = 'w';
   if (S_IXGRP & st->st_mode) mode[6] = 'x';
   if (S_IROTH & st->st_mode) mode[7] = 'r';
   if (S_IWOTH & st->st_mode) mode[8] = 'w';
   if (S_IXOTH & st->st_mode) mode[9] = 'x';

   if (S_ISUID & st->st_mode) mode[3] = (mode[3] == 'x') ? 's' : 'S';
   if (S_ISGID & st->st_mode) mode[6] = (mode[6] == 'x') ? 's' : 'S';
   if (S_ISVTX & st->st_mode) mode[9] = (mode[9] == 'x') ? 't' : 'T';
#elif MSWIN32
   if (st->st_mode & _S_IFREG) mode[0] = '-';
   else if (st->st_mode & _S_IFDIR) mode[0] = 'd';
   else if (st->st_mode & _S_IFCHR) mode[0] = 'c';
   else if (st->st_mode & _S_IFMT) mode[0] = 'm';

   if (st->st_mode & S_IREAD) mode[1] = mode[4] = mode[7] = 'r';
   if (st->st_mode & S_IWRITE) mode[2] = mode[5] = mode[8] = 'w';
   if (st->st_mode & S_IEXEC) mode[3] = mode[6] = mode[9] = 'x';
#endif
   cstr2string(mode, &tmp);
   list_put(result, &tmp);

   MakeInt(st->st_nlink, &tmp);
   list_put(result, &tmp);

#if UNIX
   convert_from_uid_t(st->st_uid, &tmp);
   list_put(result, &tmp);
   convert_from_gid_t(st->st_gid, &tmp);
   list_put(result, &tmp);
#else
   list_put(result, &emptystr);
   list_put(result, &emptystr);
#endif

   convert_from_dev_t(st->st_rdev, &tmp);
   list_put(result, &tmp);
   convert_from_off_t(st->st_size, &tmp);
   list_put(result, &tmp);
#if UNIX
   MakeInt(st->st_blksize, &tmp);
   list_put(result, &tmp);
   convert_from_blkcnt_t(st->st_blocks, &tmp);
   list_put(result, &tmp);
#else
   list_put(result, &zerodesc);
   list_put(result, &zerodesc);
#endif
   convert_from_time_t(st->st_atime, &tmp);
   list_put(result, &tmp);
   convert_from_time_t(st->st_mtime, &tmp);
   list_put(result, &tmp);
   convert_from_time_t(st->st_ctime, &tmp);
   list_put(result, &tmp);
#if HAVE_NS_FILE_STAT
   MakeInt(st->st_atim.tv_nsec, &tmp);
   list_put(result, &tmp);
   MakeInt(st->st_mtim.tv_nsec, &tmp);
   list_put(result, &tmp);
   MakeInt(st->st_ctim.tv_nsec, &tmp);
   list_put(result, &tmp);
#else
   list_put(result, &zerodesc);
   list_put(result, &zerodesc);
   list_put(result, &zerodesc);
#endif
}
#endif /* PLAN9 */

function io_Files_stat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      tended struct descrip result;
#if PLAN9
      struct Dir *st;
      if (!(st = dirstat(s))) {
          errno2why();
          fail;
      }
      stat2list(st, &result);
      free(st);
#else
      struct stat st;
      if (stat(s, &st) < 0) {
          errno2why();
          fail;
      }
      stat2list(&st, &result);
#endif
      return result;
   }
end

function io_Files_lstat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      tended struct descrip result;
#if PLAN9
      struct Dir *st;
      if (!(st = dirstat(s))) {
          errno2why();
          fail;
      }
      stat2list(st, &result);
      free(st);
#else
      struct stat st;
      if (lstat(s, &st) < 0) {
          errno2why();
          fail;
      }
      stat2list(&st, &result);
#endif
      return result;
   }
end

#if PLAN9
function io_Files_dir_read_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      tended struct descrip result;
      struct Dir *st;
      int fd;
      long n, i;
      fd = open(s, OREAD);
      if (fd < 0) {
          errno2why();
          fail;
      }
      n = dirreadall(fd, &st);
      close(fd);
      if (n < 0) {
          errno2why();
          fail;
      }
      create_list(n, &result);
      for (i = 0; i < n; ++i) {
          tended struct descrip t;
          stat2list(&st[i], &t);
          list_put(&result, &t);
      }
      free(st);
      return result;
   }
end
#endif

#if PLAN9
function io_Files_wstat(s, mode, uid, gid, atime, mtime, length, name)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
       struct Dir st;
       WstatBody();
       if (dirwstat(s, &st) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end
#else
function io_Files_wstat(s, mode, uid, gid, atime, mtime)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
#if UNIX
       if (!is:null(mode)) {
           mode_t c_mode;
           if (!cnv:integer(mode, mode))
               runerr(101, mode);
           if (!convert_to_mode_t(&mode, &c_mode))
               runerr(0);
           if (chmod(s, c_mode) < 0) {
               errno2why();
               fail;
           }
       }
       if (!is:null(uid) || !is:null(gid)) {
           uid_t owner;
           gid_t group;
           if (is:null(uid))
               owner = (uid_t)-1;
           else {
               if (!cnv:integer(uid, uid))
                   runerr(101, uid);
               if (!convert_to_uid_t(&uid, &owner))
                   runerr(0);
           }
           if (is:null(gid))
               group = (gid_t)-1;
           else {
               if (!cnv:integer(gid, gid))
                   runerr(101, gid);
               if (!convert_to_gid_t(&gid, &group))
                   runerr(0);
           }
           if (chown(s, owner, group) < 0) {
               errno2why();
               fail;
           }
       }
       if (!is:null(atime) || !is:null(mtime)) {
           struct utimbuf u;
           struct stat st;
           if (is:null(atime) || is:null(mtime)) {
               if (stat(s, &st) < 0) {
                   errno2why();
                   fail;
               }
           }
           if (is:null(atime)) 
               u.actime = st.st_atime;
           else {
               if (!cnv:integer(atime, atime))
                   runerr(101, atime);
               if (!convert_to_time_t(&atime, &u.actime))
                   runerr(0);
           }
           if (is:null(mtime)) 
               u.modtime = st.st_mtime;
           else {
               if (!cnv:integer(mtime, mtime))
                   runerr(101, mtime);
               if (!convert_to_time_t(&mtime, &u.modtime))
                   runerr(0);
           }
           if (utime(s, &u) < 0) {
               errno2why();
               fail;
           }
       }

       return nulldesc;
#else
        Unsupported;
#endif
   }
end
#endif

function io_Files_access(s, mode)
   if !cnv:C_string(s) then
      runerr(103,s)
   if !def:C_integer(mode, F_OK) then
      runerr(101, mode)
   body {
      if (access(s, mode) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

function util_Time_get_system_seconds()
   body {
      tended struct descrip result;
      struct timeval tp;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      convert_from_time_t(tp.tv_sec, &result);
      return result;
   }
end

function util_Time_get_system_millis()
   body {
      struct timeval tp;
      struct descrip lm;
      tended struct descrip ls, lt, result;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      convert_from_time_t(tp.tv_sec, &ls);
      MakeInt(tp.tv_usec / 1000, &lm);
      bigmul(&ls, &thousanddesc, &lt);
      bigadd(&lt, &lm, &result);
      return result;
   }
end

function util_Time_get_system_micros()
   body {
      struct timeval tp;
      struct descrip lm;
      tended struct descrip ls, lt, result;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      convert_from_time_t(tp.tv_sec, &ls);
      MakeInt(tp.tv_usec, &lm);
      bigmul(&ls, &milliondesc, &lt);
      bigadd(&lt, &lm, &result);
      return result;
   }
end


#if MSWIN32
/* These have to be defined here, rather than in sys.h, since they
 * would interfere with 'struct timezone' */
#define timezone _timezone
#define tzname _tzname
#endif

#if PLAN9
static struct tzinfo tz;

function util_Timezone_get_local_timezones()
   body {
      tended struct descrip tmp1, tmp2, result;
      readtzinfo(&tz);
      create_list(2, &result);
      create_list(2, &tmp1);
      MakeInt(tz.stdiff, &tmp2);
      list_put(&tmp1, &tmp2);
      cstr2string(tz.stname, &tmp2);
      list_put(&tmp1, &tmp2);
      list_put(&result, &tmp1);
      if (tz.dlname) {
          create_list(2, &tmp1);
          MakeInt(tz.dldiff, &tmp2);
          list_put(&tmp1, &tmp2);
          cstr2string(tz.dlname, &tmp2);
          list_put(&tmp1, &tmp2);
          list_put(&result, &tmp1);
      }
      return result;
   }
end

function util_Timezone_get_gmt_offset_at(n)
   if !cnv:integer(n) then
      runerr(101, n)
   body {
       word t;
       long *p;
       if (!cnv:C_integer(n, t))
           fail;
       /* See localtime() in libc/9sys/ctime.c */
       t += tz.stdiff;
       for (p = tz.dlpairs; *p; p += 2) {
           if (t >= p[0] && t < p[1])
               return C_integer tz.dldiff;
       }
       return C_integer tz.stdiff;
   }
end

#else /* PLAN9 */

function util_Timezone_get_local_timezones()
   body {
#if HAVE_STRUCT_TM_TM_GMTOFF && HAVE_STRUCT_TM_TM_ISDST && HAVE_STRUCT_TM_TM_ZONE
    tended struct descrip tmp, dst, std, result;
    struct tm *pt;
    time_t t;
    int i, seen = 0;
    time(&t);
    for (i = 0; seen != 3 && i < 366; ++i) {
        pt = localtime(&t);
        if (pt->tm_isdst) {
            if (!(seen & 1)) {
                create_list(2, &dst);
                MakeInt(pt->tm_gmtoff, &tmp);
                list_put(&dst, &tmp);
                cstr2string((char*)pt->tm_zone, &tmp);
                list_put(&dst, &tmp);
                seen |= 1;
            }
        } else {
            if (!(seen & 2)) {
                create_list(2, &std);
                MakeInt(pt->tm_gmtoff, &tmp);
                list_put(&std, &tmp);
                cstr2string((char *)pt->tm_zone, &tmp);
                list_put(&std, &tmp);
                seen |= 2;
            }
        }
        t += 86400;
    }
    if (!(seen & 2))
        fail;
    create_list(2, &result);
    list_put(&result, &std);
    if (seen & 1)
        list_put(&result, &dst);
    return result;
#elif HAVE_TIMEZONE
    tended struct descrip tmp1, tmp2, result;
    tzset();
    create_list(1, &result);
    create_list(2, &tmp1);
    MakeInt(-timezone, &tmp2);
    list_put(&tmp1, &tmp2);
    #if HAVE_TZNAME
    cstr2string(tzname[0], &tmp2);
    list_put(&tmp1, &tmp2);
    #endif
    list_put(&result, &tmp1);
    return result;
#else
    fail;
#endif
   }
end

function util_Timezone_get_gmt_offset_at(n)
   if !cnv:integer(n) then
      runerr(101, n)
   body {
#if HAVE_STRUCT_TM_TM_GMTOFF
       time_t t;
       struct tm *ct;
       if (!convert_to_time_t(&n, &t))
           fail;
       ct = localtime(&t);
       return C_integer ct->tm_gmtoff;
#else
       fail;
#endif
   }
end


#endif /* PLAN9 */

/* RamStream implementation */

struct sdescrip ptrf = {3, "ptr"};

struct ramstream {
    word pos, size, avail, wiggle;
    char *data;
};

#begdef GetSelfRs()
struct ramstream *self_rs;
dptr self_rs_dptr;
static struct inline_field_cache self_rs_ic;
self_rs_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_rs_ic);
if (!self_rs_dptr)
    syserr("Missing ptr field");
self_rs = (struct ramstream*)IntVal(*self_rs_dptr);
if (!self_rs)
    runerr(219, self);
#enddef

function io_RamStream_close(self)
   body {
       GetSelfRs();
       free(self_rs->data);
       free(self_rs);
       *self_rs_dptr = zerodesc;
       return self;
   }
end

function io_RamStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       tended struct descrip result;
       GetSelfRs();

       if (i <= 0)
           Irunerr(205, i);

       if (self_rs->pos >= self_rs->size)
           return nulldesc;

       i = Min(i, self_rs->size - self_rs->pos);
       bytes2string(&self_rs->data[self_rs->pos], i, &result);
       self_rs->pos += i;
       
       return result;
   }
end

function io_RamStream_new_impl(s, wiggle)
   if !def:string(s, emptystr) then
      runerr(103, s)
   if !def:C_integer(wiggle, 512) then
      runerr(101, wiggle)
   body {
       struct ramstream *p;
       if (wiggle < 0)
           Irunerr(205, wiggle);
       p = rt_malloc(sizeof(*p));
       p->wiggle = wiggle;
       p->pos = p->size = StrLen(s);
       p->avail = p->size + p->wiggle;
       p->data = rt_malloc(p->avail);
       memcpy(p->data, StrLoc(s), p->size);
       return C_integer((word)p);
   }
end

function io_RamStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       GetSelfRs();
       if (self_rs->pos + StrLen(s) > self_rs->avail) {
           self_rs->avail = 2 * (self_rs->pos + StrLen(s));
           self_rs->data = rt_realloc(self_rs->data, self_rs->avail);
       }

       if (self_rs->pos > self_rs->size)
           memset(&self_rs->data[self_rs->size], 0, self_rs->pos - self_rs->size);

       memcpy(&self_rs->data[self_rs->pos], StrLoc(s), StrLen(s));
       self_rs->pos += StrLen(s);
       if (self_rs->pos > self_rs->size)
           self_rs->size = self_rs->pos;

       return C_integer StrLen(s);
   }
end

function io_RamStream_seek(self, offset)
   if !cnv:C_integer(offset) then
      runerr(101, offset)
   body {
       GetSelfRs();
       if (offset > 0)
           self_rs->pos = offset - 1;
       else {
           if (self_rs->size < -offset) {
               LitWhy("Invalid value to seek");
               fail;
           }
           self_rs->pos = self_rs->size + offset;
       }
       return C_integer(self_rs->pos + 1);
   }
end

function io_RamStream_tell(self)
   body {
       GetSelfRs();
       return C_integer(self_rs->pos + 1);
   }
end

function io_RamStream_truncate(self, len)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
       GetSelfRs();
       self_rs->pos = len;
       self_rs->avail = len + self_rs->wiggle;
       self_rs->data = rt_realloc(self_rs->data, self_rs->avail);
       if (self_rs->size < len)
           memset(&self_rs->data[self_rs->size], 0, len - self_rs->size);
       self_rs->size = len;
       return self;
   }
end

function io_RamStream_str(self)
   body {
       tended struct descrip result;
       GetSelfRs();
       bytes2string(self_rs->data, self_rs->size, &result);
       return result;
   }
end

function lang_Constructor_get_name(c)
    body {
        struct b_constructor *constructor0;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        return *constructor0->name;
    }
end

function lang_Constructor_get_constructor(c)
    body {
        struct b_constructor *constructor0;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        return constructor(constructor0);
    }
end

function lang_Constructor_get_program(c)
    body {
        struct b_constructor *constructor0;
        struct progstate *prog;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        prog = constructor0->program;
        if (!prog)
            fail;
        return coexpr(prog->K_main);
    }
end

function lang_Constructor_get_n_fields(c)
   body {
        struct b_constructor *constructor0;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        return C_integer constructor0->n_fields;
     }
end

function lang_Constructor_get_field_index(c, field)
   body {
        struct b_constructor *constructor0;
        int i;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_record_field(constructor0, &field, 0);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function lang_Constructor_get_field_location_impl(c, field)
   body {
        struct b_constructor *constructor0;
        int i;
        tended struct descrip result;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        if (!constructor0->field_locs) {
            LitWhy("No constructor field location data in icode");
            fail;
        }
        i = lookup_record_field(constructor0, &field, 0);
        if (i < 0) {
            LitWhy("Unknown field");
            fail;
        }
        loc_to_list(&constructor0->field_locs[i], &result);
        return result;
     }
end

function lang_Constructor_get_field_name(c, field)
   body {
        struct b_constructor *constructor0;
        int i;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_record_field(constructor0, &field, 0);
        if (i < 0)
            fail;
        return *constructor0->program->Fnames[constructor0->fnums[i]];
     }
end

static int lookup_proc_local(struct p_proc *proc, dptr query)
{
    word nf;

    if (!proc->program)
        return -1;

    nf = proc->nparam + proc->ndynam + proc->nstatic;

    if (is:string(*query)) {
        word i;
        for (i = 0; i < nf; ++i) {
            if (eq(proc->lnames[i], query))
                return (int)i;
        }
        return -1;
    }

    if (query->dword == D_Integer) {
        word i = cvpos_item(IntVal(*query), nf);
        if (i == CvtFail)
            return -1;
        return i - 1;
    }

    syserr("Invalid query type to lookup_proc_local");
    /* Not reached */
    return 0;
}

static struct p_proc *get_procedure(struct b_proc *bp)
{
    struct p_proc *pp;
    if (bp->type != P_Proc)
        return 0;
    pp = (struct p_proc *)bp;
    if (!pp->program)
        return 0;
    return pp;
}

function lang_Proc_get_n_arguments(c)
   body {
      struct b_proc *proc0;
      if (!(proc0 = get_proc_for(&c)))
          runerr(0);
      return C_integer proc0->nparam;
   }
end

function lang_Proc_has_varargs(c)
   body {
      struct b_proc *proc0;
      if (!(proc0 = get_proc_for(&c)))
          runerr(0);
      if (proc0->vararg)
          return nulldesc;
      else
          fail;
   }
end

function lang_Proc_get_n_dynamics(c)
   body {
       struct b_proc *proc0;
       struct p_proc *pp;
       if (!(proc0 = get_proc_for(&c)))
           runerr(0);
       if (!(pp = get_procedure(proc0)))
           fail;
       return C_integer pp->ndynam;
     }
end

function lang_Proc_get_n_statics(c)
   body {
       struct b_proc *proc0;
       struct p_proc *pp;
       if (!(proc0 = get_proc_for(&c)))
          runerr(0);
       if (!(pp = get_procedure(proc0)))
           fail;
        return C_integer pp->nstatic;
     }
end

function lang_Proc_get_local_index(c, id)
   body {
        struct b_proc *proc0;
        struct p_proc *pp;
        int i;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        if (!(pp = get_procedure(proc0)))
           fail;
        i = lookup_proc_local(pp, &id);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function lang_Proc_get_local_location_impl(c, id)
   body {
        int i;
        struct b_proc *proc0;
        struct p_proc *pp;
        tended struct descrip result;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        if (!(pp = get_procedure(proc0))) {
            LitWhy("Not a Procedure");
            fail;
        }
        if (!pp->llocs) {
            LitWhy("No local location data in icode");
            fail;
        }
        i = lookup_proc_local(pp, &id);
        if (i < 0) {
            LitWhy("Unknown local");
            fail;
        }
        loc_to_list(&pp->llocs[i], &result);
        return result;
     }
end

function lang_Proc_get_local_name(c, id)
   body {
        struct b_proc *proc0;
        struct p_proc *pp;
        int i;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        if (!(pp = get_procedure(proc0)))
            fail;
        i = lookup_proc_local(pp, &id);
        if (i < 0)
            fail;
        return *pp->lnames[i];
     }
end

function lang_Proc_get_local_kind(c, id)
   body {
        struct b_proc *proc0;
        struct p_proc *pp;
        int i;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        if (!(pp = get_procedure(proc0)))
            fail;
        i = lookup_proc_local(pp, &id);
        if (i < 0)
            fail;
        if (i < pp->nparam)
            return C_integer Argument;
        if (i < pp->nparam + pp->ndynam)
            return C_integer Dynamic;
        return C_integer Static;
     }
end

function lang_Proc_get_name(c, flag)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
           runerr(0);
        if (!isflag(&flag))
           runerr(171, flag);
        if (proc0->field && is:null(flag)) {
            tended struct descrip result;
            int len;
            struct b_class *class0 = proc0->field->defining_class;
            dptr fname = class0->program->Fnames[proc0->field->fnum];
            len = StrLen(*class0->name) + StrLen(*fname) + 1;
            MemProtect (StrLoc(result) = reserve(Strings, len));
            StrLen(result) = len;
            alcstr(StrLoc(*class0->name), StrLen(*class0->name));
            alcstr(".", 1);
            alcstr(StrLoc(*fname),StrLen(*fname));
            return result;
        } else
            return *proc0->name;
     }
end

function lang_Proc_get_program(c, flag)
    body {
        struct b_proc *proc0;
        struct progstate *prog;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (!isflag(&flag))
           runerr(171, flag);
        if (proc0->field && is:null(flag))
            prog = proc0->field->defining_class->program;
        else {
            struct p_proc *pp;
            if (!(pp = get_procedure(proc0)))
                fail;
            prog = pp->program;
        }
        return coexpr(prog->K_main);
    }
end

function lang_Proc_get_kind(c)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        return C_integer get_proc_kind(proc0);
     }
end

function lang_Proc_is_defined(c)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (proc0 == (struct b_proc *)&Bdeferred_method_stub)
            fail;
        else
            return nulldesc;
     }
end

function lang_Proc_get_defining_class(c)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (proc0->field)
            return class(proc0->field->defining_class);
        else
            fail;
     }
end

function lang_Proc_get_field_name(c)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (proc0->field)
            return *proc0->field->defining_class->program->Fnames[proc0->field->fnum];
        else
            fail;
     }
end

function lang_Proc_get_field_index(c)
   body {
        struct b_proc *proc0;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (proc0->field)
            return C_integer 1 + lookup_class_field_by_fnum(proc0->field->defining_class, proc0->field->fnum);
        else
            fail;
     }
end

function lang_Internal_compare(x, y)
   body {
      return C_integer anycmp(&x, &y);
   }
end

function lang_Internal_hash(x)
   body {
      return C_integer hash(&x) & MaxWord;
   }
end

function lang_Coexpression_traceback(ce, act_chain)
   body {
       tended struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       if (!isflag(&act_chain))
          runerr(171, act_chain);
       traceback(b, 0, !is:null(act_chain));
       return nulldesc;
   }
end

function lang_Coexpression_get_stack_info_impl(ce, lim)
   if !def:C_integer(lim, -1) then
      runerr(101, lim)
   body {
       struct p_frame *pf;
       tended struct b_coexpr *b;
       struct ipc_line *pline;
       struct ipc_fname *pfile;

       if (!(b = get_coexpr_for(&ce)))
          runerr(0);

       for (pf = b->curr_pf; lim && pf; pf = pf->caller) {
           if (pf->proc->program) {
                struct descrip prc;
                tended struct descrip img, args, result;
                dptr arg;
                word nargs;

                create_list(4, &result);
                prc.dword = D_Proc;
                BlkLoc(prc) = (union block*)pf->proc;
                getimage(&prc, &img);
                list_put(&result, &img);
                
                nargs = pf->proc->nparam;
                create_list(nargs, &args);
                arg = pf->fvars->desc;
                while (nargs--) {
                    getimage(arg++, &img);
                    list_put(&args, &img);
                }

                list_put(&result, &args);

                pline = frame_ipc_line(pf);
                pfile = frame_ipc_fname(pf);
                if (pline && pfile) {
                    struct descrip lno;
                    MakeInt(pline->line, &lno);
                    list_put(&result, pfile->fname);
                    list_put(&result, &lno);
                }
                suspend result;
                --lim;
            }
       }

       fail;
   }
end

#if PLAN9
function io_Files_bind(name, old, flag)
   if !cnv:C_string(name) then
      runerr(103, name)
   if !cnv:C_string(old) then
      runerr(103, old)
   if !cnv:C_integer(flag) then
      runerr(101, flag)

   body {
       if (bind(name, old, flag) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function io_Files_mount(f, af, old, flag, aname)
   if !cnv:C_string(old) then
      runerr(103, old)
   if !cnv:C_integer(flag) then
      runerr(101, flag)
   if !cnv:C_string(aname) then
      runerr(103, aname)

   body {
       int afd;
       FdStaticParam(f, fd);
       if (is:null(af))
           afd = -1;
       else {
           FdStaticParam(af, tmp);
           afd = tmp;
       }
       if (mount(fd, afd, old, flag, aname) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function io_Files_unmount(name, old)
   if !cnv:C_string(old) then
      runerr(103, old)

   body {
       tended char *s;
       if (is:null(name))
           s = 0;
       else if (!cnv:C_string(name, s))
           runerr(103, name);

       if (unmount(s, old) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function io_DescStream_length(self)
   body {
       tended struct descrip result;
       struct Dir *st;
       GetSelfFd();
       if (!(st = dirfstat(self_fd))) {
           errno2why();
           fail;
       }
       convert_from_vlong(st->length, &result);
       free(st);
       return result;
   }
end


enum fileworker_status { FW_RUNNING, FW_COMPLETE };
enum fileworker_cmd { FW_READ, FW_WRITE, FW_OPEN, FW_CREATE, FW_CLOSE, FW_WRITE_ALL };

struct fileworker {
    int pid;
    int status;
    QLock l;
    Rendez rz;
    char *buff;
    long buff_size, read_size, write_size;
    int cmd;
    int fd, mode;
    ulong perm;
    long result;
    char errstr[ERRMAX];
    int close_when_complete;
    struct fileworker *next, *prev;
};

static struct fileworker *fileworkers;

static void wait_for_fileworker_status(struct fileworker *w, int status)
{
    if (w->status != status) {
        qlock(&w->l);
        while (w->status != status)
            rsleep(&w->rz);
        qunlock(&w->l);
    }
}

static void set_fileworker_status(struct fileworker *w, int status)
{
    if (w->status == status)
        syserr("status in set_fileworker_status inconsistent");
    qlock(&w->l);
    w->status = status;
    rwakeup(&w->rz);
    qunlock(&w->l);
}

static long write_all(int fd, void *buf, long nbytes)
{
    long n = nbytes;
    char *p = buf;
    while (n > 0) {
        long r = write(fd, p, n);
        if (r < 0)
            return r;
        n -= r;
        p += r;
    }
    return nbytes;
}

static void fileworker_loop(struct fileworker *w)
{
    for(;;) {
        wait_for_fileworker_status(w, FW_RUNNING);
        switch (w->cmd) {
            case FW_READ: {
                w->result = read(w->fd, w->buff, w->read_size);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                break;
            }
            case FW_WRITE: {
                w->result = write(w->fd, w->buff, w->write_size);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                break;
            }
            case FW_OPEN: {
                w->result = open(w->buff, w->mode);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                else
                    w->fd = w->result;
                break;
            }
            case FW_CREATE: {
                w->result = create(w->buff, w->mode, w->perm);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                else
                    w->fd = w->result;
                break;
            }
            case FW_CLOSE: {
                w->result = close(w->fd);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                else
                    w->fd = -1;
                break;
            }
            case FW_WRITE_ALL: {
                w->result = write_all(w->fd, w->buff, w->write_size);
                if (w->result < 0)
                    errstr(w->errstr, sizeof(w->errstr));
                break;
            }
        }
        set_fileworker_status(w, FW_COMPLETE);
        if (w->close_when_complete) {
            free(w->buff);
            if (w->fd >= 0)
                close(w->fd);
            free(w);
            _exits(0);
        }
    }
}

static void cleanup_fileworker(struct fileworker *w)
{
    /*
     * Unfortunately there is a race condition in the kill_proc, when
     * killing an open or create command, since the worker process may
     * be killed between the point open/create returns and the w->fd
     * member is updated.  This may leave a redundant file descriptor
     * in the file table.
     */
    if (w->pid >= 0)
        kill_proc(w->pid);
    free(w->buff);
    if (w->fd >= 0)
        close(w->fd);
    GUnlink4(w, fileworkers, next, prev);
    free(w);
}

static void cleanup_fileworkers(void)
{
    while (fileworkers)
        cleanup_fileworker(fileworkers);
}

static void catchpipe(void *a, char *msg)
{
    static char *foo = "sys: write on closed pipe";
    if (strncmp(msg, foo, strlen(foo)) == 0)
        noted(NCONT);
    else
        noted(NDFLT);
}

#begdef GetSelfFileWorker()
struct fileworker *self_fileworker;
dptr self_fileworker_dptr;
static struct inline_field_cache self_fileworker_ic;
self_fileworker_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_fileworker_ic);
if (!self_fileworker_dptr)
    syserr("Missing ptr field");
self_fileworker = (struct fileworker*)IntVal(*self_fileworker_dptr);
if (!self_fileworker)
    runerr(219, self);
#enddef

function io_FileWorker_new_impl(buff_size, f)
   if !def:C_integer(buff_size, 1024) then
      runerr(101, buff_size)
   body {
       struct fileworker *p;
       int pid, fd;
       static int fileworker_inited;
       if (is:null(f))
           fd = -1;
       else {
           FdStaticParam(f, tmp);
           fd = tmp;
       }

       if (!fileworker_inited) {
           atexit(cleanup_fileworkers);
           fileworker_inited = 1;
       }

       p = rt_zalloc(sizeof(*p));
       GLink4(p, fileworkers, next, prev);

       p->pid = -1;
       p->buff = rt_zalloc(buff_size);
       p->buff_size = buff_size;
       p->fd = fd;
       if (p->fd >= 0)
           p->fd = dup(p->fd, -1);
       p->rz.l = &p->l;
       p->status = FW_COMPLETE;
       switch (pid = rfork(RFPROC|RFMEM)) {
           case 0: {
               notify(catchpipe);
               fileworker_loop(p);
               /* Not reached */
               break;
           }
           case -1: {
               whyf("rfork failed: %r");
               cleanup_fileworker(p);
               fail;
           }
       }
       p->pid = pid;
       return C_integer((word)p);
   }
end

#begdef StartFileWorkerCmd(x)
   self_fileworker->cmd = x;
   self_fileworker->result = 0;
   self_fileworker->errstr[0] = 0;
   set_fileworker_status(self_fileworker, FW_RUNNING);
   return self;
#enddef

function io_FileWorker_op_read(self, n)
   body {
      word i;
      GetSelfFileWorker();
      if (is:null(n))
          i = self_fileworker->buff_size;
      else {
          if (!cnv:C_integer(n, i))
              runerr(101, n);
          if (i <= 0)
              Irunerr(205, i);
          if (i > self_fileworker->buff_size) {
              LitWhy("Request size too long for buffer");
              fail;
          }
      }
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      self_fileworker->read_size = i;
      StartFileWorkerCmd(FW_READ);
   }
end

function io_FileWorker_op_write(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      GetSelfFileWorker();
      if (StrLen(s) > self_fileworker->buff_size) {
          LitWhy("String too long for buffer");
          fail;
      }
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      self_fileworker->write_size = StrLen(s);
      memcpy(self_fileworker->buff, StrLoc(s), StrLen(s));
      StartFileWorkerCmd(FW_WRITE);
   }
end

function io_FileWorker_op_write_all(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      GetSelfFileWorker();
      if (StrLen(s) > self_fileworker->buff_size) {
          LitWhy("String too long for buffer");
          fail;
      }
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      self_fileworker->write_size = StrLen(s);
      memcpy(self_fileworker->buff, StrLoc(s), StrLen(s));
      StartFileWorkerCmd(FW_WRITE_ALL);
   }
end

function io_FileWorker_op_open(self, path, mode)
   if !cnv:string(path) then
      runerr(103, path)
   if !cnv:C_integer(mode) then
      runerr(101, mode)
   body {
      GetSelfFileWorker();
      if (StrLen(path) >= self_fileworker->buff_size) {
          LitWhy("String too long for buffer");
          fail;
      }
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      memcpy(self_fileworker->buff, StrLoc(path), StrLen(path));
      self_fileworker->buff[StrLen(path)] = 0;
      self_fileworker->mode = mode;
      StartFileWorkerCmd(FW_OPEN);
   }
end

function io_FileWorker_op_create(self, path, mode, perm)
   if !cnv:string(path) then
      runerr(103, path)
   if !cnv:C_integer(mode) then
      runerr(101, mode)
   body {
      ulong uperm;
      GetSelfFileWorker();
      if (is:null(perm))
          uperm = 0664;
      else {
          if (!convert_to_ulong(&perm, &uperm))
              runerr(0);
      }
      if (StrLen(path) >= self_fileworker->buff_size) {
          LitWhy("String too long for buffer");
          fail;
      }
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      memcpy(self_fileworker->buff, StrLoc(path), StrLen(path));
      self_fileworker->buff[StrLen(path)] = 0;
      self_fileworker->mode = mode;
      self_fileworker->perm = uperm;
      StartFileWorkerCmd(FW_CREATE);
   }
end

function io_FileWorker_op_close(self)
   body {
      GetSelfFileWorker();
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      StartFileWorkerCmd(FW_CLOSE);
   }
end

function io_FileWorker_is_running(self)
   body {
      GetSelfFileWorker();
      if (self_fileworker->status == FW_RUNNING)
          return nulldesc;
      else
          fail;
   }
end

function io_FileWorker_get_buff_size(self)
   body {
      GetSelfFileWorker()
      return C_integer self_fileworker->buff_size;
   }
end

function io_FileWorker_get_buff(self, n)
   if !cnv:C_integer(n) then
      runerr(101, n)
   body {
      tended struct descrip result;
      GetSelfFileWorker()
      if (n <= 0)
           Irunerr(205, n);
      if (n > self_fileworker->buff_size) {
          LitWhy("Request size too long for buffer");
          fail;
      }
      bytes2string(self_fileworker->buff, n, &result);
      return result;
   }
end

function io_FileWorker_get_result(self)
   body {
      GetSelfFileWorker()
      return C_integer self_fileworker->result;
   }
end

function io_FileWorker_await(self)
   body {
      GetSelfFileWorker()
      wait_for_fileworker_status(self_fileworker, FW_COMPLETE);
      if (self_fileworker->result < 0) {
          why(self_fileworker->errstr);
          fail;
      }
      return C_integer self_fileworker->result;
   }
end

function io_FileWorker_close(self)
   body {
      GetSelfFileWorker()
      cleanup_fileworker(self_fileworker);
      *self_fileworker_dptr = zerodesc;
      return self;
   }
end

function io_FileWorker_close_when_complete(self)
   body {
      GetSelfFileWorker()
      qlock(&self_fileworker->l);
      if (self_fileworker->status == FW_RUNNING) {
         self_fileworker->close_when_complete = 1;
         qunlock(&self_fileworker->l);
         GUnlink4(self_fileworker, fileworkers, next, prev);
      } else {
         qunlock(&self_fileworker->l);
         cleanup_fileworker(self_fileworker);
      }
      *self_fileworker_dptr = zerodesc;
      return self;
   }
end

function io_FileWorker_dup_fd(self)
   body {
      int i;
      GetSelfFileWorker();
      if ((i = dup(self_fileworker->fd, -1)) < 0) {
          errno2why();
          fail;
      }
      return C_integer i;
   }
end

#endif

function weakref(val)
   body {
      type_case val of {
        list:
        set:   
        table: 
        record:
        methp:
        object:
        coexpr: {
              struct b_weakref *p;
              MemProtect(p = alcweakref());
              p->val = val;
              return weakref(p);
          }
       default:
           fail;
     }
  }
end

function weakrefval(wr)
   if !is:weakref(wr) then
       runerr(630, wr)
   body {
       struct descrip t = WeakrefBlk(wr).val;
       if (is:null(t))
           fail;
       return t;
    }
end

function io_PttyStream_new_impl()
   body {
#if UNIX
       int fd;
       char *sn;
       tended struct descrip result, tmp;

       if ((fd = posix_openpt(O_RDWR | O_NOCTTY)) < 0) {
           errno2why();
           fail;
       }
       if (grantpt(fd) < 0) {
           errno2why();
           close(fd);
           fail;
       }
       if (unlockpt(fd) < 0) {
           errno2why();
           close(fd);
           fail;
       }
       sn = ptsname(fd);
       if (!sn) {
           errno2why();
           close(fd);
           fail;
       }

       create_list(2, &result);
       MakeInt(fd, &tmp);
       list_put(&result, &tmp);
       cstr2string(sn, &tmp);
       list_put(&result, &tmp);

       return result;
#else
       Unsupported;
#endif
    }
end

#if UNIX
function io_PttyStream_prepare_slave(f)
    body {
       FdStaticParam(f, fd);
#if HAVE_TIOCSCTTY                        /* Acquire controlling tty on BSD */
       if (ioctl(fd, TIOCSCTTY, 0) < 0) {
           errno2why();
           fail;
       }
#endif
#if OS_SOLARIS
       if (ioctl(fd, I_PUSH, "ptem") < 0) {
           errno2why();
           fail;
       }
       if (ioctl(fd, I_PUSH, "ldterm") < 0) {
           errno2why();
           fail;
       }
#endif
       return nulldesc;
    }
end

function io_PttyStream_set_size(self, cols, rows)
   if !cnv:C_integer(rows) then
      runerr(101, rows)
   if !cnv:C_integer(cols) then
      runerr(101, cols)
    body {
       struct winsize ws;
       GetSelfFd();
       ws.ws_row = rows;
       ws.ws_col = cols;
       if (ioctl(self_fd, TIOCSWINSZ, &ws) < 0) {
           errno2why();
           fail;
       }
       return self;
    }
end
#endif
