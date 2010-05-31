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

#define SysColor unsigned long
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
 * input masks
 */
#define PointerMotionMask    1
#define WindowClosureMask    2
#define KeyReleaseMask       4

/*
 * something I think should be #defined
 */
#define EOS                  '\0'

/* size of the working buffer, used for dialog messages and such */
#define PMSTRBUFSIZE         2048
/*
 * the bitmasks for the modifier keys
 */
#define ControlMask          (1L << 16L)
#define Mod1Mask             (2L << 16L)
#define ShiftMask            (4L << 16L)
#define VirtKeyMask          (8L << 16L)

/* some macros for Windows */

#define MAKERGB(r,g,b) RGB(r,g,b)
#define RGB16TO8(x) if ((x) > 0xff) (x) = (((x) >> 8) & 0xff)
#define FNTWIDTH(size) ((size) & 0xFFFF)
#define FNTHEIGHT(size) ((size) >> 16)
#define MAKEFNTSIZE(height, width) (((height) << 16) | (width))
#define WaitForEvent(msgnum, msgstruc) ObtainEvents(NULL, WAIT_EVT, msgnum, msgstruc)

#define SHARED          0
#define MUTABLE         1
#define MAXCOLORNAME	40
/*
 * color structure, inspired by X code (xwin.h)
 */
typedef struct wcolor {
  int		refcount;
  char		name[6+MAXCOLORNAME];	/* name for WAttrib & WColor reads */
  SysColor	c;
  int           type;			/* SHARED or MUTABLE */
} *wclrp;

/*
 * we make the segment structure look like this so that we can
 * cast it to POINTL structures that can be passed to GpiPolyLineDisjoint
 */
typedef struct {
   int x1, y1;
   int x2, y2;
   } XSegment;

typedef POINT XPoint;
typedef RECT XRectangle;

typedef struct {
  int x, y;
  int width, height;
  double angle1, angle2;
  } XArc;

/*
 * macros performing row/column to pixel y,x translations
 * computation is 1-based and depends on the current font's size.
 * exception: XTOCOL as defined is 0-based, because that's what its
 * clients seem to need.
 */
#define ROWTOY(wb, row)  ((row - 1) * LEADING(wb) + ASCENT(wb))
#define COLTOX(wb, col)  ((col - 1) * FWIDTH(wb))
#define YTOROW(wb, y)    (((y) - ASCENT(w)) /  LEADING(wb) + 1)
#define XTOCOL(w,x)  (!FWIDTH(w) ? (x) : ((x) / FWIDTH(w)))

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
   HDC pixdc = CreatePixDC(w, stddc);

#define STDFONT \
   { if(stdwin)SelectObject(stddc, wc->font->font); SelectObject(pixdc,wc->font->font); }

#define FREE_STDLOCALS(w) do { SelectObject(pixdc, (w)->window->theOldPix); ReleaseDC((w)->window->iconwin, stddc); DeleteDC(pixdc); } while (0)

#define glXSwapBuffers(foo, bar) { \
HDC stddc = CreateWinDC(w);\
         SwapBuffers(stddc);\
ReleaseDC(w->window->iconwin, stddc);\
}

#ifndef WM_MOUSEWHEEL
#define WM_MOUSEWHEEL 0x20A
#endif
