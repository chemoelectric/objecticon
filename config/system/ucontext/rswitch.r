#passthru #include <ucontext.h>

static int inited = 0;		/* has first-time initialization been done? */

static void aborted(char *s) {
    ffatalerr("ucontext coexpression switch: %s; program will abort\n"
              "errnum=%d (%s)\n", s, errno, strerror(errno));
}

/*
 * coswitch(old, new, first) -- switch contexts.
 */
void coswitch(word *o, word *n, int first) 
{
    ucontext_t *oldc, *newc;			/* old and new context pointers */
    int dummy;

    if (inited)				/* if not first call */
        oldc = (ucontext_t *)o[1];			/* load current context pointer */
    else {
        /*
         * This is the first coswitch() call.
         * Allocate and initialize the context struct for &main.
         */
        MemProtect(oldc = malloc(sizeof(ucontext_t)));
        o[1] = (word)oldc;     /* Save in state */
        inited = 1;
    }

    /* Keep an estimate of the C stack position in cstate[0] (see Prog.get_stack) */
    o[0] = (word)&dummy;

    if (first != 0)			/* if not first call for this cstate */
        newc = (ucontext_t *)n[1];			/* load new context pointer */
    else {
        word midstack;
        /*
         * This is a newly allocated cstate array.
         * Allocate and initialize a context struct.
         */
        MemProtect(newc = malloc(sizeof(ucontext_t)));
        n[1] = (word)newc;
        if (getcontext(newc) != 0)
            aborted("getcontext failed");

        /*
         * The newly allocated stack goes from sp (low address) to n[0] (ie cstate[0],
         * high address).  We give the top half to the C stack, leaving the bottom
         * half for icon.
         */
        midstack = StackAlign((char *)sp + DiffPtrsBytes(n[0], sp) / 2);

        newc->uc_stack.ss_sp = (char *)midstack;
        newc->uc_stack.ss_size = DiffPtrsBytes(n[0], midstack);
        newc->uc_link = 0;
        
        makecontext(newc, new_context, 0);
    }

    if (swapcontext(oldc, newc) != 0)
        aborted("swapcontext failed");
}

/*
 * coclean(old) -- clean up co-expression state before freeing.
 */
void coclean(word *o) 
{
    ucontext_t *oldc = (ucontext_t *)o[1];		/* old context pointer */
    if (oldc)			/* if never initialized, do nothing */
        free(oldc);				/* free context block */
}
