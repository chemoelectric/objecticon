/*
 * cstructs.h - structures and accompanying manifest constants for functions
 *  in the common subdirectory.
 */

/*
 * fileparts holds a file name broken down into parts.
 */
struct fileparts {			/* struct of file name parts */
   char *dir;				/* directory */
   char *name;				/* name */
   char *ext;				/* extension */
   };

/*
 * A structure for holding a static string buffer.
 */
struct staticstr {
    size_t smin;                        /* don't shrink below this size */
    size_t curr;                        /* the current allocated size */
    char *s;                            /* the buffer */
};

/*
 * Structures for the mb_ functions, which allow multiple allocations
 * from a single structure, which can then be freed all at once.
 */
struct membuff_block {
    char *mem, *free;
    size_t size;
    struct membuff_block *next;
};

struct membuff {
    char *name;
    size_t init_size;
    struct membuff_block *first, *last, *curr;
};

/*
 * str_buf references a string buffer. Strings are built a character
 *  at a time. When a buffer "fragment" is filled, another is allocated
 *  and the the current string copied to it.
 */
struct str_buf_frag {
   struct str_buf_frag *next;     /* next buffer fragment */
   char s[1];                     /* variable size buffer, really > 1 */
   };

struct str_buf {
   size_t size;                   /* total size of current buffer */
   char *strtimage;               /* start of string currently being built */
   char *endimage;                /* next free character in buffer */
   char *end;                     /* end of current buffer */
   struct str_buf_frag *frag_lst; /* list of buffer fragments */
   struct str_buf *next;          /* buffers can be put on free list */
   };

#define AppChar(sbuf, c) do {\
   if ((sbuf).endimage >= (sbuf).end)\
      new_sbuf(&(sbuf));\
   *((sbuf).endimage)++ = (c); } while (0)

#define CurrLen(sbuf) ((sbuf).endimage - (sbuf).strtimage)

/*
 * minimum number of unsigned ints needed to hold the bits of a cset - only
 *  used in translators, not in the run-time system.
 */
#define BVectSize 16

/*
 * Number of elements of a C array, and element size.
 */
#define ElemCount(a)  (sizeof(a)/sizeof(a[0]))
#define ElemSize(a)   (sizeof(a[0]))

/*
 * Absolute value, maximum, and minimum.
 */
#define Abs(x)          (((x)<0)?(-(x)):(x))
#define Max(x,y)        ((x)>(y)?(x):(y))
#define Min(x,y)        ((x)<(y)?(x):(y))

/*
 * Compare double to zero with given tolerance factor.
 */
#define NearZero(x, zs) (fabs(x) < pow(10.0, -(zs + 1)))

/*
 * Hash functions for symbol tables.  Cast to uword so that the result
 * is never -ve, and avoid compiler warnings about casting pointer to
 * narrower type.
 */
#define hasher(x,obj)   (((uword)x)%ElemCount(obj))
/* If x is a pointer */
#define ptrhasher(x,obj)   ((((uword)x)>>5 ^ ((uword)x))%ElemCount(obj))

/*
 * Clear an object
 */
#define ArrClear(obj) (memset(obj, 0, sizeof(obj)))
#define StructClear(obj) (memset(&obj, 0, sizeof(obj)))

/*
 * Allocate an object and zero memory.
 */
#define Alloc(type)   safe_zalloc(sizeof(type))

/*
 * Allocate an object, but don't zero memory.
 */
#define Alloc1(type)   safe_malloc(sizeof(type))

/*
 *  Important note:  The code that follows is not strictly legal C.
 *   It tests to see if pointer p2 is between p1 and p3. This may
 *   involve the comparison of pointers in different arrays, which
 *   is not well-defined.  The casts of these pointers to unsigned "words"
 *   (longs or ints, depending) works with all C compilers and architectures
 *   on which Icon has been implemented.  However, it is possible it will
 *   not work on some system.  If it doesn't, there may be a "false
 *   positive" test, which is likely to cause a memory violation or a
 *   loop. It is not practical to implement Icon on a system on which this
 *   happens.
 */

#define InRange(p1,p2,p3) ((uword)(p2) >= (uword)(p1) && (uword)(p2) < (uword)(p3))

#define DiffPtrsBytes(p1,p2) DiffPtrs((char*)(p1), (char*)(p2))

/*
 * Return x rounded up to the next multiple of WordSize.
 */
#define WordRound(x) (((x) + WordSize - 1) & -WordSize)

/*
 * Miscellaneous definitions
 */

#define MAX_CODE_POINT 0x10FFFF
#define MAX_UTF8_SEQ_LEN 6
extern int utf8_seq_len_arr[];
#define UTF8_SEQ_LEN(ch) utf8_seq_len_arr[(ch) & 0xff]

#define URL_UNRESERVED "/-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"

/* Data structures for cset char ranges */

struct range {
    word from, to;
};

struct rangeset {
    word n_ranges;         /* Number of entries in range */
    word n_alloc;          /* Alloced space in both range & temp */
    struct range *range;   /* Range data */
    struct range *temp;    /* Temporary area */
};

/*
 * The following code is operating-system dependent [@filepart.01].
 *
 *  Define symbols for building file names.
 *  1. FILEPREFIX: the characters that terminate a file name prefix
 *  2. FILESEP: the char to insert after a dir name, if any
 *  3. PATHSEP: separator character on $PATH, $OI_PATH etc.
 */

#if UNIX
#define FILESEP '/'
#define FILEPREFIX "/"
#define PATHSEP ':'
#endif
#if PLAN9
#define FILESEP '/'
#define FILEPREFIX "/"
#define PATHSEP ' '
#endif
#if MSWIN32
#define FILESEP '\\'
#define FILEPREFIX "/:\\"
#define PATHSEP ';'
#endif
