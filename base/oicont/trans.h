#ifndef _TRANS_H
#define _TRANS_H 1

#include "tmain.h"
#include "icont.h"
#include "tree.h"

void trans(struct file_param *trans_files, int *fatals, int *warnings);
void tsyserr(char *s);
void tfatal(char *fmt, ...);
void tfatal_at(struct node *n, char *fmt, ...);
void twarn_at(struct node *n, char *fmt, ...);

#endif
