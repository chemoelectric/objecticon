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


"kill() - send a signal to a process."

function posix_System_kill(pid, signal)
   if !cnv:integer(pid) then
      runerr(101, pid)
   if !cnv:C_integer(signal) then
      runerr(101, signal)
   body {
#if UNIX
      pid_t i;
      if (!convert_to_pid_t(&pid, &i))
          runerr(0);
      if (kill(i, signal) != 0) {
         errno2why();
         fail;
      }
      ReturnDefiningClass;
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
      if (flag & RFMEM)
          Irunerr(205, flag);
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
      pid_t pid;
      tended struct descrip result;
      if ((pid = fork()) < 0) {
         errno2why();
         fail;
         }
      convert_from_pid_t(pid, &result);      
      return result;
#else
      Unsupported;
#endif
      }
end

#endif

#if MSWIN32

function posix_System_environ()
  body {
    tended struct descrip tmp, result;
    WCHAR *p, *env = GetEnvironmentStringsW();
    create_list(0, &result);
    p = env;
    while (*p) {
        wchar_to_utf8_string(p, &tmp);
        list_put(&result, &tmp);
        p += wcslen(p) + 1;
    }
    FreeEnvironmentStringsW(env);
    return result;
  }
end

#elif PLAN9
extern char **environ;

#else
extern char **environ;

function posix_System_environ()
  body {
    tended struct descrip tmp, result;
    char **p = environ;
    create_list(0, &result);
    while (*p) {
        cstr2string(*p, &tmp);
        list_put(&result, &tmp);
        ++p;
    }
    return result;
  }
end

#endif

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
    a = safe_malloc((ListBlk(*l).size + 1) * sizeof(char *));
    if (total > 0) {
        data = safe_malloc(total);
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
   if !def:integer(pid, -1) then
      runerr(101, pid)
   if !def:C_integer(options, 0) then 
      runerr(103, options)
   body {
#if PLAN9
      tended struct descrip result, tmp;
      word i;
      Waitmsg *w;
      if (!cnv:C_integer(pid, i))
          runerr(101, pid);
      w = waitforpid(i);
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
      pid_t i, j;
      tended struct descrip result, tmp;
      int status = 0;
      if (!convert_to_pid_t(&pid, &i))
          runerr(0);
      if ((j = waitpid(i, &status, options)) < 0) {
          errno2why();
          fail;
      }
      create_list(3, &result);
      convert_from_pid_t(j, &tmp);      
      list_put(&result, &tmp);
      /* Unpack all the fields */
      if (j == 0) {
          /* Means we were called with WNOHANG, and the exit status is not yet available. */
          LitStr("unavailable", &tmp);
          list_put(&result, &tmp);
      } else if (WIFSTOPPED(status)) {
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
      word i;
      int wpid, termstat;
      if (!cnv:C_integer(pid, i))
          runerr(101, pid);
      if ((wpid = _cwait(&termstat, i, options)) < 0) {
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
       ReturnDefiningClass;
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
      ReturnDefiningClass;
   }
end

"getenv(s) - return contents of environment variable s."

function posix_System_getenv(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      tended struct descrip result;
      char *p;
      p = getenv(s);
      /* fail if not in environment */
      if (!p)
          fail;
      cstr2string(p, &result);
      return result;
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
#if UNIX
     tended struct descrip result;
     convert_from_pid_t(getpid(), &result);      
     return result;
#elif PLAN9
     return C_integer getpid();
#else
     Unsupported;
#endif
    }
end

function posix_System_getppid()
   body {
#if UNIX
     tended struct descrip result;
     convert_from_pid_t(getppid(), &result);      
     return result;
#elif PLAN9
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

    w = safe_malloc(sizeof(*w));
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

void kill_proc(int id)
{
    postnote(PNPROC, id, "kill");
    free(waitforpid(id));
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

function posix_System_getuid()
   body {
#if UNIX
     tended struct descrip result;
     convert_from_uid_t(getuid(), &result);      
     return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_geteuid()
   body {
#if UNIX
     tended struct descrip result;
     convert_from_uid_t(geteuid(), &result);      
     return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_getgid()
   body {
#if UNIX
     tended struct descrip result;
     convert_from_gid_t(getgid(), &result);      
     return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_getegid()
   body {
#if UNIX
     tended struct descrip result;
     convert_from_gid_t(getegid(), &result);      
     return result;
#else
     Unsupported;
#endif
    }
end

#if UNIX
static void passwd2list(struct passwd *pw, dptr result)
{
   tended struct descrip tmp;
   create_list(6, result);
   cstr2string(pw->pw_name, &tmp);
   list_put(result, &tmp);
   cstr2string(pw->pw_passwd, &tmp);
   list_put(result, &tmp);
   convert_from_uid_t(pw->pw_uid, &tmp);
   list_put(result, &tmp);
   convert_from_gid_t(pw->pw_gid, &tmp);
   list_put(result, &tmp);
   cstr2string(pw->pw_dir, &tmp);
   list_put(result, &tmp);
   cstr2string(pw->pw_shell, &tmp);
   list_put(result, &tmp);
}

static void group2list(struct group *gr, dptr result)
{
   tended struct descrip tmp, mem;
   int i;
   create_list(4, result);
   cstr2string(gr->gr_name, &tmp);
   list_put(result, &tmp);
   cstr2string(gr->gr_passwd, &tmp);
   list_put(result, &tmp);
   convert_from_gid_t(gr->gr_gid, &tmp);
   list_put(result, &tmp);
   create_list(0, &mem);
   list_put(result, &mem);
   i = 0;
   while (gr->gr_mem[i]) {
       cstr2string(gr->gr_mem[i], &tmp);
       list_put(&mem, &tmp);
       ++i;
   }
}
#endif

function posix_System_getpw_impl(v)
   body {
#if UNIX
    tended struct descrip result;
    struct passwd *pw;
    if (is:integer(v)) {
        uid_t u;
        if (!convert_to_uid_t(&v, &u))
           runerr(0);
        pw = getpwuid(u);
    } else {
        if (!cnv:string(v, v)) 
           runerr(103, v);
        pw = getpwnam(buffstr(&v));
    }
    if (!pw)
        fail;
    passwd2list(pw, &result);
    return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_getgr_impl(v)
   body {
#if UNIX
    tended struct descrip result;
    struct group *gr;
    if (is:integer(v)) {
        gid_t g;
        if (!convert_to_gid_t(&v, &g))
           runerr(0);
        gr = getgrgid(g);
    } else {
        if (!cnv:string(v, v)) 
           runerr(103, v);
        gr = getgrnam(buffstr(&v));
    }
    if (!gr)
        fail;
    group2list(gr, &result);
    return result;
#else
     Unsupported;
#endif
    }
end

function posix_System_getgroups()
   body {
#if UNIX
    tended struct descrip tmp, result;
    gid_t *buf;
    int i, n;
    n = getgroups(0, 0);
    if (n < 0) {
        errno2why();
        fail;
    }
    buf = safe_malloc(n * sizeof(gid_t));
    n = getgroups(n, buf);
    if (n < 0) {
        errno2why();
        free(buf);
        fail;
    }
    create_list(n, &result);
    for (i = 0; i < n; ++i) {
        convert_from_gid_t(buf[i], &tmp);
        list_put(&result, &tmp);
    }
    free(buf);
    return result;
#else
    Unsupported;
#endif
    }
end

function posix_System_setuid(uid)
   if !cnv:integer(uid) then
      runerr(101, uid)
   body {
#if UNIX
       uid_t u;
       if (!convert_to_uid_t(&uid, &u))
           runerr(0);
       if (setuid(u) < 0) {
           errno2why();
           fail;
       }
       ReturnDefiningClass;
#else
       Unsupported;
#endif
    }
end

function posix_System_setgid(gid)
   if !cnv:integer(gid) then
      runerr(101, gid)
   body {
#if UNIX
       gid_t g;
       if (!convert_to_gid_t(&gid, &g))
           runerr(0);
       if (setgid(g) < 0) {
           errno2why();
           fail;
       }
       ReturnDefiningClass;
#else
       Unsupported;
#endif
    }
end

function posix_System_setsid()
   body {
#if UNIX
       pid_t i;
       tended struct descrip result;
       if ((i = setsid()) < 0) {
           errno2why();
           fail;
       }
       convert_from_pid_t(i, &result);      
       return result;
#else
       Unsupported;
#endif
    }
end

function posix_System_getsid(pid)
   if !def:integer(pid, 0) then
      runerr(101, pid)
   body {
#if UNIX
       pid_t i, j;
       tended struct descrip result;
       if (!convert_to_pid_t(&pid, &i))
           runerr(0);
       if ((j = getsid(i)) < 0) {
           errno2why();
           fail;
       }
       convert_from_pid_t(j, &result);      
       return result;
#else
       Unsupported;
#endif
    }
end

function posix_System_setpgid(pid, pgid)
   if !def:integer(pid, 0) then
      runerr(101, pid)
   if !def:integer(pgid, 0) then
      runerr(101, pgid)
   body {
#if UNIX
       pid_t i, j;
       if (!convert_to_pid_t(&pid, &i))
           runerr(0);
       if (!convert_to_pid_t(&pgid, &j))
           runerr(0);
       if (setpgid(i, j) < 0) {
           errno2why();
           fail;
       }
       ReturnDefiningClass;
#else
       Unsupported;
#endif
    }
end

function posix_System_getpgid(pid)
   if !def:integer(pid, 0) then
      runerr(101, pid)
   body {
#if UNIX
       pid_t i, j;
       tended struct descrip result;
       if (!convert_to_pid_t(&pid, &i))
           runerr(0);
       if ((j = getpgid(i)) < 0) {
           errno2why();
           fail;
       }
       convert_from_pid_t(j, &result);      
       return result;
#else
       Unsupported;
#endif
    }
end

#if OS_DARWIN
function posix_System_getcwd(pid)
   if !cnv:integer(pid) then
      runerr(101, pid)
   body {
        tended struct descrip result;
	struct proc_vnodepathinfo pathinfo;
	int ret;
        pid_t i;
        if (!convert_to_pid_t(&pid, &i))
            runerr(0);
	ret = proc_pidinfo(i, PROC_PIDVNODEPATHINFO, 0, &pathinfo, sizeof(pathinfo));
	if (ret != sizeof(pathinfo)) { 
            errno2why();
            fail;
        }
        cstr2string(pathinfo.pvi_cdir.vip_path, &result);
        return result;
   }
end
#endif
