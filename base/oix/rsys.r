/*
 * File: rsys.r
 *  Contents: [flushrec], [getrec], getstrg, host, longread, [putrec], putstr
 */



#if MSWIN32
#ifndef NTGCC
#define pclose _pclose
#endif
#endif


/*
 * Read a long string in shorter parts. (Standard read may not handle long
 *  strings.)
 */
word longread(char *s, int width, long len, FILE *fd)
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if MSWIN32
   /*
    * Under NT/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* MSWIN32 */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = fread(ts, width, (int)((len < MaxIn) ? len : MaxIn), fd);
      if (n <= 0) {
#if MSWIN32
         fseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if MSWIN32
   fseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
   return tally;
   }


#ifdef HAVE_LIBZ
/*
 * Read a long string in shorter parts from a comressed file. 
 * (Standard read may not handle long strings.)
 */
word gzlongread(char *s, int width, long len, FILE *fd)
{
   tended char *ts = s;
   long tally = 0;
   long n = 0;

#if MSWIN32
   /*
    * Under WIN32/MSVC++, ftell() used in Icon where() returns bad answers
    * after a wlongread().  We work around it here by fseeking after fread.
    */
   long pos = ftell(fd);
#endif					/* MSWIN32 */

#ifdef XWindows
   if (isatty(fileno(fd))) wflushall();
#endif					/* XWindows */

   while (len > 0) {
      n = gzread(fd,ts, width * ((int)((len < MaxIn) ? len : MaxIn)));
      if (n <= 0) {
#if MSWIN32
         gzseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
         return tally;
	 }
      tally += n;
      ts += n;
      len -= n;
      }
#if MSWIN32
   gzseek(fd, pos + tally, SEEK_SET);
#endif					/* MSWIN32 */
   return tally;
   }

#endif					/* HAVE_LIBZ */



/*
 * Print string referenced by descriptor d. Note, d must not move during
 *   a garbage collection.
 */

int putstr(f, d)
register FILE *f;
dptr d;
   {
   register char *s;
   register word l;

   l = StrLen(*d);
   if (l == 0)
      return  Succeeded;
   s = StrLoc(*d);

   if (fwrite(s,1,l,f) != l)
      return Failed;
   else
      return Succeeded;
   }

/*
 * Wait for input to become available on fd, with timeout of t ms
 */
int iselect(int fd, word t)
   {

   struct timeval tv;
   fd_set fds;
   tv.tv_sec = t/1000;
   tv.tv_usec = (t % 1000) * 1000;
#if !MSWIN32
   FD_ZERO(&fds);
#endif					/* MSWIN32 */
   FD_SET(fd, &fds);
   return select(fd+1, &fds, NULL, NULL, &tv);

   }

/*
 * idelay(n) - delay for n milliseconds
 */
int idelay(n)
int n;
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
#endif					/* UNIX */

#if MSWIN32
#ifdef MSWindows
   Sleep(n);
#else					/* MSWindows */
   /*
    * In the old DOS documentation, sleep(n) took a # of seconds to sleep,
    * but VC++ 2.0's _sleep() seems to be taking milliseconds.
    */
   _sleep(n);

#endif					/* MSWindows */
   return Succeeded;
#else					/* MSWIN32 */
   return Failed;
#endif					/* MSWIN32 */

#if PORT
   return Failed;
#endif	

   /*
    * End of operating-system dependent code.
    */
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

static long cptime()
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
   return (long) ((1000.0 / CLK_TCK) * (t - starttime));
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
