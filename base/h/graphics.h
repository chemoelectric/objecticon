/*
 * graphics.h - macros and types used in Icon's graphics interface.
 */

#ifdef XWindows
   #include "../h/xwin.h"
#endif					/* XWindows */

#ifdef MSWindows
   #include "../h/mswin.h"
#endif					/* MSWindows */

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

#define EVQUESUB(w,i) *evquesub(w,i)
#define EQUEUELEN 256

/*
 * mode bits for the Icon window context (as opposed to X context)
 */

#define ISINITIAL(w)    ((w)->window->bits & 1)
#define ISINITIALW(ws)   ((ws)->bits & 1)
/* bit 4 is available */
#define ISREVERSE(w)    ((w)->context->bits & 8)
#define ISXORREVERSE(w)	((w)->context->bits & 16)
#define ISXORREVERSEW(w) ((w)->bits & 16)
#define ISCLOSED(w)	((w)->window->bits & 64)
#define ISRESIZABLE(w)	((w)->window->bits & 128)
#define ISEXPOSED(w)    ((w)->window->bits & 256)

/* bit 4 is available */
#define SETREVERSE(w)   ((w)->context->bits |= 8)
#define SETXORREVERSE(w) ((w)->context->bits |= 16)
#define SETCLOSED(w)	((w)->window->bits |= 64)
#define SETRESIZABLE(w)	((w)->window->bits |= 128)
#define SETEXPOSED(w)   ((w)->window->bits |= 256)
/* bit 4 is available */
#define CLRREVERSE(w)   ((w)->context->bits &= ~8)
#define CLRXORREVERSE(w) ((w)->context->bits &= ~16)
#define CLRCLOSED(w)	((w)->window->bits &= ~64)
#define CLRRESIZABLE(w)	((w)->window->bits &= ~128)
#define CLREXPOSED(w)   ((w)->window->bits &= ~256)

#ifdef XWindows
#define ISZOMBIE(w)     ((w)->window->bits & 1)
#define SETZOMBIE(w)    ((w)->window->bits |= 1)
#define CLRZOMBIE(w)    ((w)->window->bits &= ~1)
#endif					/* XWindows */

#ifdef MSWindows
#define ISTOBEHIDDEN(ws)  ((ws)->bits & 4096)
#define SETTOBEHIDDEN(ws)  ((ws)->bits |= 4096)
#define CLRTOBEHIDDEN(ws)  ((ws)->bits &= ~4096)
#endif					/* MSWindows */

#define ISTITLEBAR(ws) ((ws)->bits & 8192)
#define SETTITLEBAR(ws) ((ws)->bits |= 8192)
#define CLRTITLEBAR(ws) ((ws)->bits &= ~8192)


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
#ifdef XWindows
  char	      *	name;			/* name for WAttrib and fontsearch */
  int           ascent;                 /* font dimensions */
  int           descent;
  int		height;			
  int           maxwidth;               /* max width of one char */
#ifdef HAVE_LIBXFT
  XftFont     * fsp;
#else
  XFontStruct *	fsp;			/* X font pointer */
#endif /* HAVE_LIBXFT */
#endif					/* XWindows */
#ifdef MSWindows
  char		*name;			/* name for WAttrib and fontsearch */
  HFONT		font;
  LONG		ascent;
  LONG		descent;
  LONG		charwidth;
  LONG		height;
#endif					/* MSWindows */
} wfont, *wfp;

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
#ifdef XWindows
   XImage *im;
#endif					/* XWindows */
#ifdef MSWindows
   COLORREF *crp;
#endif					/* MSWindows */
   };

#define TCH1 '~'			/* usual transparent character */
#define TCH2 0377			/* alternate transparent character */
#define PCH1 ' '			/* punctuation character */
#define PCH2 ','			/* punctuation character */


#ifdef XWindows

/*
 * Displays are maintained in a global list in rwinrsc.r.
 */
typedef struct _wdisplay {
  int		refcount;
  int		serial;			/* serial # */
  char		name[MAXDISPLAYNAME];
  Display *	display;
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
  char		*patternname;
  wfp		font;
  int		dx, dy;
  int		fillstyle;
  int		drawop;
  double	gamma;			/* gamma correction value */
  int		bits;			/* context bits */
#ifdef XWindows
  wdp		display;
  GC		gc;			/* X graphics context */
  int		fg, bg;
  int		linestyle;
  int		linewidth;
  int		leading;		/* inter-line leading */
#endif					/* XWindows */
#ifdef MSWindows
  LOGPEN	pen;
  LOGPEN	bgpen;
  LOGBRUSH	brush;
  LOGBRUSH	bgbrush;
  HRGN          cliprgn;
  HBITMAP	pattern;
  SysColor	fg, bg;
  char		*fgname, *bgname;
  int		leading, bkmode;
#endif					/* MSWindows*/

} wcontext, *wcp;

/*
 * Native facilities include the following child controls (windows) that
 * persist on the canvas and intercept various events.
 */
#ifdef MSWindows
#define CHILD_BUTTON 0
#define CHILD_SCROLLBAR 1
#define CHILD_EDIT 2
typedef struct childcontrol {
   int  type;				/* what kind of control? */
   HWND win;				/* child window handle */
   HFONT font;
   char *id;				/* child window string id */
} childcontrol;
#endif					/* MSWindows */

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
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  char		*windowlabel;		/* window label */
  char		*iconimage;		/* icon pixmap file name */
  char		*iconlabel;		/* icon label */
  struct imgdata initimage;		/* initial image data */
  struct imgdata initicon;		/* initial icon image data */
  int		pointery,pointerx;	/* current mouse location, in pixels */
  int		posy, posx;		/* desired upper lefthand corner */
  unsigned int	height;			/* window height, in pixels */
  unsigned int	width;			/* window width, in pixels */
  unsigned int	minheight;		/* minimum window height, in pixels */
  unsigned int	minwidth;		/* minimum window width, in pixels */
  struct descrip selectionproc;         /* callback procedure for getting/clearing selection */
  int		bits;			/* window bits */
  int		theCursor;		/* index into cursor table */
  word		timestamp;		/* last event time stamp */
  char		eventQueue[EQUEUELEN];  /* queue of cooked-mode keystrokes */
  int		eQfront, eQback;
  char		*cursorname;
  struct descrip listp;		/* icon values for this window */
#ifdef XWindows
  wdp		display;
  Window	win;			/* X window */
  Pixmap	pix;			/* current screen state */
  Pixmap	initialPix;		/* an initial image to display */
  Window        iconwin;		/* icon window */
  Pixmap	iconpix;		/* icon pixmap */
  Visual	*vis;
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
  char *selectiondata;
  int		iconic;			/* window state; icon, window or root*/
  int		iconx, icony;           /* location of icon */
  unsigned int	iconw, iconh;		/* width and height of icon */
  long		wmhintflags;		/* window manager hints */
#endif					/* XWindows */
#ifdef MSWindows
  HWND		win;			/* client window */
  HWND		iconwin;		/* client window when iconic */
  HBITMAP	pix;			/* backing bitmap */
  HBITMAP	iconpix;		/* backing bitmap */
  HBITMAP	initialPix;		/* backing bitmap */
  HBITMAP	theOldPix;
  int		hasCaret;
  HCURSOR	curcursor;
  HCURSOR	savedcursor;
  HMENU		menuBar;
  int		nmMapElems;
  char **       menuMap;
  HWND		focusChild;
  int           nChildren;
  childcontrol *child;
#endif					/* MSWindows */
  int            no;          /* new field added for child windows */
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
 * Attributes
 */

#define A_ASCENT	1
#define A_BG		2
#define A_CANVAS	3
#define A_CLIPH		4
#define A_CLIPW		5
#define A_CLIPX		6
#define A_CLIPY		7
#define A_DEPTH		8 
#define A_DESCENT	9 
#define A_DISPLAY	10
#define A_DISPLAYHEIGHT	11
#define A_DISPLAYWIDTH	12
#define A_DRAWOP	13
#define A_DX		14
#define A_DY		15
#define A_FG		16
#define A_FHEIGHT	17
#define A_FILLSTYLE	18
#define A_FONT		19
#define A_FWIDTH	20
#define A_GAMMA		21
#define A_GEOMETRY	22
#define A_HEIGHT	23
#define A_ICONIC	24
#define A_ICONIMAGE     25
#define A_ICONLABEL	26
#define A_ICONPOS	27
#define A_IMAGE		28
#define A_LABEL		29
#define A_LINESTYLE	30
#define A_LINEWIDTH	31
#define A_PATTERN	32
#define A_POINTERX	33
#define A_POINTERY	34
#define A_POINTER	35
#define A_POS		36
#define A_POSX		37
#define A_POSY		38
#define A_RESIZE	39
#define A_REVERSE	40
#define A_SIZE		41
#define A_VISUAL	42
#define A_WIDTH		43
#define A_WINDOWLABEL   44
#define A_INPUTMASK	45
#define A_TITLEBAR      46
#define A_MINSIZE	47
#define A_MINWIDTH	48
#define A_MINHEIGHT	49

#define NUMATTRIBS	49

#define XICONSLEEP	20 /* milliseconds */
