/*
 * File: rwindow.r
 *  non window-system-specific window support routines
 */

#ifdef Graphics

/*
 * global variables.
 */

wcp wcntxts = NULL;
wsp wstates = NULL;
wbp wbndngs = NULL;

#ifdef HAVE_LIBJPEG
static int  writeJPEG       (wbp w, char *filename, int x, int y, int width, int height);
static int  readJPEG        (char *fname, struct imgdata *d);
#endif                                  /* HAVE_LIBJPEG */
#ifdef HAVE_LIBPNG
static int readPNG(char *filename, struct imgdata *imd);
static int writePNG(wbp w, char *filename, int x, int y, int width, int height);
#endif
static int readGIF         (char *fname, struct imgdata *d);

static	int	colorphrase    (char *buf, int *r, int *g, int *b);
static	double rgbval(double n1, double n2, double hue);
static  void wgetq(wbp w, dptr res);
static	void getfg_rgb(wbp w, int *r, int *g, int *b);
static	void getbg_rgb(wbp w, int *r, int *g, int *b);

static void drawpalette(wbp w, int x, int y, int width, int height, 
                        struct palentry *e, unsigned char *s, int copy);

int canvas_serial, context_serial;

#if MSWIN32
extern wclrp scp;
extern HPALETTE palette;
extern int numColors;
#endif					/* MSWIN32 */

static void wgetq(wbp w, dptr res)
{
    if (!list_get(&w->window->listp, res))
        fatalerr(143, 0);
}


void wgetevent(wbp w, dptr res)
{
    tended struct descrip qval;
    int i;

    while (ListBlk(w->window->listp).size == 0) {
        pollevent();				/* poll all windows */
        idelay(XICONSLEEP);
    }

    wgetq(w, &qval);
    create_list(8, res);
    list_put(res, &qval);

    /*
     * Handle the selection message types.
     */
    if (is:integer(qval)) {
        switch (IntVal(qval)) {
            case SELECTIONREQUEST: {
                /* Five items follow; copy them to the result */
                for (i = 0; i < 5; ++i) {
                    wgetq(w, &qval);
                    list_put(res, &qval);
                }
                return;
            }
            case INVOKELATER: {
                /* Two items follow */
                for (i = 0; i < 2; ++i) {
                    wgetq(w, &qval);
                    list_put(res, &qval);
                }
                return;
            }
            case SELECTIONCLEAR: {
                /* One item follows */
                wgetq(w, &qval);
                list_put(res, &qval);
                return;
            }
            case SELECTIONRESPONSE: {
                /* Three items follow */
                for (i = 0; i < 3; ++i) {
                    wgetq(w, &qval);
                    list_put(res, &qval);
                }
                return;
            }
        }
    }

    /*
     * All other types - "real events" - seven items follow.  The x,y
     * values need to be adjusted with the dx,dy offsets.
     */
    wgetq(w, &qval);
    IntVal(qval) -= w->context->dx;
    list_put(res, &qval);

    wgetq(w, &qval);
    IntVal(qval) -= w->context->dy;
    list_put(res, &qval);

    for (i = 0; i < 5; ++i) {
        wgetq(w, &qval);
        list_put(res, &qval);
    }
}


/*
 * Enqueue an event, encoding time interval and key state with x and y values.
 */
void qevent(wsp ws,             /* canvas */
            dptr e,             /* event code (descriptor pointer) */
            int x,              /* x and y values */
            int y,      
            uword t,            /* ms clock value */
            int ctrl,           /* modifier key flags */
            int meta,
            int shift,
            int rel)            /* key release flag */
{
    dptr q = &(ws->listp);	/* a window's event queue (Icon list value) */
    struct descrip d;
    word ivl;

    if (t != 0) {		/* if clock value supplied */
        if (ws->timestamp == 0)		/* if first time */
            ws->timestamp = t;
        if (t < ws->timestamp)		/* if clock went backwards */
            t = ws->timestamp;
        ivl = t - ws->timestamp;		/* calc interval in milliseconds */
        ws->timestamp = t;		/* save new clock value */
    }
    else
        ivl = 0;				/* report 0 if interval unknown */

    /* Event code */
    list_put(q, e);

    /* x, y */
    MakeInt(x, &d);
    list_put(q, &d);
    MakeInt(y, &d);
    list_put(q, &d);

    /* Modifiers */
    if (ctrl)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (meta)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (shift)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (rel)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);

    /* Interval */
    MakeInt(ivl, &d);
    list_put(q, &d);
}

#define swap(a,b) { int tmp = a; a = b; b = tmp; }

void qmouseevents(wsp ws,             /* canvas */
                  int state,          /* state of mouse buttons */
                  int x,              /* x and y values */
                  int y,      
                  uword t,            /* ms clock value */
                  int ctrl,           /* modifier key flags */
                  int meta,
                  int shift)
{
    struct descrip d;
    if (ws->mousestate == state) {
        /* Motion */
        if (state == 0) {
            if (ws->inputmask & IM_POINTER_MOTION) {
                MakeInt(MOUSEMOVED, &d);
                qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
            }
        } else {
            switch (ws->buttonorder[0]) {
                case 1: {
                    MakeInt(MOUSELEFTDRAG, &d);
                    qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
                    break;
                }
                case 2: {
                    MakeInt(MOUSEMIDDRAG, &d);
                    qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
                    break;
                }
                case 4: {
                    MakeInt(MOUSERIGHTDRAG, &d);
                    qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
                    break;
                }
            }
        }
    } else {
        /* Press or release of one or more buttons */
        if ((ws->mousestate & 1) && !(state & 1)) {
            if (ws->buttonorder[0] == 1)
                swap(ws->buttonorder[0],ws->buttonorder[1]);
            if (ws->buttonorder[1] == 1)
                swap(ws->buttonorder[1],ws->buttonorder[2]);
            MakeInt(MOUSELEFTUP, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        } else if (!(ws->mousestate & 1) && (state & 1)) {
            if (ws->buttonorder[2] == 1)
                swap(ws->buttonorder[1],ws->buttonorder[2]);
            if (ws->buttonorder[1] == 1)
                swap(ws->buttonorder[0],ws->buttonorder[1]);
            MakeInt(MOUSELEFT, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        }

        if ((ws->mousestate & 2) && !(state & 2)) {
            if (ws->buttonorder[0] == 2)
                swap(ws->buttonorder[0],ws->buttonorder[1]);
            if (ws->buttonorder[1] == 2)
                swap(ws->buttonorder[1],ws->buttonorder[2]);
            MakeInt(MOUSEMIDUP, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);

        } else if (!(ws->mousestate & 2) && (state & 2)) {
            if (ws->buttonorder[2] == 2)
                swap(ws->buttonorder[1], ws->buttonorder[2]);
            if (ws->buttonorder[1] == 2)
                swap(ws->buttonorder[0], ws->buttonorder[1]);
            MakeInt(MOUSEMID, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        }

        if ((ws->mousestate & 4) && !(state & 4)) {
            if (ws->buttonorder[0] == 4)
                swap(ws->buttonorder[0],ws->buttonorder[1]);
            if (ws->buttonorder[1] == 4)
                swap(ws->buttonorder[1],ws->buttonorder[2]);
            MakeInt(MOUSERIGHTUP, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        } else if (!(ws->mousestate & 4) && (state & 4)) {
            if (ws->buttonorder[2] == 4)
                swap(ws->buttonorder[1], ws->buttonorder[2]);
            if (ws->buttonorder[1] == 4)
                swap(ws->buttonorder[0], ws->buttonorder[1]);
            MakeInt(MOUSERIGHT, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        }

        /* The mouse wheel just generates up events, depending on the 
         * direction */
        if ((ws->mousestate & 8) && !(state & 8)) {
            MakeInt(MOUSE4UP, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        }
        if ((ws->mousestate & 16) && !(state & 16)) {
            MakeInt(MOUSE5UP, &d);
            qevent(ws, &d, x, y, t, ctrl, meta, shift, 0);
        }
    }
    ws->mousestate = state;
}


static void getfg_rgb(wbp w, int *r, int *g, int *b)
{
    parsecolor(getfg(w), r, g, b);
}

static void getbg_rgb(wbp w, int *r, int *g, int *b)
{
    parsecolor(getbg(w), r, g, b);
}

static void linearfilter_impl(int *val, float m, int c)
{
    *val = *val * m + c;
    if (*val < 0) *val = 0;
    else if (*val > 65535) *val = 65535;
}
 
static void linearfilter(struct filter *f)
{
    int i, j;
    struct imgmem *imem = f->imem;
    for (j = imem->y; j < imem->y + imem->height; j++) {
        for (i = imem->x; i < imem->x + imem->width; i++) {
            int r, g, b;
            gotopixel(imem, i, j);
            getpixel(imem, &r, &g, &b);
            linearfilter_impl(&r, f->p.linear.mr, f->p.linear.cr);
            linearfilter_impl(&g, f->p.linear.mg, f->p.linear.cg);
            linearfilter_impl(&b, f->p.linear.mb, f->p.linear.cb);
            setpixel(imem, r, g, b);
        }
    }
}

static int grey_band(int nb, int r, int g, int b)
{
    return (int)(nb * (0.299 * r + 0.587 * g + 0.114 * b) / 65535.0);
}

static void shadefilter(struct filter *f)
{
    int i, j;
    struct imgmem *imem = f->imem;
    int bk, bg_r, bg_g, bg_b;
    getbg_rgb(f->w, &bg_r, &bg_g, &bg_b);

    bk = grey_band(f->p.shade.nband, bg_r, bg_g, bg_b);
    for (j = imem->y; j < imem->y + imem->height; j++) {
        for (i = imem->x; i < imem->x + imem->width; i++) {
            int r, g, b, k, v;
            gotopixel(imem, i, j);
            getpixel(imem, &r, &g, &b);
            k = grey_band(f->p.shade.nband, r, g, b);
            if (k != bk) {
                v = f->p.shade.c + f->p.shade.m * k;
                setpixel(imem, v, v, v);
            }
        }
    }
}

static void coercefilter(struct filter *f)
{
    int i, j;
    struct imgmem *imem = f->imem;
    struct palentry *pal = palsetup(f->p.coerce.p);
    for (j = imem->y; j < imem->y + imem->height; j++) {
        for (i = imem->x; i < imem->x + imem->width; i++) {
            int r, g, b;
            char *s;
            struct palentry *e;
            gotopixel(imem, i, j);
            getpixel(imem, &r, &g, &b);
            s = rgbkey(f->p.coerce.p, r, g, b);
            e = pal + (*s & 0xff);
            setpixel(imem, e->r, e->g, e->b);
        }
    }
}

static void invertfilter(struct filter *f)
{
    int i, j;
    struct imgmem *imem = f->imem;
    for (j = imem->y; j < imem->y + imem->height; j++) {
        for (i = imem->x; i < imem->x + imem->width; i++) {
            int r, g, b;
            gotopixel(imem, i, j);
            getpixel(imem, &r, &g, &b);
            setpixel(imem, 65535 - r, 65535 - g, 65535 - b);
        }
    }
}

int parseinputmask(char *s, int *res)
{
    char *t;
    *res = 0;
    for (t = s; *t; ++t) {
        switch (*t) {
            case 'k':
                *res |= IM_KEY_RELEASE;
                break;
            case 'm':
                *res |= IM_POINTER_MOTION;
                break;
            default:
                return 0;
        }
    }
    return 1;
}

int parsefilter(wbp w, char *s, struct filter *res)
{
    char eof;
    res->w = w;
    if (strncmp(s, "linear,", 7) == 0) {
        int n;
        res->f = linearfilter;
        n = sscanf(s + 7, "%f,%f,%f,%d,%d,%d%c", 
                   &res->p.linear.mr, &res->p.linear.mg, &res->p.linear.mb,
                   &res->p.linear.cr, &res->p.linear.cg, &res->p.linear.cb, 
                   &eof);
        if (n != 3 && n != 6)
            return 0;
        if (n == 3)
            res->p.linear.cr = res->p.linear.cg = res->p.linear.cb = 0;
        return 1;
    }
    if (strncmp(s, "shade,", 6) == 0) {
        res->f = shadefilter;
        if (sscanf(s + 6, "%d,%d,%d%c", &res->p.shade.nband,
                   &res->p.shade.m, &res->p.shade.c, &eof) != 3)
            return 0;
        return 1;
    }
    if (strncmp(s, "coerce,", 7) == 0) {
        res->f = coercefilter;
        return parsepalette(s + 7, &res->p.coerce.p);
    }
    if (strncmp(s, "invert", 6) == 0) {
        res->f = invertfilter;
        return 1;
    }

    return 0;
}


/*
 * Structures and tables used for color parsing.
 *  Tables must be kept lexically sorted.
 */

typedef struct {	/* color name entry */
    char name[8];	/* basic color name */
    char ish[12];	/* -ish form */
    short hue;		/* hue, in degrees */
    char lgt;		/* lightness, as percentage */
    char sat;		/* saturation, as percentage */
} colrname;

typedef struct {	/* arbitrary lookup entry */
    char word[15];	/* word */
    char val;		/* value, as percentage */
} colrmod;

static colrname colortable[] = {		/* known colors */
    /* color       ish-form     hue  lgt  sat */
    { "black",    "blackish",     0,   0,   0 },
    { "blue",     "bluish",     240,  50, 100 },
    { "brown",    "brownish",    30,  25, 100 },
    { "cyan",     "cyanish",    180,  50, 100 },
    { "gray",     "grayish",      0,  50,   0 },
    { "green",    "greenish",   120,  50, 100 },
    { "grey",     "greyish",      0,  50,   0 },
    { "magenta",  "magentaish", 300,  50, 100 },
    { "orange",   "orangish",    15,  50, 100 },
    { "pink",     "pinkish",    345,  75, 100 },
    { "purple",   "purplish",   270,  50, 100 },
    { "red",      "reddish",      0,  50, 100 },
    { "violet",   "violetish",  270,  75, 100 },
    { "white",    "whitish",      0, 100,   0 },
    { "yellow",   "yellowish",   60,  50, 100 },
};

static colrmod lighttable[] = {			/* lightness modifiers */
    { "dark",       0 },
    { "deep",       0 },		/* = very dark (see code) */
    { "light",    100 },
    { "medium",    50 },
    { "pale",     100 },		/* = very light (see code) */
};

static colrmod sattable[] = {			/* saturation levels */
    { "moderate",  50 },
    { "strong",    75 },
    { "vivid",    100 },
    { "weak",      25 },
};

/*
 *  parsecolor(s, &r, &g, &b) - parse a color specification
 *
 *  parsecolor interprets a color specification and produces r/g/b values
 *  scaled linearly from 0 to 65535.  parsecolor returns 1 on success, 0
 *  on an invalid specification.
 *
 *  An Icon color specification can be any of the forms
 *
 *     #rgb			(hexadecimal digits)
 *     #rrggbb
 *     #rrrgggbbb		(note: no 3 digit rrrgggbbbaaa)
 *     #rrrrggggbbbb
 *     nnnnn,nnnnn,nnnnn	(integers 0 - 65535)
 *     <Icon color phrase>
 */

int parsecolor(char *buf, int *r, int *g, int *b)
{
    int len, mul;
    char *fmt, c;

    *r = *g = *b = 0L;

    /* trim leading spaces */
    while (isspace((unsigned char)*buf))
        buf++;

    /* try interpreting as three comma-separated numbers */
    if (sscanf(buf, "%d,%d,%d%c", r, g, b, &c) == 3) {
        if (*r>=0 && *r<=65535 && *g>=0 && *g<=65535 && *b>=0 && *b<=65535)
            return 1;
        else
            return 0;
    }

    /* try interpreting as a hexadecimal value */
    if (*buf == '#') {
        buf++;
        for (len = 0; isalnum((unsigned char)buf[len]); len++);
        switch (len) {
            case  3:  fmt = "%1x%1x%1x%c";  mul = 0x1111;  break;
            case  6:  fmt = "%2x%2x%2x%c";  mul = 0x0101;  break;
            case  9:  fmt = "%3x%3x%3x%c";  mul = 0x0010;  break;
            case 12:  fmt = "%4x%4x%4x%c";  mul = 0x0001;  break;
            default:  return 0;
        }
        if (sscanf(buf, fmt, r, g, b, &c) != 3)
            return 0;
        *r *= mul;
        *g *= mul;
        *b *= mul;
        return 1;
    }

    /* try interpreting as a color phrase */
    if (colorphrase(buf, r, g, b))
        return 1;
    else
        return 0;
}


/*
 *  colorphrase(s, &r, &g, &b) -- parse Icon color phrase.
 *
 *  A Unicon color phrase matches the pattern
 *
 *   transparent
 *   subtransparent                           weak
 *   translucent                 pale         moderate
 *   subtranslucent              light        strong
 * [ opaque     ]        [[very] medium ]   [ vivid    ]   [color[ish]]   color
 *                               dark 
 *                               deep
 *
 *  where "color" is any of:
 *
 *          black gray grey white pink violet brown
 *          red orange yellow green cyan blue purple magenta
 *
 *  A single space or hyphen separates each word from its neighbor.  The
 *  default lightness is "medium", and the default saturation is "vivid".
 *  The default diaphaneity is "opaque".
 *
 *  "pale" means "very light"; "deep" means "very dark".
 *
 *  This naming scheme is based loosely on
 *	A New Color-Naming System for Graphics Languages
 *	Toby Berk, Lee Brownston, and Arie Kaufman
 *	IEEE Computer Graphics & Applications, May 1982
 */

static int colorphrase(char *buf, int *r, int *g, int *b)
{
    int len, very;
    char c, *p, *ebuf, cbuffer[MAXCOLORNAME];
    float lgt, sat, blend, bl2, m1, m2;
    float h1, l1, s1, h2, l2, s2, r2, g2, b2;

    lgt = -1.0;				/* default no lightness mod */
    sat =  1.0;				/* default vivid saturation */
    len = strlen(buf);
    while (isspace((unsigned char)buf[len-1]))
        len--;				/* trim trailing spaces */

    if (len >= sizeof(cbuffer))
        return 0;				/* if too long for valid Icon spec */

    /*
     * copy spec, lowering case and replacing spaces and hyphens with NULs
     */
    for(p = cbuffer; (c = *buf) != 0; p++, buf++) {
        if ((unsigned char)isupper(c)) *p = tolower((unsigned char)c);
        else if (c == ' ' || c == '-') *p = '\0';
        else *p = c;
    }
    *p = '\0';

    buf = cbuffer;
    ebuf = buf + len;
    /* check for "very" */
    if (strcmp(buf, "very") == 0) {
        very = 1;
        buf += strlen(buf) + 1;
        if (buf >= ebuf)
            return 0;
    }
    else
        very = 0;

    /* check for lightness adjective */
    p = bsearch(buf, (char *)lighttable,
                ElemCount(lighttable), ElemSize(lighttable), (BSearchFncCast)strcmp);
    if (p) {
        /* set the "very" flag for "pale" or "deep" */
        if (strcmp(buf, "pale") == 0)
            very = 1;			/* pale = very light */
        else if (strcmp(buf, "deep") == 0)
            very = 1;			/* deep = very dark */
        /* skip past word */
        buf += strlen(buf) + 1;
        if (buf >= ebuf)
            return 0;
        /* save lightness value, but ignore "medium" */
        if ((((colrmod *)p) -> val) != 50)
            lgt = ((colrmod *)p) -> val / 100.0;
    }
    else if (very)
        return 0;

    /* check for saturation adjective */
    p = bsearch(buf, (char *)sattable,
                ElemCount(sattable), ElemSize(sattable), (BSearchFncCast)strcmp);
    if (p) {
        sat = ((colrmod *)p) -> val / 100.0;
        buf += strlen(buf) + 1;
        if (buf >= ebuf)
            return 0;
    }

    if (buf + strlen(buf) >= ebuf)
        blend = h1 = l1 = s1 = 0.0;		/* only one word left */
    else {
        /* we have two (or more) name words; get the first */
        if ((p = bsearch(buf, colortable[0].name,
                         ElemCount(colortable), ElemSize(colortable), (BSearchFncCast)strcmp)) != NULL) {
            blend = 0.5;
        }
        else if ((p = bsearch(buf, colortable[0].ish,
                              ElemCount(colortable), ElemSize(colortable), (BSearchFncCast)strcmp)) != NULL) {
            p -= sizeof(colortable[0].name);
            blend = 0.25;
        }
        else
            return 0;

        h1 = ((colrname *)p) -> hue;
        l1 = ((colrname *)p) -> lgt / 100.0;
        s1 = ((colrname *)p) -> sat / 100.0;
        buf += strlen(buf) + 1;
    }

    /* process second (or only) name word */
    p = bsearch(buf, colortable[0].name,
                ElemCount(colortable), ElemSize(colortable), (BSearchFncCast)strcmp);
    if (!p || buf + strlen(buf) < ebuf)
        return 0;
    h2 = ((colrname *)p) -> hue;
    l2 = ((colrname *)p) -> lgt / 100.0;
    s2 = ((colrname *)p) -> sat / 100.0;

    /* at this point we know we have a valid spec */

    /* interpolate hls specs */
    if (blend > 0) {
        bl2 = 1.0 - blend;
   
        if (s1 == 0.0)
            ; /* use h2 unchanged */
        else if (s2 == 0.0)
            h2 = h1;
        else if (h2 - h1 > 180)
            h2 = blend * h1 + bl2 * (h2 - 360);
        else if (h1 - h2 > 180)
            h2 = blend * (h1 - 360) + bl2 * h2;
        else
            h2 = blend * h1 + bl2 * h2;
        if (h2 < 0)
            h2 += 360;
   
        l2 = blend * l1 + bl2 * l2;
        s2 = blend * s1 + bl2 * s2;
    }

    /* apply saturation and lightness modifiers */
    if (lgt >= 0.0) {
        if (very)
            l2 = (2 * lgt + l2) / 3.0;
        else
            l2 = (lgt + 2 * l2) / 3.0;
    }
    s2 *= sat;

    /* convert h2,l2,s2 to r2,g2,b2 */
    /* from Foley & Van Dam, 1st edition, p. 619 */
    /* beware of dangerous typos in 2nd edition */
    if (s2 == 0)
        r2 = g2 = b2 = l2;
    else {
        if (l2 < 0.5)
            m2 = l2 * (1 + s2);
        else
            m2 = l2 + s2 - l2 * s2;
        m1 = 2 * l2 - m2;
        r2 = rgbval(m1, m2, h2 + 120);
        g2 = rgbval(m1, m2, h2);
        b2 = rgbval(m1, m2, h2 - 120);
    }

    /* scale and convert the calculated result */
    *r = 65535 * r2;
    *g = 65535 * g2;
    *b = 65535 * b2;

    return 1;
}

/*
 * rgbval(n1, n2, hue) - helper function for HLS to RGB conversion
 */
static double rgbval(double n1, double n2, double hue)
{
    if (hue > 360)
        hue -= 360;
    else if (hue < 0)
        hue += 360;

    if (hue < 60)
        return n1 + (n2 - n1) * hue / 60.0;
    else if (hue < 180)
        return n2;
    else if (hue < 240)
        return n1 + (n2 - n1) * (240 - hue) / 60.0;
    else
        return n1;
}

int initimgmem(wbp w, struct imgmem *i, int copy, int clip, int x, int y, int width, int height)
{
    wcp wc = w->context;
    wsp ws = w->window;
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
        return 0;

    if (clip && wc->clipw >= 0) {
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
            return 0;
    }

    i->x = x;
    i->y = y;
    i->width = width;
    i->height = height;
    loadimgmem(w, i, copy);
    return 1;
}

int gotopixel(struct imgmem *imem, int x, int y)
{
    if (x >= imem->x && x < imem->x + imem->width &&
        y >= imem->y && y < imem->y + imem->height) {
        imem->xoff = x - imem->x;
        imem->yoff = y - imem->y;
        return 1;
    } else
        return 0;
}

void freeimgdata(struct imgdata *imd)
{
    free(imd->paltbl);
    imd->paltbl = 0;
    free(imd->data);
    imd->data = 0;
    imd->format = imd->height = imd->width = 0;
}

#begdef DrawOpaqueStart(func, size)
static void func(wbp w, int x, int y, int width, int height, unsigned char *s);

static void func(wbp w, int x, int y, int width, int height, unsigned char *s)
{
    struct imgmem imem;
    int i, j;

    if (!initimgmem(w, &imem, 0, 1, x, y, width, height))
        return;

    for (j = y; j < y + height; j++) {
        for (i = x; i < x + width; i++) {
            if (!gotopixel(&imem, i, j)) 
                s += size;
            else {
                int r, g, b;
#enddef
#begdef DrawOpaqueEnd()
                setpixel(&imem, r, g, b);
            }
        }
    }
    saveimgmem(w, &imem);
    freeimgmem(&imem);
}
#enddef

#begdef DrawAlphaStart(func, size)
static void func(wbp w, int x, int y, int width, int height, unsigned char *s);

static void func(wbp w, int x, int y, int width, int height, unsigned char *s)
{
    struct imgmem imem;
    int i, j;

    if (!initimgmem(w, &imem, 1, 1, x, y, width, height))
        return;

    for (j = y; j < y + height; j++) {
        for (i = x; i < x + width; i++) {
            if (!gotopixel(&imem, i, j)) 
                s += size;
            else {
                int r, g, b, a;
#enddef

#begdef DrawAlphaEnd()
                if (a) {
                    if (a != 65535) {
                        int r1, g1, b1;
                        getpixel(&imem, &r1, &g1, &b1);
                        r = CombineAlpha(r, r1, a);
                        g = CombineAlpha(g, g1, a);
                        b = CombineAlpha(b, b1, a);
                    }
                    setpixel(&imem, r, g, b);
                }
            }
        }
    }
    saveimgmem(w, &imem);
    freeimgmem(&imem);
}
#enddef

DrawAlphaStart(drawga16,2)
   r = g = b = 257 * (*s++);
   a = 257 * (*s++);
DrawAlphaEnd()

DrawAlphaStart(drawag16,2)
   a = 257 * (*s++);
   r = g = b = 257 * (*s++);
DrawAlphaEnd()

DrawAlphaStart(drawga32,4)
    r = *s++;
    r = r<<8|*s++;
    g = b = r;
    a = *s++;
    a = a<<8|*s++;
DrawAlphaEnd()

DrawAlphaStart(drawrgba32,4)
    r = 257 * (*s++);
    g = 257 * (*s++);
    b = 257 * (*s++);
    a = 257 * (*s++);
DrawAlphaEnd()

DrawAlphaStart(drawabgr32,4)
    a = 257 * (*s++);
    b = 257 * (*s++);
    g = 257 * (*s++);
    r = 257 * (*s++);
DrawAlphaEnd()

DrawAlphaStart(drawrgba64,8)
    r = *s++;
    r = r<<8|*s++;
    g = *s++;
    g = g<<8|*s++;
    b = *s++;
    b = b<<8|*s++;
    a = *s++;
    a = a<<8|*s++;
DrawAlphaEnd()

DrawOpaqueStart(drawrgb48,6)
    r = *s++;
    r = r<<8|*s++;
    g = *s++;
    g = g<<8|*s++;
    b = *s++;
    b = b<<8|*s++;
DrawOpaqueEnd()

DrawOpaqueStart(drawrgb24,3)
    r = 257 * (*s++);
    g = 257 * (*s++);
    b = 257 * (*s++);
DrawOpaqueEnd()

DrawOpaqueStart(drawbgr24,3)
    b = 257 * (*s++);
    g = 257 * (*s++);
    r = 257 * (*s++);
DrawOpaqueEnd()

DrawOpaqueStart(drawg8,1)
    r = g = b = 257 * (*s++);
DrawOpaqueEnd()

DrawOpaqueStart(drawg16,2)
    r = *s++;
    r = r<<8|*s++;
    g = b = r;
DrawOpaqueEnd()

void drawimgdata(wbp w, int x, int y, struct imgdata *imd)
{
    switch (imd->format) {
        case IMGDATA_PALETTE_OPAQUE:
            drawpalette(w, x, y, imd->width, imd->height, imd->paltbl, imd->data, 0);
            break;
        case IMGDATA_PALETTE_TRANS:
            drawpalette(w, x, y, imd->width, imd->height, imd->paltbl, imd->data, 1);
            break; 
       case IMGDATA_RGB24:
            drawrgb24(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_BGR24:
            drawbgr24(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_RGBA32:
            drawrgba32(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_ABGR32:
            drawabgr32(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_RGB48:
            drawrgb48(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_RGBA64:
            drawrgba64(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_G8:
            drawg8(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_GA16:
            drawga16(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_AG16:
            drawag16(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_G16:
            drawg16(w, x, y, imd->width, imd->height, imd->data);
            break;
        case IMGDATA_GA32:
            drawga32(w, x, y, imd->width, imd->height, imd->data);
            break;
        default:
            syserr("Unknown image format");
            break;
    }
}

static void drawpalette(wbp w, int x, int y, int width, int height, 
                        struct palentry *e, unsigned char *s, int copy)
{
    struct imgmem imem;
    int i, j;

    if (!initimgmem(w, &imem, copy, 1, x, y, width, height))
        return;

    for (j = y; j < y + height; j++) {
        for (i = x; i < x + width; i++) {
            struct palentry *pe = &e[*s];
            if (!pe->transpt && gotopixel(&imem, i, j))
                setpixel(&imem, pe->r, pe->g, pe->b);
            ++s;
        }
    }
    saveimgmem(w, &imem);
    freeimgmem(&imem);
}

void drawblimage(wbp w, int x, int y, int width, int height,
                int ch, unsigned char *s)
{
    unsigned int m, msk1, c, ix, iy;
    int slen = height*((width + 3)/4);
    int fg_r, fg_g, fg_b, bg_r, bg_g, bg_b;
    struct imgmem imem;

    getfg_rgb(w, &fg_r, &fg_g, &fg_b);
    getbg_rgb(w, &bg_r, &bg_g, &bg_b);

    if (!initimgmem(w, &imem, ch == TCH1, 1, x, y, width, height))
        return;

    m = width % 4;
    if (m == 0)
        msk1 = 8;
    else
        msk1 = 1 << (m - 1);              /* mask for first byte of row */

    ix = width;
    iy = 0;
    m = msk1;
    while (slen--) {
        if (isxdigit((unsigned char)(c = *s++))) {         /* if hexadecimal character */
            if (!isdigit((unsigned char)c))               /* fix bottom 4 bits if necessary */
                c += 9;
            while (m > 0) {                /* set (usually) 4 pixel values */
                --ix;
                if (gotopixel(&imem, x + ix, y + iy)) {
                    if (c & m) {
                        setpixel(&imem, fg_r, fg_g, fg_b);
                    }
                    else if (ch != TCH1) {      /* if zeroes aren't transparent */
                        setpixel(&imem, bg_r, bg_g, bg_b);
                    }
                }
                m >>= 1;
	    }
            if (ix == 0) {                 /* if end of row */
                ix = width;
                iy++;
                m = msk1;
	    }
            else
                m = 8;
        }
    }
    if (ix > 0) {                         /* pad final row if incomplete */
        while (ix < width) {
            if (gotopixel(&imem, x + ix, y + iy)) {
                setpixel(&imem, bg_r, bg_g, bg_b);
            }
            ix++;
        }
    }

    saveimgmem(w, &imem);
    freeimgmem(&imem);
}

/*
 *  Functions and data for reading and writing GIF and JPEG images
 */

#define GifSeparator	0x2C	/* (',') beginning of image */
#define GifTerminator	0x3B	/* (';') end of image */
#define GifExtension	0x21	/* ('!') extension block */
#define GifControlExt	0xF9	/*       graphic control extension label */
#define GifEmpty	-1	/* internal flag indicating no prefix */

#define GifTableSize	4096	/* maximum number of entries in table */
#define GifBlockSize	255	/* size of output block */

typedef struct lzwnode {	/* structure of LZW encoding tree node */
    unsigned short tcode;		/* token code */
    unsigned short child;	/* first child node */
    unsigned short sibling;	/* next sibling */
} lzwnode;

#ifdef HAVE_LIBJPEG
struct my_error_mgr { /* a part of JPEG error handling */
    struct jpeg_error_mgr pub;	/* "public" fields */
    jmp_buf setjmp_buffer;	/* for return to caller */
};

typedef struct my_error_mgr * my_error_ptr; /* a part of error handling */
#endif					/* HAVE_LIBJPEG */

static	int	gfread		(FILE *f);
static	int	gfheader	(FILE *f);
static	int	gfskip		(FILE *f);
static	void	gfcontrol	(FILE *f);
static	int	gfimhdr		(FILE *f);
static	int	gfmap		(FILE *f);
static	int	gfsetup		(void);
static	int	gfrdata		(FILE *f);
static	int	gfrcode		(FILE *f);
static	void	gfinsert	(int prev, int c);
static	int	gffirst		(int c);
static	void	gfgen		(int c);
static	void	gfput		(int b);

static int gf_gcmap, gf_lcmap;		/* global color map? local color map? */
static int gf_nbits;			/* number of bits per pixel */
static int gf_ilace;			/* interlace flag */
static int gf_width, gf_height;		/* image size */

static short *gf_prefix, *gf_suffix;	/* prefix and suffix tables */
static int gf_free;			/* next free position */
static int gf_format;			/* imgdata format */

static struct palentry *gf_paltbl;	/* palette table */
static unsigned char *gf_string;	/* image string */
static unsigned char *gf_nxt, *gf_lim;	/* store pointer and its limit */
static int gf_row, gf_step;		/* current row and step size */

static int gf_cdsize;			/* code size */
static int gf_clear, gf_eoi;		/* values of CLEAR and EOI codes */
static int gf_lzwbits, gf_lzwmask;	/* current bits per code */

static unsigned long gf_curr;		/* current partial byte(s) */
static int gf_valid;			/* number of valid bits */
static int gf_rem;			/* remaining bytes in this block */

/*
 * readGIF(filename, imd) - read GIF file into image data structure
 *
 * p is a palette number to which the GIF colors are to be coerced;
 * p=0 uses the colors exactly as given in the GIF file.
 */
static int readGIF(char *filename, struct imgdata *imd)
{
    int r;
    FILE *fp;

    if ((fp = fopen(filename, "rb")) == NULL) {
        errno2why();
        return Failed;
    }

    r = gfread(fp);			/* read image */
    fclose(fp);

    if (gf_prefix) {
        free(gf_prefix);
        gf_prefix = NULL;
    }
    if (gf_suffix) {
        free(gf_suffix);
        gf_suffix = NULL;
    }

    if (!r) {			/* if no success, free mem */
        if (gf_paltbl) {
            free(gf_paltbl);
            gf_paltbl = NULL;
        }
        if (gf_string) {
            free(gf_string);
            gf_string = NULL;
        }
        return Failed;
    }

    imd->width = gf_width;			/* set return variables */
    imd->height = gf_height;
    imd->paltbl = gf_paltbl;
    imd->data = gf_string;
    imd->format = gf_format;

    return Succeeded;				/* return success */
}

/*
 * gfread(filename, p) - read GIF file, setting gf_ globals
 */
static int gfread(FILE *fp)
{
    int i;

    gf_prefix = NULL;
    gf_suffix = NULL;
    gf_string = NULL;
    gf_format = IMGDATA_PALETTE_OPAQUE;

    MemProtect(gf_paltbl = malloc(256 * sizeof(struct palentry)));

    for (i = 0; i < 256; i++)		/* init palette table */
        gf_paltbl[i].valid = gf_paltbl[i].transpt = 0;

    if (!gfheader(fp))			/* read file header */
        return 0;
    if (gf_gcmap)			/* read global color map, if any */
        if (!gfmap(fp))
            return 0;
    if (!gfskip(fp))			/* skip to start of image */
        return 0;
    if (!gfimhdr(fp))			/* read image header */
        return 0;
    if (gf_lcmap)			/* read local color map, if any */
        if (!gfmap(fp))
            return 0;
    if (!gfsetup())			/* prepare to read image */
        return 0;
    if (!gfrdata(fp))			/* read image data */
        return 0;
    while (gf_row < gf_height)		/* pad if too short */
        gfput(0);

    return 1;
}

/*
 * gfheader(f) - read GIF file header; return nonzero if successful
 */
static int gfheader(FILE *f)
{
    unsigned char hdr[13];		/* size of a GIF header */
    int b;

    if (fread((char *)hdr, sizeof(char), sizeof(hdr), f) != sizeof(hdr))
        return 0;				/* header short or missing */
    if (strncmp((char *)hdr, "GIF", 3) != 0 ||
        !isdigit((unsigned char)hdr[3]) || !isdigit((unsigned char)hdr[4]))
        return 0;				/* not GIFnn */

    b = hdr[10];				/* flag byte */
    gf_gcmap = b & 0x80;			/* global color map flag */
    gf_nbits = (b & 7) + 1;		/* number of bits per pixel */
    return 1;
}

/*
 * gfskip(f) - skip intermediate blocks and locate image
 */
static int gfskip(FILE *f)
{
    int c, n;

    while ((c = getc(f)) != GifSeparator) { /* look for start-of-image flag */
        if (c == EOF)
            return 0;
        if (c == GifExtension) {		/* if extension block is present */
            c = getc(f);				/* get label */
            if ((c & 0xFF) == GifControlExt)
                gfcontrol(f);			/* process control subblock */
            while ((n = getc(f)) != 0) {		/* read blks until empty one */
                if (n == EOF)
                    return 0;
                n &= 0xFF;				/* ensure positive count */
                while (n--)				/* skip block contents */
                    getc(f);
            }
        }
    }
    return 1;
}

/*
 * gfcontrol(f) - process control extension subblock
 */
static void gfcontrol(FILE *f)
{
    int i, n, c, t;

    n = getc(f) & 0xFF;				/* subblock length (s/b 4) */
    for (i = t = 0; i < n; i++) {
        c = getc(f) & 0xFF;
        if (i == 0)
            t = c & 1;				/* transparency flag */
        else if (i == 3 && t != 0) {
            gf_paltbl[c].transpt = 1;		/* set flag for transpt color */
            gf_paltbl[c].valid = 0;		/* color is no longer "valid" */
            gf_format = IMGDATA_PALETTE_TRANS;  /* change the format to indicate transparency */
        }
    }
}

/*
 * gfimhdr(f) - read image header
 */
static int gfimhdr(FILE *f)
{
    unsigned char hdr[9];		/* size of image hdr excl separator */
    int b;

    if (fread((char *)hdr, sizeof(char), sizeof(hdr), f) != sizeof(hdr))
        return 0;				/* header short or missing */
    gf_width = hdr[4] + 256 * hdr[5];
    gf_height = hdr[6] + 256 * hdr[7];
    b = hdr[8];				/* flag byte */
    gf_lcmap = b & 0x80;			/* local color map flag */
    gf_ilace = b & 0x40;			/* interlace flag */
    if (gf_lcmap)
        gf_nbits = (b & 7) + 1;		/* if local map, reset nbits also */
    return 1;
}

/*
 * gfmap(f, p) - read GIF color map into paltbl
 */
static int gfmap(FILE *f)
{
    int ncolors, i, r, g, b;

    ncolors = 1 << gf_nbits;

    for (i = 0; i < ncolors; i++) {
        r = getc(f);
        g = getc(f);
        b = getc(f);
        if (r == EOF || g == EOF || b == EOF)
            return 0;
        gf_paltbl[i].r   = 257 * r;	/* 257 * 255 -> 65535 */
        gf_paltbl[i].g = 257 * g;
        gf_paltbl[i].b  = 257 * b;
        if (!gf_paltbl[i].transpt)		/* if not transparent color */
            gf_paltbl[i].valid = 1;		/* mark as valid/opaque */
    }

    return 1;
}

/*
 * gfsetup() - prepare to read GIF data
 */
static int gfsetup()
{
    int i;
    word len;

    len = gf_width * gf_height;
    MemProtect(gf_string = malloc(len));
    MemProtect(gf_prefix = malloc(GifTableSize * sizeof(short)));
    MemProtect(gf_suffix = malloc(GifTableSize * sizeof(short)));
    for (i = 0; i < GifTableSize; i++) {
        gf_prefix[i] = GifEmpty;
        gf_suffix[i] = i;
    }

    gf_row = 0;				/* current row is 0 */
    gf_nxt = gf_string;			/* set store pointer */

    if (gf_ilace) {			/* if interlaced */
        gf_step = 8;			/* step rows by 8 */
        gf_lim = gf_string + gf_width;	/* stop at end of one row */
    }
    else {
        gf_lim = gf_string + len;		/* do whole image at once */
        gf_step = gf_height;		/* step to end when full */
    }

    return 1;
}

/*
 * gfrdata(f) - read GIF data
 */
static int gfrdata(FILE *f)
{
    int curr, prev, c;

    if ((gf_cdsize = getc(f)) == EOF)
        return 0;
    gf_clear = 1 << gf_cdsize;
    gf_eoi = gf_clear + 1;
    gf_free = gf_eoi + 1;

    gf_lzwbits = gf_cdsize + 1;
    gf_lzwmask = (1 << gf_lzwbits) - 1;

    gf_curr = 0;
    gf_valid = 0;
    gf_rem = 0;

    prev = curr = gfrcode(f);
    while (curr != gf_eoi) {
        if (curr == gf_clear) {		/* if reset code */
            gf_lzwbits = gf_cdsize + 1;
            gf_lzwmask = (1 << gf_lzwbits) - 1;
            gf_free = gf_eoi + 1;
            prev = curr = gfrcode(f);
            gfgen(curr);
        }
        else if (curr < gf_free) {	/* if code is in table */
            gfgen(curr);
            gfinsert(prev, gffirst(curr));
            prev = curr;
        }
        else if (curr == gf_free) {	/* not yet in table */
            c = gffirst(prev);
            gfgen(prev);
            gfput(c);
            gfinsert(prev, c);
            prev = curr;
        }
        else {				/* illegal code */
            if (gf_nxt == gf_lim)
                return 1;			/* assume just extra stuff after end */
            else
                return 0;			/* more badly confused */
        }
        curr = gfrcode(f);
    }

    return 1;
}

/*
 * gfrcode(f) - read next LZW code
 */
static int gfrcode(FILE *f)
{
    int c, r;

    while (gf_valid < gf_lzwbits) {
        if (--gf_rem <= 0) {
            if ((gf_rem = getc(f)) == EOF)
                return gf_eoi;
        }
        if ((c = getc(f)) == EOF)
            return gf_eoi;
        gf_curr |= ((c & 0xFF) << gf_valid);
        gf_valid += 8;
    }
    r = gf_curr & gf_lzwmask;
    gf_curr >>= gf_lzwbits;
    gf_valid -= gf_lzwbits;
    return r;
}

/*
 * gfinsert(prev, c) - insert into table
 */
static void gfinsert(int prev, int c)
{

    if (gf_free >= GifTableSize)		/* sanity check */
        return;

    gf_prefix[gf_free] = prev;
    gf_suffix[gf_free] = c;

    /* increase code size if code bits are exhausted, up to max of 12 bits */
    if (++gf_free > gf_lzwmask && gf_lzwbits < 12) {
        gf_lzwmask = gf_lzwmask * 2 + 1;
        gf_lzwbits++;
    }

}

/*
 * gffirst(c) - return the first pixel in a map structure
 */
static int gffirst(int c)
{
    int d;

    if (c >= gf_free)
        return 0;				/* not in table (error) */
    while ((d = gf_prefix[c]) != GifEmpty)
        c = d;
    return gf_suffix[c];
}

/*
 * gfgen(c) - generate and output prefix
 */
static void gfgen(int c)
{
    int d;

    if ((d = gf_prefix[c]) != GifEmpty)
        gfgen(d);
    gfput(gf_suffix[c]);
}

/*
 * gfput(b) - add a byte to the output string
 */
static void gfput(int b)
{
    if (gf_nxt >= gf_lim) {		/* if current row is full */
        gf_row += gf_step;
        while (gf_row >= gf_height && gf_ilace && gf_step > 2) {
            if (gf_step == 4) {
                gf_row = 1;
                gf_step = 2;
            }
            else if ((gf_row % 8) != 0) {
                gf_row = 2;
                gf_step = 4;
            }
            else {
                gf_row = 4;
                /* gf_step remains 8 */
	    }
        }

        if (gf_row >= gf_height) {
            gf_step = 0;
            return;			/* too much data; ignore it */
        }
        gf_nxt = gf_string + ((word)gf_row * (word)gf_width);
        gf_lim = gf_nxt + gf_width;
    }

    *gf_nxt++ = b;			/* store byte */
}


#ifdef HAVE_LIBJPEG
/*
 * readJPEG(filename, p, imd) - read JPEG file into image data structure
 * p is a palette number to which the JPEG colors are to be coerced;
 * p=0 uses the rgb data from the image, with no palette.
 */

void my_error_exit (j_common_ptr cinfo);


static int readJPEG(char *filename, struct imgdata *imd)
{
    struct jpeg_decompress_struct cinfo; /* libjpeg struct */
    struct my_error_mgr jerr;
    int row_stride;
    unsigned char *data = 0;
    FILE *fp;

    fp = fopen(filename, "rb");
    if (!fp) {
        errno2why();
        return Failed;
    }

    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = my_error_exit;

    if (setjmp(jerr.setjmp_buffer)) {
        jpeg_destroy_decompress(&cinfo);
        if (data) free(data);
        fclose(fp);
        whyf("readJPEG: Failed to read file %s", filename);
        return Failed;
    }

    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, fp);
    jpeg_read_header(&cinfo, TRUE);

    /*
     * set parameters for decompression
     */
    cinfo.quantize_colors = FALSE;

    /* Start decompression */

    jpeg_start_decompress(&cinfo);
    row_stride = cinfo.output_width * cinfo.output_components; /* actual width of the image */

    MemProtect(data = malloc(row_stride * cinfo.output_height));
	
    while (cinfo.output_scanline < cinfo.image_height) {
        JSAMPROW row_pointer[1];
        row_pointer[0] = &data[cinfo.output_scanline * row_stride];
        jpeg_read_scanlines(&cinfo, row_pointer, 1);
    }


    jpeg_finish_decompress(&cinfo);

    /*
     * Release JPEG decompression object
     */
    jpeg_destroy_decompress(&cinfo);

    fclose(fp);

    imd->width = cinfo.output_width;
    imd->height = cinfo.output_height;
    imd->paltbl = 0;
    imd->data = data;
    imd->format = IMGDATA_RGB24;
    return Succeeded;
}


/* a part of error handling */
void my_error_exit (j_common_ptr cinfo)
{
    my_error_ptr myerr = (my_error_ptr) cinfo->err;
    (*cinfo->err->output_message) (cinfo);
    longjmp(myerr->setjmp_buffer, 1);
}


int writeJPEG(wbp w, char *filename, int x, int y, int width,int height)
{
    struct imgmem imem;
    int i, j;
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    int row_stride;		/* physical row width in image buffer */
    int quality;
    FILE *fp;
    unsigned char *data;

    fp = fopen(filename, "wb");
    if (!fp) {
        errno2why();
        return Failed;
    }

    MemProtect(data = malloc(width * height * 3));

    quality = 95;
    
    if (initimgmem(w, &imem, 1, 0, x, y, width, height)) {
        unsigned char *p = data;
        for (j = y; j < y + height; j++) {
            for (i = x; i < x + width; i++) {
                if (gotopixel(&imem, i, j)) {
                    int r, g, b;
                    getpixel(&imem, &r, &g, &b);
                    *p++ = r / 256;
                    *p++ = g / 256;
                    *p++ = b / 256;
                } else {
                    *p++ = 0;
                    *p++ = 0;
                    *p++ = 0;
                }
            }
        }
        freeimgmem(&imem);
    } else
        memset(data, 0, width * height * 3);

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);

    jpeg_stdio_dest(&cinfo, fp);

    cinfo.image_width = width; 	/* image width and height, in pixels */
    cinfo.image_height = height;

    cinfo.input_components = 3;	/* # of color components per pixel */
    cinfo.in_color_space = JCS_RGB; /* colorspace of input image */

    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE /*limit to baseline-JPEG values */);

    jpeg_start_compress(&cinfo, TRUE);

    row_stride = cinfo.image_width * 3;	/* JSAMPLEs per row in image_buffer */

    while (cinfo.next_scanline < cinfo.image_height) {
        JSAMPROW row_pointer[1];     
        row_pointer[0] = &data[cinfo.next_scanline * row_stride];
        jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }

    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);

    free(data);
    fclose(fp);

    return Succeeded;
}

#endif

#ifdef HAVE_LIBPNG

static int readPNG(char *filename, struct imgdata *imd)
{
    png_structp png_ptr;
    png_infop info_ptr;
    png_byte header[8];	/* 8 is the maximum size that can be checked */
    int width, height, i;
    png_bytep *row_pointers = 0, p;
    unsigned char *data = 0;
    int format;
    FILE *fp;
    double image_gamma;

    /* open file and test for it being a png */
    fp = fopen(filename, "rb");
    if (!fp) {
        errno2why();
        return Failed;
    }
    if (fread(header, 1, 8, fp) != 8) {
        errno2why();
        fclose(fp);
        return Failed;
    }

    if (png_sig_cmp(header, 0, 8)) {
        fclose(fp);
        whyf("readPNG: File %s is not recognized as a PNG file", filename);
        return Failed;
    }

    MemProtect(png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL));
    MemProtect(info_ptr = png_create_info_struct(png_ptr));

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, 0);
        if (row_pointers) free(row_pointers);
        if (data) free(data);
        fclose(fp);
        whyf("readPNG: Failed to read file %s", filename);
        return Failed;
    }

    png_init_io(png_ptr, fp);

    png_set_sig_bytes(png_ptr, 8);
    png_read_info(png_ptr, info_ptr);

    /* 
     * Gamma correction using a screen gamma of 2.2.
     */
    if (png_get_gAMA(png_ptr, info_ptr, &image_gamma))
        png_set_gamma(png_ptr, 2.2, image_gamma);
    if (info_ptr->color_type == PNG_COLOR_TYPE_PALETTE)
        png_set_palette_to_rgb(png_ptr);
    if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY && info_ptr->bit_depth < 8) 
        png_set_gray_1_2_4_to_8(png_ptr);
    if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
        png_set_tRNS_to_alpha(png_ptr);

    png_read_update_info(png_ptr, info_ptr);

    if (info_ptr->color_type == PNG_COLOR_TYPE_RGB && info_ptr->pixel_depth == 24)
        format = IMGDATA_RGB24;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_RGB && info_ptr->pixel_depth == 48)
        format = IMGDATA_RGB48;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA && info_ptr->pixel_depth == 32)
        format = IMGDATA_RGBA32;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_RGB_ALPHA && info_ptr->pixel_depth == 64)
        format = IMGDATA_RGBA64;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY && info_ptr->pixel_depth == 8)
        format = IMGDATA_G8;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY_ALPHA && info_ptr->pixel_depth == 16)
        format = IMGDATA_GA16;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY && info_ptr->pixel_depth == 16)
        format = IMGDATA_G16;
    else if (info_ptr->color_type == PNG_COLOR_TYPE_GRAY_ALPHA && info_ptr->pixel_depth == 32)
        format = IMGDATA_GA32;
    else {
        fclose(fp);
        png_destroy_read_struct(&png_ptr, &info_ptr, 0);
        whyf("readPNG: File %s, unsupported format/depth", filename);
        return Failed;
    }

    width = info_ptr->width;
    height = info_ptr->height;

    MemProtect(row_pointers = malloc(sizeof(png_bytep) * height));
    MemProtect(data = malloc(info_ptr->rowbytes * height));
    p = (png_bytep)data;
    for (i = 0; i < height; ++i) {
        row_pointers[i] = p;
        p += info_ptr->rowbytes;
    }
    png_read_image(png_ptr, row_pointers);
    png_read_end(png_ptr, 0);
    png_destroy_read_struct(&png_ptr, &info_ptr, 0);
    free(row_pointers);
    fclose(fp);

    imd->width = width;
    imd->height = height;
    imd->paltbl = 0;
    imd->data = data;
    imd->format = format;

    return Succeeded;
}


static int writePNG(wbp w, char *filename, int x, int y, int width, int height)
{
    FILE *fp;
    png_structp png_ptr;
    png_infop info_ptr;
    png_bytep *row_pointers = 0, p;
    unsigned char *data = 0;
    int i, j;
    struct imgmem imem;

    fp = fopen(filename, "wb");
    if (!fp) {
        errno2why();
        return Failed;
    }

    MemProtect(png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL));
    MemProtect(info_ptr = png_create_info_struct(png_ptr));

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        if (row_pointers) free(row_pointers);
        if (data) free(data);
        fclose(fp);
        LitWhy("readPNG: libpng failed to write image");
        return Failed;
    }

    png_init_io(png_ptr, fp);
    png_set_IHDR(png_ptr, info_ptr, width, height,
                 16, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
    png_write_info(png_ptr, info_ptr);

    MemProtect(row_pointers = malloc(sizeof(png_bytep) * height));
    MemProtect(data = malloc(width * height * 6));
    p = (png_bytep)data;
    for (i = 0; i < height; ++i) {
        row_pointers[i] = p;
        p += 6 * width;
    }

    if (initimgmem(w, &imem, 1, 0, x, y, width, height)) {
        p = (png_bytep)data;
        for (j = y; j < y + height; j++) {
            for (i = x; i < x + width; i++) {
                if (gotopixel(&imem, i, j)) {
                    int r, g, b;
                    getpixel(&imem, &r, &g, &b);
                    *p++ = (r>>8) & 0xff;
                    *p++ = r & 0xff;
                    *p++ = (g>>8) & 0xff;
                    *p++ = g & 0xff;
                    *p++ = (b>>8) & 0xff;
                    *p++ = b & 0xff;
                } else {
                    *p++ = 0;
                    *p++ = 0;
                    *p++ = 0;
                    *p++ = 0;
                    *p++ = 0;
                    *p++ = 0;
                }
            }
        }
        freeimgmem(&imem);
    } else
        memset(data, 0, width * height * 6);

    png_write_image(png_ptr, row_pointers);
    png_write_end(png_ptr, 0);
    png_destroy_write_struct(&png_ptr, &info_ptr);

    free(row_pointers);
    free(data);
    fclose(fp);

    return Succeeded;
}

#endif

/*
 * Static data for XDrawImage and XPalette functions
 */

/*
 * c<n>list - the characters of the palettes that are not contiguous ASCII
 */
char c1list[] = "0123456789?!nNAa#@oOBb$%pPCc&|\
qQDd,.rREe;:sSFf+-tTGg*/uUHh`'vVIi<>wWJj()xXKk[]yYLl{}zZMm^=";
char c2list[] = "kbgcrmywx";
char c3list[] = "@ABCDEFGHIJKLMNOPQRSTUVWXYZabcd";
char c4list[] =
    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz{}$%&*+-/?@";

/*
 * cgrays -- lists of grayscales contained within color palettes
 */
static char *cgrays[] = { "0123456", "kxw", "@abMcdZ", "0$%&L*+-g/?@}",
                          "\0}~\177\200\37\201\202\203\204>\205\206\207\210]\211\212\213\214|",
                          "\0\330\331\332\333\334+\335\336\337\340\341V\342\343\344\345\346\201\
\347\350\351\352\353\254\354\355\356\357\360\327" };

/*
 * c1cube - a precomputed mapping from a color cube to chars in c1 palette
 *
 * This is 10x10x10 cube (A Thousand Points of Light).
 */
#define C1Side 10  			/* length of one side of C1 cube */
static char c1cube[] = {
    '0', '0', 'w', 'w', 'w', 'W', 'W', 'W', 'J', 'J', '0', '0', 'v', 'v', 'v',
    'W', 'W', 'W', 'J', 'J', 's', 't', 't', 'v', 'v', 'V', 'V', 'V', 'V', 'J',
    's', 't', 't', 'u', 'u', 'V', 'V', 'V', 'V', 'I', 's', 't', 't', 'u', 'u',
    'V', 'V', 'V', 'I', 'I', 'S', 'S', 'T', 'T', 'T', 'U', 'U', 'U', 'I', 'I',
    'S', 'S', 'T', 'T', 'T', 'U', 'U', 'U', 'U', 'I', 'S', 'S', 'T', 'T', 'T',
    'U', 'U', 'U', 'U', 'H', 'F', 'F', 'T', 'T', 'G', 'G', 'U', 'U', 'H', 'H',
    'F', 'F', 'F', 'G', 'G', 'G', 'G', 'H', 'H', 'H', '0', '0', 'x', 'x', 'x',
    'W', 'W', 'W', 'J', 'J', '!', '1', '1', 'v', 'v', 'W', 'W', 'W', 'J', 'J',
    'r', '1', '1', 'v', 'v', 'V', 'V', 'V', 'j', 'j', 'r', 'r', 't', 'u', 'u',
    'V', 'V', 'V', 'j', 'j', 'r', 'r', 't', 'u', 'u', 'V', 'V', 'V', 'I', 'I',
    'S', 'S', 'T', 'T', 'T', 'U', 'U', 'U', 'I', 'I', 'S', 'S', 'T', 'T', 'T',
    'U', 'U', 'U', 'i', 'i', 'S', 'S', 'T', 'T', 'T', 'U', 'U', 'U', 'i', 'i',
    'F', 'F', 'f', 'f', 'G', 'G', 'g', 'g', 'H', 'H', 'F', 'F', 'f', 'f', 'G',
    'G', 'g', 'g', 'H', 'H', 'n', 'z', 'x', 'x', 'x', 'X', 'X', 'X', 'X', 'J',
    '!', '1', '1', 'x', 'x', 'X', 'X', 'X', 'j', 'j', 'p', '1', '1', '2', '2',
    ')', 'V', 'j', 'j', 'j', 'r', 'r', '2', '2', '2', ')', 'V', 'j', 'j', 'j',
    'r', 'r', '2', '2', '2', '>', '>', '>', 'j', 'j', 'R', 'R', '-', '-', '/',
    '/', '>', '>', 'i', 'i', 'R', 'R', 'R', 'T', '/', '/', '\'','i', 'i', 'i',
    'R', 'R', 'f', 'f', '/', '/', 'g', 'g', 'i', 'i', 'R', 'f', 'f', 'f', 'f',
    'g', 'g', 'g', 'h', 'h', 'F', 'f', 'f', 'f', 'f', 'g', 'g', 'g', 'h', 'h',
    'n', 'z', 'z', 'y', 'y', 'X', 'X', 'X', 'X', 'K', 'o', 'o', 'z', 'y', 'y',
    'X', 'X', 'X', 'j', 'j', 'p', 'p', '2', '2', '2', ')', 'X', 'j', 'j', 'j',
    'q', 'q', '2', '2', '2', ')', ')', 'j', 'j', 'j', 'q', 'q', '2', '2', '2',
    '>', '>', '>', 'j', 'j', 'R', 'R', '-', '-', '/', '/', '>', '>', 'i', 'i',
    'R', 'R', 'R', '-', '/', '/', '\'','\'','i', 'i', 'R', 'R', 'f', 'f', '/',
    '/', '\'','g', 'i', 'i', 'R', 'f', 'f', 'f', 'f', 'g', 'g', 'g', 'h', 'h',
    'E', 'f', 'f', 'f', 'f', 'g', 'g', 'g', 'h', 'h', 'n', 'z', 'z', 'y', 'y',
    'X', 'X', 'X', 'K', 'K', 'o', 'o', 'z', 'y', 'y', 'X', 'X', 'X', 'K', 'K',
    '?', '?', '?', '2', '2', ']', ']', ']', 'j', 'j', 'q', 'q', '2', '2', '2',
    ']', ']', ']', 'j', 'j', 'q', 'q', '2', '2', '3', '3', '>', '>', 'j', 'j',
    'R', 'R', ':', ':', '3', '3', '>', '>', 'i', 'i', 'R', 'R', ':', ':', ':',
    '/', '\'','\'','i', 'i', 'R', 'R', ':', ':', ':', '/', '\'','\'','i', 'i',
    'E', 'E', 'f', 'f', 'f', 'g', 'g', 'g', 'h', 'h', 'E', 'E', 'f', 'f', 'f',
    'g', 'g', 'g', 'h', 'h', 'N', 'N', 'Z', 'Z', 'Z', 'Y', 'Y', 'Y', 'K', 'K',
    'O', 'O', 'Z', 'Z', 'Z', 'Y', 'Y', 'Y', 'K', 'K', '?', '?', '?', '@', '=',
    ']', ']', ']', 'k', 'k', 'P', 'P', '@', '@', '=', ']', ']', ']', 'k', 'k',
    'P', 'P', '%', '%', '%', '3', ']', ']', 'k', 'k', 'Q', 'Q', '|', '|', '3',
    '3', '4', '4', '(', '(', 'Q', 'Q', ':', ':', ':', '4', '4', '4', '(', '(',
    'Q', 'Q', ':', ':', ':', '4', '4', '4', '<', '<', 'E', 'E', 'e', 'e', 'e',
    '+', '+', '*', '*', '<', 'E', 'E', 'e', 'e', 'e', '+', '+', '*', '*', '`',
    'N', 'N', 'Z', 'Z', 'Z', 'Y', 'Y', 'Y', 'Y', 'K', 'O', 'O', 'Z', 'Z', 'Z',
    'Y', 'Y', 'Y', 'k', 'k', 'O', 'O', 'O', 'Z', '=', '=', '}', 'k', 'k', 'k',
    'P', 'P', 'P', '@', '=', '=', '}', '}', 'k', 'k', 'P', 'P', '%', '%', '%',
    '=', '}', '}', 'k', 'k', 'Q', 'Q', '|', '|', '|', '4', '4', '4', '(', '(',
    'Q', 'Q', '.', '.', '.', '4', '4', '4', '(', '(', 'Q', 'Q', 'e', '.', '.',
    '4', '4', '4', '<', '<', 'Q', 'e', 'e', 'e', 'e', '+', '+', '*', '*', '<',
    'E', 'e', 'e', 'e', 'e', '+', '+', '*', '*', '`', 'N', 'N', 'Z', 'Z', 'Z',
    'Y', 'Y', 'Y', 'Y', 'L', 'O', 'O', 'Z', 'Z', 'Z', 'Y', 'Y', 'Y', 'k', 'k',
    'O', 'O', 'O', 'a', '=', '=', 'm', 'k', 'k', 'k', 'P', 'P', 'a', 'a', '=',
    '=', '}', 'k', 'k', 'k', 'P', 'P', '%', '%', '%', '=', '}', '8', '8', '8',
    'Q', 'Q', '|', '|', '|', '4', '4', '8', '8', '8', 'Q', 'Q', 'c', '.', '.',
    '4', '4', '4', '[', '[', 'Q', 'Q', 'c', 'c', '9', '9', '4', '5', '5', '<',
    'Q', 'e', 'e', 'e', 'e', ';', ';', '5', '5', '<', 'D', 'e', 'e', 'e', 'e',
    ';', ';', ';', '*', '`', 'A', 'A', 'Z', 'Z', 'M', 'M', 'Y', 'Y', 'L', 'L',
    'A', 'A', 'a', 'a', 'M', 'M', 'm', 'm', 'L', 'L', 'B', 'B', 'a', 'a', 'a',
    'm', 'm', 'm', 'l', 'l', 'B', 'B', 'a', 'a', 'a', 'm', 'm', 'm', 'l', 'l',
    'C', 'C', 'b', 'b', 'b', '7', '7', '7', '8', '8', 'C', 'C', 'b', 'b', 'b',
    '7', '7', '^', '[', '[', 'Q', 'c', 'c', 'c', 'c', '#', '#', '^', '[', '[',
    'Q', 'c', 'c', 'c', '9', '9', '$', '5', '5', '[', 'D', 'D', 'd', 'd', '9',
    '&', '&', '5', '5', '6', 'D', 'D', 'd', 'd', 'd', ';', ';', ';', '6', '6',
    'A', 'A', 'A', 'M', 'M', 'M', 'M', 'L', 'L', 'L', 'A', 'A', 'a', 'a', 'M',
    'M', 'm', 'm', 'L', 'L', 'B', 'B', 'a', 'a', 'a', 'm', 'm', 'm', 'l', 'l',
    'B', 'B', 'a', 'a', 'a', 'm', 'm', 'm', 'l', 'l', 'C', 'C', 'b', 'b', 'b',
    '7', '7', '7', 'l', 'l', 'C', 'C', 'b', 'b', 'b', '7', '7', '^', '^', '{',
    'C', 'c', 'c', 'c', 'c', '#', '#', '^', '^', '{', 'D', 'c', 'c', 'c', '9',
    '9', '$', '$', '^', '{', 'D', 'D', 'd', 'd', '9', '&', '&', '&', '6', '6',
    'D', 'D', 'd', 'd', 'd', ',', ',', ',', '6', '6'
};

/*
 * c1rgb - RGB values for c1 palette entries
 *
 * Entry order corresponds to c1list (above).
 * Each entry gives r,g,b in linear range 0 to 48.
 */
static unsigned char c1rgb[] = {
    0, 0, 0,		/*  0             black		*/
    8, 8, 8,		/*  1   very dark gray		*/
    16, 16, 16,		/*  2        dark gray		*/
    24, 24, 24,		/*  3             gray		*/
    32, 32, 32,		/*  4       light gray		*/
    40, 40, 40,		/*  5  very light gray		*/
    48, 48, 48,		/*  6             white		*/
    48, 24, 30,		/*  7             pink		*/
    36, 24, 48,		/*  8             violet	*/
    48, 36, 24,		/*  9  very light brown		*/
    24, 12, 0,		/*  ?             brown		*/
    8, 4, 0,		/*  !   very dark brown		*/
    16, 0, 0,		/*  n   very dark red		*/
    32, 0, 0,		/*  N        dark red		*/
    48, 0, 0,		/*  A             red		*/
    48, 16, 16,		/*  a       light red		*/
    48, 32, 32,		/*  #  very light red		*/
    30, 18, 18,		/*  @        weak red		*/
    16, 4, 0,		/*  o   very dark orange	*/
    32, 8, 0,		/*  O        dark orange	*/
    48, 12, 0,		/*  B             orange	*/
    48, 24, 16,		/*  b       light orange	*/
    48, 36, 32,		/*  $  very light orange	*/
    30, 21, 18,		/*  %        weak orange	*/
    16, 8, 0,		/*  p   very dark red-yellow	*/
    32, 16, 0,		/*  P        dark red-yellow	*/
    48, 24, 0,		/*  C             red-yellow	*/
    48, 32, 16,		/*  c       light red-yellow	*/
    48, 40, 32,		/*  &  very light red-yellow	*/
    30, 24, 18,		/*  |        weak red-yellow	*/
    16, 16, 0,		/*  q   very dark yellow	*/
    32, 32, 0,		/*  Q        dark yellow	*/
    48, 48, 0,		/*  D             yellow	*/
    48, 48, 16,		/*  d       light yellow	*/
    48, 48, 32,		/*  ,  very light yellow	*/
    30, 30, 18,		/*  .        weak yellow	*/
    8, 16, 0,		/*  r   very dark yellow-green	*/
    16, 32, 0,		/*  R        dark yellow-green	*/
    24, 48, 0,		/*  E             yellow-green	*/
    32, 48, 16,		/*  e       light yellow-green	*/
    40, 48, 32,		/*  ;  very light yellow-green	*/
    24, 30, 18,		/*  :        weak yellow-green	*/
    0, 16, 0,		/*  s   very dark green		*/
    0, 32, 0,		/*  S        dark green		*/
    0, 48, 0,		/*  F             green		*/
    16, 48, 16,		/*  f       light green		*/
    32, 48, 32,		/*  +  very light green		*/
    18, 30, 18,		/*  -        weak green		*/
    0, 16, 8,		/*  t   very dark cyan-green	*/
    0, 32, 16,		/*  T        dark cyan-green	*/
    0, 48, 24,		/*  G             cyan-green	*/
    16, 48, 32,		/*  g       light cyan-green	*/
    32, 48, 40,		/*  *  very light cyan-green	*/
    18, 30, 24,		/*  /        weak cyan-green	*/
    0, 16, 16,		/*  u   very dark cyan		*/
    0, 32, 32,		/*  U        dark cyan		*/
    0, 48, 48,		/*  H             cyan		*/
    16, 48, 48,		/*  h       light cyan		*/
    32, 48, 48,		/*  `  very light cyan		*/
    18, 30, 30,		/*  '        weak cyan		*/
    0, 8, 16,		/*  v   very dark blue-cyan	*/
    0, 16, 32,		/*  V        dark blue-cyan	*/
    0, 24, 48,		/*  I             blue-cyan	*/
    16, 32, 48,		/*  i       light blue-cyan	*/
    32, 40, 48,		/*  <  very light blue-cyan	*/
    18, 24, 30,		/*  >        weak blue-cyan	*/
    0, 0, 16,		/*  w   very dark blue		*/
    0, 0, 32,		/*  W        dark blue		*/
    0, 0, 48,		/*  J             blue		*/
    16, 16, 48,		/*  j       light blue		*/
    32, 32, 48,		/*  (  very light blue		*/
    18, 18, 30,		/*  )        weak blue		*/
    8, 0, 16,		/*  x   very dark purple	*/
    16, 0, 32,		/*  X        dark purple	*/
    24, 0, 48,		/*  K             purple	*/
    32, 16, 48,		/*  k       light purple	*/
    40, 32, 48,		/*  [  very light purple	*/
    24, 18, 30,		/*  ]        weak purple	*/
    16, 0, 16,		/*  y   very dark magenta	*/
    32, 0, 32,		/*  Y        dark magenta	*/
    48, 0, 48,		/*  L             magenta	*/
    48, 16, 48,		/*  l       light magenta	*/
    48, 32, 48,		/*  {  very light magenta	*/
    30, 18, 30,		/*  }        weak magenta	*/
    16, 0, 8,		/*  z   very dark magenta-red	*/
    32, 0, 16,		/*  Z        dark magenta-red	*/
    48, 0, 24,		/*  M             magenta-red	*/
    48, 16, 32,		/*  m       light magenta-red	*/
    48, 32, 40,		/*  ^  very light magenta-red	*/
    30, 18, 24,		/*  =        weak magenta-red	*/
};

/*
 * parsepalette() - get palette number, or 0 if unrecognized.
 *
 *    returns in *p: +1 ... +6 for "c1" through "c6"
 *                   -2 ... -256 for "g2" through "g256"
 *    returns 0 for unrecognized palette name
 */
int parsepalette(char *s, int *p)
{
    char c, x;
    int n;
    if (sscanf(s, "%c%d%c", &c, &n, &x) != 2)
        return 0;
    if (c == 'c' && n >= 1 && n <= 6) {
        *p = n;
        return 1;
    }
    if (c == 'g' && n >= 2 && n <= 256) {
        *p = -n;
        return 1;
    }
    return 0;
}


struct palentry *palsetup_palette;	/* current palette */

/*
 * palsetup(p) - set up palette for specified palette.
 */
struct palentry *palsetup(int p)
{
    int r, g, b, i, n, c;
    unsigned int rr, gg, bb;
    unsigned char *s = NULL, *t;
    double m;
    struct palentry *e;

    static int palnumber;		/* current palette number */

    if (palnumber == p)
        return palsetup_palette;
    if (palsetup_palette == NULL)
        MemProtect(palsetup_palette = malloc(256 * sizeof(struct palentry)));

    palnumber = p;

    for (i = 0; i < 256; i++)
        palsetup_palette[i].valid = palsetup_palette[i].transpt = 0;
    palsetup_palette[TCH1].transpt = 1;
    palsetup_palette[TCH2].transpt = 1;

    if (p < 0) {				/* grayscale palette */
        n = -p;
        if (n <= 64)
            s = (unsigned char *)c4list;
        else
            s = (unsigned char *)allchars;
        m = 1.0 / (n - 1);

        for (i = 0; i < n; i++) {
            e = &palsetup_palette[*s++];
            gg = 65535 * m * i;
            e->r = e->g = e->b = gg;
            e->valid = 1;
            e->transpt = 0;
        }
        return palsetup_palette;
    }

    if (p == 1) {			/* special c1 palette */
        s = (unsigned char *)c1list;
        t = c1rgb;
        while ((c = *s++) != 0) {
            e = &palsetup_palette[c];
            e->r   = 65535 * (((int)*t++) / 48.0);
            e->g = 65535 * (((int)*t++) / 48.0);
            e->b  = 65535 * (((int)*t++) / 48.0);
            e->valid = 1;
            e->transpt = 0;
        }
        return palsetup_palette;
    }

    switch (p) {				/* color cube plus extra grays */
        case  2:  s = (unsigned char *)c2list;	break;	/* c2 */
        case  3:  s = (unsigned char *)c3list;	break;	/* c3 */
        case  4:  s = (unsigned char *)c4list;	break;	/* c4 */
        case  5:  s = (unsigned char *)allchars;break;	/* c5 */
        case  6:  s = (unsigned char *)allchars;break;	/* c6 */
    }
    m = 1.0 / (p - 1);
    for (r = 0; r < p; r++) {
        rr = 65535 * m * r;
        for (g = 0; g < p; g++) {
            gg = 65535 * m * g;
            for (b = 0; b < p; b++) {
                bb = 65535 * m * b;
                e = &palsetup_palette[*s++];
                e->r = rr;
                e->g = gg;
                e->b = bb;
                e->valid = 1;
                e->transpt = 0;
            }
        }
    }
    m = 1.0 / (p * (p - 1));
    for (g = 0; g < p * (p - 1); g++)
        if (g % p != 0) {
            gg = 65535 * m * g;
            e = &palsetup_palette[*s++];
            e->r = e->g = e->b = gg;
            e->valid = 1;
            e->transpt = 0;
        }
    return palsetup_palette;
}

/*
 * rgbkey(p,r,g,b) - return pointer to key of closest color in palette number p.
 *
 * In color cubes, finds "extra" grays only if r == g == b.
 */
char *rgbkey(int p, int r0, int g0, int b0)
{
    int n, i;
    double m, r, g, b;
    char *s;

    r = r0 / 65535.0;
    g = g0 / 65535.0;
    b = b0 / 65535.0;

    if (p > 0) { 			/* color */
        if (r == g && g == b) {
            if (p == 1)
                m = 6;
            else
                m = p * (p - 1);
            return cgrays[p - 1] + (int)(0.501 + m * g);
        }
        else {
            if (p == 1)
                n = C1Side;
            else
                n = p;
            m = n - 1;
            i = (int)(0.501 + m * r);
            i = n * i + (int)(0.501 + m * g);
            i = n * i + (int)(0.501 + m * b);
            switch(p) {
                case  1:  return c1cube + i;		/* c1 */
                case  2:  return c2list + i;		/* c2 */
                case  3:  return c3list + i;		/* c3 */
                case  4:  return c4list + i;		/* c4 */
                case  5:  return allchars + i;	        /* c5 */
                case  6:  return allchars + i;	        /* c6 */
            }
        }
    }
    else {				/* grayscale */
        if (p < -64)
            s = allchars;
        else
            s = c4list;
        return s + (int)(0.5 + (0.299 * r + 0.587 * g + 0.114 * b) * (-p - 1));
    }

    /*NOTREACHED*/
    return 0;  /* avoid gcc warning */
}

int getdefaultfontsize(int deflt)
{
    static int t;
    if (!t) {
        char *s = getenv("OIFONTSIZE");
        if (s) {
            char ch;
            if (sscanf(s, "%d%c", &t, &ch) != 1 || t <= 0)
                t = -1;
        } else
            t = -1;
    }
    if (t < 0)
        return deflt;
    return t;
}

char *getdefaultfont()
{
    static char *t;
    if (!t) {
        char *s = getenv("OIFONT");
        if (s)
            t = salloc(s);
        else
            t = "fixed";
    }
    return t;
}


/*
 * mapping from recognized style attributes to flag values
 */
stringint fontwords[] = {
    { 0,                17 },           /* number of entries */
    { "bold",           FONTATT_WEIGHT  | FONTFLAG_BOLD },
    { "condensed",      FONTATT_WIDTH   | FONTFLAG_CONDENSED },
    { "demi",           FONTATT_WEIGHT  | FONTFLAG_DEMI },
    { "demibold",       FONTATT_WEIGHT  | FONTFLAG_DEMI | FONTFLAG_BOLD },
    { "extended",       FONTATT_WIDTH   | FONTFLAG_EXTENDED },
    { "italic",         FONTATT_SLANT   | FONTFLAG_ITALIC },
    { "light",          FONTATT_WEIGHT  | FONTFLAG_LIGHT },
    { "medium",         FONTATT_WEIGHT  | FONTFLAG_MEDIUM },
    { "mono",           FONTATT_SPACING | FONTFLAG_MONO },
    { "narrow",         FONTATT_WIDTH   | FONTFLAG_NARROW },
    { "normal",         FONTATT_WIDTH   | FONTFLAG_NORMAL },
    { "oblique",        FONTATT_SLANT   | FONTFLAG_OBLIQUE },
    { "proportional",   FONTATT_SPACING | FONTFLAG_PROPORTIONAL },
    { "roman",          FONTATT_SLANT   | FONTFLAG_ROMAN },
    { "sans",           FONTATT_SERIF   | FONTFLAG_SANS },
    { "serif",          FONTATT_SERIF   | FONTFLAG_SERIF },
    { "wide",           FONTATT_WIDTH   | FONTFLAG_WIDE },
};

/*
 * parsefont - extract font family name, style attributes, and size
 *
 * these are window system independent values, so they require
 *  further translation into window system dependent values.
 *
 * returns 1 on an OK font name
 * returns 0 on a "malformed" font (might be a window-system fontname)
 */
int parsefont(char *s, char family[MAXFONTWORD], int *style, int *size)
{
    char c, *a, attr[MAXFONTWORD];
    int tmp;

    /*
     * set up the defaults
     */
    *family = '\0';
    *style = 0;
    *size = -1;

    /*
     * now, scan through the raw and break out pieces
     */
    for (;;) {

        /*
         * find start of next comma-separated attribute word
         */
        while (isspace((unsigned char)*s) || *s == ',')	/* trim leading spaces & empty words */
            s++;
        if (*s == '\0')			/* stop at end of string */
            break;

        /*
         * copy word, converting to lower case to implement case insensitivity
         */
        for (a = attr; (c = *s) != '\0' && c != ','; s++) {
            *a++ = tolower((unsigned char)c);
            if (a - attr >= MAXFONTWORD - 1)
                return 0;			/* too long */
        }

        /*
         * trim trailing spaces and terminate word
         */
        while (isspace((unsigned char)a[-1]))
            a--;
        *a = '\0';

        /*
         * interpret word as family name, size, or style characteristic
         */
        if (*family == '\0')
            strcpy(family, attr);		/* first word is the family name */
        else if (sscanf(attr, "%d%c", &tmp, &c) == 1 && tmp > 0) {
            if (*size != -1 && *size != tmp)
                return 0;			/* if conflicting sizes given */
            *size = tmp;			/* integer value is a size */
        }
        else {				/* otherwise it's a style attribute */
            tmp = stringint_str2int(fontwords, attr);	/* look up in table */
            if (tmp != -1) {		/* if recognized */
                if ((tmp & *style) != 0 && (tmp & *style) != tmp)
                    return 0;		/* conflicting attribute */
                *style |= tmp;
            }
        }
    }

    /* got to end of string; it's OK if it had at least a font family */
    return (*family != '\0');
}

static int pattern_bits[16][8] = {
    {0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff},
    {0xfe, 0xff, 0xef, 0xff, 0xfe, 0xff, 0xef, 0xff},
    {0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd, 0x77, 0xdd},
    {0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa},
    {0x11, 0x44, 0x11, 0x44, 0x11, 0x44, 0x11, 0x44},
    {0x01, 0x00, 0x10, 0x00, 0x01, 0x00, 0x10, 0x00},
    {0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00},
    {0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10},
    {0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01},
    {0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00},
    {0x10, 0x10, 0x10, 0xff, 0x10, 0x10, 0x10, 0x10},
    {0x82, 0x44, 0x28, 0x10, 0x28, 0x44, 0x82, 0x01},
    {0x0f, 0x0f, 0x0f, 0x0f, 0xf0, 0xf0, 0xf0, 0xf0},
    {0x1b, 0x18, 0x81, 0xb1, 0x36, 0x06, 0x60, 0x63},
    {0x02, 0x02, 0x05, 0xf8, 0x20, 0x20, 0x50, 0x8f},
    {0x03, 0x84, 0x48, 0x30, 0x03, 0x84, 0x48, 0x30}
};

/*
 * pattern symbols
 */
static stringint patternsyms[] = {
    {0, 16},
    { "black",      0},
    { "checkers",  12},
    { "darkgray",   2},
    { "diagonal",   8},
    { "grains",    13},
    { "gray",       3},
    { "grid",      10},
    { "horizontal", 9},
    { "lightgray",  4},
    { "scales",    14},
    { "trellis",   11},
    { "vertical",   7},
    { "verydark",   1},
    { "verylight" , 5},
    { "waves",     15},
    { "white",      6},
};

static int ppattern[MAX_PATTERN_HEIGHT];

/*
 * parsepattern() - parse an encoded numeric stipple pattern, return 1 on success,
 * 0 on invalid pattern.
 */
int parsepattern(char *s, int *width, int *height, int **data)
{
    int i, j, v, len, hexdigits_per_row;

    if (!isdigit((unsigned char)s[0])) {
        if ((i = stringint_str2int(patternsyms, s)) < 0)
            return 0;
        *width = *height = 8;
        *data = pattern_bits[i];
        return 1;
    }

    len = strlen(s);

    /*
     * Get the width
     */
    if (sscanf(s, "%d,", width) != 1) 
        return 0;
    if (*width < 1 || *width > MAX_PATTERN_WIDTH)
        return 0;

    /*
     * skip over width
     */
    while ((len > 0) && isdigit((unsigned char)*s)) {
        len--; s++;
    }
    if ((len <= 1) || (*s != ',')) 
        return 0;
    len--; s++;					/* skip over ',' */

    if (*s == '#') {
        /*
         * get remaining bits as hex constant
         */
        s++; len--;
        if (len == 0) 
            return 0;
        hexdigits_per_row = *width / 4;
        if (*width % 4) hexdigits_per_row++;
        *height = len / hexdigits_per_row;
        if (len % hexdigits_per_row) (*height)++;
        if (*height > MAX_PATTERN_HEIGHT)
            return 0;
        for (i = 0; i < *height; i++) {
            v = 0;
            for (j = 0; j < hexdigits_per_row; j++, len--, s++) {
                if (len == 0) break;
                v <<= 4;
                if (isdigit((unsigned char)*s)) v += *s - '0';
                else switch (*s) {
                    case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
                        v += *s - 'a' + 10; break;
                    case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
                        v += *s - 'A' + 10; break;
                    default: return 0;
                }
	    }
            ppattern[i] = v;
        }
    }
    else {
        /*
         * get remaining bits as comma-separated decimals
         */
        v = 0;
        *height = 0;
        while (len > 0) {
            while ((len > 0) && isdigit((unsigned char)*s)) {
                v = v * 10 + *s - '0';
                len--; s++;
	    }
            if (*height >= MAX_PATTERN_HEIGHT) 
                return 0; 
            ppattern[*height] = v;
            (*height)++;
            v = 0;

            if (len > 0) {
                if (*s == ',') { 
                    len--; s++; 
                } else
                    return 0;
            }
        }
    }
    *data = ppattern;
    return 1;
}


int readimagefile(char *filename, struct imgdata *imd)
{
    int r;
    struct fileparts *fp;

    if ((r = readimagefileimpl(filename, imd)) != NoCvt)
        return r;

    fp = fparse(filename);
#ifdef HAVE_LIBPNG
    if (strcasecmp(fp->ext, ".png") == 0)
        return readPNG(filename, imd);
#endif

#ifdef HAVE_LIBJPEG
    if (strcasecmp(fp->ext, ".jpg") == 0 || strcasecmp(fp->ext, ".jpeg") == 0)
        return readJPEG(filename, imd);
#endif

    if (strcasecmp(fp->ext, ".gif") == 0)
        return readGIF(filename, imd);

    LitWhy("Unsupported file type");
    return Failed;
}


int writeimagefile(wbp w, char *filename, int x, int y, int width, int height)
{
    int r;
    struct fileparts *fp;

    if ((r = writeimagefileimpl(w, filename, x, y, width, height)) != NoCvt)
        return r;

    fp = fparse(filename);

#ifdef HAVE_LIBPNG
    if (strcasecmp(fp->ext, ".png") == 0)
        return writePNG(w, filename, x, y, width, height);
#endif		

#ifdef HAVE_LIBJPEG
    if (strcasecmp(fp->ext, ".jpg") == 0 || strcasecmp(fp->ext, ".jpeg") == 0)
        return writeJPEG(w, filename, x, y, width, height);
#endif

    LitWhy("Unsupported file type");
    return Failed;
}


/*
 * rectargs -- interpret rectangle arguments uniformly
 *
 *  Given an arglist and the index of the next x value, rectargs sets
 *  x/y/width/height to explicit or defaulted values.  These result values
 *  are in canonical form:  Width and height are nonnegative and x and y
 *  have been corrected by dx and dy.
 *
 *  Returns Error on problem, setting errval etc.
 */
int rectargs(wbp w, dptr argv, word *px, word *py, word *pw, word *ph)
{
    int defw, defh;
    wcp wc = w->context;
    wsp ws = w->window;

    /*
     * Get x and y, defaulting to -dx and -dy.
     */
    if (!def:C_integer(argv[0], -wc->dx, *px))
        ReturnErrVal(101, argv[0], Error);

    if (!def:C_integer(argv[1], -wc->dy, *py))
        ReturnErrVal(101, argv[1], Error);

    *px += wc->dx;
    *py += wc->dy;

    /*
     * Get w and h, defaulting to extend to the edge
     */
    defw = ws->width - *px;
    defh = ws->height - *py;

    if (!def:C_integer(argv[2], defw, *pw))
        ReturnErrVal(101, argv[2], Error);

    if (!def:C_integer(argv[3], defh, *ph))
        ReturnErrVal(101, argv[3], Error);

    /*
     * Correct negative w/h values.
     */
    if (*pw < 0)
        *px -= (*pw = -*pw);
    if (*ph < 0)
        *py -= (*ph = -*ph);

    return Succeeded;
}


/*
 * docircles -- draw or file circles.
 *
 *  Helper for DrawCircle and FillCircle.
 *  Returns index of bad argument, or -1 for success.
 */
int docircle(wbp w, dptr argv, int fill)
{
    word x, y, r;
    int arc_x, arc_y, arc_width, arc_height;
    double arc_angle1, arc_angle2;
    int dx, dy;
    double theta, alpha;

    dx = w->context->dx;
    dy = w->context->dy;

    /*
     * Collect arguments.
     */
    if (!cnv:C_integer(argv[0], x))
        ReturnErrVal(101, argv[0], Error);
    if (!cnv:C_integer(argv[1], y))
        ReturnErrVal(101, argv[1], Error);
    if (!cnv:C_integer(argv[2], r))
        ReturnErrVal(101, argv[2], Error);
    if (!def:C_double(argv[3], 0.0, theta))
        ReturnErrVal(102, argv[3], Error);
    if (!def:C_double(argv[4], 2 * Pi, alpha))
        ReturnErrVal(102, argv[4], Error);

    /*
     * Put in canonical form: r >= 0, -2*pi <= theta < 0, alpha >= 0.
     */
    if (r < 0) {			/* ensure positive radius */
        r = -r;
        theta += Pi;
    }
    if (alpha < 0) {			/* ensure positive extent */
        theta += alpha;
        alpha = -alpha;
    }

    theta = fmod(theta, 2 * Pi);
    if (theta > 0)			/* normalize initial angle */
        theta -= 2 * Pi;

    /*
     * Build the Arc descriptor.
     */
    arc_x = x + dx - r;
    arc_y = y + dy - r;
    arc_width = 2 * r;
    arc_height = 2 * r;

    arc_angle1 = theta;
    if (alpha >= 2 * Pi)
        arc_angle2 = 2 * Pi;
    else
        arc_angle2 = alpha;

    /*
     * Draw or fill the arc.
     */
    if (fill)
        fillarc(w, arc_x, arc_y, arc_width, arc_height, arc_angle1, arc_angle2);
    else
        drawarc(w,arc_x, arc_y, arc_width, arc_height, arc_angle1, arc_angle2);

    return Succeeded;
}


/*
 * genCurve - draw a smooth curve through a set of points.  Algorithm from
 *  Barry, Phillip J., and Goldman, Ronald N. (1988).
 *  A Recursive Evaluation Algorithm for a class of Catmull-Rom Splines.
 *  Computer Graphics 22(4), 199-204.
 */
void genCurve(wbp w, XPoint *p, int n, void (*helper)(wbp, XPoint [], int))
{
    int    i, j, steps;
    float  ax, ay, bx, by, stepsize, stepsize2, stepsize3;
    float  x, dx, d2x, d3x, y, dy, d2y, d3y;
    XPoint *thepoints = NULL;
    long npoints = 0;

    for (i = 3; i < n; i++) {
        /*
         * build the coefficients ax, ay, bx and by, using:
         *                             _              _   _    _
         *   i                 i    1 | -1   3  -3   1 | | Pi-3 |
         *  Q (t) = T * M   * G   = - |  2  -5   4  -1 | | Pi-2 |
         *               CR    Bs   2 | -1   0   1   0 | | Pi-1 |
         *                            |_ 0   2   0   0_| |_Pi  _|
         */

        ax = p[i].x - 3 * p[i-1].x + 3 * p[i-2].x - p[i-3].x;
        ay = p[i].y - 3 * p[i-1].y + 3 * p[i-2].y - p[i-3].y;
        bx = 2 * p[i-3].x - 5 * p[i-2].x + 4 * p[i-1].x - p[i].x;
        by = 2 * p[i-3].y - 5 * p[i-2].y + 4 * p[i-1].y - p[i].y;

        /*
         * calculate the forward differences for the function using
         * intervals of size 0.1
         */
        steps = Max(Abs(p[i-1].x - p[i-2].x), Abs(p[i-1].y - p[i-2].y)) + 10;

        if (steps+4 > npoints) {
            if (thepoints != NULL) free(thepoints);
            MemProtect(thepoints = malloc((steps+4) * sizeof(XPoint)));
            npoints = steps+4;
        }

        stepsize = 1.0/steps;
        stepsize2 = stepsize * stepsize;
        stepsize3 = stepsize * stepsize2;

        x = thepoints[0].x = p[i-2].x;
        y = thepoints[0].y = p[i-2].y;
        dx = (stepsize3*0.5)*ax + (stepsize2*0.5)*bx + (stepsize*0.5)*(p[i-1].x-p[i-3].x);
        dy = (stepsize3*0.5)*ay + (stepsize2*0.5)*by + (stepsize*0.5)*(p[i-1].y-p[i-3].y);
        d2x = (stepsize3*3) * ax + stepsize2 * bx;
        d2y = (stepsize3*3) * ay + stepsize2 * by;
        d3x = (stepsize3*3) * ax;
        d3y = (stepsize3*3) * ay;

        /* calculate the points for drawing the curve */

        for (j = 0; j < steps; j++) {
            x = x + dx;
            y = y + dy;
            dx = dx + d2x;
            dy = dy + d2y;
            d2x = d2x + d3x;
            d2y = d2y + d3y;
            thepoints[j + 1].x = (int)x;
            thepoints[j + 1].y = (int)y;
        }
        helper(w, thepoints, steps + 1);
    }
    if (thepoints != NULL) {
        free(thepoints);
        thepoints = NULL;
    }
}

static void curveHelper(wbp w, XPoint *thepoints, int n)
{
    /*
     * Could use drawpoints(w, thepoints, n)
     *  but that ignores the line_width and line_style attributes...
     * Might make line_style work a little better by "compressing" straight
     *  sections produced by genCurve into single drawline points.
     */
    drawlines(w, thepoints, n);
}

/*
 * draw a smooth curve through the array of points
 */
void drawCurve(wbp w, XPoint *p, int n)
{
    genCurve(w, p, n, curveHelper);
}


/*
 * allocate a window binding structure
 */
wbp alcwbinding()
   {
   wbp w;

   GRFX_ALLOC(w, _wbinding);
   GRFX_LINK(w, wbndngs);
   return w;
   }

/*
 * free a window binding.
 */
void freewbinding(wbp w)
   {
   w->refcount--;
   if(w->refcount == 0) {
      if (w->window) freewindow(w->window);
      if (w->context) freecontext(w->context);
      GRFX_UNLINK(w, wbndngs);
      }
   }

#endif					/* Graphics */


