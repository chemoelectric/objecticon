/*
 * Icon configuration.
 */

/*
 * Names for standard environment variables.
 * The standard names are used unless they are overridden.
 */

#ifndef TRACE
   #define TRACE "TRACE"
#endif

#ifndef OI_MAX_LEVEL
   #define OI_MAX_LEVEL "OI_MAX_LEVEL"
#endif

#ifndef OI_STRING_SIZE
   #define OI_STRING_SIZE "OI_STRING_SIZE"
#endif

#ifndef OI_BLOCK_SIZE
   #define OI_BLOCK_SIZE "OI_BLOCK_SIZE"
#endif

#ifndef OI_MEM_GROWTH
   #define OI_MEM_GROWTH "OI_MEM_GROWTH"
#endif

#ifndef OI_MEM_CUSHION
   #define OI_MEM_CUSHION "OI_MEM_CUSHION"
#endif

#ifndef OI_CORE
   #define OI_CORE "OI_CORE"
#endif

#ifndef OI_PATH
   #define OI_PATH "OI_PATH"
#endif

#ifndef OI_INCL
   #define OI_INCL "OI_INCL"
#endif

#ifndef OI_FONT
   #define OI_FONT "OI_FONT"
#endif

#ifndef OI_FONT_SIZE
   #define OI_FONT_SIZE "OI_FONT_SIZE"
#endif

#ifndef OI_LEADING
   #define OI_LEADING "OI_LEADING"
#endif

#ifndef OI_IP_VERSION
   #define OI_IP_VERSION "OI_IP_VERSION"
#endif

#ifndef OI_STACK_LIMIT
   #define OI_STACK_LIMIT "OI_STACK_LIMIT"
#endif

#ifndef OI_STACK_CUSHION
   #define OI_STACK_CUSHION "OI_STACK_CUSHION"
#endif

#if MSWIN32
   #undef Graphics
   #define Graphics 1
#endif					/* MSWIN32 */

#if HAVE_LIBX11
   #define Graphics 1
   #define XWindows 1
#endif

/*
 * Other defaults.
 */

#ifndef ByteBits
   #define ByteBits 8
#endif					/* ByteBits */

#ifndef ShortBits
   #define ShortBits (ByteBits * SIZEOF_SHORT)
#endif					/* ShortBits */

#ifndef WordBits
   #define WordBits (ByteBits * SIZEOF_VOIDP)
#endif					/* WordBits */

#ifndef IntBits
   #define IntBits (ByteBits * SIZEOF_INT)
#endif					/* IntBits */

#ifndef LongBits
   #define LongBits (ByteBits * SIZEOF_LONG)
#endif					/* LongBits */

#ifndef LongLongBits
   #define LongLongBits (ByteBits * SIZEOF_LONG_LONG)
#endif					/* LongBits */

#ifndef RealBits
   #define RealBits (ByteBits * SIZEOF_DOUBLE)
#endif					/* RealBits */

/*
 * Default sizing and such.
 */

#define WordSize sizeof(word)

/*
 *  The following definitions assume ANSI C.
 */
#define Bell '\a'

#ifndef PPInit
   #define PPInit ""
#endif                                 /* PPInit */

#ifndef QSortFncCast
   #define QSortFncCast int (*)(const void *,const void *)
#endif					/* QSortFncCast */

#ifndef BSearchFncCast
   #define BSearchFncCast int (*)(const void *,const void *)
#endif					/* BSearchFncCast */

#ifndef WriteBinary
   #define WriteBinary "wb"
#endif					/* WriteBinary */

#ifndef ReadBinary
   #define ReadBinary "rb"
#endif					/* ReadBinary */

#ifndef AppendBinary
   #define AppendBinary "ab"
#endif					/* AppendBinary */

#ifndef ReadWriteBinary
   #define ReadWriteBinary "wb+"
#endif					/* ReadWriteBinary */

#ifndef ReadEndBinary
   #define ReadEndBinary "r+b"
#endif					/* ReadEndBinary */

#ifndef WriteText
   #define WriteText "w"
#endif					/* WriteText */

#ifndef ReadText
   #define ReadText "r"
#endif					/* ReadText */

#ifndef AppendText
   #define AppendText "a"
#endif					/* AppendText */

#ifndef DiffPtrs
   #define DiffPtrs(p1,p2) (word)((p1)-(p2))
#endif					/* DiffPtrs */

#ifndef RttSuffix
   #define RttSuffix ".r"
#endif					/* RttSuffix */

#ifndef CSuffix
   #define CSuffix ".c"
#endif					/* CSuffix */

#ifndef TmpSuffix
   #define TmpSuffix ".tmp"
#endif					/* TmpSuffix */

#ifndef SourceSuffix
   #define SourceSuffix ".icn"
#endif					/* SourceSuffix */

#ifndef USuffix
   #define USuffix ".u"
#endif				/* USuffix */

#ifndef UXSuffix
   #define UXSuffix ".ux"
#endif				/* UXSuffix */

#ifndef UcsIndexStepFactor
   #define UcsIndexStepFactor  4.5
#endif

#define IcodeDelim "[executable Icon binary follows]"

/*
 * Other sizeof macros:
 *
 *  Wsizeof(x)	-- Size of x in words.
 *  Vwsizeof(x) -- Size of x in words, minus the size of a descriptor.	Used
 *   when structures have a potentially null list of descriptors
 *   at their end.
 */

#define Wsizeof(x)	((sizeof(x) + sizeof(word) - 1) / sizeof(word))
#define Vwsizeof(x)	((sizeof(x) - sizeof(struct descrip) +\
			   sizeof(word) - 1) / sizeof(word))

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
#elif WordBits == 32
/*
 * 32-bit words.
 */

   #define LogWordBits	        5		/* log of WordBits */
   #define MaxUWord  ((uword)0xffffffff)   /* largest uword */
   #define MaxWord  ((word)0x7fffffff)   /* largest word */
   #define MinWord  ((word)0x80000000)   /* smallest word */
   
   #define F_Nqual	0x80000000	/* set if NOT string qualifier */
   #define F_Var	0x40000000	/* set if variable */
   #define F_Ptr	0x10000000	/* set if value field is pointer */
   #define F_Typecode	0x20000000	/* set if dword includes type code */
#else
   #error "WordBits must equal either 32 or 64"
#endif

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
   #error "HSlots and LogHSlots are inconsistent"
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
#ifndef MaxDigits
   #define MaxDigits	30
#endif

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
