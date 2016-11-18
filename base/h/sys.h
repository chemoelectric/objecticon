/*
 * sys.h -- system include files.
 */


/*
 * Universal (Standard ANSI C) includes.
 */
#if PLAN9
   #include <u.h>
   #include <libc.h>
   /* Avoid clash with size operator's struct */
   #define Bsize Bsize2
   #include <bio.h>
   #undef Bsize
   #include <draw.h>
   #include <memdraw.h>
   #include <cursor.h>
   #include <ctype.h>
   #include <stdio.h>
   #define SHRT_MAX 32767
   #define UCHAR_MAX 255
   #define INT_MAX 0x7fffffff
   typedef unsigned int size_t;
   typedef unsigned int dev_t;
   typedef unsigned long time_t;
   typedef unsigned long mode_t;
   typedef unsigned long clock_t;
   typedef vlong off_t;
   #define vsnprint vsnprint
   #define vsnprintf vsnprint
   #define setenv(k, v, o) putenv(k, v)
   #define getenv(k) oi_getenv(k)
   #define fillarc oi_fillarc
   #define EXIT_FAILURE 1
   #define EXIT_SUCCESS 0
   #define F_OK 0
   #define R_OK 4
   #define W_OK 2
   #define X_OK 1

   /* The posix file open constants */
   #define O_RDONLY 0
   #define O_WRONLY 1
   #define O_RDWR   2
   #define O_ACCMODE 3
   #define O_NONBLOCK 0
   #define O_APPEND  0x10000
   #define O_CREAT   0x20000
   #define O_TRUNC   0x40000
   #define O_EXCL    0x80000
   #define O_NOCTTY  0
   #define O_DSYNC   0
   #define O_RSYNC   0
   #define O_SYNC    0

   /* The poll() constants */
   #define POLLIN          0x001           /* There is data to read.  */
   #define POLLPRI         0x002           /* There is urgent data to read.  */
   #define POLLOUT         0x004           /* Writing now will not block.  */
   #define POLLERR         0x008           /* Error condition.  */
   #define POLLHUP         0x010           /* Hung up.  */
   #define POLLNVAL        0x020           /* Invalid polling request.  */

   #define PF_INET 0
   #define AF_INET 0
   #define SOCK_STREAM 0

   #define PointerMotionMask    1

   struct timeval {
      long    tv_sec;
      long    tv_usec;
   };
   struct timezone {
      int tz_minuteswest;     /* minutes west of Greenwich */
      int tz_dsttime;         /* type of DST correction */
   };
   #define TZSIZE 150
   struct tzinfo {
        char    stname[4];
        char    dlname[4];
        long    stdiff;
        long    dldiff;
	long	dlpairs[TZSIZE];
   };
   void be2vlong(vlong *to, uchar *f);
   char *getcwd(char *buf, size_t size);
   int mkdir(const char *path, mode_t mode);
   int rmdir(const char *path);
   int gethostname(char *name, size_t len);
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
   #include <setjmp.h>
#endif

/*
 * Operating-system-dependent includes.
 */

#if MSWIN32
   #include <winsock2.h>
   #include <ws2tcpip.h>
   #include <windows.h>
   #undef Type
   #undef MOD_SHIFT
   #include <sys/types.h>
   #include <sys/stat.h>
   #include <fcntl.h>
   #include <direct.h>
   #define LRESULT_CALLBACK LRESULT CALLBACK
   #define BOOL_CALLBACK BOOL CALLBACK
   #include <mmsystem.h>
   #include <process.h>
   #define Type(d) (int)((d).dword & TypeMask)
   #undef lst1
   #undef lst2
   #define F_OK 0
   #define R_OK 0
   #define X_OK 0
   #ifndef vsnprintf
      #define vsnprintf(a,b,c,d) vsprintf(a,c,d)
   #endif
   #define ftruncate _chsize
   #define alloca _alloca
   #define strdup _strdup
   #define unlink _unlink
   #define snprintf _snprintf
   typedef int mode_t;
   #define O_ACCMODE 3
   #include <sys/timeb.h>
   #include <sys/locking.h>
   #include <sys/utime.h>
   #include <io.h>
   #include <time.h>
   #include "gdip.h"

   #define rename(x, y) rename_utf8(x, y)
   #define mkdir(x) mkdir_utf8(x)
   #define remove(x) remove_utf8(x)
   #define rmdir(x) rmdir_utf8(x)
   #define access(x, y) access_utf8(x, y)
   #define stat(x, y) stat_utf8(x, y)
   #define open(x, y, z) open_utf8(x, y, z)
   #define lstat(x, y) stat_utf8(x, y)
   #define getenv(x) getenv_utf8(x)
   #define setenv(k, v, o) setenv_utf8(k, v)
   #define unsetenv(a) setenv_utf8(a, NULL)
   #define fopen(x, y) fopen_utf8(x, y)
#endif					/* MSWIN32 */

#if UNIX
   #include <dirent.h>
   #include <limits.h>
   #include <unistd.h>
   #include <strings.h>
   #include <sys/stat.h>
   #include <sys/time.h>
   #include <sys/times.h>
   #include <sys/types.h>
   #include <termios.h>
   #include <sys/utsname.h>
   #include <sys/select.h>
   #include <sys/wait.h>
   #include <sys/ioctl.h>
   #if HAVE_POLL
   #include <sys/poll.h>
   #endif
   #include <utime.h>
   #include <sys/resource.h>
   #include <fcntl.h>
   #include <sys/socket.h>
   #include <sys/un.h>
   #include <netinet/in.h>
   #include <arpa/inet.h>
   #include <netdb.h>
   #include <pwd.h>
   #include <grp.h>
   #if OS_SOLARIS
   #include <stropts.h>
   #endif
   #if OS_DARWIN
   #include <sys/sysctl.h>
   #include <libproc.h>
   #endif
#endif					/* UNIX */

#if XWindows
   #include <X11/X.h>
   #include <X11/Xmd.h>
   #include <X11/Xlib.h>
   #include <X11/Xutil.h>
   #include <X11/Xos.h>
   #include <X11/Xatom.h>
   #include <X11/cursorfont.h>
   #include <X11/keysym.h>
   #include <X11/Xft/Xft.h>
   #include <fontconfig/fontconfig.h>
   #include <X11/extensions/Xrender.h>
#endif					/* XWindows */

/*
 * Include this after Xlib stuff, jmorecfg.h expects this.
 */
#if HAVE_LIBJPEG
#include "jpeglib.h"
#include "jerror.h"
/* we do not use their definitions of GLOBAL, LOCAL, or OF; we use our own */
#undef GLOBAL
#undef LOCAL
#undef OF
#endif					/* HAVE_LIBJPEG */

#if HAVE_LIBPNG
#define PNG_SKIP_SETJMP_CHECK 1
#include "png.h"
#endif

#if HAVE_LIBDL
#include <dlfcn.h>
#endif					/* HAVE_LIBDL */

#if HAVE_LIBZ
#include <zlib.h>
#endif					/* HAVE_LIBZ */
