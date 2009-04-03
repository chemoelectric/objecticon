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


   /*
    * Typedefs for the interpreter.
    */
   
   /*
    * Icode consists of operators and arguments.  Operators are small integers,
    *  while arguments may be pointers.  To conserve space in icode files on
    *  computers with 16-bit ints, icode is written by the linker as a mixture
    *  of ints and words (longs).  When an icode file is read in and processed
    *  by the interpreter, it looks like a C array of mixed ints and words.
    *  Accessing this "nonstandard" structure is handled by a union of int and
    *  word pointers and incrementing is done by incrementing the appropriate
    *  member of the union (see the interpreter).  This is a rather dubious
    *  method and certainly not portable.  A better way might be to address
    *  icode with a char *, but the incrementing code might be inefficient
    *  (at a place that experiences a lot of execution activity).
    *
    * For the moment, the dubious coding is isolated under control of the
    *  size of integers.
    */
   
   #if IntBits != WordBits
   
      typedef union {
         int *op;
         word *opnd;
         } inst;
      
      #else				/* IntBits != WordBits */
      
      typedef union {
         word *op;
         word *opnd;
         } inst;
      
   #endif				/* IntBits != WordBits */
      
