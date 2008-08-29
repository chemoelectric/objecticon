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
	 Protect(p = alcstr(p,l),runerr(0));
	 return string(l,p);
	 }
      else 				/* fail if not in environment */
	 fail;

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
#if MSWIN32
#define rmdir _rmdir
#endif					/* MSWIN32 */
	 if (rmdir(s) != 0) {
            on_error(errno);
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
