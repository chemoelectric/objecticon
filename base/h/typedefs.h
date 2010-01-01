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

/*
 * Select a size for large int DIGIT type; DigitBits is defined as
 * WordBits/2.
 */
#if DigitBits == ShortBits
   typedef unsigned short DIGIT;
#elif DigitBits == IntBits
   typedef unsigned int DIGIT;
#else
   #error "DigitBits must equal either ShortBits or IntBits"
#endif

/*
 * Typedefs to make some things easier.
 */

typedef struct descrip *dptr;
typedef word C_integer;
#if SIZEOF_LONG_LONG != 0
typedef long long longlong;
typedef unsigned long long ulonglong;
#else
typedef long longlong;
typedef unsigned long ulonglong;
#endif
