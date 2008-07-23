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

/*
 * Operating-system-dependent includes.
 */
#if PORT
   Deliberate Syntax Error
#endif					/* PORT */

#if MSDOS
   #undef Type
   #include <sys/types.h>
   #include <sys/stat.h>
   #include <fcntl.h>
   #include <direct.h>
#ifdef NTGCC
   #include <dirent.h>
#endif					/* NTGCC */

   #ifdef MSWindows
      #define int_PASCAL int PASCAL
      #define LRESULT_CALLBACK LRESULT CALLBACK
      #define BOOL_CALLBACK BOOL CALLBACK
      #ifdef PosixFns
      #include <winsock2.h>
      #else					/* PosixFns */
      #include <windows.h>
      #endif					/* PosixFns */
      #include <mmsystem.h>
      #include <process.h>
   #else					/* MSWindows */
      #if NT
      #ifdef PosixFns
      #include <winsock2.h>
      #else
      #endif					/* PosixFns */
      #endif					/* NT */
   #endif				/* MSWindows */
   #include <setjmp.h>
   #define Type(d) (int)((d).dword & TypeMask)
   #undef lst1
   #undef lst2
#endif					/* MSDOS */


#if UNIX
   #include <dirent.h>
   #include <limits.h>
   #include <unistd.h>
   #include <sys/stat.h>
   #include <sys/time.h>
   #include <sys/times.h>
   #include <sys/types.h>
   #include <termios.h>
   #ifdef SysSelectH
      #include <sys/select.h>
   #endif
#endif					/* UNIX */

#ifdef XWindows

#ifdef Redhat71
/* due to a header bug, we must commit a preemptive first strike of Xosdefs */
#include <X11/Xosdefs.h>

#ifdef X_WCHAR
#undef X_WCHAR
#endif
#ifdef X_NOT_STDC_ENV
#undef X_NOT_STDC_ENV
#endif
#endif					/* Redhat71 */

      #ifdef HAVE_LIBXPM
         #include <X11/xpm.h>
      #else				/* HAVE_LIBXPM */
         #include <X11/Xlib.h>
      #endif				/* HAVE_LIBXPM */

      #include <X11/Xutil.h>
      #include <X11/Xos.h>
      #include <X11/Xatom.h>

   #ifdef HAVE_LIBXFT
   #include <X11/Xft/Xft.h>
   #endif
#endif					/* XWindows */

/*
 * Include this after Xlib stuff, jmorecfg.h expects this.
 */
#ifdef HAVE_LIBJPEG

#if defined(__x86_64__) && defined(XWindows)
/* Some AMD64 Gentoo systems seem to have a buggy macros in
   jmorecfg.h, but if we include Xmd.h beforehand then we get better
   definitions of the macros. */
#include <X11/Xmd.h>
#endif

#ifdef NTGCC
/* avoid INT32 compile error in jmorecfg.h by pretending we used Xmd.h! */
#define XMD_H
#endif

#include "jpeglib.h"
#include "jerror.h"
#include <setjmp.h>
/* we do not use their definitions of GLOBAL, LOCAL, or OF; we use our own */
#undef GLOBAL
#undef LOCAL
#undef OF
#endif					/* HAVE_LIBJPEG */

#ifdef Graphics
   #define VanquishReturn(s) return s;
#endif					/* Graphics */

/*
 * Feature-dependent includes.
 */
#ifndef HostStr
      #include <sys/utsname.h>
#endif					/* HostStr */

#ifdef HAVE_LIBDL
#if NT
   void *dlopen(char *, int); /* LoadLibrary */
   void *dlsym(void *, char *sym); /* GetProcAddress */
   int dlclose(void *); /* FreeLibrary */
#else					/* NT */
   #include <dlfcn.h>
#endif					/* NT */
#endif					/* HAVE_LIBDL */

#if WildCards
   #include "../h/filepat.h"
#endif					/* WildCards */


#ifdef HAVE_LIBZ
			
#  ifdef STDC
#    define OF(args)  args
#  else
#    define OF(args)  ()
#  endif

#include <zlib.h>

#endif					/* HAVE_LIBZ */

