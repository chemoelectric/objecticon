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
	 MemProtect(p = alcstr(p,l));
	 return string(l,p);
	 }
      else 				/* fail if not in environment */
	 fail;

      }
end


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
      return string(1, (char *)&allchars[i & 0xFF]);
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
      return string(1, (char *)&allchars[i & 0xFF]);
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
   body {
       int buff_size, rc;
       char *buff;

       if (!is:null(s)) {
           tended char *dir;
           if (!cnv:C_string(s, dir))
               runerr(103, s);
           if (chdir(dir) < 0) {
               errno2why();
               fail;
           }
       }

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


"system(s) - execute string s as a system command."

function{1} system(s)
   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)

   abstract {
      return integer
      }

   inline {
      /*
       * Pass the C string to the system() function and return
       * the exit code of the command as the result of system().
       * Note, the expression on a "return" may not have side effects,
       * so the exit code must be returned via a variable.
       */
      C_integer i;

#ifdef Graphics
      pollctr >>= 1;
      pollctr++;
#endif                                  /* Graphics */

      i = (C_integer)system(s);
      return C_integer i;
      }
end
