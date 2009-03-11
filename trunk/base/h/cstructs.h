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
 * str_buf references a string buffer. Strings are built a character
 *  at a time. When a buffer "fragment" is filled, another is allocated
 *  and the the current string copied to it.
 */
struct str_buf_frag {
   struct str_buf_frag *next;     /* next buffer fragment */
   char s[1];                     /* variable size buffer, really > 1 */
   };

struct str_buf {
   unsigned int size;             /* total size of current buffer */
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
 * Clear an object
 */
#define ArrClear(obj) (memset(obj, 0, sizeof(obj)))
#define StructClear(obj) (memset(&obj, 0, sizeof(obj)))

/*
 * Allocate an object
 */
#define Alloc(type)   safe_alloc(sizeof(type))

/*
 * Miscellaneous definitions
 */

#define MAX_CODE_POINT 0x10FFFF
#define MAX_UTF8_SEQ_LEN 6
extern int utf8_seq_len_arr[];
#define UTF8_SEQ_LEN(ch) utf8_seq_len_arr[(ch) & 0xff]

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
 *  3. PATHSEP: separator character on $PATH, $OIPATH etc.
 */

#if UNIX
#define FILESEP '/'
#define FILEPREFIX "/"
#define PATHSEP ':'
#endif
#if MSWIN32
#define FILESEP '\\'
#define FILEPREFIX "/:\\"
#define PATHSEP ';'
#endif
