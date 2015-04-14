#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <stdio.h>
#include "../h/gdip.h"

using namespace Gdiplus;

static void dbg(char *fmt, ...);

static void dbg(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fflush(stderr);
}

static ULONG_PTR gdiplusToken;

extern "C"
void gb_initialize(void)
{
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
    dbg("gb_initialize: hello from gdip.cpp\n");
}

extern "C"
gb_Bitmap *gb_create_Bitmap(int width, int height, gb_Color bg, gb_Bitmap *cp)
{
    Bitmap *bm = new Bitmap(width, height, PixelFormat32bppARGB);
    Color c = Color((ARGB)bg);
    Graphics g(bm);
    SolidBrush br(c);
    g.FillRectangle(&br, 0, 0, width, height);
    if (cp)
        g.DrawImage((Bitmap *)cp, 0, 0);
       
    dbg("Returning new bitmap %p filled with %x\n",bm,(int)bg);
    return (gb_Bitmap*)bm;
}

extern "C"
gb_Bitmap *gb_create_empty_Bitmap(int width, int height)
{
    Bitmap *bm = new Bitmap(width, height, PixelFormat32bppARGB);
    return (gb_Bitmap*)bm;
}

extern "C"
void gb_free_Bitmap(gb_Bitmap *bm)
{
    Bitmap *b = (Bitmap *)bm;
    dbg("Deleting bitmap %p\n",b);
    delete b;
}

static Graphics *get_graphics(gb_Draw *d)
{
    Bitmap *b = (Bitmap *)d->pix;
    Graphics *g = Graphics::FromImage(b);
    if (d->clipw >= 0) {
        Rect r(d->clipx, d->clipy, d->clipw, d->cliph);
        g->SetClip(r);
    }

    return g;
}

static Brush *get_fg_brush(gb_Draw *d)
{
    if (d->pattern) {
        Bitmap *b = (Bitmap *)d->pattern;
        return new TextureBrush(b);
    } else {
        Color c = Color((ARGB)d->fg);
        return new SolidBrush(c);
    }
}

static Brush *get_bg_brush(gb_Draw *d)
{
    Color c = Color((ARGB)d->bg);
    return new SolidBrush(c);
}

extern "C"
void gb_pix_to_win(gb_Draw *d, int x, int y, int width, int height)
{
    if (!d->win)
        return;
    Graphics h(d->win);
    dbg("gb_pix_to_win %d %d %dx%d\n",x,y,width,height);
    if (d->clipw >= 0) {
        Rect r(d->clipx, d->clipy, d->clipw, d->cliph);
        h.SetClip(r);
    }
    Bitmap *b = (Bitmap *)d->pix;
    h.DrawImage(b, x, y, x, y, width, height, UnitPixel);
}

extern "C"
void gb_erasearea(gb_Draw *d, int x, int y, int width, int height)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_bg_brush(d);
    dbg("Erase area g=%p fg=%x bg=%x\n", g, (int)d->fg, (int)d->bg);
    g->FillRectangle(b, x, y, width, height);
    gb_pix_to_win(d, x, y, width, height);
    delete b;
    delete g;
}

extern "C"
void gb_fillrectangle(gb_Draw *d, int x, int y, int width, int height)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_fg_brush(d);
    g->FillRectangle(b, x, y, width, height);
    gb_pix_to_win(d, x, y, width, height);
    delete b;
    delete g;
}

extern "C"
void gb_drawrectangle(gb_Draw *d, int x, int y, int width, int height, int thick)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_fg_brush(d);

    dbg("Draw rectangle g=%p\n", g);

    if (width <= 2 * thick || height <= 2 * thick)
        g->FillRectangle(b, x, y, width, height);
    else {
        g->FillRectangle(b, x, y, width, thick);
        g->FillRectangle(b, x, y + thick, thick, height - 2 * thick);
        g->FillRectangle(b, x + width - thick, y + thick,
                         thick, height - 2 * thick);
        g->FillRectangle(b, x, y + height - thick,
                         width, thick);
    }

    gb_pix_to_win(d, x, y, width, height);

    delete b;
    delete g;
}

extern "C"
void gb_do_paint(HWND hwnd, gb_Bitmap *pix)
{
    HDC hdc;
    PAINTSTRUCT ps;
    Bitmap *b = (Bitmap *)pix;
    dbg("do_paint b=%p (%dx%d)\n",b ,   b->GetWidth(), b->GetHeight());
    hdc = BeginPaint(hwnd, &ps);
    Graphics g(hdc);
    g.DrawImage(b, 
                ps.rcPaint.left,
                ps.rcPaint.top, 
                ps.rcPaint.left,
                ps.rcPaint.top, 
                ps.rcPaint.right - ps.rcPaint.left + 1,
                ps.rcPaint.bottom - ps.rcPaint.top + 1,
                UnitPixel);

    EndPaint(hwnd, &ps);
}

extern "C"
gb_Color gb_make_Color(int a, int r, int g, int b)
{
    return (gb_Color) Color::MakeARGB(a, r, g, b);
}

extern "C"
void gb_copyarea(gb_Bitmap *src, int x, int y, int width, int height, gb_Draw *d, int x2, int y2)
{
    Graphics *g = get_graphics(d);
    Bitmap *bm = (Bitmap *)src;
    dbg("copyarea %d %d -> %d %d\n",x,y,x2,y2);
    g->DrawImage(bm, 
                 x2, y2,
                 x, y, width, height,
                 UnitPixel);
    gb_pix_to_win(d, x2, y2, width, height);
    delete g;
}

extern "C"
gb_Color gb_getpixel(gb_Bitmap *src, int x, int y)
{
    Bitmap *bm = (Bitmap *)src;
    Color c;
    bm->GetPixel(x, y, &c);
    return (gb_Color) c.GetValue();
}

extern "C"
void gb_setpixel(gb_Bitmap *src, int x, int y, BYTE a, BYTE r, BYTE g, BYTE b)
{
    Bitmap *bm = (Bitmap *)src;
    Color c = Color(a, r, g, b);
    bm->SetPixel(x, y, c);
}

extern "C"
gb_Font *gb_create_Font(HDC hdc, HFONT hfont)
{
    Font *f = new Font(hdc, hfont);
    dbg("new font hfont=%x -> f=%p\n",(int)hfont,f);
    return (gb_Font *)f;
}

extern "C"
void gb_drawstring(gb_Draw *d, int x, int y, WCHAR *str, int length)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_fg_brush(d);
    Font *f = (Font *)d->font;
    PointF pf(x, y);
    RectF bound;
    dbg("draw string length font=%p %d @ %d,%d\n", f,length,x,y);
    g->DrawDriverString((UINT16 *)str, 
                        length, f, b, &pf, 
                        DriverStringOptionsRealizedAdvance | DriverStringOptionsCmapLookup,
                        0);


    g->MeasureDriverString((UINT16 *)str, 
                           length, f, &pf, 
                           DriverStringOptionsRealizedAdvance | DriverStringOptionsCmapLookup,
                           0, &bound);

    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);
    delete b;
    delete g;
}

extern "C"
float gb_textwidth(gb_Draw *d, WCHAR *str, int length)
{
    Graphics *g = get_graphics(d);
    Font *f = (Font *)d->font;
    PointF pf(0, 0);
    RectF bound;
    g->MeasureDriverString((UINT16 *)str, 
                           length, f, &pf, 
                           DriverStringOptionsRealizedAdvance | DriverStringOptionsCmapLookup,
                           0, &bound);
    delete g;
    return bound.Width;
}

extern "C"
void gb_get_Bitmap_size(gb_Bitmap *src, UINT *width, UINT *height)
{
    Bitmap *bm = (Bitmap *)src;
    *width = bm->GetWidth();
    *height = bm->GetWidth();
}

static REAL to_degrees(double rad)
{
    return 180.0 * (rad / 3.14159265359);
}

extern "C"
void gb_drawarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_fg_brush(d);
    Pen *p = new Pen(b, d->linewidth);
    g->DrawArc(p, (REAL)cx - (REAL)rx, cy - ry, 2*rx, 2*ry, to_degrees(angle1), to_degrees(angle2)); 
    gb_pix_to_win(d, cx - rx, cy - ry, 2*rx, 2*ry);
    delete p;
    delete b;
    delete g;
}

static PointF *convert_points(struct point *points0, int npoints)
{
    PointF *points;
    int i;
    points = new PointF[npoints];
    for (i = 0; i < npoints; ++i) {
        points[i].X = (REAL)points0[i].x;
        points[i].Y = (REAL)points0[i].y;
    }
    return points;
}

extern "C"
void gb_drawlines(gb_Draw *d, struct point *points0, int npoints,
                  int ex_x, int ex_y, int ex_width, int ex_height)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_fg_brush(d);
    Pen *p = new Pen(b, d->linewidth);
    PointF *points = convert_points(points0, npoints);
    dbg("doing %d points\n",npoints);
    g->DrawLines(p, points, npoints);
    gb_pix_to_win(d, ex_x, ex_y, ex_width, ex_height);
    delete[] points;
    delete p;
    delete b;
    delete g;
}

