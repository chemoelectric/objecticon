#include "../h/modflags.h"

/*
 * File: imisc.r
 *  Contents: field, mkrec, limit, llist, bscan, escan
 */

/*
 * x.y - access field y of record x.
 */
static int cast_access(dptr cargp, struct inline_field_cache *ic);
static int instance_access(dptr cargp, struct inline_field_cache *ic);
static int class_access(dptr cargp, struct inline_field_cache *ic);
static int record_access(dptr cargp, struct inline_field_cache *ic);

/*
 * x.y() or x.y!l - field apply/invoke combination
 */
static int instance_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic);
static int cast_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic);
static int class_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic);
static int record_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic);

LibDcl(field,2,".")
{
    int r;
    struct inline_field_cache *ic;
    Deref(Arg1);
    Deref(Arg2);
    ic = (struct inline_field_cache*)ipc.opnd;
    ipc.opnd += 2;
    type_case Arg1 of {
      record: {
            r = record_access(cargp, ic);
      }

      cast: {
            r = cast_access(cargp, ic);
      }

      class: {
            r = class_access(cargp, ic);
      }

      object: {
            r = instance_access(cargp, ic);
      }

      default: {
          RunErr(624, &Arg1);
      }
    }
    if (r == Error)
        RunErr(0, &Arg1);
    Return;
}

int field_access(dptr cargp)
{
    Deref(Arg1);
    Deref(Arg2);
    type_case Arg1 of {
      record: {
            return record_access(cargp, 0);
      }

      cast: {
            return cast_access(cargp, 0);
      }

      class: {
            return class_access(cargp, 0);
      }

      object: {
            return instance_access(cargp, 0);
      }

      default: {
          ReturnErrNum(624, Error);
      }
   }
}

int invokef_access(int fno, int *nargs)
{
    struct inline_field_cache *ic;
    struct descrip field;
    dptr cargp;
    ic = (struct inline_field_cache*)ipc.opnd;
    ipc.opnd += 2;
    cargp = (dptr)(sp - 1) - *nargs;
    Deref(*cargp);
    MakeInt(fno, &field);
    type_case *cargp of {
      object: {
            return instance_invokef(nargs, cargp, &field, ic);
      }
      class: {
            return class_invokef(nargs, cargp, &field, ic);
      }
      cast: {
            return cast_invokef(nargs, cargp, &field, ic);
      }
      record: {
            return record_invokef(nargs, cargp, &field, ic);
      }
      default: {
          ReturnErrNum(624, Error);
      }
    }
}

static int instance_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic)
{
    struct b_object *obj = &BlkLoc(*cargp)->object;
    struct b_class *class = obj->class;
    struct class_field *cf;
    int i, j, ac;

    i = lookup_class_field(class, field, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    cf = class->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static)
        ReturnErrNum(601, Error);

    if (cf->flags & M_Method) {
        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && obj->init_state != Initializing)
            ReturnErrNum(622, Error);

        ac = check_access(cf, class);
        if (ac == Error)
            return ac;

        /*
         * Instance method.  Move args down, increment nargs, slot in proc.
         */
        for (j = *nargs; j >= 0; j--) 
            cargp[j + 1] = cargp[j];
        cargp->dword = D_Proc;
        BlkLoc(*cargp) = (union block *)&BlkLoc(*cf->field_descriptor)->proc;
        (*nargs)++;
        sp += 2;
    } else {
        ac = check_access(cf, class);
        if (ac == Succeeded || (cf->flags & M_Readable))
            *cargp = obj->fields[i];
        else
            return ac;
    }

    EVValD(&xexpr, E_Objectref);
    EVVal(i + 1, E_Objectsub);
    return Succeeded;
}

static int cast_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic)
{
    struct b_cast *cast = &BlkLoc(*cargp)->cast;
    struct b_object *obj = cast->object;
    struct b_class *obj_class = obj->class, *cast_class = cast->class;
    struct class_field *cf;
    int i, j, ac;

    /* Lookup in the cast's class */
    i = lookup_class_field(cast_class, field, ic);
    if (i < 0)
        ReturnErrNum(207, Error);

    cf = cast_class->fields[i];

    if (cf->flags & M_Static)
        ReturnErrNum(601, Error);

    if (!(cf->flags & M_Method))
        ReturnErrNum(628, Error);

    /* Can't access new except whilst initializing */
    if ((cf->flags & M_Special) && obj->init_state != Initializing)
        ReturnErrNum(622, Error);

    ac = check_access(cf, obj_class);
    if (ac == Error)
        return ac;

    /*
     * Instance method.  Move args down, increment nargs, slot in proc and object.
     */
    for (j = *nargs; j > 0; j--) 
        cargp[j + 1] = cargp[j];

    cargp->dword = D_Proc;
    BlkLoc(*cargp) = (union block *)&BlkLoc(*cf->field_descriptor)->proc;
    cargp[1].dword = D_Object;
    BlkLoc(cargp[1]) = (union block *)obj;
    (*nargs)++;
    sp += 2;
    EVValD(&xexpr, E_Castref);
    EVVal(i + 1, E_Castsub);

    return Succeeded;
}

static int class_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic)
{
    struct b_class *class = &BlkLoc(*cargp)->class;
    struct class_field *cf;
    int i, ac;

    ensure_initialized(class);
    i = lookup_class_field(class, field, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    cf = class->fields[i];

    /* Can only access a static field (var or meth) via the class */
    if (!(cf->flags & M_Static))
        ReturnErrNum(600, Error);

    /* Can't access static init method via a field */
    if (cf->flags & M_Special)
        ReturnErrNum(621, Error);

    ac = check_access(cf, 0);
    if (ac == Succeeded || (cf->flags & M_Readable))
        *cargp = *cf->field_descriptor;
    else
        return ac;

    EVValD(&xexpr, E_Classref);
    EVVal(i + 1, E_Classsub);
    return Succeeded;
}

static int record_invokef(int *nargs, dptr cargp, dptr field, struct inline_field_cache *ic)
{
    struct b_record *rec = &BlkLoc(*cargp)->record;
    struct b_constructor *recdef = BlkLoc(*cargp)->record.constructor;

    int i = lookup_record_field(recdef, field, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    *cargp = rec->fields[i];

    EVValD(&xexpr, E_Rref);
    EVVal(i + 1, E_Rsub);

    return Succeeded;
}


static int cast_access(dptr cargp, struct inline_field_cache *ic)
{
    struct b_cast *cast = &BlkLoc(Arg1)->cast;
    struct b_object *obj = cast->object;
    struct b_methp *mp;
    struct b_class *obj_class = obj->class, *cast_class = cast->class;
    struct class_field *cf;
    int i, ac;

    /* Lookup in the cast's class */
    i = lookup_class_field(cast_class, &Arg2, ic);
    if (i < 0)
        ReturnErrNum(207, Error);

    cf = cast_class->fields[i];

    if (cf->flags & M_Static)
        ReturnErrNum(601, Error);

    if (!(cf->flags & M_Method))
        ReturnErrNum(628, Error);

    /* Can't access new except whilst initializing */
    if ((cf->flags & M_Special) && obj->init_state != Initializing)
        ReturnErrNum(622, Error);

    ac = check_access(cf, obj_class);
    if (ac == Error)
        return ac;
    /*
     * Instance method.
     */
    MemProtect(mp = alcmethp());
    /*
     * Refresh pointers after allocation.
     */
    cast = &BlkLoc(Arg1)->cast;
    obj = cast->object;
    mp->object = obj;
    mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
    Arg0.dword = D_Methp;
    BlkLoc(Arg0) = (union block *)mp;

    EVValD(&Arg1, E_Castref);
    EVVal(i + 1, E_Castsub);

    return Succeeded;
}

static int class_access(dptr cargp, struct inline_field_cache *ic)
{
    struct b_class *class = &BlkLoc(Arg1)->class;
    struct class_field *cf;
    dptr dp;
    int i, ac;

    ensure_initialized(class);
    i = lookup_class_field(class, &Arg2, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    cf = class->fields[i];

    /* Can only access a static field (var or meth) via the class */
    if (!(cf->flags & M_Static))
        ReturnErrNum(600, Error);

    /* Can't access static init method via a field */
    if (cf->flags & M_Special)
        ReturnErrNum(621, Error);

    dp = cf->field_descriptor;
    ac = check_access(cf, 0);

    if (ac == Succeeded && 
        !(cf->flags & M_Method) &&        /* Don't return a ref to a static method */
        (!(cf->flags & M_Const) || class->init_state == Initializing))
    {
        Arg0.dword = D_Var;
        VarLoc(Arg0) = dp;
    } else if (ac == Succeeded || (cf->flags & M_Readable))
        Arg0 = *dp;
    else
        return ac;

    EVValD(&Arg1, E_Classref);
    EVVal(i + 1, E_Classsub);
    return Succeeded;
}

static int instance_access(dptr cargp, struct inline_field_cache *ic)
{
    struct b_object *obj = &BlkLoc(Arg1)->object;
    struct b_class *class = obj->class;
    struct b_methp *mp;
    struct class_field *cf;
    int i, ac;

    i = lookup_class_field(class, &Arg2, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    cf = class->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static)
        ReturnErrNum(601, Error);

    if (cf->flags & M_Method) {
        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && obj->init_state != Initializing)
            ReturnErrNum(622, Error);

        ac = check_access(cf, class);
        if (ac == Error)
            return ac;

        /*
         * Instance method.  Return a method pointer.
         */
        MemProtect(mp = alcmethp());
        /*
         * Refresh pointers after allocation.
         */
        obj = &BlkLoc(Arg1)->object;
        mp->object = obj;
        mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
        Arg0.dword = D_Methp;
        BlkLoc(Arg0) = (union block *)mp;
    } else {
        dptr dp = &obj->fields[i];
        ac = check_access(cf, class);
        if (ac == Succeeded &&
            (!(cf->flags & M_Const) || obj->init_state == Initializing))
        {
            /* Return a pointer to the field */
            Arg0.dword = D_Var + ((word *)dp - (word *)obj);
            BlkLoc(Arg0) = (union block *)obj;
        } else if (ac == Succeeded || (cf->flags & M_Readable))
            Arg0 = *dp;
        else
            return ac;
    }

    EVValD(&Arg1, E_Objectref);
    EVVal(i + 1, E_Objectsub);
    return Succeeded;
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

    caller_proc = CallerProc;

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
        c = lexcmp(&class->fields[i]->name, name);
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
int lookup_class_field_by_fnum(struct b_class *class, word fnum)
{
    int i, m, l = 0, r = class->n_instance_fields + class->n_class_fields - 1;
    word c;
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
        word fnum;
        int index;

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
            index = lookup_class_field_by_name(class, &efnames[fnum]);
        } else if (class->program != curpstate) {
            /*
             * The class was defined in another program, but the field
             * just happens to match one defined in this program.  We
             * can't lookup by field number - the target class will
             * have a different set of field numbers.  So we do string
             * lookup here too.
             */
            index = lookup_class_field_by_name(class, &fnames[fnum]);
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
            word nf = class->n_instance_fields + class->n_class_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            word i = cvpos(IntVal(*query), nf);
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

static int record_access(dptr cargp, struct inline_field_cache *ic)
{
    struct b_record *rec = &BlkLoc(Arg1)->record;
    struct b_constructor *recdef = BlkLoc(Arg1)->record.constructor;
    dptr dp;
    int i = lookup_record_field(recdef, &Arg2, ic);
    if (i < 0)
        ReturnErrNum(207, Error);
    /*
     * Return a pointer to the descriptor for the appropriate field.
     */
    dp = &rec->fields[i];
    Arg0.dword = D_Var + ((word *)dp - (word *)rec);
    BlkLoc(Arg0) = (union block *)rec;

    EVValD(&Arg1, E_Rref);
    EVVal(i + 1, E_Rsub);

    return Succeeded;
}

int lookup_record_field_by_name(struct b_constructor *recdef, dptr name)
{
    int i, c, m, l = 0, r = recdef->n_fields - 1;
    while (l <= r) {
        m = (l + r) / 2;
        i = recdef->sorted_fields[m];
        c = lexcmp(&recdef->field_names[i], name);
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
 * This follows similar logic to lookup_class_field above.
 */
int lookup_record_field(struct b_constructor *recdef, dptr query, struct inline_field_cache *ic)
{
    if (ic) {
        word fnum;
        int index;

        /*
         * Check if we have a inline cache match.
         */
        if (ic->class == (union block *)recdef)
            return ic->index;

        fnum = IntVal(*query);

        if (fnum < 0)
            index = lookup_record_field_by_name(recdef, &efnames[fnum]);
        else
            index = lookup_record_field_by_name(recdef, &fnames[fnum]);

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
            word nf = recdef->n_fields;
            /*
             * Simple index into fields array, using conventional icon
             * semantics.
             */
            word i = cvpos(IntVal(*query), nf);
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
 * limit - explicit limitation initialization.
 */


LibDcl(limit,2,"\\")
{

    C_integer tmp;

    /*
     * The limit is both passed and returned in Arg0.  The limit must
     *  be an integer.  If the limit is 0, the expression being evaluated
     *  fails.  If the limit is < 0, it is an error.  Note that the
     *  result produced by limit is ultimately picked up by the lsusp
     *  function.
     */
    Deref(Arg0);

    if (!cnv:C_integer(Arg0,tmp))
        RunErr(101, &Arg0);
    MakeInt(tmp,&Arg0);

    if (IntVal(Arg0) < 0) 
        RunErr(205, &Arg0);
    if (IntVal(Arg0) == 0)
        Fail;
    Return;
}

/*
 * bscan - set &subject and &pos upon entry to a scanning expression.
 *
 *  Arguments are:
 *	Arg0 - new value for &subject
 *	Arg1 - saved value of &subject
 *	Arg2 - saved value of &pos
 *
 * A variable pointing to the saved &subject and &pos is returned to be
 *  used by escan.
 */

LibDcl(bscan,2,"?")
{
    int rc;
    struct pf_marker *cur_pfp;

    /*
     * Convert the new value for &subject to a string.
     */
    Deref(Arg0);

    if (!cnv:string_or_ucs(Arg0,Arg0))
       RunErr(129, &Arg0);

    EVValD(&Arg0, E_Snew);

    /*
     * Establish a new &subject value and set &pos to 1.
     */
    k_subject = Arg0;
    k_pos = 1;

    /* If the saved scanning environment belongs to the current procedure
     *  call, put a reference to it in the procedure frame.
     */
    if (pfp->pf_scan == NULL)
        pfp->pf_scan = &Arg1;
    cur_pfp = pfp;

    /*
     * Suspend with a variable pointing to the saved &subject and &pos.
     */
    ArgType(0) = D_Var;
    VarLoc(Arg0) = &Arg1;

    rc = interp(G_Csusp,cargp);

#if E_Srem || E_Sfail
    if (rc != A_Resume)
        EVValD(&Arg1, E_Srem);
    else
        EVValD(&Arg1, E_Sfail);
#endif					/* E_Srem || E_Sfail */

    if (pfp != cur_pfp)
        return rc;

    /*
     * Leaving scanning environment. Restore the old &subject and &pos values.
     */
    k_subject = Arg1;
    k_pos = IntVal(Arg2);

    if (pfp->pf_scan == &Arg1)
        pfp->pf_scan = NULL;

    return rc;

}

/*
 * escan - restore &subject and &pos at the end of a scanning expression.
 *
 *  Arguments:
 *    Arg0 - variable pointing to old values of &subject and &pos
 *    Arg1 - result of the scanning expression
 *
 * The two arguments are reversed, so that the result of the scanning
 *  expression becomes the result of escan. This result is dereferenced
 *  if it refers to &subject or &pos. Then the saved values of &subject
 *  and &pos are exchanged with the current ones.
 *
 * Escan suspends once it has restored the old &subject; on failure
 *  the new &subject and &pos are "unrestored", and the failure is
 *  propagated into the using clause.
 */

LibDcl(escan,1,"escan")
{
    struct descrip tmp;
    int rc;
    struct pf_marker *cur_pfp;

    /*
     * Copy the result of the scanning expression into Arg0, which will
     *  be the result of the scan.
     */
    tmp = Arg0;
    Arg0 = Arg1;
    Arg1 = tmp;

    /*
     * If the result of the scanning expression is &subject or &pos,
     *  it is dereferenced. #%#%  following is incorrect #%#%
     */
    /*if ((Arg0 == k_subject) ||
      (Arg0 == kywd_pos))
      Deref(Arg0); */

    /*
     * Swap new and old values of &subject
     */
    tmp = k_subject;
    k_subject = *VarLoc(Arg1);
    *VarLoc(Arg1) = tmp;

    /*
     * Swap new and old values of &pos
     */
    tmp = *(VarLoc(Arg1) + 1);
    IntVal(*(VarLoc(Arg1) + 1)) = k_pos;
    k_pos = IntVal(tmp);

    /*
     * If we are returning to the scanning environment of the current 
     *  procedure call, indicate that it is no longed in a saved state.
     */
    if (pfp->pf_scan == VarLoc(Arg1))
        pfp->pf_scan = NULL;
    cur_pfp = pfp;

    /*
     * Suspend with the value of the scanning expression.
     */

    EVValD(&k_subject, E_Ssusp);

    rc = interp(G_Csusp,cargp);
    if (pfp != cur_pfp)
        return rc;

    /*
     * Re-entering scanning environment, exchange the values of &subject
     *  and &pos again
     */
    tmp = k_subject;
    k_subject = *VarLoc(Arg1);
    *VarLoc(Arg1) = tmp;

#if E_Sresum
    if (rc == A_Resume)
        EVValD(&k_subject, E_Sresum);
#endif					/* E_Sresum */

    tmp = *(VarLoc(Arg1) + 1);
    IntVal(*(VarLoc(Arg1) + 1)) = k_pos;
    k_pos = IntVal(tmp);

    if (pfp->pf_scan == NULL)
        pfp->pf_scan = VarLoc(Arg1);

    return rc;
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
    struct b_class *class = obj->class;
    int i;

    if (ic) {
        if (ic->class == (union block *)class)
            i = ic->index;
        else {
            i = lookup_class_field_by_name(class, fname);
            ic->class = (union block *)class;
            ic->index = i;
        }
    } else
        i = lookup_class_field_by_name(class, fname);

    if (i < 0 || i >= class->n_instance_fields)
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
    struct b_class *class;
    dptr p;

    if (!is:object(*x))
        return 0;

    class = BlkLoc(*x)->object.class;

    if (ic) {
        if (class->program == ic->program)
            p = ic->global;
        else {
            p = lookup_global(cname, class->program);
            ic->program = class->program;
            ic->global = p;
        }
    } else
        p = lookup_global(cname, class->program);

    return p && is:class(*p) && class_is(class, &BlkLoc(*p)->class);
}
