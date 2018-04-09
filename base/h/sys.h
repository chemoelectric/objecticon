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
#include <stdint.h>

/*
 * Operating-system-dependent includes.
 */

#if MSWIN32
   #include <winsock2.h>
   #include <ws2tcpip.h>
   #include <windows.h>
   #include <windowsx.h>
   #undef MOD_SHIFT
   #include <sys/types.h>
   #include <sys/stat.h>
   #include <fcntl.h>
   #include <direct.h>
   #define LRESULT_CALLBACK LRESULT CALLBACK
   #define BOOL_CALLBACK BOOL CALLBACK
   #define S_ISDIR(mod) ((mod) & _S_IFDIR)
   #undef lst1
   #undef lst2
   #define F_OK 0
   #define R_OK 0
   #define X_OK 0
   #define ftruncate _chsize_s
   typedef int mode_t;
   #define O_ACCMODE 3
   #include <sys/timeb.h>
   #include <io.h>
   #include <time.h>
   #include "gdip.h"
   #define off_t __int64
   #define lseek(x, y, z) _lseeki64(x, y, z)
   #define rename(x, y) rename_utf8(x, y)
   #define mkdir(x) mkdir_utf8(x)
   #define remove(x) remove_utf8(x)
   #define rmdir(x) rmdir_utf8(x)
   #define access(x, y) access_utf8(x, y)
   #define stat(x, y) stat_utf8(x, y)
   #define open(x, y, z) open_utf8(x, y, z)
   #define getenv(x) getenv_utf8(x)
   #define setenv(k, v, o) setenv_utf8(k, v)
   #define unsetenv(a) setenv_utf8(a, NULL)
   #define fopen(x, y) fopen_utf8(x, y)
   #define system(x) system_utf8(x)
   #define chdir(x) chdir_utf8(x)
   #define getcwd(x, y) getcwd_utf8(x, y)
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
   /* Avoid name clash with symbol in glib math.h */
   #define canonicalize oi_canonicalize
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
