/*
 * File: fwindow.r - Icon graphics interface
 *
 */

static struct sdescrip pixclassname = {15, "graphics.Pixels"};

static struct sdescrip idpf = {3, "idp"};

#begdef ImageDataStaticParam(p, x)
struct imgdata *x;
dptr x##_dptr;
static struct inline_field_cache x##_ic;
static struct inline_global_cache x##_igc;
if (!c_is(&p, (dptr)&pixclassname, &x##_igc))
    runerr(205, p);
x##_dptr = c_get_instance_data(&p, (dptr)&idpf, &x##_ic);
if (!x##_dptr)
    syserr("Missing idp field");
(x) = (struct imgdata *)IntVal(*x##_dptr);
if (!(x))
    runerr(152, p);
#enddef

#begdef GetSelfImageData()
struct imgdata *self_id;
dptr self_id_dptr;
static struct inline_field_cache self_id_ic;
self_id_dptr = c_get_instance_data(&self, (dptr)&idpf, &self_id_ic);
if (!self_id_dptr)
    syserr("Missing idp field");
self_id = (struct imgdata *)IntVal(*self_id_dptr);
if (!self_id)
    runerr(152, self);
#enddef


#if Graphics

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

function graphics_Window_open_impl(display)
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
      if (grabpointer(self_w) != Succeeded)
          fail;
      return self;
   }
end

function graphics_Window_ungrab_pointer(self)
   body {
      GetSelfW();
      if (ungrabpointer(self_w) != Succeeded)
          fail;
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
       w2 = alcwbinding();
       w2->window = self_w->window;
       w2->window->refcount++;
       w2->context = clonecontext(self_w);
       return C_integer((word)w2);
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

      return self;
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
      word dx, dy, x0, y0, xN, yN, t;
      struct point *points;
      GetSelfW();

      closed = 0;
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;

      MemProtect(points = malloc(sizeof(struct point) * (n+2)));

      if (n > 1) {
          CnvCInteger(argv[0], x0)
          CnvCInteger(argv[1], y0)
          CnvCInteger(argv[argc - 2], xN)
          CnvCInteger(argv[argc - 1], yN)
          if ((x0 == xN) && (y0 == yN)) {
              closed = 1;               /* duplicate the next to last point */
              CnvCInteger(argv[argc-4], t);
              points[0].x = t + self_w->context->dx;
              CnvCInteger(argv[argc-3], t);
              points[0].y = t + self_w->context->dy;
          }
          else {                       /* duplicate the first point */
              CnvCInteger(argv[0], t);
              points[0].x = t + self_w->context->dx;
              CnvCInteger(argv[1], t);
              points[0].y = t + self_w->context->dy;
          }
          for (i = 1; i <= n; i++) {
              int base = (i-1) * 2;
              CnvCInteger(argv[base], t);
              points[i].x = t + dx;
              CnvCInteger(argv[base + 1], t);
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
              drawCurve(self_w, points, n+2);
          }
      }
      free(points);

      return self;
   }
end

function graphics_Window_draw_image_impl(self, x0, y0, w0, h0, d)
   body {
      word x, y, width, height;
      GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
      {
      ImageDataStaticParam(d, id);
      drawimgdata(self_w, x, y, width, height, id);
      }
      return self;
   }
end

function graphics_Window_draw_line(self, argv[argc])
   body {
      int i, j, n;
      struct point points[MAXPOINTS];
      int dx, dy;

      GetSelfW();

      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i = 0, j = 0; i < n; i++, j++) {
          int base = i * 2;
          word t;
          if (j == MAXPOINTS) {
              drawlines(self_w, points, MAXPOINTS);
              points[0] = points[MAXPOINTS-1];
              j = 1;
          }
          CnvCInteger(argv[base], t);
          points[j].x = t + dx;
          CnvCInteger(argv[base + 1], t);
          points[j].y = t + dy;
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
      struct point points[MAXPOINTS];
      word t;

      GetSelfW();
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;

      /*
       * To make a closed polygon, start with the *last* point.
       */
      CnvCInteger(argv[argc - 2], t);
      points[0].x = t + dx;
      CnvCInteger(argv[argc - 1], t);
      points[0].x = t + dy;

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
          CnvCInteger(argv[base], t);
          points[j].x = t + dx;
          CnvCInteger(argv[base + 1], t);
          points[j].y = t + dy;
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
      struct point *points;
      int dx, dy;
      GetSelfW();

      CheckArgMultipleOf(2);

      /*
       * Allocate space for all the points in a contiguous array,
       * because a FillPolygon must be performed in a single call.
       */
      n = argc>>1;
      MemProtect(points = malloc(sizeof(struct point) * n));
      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i=0; i < n; i++) {
          int base = i * 2;
          word t;
          CnvCInteger(argv[base], t);
          points[i].x = t + dx;
          CnvCInteger(argv[base + 1], t);
          points[i].y = t + dy;
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

function graphics_Window_get_pixels_impl(self, x0, y0, w0, h0, format)
   if !def:C_integer(format, IMGDATA_RGBA64) then
      runerr(101, format)
   body {
      struct imgdata *imd;
      struct imgmem imem;
      word x, y, width, height;
      int i, j, r, g, b;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      if (!validimgdataformat(format))
          Irunerr(153, format);
      if (imgdatapalettesize(format) > 0) {
          LitWhy("Cannot use a PALETTE format as destination");
          fail;
      }

      if (initimgmem(self_w, &imem, 1, 0, x, y, width, height)) {
          MemProtect(imd = malloc(sizeof(struct imgdata)));
          imd->width = imem.width;
          imd->height = imem.height;
          imd->format = format;
          imd->paltbl = 0;
          MemProtect(imd->data = malloc(getimgdatalength(imd)));
          for (j = 0; j < imem.height; j++) {
              for (i = 0; i < imem.width; i++) {
                  getimgmempixel(&imem, i, j, &r, &g, &b);
                  setimgdatapixel(imd, i, j, r, g, b, 65535);
              }
          }
          freeimgmem(&imem);
          return C_integer((word)imd);
      } else {
          /* Region completely off-screen */
          LitWhy("Region empty");
          fail;
      }
   }
end

function graphics_Pixels_open_impl(val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
      struct imgdata *imd;
      MemProtect(imd = malloc(sizeof(struct imgdata)));
      if (interpimage(&val, imd) == Succeeded)
          return C_integer((word)imd);
      else {
          free(imd);
          fail;
      }
   }
end

function graphics_Pixels_to_file(self, fname)
   if !cnv:string(fname) then
       runerr(103, fname)
   body {
      char *s;
      GetSelfImageData();
      s = buffstr(&fname);
      if (writeimagefile(s, self_id) != Succeeded)
          fail;
      return self;
   }
end

function graphics_Window_filter(self, x0, y0, w0, h0, spec)
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
          return self;
      }

      for (i = 0; i < nfilter; ++i) {
          filter[i].imem = &imem;
          filter[i].f(&filter[i]);
      }
      saveimgmem(self_w, &imem);
      freeimgmem(&imem);
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
       buffnstr(&property, &t1, &selection, &t2, &target, &t3, NULL);
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
       buffnstr(&selection, &t1, &target_type, &t2, NULL);
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

function graphics_Window_get_width(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->width, &result);
       return result;
   }
end

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
      ImageDataStaticParam(val, id);
      AttemptAttr(setwindowicon(self_w, id), "Failed to set window icon");
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

#else    /* Graphics */

UnsupportedFunc(graphics_Window_open_impl)
UnsupportedFunc(graphics_Pixels_open_impl)
UnsupportedFunc(graphics_Pixels_to_file)

#endif   

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
      if (!e->a) {
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

function graphics_Pixels_blank_impl(width, height, format)
   if !cnv:C_integer(width) then
      runerr(101, width)
   if !cnv:C_integer(height) then
      runerr(101, height)
   if !def:C_integer(format, IMGDATA_RGBA64) then
      runerr(101, format)
   body {
       struct imgdata *imd;
       int n;
       if (width < 1)
           Irunerr(148, width);
       if (height < 1)
           Irunerr(148, height);
       if (!validimgdataformat(format))
           Irunerr(153, format);
       MemProtect(imd = malloc(sizeof(struct imgdata)));
       imd->width = width;
       imd->height = height;
       imd->format = format;
       n = imgdatapalettesize(format);
       if (n > 0)
           MemProtect(imd->paltbl = calloc(n, sizeof(struct palentry)));
       else
           imd->paltbl = 0;
       MemProtect(imd->data = calloc(getimgdatalength(imd), 1));
       return C_integer((word)imd);
   }
end


function graphics_Pixels_get_width(self)
   body {
      struct descrip result;
      GetSelfImageData();
      MakeInt(self_id->width, &result);
      return result;
   }
end

function graphics_Pixels_get_height(self)
   body {
      struct descrip result;
      GetSelfImageData();
      MakeInt(self_id->height, &result);
      return result;
   }
end

function graphics_Pixels_close(self)
   body {
      GetSelfImageData();
      freeimgdata(self_id);
      free(self_id);
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
      GetSelfImageData();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      getimgdatapixel(self_id, x, y, &r, &g, &b, &a);
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

function graphics_Pixels_get(self, x, y)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
      int r, g, b, a;
      tended struct descrip result;
      char buff[64];
      GetSelfImageData();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      getimgdatapixel(self_id, x, y, &r, &g, &b, &a);
      sprintf(buff, "%d,%d,%d", r, g, b);
      cstr2string(buff, &result);
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
      GetSelfImageData();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      if (imgdatapalettesize(self_id->format) > 0) {
          LitWhy("Can't set a pixel with a PALETTE format");
          fail;
      }
      setimgdatapixel(self_id, x, y, r & 0xffff, g & 0xffff, b & 0xffff, a & 0xffff);
      return self;
   }
end

function graphics_Pixels_set(self, x, y, v, a)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:string(v) then
       runerr(103, v)
   if !def:C_integer(a, 65535) then
      runerr(101, a)
   body {
      int r, g, b;
      GetSelfImageData();
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      if (imgdatapalettesize(self_id->format) > 0) {
          LitWhy("Can't set a pixel with a PALETTE format");
          fail;
      }
      if (!parsecolor(buffstr(&v), &r, &g, &b)) {
          LitWhy("Invalid color");
          fail;
      }
      setimgdatapixel(self_id, x, y, r, g, b, a);
      return self;
   }
end

function graphics_Pixels_get_format(self)
   body {
      GetSelfImageData();
      return C_integer self_id->format;
   }
end

function graphics_Pixels_get_data(self)
   body {
      tended struct descrip result;
      GetSelfImageData();
      bytes2string((char *)self_id->data, getimgdatalength(self_id), &result);
      return result;
   }
end

function graphics_Pixels_set_data(self, s)
   if !cnv:string(s) then
       runerr(103, s)
   body {
      tended struct descrip result;
      int n;
      GetSelfImageData();
      n = getimgdatalength(self_id);
      if (StrLen(s) < n) {
          memcpy(self_id->data, StrLoc(s), StrLen(s));
          memset(self_id->data + StrLen(s), 0, n - StrLen(s));
      } else
          memcpy(self_id->data, StrLoc(s), n);
      return self;
   }
end

function graphics_Pixels_set_size(self, width, height)
   if !cnv:C_integer(width) then
      runerr(101, width)
   if !cnv:C_integer(height) then
      runerr(101, height)
   body {
      int old_n, new_n;
      GetSelfImageData();
       if (width < 1)
           Irunerr(148, width);
       if (height < 1)
           Irunerr(148, height);
      old_n = getimgdatalength(self_id);
      self_id->width = width;
      self_id->height = height;
      new_n = getimgdatalength(self_id);
      MemProtect(self_id->data = realloc(self_id->data, new_n));
      if (new_n > old_n)
          memset(self_id->data + old_n, 0, new_n - old_n);
      return self;
   }
end

function graphics_Pixels_convert_impl(self, format)
   if !def:C_integer(format, IMGDATA_RGBA64) then
      runerr(101, format)
   body {
      struct imgdata *imd;
      int x, y, r, g, b, a, width, height;
      GetSelfImageData();
      if (!validimgdataformat(format))
          Irunerr(153, format);
      if (imgdatapalettesize(format) > 0) {
          LitWhy("Cannot use a PALETTE format as destination");
          fail;
      }
      width = self_id->width;
      height = self_id->height;
      MemProtect(imd = malloc(sizeof(struct imgdata)));
      imd->width = width;
      imd->height = height;
      imd->format = format;
      imd->paltbl = 0;
      MemProtect(imd->data = malloc(getimgdatalength(imd)));
      for (y = 0; y < height; ++y) {
          for (x = 0; x < width; ++x) {
              getimgdatapixel(self_id, x, y, &r, &g, &b, &a);
              setimgdatapixel(imd, x, y, r, g, b, a);
          }
      }
      return C_integer((word)imd);
   }
end

function graphics_Pixels_clone_impl(self)
   body {
      struct imgdata *imd;
      int n;
      GetSelfImageData();
      MemProtect(imd = malloc(sizeof(struct imgdata)));
      imd->width = self_id->width;
      imd->height = self_id->height;
      imd->format = self_id->format;
      n = imgdatapalettesize(self_id->format);
      if (n) {
          MemProtect(imd->paltbl = malloc(n * sizeof(struct palentry)));
          memcpy(imd->paltbl, self_id->paltbl, n * sizeof(struct palentry));
      } else
          imd->paltbl = 0;
      n = getimgdatalength(self_id);
      MemProtect(imd->data = malloc(n));
      memcpy(imd->data, self_id->data, n);
      return C_integer((word)imd);
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
      GetSelfImageData();
      n = imgdatapalettesize(self_id->format);
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
      GetSelfImageData();
      n = imgdatapalettesize(self_id->format);
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

function graphics_Pixels_set_palette(self, i, v, a)
   if !cnv:C_integer(i) then
      runerr(101, i)
   if !cnv:string(v) then
       runerr(103, v)
   if !def:C_integer(a, 65535) then
      runerr(101, a)
   body {
      struct palentry *e;
      int n, r, g, b;
      GetSelfImageData();
      n = imgdatapalettesize(self_id->format);
      if (n == 0) {
          LitWhy("Can only set a palette entry with a PALETTE format");
          fail;
      }
      if (i < 0 || i >= n) {
          LitWhy("Out of range");
          fail;
      }
      if (!parsecolor(buffstr(&v), &r, &g, &b)) {
          LitWhy("Invalid color");
          fail;
      }
      e = &self_id->paltbl[i];
      e->r = r;
      e->g = g;
      e->b = b;
      e->a = a & 0xffff;
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
      struct descrip result;
      GetSelfImageData();
      if (imgdatapalettesize(self_id->format) == 0) {
          LitWhy("Can only get a palette index with a PALETTE format");
          fail;
      }
      if (x < 0 || x >= self_id->width || y < 0 || y >= self_id->height) {
          LitWhy("Out of range");
          fail;
      }
      MakeInt(getimgdatapaletteindex(self_id, x, y), &result);
      return result;
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
      GetSelfImageData();
      n = imgdatapalettesize(self_id->format);
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
      setimgdatapaletteindex(self_id, x, y, i);
      return self;
   }
end

function graphics_Pixels_load_palette(self, pal)
   if !cnv:string(pal) then
       runerr(103, pal)
   body {
      int p;
      struct palentry *e;
      GetSelfImageData();
      if (self_id->format != IMGDATA_PALETTE8) {
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
