#ifndef _TMAIN_H
#define _TMAIN_H 1

#include <stdio.h>
#include "icont.h"

struct file_param {
    char *name;
    struct file_param *next;
};

extern int m4pre;	/* -m: use m4 preprocessor? [UNIX] */
extern int trace;	/* -t: initial &trace value */
extern int pponly;	/* -E: preprocess only */
extern int strinv;	/* -f s: allow full string invocation */
extern int verbose;	/* -v n: verbosity of commentary */
extern int neweronly;	/* -n: only translate .icn if newer than .u */
extern int Dflag;       /* -L: link debug */
extern int Zflag;	/* -Z: icode-gz compression */

extern char *progname;

/*
 * Files and related globals.
 */
extern char *lpath;			/* search path for $include */
extern char *ipath;			/* search path for linking */
extern FILE *ucodefile;	        /* current ucode output file */
extern char *ofile;         	/* name of linker output file */
extern char *iconxloc;			/* path to iconx */
extern long hdrsize;			/* size of iconx header */

/*
 * Some convenient interned strings.
 */
extern char *main_string;
extern char *default_string;
extern char *self_string;
extern char *new_string;
extern char *init_string;
extern char *all_string;
extern char *lang_string;
extern char *package_marker_string;
extern char *standard_field_names[];

int main(int argc, char **argv);
void report(char *fmt, ...);
void quit(char *msg);
void quitf(char *fmt, ...);
char *abbreviate(char *path);

#endif
