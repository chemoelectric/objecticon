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

#if AMIGA
   #include <fcntl.h>
   #include <ios1.h>
   #include <libraries/dosextens.h>
   #include <libraries/dos.h>
   #include <workbench/startup.h>
   #if __SASC
      #include <proto/dos.h>
      #include <proto/icon.h>
      #include <proto/wb.h>
      #undef GLOBAL
      #undef STATIC			/* defined in <exec/types.h> */
   #endif				/* __SASC */
#endif					/* AMIGA */

#if ATARI_ST
   #include <fcntl.h>
   #include <osbind.h>
#endif					/* ATARI_ST */

#if MACINTOSH
   #if LSC
      #include <unix.h>
   #endif				/* LSC */
   #if MPW
      #define create xx_create	/* prevent duplicate definition of create() */
      #include <Types.h>
      #include <Events.h>
      #include <Files.h>
      #include <FCntl.h>
      #include <Files.h>
      #include <IOCtl.h>
      #include <fp.h>
      #include <OSUtils.h>
      #include <Memory.h>
      #include <Errors.h>
      #include "time.h"
      #include <Quickdraw.h>
      #include <ToolUtils.h>
      #include <CursorCtl.h>
   #endif				/* MPW */
   #ifdef MacGraph
      #include <console.h>
      #include <AppleEvents.h>
      #include <GestaltEqu.h>
      #include <fp.h>
      #include <QDOffscreen.h>
      #include <Palettes.h>
      #include <Quickdraw.h>
   #endif				/* MacGraph */
#endif					/* MACINTOSH */


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


#if OS2
   #define INCL_DOS
   #define INCL_ERRORS
   #define INCL_RESOURCES
   #define INCL_DOSMODULEMGR

   #ifdef PresentationManager
      #define INCL_PM
   #endif				/* PresentationManager */

   #include <os2.h>
   /* Pipe support for OS/2 */
   #include <stddef.h>
   #include <process.h>
   #include <fcntl.h>

#endif					/* OS2 */

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

#if VMS
   #include <types.h>
   #include <dvidef>
   #include <iodef>
   #include <stsdef.h>
#endif					/* VMS */

#ifdef XWindows
   /*
    * Undef VMS under UNIX, and UNIX under VMS,
    * to avoid confusing the tests within the X header files.
    */
   #if VMS
      #undef UNIX
      #include "decw$include:Xlib.h"
      #include "decw$include:Xutil.h"
      #include "decw$include:Xos.h"
      #include "decw$include:Xatom.h"

      #ifdef HAVE_LIBXPM
         #include <X11/xpm.h>
      #endif				/* HAVE_LIBXPM */

      #undef UNIX
      #define UNIX 0
   #else				/* VMS */
      #undef VMS

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
#if !AMIGA
#define AMIGA_ZERO
#undef AMIGA
#endif					/* !AMIGA */
         #include <X11/xpm.h>
#ifdef AMIGA_ZERO
#define AMIGA 0
#endif					/* !AMIGA */
      #else				/* HAVE_LIBXPM */
         #include <X11/Xlib.h>
      #endif				/* HAVE_LIBXPM */

      #include <X11/Xutil.h>
      #include <X11/Xos.h>
      #include <X11/Xatom.h>

      #undef VMS
      #define VMS 0
   #endif				/* VMS */

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
   #if !VMS
      #include <sys/utsname.h>
   #endif				/* !VMS */
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

#if !VMS
#undef VMS
#endif
#include <zlib.h>
#ifndef VMS
#define VMS 0
#endif

#endif					/* HAVE_LIBZ */

