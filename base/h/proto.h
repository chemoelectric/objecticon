/*
 * proto.h -- prototypes for library functions.
 */

/*
 * The following code is operating-system dependent. [@proto.01].
 *  Prototypes for library functions.
 */

#if PORT
   Deliberate Syntax Error
#endif					/* PORT */

#if MSDOS
   #if HIGHC_386
      int	brk		(pointer p);
      pointer sbrk		(msize n);
   #endif				/* HIGHC_386 */
   #if INTEL_386
      #include <dos.h>
      int	brk		(pointer p);
   #endif				/* INTEL_386 */
   #if MICROSOFT || TURBO || ZTC_386 || WATCOM || NT || BORLAND_286 || BORLAND_386
#ifndef LCC
      #include <dos.h>
#endif					/* not LCC */
   #endif				/* MICROSOFT || TURBO || ZTC_386 ... */
#endif					/* MSDOS */

/*
 * End of operating-system specific code.
 */

#ifdef MSWindows
   #if BORLAND_286
      #define lstrlen longstrlen
   #endif				/* Borland_286 */
#endif					/* MSWindows */

#include "../h/mproto.h"

/*
 * These must be after prototypes to avoid clash with system
 * prototypes.
 */

#if IntBits == 16
   #define sbrk lsbrk
   #define strlen lstrlen
   #define qsort lqsort
#endif					/* IntBits == 16 */
