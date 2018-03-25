#ifndef _TRANS_H
#define _TRANS_H 1

#include "tmain.h"
#include "icont.h"
#include "tree.h"

extern int tfatals;		/* total fatal errors */
extern int twarnings;		/* number of warning errors in file */

void trans(struct file_param *trans_files, struct pp_def *pp_defs, int *fatals, int *warnings);
void tfatal(char *fmt, ...);
void tfatal_at(struct node *n, char *fmt, ...);
void twarn_at(struct node *n, char *fmt, ...);

#endif
