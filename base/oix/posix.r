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


"syserrstr() - get the error string corresponding to an &errno value."

function{0,1} syserrstr(e)
   if !cnv:C_integer(e) then
      runerr(101, e)
   abstract {
      return string
      }
   inline {
      int rv;
#ifdef HAVE_STRERROR
      char *s = strerror(e);
      String(result, alcstr(s, strlen(s)));
#else					/* HAVE_STRERROR */
#ifdef HAVE_SYS_NERR
      if (e <= 0 || e > sys_nerr)
	 fail;
#endif
#ifdef HAVE_SYS_ERRLIST
      String(result, (char *)sys_errlist[e]);
#else
      fail;
#endif					/* HAVE_SYS_ERRLIST */
#endif					/* HAVE_STRERROR */
      return result;
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
   if !is:string(signal) then
      if !is:integer(signal) then
         runerr(170, signal)
   if !cnv:C_integer(pid) then
      runerr(101, pid)

   abstract {
      return null
      }
   body {
      C_integer sig;
      tended char *signalname;
     
      if (is:string(signal)) {
	 /* Parse signal name */
         cnv:C_string(signal, signalname);
	 sig = si_s2i((siptr)signalnames, signalname);
	 if (sig == -1)
	    runerr(1043, signal);
         }
      else {
         cnv:C_integer(signal, sig);
	 if (sig < 0 || sig > 50)
	    runerr(1043, signal);
	 }
      if (sig == 0) { 
	 IntVal(amperErrno) = EINVAL; 
	 fail; 
      } 

      IntVal(amperErrno) = 0;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if (kill(pid, sig) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
#endif					/* MSWIN32 */
      }
end

"trap() - trap a signal."

function{0,1} trap(nsignal, handler)
   if !is:string(nsignal) then
      if !is:integer(nsignal) then
         runerr(170, nsignal)
   abstract {
      return proc
      }
   body { 
      C_integer sig;
      tended char *signalname;
        
      if (is:string(nsignal)) {
         cnv:C_string(nsignal, signalname);
	 sig = si_s2i((siptr)signalnames, signalname);
	 if (sig == -1)
	    runerr(1043, nsignal);
         }
      else {
         cnv:C_integer(nsignal, sig);
	 if (sig < 0 || sig > 50)
	    runerr(1043, nsignal);
         }
      if (sig == 0) { 
	 IntVal(amperErrno) = EINVAL; 
	 fail; 
      } 

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
      file: {
         abstract {
	    return null
         }
	 body {
	    int fd;
	    IntVal(amperErrno) = 0;
	    if ((fd = get_fd(s, 0)) < 0)
	       runerr(174, s);
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if (fchown(fd, i_u, i_g) != 0) {
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
      file: {
	 abstract {
	    return null
	    }
	 body {
	    tended char *cmode;
	    C_integer i, fd;
	    IntVal(amperErrno) = 0;
	    if (is:string(m)) {
	       cnv:C_string(m, cmode);
	       if ((fd = get_fd(s, 0)) < 0)
		  runerr(174, s);
	       i = getmodefd(fd, cmode);
	       if (i == -1) {
		  IntVal(amperErrno) = errno;
		  fail;
	       }
	       if (i == -2)
		  runerr(1045, m);
	    }
	    else
	       cnv:C_integer(m, i);
#if MSWIN32
	    fail;
#else					/* MSWIN32 */
	    if (fchmod(fd, i) != 0) {
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
      file: {
	 abstract {
	    return null
	    }
	 body {
	    int fd;
	    IntVal(amperErrno) = 0;

#ifdef HAVE_LIBZ 
            if (BlkLoc(f)->file.status & Fs_Compress) {
               fail;
               }
#endif					/* HAVE_LIBZ */

	    if ((fd = get_fd(f, 0)) < 0)
	       runerr(174, f);
	    if (ftruncate(fd, l) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }
	    return nulldesc;
	 }
      }
      default:
	 runerr(109, f)
      }
end

"flock() - apply or remove a lock on a file."

function{0,1} flock(f, cmd)
   declare {
      tended char *c;
   }
   if !cnv:C_string(cmd, c) then
      runerr(101, cmd)
   if !is:file(f) then
      runerr(105, f)
   abstract {
      return null
      }
   body {

      int option = 0;
      int fd, i=0;
      long flength;

#ifdef HAVE_LIBZ 
      if (BlkLoc(f)->file.status & Fs_Compress) {
         fail;
         }
#endif					/* HAVE_LIBZ */

#if MSWIN32
      while (c[i])
	 switch (c[i++]) {
	 case 'x': option |= LK_LOCK; break;
	 /*
	 case 's': option |= LOCK_SH; break;
	 */
	 case 'b': option |= LK_NBLCK; break;
#ifndef NTGCC
	 case 'u': option |= LK_UNLCK; break;
#endif					/* NTGCC */
	 default: runerr(1044, cmd);
	 }

      IntVal(amperErrno) = 0;
      
      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);
	   
      if ((flength = _filelength(fd)) < 0)
	  irunerr(174, (int)flength);

      if (_locking(fd, option, flength) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
      }
      return nulldesc;
#endif					/* MSWIN32 */
#if defined(BSD) || defined(BSD_4_4_LITE) || defined(IRIS4D) || defined(Linux)

      while (c[i])
	 switch (c[i++]) {
	 case 'x': option |= LOCK_EX; break;
	 case 's': option |= LOCK_SH; break;
	 case 'b': option |= LOCK_NB; break;
	 case 'u': option |= LOCK_UN; break;
	 default: runerr(1044, cmd);
     }

      IntVal(amperErrno) = 0;
      
      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);

      if (flock(fd, option) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
      }
#else					/* BSD */
      fail;
#endif					/* BSD */
      return nulldesc;
   }
end

"fcntl() - control a file."

function{0,1} fcntl(f, action, options)
   if !is:string(action) then
      runerr(103, action)
   if !is:file(f) then
      runerr(105, f)
   if !is:string(options) then
      if !is:integer(options) then
         runerr(1044, options)
   abstract {
      return string ++ record ++ integer
      }
   body {
      int fd, cmd, nfields, buflen;
      tended char *c;
      static dptr constr;

#ifdef HAVE_LIBZ 
      if (BlkLoc(f)->file.status & Fs_Compress) {
         fail;
         }
#endif					/* HAVE_LIBZ */

#if MSWIN32
      fail;
#else					/* MSWIN32 */
      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);

      cnv:C_string(action, c);

      switch (*c) {
	 case 'F': cmd = F_SETFL; break;
	 case 'f': cmd = F_GETFL; break;
	 case 'X': cmd = F_SETFD; break;
	 case 'x': cmd = F_GETFD; break;
	 case 'L': cmd = F_SETLK; break;
	 case 'l': cmd = F_GETLK; break;
	 case 'W': cmd = F_SETLKW; break;
#ifdef HP
	   /* Owners not defined on HP */
#else					/* HP */
	 case 'O': cmd = F_SETOWN; break;
	 case 'o': cmd = F_GETOWN; break;
#endif					/* HP */
	 default: runerr(1044, action);
      }

      /* Figure out options to use */
      if (cmd == F_SETLK || cmd == F_GETLK || cmd == F_SETLKW) {
	 struct flock fl;
	 tended struct b_record *rp;
	 tended char *lock;
	 char *start, *len, *p;
	 char buf[32];

         cnv:C_string(options, lock);
	 if ((start = strchr(lock, ',')) == NULL)
	    runerr(1044, options);
	 *start++ = 0;
	 if ((len = strchr(start, ',')) == NULL)
	    runerr(1044, options);
	 *len++ = 0;

	 switch (lock[0]) {
	 case 'r': fl.l_type = F_RDLCK; break;
	 case 'w': fl.l_type = F_WRLCK; break;
	 case 'u': fl.l_type = F_UNLCK; break;
	 default: runerr(1044, options);
	 }
	 if (lock[1] != 0)
	    runerr(1044, options);

	 switch(start[0]) {
	 case '+': 
	    fl.l_whence = SEEK_CUR;
	    fl.l_start = strtol(start+1, &p, 10);
	    break;
	 case '-':
	    fl.l_whence = SEEK_END;
	    fl.l_start = strtol(start+1, &p, 10);
	    break;
	 default : 
	    fl.l_whence = SEEK_SET;
	    fl.l_start = strtol(start, &p, 10);
	    break;
	 }
	 if (*p != ',')
	    runerr(1044, options);

	 fl.l_len = strtol(len, &p, 10);
	 if (*p != ',')
	    runerr(1044, options);

	 start[-1] = len[-1] = ',';

	 IntVal(amperErrno) = 0;
	 if (fcntl(fd, cmd, &fl) < 0) {
	    IntVal(amperErrno) = errno;
	    fail;
	 }

	 p = buf;
	 switch (fl.l_type) {
	 case F_RDLCK: *p++ = 'r'; break;
	 case F_WRLCK: *p++ = 'w'; break;
	 case F_UNLCK: *p++ = 'u'; break;
	 }
	 *p++ = ',';
	 switch (fl.l_whence) {
	 case SEEK_CUR: *p++ = '+'; break;
	 case SEEK_END: *p++ = '-'; break;
	 }

	 sprintf(p, "%ld,%ld", fl.l_start, fl.l_len);

	 if (!constr)
	    if (!(constr = rec_structor("posix_lock")))
	       syserr("failed to create posix record constructor");

	 nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
	 Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));
	 result.dword = D_Record;
	 result.vword.bptr = (union block*)rp;
	 IntVal(rp->fields[1]) = fl.l_pid;
	 buflen = strlen(buf);
	 Protect(StrLoc(rp->fields[0]) = alcstr(buf, buflen), runerr(0));
	 StrLen(rp->fields[0]) = buflen;

	 return result;
      } else {
	 /* options should be an int */
	 C_integer o = 0, retval;

	 if (cmd == F_SETFL) {
	    tended char *opt;
	    cnv:C_string(options, opt);
	    while (*opt)
	      switch(*opt++) {
	      case 'd': o |= O_NDELAY; break;
	      case 'a': o |= O_APPEND; break;
#if defined(HP) || defined(SUN)
	      case 's': o |= FASYNC; break;
#endif
	      default: runerr(1044, options);
	      }
	 } else
	    cnv:C_integer(options, o);

	 IntVal(amperErrno) = 0;
	 if ((retval = fcntl(fd, cmd, o)) < 0) {
	    IntVal(amperErrno) = errno;
	    fail;
	 }

	 if (cmd == F_GETFL) {
	    char buf[10], *p = buf;
	    int buflen;
	    if (retval & O_APPEND) *p++ = 'a';
	    if (retval & O_NDELAY) *p++ = 'd';
#if defined(HP) || defined(SUN)
	    if (retval & FASYNC) *p++ = 's';
#endif
	    *p = 0;
	    buflen = strlen(buf);
	    Protect(StrLoc(result) = alcstr(buf, buflen), runerr(0));
	    StrLen(result) = buflen;
	    return result;

	 } else
	    return C_integer retval;
      }
#endif					/* MSWIN32 */
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


"ioctl() - control a device driver."

function{0,1} ioctl(f, action, options)
   if !cnv:C_integer(action) then
      runerr(103, action)
   if !is:file(f) then
      runerr(105, f)
   abstract {
      return integer
      }
   inline {
      int retval, fd;
      IntVal(amperErrno) = 0;
      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);

#ifdef HAVE_LIBZ 
      if (BlkLoc(f)->file.status & Fs_Compress) {
         fail;
         }
#endif					/* HAVE_LIBZ */

#if MSWIN32
      fail;
#else					/* MSWIN32 */
#ifdef UNICON_IOCTL
      if ((retval = ioctl(fd, action, options)) < 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
#else					/* UNICON_IOCTL */
      runerr(121, f);
#endif					/* UNICON_IOCTL */
#endif					/* MSWIN32 */
      return C_integer retval;
      }
end

"filepair() - create a connected bidirectional pair of files."

function{0,1} filepair()
   abstract {
      return new list(file)
      }
   body {
      int fds[2], i;
      FILE* fps[2];
      struct descrip fname;
      struct b_file *fl; /* not tended: single assignment usage */
      tended struct b_list *lp;
      tended union block *ep;
#if MSWIN32
      fail;
#else					/* MSWIN32 */
      IntVal(amperErrno) = 0;
      if (socketpair(AF_UNIX, SOCK_STREAM, 0, fds) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      /* create a list to put them in */
      Protect(lp = alclist(2, 2), runerr(0));
      ep = lp->listhead;

      /* Create the two file objects and put them into the list */
      StrLoc(fname) = "filepair";
      StrLen(fname) = 8;
      for(i = 0; i < 2; i++) {
	 fps[i] = fdopen(fds[i], "r");
	 Protect(fl = alcfile(fps[i], Fs_Write|Fs_Read|Fs_Socket, &fname),
		 runerr(0));
	 ep->lelem.lslots[i].dword = D_File;
	 ep->lelem.lslots[i].vword.bptr = (union block*)fl;
	 }

      return list(lp);
#endif					/* MSWIN32 */
   }
end

"pipe() - create a pipe."

function{0,1} pipe()
   abstract {
      return new list(file)
      }
   body {
      int fds[2], i;
      FILE* fps[2];
      struct descrip fname;
      struct b_file *fl;
      tended struct b_list *lp;
      tended union block *ep;

      IntVal(amperErrno) = 0;
#if MSWIN32
#define pipe(x) _pipe(x, 4096, O_BINARY|O_NOINHERIT)
#endif
      if (pipe(fds) != 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      /* create a list to put them in */
      Protect(lp = alclist(2, 2), runerr(0));
      ep = lp->listhead;

      /* Create the two file objects and put them into the list */
      StrLoc(fname) = "pipe";
      StrLen(fname) = 4;
      for(i = 0; i < 2; i++) {
	 fps[i] = fdopen(fds[i], i? "w":"r");
	 Protect(fl = alcfile(fps[i], (i? Fs_Write:Fs_Read), &fname),
		 runerr(0));
	 ep->lelem.lslots[i].dword = D_File;
	 ep->lelem.lslots[i].vword.bptr = (union block*)fl;
	 }
      return list(lp);
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
      fail;
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

"fdup() - duplicate a file (including its Unix fd)."

function{0,1} fdup(src, dest)
   if !is:file(src) then
      runerr(105, src)
   if !is:file(dest) then
      runerr(105, dest)
   abstract {
      return null
      }
   body {
      int fd_src, fd_dest, status;
      char *fmode;
      FILE *fp;

      if (BlkLoc(src)->file.status == 0)
	 runerr(1042, src);

#ifdef Graphics
      if (BlkLoc(src)->file.status & Fs_Window)
	 runerr(105, src);
      if (BlkLoc(dest)->file.status & Fs_Window)
	 runerr(105, dest);
#endif					/* Graphics */

      if ((fd_src = get_fd(src, 0)) < 0)
	 runerr(174, src);

      if ((fd_dest = get_fd(dest, 0)) < 0)
	 runerr(174, dest);
      if (BlkLoc(dest)->file.status != 0)
	 if (BlkLoc(dest)->file.status & Fs_Pipe)
	    pclose(BlkLoc(dest)->file.fd.fp);
	 else 
	    fclose(BlkLoc(dest)->file.fd.fp);
 
      IntVal(amperErrno) = 0;
      if (dup2(fd_src, fd_dest) < 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      BlkLoc(dest)->file.status = status = BlkLoc(src)->file.status;
      switch (status & (Fs_Read|Fs_Write)) {
      case Fs_Read & ~Fs_Write : fmode = "r"; break;
      case ~Fs_Read & Fs_Write : fmode = "w"; break;
      case Fs_Read & Fs_Write : fmode = "r+"; break;
      default: runerr(500); break;
      }
      BlkLoc(dest)->file.fd.fp = fp = fdopen(fd_dest, fmode);
      BlkLoc(dest)->file.fname = BlkLoc(src)->file.fname;
      return nulldesc;
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

"system() - create a new process, optionally mapping its stdin/stdout/stderr."

function{0,1} system(argv, d_stdin, d_stdout, d_stderr, mode)
   if !is:file(d_stdin) then
      if !is:null(d_stdin) then
	 runerr(105, d_stdin)
   if !is:file(d_stdout) then
      if !is:null(d_stdout) then
	 runerr(105, d_stdout)
   if !is:file(d_stderr) then
      if !is:null(d_stderr) then
	 runerr(105, d_stderr)
   if !is:list(argv) then
      if !is:string(argv) then
         runerr(110, argv)
   if !is:string(mode) then
      if !is:integer(mode) then
	 if !is:file(mode) then
	    if !is:null(mode) then
	       runerr(170, mode)
   abstract {
      return null ++ integer
      }
   body {
      int i, j, n, fd_0, fd_1, fd_2, is_argv_str=0, pid;
      C_integer i_mode=0;
      tended union block *ep;
	 
      /*
       * We are subverting the RTT type system here w.r.t. garbage
       * collection but we're going to be doing an exec() so ...
       */
      tended char *p;
      tended char *cmdline;
      char **margv=NULL;
      IntVal(amperErrno) = 0;

      /* Decode the mode */
      if (is:integer(mode))
	 cnv:C_integer(mode, i_mode);
      else if (is:string(mode)) {
	 tended char *s_mode;
         cnv:C_string(mode, s_mode);
	 i_mode = (strcmp(s_mode, "nowait") == 0);
      }

      if (is:list(argv)) {
         margv = (char **)malloc((BlkLoc(argv)->list.size+1) * sizeof(char *));
         if (margv == NULL) runerr(305);
	 n = 0;
	 /* Traverse the list */
	 for (ep = BlkLoc(argv)->list.listhead; BlkType(ep) == T_Lelem;
	      ep = ep->lelem.listnext) {
	    for (i = 0; i < ep->lelem.nused; i++) {
	       dptr f;
	       j = ep->lelem.first + i;
	       if (j >= ep->lelem.nslots)
		  j -= ep->lelem.nslots;
	       f = &ep->lelem.lslots[j];

	       if (!cnv:C_string((*f), p))
		  runerr(103, *f);
	       margv[n++] = p;
	       }
	    }
	 margv[n] = 0;
         }
      else if (is:string(argv)) {
	 is_argv_str = 1;
         cnv:C_string(argv, cmdline);
      }


#if !MSWIN32
      /* 
       * We don't use system(3) any more since the program is allowed to
       * re-map the files even for foreground execution
       */
      switch (pid = fork()) {
      case 0:

	 dup_fds(&d_stdin, &d_stdout, &d_stderr);

	 if (is_argv_str)
	    execl("/bin/sh", "sh", "-c", cmdline, 0);
	 else {
	    execvp(margv[0], margv);
	    free(margv);
            }

	  /*
	   * If we returned.... this is the child, so failure is no good;
	   * stop with a runtime error so at least the user will get some
	   * indication of the problem.
	   */
	  IntVal(amperErrno) = errno;
	  runerr(500);
	  break;
      case -1:
         if (margv) free(margv);
	 fail;
	 break;
      default:
         if (margv) free(margv);
	 if (!i_mode) {
	    int status;
	    waitpid(pid, &status, 0);
	    return C_integer status;
	    }
	 else {
	    return C_integer pid;
            }
      }
#else					/* MSWIN32 */
     /*
      * We might want to use CreateProcess and pass the file handles
      * for stdin/stdout/stderr to the child process.  Another candidate
      * is _execvp().
      */
      if (i_mode) {
         _flushall();
	 if (is:string(argv)) {
	    int argc;
	    char **garbage;
	    argc = CmdParamToArgv(cmdline, &garbage, 0);
	    i = (C_integer)_spawnvp(_P_NOWAITO, garbage[0], garbage);
	    }
	 else {
	    i = (C_integer)_spawnvp(_P_NOWAITO, margv[0], margv);
	    free(margv);
            }
	 if (i != 0) {
	    IntVal(amperErrno) = errno;
	    fail;
	    }
         }
      else {
	    /* Sigh... old "system". Collect all args into a string. */
	    if (is_argv_str) {
#ifdef MSWindows
	       i = (C_integer)mswinsystem(cmdline);
#else					/* MSWindows */
	       i = (C_integer)system(cmdline);
#endif					/* MSWindows */
	       return C_integer i;
	       }
	    else {
	       int i, total = 0, n;
	       tended char *s;
	 
	       i = 0;
	       while (margv[i]) {
		  total += strlen(margv[i]) + 1;
		  i++;
		  }
	       n = i-1;
	       /* We use Icon's allocator, it's the only safe way. */
	       Protect(s = alcstr(0, total), runerr(0));
	       p = s;
	       for (i = 0; i < n; i++) {
		  strcpy(p, margv[i]);
		  p += strlen(margv[i]);
		  *p++ = ' ';
		  }
#ifdef MSWindows
	       i = (C_integer)mswinsystem(s);
#else					/* MSWindows */
	       i = (C_integer)system(s);
#endif					/* MSWindows */
	       free(margv);
	       return C_integer i;
	       }
	    }
#endif					/* MSWIN32 */

      /*NOTREACHED*/
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
	 sprintf(retval, "%d stopped:%s", wpid, 
		 si_i2s((siptr)signalnames, WSTOPSIG(status)));

      else if (WIFSIGNALED(status))
	 sprintf(retval, "%d terminated:%s", wpid, 
		 si_i2s((siptr)signalnames, WTERMSIG(status)));

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
      int nfields;

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

      nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
      Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));
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
      int nfields;

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

      nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
      Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));
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
	    int nfields;

            cnv:C_string(f, fname);
	    IntVal(amperErrno) = 0;
	    if (lstat(fname, &sbuf) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	    }
	    if (!constr)
	       if (!(constr = rec_structor("posix_stat")))
		  syserr("failed to create posix record constructor");

	    nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
	    Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));
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
      file: {
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
	    int nfields, fd;

#ifdef HAVE_LIBZ 
            if (BlkLoc(f)->file.status & Fs_Compress)
               fail;
#endif					/* HAVE_LIBZ */

	    IntVal(amperErrno) = 0;
	    if ((fd = get_fd(f, 0)) < 0)
	       runerr(174, f);
	    if (fstat(fd, &sbuf) != 0) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }
	    if (!constr)
	       if (!(constr = rec_structor("posix_stat")))
		  syserr("failed to create posix record constructor");

	    nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
	    Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));
	    stat2rec(&sbuf, &result, &rp);
	    return result;
	 }
      }
      default:
	 runerr(109, f)
   }
end

"send() - send a UDP datagram."

function{0,1} send(addr, msg)
   if !cnv:C_string(addr) then
      runerr(103, addr)
   if !cnv:string(msg) then
      runerr(103, msg)
   abstract {
      return null
      }
   body {
      IntVal(amperErrno) = 0;
      if (!sock_send(addr, StrLoc(msg), StrLen(msg))) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      return nulldesc;
   }
end

"receive() - receive a UDP datagram."

function{0,1} receive(f)
  if !is:file(f) then
      runerr(105, f)
   abstract {
      return record
      }
   body {
      tended struct b_record *rp;
      static dptr constr;
      int nfields, status, ret;
      
      status = BlkLoc(f)->file.status;
      if (!(status & Fs_Socket))
	 runerr(175, f);

      if (!constr)
	 if (!(constr = rec_structor("posix_message")))
	    syserr("failed to create posix record constructor");

      nfields = (int) ((struct b_proc *)BlkLoc(*constr))->nfields;
      Protect(rp = alcrecd(nfields, BlkLoc(*constr)), runerr(0));

      IntVal(amperErrno) = 0;
      if ((ret = sock_recv(BlkLoc(f)->file.fd.fd, &rp)) == 0) {
	 IntVal(amperErrno) = errno;
	 fail;
	 }
      if (ret == -1)
	 runerr(171, f);
	 
      result.dword = D_Record;
      result.vword.bptr = (union block *)rp;
      return result;
   }
end

/* 
 * Select
 */
int set_if_selectable(struct descrip *f, fd_set *fdsp, int *n)
{
   int fd, status;
   if (is:file(*f)) {
      status = BlkLoc(*f)->file.status;
#if UNIX
      if (status & Fs_Buff) return 1048;
      BlkLoc(*f)->file.status |= Fs_Unbuf;
#endif					/* UNIX */

#ifdef Graphics
      /*
       * windows are handled separately from sockets in select()
       */
      if (status & Fs_Window) {
	 return 0;
	 }
      else 
#endif					/* Graphics */
      if ((fd = get_fd(*f, Fs_Read|Fs_Socket)) < 0) {
	 if (fd == -2)
	    return 212;
	 else
	   return 174;
         }
      }
   else
      return 105;

   if (*n < fd + 1)
      *n = fd + 1;
   FD_SET(fd, fdsp);
   return 0;
}

void post_if_ready(struct descrip *ldp, struct descrip *f, fd_set *fdsp)
{
   int fd, fromlen, status = BlkLoc(*f)->file.status;
   struct sockaddr_in from;

   if ((status & Fs_Socket) == 0) return;

   fd = get_fd(*f, Fs_Read|Fs_Socket);
   if ((fd!=-1) && FD_ISSET(fd, fdsp)) {
      /*
       * If its a listener socket, convert it to the new connection.
       */
      if (status & Fs_Listen) {
	 fromlen = sizeof(from);
	 if ((fd = accept(fd, (struct sockaddr *)&from, &fromlen)) < 0)
	    return;
	 BlkLoc(*f)->file.fd.fd = fd;
	 BlkLoc(*f)->file.status = Fs_Socket | Fs_Read | Fs_Write;
	 }
      c_put(ldp, f);
      }
}


"select() - wait for i/o to be available on files."

function{0,1} select(files[nargs])
   abstract {
      return new list(file)
      }
   body {
      int rv, status, acc_time = 0, check_time, clocks;
      int i, j, k=0, n=0, nset, nset_add=0;
      C_integer timeout = -1;
#if UNIX
      struct tms t;
      int base_time = times(&t), ctps = sysconf(_SC_CLK_TCK);
#else					/* UNIX */
      int base_time = clock(), ctps = CLOCKS_PER_SEC;
#endif					/* UNIX */
      fd_set fds;
      struct timeval tv, *ptv = &tv;
      tended struct b_list *lp = NULL;
      tended union block *ep;
      tended struct descrip d = nulldesc;
      tended struct descrip d2 = nulldesc;
      tended struct descrip f;
      tended struct b_list *lws = NULL;

      /*
       * prepass: pull out windows, into their own list
       */
#ifdef Graphics
      if ((lws = alclist(0, MinListSlots)) == NULL) fail;
      d2.dword = D_List;
      BlkLoc(d2) = (union block *)lws;
      for (k=0; k<nargs; k++) {
	 if (is:file(files[k]) && (BlkLoc(files[k])->file.status & Fs_Window))
	    c_put(&d2, files+k);
	 else if (is:list(files[k])) {
	    for (ep = BlkLoc(files[k])->list.listhead;
		 BlkType(ep) == T_Lelem; ep = ep->lelem.listnext) {
	       for (i = 0; i < ep->lelem.nused; i++) {
		  j = ep->lelem.first + i;
		  if (j >= ep->lelem.nslots)
		     j -= ep->lelem.nslots;
		  f = ep->lelem.lslots[j];
		  if (is:file(f) && BlkLoc(f)->file.status & Fs_Window)
		     c_put(&d2, &f);
		  }
	       }
	    }
	 }
#endif					/* Graphics */

      /*
       * Unicon select() repeats until a timeout or real result.
       * GUI activity requires periodic service while select() waits.
       *
       * Could pull a lot of redundant work out of this loop, such as
       * the calculation of the list of windows.
       */

      do {
	 n = 0;
	 FD_ZERO(&fds);			/* Set the fd's in the set */

	 for(k=0;k<nargs;k++) {
	    /* Traverse the list, build fd_set of sockets */
	    if (!is:list(files[k])) {
	       if ((k+1 == nargs) && is:integer(files[k]))
		  cnv:C_integer(files[k], timeout);
	       else
		  if (rv = set_if_selectable(files+k, &fds, &n))
		     runerr(rv, files[k]);
	       }
	    else
	       for (ep = BlkLoc(files[k])->list.listhead;
		    BlkType(ep) == T_Lelem; ep = ep->lelem.listnext) {
		  for (i = 0; i < ep->lelem.nused; i++) {
		     j = ep->lelem.first + i;
		     if (j >= ep->lelem.nslots)
		        j -= ep->lelem.nslots;
		     f = ep->lelem.lslots[j];
		     if (rv = set_if_selectable(&f, &fds, &n))
			runerr(rv, f);
		     }
	          }
	    }
      
      /* Set the tv struct */
      if (timeout < 0) {
#ifdef Graphics
	 /*
	  * if there are any windows, then even if we said to go forever
	  * timeout periodically to check for window events.
	  */
	 if (lws->size > 0) {
	    tv.tv_sec = 0;
	    tv.tv_usec = 50000;
	    }
	 else
#endif					/* Graphics */
	    ptv = 0;
         }
      else {
	 tv.tv_sec = timeout/1000;
	 tv.tv_usec = (timeout%1000)*1000;
	 }

      errno = 0;
      IntVal(amperErrno) = 0;

#ifdef Graphics
      if ((lws->size > 0) && ((lp = findactivewindow(lws)) != NULL)) {
	 d.dword = D_List;
	 BlkLoc(d) = (union block *) lp;
         tv.tv_sec = tv.tv_usec = 0;
	 }
#endif					/* Graphics */

      if (n) {
         if ((nset = select(n, &fds, NULL, NULL, ptv)) < 0) {
#if MSWIN32
	    IntVal(amperErrno) = WSAGetLastError();
#else
	    IntVal(amperErrno) = errno;
#endif
	    if (IntVal(amperErrno) != 0)
	       fail;
	    }

#ifdef Graphics
	 pollevent();

	 /*
	  * if our select() could have taken any time, try windows again
	  */
	 if ((lp == NULL) && ((lp = findactivewindow(lws)) != NULL)) {
	    d.dword = D_List;
	    BlkLoc(d) = (union block *) lp;
	    }
#endif					/* Graphics */
	 }
      else if (ptv && (ptv->tv_sec || ptv->tv_usec)) {
	 idelay(ptv->tv_sec * 1000 + ptv->tv_usec / 1000);
	 }

      if (lp == NULL) {
	 if ((lp = alclist(0, MinListSlots)) == NULL) fail;
         }

      d.dword = D_List;
      BlkLoc(d) = (union block *)lp;

      for(k=0;k<nargs;k++) {
	 if (is:file(files[k])) {

#ifdef HAVE_LIBZ
           if (BlkLoc(files[k])->file.status & Fs_Compress) { 
               fail;
               }
#endif					/* HAVE_LIBZ */
	    post_if_ready(&d, files+k, &fds);
	    }
         else if (is:integer(files[k])) {/* timeout */}
	 else {
            for (ep = BlkLoc(files[k])->list.listhead;
	         BlkType(ep) == T_Lelem;
	         ep = ep->lelem.listnext) {
	       for (i = 0; i < ep->lelem.nused; i++) {
	          j = ep->lelem.first + i;
	          if (j >= ep->lelem.nslots)
	             j -= ep->lelem.nslots;
	          f = ep->lelem.lslots[j];
		  if (is:file(f)) {
#ifdef HAVE_LIBZ
		     if (BlkLoc(files[k])->file.status & Fs_Compress) { 
	                fail;
	                }
#endif					/* HAVE_LIBZ */
		     post_if_ready(&d, &f, &fds);
		     }
	       }
	    }
          }
	 }
	 /*
	  * This little gem tries to check if the timeout has elapsed.
	  * On some buggy versions of linux, at least, the struct members
	  * that t points at don't get updated, although times()'s return
	  * value does show forward progress.  Use that return value,
	  * try to handle overflow.  More ifdef's will be needed here
	  * if times() return value doesn't work on some systems.
	  */
#if UNIX
	 clocks = times(&t);
#else					/* UNIX */
	 clocks = clock();
#endif					/* UNIX */
	 if (clocks > base_time) {
	    acc_time = clocks - base_time;
	    check_time = acc_time;
	    }
	 else {
	    check_time = clocks + acc_time;
	    }
      } while ((BlkLoc(d)->list.size == 0) &&
	       ((timeout < 0)||(check_time*1000/ctps<timeout)));

      Desc_EVValD(lp, E_Lcreate, D_List);
      return list(lp);
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

"sysread() - low level non-blocking read with no buffering."

function{0, 1} sysread(f, i)
   if !def:C_integer(i, 0) then
      runerr(101, i)

   if is:null(f) then
      inline {
	 f.dword = D_File;
	 BlkLoc(f) = (union block *)&k_input;
	 }
   else if !is:file(f) then
      runerr(105, f)

   abstract {
      return string
      }
   body {
      int status, fd;
      tended struct descrip desc;
      status = BlkLoc(f)->file.status;

      if (!status || !(status & Fs_Read) 
#ifdef Graphics
      || (status & Fs_Window)
#endif					/* Graphics */
          )
	  runerr(212, f);

      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);

      if (status & Fs_Buff)
	 runerr(1048, f);
      BlkLoc(f)->file.status = status;

      IntVal(amperErrno) = 0;
      if (u_read(fd, i, &desc) == 0)
	 fail;
      return desc;
   }
end

"syswrite() - low level write with no buffering."

function{0, 1} syswrite(f, s)
   if !cnv:string(s,s) then
      runerr(103, s)

   if is:null(f) then
      inline {
	 f.dword = D_File;
	 BlkLoc(f) = (union block *)&k_output;
	 }
   else if !is:file(f) then
      runerr(105, f)

   abstract {
      return integer
      }
   body {
      int status, fd, rc;
      tended struct descrip desc;
      status = BlkLoc(f)->file.status;

      if (!status || !(status & Fs_Write) 
#ifdef Graphics
      || (status & Fs_Window)
#endif					/* Graphics */
          )
	  runerr(213, f);

      if ((fd = get_fd(f, 0)) < 0)
	 runerr(174, f);
      
      if (status & Fs_Buff)
	 runerr(1048, f);
      BlkLoc(f)->file.status = status;
      
      IntVal(amperErrno) = 0;
      /* 
       * If applicable, use send for sockets so that we get the EPIPE
       * error code, rather than the SIGPIPE signal.
       */
#ifdef HAVE_MSG_NOSIGNAL
      if (status & Fs_Socket) 
         rc = send(fd, StrLoc(s), StrLen(s), MSG_NOSIGNAL);
      else
         rc = write(fd, StrLoc(s), StrLen(s));
#else
      rc = write(fd, StrLoc(s), StrLen(s));
#endif
      if (rc < 0) {
         IntVal(amperErrno) = errno;
         fail;
      }
      return C_integer(rc);
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




