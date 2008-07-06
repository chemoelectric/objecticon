/*
 * mlocal.c - special platform specific code
 */
#include "../h/gsupport.h"

#if UNIX || NT

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#if UNIX || defined(NTGCC)
#include <unistd.h>
#endif					/* UNIX || NTGCC */
#if UNIX
#define PATHSEP ':'
#define FILESEP '/'
#endif
#if MSDOS
#define PATHSEP ';'
#define FILESEP '\\'
#endif

static char *findexe(char *name, char *buf, size_t len);
char *findonpath(char *name, char *buf, size_t len);
static char *followsym(char *name, char *buf, size_t len);

/*
 *  relfile(prog, mod) -- find related file.
 *
 *  Given that prog is the argv[0] by which this program was executed,
 *  and assuming that it was set by the shell or other equally correct
 *  invoker, relfile finds the location of a related file and returns
 *  it in an allocated string.  It takes the location of prog, appends
 *  mod, and normalizes the result; thus if argv[0] is icont or its path,
 *  relfile(argv[0],"/../iconx") finds the location of iconx.
 */
char *relfile(char *prog, char *mod) {
   static char baseloc[MaxPath];
   char buf[MaxPath];

   if (baseloc[0] == 0) {		/* if argv[0] not already found */
      if (findexe(prog, baseloc, sizeof(baseloc)) == NULL) {
	 fprintf(stderr, "cannot find location of %s\n", prog);
         exit(EXIT_FAILURE);
	 }
      if (followsym(baseloc, buf, sizeof(buf)) != NULL)
         strcpy(baseloc, buf);
   }

   strcpy(buf, baseloc);		/* start with base location */
   strcat(buf, mod);			/* append adjustment */
   normalize(buf);			/* normalize result */
   return salloc(buf);			/* return allocated string */
   }

/*
 *  findexe(prog, buf, len) -- find absolute executable path, given argv[0]
 *
 *  Finds the absolute path to prog, assuming that prog is the value passed
 *  by the shell in argv[0].  The result is placed in buf, which is returned.
 *  NULL is returned in case of error.
 */

static char *findexe(char *name, char *buf, size_t len) {
   int n;
   char *s;

   if (name == NULL)
      return NULL;

   /* if name does not contain a slash, search $PATH for file */
   if ((strchr(name, '/') != NULL)
#if MSDOS
       || (strchr(name, '\\') != NULL)
#endif
       )
      strcpy(buf, name);
   else if (findonpath(name, buf, len) == NULL) {
      strcpy(buf, name);
      }

   /* if path is not absolute, prepend working directory */
#if MSDOS
   if (! (isalpha(buf[0]) && buf[1] == ':'))
#endif					/* MSDOS */
   if ((buf[0] != '/')
#if MSDOS
       && (buf[0] != '\\')
#endif					/* MSDOS */
   ) {
      n = strlen(buf) + 1;
      memmove(buf + len - n, buf, n);
      if (getcwd(buf, len - n) == NULL)
         return NULL;
      s = buf + strlen(buf);
      *s = '/';
      memcpy(s + 1, buf + len - n, n);
      }
   normalize(buf);
   return buf;
   }

/*
 *  findonpath(name, buf, len) -- find name on $PATH
 *
 *  Searches $PATH (using POSIX 1003.2 rules) for executable name,
 *  writing the resulting path in buf if found.
 */
char *findonpath(char *name, char *buf, size_t len) {
   int nlen, plen;
   char *path, *next, *sep, *end;

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
      if (plen + 1 + nlen + 1 > len) {
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

/*
 *  followsym(name, buf, len) -- follow symlink to final destination.
 *
 *  If name specifies a file that is a symlink, resolves the symlink to
 *  its ultimate destination, and returns buf.  Otherwise, returns NULL.
 *
 *  Note that symlinks in the path to name do not make it a symlink.
 *
 *  buf should be long enough to hold name.
 */

#define MAX_FOLLOWED_LINKS 24

static char *followsym(char *name, char *buf, size_t len) {
   int i, n;
   char *s, tbuf[MaxPath];

#if UNIX
   strcpy(buf, name);

   for (i = 0; i < MAX_FOLLOWED_LINKS; i++) {
      if ((n = readlink(buf, tbuf, sizeof(tbuf) - 1)) <= 0)
         break;
      tbuf[n] = 0;

      if (tbuf[0] == '/') {
         if (n < len)
            strcpy(buf, tbuf);
         else
            return NULL;
         }
      else {
         s = strrchr(buf, '/');
         if (s != NULL)
            s++;
         else
            s = buf;
         if ((s - buf) + n < len)
            strcpy(s, tbuf);
         else
            return NULL;
         }
      normalize(buf);
      }

   if (i > 0 && i < MAX_FOLLOWED_LINKS)
      return buf;
   else
#endif
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

FILE *pathOpen(char *fname, char *mode)
{
    char buf[260 + 1];
    int i, use = 1;

    for( i = 0; buf[i] = fname[i]; ++i)
        /* find out if a path has been given in the file name */
        if (buf[i] == '/' || buf[i] == ':' || buf[i] == '\\')
            use = 0;

    /* If a path has been given with the file name, don't bother to
       use the PATH */

    if (use && !pathFind(fname, buf, 150))
        return 0;

    return fopen(buf, mode);
}


#else


FILE *pathOpen(char *fname, char *mode)
{
   char tmp[256];
   char *s = findexe(fname, tmp, 255);
   if (s) {
      return fopen(tmp, mode);
      }
   return NULL;
}
#endif

void quotestrcat(char *buf, char *s)
{
   if (strchr(s, ' ')) strcat(buf, "\"");
   strcat(buf, s);
   if (strchr(s, ' ')) strcat(buf, "\"");
}

#else                                  /* UNIX */

static char junk;		/* avoid empty module */

#endif					/* UNIX */


#if AMIGA && __SASC
#include <workbench/startup.h>
#include <rexx/rxslib.h>
#include <proto/dos.h>
#include <proto/icon.h>
#include <proto/wb.h>
#include <proto/rexxsyslib.h>
#include <proto/exec.h>

int _WBargc;
char **_WBargv;
struct MsgPort *_IconPort = NULL;
char *_PortName;

/* This is an SAS/C auto-initialization routine.  It extracts the
 * filename arguments from the ArgList in the Workbench startup message
 * and generates an ANSI argv, argc from them.  These are given the
 * global pointers _WBargc and _WBargv.  It also checks the Tooltypes for
 * a WINDOW specification and points the ToolWindow to it.  (NOTE: the
 * ToolWindow is a reserved hook in the WBStartup structure which is
 * currently unused. When the Workbench supports editing the ToolWindow,
 * this ToolType will become obsolete.)  The priority is set to 400 so
 * this will run before the stdio initialization (_iob.c).  The code in
 * _iob.c sets up the default console window according to the ToolWindow
 * specification, provided it is not NULL. 
 */

int __stdargs _STI_400_WBstartup(void) {
   struct WBArg *wba;
   struct DiskObject *dob;
   int n;
   char buf[512];
   char *windowspec;

   _WBargc = 0;
   if(_WBenchMsg == NULL || Output() != NULL) return 0;
   _WBargv = (char **)malloc((_WBenchMsg->sm_NumArgs + 4)*sizeof(char *));
   if(_WBargv == NULL) return 1;
   wba = _WBenchMsg->sm_ArgList;

   /* Change to the WB icon's directory */
   CurrentDir((wba+1)->wa_Lock);

   /* Get the window specification */
   if(dob = GetDiskObject((wba+1)->wa_Name)) {
      if(dob->do_ToolTypes){
         windowspec = FindToolType(dob->do_ToolTypes, "WINDOW");
         if (windowspec){
            _WBenchMsg->sm_ToolWindow = malloc(strlen(windowspec)+1);
            strcpy(_WBenchMsg->sm_ToolWindow, windowspec);
            }
         }
      FreeDiskObject(dob);
      }

   /* Create argc and argv */
   for(n = 0; n < _WBenchMsg->sm_NumArgs; n++, wba++){
      if (wba->wa_Name != NULL &&
              NameFromLock(wba->wa_Lock, buf, sizeof(buf)) != 0) {
         AddPart(buf, wba->wa_Name, sizeof(buf));
         _WBargv[_WBargc] = (char *)malloc(strlen(buf) + 1);
         if (_WBargv[_WBargc] == NULL) return 1; 
         strcpy(_WBargv[_WBargc], buf);
         _WBargc++;
         }
      }

   /* Just in case ANSI is watching ... */
   _WBargv[_WBargc] = NULL;
   }

/* We open and close our message port with this auto-initializer and
 * auto-terminator to minimize disruption of the Icon code.
 */

void _STI_10000_OpenPort(void) {
   char  *name;
   char  *end;
   int   n = 1;
   char  buf[256];

   if( GetProgramName(buf, 256) == 0) {
     if (_WBargv == NULL) return; 
     else strcpy(buf, _WBargv[0]);
     }

   name = FilePart(buf);
   _PortName = malloc(strlen(name) + 2);
   strcpy(_PortName, name);
   end = _PortName + strlen(_PortName);
   /* In case there are many of us */ 
   while ( FindPort(_PortName) != NULL ) {
      sprintf(end, "%d", n++);
      if (n > 9) return;
      }
   _IconPort = CreatePort(_PortName, 0);
   }

void _STD_10000_ClosePort(void) {
   struct Message *msg;

   if (_IconPort) {
      while (msg = GetMsg(_IconPort)) ReplyMsg(msg);
      DeletePort(_IconPort);
      }
   }

/*
 * This posts an error message to the ARexx Clip List.
 * The clip is named <_PortName>Clip.<errorcount>.  The value
 * string contains the file name, line number, error number and
 *  error message.
 */
static int errorcount = 0;

void PostClip(char *file, int line, int number, char *text) {
   struct MsgPort *rexxport;
   struct RexxMsg *rxmsg;
   char name[128];
   char value[512];

   if ( _IconPort ) {
      if ( rxmsg = CreateRexxMsg(_IconPort, NULL, NULL) ) {
         errorcount++;
         sprintf(name, "%sClip.%d", _PortName, errorcount);
         sprintf(value, "File: %s Line: %d Number: %d Text: %s",
                         file, line, number, text);
         rxmsg->rm_Action = RXADDCON;
         ARG0(rxmsg) = name;
         ARG1(rxmsg) = value;
         ARG2(rxmsg) = (unsigned char *)(strlen(value) + 1);
         Forbid();
         rexxport = FindPort("REXX");
         if ( rexxport ) { 
            PutMsg(rexxport, (struct Message *)rxmsg);
            WaitPort(_IconPort);
            }
         Permit();
         GetMsg(_IconPort);
         DeleteRexxMsg(rxmsg);
         }
      }
   }


/*
 * This function sends a message to the resident ARexx process telling it to
 * run the specified script with argument a stem for the names of the clips
 * containing error information.  The intended use is to invoke an editor
 *  when a fatal error is encountered.
 */

void CallARexx(char *script) {
   struct MsgPort *rexxport;
   struct RexxMsg *rxmsg;
   char command[512];

   if ( _IconPort ) {
      if ( rxmsg = CreateRexxMsg(_IconPort, NULL, NULL) ) {
         sprintf(command, "%s %sClip", script, _PortName);
         rxmsg->rm_Action = RXCOMM | RXFB_NOIO;
         ARG0(rxmsg) = command;
         if (FillRexxMsg(rxmsg,1,0) ) {
            Forbid();
            rexxport = FindPort("REXX");
            if ( rexxport ) { 
               PutMsg(rexxport, (struct Message *)rxmsg);
               WaitPort(_IconPort);
               }
            Permit();
            GetMsg(_IconPort);
            ClearRexxMsg(rxmsg,1);
            }
         DeleteRexxMsg(rxmsg);
         }
      }
   }
#endif					/* AMIGA && __SASC */

#if !UNIX && !(AMIGA && __SASC)
char junkclocal; /* avoid empty module */
#endif					/* !UNIX && !(AMIGA && __SASC) */
