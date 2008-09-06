/*
 * File: fwindow.r - Icon graphics interface
 *
 */

#ifdef Graphics

/*
 * Global variables.
 *  A poll counter for use in interp.c,
 *  the binding for the console window - FILE * for simplicity,
 *  &col, &row, &x, &y, &interval, timestamp, and modifier keys.
 */
int pollctr;

function{0,1} graphics_Window_open_impl(attr[n])
   body {
      int j, err_index = -1;
      tended struct b_list *hp;
      wbp f;

      /*
       * allocate an empty event queue for the window
       */
      Protect(hp = alclist(0, MinListSlots), runerr(0));

      /*
       * loop through attributes, checking validity
       */
      for (j = 0; j < n; j++) {
          if (is:null(attr[j]))
              attr[j] = emptystr;
          if (!is:string(attr[j]))
              runerr(109, attr[j]);
      }

      f = wopen("Object Icon", hp, attr, n, &err_index,0);

      if (f == NULL) {
          if (err_index >= 0) runerr(145, attr[err_index]);
          else if (err_index == -1) fail;
          else runerr(305);
      }

      return C_integer((long int)f);
   }
end

static struct sdescrip wbpf = {3, "wbp"};

#begdef WindowParam(p, w)
wbp w;
dptr w##_dptr;
static struct inline_cache w##_ic;
if (!is:object(p))
    runerr(602, p);
w##_dptr = c_get_instance_data(&p, (dptr)&wbpf, &w##_ic);
if (!w##_dptr)
    runerr(207,*(dptr)&wbpf);
(w) = (wbp)IntVal(*w##_dptr);
if (!(w))
    runerr(142, p);
if (ISCLOSED(w))
    runerr(142, p);
#enddef


function{1} graphics_Window_alert(self, volume)
   if !def:C_integer(volume, 0) then
      runerr(101, volume)
   body {
       WindowParam(self, w);
       walert(w, volume);
       return nulldesc;
   }
end

function{0,1} graphics_Window_bg(self, colr)
   body {
      char sbuf1[MaxCvtLen];
      int len;
      tended char *tmp;
      WindowParam(self, w);

      /*
       * If there is an argument we are setting by either a mutable
       * color (negative int) or a string name.
       */
      if (!is:null(colr)) {
          if (is:integer(colr)) {    /* mutable color or packed RGB */
              if (isetbg(w, IntVal(colr)) == Failed) 
                  fail;
          }
          else {
              if (!cnv:C_string(colr, tmp))
                  runerr(103, colr);
              if(setbg(w, tmp) == Failed)
                  fail;
          }
      }

      /*
       * In any event, this function returns the current background color.
       */
      getbg(w, sbuf1);
      len = strlen(sbuf1);
      Protect(tmp = alcstr(sbuf1, len), runerr(0));
      return string(len, tmp);
   }
end

function{1} graphics_Window_clip(self, argv[argc])
   body {
      int r;
      C_integer x, y, width, height;
      wcp wc;
      WindowParam(self, w);

      wc = w->context;

      if (argc == 0) {
          wc->clipx = wc->clipy = 0;
          wc->clipw = wc->cliph = -1;
          unsetclip(w);
      }
      else {
          r = rectargs(w, argc, argv, 0, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          wc->clipx = x;
          wc->clipy = y;
          wc->clipw = width;
          wc->cliph = height;
          setclip(w);
      }

      return self;
   }
end

function{1} graphics_Window_clone_impl(self, argv[argc])
   body {
       wbp w2;
       int n;
       tended struct descrip sbuf, sbuf2;
       char answer[128];
       WindowParam(self, w);

       Protect(w2 = alc_wbinding(), runerr(0));
       w2->window = w->window;
       w2->window->refcount++;
       Protect(w2->context = clone_context(w), runerr(0));

       for (n = 0; n < argc; n++) {
           if (!is:null(argv[n])) {
               if (!cnv:tmp_string(argv[n], sbuf))
                   runerr(109, argv[n]);
               switch (wattrib(w2, StrLoc(argv[n]), StrLen(argv[n]), &sbuf2, answer)) {
                   case Failed: fail;
                   case Error: runerr(0, argv[n]);
	       }
           }
       }

       return C_integer((long int)w2);
   }
end

function{0,1} graphics_Window_color(self, argv[argc])
   body {
      int i, len;
      C_integer n;
      char *colorname, *srcname;
      tended char *tmp;
      WindowParam(self, w);

      if (argc == 0) runerr(101);

      if (argc == 1) {			/* if this is a query */
          CnvCInteger(argv[0], n)
              if ((colorname = get_mutable_name(w, n)) == NULL)
                  fail;
          len = strlen(colorname);
          Protect(tmp = alcstr(colorname, len), runerr(0));
          return string(len, tmp);
      }

      CheckArgMultipleOf(2);

      for (i = 0; i < argc; i += 2) {
          CnvCInteger(argv[i], n)
              if ((colorname = get_mutable_name(w, n)) == NULL)
                  fail;

          if (is:integer(argv[i+1])) {		/* copy another mutable  */
              if (IntVal(argv[i+1]) >= 0)
                  runerr(205, argv[i+1]);		/* must be negative */
              if ((srcname = get_mutable_name(w, IntVal(argv[i+1]))) == NULL)
                  fail;
              if (set_mutable(w, n, srcname) == Failed) fail;
              strcpy(colorname, srcname);
          }
   
          else {					/* specified by name */
              tended char *tmp;
              if (!cnv:C_string(argv[i+1],tmp))
                  runerr(103,argv[i+1]);
   
              if (set_mutable(w, n, tmp) == Failed) fail;
              strcpy(colorname, tmp);
          }
      }

      return self;
   }
end

function{0,1} graphics_Window_color_value(self, k)
   body {
      C_integer n;
      int len;
      long r, g, b, a = 65535;
      tended char *s;
      char tmp[32], *t;
      WindowParam(self, w);

      if (is:null(k))
          runerr(103);

      if (cnv:C_integer(k, n)) {
          if ((t = get_mutable_name(w, n)))
              Protect(s = alcstr(t, (word)strlen(t)+1), runerr(306));
          else
              fail;
      }
      else if (!cnv:C_string(k, s))
          runerr(103, k);

      if (parsecolor(w, s, &r, &g, &b, &a) == Succeeded) {
          if (a < 65535)
              sprintf(tmp,"%ld,%ld,%ld,%ld", r, g, b, a);
          else
              sprintf(tmp,"%ld,%ld,%ld", r, g, b);
          len = strlen(tmp);
          Protect(s = alcstr(tmp,len), runerr(306));
          return string(len, s);
      }
      fail;
   }
end

function{0,1} graphics_Window_copy_area(src, dest, argv[argc])
   body {
      int n, r;
      C_integer x, y, width, height, x2, y2, width2, height2;
      wbp w2;

      WindowParam(src, w);
      if (is:null(dest))
          w2 = w;
      else {
          WindowParam(dest, tmp);
          w2 = tmp;
      }

      /*
       * x1, y1, width, and height follow standard conventions.
       */
      r = rectargs(w, argc, argv, 0, &x, &y, &width, &height);
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

      if (copyArea(w, w2, x, y, width, height, x2, y2) == Failed)
          fail;

      return nulldesc;
   }
end

function{0,1} graphics_Window_couple_impl(win, win2)
   body {
      tended struct descrip sbuf, sbuf2;
      wbp wb, wb2, wb_new;
      wsp ws;

      {
          WindowParam(win, tmp);
          wb = tmp;
      }
      {
          WindowParam(win2, tmp);
          wb2 = tmp;
      }

      /*
       * make the new binding
       */
      Protect(wb_new = alc_wbinding(), runerr(0));

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

      return C_integer((long int)wb_new);
   }
end


function{1} graphics_Window_draw_arc(self, argv[argc])
   body {
      int i, j, r;
      XArc arcs[MAXXOBJS];
      C_integer x, y, width, height;
      double a1, a2;

      WindowParam(self, w);

      j = 0;
      for (i = 0; i < argc || i == 0; i += 6) {
          if (j == MAXXOBJS) {
              drawarcs(w, arcs, MAXXOBJS);
              j = 0;
          }
          r = rectargs(w, argc, argv, i, &x, &y, &width, &height);
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

      drawarcs(w, arcs, j);

      return self;
   }
end

function{1} graphics_Window_draw_circle(self, argv[argc])
   body {
      int r;
      WindowParam(self, w);

      r = docircles(w, argc, argv, 0);
      if (r < 0)
         return self;
      else if (r >= argc)
         runerr(146);
      else 
         runerr(102, argv[r]);
   }
end

function{1} graphics_Window_draw_curve(self, argv[argc])
   body {
      int i, n, closed = 0;
      C_integer dx, dy, x0, y0, xN, yN;
      XPoint *points;
      WindowParam(self, w);

      CheckArgMultipleOf(2);

      dx = w->context->dx;
      dy = w->context->dy;

      Protect(points = (XPoint *)malloc(sizeof(XPoint) * (n+2)), runerr(305));

      if (n > 1) {
          CnvCInteger(argv[0], x0)
              CnvCInteger(argv[1], y0)
              CnvCInteger(argv[argc - 2], xN)
              CnvCInteger(argv[argc - 1], yN)
              if ((x0 == xN) && (y0 == yN)) {
                  closed = 1;               /* duplicate the next to last point */
                  CnvCShort(argv[argc-4], points[0].x);
                  CnvCShort(argv[argc-3], points[0].y);
                  points[0].x += w->context->dx;
                  points[0].y += w->context->dy;
              }
              else {                       /* duplicate the first point */
                  CnvCShort(argv[0], points[0].x);
                  CnvCShort(argv[1], points[0].y);
                  points[0].x += w->context->dx;
                  points[0].y += w->context->dy;
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
              drawlines(w, points+1, n);
          }
          else {
              drawCurve(w, points, n+2);
          }
      }
      free(points);

      return self;
   }
end


function{0,1} graphics_Window_draw_image(self, argv[argc])
   body {
      int c, i, width, height, row, p;
      C_integer x, y;
      word nchars;
      unsigned char *s, *t, *z;
      struct descrip d;
      struct palentry *e;
      WindowParam(self, w);

      /*
       * X or y can be defaulted but s is required.
       * Validate x/y first so that the error message makes more sense.
       */
      if (argc >= 1 && !def:C_integer(argv[0], -w->context->dx, x))
          runerr(101, argv[0]);
      if (argc >= 2 && !def:C_integer(argv[1], -w->context->dy, y))
          runerr(101, argv[1]);
      if (argc < 3)
          runerr(103);			/* missing s */
      if (!cnv:tmp_string(argv[2], d))
          runerr(103, argv[2]);

      x += w->context->dx;
      y += w->context->dy;
      /*
       * Extract the Width and skip the following comma.
       */
      s = (unsigned char *)StrLoc(d);
      z = s + StrLen(d);		/* end+1 of string */
      width = 0;
      while (s < z && *s == ' ')	/* skip blanks */
          s++;
      while (s < z && isdigit(*s))	/* scan number */
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
              if (isxdigit(*t))
                  nchars++;			/* count hex digits */
              else if (*t != PCH1 && *t != PCH2)
                  fail;				/* illegal punctuation */
          if (nchars == 0)
              fail;
          row = (width + 3) / 4;			/* digits per row */
          if (nchars % row != 0)
              fail;
          height = nchars / row;
          if (blimage(w, x, y, width, height, c, s, (word)(z - s)) == Error)
              runerr(305);
          else
              return nulldesc;
      }

      /*
       * Extract the palette name and skip its comma.
       */
      c = *s++;					/* save initial character */
      p = 0;
      while (s < z && isdigit(*s))		/* scan digits */
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
      i = strimage(w, x, y, width, height, e, s, (word)(z - s), 0);
      if (i == 0)
          return nulldesc;
      else if (i < 0)
          runerr(305);
      else
          return C_integer i;
   }
end


function{1} graphics_Window_draw_line(self, argv[argc])
   body {
      int i, j, n;
      XPoint points[MAXXOBJS];
      int dx, dy;

      WindowParam(self, w);

      CheckArgMultipleOf(2);

      dx = w->context->dx;
      dy = w->context->dy;
      for(i = 0, j = 0; i < n; i++, j++) {
          int base = i * 2;
          if (j == MAXXOBJS) {
              drawlines(w, points, MAXXOBJS);
              points[0] = points[MAXXOBJS-1];
              j = 1;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawlines(w, points, j);

      return self;
   }
end

function{1} graphics_Window_draw_point(self, argv[argc])
   body {
      int i, j, n;
      XPoint points[MAXXOBJS];
      int dx, dy;

      WindowParam(self, w);
      CheckArgMultipleOf(2);

      dx = w->context->dx;
      dy = w->context->dy;
      for(i=0, j=0; i < n; i++, j++) {
          int base = i * 2;
          if (j == MAXXOBJS) {
              drawpoints(w, points, MAXXOBJS);
              j = 0;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawpoints(w, points, j);
      
      return self;
   }
end

function{1} graphics_Window_draw_polygon(self, argv[argc])
   body {
      int i, j, n, base, dx, dy;
      XPoint points[MAXXOBJS];

      WindowParam(self, w);
      CheckArgMultipleOf(2);

      dx = w->context->dx;
      dy = w->context->dy;

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
              drawlines(w, points, MAXXOBJS);
              points[0] = points[MAXXOBJS-1];
              j = 1;
          }
          CnvCShort(argv[base], points[j].x);
          CnvCShort(argv[base + 1], points[j].y);
          points[j].x += dx;
          points[j].y += dy;
      }
      drawlines(w, points, j);

      return self;
   }
end

function{1} graphics_Window_draw_rectangle(self, argv[argc])
   body {
      int i, j, r;
      XRectangle recs[MAXXOBJS];
      C_integer x, y, width, height;

      WindowParam(self, w);

      j = 0;

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          if (j == MAXXOBJS) {
              drawrectangles(w,recs,MAXXOBJS);
              j = 0;
          }
          RECX(recs[j]) = x;
          RECY(recs[j]) = y;
          RECWIDTH(recs[j]) = width;
          RECHEIGHT(recs[j]) = height;
          j++;
      }

      drawrectangles(w, recs, j);

      return self;
   }
end

function{1} graphics_Window_draw_segment(self, argv[argc])
   body {
      int i, j, n, dx, dy;
      XSegment segs[MAXXOBJS];

      WindowParam(self, w);
      CheckArgMultipleOf(4);

      dx = w->context->dx;
      dy = w->context->dy;
      for(i=0, j=0; i < n; i++, j++) {
          int base = i * 4;
          if (j == MAXXOBJS) {
              drawsegments(w, segs, MAXXOBJS);
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
      drawsegments(w, segs, j);

      return self;
    }
end

function{1} graphics_Window_draw_string(self, argv[argc])
   body {
      int i, n, len;
      char *s;
      int dx, dy;

      WindowParam(self, w);
      CheckArgMultipleOf(3);

      for(i=0; i < n; i++) {
          C_integer x, y;
          int base = i * 3;
          CnvCInteger(argv[base], x);
          CnvCInteger(argv[base + 1], y);
          x += w->context->dx;
          y += w->context->dy;
          CnvTmpString(argv[base + 2], argv[base + 2]);
          s = StrLoc(argv[base + 2]);
          len = StrLen(argv[base + 2]);
          drawstrng(w, x, y, s, len);
      }
      return self;
   }
end


function{1} graphics_Window_erase_area(self, argv[argc])
   body {
      int i, r;
      C_integer x, y, width, height;
      WindowParam(self, w);

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          eraseArea(w, x, y, width, height);
      }
      return self;
   }
end



function{1} graphics_Window_event(self, timeout)
   if !def:C_integer(timeout, -1) then
      runerr(101, timeout)
   body {
      C_integer i;
      tended struct descrip d;
      WindowParam(self, w);

      d = create_list(8);
      i = wgetevent2(w, &d, timeout);
      if (i == -3) {
          if (timeout < 0) {
              /* Something's wrong, but what?  */
              runerr(-1);
          }
          fail;
      }
      if (i == 0)
          return d;
      else if (i == -1)
          runerr(141);
      else
          runerr(143);
   }
end

function{0,1} graphics_Window_pending(self, argv[argc])
   body {
      wsp ws;
      int i;
      WindowParam(self, w);

      ws = w->window;
      wsync(w);

      /*
       * put additional arguments to Pending on the pending list in
       * guaranteed consecutive order.
       */
      for (i = 0; i < argc; i++) {
          c_put(&(ws->listp), &argv[i]);
      }

      /*
       * retrieve any events that might be relevant before returning the
       * pending queue.
       */
      switch (pollevent()) {
          case -1: runerr(141);
          case 0: fail;
      }
      return ws->listp;
   }
end


function{0,1} graphics_Window_fg(self, colr)
   body {
      char sbuf1[MaxCvtLen];
      int len;
      tended char *tmp;
      char *temp;
      WindowParam(self, w);

      /*
       * If there is a (non-window) argument we are setting by
       *  either a mutable color (negative int) or a string name.
       */
      if (!is:null(colr)) {
	  if (is:integer(colr)) {	/* mutable color or packed RGB */
              if (isetfg(w, IntVal(colr)) == Failed) 
                  fail;
          }
	  else {
              if (!cnv:C_string(colr, tmp))
                  runerr(103, colr);
              if(setfg(w, tmp) == Failed)
                  fail;
          }

      }

      /*
       * In any case, this function returns the current foreground color.
       */

      getfg(w, sbuf1);

      len = strlen(sbuf1);
      Protect(tmp = alcstr(sbuf1, len), runerr(0));
      return string(len, tmp);
   }
end

function{1} graphics_Window_fill_arc(self, argv[argc])
   body {
      int i, j, r;
      XArc arcs[MAXXOBJS];
      C_integer x, y, width, height;
      double a1, a2;

      WindowParam(self, w);

      j = 0;
      for (i = 0; i < argc || i == 0; i += 6) {
          if (j == MAXXOBJS) {
              fillarcs(w, arcs, MAXXOBJS);
              j = 0;
          }
          r = rectargs(w, argc, argv, i, &x, &y, &width, &height);
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

      fillarcs(w, arcs, j);

      return self;
   }
end

function{1} graphics_Window_fill_circle(self, argv[argc])
   body {
      int r;
      WindowParam(self, w);

      r = docircles(w, argc, argv, 1);
      if (r < 0)
          return self;
      else if (r >= argc)
         runerr(146);
      else 
         runerr(102, argv[r]);
   }
end

function{1} graphics_Window_fill_polygon(self, argv[argc])
   body {
      int i, j, n;
      XPoint *points;
      int dx, dy;
      WindowParam(self, w);

      CheckArgMultipleOf(2);

      /*
       * Allocate space for all the points in a contiguous array,
       * because a FillPolygon must be performed in a single call.
       */
      n = argc>>1;
      Protect(points = (XPoint *)malloc(sizeof(XPoint) * n), runerr(305));
      dx = w->context->dx;
      dy = w->context->dy;
      for(i=0; i < n; i++) {
          int base = i * 2;
          CnvCShort(argv[base], points[i].x);
          CnvCShort(argv[base + 1], points[i].y);
          points[i].x += dx;
          points[i].y += dy;
      }
      fillpolygon(w, points, n);
      free(points);

      return self;
   }
end

function{1} graphics_Window_fill_rectangle(self, argv[argc])
   body {
      int i, j, r;
      XRectangle recs[MAXXOBJS];
      C_integer x, y, width, height;

      WindowParam(self, w);

      j = 0;

      for (i = 0; i < argc || i == 0; i += 4) {
          r = rectargs(w, argc, argv, i, &x, &y, &width, &height);
          if (r >= 0)
              runerr(101, argv[r]);
          if (j == MAXXOBJS) {
              fillrectangles(w,recs,MAXXOBJS);
              j = 0;
          }
          RECX(recs[j]) = x;
          RECY(recs[j]) = y;
          RECWIDTH(recs[j]) = width;
          RECHEIGHT(recs[j]) = height;
          j++;
      }

      fillrectangles(w, recs, j);

      return self;
   }
end

function{0,1} graphics_Window_font(self, f)
   body {
      tended char *tmp;
      int len;
      char buf[MaxCvtLen];
      WindowParam(self, w);

      if (!is:null(f)) {
          if (!cnv:C_string(f, tmp))
              runerr(103, f);
          if (setfont(w,&tmp) == Failed) 
              fail;
      }
      getfntnam(w, buf);
      len = strlen(buf);
      Protect(tmp = alcstr(buf, len), runerr(0));
      return string(len,tmp);
   }
end

function{1} graphics_Window_free_color(self, argv[argc])
   body {
      int i;
      C_integer n;
      tended char *s;
      WindowParam(self, w);

      if (argc == 0)
          runerr(103);

      for (i = 0; i < argc; i++) {
          if (is:integer(argv[i])) {
              CnvCInteger(argv[i], n)
              if (n < 0)
                  free_mutable(w, n);
          }
          else {
              if (!cnv:C_string(argv[i], s))
                  runerr(103,argv[i]);
              freecolor(w, s);
          }
      }

      return self;
   }
end

function{1} graphics_Window_lower(self)
   body {
      WindowParam(self, w);
      lowerWindow(w);
      return self;
   }
end


function{0,1} graphics_Window_new_color(self, argv[argc])
   body {
      int rv;
      WindowParam(self, w);

      if (mutable_color(w, argv, argc, &rv) == Failed) 
          fail;
      return C_integer rv;
   }
end

function{0,1} graphics_Window_palette_chars(p)
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
          case  5:  return string(141, (char *)allchars);	/* c5 */
          case  6:  return string(241, (char *)allchars);	/* c6 */
          default:					/* gn */
              if (n >= -64)
                  return string(-n, c4list);
              else
                  return string(-n, (char *)allchars);
      }
      fail; /* NOTREACHED */ /* avoid spurious rtt warning message */
   }
end

function{0,1} graphics_Window_palette_color(s1, s2)
   body {
      int p, len;
      char tmp[24], *s;
      struct palentry *e;
      tended struct descrip d;

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
      len = strlen(tmp);
      Protect(s = alcstr(tmp, len), runerr(306));
      return string(len, s);
   }
end

function{0,1} graphics_Window_palette_key(self, s1, s2)
   body {
      int p;
      C_integer n;
      tended char *s;
      long r, g, b, a;

      WindowParam(self, w);

      p = palnum(&s1);
      if (p == -1)
          runerr(103, s1);
      if (p == 0)
          fail;

      if (cnv:C_integer(s2, n)) {
          if ((s = get_mutable_name(w, n)) == NULL)
              fail;
      }
      else if (!cnv:C_string(s2, s))
          runerr(103, s2);

      if (parsecolor(w, s, &r, &g, &b, &a) == Succeeded)
          return string(1, rgbkey(p, r / 65535.0, g / 65535.0, b / 65535.0));
      else
          fail;
   }
end

function{1} graphics_Window_pattern(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
      WindowParam(self, w);

      switch (SetPattern(w, StrLoc(s), StrLen(s))) {
          case Error:
              runerr(0, s);
          case Failed:
              fail;
      }

      return self;
   }
end

function{3} graphics_Window_pixel(self, argv[argc])
   body {
      struct imgmem imem;
      C_integer x, y, width, height;
      int slen, r;
      tended struct descrip lastval;
      char strout[50];
      WindowParam(self, w);

      r = rectargs(w, argc, argv, 0, &x, &y, &width, &height);
      if (r >= 0)
          runerr(101, argv[r]);

      {
          int i, j;
          long rv;
          wsp ws = w->window;

          imem.x = Max(x,0);
          imem.y = Max(y,0);
          imem.width = Min(width, (int)ws->width - imem.x);
          imem.height = Min(height, (int)ws->height - imem.y);

          if (getpixel_init(w, &imem) == Failed) fail;

          lastval = emptystr;

          for (j=y; j < y + height; j++) {
              for (i=x; i < x + width; i++) {
                  getpixel(w, i, j, &rv, strout, &imem);
	
                  slen = strlen(strout);
                  if (rv >= 0) {
                      int signal;
                      if (slen != StrLen(lastval) ||
                          strncmp(strout, StrLoc(lastval), slen)) {
                          Protect((StrLoc(lastval) = alcstr(strout, slen)), runerr(0));
                          StrLen(lastval) = slen;
                      }
                      /*
                       * suspend, but free up imem if vanquished; RTL workaround.
                       * Needs implementing under the compiler iconc.
                       */
                      r_args[0] = lastval;
                      if ((signal = interp(G_Fsusp, r_args)) != A_Resume) {
                          tend = r_tend.previous;
                          getpixel_term(w, &imem);
                          VanquishReturn(signal);
                      }
                  }
                  else {
                      int signal;
                      /*
                       * suspend, but free up imem if vanquished; RTL workaround
                       * Needs implementing under the compiler.
                       */
                      r_args[0].dword = D_Integer;
                      r_args[0].vword.integr = rv;
                      if ((signal = interp(G_Fsusp, r_args)) != A_Resume) {
                          tend = r_tend.previous;
                          getpixel_term(w, &imem);
                          VanquishReturn(signal);
                      }
                  }
              }
          }
          getpixel_term(w, &imem);
          fail;
      }
   }
end

function{1} graphics_Window_query_root_pointer()
   body {
      XPoint xp;
      struct descrip t;
      pollevent();
      query_rootpointer(&xp);
      result = create_list(2);
      MakeInt(xp.x, &t);
      c_put(&result, &t);
      MakeInt(xp.y, &t);
      c_put(&result, &t);
      return result;
   }
end

function{1} graphics_Window_raise(self)
   body {
      WindowParam(self, w);
      raiseWindow(w);
      return self;
   }
end

function{0,1} graphics_Window_read_image(self, argv[argc])
   body {
      char filename[MaxPath + 1];
      tended char *tmp;
      int status;
      C_integer x, y;
      int p, r;
      struct imgdata imd;
      WindowParam(self, w);

      if (argc == 0)
          runerr(103,nulldesc);
      if (!cnv:C_string(argv[0], tmp))
          runerr(103,argv[0]);

      /*
       * x and y must be integers; they default to the upper left pixel.
       */
      if (argc < 2) 
          x = -w->context->dx;
      else if (!def:C_integer(argv[1], -w->context->dx, x))
          runerr(101, argv[1]);
      if (argc < 3)
          y = -w->context->dy;
      else if (!def:C_integer(argv[2], -w->context->dy, y))
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

      x += w->context->dx;
      y += w->context->dy;
      strncpy(filename, tmp, MaxPath);   /* copy to loc that won't move*/
      filename[MaxPath] = '\0';

      /*
       * First try to read as a GIF file.
       * If that doesn't work, try platform-dependent image reading code.
       */
      r = readGIF(filename, p, &imd);
      if (r != Succeeded) r = readBMP(filename, p, &imd);
      if (r == Succeeded) {
          status = strimage(w, x, y, imd.width, imd.height, imd.paltbl,
                            imd.data, (word)imd.width * (word)imd.height, 0);
          if (status < 0)
              r = Error;
          free((pointer)imd.paltbl);
          free((pointer)imd.data);
      }
      else if (r == Failed)
          r = readimage(w, filename, x, y, &status);
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

function{1} graphics_Window_sync()
   body {
      wsync(0);
      pollevent();
      return nulldesc;
   }
end

function{1} graphics_Window_text_width(self, s)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
      C_integer i;
      WindowParam(self, w);
      i = TEXTWIDTH(w, StrLoc(s), StrLen(s));
      return C_integer i;
   }
end

"Uncouple(w) - uncouple window"

function{1} graphics_Window_uncouple(self)
   body {
      WindowParam(self, w);
      *w_dptr = zerodesc;
      free_binding(w);
      return self;
   }
end

function{*} graphics_Window_attrib(self, argv[argc])
   body {
      wbp wsave;
      word n;
      tended struct descrip sbuf, sbuf2 = nulldesc;
      char answer[4096];
      int  pass, config = 0;

      WindowParam(self, w);

      wsave = w;
      /*
       * Loop through the arguments.
       */

      for (pass = 1; pass <= 2; pass++) {
          w = wsave;
          if (config && pass == 2) {
              if (do_config(w, config) == Failed) fail;
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


                      switch (wattrib(w, StrLoc(sbuf), StrLen(sbuf),
                                      &sbuf2, answer)) {
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

                  switch (wattrib(w, StrLoc(sbuf), StrLen(sbuf),
                                  &sbuf2, answer)) {
                      case Failed: continue;
                      case Error:  runerr(0, argv[n]);
                  }
                  if (is:string(sbuf2)) {
                      char *p=StrLoc(sbuf2);
                      Protect(StrLoc(sbuf2) = alcstr(StrLoc(sbuf2),StrLen(sbuf2)), runerr(0));
                      if (p != answer) free(p);
                  }
                  suspend sbuf2;
              }
          }
      }
      fail;
   }
end

function{0,1} graphics_Window_wdefault(self, prog, opt)
   if !cnv:C_string(prog) then
       runerr(103, prog)
   if !cnv:C_string(opt) then
       runerr(103, opt)
   body {
      long l;
      char sbuf1[MaxCvtLen];
      WindowParam(self, w);

      if (getdefault(w, prog, opt, sbuf1) == Failed) 
          fail;
      l = strlen(sbuf1);
      Protect(prog = alcstr(sbuf1,l),runerr(0));
      return string(l,prog);
   }
end

function{1} graphics_Window_flush(self)
   body {
      WindowParam(self, w);
      wflush(w);
      return self;
   }
end

function{0,1} graphics_Window_write_image(self, s, argv[argc])
   if !cnv:C_string(s) then
       runerr(103, s)
   body {
      int r;
      C_integer x, y, width, height;
      WindowParam(self, w);

      r = rectargs(w, argc, argv, 0, &x, &y, &width, &height);
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
      if (x + width > (long) w->window->width)
          width = w->window->width - x;
      if (y + height > (long) w->window->height)
          height = w->window->height - y;
      if (width <= 0 || height <= 0)
          fail;

      /*
       * try platform-dependent code first; it will reject the call
       * if the file name s does not specify a platform-dependent format.
       */
      r = dumpimage(w, s, x, y, width, height);
#ifdef HAVE_LIBJPEG
      if ((r == NoCvt) &&
	  (strcmp(s + strlen(s)-4, ".jpg")==0 ||
           (strcmp(s + strlen(s)-4, ".JPG")==0))) {
          r = writeJPEG(w, s, x, y, width, height);
      }
#endif					/* HAVE_LIBJPEG */
      if (r == NoCvt)
          r = writeBMP(w, s, x, y, width, height);
      if (r == NoCvt)
          r = writeGIF(w, s, x, y, width, height);
      if (r != Succeeded)
         fail;

      return self;
   }
end

function{1} graphics_Window_own_selection(self, selection, callback)
   if !cnv:C_string(selection) then
      runerr(103,selection)
   if !is:proc(callback) then
      runerr(106,callback);
   body {
       WindowParam(self, w);
       w->window->selectionproc = callback;
       ownselection(w, selection);
       return self;
   }
end

function{0,1} graphics_Window_get_selection_content(self, selection,target_type)
   if !cnv:C_string(selection) then
      runerr(103,selection)
   if !def:C_string(target_type, "STRING") then
      runerr(103,target_type)
   body {
       tended struct descrip s;
       WindowParam(self, w);
       s = getselectioncontent(w, selection,target_type);
       if (is:null(s))
           fail;
       return s;
   }
end

function{1} graphics_Window_close(self)
   body {
     WindowParam(self, w);

     *w_dptr = zerodesc;
     SETCLOSED(w);
     wclose(w);

     return self;
   }
end

#else  /* Graphics */

function{0,1} graphics_Window_open_impl(attr[n])
   runerr(121)
end

#endif   /* Graphics */
