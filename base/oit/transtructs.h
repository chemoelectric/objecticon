/*
 * The data structures used during linking.
 */

#ifndef _TRANSTRUCTS_H
#define _TRANSTRUCTS_H 1

#include "icont.h"

/*
 * Structures for symbol table entries.
 */
struct tlentry {                /* local table entry */
    struct tlentry *l_blink;    /*   link for bucket chain */
    char *l_name;               /*   name of variable */
    struct node *pos;           /*   where defined */
    word l_flag;                /*   variable flags */
    int l_index;                /*   "index" of local in table */
    int seen;                   /*   flag to indicate whether entry encountered
                                 *   in the function body */
    struct tlentry *l_next;     /*   next local in table */
};

struct tgentry {                /* global table entry */
    struct tgentry *g_blink;    /*   link for bucket chain */
    char *g_name;               /*   name of variable */
    struct node *pos;           /*   where defined */
    word g_flag;                /*   variable flags */
    struct tfunction *func;     /*   pointer to func if a proc/record */
    struct tclass *class;       /*   pointer to class if a class */
    struct tgentry *g_next;     /*   next global in table */
};

struct tcentry {                /* constant table entry */
    struct tcentry *c_blink;    /*   link for bucket chain */
    char *c_name;               /*   pointer to string */
    int c_length;               /*   length of string */
    word c_flag;                /*   type of literal flag */
    int c_index;                /*   "index" of constant in table */
    struct tcentry *c_next;     /*   next constant in table */
};

struct tfunction {
    struct tlentry *lhash[128], *lfirst, *llast;                /* hash area for local table */
    struct tcentry *chash[128], *cfirst, *clast;                /* hash area for constant table */
    struct node *code;
    word flag;
    struct tfunction *next;
    struct tclass_field *field;             /* For a method, a pointer to the class's field */
    struct tgentry *global;                 /* For a proc/record, a pointer to the global entry */
};

/*
 * Element in the list of imports.
 */
struct timport {
    char *name;
    int mode;         /* Mode indicating whether whole package import (I_All), qualified with 
                       * included symbols, eg import gui(X,Y) (I_Some),  or qualified with excluded
                       * symbols eg import gui -(X,Y) (I_Except).
                       */
    struct node *pos;
    struct timport_symbol *symbol_hash[64], *symbols, *last_symbol;
    struct timport *next, *b_next;
};

/*
 * Symbol in an import.
 */
struct timport_symbol {
    char *name;
    struct node *pos;
    struct timport_symbol *next, *b_next;
};

/*
 * "Invocable" declarations are recorded in a list
 */
struct tinvocable {
    char *name;                 /* name of global */
    struct node *pos;           /* where defined */
    struct tinvocable *next;    /* link to next entry */
};

struct tclass_super {
    char *name;
    struct node *pos;
    struct tclass_super *b_next, *next;
};

struct tclass_field {
    char *name;
    struct node *pos;
    word flag;
    struct tfunction *f;  /* For a method only */
    struct tclass *class; /* Pointer back to class instance */
    struct tclass_field *b_next, *next;
};

struct tclass {
    word flag;
    struct tclass_super *super_hash[32], *supers, *curr_super;
    struct tclass_field *field_hash[32], *fields, *curr_field;
    struct tclass *next;
    struct tgentry *global;   /* Global table entry */
};


#endif
