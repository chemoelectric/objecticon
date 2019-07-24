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
       if (_lhs)
           suspend expr;
       else
           suspend;
   } while (0)
#enddef

#begdef LazyReturn(expr)
   do {
       if (_lhs)
           return expr;
       else
           return;
   } while (0)
#enddef

#begdef Irunerr(n, v)
   do {
      MakeInt(v, &t_errorvalue);
      t_errornumber = n;
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

#begdef Blkrunerr(n, bp, type)
   do {
      MakeDesc(type, bp, &t_errorvalue);
      t_errornumber = n;
      t_have_val = 1;
      runerr(0);
   } while (0)
#enddef

/*
 * Used from a static native method, return the class the method is
 * defined in.  Useful for method chaining.
 */
#define ReturnDefiningClass return class(curr_cf->proc->field->defining_class)

/*
 * Protection macro.
 */
#define Protect(notnull,orelse) do {if (!(notnull)) orelse;} while(0)

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
      if (!Testb(event, curpstate->eventmask->bits)) break;
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
      if (!Testb(event, curpstate->eventmask->bits)) break;
      add_to_prog_event_queue(dp, event);
   } while (0)
#endif
#enddef					/* EVValD */

/*
 * Macro with construction of event descriptor.
 */
#begdef Desc_EVValD(bp, event, type)
#if event
   do {
      struct descrip eventdesc;
      if (!curpstate->monitor) break;
      if (curpstate->eventmask->size == 0) break;
      if (!Testb(event, curpstate->eventmask->bits)) break;
      MakeDesc(type, bp, &eventdesc);
      add_to_prog_event_queue(&eventdesc, event);
   } while (0)
#endif
#enddef					/* Desc_EVValD */

/*
 * dummy typedefs for things defined in #include files
 */
typedef int clock_t, time_t, fd_set, va_list, off_t, mode_t,
    ino_t, blkcnt_t, dev_t, size_t, jmp_buf,
    DIR, uid_t, gid_t, pid_t, stringint, socklen_t,
    int16_t, uint16_t, int32_t, uint32_t, int64_t, uint64_t;

#if HAVE_LIBZ
typedef int gzFile;
#endif					/* HAVE_LIBZ */

#if HAVE_LIBJPEG
typedef int j_common_ptr, JSAMPARRAY, JSAMPROW;
#endif					/* HAVE_LIBJPEG */

#if HAVE_LIBPNG
typedef int png_structp, png_infop, png_bytep, png_byte, png_colorp, png_color, png_color_16, png_color_16p;
#endif

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
      typedef int Cardinal,String,XtResource,XtPointer,XArc,CARD32,INT32;
      typedef int XRenderColor, XRenderPictureAttributes, XRenderPictFormat;
      typedef int XPointFixed, XLineFixed, XTriangle, XTrapezoid, XTransform;
      typedef int XPointDouble;
   #endif				/* XWindows */
#endif					/* Graphics */

#if MSWIN32
   typedef int MINMAXINFO, BOOL_CALLBACK;
   typedef int LRESULT_CALLBACK, MSG, BYTE, WORD, DWORD;
   typedef int HINSTANCE, HGLOBAL, LPSTR, HBITMAP, POINT, RECT;
   typedef int HWND, HDC, UINT, WPARAM, LPARAM, SIZE, BOOL;
   typedef int HFONT, HCURSOR, HMODULE, BITMAP, LPVOID;
   typedef int WNDCLASSEXW, LONG, ULONG_PTR, LPCTSTR, TRACKMOUSEEVENT;
   typedef int WCHAR, WSADATA, WORD, HANDLE, MEMORYSTATUS;
   typedef int PVOID, WIN32_FIND_DATAW, ICONINFO;
   typedef int INT8, INT16, INT32, INT64, UINT8, UINT16, UINT32, UINT64;
   typedef int SOCKET, SIZE_T, INT_PTR, LPWSTR, SHORT, HICON, LONG_PTR;
   typedef int gb_Bitmap, gb_Draw, gb_Color, gb_Font;
#endif				/* MSWIN32 */

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
   
#begdef CheckArgMultipleOf(mult, min)
   {
       if ((argc) % (mult) || (argc) / (mult) < (min))
          runerr(168);
   }
#enddef				/* CheckArgMultiple */
   

/*
 * Macros used for graphics structures.
 *
 */
#begdef GAlloc(var,type)
   do {
      var = safe_zalloc(sizeof(struct type));
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
if (!c_is(&p, (dptr)&pixclassname, &x##_igc)) {
   CMakeStr("graphics.Pixels expected", &t_errortext);
   runerr(-1, p);
}
x##_dptr = c_get_instance_data(&p, (dptr)&ptrf, &x##_ic);
if (!x##_dptr)
    syserr("Missing idp field");
if (is:null(*x##_dptr))
    runerr(219, p);
(x) = (struct imgdata *)IntVal(*x##_dptr);
#enddef

#begdef WindowStaticParam(p, w)
wbp w;
dptr w##_dptr;
static struct inline_field_cache w##_ic;
static struct inline_global_cache w##_igc;
if (!c_is(&p, (dptr)&wclassname, &w##_igc)) {
   CMakeStr("graphics.Window expected", &t_errortext);
   runerr(-1, p);
}
w##_dptr = c_get_instance_data(&p, (dptr)&ptrf, &w##_ic);
if (!w##_dptr)
    syserr("Missing wbp field");
if (is:null(*w##_dptr))
    runerr(219, p);
(w) = (wbp)IntVal(*w##_dptr);
#enddef

/*
 * Op that can succeed or fail setting &why, with default value for
 * &why if none set by op.
 */
#begdef AttemptAttr(operation, reason)
do {
   tended struct descrip saved_why;
   saved_why = kywd_why;
   kywd_why = emptystr;
   switch (operation) { 
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
           syserr("Invalid return code from op"); 
           break;
       }
   }
} while(0)
#enddef

/*
 * Op that can succeed or fail.
 */
#begdef AttemptOp(operation)
do {
   switch (operation) { 
       case Succeeded: {
           break;
       }
       case Failed: {
           fail;
       }
       default: {
           syserr("Invalid return code from op"); 
           break;
       }
   }
} while(0)
#enddef

/*
 * Op that can succeed or fail setting &why or cause runtime error,
 * with default value for &why if none set by op.
 */
#begdef AttemptAttrCanErr(operation, reason)
do {
   tended struct descrip saved_why;
   saved_why = kywd_why;
   kywd_why = emptystr;
   switch (operation) { 
       case Error: {
           kywd_why = saved_why;
           runerr(0); 
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
           syserr("Invalid return code from op"); 
           break;
       }
   }
} while(0)
#enddef

/*
 * Op that can succeed or fail or cause runtime error.
 */
#begdef AttemptOpCanErr(operation)
do {
   switch (operation) { 
       case Error: {
           runerr(0); 
           break;
       }
       case Succeeded: {
           break;
       }
       case Failed: {
           fail;
       }
       default: {
           syserr("Invalid return code from op"); 
           break;
       }
   }
} while(0)
#enddef

#begdef FdStaticParam(p, m)
int m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
static struct inline_global_cache m##_igc;
if (!c_is(&p, (dptr)&dsclassname, &m##_igc)) {
   CMakeStr("io.DescStream expected", &t_errortext);
   runerr(-1, p);
}
m##_dptr = c_get_instance_data(&p, (dptr)&fdf, &m##_ic);
if (!m##_dptr)
    syserr("Missing fd field");
if (is:null(*m##_dptr))
    runerr(219, p);
(m) = (int)IntVal(*m##_dptr);
#enddef

#if MSWIN32
#begdef SocketStaticParam(p, m)
SOCKET m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
static struct inline_global_cache m##_igc;
if (!c_is(&p, (dptr)&wsclassname, &m##_igc)) {
   CMakeStr("io.WinsockStream expected", &t_errortext);
   runerr(-1, p);
}
m##_dptr = c_get_instance_data(&p, (dptr)&socketf, &m##_ic);
if (!m##_dptr)
    syserr("Missing socket field");
if (is:null(*m##_dptr))
    runerr(219, p);
(m) = (SOCKET)IntVal(*m##_dptr);
#enddef
#endif

/*
 * Check and convert to class/record field specifier - integer or string.
 */

#begdef CheckField(field)
{
    word x;
    if (cnv:C_integer(field, x))
        MakeInt(x, &field);
    else if (!cnv:string(field,field))
        runerr(170,field);
}
#enddef

/*
 * These macros are used to convert to/from various integer types
 * which may be bigger than a word and may or may not be signed.
 */

#begdef convert_to_macro(TYPE)
int convert_to_##TYPE(dptr src, TYPE *dest)
{
    struct descrip bits, int65535;
    tended struct descrip i, t, u, pwr;
    TYPE res = 0;
    int pos = 0, k;

    /*
     * If we have a normal integer, try a conversion to the target type.
     */
    if (Type(*src) == T_Integer &&
        sizeof(TYPE) >= sizeof(word) &&
        (((TYPE)-1 < 0) || IntVal(*src) >= 0))   /* TYPE signed, or src +ve */
    {
        *dest = IntVal(*src);
        return 1;
    }

    MakeInt(65535, &int65535);
    /* pwr = 2 ^ "n bits in TYPE" */
    bigshift(&onedesc, sizeof(TYPE) * 8, &pwr);
    i = *src;
    if (bigsign(&i) < 0) {
        /* Check TYPE is signed */
        if ((TYPE)-1 > 0)
            ReturnErrVal(101, *src, 0);
        bigshift(&pwr, -1, &t);
        /* src must be >= -ve pwr/2 */
        bigneg(&t, &u);
        if (bigcmp(&i, &u) < 0)
            ReturnErrVal(101, *src, 0);
        /* Convert to the two's complement representation of i (i := pwr + i) */
        bigadd(&i, &pwr, &i);
    } else if ((TYPE)-1 > 0) {
        /* TYPE unsigned, i must be < pwr */
        if (bigcmp(&i, &pwr) >= 0)
            ReturnErrVal(101, *src, 0);
    } else {
        /* TYPE signed - src must be < pwr/2 */
        bigshift(&pwr, -1, &t);
        if (bigcmp(&i, &t) >= 0)
            ReturnErrVal(101, *src, 0);
    }

    /*
     * Copy the bits in the converted source (it is now in two's
     * complement form) into the target.
     */
    for (k = 0; k < sizeof(TYPE) / 2; ++k) {
        bigand(&i, &int65535, &bits);
        bigshift(&i, -16, &i);
        res |= ((TYPE)IntVal(bits) << pos);
        pos += 16;
    }
    *dest = res;
    return 1;
}
#enddef

#begdef convert_from_macro(TYPE)
void convert_from_##TYPE(TYPE src, dptr dest)
{
    TYPE j = src;
    int k;
    word pos = 0;
    tended struct descrip res, chunk, pwr;

    /* See if it fits in a word.  For an unsigned type, just compare
     * against MaxWord; for a signed compare against MinWord too. */
    if (src <= MaxWord && ((TYPE)-1 > 0 || src >= MinWord)) {
        MakeInt(src, dest);
        return;
    }

    /* Copy the raw bits of src, to dest in 16 bit chunks.  For a -ve
     * src, the two's complement representation is copied, and then
     * converted below
     */
    res = zerodesc;
    for (k = 0; k < sizeof(TYPE) / 2; ++k) {
        int bits = j & 0xffff;
        j = j >> 16;
        MakeInt(bits, &chunk);
        bigshift(&chunk, pos, &chunk);
        bigadd(&res, &chunk, &res);
        pos += 16;
    }
    if (src < 0) {
        /* pwr = 2 ^ "n bits in TYPE" */
        bigshift(&onedesc, sizeof(TYPE) * 8, &pwr);
        /* Convert from two's complement to true value - res := res - pwr */
        bigsub(&res, &pwr, &res);
    }
    *dest = res;
}
#enddef
