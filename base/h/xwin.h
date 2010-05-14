#if XWindows

#define DRAWOP_AND			GXand
#define DRAWOP_ANDINVERTED		GXandInverted
#define DRAWOP_ANDREVERSE		GXandReverse
#define DRAWOP_CLEAR			GXclear
#define DRAWOP_COPY			GXcopy
#define DRAWOP_COPYINVERTED		GXcopyInverted
#define DRAWOP_EQUIV			GXequiv
#define DRAWOP_INVERT			GXinvert
#define DRAWOP_NAND			GXnand
#define DRAWOP_NOOP			GXnoop
#define DRAWOP_NOR			GXnor
#define DRAWOP_OR			GXor
#define DRAWOP_ORINVERTED		GXorInverted
#define DRAWOP_ORREVERSE		GXorReverse
#define DRAWOP_REVERSE			0x10
#define DRAWOP_SET			GXset
#define DRAWOP_XOR			GXxor

#define XLFD_Foundry	 1
#define XLFD_Family	 2
#define XLFD_Weight	 3
#define XLFD_Slant	 4
#define XLFD_SetWidth	 5
#define XLFD_AddStyle	 6
#define XLFD_Size	 7
#define XLFD_PointSize	 8
#define XLFD_Spacing	11
#define XLFD_CharSet	13

#define SysColor XColor
#define RootState IconicState+1
#define MaximizedState IconicState+2
#define HiddenState IconicState+3
#define PopupState IconicState+4

/*
 * This macro allows the "true" X input masks to be
 * obtained from the inputmask field.
 */
#define XMasks(f)            ((f) & ((1L<<25)-1))

/*
 * The following constants define limitations in the system, gradually being
 * removed as this code is rewritten to use dynamic allocation.
 */
#define DMAXCOLORS	256
#define WMAXCOLORS	256
#define MAXCOLORNAME	40
#define MAXDISPLAYNAME	64
#define NUMCURSORSYMS	78

/*
 * Macros to ease coding in which every X call must be done twice.
 */
#define RENDER2(func,v1,v2) {\
   if (stdwin) func(stddpy, stdwin, stdgc, v1, v2); \
   func(stddpy, stdpix, stdgc, v1, v2);}
#define RENDER3(func,v1,v2,v3) {\
   if (stdwin) func(stddpy, stdwin, stdgc, v1, v2, v3); \
   func(stddpy, stdpix, stdgc, v1, v2, v3);}
#define RENDER4(func,v1,v2,v3,v4) {\
   if (stdwin) func(stddpy, stdwin, stdgc, v1, v2, v3, v4); \
   func(stddpy, stdpix, stdgc, v1, v2, v3, v4);}
#define RENDER6(func,v1,v2,v3,v4,v5,v6) {\
   if (stdwin) func(stddpy, stdwin, stdgc, v1, v2, v3, v4, v5, v6); \
   func(stddpy, stdpix, stdgc, v1, v2, v3, v4, v5, v6);}
#define RENDER7(func,v1,v2,v3,v4,v5,v6,v7) {\
   if (stdwin) func(stddpy, stdwin, stdgc, v1, v2, v3, v4, v5, v6, v7); \
   func(stddpy, stdpix, stdgc, v1, v2, v3, v4, v5, v6, v7);}


/*
 * Macros to perform direct window system calls from graphics routines
 */
#define STDLOCALS(w) \
   GC      stdgc;   \
   Display *stddpy; \
   Window  stdwin; \
   Pixmap  stdpix;\
   wcp wc = (w)->context; \
   wsp ws = (w)->window; \
   wdp wd = ws->display; \
   stdgc  = wc->gc; \
   stddpy = wd->display; \
   stdwin  = ws->win; \
   stdpix  = ws->pix;

/*
 * Colors.  These are allocated within displays; they are currently
 * statically bounded to DMAXCOLORS colors per display.  Pointers
 * into the display's color table are also kept on a per-window
 * basis so that they may be (de)allocated when a window is cleared.
 * Colors are aliased by r,g,b value.  Allocations by name and r,g,b
 * share when appropriate.
 *
 * Color (de)allocation comprises a simple majority of the space
 * requirements of the current implementation.  A monochrome-only
 * version would take a lot less space.
 *
 * The name field is the string returned by WAttrib.  For a mutable
 * color this is of the form "-47" followed by a second C string
 * containing the current color setting.
 */
typedef struct wcolor {
   int		refcount;
   char		name[6+MAXCOLORNAME];	/* name for WAttrib & WColor reads */
   unsigned short r, g, b;		/* rgb for colorsearch */
   unsigned long	c;		/* X pixel value */
} *wclrp;



#endif					/* XWindows */
