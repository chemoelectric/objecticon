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
    {101, "Integer expected or out of range"},
    {102, "Numeric expected or out of range"},
    {103, "String expected"},
    {104, "Cset expected"},
    {105, "File expected"},
    {106, "Procedure or other invocable expected"},
    {107, "Record expected"},
    {108, "List expected"},
    {109, "String or file expected"},
    {110, "String or list expected"},
    {111, "Variable expected"},
    {112, "Invalid type to size operation"},
    {113, "Invalid type to random operation"},
    {114, "Invalid type to subscript operation"},
    {115, "Structure expected"},
    {116, "Invalid type to element generator"},
    {117, "Missing main procedure"},
    {118, "Co-expression expected"},
    {119, "Set expected"},
    {120, "Two csets or two sets expected"},
    {121, "Function not supported"},
    {122, "Set, list or table expected"},
    {123, "Invalid type"},
    {124, "Table expected"},
    {125, "List, record, or set expected"},
    {126, "List or record expected"},
    {127, "List or table expected"},
    {128, "Ucs expected"},
    {129, "String or ucs expected"},
    {130, "Even number of parameters expected"},
    {131, "Invalid type to section operation"},
    {132, "Cset, string or ucs expected"},
    {133, "Set or table expected"},
    {134, "Odd number of parameters expected"},
    {135, "Cannot transmit failure to this co-expression"},
    {136, "Cannot set activator to a unactivated co-expression"},
    {137, "Must specify activator for an unactivated co-expression"},
    {138, "Cannot activate this co-expression"},
    {139, "Cannot activate a co-expression that has caused a runtime error or called exit()"},
    {140, "&handler co-expression cannot be an unactivated co-expression"},

#if Graphics
    {141, "Program terminated by window manager"},
    {142, "Attempt to read/write on closed window"},
    {143, "Malformed event queue"},
    {144, "Window system error"},
    {145, "Bad window attribute"},
    {146, "Incorrect number of arguments to drawing function"},
    {147, "Window attribute cannot be read or written as requested"},
    {148, "Invalid position or size"},
    {152, "Attempt to read/write on closed data"},
    {153, "Invalid pixel format"},
    {154, "Paletted pixel format expected"},
    {155, "Hold or restore called out of sequence"},
#endif					/* Graphics */

    {169, "Insufficient arguments"},
    {170, "String or integer expected"},
    {171, "Flag value expected"},
    {176, "exec() requires at least one argument for the program"},
    {177, "Even number of elements expected"},
    {178, "Odd number of elements expected"},
    {179, "List or set expected"},

    {201, "Division by zero"},
    {202, "Remaindering by zero"},
    {203, "Integer overflow"},
    {204, "Real overflow"},
    {205, "Invalid value"},
    {206, "Negative first argument to real exponentiation"},
    {207, "Invalid field name"},
    {208, "Second and third arguments to map of unequal length"},
    {209, "Zero raised to a negative exponent"},
    {210, "Non-ascending arguments to detab/entab"},
    {211, "By value equal to zero"},
    {215, "Attempt to refresh &main"},
    {216, "Attempt to cocopy &main"},
    {219, "Already closed"},

    {302, "Memory violation"},
    {303, "Inadequate space for main co-expression"},
    {304, "Inadequate space for qualifier list during garbage collection"},
    {305, "Inadequate space for static allocation"},
    {306, "Inadequate space for block pointer stack during garbage collection"},
    {309, "Out of memory, allocation returned null"},
    {311, "Invocation level too deep"},
    {313, "Inadequate space for string region"},
    {314, "Inadequate space for block region"},
    {315, "Inadequate space for main program icode"},

    {500, "Program malfunction"},		/* for use by runerr() */
    {600, "Attempt to access instance field via class"},
    {601, "Attempt to access static field via instance"},
    {602, "Object expected"},
    {603, "Class expected"},
    {605, "An abstract class is uninstantiable"},
    {606, "Can only access an instance method via a class from an instance method"},
    {607, "Can only access an instance method via a class when the method is in an implemented class of self"},
    {608, "A private field can only be accessed from within the same class"},
    {609, "A protected instance field can only be accessed from an implemented class of the instance"},
    {610, "A protected static field can only be accessed from a subclass"},
    {611, "A package field can only be accessed from the same package"},
    {612, "Optional method invoked"},
    {613, "Methp expected"},
    {614, "Abstract method invoked"},
    {615, "Procedure expected"},
    {616, "Can only load a library from within a class"},
    {617, "Can only load a library whilst the class is being initialized"},
    {620, "Class or object expected"},
    {621, "init cannot be accessed via a field"},
    {622, "new cannot be accessed on an initialized object"},
    {624, "Record, class or object expected"},
    {625, "Record or constructor expected"},
    {627, "This method must be called from within a class"},
    {628, "Method removed by translator"},
    {629, "Unresolved native method"},
    {630, "Weakref expected"},
    {631, "Procedure, methp or 2-element list expected"},
    {632, "Co-expression which is a program's &main expected"},
    {633, "Given program not a child of this program"},
    {634, "Class or constructor expected"},
    {635, "Class, object, constructor or record expected"},
    {636, "Invalid program monitoring sequence"},
    {637, "Keyword expected"},
    {638, "List not convertible to class method"},
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
        fprintf(stderr, "Offending value: ");
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
