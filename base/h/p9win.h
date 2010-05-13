typedef Point XPoint;

struct SharedColor {
   Image *i;            /* 1x1 image representing colour rgba */
   char  *name;
   int   rgba;          /* rgba of i */
   int   refcount;
};

struct SharedPattern {
   int width, height;    /* Data representing the pattern */
   int bits[MAXXOBJS];
   Image *i;             /* Cached image of the pattern computed according to fg & bg rgba and style.  It is */
                         /* recomputed as and when fg/bg rgba and/or style change. */
   char *name;
   int   fg_rgba, bg_rgba, style;
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

