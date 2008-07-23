/*
 * File: fload.r
 *  Contents: loadfunc.
 *
 *  This file contains loadfunc(), the dynamic loading function for
 *  Unix systems having the <dlfcn.h> interface.
 *
 *  from Icon:
 *     p := loadfunc(filename, funcname)
 *     p(arg1, arg2, ...)
 *
 *  in C:
 *     int func(int argc, dptr argv)
 *        return -1 for failure, 0 for success, >0 for error
 *        argc is number of true args not including argv[0]
 *        argv[0] is for return value; others are true args
 */

#ifdef HAVE_LIBDL

#ifndef RTLD_LAZY	/* normally from <dlfcn.h> */
#define RTLD_LAZY 1
#endif					/* RTLD_LAZY */

#if MSWIN32
void *dlopen(char *name, int flag)
{ /* LoadLibrary */
    return (void *)LoadLibrary(name);
}
void *dlsym(void *handle, char *sym)
{
    return (void *)GetProcAddress((HMODULE)handle, sym);
}
int dlclose(void *handle)
{ /* FreeLibrary */
    return FreeLibrary((HMODULE)handle);
}

char *dlerror(void)
{
    return "undiagnosed dynamic load error";
}
#endif					/* MSWIN32 */

#ifdef FreeBSD
/*
 * If DL_GETERRNO exists, this is an FreeBSD 1.1.5 or 2.0 
 * which lacks dlerror(); supply a substitute.
 */
#passthru #ifdef DL_GETERRNO
char *dlerror(void)
{
    int no;
   
    if (0 == dlctl(NULL, DL_GETERRNO, &no))
        return(strerror(no));
    else
        return(NULL);
}
#passthru #endif
#endif					/* __FreeBSD__ */

"loadfunc(filename,funcname) - load C function dynamically."

function{0,1} loadfunc(filename,funcname)

    if !cnv:C_string(filename) then
        runerr(103, filename)
    if !cnv:C_string(funcname) then
        runerr(103, funcname)

abstract {
    return proc
}
body
{
    int (*func)() = 0;
    struct b_proc *blk;
    static char *curfile;
    static void *handle;
    char *tname;
   
    /*
     * Get a library handle, reusing it over successive calls.
     */
    if (!handle || !curfile || strcmp(filename, curfile) != 0) {
        if (curfile)
            free((pointer)curfile);	/* free the old file name */
        curfile = salloc(filename);	/* save the new name */
        handle = dlopen(filename, RTLD_LAZY);	/* get the handle */
    }
    /*
     * Load the function.  Diagnose both library and function errors here.
     */
    if (handle) {
        Protect(tname = malloc(strlen(funcname) + 3), runerr(0));
        sprintf(tname, "Z%s", funcname);
        func = (int (*)())dlsym(handle, tname);
        if (!func) {
            /*
             * If no function, try again by prepending an underscore.
             * (for OpenBSD and similar systems.)
             */
            sprintf(tname, "_Z%s", funcname);
            func = (int (*)())dlsym(handle, tname);
        }
        sprintf(tname, "B%s", funcname);
        blk = (struct b_proc *)dlsym(handle, tname);
        if (!blk) {
            sprintf(tname, "_B%s", funcname);
            func = (int (*)())dlsym(handle, tname);
        }
    }
    if (!handle || !func || !blk) {
        fprintf(stderr, "\nloadfunc(\"%s\",\"%s\"): %s\n",
                filename, funcname, dlerror());
        runerr(216);
    }
    free(tname);
    return proc(blk);
}
end

#else						/* HAVE_LIBDL */
"loadfunc(filename,funcname) - load C function dynamically."
function{0,1} loadfunc(filename,funcname)
   runerr(121)
end
#endif						/* HAVE_LIBDL */
