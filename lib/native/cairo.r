#passthru #undef code
#passthru #include <cairo.h>
#passthru #include <cairo-xlib.h>
#passthru #include <cairo-svg.h>
#passthru #include <cairo-ps.h>
#passthru #include <cairo-pdf.h>
#passthru #include <cairo-xlib-xrender.h>
#passthru #include <cairo-ft.h>
#passthru #include <pango/pangocairo.h>
#passthru #include <pango/pangofc-fontmap.h>
#passthru #include <librsvg/rsvg.h>

static void pix_to_win(cairo_t *cr, double x1, double y1, double x2, double y2);
static void ensure(cairo_t *cr);
static cairo_operator_t convert_op(int op);
static void device_stroke_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2);
static void device_fill_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2);
static void device_clip_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2);

static cairo_user_data_key_t contextkey;
static cairo_user_data_key_t winkey;
static cairo_user_data_key_t pickey;
static cairo_user_data_key_t imdkey;

#begdef GetSelfCr()
cairo_t *self_cr;
dptr self_cr_dptr;
static struct inline_field_cache self_cr_ic;
self_cr_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_cr_ic);
if (!self_cr_dptr)
    syserr("Missing ptr field");
self_cr = (cairo_t *)IntVal(*self_cr_dptr);
if (!self_cr)
    runerr(152, self);
ensure(self_cr);
#enddef

#begdef GetSelfPattern()
cairo_pattern_t *self_pattern;
dptr self_pattern_dptr;
static struct inline_field_cache self_pattern_ic;
self_pattern_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_pattern_ic);
if (!self_pattern_dptr)
    syserr("Missing ptr field");
self_pattern = (cairo_pattern_t *)IntVal(*self_pattern_dptr);
if (!self_pattern)
    runerr(152, self);
#enddef

#begdef GetSelfSurface()
cairo_surface_t *self_surface;
dptr self_surface_dptr;
static struct inline_field_cache self_surface_ic;
self_surface_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_surface_ic);
if (!self_surface_dptr)
    syserr("Missing ptr field");
self_surface = (cairo_surface_t *)IntVal(*self_surface_dptr);
if (!self_surface)
    runerr(152, self);
#enddef

static struct sdescrip patternclassname = {13, "cairo.Pattern"};

#begdef PatternStaticParam(p, x)
cairo_pattern_t *x;
dptr x##_dptr;
static struct inline_field_cache x##_ic;
static struct inline_global_cache x##_igc;
if (!c_is(&p, (dptr)&patternclassname, &x##_igc))
    runerr(205, p);
x##_dptr = c_get_instance_data(&p, (dptr)&ptrf, &x##_ic);
if (!x##_dptr)
    syserr("Missing ptr field");
(x) = (cairo_pattern_t *)IntVal(*x##_dptr);
if (!(x))
    runerr(152, p);
#enddef

static struct sdescrip surfaceclassname = {13, "cairo.Surface"};

#begdef SurfaceStaticParam(p, x)
cairo_surface_t *x;
dptr x##_dptr;
static struct inline_field_cache x##_ic;
static struct inline_global_cache x##_igc;
if (!c_is(&p, (dptr)&surfaceclassname, &x##_igc))
    runerr(205, p);
x##_dptr = c_get_instance_data(&p, (dptr)&ptrf, &x##_ic);
if (!x##_dptr)
    syserr("Missing ptr field");
(x) = (cairo_surface_t *)IntVal(*x##_dptr);
if (!(x))
    runerr(152, p);
#enddef

static struct sdescrip crclassname = {13, "cairo.Context"};

#begdef CrStaticParam(p, x)
cairo_t *x;
dptr x##_dptr;
static struct inline_field_cache x##_ic;
static struct inline_global_cache x##_igc;
if (!c_is(&p, (dptr)&crclassname, &x##_igc))
    runerr(205, p);
x##_dptr = c_get_instance_data(&p, (dptr)&ptrf, &x##_ic);
if (!x##_dptr)
    syserr("Missing ptr field");
(x) = (cairo_t *)IntVal(*x##_dptr);
if (!(x))
    runerr(152, p);
#enddef

#begdef GetSelfSVG()
RsvgHandle *self_svg;
dptr self_svg_dptr;
static struct inline_field_cache self_svg_ic;
self_svg_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_svg_ic);
if (!self_svg_dptr)
    syserr("Missing ptr field");
self_svg = (RsvgHandle *)IntVal(*self_svg_dptr);
if (!self_svg)
    runerr(152, self);
#enddef

#define CheckSurfaceStatus(obj) do {if (cairo_surface_status(obj) == CAIRO_STATUS_NO_MEMORY) fatalerr(309,NULL);} while(0)
#define CheckPatternStatus(obj) do {if (cairo_pattern_status(obj) == CAIRO_STATUS_NO_MEMORY) fatalerr(309,NULL);} while(0)
#define CheckContextStatus(obj) do {if (cairo_status(obj) == CAIRO_STATUS_NO_MEMORY) fatalerr(309,NULL);} while(0)

static stringint drawops[] = {
   { 0, 12},
   {"atop",  CAIRO_OPERATOR_ATOP},
   {"clear", CAIRO_OPERATOR_CLEAR },
   {"dest", CAIRO_OPERATOR_DEST },
   {"dest atop", CAIRO_OPERATOR_DEST_ATOP },
   {"dest in", CAIRO_OPERATOR_DEST_IN },
   {"dest out", CAIRO_OPERATOR_DEST_OUT},
   {"dest over", CAIRO_OPERATOR_DEST_OVER },
   {"in",  CAIRO_OPERATOR_IN},
   {"out", CAIRO_OPERATOR_OUT},
   {"over", CAIRO_OPERATOR_OVER},
   {"source", CAIRO_OPERATOR_SOURCE},
   {"xor", CAIRO_OPERATOR_XOR},
};

static stringint linejoins[] = {
    {0, 3},
    {"bevel",    CAIRO_LINE_JOIN_BEVEL},
    {"miter",    CAIRO_LINE_JOIN_MITER},
    {"round",    CAIRO_LINE_JOIN_ROUND},
};

static stringint linecaps[] = {
    {0, 3},
    {"butt",    CAIRO_LINE_CAP_BUTT},
    {"round",   CAIRO_LINE_CAP_ROUND},
    {"square",  CAIRO_LINE_CAP_SQUARE},
};

static stringint fillrules[] = {
    {0, 2},
    {"even-odd",CAIRO_FILL_RULE_EVEN_ODD},
    {"winding", CAIRO_FILL_RULE_WINDING},
};

static stringint extends[] = {
    {0, 4},
    {"none", CAIRO_EXTEND_NONE},
    {"pad", CAIRO_EXTEND_PAD},
    {"reflect", CAIRO_EXTEND_REFLECT},
    {"repeat", CAIRO_EXTEND_REPEAT},
};

static void pop_word(dptr l, word *res)
{
    tended struct descrip e;
    if (!list_get(l, &e))
        syserr("pop_word: empty list");
    if (!cnv:C_integer(e, *res))
        syserr("pop_word: not an int");
}

static void pop_double(dptr l, double *res)
{
    tended struct descrip e;
    if (!list_get(l, &e))
        syserr("pop_double: empty list");
    if (!cnv:C_double(e, *res))
        syserr("pop_double: not a double");
}

static cairo_operator_t convert_op(int op)
{
    switch (op) {
        case PictOpAtop: 
            return CAIRO_OPERATOR_ATOP;
        case PictOpClear: 
            return CAIRO_OPERATOR_CLEAR;
        case PictOpDst: 
            return CAIRO_OPERATOR_DEST;
        case PictOpAtopReverse: 
            return CAIRO_OPERATOR_DEST_ATOP;
        case PictOpInReverse: 
            return CAIRO_OPERATOR_DEST_IN;
        case PictOpOutReverse: 
            return CAIRO_OPERATOR_DEST_OUT;
        case PictOpOverReverse: 
            return CAIRO_OPERATOR_DEST_OVER;
        case PictOpIn: 
            return CAIRO_OPERATOR_IN;
        case PictOpOut: 
            return CAIRO_OPERATOR_OUT;
        case PictOpOver: 
            return CAIRO_OPERATOR_OVER;
        case PictOpSrc: 
            return CAIRO_OPERATOR_SOURCE;
        case PictOpXor: 
            return CAIRO_OPERATOR_XOR;
        default: {
            syserr("Unexpected operator");
            return 0;
        }
    }
}

static wbp getwindow(cairo_t *cr)
{
    cairo_surface_t *surface = cairo_get_target(cr);
    if (cairo_surface_get_type(surface) == CAIRO_SURFACE_TYPE_XLIB)
        return (wbp)cairo_surface_get_user_data(surface, &winkey);
    else
        return 0;
}

static PangoLayout *getpangolayout(cairo_t *cr)
{
    return (PangoLayout *)cairo_get_user_data(cr, &contextkey);
}

function cairo_Context_set_font(self, val)
   if !cnv:string(val) then
      runerr(103, val)
    body {
       PangoFontDescription *fontdesc;
       wbp w;
       GetSelfCr();
       w = getwindow(self_cr);
       if (w) {
           wsp ws = w->window;
           wdp wd = ws->display;
           wfp tmp = loadfont(wd, buffstr(&val));
           if (!tmp) {
               LitWhy("No matching font in system");
               fail;
           }
           fontdesc = pango_fc_font_description_from_pattern(tmp->fsp->pattern, TRUE);
       } else {
           FcPattern *pat, *mat;
           FcResult result;
           char *ps = tofcpatternstr(buffstr(&val));
           pat = FcNameParse((FcChar8 *)ps);
           FcConfigSubstitute(NULL, pat, FcMatchPattern);
           FcDefaultSubstitute(pat);
           mat = FcFontMatch(NULL, pat, &result);
           fontdesc = pango_fc_font_description_from_pattern(mat, TRUE);
           FcPatternDestroy(pat);
           FcPatternDestroy(mat);
       }
       pango_layout_set_font_description(getpangolayout(self_cr), fontdesc);
       pango_font_description_free(fontdesc);
       return self;
    }
end

function cairo_Context_set_dash(self, offset, args[n])
    if !cnv:C_double(offset) then
       runerr(102, offset)
    body {
       double *d;
       int i;
       GetSelfCr();
       MemProtect(d = malloc(n * sizeof(double)));
       for (i = 0; i < n; ++i) {
           if (!cnv:C_double(args[i], d[i])) {
               free(d);
               runerr(102, args[i]);
           }
       }
       cairo_set_dash(self_cr, d, n, offset);
       free(d);
       return self;
    }
end

function cairo_Context_set_source_rgba(self, r, g, b, a)
    if !cnv:C_double(r) then
       runerr(102, r)
    if !cnv:C_double(g) then
       runerr(102, g)
    if !cnv:C_double(b) then
       runerr(102, b)
    if !def:C_double(a, 1.0) then
       runerr(102, a)
    body {
       GetSelfCr();
       cairo_set_source_rgba(self_cr, r, g, b, a);
       return self;
    }
end

function cairo_Context_set_source_pattern(self, pat)
    body {
       GetSelfCr();
       {
       PatternStaticParam(pat, pattern);
       cairo_set_source(self_cr, pattern);
       }
       return self;
    }
end

static void destroypic(void *data)
{
    unlink_sharedpicture((struct SharedPicture *)data);
}

static void clone_wc(cairo_t *cr)
{
    cairo_matrix_t matrix;
    PangoFontDescription *fontdesc;
    wbp w;
    wsp ws;
    wdp wd;
    wcp wc;

    w = getwindow(cr);
    if (!w)
        return;

    ws = w->window;
    wd = ws->display;
    wc = w->context;
    cairo_set_line_width(cr, wc->linewidth);
    if (wc->pattern) {
        cairo_surface_t *surface;
        cairo_pattern_t *pattern;
        struct SharedPicture *pic;
        pic = link_sharedpicture(wc->pattern);
        surface = cairo_xlib_surface_create_with_xrender_format(wd->display, 
                                                                pic->pix,
                                                                DefaultScreenOfDisplay(wd->display),
                                                                wd->pixfmt,
                                                                pic->width, pic->height);
        CheckSurfaceStatus(surface);
        pattern = cairo_pattern_create_for_surface(surface);
        CheckPatternStatus(pattern);
        cairo_pattern_set_user_data(pattern, &pickey, pic, destroypic);
        cairo_pattern_set_extend(pattern, CAIRO_EXTEND_REPEAT);
        cairo_set_source(cr, pattern);
        cairo_surface_destroy(surface);
        cairo_pattern_destroy(pattern);
    } else {
        cairo_set_source_rgba(cr,
                              wc->fg->color.red / 65535.0,
                              wc->fg->color.green / 65535.0,
                              wc->fg->color.blue / 65535.0,
                              wc->fg->color.alpha / 65535.0);
    }

    fontdesc = pango_fc_font_description_from_pattern(wc->font->fsp->pattern, TRUE);
    pango_layout_set_font_description(getpangolayout(cr), fontdesc);
    pango_font_description_free(fontdesc);

    if (wc->clipw >= 0) {
        cairo_rectangle(cr, wc->clipx, wc->clipy, wc->clipw, wc->cliph);
        cairo_clip(cr);
        cairo_new_path(cr);
    }
    cairo_matrix_init_translate(&matrix, wc->dx, wc->dy);
    cairo_set_matrix(cr, &matrix);
    if (wc->linestyle->i == EndDisc)
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
    cairo_set_operator(cr, convert_op(wc->drawop->i));
}

static void destroylayout(void *data)
{
    g_object_unref((PangoLayout *)data);
}

function cairo_Context_new_impl(sur)
    body {
       cairo_t *cr;
       PangoLayout *layout;
       {
       SurfaceStaticParam(sur, surface);
       cr = cairo_create(surface);
       CheckContextStatus(cr);
       layout = pango_cairo_create_layout(cr);
       cairo_set_user_data(cr, &contextkey, layout, destroylayout);
       clone_wc(cr);
       }
       return C_integer (word) cr;
    }
end

static void ensure(cairo_t *cr)
{
    wbp w;
    wsp ws;
    cairo_surface_t *surface;
    w = getwindow(cr);
    if (!w)
        return;
    surface = cairo_get_target(cr);
    ws = w->window;
    if (cairo_xlib_surface_get_drawable(surface) != ws->pix)
        cairo_xlib_surface_set_drawable(surface,
                                        ws->pix,
                                        ws->pixwidth, ws->pixheight);
}

static void pix_to_win(cairo_t *cr, double x1, double y1, double x2, double y2)
{
    int x, y, width, height;
    wbp w;
    wsp ws;
    wdp wd;
    w = getwindow(cr);
    if (!w)
        return;
    ws = w->window;
    if (!ws->win)
        return;
    wd = ws->display;
    range_extent(x1, y1, x2, y2, &x, &y, &width, &height);
    XRenderComposite(wd->display, PictOpSrc, ws->ppic, 0, ws->wpic,
                     x, y, 0, 0, x, y, width, height);
}

function cairo_Context_set_matrix_impl(self, xx, yx, xy, yy, x0, y0)
    if !cnv:C_double(xx) then
       runerr(102, xx)
    if !cnv:C_double(yx) then
       runerr(102, yx)
    if !cnv:C_double(xy) then
       runerr(102, xy)
    if !cnv:C_double(yy) then
       runerr(102, yy)
    if !cnv:C_double(x0) then
       runerr(102, x0)
    if !cnv:C_double(y0) then
       runerr(102, y0)
    body {
       cairo_matrix_t m;        
       GetSelfCr();
       cairo_matrix_init(&m, xx, yx, xy, yy, x0, y0);
       cairo_set_matrix(self_cr, &m);
       return self;
    }
end

function cairo_Context_get_matrix_impl(self)
    body {
       tended struct descrip result, tmp;
       cairo_matrix_t m;        
       GetSelfCr();
       cairo_get_matrix(self_cr, &m);
       create_list(6, &result);
       MakeReal(m.xx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.xy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.x0, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.y0, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_set_operator(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       stringint *e;
       GetSelfCr();
       e = stringint_lookup(drawops, buffstr(&val));
       if (!e) {
           LitWhy("Invalid operator");
           fail;
       }
       cairo_set_operator(self_cr, e->i);
       return self;
   }
end

function cairo_Context_translate(self, tx, ty)
    if !cnv:C_double(tx) then
       runerr(102, tx)
    if !cnv:C_double(ty) then
       runerr(102, ty)
    body {
       GetSelfCr();
       cairo_translate(self_cr, tx, ty);
       return self;
    }
end

function cairo_Context_scale(self, sx, sy)
    if !cnv:C_double(sx) then
       runerr(102, sx)
    if !cnv:C_double(sy) then
       runerr(102, sy)
    body {
       GetSelfCr();
       cairo_scale(self_cr, sx, sy);
       return self;
    }
end

function cairo_Context_rotate(self, r)
    if !cnv:C_double(r) then
       runerr(102, r)
    body {
       GetSelfCr();
       cairo_rotate(self_cr, r);
       return self;
    }
end

function cairo_Context_clip(self)
    body {
       GetSelfCr();
       cairo_clip(self_cr);
       return self;
    }
end

function cairo_Context_reset_clip(self)
    body {
       GetSelfCr();
       cairo_reset_clip(self_cr);
       return self;
    }
end

function cairo_Context_move_to(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       GetSelfCr();
       cairo_move_to(self_cr, x, y);
       return self;
    }
end

function cairo_Context_rel_move_to(self, dx, dy)
    if !cnv:C_double(dx) then
       runerr(102, dx)
    if !cnv:C_double(dy) then
       runerr(102, dy)
    body {
       GetSelfCr();
       cairo_rel_move_to(self_cr, dx, dy);
       return self;
    }
end

function cairo_Context_line_to(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       GetSelfCr();
       cairo_line_to(self_cr, x, y);
       return self;
    }
end

function cairo_Context_rel_line_to(self, dx, dy)
    if !cnv:C_double(dx) then
       runerr(102, dx)
    if !cnv:C_double(dy) then
       runerr(102, dy)
    body {
       GetSelfCr();
       cairo_rel_line_to(self_cr, dx, dy);
       return self;
    }
end

function cairo_Context_text_path(self, s)
   if !cnv:ucs(s) then
      runerr(128, s)
    body {
       PangoLayout *layout;
       GetSelfCr();
       layout = getpangolayout(self_cr);
       pango_cairo_update_layout(self_cr, layout);
       pango_layout_set_text(layout, StrLoc(UcsBlk(s).utf8), StrLen(UcsBlk(s).utf8));
       pango_cairo_layout_path(self_cr, layout);
       return self;
    }
end

function cairo_Context_set_line_width(self, w)
    if !cnv:C_double(w) then
       runerr(102, w)
    body {
       GetSelfCr();
       cairo_set_line_width(self_cr, w);
       return self;
    }
end

function cairo_Context_set_line_join(self, val)
    if !cnv:string(val) then
       runerr(103, val)
    body {
       stringint *e;
       GetSelfCr();
       e = stringint_lookup(linejoins, buffstr(&val));
       if (!e) {
           LitWhy("Invalid join");
           fail;
       }
       cairo_set_line_join(self_cr, e->i);
       return self;
    }
end

function cairo_Context_set_line_cap(self, val)
    if !cnv:string(val) then
       runerr(103, val)
    body {
       stringint *e;
       GetSelfCr();
       e = stringint_lookup(linecaps, buffstr(&val));
       if (!e) {
           LitWhy("Invalid cap");
           fail;
       }
       cairo_set_line_cap(self_cr, e->i);
       return self;
    }
end

function cairo_Context_set_fill_rule(self, val)
    if !cnv:string(val) then
       runerr(103, val)
    body {
       stringint *e;
       GetSelfCr();
       e = stringint_lookup(fillrules, buffstr(&val));
       if (!e) {
           LitWhy("Invalid fill rule");
           fail;
       }
       cairo_set_fill_rule(self_cr, e->i);
       return self;
    }
end

function cairo_Context_arc(self, xc, yc, r, a1, a2)
    if !cnv:C_double(xc) then
       runerr(102, xc)
    if !cnv:C_double(yc) then
       runerr(102, yc)
    if !cnv:C_double(r) then
       runerr(102, r)
    if !cnv:C_double(a1) then
       runerr(102, a1)
    if !cnv:C_double(a2) then
       runerr(102, a2)
    body {
       GetSelfCr();
       cairo_arc(self_cr, xc, yc, r, a1, a2);
       return self;
    }
end

function cairo_Context_rectangle(self, x, y, width, height)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    if !cnv:C_double(width) then
       runerr(102, width)
    if !cnv:C_double(height) then
       runerr(102, height)
    body {
       GetSelfCr();
       cairo_rectangle(self_cr, x, y, width, height);
       return self;
    }
end

function cairo_Context_curve_to(self, x1, y1, x2, y2, x3, y3)
    if !cnv:C_double(x1) then
       runerr(102, x1)
    if !cnv:C_double(y1) then
       runerr(102, y1)
    if !cnv:C_double(x2) then
       runerr(102, x2)
    if !cnv:C_double(y2) then
       runerr(102, y2)
    if !cnv:C_double(x3) then
       runerr(102, x3)
    if !cnv:C_double(y3) then
       runerr(102, y3)
    body {
       GetSelfCr();
       cairo_curve_to(self_cr, x1, y1, x2, y2, x3, y3);
       return self;
    }
end

function cairo_Context_rel_curve_to(self, dx1, dy1, dx2, dy2, dx3, dy3)
    if !cnv:C_double(dx1) then
       runerr(102, dx1)
    if !cnv:C_double(dy1) then
       runerr(102, dy1)
    if !cnv:C_double(dx2) then
       runerr(102, dx2)
    if !cnv:C_double(dy2) then
       runerr(102, dy2)
    if !cnv:C_double(dx3) then
       runerr(102, dx3)
    if !cnv:C_double(dy3) then
       runerr(102, dy3)
    body {
       GetSelfCr();
       cairo_curve_to(self_cr, dx1, dy1, dx2, dy2, dx3, dy3);
       return self;
    }
end

function cairo_Context_close_path(self)
    body {
       GetSelfCr();
       cairo_close_path(self_cr);
       return self;
    }
end

function cairo_Context_new_path(self)
    body {
       GetSelfCr();
       cairo_new_path(self_cr);
       return self;
    }
end

static void device_stroke_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2)
{
    struct point p1, p2, p3, p4;
    /* This gives a rectangle in user space.  Calculate the 4 corners of the rectangle. */
    cairo_stroke_extents(cr, x1, y1, x2, y2);
    p1.x = *x1; p1.y = *y1;
    p2.x = *x2; p2.y = *y1;
    p3.x = *x2; p3.y = *y2;
    p4.x = *x1; p4.y = *y2;
    /* Now translate the corners.  This will give a rectangle, but it may be rotated */
    cairo_user_to_device(cr, &p1.x, &p1.y);
    cairo_user_to_device(cr, &p2.x, &p2.y);
    cairo_user_to_device(cr, &p3.x, &p3.y);
    cairo_user_to_device(cr, &p4.x, &p4.y);
    /* Finally calculate the corners of the (not rotated) device
     * rectangle that encloses the rotated rectangle */
    *x1 = *x2 = p1.x;
    if (p2.x < *x1) *x1 = p2.x; else if (p2.x > *x2) *x2 = p2.x;
    if (p3.x < *x1) *x1 = p3.x; else if (p3.x > *x2) *x2 = p3.x;
    if (p4.x < *x1) *x1 = p4.x; else if (p4.x > *x2) *x2 = p4.x;
    *y1 = *y2 = p1.y;
    if (p2.y < *y1) *y1 = p2.y; else if (p2.y > *y2) *y2 = p2.y;
    if (p3.y < *y1) *y1 = p3.y; else if (p3.y > *y2) *y2 = p3.y;
    if (p4.y < *y1) *y1 = p4.y; else if (p4.y > *y2) *y2 = p4.y;
}

static void device_fill_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2)
{
    cairo_save(cr);
    cairo_identity_matrix(cr);
    cairo_fill_extents(cr, x1, y1, x2, y2);
    cairo_restore(cr);
}

static void device_clip_extents(cairo_t *cr, double *x1, double *y1, double *x2, double *y2)
{
    cairo_save(cr);
    cairo_identity_matrix(cr);
    cairo_clip_extents(cr, x1, y1, x2, y2);
    cairo_restore(cr);
}

function cairo_Context_stroke(self)
    body {
       double x1, y1, x2, y2;
       GetSelfCr();
       device_stroke_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_stroke (self_cr);
       pix_to_win(self_cr, x1, y1, x2, y2);
       return self;
    }
end

function cairo_Context_fill(self)
    body {
       double x1, y1, x2, y2;
       GetSelfCr();
       device_fill_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_fill (self_cr);
       pix_to_win(self_cr, x1, y1, x2, y2);
       return self;
    }
end

function cairo_Context_stroke_preserve(self)
    body {
       double x1, y1, x2, y2;
       GetSelfCr();
       device_stroke_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_stroke_preserve(self_cr);
       pix_to_win(self_cr, x1, y1, x2, y2);
       return self;
    }
end

function cairo_Context_fill_preserve(self)
    body {
       double x1, y1, x2, y2;
       GetSelfCr();
       device_fill_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_fill_preserve(self_cr);
       pix_to_win(self_cr, x1, y1, x2, y2);
       return self;
    }
end

function cairo_Context_paint(self)
    body {
       double x1, y1, x2, y2;
       GetSelfCr();
       device_clip_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_paint(self_cr);
       pix_to_win(self_cr, x1, y1, x2, y2);
       return self;
    }
end

function cairo_Context_mask(self, pat)
    body {
       GetSelfCr();
       {
       double x1, y1, x2, y2;
       PatternStaticParam(pat, p);
       device_clip_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_mask(self_cr, p);
       pix_to_win(self_cr, x1, y1, x2, y2);
       }
       return self;
    }
end

function cairo_Context_mask_surface(self, sur, x, y)
    if !def:C_double(x, 0.0) then
       runerr(102, x)
    if !def:C_double(y, 0.0) then
       runerr(102, y)
    body {
       GetSelfCr();
       {
       double x1, y1, x2, y2;
       SurfaceStaticParam(sur, surface);
       device_clip_extents(self_cr, &x1, &y1, &x2, &y2);
       cairo_mask_surface(self_cr, surface, x, y);
       pix_to_win(self_cr, x1, y1, x2, y2);
       }
       return self;
    }
end

function cairo_Context_close(self)
    body {
       GetSelfCr();
       cairo_destroy(self_cr);
       *self_cr_dptr = zerodesc;
       return self;
    }
end

function cairo_Context_save(self)
    body {
       GetSelfCr();
       cairo_save(self_cr);
       return self;
    }
end

function cairo_Context_restore(self)
    body {
       GetSelfCr();
       cairo_restore(self_cr);
       return self;
    }
end

function cairo_Context_get_stroke_extents(self)
    body {
       tended struct descrip result, tmp;
       double x1, y1, x2, y2;
       GetSelfCr();
       cairo_stroke_extents(self_cr, &x1, &y1, &x2, &y2);
       create_list(4, &result);
       MakeReal(x1, &tmp);
       list_put(&result, &tmp);
       MakeReal(y1, &tmp);
       list_put(&result, &tmp);
       MakeReal(x2, &tmp);
       list_put(&result, &tmp);
       MakeReal(y2, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_get_fill_extents(self)
    body {
       tended struct descrip result, tmp;
       double x1, y1, x2, y2;
       GetSelfCr();
       cairo_fill_extents(self_cr, &x1, &y1, &x2, &y2);
       create_list(4, &result);
       MakeReal(x1, &tmp);
       list_put(&result, &tmp);
       MakeReal(y1, &tmp);
       list_put(&result, &tmp);
       MakeReal(x2, &tmp);
       list_put(&result, &tmp);
       MakeReal(y2, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_get_clip_extents(self)
    body {
       tended struct descrip result, tmp;
       double x1, y1, x2, y2;
       GetSelfCr();
       cairo_clip_extents(self_cr, &x1, &y1, &x2, &y2);
       create_list(4, &result);
       MakeReal(x1, &tmp);
       list_put(&result, &tmp);
       MakeReal(y1, &tmp);
       list_put(&result, &tmp);
       MakeReal(x2, &tmp);
       list_put(&result, &tmp);
       MakeReal(y2, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_get_path_extents(self)
    body {
       tended struct descrip result, tmp;
       double x1, y1, x2, y2;
       GetSelfCr();
       cairo_path_extents(self_cr, &x1, &y1, &x2, &y2);
       create_list(4, &result);
       MakeReal(x1, &tmp);
       list_put(&result, &tmp);
       MakeReal(y1, &tmp);
       list_put(&result, &tmp);
       MakeReal(x2, &tmp);
       list_put(&result, &tmp);
       MakeReal(y2, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_user_to_device(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       tended struct descrip result, tmp;
       GetSelfCr();
       cairo_user_to_device(self_cr, &x, &y);
       create_list(2, &result);
       MakeReal(x, &tmp);
       list_put(&result, &tmp);
       MakeReal(y, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_device_to_user(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       tended struct descrip result, tmp;
       GetSelfCr();
       cairo_device_to_user(self_cr, &x, &y);
       create_list(2, &result);
       MakeReal(x, &tmp);
       list_put(&result, &tmp);
       MakeReal(y, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_in_stroke(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       GetSelfCr();
       if (cairo_in_stroke(self_cr, x, y))
           return self;
       else
           fail;
    }
end

function cairo_Context_in_fill(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       GetSelfCr();
       if (cairo_in_fill(self_cr, x, y))
           return self;
       else
           fail;
    }
end

function cairo_Context_in_clip(self, x, y)
    if !cnv:C_double(x) then
       runerr(102, x)
    if !cnv:C_double(y) then
       runerr(102, y)
    body {
       GetSelfCr();
       if (cairo_in_clip(self_cr, x, y))
           return self;
       else
           fail;
    }
end

function cairo_Context_get_path_impl(self, flat)
    body {
       tended struct descrip result, tmp;
       cairo_path_t *path;
       cairo_path_data_t *data;
       int i, j;
       GetSelfCr();
       if (!isflag(&flat))
           runerr(171, flat);
       if (is:null(flat))
           path = cairo_copy_path(self_cr);
       else
           path = cairo_copy_path_flat(self_cr);
       create_list(path->num_data, &result);
       for (i = 0; i < path->num_data; i += path->data[i].header.length) {
           data = &path->data[i];
           switch (data->header.type) {
               case CAIRO_PATH_MOVE_TO: {
                   MakeInt(0, &tmp);
                   list_put(&result, &tmp);
                   MakeReal(data[1].point.x, &tmp);
                   list_put(&result, &tmp);
                   MakeReal(data[1].point.y, &tmp);
                   list_put(&result, &tmp);
                   break;
               }
               case CAIRO_PATH_LINE_TO: {
                   MakeInt(1, &tmp);
                   list_put(&result, &tmp);
                   MakeReal(data[1].point.x, &tmp);
                   list_put(&result, &tmp);
                   MakeReal(data[1].point.y, &tmp);
                   list_put(&result, &tmp);
                   break;
               }
               case CAIRO_PATH_CURVE_TO: {
                   MakeInt(2, &tmp);
                   list_put(&result, &tmp);
                   for (j = 1; j <= 3; ++j) {
                       MakeReal(data[j].point.x, &tmp);
                       list_put(&result, &tmp);
                       MakeReal(data[j].point.y, &tmp);
                       list_put(&result, &tmp);
                   }
                   break;
               }
               case CAIRO_PATH_CLOSE_PATH: {
                   MakeInt(3, &tmp);
                   break;
               }
           }
       }
       cairo_path_destroy (path);
       return result;
    }
end

static void need_path_data(cairo_path_data_t **d, int *na, int n)
{
    if (n >= *na) {
        *na = n + 32;
        MemProtect(*d = realloc(*d, *na * sizeof(cairo_path_data_t)));
    }
}

function cairo_Context_append_path_impl(self, l)
    if !is:list(l) then
       runerr(108, l)
    body {
       cairo_path_t path;
       cairo_path_data_t *d;
       int n, na;
       GetSelfCr();
       n = na = 0;
       d = 0;
       while (ListBlk(l).size > 0) {
           word kind;
           pop_word(&l, &kind);
           switch (kind) {
               case 0: {
                   double x, y;
                   pop_double(&l, &x);
                   pop_double(&l, &y);
                   need_path_data(&d, &na, n + 2);
                   d[n].header.type = CAIRO_PATH_MOVE_TO;
                   d[n].header.length = 2;
                   d[n + 1].point.x = x;
                   d[n + 1].point.y = y;
                   n += 2;
                   break;
               }
               case 1: {
                   double x, y;
                   pop_double(&l, &x);
                   pop_double(&l, &y);
                   need_path_data(&d, &na, n + 2);
                   d[n].header.type = CAIRO_PATH_LINE_TO;
                   d[n].header.length = 2;
                   d[n + 1].point.x = x;
                   d[n + 1].point.y = y;
                   n += 2;
                   break;
               }
               case 2: {
                   double x1, y1, x2, y2, x3, y3;
                   pop_double(&l, &x1);
                   pop_double(&l, &y1);
                   pop_double(&l, &x2);
                   pop_double(&l, &y2);
                   pop_double(&l, &x3);
                   pop_double(&l, &y3);
                   need_path_data(&d, &na, n + 4);
                   d[n].header.type = CAIRO_PATH_CURVE_TO;
                   d[n].header.length = 4;
                   d[n + 1].point.x = x1;
                   d[n + 1].point.y = y1;
                   d[n + 2].point.x = x2;
                   d[n + 2].point.y = y2;
                   d[n + 3].point.x = x3;
                   d[n + 3].point.y = y3;
                   n += 4;
                   break;
               }
               case 3: {
                   need_path_data(&d, &na, n + 1);
                   d[n].header.type = CAIRO_PATH_CLOSE_PATH;
                   d[n].header.length = 1;
                   n++;
                   break;
               }
               default:
                   syserr("Bad kind of path element");
           }
       }
       path.status = CAIRO_STATUS_SUCCESS;
       path.data = d;
       path.num_data = n;
       cairo_append_path(self_cr, &path);
       free(d);
       return self;
    }
end

function cairo_Context_set_source_extend(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       stringint *e;
       GetSelfCr();
       e = stringint_lookup(extends, buffstr(&val));
       if (!e) {
           LitWhy("Invalid extend choice");
           fail;
       }
       cairo_pattern_set_extend(cairo_get_source(self_cr), e->i);
       return self;
   }
end

function cairo_Context_set_source_matrix_impl(self, xx, yx, xy, yy, x0, y0)
    if !cnv:C_double(xx) then
       runerr(102, xx)
    if !cnv:C_double(yx) then
       runerr(102, yx)
    if !cnv:C_double(xy) then
       runerr(102, xy)
    if !cnv:C_double(yy) then
       runerr(102, yy)
    if !cnv:C_double(x0) then
       runerr(102, x0)
    if !cnv:C_double(y0) then
       runerr(102, y0)
    body {
       cairo_matrix_t m;        
       GetSelfCr();
       cairo_matrix_init(&m, xx, yx, xy, yy, x0, y0);
       cairo_pattern_set_matrix(cairo_get_source(self_cr), &m);
       return self;
    }
end

function cairo_Context_get_source_matrix_impl(self)
    body {
       tended struct descrip result, tmp;
       cairo_matrix_t m;        
       GetSelfCr();
       cairo_pattern_get_matrix(cairo_get_source(self_cr), &m);
       create_list(6, &result);
       MakeReal(m.xx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.xy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.x0, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.y0, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Context_get_current_point(self)
    body {
       tended struct descrip result, tmp;
       double x, y;
       GetSelfCr();
       if (!cairo_has_current_point(self_cr))
           fail;
       cairo_get_current_point(self_cr, &x, &y);
       create_list(2, &result);
       MakeReal(x, &tmp);
       list_put(&result, &tmp);
       MakeReal(y, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Pattern_close(self)
    body {
       GetSelfPattern();
       cairo_pattern_destroy(self_pattern);
       *self_pattern_dptr = zerodesc;
       return self;
    }
end

function cairo_Gradient_add_color_stop_rgba(self, offset, r, g, b, a)
    if !cnv:C_double(offset) then
       runerr(102, offset)
    if !cnv:C_double(r) then
       runerr(102, r)
    if !cnv:C_double(g) then
       runerr(102, g)
    if !cnv:C_double(b) then
       runerr(102, b)
    if !def:C_double(a, 1.0) then
       runerr(102, a)
    body {
       GetSelfPattern();
       cairo_pattern_add_color_stop_rgba(self_pattern, offset, r, g, b, a);
       return self;
    }
end

function cairo_LinearGradient_new_impl(x0, y0, x1, y1)
    if !cnv:C_double(x0) then
       runerr(102, x0)
    if !cnv:C_double(y0) then
       runerr(102, y0)
    if !cnv:C_double(x1) then
       runerr(102, x1)
    if !cnv:C_double(y1) then
       runerr(102, y1)
    body {
       cairo_pattern_t *pattern;
       pattern = cairo_pattern_create_linear(x0, y0, x1, y1);
       CheckPatternStatus(pattern);
       return C_integer (word) pattern;
    }
end

function cairo_RadialGradient_new_impl(cx0, cy0, r0, cx1, cy1, r1)
    if !cnv:C_double(cx0) then
       runerr(102, cx0)
    if !cnv:C_double(cy0) then
       runerr(102, cy0)
    if !cnv:C_double(r0) then
       runerr(102, r0)
    if !cnv:C_double(cx1) then
       runerr(102, cx1)
    if !cnv:C_double(cy1) then
       runerr(102, cy1)
    if !cnv:C_double(r1) then
       runerr(102, r1)
    body {
       cairo_pattern_t *pattern;
       pattern = cairo_pattern_create_radial(cx0, cy0, r0, cx1, cy1, r1);
       CheckPatternStatus(pattern);
       return C_integer (word) pattern;
    }
end


function cairo_Pattern_set_matrix_impl(self, xx, yx, xy, yy, x0, y0)
    if !cnv:C_double(xx) then
       runerr(102, xx)
    if !cnv:C_double(yx) then
       runerr(102, yx)
    if !cnv:C_double(xy) then
       runerr(102, xy)
    if !cnv:C_double(yy) then
       runerr(102, yy)
    if !cnv:C_double(x0) then
       runerr(102, x0)
    if !cnv:C_double(y0) then
       runerr(102, y0)
    body {
       cairo_matrix_t m;        
       GetSelfPattern();
       cairo_matrix_init(&m, xx, yx, xy, yy, x0, y0);
       cairo_pattern_set_matrix(self_pattern, &m);
       return self;
    }
end

function cairo_Pattern_get_matrix_impl(self)
    body {
       tended struct descrip result, tmp;
       cairo_matrix_t m;        
       GetSelfPattern();
       cairo_pattern_get_matrix(self_pattern, &m);
       create_list(6, &result);
       MakeReal(m.xx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yx, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.xy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.yy, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.x0, &tmp);
       list_put(&result, &tmp);
       MakeReal(m.y0, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_Pattern_set_extend(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       stringint *e;
       GetSelfPattern();
       e = stringint_lookup(extends, buffstr(&val));
       if (!e) {
           LitWhy("Invalid extend choice");
           fail;
       }
       cairo_pattern_set_extend(self_pattern, e->i);
       return self;
   }
end

static void destroywin(void *data)
{
    freewbinding((wbp)data);
}

function cairo_WindowSurface_new_impl(win)
    body {
       cairo_surface_t *surface;
       wsp ws;
       wdp wd;
       wcp wc;
       wbp w2;
       {
       WindowStaticParam(win, w);
       ws = w->window;
       wd = ws->display;
       wc = w->context;
       surface = cairo_xlib_surface_create_with_xrender_format(wd->display, 
                                                               ws->pix,
                                                               DefaultScreenOfDisplay(wd->display),
                                                               wd->pixfmt,
                                                               ws->pixwidth, ws->pixheight);

       CheckSurfaceStatus(surface);
       w2 = alcwbinding(wd);
       w2->window = linkwindow(ws);
       w2->context = linkcontext(wc);
       cairo_surface_set_user_data(surface, &winkey, w2, destroywin);
       }
       return C_integer (word) surface;
    }
end

function cairo_Surface_close(self)
    body {
       GetSelfSurface();
       cairo_surface_destroy(self_surface);
       *self_surface_dptr = zerodesc;
       return self;
    }
end

function cairo_SVGSurface_new_impl(filename, width, height)
   if !cnv:string(filename) then
      runerr(103, filename)
    if !cnv:C_double(width) then
       runerr(102, width)
    if !cnv:C_double(height) then
       runerr(102, height)
    body {
       cairo_surface_t *surface;
       surface = cairo_svg_surface_create(buffstr(&filename), width, height);
       CheckSurfaceStatus(surface);
       return C_integer (word) surface;
    }
end

function cairo_PostScriptSurface_new_impl(filename, width, height)
   if !cnv:string(filename) then
      runerr(103, filename)
    if !cnv:C_double(width) then
       runerr(102, width)
    if !cnv:C_double(height) then
       runerr(102, height)
    body {
       cairo_surface_t *surface;
       surface = cairo_ps_surface_create(buffstr(&filename), width, height);
       CheckSurfaceStatus(surface);
       return C_integer (word) surface;
    }
end

function cairo_PDFSurface_new_impl(filename, width, height)
   if !cnv:string(filename) then
      runerr(103, filename)
    if !cnv:C_double(width) then
       runerr(102, width)
    if !cnv:C_double(height) then
       runerr(102, height)
    body {
       cairo_surface_t *surface;
       surface = cairo_pdf_surface_create(buffstr(&filename), width, height);
       CheckSurfaceStatus(surface);
       return C_integer (word) surface;
    }
end

function cairo_SurfacePattern_new_impl(sur)
    body {
       cairo_pattern_t *pattern;
       SurfaceStaticParam(sur, surface);
       pattern = cairo_pattern_create_for_surface(surface);
       CheckPatternStatus(pattern);
       return C_integer (word) pattern;
    }
end

function cairo_SolidPattern_new_impl(r, g, b, a)
    if !cnv:C_double(r) then
       runerr(102, r)
    if !cnv:C_double(g) then
       runerr(102, g)
    if !cnv:C_double(b) then
       runerr(102, b)
    if !def:C_double(a, 1.0) then
       runerr(102, a)
    body {
       cairo_pattern_t *pattern;
       pattern = cairo_pattern_create_rgba(r, g, b, a);
       CheckPatternStatus(pattern);
       return C_integer (word) pattern;
    }
end

function cairo_RecordingSurface_new_impl(x, y, width, height)
    body {
       cairo_surface_t *surface;
       if (is:null(x))
           surface = cairo_recording_surface_create(CAIRO_CONTENT_COLOR_ALPHA, NULL);
       else {
           cairo_rectangle_t r;
           if (!cnv:C_double(x, r.x))
               runerr(102, x);
           if (!cnv:C_double(y, r.y))
               runerr(102, y);
           if (!cnv:C_double(width, r.width))
               runerr(102, width);
           if (!cnv:C_double(height, r.height))
               runerr(102, height);
           surface = cairo_recording_surface_create(CAIRO_CONTENT_COLOR_ALPHA, &r);
       }
       CheckSurfaceStatus(surface);
       return C_integer (word) surface;
    }
end

function cairo_RecordingSurface_get_extents(self)
    body {
       tended struct descrip result, tmp;
       cairo_rectangle_t r;
       GetSelfSurface();
       cairo_recording_surface_get_extents(self_surface, &r);
       create_list(4, &result);
       MakeReal(r.x, &tmp);
       list_put(&result, &tmp);
       MakeReal(r.y, &tmp);
       list_put(&result, &tmp);
       MakeReal(r.width, &tmp);
       list_put(&result, &tmp);
       MakeReal(r.height, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_RecordingSurface_ink_extents(self)
    body {
       tended struct descrip result, tmp;
       double x, y, width, height;
       GetSelfSurface();
       cairo_recording_surface_ink_extents(self_surface, &x, &y, &width, &height);
       create_list(4, &result);
       MakeReal(x, &tmp);
       list_put(&result, &tmp);
       MakeReal(y, &tmp);
       list_put(&result, &tmp);
       MakeReal(width, &tmp);
       list_put(&result, &tmp);
       MakeReal(height, &tmp);
       list_put(&result, &tmp);
       return result;
    }
end

function cairo_PagedSurface_copy_page(self)
    body {
       GetSelfSurface();
       cairo_surface_copy_page(self_surface);
       return self;
    }
end

function cairo_PagedSurface_show_page(self)
    body {
       GetSelfSurface();
       cairo_surface_show_page(self_surface);
       return self;
    }
end

static void destroyimd(void *data)
{
    unlinkimgdata((struct imgdata *)data);
}

function cairo_ImageSurface_new_impl(pix)
    body {
       cairo_surface_t *surface;
       {
       PixelsStaticParam(pix, imd);
       surface = cairo_image_surface_create_for_data(imd->data,
                                                     CAIRO_FORMAT_ARGB32,
                                                     imd->width, imd->height,
                                                     4 * imd->width);
       CheckSurfaceStatus(surface);
       cairo_surface_set_user_data(surface, &imdkey, linkimgdata(imd), destroyimd);
       }
       return C_integer (word) surface;
    }
end

function cairo_ImageSurface_get_width(self)
    body {
        GetSelfSurface();
        return C_integer cairo_image_surface_get_width(self_surface);
    }
end

function cairo_ImageSurface_get_height(self)
    body {
        GetSelfSurface();
        return C_integer cairo_image_surface_get_height(self_surface);
    }
end

static int is_svg_filename(dptr data)
{
    return StrLen(*data) <= 2048 &&
        ((StrLen(*data) >= 6 && strncasecmp(StrLoc(*data) + StrLen(*data) - 5, ".svgz", 5) == 0) ||
         (StrLen(*data) >= 5 && strncasecmp(StrLoc(*data) + StrLen(*data) - 4, ".svg", 4) == 0) ||
         (StrLen(*data) >= 5 && strncasecmp(StrLoc(*data) + StrLen(*data) - 4, ".xml", 4) == 0));
}

function cairo_SVG_new_impl(data)
   if !cnv:string(data) then
      runerr(103, data)
    body {
       RsvgHandle *h;
       GError *err = 0;
       g_type_init();
       if (is_svg_filename(&data))
           h = rsvg_handle_new_from_file(buffstr(&data),
                                         &err);
       else
           h = rsvg_handle_new_from_data((const guint8 *)StrLoc(data),
                                         StrLen(data),
                                         &err);
       if (!h) {
           why(err->message);
           g_error_free(err);
           fail;
       }
       return C_integer (word) h;
    }
end

function cairo_SVG_get_width(self, id)
    body {
        RsvgDimensionData dimensions;
        char *s2;
        GetSelfSVG();
        if (is:null(id))
            s2 = 0;
        else {
            if (!cnv:string(id, id))
                runerr(103, id);
            s2 = buffstr(&id);
        }
        rsvg_handle_get_dimensions_sub(self_svg, &dimensions, s2);
        return C_integer dimensions.width;
    }
end

function cairo_SVG_get_height(self, id)
    body {
        RsvgDimensionData dimensions;
        char *s2;
        GetSelfSVG();
        if (is:null(id))
            s2 = 0;
        else {
            if (!cnv:string(id, id))
                runerr(103, id);
            s2 = buffstr(&id);
        }
        rsvg_handle_get_dimensions_sub(self_svg, &dimensions, s2);
        return C_integer dimensions.height;
    }
end

function cairo_SVG_get_x(self, id)
   if !cnv:string(id) then
      runerr(103, id)
    body {
        RsvgPositionData pos;
        GetSelfSVG();
        rsvg_handle_get_position_sub(self_svg, &pos, buffstr(&id));
        return C_integer pos.x;
    }
end

function cairo_SVG_get_y(self, id)
   if !cnv:string(id) then
      runerr(103, id)
    body {
        RsvgPositionData pos;
        GetSelfSVG();
        rsvg_handle_get_position_sub(self_svg, &pos, buffstr(&id));
        return C_integer pos.y;
    }
end

function cairo_SVG_has_sub(self, id)
   if !cnv:string(id) then
      runerr(103, id)
    body {
        GetSelfSVG();
        if (rsvg_handle_has_sub(self_svg, buffstr(&id)))
            return nulldesc;
        else
            fail;
    }
end

function cairo_SVG_get_title(self)
    body {
        tended struct descrip str, result;
        char *s;
        GetSelfSVG();
        s = (char *)rsvg_handle_get_title(self_svg);
        if (!s)
            fail;
        cstr2string(s, &str);
        if (!string2ucs(&str, &result))
            fail;
        return result;
    }
end

function cairo_SVG_get_desc(self)
    body {
        tended struct descrip str, result;
        char *s;
        GetSelfSVG();
        s = (char *)rsvg_handle_get_desc(self_svg);
        if (!s)
            fail;
        cstr2string(s, &str);
        if (!string2ucs(&str, &result))
            fail;
        return result;
    }
end

function cairo_SVG_get_metadata(self)
    body {
        tended struct descrip str, result;
        char *s;
        GetSelfSVG();
        s = (char *)rsvg_handle_get_metadata(self_svg);
        if (!s)
            fail;
        cstr2string(s, &str);
        if (!string2ucs(&str, &result))
            fail;
        return result;
    }
end

function cairo_SVG_render(self, context, id)
    body {
        char *s2;
        double x1, y1, x2, y2;
        GetSelfSVG();
        {
        CrStaticParam(context, cr);
        if (is:null(id))
            s2 = 0;
        else {
            if (!cnv:string(id, id))
                runerr(103, id);
            s2 = buffstr(&id);
        }
        device_clip_extents(cr, &x1, &y1, &x2, &y2);
        rsvg_handle_render_cairo_sub(self_svg, cr, s2);
        pix_to_win(cr, x1, y1, x2, y2);
        }
        return nulldesc;
    }
end

function cairo_SVG_close(self)
    body {
       GetSelfSVG();
       g_object_unref(self_svg);
       *self_svg_dptr = zerodesc;
       return self;
    }
end
