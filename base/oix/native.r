#include "../h/modflags.h"

/*
 * Helper method to get a class from a descriptor; if a class
 * descriptor then obviously the block is returned; if an object then
 * the object's class is returned.
 */
static struct b_class *get_class_for(dptr x)
{
    type_case *x of {
      class: {
            return &BlkLoc(*x)->class;
        }
      object: {
            return BlkLoc(*x)->object.class;
        }
     default: {
            return 0;
        }
    }
}

function{1} classof(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       return class(BlkLoc(o)->object.class);
    }
end

function{0,1} is(x,c)
   if !is:class(c) then
       runerr(603, c)
    body {
        struct b_class *class, *target = &BlkLoc(c)->class;
        int i;
        if (!(class = get_class_for(&x)))
            runerr(619, x);
        for (i = 0; i < class->n_implemented_classes; ++i) {
            if (class->implemented_classes[i] == target)
                return c;
        }
        fail;
    }
end

function{*} lang_Class_get_supers(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_supers; ++i)
            suspend class(class->supers[i]);
        fail;
    }
end

function{*} lang_Class_get_implemented_classes(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_implemented_classes; ++i)
            suspend class(class->implemented_classes[i]);
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

function{1} lang_Class_get_field_flags(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
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
            runerr(619, c);
        return C_integer class->flags;
     }
end

function{0,1} lang_Class_get_field_index(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
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
            runerr(619, c);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return class->fields[i]->name;
     }
end

function{0,1} lang_Class_get_field_defining_class(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
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
            runerr(619, c);
        return C_integer class->n_instance_fields + class->n_class_fields;
     }
end

function{1} lang_Class_get_n_class_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->n_class_fields;
     }
end

function{1} lang_Class_get_n_instance_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->n_instance_fields;
     }
end

function{*} lang_Class_get_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_instance_fields + class->n_class_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_instance_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_instance_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_class_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
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
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc != 0) 
           runerr(rc, obj);
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{0,1} lang_Class_getf(obj, field)
   body {
       struct descrip res;
       int rc;
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc != 0) 
           fail;
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{1} lang_Class_set_method(field, pr)
   body {
        dptr pp = (dptr)pfp - (pfp->pf_nargs + 1);
        struct b_proc *caller_proc, *new_proc;
        struct b_class *class;
        struct class_field *cf;
        int i;

        if (pp->dword != D_Proc) {
            showstack();
            syserr("couldn't find proc on stack");
        }
        if (!is:proc(pr))
            runerr(615, pr);

        caller_proc = &BlkLoc(*pp)->proc;
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

        BlkLoc(*cf->field_descriptor) = (union block *)new_proc;
        new_proc->field = cf;

        return pr;
   }
end

function{0,1} lang_Class_for_name(s, c)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;
       if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           prog = curpstate;
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
        Protect(obj = alcobject(class), runerr(0));
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
function{*} util_WindowsFileSystem_get_roots()
    body {
        DWORD n = GetLogicalDrives();
        char t[4], c = 'A';
	strcpy(t, "?:\\");
        while (n) {
	   if (n & 1) {
	      t[0] = c;
	      suspend cstr2string(t);
	   }
	   n /= 2;
	   ++c;
	}
        fail;
    }
end

function{0,1} util_WindowsFilePath_getdcwd(d)
   if !cnv:tmp_string(d) then
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
      result = cstr2string(p);
      free(p);
      return result;
   }
end

#endif
