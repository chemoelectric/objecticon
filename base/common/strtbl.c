/*
 * The functions in this file maintain a hash table of strings and manage
 *   string buffers.
 */
#include "../h/gsupport.h"

/*
 * Entry in string table.
 */
struct str_entry {
    struct str_entry *next;
    char *s;                 /* string */
    int length;              /* length of string */
};

#define SBufSize 1024                     /* initial size of a string buffer */

/*
 * init_str - initialize string hash table.
 */
void init_str()
{
}

/*
 * Hash a string of length len bytes (may include nulls).
 */
static uword hash(char *s, int len)
{
    uword u;
    int l;
    l = len;
    if (l > 10)		/* limit scan to first ten characters */
        l = 10;
    u = 0;
    while (l-- > 0) {
        u += *s++ & 0xFF;	/* add unsigned version of next char */
        u *= 37;		/* scale total by a nice prime number */
    }
    u += len;			/* add the (untruncated) string length */
    return u;
}

static uword str_tbl_hash_func(struct str_entry *p) { return hash(p->s, p->length); }
DefineHash(, struct str_entry) str_tbl = { 16000, str_tbl_hash_func };

#if 0
void dump_stbl()
{
    struct str_entry *se;
    int h;

    for (h = 0; h < str_tbl.nbuckets; ++h) {
        int i = 0;
        for (se = str_tbl.l[h]; se != NULL; se = se->next)
            ++i;
            /*printf("entry len=%d s=%s\n",se->length,se->s);*/
        printf("Table %d -> %d entries\n", h, i);
    }
    printf("-----\n");
}

void dump_sbuf(struct str_buf *s)
{
    printf("size=%lu\n",(unsigned long)s->size);
    printf("strtimage=%p endimage=%p (%ld bytes)\n",s->strtimage,s->endimage,(long)(s->endimage-s->strtimage));
    printf("end=%p (remain=%ld) \n",s->end,(long)(s->end-s->endimage));
}
#endif

/*
 * new_sbuf - allocate a new buffer for a sbuf struct, copying the partially
 *   created string from the end of full buffer to the new one.
 */
void new_sbuf(struct str_buf *sbuf)
{
    char *s1, *s2;

    if (sbuf->size == 0) 
        sbuf->size = SBufSize;
    else {
        /*
         * The new buffer is larger than the old one to insure that any
         *  size string can be buffered.
         */
        sbuf->size *= 2;
    }

    s1 = sbuf->strtimage;
    s2 = sbuf->strtimage = safe_malloc(sbuf->size);
    while (s1 < sbuf->endimage)
        *s2++ = *s1++;
    sbuf->endimage = s2;
    sbuf->end = sbuf->strtimage + sbuf->size;
}

static struct str_entry *lookup(char *s, int len)
{
    struct str_entry *se = 0;
    if (str_tbl.nbuckets > 0) {
        se = str_tbl.l[hash(s, len) % str_tbl.nbuckets];
        while (se &&
               (len != se->length || memcmp(s, se->s, len) != 0))
            se = se->next;
    }
    return se;
}

/*
 * spec_str - install a special string (null terminated) in the string table.
 */
char *spec_str(char *s)
{
    struct str_entry *se;
    int l;
    /* The null is included in the string. */
    l = strlen(s) + 1;
    se = lookup(s, l);
    if (!se) {
        se = Alloc(struct str_entry);
        se->s = s;
        se->length = l;
        add_to_hash(&str_tbl, se);
    }
    return se->s;
}

/*
 * str_install - find out if the string at the end of the buffer is in
 *   the string table. If not, put it there. Return a pointer to the
 *   string in the table.
 */
char *str_install(struct str_buf *sbuf)
{
    struct str_entry *se;
    char *s;
    char *e;
    int l;

    /* null terminate the buffered copy of the string */
    AppChar(*sbuf, '\0');   
    s = sbuf->strtimage;
    e = sbuf->endimage;
    l = e - s;
    se = lookup(s, l);
    if (se) {
        /*
         * A copy of the string is already in the table. Delete the copy
         *  in the buffer.
         */
        sbuf->endimage = s;
    } else {
        /*
         * The string is not in the table. Add the copy from the buffer to the
         *  table.
         */
        se = Alloc(struct str_entry);
        se->s = s;
        se->length = l;
        sbuf->strtimage = e;
        add_to_hash(&str_tbl, se);
    }
    return se->s;
}

/*
 * Chuck away any accumulated chars at the end of the buffer.
 */
void zero_sbuf(struct str_buf *sbuf)
{
    sbuf->endimage = sbuf->strtimage;
}

/*
 * Append n chars from s to the given buf
 */
void append_n(struct str_buf *sbuf, char *s, int n)
{
    while (n--)
        AppChar(*sbuf, *s++);
}

static struct str_buf util;

/*
 * Intern a string using our local sbuf
 */
char *intern(char *s)
{
    zero_sbuf(&util);
    while (*s)
        AppChar(util, *s++);
    return str_install(&util);
}

/*
 * Intern exactly n chars from s using our local sbuf
 */
char *intern_n(char *s, int n)
{
    zero_sbuf(&util);
    while (n--)
        AppChar(util, *s++);
    return str_install(&util);
}

/*
 * Catenate and intern the given strings (terminated with a null
 * pointer).
 */
char *join(char *s, ...)
{
    va_list argp;
    zero_sbuf(&util);
    va_start(argp, s);
    while (s) {
        while (*s)
            AppChar(util, *s++);
        s = va_arg(argp, char*);
    }
    va_end(argp);
    return str_install(&util);
}

static struct str_buf tbuf[8];
static int tcount = 0;

/*
 * get_sbuf - get a temporary str_buf
 */
struct str_buf *get_sbuf()
{
    struct str_buf *sbuf;
    if (tcount >= ElemCount(tbuf)) {
        fprintf(stderr, "get_sbuf: out of buffers to allocate\n");
        exit(EXIT_FAILURE);
    }
    sbuf = &tbuf[tcount++];
    zero_sbuf(sbuf);
    return sbuf;
}

/*
 * rel_sbuf - free the most recent temporary str_buf allocated by
 * get_sbuf.
 */
void rel_sbuf(struct str_buf *sbuf)
{
    if (tcount == 0 || &tbuf[tcount - 1] != sbuf) {
        fprintf(stderr, "get_sbuf: rel_sbuf out of sequence\n");
        exit(EXIT_FAILURE);
    }
    --tcount;
}
