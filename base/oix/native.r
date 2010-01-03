#include "../h/modflags.h"

static struct descrip stat2list(struct stat *st);

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

      cast:
            return CastBlk(*x).class;
                    
     default: 
            ReturnErrVal(620, *x, 0);
    }
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
         cast: return class(CastBlk(o).class);
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

static void extract_package(dptr s, dptr d)
{
    char *p = StrLoc(*s) + StrLen(*s);
    while (--p >= StrLoc(*s)) {
        if (*p == '.') {
            MakeStr(StrLoc(*s), p - StrLoc(*s), d);
            return;
        }
    }
    syserr("In a package, but no dots");  
}

/*
 * These macros are used to convert to/from various integer types
 * which may be bigger than a word and may or may not be signed.
 */

#begdef convert_to_macro(TYPE)
static int convert_to_##TYPE(dptr src, TYPE *dest)
{
    struct descrip bits, intneg16, int65535, digs;
    tended struct descrip i, t, u, pwr;
    TYPE res = 0;
    int pos = 0, k;

    /*
     * If we have a normal integer, try a conversion to the target type.
     */
    if (Type(*src) == T_Integer &&
        sizeof(TYPE) >= sizeof(word) &&
        (((TYPE)-1 < 0) || IntVal(*src) >= 0))   /* TYPE signed, or src +ve */
    {
        *dest = IntVal(*src);
        return 1;
    }

    MakeInt(-16, &intneg16);
    MakeInt(65535, &int65535);
    /* pwr = 2 ^ "n bits in TYPE" */
    MakeInt(sizeof(TYPE) * 8, &digs);
    bigshift(&onedesc, &digs, &pwr);
    i = *src;
    if (bigcmp(&i, &zerodesc) < 0) {
        /* Check TYPE is signed */
        if ((TYPE)-1 > 0)
            ReturnErrVal(101, *src, 0);
        bigshift(&pwr, &minusonedesc, &t);
        /* src must be >= -ve pwr/2 */
        bigneg(&t, &u);
        if (bigcmp(&i, &u) < 0)
            ReturnErrVal(101, *src, 0);
        /* Convert to the two's complement representation of i (i := pwr + i) */
        bigadd(&i, &pwr, &i);
    } else if ((TYPE)-1 > 0) {
        /* TYPE unsigned, i must be < pwr */
        if (bigcmp(&i, &pwr) >= 0)
            ReturnErrVal(101, *src, 0);
    } else {
        /* TYPE signed - src must be < pwr/2 */
        bigshift(&pwr, &minusonedesc, &t);
        if (bigcmp(&i, &t) >= 0)
            ReturnErrVal(101, *src, 0);
    }

    /*
     * Copy the bits in the converted source (it is now in two's
     * complement form) into the target.
     */
    for (k = 0; k < sizeof(TYPE) / 2; ++k) {
        bigand(&i, &int65535, &bits);
        bigshift(&i, &intneg16, &i);
        res |= ((ulonglong)IntVal(bits) << pos);
        pos += 16;
    }
    *dest = res;
    return 1;
}
#enddef

#begdef convert_from_macro(TYPE)
static void convert_from_##TYPE(TYPE src, dptr dest)
{
    TYPE j = src;
    int k;
    struct descrip pos = zerodesc, digs;
    tended struct descrip res, chunk, pwr;

    /* See if it fits in a word */
    if (src <= MaxWord && src >= MinWord) {
        MakeInt(src, dest);
        return;
    }

    /* Copy the raw bits of src, to dest in 16 bit chunks.  For a -ve
     * src, the two's complement representation is copied, and then
     * converted below
     */
    res = zerodesc;
    for (k = 0; k < sizeof(TYPE) / 2; ++k) {
        int bits = j & 0xffff;
        j = j >> 16;
        MakeInt(bits, &chunk);
        bigshift(&chunk, &pos, &chunk);
        bigadd(&res, &chunk, &res);
        IntVal(pos) += 16;
    }
    if (src < 0) {
        /* pwr = 2 ^ "n bits in TYPE" */
        MakeInt(sizeof(TYPE) * 8, &digs);
        bigshift(&onedesc, &digs, &pwr);
        /* Convert from two's complement to true value - res := res - pwr */
        bigsub(&res, &pwr, &res);
    }
    *dest = res;
}
#enddef
convert_to_macro(off_t)
convert_from_macro(off_t)
#if UNIX
convert_from_macro(ino_t)
convert_from_macro(blkcnt_t)
#endif
convert_from_macro(ulonglong)

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

function lang_Prog_get_variable_name(underef v)
   /*
    * v must be a variable
    */
   if !is:variable(v) then
      runerr(111, v);

   body {
      tended struct descrip result;
      word i = get_name(&v, &result);
      if (i == Error)
         runerr(0);
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

      if (StrLen(s) == 0 || *StrLoc(s) != '&')
         fail;

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
              if (strncmp(t,"error",5) == 0) {
                  return kywdint(&(p->Kywd_err));
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
                  return p->K_errortext;
              }
              break;
          }

          case 11 : {
              if (strncmp(t,"errorvalue",10) == 0) {
                  return p->K_errorvalue;
              }
              break;
          }
          case 12 : {
              if (strncmp(t,"errornumber",11) == 0) {
                  return C_integer p->K_errornumber;
              }
              break;
          }
      }

      runerr(205, s);
   }
end


function lang_Prog_get_global(s, c)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       p = lookup_global(&s, prog);
       if (p)
           return named_var(p);
       else
           fail;
   }
end

function lang_Prog_get_globals(c)
   body {
       struct progstate *prog;
       dptr dp;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       for (dp = prog->Globals; dp != prog->Eglobals; dp++)
           suspend named_var(dp);

      fail;
   }
end

function lang_Prog_get_global_names(c)
   body {
       struct progstate *prog;
       dptr *dp;
       if (!(prog = get_program_for(&c)))
          runerr(0);
      for (dp = prog->Gnames; dp != prog->Egnames; dp++)
         suspend **dp;
      fail;
   }
end

function lang_Prog_get_functions()
   body {
      register int i;

      for (i = 0; i < fnc_tbl_sz; ++i)
          suspend proc(fnc_tbl[i]);

      fail;
      }
end

function lang_Prog_get_operators()
   body {
      register int i;

      for (i = 0; i < op_tbl_sz; ++i)
          suspend proc(op_tbl[i]);

      fail;
      }
end

function lang_Prog_get_keywords()
   body {
      register int i;

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
       if (n < 1 || n > 3) {
           irunerr(205, n);
           errorfail;
       }
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


function lang_Prog_get_global_location_impl(s, c)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       struct loc *p;
       tended struct descrip result;
       if (!(prog = get_program_for(&c)))
          runerr(0);

       if (prog->Glocs == prog->Eglocs) {
           LitWhy("No global location data in icode");
           fail;
       }
           
       p = lookup_global_loc(&s, prog);
       if (!p) {
           LitWhy("Unknown symbol");
           fail;
       }

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
       tended struct b_coexpr *b;
       struct p_frame *pf;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
       pf = get_current_user_frame_of(b);
       if (pf)
           return coexpr(pf->proc->program->K_main);
       else
           fail;
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
       tended struct descrip lt1, lt2, result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      if (tp.tv_sec - prog->start_time.tv_sec < (MaxWord/1000)) {
          MakeInt((tp.tv_sec - prog->start_time.tv_sec) * 1000 + 
                  (tp.tv_usec - prog->start_time.tv_usec) / 1000, &result);
      } else {
          MakeInt(tp.tv_sec - prog->start_time.tv_sec, &ls);
          MakeInt(tp.tv_usec - prog->start_time.tv_usec, &lm);
          bigmul(&ls, &thousanddesc, &lt1);
          bigdiv(&lm, &thousanddesc ,&lt2);
          bigadd(&lt1, &lt2, &result);
      }
      return result;
   }
end

function lang_Prog_get_startup_micros(c)
   body {
       struct progstate *prog;
       struct descrip ls, lm;
       tended struct descrip lt1, result;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       MakeInt(prog->start_time.tv_sec, &ls);
       MakeInt(prog->start_time.tv_usec, &lm);
       bigmul(&ls, &milliondesc, &lt1);
       bigadd(&lt1, &lm, &result);
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
       struct descrip tmp;
       tended struct descrip l, result;
       int n;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       create_list(2, &result);

       n = 0;
       for (rp = prog->stringregion; rp; rp = rp->next)
           ++n;
       for (rp = prog->stringregion->prev; rp; rp = rp->prev)
           ++n;
       create_list(2 * (n + 1), &l);
       list_put(&result, &l);
       for (rp = prog->stringregion; rp; rp = rp->next) {
           MakeInt(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           MakeInt(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }
       for (rp = prog->stringregion->prev; rp; rp = rp->prev) {
           MakeInt(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           MakeInt(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }

       n = 0;
       for (rp = prog->blockregion; rp; rp = rp->next)
           ++n;
       for (rp = prog->blockregion->prev; rp; rp = rp->prev)
           ++n;
       create_list(2 * (n + 1), &l);
       list_put(&result, &l);
       for (rp = prog->blockregion; rp; rp = rp->next) {
           MakeInt(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           MakeInt(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }
       for (rp = prog->blockregion->prev; rp; rp = rp->prev) {
           MakeInt(DiffPtrs(rp->free,rp->base), &tmp);
           list_put(&l, &tmp);
           MakeInt(DiffPtrs(rp->end,rp->base), &tmp);
           list_put(&l, &tmp);
       }

       return result;
   }
end

function lang_Prog_get_stack_used(c)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       return C_integer prog->stackcurr;
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
    if (prog && (t = lookup_global(s, prog))) {
       if (is:proc(*t))
           return &ProcBlk(*t);
       else
           return 0;
   }

    /*
     * See if the string represents an operator. In this case the arity
     *  of the operator must match the one given.
     */
    if (arity && !isalpha((unsigned char)*StrLoc(*s)) && *StrLoc(*s) != '&') {
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

   else if cnv:tmp_string(x) then {
      /*
       * n must be 1, 2, or 3; it defaults to 1.
       */
      if !def:C_integer(n, 1) then
         runerr(101, n)
      body {
         struct b_proc *p;
	 struct progstate *prog;

         if (n < 1 || n > 3) {
            irunerr(205, n);
            errorfail;
         }

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

function lang_Class_get_package(c)
    body {
        struct b_class *class0;
        tended struct descrip result;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        if (class0->package_id == 0)
            fail;
        extract_package(class0->name, &result);
        return result;
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

function lang_Class_get_location_impl(c)
    body {
        struct b_class *class0;
        struct loc *p;
        tended struct descrip result;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        if (class0->program->Glocs == class0->program->Eglocs) {
            LitWhy("No global location data in icode");
            fail;
        }
        p = lookup_global_loc(class0->name, class0->program);
        if (!p)
            syserr("Class name not found in global table");
        loc_to_list(p, &result);
        return result;
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

function lang_Class_get_cast_object(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return object(CastBlk(c).object);
    }
end

function lang_Class_get_cast_class(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return class(CastBlk(c).class);
    }
end

#begdef CheckField(field)
{
    word x;
    if (cnv:C_integer(field, x))
        MakeInt(x, &field);
    else if (!cnv:string(field,field))
        runerr(170,field);
}
#enddef

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

function lang_Class_get_n_fields(c)
   body {
        struct b_class *class0;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        return C_integer class0->n_instance_fields + class0->n_class_fields;
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

function lang_Class_get_field_names(c)
    body {
        struct b_class *class0;
        dptr *fn;
        word i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        fn = class0->program->Fnames;
        for (i = 0; i < class0->n_instance_fields + class0->n_class_fields; ++i)
            suspend *fn[class0->fields[i]->fnum];
        fail;
    }
end

function lang_Class_get_instance_field_names(c)
    body {
        struct b_class *class0;
        dptr *fn;
        word i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        fn = class0->program->Fnames;
        for (i = 0; i < class0->n_instance_fields; ++i)
            suspend *fn[class0->fields[i]->fnum];
        fail;
    }
end

function lang_Class_get_class_field_names(c)
    body {
        struct b_class *class0;
        dptr *fn;
        word i;
        if (!(class0 = get_class_for(&c)))
            runerr(0);
        fn = class0->program->Fnames;
        for (i = class0->n_instance_fields; 
             i < class0->n_instance_fields + class0->n_class_fields; ++i)
            suspend *fn[class0->fields[i]->fnum];
        fail;
    }
end

struct b_proc *clone_b_proc(struct b_proc *bp)
{
    struct b_proc *new0;
    switch (bp->type) {
        case P_Proc: {
            MemProtect(new0 = malloc(sizeof(struct p_proc)));
            memcpy(new0, bp, sizeof(struct p_proc));
            break;
        }
        case C_Proc: {
            MemProtect(new0 = malloc(sizeof(struct c_proc)));
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

function lang_Class_set_method(field, pr)
   body {
        struct p_proc *caller_proc;
        struct b_proc *new_proc;
        struct b_class *class0;
        struct class_field *cf;
        int i;

        CheckField(field);
        if (!is:proc(pr))
            runerr(615, pr);

        caller_proc = get_current_user_proc();
        if (!caller_proc->field)
            runerr(616);
        class0 = caller_proc->field->defining_class;

        i = lookup_class_field(class0, &field, 0);
        if (i < 0)
            runerr(207, field);
        cf = class0->fields[i];

        if (cf->defining_class != class0)
            runerr(616);

        if (!(cf->flags & M_Method))
            runerr(617, field);

        new_proc = &ProcBlk(pr);
        if (new_proc->field)
            runerr(618, pr);

        if (BlkLoc(*cf->field_descriptor) != (union block *)&Bdeferred_method_stub)
            runerr(623, field);

        new_proc = clone_b_proc(new_proc);
        BlkLoc(*cf->field_descriptor) = (union block *)new_proc;
        new_proc->field = cf;

        return pr;
   }
end

#ifdef HAVE_LIBDL

static struct b_proc *try_load(void *handle, struct b_class *class0,  struct class_field *cf)
{
    word i;
    char *fq, *p, *t;
    struct b_proc *blk;
    dptr fname;

    fname = class0->program->Fnames[cf->fnum];
    MemProtect(fq = malloc(StrLen(*class0->name) + StrLen(*fname) + 3));
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

        handle = dlopen(lib, RTLD_LAZY);
        if (!handle) {
            why(dlerror());
            fail;
        }

        for (i = 0; i < class0->n_instance_fields + class0->n_class_fields; ++i) {
            struct class_field *cf = class0->fields[i];
            if ((cf->defining_class == class0) &&
                (cf->flags & M_Method) &&
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

#else						/* HAVE_LIBDL */
function lang_Class_load_library(lib)
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
               unsigned int s:16;
           } i;
           i.c[0] = p[0];
           i.c[1] = p[1];
           return C_integer i.s;
       }
       if (StrLen(s) == 4) {
           union {
               unsigned char c[4];
               unsigned long int w:32;
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

function io_WindowsFilePath_getdcwd(d)
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

static struct sdescrip fdf = {2, "fd"};
static struct sdescrip eof_flagf = {8, "eof_flag"};
static struct sdescrip dsclassname = {13, "io.DescStream"};

#begdef GetSelfEofFlag()
dptr self_eof_flag;
static struct inline_field_cache self_eof_flag_ic;
self_eof_flag = c_get_instance_data(&self, (dptr)&eof_flagf, &self_eof_flag_ic);
if (!self_eof_flag)
   syserr("Missing eof_flag field");
#enddef

#begdef FdStaticParam(p, m)
int m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
static struct inline_global_cache m##_igc;
if (!c_is(&p, (dptr)&dsclassname, &m##_igc))
    runerr(205, p);
m##_dptr = c_get_instance_data(&p, (dptr)&fdf, &m##_ic);
if (!m##_dptr)
    syserr("Missing fd field");
(m) = (int)IntVal(*m##_dptr);
if (m < 0)
    runerr(219, p);
#enddef

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

function io_FileStream_open_impl(path, flags, mode)
   if !cnv:C_string(path) then
      runerr(103, path)

   if !cnv:C_integer(flags) then
      runerr(101, flags)

#if UNIX
   if !def:C_integer(mode, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) then
      runerr(101, mode)
#else
   if !def:C_integer(mode, 0664) then
      runerr(101, mode)
#endif

   body {
       int fd;

#if MSWIN32
       fd = open(path, flags | O_BINARY, mode);
#else
       fd = open(path, flags, mode);
#endif
       if (fd < 0) {
           errno2why();
           fail;
       }

       return C_integer fd;
   }
end

function io_FileStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = read(self_fd, StrLoc(s), i);
       if (nread <= 0) {
           GetSelfEofFlag();

           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {  /* nread == 0 */
               *self_eof_flag = onedesc;
               LitWhy("End of file");
           }
           fail;
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
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return nulldesc;
   }
end

function io_FileStream_truncate(self, len)
   if !cnv:integer(len) then
      runerr(101, len)
   body {
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
       return nulldesc;
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
       return nulldesc;
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

       if (bigcmp(&offset, &zerodesc) > 0) {
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
#if UNIX
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

function io_SocketStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = recv(self_fd, StrLoc(s), i, 0);
       if (nread <= 0) {
           GetSelfEofFlag();

           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {  /* nread == 0 */
               *self_eof_flag = onedesc;
               LitWhy("End of file");
           }
           fail;
       }

       StrLen(s) = nread;

       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(StrLoc(s) + nread);

       return s;
   }
end

function io_SocketStream_socket_impl(domain, typ)
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
        * code, rather than the SIGPIPE signal.
        */
#ifdef HAVE_MSG_NOSIGNAL
       rc = send(self_fd, StrLoc(s), StrLen(s), MSG_NOSIGNAL);
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
       if (close(self_fd) < 0) {
           errno2why();
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return nulldesc;
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

struct sockaddr *parse_sockaddr(char *s, int *len)
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
#endif
    if (strncmp(s, "inet:", 5) == 0) {
        static struct sockaddr_in iss;
        char *t = s + 5, host[128], *p;
        int port;
        struct hostent *hp;

        if (strlen(t) >= sizeof(host)) {
            LitWhy("Name too long");
            return 0;
        }
        strcpy(host, t);
        p = strchr(host, ':');
        if (!p) {
            LitWhy("Bad socket address format");
            return 0;
        }
        *p++ = 0;
        port = atoi(p);
        iss.sin_family = AF_INET;
        iss.sin_port = htons((u_short)port);
        if (strcmp(host, "INADDR_ANY") == 0)
            iss.sin_addr.s_addr = INADDR_ANY;
        else {
            if ((hp = gethostbyname(host)) == NULL) {
                switch (h_errno) {
                    case HOST_NOT_FOUND: LitWhy("Name lookup failure: host not found"); break;
                    case NO_DATA: LitWhy("Name lookup failure: no IP address for host") ; break;
                    case NO_RECOVERY: LitWhy("Name lookup failure: name server error") ; break;
                    case TRY_AGAIN: LitWhy("Name lookup failure: temporary name server error") ; break;
                    default: LitWhy("Name lookup failure") ; break;
                }
                return 0;
            }
            memcpy(&iss.sin_addr, hp->h_addr, hp->h_length);
        }
        *len = sizeof(iss);
        return (struct sockaddr *)&iss;
    }

    LitWhy("Bad socket address format");
    return 0;
}

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

       return nulldesc;
   }
end

function io_SocketStream_bind(self, addr)
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

       if (bind(self_fd, sa, len) < 0) {
           errno2why();
           fail;
       }

       return nulldesc;
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
       return nulldesc;
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
           return nulldesc;
       }
   }
end

function io_DescStream_stat_impl(self)
   body {
       struct stat st;
       GetSelfFd();
       if (fstat(self_fd, &st) < 0) {
           errno2why();
           fail;
       }
       return stat2list(&st);
   }
end

function io_DescStream_select(rl, wl, el, timeout)
    body {
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
       /* A rc of zero means timeout */
       if (rc == 0) {
           LitWhy("Timeout");
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
    }
end

function io_DescStream_poll(a[n])
   body {
#ifdef HAVE_POLL
       static struct pollfd *ufds = 0;
       unsigned int nfds;
       word timeout;
       int i, rc;
       tended struct descrip result;

       nfds = n / 2;
       if (n % 2 == 0 || is:null(a[n - 1]))
           timeout = -1;
       else if (!cnv:C_integer(a[n - 1], timeout))
           runerr(101, a[n - 1]);

       MemProtect(ufds = realloc(ufds, nfds * sizeof(struct pollfd)));

       for (i = 0; i < nfds; ++i) {
           word events;
           FdStaticParam(a[2 * i], fd);
           if (!cnv:C_integer(a[2 * i + 1], events))
               runerr(101, a[2 * i + 1]);
           ufds[i].fd = fd;
           ufds[i].events = (short)events;
       }

       rc = poll(ufds, nfds, timeout);
       if (rc < 0) {
           errno2why();
           fail;
       }
       /* A rc of zero means timeout */
       if (rc == 0) {
           LitWhy("Timeout");
           fail;
       }

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


#if UNIX
static struct sdescrip ddf = {2, "dd"};

#begdef GetSelfDir()
DIR *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ddf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (DIR*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function io_DirStream_open_impl(path)
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

function io_DirStream_read_impl(self)
   body {
       struct dirent *de;
       tended struct descrip result;
       GetSelfDir();
       errno = 0;
       de = readdir(self_dir);
       if (!de) {
           GetSelfEofFlag();
           if (errno) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {
               *self_eof_flag = onedesc;
               LitWhy("End of file");
           }
           fail;
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
           fail;
       }
       *self_dir_dptr = zerodesc;
       return nulldesc;
   }
end

#elif MSWIN32
enum DirDataStatus { EMPTY, FIRST, MORE };

struct DirData {
   WIN32_FIND_DATA fileData;
   int status;
   HANDLE handle;
};

static struct sdescrip ddf = {2, "dd"};

#begdef GetSelfDir()
struct DirData *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ddf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (struct DirData*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function io_DirStream_open_impl(path)
   if !cnv:string(path) then
      runerr(103, path)
   body {
       struct DirData *fd;
       tended char *cpath;
       if (StrLen(path) == 0) {
	  cpath = "*";
       } else {
	  char last = StrLoc(path)[StrLen(path) - 1];
	  if (last == '\\' || last == '/' || last == ':') {
	     MemProtect(cpath = reserve(Strings, StrLen(path) + 2));
	     alcstr(StrLoc(path), StrLen(path));
	     alcstr("*\0", 2);
	  } else {
	     int i;
	     for (i = 0; i < StrLen(path); ++i) {
		char ch = StrLoc(path)[i];
		if (ch == '*' || ch == '?')
		   break;
	     }
	     if (i == StrLen(path)) {
		MemProtect(cpath = reserve(Strings, StrLen(path) + 3));
		alcstr(StrLoc(path), StrLen(path));
		alcstr("\\*\0", 3);
	     } else {
		MemProtect(cpath = reserve(Strings, StrLen(path) + 1));
		alcstr(StrLoc(path), StrLen(path));
		alcstr("\0", 1);
	     }
	  }
       }
       MemProtect(fd = malloc(sizeof(struct DirData)));
       fd->handle = FindFirstFile(cpath, &fd->fileData);
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

function io_DirStream_read_impl(self)
   body {
       tended struct descrip result;
       GetSelfDir();
       if (self_dir->status == EMPTY) {
           GetSelfEofFlag();
	   *self_eof_flag = onedesc;
	   LitWhy("End of file");
           fail;
       }
       if (self_dir->status == FIRST) {
	  cstr2string(self_dir->fileData.cFileName, &result);
	  self_dir->status = MORE;
	  return result;
       }
       if (!FindNextFile(self_dir->handle, &self_dir->fileData)) {
           GetSelfEofFlag();
	   *self_eof_flag = onedesc;
	   LitWhy("End of file");
           fail;
       }
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
       return nulldesc;
   }
end

#endif


function io_Files_rename(s1,s2)
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

#if UNIX
function io_Files_mkdir(s, mode)
   if !cnv:C_string(s) then
      runerr(103, s)

   if !def:C_integer(mode, S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH) then
      runerr(101, mode)

   body {
      if (mkdir(s, mode) < 0) {
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
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
#if HAVE_TRUNCATE
      if (truncate(s, len) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
#else
      int fd;
      fd = open(s, O_WRONLY, 0);
      if (fd < 0) {
           errno2why();
           fail;
      }
      if (ftruncate(fd, len) < 0) {
           errno2why();
           close(fd);
           fail;
      }
      close(fd);
      return nulldesc;
#endif
   }
end

static struct descrip stat2list(struct stat *st)
{
   tended struct descrip tmp, res;
   char mode[12], *user, *group;
   struct passwd *pw;
   struct group *gr;

   create_list(13, &res);
   MakeInt(st->st_dev, &tmp);
   list_put(&res, &tmp);
#if UNIX
   convert_from_ino_t(st->st_ino, &tmp);
   list_put(&res, &tmp);
#else
   list_put(&res, &zerodesc);
#endif
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
   list_put(&res, &tmp);

   MakeInt(st->st_nlink, &tmp);
   list_put(&res, &tmp);

#if UNIX
   pw = getpwuid(st->st_uid);
   if (!pw) {
      sprintf(mode, "%d", (int)st->st_uid);
      user = mode;
   } else
      user = pw->pw_name;
   cstr2string(user, &tmp);
   list_put(&res, &tmp);
   
   gr = getgrgid(st->st_gid);
   if (!gr) {
      sprintf(mode, "%d", (int)st->st_gid);
      group = mode;
   } else
      group = gr->gr_name;
   cstr2string(group, &tmp);
   list_put(&res, &tmp);
#else
   list_put(&res, &emptystr);
   list_put(&res, &emptystr);
#endif

   MakeInt(st->st_rdev, &tmp);
   list_put(&res, &tmp);
   convert_from_off_t(st->st_size, &tmp);
   list_put(&res, &tmp);
#if UNIX
   MakeInt(st->st_blksize, &tmp);
   list_put(&res, &tmp);
   convert_from_blkcnt_t(st->st_blocks, &tmp);
   list_put(&res, &tmp);
#else
   list_put(&res, &zerodesc);
   list_put(&res, &zerodesc);
#endif
   MakeInt(st->st_atime, &tmp);
   list_put(&res, &tmp);
   MakeInt(st->st_mtime, &tmp);
   list_put(&res, &tmp);
   MakeInt(st->st_ctime, &tmp);
   list_put(&res, &tmp);

   return res;
}

function io_Files_stat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      struct stat st;
      if (stat(s, &st) < 0) {
          errno2why();
          fail;
      }
      return stat2list(&st);
   }
end

function io_Files_lstat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      struct stat st;
      if (lstat(s, &st) < 0) {
          errno2why();
          fail;
      }
      return stat2list(&st);
   }
end

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

function util_Timezone_get_system_timezone()
   body {
      time_t t;
      struct tm *ct;
      tended struct descrip tmp, result;

      tzset();
      time(&t);
      ct = localtime(&t);

      create_list(2, &result);
      #if HAVE_STRUCT_TM_TM_GMTOFF
         MakeInt(ct->tm_gmtoff, &tmp);
         list_put(&result, &tmp);
         #if HAVE_TZNAME && HAVE_STRUCT_TM_TM_ISDST
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             list_put(&result, &tmp);
         }
         #endif
      #elif HAVE_TIMEZONE      
         #if MSWIN32
         MakeInt(timezone - _dstbias, &tmp);
         #else
         MakeInt(timezone, &tmp);
         #endif
         list_put(&result, &tmp);
         #if HAVE_TZNAME && HAVE_STRUCT_TM_TM_ISDST
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             list_put(&result, &tmp);
         }
         #endif
      #else
         list_put(&result, &zerodesc);
      #endif

      return result;
   }
end

/* RamStream implementation */

static struct sdescrip ptrf = {3, "ptr"};

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
       return nulldesc;
   }
end

function io_RamStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       tended struct descrip result;
       GetSelfRs();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }

       if (self_rs->pos >= self_rs->size) {
           GetSelfEofFlag();
           *self_eof_flag = onedesc;
           LitWhy("End of file");
           fail;
       }

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
       if (wiggle < 0) {
           irunerr(205, wiggle);
           errorfail;
       }
       MemProtect(p = malloc(sizeof(*p)));
       p->wiggle = wiggle;
       p->pos = p->size = StrLen(s);
       p->avail = p->size + p->wiggle;
       MemProtect(p->data = malloc(p->avail));
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
           MemProtect(self_rs->data = realloc(self_rs->data, self_rs->avail));
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
       MemProtect(self_rs->data = realloc(self_rs->data, self_rs->avail));
       if (self_rs->size < len)
           memset(&self_rs->data[self_rs->size], 0, len - self_rs->size);
       self_rs->size = len;
       return nulldesc;
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

function util_Connectable_is_methp_with_object(mp, o)
   if !is:object(o) then
       runerr(602, o)
    body {
       if (is:methp(mp) && MethpBlk(mp).object == &ObjectBlk(o))
           return nulldesc;
       else
           fail;
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

function lang_Constructor_get_package(c)
    body {
        struct b_constructor *constructor0;
        tended struct descrip result;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        if (constructor0->package_id == 0)
            fail;
        extract_package(constructor0->name, &result);
        return result;
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

function lang_Constructor_get_location_impl(c)
    body {
        struct b_constructor *constructor0;
        struct loc *p;
        tended struct descrip result;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        if (constructor0->program->Glocs == constructor0->program->Eglocs) {
            LitWhy("No global location data in icode");
            fail;
        }
        p = lookup_global_loc(constructor0->name, constructor0->program);
        if (!p)
            syserr("Constructor name not found in global table");
        loc_to_list(p, &result);
        return result;
    }
end

function lang_Constructor_get_field_names(c)
    body {
        struct b_constructor *constructor0;
        dptr *fn;
        word i;
        if (!(constructor0 = get_constructor_for(&c)))
            runerr(0);
        fn = constructor0->program->Fnames;
        for (i = 0; i < constructor0->n_fields; ++i)
            suspend *fn[constructor0->fnums[i]];
        fail;
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
        word i = cvpos(IntVal(*query), nf);
        if (i != CvtFail && i <= nf)
            return i - 1;
        else
            return -1;
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

function lang_Proc_get_n_locals(c)
   body {
        struct b_proc *proc0;
        struct p_proc *pp;
        if (!(proc0 = get_proc_for(&c)))
           runerr(0);
        if (!(pp = get_procedure(proc0)))
            fail;
        return C_integer pp->nparam + pp->ndynam + pp->nstatic;
     }
end

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

function lang_Proc_get_local_names(c)
   body {
        struct b_proc *proc0;
        struct p_proc *pp;
        word i, nf;
        if (!(proc0 = get_proc_for(&c)))
           runerr(0);
        if (!(pp = get_procedure(proc0)))
           fail;
        nf = pp->nparam + pp->ndynam + pp->nstatic;
        for (i = 0; i < nf; ++i)
            suspend *pp->lnames[i];
        fail;
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

function lang_Proc_get_package(c, flag)
   body {
        struct b_proc *proc0;
        tended struct descrip result;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        if (proc0->field && is:null(flag)) {
            if (proc0->field->defining_class->package_id == 0)
                fail;
            extract_package(proc0->field->defining_class->name, &result);
        } else {
            struct p_proc *pp;
            if (!(pp = get_procedure(proc0)))
                fail;
            if (pp->package_id == 0)
                fail;
            extract_package(pp->name, &result);
        }
        return result;
    }
end

function lang_Proc_get_program(c, flag)
    body {
        struct b_proc *proc0;
        struct progstate *prog;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
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

function lang_Proc_get_location_impl(c, flag)
   body {
        tended struct descrip result;
        struct b_proc *proc0;
        struct p_proc *pp;
        struct loc *p;
        if (!(proc0 = get_proc_for(&c)))
            runerr(0);
        /* The check for M_Defer here is to avoid (if flag is 1), looking up a non-deferred
         * method's name in the global name table.
         */
        if (proc0->field && (is:null(flag) ||
                            !(proc0->field->flags & M_Defer))) {
            struct progstate *prog = proc0->field->defining_class->program;
            if (prog->ClassFieldLocs == prog->EClassFieldLocs) {
                LitWhy("No field location data in icode");
                fail;
            }
            p = &prog->ClassFieldLocs[proc0->field - prog->ClassFields];
        } else if (!(pp = get_procedure(proc0))) {
            LitWhy("Proc not a procedure, has no location");
            fail;
        } else {
            if (pp->program->Glocs == pp->program->Eglocs) {
                LitWhy("No global location data in icode");
                fail;
            }
            p = lookup_global_loc(pp->name, pp->program);
            if (!p)
                syserr("Procedure name not found in global table");
        }
        loc_to_list(p, &result);
        return result;
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

function lang_Internal_compare(x, y)
   body {
      return C_integer anycmp(&x, &y);
   }
end

function lang_Internal_hash(x)
   body {
       struct descrip result;
       MakeInt(hash(&x) & MaxWord, &result);
       return result;
   }
end

function lang_Coexpression_traceback(ce, act_chain)
   body {
       tended struct b_coexpr *b;
       if (!(b = get_coexpr_for(&ce)))
          runerr(0);
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
