#include "../h/gsupport.h"

/*
 * redirerr - redirect error output to the named file. '-' indicates that
 *  it should be redirected to standard out.
 */
int redirerr(p)
char *p;
   {
   if ( *p == '-' ) { /* let - be stdout */

/*
 * The following code is operating-system dependent [@redirerr.01].  Redirect
 *  stderr to stdout.
 */

#if PORT
   /* may not be possible */
   Deliberate Syntax Error
#endif					/* PORT */

#if MSDOS
   #if HIGHC_386 || NT
      /*
       * Don't like doing this, but it seems to work.
       */
      setbuf(stdout,NULL);
      setbuf(stderr,NULL);
      stderr->_file = stdout->_file;
   #else				/* HIGHC_386 || NT */
      dup2(fileno(stdout),fileno(stderr));
   #endif				/* HIGHC_386 || NT */
#endif					/* MSDOS */


#if UNIX
      /*
       * This relies on the way UNIX assigns file numbers.
       */
      close(fileno(stderr));
      dup(fileno(stdout));
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

       }
    else    /* redirecting to named file */
       if (freopen(p, "w", stderr) == NULL)
          return 0;
   return 1;
   }
