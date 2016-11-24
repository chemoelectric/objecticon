#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <cursor.h>
#include <mouse.h>
#include <keyboard.h>
#include "frame.h"
#include <fcall.h>
#include <plumb.h>
#include "dat.h"
#include "fns.h"
#include <ctype.h>

char	Ebadwr[]		= "bad rectangle in wctl request";
char	Ewalloc[]		= "window allocation failed in wctl request";

/* >= Top are disallowed if mouse button is pressed */
enum
{
	New,
	Resize,
	Move,
	Scroll,
	Noscroll,
        Grabpointer,
        Ungrabpointer,
        Grabkeyboard,
        Ungrabkeyboard,
	Set,
	Top,
	Bottom,
	Current,
	Hide,
	Unhide,
        Close,
	Delete,
        Refresh2,
        Select,
};

static char *cmds[] = {
	[New]	        = "new",
	[Resize]	= "resize",
	[Move]	        = "move",
	[Scroll]	= "scroll",
	[Noscroll]	= "noscroll",
	[Set]		= "set",
	[Top]	        = "top",
	[Bottom]	= "bottom",
	[Current]	= "current",
	[Hide]	        = "hide",
	[Unhide]	= "unhide",
        [Grabpointer]   = "grabpointer",
        [Ungrabpointer] = "ungrabpointer",
        [Grabkeyboard]  = "grabkeyboard",
        [Ungrabkeyboard]= "ungrabkeyboard",
        [Close]         = "close",
	[Delete]	= "delete",
	[Refresh2]	= "refresh",
	[Select]	= "select",
	nil
};

enum
{
	Cd,
	Deltax,
	Deltay,
	Hidden,
	Id,
	Maxx,
	Maxy,
	Minx,
	Miny,
	PID,
	R,
	Scrolling,
	Noscrolling,
        Mindx,
        Maxdx,
        Mindy,
        Maxdy,
        Noborder,
        Transientfor,
        Layer,
};

static char *params[] = {
	[Cd]	 		= "-cd",
	[Deltax]		= "-dx",
	[Deltay]		= "-dy",
	[Hidden]		= "-hide",
	[Id]			= "-id",
	[Maxx]			= "-maxx",
	[Maxy]			= "-maxy",
	[Minx]			= "-minx",
	[Miny]			= "-miny",
	[PID]			= "-pid",
	[R]			= "-r",
	[Scrolling]		= "-scroll",
	[Noscrolling]		= "-noscroll",
        [Mindx]                 = "-mindx",
        [Maxdx]                 = "-maxdx",
        [Mindy]                 = "-mindy",
        [Maxdy]                 = "-maxdy",
        [Noborder]              = "-noborder",
        [Transientfor]          = "-transientfor",
	[Layer]                 = "-layer",
	nil
};

/*
 * Check that newly created window will be of manageable size
 */
int
goodrect(Rectangle r)
{
	if(!eqrect(canonrect(r), r))
		return 0;
	if(Dx(r)<100 || Dy(r)<3*font->height)
		return 0;
	/* must have some screen and border visible so we can move it out of the way */
	if(Dx(r) >= Dx(screen->r) && Dy(r) >= Dy(screen->r))
		return 0;
	/* reasonable sizes only please */
	if(Dx(r) > BIG*Dx(screen->r))
		return 0;
	if(Dy(r) > BIG*Dx(screen->r))
		return 0;
	return 1;
}

static
int
word(char **sp, char *tab[])
{
	char *s, *t;
	int i;

	s = *sp;
	while(isspace(*s))
		s++;
	t = s;
	while(*s!='\0' && !isspace(*s))
		s++;
	for(i=0; tab[i]!=nil; i++)
		if(strncmp(tab[i], t, strlen(tab[i])) == 0){
			*sp = s;
			return i;
	}
	return -1;
}

int
set(int sign, int neg, int abs, int pos)
{
	if(sign < 0)
		return neg;
	if(sign > 0)
		return pos;
	return abs;
}

Rectangle
newrect(void)
{
	static int i = 0;
	int minx, miny, dx, dy;

	dx = min(600, Dx(screen->r) - 2*Borderwidth);
	dy = min(400, Dy(screen->r) - 2*Borderwidth);
	minx = 32 + 16*i;
	miny = 32 + 16*i;
	i++;
	i %= 10;

	return Rect(minx, miny, minx+dx, miny+dy);
}

void
shift(int *minp, int *maxp, int min, int max)
{
	if(*minp < min){
		*maxp += min-*minp;
		*minp = min;
	}
	if(*maxp > max){
		*minp += max-*maxp;
		*maxp = max;
	}
}

Rectangle
rectonscreen(Rectangle r)
{
	shift(&r.min.x, &r.max.x, screen->r.min.x, screen->r.max.x);
	shift(&r.min.y, &r.max.y, screen->r.min.y, screen->r.max.y);
	return r;
}

/* permit square brackets, in the manner of %R */
int
riostrtol(char *s, char **t)
{
	int n;

	while(*s!='\0' && (*s==' ' || *s=='\t' || *s=='['))
		s++;
	if(*s == '[')
		s++;
	n = strtol(s, t, 10);
	if(*t != s)
		while((*t)[0] == ']')
			(*t)++;
	return n;
}

#define Expect(cond)  do { \
    if(!(cond)) { \
        strcpy(err, "invalid parameter for this command"); \
        return -1; \
    } \
   } while (0)


int
parsewctl(char **argp, Rectangle r, Rectangle *rp, int *pidp, int *idp, int *hiddenp, int *scrollingp,
          int *transientforp, int *noborderp, int *layerp,
          int *mindxp, int *maxdxp, int *mindyp, int *maxdyp,
          char **cdp, char *s, char *err)
{
    int cmd, param, xy, sign, got_layer = 0;
    char *t;

    *pidp = 0;
    *hiddenp = 0;
    *scrollingp = scrolling;
    *noborderp = 0;
    *cdp = nil;
    *transientforp = -1;
    *layerp = INVALID_LAYER;
    cmd = word(&s, cmds);
    if(cmd < 0){
        strcpy(err, "unrecognized wctl command");
        return -1;
    }
    if(cmd == New)
        r = newrect();

    strcpy(err, "missing or bad wctl parameter");
    while((param = word(&s, params)) >= 0){
        switch(param){	/* special cases */
            case Hidden:
                Expect(cmd == New);
                *hiddenp = 1;
                continue;
            case Noborder:
                Expect(cmd == New);
                *noborderp = 1;
                continue;
            case Scrolling:
                Expect(cmd == New);
                *scrollingp = 1;
                continue;
            case Noscrolling:
                Expect(cmd == New);
                *scrollingp = 0;
                continue;
            case R:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.min.x = riostrtol(s, &t);
                if(t == s)
                    return -1;
                s = t;
                r.min.y = riostrtol(s, &t);
                if(t == s)
                    return -1;
                s = t;
                r.max.x = riostrtol(s, &t);
                if(t == s)
                    return -1;
                s = t;
                r.max.y = riostrtol(s, &t);
                if(t == s)
                    return -1;
                s = t;
                continue;
        }
        while(isspace(*s))
            s++;
        if(param == Cd){
            Expect(cmd == New);
            *cdp = s;
            while(*s && !isspace(*s))
                s++;
            if(*s != '\0')
                *s++ = '\0';
            continue;
        }
        sign = 0;
        if(*s == '-'){
            sign = -1;
            s++;
        }else if(*s == '+'){
            sign = +1;
            s++;
        }
        if(!isdigit(*s))
            return -1;
        xy = riostrtol(s, &s);
        switch(param){
            case -1:
                strcpy(err, "unrecognized wctl parameter");
                return -1;
            case Minx:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.min.x = set(sign, r.min.x-xy, xy, r.min.x+xy);
                break;
            case Miny:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.min.y = set(sign, r.min.y-xy, xy, r.min.y+xy);
                break;
            case Maxx:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.max.x = set(sign, r.max.x-xy, xy, r.max.x+xy);
                break;
            case Maxy:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.max.y = set(sign, r.max.y-xy, xy, r.max.y+xy);
                break;
            case Deltax:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.max.x = set(sign, r.max.x-xy, r.min.x+xy, r.max.x+xy);
                break;
            case Deltay:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                r.max.y = set(sign, r.max.y-xy, r.min.y+xy, r.max.y+xy);
                break;
            case Mindx:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                *mindxp = set(sign, *mindxp-xy, xy, *mindxp+xy);
                if (*mindxp < 1) {
                    strcpy(err, "invalid mindx");
                    return -1;
                }
                break;
            case Maxdx:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                *maxdxp = set(sign, *maxdxp-xy, xy, *maxdxp+xy);
                if (*maxdxp < 1) {
                    strcpy(err, "invalid maxdx");
                    return -1;
                }
                break;
            case Mindy:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                *mindyp = set(sign, *mindyp-xy, xy, *mindyp+xy);
                if (*mindyp < 1) {
                    strcpy(err, "invalid mindy");
                    return -1;
                }
                break;
            case Maxdy:
                Expect(cmd == New || cmd == Move || cmd == Resize);
                *maxdyp = set(sign, *maxdyp-xy, xy, *maxdyp+xy);
                if (*maxdyp < 1) {
                    strcpy(err, "invalid maxdy");
                    return -1;
                }
                break;
            case Layer:
                Expect(cmd == New || cmd == Set);
                *layerp = set(sign, -xy, xy, xy);
                break;
            case Transientfor:
                Expect(cmd == New);
                if (!wlookid(xy)) {
                    strcpy(err, "invalid transientfor id");
                    return -1;
                }
                *transientforp = xy;
                break;
            case Id:
                Expect(cmd != New);
                if(idp != nil)
                    *idp = xy;
                break;
            case PID:
                Expect(cmd == New || cmd == Set);
                if(pidp != nil)
                    *pidp = xy;
                break;
        }
    }

    /**rp = rectonscreen(rectaddpt(r, screen->r.min));*/
    *rp = rectaddpt(r, screen->r.min);

    while(isspace(*s))
        s++;
    if(cmd!=New && *s!='\0'){
        strcpy(err, "extraneous text in wctl message");
        return -1;
    }

    if(argp)
        *argp = s;

    if (cmd == New) {
        if (*noborderp && *hiddenp) {
            strcpy(err, "noborder window cannot be hidden");
            return -1;
        }
        if (*transientforp != -1) {
            if (*noborderp) {
                strcpy(err, "transient window cannot be noborder");
                return -1;
            }
            if (*layerp != INVALID_LAYER) {
                strcpy(err, "transient window cannot have layer set");
                return -1;
            }
        }
    }

    return cmd;
}

static
int
wctlnew(Rectangle rect, char *arg, int pid, int hideit, int scrollit, int transientfor, int noborder, 
        int layer, int mindx, int maxdx, int mindy, int maxdy,
        char *dir, char *err)
{
	char **argv;
	Image *i;

        limitrect(noborder, mindx, maxdx, mindy, maxdy, &rect);
	argv = emalloc(4*sizeof(char*));
	argv[0] = "rc";
	argv[1] = "-c";
	while(isspace(*arg))
		arg++;
	if(*arg == '\0'){
		argv[1] = "-i";
		argv[2] = nil;
	}else{
		argv[2] = arg;
		argv[3] = nil;
	}
	if(hideit)
		i = allocimage(display, rect, screen->chan, 0, DWhite);
	else
		i = allocwindow(wscreen, rect, Refbackup, DWhite);
	if(i == nil){
		strcpy(err, Ewalloc);
		return -1;
	}
	if (!noborder) border(i, rect, Selborder, red, ZP);

	new(i, hideit, scrollit, transientfor, noborder, 
            layer, mindx, maxdx, mindy, maxdy,
            pid, dir, "/bin/rc", argv);
	free(argv);	/* when new() returns, argv and args have been copied */
	return 1;
}

int
writewctl(Xfid *x, char *err)
{
        int cnt, cmd, id, hideit, scrollit, pid, noborder, transientfor,
            mindx, maxdx, mindy, maxdy, layer;
	Image *i;
	char *arg, *dir;
	Rectangle rect;
        int fl;
	Window *w;

	w = x->f->w;
	cnt = x->count;
	x->data[cnt] = '\0';
	id = 0;

        rect = rectsubpt(w->i->r, screen->r.min);
        mindx = w->mindx;
        maxdx = w->maxdx;
        mindy = w->mindy;
        maxdy = w->maxdy;
	cmd = parsewctl(&arg, rect, &rect, &pid, &id, &hideit, &scrollit, &transientfor, &noborder, 
                        &layer, &mindx, &maxdx, &mindy, &maxdy,
                        &dir, x->data, err);
	if(cmd < 0)
		return -1;

	if(mouse->buttons!=0 && cmd>=Top){
		strcpy(err, "action disallowed when mouse active");
		return -1;
	}

	if(id != 0){
                w = wlookid(id);
		if(!w){
			strcpy(err, "no such window id");
			return -1;
		}
		if(w->deleted || w->i==nil){
			strcpy(err, "window deleted");
			return -1;
		}
	}

	switch(cmd){
	case New:
                return wctlnew(rect, arg, pid, hideit, scrollit, transientfor, noborder, 
                               layer, mindx, maxdx, mindy, maxdy,
                               dir, err);
	case Refresh2:
                wrefresh(w, w->i->r);
		return 1;
        case Set: {
		if(pid >= 0)
			wsetpid(w, pid);
                if(layer != INVALID_LAYER) {
                    if (!wsetlayer(w, layer)) {
                        strcpy(err, "cannot set window layer");
                        return -1;
                    }
                }
		return 1;
        }
	case Move:
		rect = Rect(rect.min.x, rect.min.y, rect.min.x+Dx(w->i->r), rect.min.y+Dy(w->i->r));
		/* fall through */
        case Resize: {
                int limchanged = 0, limited;
                if (w->mindx != mindx || w->maxdx != maxdx || w->mindy != mindy || w->maxdy != maxdy) {
                    limchanged = 1;
                    w->mindx = mindx;
                    w->maxdx = maxdx;
                    w->mindy = mindy;
                    w->maxdy = maxdy;
                }
                limited = wlimitrect(w, &rect);
                if(eqrect(rect, w->i->r)) {
                    /* If we didn't change the rectangle, then only
                     * send a wctl message if the size limits changed,
                     * and only send a mouse 'l' message if the
                     * rectangle was limited.  For consistency with
                     * what happens if the rectangle does change, the
                     * window is topped.
                     */
                    wtop(w);
                    if (limchanged) {
                        w->wctlready = 1;
                        wsendctlmesg(w, Wakeup);
                    }
                    if (limited)
                        sendmouseevent(w, 'l');
                } else {
                    if (w->hidden)
                        i = allocimage(display, rect, w->i->chan, 0, DWhite);
                    else
                        i = allocwindow(wscreen, rect, Refbackup, DWhite);
                    if(i == nil){
                        strcpy(err, Ewalloc);
                        return -1;
                    }
                    if (!w->noborder) border(i, rect, Selborder, red, ZP);
                    /* This will send both a wctl and a mouse reshape message */
                    wreshaped(w, i);
                    ensure_transient_stacking();
                    reconcile_stacking();
                }
		return 1;
        }
	case Scroll:
		w->scrolling = 1;
		wshow(w, w->nr);
		wsendctlmesg(w, Wakeup);
		return 1;
	case Noscroll:
		w->scrolling = 0;
		wsendctlmesg(w, Wakeup);
		return 1;
	case Close:
                wclosereq(w);
		return 1;
	case Top:
                if (!wtop(w)) {
                    strcpy(err, "cannot make window top");
                    return -1;
                }
		return 1;
	case Bottom:
                if (!wbottom(w)) {
                    strcpy(err, "cannot make window bottom");
                    return -1;
                }
		return 1;
	case Current:
                if (!wcurrent(w)) {
                    strcpy(err, "cannot make window current");
                    return -1;
                }
		return 1;
	case Hide:
		if(!whide(w)){
                    strcpy(err, "cannot hide window");
                    return -1;
		}
		return 1;
	case Unhide:
		if(!wunhide(w)){
                    strcpy(err, "cannot unhide window");
                    return -1;
		}
		return 1;
	case Select:
		if(!wselect(w)){
                    strcpy(err, "cannot select window");
                    return -1;
		}
		return 1;
        case Grabpointer:
                grabpointer = w;
                return 1;
        case Ungrabpointer:
                grabpointer = 0;
                return 1;
        case Grabkeyboard:
                grabkeyboard = w;
                return 1;
        case Ungrabkeyboard:
                grabkeyboard = 0;
                return 1;
	case Delete:
		wsendctlmesg(w, Deleted);
		return 1;
	}
	strcpy(err, "invalid wctl message");
	return -1;
}

void
wctlthread(void *v)
{
	char *buf, *arg, *dir;
	int cmd, id, pid, hideit, scrollit, noborder, transientfor,
            mindx, maxdx, mindy, maxdy, layer;
	Rectangle rect;
	char err[ERRMAX];
	Channel *c;

	c = v;

	threadsetname("WCTLTHREAD");

	for(;;){
		buf = recvp(c);
                mindx = mindy = 1;
                maxdx = maxdy = INT_MAX;
		cmd = parsewctl(&arg, ZR, &rect, &pid, &id, &hideit, &scrollit, &transientfor, &noborder, 
                                &layer, &mindx, &maxdx, &mindy, &maxdy,
                                &dir, buf, err);

		switch(cmd){
		case New:
                    wctlnew(rect, arg, pid, hideit, scrollit, transientfor, noborder, 
                            layer, mindx, maxdx, mindy, maxdy,
                            dir, err);
		}
		free(buf);
	}
}

void
wctlproc(void *v)
{
	char *buf;
	int n, eofs;
	Channel *c;

	threadsetname("WCTLPROC");
	c = v;

	eofs = 0;
	for(;;){
		buf = emalloc(messagesize);
		n = read(wctlfd, buf, messagesize-1);	/* room for \0 */
		if(n < 0)
			break;
		if(n == 0){
			if(++eofs > 20)
				break;
			continue;
		}
		eofs = 0;

		buf[n] = '\0';
		sendp(c, buf);
	}
}
