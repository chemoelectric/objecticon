/*
 * pthreads.c -- Icon context switch code using POSIX threads 
 *
 * This code implements co-expression context switching on any system
 * that provides POSIX threads. It is typically much slower when
 * called than platform-specific custom code, but of course it is much
 * more portable, and it is typically used infrequently.
 *
 */

#passthru #include <pthread.h>
#passthru #include <semaphore.h>

/*
 * Define a "context" struct to hold the thread information we need.
 */
typedef struct {
    pthread_t thread;	/* thread ID (thread handle) */
    sem_t sema;          /* synchronization semaphore (if unnamed) */
    int alive;		/* set zero when thread is to die */
} context;

static void *nctramp(void *arg);

/*
 * Treat an Icon "cstate" array as an array of context pointers.
 * cstate[0] is used by Icon code that thinks it's setting a stack pointer.
 * We use cstate[1] to point to the actual context struct.
 * (Both of these are initialized to NULL by Icon 9.4.1 or later.)
 */
typedef context **cstate;

static void aborted(char *s) {
    ffatalerr("pthreads coexpression switch: %s; program will abort\n"
              "errnum=%d (%s)\n", s, errno, strerror(errno));
}

/*
 * makesem(ctx) -- initialize semaphore in context struct.
 */
static void makesem(context *ctx) {
    if (sem_init(&ctx->sema, 0, 0) == -1)
        aborted("cannot init semaphore");
}

static int sem_wait_ex(sem_t *c)
{
    int i;

    do {
        i = sem_wait(c);
    } while (i == -1 && errno == EINTR);

    return i;
}

/*
 * coswitch(old, new, first) -- switch contexts.
 */
void coswitch(word *o, word *n, int first) 
{
    static int inited = 0;		/* has first-time initialization been done? */
    cstate ocs = (cstate)o;			/* old cstate pointer */
    cstate ncs = (cstate)n;			/* new cstate pointer */
    context *oldc, *newc;			/* old and new context pointers */

    if (inited)				/* if not first call */
        oldc = ocs[1];			/* load current context pointer */
    else {
        /*
         * This is the first coswitch() call.
         * Allocate and initialize the context struct for &main.
         */
        MemProtect(oldc = ocs[1] = malloc(sizeof(context)));
        makesem(oldc);
        oldc->thread = pthread_self();
        oldc->alive = 1;
        inited = 1;
    }

    if (first != 0)			/* if not first call for this cstate */
        newc = ncs[1];			/* load new context pointer */
    else {
        pthread_attr_t attr;
        /*
         * This is a newly allocated cstate array.
         * Allocate and initialize a context struct.
         */
        MemProtect(newc = ncs[1] = malloc(sizeof(context)));
        makesem(newc);
        pthread_attr_init(&attr);
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
        if ((errno = pthread_create(&newc->thread, &attr, nctramp, newc)) != 0) 
            aborted("cannot create thread");
        newc->alive = 1;
    }

    if (sem_post(&newc->sema) == -1)                      /* unblock the new thread */
        aborted("sem_post in coswitch failed");

    if (sem_wait_ex(&oldc->sema) == -1)                    /* block this thread */
        aborted("sem_wait_ex in coswitch failed");
    
    if (!oldc->alive)		
        pthread_exit(NULL);		/* if unblocked because unwanted */
            				/* else return to continue running */
}

/*
 * coclean(old) -- clean up co-expression state before freeing.
 */
void coclean(word *o) {
    cstate ocs = (cstate)o;			/* old cstate pointer */
    context *oldc = ocs[1];		/* old context pointer */
    if (oldc == NULL)			/* if never initialized, do nothing */
        return;
    oldc->alive = 0;			/* signal thread to exit */
    if (sem_post(&oldc->sema) == -1)                      /* unblock it */
        aborted("sem_post in coclean failed");

    if ((errno = pthread_join(oldc->thread, NULL)) != 0)  /* wait for thread to exit */
        aborted("pthread_join failed");

    if (sem_destroy(&oldc->sema) == -1)           /* destroy associated semaphore */
        aborted("sem_destroy in coclean failed");

    free(oldc);				/* free context block */
}

/*
 * nctramp() -- trampoline for calling new_context().
 */
static void *nctramp(void *arg) {
    context *newc = arg;			/* new context pointer */
    if (sem_wait_ex(&newc->sema) == -1)                    /* wait for signal */
        aborted("sem_wait_ex in nctramp failed");
    new_context();			/* call new_context; will not return */
    syserr("new_context returned to nctramp");
    return NULL;
}
