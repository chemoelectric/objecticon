/*
 * sys.h -- system include files.
 */


/*
 * Universal (Standard ANSI C) includes.
 */
#if PLAN9
   #include <u.h>
   #include <libc.h>
   #include <draw.h>
   #include <ctype.h>
   #include <stdio.h>
   #define SHRT_MAX 32767
   #define UCHAR_MAX 255
   typedef unsigned int size_t;
   typedef unsigned long time_t;
   typedef unsigned long mode_t;
   typedef unsigned long clock_t;
   typedef vlong off_t;
   typedef Point XPoint;
   #define ANGLE(ang) (ang)
   #define EXTENT(ang) (ang)
#define SCREENDEPTH(w) 0
#define LINEWIDTH(w) 0
#define DISPLAYHEIGHT(w) 0
#define DISPLAYWIDTH(w) 0
#define ICONFILENAME(w) ""
#define ICONLABEL(w) ""
#define WINDOWLABEL(w) ""

#define FS_SOLID             1
#define FS_STIPPLE           2

#define PointerMotionMask    1
#define WindowClosureMask    2
#define KeyReleaseMask       4
#define ControlMask          (1L << 16L)
#define Mod1Mask             (2L << 16L)
#define ShiftMask            (4L << 16L)
#define VirtKeyMask          (8L << 16L)

#define vsnprint vsnprint

   #define readimage oi_readimage
   #define fillarc oi_fillarc
   #define EXIT_FAILURE 1
   #define EXIT_SUCCESS 0
   #define F_OK 0
   #define R_OK 4
   #define W_OK 2
   #define X_OK 1
   #define ERANGE 100
   #define EDOM   101
   #define O_RDONLY OREAD
   #define O_WRONLY OWRITE
   #define O_RDWR   ORDWR
   #define O_ACCMODE 0 
   #define O_NONBLOCK 0
   #define O_APPEND  1024
   #define O_CREAT   512
   #define O_TRUNC   OTRUNC
   #define O_EXCL    0
   #define O_NOCTTY  0
   #define O_DSYNC   0
   #define O_RSYNC   0
   #define O_SYNC    0

   #define PF_INET 0
   #define AF_INET 0
   #define SOCK_STREAM 0

   #define PointerMotionMask    1

   extern int errno;
   struct timeval {
      long    tv_sec;
      long    tv_usec;
   };
   struct timezone {
      int tz_minuteswest;     /* minutes west of Greenwich */
      int tz_dsttime;         /* type of DST correction */
   };
   void be2vlong(vlong *to, uchar *f);
   int system(const char *command);
   char *getcwd(char *buf, size_t size);
   int mkdir(const char *path, mode_t mode);
   int rmdir(const char *path);
   int gethostname(char *name, size_t len);
   int setenv(const char *name, const char *value, int overwrite);
   int unsetenv(const char *name);
   off_t lseek(int fd, off_t offset, int whence);
   int dup2(int oldfd, int newfd);
   void exit(int status);
   int mkstemp(char *template);
   void *bsearch(const void *key, const void *base,
                     size_t nmemb, size_t size,
                     int (*compar)(const void *, const void *));
   int gettimeofday(struct timeval *tv, struct timezone *tz);
   int execv(const char *path, char *const argv[]);
   int execve(const char *path, char *const argv[], char *const envp[]);
   int rename(const char *old, const char *new);
   int unlink(const char *path);
#else
   #include <ctype.h>
   #include <errno.h>
   #include <math.h>
   #include <signal.h>
   #include <stdio.h>
   #include <stdlib.h>
   #include <string.h>
   #include <time.h>
   #include <stdarg.h>
   #include <limits.h>
   #include <float.h>
   #include <assert.h>
#endif

/*
 * Operating-system-dependent includes.
 */

#if MSWIN32
   #define  _WIN32_WINNT 0x0400
   #include <windows.h>
   #undef Type
   #include <sys/types.h>
   #include <sys/stat.h>
   #include <fcntl.h>
   #include <direct.h>
   #define int_PASCAL int PASCAL
   #define LRESULT_CALLBACK LRESULT CALLBACK
   #define BOOL_CALLBACK BOOL CALLBACK
   #include <mmsystem.h>
   #include <process.h>
   #include <setjmp.h>
   #define Type(d) (int)((d).dword & TypeMask)
   #undef lst1
   #undef lst2
   #ifndef F_OK
     #define F_OK 0
   #endif
   #ifndef R_OK
     #define R_OK 0
   #endif
   #define setenv(a,b,c) SetEnvironmentVariable(a,b)
   #define unsetenv(a) SetEnvironmentVariable(a,"")
   #ifndef vsnprintf
      #define vsnprintf(a,b,c,d) vsprintf(a,c,d)
   #endif
   #ifndef mkstemp
       #define mkstemp mktemp
   #endif
   #define ftruncate _chsize
   #define lstat stat
   #define alloca _alloca
#endif					/* MSWIN32 */

#if UNIX
   #include <dirent.h>
   #include <limits.h>
   #include <unistd.h>
   #include <sys/stat.h>
   #include <sys/time.h>
   #include <sys/times.h>
   #include <sys/types.h>
   #include <termios.h>
   #include <sys/utsname.h>
   #include <sys/select.h>
#endif					/* UNIX */

#if XWindows
      #ifdef HAVE_LIBXPM
         #include <X11/xpm.h>
      #else				/* HAVE_LIBXPM */
         #include <X11/Xlib.h>
      #endif				/* HAVE_LIBXPM */

      #include <X11/Xutil.h>
      #include <X11/Xos.h>
      #include <X11/Xatom.h>
      #include <X11/cursorfont.h>
      #include <X11/keysym.h>

   #ifdef HAVE_LIBXFT
   #include <X11/Xft/Xft.h>
   #endif
#endif					/* XWindows */

/*
 * Include this after Xlib stuff, jmorecfg.h expects this.
 */
#ifdef HAVE_LIBJPEG
#include "jpeglib.h"
#include "jerror.h"
#include <setjmp.h>
/* we do not use their definitions of GLOBAL, LOCAL, or OF; we use our own */
#undef GLOBAL
#undef LOCAL
#undef OF
#endif					/* HAVE_LIBJPEG */

#ifdef HAVE_LIBDL
#if MSWIN32
   void *dlopen(char *, int); /* LoadLibrary */
   void *dlsym(void *, char *sym); /* GetProcAddress */
   int dlclose(void *); /* FreeLibrary */
#else					/* MSWIN32 */
   #include <dlfcn.h>
#endif					/* MSWIN32 */
#endif					/* HAVE_LIBDL */


#ifdef HAVE_LIBZ
			
#  ifdef STDC
#    define OF(args)  args
#  else
#    define OF(args)  ()
#  endif

#include <zlib.h>

#endif					/* HAVE_LIBZ */

