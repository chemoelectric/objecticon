/*
 * File: fload.r
 *  Contents: loadfunc.
 *
 *  This file contains Proc.load(), the dynamic loading function for
 *  Unix systems having the <dlfcn.h> interface.
 * 
 *     p := Proc.load(filename, funcname)
 *     p(arg1, arg2, ...)
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

function{0,1} lang_Proc_load(filename,funcname)
    if !cnv:C_string(filename) then
        runerr(103, filename)
    if !cnv:C_string(funcname) then
        runerr(103, funcname)
    body {
       struct b_proc *blk;
       static char *curfile;
       static void *handle;
       char *tname;
   
       /*
        * Get a library handle, reusing it over successive calls.
        */
       if (!handle || !curfile || strcmp(filename, curfile) != 0) {
           if (curfile)
               free(curfile);	/* free the old file name */
           curfile = salloc(filename);	/* save the new name */
           handle = dlopen(filename, RTLD_LAZY);	/* get the handle */
       }
       if (!handle) {
           why(dlerror());
           fail;
       }
       /*
        * Load the function.  Diagnose both library and function errors here.
        */
       MemProtect(tname = malloc(strlen(funcname) + 3));
       sprintf(tname, "B%s", funcname);
       blk = (struct b_proc *)dlsym(handle, tname);
       if (!blk) {
           sprintf(tname, "_B%s", funcname);
           blk = (struct b_proc *)dlsym(handle, tname);
       }
       if (!blk) {
           free(tname);
           whyf("Symbol '%s' not found in library", funcname);
           fail;
       }
       /* Sanity check. */
       if (blk->title != T_Proc) {
           fprintf(stderr, "\nloadfunc(\"%s\",\"%s\"): Loaded block didn't have D_Proc in its dword\n",
                   filename, funcname);
           fatalerr(218, NULL);
       }

       free(tname);
       return proc(blk);
    }
end

#else						/* HAVE_LIBDL */
function{0,1} lang_Proc_load(filename,funcname)
   runerr(121)
end
#endif						/* HAVE_LIBDL */
