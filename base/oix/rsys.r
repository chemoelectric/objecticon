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
 *  generally more than one millisecond and on some systems it may only
 *  be accurate to the second.
 */

#if UNIX && SIZEOF_CLOCK_T < 8

/*
 * For some unfathomable reason, the Open Group's "Single Unix Specification"
 *  requires that the ANSI C clock() function be defined in units of 1/1000000
 *  second.  This means that the result overflows a 32-bit signed clock_t
 *  value after only about 35 minutes.  So, under UNIX, we use the POSIX standard
 *  times() function instead, unless clock_t is 64 bits.
 */

word millisec()
   {
   static long clockres = 0;
   struct tms tp;

   if (clockres == 0)
       clockres = sysconf(_SC_CLK_TCK);

   times(&tp);
   return (word) ((1000.0 / clockres) * (tp.tms_utime + tp.tms_stime));
   }

#else

/*
 * On anything other than UNIX (or if clock_t is big enough), just use
 * the ANSI C clock() function.
 */

word millisec()
   {
   return (word) ((1000.0 / CLOCKS_PER_SEC) * clock());
   }

#endif
