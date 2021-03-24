/*
 * File: fsys.r
 */


"exit(i) - exit process with status i, which defaults to 0."

function exit(status)
   if !def:C_integer(status, EXIT_SUCCESS) then
      runerr(101, status)
   body {
      if (curpstate->monitor &&
           Testb(E_Exit, curpstate->eventmask->bits)) {
           add_to_prog_event_queue(&nulldesc, E_Exit);
           curpstate->exited = 1;
           push_fatalerr_139_frame();
           return;
      }
      c_exit((int)status);
      fail;
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
       ReturnDefiningClass;
   }
end

function io_Files_getcwd()
   body {
       int buff_size;
       char *buff;

       buff_size = 32;
       for (;;) {
           MemProtect(buff = reserve(Strings, buff_size));
           if (getcwd(buff, buff_size)) {
               int len = strlen(buff);
               /* Success - confirm allocation and return */
               alcstr(NULL, len);
               return string(len, buff);
           }
           if (errno != ERANGE) {
               /* Failed */
               errno2why();
               fail;
           }
           /* Didn't fit (errno == ERANGE) - so increase buff_size and
            * repeat */
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
      poll(NULL, 0, n);
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
