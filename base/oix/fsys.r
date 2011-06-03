/*
 * File: fsys.r
 */


"exit(i) - exit process with status i, which defaults to 0."

function exit(status)
   if !def:C_integer(status, EXIT_SUCCESS) then
      runerr(101, status)
   body {
      c_exit((int)status);
      fail;
      }
end

"get_char() - return a character from console."

function io_Console_get_char(echo)
   body {
#if UNIX
#define STDIN 0
      struct termios otty, tty;
      char c;
      int n;

      if (!isflag(&echo))
          runerr(171, echo);

      tcgetattr(STDIN, &otty);		/* get current tty attributes */

      tty = otty;
      tty.c_lflag &= ~ICANON;
      if (is:null(echo))
          tty.c_lflag &= ~ECHO;
      else
          tty.c_lflag |= ECHO;

      tcsetattr(STDIN, TCSANOW, &tty);	/* set temporary attributes */

      n = read(STDIN, &c, 1);		/* read one char from stdin */

      tcsetattr(STDIN, TCSANOW, &otty);	/* reset tty to original state */

      if (n == 1)				/* if read succeeded */
          return string(1, &allchars[c & 0xFF]);
      else
          fail;
#else
      Unsupported;
#endif
      }
end

function io_Console_wait_char()
   body {
#if UNIX
#define STDIN 0
      struct termios otty, tty;
      fd_set fds;
      struct timeval tv;
      int rv;

      tcgetattr(STDIN, &otty);		/* get current tty attributes */

      tty = otty;
      tty.c_lflag &= ~ICANON;		/* disable input batching */
      tcsetattr(STDIN, TCSANOW, &tty);	/* set attribute temporarily */

      FD_ZERO(&fds);			/* initialize fd struct */
      FD_SET(STDIN, &fds);			/* set STDIN bit */
      tv.tv_sec = tv.tv_usec = 0;		/* set immediate return */
      rv = select(STDIN + 1, &fds, NULL, NULL, &tv);

      tcsetattr(STDIN, TCSANOW, &otty);	/* reset tty to original state */

      if (rv)
          return nulldesc;
      else 
          fail;
#else
     Unsupported;
#endif
     }
end

function io_Console_get_size()
   body {
#if UNIX
       tended struct descrip result;
       struct descrip t;
       struct winsize w;
       if (ioctl(0, TIOCGWINSZ, &w) < 0) {
           errno2why();
           fail;
       }
       create_list(2, &result);
       MakeInt(w.ws_col, &t);
       list_put(&result, &t);
       MakeInt(w.ws_row, &t);
       list_put(&result, &t);
       return result;
#else
       Unsupported;
#endif
     }
end

"chdir(s) - change working directory to s."
function io_Files_chdir(s)
   if !cnv:C_string(s) then
      runerr(103, s)

   body {
       if (chdir(s) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function io_Files_getcwd()
   body {
       int buff_size;
       char *buff;

       buff_size = 32;
       for (;;) {
           MemProtect(buff = alcstr(0, buff_size));
           if (getcwd(buff, buff_size)) {
               int len = strlen(buff);
               /* Success - free surplus and return */
               dealcstr(buff + len);
               return string(len, buff);
           }
           if (errno != ERANGE) {
               /* Failed; free buff and fail */
               dealcstr(buff);
               errno2why();
               fail;
           }
           /* Didn't fit (errno == ERANGE) - so deallocate buff,
            * increase buff_size and repeat */
           dealcstr(buff);
           buff_size *= 2;
       }
   }
end


"delay(i) - delay for i milliseconds."

function delay(n)
   if !cnv:C_integer(n) then
      runerr(101,n)
   body {
      if (n <= 0) 
          return nulldesc; /* delay < 0 = no delay */

#if UNIX
      {
      struct timeval t;
      t.tv_sec = n / 1000;
      t.tv_usec = (n % 1000) * 1000;
      select(1, NULL, NULL, NULL, &t);
      }
#elif MSWIN32
      Sleep(n);
#endif

      return nulldesc;
      }
end


"system(s) - execute string s as a system command."

function system(s)
   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
       return C_integer (word)system(s);
      }
end
