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
    tended struct b_lelem *le;
    tended struct descrip t;
    struct lgstate state;
    word i, total;

    /*
     * Chain through each list block, making all elements strings
     * and counting the string array size required (total).
     */
    total = 0;
    for (le = lgfirst(&ListBlk(*l), &state); le;
         le = lgnext(&ListBlk(*l), &state, le))
    {
        t = le->lslots[state.result];
        if (!cnv:string(t, t))
            ReturnErrVal(103, t, 0);
        le->lslots[state.result] = t;
        total += StrLen(t) + 1;
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
    for (le = lgfirst(&ListBlk(*l), &state); le;
         le = lgnext(&ListBlk(*l), &state, le))
    {
        t = le->lslots[state.result];
        a[i++] = p;
        memcpy(p, StrLoc(t), StrLen(t));
        p += StrLen(t);
        *p++ = 0;
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
   if !def:C_integer(options, 0) then 
      runerr(101, options)
   body {
#if UNIX
      pid_t i, j;
      tended struct descrip result, tmp;
      int status = 0;
      if (!def:integer(pid, -1, pid))
          runerr(101, pid);
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
      word h;
      DWORD r, t, rc;
      if (!cnv:C_integer(pid, h))
          runerr(101, pid);
      if ((options & WNOHANG))
          t = 0;
      else
          t = INFINITE;
      r = WaitForSingleObject((HANDLE)h, t);
      if (r == WAIT_FAILED) {
          win32error2why();
          fail;
      }
      create_list(3, &result);
      list_put(&result, &pid);
      if (r == WAIT_TIMEOUT) {
          /* Means we were called with WNOHANG, and the exit status is not yet available. */
          LitStr("unavailable", &tmp);
          list_put(&result, &tmp);
      } else if (r == 0) {
          LitStr("exited", &tmp);
          list_put(&result, &tmp);
          rc = 0;
          GetExitCodeProcess((HANDLE)h, &rc);
          MakeInt(rc, &tmp);
          list_put(&result, &tmp);
      } else {
          LitStr("unknown", &tmp);
          list_put(&result, &tmp);
      }
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
       tended struct descrip result;
       struct utsname utsn;
       if (uname(&utsn) < 0) {
           errno2why();
           fail;
       }
       C_to_list(&result, "sssss",
                 utsn.sysname,
                 utsn.nodename,
                 utsn.release,
                 utsn.version,
                 utsn.machine);
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
#else
     Unsupported;
#endif
    }
end

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
static void passwd_to_list(struct passwd *pw, dptr result)
{
   tended struct descrip uid, gid;
   convert_from_uid_t(pw->pw_uid, &uid);
   convert_from_gid_t(pw->pw_gid, &gid);
   C_to_list(result, "ssppss",
             pw->pw_name,
             pw->pw_passwd,
             &uid,
             &gid,
             pw->pw_dir,
             pw->pw_shell);
}

static void group_to_list(struct group *gr, dptr result)
{
   tended struct descrip tmp, mem, gid;
   int i;
   convert_from_gid_t(gr->gr_gid, &gid);
   create_list(0, &mem);
   i = 0;
   while (gr->gr_mem[i]) {
       cstr2string(gr->gr_mem[i], &tmp);
       list_put(&mem, &tmp);
       ++i;
   }
   C_to_list(result, "sspp",
             gr->gr_name,
             gr->gr_passwd,
             &gid,
             &mem);
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
    passwd_to_list(pw, &result);
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
    group_to_list(gr, &result);
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

#if MSWIN32
function posix_System_create_process(app_name, cmd_line, cwd, in, out, err)
   body {
       STARTUPINFOW si; 
       PROCESS_INFORMATION pi; 
       WCHAR *w_app_name, *w_cmd_line, *w_cwd;
       BOOL b;

       if (is:null(app_name) && is:null(cmd_line))
           runerr(103, cmd_line);

       StructClear(pi); 
       StructClear(si); 
       si.cb = sizeof(si);

       if (!is:null(in) || !is:null(out) || !is:null(err)) {
           si.dwFlags = STARTF_USESTDHANDLES;
           {
               FdStaticParam(in, fd);
               si.hStdInput = (HANDLE)_get_osfhandle(fd);
           }
           {
               FdStaticParam(out, fd);
               si.hStdOutput = (HANDLE)_get_osfhandle(fd);
           }
           {
               FdStaticParam(err, fd);
               si.hStdError = (HANDLE)_get_osfhandle(fd);
           }
       }

       if (is:null(app_name))
           w_app_name = NULL;
       else if (cnv:string(app_name, app_name))
           w_app_name = utf8_string_to_wchar(&app_name, 1, NULL);
       else
           runerr(103, app_name);

       if (is:null(cmd_line))
           w_cmd_line = NULL;
       else if (cnv:string(cmd_line, cmd_line))
           w_cmd_line = utf8_string_to_wchar(&cmd_line, 1, NULL);
       else {
           free(w_app_name);
           runerr(103, cmd_line);
       }

       if (is:null(cwd))
           w_cwd = NULL;
       else if (cnv:string(cwd, cwd))
           w_cwd = utf8_string_to_wchar(&cwd, 1, NULL);
       else {
           free(w_app_name);
           free(w_cmd_line);
           runerr(103, cwd);
       }

       b = CreateProcessW(w_app_name,
                          w_cmd_line,
                          NULL,           /* lpProcessAttributes */
                          NULL,           /* lpThreadAttributes */
                          TRUE,           /* bInheritHandles */
                          0,              /* dwCreationFlags */
                          NULL,           /* lpEnvironment */
                          w_cwd,          /* lpCurrentDirectory */
                          &si,
                          &pi);
       free(w_app_name);
       free(w_cmd_line);
       free(w_cwd);
       if (b) {
           CloseHandle(pi.hThread);
           return C_integer((word)pi.hProcess);
       } else {
           win32error2why();
           fail;
       }
   }
end

function posix_System_close_handle(h)
   if !cnv:C_integer(h) then
      runerr(101, h)
   body {
       if (!CloseHandle((HANDLE)h)) {
           win32error2why();
           fail;
       }
       ReturnDefiningClass;
   }
end

#endif
