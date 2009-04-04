/*
 * data.r -- Various interpreter data tables.
 */


struct b_proc Bnoproc;

/*
 * A procedure block for list construction, used by event monitoring.
 */
struct b_iproc mt_llist = {
   T_Proc, sizeof(struct b_proc), Ollist,
   0, 0, 0, 0, 0, 0, 0, {sizeof( "[...]")-1, "[...]"}, 0, 0};

/*
 * External declarations for function blocks.
 */

#define FncDef(p) extern struct b_proc Cat(B,p);
#passthru #undef exit
#undef exit
#include "../h/fdefs.h"
#undef FncDef

#define OpDef(p,n,s,u) extern struct b_proc Cat(B,p);
#include "../h/odefs.h"
#undef OpDef

extern struct b_proc Bbscan;
extern struct b_proc Bescan;
extern struct b_proc Bfield;
extern struct b_proc Blimit;
extern struct b_proc Bllist;

 


struct b_proc *opblks[] = {
	NULL,
#define OpDef(p,n,s,u) Cat(&B,p),
#include "../h/odefs.h"
#undef OpDef
   &Bbscan,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   &Bescan,
   NULL,
   &Bfield,
   NULL,
   NULL,
   NULL,
   NULL,
   NULL,
   &Blimit,
   &Bllist,
   NULL,
   NULL,
   NULL
   };

/*
 * Array of names and corresponding functions.
 *  Operators are kept in a similar table, op_tbl.
 */

struct pstrnm pntab[] = {

#define FncDef(p) {Lit(p), Cat(&B,p)},
#include "../h/fdefs.h"
#undef FncDef
	};

int pnsize = (sizeof(pntab) / sizeof(struct pstrnm));


/*
 * Structures for built-in values.  Parts of some of these structures are
 *  initialized later. Since some C compilers cannot handle any partial
 *  initializations, all parts are initialized later if any have to be.
 */


/*
 * Keyword variables.
 */


struct descrip kywd_dmp;               	/* &dump */

/*
 * Various constant descriptors, initialised in init.r
 */

struct descrip nullptr;                 /* descriptor with null block pointer */
struct descrip trashcan;		/* descriptor that is never read */
struct descrip blank; 			/* one-character blank string */
struct descrip emptystr; 		/* zero-length empty string */
struct descrip lcase;			/* string of lowercase letters */
struct descrip letr;			/* "r" */
struct descrip nulldesc;           	/* null value */
struct descrip onedesc;              	/* integer 1 */
struct descrip ucase;			/* string of uppercase letters */
struct descrip zerodesc;              	/* integer 0 */
struct descrip minusonedesc;           	/* integer -1 */
struct descrip thousanddesc;	        /* 1000 */
struct descrip milliondesc;	        /* 1000000 */

struct b_cset *blankcs;   /* ' ' */
struct b_cset *lparcs;    /* '(' */
struct b_cset *rparcs;    /* ')' */

/*
 * Descriptors used by event monitoring.
 */
struct descrip csetdesc;
struct descrip eventdesc;
struct descrip rzerodesc;

struct b_cset *k_ascii;	        /* value of &ascii */
struct b_cset *k_cset;	        /* value of &cset */
struct b_cset *k_uset;	        /* value of &uset */
struct b_cset *k_digits;	/* value of &lcase */
struct b_cset *k_lcase;	        /* value of &lcase */
struct b_cset *k_letters;	/* value of &letters */
struct b_cset *k_ucase;	        /* value of &ucase */

struct b_ucs *emptystr_ucs;     /* ucs empty string */
struct b_ucs *blank_ucs;        /* ucs blank string */

/*
 *  Real block needed for event monitoring.
 */
struct b_real realzero = {T_Real, 0.0};

/*
 * An array of all characters for use in making one-character strings.
 */

unsigned char allchars[256] = {
     0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
    16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
    32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63,
    64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95,
    96, 97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,111,
   112,113,114,115,116,117,118,119,120,121,122,123,124,125,126,127,
   128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143,
   144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159,
   160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,
   176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191,
   192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,
   208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223,
   224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,
   240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255,
};


/*
 * Note:  the following material is here to avoid a bug in the Cray C compiler.
 */

#define OpDef(p,n,s,u) int Cat(O,p) (dptr cargp);
#include "../h/odefs.h"
#undef OpDef

/*
 * When an opcode n has a subroutine call associated with it, the
 *  nth word here is the routine to call.
 */

int (*optab[])() = {
	err,
#define OpDef(p,n,s,u) Cat(O,p),
#include "../h/odefs.h"
#undef OpDef
   Obscan,
   err,
   err,
   err,
   err,
   err,
   Ocreate,
   err,
   err,
   err,
   err,
   Oescan,
   err,
   Ofield
   };

/*
 *  Keyword function look-up table.
 */
#define KDef(p,n) int Cat(K,p) (dptr cargp);
#include "../h/kdefs.h"
#undef KDef

int (*keytab[])() = {
   err,
#define KDef(p,n) Cat(K,p),
#include "../h/kdefs.h"
   };
