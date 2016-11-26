
typedef struct Frbox Frbox;
typedef struct Frame Frame;
typedef ushort Attr;


enum
{
        /* First four bits give the foreground colour; 0 means use default */
        AttrBlackFg = 1,
        AttrRedFg = 2,
        AttrGreenFg = 3,
        AttrYellowFg = 4,
        AttrBlueFg = 5,
        AttrMagentaFg = 6,
        AttrCyanFg = 7,
        AttrWhiteFg = 8,
        AttrFg = 15,

        /* Bits 4-7 give the background colour; 0 means use default */
        AttrBlackBg = 1<<4,
        AttrRedBg = 2<<4,
        AttrGreenBg = 3<<4,
        AttrYellowBg = 4<<4,
        AttrBlueBg = 5<<4,
        AttrMagentaBg = 6<<4,
        AttrCyanBg = 7<<4,
        AttrWhiteBg = 8<<4,
        AttrBg = 15<<4,

        /* Remaining bits are on/off flags */
        AttrBold = 1<<8,
        AttrItalic = 1<<9,
        AttrUnderline = 1<<10,
        AttrInverse = 1<<11,
        AttrInvisible = 1<<12,
        AttrCrossed = 1<<13,
};

enum{
	BACK,
	HIGH,
	BORD,
	TEXT,
	HTEXT,

        ATTR_BLACK,
        ATTR_RED,
        ATTR_GREEN,
        ATTR_YELLOW,
        ATTR_BLUE,
        ATTR_MAGENTA,
        ATTR_CYAN,
        ATTR_WHITE,

	NCOL
};

enum{
        REGULAR_FONT,
        BOLD_FONT,
        ITALIC_FONT,
        BOLD_ITALIC_FONT,

        NFONT
};

#define	FRTICKW	3

struct Frbox
{
	long		wid;		/* in pixels */
	long		nrune;		/* <0 ==> negate and treat as break char */
	union{
                struct{
                        Rune    *rptr;  /* null terminated text content */
                        Attr    attr;   /* attributes of this box */
                };
		struct{
			short	bc;	/* break char */
			short	minwid;
		};
	};
};

struct Frame
{
	Font		*font;		/* regular font in the frame */
	Font		*fonts[NFONT];	/* all fonts (including regular). */
	Display		*display;	/* on which frame appears */
	Image		*b;		/* on which frame appears */
	Image		*cols[NCOL];	/* text and background colors */
	Rectangle	r;		/* in which text appears */
	Rectangle	entire;		/* of full frame */
	void			(*scroll)(Frame*, int);	/* scroll function provided by application */
	Frbox		*box;
	ulong		p0, p1;		/* selection */
	ushort		nbox, nalloc;
	ushort		maxtab;		/* max size of tab, in pixels */
	ushort		nchars;		/* # runes in frame */
	ushort		nlines;		/* # lines with text */
	ushort		maxlines;	/* total # lines in frame */
	ushort		lastlinefull;	/* last line fills frame */
	ushort		modified;	/* changed since frselect() */
	Image		*tick;	/* typing tick */
	Image		*tickback;	/* saved image under tick */
	int			ticked;	/* flag: is tick onscreen? */
};

ulong	frcharofpt(Frame*, Point);
Point	frptofchar(Frame*, ulong);
int	frdelete(Frame*, ulong, ulong);
void	frinsert(Frame*, Rune*, Attr*, uint nchar, ulong);
void	frselect(Frame*, Mousectl*);
void	frselectpaint(Frame*, Point, Point, Image*);
void	frdrawsel(Frame*, Point, ulong, ulong, int);
Point   frdrawsel0(Frame*, Point, ulong, ulong, Image*, Image*);
void	frinit(Frame*, Rectangle, Font**, Image*, Image**);
void	frsetrects(Frame*, Rectangle, Image*);
void	frclear(Frame*, int);
void    frprintattr(Attr a);
void    frdump(Frame *f);

Point	_frdraw(Frame*, Point);
void	_frgrowbox(Frame*, int);
void	_frfreebox(Frame*, int, int);
void	_frmergebox(Frame*, int);
void	_frdelbox(Frame*, int, int);
void	_frsplitbox(Frame*, int, int);
int	_frfindbox(Frame*, int, ulong, ulong);
void	_frclosebox(Frame*, int, int);
int	_frcanfit(Frame*, Point, Frbox*);
void	_frcklinewrap(Frame*, Point*, Frbox*);
void	_frcklinewrap0(Frame*, Point*, Frbox*);
void	_fradvance(Frame*, Point*, Frbox*);
int	_frnewwid(Frame*, Point, Frbox*);
int	_frnewwid0(Frame*, Point, Frbox*);
void	_frclean(Frame*, Point, int, int);
void	_frdrawtext(Frame*, Point, Image*, Image*);
void	_fraddbox(Frame*, int, int);
Point	_frptofcharptb(Frame*, ulong, Point, int);
Point	_frptofcharnb(Frame*, ulong, int);
int	_frstrlen(Frame*, int);
void	frtick(Frame*, Point, int);
void	frinittick(Frame*);
void	frredraw(Frame*);
Font    *_frboxfont(Frame *f, Frbox *b);
void    *_frmalloc(Frame *f, unsigned n);
void    *_frrealloc(Frame *f, void *p, unsigned n);


#define	NRUNE(b)	((b)->nrune<0? 1 : (b)->nrune)
