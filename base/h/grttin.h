/*
 * Group of include files for input to rtt.
 *   rtt reads these files for preprocessor directives and typedefs, but
 *   does not output any code from them.
 */
#include "../h/auto.h"
#include "../h/define.h"
#include "../h/config.h"
#include "../h/version.h"
#include "../h/monitor.h"

#ifndef NoTypeDefs
   #include "../h/typedefs.h"
#endif					/* NoTypeDefs */

/*
 * Macros that must be expanded by rtt.
 */

/*
 * Declaration for library routine.
 */
#begdef LibDcl(nm,n,pn)
   #passthru OpBlock(nm,n,pn,0)

   int O##nm(nargs,cargp)
   int nargs;
   register dptr cargp;
#enddef					/* LibDcl */

/*
 * Error exit from non top-level routines. Set tentative values for
 *   error number and error value; these errors will but put in
 *   effect if the run-time error routine is called.
 */
#begdef ReturnErrVal(err_num, offending_val, ret_val)
   do {
   t_errornumber = err_num;
   t_errorvalue = offending_val;
   t_have_val = 1;
   return ret_val;
   } while (0)
#enddef					/* ReturnErrVal */

#begdef ReturnErrNum(err_num, ret_val)
   do {
   t_errornumber = err_num;
   t_errorvalue = nulldesc;
   t_have_val = 0;
   return ret_val;
   } while (0)
#enddef					/* ReturnErrNum */

/*
 * Code expansions for exits from C code for top-level routines.
 */
#define Fail		return A_Resume
#define Return		return A_Continue

/*
 * RunErr encapsulates a call to the function err_msg, followed
 *  by Fail.  The idea is to avoid the problem of calling
 *  runerr directly and forgetting that it may actually return.
 */

#define RunErr(n,dp) do {\
   err_msg((int)n,dp);\
   Fail;\
   } while (0)

/*
 * Protection macro.
 */
#define Protect(notnull,orelse) do {if ((notnull)==NULL) orelse;} while(0)

#define MemProtect(notnull) do {if ((notnull)==NULL) fatalerr(309,NULL);} while(0)

/*
 * perform what amounts to "function inlining" of EVVal
 */
#begdef RealEVVal(value,event)
   do {
      if (is:null(curpstate->eventmask)) break;
      else if (!Testb((word)event, BlkLoc(curpstate->eventmask)->cset.bits)) break;
      MakeInt(value, &(curpstate->parent->eventval));
      if (!is:null(curpstate->valuemask) &&
	  !invaluemask(curpstate, event, &(curpstate->parent->eventval)))
	 break;
      actparent(event);
   } while (0)
#enddef					/* RealEVVal */

#begdef EVVal(value,event)
#if event
   RealEVVal(value,event)
#endif
#enddef					/* EVVal */
#begdef EVValD(dp,event)
#if event
   do {
      if (is:null(curpstate->eventmask)) break;
      else if (!Testb((word)event, BlkLoc(curpstate->eventmask)->cset.bits)) break;
      curpstate->parent->eventval = *(dp);
      if (!is:null(curpstate->valuemask) &&
	  !invaluemask(curpstate, event, &(curpstate->parent->eventval)))
	 break;
      actparent(event);
   } while (0)
#endif
#enddef					/* EVValD */
#begdef EVValX(bp,event)
#if event
   do {
      struct progstate *parent = curpstate->parent;
      if (is:null(curpstate->eventmask)) break;
      else if (!Testb((word)event, BlkLoc(curpstate->eventmask)->cset.bits)) break;
      parent->eventval.dword = D_Coexpr;
      BlkLoc(parent->eventval) = (union block *)(bp);
      if (!is:null(curpstate->valuemask) &&
	  !invaluemask(curpstate, event, &(curpstate->parent->eventval)))
	 break;
      actparent(event);
   } while (0)
#endif
#enddef					/* EVValX */
#begdef EVVar(dp, e)
#if e
   do {
      if (!is:null(curpstate->eventmask) &&
          Testb((word)e, BlkLoc(curpstate->eventmask)->cset.bits)) {
            EVVariable(dp, e);
	    }
   } while(0)
#endif
#enddef

#begdef InterpEVVal(value,event)
#if event
  { ExInterp; RealEVVal(value,event); EntInterp; }
#endif
#enddef
#begdef InterpEVValD(dp,event)
#if event
 { ExInterp; EVValD(dp,event); EntInterp; }
#endif
#enddef

/*
 * Macro with construction of event descriptor.
 */

#begdef Desc_EVValD(bp, code, type)
#if code
   do {
   eventdesc.dword = type;
   eventdesc.vword.bptr = (union block *)(bp);
   EVValD(&eventdesc, code);
   } while (0)
#endif
#enddef					/* Desc_EVValD */

/*
 * dummy typedefs for things defined in #include files
 */
typedef int clock_t, time_t, fd_set, va_list;

#if WildCards
   typedef int FINDDATA_T;
#endif					/* WildCards */

typedef int DIR;

typedef int size_t;
typedef long time_t;

#ifdef HAVE_LIBZ
typedef int gzFile;
#endif					/* HAVE_LIBZ */


typedef int jmp_buf;

#if MSWIN32
typedef int HMODULE, WSADATA, WORD, HANDLE, MEMORYSTATUS;
#ifdef NTGCC
typedef int STARTUPINFO, PROCESS_INFORMATION, SECURITY_ATTRIBUTES;
#endif
#endif					/* MSWIN32 */

#ifdef HAVE_LIBJPEG
typedef int j_common_ptr, JSAMPARRAY, JSAMPROW;
#endif					/* HAVE_LIBJPEG */

typedef int SOCKET;
typedef int u_short;
typedef int fd_set;

struct timeval {
   long    tv_sec;
   long    tv_usec;
};
typedef int time_t;
typedef int DIR;


typedef int siptr, stringint, inst;

/*
 * graphics
 */
#ifdef Graphics
   typedef int wbp, wsp, wcp, wdp, wclrp, wfp, wtp;
   typedef int wbinding, wstate, wcontext, wfont;
   typedef int XRectangle, XPoint, XSegment, XArc, SysColor, LinearColor;
   typedef int LONG, SHORT;

   #ifdef XWindows
      typedef int Atom, Time, XSelectionEvent, XErrorEvent, XErrorHandler;
      typedef int XGCValues, XColor, XFontStruct, XWindowAttributes, XEvent;
      typedef int XExposeEvent, XKeyEvent, XButtonEvent, XConfigureEvent;
      typedef int XSizeHints, XWMHints, XClassHint, XTextProperty;
      typedef int Colormap, XVisualInfo;
      typedef int *Display, Cursor, GC, Window, Pixmap, Visual, KeySym;
      typedef int WidgetClass, XImage, XpmAttributes, XSetWindowAttributes;
      typedef int XGlyphInfo, XftColor, Region, XftDraw;
      typedef int Cardinal,String,XtResource,XtPointer;
   #endif				/* XWindows */
      
   #ifdef MSWindows
      typedef int clock_t, jmp_buf, MINMAXINFO, OSVERSIONINFO, BOOL_CALLBACK;
      typedef int int_PASCAL, LRESULT_CALLBACK, MSG, BYTE, WORD, DWORD;
      typedef int HINSTANCE, HGLOBAL, HPEN, HBRUSH, HRGN;
      typedef int LPSTR, HBITMAP, WNDCLASS, PAINTSTRUCT, POINT, RECT;
      typedef int HWND, HDC, UINT, WPARAM, LPARAM, SIZE;
      typedef int COLORREF, HFONT, LOGFONT, TEXTMETRIC, FONTENUMPROC, FARPROC;
      typedef int LOGPALETTE, HPALETTE, PALETTEENTRY, HCURSOR, BITMAP, HDIB;
      typedef int LOGPEN, LOGBRUSH, LPVOID, MCI_PLAY_PARMS;
      typedef int MCI_OPEN_PARMS, MCI_STATUS_PARMS, MCI_SEQ_SET_PARMS;
      typedef int CHOOSEFONT, CHOOSECOLOR, OPENFILENAME, HMENU, LPBITMAPINFO;
      typedef int childcontrol, CPINFO, BITMAPINFO, BITMAPINFOHEADER, RGBQUAD;
   #endif				/* MSWindows */

   /*
    * Convenience macros to make up for RTL's long-windedness.
    */
   #begdef CnvShortInt(desc, s, max, min, type)
	{
	C_integer tmp;
	if (!cnv:C_integer(desc,tmp) || tmp > max || tmp < min)
	   runerr(101,desc);
	s = (type) tmp;
	}
   #enddef				/* CnvShortInt */
   #define CnvCShort(desc, s) CnvShortInt(desc, s, 0x7FFF, -0x8000, short)
   #define CnvCUShort(desc, s) CnvShortInt(desc, s, 0xFFFF, 0, unsigned short)
   
   #define CnvCInteger(d,i) \
     if (!cnv:C_integer(d,i)) runerr(101,d);
   
   #define DefCInteger(d,default,i) \
     if (!def:C_integer(d,default,i)) runerr(101,d);
   
   #define CnvString(din,dout) \
     if (!cnv:string(din,dout)) runerr(103,din);
   
   #define CnvTmpString(din,dout) \
     if (!cnv:tmp_string(din,dout)) runerr(103,din);
   
   /*
    * conventions supporting optional initial window arguments:
    *
    * All routines declare argv[argc] as their parameters
    * Macro OptWindow checks argv[0] and assigns _w_ and warg if it is a window
    * warg serves as a base index and is added everywhere argv is indexed
    * n is used to denote the actual number of "objects" in the call
    * Macro ReturnWindow returns either the initial window argument, or &window
    */
   #begdef OptWindow(w)
      if (argc>warg && is:window(argv[warg])) {
         if (!(BlkLoc(argv[warg])->window.isopen))
	    runerr(142,argv[warg]);
         (w) = BlkLoc(argv[warg])->window.wb;
         if (ISCLOSED(w))
	    runerr(142,argv[warg]);
         warg++;
         }
      else {
         if (!(is:window(kywd_xwin[XKey_Window])))
	    runerr(140,kywd_xwin[XKey_Window]);
         if (!(BlkLoc(kywd_xwin[XKey_Window])->window.isopen))
	    runerr(142,kywd_xwin[XKey_Window]);
         (w) = (wbp)BlkLoc(kywd_xwin[XKey_Window])->window.wb;
         if (ISCLOSED(w))
	    runerr(142,kywd_xwin[XKey_Window]);
         }
   #enddef				/* OptWindow */
   
   #begdef ReturnWindow
         if (!warg) return kywd_xwin[XKey_Window];
         else return argv[0]
   #enddef				/* ReturnWindow */
   
   #begdef CheckArgMultiple(mult)
   {
     if ((argc-warg) % (mult)) runerr(146);
     n = (argc-warg)/mult;
     if (!n) runerr(146);
   }
   #enddef				/* CheckArgMultiple */

   #begdef CheckArgMultipleOf(mult)
   {
     if ((argc) % (mult)) runerr(146);
     n = (argc)/mult;
     if (!n) runerr(146);
   }
   #enddef				/* CheckArgMultiple */
   
#endif					/* Graphics */

/*
 * GRFX_ALLOC* family of macros used for static allocations.
 * Not really specific to Graphics any more, also used by databases.
 *
 * calloc to make sure uninit'd entries are zeroed.
 */
#begdef GRFX_ALLOC(var,type)
   do {
      MemProtect(var = calloc(1, sizeof(struct type)));
      var->refcount = 1;
   } while(0)
#enddef				/* GRFX_ALLOC */
   
#begdef GRFX_LINK(var, chain)
   do {
      var->next = chain;
      var->previous = NULL;
      if (chain) chain->previous = var;
      chain = var;
   } while(0)
#enddef				/* GRFX_LINK */
   
#begdef GRFX_UNLINK(var, chain)
   do {
      if (var->previous) var->previous->next = var->next;
      else chain = var->next;
      if (var->next) var->next->previous = var->previous;
      free(var);
   } while(0)
#enddef				/* GRFX_UNLINK */
