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

#define asize(obj)      ((sizeof(obj)/sizeof(obj[0])))
#define clear(obj)      (memset(obj, 0, sizeof(obj)))
