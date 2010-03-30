/*
 * File: rsys.r
 */


/*
 * Print string referenced by descriptor d.
 */
int putstr(FILE *f, dptr d)
{
    return putn(f, StrLoc(*d), StrLen(*d));
}

/*
 * Put n chars from s to file f.
 */
int putn(FILE *f, char *s, int n)
{
    if (fwrite(s, 1, n, f) != n)
        return Failed;
    else
        return Succeeded;
}

/*
 * idelay(n) - delay for n milliseconds
 */
int idelay(int n)
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
#elif MSWIN32
   Sleep(n);
   return Succeeded;
#else					/* MSWIN32 */
   return Failed;
#endif					/* MSWIN32 */

}


/*
 * millisec - returns execution time in milliseconds. Time is measured
 *  from the function's first call. The granularity of the time is
 *  generally more than one millisecond and on some systems it my only
 *  be accurate to the second.
 */

#if UNIX

/*
 * For some unfathomable reason, the Open Group's "Single Unix Specification"
 *  requires that the ANSI C clock() function be defined in units of 1/1000000
 *  second.  This means that the result overflows a 32-bit signed clock_t
 *  value only about 35 minutes.  So, under UNIX, we use the POSIX standard
 *  times() function instead.
 */

static long cptime(void)
   {
   struct tms tp;
   times(&tp);
   return (long) (tp.tms_utime + tp.tms_stime);
   }

long millisec()
   {
   static long starttime = -2;
   long t;

   t = cptime();
   if (starttime == -2)
      starttime = t;
   return (long) ((1000.0 / sysconf(_SC_CLK_TCK)) * (t - starttime));
   }

#else					/* UNIX */

/*
 * On anything other than UNIX, just use the ANSI C clock() function.
 */

long millisec()
   {
   static clock_t starttime = -2;
   clock_t t;

   t = clock();
   if (starttime == -2)
      starttime = t;
   return (long) ((1000.0 / CLOCKS_PER_SEC) * (t - starttime));
   }

#endif					/* UNIX */
