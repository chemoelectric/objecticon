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
    {134, "odd number of parameters expected"},
    {135, "cannot transmit failure to this co-expression"},
    {136, "cannot set activator to a unactivated co-expression"},
    {137, "must specify activator for an unactivated co-expression"},
    {138, "cannot activate this co-expression"},
    {139, "cannot activate a co-expression that has caused a runtime error"},
    {140, "&handler co-expression cannot be an unactivated co-expression"},

#if Graphics
    {141, "program terminated by window manager"},
    {142, "attempt to read/write on closed window"},
    {143, "malformed event queue"},
    {144, "window system error"},
    {145, "bad window attribute"},
    {146, "incorrect number of arguments to drawing function"},
    {147, "window attribute cannot be read or written as requested"},
    {148, "invalid position or size"},
    {152, "attempt to read/write on closed data"},
    {153, "invalid pixel format"},
    {154, "paletted pixel format expected"},
#endif					/* Graphics */

    {159, "string too long"},
    {169, "insufficient arguments"},
    {170, "string or integer expected"},
    {171, "flag value expected"},
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
    {216, "attempt to cocopy &main"},
    {219, "already closed"},

    {302, "memory violation"},
    {303, "inadequate space for main co-expression"},
    {304, "inadequate space for qualifier list during garbage collection"},
    {305, "inadequate space for static allocation"},
    {306, "inadequate space for block pointer stack during garbage collection"},
    {309, "out of memory, allocation returned null"},
    {311, "invocation level too deep"},
    {313, "inadequate space for string region"},
    {314, "inadequate space for block region"},
    {315, "inadequate space for main program icode"},

    {500, "program malfunction"},		/* for use by runerr() */
    {600, "attempt to access instance field via class"},
    {601, "attempt to access static field via instance"},
    {602, "object expected"},
    {603, "class expected"},
    {605, "an abstract class is uninstantiable"},
    {606, "can only access instance method via a class from an instance method"},
    {607, "can only access instance method via a class which is an implemented class of self"},
    {608, "a private field can only be accessed from within the same class"},
    {609, "a protected instance field can only be accessed from an implemented class of the instance"},
    {610, "a protected static field can only be accessed from a subclass"},
    {611, "a package field can only be accessed from the same package"},
    {612, "unresolved deferred method"},
    {613, "methp expected"},
    {615, "procedure expected"},
    {616, "can only load a library from within a class"},
    {617, "can only load a library whilst the class is being initialized"},
    {620, "class or object expected"},
    {621, "init cannot be accessed via a field"},
    {622, "new cannot be accessed on an initialized object"},
    {624, "record, class or object expected"},
    {625, "record or constructor expected"},
    {627, "this method must be called from within a class"},
    {630, "weakref expected"},
    {631, "procedure or methp expected"},
    {632, "co-expression which is a program's &main expected"},
    {633, "given program not a child of this program"},
    {634, "class or constructor expected"},
    {635, "class, object, constructor or record expected"},
    {636, "invalid program monitoring sequence"},
    {637, "keyword expected"},
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
        if (v) {
            k_errorvalue = *v;
            have_errval = 1;
        } else {
            k_errorvalue = nulldesc;
            have_errval = 0;
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
    k_errorcoexpr = k_current;

    if (set_up) {
        if (is:null(kywd_handler)) {
            if (k_errornumber == -1) {
                fprintf(stderr, "\nRun-time error: %.*s\n", StrF(k_errortext));
                print_location(stderr, curr_pf);
            } else {
                fprintf(stderr, "\nRun-time error %d\n", k_errornumber);
                print_location(stderr, curr_pf);
                putstr(stderr, &k_errortext);
                fputc('\n', stderr);
            }
        }
        else {
            /* Clear the x* variables for the next error */
            xarg1 = xarg2 = xarg3 = xexpr = xargp = xfield = 0;
            /* Push the frame for the error handler and return to the interpreter loop */
            activate_handler();
            return;
        }
    }
    else {
        if (k_errornumber == -1)
            fprintf(stderr, "\nRun-time error in startup code: ");
        else
            fprintf(stderr, "\nRun-time error %d in startup code\n", n);
        putstr(stderr, &k_errortext);
        fputc('\n', stderr);
    }

    if (have_errval) {
        fprintf(stderr, "offending value: ");
        outimage(stderr, &k_errorvalue, 0);
        putc('\n', stderr);
    }

    if (curpstate->monitor &&
        Testb(E_Error, curpstate->eventmask->bits)) {
        traceback(k_current, 1, 1);
        add_to_prog_event_queue(&nulldesc, E_Error);
        curpstate->exited = 1;
        push_fatalerr_139_frame();
        return;
    }

    /* traceback() does a malloc, so checkfatalrecurse() is used to
     * avoid repeatedly looping (until a stack overflow) if we run out
     * of memory.
     */

    checkfatalrecurse();

    if (!set_up) {		/* skip if start-up problem */
        if (dodump > 1)
            abort();
        c_exit(EXIT_FAILURE);
    }
    if (!collecting)
        traceback(k_current, 1, 1);

    if (dodump > 1)
        abort();

    c_exit(EXIT_FAILURE);
}
