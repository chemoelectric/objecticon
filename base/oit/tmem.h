#ifndef _TMEM_H
#define _TMEM_H 1

#include "tree.h"
#include "transtructs.h"
#include "membuff.h"

#define FAlloc(type)   mb_alloc(&file_mb, sizeof(type))
extern struct membuff file_mb;

void tminit(void);
void tmfilefree(void);
void tmfree(void);
void next_function(int flag);
void next_class(char *name, int flag, struct node *n);
void next_super(char *name, struct node *n);
void check_flags(int flag, struct node *n);
void next_field(char *name, int flag, struct node *n);
void next_method(char *name, int flag, struct node *n);
void next_procedure(char *name, struct node *n);
struct timport *lookup_import(char *s);
void set_package(char *s, struct node *n);
void next_import(char *s, int qualified, struct node *n);
void add_import_symbol(char *s, struct node *n); 
void add_invocable(char *name, int x, struct node *n);
char *dottedid2string(struct node *n);
struct node *convert_dottedidentexpr(struct node *n);

#endif
