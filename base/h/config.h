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

#if PLAN9
   #define Graphics 1
#endif

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

