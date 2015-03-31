/*
 * getopt.c -- get command-line options.
 */

#include "../h/gsupport.h"

/*
 * Based on a public domain implementation of System V
 *  getopt(3) by Keith Bostic (keith@seismo), Aug 24, 1984.
 */

#define BadCh	(int)'?'
#define EMSG	""
#define tell(m)	fprintf(stderr,"%s: %s -- %c\n",nargv[0],m,oi_optopt);return BadCh;

int oi_optind = 1;		/* index into parent argv vector */
int oi_optopt;		/* character checked for validity */
char *oi_optarg;		/* argument associated with option */

int oi_getopt(int nargc, char *const nargv[], const char *ostr)
   {
   static char *place = EMSG;		/* option letter processing */
   char *oli;			/* option letter list index */

   if(!*place) {			/* update scanning pointer */
      if(oi_optind >= nargc || *(place = nargv[oi_optind]) != '-' || !*++place)
         return(EOF);
      if (*place == '-') {		/* found "--" */
         ++oi_optind;
         return(EOF);
         }
      }					/* option letter okay? */

   if (((oi_optopt=(int)*place++) == (int)':') || (oli=strchr(ostr,oi_optopt)) == 0) {
      if(!*place) ++oi_optind;
      tell("illegal option");
      }
   if (*++oli != ':') {			/* don't need argument */
      oi_optarg = NULL;
      if (!*place) ++oi_optind;
      }
   else {				/* need an argument */
      if (*place) oi_optarg = place;	/* no white space */
      else if (nargc <= ++oi_optind) {	/* no arg */
         place = EMSG;
         tell("option requires an argument");
         }
      else oi_optarg = nargv[oi_optind];	/* white space */
      place = EMSG;
      ++oi_optind;
      }
   return(oi_optopt);			/* dump back option letter */
   }

