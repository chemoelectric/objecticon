/*
 * mlocal.c - special platform specific code
 */
#include "../h/gsupport.h"

#if UNIX || NT

#if UNIX
#define PATHSEP ':'
#define FILESEP '/'
#endif
#if MSDOS
#define PATHSEP ';'
#define FILESEP '\\'
#endif

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
    strcat(t, mod);			/* append adjustment */
    normalize(t);			/* normalize result */
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
    static char buf[PATH_MAX];

    nlen = strlen(name);
    path = getenv("PATH");
    if (path == NULL || *path == '\0')
        path = ".";
    end = path + strlen(path);
    for (next = path; next <= end; next = sep + 1) {
        sep = strchr(next, PATHSEP);
        if (sep == NULL)
            sep = end;
        plen = sep - next;
        if (plen == 0) {
            next = ".";
            plen = 1;
        }
        if (plen + 1 + nlen + 1 >= sizeof(buf)) {
            *buf = '\0';
            return NULL;
        }
        memcpy(buf, next, plen);
        buf[plen] = '/';
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
    return NULL;
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
    static char result[PATH_MAX];
    static char currentdir[PATH_MAX];
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
    static char result[PATH_MAX];
    static char currentdir[PATH_MAX];
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
    return NULL;
}


void quotestrcat(char *buf, char *s)
{
    if (strchr(s, ' ')) strcat(buf, "\"");
    strcat(buf, s);
    if (strchr(s, ' ')) strcat(buf, "\"");
}


#endif
