/*
 *  Configuration parameters that depend on computer architecture.
 *  Some depend on values defined in config.h, which is always
 *  included before this file.
 */

#ifndef CStateSize
   #define CStateSize 15		/* size of C state for co-expressions */
#endif					/* CStateSize */

/*
 * The following definitions depend on the sizes of ints and pointers.
 */

/*
 * Most of the present implementations use 32-bit "words".  Note that
 *  WordBits is the number of bits in an Icon integer, not necessarily
 *  the number of bits in an int (given by IntBits).  For example,
 *  in MS-DOS an Icon integer is a long, not an int.
 *
 *  MaxStrLen must not be so large as to overlap flags.
 */

/*
 * 64-bit words.
 */

#if WordBits == 64
   #define LogWordBits	6			/* log of WordBits */
   #define MinWord  ((word)0x8000000000000000) /* smallest word */
   #define MaxWord  ((word)0x7fffffffffffffff) /* largest word */
   #define MaxStrLen 017777777777L		/* maximum string length */

   #define MinWordStr "-9223372036854775808"

   #define F_Nqual      0x8000000000000000	/* set if NOT string qualifier*/
   #define F_Var	0x4000000000000000	/* set if variable */
   #define F_Ptr	0x1000000000000000	/* set if value field is ptr */
   #define F_Typecode   0x2000000000000000	/* set if dword incls typecode*/
#endif					/* WordBits == 64 */

/*
 * 32-bit words.
 */

#if WordBits == 32
   #define LogWordBits	        5		/* log of WordBits */
   #define MaxWord  ((word)0x7fffffff)   /* largest word */
   #define MinWord  ((word)0x80000000)   /* smallest word */
   
   #define MinWordStr "-2147483648"
   
   #define MaxStrLen    0x7fffffff	/* maximum string length */

   #define F_Nqual	0x80000000	/* set if NOT string qualifier */
   #define F_Var	0x40000000	/* set if variable */
   #define F_Ptr	0x10000000	/* set if value field is pointer */
   #define F_Typecode	0x20000000	/* set if dword includes type code */
#endif					/* WordBits == 32 */

/*
 * Values that depend on the number of bits in an int (not necessarily
 * the same as the number of bits in a word).
 */

#if IntBits == 64
   #define MaxInt	0777777777777777777777L /* largest int */
#endif					/* IntBits == 64 */

#if IntBits == 32
   #define MaxInt	        0x7fffffff	/* largest int */
#endif					/* IntBits == 32 */

#ifndef LogHuge
   #define LogHuge 309			/* maximum base-10 exp+1 of real */
#endif					/* LogHuge */

#ifndef Big
   #define Big 9007199254740992.	/* larger than 2^53 lose precision */
#endif					/* Big */

#ifndef Precision
   #define Precision 10			/* digits in string from real */
#endif					/* Precision */

/*
 * Parameters that configure tables and sets:
 *
 *  HSlots	Initial number of hash buckets; must be a power of 2.
 *  LogHSlots	Log to the base 2 of HSlots.
 *
 *  HSegs	Maximum number of hash bin segments; the maximum number of
 *		hash bins is HSlots * 2 ^ (HSegs - 1).
 *
 *		If Hsegs is increased above 12, the arrays log2h[] and segsize[]
 *		in the runtime system will need modification.
 *
 *  MaxHLoad	Maximum loading factor; more hash bins are allocated when
 *		the average bin exceeds this many entries.
 *
 *  MinHLoad	Minimum loading factor; if a newly created table (e.g. via
 *		copy()) is more lightly loaded than this, bins are combined.
 *
 *  Because splitting doubles the number of hash bins, and combining halves it,
 *  MaxHLoad should be at least twice MinHLoad.
 */

#ifndef HSlots
   #define HSlots     8
   #define LogHSlots  3
#endif					/* HSlots */

#if ((1 << LogHSlots) != HSlots)
   Deliberate Syntax Error -- HSlots and LogHSlots are inconsistent
#endif					/* HSlots / LogHSlots consistency */

#ifndef HSegs
   #define HSegs	 12
#endif					/* HSegs */

#ifndef MinHLoad
   #define MinHLoad  1
#endif					/* MinHLoad */

#ifndef MaxHLoad
   #define MaxHLoad  5
#endif					/* MaxHLoad */

/*
 * The number of bits in each base-B digit; the type DIGIT (unsigned int)
 *  in rt.h must be large enough to hold this many bits.
 *  It must be at least 2 and at most WordBits / 2.
 */
#define NB           (WordBits / 2)

/*
 * The number of decimal digits at which the image lf a large integer
 * goes from exact to approximate (to avoid possible long delays in
 * conversion from large integer to string because of its quadratic
 * complexity).
 */
#define MaxDigits	30

/*
 * Lower-bound default for coexprlim; more are allowed if memory size permits.
 */
#ifndef CoexprLim
   #define CoexprLim 15
#endif					/* CoexprLim */

/*
 * What follows is default memory sizing. Implementations with special
 *  requirements may specify these values in define.h.
 */

#ifndef MinDefStrSpace
   #define MinDefStrSpace 500000	/* minimum default size of the string space in bytes */
#endif					/* (default size may be larger if memory is ample) */

#ifndef MinDefAbrSize
   #define MinDefAbrSize (125000 * WordSize) /* minimum default size of the block region in bytes */
#endif					/* (default size may be larger if memory is ample) */

#ifndef MStackSize
   #define MStackSize (30000 * WordSize) /* default value of mstksize, the size of the main interpreter stack */
#endif					/* MStackSize */

#ifndef XStackSize
   #define XStackSize (30000 * WordSize)	/* default value of xstksize, the co-expression stack size */
#endif					/* XStackSize */

#ifndef QualLstSize
   #define QualLstSize	(1250 * WordSize) /* size of qualifier pointer region */
#endif					/* QualLstSize */

#ifndef RegionCushion
   #define RegionCushion 10		/* % memory cushion to avoid thrashing*/
#endif					/* RegionCushion */

#ifndef RegionGrowth
   #define RegionGrowth 200		/* % region growth when full */
#endif					/* RegionGrowth */

#ifndef MinAbrSize
   #define MinAbrSize  (1250 * WordSize) /* min size of a block region in bytes */
#endif					/* MinAbrSize */
