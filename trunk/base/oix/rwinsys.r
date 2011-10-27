/*
 * File: rwinsys.r
 *  Window-system-specific window support routines.
 *  This file simply includes an appropriate r*win.ri file.
 */

#if Graphics

#if XWindows
  #include "rxwin.ri"
#elif MSWIN32
  #include "rmswin.ri"
#endif

#endif					/* Graphics */
