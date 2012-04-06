#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <cursor.h>
#include <mouse.h>
#include <keyboard.h>
#include <frame.h>
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
        Keepabove2,
        Keepbelow2,
        Grab,
        Ungrab,
	Set,
	Top,
	Bottom,
	Current,
	Hide,
	Unhide,
        Close,
	Delete,
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
        [Grab]          = "grab",
        [Ungrab]        = "ungrab",
        [Keepabove2]    = "keepabove",
        [Keepbelow2]    = "keepbelow",
        [Close]         = "close",
	[Delete]	= "delete",
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
        Keepabove,
        Keepbelow,
        Transientfor,
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
        [Keepabove]             = "-keepabove",
        [Keepbelow]             = "-keepbelow",
        [Transientfor]          = "-transientfor",
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


int
parsewctl(char **argp, Rectangle r, Rectangle *rp, int *pidp, int *idp, int *hiddenp, int *scrollingp,
          int *transientforp, int *noborderp, int *keepabovep, int *keepbelowp,
          int *mindxp, int *maxdxp, int *mindyp, int *maxdyp, 
          char **cdp, char *s, char *err)
{
	int cmd, param, xy, sign;
	char *t;

	*pidp = 0;
	*hiddenp = 0;
	*scrollingp = scrolling;
        *keepabovep = *keepbelowp = *noborderp = 0;
	*cdp = nil;
        *transientforp = -1;
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
			*hiddenp = 1;
			continue;
		case Noborder:
			*noborderp = 1;
			continue;
                case Keepabove:
                        *keepbelowp = 0;
                        *keepabovep = 1;
			continue;
                case Keepbelow:
                        *keepabovep = 0;
                        *keepbelowp = 1;
			continue;
		case Scrolling:
			*scrollingp = 1;
			continue;
		case Noscrolling:
			*scrollingp = 0;
			continue;
		case R:
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
			r.min.x = set(sign, r.min.x-xy, xy, r.min.x+xy);
			break;
		case Miny:
			r.min.y = set(sign, r.min.y-xy, xy, r.min.y+xy);
			break;
		case Maxx:
			r.max.x = set(sign, r.max.x-xy, xy, r.max.x+xy);
			break;
		case Maxy:
			r.max.y = set(sign, r.max.y-xy, xy, r.max.y+xy);
			break;
		case Deltax:
			r.max.x = set(sign, r.max.x-xy, r.min.x+xy, r.max.x+xy);
			break;
		case Deltay:
			r.max.y = set(sign, r.max.y-xy, r.min.y+xy, r.max.y+xy);
			break;
		case Mindx:
                        *mindxp = xy;
			break;
		case Maxdx:
                        *maxdxp = xy;
			break;
		case Mindy:
                        *mindyp = xy;
			break;
		case Maxdy:
                        *maxdyp = xy;
			break;
		case Transientfor:
                        *transientforp = xy;
			break;
		case Id:
			if(idp != nil)
				*idp = xy;
			break;
		case PID:
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

	return cmd;
}

static
int
wctlnew(Rectangle rect, char *arg, int pid, int hideit, int scrollit, int transientfor, int noborder, 
        int keepabove, int keepbelow, int mindx, int maxdx, int mindy, int maxdy,
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
            keepabove, keepbelow, mindx, maxdx, mindy, maxdy,
            pid, dir, "/bin/rc", argv);
	free(argv);	/* when new() returns, argv and args have been copied */
	return 1;
}

int
writewctl(Xfid *x, char *err)
{
        int cnt, cmd, j, id, hideit, scrollit, pid, noborder, transientfor,
            keepabove, keepbelow, mindx, maxdx, mindy, maxdy;
	Image *i;
	char *arg, *dir;
	Rectangle rect;
        int fl;
	Window *w;

	w = x->f->w;
	cnt = x->count;
	x->data[cnt] = '\0';
	id = 0;

        rect = w->i->r;
        mindx = w->mindx;
        maxdx = w->maxdx;
        mindy = w->mindy;
        maxdy = w->maxdy;
	cmd = parsewctl(&arg, rect, &rect, &pid, &id, &hideit, &scrollit, &transientfor, &noborder, 
                        &keepabove, &keepbelow, &mindx, &maxdx, &mindy, &maxdy,
                        &dir, x->data, err);
	if(cmd < 0)
		return -1;

	if(mouse->buttons!=0 && cmd>=Top){
		strcpy(err, "action disallowed when mouse active");
		return -1;
	}

	if(id != 0){
		for(j=0; j<nwindow; j++)
			if(window[j]->id == id)
				break;
		if(j == nwindow){
			strcpy(err, "no such window id");
			return -1;
		}
		w = window[j];
		if(w->deleted || w->i==nil){
			strcpy(err, "window deleted");
			return -1;
		}
	}

	switch(cmd){
	case New:
                return wctlnew(rect, arg, pid, hideit, scrollit, transientfor, noborder, 
                               keepabove, keepbelow, mindx, maxdx, mindy, maxdy,
                               dir, err);
	case Set:
		if(pid > 0)
			wsetpid(w, pid, 0);
		return 1;
	case Move:
		rect = Rect(rect.min.x, rect.min.y, rect.min.x+Dx(w->i->r), rect.min.y+Dy(w->i->r));
		/*rect = rectonscreen(rect);*/
		/* fall through */
	case Resize:
                w->mindx = mindx;
                w->maxdx = maxdx;
                w->mindy = mindy;
                w->maxdy = maxdy;
                fl = wlimitrect(w, &rect);
                /* If we didn't change the rectangle and we didn't
                 * limit the requested size, don't fire an event */
                if(!fl && eqrect(rect, w->i->r))
                    return 1;
                if (ishidden(w)) {
                    i = allocimage(display, rect, w->i->chan, 0, DWhite);
                    if(i == nil){
                        strcpy(err, Ewalloc);
                        return -1;
                    }
                    if (!w->noborder) border(i, rect, Selborder, red, ZP);
                    wsendctlmesg(w, Reshaped, ZR, i);
                } else {
                    i = allocwindow(wscreen, rect, Refbackup, DWhite);
                    if(i == nil){
                        strcpy(err, Ewalloc);
                        return -1;
                    }
                    if (!w->noborder) border(i, rect, Selborder, red, ZP);
                    wsendctlmesg(w, Reshaped, i->r, i);
                }
		return 1;
	case Scroll:
		w->scrolling = 1;
		wshow(w, w->nr);
		wsendctlmesg(w, Wakeup, ZR, nil);
		return 1;
	case Noscroll:
		w->scrolling = 0;
		wsendctlmesg(w, Wakeup, ZR, nil);
		return 1;
	case Keepabove2:
                wkeepabove(w);
		return 1;
	case Keepbelow2:
                wkeepbelow(w);
		return 1;
	case Close:
                wclosereq(w);
		return 1;
	case Top:
		wtopme(w);
		return 1;
	case Bottom:
		wbottomme(w);
		return 1;
	case Current:
		wcurrent(w);
		return 1;
	case Hide:
		switch(whide(w)){
		case -1:
			strcpy(err, "window already hidden");
			return -1;
		case 0:
			strcpy(err, "hide failed");
			return -1;
		default:
			break;
		}
		return 1;
	case Unhide:
		for(j=0; j<nhidden; j++)
			if(hidden[j] == w)
				break;
		if(j == nhidden){
			strcpy(err, "window not hidden");
			return -1;
		}
		if(wunhide(j) == 0){
			strcpy(err, "hide failed");
			return -1;
		}
		return 1;
        case Grab:
                grab = w;
                return 1;
        case Ungrab:
                grab = 0;
                return 1;
	case Delete:
		wsendctlmesg(w, Deleted, ZR, nil);
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
            keepabove, keepbelow, mindx, maxdx, mindy, maxdy;
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
                                &keepabove, &keepbelow, &mindx, &maxdx, &mindy, &maxdy,
                                &dir, buf, err);

		switch(cmd){
		case New:
                    wctlnew(rect, arg, pid, hideit, scrollit, transientfor, noborder, 
                            keepabove, keepbelow, mindx, maxdx, mindy, maxdy,
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
