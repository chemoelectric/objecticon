/*
 * Icon configuration.
 */

/*
 * System-specific definitions are in define.h
 */

/*
 *  A number of symbols are defined here.  Some are specific to individual
 *  to operating systems.  Examples are:
 *
 *	MSWIN32		MS-DOS for PCs
 *	UNIX		any UNIX system; also set for BeOS
 *
 *  These are defined to be 1 or 0 depending on which operating system
 *  the installation is being done under.  They are all defined and only
 *  one is defined to be 1.  (They are used in the form #if VAX || MSWIN32.)
 *
 *  There also are definitions of symbols for specific computers and
 *  versions of operating systems.  These include:
 *
 *	SUN		code specific to the Sun Workstation
 *	MICROSOFT	code specific to the Microsoft C compiler for MS-DOS
 *
 *  Other definitions may occur for different configurations. These include:
 *
 *	DeBug		debugging code
 *
 *  Other definitions perform configurations that are common to several
 *  systems. An example is:
 *
 *	Double		align reals at double-word boundaries
 *
 */

/*
 * If COMPILER is not defined, code for the interpreter is compiled.
 */

   #define COMPILER 0

/*
 * The following definitions insure that all the symbols for operating
 * systems that are not relevant are defined to be 0 -- so that they
 * can be used in logical expressions in #if directives.
 */

#ifndef PORT
   #define PORT 0
#endif					/* PORT */

#ifndef MSWIN32
   #define MSWIN32 0
#endif					/* MSWIN32 */

#ifndef UNIX
   #define UNIX 0
#endif					/* UNIX */

/*
 * The following definitions serve to cast common conditionals is
 *  a positive way, while allowing defaults for the cases that
 *  occur most frequently.  That is, if co-expressions are not supported,
 *  NoCoexpr is defined in define.h, but if they are supported, no
 *  definition is needed in define.h; nonetheless subsequent conditionals
 *  can be cast as #ifdef Coexpr.
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

#ifndef COEXPSIZE
   #define COEXPSIZE "COEXPSIZE"
#endif

#ifndef STRSIZE
   #define STRSIZE "STRSIZE"
#endif

#ifndef HEAPSIZE
   #define HEAPSIZE "HEAPSIZE"
#endif

#ifndef BLOCKSIZE
   #define BLOCKSIZE "BLOCKSIZE"
#endif

#ifndef BLKSIZE
   #define BLKSIZE "BLKSIZE"
#endif

#ifndef MSTKSIZE
   #define MSTKSIZE "MSTKSIZE"
#endif

#ifndef QLSIZE
   #define QLSIZE "QLSIZE"
#endif

#ifndef ICONCORE
   #define ICONCORE "ICONCORE"
#endif

#ifndef IPATH
   #define IPATH "OIPATH"
#endif

#ifndef LPATH
   #define LPATH "OLPATH"
#endif

#ifdef MSWindows
   #undef Graphics
   #define Graphics 1
#endif					/* MSWindows */

#ifdef HAVE_LIBX11
   #define Graphics 1
   #define XWindows 1
#endif

/*
 * Other defaults.
 */

#ifndef AllocType
   #define AllocType unsigned int
#endif					/* AllocType */

#ifndef MaxPath
   #define MaxPath 1024
#endif					/* MaxPath */

#ifndef StackAlign
   #define StackAlign 2
#endif					/* StackAlign */

#ifndef WordBits
   #define WordBits 32
#endif					/* WordBits */

#ifndef IntBits
   #define IntBits WordBits
#endif					/* IntBits */

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
 * Features enabled by default under certain systems
 */

#ifndef Pipes
   #if UNIX
      #define Pipes
   #endif	
#endif					/* Pipes */


/*
 * Default sizing and such.
 */

#define WordSize sizeof(word)
#define ShortSize sizeof(short)

#ifndef ByteBits
   #define ByteBits 8
#endif					/* ByteBits */

/*
 *  The following definitions assume ANSI C.
 */
#define Cat(x,y) x##y
#define Lit(x) #x
#define Bell '\a'

/*
 *  something to handle a cast problem for signal().
 */
#ifndef SigFncCast
   #define SigFncCast (void (*)(int))
#endif					/* SigFncCast */

#ifndef QSortFncCast
   #define QSortFncCast int (*)(const void *,const void *)
#endif					/* QSortFncCast */

/*
 * Customize output if not pre-defined.
 */

#ifndef TraceOut
   #define TraceOut(s) fprintf(stderr,s)
#endif					/* TraceOut */

#define BackSlash "\\"

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

/*
 * The following code is operating-system dependent [@config.01].
 *  Any configuration stuff that has to be done at this point.
 */

#if PORT
   /* Probably nothing is needed. */
Deliberate Syntax Error
#endif					/* PORT */

#ifndef NoWildCards
   #if MSWIN32
      #define WildCards 1
   #else				/* MSWIN32 || ... */
      #define WildCards 0
   #endif				/* MSWIN32 || ... */
#else					/* NoWildCards */
   #define WildCards 0
#endif					/* NoWildCards */

/*
 * End of operating-system specific code.
 */

#ifndef DiffPtrs
   #define DiffPtrs(p1,p2) (word)((p1)-(p2))
#endif					/* DiffPtrs */

#ifndef AllocReg
   #define AllocReg(n) malloc((msize)n)
#endif					/* AllocReg */

#ifndef RttSuffix
   #define RttSuffix ".r"
#endif					/* RttSuffix */

#ifndef DBSuffix
   #define DBSuffix ".db"
#endif					/* DBSuffix */

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

#ifndef HSuffix
   #define HSuffix ".h"
#endif					/* HSuffix */

#ifndef ObjSuffix
   #define ObjSuffix ".o"
#endif					/* ObjSuffix */

#ifndef LibSuffix
   #define LibSuffix ".a"
#endif					/* LibSuffix */

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
 *  Vsizeof is for use with variable-sized (i.e., indefinite)
 *   structures containing an array of descriptors declared of size 1
 *   to avoid compiler warnings associated with 0-sized arrays.
 */

#define Vsizeof(s)	(sizeof(s) - sizeof(struct descrip))

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
