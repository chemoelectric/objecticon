#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <shlwapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include "../h/gdip.h"

using namespace Gdiplus;

static const int draw_debug = 0;

static ULONG_PTR gdiplusToken;

static struct gb_funcs *funcs;

#define dbg (funcs->dbg)

#define Copying(d) ((d)->win && !(d)->holding)

extern "C"
void gb_initialize(struct gb_funcs *fs)
{
    GdiplusStartupInput gdiplusStartupInput;
    GdiplusStartup(&gdiplusToken, &gdiplusStartupInput, NULL);
    funcs = fs;
    if (draw_debug) dbg("gb_initialize: hello from gdip.cpp\n");
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
    if (draw_debug) dbg("Returning new Bitmap %p filled with %x\n",bm,(int)bg);
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
    if (draw_debug) dbg("Deleting Bitmap %p\n",b);
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
    p->SetEndCap((LineCap)d->lineend);
    p->SetStartCap((LineCap)d->lineend);
    p->SetLineJoin((LineJoin)d->linejoin);
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
    if (draw_debug) dbg("Draw Bitmap at %d, %d\n", x, y);
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

    /* Avoid unnecessary call to MeasureDriverString if gb_pix_to_win() is a no-op. */
    if (Copying(d)) {
        g->MeasureDriverString((UINT16 *)str, 
                               length, f, &pf, 
                               DriverStringOptionsRealizedAdvance | DriverStringOptionsCmapLookup,
                               0, &bound);

        gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);
    }

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

static void path_to_win(gb_Draw *d, GraphicsPath &path, Pen *p)
{
    if (Copying(d)) {
        Rect bound;
        path.GetBounds(&bound, NULL, p);
        gb_pix_to_win(d, bound.X, bound.Y, bound.Width, bound.Height);
    }
}

extern "C"
void gb_drawarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2)
{
    Graphics *g = get_graphics(d, 1);
    Brush *b = get_fg_brush(d);
    Pen *p = get_fg_pen(d, b);
    GraphicsPath path;
    path.AddArc((REAL)cx - (REAL)rx,
                cy - ry,
                2 * rx,
                2 * ry,
                to_degrees(angle1),
                to_degrees(angle2)); 

    g->DrawPath(p, &path);
    path_to_win(d, path, p);

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
    path.AddPie((REAL)cx - (REAL)rx,
                cy - ry,
                2 * rx,
                2 * ry,
                to_degrees(angle1),
                to_degrees(angle2)); 

    g->FillPath(b, &path);
    path_to_win(d, path, NULL);

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
    if (draw_debug) dbg("doing %d points\n",npoints);
    if (points0[0].x == points0[npoints - 1].x &&
        points0[0].y == points0[npoints - 1].y)
        path.AddPolygon(points, npoints);
    else
        path.AddLines(points, npoints);
    g->DrawPath(p, &path);
    path_to_win(d, path, p);

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
    path.AddPolygon(points, npoints);
    g->FillPath(b, &path);
    path_to_win(d, path, NULL);

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
    int i;
    for (i = 0; i < ntris; ++i) {
        PointF p[3];
        p[0].X = tris[i].p1.x; p[0].Y = tris[i].p1.y;
        p[1].X = tris[i].p2.x; p[1].Y = tris[i].p2.y;
        p[2].X = tris[i].p3.x; p[2].Y = tris[i].p3.y;
        path.AddPolygon(p, 3);
    }
    g->FillPath(b, &path);
    path_to_win(d, path, NULL);

    delete b;
    delete g;
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
        WCHAR *t = funcs->utf8_to_wchar(family);
        ff = new FontFamily(t);
        free(t);
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
        char *t = funcs->wchar_to_utf8(familyName);
        dbg("f=%p family name: %s\n",f,t);
        free(t);
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
gb_Bitmap *gb_load_Bitmap_data(BYTE *data, UINT length)
{
    Bitmap *b;
    IStream *stream = SHCreateMemStream(data, length);
    b = Bitmap::FromStream(stream);
    stream->Release();
    if (!b || b->GetWidth() == 0 || b->GetHeight() == 0) {
        if (draw_debug) dbg("Failed to Load Bitmap from data\n");
        delete b;
        return 0;
    }
    if (draw_debug) dbg("Loaded Bitmap from data %dx%d\n",b->GetWidth(),b->GetHeight());
    return (gb_Bitmap *)b;
}

extern "C"
gb_Bitmap *gb_load_Bitmap_file(char *filename)
{
    Bitmap *b;
    WCHAR *t = funcs->utf8_to_wchar(filename);
    b = Bitmap::FromFile(t);
    free(t);
    if (!b || b->GetWidth() == 0 || b->GetHeight() == 0) {
        if (draw_debug) dbg("Failed to Load Bitmap from file %s\n", filename);
        delete b;
        return 0;
    }
    if (draw_debug) dbg("Loaded Bitmap from file %s %dx%d\n",filename,b->GetWidth(),b->GetHeight());
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

static char *PixelFormatString(PixelFormat i)
{
    switch (i) {
        case PixelFormat1bppIndexed: return "PixelFormat1bppIndexed";
        case PixelFormat4bppIndexed: return "PixelFormat4bppIndexed";
        case PixelFormat8bppIndexed: return "PixelFormat8bppIndexed";
        case PixelFormat16bppGrayScale: return "PixelFormat16bppGrayScale";
        case PixelFormat16bppRGB555: return "PixelFormat16bppRGB555";
        case PixelFormat16bppRGB565: return "PixelFormat16bppRGB565";
        case PixelFormat16bppARGB1555: return "PixelFormat16bppARGB1555";
        case PixelFormat24bppRGB: return "PixelFormat24bppRGB";
        case PixelFormat32bppRGB: return "PixelFormat32bppRGB";
        case PixelFormat32bppARGB: return "PixelFormat32bppARGB";
        case PixelFormat32bppPARGB: return "PixelFormat32bppPARGB";
        case PixelFormat48bppRGB: return "PixelFormat48bppRGB";
        case PixelFormat64bppARGB: return "PixelFormat64bppARGB";
        case PixelFormat64bppPARGB: return "PixelFormat64bppPARGB";
        default: return "?";
    }    
}

static struct palentry *build_paltbl(Bitmap *b)
{
    ColorPalette *pal;
    struct palentry *pt;
    int i, sz;
    sz = b->GetPaletteSize();
    if (sz <= 0)
        return 0;
    pal = (ColorPalette *)funcs->safe_malloc(sz);
    b->GetPalette(pal, sz);
    if (pal->Count <= 0 || pal->Count > 256) {
        free(pal);
        return 0;
    }
    if (draw_debug) 
        dbg("\tPalette data Flags=%x Count=%d\n", pal->Flags, pal->Count);
    pt = (struct palentry *)funcs->safe_zalloc(256 * sizeof(struct palentry));
    for (i = 0; i < pal->Count; ++i) {
        Color c = Color(pal->Entries[i]);
        pt[i].r = 257 * c.GetR();
        pt[i].g = 257 * c.GetG();
        pt[i].b = 257 * c.GetB();
        pt[i].a = 257 * c.GetA();
    }
    free(pal);
    return pt;
}

extern "C"
int gb_get_Bitmap_data(gb_Bitmap *bm,
                       int x, int y, int width, int height,
                       unsigned char **data, struct palentry **paltbl, char **format)
{
    Bitmap *b = (Bitmap *)bm;
    PixelFormat pf;
    int bpp, rowsize, size;
    char *fmt;
    unsigned char *p;

    switch (b->GetPixelFormat()) {
        case PixelFormat1bppIndexed:
        case PixelFormat4bppIndexed:
        case PixelFormat8bppIndexed:
            if (!paltbl)
                return 0;
            pf = PixelFormat8bppIndexed;
            bpp = 1;
            fmt = "PALETTE8";
            break;
        case PixelFormat16bppGrayScale:
        case PixelFormat16bppRGB555:
        case PixelFormat16bppRGB565:
        case PixelFormat24bppRGB:
        case PixelFormat32bppRGB:
        case PixelFormat48bppRGB:
            pf = PixelFormat24bppRGB;
            bpp = 3;
            fmt = "BGR24";
            break;
        case PixelFormat16bppARGB1555:
        case PixelFormat32bppARGB:
        case PixelFormat32bppPARGB:
        case PixelFormat64bppARGB:
        case PixelFormat64bppPARGB:
            pf = PixelFormat32bppARGB;
            bpp = 4;
            fmt = "MSBGRA32";
            break;
        default:
            return 0;
    }    
    if (draw_debug) 
        dbg("Bitmap Format %s (%x)\n",
            PixelFormatString(b->GetPixelFormat()), b->GetPixelFormat());

    rowsize = width * bpp;
    size = funcs->safe_imul(1, height, rowsize);
    p = (unsigned char *)funcs->safe_malloc(size);

    BitmapData bd;
    bd.Width = width;
    bd.Height = height;
    bd.Stride = rowsize;
    bd.PixelFormat = pf;
    bd.Scan0 = p;
    bd.Reserved = NULL;
    Rect r(x, y, width, height);
    Status st;
    st = b->LockBits(&r,
                     ImageLockModeRead | ImageLockModeUserInputBuf,
                     pf, &bd);
    if (st != Ok) {
        free(p);
        return 0;
    }
    b->UnlockBits(&bd);
    
    if (draw_debug) 
        dbg("\tBitmapData %dx%d Format=%s Stride=%d Scan0=%p\n",
            bd.Width, bd.Height, PixelFormatString(bd.PixelFormat),
            bd.Stride, bd.Scan0);

    if (pf == PixelFormat8bppIndexed) {
        struct palentry *pt;
        pt = build_paltbl(b);
        if (!pt) {
            free(p);
            return 0;
        }
        *paltbl = pt;
    } else {
        if (paltbl)
            *paltbl = 0;
    }

    *data = p;
    *format = fmt;

    if (draw_debug) dbg("\tSuccessfully created data from Bitmap, format=%s\n", fmt);
    return 1;
}

gb_Bitmap *gb_create_Bitmap_from_data(int width, int height,
                                      unsigned char *data, char *format,
                                      int ix, int iy, int iw, int ih)
{
    int bpp;
    PixelFormat pf;

    if (strcmp(format, "MSBGRA32") == 0) {
        pf = PixelFormat32bppARGB;
        bpp = 4;
    } else if (strcmp(format, "BGR24") == 0) {
        pf = PixelFormat24bppRGB;
        bpp = 3;
    } else
        return 0;

    Bitmap *b = new Bitmap(iw, ih, pf);
    BitmapData bd;
    bd.Width = iw;
    bd.Height = ih;
    bd.Stride = bpp * width;
    bd.PixelFormat = pf;
    bd.Scan0 = data + bpp * (iy * width + ix);
    bd.Reserved = NULL;
    Rect r(0, 0, iw, ih);
    Status st;
    st = b->LockBits(&r, 
                     ImageLockModeWrite | ImageLockModeUserInputBuf,
                     pf, &bd);
    if (st != Ok) {
        delete b;
        return 0;
    }
    b->UnlockBits(&bd);
    if (draw_debug) dbg("Successfully created Bitmap from data, format=%s\n", format);
    return (gb_Bitmap*)b;
}

extern "C"
gb_Bitmap *gb_create_temp_Bitmap_from_data(int width, int height,
                                           unsigned char *data, char *format,
                                           int ix, int iy, int iw, int ih)
{
    if (strcmp(format, "MSBGRA32") == 0) {
        /*
         * NB - this constructor doesn't copy the data.
         */
        Bitmap *b = new Bitmap(iw, ih,
                               4 * width,
                               PixelFormat32bppARGB,
                               data + 4 * (iy * width + ix));
        if (draw_debug) dbg("Successfully created temp Bitmap from data, format=%s\n", format);
        return (gb_Bitmap*)b;
    }
    if (draw_debug) dbg("Don't know how to create temp Bitmap from data for format=%s\n", format);
    return 0;
}
