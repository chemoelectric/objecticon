#ifndef _LINK_H
#define _LINK_H 1

#include "tmain.h"
#include "icont.h"
#include "linkstructs.h"

extern FILE *infile;		/* current input file */
extern FILE *outfile;		/* linker output file */
extern FILE *dbgfile;		/* debug file */
extern char *inname;		/* input file name */
extern struct lfunction *curr_lfunc;
extern struct gentry *gmain;    /* the main() procedure */

void ilink(struct file_param *link_files, int *fatals, int *warnings);
char *function_name(struct lfunction *f);
void lfatal(struct lfile *lf, struct loc *pos, char *fmt, ...);
void lfatal2(struct lfile *lf, struct loc *pos, struct loc *pos2, char *tail, char *fmt, ...);
void lwarn(struct lfile *lf, struct loc *pos, char *fmt, ...);
void setexe(char *fname);
char *f_flag2str(int flag);
char *m_flag2str(int flag);
void dumpstate(void);

#endif
