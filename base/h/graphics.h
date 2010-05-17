/*
 * graphics.h - macros and types used in Icon's graphics interface.
 */

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

#if XWindows
   #include "../h/xwin.h"
#elif MSWIN32
   #include "../h/mswin.h"
#elif PLAN9
   #include "../h/p9win.h"
#endif

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
 * Here are the events we support (in addition to keyboard characters)
 */
#define MOUSELEFT	(-1)
#define MOUSEMID	(-2)
#define MOUSERIGHT	(-3)
#define MOUSELEFTUP	(-4)
#define MOUSEMIDUP	(-5)
#define MOUSERIGHTUP	(-6)
#define MOUSELEFTDRAG	(-7)
#define MOUSEMIDDRAG	(-8)
#define MOUSERIGHTDRAG	(-9)
#define RESIZED		(-10)
#define WINDOWCLOSED    (-11)
#define MOUSEMOVED      (-12)
#define MOUSE4          (-13)
#define MOUSE5          (-14)
#define MOUSE4UP        (-16)
#define MOUSE5UP        (-17)
#define SELECTIONREQUEST   (-30)
#define SELECTIONCLEAR     (-31)
#define SELECTIONRESPONSE  (-32)
#define INVOKELATER     (-40)

/*
 * mode bits for the Icon window context (as opposed to X context)
 */

#define ISINITIAL(w)    ((w)->window->bits & 1)
#define ISINITIALW(ws)   ((ws)->bits & 1)
/* bit 4 is available */
#define ISRESIZABLE(w)	((w)->window->bits & 128)
#define ISEXPOSED(w)    ((w)->window->bits & 256)

/* bit 4 is available */
#define SETRESIZABLE(w)	((w)->window->bits |= 128)
#define SETEXPOSED(w)   ((w)->window->bits |= 256)
/* bit 4 is available */
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
#elif PLAN9
  Font          *font;
#elif MSWIN32
  HFONT		font;
#endif
} wfont, *wfp;

#define ASCENT(w) ((w)->context->font->ascent)
#define DESCENT(w) ((w)->context->font->descent)
#define FHEIGHT(w) ((w)->context->font->height)
#define FWIDTH(w) ((w)->context->font->maxwidth)

/*
 * These structures and definitions are used for colors and images.
 */
typedef struct {
   int red, green, blue;		/* color components, linear 0 - 65535*/
   } LinearColor;

struct palentry {			/* entry for one palette member */
   LinearColor clr;			/* RGB value of color */
   char used;				/* nonzero if char is used */
   char valid;				/* nonzero if entry is valid & opaque */
   char transpt;			/* nonzero if char is transparent */
   };

#define IMGDATA_RGB24      1
#define IMGDATA_RGBA32     2
#define IMGDATA_RGB48      3
#define IMGDATA_RGBA64     4
#define IMGDATA_PALETTE    5

struct imgdata {			/* image loaded from a file */
   int width, height;			/* image dimensions */
   struct palentry *paltbl;		/* pointer to palette table */
   int format;                          /* format of data, if palette is nil */
   unsigned char *data;			/* pointer to image data */
   };

struct imgmem {
   int x, y, width, height;             /* Pos/dimensions of rectangle being got/set */
   int xoff, yoff;                      /* Increasing x,y offset within rectangle during looping */
#if XWindows
   XImage *im;
#elif PLAN9
   Image *im;
   uchar *data;
   int len;
#elif MSWIN32
   COLORREF *crp;
#endif
   };

#define TCH1 '~'			/* usual transparent character */
#define TCH2 0377			/* alternate transparent character */

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
  struct SharedColor *black, *white;
  Colormap	cmap;
  int		screen;
  wfp		fonts;
#ifdef HAVE_LIBXFT
  XFontStruct   *xfont;
#endif
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
  int		bits;			/* context bits */
#if XWindows
  wdp		display;
  GC		gc;			/* X graphics context */
  struct SharedColor *fg, *bg;
  stringint     *linestyle;
  int		linewidth;
  char		*patternname;
  stringint     *fillstyle;
  stringint     *drawop;
#elif PLAN9
  struct SharedColor *fg, *bg;
  struct SharedPattern  *pattern;
  int           thick;
  stringint     *fillstyle;
  stringint     *drawop;
  stringint     *linestyle;
#elif MSWIN32
  LOGPEN	pen;
  LOGPEN	bgpen;
  LOGBRUSH	brush;
  LOGBRUSH	bgbrush;
  HRGN          cliprgn;
  HBITMAP	pattern;
  SysColor	fg, bg;
  char		*patternname, *fgname, *bgname;
  int		bkmode;
  int		fillstyle;
  int		drawop;
#endif

} wcontext, *wcp;


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
  int		y, x;		        /* desired upper lefthand corner */
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
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  Visual	*vis;
  stringint     *cursor;
#ifdef HAVE_LIBXFT
  XftDraw       *winDraw,*pixDraw;
#endif
  int		normalx, normaly;	/* pos to remember when maximized */
  int		normalw, normalh;	/* size to remember when maximized */
  int		iconic;			/* window state; icon, window or root*/
  Window        transientfor;           /* transient-for hint */
  long		wmhintflags;		/* window manager hints */
#elif PLAN9
  Image         *win;
  Screen        *screen;
  Image         *pix;
  char          mount_dir[64];
  int           event_pipe[2];
  int           wsys_fd, wctl_fd, mouse_fd, cons_fd, consctl_fd, cursor_fd,
                   mouse_time_fd, cons_time_fd;
  int           mouse_pid, cons_pid;
  int           mouse_down;
  int           last_mouse_x, last_mouse_y;
  int           desired_canvas;
  stringint     *cursor;
  int           using_win;
#elif MSWIN32
  HWND		win;			/* client window */
  HWND		iconwin;		/* client window when iconic */
  HBITMAP	pix;			/* backing bitmap */
  HBITMAP	iconpix;		/* backing bitmap */
  HBITMAP	theOldPix;
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  HCURSOR	curcursor;
  HCURSOR	savedcursor;
  char		*cursorname;
#endif
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
