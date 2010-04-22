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


static	int	colorphrase    (char *buf, long *r, long *g, long *b, long *a);
static	double	rgbval	(double n1, double n2, double hue);
static  void    wgetq          (wbp w, dptr res);

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
                int i;
                /* Five items follow; copy them to the result */
                for (i = 0; i < 5; ++i) {
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
            long f,             /* modifier key flags */
            int krel)           /* key release flag */
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
    if (f & ControlMask)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (f & Mod1Mask)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (f & ShiftMask)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);
    if (krel)
        list_put(q, &onedesc);
    else
        list_put(q, &nulldesc);

    /* Interval */
    MakeInt(ivl, &d);
    list_put(q, &d);
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

static colrmod transptable[] = {		/* transparency levels */
    { "opaque",  100 },
    { "subtranslucent",  75 },
    { "subtransparent",  25 },
    { "translucent",  50 },
    { "transparent",  5 },
};


/*
 *  parsecolor(w, s, &r, &g, &b, &a) - parse a color specification
 *
 *  parsecolor interprets a color specification and produces r/g/b values
 *  scaled linearly from 0 to 65535.  parsecolor returns Succeeded or Failed.
 *
 *  An Icon color specification can be any of the forms
 *
 *     #rgb			(hexadecimal digits)
 *     #rgba
 *     #rrggbb
 *     #rrggbbaa
 *     #rrrgggbbb		(note: no 3 digit rrrgggbbbaaa)
 *     #rrrrggggbbbb
 *     #rrrrggggbbbbaaaa
 *     nnnnn,nnnnn,nnnnn	(integers 0 - 65535)
 *     <Icon color phrase>
 *     <native color spec>
 */

int parsecolor(wbp w, char *buf, long *r, long *g, long *b, long *a)
{
    int len, mul;
    char *fmt, c;
    double dr, dg, db = 1.0;

    *r = *g = *b = 0L;
    *a = 65535;

    /* trim leading spaces */
    while (isspace((unsigned char)*buf))
        buf++;


    /* try interpreting as three comma-separated numbers */
    if (sscanf(buf, "%lf,%lf,%lf%c", &dr, &dg, &db, &c) == 3) {
        *r = dr;
        *g = dg;
        *b = db;


        if (*r>=0 && *r<=65535 && *g>=0 && *g<=65535 && *b>=0 && *b<=65535)
            return Succeeded;
        else
            return Failed;
    }

    /* try interpreting as a hexadecimal value */
    if (*buf == '#') {
        buf++;
        for (len = 0; isalnum((unsigned char)buf[len]); len++);
        switch (len) {
            case  3:  fmt = "%1x%1x%1x%c";  mul = 0x1111;  break;
            case  4:  fmt = "%1x%1x%1x%1x%c";  mul = 0x1111;  break;
            case  6:  fmt = "%2x%2x%2x%c";  mul = 0x0101;  break;
            case  8:  fmt = "%2x%2x%2x%2x%c";  mul = 0x0101;  break;
            case  9:  fmt = "%3x%3x%3x%c";  mul = 0x0010;  break;
            case 12:  fmt = "%4x%4x%4x%c";  mul = 0x0001;  break;
            case 16:  fmt = "%4x%4x%4x%4x%c";  mul = 0x0001;  break;
            default:  return Failed;
        }
        if ((len == 4) || (len == 8) || (len == 16)) {
            if (sscanf(buf, fmt, r, g, b, a, &c) != 4)
                return Failed;
            *a *= mul;
        }
        else if (sscanf(buf, fmt, r, g, b, &c) != 3)
            return Failed;
        *r *= mul;
        *g *= mul;
        *b *= mul;
        return Succeeded;
    }


    /* try interpreting as a color phrase or as a native color spec */
    if (colorphrase(buf, r, g, b, a) || nativecolor(w, buf, r, g, b))
        return Succeeded;
    else
        return Failed;
}


/*
 *  colorphrase(s, &r, &g, &b, &a) -- parse Icon color phrase.
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

static int colorphrase(char *buf, long *r, long *g, long *b, long *a)
{
    int len, very;
    char c, *p, *ebuf, cbuffer[MAXCOLORNAME];
    float lgt, sat, blend, bl2, m1, m2, alpha;
    float h1, l1, s1, h2, l2, s2, r2, g2, b2;

    alpha = 1.0;
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

    /* check for diaphaneity adjective */
    p = bsearch(buf, (char *)transptable,
                ElemCount(transptable), ElemSize(transptable), (BSearchFncCast)strcmp);

    if (p) {
        /* skip past word */
        buf += strlen(buf) + 1;
        if (buf >= ebuf)
            return 0;
        /* save diaphaneity value, but ignore "opaque" */
        if ((((colrmod *)p) -> val) != 100)
            alpha = ((colrmod *)p) -> val / 100.0;
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
    *a = 65535 * alpha;

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

static	int	gfread		(char *fn, int p);
static	int	gfheader	(FILE *f);
static	int	gfskip		(FILE *f);
static	void	gfcontrol	(FILE *f);
static	int	gfimhdr		(FILE *f);
static	int	gfmap		(FILE *f, int p);
static	int	gfsetup		(void);
static	int	gfrdata		(FILE *f);
static	int	gfrcode		(FILE *f);
static	void	gfinsert	(int prev, int c);
static	int	gffirst		(int c);
static	void	gfgen		(int c);
static	void	gfput		(int b);

static	int	gfwrite		(wbp w, char *filename,
                                 int x, int y, int width, int height);
static	int	bmpwrite	(wbp w, char *filename,
                                 int x, int y, int width, int height);
static	void	gfpack		(unsigned char *data, long len,
                                 struct palentry *paltbl);
static	void	gfmktree	(lzwnode *tree);
static	void	gfout		(int tcode);
static	void	gfdump		(void);

static FILE *gf_f;			/* input file */

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

static unsigned char *gf_obuf;		/* output buffer */
static unsigned long gf_curr;		/* current partial byte(s) */
static int gf_valid;			/* number of valid bits */
static int gf_rem;			/* remaining bytes in this block */

#ifdef HAVE_LIBJPEG
static int jpg_space;
#endif					/* HAVE_LIBJPEG */


/*
 * Construct Icon-style paltbl from BMP-style colortable
 */
struct palentry *bmp_paltbl(int n, int *colortable)
{
    int i;
    if (!(gf_paltbl=(struct palentry *)calloc(256, sizeof(struct palentry))))
        return NULL;
    for(i=0;i<n;i++) {
        gf_paltbl[i].used = gf_paltbl[i].valid = 1;
        gf_paltbl[i].transpt = 0;
        gf_paltbl[i].clr.red = ((unsigned char)((char *)(colortable+i))[0]) * 257;
        gf_paltbl[i].clr.green = ((unsigned char)((char *)(colortable+i))[1]) * 257;
        gf_paltbl[i].clr.blue = ((unsigned char)((char *)(colortable+i))[2]) * 257;
    }
    return gf_paltbl;
}

/*
 * Construct Icon-style imgdata from BMP-style rasterdata.
 * Only trick we know about so far is to reverse rows so first row is bottom
 */
unsigned char * bmp_data(int width, int height, int bpp, unsigned char * rasterdata)
{
    int i;
    int rowbytes = width * bpp;
    unsigned char *tmp = malloc(rowbytes);

    if (tmp==NULL) return NULL;
    for(i=0;i<height/2;i++) {
        memmove(tmp, rasterdata + (i * rowbytes), rowbytes);
        memmove(rasterdata + (i * rowbytes),
                rasterdata + (height-i-1) * rowbytes, rowbytes);
        memmove(rasterdata + (height-i-1) * rowbytes, tmp, rowbytes);
    }
    free(tmp);
    return rasterdata;
}


/*
 * readBMP() - BMP file reader, patterned after readGIF().
 */
int readBMP(char *filename, int p, struct imgdata *imd)
{
    FILE *f;
    int c;
    char headerstuff[52]; /* 54 - 2 byte magic number = 52 */
    int filesize, dataoffset, width, height, compression, imagesize,
        xpixelsperm, ypixelsperm, colorsused, colorsimportant, numcolors;
    short bitcount;
    int *colortable = NULL;
    unsigned char *rasterdata;
    if ((f = fopen(filename, "rb")) == NULL) return Failed;
    if (((c = getc(f)) != 'B') || ((c = getc(f)) != 'M')) {
        fclose(f);
        return Failed;
    }
    if (fread(headerstuff, 1, 52, f) < 1) {
        fclose(f);
        return Failed;
    }
    filesize = *(int *)(headerstuff);
    dataoffset = *(int *)(headerstuff+8);
    width = *(int *)(headerstuff+16);
    height = *(int *)(headerstuff+20);
    bitcount = *(short *)(headerstuff+26);
    switch(bitcount) {
        case 1: numcolors = 1; break;
        case 4: numcolors = 16; break;
        case 8: numcolors = 256; break;
        case 16: numcolors = 65536; break;
        case 24: numcolors = 65536 * 256;
        default: {
            fclose(f);
            return Failed;
        }
    }
    compression = *(int *)(headerstuff+28);
    if (compression != 0) {
        fprintf(stderr, "warning, can't read compressed bmp's yet\n");
        fclose(f);
        return Failed;
    }

    imagesize = *(int *)(headerstuff+32);
    if (compression == 0 && (imagesize==0)) {
        imagesize = filesize - 54;
        if (bitcount <= 8) imagesize -= 4 * numcolors;
    }

    xpixelsperm = *(int *)(headerstuff+36);
    ypixelsperm = *(int *)(headerstuff+40);

    colorsused = *(int *)(headerstuff+44);
    colorsimportant = *(int *)(headerstuff+48);

    if (bitcount <= 8) {
        if ((colortable = malloc(4 * numcolors)) == NULL) {
            fclose(f); return Failed;
	}
        if (fread(colortable, 4, numcolors, f) < numcolors) {
            fclose(f); return Failed;
	}
    }
    if ((rasterdata = malloc(imagesize))) {
        if (fread(rasterdata, 1, imagesize, f) < imagesize) {
            fclose(f); return Failed;
	}
        /* OK, read the whole thing, now what to do with it ? */
        imd->width = width;
        imd->height = height;
        if (colortable) {
            imd->paltbl = bmp_paltbl(numcolors, colortable);
            imd->data = bmp_data(width, height, 1, rasterdata);
        }
        else {
            imd->paltbl = NULL;
            imd->data = bmp_data(width, height, 3, rasterdata);
        }
        return Succeeded;
    }
    fclose(f);
    return Failed;
}
/*
 * readGIF(filename, p, imd) - read GIF file into image data structure
 *
 * p is a palette number to which the GIF colors are to be coerced;
 * p=0 uses the colors exactly as given in the GIF file.
 */
int readGIF(char *filename, int p, struct imgdata *imd)
{
    int r;

    r = gfread(filename, p);			/* read image */

    if (gf_prefix) {
        free(gf_prefix);
        gf_prefix = NULL;
    }
    if (gf_suffix) {
        free(gf_suffix);
        gf_suffix = NULL;
    }
    if (gf_f) {
        fclose(gf_f);
        gf_f = NULL;
    }

    if (r != Succeeded) {			/* if no success, free mem */
        if (gf_paltbl) {
            free(gf_paltbl);
            gf_paltbl = NULL;
        }
        if (gf_string) {
            free(gf_string);
            gf_string = NULL;
        }
        return r;					/* return Failed or Error */
    }

    imd->width = gf_width;			/* set return variables */
    imd->height = gf_height;
    imd->paltbl = gf_paltbl;
    imd->data = gf_string;

    return Succeeded;				/* return success */
}

/*
 * gfread(filename, p) - read GIF file, setting gf_ globals
 */
static int gfread(char *filename, int p)
{
    int i;

    gf_f = NULL;
    gf_prefix = NULL;
    gf_suffix = NULL;
    gf_string = NULL;

    if (!(gf_paltbl=malloc(256 * sizeof(struct palentry))))
        return Failed;

#if MSWIN32
    if ((gf_f = fopen(filename, "rb")) == NULL)
#else					/* MSWIN32 */
        if ((gf_f = fopen(filename, "r")) == NULL)
#endif					/* MSWIN32 */
            return Failed;

    for (i = 0; i < 256; i++)		/* init palette table */
        gf_paltbl[i].used = gf_paltbl[i].valid = gf_paltbl[i].transpt = 0;

    if (!gfheader(gf_f))			/* read file header */
        return Failed;
    if (gf_gcmap)			/* read global color map, if any */
        if (!gfmap(gf_f, p))
            return Failed;
    if (!gfskip(gf_f))			/* skip to start of image */
        return Failed;
    if (!gfimhdr(gf_f))			/* read image header */
        return Failed;
    if (gf_lcmap)			/* read local color map, if any */
        if (!gfmap(gf_f, p))
            return Failed;
    if (!gfsetup())			/* prepare to read image */
        return Error;
    if (!gfrdata(gf_f))			/* read image data */
        return Failed;
    while (gf_row < gf_height)		/* pad if too short */
        gfput(0);

    return Succeeded;
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
 * gfmap(f, p) - read GIF color map into paltbl under control of palette p
 */
static int gfmap(FILE *f, int p)
{
    int ncolors, i, r, g, b, c;
    struct palentry *stdpal = 0;

    if (p)
        stdpal = palsetup(p);

    ncolors = 1 << gf_nbits;

    for (i = 0; i < ncolors; i++) {
        r = getc(f);
        g = getc(f);
        b = getc(f);
        if (r == EOF || g == EOF || b == EOF)
            return 0;
        if (p) {
            c = *(unsigned char *)(rgbkey(p, r / 255.0, g / 255.0, b / 255.0));
            gf_paltbl[i].clr = stdpal[c].clr;
        }
        else {
            gf_paltbl[i].clr.red   = 257 * r;	/* 257 * 255 -> 65535 */
            gf_paltbl[i].clr.green = 257 * g;
            gf_paltbl[i].clr.blue  = 257 * b;
        }
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

    len = (word)gf_width * (word)gf_height;
    gf_string = malloc(len);
    gf_prefix = malloc(GifTableSize * sizeof(short));
    gf_suffix = malloc(GifTableSize * sizeof(short));
    if (!gf_string || !gf_prefix || !gf_suffix)
        return 0;
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
    gf_paltbl[b].used = 1;		/* mark color entry as used */
}


#ifdef HAVE_LIBJPEG
/*
 * readJPEG(filename, p, imd) - read JPEG file into image data structure
 * p is a palette number to which the JPEG colors are to be coerced;
 * p=0 uses the colors exactly as given in the JPEG file.
 */
static int jpegread(char *filename, int p);

int readJPEG(char *filename, int p, struct imgdata *imd)
{
    int r;
    r = jpegread(filename, p);			/* read image */
    if (r == Failed) return Failed;

    imd->width = gf_width;		/* set return variables */
    imd->height = gf_height;
    imd->paltbl = gf_paltbl;
    imd->data = gf_string;

    return Succeeded;				/* return success */
}

void my_error_exit (j_common_ptr cinfo);

/*
 * jpegread(filename, p) - read jpeg file, setting gf_ globals
 */
static int jpegread(char *filename, int p)
{
    struct jpeg_decompress_struct cinfo; /* libjpeg struct */
    struct my_error_mgr jerr;
    JSAMPARRAY buffer;
    int row_stride;
    int i,j;
    gf_f = NULL;

#if MSWIN32
    if ((gf_f = fopen(filename, "rb")) == NULL)
#else					/* MSWIN32 */
        if ((gf_f = fopen(filename, "r")) == NULL)
#endif					/* MSWIN32 */
            return Failed;

    cinfo.err = jpeg_std_error(&jerr.pub);
    jerr.pub.error_exit = my_error_exit;

    if (setjmp(jerr.setjmp_buffer)) {
        jpeg_destroy_decompress(&cinfo);
        fclose(gf_f);
        return Failed;
    }

    jpeg_create_decompress(&cinfo);
    jpeg_stdio_src(&cinfo, gf_f);
    jpeg_read_header(&cinfo, TRUE);

    /*
     * set parameters for decompression
     */
    if (p == 1) {  /* 8-bit */
        cinfo.quantize_colors = TRUE;
        cinfo.desired_number_of_colors = 254;
    }
    else { 
        cinfo.quantize_colors = FALSE;
    }

    /* Start decompression */

    jpeg_start_decompress(&cinfo);
    gf_width = cinfo.output_width;
    gf_height = cinfo.output_height;
    row_stride = cinfo.output_width * cinfo.output_components; /* actual width of the image */

    if (p == 1) {
        if (!(gf_paltbl=malloc(256 * sizeof(struct palentry))))
            return Failed;

        for (i = 0; i < cinfo.actual_number_of_colors; i++) {
            /* init palette table */
            gf_paltbl[i].used = 1;
            gf_paltbl[i].valid = 1;
            gf_paltbl[i].transpt = 0;
            gf_paltbl[i].clr.red = cinfo.colormap[0][i] * 257;
            gf_paltbl[i].clr.green = cinfo.colormap[1][i] * 257;
            gf_paltbl[i].clr.blue = cinfo.colormap[2][i] * 257;
        }

        for(;i < 256; i++) {
            gf_paltbl[i].used = gf_paltbl[i].valid = gf_paltbl[i].transpt = 0;
        }
    }

/*   if (p == 1) */
    gf_string = calloc(jpg_space=row_stride*cinfo.output_height,
                       sizeof(unsigned char));
	
    /*
     * Make a one-row-high sample array that will go away when done with image
     */
    buffer = (*cinfo.mem->alloc_sarray)
        ((j_common_ptr) &cinfo, JPOOL_IMAGE, row_stride, 1);
    j = 0;
    while (cinfo.output_scanline < cinfo.output_height) {
/*      k = 0; */
        (void) jpeg_read_scanlines(&cinfo, buffer, 1);

        for (i=0; i<row_stride; i++) {
/*	 if (p == 1) */   /* 8bit color */
	    gf_string[j*row_stride+i] = buffer[0][i];
        }
        j += 1;
    }


    (void) jpeg_finish_decompress(&cinfo); /* jpeg lib function call */

    /*
     * Release JPEG decompression object
     */
    jpeg_destroy_decompress(&cinfo); /* jpeg lib function call */

    fclose(gf_f);
    return Succeeded;
}


/* a part of error handling */
void my_error_exit (j_common_ptr cinfo)
{
    my_error_ptr myerr = (my_error_ptr) cinfo->err;
    (*cinfo->err->output_message) (cinfo);
    longjmp(myerr->setjmp_buffer, 1);
}

#endif


/*
 * writeBMP(w, filename, x, y, width, height) - write BMP image
 *
 * Fails if filename does not end in .bmp or .BMP; default is write .GIF.
 * Returns Succeeded, Failed, or Error.
 * We assume that the area specified is within the window.
 */
int writeBMP(wbp w, char *filename, int x, int y, int width, int height)
{
    int r;
    if (strstr(filename, ".BMP")==NULL && strstr(filename,".bmp")==NULL)
        return NoCvt;

    r = bmpwrite(w, filename, x, y, width, height);
    if (gf_f) { fclose(gf_f); gf_f = NULL; }
    if (gf_string) { free(gf_string); gf_string = NULL; }
    return r;
}

/*
 * bmpwrite(w, filename, x, y, width, height) - write BMP file
 */

static int bmpwrite(wbp w, char *filename, int x, int y, int width, int height)
{
    int i, a[6];
    short sh[2];
    int len;
    struct palentry paltbl[DMAXCOLORS];

    len = width * height;	/* total length of data */

    if (!(gf_f = fopen(filename, "wb")))
        return Failed;
    if (!(gf_string = malloc(len)))
        return Error;

    for (i = 0; i < DMAXCOLORS; i++)
        paltbl[i].used = paltbl[i].valid = paltbl[i].transpt = 0;
    if (!getimstr(w, x, y, width, height, paltbl, gf_string))
        return Error;

    fprintf(gf_f, "BM");
    a[0] = 54 + 4 * 256 + len;
    a[1] = 0;
    a[2] = 54 + 4 * 256;
    a[3] = 40;
    a[4] = width;
    a[5] = height;
    if (fwrite(a, 4, 6, gf_f) < 6) return Failed;
    sh[0] = 1;
    sh[1] = 8;
    if (fwrite(sh, 2, 2, gf_f) < 2) return Failed;
    a[0] = 0;
    a[1] = len;
    a[2] = a[3] = 3938; /* presumably, hardwire to assume 100dpi */
    a[4] = 256; /* colors used */
    a[5] = 0; /* colors important */
    if (fwrite(a, 4, 6, gf_f) < 6) return Failed;

    for (i=0; i<256; i++) {
        unsigned char c[4];
        c[0] = paltbl[i].clr.red >> 8;
        c[1] = paltbl[i].clr.green >> 8;
        c[2] = paltbl[i].clr.blue >> 8;
        c[3] = 0;
        if (fwrite(c, 4, 1, gf_f) < 1) return Failed;
    }
    if (bmp_data(width, height, 1, gf_string) == NULL) return Error;
    if (fwrite(gf_string, width, height, gf_f) < height) return Failed;
    return Succeeded;
}


/*
 * writeGIF(w, filename, x, y, width, height) - write GIF image
 *
 * Returns Succeeded, Failed, or Error.
 * We assume that the area specified is within the window.
 */
int writeGIF(wbp w, char *filename, int x, int y, int width, int height)
{
    int r;

    if (strstr(filename, ".GIF")==NULL && strstr(filename,".gif")==NULL)
        return NoCvt;

    r = gfwrite(w, filename, x, y, width, height);
    if (gf_f) { fclose(gf_f); gf_f = NULL; }
    if (gf_string) { free(gf_string); gf_string = NULL; }
    return r;
}

/*
 * gfwrite(w, filename, x, y, width, height) - write GIF file
 *
 * We write GIF87a format (not 89a) for maximum acceptability and because
 * we don't need any of the extensions of GIF89.
 */

static int gfwrite(wbp w, char *filename, int x, int y, int width, int height)
{
    int i, c, cur;
    int len;
    LinearColor *cp;
    unsigned char *p, *q;
    struct palentry paltbl[DMAXCOLORS];
    unsigned char obuf[GifBlockSize];
    lzwnode tree[GifTableSize + 1];

    len = width * height;	/* total length of data */

    if (!(gf_f = fopen(filename, "wb")))
        return Failed;
    if (!(gf_string = malloc(len)))
        return Error;

    for (i = 0; i < DMAXCOLORS; i++)
        paltbl[i].used = paltbl[i].valid = paltbl[i].transpt = 0;
    if (!getimstr(w, x, y, width, height, paltbl, gf_string))
        return Error;

    gfpack(gf_string, len, paltbl);	/* pack color table, set color params */

    gf_clear = 1 << gf_cdsize;		/* set encoding variables */
    gf_eoi = gf_clear + 1;
    gf_free = gf_eoi + 1;
    gf_lzwbits = gf_cdsize + 1;

    /*
     * Write the header, global color table, and image descriptor.
     */

    fprintf(gf_f, "GIF87a%c%c%c%c%c%c%c", width, width >> 8, height, height >> 8,
            0x80 | ((gf_nbits - 1) << 4) | (gf_nbits - 1), 0, 0);


    for (i = 0; i < (1 << gf_nbits); i++) {	/* output color table */
        if (i < DMAXCOLORS && paltbl[i].valid) {
            cp = &paltbl[i].clr;
            putc(cp->red >> 8, gf_f);
            putc(cp->green >> 8, gf_f);
            putc(cp->blue >> 8, gf_f);
        }
        else {
            putc(0, gf_f);
            putc(0, gf_f);
            putc(0, gf_f);
        }
    }

    fprintf(gf_f, "%c%c%c%c%c%c%c%c%c%c%c", GifSeparator, 0, 0, 0, 0,
            width, width >> 8, height, height >> 8, gf_nbits - 1, gf_cdsize);

    /*
     * Encode and write the image.
     */
    gf_obuf = obuf;			/* initialize output state */
    gf_curr = 0;
    gf_valid = 0;
    gf_rem = GifBlockSize;

    gfmktree(tree);			/* initialize encoding tree */

    gfout(gf_clear);			/* start with CLEAR code */

    p = gf_string;
    q = p + len;
    cur = *p++;				/* first pixel is special */
    while (p < q) {
        c = *p++;				/* get code */
        for (i = tree[cur].child; i != 0; i = tree[i].sibling)
            if (tree[i].tcode == c)	/* find as suffix of previous string */
                break;
        if (i != 0) {			/* if found in encoding tree */
            cur = i;			/* note where */
            continue;			/* and accumulate more */
        }
        gfout(cur);			/* new combination -- output prefix */
        tree[gf_free].tcode = c;		/* make node for new combination */
        tree[gf_free].child = 0;
        tree[gf_free].sibling = tree[cur].child;
        tree[cur].child = gf_free;
        cur = c;				/* restart string from single pixel */
        ++gf_free;			/* grow tree to account for new node */
        if (gf_free > (1 << gf_lzwbits)) {
            if (gf_free > GifTableSize) {
                gfout(gf_clear);		/* table is full; reset to empty */
                gf_lzwbits = gf_cdsize + 1;
                gfmktree(tree);
            }
            else
                gf_lzwbits++;		/* time to make output one bit wider */
        }
    }

    /*
     * Finish up.
     */
    gfout(cur);				/* flush accumulated prefix */
    gfout(gf_eoi);			/* send EOI code */
    gf_lzwbits = 7;
    gfout(0);				/* force out last partial byte */
    gfdump();				/* dump final block */
    putc(0, gf_f);			/* terminate image (block of size 0) */
    putc(GifTerminator, gf_f);		/* terminate file */

    fflush(gf_f);
    if (ferror(gf_f))
        return Failed;
    else
        return Succeeded;			/* caller will close file */
}

/*
 * gfpack() - pack palette table to eliminate gaps
 *
 * Sets gf_nbits and gf_cdsize based on the number of colors.
 */
static void gfpack(unsigned char *data, long len, struct palentry *paltbl)
{
    int i, ncolors, lastcolor;
    unsigned char *p, *q, cmap[DMAXCOLORS];

    ncolors = 0;
    lastcolor = 0;
    for (i = 0; i < DMAXCOLORS; i++)
        if (paltbl[i].used) {
            lastcolor = i;
            cmap[i] = ncolors;		/* mapping to output color */
            if (i != ncolors) {
                paltbl[ncolors] = paltbl[i];		/* shift down */
                paltbl[i].used = paltbl[i].valid = paltbl[i].transpt = 0;
                /* invalidate old */
            }
            ncolors++;
        }

    if (ncolors < lastcolor + 1) {	/* if entries were moved to fill gaps */
        p = data;
        q = p + len;
        while (p < q) {
            *p = cmap[*p];			/* adjust color values in data string */
            p++;
        }
    }

    gf_nbits = 1;
    while ((1 << gf_nbits) < ncolors)
        gf_nbits++;
    if (gf_nbits < 2)
        gf_cdsize = 2;
    else
        gf_cdsize = gf_nbits;
}

/*
 * gfmktree() - initialize or reinitialize encoding tree
 */

static void gfmktree(lzwnode *tree)
{
    int i;

    for (i = 0; i < gf_clear; i++) {	/* for each basic entry */
        tree[i].tcode = i;			/* code is pixel value */
        tree[i].child = 0;		/* no suffixes yet */
        tree[i].sibling = i + 1;		/* next code is sibling */
    }
    tree[gf_clear - 1].sibling = 0;	/* last entry has no sibling */
    gf_free = gf_eoi + 1;		/* reset next free entry */
}

/*
 * gfout(code) - output one LZW token
 */
static void gfout(int tcode)
{
    gf_curr |= tcode << gf_valid;		/* add to current word */
    gf_valid += gf_lzwbits;		/* count the bits */
    while (gf_valid >= 8) {		/* while we have a byte to output */
        gf_obuf[GifBlockSize - gf_rem] = gf_curr;	/* put in buffer */
        gf_curr >>= 8;				/* remove from word */
        gf_valid -= 8;
        if (--gf_rem == 0)			/* flush buffer when full */
            gfdump();
    }
}

/*
 * gfdump() - dump output buffer
 */
static void gfdump()
{
    int n, dummy;

    n = GifBlockSize - gf_rem;
    putc(n, gf_f);			/* write block size */
    dummy = fwrite(gf_obuf, 1, n, gf_f); /*write block */
    gf_rem = GifBlockSize;		/* reset buffer to empty */
}


#ifdef HAVE_LIBJPEG


static int jpegwrite(wbp w, char *filename, int x, int y,int width,int height);

/*
 * writeJPEG(w, filename, x, y, width, height) - write JPEG image
 * Returns Succeeded, Failed, or Error.
 * We assume that the area specified is within the window.
 */
int writeJPEG(wbp w, char *filename, int x, int y, int width, int height)
{
    int r;

    if (strstr(filename, ".JPEG")==NULL && strstr(filename,".jpeg")==NULL
        && strstr(filename, ".JPG")==NULL && strstr(filename,".jpg")==NULL)
        return NoCvt;

    r = jpegwrite(w, filename, x, y, width, height);
    if (gf_f) fclose(gf_f);
    if (gf_string) free(gf_string);
    return r;
}


/*
 * jpegwrite(w, filename, x, y, width, height) - write JPEG file
 */

static int jpegwrite(wbp w, char *filename, int x, int y, int width,int height)
{
    int i, j;
    int len;
    struct palentry paltbl[DMAXCOLORS];

    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;

    JSAMPROW row_pointer[1];	/* pointer to JSAMPLE row[s] */
    int row_stride;		/* physical row width in image buffer */
    int quality;

    unsigned char * gf_string_pixcolor;

    gf_string_pixcolor = calloc(width*height*3, sizeof(unsigned char));

    len = width * height ;	/* total length of data */

    if (!(gf_string = malloc(len)))
        return Error;

    for (i = 0; i < DMAXCOLORS; i++)
        paltbl[i].used = paltbl[i].valid = paltbl[i].transpt = 0;

    if (!getimstr(w, x, y, width, height, paltbl, gf_string))
        return Error;

    gfpack(gf_string, len, paltbl);/* pack color table, set color params */

    quality = 95;

    for ( i = 0, j=0; j < len; i = i + 3, j++) {
        gf_string_pixcolor[i] = paltbl[gf_string[j]].clr.red;
        gf_string_pixcolor[i+1] = paltbl[gf_string[j]].clr.green;
        gf_string_pixcolor[i+2] = paltbl[gf_string[j]].clr.blue;
    }

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);

    if ((gf_f = fopen(filename,"wb")) == NULL) {
        fprintf(stderr, "can't open file" );
        exit(1);
    }

    jpeg_stdio_dest(&cinfo, gf_f);

    cinfo.image_width = width; 	/* image width and height, in pixels */
    cinfo.image_height = height;

    cinfo.input_components = 3;	/* # of color components per pixel */
    cinfo.in_color_space = JCS_RGB; /* colorspace of input image */

    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE /*limit to baseline-JPEG values */);

    jpeg_start_compress(&cinfo, TRUE);

    row_stride = cinfo.image_width *3;	/* JSAMPLEs per row in image_buffer */

    while (cinfo.next_scanline < cinfo.image_height) {
        row_pointer[0] = & gf_string_pixcolor[cinfo.next_scanline*row_stride];
        (void) jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }

    jpeg_finish_compress(&cinfo);
    fclose(gf_f);
    gf_f = NULL;
    jpeg_destroy_compress(&cinfo);
    return Succeeded;
}

#endif					/* HAVE_LIBJPEG */



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
 * palnum(d) - return palette number, or 0 if unrecognized.
 *
 *    returns +1 ... +6 for "c1" through "c6"
 *    returns +1 for &null
 *    returns -2 ... -256 for "g2" through "g256"
 *    returns 0 for unrecognized palette name
 *    returns -1 for non-string argument
 */
int palnum(dptr d)
{
    tended char *s;
    char c, x;
    int n;

    if (is:null(*d))
        return 1;
    if (!cnv:C_string(*d, s))
        return -1;
    if (sscanf(s, "%c%d%c", &c, &n, &x) != 2)
        return 0;
    if (c == 'c' && n >= 1 && n <= 6)
        return n;
    if (c == 'g' && n >= 2 && n <= 256)
        return -n;
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
    if (palsetup_palette == NULL) {
        palsetup_palette =
            malloc(256 * sizeof(struct palentry));
        if (palsetup_palette == NULL)
            return NULL;
    }
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
            e->clr.red = e->clr.green = e->clr.blue = gg;
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
            e->clr.red   = 65535 * (((int)*t++) / 48.0);
            e->clr.green = 65535 * (((int)*t++) / 48.0);
            e->clr.blue  = 65535 * (((int)*t++) / 48.0);
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
                e->clr.red = rr;
                e->clr.green = gg;
                e->clr.blue = bb;
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
            e->clr.red = e->clr.green = e->clr.blue = gg;
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
char *rgbkey(int p, double r, double g, double b)
{
    int n, i;
    double m;
    char *s;

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

/*
 * mapping from recognized style attributes to flag values
 */
stringint fontwords[] = {
    { 0,			24 },		/* number of entries */
    { "arabic",		FONTATT_CHARSET | FONTFLAG_ARABIC },
    { "bold",		FONTATT_WEIGHT	| FONTFLAG_BOLD },
    { "condensed",	FONTATT_WIDTH	| FONTFLAG_CONDENSED },
    { "cyrillic",	FONTATT_CHARSET | FONTFLAG_CYRILLIC },
    { "demi",		FONTATT_WEIGHT	| FONTFLAG_DEMI },
    { "demibold",	FONTATT_WEIGHT	| FONTFLAG_DEMI | FONTFLAG_BOLD },
    { "extended",	FONTATT_WIDTH	| FONTFLAG_EXTENDED },
    { "greek",		FONTATT_CHARSET | FONTFLAG_GREEK },
    { "hebrew",		FONTATT_CHARSET | FONTFLAG_HEBREW },
    { "italic",		FONTATT_SLANT	| FONTFLAG_ITALIC },
    { "latin1",		FONTATT_CHARSET | FONTFLAG_LATIN1 },
    { "latin2",		FONTATT_CHARSET | FONTFLAG_LATIN2 },
    { "latin6",		FONTATT_CHARSET | FONTFLAG_LATIN6 },
    { "light",		FONTATT_WEIGHT	| FONTFLAG_LIGHT },
    { "medium",		FONTATT_WEIGHT	| FONTFLAG_MEDIUM },
    { "mono",		FONTATT_SPACING	| FONTFLAG_MONO },
    { "narrow",		FONTATT_WIDTH	| FONTFLAG_NARROW },
    { "normal",		FONTATT_WIDTH	| FONTFLAG_NORMAL },
    { "oblique",		FONTATT_SLANT	| FONTFLAG_OBLIQUE },
    { "proportional",	FONTATT_SPACING	| FONTFLAG_PROPORTIONAL },
    { "roman",		FONTATT_SLANT	| FONTFLAG_ROMAN },
    { "sans",		FONTATT_SERIF	| FONTFLAG_SANS },
    { "serif",		FONTATT_SERIF	| FONTFLAG_SERIF },
    { "wide",		FONTATT_WIDTH	| FONTFLAG_WIDE },
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
int parsefont(char *s, char family[MAXFONTWORD+1], int *style, int *size)
{
    char c, *a, attr[MAXFONTWORD+1];
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
            if (isupper((unsigned char)c))
                c = tolower((unsigned char)c);
            *a++ = c;
            if (a - attr >= MAXFONTWORD)
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

/*
 * parsepattern() - parse an encoded numeric stipple pattern
 */
int parsepattern(char *s, int *width, int *nbits, int *bits)
{
    int v;
    int i, j, len, hexdigits_per_row, maxbits = *nbits;

    len = strlen(s);

    /*
     * Get the width
     */
    if (sscanf(s, "%d,", width) != 1) return Failed;
    if (*width < 1) return Failed;

    /*
     * skip over width
     */
    while ((len > 0) && isdigit((unsigned char)*s)) {
        len--; s++;
    }
    if ((len <= 1) || (*s != ',')) return Failed;
    len--; s++;					/* skip over ',' */

    if (*s == '#') {
        /*
         * get remaining bits as hex constant
         */
        s++; len--;
        if (len == 0) return Failed;
        hexdigits_per_row = *width / 4;
        if (*width % 4) hexdigits_per_row++;
        *nbits = len / hexdigits_per_row;
        if (len % hexdigits_per_row) (*nbits)++;
        if (*nbits > maxbits) return Failed;
        for (i = 0; i < *nbits; i++) {
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
                    default: return Failed;
                }
	    }
            *bits++ = v;
        }
    }
    else {
        if (*width > 32) return Failed;
        /*
         * get remaining bits as comma-separated decimals
         */
        v = 0;
        *nbits = 0;
        while (len > 0) {
            while ((len > 0) && isdigit((unsigned char)*s)) {
                v = v * 10 + *s - '0';
                len--; s++;
	    }
            (*nbits)++;
            if (*nbits > maxbits) return Failed;
            *bits++ = v;
            v = 0;

            if (len > 0) {
                if (*s == ',') { len--; s++; }
                else {
                    ReturnErrNum(205, Error);
                }
            }
        }
    }
    return Succeeded;
}


int readimagefile(char *filename, int p, struct imgdata *imd)
{
    int r;
    if ((r = readGIF(filename, p, imd)) == Succeeded)
        return Succeeded;
    if ((r = readBMP(filename, p, imd)) == Succeeded)
        return Succeeded;
#ifdef HAVE_LIBJPEG
    if ((r = readJPEG(filename, p == 0 ? 1 : p, imd)) == Succeeded)
        return Succeeded;
#endif
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
            thepoints = malloc((steps+4) * sizeof(XPoint));
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
     *  but that ignores the linewidth and linestyle attributes...
     * Might make linestyle work a little better by "compressing" straight
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


