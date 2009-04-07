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
            return &BlkLoc(*x)->class;
        
      object: 
            return BlkLoc(*x)->object.class;

      cast:
            return BlkLoc(*x)->cast.class;
                    
     default: 
            ReturnErrVal(620, *x, 0);
    }
}

static struct b_constructor *get_constructor_for(dptr x)
{
    type_case *x of {
      constructor: 
            return &BlkLoc(*x)->constructor;
        
      record: 
            return BlkLoc(*x)->record.constructor;
        
     default: 
            ReturnErrVal(625, *x, 0);
    }
}

static struct b_proc *get_proc_for(dptr x)
{
    type_case *x of {
      proc: 
            return &BlkLoc(*x)->proc;
        
      methp: 
            return BlkLoc(*x)->methp.proc;
        
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
             if (BlkLoc(*x)->coexpr.main_of)
                return BlkLoc(*x)->coexpr.main_of;
             else
                ReturnErrVal(632, *x, 0);
        }
        default:
             ReturnErrVal(118, *x, 0);
    }
}

function{1} classof(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       return class(BlkLoc(o)->object.class);
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


function{0,1} is(o, target)
   if !is:class(target) then
       runerr(603, target)
    body {
        if (is:object(o) && class_is(BlkLoc(o)->object.class, &BlkLoc(target)->class))
            return target;
        else
            fail;
    }
end

function{1} lang_Prog_get_parent(c)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&c)))
          runerr(0);

      if (prog->parent == NULL) 
          fail;

      return coexpr(prog->parent->K_main);
    }
end

function{0,1} lang_Prog_send_event(x,y,ce)
   body {
      struct progstate *dest;

      if (is:null(x)) {
	 x = curpstate->eventcode;
	 if (is:null(y)) y = curpstate->eventval;
      }
      if (!(dest = get_program_for(&ce)))
          runerr(0);
      dest->eventcode = x;
      dest->eventval = y;
      if (mt_activate(&(dest->eventcode),&result,
			 (struct b_coexpr *)BlkLoc(ce)) == A_Cofail) {
         fail;
         }
       return result;
      }
end

function{1} lang_Prog_get_eventmask(ce)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       return prog->eventmask;
   }
end

function{1} lang_Prog_set_eventmask(cs, ce)
   if !cnv:cset(cs) then 
      runerr(104,cs)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       if (BlkLoc(cs) != BlkLoc(prog->eventmask)) {
           prog->eventmask = cs;
           assign_event_functions(prog, cs);
       }
       return cs;
   }
end

function{1} lang_Prog_get_valuemask(ce)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       return prog->valuemask;
   }
end

function{1} lang_Prog_set_valuemask(vmask, ce)
   if !is:table(vmask) then
      runerr(124,vmask)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       prog->valuemask = vmask;
       return vmask;
   }
end


function{1} lang_Prog_set_opmask(cs, ce)
   if !cnv:cset(cs) then 
      runerr(104,cs)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       prog->opcodemask = cs;
       return cs;
   }
end

function{1} lang_Prog_get_opmask(ce)
   body {
       struct progstate *prog;
       if (!(prog = get_program_for(&ce)))
          runerr(0);
       return prog->opcodemask;
   }
end

function{0,1} lang_Prog_get_variable(s,c)
   if !cnv:string(s) then
      runerr(103, s)

   body {
       int rv;
       struct progstate *prog;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       rv = getvar(&s, &result, prog);
       if (rv == Failed)
           fail;

       if (is:coexpr(c) && ((rv == LocalName) || (rv == StaticName)))
           Deref(result);

       return result;
   }
end


function{*} lang_Prog_get_keyword(s,c)
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
                  word *i;
                  struct ipc_fname *t;

                  /* If the prog's &current isn't in this program, we can't look up
                   * the file in this program's table */
                  if (p->K_current->program != p)
                      fail;
                  /* If the prog's &current is the currently executing coexpression, take
                   * the ipc, otherwise the stored ipc in the coexpression block
                   */
                  if (p->K_current == k_current)
                      i = ipc;
                  else
                      i = p->K_current->es_ipc;
                  t = find_ipc_fname(i, p);
                  if (!t)
                      fail;
                  return t->fname;
              }
              if (strncmp(t,"line",4) == 0) {
                  word *i;
                  struct ipc_line *t;
                  if (p->K_current->program != p)
                      fail;
                  if (p->K_current == k_current)
                      i = ipc;
                  else
                      i = p->K_current->es_ipc;
                  t = find_ipc_line(i, p);
                  if (!t)
                      fail;
                  return C_integer t->line;
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
                  return kywdint(&(p->Kywd_trc));
              }
              if (strncmp(t,"error",5) == 0) {
                  return kywdint(&(p->Kywd_err));
              }
              break;
          }
          case 7 : {
              if (strncmp(t,"random",6) == 0) {
                  return kywdint(&(p->Kywd_ran));
              }
              if (strncmp(t,"source",6) == 0) {
                  struct b_coexpr *a = p->K_current->es_activator;
                  if (!a)  /* It will be 0 for a just-loaded program */
                     fail;
                  return coexpr(a);
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
              if (strncmp(t,"progname",8) == 0) {
                  return kywdstr(&(p->Kywd_prog));
              }
              break;
          }
          case 10: {
              if (strncmp(t,"errortext",9) == 0) {
                  return p->K_errortext;
              }
              if (strncmp(t,"eventcode",9) == 0) {
                  return kywdevent(&(p->eventcode));
              }
              break;
          }

          case 11 : {
              if (strncmp(t,"errorvalue",10) == 0) {
                  return p->K_errorvalue;
              }
              if (strncmp(t,"eventvalue",10) == 0) {
                  return kywdevent(&(p->eventval));
              }
              break;
          }
          case 12 : {
              if (strncmp(t,"errornumber",11) == 0) {
                  return C_integer p->K_errornumber;
              }
              if (strncmp(t,"eventsource",11) == 0) {
                  return kywdevent(&(p->eventsource));
              }
              break;
          }
      }

      runerr(205, s);
   }
end


function{0,1} lang_Prog_get_global(s, c)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       p = lookup_global(&s, prog);
       if (p) {
           result.dword = D_Var;
           VarLoc(result) = p;
           return result;
       } else
           fail;
   }
end

function{0,1} lang_Prog_get_globals(c)
   body {
       struct progstate *prog;
       dptr dp;
       if (!(prog = get_program_for(&c)))
          runerr(0);
       for (dp = prog->Globals; dp != prog->Eglobals; dp++) {
          result.dword = D_Var;
          VarLoc(result) = dp;
          suspend result;
       }

      fail;
   }
end

function{0,1} lang_Prog_get_global_names(c)
   body {
       struct progstate *prog;
       dptr dp;
       if (!(prog = get_program_for(&c)))
          runerr(0);
      for (dp = prog->Gnames; dp != prog->Egnames; dp++)
         suspend *dp;
      fail;
   }
end

function{*} lang_Prog_get_function_names()
   abstract {
      return string
      }
   body {
      register int i;

      for (i = 0; i<pnsize; i++) {
	 suspend string(strlen(pntab[i].pstrep), pntab[i].pstrep);
         }
      fail;
      }
end


function{0,1} lang_Prog_get_global_location(s, c)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       struct loc *p;
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

       if (is:null(p->fname)) {
           LitWhy("Symbol is builtin, has no location");
           fail;
       }

       suspend p->fname;
       return C_integer p->line;
   }
end

function{1} lang_Prog_get_coexpression_program(c)
   if !is:coexpr(c) then
      runerr(118,c)
   body {
        return coexpr(BlkLoc(c)->coexpr.program->K_main);
   }
end

function{0,1} lang_Prog_get_runtime_millis(c)
   body {
       struct progstate *prog;
       struct timeval tp;
       struct descrip ls, lm;
       tended struct descrip lt1, lt2;

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
          if (bigmul(&ls, &thousanddesc, &lt1) == Error ||
              bigdiv(&lm, &thousanddesc ,&lt2) == Error ||
              bigadd(&lt1, &lt2, &result) == Error)
              runerr(0);
      }
      return result;
   }
end

function{0,1} lang_Prog_get_startup_micros(c)
   body {
       struct progstate *prog;
       struct descrip ls, lm;
       tended struct descrip lt1;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       MakeInt(prog->start_time.tv_sec, &ls);
       MakeInt(prog->start_time.tv_usec, &lm);
       if (bigmul(&ls, &milliondesc, &lt1) == Error ||
           bigadd(&lt1, &lm, &result) == Error)
           runerr(0);
       return result;
   }
end

function{4} lang_Prog_get_collections(c)
   body {
       struct progstate *prog;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       suspend C_integer prog->colltot;
       suspend C_integer prog->collstat;
       suspend C_integer prog->collstr;
       return C_integer prog->collblk;
   }
end

function{4} lang_Prog_get_allocations(c)
   body {
       struct progstate *prog;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       suspend C_integer prog->stattotal + prog->stringtotal + prog->blocktotal;
       suspend C_integer prog->stattotal;
       suspend C_integer prog->stringtotal;
       return C_integer prog->blocktotal;
   }
end

function{6} lang_Prog_get_regions(c)
   body {
       struct progstate *prog;
       word sum1, sum2;
       struct region *rp;

       if (!(prog = get_program_for(&c)))
          runerr(0);

       suspend C_integer prog->statcurr;
       suspend C_integer prog->statcurr;

       sum1 = sum2 = 0;
       for (rp = prog->stringregion; rp; rp = rp->next) {
           sum1 += DiffPtrs(rp->free,rp->base);
           sum2 += DiffPtrs(rp->end,rp->base);
       }
       for (rp = prog->stringregion->prev; rp; rp = rp->prev) {
           sum1 += DiffPtrs(rp->free,rp->base);
           sum2 += DiffPtrs(rp->end,rp->base);
       }
       suspend C_integer sum1;
       suspend C_integer sum2;

       sum1 = sum2 = 0;
       for (rp = prog->blockregion; rp; rp = rp->next) {
           sum1 += DiffPtrs(rp->free,rp->base);
           sum2 += DiffPtrs(rp->end,rp->base);
       }
       for (rp = prog->blockregion->prev; rp; rp = rp->prev) {
           sum1 += DiffPtrs(rp->free,rp->base);
           sum2 += DiffPtrs(rp->end,rp->base);
       }
       suspend C_integer sum1;
       return C_integer sum2;
   }
end

function{2} lang_Prog_get_stack(c)
   if !is:coexpr(c) then
      runerr(118,c)
   body {
       word *top, *bottom, *isp;
       struct b_coexpr *ce = (struct b_coexpr *)BlkLoc(c);

       if (ce == rootpstate.K_main) {
           top = stack + Wsizeof(struct b_coexpr);
           bottom = stackend;
           if (ce == k_current)
               isp = sp;
           else
               isp = ce->es_sp;
       } else if (ce->main_of) {
           /* See init.r, Prog.load */
           top = (word *)ce + Wsizeof(struct b_coexpr) + Wsizeof(struct progstate) + 
               ce->main_of->hsize/WordSize;
           if (ce->main_of->hsize % WordSize) 
               top++;
           if (ce == k_current) {
               bottom = (word *)&top;
               isp = sp;
           } else {
               bottom = (word *)(ce->cstate[0]);
               isp = ce->es_sp;
           }
       } else {
           top = (word *)(ce + 1);
           if (ce == k_current) {
               bottom = (word *)&top;
               isp = sp;
           } else {
               bottom = (word *)(ce->cstate[0]);
               isp = ce->es_sp;
           }
       }
       suspend C_integer DiffPtrsBytes(bottom, top);
       return C_integer DiffPtrsBytes(isp + 1, top);
   }
end

function{1} lang_Class_get_name(c)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return class->name;
    }
end

function{1} lang_Class_get_class(c)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return class(class);
    }
end

function{0,1} lang_Class_get_package(c)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        if (class->package_id == 0)
            fail;
        extract_package(&class->name, &result);
        return result;
    }
end

function{1} lang_Class_get_program(c)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return coexpr(class->program->K_main);
    }
end

function{0,1} lang_Class_get_location(c)
    body {
        struct b_class *class;
        struct loc *p;
        if (!(class = get_class_for(&c)))
            runerr(0);
        if (class->program->Glocs == class->program->Eglocs) {
            LitWhy("No global location data in icode");
            fail;
        }
        p = lookup_global_loc(&class->name, class->program);
        if (!p)
            syserr("Class name not found in global table");
        suspend p->fname;
        return C_integer p->line;
    }
end

function{*} lang_Class_get_supers(c)
    body {
        struct b_class *class;
        word i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class->n_supers; ++i)
            suspend class(class->supers[i]);
        fail;
    }
end

function{*} lang_Class_get_implemented_classes(c)
    body {
        struct b_class *class;
        word i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class->n_implemented_classes; ++i)
            suspend class(class->implemented_classes[i]);
        fail;
    }
end

function{0,1} lang_Class_implements(c, target)
   if !is:class(target) then
       runerr(603, target)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        if (class_is(class, &BlkLoc(target)->class))
            return target;
        else
            fail;
    }
end

function{1} lang_Class_get_methp_object(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
       return object(BlkLoc(mp)->methp.object);
    }
end

function{1} lang_Class_get_methp_proc(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
        return proc(BlkLoc(mp)->methp.proc);
    }
end

function{1} lang_Class_get_cast_object(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return object(BlkLoc(c)->cast.object);
    }
end

function{1} lang_Class_get_cast_class(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return class(BlkLoc(c)->cast.class);
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

function{1} lang_Class_get_field_flags(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return C_integer class->fields[i]->flags;
     }
end

function{1} lang_Class_get_class_flags(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return C_integer class->flags;
     }
end

function{0,1} lang_Class_get_field_index(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function{0,1} lang_Class_get_field_name(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return class->fields[i]->name;
     }
end

function{0,1} lang_Class_get_field_location(c, field)
   body {
        struct b_class *class;
        struct loc *loc;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        if (class->program->ClassFieldLocs == class->program->EClassFieldLocs) {
            LitWhy("No field location data in icode");
            fail;
        }
        i = lookup_class_field(class, &field, 0);
        if (i < 0) {
            LitWhy("Unknown field");
            fail;
        }
        loc = &class->program->ClassFieldLocs[class->fields[i] - class->program->ClassFields];
        suspend loc->fname;
        return C_integer loc->line;
     }
end

function{0,1} lang_Class_get_field_defining_class(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return class(class->fields[i]->defining_class);
     }
end

function{1} lang_Class_get_n_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return C_integer class->n_instance_fields + class->n_class_fields;
     }
end

function{1} lang_Class_get_n_class_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return C_integer class->n_class_fields;
     }
end

function{1} lang_Class_get_n_instance_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(0);
        return C_integer class->n_instance_fields;
     }
end

function{*} lang_Class_get_field_names(c)
    body {
        struct b_class *class;
        word i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class->n_instance_fields + class->n_class_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_instance_field_names(c)
    body {
        struct b_class *class;
        word i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        for (i = 0; i < class->n_instance_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_class_field_names(c)
    body {
        struct b_class *class;
        word i;
        if (!(class = get_class_for(&c)))
            runerr(0);
        for (i = class->n_instance_fields; 
             i < class->n_instance_fields + class->n_class_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

#include "../h/opdefs.h"

function{1} lang_Class_get(obj, field)
   body {
       struct descrip res;
       int rc;
       CheckField(field);
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc == Error) 
           runerr(0, obj);
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{0,1} lang_Class_getf(obj, field, quiet)
   body {
       struct descrip res;
       int rc;
       CheckField(field);
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc == Error) {
           if (is:null(quiet))
               whyf("%s (error %d)", lookup_err_msg(t_errornumber), t_errornumber);
           fail;
       }
       res = *((dptr)(sp + 1));
       return res;
   }
end

static struct b_proc *clone_b_proc(struct b_proc *bp)
{
    struct b_proc *new;
    MemProtect(new = malloc(sizeof(struct b_proc)));
    memcpy(new, bp, sizeof(struct b_proc));
    return new;
}

function{1} lang_Class_set_method(field, pr)
   body {
        struct b_proc *caller_proc, *new_proc;
        struct b_class *class;
        struct class_field *cf;
        int i;

        CheckField(field);
        if (!is:proc(pr))
            runerr(615, pr);

        caller_proc = CallerProc;
        if (!caller_proc->field)
            runerr(616);
        class = caller_proc->field->defining_class;

        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            runerr(207, field);
        cf = class->fields[i];

        if (cf->defining_class != class)
            runerr(616);

        if (!(cf->flags & M_Method))
            runerr(617, field);

        new_proc = &BlkLoc(pr)->proc;
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

static struct b_proc *try_load(void *handle, struct b_class *class,  struct class_field *cf)
{
    word i;
    char *fq, *p, *t;
    struct b_proc *blk;

    MemProtect(fq = malloc(StrLen(class->name) + StrLen(cf->name) + 3));
    p = fq;
    *p++ = 'B';
    t = StrLoc(class->name);
    for (i = 0; i < StrLen(class->name); ++i)
        *p++ = (t[i] == '.') ? '_' : t[i];
    *p++ = '_';
    strncpy(p, StrLoc(cf->name), StrLen(cf->name));
    p[StrLen(cf->name)] = 0;

    blk = (struct b_proc *)dlsym(handle, fq);
    if (!blk) {
        free(fq);
        return 0;
    }

    /* Sanity check. */
    if (blk->title != T_Proc) {
        fprintf(stderr, "\nlang.Class.load_library() - symbol %s not a procedure block\n", fq);
        fatalerr(218, NULL);
    }

    free(fq);

    return blk;
}

function{1} lang_Class_load_library(lib)
   if !cnv:C_string(lib) then
      runerr(103, lib)
   body {
        struct b_proc *caller_proc;
        struct b_class *class;
        word i;
        void *handle;

        caller_proc = CallerProc;
        if (!caller_proc->field)
            runerr(616);
        class = caller_proc->field->defining_class;

        handle = dlopen(lib, RTLD_LAZY);
        if (!handle) {
            why(dlerror());
            fail;
        }

        for (i = 0; i < class->n_instance_fields + class->n_class_fields; ++i) {
            struct class_field *cf = class->fields[i];
            if ((cf->defining_class == class) &&
                (cf->flags & M_Method) &&
                BlkLoc(*cf->field_descriptor) == (union block *)&Bdeferred_method_stub) {
                struct b_proc *bp = try_load(handle, class, cf);
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

function{0,1} lang_Class_for_name(s, c)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;

       if (is:null(c))
           prog = curpstate;
       else if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           runerr(118, c);

       p = lookup_global(&s, prog);
       if (p && is:class(*p))
           return *p;
       else
           fail;
   }
end

function{1} lang_Class_create_raw(c)
   if !is:class(c) then
       runerr(603, c)
    body {
        struct b_object *obj;
        struct b_class *class = &BlkLoc(c)->class;
        ensure_initialized(class);
        MemProtect(obj = alcobject(class));
        obj->init_state = Initializing;
        return object(obj);
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
        struct b_class *class = &BlkLoc(c)->class;
        ensure_initialized(class);
        return c;
   }
end

function{1} parser_UReader_raw_convert(s)
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
function{*} io_WindowsFileSystem_get_roots()
    body {
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

function{0,1} io_WindowsFilePath_getdcwd(d)
   if !cnv:string(d) then
      runerr(103, d)
   body {
      char *p;
      int dir;
      if (StrLen(d) != 1)
	 fail;
      dir = toupper(*StrLoc(d)) - 'A' + 1;
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

function{0,1} io_FileStream_open_impl(path, flags, mode)
   if !cnv:C_string(path) then
      runerr(103, path)

   if !cnv:C_integer(flags) then
      runerr(101, flags)

   if !def:C_integer(mode, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH) then
      runerr(101, mode)

   body {
       int fd;

       fd = open(path, flags, mode);
       if (fd < 0) {
           errno2why();
           fail;
       }

       return C_integer fd;
   }
end

function{0,1} io_FileStream_in(self, i)
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

function{0,1} io_FileStream_out(self, s)
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

function{0,1} io_FileStream_close(self)
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

function{0,1} io_FileStream_truncate(self, len)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
       GetSelfFd();
       if (lseek(self_fd, len, SEEK_SET) < 0) {
           errno2why();
           fail;
       }

       if (ftruncate(self_fd, len) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_FileStream_stat_impl(self)
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

function{0,1} io_FileStream_chdir(self)
   body {
       GetSelfFd();
       if (fchdir(self_fd) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_FileStream_dup2_impl(self, n)
   if !cnv:C_integer(n) then
      runerr(101, n)
   body {
       GetSelfFd();
       if (dup2(self_fd, n) < 0) {
           errno2why();
           fail;
       }
       return C_integer n;
   }
end

function{0,1} io_FileStream_seek(self, offset)
   if !cnv:C_integer(offset) then
      runerr(101, offset)
   body {
       int whence, rc;
       GetSelfFd();
       if (offset > 0) {
           --offset;
           whence = SEEK_SET;
       } else
           whence = SEEK_END;
       if ((rc = lseek(self_fd, offset, whence)) < 0) {
           errno2why();
           fail;
       }
       return C_integer(rc + 1);
   }
end

function{0,1} io_FileStream_tell(self)
   body {
       int rc;
       GetSelfFd();
       if ((rc = lseek(self_fd, 0, SEEK_CUR)) < 0) {
           errno2why();
           fail;
       }
       return C_integer(rc + 1);
   }
end

function{0,1} io_FileStream_pipe_impl()
   body {
       int fds[2];
       struct descrip t;

       if (pipe(fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      c_put(&result, &t);

      MakeInt(fds[1], &t);
      c_put(&result, &t);

      return result;
   }
end

function{0,1} io_SocketStream_in(self, i)
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

function{0,1} io_SocketStream_socket_impl(domain, typ)
   if !def:C_integer(domain, PF_INET) then
      runerr(101, domain)

   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       SOCKET sockfd;
       sockfd = socket(domain, typ, 0);
       if (sockfd < 0) {
           errno2why();
           fail;
       }
       return C_integer sockfd;
   }
end

function{0,1} io_SocketStream_out(self, s)
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

function{0,1} io_SocketStream_close(self)
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

function{0,1} io_SocketStream_socketpair_impl(typ)
   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       int fds[2];
       struct descrip t;

       if (socketpair(AF_UNIX, typ, 0, fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      c_put(&result, &t);

      MakeInt(fds[1], &t);
      c_put(&result, &t);

      return result;
   }
end

struct sockaddr *parse_sockaddr(char *s, int *len)
{
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

function{0,1} io_SocketStream_connect(self, addr)
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

function{0,1} io_SocketStream_bind(self, addr)
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

function{0,1} io_SocketStream_listen(self, backlog)
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

function{0,1} io_SocketStream_accept_impl(self)
   body {
       SOCKET sockfd;
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
        create_list(BlkLoc(l)->list.size, &tmpl);
        while (c_get(&BlkLoc(l)->list, &e)) {
            FdStaticParam(e, fd);
            c_put(&tmpl, &e);
            FD_SET(fd, &s);
        }
    }
}
#enddef

#begdef fd_set2list(l, tmpl, s)
{
    tended struct descrip e;

    if (!is:null(l)) {
        while (c_get(&BlkLoc(tmpl)->list, &e)) {
            FdStaticParam(e, fd);
            if (FD_ISSET(fd, &s)) {
                c_put(&l, &e);
                ++count;
            }
        }
    }
}
#enddef

function{0,1} io_DescStream_select(rl, wl, el, timeout)
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
           C_integer t;
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

function{0,1} io_DescStream_poll(a[n])
   body {
#ifdef HAVE_POLL
       static struct pollfd *ufds = 0;
       unsigned int nfds;
       word timeout;
       int i, rc;

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
           c_put(&result, &tmp);
       }

       return result;
#else
       runerr(121);
#endif  /* HAVE_POLL */
   }
end

function{0,1} io_DescStream_flag(self, on, off)
    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
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
    }
end

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

function{0,1} io_DirStream_open_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       DIR *dd = opendir(path);
       if (!dd) {
           errno2why();
           fail;
       }
       return C_integer((long int)dd);
   }
end

function{0,1} io_DirStream_read_impl(self)
   body {
       struct dirent *de;
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

function{0,1} io_DirStream_close(self)
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


function{0,1} io_Files_rename(s1,s2)
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

function{0,1} io_Files_hardlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if (link(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

function{0,1} io_Files_symlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if (symlink(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

function{0,1} io_Files_readlink(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
#if MSWIN32
       runerr(121);
#else					/* MSWIN32 */
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
#endif					/* MSWIN32 */
      }
end

function{0,1} io_Files_mkdir(s, mode)
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

function{0,1} io_Files_remove(s)
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

function{0,1} io_Files_truncate(s, len)
   if !cnv:C_string(s) then
      runerr(103,s)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
      if (truncate(s, len) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
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
   c_put(&res, &tmp);
   MakeInt(st->st_ino, &tmp);
   c_put(&res, &tmp);

   strcpy(mode, "----------");
#if MSWIN32
   if (st->st_mode & _S_IFREG) mode[0] = '-';
   else if (st->st_mode & _S_IFDIR) mode[0] = 'd';
   else if (st->st_mode & _S_IFCHR) mode[0] = 'c';
   else if (st->st_mode & _S_IFMT) mode[0] = 'm';

   if (st->st_mode & S_IREAD) mode[1] = mode[4] = mode[7] = 'r';
   if (st->st_mode & S_IWRITE) mode[2] = mode[5] = mode[8] = 'w';
   if (st->st_mode & S_IEXEC) mode[3] = mode[6] = mode[9] = 'x';
#else					/* MSWIN32 */
   if (S_ISLNK(st->st_mode)) mode[0] = 'l';
   else if (S_ISREG(st->st_mode)) mode[0] = '-';
   else if (S_ISDIR(st->st_mode)) mode[0] = 'd';
   else if (S_ISCHR(st->st_mode)) mode[0] = 'c';
   else if (S_ISBLK(st->st_mode)) mode[0] = 'b';
   else if (S_ISFIFO(st->st_mode)) mode[0] = '|';
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
#endif					/* MSWIN32 */
   cstr2string(mode, &tmp);
   c_put(&res, &tmp);

   MakeInt(st->st_nlink, &tmp);
   c_put(&res, &tmp);

#if MSWIN32
   c_put(&res, emptystr);
   c_put(&res, emptystr);
#else					/* MSWIN32 */
   pw = getpwuid(st->st_uid);
   if (!pw) {
      sprintf(mode, "%d", st->st_uid);
      user = mode;
   } else
      user = pw->pw_name;
   cstr2string(user, &tmp);
   c_put(&res, &tmp);
   
   gr = getgrgid(st->st_gid);
   if (!gr) {
      sprintf(mode, "%d", st->st_gid);
      group = mode;
   } else
      group = gr->gr_name;
   cstr2string(group, &tmp);
   c_put(&res, &tmp);
#endif					/* MSWIN32 */

   MakeInt(st->st_rdev, &tmp);
   c_put(&res, &tmp);
   MakeInt(st->st_size, &tmp);
   c_put(&res, &tmp);
#if MSWIN32
   c_put(&res, zerodesc);
   c_put(&res, zerodesc);
#else
   MakeInt(st->st_blksize, &tmp);
   c_put(&res, &tmp);
   MakeInt(st->st_blocks, &tmp);
   c_put(&res, &tmp);
#endif
   MakeInt(st->st_atime, &tmp);
   c_put(&res, &tmp);
   MakeInt(st->st_mtime, &tmp);
   c_put(&res, &tmp);
   MakeInt(st->st_ctime, &tmp);
   c_put(&res, &tmp);

   return res;
}

function{0,1} io_Files_stat_impl(s)
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

function{0,1} io_Files_lstat_impl(s)
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

function{0,1} io_Files_access(s, mode)
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

function{1} util_Timezone_get_system_timezone()
   body {
      time_t t;
      struct tm *ct;
      tended struct descrip tmp;

      tzset();
      time(&t);
      ct = localtime(&t);

      create_list(2, &result);
      #if HAVE_STRUCT_TM_TM_GMTOFF
         MakeInt(ct->tm_gmtoff, &tmp);
         c_put(&result, &tmp);
         #if HAVE_TZNAME
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             c_put(&result, &tmp);
         }
         #endif
      #elif HAVE_TIMEZONE      
         MakeInt(timezone, &tmp);
         c_put(&result, &tmp);
         #if HAVE_TZNAME
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             c_put(&result, &tmp);
         }
         #endif
      #else
         c_put(&result, &zerodesc);
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

function{1} io_RamStream_close(self)
   body {
       GetSelfRs();
       free(self_rs->data);
       free(self_rs);
       *self_rs_dptr = zerodesc;
       return nulldesc;
   }
end

function{0,1} io_RamStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
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

function{1} io_RamStream_new_impl(s, wiggle)
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
       return C_integer((long int)p);
   }
end

function{1} io_RamStream_out(self, s)
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

function{0,1} io_RamStream_seek(self, offset)
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

function{1} io_RamStream_tell(self)
   body {
       GetSelfRs();
       return C_integer(self_rs->pos + 1);
   }
end

function{1} io_RamStream_truncate(self, len)
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

function{1} io_RamStream_str(self)
   body {
       GetSelfRs();
       bytes2string(self_rs->data, self_rs->size, &result);
       return result;
   }
end

function{1} util_Connectable_is_methp_with_object(mp, o)
   if !is:object(o) then
       runerr(602, o)
    body {
       if (is:methp(mp) && BlkLoc(mp)->methp.object == &BlkLoc(o)->object)
           return nulldesc;
       else
           fail;
    }
end

function{1} lang_Constructor_get_name(c)
    body {
        struct b_constructor *constructor;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        return constructor->name;
    }
end

function{1} lang_Constructor_get_constructor(c)
    body {
        struct b_constructor *constructor;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        return constructor(constructor);
    }
end

function{0,1} lang_Constructor_get_package(c)
    body {
        struct b_constructor *constructor;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        if (constructor->package_id == 0)
            fail;
        extract_package(&constructor->name, &result);
        return result;
    }
end

function{1} lang_Constructor_get_program(c)
    body {
        struct b_constructor *constructor;
        struct progstate *prog;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        prog = constructor->program;
        if (!prog)
            fail;
        return coexpr(prog->K_main);
    }
end

function{0,1} lang_Constructor_get_location(c)
    body {
        struct b_constructor *constructor;
        struct loc *p;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        if (!constructor->program) {
            LitWhy("Dynamically created constructor has no location");
            fail;
        }
        if (constructor->program->Glocs == constructor->program->Eglocs) {
            LitWhy("No global location data in icode");
            fail;
        }
        p = lookup_global_loc(&constructor->name, constructor->program);
        if (!p)
            syserr("Constructor name not found in global table");
        suspend p->fname;
        return C_integer p->line;
    }
end

function{*} lang_Constructor_get_field_names(c)
    body {
        struct b_constructor *constructor;
        word i;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        for (i = 0; i < constructor->n_fields; ++i)
            suspend constructor->field_names[i];
        fail;
    }
end

function{1} lang_Constructor_get_n_fields(c)
   body {
        struct b_constructor *constructor;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        return C_integer constructor->n_fields;
     }
end

function{0,1} lang_Constructor_get_field_index(c, field)
   body {
        struct b_constructor *constructor;
        int i;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_record_field(constructor, &field, 0);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function{0,1} lang_Constructor_get_field_location(c, field)
   body {
        struct b_constructor *constructor;
        int i;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        if (!constructor->program) {
            LitWhy("Dynamically created constructor has no location");
            fail;
        }
        if (!constructor->field_locs) {
            LitWhy("No constructor field location data in icode");
            fail;
        }
        i = lookup_record_field(constructor, &field, 0);
        if (i < 0) {
            LitWhy("Unknown field");
            fail;
        }
        suspend constructor->field_locs[i].fname;
        return C_integer constructor->field_locs[i].line;
     }
end

function{0,1} lang_Constructor_get_field_name(c, field)
   body {
        struct b_constructor *constructor;
        int i;
        if (!(constructor = get_constructor_for(&c)))
            runerr(0);
        CheckField(field);
        i = lookup_record_field(constructor, &field, 0);
        if (i < 0)
            fail;
        return constructor->field_names[i];
     }
end

int lookup_proc_local(struct b_proc *proc, dptr query)
{
    word nf;

    if (!proc->program)
        return -1;

    nf = abs(proc->nparam) + proc->ndynam + proc->nstatic;

    if (is:string(*query)) {
        word i;
        for (i = 0; i < nf; ++i) {
            if (eq(&proc->lnames[i], query))
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

function{1} lang_Proc_get_n_locals(c)
   body {
        struct b_proc *proc;
        if (!(proc = get_proc_for(&c)))
           runerr(0);
       if (!proc->program)
            fail;
        return C_integer abs(proc->nparam) + proc->ndynam + proc->nstatic;
     }
end

function{1} lang_Proc_get_n_arguments(c)
   body {
      struct b_proc *proc;
      if (!(proc = get_proc_for(&c)))
          runerr(0);
      return C_integer proc->nparam;
   }
end

function{1} lang_Proc_get_n_dynamics(c)
   body {
       struct b_proc *proc;
       if (!(proc = get_proc_for(&c)))
           runerr(0);
       if (!proc->program)
            fail;
       return C_integer proc->ndynam;
     }
end

function{1} lang_Proc_get_n_statics(c)
   body {
       struct b_proc *proc;
       if (!(proc = get_proc_for(&c)))
          runerr(0);
       if (!proc->program)
            fail;
        return C_integer proc->nstatic;
     }
end

function{*} lang_Proc_get_local_names(c)
   body {
        struct b_proc *proc;
        word i, nf;
        if (!(proc = get_proc_for(&c)))
           runerr(0);
        if (!proc->program)
            fail;
        nf = abs(proc->nparam) + proc->ndynam + proc->nstatic;
        for (i = 0; i < nf; ++i)
            suspend proc->lnames[i];
        fail;
    }
end

function{0,1} lang_Proc_get_local_index(c, id)
   body {
        struct b_proc *proc;
        int i;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        i = lookup_proc_local(proc, &id);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function{0,1} lang_Proc_get_local_location(c, id)
   body {
        int i;
        struct b_proc *proc;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        if (!proc->llocs) {
            LitWhy("No local location data in icode");
            fail;
        }
        i = lookup_proc_local(proc, &id);
        if (i < 0) {
            LitWhy("Unknown local");
            fail;
        }
        suspend proc->llocs[i].fname;
        return C_integer proc->llocs[i].line;
     }
end

function{0,1} lang_Proc_get_local_name(c, id)
   body {
        struct b_proc *proc;
        int i;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        i = lookup_proc_local(proc, &id);
        if (i < 0)
            fail;
        return proc->lnames[i];
     }
end

function{0,1} lang_Proc_get_local_type(c, id)
   body {
        struct b_proc *proc;
        int i;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        CheckField(id);
        i = lookup_proc_local(proc, &id);
        if (i < 0)
            fail;
        if (i < abs(proc->nparam))
            return C_integer 1;
        if (i < abs(proc->nparam) + proc->ndynam)
            return C_integer 2;
        return C_integer 3;
     }
end

function{1} lang_Proc_get_name(c, flag)
   body {
        struct b_proc *proc;
        if (!(proc = get_proc_for(&c)))
           runerr(0);
        if (proc->field && is:null(flag)) {
            int len = StrLen(proc->field->defining_class->name) + StrLen(proc->field->name) + 1;
            MemProtect (StrLoc(result) = reserve(Strings, len));
            StrLen(result) = len;
            alcstr(StrLoc(proc->field->defining_class->name),StrLen(proc->field->defining_class->name));
            alcstr(".", 1);
            alcstr(StrLoc(proc->field->name),StrLen(proc->field->name));
            return result;
        } else
            return proc->pname;
     }
end

function{0,1} lang_Proc_get_package(c, flag)
   body {
        struct b_proc *proc;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        if (proc->field && is:null(flag)) {
            if (proc->field->defining_class->package_id == 0)
                fail;
            extract_package(&proc->field->defining_class->name, &result);
        } else {
            if (proc->package_id == 0)
                fail;
            extract_package(&proc->pname, &result);
        }
        return result;
    }
end

function{1} lang_Proc_get_program(c, flag)
    body {
        struct b_proc *proc;
        struct progstate *prog;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        if (proc->field && is:null(flag))
            prog = proc->field->defining_class->program;
        else
            prog = proc->program;
        if (!prog)
            fail;
        return coexpr(prog->K_main);
    }
end

function{0,1} lang_Proc_get_location(c, flag)
   body {
        struct b_proc *proc;
        struct loc *p;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        /* The check for M_Defer here is to avoid (if flag is 1), looking up a non-deferred
         * method's name in the global name table.
         */
        if (proc->field && (is:null(flag) ||
                            !(proc->field->flags & M_Defer))) {
            if (proc->program->ClassFieldLocs == proc->program->EClassFieldLocs) {
                LitWhy("No field location data in icode");
                fail;
            }
            p = &proc->program->ClassFieldLocs[proc->field - proc->program->ClassFields];
        } else if (!proc->program) {
            LitWhy("Proc is builtin, has no location");
            fail;
        } else {
            if (proc->program->Glocs == proc->program->Eglocs) {
                LitWhy("No global location data in icode");
                fail;
            }
            p = lookup_global_loc(&proc->pname, proc->program);
            if (!p)
                syserr("Procedure name not found in global table");
        }
        suspend p->fname;
        return C_integer p->line;
     }
end

function{0,1} lang_Proc_get_defining_class(c)
   body {
        struct b_proc *proc;
        if (!(proc = get_proc_for(&c)))
            runerr(0);
        if (proc->field)
            return class(proc->field->defining_class);
        else
            fail;
     }
end

