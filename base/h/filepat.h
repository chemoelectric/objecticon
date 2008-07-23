#ifndef FILEPAT_H
#define FILEPAT_H
/*
 * Typedefs and macros for filename wildcard expansion on some systems.
 *  The definitions provided here are:
 *
 *    typedef ... FINDFILE_T;
 *    // Current state of the filename wildcard expansion
 *
 *    int FINDFIRST ( char *pattern, FINDFILE_T *pfd );
 *    // Initializes *pfd and returns 1 if a file is found that matches the
 *    // pattern, 0 otherwise
 *
 *    int FINDNEXT ( FINDFILE_T *pfd );
 *    // Assuming that the last FINDFIRST/FINDNEXT call was successful,
 *    // updates *pfd and returns whether another match can be made.
 *
 *    char *FILENAME ( FINDFILE_T *pfd );
 *    // Assuming that the last FINDFIRST/FINDNEXT call was successful,
 *    // returns pointer to last found file name.
 *
 *    void FINDCLOSE ( FINDFILE_T *pfd );
 *    // Does any cleanup required after doing filenaame wildcard expansion.
 *
 * Also, the macro WildCards will be defined to be 1 if there is file
 * pattern matching is supported, 0 otherwise.  If !WildCards, then a
 * default set of typedef/macros will be provided that will return only one
 * match, the original pattern.
 */


#if WildCards

#if MSWIN32

#include <io.h>

typedef struct _FINDFILE_TAG {
   long			handle;
   struct _finddata_t	fileinfo;
   } FINDDATA_T;

#define FINDFIRST(pattern, pfd)	\
   ( ( (pfd)->handle = _findfirst ( (pattern), &(pfd)->fileinfo ) ) != -1L )
#define FINDNEXT(pfd) ( _findnext ( (pfd)->handle, &(pfd)->fileinfo ) != -1 )
#define FILENAME(pfd)	( (pfd)->fileinfo.name )
#define FINDCLOSE(pfd)	_findclose( (pfd)->handle )

#endif 					/* MSWIN32 */



#if PORT
Deliberate Syntax Error                 /* Give it some thought */
#endif                                  /* PORT */
#endif					/* WildCards */
#endif
