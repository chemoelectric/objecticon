#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include "frame.h"

#define	DELTA	25

static Frame		frame;

static
Point
bxscan(Frame *f, Rune *sp, Attr *ap, uint nchar, Point *ppt)
{
	int c, nb, delta, nl, nr;
	Frbox *b;
        Rune *rp;
        Rune *ep;
        Attr a0,a1;
        ep = sp + nchar;
	frame.r = f->r;
	frame.b = f->b;
	frame.font = f->font;
	frame.maxtab = f->maxtab;
	frame.nbox = 0;
	frame.nchars = 0;
	memmove(frame.fonts, f->fonts, sizeof frame.fonts);
	memmove(frame.cols, f->cols, sizeof frame.cols);
	delta = DELTA;
	nl = 0;
	for(nb=0; sp<ep && nl<=f->maxlines; nb++,frame.nbox++){
		if(nb == frame.nalloc){
			_frgrowbox(&frame, delta);
			if(delta < 10000)
				delta *= 2;
		}
		b = &frame.box[nb];
		c = *sp;
		if(c=='\t' || c=='\n'){
			b->bc = c;
			b->wid = 5000;
			b->minwid = (c=='\n')? 0 : stringwidth(frame.font, " ");
			b->nrune = -1;
			if(c=='\n')
				nl++;
			frame.nchars++;
			sp++; 
                        if(ap) ap++;
		}else{
			nr = 0;
                        a0 = ap ? *ap : 0;
			while(sp < ep){
				c = *sp;
                                a1 = ap ? *ap : 0;
				if(a1 != a0 || c=='\t' || c=='\n')
					break;
				sp++; 
                                if(ap) ap++;
				nr++;
			}
			b = &frame.box[nb];
                        rp = _frallocrunestr(f, nr + 1);
                        memcpy(rp, sp - nr, nr * sizeof(Rune));
                        rp[nr] = 0;
                        b->rptr = rp;
                        b->attr = a0;
			b->nrune = nr;
			b->wid = runestringwidth(frboxfont(&frame,b), b->rptr);
			frame.nchars += nr;
		}
	}
	_frcklinewrap0(f, ppt, &frame.box[0]);
	return _frdraw(&frame, *ppt);
}

static
void
chopframe(Frame *f, Point pt, ulong p, int bn)
{
	Frbox *b;

	for(b = &f->box[bn]; ; b++){
		if(b >= &f->box[f->nbox])
			drawerror(f->display, "endofframe");
		_frcklinewrap(f, &pt, b);
		if(pt.y >= f->r.max.y)
			break;
		p += NRUNE(b);
		_fradvance(f, &pt, b);
	}
	f->nchars = p;
	f->nlines = f->maxlines;
	if(b<&f->box[f->nbox])				/* BUG */
		_frdelbox(f, (int)(b-f->box), f->nbox-1);
}

void
frdump(Frame *f)
{
    int i;
    print("Frame %p\n", f);
    print("nlines=%d nbox=%d nalloc=%d\n", f->nlines, f->nbox, f->nalloc);
    for (i = 0; i < f->nbox; ++i) {
        Frbox *b = &f->box[i];
        print("\tbox[%d] %p\n", i, b);
        print("\t\twid=%ld nrune=%ld\n", b->wid, b->nrune);
        if (b->nrune >= 0) {
            print("\t\tattr=");frprintattr(b->attr); 
            print("\n\t\trptr='%S'(%d)\n", b->rptr, runestrlen(b->rptr));
        } else
            print("\t\tbc=%d minwid=%d\n", (int)b->bc, (int)b->minwid);
    }
    print("----------\n");
}

static void
dump_content(Rune *sp, Attr *ap, uint nchar)
{
    Rune c;
    Attr a = 0;
    int i;
    print("nr=%d:",nchar);
    for (i = 0; i < nchar; ++i) {
        if (ap[i] != a) {
            a = ap[i];
            frprintattr(a);
        }
        print("%C",sp[i]);
    }
    print(":\n");
}

void
frinsert(Frame *f, Rune *sp, Attr *ap, uint nchar, ulong p0)
{
	Point pt0, pt1, opt0, ppt0, ppt1, pt;
        Rune *ep;
	Frbox *b;
	int n, n0, nn0, y;
	ulong cn0;
	Image *col;
	Rectangle r;
	static struct{
		Point pt0, pt1;
	}*pts;
	static int nalloc=0;
	int npts;
        //print("frinsert attr=%p\n",ap);//        dump_content(sp,ap,nchar);
        ep = sp + nchar;
	if(p0>f->nchars || sp==ep || f->b==nil)
		return;
	n0 = _frfindbox(f, 0, 0, p0);
	cn0 = p0;
	nn0 = n0;
	pt0 = _frptofcharnb(f, p0, n0);
	ppt0 = pt0;
	opt0 = pt0;
	pt1 = bxscan(f, sp, ap, nchar, &ppt0);
	ppt1 = pt1;
	if(n0 < f->nbox){
		_frcklinewrap(f, &pt0, b = &f->box[n0]);	/* for frdrawsel() */
		_frcklinewrap0(f, &ppt1, b);
	}
	f->modified = 1;
	/*
	 * ppt0 and ppt1 are start and end of insertion as they will appear when
	 * insertion is complete. pt0 is current location of insertion position
	 * (p0); pt1 is terminal point (without line wrap) of insertion.
	 */
	if(f->p0 == f->p1)
		frtick(f, frptofchar(f, f->p0), 0);

	/*
	 * Find point where old and new x's line up
	 * Invariants:
	 *	pt0 is where the next box (b, n0) is now
	 *	pt1 is where it will be after the insertion
	 * If pt1 goes off the rectangle, we can toss everything from there on
	 */
	for(b = &f->box[n0],npts=0;
	     pt1.x!=pt0.x && pt1.y!=f->r.max.y && n0<f->nbox; b++,n0++,npts++){
		_frcklinewrap(f, &pt0, b);
		_frcklinewrap0(f, &pt1, b);
		if(b->nrune > 0){
			n = _frcanfit(f, pt1, b);
			if(n == 0)
				drawerror(f->display, "_frcanfit==0");
			if(n != b->nrune){
				_frsplitbox(f, n0, n);
				b = &f->box[n0];
			}
		}
		if(npts == nalloc){
			pts = realloc(pts, (npts+DELTA)*sizeof(pts[0]));
			nalloc += DELTA;
			b = &f->box[n0];
		}
		pts[npts].pt0 = pt0;
		pts[npts].pt1 = pt1;
		/* has a text box overflowed off the frame? */
		if(pt1.y == f->r.max.y)
			break;
		_fradvance(f, &pt0, b);
		pt1.x += _frnewwid(f, pt1, b);
		cn0 += NRUNE(b);
	}
	if(pt1.y > f->r.max.y)
		drawerror(f->display, "frinsert pt1 too far");
	if(pt1.y==f->r.max.y && n0<f->nbox){
		f->nchars -= _frstrlen(f, n0);
		_frdelbox(f, n0, f->nbox-1);
	}
	if(n0 == f->nbox)
		f->nlines = (pt1.y-f->r.min.y)/f->font->height+(pt1.x>f->r.min.x);
	else if(pt1.y!=pt0.y){
		int q0, q1;

		y = f->r.max.y;
		q0 = pt0.y+f->font->height;
		q1 = pt1.y+f->font->height;
		f->nlines += (q1-q0)/f->font->height;
		if(f->nlines > f->maxlines)
			chopframe(f, ppt1, p0, nn0);
		if(pt1.y < y){
			r = f->r;
			r.min.y = q1;
			r.max.y = y;
			if(q1 < y)
				draw(f->b, r, f->b, nil, Pt(f->r.min.x, q0));
			r.min = pt1;
			r.max.x = pt1.x+(f->r.max.x-pt0.x);
			r.max.y = q1;
			draw(f->b, r, f->b, nil, pt0);
		}
	}
	/*
	 * Move the old stuff down to make room.  The loop will move the stuff
	 * between the insertion and the point where the x's lined up.
	 * The draw()s above moved everything down after the point they lined up.
	 */
	for((y=pt1.y==f->r.max.y?pt1.y:0),b = &f->box[n0-1]; --npts>=0; --b){
		pt = pts[npts].pt1;
		if(b->nrune > 0){
			r.min = pt;
			r.max = r.min;
			r.max.x += b->wid;
			r.max.y += f->font->height;
			draw(f->b, r, f->b, nil, pts[npts].pt0);
			/* clear bit hanging off right */
			if(npts==0 && pt.y>pt0.y){
				/*
				 * first new char is bigger than first char we're
				 * displacing, causing line wrap. ugly special case.
				 */
				r.min = opt0;
				r.max = opt0;
				r.max.x = f->r.max.x;
				r.max.y += f->font->height;
				if(f->p0<=cn0 && cn0<f->p1)	/* b+1 is inside selection */
					col = f->cols[HIGH];
				else
					col = f->cols[BACK];
				draw(f->b, r, col, nil, r.min);
			}else if(pt.y < y){
				r.min = pt;
				r.max = pt;
				r.min.x += b->wid;
				r.max.x = f->r.max.x;
				r.max.y += f->font->height;
				if(f->p0<=cn0 && cn0<f->p1)	/* b+1 is inside selection */
					col = f->cols[HIGH];
				else
					col = f->cols[BACK];
				draw(f->b, r, col, nil, r.min);
			}
			y = pt.y;
			cn0 -= b->nrune;
		}else{
			r.min = pt;
			r.max = pt;
			r.max.x += b->wid;
			r.max.y += f->font->height;
			if(r.max.x >= f->r.max.x)
				r.max.x = f->r.max.x;
			cn0--;
			if(f->p0<=cn0 && cn0<f->p1)	/* b is inside selection */
				col = f->cols[HIGH];
			else
				col = f->cols[BACK];
			draw(f->b, r, col, nil, r.min);
			y = 0;
			if(pt.x == f->r.min.x)
				y = pt.y;
		}
	}
	/* insertion can extend the selection, so the condition here is different */
	if(f->p0<p0 && p0<=f->p1)
		col = f->cols[HIGH];
	else
		col = f->cols[BACK];
	frselectpaint(f, ppt0, ppt1, col);
	_frdrawtext(&frame, ppt0, f->cols[TEXT], col);
	_fraddbox(f, nn0, frame.nbox);
	for(n=0; n<frame.nbox; n++)
		f->box[nn0+n] = frame.box[n];
	if(nn0>0 && f->box[nn0-1].nrune>=0 && ppt0.x-f->box[nn0-1].wid>=f->r.min.x){
		--nn0;
		ppt0.x -= f->box[nn0].wid;
	}
	n0 += frame.nbox;
	_frclean(f, ppt0, nn0, n0<f->nbox-1? n0+1 : n0);
	f->nchars += frame.nchars;
	if(f->p0 >= p0)
		f->p0 += frame.nchars;
	if(f->p0 > f->nchars)
		f->p0 = f->nchars;
	if(f->p1 >= p0)
		f->p1 += frame.nchars;
	if(f->p1 > f->nchars)
		f->p1 = f->nchars;
	if(f->p0 == f->p1)
		frtick(f, frptofchar(f, f->p0), 1);
        //frdump(f);
}
