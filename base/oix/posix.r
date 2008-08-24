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

extern int errno;

#define String(d, s) do {                               \
      int len = strlen(s);                              \
      Protect(StrLoc(d) = alcstr((s), len), runerr(0)); \
      StrLen(d) = len;                                  \
} while (0)


"strerror() - get the error string corresponding to an &errno value."

function{0,1} strerror(e)
   if !def:C_integer(e, IntVal(amperErrno)) then
      runerr(101, e)
   abstract {
      return string
      }
   inline {
       struct errtab *p;
       char buff[32];
       for (p = xerrnotab; p->err_no > 0; p++) {
           if (p->err_no == e) {
               MakeCStr(p->errmsg, &result);
               return result;
           }
       }
#ifdef HAVE_STRERROR
       return cstr2string(strerror(e));
#elif HAVE_SYS_NERR && HAVE_SYS_ERRLIST
      if (e <= 0 || e > sys_nerr) {
          sprintf(buff, "Unknown error %d", e);
          return cstr2string(buff);
      }
      MakeCStr((char *)sys_errlist[e], &result);
      return result;
#else
      sprintf(buff, "Error %d", e);
      return cstr2string(buff);
#endif
    }
end

"getppid() - get parent pid."

function{0,1} getppid()
   abstract {
      return integer
      }
   body {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      return C_integer (getppid());
#endif					/* MSWIN32 */
      }
end

"getpid() - get process pid."

function{0,1} getpid()
   abstract {
      return integer
      }
   inline {
     IntVal(amperErrno) = 0;
#if MSWIN32
#define getpid _getpid
#endif
     return C_integer (getpid());
     }
end

"hardlink() - create a hard link to a file."

function{0,1} hardlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (link(s1, s2) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
         }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"symlink() - create a symlink to a file."

function{0,1} symlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (symlink(s1, s2) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
         }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"readlink() - read a symbolic link."

function{0,1} readlink(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   abstract {
      return string
      }
   body {
      char ret[NAME_MAX];
      int len;
      char *out;
      long n;

      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      reserve(Strings, NAME_MAX);
      Protect(StrLoc(result) = alcstr(NULL, NAME_MAX), runerr(0));
      if ((len = readlink(s, StrLoc(result), NAME_MAX)) < 0) {
	 /* Give back the string */
	 n = DiffPtrs(StrLoc(result),strfree); /* note the deallocation */
	 EVStrAlc(n);
         strtotal += n;
         strfree = StrLoc(result);              /* reset free pointer */

	 IntVal(amperErrno) = errno;
	 fail;
         }

      /* Return the extra characters at the end */
      out = StrLoc(result) + len;
      StrLen(result) = DiffPtrs(out,StrLoc(result));
      n = DiffPtrs(out,strfree);             /* note the deallocation */
      EVStrAlc(n);
      strtotal += n;
      strfree = out;                         /* give back unused space */

      return result;
#endif					/* MSWIN32 */
      }
end

"kill() - send a signal to a process."

function{0,1} kill(pid, signal)
   if !cnv:C_integer(pid) then
      runerr(101, pid)

   if !cnv:C_integer(signal) then
      runerr(101, signal)

   abstract {
      return null
      }
   body {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (kill(pid, signal) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"trap() - trap a signal."

function{0,1} trap(sig, handler)
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

"chown() - change the owner of a file."

function{0,1} chown(s, u, g)
   declare {
      C_integer i_u, i_g;
      }
   type_case u of {
      string: {
	 body {
	    tended char* fname;
	    cnv:C_string(u, fname);
	    i_u = get_uid(fname);
	 }
      }
      integer: {
	 body {
	    cnv:C_integer(u, i_u);
	 }
      }
      null: {
	 body {
	    i_u = -1;
	 }
      }
      default: {
	 runerr(170, g);
      }
   }

   type_case g of {
      string: {
	 body {
	    tended char* gname;
	    cnv:C_string(g, gname);
	    i_g = get_gid(gname);
	 }
      }
      integer: {
	 body {
	    cnv:C_integer(g, i_g);
	 }
      }
      null: {
	 body {
	    i_g = -1;
	 }
      }
      default: {
 	 runerr(170, u);
      }
   }

   type_case s of {
      string: {
         abstract {
	    return null
         }
	 body {
	    tended char *fname;

	    IntVal(amperErrno) = 0;
            cnv:C_string(s, fname);
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if (chown(fname, i_u, i_g) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }
	    return nulldesc;
#endif					/* MSWIN32 */
	 }
      }
      default:
	 runerr(109, s)
      }
end

"chmod() - change the permission on a file."

function{0,1} chmod(s, m)
   if !is:string(m) then
      if !is:integer(m) then
         runerr(170, m)

   type_case s of {
      string: {
 	 abstract {
	    return null
	    }
	 body {
	    C_integer i;
	    tended char *fname, *cmode;
	    IntVal(amperErrno) = 0;
            cnv:C_string(s, fname);
	    if (is:string(m)) {
	       cnv:C_string(m, cmode);
	       i = getmodenam(fname, cmode);
	       if (i == -1) {
		  IntVal(amperErrno) = errno;
		  fail;
		  }
	       if (i == -2)
		  runerr(1045, m);
	       }
	    else {
	       cnv:C_integer(m, i);
	       }
#if MSWIN32
#define chmod _chmod
#endif
	    if (chmod(fname, i) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	    }
	    return nulldesc;
	 }
      }
      default:
	 runerr(109, s)
      }
end

"chroot() - change the root directory."

function{0,1} chroot(d)
   if !cnv:C_string(d) then
      runerr(103, d)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (chroot(d) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"rmdir() - remove an empty directory."

function{0,1} rmdir(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
#define rmdir _rmdir
#endif
      if (rmdir(s) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
         }
      return nulldesc;
      }
end

"mkdir() - make a new directory."

function{0,1} mkdir(s, m)
   if !cnv:C_string(s) then
      runerr(103, s)
   if !is:string(m) then
      if !is:integer(m) then
	 if !is:null(m) then
            runerr(170, m)

   abstract {
      return null
      }
   body {
      tended char *cmode;
      C_integer mode = 0777;	/* default; will be modified by umask */
      
      if (is:string(m)) {
         cnv:C_string(m, cmode);
	 mode = getmodenam(0, cmode);
	 if (mode == -1) {
	    IntVal(amperErrno) = errno;
	    fail;
	 }
	 if (mode == -2)
	    runerr(1045, m);
      }
      else {
         cnv:C_integer(m, mode);
      }

      IntVal(amperErrno) = 0;
#if MSWIN32
#define mkdir(s,mode) _mkdir(s)		/* in MSWIN32, _mkdir don't have mode*/
#endif
      if (mkdir(s, mode) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
      }
      return nulldesc;
      }
end

"truncate() - truncate a file at a certain position."

function{0,1} truncate(f, l)
   if !cnv:C_integer(l) then
      runerr(101, l)
   type_case f of {
      string: {
 	 abstract {
	    return null
	    }
	 body {
	    tended char *s;
	    int fd = 0;

	    IntVal(amperErrno) = 0;
            cnv:C_string(f, s);

#if MSWIN32
	    if (((fd = _open(s, _O_RDWR | _O_CREAT, _S_IWRITE)) == -1) ||
		(_chsize(fd, l) != 0)) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }
	    _close(fd);
#else					/* MSWIN32 */
	    if (truncate(s, l) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }
#endif					/* MSWIN32 */
	    return nulldesc;
	 }
      }
      default:
	 runerr(109, f)
      }
end

"utime() - set access and/or modification times on a file."

function{0,1} utime(f, atime, mtime)
   if !cnv:C_string(f) then
      runerr(103, f)
   if !cnv:C_integer(mtime) then
      runerr(101, mtime)
   if !cnv:C_integer(atime) then
      runerr(101, atime)
   abstract {
      return null
      }
   body {
#if MSWIN32
#define utime _utime
#define utimbuf _utimbuf
#endif
      struct utimbuf t;
      t.actime = atime;
      t.modtime = mtime;
      IntVal(amperErrno) = 0;
      if (utime(f, &t) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
      }
end


"fork() - spawn a new identical process."

#if MSWIN32
function{0} fork()
#else					/* MSWIN32 */
function{0,1} fork()
#endif					/* MSWIN32 */
   abstract {
      return integer
      }
   inline {
      int pid;
      IntVal(amperErrno) = 0;
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if ((pid = fork()) < 0) {
	 IntVal(amperErrno) = errno;
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


"exec() - replace the executing Icon program with a new program."

function{0,1} exec(f, argv[argc])
   if !cnv:C_string(f) then
      runerr(103, f)
   abstract {
      return null
      }
   body {
      int i;
      /*
       * We are subverting the RTT type system here w.r.t. garbage
       * collection but we're going to be doing an exec() so ...
       */
      tended char *p;
      /* fixme: remove static limit on margv */
      char *margv[200];		/* We need a different array so we can put
				   a nil pointer at the end of the list */
      if (argc > 200)
    	 runerr(0);
      IntVal(amperErrno) = 0;
      for(i = 0; i < argc; i++) {
         if (!cnv:C_string(argv[i], p))
	    runerr(103, argv[i]);
	 margv[i] = p;
      }
      margv[i] = 0;
      if (execvp(f, margv) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
      }
end


"getuid() - get the real user identity."

function{0,1} getuid()
   abstract {
      return string
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      struct passwd *pw;
      char name[12], *user;
      int u;
      pw = getpwuid(u = getuid());
      if (!pw) {
	 sprintf(name, "%d", u);
	 user = name;
	 }
      else
	 user = pw->pw_name;
      String(result, user);
      return result;
#endif					/* MSWIN32 */
      }
end

"geteuid() - get the effective user identity."

function{0,1} geteuid()
   abstract {
      return string
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      struct passwd *pw;
      char name[12], *user;
      int u;
      pw = getpwuid(u = geteuid());
      if (!pw) {
	 sprintf(name, "%d", u);
	 user = name;
	 }
      else
	 user = pw->pw_name;
      String(result, user);
      return result;
#endif					/* MSWIN32 */
      }
end

"getgid() - get the real group identity."

function{0,1} getgid()
   abstract {
      return string
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      struct group *gr;
      char name[12], *user;
      int g;
      gr = getgrgid(g = getgid());
      if (!gr) {
	 sprintf(name, "%d", g);
	 user = name;
	 }
      else
	 user = gr->gr_name;
      String(result, user);
      return result;
#endif					/* MSWIN32 */
      }
end

"getegid() - get the effective group identity."

function{0,1} getegid()
   abstract {
      return string
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      struct group *gr;
      char name[12], *user;
      int g;
      gr = getgrgid(g = getegid());
      if (!gr) {
	 sprintf(name, "%d", g);
	 user = name;
	 }
      else
	 user = gr->gr_name;
      String(result, user);
      return result;
#endif					/* MSWIN32 */
      }
end

"setuid() - set the real and/or effective user identity."

function{0,1} setuid(u)
   if !cnv:C_integer(u) then
      runerr(101, u)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (setuid(u) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"setgid() - set the real and/or effective group identity."

function{0,1} setgid(g)
   if !cnv:C_integer(g) then
      runerr(101, g)
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (setgid(g) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

"getpgrp() - get the process group."

function{0,1} getpgrp()
   abstract {
      return integer
      }
   inline {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      return C_integer getpgrp();
#endif					/* MSWIN32 */
   }
end

"setpgrp() - set the process group."

function{0,1} setpgrp()
   abstract {
      return null
      }
   inline {
      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (Setpgrp() != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

"crypt() - the password encryption function."

function{0,1} crypt(key, salt)
   if !cnv:C_string(key) then
      runerr(103, key)
   if !cnv:C_string(salt) then
      runerr(103, salt)
   abstract {
      return string
      }
   inline {
#ifdef HAVE_LIBCRYPT
      char *crypt(const char *key, const char *salt);
      String(result, (char*)crypt(key, salt));
      return result;
#else
      fail;
      return nulldesc; /* NOTREACHED */
#endif
   }
end

"umask() - set the umask and return the old value."

function{0,1} umask(mask)
   if !is:integer(mask) then
      if !is:string(mask) then
	 if !is:null(mask) then
	    runerr(170, mask)
   abstract {
      return integer ++ string
      }
   inline {
      if (is:integer(mask)) {
	 C_integer m;
         cnv:C_integer(mask, m);
#if MSWIN32
#define umask _umask
#endif
	 return C_integer umask(m);
	 }
      else if (is:string(mask)) {
	 /*
	  * string better be of the form rwxrwxrwx with some dashes
	  */
	 tended char *perm;
	 int i, cmask, oldmask;
	 char allperms[10];

         cnv:C_string(mask, perm);
	 strcpy(allperms, "rwxrwxrwx");

	 cmask = 0;
	 for(i = 0; i < 9; i++) {
	    cmask = cmask << 1;
	    if (perm[i] == '-') {
	       cmask |= 1;
	    } else if (perm[i] != allperms[i])
	       runerr(1046, mask);
	 }
	 oldmask = umask(cmask);
	 for (i = 0; i < 9; i++) {
	    if (oldmask & (1 << (8-i)))
	       allperms[i] = '-';
	 }
	 String(result, allperms);
	 return result;
      }
      else {
	 /* If null, just return the present value of umask */
	 int oldmask, i;
	 char allperms[10];
	 strcpy(allperms, "rwxrwxrwx");

	 oldmask = umask(0);
	 umask(oldmask);
	 for (i = 0; i < 9; i++) {
	    if (oldmask & (1 << (8-i)))
	       allperms[i] = '-';
	 }
	 String(result, allperms);
	 return result;
      }
   }
end

"wait() - wait for process to terminate or stop."
"the return value is `status' from the wait(2) manpage."

function{0,1} wait(pid, options)
   if !def:C_integer(pid, -1) then
      runerr(101, pid)
   if !def:C_string(options, "") then 
      runerr(103, options)
   abstract {
      return string;
      }
   body {
      char retval[64];
      int option = 0, status = 0, wpid, i=0;
#if !MSWIN32
#if defined(BSD) || defined(Linux) || defined(BSD_4_4_LITE)
      struct rusage rusage;
      while(options[i])
	 switch(options[i++]) {
	 case 'n' : option |= WNOHANG; break;
	 case 'u' : option |= WUNTRACED; break;
	 }

      IntVal(amperErrno) = 0;
      if ((wpid = wait4(pid, &status, option, &rusage)) < 0) {
	 IntVal(amperErrno) = errno;
	 fail;
      }

#else					/* BSD || Linux */

      /* HP and Solaris */
      if (pid == -1) {
	 IntVal(amperErrno) = 0;
	 if ((wpid = wait(&status)) < 0) {
	    IntVal(amperErrno) = errno;
	    fail;
	 }
      } else {
	 while(options[i])
	    switch(options[i++]) {
	    case 'n' : option |= WNOHANG; break;
	    case 'u' : option |= WUNTRACED; break;
	    }

	 IntVal(amperErrno) = 0;
	 if ((wpid = waitpid(pid, &status, option)) < 0) {
	    IntVal(amperErrno) = errno;
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

      while(options[i])
	 switch(options[i++]) {
	 case 'n' : option |= _WAIT_CHILD; break;
	 case 'u' : option |= _WAIT_GRANDCHILD; break;
	 }

      IntVal(amperErrno) = 0;
      if ((wpid = _cwait(&termstat, pid, option)) < 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      sprintf(retval, "%d terminated:%d", wpid, termstat);
#endif					/* MSWIN32 */

      String(result, retval);
      return result;
   }
end

#begdef GenTime(name, conv_type, i)

#name "(t) - convert time_t (seconds since Jan 1, 1970 00:00:00) into " conv_type

function{0,1} name(t)
   if !cnv:C_integer(t) then
      runerr(101, t)
   abstract {
      return string
   }
   inline {
      char *p;
      int l;
#if i
      p = name((time_t *)&t);
#else
      p = asctime(gmtime((time_t *)&t));
#endif
      l = strlen(p) - 1;
      reserve(Strings, l);
      Protect(StrLoc(result) = alcstr(p, l), runerr(0));
      StrLen(result) = l;
      return result;
   }
end
#enddef

GenTime(ctime, "ASCII.", 1)
GenTime(gtime, "UTC.", 0)

"gettimeofday() - get time since the epoch (Jan 1, 1970 00:00:00)."

function{0,1} gettimeofday()
   abstract {
      return record
   }
   body {
      struct timeval tp;
#if MSWIN32
      struct _timeb wtp;
#endif					/* MSWIN32 */
      struct b_record *rp; /* does not need to be tended */
      static dptr constr;

      IntVal(amperErrno) = 0;
#if MSWIN32
      _ftime( &wtp );
#else					/* MSWIN32 */
      if (gettimeofday(&tp, 0) < 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
#endif					/* MSWIN32 */
      if (!constr)
	 if (!(constr = rec_structor("posix_timeval")))
	    syserr("failed to create posix record constructor");

      Protect(rp = alcrecd(&BlkLoc(*constr)->constructor), runerr(0));
      result.dword = D_Record;
      result.vword.bptr = (union block *)rp;
#if MSWIN32
      MakeInt(wtp.time, &(rp->fields[0]));
      MakeInt(wtp.millitm * 1000, &(rp->fields[1]));
#else					/* MSWIN32 */
      MakeInt(tp.tv_sec, &(rp->fields[0]));
      MakeInt(tp.tv_usec, &(rp->fields[1]));
#endif					/* MSWIN32 */
      return result;

   }
end

"lstat() - get file status without following symlinks."

function{0,1} lstat(f)
   if !cnv:C_string(f) then
      runerr(103, f)
   abstract {
      return record
      }
   body {
      tended struct b_record *rp;
#if MSWIN32
      struct _stat sbuf;
#else					/* MSWIN32 */
      struct stat sbuf;
#endif					/* MSWIN32 */
      static dptr constr;

      IntVal(amperErrno) = 0;
#if MSWIN32
#define lstat _stat
#endif					/* MSWIN32 */
      if (lstat(f, &sbuf) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
      }

      if (!constr)
	 if (!(constr = rec_structor("posix_stat")))
	    syserr("failed to create posix record constructor");

      Protect(rp = alcrecd(&BlkLoc(*constr)->constructor), runerr(0));
      stat2rec(&sbuf, &result, &rp);
      return result;
   }
end

"stat() - get file status."

function{0,1} stat(f)
   type_case f of {
      string: {
 	 abstract {
	    return record
	    }
	 body {
	    tended struct b_record *rp;
#if MSWIN32
	    struct _stat sbuf;
#else					/* MSWIN32 */
	    struct stat sbuf;
#endif					/* MSWIN32 */
	    tended char *fname;
	    static dptr constr;

            cnv:C_string(f, fname);
	    IntVal(amperErrno) = 0;
	    if (lstat(fname, &sbuf) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	    }
	    if (!constr)
	       if (!(constr = rec_structor("posix_stat")))
		  syserr("failed to create posix record constructor");

	    Protect(rp = alcrecd(&BlkLoc(*constr)->constructor), runerr(0));
	    stat2rec(&sbuf, &result, &rp);

#if !MSWIN32
	    if (S_ISLNK(sbuf.st_mode)) {
	       /* readlink */
	       char ret[NAME_MAX];
	       int len;
	       char *out;
	       long n;

	       IntVal(amperErrno) = 0;

	       reserve(Strings, NAME_MAX);
	       Protect(StrLoc(rp->fields[13]) = 
		       alcstr(NULL, NAME_MAX), runerr(0));
	       if ((len = readlink(fname, StrLoc(rp->fields[13]), NAME_MAX)) < 0) {
		  /* Give back the string */
		  n = DiffPtrs(StrLoc(rp->fields[13]),strfree);
		  EVStrAlc(n);
		  strtotal += DiffPtrs(StrLoc(rp->fields[13]),strfree);
		  /* reset free pointer */
		  strfree = StrLoc(rp->fields[13]);

		  IntVal(amperErrno) = errno;
		  fail;
	       }

	       /* Return the extra characters at the end */
	       out = StrLoc(rp->fields[13]) + len;
	       StrLen(rp->fields[13]) = DiffPtrs(out,StrLoc(rp->fields[13]));
	       n = DiffPtrs(out,strfree);
	       EVStrAlc(n);
	       strtotal += n;
	       strfree = out;
	    }
#endif					/* !MSWIN32 */
	    return result;
	 }
      }
      default:
	 runerr(109, f)
   }
end

"getpw() - get password file information."

function{0,1} getpw(u)

   declare {
      struct passwd *pw;
   }
   abstract {
      return record
   }
   type_case u of {
      string: {
	 body {
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    tended char* name;
	    cnv:C_string(u, name);
	    
	    if ((pw = getpwnam(name)) == NULL)
	       fail;

	    if (make_pwd(pw, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
      integer: {
	 body {
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    C_integer uid;
	    cnv:C_integer(u, uid);

	    if ((pw = getpwuid(uid)) == NULL)
	       fail;

	    if (make_pwd(pw, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
      null: {
	 body {
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if ((pw = getpwent()) == NULL)
	       fail;

	    if (make_pwd(pw, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
      default: {
         runerr(170, u)
      }
   }

end

"getgr() - get group information."

function{0,1} getgr(g)

   declare {
      struct group *gr;
      }
   abstract {
      return record
      }
   type_case g of {
      string: {
	 body {
	    tended char* name;
	    cnv:C_string(g, name);
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if ((gr = getgrnam(name)) == NULL)
	       fail;

	    if (make_group(gr, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
   integer: {
	 body {
	    C_integer gid;
	    cnv:C_integer(g, gid);
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if ((gr = getgrgid(gid)) == NULL)
	       fail;

	    if (make_group(gr, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
   null: {
	 body {
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if ((gr = getgrent()) == NULL)
	       fail;

	    if (make_group(gr, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
   default: {
         runerr(170, g)
      }
   }

end

"gethost() - get host information."

function{0,1} gethost(h)
   declare {
      struct hostent *hs;
   }
   abstract {
      return record
   }
   type_case h of {
      string: {
	 body {
	    tended char* name;
	    cnv:C_string(h, name);
    
	    if ((hs = gethostbyname(name)) == NULL)
	       fail;
	    if (make_host(hs, &result) == 0)
	       syserr("failed to create posix record constructor");

	    return result;
	 }
      }
      null: {
	 body {
#if MSWIN32
	    static struct hostent *hs2;
	    if (hs2 != NULL) {
	       hs2 = NULL;
	       fail;
	       }
	    else {
	       char name[256];
	       gethostname(name, 256);
	       if ((hs2 = gethostbyname(name)) == NULL)
		  fail;
	       if (make_host(hs2, &result) == 0)
		  syserr("failed to create posix record constructor");
	       return result;
	       }
#else					/* MSWIN32 */

#ifdef HAVE_GETHOSTENT
	    if ((hs = gethostent()) == NULL)
	       fail;
#else
            fail;
#endif

	    if (make_host(hs, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
   default: {
         runerr(103, h)
      }
   }
end

"getserv() - get network service information."

function{0,1} getserv(s, proto)
   declare {
      struct servent *serv;
   }
   abstract {
      return record
   }
   type_case s of {
      string: {
	 body {
	    struct servent *serv;
	    tended char *p;
	    tended char* name;
	    p = 0;
	    cnv:C_string(s, name);
            if (!is:null(proto))
	       if (!cnv:C_string(proto, p))
		  runerr(103, proto);
  
	    if (p && !getprotobyname(p))
	       runerr(1047, proto);
	    if ((serv = getservbyname(name, p)) == NULL)
	       fail;

	    if (make_serv(serv, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
	 }
      }
      integer: {
	 body {
	    tended char *p;
	    C_integer port;
	    p = 0;
	    cnv:C_integer(s, port);
            if (!is:null(proto))
	       if (!cnv:C_string(proto, p))
		  runerr(103, proto);

	    if (p && !getprotobyname(p))
	       runerr(1047, proto);
	    if ((serv = getservbyport(port, p)) == NULL)
	       fail;

	    if (make_serv(serv, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
	 }
      }
      null: {
	 body {
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if ((serv = getservent()) == NULL)
	       fail;

	    if (make_serv(serv, &result) == 0)
	       syserr("failed to create posix record constructor");
	    return result;
#endif					/* MSWIN32 */
	 }
      }
   default: {
         runerr(170, s)
      }
   }
end

"setpwent() - reset the password file."

function{0,1} setpwent()
   abstract {
      return null
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      setpwent();
#endif					/* MSWIN32 */
      return nulldesc;
   }
end

"setgrent() - reset the group file."

function{0,1} setgrent()
   abstract {
      return null
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      setgrent();
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

"sethostent() - reset host processing."

function{0,1} sethostent(so)
   if !def:C_integer(so, 1) then
      runerr(101, so)
   abstract {
      return null
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      sethostent(so);
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"setservent() - reset network service entry processing."

function{0,1} setservent(so)
   if !def:C_integer(so, 1) then
      runerr(101, so)
   abstract {
      return null
      }
   body {
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      setservent(so);
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

"setenv() - set an environment variable."

function{0, 1} setenv(name, value)
   if !cnv:C_string(name) then
      runerr(103, name)
   if !cnv:C_string(value) then
      runerr(103, value)
   abstract {
      return null
      }
   inline {
#if MSWIN32
      if (!SetEnvironmentVariable(name, value))
         fail;
#else
#if defined(SUN) || defined(HP)

      /*
       * WARNING! I don't know if other systems require putenv with
       * non-auto storage! If there are, they should be added to this
       * section.
       *
       * putenv(3C) needs a string that's "name=value". We malloc() the
       * the string for this; if there's another call to putenv(3C)
       * with the same value, the old string is no longer needed. What
       * we do is store a sentinel in front of the name=value section;
       * before calling putenv we call getenv and see if it's a string
       * we allocated for a previous putenv by looking for the sentinel.
       * If it is we can free it.                  -- shamim July 2002
       */

      char *p, *q;
      char* sentinel = "n59KxD2LlhPL1suOWsNg";
      int slen = strlen(sentinel);
      int n = slen + strlen(name) + strlen(value) + 1;

      if ((p = malloc(n + 1)) == 0)
         fail;
      snprintf(p, n+1, "%s%s=%s", sentinel, name, value);
      p[n] = 0;
      if ((q = getenv(name)) != 0) {
         q -= strlen(name) + slen + 1;
         if (strncmp(q, sentinel, slen) != 0)
            q = 0;
      }
      if (putenv(p + slen) != 0)
         fail;
      if (q)
         free(q);
#else
      /* Tested on OpenBSD 3.1, FreeBSD-4.6, Linux 2.4.18 */
      if (setenv(name, value, 1) < 0)
         fail;
#endif
#endif
      return nulldesc;
   }
end




