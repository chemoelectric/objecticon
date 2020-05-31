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
    char *t = oihomewalk("bin", 0);
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
        int l = strlen(cwd);
        ssreserve(&buf, l + 1 + strlen(path) + 1);
        strcpy(buf.s, cwd);
        if (!strchr(FILEPREFIX, buf.s[l - 1]))
            buf.s[l++] = FILESEP;
        strcpy(&buf.s[l], path);
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
    char *r = strrchr(s, '.');
    if (!r)
        r = s + strlen(s);
    return r;
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
        if (*p == '.' && *fp.ext == '\0')
            fp.ext = p;
        else if (strchr(FILEPREFIX,*p)) {
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
 * Does the rangeset have a range which includes the given from-to.
 */
static int has_range(struct rangeset *rs, int from, int to)
{
    int l, r, m;
    l = 0;
    r = rs->n_ranges - 1;
    while (l <= r) {
        m = (l + r) / 2;
        if (from < rs->range[m].from)
            r = m - 1;
        else if (from > rs->range[m].to)
            l = m + 1;
        else  /* from >= rs->range[m].from && from <= rs->range[m].to */
            return to <= rs->range[m].to;
    }
    return 0;
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
     * Use binary search to see if this range is already contained within
     * an existing range; if so no need to do anything.
     */
    if (has_range(rs, from, to))
        return;

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
unsigned int hashcstr(char *s)
{
    unsigned int h;
    h = 0;
    while (*s) {
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
    s1 = safe_malloc(strlen(s) + 1);
    return strcpy(s1, s);
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
    ssreserve(ss, strlen(val) + 1);
    return strcpy(ss->s, val);
}

/*
 * Append the given string to the buffer, which must already contain a
 * valid string.
 */
char *sscat(struct staticstr *ss, char *val)
{
    ssexpand(ss, strlen(ss->s) + strlen(val) + 1);
    return strcat(ss->s, val);
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
 * cached (< 1K on 64-bit, 512KB on 32-bit); sizes larger than this
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
 * the limit is 512KB.
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

