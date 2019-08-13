#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <stdio.h>
#include <math.h>
#include "../h/gdip.h"

using namespace Gdiplus;

static const int draw_debug = 0;

static void dbg(char *fmt, ...);

static void dbg(char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    fflush(stderr);
}

static ULONG_PTR gdiplusToken;
static gb_fatalerr_func ffatalerr;

extern "C"
void gb_initialize(gb_fatalerr_func f)
{
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
    if (draw_debug) dbg("gb_initialize: hello from gdip.cpp\n");
    ffatalerr = f;
}

extern "C"
gb_Bitmap *gb_create_Bitmap(int width, int height, gb_Color bg, gb_Bitmap *cp)
{
    Bitmap *bm = new Bitmap(width, height, PixelFormat32bppARGB);
    Color c = Color((ARGB)bg);
    Graphics g(bm);
    SolidBrush br(c);
    g.SetCompositingMode(CompositingModeSourceCopy);
    g.FillRectangle(&br, 0, 0, width, height);
    if (cp)
        g.DrawImage((Bitmap *)cp, 0, 0);
    if (draw_debug) dbg("Returning new bitmap %p filled with %x\n",bm,(int)bg);
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
    if (draw_debug) dbg("Deleting bitmap %p\n",b);
    delete b;
}

static Graphics *get_graphics(gb_Draw *d, int aa=0)
{
    Bitmap *b = (Bitmap *)d->pix;
    Graphics *g = Graphics::FromImage(b);
    if (d->clipw >= 0) {
        Rect r(d->clipx, d->clipy, d->clipw, d->cliph);
        g->SetClip(r);
    }
    g->SetCompositingMode((CompositingMode)d->drawop);
    if (aa)
        g->SetSmoothingMode(SmoothingModeHighQuality);
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

static Pen *get_fg_pen(gb_Draw *d, Brush *b)
{
    Pen *p = new Pen(b, d->linewidth);
    if (d->lineend == EndRound) {
        p->SetEndCap(LineCapRound);
        p->SetStartCap(LineCapRound);
    }
    switch (d->linejoin) {
        case JoinRound: p->SetLineJoin(LineJoinRound); break;
        case JoinBevel: p->SetLineJoin(LineJoinBevel); break;
    }
    return p;
}

static Brush *get_bg_brush(gb_Draw *d)
{
    Color c = Color((ARGB)d->bg);
    return new SolidBrush(c);
}

extern "C"
void gb_pix_to_win(gb_Draw *d, int x, int y, int width, int height)
{
    if (!d->win || d->holding)
        return;
    Graphics h(d->win);
    if (draw_debug) dbg("gb_pix_to_win %d %d %dx%d\n",x,y,width,height);
    if (d->clipw >= 0) {
        Rect r(d->clipx, d->clipy, d->clipw, d->cliph);
        h.SetClip(r);
    }
    Bitmap *b = (Bitmap *)d->pix;
    h.SetCompositingMode(CompositingModeSourceCopy);
    h.DrawImage(b, x, y, x, y, width, height, UnitPixel);
}

extern "C"
void gb_draw_Bitmap(gb_Draw *d, int x, int y, gb_Bitmap *src, int copy)
{
    Graphics *g = get_graphics(d);
    Bitmap *bm = (Bitmap *)src;
    Bitmap *b = (Bitmap *)d->pix;
    if (draw_debug) dbg("Draw bitmap at %d, %d\n", x, y);
    if (copy)
        g->SetCompositingMode(CompositingModeSourceCopy);
    g->DrawImage(bm, x, y);
    gb_pix_to_win(d, x, y, bm->GetWidth(), bm->GetHeight());
    delete g;
}

extern "C"
void gb_erasearea(gb_Draw *d, int x, int y, int width, int height)
{
    Graphics *g = get_graphics(d);
    Brush *b = get_bg_brush(d);
    if (draw_debug) dbg("Erase area g=%p fg=%x bg=%x\n", g, (int)d->fg, (int)d->bg);
    g->SetCompositingMode(CompositingModeSourceCopy);
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
    if (draw_debug) dbg("Fill rectangle %d %d %dx%d\n", x, y, width, height);
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

    if (draw_debug) dbg("Draw rectangle %d %d %dx%d thick=%d\n", x, y, width, height, thick);

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
    if (draw_debug) dbg("do_paint b=%p (%dx%d)\n",b ,   b->GetWidth(), b->GetHeight());
    hdc = BeginPaint(hwnd, &ps);
    Graphics g(hdc);
    g.SetCompositingMode(CompositingModeSourceCopy);
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
    if (draw_debug) dbg("copyarea %d %d -> %d %d\n",x,y,x2,y2);
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
    if (draw_debug) dbg("new font hfont=%p -> f=%p\n",hfont,f);
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
    if (draw_debug) dbg("draw string length font=%p %d @ %d,%d\n", f,length,x,y);
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
    *height = bm->GetHeight();
}

static REAL to_degrees(double rad)
{
    return 180.0 * (rad / 3.14159265359);
}

extern "C"
void gb_drawarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    Pen *p = get_fg_pen(d, b);
    GraphicsPath path;
    Rect bound;
    path.AddArc((REAL)cx - (REAL)rx,
                cy - ry,
                2 * rx,
                2 * ry,
                to_degrees(angle1),
                to_degrees(angle2)); 

    g->DrawPath(p, &path);
    path.GetBounds(&bound, NULL, p);
    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);

    delete p;
    delete b;
    delete g;
}

extern "C"
void gb_fillarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    GraphicsPath path;
    Rect bound;
    path.AddPie((REAL)cx - (REAL)rx,
                cy - ry,
                2 * rx,
                2 * ry,
                to_degrees(angle1),
                to_degrees(angle2)); 

    g->FillPath(b, &path);
    path.GetBounds(&bound, NULL, NULL);
    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);

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
void gb_drawlines(gb_Draw *d, struct point *points0, int npoints)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    Pen *p = get_fg_pen(d, b);
    PointF *points = convert_points(points0, npoints);
    GraphicsPath path;
    Rect bound;
    if (draw_debug) dbg("doing %d points\n",npoints);
    if (points0[0].x == points0[npoints - 1].x &&
        points0[0].y == points0[npoints - 1].y)
        path.AddPolygon(points, npoints);
    else
        path.AddLines(points, npoints);
    g->DrawPath(p, &path);
    path.GetBounds(&bound, NULL, p);
    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);

    delete[] points;
    delete p;
    delete b;
    delete g;
}

extern "C"
void gb_fillpolygon(gb_Draw *d, struct point *points0, int npoints)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    PointF *points = convert_points(points0, npoints);
    GraphicsPath path;
    Rect bound;
    path.AddPolygon(points, npoints);
    g->FillPath(b, &path);
    path.GetBounds(&bound, NULL, NULL);
    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);

    delete[] points;
    delete b;
    delete g;
}

extern "C"
void gb_filltriangles(gb_Draw *d, struct triangle *tris, int ntris)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    GraphicsPath path;
    Rect bound;
    int i;
    for (i = 0; i < ntris; ++i) {
        PointF p[3];
        p[0].X = tris[i].p1.x; p[0].Y = tris[i].p1.y;
        p[1].X = tris[i].p2.x; p[1].Y = tris[i].p2.y;
        p[2].X = tris[i].p3.x; p[2].Y = tris[i].p3.y;
        path.AddPolygon(p, 3);
    }
    g->FillPath(b, &path);
    path.GetBounds(&bound, NULL, NULL);
    gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);

    delete b;
    delete g;
}

static
WCHAR *utf8_to_wchar(char *s)
{
    WCHAR *mbs;
    int n;
    if (!s)
        return NULL;
    n = MultiByteToWideChar(CP_UTF8,
                            0,
                            s,
                            -1,
                            0,
                            0);
    mbs = new WCHAR[n];
    MultiByteToWideChar(CP_UTF8,
                        0,
                        s,
                        -1,
                        mbs,
                        n);
    return mbs;
}

static
char *wchar_to_utf8(WCHAR *s)
{
    char *u;
    int n;
    if (!s)
        return NULL;
    n = WideCharToMultiByte(CP_UTF8,
                            0,
                            s,
                            -1,
                            0,
                            0,
                            NULL,
                            NULL);
    u = new char[n];
    WideCharToMultiByte(CP_UTF8,
                        0,
                        s,
                        -1,
                        u,
                        n,
                        NULL,
                        NULL);
    return u;
}

extern "C"
gb_Font *gb_find_Font(char *family, int flags, double size)
{
    const FontFamily *ff;

    if (!strcmp(family, "mono") || !strcmp(family, "fixed"))
        ff = new FontFamily(L"Lucida Console");
    else if (!strcmp(family, "typewriter"))
        ff = FontFamily::GenericMonospace()->Clone();
    else if (!strcmp(family, "sans"))
        ff = FontFamily::GenericSansSerif()->Clone();
    else if (!strcmp(family, "serif"))
        ff = FontFamily::GenericSerif()->Clone();
    else {
        WCHAR *t = utf8_to_wchar(family);
        ff = new FontFamily(t);
        delete[] t;
    }

    if (!ff->IsAvailable()) {
        delete ff;
        return 0;
    }

    INT style = 0;
    if (flags & (FONTFLAG_BOLD | FONTFLAG_DEMIBOLD))
        style |= FontStyleBold;
    if (flags & (FONTFLAG_ITALIC | FONTFLAG_OBLIQUE))
        style |= FontStyleItalic;

    Font *f = new Font(ff, size, style);
    if (!f->IsAvailable()) {
        delete f;
        delete ff;
        return 0;
    }
        
    delete ff;
    return (gb_Font *)f;
}

extern "C"
void gb_get_metrics(HDC dc, gb_Font *fin, int *ascent, int *descent, int *maxwidth)
{
    FontFamily ff;
    Font *f;
    f = (Font *)fin;
    f->GetFamily(&ff);

    WCHAR familyName[LF_FACESIZE];
    ff.GetFamilyName(familyName);

    int ppi = (int)GetDeviceCaps(dc, LOGPIXELSY);
    double pts_per_du = f->GetSize() / ff.GetEmHeight(f->GetStyle());
    double asc_pts = ff.GetCellAscent(f->GetStyle()) * pts_per_du;
    double desc_pts = ff.GetCellDescent(f->GetStyle()) * pts_per_du;
    double asc_pix = ppi * asc_pts / 72.0;
    double desc_pix = ppi * desc_pts / 72.0;
    *ascent = ceil(asc_pix);
    *descent = ceil(desc_pix);

    if (draw_debug) {
        char *t = wchar_to_utf8(familyName);
        dbg("f=%p family name: %s\n",f,t);
        delete[] t;
        dbg("\tsize = %f points\n",f->GetSize());
        dbg("\t     = %d design units\n", (int)ff.GetEmHeight(f->GetStyle()));
        dbg("\tppdu   = %f\n", pts_per_du);
        dbg("\tppi  = %d\n", ppi);
        dbg("\tasc  = %d design units\n", (int)ff.GetCellAscent(f->GetStyle()));
        dbg("\t     = %f pts\n", asc_pts);
        dbg("\t     = %f pixels\n", asc_pix);
        dbg("\tdesc = %d design units\n", (int)ff.GetCellDescent(f->GetStyle()));
        dbg("\t     = %f pts\n", desc_pts);
        dbg("\t     = %f pixels\n", desc_pix);
        dbg("\ta+d  = %f pixels\n", asc_pix + desc_pix);
        dbg("\tgetheight = %f pixels\n", f->GetHeight(ppi));
    }

    Graphics g(dc);
    int mw = 0;
    for (int i = 1; i < 256; ++i) {
        int w;
        WCHAR str[1];
        PointF pf(0, 0);
        RectF bound;
        str[0] = i;
        g.MeasureDriverString((UINT16 *)str, 
                              1, f, &pf, 
                              DriverStringOptionsRealizedAdvance | DriverStringOptionsCmapLookup,
                              0, &bound);
        w = ceil(bound.Width);
        if (w > mw)
            mw = w;
    }
    *maxwidth = mw;
}

extern "C"
gb_Bitmap *gb_load_Bitmap(char *filename)
{
    Bitmap *b;
    WCHAR *t = utf8_to_wchar(filename);
    b = Bitmap::FromFile(t);
    delete[] t;
    if (!b || b->GetWidth() == 0 || b->GetHeight() == 0) {
        if (draw_debug) dbg("Failed to Load bitmap from file %s\n", filename);
        delete b;
        return 0;
    }
    if (draw_debug) dbg("Loaded bitmap %dx%d\n",b->GetWidth(),b->GetHeight());
    return (gb_Bitmap *)b;
}

extern "C"
HICON gb_get_HICON(gb_Bitmap *bm)
{
    HICON res;
    Status st;
    Bitmap *b = (Bitmap *)bm;
    st = b->GetHICON(&res);
    if (st == Ok)
        return res;
    else
        return 0;
}
