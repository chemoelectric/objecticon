/*
 * File: fsys.r
 *  Contents: close, chdir, exit, getenv, open, read, reads, remove, rename,
 *  [save], seek, stop, system, where, write, writes, [getch, getche, kbhit]
 */

/*
 * The following code is operating-system dependent [@fsys.01]. Include
 *  system-dependent files and declarations.
 */

#if PORT
   /* nothing to do */
Deliberate Syntax Error
#endif					/* PORT */

#if MSWIN32 || UNIX
   /* nothing to do */
#endif			

/*
 * End of operating-system specific code.
 */


"flush(f) - flush file f."

function{1} flush(f)
   if !is:file(f) then
      runerr(105, f)
   body {
       int rc;

       if (!(BlkLoc(f)->file.status & Fs_Write))
          runerr(213, f);

       IntVal(amperErrno) = 0;
       rc = file_flush(&BlkLoc(f)->file);
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       /*
        * Return the flushed file.
        */
       return f;
   }
end

"close(f) - close file f."

function{1} close(f)
   if !is:file(f) then
      runerr(105, f)
   body {
       int rc;

       /* A double-close succeeds and returns the file */
       if (BlkLoc(f)->file.status & Fs_Closed)
           return f;

       IntVal(amperErrno) = 0;
       rc = file_close(&BlkLoc(f)->file);
       BlkLoc(f)->file.status = Fs_Closed;
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       /*
        * Return the closed file.
        */
       return f;
   }
end

"seek(f, offset, whence) - seek to offset in file f."
" whence can be SEEK_SET (the default), SEEK_CUR or SEEK_END"

function{0,1} seek(f, offset, whence)
   if !is:file(f) then
      runerr(105,f)

   if !cnv:C_integer(offset) then
      runerr(101, offset)

   if !def:C_integer(whence, SEEK_SET) then
      runerr(101, whence)

   body {
       int rc;
       if (!(BlkLoc(f)->file.status & (Fs_Read | Fs_Write)))
          runerr(217, f);

       IntVal(amperErrno) = 0;
       rc = file_seek(&BlkLoc(f)->file, offset, whence);
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       return C_integer rc;
   }
end

"tell(f) - return current offset position in file f."

function{0,1} tell(f)

   if !is:file(f) then
      runerr(105,f)

   abstract {
      return integer
      }

   body {
       int rc;

       if (!(BlkLoc(f)->file.status & (Fs_Read | Fs_Write)))
          runerr(217, f);

       IntVal(amperErrno) = 0;
       rc = file_tell(&BlkLoc(f)->file);
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       return C_integer rc;
   }
end


#undef exit
#passthru #undef exit

"exit(i) - exit process with status i, which defaults to 0."

function{} exit(status)
   if !def:C_integer(status, EXIT_SUCCESS) then
      runerr(101, status)
   inline {
      c_exit((int)status);
      fail;
      }
end


"getenv(s) - return contents of environment variable s."

function{0,1} getenv(s)

   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)
   abstract {
      return string
      }

   inline {
      register char *p;
      long l;

      if ((p = getenv(s)) != NULL) {	/* get environment variable */
	 l = strlen(p);
	 Protect(p = alcstr(p,l),runerr(0));
	 return string(l,p);
	 }
      else 				/* fail if not in environment */
	 fail;

      }
end


"open(s1, s2) - open file named s1 with options s2"
" and attributes given in trailing arguments."
function{0,1} open(fname, spec)
   if !cnv:string(fname) then
      runerr(103, fname)

   /*
    * spec defaults to "r".
    */
   if !def:string(spec, letr) then
      runerr(103, spec)

   abstract {
      return file
      }

   body {
       tended char *fnamestr, *specstr;
       tended struct b_file *fl;
       int status;
       char mode[16], *s;
       FILE *f;

       /*
        * get a C string for the file name and spec
        */
       if (!cnv:C_string(fname, fnamestr))
           runerr(103,fname);

       if (!cnv:C_string(spec, specstr))
           runerr(103,spec);

       status = Fs_Stdio;
       s = specstr;
       while (*s) {
           switch (tolower(*s++)) {
               case 'a':
                   status |= Fs_Write;
                   break;
               case 'r':
                   status |= Fs_Read;
                   break;
               case 'w':
                   status |= Fs_Write;
                   break;
               case '+':
                   status |= Fs_Read | Fs_Write;
                   break;
               case 'b':
                   break;
               default:
                   runerr(209, spec);
           }
       }

       IntVal(amperErrno) = 0;

       f = fopen(fnamestr, specstr);
       if (!f) {
           IntVal(amperErrno) = errno;
           fail;
       }
       Protect(fl = alcfile(status, &fname), runerr(0));
       fl->u.fp = f;
       return file(fl);
   }
end

function{0,1} open2(path, flags, mode)
   if !cnv:string(path) then
      runerr(103, path)

   if !cnv:C_integer(flags) then
      runerr(101, flags)

   if !def:C_integer(mode, 0) then
      runerr(101, mode)

   abstract {
      return file
      }

   body {
       int status = Fs_Desc, fd;
       tended char *pathstr;
       tended struct b_file *fl;

       if (!cnv:C_string(path, pathstr))
           runerr(103, path);

       if (flags & O_RDWR)
           status |= Fs_Read | Fs_Write;
       else if (flags & O_WRONLY)
           status |= Fs_Write;
       else
           status |= Fs_Read;

       IntVal(amperErrno) = 0;
       fd = open(pathstr, flags, mode);
       if (fd < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       Protect(fl = alcfile(status, &path), runerr(0));
       fl->u.fd = fd;
       return file(fl);
   }
end

function{0,1} fflag(f, on, off)
    if !is:file(f) then
      runerr(105, f)

    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
        int fd, i;
        
        if (BlkLoc(f)->file.status & Fs_Closed)
            runerr(218, f);

        IntVal(amperErrno) = 0;

        if ((fd = file_fd(&BlkLoc(f)->file)) < 0) {
            IntVal(amperErrno) = errno;
            fail;
        }
        if ((i = fcntl(fd, F_GETFL, 0)) < 0) {
           IntVal(amperErrno) = errno;
           fail;
        }
        if (on || off) {
            i = (i | on) & (~off);
            if (fcntl(fd, F_SETFL, i) < 0) {
                IntVal(amperErrno) = errno;
                fail;
            }
        }

        return C_integer i;
    }
end

function{1} fstatus(f)
    if !is:file(f) then
      runerr(105, f)
    body {
        return C_integer BlkLoc(f)->file.status;
    }
end

function{0,1} popen(cmd, spec)
   if !cnv:string(cmd) then
      runerr(103, cmd)

   /*
    * spec defaults to "r".
    */
   if !def:string(spec, letr) then
      runerr(103, spec)

   body {
       tended char *cmdstr, *specstr;
       tended struct b_file *fl;
       FILE *f;
       int status = Fs_Stdio | Fs_Prog;

       /*
        * get a C string for the command and spec
        */
       if (!cnv:C_string(cmd, cmdstr))
           runerr(103,cmd);

       if (!cnv:C_string(spec, specstr))
           runerr(103,spec);

       if (strcmp(specstr, "r") == 0)
           status |= Fs_Read;
       else if (strcmp(specstr, "w") == 0)
           status |= Fs_Write;
       else
           runerr(209, spec);

       IntVal(amperErrno) = 0;

       f = popen(cmdstr, specstr);
       if (!f) {
           IntVal(amperErrno) = errno;
           fail;
       }

       Protect(fl = alcfile(status, &cmd), runerr(0));
       fl->u.fp = f;
       return file(fl);
   }

end

function{0,1} opendir(dname)
   if !cnv:string(dname) then
      runerr(103, dname)

   body {
       tended char *dnamestr;
       tended struct b_file *fl;
       DIR *f;

       /*
        * get a C string for the dir.
        */
       if (!cnv:C_string(dname, dnamestr))
           runerr(103, dname);

       IntVal(amperErrno) = 0;

       f = opendir(dnamestr);
       if (!f) {
           IntVal(amperErrno) = errno;
           fail;
       }

       Protect(fl = alcfile(Fs_Read | Fs_Directory, &dname), runerr(0));
       fl->u.dir = f;
       return file(fl);
   }
end

#if MSWIN32
#define pipe(x) _pipe(x, 4096, O_BINARY|O_NOINHERIT)
#endif

"pipe() - create a pipe."

function{0,1} pipe()
   body {
      int fds[2];
      struct descrip fname;
      tended struct descrip f;
      tended struct b_file *fl;

      IntVal(amperErrno) = 0;
      if (pipe(fds) < 0) {
          IntVal(amperErrno) = errno;
          fail;
      }

      result = create_list(2);

      /*
       * The name is simply "pipe".
       */
      MakeCStr("pipe", &fname);

      Protect(fl = alcfile(Fs_Desc | Fs_Read, &fname), runerr(0));
      fl->u.fd = fds[0];
      f.dword = D_File;
      BlkLoc(f) = (union block *)fl;
      c_put(&result, &f);

      Protect(fl = alcfile(Fs_Desc | Fs_Write, &fname), runerr(0));
      fl->u.fd = fds[1];
      BlkLoc(f) = (union block *)fl;
      c_put(&result, &f);

      return result;
   }
end

function{0,1} socket(domain, typ)
   if !def:C_integer(domain, PF_INET) then
      runerr(101, domain)

   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       SOCKET sockfd;
       struct descrip fname;
       tended struct b_file *fl;

       IntVal(amperErrno) = 0;
       sockfd = socket(domain, typ, 0);
       if (sockfd < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       /*
        * The name is simply "socket".
        */
       MakeCStr("socket", &fname);

       /*
        * Allocate and return a new file structure.
        */
       Protect(fl = alcfile(Fs_Socket | Fs_Read | Fs_Write, &fname), runerr(0));
       fl->u.sd = sockfd;
       return file(fl);
   }
end

function{0,1} socketpair(typ)
   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       int fds[2];
       struct descrip fname;
       tended struct descrip f;
       tended struct b_file *fl;

       IntVal(amperErrno) = 0;

       if (socketpair(AF_UNIX, typ, 0, fds) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

      result = create_list(2);

      /*
       * The name is simply "socket".
       */
      MakeCStr("socket", &fname);

      Protect(fl = alcfile(Fs_Socket | Fs_Read, &fname), runerr(0));
      fl->u.fd = fds[0];
      f.dword = D_File;
      BlkLoc(f) = (union block *)fl;
      c_put(&result, &f);

      Protect(fl = alcfile(Fs_Socket | Fs_Write, &fname), runerr(0));
      fl->u.fd = fds[1];
      BlkLoc(f) = (union block *)fl;
      c_put(&result, &f);

      return result;
   }
end

function{0,1} connect(f, addr)
   if !is:file(f) then
      runerr(105, f)
   
   if !cnv:string(addr) then
      runerr(103, addr)

   body {
       tended char *addrstr;
       struct sockaddr *sa;
       int len;

       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       /*
        * get a C string for the address.
        */
       if (!cnv:C_string(addr, addrstr))
           runerr(103, addr);

       IntVal(amperErrno) = 0;

       sa = parse_sockaddr(addrstr, &len);
       if (!sa) {
           IntVal(amperErrno) = errno;
           fail;
       }

       if (connect(BlkLoc(f)->file.u.sd, sa, len) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       /*
        * Update the file's name field to represent the connected
        * address.
        */
       BlkLoc(f)->file.fname = addr;

       return f;
   }
end

function{0,1} bind(f, addr)
   if !is:file(f) then
      runerr(105, f)
   
   if !cnv:string(addr) then
      runerr(103, addr)

   body {
       tended char *addrstr;
       struct sockaddr *sa;
       int len;

       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       /*
        * get a C string for the address.
        */
       if (!cnv:C_string(addr, addrstr))
           runerr(103, addr);

       IntVal(amperErrno) = 0;

       sa = parse_sockaddr(addrstr, &len);
       if (!sa) {
           IntVal(amperErrno) = errno;
           fail;
       }

       if (bind(BlkLoc(f)->file.u.sd, sa, len) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       /*
        * Update the file's name field to represent the connected
        * address.
        */
       BlkLoc(f)->file.fname = addr;

       return f;
   }
end

function{0,1} listen(f, backlog)
   if !is:file(f) then
      runerr(105, f)
   
   if !cnv:C_integer(backlog) then
      runerr(101, backlog)

   body {
       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       IntVal(amperErrno) = 0;
       if (listen(BlkLoc(f)->file.u.sd, backlog) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       return f;
   }
end

function{0,1} accept(f)
   if !is:file(f) then
      runerr(105, f)
   body {
       struct descrip fname;
       tended struct b_file *fl;
       SOCKET sockfd;

       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       IntVal(amperErrno) = 0;
       if ((sockfd = accept(BlkLoc(f)->file.u.sd, 0, 0)) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       MakeCStr("accepted socket", &fname);

       /*
        * Allocate and return a new file structure.
        */
       Protect(fl = alcfile(Fs_Socket | Fs_Read | Fs_Write, &fname), runerr(0));
       fl->u.sd = sockfd;
       return file(fl);
   }
end

function{0,1} sendto(f)
   if !is:file(f) then
      runerr(105, f)

    body {
       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       fail;
    }
end

function{0,1} recvfrom(f)
   if !is:file(f) then
      runerr(105, f)

    body {
       if (!(BlkLoc(f)->file.status & Fs_Socket))
           runerr(1050, f);

       fail;
    }
end

"flock() - apply or remove a lock on a file."

function{0,1} flock(f, operation)
   if !is:file(f) then
      runerr(105, f)

   if !cnv:C_integer(operation) then
      runerr(101, operation)

   body {
       int fd;
       if (BlkLoc(f)->file.status & Fs_Closed)
           runerr(218, f);

       IntVal(amperErrno) = 0;
       if ((fd = file_fd(&BlkLoc(f)->file)) < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }

       if (flock(fd, operation) < 0) {
          IntVal(amperErrno) = errno;
          fail;
       }
       return f;
   }
end

static int list2fd_set(dptr l, dptr tmpl, fd_set *s)
{
    tended struct descrip e;

    FD_ZERO(s);
    if (is:null(*l))
        return 0;
    if (!is:list(*l)) {
        err_msg(108, l);
        return -1;
    }
    *tmpl = create_list(BlkLoc(*l)->list.size);

    while (c_get(&BlkLoc(*l)->list, &e)) {
        int fd;
        if (!is:file(e)) {
            err_msg(105, &e);
            return -1;
        }
        if (BlkLoc(e)->file.status & Fs_Closed) {
            err_msg(218, &e);
            return -1;
        }
        if ((fd = file_fd(&BlkLoc(e)->file)) < 0)
            return -1;
        c_put(tmpl, &e);
        FD_SET(fd, s);
    }
    /*printf("#elements in l:%d\n",BlkLoc(*l)->list.size);*/
    return 0;
}

static void fd_set2list(dptr l, dptr tmpl, fd_set *s)
{
    tended struct descrip e;

    if (is:null(*l))
        return;

    while (c_get(&BlkLoc(*tmpl)->list, &e)) {
        int fd;
        if ((fd = file_fd(&BlkLoc(e)->file)) < 0)
            /* Should never happen ... */
            continue;
        if (FD_ISSET(fd, s))
            c_put(l, &e);
    }
    /*printf("#elements in l:%d\n",BlkLoc(*l)->list.size);*/
}

function{0,1} select(rl, wl, el, timeout)
    body {
       fd_set rset, wset, eset;
       struct timeval tv, *ptv;
       tended struct descrip rtmp, wtmp, etmp;
       int rc;

       IntVal(amperErrno) = 0;

       if ((list2fd_set(&rl, &rtmp, &rset) < 0) ||
           (list2fd_set(&wl, &wtmp, &wset) < 0) ||
           (list2fd_set(&el, &etmp, &eset) < 0)) {
           IntVal(amperErrno) = errno;
           fail;
       }

       if (is:null(timeout))
           ptv = 0;
       else {
           C_integer t;
           if (!cnv:C_integer(timeout, t))
               runerr(101, timeout);
           tv.tv_sec = t / 1000;
           tv.tv_usec = (t % 1000) * 1000;
           ptv = &tv;
       }

       rc = select(FD_SETSIZE, &rset, &wset, &eset, ptv);
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           fail;
       }
       /* A rc of zero means timeout; we fail with a custom &errno */
       if (rc == 0) {
           IntVal(amperErrno) = XE_TIMEOUT;
           fail;
       }

       fd_set2list(&rl, &rtmp, &rset);
       fd_set2list(&wl, &wtmp, &wset);
       fd_set2list(&el, &etmp, &eset);

       return C_integer rc;
    }
end

"Poll one or more files for i/o using the poll function."
" The arguments should be of the form file1, events1, file2,"
" events2, etc.  The last argument is the timeout, which will"
" default to -1 if not present.   The result is a list of "
" all the revents values corresponding to the files"

function{0,1} poll(a[n])
   body {
#ifdef HAVE_POLL
       struct pollfd *ufds;
       unsigned int nfds;
       int timeout, i, rc;

       nfds = n / 2;
       if (n % 2 == 0)
           timeout = -1;
       else {
           if (!cnv:C_integer(a[n - 1], timeout))
               runerr(101, a[n - 1]);
       }

       Protect(ufds = calloc(nfds, sizeof(struct pollfd)), runerr(0));
       IntVal(amperErrno) = 0;
       for (i = 0; i < nfds; ++i) {
           int events, fd;
           if (!is:file(a[2 * i])) {
               free(ufds);
               runerr(105, a[2 * i]);
           }
           if (BlkLoc(a[2 * i])->file.status & Fs_Closed) {
               free(ufds);
               runerr(218, a[2 * i]);
           }
           if (!cnv:C_integer(a[2 * i + 1], events)) {
               free(ufds);
               runerr(101, a[2 * i + 1]);
           }
           if ((fd = file_fd(&BlkLoc(a[2 * i])->file)) < 0) {
               free(ufds);
               IntVal(amperErrno) = errno;
               fail;
           }
           ufds[i].fd = fd;
           ufds[i].events = events;
       }

       rc = poll(ufds, nfds, timeout);
       if (rc < 0) {
           free(ufds);
           IntVal(amperErrno) = errno;
           fail;
       }
       /* A rc of zero means timeout; we fail with a custom &errno */
       if (rc == 0) {
           free(ufds);
           IntVal(amperErrno) = XE_TIMEOUT;
           fail;
       }

       result = create_list(nfds);
       for (i = 0; i < nfds; ++i) {
           struct descrip tmp;
           MakeInt(ufds[i].revents, &tmp);
           c_put(&result, &tmp);
       }

       free(ufds);

       return result;
#else
       runerr(121);
#endif  /* HAVE_POLL */
   }
end

"read(f) - read line on file f."

function{0,1} read(f)
   /*
    * Default f to &input.
    */
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
       tended struct descrip s;
       static char sbuf[MaxReadStr];
       char *sp;

       if (!(BlkLoc(f)->file.status & Fs_Read))
           runerr(212, f);

       IntVal(amperErrno) = 0;
       StrLen(s) = 0;
       for (;;) {
           int nread;
           nread = file_readline(&BlkLoc(f)->file, sbuf, sizeof(sbuf));
           if (nread < 0) {
               IntVal(amperErrno) = errno;
               fail;
           }
           if (nread == 0) {
               if (StrLen(s) == 0) {
                   IntVal(amperErrno) = XE_EOF;
                   fail;
               } else
                   break;
           }
           Protect(reserve(Strings, nread), runerr(0));
           if (StrLen(s) > 0 && !InRange(strbase, StrLoc(s),strfree)) {
               Protect(reserve(Strings, StrLen(s) + nread), runerr(0));
               Protect((StrLoc(s) = alcstr(StrLoc(s), StrLen(s))), runerr(0));
           }
           Protect(sp = alcstr(sbuf, nread), runerr(0));
           if (StrLen(s) == 0)
               StrLoc(s) = sp;
           StrLen(s) += nread;

           if (StrLoc(s)[StrLen(s) - 1] == '\n') {
               --StrLen(s);
               if (StrLen(s) > 0 &&  StrLoc(s)[StrLen(s) - 1] == '\r')
                   --StrLen(s);
               break;
           }
       }
       return s;
   }
end


"reads(f,i) - read i characters on file f."
  "The number of chars returned may be less than i, but will be > 0"

function{0,1} reads(f,i)
   /*
    * Default f to &input.
    */
   if is:null(f) then
      inline {
	 f.dword = D_File;
	 BlkLoc(f) = (union block *)&k_input;
	 }
   else if !is:file(f) then
      runerr(105, f)

   /*
    * i defaults to 1 (read a single character)
    */
   if !def:C_integer(i,1L) then
      runerr(101, i)

   abstract {
      return string
      }

   body {
       int nread;
       tended struct descrip s;

       if (!(BlkLoc(f)->file.status & Fs_Read))
           runerr(212, f);

       /*
        * Be sure that a positive number of bytes is to be read.
        */
       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }

       /*
        * For now, assume we can read the full number of bytes.
        */
       Protect(StrLoc(s) = alcstr(NULL, i), runerr(0));

       IntVal(amperErrno) = 0;

       nread = file_readstr(&BlkLoc(f)->file, StrLoc(s), i);
       if (nread < 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           IntVal(amperErrno) = errno;
           fail;
       }

       if (nread == 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           IntVal(amperErrno) = XE_EOF;
           fail;
       }

       StrLen(s) = nread;
       /*
        * We may not have used the entire amount of storage we reserved.
        */
       strtotal += DiffPtrs(StrLoc(s) + nread, strfree);
       strfree = StrLoc(s) + nread;

       return s;
   }
end


"remove(s) - remove the file named s."

function{0,1} remove(s)

   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)
   abstract {
      return null
      }

   inline {
      if (remove(s) != 0) {
	 IntVal(amperErrno) = 0;
#if MSWIN32
#define rmdir _rmdir
#endif					/* MSWIN32 */
	 if (rmdir(s) != 0) {
	    IntVal(amperErrno) = errno;
	    fail;
            }
	 fail;
         }
      return nulldesc;
      }
end


"rename(s1,s2) - rename the file named s1 to have the name s2."

function{0,1} rename(s1,s2)

   /*
    * Make C-style strings out of s1 and s2
    */
   if !cnv:C_string(s1) then
      runerr(103,s1)
   if !cnv:C_string(s2) then
      runerr(103,s2)

   abstract {
      return null
      }

   body {
#if MSWIN32
      int i=0;
      if ((i = rename(s1,s2)) != 0) {
	 remove(s2);
	 if (rename(s1,s2) != 0)
	    fail;
	 }
      return nulldesc;
#else					/*NT*/
      if (rename(s1,s2) != 0)
	 fail;
      return nulldesc;
#endif					/* MSWIN32 */
      }
end


/*
 * stop(), write(), and writes() differ in whether they stop the program
 *  and whether they output newlines. The macro GenWrite is used to
 *  produce all three functions.
 */
#define False 0
#define True 1

#begdef GenWrite(name, nl, terminate)

#name "(a,b,...) - write arguments"
#if !nl
   " without newline terminator"
#endif
#if terminate
   " (starting on error output) and stop"
#endif
"."

#if terminate
function {} name(x[nargs])
#else
function {1} name(x[nargs])
#endif

  body {
    tended struct descrip t;
    tended struct descrip f;
    int rc, n, count = 0;

    if (nargs == 0 || !is:file(x[0])) {
        f.dword = D_File;
        #if terminate
        BlkLoc(f) = (union block *)&k_errout;
        #else
        BlkLoc(f) = (union block *)&k_output;
        #endif
        n = 0;
    } else {
        f = x[0];
        n = 1;
    }

    if (!(BlkLoc(f)->file.status & Fs_Write))
        runerr(213, f);

    IntVal(amperErrno) = 0;
    /*
     * Loop through the arguments.
     */
    for (; n < nargs; n++) {
        /*
         * Convert the argument to a string, defaulting to a empty
         *  string.
         */
        if (!def:tmp_string(x[n],emptystr,t))
            runerr(109, x[n]);

        rc = file_outputstr(&BlkLoc(f)->file, StrLoc(t), StrLen(t));
        if (rc < 0) {
            IntVal(amperErrno) = errno;
            #if terminate
            c_exit(EXIT_FAILURE);
            #else
            fail;
            #endif
        }
        count += rc;
        if (rc < StrLen(t)) {
            #if terminate
            c_exit(EXIT_FAILURE);
            #else
            return C_integer count;
            #endif
        }
    }

    #if nl
      /*
       * Append a newline to the file and flush.
       */
       rc = file_outputstr(&BlkLoc(f)->file, "\n", 1);
       if (rc < 0) {
           IntVal(amperErrno) = errno;
           #if terminate
           c_exit(EXIT_FAILURE);
           #else
           fail;
           #endif
       }
       count += rc;
       if (file_flush(&BlkLoc(f)->file) < 0) {
           IntVal(amperErrno) = errno;
           #if terminate
           c_exit(EXIT_FAILURE);
           #else
           fail;
           #endif
       }
    #endif

    #if terminate
    c_exit(EXIT_FAILURE);
    #else
    return C_integer count;
    #endif
  }
end
#enddef					/* GenWrite */

GenWrite(stop,	 True,	True)  /* stop(s, ...) - write message and stop */
GenWrite(write,  True,	False) /* write(s, ...) - write with new-line */
GenWrite(writes, False, False) /* writes(s, ...) - write with no new-line */


"getch() - return a character from console."

function{0,1} getch()
   abstract {
      return string;
      }
   body {
      int i;
      i = getch();
      if (i<0 || i>255)
	 fail;
      return string(1, (char *)&allchars[FromAscii(i) & 0xFF]);
      }
end

"getche() -- return a character from console with echo."

function{0,1} getche()
   abstract {
      return string;
      }
   body {
      int i;
      i = getche();
      if (i<0 || i>255)
	 fail;
      return string(1, (char *)&allchars[FromAscii(i) & 0xFF]);
      }
end


"kbhit() -- Check to see if there is a keyboard character waiting to be read."

function{0,1} kbhit()
   abstract {
      return null
      }
   inline {
      if (kbhit())
	 return nulldesc;
      else fail;
      }
end


"chdir(s) - change working directory to s."
function{0,1} chdir(s)
   if !cnv:string(s) then
       if !is:null(s) then
	  runerr(103, s)
   abstract {
      return string
   }
   body {

#if PORT
   Deliberate Syntax Error
#endif                                  /* PORT */

#if MSWIN32 || UNIX

      char path[MaxPath];
      int len;

      if (is:string(s)) {
	 tended char *dir;
	 cnv:C_string(s, dir);
	 if (chdir(dir) != 0)
	    fail;
	 }
      if (getcwd(path, sizeof(path)) == NULL)
	  fail;

      len = strlen(path);
      Protect(StrLoc(result) = alcstr(path, len), runerr(0));
      StrLen(result) = len;
      return result;

#endif
   }
end


"delay(i) - delay for i milliseconds."

function{0,1} delay(n)

   if !cnv:C_integer(n) then
      runerr(101,n)
   abstract {
      return null
      }

   inline {
      if (idelay(n) == Failed)
        fail;
#ifdef Graphics
      pollctr >>= 1;
      pollctr++;
#endif					/* Graphics */
      return nulldesc;
      }
end

