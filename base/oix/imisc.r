struct p_frame *get_current_user_frame()
{
    struct p_frame *pf = curr_pf;
    while (pf && !pf->proc->program)
        pf = pf->caller;
    return pf;
}

struct p_frame *get_current_user_frame_of(struct b_coexpr *ce)
{
    struct p_frame *pf = ce->curr_pf;
    while (pf && !pf->proc->program)
        pf = pf->caller;
    return pf;
}

struct p_proc *get_current_user_proc()
{
    return get_current_user_frame()->proc;
}

struct progstate *get_current_program_of(struct b_coexpr *ce)
{
    struct p_frame *pf = ce->curr_pf;
    struct progstate *p = pf->proc->program;
    if (!p) 
        p = pf->creator;
    return p;
}

/*
 * Check whether the calling procedure (deduced from the stack) has
 * access to the given field of the given instance class (which is
 * null for a static access).  Returns Succeeded if it does have
 * access, Readable if it doesn't but the M_Readable flag is set, or
 * an Error, setting the appropriate error number, which can then be
 * used to produce a runtime error message.
 */
int check_access(struct class_field *cf, struct b_class *instance_class)
{
    struct p_proc *caller_proc;
    struct class_field *caller_field;

    if (cf->flags & M_Public)
        return Succeeded;

    caller_proc = get_current_user_proc();

    if (caller_proc->package_id == 1)  /* Is the caller in lang? */
        return Succeeded;

    caller_field = caller_proc->field;
    switch (cf->flags & (M_Private | M_Protected | M_Package)) {
        case M_Private: {
            if (caller_field && caller_field->defining_class == cf->defining_class)
                return Succeeded;
            if (cf->flags & M_Readable)
                return Readable;
            ReturnErrNum(608, Error);
        }

        case M_Protected: {
            if (instance_class) {
                /* Instance access, caller must be in instance's implemented classes */
                if (caller_field && class_is(instance_class, 
                                             caller_field->defining_class))
                    return Succeeded;
                if (cf->flags & M_Readable)
                    return Readable;
                ReturnErrNum(609, Error);
            } else {
                /* Static access, definition must be in caller's implemented classes */
                if (caller_field && class_is(caller_field->defining_class, 
                                             cf->defining_class))
                    return Succeeded;
                if (cf->flags & M_Readable)
                    return Readable;
                ReturnErrNum(610, Error);
            }
        }

        case M_Package: {
            /* Check for same package.  Note that packages in
             * different programs are distinct.
             */
            if ((caller_proc->program == cf->defining_class->program &&
                 caller_proc->package_id == cf->defining_class->package_id))
                return Succeeded;
            if (cf->flags & M_Readable)
                return Readable;
            ReturnErrNum(611, Error);
        }

        default: {
            syserr("unknown/missing access modifier");
        }
    }
    return Succeeded; /* Not reached */
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
int check_access_ic(struct class_field *cf, struct b_class *instance_class, struct inline_field_cache *ic)
{
    if (ic) {
        int ac;
        if (ic->access)
            return ic->access;
        ac = check_access(cf, instance_class);
        if (ac != Error)
            ic->access = ac;
        return ac;
    } else
        return check_access(cf, instance_class);
}

/*
 * Do a binary search look up of a field name in the given class.
 * Returns the index into the class's field array, or -1 if not found.
 */
int lookup_class_field_by_name(struct b_class *class, dptr name)
{
    int i, c, m, l = 0, r = class->n_instance_fields + class->n_class_fields - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = class->sorted_fields[m];
        c = lexcmp(class->program->Fnames[class->fields[i]->fnum], name);
        if (c == Greater)
            r = m - 1;
        else if (c == Less)
            l = m + 1;
        else
            return i;
    }
    return -1;
}

/*
 * Do a binary search look up of a field number in the given class.
 * Returns the index into the class's field array, or -1 if not found.
 */
int lookup_class_field_by_fnum(struct b_class *class, int fnum)
{
    int i, c, m, l = 0, r = class->n_instance_fields + class->n_class_fields - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = class->sorted_fields[m];
        c = class->fields[i]->fnum - fnum;
        if (c > 0)
            r = m - 1;
        else if (c < 0)
            l = m + 1;
        else
            return i;
    }
    return -1;
}

/*
 * Lookup a field in a class.  The parameter query points to a
 * descriptor which is interpreted differently depending on whether we
 * are being invoked from an Op_Field instruction, in which case it is
 * a field number, or from a function such as Class.get(), in which
 * case it is a string or an integer.  The presence of an inline_field_cache
 * parameter decides which of the two types of query it is.
 * 
 * In either case, the index into the class's fields array is returned
 * to provide the corresponding field, or -1 if the field was not
 * found.
 */
int lookup_class_field(struct b_class *class, dptr query, struct inline_field_cache *ic)
{
    if (ic) {
        int fnum, index;

        /*
         * Check if we have a inline cache match.
         */
        if (ic->class == (union block *)class)
            return ic->index;

        /*
         * Query is a field number (from an Op_field).
         */
        fnum = IntVal(*query);
        if (class->program == curpstate) {
            /*
             * Lookup by fnum in the sorted field table.
             */
            index = lookup_class_field_by_fnum(class, fnum);
        } else {
            /*
             * The class was defined in another program.  We can't
             * lookup by field number - the target class will have a
             * different set of field numbers.  So we do string lookup
             * here instead.
             */
            index = lookup_class_field_by_name(class, fnames[fnum]);
        }

        /*
         * Cache the result.
         */
        ic->class = (union block *)class;
        ic->index = index;
        ic->access = 0;

        return index;
    } else {
        /*
         * Query is a string (field name) or int (field index).
         */
        if (is:string(*query))
            return lookup_class_field_by_name(class, query);

        if (IsCInteger(*query)) {
            int nf = class->n_instance_fields + class->n_class_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            int i = cvpos_item(IntVal(*query), nf);
            if (i == CvtFail)
                return -1;
            return i - 1;
        }

        syserr("Invalid query type to lookup_class_field");
        /* Not reached */
        return 0;
    }
}

int lookup_record_field_by_name(struct b_constructor *recdef, dptr name)
{
    int i, c, m, l = 0, r = recdef->n_fields - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = recdef->sorted_fields[m];
        c = lexcmp(recdef->program->Fnames[recdef->fnums[i]], name);
        if (c == Greater)
            r = m - 1;
        else if (c == Less)
            l = m + 1;
        else
            return i;
    }
    return -1;
}

int lookup_record_field_by_fnum(struct b_constructor *recdef, int fnum)
{
    int i, c, m, l = 0, r = recdef->n_fields - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = recdef->sorted_fields[m];
        c = recdef->fnums[i] - fnum;
        if (c > 0)
            r = m - 1;
        else if (c < 0)
            l = m + 1;
        else
            return i;
    }
    return -1;
}

/*
 * This follows similar logic to lookup_class_field above.
 */
int lookup_record_field(struct b_constructor *recdef, dptr query, struct inline_field_cache *ic)
{
    if (ic) {
        int fnum, index;

        /*
         * Check if we have a inline cache match.
         */
        if (ic->class == (union block *)recdef)
            return ic->index;

        fnum = IntVal(*query);

        if (recdef->program == curpstate)
            index = lookup_record_field_by_fnum(recdef, fnum);
        else
            index = lookup_record_field_by_name(recdef, fnames[fnum]);

        ic->class = (union block *)recdef;
        ic->index = index;
        ic->access = 0;

        return index;
    } else {
        /*
         * Query is a string (field name) or int (field index).
         */
        if (is:string(*query))
            return lookup_record_field_by_name(recdef, query);

        if (IsCInteger(*query)) {
            int nf = recdef->n_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            int i = cvpos_item(IntVal(*query), nf);
            if (i == CvtFail)
                return -1;
            return i - 1;
        }

        syserr("Invalid query type to lookup_record_field");
        /* Not reached */
        return 0;
    }
}


/*
 * Little c-level utility for accessing an instance field by name in
 * an object.  Returns null if the field is unknown, or the field is a
 * static or a method.  An optional inline_field_cache can be provided, and
 * in this case the name must be the same for every call with the same
 * cache (they should both really be pointers to static data).
 */

dptr c_get_instance_data(dptr x, dptr fname, struct inline_field_cache *ic)
{
    struct b_object *obj = &ObjectBlk(*x);
    struct b_class *class0 = obj->class;
    int i;

    if (ic) {
        if (ic->class == (union block *)class0)
            i = ic->index;
        else {
            i = lookup_class_field_by_name(class0, fname);
            ic->class = (union block *)class0;
            ic->index = i;
            ic->access = 0;
        }
    } else
        i = lookup_class_field_by_name(class0, fname);

    if (i < 0 || i >= class0->n_instance_fields)
        return 0;
    return &obj->fields[i];
}

/*
 * C-level util which behaves like the builtin is() function.  It
 * checks if a given dptr is an object, and if so whether it
 * implements a class named by cname.  An inline cache makes this
 * latter test efficient and if used the same name must always be
 * passed with the same cache.  Returns non-zero if x is an object and
 * implements the class; 0 otherwise.
 * 
 * Note that cname is looked up in curpstate, so if x is from another
 * program, no match will be found.
 * 
 * If c_is() is called from a native method, then note that curpstate
 * will have been set to the method's defining class's program (see
 * interp.r).
 */
int c_is(dptr x, dptr cname, struct inline_global_cache *ic)
{
    struct b_class *class0;
    dptr p;

    if (!is:object(*x))
        return 0;

    class0 = ObjectBlk(*x).class;

    if (ic) {
        if (curpstate == ic->program)
            p = ic->global;
        else {
            p = lookup_named_global(cname, 1, curpstate);
            ic->program = curpstate;
            ic->global = p;
        }
    } else
        p = lookup_named_global(cname, 1, curpstate);

    return p && is:class(*p) && class_is(class0, &ClassBlk(*p));
}

int get_proc_kind(struct b_proc *bp)
{
    switch (bp->type) {
        case P_Proc: {
            /* Icon procedure */
            if (((struct p_proc *)bp)->program == 0)
                return Internal;
            return Procedure;
            break;
        }
        case C_Proc: {
            /* Builtin */
            char c = *StrLoc(*bp->name);
            if (c == '&' && StrLen(*bp->name) > 1)
                return Keyword;
            if (c == '_' || oi_isalpha(c))
                return Function;
            return Operator;
            break;
        }
        default: {
            syserr("Unknown proc type");
            return 0;  /* Not reached */
        }
    }
}
