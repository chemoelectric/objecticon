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

static char attr_buff[4096];     /* Buff for attribute values */


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

static char *buffstr(dptr d)
{
    if (StrLen(*d) >= sizeof(attr_buff))
        fatalerr(149, d);
    memcpy(attr_buff, StrLoc(*d), StrLen(*d));
    attr_buff[StrLen(*d)] = 0;
    return attr_buff;
}

#passthru #define _DPTR dptr
#passthru #define _CHARPP char **
static void buffnstr(dptr d, char **s, ...)
{
    int free;
    char *t;
    va_list ap;
    va_start(ap, s);
    t = attr_buff;
    free = sizeof(attr_buff);
    while (d) {
        if (StrLen(*d) >= free)
            fatalerr(149, d);
        memcpy(t, StrLoc(*d), StrLen(*d));
        *s = t;
        t += StrLen(*d);
        *t++ = 0;
        free -= StrLen(*d) + 1;
        d = va_arg(ap, _DPTR);
        if (!d)
            break;
        s = va_arg(ap, _CHARPP);
    }
    va_end(ap);
}

function graphics_Window_wcreate(display)
   body {
      wbp w;
      inattr = 1;
      wconfig = 0;
      if (is:null(display))
          w = wcreate(0);
      else {
         if (!cnv:string(display, display))
             runerr(103, display);
         w = wcreate(buffstr(&display));
      }
      if (!w)
          fail;
      return C_integer (word) w;
   }
end

function graphics_Window_wopen(self, parent)
   body {
      wbp w2;
      GetSelfW();

      if (is:null(parent)) {
          if (wopen(self_w, 0) != Succeeded) {
              *self_w_dptr = zerodesc;
              freewbinding(self_w);
              fail;
          }
      } else {
          WindowStaticParam(parent, w2);
          if (wopen(self_w, w2) != Succeeded) {
              *self_w_dptr = zerodesc;
              freewbinding(self_w);
              fail;
          }
      }
      inattr = wconfig = 0;
      return self;
   }
end

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
      if (wconfig) {
          doconfig(self_w, wconfig);
          wconfig = 0;
      }
      fail;
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

function graphics_Window_color_value(k)
   body {
      word n;
      int r, g, b, a;
      tended char *s;
      char tmp[32];

      a = 65535;

      if (!cnv:C_string(k, s))
          runerr(103, k);

      if (parsecolor(s, &r, &g, &b, &a) == Succeeded) {
          tended struct descrip result;
          if (a < 65535)
              sprintf(tmp,"%d,%d,%d,%d", r, g, b, a);
          else
              sprintf(tmp,"%d,%d,%d", r, g, b);
          cstr2string(tmp, &result);
          return result;
      }
      fail;
   }
end

function graphics_Window_copy_to(self, dest, x0, y0, w0, h0, x1, y1)
   body {
      int n, r;
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

      if (!def:C_integer(x1, -self_w->context->dx, x2))
          runerr(101, x1);

      if (!def:C_integer(y1, -self_w->context->dy, y2))
          runerr(101, y1);

      if (copyarea(self_w, w2, x, y, width, height, x2, y2) == Failed)
          fail;

      return nulldesc;
   }
end

function graphics_Window_couple_impl(win, win2)
   body {
      tended struct descrip sbuf, sbuf2;
      wbp wb, wb2, wb_new;
      wsp ws;

      {
          WindowStaticParam(win, tmp);
          wb = tmp;
      }
      {
          WindowStaticParam(win2, tmp);
          wb2 = tmp;
      }

      /*
       * make the new binding
       */
      wb_new = alcwbinding();

      wb_new->window = ws = wb->window;
      /*
       * Bind an existing window to an existing context,
       * and up the context's reference count.
       */
      if (rebind(wb_new, wb2) == Failed) 
          fail;
      wb_new->context->refcount++;

      /* bump up refcount to ws */
      ws->refcount++;

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
      int r;
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
      int c, i, width, height, row, p;
      word x, y;
      word nchars;
      unsigned char *s, *t, *z;
      struct palentry *e;
      GetSelfW();

      /*
       * X or y can be defaulted but s is required.
       * Validate x/y first so that the error message makes more sense.
       */
      if (!def:C_integer(x0, -self_w->context->dx, x))
          runerr(101, x0);
      if (!def:C_integer(y0, -self_w->context->dy, y))
          runerr(101, y0);
      if (!cnv:string(d, d))
          runerr(103, d);

      x += self_w->context->dx;
      y += self_w->context->dy;
      /*
       * Extract the Width and skip the following comma.
       */
      s = (unsigned char *)StrLoc(d);
      z = s + StrLen(d);		/* end+1 of string */
      width = 0;
      while (s < z && *s == ' ')	/* skip blanks */
          s++;
      while (s < z && isdigit((unsigned char)*s))	/* scan number */
          width = 10 * width + *s++ - '0';
      while (s < z && *s == ' ')	/* skip blanks */
          s++;
      if (width == 0 || *s++ != ',')	/* skip comma */
          fail;
      while (s < z && *s == ' ')	/* skip blanks */
          s++;
      if (s >= z)			/* if end of string */
          fail;

      /*
       * Check for a bilevel format.
       */
      if ((c = *s) == '#' || c == '~') {
          s++;
          nchars = 0;
          for (t = s; t < z; t++)
              if (isxdigit((unsigned char)*t))
                  nchars++;			/* count hex digits */
              else if (*t != PCH1 && *t != PCH2)
                  fail;				/* illegal punctuation */
          if (nchars == 0)
              fail;
          row = (width + 3) / 4;			/* digits per row */
          if (nchars % row != 0)
              fail;
          height = nchars / row;
          drawblimage(self_w, x, y, width, height, c, s, z - s);
          return nulldesc;
      }

      /*
       * Extract the palette name and skip its comma.
       */
      c = *s++;					/* save initial character */
      p = 0;
      while (s < z && isdigit((unsigned char)*s))		/* scan digits */
          p = 10 * p + *s++ - '0';
      while (s < z && *s == ' ')		/* skip blanks */
          s++;
      if (s >= z || p == 0 || *s++ != ',')	/* skip comma */
          fail;
      if (c == 'g' && p >= 2 && p <= 256)	/* validate grayscale number */
          p = -p;
      else if (c != 'c' || p < 1 || p > 6)	/* validate color number */
          fail;

      /*
       * Scan the image to see which colors are needed.
       */
      e = palsetup(p); 
      if (e == NULL)
          runerr(305);
      for (i = 0; i < 256; i++)
          e[i].used = 0;
      nchars = 0;
      for (t = s; t < z; t++) {
          c = *t; 
          e[c].used = 1;
          if (e[c].valid || e[c].transpt)
              nchars++;			/* valid color, or transparent */
          else if (c != PCH1 && c != PCH2)
              fail;
      }
      if (nchars == 0)
          fail;					/* empty image */
      if (nchars % width != 0)
          fail;					/* not rectangular */

      /*
       * Call platform-dependent code to draw the image.
       */
      height = nchars / width;
      drawstrimage(self_w, x, y, width, height, e, s, z - s);
      return nulldesc;
   }
end

function graphics_Window_draw_line(self, argv[argc])
   body {
      int i, j, n;
      XPoint points[MAXXOBJS];
      int dx, dy;

      GetSelfW();

      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i = 0, j = 0; i < n; i++, j++) {
          int base = i * 2;
          if (j == MAXXOBJS) {
              drawlines(self_w, points, MAXXOBJS);
              points[0] = points[MAXXOBJS-1];
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
      XPoint points[MAXXOBJS];

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
          if (j == MAXXOBJS) {
              drawlines(self_w, points, MAXXOBJS);
              points[0] = points[MAXXOBJS-1];
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

function graphics_Window_draw_string(self, x, y, str)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:string_or_ucs(str) then
      runerr(129, str)
   body {
      int len;
      char *s;
      GetSelfW();
      x += self_w->context->dx;
      y += self_w->context->dy;
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

function graphics_Window_free_color(self, argv[argc])
   body {
      int i;
      word n;
      tended char *s;
      GetSelfW();

      if (argc == 0)
          runerr(103);

      for (i = 0; i < argc; i++) {
          if (!cnv:string(argv[i],argv[i]))
              runerr(103,argv[i]);
          freecolor(self_w, buffstr(&argv[i]));
      }

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

function graphics_Window_palette_chars(p)
   body {
      int n;
      extern char c1list[], c2list[], c3list[], c4list[];

      if (is:null(p))
          n = 1;
      else
          n = palnum(&p);
      switch (n) {
          case -1:  runerr(103, p);		/* not a string */
          case  0:  fail;				/* unrecognized */
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
   body {
      int p;
      char tmp[32];
      struct palentry *e;
      tended struct descrip d, result;

      p = palnum(&s1);
      if (p == -1)
          runerr(103, s1);
      if (p == 0)
          fail;

      if (!cnv:tmp_string(s2, d))
          runerr(103, s2);
      if (StrLen(d) != 1)
          runerr(205, d);
      e = palsetup(p); 
      if (e == NULL)
          runerr(305);
      e += *StrLoc(d) & 0xFF;
      if (!e->valid)
          fail;
      sprintf(tmp, "%d,%d,%d", e->clr.red, e->clr.green, e->clr.blue);
      cstr2string(tmp, &result);
      return result;
   }
end

function graphics_Window_palette_key(s1, s2)
   body {
      int p;
      word n;
      tended char *s;
      int r, g, b, a;

      p = palnum(&s1);
      if (p == -1)
          runerr(103, s1);
      if (p == 0)
          fail;

      if (!cnv:C_string(s2, s))
          runerr(103, s2);

      if (parsecolor(s, &r, &g, &b, &a) == Succeeded)
          return string(1, rgbkey(p, r / 65535.0, g / 65535.0, b / 65535.0));
      else
          fail;
   }
end

function graphics_Window_pixel(self, x0, y0, w0, h0)
   body {
      struct imgmem imem;
      word x, y, width, height;
      int slen;
      tended struct descrip lastval, result, bg;
      int i, j;
      word rv;
      wsp ws;
      GetSelfW();

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      ws = self_w->window;

      imem.x = Max(x,0);
      imem.y = Max(y,0);
      imem.width = Min(width, ws->width - imem.x);
      imem.height = Min(height, ws->height - imem.y);

      if (getpixelinit(self_w, &imem) == Failed) fail;
      getbg(self_w, attr_buff);
      cstr2string(attr_buff, &bg);
      lastval = emptystr;

      create_list(width * height, &result);

      for (j=y; j < y + height; j++) {
          for (i=x; i < x + width; i++) {
              if (i < imem.x || i >= imem.x + imem.width ||
                  j < imem.y || j >= imem.y + imem.height)
                  list_put(&result, &bg);
              else  {
                  getpixel(self_w, i, j, &rv, attr_buff, &imem);
                  if (rv >= 0) {
                      slen = strlen(attr_buff);
                      if (slen != StrLen(lastval) ||
                          strncmp(attr_buff, StrLoc(lastval), slen)) {
                          bytes2string(attr_buff, slen, &lastval);
                      }
                      list_put(&result, &lastval);
                  }
                  else {
                      struct descrip tmp;
                      MakeInt(rv, &tmp);
                      list_put(&result, &tmp);
                  }
              }
          }
      }

      getpixelterm(self_w, &imem);
      return result;
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

function graphics_Window_read_image(self, x, y, file, pal)
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   if !cnv:string(file) then
      runerr(103, file)
   body {
      char *filename;
      int p, r;
      struct imgdata imd;
      GetSelfW();

      /*
       * p is an optional palette name.
       */
      if (is:null(pal)) 
          p = 0;
      else {
          p = palnum(&pal);
          if (p == -1)
              runerr(103, pal);
          if (p == 0)
              fail;
      }

      x += self_w->context->dx;
      y += self_w->context->dy;

      filename = buffstr(&file);

      /*
       * First try to read as a standard file.
       * If that doesn't work, try platform-dependent image reading code.
       */
      r = readimagefile(filename, p, &imd);
      if (r == Succeeded) {
          drawstrimage(self_w, x, y, imd.width, imd.height, imd.paltbl,
                            imd.data, imd.width * imd.height);
          free(imd.paltbl);
          free(imd.data);
      }
      else {
          r = readimage(self_w, x, y, filename);
          if (r != Succeeded) 
              fail;
      }
      return nulldesc;
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
      int r;
      word x, y, width, height;
      char *s;
      GetSelfW();

      s = buffstr(&fname);

      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);

      /*
       * clip image to window, and fail if zero-sized.
       * (the casts to long are necessary to avoid unsigned comparison.)
       */
      if (x < 0) {
          width += x;
          x = 0;
      }
      if (y < 0) {
          height += y;
          y = 0;
      }
      if (x + width > (long) self_w->window->width)
          width = self_w->window->width - x;
      if (y + height > (long) self_w->window->height)
          height = self_w->window->height - y;
      if (width <= 0 || height <= 0)
          fail;

      /*
       * try platform-dependent code first; it will reject the call
       * if the file name s does not specify a platform-dependent format.
       */
      r = dumpimage(self_w, s, x, y, width, height);
#ifdef HAVE_LIBJPEG
      if ((r == NoCvt) &&
	  (strcmp(s + strlen(s)-4, ".jpg")==0 ||
           (strcmp(s + strlen(s)-4, ".JPG")==0))) {
          r = writeJPEG(self_w, s, x, y, width, height);
      }
#endif					/* HAVE_LIBJPEG */
      if (r == NoCvt)
          r = writeBMP(self_w, s, x, y, width, height);
      if (r == NoCvt)
          r = writeGIF(self_w, s, x, y, width, height);
      if (r != Succeeded)
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

function graphics_Window_get_ascent(self)
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
       getbg(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_canvas(self)
   body {
       tended struct descrip result;
       GetSelfW();
       getcanvas(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_clip(self)
   body {
       tended struct descrip result;
       struct descrip t;
       GetSelfW();
       if (self_w->context->clipw < 0)
           fail;
       create_list(4, &result);
       MakeInt(self_w->context->clipx - self_w->context->dx, &t);
       list_put(&result, &t);
       MakeInt(self_w->context->clipy - self_w->context->dy, &t);
       list_put(&result, &t);
       MakeInt(self_w->context->clipw, &t);
       list_put(&result, &t);
       MakeInt(self_w->context->cliph, &t);
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

function graphics_Window_get_descent(self)
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
       getdisplay(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_drawop(self)
   body {
       tended struct descrip result;
       GetSelfW();
       getdrawop(self_w, attr_buff);
       cstr2string(attr_buff, &result);
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
       getfg(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_fheight(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(FHEIGHT(self_w), &result);
       return result;
   }
end

function graphics_Window_get_fillstyle(self)
   body {
       tended struct descrip result;
       GetSelfW();
       getfillstyle(self_w, attr_buff);
       cstr2string(attr_buff, &result);
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

function graphics_Window_get_fwidth(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(FWIDTH(self_w), &result);
       return result;
   }
end

function graphics_Window_get_gamma(self)
   body {
       GetSelfW();
       return C_double self_w->context->gamma;
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
       MakeInt(ws->posx, &t);
       list_put(&result, &t);
       MakeInt(ws->posy, &t);
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

function graphics_Window_get_inputmask(self)
   body {
       tended struct descrip result;
       char *s;
       int mask;
       GetSelfW();
       s = attr_buff;  
       mask = self_w->window->inputmask;
       if (mask & PointerMotionMask)
           *s++ = 'm';
       if (mask & KeyReleaseMask)
           *s++ = 'k';
       *s = 0;
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_label(self)
   body {
       tended struct descrip result;
       GetSelfW();
       if (getwindowlabel(self_w, attr_buff) != Succeeded)
           fail;
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_linestyle(self)
   body {
       tended struct descrip result;
       GetSelfW();
       getlinestyle(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_linewidth(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(getlinewidth(self_w), &result);
       return result;
   }
end

function graphics_Window_get_maxheight(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->maxheight, &result);
       return result;
   }
end

function graphics_Window_get_maxsize(self)
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

function graphics_Window_get_maxwidth(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->maxwidth, &result);
       return result;
   }
end

function graphics_Window_get_minheight(self)
   body {
       struct descrip result;
       GetSelfW();
       MakeInt(self_w->window->minheight, &result);
       return result;
   }
end

function graphics_Window_get_minsize(self)
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

function graphics_Window_get_minwidth(self)
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
       char *s;
       GetSelfW();
       getpattern(self_w, attr_buff);
       cstr2string(attr_buff, &result);
       return result;
   }
end

function graphics_Window_get_pointer(self)
   body {
       tended struct descrip result;
       GetSelfW();
       getpointer(self_w, attr_buff);
       cstr2string(attr_buff, &result);
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
       MakeInt(self_w->window->posx, &t);
       list_put(&result, &t);
       MakeInt(self_w->window->posy, &t);
       list_put(&result, &t);
       return result;
   }
end

function graphics_Window_get_posx(self)
   body {
       struct descrip result;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       MakeInt(self_w->window->posx, &result);
       return result;
   }
end

function graphics_Window_get_posy(self)
   body {
       struct descrip result;
       GetSelfW();
       if (getpos(self_w) != Succeeded)
           fail;
       MakeInt(self_w->window->posy, &result);
       return result;
   }
end

function graphics_Window_can_resize(self)
   body {
       GetSelfW();
       if (ISRESIZABLE(self_w))
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

function graphics_Window_get_visual(self)
   body {
       tended struct descrip result;
       GetSelfW();
       if (getvisual(self_w, attr_buff) != Succeeded)
           fail;
       cstr2string(attr_buff, &result);
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

  
function graphics_Window_set_bg(self, val)
   body {
       word i;
       GetSelfW();
       if (!cnv:string(val, val))
           runerr(103, val);
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
      word x, y, width, height;
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

function graphics_Window_set_drawop(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setdrawop(self_w, buffstr(&val)), "Invalid drawop");
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
   body {
       word i;
       GetSelfW();
       if (!cnv:string(val, val))
           runerr(103, val);
       AttemptAttr(setfg(self_w, buffstr(&val)), "Invalid color");
       return self;
   }
end

function graphics_Window_set_fillstyle(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfillstyle(self_w, buffstr(&val)), "Invalid fillstyle");
       return self;
   }
end

function graphics_Window_set_font(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setfont(self_w, buffstr(&val)), "Invalid font");
       return self;
   }
end

function graphics_Window_set_gamma(self, val)
   body {
       double d;
       GetSelfW();
       if (!cnv:C_double(val, d)) 
           runerr(102, val);
       AttemptAttr(setgamma(self_w, d), "Invalid gamma value");
       return self;
   }
end

function graphics_Window_set_geometry(self, x0, y0, w0, h0)
   body {
       word x, y, width, height;
       GetSelfW();
      if (rectargs(self_w, &x0, &x, &y, &width, &height) == Error)
          runerr(0);
       self_w->window->posx = x;
       self_w->window->posy = y;
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

function graphics_Window_set_image(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       wsp ws;
       char *s;
       int r;
       GetSelfW();
       ws = self_w->window;
       s = buffstr(&val);
       r = readimagefile(s, 0, &ws->initimage);
       if (r == Succeeded) {
           self_w->window->width = ws->initimage.width;
           self_w->window->height = ws->initimage.height;
           wconfig |= C_SIZE | C_IMAGE;
       }
       else
           r = setimage(self_w, s);
       AttemptAttr(r, "Unable to draw image");
       return self;
   }
end

function graphics_Window_set_inputmask(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setinputmask(self_w, buffstr(&val)), "Invalid input mask");
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

function graphics_Window_set_linestyle(self, val)
   if !cnv:string(val) then
      runerr(103, val)
   body {
       GetSelfW();
       AttemptAttr(setlinestyle(self_w, buffstr(&val)), "Invalid linestyle");
       return self;
   }
end

function graphics_Window_set_linewidth(self, val)
   body {
       word i;
       GetSelfW();
       if (!cnv:C_integer(val, i))
           runerr(101, val);
       AttemptAttr(setlinewidth(self_w, i), "Invalid linewidth");
       return self;
   }
end

function graphics_Window_set_maxheight(self, height)
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

function graphics_Window_set_maxsize(self, width, height)
   body {
       tended char *s;
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

function graphics_Window_set_maxwidth(self, width)
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

function graphics_Window_set_minheight(self, height)
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

function graphics_Window_set_minsize(self, width, height)
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

function graphics_Window_set_minwidth(self, width)
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
   if !cnv:C_integer(x) then
      runerr(101, x)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
       GetSelfW();
       self_w->window->posx = x;
       self_w->window->posy = y;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_posx(self, x)
   if !cnv:C_integer(x) then
      runerr(101, x)
   body {
       GetSelfW();
       self_w->window->posx = x;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_posy(self, y)
   if !cnv:C_integer(y) then
      runerr(101, y)
   body {
       GetSelfW();
       self_w->window->posy = y;
       wconfig |= C_POS;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_set_resize(self, val)
   body {
       GetSelfW();
       if (is:null(val))
           CLRRESIZABLE(self_w);
       else
           SETRESIZABLE(self_w);
       wconfig |= C_RESIZE;
       SimpleAttr();
       return self;
   }
end

function graphics_Window_toggle_fgbg(self)
   body {
       GetSelfW();
       togglefgbg(self_w);
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

function graphics_Window_set_titlebar(self, val)
   body {
       GetSelfW();
       if (is:null(val))
           CLRTITLEBAR(self_w->window);
       else
           SETTITLEBAR(self_w->window);
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

function graphics_Window_post_set(self)
   body {
       return self;
   }
end

#endif   /* Graphics */
