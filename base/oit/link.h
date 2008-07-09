#ifndef _LINK_H
#define _LINK_H 1

#include <stdio.h>
#include "tmain.h"
#include "icont.h"
#include "linkstructs.h"

extern FILE *infile;		/* current input file */
extern FILE *outfile;		/* linker output file */
extern FILE *dbgfile;		/* debug file */
extern char *inname;		/* input file name */
extern int lineno;		/* source program line number (from ucode) */

void ilink(struct file_param *link_files, char *outname, int *fatals, int *warnings);
char *function_name(struct lfunction *f);
void lfatal(struct loc *pos, char *fmt, ...);
void lwarn(struct loc *pos, char *fmt, ...);
void setexe(char *fname);
void dumpstate();

#endif
