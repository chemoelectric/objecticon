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
#define XLFD_AverageWidth 12
#define XLFD_CharSet	13

#define RootState IconicState+1
#define MaximizedState IconicState+2
#define HiddenState IconicState+3
#define PopupState IconicState+4
#define FullScreenState IconicState+5

#define MAXDISPLAYNAME	64
#define NUMCURSORSYMS	78

/* Interned atoms array */
#define NUMATOMS        18
#define ATOM_CHARACTER_POSITION    0
#define ATOM_CLIENT_WINDOW         1
#define ATOM_HOSTNAME              2
#define ATOM_HOST_NAME             3
#define ATOM_LENGTH                4
#define ATOM_LIST_LENGTH           5
#define ATOM_NAME                  6
#define ATOM_OWNER_OS              7
#define ATOM_SPAN                  8
#define ATOM_TARGETS               9
#define ATOM_TIMESTAMP            10
#define ATOM_USER                 11
#define ATOM_WM_DELETE_WINDOW     12
#define ATOM__OBJECTICON_PROP     13
#define ATOM__NET_WM_STATE_MAXIMIZED_VERT 14
#define ATOM__NET_WM_STATE_MAXIMIZED_HORZ 15
#define ATOM__NET_WM_STATE_FULLSCREEN     16
#define ATOM__NET_WM_STATE                17

#define _NET_WM_STATE_ADD            1
#define _NET_WM_STATE_REMOVE         0

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

struct SharedColor {
   int r, g, b;         /* rgb of c */
   unsigned long c;     /* X pixel value */
   char  *name;
   int   refcount;
};



#endif                                  /* XWindows */
