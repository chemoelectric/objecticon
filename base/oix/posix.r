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
int gettimeofday(struct timeval *tv, struct timezone *tz)
{
    struct _timeb wtp;
    _ftime( &wtp );
    tv->tv_sec = wtp.time;
    tv->tv_usec = wtp.millitm * 1000;
    return 0;
}
#endif


"kill() - send a signal to a process."

function posix_System_kill(pid, signal)
   if !cnv:C_integer(pid) then
      runerr(101, pid)

   if !cnv:C_integer(signal) then
      runerr(101, signal)

   body {
#if UNIX
      if (kill(pid, signal) != 0) {
	 errno2why();
	 fail;
	 }
      return nulldesc;
#else
     Unsupported;
#endif
      }
end

#ifdef PLAN9
"fork() - spawn a new identical process."

function posix_System_fork(flag)
   if !def:C_integer(flag, RFFDG|RFREND|RFPROC) then
      runerr(101, flag)
   body {
      int pid;
      
      if ((pid = rfork(flag)) < 0) {
	 errno2why();
	 fail;
      }
      return C_integer pid;
   }
end

#else
"fork() - spawn a new identical process."

function posix_System_fork()
   body {
#if UNIX
      int pid;
      if ((pid = fork()) < 0) {
	 errno2why();
	 fail;
	 }
#if Graphics
      /* A child process can't interact with the graphics system */
      if (pid == 0)
        wdsplys = 0;
#endif
      return C_integer pid;
#else
     Unsupported;
#endif
      }
end

#endif

extern char **environ;

function posix_System_environ()
  body {
    char **p = environ;
    while (*p) {
        tended struct descrip result;
        cstr2string(*p, &result);
        suspend result;
        ++p;
    }
    fail;
  }
end

static char ** list2stringptrs(dptr l)
{
    char *data, *p = 0, **a;
    tended union block *pb;
    int i, j, k, total;

    /*
     * Chain through each list block, making all elements strings
     * and counting the string array size required (total).
     */
    total = 0;
    for (pb = ListBlk(*l).listhead;
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
    MemProtect(a = malloc((ListBlk(*l).size + 1) * sizeof(char *)));
    if (total > 0) {
        MemProtect(data = malloc(total));
        p = data;
    }
    i = 0;
    for (pb = ListBlk(*l).listhead;
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
    if (i != ListBlk(*l).size)
        syserr("Inconsistent list/element size in list2stringptrs");
    a[i] = 0;
    return a;
}

function posix_System_execve(f, argv, envp)
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
      if (ListBlk(argv).size < 1)
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

function posix_System_wait_impl(pid, options)
   if !def:C_integer(pid, -1) then
      runerr(101, pid)
   if !def:C_integer(options, 0) then 
      runerr(103, options)
   body {
#if PLAN9
      tended struct descrip result, tmp;
      Waitmsg *w = waitforpid(pid);
      if (!w) {
          LitWhy("process has no children");
          fail;
      }
      create_list(3, &result);
      MakeInt(w->pid, &tmp);
      list_put(&result, &tmp);
      if (w->msg[0] == 0) {
          LitStr("exited normally", &tmp);
          list_put(&result, &tmp);
      } else {
          LitStr("exited", &tmp);
          list_put(&result, &tmp);
          cstr2string(w->msg, &tmp);
          list_put(&result, &tmp);
      }
      free(w);
      return result;
#elif UNIX
      struct descrip tmp;
      tended struct descrip result;
      char retval[64];
      int status = 0, wpid;
      if ((wpid = waitpid(pid, &status, options)) < 0) {
          errno2why();
          fail;
      }
      create_list(3, &result);
      MakeInt(wpid, &tmp);
      list_put(&result, &tmp);
      /* Unpack all the fields */
      if (WIFSTOPPED(status)) {
          LitStr("stopped", &tmp);
          list_put(&result, &tmp);
          MakeInt(WSTOPSIG(status), &tmp);
          list_put(&result, &tmp);
      } else if (WIFSIGNALED(status)) {
#ifdef WCOREDUMP
          if (WCOREDUMP(status))
              LitStr("coredump", &tmp);
          else
              LitStr("terminated", &tmp);
#else
          LitStr("terminated", &tmp);
#endif
          list_put(&result, &tmp);
          MakeInt(WTERMSIG(status), &tmp);
          list_put(&result, &tmp);
      } else if (WIFEXITED(status)) {
          LitStr("exited", &tmp);
          list_put(&result, &tmp);
          MakeInt(WEXITSTATUS(status), &tmp);
          list_put(&result, &tmp);
      } else {
          LitStr("unknown", &tmp);
          list_put(&result, &tmp);
      }
      return result;
#elif MSWIN32
      struct descrip tmp;
      tended struct descrip result;
      int wpid, termstat;
      if ((wpid = _cwait(&termstat, pid, options)) < 0) {
	 errno2why();
	 fail;
      }
      create_list(3, &result);
      MakeInt(wpid, &tmp);
      list_put(&result, &tmp);
      LitStr("terminated", &tmp);
      list_put(&result, &tmp);
      MakeInt(termstat, &tmp);
      list_put(&result, &tmp);
      return result;
#else
      Unsupported;
#endif
   }
end


function posix_System_unsetenv(name)
   if !cnv:C_string(name) then
      runerr(103, name)
   body {
#if HAVE_UNSETENV_INT_RETURN
       if (unsetenv(name) < 0) {
	 errno2why();
	 fail;
       }
#else
       unsetenv(name);
#endif
       return nulldesc;
   }
end

"setenv() - set an environment variable."

function posix_System_setenv(name, value)
   if !cnv:C_string(name) then
      runerr(103, name)
   if !cnv:C_string(value) then
      runerr(103, value)
   body {
      if (setenv(name, value, 1) < 0) {
	 errno2why();
         fail;
      }
      return nulldesc;
   }
end




"getenv(s) - return contents of environment variable s."

function posix_System_getenv(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      char *p;
      if ((p = getenv(s)) != NULL) {	/* get environment variable */
          tended struct descrip result;
          cstr2string(p, &result);
#if PLAN9
          free(p);
#endif
          return result;
      }
      else 				/* fail if not in environment */
	 fail;

   }
end

function posix_System_uname_impl()
    body {
#if HAVE_UNAME
       tended struct descrip tmp, result;
       struct utsname utsn;
       if (uname(&utsn) < 0) {
           errno2why();
           fail;
       }
       create_list(5, &result);
       cstr2string(utsn.sysname, &tmp);
       list_put(&result, &tmp);
       cstr2string(utsn.nodename, &tmp);
       list_put(&result, &tmp);
       cstr2string(utsn.release, &tmp);
       list_put(&result, &tmp);
       cstr2string(utsn.version, &tmp);
       list_put(&result, &tmp);
       cstr2string(utsn.machine, &tmp);
       list_put(&result, &tmp);
       return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_getpid()
   body {
#if UNIX || PLAN9
     return C_integer getpid();
#else
     Unsupported;
#endif
    }
end

function posix_System_getppid()
   body {
#if UNIX || PLAN9
     return C_integer getppid();
#else
     Unsupported;
#endif
    }
end

#if PLAN9

/*
 * status not yet collected for processes that have exited
 */
typedef struct Waited Waited;
struct Waited {
   Waitmsg*        msg;
   Waited* next;
};
static Waited *wd;

static Waitmsg *lookpid(int pid)
{
    Waited **wl, *w;
    Waitmsg *msg;

    for(wl = &wd; (w = *wl) != nil; wl = &w->next)
        if(pid <= 0 || w->msg->pid == pid){
            msg = w->msg;
            *wl = w->next;
            free(w);
            return msg;
        }
    return 0;
}

static void addpid(Waitmsg *msg)
{
    Waited *w;

    MemProtect(w = malloc(sizeof(*w)));
    w->msg = msg;
    w->next = wd;
    wd = w;
}

Waitmsg *waitforpid(int pid)
{
    Waitmsg *w;
    
    w = lookpid(pid);
    if (w)
        return w;

    for (;;) {
        w = wait();
        if (!w)
            return 0;
        if (pid == -1 || w->pid == pid)
            break;
        addpid(w);
    }

    return w;
}

int system(const char *command)
{
    int pid, rc;
    Waitmsg *w;
    switch (pid = rfork(RFPROC|RFFDG)) {
        case 0: {
            execl("/bin/rc", "rc", "-c", command, 0);
            exits("execl returned in system()");
            return -1;
        }
        case -1:
            return -1;
    }
    w = waitforpid(pid);
    if (!w)
        return -1;
    rc = (w->msg[0] == 0 ? 0 : 1);
    free(w);
    return rc;
}
#endif
