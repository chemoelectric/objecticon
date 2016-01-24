/*
 * graphics.h - macros and types used in Icon's graphics interface.
 */

/*
 * Entry in palette table.
 */
struct palentry {
   int r, g, b, a;                         /* RGBA value of color */
};

struct point {
    double x;
    double y;
};

struct triangle {
    struct point p1, p2, p3;
};

struct trapezoid {
    double top, x1, x2;
    double bottom, x3, x4;
};

#define TCH1 '~'			/* usual transparent character */
#define TCH2 0377			/* alternate transparent character */

#define MIN_FONT_SIZE 1.0

#define MAXCOLORNAME 50

#define IMGDATA_RGB24      1
#define IMGDATA_BGR24      2
#define IMGDATA_RGBA32     3
#define IMGDATA_ABGR32     4
#define IMGDATA_RGB48      5
#define IMGDATA_RGBA64     6
#define IMGDATA_G8         7
#define IMGDATA_GA16       8
#define IMGDATA_AG16       9
#define IMGDATA_G16        10
#define IMGDATA_GA32       11
#define IMGDATA_XRGB32     12
#define IMGDATA_BGRX32     13
#define IMGDATA_PALETTE1   21
#define IMGDATA_PALETTE2   22
#define IMGDATA_PALETTE4   24
#define IMGDATA_PALETTE8   28

#define Mul16(v, a) (((unsigned)(v) * (a)) / 65535)
#define Div16(v, a) (((unsigned)(v) * 65535) / (a))

#define Gray(r, g, b) (0.299 * (r) + 0.587 * (g) + 0.114 * (b))
#define IntGray(r, g, b) ((int)(Gray(r, g, b) + 0.5))

struct imgdata;

struct imgdataformat {
    void (*setpixel)(struct imgdata *imd, int x, int y, int r, int g, int b, int a);
    void (*getpixel)(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a);
    void (*setpaletteindex)(struct imgdata *imd, int x, int y, int i);
    int (*getpaletteindex)(struct imgdata *imd, int x, int y);
    int (*getlength)(struct imgdata *imd);
    int alpha_depth, color_depth, palette_size;
    char *name;
    struct imgdataformat *next;      /* Used for hashing */
};

extern struct imgdataformat imgdataformat_A8;
extern struct imgdataformat imgdataformat_A16;
extern struct imgdataformat imgdataformat_RGB24;
extern struct imgdataformat imgdataformat_BGR24;
extern struct imgdataformat imgdataformat_RGBA32;
extern struct imgdataformat imgdataformat_ABGR32;
extern struct imgdataformat imgdataformat_RGB48;
extern struct imgdataformat imgdataformat_RGBA64;
extern struct imgdataformat imgdataformat_G8;
extern struct imgdataformat imgdataformat_GA16;
extern struct imgdataformat imgdataformat_AG16;
extern struct imgdataformat imgdataformat_G16;
extern struct imgdataformat imgdataformat_GA32;
extern struct imgdataformat imgdataformat_PALETTE1;
extern struct imgdataformat imgdataformat_PALETTE2;
extern struct imgdataformat imgdataformat_PALETTE4;
extern struct imgdataformat imgdataformat_PALETTE8;

extern struct sdescrip pixclassname;

struct imgdata {			/* image data */
    int refcount;
    int width, height;			/* image dimensions */
    struct palentry *paltbl;		/* pointer to palette table, or null */
    struct imgdataformat *format;       /* format of data */
    unsigned char *data;	        /* pointer to image data */
   };


#if Graphics

extern struct sdescrip wclassname;

#if XWindows
#define RootState IconicState+1
#define MaximizedState IconicState+2
#define HiddenState IconicState+3
#define PopupState IconicState+4
#define FullScreenState IconicState+5

#define EndDisc 1
#define EndSquare 2

/* Interned atoms array */
#define NUMATOMS        30
#define ATOM_CHARACTER_POSITION            0
#define ATOM_CLIENT_WINDOW                 1
#define ATOM_CLIPBOARD                     2
#define ATOM_HOSTNAME                      3
#define ATOM_HOST_NAME                     4
#define ATOM_LENGTH                        5
#define ATOM_LIST_LENGTH                   6
#define ATOM_NAME                          7
#define ATOM_OWNER_OS                      8
#define ATOM_SPAN                          9
#define ATOM_TARGETS                      10
#define ATOM_TIMESTAMP                    11
#define ATOM_USER                         12
#define ATOM_WM_DELETE_WINDOW             13
#define ATOM__NET_WM_STATE_MAXIMIZED_VERT 14
#define ATOM__NET_WM_STATE_MAXIMIZED_HORZ 15
#define ATOM__NET_WM_STATE_FULLSCREEN     16
#define ATOM__NET_WM_STATE                17
#define ATOM__NET_WM_ICON                 18
#define ATOM__NET_WM_NAME                 19
#define ATOM_UTF8_STRING                  20
#define ATOM_WM_STATE                     21
#define ATOM__OBJECTICON_PROP0            22
#define ATOM__OBJECTICON_PROP1            23
#define ATOM__OBJECTICON_PROP2            24
#define ATOM__OBJECTICON_PROP3            25
#define ATOM__OBJECTICON_PROP4            26
#define ATOM__OBJECTICON_PROP5            27
#define ATOM__OBJECTICON_PROP6            28
#define ATOM__OBJECTICON_PROP7            29

#define _NET_WM_STATE_ADD            1
#define _NET_WM_STATE_REMOVE         0

extern struct imgdataformat imgdataformat_X11ARGB32;
extern struct imgdataformat imgdataformat_X11BGRA32;
#endif

#ifndef MAXFONTWORD
   #define MAXFONTWORD 40
#endif					/* MAXFONTWORD */

#define FONTATT_SPACING         0x01000000
#define FONTFLAG_MONO           0x00000001
#define FONTFLAG_PROPORTIONAL   0x00000002

#define FONTATT_SERIF           0x02000000
#define FONTFLAG_SANS           0x00000004
#define FONTFLAG_SERIF          0x00000008

#define FONTATT_SLANT           0x04000000
#define FONTFLAG_ROMAN          0x00000010
#define FONTFLAG_ITALIC         0x00000020
#define FONTFLAG_OBLIQUE        0x00000040

#define FONTATT_WEIGHT          0x08000000
#define FONTFLAG_LIGHT          0x00000100
#define FONTFLAG_MEDIUM         0x00000200
#define FONTFLAG_DEMI           0x00000400
#define FONTFLAG_BOLD           0x00000800

#define FONTATT_WIDTH           0x10000000
#define FONTFLAG_CONDENSED      0x00001000
#define FONTFLAG_NARROW         0x00002000
#define FONTFLAG_NORMAL         0x00004000
#define FONTFLAG_WIDE           0x00008000
#define FONTFLAG_EXTENDED       0x00010000

/*
 * Here are the events we support (in addition to keyboard characters)
 */
#define MOUSELEFT	(-1)
#define MOUSEMID	(-2)
#define MOUSERIGHT	(-3)
#define MOUSELEFTUP	(-4)
#define MOUSEMIDUP	(-5)
#define MOUSERIGHTUP	(-6)
#define WINDOWSTATE	(-8)
#define WINDOWMOVED	(-9)
#define WINDOWRESIZED	(-10)
#define WINDOWCLOSED    (-11)
#define MOUSEMOVED      (-12)
#define MOUSE4          (-13)
#define MOUSE5          (-14)
#define MOUSE4UP        (-16)
#define MOUSE5UP        (-17)
#define MOUSEENTERED    (-18)
#define MOUSEEXITED     (-19)
#define MOUSEDRAG       (-20)
#define SELECTIONREQUEST   (-30)
#define SELECTIONCLEAR     (-31)
#define SELECTIONRESPONSE  (-32)
#define INVOKELATER     (-40)

/*
 * mode bits for the Icon window context (as opposed to X context)
 */

#if MSWIN32

struct SharedColor {
   gb_Color color;
   char  *name;
   int   refcount;
};

struct SharedBitmap {
   gb_Bitmap *bitmap;
   int refcount;
};

struct SharedCursor {
   HCURSOR cursor;
   int refcount;
};

struct wcursor {
   struct wcursor *next;
   char *name;
   struct SharedCursor *shared_cursor;
};
#endif

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
  struct _wfont *next;
  char	        *name;			/* name for WAttrib and fontsearch */
  int           ascent;                 /* font dimensions */
  int           descent;
  int           maxwidth;               /* max width of one char */
#if XWindows
  XftFont     * fsp;
#elif PLAN9
  Font          *font;
#elif MSWIN32
  gb_Font	*font;
#endif
} wfont, *wfp;

#if XWindows

#define FONTHASH_SIZE 64
#define CURSORHASH_SIZE 128

/*
 * Displays are maintained in a global list in rwinrsc.r.
 */
typedef struct _wdisplay {
  char		*name;
  Display *	display;
  struct _wbinding *wbndngs;          /* List of current window bindings */
  struct _wstate *vwstates;           /* List of windows with win non-null */
  struct imgdataformat *format;                /* imgdata format */
  struct progstate *program;           /* owning program */
  struct SharedColor *black, *white, *transparent;
  wfp		fonts[FONTHASH_SIZE], defaultfont;
  XRenderPictFormat *pixfmt, *winfmt, *maskfmt;
  struct wcursor *cursors[CURSORHASH_SIZE];
  Atom          atoms[NUMATOMS];      /* interned atoms */
  struct _wdisplay *previous, *next;
} *wdp;

struct SharedColor {
   wdp wd;
   XRenderColor color;
   Picture brush;
   char  *name;
   int   refcount;
};

struct SharedPicture {
   wdp wd;
   Picture i;
   Pixmap pix;
   int width, height;
   int refcount;
};

struct SharedCursor {
   wdp wd;
   Cursor cursor;
   int refcount;
};

struct wcursor {
   struct wcursor *next;
   char *name;
   struct SharedCursor *shared_cursor;
};
#elif PLAN9
struct SharedColor {
   Image *i;            /* 1x1 image representing colour rgb */
   char  *name;
   int   rgba;          /* rgba of i */
   int   refcount;
};

struct SharedImage {
   Image *i;
   int   refcount;
};

struct SharedCursor {
   struct Cursor *cursor;
   int refcount;
};

struct wcursor {
   struct wcursor *next;
   char *name;
   struct SharedCursor *shared_cursor;
};
#endif

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
  int		clipx, clipy, clipw, cliph;
  wfp		font;
  int		dx, dy;
  double        leading;
#if XWindows
  wdp		display;
  struct SharedColor *fg, *bg;
  struct SharedPicture  *pattern;
  stringint     *linestyle;
  double	linewidth;
  stringint     *drawop;
#elif PLAN9
  struct SharedColor *fg, *bg;
  struct SharedImage  *pattern;
  stringint     *linestyle;
  int           linewidth;
  stringint     *drawop;
#elif MSWIN32
  struct SharedColor *fg, *bg;
  struct SharedBitmap  *pattern;
  stringint     *linestyle;
  double         linewidth;
  stringint     *drawop;
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
  int		inputmask;		/* user input mask */
  int		y, x;		        /* desired upper lefthand corner */
  int           height;                 /* window height, in pixels */
  int           width;                  /* window width, in pixels */
  int           minheight;              /* minimum window height, in pixels */
  int           minwidth;               /* minimum window width, in pixels */
  int           maxheight;              /* maximum window height, in pixels */
  int           maxwidth;               /* maximum window width, in pixels */
  int           resizable;              /* flag, is window resizable */
  struct descrip listp;		        /* event list for this window */
  struct descrip windowlabel;		/* window label */
  int           mousestate;             /* buttons down after last mouse event */
#if XWindows
  wdp		display;
  struct _wstate *vprevious, *vnext;    /* List of states with win non-null */
  Window	win;			/* X window */
  Picture       wpic;                   /* Render extension Picture view of win */
  Pixmap	pix;			/* current screen state */
  Picture       ppic;                   /* Render extension Picture view of pix */
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  struct wcursor *cursor;               /* current cursor */
  unsigned long *icondata;              /* window icon data and length */
  int           iconlen;
  XftDraw       *pxft;
  int		state;			/* window state; icon, window or root*/
  struct _wstate *transientfor;         /* transient-for hint */
  int           propcount;              /* counter for selection requests*/
#elif PLAN9
  struct _wstate *vprevious, *vnext;    /* List of states with win non-null */
  Image         *win;
  Screen        *screen;
  Image         *pix;
  char          mount_dir[128];
  int           event_pipe[2];
  int           mouse_events, cons_events, events_read;
  char          *wsys;
  int           wsys_fd, wctl_fd, mouse_fd, cons_fd, consctl_fd, 
                wininfo_fd, screeninfo_fd, cursor_fd, label_fd;
  int           mouse_pid, cons_pid;
  int           winid;                  /* Id as per winid file */
  struct _wstate *transientfor;         /* Reference to  transient-for window */
  int           state;                  /* Current or desired window state */
  struct wcursor *cursor;               /* current cursor */
  int           using_win;
  int           border_width;
#elif MSWIN32
  struct _wstate *vprevious, *vnext;    /* List of states with win non-null */
  HWND		win;			/* client window */
  gb_Bitmap     *pix;
  int		pixheight;		/* backing pixmap height, in pixels */
  int		pixwidth;		/* pixmap width, in pixels */
  int		state;			/* window state; icon, window or root*/
  struct wcursor *cursor;               /* current cursor */
  struct _wstate *transientfor;
  HCURSOR	savedcursor;
  HWND          savedgrab;
  int           trackingmouse;          /* Set if TrackMouseEvent in use */
  int           grabbingmouse;          /* Set if SetCapture in use */
#endif
} wstate, *wsp;

typedef struct _wbinding {
  struct _wbinding *previous, *next;
  wcp context;
  wsp window;
} wbinding, *wbp;

struct filter {
   wbp w;
   struct imgdata *imd;
   void (*f)(struct filter *);
   union {
      struct {
         float mr, mb, mg, ma;
         int cr, cb, cg, ca;
      } linear;
      struct {
         int p;
      } coerce;
      struct {
         int nband, c, m;
      } shade;
   } p;
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

/*
 * Input masks
 */
#define IM_KEY_RELEASE     1
#define IM_POINTER_MOTION  2

#define MOD_SHIFT       1
#define MOD_LOCK        2
#define MOD_CTRL        4
#define MOD_META        8 
#define MOD_META2       16
#define MOD_META3       32
#define MOD_META4       64
#define MOD_META5       128
#define MOD_RELEASE     256

#endif					/* Graphics */
