#include "../h/gsupport.h"

/*
 * redirerr - redirect error output to the named file. '-' indicates that
 *  it should be redirected to standard out.
 */
int redirerr(char *p)
{
    if ( *p == '-' ) { /* let - be stdout */

#if MSWIN32
            /*
             * Don't like doing this, but it seems to work.
             */
            setbuf(stdout,NULL);
        setbuf(stderr,NULL);
        stderr->_file = stdout->_file;
#endif					/* MSWIN32 */

#if UNIX
        dup2(1,2);
#endif					/* UNIX */

    } else {    /* redirecting to named file */
        int f;
        if ((f = open(p, O_WRONLY|O_CREAT|O_TRUNC)) < 0)
            return 0;
        dup2(f,2);
    }
    return 1;
}
