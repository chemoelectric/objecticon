/*
 * graphics.h - macros and types used in Icon's graphics interface.
 */

#if XWindows
   #include "../h/xwin.h"
#endif					/* XWindows */

#if MSWIN32
   #include "../h/mswin.h"
#endif					/* MSWIN32 */

#ifndef MAXXOBJS
   #define MAXXOBJS 256
#endif					/* MAXXOBJS */

#ifndef DMAXCOLORS
   #define DMAXCOLORS 256
#endif					/* DMAXCOLORS */

#ifndef MAXCOLORNAME
   #define MAXCOLORNAME 40
#endif					/* MAXCOLORNAME */

#ifndef MAXFONTWORD
   #define MAXFONTWORD 40
#endif					/* MAXFONTWORD */

#define DEFAULTFONTSIZE 14

#define FONTATT_SPACING		0x01000000
#define FONTFLAG_MONO		0x00000001
#define FONTFLAG_PROPORTIONAL	0x00000002

#define FONTATT_SERIF		0x02000000
#define FONTFLAG_SANS		0x00000004
#define FONTFLAG_SERIF		0x00000008

#define FONTATT_SLANT		0x04000000
#define FONTFLAG_ROMAN		0x00000010
#define FONTFLAG_ITALIC		0x00000020
#define FONTFLAG_OBLIQUE	0x00000040

#define FONTATT_WEIGHT		0x08000000
#define FONTFLAG_LIGHT		0x00000100
#define FONTFLAG_MEDIUM		0x00000200
#define FONTFLAG_DEMI		0x00000400
#define FONTFLAG_BOLD		0x00000800

#define FONTATT_WIDTH		0x10000000
#define FONTFLAG_CONDENSED	0x00001000
#define FONTFLAG_NARROW		0x00002000
#define FONTFLAG_NORMAL		0x00004000
#define FONTFLAG_WIDE		0x00008000
#define FONTFLAG_EXTENDED	0x00010000

#define FONTATT_CHARSET		0x20000000
#define FONTFLAG_LATIN1		0x00020000
#define FONTFLAG_LATIN2		0x00040000
#define FONTFLAG_CYRILLIC	0x00080000
#define FONTFLAG_ARABIC		0x00100000
#define FONTFLAG_GREEK		0x00200000
#define FONTFLAG_HEBREW		0x00400000
#define FONTFLAG_LATIN6		0x00800000

/*
 * EVENT HANDLING
 *
 * Each window keeps an associated queue of events waiting to be
 * processed.  The queue consists of <eventcode,x,y> triples,
 * where eventcodes are strings for normal keyboard events, and
 * integers for mouse and special keystroke events.
 *
 * The main queue is an icon list.  In addition, there is a queue of
 * old keystrokes maintained for cooked mode operations, maintained
 * in a little circular array of chars.
 */
#define EQ_MOD_CONTROL (1L<<16L)
#define EQ_MOD_META    (1L<<17L)
#define EQ_MOD_SHIFT   (1L<<18L)
#define EQ_MOD_RELEASE (1L<<19L)


/*
 * mode bits for the Icon window context (as opposed to X context)
 */

#define ISINITIAL(w)    ((w)->window->bits & 1)
#define ISINITIALW(ws)   ((ws)->bits & 1)
/* bit 4 is available */
#define ISXORREVERSE(w)	((w)->context->bits & 16)
#define ISXORREVERSEW(w) ((w)->bits & 16)
#define ISRESIZABLE(w)	((w)->window->bits & 128)
#define ISEXPOSED(w)    ((w)->window->bits & 256)

/* bit 4 is available */
#define SETXORREVERSE(w) ((w)->context->bits |= 16)
#define SETRESIZABLE(w)	((w)->window->bits |= 128)
#define SETEXPOSED(w)   ((w)->window->bits |= 256)
/* bit 4 is available */
#define CLRXORREVERSE(w) ((w)->context->bits &= ~16)
#define CLRRESIZABLE(w)	((w)->window->bits &= ~128)
#define CLREXPOSED(w)   ((w)->window->bits &= ~256)

#define ISTOBEHIDDEN(ws)  ((ws)->bits & 4096)
#define SETTOBEHIDDEN(ws)  ((ws)->bits |= 4096)
#define CLRTOBEHIDDEN(ws)  ((ws)->bits &= ~4096)

#if XWindows
#define ISZOMBIE(w)     ((w)->window->bits & 1)
#define SETZOMBIE(w)    ((w)->window->bits |= 1)
#define CLRZOMBIE(w)    ((w)->window->bits &= ~1)
#endif					/* XWindows */

#define ISTITLEBAR(ws) ((ws)->bits & 8192)
#define SETTITLEBAR(ws) ((ws)->bits |= 8192)
#define CLRTITLEBAR(ws) ((ws)->bits &= ~8192)

#define DEFAULT_WINDOW_LABEL "Object Icon"

/*
 * Window Resources
 * Icon "Resources" are a layer on top of the window system resources,
 * provided in order to facilitate resource sharing and minimize the
 * number of calls to the window system.  Resources are reference counted.
 * These data structures are simple sets of pointers
 * into internal window system structures.
 */


/*
 * Fonts are allocated within displays.
 */
typedef struct _wfont {
  int		refcount;
  int		serial;			/* serial # */
  struct _wfont *previous, *next;
  char	        *name;			/* name for WAttrib and fontsearch */
  int           ascent;                 /* font dimensions */
  int           descent;
  int		height;			
  int           maxwidth;               /* max width of one char */
#if XWindows
#ifdef HAVE_LIBXFT
  XftFont     * fsp;
#else
  XFontStruct *	fsp;			/* X font pointer */
#endif /* HAVE_LIBXFT */
#endif					/* XWindows */
#if MSWIN32
  HFONT		font;
#endif					/* MSWIN32 */
} wfont, *wfp;

#define ASCENT(w) ((w)->context->font->ascent)
#define DESCENT(w) ((w)->context->font->descent)
#define FHEIGHT(w) ((w)->context->font->height)
#define FWIDTH(w) ((w)->context->font->maxwidth)

/*
 * These structures and definitions are used for colors and images.
 */
typedef struct {
   long red, green, blue;		/* color components, linear 0 - 65535*/
   } LinearColor;

struct palentry {			/* entry for one palette member */
   LinearColor clr;			/* RGB value of color */
   char used;				/* nonzero if char is used */
   char valid;				/* nonzero if entry is valid & opaque */
   char transpt;			/* nonzero if char is transparent */
   };

struct imgdata {			/* image loaded from a file */
   int width, height;			/* image dimensions */
   struct palentry *paltbl;		/* pointer to palette table */
   unsigned char *data;			/* pointer to image data */
   };

struct imgmem {
   int x, y, width, height;
#if XWindows
   XImage *im;
#endif					/* XWindows */
#if MSWIN32
   COLORREF *crp;
#endif					/* MSWIN32 */
   };

#define TCH1 '~'			/* usual transparent character */
#define TCH2 0377			/* alternate transparent character */
#define PCH1 ' '			/* punctuation character */
#define PCH2 ','			/* punctuation character */


#if XWindows

/*
 * Displays are maintained in a global list in rwinrsc.r.
 */
typedef struct _wdisplay {
  int		refcount;
  int		serial;			/* serial # */
  char		name[MAXDISPLAYNAME];
  Display *	display;
  struct progstate *program;           /* owning program */
  GC		icongc;
  Colormap	cmap;
  double	gamma;
  int		screen;
  int		numFonts;
  wfp		fonts;
#ifdef HAVE_LIBXFT
  XFontStruct   *xfont;
#endif
  int           numColors;		/* allocated color info */
  int		sizColors;		/* # elements of alloc. color array */
  struct wcolor	*colors;
  Cursor	cursors[NUMCURSORSYMS];
  struct _wdisplay *previous, *next;
} *wdp;
#endif					/* XWindows */

/*
 * Texture management requires that we be able to lookup and reuse
 * existing textures, as well as support dynamic window-based textures.
 */

/*
 * "Context" comprises the graphics context, and the font (i.e. text context).
 * Foreground and background colors (pointers into the display color table)
 * are stored here to reduce the number of window system queries.
 * Contexts are allocated out of a global array in rwinrsrc.c.
 */
typedef struct _wcontext {
  int		refcount;
  int		serial;			/* serial # */
  struct _wcontext *previous, *next;
  int		clipx, clipy, clipw, cliph;
  wfp		font;
  int		dx, dy;
  double	gamma;			/* gamma correction value */
  int		bits;			/* context bits */
#if XWindows
  wdp		display;
  GC		gc;			/* X graphics context */
  int		fg, bg;
  int		linestyle;
  int		linewidth;
  int		leading;		/* inter-line leading */
  char		*patternname;
  int		fillstyle;
  int		drawop;
#endif					/* XWindows */
#if MSWIN32
  LOGPEN	pen;
  LOGPEN	bgpen;
  LOGBRUSH	brush;
  LOGBRUSH	bgbrush;
  HRGN          cliprgn;
  HBITMAP	pattern;
  SysColor	fg, bg;
  char		*patternname, *fgname, *bgname;
  int		leading, bkmode;
  int		fillstyle;
  int		drawop;
#endif					/* MSWIN32*/

} wcontext, *wcp;

/*
 * Native facilities include the following child controls (windows) that
 * persist on the canvas and intercept various events.
 */
#if MSWIN32
#define CHILD_BUTTON 0
#define CHILD_SCROLLBAR 1
#define CHILD_EDIT 2
typedef struct childcontrol {
   int  type;				/* what kind of control? */
   HWND win;				/* child window handle */
   HFONT font;
   char *id;				/* child window string id */
} childcontrol;
#endif					/* MSWIN32 */

/*
 * "Window state" includes the actual X window and references to a large
 * number of resources allocated on a per-window basis.  Windows are
 * allocated out of a global array in rwinrsrc.c.  Windows remember the
 * first WMAXCOLORS colors they allocate, and deallocate them on clearscreen.
 */
typedef struct _wstate {
  int		refcount;		/* reference count */
  int		serial;			/* serial # */
  struct _wstate *previous, *next;
  int		inputmask;		/* user input mask */
  char		*windowlabel;		/* window label */
  struct imgdata initimage;		/* initial image data */
  int		posy, posx;		/* desired upper lefthand corner */
  int           height;                 /* window height, in pixels */
  int           width;                  /* window width, in pixels */
  int           minheight;              /* minimum window height, in pixels */
  int           minwidth;               /* minimum window width, in pixels */
  int           maxheight;              /* maximum window height, in pixels */
  int           maxwidth;               /* maximum window width, in pixels */
  int		bits;			/* window bits */
  word		timestamp;		/* last event time stamp */
  struct descrip listp;		        /* event list for this window */
#if XWindows
  wdp		display;
  Window	win;			/* X window */
  Pixmap	pix;			/* current screen state */
  Pixmap	initialPix;		/* an initial image to display */
  Window        iconwin;		/* icon window */
  Pixmap	iconpix;		/* icon pixmap */
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  Visual	*vis;
  int		theCursor;		/* index into cursor table */
#ifdef HAVE_LIBXFT
  XftDraw       *winDraw,*pixDraw;
#endif
  int		normalx, normaly;	/* pos to remember when maximized */
  int		normalw, normalh;	/* size to remember when maximized */
  int           numColors;		/* allocated (used) color info */
  int           sizColors;		/* malloced size of theColors */
  short		*theColors;		/* indices into display color table */
  int           numiColors;		/* allocated color info for the icon */
  int           siziColors;		/* malloced size of iconColors */
  short		*iconColors;		/* indices into display color table */
  int		iconic;			/* window state; icon, window or root*/
  int		iconx, icony;           /* location of icon */
  int    	iconw, iconh;		/* width and height of icon */
  long		wmhintflags;		/* window manager hints */
  char		*iconimage;		/* icon pixmap file name */
  struct imgdata initicon;		/* initial icon image data */
  char		*iconlabel;		/* icon label */
#endif					/* XWindows */
#if MSWIN32
  HWND		win;			/* client window */
  HWND		iconwin;		/* client window when iconic */
  HBITMAP	pix;			/* backing bitmap */
  HBITMAP	iconpix;		/* backing bitmap */
  HBITMAP	initialPix;		/* backing bitmap */
  HBITMAP	theOldPix;
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  HCURSOR	curcursor;
  HCURSOR	savedcursor;
  char		*cursorname;
  HMENU		menuBar;
  int		nmMapElems;
  char **       menuMap;
  HWND		focusChild;
  int           nChildren;
  childcontrol *child;
#endif					/* MSWIN32 */
} wstate, *wsp;

/*
 * Icon window file variables are actually pointers to "bindings"
 * of a window and a context.  They are allocated out of a global
 * array in rwinrsrc.c.  There is one binding per Icon window value.
 */
typedef struct _wbinding {
  int refcount;
  int serial;
  struct _wbinding *previous, *next;
  wcp context;
  wsp window;
} wbinding, *wbp;

struct wbind_list {
  struct _wbinding *child;
  struct wbind_list *next;
};


/*
 * Gamma Correction value to compensate for nonlinear monitor color response
 */
#ifndef GammaCorrection
#define GammaCorrection 2.5
#endif					/* GammaCorrection */

/*
 * Flags to doconfig()
 */
#define C_POS           1
#define C_SIZE          2
#define C_MINSIZE       4
#define C_MAXSIZE       8
#define C_RESIZE	16
#define C_CLIP	        32
#define C_IMAGE	        64


#define XICONSLEEP	20 /* milliseconds */
