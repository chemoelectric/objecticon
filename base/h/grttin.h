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
      MakeReal(v, &t_errorvalue);
      t_errornumber = n;
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

#begdef UnsupportedFunc(name)
function name()
    body {
      Unsupported;
    }
end
#enddef

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
typedef int clock_t, time_t, fd_set, va_list, off_t, mode_t,
    ino_t, blkcnt_t;

typedef int DIR;

typedef int size_t;
typedef long time_t;

#if HAVE_LIBZ
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

#if HAVE_LIBJPEG
typedef int j_common_ptr, JSAMPARRAY, JSAMPROW;
#endif					/* HAVE_LIBJPEG */

#if HAVE_LIBPNG
typedef int png_structp, png_infop, png_bytep, png_byte, png_colorp, png_color, png_color_16, png_color_16p;
#endif

#if HAVE_LIBOPENSSL
typedef int SSL_CTX, SSL, SSL_METHOD, BIO, X509;
#endif

typedef int SOCKET;
typedef int u_short;
typedef int fd_set;

struct timeval {
   long    tv_sec;
   long    tv_usec;
};
typedef int time_t, DIR, uid_t, gid_t, stringint;

/*
 * graphics
 */
#if Graphics
   typedef int wbp, wsp, wcp, wdp, wclrp, wfp, wtp;
   typedef int wbinding, wstate, wcontext, wfont;
   typedef int XRectangle, XPoint, XSegment, XArc, SysColor, LinearColor;

   #if XWindows
      typedef int Atom, Time, XSelectionEvent, XErrorEvent, XErrorHandler;
      typedef int XGCValues, XColor, XFontStruct, XWindowAttributes, XEvent;
      typedef int XExposeEvent, XKeyEvent, XButtonEvent, XConfigureEvent;
      typedef int XSizeHints, XWMHints, XClassHint, XTextProperty, Drawable;
      typedef int Colormap, XVisualInfo, XCrossingEvent, XPropertyEvent;
      typedef int *Display, Cursor, GC, Window, Pixmap, Picture, Visual, KeySym;
      typedef int WidgetClass, XImage, XpmAttributes, XSetWindowAttributes;
      typedef int XGlyphInfo, XftColor, Region, XftDraw, FcChar8, FcPattern, FcResult;
      typedef int Cardinal,String,XtResource,XtPointer,XArc,CARD32;
      typedef int XRenderColor, XRenderPictureAttributes, XRenderPictFormat;
      typedef int XPointFixed, XLineFixed, XTriangle, XTrapezoid, XTransform;
      typedef int XPointDouble;
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
#endif					/* Graphics */

/*
 * Convenience macros to make up for RTL's long-windedness.
 */
   
#define CnvCInteger(d,i)                        \
if (!cnv:C_integer(d,i)) runerr(101,d);

#define DefCInteger(d,default,i)                \
if (!def:C_integer(d,default,i)) runerr(101,d);

#define CnvCDouble(d,i)                        \
if (!cnv:C_double(d,i)) runerr(102,d);
   
#define CnvString(din,dout)                     \
if (!cnv:string(din,dout)) runerr(103,din);
   
#define CnvTmpString(din,dout)                  \
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
   

/*
 * Macros used for graphics structures.
 *
 */
#begdef GAlloc(var,type)
   do {
      MemProtect(var = calloc(1, sizeof(struct type)));
      var->refcount = 1;
   } while(0)
#enddef				/* GAlloc */
   
#begdef GLink(var, chain)
   do {
      var->next = chain;
      var->previous = NULL;
      if (chain) chain->previous = var;
      chain = var;
   } while(0)
#enddef				/* GLink */
   
#begdef GUnlink(var, chain)
   do {
      if (var->previous) var->previous->next = var->next;
      else chain = var->next;
      if (var->next) var->next->previous = var->previous;
   } while(0)
#enddef				/* GUnlink */

#begdef GLink4(var, chain, next, previous)
   do {
      var->next = chain;
      var->previous = NULL;
      if (chain) chain->previous = var;
      chain = var;
   } while(0)
#enddef
   
#begdef GUnlink4(var, chain, next, previous)
   do {
      if (var->previous) var->previous->next = var->next;
      else chain = var->next;
      if (var->next) var->next->previous = var->previous;
   } while(0)
#enddef

#define GReference(obj) ((obj)->refcount++)
#define GUnreference(obj) ((obj)->refcount--)

#begdef PixelsStaticParam(p, x)
struct imgdata *x;
dptr x##_dptr;
static struct inline_field_cache x##_ic;
static struct inline_global_cache x##_igc;
if (!c_is(&p, (dptr)&pixclassname, &x##_igc))
    runerr(205, p);
x##_dptr = c_get_instance_data(&p, (dptr)&idpfieldname, &x##_ic);
if (!x##_dptr)
    syserr("Missing idp field");
(x) = (struct imgdata *)IntVal(*x##_dptr);
if (!(x))
    runerr(152, p);
#enddef

#begdef WindowStaticParam(p, w)
wbp w;
dptr w##_dptr;
static struct inline_field_cache w##_ic;
static struct inline_global_cache w##_igc;
if (!c_is(&p, (dptr)&wclassname, &w##_igc))
    runerr(205, p);
w##_dptr = c_get_instance_data(&p, (dptr)&wbpfieldname, &w##_ic);
if (!w##_dptr)
    syserr("Missing wbp field");
(w) = (wbp)IntVal(*w##_dptr);
if (!(w))
    runerr(142, p);
#enddef

#begdef AttemptAttr(operation, reason)
do {
   tended struct descrip saved_why;
   saved_why = kywd_why;
   kywd_why = emptystr;
   switch (operation) { 
       case Error: {
           kywd_why = saved_why;
           runerr(145, val); 
           break;
       }
       case Succeeded: {
           kywd_why = saved_why;
           break;
       }
       case Failed: {
           if (StrLen(kywd_why) == 0)
               LitWhy(reason);
           fail;
       }
       default: {
           syserr("Invalid return code from graphics op"); 
           fail;
       }
   }
} while(0)
#enddef

