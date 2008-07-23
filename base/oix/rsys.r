/*
 * File: rsys.r
 *  Contents: [flushrec], [getrec], getstrg, host, longread, [putrec], putstr
 */


#ifdef PosixFns
#ifndef SOCKET_ERROR
#define SOCKET_ERROR -1
#endif
/*
 * sock_getstrg - read a line into buf from socket.  
 *  At most maxi characters are read.  sock_getstrg returns the 
 *  length of the line, not counting the newline.  Returns -1 
 *  if EOF and -3 if a socket error occur.
 */
int sock_getstrg(buf, maxi, fd)
register char *buf;
int maxi;
SOCKET fd;
   {
   int r = 0, i=0;
   char *stmp=NULL;
  
   if ((r=recv(fd, buf, maxi, MSG_PEEK))==SOCKET_ERROR) {
#if NT
      if(WSAGetLastError() == WSAESHUTDOWN)   
	 return -1;
#endif					/* NT */
      k_errornumber = 1040;
      return -3;
      }
   if (r == 0) return -1;
   
   stmp = buf;
   while (stmp - buf < r) {
      if (*stmp == '\n') break;
      stmp++;
      }

   if (stmp - buf < r) {
      if(stmp == buf)
	 i = stmp - buf + 1;
      else
	 i = stmp - buf;
      }
   else  
      i = r;
   if ((r=recv(fd, buf, i, 0)) == SOCKET_ERROR) {
#if NT
      if (WSAGetLastError() == WSAESHUTDOWN)
	 return -1;
#endif					/* NT */
      k_errornumber = 1040;
      return -3;
      }
   return r;
   }
#endif					/* NT */

#if NT
#ifndef NTGCC
#define pclose _pclose
#endif
#endif

/*
 * getstrg - read a line into buf from file fbp.  At most maxi characters
 *  are read.  getstrg returns the length of the line, not counting the
 *  newline.  Returns -1 if EOF and -2 if length was limited by maxi.
 *  Discards \r before \n in translated mode.  [[ Needs ferror() check. ]]
 */
int getstrg(buf, maxi, fbp)
register char *buf;
int maxi;
struct b_file *fbp;
   {
   register int c, l;
   FILE *fd = fbp->fd.fp;

#ifdef PosixFns
   static char savedbuf[BUFSIZ];
   static int nsaved = 0;
#endif					/* PosixFns */

#ifdef XWindows
   wflushall();
#endif					/* XWindows */
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd) || (fgets(buf, maxi, fd) == NULL)) {
         pclose(fd);
	 fbp->status = 0;
         return -1;
         }
      l = strlen(buf);
      if (l>0 && buf[l-1] == '\n') l--;
      if (l>0 && buf[l-1] == '\r' && (fbp->status & Fs_Untrans) == 0) l--;
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         }
      return l;
      }
#endif					/* NT */

   l = 0;

#ifdef PosixFns
   /* If there are saved chars in the static buffer, use those */
   if (nsaved > 0) {
      strncpy(buf, savedbuf, nsaved);
      l = nsaved;
      buf += l;
   }
#endif

   while (1) {

#ifdef Graphics
      /* insert non-blocking read/code to service windows here */
#endif					/* Graphics */

#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
      if ((c = fgetc(fd)) == '\n') {	/* \n terminates line */
	 break;
         }

      if (c == '\r' && (fbp->status & Fs_Untrans) == 0) {
	 /* \r terminates line in translated mode */
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
	 if ((c = fgetc(fd)) != '\n')	/* consume following \n */
	     ungetc(c, fd);		/* (put back if not \n) */
	 break;
	 }
#if NT
   if (fbp->status & Fs_Pipe) {
      if (feof(fd)) {
         pclose(fd);
	 fbp->status = 0;
         if (l>0) return 1;
         else return -1;
         }
      }
#endif					/* NT */
      if (c == EOF) {
#if NT
         if (fbp->status & Fs_Pipe) {
            pclose(fd);
	    fbp->status = 0;
            }
#endif					/* NT */

#ifdef PosixFns
	 /* If errno is EAGAIN, we will not return any chars just yet */
	 if (errno == EAGAIN 
#if !NT
	    || errno == EWOULDBLOCK
#endif
	 ) {
	    return -1;
	 }
#endif					/* PosixFns */

	 if (l > 0) {
#ifdef PosixFns
	    /* Clear the saved chars buffer */
	    nsaved = 0;
#endif					/* PosixFns */
	    return l;
	    } 
	 else return -1;
	 }
      if (++l > maxi) {
	 ungetc(c, fd);
#ifdef PosixFns
	 /* Clear the saved chars buffer */
	 nsaved = 0;
#endif					/* PosixFns */
	 return -2;
	 }
#ifdef PosixFns
      savedbuf[nsaved++] = c;
#endif					/* PosixFns */
      *buf++ = c;
      }

#ifdef PosixFns
   /* We can clear the saved static buffer */
   nsaved = 0;
#endif					/* PosixFns */

   return l;
   }

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

#if NT
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* NT */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = fread(ts, width, (int)((len < MaxIn) ? len : MaxIn), fd);
      if (n <= 0) {
#if NT
         fseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if NT
   fseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
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

#if NT
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* NT */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = gzread(fd,ts, width * ((int)((len < MaxIn) ? len : MaxIn)));
      if (n <= 0) {
#if NT
         gzseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if NT
   gzseek(fd, pos + tally, SEEK_SET);
#endif					/* NT */
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

#ifdef MSWindows
#endif					/* MSWindows */
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

#ifdef PosixFns
   struct timeval tv;
   fd_set fds;
   tv.tv_sec = t/1000;
   tv.tv_usec = (t % 1000) * 1000;
#if !NT
   FD_ZERO(&fds);
#endif					/* NT */
   FD_SET(fd, &fds);
   return select(fd+1, &fds, NULL, NULL, &tv);
#else					/* PosixFns */
   return -1;
#endif					/* PosixFns */

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

#if MSDOS
#if SCCX_MX
   msleep(n);
   return Succeeded;
#else					/* SCCX_MX */
#if NT
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
#else					/* NT */
   return Failed;
#endif					/* NT */
#endif					/* SCCX_MX */
#endif					/* MSDOS */

#if PORT
   return Failed;
#endif	

   /*
    * End of operating-system dependent code.
    */
   }


#ifdef NTGCC

/* libc replacement functions for win32.

Copyright (C) 1992, 93 Free Software Foundation, Inc.

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Library General Public
License as published by the Free Software Foundation; either
version 2 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.

You should have received a copy of the GNU Library General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.  */

/*
  This does make sense only under WIN32.
  Functions:
    - popen() rewritten
    - pclose() rewritten
    - stat() wrapper for _stat(), removing trailing slashes
  */

struct _popen_elt {
  FILE *f;                      /* File stream returned */
  HANDLE hp;                    /* Handle of associated process */
  struct _popen_elt *next;      /* Next list element */
};

static struct _popen_elt _z = { NULL, 0, &_z };
static struct _popen_elt *_popen_list = &_z;

FILE *popen (const char* cmd, const char *mode)
/* [<][>][^][v][top][bottom][index][help] */
{
  STARTUPINFO si;
  PROCESS_INFORMATION pi;
  SECURITY_ATTRIBUTES sa = { sizeof(SECURITY_ATTRIBUTES), NULL, TRUE };
  FILE *f = NULL;
  int fno, i;
  HANDLE child_in, child_out;
  HANDLE father_in, father_out;
  HANDLE father_in_dup, father_out_dup;
  HANDLE current_in, current_out;
  HANDLE current_pid;
  int binary_mode;
  char *new_cmd, *app_name = NULL;
  char *p, *q;
  struct _popen_elt *new_process;
  char pname[MaxPath], *fp;
  char *suffixes[] = { ".bat", ".cmd", ".com", ".exe", NULL };
  char **s;
  int go_on;

  /* We should look for the application name along the PATH,
     and decide to prepend "%COMSPEC% /c " or not to the command line.
     Do nothing for the moment. */

  /* Another way to do that would be to try CreateProcess first without
     invoking cmd, and look at the error code. If it fails because of
     command not found, try to prepend "cmd /c" to the cmd line.
     */

  /* Look for the application name */
  for (p = cmd; *p && isspace(*p); p++);
  if (*p == '"') {
    q = ++p;
    while(*p && *p != '"') p++;
    if (*p != '\0') {
      fprintf(stderr, "popen: malformed command (\" not terminated)\n");
      return NULL;
    }
  }
  else
    for (q = p; *p && !isspace(*p); p++);
  /* q points to the beginning of appname, p to the last + 1 char */
  if ((app_name = malloc(p - q + 1)) == NULL) {
    fprintf(stderr, "xpopen: malloc(app_name) failed.\n");
    return NULL;
  }
  strncpy(app_name, q, p - q );
  app_name[p - q] = '\0';
  pname[0] = '\0';
#ifdef __TRACE
  fprintf(stderr, "popen: app_name = %s\n", app_name);
#endif

  /* Looking for appname on the path */
  for (s = suffixes, go_on = 1; go_on; *s++) {
    if (SearchPath(NULL,        /* Address of search path */
                   app_name,    /* Address of filename */
                   *s,          /* Address of extension */
                   sizeof(pname),    /* Size of destination buffer */
                   pname,       /* Address of destination buffer */
                   &fp)         /* File part of app_name */
      != 0) {
#ifdef __TRACE
      fprintf(stderr, "%s found with suffix %s\n", app_name, *s);
#endif
      new_cmd = strdup(cmd);
      free(app_name);
      app_name = strdup(pname);
      break;
    }
    go_on = (*s != NULL);
  }
  if (go_on == 0) {
    /* the app_name was not found */
#ifdef __TRACE
    fprintf(stderr, "%s not found, concatenating comspec\n", app_name);
#endif
    new_cmd = malloc(strlen(getenv("CONSPEC"))+4+strlen(cmd)+1);
    sprintf(new_cmd, "%s /c %s", getenv("COMSPEC"), cmd);
    free(app_name);
    app_name = NULL;
  }
  else {
  }
#ifdef __TRACE
  fprintf(stderr, "popen: app_name = %s\n", app_name);
  fprintf(stderr, "popen: cmd_line = %s\n", new_cmd);
#endif

  current_in = GetStdHandle(STD_INPUT_HANDLE);
  current_out = GetStdHandle(STD_OUTPUT_HANDLE);
  current_pid = GetCurrentProcess();
  ZeroMemory( &si, sizeof(STARTUPINFO) );
  si.cb = sizeof(STARTUPINFO);
  si.dwFlags = STARTF_USESTDHANDLES | STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;

  if (strchr(mode, 'b'))
    binary_mode = _O_BINARY;
  else
    binary_mode = _O_TEXT;

  /* Opening the pipe for writing */
  if (strchr(mode, 'w')) {
    binary_mode |= _O_WRONLY;
    if (CreatePipe(&child_in, &father_out, &sa, 0) == FALSE) {
      fprintf(stderr, "popen: error CreatePipe\n");
      return NULL;
    }
#if 0
    if (SetStdHandle(STD_INPUT_HANDLE, child_in) == FALSE) {
      fprintf(stderr, "popen: error SetStdHandle child_in\n");
      return NULL;
    }
#endif
    si.hStdInput = child_in;
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);

    if (DuplicateHandle(current_pid, father_out, 
                        current_pid, &father_out_dup, 
                        0, FALSE, DUPLICATE_SAME_ACCESS) == FALSE) {
      fprintf(stderr, "popen: error DuplicateHandle father_out\n");
      return NULL;
    }
    CloseHandle(father_out);
    fno = _open_osfhandle((long)father_out_dup, binary_mode);
    f = _fdopen(fno, mode);
    i = setvbuf( f, NULL, _IONBF, 0 );
  }
  /* Opening the pipe for reading */
  else if (strchr(mode, 'r')) {
    binary_mode |= _O_RDONLY;
    if (CreatePipe(&father_in, &child_out, &sa, 0) == FALSE) {
      fprintf(stderr, "popen: error CreatePipe\n");
      return NULL;
    }
#if 0
    if (SetStdHandle(STD_OUTPUT_HANDLE, child_out) == FALSE) {
      fprintf(stderr, "popen: error SetStdHandle child_out\n");
      return NULL;
    }
#endif
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = child_out;
    si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
    if (DuplicateHandle(current_pid, father_in, 
                        current_pid, &father_in_dup, 
                        0, FALSE, DUPLICATE_SAME_ACCESS) == FALSE) {
      fprintf(stderr, "popen: error DuplicateHandle father_in\n");
      return NULL;
    }
    CloseHandle(father_in);
    fno = _open_osfhandle((long)father_in_dup, binary_mode);
    f = _fdopen(fno, mode);
    i = setvbuf( f, NULL, _IONBF, 0 );
  }
  else {
    fprintf(stderr, "popen: invalid mode %s\n", mode);
    return NULL;
  }

  /* creating child process */
  if (CreateProcess(app_name,   /* pointer to name of executable module */
                    new_cmd,    /* pointer to command line string */
                    NULL,       /* pointer to process security attributes */
                    NULL,       /* pointer to thread security attributes */
                    TRUE,       /* handle inheritance flag */
                    CREATE_NEW_CONSOLE,         /* creation flags */
                    NULL,       /* pointer to environment */
                    NULL,       /* pointer to current directory */
                    &si,        /* pointer to STARTUPINFO */
                    &pi         /* pointer to PROCESS_INFORMATION */
                  ) == FALSE) {
    fprintf(stderr, "popen: CreateProcess %x\n", GetLastError());
    return NULL;
  }
  
#if 0
  /* Restoring saved values for stdin/stdout */
  if (SetStdHandle(STD_INPUT_HANDLE, current_in) == FALSE) 
    fprintf(stderr, "popen: error re-redirecting Stdin\n");  
  if (SetStdHandle(STD_OUTPUT_HANDLE, current_out) == FALSE) 
    fprintf(stderr, "popen: error re-redirecting Stdout\n");  
#endif  
   /* Only the process handle is needed */
  if (CloseHandle(pi.hThread) == FALSE) {
    fprintf(stderr, "popen: error closing thread handle\n");
    return NULL;
  }

  if (new_cmd) free(new_cmd);
  if (app_name) free(app_name);

#if 0
  /* This does not seem to make sense for console apps */
  while (1) {
    i = WaitForInputIdle(pi.hProcess, 5); /* Wait 5ms  */
    if (i == 0xFFFFFFFF) {
      fprintf(stderr, "popen: process can't initialize\n");
      return NULL;
    }
    else if (i == WAIT_TIMEOUT)
      fprintf(stderr, "popen: warning, process still not initialized\n");
    else
      break;
  }
#endif

  /* Add the pair (f, pi.hProcess) to the list */
  if ((new_process = malloc(sizeof(struct _popen_elt))) == NULL) {
    fprintf (stderr, "popen: malloc(new_process) error\n");
    return NULL;
  }
  /* Saving the FILE * pointer, access key for retrieving the process
     handle later on */
  new_process->f = f;
  /* Closing the unnecessary part of the pipe */
  if (strchr(mode, 'r')) {
    CloseHandle(child_out);
  }
  else if (strchr(mode, 'w')) {
    CloseHandle(child_in);
  }
  /* Saving the process handle */
  new_process->hp = pi.hProcess;
  /* Linking it to the list of popen() processes */
  new_process->next = _popen_list;
  _popen_list = new_process;

  return f;

}

int pclose (FILE * f)
/* [<][>][^][v][top][bottom][index][help] */
{
  struct _popen_elt *p, *q;
  int exit_code;

  /* Look for f is the access key in the linked list */
  for (q = NULL, p = _popen_list; 
       p != &_z && p->f != f; 
       q = p, p = p->next);

  if (p == &_z) {
    fprintf(stderr, "pclose: error, file not found.");
    return -1;
  }

  /* Closing the FILE pointer */
  fclose(f);

  /* Waiting for the process to terminate */
  if (WaitForSingleObject(p->hp, INFINITE) != WAIT_OBJECT_0) {
    fprintf(stderr, "pclose: error, process still active\n");
    return -1;
  }

  /* retrieving the exit code */
  if (GetExitCodeProcess(p->hp, &exit_code) == 0) {
    fprintf(stderr, "pclose: can't get process exit code\n");
    return -1;
  }

  /* Closing the process handle, this will cause the system to
     remove the process from memory */
  if (CloseHandle(p->hp) == FALSE) {
    fprintf(stderr, "pclose: error closing process handle\n");
    return -1;
  }

  /* remove the elt from the list */
  if (q != NULL)
    q->next = p->next;
  else
    _popen_list = p->next;
  free(p);
    
  return exit_code;
}
#endif
