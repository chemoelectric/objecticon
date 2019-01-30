/*
 * File: fsys.r
 */


"exit(i) - exit process with status i, which defaults to 0."
#if PLAN9
function exit(status)
   body {
      word i;
      tended char *s;
      if (curpstate->monitor &&
           Testb(E_Exit, curpstate->eventmask->bits)) {
           add_to_prog_event_queue(&nulldesc, E_Exit);
           curpstate->exited = 1;
           push_fatalerr_139_frame();
           return;
      }
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
#endif


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

#if !PLAN9
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
      if (n <= 0) 
          return nulldesc; /* delay < 0 = no delay */

#if PLAN9
      sleep(n);
#elif UNIX
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
