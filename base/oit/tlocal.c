/*
 *  tlocal.c -- functions needed for different systems.
 */

#include "icont.h"

/*
 * The following code is operating-system dependent [@tlocal.01].
 *  Routines needed by different systems.
 */

#if PORT
/* place to put anything system specific */
Deliberate Syntax Error
#endif					/* PORT */

#if MACINTOSH
#if MPW
/* Routine to set file type and creator.
*/

#include <Files.h>

void
setfile(filename,type,creator)
char *filename;
OSType type,creator;
   {
   FInfo info;

   if (getfinfo(filename,0,&info) == 0) {
      info.fdType = type;
      info.fdCreator = creator;
      setfinfo(filename,0,&info);
      }
   return;
   }


/* Routine to quote strings for MPW
*/

char *
mpwquote(s)
char *s;
   {
   static char quotechar[] =
	 " \t\n\r#;&|()6'\"/\\{}`?E[]+*GH(<>3I7";
   static char *endq = quotechar + sizeof(quotechar);
   int quote = 0;
   char c,d,*sp,*qp,*cp,*q;
   char *malloc();

   sp = s;
   while (c = *sp++) {
      cp = quotechar;
      while ((d = *cp++) && c != d)
	 ;
      if (cp != endq) {
         quote = 1;
	 break;
	 }
      }
   if (quote) {
      qp = q = malloc(4 * strlen(s) + 1);
      *qp++ = '\'';
      sp = s;
      while (c = *sp++) {
	 if (c == '\'') {
	    *qp++ = '\'';
	    *qp++ = '6';
	    *qp++ = '\'';
	    *qp++ = '\'';
	    quote = 1;
	    }
	 else *qp++ = c;
	 }
      *qp++ = '\'';
      *qp++ = '\0';
      }
   else {
      q = malloc(strlen(s) + 1);
      strcpy(q,s);
      }
   return q;
   }


/*
 * SortOptions -- sorts icont options so that options and file names can
 * appear in any order.
 */
void
SortOptions(argv)
char *argv[];
   {
   char **last,**p,*q,**op,**fp,**optlist,**filelist,opt,*s,*malloc();
   int size,error = 0;;

   /*
    * Count parameters before -x.
    */
   ++argv;
   for (last = argv; *last != NULL && strcmp(*last,"-x") != 0; ++last)
      ;
   /*
    * Allocate a work area to build separate lists of options
    * and filenames.
    */
   size = (last - argv + 1) * sizeof(char*);
   optlist = filelist = NULL;
   op = optlist = (char **)malloc(size);
   fp = filelist = (char **)malloc(size);
   if (optlist && filelist) {			/* if allocations ok */
      for (p = argv; (s = *p); ++p) {		/* loop thru args */
         if (error) break;
	 if (s[0] == '-' && (opt = s[1]) != '\0') { /* if an option */
	    if (q = strchr(Options,opt)) {	/* if valid option */
	       *op++ = s;
	       if (q[1] == ':') {		/* if has a value */
		  if (s[2] != '\0') s += 2;	/* if value in this word */
		  else s = *op++ = *++p;	/* else value in next word */
		  if (s) {			/* if next word exists */
		     if (opt == 'S') {		/* if S option */
			if (s[0] == 'h') ++s;	/* bump past h */
			if (s[0]) ++s;		/* bump past letter */
			else error = 3;		/* error -- no letter */
			if (s[0] == '\0') {	/* if value in next word */
			   if ((*op++ = *++p) == NULL)
			         error = 4;	/* error -- no next word */
			   }
			}
		     }
		  else error = 1;	/* error -- missing value */
		  }
	       }
	       else error = 2;		/* error -- invalid option */
	    }
	 else {					/* else a file */
	    *fp++ = s;
	    }
	 }
      *op = NULL;
      *fp = NULL;
      if (!error) {
	 p = argv;
	 for (op = optlist; *op; ++op) *p++ = *op;
	 for (fp = filelist; *fp; ++fp) *p++ = *fp;
	 }
      }
   if (optlist) free(optlist);
   if (filelist) free(filelist);
   return;
   }
#endif					/* MPW */
#endif					/* MACINTOSH */

#if UNIX
#endif					/* UNIX */

/*
 * End of operating-system specific code.
 */

