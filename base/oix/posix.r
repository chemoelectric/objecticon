/*
 * fxposix.ri - posix interface
 *
 * $Id: fxposix.ri,v 1.39 2005/07/20 18:01:31 rparlett Exp $
 */

/*
 * Copyright 1997-99 Shamim Mohamed.
 *
 * Modification and redistribution is permitted as long as this (and any
 * other) copyright notices are kept intact.
 */



#if MSWIN32
#define ftruncate _chsize
#define pclose _pclose
#define dup2 _dup2
#define execvp _execvp
#define fstat _fstat
#endif					/* MSWIN32 */

"kill() - send a signal to a process."

function{0,1} posix_System_kill(pid, signal)
   if !cnv:C_integer(pid) then
      runerr(101, pid)

   if !cnv:C_integer(signal) then
      runerr(101, signal)

   abstract {
      return null
      }
   body {
      
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (kill(pid, signal) != 0) {
	 errno2why();
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"trap() - trap a signal."

function{0,1} posix_System_trap(sig, handler)
   if !cnv:C_integer(sig) then
      runerr(101, sig)
   abstract {
      return proc
      }
   body { 
       tended char *signalname;
        
#if MSWIN32
       fail;
#else					/* MSWIN32 */
       if (is:null(handler))
           signal(sig, SIG_DFL);
       else if (is:proc(handler)) {
           struct b_proc *pp = (struct b_proc*)BlkLoc(handler);
           if (pp->nparam != 1 && pp->nparam != -1)
               runerr(172, handler);
           signal(sig, signal_dispatcher);
       }
       else
           runerr(106, handler);
       return register_sig(sig, handler);
#endif					/* MSWIN32 */
      }
end

"fork() - spawn a new identical process."

function{0,1} posix_System_fork()
   inline {
      int pid;
      
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if ((pid = fork()) < 0) {
	 errno2why();
	 fail;
	 }
#ifdef Graphics
      /* A child process can't interact with the graphics system */
      if (pid == 0)
        wdsplys = 0;
#endif
      return C_integer pid;
#endif					/* MSWIN32 */
      }
end

extern char **environ;

function{*} posix_System_environ()
  body {
    char **p = environ;
    while (*p) {
        cstr2string(*p, &result);
        suspend result;
        ++p;
    }
    fail;
  }
end

static char ** list2stringptrs(dptr l)
{
    char *data, *p, **a;
    tended union block *pb;
    int i, j, k, total;

    /*
     * Chain through each list block, making all elements strings
     * and counting the string array size required (total).
     */
    total = 0;
    for (pb = BlkLoc(*l)->list.listhead;
         pb && (BlkType(pb) == T_Lelem);
         pb = pb->lelem.listnext) {
        for (j = 0; j < pb->lelem.nused; j++) {
            k = pb->lelem.first + j;
            if (k >= pb->lelem.nslots)
                k -= pb->lelem.nslots;
            if (!cnv:string(pb->lelem.lslots[k], pb->lelem.lslots[k])) {
                ReturnErrVal(103, pb->lelem.lslots[k], 0);
            }
            total += StrLen(pb->lelem.lslots[k]) + 1;
        }
    }

    /*
     * Allocate the required memory for string and pointers, and go through
     * again filling the space.
     */
    MemProtect(a = malloc((BlkLoc(*l)->list.size + 1) * sizeof(char *)));
    if (total > 0) {
        MemProtect(data = malloc(total));
        p = data;
    }
    i = 0;
    for (pb = BlkLoc(*l)->list.listhead;
         pb && (BlkType(pb) == T_Lelem);
         pb = pb->lelem.listnext) {
        for (j = 0; j < pb->lelem.nused; j++) {
            k = pb->lelem.first + j;
            if (k >= pb->lelem.nslots)
                k -= pb->lelem.nslots;
          a[i++] = p;
          memcpy(p, StrLoc(pb->lelem.lslots[k]), StrLen(pb->lelem.lslots[k]));
          p += StrLen(pb->lelem.lslots[k]);
          *p++ = 0;
        }
    }
    if (i != BlkLoc(*l)->list.size)
        syserr("Inconsistent list/element size in list2stringptrs");
    a[i] = 0;
    return a;
}

function{0,1} posix_System_execve(f, argv, envp)
   if !cnv:C_string(f) then
      runerr(103, f)
   if !is:list(argv) then
      runerr(108, argv)
   if !is:null(envp) then {
      if !is:list(envp) then
         runerr(108, envp)
   }

   body {
      char **c_argv, **c_envp;
      if (BlkLoc(argv)->list.size < 1)
          runerr(176, argv);
      if (!(c_argv = list2stringptrs(&argv)))
          runerr(0);
      if (is:null(envp))
          c_envp = environ;
      else {
          if (!(c_envp = list2stringptrs(&envp))) {
              free(c_argv[0]);
              free(c_argv);
              runerr(0);
          }
      }
      if (execve(f, c_argv, c_envp) != 0) {
         free(c_argv[0]);
         free(c_argv);
         if (c_envp != environ) {
             free(c_envp[0]);
             free(c_envp);
         }
	 errno2why();
	 fail;
      }
      /* Not reached */
      return nulldesc;
   }
end



"wait() - wait for process to terminate or stop."
"the return value is `status' from the wait(2) manpage."

function{0,1} posix_System_wait(pid, options)
   if !def:C_integer(pid, -1) then
      runerr(101, pid)
   if !def:C_integer(options, 0) then 
      runerr(103, options)
   abstract {
      return string;
      }
   body {
      char retval[64];
      int status = 0, wpid, i=0;
#if !MSWIN32
#if defined(BSD) || defined(Linux) || defined(BSD_4_4_LITE)
      struct rusage rusage;
      if ((wpid = wait4(pid, &status, options, &rusage)) < 0) {
	 errno2why();
	 fail;
      }

#else					/* BSD || Linux */

      /* HP and Solaris */
      if (pid == -1) {
	 
	 if ((wpid = wait(&status)) < 0) {
	    errno2why();
	    fail;
	 }
      } else {
	 if ((wpid = waitpid(pid, &status, options)) < 0) {
	    errno2why();
	    fail;
	 }
      }
#endif					/* BSD || Linux */

      /* Unpack all the fields */
      if (WIFSTOPPED(status))
          sprintf(retval, "%d stopped:%d", wpid, WSTOPSIG(status));

      else if (WIFSIGNALED(status))
          sprintf(retval, "%d terminated:%d", wpid, WTERMSIG(status));

      else if (WIFEXITED(status))
	 sprintf(retval, "%d exited:%d", wpid, WEXITSTATUS(status));
      else
	 sprintf(retval, "???");
#ifdef Linux
      if (WIFSIGNALED(status) && status & 0200 )	/* core dump */
#else
#if defined(BSD) && defined(SUN)
      if (WIFSIGNALED(status) && ((union __wait*)&status)->w_T.w_Coredump)
#else
      if (WIFSIGNALED(status) && WCOREDUMP(status))
#endif
#endif
	 strcat(retval, ":core");

#else					/* MSWIN32 */
      int termstat;
      if ((wpid = _cwait(&termstat, pid, options)) < 0) {
	 errno2why();
	 fail;
	 }
      sprintf(retval, "%d terminated:%d", wpid, termstat);
#endif					/* MSWIN32 */

      cstr2string(retval, &result);
      return result;
   }
end


function{0,1} util_Time_get_system_seconds()
   body {
      struct timeval tp;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      return C_integer tp.tv_sec;
   }
end

function{0,1} util_Time_get_system_millis()
   body {
      struct timeval tp;
      struct descrip ls, lm, thousand;
      tended struct descrip lt1, lt2;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      MakeInt(tp.tv_sec, &ls);
      MakeInt(tp.tv_usec, &lm);
      MakeInt(1000, &thousand);
      if (bigmul(&ls, &thousand, &lt1) == Error ||
          bigdiv(&lm, &thousand ,&lt2) == Error ||
          bigadd(&lt1, &lt2, &result) == Error)
          runerr(0);
      return result;
   }
end


function{0,1} util_Time_get_system_micros()
   body {
      struct timeval tp;
      struct descrip ls, lm, million;
      tended struct descrip lt1;
      if (gettimeofday(&tp, 0) < 0) {
	 errno2why();
	 fail;
      }
      MakeInt(tp.tv_sec, &ls);
      MakeInt(tp.tv_usec, &lm);
      MakeInt(1000000, &million);
      if (bigmul(&ls, &million, &lt1) == Error ||
          bigadd(&lt1, &lm, &result) == Error)
          runerr(0);
      return result;
   }
end

function{0, 1} posix_System_unsetenv(name)
   if !cnv:C_string(name) then
      runerr(103, name)
   body {
       if (unsetenv(name) < 0) {
	 errno2why();
	 fail;
       }
       return nulldesc;
   }
end

"setenv() - set an environment variable."

function{0, 1} posix_System_setenv(name, value)
   if !cnv:C_string(name) then
      runerr(103, name)
   if !cnv:C_string(value) then
      runerr(103, value)
   body {
#if MSWIN32
      if (!SetEnvironmentVariable(name, value))
         fail;
#else
      if (setenv(name, value, 1) < 0) {
	 errno2why();
         fail;
      }
#endif
      return nulldesc;
   }
end




"getenv(s) - return contents of environment variable s."

function{0,1} posix_System_getenv(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      char *p;
      if ((p = getenv(s)) != NULL) {	/* get environment variable */
          cstr2string(p, &result);
          return result;
      }
      else 				/* fail if not in environment */
	 fail;

   }
end

