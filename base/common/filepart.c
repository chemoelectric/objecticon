/*
 * This file contains pathfind(), fparse(), makename(), and smatch().
 */
#include "../h/gsupport.h"

static char *tryfile	(char *buf, char *dir, char *name, char *extn);

/*
 * The following code is operating-system dependent [@filepart.01].
 *
 *  Define symbols for building file names.
 *  1. Prefix: the characters that terminate a file name prefix
 *  2. FileSep: the char to insert after a dir name, if any
 *  2. DefPath: the default IPATH/LPATH, if not null
 *  3. PathSep: allowable IPATH/LPATH separators, if not just " "
 */

#if PORT
#define Prefix "/"
#define FileSep '/'
Deliberate Syntax Error
#endif					/* PORT */

#if AMIGA
#define Prefix "/:"
#define FileSep '/'
#endif					/* AMIGA */

#if ARM
#define Prefix ".:"
#define DefPath "Icon: Lib:Icon."
#endif					/* ARM */

#if ATARI_ST
#define Prefix "/:\\"
#endif					/* ATARI_ST */

#if MSDOS || OS2
#define Prefix "/:\\"
#define DefPath ";"
#if HIGHC_386
#define FileSep '\\'
#else				/* HIGHC_386 */
#define FileSep '/'
#endif				/* HIGHC_386 */
#endif					/* MSDOS || OS2 */

#if MACINTOSH
#define Prefix ":"
#define FileSep ':'
#if MPW || LWC
#define DefPath ":"
#endif				/* MPW || LSC */
#if MPW
#define PathSep ","
#endif				/* MPW */
#endif					/* MACINTOSH */

#if MVS
#define Prefix ""
#define FileSep '('
#if SASC
#define DefPath "iconlib ddn:::lib"
#endif				/* SASC */
#endif					/* MVS */

#if VM
#define Prefix ""
#endif					/* VM */

#if UNIX
#define Prefix "/"
#define FileSep '/'
#define PathSep " :"
#endif					/* UNIX */

#if VMS
#define Prefix "]:"
#endif					/* VMS */

/*
 * End of operating-system specific code.
 */

#ifndef DefPath
#define DefPath ""
#endif					/* DefPath */

#ifndef PathSep
#define PathSep " "
#endif					/* PathSep */

#include <string.h>

/*
 * pathfind(buf,path,name,extn) -- find file in path and return name.
 *
 *  pathfind looks for a file on a path, begining with the current
 *  directory.  Details vary by platform, but the general idea is
 *  that the file must be a readable simple text file.  pathfind
 *  returns buf if it finds a file or NULL if not.
 *
 *  buf[MaxFileName] is a buffer in which to put the constructed file name.
 *  path is the IPATH or LPATH value, or NULL if unset.
 *  name is the file name.
 *  extn is the file extension (.icn or .u1) to be appended, or NULL if none.
 */
char *pathfind(buf, path, name, extn)
    char *buf, *path, *name, *extn;
{
    char *s;
    char pbuf[MaxFileName];

    if (tryfile(buf, (char *)NULL, name, extn))	/* try curr directory first */
        return buf;

    /* Don't search the path if we have an absolute path */
    if (isabsolute(name))
        return NULL;

    if (!path)				/* if no path, use default */
        path = DefPath;
    s = path;

    while ((s = pathelem(s, pbuf)) != 0) {	/* for each path element */
        if (tryfile(buf, pbuf, name, extn))	/* look for file */
            return buf;
    }
    return NULL;				/* return NULL if no file found */
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
 * pathelem(s,buf) -- copy next path element from s to buf.
 *
 *  Returns the updated pointer s.
 */
char *pathelem(s, buf)
    char *s, *buf;
{
    char c;

    while ((c = *s) != '\0' && strchr(PathSep, c))
        s++;
    if (!*s)
        return NULL;

    if (*s == '"') {
        s++;
        while ((c = *s) != '\0' && (c != '"')) {
            *buf++ = c;
            s++;
        }
        s++;
    }
    else {
        while ((c = *s) != '\0' && !strchr(PathSep, c)) {
            *buf++ = c;
            s++;
        }
    }
#ifdef FileSep
    /*
     * We have to append a path separator here.
     *  Seems like makename should really be the one to do that.
     */
    if (!strchr(Prefix, buf[-1])) {	/* if separator not already there */
        *buf++ = FileSep;
    }
#endif					/* FileSep */

    *buf = '\0';
    return s;
}

/*
 * Find the last path element in a path string, eg /abc/def/file.txt -> file.txt
 */
char *last_pathelem(char *s)
{
    char *p = strrchr(s, FileSep);
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
 * tryfile(buf, dir, name, extn) -- check to see if file is readable.
 *
 *  The file name is constructed in buf from dir + name + extn.
 *  findfile returns buf if successful or NULL if not.
 */
static char *tryfile(buf, dir, name, extn)
    char *buf, *dir, *name, *extn;
{
    FILE *f;
    makename(buf, dir, name, extn);
    if ((f = fopen(buf, ReadText)) != NULL) {
        fclose(f);
        return buf;
    }
    else
        return NULL;
}

/*
 * fparse - break a file name down into component parts.
 * Result is a pointer to a struct of static pointers good until the next call.
 */
struct fileparts *fparse(s)
    char *s;
{
    static char buf[MaxFileName+2];
    static struct fileparts fp;
    int n;
    char *p, *q;

    q = s;
    fp.ext = p = s + strlen(s);
    while (--p >= s) {
        if (*p == '.' && *fp.ext == '\0')
            fp.ext = p;
        else if (strchr(Prefix,*p)) {
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
char *makename(dest,d,name,e)
    char *dest, *d, *name, *e;
{
    struct fileparts fp;
    fp = *fparse(name);
    if (d != NULL)
        fp.dir = d;
    if (e != NULL)
        fp.ext = e;

    sprintf(dest,"%s%s%s",fp.dir,fp.name,fp.ext);

    return dest;
}

/*
 * smatch - case-insensitive string match - returns nonzero if they match
 */
int smatch(s,t)
    char *s, *t;
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


#if MSDOS
#if NT
#include <sys/stat.h>
#include <direct.h>
#endif					/* NT */

/*
 * this version of pathfind, unlike the one above, is looking on
 * the real path to find an executable.
 */
int pathFind(char target[], char buf[], int n)
{
    char *path;
    register int i;
    int res;
    struct stat sbuf;

    if ((path = getenv("PATH")) == 0)
        path = "";

    if (!getcwd(buf, n)) {		/* get current working directory */
        *buf = 0;		/* may be better to do something nicer if we can't */
        return 0;		/* find out where we are -- struggling to achieve */
    }			/* something can be better than not trying */

    /* attempt to find the icode file in the current directory first */
    /* this mimicks the behavior of COMMAND.COM */
    if ((i = strlen(buf)) > 0) {
        i = buf[i - 1];
        if (i != '\\' && i != '/' && i != ':')
            strcat(buf, "/");
    }
    strcat(buf, target);
    res = stat(buf, &sbuf);

    while(res && *path) {
        for (i = 0; *path && *path != ';'; ++i)
            buf[i] = *path++;
        if (*path)			/* skip the ; or : separator */
            ++path;
        if (i == 0)			/* skip empty fragments in PATH */
            continue;
        if (i > 0 && buf[i-1] != '/' && buf[i-1] != '\\' && buf[i-1] != ':')
            buf[i++] = '\\';
        strcpy(buf + i, target);
        res = stat(buf, &sbuf);
        /* exclude directories (and any other nasties) from selection */
        if (res == 0 && sbuf.st_mode & S_IFDIR)
            res = -1;
    }
    if (res != 0)
        *buf = 0;
    return res == 0;
}
#endif					/* MSDOS */



#if MSDOS || OS2
FILE *pathOpen(char *fname, char *mode)
{
#if OS2
    char buf[260 + 1];
#else					/* OS2 */
    char buf[150 + 1];
#endif					/* OS2 */
    int i, use = 1;

#if SCCX_MX
    /* Avoid compiler warning */
    for( i = 0; (buf[i] = fname[i]) != 0; ++i)
#else
        for( i = 0; buf[i] = fname[i]; ++i)
#endif					/* SCCX_MX */

            /* find out if a path has been given in the file name */
            if (buf[i] == '/' || buf[i] == ':' || buf[i] == '\\')
                use = 0;

    /* If a path has been given with the file name, don't bother to
       use the PATH */

#if OS2
    if (use && DosSearchPath(SEARCH_CUR_DIRECTORY | SEARCH_ENVIRONMENT, 
                             "PATH", fname, buf, 260))
#else					/* OS2 */
        if (use && !pathFind(fname, buf, 150))
#endif 					/* OS2 */
            return 0;

    return fopen(buf, mode);
}
#endif					/* MSDOS || OS2 */


/*
 * Given a path, abbreviate it if it is absolute and under the current
 * directory.  Thus, if the cd is "/tmp/dir", then
 * abbreviate("/tmp/dir/one/two.txt") would return "one/two.txt".  The
 * function is non-destructive.
 */
char *abbreviate(char *path)
{
    static char currentdir[PATH_MAX];
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
