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
int putn(FILE *f, char *s, size_t n)
{
    if (fwrite(s, 1, n, f) != n)
        return Failed;
    else
        return Succeeded;
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
 *  value after only about 35 minutes.  So, under UNIX, we use the POSIX standard
 *  times() function instead.
 */

long millisec()
   {
   static long clockres = 0;
   struct tms tp;

   if (clockres == 0)
       clockres = sysconf(_SC_CLK_TCK);

   times(&tp);
   return (long) ((1000.0 / clockres) * (tp.tms_utime + tp.tms_stime));
   }

#elif PLAN9

long millisec()
{
    long t[4];
    times(t);
    return t[0] + t[1];
}


#else

/*
 * On anything other than UNIX, just use the ANSI C clock() function.
 */

long millisec()
   {
   return (long) ((1000.0 / CLOCKS_PER_SEC) * clock());
   }

#endif					/* UNIX */
