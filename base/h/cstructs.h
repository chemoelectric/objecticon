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
struct str_buf {
   size_t size;                   /* total size of current buffer */
   char *strtimage;               /* start of string currently being built */
   char *endimage;                /* next free character in buffer */
   char *end;                     /* end of current buffer */
   };

#define AppChar(sbuf, c) do {\
   if ((sbuf).endimage >= (sbuf).end)\
      new_sbuf(&(sbuf));\
   *((sbuf).endimage)++ = (c); } while (0)

#define CurrLen(sbuf) ((sbuf).endimage - (sbuf).strtimage)

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
 * Hash function for a pointer and a fixed-size hash table.
 */
#define hasher(x,obj)   (hashptr(x) % ElemCount(obj))

/*
 * Hash calculation for a pointer (or any large number).  Cast to
 * uword so that the result is never -ve, and avoid compiler warnings
 * about casting pointer to narrower type.
 */
#define hashptr(x)   ((((uword)(x))>>5 ^ ((uword)(x))))

/*
 * Define a hash table structure to use with the functions in
 * mlocal.c.  "type" is the list structure type of the elements in the
 * buckets and must include a linked list "next" field as its first
 * element.
 */
#define DefineHash(name, type) \
struct name { \
    int init;                   /* Initial desired number of bucket lists */ \
    uword (*hash)(type *);      /* Hash function */ \
    int size;                   /* Number of entries */ \
    int nbuckets;               /* Number of bucket lists */ \
    type **l;                   /* Bucket lists */ \
}

/*
 * Expands to an expression which gives the bucket list for the given
 * hash table t and hash number h.  The result is NULL if the list is
 * empty, or the table has no buckets.
 */
#define Bucket(t, h) ((t).nbuckets == 0 ? NULL : (t).l[(h) % (t).nbuckets])

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
#define UDiffPtrsBytes(p1,p2) ((uword)DiffPtrsBytes(p1,p2))
#define UDiffPtrs(p1,p2) ((uword)DiffPtrs(p1,p2))

/*
 * Return x rounded up to the next multiple of WordSize.
 */
#define WordRound(x) (((x) + WordSize - 1) & -WordSize)

/*
 * NULL cast to a void *; this is useful in vararg lists, where we
 * need to be certain that we are using a true pointer (NULL might be
 * defined as "0", an int, and hence of a different size).
 */
#define NullPtr ((void *)NULL)

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
