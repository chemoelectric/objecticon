/*
 * Type for an externally findable & setable integer, used by "setsize". CS
 */

/*
 * typdefs for the run-time system.
 */

typedef int ALIGN;		/* pick most stringent type for alignment */
typedef unsigned int DIGIT;

/*
 * Default sizing and such.
 */

/*
 * Set up typedefs and related definitions depending on whether or not
 * pointers are the same size as ints or longs (WordBits is by default
 * the number of bits in a void*).  After this, word should be an
 * integer type so that sizeof(word)==sizeof(void*)==8*WordBits.
 */

#if IntBits == WordBits
   typedef int word;
   typedef unsigned int uword;
#elif LongBits == WordBits
   typedef long word;
   typedef unsigned long uword;
#else
   #error "WordBits must equal either IntBits or LongBits"
#endif

#ifndef PointerDef
   typedef void *pointer;
#endif					/* PointerDef */

/*
 * Typedefs to make some things easier.
 */

typedef int (*fptr)();
typedef struct descrip *dptr;

typedef word C_integer;

/*
 * A success continuation is referenced by a pointer to an integer function
 *  that takes no arguments.
 */
typedef int (*continuation) (void);
