/*
 *  Configuration parameters that depend on computer architecture.
 *  Some depend on values defined in config.h, which is always
 *  included before this file.
 *
 *  Most of the present implementations use 32-bit "words".  Note that
 *  WordBits is the number of bits in an Icon integer, not necessarily
 *  the number of bits in an int (given by IntBits).  For example,
 *  in MS-DOS an Icon integer is a long, not an int.
 *
 */

/*
 * 64-bit words.
 */

#if WordBits == 64
   #define LogWordBits	6			/* log of WordBits */
   #define MaxUWord  ((uword)0xffffffffffffffff) /* largest uword */
   #define MaxWord  ((word)0x7fffffffffffffff) /* largest word */
   #define MinWord  ((word)0x8000000000000000) /* smallest word */

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
   #define MaxUWord  ((uword)0xffffffff)   /* largest uword */
   #define MaxWord  ((word)0x7fffffff)   /* largest word */
   #define MinWord  ((word)0x80000000)   /* smallest word */
   
   #define F_Nqual	0x80000000	/* set if NOT string qualifier */
   #define F_Var	0x40000000	/* set if variable */
   #define F_Ptr	0x10000000	/* set if value field is pointer */
   #define F_Typecode	0x20000000	/* set if dword includes type code */
#endif					/* WordBits == 32 */

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
   #error HSlots and LogHSlots are inconsistent
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
 * The number of decimal digits at which the image lf a large integer
 * goes from exact to approximate (to avoid possible long delays in
 * conversion from large integer to string because of its quadratic
 * complexity).
 */
#define MaxDigits	30


/*
 * What follows is default memory sizing. Implementations with special
 *  requirements may specify these values in define.h.
 */

#ifndef MinDefStrSpace
   #define MinDefStrSpace (512 * 1024)       /* minimum default size of the string space in bytes */
#endif                                  /* (default size may be larger if memory is ample) */

#ifndef MinDefAbrSize
   #define MinDefAbrSize (128 * 1024 * WordSize) /* minimum default size of the block region in bytes */
#endif                                  /* (default size may be larger if memory is ample) */

#ifndef MaxDefStrSpace
   #define MaxDefStrSpace (20 * 1024 * 1024)           /* maximum default size of the string space in bytes */
#endif

#ifndef MaxDefAbrSize
   #define MaxDefAbrSize (5 * 1024 * 1024  * WordSize)       /* maximum default size of the block region in bytes */
#endif

#ifndef RegionCushion
   #define RegionCushion 10		/* % memory cushion to avoid thrashing*/
#endif					/* RegionCushion */

#ifndef RegionGrowth
   #define RegionGrowth 200		/* % region growth when full */
#endif					/* RegionGrowth */

#ifndef MinAbrSize
   #define MinAbrSize  (1250 * WordSize) /* min size of a block region in bytes */
#endif					/* MinAbrSize */

#ifndef StackCushion
   #define StackCushion 150		/* % limit factor to avoid thrashing*/
#endif					
