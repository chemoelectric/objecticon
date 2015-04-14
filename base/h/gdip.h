
typedef struct gb_Bitmap gb_Bitmap;
typedef struct gb_Font gb_Font;

typedef DWORD gb_Color;

typedef struct gb_Draw {
   HWND win;
   gb_Bitmap *pix;
   int clipx, clipy, clipw, cliph;
   gb_Font *font;
   gb_Color fg, bg;
   gb_Bitmap *pattern;
   double linewidth;
} gb_Draw;

#ifdef __cplusplus
struct point {
    double x;
    double y;
};
#endif


#ifdef __cplusplus
extern "C" {
#endif

void gb_initialize(void);
gb_Bitmap *gb_create_Bitmap(int width, int height, gb_Color bg, gb_Bitmap *cp);
gb_Bitmap *gb_create_empty_Bitmap(int width, int height);
void gb_free_Bitmap(gb_Bitmap *bm);
void gb_drawrectangle(gb_Draw *d, int x, int y, int width, int height, int thick);
void gb_fillrectangle(gb_Draw *d, int x, int y, int width, int height);
void gb_erasearea(gb_Draw *d, int x, int y, int width, int height);
void gb_drawstring(gb_Draw *d, int x, int y, WCHAR *str, int length);
void gb_drawarc(gb_Draw *d, double cx, double cy, double rx, double ry, double angle1, double angle2);
void gb_drawlines(gb_Draw *d, struct point *points, int npoints,
                      int ex_x, int ex_y, int ex_width, int ex_height);
float gb_textwidth(gb_Draw *d, WCHAR *str, int length);
void gb_do_paint(HWND hwnd, gb_Bitmap *pix);
void gb_copyarea(gb_Bitmap *src, int x, int y, int width, int height, gb_Draw *d, int x2, int y2);
gb_Color gb_make_Color(int a, int r, int g, int b);
gb_Color gb_getpixel(gb_Bitmap *bm, int x, int y);
void gb_setpixel(gb_Bitmap *bm, int x, int y, BYTE a, BYTE r, BYTE g, BYTE b);
void gb_pix_to_win(gb_Draw *d, int x, int y, int width, int height);
gb_Font *gb_create_Font(HDC hdc, HFONT hfont);
void gb_get_Bitmap_size(gb_Bitmap *bm, UINT *width, UINT *height);
#ifdef __cplusplus
}
#endif
