/*
 * Set up typedefs and related definitions depending on whether or not
 * pointers are the same size as ints or longs (WordBits is by default
 * the number of bits in a void*).  After this, word should be an
 * integer type so that sizeof(word)==sizeof(void*)==8*WordBits.
 */

#if WordBits == 64
   #define LogWordBits  6                       /* log of WordBits */
   #define MaxUWord ((uword)0xffffffffffffffff) /* largest uword */
   #define MaxWord  ((word)0x7fffffffffffffff)  /* largest word */
   #define MinWord  ((word)0x8000000000000000)  /* smallest word */
   #define RandA        3249286849523012805     /* random seed multiplier */
                                                /* (from "Tables of Linear Congruential Generators"
                                                 *  by Pierre L'Ecuyer) */
   #define RandC        1442695040888963407     /* random seed additive constant */
   #define RandScale    1.0842021724855e-19     /* random scale factor, approx 1/(2^63) */
   #define F_Nqual      0x8000000000000000      /* set if NOT string qualifier*/
   #define F_Var        0x4000000000000000      /* set if variable */
   #define F_Ptr        0x1000000000000000      /* set if value field is ptr */
   #define F_Typecode   0x2000000000000000      /* set if dword incls typecode*/
#elif WordBits == 32
   #define LogWordBits  5                       /* log of WordBits */
   #define MaxUWord     ((uword)0xffffffff)     /* largest uword */
   #define MaxWord      ((word)0x7fffffff)      /* largest word */
   #define MinWord      ((word)0x80000000)      /* smallest word */
   #define RandA        1103515245              /* random seed multiplier */
   #define RandC        453816693               /* random seed additive constant */
   #define RandScale    4.656612873e-10         /* random scale factor, approx 1/(2^31) */
   #define F_Nqual      0x80000000              /* set if NOT string qualifier */
   #define F_Var        0x40000000              /* set if variable */
   #define F_Ptr        0x10000000              /* set if value field is pointer */
   #define F_Typecode   0x20000000              /* set if dword includes type code */
#else
   #error "WordBits must equal either 32 or 64"
#endif

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

/*
 * Typedefs to make some things easier.
 */

typedef struct descrip *dptr;
typedef long long longlong;
typedef unsigned long long ulonglong;
