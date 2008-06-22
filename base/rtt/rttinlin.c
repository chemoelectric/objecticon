/*
 * rttinlin.c contains routines which produce the in-line version of an
 *  operation and put it in the data base.
 */
#include "rtt.h"

/*
 * prototypes for static functions. 
 */
static struct il_code *abstrcomp (struct node *n, int indx_stor,
                                    int chng_stor, int escapes);
static void         abstrsnty (struct token *t, int typcd,
                                   int indx_stor, int chng_stor);
static int             body_anlz (struct node *n, int *does_break,
                                   int may_mod, int const_cast, int all);
static struct il_code *body_fnc  (struct node *n);
static void         chkrettyp (struct node *n);
static void         chng_ploc (int typcd, struct node *src);
static void         cnt_bufs  (struct node *cnv_typ);
static struct il_code *il_walk   (struct node *n);
static struct il_code *il_var    (struct node *n);
static int             is_addr   (struct node *dcltor, int modifier);
static void         lcl_tend  (struct node *n);
static int             mrg_abstr (int sum, int typ);
static int             strct_typ (struct node *typ, int *is_reg);

static int body_ret; /* RetInt, RetDbl, and/or RetOther for current body */
static int ret_flag; /* DoesFail, DoesRet, and/or DoesSusp for current body */
int fnc_ret;         /* RetInt, RetDbl, RetNoVal, or RetSig for current func */

