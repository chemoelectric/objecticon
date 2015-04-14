/*
 * File: fwindow.r - Icon graphics interface
 *
 */

struct sdescrip pixclassname = {15, "graphics.Pixels"};

#begdef GetSelfPixels()
struct imgdata *self_id;
dptr self_id_dptr;
static struct inline_field_cache self_id_ic;
self_id_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_id_ic);
if (!self_id_dptr)
    syserr("Missing idp field");
self_id = (struct imgdata *)IntVal(*self_id_dptr);
if (!self_id)
    runerr(152, self);
#enddef


#if Graphics

/*
 * Global variables.
 */
struct sdescrip wclassname = {15, "graphics.Window"};

#begdef GetSelfW()
wbp self_w;
dptr self_w_dptr;
static struct inline_field_cache self_w_ic;
self_w_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_w_ic);
if (!self_w_dptr)
    syserr("Missing wbp field");
self_w = (wbp)IntVal(*self_w_dptr);
if (!self_w)
    runerr(142, self);
#enddef

function graphics_Window_new_impl(display)
   body {
      wbp w;
      char *s2;
      if (is:null(display))
          s2 = 0;
      else {
         if (!cnv:string(display, display))
             runerr(103, display);
         s2 = buffstr(&display);
      }
      w = wopen(s2);
      if (!w)
          fail;
      return C_integer (word) w;
   }
end

function graphics_Window_grab_pointer(self)
   body {
      GetSelfW();
      AttemptOp(grabpointer(self_w));
      return self;
   }
end

function graphics_Window_ungrab_pointer(self)
   body {
      GetSelfW();
      AttemptOp(ungrabpointer(self_w));
      return self;
   }
end

function graphics_Window_grab_keyboard(self)
   body {
      GetSelfW();
      AttemptOp(grabkeyboard(self_w));
      return self;
   }
end

function graphics_Window_ungrab_keyboard(self)
   body {
      GetSelfW();
      AttemptOp(ungrabkeyboard(self_w));
      return self;
   }
end

function graphics_Window_alert(self, volume)
   if !def:C_integer(volume, 0) then
      runerr(101, volume)
   body {
       GetSelfW();
       walert(self_w, volume);
       return self;
   }
end

function graphics_Window_clone_impl(self)
   body {
       wbp w2;
       GetSelfW();
       w2 = clonewindow(self_w);
       return C_integer((word)w2);
   }
end

function graphics_Window_copy_to(self, x0, y0, w0, h0, dest, x1, y1)
   body {
      word ox, oy, x, y, width, height, x2, y2;
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

      ox = x;
      oy = y;
      if (!reducerect(self_w, 0, &x, &y, &width, &height))
          return self;

      AttemptOp(copyarea(self_w, x, y, width, height, w2, x2 + (x - ox), y2 + (y - oy)));

      return self;
   }
end

function graphics_Window_couple_impl(self, other)
   body {
      wbp wb_new;
      GetSelfW();
      {
      WindowStaticParam(other, w2);
      wb_new = couplewindows(self_w, w2);
      if (!wb_new)
          fail;
      }
      return C_integer((word)wb_new);
   }
end

function graphics_Window_draw_arc(self, x0, y0, rx0, ry0, ang1, ang2)
   body {
      double x, y, rx, ry, a1, a2;

      GetSelfW();

      if (dpointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);

      if (!cnv:C_double(rx0, rx))
          runerr(102, rx0);
      if (!cnv:C_double(ry0, ry))
          runerr(102, ry0);

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

      if (rx > 0 && ry > 0)
          drawarc(self_w, x, y, rx, ry, a1, a2);

      return self;
   }
end

function graphics_Window_draw_curve(self, argv[argc])
   body {
      int i, n, closed;
      double dx, dy, x0, y0, xN, yN, t;
      struct point *points;
      GetSelfW();

      closed = 0;
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;

      MemProtect(points = malloc(sizeof(struct point) * (n + 2)));

      if (n > 1) {
          CnvCDouble(argv[0], x0)
          CnvCDouble(argv[1], y0)
          CnvCDouble(argv[argc - 2], xN)
          CnvCDouble(argv[argc - 1], yN)
          if ((x0 == xN) && (y0 == yN)) {
              closed = 1;               /* duplicate the next to last point */
              CnvCDouble(argv[argc-4], t);
              points[0].x = t + self_w->context->dx;
              CnvCDouble(argv[argc-3], t);
              points[0].y = t + self_w->context->dy;
          }
          else {                       /* duplicate the first point */
              CnvCDouble(argv[0], t);
              points[0].x = t + self_w->context->dx;
              CnvCDouble(argv[1], t);
              points[0].y = t + self_w->context->dy;
          }
          for (i = 1; i <= n; i++) {
              int base = (i-1) * 2;
              CnvCDouble(argv[base], t);
              points[i].x = t + dx;
              CnvCDouble(argv[base + 1], t);
              points[i].y = t + dy;
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
              drawcurve(self_w, points, n+2);
          }
      }
      free(points);

      return self;
   }
end

function graphics_Window_draw_image_impl(self, x0, y0, d)
   body {
      word x, y;
      GetSelfW();
      if (pointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);
      {
      PixelsStaticParam(d, id);
      drawimgdata(self_w, x, y, id);
      }
      return self;
   }
end

function graphics_Window_draw_line(self, argv[argc])
   body {
      int i, n;
      struct point *points;
      int dx, dy;
      GetSelfW();
      CheckArgMultipleOf(2);
      MemProtect(points = malloc(sizeof(struct point) * (argc / 2)));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      n = 0;
      for(i = 0; i < argc; i += 2) {
          double x, y;
          CnvCDouble(argv[i], x);
          CnvCDouble(argv[i + 1], y);
          points[n].x = x + dx;
          points[n].y = y + dy;
          ++n;
      }
      drawlines(self_w, points, n);
      free(points);

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

function graphics_Window_draw_rectangle(self, x0, y0, w0, h0, thick0)
   body {
      word x, y, width, height, thick;

      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!def:C_integer(thick0, 1, thick))
          runerr(101, thick0);

      if (width > 0 && height > 0 && thick > 0)
          drawrectangle(self_w, x, y, width, height, thick);

      return self;
   }
end

function graphics_Window_draw_string(self, x0, y0, str)
   body {
      double x, y;
      GetSelfW();
      if (dpointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);
      if (!cnv:string_or_ucs(str,str))
          runerr(129, str);
      drawstring(self_w, x, y, &str);
      return self;
   }
end

function graphics_Window_erase_area(self, x0, y0, w0, h0)
   body {
      word x, y, width, height;
      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
      if (reducerect(self_w, 1, &x, &y, &width, &height))
          erasearea(self_w, x, y, width, height);
      return self;
   }
end

function graphics_Window_event(self)
   body {
      tended struct descrip d;
      GetSelfW();
      if (ListBlk(self_w->window->listp).size == 0) {
        pollevent(self_w);
        if (ListBlk(self_w->window->listp).size == 0)
            fail;
      }
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
      pollevent(self_w);

      return ws->listp;
   }
end

function graphics_Window_fill_arc(self, x0, y0, rx0, ry0, ang1, ang2)
   body {
      double x, y, rx, ry, a1, a2;

      GetSelfW();

      if (dpointargs(self_w, &x0, &x, &y) == Error)
          runerr(0);

      if (!cnv:C_double(rx0, rx))
          runerr(102, rx0);
      if (!cnv:C_double(ry0, ry))
          runerr(102, ry0);

      if (!def:C_double(ang1, 0.0, a1))
          runerr(102, ang1);
      if (a1 >= 0.0)
          a1 = fmod(a1, 2 * Pi);
      else
          a1 = -fmod(-a1, 2 * Pi);

      if (!def:C_double(ang2, 2 * Pi, a2))
          runerr(102, ang2);
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
      
      if (rx > 0 && ry > 0)
          fillarc(self_w, x, y, rx, ry, a1, a2);
      
      return self;
   }
end

function graphics_Window_fill_polygon(self, argv[argc])
   body {
      int i, n;
      struct point *points;
      int dx, dy;
      GetSelfW();
      CheckArgMultipleOf(2);
      MemProtect(points = malloc(sizeof(struct point) * (argc / 2)));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      n = 0;
      for(i = 0; i < argc; i += 2) {
          double x, y;
          CnvCDouble(argv[i], x);
          CnvCDouble(argv[i + 1], y);
          points[n].x = x + dx;
          points[n].y = y + dy;
          ++n;
      }
      fillpolygon(self_w, points, n);
      free(points);

      return self;
   }
end

function graphics_Window_fill_trapezoids(self, argv[argc])
   body {
      int i, n;
      struct trapezoid *traps;
      int dx, dy;
      GetSelfW();
      CheckArgMultipleOf(6);
      MemProtect(traps = malloc(sizeof(struct trapezoid) * (argc / 6)));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      n = 0;
      for(i = 0; i < argc; i += 6) {
          double top, x1, x2, bottom, x3, x4;
          CnvCDouble(argv[i], top);
          CnvCDouble(argv[i + 1], x1);
          CnvCDouble(argv[i + 2], x2);
          CnvCDouble(argv[i + 3], bottom);
          CnvCDouble(argv[i + 4], x3);
          CnvCDouble(argv[i + 5], x4);
          traps[n].top = top + dy;
          traps[n].x1 = x1 + dx;
          traps[n].x2 = x2 + dx;
          traps[n].bottom = bottom + dy;
          traps[n].x3 = x3 + dx;
          traps[n].x4 = x4 + dx;
          ++n;
      }
      filltrapezoids(self_w, traps, n);
      free(traps);

      return self;
   }
end

function graphics_Window_fill_triangles(self, argv[argc])
   body {
      int i, n;
      struct triangle *tris;
      int dx, dy;
      GetSelfW();
      CheckArgMultipleOf(6);
      MemProtect(tris = malloc(sizeof(struct triangle) * (argc / 6)));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      n = 0;
      for(i = 0; i < argc; i += 6) {
          double x1, y1, x2, y2, x3, y3;
          CnvCDouble(argv[i], x1);
          CnvCDouble(argv[i + 1], y1);
          CnvCDouble(argv[i + 2], x2);
          CnvCDouble(argv[i + 3], y2);
          CnvCDouble(argv[i + 4], x3);
          CnvCDouble(argv[i + 5], y3);
          tris[n].p1.x = x1 + dx;
          tris[n].p1.y = y1 + dy;
          tris[n].p2.x = x2 + dx;
          tris[n].p2.y = y2 + dy;
          tris[n].p3.x = x3 + dx;
          tris[n].p3.y = y3 + dy;
          ++n;
      }
      filltriangles(self_w, tris, n);
      free(tris);

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
      AttemptOp(lowerwindow(self_w));
      return self;
   }
end

function graphics_Window_get_pattern_impl(self)
   body {
      struct imgdata *imd;
      int rv;
      GetSelfW();
      imd = newimgdata();
      if ((rv = getpattern(self_w, imd)) != Succeeded)
          unlinkimgdata(imd);
      AttemptOp(rv);
      return C_integer((word)imd);
   }
end

function graphics_Window_get_icon_impl(self)
   body {
      struct imgdata *imd;
      int rv;
      GetSelfW();
      imd = newimgdata();
      if ((rv = getwindowicon(self_w, imd)) != Succeeded)
          unlinkimgdata(imd);
      AttemptOp(rv);
      return C_integer((word)imd);
   }
end

function graphics_Window_get_pixels_impl(self, x0, y0, w0, h0)
   body {
      struct imgdata *imd;
      word x, y, width, height;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (reducerect(self_w, 0, &x, &y, &width, &height)) {
          imd = newimgdata();
          imd->width = width;
          imd->height = height;
          captureimgdata(self_w, x, y, imd);
          return C_integer((word)imd);
      } else {
          /* Region completely off-screen */
          LitWhy("Region empty");
          fail;
      }
   }
end

function graphics_Pixels_new_open_impl(val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
      struct imgdata *imd;
      int rv;
      imd = newimgdata();
      if ((rv = interpimage(&val, imd)) != Succeeded)
          unlinkimgdata(imd);
      AttemptOp(rv);
      return C_integer((word)imd);
   }
end

function graphics_Pixels_to_file(self, fname)
   if !cnv:string(fname) then
       runerr(103, fname)
   body {
      char *s;
      GetSelfPixels();
      s = buffstr(&fname);
      AttemptOp(writeimagefile(s, self_id));
      return self;
   }
end

function graphics_Window_filter(self, x0, y0, w0, h0, spec)
   body {
      word x, y, width, height;
      struct filter *filter;
      struct imgdata *imd;
      int i, nfilter;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (is:list(spec)) {
          struct lgstate state;
          tended struct b_lelem *le;
          tended struct descrip elem;
          nfilter = ListBlk(spec).size;
          MemProtect(filter = malloc(1 + nfilter * sizeof(struct filter)));  /* + 1 to avoid 0 malloc */
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

      if (!reducerect(self_w, 1, &x, &y, &width, &height)) {
          free(filter);
          return self;
      }

      imd = newimgdata();
      imd->width = width;
      imd->height = height;
      captureimgdata(self_w, x, y, imd);

      for (i = 0; i < nfilter; ++i) {
          filter[i].imd = imd;
          filter[i].f(&filter[i]);
      }

      drawimgdata(self_w, x, y, imd);
      unlinkimgdata(imd);
      free(filter);

      return self;
   }
end

function graphics_Window_query_root_pointer(self)
   body {
      int x, y;
      tended struct descrip result;
      struct descrip t;
      GetSelfW();
      AttemptOp(queryrootpointer(self_w, &x, &y));
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
      AttemptOp(querypointer(self_w, &x, &y));
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
      AttemptOp(getdisplaysize(self_w, &width, &height));
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
      AttemptOp(warppointer(self_w, x + self_w->context->dx, y + self_w->context->dy));
      return self;
   }
end

function graphics_Window_raise(self)
   body {
      GetSelfW();
      AttemptOp(raisewindow(self_w));
      return self;
   }
end

function graphics_Window_focus(self)
   body {
      GetSelfW();
      AttemptOp(focuswindow(self_w));
      return self;
   }
end

function graphics_Window_text_width(self, s)
   if !cnv:string_or_ucs(s) then
      runerr(129, s)
   body {
      GetSelfW();
      return C_integer textwidth(self_w, &s);
   }
end

function graphics_Window_close(self)
   body {
      GetSelfW();
      *self_w_dptr = zerodesc;
      freewbinding(self_w);
      return self;
   }
end

function graphics_Window_own_selection(self, selection)
   if !cnv:string(selection) then
      runerr(103,selection)
   body {
       GetSelfW();
       AttemptOp(ownselection(self_w, buffstr(&selection)));
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
       buffnstr(&property, &t1, &selection, &t2, &target, &t3, NULL);
       AttemptOpCanErr(sendselectionresponse(self_w, requestor, t1, t2, t3, time, &data));
       return self;
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
       buffnstr(&selection, &t1, &target_type, &t2, NULL);
       AttemptOp(requestselection(self_w, t1, t2));
       return self;
   }
end

function graphics_Window_get_font_ascent(self)
   body {
       GetSelfW();
       return C_integer self_w->context->font->ascent;
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
      word x, y, width, height;
      GetSelfW();
      wc = self_w->context;

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!reducerect(self_w, 1, &x, &y, &width, &height))
          fail;

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

function graphics_Window_viewable(self, x0, y0, w0, h0)
   body {
      tended struct descrip result;
      struct descrip t;
      wcp wc;
      word x, y, width, height;
      GetSelfW();
      wc = self_w->context;

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!reducerect(self_w, 0, &x, &y, &width, &height))
          fail;

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
       int i;
       GetSelfW();
       AttemptOp(getdepth(self_w, &i));
       return C_integer i;
   }
end

function graphics_Window_get_format(self)
   body {
       struct descrip result;
       GetSelfW();
       CMakeStr(getimgdataformat(self_w)->name, &result);
       return result;
   }
end

function graphics_Window_get_font_descent(self)
   body {
       GetSelfW();
       return C_integer self_w->context->font->descent;
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
       GetSelfW();
       return C_integer self_w->context->dx;
   }
end

function graphics_Window_get_dy(self)
   body {
       GetSelfW();
       return C_integer self_w->context->dy;
   }
end

function graphics_Window_get_absolute_leading(self)
   body {
       GetSelfW();
       return C_integer (0.5 + self_w->context->leading * (self_w->context->font->ascent + self_w->context->font->descent));
   }
end

function graphics_Window_get_leading(self)
   body {
       GetSelfW();
       return C_double self_w->context->leading;
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
       GetSelfW();
       return C_integer self_w->context->font->maxwidth;
   }
end

function graphics_Window_get_geometry(self)
   body {
       tended struct descrip result;
       struct descrip t;
       wsp ws;
       GetSelfW();
       AttemptOp(getpos(self_w));
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
       GetSelfW();
       return C_integer self_w->window->height;
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
       GetSelfW();
       return self_w->window->windowlabel;
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
       GetSelfW();
       return C_double getlinewidth(self_w);
   }
end

function graphics_Window_get_max_height(self)
   body {
       GetSelfW();
       return C_integer self_w->window->maxheight;
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
       GetSelfW();
       return C_integer self_w->window->maxwidth;
   }
end

function graphics_Window_get_min_height(self)
   body {
       GetSelfW();
       return C_integer self_w->window->minheight;
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
       GetSelfW();
       return C_integer self_w->window->minwidth;
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
       AttemptOp(getpos(self_w));
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
       GetSelfW();
       AttemptOp(getpos(self_w));
       return C_integer self_w->window->x;
   }
end

function graphics_Window_get_y(self)
   body {
       GetSelfW();
       AttemptOp(getpos(self_w));
       return C_integer self_w->window->y;
   }
end

function graphics_Window_can_resize(self)
   body {
       GetSelfW();
       if (self_w->window->resizable)
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

function graphics_Window_get_references(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       create_list(2, &result);
       MakeInt(self_w->window->refcount, &t);
       list_put(&result, &t);
       MakeInt(self_w->context->refcount, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_width(self)
   body {
       GetSelfW();
       return C_integer self_w->window->width;
   }
end

#begdef SimpleAttr(wconfig)
do {
    doconfig(self_w, wconfig);
} while(0)
#enddef

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
      SimpleAttr(C_CLIP);
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
      SimpleAttr(C_CLIP);
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

function graphics_Window_set_leading(self, val)
   body {
       double d;
       GetSelfW();
       if (!cnv:C_double(val, d))
           runerr(102, val);
       if (d < 0.0)
           Drunerr(148, d);
       self_w->context->leading = d;
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

function graphics_Window_set_pattern_impl(self, val)
   body {
      GetSelfW();
      {
      if (is:null(val))
          AttemptAttr(setpattern(self_w, 0), "Failed to clear pattern");
      else {
          PixelsStaticParam(val, id);
          AttemptAttr(setpattern(self_w, id), "Failed to set pattern");
      }
      return self;
      }
   }
end

function graphics_Window_set_font(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfont(self_w, buffstr(&val)), "Invalid or unavailable font");
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
       SimpleAttr(C_SIZE | C_POS);
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
       SimpleAttr(C_SIZE);
       return self;
   }
end

function graphics_Window_set_icon_impl(self, val)
   body {
      GetSelfW();
      {
      if (is:null(val))
          AttemptAttr(setwindowicon(self_w, 0), "Failed to clear window icon");
      else {
          PixelsStaticParam(val, id);
          AttemptAttr(setwindowicon(self_w, id), "Failed to set window icon");
      }
      return self;
      }
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
   if !cnv:ucs(val) then
      runerr(128, val)
   body {
       GetSelfW();
       AttemptAttr(setwindowlabel(self_w, &val), "Failed to set window label");
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
       double d;
       GetSelfW();
       if (!cnv:C_double(val, d))
           runerr(102, val);
       if (d <= 0.0)
           Drunerr(148, d);
       AttemptAttr(setlinewidth(self_w, d), "Invalid line_width");
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
       SimpleAttr(C_MAXSIZE);
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
       SimpleAttr(C_MAXSIZE);
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
       SimpleAttr(C_MAXSIZE);
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
       SimpleAttr(C_MINSIZE);
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
       if (height < 1)
           Irunerr(148, height);
       self_w->window->minwidth = width;
       self_w->window->minheight = height;
       SimpleAttr(C_MINSIZE);
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
       SimpleAttr(C_MINSIZE);
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
       SimpleAttr(C_POS);
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
       SimpleAttr(C_POS);
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
       SimpleAttr(C_POS);
       return self;
   }
end

function graphics_Window_set_resize(self, val)
   body {
       GetSelfW();
       if (!isflag(&val))
           runerr(171, val);
       self_w->window->resizable = !is:null(val);
       SimpleAttr(C_RESIZE);
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
       SimpleAttr(C_SIZE);
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
       SimpleAttr(C_SIZE);
       return self;
   }
end

function graphics_Window_set_transient_for(self, val)
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

function graphics_Window_define_pointer(self, name, x, y)
   if !cnv:string(name) then
       runerr(103, name)
   if !def:C_integer(x, 0) then
      runerr(101, x)
   if !def:C_integer(y, 0) then
      runerr(101, y)
   body {
       char *s;
       GetSelfW();
       s = buffstr(&name);
       AttemptOp(definepointer(self_w, s, x, y));
       return self;
   }
end

function graphics_Window_copy_pointer(self, dest, src)
   if !cnv:string(dest) then
       runerr(103, dest)
   if !cnv:string(src) then
       runerr(103, src)
   body {
       char *t1, *t2;
       GetSelfW();
       buffnstr(&dest, &t1, &src, &t2, NULL);
       AttemptAttr(copypointer(self_w, t1, t2), "Invalid pointer");
       return self;
   }
end

#else    /* Graphics */

UnsupportedFunc(graphics_Window_new_impl)
UnsupportedFunc(graphics_Pixels_new_open_impl)
UnsupportedFunc(graphics_Pixels_to_file)

#endif   

function graphics_Window_color_value(s)
    if !cnv:string(s) then
       runerr(103, s);
   body {
      int r, g, b, a;
      tended struct descrip result;
      if (!parsecolor(buffstr(&s), &r, &g, &b, &a))
          fail;
      cstr2string(tocolorstring(r, g, b, a), &result);
      return result;
   }
end

function graphics_Window_parse_color(s)
    if !cnv:string(s) then
       runerr(103, s);
   body {
      int r, g, b, a;
      tended struct descrip result;
      struct descrip t;
      if (!parsecolor(buffstr(&s), &r, &g, &b, &a))
          fail;
      create_list(4, &result);
      MakeInt(r, &t);
      list_put(&result, &t);
      MakeInt(g, &t);
      list_put(&result, &t);
      MakeInt(b, &t);
      list_put(&result, &t);
      MakeInt(a, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_palette_chars(pal)
   if !cnv:string(pal) then
       runerr(103, pal)
   body {
      int n;
      if (!parsepalette(buffstr(&pal), &n)) {
          LitWhy("Invalid palette");
          fail;
      }
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
      if (!e->a) {
          LitWhy("Invalid character");
          fail;
      }
      cstr2string(tocolorstring(e->r, e->g, e->b, e->a), &result);
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
      if (!parsecolor(buffstr(&s2), &r, &g, &b, 0)) {
          LitWhy("Invalid color");
          fail;
      }
      return string(1, rgbkey(p, r, g, b));
   }
end

function graphics_Window_get_default_font()
   body {
       tended struct descrip result;
       cstr2string(defaultfont, &result);
       return result;
   }
end

function graphics_Window_get_default_font_size()
   body {
       return C_double defaultfontsize;
   }
end

function graphics_Pixels_new_blank_impl(width, height, format)
   if !cnv:C_integer(width) then
      runerr(101, width)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
       struct imgdata *imd;
       struct imgdataformat *fmt;
       if (width < 1)
           Irunerr(148, width);
       if (height < 1)
           Irunerr(148, height);
       if (is:null(format))
           fmt = &imgdataformat_RGBA64;
       else {
           if (!cnv:string(format, format))
               runerr(103, format);
           fmt = parseimgdataformat(buffstr(&format));
           if (!fmt) {
               LitWhy("Invalid format");
               fail;
           }
       }
       imd = initimgdata(width, height, fmt);
       /* Clear the data */
       memset(imd->data, 0, fmt->getlength(imd));
       if (imd->paltbl)
           memset(imd->paltbl, 0, fmt->palette_size * sizeof(struct palentry));
       return C_integer((word)imd);
   }
end


function graphics_Pixels_get_width(self)
   body {
      GetSelfPixels();
      return C_integer self_id->width;
   }
end

function graphics_Pixels_get_height(self)
   body {
      GetSelfPixels();
      return C_integer self_id->height;
   }
end

function graphics_Pixels_close(self)
   body {
      GetSelfPixels();
      unlinkimgdata(self_id);
       *self_id_dptr = zerodesc;
      return self;
   }
end

function graphics_Pixels_get_rgba(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      int r, g, b, a;
      tended struct descrip result;
      struct descrip t;
      GetSelfPixels();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      self_id->format->getpixel(self_id, x, y, &r, &g, &b, &a);
      create_list(4, &result);
      MakeInt(r, &t);
      list_put(&result, &t);
      MakeInt(g, &t);
      list_put(&result, &t);
      MakeInt(b, &t);
      list_put(&result, &t);
      MakeInt(a, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Pixels_copy_pixel(self, x1, y1, other, x2, y2)
   if !cnv:C_integer(x1) then
      runerr(101, x1)
   if !cnv:C_integer(y1) then
      runerr(101, y1)
   if !cnv:C_integer(x2) then
      runerr(101, x2)
   if !cnv:C_integer(y2) then
      runerr(101, y2)
   body {
      int r, g, b, a;
      GetSelfPixels();
      if (x1 < 0 || x1 >= self_id->width || y1 < 0 || y1 >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      {
      PixelsStaticParam(other, id2);
      if (x2 < 0 || x2 >= id2->width || y2 < 0 || y2 >= id2->height) {
          LitWhy("Out of range");
          fail;
      }
      self_id->format->getpixel(self_id, x1, y1, &r, &g, &b, &a);
      id2->format->setpixel(id2, x2, y2, r, g, b, a);
      }
      return self;
   }
end

function graphics_Pixels_get(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      int r, g, b, a;
      tended struct descrip result;
      GetSelfPixels();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      self_id->format->getpixel(self_id, x, y, &r, &g, &b, &a);
      cstr2string(tocolorstring(r, g, b, a), &result);
      return result;
   }
end

function graphics_Pixels_set_rgba(self, x, y, r, g, b, a)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:C_integer(r) then
      runerr(101, r)
   if !cnv:C_integer(g) then
      runerr(101, g)
   if !cnv:C_integer(b) then
      runerr(101, b)
   if !def:C_integer(a, 65535) then
      runerr(101, a)
   body {
      GetSelfPixels();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      self_id->format->setpixel(self_id, x, y, r & 0xffff, g & 0xffff, b & 0xffff, a & 0xffff);
      return self;
   }
end

function graphics_Pixels_set(self, x, y, v)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:string(v) then
       runerr(103, v)
   body {
      int r, g, b, a;
      GetSelfPixels();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      if (!parsecolor(buffstr(&v), &r, &g, &b, &a)) {
          LitWhy("Invalid color");
          fail;
      }
      self_id->format->setpixel(self_id, x, y, r, g, b, a);
      return self;
   }
end

function graphics_Pixels_get_format(self)
   body {
      struct descrip result;
      GetSelfPixels();
      CMakeStr(self_id->format->name, &result);
      return result;
   }
end

function graphics_Pixels_get_data(self)
   body {
      tended struct descrip result;
      GetSelfPixels();
      bytes2string((char *)self_id->data, self_id->format->getlength(self_id), &result);
      return result;
   }
end

function graphics_Pixels_set_data(self, s)
   if !cnv:string(s) then
       runerr(103, s)
   body {
      tended struct descrip result;
      int n;
      GetSelfPixels();
      n = self_id->format->getlength(self_id);
      if (StrLen(s) < n) {
          memcpy(self_id->data, StrLoc(s), StrLen(s));
          memset(self_id->data + StrLen(s), 0, n - StrLen(s));
      } else
          memcpy(self_id->data, StrLoc(s), n);
      return self;
   }
end

function graphics_Pixels_clone_impl(self)
   body {
      struct imgdata *imd;
      int n;
      GetSelfPixels();
      imd = initimgdata(self_id->width, self_id->height, self_id->format);
      n = self_id->format->palette_size;
      if (n)
          memcpy(imd->paltbl, self_id->paltbl, n * sizeof(struct palentry));
      memcpy(imd->data, self_id->data, imd->format->getlength(self_id));
      return C_integer((word)imd);
   }
end

function graphics_Pixels_shared_copy_impl(self)
   body {
      GetSelfPixels();
      return C_integer((word)linkimgdata(self_id));
   }
end

function graphics_Pixels_convert_impl(self, format)
   if !cnv:string(format) then
       runerr(103, format)
   body {
      struct imgdata *imd;
      struct imgdataformat *fmt;
      GetSelfPixels();
      fmt = parseimgdataformat(buffstr(&format));
      if (!fmt) {
          LitWhy("Invalid format");
          fail;
      }
      imd = initimgdata(self_id->width, self_id->height, fmt);
      copyimgdata(imd, self_id);
      return C_integer((word)imd);
   }
end

function graphics_Pixels_get_alpha_depth(self)
   body {
      GetSelfPixels();
      return C_integer self_id->format->alpha_depth;
   }
end

function graphics_Pixels_get_color_depth(self)
   body {
      GetSelfPixels();
      return C_integer self_id->format->color_depth;
   }
end

function graphics_Pixels_get_palette_size(self)
   body {
      int n;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0)
          fail;
      else
          return C_integer n;
   }
end

function graphics_Pixels_get_palette(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
      struct palentry *e;
      tended struct descrip result;
      int n;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0) {
          LitWhy("Can only get a palette entry with a PALETTE format");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      e = &self_id->paltbl[i];
      cstr2string(tocolorstring(e->r, e->g, e->b, e->a), &result);
      return result;
   }
end

function graphics_Pixels_get_palette_rgba(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
      struct palentry *e;
      tended struct descrip result;
      struct descrip t;
      int n;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0) {
          LitWhy("Can only get a palette entry with a PALETTE format");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      e = &self_id->paltbl[i];
      create_list(4, &result);
      MakeInt(e->r, &t);
      list_put(&result, &t);
      MakeInt(e->g, &t);
      list_put(&result, &t);
      MakeInt(e->b, &t);
      list_put(&result, &t);
      MakeInt(e->a, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Pixels_set_palette_rgba(self, i, r, g, b, a)
   if !cnv:C_integer(i) then
      runerr(101, i)
   if !cnv:C_integer(r) then
      runerr(101, r)
   if !cnv:C_integer(g) then
      runerr(101, g)
   if !cnv:C_integer(b) then
      runerr(101, b)
   if !def:C_integer(a, 65535) then
      runerr(101, a)
   body {
      struct palentry *e;
      int n;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0) {
          LitWhy("Can only set a palette entry with a PALETTE format");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      e = &self_id->paltbl[i];
      e->r = r & 0xffff;
      e->g = g & 0xffff;
      e->b = b & 0xffff;
      e->a = a & 0xffff;
      return self;
   }
end

function graphics_Pixels_set_palette(self, i, v)
   if !cnv:C_integer(i) then
      runerr(101, i)
   if !cnv:string(v) then
       runerr(103, v)
   body {
      struct palentry *e;
      int n, r, g, b, a;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0) {
          LitWhy("Can only set a palette entry with a PALETTE format");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      if (!parsecolor(buffstr(&v), &r, &g, &b, &a)) {
          LitWhy("Invalid color");
          fail;
      }
      e = &self_id->paltbl[i];
      e->r = r;
      e->g = g;
      e->b = b;
      e->a = a;
      return self;
      fail;
   }
end

function graphics_Pixels_get_palette_index(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      GetSelfPixels();
      if (self_id->format->palette_size == 0) {
          LitWhy("Can only get a palette index with a PALETTE format");
          fail;
      }
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      return C_integer self_id->format->getpaletteindex(self_id, x, y);
   }
end

function graphics_Pixels_set_palette_index(self, x, y, i)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
      int n;
      GetSelfPixels();
      n = self_id->format->palette_size;
      if (n == 0) {
          LitWhy("Can only set a palette index with a PALETTE format");
          fail;
      }
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      self_id->format->setpaletteindex(self_id, x, y, i);
      return self;
   }
end

function graphics_Pixels_load_palette(self, pal)
   if !cnv:string(pal) then
       runerr(103, pal)
   body {
      int p;
      struct palentry *e;
      GetSelfPixels();
      if (self_id->format != &imgdataformat_PALETTE8) {
          LitWhy("Can only load a palette with PALETTE8 format");
          fail;
      }
      if (!parsepalette(buffstr(&pal), &p)) {
          LitWhy("Invalid palette");
          fail;
      }
      e = palsetup(p); 
      memcpy(self_id->paltbl, e, 256 * sizeof(struct palentry));
      return self;
   }
end

function graphics_Pixels_get_references(self)
   body {
       GetSelfPixels();
       return C_integer self_id->refcount;
   }
end
