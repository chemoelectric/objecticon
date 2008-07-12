#include "../h/modflags.h"

/*
 * File: imisc.r
 *  Contents: field, mkrec, limit, llist, bscan, escan
 */

/*
 * x.y - access field y of record x.
 */
static int cast_access(dptr cargp, int query_flag);
static int instance_access(dptr cargp, int query_flag);
static int class_access(dptr cargp, int query_flag);
static int lookup_record_field(struct b_proc *recdef, dptr num);
static int in_lang(dptr s);
static int same_package(dptr n1, dptr n2);
static int in_hierarchy(struct b_class *c1, struct b_class *c2);
static int record_access(dptr cargp);

LibDcl(field,2,".")
{
    int r;
    Deref(Arg1);
    Deref(Arg2);
    type_case Arg1 of {
      record: {
            r = record_access(cargp);
        }

      cast: {
            r = cast_access(cargp, 1);
        }

      class: {
            r = class_access(cargp, 1);
        }

      object: {
            r = instance_access(cargp, 1);
        }

        default: {
            RunErr(107, &Arg1);
        }
    }
    if (r != 0)
        RunErr(r, &Arg1);
    Return;
}

int field_access(dptr cargp)
{
    Deref(Arg1);
    Deref(Arg2);
    type_case Arg1 of {
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
            fatalerr(620, &Arg1);
            return 0; /* Unreachable */
        }
    }
}

static int cast_access(dptr cargp, int query_flag)
{
    struct b_cast *cast = &BlkLoc(Arg1)->cast;
    struct b_object *obj = cast->object;
    struct b_methp *mp;
    struct b_class *obj_class = obj->class, *cast_class = cast->class;
    struct class_field *cf;
    int i, ac;

    /* Lookup field in the object's own class first */
    i = lookup_class_field(obj_class, &Arg2, query_flag);
    if (i < 0)
        return 207;
    cf = obj_class->fields[i];
    
    if (cf->flags & (M_Method | M_Static)) {
        /* It's not an instance variable, so lookup in the cast's class */
        i = lookup_class_field(cast_class, &Arg2, query_flag);
        if (i < 0)
            return 207;
        cf = cast_class->fields[i];

        if (cf->flags & M_Static)
            return 601;

        /* It should be a method, otherwise it would have been inherited as an
         * instance variable in the object's own class
         */
        if (!(cf->flags & M_Method))
            syserr("method expected in cast");

        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && obj->init_state != Initializing)
            return 622;

        ac = check_access(cf, obj_class);
        if (ac != 0)
            return ac;
        /*
         * Instance method.
         */
        Protect(mp = alcmethp(), fatalerr(0,NULL));
        /*
         * Refresh pointers after allocation.
         */
        cast = &BlkLoc(Arg1)->cast;
        obj = cast->object;
        mp->object = obj;
        mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
        Arg0.dword = D_Methp;
        BlkLoc(Arg0) = (union block *)mp;
        return 0;
    } else {
        /* An instance field, simply return it like an access to the object itself */
        dptr dp = &obj->fields[i];
        ac = check_access(cf, obj_class);
        if (ac == 0 &&
            (!(cf->flags & M_Const) || obj->init_state == Initializing))
        {
            /* Return a pointer to the field */
            Arg0.dword = D_Var + ((word *)dp - (word *)obj);
            BlkLoc(Arg0) = (union block *)obj;
            return 0;
        }
        if (ac == 0 || (cf->flags & M_Readable)) {
            Arg0 = *dp;
            return 0;
        }
        return ac;
    }
}

static int class_access(dptr cargp, int query_flag)
{
    struct b_class *class = &BlkLoc(Arg1)->class;
    struct class_field *cf;
    dptr dp;
    int i, ac;

    ensure_initialized(class);
    i = lookup_class_field(class, &Arg2, query_flag);
    if (i < 0)
        return 207;
    cf = class->fields[i];

    /* Can only access a static field (var or meth) via the class */
    if (!(cf->flags & M_Static))
        return 600;

    /* Can't access static init method via a field */
    if (cf->flags & M_Special)
        return 621;

    dp = cf->field_descriptor;
    ac = check_access(cf, 0);

    if (ac == 0 && 
        !(cf->flags & M_Method) &&        /* Don't return a ref to a static method */
        (!(cf->flags & M_Const) || class->init_state == Initializing))
    {
        Arg0.dword = D_Var;
        VarLoc(Arg0) = dp;
        return 0;
    }
    if (ac == 0 || (cf->flags & M_Readable)) {
        Arg0 = *dp;
        return 0;
    }

    return ac;
}

static int instance_access(dptr cargp, int query_flag)
{
    struct b_object *obj = &BlkLoc(Arg1)->object;
    struct b_class *class = obj->class;
    struct b_methp *mp;
    struct class_field *cf;
    int i, ac;

    i = lookup_class_field(class, &Arg2, query_flag);
    if (i < 0)
        return 207;
    cf = class->fields[i];

    /* Can't access a static (var or meth) via an instance */
    if (cf->flags & M_Static)
        return 601;

    if (cf->flags & M_Method) {
        /* Can't access new except whilst initializing */
        if ((cf->flags & M_Special) && obj->init_state != Initializing)
            return 622;

        ac = check_access(cf, class);
        if (ac != 0)
            return ac;

        /*
         * Instance method.  Return a method pointer.
         */
        Protect(mp = alcmethp(), fatalerr(0,NULL));
        /*
         * Refresh pointers after allocation.
         */
        obj = &BlkLoc(Arg1)->object;
        mp->object = obj;
        mp->proc = &BlkLoc(*cf->field_descriptor)->proc;
        Arg0.dword = D_Methp;
        BlkLoc(Arg0) = (union block *)mp;
        return 0;
    } else {
        dptr dp = &obj->fields[i];
        ac = check_access(cf, class);
        if (ac == 0 &&
            (!(cf->flags & M_Const) || obj->init_state == Initializing))
        {
            /* Return a pointer to the field */
            Arg0.dword = D_Var + ((word *)dp - (word *)obj);
            BlkLoc(Arg0) = (union block *)obj;
            return 0;
        }
        if (ac == 0 || (cf->flags & M_Readable)) {
            Arg0 = *dp;
            return 0;
        }
        return ac;
    }
}

/*
 * Check whether the calling procedure (deduced from the stack) has
 * access to the given field of the given instance class (which is
 * null for a static access).  Returns zero if it does have access, or
 * an error number if it doesn't.  The error number can then be used
 * to produce a runtime error message, or simply to cause failure.
 */
int check_access(struct class_field *cf, struct b_class *instance_class)
{
    struct pf_marker *fp = pfp;
    dptr pp = (dptr)fp - (pfp->pf_nargs + 1);
    struct class_field *caller_field;
    struct b_class *caller_class = 0;
    struct b_proc *caller_proc;
    dptr caller_fq;   /* Either the class name or the procedure name; gives the caller package */

    if (cf->flags & M_Public)
        return 0;

    if (pp->dword != D_Proc) {
        showstack();
        syserr("couldn't find proc on stack");
    }

    caller_proc = &BlkLoc(*pp)->proc;

    caller_field = caller_proc->field;
    if (caller_field) {
        caller_class = caller_field->defining_class;
        caller_fq = &caller_class->name;
    } else
        caller_fq = &caller_proc->pname;

    if (in_lang(caller_fq))
        return 0;

    if (cf->flags & M_Private) {
        if (caller_class == cf->defining_class)
            return 0;
        return 608;
    }

    if (cf->flags & M_Protected) {
        if (instance_class) {
            /* Instance access, caller must be in instance's superclasses */
            if (caller_class && in_hierarchy(caller_class, instance_class))
                return 0;
            return 609;
        } else {
            /* Static access, definition must be in caller's superclasses */
            if (caller_class && in_hierarchy(cf->defining_class, caller_class))
                return 0;
            return 610;
        }
    }

    if (cf->flags & M_Package) {
        /* Check for same package.  Note that packages in different programs are
         * distinct.
         */
        if (caller_proc->program == cf->defining_class->program &&
                same_package(caller_fq, &cf->defining_class->name))
            return 0;
        return 611;
    }

    syserr("unknown/missing access modifier");
    return 0; /* Not reached */
}

/*
 * Is c1 in the hierarchy of c2, ie in its list of implemented
 * classes?
 */
static int in_hierarchy(struct b_class *c1, struct b_class *c2)
{
    int i;
    for (i = 0; i < c2->n_implemented_classes; ++i)
        if (c2->implemented_classes[i] == c1)
            return 1;
    return 0;
}

static int pack_end(dptr p)
{
    char *s = StrLoc(*p);
    int i = StrLen(*p) - 1;
    while (i >= 0) {
        if (s[i] == '.')
            break;
        --i;
    }
    return i;
}

static int in_lang(dptr p)
{
    return pack_end(p) == 4 && !strncmp(StrLoc(*p), "lang", 4);
}

static int same_package(dptr p1, dptr p2)
{
    int i1 = pack_end(p1);
    int i2 = pack_end(p2);
    if (i1 < 0 || i2 < 0)
        return i1 == i2;
    return i1 == i2 && !strncmp(StrLoc(*p1), StrLoc(*p2), i1);
}

/*
 * Do a binary search look up of a field name in the given class.  Returns the
 * index into the class's field array, or -1 if not found.
 */
static int lookup_class_field_by_name(struct b_class *class, dptr name)
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
 * Lookup a field in a class.  The parameter query points to a
 * descriptor which is interpreted differently depending on query_flag.
 * If the flag is set, then it is a field number from an Op_Field
 * instruction; otherwise it is a string or an integer from a function
 * such as Class.get().
 * 
 * In either case, the index into the class's fields array is returned
 * to provide the corresponding field, or -1 if the field was not
 * found.
 */
int lookup_class_field(struct b_class *class, dptr query, int query_flag)
{
    if (query_flag) {
        int fnum;
        /*
         * Query is a field number (from an Op_field).
         */
        fnum = IntVal(*query);
        if (fnum < 0) {
            /*
             * This means the field is not in the field table (ie was not
             * encountered as a field of a class/record during linking).
             * Its name is stored in the field names table however, and
             * the offset from the end is the given number.
             * 
             * So we forget about field tables, and look up by string
             * comparison using the class's field info.
             */
            return lookup_class_field_by_name(class, &efnames[fnum]);
        }

        if (class->program != curpstate) {
            /*
             * The class was defined in another prog - so we can't use our
             * own fieldtable - the target class doesn't have a column in
             * it.  Likewise, we can't use fnum in the other prog's
             * fieldtable.  So we do string lookup here too.
             */
            return lookup_class_field_by_name(class, &fnames[fnum]);
        }

        /*
         * The simple case - use the field table.
         */
        return ftabp[fnum * (*records + *classes) + class->fieldtable_col];
    } else {
        int i, nf = class->n_instance_fields + class->n_class_fields;
        /*
         * Query is a string (field name) or int (field index).
         */
        if (Qual(*query))
            return lookup_class_field_by_name(class, query);

        if (!is:integer(*query))
            syserr("Expected string or integer for field lookup");

        /*
         * Simple index into fields array, using conventional icon
         * semantics.
         */
        i = IntVal(*query);
        if (i > 0) {
            if (i <= nf)
                return i - 1;
        } else if (i < 0) {
            if (i >= -nf)
                return nf + i;
        }
        return -1;
    }
}

static int record_access(dptr cargp)
{
    struct b_record *rec = &BlkLoc(Arg1)->record;
    struct b_proc *recdef = &BlkLoc(Arg1)->record.recdesc->proc;
    dptr dp;
    int i = lookup_record_field(recdef, &Arg2);
    if (i < 0)
        return 207;
    /*
     * Return a pointer to the descriptor for the appropriate field.
     */
    dp = &rec->fields[i];
    Arg0.dword = D_Var + ((word *)dp - (word *)rec);
    BlkLoc(Arg0) = (union block *)rec;
    return 0;
}

/*
 * This follows similar logic to lookup_class_field above.
 */
static int lookup_record_field(struct b_proc *recdef, dptr num)
{
    struct descrip s;
    int i;
    int fnum = IntVal(*num);

    if (fnum < 0) {
        s = efnames[fnum];
        for (i = 0; i < recdef->nfields; ++i) {
            if (StrLen(s) == StrLen(recdef->lnames[i]) &&
                !strncmp(StrLoc(s), StrLoc(recdef->lnames[i]), StrLen(s)))
                break;
        }
        if (i < recdef->nfields)
            return i;
        return -1;
    }

    if (recdef->program != curpstate) {
        s = fnames[fnum];
        for (i = 0; i < recdef->nfields; ++i) {
            if (StrLen(s) == StrLen(recdef->lnames[i]) &&
                !strncmp(StrLoc(s), StrLoc(recdef->lnames[i]), StrLen(s)))
                break;
        }
        if (i < recdef->nfields)
            return i;
        return -1;
    }

    return ftabp[fnum * (*records + *classes) + recdef->recfieldtable_col];
}


/*
 * mkrec - create a record.
 */

LibDcl(mkrec,-1,"mkrec")
{
    register int i;
    register struct b_proc *bp;
    register struct b_record *rp;

    /*
     * Be sure that call is from a procedure.
     */

    /*
     * Get a pointer to the record constructor procedure and allocate
     *  a record with the appropriate number of fields.
     */
    bp = (struct b_proc *) BlkLoc(Arg0);
    Protect(rp = alcrecd((int)bp->nfields, (union block *)bp), RunErr(0,NULL));

    /*
     * Set all fields in the new record to null value.
     */
    for (i = (int)bp->nfields; i > nargs; i--)
        rp->fields[i-1] = nulldesc;

    /*
     * Assign each argument value to a record element and dereference it.
     */
    for ( ; i > 0; i--) {
        rp->fields[i-1] = Arg(i);
        Deref(rp->fields[i-1]);
    }

    ArgType(0) = D_Record;
    Arg0.vword.bptr = (union block *)rp;
    EVValD(&Arg0, E_Rcreate);
    Return;
}

/*
 * limit - explicit limitation initialization.
 */


LibDcl(limit,2,BackSlash)
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

    if (!cnv:string(Arg0,Arg0))
        RunErr(103, &Arg0);

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

