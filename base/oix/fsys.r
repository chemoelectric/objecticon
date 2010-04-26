/*
 * File: fsys.r
 */


"exit(i) - exit process with status i, which defaults to 0."
#if PLAN9
function exit(status)
   body {
      word i;
      tended char *s;
      if (is:null(status))
         c_exit(EXIT_SUCCESS);
      else if (cnv:C_integer(status, i))
         c_exit((int)i);
      else if (cnv:C_string(status, s))
         c_exits(s);
      else
         runerr(170, status);
      /* not reached */
      fail;
      }
end

#else
function exit(status)
   if !def:C_integer(status, EXIT_SUCCESS) then
      runerr(101, status)
   body {
      c_exit((int)status);
      fail;
      }
end
#endif


"getch() - return a character from console."

function io_Keyboard_getch()
   body {
      int i;
      i = getch();
      if (i<0 || i>255)
	 fail;
      return string(1, &allchars[i & 0xFF]);
      }
end

"getche() -- return a character from console with echo."

function io_Keyboard_getche()
   body {
      int i;
      i = getche();
      if (i<0 || i>255)
	 fail;
      return string(1, &allchars[i & 0xFF]);
      }
end


"kbhit() -- Check to see if there is a keyboard character waiting to be read."

function io_Keyboard_kbhit()
   body {
      if (kbhit())
	 return nulldesc;
      else fail;
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

#if PLAN9
function io_Files_getcwd()
   body {
       int buff_size, fd, n, len;
       char *buff;

       fd = open(".", OREAD);
       if (fd < 0) {
           errno2why();
           fail;
       }

       buff_size = 32;
       for (;;) {
           MemProtect(buff = alcstr(0, buff_size));
           n = fd2path(fd, buff, buff_size);
           if (n != 0) {
               /* Failed; free buff and fail */
               dealcstr(buff);
               errno2why();
               close(fd);
               fail;
           }
           len = strlen(buff);
           if (len <= buff_size - 6) {
               /* Success - free surplus and return */
               close(fd);
               dealcstr(buff + len);
               return string(len, buff);
           }
           /* Didn't fit - so deallocate buff, increase buff_size and
            * repeat */
           dealcstr(buff);
           buff_size *= 2;
       }
   }
end
#else
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
#endif

"delay(i) - delay for i milliseconds."

function delay(n)

   if !cnv:C_integer(n) then
      runerr(101,n)

   body {
      if (idelay(n) == Failed)
        fail;
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
