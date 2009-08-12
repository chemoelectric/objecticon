/*
 * errmsg.r -- err_msg, irunerr, drunerr
 */

/*
 * Run-time error numbers and text.
 */
struct errtab {
    int err_no;			/* error number */
    char *errmsg;		/* error message */
};

/*
 * Run-time error numbers and text.
 */
struct errtab errtab[] = {
    {101, "integer expected or out of range"},
    {102, "numeric expected"},
    {103, "string expected"},
    {104, "cset expected"},
    {105, "file expected"},
    {106, "procedure or other invocable expected"},
    {107, "record expected"},
    {108, "list expected"},
    {109, "string or file expected"},
    {110, "string or list expected"},
    {111, "variable expected"},
    {112, "invalid type to size operation"},
    {113, "invalid type to random operation"},
    {114, "invalid type to subscript operation"},
    {115, "structure expected"},
    {116, "invalid type to element generator"},
    {117, "missing main procedure"},
    {118, "co-expression expected"},
    {119, "set expected"},
    {120, "two csets or two sets expected"},
    {121, "function not supported"},
    {122, "set, list or table expected"},
    {123, "invalid type"},
    {124, "table expected"},
    {125, "list, record, or set expected"},
    {126, "list or record expected"},
    {127, "list or table expected"},
    {128, "ucs expected"},
    {129, "string or ucs expected"},
    {130, "even number of parameters expected"},
    {131, "invalid type to section operation"},
    {132, "cset, string or ucs expected"},
    {133, "set or table expected"},

#ifdef Graphics
    {140, "window expected"},
    {141, "program terminated by window manager"},
    {142, "attempt to read/write on closed window"},
    {143, "malformed event queue"},
    {144, "window system error"},
    {145, "bad window attribute"},
    {146, "incorrect number of arguments to drawing function"},
    {147, "window attribute cannot be read or written as requested"},
    {148, "selection proc returned wrong type"},
#endif					/* Graphics */

    {170, "string or integer expected"},
    {176, "exec requires at least one argument for the program"},

    {201, "division by zero"},
    {202, "remaindering by zero"},
    {203, "integer overflow"},
    {204, "real overflow, underflow, or division by zero"},
    {205, "invalid value"},
    {206, "negative first argument to real exponentiation"},
    {207, "invalid field name"},
    {208, "second and third arguments to map of unequal length"},
    {210, "non-ascending arguments to detab/entab"},
    {211, "by value equal to zero"},
    {215, "attempt to refresh &main"},
    {219, "already closed"},

    {302, "memory violation"},
    {303, "inadequate space for evaluation stack"},
    {304, "inadequate space for qualifier list during garbage collection"},
    {305, "inadequate space for static allocation"},
    {306, "inadequate space in string region"},
    {307, "inadequate space in block region"},
    {308, "system stack overflow in co-expression"},
    {309, "out of memory, allocation returned null"},
    {310, "inadequate co-expression C stack space during garbage collection"},
    {311, "main stack overflow"},
    {312, "stack overflow in co-expression"},
    {313, "inadequate space for string region"},
    {314, "inadequate space for block region"},
    {315, "inadequate space for main program icode"},

    {401, "co-expressions not implemented"},
    {402, "program not compiled with debugging option"},

    {500, "program malfunction"},		/* for use by runerr() */
    {600, "attempt to access instance field via class"},
    {601, "attempt to access static field via instance"},
    {602, "object expected"},
    {603, "class expected"},
    {604, "cannot cast to a class which is not a superclass of object"},
    {608, "a private field can only be accessed from within the same class"},
    {609, "a protected instance field can only be accessed from within an implemented class of the instance"},
    {610, "a protected static field can only be accessed if it is within an implemented class of the caller"},
    {611, "a package field can only be accessed from within the same package"},
    {612, "unresolved deferred method"},
    {613, "methp expected"},
    {614, "cast expected"},
    {615, "procedure expected"},
    {616, "can only set a method from within the defining class"},
    {617, "the given field is not a method"},
    {618, "the given procedure is a method"},
    {619, "class or object expected"},
    {620, "class, cast or object expected"},
    {621, "init cannot be accessed via a field"},
    {622, "new cannot be accessed on an initialized object"},
    {623, "can only set a method on an unresolved field"},
    {624, "record, class, cast or object expected"},
    {625, "record or constructor expected"},
    {628, "attempt to access non-method via a cast"},
    {631, "procedure or methp expected"},
    {632, "co-expression which is a program's &main expected"},
   };


static int lookup_err_msg_compare(int *key, struct errtab *item)
{
    return *key - item->err_no;
}

char *lookup_err_msg(int n)
{
    struct errtab *p = bsearch(&n, errtab, ElemCount(errtab), 
                               sizeof(struct errtab), 
                               (BSearchFncCast)lookup_err_msg_compare);
    if (p)
        return p->errmsg;
    else
        return 0;
}

/*
 * err_msg - print run-time error message, performing trace back if required.
 *  This function underlies the rtt runerr() construct.
 */
void err_msg(int n, dptr v)
{
    char *em;

    if (n == 0) {
        k_errornumber = t_errornumber;
        /* Allow v to override the t_ settings */
        if (v) {
            k_errorvalue = *v;
            have_errval = 1;
        } else {
            k_errorvalue = t_errorvalue;
            have_errval = t_have_val;
        }
    }
    else {
        k_errornumber = n;
        if (v == NULL) {
            k_errorvalue = nulldesc;
            have_errval = 0;
        }
        else {
            k_errorvalue = *v;
            have_errval = 1;
        }
    }
    if (k_errornumber == -1)
        k_errortext = t_errortext;
    else {
        em = lookup_err_msg(k_errornumber);
        if (em)
            CMakeStr(em, &k_errortext);
        else
            k_errortext = emptystr;
    }

    EVVal((word)k_errornumber,E_Error);

    if (pfp != NULL) {
        if (IntVal(kywd_err) == 0) {
            char *s = StrLoc(k_errortext);
            int i = StrLen(k_errortext);
            dptr fn;
            if (k_errornumber == -1) {
                fprintf(stderr, "\nRun-time error: ");
                while (i-- > 0)
                    fputc(*s++, stderr);
                fputc('\n', stderr);
                fn = findfile(ipc);
                if (fn) {
                    struct descrip t;
                    abbr_fname(fn, &t);
                    fprintf(stderr, "File %.*s; Line %d\n", (int)StrLen(t), StrLoc(t), findline(ipc));
                } else
                    fprintf(stderr, "File ?; Line %d\n", findline(ipc));
            } else {
                fprintf(stderr, "\nRun-time error %d\n", k_errornumber);
                fn = findfile(ipc);
                if (fn) {
                    struct descrip t;
                    abbr_fname(fn, &t);
                    fprintf(stderr, "File %.*s; Line %d\n", (int)StrLen(t), StrLoc(t), findline(ipc));
                } else
                    fprintf(stderr, "File ?; Line %d\n", findline(ipc));
                while (i-- > 0)
                    fputc(*s++, stderr);
                fputc('\n', stderr);
            }
        }
        else {
            IntVal(kywd_err)--;
            return;
        }
    }
    else {
        char *s = StrLoc(k_errortext);
        int i = StrLen(k_errortext);
        if (k_errornumber == -1)
            fprintf(stderr, "\nRun-time error in startup code: ");
        else
            fprintf(stderr, "\nRun-time error %d in startup code\n", n);
        while (i-- > 0)
            fputc(*s++, stderr);
        fputc('\n', stderr);
    }

    if (have_errval) {
        fprintf(stderr, "offending value: ");
        outimage(stderr, &k_errorvalue, 0);
        putc('\n', stderr);
    }

    if (pfp == NULL) {		/* skip if start-up problem */
        if (dodump > 1)
            abort();
        c_exit(EXIT_FAILURE);
    }
    if (!collecting) {
        fprintf(stderr, "Traceback:\n");
        tracebk(pfp, argp);
        fflush(stderr);
    }

    if (dodump > 1)
        abort();

    c_exit(EXIT_FAILURE);
}

/*
 * irunerr - print an error message when the offending value is a C_integer
 *  rather than a descriptor.
 */
void irunerr(n, v)
    int n;
    C_integer v;
{
    t_errornumber = n;
    IntVal(t_errorvalue) = v;
    t_errorvalue.dword = D_Integer;
    t_have_val = 1;
    err_msg(0,NULL);
}

/*
 * drunerr - print an error message when the offending value is a C double
 *  rather than a descriptor.
 */
void drunerr(n, v)
    int n;
    double v;
{
    union block *bp;

    MemProtect(bp = (union block *)alcreal(v));
    t_errornumber = n;
    BlkLoc(t_errorvalue) = bp;
    t_errorvalue.dword = D_Real;
    t_have_val = 1;
    err_msg(0,NULL);
}
