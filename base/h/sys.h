/*
 * sys.h -- system include files.
 */


/*
 * Universal (Standard ANSI C) includes.
 */
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

/*
 * Operating-system-dependent includes.
 */

#if MSWIN32
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
   #define setenv(a,b,c) SetEnvironmentVariable(a,b)
   #define unsetenv(a) SetEnvironmentVariable(a,"")
   #ifndef vsnprintf
      #define vsnprintf(a,b,c,d) vsprintf(a,c,d)
   #endif
   #define ftruncate _chsize
   #define lstat stat
   #define alloca _alloca
   #define strdup _strdup
   #define unlink _unlink
   #define snprintf _snprintf
   typedef int mode_t;
   typedef int socklen_t;
   #define O_ACCMODE 3
   #include <sys/timeb.h>
   #include <sys/locking.h>
   #include <sys/utime.h>
   #include <io.h>
   #include <time.h>
   #include "gdip.h"
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
#if MSWIN32
   void *dlopen(char *, int); /* LoadLibrary */
   void *dlsym(void *, char *sym); /* GetProcAddress */
   int dlclose(void *); /* FreeLibrary */
#else					/* MSWIN32 */
   #include <dlfcn.h>
#endif					/* MSWIN32 */
#endif					/* HAVE_LIBDL */


#if HAVE_LIBZ
			
#  ifdef STDC
#    define OF(args)  args
#  else
#    define OF(args)  ()
#  endif

#include <zlib.h>

#endif					/* HAVE_LIBZ */
