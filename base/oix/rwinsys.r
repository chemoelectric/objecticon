/*
 * File: rwinsys.r
 *  Window-system-specific window support routines.
 *  This file simply includes an appropriate r*win.ri file.
 */

#ifdef Graphics

#if XWindows
#include "rxwin.ri"
#endif					/* XWindows */

#if MSWIN32
#include "rmswin.ri"
#endif  				/* MSWIN32 */

#if PLAN9
#include "p9win.ri"
#endif  				/* MSWIN32 */

#endif					/* Graphics */
