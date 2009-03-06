
/*
 * posix.h - includes for posix interface
 */

/*
 * Copyright 1997 Shamim Mohamed.
 *
 * Modification and redistribution is permitted as long as this (and any
 * other) copyright notices are kept intact.
 */

#if UNIX
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#ifdef HAVE_POLL
#include <sys/poll.h>
#endif
#include <time.h>
#include <dirent.h>
#include <unistd.h>
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
#endif					/* UNIX */

#if MSWIN32
#include <sys/timeb.h>
#include <sys/locking.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/utime.h>
#include <fcntl.h>
#include <io.h>
#include <time.h>
#include <process.h>
#endif					/* MSWIN32 */

#if defined(SUN) || defined(HP) || defined(IRIS4D)
#include <sys/file.h>

extern int sys_nerr;
extern char *sys_errlist[];


#ifdef SYSV
#define bcopy(a, b, n) memcopy(b, a, n)
#endif
#endif					/* SUN || HP */

#ifdef HP
#define FASYNC O_SYNC
#endif

#if defined(BSD) || defined(HP) || defined(BSD_4_4_LITE)
#include <sys/param.h>
#endif

#if defined(BSD) || defined(BSD_4_4_LITE)
#define Setpgrp() setpgrp(0, 0)
#else
#define Setpgrp() setpgrp()
#endif

extern stringint signalnames[];

#ifdef IRIS4D
#include <limits.h>
#include <sys/param.h>
#endif					/* IRIS4D */

#if MSWIN32
extern WORD wVersionRequested;
extern WSADATA wsaData;
extern int werr;
extern int WINSOCK_INITIAL;
#endif					/* MSWIN32 */
