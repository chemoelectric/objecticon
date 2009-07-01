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

static int inited = 0;		/* has first-time initialization been done? */

/*
 * Define a "context" struct to hold the thread information we need.
 */
typedef struct {
    pthread_t thread;	/* thread ID (thread handle) */
    pthread_mutex_t mutex;
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
    fprintf(stderr, "pthreads coexpression switch: Unexpected problem: %s; program will abort\n", s);
    perror("perror reports");
    err_msg(1001, 0);
}

static void my_lock(pthread_mutex_t *c)
{
    if (pthread_mutex_lock(c) != 0)
        aborted("my_lock failed");
}

static void my_unlock(pthread_mutex_t *c)
{
    if (pthread_mutex_unlock(c) != 0)
        aborted("my_unlock failed");
}

static void create_lock(pthread_mutex_t *c)
{
    if (pthread_mutex_init(c, NULL) != 0)
        aborted("pthread_mutext_init failed");
    my_lock(c);
}


/*
 * coswitch(old, new, first) -- switch contexts.
 */
void coswitch(word *o, word *n, int first) 
{

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
        create_lock(&oldc->mutex);
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
        create_lock(&newc->mutex);
        pthread_attr_init(&attr);
#ifdef UpStack
        if (pthread_attr_setstack(&attr, (void *)n[0], PTHREAD_STACK_MIN) != 0)
            aborted("pthread_attr_setstack failed");
#else
        if (pthread_attr_setstack(&attr, (void *)n[0] - PTHREAD_STACK_MIN, PTHREAD_STACK_MIN) != 0)
            aborted("pthread_attr_setstack failed");
#endif
        pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_JOINABLE);
        if (pthread_create(&newc->thread, &attr, nctramp, newc) != 0) 
            aborted("cannot create thread");
        newc->alive = 1;
    }

    my_unlock(&newc->mutex);			/* unblock the new thread */
    my_lock(&oldc->mutex);			/* block this thread */
    
    if (!oldc->alive)		
        pthread_exit(NULL);		/* if unblocked because unwanted */
            				/* else return to continue running */
}

/*
 * coclean(old) -- clean up co-expression state before freeing.
 */
void coclean(void *o) {
    cstate ocs = o;			/* old cstate pointer */
    context *oldc = ocs[1];		/* old context pointer */
    if (oldc == NULL)			/* if never initialized, do nothing */
        return;
    oldc->alive = 0;			/* signal thread to exit */
    my_unlock(&oldc->mutex);			/* unblock it */
    pthread_join(oldc->thread, NULL);	/* wait for thread to exit */
    pthread_mutex_destroy(&oldc->mutex);		/* destroy associated semaphore */
    free(oldc);				/* free context block */
}

/*
 * nctramp() -- trampoline for calling new_context().
 */
static void *nctramp(void *arg) {
    context *newc = arg;			/* new context pointer */
    my_lock(&newc->mutex);
    new_context();			/* call new_context; will not return */
    syserr("new_context returned to nctramp");
    return NULL;
}
