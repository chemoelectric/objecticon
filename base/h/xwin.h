#ifdef XWindows

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

#ifdef HAVE_LIBXFT
#define TEXTWIDTH(w,s,n) xft_stringwidth(w, s, n)
#define UTF8WIDTH(w,s,n) xft_utf8width(w, s, n)
#else
#define TEXTWIDTH(w,s,n) XTextWidth((w)->context->font->fsp, s, n)
#define UTF8WIDTH(w,s,n) XTextWidth((w)->context->font->fsp, s, n)
#endif
#define FWIDTH(w) ((w)->context->font->maxwidth)
#define MAXDESCENDER(w) (w->context->font->descent)
#define SCREENDEPTH(w)\
	DefaultDepth((w)->window->display->display, w->window->display->screen)
#define ASCENT(w) ((w)->context->font->ascent)
#define DESCENT(w) ((w)->context->font->descent)
#define FHEIGHT(w) ((w)->context->font->height)
#define LINEWIDTH(w) ((w)->context->linewidth)
#define DISPLAYHEIGHT(w)\
	DisplayHeight(w->window->display->display, w->window->display->screen)
#define DISPLAYWIDTH(w)\
	DisplayWidth(w->window->display->display, w->window->display->screen)
#define FS_SOLID FillSolid
#define FS_STIPPLE FillStippled
#define SysColor XColor
/* 8-bit primary components of a current fg or bg index, used in 3D code */
#define RED(colrindex) ((w->context->display->colors[colrindex].r)>>8)
#define GREEN(colrindex) ((w->context->display->colors[colrindex].g)>>8)
#define BLUE(colrindex) ((w->context->display->colors[colrindex].b)>>8)
#define ARCWIDTH(arc) ((arc).width)
#define ARCHEIGHT(arc) ((arc).height)
#define RECX(rec) ((rec).x)
#define RECY(rec) ((rec).y)
#define RECWIDTH(rec) ((rec).width)
#define RECHEIGHT(rec) ((rec).height)
#define ANGLE(ang) (-(ang) * 180 / Pi * 64)
#define EXTENT(ang) (-(ang) * 180 / Pi * 64)
#define ISICONIC(w) ((w)->window->iconic == IconicState)
#define ISFULLSCREEN(w) (0)
#define ISROOTWIN(w) ((w)->window->iconic == RootState)
#define ISNORMALWINDOW(w) ((w)->window->iconic == NormalState)
#define ICONFILENAME(w) ((w)->window->iconimage)
#define ICONLABEL(w) ((w)->window->iconlabel)
#define WINDOWLABEL(w) ((w)->window->windowlabel)
#define RootState IconicState+1
#define MaximizedState IconicState+2
#define HiddenState IconicState+3

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
#define SHARED          0
#define MUTABLE         1
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

#define drawarcs(w, arcs, narcs) \
   { STDLOCALS(w); RENDER2(XDrawArcs,arcs,narcs); }
#define drawlines(w, points, npoints) \
   { STDLOCALS(w); RENDER3(XDrawLines,points,npoints,CoordModeOrigin); }
#define drawpoints(w, points, npoints) \
   { STDLOCALS(w); RENDER3(XDrawPoints,points,npoints,CoordModeOrigin); }
#define drawrectangles(w, recs, nrecs) { \
   int i; \
   STDLOCALS(w); \
   for(i=0; i<nrecs; i++) { \
     RENDER4(XDrawRectangle,recs[i].x,recs[i].y,recs[i].width,recs[i].height);\
     }}

#define drawsegments(w, segs, nsegs) \
   { STDLOCALS(w); RENDER2(XDrawSegments,segs,nsegs); }
#ifndef HAVE_LIBXFT
#define drawstrng(w, x, y, s, slen) \
   { STDLOCALS(w); RENDER4(XDrawString, x, y, s, slen); }
#define drawutf8(w, x, y, s, slen) \
   { STDLOCALS(w); RENDER4(XDrawString, x, y, s, slen); }
#endif
#define fillarcs(w, arcs, narcs) \
   { STDLOCALS(w); RENDER2(XFillArcs, arcs, narcs); }
#define fillpolygon(w, points, npoints) \
   { STDLOCALS(w); RENDER4(XFillPolygon, points, npoints, Complex, CoordModeOrigin); }

/*
 * "get" means remove them from the Icon list and put them on the ghost queue
 */
#define EVQUEGET(w,d) { \
   wsp ws = (w)->window; \
   if (!list_get(&ws->listp,&d)) fatalerr(0,NULL); \
   }
#define EVQUEEMPTY(w) (BlkLoc((w)->window->listp)->list.size == 0)

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
   int           type;			/* SHARED or MUTABLE */
} *wclrp;



#endif					/* XWindows */
