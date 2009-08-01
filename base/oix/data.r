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

#define OpDef(p) extern struct b_proc Cat(B,p);
#include "../h/odefs.h"
#undef OpDef

extern struct b_proc Bbscan;
extern struct b_proc Bescan;
extern struct b_proc Bfield;
extern struct b_proc Blimit;
extern struct b_proc Bllist;

 


struct b_proc *opblks[] = {
	NULL,
#define OpDef(p) Cat(&B,p),
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

struct b_real realzero;          /* real zero block */
struct b_real realphi;	        /* real phi descriptor */
struct b_real realpi;	        /* real pi descriptor */
struct b_real reale;	        /* real e descriptor */

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
 * An array of all characters for use in making one-character strings.
 */
char *allchars = 
    "\000\001\002\003\004\005\006\007"
    "\010\011\012\013\014\015\016\017"
    "\020\021\022\023\024\025\026\027"
    "\030\031\032\033\034\035\036\037"
    "\040\041\042\043\044\045\046\047"
    "\050\051\052\053\054\055\056\057"
    "\060\061\062\063\064\065\066\067"
    "\070\071\072\073\074\075\076\077"
    "\100\101\102\103\104\105\106\107"
    "\110\111\112\113\114\115\116\117"
    "\120\121\122\123\124\125\126\127"
    "\130\131\132\133\134\135\136\137"
    "\140\141\142\143\144\145\146\147"
    "\150\151\152\153\154\155\156\157"
    "\160\161\162\163\164\165\166\167"
    "\170\171\172\173\174\175\176\177"
    "\200\201\202\203\204\205\206\207"
    "\210\211\212\213\214\215\216\217"
    "\220\221\222\223\224\225\226\227"
    "\230\231\232\233\234\235\236\237"
    "\240\241\242\243\244\245\246\247"
    "\250\251\252\253\254\255\256\257"
    "\260\261\262\263\264\265\266\267"
    "\270\271\272\273\274\275\276\277"
    "\300\301\302\303\304\305\306\307"
    "\310\311\312\313\314\315\316\317"
    "\320\321\322\323\324\325\326\327"
    "\330\331\332\333\334\335\336\337"
    "\340\341\342\343\344\345\346\347"
    "\350\351\352\353\354\355\356\357"
    "\360\361\362\363\364\365\366\367"
    "\370\371\372\373\374\375\376\377";


/*
 * Note:  the following material is here to avoid a bug in the Cray C compiler.
 */

#define OpDef(p) int Cat(O,p) (dptr cargp);
#include "../h/odefs.h"
#undef OpDef

/*
 * When an opcode n has a subroutine call associated with it, the
 *  nth word here is the routine to call.
 */

int (*optab[])() = {
	err,
#define OpDef(p) Cat(O,p),
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
