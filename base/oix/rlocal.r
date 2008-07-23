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


/*********************************** MAC ***********************************/

#if MACINTOSH
#if MPW
/*
 * Special routines for Macintosh Programmer's Workshop (MPW) implementation
 *  of the Icon Programming Language
 */

#include <Types.h>
#include <Events.h>
#include <Files.h>
#include <FCntl.h>
#include <IOCtl.h>
#include <SANE.h>
#include <OSUtils.h>
#include <Memory.h>
#include <Errors.h>
#include "time.h"
#include <QuickDraw.h>
#include <ToolUtils.h>
#include <CursorCtl.h>

#define isatty(fd) (!ioctl((fd), FIOINTERACTIVE))

   void
SetFileToMPWText(const char *fname) {
   FInfo info;
   int needToSet = 0;
 
   if (getfinfo(fname,0,&info) == 0) {
      if (info.fdType == 0) {
	 info.fdType = 'TEXT';
	 needToSet = 1;
	 }
      if (info.fdCreator == 0) {
	 info.fdCreator = 'MPS ';
	 needToSet = 1;
	 }
      if (needToSet) {
	 setfinfo(fname,0,&info);
	 }
      }
   return;
   }


   int
MPWFlush(FILE *f) {
   static int fetched = 0;
   static char *noLineFlush;

   if (!fetched) {
      noLineFlush = getenv("NOLINEFLUSH");
      fetched = 1;
      }
   if (!noLineFlush || noLineFlush[0] == '\0')
         fflush(f);
   return 0;
   }


   void
SetFloatTrap(void (*fpetrap)()) {
   /* This is equivalent to SIGFPE signal in the Standard Apple
      Numeric Environment (SANE) */
   environment e;

   getenvironment(&e);
      #ifdef mc68881
	 e.FPCR |= CURUNDERFLOW|CUROVERFLOW|CURDIVBYZERO;
      #else					/* mc68881 */
	 e |= UNDERFLOW|OVERFLOW|DIVBYZERO;
      #endif					/* mc68881 */
   setenvironment(e);
   #ifdef mc68881
      {
      static trapvector tv =
         {fpetrap,fpetrap,fpetrap,fpetrap,fpetrap,fpetrap,fpetrap};
      settrapvector(&tv);
      }
   #else					/* mc68881 */
      sethaltvector((haltvector)fpetrap);
   #endif					/* mc68881 */
   }


   void
SetWatchCursor(void) {
   SetCursor(*GetCursor(watchCursor));	/* Set watch cursor */
   }


#define TicksPerRotation 10 /* rotate cursor no more often than 6 times
				 per second */

   void
RotateTheCursor(void) {
   static unsigned long nextRotate = 0;
   if (TickCount() >= nextRotate) {
      RotateCursor(0);
      nextRotate = TickCount() + TicksPerRotation;
      }
   else {
      RotateCursor(1);
      }
   }

/*
 *  Initialization and Termination Routines
 */

/*
 *  MacExit -- This function is installed by an atexit() call in MacInit
 *  -- it is called automatically when the program terminates.
 */
   void
MacExit() {
   void ResetStack();
   extern Ptr MemBlock;

   ResetStack();
   /* if (MemBlock != NULL) DisposPtr(MemBlock); */
   }

/*
 *  MacInit -- This function is called near the beginning of execution of
 *  iconx.  It is called by our own brk/sbrk initialization routine.
 */
   void
MacInit() {
   atexit(MacExit);
   return;
   }

/*
 * MacDelay -- Delay n milliseconds.
 */
   void
MacDelay(int n) {
   unsigned long endTicks;
   unsigned long nextRotate;

   endTicks = TickCount() + (n * 3 + 25) / 50;
   nextRotate = 0;
   while (TickCount() < endTicks) {
      if (TickCount() >= nextRotate) {
         nextRotate = TickCount() + TicksPerRotation;
	 RotateCursor(0);
         }
      else {
         RotateCursor(1);
	 }
      }
   }
#endif					/* MPW */
#endif					/* MACINTOSH */

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
