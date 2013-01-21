#if XWindows

#define RootState IconicState+1
#define MaximizedState IconicState+2
#define HiddenState IconicState+3
#define PopupState IconicState+4
#define FullScreenState IconicState+5

#define EndDisc 1
#define EndSquare 2

#define MAXDISPLAYNAME	64
#define NUMCURSORSYMS	78

/* Interned atoms array */
#define NUMATOMS        22
#define ATOM_CHARACTER_POSITION    0
#define ATOM_CLIENT_WINDOW         1
#define ATOM_HOSTNAME              2
#define ATOM_HOST_NAME             3
#define ATOM_LENGTH                4
#define ATOM_LIST_LENGTH           5
#define ATOM_NAME                  6
#define ATOM_OWNER_OS              7
#define ATOM_SPAN                  8
#define ATOM_TARGETS               9
#define ATOM_TIMESTAMP            10
#define ATOM_USER                 11
#define ATOM_WM_DELETE_WINDOW     12
#define ATOM__OBJECTICON_PROP     13
#define ATOM__NET_WM_STATE_MAXIMIZED_VERT 14
#define ATOM__NET_WM_STATE_MAXIMIZED_HORZ 15
#define ATOM__NET_WM_STATE_FULLSCREEN     16
#define ATOM__NET_WM_STATE                17
#define ATOM__NET_WM_ICON                 18
#define ATOM__NET_WM_NAME                 19
#define ATOM_UTF8_STRING                  20
#define ATOM_WM_STATE                     21

#define _NET_WM_STATE_ADD            1
#define _NET_WM_STATE_REMOVE         0

struct SharedColor {
   XRenderColor color;
   Picture brush;
   char  *name;
   int   refcount;
};

struct SharedPicture {
   Picture i;
   Pixmap pix;
   int width, height;
   int refcount;
};


#endif                                  /* XWindows */
