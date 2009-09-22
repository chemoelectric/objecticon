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

void ilink(struct file_param *link_files, int *fatals, int *warnings);
char *function_name(struct lfunction *f);
void lfatal(struct lfile *lf, struct loc *pos, char *fmt, ...);
void lwarn(struct lfile *lf, struct loc *pos, char *fmt, ...);
void setexe(char *fname);
char *f_flag2str(int flag);
void dumpstate();

#endif
