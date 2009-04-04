/*
 * The functions in this file maintain a hash table of strings and manage
 *   string buffers.
 */
#include "../h/gsupport.h"
#include <stdarg.h>

/*
 * Prototype for static function.
 */
static int streq  (int len,char *s1,char *s2);

/*
 * Entry in string table.
 */
struct str_entry {
    char *s;                 /* string */
    int length;              /* length of string */
    struct str_entry *next;
};

#define SBufSize 1024                     /* initial size of a string buffer */
#define StrTblSz 16000                    /* size of string hash table */
static struct str_entry **str_tbl = NULL; /* string hash table */

/*
 * init_str - initialize string hash table.
 */
void init_str()
{
    int h;

    if (str_tbl == NULL) {
        str_tbl = safe_alloc(StrTblSz * sizeof(struct str_entry *));
        for (h = 0; h < StrTblSz; ++h)
            str_tbl[h] = NULL;
    }
}

/*
 * free_stbl - free string table.
 */
void free_stbl()
{
    struct str_entry *se, *se1;
    int h;

    for (h = 0; h < StrTblSz; ++h)
        for (se = str_tbl[h]; se != NULL; se = se1) {
            se1 = se->next;
            free((char *)se);
        }

    free((char *)str_tbl);
    str_tbl = NULL;
}

void dump_stbl()
{
    struct str_entry *se;
    int h;

    for (h = 0; h < StrTblSz; ++h) {
        int i = 0;
        for (se = str_tbl[h]; se != NULL; se = se->next)
            ++i;
            /*printf("entry len=%d s=%s\n",se->length,se->s);*/
        printf("Table %d -> %d entries\n", h, i);
    }
    printf("-----\n");
}

void dump_sbuf(struct str_buf *s)
{
    printf("size=%d\n",s->size);
    printf("strtimage=%p endimage=%p (%d bytes)\n",s->strtimage,s->endimage,(s->endimage-s->strtimage));
    printf("end=%p (remain=%d) \n",s->end,(s->end-s->endimage));
}

/*
 * init_sbuf - initialize a new sbuf struct.  This just zeroes the
 * structure.
 */
void init_sbuf(struct str_buf *sbuf)
{
    memset(sbuf, 0, sizeof(*sbuf));
}

/*
 * clear_sbuf - free string buffer storage.
 */
void clear_sbuf(struct str_buf *sbuf)
{
    struct str_buf_frag *sbf, *sbf1;

    for (sbf = sbuf->frag_lst; sbf != NULL; sbf = sbf1) {
        sbf1 = sbf->next;
        free((char *)sbf);
    }
    memset(sbuf, 0, sizeof(*sbuf));
}

/*
 * new_sbuf - allocate a new buffer for a sbuf struct, copying the partially
 *   created string from the end of full buffer to the new one.
 */
void new_sbuf(struct str_buf *sbuf)
{
    struct str_buf_frag *sbf;
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
    sbf = safe_alloc(sizeof(struct str_buf_frag) + (sbuf->size - 1));
    sbf->next = sbuf->frag_lst;
    sbuf->frag_lst = sbf;
    sbuf->strtimage = sbf->s;
    s2 = sbuf->strtimage;
    while (s1 < sbuf->endimage)
        *s2++ = *s1++;
    sbuf->endimage = s2;
    sbuf->end = sbuf->strtimage + sbuf->size;
}

/*
 * spec_str - install a special string (null terminated) in the string table.
 */
char *spec_str(s)
    char *s;
{
    struct str_entry *se;
    register char *s1;
    register int l;
    unsigned int h;

    h = 0;
    l = 0;
    s1 = s;
    /* NB: Hash and length computations include the \0 at the end */
    for (;;) {
        h = 13 * h + (*s1 & 0377);
        ++l;
        if (!*s1)
            break;
        ++s1;
    }
    h %= StrTblSz;
    for (se = str_tbl[h]; se != NULL; se = se->next)
        if (l == se->length && streq(l, s, se->s))
            return se->s;
    se = Alloc(struct str_entry);
    se->s = s;
    se->length = l;
    se->next = str_tbl[h];
    str_tbl[h] = se;
    return s;
}

/*
 * str_install - find out if the string at the end of the buffer is in
 *   the string table. If not, put it there. Return a pointer to the
 *   string in the table.
 */
char *str_install(struct str_buf *sbuf)
{
    unsigned int h;
    struct str_entry *se;
    register char *s;
    register char *e;
    int l;

    /* null terminate the buffered copy of the string */
    AppChar(*sbuf, '\0');   
    s = sbuf->strtimage;
    e = sbuf->endimage;

    /*
     * Compute hash value.
     */
    h = 0;
    while (s < e)
        h = 13 * h + (*s++ & 0377);
    h %= StrTblSz;
    s = sbuf->strtimage;
    l = e - s;
    for (se = str_tbl[h]; se != NULL; se = se->next)
        if (l == se->length && streq(l, s, se->s)) {
            /*
             * A copy of the string is already in the table. Delete the copy
             *  in the buffer.
             */
            sbuf->endimage = s;
            return se->s;
        }

    /*
     * The string is not in the table. Add the copy from the buffer to the
     *  table.
     */
    se = Alloc(struct str_entry);
    se->s = s;
    se->length = l;
    sbuf->strtimage = e;
    se->next = str_tbl[h];
    str_tbl[h] = se;
    return se->s;
}

/*
 * Chuck away any accumulated chars at the end of the buffer.
 */
void zero_sbuf(struct str_buf *sbuf)
{
    sbuf->endimage = sbuf->strtimage;

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

/*
 * Call clear_sbuf on the static sbufs in this file.  This should only
 * be called in conjunction with free_stbl(), which will have pointers
 * into any memory allocated in these sbufs.
 */
void clear_local_sbufs()
{
    int i;
    clear_sbuf(&util);
    for (i = 0; i < ElemCount(tbuf); ++i)
        clear_sbuf(&tbuf[i]);
    tcount = 0;
}

/*
 * streq - compare s1 with s2 for len bytes, and return 1 for equal,
 *  0 for not equal.
 */
static int streq(int len, char *s1, char *s2)
{
    while (len--)
        if (*s1++ != *s2++)
            return 0;
    return 1;
}
