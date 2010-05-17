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
#include "../h/typedefs.h"

/*
 * Macros that must be expanded by rtt.
 */

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

#begdef LazySuspend(expr)
   do {
       if (frame->lhs)
           suspend expr;
       else
           suspend;
   } while (0)
#enddef

#begdef LazyReturn(expr)
   do {
       if (frame->lhs)
           return expr;
       else
           return;
   } while (0)
#enddef

#begdef Irunerr(n, v)
   do {
      t_errornumber = n;
      IntVal(t_errorvalue) = v;
      t_errorvalue.dword = D_Integer;
      t_have_val = 1;
      runerr(0);
   } while (0)
#enddef

#begdef Drunerr(n, v)
   do {
      union block *bp;
      MemProtect(bp = (union block *)alcreal(v));
      t_errornumber = n;
      BlkLoc(t_errorvalue) = bp;
      t_errorvalue.dword = D_Real;
      t_have_val = 1;
      runerr(0);
   } while (0)
#enddef

/*
 * Protection macro.
 */
#define Protect(notnull,orelse) do {if (!(notnull)) orelse;} while(0)

#define MemProtect(notnull) do {if (!(notnull)) fatalerr(309,NULL);} while(0)

#define Unsupported {\
       LitWhy("Function not supported"); \
       fail; \
       }

#begdef EVVal(value,event)
#if event
   do {
      struct descrip value_desc;
      if (!curpstate->monitor) break;
      if (curpstate->eventmask->size == 0) break;
      if (!Testb((word)event, curpstate->eventmask->bits)) break;
      MakeInt(value, &value_desc);
      add_to_prog_event_queue(&value_desc, event);
   } while (0)
#endif
#enddef					/* EVVal */

#begdef EVValD(dp,event)
#if event
   do {
      if (!curpstate->monitor) break;
      if (curpstate->eventmask->size == 0) break;
      if (!Testb((word)event, curpstate->eventmask->bits)) break;
      add_to_prog_event_queue(dp, event);
   } while (0)
#endif
#enddef					/* EVValD */

/*
 * Macro with construction of event descriptor.
 */

#begdef Desc_EVValD(bp, code, type)
#if code
   do {
   if (!curpstate->monitor) break;
   eventdesc.dword = type;
   eventdesc.vword.bptr = (union block *)(bp);
   EVValD(&eventdesc, code);
   } while (0)
#endif
#enddef					/* Desc_EVValD */

/*
 * dummy typedefs for things defined in #include files
 */
typedef int clock_t, time_t, fd_set, va_list, off_t,
    ino_t, blkcnt_t;

typedef int DIR;

typedef int size_t;
typedef long time_t;

#ifdef HAVE_LIBZ
typedef int gzFile;
#endif					/* HAVE_LIBZ */


typedef int jmp_buf;

#if MSWIN32
typedef int HMODULE, WSADATA, WORD, HANDLE, MEMORYSTATUS, WIN32_FIND_DATA, 
   PVOID, PFIBER_START_ROUTINE;
#ifdef NTGCC
typedef int STARTUPINFO, PROCESS_INFORMATION, SECURITY_ATTRIBUTES;
#endif
#endif					/* MSWIN32 */

#ifdef HAVE_LIBJPEG
typedef int j_common_ptr, JSAMPARRAY, JSAMPROW;
#endif					/* HAVE_LIBJPEG */

#ifdef HAVE_LIBPNG
typedef int png_structp, png_infop, png_bytep, png_byte;
#endif

typedef int SOCKET;
typedef int u_short;
typedef int fd_set;

struct timeval {
   long    tv_sec;
   long    tv_usec;
};
typedef int time_t;
typedef int DIR;

typedef int pthread_t, sem_t, pthread_attr_t, pthread_mutex_t, ucontext_t, stack_t,
    pth_uctx_t;

typedef int siptr, stringint, inst;

/*
 * graphics
 */
#ifdef Graphics
   typedef int wbp, wsp, wcp, wdp, wclrp, wfp, wtp;
   typedef int wbinding, wstate, wcontext, wfont;
   typedef int XRectangle, XPoint, XSegment, XArc, SysColor, LinearColor;

   #if XWindows
      typedef int Atom, Time, XSelectionEvent, XErrorEvent, XErrorHandler;
      typedef int XGCValues, XColor, XFontStruct, XWindowAttributes, XEvent;
      typedef int XExposeEvent, XKeyEvent, XButtonEvent, XConfigureEvent;
      typedef int XSizeHints, XWMHints, XClassHint, XTextProperty;
      typedef int Colormap, XVisualInfo;
      typedef int *Display, Cursor, GC, Window, Pixmap, Visual, KeySym;
      typedef int WidgetClass, XImage, XpmAttributes, XSetWindowAttributes;
      typedef int XGlyphInfo, XftColor, Region, XftDraw, FcChar8;
      typedef int Cardinal,String,XtResource,XtPointer,XArc;
   #endif				/* XWindows */
      
   #if MSWIN32
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
   #endif				/* MSWIN32 */

   /*
    * Convenience macros to make up for RTL's long-windedness.
    */
   #begdef CnvShortInt(desc, s, max, min, type)
	{
	word tmp;
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
