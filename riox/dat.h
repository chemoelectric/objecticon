enum
{
	Qdir,			/* /dev for this window */
	Qcons,
	Qconsctl,
	Qcursor,
	Qwdir,
	Qwinid,
	Qwinname,
	Qkbdin,
	Qlabel,
	Qmouse,
	Qnew,
	Qscreen,
	Qscreeninfo,
	Qsnarf,
	Qtext,
	Qwctl,
	Qwindow,
	Qwininfo,
	Qwsys,		/* directory of window directories */
	Qwsysdir,		/* window directory, child of wsys */

	QMAX,
};

enum
{
	Kscrolloneup = KF|0x20,
	Kscrollonedown = KF|0x21,
};

#define	STACK	8192
#define INT_MAX               0x7fffffff
#define INT_MIN               0x80000000
#define VISIBLE_PART          50

typedef	struct	Consreadmesg Consreadmesg;
typedef	struct	Conswritemesg Conswritemesg;
typedef	struct	Stringpair Stringpair;
typedef	struct	Dirtab Dirtab;
typedef	struct	Fid Fid;
typedef	struct	Filsys Filsys;
typedef	struct	Mouseinfo	Mouseinfo;
typedef	struct	Mousereadmesg Mousereadmesg;
typedef	struct	Mousestate	Mousestate;
typedef	struct	Ref Ref;
typedef	struct	Timer Timer;
typedef	struct	Window Window;
typedef	struct	Xfid Xfid;
typedef struct  MouseEx MouseEx;
typedef struct MousectlEx MousectlEx;

enum
{
	Selborder		= 4,		/* border of selected window */
	Unselborder	= 1,		/* border of unselected window */
	Scrollwid 		= 12,		/* width of scroll bar */
	Scrollgap 		= 4,		/* gap right of scroll bar */
	BIG			= 3,		/* factor by which window dimension can exceed screen */
	TRUE		= 1,
	FALSE		= 0,
};

#define	QID(w,q)	((w<<8)|(q))
#define	WIN(q)	((((ulong)(q).path)>>8) & 0xFFFFFF)
#define	FILE(q)	(((ulong)(q).path) & 0xFF)

enum	/* control messages */
{
	Wakeup,
	Rawon,
	Rawoff,
	Holdon,
	Holdoff,
	Deleted,
	Exited,
};

struct Conswritemesg
{
	Channel	*cw;		/* chan(Stringpair) */
};

struct Consreadmesg
{
	Channel	*c1;		/* chan(tuple(char*, int) == Stringpair) */
	Channel	*c2;		/* chan(tuple(char*, int) == Stringpair) */
};

struct Mousereadmesg
{
	Channel	*cm;		/* chan(Mouse) */
};

struct Stringpair	/* rune and nrune or byte and nbyte */
{
	void		*s;
	int		ns;
};

struct MouseEx
{
        Mouse;
        uchar type;
};

struct MousectlEx
{
        MouseEx;
        Channel   *c;           /* chan(MouseEx) */
        Image *image;
};

struct Mousestate
{
	MouseEx;
	ulong	counter;	/* serial no. of mouse event */
};

struct Mouseinfo
{
	Mousestate	queue[64];
	int	ri;	/* read index into queue */
	int	wi;	/* write index */
	ulong	counter;	/* serial no. of last mouse event we received */
	ulong	lastcounter;	/* serial no. of last mouse event sent to client */
	uchar	qfull;	/* filled the queue; no more recording until client comes back */	
};	

struct Window
{
	Ref;
	QLock;
	Frame;
	Image		*i;
	MousectlEx		mc;
	Mouseinfo	mouse;
	Channel		*ck;			/* chan(Rune[10]) */
	Channel		*cctl;		/* chan(int) */
	Channel		*conswrite;	/* chan(Conswritemesg) */
	Channel		*consread;	/* chan(Consreadmesg) */
	Channel		*mouseread;	/* chan(Mousereadmesg) */
	Channel		*wctlread;		/* chan(Consreadmesg) */
	uint			nr;			/* number of runes in window */
	uint			maxr;		/* number of runes allocated in r */
	Rune			*r;
	uint			nraw;
	Rune			*raw;
	uint			org;
	uint			q0;
	uint			q1;
	uint			qh;
	int			id;
	char			name[64];
	uint			namecount;
	Rectangle		scrollr;
	/*
	 * Rio once used originwindow, so screenr could be different from i->r.
	 * Now they're always the same but the code doesn't assume so.
	*/
	Rectangle		screenr;	/* screen coordinates of window */
	int			wctlready;
	Rectangle		lastsr;
	int			topped;
	int			notefd;
	uchar		scrolling;
	uchar		noborder;
        uchar           keepabove;
        uchar           keepbelow;
        Window          *transientfor;
        Window          *transientforroot;
        Window          *rememberedfocus;           /* id of window to get focus on unhide */
        int             mindx;
        int             maxdx;
        int             mindy;
        int             maxdy;
        int             focusclickflag;      /* flag indicating whether to skip first event in just-focused window */
	Cursor		cursor;
	Cursor		*cursorp;
	uchar		holding;
	uchar		rawing;
	uchar		ctlopen;
	uchar		wctlopen;
	uchar		deleted;
	uchar		mouseopen;
        uchar           hidden;
//        uchar           grab;
	char			*label;
	int			pid;
	char			*dir;
};

int		winborder(Window*, Point);
void		winctl(void*);
void		winshell(void*);
Window*	wlookid(int);
Window*	wmk(Image*, MousectlEx*, Channel*, Channel*, int, int, int, int, int, int, int, int, int, int);
Window*	wpointto(Point);
int		wtop(Window*);
int		wbottom(Window*);
char*	wcontents(Window*, int*);
int		wbswidth(Window*, Rune);
int		wclickmatch(Window*, int, int, int, uint*);
int		wclose(Window*);
int		wctlmesg(Window*, int);
uint		wbacknl(Window*, uint, uint);
uint		winsert(Window*, Rune*, int, uint);
void		waddraw(Window*, Rune*, int);
int             wstatestring(Window *w, char *dest, int destsize);
void		wborder(Window*, int);
void		wclosewin(Window*);
int		wcurrent(Window*);
void            choosewcurrent(void);
void		wcut(Window*);
void		wdelete(Window*, uint, uint);
void		wdoubleclick(Window*, uint*, uint*);
void		wfill(Window*);
void		wframescroll(Window*, int);
void		wkeyctl(Window*, Rune);
void		wmousectl(Window*);
void		wmovemouse(Window*, Point);
void		wpaste(Window*);
void		wplumb(Window*);
void		wrefresh(Window*, Rectangle);
void		wrepaint(Window*);
void		wresize(Window*, Image*);
void		wreshaped(Window *w, Image *i);
void		wscrdraw(Window*);
void		wscroll(Window*, int);
void		wselection(Window*);
void		wsendctlmesg(Window*, int);
void		wsetcursor(Window*, int);
void		wsetname(Window*);
void		wsetorigin(Window*, uint, int);
void		wsetpid(Window*, int, int);
void		wsetselect(Window*, uint, uint);
void		wshow(Window*, uint);
void		wsnarf(Window*);
void 		wscrsleep(Window*, uint);
void		wsetcols(Window*);

struct Dirtab
{
	char		*name;
	uchar	type;
	uint		qid;
	uint		perm;
};

struct Fid
{
	int		fid;
	int		busy;
	int		open;
	int		mode;
	Qid		qid;
	Window	*w;
	Dirtab	*dir;
	Fid		*next;
	int		nrpart;
	uchar	rpart[UTFmax];
};

struct Xfid
{
		Ref;
		Xfid		*next;
		Xfid		*free;
		Fcall;
		Channel	*c;	/* chan(void(*)(Xfid*)) */
		Fid		*f;
		uchar	*buf;
		Filsys	*fs;
		QLock	active;
		int		flushing;	/* another Xfid is trying to flush us */
		int		flushtag;	/* our tag, so flush can find us */
		Channel	*flushc;	/* channel(int) to notify us we're being flushed */
};

Channel*	xfidinit(void);
void		xfidctl(void*);
void		xfidflush(Xfid*);
void		xfidattach(Xfid*);
void		xfidopen(Xfid*);
void		xfidclose(Xfid*);
void		xfidread(Xfid*);
void		xfidwrite(Xfid*);

enum
{
	Nhash	= 16,
};

struct Filsys
{
		int		cfd;
		int		sfd;
		int		pid;
		char		*user;
		Channel	*cxfidalloc;	/* chan(Xfid*) */
		Fid		*fids[Nhash];
};

Filsys*	filsysinit(Channel*);
int		filsysmount(Filsys*, int);
Xfid*		filsysrespond(Filsys*, Xfid*, Fcall*, char*);
void		filsyscancel(Xfid*);

void		wctlproc(void*);
void		wctlthread(void*);

void		deletetimeoutproc(void*);

struct Timer
{
	int		dt;
	int		cancel;
	Channel	*c;	/* chan(int) */
	Timer	*next;
};

Font		*font;
Mousectl	*mousectl;
Mouse	*mouse;
Keyboardctl	*keyboardctl;
Display	*display;
Image	*view;
Screen	*wscreen;
Cursor	boxcursor;
Cursor	crosscursor;
Cursor	sightcursor;
Cursor	whitearrow;
Cursor	query;
Cursor	*corners[9];
Image	*background;
Image	*lightgrey;
Image	*red;
Window	**window;
Window	*wkeyboard;	/* window of simulated keyboard */
int		nwindow;
int		topped;
int		snarffd;
Window	*input;
Window	*grab, *eein, *held;
Window *over, *overb, *overw;
QLock	all;			/* BUG */
Filsys	*filsys;
int		nsnarf;
Rune*	snarf;
int		scrolling;
int		maxtab;
Channel*	winclosechan;
Channel*	deletechan;
char		*startdir;
int		sweeping;
int		wctlfd;
char		srvpipe[];
char		srvwctl[];
int		errorshouldabort;
int		menuing;		/* menu action is pending; waiting for window to be indicated */
int		snarfversion;	/* updated each time it is written */
int		messagesize;		/* negotiated in 9P version setup */
