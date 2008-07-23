/*
 * File: rlocal.r
 * Routines needed for different systems.
 */

/*  IMPORTANT NOTE:  Because of the way RTL works, this file should not
 *  contain any includes of system files, as in
 *
 *	include <foo>
 *
 *  Instead, such includes should be placed in h/sys.h.
 */

/*
 * The following code is operating-system dependent [@rlocal.01].
 *  Routines needed by different systems.
 */

#if PORT
   /* place for anything system-specific */
Deliberate Syntax Error
#endif					/* PORT */



/*********************************** MSDOS ***********************************/

#if MSDOS
#if INTEL_386
/*  sbrk(incr) - adjust the break value by incr.
 *  Returns the new break value, or -1 if unsuccessful.
 */

pointer sbrk(incr)
msize incr;
{
   static pointer base = 0;		/* base of the sbrk region */
   static pointer endofmem, curr;
   pointer result;
   union REGS rin, rout;

   if (!base) {					/* if need to initialize				*/
      rin.w.eax = 0x80004800;	/* use DOS allocate function with max	*/
      rin.w.ebx = 0xffffffff;	/*  request to determine size of free	*/
      intdos(&rin, &rout);		/*  memory (including virtual memory.	*/
	  rin.w.ebx = rout.w.ebx;	/* DOS allocate all of memory.			*/
      intdos(&rin, &rout);
      if (rout.w.cflag)
         return (pointer)-1;
      curr = base = (pointer)rout.w.eax;
      endofmem = (pointer)((char *)base + rin.w.ebx);
      }
	
   if ((char *)curr + incr > (char *)endofmem)
      return (pointer)-1;
   result = curr;
   curr = (pointer)((char *)curr + incr);
   return result;

}

/*  brk(addr) - set the break address to the given value, rounded up to a page.
 *  returns 0 if successful, -1 if not.
 */

int brk(addr)
pointer addr;
{
   int result;
   result = sbrk((char *)addr - (char *)sbrk(0)) == (pointer)-1 ? -1 : 0;
   return result;
}

#endif					/* INTEL_386 */

#if TURBO
extern unsigned _stklen = 16 * 1024;
#endif					/* TURBO */

#endif					/* MSDOS */



/*********************************** UNIX ***********************************/

#if UNIX

/*
 * Documentation notwithstanding, the Unix versions of the keyboard functions
 * read from standard input and not necessarily from the keyboard (/dev/tty).
 */
#define STDIN 0

/*
 * int getch() -- read character without echoing
 * int getche() -- read character with echoing
 *
 * Read and return a character from standard input in non-canonical
 * ("cbreak") mode.  Return -1 for EOF.
 *
 * Reading is done even if stdin is not a tty;
 * the tty get/set functions are just rejected by the system.
 */

int rchar(int with_echo);

int getch(void)		{ return rchar(0); }
int getche(void)	{ return rchar(1); }

int rchar(int with_echo)
{
   struct termios otty, tty;
   char c;
   int n;

   tcgetattr(STDIN, &otty);		/* get current tty attributes */

   tty = otty;
   tty.c_lflag &= ~ICANON;
   if (with_echo)
      tty.c_lflag |= ECHO;
   else
      tty.c_lflag &= ~ECHO;
   tcsetattr(STDIN, TCSANOW, &tty);	/* set temporary attributes */

   n = read(STDIN, &c, 1);		/* read one char from stdin */

   tcsetattr(STDIN, TCSANOW, &otty);	/* reset tty to original state */

   if (n == 1)				/* if read succeeded */
      return c & 0xFF;
   else
      return -1;
}

/*
 * kbhit() -- return nonzero if characters are available for getch/getche.
 */
int kbhit(void)
{
   struct termios otty, tty;
   fd_set fds;
   struct timeval tv;
   int rv;

   tcgetattr(STDIN, &otty);		/* get current tty attributes */

   tty = otty;
   tty.c_lflag &= ~ICANON;		/* disable input batching */
   tcsetattr(STDIN, TCSANOW, &tty);	/* set attribute temporarily */

   FD_ZERO(&fds);			/* initialize fd struct */
   FD_SET(STDIN, &fds);			/* set STDIN bit */
   tv.tv_sec = tv.tv_usec = 0;		/* set immediate return */
   rv = select(STDIN + 1, &fds, NULL, NULL, &tv);

   tcsetattr(STDIN, TCSANOW, &otty);	/* reset tty to original state */

   return rv;				/* return result */
}

#endif					/* UNIX */
