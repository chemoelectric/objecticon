
typedef struct gb_Bitmap gb_Bitmap;
typedef struct gb_Font gb_Font;

typedef DWORD gb_Color;

typedef struct gb_Draw {
   HWND win;
   gb_Bitmap *pix;
   int clipx, clipy, clipw, cliph;
   int holding;
   gb_Font *font;
   gb_Color fg, bg;
   gb_Bitmap *pattern;
   double linewidth;
   int drawop;
   int linejoin;
   int lineend;
} gb_Draw;

#define EndFlat      0   // LineCapFlat
#define EndSquare    1   // LineCapSquare
#define EndRound     2   // LineCapRound
#define EndPoint     3   // LineCapTriangle

#define JoinBevel    1   // LineJoinBevel
#define JoinRound    2   // LineJoinRound
#define JoinMiter    3   // LineJoinMiterClipped

#ifdef __cplusplus
struct point {
    double x;
    double y;
};

struct triangle {
    struct point p1, p2, p3;
};

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
#define FONTFLAG_THIN           0x00000100
#define FONTFLAG_LIGHT          0x00000200
#define FONTFLAG_MEDIUM         0x00000400
#define FONTFLAG_DEMIBOLD       0x00000800
#define FONTFLAG_BOLD           0x00001000

#define FONTATT_WIDTH           0x10000000
#define FONTFLAG_CONDENSED      0x00002000
#define FONTFLAG_NARROW         0x00004000
#define FONTFLAG_NORMAL         0x00008000
#define FONTFLAG_WIDE           0x00010000
#define FONTFLAG_EXTENDED       0x00020000

#endif


#ifdef __cplusplus
extern "C" {
#endif
typedef void (*gb_fatalerr_func)(char *fmt, ...);
void gb_initialize(gb_fatalerr_func f);
gb_Bitmap *gb_create_Bitmap(int width, int height, gb_Color bg, gb_Bitmap *cp);
gb_Bitmap *gb_create_empty_Bitmap(int width, int height);
gb_Bitmap *gb_load_Bitmap_file(char *filename);
gb_Bitmap *gb_load_Bitmap_data(BYTE *data, UINT length);
void gb_free_Bitmap(gb_Bitmap *bm);
void gb_draw_Bitmap(gb_Draw *d, int x, int y, gb_Bitmap *bm, int copy);
void gb_drawrectangle(gb_Draw *d, int x, int y, int width, int height, int thick);
void gb_fillrectangle(gb_Draw *d, int x, int y, int width, int height);
void gb_erasearea(gb_Draw *d, int x, int y, int width, int height);
void gb_drawstring(gb_Draw *d, int x, int y, WCHAR *str, int length);
void gb_drawarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2);
void gb_fillarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2);
void gb_drawlines(gb_Draw *d, struct point *points, int npoints);
void gb_fillpolygon(gb_Draw *d, struct point *points, int npoints);
void gb_filltriangles(gb_Draw *d, struct triangle *tris, int ntris);
float gb_textwidth(gb_Draw *d, WCHAR *str, int length);
void gb_do_paint(HWND hwnd, gb_Bitmap *pix);
void gb_copyarea(gb_Bitmap *src, int x, int y, int width, int height, gb_Draw *d, int x2, int y2);
gb_Color gb_make_Color(int a, int r, int g, int b);
gb_Color gb_getpixel(gb_Bitmap *bm, int x, int y);
void gb_setpixel(gb_Bitmap *bm, int x, int y, BYTE a, BYTE r, BYTE g, BYTE b);
void gb_pix_to_win(gb_Draw *d, int x, int y, int width, int height);
gb_Font *gb_create_Font(HDC hdc, HFONT hfont);
void gb_get_Bitmap_size(gb_Bitmap *bm, UINT *width, UINT *height);

gb_Font *gb_find_Font(char *family, int flags, double size);
void gb_get_metrics(HDC dc, gb_Font *f, int *ascent, int *descent, int *maxwidth);
HICON gb_get_HICON(gb_Bitmap *bm);

#ifdef __cplusplus
}
#endif
