/*
 * File: fwindow.r - Icon graphics interface
 *
 */

#ifdef Graphics

/*
 * Global variables.
 *  the binding for the console window - FILE * for simplicity,
 *  &col, &row, &x, &y, &interval, timestamp, and modifier keys.
 */

#define MAXPOINTS 256

static struct sdescrip wclassname = {15, "graphics.Window"};

static struct sdescrip wbpf = {3, "wbp"};

#begdef WindowStaticParam(p, w)
wbp w;
dptr w##_dptr;
static struct inline_field_cache w##_ic;
static struct inline_global_cache w##_igc;
if (!c_is(&p, (dptr)&wclassname, &w##_igc))
    runerr(205, p);
w##_dptr = c_get_instance_data(&p, (dptr)&wbpf, &w##_ic);
if (!w##_dptr)
    syserr("Missing wbp field");
(w) = (wbp)IntVal(*w##_dptr);
if (!(w))
    runerr(142, p);
#enddef

#begdef GetSelfW()
wbp self_w;
dptr self_w_dptr;
static struct inline_field_cache self_w_ic;
self_w_dptr = c_get_instance_data(&self, (dptr)&wbpf, &self_w_ic);
if (!self_w_dptr)
    syserr("Missing wbp field");
self_w = (wbp)IntVal(*self_w_dptr);
if (!self_w)
    runerr(142, self);
#enddef

function graphics_Window_wcreate(display)
   body {
      wbp w;
      char *s2;
      inattr = 1;
      wconfig = 0;

      if (is:null(display))
          s2 = 0;
      else {
         if (!cnv:string(display, display))
             runerr(103, display);
         s2 = buffstr(&display);
      }
      w = wcreate(s2);
      if (!w)
          fail;
      return C_integer (word) w;
   }
end

function graphics_Window_wopen(self)
   body {
      GetSelfW();
      if (wopen(self_w) != Succeeded) {
          *self_w_dptr = zerodesc;
          freewbinding(self_w);
          fail;
      }
      inattr = wconfig = 0;
      return self;
   }
end

function graphics_Window_grab_pointer(self)
   body {
      GetSelfW();
      if (grabpointer(self_w) != Succeeded)
          fail;
      return nulldesc;
   }
end

function graphics_Window_ungrab_pointer(self)
   body {
      GetSelfW();
      if (ungrabpointer(self_w) != Succeeded)
          fail;
      return nulldesc;
   }
end

function graphics_Window_alert(self, volume)
   if !def:C_integer(volume, 0) then
      runerr(101, volume)
   body {
       GetSelfW();
       walert(self_w, volume);
       return nulldesc;
   }
end

function graphics_Window_clone_impl(self)
   body {
       wbp w2;
       GetSelfW();
       w2 = alcwbinding();
       w2->window = self_w->window;
       w2->window->refcount++;
       w2->context = clonecontext(self_w);
       return C_integer((word)w2);
   }
end

function graphics_Window_color_value(s)
    if !cnv:string(s) then
       runerr(103, s);
   body {
      int r, g, b;
      tended struct descrip result;
      char tmp[32];
      if (!parsecolor(buffstr(&s), &r, &g, &b))
          fail;
      sprintf(tmp,"%d,%d,%d", r, g, b);
      cstr2string(tmp, &result);
      return result;
   }
end

function graphics_Window_parse_color(s)
    if !cnv:string(s) then
       runerr(103, s);
   body {
      int r, g, b;
      tended struct descrip result;
      struct descrip t;
      if (!parsecolor(buffstr(&s), &r, &g, &b))
          fail;
      create_list(3, &result);
      MakeInt(r, &t);
      list_put(&result, &t);
      MakeInt(g, &t);
      list_put(&result, &t);
      MakeInt(b, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_copy_to(self, dest, x0, y0, w0, h0, x1, y1)
   body {
      word x, y, width, height, x2, y2;
      wbp w2;

      GetSelfW();

      if (is:null(dest))
          w2 = self_w;
      else {
          WindowStaticParam(dest, tmp);
          w2 = tmp;
      }

      /*
       * x1, y1, width, and height follow standard conventions.
       */
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (pointargs(w2, &x1, &x2, &y2) == Error)
          runerr(0);

      copyarea(self_w, w2, x, y, width, height, x2, y2);

      return nulldesc;
   }
end

function graphics_Window_couple_impl(self, other)
   body {
      wbp wb2, wb_new;
      GetSelfW();
      {
          WindowStaticParam(other, tmp);
          wb2 = tmp;
      }

      /*
       * make the new binding
       */
      wb_new = alcwbinding();

      wb_new->window = self_w->window;
      /*
       * Bind an existing window to an existing context,
       * and up the context's reference count.
       */
      if (rebind(wb_new, wb2) == Failed) 
          fail;
      wb_new->context->refcount++;

      /* bump up refcount to self_w->window */
      self_w->window->refcount++;

      return C_integer((word)wb_new);
   }
end


function graphics_Window_draw_arc(self, x0, y0, w0, h0, ang1, ang2)
   body {
      word x, y, width, height;
      double a1, a2;

      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      /*
       * Angle 1 processing.  Computes in radians and 64'ths of a degree,
       *  bounds checks, and handles wraparound.
       */
      if (!def:C_double(ang1, 0.0, a1))
          runerr(102, ang1);
      if (a1 >= 0.0)
          a1 = fmod(a1, 2 * Pi);
      else
          a1 = -fmod(-a1, 2 * Pi);

      /*
       * Angle 2 processing
       */
      if (!def:C_double(ang2, 2 * Pi, a2))
          runerr(102, ang2);
      if (fabs(a2) > 3 * Pi)
          runerr(101, ang2);
      if (fabs(a2) >= 2 * Pi)
          a2 = 2 * Pi;
      else {
          if (a2 < 0.0) {
              a1 += a2;
              a2 = fabs(a2);
          }
      }
      if (a1 < 0.0)
          a1 = 2 * Pi - fmod(fabs(a1), 2 * Pi);
      else
          a1 = fmod(a1, 2 * Pi);

      drawarc(self_w, x, y, width, height, a1, a2);

      return self;
   }
end

function graphics_Window_draw_circle(self, x, y, r, theta, alpha)
   body {
      GetSelfW();

      if (docircle(self_w, &x, 0) == Error)
          runerr(0);
      return self;
   }
end

function graphics_Window_draw_curve(self, argv[argc])
   body {
      int i, n, closed;
      word dx, dy, x0, y0, xN, yN;
      XPoint *points;
      GetSelfW();

      closed = 0;
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;

      MemProtect(points = (XPoint *)malloc(sizeof(XPoint) * (n+2)));

      if (n > 1) {
          CnvCInteger(argv[0], x0)
              CnvCInteger(argv[1], y0)
              CnvCInteger(argv[argc - 2], xN)
              CnvCInteger(argv[argc - 1], yN)
              if ((x0 == xN) && (y0 == yN)) {
                  closed = 1;               /* duplicate the next to last point */
                  CnvCShort(argv[argc-4], points[0].x);
                  CnvCShort(argv[argc-3], points[0].y);
                  points[0].x += self_w->context->dx;
                  points[0].y += self_w->context->dy;
              }
              else {                       /* duplicate the first point */
                  CnvCShort(argv[0], points[0].x);
                  CnvCShort(argv[1], points[0].y);
                  points[0].x += self_w->context->dx;
                  points[0].y += self_w->context->dy;
              }
          for (i = 1; i <= n; i++) {
              int base = (i-1) * 2;
              CnvCShort(argv[base], points[i].x);
              CnvCShort(argv[base + 1], points[i].y);
              points[i].x += dx;
              points[i].y += dy;
          }
          if (closed) {                /* duplicate the second point */
              points[i] = points[2];
          }
          else {                       /* duplicate the last point */
              points[i] = points[i-1];
          }
          if (n < 3) {
              drawlines(self_w, points+1, n);
          }
          else {
              drawCurve(self_w, points, n+2);
          }
      }
      free(points);

      return self;
   }
end

function graphics_Window_draw_image(self, x0, y0, d)
   body {
      word x, y;
      struct imgdata imd;
      GetSelfW();

      if (pointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);
      if (!cnv:string(d, d))
          runerr(103, d);

      if (interpimage(self_w, &d, &imd) != Succeeded)
          fail;
      drawimgdata(self_w, x, y, &imd);
      freeimgdata(&imd);
      return self;
   }
end

function graphics_Window_draw_line(self, argv[argc])
   body {
      int i, j, n;
      XPoint points[MAXPOINTS];
      int dx, dy;

      GetSelfW();

      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i = 0, j = 0; i < n; i++, j++) {
          int base = i * 2;
          if (j == MAXPOINTS) {
              drawlines(self_w, points, MAXPOINTS);
              points[0] = points[MAXPOINTS-1];
              j = 1;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawlines(self_w, points, j);

      return self;
   }
end

function graphics_Window_draw_point(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      int dx, dy;
      GetSelfW();
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      drawpoint(self_w, x + dx, y + dy);
      return self;
   }
end

function graphics_Window_draw_polygon(self, argv[argc])
   body {
      int i, j, n, base, dx, dy;
      XPoint points[MAXPOINTS];

      GetSelfW();
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;

      /*
       * To make a closed polygon, start with the *last* point.
       */
      CnvCShort(argv[argc - 2], points[0].x);
      CnvCShort(argv[argc - 1], points[0].y);
      points[0].x += dx;
      points[0].y += dy;

      /*
       * Now add all points from beginning to end, including last point again.
       */
      for(i = 0, j = 1; i < n; i++, j++) {
          base = i * 2;
          if (j == MAXPOINTS) {
              drawlines(self_w, points, MAXPOINTS);
              points[0] = points[MAXPOINTS-1];
              j = 1;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawlines(self_w, points, j);

      return self;
   }
end

function graphics_Window_draw_rectangle(self, x0, y0, w0, h0)
   body {
      word x, y, width, height;

      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      drawrectangle(self_w, x, y, width, height);

      return self;
   }
end

function graphics_Window_draw_string(self, x0, y0, str)
   body {
      int len;
      word x, y;
      char *s;
      GetSelfW();

      if (pointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);
      if (!cnv:string_or_ucs(str,str))
          runerr(129, str);

      if (is:ucs(str)) {
          s = StrLoc(UcsBlk(str).utf8);
          len = StrLen(UcsBlk(str).utf8);
          drawutf8(self_w, x, y, s, len, UcsBlk(str).length);
      } else {
          s = StrLoc(str);
          len = StrLen(str);
          drawstring(self_w, x, y, s, len);
      }
      return self;
   }
end

function graphics_Window_erase_area(self, x0, y0, w0, h0)
   body {
      word x, y, width, height;
      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
      erasearea(self_w, x, y, width, height);
      return self;
   }
end

function graphics_Window_event(self)
   body {
      tended struct descrip d;
      GetSelfW();
      wgetevent(self_w, &d);
      return d;
   }
end

function graphics_Window_pending(self, argv[argc])
   body {
      wsp ws;
      int i;
      GetSelfW();

      ws = self_w->window;
      wsync(self_w);

      /*
       * put additional arguments to Pending on the pending list in
       * guaranteed consecutive order.
       */
      for (i = 0; i < argc; i++)
          list_put(&(ws->listp), &argv[i]);

      /*
       * retrieve any events that might be relevant before returning the
       * pending queue.
       */
      pollevent();

      return ws->listp;
   }
end

function graphics_Window_fill_arc(self, x0, y0, w0, h0, ang1, ang2)
   body {
      word x, y, width, height;
      double a1, a2;

      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!def:C_double(ang1, 0.0, a1))
          runerr(102, ang1);
      if (a1 >= 0.0)
          a1 = fmod(a1, 2 * Pi);
      else
          a1 = -fmod(-a1, 2 * Pi);

      if (!def:C_double(ang2, 2 * Pi, a2))
          runerr(102, ang2);
      if (fabs(a2) > 3 * Pi)
          runerr(101, ang2);
      if (fabs(a2) >= 2 * Pi)
          a2 = 2 * Pi;
      else {
          if (a2 < 0.0) {
              a1 += a2;
              a2 = fabs(a2);
          }
      }
      if (a1 < 0.0)
          a1 = 2 * Pi - fmod(fabs(a1), 2 * Pi);
      else
          a1 = fmod(a1, 2 * Pi);
      
      fillarc(self_w, x, y, width, height, a1, a2);
      
      return self;
   }
end

function graphics_Window_fill_circle(self, x, y, r, theta, alpha)
   body {
      GetSelfW();

      if (docircle(self_w, &x, 1) == Error)
          runerr(0);
      return self;
   }
end

function graphics_Window_fill_polygon(self, argv[argc])
   body {
      int i, n;
      XPoint *points;
      int dx, dy;
      GetSelfW();

      CheckArgMultipleOf(2);

      /*
       * Allocate space for all the points in a contiguous array,
       * because a FillPolygon must be performed in a single call.
       */
      n = argc>>1;
      MemProtect(points = (XPoint *)malloc(sizeof(XPoint) * n));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i=0; i < n; i++) {
          int base = i * 2;
          CnvCShort(argv[base], points[i].x);
          CnvCShort(argv[base + 1], points[i].y);
          points[i].x += dx;
          points[i].y += dy;
      }
      fillpolygon(self_w, points, n);
      free(points);

      return self;
   }
end

function graphics_Window_fill_rectangle(self, x0, y0, w0, h0)
   body {
      word x, y, width, height;

      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      fillrectangle(self_w, x, y, width, height);

      return self;
   }
end

function graphics_Window_lower(self)
   body {
      GetSelfW();
      lowerwindow(self_w);
      return self;
   }
end

function graphics_Window_palette_chars(pal)
   if !cnv:string(pal) then
       runerr(103, pal)
   body {
      int n;
      if (!parsepalette(buffstr(&pal), &n))
          fail;
      switch (n) {
          case  1:  return string(90, c1list);			/* c1 */
          case  2:  return string(9, c2list);			/* c2 */
          case  3:  return string(31, c3list);			/* c3 */
          case  4:  return string(73, c4list);			/* c4 */
          case  5:  return string(141, allchars);	/* c5 */
          case  6:  return string(241, allchars);	/* c6 */
          default:					/* gn */
              if (n >= -64)
                  return string(-n, c4list);
              else
                  return string(-n, allchars);
      }
      fail; /* NOTREACHED */ /* avoid spurious rtt warning message */
   }
end

function graphics_Window_palette_color(s1, s2)
   if !cnv:string(s1) then
       runerr(103, s1)
   if !cnv:string(s2) then
       runerr(103, s2)
   body {
      int p;
      char tmp[32];
      struct palentry *e;
      tended struct descrip result;
      if (!parsepalette(buffstr(&s1), &p)) {
          LitWhy("Invalid palette");
          fail;
      }
      if (StrLen(s2) != 1)
          runerr(205, s2);
      e = palsetup(p); 
      e += *StrLoc(s2) & 0xFF;
      if (!e->valid) {
          LitWhy("Invalid character");
          fail;
      }
      sprintf(tmp, "%d,%d,%d", e->r, e->g, e->b);
      cstr2string(tmp, &result);
      return result;
   }
end

function graphics_Window_palette_key(s1, s2)
   if !cnv:string(s1) then
       runerr(103, s1)
   if !cnv:string(s2) then
       runerr(103, s2)
   body {
      int p, r, g, b;
      if (!parsepalette(buffstr(&s1), &p)) {
          LitWhy("Invalid palette");
          fail;
      }
      if (!parsecolor(buffstr(&s2), &r, &g, &b)) {
          LitWhy("Invalid color");
          fail;
      }
      return string(1, rgbkey(p, r, g, b));
   }
end

function graphics_Window_get_pixels(self, x0, y0, w0, h0)
   body {
      struct imgmem imem;
      word x, y, width, height;
      tended struct descrip lastval, result;
      int i, j, r, g, b;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      create_list(width * height, &result);

      if (initimgmem(self_w, &imem, 1, 0, x, y, width, height)) {
          lastval = emptystr;
          r = g = b = -1;
          for (j = y; j < y + height; j++) {
              for (i = x; i < x + width; i++) {
                  if (gotopixel(&imem, i, j)) {
                      int r0, g0, b0;
                      getpixel(&imem, &r0, &g0, &b0);
                      if (r != r0 || g != g0 || b != b0) {
                          char buff[64];
                          r = r0; g = g0; b = b0;
                          sprintf(buff, "%d,%d,%d", r, g, b);
                          cstr2string(buff, &lastval);
                      }
                      list_put(&result, &lastval);
                  } else
                      list_put(&result, &nulldesc);
              }
          }
          freeimgmem(&imem);
      } else {
          /* Region completely off-screen */
          for (i = 0; i < width * height; i++)
              list_put(&result, &nulldesc);
      }
      return result;
   }
end

function graphics_Window_set_pixels(self, data, x0, y0, w0, h0)
   if !is:list(data) then
      runerr(108, data)
   body {
      struct imgmem imem;
      word x, y, width, height;
      struct lgstate state;
      tended struct b_lelem *le;
      tended struct descrip elem;
      int i, j;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!initimgmem(self_w, &imem, 1, 1, x, y, width, height))
          return nulldesc;

      le = lgfirst(&ListBlk(data), &state);
      for (j = y; le && j < y + height; j++) {
          for (i = x; le && i < x + width; i++) {
              elem = le->lslots[state.result];
              le = lgnext(&ListBlk(data), &state, le);
              if (!is:null(elem) && gotopixel(&imem, i, j)) {
                  int r, g, b;
                  if (!cnv:string(elem, elem))
                      runerr(103, elem);
                  if (parsecolor(buffstr(&elem), &r, &g, &b))
                      setpixel(&imem, r, g, b);
              }
          }
      }

      saveimgmem(self_w, &imem);
      freeimgmem(&imem);
      return nulldesc;
   }
end

function graphics_Window_filter(self, spec, x0, y0, w0, h0)
   body {
      struct imgmem imem;
      word x, y, width, height;
      struct filter *filter;
      int i, nfilter;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (is:list(spec)) {
          struct lgstate state;
          tended struct b_lelem *le;
          tended struct descrip elem;
          nfilter = ListBlk(spec).size;
          MemProtect(filter = malloc(nfilter * sizeof(struct filter)));
          for (le = lgfirst(&ListBlk(spec), &state); le;
               le = lgnext(&ListBlk(spec), &state, le)) {
              elem = le->lslots[state.result];
              if (!cnv:string(elem, elem)) {
                  free(filter);
                  runerr(103, elem);
              }
              if (!parsefilter(self_w, buffstr(&elem), &filter[state.listindex - 1])) {
                  LitWhy("Invalid filter");
                  free(filter);
                  fail;
              }
          }
      } else {
          if (!cnv:string(spec, spec))
              runerr(103, spec);

          MemProtect(filter = malloc(sizeof(struct filter)));
          nfilter = 1;
          if (!parsefilter(self_w, buffstr(&spec), &filter[0])) {
              LitWhy("Invalid filter");
              free(filter);
              fail;
          }
      }

      if (!initimgmem(self_w, &imem, 1, 1, x, y, width, height)) {
          free(filter);
          return nulldesc;
      }

      for (i = 0; i < nfilter; ++i) {
          filter[i].imem = &imem;
          filter[i].f(&filter[i]);
      }
      saveimgmem(self_w, &imem);
      freeimgmem(&imem);
      free(filter);

      return nulldesc;
   }
end

function graphics_Window_query_root_pointer(self)
   body {
      int x, y;
      tended struct descrip result;
      struct descrip t;
      GetSelfW();
      pollevent();
      if (queryrootpointer(self_w, &x, &y) != Succeeded)
          fail;
      create_list(2, &result);
      MakeInt(x, &t);
      list_put(&result, &t);
      MakeInt(y, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_query_pointer(self)
   body {
      int x, y;
      tended struct descrip result;
      struct descrip t;
      GetSelfW();
      pollevent();
      if (querypointer(self_w, &x, &y) != Succeeded)
          fail;
      create_list(2, &result);
      MakeInt(x - self_w->context->dx, &t);
      list_put(&result, &t);
      MakeInt(y - self_w->context->dy, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_get_display_size(self)
   body {
      int width, height;
      tended struct descrip result;
      struct descrip t;
      GetSelfW();
      if (getdisplaysize(self_w, &width, &height) != Succeeded)
          fail;
      create_list(2, &result);
      MakeInt(width, &t);
      list_put(&result, &t);
      MakeInt(height, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_warp_pointer(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      GetSelfW();
      if (warppointer(self_w, x + self_w->context->dx, y + self_w->context->dy) != Succeeded)
          fail;
      return self;
   }
end

function graphics_Window_raise(self)
   body {
      GetSelfW();
      if (raisewindow(self_w) != Succeeded)
          fail;
      return self;
   }
end

function graphics_Window_sync()
   body {
      wsync(0);
      pollevent();
      return nulldesc;
   }
end

function graphics_Window_text_width(self, s)
   if !cnv:string_or_ucs(s) then
      runerr(129, s)
   body {
      word i;
      GetSelfW();
      if (is:ucs(s))
          i = utf8width(self_w, 
                        StrLoc(UcsBlk(s).utf8), 
                        StrLen(UcsBlk(s).utf8),
                        UcsBlk(s).length);
      else
          i = textwidth(self_w, StrLoc(s), StrLen(s));
      return C_integer i;
   }
end

"Uncouple(w) - uncouple window"

function graphics_Window_uncouple(self)
   body {
      GetSelfW();
      *self_w_dptr = zerodesc;
      freewbinding(self_w);
      return self;
   }
end

function graphics_Window_flush(self)
   body {
      GetSelfW();
      wflush(self_w);
      return self;
   }
end

function graphics_Window_write_image(self, fname, x0, y0, w0, h0)
   if !cnv:string(fname) then
       runerr(103, fname)
   body {
      word x, y, width, height;
      char *s;
      GetSelfW();

      s = buffstr(&fname);

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (writeimagefile(self_w, s, x, y, width, height) != Succeeded)
          fail;

      return self;
   }
end

function graphics_Window_own_selection(self, selection)
   if !cnv:string(selection) then
      runerr(103,selection)
   body {
       GetSelfW();
       if (ownselection(self_w, buffstr(&selection)) != Succeeded)
           fail;
       return self;
   }
end

function graphics_Window_send_selection_response(self, requestor, property, selection, target, time, data)
   if !cnv:C_integer(requestor) then
      runerr(101, requestor)
   if !cnv:string(property) then
      runerr(103, property)
   if !cnv:string(selection) then
      runerr(103, selection)
   if !cnv:string(target) then
      runerr(103, target)
   if !cnv:C_integer(time) then
      runerr(101, time)
   body {
       char *t1, *t2, *t3;
       GetSelfW();
       buffnstr(&property, &t1, &selection, &t2, &target, &t3, 0);
       switch (sendselectionresponse(self_w, requestor, t1, t2, t3, time, &data)) {
           case Error: {
               runerr(0);
               break;
           }
           case Failed: {
               fail;
               break;
           }
           case Succeeded: {
               return self;
           }
       }
       /* Not reached */
       fail;
   }
end

static struct sdescrip deftarget = {6, "STRING"};

function graphics_Window_request_selection(self, selection, target_type)
   if !cnv:string(selection) then
      runerr(103,selection)
   if !def:string(target_type, *((dptr)&deftarget)) then
      runerr(103,target_type)
   body {
       char *t1, *t2;
       GetSelfW();
       buffnstr(&selection, &t1, &target_type, &t2, 0);
       if (requestselection(self_w, t1, t2) == Failed)
           fail;
       return self;
   }
end

function graphics_Window_close(self)
   body {
     GetSelfW();

     *self_w_dptr = zerodesc;
     wclose(self_w);
     freewbinding(self_w);

     return self;
   }
end

function graphics_Window_get_font_ascent(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(ASCENT(self_w), &result);
       return result;
   }
end

function graphics_Window_get_bg(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getbg(self_w), &result);
       return result;
   }
end

function graphics_Window_get_canvas(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getcanvas(self_w), &result);
       return result;
   }
end

function graphics_Window_drawable(self, x0, y0, w0, h0)
   body {
      tended struct descrip result;
      struct descrip t;
      wcp wc;
      wsp ws;
      word x, y, width, height;
      GetSelfW();
      wc = self_w->context;
      ws = self_w->window;

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (x < 0)  { 
          width += x; 
          x = 0; 
      }
      if (y < 0)  { 
          height += y; 
          y = 0; 
      }
      if (x + width > ws->width)
          width = ws->width - x; 
      if (y + height > ws->height)
          height = ws->height - y; 

      if (width <= 0 || height <= 0)
          fail;

      if (wc->clipw >= 0) {
          /* Further reduce the rectangle to the clipping region */
          if (x < wc->clipx) {
              width += x - wc->clipx;
              x = wc->clipx;
          }
          if (y < wc->clipy) {
              height += y - wc->clipy; 
              y = wc->clipy;
          }
          if (x + width > wc->clipx + wc->clipw)
              width = wc->clipx + wc->clipw - x;
          if (y + height > wc->clipy + wc->cliph)
              height = wc->clipy + wc->cliph - y;

          if (width <= 0 || height <= 0)
              fail;
      }

      create_list(4, &result);
      MakeInt(x - wc->dx, &t);
      list_put(&result, &t);
      MakeInt(y - wc->dy, &t);
      list_put(&result, &t);
      MakeInt(width, &t);
      list_put(&result, &t);
      MakeInt(height, &t);
      list_put(&result, &t);

      return result;
   }
end


function graphics_Window_get_clip(self)
   body {
       tended struct descrip result;
       struct descrip t;
       wcp wc;
       GetSelfW();
       wc = self_w->context;
       if (wc->clipw < 0)
           fail;
       create_list(4, &result);
       MakeInt(wc->clipx - wc->dx, &t);
       list_put(&result, &t);
       MakeInt(wc->clipy - wc->dy, &t);
       list_put(&result, &t);
       MakeInt(wc->clipw, &t);
       list_put(&result, &t);
       MakeInt(wc->cliph, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_depth(self)
   body {
       struct descrip result;
       int i;
       GetSelfW();
       if (getdepth(self_w, &i) == Failed)
           fail;
       MakeInt(i, &result);
       return result;
   }
end

function graphics_Window_get_font_descent(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(DESCENT(self_w), &result);
       return result;
   }
end

function graphics_Window_get_display(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getdisplay(self_w), &result);
       return result;
   }
end

function graphics_Window_get_draw_op(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getdrawop(self_w), &result);
       return result;
   }
end

function graphics_Window_get_dx(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->context->dx, &result);
       return result;
   }
end

function graphics_Window_get_dy(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->context->dy, &result);
       return result;
   }
end

function graphics_Window_get_fg(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getfg(self_w), &result);
       return result;
   }
end

function graphics_Window_get_font_height(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(FHEIGHT(self_w), &result);
       return result;
   }
end

function graphics_Window_get_fill_style(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getfillstyle(self_w), &result);
       return result;
   }
end

function graphics_Window_get_font(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(self_w->context->font->name, &result);
       return result;
   }
end

function graphics_Window_get_font_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(FWIDTH(self_w), &result);
       return result;
   }
end

function graphics_Window_get_geometry(self)
   body {
       tended struct descrip result;
       struct descrip t;
       wsp ws;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       ws = self_w->window;
       create_list(4, &result);
       MakeInt(ws->x, &t);
       list_put(&result, &t);
       MakeInt(ws->y, &t);
       list_put(&result, &t);
       MakeInt(ws->width, &t);
       list_put(&result, &t);
       MakeInt(ws->height, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_height(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->height, &result);
       return result;
   }
end

function graphics_Window_get_input_mask(self)
   body {
       tended struct descrip result;
       char buf[3], *s;
       int mask;
       GetSelfW();
       s = buf;  
       mask = self_w->window->inputmask;
       if (mask & IM_POINTER_MOTION)
           *s++ = 'm';
       if (mask & IM_KEY_RELEASE)
           *s++ = 'k';
       *s = 0;
       cstr2string(buf, &result);
       return result;
   }
end

function graphics_Window_get_label(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getwindowlabel(self_w), &result);
       return result;
   }
end

function graphics_Window_get_line_style(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getlinestyle(self_w), &result);
       return result;
   }
end

function graphics_Window_get_line_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(getlinewidth(self_w), &result);
       return result;
   }
end

function graphics_Window_get_max_height(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->maxheight, &result);
       return result;
   }
end

function graphics_Window_get_max_size(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       create_list(2, &result);
       MakeInt(self_w->window->maxwidth, &t);
       list_put(&result, &t);
       MakeInt(self_w->window->maxheight, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_max_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->maxwidth, &result);
       return result;
   }
end

function graphics_Window_get_min_height(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->minheight, &result);
       return result;
   }
end

function graphics_Window_get_min_size(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       create_list(2, &result);
       MakeInt(self_w->window->minwidth, &t);
       list_put(&result, &t);
       MakeInt(self_w->window->minheight, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_min_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->minwidth, &result);
       return result;
   }
end

function graphics_Window_get_pattern(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getpattern(self_w), &result);
       return result;
   }
end

function graphics_Window_get_pointer(self)
   body {
       tended struct descrip result;
       GetSelfW();
       cstr2string(getpointer(self_w), &result);
       return result;
   }
end

function graphics_Window_get_pos(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       create_list(2, &result);
       MakeInt(self_w->window->x, &t);
       list_put(&result, &t);
       MakeInt(self_w->window->y, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_x(self)
   body {
       struct descrip result;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       MakeInt(self_w->window->x, &result);
       return result;
   }
end

function graphics_Window_get_y(self)
   body {
       struct descrip result;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       MakeInt(self_w->window->y, &result);
       return result;
   }
end

function graphics_Window_can_resize(self)
   body {
       GetSelfW();
       if (ISRESIZABLE(self_w->window))
           return nulldesc;
       else
           fail;
   }
end

function graphics_Window_get_size(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       create_list(2, &result);
       MakeInt(self_w->window->width, &t);
       list_put(&result, &t);
       MakeInt(self_w->window->height, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->width, &result);
       return result;
   }
end

int wconfig, inattr;

#begdef AttemptAttr(operation, reason)
do {
   LitWhy("");
   switch (operation) { 
       case Error: {
           runerr(145, val); 
           break;
       }
       case Succeeded: {
           if (!inattr && wconfig) {
               doconfig(self_w, wconfig);
               wconfig = 0;
           }
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

#begdef SimpleAttr()
do {
   if (!inattr && wconfig) {
       doconfig(self_w, wconfig);
       wconfig = 0;
   }
} while(0)
#enddef

function graphics_Window_pre_attrib(self)
   body {
      inattr = 1;
      wconfig = 0;
      fail;
   }
end

function graphics_Window_post_attrib(self)
   body {
      GetSelfW();
      inattr = 0;
      SimpleAttr();
      fail;
   }
end
  
function graphics_Window_set_bg(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setbg(self_w, buffstr(&val)), "Invalid color");
       return self;
   }
end

function graphics_Window_set_canvas(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setcanvas(self_w, buffstr(&val)), "Invalid canvas type");
       return self;
   }
end

function graphics_Window_clip(self, x0, y0, w0, h0)
   body {
      word x, y, width, height;
      wcp wc;
      GetSelfW();

      wc = self_w->context;
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
      wc->clipx = x;
      wc->clipy = y;
      wc->clipw = width;
      wc->cliph = height;
      wconfig |= C_CLIP;
      SimpleAttr();
      return self;
   }
end

function graphics_Window_unclip(self)
   body {
      wcp wc;
      GetSelfW();
      wc = self_w->context;
      wc->clipx = wc->clipy = 0;
      wc->clipw = wc->cliph = -1;
      wconfig |= C_CLIP;
      SimpleAttr();
      return self;
   }
end

function graphics_Window_set_draw_op(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setdrawop(self_w, buffstr(&val)), "Invalid draw_op");
       return self;
   }
end

function graphics_Window_set_dx(self, val)
   if !cnv:C_integer(val) then
       runerr(101, val)
   body {
       GetSelfW();
       self_w->context->dx = val;
       return self;
   }
end

function graphics_Window_set_dy(self, val)
   if !cnv:C_integer(val) then
       runerr(101, val)
   body {
       GetSelfW();
       self_w->context->dy = val;
       return self;
   }
end

function graphics_Window_set_fg(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfg(self_w, buffstr(&val)), "Invalid color");
       return self;
   }
end

function graphics_Window_set_fill_style(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfillstyle(self_w, buffstr(&val)), "Invalid fill_style");
       return self;
   }
end

function graphics_Window_set_font(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfont(self_w, buffstr(&val)), "No matching font in system");
       return self;
   }
end

function graphics_Window_set_geometry(self, x0, y0, w0, h0)
   body {
       word x, y, width, height;
       GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
       self_w->window->x = x;
       self_w->window->y = y;
       self_w->window->width = width;
       self_w->window->height = height;
       wconfig |= C_SIZE | C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_height(self, height)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
       GetSelfW();
       if (height < 1)
           Irunerr(148, height);
       self_w->window->height = height;
       wconfig |= C_SIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_image(self, d)
   if !cnv:string(d) then
      runerr(103, d)
   body {
       wsp ws;
       GetSelfW();
       ws = self_w->window;
       if (interpimage(self_w, &d, &ws->initimage) != Succeeded)
           fail;
       self_w->window->width = ws->initimage.width;
       self_w->window->height = ws->initimage.height;
       wconfig |= C_SIZE | C_IMAGE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_input_mask(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       int t;
       GetSelfW();
       if (!parseinputmask(buffstr(&val), &t)) {
           LitWhy("Invalid input mask");
           fail;
       }
       self_w->window->inputmask = t;
       return self;
   }
end

function graphics_Window_set_label(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setwindowlabel(self_w, buffstr(&val)), "Failed to set window label");
       return self;
   }
end

function graphics_Window_set_line_style(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setlinestyle(self_w, buffstr(&val)), "Invalid line_style");
       return self;
   }
end

function graphics_Window_set_line_width(self, val)
   body {
       word i;
       GetSelfW();
       if (!cnv:C_integer(val, i))
           runerr(101, val);
       AttemptAttr(setlinewidth(self_w, i), "Invalid line_width");
       return self;
   }
end

function graphics_Window_set_max_height(self, height)
   body {
       word i;
       GetSelfW();
       if (is:null(height))
           i = INT_MAX;
       else {
           if (!cnv:C_integer(height, i))
               runerr(101, height);
           if (i < 1)
               runerr(148, height);
       }
       self_w->window->maxheight = i;
       wconfig |= C_MAXSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_max_size(self, width, height)
   body {
       word i, j;
       GetSelfW();
       if (is:null(width))
           i = INT_MAX;
       else {
           if (!cnv:C_integer(width, i))
               runerr(101, width);
           if (i < 1)
               runerr(148, width);
       }
       if (is:null(height))
           j = INT_MAX;
       else {
           if (!cnv:C_integer(height, j))
               runerr(101, height);
           if (j < 1)
               runerr(148, height);
       }
       self_w->window->maxwidth = i;
       self_w->window->maxheight = j;
       wconfig |= C_MAXSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_max_width(self, width)
   body {
       word i;
       GetSelfW();
       if (is:null(width))
           i = INT_MAX;
       else {
           if (!cnv:C_integer(width, i))
               runerr(101, width);
           if (i < 1)
               runerr(148, width);
       }
       self_w->window->maxwidth = i;
       wconfig |= C_MAXSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_min_height(self, height)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
       GetSelfW();
       if (height < 1)
           Irunerr(148, height);
       self_w->window->minheight = height;
       wconfig |= C_MINSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_min_size(self, width, height)
   if !cnv:C_integer(width) then
      runerr(101, width)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
       GetSelfW();
       if (width < 1)
           Irunerr(148, width);
       if (height < 0)
           Irunerr(148, height);
       self_w->window->minwidth = width;
       self_w->window->minheight = height;
       wconfig |= C_MINSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_min_width(self, width)
   if !cnv:C_integer(width) then
      runerr(101, width)
   body {
       GetSelfW();
       if (width < 1)
           Irunerr(148, width);
       self_w->window->minwidth = width;
       wconfig |= C_MINSIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_pattern(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setpattern(self_w, buffstr(&val)), "Invalid pattern");
       return self;
   }
end

function graphics_Window_set_pointer(self, val)
   if !cnv:string(val) then
       runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setpointer(self_w, buffstr(&val)), "Invalid pointer");
       return self;
   }
end

function graphics_Window_set_pos(self, x, y)
   body {
       word i, j;
       GetSelfW();
       if (is:null(x))
           i = -INT_MAX;
       else {
           if (!cnv:C_integer(x, i))
               runerr(101, x);
       }
       if (is:null(y))
           j = -INT_MAX;
       else {
           if (!cnv:C_integer(y, j))
               runerr(101, y);
       }
       self_w->window->x = i;
       self_w->window->y = j;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_x(self, x)
   body {
       word i;
       GetSelfW();
       if (is:null(x))
           i = -INT_MAX;
       else {
           if (!cnv:C_integer(x, i))
               runerr(101, x);
       }
       self_w->window->x = i;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_y(self, y)
   body {
       word i;
       GetSelfW();
       if (is:null(y))
           i = -INT_MAX;
       else {
           if (!cnv:C_integer(y, i))
               runerr(101, y);
       }
       self_w->window->y = i;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_resize(self, val)
   body {
       GetSelfW();
       if (is:null(val))
           CLRRESIZABLE(self_w->window);
       else
           SETRESIZABLE(self_w->window);
       wconfig |= C_RESIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_size(self, width, height)
   if !cnv:C_integer(width) then
      runerr(101, width)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
       GetSelfW();
       if (width < 1)
           Irunerr(148, width);
       if (height < 1)
           Irunerr(148, height);
       self_w->window->width = width;
       self_w->window->height = height;
       wconfig |= C_SIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_width(self, width)
   if !cnv:C_integer(width) then
      runerr(101, width)
   body {
       GetSelfW();
       if (width < 1)
           Irunerr(148, width);
       self_w->window->width = width;
       wconfig |= C_SIZE;
       SimpleAttr();
       return self;
   }
end

#if PLAN9
function graphics_Window_get_dir(self)
   body {
       tended struct descrip result;
       GetSelfW();
       if (!self_w->window->win)
           fail;
       cstr2string(self_w->window->mount_dir, &result);
       return result;
   }
end
#endif

function graphics_Window_set_transient_for_impl(self, val)
   body {
       wbp w2;
       GetSelfW();
       if (is:null(val))
           w2 = 0;
       else {
           WindowStaticParam(val, tmp);
           w2 = tmp;
       }
       AttemptAttr(settransientfor(self_w, w2), "Cannot set transient_for");
       return self;
   }
end

#endif   /* Graphics */
