/*
 * mswin.h - macros and types used in the MS Windows graphics interface.
 */

#define DRAWOP_AND			R2_MASKPEN
#define DRAWOP_ANDINVERTED		R2_MASKNOTPEN
#define DRAWOP_ANDREVERSE		R2_NOTMASKPEN
#define DRAWOP_CLEAR			R2_BLACK
#define DRAWOP_COPY			R2_COPYPEN
#define DRAWOP_COPYINVERTED		R2_NOTCOPYPEN
#define DRAWOP_EQUIV			R2_NOTXORPEN
#define DRAWOP_INVERT			R2_NOT
#define DRAWOP_NAND			R2_MASKNOTPEN
#define DRAWOP_NOOP			R2_NOP
#define DRAWOP_NOR			R2_MERGENOTPEN
#define DRAWOP_OR			R2_MERGEPEN
#define DRAWOP_ORINVERTED		R2_MERGEPENNOT
#define DRAWOP_ORREVERSE		R2_NOTMERGEPEN
#define DRAWOP_REVERSE			R2_USER1
#define DRAWOP_SET			R2_WHITE
#define DRAWOP_XOR			R2_XORPEN

#define RED(x) GetRValue(x)
#define GREEN(x) GetGValue(x)
#define BLUE(x) GetBValue(x)

/*
 *
 */
#define FULLARC 2 * Pi

/*
 * the special ROP code for mode reverse
 */
#define R2_USER1            (R2_LAST << 1)
/*
 * window states
 */
#define WS_NORMAL            0
#define WS_MIN               1
#define WS_MAX               2

/*
 * something I think should be #defined
 */
#define EOS                  '\0'

/* size of the working buffer, used for dialog messages and such */
#define PMSTRBUFSIZE         2048

/* some macros for Windows */

#define MAKERGB(r,g,b) RGB(r,g,b)
#define RGB16TO8(x) if ((x) > 0xff) (x) = (((x) >> 8) & 0xff)
#define FNTWIDTH(size) ((size) & 0xFFFF)
#define FNTHEIGHT(size) ((size) >> 16)
#define MAKEFNTSIZE(height, width) (((height) << 16) | (width))
#define WaitForEvent(msgnum, msgstruc) ObtainEvents(NULL, WAIT_EVT, msgnum, msgstruc)

/*
 * system size values
 */
#define BORDERWIDTH      (GetSystemMetrics(SM_CXBORDER)) /* 1 */
#define BORDERHEIGHT     (GetSystemMetrics(SM_CYBORDER)) /* 1 */
#define TITLEHEIGHT      (GetSystemMetrics(SM_CYCAPTION)) /* 20 */
#define FRAMEWIDTH	 (GetSystemMetrics(SM_CXFRAME))   /* 4 */
#define FRAMEHEIGHT	 (GetSystemMetrics(SM_CYFRAME))   /* 4 */

#define STDLOCALS(w) \
   wcp wc = (w)->context;\
   wsp ws = (w)->window;\
   HWND stdwin = ws->win;\
   HBITMAP stdpix = ws->pix;\
   HDC stddc = CreateWinDC(w);\
   HDC pixdc = CreatePixDC(w);

#define STDFONT \
   { if(stdwin)SelectObject(stddc, wc->font->font); SelectObject(pixdc,wc->font->font); }

#define FREE_STDLOCALS(w) do { \
   SelectObject(pixdc, (w)->window->theOldPix); \
   if (stddc) ReleaseDC((w)->window->win, stddc);    \
   DeleteDC(pixdc); } while (0)
