/*
 * File: rwindow.r
 *  non window-system-specific window support routines
 */

static int colorphrase(char *buf, int *r, int *g, int *b, int *a);
static double rgbval(double n1, double n2, double hue);

#if Graphics

#if HAVE_LIBJPEG
static int readjpeg            (struct imgdata *imd);
static int writejpegfile       (char *filename, struct imgdata *imd);
#endif                                  /* HAVE_LIBJPEG */
#if HAVE_LIBPNG
static int readpng             (struct imgdata *imd);
static int writepngfile        (char *filename, struct imgdata *imd);
#endif
static int readgif             (struct imgdata *imd);
static  void wgetq(wbp w, dptr res);
static int tryimagedata(dptr data, struct imgdata *imd);
static int tryimagefile(char *filename, struct imgdata *imd);
static int readimagedata(dptr data, struct imgdata *imd, int (*fun)(struct imgdata *));
static int readimagefile(char *filename, struct imgdata *imd, int (*fun)(struct imgdata *));

static void wgetq(wbp w, dptr res)
{
    if (!list_get(&w->window->listp, res))
        fatalerr(143, 0);
}

void wgetevent(wbp w, dptr res)
{
    tended struct descrip qval;
    int i;

    wgetq(w, &qval);
    create_list(5, res);
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
            case INVOKELATER:
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
            case FOCUSIN:
            case FOCUSOUT:
            case WINDOWSTATE:
            case WINDOWRESIZED:
            case WINDOWMOVED:
            case WINDOWCLOSED: {
                /* No items follow */
                return;
            }
        }
    }

    /*
     * All other types - "real events" - 4 items follow.  The x,y
     * values need to be adjusted with the dx,dy offsets.
     */
    wgetq(w, &qval);
    IntVal(qval) -= w->context->dx;
    list_put(res, &qval);

    wgetq(w, &qval);
    IntVal(qval) -= w->context->dy;
    list_put(res, &qval);

    /* Interval */
    wgetq(w, &qval);
    list_put(res, &qval);

    /* Modifier */
    wgetq(w, &qval);
    list_put(res, &qval);
}


/*
 * Enqueue an event, encoding time interval and key state with x and y values.
 */
void qevent(wsp ws,             /* canvas */
            dptr e,             /* event code (descriptor pointer) */
            int x,              /* x and y values */
            int y,      
            word t,             /* ms clock value */
            int mod)            /* modifier flags */
{
    dptr q = &(ws->listp);	/* a window's event queue (Icon list value) */
    struct descrip d;

    /* Event code */
    list_put(q, e);

    /* x, y */
    MakeInt(x, &d);
    list_put(q, &d);
    MakeInt(y, &d);
    list_put(q, &d);

    /* Timestamp */
    MakeInt(t, &d);
    list_put(q, &d);

    /* Modifier flags */
    MakeInt(mod, &d);
    list_put(q, &d);
}

/*
 * Helper function to add a single-descriptor event to the queue.
 */
void qeventcode(wsp ws, int c)
{
    struct descrip d;
    MakeInt(c, &d);
    list_put(&ws->listp, &d);
}

void qmouseevents(wsp ws,             /* canvas */
                  int state,          /* state of mouse buttons */
                  int x,              /* x and y values */
                  int y,      
                  word t,             /* ms clock value */
                  int mod)            /* modifier key flags */
{
    struct descrip d;
    if (ws->mousestate == state) {
        if (state == 0) {
            /* Motion */
            MakeInt(MOUSEMOVED, &d);
            qevent(ws, &d, x, y, t, mod);
        } else {
            /* Drag on one or more buttons */
            MakeInt(MOUSEDRAG, &d);
            qevent(ws, &d, x, y, t, mod);
        }
    } else {
        /* Press or release of one or more buttons */
        if ((ws->mousestate & 1) && !(state & 1)) {
            MakeInt(MOUSELEFTUP, &d);
            qevent(ws, &d, x, y, t, mod);
        } else if (!(ws->mousestate & 1) && (state & 1)) {
            MakeInt(MOUSELEFT, &d);
            qevent(ws, &d, x, y, t, mod);
        }

        if ((ws->mousestate & 2) && !(state & 2)) {
            MakeInt(MOUSEMIDUP, &d);
            qevent(ws, &d, x, y, t, mod);

        } else if (!(ws->mousestate & 2) && (state & 2)) {
            MakeInt(MOUSEMID, &d);
            qevent(ws, &d, x, y, t, mod);
        }

        if ((ws->mousestate & 4) && !(state & 4)) {
            MakeInt(MOUSERIGHTUP, &d);
            qevent(ws, &d, x, y, t, mod);
        } else if (!(ws->mousestate & 4) && (state & 4)) {
            MakeInt(MOUSERIGHT, &d);
            qevent(ws, &d, x, y, t, mod);
        }

        /* The mouse wheel buttons just generate one kind of event,
         * and cannot be held. */
        if (state & 8) {
            MakeInt(MOUSE4, &d);
            qevent(ws, &d, x, y, t, mod);
        }
        if (state & 16) {
            MakeInt(MOUSE5, &d);
            qevent(ws, &d, x, y, t, mod);
        }
        if (state & 32) {
            MakeInt(MOUSE6, &d);
            qevent(ws, &d, x, y, t, mod);
        }
        if (state & 64) {
            MakeInt(MOUSE7, &d);
            qevent(ws, &d, x, y, t, mod);
        }

        ws->mousestate = (state & 7);
    }
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
    struct imgdata *imd = f->imd;
    for (j = 0; j < imd->height; j++) {
        for (i = 0; i < imd->width; i++) {
            int r, g, b, a;
            imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
            linearfilter_impl(&r, f->p.linear.mr, f->p.linear.cr);
            linearfilter_impl(&g, f->p.linear.mg, f->p.linear.cg);
            linearfilter_impl(&b, f->p.linear.mb, f->p.linear.cb);
            linearfilter_impl(&a, f->p.linear.ma, f->p.linear.ca);
            imd->format->setpixel(imd, i, j, r, g, b, a);
        }
    }
}

static int grey_band(int nb, int r, int g, int b)
{
    return (int)(nb * Gray(r, g, b) / 65536.0);
}

static void shadefilter(struct filter *f)
{
    int i, j;
    struct imgdata *imd = f->imd;
    int bk, bg_r, bg_g, bg_b;
    parsecolor(getbg(f->w), &bg_r, &bg_g, &bg_b, 0);

    bk = grey_band(f->p.shade.nband, bg_r, bg_g, bg_b);
    for (j = 0; j < imd->height; j++) {
        for (i = 0; i < imd->width; i++) {
            int r, g, b, a, k, v;
            imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
            k = grey_band(f->p.shade.nband, r, g, b);
            if (k != bk) {
                v = f->p.shade.c + f->p.shade.m * k;
                if (v < 0) v = 0;
                else if (v > 65535) v = 65535;
                imd->format->setpixel(imd, i, j, v, v, v, a);
            }
        }
    }
}

static void coercefilter(struct filter *f)
{
    int i, j;
    struct imgdata *imd = f->imd;
    struct palentry *pal = palsetup(f->p.coerce.p);
    for (j = 0; j < imd->height; j++) {
        for (i = 0; i < imd->width; i++) {
            int r, g, b, a;
            char *s;
            struct palentry *e;
            imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
            s = rgbkey(f->p.coerce.p, r, g, b);
            e = pal + (*s & 0xff);
            imd->format->setpixel(imd, i, j, e->r, e->g, e->b, a);
        }
    }
}

static void invertfilter(struct filter *f)
{
    int i, j;
    struct imgdata *imd = f->imd;
    for (j = 0; j < imd->height; j++) {
        for (i = 0; i < imd->width; i++) {
            int r, g, b, a;
            imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
            imd->format->setpixel(imd, i, j, 65535 - r, 65535 - g, 65535 - b, a);
        }
    }
}

int parsefilter(wbp w, char *s, struct filter *res)
{
    char eof;
    res->w = w;
    if (strncmp(s, "linear,", 7) == 0) {
        int n;
        res->f = linearfilter;
        n = sscanf(s + 7, "%f,%f,%f,%f,%d,%d,%d,%d%c", 
                   &res->p.linear.mr, &res->p.linear.mg, &res->p.linear.mb, &res->p.linear.ma,
                   &res->p.linear.cr, &res->p.linear.cg, &res->p.linear.cb, &res->p.linear.ca, 
                   &eof);
        if (n != 4 && n != 8)
            return 0;
        if (n == 4)
            res->p.linear.cr = res->p.linear.cg = res->p.linear.cb = res->p.linear.ca = 0;
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

int reducerect(wbp w, int clip, int *x, int *y, int *width, int *height)
{
    wcp wc = w->context;
    wsp ws = w->window;
    if (*x < 0)  { 
        *width += *x; 
        *x = 0; 
    }
    if (*y < 0)  { 
        *height += *y; 
        *y = 0; 
    }
    if (*x + *width > ws->width)
        *width = ws->width - *x; 
    if (*y + *height > ws->height)
        *height = ws->height - *y; 

    if (*width <= 0 || *height <= 0)
        return 0;

    if (clip && wc->clipw >= 0) {
        /* Further reduce the rectangle to the clipping region */
        if (*x < wc->clipx) {
            *width += *x - wc->clipx;
            *x = wc->clipx;
        }
        if (*y < wc->clipy) {
            *height += *y - wc->clipy; 
            *y = wc->clipy;
        }
        if (*x + *width > wc->clipx + wc->clipw)
            *width = wc->clipx + wc->clipw - *x;
        if (*y + *height > wc->clipy + wc->cliph)
            *height = wc->clipy + wc->cliph - *y;

        if (*width <= 0 || *height <= 0)
            return 0;
    }
    return 1;
}

int reducehline(wbp w, int clip, int *x, int *width)
{
    wcp wc = w->context;
    wsp ws = w->window;
    if (*x < 0)  { 
        *width += *x; 
        *x = 0; 
    }
    if (*x + *width > ws->width)
        *width = ws->width - *x; 

    if (*width <= 0)
        return 0;

    if (clip && wc->clipw >= 0) {
        /* Further reduce the line to the clipping region */
        if (*x < wc->clipx) {
            *width += *x - wc->clipx;
            *x = wc->clipx;
        }
        if (*x + *width > wc->clipx + wc->clipw)
            *width = wc->clipx + wc->clipw - *x;

        if (*width <= 0)
            return 0;
    }
    return 1;
}

int reducevline(wbp w, int clip, int *y, int *height)
{
    wcp wc = w->context;
    wsp ws = w->window;
    if (*y < 0)  { 
        *height += *y; 
        *y = 0; 
    }
    if (*y + *height > ws->height)
        *height = ws->height - *y; 

    if (*height <= 0)
        return 0;

    if (clip && wc->clipw >= 0) {
        /* Further reduce the line to the clipping region */
        if (*y < wc->clipy) {
            *height += *y - wc->clipy; 
            *y = wc->clipy;
        }
        if (*y + *height > wc->clipy + wc->cliph)
            *height = wc->clipy + wc->cliph - *y;

        if (*height <= 0)
            return 0;
    }
    return 1;
}

static int tryimagedata(dptr data, struct imgdata *imd)
{
    int r;
    if ((r = readimagedataimpl(data, imd)) != NoCvt)
        return r;
    if (is_gif(data))
        return readimagedata(data, imd, readgif);

#if HAVE_LIBPNG
    if (is_png(data))
        return readimagedata(data, imd, readpng);
#endif

#if HAVE_LIBJPEG
    if (is_jpeg(data))
        return readimagedata(data, imd, readjpeg);
#endif

    return NoCvt;
}

static int tryimagefile(char *filename, struct imgdata *imd)
{
    int r;
    char *ext;

    if ((r = readimagefileimpl(filename, imd)) != NoCvt)
        return r;

    ext = getext(filename);

    if (strcasecmp(ext, ".gif") == 0)
        return readimagefile(filename, imd, readgif);

#if HAVE_LIBPNG
    if (strcasecmp(ext, ".png") == 0)
        return readimagefile(filename, imd, readpng);
#endif

#if HAVE_LIBJPEG
    if (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0)
        return readimagefile(filename, imd, readjpeg);
#endif

    return NoCvt;
}

#define MaxTryImageFile 1024

int interpimage(dptr d, struct imgdata *imd)
{
    int r;
    if ((r = tryimagedata(d, imd)) != NoCvt)
        return r;
    if (StrLen(*d) < MaxTryImageFile) {
        if ((r = tryimagefile(buffstr(d), imd)) != NoCvt)
            return r;
    }
    LitWhy("Unable to interpret string as image");
    return Failed;
}

/*
 * Some helper functions for reading image data either from a file or
 * from memory.
 */

static FILE *imagefile;
static char *imagedata, *imagedata_eof, *imagefile_name;
static size_t imagedata_len;

static int readimagedata(dptr data, struct imgdata *imd, int (*fun)(struct imgdata *))
{
    int r;
    imagedata = StrLoc(*data);
    imagedata_len = StrLen(*data);
    imagedata_eof = imagedata + imagedata_len;
    imagefile_name = "(memory)";
    r = fun(imd);
    imagefile_name = imagedata = imagedata_eof = 0;
    imagedata_len = 0;
    return r;
}

static int readimagefile(char *filename, struct imgdata *imd, int (*fun)(struct imgdata *))
{
    int r;
    imagefile = fopen(filename, "rb");
    if (!imagefile) {
        errno2why();
        return Failed;
    }
    imagefile_name = filename;
    r = fun(imd);
    fclose(imagefile);
    imagefile = 0;
    imagefile_name = 0;
    return r;
}

static size_t imageread(void *ptr, size_t len)
{
    if (imagefile)
        return fread(ptr, 1, len, imagefile);
    else {
        len = Min(len, UDiffPtrsBytes(imagedata_eof,imagedata));
        memcpy(ptr, imagedata, len);
        imagedata += len;
        return len;
    }
}

static int imagegetc(void)
{
    if (imagefile)
        return getc(imagefile);
    else {
        if (imagedata >= imagedata_eof)
            return EOF;
        else
            return *imagedata++ & 0xff;
    }
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

static	int	gfread		(void);
static	int	gfheader	(void);
static	int	gfskip		(void);
static	void	gfcontrol	(void);
static	int	gfimhdr		(void);
static	int	gfmap		(void);
static	int	gfsetup		(void);
static	int	gfrdata		(void);
static	int	gfrcode		(void);
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

static int readgif(struct imgdata *imd)
{
    int r;

    r = gfread();			/* read image */

    free(gf_prefix);
    gf_prefix = NULL;
    free(gf_suffix);
    gf_suffix = NULL;

    if (!r) {			/* if no success, free mem */
        free(gf_paltbl);
        gf_paltbl = NULL;
        free(gf_string);
        gf_string = NULL;
        whyf("readgif: Failed to read GIF file %s", imagefile_name);
        return Failed;
    }

    imd->width = gf_width;			/* set return variables */
    imd->height = gf_height;
    imd->paltbl = gf_paltbl;
    imd->data = gf_string;
    imd->format = &imgdataformat_PALETTE8;

    return Succeeded;				/* return success */
}

/*
 * gfread() - read GIF file, setting gf_ globals
 */
static int gfread()
{
    gf_prefix = NULL;
    gf_suffix = NULL;
    gf_string = NULL;

    gf_paltbl = safe_calloc(256, sizeof(struct palentry));

    if (!gfheader())			/* read file header */
        return 0;
    if (gf_gcmap)			/* read global color map, if any */
        if (!gfmap())
            return 0;
    if (!gfskip())			/* skip to start of image */
        return 0;
    if (!gfimhdr())			/* read image header */
        return 0;
    if (gf_lcmap)			/* read local color map, if any */
        if (!gfmap())
            return 0;
    if (!gfsetup())			/* prepare to read image */
        return 0;
    if (!gfrdata())			/* read image data */
        return 0;
    while (gf_row < gf_height)		/* pad if too short */
        gfput(0);

    return 1;
}

/*
 * gfheader(f) - read GIF file header; return nonzero if successful
 */
static int gfheader()
{
    unsigned char hdr[13];		/* size of a GIF header */
    int b;

    if (imageread(hdr, sizeof(hdr)) != sizeof(hdr))
        return 0;				/* header short or missing */
    if (strncmp((char *)hdr, "GIF", 3) != 0 ||
        !oi_isdigit(hdr[3]) || !oi_isdigit(hdr[4]))
        return 0;				/* not GIFnn */

    b = hdr[10];				/* flag byte */
    gf_gcmap = b & 0x80;			/* global color map flag */
    gf_nbits = (b & 7) + 1;		/* number of bits per pixel */
    return 1;
}

/*
 * gfskip(f) - skip intermediate blocks and locate image
 */
static int gfskip()
{
    int c, n;

    while ((c = imagegetc()) != GifSeparator) { /* look for start-of-image flag */
        if (c == EOF)
            return 0;
        if (c == GifExtension) {		/* if extension block is present */
            c = imagegetc();				/* get label */
            if ((c & 0xFF) == GifControlExt)
                gfcontrol();			/* process control subblock */
            while ((n = imagegetc()) != 0) {		/* read blks until empty one */
                if (n == EOF)
                    return 0;
                n &= 0xFF;				/* ensure positive count */
                while (n--)				/* skip block contents */
                    imagegetc();
            }
        }
    }
    return 1;
}

/*
 * gfcontrol(f) - process control extension subblock
 */
static void gfcontrol()
{
    int i, n, c, t;

    n = imagegetc() & 0xFF;				/* subblock length (s/b 4) */
    for (i = t = 0; i < n; i++) {
        c = imagegetc() & 0xFF;
        if (i == 0)
            t = c & 1;				/* transparency flag */
        else if (i == 3 && t != 0) {
            gf_paltbl[c].a = 0;		/* set flag for transpt color */
        }
    }
}

/*
 * gfimhdr(f) - read image header
 */
static int gfimhdr()
{
    unsigned char hdr[9];		/* size of image hdr excl separator */
    int b;

    if (imageread(hdr, sizeof(hdr)) != sizeof(hdr))
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
static int gfmap()
{
    int ncolors, i, r, g, b;

    ncolors = 1 << gf_nbits;

    for (i = 0; i < ncolors; i++) {
        r = imagegetc();
        g = imagegetc();
        b = imagegetc();
        if (r == EOF || g == EOF || b == EOF)
            return 0;
        gf_paltbl[i].r  = 257 * r;	/* 257 * 255 -> 65535 */
        gf_paltbl[i].g  = 257 * g;
        gf_paltbl[i].b  = 257 * b;
        if (!gf_paltbl[i].a)		/* if not transparent color */
            gf_paltbl[i].a  = 65535;
    }

    return 1;
}

/*
 * gfsetup() - prepare to read GIF data
 */
static int gfsetup()
{
    int i, len;

    len = safe_imul(1, gf_width, gf_height);
    gf_string = safe_malloc(len);
    gf_prefix = safe_malloc(GifTableSize * sizeof(short));
    gf_suffix = safe_malloc(GifTableSize * sizeof(short));
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
static int gfrdata()
{
    int curr, prev, c;

    if ((gf_cdsize = imagegetc()) == EOF)
        return 0;
    gf_clear = 1 << gf_cdsize;
    gf_eoi = gf_clear + 1;
    gf_free = gf_eoi + 1;

    gf_lzwbits = gf_cdsize + 1;
    gf_lzwmask = (1 << gf_lzwbits) - 1;

    gf_curr = 0;
    gf_valid = 0;
    gf_rem = 0;

    prev = curr = gfrcode();
    while (curr != gf_eoi) {
        if (curr == gf_clear) {		/* if reset code */
            gf_lzwbits = gf_cdsize + 1;
            gf_lzwmask = (1 << gf_lzwbits) - 1;
            gf_free = gf_eoi + 1;
            prev = curr = gfrcode();
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
        curr = gfrcode();
    }

    return 1;
}

/*
 * gfrcode(f) - read next LZW code
 */
static int gfrcode()
{
    int c, r;

    while (gf_valid < gf_lzwbits) {
        if (--gf_rem <= 0) {
            if ((gf_rem = imagegetc()) == EOF)
                return gf_eoi;
        }
        if ((c = imagegetc()) == EOF)
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
        gf_nxt = gf_string + (gf_row * gf_width);
        gf_lim = gf_nxt + gf_width;
    }

    *gf_nxt++ = b;			/* store byte */
}


#if HAVE_LIBJPEG

struct my_error_mgr { /* a part of JPEG error handling */
    struct jpeg_error_mgr pub;	/* "public" fields */
    jmp_buf setjmp_buffer;	/* for return to caller */
};

static void my_error_exit(j_common_ptr cinfo);

static int readjpeg(struct imgdata *imd)
{
    struct jpeg_decompress_struct cinfo; /* libjpeg struct */
    struct my_error_mgr jerr;
    int row_stride;
    unsigned char *data = 0;

    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = my_error_exit;

    if (setjmp(jerr.setjmp_buffer)) {
        jpeg_destroy_decompress(&cinfo);
        free(data);
        whyf("readjpegfile: Failed to read JPEG file %s", imagefile_name);
        return Failed;
    }

    jpeg_create_decompress(&cinfo);

    if (imagefile)
        jpeg_stdio_src(&cinfo, imagefile);
    else
        jpeg_mem_src(&cinfo, (unsigned char *)imagedata, imagedata_len);

    jpeg_read_header(&cinfo, TRUE);

    /*
     * set parameters for decompression
     */
    cinfo.quantize_colors = FALSE;

    /* Start decompression */

    jpeg_start_decompress(&cinfo);
    row_stride = cinfo.output_width * cinfo.output_components; /* actual width of the image */

    data = safe_malloc(safe_imul(1, row_stride, cinfo.output_height));
	
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

    switch (cinfo.out_color_space) {
        case JCS_GRAYSCALE: imd->format = &imgdataformat_G8; break;
        case JCS_RGB: imd->format = &imgdataformat_RGB24; break;
        default: {
            free(data);
            whyf("readjpegfile: Unknown color_space in file %s", imagefile_name);
            return Failed;
        }
    }

    imd->width = cinfo.output_width;
    imd->height = cinfo.output_height;
    imd->data = data;

    return Succeeded;
}

/* a part of error handling */
static void my_error_exit(j_common_ptr cinfo)
{
    struct my_error_mgr *myerr = (struct my_error_mgr *) cinfo->err;
    (*cinfo->err->output_message) (cinfo);
    longjmp(myerr->setjmp_buffer, 1);
}

int writejpegfile(char *filename, struct imgdata *imd)
{
    int i, j;
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    int row_stride;		/* physical row width in image buffer */
    int quality;
    FILE *fp;
    unsigned char *data, *p;

    fp = fopen(filename, "wb");
    if (!fp) {
        errno2why();
        return Failed;
    }

    quality = 95;
    
    data = safe_malloc(safe_imul(imd->width, imd->height, 3));
    p = data;
    for (j = 0; j < imd->height; j++) {
        for (i = 0; i < imd->width; i++) {
            int r, g, b, a;
            imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
            *p++ = r / 256;
            *p++ = g / 256;
            *p++ = b / 256;
        }
    }

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);

    jpeg_stdio_dest(&cinfo, fp);

    cinfo.image_width = imd->width; 	/* image width and height, in pixels */
    cinfo.image_height = imd->height;

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

#if HAVE_LIBPNG

static void png_user_read(png_structp png_ptr, png_bytep data, png_size_t len)
{
    size_t r;
    r = imageread(data, len);
    if (r != len)
        png_error(png_ptr, "png: Unexpected end of file");
}

static int readpng(struct imgdata *imd)
{
    png_structp png_ptr;
    png_infop info_ptr;
    png_byte header[8];	/* 8 is the maximum size that can be checked */
    int width, height, i;
    png_bytep *row_pointers = 0, p;
    unsigned char *data = 0;
    struct imgdataformat *format;
    int pixel_depth, color_type;

    /* test for it being a png */
    if (imageread(header, 8) != 8) {
        whyf("readpngfile: Couldn't read header from PNG file %s", imagefile_name);
        return Failed;
    }

    if (png_sig_cmp(header, 0, 8)) {
        whyf("readpngfile: File %s is not recognized as a PNG file", imagefile_name);
        return Failed;
    }

    MemProtect(png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL));
    MemProtect(info_ptr = png_create_info_struct(png_ptr));

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_read_struct(&png_ptr, &info_ptr, 0);
        free(row_pointers);
        free(data);
        whyf("readpngfile: Failed to read PNG file %s", imagefile_name);
        return Failed;
    }

    png_set_read_fn(png_ptr, NULL, png_user_read);

    png_set_sig_bytes(png_ptr, 8);
    png_read_info(png_ptr, info_ptr);

    /*
     * Ensure grayscale images have at least 8bit depth (png's row
     * padding is too painful to handle for smaller depths).
     */
    if (png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_GRAY)
        png_set_expand_gray_1_2_4_to_8(png_ptr);

    if (png_get_color_type(png_ptr, info_ptr) == PNG_COLOR_TYPE_PALETTE)
        /* Ensures an 8bit depth, for same reason as for grayscale. */
        png_set_packing(png_ptr);
    else {
        if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS))
            png_set_tRNS_to_alpha(png_ptr);
    }

    if (png_get_interlace_type(png_ptr, info_ptr) == PNG_INTERLACE_ADAM7)
        png_set_interlace_handling(png_ptr);

    png_read_update_info(png_ptr, info_ptr);
    pixel_depth = png_get_bit_depth(png_ptr, info_ptr) * png_get_channels(png_ptr, info_ptr);
    color_type = png_get_color_type(png_ptr, info_ptr);

    if (color_type == PNG_COLOR_TYPE_PALETTE && pixel_depth == 8) {
        png_colorp palette;
        png_bytep trans;
        int i, num_palette, num_trans;
        format = &imgdataformat_PALETTE8;
        imd->paltbl = safe_calloc(format->palette_size, sizeof(struct palentry));
        if (png_get_PLTE(png_ptr, info_ptr, &palette, &num_palette)) {
            num_palette = Min(num_palette, format->palette_size);
            for (i = 0; i < num_palette; ++i) {
                imd->paltbl[i].r = 257 * palette[i].red;
                imd->paltbl[i].g = 257 * palette[i].green;
                imd->paltbl[i].b = 257 * palette[i].blue;
                imd->paltbl[i].a = 0xffff;
            }
        }
        if (png_get_tRNS(png_ptr, info_ptr, &trans, &num_trans, 0)) {
            num_trans = Min(num_trans, format->palette_size);
            for (i = 0; i < num_trans; ++i)
                imd->paltbl[i].a = 257 * trans[i];
        }
    } else {
        if (color_type == PNG_COLOR_TYPE_RGB && pixel_depth == 24)
            format = &imgdataformat_RGB24;
        else if (color_type == PNG_COLOR_TYPE_RGB && pixel_depth == 48)
            format = &imgdataformat_RGB48;
        else if (color_type == PNG_COLOR_TYPE_RGB_ALPHA && pixel_depth == 32)
            format = &imgdataformat_RGBA32;
        else if (color_type == PNG_COLOR_TYPE_RGB_ALPHA && pixel_depth == 64)
            format = &imgdataformat_RGBA64;
        else if (color_type == PNG_COLOR_TYPE_GRAY && pixel_depth == 8)
            format = &imgdataformat_G8;
        else if (color_type == PNG_COLOR_TYPE_GRAY_ALPHA && pixel_depth == 16)
            format = &imgdataformat_GA16;
        else if (color_type == PNG_COLOR_TYPE_GRAY && pixel_depth == 16)
            format = &imgdataformat_G16;
        else if (color_type == PNG_COLOR_TYPE_GRAY_ALPHA && pixel_depth == 32)
            format = &imgdataformat_GA32;
        else {
            png_destroy_read_struct(&png_ptr, &info_ptr, 0);
            whyf("readpngfile: File %s, unsupported format/depth", imagefile_name);
            return Failed;
        }
    }

    width = png_get_image_width(png_ptr, info_ptr);
    height = png_get_image_height(png_ptr, info_ptr);

    row_pointers = safe_malloc(sizeof(png_bytep) * height);
    data = safe_malloc(safe_imul(1, png_get_rowbytes(png_ptr, info_ptr), height));
    p = (png_bytep)data;
    for (i = 0; i < height; ++i) {
        row_pointers[i] = p;
        p += png_get_rowbytes(png_ptr, info_ptr);
    }
    png_read_image(png_ptr, row_pointers);
    png_read_end(png_ptr, 0);
    png_destroy_read_struct(&png_ptr, &info_ptr, 0);
    free(row_pointers);

    imd->width = width;
    imd->height = height;
    imd->data = data;
    imd->format = format;

    return Succeeded;
}

static int writepngfile(char *filename, struct imgdata *imd)
{
    FILE *fp;
    png_structp png_ptr;
    png_infop info_ptr;
    png_bytep *row_pointers = 0, p;
    unsigned char *data = 0;
    int i, j;

    fp = fopen(filename, "wb");
    if (!fp) {
        errno2why();
        return Failed;
    }

    MemProtect(png_ptr = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL));
    MemProtect(info_ptr = png_create_info_struct(png_ptr));

    if (setjmp(png_jmpbuf(png_ptr))) {
        png_destroy_write_struct(&png_ptr, &info_ptr);
        free(row_pointers);
        free(data);
        fclose(fp);
        whyf("writepngfile: libpng failed to write image to file %s", filename);
        return Failed;
    }

    png_init_io(png_ptr, fp);

    if (imd->format->palette_size) {
        png_color color[256];
        png_byte trans[256];
        png_set_IHDR(png_ptr, info_ptr, imd->width, imd->height,
                     8, PNG_COLOR_TYPE_PALETTE, PNG_INTERLACE_NONE,
                     PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
        for (i = 0; i < imd->format->palette_size; ++i) {
            color[i].red = imd->paltbl[i].r / 256;
            color[i].green = imd->paltbl[i].g / 256;
            color[i].blue = imd->paltbl[i].b / 256;
            trans[i] = imd->paltbl[i].a / 256;
        }
        png_set_PLTE(png_ptr, info_ptr, color, imd->format->palette_size);
        png_set_tRNS(png_ptr, info_ptr, trans, imd->format->palette_size, 0);
        png_write_info(png_ptr, info_ptr);
        row_pointers = safe_malloc(sizeof(png_bytep) * imd->height);
        data = safe_malloc(safe_imul(imd->width, imd->height, 1));
        p = (png_bytep)data;
        for (i = 0; i < imd->height; ++i) {
            row_pointers[i] = p;
            p += imd->width;
        }
        p = (png_bytep)data;
        for (j = 0; j < imd->height; j++) {
            for (i = 0; i < imd->width; i++)
                *p++ = imd->format->getpaletteindex(imd, i, j);
        }
    } else if (imd->format->alpha_depth) {
        png_set_IHDR(png_ptr, info_ptr, imd->width, imd->height,
                     16, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE,
                     PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
        png_write_info(png_ptr, info_ptr);

        row_pointers = safe_malloc(sizeof(png_bytep) * imd->height);
        data = safe_malloc(safe_imul(imd->width, imd->height, 8));
        p = (png_bytep)data;
        for (i = 0; i < imd->height; ++i) {
            row_pointers[i] = p;
            p += 8 * imd->width;
        }
        p = (png_bytep)data;
        for (j = 0; j < imd->height; j++) {
            for (i = 0; i < imd->width; i++) {
                int r, g, b, a;
                imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
                *p++ = (r>>8) & 0xff;
                *p++ = r & 0xff;
                *p++ = (g>>8) & 0xff;
                *p++ = g & 0xff;
                *p++ = (b>>8) & 0xff;
                *p++ = b & 0xff;
                *p++ = (a>>8) & 0xff;
                *p++ = a & 0xff;
            }
        }
    } else {
        png_set_IHDR(png_ptr, info_ptr, imd->width, imd->height,
                     16, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
                     PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_BASE);
        png_write_info(png_ptr, info_ptr);

        row_pointers = safe_malloc(sizeof(png_bytep) * imd->height);
        data = safe_malloc(safe_imul(imd->width, imd->height, 6));
        p = (png_bytep)data;
        for (i = 0; i < imd->height; ++i) {
            row_pointers[i] = p;
            p += 6 * imd->width;
        }
        p = (png_bytep)data;
        for (j = 0; j < imd->height; j++) {
            for (i = 0; i < imd->width; i++) {
                int r, g, b, a;
                imd->format->getpixel(imd, i, j, &r, &g, &b, &a);
                *p++ = (r>>8) & 0xff;
                *p++ = r & 0xff;
                *p++ = (g>>8) & 0xff;
                *p++ = g & 0xff;
                *p++ = (b>>8) & 0xff;
                *p++ = b & 0xff;
            }
        }
    }
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
 * mapping from recognized style attributes to flag values
 */
stringint fontwords[] = {
    { 0,                17 },           /* number of entries */
    { "bold",           FONTATT_WEIGHT  | FONTFLAG_BOLD },
    { "condensed",      FONTATT_WIDTH   | FONTFLAG_CONDENSED },
    { "demibold",       FONTATT_WEIGHT  | FONTFLAG_DEMIBOLD },
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
    { "thin",           FONTATT_WEIGHT  | FONTFLAG_THIN },
    { "wide",           FONTATT_WIDTH   | FONTFLAG_WIDE },
};

/*
 * parsefont - extract font family name, style attributes, and size
 *
 * these are window system independent values, so they require
 *  further translation into window system dependent values.
 *
 * returns 1 on an OK font name
 * returns 0 on a "malformed" font
 */
int parsefont(char *s, char family[MAXFONTWORD], int *style, double *size)
{
    char c, *a, attr[MAXFONTWORD];
    double tmpf;
    int tmp;

    /*
     * set up the defaults
     */
    *family = '\0';
    *style = 0;
    *size = -1.0;

    /*
     * now, scan through the raw and break out pieces
     */
    for (;;) {

        /*
         * find start of next comma-separated attribute word
         */
        while (oi_isspace(*s) || *s == ',')	/* trim leading spaces & empty words */
            s++;
        if (*s == '\0')			/* stop at end of string */
            break;

        /*
         * copy word, converting to lower case to implement case insensitivity
         */
        for (a = attr; (c = *s) != '\0' && c != ','; s++) {
            *a++ = oi_tolower(c);
            if (a - attr >= MAXFONTWORD - 1)
                return 0;			/* too long */
        }

        /*
         * trim trailing spaces and terminate word
         */
        while (oi_isspace(a[-1]))
            a--;
        *a = '\0';

        /*
         * interpret word as family name, size, or style characteristic
         */
        if (*family == '\0')
            strcpy(family, attr);		/* first word is the family name */
        else if ((*attr == '*' && sscanf(attr + 1, "%lf%c", &tmpf, &c) == 1) ||
                 sscanf(attr, "%lf%c", &tmpf, &c) == 1) {
            if (*attr == '*')
                tmpf *= defaultfontsize;        /* factor of default font size */
            else if (*attr == '+' || tmpf < 0.0)
                tmpf += defaultfontsize;        /* relative to default font size */
            if (tmpf < MIN_FONT_SIZE) 
                tmpf = MIN_FONT_SIZE;
            if (*size != -1.0 && *size != tmpf)
                return 0;			/* if conflicting sizes given */
            *size = tmpf;			/* float value is a size */
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

    if (*size == -1.0)
        *size = defaultfontsize;

    /* got to end of string; it's OK if it had at least a font family */
    return (*family != '\0');
}

int is_png(dptr data)
{
    return (StrLen(*data) >= 8 &&
            strncmp(StrLoc(*data), "\x89PNG\x0D\x0A\x1A\x0A", 8) == 0);
}

int is_jpeg(dptr data)
{
    return (StrLen(*data) >= 2 &&
            strncmp(StrLoc(*data), "\xFF\xD8", 2) == 0);

}

int is_gif(dptr data)
{
    return (StrLen(*data) >= 6 &&
            strncmp(StrLoc(*data), "GIF8", 4) == 0 &&
            (StrLoc(*data)[4] == '7' || StrLoc(*data)[4] == '9') &&
            StrLoc(*data)[5] == 'a');
}

int writeimagefile(char *filename, struct imgdata *imd)
{
    int r;

    if ((r = writeimagefileimpl(filename, imd)) != NoCvt)
        return r;

#if HAVE_LIBPNG || HAVE_LIBJPEG
    {
    char *ext = getext(filename);

#if HAVE_LIBPNG
    if (strcasecmp(ext, ".png") == 0)
        return writepngfile(filename, imd);
#endif		

#if HAVE_LIBJPEG
    if (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0)
        return writejpegfile(filename, imd);
#endif
    }
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
int rectargs(wbp w, dptr argv, int *px, int *py, int *pw, int *ph)
{
    wcp wc = w->context;
    wsp ws = w->window;
    word t;

    /*
     * Get x and y, defaulting to -dx and -dy.
     */
    if (!def:C_integer(argv[0], -wc->dx, t))
        ReturnErrVal(101, argv[0], Error);
    *px = t;

    if (!def:C_integer(argv[1], -wc->dy, t))
        ReturnErrVal(101, argv[1], Error);
    *py = t;

    *px += wc->dx;
    *py += wc->dy;

    /*
     * Get w and h, defaulting to extend to the edge
     */
    if (!def:C_integer(argv[2], ws->width - *px, t))
        ReturnErrVal(101, argv[2], Error);
    *pw = t;

    if (!def:C_integer(argv[3], ws->height - *py, t))
        ReturnErrVal(101, argv[3], Error);
    *ph = t;

    /*
     * Correct negative w/h values.
     */
    if (*pw < 0)
        *pw = 0;
    if (*ph < 0)
        *ph = 0;

    return Succeeded;
}

int pointargs(wbp w, dptr argv, int *px, int *py)
{
    wcp wc = w->context;
    word t;

    /*
     * Get x and y
     */
    if (!cnv:C_integer(argv[0], t))
        ReturnErrVal(101, argv[0], Error);
    *px = t;

    if (!cnv:C_integer(argv[1], t))
        ReturnErrVal(101, argv[1], Error);
    *py = t;

    *px += wc->dx;
    *py += wc->dy;

    return Succeeded;
}

int pointargs_def(wbp w, dptr argv, int *px, int *py)
{
    wcp wc = w->context;
    word t;

    /*
     * Get x and y, defaulting to -dx and -dy.
     */
    if (!def:C_integer(argv[0], -wc->dx, t))
        ReturnErrVal(101, argv[0], Error);
    *px = t;

    if (!def:C_integer(argv[1], -wc->dy, t))
        ReturnErrVal(101, argv[1], Error);
    *py = t;

    *px += wc->dx;
    *py += wc->dy;

    return Succeeded;
}

int dpointargs_def(wbp w, dptr argv, double *px, double *py)
{
    wcp wc = w->context;

    /*
     * Get x and y, defaulting to -dx and -dy.
     */
    if (!def:C_double(argv[0], -wc->dx, *px))
        ReturnErrVal(102, argv[0], Error);

    if (!def:C_double(argv[1], -wc->dy, *py))
        ReturnErrVal(102, argv[1], Error);

    *px += wc->dx;
    *py += wc->dy;

    return Succeeded;
}

/*
 * draw a smooth curve through the array of points

 *  - draw a smooth curve through a set of points.  Algorithm from
 *  Barry, Phillip J., and Goldman, Ronald N. (1988).
 *  A Recursive Evaluation Algorithm for a class of Catmull-Rom Splines.
 *  Computer Graphics 22(4), 199-204.
 */
void drawcurve(wbp w, struct point *p, int n)
{
    int    i, j, steps, n2, nalc;
    double  ax, ay, bx, by, stepsize, stepsize2, stepsize3;
    double  x, dx, d2x, d3x, y, dy, d2y, d3y;
    struct point *thepoints;
    if (n < 5)
        return;
    nalc = 64;
    thepoints = safe_malloc(nalc * sizeof(struct point));
    thepoints[0] = p[1];
    n2 = 1;

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
        stepsize = 1.0/steps;
        stepsize2 = stepsize * stepsize;
        stepsize3 = stepsize * stepsize2;

        x = p[i-2].x;
        y = p[i-2].y;
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
            if (n2 >= nalc) {
                nalc += 256;
                thepoints = safe_realloc(thepoints, nalc * sizeof(struct point));
            }
            thepoints[n2].x = x;
            thepoints[n2].y = y;
            ++n2;
        }
    }

    /* Ensure the last output point is precisely the last input point;
     * this also ensures drawlines identifies a closed curve
     * correctly. */
    thepoints[n2 - 1] = p[n - 2];

    drawlines(w, thepoints, n2);
    free(thepoints);
}

wsp linkwindow(wsp ws)
{
    ws->refcount++;
    return ws;
}

wcp linkcontext(wcp wc)
{
    wc->refcount++;
    return wc;
}

void range_extent(double x1, double y1, double x2, double y2, int *x, int *y, int *width, int *height)
{
    *x = floor(x1) - 2;
    *y = floor(y1) - 2;
    *width = ceil(x2) - floor(x1) + 4;
    *height = ceil(y2) - floor(y1) + 4;
}

void triangles_extent(struct triangle *tris, int ntris, int *x, int *y, int *width, int *height)
{
    int i;
    double x1, y1, x2, y2;
    if (ntris == 0) {
        *x = *y = *width = *height = 0;
        return;
    }
    x1 = Min(Min(tris[0].p1.x, tris[0].p2.x), tris[0].p3.x);
    y1 = Min(Min(tris[0].p1.y, tris[0].p2.y), tris[0].p3.y);
    x2 = Max(Max(tris[0].p1.x, tris[0].p2.x), tris[0].p3.x);
    y2 = Max(Max(tris[0].p1.y, tris[0].p2.y), tris[0].p3.y);
    for (i = 1; i < ntris; ++i) {
        if (tris[i].p1.x < x1) x1 = tris[i].p1.x;
        if (tris[i].p2.x < x1) x1 = tris[i].p2.x;
        if (tris[i].p3.x < x1) x1 = tris[i].p3.x;
        if (tris[i].p1.y < y1) y1 = tris[i].p1.y;
        if (tris[i].p2.y < y1) y1 = tris[i].p2.y;
        if (tris[i].p3.y < y1) y1 = tris[i].p3.y;

        if (tris[i].p1.x > x2) x2 = tris[i].p1.x;
        if (tris[i].p2.x > x2) x2 = tris[i].p2.x;
        if (tris[i].p3.x > x2) x2 = tris[i].p3.x;
        if (tris[i].p1.y > y2) y2 = tris[i].p1.y;
        if (tris[i].p2.y > y2) y2 = tris[i].p2.y;
        if (tris[i].p3.y > y2) y2 = tris[i].p3.y;
    }
    range_extent(x1, y1, x2, y2, x, y, width, height);
}

void points_extent(struct point *points, int npoints, int *x, int *y, int *width, int *height)
{
    int i;
    double x1, y1, x2, y2;
    if (npoints == 0) {
        *x = *y = *width = *height = 0;
        return;
    }
    x1 = x2 = points[0].x;
    y1 = y2 = points[0].y;
    for (i = 1; i < npoints; ++i) {
        if (points[i].x < x1)
            x1 = points[i].x;
        if (points[i].y < y1)
            y1 = points[i].y;
        if (points[i].x > x2)
            x2 = points[i].x;
        if (points[i].y > y2)
            y2 = points[i].y;
    }
    range_extent(x1, y1, x2, y2, x, y, width, height);
}

#endif					/* Graphics */


/*
 * Structures and tables used for color parsing.
 *  Tables must be kept lexically sorted.
 */

typedef struct {        /* color name entry */
    char *name;         /* basic color name */
    char *ish;          /* -ish form */
    short hue;          /* hue, in degrees */
    char lgt;           /* lightness, as percentage */
    char sat;           /* saturation, as percentage */
} colorname;

static colorname colortable[] = {		/* known colors */
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

static stringint lighttable[] = {			/* lightness modifiers */
    { 0, 5},
    { "dark",       0 },
    { "deep",       0 },		/* = very dark (see code) */
    { "light",    100 },
    { "medium",    50 },
    { "pale",     100 },		/* = very light (see code) */
};

static stringint sattable[] = {			/* saturation levels */
    { 0, 4},
    { "moderate",  50 },
    { "strong",    75 },
    { "vivid",    100 },
    { "weak",      25 },
};

/*
 *  parsecolor(s, &r, &g, &b, &a) - parse a color specification
 *  parseopaquecolor(s, &r, &g, &b) - parse a color specification, requiring
 *                                    an opaque color.
 *
 *  parsecolor interprets a color specification and produces r/g/b values
 *  scaled linearly from 0 to 65535.  parsecolor returns 1 on success, 0
 *  on an invalid specification.
 * 
 *  An Icon color specification can be any of the forms
 *
 *     #rgb			(hexadecimal digits)
 *     #rgba			(hexadecimal digits)
 *     #rrggbb
 *     #rrggbbaa
 *     #rrrgggbbb		(note: no 3 digit rrrgggbbbaaa)
 *     #rrrrggggbbbb
 *     #rrrrggggbbbbaaaa
 *     nnnnn,nnnnn,nnnnn	(integers 0 - 65535)
 *     nnnnn,nnnnn,nnnnn,nnnnn	(integers 0 - 65535)
 *     <Icon color phrase>
 */
int parseopaquecolor(char *buf, int *r, int *g, int *b)
{
    int a;
    return parsecolor(buf, r, g, b, &a) && a == 65535;
}

int parsecolor(char *buf, int *r, int *g, int *b, int *a)
{
    int len, mul, ignore;
    float rf, gf, bf, af;
    char *fmt, c;

    if (!a)
        a = &ignore;
    *r = *g = *b = 0L;
    *a = 65535;

    /* trim leading spaces */
    while (oi_isspace(*buf))
        buf++;

    /* try interpreting as three comma-separated decimal ints in the range 0..65535 */
    if (sscanf(buf, "%d,%d,%d%c", r, g, b, &c) == 3) {
        if (*r >= 0 && *r <= 65535 && *g >= 0 && *g <= 65535 && *b >= 0 && *b <= 65535)
            return 1;
        else
            return 0;
    }

    /* try interpreting as three comma-separated floats in the range 0..1 */
    if (sscanf(buf, "%f,%f,%f%c", &rf, &gf, &bf, &c) == 3) {
        if (rf >= 0.0 && rf <= 1.0 && gf >= 0.0 && gf <= 1.0 && bf >= 0.0 && bf <= 1.0) {
            *r = 65535 * rf;
            *g = 65535 * gf;
            *b = 65535 * bf;
            return 1;
        } else
            return 0;
    }

    /* try interpreting as four comma-separated decimal ints in the range 0..65535 */
    if (sscanf(buf, "%d,%d,%d,%d%c", r, g, b, a, &c) == 4) {
        if (*r >= 0 && *r <= 65535 && *g >= 0 && *g <= 65535 && *b >= 0 && *b <= 65535 && *a >= 0 && *a <= 65535)
            return 1;
        else
            return 0;
    }

    /* try interpreting as four comma-separated floats in the range 0..1 */
    if (sscanf(buf, "%f,%f,%f,%f%c", &rf, &gf, &bf, &af, &c) == 4) {
        if (rf >= 0.0 && rf <= 1.0 && gf >= 0.0 && gf <= 1.0 && bf >= 0.0 && bf <= 1.0 && af >= 0.0 && af <= 1.0) {
            *r = 65535 * rf;
            *g = 65535 * gf;
            *b = 65535 * bf;
            *a = 65535 * af;
            return 1;
        } else
            return 0;
    }

    /* try interpreting as a hexadecimal value */
    if (*buf == '#') {
        buf++;
        for (len = 0; oi_isalnum(buf[len]); len++);
        switch (len) {
            case  3:  fmt = "%1x%1x%1x%c";  mul = 0x1111;  break;
            case  4:  fmt = "%1x%1x%1x%1x%c";  mul = 0x1111;  break;
            case  6:  fmt = "%2x%2x%2x%c";  mul = 0x0101;  break;
            case  8:  fmt = "%2x%2x%2x%2x%c";  mul = 0x0101;  break;
            case  9:  fmt = "%3x%3x%3x%c";  mul = 0x0010;  break;
            case 12:  fmt = "%4x%4x%4x%c";  mul = 0x0001;  break;
            case 16:  fmt = "%4x%4x%4x%4x%c";  mul = 0x0001;  break;
            default:  return 0;
        }
        if ((len == 4) || (len == 8) || (len == 16)) {
            if (sscanf(buf, fmt, r, g, b, a, &c) != 4)
                return 0;
            *a *= mul;
        }
        else if (sscanf(buf, fmt, r, g, b, &c) != 3)
            return 0;
        *r *= mul;
        *g *= mul;
        *b *= mul;
        return 1;
    }

    /* try interpreting as a color phrase */
    return colorphrase(buf, r, g, b, a);
}

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

    static int palnumber;               /* current palette number */
    static struct palentry *palette;    /* current palette */

    if (palnumber == p)
        return palette;
    if (palette == NULL)
        palette = safe_malloc(256 * sizeof(struct palentry));

    memset(palette, 0, 256 * sizeof(struct palentry));
    palnumber = p;

    if (p < 0) {                                /* grayscale palette */
        n = -p;
        if (n <= 64)
            s = (unsigned char *)c4list;
        else
            s = (unsigned char *)allchars;
        m = 1.0 / (n - 1);

        for (i = 0; i < n; i++) {
            e = &palette[*s++];
            gg = 65535 * m * i;
            e->r = e->g = e->b = gg;
            e->a = 65535;
        }
        return palette;
    }

    if (p == 1) {                       /* special c1 palette */
        s = (unsigned char *)c1list;
        t = c1rgb;
        while ((c = *s++) != 0) {
            e = &palette[c];
            e->r   = 65535 * (((int)*t++) / 48.0);
            e->g = 65535 * (((int)*t++) / 48.0);
            e->b  = 65535 * (((int)*t++) / 48.0);
            e->a = 65535;
        }
        return palette;
    }

    switch (p) {                                /* color cube plus extra grays */
        case  2:  s = (unsigned char *)c2list;  break;  /* c2 */
        case  3:  s = (unsigned char *)c3list;  break;  /* c3 */
        case  4:  s = (unsigned char *)c4list;  break;  /* c4 */
        case  5:  s = (unsigned char *)allchars;break;  /* c5 */
        case  6:  s = (unsigned char *)allchars;break;  /* c6 */
    }
    m = 1.0 / (p - 1);
    for (r = 0; r < p; r++) {
        rr = 65535 * m * r;
        for (g = 0; g < p; g++) {
            gg = 65535 * m * g;
            for (b = 0; b < p; b++) {
                bb = 65535 * m * b;
                e = &palette[*s++];
                e->r = rr;
                e->g = gg;
                e->b = bb;
                e->a = 65535;
            }
        }
    }
    m = 1.0 / (p * (p - 1));
    for (g = 0; g < p * (p - 1); g++)
        if (g % p != 0) {
            gg = 65535 * m * g;
            e = &palette[*s++];
            e->r = e->g = e->b = gg;
            e->a = 65535;
        }
    return palette;
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
        return s + (int)(0.5 + Gray(r, g, b) * (-p - 1));
    }

    /*NOTREACHED*/
    return 0;  /* avoid gcc warning */
}

static int colrcmp1(char *s, colorname *c)
{
    return strcmp(s, c->ish);
}

static int colrcmp2(char *s, colorname *c)
{
    return strcmp(s, c->name);
}

static colorname *lookup_color(char *s, int ish)
{
    return (colorname *)bsearch(s, colortable, ElemCount(colortable), 
                                ElemSize(colortable), (BSearchFncCast)(ish ? colrcmp1:colrcmp2));
}

/*
 *  colorphrase(s, &r, &g, &b, &a) -- parse Icon color phrase.
 *
 *  A color phrase matches the pattern
 *
 *                               weak
 *                  pale         moderate
 *                  light        strong
 *          [[very] medium ]   [ vivid    ]   [color[ish]]   color [transparency%]
 *                  dark
 *                  deep
 * OR
 *          transparent
 * 
 *  where "color" is any of:
 *
 *          black gray grey white pink violet brown
 *          red orange yellow green cyan blue purple magenta
 *
 *  A single space or hyphen separates each word from its neighbor.  The
 *  default lightness is "medium", and the default saturation is "vivid".
 *
 *  "pale" means "very light"; "deep" means "very dark".
 *
 *  This naming scheme is based loosely on
 *	A New Color-Naming System for Graphics Languages
 *	Toby Berk, Lee Brownston, and Arie Kaufman
 *	IEEE Computer Graphics & Applications, May 1982
 */

static int colorphrase(char *buf, int *r, int *g, int *b, int *a)
{
    int len, very, n, pct;
    char eof, c, *p, *ebuf, cbuffer[128];
    float lgt, sat, blend, bl2, m1, m2;
    float h1, l1, s1, h2, l2, s2, r2, g2, b2;
    stringint *e;
    colorname *color1, *color2;

    lgt = -1.0;				/* default no lightness mod */
    sat =  1.0;				/* default vivid saturation */
    len = strlen(buf);
    if (len >= sizeof(cbuffer))
        return 0;				/* if too long for valid Icon spec */

    /*
     * copy spec, lowering case and replacing spaces and hyphens with NULs
     */
    for(p = cbuffer; (c = *buf) != 0; p++, buf++) {
        if (oi_isupper(c)) *p = oi_tolower(c);
        else if (c == ' ' || c == '-') *p = '\0';
        else *p = c;
    }
    *p = '\0';

    buf = cbuffer;
    ebuf = buf + len;

    /* check for "transparent" */
    if (strcmp(buf, "transparent") == 0) {
        buf += strlen(buf) + 1;
        /* Check for extraneous input */
        if (buf <= ebuf)
            return 0;
        *r = *g = *b = *a = 0;
        return 1;
    }

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
    e = stringint_lookup(lighttable, buf);
    if (e) {
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
        if (e->i != 50)
            lgt = e->i / 100.0;
    }
    else if (very)
        return 0;

    /* check for saturation adjective */
    e = stringint_lookup(sattable, buf);
    if (e) {
        sat = e->i / 100.0;
        buf += strlen(buf) + 1;
        if (buf >= ebuf)
            return 0;
    }

    if ((color1 = lookup_color(buf, 0))) {
        buf += strlen(buf) + 1;
        if (buf >= ebuf || !(color2 = lookup_color(buf, 0))) {
            blend = 0.0;
            color2 = color1;
            color1 = 0;
        } else {
            blend = 0.5;
            buf += strlen(buf) + 1;
        }
    } else {
        if (!(color1 = lookup_color(buf, 1)))
            return 0;
        buf += strlen(buf) + 1;
        if (buf >= ebuf || !(color2 = lookup_color(buf, 0)))
            return 0;
        buf += strlen(buf) + 1;
        blend = 0.25;
    }

    h2 = color2->hue;
    l2 = color2->lgt / 100.0;
    s2 = color2->sat / 100.0;

    /* Check for alpha % spec */
    if (buf <= ebuf) {
        n = sscanf(buf, "%d%%%c", &pct, &eof);
        if (n != 1 || pct < 0 || pct > 100)
            return 0;
        /* Check for extraneous input */
        buf += strlen(buf) + 1;
        if (buf <= ebuf)
            return 0;
        *a  = (65535 * pct) / 100;
    } else
        *a = 65535;

    /* at this point we know we have a valid spec */

    /* interpolate hls specs */
    if (blend > 0) {
        h1 = color1->hue;
        l1 = color1->lgt / 100.0;
        s1 = color1->sat / 100.0;

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

char *tocolorstring(int r, int g, int b, int a)
{
    static char buf[64];
    if (a == 65535)
        sprintf(buf,"%d,%d,%d", r, g, b);
    else
        sprintf(buf,"%d,%d,%d,%d", r, g, b, a);
    return buf;
}

/*
 * Image data manipulation functions.
 */

struct imgdata *newimgdata()
{
    struct imgdata *imd;
    GAlloc(imd, imgdata);
    return imd;
}

struct imgdata *initimgdata(int width, int height, struct imgdataformat *fmt)
{
    struct imgdata *imd;
    int n;
    imd = newimgdata();
    imd->width = width;
    imd->height = height;
    imd->format = fmt;
    n = fmt->palette_size;
    if (n > 0)
        imd->paltbl = safe_malloc(n * sizeof(struct palentry));
    imd->data = safe_malloc(fmt->getlength(imd));
    return imd;
}

void copyimgdata(struct imgdata *dest, struct imgdata *src, int x, int y)
{
    int i, j, width, height;
    width = dest->width;
    height = dest->height;
    for (j = 0; j < height; j++) {
        for (i = 0; i < width; i++) {
            int sr, sg, sb, sa;
            src->format->getpixel(src, x + i, y + j, &sr, &sg, &sb, &sa);
            dest->format->setpixel(dest, i, j, sr, sg, sb, sa);
        }
    }
}

struct imgdata *linkimgdata(struct imgdata *imd)
{
    ++imd->refcount;
    return imd;
}

void unlinkimgdata(struct imgdata *imd)
{
    --imd->refcount;
    if (imd->refcount == 0) {
        free(imd->paltbl);
        free(imd->data);
        free(imd);
    }
}

static void set_RGB24(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    unsigned char *s;
    int n = imd->width * y + x;
    s = imd->data + 3 * n;
    *s++ = r / 256;
    *s++ = g / 256;
    *s++ = b / 256;
}

static void get_RGB24(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 3 * n;
    *r = 257 * (*s++);
    *g = 257 * (*s++);
    *b = 257 * (*s++);
    *a = 65535;
}

/*
 * Multiply 3 ints, raising a fatalerr on overflow.
 */
int safe_imul(int x, int y, int z)
{
    word r;
    r = mul(x, y);
    if (!over_flow) {
        r = mul(r, z);
        if (!over_flow) {
            if ((int)r == r)
                return r;
        }
    }
    fatalerr(203, NULL);
    /* Not reached */
    return 0;
}

int getlength_1(struct imgdata *imd)
{
    return 1 + safe_imul(1, imd->width, imd->height) / 8;
}
int getlength_2(struct imgdata *imd)
{
    return 1 + safe_imul(1, imd->width, imd->height) / 4;
}
int getlength_4(struct imgdata *imd)
{
    return 1 + safe_imul(1, imd->width, imd->height) / 2;
}
int getlength_8(struct imgdata *imd)
{
    return safe_imul(1, imd->width, imd->height);
}
int getlength_16(struct imgdata *imd)
{
    return safe_imul(2, imd->width, imd->height);
}
int getlength_24(struct imgdata *imd)
{
    return safe_imul(3, imd->width, imd->height);
}
int getlength_32(struct imgdata *imd)
{
    return safe_imul(4, imd->width, imd->height);
}
int getlength_48(struct imgdata *imd)
{
    return safe_imul(6, imd->width, imd->height);
}
int getlength_64(struct imgdata *imd)
{
    return safe_imul(8, imd->width, imd->height);
}

static void set_A8(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    *s = a / 256;
}

static void get_A8(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    *a = 257 * (*s);
    *r = *g = *b = 0;
}

static void set_A16(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *s++ =  a / 256;
    *s =  a % 256;
}
static void get_A16(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *a = *s++;
    *a = *a<<8|*s;
    *r = *g = *b = 0;
}

static void set_BGR24(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 3 * n;
    *s++ = b / 256;
    *s++ = g / 256;
    *s++ = r / 256;
}

static void get_BGR24(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 3 * n;
    *b = 257 * (*s++);
    *g = 257 * (*s++);
    *r = 257 * (*s++);
    *a = 65535;
}

static void set_RGBA32(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    *s++ = r / 256;
    *s++ = g / 256;
    *s++ = b / 256;
    *s++ = a / 256;
}

static void get_RGBA32(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    *r = 257 * (*s++);
    *g = 257 * (*s++);
    *b = 257 * (*s++);
    *a = 257 * (*s++);
}

static void set_ABGR32(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    *s++ = a / 256;
    *s++ = b / 256;
    *s++ = g / 256;
    *s++ = r / 256;
}
static void get_ABGR32(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    *a = 257 * (*s++);
    *b = 257 * (*s++);
    *g = 257 * (*s++);
    *r = 257 * (*s++);
}

static void set_RGB48(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 6 * n;
    *s++ = r / 256;
    *s++ = r % 256;
    *s++ = g / 256;
    *s++ = g % 256;
    *s++ = b / 256;
    *s++ = b % 256;
}
static void get_RGB48(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 6 * n;
    *r = *s++;
    *r = *r<<8|*s++;
    *g = *s++;
    *g = *g<<8|*s++;
    *b = *s++;
    *b = *b<<8|*s++;
    *a = 65535;
}

static void set_RGBA64(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 8 * n;
    *s++ = r / 256;
    *s++ = r % 256;
    *s++ = g / 256;
    *s++ = g % 256;
    *s++ = b / 256;
    *s++ = b % 256;
    *s++ = a / 256;
    *s++ = a % 256;
}
static void get_RGBA64(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 8 * n;
    *r = *s++;
    *r = *r<<8|*s++;
    *g = *s++;
    *g = *g<<8|*s++;
    *b = *s++;
    *b = *b<<8|*s++;
    *a = *s++;
    *a = *a<<8|*s++;
}

static void set_G8(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    *s++ = IntGray(r, g, b) / 256;
}

static void get_G8(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    *r = *g = *b = 257 * (*s++);
    *a = 65535;
}

static void set_GA16(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *s++ = IntGray(r, g, b) / 256;
    *s++ = a / 256;
}
static void get_GA16(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *r = *g = *b = 257 * (*s++);
    *a = 257 * (*s++);
}

static void set_AG16(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *s++ = a / 256;
    *s++ = IntGray(r, g, b) / 256;
}
static void get_AG16(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *a = 257 * (*s++);
    *r = *g = *b = 257 * (*s++);
}

static void set_G16(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int gr, n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    gr = IntGray(r, g, b);
    *s++ =  gr / 256;
    *s++ =  gr % 256;
}
static void get_G16(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 2 * n;
    *r = *s++;
    *r = *r<<8|*s++;
    *g = *b = *r;
    *a = 65535;
}

static void set_GA32(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    int gr, n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    gr = IntGray(r, g, b);
    *s++ =  gr / 256;
    *s++ =  gr % 256;
    *s++ = a / 256;
    *s++ = a % 256;
}
static void get_GA32(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + 4 * n;
    *r = *s++;
    *r = *r<<8|*s++;
    *g = *b = *r;
    *a = *s++;
    *a = *a<<8|*s++;
}

static void get_PALETTE(struct imgdata *imd, int x, int y, int *r, int *g, int *b, int *a)
{
    struct palentry *pe = &imd->paltbl[imd->format->getpaletteindex(imd, x, y)];
    *r = pe->r;
    *g = pe->g;
    *b = pe->b;
    *a = pe->a;
}

static unsigned int square(int x) {    return (x/2) * (x/2); }

static unsigned int distance_rgb(struct palentry *pe, int r, int g, int b)
{
    return square(r - pe->r) + square(g - pe->g) + square(b - pe->b);
}

static void set_PALETTE(struct imgdata *imd, int x, int y, int r, int g, int b, int a)
{
    unsigned int best_d, d;
    struct palentry *best, *pe;
    int i;

    #define Bullseye (best_d == 0 && best->a == a)
    best = imd->paltbl;
    best_d = distance_rgb(imd->paltbl, r, g, b);
    if (!Bullseye) {
        for (i = 1; i < imd->format->palette_size; ++i) {
            pe = &imd->paltbl[i];
            d = distance_rgb(pe, r, g, b);
            if (d < best_d) {
                best_d = d;
                best = pe;
                if (Bullseye) break;
            } else if (d == best_d) {
                if (Abs(best->a - a) > Abs(pe->a - a)) {
                    best = pe;
                    if (Bullseye) break;
                }
            }
        }
    }
    imd->format->setpaletteindex(imd, x, y, best - imd->paltbl);
}

static int getpi_PALETTE1(struct imgdata *imd, int x, int y)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 8;
    return (*s >> (n % 8)) & 1;
}
static void setpi_PALETTE1(struct imgdata *imd, int x, int y, int i)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 8;
    *s = (*s & ~(1 << (n % 8))) | (i << (n % 8));
}

static int getpi_PALETTE2(struct imgdata *imd, int x, int y)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 4;
    return (*s >> 2 * (n % 4)) & 3;
}
static void setpi_PALETTE2(struct imgdata *imd, int x, int y, int i)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 4;
    *s = (*s & ~(3 << 2 * (n % 4))) | (i << 2 * (n % 4));
}

static int getpi_PALETTE4(struct imgdata *imd, int x, int y)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 2;
    return (*s >> 4 * (n % 2)) & 15;
}
static void setpi_PALETTE4(struct imgdata *imd, int x, int y, int i)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n / 2;
    *s = (*s & ~(15 << 4 * (n % 2))) | (i << 4 * (n % 2));
}

static int getpi_PALETTE8(struct imgdata *imd, int x, int y)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    return *s;
}
static void setpi_PALETTE8(struct imgdata *imd, int x, int y, int i)
{
    int n = imd->width * y + x;
    unsigned char *s = imd->data + n;
    *s = (unsigned char)i;
}

#define IMDHASH_SIZE 32

static struct imgdataformat *imdfmt_hash[IMDHASH_SIZE];

static int imdfmt_hash_func(char *s)
{
    int h = 0;
    while (*s)
        h = 13 * h + (*s++ & 0377);
    return h % ElemCount(imdfmt_hash);
}

struct imgdataformat imgdataformat_A8 =   {set_A8,get_A8,0,0,getlength_8,8,0,0,"A8"};
struct imgdataformat imgdataformat_A16 =   {set_A16,get_A16,0,0,getlength_16,16,0,0,"A16"};
struct imgdataformat imgdataformat_RGB24 =   {set_RGB24,get_RGB24,0,0,getlength_24,0,24,0,"RGB24"};
struct imgdataformat imgdataformat_BGR24 =   {set_BGR24,get_BGR24,0,0,getlength_24,0,24,0,"BGR24"};
struct imgdataformat imgdataformat_RGBA32 =   {set_RGBA32,get_RGBA32,0,0,getlength_32,8,24,0,"RGBA32"};
struct imgdataformat imgdataformat_ABGR32 =   {set_ABGR32,get_ABGR32,0,0,getlength_32,8,24,0,"ABGR32"};
struct imgdataformat imgdataformat_RGB48 =   {set_RGB48,get_RGB48,0,0,getlength_48,0,48,0,"RGB48"};
struct imgdataformat imgdataformat_RGBA64 =   {set_RGBA64,get_RGBA64,0,0,getlength_64,16,48,0,"RGBA64"};
struct imgdataformat imgdataformat_G8 =   {set_G8,get_G8,0,0,getlength_8,0,8,0,"G8"};
struct imgdataformat imgdataformat_GA16 =   {set_GA16,get_GA16,0,0,getlength_16,8,8,0,"GA16"};
struct imgdataformat imgdataformat_AG16 =   {set_AG16,get_AG16,0,0,getlength_16,8,8,0,"AG16"};
struct imgdataformat imgdataformat_G16 =   {set_G16,get_G16,0,0,getlength_16,0,16,0,"G16"};
struct imgdataformat imgdataformat_GA32 =   {set_GA32,get_GA32,0,0,getlength_32,16,16,0,"GA32"};
struct imgdataformat imgdataformat_PALETTE1 =   {set_PALETTE,get_PALETTE,setpi_PALETTE1,getpi_PALETTE1,getlength_1,16,48,2,"PALETTE1"};
struct imgdataformat imgdataformat_PALETTE2 =   {set_PALETTE,get_PALETTE,setpi_PALETTE2,getpi_PALETTE2,getlength_2,16,48,4,"PALETTE2"};
struct imgdataformat imgdataformat_PALETTE4 =   {set_PALETTE,get_PALETTE,setpi_PALETTE4,getpi_PALETTE4,getlength_4,16,48,16,"PALETTE4"};
struct imgdataformat imgdataformat_PALETTE8 =   {set_PALETTE,get_PALETTE,setpi_PALETTE8,getpi_PALETTE8,getlength_8,16,48,256,"PALETTE8"};

void registerimgdataformat(struct imgdataformat *fmt)
{
    int i = imdfmt_hash_func(fmt->name);
    fmt->next = imdfmt_hash[i];
    imdfmt_hash[i] = fmt;
}

struct imgdataformat *parseimgdataformat(char *s)
{
    static int inited;
    struct imgdataformat *p;
    int i;
    if (!inited) {
        registerimgdataformat(&imgdataformat_A16);
        registerimgdataformat(&imgdataformat_A8);
        registerimgdataformat(&imgdataformat_ABGR32);
        registerimgdataformat(&imgdataformat_AG16);
        registerimgdataformat(&imgdataformat_BGR24);
        registerimgdataformat(&imgdataformat_G16);
        registerimgdataformat(&imgdataformat_G8);
        registerimgdataformat(&imgdataformat_GA16);
        registerimgdataformat(&imgdataformat_GA32);
        registerimgdataformat(&imgdataformat_PALETTE1);
        registerimgdataformat(&imgdataformat_PALETTE2);
        registerimgdataformat(&imgdataformat_PALETTE4);
        registerimgdataformat(&imgdataformat_PALETTE8);
        registerimgdataformat(&imgdataformat_RGB24);
        registerimgdataformat(&imgdataformat_RGB48);
        registerimgdataformat(&imgdataformat_RGBA32);
        registerimgdataformat(&imgdataformat_RGBA64);
        inited = 1;
#if Graphics
        registerplatformimgdataformats();
#endif
    }

    i = imdfmt_hash_func(s);
    for (p = imdfmt_hash[i]; p; p = p->next) {
        if (strcmp(s, p->name) == 0)
            return p;
    }
    return 0;
}

int pixels_rectargs(struct imgdata *img, dptr argv, int *px, int *py, int *pw, int *ph)
{
    word t;

    /*
     * Get x and y, defaulting to 0.
     */
    if (!def:C_integer(argv[0], 0, t))
        ReturnErrVal(101, argv[0], Error);
    *px = t;

    if (!def:C_integer(argv[1], 0, t))
        ReturnErrVal(101, argv[1], Error);
    *py = t;

    /*
     * Get w and h, defaulting to extend to the edge
     */
    if (!def:C_integer(argv[2], img->width - *px, t))
        ReturnErrVal(101, argv[2], Error);
    *pw = t;

    if (!def:C_integer(argv[3], img->height - *py, t))
        ReturnErrVal(101, argv[3], Error);
    *ph = t;

    /*
     * Correct negative w/h values.
     */
    if (*pw < 0)
        *pw = 0;
    if (*ph < 0)
        *ph = 0;

    return Succeeded;
}

int pixels_pointargs_def(dptr argv, int *px, int *py)
{
    word t;

    /*
     * Get x and y, defaulting to 0.
     */
    if (!def:C_integer(argv[0], 0, t))
        ReturnErrVal(101, argv[0], Error);
    *px = t;

    if (!def:C_integer(argv[1], 0, t))
        ReturnErrVal(101, argv[1], Error);
    *py = t;

    return Succeeded;
}

int pixels_reducerect(struct imgdata *img, int *x, int *y, int *width, int *height)
{
    if (*x < 0)  { 
        *width += *x; 
        *x = 0; 
    }
    if (*y < 0)  { 
        *height += *y; 
        *y = 0; 
    }
    if (*x + *width > img->width)
        *width = img->width - *x; 
    if (*y + *height > img->height)
        *height = img->height - *y; 

    if (*width <= 0 || *height <= 0)
        return 0;

    return 1;
}
