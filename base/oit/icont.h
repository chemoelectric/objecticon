/*
 * Miscellaneous definitions used in both translator and link phases.
 */

#ifndef _ICONT_H
#define _ICONT_H 1

#include "../h/gsupport.h"
#undef OF
#undef CONST
#include "../h/version.h"
#include "../h/mproto.h"
#include "../h/modflags.h"

#define F_Global	    01	/* variable declared global externally */
#define F_Proc		    04	/* procedure */
#define F_Record	   010	/* record */
#define F_Dynamic     	   020	/* variable declared local */
#define F_Static	   040	/* variable declared static */
#define F_Builtin	  0100	/* identifier refers to built-in procedure */
#define F_Vararg	  0200	/* identifier is a vararg */
#define F_Argument	 01000	/* variable is a formal parameter */
#define F_IntLit	 02000	/* literal is an integer */
#define F_RealLit	 04000	/* literal is a real */
#define F_StrLit	010000	/* literal is a string */
#define F_CsetLit	020000	/* literal is a cset */
#define F_UcsLit        040000  /* literal is a ucs */
#define F_LrgintLit    0100000  /* literal is a large int */
#define F_Class        0200000  /* class */
#define F_Importsym    0400000  /* symbol in an import declaration */
#define F_Field       01000000  /* local X is really self.X or Class.X */
#define F_Method      02000000  /* function is a method */

/*
 * Hash functions for symbol tables.
 */
#define hasher(x,obj)   (((word)x)%ElemCount(obj))

#define MemProtect(notnull) do {if (!(notnull)) quitf("Out of memory");} while(0)
#define Abs(x) (((x) < 0) ? (-(x)) : (x))
#define Max(x,y)        ((x)>(y)?(x):(y))
#define Min(x,y)        ((x)<(y)?(x):(y))

#endif
