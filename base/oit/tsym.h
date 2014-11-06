#ifndef _TSYM_H
#define _TSYM_H 1

#include "tree.h"
#include "transtructs.h"

/*
 * Symbol table region pointers.
 */

#define GHASH_SIZE    128
extern struct tgentry *ghash[GHASH_SIZE];	/* hash area for global table */
extern struct tgentry *gfirst;	/* first global table entry */
extern struct tgentry *glast;	/* last global table entry */

extern struct tfunction *functions, *curr_func;
extern struct tclass *classes, *curr_class;
extern char *package_name;
extern int idflag;
extern int modflag;
extern int packageflag;
extern struct timport *imports, *last_import, *curr_import;
extern struct tinvocable *tinvocables, *last_tinvocable;

void install(char *name, struct node *n);
struct tgentry *next_global(char *name, int flag, struct node *n);
struct tlentry *put_local(char *name, int flag, struct node *n, int unique);
int putlit(char *id, int idtype, int len);
int klookup(char *id);
void ensure_pos(struct node *x);
void reset_pos(void);
void output_code(void);

#endif
