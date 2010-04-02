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
if (!(w) || ISCLOSED(w))
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
if (!self_w || ISCLOSED(self_w))
    runerr(142, self);
#enddef

function graphics_Window_open_impl(attr[n])
   body {
      int j, err_index;
      tended struct b_list *hp;
      wbp f;

      /*
       * allocate an empty event queue for the window
       */
      MemProtect(hp = alclist(0, MinListSlots));

      /*
       * loop through attributes, checking validity
       */
      for (j = 0; j < n; j++) {
          if (is:null(attr[j]))
              attr[j] = emptystr;
          if (!is:string(attr[j]))
              runerr(109, attr[j]);
      }

      err_index = -1;
      f = wopen(0, "Object Icon", hp, attr, n, &err_index);

      if (f == NULL) {
          if (err_index >= 0) runerr(145, attr[err_index]);
          else if (err_index == -1) fail;
          else runerr(305);
      }

      return C_integer((word)f);
   }
end

function graphics_Window_open_child_impl(self, attr[n])
   body {
      int j, err_index;
      tended struct b_list *hp;
      wbp f;
      GetSelfW();

      /*
       * allocate an empty event queue for the window
       */
      MemProtect(hp = alclist(0, MinListSlots));

      /*
       * loop through attributes, checking validity
       */
      for (j = 0; j < n; j++) {
          if (is:null(attr[j]))
              attr[j] = emptystr;
          if (!is:string(attr[j]))
              runerr(109, attr[j]);
      }

      err_index = -1;
      f = wopen(self_w, "Object Icon", hp, attr, n, &err_index);

      if (f == NULL) {
          if (err_index >= 0) runerr(145, attr[err_index]);
          else if (err_index == -1) fail;
          else runerr(305);
      }

      return C_integer((word)f);
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

function graphics_Window_bg(self, colr)
   body {
      tended struct descrip result;
      tended char *tmp;
      GetSelfW();

      /*
       * If there is an argument we are setting by either a mutable
       * color (negative int) or a string name.
       */
      if (!is:null(colr)) {
          if (is:integer(colr)) {    /* mutable color or packed RGB */
              if (isetbg(self_w, IntVal(colr)) == Failed) 
                  fail;
          }
          else {
              if (!cnv:C_string(colr, tmp))
                  runerr(103, colr);
              if(setbg(self_w, tmp) == Failed)
                  fail;
          }
      }

      /*
       * In any event, this function returns the current background color.
       */
      getbg(self_w, attr_buff);
      cstr2string(attr_buff, &result);
      return result;
   }
end

function graphics_Window_clip(self, argv[argc])
   body {
      int r;
      word x, y, width, height;
      wcp wc;
      GetSelfW();

      wc = self_w->context;

      if (argc == 0) {
          wc->clipx = wc->clipy = 0;
          wc->clipw = wc->cliph = -1;
          unsetclip(self_w);
      }
      else {
          r = rectargs(self_w, argc, argv, 0, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          wc->clipx = x;
          wc->clipy = y;
          wc->clipw = width;
          wc->cliph = height;
          setclip(self_w);
      }

      return self;
   }
end

function graphics_Window_clone_impl(self, argv[argc])
   body {
       wbp w2;
       int n;
       tended struct descrip sbuf, sbuf2;
       GetSelfW();

       w2 = alc_wbinding();
       w2->window = self_w->window;
       w2->window->refcount++;
       MemProtect(w2->context = clone_context(self_w));

       for (n = 0; n < argc; n++) {
           if (!is:null(argv[n])) {
               if (!cnv:tmp_string(argv[n], sbuf))
                   runerr(109, argv[n]);
               switch (wattrib(w2, StrLoc(argv[n]), StrLen(argv[n]), &sbuf2, attr_buff)) {
                   case Failed: fail;
                   case Error: runerr(0, argv[n]);
	       }
           }
       }

       return C_integer((word)w2);
   }
end

function graphics_Window_color(self, argv[argc])
   body {
      int i;
      word n;
      char *colorname, *srcname;
      tended char *tmp;
      GetSelfW();

      if (argc == 0) runerr(101);

      if (argc == 1) {			/* if this is a query */
          tended struct descrip result;
          CnvCInteger(argv[0], n)
          if ((colorname = get_mutable_name(self_w, n)) == NULL)
              fail;
          cstr2string(colorname, &result);
          return result;
      }

      CheckArgMultipleOf(2);

      for (i = 0; i < argc; i += 2) {
          CnvCInteger(argv[i], n)
              if ((colorname = get_mutable_name(self_w, n)) == NULL)
                  fail;

          if (is:integer(argv[i+1])) {		/* copy another mutable  */
              if (IntVal(argv[i+1]) >= 0)
                  runerr(205, argv[i+1]);		/* must be negative */
              if ((srcname = get_mutable_name(self_w, IntVal(argv[i+1]))) == NULL)
                  fail;
              if (set_mutable(self_w, n, srcname) == Failed) fail;
              strcpy(colorname, srcname);
          }
   
          else {					/* specified by name */
              tended char *tmp;
              if (!cnv:C_string(argv[i+1],tmp))
                  runerr(103,argv[i+1]);
   
              if (set_mutable(self_w, n, tmp) == Failed) fail;
              strcpy(colorname, tmp);
          }
      }

      return self;
   }
end

function graphics_Window_color_value(self, k)
   body {
      word n;
      long r, g, b, a;
      tended char *s;
      char tmp[32], *t;
      GetSelfW();

      a = 65535;
      if (is:null(k))
          runerr(103);

      if (cnv:C_integer(k, n)) {
          if ((t = get_mutable_name(self_w, n)))
              MemProtect(s = alcstr(t, (word)strlen(t)+1));
          else
              fail;
      }
      else if (!cnv:C_string(k, s))
          runerr(103, k);

      if (parsecolor(self_w, s, &r, &g, &b, &a) == Succeeded) {
          tended struct descrip result;
          if (a < 65535)
              sprintf(tmp,"%ld,%ld,%ld,%ld", r, g, b, a);
          else
              sprintf(tmp,"%ld,%ld,%ld", r, g, b);
          cstr2string(tmp, &result);
          return result;
      }
      fail;
   }
end

function graphics_Window_copy_to(self, dest, argv[argc])
   body {
      int n, r;
      word x, y, width, height, x2, y2, width2, height2;
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
      r = rectargs(self_w, argc, argv, 0, &x, &y, &width, &height);
      if (r >= 0)
          runerr(101, argv[r]);

      /*
       * get x2 and y2, ignoring width and height.
       */
      n = argc;
      if (n > 6)
          n = 6;
      r = rectargs(w2, n, argv, 4, &x2, &y2, &width2, &height2);
      if (r >= 0)
          runerr(101, argv[r]);

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
      wb_new = alc_wbinding();

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


function graphics_Window_draw_arc(self, argv[argc])
   body {
      int i, j, r;
      XArc arcs[MAXXOBJS];
      word x, y, width, height;
      double a1, a2;

      GetSelfW();

      j = 0;
      for (i = 0; i < argc || i == 0; i += 6) {
          if (j == MAXXOBJS) {
              drawarcs(self_w, arcs, MAXXOBJS);
              j = 0;
          }
          r = rectargs(self_w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);

          arcs[j].x = x;
          arcs[j].y = y;
          ARCWIDTH(arcs[j]) = width;
          ARCHEIGHT(arcs[j]) = height;

          /*
           * Angle 1 processing.  Computes in radians and 64'ths of a degree,
           *  bounds checks, and handles wraparound.
           */
          if (i + 4 >= argc || is:null(argv[i + 4]))
              a1 = 0.0;
          else {
              if (!cnv:C_double(argv[i + 4], a1))
                  runerr(102, argv[i + 4]);
              if (a1 >= 0.0)
                  a1 = fmod(a1, 2 * Pi);
              else
                  a1 = -fmod(-a1, 2 * Pi);
          }
          /*
           * Angle 2 processing
           */
          if (i + 5 >= argc || is:null(argv[i + 5]))
              a2 = 2 * Pi;
          else {
              if (!cnv:C_double(argv[i + 5], a2))
                  runerr(102, argv[i + 5]);
              if (fabs(a2) > 3 * Pi)
                  runerr(101, argv[i + 5]);
          }
          if (fabs(a2) >= 2 * Pi) {
              a2 = 2 * Pi;
          }
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
          arcs[j].angle1 = ANGLE(a1);
          arcs[j].angle2 = EXTENT(a2);

          j++;
      }

      drawarcs(self_w, arcs, j);

      return self;
   }
end

function graphics_Window_draw_circle(self, argv[argc])
   body {
      int r;
      GetSelfW();

      r = docircles(self_w, argc, argv, 0);
      if (r < 0)
         return self;
      else if (r >= argc)
         runerr(146);
      else 
         runerr(102, argv[r]);
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


function graphics_Window_draw_image(self, argv[argc])
   body {
      int c, i, width, height, row, p;
      word x, y;
      word nchars;
      unsigned char *s, *t, *z;
      struct descrip d;
      struct palentry *e;
      GetSelfW();

      /*
       * X or y can be defaulted but s is required.
       * Validate x/y first so that the error message makes more sense.
       */
      if (argc >= 1 && !def:C_integer(argv[0], -self_w->context->dx, x))
          runerr(101, argv[0]);
      if (argc >= 2 && !def:C_integer(argv[1], -self_w->context->dy, y))
          runerr(101, argv[1]);
      if (argc < 3)
          runerr(103);			/* missing s */
      if (!cnv:tmp_string(argv[2], d))
          runerr(103, argv[2]);

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
          if (drawblimage(self_w, x, y, width, height, c, s, (word)(z - s)) == Error)
              runerr(305);
          else
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
      i = strimage(self_w, x, y, width, height, e, s, (word)(z - s), 0);
      if (i == 0)
          return nulldesc;
      else if (i < 0)
          runerr(305);
      else
          return C_integer i;
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

function graphics_Window_draw_point(self, argv[argc])
   body {
      int i, j, n;
      XPoint points[MAXXOBJS];
      int dx, dy;

      GetSelfW();
      CheckArgMultipleOf(2);

      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i=0, j=0; i < n; i++, j++) {
          int base = i * 2;
          if (j == MAXXOBJS) {
              drawpoints(self_w, points, MAXXOBJS);
              j = 0;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawpoints(self_w, points, j);
      
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

function graphics_Window_draw_rectangle(self, argv[argc])
   body {
      int i, j, r;
      XRectangle recs[MAXXOBJS];
      word x, y, width, height;

      GetSelfW();

      j = 0;

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(self_w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          if (j == MAXXOBJS) {
              drawrectangles(self_w,recs,MAXXOBJS);
              j = 0;
          }
          RECX(recs[j]) = x;
          RECY(recs[j]) = y;
          RECWIDTH(recs[j]) = width;
          RECHEIGHT(recs[j]) = height;
          j++;
      }

      drawrectangles(self_w, recs, j);

      return self;
   }
end

function graphics_Window_draw_segment(self, argv[argc])
   body {
      int i, j, n, dx, dy;
      XSegment segs[MAXXOBJS];

      GetSelfW();
      CheckArgMultipleOf(4);

      dx = self_w->context->dx;
      dy = self_w->context->dy;
      for(i=0, j=0; i < n; i++, j++) {
          int base = i * 4;
          if (j == MAXXOBJS) {
              drawsegments(self_w, segs, MAXXOBJS);
              j = 0;
          }
          CnvCShort(argv[base], segs[j].x1);
          CnvCShort(argv[base + 1], segs[j].y1);
          CnvCShort(argv[base + 2], segs[j].x2);
          CnvCShort(argv[base + 3], segs[j].y2);
          segs[j].x1 += dx;
          segs[j].x2 += dx;
          segs[j].y1 += dy;
          segs[j].y2 += dy;
      }
      drawsegments(self_w, segs, j);

      return self;
    }
end

function graphics_Window_draw_string(self, argv[argc])
   body {
      int i, n, len;
      char *s;

      GetSelfW();
      CheckArgMultipleOf(3);

      for(i=0; i < n; i++) {
          word x, y;
          int base = i * 3;
          CnvCInteger(argv[base], x);
          CnvCInteger(argv[base + 1], y);
          x += self_w->context->dx;
          y += self_w->context->dy;
          if (!cnv:string_or_ucs(argv[base + 2],argv[base + 2]))
              runerr(129, argv[base + 2]);
          if (is:ucs(argv[base + 2])) {
              s = StrLoc(UcsBlk(argv[base + 2]).utf8);
              len = StrLen(UcsBlk(argv[base + 2]).utf8);
              drawutf8(self_w, x, y, s, len);
          } else {
              s = StrLoc(argv[base + 2]);
              len = StrLen(argv[base + 2]);
              drawstrng(self_w, x, y, s, len);
          }
      }
      return self;
   }
end


function graphics_Window_erase_area(self, argv[argc])
   body {
      int i, r;
      word x, y, width, height;
      GetSelfW();

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(self_w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          erasearea(self_w, x, y, width, height);
      }
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


function graphics_Window_fg(self, colr)
   body {
      tended struct descrip result;
      tended char *tmp;
      GetSelfW();

      /*
       * If there is a (non-window) argument we are setting by
       *  either a mutable color (negative int) or a string name.
       */
      if (!is:null(colr)) {
	  if (is:integer(colr)) {	/* mutable color or packed RGB */
              if (isetfg(self_w, IntVal(colr)) == Failed) 
                  fail;
          }
	  else {
              if (!cnv:C_string(colr, tmp))
                  runerr(103, colr);
              if(setfg(self_w, tmp) == Failed)
                  fail;
          }

      }

      /*
       * In any case, this function returns the current foreground color.
       */

      getfg(self_w, attr_buff);
      cstr2string(attr_buff, &result);
      return result;
   }
end

function graphics_Window_fill_arc(self, argv[argc])
   body {
      int i, j, r;
      XArc arcs[MAXXOBJS];
      word x, y, width, height;
      double a1, a2;

      GetSelfW();

      j = 0;
      for (i = 0; i < argc || i == 0; i += 6) {
          if (j == MAXXOBJS) {
              fillarcs(self_w, arcs, MAXXOBJS);
              j = 0;
          }
          r = rectargs(self_w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);

          arcs[j].x = x;
          arcs[j].y = y;
          ARCWIDTH(arcs[j]) = width;
          ARCHEIGHT(arcs[j]) = height;

          if (i + 4 >= argc || is:null(argv[i + 4])) {
              a1 = 0.0;
          }
          else {
              if (!cnv:C_double(argv[i + 4], a1))
                  runerr(102, argv[i + 4]);
              if (a1 >= 0.0)
                  a1 = fmod(a1, 2 * Pi);
              else
                  a1 = -fmod(-a1, 2 * Pi);
          }
          if (i + 5 >= argc || is:null(argv[i + 5]))
              a2 = 2 * Pi;
          else {
              if (!cnv:C_double(argv[i + 5], a2))
                  runerr(102, argv[i + 5]);
              if (fabs(a2) > 3 * Pi)
                  runerr(101, argv[i + 5]);
          }
          if (fabs(a2) >= 2 * Pi) {
              a2 = 2 * Pi;
          }
          else {
              if (a2 < 0.0) {
                  a1 += a2;
                  a2 = fabs(a2);
              }
          }
          arcs[j].angle2 = EXTENT(a2);
          if (a1 < 0.0)
              a1 = 2 * Pi - fmod(fabs(a1), 2 * Pi);
          else
              a1 = fmod(a1, 2 * Pi);
          arcs[j].angle1 = ANGLE(a1);

          j++;
      }

      fillarcs(self_w, arcs, j);

      return self;
   }
end

function graphics_Window_fill_circle(self, argv[argc])
   body {
      int r;
      GetSelfW();

      r = docircles(self_w, argc, argv, 1);
      if (r < 0)
          return self;
      else if (r >= argc)
         runerr(146);
      else 
         runerr(102, argv[r]);
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

function graphics_Window_fill_rectangle(self, argv[argc])
   body {
      int i, j, r;
      XRectangle recs[MAXXOBJS];
      word x, y, width, height;

      GetSelfW();

      j = 0;

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(self_w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          if (j == MAXXOBJS) {
              fillrectangles(self_w,recs,MAXXOBJS);
              j = 0;
          }
          RECX(recs[j]) = x;
          RECY(recs[j]) = y;
          RECWIDTH(recs[j]) = width;
          RECHEIGHT(recs[j]) = height;
          j++;
      }

      fillrectangles(self_w, recs, j);

      return self;
   }
end

function graphics_Window_font(self, f)
   body {
      tended struct descrip result;
      tended char *tmp;
      GetSelfW();

      if (!is:null(f)) {
          if (!cnv:C_string(f, tmp))
              runerr(103, f);
          if (setfont(self_w,&tmp) == Failed) 
              fail;
      }
      getfontname(self_w, attr_buff);
      cstr2string(attr_buff, &result);
      return result;
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
          if (is:integer(argv[i])) {
              CnvCInteger(argv[i], n)
              if (n < 0)
                  free_mutable(self_w, n);
          }
          else {
              if (!cnv:C_string(argv[i], s))
                  runerr(103,argv[i]);
              free_color(self_w, s);
          }
      }

      return self;
   }
end

function graphics_Window_lower(self)
   body {
      GetSelfW();
      lowerWindow(self_w);
      return self;
   }
end


function graphics_Window_new_color(self, argv[argc])
   body {
      int rv;
      GetSelfW();

      if (mutable_color(self_w, argv, argc, &rv) == Failed) 
          fail;
      return C_integer rv;
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
      sprintf(tmp, "%ld,%ld,%ld", e->clr.red, e->clr.green, e->clr.blue);
      cstr2string(tmp, &result);
      return result;
   }
end

function graphics_Window_palette_key(self, s1, s2)
   body {
      int p;
      word n;
      tended char *s;
      long r, g, b, a;

      GetSelfW();

      p = palnum(&s1);
      if (p == -1)
          runerr(103, s1);
      if (p == 0)
          fail;

      if (cnv:C_integer(s2, n)) {
          if ((s = get_mutable_name(self_w, n)) == NULL)
              fail;
      }
      else if (!cnv:C_string(s2, s))
          runerr(103, s2);

      if (parsecolor(self_w, s, &r, &g, &b, &a) == Succeeded)
          return string(1, rgbkey(p, r / 65535.0, g / 65535.0, b / 65535.0));
      else
          fail;
   }
end

function graphics_Window_pattern(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      GetSelfW();

      switch (setpattern(self_w, StrLoc(s), StrLen(s))) {
          case Error:
              runerr(0, s);
          case Failed:
              fail;
      }

      return self;
   }
end

function graphics_Window_pixel(self, argv[argc])
   body {
      struct imgmem imem;
      word x, y, width, height;
      int slen, r;
      tended struct descrip lastval, result;
      char strout[50];
      int i, j;
      word rv;
      wsp ws;
      GetSelfW();

      r = rectargs(self_w, argc, argv, 0, &x, &y, &width, &height);
      if (r >= 0)
          runerr(101, argv[r]);

      ws = self_w->window;

      imem.x = Max(x,0);
      imem.y = Max(y,0);
      imem.width = Min(width, (int)ws->width - imem.x);
      imem.height = Min(height, (int)ws->height - imem.y);

      if (getpixel_init(self_w, &imem) == Failed) fail;

      lastval = emptystr;

      create_list(width * height, &result);

      for (j=y; j < y + height; j++) {
          for (i=x; i < x + width; i++) {
              getpixel(self_w, i, j, &rv, strout, &imem);
              slen = strlen(strout);
              if (rv >= 0) {
                  if (slen != StrLen(lastval) ||
                      strncmp(strout, StrLoc(lastval), slen)) {
                      MemProtect((StrLoc(lastval) = alcstr(strout, slen)));
                      StrLen(lastval) = slen;
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

      getpixel_term(self_w, &imem);
      return result;
   }
end

function graphics_Window_query_root_pointer()
   body {
      XPoint xp;
      tended struct descrip result;
      struct descrip t;
      pollevent();
      query_rootpointer(&xp);
      create_list(2, &result);
      MakeInt(xp.x, &t);
      list_put(&result, &t);
      MakeInt(xp.y, &t);
      list_put(&result, &t);
      return result;
   }
end

function graphics_Window_raise(self)
   body {
      GetSelfW();
      if (raisewindow(self_w) == Failed)
          fail;
      return self;
   }
end

function graphics_Window_read_image(self, argv[argc])
   body {
      char filename[MaxPath + 1];
      tended char *tmp;
      int status;
      word x, y;
      int p, r;
      struct imgdata imd;
      GetSelfW();

      if (argc == 0)
          runerr(103,nulldesc);
      if (!cnv:C_string(argv[0], tmp))
          runerr(103,argv[0]);

      /*
       * x and y must be integers; they default to the upper left pixel.
       */
      if (argc < 2) 
          x = -self_w->context->dx;
      else if (!def:C_integer(argv[1], -self_w->context->dx, x))
          runerr(101, argv[1]);
      if (argc < 3)
          y = -self_w->context->dy;
      else if (!def:C_integer(argv[2], -self_w->context->dy, y))
          runerr(101, argv[2]);

      /*
       * p is an optional palette name.
       */
      if (argc < 4 || is:null(argv[3])) 
          p = 0;
      else {
          p = palnum(&argv[3]);
          if (p == -1)
              runerr(103, argv[3]);
          if (p == 0)
              fail;
      }

      x += self_w->context->dx;
      y += self_w->context->dy;
      strncpy(filename, tmp, MaxPath);   /* copy to loc that won't move*/
      filename[MaxPath] = '\0';

      /*
       * First try to read as a GIF file.
       * If that doesn't work, try platform-dependent image reading code.
       */
      r = readGIF(filename, p, &imd);
      if (r != Succeeded) r = readBMP(filename, p, &imd);
      if (r == Succeeded) {
          status = strimage(self_w, x, y, imd.width, imd.height, imd.paltbl,
                            imd.data, (word)imd.width * (word)imd.height, 0);
          if (status < 0)
              r = Error;
          free(imd.paltbl);
          free(imd.data);
      }
      else if (r == Failed)
          r = readimage(self_w, filename, x, y, &status);
      if (r == Error)
          runerr(305);
      if (r == Failed)
          fail;
      if (status == 0)
          return nulldesc;
      else
          return C_integer (word)status;
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
          i = utf8width(self_w, StrLoc(UcsBlk(s).utf8), StrLen(UcsBlk(s).utf8));
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
      free_binding(self_w);
      return self;
   }
end

function graphics_Window_attrib(self, argv[argc])
   body {
      wbp wsave;
      word n;
      tended struct descrip sbuf, sbuf2;
      int pass, config;
      GetSelfW();

      config = 0;
      sbuf2 = nulldesc;

      wsave = self_w;
      /*
       * Loop through the arguments.
       */

      for (pass = 1; pass <= 2; pass++) {
          self_w = wsave;
          if (config && pass == 2) {
              if (do_config(self_w, config) == Failed) fail;
          }
          for (n = 0; n < argc; n++) {
              /*
               * In pass 1, a null argument is an error; failed attribute
               *  assignments are turned into null descriptors for pass 2
               *  and are ignored.
               */
              if (is:null(argv[n])) {
                  if (pass == 2)
                      continue;
                  else runerr(109, argv[n]);
              }
              /*
               * If its an integer or real, it can't be a valid attribute.
               */
              if (is:integer(argv[n]) || is:real(argv[n])) {
                  runerr(145, argv[n]);
              }
              /*
               * Convert the argument to a string
               */
              if (!cnv:tmp_string(argv[n], sbuf)) 
                  runerr(109, argv[n]);
              /*
               * Read/write the attribute
               */
              if (pass == 1) {
            
                  char *tmp_s = StrLoc(sbuf);
                  char *tmp_s2 = StrLoc(sbuf) + StrLen(sbuf); 
                  for ( ; tmp_s < tmp_s2; tmp_s++)
                      if (*tmp_s == '=') break;
                  if (tmp_s < tmp_s2) {
                      /*
                       * pass 1: perform attribute assignments
                       */  


                      switch (wattrib(self_w, StrLoc(sbuf), StrLen(sbuf),
                                      &sbuf2, attr_buff)) {
                          case Failed:
                              /*
                               * Mark the attribute so we don't produce a result
                               */
                              argv[n] = nulldesc;
                              continue;
                          case Error: runerr(0, argv[n]);
               

                      }
                      if (StrLen(sbuf) > 4) {
                          if (!strncmp(StrLoc(sbuf), "pos=", 4)) config |= 1;
                          if (StrLen(sbuf) > 5) {
                              if (!strncmp(StrLoc(sbuf), "posx=", 5)) config |= 1;
                              if (!strncmp(StrLoc(sbuf), "posy=", 5)) config |= 1;
                              if (!strncmp(StrLoc(sbuf), "rows=", 5)) config |= 2;
                              if (!strncmp(StrLoc(sbuf), "size=", 5)) config |= 2;
                              if (StrLen(sbuf) > 6) {
                                  if (!strncmp(StrLoc(sbuf), "width=", 6))
                                      config |= 2;
                                  if (!strncmp(StrLoc(sbuf), "lines=", 6))
                                      config |= 2;
                                  if (StrLen(sbuf) > 7) {
                                      if (!strncmp(StrLoc(sbuf), "height=", 7))
                                          config |= 2;
                                      if (!strncmp(StrLoc(sbuf), "resize=", 7))
                                          config |= 2;
                                      if (StrLen(sbuf) > 8) {
                                          if (!strncmp(StrLoc(sbuf), "columns=", 8))
                                              config |= 2;
                                          if (StrLen(sbuf) > 9) {
                                              if (!strncmp(StrLoc(sbuf),
                                                           "geometry=", 9))
                                                  config |= 3;
                                          }
                                      }
                                  }
                              }
                          }
                      }
                  }
              }
              /*
               * pass 2: perform attribute queries, suspend result(s)
               */
              else if (pass==2) {
                  char *stmp, *stmp2;
                  /*
                   * Turn assignments into queries.
                   */
                  for( stmp = StrLoc(sbuf), 
                           stmp2 = stmp + StrLen(sbuf); stmp < stmp2; stmp++)
                      if (*stmp == '=') break;
                  if (stmp < stmp2)
                      StrLen(sbuf) = stmp - StrLoc(sbuf);

                  switch (wattrib(self_w, StrLoc(sbuf), StrLen(sbuf),
                                  &sbuf2, attr_buff)) {
                      case Failed: continue;
                      case Error:  runerr(0, argv[n]);
                  }
                  if (is:string(sbuf2))
                      MemProtect(StrLoc(sbuf2) = alcstr(StrLoc(sbuf2),StrLen(sbuf2)));
                  suspend sbuf2;
              }
          }
      }
      fail;
   }
end

function graphics_Window_wdefault(self, prog, opt)
   if !cnv:C_string(prog) then
       runerr(103, prog)
   if !cnv:C_string(opt) then
       runerr(103, opt)
   body {
      tended struct descrip result; 
      GetSelfW();

      if (getdefault(self_w, prog, opt, attr_buff) == Failed) 
          fail;
      cstr2string(attr_buff, &result);
      return result;
   }
end

function graphics_Window_flush(self)
   body {
      GetSelfW();
      wflush(self_w);
      return self;
   }
end

function graphics_Window_write_image(self, s, argv[argc])
   if !cnv:C_string(s) then
       runerr(103, s)
   body {
      int r;
      word x, y, width, height;
      GetSelfW();

      r = rectargs(self_w, argc, argv, 0, &x, &y, &width, &height);
      if (r >= 0)
          runerr(101, argv[r]);

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
   if !cnv:C_string(selection) then
      runerr(103,selection)
   body {
       GetSelfW();
       if (own_selection(self_w, selection) == Failed)
           fail;
       return self;
   }
end

function graphics_Window_send_selection_response(self, requestor, property, target, selection, time, data)
   if !cnv:C_integer(requestor) then
      runerr(101, requestor)
   if !cnv:C_string(property) then
      runerr(103, property)
   if !cnv:C_string(target) then
      runerr(103, target)
   if !cnv:C_string(selection) then
      runerr(103, selection)
   if !cnv:C_integer(time) then
      runerr(101, time)
   body {
       GetSelfW();
       if (send_selection_response(self_w, requestor, property, target, selection, time, &data) == Failed)
           runerr(0);
       else
           return self;
   }
end

function graphics_Window_request_selection(self, selection, target_type)
   if !cnv:C_string(selection) then
      runerr(103,selection)
   if !def:C_string(target_type, "STRING") then
      runerr(103,target_type)
   body {
       GetSelfW();
       if (request_selection(self_w, selection, target_type) == Failed)
           fail;
       return self;
   }
end

function graphics_Window_close(self)
   body {
     GetSelfW();

     *self_w_dptr = zerodesc;
     SETCLOSED(self_w);
     wclose(self_w);

     return self;
   }
end

function graphics_Window_generic_palette_key(s1, s2)
   body {
      int p;
      word n;
      tended char *s;
      long r, g, b, a;

      p = palnum(&s1);
      if (p == -1)
          runerr(103, s1);
      if (p == 0)
          fail;

      if (cnv:C_integer(s2, n))
              fail;
      if (!cnv:C_string(s2, s))
          runerr(103, s2);

      if (parsecolor(0, s, &r, &g, &b, &a) == Succeeded)
          return string(1, rgbkey(p, r / 65535.0, g / 65535.0, b / 65535.0));
      else
          fail;
   }
end

function graphics_Window_generic_color_value(k)
   body {
      word n;
      long r, g, b, a = 65535;
      tended char *s;
      char tmp[32];

      if (is:null(k))
          runerr(103);

      if (cnv:C_integer(k, n))
          fail;
      if (!cnv:C_string(k, s))
          runerr(103, k);

      if (parsecolor(0, s, &r, &g, &b, &a) == Succeeded) {
          tended struct descrip result;
          if (a < 65535)
              sprintf(tmp,"%ld,%ld,%ld,%ld", r, g, b, a);
          else
              sprintf(tmp,"%ld,%ld,%ld", r, g, b);
          cstr2string(tmp, &result);
          return result;
      }
      fail;
   }
end

#else  /* Graphics */

function graphics_Window_open_impl(attr[n])
   body {
     Unsupported;
   }
end

#endif   /* Graphics */
