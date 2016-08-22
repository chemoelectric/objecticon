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
#include <complete.h>
#include "dat.h"
#include "fns.h"

#define MOVEIT if(0)

enum
{
	HiWater	= 640000,	/* max size of history */
	LoWater	= 400000,	/* min size of history after max'ed */
	MinWater	= 20000,	/* room to leave available when reallocating */
};

int		topped, order;
static	int		id;

static	Image	*cols[NCOL];
static	Image	*grey;
static	Image	*darkgrey;
static	Cursor	*lastcursor;
static	Image	*titlecol;
static	Image	*lighttitlecol;
static	Image	*holdcol;
static	Image	*lightholdcol;
static	Image	*paleholdcol;

static void addhist(Window *w, int from, int to);
static void rmhist(Window *w);
static void gotohist(Window *w, int pos);
static void searchhist(Window *w, int dir);
static void resethist(Window *w);
static void locatehist(Window *w);

#define HistEntry(w,pos) ((w)->hist[((w)->hfirst + (pos)) % (w)->hlimit])

Window*
wmk(Image *i, MousectlEx *mc, Channel *ck, Channel *cctl, int hidden, int scrolling, int transientfor, int noborder,
    int layer, int mindx, int maxdx, int mindy, int maxdy)
{
        Window *w, *x;
	Rectangle r;

	if(cols[0] == nil){
		/* greys are multiples of 0x11111100+0xFF, 14* being palest */
		grey = allocimage(display, Rect(0,0,1,1), CMAP8, 1, 0xEEEEEEFF);
		darkgrey = allocimage(display, Rect(0,0,1,1), CMAP8, 1, 0x666666FF);
		cols[BACK] = display->white;
		cols[HIGH] = allocimage(display, Rect(0,0,1,1), CMAP8, 1, 0xCCCCCCFF);
		cols[BORD] = allocimage(display, Rect(0,0,1,1), CMAP8, 1, 0x999999FF);
		cols[TEXT] = display->black;
		cols[HTEXT] = display->black;
		titlecol = allocimage(display, Rect(0,0,1,1), CMAP8, 1, DGreygreen);
		lighttitlecol = allocimage(display, Rect(0,0,1,1), CMAP8, 1, DPalegreygreen);
		holdcol = allocimage(display, Rect(0,0,1,1), CMAP8, 1, DMedblue);
		lightholdcol = allocimage(display, Rect(0,0,1,1), CMAP8, 1, DGreyblue);
		paleholdcol = allocimage(display, Rect(0,0,1,1), CMAP8, 1, DPalegreyblue);
	}
	w = emalloc(sizeof(Window));
	w->screenr = i->r;
	r = insetrect(i->r, Selborder+1);
	w->i = i;
	w->mc = *mc;
	w->ck = ck;
	w->cctl = cctl;
	w->cursorp = nil;
	w->conswrite = chancreate(sizeof(Conswritemesg), 0);
	w->consread =  chancreate(sizeof(Consreadmesg), 0);
	w->mouseread =  chancreate(sizeof(Mousereadmesg), 0);
	w->wctlread =  chancreate(sizeof(Consreadmesg), 0);
	w->scrollr = r;
	w->scrollr.max.x = r.min.x+Scrollwid;
	w->lastsr = ZR;
	r.min.x += Scrollwid+Scrollgap;
	frinit(w, r, font, i, cols);
	w->maxtab = maxtab*stringwidth(font, "0");
	w->order = ++order;
        w->topped = ++topped;
	w->id = ++id;
	w->notefd = -1;
        w->hidden = hidden;
	w->scrolling = scrolling;
        if (transientfor != -1 && (x = wlookid(transientfor))) {
            w->transientfor = x;
            incref(x);
        } else
            w->transientfor = nil;
        x = w;
        while (x->transientfor)
            x = x->transientfor;
        w->transientforroot = x;
        w->noborder = noborder;
        w->layer = (layer == INVALID_LAYER ? 0 : layer);
        w->focusclickflag = 0;
        w->mindx = mindx;
        w->maxdx = maxdx;
        w->mindy = mindy;
        w->maxdy = maxdy;
        w->hlimit = 128;
        w->hist = emalloc(w->hlimit * sizeof(Rune *));
        w->hsentlen = w->hpos = w->hsize = w->hfirst = w->hlast = 0;
        w->hsent = w->hedit = 0;
        w->hstartno = 1;
	w->label = estrdup("<unnamed>");
        w->pid = 0;
        if (noborder) {
            draw(w->i, w->i->r, cols[BACK], nil, w->entire.min);
        } else {
            r = insetrect(w->i->r, Selborder);
            draw(w->i, r, cols[BACK], nil, w->entire.min);
            wborder(w, Selborder);
        }
	wscrdraw(w);
	incref(w);	/* ref will be removed after mounting; avoids delete before ready to be deleted */
	return w;
}

void
wsetname(Window *w)
{
	int i, n;
	char err[ERRMAX];

        if (w->noborder)
            n = sprint(w->name, "noborder.window.%d.%d", w->id, w->namecount++);
        else
            n = sprint(w->name, "window.%d.%d", w->id, w->namecount++);
	for(i='A'; i<='Z'; i++){
		if(nameimage(w->i, w->name, 1) > 0)
			return;
		errstr(err, sizeof err);
		if(strcmp(err, "image name in use") != 0)
			break;
		w->name[n] = i;
		w->name[n+1] = 0;
	}
	w->name[0] = 0;
	fprint(2, "rio: setname failed: %s\n", err);
}

void
wresize(Window *w, Image *i)
{
	Rectangle r, or;

	or = w->i->r;
	if((Dx(or)==Dx(i->r) && Dy(or)==Dy(i->r)))
	 	draw(i, i->r, w->i, nil, w->i->r.min);
	freeimage(w->i);
	w->i = i;
	wsetname(w);
	w->mc.image = i;
	r = insetrect(i->r, Selborder+1);
	w->scrollr = r;
	w->scrollr.max.x = r.min.x+Scrollwid;
	w->lastsr = ZR;
	r.min.x += Scrollwid+Scrollgap;
        frclear(w, FALSE);
        frinit(w, r, w->font, w->i, cols);
        wsetcols(w);
        w->maxtab = maxtab*stringwidth(w->font, "0");
        r = insetrect(w->i->r, Selborder);
        draw(w->i, r, cols[BACK], nil, w->entire.min);
        wfill(w);
        wsetselect(w, w->q0, w->q1);
        wscrdraw(w);
	if(w == input)
		wborder(w, Selborder);
	else
		wborder(w, Unselborder);
	w->order = ++order;
        w->topped = ++topped;
}

void
wclosereq(Window *w)
{
    sendmouseevent(w, 'c');
}

void
wrefresh(Window *w, Rectangle)
{
	/* BUG: rectangle is ignored */
	if(w == input)
		wborder(w, Selborder);
	else
		wborder(w, Unselborder);
	if(w->mouseopen)
		return;
	draw(w->i, insetrect(w->i->r, Borderwidth), w->cols[BACK], nil, w->i->r.min);
	w->ticked = 0;
	if(w->p0 > 0)
		frdrawsel(w, frptofchar(w, 0), 0, w->p0, 0);
	if(w->p1 < w->nchars)
		frdrawsel(w, frptofchar(w, w->p1), w->p1, w->nchars, 0);
	frdrawsel(w, frptofchar(w, w->p0), w->p0, w->p1, 1);
	w->lastsr = ZR;
	wscrdraw(w);
}

int
wclose(Window *w)
{
	int i;

	i = decref(w);
	if(i > 0)
		return 0;
	if(i < 0)
		error("negative ref count");
	if(!w->deleted)
		wclosewin(w);
	wsendctlmesg(w, Exited);
	return 1;
}

int      dbgalt(Alt *alts, char *lab)
{
    int x;
    print("<%s:",lab);
    x = alt(alts);
    print(":%s=%d>",lab,x);
    return x;
}

void
winctl(void *arg)
{
	Rune *rp, *bp, *tp, *up, *kbdr;
	uint qh;
	int nr, nb, c, wid, i, npart, initial, qh0;
	char *s, *t, part[3];
	Window *w;
	Mousestate *mp, m;
	enum { WKey, WMouse, WMouseread, WCtl, WCwrite, WCread, WWread, NWALT };
	Alt alts[NWALT+1];
	Mousereadmesg mrm;
	Conswritemesg cwm;
	Consreadmesg crm;
	Consreadmesg cwrm;
	Stringpair pair;
	int wcm;
        char buff[256];

	w = arg;
	snprint(buff, sizeof buff, "winctl-id%d", w->id);
	threadsetname(buff);

	mrm.cm = chancreate(sizeof(MouseEx), 0);
	cwm.cw = chancreate(sizeof(Stringpair), 0);
	crm.c1 = chancreate(sizeof(Stringpair), 0);
	crm.c2 = chancreate(sizeof(Stringpair), 0);
	cwrm.c1 = chancreate(sizeof(Stringpair), 0);
	cwrm.c2 = chancreate(sizeof(Stringpair), 0);
	

	alts[WKey].c = w->ck;
	alts[WKey].v = &kbdr;
	alts[WKey].op = CHANRCV;
	alts[WMouse].c = w->mc.c;
	alts[WMouse].v = &w->mc.Mouse;
	alts[WMouse].op = CHANRCV;
	alts[WMouseread].c = w->mouseread;
	alts[WMouseread].v = &mrm;
	alts[WMouseread].op = CHANSND;
	alts[WCtl].c = w->cctl;
	alts[WCtl].v = &wcm;
	alts[WCtl].op = CHANRCV;
	alts[WCwrite].c = w->conswrite;
	alts[WCwrite].v = &cwm;
	alts[WCwrite].op = CHANSND;
	alts[WCread].c = w->consread;
	alts[WCread].v = &crm;
	alts[WCread].op = CHANSND;
	alts[WWread].c = w->wctlread;
	alts[WWread].v = &cwrm;
	alts[WWread].op = CHANSND;
	alts[NWALT].op = CHANEND;

	npart = 0;
	for(;;){
		if(w->mouseopen && w->mouse.counter != w->mouse.lastcounter)
			alts[WMouseread].op = CHANSND;
		else
			alts[WMouseread].op = CHANNOP;
		if(!w->scrolling && !w->mouseopen && w->qh>w->org+w->nchars)
			alts[WCwrite].op = CHANNOP;
		else
			alts[WCwrite].op = CHANSND;
		if(w->deleted || !w->wctlready)
			alts[WWread].op = CHANNOP;
		else
			alts[WWread].op = CHANSND;
		/* this code depends on NL and EOT fitting in a single byte */
		/* kind of expensive for each loop; worth precomputing? */
		if(w->holding)
			alts[WCread].op = CHANNOP;
		else if(npart || (w->rawing && w->nraw>0))
			alts[WCread].op = CHANSND;
		else{
			alts[WCread].op = CHANNOP;
			for(i=w->qh; i<w->nr; i++){
				c = w->r[i];
				if(c=='\n' || c=='\004'){
					alts[WCread].op = CHANSND;
					break;
				}
			}
		}
		switch(alt(alts)){
		case WKey:
			for(i=0; kbdr[i]!=L'\0'; i++)
				wkeyctl(w, kbdr[i]);
//			wkeyctl(w, r);
///			while(nbrecv(w->ck, &r))
//				wkeyctl(w, r);
			break;
		case WMouse:
			if(w->mouseopen) {
				w->mouse.counter++;
				/* queue click events */
				if(!w->mouse.qfull) {	/* add to ring */
					mp = &w->mouse.queue[w->mouse.wi];
					if(++w->mouse.wi == nelem(w->mouse.queue))
						w->mouse.wi = 0;
					if(w->mouse.wi == w->mouse.ri)
						w->mouse.qfull = TRUE;
					mp->MouseEx = w->mc;
					mp->counter = w->mouse.counter;
				}
			} else
				wmousectl(w);
			break;
		case WMouseread:
			/* send a queued event or, if the queue is empty, the current state */
			/* if the queue has filled, we discard all the events it contained. */
			/* the intent is to discard frantic clicking by the user during long latencies. */
			w->mouse.qfull = FALSE;
			if(w->mouse.wi != w->mouse.ri) {
				m = w->mouse.queue[w->mouse.ri];
				if(++w->mouse.ri == nelem(w->mouse.queue))
					w->mouse.ri = 0;
			} else {
				m = (Mousestate){w->mc.MouseEx, w->mouse.counter};
                        }

			w->mouse.lastcounter = m.counter;
			send(mrm.cm, &m.MouseEx);
			continue;
		case WCtl:
			if(wctlmesg(w, wcm) == Exited){
				chanfree(crm.c1);
				chanfree(crm.c2);
				chanfree(mrm.cm);
				chanfree(cwm.cw);
				chanfree(cwrm.c1);
				chanfree(cwrm.c2);
				threadexits(nil);
			}
			continue;
		case WCwrite:
			recv(cwm.cw, &pair);
			rp = pair.s;
			nr = pair.ns;
			bp = rp;
			for(i=0; i<nr; i++)
				if(*bp++ == '\b'){
					--bp;
					initial = 0;
					tp = runemalloc(nr);
					runemove(tp, rp, i);
					up = tp+i;
					for(; i<nr; i++){
						*up = *bp++;
						if(*up == '\b')
							if(up == tp)
								initial++;
							else
								--up;
						else
							up++;
					}
					if(initial){
						if(initial > w->qh)
							initial = w->qh;
						qh = w->qh-initial;
						wdelete(w, qh, qh+initial);
						w->qh = qh;
					}
					free(rp);
					rp = tp;
					nr = up-tp;
					rp[nr] = 0;
					break;
				}
			w->qh = winsert(w, rp, nr, w->qh)+nr;
			if(w->scrolling || w->mouseopen)
				wshow(w, w->qh);
			wsetselect(w, w->q0, w->q1);
			wscrdraw(w);
			free(rp);
			break;
		case WCread:
			recv(crm.c1, &pair);
			t = pair.s;
			nb = pair.ns;
                        qh0 = w->qh;
			i = npart;
			npart = 0;
			if(i)
				memmove(t, part, i);
			while(i<nb && (w->qh<w->nr || w->nraw>0)){
				if(w->qh == w->nr){
					wid = runetochar(t+i, &w->raw[0]);
					w->nraw--;
					runemove(w->raw, w->raw+1, w->nraw);
				}else
					wid = runetochar(t+i, &w->r[w->qh++]);
				c = t[i];	/* knows break characters fit in a byte */
				i += wid;
				if(!w->rawing && (c == '\n' || c=='\004')){
					if(c == '\004')
						i--;
					break;
				}
			}
			if(i==nb && w->qh<w->nr && w->r[w->qh]=='\004')
				w->qh++;
			if(i > nb){
				npart = i-nb;
				memmove(part, t+nb, npart);
				i = nb;
			}
                        if (!w->rawing)
                            addhist(w, qh0, w->qh);
			pair.s = t;
			pair.ns = i;
			send(crm.c2, &pair);
			continue;
		case WWread:
			w->wctlready = 0;
			recv(cwrm.c1, &pair);
			if(w->deleted || w->i==nil)
				pair.ns = sprint(pair.s, "");
			else
                            pair.ns = wstatestring(w, pair.s, pair.ns);

			send(cwrm.c2, &pair);
			continue;
		}
		if(!w->deleted)
			flushimage(display, 1);
	}
}

int
wstatestring(Window *w, char *dest, int destsize)
{
    char buff[256];
    strcpy(buff, " ");
    if(w->hidden)
        strcat(buff, "hidden ");
    if(w == input)
        strcat(buff, "current ");
    if(w->noborder)
        strcat(buff, "noborder ");
    if(w->layer)
        sprint(buff + strlen(buff), "layer:%d ", w->layer);
    if (w->transientfor != nil)
        sprint(buff + strlen(buff), "transientfor:%d ", w->transientfor->id);
    if (w->mindx != 1)
        sprint(buff + strlen(buff), "mindx:%d ", w->mindx);
    if (w->mindy != 1)
        sprint(buff + strlen(buff), "mindy:%d ", w->mindy);
    if (w->maxdx != INT_MAX)
        sprint(buff + strlen(buff), "maxdx:%d ", w->maxdx);
    if (w->maxdy != INT_MAX)
        sprint(buff + strlen(buff), "maxdy:%d ", w->maxdy);
    return snprint(dest, destsize, "%11d %11d %11d %11d%s",
                   w->i->r.min.x - screen->r.min.x, 
                   w->i->r.min.y - screen->r.min.y, 
                   w->i->r.max.x - screen->r.min.x,
                   w->i->r.max.y - screen->r.min.y,
                   buff);
}

void
waddraw(Window *w, Rune *r, int nr)
{
	w->raw = runerealloc(w->raw, w->nraw+nr);
	runemove(w->raw+w->nraw, r, nr);
	w->nraw += nr;
}

/*
 * Need to do this in a separate proc because if process we're interrupting
 * is dying and trying to print tombstone, kernel is blocked holding p->debug lock.
 */
void
interruptproc(void *v)
{
	int *notefd;

	notefd = v;
	write(*notefd, "interrupt", 9);
	free(notefd);
}

int
windfilewidth(Window *w, uint q0, int oneelement)
{
	uint q;
	Rune r;

	q = q0;
	while(q > 0){
		r = w->r[q-1];
		if(r<=' ')
			break;
		if(oneelement && r=='/')
			break;
		--q;
	}
	return q0-q;
}

void
showcandidates(Window *w, Completion *c)
{
	int i;
	Fmt f;
	Rune *rp;
	uint nr, qline, q0;
	char *s;

	runefmtstrinit(&f);
	if (c->nmatch == 0)
		s = "[no matches in ";
	else
		s = "[";
	if(c->nfile > 32)
		fmtprint(&f, "%s%d files]\n", s, c->nfile);
	else{
		fmtprint(&f, "%s", s);
		for(i=0; i<c->nfile; i++){
			if(i > 0)
				fmtprint(&f, " ");
			fmtprint(&f, "%s", c->filename[i]);
		}
		fmtprint(&f, "]\n");
	}
	/* place text at beginning of line before host point */
	qline = w->qh;
	while(qline>0 && w->r[qline-1] != '\n')
		qline--;

	rp = runefmtstrflush(&f);
	nr = runestrlen(rp);

	q0 = w->q0;
	q0 += winsert(w, rp, runestrlen(rp), qline) - qline;
	free(rp);
	wsetselect(w, q0+nr, q0+nr);
}

Rune*
namecomplete(Window *w)
{
	int nstr, npath;
	Rune *rp, *path, *str;
	Completion *c;
	char *s, *dir, *root;

	/* control-f: filename completion; works back to white space or / */
	if(w->q0<w->nr && w->r[w->q0]>' ')	/* must be at end of word */
		return nil;
	nstr = windfilewidth(w, w->q0, TRUE);
	str = runemalloc(nstr);
	runemove(str, w->r+(w->q0-nstr), nstr);
	npath = windfilewidth(w, w->q0-nstr, FALSE);
	path = runemalloc(npath);
	runemove(path, w->r+(w->q0-nstr-npath), npath);
	rp = nil;

	/* is path rooted? if not, we need to make it relative to window path */
	if(npath>0 && path[0]=='/'){
		dir = malloc(UTFmax*npath+1);
		sprint(dir, "%.*S", npath, path);
	}else{
                char *wdir = get_wdir(w);
		if(strcmp(wdir, "") == 0)
			root = ".";
		else
			root = wdir;
		dir = malloc(strlen(root)+1+UTFmax*npath+1);
		sprint(dir, "%s/%.*S", root, npath, path);
	}
	dir = cleanname(dir);

	s = smprint("%.*S", nstr, str);
	c = complete(dir, s);
	free(s);
	if(c == nil)
		goto Return;

	if(!c->advance)
		showcandidates(w, c);

	if(c->advance)
		rp = runesmprint("%s", c->string);

  Return:
	freecompletion(c);
	free(dir);
	free(path);
	free(str);
	return rp;
}

void
wkeyctl(Window *w, Rune r)
{
	uint q0 ,q1;
	int n, nb, nr;
	Rune *rp;
	int *notefd;

	if(r == 0)
		return;
	if(w->deleted)
		return;
	/* navigation keys work only when mouse is not open */
	if(!w->mouseopen)
		switch(r){
		case riox_Kscrollonedown:
			n = mousescrollsize(w->maxlines);
			if(n <= 0)
				n = 1;
			goto case_Down;
		case Kpgdown:
			n = w->maxlines/2;
		case_Down:
			q0 = w->org+frcharofpt(w, Pt(w->Frame.r.min.x, w->Frame.r.min.y+n*w->font->height));
			wsetorigin(w, q0, TRUE);
			return;
		case riox_Kscrolloneup:
			n = mousescrollsize(w->maxlines);
			if(n <= 0)
				n = 1;
			goto case_Up;
		case Kpgup:
			n = w->maxlines/2;
		case_Up:
			q0 = wbacknl(w, w->org, n);
			wsetorigin(w, q0, TRUE);
			return;
		case Kleft:
			if(w->q0 > 0){
				q0 = w->q0-1;
				wsetselect(w, q0, q0);
				wshow(w, q0);
			}
			return;
		case Kright:
			if(w->q1 < w->nr){
				q1 = w->q1+1;
				wsetselect(w, q1, q1);
				wshow(w, q1);
			}
			return;
		case Khome:
			wshow(w, 0);
			return;
		case Kend:
			wshow(w, w->nr);
			return;
		case 0x01:	/* ^A: beginning of line */
			if(w->q0==0 || w->q0==w->qh || w->r[w->q0-1]=='\n')
				return;
			nb = wbswidth(w, 0x15 /* ^U */);
			wsetselect(w, w->q0-nb, w->q0-nb);
			wshow(w, w->q0);
			return;
		case 0x05:	/* ^E: end of line */
			q0 = w->q0;
			while(q0 < w->nr && w->r[q0]!='\n')
				q0++;
			wsetselect(w, q0, q0);
			wshow(w, w->q0);
			return;
		}
	if(w->rawing && (w->q0==w->nr || w->mouseopen)){
		waddraw(w, &r, 1);
		return;
	}
	if(r==0x1B || (w->holding && r==0x7F)){	/* toggle hold */
		if(w->holding)
			--w->holding;
		else
			w->holding++;
		wrepaint(w);
		if(r == 0x1B)
			return;
	}
	if(r != 0x7F){
		wsnarf(w);
		wcut(w);
	}
	switch(r){
        case Kup:
                if (!w->holding)
                   gotohist(w, w->hpos - 1);
                return;
        case Kdown:
                if (!w->holding)
                    gotohist(w, w->hpos + 1);
                return;
        case 16:   /* ^P */
                if (!w->holding)
                    locatehist(w);
                return;
        case 18:   /* ^R */
                if (!w->holding)
                    searchhist(w, -1);
                return;
        case 20:   /* ^T */
                if (!w->holding)
                    searchhist(w, 1);
                return;
        case 25:   /* ^Y */
                if (w->q0 < w->nr) {
                    wdelete(w, w->q0, w->q0 + 1);
                    wshow(w, w->q0);
                }
                return;
	case 0x7F:		/* send interrupt */
                w->qh = w->nr;
                wsetselect(w, w->nr, w->nr);
                wshow(w, w->nr);
                resethist(w);
		notefd = emalloc(sizeof(int));
		*notefd = w->notefd;
		proccreate(interruptproc, notefd, 4096);
		return;
	case 0x06:	/* ^F: file name completion */
	case Kins:		/* Insert: file name completion */
		rp = namecomplete(w);
		if(rp == nil)
			return;
		nr = runestrlen(rp);
		q0 = w->q0;
		q0 = winsert(w, rp, nr, q0);
		wshow(w, q0+nr);
		free(rp);
		return;
	case 0x08:	/* ^H: erase character */
	case 0x15:	/* ^U: erase line */
	case 0x17:	/* ^W: erase word */
		if(w->q0==0 || w->q0==w->qh)
			return;
		nb = wbswidth(w, r);
		q1 = w->q0;
		q0 = q1-nb;
		if(q0 < w->org){
			q0 = w->org;
			nb = q1-q0;
		}
		if(nb > 0){
			wdelete(w, q0, q0+nb);
			wsetselect(w, q0, q0);
		}
		return;
        case '\n' :
               /* If the cursor is in the edited region, (qh..nr), or
                * just to its left, move it to the end so the edited
                * line is not split
                */ 
               if (w->q0 >= w->qh && w->q0 < w->nr)
                   wsetselect(w, w->nr, w->nr);
               break;
	}

	/* otherwise ordinary character; just insert */
	q0 = w->q0;
	q0 = winsert(w, &r, 1, q0);
	wshow(w, q0+1);
}

void
wsetcols(Window *w)
{
	if(w->holding)
		if(w == input)
			w->cols[TEXT] = w->cols[HTEXT] = holdcol;
		else
			w->cols[TEXT] = w->cols[HTEXT] = lightholdcol;
	else
		if(w == input)
			w->cols[TEXT] = w->cols[HTEXT] = display->black;
		else
			w->cols[TEXT] = w->cols[HTEXT] = darkgrey;
}

void
wrepaint(Window *w)
{
	wsetcols(w);
	if(!w->mouseopen)
		frredraw(w);
	if(w == input){
		wborder(w, Selborder);
		wsetcursor(w, 0);
	}else
		wborder(w, Unselborder);
}

int
wbswidth(Window *w, Rune c)
{
	uint q, eq, stop;
	Rune r;
	int skipping;

	/* there is known to be at least one character to erase */
	if(c == 0x08)	/* ^H: erase character */
		return 1;
	q = w->q0;
	stop = 0;
	if(q > w->qh)
		stop = w->qh;
	skipping = TRUE;
	while(q > stop){
		r = w->r[q-1];
		if(r == '\n'){		/* eat at most one more character */
			if(q == w->q0)	/* eat the newline */
				--q;
			break; 
		}
		if(c == 0x17){
			eq = isalnum(r);
			if(eq && skipping)	/* found one; stop skipping */
				skipping = FALSE;
			else if(!eq && !skipping)
				break;
		}
		--q;
	}
	return w->q0-q;
}

void
wsnarf(Window *w)
{
	if(w->q1 == w->q0)
		return;
	nsnarf = w->q1-w->q0;
	snarf = runerealloc(snarf, nsnarf);
	snarfversion++;	/* maybe modified by parent */
	runemove(snarf, w->r+w->q0, nsnarf);
	putsnarf();
}

void
wcut(Window *w)
{
	if(w->q1 == w->q0)
		return;
	wdelete(w, w->q0, w->q1);
	wsetselect(w, w->q0, w->q0);
}

void
wpaste(Window *w)
{
	uint q0;

	if(nsnarf == 0)
		return;
	wcut(w);
	q0 = w->q0;
	if(w->rawing && q0==w->nr){
		waddraw(w, snarf, nsnarf);
		wsetselect(w, q0, q0);
	}else{
		q0 = winsert(w, snarf, nsnarf, w->q0);
		wsetselect(w, q0, q0+nsnarf);
	}
}

void
wplumb(Window *w)
{
	Plumbmsg *m;
	static int fd = -2;
	char buf[32];
	uint p0, p1;
	Cursor *c;

	if(fd == -2)
		fd = plumbopen("send", OWRITE|OCEXEC);
	if(fd < 0)
		return;
	m = emalloc(sizeof(Plumbmsg));
	m->src = estrdup("rio");
	m->dst = nil;
	m->wdir = estrdup(get_wdir(w));
	m->type = estrdup("text");
	p0 = w->q0;
	p1 = w->q1;
	if(w->q1 > w->q0)
		m->attr = nil;
	else{
		while(p0>0 && w->r[p0-1]!=' ' && w->r[p0-1]!='\t' && w->r[p0-1]!='\n')
			p0--;
		while(p1<w->nr && w->r[p1]!=' ' && w->r[p1]!='\t' && w->r[p1]!='\n')
			p1++;
		sprint(buf, "click=%d", w->q0-p0);
		m->attr = plumbunpackattr(buf);
	}
	if(p1-p0 > messagesize-1024){
		plumbfree(m);
		return;	/* too large for 9P */
	}
	m->data = runetobyte(w->r+p0, p1-p0, &m->ndata);
	if(plumbsend(fd, m) < 0){
		c = lastcursor;
		riosetcursor(&query, 1);
		sleep(300);
		riosetcursor(c, 1);
	}
	plumbfree(m);
}

char *
get_wdir(Window *w)
{
    static char buff[512];
    char pf[64];
    int f, n, i;
    buff[0] = 0;
    if (w->pid == 0)
        return startdir;
    snprint(pf, sizeof(pf), "/proc/%d/fd", w->pid);
    f = open(pf, OREAD);
    if (f < 0)
        return startdir;
    n = read(f, buff, sizeof(buff));
    close(f);
    for (i = 0; i < n; ++i) {
        if (buff[i] == '\n') {
            buff[i] = 0;
            return buff;
        }
    }
    return startdir;
}

int
winborder(Window *w, Point xy)
{
	return !w->noborder && ptinrect(xy, w->screenr) && !ptinrect(xy, insetrect(w->screenr, Selborder));
}

void
wmousectl(Window *w)
{
	int but;

        if(w->focusclickflag) {
            w->focusclickflag = 0;
            return;
        }

	if(w->mc.buttons == 1)
		but = 1;
	else if(w->mc.buttons == 2)
		but = 2;
	else if(w->mc.buttons == 4)
		but = 3;
	else{
		if(w->mc.buttons == 8)
			wkeyctl(w, riox_Kscrolloneup);
		if(w->mc.buttons == 16)
			wkeyctl(w, riox_Kscrollonedown);
		return;
	}

	incref(w);		/* hold up window while we track */
	if(w->deleted)
		goto Return;
	if(ptinrect(w->mc.xy, w->scrollr)){
		if(but)
			wscroll(w, but);
		goto Return;
	}
	if(but == 1)
		wselection(w);
	/* else all is handled by main process */
   Return:
	wclose(w);
}

void
wdelete(Window *w, uint q0, uint q1)
{
	uint n, p0, p1;

	n = q1-q0;
	if(n == 0)
		return;
	runemove(w->r+q0, w->r+q1, w->nr-q1);
	w->nr -= n;
	if(q0 < w->q0)
		w->q0 -= min(n, w->q0-q0);
	if(q0 < w->q1)
		w->q1 -= min(n, w->q1-q0);
	if(q1 < w->qh)
		w->qh -= n;
	else if(q0 < w->qh)
		w->qh = q0;
	if(q1 <= w->org)
		w->org -= n;
	else if(q0 < w->org+w->nchars){
		p1 = q1 - w->org;
		if(p1 > w->nchars)
			p1 = w->nchars;
		if(q0 < w->org){
			w->org = q0;
			p0 = 0;
		}else
			p0 = q0 - w->org;
		frdelete(w, p0, p1);
		wfill(w);
	}
}


static Window	*clickwin;
static uint	clickmsec;
static Window	*selectwin;
static uint	selectq;

/*
 * called from frame library
 */
void
framescroll(Frame *f, int dl)
{
	if(f != &selectwin->Frame)
		error("frameselect not right frame");
	wframescroll(selectwin, dl);
}

void
wframescroll(Window *w, int dl)
{
	uint q0;

	if(dl == 0){
		wscrsleep(w, 100);
		return;
	}
	if(dl < 0){
		q0 = wbacknl(w, w->org, -dl);
		if(selectq > w->org+w->p0)
			wsetselect(w, w->org+w->p0, selectq);
		else
			wsetselect(w, selectq, w->org+w->p0);
	}else{
		if(w->org+w->nchars == w->nr)
			return;
		q0 = w->org+frcharofpt(w, Pt(w->Frame.r.min.x, w->Frame.r.min.y+dl*w->font->height));
		if(selectq >= w->org+w->p1)
			wsetselect(w, w->org+w->p1, selectq);
		else
			wsetselect(w, selectq, w->org+w->p1);
	}
	wsetorigin(w, q0, TRUE);
}

/**************************************************/
/* Copied from frselect.c to work with MousectlEx */

static
int
region(int a, int b)
{
	if(a < b)
		return -1;
	if(a == b)
		return 0;
	return 1;
}

void
frselectex(Frame *f, MousectlEx *mc)	/* when called, button 1 is down */
{
	ulong p0, p1, q;
	Point mp, pt0, pt1, qt;
	int reg, b, scrled;

	mp = mc->xy;
	b = mc->buttons;

	f->modified = 0;
	frdrawsel(f, frptofchar(f, f->p0), f->p0, f->p1, 0);
	p0 = p1 = frcharofpt(f, mp);
	f->p0 = p0;
	f->p1 = p1;
	pt0 = frptofchar(f, p0);
	pt1 = frptofchar(f, p1);
	frdrawsel(f, pt0, p0, p1, 1);
	reg = 0;
	do{
		scrled = 0;
		if(f->scroll){
			if(mp.y < f->r.min.y){
				(*f->scroll)(f, -(f->r.min.y-mp.y)/(int)f->font->height-1);
				p0 = f->p1;
				p1 = f->p0;
				scrled = 1;
			}else if(mp.y > f->r.max.y){
				(*f->scroll)(f, (mp.y-f->r.max.y)/(int)f->font->height+1);
				p0 = f->p0;
				p1 = f->p1;
				scrled = 1;
			}
			if(scrled){
				if(reg != region(p1, p0))
					q = p0, p0 = p1, p1 = q;	/* undo the swap that will happen below */
				pt0 = frptofchar(f, p0);
				pt1 = frptofchar(f, p1);
				reg = region(p1, p0);
			}
		}
		q = frcharofpt(f, mp);
		if(p1 != q){
			if(reg != region(q, p0)){	/* crossed starting point; reset */
				if(reg > 0)
					frdrawsel(f, pt0, p0, p1, 0);
				else if(reg < 0)
					frdrawsel(f, pt1, p1, p0, 0);
				p1 = p0;
				pt1 = pt0;
				reg = region(q, p0);
				if(reg == 0)
					frdrawsel(f, pt0, p0, p1, 1);
			}
			qt = frptofchar(f, q);
			if(reg > 0){
				if(q > p1)
					frdrawsel(f, pt1, p1, q, 1);
				else if(q < p1)
					frdrawsel(f, qt, q, p1, 0);
			}else if(reg < 0){
				if(q > p1)
					frdrawsel(f, pt1, p1, q, 0);
				else
					frdrawsel(f, qt, q, p1, 1);
			}
			p1 = q;
			pt1 = qt;
		}
		f->modified = 0;
		if(p0 < p1) {
			f->p0 = p0;
			f->p1 = p1;
		}
		else {
			f->p0 = p1;
			f->p1 = p0;
		}
		if(scrled)
			(*f->scroll)(f, 0);
		flushimage(f->display, 1);
		if(!scrled)
			readmouseex(mc);
		mp = mc->xy;
	}while(mc->buttons == b);
}

/**************************************************/

void
wselection(Window *w)
{
	uint q0, q1;
	int b, x, y, first;

        if(w != input) return;

	first = 1;
	selectwin = w;
	/*
	 * Double-click immediately if it might make sense.
	 */
	b = w->mc.buttons;
	q0 = w->q0;
	q1 = w->q1;
	selectq = w->org+frcharofpt(w, w->mc.xy);
	if(clickwin==w && w->mc.msec-clickmsec<500)
	if(q0==q1 && selectq==w->q0){
		wdoubleclick(w, &q0, &q1);
		wsetselect(w, q0, q1);
		flushimage(display, 1);
		x = w->mc.xy.x;
		y = w->mc.xy.y;
		/* stay here until something interesting happens */
		do
			readmouseex(&w->mc);
		while(w->mc.buttons==b && abs(w->mc.xy.x-x)<3 && abs(w->mc.xy.y-y)<3);
		w->mc.xy.x = x;	/* in case we're calling frselect */
		w->mc.xy.y = y;
		q0 = w->q0;	/* may have changed */
		q1 = w->q1;
		selectq = q0;
	}
	if(w->mc.buttons == b){
		w->scroll = framescroll;
                frselectex(w, &w->mc);
		/* horrible botch: while asleep, may have lost selection altogether */
		if(selectq > w->nr)
			selectq = w->org + w->p0;
		w->Frame.scroll = nil;
		if(selectq < w->org)
			q0 = selectq;
		else
			q0 = w->org + w->p0;
		if(selectq > w->org+w->nchars)
			q1 = selectq;
		else
			q1 = w->org+w->p1;
	}
	if(q0 == q1){
		if(q0==w->q0 && clickwin==w && w->mc.msec-clickmsec<500){
			wdoubleclick(w, &q0, &q1);
			clickwin = nil;
		}else{
			clickwin = w;
			clickmsec = w->mc.msec;
		}
	}else
		clickwin = nil;
	wsetselect(w, q0, q1);
	flushimage(display, 1);
	while(w->mc.buttons){
		w->mc.msec = 0;
		b = w->mc.buttons;
		if(b & 6){
			if(b & 2){
				wsnarf(w);
				wcut(w);
			}else{
				if(first){
					first = 0;
					getsnarf();
				}
				wpaste(w);
			}
		}
		wscrdraw(w);
		flushimage(display, 1);
		while(w->mc.buttons == b)
			readmouseex(&w->mc);
		clickwin = nil;
	}
}

void
wsendctlmesg(Window *w, int type)
{
	send(w->cctl, &type);
}

int
wctlmesg(Window *w, int m)
{
	char buf[64];

	switch(m){
	default:
		error("unknown control message");
		break;
	case Wakeup:
		break;
	case Rawon:
		break;
	case Rawoff:
		if(w->deleted)
			break;
		while(w->nraw > 0){
			wkeyctl(w, w->raw[0]);
			--w->nraw;
			runemove(w->raw, w->raw+1, w->nraw);
		}
		break;
	case Holdon:
	case Holdoff:
		if(w->deleted)
			break;
		wrepaint(w);
		flushimage(display, 1);
		break;
	case Deleted:
		if(w->deleted)
			break;
		write(w->notefd, "hangup", 6);
		proccreate(deletetimeoutproc, estrdup(w->name), 4096);
		wclosewin(w);
		break;
	case Exited:
		frclear(w, TRUE);
		close(w->notefd);
		chanfree(w->mc.c);
		chanfree(w->ck);
		chanfree(w->cctl);
		chanfree(w->conswrite);
		chanfree(w->consread);
		chanfree(w->mouseread);
		chanfree(w->wctlread);
		free(w->raw);
		free(w->r);
		free(w->label);
                while (w->hsize > 0)
                    rmhist(w);
                free(w->hist);
                free(w->hedit);
                free(w->hsent);
		free(w);
		break;
	}
	return m;
}

/*
 * Go to a history entry based on the number in the current line edit.
 */
static void
locatehist(Window *w)
{
    int num, i;
    Rune r;

    if (w->qh == w->nr)
        return;

    num = 0;
    for (i = w->qh; i < w->nr; ++i) {
        Rune r = w->r[i];
        if (r < '0' || r > '9')
            return;
        num = 10 * num + (r - '0');
    }
    gotohist(w, num - w->hstartno);
}

#define HistCheck { \
        Rune *h = HistEntry(w,i); \
        if (runestrncmp(h, rs, rl) == 0 &&                 \
               (runestrlen(h) != tl || runestrncmp(h, rs, tl) != 0)) { \
            gotohist(w, i);                                             \
            wsetselect(w, w->qh + rl, w->qh + rl);                      \
            return;                                                     \
        } \
    }

/*
 * Search for a given history entry.
 */
static void
searchhist(Window *w, int dir)
{
    Rune *rs;
    int rl, tl, i;

    /* Get the string to search for and its length. */
    rs = &w->r[w->qh];
    rl = w->q0 - w->qh;
    if (rl < 0)
        return;

    /* Get the length of the current input line; we will skip lines that
     * match this whole line to avoid pressing ^r and getting the same
     * result repeatedly.
     */
    tl = w->nr - w->qh;

    /* Do a circular search backward of forward. */
    if (dir < 0) {
        for (i = w->hpos - 1; i >= 0; i--)
            HistCheck;
        for (i = w->hsize - 1; i >= w->hpos + 1; i--)
            HistCheck;
    } else {
        for (i = w->hpos + 1; i < w->hsize; i++)
            HistCheck;
        for (i = 0; i <= w->hpos - 1; i++)
            HistCheck;
    }
}

/*
 * Goto the given history number.
 */
static void
gotohist(Window *w, int pos)
{
    int nb;
    Rune *rs;

    if (pos < 0 || pos > w->hsize)
        return;

    /* If we're moving off the current edit line, save it into hedit. */
    if (w->hpos == w->hsize) {
        int len = w->nr - w->qh;
        w->hedit = erealloc(w->hedit, (1 + len) * sizeof(Rune));
        memcpy(w->hedit, &w->r[w->qh], len * sizeof(Rune));
        w->hedit[len] = 0;
    }

    /* Go to the end and delete the line, ^U-style */
    wsetselect(w, w->nr, w->nr);
    if (w->qh != w->nr) {
        nb = wbswidth(w, 0x15);  // 0x15 = ^U
        if (nb > 0) {
            wdelete(w, w->nr - nb, w->nr);
            wsetselect(w, w->nr, w->nr);
        }
    }

    /* The string to insert is either hedit if we're one beyond the
     *  history, or the relevant entry.
     */
    if (pos == w->hsize)
        rs = w->hedit;
    else
        rs = HistEntry(w, pos);

    /* Insert it. */
    winsert(w, rs, runestrlen(rs), w->nr);
    wsetselect(w, w->nr, w->nr);
    wshow(w, w->nr);

    /* Note the new position */
    w->hpos = pos;
}

/* Add the characters in from..to, which are about to be sent to the
 * reader of cons; if they end with a newline or ^d, create a new
 * history entry, otherwise buffer them for next time.
 */
static void
addhist(Window *w, int from, int to)
{
    Rune *rs;
    int i, b;
    /* Add the new chars to the hsent buffer */
    w->hsent = erealloc(w->hsent, (w->hsentlen + to - from) * sizeof(Rune));
    for (i = from; i < to; ++i)
        w->hsent[w->hsentlen++] = w->r[i];

    /* If hsent now ends with a newline or ^d char, then empty hsent
     * and add a new entry to the history.
     */
    if (w->hsentlen > 0 && (w->hsent[w->hsentlen - 1] == '\n' || w->hsent[w->hsentlen - 1] == 4)) {
        /* Don't add an empty string to the history. */
        if (w->hsentlen > 1) {
            rs = emalloc(sizeof(Rune) * w->hsentlen);
            memcpy(rs, w->hsent, (w->hsentlen - 1) * sizeof(Rune));
            rs[w->hsentlen - 1] = 0;
            /* If history full, make room for one entry. */
            if (w->hsize == w->hlimit)
                rmhist(w);
            w->hist[w->hlast] = rs;
            w->hlast = (w->hlast + 1) % w->hlimit;
            w->hsize++;
        }
        resethist(w);
        w->hsentlen = 0;
    }
}

/*
 * Remove the oldest history entry.
 */
static void
rmhist(Window *w)
{
    if (w->hsize == 0)
        return;
    free(w->hist[w->hfirst]);
    w->hfirst = (w->hfirst + 1) % w->hlimit;
    w->hstartno++;
    w->hsize--;
}

/*
 * Reset the history position to be the current edit line, ie just one
 * beyond the history size.
 */
static void
resethist(Window *w)
{
    w->hpos = w->hsize;
}

void
wreshaped(Window *w, Image *i)
{
    char *t;
    if(w->deleted){
        freeimage(i);
        return;
    }
    w->screenr = (i->screen) ? i->r : ZR;
    t = estrdup(w->name);
    wresize(w, i);
    w->wctlready = 1;
    proccreate(deletetimeoutproc, t, 4096);
    /* This is also equivalent to a Wakeup, which we need since
     * wctlready is being set to 1 above. */
    sendmouseevent(w, 'r');
}

/*
 * Convert back to physical coordinates
 */
void
wmovemouse(Window *w, Point p)
{
	p.x += w->screenr.min.x-w->i->r.min.x;
	p.y += w->screenr.min.y-w->i->r.min.y;
	moveto(mousectl, p);
}

void
wborder(Window *w, int type)
{
	Image *col;
        
	if(w->noborder || w->i == nil)
		return;
	if(w->holding){
		if(type == Selborder)
			col = holdcol;
		else
			col = paleholdcol;
	}else{
		if(type == Selborder)
			col = titlecol;
		else
			col = lighttitlecol;
	}

	border(w->i, w->i->r, Selborder, col, ZP);
}

Window*
wpointto(Point pt)
{
	int i;
	Window *v, *w;

	w = nil;
	for(i=0; i<nwindow; i++){
		v = window[i];
		if(ptinrect(pt, v->screenr))
		if(!v->deleted)
		if(w==nil || v->topped>w->topped)
			w = v;
	}
	return w;
}

void
choosewcurrent(void)
{
    Window *w = 0;
    int i;
    for(i=0; i<nwindow; i++) {
        Window *x = window[i];
        if (!x->hidden && !x->noborder) {   /* if not hidden and has border */
            if (!w || x->topped > w->topped)
                w = x;
        }
    }
    if (w)
        wcurrent(w);
}

int
wcurrent(Window *w)
{
	Window *oi;

        if(w && (w->noborder || w->hidden))
            return 0;

	if(wkeyboard!=nil && w==wkeyboard)
		return 0;
	oi = input;
	input = w;
        if(oi)
            oi->transientforroot->rememberedfocus = oi;
	if(oi!=w && oi!=nil)
		wrepaint(oi);
	if(w !=nil){
		wrepaint(w);
		wsetcursor(w, 0);
	}
	if(w != oi){
		if(oi){
			oi->wctlready = 1;
			wsendctlmesg(oi, Wakeup);
		}
		if(w){
			w->wctlready = 1;
			wsendctlmesg(w, Wakeup);
		}
                flushimage(display, 1);
	}
        return 1;
}

void
wsetcursor(Window *w, int force)
{
	Cursor *p;
        if(grabpointer && w != grabpointer)
            return;
	if(w==nil || /*w!=input || */ w->i==nil || Dx(w->screenr)<=0)
		p = nil;
	else if(grabpointer || wpointto(mouse->xy) == w){
		p = w->cursorp;
		if(p==nil && w->holding)
			p = &whitearrow;
	}else
		p = nil;
	if(!menuing)
		riosetcursor(p, force && !menuing);
}

void
riosetcursor(Cursor *p, int force)
{
	if(!force && p==lastcursor)
		return;
	setcursor(mousectl, p);
	lastcursor = p;
}

/*
 * Adjust the order values so that transient stacking order is
 * maintained correctly.
 */
void ensure_transient_stacking(void)
{
    int i;
    for(i=0; i<nwindow; i++) {
        Window *x, *w = window[i];
        if ((x = w->transientfor) && x->order > w->order) 
            w->order = ++order;
    }
}

/*
 * Adjust the order values so that transient stacking order is
 * maintained correctly.
 */
void ensure_transient_stacking_rev(void)
{
    int i;
    for(i = nwindow-1; i >= 0; i--) {
        Window *x, *w = window[i];
        if ((x = w->transientfor) && x->order > w->order) 
            x->order = - ++order;
    }
}

static
int order_cmp(void *x, void*y)
{
    Window *w1 = *((Window **)x);
    Window *w2 = *((Window **)y);
    if (w1->transientforroot->layer == w2->transientforroot->layer)
        return w1->order - w2->order;
    else
        return w1->transientforroot->layer - w2->transientforroot->layer;
}

/*
 * Get the windows in an array sorted by order, so that the first
 * element is the lowest in the order.
 */
static Window **get_sorted_windows(void)
{
    Window **sortwin;
    sortwin = emalloc(nwindow * sizeof(Window *));
    memcpy(sortwin, window, nwindow * sizeof(Window *));
    qsort(sortwin, nwindow, sizeof(Window *), order_cmp);
    return sortwin;
}

/*
 * Check if an array of windows is correctly ordered by the topped field.
 */
static int ordered(Window **w, int n)
{
    int i;
    for (i = 0; i < n; ++i) {
        if (i > 0 && w[i-1]->topped > w[i]->topped)
            return 0;
    }
    return 1;
}

/*
 * Make the actual stacking order of the windows (indicated by the
 * topped field) match with the desired order (indicated by
 * order and layer).
 */
void
reconcile_stacking(void)
{
    Window **sortwin;
    int i, nw;

    sortwin = get_sorted_windows();

    /* Reduce sortwin so that it only includes unhidden windows */
    nw = 0;
    for(i=0; i<nwindow; i++) {
        if (!sortwin[i]->hidden) {
            if (nw != i)
                sortwin[nw] = sortwin[i];
            ++nw;
        }
    }

    /*
     * Now sortwin holds the desired order of the visible window
     * stack, with sortwin[0] being the bottom and sortwin[nw-1] being
     * the top.  Check if the current actual stack order is the same;
     * if so do nothing.  If all but either the first or last element
     * are already in order, then we can use either topwindow or
     * bottomwindow; otherwise we have to use bottomnwindows to reset
     * the order entirely.
     */
    if (!ordered(sortwin, nw)) {
        if (ordered(sortwin, nw - 1)) {
            topwindow(sortwin[nw - 1]->i);
            sortwin[nw - 1]->topped = ++topped;
        } else if (ordered(sortwin + 1, nw - 1)) { 
            bottomwindow(sortwin[0]->i);
            sortwin[0]->topped = - ++topped;
        }
        else {
            Image **img = emalloc(nw * sizeof(Image *));
            for(i=0; i<nw; i++) {
                Window *w = sortwin[i];
                img[i] = w->i;
                w->topped = ++topped;
            }
            bottomnwindows(img, nw);
            free(img);
        }
    }
    flushimage(display, 1);
    free(sortwin);
}

int wtop(Window *w)
{
    Window **sortwin;
    int i;

    w->order = ++order;
    ensure_transient_stacking();

    /*
     * Move all the windows in w's transient group to the top.  This
     * stage avoids any other window coming amongst the group's order.
     * For example if we have A1 A2 A3 X, and top A2, unless we moved
     * A1 and A3, we would be left with A1 A3 X A2, rather than X A1
     * A3 A2.
     */
    sortwin = get_sorted_windows();
    w = w->transientforroot;
    for(i=0; i<nwindow; i++) {
        Window *x = sortwin[i];
        if (w == x->transientforroot)
            x->order = ++order;
    }
    free(sortwin);

    reconcile_stacking();
    return 1;
}

int
wbottom(Window *w)
{
    Image **below;
    Window **sortwin;
    int i, nbelow;

    w->order = - ++order;
    ensure_transient_stacking_rev();

    sortwin = get_sorted_windows();
    w = w->transientforroot;
    for(i = nwindow-1; i >= 0; i--) {
        Window *x = sortwin[i];
        if (w == x->transientforroot)
            x->order = - ++order;
    }
    free(sortwin);

    reconcile_stacking();
    return 1;
}

Window*
wlookid(int id)
{
	int i;

	for(i=0; i<nwindow; i++)
		if(window[i]->id == id)
			return window[i];
	return nil;
}

void
wclosewin(Window *w)
{
	Rectangle r;
	int i, findinput = 0;

	w->deleted = TRUE;
        if(w == held) held = nil;
        if(w == eein) eein = nil;
        if(w == grabpointer) grabpointer = nil;
        if(w == grabkeyboard) grabkeyboard = nil;
        if(w == over) over = nil;
        if(w == overb) overb = nil;
        if(w == overw) overw = nil;
        if(w->transientforroot->rememberedfocus == w)
            w->transientforroot->rememberedfocus = nil;
	if(w == input){
		input = nil;
		wsetcursor(w, 0);
                findinput = 1;
	}
	if(w == wkeyboard)
		wkeyboard = nil;
	for(i=0; i<nwindow; i++)
		if(window[i] == w){
			--nwindow;
			memmove(window+i, window+i+1, (nwindow-i)*sizeof(Window*));
			w->deleted = TRUE;
			r = w->i->r;
			/* move it off-screen to hide it, in case client is slow in letting it go */
			MOVEIT originwindow(w->i, r.min, view->r.max);
			freeimage(w->i);
			w->i = nil;

                        /* If the closing window had input, try to find another window to give it to. */
                        if(findinput)
                            choosewcurrent();
                        if(w->transientfor) {
                            w->transientforroot = w;
                            wclose(w->transientfor);
                            w->transientfor = nil;
                        }
			return;
		}
	error("unknown window in closewin");
}

void
wsetpid(Window *w, int pid, int dolabel)
{
	char buf[128];
	int fd;

	w->pid = pid;
	if(dolabel){
		sprint(buf, "rc %d", pid);
		free(w->label);
		w->label = estrdup(buf);
	}
	sprint(buf, "/proc/%d/notepg", pid);
	fd = open(buf, OWRITE|OCEXEC);
	if(w->notefd > 0)
		close(w->notefd);

	w->notefd = fd;
}

void
winshell(void *args)
{
	Window *w;
	Channel *pidc;
	void **arg;
	char *cmd, *dir;
	char **argv;

	arg = args;
	w = arg[0];
	pidc = arg[1];
	cmd = arg[2];
	argv = arg[3];
	dir = arg[4];
	rfork(RFNAMEG|RFFDG|RFENVG);
	if(filsysmount(filsys, w->id) < 0){
		fprint(2, "mount failed: %r\n");
		sendul(pidc, 0);
		threadexits("mount failed");
	}
	close(0);
	if(open("/dev/cons", OREAD) < 0){
		fprint(2, "can't open /dev/cons: %r\n");
		sendul(pidc, 0);
		threadexits("/dev/cons");
	}
	close(1);
	if(open("/dev/cons", OWRITE) < 0){
		fprint(2, "can't open /dev/cons: %r\n");
		sendul(pidc, 0);
		threadexits("open");	/* BUG? was terminate() */
	}
	if(wclose(w) == 0){	/* remove extra ref hanging from creation */
		notify(nil);
		dup(1, 2);
		if(dir)
			chdir(dir);
		procexec(pidc, cmd, argv);
		_exits("exec failed");
	}
}

static Rune left1[] =  { L'{', L'[', L'(', L'<', L'«', 0 };
static Rune right1[] = { L'}', L']', L')', L'>', L'»', 0 };
static Rune left2[] =  { L'\n', 0 };
static Rune left3[] =  { L'\'', L'"', L'`', 0 };

Rune *left[] = {
	left1,
	left2,
	left3,
	nil
};
Rune *right[] = {
	right1,
	left2,
	left3,
	nil
};

void
wdoubleclick(Window *w, uint *q0, uint *q1)
{
	int c, i;
	Rune *r, *l, *p;
	uint q;

	for(i=0; left[i]!=nil; i++){
		q = *q0;
		l = left[i];
		r = right[i];
		/* try matching character to left, looking right */
		if(q == 0)
			c = '\n';
		else
			c = w->r[q-1];
		p = strrune(l, c);
		if(p != nil){
			if(wclickmatch(w, c, r[p-l], 1, &q))
				*q1 = q-(c!='\n');
			return;
		}
		/* try matching character to right, looking left */
		if(q == w->nr)
			c = '\n';
		else
			c = w->r[q];
		p = strrune(r, c);
		if(p != nil){
			if(wclickmatch(w, c, l[p-r], -1, &q)){
				*q1 = *q0+(*q0<w->nr && c=='\n');
				*q0 = q;
				if(c!='\n' || q!=0 || w->r[0]=='\n')
					(*q0)++;
			}
			return;
		}
	}
	/* try filling out word to right */
	while(*q1<w->nr && isalnum(w->r[*q1]))
		(*q1)++;
	/* try filling out word to left */
	while(*q0>0 && isalnum(w->r[*q0-1]))
		(*q0)--;
}

int
wclickmatch(Window *w, int cl, int cr, int dir, uint *q)
{
	Rune c;
	int nest;

	nest = 1;
	for(;;){
		if(dir > 0){
			if(*q == w->nr)
				break;
			c = w->r[*q];
			(*q)++;
		}else{
			if(*q == 0)
				break;
			(*q)--;
			c = w->r[*q];
		}
		if(c == cr){
			if(--nest==0)
				return 1;
		}else if(c == cl)
			nest++;
	}
	return cl=='\n' && nest==1;
}


uint
wbacknl(Window *w, uint p, uint n)
{
	int i, j;

	/* look for start of this line if n==0 */
	if(n==0 && p>0 && w->r[p-1]!='\n')
		n = 1;
	i = n;
	while(i-->0 && p>0){
		--p;	/* it's at a newline now; back over it */
		if(p == 0)
			break;
		/* at 128 chars, call it a line anyway */
		for(j=128; --j>0 && p>0; p--)
			if(w->r[p-1]=='\n')
				break;
	}
	return p;
}

void
wshow(Window *w, uint q0)
{
	int qe;
	int nl;
	uint q;
        int t;

	qe = w->org+w->nchars;
        /* This calculation stops the cursor disappearing below the
         * window when a newline is the last char and at the bottom of
         * the window. */
        t = w->nlines;
        if (w->nr > 0 && w->r[w->nr - 1] == '\n')
            ++t;
	if(w->org<=q0 && (q0<qe || (q0==qe && qe==w->nr && t <= w->maxlines)))
		wscrdraw(w);
	else{
		nl = 4*w->maxlines/5;
		q = wbacknl(w, q0, nl);
		/* avoid going backwards if trying to go forwards - long lines! */
		if(!(q0>w->org && q<w->org))
			wsetorigin(w, q, TRUE);
		while(q0 > w->org+w->nchars)
			wsetorigin(w, w->org+1, FALSE);
	}
}

void
wsetorigin(Window *w, uint org, int exact)
{
	int i, a, fixup;
	Rune *r;
	uint n;

	if(org>0 && !exact){
		/* org is an estimate of the char posn; find a newline */
		/* don't try harder than 256 chars */
		for(i=0; i<256 && org<w->nr; i++){
			if(w->r[org] == '\n'){
				org++;
				break;
			}
			org++;
		}
	}
	a = org-w->org;
	fixup = 0;
	if(a>=0 && a<w->nchars){
		frdelete(w, 0, a);
		fixup = 1;	/* frdelete can leave end of last line in wrong selection mode; it doesn't know what follows */
	}else if(a<0 && -a<w->nchars){
		n = w->org - org;
		r = runemalloc(n);
		runemove(r, w->r+org, n);
		frinsert(w, r, r+n, 0);
		free(r);
	}else
		frdelete(w, 0, w->nchars);
	w->org = org;
	wfill(w);
	wscrdraw(w);
	wsetselect(w, w->q0, w->q1);
	if(fixup && w->p1 > w->p0)
		frdrawsel(w, frptofchar(w, w->p1-1), w->p1-1, w->p1, 1);
}

void
wsetselect(Window *w, uint q0, uint q1)
{
	int p0, p1;

	/* w->p0 and w->p1 are always right; w->q0 and w->q1 may be off */
	w->q0 = q0;
	w->q1 = q1;
	/* compute desired p0,p1 from q0,q1 */
	p0 = q0-w->org;
	p1 = q1-w->org;
	if(p0 < 0)
		p0 = 0;
	if(p1 < 0)
		p1 = 0;
	if(p0 > w->nchars)
		p0 = w->nchars;
	if(p1 > w->nchars)
		p1 = w->nchars;
	if(p0==w->p0 && p1==w->p1)
		return;
	/* screen disagrees with desired selection */
	if(w->p1<=p0 || p1<=w->p0 || p0==p1 || w->p1==w->p0){
		/* no overlap or too easy to bother trying */
		frdrawsel(w, frptofchar(w, w->p0), w->p0, w->p1, 0);
		frdrawsel(w, frptofchar(w, p0), p0, p1, 1);
		goto Return;
	}
	/* overlap; avoid unnecessary painting */
	if(p0 < w->p0){
		/* extend selection backwards */
		frdrawsel(w, frptofchar(w, p0), p0, w->p0, 1);
	}else if(p0 > w->p0){
		/* trim first part of selection */
		frdrawsel(w, frptofchar(w, w->p0), w->p0, p0, 0);
	}
	if(p1 > w->p1){
		/* extend selection forwards */
		frdrawsel(w, frptofchar(w, w->p1), w->p1, p1, 1);
	}else if(p1 < w->p1){
		/* trim last part of selection */
		frdrawsel(w, frptofchar(w, p1), p1, w->p1, 0);
	}

    Return:
	w->p0 = p0;
	w->p1 = p1;
}

uint
winsert(Window *w, Rune *r, int n, uint q0)
{
	uint m;

	if(n == 0)
		return q0;
	if(w->nr+n>HiWater && q0>=w->org && q0>=w->qh){
		m = min(HiWater-LoWater, min(w->org, w->qh));
		w->org -= m;
		w->qh -= m;
		if(w->q0 > m)
			w->q0 -= m;
		else
			w->q0 = 0;
		if(w->q1 > m)
			w->q1 -= m;
		else
			w->q1 = 0;
		w->nr -= m;
		runemove(w->r, w->r+m, w->nr);
		q0 -= m;
	}
	if(w->nr+n > w->maxr){
		/*
		 * Minimize realloc breakage:
		 *	Allocate at least MinWater
		 * 	Double allocation size each time
		 *	But don't go much above HiWater
		 */
		m = max(min(2*(w->nr+n), HiWater), w->nr+n)+MinWater;
		if(m > HiWater)
			m = max(HiWater+MinWater, w->nr+n);
		if(m > w->maxr){
			w->r = runerealloc(w->r, m);
			w->maxr = m;
		}
	}
	runemove(w->r+q0+n, w->r+q0, w->nr-q0);
	runemove(w->r+q0, r, n);
	w->nr += n;
	/* if output touches, advance selection, not qh; works best for keyboard and output */
	if(q0 <= w->q1)
		w->q1 += n;
	if(q0 <= w->q0)
		w->q0 += n;
	if(q0 < w->qh)
		w->qh += n;
	if(q0 < w->org)
		w->org += n;
	else if(q0 <= w->org+w->nchars)
		frinsert(w, r, r+n, q0-w->org);
	return q0;
}

void
wfill(Window *w)
{
	Rune *rp;
	int i, n, m, nl;

	if(w->lastlinefull)
		return;
	rp = malloc(messagesize);
	do{
		n = w->nr-(w->org+w->nchars);
		if(n == 0)
			break;
		if(n > 2000)	/* educated guess at reasonable amount */
			n = 2000;
		runemove(rp, w->r+(w->org+w->nchars), n);
		/*
		 * it's expensive to frinsert more than we need, so
		 * count newlines.
		 */
		nl = w->maxlines-w->nlines;
		m = 0;
		for(i=0; i<n; ){
			if(rp[i++] == '\n'){
				m++;
				if(m >= nl)
					break;
			}
		}
		frinsert(w, rp, rp+i, w->nchars);
	}while(w->lastlinefull == FALSE);
	free(rp);
}

char*
wcontents(Window *w, int *ip)
{
	return runetobyte(w->r, w->nr, ip);
}

char*
whist(Window *w, int *ip)
{
    int ulen, i, max;
    char *res, *p;

    ulen = 0;
    for (i = 0; i < w->hsize; ++i) {
        Rune *rs = HistEntry(w, i);
        ulen += runestrlen(rs);
    }
    max = ulen * UTFmax + 8 * w->hsize;
    res = p = emalloc(max);

    for (i = 0; i < w->hsize; ++i) {
        Rune *rs = HistEntry(w, i);
        p += sprint(p, "%4d  %S\n", i + w->hstartno, rs);
    }
    *ip = p - res;
    return res;
}
