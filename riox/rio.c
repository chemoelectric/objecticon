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

/*
 *  WASHINGTON (AP) - The Food and Drug Administration warned
 * consumers Wednesday not to use ``Rio'' hair relaxer products
 * because they may cause severe hair loss or turn hair green....
 *    The FDA urged consumers who have experienced problems with Rio
 * to notify their local FDA office, local health department or the
 * company at 1‑800‑543‑3002.
 */

void		newtile(int);
Image	*sweep(Window *);
Image	*bandsize(Window*);
Image*	drag(Window*, Rectangle*);
void		refresh(Rectangle);
void		resized(void);
Channel	*exitchan;	/* chan(int) */
Channel	*winclosechan; /* chan(Window*); */
Rectangle	viewr;
int		threadrforkflag = 0;	/* should be RFENVG but that hides rio from plumber */

void	mousethread(void*);
void	keyboardthread(void*);
void winclosethread(void*);
void deletethread(void*);
void	initcmd(void*);

char		*fontname;
int		mainpid;
int             classic = 0;

static int hasexit;

char *rcargv[] = { "rc", "-i", nil };
char *kbdargv[] = { "rc", "-c", nil, nil };

int errorshouldabort = 0;

void
derror(Display*, char *errorstr)
{
	error(errorstr);
}

void
usage(void)
{
	fprint(2, "usage: riox [-x] [-f font] [-i initcmd] [-k kbdcmd] [-s]\n");
	exits("usage");
}

void
threadmain(int argc, char *argv[])
{
        char *initstr, *kbdin, *s;
	static void *arg[1];
	char buf[256];
	Image *i;
	Rectangle r;
	initstr = nil;
	kbdin = nil;
	maxtab = 0;
	ARGBEGIN{
	case 'x':
                hasexit = 1;
                break;
	case 'c':
                classic = 1;
                break;
	case 'f':
		fontname = ARGF();
		if(fontname == nil)
			usage();
		break;
	case 'i':
		initstr = ARGF();
		if(initstr == nil)
			usage();
		break;
	case 'k':
		if(kbdin != nil)
			usage();
		kbdin = ARGF();
		if(kbdin == nil)
			usage();
		break;
	case 's':
		scrolling = TRUE;
		break;
	}ARGEND

        /* Protect environment vars (font, wsys, wctl) with -x */
        if (hasexit)
            rfork(RFENVG);

	mainpid = getpid();
	if(getwd(buf, sizeof buf) == nil)
		startdir = estrdup(".");
	else
		startdir = estrdup(buf);
	if(fontname == nil)
		fontname = getenv("font");
	if(fontname == nil)
		fontname = "/lib/font/bit/lucm/unicode.9.font";
	s = getenv("tabstop");
	if(s != nil)
		maxtab = strtol(s, nil, 0);
	if(maxtab == 0)
		maxtab = 4;
	free(s);
	/* check font before barging ahead */
	if(access(fontname, 0) < 0){
		fprint(2, "rio: can't access %s: %r\n", fontname);
		exits("font open");
	}
	putenv("font", fontname);

	snarffd = open("/dev/snarf", OREAD|OCEXEC);
	if(geninitdraw(nil, derror, nil, "rio", nil, Refnone) < 0){
		fprint(2, "rio: can't open display: %r\n");
		exits("display open");
	}
	iconinit();
        fontinit();
        colorinit();
	view = screen;
	viewr = view->r;
	mousectl = initmouse(nil, screen);
	if(mousectl == nil)
		error("can't find mouse");
	mouse = mousectl;
	keyboardctl = initkeyboard(nil);
	if(keyboardctl == nil)
		error("can't find keyboard");
	wscreen = allocscreen(screen, background, 0);
	if(wscreen == nil)
		error("can't allocate screen");
	draw(view, viewr, background, nil, ZP);
	flushimage(display, 1);

	exitchan = chancreate(sizeof(int), 0);
	winclosechan = chancreate(sizeof(Window*), 0);
	deletechan = chancreate(sizeof(char*), 0);

	timerinit();
	threadcreate(keyboardthread, nil, STACK);
	threadcreate(mousethread, nil, STACK);
	threadcreate(winclosethread, nil, STACK);
	threadcreate(deletethread, nil, STACK);

	filsys = filsysinit(xfidinit());

	if(filsys == nil)
		fprint(2, "rio: can't create file system server: %r\n");
	else{
		errorshouldabort = 1;	/* suicide if there's trouble after this */
		if(initstr)
			proccreate(initcmd, initstr, STACK);
		if(kbdin){
			kbdargv[2] = kbdin;
			r = screen->r;
			r.max.x = r.min.x+300;
			r.max.y = r.min.y+80;
			i = allocwindow(wscreen, r, Refbackup, DWhite);
			wkeyboard = new(i, FALSE, scrolling, -1, 0, 
                                        0, 1, INT_MAX, 1, INT_MAX,
                                        0, nil, "/bin/rc", kbdargv);
			if(wkeyboard == nil)
				error("can't create keyboard window");
		}
		threadnotify(shutdown, 1);
		recv(exitchan, nil);
	}
	killprocs();
	threadexitsall(nil);
}

/*
 * /dev/snarf updates when the file is closed, so we must open our own
 * fd here rather than use snarffd
 */
void
putsnarf(void)
{
	int fd, i, n;

	if(snarffd<0 || nsnarf==0)
		return;
	fd = open("/dev/snarf", OWRITE);
	if(fd < 0)
		return;
	/* snarf buffer could be huge, so fprint will truncate; do it in blocks */
	for(i=0; i<nsnarf; i+=n){
		n = nsnarf-i;
		if(n >= 256)
			n = 256;
		if(fprint(fd, "%.*S", n, snarf+i) < 0)
			break;
	}
	close(fd);
}

void
getsnarf(void)
{
	int i, n, nb, nulls;
	char *sn, buf[1024];

	if(snarffd < 0)
		return;
	sn = nil;
	i = 0;
	seek(snarffd, 0, 0);
	while((n = read(snarffd, buf, sizeof buf)) > 0){
		sn = erealloc(sn, i+n+1);
		memmove(sn+i, buf, n);
		i += n;
		sn[i] = 0;
	}
	if(i > 0){
		snarf = runerealloc(snarf, i+1);
		cvttorunes(sn, i, snarf, &nb, &nsnarf, &nulls);
		free(sn);
	}
}

void
initcmd(void *arg)
{
	char *cmd;

	cmd = arg;
	rfork(RFENVG|RFFDG|RFNOTEG|RFNAMEG);
	procexecl(nil, "/bin/rc", "rc", "-c", cmd, nil);
	fprint(2, "rio: exec failed: %r\n");
	exits("exec");
}

char *oknotes[] =
{
	"delete",
	"hangup",
	"kill",
	"exit",
	nil
};

int
shutdown(void *, char *msg)
{
	int i;
	static Lock shutdownlk;
	
	killprocs();
	for(i=0; oknotes[i]; i++)
		if(strncmp(oknotes[i], msg, strlen(oknotes[i])) == 0){
			lock(&shutdownlk);	/* only one can threadexitsall */
			threadexitsall(msg);
		}
	fprint(2, "rio %d: abort: %s\n", getpid(), msg);
	abort();
	exits(msg);
	return 0;
}

void
killprocs(void)
{
	int i;

	for(i=0; i<nwindow; i++)
		postnote(PNGROUP, window[i]->pid, "hangup");
}

void
keyboardthread(void*)
{
	Rune buf[2][20], *rp;
	int n, i;

	threadsetname("keyboardthread");
	n = 0;
	for(;;){
		rp = buf[n];
		n = 1-n;
		recv(keyboardctl->c, rp);
		for(i=1; i<nelem(buf[0])-1; i++)
			if(nbrecv(keyboardctl->c, rp+i) <= 0)
				break;
		rp[i] = L'\0';
                if(grabkeyboard != nil)
			sendp(grabkeyboard->ck, rp);
		else if(input != nil)
			sendp(input->ck, rp);
	}
}

/*
 * Used by /dev/kbdin
 */
void
keyboardsend(char *s, int cnt)
{
	Rune *r;
	int i, nb, nr;

	r = runemalloc(cnt);
	/* BUGlet: partial runes will be converted to error runes */
	cvttorunes(s, cnt, r, &nb, &nr, nil);
	for(i=0; i<nr; i++)
		send(keyboardctl->c, &r[i]);
	free(r);
}

int
portion(int x, int lo, int hi)
{
	x -= lo;
	hi -= lo;
	if(x < 20)
		return 0;
	if(x > hi-20)
		return 2;
	return 1;
}

int
whichcorner(Window *w, Point p)
{
	int i, j;
	
	i = portion(p.x, w->screenr.min.x, w->screenr.max.x);
	j = portion(p.y, w->screenr.min.y, w->screenr.max.y);
	return 3*j+i;
}

void
cornercursor(Window *w, Point p, int force)
{
	if(w!=nil && winborder(w, p)) {
                int t = whichcorner(w, p);
                if (classic || t % 2 == 0) {
                    if (resizable(w))
                        riosetcursor(corners[whichcorner(w, p)], force);
                    else
                        wsetcursor(w, force);
                } else
                        riosetcursor(&boxcursor, force);
	} else
		wsetcursor(w, force);
}

/* thread to allow fsysproc to synchronize window closing with main proc */
void
winclosethread(void*)
{
	Window *w;

	threadsetname("winclosethread");
	for(;;){
		w = recvp(winclosechan);
		wclose(w);
	}
}

/* thread to make Deleted windows that the client still holds disappear offscreen after an interval */
void
deletethread(void*)
{
	char *s;
	Image *i;

	threadsetname("deletethread");
	for(;;){
		s = recvp(deletechan);
		i = namedimage(display, s);
		if(i != nil){
			/* move it off-screen to hide it, since client is slow in letting it go */
			originwindow(i, i->r.min, view->r.max);
		}
		freeimage(i);
		free(s);
	}
}

void
deletetimeoutproc(void *v)
{
	char *s;

	s = v;
	sleep(750);	/* remove window from screen after 3/4 of a second */
	sendp(deletechan, s);
}

/*
 * Button 6 - keyboard toggle - has been pressed.
 * Send event to keyboard, wait for button up, send that.
 * Note: there is no coordinate translation done here; this
 * is just about getting button 6 to the keyboard simulator.
 */
void
keyboardhide(void)
{
	send(wkeyboard->mc.c, mouse);
	do
		readmouse(mousectl);
	while(mouse->buttons & (1<<5));
	send(wkeyboard->mc.c, mouse);
}

void
sendmouseevent(Window *w, uchar type)
{
    MouseEx tmp;
    tmp.Mouse = mousectl->Mouse;
    tmp.xy.x = mousectl->xy.x + (w->i->r.min.x-w->screenr.min.x);
    tmp.xy.y = mousectl->xy.y + (w->i->r.min.y-w->screenr.min.y);
    tmp.type = type;
    send(w->mc.c, &tmp);
}

static void enterexit(Window *now, Window *evwin)
{
    if (eein != now && now)
        sendmouseevent(now, 'e');
    if (evwin)
        sendmouseevent(evwin, 'm');
    if (eein != now && eein)
        sendmouseevent(eein, 'x');
    eein = now;
}

static void doresize(Window *w)
{
    Image *i;
    i = bandsize(w);
    if(i != nil){
        wreshaped(w, i);
        cornercursor(w, mouse->xy, 1);
        ensure_transient_stacking();
        reconcile_stacking();
    }
}

static void domove(Window *w)
{
    Rectangle r;
    Image *i;
    i = drag(w, &r);
    if(i != nil){
        wreshaped(w, i);
        cornercursor(w, mouse->xy, 1);
        ensure_transient_stacking();
        reconcile_stacking();
    }
}

static void
pressed(Window *w)
{
    if(!w->topped == topped && input == w || w->noborder)
        return;
    wtop(w);
    wcurrent(w);
    flushimage(display, 1);
}

static void domouse(void)
{
    static int oldbuttons;
    int press;

    if (grabpointer) {
        overw = over = grabpointer;
        overb = 0;
    } else {
        overw = wpointto(mouse->xy);
        if (overw) {
            if (overw->noborder || ptinrect(mouse->xy, insetrect(overw->screenr, Selborder))) {
                over = overw;
                overb = 0;
            } else {
                overb = overw;
                over = 0;
            }
        } else
            over = overb = 0;

        /* Enter/exit events */
        if (eein != over) {
            if (eein) sendmouseevent(eein, 'x');
            if (over) sendmouseevent(over, 'e');
            eein = over;
        }
    }

    if (mouse->buttons & 120) {
        /* One of the four mouse wheel buttons */
        if (held)
            sendmouseevent(held, 'm');
        else if (over)
            sendmouseevent(over, 'm');
    } else {
        /* Which buttons have been pressed */
        press = ~oldbuttons & mouse->buttons;

        if (press) {
            if (held)
                sendmouseevent(held, 'm');
            else {
                /* Top and give focus if appropriate.  The last &&
                 * indicates not to give focus on the right-click context
                 * menu (button3wmenu) */
                if ((press & 7) && overw && !grabpointer && !(overb && !classic && ((press & 5) == 4)))
                    pressed(overw);
                held = over;
                if (held)
                    sendmouseevent(held, 'm');

                if (overb) {
                    if (press & 1) {
                        if (classic || whichcorner(overb, mouse->xy) % 2 == 0)
                            doresize(overb);
                        else
                            domove(overb);
                    } else if (press & 4) {
                        if (classic)
                            domove(overb);
                        else {
                            riosetcursor(nil, 0);
                            button3wmenu(overb);
                        }
                    }
                } else if (!over && (press & 4)) {
                    if (classic)
                        classic_button3menu();
                    else
                        button3menu();
                } else if((press & 6) && over && !over->mouseopen && !ptinrect(mouse->xy, over->scrollr)) {
                    if (press & 4) {
                        if (classic)
                            classic_button3menu();
                        else
                            button3txtmenu(over);
                    } else {  /* press & 2 */
                        if (classic)
                            button3txtmenu(over);
                        else
                            wmpress(over);
                    }
                    held = 0;
                }
            }
        } else if (mouse->buttons == 0) {
            if (oldbuttons == 0) {
                if (over) sendmouseevent(over, 'm');
            } else {
                if (held) sendmouseevent(held, 'm');
            }
            if (overb)
                cornercursor(overb, mouse->xy, 0);
            else
                wsetcursor(over, 0);
            held = 0;
        } else {
            if (held)
                sendmouseevent(held, 'm');
        }

        oldbuttons = mouse->buttons;
    }
}

void
mousethread(void*)
{
	enum {
		MReshape,
		MMouse,
		NALT
	};
	static Alt alts[NALT+1];

	threadsetname("mousethread");

	alts[MReshape].c = mousectl->resizec;
	alts[MReshape].v = nil;
	alts[MReshape].op = CHANRCV;
	alts[MMouse].c = mousectl->c;
	alts[MMouse].v = &mousectl->Mouse;
	alts[MMouse].op = CHANRCV;
	alts[NALT].op = CHANEND;

	for(;;)
	    switch(alt(alts)){
		case MReshape:
			resized();
			break;
		case MMouse:
                    domouse();
                    break;
		}
}

void
resized(void)
{
	Image *im;
	int i;
	Rectangle r;
	Point o, n;
	Window *w;

//	if(getwindow(display, Refnone) < 0)
//		error("failed to re-attach window");
        /* There seems to be a race condition at startup which causes this to fail occasionally.  As we
         * seem to get several reshapes, it doesn't matter if we miss one */
	if(getwindow(display, Refnone) < 0) {
            return;
        }
	freescrtemps();
	view = screen;
	freescreen(wscreen);
	wscreen = allocscreen(screen, background, 0);
	if(wscreen == nil)
		error("can't re-allocate screen");
	draw(view, view->r, background, nil, ZP);
	o = subpt(viewr.max, viewr.min);
	n = subpt(view->clipr.max, view->clipr.min);
	for(i=0; i<nwindow; i++){
		w = window[i];
		if(w->deleted)
			continue;
		r = rectsubpt(w->i->r, viewr.min);
		r.min.x = (r.min.x*n.x)/o.x;
		r.min.y = (r.min.y*n.y)/o.y;
		r.max.x = (r.max.x*n.x)/o.x;
		r.max.y = (r.max.y*n.y)/o.y;
		r = rectaddpt(r, screen->clipr.min);
                wlimitrect(w, &r);
		if(w->hidden)
			im = allocimage(display, r, screen->chan, 0, DWhite);
		else
			im = allocwindow(wscreen, r, Refbackup, DWhite);
		if(im)
                    wreshaped(w, im);
	}
	viewr = screen->r;
	flushimage(display, 1);
}

#define MAX_WIN_MENU 100

void
button3menu(void)
{
        int i, j, n = 0;
        int mnew, exit = -2;
        char *menustr[MAX_WIN_MENU];
        Window *menuwin[MAX_WIN_MENU];
        Menu menu = { menustr };

        menustr[mnew = n++] = estrdup("New");
	if(hasexit)
            menustr[exit = n++] = estrdup("Exit");

	for(j = 0; j < nwindow && n < MAX_WIN_MENU - 1; j++) {
            Window *w = window[j];
            if (!w->noborder && !w->transientfor) {
                menuwin[n] = w;
                menustr[n] = emalloc(strlen(w->label) + 5);
                if (input && input->transientforroot == w)
                    sprint(menustr[n], "* %s", w->label);
                else if (w->hidden)
                    sprint(menustr[n], "H %s", w->label);
                else
                    sprint(menustr[n], "  %s", w->label);
                ++n;
            }
        }
        menustr[n] = 0;

	sweeping = 1;
	i = menuhit(3, mousectl, &menu, wscreen);
        if (i == mnew)
            new(sweep(nil), FALSE, scrolling, -1, 0, 
                0, 1, INT_MAX, 1, INT_MAX,
                0, nil, "/bin/rc", nil);
        else if (i == exit)
            send(exitchan, nil);
        else if (i > 0)
            wselect(menuwin[i]);
	sweeping = 0;
        for (i = 0; i < n; ++i)
            free(menustr[i]);
}

void
classic_button3menu(void)
{
    int i, j, n = 0;
    int mnew, resize, move, delete, hide, exit = -2;
    char *menustr[MAX_WIN_MENU];
    Window *w, *menuwin[MAX_WIN_MENU];
    Menu menu = { menustr };
    menustr[mnew = n++] = estrdup("New");
    menustr[resize = n++] = estrdup("Resize");
    menustr[move = n++] = estrdup("Move");
    menustr[delete = n++] = estrdup("Delete");
    menustr[hide = n++] = estrdup("Hide");
    if(hasexit)
        menustr[exit = n++] = estrdup("Exit");
    for(j = 0; j < nwindow && n < MAX_WIN_MENU - 1; j++) {
        Window *w = window[j];
        if (!w->noborder && !w->transientfor && w->hidden) {
            menuwin[n] = w;
            menustr[n] = emalloc(strlen(w->label) + 5);
            sprint(menustr[n], "%s", w->label);
            ++n;
        }
    }
    menustr[n] = 0;

    sweeping = 1;
    i = menuhit(3, mousectl, &menu, wscreen);
    if (i == mnew)
        new(sweep(nil), FALSE, scrolling, -1, 0, 
            0, 1, INT_MAX, 1, INT_MAX,
            0, nil, "/bin/rc", nil);
    else if (i == resize) {
	w = pointto(TRUE);
        if (w && !w->noborder) {
            Image *j = sweep(nil);
            if (j) {
                Rectangle r = j->r;
                if (wlimitrect(w, &r)) {
                    freeimage(j);
                    j = allocwindow(wscreen, r, Refbackup, DWhite);
                }
                if (j) {
                    wreshaped(w, j);
                    wcurrent(w);
                    cornercursor(w, mouse->xy, 1);
                    ensure_transient_stacking();
                    reconcile_stacking();
                }
            }
        }
    } else if (i == move) {
	w = pointto(FALSE);
        if (w && !w->noborder) {
            Rectangle r;
            Image *j = drag(w, &r);
            if (j) {
                wreshaped(w, j);
                wcurrent(w);
                cornercursor(w, mouse->xy, 1);
                ensure_transient_stacking();
                reconcile_stacking();
            }
        }
    } else if (i == delete) {
	w = pointto(TRUE);
	if (w)
            wsendctlmesg(w, Deleted);
    } else if (i == hide) {
	w = pointto(TRUE);
	if (w)
            whide(w);
    } else if (i == exit)
        send(exitchan, nil);
    else if (i > 0)
        wselect(menuwin[i]);
    sweeping = 0;
    for (i = 0; i < n; ++i)
        free(menustr[i]);
}

void
button3wmenu(Window *w)
{
	int i = 0;
        int hide = -2, close, keepabove = -2, keepbelow = -2, keepnormal = -2, delete = -2;
        char *menustr[6];
        Menu menu = { menustr };

        if (!w->transientfor)
            menustr[hide = i++] = "Hide";

        if (w->mouseopen)
            menustr[close = i++] = "Close";
        if (!w->transientfor) {
            if (w->layer != 0)
                menustr[keepnormal = i++] = "Keep normal";
            if (w->layer <= 0)
                menustr[keepabove = i++] = "Keep above";
            if (w->layer >= 0)
                menustr[keepbelow = i++] = "Keep below";
            menustr[delete = i++] = "Delete";
        }
        if (i == 0)
            return;
        menustr[i] = 0;
	i = menuhit(3, mousectl, &menu, wscreen);
        if (i == hide)
            whide(w);
        else if (i == close)
            wclosereq(w);
        else if (i == keepabove)
            wsetlayer(w, 1);
        else if (i == keepbelow)
            wsetlayer(w, -1);
        else if (i == keepnormal)
            wsetlayer(w, 0);
        else if (i == delete)
            wsendctlmesg(w, Deleted);
}

enum
{
	Cut,
	Paste,
	Snarf,
	Plumb,
	Send,
	Scroll,
};

void
button3txtmenu(Window *w)
{
        char *menu2str[] = {
          [Cut]           "cut",
          [Paste]         "paste",
          [Snarf]         "copy",
          [Plumb]         "plumb",
          [Send]          "send",
          [Scroll]        "scroll",
          nil
        };
 
        Menu menu2 = { menu2str };

	if(w->deleted)
		return;
	incref(w);
        if(classic)
                menu2str[Snarf] = "snarf";
	if(w->scrolling)
		menu2str[Scroll] = "noscroll";
	else
		menu2str[Scroll] = "scroll";
	switch(menuhit(classic ? 2:3, mousectl, &menu2, wscreen)){
	case Cut:
		wsnarf(w);
		wcut(w);
		wscrdraw(w);
		break;

	case Snarf:
		wsnarf(w);
		break;

	case Paste:
		getsnarf();
		wpaste(w);
		wscrdraw(w);
		break;

	case Plumb:
		wplumb(w);
		break;

	case Send:
		getsnarf();
		wsnarf(w);
		if(nsnarf == 0)
			break;
		if(w->rawing){
			waddraw(w, snarf, nsnarf);
			if(snarf[nsnarf-1]!='\n' && snarf[nsnarf-1]!='\004')
				waddraw(w, L"\n", 1);
		}else{
                        winsert(w, snarf, 0, nsnarf, w->nr);
			if(snarf[nsnarf-1]!='\n' && snarf[nsnarf-1]!='\004')
                               winsert(w, L"\n", 0, 1, w->nr);
		}
		wsetselect(w, w->nr, w->nr);
		wshow(w, w->nr);
		break;

	case Scroll:
		if(w->scrolling ^= 1)
			wshow(w, w->nr);
		break;
	}
	wclose(w);
	wsendctlmesg(w, Wakeup);
	flushimage(display, 1);
}

Point
onscreen(Point p)
{
	p.x = max(screen->clipr.min.x, p.x);
	p.x = min(screen->clipr.max.x, p.x);
	p.y = max(screen->clipr.min.y, p.y);
	p.y = min(screen->clipr.max.y, p.y);
	return p;
}

Image*
sweep(Window *w)
{
	Image *i, *oi;
	Rectangle r;
	Point p0, p;

	i = nil;
	menuing = TRUE;
	riosetcursor(&crosscursor, 1);
	while(mouse->buttons == 0)
		readmouse(mousectl);
	p0 = onscreen(mouse->xy);
	p = p0;
	r.min = p;
	r.max = p;
        if (w) wlimitrect(w, &r);
	oi = nil;
	while(mouse->buttons & 5){
		readmouse(mousectl);
		if(!(mouse->buttons & 5) && mouse->buttons != 0)
			break;
		if(!eqpt(mouse->xy, p)){
			p = onscreen(mouse->xy);
			r = canonrect(Rpt(p0, p));
                        if (w) wlimitrect(w, &r);
			if(Dx(r)>5 && Dy(r)>5){
				i = allocwindow(wscreen, r, Refnone, 0xEEEEEEFF); /* grey */
				freeimage(oi);
				if(i == nil)
					goto Rescue;
				oi = i;
				border(i, r, Selborder, red, ZP);
				flushimage(display, 1);
			}
		}
	}
	if(mouse->buttons != 0)
		goto Rescue;
	if(i==nil || Dx(i->r)<100 || Dy(i->r)<3*font->height)
		goto Rescue;
	oi = i;
	i = allocwindow(wscreen, oi->r, Refbackup, DWhite);
	freeimage(oi);
	if(i == nil)
		goto Rescue;
	if (w && !w->noborder) border(i, r, Selborder, red, ZP);
	cornercursor(input, mouse->xy, 1);
	goto Return;

 Rescue:
	freeimage(i);
	i = nil;
	cornercursor(input, mouse->xy, 1);
	while(mouse->buttons)
		readmouse(mousectl);

 Return:
	moveto(mousectl, mouse->xy);	/* force cursor update; ugly */
	menuing = FALSE;
	return i;
}

void
drawedge(Image **bp, Rectangle r)
{
	Image *b = *bp;
	if(b != nil && Dx(b->r) == Dx(r) && Dy(b->r) == Dy(r))
		originwindow(b, r.min, r.min);
	else{
		freeimage(b);
		*bp = allocwindow(wscreen, r, Refbackup, DRed);
	}
}

void
drawborder(Rectangle r, int show)
{
	static Image *b[4];
	int i;
	if(show == 0){
		for(i = 0; i < 4; i++){
			freeimage(b[i]);
			b[i] = nil;
		}
	}else{
		r = canonrect(r);
		drawedge(&b[0], Rect(r.min.x, r.min.y, r.min.x+Borderwidth, r.max.y));
		drawedge(&b[1], Rect(r.min.x+Borderwidth, r.min.y, r.max.x-Borderwidth, r.min.y+Borderwidth));
		drawedge(&b[2], Rect(r.max.x-Borderwidth, r.min.y, r.max.x, r.max.y));
		drawedge(&b[3], Rect(r.min.x+Borderwidth, r.max.y-Borderwidth, r.max.x-Borderwidth, r.max.y));
	}
}

Image*
drag(Window *w, Rectangle *rp)
{
	Image *i, *ni;
	Point p, op, d, dm, om;
	Rectangle r;

	i = w->i;
	menuing = TRUE;
	om = mouse->xy;
	riosetcursor(&boxcursor, 1);
	dm = subpt(mouse->xy, w->screenr.min);
	d = subpt(i->r.max, i->r.min);
	op = subpt(mouse->xy, dm);
	drawborder(Rect(op.x, op.y, op.x+d.x, op.y+d.y), 1);
	flushimage(display, 1);
	//while(mouse->buttons == 4){
	while(mouse->buttons){
		p = subpt(mouse->xy, dm);
		if(!eqpt(p, op)){
                        r = Rect(p.x, p.y, p.x+d.x, p.y+d.y);
                        wlimitrect(w, &r);
			drawborder(r, 1);
			flushimage(display, 1);
			op = p;
		}
		readmouse(mousectl);
	}
	r = Rect(op.x, op.y, op.x+d.x, op.y+d.y);
        wlimitrect(w, &r);
	drawborder(r, 0);
	cornercursor(w, mouse->xy, 1);
	moveto(mousectl, mouse->xy);	/* force cursor update; ugly */
	menuing = FALSE;
	flushimage(display, 1);
        if(eqrect(w->i->r, r))
                return nil;
	if(mouse->buttons!=0 || (ni=allocwindow(wscreen, r, Refbackup, DWhite))==nil){
		moveto(mousectl, om);
		while(mouse->buttons)
			readmouse(mousectl);
		*rp = Rect(0, 0, 0, 0);
		return nil;
	}
//	draw(ni, ni->r, i, nil, i->r.min);
	*rp = r;
	return ni;
}

Point
cornerpt(Rectangle r, Point p, int which)
{
	switch(which){
	case 0:	/* top left */
		p = Pt(r.min.x, r.min.y);
		break;
	case 2:	/* top right */
		p = Pt(r.max.x,r.min.y);
		break;
	case 6:	/* bottom left */
		p = Pt(r.min.x, r.max.y);
		break;
	case 8:	/* bottom right */
		p = Pt(r.max.x, r.max.y);
		break;
	case 1:	/* top edge */
		p = Pt(p.x,r.min.y);
		break;
	case 5:	/* right edge */
		p = Pt(r.max.x, p.y);
		break;
	case 7:	/* bottom edge */
		p = Pt(p.x, r.max.y);
		break;
	case 3:		/* left edge */
		p = Pt(r.min.x, p.y);
		break;
	}
	return p;
}

Rectangle
whichrect(Rectangle r, Point p, int which)
{
	switch(which){
	case 0:	/* top left */
		r = Rect(p.x, p.y, r.max.x, r.max.y);
		break;
	case 2:	/* top right */
		r = Rect(r.min.x, p.y, p.x, r.max.y);
		break;
	case 6:	/* bottom left */
		r = Rect(p.x, r.min.y, r.max.x, p.y);
		break;
	case 8:	/* bottom right */
		r = Rect(r.min.x, r.min.y, p.x, p.y);
		break;
	case 1:	/* top edge */
		r = Rect(r.min.x, p.y, r.max.x, r.max.y);
		break;
	case 5:	/* right edge */
		r = Rect(r.min.x, r.min.y, p.x, r.max.y);
		break;
	case 7:	/* bottom edge */
		r = Rect(r.min.x, r.min.y, r.max.x, p.y);
		break;
	case 3:		/* left edge */
		r = Rect(p.x, r.min.y, r.max.x, r.max.y);
		break;
	}
	return canonrect(r);
}

int
resizable(Window *w)
{
    return !w->noborder && (w->mindx != w->maxdx || w->mindy != w->maxdy);
}

int
wlimitrect(Window *w, Rectangle *r)
{
    return limitrect(w->noborder, w->mindx, w->maxdx, w->mindy, w->maxdy, r);
}

int
limitrect(int noborder, int mindx, int maxdx, int mindy, int maxdy, Rectangle *r)
{
    int v = 0;
    if(!eqrect(canonrect(*r), *r)) {
        *r = canonrect(*r);
        v = 1;
    }
    /* Limit min/max values to reasonable dimensions */
    if (noborder) {
        mindx = max(mindx, 1);
        mindy = max(mindy, 1);
    } else {
        mindx = max(mindx, 100);
        mindy = max(mindy, 3*font->height);
    }

    maxdx = min(maxdx, BIG*Dx(screen->r));
    maxdy = min(maxdy, BIG*Dy(screen->r));

    /* Limit size of window according to min/max values */
    if (Dx(*r) > maxdx) {
        r->max.x -= Dx(*r) - maxdx;
        v = 1;
    }
    if (Dx(*r) < mindx) {
        r->max.x += mindx - Dx(*r);
        v = 1;
    }
    if (Dy(*r) > maxdy) {
        r->max.y -= Dy(*r) - maxdy;
        v = 1;
    }
    if (Dy(*r) < mindy) {
        r->max.y += mindy - Dy(*r);
        v = 1;
    }

    /* Ensure some of the window is visible on the screen */
    if (r->min.y < screen->r.min.y) {
        int t = Dy(*r);
        r->min.y = screen->r.min.y;
        r->max.y = r->min.y + t;
        v = 1;
    }
    if (r->min.y > screen->r.max.y - VISIBLE_PART) {
        int t = Dy(*r);
        r->min.y = screen->r.max.y - VISIBLE_PART;
        r->max.y = r->min.y + t;
        v = 1;
    }
    if (r->max.x < screen->r.min.x + VISIBLE_PART) {
        int t = Dx(*r);
        r->max.x = screen->r.min.x + VISIBLE_PART;
        r->min.x = r->max.x - t;
        v = 1;
    }
    if (r->min.x > screen->r.max.x - VISIBLE_PART) {
        int t = Dx(*r);
        r->min.x = screen->r.max.x - VISIBLE_PART;
        r->max.x = r->min.x + t;
        v = 1;
    }
        
    return v;
}

Image*
bandsize(Window *w)
{
	Image *i;
	Rectangle r, or;
	Point p;
	int which, but;
        if (!resizable(w))
            return nil;
	p = mouse->xy;
        cornercursor(w, p, 1);
	but = mouse->buttons;
	which = whichcorner(w, p);
	p = cornerpt(w->screenr, p, which);
	wmovemouse(w, p);
	readmouse(mousectl);
	r = whichrect(w->screenr, p, which);
	drawborder(r, 1);
	or = r;
	
	while(mouse->buttons == but){
		p = onscreen(mouse->xy);
		r = whichrect(w->screenr, p, which);
                wlimitrect(w, &r);
		if(!eqrect(r, or) /*&& goodrect(r)*/){
			drawborder(r, 1);
			flushimage(display, 1);
			or = r;
		}
		readmouse(mousectl);
	}
	p = mouse->xy;
	drawborder(or, 0);
	flushimage(display, 1);
	wsetcursor(w, 1);
	if(mouse->buttons!=0 || Dx(or)<100 || Dy(or)<3*font->height){
		while(mouse->buttons)
			readmouse(mousectl);
		return nil;
	}
        if(eqrect(w->i->r, or))
                return nil;
	i = allocwindow(wscreen, or, Refbackup, DWhite);
	if(i == nil)
		return nil;
	border(i, r, Selborder, red, ZP);
	return i;
}

Window*
pointto(int wait)
{
	Window *w;

	menuing = TRUE;
	riosetcursor(&sightcursor, 1);
	while(mouse->buttons == 0)
		readmouse(mousectl);
	if(mouse->buttons == 4)
		w = wpointto(mouse->xy);
	else
		w = nil;
	if(wait){
		while(mouse->buttons){
			if(mouse->buttons!=4 && w !=nil){	/* cancel */
				cornercursor(input, mouse->xy, 0);
				w = nil;
			}
			readmouse(mousectl);
		}
		if(w != nil && wpointto(mouse->xy) != w)
			w = nil;
	}
	cornercursor(input, mouse->xy, 0);
	moveto(mousectl, mouse->xy);	/* force cursor update; ugly */
	menuing = FALSE;
	return w;
}

int
wsetlayer(Window *w, int layer)
{
    if (w->transientfor)
        return 0;
    if (w->layer == layer)
        return 1;
    w->wctlready = 1;
    w->layer = layer;
    wsendctlmesg(w, Wakeup);
    //reconcile_stacking();
    return wtop(w);
}


int
wselect(Window *w)
{
    if (w->noborder || w->transientfor)
        return 0;
    if (input && input->transientforroot == w)
        whide(w);
    else if (w->hidden)
        wunhide(w);
    else {
        Window *f = w->rememberedfocus;
        if (!f || f->hidden)
            f = w;
        wtop(f);
        wcurrent(f);
    }
    return 1;
}

int
whide(Window *w)
{
    int j;
    if(w->hidden)
        return 1;
    if (w->noborder || w->transientfor)
        return 0;
    for(j=0; j<nwindow; j++) {
        Window *x = window[j];
        if (!x->hidden && w == x->transientforroot) {
            Image *i = allocimage(display, x->screenr, x->i->chan, 0, DWhite);
            if(x == input)
                wcurrent(nil);
            x->hidden = 1;
            wreshaped(x, i);
        }
    }
    flushimage(display, 1);
    if (input == nil)
        choosewcurrent();
    return 1;
}

int
wunhide(Window *w)
{
    int j;
    Window *f;
    if (!w->hidden)
        return 1;
    if (w->transientfor)
        return 0;
    for(j=0; j<nwindow; j++) {
        Window *x = window[j];
        if (x->hidden && w == x->transientforroot) {
            Image *i = allocwindow(wscreen, x->i->r, Refbackup, DWhite);
            x->hidden = 0;
            wreshaped(x, i);
        }
    }
    /* Restore focus to appropriate window */
    if ((f = w->rememberedfocus))
        f->order = ++order;
    ensure_transient_stacking();
    reconcile_stacking();
    if(f)
        wcurrent(f);
    return 1;
}

int
readmouseex(MousectlEx *mc)
{
        if(mc->image)
                flushimage(mc->image->display, 1);
        if(recv(mc->c, &mc->MouseEx) < 0){
                fprint(2, "readmouse: %r\n");
                return -1;
        }
        return 0;
}

Window*
new(Image *i, int hideit, int scrollit, int transientfor, int noborder, 
    int layer, int mindx, int maxdx, int mindy, int maxdy,
    int pid, char *dir, char *cmd, char **argv)
{
	Window *w;
	MousectlEx *mc;
	Channel *cm, *ck, *cctl, *cpid;
	void **arg;

	if(i == nil)
		return nil;
	cm = chancreate(sizeof(MouseEx), 0);
	ck = chancreate(sizeof(Rune*), 0);
	cctl = chancreate(sizeof(int), 4);
	cpid = chancreate(sizeof(int), 0);
	if(cm==nil || ck==nil || cctl==nil)
		error("new: channel alloc failed");
	mc = emalloc(sizeof(MousectlEx));
        mc->Mouse = mousectl->Mouse;
        mc->type = 'm';
	mc->c = cm;
        mc->image = i;
	w = wmk(i, mc, ck, cctl, hideit, scrollit, transientfor, noborder,
                layer, mindx, maxdx, mindy, maxdy);
	free(mc);	/* wmk copies *mc */
	window = erealloc(window, ++nwindow*sizeof(Window*));
	window[nwindow-1] = w;
	if(hideit){
		w->screenr = ZR;
	}
	threadcreate(winctl, w, 8192);
	if(!hideit)
		wcurrent(w);
        reconcile_stacking();

	if(pid == 0){
		arg = emalloc(5*sizeof(void*));
		arg[0] = w;
		arg[1] = cpid;
		arg[2] = cmd;
		if(argv == nil)
			arg[3] = rcargv;
		else
			arg[3] = argv;
		arg[4] = dir;
		proccreate(winshell, arg, 8192);
		pid = recvul(cpid);
		free(arg);
	}
	if(pid == 0){
		/* window creation failed */
		wsendctlmesg(w, Deleted);
		chanfree(cpid);
		return nil;
	}
        if (pid > 0) {
            char buf[128];
            wsetpid(w, pid);
            sprint(buf, "rc %d", pid);
            free(w->label);
            w->label = estrdup(buf);
        }
	wsetname(w);
	chanfree(cpid);
	return w;
}
