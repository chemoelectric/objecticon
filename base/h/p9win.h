typedef Point XPoint;

struct SharedColor {
   Image *i,            /* 1x1 image representing colour rgba */
         *i_trans;      /* same as i, but with a=0x80 */
   char *name;
   int   rgba;          /* rgba of i */
   int   rgba_trans;    /* rgba of i_trans */
   int   refcount;
};

struct SharedPattern {
   int width, height;    /* Data representing the pattern */
   int bits[MAXXOBJS];
   Image *i;             /* Cached image of the pattern computed according to rgba and style.  It is */
                         /* recomputed as and when rgba and/or style change. */
   char *name;
   int   rgba, style;
   int   refcount;
};

#define FS_SOLID             1
#define FS_STIPPLE           2

#define PointerMotionMask    1
#define WindowClosureMask    2
#define KeyReleaseMask       4
#define ControlMask          (1L << 16L)
#define Mod1Mask             (2L << 16L)
#define ShiftMask            (4L << 16L)
#define VirtKeyMask          (8L << 16L)

