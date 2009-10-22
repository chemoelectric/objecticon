#include "../h/modflags.h"

    
struct b_proc *get_current_user_proc()
{
    struct p_frame *pf = curr_pf;
    while (pf->proc->program == 0)
        pf = pf->caller;
    return pf->proc;
}

struct p_frame *get_current_user_frame()
{
    struct p_frame *pf = curr_pf;
    while (pf->proc->program == 0)
        pf = pf->caller;
    return pf;
}

/*
 * Check whether the calling procedure (deduced from the stack) has
 * access to the given field of the given instance class (which is
 * null for a static access).  Returns Succeeded if it does have
 * access, or an Error if it doesn't, setting the appropriate error
 * number, which can then be used to produce a runtime error message.
 */
int check_access(struct class_field *cf, struct b_class *instance_class)
{
    struct b_proc *caller_proc;
    struct class_field *caller_field;

    if (cf->flags & M_Public)
        return Succeeded;

    caller_proc = get_current_user_proc();

    if (caller_proc->package_id == 1)  /* Is the caller in lang? */
        return Succeeded;

    caller_field = caller_proc->field;
    switch (cf->flags & (M_Private|M_Protected|M_Package)) {
        case M_Private: {
            if (caller_field && caller_field->defining_class == cf->defining_class)
                return Succeeded;
            ReturnErrNum(608, Error);
        }

        case M_Protected: {
            if (instance_class) {
                /* Instance access, caller must be in instance's implemented classes */
                if (caller_field && class_is(instance_class, 
                                             caller_field->defining_class))
                    return Succeeded;
                ReturnErrNum(609, Error);
            } else {
                /* Static access, definition must be in caller's implemented classes */
                if (caller_field && class_is(caller_field->defining_class, 
                                             cf->defining_class))
                    return Succeeded;
                ReturnErrNum(610, Error);
            }
        }

        case M_Package: {
            /* Check for same package.  Note that packages in
             * different programs are distinct.  Note also that the
             * field's prog/package - may be different from the proc's
             * if it was created via set_method.  In any case, we
             * allow access for a prog/package match on either field
             * or proc.
             */
            if ((caller_proc->program == cf->defining_class->program &&
                 caller_proc->package_id == cf->defining_class->package_id) ||
                (caller_field &&
                 caller_field->defining_class->program == cf->defining_class->program &&
                 caller_field->defining_class->package_id == cf->defining_class->package_id))
                return Succeeded;
            ReturnErrNum(611, Error);
        }

        default: {
            syserr("unknown/missing access modifier");
        }
    }
    return Succeeded; /* Not reached */
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
        if (fnum < 0) {
            /*
             * This means the field was not encountered as a field of
             * a class/record during linking.  The field lookup may
             * still work however, if the class is in another program.
             * 
             * The field name is stored in the field names table and
             * the offset from the end is the given number, so we look
             * up by string comparison.
             */
            index = lookup_class_field_by_name(class, efnames[fnum]);
        } else if (class->program != curpstate) {
            /*
             * The class was defined in another program, but the field
             * just happens to match one defined in this program.  We
             * can't lookup by field number - the target class will
             * have a different set of field numbers.  So we do string
             * lookup here too.
             */
            index = lookup_class_field_by_name(class, fnames[fnum]);
        } else {
            /*
             * Lookup by fnum in the sorted field table.
             */
            index = lookup_class_field_by_fnum(class, fnum);
        }

        /*
         * Cache the result.
         */
        ic->class = (union block *)class;
        ic->index = index;

        return index;
    } else {
        /*
         * Query is a string (field name) or int (field index).
         */
        if (is:string(*query))
            return lookup_class_field_by_name(class, query);

        if (query->dword == D_Integer) {
            int nf = class->n_instance_fields + class->n_class_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            int i = cvpos(IntVal(*query), nf);
            if (i != CvtFail && i <= nf)
                return i - 1;
            else
                return -1;
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

        if (fnum < 0)
            index = lookup_record_field_by_name(recdef, efnames[fnum]);
        else if (recdef->program != curpstate)
            index = lookup_record_field_by_name(recdef, fnames[fnum]);
        else
            index = lookup_record_field_by_fnum(recdef, fnum);

        ic->class = (union block *)recdef;
        ic->index = index;

        return index;
    } else {
        /*
         * Query is a string (field name) or int (field index).
         */
        if (is:string(*query))
            return lookup_record_field_by_name(recdef, query);

        if (query->dword == D_Integer) {
            int nf = recdef->n_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            int i = cvpos(IntVal(*query), nf);
            if (i != CvtFail && i <= nf)
                return i - 1;
            else
                return -1;
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
    struct b_object *obj = &BlkLoc(*x)->object;
    struct b_class *class0 = obj->class;
    int i;

    if (ic) {
        if (ic->class == (union block *)class0)
            i = ic->index;
        else {
            i = lookup_class_field_by_name(class0, fname);
            ic->class = (union block *)class0;
            ic->index = i;
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
 */
int c_is(dptr x, dptr cname, struct inline_global_cache *ic)
{
    struct b_class *class0;
    dptr p;

    if (!is:object(*x))
        return 0;

    class0 = BlkLoc(*x)->object.class;

    if (ic) {
        if (class0->program == ic->program)
            p = ic->global;
        else {
            p = lookup_global(cname, class0->program);
            ic->program = class0->program;
            ic->global = p;
        }
    } else
        p = lookup_global(cname, class0->program);

    return p && is:class(*p) && class_is(class0, &BlkLoc(*p)->class);
}
