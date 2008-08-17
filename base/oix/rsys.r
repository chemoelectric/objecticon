/*
 * File: rsys.r
 *  Contents: [flushrec], [getrec], getstrg, host, longread, [putrec], putstr
 */



#if MSWIN32
#ifndef NTGCC
#define pclose _pclose
#endif
#endif

/*
 * iconhost - return some sort of host name into the buffer pointed at
 *  by hostname.  This code accommodates several different host name
 *  fetching schemes.
 */
void iconhost(hostname)
char *hostname;
   {

#ifdef HostStr
   /*
    * The string constant HostStr contains the host name.
    */
   strcpy(hostname,HostStr);
#else					/* HostStr */
   {
   /*
    * Use the uname system call.  (POSIX)
    */
   struct utsname utsn;
   uname(&utsn);
   strcpy(hostname,utsn.nodename);
   }
#endif					/* HostStr */

   }

/*
 * Read a long string in shorter parts. (Standard read may not handle long
 *  strings.)
 */
word longread(s,width,len,fd)
FILE *fd;
int width;
char *s;
long len;
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if MSWIN32
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* MSWIN32 */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = fread(ts, width, (int)((len < MaxIn) ? len : MaxIn), fd);
      if (n <= 0) {
#if MSWIN32
         fseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if MSWIN32
   fseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
   return tally;
   }


#ifdef HAVE_LIBZ
/*
 * Read a long string in shorter parts from a comressed file. 
 * (Standard read may not handle long strings.)
 */
word gzlongread(s,width,len,fd)
FILE *fd;
int width;
char *s;
long len;
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if MSWIN32
   /*
    * Under WIN32/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* MSWIN32 */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = gzread(fd,ts, width * ((int)((len < MaxIn) ? len : MaxIn)));
      if (n <= 0) {
#if MSWIN32
         gzseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if MSWIN32
   gzseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
   return tally;
   }

#endif					/* HAVE_LIBZ */



/*
 * Print string referenced by descriptor d. Note, d must not move during
 *   a garbage collection.
 */

int putstr(f, d)
register FILE *f;
dptr d;
   {
   register char *s;
   register word l;
   register int  i;

   l = StrLen(*d);
   if (l == 0)
      return  Succeeded;
   s = StrLoc(*d);

   if (longwrite(s,l,f) < 0)
      return Failed;
   else
      return Succeeded;
   }

/*
 * Wait for input to become available on fd, with timeout of t ms
 */
iselect(fd, t)
int fd, t;
   {

   struct timeval tv;
   fd_set fds;
   tv.tv_sec = t/1000;
   tv.tv_usec = (t % 1000) * 1000;
#if !MSWIN32
   FD_ZERO(&fds);
#endif					/* MSWIN32 */
   FD_SET(fd, &fds);
   return select(fd+1, &fds, NULL, NULL, &tv);

   }

/*
 * idelay(n) - delay for n milliseconds
 */
int idelay(n)
int n;
   {
   if (n <= 0) return Succeeded; /* delay < 0 = no delay */

/*
 * The following code is operating-system dependent [@fsys.01].
 */

#if UNIX
   {
   struct timeval t;
   t.tv_sec = n / 1000;
   t.tv_usec = (n % 1000) * 1000;
   select(1, NULL, NULL, NULL, &t);
   return Succeeded;
   }
#endif					/* UNIX */

#if MSWIN32
#ifdef MSWindows
   Sleep(n);
#else					/* MSWindows */
   /*
    * In the old DOS documentation, sleep(n) took a # of seconds to sleep,
    * but VC++ 2.0's _sleep() seems to be taking milliseconds.
    */
   _sleep(n);

#endif					/* MSWindows */
   return Succeeded;
#else					/* MSWIN32 */
   return Failed;
#endif					/* MSWIN32 */

#if PORT
   return Failed;
#endif	

   /*
    * End of operating-system dependent code.
    */
   }


int file_readline(struct b_file *fbp, char *buf, int max)
{
    word status = fbp->status;
    if (status & Fs_Stdio) {
        FILE *fd = fbp->u.fp;
        int n = 0;
        while (n < max) {
            int c = fgetc(fd);
            if (c == EOF)
                break;
            buf[n++] = c;
            if (c == '\n')
                break;
        }
        if (ferror(fd))
            return -1;
        else
            return n;
    }
    if (status & Fs_Socket) {
        int r, i;
        r =  recv(fbp->u.sd, buf, max, MSG_PEEK);
        if (r <= 0)
            return r;
        max = r;
        for (i = 0; i < r; ++i) {
            if (buf[i] == '\n') {
                max = i + 1;
                break;
            }
        }
        return recv(fbp->u.sd, buf, max, 0);
    }
    if (status & Fs_Desc) {
        int n = 0;
        while (n < max) {
            char c;
            int rc = read(fbp->u.fd, &c, 1);
            if (rc < 0)
                return -1;
            if (rc == 0)
                break;
            buf[n++] = c;
            if (c == '\n')
                break;
        }
        return n;
    }
    if (status & Fs_Directory) {
        struct dirent *e;
        int len;
        errno = 0;
        e = readdir(fbp->u.dir);
        if (!e) {
            if (errno)
                return -1;
            else
                return 0;
        }
        len = strlen(e->d_name);
        if (len >= max) {
            errno = XE_DIRTOOLONG;
            return -1;
        }
        strcpy(buf, e->d_name);
        buf[len] = '\n';
        return len + 1;
    }
    errno = XE_NOTSUPPORTED;
    return -1;
}

int file_readstr(struct b_file *fbp, char *buf, int max)
{
    word status = fbp->status;
    if (status & Fs_Stdio) {
        FILE *fd = fbp->u.fp;
        int n = fread(buf, 1, max, fd);
        if (ferror(fd))
            return -1;
        else
            return n;
    }
    if (status & Fs_Socket)
        return recv(fbp->u.sd, buf, max, 0);
    if (status & Fs_Desc)
        return read(fbp->u.fd, buf, max);

    errno = XE_NOTSUPPORTED;
    return -1;
}

int file_outputstr(struct b_file *fbp, char *buf, int n)
{
    word status = fbp->status;
    if (status & Fs_Stdio) {
        FILE *fd = fbp->u.fp;
        n = fwrite(buf, 1, n, fd);
        if (ferror(fd))
            return -1;
        else
            return n;
    }
    if (status & Fs_Socket) {
        /* 
         * If possible use MSG_NOSIGNAL so that we get the EPIPE error
         * code, rather than the SIGPIPE signal.
         */
#ifdef HAVE_MSG_NOSIGNAL
        return send(fbp->u.sd, buf, n, MSG_NOSIGNAL);
#else
        return send(fbp->u.sd, buf, n, 0);
#endif
    }
    if (status & Fs_Desc)
        return write(fbp->u.fd, buf, n);

    errno = XE_NOTSUPPORTED;
    return -1;
}

int file_flush(struct b_file *fbp)
{
    word status = fbp->status;
    if (status & Fs_Stdio)
        return fflush(fbp->u.fp);
    return 0;
}

int file_close(struct b_file *fbp)
{
    word status = fbp->status;
    if (status & Fs_Prog)
        return pclose(fbp->u.fp);
    if (status & Fs_Stdio)
        return fclose(fbp->u.fp);
    if (status & Fs_Socket) {
#if MSWIN32
        return closesocket(fbp->u.sd);
#else					/* MSWIN32 */
        return close(fbp->u.sd);
#endif
    }
    if (status & Fs_Desc)
        return close(fbp->u.fd);
    if (status & Fs_Directory)
        return closedir(fbp->u.dir);
    return 0;
}

int file_seek(struct b_file *fbp, int offset, int whence)
{
    word status = fbp->status;
    if (status & Fs_Stdio) {
        int i = fseek(fbp->u.fp, offset, whence);
        if (i < 0)
            return i;
        return ftell(fbp->u.fp);
    }
    if (status & Fs_Desc)
        return lseek(fbp->u.fd, offset, whence);

    errno = XE_NOTSUPPORTED;
    return -1;
}

int file_tell(struct b_file *fbp)
{
    word status = fbp->status;
    if (status & Fs_Stdio)
        return ftell(fbp->u.fp);
    if (status & Fs_Desc)
        return lseek(fbp->u.fd, 0, SEEK_CUR);

    errno = XE_NOTSUPPORTED;
    return -1;
}

int file_fd(struct b_file *fbp)
{
    word status = fbp->status;

    if (status & Fs_Stdio)
        return fileno(fbp->u.fp);
    if (status & Fs_Socket)
        return (int)fbp->u.sd;
    if (status & Fs_Desc)
        return fbp->u.fd;
    if (status & Fs_Directory)
        return dirfd(fbp->u.dir);

    errno = XE_NOTSUPPORTED;
    return -1;
}


struct sockaddr *parse_sockaddr(char *s, int *len)
{
    if (strncmp(s, "unix:", 5) == 0) {
        static struct sockaddr_un us;
        char *t = s + 5;
        if (strlen(t) >= sizeof(us.sun_path)) {
            errno = XE_NAMETOOLONG;
            return 0;
        }
        us.sun_family = AF_UNIX;
        strcpy(us.sun_path, t);
        *len = sizeof(us.sun_family) + strlen(us.sun_path);
        return (struct sockaddr *)&us;
    } 

    if (strncmp(s, "inet:", 5) == 0) {
        static struct sockaddr_in iss;
        char *t = s + 5, host[128], *p;
        int port;
        struct hostent *hp;

        if (strlen(t) >= sizeof(host)) {
            errno = XE_NAMETOOLONG;
            return 0;
        }
        strcpy(host, t);
        p = strchr(host, ':');
        if (!p) {
            errno = XE_BADADDRFMT;
            return 0;
        }
        *p++ = 0;
        port = atoi(p);
        iss.sin_family = AF_INET;
        iss.sin_port = htons((u_short)port);
        if (strcmp(host, "INADDR_ANY") == 0)
            iss.sin_addr.s_addr = INADDR_ANY;
        else {
            if ((hp = gethostbyname(host)) == NULL) {
                switch (h_errno) {
                    case HOST_NOT_FOUND: errno = XE_HOSTNOTFOUND ; break;
                    case NO_DATA: errno = XE_NOIPADDR ; break;
                    case NO_RECOVERY: errno = XE_NAMESRVERR ; break;
                    case TRY_AGAIN: errno = XE_TMPNAMESRVERR ; break;
                    default: errno = XE_UNKNOWN ; break;
                }
                return 0;
            }
            memcpy(&iss.sin_addr, hp->h_addr, hp->h_length);
        }
        *len = sizeof(iss);
        return (struct sockaddr *)&iss;
    }

    errno = XE_BADADDRFMT;
    return 0;
}

