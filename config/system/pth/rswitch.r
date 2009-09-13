#passthru #include <pth.h>

static void aborted(char *s) {
    ffatalerr("GNU pth coexpression switch: %s; program will abort\n"
              "errnum=%d (%s)\n", s, errno, strerror(errno));
}

static void nctramp(void *arg);

/*
 * coswitch(old, new, first) -- switch contexts.
 */
void coswitch(word *o, word *n, int first) 
{
    static int inited = 0;		/* has first-time initialization been done? */
    pth_uctx_t oldc, newc;		/* old and new context pointers */
    int dummy;

    if (inited)				/* if not first call */
        oldc = (pth_uctx_t)o[1];	/* load current context pointer */
    else {
        /*
         * This is the first coswitch() call.
         * Allocate and initialize the context struct for &main.
         */
        if (!pth_uctx_create(&oldc))
            aborted("pth_uctx_create failed");
        o[1] = (word)oldc;     /* Save in state */
        inited = 1;
    }

    /* Keep an estimate of the C stack position in cstate[0] (see Prog.get_stack) */
    o[0] = (word)&dummy;

    if (first != 0)			/* if not first call for this cstate */
        newc = (pth_uctx_t)n[1];	/* load new context pointer */
    else {
        word midstack;
        /*
         * This is a newly allocated cstate array.
         * Allocate and initialize a context struct.
         */
        if (!pth_uctx_create(&newc))
            aborted("pth_uctx_create failed");
        n[1] = (word)newc;

        /*
         * The newly allocated stack goes from sp (low address) to n[0] (ie cstate[0],
         * high address).  We give the top half to the C stack, leaving the bottom
         * half for icon.
         */
        midstack = StackAlign((char *)sp + DiffPtrsBytes(n[0], sp) / 2);

        if (!pth_uctx_make(newc, 
                           (char *)midstack,
                           DiffPtrsBytes(n[0], midstack),
                           NULL, 
                           nctramp, 
                           NULL,
                           NULL))
            aborted("pth_uctx_make failed");
    }

    if (!pth_uctx_switch(oldc, newc))
        aborted("pth_uctx_switch failed");
}

/*
 * coclean(old) -- clean up co-expression state before freeing.
 */
void coclean(word *o) 
{
    pth_uctx_t oldc = (pth_uctx_t)o[1];		/* old context pointer */
    if (oldc)			                /* if never initialized, do nothing */
        pth_uctx_destroy(oldc);			/* free context block */
}

/*
 * nctramp() -- trampoline for calling new_context().
 */
static void nctramp(void *arg) 
{
    new_context();			/* call new_context; will not return */
    syserr("new_context returned to nctramp");
}
