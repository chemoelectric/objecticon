struct SharedColor {
   Image *i;            /* 1x1 image representing colour rgb */
   char  *name;
   int   rgb;          /* rgb of i */
   int   refcount;
};

struct SharedPattern {
   int width, height;    /* Data representing the pattern */
   int rowdata[MAX_PATTERN_HEIGHT];
   Image *i;             /* Cached image of the pattern computed according to fg & bg rgb and style.  It is */
                         /* recomputed as and when fg/bg rgb and/or style change. */
   char *name;
   int   fg_rgb, bg_rgb, style;
   int   refcount;
};
