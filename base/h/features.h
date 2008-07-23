/*
 * features.h -- predefined symbols and &features
 *
 * This file consists entirely of a sequence of conditionalized calls
 *  to the Feature() macro.  The macro is not defined here, but is
 *  defined to different things by the the code that includes it.
 *
 * For the macro call  Feature(guard,symname,kwval)
 * the parameters are:
 *    guard	for the compiler's runtime system, an expression that must
 *		evaluate as true for the feature to be included in &features
 *    symname	predefined name in the preprocessor; "" if none
 *    kwval	value produced by the &features keyword; 0 if none
 *
 * The translator and compiler modify this list of predefined symbols
 * through calls to ppdef().
 */

   Feature(1, "_V9", 0)			/* Version 9 (unconditional) */

#if MSWIN32
   Feature(1, "_MS_WIN32", "MS Win32")
#endif					/* MSWIN32 */

#if PORT
   Feature(1, "_PORT", "PORT")
#endif					/* PORT */

#if UNIX
   Feature(1, "_UNIX", "UNIX")
#endif					/* VM */

#ifdef PosixFns
   Feature(1, "_POSIX", "POSIX")
#endif					/* PosixFns */

#if EBCDIC != 1
   Feature(1, "_ASCII", "ASCII")
#else					/* EBCDIC != 1 */
   Feature(1, "_EBCDIC", "EBCDIC")
#endif					/* EBCDIC */

   Feature(1, "_CO_EXPRESSIONS", "co-expressions")


#ifdef HAVE_LIBDL
   Feature(1, "_DYNAMIC_LOADING", "dynamic loading")
#endif					/* HAVE_LIBDL */

   Feature(1, "", "environment variables")

#ifdef EventMon
   Feature(1, "_EVENT_MONITOR", "event monitoring")
#endif					/* EventMon */

   Feature(1, "_EXTERNAL_FUNCTIONS", "external functions")

#ifdef KeyboardFncs
   Feature(1, "_KEYBOARD_FUNCTIONS", "keyboard functions")
#endif					/* KeyboardFncs */

#ifdef LargeInts
   Feature(largeints, "_LARGE_INTEGERS", "large integers")
#endif					/* LargeInts */

   Feature(1, "_MULTITASKING", "multiple programs")

#ifdef Pipes
   Feature(1, "_PIPES", "pipes")
#endif					/* Pipes */

   Feature(1, "_SYSTEM_FUNCTION", "system function")


#ifdef Graphics
   Feature(1, "_GRAPHICS", "graphics")
#endif					/* Graphics */


#ifdef XWindows
   Feature(1, "_X_WINDOW_SYSTEM", "X Windows")
#endif					/* XWindows */

#ifdef MSWindows
   Feature(1, "_MS_WINDOWS", "MS Windows")
#endif					/* MSWindows */

#ifdef DosFncs
   Feature(1, "_DOS_FUNCTIONS", "MS-DOS extensions")
#endif					/* DosFncs */

#ifdef HAVE_LIBZ
   Feature(1, "_LIBZ_COMPRESSION", "libz file compression")
#endif					/* HAVE_LIBZ */

#ifdef HAVE_LIBJPEG
   Feature(1, "_JPEG", "JPEG images")
#endif					/* HAVE_LIBJPEG */

#ifdef HAVE_LIBXPM
   Feature(1, "_XPM", "XPM images")
#endif					/* HAVE_LIBXPM */

