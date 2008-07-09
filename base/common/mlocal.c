/*
 * mlocal.c - special platform specific code
 */
#include "../h/gsupport.h"

/*
 * The following code is operating-system dependent [@filepart.01].
 *
 *  Define symbols for building file names.
 *  1. PREFIX: the characters that terminate a file name prefix
 *  2. FILESEP: the char to insert after a dir name, if any
 *  3. IPATHSEP: allowable OIPATH/OLPATH separators,
 *  4. XPATHSEP: separator for executable PATH variable
 */

#if UNIX
#define FILESEP '/'
#define PREFIX "/"
#define IPATHSEP " :"
#define XPATHSEP ":"
#endif
#if MSDOS
#define FILESEP '\\'
#define PREFIX "/:\\"
#define IPATHSEP " "
#define XPATHSEP ";"
#endif

static char *tryfile(char *dir, char *name, char *extn);

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
    char *t = findexe(prog);
    if (!t) {
        fprintf(stderr, "cannot find location of %s\n", prog);
        exit(EXIT_FAILURE);
    }
    strcat(t, mod);                     /* append adjustment */
    normalize(t);                       /* normalize result */
    return t;
}

/*
 *  findexe(prog) -- find absolute executable path, given argv[0]
 *
 *  Finds the absolute path to prog, assuming that prog is the value passed
 *  by the shell in argv[0].
 * 
 *  A pointer to a static buffer is returned, or NULL in case of error.
 */

char *findexe(char *name) 
{
    char *s;

    /* if name does not contain a slash, search $PATH for file */
    if ((strchr(name, '/') != NULL)
#if MSDOS
        || (strchr(name, '\\') != NULL)
#endif
        )
        return canonicalize(name);
    else {
        s = findonpath(name);
        if (s)
            return canonicalize(s);
        else
            return canonicalize(name);
    }
}

/*
 *  findonpath(name) -- find name on $PATH
 *
 *  Searches $PATH (using POSIX 1003.2 rules) for executable name,
 *
 *  A pointer to a static buffer is returned, or NULL if not found.
 */
char *findonpath(char *name) 
{
    int nlen, plen;
    char *path, *next, *sep, *end;
    static char buf[MaxPath];

    nlen = strlen(name);
    path = getenv("PATH");
    if (path == NULL || *path == '\0')
        path = ".";
    end = path + strlen(path);
    for (next = path; next <= end; next = sep + 1) {
        sep = next;
        while (*sep && !strchr(XPATHSEP, *sep))
            ++sep;
        plen = sep - next;
        if (plen == 0) {
            next = ".";
            plen = 1;
        }
        if (plen + 1 + nlen + 1 >= sizeof(buf)) {
            *buf = '\0';
            return 0;
        }
        memcpy(buf, next, plen);
        buf[plen] = FILESEP;
        strcpy(buf + plen + 1, name);
#if NT && !defined(NTGCC)
/* under visual C++, just check whether the file exists */
#define access _access
#define X_OK 00
#endif
        if (access(buf, X_OK) == 0)
            return buf;
#if MSDOS
        strcat(buf, ".exe");
        if (access(buf, X_OK) == 0)
            return buf;
#endif
    }
    *buf = '\0';
    return 0;
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
 * Canonicalize a path by making it an absolute path if it isn't one
 * already, and then normalizing the result.  A pointer to a static
 * buffer is returned.
 */
char *canonicalize(char *path)
{
    static char result[MaxPath];
    static char currentdir[MaxPath];
    if (path[0] == '/') {
        if (snprintf(result, sizeof(result), "%s", path) >= sizeof(result)) {
            fprintf(stderr, "path too long to canonicalize: %s", path);
            exit(1);
        }
    } else {
        if (!getcwd(currentdir, sizeof(currentdir))) {
            fprintf(stderr, "getcwd return 0 - current working dir too long.");
            exit(1);
        }
        if (snprintf(result, sizeof(result), "%s/%s", currentdir, path) >= sizeof(result)) {
            fprintf(stderr, "path too long to canonicalize: %s", path);
            exit(1);
        }
    }
    normalize(result);
    return result;
}
#endif

#if MSDOS

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
            *p = tolower(*p);
    }
    if (isalpha(file[0]) && file[1]==':') 
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
 * Canonicalize a path by making it an absolute path if it isn't one
 * already, and then normalizing the result.  A pointer to a static
 * buffer is returned.
 */
char *canonicalize(char *path)
{
    static char result[MaxPath];
    static char currentdir[MaxPath];
    if (path[0] == '\\' || path[0] == '/' ||
        (isalpha(path[0]) && path[1] == ':')) {
        if (snprintf(result, sizeof(result), "%s", path) >= sizeof(result)) {
            fprintf(stderr, "path too long to canonicalize: %s", path);
            exit(1);
        }
    } else {
        if (!getcwd(currentdir, sizeof(currentdir))) {
            fprintf(stderr, "getcwd return 0 - current working dir too long.");
            exit(1);
        }
        if (snprintf(result, sizeof(result), "%s\\%s", currentdir, path) >= sizeof(result)) {
            fprintf(stderr, "path too long to canonicalize: %s", path);
            exit(1);
        }
    }
    normalize(result);
    return result;
}

#endif


FILE *pathopen(char *fname, char *mode)
{
    char *s = findexe(fname);
    if (s) 
        return fopen(s, mode);
    return 0;
}


void quotestrcat(char *buf, char *s)
{
    if (strchr(s, ' ')) strcat(buf, "\"");
    strcat(buf, s);
    if (strchr(s, ' ')) strcat(buf, "\"");
}


/*
 * pathfind(buf,path,name,extn) -- find file in path and return name.
 *
 *  pathfind looks for a file on a path, begining with the current
 *  directory.  Details vary by platform, but the general idea is
 *  that the file must be a readable simple text file.
 *
 *  A pointer to a makename's static buffer is returned, or NULL if
 *  not found.
 * 
 *  path is the IPATH or LPATH value, or NULL if unset.
 *  name is the file name.
 *  extn is the file extension (.icn or .u) to be appended, or NULL if none.
 */
char *pathfind(char *path, char *name, char *extn)
{
    char *p;

    if ((p = tryfile(0, name, extn)))     /* try curr directory first */
        return p;

    /* Don't search the path if we have an absolute path */
    if (isabsolute(name))
        return 0;

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
 * Is a file path absolute?
 */
int isabsolute(char *s)
{
#if UNIX
    return *s == '/';
#endif

#if MSDOS || OS2
    return isalpha(*s) && s[1] == ':' && (s[2] == '\\' || s[2] == '/');
#endif

#if PORT
Deliberate Syntax Error
#endif
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
    static char buf[MaxPath];
    char c, *s = *ps, *b = buf;

    while ((c = *s) != '\0' && strchr(IPATHSEP, c))
        s++;
    if (!*s) {
        *ps = 0;
        return 0;
    }

    if (*s == '"') {
        s++;
        while ((c = *s) != '\0' && (c != '"')) {
            *b++ = c;
            s++;
        }
        s++;
    }
    else {
        while ((c = *s) != '\0' && !strchr(IPATHSEP, c)) {
            *b++ = c;
            s++;
        }
    }

    /*
     * We have to append a path separator here.
     *  Seems like makename should really be the one to do that.
     */
    if (!strchr(PREFIX, b[-1])) {       /* if separator not already there */
        *b++ = FILESEP;
    }

    *b = 0;
    *ps = s;
    return buf;
}

/*
 * Find the last path element in a path string, eg /abc/def/file.txt -> file.txt
 */
char *last_pathelem(char *s)
{
    char *p = strrchr(s, FILESEP);
    if (!p)
        return s;
    else
        return p + 1;
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
 * tryfile(dir, name, extn) -- check to see if file is readable.
 *
 *  The file name is constructed in from dir + name + extn.  findfile
 *  returns makename's static buf if successful or NULL if not.
 */
static char *tryfile(char *dir, char *name, char *extn)
{
    FILE *f;
    char *p = makename(dir, name, extn);
    if ((f = fopen(p, ReadText)) != NULL) {
        fclose(f);
        return p;
    }
    else
        return 0;
}

/*
 * fparse - break a file name down into component parts.
 * Result is a pointer to a struct of static pointers good until the next call.
 */
struct fileparts *fparse(char *s)
{
    static char buf[MaxPath];
    static struct fileparts fp;
    int n;
    char *p, *q;

    q = s;
    fp.ext = p = s + strlen(s);
    while (--p >= s) {
        if (*p == '.' && *fp.ext == '\0')
            fp.ext = p;
        else if (strchr(PREFIX,*p)) {
            q = p+1;
            break;
        }
    }

    fp.dir = buf;
    n = q - s;
    strncpy(fp.dir,s,n);
    fp.dir[n] = '\0';
    fp.name = buf + n + 1;
    n = fp.ext - q;
    strncpy(fp.name,q,n);
    fp.name[n] = '\0';

    return &fp;
}

/*
 * makename - make a file name, optionally substituting a new dir and/or ext
 */
char *makename(char *d, char *name, char *e)
{
    static char buf[MaxPath];
    struct fileparts *fp = fparse(name);
    if (d)
        fp->dir = d;
    if (e)
        fp->ext = e;
    snprintf(buf, sizeof(buf), "%s%s%s", fp->dir, fp->name, fp->ext);
    return buf;
}

/*
 * smatch - case-insensitive string match - returns nonzero if they match
 */
int smatch(char *s, char *t)
{
    char a, b;
    for (;;) {
        while (*s == *t)
            if (*s++ == '\0')
                return 1;
            else
                t++;
        a = *s++;
        b = *t++;
        if (isupper(a))  a = tolower(a);
        if (isupper(b))  b = tolower(b);
        if (a != b)
            return 0;
    }
}

/*
 * Given a path, abbreviate it if it is absolute and under the current
 * directory.  Thus, if the cd is "/tmp/dir", then
 * abbreviate("/tmp/dir/one/two.txt") would return "one/two.txt".  The
 * function is non-destructive.
 */
char *abbreviate(char *path)
{
    static char currentdir[MaxPath];
    int n;

    if (!getcwd(currentdir, sizeof(currentdir))) {
        fprintf(stderr, "getcwd return 0 - current working dir too long.");
        exit(1);
    }
    n = strlen(currentdir);

    if (strncmp(path, currentdir, n))
        return path;

    return &path[n + 1];
}

