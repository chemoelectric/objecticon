#ifndef _UCODE_H
#define _UCODE_H 1

/*
 * Output routines for the opcode and the parameters.
 */

/* Output the opcode */
void uout_op(int opcode);

/* 16 bits signed */
void uout_short(int n);

/* 32 bits signed */
void uout_word(word n);

/* null-terminated string */
void uout_str(char *s);

/* len bytes of binary data */
void uout_bin(int len, char *s);

/*
 * The input routines follow a similar pattern.
 */

/* Get the next op, returning null on EOF */
struct ucode_op *uin_op();

/* Get the next op, but quit on EOF */
struct ucode_op *uin_expectop();

/* Get a word */
word uin_word();

/* Get and intern a null-terminated string */
char *uin_str();

/* Get and intern a null-terminated string, prefix with package plus a . */
char *uin_fqid(char *package);

/* Get and intern binary data, storing the length in n */
char *uin_bin(int *n);

/* Get a 16 bit signed short */
int uin_short();

/* Given the last opcode just read, skip over the instruction's parameters */
void uin_skip(int opcode);

int     udis(int argc, char **argv);

/*
 * Definition of a particular instruction.
 */
struct ucode_op {
    int opcode;
    char *name;          /* Printable name */
    int param_type[3];   /* The types of the parameters */
    char *fmt;           /* Format for disassembly */
};

/*
 * The parameter types.
 */
#define TYPE_NONE      0   /* no params */
#define TYPE_WORD      1   /* signed 32 bits */
#define TYPE_SHORT     2   /* signed 16 bits */
#define TYPE_STR       3   /* null terminated string */
#define TYPE_BIN       4   /* binary data (length + bytes) */

#endif
