/*
 * mlocal.c - special platform specific code
 */
#include "../h/gsupport.h"


static char *tryfile(char *dir, char *name, char *extn);
static char *tryexe(char *dir, char *name);
static word calc_ucs_offset_words(word n_offs, int offset_bits);
static word calc_ucs_index_step(word utf8_len, word len, int offset_bits);
static char *getcachedcwd(void);

/*
 *  findexe(prog) -- find absolute executable, searching $PATH (using
 *  POSIX 1003.2 rules) for executable name.
 * 
 *  A pointer to a static buffer is returned, or NULL if
 *  not found.  NB: this buffer is the same as that returned
 *  by pathfind and makename.
 */
char *findexe(char *name) 
{
    char *path, *p;
    /* Does name have a separator char? If so, don't search $PATH */
    for (p = name; *p; ++p) {
        if (strchr(FILEPREFIX, *p))
            return tryexe(0, name);
    }

#if MSWIN32
    /* On windows, the cd is always on the path. */    
    if ((p = tryexe(0, name)))
        return p;
#endif

    path = getenv_nn("PATH");
    if (!path)
        path = "";

    for (;;) {
        char *e = pathelem(&path);
        if (!e)
            break;
        if ((p = tryexe(e, name)))        /* look for file */
            return p;
    }

    return 0;
}

/*
 * Return a directory name which is the value of OI_HOME followed by
 * the given list of sub-directories, terminated with null.  The
 * returned path always ends with a separator.  NB: returns null
 * if OI_HOME is not defined.
 */
char *oihomewalk(char *e, ...)
{
    static struct staticstr buf = {128};
    char *oh, *p, *e1;
    va_list ap;
    int len;

    oh = getenv_nn("OI_HOME");
    if (!oh)
        return 0;

    len = strlen(oh) + 1;  /* +1 for the possible first separator */

    e1 = e;
    va_start(ap, e);
    while (e1) {
        len += strlen(e1) + 1;  /* dir + 1 for the separator */
        e1 = va_arg(ap, char*);
    }
    ++len;  /* null byte at end */
    va_end(ap);

    ssreserve(&buf, len);
    p = buf.s;
    p += sprintf(buf.s, "%s", oh);
    /* Add a file separator if needed. */
    if (p > buf.s && !strchr(FILEPREFIX, *(p - 1))) {
        *p++ = FILESEP;
        *p = 0;
    }

    e1 = e;
    va_start(ap, e);
    while (e1) {
        p += sprintf(p, "%s%c", e1, FILESEP);
        e1 = va_arg(ap, char*);
    }

    return buf.s;
}

/*
 * Find an executable file in the OI_HOME/bin directory.
 */
char *findoiexe(char *name) 
{
    char *t = oihomewalk("bin", NullPtr);
    return t ? tryexe(t, name) : 0;
}

#if UNIX

/*
 * Normalize a path by removing redundant slashes, . dirs and .. dirs.
 */
void normalize(char *file)
{
    char *p, *q;
    p = q = file;
    while (*p) {
        if (*p == '/' && *(p+1) == '.' && 
            *(p+2) == '.' && (*(p+3) == '/' || *(p+3) == 0)) {
            p += 3;
            if (q > file) {
                --q;
                while (q > file && *q != '/')
                    --q;
            }
        } else if (*p == '/' && *(p+1) == '.' && 
                   (*(p+2) == '/' || *(p+2) == 0)) {
            p += 2;
        } else if (*p == '/' && *(p+1) == '/') {  /* Duplicate slashes */
            ++p;
        } else
            *q++ = *p++;
    }
    *q = 0;
}

/*
 * Is a file path absolute?
 */
int isabsolute(char *s)
{
    return *s == '/';
}

/*
 * Check if a file exists as an exe.
 */
static char *tryexe(char *dir, char *name)
{
    char *s = makename(dir, name, 0);
    if (!access(s, X_OK))
        return s;
    else
        return 0;
}

/*
 * tryfile(dir, name, extn) -- check to see if file is present.
 *
 *  The file name is constructed in from dir + name + extn.  tryfile
 *  returns a pointer to a static string if successful or NULL if not.
 */
static char *tryfile(char *dir, char *name, char *extn)
{
    char *s = makename(dir, name, extn);
    if (!access(s, F_OK))
        return s;
    else
        return 0;
}
#endif

int is_flowterm_tty(FILE *f)
{
#if UNIX
    static int init, flowterm;
    if (!init) {
        char *s;
        init = 1;
        s = getenv_nn("FLOWTERM");
        if (s)
            flowterm = atoi(s);
    }
    switch (flowterm) {
        case 1 : return isatty(fileno(f));
        case 2 : return 1;
        default : return 0;
    }
#else
    return 0;
#endif
}

#if MSWIN32

/*
 * Normalize a path by lower-casing everything, changing / to \,
 * removing redundant slashes, . dirs and .. dirs.
 */
void normalize(char *file)
{
    char *p, *q;

    /*
     * Lower case everything and convert / to \
     */
    for (p = file; *p; ++p) {
        if (*p == '/')
            *p = '\\';
        else 
            *p = oi_tolower(*p);
    }
    if (oi_isalpha(file[0]) && file[1]==':') 
        file += 2;
    p = q = file;
    while (*p) {
        if (*p == '\\' && *(p+1) == '.' && 
            *(p+2) == '.' && (*(p+3) == '\\' || *(p+3) == 0)) {
            p += 3;
            if (q > file) {
                --q;
                while (q > file && *q != '\\')
                    --q;
            }
        } else if (*p == '\\' && *(p+1) == '.' && 
                   (*(p+2) == '\\' || *(p+2) == 0)) {
            p += 2;
        } else if (*p == '\\' && *(p+1) == '\\') {  /* Duplicate slashes */
            ++p;
        } else
            *q++ = *p++;
    }
    *q = 0;
}

/*
 * Is a file path absolute?
 */
int isabsolute(char *s)
{
    return oi_isalpha(*s) && s[1] == ':' && (s[2] == '\\' || s[2] == '/');
}

/*
 * Check if a file exists as an exe.
 */
static char *tryexe(char *dir, char *name)
{
    char *s = makename(dir, name, 0);

    /*
     * Try as given
     */
    if (!access(s, 0))
        return s;

    /*
     * If name has no extension, try extensions .exe and .bat
     * as alternatives.
     */
    if (*getext(name) == '\0') {
       s = makename(dir, name, ".exe");
       if (!access(s, 0))
	  return s;

       s = makename(dir, name, ".bat");
       if (!access(s, 0))
	  return s;
    }

    return 0;
}

/*
 * tryfile(dir, name, extn) -- check to see if file is readable.
 *
 *  The file name is constructed in from dir + name + extn.  findfile
 *  returns a pointer to a static string if successful or NULL if not.
 */
static char *tryfile(char *dir, char *name, char *extn)
{
    char *s = makename(dir, name, extn);
    if (strcmpi(s, "nul") == 0)
       return s;
    if (!access(s, 0))
        return s;
    else
        return 0;
}

#endif

static char *getcachedcwd()
{
    static char *buf;
    if (!buf) {
        int len = 32;
        for (;;) {
            buf = safe_realloc(buf, len);
            if (getcwd(buf, len))
                break;
            if (errno != ERANGE) {
                fprintf(stderr, "Unable to getcwd() (errno=%d)", errno);
                exit(EXIT_FAILURE);
            }
            len *= 2;
        }
    }
    return buf;
}

/*
 * Canonicalize a path by making it an absolute path if it isn't one
 * already, and then normalizing the result.  A pointer to a static
 * buffer is returned.
 */
char *canonicalize(char *path)
{
    static struct staticstr buf = {128};
    if (isabsolute(path))
        sscpy(&buf, path);
    else {
        char *cwd = getcachedcwd();
        size_t l, m;
        l = strlen(cwd);
        m = strlen(path);
        ssreserve(&buf, l + 1 + m + 1);
        memcpy(buf.s, cwd, l);
        if (!strchr(FILEPREFIX, buf.s[l - 1]))
            buf.s[l++] = FILESEP;
        memcpy(&buf.s[l], path, m + 1);
    }
    normalize(buf.s);
    return buf.s;
}

/*
 * pathfind(cd,path,name,extn) -- find file in path and return name.
 *
 *  pathfind looks for a file on a path, begining with the current
 *  directory.  Details vary by platform, but the general idea is
 *  that the file must be a readable simple text file.
 *
 *  A pointer to a static buffer is returned, or NULL if not found.
 *  NB: this buffer is the same as that returned by findexe and
 *  makename.
 * 
 *  cd is the notional current directory to test before the path
 *  path is the search path value, or NULL if unset.
 *  name is the file name.
 *  extn is the file extension (.icn or .u) to be appended, or NULL if none.
 */
char *pathfind(char *cd, char *path, char *name, char *extn)
{
    char *p, *name_dir;

    /* Don't search the path if we have an absolute file */
    if (isabsolute(name))
        return tryfile(0, name, extn);

    /* Also don't search if we have a relative name; it is relative to
     * the cd */
    name_dir = getdir(name);
    if (*name_dir) {
        char *tmp;
        int len;
        len = strlen(cd) + strlen(name_dir) + 1;
        tmp = safe_malloc(len);
        snprintf(tmp, len, "%s%s", cd, name_dir);
        p = tryfile(tmp, name, extn);
        free(tmp);
        return p;
    }

    /* Neither absolute nor relative.  Try current directory first */
    if ((p = tryfile(cd, name, extn)))
        return p;

    if (!path)
        return 0;

    for (;;) {
        char *e = pathelem(&path);
        if (!e)
            break;
        if ((p = tryfile(e, name, extn)))        /* look for file */
            return p;
    }

    return 0;                           /* return 0 if no file found */
}

/*
 * pathelem(s) -- get next path element
 * 
 * The parameter s is a pointer to a pointer to a string.  This pointer is
 * advanced and the intermediate path element copied to a static buffer
 * and returned.
 * 
 * If no path remains, the pointer is set to NULL, and NULL is
 * returned.
 */
char *pathelem(char **ps)
{
    static struct staticstr buf = {128};
    char *s = *ps, *e;
    int n;

    if (!s)
        return 0;

    e = s;
    while (*e && *e != PATHSEP)
        ++e;

    n = e - s;
    if (n == 0) {
        s = ".";
        n = 1;
    }

    ssreserve(&buf, n + 2);
    memcpy(buf.s, s, n);
    if (!strchr(FILEPREFIX, buf.s[n - 1]))
        buf.s[n++] = FILESEP;
    buf.s[n] = 0;
    if (*e)
        *ps = e + 1;
    else 
        *ps = 0;
    return buf.s;
}

/*
 * Find the last path element in a path string, eg /abc/def/file.txt -> file.txt
 */
char *last_pathelem(char *s)
{
    char *p = s + strlen(s);
    while (--p >= s) {
        if (strchr(FILEPREFIX, *p))
            return p + 1;
    }
    return s;
}

/*
 * Return true iff file f1 is newer than f2, or either file doesn't
 * exist.
 */
int newer_than(char *f1, char *f2)
{
    time_t t1;
    static struct stat buf;
    if (stat(f1, &buf) < 0)
        return 1;
    t1 = buf.st_mtime;
    if (stat(f2, &buf) < 0)
        return 1;
    return t1 > buf.st_mtime;
}

/*
 * Shorthand for fparse(s)->dir.
 */
char *getdir(char *s)
{
    return fparse(s)->dir;
}

/*
 * This is like fparse(s)->ext, but instead of returning a pointer to
 * a static buffer, it returns a pointer into the given string.  It
 * never returns NULL.
 */
char *getext(char *s)
{
    char *p, *x;
    x = p = s + strlen(s);
    while (--p > s) {
        if (*p == '.' && p < x - 1 && !strchr(FILEPREFIX, p[-1]))
            return p;
        else if (strchr(FILEPREFIX, *p))
            break;
    }
    return x;
}

/*
 * fparse - break a file name down into component parts.
 * Result is a pointer to a struct of static pointers.
 */
struct fileparts *fparse(char *s)
{
    static struct staticstr buf = {128};
    static struct fileparts fp;
    int n;
    char *p, *q;

    q = s;
    fp.ext = p = s + strlen(s);
    while (--p >= s) {
        if (*p == '.' && p > s && *fp.ext == '\0' &&
            p < fp.ext - 1 && !strchr(FILEPREFIX, p[-1]))
            fp.ext = p;
        else if (strchr(FILEPREFIX, *p)) {
            q = p+1;
            break;
        }
    }
    ssreserve(&buf, fp.ext - s + 2);
    fp.dir = buf.s;
    n = q - s;
    memcpy(fp.dir, s, n);
    fp.dir[n] = '\0';
    fp.name = buf.s + n + 1;
    n = fp.ext - q;
    memcpy(fp.name, q, n);
    fp.name[n] = '\0';

    return &fp;
}

/*
 * makename - make a file name, optionally substituting a new dir and/or ext.
 * 
 *  A pointer to a static buffer is returned.  NB: this buffer is the
 *  same as that returned by pathfind and findexe.
 */
char *makename(char *d, char *name, char *e)
{
    static struct staticstr buf = {128};
    struct fileparts *fp = fparse(name);
    if (d)
        fp->dir = d;
    if (e)
        fp->ext = e;
    ssreserve(&buf, strlen(fp->dir) + strlen(fp->name) + strlen(fp->ext) + 1);
    sprintf(buf.s, "%s%s%s", fp->dir, fp->name, fp->ext);
    return buf.s;
}

struct rangeset *init_rangeset()
{
    struct rangeset *rs = safe_malloc(sizeof(struct rangeset));
    rs->n_ranges = 0;
    rs->n_alloc = 8;
    rs->range = safe_malloc(rs->n_alloc * sizeof(struct range));
    rs->temp = safe_malloc(rs->n_alloc * sizeof(struct range));
    return rs;
}

void free_rangeset(struct rangeset *rs)
{
    free(rs->range);
    free(rs->temp);
    free(rs);
}

static int merge_range(struct range *r1, struct range *r2)
{
    if (r1->from < r2->from) {
        if (r1->to >= r2->from - 1) {
            if (r2->to > r1->to)
                r1->to = r2->to;
            return 1;
        }
    } else {
        if (r2->to >= r1->from - 1) {
            r1->from = r2->from;
            if (r2->to > r1->to)
                r1->to = r2->to;
            return 1;
        }
    }
    return 0;
}

static int ensure_rangeset_size(struct rangeset *rs, int n)
{
    if (rs->n_alloc >= n)
        return 1;
    n *= 2;
    rs->range = safe_realloc(rs->range, n * sizeof(struct range));
    rs->temp = safe_realloc(rs->temp, n * sizeof(struct range));
    rs->n_alloc = n;
    return 1;
}

/*
 * Search for a range which from..to touches.
 */
static int touches_range(struct rangeset *rs, int from, int to)
{
    int l, r, m;
    l = 0;
    r = rs->n_ranges - 1;
    while (l <= r) {
        m = (l + r) / 2;
        if (to < rs->range[m].from - 1)
            r = m - 1;
        else if (from > rs->range[m].to + 1)
            l = m + 1;
        else
            /* from <= rs->range[m].to + 1 && to >= rs->range[m].from - 1 */
            return m;
    }
    return -1;
}

void add_char(struct rangeset *rs, int ch)
{
    add_range(rs, ch, ch);
}

void add_range(struct rangeset *rs, int from, int to)
{
    word i, n;
    struct range new;
    struct range *t;
    if (from < 0 || from > MAX_CODE_POINT || to < 0 || to > MAX_CODE_POINT) {
        fprintf(stderr, "Tried to add invalid code point to range set\n");
        exit(EXIT_FAILURE);
    }
    if (from > to)
        return;

    /*
     * Easy case if we can just add the new range to the end.
     */
    if (rs->n_ranges == 0 || from > rs->range[rs->n_ranges - 1].to + 1) {
        ensure_rangeset_size(rs, 1 + rs->n_ranges);
        rs->range[rs->n_ranges].from = from;
        rs->range[rs->n_ranges].to = to;
        ++rs->n_ranges;
        return;
    }
    /*
     * See if we can expand the last range.  Just this and the above
     * case can handle csets built up from ranges with ascending from
     * values, which covers the four basic set operations in oset.r.
     */
    if (from >= rs->range[rs->n_ranges - 1].from) {
        if (to > rs->range[rs->n_ranges - 1].to)
            rs->range[rs->n_ranges - 1].to = to;
        return;
    }

    /*
     * Use binary search to see if a current range can be expanded to
     * accommodate the new range.  It must touch an existing range,
     * and also not touch the adjacent ranges.
     */
    n = touches_range(rs, from, to);
    if (n >= 0 &&
        (n == 0 || from > rs->range[n - 1].to + 1) &&
        (n == rs->n_ranges-1 || to < rs->range[n + 1].from - 1))
    {
        if (to > rs->range[n].to)
            rs->range[n].to = to;
        if (from < rs->range[n].from)
            rs->range[n].from = from;
        return;
    }
    
    /* Allocates room for rs->n_ranges + 1 ranges: it can grow by at most one range */
    ensure_rangeset_size(rs, 1 + rs->n_ranges);

    /* Merge the new range with existing ranges */
    n = 0;
    new.from = from;
    new.to = to;
    for (i = 0; i < rs->n_ranges; ++i) {
        if (!merge_range(&new, &rs->range[i])) {
            if (rs->range[i].from > new.from)
                break;
            rs->temp[n++] = rs->range[i];
        }
    }

    /* Add the new range and any remaining old ones */
    rs->temp[n++] = new;
    for (; i < rs->n_ranges; ++i)
        rs->temp[n++] = rs->range[i];

    /*
     * Set the new size and swap the range and temp arrays.
     */
    rs->n_ranges = n;
    t = rs->range;
    rs->range = rs->temp;
    rs->temp = t;
}

void print_rangeset(struct rangeset *rs)
{
    int i ;
    for (i = 0; i < rs->n_ranges; ++i)
        printf("%d   %ld - %ld\n", i, (long)rs->range[i].from, (long)rs->range[i].to);
}

/*
 * # Bits  Min val(hex)     Bit pattern
 * 1    7                   0xxxxxxx
 * 2   11     00000080      110xxxxx 10xxxxxx
 * 3   16     00000800      1110xxxx 10xxxxxx 10xxxxxx
 * 4   21     00010000      11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
 * 5   26     00200000      111110xx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
 * 6   31     04000000      1111110x 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx 10xxxxxx
 *
 */

#define ISCONT(b) (((b) & 0xc0) == 0x80)
#define NEXT(p) (*(*(unsigned char **)(p))++)

int utf8_check(char **p, char *end)
{
    int b1 = NEXT(p);
    switch ((b1 >> 4) & 0x0f) {
        case 0: case 1: case 2: case 3:
        case 4: case 5: case 6: case 7: {
            /* 1 byte, 7 bits: 0xxxxxxx */
            return b1 & 0x7f;
        }
        case 12: case 13: {
            int i, b2;
            /* 2 bytes, 11 bits: 110xxxxx 10xxxxxx */
            if (*p >= end)
                return -1;
            b2 = NEXT(p);
            if (!ISCONT(b2)) return -1;
            i = ((((b1 & 0x1f) << 6) |
                  ((b2 & 0x3f))));
            if (i < 0x80)
                return -1;
            return i;
        }
        case 14: {
            int i, b2, b3;
            /* 3 bytes, 16 bits: 1110xxxx 10xxxxxx 10xxxxxx */
            if (end - *p < 2)
                return -1;
            b2 = NEXT(p);
            if (!ISCONT(b2)) return -1;
            b3 = NEXT(p);
            if (!ISCONT(b3)) return -1;
            i = ((((b1 & 0x0f) << 12) |
                  ((b2 & 0x3f) << 06) |
                  ((b3 & 0x3f))));
            if (i < 0x800)
                return -1;
            return i;
        }
        case 15: {
            switch (b1 & 0x0f) {
                case 0: case 1: case 2: case 3:
                case 4: case 5: case 6: case 7: {
                    int i, b2, b3, b4;
                    /* 4 bytes, 21 bits */
                    if (end - *p < 3)
                        return -1;
                    b2 = NEXT(p);
                    if (!ISCONT(b2)) return -1;
                    b3 = NEXT(p);
                    if (!ISCONT(b3)) return -1;
                    b4 = NEXT(p);
                    if (!ISCONT(b4)) return -1;
                    i = (((b1 & 0x07) << 18) |
                         ((b2 & 0x3f) << 12) |
                         ((b3 & 0x3f) << 06) |
                         ((b4 & 0x3f)));
                    if (i < 0x10000)
                        return -1;
                    return i;
                }

                case 8: case 9: case 10: case 11: {
                    int i, b2, b3, b4, b5;
                    /* 5 bytes, 26 bits */
                    if (end - *p < 4)
                        return -1;
                    b2 = NEXT(p);
                    if (!ISCONT(b2)) return -1;
                    b3 = NEXT(p);
                    if (!ISCONT(b3)) return -1;
                    b4 = NEXT(p);
                    if (!ISCONT(b4)) return -1;
                    b5 = NEXT(p);
                    if (!ISCONT(b5)) return -1;
                    i = (((b1 & 0x03) << 24) |
                         ((b2 & 0x3f) << 18) |
                         ((b3 & 0x3f) << 12) |
                         ((b4 & 0x3f) << 06) |
                         ((b5 & 0x3f)));
                    if (i < 0x200000)
                        return -1;
                    return i;
                }

                case 12: case 13: {
                    int i, b2, b3, b4, b5, b6;
                    /* 6 bytes, 31 bits */
                    if (end - *p < 5)
                        return -1;
                    b2 = NEXT(p);
                    if (!ISCONT(b2)) return -1;
                    b3 = NEXT(p);
                    if (!ISCONT(b3)) return -1;
                    b4 = NEXT(p);
                    if (!ISCONT(b4)) return -1;
                    b5 = NEXT(p);
                    if (!ISCONT(b5)) return -1;
                    b6 = NEXT(p);
                    if (!ISCONT(b6)) return -1;
                    i = (((b1 & 0x01) << 30) |
                         ((b2 & 0x3f) << 24) |
                         ((b3 & 0x3f) << 18) |
                         ((b4 & 0x3f) << 12) |
                         ((b5 & 0x3f) << 06) |
                         ((b6 & 0x3f)));
                    if (i < 0x4000000)
                        return -1;
                    return i;
                }

                default:
                    return -1;
            }
        }
    }
    return -1;
}

int utf8_iter(char **p)
{
    int b1 = NEXT(p);
    switch ((b1 >> 4) & 0x0f) {
        case 0: case 1: case 2: case 3:
        case 4: case 5: case 6: case 7: {
            /* 1 byte, 7 bits: 0xxxxxxx */
            return b1 & 0x7f;
        }
        case 12: case 13: {
            int i, b2;
            /* 2 bytes, 11 bits: 110xxxxx 10xxxxxx */
            b2 = NEXT(p);
            i = ((((b1 & 0x1f) << 6) |
                  ((b2 & 0x3f))));
            return i;
        }
        case 14: {
            int i, b2, b3;
            /* 3 bytes, 16 bits: 1110xxxx 10xxxxxx 10xxxxxx */
            b2 = NEXT(p);
            b3 = NEXT(p);
            i = ((((b1 & 0x0f) << 12) |
                  ((b2 & 0x3f) << 06) |
                  ((b3 & 0x3f))));
            return i;
        }
        case 15: {
            switch (b1 & 0x0f) {
                case 0: case 1: case 2: case 3:
                case 4: case 5: case 6: case 7: {
                    int i, b2, b3, b4;
                    /* 4 bytes, 21 bits */
                    b2 = NEXT(p);
                    b3 = NEXT(p);
                    b4 = NEXT(p);
                    i = (((b1 & 0x07) << 18) |
                         ((b2 & 0x3f) << 12) |
                         ((b3 & 0x3f) << 06) |
                         ((b4 & 0x3f)));
                    return i;
                }

                case 8: case 9: case 10: case 11: {
                    int i, b2, b3, b4, b5;
                    /* 5 bytes, 26 bits */
                    b2 = NEXT(p);
                    b3 = NEXT(p);
                    b4 = NEXT(p);
                    b5 = NEXT(p);
                    i = (((b1 & 0x03) << 24) |
                         ((b2 & 0x3f) << 18) |
                         ((b3 & 0x3f) << 12) |
                         ((b4 & 0x3f) << 06) |
                         ((b5 & 0x3f)));
                    return i;
                }

                case 12: case 13: {
                    int i, b2, b3, b4, b5, b6;
                    /* 6 bytes, 31 bits */
                    b2 = NEXT(p);
                    b3 = NEXT(p);
                    b4 = NEXT(p);
                    b5 = NEXT(p);
                    b6 = NEXT(p);
                    i = (((b1 & 0x01) << 30) |
                         ((b2 & 0x3f) << 24) |
                         ((b3 & 0x3f) << 18) |
                         ((b4 & 0x3f) << 12) |
                         ((b5 & 0x3f) << 06) |
                         ((b6 & 0x3f)));
                    return i;
                }

                default:
                    return 0;
            }
        }
    }
    return 0;
}

int utf8_rev_iter(char **p)
{
    for (;;) {
        if (!ISCONT(*--(*p))) {
            char *t = *p;
            return utf8_iter(&t);
        }
    }
}

void utf8_rev_iter0(char **p)
{
    while (ISCONT(*--(*p)));
}

int utf8_seq(int c, char *s)
{
    if (c < 0x80) {
        if (s) s[0] = (char)c;
        return 1;
    }
    if (c < 0x800) {
        if (s) {
            s[0] = (char)(0xc0 | ((c >> 6)));
            s[1] = (char)(0x80 | (c & 0x3f));
        }
        return 2;
    }
    if (c < 0x10000) {
        if (s) {
            s[0] = (char)(0xe0 | ((c >> 12)));
            s[1] = (char)(0x80 | ((c >> 6) & 0x3f));
            s[2] = (char)(0x80 | (c & 0x3f));
        }
        return 3;
    }
    if (c < 0x200000) {
        if (s) {
            s[0] = (char)(0xf0 | ((c >> 18)));
            s[1] = (char)(0x80 | ((c >> 12) & 0x3f));
            s[2] = (char)(0x80 | ((c >> 6) & 0x3f));
            s[3] = (char)(0x80 | (c & 0x3f));
        }
        return 4;
    }
    if (c < 0x400000) {
        if (s) {
            s[0] = (char)(0xf8 | ((c >> 24)));
            s[1] = (char)(0x80 | ((c >> 18) & 0x3f));
            s[2] = (char)(0x80 | ((c >> 12) & 0x3f));
            s[3] = (char)(0x80 | ((c >> 6) & 0x3f));
            s[4] = (char)(0x80 | (c & 0x3f));
        }
        return 5;
    }

    if (s) {
        s[0] = (char)(0xfc | ((c >> 30)));
        s[1] = (char)(0x80 | ((c >> 24) & 0x3f));
        s[2] = (char)(0x80 | ((c >> 18) & 0x3f));
        s[3] = (char)(0x80 | ((c >> 12) & 0x3f));
        s[4] = (char)(0x80 | ((c >> 6) & 0x3f));
        s[5] = (char)(0x80 | (c & 0x3f));
    }
    return 6;
}

int 
utf8_seq_len_arr[] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        1,1,1,1,1,1,1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,
        -1,-1,-1,-1,-1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
        2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,
        5,5,5,5,6,6,-1,-1};

static word calc_ucs_offset_words(word n_offs, int offset_bits)
{
    int opw;
    opw = WordBits / offset_bits;
    if (n_offs % opw == 0)
        return n_offs / opw;
    else
        return 1 + n_offs / opw;
}

static word calc_ucs_index_step(word utf8_len, word len, int offset_bits)
{
    static unsigned char cache[257];
    word s, k;
    /* String is all ascii, including empty string; return 0 indicating not 
     * to use index */
    if (utf8_len == len)
        return 0;
    /* Single char non-ascii. */
    if (len == 1)
        return 1;
    if (offset_bits == 8 && len < ElemCount(cache) && cache[len] > 0)
        return cache[len];
    s = (word)(log(len) * UcsIndexStepFactor);
    if (s >= len)
        s = len;
    else {
        /* Make s as small as possible without altering the number of
         * words used by the index */
        k = calc_ucs_offset_words((len - 1) / s, offset_bits);
        while (s > 1 && calc_ucs_offset_words((len - 1) / (s - 1), offset_bits) == k)
            --s;
    }
    if (offset_bits == 8 && len < ElemCount(cache))
        cache[len] = (unsigned char)s;
    return s;
}

void calc_ucs_index_settings(word utf8_len, word len, word *index_step, word *n_offs, word *offset_bits, word *n_off_words)
{
    if (utf8_len <= 256)
        *offset_bits =  8;
    else if (utf8_len <= 65536)
        *offset_bits = 16;
#if WordBits == 32
    else
        *offset_bits = 32;
#else
    else if (utf8_len <= 0x100000000)
        *offset_bits = 32;
    else
        *offset_bits = 64;
#endif

    *index_step = calc_ucs_index_step(utf8_len, len, *offset_bits);
    if (*index_step == 0)
        *n_offs = 0;
    else
        *n_offs = (len - 1) / *index_step;

    *n_off_words = calc_ucs_offset_words(*n_offs, *offset_bits);
}

#if MSWIN32
int strcasecmp(char *s1, char *s2)
{
    int j;
    while (1) {
        j = oi_tolower(*s1) - oi_tolower(*s2);
        if (j) 
            return j;
        if (*s1 == '\0') 
            break;
        s1++; s2++;
    }
    return 0;
}

int strncasecmp(char *s1, char *s2, int n)
{
    int j;
    while (n--) {
        j = oi_tolower(*s1) - oi_tolower(*s2);
        if (j) 
            return j;
        if (*s1 == '\0') 
            break;
        s1++; s2++;
    }
    return 0;
}
#endif					/* MSWIN32 */

/*
 * Convert a double to a C string.  A pointer into a static buffer is returned.
 */
char *double2cstr(double n)
{
    static char result[64];
    char *p, *s = result;
    if (n == 0.0)                        /* ensure -0.0 (which == 0.0), prints as "0.0" */
        return "0.0";

    s++; 				/* leave room for leading zero */
    sprintf(s, "%.*g", Precision, n);

    /*
     * Now clean up possible messes.
     */
    while (*s == ' ')			/* delete leading blanks */
        s++;

    /*
     * Check for nan, infinity.
     */
    if (strchr(s, 'n') || strchr(s, 'N'))
        return s;
    if (*s == '.') {			/* prefix 0 to initial period */
        s--;
        *s = '0';
    }
    else if (!strchr(s, '.') && !strchr(s, 'e') && !strchr(s, 'E'))
        strcat(s, ".0");		/* if no decimal point or exp. */
    else if (s[strlen(s) - 1] == '.')		/* if decimal point is at end ... */
        strcat(s, "0");

    /* Convert e+0dd -> e+dd */
    if ((p = strchr(s, 'e')) && p[2] == '0' && 
        oi_isdigit(p[3]) && oi_isdigit(p[4]))
        strcpy(p + 2, p + 3);

    return s;
}

/*
 * Convert a word to a C string.  A pointer into a static buffer is returned.
 */
char *word2cstr(word n)
{
    static char result[32];
    sprintf(result, WordFmt, n);
    return result;
}

/*
 * Simple hash function for C strings.
 */
uword hashcstr(char *s)
{
    int j;
    uword h;
    h = 0;
    j = 10;   /* limit scan to first ten characters */
    while (*s && j-- > 0) {
        h = 13 * h + (*s & 0377);
        ++s;
    }
    return h;
}

/*
 * Get the hostname, returning a pointer to static data, or NULL on error.
 */
char *get_hostname()
{
    static struct staticstr buf = {64};
#if HAVE_UNAME
    struct utsname utsn;
    if (uname(&utsn) < 0)
        return 0;
    sscpy(&buf, utsn.nodename);
#else
    char result[256];
    if (gethostname(result, sizeof(result)) < 0)
        return 0;
    sscpy(&buf, result);
#endif
    return buf.s;
}

/*
 * Return a pointer to a static buffer giving a filepath which is the
 * filename fn in the system's temporary directory.
 */
char *maketemp(char *fn)
{
    static struct staticstr buf = {128};
#if MSWIN32
    WCHAR path[MAX_PATH + 100];
    char *tmp;
    path[0] = 0;
    GetTempPathW(ElemCount(path), path);
    tmp = wchar_to_utf8(path);
    ssreserve(&buf, strlen(tmp) + strlen(fn) + 1);
    sprintf(buf.s, "%s%s", tmp, fn);
    free(tmp);
#else
    char *tmp = getenv_nn("TEMP");
    if (tmp == 0)
        tmp = "/tmp";
    ssreserve(&buf, strlen(tmp) + 1 + strlen(fn) + 1);
    sprintf(buf.s, "%s%c%s", tmp, FILESEP, fn);
#endif
    return buf.s;
}

/*
 * Return a static buffer based on the system error string.
 */
char *get_system_error()
{
    static struct staticstr buf = {128};
#if MSWIN32
    char *msg;
    msg = wchar_to_utf8(_wcserror(errno));
    ssreserve(&buf, strlen(msg) + 32);
    sprintf(buf.s, "%s (errno=%d)", msg, errno);
    free(msg);
#else
    char *msg = 0;

    #if HAVE_STRERROR
       msg = strerror(errno);
    #elif HAVE_SYS_NERR && HAVE_SYS_ERRLIST
       if (errno > 0 && errno <= sys_nerr)
           msg = (char *)sys_errlist[errno];
    #endif
    if (!msg)
        msg = "Unknown system error";

    ssreserve(&buf, strlen(msg) + 32);
    sprintf(buf.s, "%s (errno=%d)", msg, errno);
#endif
    return buf.s;
}

/*
 * printf to a static buffer.
 */
char *buffprintf(char *fmt, ...)
{
    char *s;
    va_list ap;
    va_start(ap, fmt);
    s = buffvprintf(fmt, ap);
    va_end(ap);
    return s;
}

/*
 * vprintf to a static buffer.
 */
char *buffvprintf(char *fmt, va_list ap)
{
    static struct staticstr buf = {96};
    va_list ap1;
    int n;
    ssreserve(&buf, buf.smin);
    while (1) {
        va_copy(ap1, ap);
        n = vsnprintf(buf.s, buf.curr, fmt, ap1);
        va_end(ap1);
        if (n < 0) {
            buf.s[0] = 0;
            break;
        }
        if (n < buf.curr)
            break;
        ssreserve(&buf, n + 1);
    }
    return buf.s;
}

/*
 * salloc - allocate and initialize string
 */
char *salloc(char *s)
{
    char *s1;
    size_t n = strlen(s) + 1;
    s1 = safe_malloc(n);
    return memcpy(s1, s, n);
}

/*
 * Ensure n bytes are allocated in the given buffer.  The old value of
 * the buffer (if any) is lost.
 */
void ssreserve(struct staticstr *ss, size_t n)
{
    if (n > ss->curr) {
        ss->curr = n;
        free(ss->s);
        ss->s = safe_malloc(n);
    } else if (n < ss->curr) {
        if (ss->curr > ss->smin) {
            ss->curr = Max(n, ss->smin);
            ss->s = safe_realloc(ss->s, ss->curr);
        }
    }
    if (ss->s)
        *ss->s = 0;
}

/*
 * Ensure n bytes are allocated in the given buffer.  The old value of
 * the buffer remains.
 */
void ssexpand(struct staticstr *ss, size_t n)
{
    if (n > ss->curr) {
        ss->curr = n;
        ss->s = safe_realloc(ss->s, ss->curr);
    }
}

/*
 * Copy the given string into the buffer.
 */
char *sscpy(struct staticstr *ss, char *val)
{
    size_t n = strlen(val) + 1;
    ssreserve(ss, n);
    return memcpy(ss->s, val, n);
}

/*
 * Append the given string to the buffer, which must already contain a
 * valid string.
 */
char *sscat(struct staticstr *ss, char *val)
{
    size_t sn, vn;
    sn = strlen(ss->s);
    vn = strlen(val);
    ssexpand(ss, sn + vn + 1);
    memcpy(ss->s + sn, val, vn + 1);
    return ss->s;
}

/*
 * Show the state of the buffer.
 */
void ssdbg(struct staticstr *ss)
{
    fprintf(stderr, "ss=%p smin=%ld curr=%ld", ss, (long)ss->smin, (long)ss->curr);
    if (ss->s)
        fprintf(stderr, " s=%p('%s',%ld)\n", ss->s, ss->s, (long)strlen(ss->s));
    else
        fprintf(stderr, " s=nil\n");
}

/*
 * This is just like getenv(), but if the variable's value is the
 * empty string, null is returned.
 */
char *getenv_nn(char *name)
{
    char *s;
    s = getenv(name);
    if (s && *s)
        return s;
    else
        return 0;
}

unsigned char   oi_ctype[256] =
{
/*       0       1       2       3       4       5       6       7  */

/*  0*/ _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,
/* 10*/ _CC,     _CS|_CC,  _CS|_CC,  _CS|_CC,  _CS|_CC,  _CS|_CC,  _CC,     _CC,
/* 20*/ _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,
/* 30*/ _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,     _CC,
/* 40*/ _CS|_CB,  _CP,     _CP,     _CP,     _CP,     _CP,     _CP,     _CP,
/* 50*/ _CP,     _CP,     _CP,     _CP,     _CP,     _CP,     _CP,     _CP,
/* 60*/ _CN|_CX,  _CN|_CX,  _CN|_CX,  _CN|_CX,  _CN|_CX,  _CN|_CX,  _CN|_CX,  _CN|_CX,
/* 70*/ _CN|_CX,  _CN|_CX,  _CP,     _CP,     _CP,     _CP,     _CP,     _CP,
/*100*/ _CP,     _CU|_CX,  _CU|_CX,  _CU|_CX,  _CU|_CX,  _CU|_CX,  _CU|_CX,  _CU,
/*110*/ _CU,     _CU,     _CU,     _CU,     _CU,     _CU,     _CU,     _CU,
/*120*/ _CU,     _CU,     _CU,     _CU,     _CU,     _CU,     _CU,     _CU,
/*130*/ _CU,     _CU,     _CU,     _CP,     _CP,     _CP,     _CP,     _CP,
/*140*/ _CP,     _CL|_CX,  _CL|_CX,  _CL|_CX,  _CL|_CX,  _CL|_CX,  _CL|_CX,  _CL,
/*150*/ _CL,     _CL,     _CL,     _CL,     _CL,     _CL,     _CL,     _CL,
/*160*/ _CL,     _CL,     _CL,     _CL,     _CL,     _CL,     _CL,     _CL,
/*170*/ _CL,     _CL,     _CL,     _CP,     _CP,     _CP,     _CP,     _CC,
};

int oi_toupper(int c)
{

    if (c < 'a' || c > 'z')
        return c;
    return oi_mtoupper(c);
}

int oi_tolower(int c)
{
    if (c < 'A' || c > 'Z')
        return c;
    return oi_mtolower(c);
}

int over_flow = 0;

#ifndef AsmOver
/*
 * add, sub, mul, neg with overflow check
 * all return 1 if ok, 0 if would overflow
 */

/*
 *  Note: on some systems an improvement in performance can be obtained by
 *  replacing the C functions that follow by checks written in assembly
 *  language.  To do so, add #define AsmOver to ../h/define.h.  If your
 *  C compiler supports the asm directive, put the new code at the end
 *  of this section under control of #else.  Otherwise put it a separate
 *  file.
 */

word add(word a, word b)
{
   if ((a ^ b) >= 0 && (a >= 0 ? b > MaxWord - a : b < MinWord - a)) {
      over_flow = 1;
      return 0;
      }
   else {
     over_flow = 0;
     return a + b;
     }
}

word sub(word a, word b)
{
   if ((a ^ b) < 0 && (a >= 0 ? b < a - MaxWord : b > a - MinWord)) {
      over_flow = 1;
      return 0;
      }
   else {
      over_flow = 0;
      return a - b;
      }
}

word mul(word a, word b)
{
   if (b != 0) {
      if ((a ^ b) >= 0) {
	 if (a >= 0 ? a > MaxWord / b : a < MaxWord / b) {
            over_flow = 1;
	    return 0;
            }
	 }
      else if (b != -1 && (a >= 0 ? a > MinWord / b : a < MinWord / b)) {
         over_flow = 1;
	 return 0;
         }
      }

   over_flow = 0;
   return a * b;
}

/* MinWord / -1 overflows; need div3 too */

word mod3(word a, word b)
{
   word retval;

   switch ( b )
   {
      case 0:
	 over_flow = 1; /* Not really an overflow, but definitely an error */
	 return 0;

      case MinWord:
	 /* Handle this separately, since -MinWord can overflow */
	 retval = ( a > MinWord ) ? a : 0;
	 break;

      default:
	 /* First, we make b positive */
      	 if ( b < 0 ) b = -b;	

	 /* Make sure retval should have the same sign as 'a' */
	 retval = a % b;
	 if ( ( a < 0 ) && ( retval > 0 ) )
	    retval -= b;
	 break;
      }

   over_flow = 0;
   return retval;
}

word div3(word a, word b)
{
   if ( ( b == 0 ) ||	/* Not really an overflow, but definitely an error */
        ( b == -1 && a == MinWord ) ) {
      over_flow = 1;
      return 0;
      }

   over_flow = 0;
   return ( a - mod3 ( a, b ) ) / b;
}

/* MinWord / -1 overflows; need div3 too */

word neg(word a)
{
   if (a == MinWord) {
      over_flow = 1;
      return 0;
      }
   over_flow = 0;
   return -a;
}
#endif					/* AsmOver */

/*
 * Allocate with malloc, but pad beginning and end with an extra
 * unused 8 bytes.  This ensures that no other allocation will exactly
 * adjoin the (inner) region returned.
 */
void *padded_malloc(size_t size)
{
    char *p = malloc(size + 16);
    if (p)
        p += 8;
    return p;
}

/*
 * The following are simple wrappers around malloc and free which
 * cache allocations returned via small_free() for recycling by
 * future small_alloc() calls.  Only allocations of small sizes are
 * cached (< 1K on 64-bit, 512B on 32-bit); sizes larger than this
 * just use malloc/free as usual.
 */


/* Stats for dump output */
static uint64_t sa_total_req, sa_n_alloc, sa_too_big;

/*
 * The range of sizes contained in one row of the cache.  The values
 * don't have to be powers of 2, but it is faster if they are.
 */
#if WordBits == 64
#define Step 128
#elif WordBits == 32
#define Step 64
#endif

/*
 * Structure for one row of the cache.
 */
struct sa_row {
    void *cache[50];        /* Cache of pointers to previously malloced data */
    int n_cached;           /* Number in above array*/
    uint64_t n_alloc, n_free, alloc_hit, free_hit;      /* Stats for dump output */
};

/*
 * The cache itself has 8 rows.  At a step size of 128 bytes per row
 * this means allocs < 1KB are subject to being cached; at 64 bytes,
 * the limit is 512B.
 */
static struct sa_row sa_rows[8];

static const int sa_debug = 0;

static void sa_dump(void)
{
    static struct timeval tp1, tp2;
    gettimeofday(&tp1, 0);
    if (sa_n_alloc && tp1.tv_sec != tp2.tv_sec) {
        int i, n_cached;
        uint64_t n_alloc, n_free, alloc_hit, free_hit;

        tp2 = tp1;

        fprintf(stderr, "Avg req: %d   Too big: %ld/%ld (%d%%)\n",
                (int)(sa_total_req / sa_n_alloc), (long)sa_too_big, (long)sa_n_alloc, (int)((100*sa_too_big) / sa_n_alloc));

        n_cached = n_alloc = n_free = alloc_hit = free_hit = 0;
        for (i = 0; i < ElemCount(sa_rows); ++i) {
            struct sa_row *q = &sa_rows[i];
            fprintf(stderr, "\tRow: %d  (Allocs %d-%d) Cached: %d  Allocs: Hit: %ld/%ld (%d%%)   Frees: Hit: %ld/%ld (%d%%)\n",
                    i, i*Step, (i + 1)*Step - 1, q->n_cached, 
                    (long)q->alloc_hit, (long)q->n_alloc, q->n_alloc ? (int)((100*q->alloc_hit) / q->n_alloc) : 0,
                    (long)q->free_hit, (long)q->n_free, q->n_free ? (int)((100*q->free_hit) / q->n_free ) :0  );
            n_cached += q->n_cached;
            n_alloc += q->n_alloc;
            n_free += q->n_free;
            alloc_hit += q->alloc_hit;
            free_hit += q->free_hit;
        }
        fprintf(stderr, "\tTotals: Cached: %d  Allocs: Hit: %ld/%ld (%d%%)   Frees: Hit: %ld/%ld (%d%%)\n", n_cached, 
                (long)alloc_hit, (long)n_alloc, n_alloc ? (int)((100*alloc_hit) / n_alloc) : 0,
                (long)free_hit, (long)n_free, n_free ? (int)((100*free_hit) / n_free ) :0  );
    }
}

void *small_alloc(size_t size)
{
    char *p;
    int row;

    if (sa_debug) {
        sa_dump();
        sa_total_req += size;
        sa_n_alloc++;
    }

    row = size / Step;
    if (row >= ElemCount(sa_rows)) {
        /* Request too big. */
        if (sa_debug) sa_too_big++;
        row = -1;
    } else {
        if (sa_debug) ++sa_rows[row].n_alloc;

        if (sa_rows[row].n_cached > 0) {
            /* Return one from the cache. */
            if (sa_debug) ++sa_rows[row].alloc_hit;
            return sa_rows[row].cache[--sa_rows[row].n_cached];
        }

        /*
         * Round the requested size upwards.  Note that since
         *  row = size/Step, and
         *  Step*(size/Step) = size - r for some remainder r < Step,
         *           "       > size - Step, so
         *  Step * (row + 1) - 1 =
         *  Step*(size/Step) + Step - 1 > size - Step + Step - 1
         *              "               > size - 1
         *              "               >= size
         */
        size = Step * (row + 1) - 1;
    }

    /* Cache empty or too big, so use malloc. */
    p = malloc(size + 8);
    if (!p)
        return 0;
    /* Save the row (or -1 if it was too big). */
    *((int *)p) = row;
    return p + 8;
}

void small_free(void *p)
{
    int row;
    char *q = ((char *)p - 8);

    /* Retrieve hidden row number */
    row = *((int *)q);
    
    if (row >= 0) {
        if (sa_debug) ++sa_rows[row].n_free;
        if (sa_rows[row].n_cached < ElemCount(sa_rows[row].cache)) {
            /* Room in cache, so save for recycling and return. */
            if (sa_debug) ++sa_rows[row].free_hit;
            sa_rows[row].cache[sa_rows[row].n_cached++] = p;
            return;
        }
    }

    /*
     * No room in cache to save, or orig alloc was too big, so just
     * free 
     */
    free(q);
}

/*
 * Return true if the (null-terminated) string s has the icode
 * delimiter as an initial string, followed by \n.
 */
int match_delim(char *s)
{
    /*
     * Splitting the test into two parts avoids creating a string
     * constant of IcodeDelim followed by \n in oix (which we will
     * search through if it was bundled with -B, so we want to lessen
     * the chance of a false match).
     */
    return strncmp(s, IcodeDelim, sizeof(IcodeDelim) - 1) == 0 && s[sizeof(IcodeDelim) - 1] == '\n';
}

/*
 * Return true if this program is running on a little-endian
 * architecture, or false if it is big-endian.
 */
int is_little_endian()
{
    union {
        unsigned char c[4];
        uint32_t i;
    } u;
    u.i = 0x01020304;
    return (0x04 == u.c[0]);
}

struct hash_item {
    struct hash_item *next;
};

DefineHash(hash_proto, struct hash_item);

/*
 * Ensure a hash table is initialized, and if it is too crowded,
 * expand and recalculate the bucket lists.
 */
void ensure_hash(void *tbl0)
{
    struct hash_proto *tbl;
    struct hash_item **ipp, *ip;
    int i, h, old;

    tbl = tbl0;
    if (tbl->nbuckets == 0) {
        tbl->nbuckets = tbl->init;
        tbl->l = safe_zalloc(tbl->nbuckets * sizeof(struct dptr_list *));
    } else if (tbl->size >= 3 * tbl->nbuckets) {
        /* Expand the table */
        old = tbl->nbuckets;
        tbl->nbuckets *= 2;
        tbl->l = safe_realloc(tbl->l,
                              tbl->nbuckets * sizeof(struct dptr_list *));
        /* Clear the new entries */
        memset(&tbl->l[old], 0, (tbl->nbuckets - old) * sizeof(struct dptr_list *));
        /* Re-calculate the hash of all entries */
        for (i = 0; i < old; ++i) {
            ipp = &tbl->l[i];
            while ((ip = *ipp)) {
                h = tbl->hash(ip) % tbl->nbuckets;
                if (h == i)
                    /* Entry stays in this bucket */
                    ipp = &ip->next;
                else {
                    /* Move entry to a new bucket */
                    *ipp = ip->next;
                    ip->next = tbl->l[h];
                    tbl->l[h] = ip;
                }
            }
        }
    }
}

/*
 * Ensure the given hash table is initialized and if necessary
 * expanded, then insert the item using the already-calculated hash value.
 */
void add_to_hash_pre(void *tbl0, void *item0, uword h)
{
    struct hash_proto *tbl;
    struct hash_item *item;
    int i;
    ensure_hash(tbl0);
    tbl = tbl0;
    item = item0;
    i = h % tbl->nbuckets;
    item->next = tbl->l[i];
    tbl->l[i] = item;
    ++tbl->size;
}

/*
 * This just calls add_to_hash_pre() after calling the table's hash
 * function.
 */
void add_to_hash(void *tbl0, void *item0)
{
    struct hash_proto *tbl;
    struct hash_item *item;
    tbl = tbl0;
    item = item0;
    add_to_hash_pre(tbl, item, tbl->hash(item));
}

/*
 * Clear the hash bucket list, and set the size to 0.  The bucket list
 * is not freed.  It is the caller's responsibility to ensure the
 * individual list items are disposed of.
 */
void clear_hash(void *tbl0)
{
    struct hash_proto *tbl;
    tbl = tbl0;
    memset(tbl->l, 0, tbl->nbuckets * sizeof(struct hash_item *));
    tbl->size = 0;
}

/*
 * Free the bucket list memory, and reset the fields to their original
 * state.
 */
void free_hash(void *tbl0)
{
    struct hash_proto *tbl;
    tbl = tbl0;
    free(tbl->l);
    tbl->l = 0;
    tbl->size = tbl->nbuckets = 0;
}

/*
 * Check the given hash table for errors, and output some statistics
 * about it.
 */
void check_hash(void *tbl0)
{
    int h, i, l, ll, tl, sz, errs, mc;
    struct hash_proto *tbl;
    struct hash_item *ip;

    tbl = tbl0;
    printf("Hash table size=%d nbuckets=%d\n",
           tbl->size, tbl->nbuckets);
    mc = errs = sz = tl = ll = 0;
    for (i = 0; i < tbl->nbuckets; ++i) {
        l = 0;
        for (ip = tbl->l[i]; ip; ip = ip->next) {
            h = tbl->hash(ip) % tbl->nbuckets;
            if (h != i) {
                printf("\tHash wrong %d vs %d\n", h, i);
                ++errs;
            }
            ++l;
            ++sz;
        }
        if (l > ll) {
            ll = l;
            mc = 1;
        } else if (l == ll)
            ++mc;
        tl += l;
    }
    if (sz != tbl->size) {
        printf("\tSize wrong %d vs %d\n", sz, tbl->size);
        ++errs;
    }

    printf("\tMaximum length=%d (%d times) Average length=%3.1f Errors=%d\n",
           ll, mc, (tbl->nbuckets == 0) ? 0.0 : ((double)tl) / tbl->nbuckets, errs);
}

int oi_towupper(int c)
{
    if (c < 0x100)
    {
        if (c == 0x00b5)
            return 0x039c;
      
        if ((c >= 0x00e0 && c <= 0x00fe && c != 0x00f7) ||
            (c >= 0x0061 && c <= 0x007a))
            return (c - 0x20);
      
        if (c == 0xff)
            return 0x0178;
      
        return c;
    }
    else if (c < 0x300)
    {
        if ((c >= 0x0101 && c <= 0x012f) ||
            (c >= 0x0133 && c <= 0x0137) ||
            (c >= 0x014b && c <= 0x0177) ||
            (c >= 0x01df && c <= 0x01ef) ||
            (c >= 0x01f9 && c <= 0x021f) ||
            (c >= 0x0223 && c <= 0x0233) ||
            (c >= 0x0247 && c <= 0x024f))
	{
            if (c & 0x01)
                return (c - 1);
            return c;
	}

        if ((c >= 0x013a && c <= 0x0148) ||
            (c >= 0x01ce && c <= 0x01dc) ||
            c == 0x023c || c == 0x0242)
	{
            if (!(c & 0x01))
                return (c - 1);
            return c;
	}
      
        if (c == 0x0131)
            return 0x0049;
      
        if (c == 0x017a || c == 0x017c || c == 0x017e)
            return (c - 1);
      
        if (c >= 0x017f && c <= 0x0292)
	{
            int k;
            switch (c)
	    {
                case 0x017f:
                    k = 0x0053;
                    break;
                case 0x0180:
                    k = 0x0243;
                    break;
                case 0x0183:
                    k = 0x0182;
                    break;
                case 0x0185:
                    k = 0x0184;
                    break;
                case 0x0188:
                    k = 0x0187;
                    break;
                case 0x018c:
                    k = 0x018b;
                    break;
                case 0x0192:
                    k = 0x0191;
                    break;
                case 0x0195:
                    k = 0x01f6;
                    break;
                case 0x0199:
                    k = 0x0198;
                    break;
                case 0x019a:
                    k = 0x023d;
                    break;
                case 0x019e:
                    k = 0x0220;
                    break;
                case 0x01a1:
                case 0x01a3:
                case 0x01a5:
                case 0x01a8:
                case 0x01ad:
                case 0x01b0:
                case 0x01b4:
                case 0x01b6:
                case 0x01b9:
                case 0x01bd:
                case 0x01c5:
                case 0x01c8:
                case 0x01cb:
                case 0x01f2:
                case 0x01f5:
                    k = c - 1;
                    break;
                case 0x01bf:
                    k = 0x01f7;
                    break;
                case 0x01c6:
                case 0x01c9:
                case 0x01cc:
                    k = c - 2;
                    break;
                case 0x01dd:
                    k = 0x018e;
                    break;
                case 0x01f3:
                    k = 0x01f1;
                    break;
                case 0x023f:
                    k = 0x2c7e;
                    break;
                case 0x0240:
                    k = 0x2c7f;
                    break;
                case 0x0250:
                    k = 0x2c6f;
                    break;
                case 0x0251:
                    k = 0x2c6d;
                    break;
                case 0x0252:
                    k = 0x2c70;
                    break;
                case 0x0253:
                    k = 0x0181;
                    break;
                case 0x0254:
                    k = 0x0186;
                    break;
                case 0x0256:
                    k = 0x0189;
                    break;
                case 0x0257:
                    k = 0x018a;
                    break;
                case 0x0259:
                    k = 0x018f;
                    break;
                case 0x025b:
                    k = 0x0190;
                    break;
                case 0x0260:
                    k = 0x0193;
                    break;
                case 0x0263:
                    k = 0x0194;
                    break;
                case 0x0268:
                    k = 0x0197;
                    break;
                case 0x0269:
                    k = 0x0196;
                    break;
                case 0x026b:
                    k = 0x2c62;
                    break;
                case 0x026f:
                    k = 0x019c;
                    break;
                case 0x0271:
                    k = 0x2c6e;
                    break;
                case 0x0272:
                    k = 0x019d;
                    break;
                case 0x0275:
                    k = 0x019f;
                    break;
                case 0x027d:
                    k = 0x2c64;
                    break;
                case 0x0280:
                    k = 0x01a6;
                    break;
                case 0x0283:
                    k = 0x01a9;
                    break;
                case 0x0288:
                    k = 0x01ae;
                    break;
                case 0x0289:
                    k = 0x0244;
                    break;
                case 0x028a:
                    k = 0x01b1;
                    break;
                case 0x028b:
                    k = 0x01b2;
                    break;
                case 0x028c:
                    k = 0x0245;
                    break;
                case 0x0292:
                    k = 0x01b7;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
    }
    else if (c < 0x0400)
    {
        int k;

        if (c >= 0x03ad && c <= 0x03af)
            return (c - 0x25);

        if (c >= 0x03b1 && c <= 0x03cb && c != 0x03c2)
            return (c - 0x20);
      
        if (c >= 0x03d9 && c <= 0x03ef && (c & 1))
            return (c - 1);

        switch (c)
	{
            case 0x0345:
                k = 0x0399;
                break;
            case 0x0371:
            case 0x0373:
            case 0x0377:
            case 0x03f8:
            case 0x03fb:
                k = c - 1;
                break;
            case 0x037b:
            case 0x037c:
            case 0x037d:
                k = c + 0x82;
                break;
            case 0x03ac:
                k = 0x0386;
                break;
            case 0x03c2:
                k = 0x03a3;
                break;
            case 0x03cc:
                k = 0x038c;
                break;
            case 0x03cd:
            case 0x03ce:
                k = c - 0x3f;
                break;
            case 0x03d0:
                k = 0x0392;
                break;
            case 0x03d1:
                k = 0x0398;
                break;
            case 0x03d5:
                k = 0x03a6;
                break;
            case 0x03d6:
                k = 0x03a0;
                break;
            case 0x03d7:
                k = 0x03cf;
                break;
            case 0x03f0:
                k = 0x039a;
                break;
            case 0x03f1:
                k = 0x03a1;
                break;
            case 0x03f2:
                k = 0x03f9;
                break;
            case 0x03f5:
                k = 0x0395;
                break;
            default:
                k = 0;
	}
        if (k != 0)
            return k;
    }
    else if (c < 0x500)
    {
        if (c >= 0x0430 && c <= 0x044f)
            return (c - 0x20);
      
        if (c >= 0x0450 && c <= 0x045f)
            return (c - 0x50);
      
        if ((c >= 0x0461 && c <= 0x0481) ||
            (c >= 0x048b && c <= 0x04bf) ||
            (c >= 0x04d1 && c <= 0x04ff))
	{
            if (c & 0x01)
                return (c - 1);
            return c;
	}
      
        if (c >= 0x04c2 && c <= 0x04ce)
	{
            if (!(c & 0x01))
                return (c - 1);
            return c;
	}
      
        if (c == 0x04cf)
            return 0x04c0;

        if (c >= 0x04f7 && c <= 0x04f9)
            return (c - 1);
    }
    else if (c < 0x0600)
    {
        if (c >= 0x0501 && c <= 0x0525 && (c & 1))
            return c - 1;

        if (c >= 0x0561 && c <= 0x0586)
            return (c - 0x30);
    }
    else if (c < 0x1f00)
    {
        if (c == 0x1d79)
            return 0xa77d;

        if (c == 0x1d7d)
            return 0x2c63;

        if ((c >= 0x1e01 && c <= 0x1e95) ||
            (c >= 0x1ea1 && c <= 0x1eff))
	{
            if (c & 0x01)
                return (c - 1);
            return c;
	}
      
        if (c == 0x1e9b)
            return 0x1e60;
    }
    else if (c < 0x2000)
    {
      
        if ((c >= 0x1f00 && c <= 0x1f07) ||
            (c >= 0x1f10 && c <= 0x1f15) ||
            (c >= 0x1f20 && c <= 0x1f27) ||
            (c >= 0x1f30 && c <= 0x1f37) ||
            (c >= 0x1f40 && c <= 0x1f45) ||
            (c >= 0x1f60 && c <= 0x1f67) ||
            (c >= 0x1f80 && c <= 0x1f87) ||
            (c >= 0x1f90 && c <= 0x1f97) ||
            (c >= 0x1fa0 && c <= 0x1fa7))
            return (c + 0x08);

        if (c >= 0x1f51 && c <= 0x1f57 && (c & 0x01))
            return (c + 0x08);
      
        if (c >= 0x1f70 && c <= 0x1ff3)
	{
            int k;
            switch (c)
	    {
                case 0x1fb0:
                    k = 0x1fb8;
                    break;
                case 0x1fb1:
                    k = 0x1fb9;
                    break;
                case 0x1f70:
                    k = 0x1fba;
                    break;
                case 0x1f71:
                    k = 0x1fbb;
                    break;
                case 0x1fb3:
                    k = 0x1fbc;
                    break;
                case 0x1fbe:
                    k = 0x0399;
                    break;
                case 0x1f72:
                    k = 0x1fc8;
                    break;
                case 0x1f73:
                    k = 0x1fc9;
                    break;
                case 0x1f74:
                    k = 0x1fca;
                    break;
                case 0x1f75:
                    k = 0x1fcb;
                    break;
                case 0x1fc3:
                    k = 0x1fcc;
                    break;
                case 0x1fd0:
                    k = 0x1fd8;
                    break;
                case 0x1fd1:
                    k = 0x1fd9;
                    break;
                case 0x1f76:
                    k = 0x1fda;
                    break;
                case 0x1f77:
                    k = 0x1fdb;
                    break;
                case 0x1fe0:
                    k = 0x1fe8;
                    break;
                case 0x1fe1:
                    k = 0x1fe9;
                    break;
                case 0x1f7a:
                    k = 0x1fea;
                    break;
                case 0x1f7b:
                    k = 0x1feb;
                    break;
                case 0x1fe5:
                    k = 0x1fec;
                    break;
                case 0x1f78:
                    k = 0x1ff8;
                    break;
                case 0x1f79:
                    k = 0x1ff9;
                    break;
                case 0x1f7c:
                    k = 0x1ffa;
                    break;
                case 0x1f7d:
                    k = 0x1ffb;
                    break;
                case 0x1ff3:
                    k = 0x1ffc;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
    }
    else if (c < 0x3000)
    {
        if (c == 0x214e)
            return 0x2132;

        if (c == 0x2184)
            return 0x2183;

        if (c >= 0x2170 && c <= 0x217f)
            return (c - 0x10);
      
        if (c >= 0x24d0 && c <= 0x24e9)
            return (c - 0x1a);
      
        if (c >= 0x2c30 && c <= 0x2c5e)
            return (c - 0x30);

        if ((c >= 0x2c68 && c <= 0x2c6c && !(c & 1)) ||
            (c >= 0x2c81 && c <= 0x2ce3 &&  (c & 1)) ||
            c == 0x2c73 || c == 0x2c76 ||
            c == 0x2cec || c == 0x2cee)
            return (c - 1);

        if (c >= 0x2c81 && c <= 0x2ce3 && (c & 1))
            return (c - 1);

        if (c >= 0x2d00 && c <= 0x2d25)
            return (c - 0x1c60);

        switch (c)
      	{
            case 0x2c61:
                return 0x2c60;
            case 0x2c65:
                return 0x023a;
            case 0x2c66:
                return 0x023e;
	}
    }
    else if (c >= 0xa000 && c < 0xb000)
    {
        if (((c >= 0xa641 && c <= 0xa65f) ||
             (c >= 0xa663 && c <= 0xa66d) ||
             (c >= 0xa681 && c <= 0xa697) ||
             (c >= 0xa723 && c <= 0xa72f) ||
             (c >= 0xa733 && c <= 0xa76f) ||
             (c >= 0xa77f && c <= 0xa787)) &&
            (c & 1))
            return (c - 1);
      	
        if (c == 0xa77a || c == 0xa77c || c == 0xa78c)
            return (c - 1);
    }
    else
    {
        if (c >= 0xff41 && c <= 0xff5a)
            return (c - 0x20);
      
        if (c >= 0x10428 && c <= 0x1044f)
            return (c - 0x28);
    }
    return c;
}

int oi_towlower(int c)
{
    if (c < 0x100)
    {
        if ((c >= 0x0041 && c <= 0x005a) ||
            (c >= 0x00c0 && c <= 0x00d6) ||
            (c >= 0x00d8 && c <= 0x00de))
            return (c + 0x20);

        return c;
    }
    else if (c < 0x300)
    {
        if ((c >= 0x0100 && c <= 0x012e) ||
            (c >= 0x0132 && c <= 0x0136) ||
            (c >= 0x014a && c <= 0x0176) ||
            (c >= 0x01de && c <= 0x01ee) ||
            (c >= 0x01f8 && c <= 0x021e) ||
            (c >= 0x0222 && c <= 0x0232))
	{
            if (!(c & 0x01))
                return (c + 1);
            return c;
	}

        if (c == 0x0130)
            return 0x0069;

        if ((c >= 0x0139 && c <= 0x0147) ||
            (c >= 0x01cd && c <= 0x01db))
	{
            if (c & 0x01)
                return (c + 1);
            return c;
	}
      
        if (c >= 0x178 && c <= 0x01f7)
	{
            int k;
            switch (c)
	    {
                case 0x0178:
                    k = 0x00ff;
                    break;
                case 0x0179:
                case 0x017b:
                case 0x017d:
                case 0x0182:
                case 0x0184:
                case 0x0187:
                case 0x018b:
                case 0x0191:
                case 0x0198:
                case 0x01a0:
                case 0x01a2:
                case 0x01a4:
                case 0x01a7:
                case 0x01ac:
                case 0x01af:
                case 0x01b3:
                case 0x01b5:
                case 0x01b8:
                case 0x01bc:
                case 0x01c5:
                case 0x01c8:
                case 0x01cb:
                case 0x01cd:
                case 0x01cf:
                case 0x01d1:
                case 0x01d3:
                case 0x01d5:
                case 0x01d7:
                case 0x01d9:
                case 0x01db:
                case 0x01f2:
                case 0x01f4:
                    k = c + 1;
                    break;
                case 0x0181:
                    k = 0x0253;
                    break;
                case 0x0186:
                    k = 0x0254;
                    break;
                case 0x0189:
                    k = 0x0256;
                    break;
                case 0x018a:
                    k = 0x0257;
                    break;
                case 0x018e:
                    k = 0x01dd;
                    break;
                case 0x018f:
                    k = 0x0259;
                    break;
                case 0x0190:
                    k = 0x025b;
                    break;
                case 0x0193:
                    k = 0x0260;
                    break;
                case 0x0194:
                    k = 0x0263;
                    break;
                case 0x0196:
                    k = 0x0269;
                    break;
                case 0x0197:
                    k = 0x0268;
                    break;
                case 0x019c:
                    k = 0x026f;
                    break;
                case 0x019d:
                    k = 0x0272;
                    break;
                case 0x019f:
                    k = 0x0275;
                    break;
                case 0x01a6:
                    k = 0x0280;
                    break;
                case 0x01a9:
                    k = 0x0283;
                    break;
                case 0x01ae:
                    k = 0x0288;
                    break;
                case 0x01b1:
                    k = 0x028a;
                    break;
                case 0x01b2:
                    k = 0x028b;
                    break;
                case 0x01b7:
                    k = 0x0292;
                    break;
                case 0x01c4:
                case 0x01c7:
                case 0x01ca:
                case 0x01f1:
                    k = c + 2;
                    break;
                case 0x01f6:
                    k = 0x0195;
                    break;
                case 0x01f7:
                    k = 0x01bf;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
        else if (c == 0x0220)
            return 0x019e;
        else if (c >= 0x023a && c <= 0x024e)
      	{
            int k;
            switch (c)
	    {
                case 0x023a:
                    k = 0x2c65;
                    break;
                case 0x023b:
                case 0x0241:
                case 0x0246:
                case 0x0248:
                case 0x024a:
                case 0x024c:
                case 0x024e:
                    k = c + 1;
                    break;
                case 0x023d:
                    k = 0x019a;
                    break;
                case 0x023e:
                    k = 0x2c66;
                    break;
                case 0x0243:
                    k = 0x0180;
                    break;
                case 0x0244:
                    k = 0x0289;
                    break;
                case 0x0245:
                    k = 0x028c;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
    }
    else if (c < 0x0400)
    {
        if (c == 0x0370 || c == 0x0372 || c == 0x0376)
            return (c + 1);
        if (c >= 0x0391 && c <= 0x03ab && c != 0x03a2)
            return (c + 0x20);
        if (c >= 0x03d8 && c <= 0x03ee && !(c & 0x01))
            return (c + 1);
        if (c >= 0x0386 && c <= 0x03ff)
	{
            int k;
            switch (c)
	    {
                case 0x0386:
                    k = 0x03ac;
                    break;
                case 0x0388:
                    k = 0x03ad;
                    break;
                case 0x0389:
                    k = 0x03ae;
                    break;
                case 0x038a:
                    k = 0x03af;
                    break;
                case 0x038c:
                    k = 0x03cc;
                    break;
                case 0x038e:
                    k = 0x03cd;
                    break;
                case 0x038f:
                    k = 0x03ce;
                    break;
                case 0x03cf:
                    k = 0x03d7;
                    break;
                case 0x03f4:
                    k = 0x03b8;
                    break;
                case 0x03f7:
                    k = 0x03f8;
                    break;
                case 0x03f9:
                    k = 0x03f2;
                    break;
                case 0x03fa:
                    k = 0x03fb;
                    break;
                case 0x03fd:
                    k = 0x037b;
                    break;
                case 0x03fe:
                    k = 0x037c;
                    break;
                case 0x03ff:
                    k = 0x037d;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
    }
    else if (c < 0x500)
    {
        if (c >= 0x0400 && c <= 0x040f)
            return (c + 0x50);
      
        if (c >= 0x0410 && c <= 0x042f)
            return (c + 0x20);
      
        if ((c >= 0x0460 && c <= 0x0480) ||
            (c >= 0x048a && c <= 0x04be) ||
            (c >= 0x04d0 && c <= 0x04fe))
	{
            if (!(c & 0x01))
                return (c + 1);
            return c;
	}
      
        if (c == 0x04c0)
            return 0x04cf;

        if (c >= 0x04c1 && c <= 0x04cd)
	{
            if (c & 0x01)
                return (c + 1);
            return c;
	}
    }
    else if (c < 0x1f00)
    {
        if ((c >= 0x0500 && c <= 0x050e) ||
            (c >= 0x0510 && c <= 0x0524) ||
            (c >= 0x1e00 && c <= 0x1e94) ||
            (c >= 0x1ea0 && c <= 0x1ef8))
	{
            if (!(c & 0x01))
                return (c + 1);
            return c;
	}
      
        if (c >= 0x0531 && c <= 0x0556)
            return (c + 0x30);

        if (c >= 0x10a0 && c <= 0x10c5)
            return (c + 0x1c60);

        if (c == 0x1e9e)
            return 0x00df;

        if (c >= 0x1efa && c <= 0x1efe && !(c & 0x01))
            return (c + 1);
    }
    else if (c < 0x2000)
    {
        if ((c >= 0x1f08 && c <= 0x1f0f) ||
            (c >= 0x1f18 && c <= 0x1f1d) ||
            (c >= 0x1f28 && c <= 0x1f2f) ||
            (c >= 0x1f38 && c <= 0x1f3f) ||
            (c >= 0x1f48 && c <= 0x1f4d) ||
            (c >= 0x1f68 && c <= 0x1f6f) ||
            (c >= 0x1f88 && c <= 0x1f8f) ||
            (c >= 0x1f98 && c <= 0x1f9f) ||
            (c >= 0x1fa8 && c <= 0x1faf))
            return (c - 0x08);

        if (c >= 0x1f59 && c <= 0x1f5f)
	{
            if (c & 0x01)
                return (c - 0x08);
            return c;
	}
    
        if (c >= 0x1fb8 && c <= 0x1ffc)
	{
            int k;
            switch (c)
	    {
                case 0x1fb8:
                case 0x1fb9:
                case 0x1fd8:
                case 0x1fd9:
                case 0x1fe8:
                case 0x1fe9:
                    k = c - 0x08;
                    break;
                case 0x1fba:
                case 0x1fbb:
                    k = c - 0x4a;
                    break;
                case 0x1fbc:
                    k = 0x1fb3;
                    break;
                case 0x1fc8:
                case 0x1fc9:
                case 0x1fca:
                case 0x1fcb:
                    k = c - 0x56;
                    break;
                case 0x1fcc:
                    k = 0x1fc3;
                    break;
                case 0x1fda:
                case 0x1fdb:
                    k = c - 0x64;
                    break;
                case 0x1fea:
                case 0x1feb:
                    k = c - 0x70;
                    break;
                case 0x1fec:
                    k = 0x1fe5;
                    break;
                case 0x1ff8:
                case 0x1ff9:
                    k = c - 0x80;
                    break;
                case 0x1ffa:
                case 0x1ffb:
                    k = c - 0x7e;
                    break;
                case 0x1ffc:
                    k = 0x1ff3;
                    break;
                default:
                    k = 0;
	    }
            if (k != 0)
                return k;
	}
    }
    else if (c < 0x2c00)
    {
        if (c >= 0x2160 && c <= 0x216f)
            return (c + 0x10);

        if (c >= 0x24b6 && c <= 0x24cf)
            return (c + 0x1a);
      
        switch (c)
      	{
            case 0x2126:
                return 0x03c9;
            case 0x212a:
                return 0x006b;
            case 0x212b:
                return 0x00e5;
            case 0x2132:
                return 0x214e;
            case 0x2183:
                return 0x2184;
	}
    }
    else if (c < 0x2d00)
    {
        if (c >= 0x2c00 && c <= 0x2c2e)
            return (c + 0x30);

        if (c >= 0x2c80 && c <= 0x2ce2 && !(c & 0x01))
            return (c + 1);

        switch (c)
      	{
            case 0x2c60:
                return 0x2c61;
            case 0x2c62:
                return 0x026b;
            case 0x2c63:
                return 0x1d7d;
            case 0x2c64:
                return 0x027d;
            case 0x2c67:
            case 0x2c69:
            case 0x2c6b:
            case 0x2c72:
            case 0x2c75:
            case 0x2ceb:
            case 0x2ced:
                return c + 1;
            case 0x2c6d:
                return 0x0251;
            case 0x2c6e:
                return 0x0271;
            case 0x2c6f:
                return 0x0250;
            case 0x2c70:
                return 0x0252;
            case 0x2c7e:
                return 0x023f;
            case 0x2c7f:
                return 0x0240;
	}
    }
    else if (c >= 0xa600 && c < 0xa800)
    {
        if ((c >= 0xa640 && c <= 0xa65e) ||
            (c >= 0xa662 && c <= 0xa66c) ||
            (c >= 0xa680 && c <= 0xa696) ||
            (c >= 0xa722 && c <= 0xa72e) ||
            (c >= 0xa732 && c <= 0xa76e) ||
            (c >= 0xa77f && c <= 0xa786))
	{
            if (!(c & 1))
                return (c + 1);
            return c;
	}

        switch (c)
      	{
            case 0xa779:
            case 0xa77b:
            case 0xa77e:
            case 0xa78b:
                return (c + 1);
            case 0xa77d:
                return 0x1d79;
	}
    }
    else
    {
        if (c >= 0xff21 && c <= 0xff3a)
            return (c + 0x20);
      
        if (c >= 0x10400 && c <= 0x10427)
            return (c + 0x28);
    }
    return c;
}
