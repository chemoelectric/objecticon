#ifndef _TMAIN_H
#define _TMAIN_H 1

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
extern int Iflag;       /* -I: ir code dump */
extern int Zflag;	/* -Z: icode-gz compression */
extern int loclevel;    /* -l n: location info */
extern int Olevel;      /* -O n: optimisation */
extern int nolink;


/*
 * Files and related globals.
 */
extern FILE *ucodefile;	        /* current ucode output file */
extern char *ofile;         	/* name of linker output file */
extern char *oixloc;			/* path to iconx */
extern long scriptsize;			/* size of iconx header script */

/*
 * Some convenient interned strings.
 */
extern char *main_string;
extern char *default_string;
extern char *self_string;
extern char *new_string;
extern char *init_string;
extern char *empty_string;
extern char *all_string;
extern char *lang_string;
extern char *stdin_string;
extern char *package_marker_string;
extern char *ascii_string;
extern char *utf8_string;
extern char *iso_8859_1_string;

int main(int argc, char **argv);
void report(char *fmt, ...);
void quit(char *fmt, ...);
char *abbreviate(char *path);
void begin_link(FILE *f, char *fname, int line);
void end_link(FILE *f);
void add_remove_file(char *s);

#endif
