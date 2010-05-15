/*
 * features.h -- predefined symbols and &features
 *
 * This file consists entirely of a sequence of conditionalized calls
 *  to the Feature() macro.  The macro is not defined here, but is
 *  defined to different things by the the code that includes it.
 *
 * For the macro call  Feature(guard,symname,kwval)
 * the parameters are:
 *    symname	predefined name in the preprocessor; "" if none
 *    kwval	value produced by the &features keyword; 0 if none
 *
 * The translator and compiler modify this list of predefined symbols
 * through calls to ppdef().
 */

   Feature("_V2", "V2")			/* Version 2 */

   Feature("_OBJECT_ICON", "Object Icon")

#if MSWIN32
   Feature("_MS_WIN32", "MS Win32")
#endif					/* MSWIN32 */

#if PLAN9
   Feature("_PLAN9", "PLAN9")
#endif

#if UNIX
   Feature("_UNIX", "UNIX")
#endif

   Feature("_POSIX", "POSIX")
   Feature("_ASCII", "ASCII")
   Feature("_CO_EXPRESSIONS", "co-expressions")
   Feature("_EVENT_MONITOR", "event monitoring")
   Feature("_KEYBOARD_FUNCTIONS", "keyboard functions")
   Feature("_LARGE_INTEGERS", "large integers")
   Feature("_MULTITASKING", "multiple programs")
   Feature("_PIPES", "pipes")
   Feature("_SYSTEM_FUNCTION", "system function")

#ifdef HAVE_LIBDL
   Feature("_DYNAMIC_LOADING", "dynamic loading")
#endif					/* HAVE_LIBDL */

#ifdef Graphics
   Feature("_GRAPHICS", "graphics")
#endif					/* Graphics */

#if XWindows
   Feature("_X_WINDOW_SYSTEM", "X Windows")
#endif					/* XWindows */

#ifdef HAVE_LIBZ
   Feature("_LIBZ_COMPRESSION", "libz file compression")
#endif					/* HAVE_LIBZ */

#ifdef HAVE_LIBJPEG
   Feature("_JPEG", "JPEG images")
#endif					/* HAVE_LIBJPEG */
