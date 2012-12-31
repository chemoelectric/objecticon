struct SharedColor {
   Image *i;            /* 1x1 image representing colour rgb */
   char  *name;
   int   rgba;          /* rgba of i */
   int   refcount;
};

struct SharedImage {
   Image *i;
   int   refcount;
};
