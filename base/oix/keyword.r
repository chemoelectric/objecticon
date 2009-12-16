/*
 * File: keyword.r
 *  Contents: all keywords
 *
 *  After adding keywords, be sure to rerun ../icont/mkkwd.
 */


"&clock - a string consisting of the current time of day"
keyword clock
   body {
      time_t t;
      struct tm *ct;
      char sbuf[9], *tmp;

      time(&t);
      ct = localtime(&t);
      sprintf(sbuf,"%02d:%02d:%02d", ct->tm_hour, ct->tm_min, ct->tm_sec);
      MemProtect(tmp = alcstr(sbuf,(word)8));
      return string(8, tmp);
      }
end

"&current - the currently active co-expression"
keyword current
   body {
       return coexpr(k_current);
      }
end

"&date - the current date"
keyword date
   body {
      time_t t;
      struct tm *ct;
      char sbuf[11], *tmp;

      time(&t);
      ct = localtime(&t);
      sprintf(sbuf, "%04d/%02d/%02d",
         1900 + ct->tm_year, ct->tm_mon + 1, ct->tm_mday);
      MemProtect(tmp = alcstr(sbuf,(word)10));
      return string(10, tmp);
      }
end

"&dateline - current date and time"
keyword dateline
   body {
      static char *day[] = {
         "Sunday", "Monday", "Tuesday", "Wednesday",
         "Thursday", "Friday", "Saturday"
         };
      static char *month[] = {
         "January", "February", "March", "April", "May", "June",
         "July", "August", "September", "October", "November", "December"
         };
      time_t t;
      struct tm *ct;
      char sbuf[256];
      int hour;
      char *merid, *tmp;
      int i;

      time(&t);
      ct = localtime(&t);
      if ((hour = ct->tm_hour) >= 12) {
         merid = "pm";
         if (hour > 12)
            hour -= 12;
         }
      else {
         merid = "am";
         if (hour < 1)
            hour += 12;
         }
      sprintf(sbuf, "%s, %s %d, %d  %d:%02d %s", day[ct->tm_wday],
         month[ct->tm_mon], ct->tm_mday, 1900 + ct->tm_year, hour,
         ct->tm_min, merid);
       i = strlen(sbuf);
       MemProtect(tmp = alcstr(sbuf, i));
       return string(i, tmp);
       }
end

"&digits - a cset consisting of the 10 decimal digits"
keyword digits
   body {
    return cset(k_digits);
   }
end

"&error - enable/disable error conversion"
keyword error
   body {
      return kywdint(&kywd_err);
      }
end

"&errornumber - error number of last error converted to failure"
keyword errornumber
   body {
      if (k_errornumber == 0)
         fail;
      return C_integer k_errornumber;
      }
end

"&errortext - error message of last error converted to failure"
keyword errortext
   body {
      if (k_errornumber == 0)
         fail;
      return k_errortext;
      }
end

"&errorvalue - erroneous value of last error converted to failure"
keyword errorvalue
   body {
      if (have_errval)
         return k_errorvalue;
      else
         fail;
      }
end

"&fail - just fail"
keyword fail
   body {
      fail;
      }
end

"&features - generate strings identifying features in this version of Icon"
keyword features
   body {
#define Feature(guard,sym,kwval) if (kwval) suspend C_string kwval;
#include "../h/features.h"
      fail;
      }
end

"&file - name of the source file for the current execution point"
keyword file
   body {
      struct ipc_fname *pfile;
      pfile = frame_ipc_fname(curr_pf);
      if (!pfile)
          fail;
      return *pfile->fname;
      }
end

"&host - a string that identifies the host computer Icon is running on."
keyword host
   body {
#ifdef HAVE_UNAME
       struct utsname utsn;
       if (uname(&utsn) < 0) {
           errno2why();
           fail;
       }
       cstr2string(utsn.nodename, &result);
#else
       char buff[256];
       if (gethostname(buff, sizeof(buff)) < 0) {
           errno2why();
           fail;
       }
       cstr2string(buff, &result);
#endif
       return result;
      }
end

"&lcase - a cset consisting of the 26 lower case letters"
keyword lcase
   body {
    return cset(k_lcase);
   }
end

"&letters - a cset consisting of the 52 letters"
keyword letters
   body {
    return cset(k_letters);
   }
end

"&level - level of procedure call."
keyword level

   body {
      return C_integer k_level;
      }
end

"&line - source line number of current execution point"
keyword line
   body {
      struct ipc_line *pline;

      pline = frame_ipc_line(curr_pf);
      if (!pline)
          fail;

      return C_integer pline->line;
      }
end

"&main - the main co-expression."
keyword main
   body {
       return coexpr(k_main);
      }
end

"&null - the null value."
keyword null
   body {
      return nulldesc;
      }
end

"&pos - a variable containing the current focus in string scanning."
keyword pos
    body {
      return kywdpos(&kywd_pos);
      }
end

"&progname - a variable containing the program name."
keyword progname
    body {
      return kywdstr(&kywd_prog);
      }
end

"&random - a variable containing the current seed for random operations."
keyword random
   body {
      return kywdint(&kywd_ran);
      }
end

"&source - the co-expression that invoked the current co-expression."
keyword source
   body {
         return coexpr(k_current->activator);
         }
end

"&subject - variable containing the current subject of string scanning."
keyword subject
   body {
      return kywdsubj(&k_subject);
      }
end

"&time - the elapsed execution time in milliseconds."
keyword time
   body {
      /*
       * &time in this program = total time - time spent in other programs
       */
      return C_integer millisec() - curpstate->Kywd_time_elsewhere;
      }
end

"&trace - variable that controls procedure tracing."
keyword trace
   body {
      return kywdint(&kywd_trace);
      }
end

"&maxlevel - variable that controls procedure tracing."
keyword maxlevel
   body {
      return kywdint(&kywd_maxlevel);
      }
end

"&dump - variable that controls termination dump."
keyword dump
   body {
      return kywdint(&kywd_dump);
      }
end

"&ucase - a cset consisting of the 26 uppercase characters."
keyword ucase
   body {
    return cset(k_ucase);
   }
end

"&version - a string indentifying this version of Icon."
keyword version
   body {
    LitStr(Version, &result);
    return result;
   }
end

"&ascii - a cset consisting of the 128 ascii characters"
keyword ascii
   body {
    return cset(k_ascii);
   }
end

"&cset - a cset consisting of the first 256 characters."
keyword cset
   body {
    return cset(k_cset);
   }
end

"&uset - a cset consisting of all the unicode characters."
keyword uset
   body {
    return cset(k_uset);
   }
end

"&why - a string giving information about the cause of failure"
keyword why
    body {
      return kywdstr(&kywd_why);
      }
end

"&yes - the standard flag value for yes."
keyword yes
   body {
    return onedesc;
      }
end

"&no - the standard flag value for no."
keyword no
   body {
      return nulldesc;
      }
end
