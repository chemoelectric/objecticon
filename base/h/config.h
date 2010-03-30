/*
 * Icon configuration.
 */

/*
 * Names for standard environment variables.
 * The standard names are used unless they are overridden.
 */

#ifndef NOERRBUF
   #define NOERRBUF "NOERRBUF"
#endif

#ifndef TRACE
   #define TRACE "TRACE"
#endif

#ifndef MAXLEVEL
   #define MAXLEVEL "MAXLEVEL"
#endif

#ifndef STRSIZE
   #define STRSIZE "STRSIZE"
#endif

#ifndef BLKSIZE
   #define BLKSIZE "BLKSIZE"
#endif

#ifndef QLSIZE
   #define QLSIZE "QLSIZE"
#endif

#ifndef IXGROWTH
   #define IXGROWTH "IXGROWTH"
#endif

#ifndef IXCUSHION
   #define IXCUSHION "IXCUSHION"
#endif

#ifndef OICORE
   #define OICORE "OICORE"
#endif

#ifndef OIPATH
   #define OIPATH "OIPATH"
#endif

#ifndef OLPATH
   #define OLPATH "OLPATH"
#endif

#if MSWIN32
   #undef Graphics
   #define Graphics 1
#endif					/* MSWIN32 */

#ifdef HAVE_LIBX11
   #define Graphics 1
   #define XWindows 1
#endif

/*
 * Other defaults.
 */

#ifndef MaxPath
   #define MaxPath 1024
#endif					/* MaxPath */

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

#ifndef SourceSuffix
   #define SourceSuffix ".icn"
#endif					/* SourceSuffix */

/*
 * Representations of directories. LocalDir is the "current working directory".
 *  SourceDir is where the source file is.
 */

#define LocalDir ""
#define SourceDir (char *)NULL

#ifndef TargetDir
   #define TargetDir LocalDir
#endif					/* TargetDir */

/*
 * Default sizing and such.
 */

#define WordSize sizeof(word)

/*
 *  The following definitions assume ANSI C.
 */
#define Cat(x,y) x##y
#define Lit(x) #x
#define Bell '\a'


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

#ifndef PPInit
   #define PPInit ""
#endif					/* PPInit */

#ifndef PPDirectives
   #define PPDirectives {"passthru", PpKeep},
#endif					/* PPDirectives */

#ifndef ExecSuffix
   #define ExecSuffix ""
#endif					/* ExecSuffix */

#ifndef CSuffix
   #define CSuffix ".c"
#endif					/* CSuffix */

#ifndef TmpSuffix
   #define TmpSuffix ".tmp"
#endif					/* TmpSuffix */

#ifndef ObjSuffix
   #define ObjSuffix ".o"
#endif					/* ObjSuffix */

/*
 * Note, size of the hash table is a power of 2:
 */
#define IHSize 128
#define IHasher(x)	(((unsigned int)(unsigned long)(x))&(IHSize-1))


#ifndef USuffix
   #define USuffix ".u"
#endif				/* USuffix */

#ifndef UXSuffix
   #define UXSuffix ".ux"
#endif				/* UXSuffix */

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

