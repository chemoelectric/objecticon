/*
 * Set up typedefs and related definitions depending on whether or not
 * pointers are the same size as ints or longs (WordBits is by default
 * the number of bits in a void*).  After this, word should be an
 * integer type so that sizeof(word)==sizeof(void*)==8*WordBits.
 */

#if IntBits == WordBits
   typedef int word;
   typedef unsigned int uword;
   #define WordFmtCh "d"
   #define XWordFmtCh "x"
   #define UWordFmtCh "u"
#elif LongBits == WordBits
   typedef long word;
   typedef unsigned long uword;
   #define WordFmtCh "ld"
   #define XWordFmtCh "lx"
   #define UWordFmtCh "lu"
#elif LongLongBits == WordBits
   typedef long long word;
   typedef unsigned long long uword;
   #define WordFmtCh "lld"
   #define XWordFmtCh "llx"
   #define UWordFmtCh "llu"
#else
   #error "WordBits must equal either IntBits, LongBits or LongLongBits"
#endif

#define WordFmt "%"WordFmtCh
#define XWordFmt "%"XWordFmtCh
#define UWordFmt "%"UWordFmtCh

/*
 * Select a size for large int DIGIT type; DigitBits is defined as
 * WordBits/2.
 */
#define DigitBits           (WordBits / 2)
#if DigitBits == ShortBits
   typedef unsigned short DIGIT;
#elif DigitBits == IntBits
   typedef unsigned int DIGIT;
#else
   #error "DigitBits must equal either ShortBits or IntBits"
#endif

#if RealBits == WordBits
   #define RealInDesc 1
#endif

#if IntBits == 32
   typedef int Integer32;
   typedef unsigned int uInteger32;
#elif ShortBits == 32
   typedef short Integer32;
   typedef unsigned short uInteger32;
#elif LongBits == 32
   typedef long Integer32;
   typedef unsigned long uInteger32;
#else
   #error "Either IntBits, ShortBits or LongBits must be 32"
#endif

#if IntBits == 16
   typedef int Integer16;
   typedef unsigned int uInteger16;
#elif ShortBits == 16
   typedef short Integer16;
   typedef unsigned short uInteger16;
#elif LongBits == 16
   typedef long Integer16;
   typedef unsigned long uInteger16;
#else
   #error "Either IntBits, ShortBits or LongBits must be 16"
#endif

/*
 * Typedefs to make some things easier.
 */

typedef struct descrip *dptr;
typedef long long longlong;
typedef unsigned long long ulonglong;
