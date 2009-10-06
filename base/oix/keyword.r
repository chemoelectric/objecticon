/*
 * File: keyword.r
 *  Contents: all keywords
 *
 *  After adding keywords, be sure to rerun ../icont/mkkwd.
 */


"&clock - a string consisting of the current time of day"
keyword{2} clock
   abstract {
      return string
      }
   inline {
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
keyword{1} current
   abstract {
      return coexpr
      }
   inline {
       return coexpr(k_current);
      }
end

"&date - the current date"
keyword{1} date
   abstract {
      return string
      }
   inline {
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
keyword{2} dateline
   abstract {
      return string
      }
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
keyword{1} digits
   body {
    return cset(k_digits);
   }
end

"&error - enable/disable error conversion"
keyword{1} error
   abstract {
      return kywdint
      }
   inline {
      return kywdint(&kywd_err);
      }
end

"&errornumber - error number of last error converted to failure"
keyword{0,1} errornumber
   abstract {
      return integer
      }
   inline {
      if (k_errornumber == 0)
         fail;
      return C_integer k_errornumber;
      }
end

"&errortext - error message of last error converted to failure"
keyword{0,1} errortext
   abstract {
      return string
      }
   inline {
      if (k_errornumber == 0)
         fail;
      return k_errortext;
      }
end

"&errorvalue - erroneous value of last error converted to failure"
keyword{0,1} errorvalue
   abstract {
      return any_value
      }
   inline {
      if (have_errval)
         return k_errorvalue;
      else
         fail;
      }
end

"&fail - just fail"
keyword{0} fail
   abstract {
      return empty_type
      }
   inline {
      fail;
      }
end

"&eventcode - event in monitored program"
keyword{0,1} eventcode
   abstract {
      return kywdany
      }
   inline {
       return nulldesc;
      }
end

"&eventsource - source of events in monitoring program"
keyword{0,1} eventsource
   abstract {
      return kywdany
      }
   inline {
       return nulldesc;
      }
end

"&eventvalue - value from event in monitored program"
keyword{0,1} eventvalue
   abstract {
      return kywdany
      }
   inline {
       return nulldesc;
      }
end

"&features - generate strings identifying features in this version of Icon"
keyword{1,*} features
   abstract {
      return string
      }
   body {
#define Feature(guard,sym,kwval) if (kwval) suspend C_string kwval;
#include "../h/features.h"
      fail;
      }
end

"&file - name of the source file for the current execution point"
keyword{1} file
   abstract {
      return string
      }
   inline {
      struct ipc_fname *pfile;
      pfile = frame_ipc_fname(PF, 1);
      if (!pfile)
          fail;
      return pfile->fname;
      }
end

"&host - a string that identifies the host computer Icon is running on."
keyword{1} host
   abstract {
     return string
     }
   inline {
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
keyword{1} lcase
   body {
    return cset(k_lcase);
   }
end

"&letters - a cset consisting of the 52 letters"
keyword{1} letters
   body {
    return cset(k_letters);
   }
end

"&level - level of procedure call."
keyword{1} level
   abstract {
      return integer
      }

   inline {
      return C_integer k_level;
      }
end

"&line - source line number of current execution point"
keyword{1} line
   abstract {
      return integer;
      }
   inline {
      struct ipc_line *pline;

      pline = frame_ipc_line(PF, 1);
      if (!pline)
          fail;

      return C_integer pline->line;
      }
end

"&main - the main co-expression."
keyword{1} main
   abstract {
      return coexpr
      }
   inline {
       return coexpr(k_main);
      }
end

"&null - the null value."
keyword{1} null
   abstract {
      return null
      }
   inline {
      return nulldesc;
      }
end

"&pos - a variable containing the current focus in string scanning."
keyword{1} pos
   abstract {
      return kywdpos
      }
    inline {
      return kywdpos(&kywd_pos);
      }
end

"&progname - a variable containing the program name."
keyword{1} progname
   abstract {
      return kywdstr
      }
    inline {
      return kywdstr(&kywd_prog);
      }
end

"&random - a variable containing the current seed for random operations."
keyword{1} random
   abstract {
      return kywdint
      }
   inline {
      return kywdint(&kywd_ran);
      }
end

"&source - the co-expression that invoked the current co-expression."
keyword{1} source
   abstract {
       return coexpr
       }
   inline {
         return coexpr(k_current->activator);
         }
end

"&subject - variable containing the current subject of string scanning."
keyword{1} subject
   abstract {
      return kywdsubj
      }
   inline {
      return kywdsubj(&k_subject);
      }
end

"&time - the elapsed execution time in milliseconds."
keyword{1} time
   abstract {
      return integer
      }
   inline {
      /*
       * &time in this program = total time - time spent in other programs
       */
      return C_integer millisec() - curpstate->Kywd_time_elsewhere;
      }
end

"&trace - variable that controls procedure tracing."
keyword{1} trace
   abstract {
      return kywdint
      }
   inline {
      return kywdint(&kywd_trc);
      }
end

"&dump - variable that controls termination dump."
keyword{1} dump
   abstract {
      return kywdint
      }
   inline {
      return kywdint(&kywd_dmp);
      }
end

"&ucase - a cset consisting of the 26 uppercase characters."
keyword{1} ucase
   body {
    return cset(k_ucase);
   }
end

"&version - a string indentifying this version of Icon."
keyword{1} version
   body {
    LitStr(Version, &result);
    return result;
   }
end

"&ascii - a cset consisting of the 128 ascii characters"
keyword{1} ascii
   body {
    return cset(k_ascii);
   }
end

"&cset - a cset consisting of the first 256 characters."
keyword{1} cset
   body {
    return cset(k_cset);
   }
end

"&uset - a cset consisting of all the unicode characters."
keyword{1} uset
   body {
    return cset(k_uset);
   }
end

"&why - a string giving information about the cause of failure"
keyword{1} why
   abstract {
      return kywdstr
      }
    inline {
      return kywdstr(&kywd_why);
      }
end

"&yes - the standard flag value for yes."
keyword{1} yes
   abstract {
      return integer;
      }
   inline {
      return C_integer 1;
      }
end

"&no - the standard flag value for no."
keyword{1} no
   abstract {
      return null
      }
   inline {
      return nulldesc;
      }
end
