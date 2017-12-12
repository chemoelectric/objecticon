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
 *  relfile(prog, mod) -- find related file.
 *
 *  Given that prog is the argv[0] by which this program was executed,
 *  and assuming that it was set by the shell or other equally correct
 *  invoker, relfile finds the location of a related file and returns
 *  it in an allocated string.  It takes the location of prog, appends
 *  mod, and normalizes the result; thus if argv[0] is icont or its path,
 *  relfile(argv[0],"/../iconx") finds the location of iconx.
 * 
 *  A pointer to a static buffer is returned.
 */
char *relfile(char *prog, char *mod) 
{
    static struct staticstr buf = {128};
    char *t = findexe(prog);
    if (!t) {
        fprintf(stderr, "cannot find location of %s\n", prog);
        exit(EXIT_FAILURE);
    }
    ssreserve(&buf, strlen(t) + strlen(mod) + 1);
    sprintf(buf.s, "%s%s", t, mod);     /* append adjustment */
    normalize(buf.s);                       /* normalize result */
    return buf.s;
}

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

#if PLAN9
    path = getenv_nn("path");
    if (!path)
        path = ". /bin";
#elif MSWIN32
    /* On windows, the cd is always on the path. */    
    if ((p = tryexe(0, name)))
        return p;
#else
    path = getenv_nn("PATH");
    if (!path)
        path = "";
#endif

    for (;;) {
        char *e = pathelem(&path);
        if (!e)
            break;
        if ((p = tryexe(e, name)))        /* look for file */
            return p;
    }

    return 0;
}


#if UNIX || PLAN9

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

#if UNIX
int is_flowterm_tty(FILE *f)
{
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
}
#endif

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
            *p = tolower((unsigned char)*p);
    }
    if (isalpha((unsigned char)file[0]) && file[1]==':') 
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
    return isalpha((unsigned char)*s) && s[1] == ':' && (s[2] == '\\' || s[2] == '/');
}

/*
 * Check if a file exists as an exe.
 */
static char *tryexe(char *dir, char *name)
{
    char *s = makename(dir, name, 0);
    struct fileparts *fp;

    /*
     * Try as given
     */
    if (!access(s, 0))
        return s;

    /*
     * If name has no extension, try extensions .exe and .bat
     * as alternatives.
     */
    fp = fparse(name);
    if (!*fp->ext) {
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
#if MSWIN32
            if (getcwd_utf8(buf, len))
#else
            if (getcwd(buf, len))
#endif
                break;
#if PLAN9
            {
                char buf[ERRMAX];
                rerrstr(buf, sizeof(buf));
                if (strcmp(buf, "buffer too short") != 0) {
                    fprintf(stderr, "unable to getcwd() (%s)", buf);
                    exit(EXIT_FAILURE);
                }
            }
#else
            if (errno != ERANGE) {
                fprintf(stderr, "unable to getcwd() (errno=%d)", errno);
                exit(EXIT_FAILURE);
            }
#endif
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
 *  cd is the current directory; may be NULL, meaning the "real" cd
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
        if (!cd)
            return tryfile(0, name, extn);
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
#if PLAN9
    Dir *d1, *d2;
    int res;
    d1 = dirstat(f1);
    if (!d1)
        return 1;
    d2 = dirstat(f2);
    if (!d2) {
        free(d1);
        return 1;
    }
    res = (d1->mtime > d2->mtime);
    free(d1);
    free(d2);
    return res;
#else
    time_t t1;
    static struct stat buf;
    if (stat(f1, &buf) < 0)
        return 1;
    t1 = buf.st_mtime;
    if (stat(f2, &buf) < 0)
        return 1;
    return t1 > buf.st_mtime;
#endif
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
    int i, n;
    struct range new;
    struct range *t;
    if (from < 0 || from > MAX_CODE_POINT || to < 0 || to > MAX_CODE_POINT) {
        fprintf(stderr, "tried to add invalid code point to range set\n");
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

int utf8_check(char **p, char *end)
{
    int b1 = (unsigned int)*(*p)++;
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
            b2 = (unsigned int)*(*p)++;
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
            b2 = (unsigned int)*(*p)++;
            if (!ISCONT(b2)) return -1;
            b3 = (unsigned int)*(*p)++;
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
                    b2 = (unsigned int)*(*p)++;
                    if (!ISCONT(b2)) return -1;
                    b3 = (unsigned int)*(*p)++;
                    if (!ISCONT(b3)) return -1;
                    b4 = (unsigned int)*(*p)++;
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
                    b2 = (unsigned int)*(*p)++;
                    if (!ISCONT(b2)) return -1;
                    b3 = (unsigned int)*(*p)++;
                    if (!ISCONT(b3)) return -1;
                    b4 = (unsigned int)*(*p)++;
                    if (!ISCONT(b4)) return -1;
                    b5 = (unsigned int)*(*p)++;
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
                    b2 = (unsigned int)*(*p)++;
                    if (!ISCONT(b2)) return -1;
                    b3 = (unsigned int)*(*p)++;
                    if (!ISCONT(b3)) return -1;
                    b4 = (unsigned int)*(*p)++;
                    if (!ISCONT(b4)) return -1;
                    b5 = (unsigned int)*(*p)++;
                    if (!ISCONT(b5)) return -1;
                    b6 = (unsigned int)*(*p)++;
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
    int b1 = (unsigned int)*(*p)++;
    switch ((b1 >> 4) & 0x0f) {
        case 0: case 1: case 2: case 3:
        case 4: case 5: case 6: case 7: {
            /* 1 byte, 7 bits: 0xxxxxxx */
            return b1 & 0x7f;
        }
        case 12: case 13: {
            int i, b2;
            /* 2 bytes, 11 bits: 110xxxxx 10xxxxxx */
            b2 = (unsigned int)*(*p)++;
            i = ((((b1 & 0x1f) << 6) |
                  ((b2 & 0x3f))));
            return i;
        }
        case 14: {
            int i, b2, b3;
            /* 3 bytes, 16 bits: 1110xxxx 10xxxxxx 10xxxxxx */
            b2 = (unsigned int)*(*p)++;
            b3 = (unsigned int)*(*p)++;
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
                    b2 = (unsigned int)*(*p)++;
                    b3 = (unsigned int)*(*p)++;
                    b4 = (unsigned int)*(*p)++;
                    i = (((b1 & 0x07) << 18) |
                         ((b2 & 0x3f) << 12) |
                         ((b3 & 0x3f) << 06) |
                         ((b4 & 0x3f)));
                    return i;
                }

                case 8: case 9: case 10: case 11: {
                    int i, b2, b3, b4, b5;
                    /* 5 bytes, 26 bits */
                    b2 = (unsigned int)*(*p)++;
                    b3 = (unsigned int)*(*p)++;
                    b4 = (unsigned int)*(*p)++;
                    b5 = (unsigned int)*(*p)++;
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
                    b2 = (unsigned int)*(*p)++;
                    b3 = (unsigned int)*(*p)++;
                    b4 = (unsigned int)*(*p)++;
                    b5 = (unsigned int)*(*p)++;
                    b6 = (unsigned int)*(*p)++;
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

#if MSWIN32 || PLAN9
int strcasecmp(char *s1, char *s2)
{
    int j;
    while (1) {
        j = tolower((unsigned char)*s1) - tolower((unsigned char)*s2);
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
        j = tolower((unsigned char)*s1) - tolower((unsigned char)*s2);
        if (j) 
            return j;
        if (*s1 == '\0') 
            break;
        s1++; s2++;
    }
    return 0;
}
#endif

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
    if (*s == '.') {			/* prefix 0 to initial period */
        s--;
        *s = '0';
    }
    else if (!strchr(s, '.') && !strchr(s, 'e') && !strchr(s, 'E'))
        strcat(s, ".0");		/* if no decimal point or exp. */
    if (s[strlen(s) - 1] == '.')		/* if decimal point is at end ... */
        strcat(s, "0");

    /* Convert e+0dd -> e+dd */
    if ((p = strchr(s, 'e')) && p[2] == '0' && 
        isdigit((unsigned char)p[3]) && isdigit((unsigned char)p[4]))
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
    WCHAR path[MaxPath];
    char *tmp;
    GetTempPathW(ElemCount(path), path);
    tmp = wchar_to_utf8(path);
    ssreserve(&buf, strlen(tmp) + strlen(fn) + 1);
    sprintf(buf.s, "%s%s", tmp, fn);
    free(tmp);
#elif PLAN9
    ssreserve(&buf, strlen(fn) + 5 + 1);
    sprint(buf.s, "/tmp/%s", fn);
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
#if PLAN9
    char tmp[ERRMAX + 1024];
    rerrstr(tmp, sizeof(tmp));
    sscpy(&buf, tmp);
#elif MSWIN32
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
        if (n < buf.curr - 1)
            break;
        ssreserve(&buf, 2 * buf.curr);
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
