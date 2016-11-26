#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include "frame.h"

#define	SLOP	25

void
_fraddbox(Frame *f, int bn, int n)	/* add n boxes after bn, shift the rest up,
				 * box[bn+n]==box[bn] */
{
	int i;

	if(bn > f->nbox)
		drawerror(f->display, "_fraddbox");
	if(f->nbox+n > f->nalloc)
		_frgrowbox(f, n+SLOP);
	for(i=f->nbox; --i>=bn; )
		f->box[i+n] = f->box[i];
	f->nbox+=n;
}

void
_frclosebox(Frame *f, int n0, int n1)	/* inclusive */
{
	int i;

	if(n0>=f->nbox || n1>=f->nbox || n1<n0)
		drawerror(f->display, "_frclosebox");
	n1++;
	for(i=n1; i<f->nbox; i++)
		f->box[i-(n1-n0)] = f->box[i];
	f->nbox -= n1-n0;
}

void
_frdelbox(Frame *f, int n0, int n1)	/* inclusive */
{
	if(n0>=f->nbox || n1>=f->nbox || n1<n0)
		drawerror(f->display, "_frdelbox");
	_frfreebox(f, n0, n1);
	_frclosebox(f, n0, n1);
}

void
_frfreebox(Frame *f, int n0, int n1)	/* inclusive */
{
	int i;

	if(n1<n0)
		return;
	if(n0>=f->nbox || n1>=f->nbox)
		drawerror(f->display, "_frfreebox");
	n1++;
	for(i=n0; i<n1; i++)
              if(f->box[i].nrune >= 0)
			free(f->box[i].rptr);
}

void
_frgrowbox(Frame *f, int delta)
{
	f->nalloc += delta;
	f->box = _frrealloc(f, f->box, f->nalloc*sizeof(Frbox));
}

static
void
dupbox(Frame *f, int bn)
{
        Rune *r;

	if(f->box[bn].nrune < 0)
		drawerror(f->display, "dupbox");
	_fraddbox(f, bn, 1);
	if(f->box[bn].nrune >= 0){
                assert(f->box[bn].nrune == runestrlen(f->box[bn].rptr));
                r = _frmalloc(f, (f->box[bn].nrune + 1) * sizeof(Rune));
                runestrcpy(r, f->box[bn].rptr);
                f->box[bn+1].rptr = r;
                f->box[bn+1].attr = f->box[bn].attr;
	}
}

static
uchar*
runeindex(uchar *p, int n)
{
	int i, w;
	Rune rune;

	for(i=0; i<n; i++,p+=w)
		if(*p < Runeself)
			w = 1;
		else{
			w = chartorune(&rune, (char*)p);
			USED(rune);
		}
	return p;
}

static
void
truncatebox(Frame *f, Frbox *b, int n)	/* drop last n chars; no allocation done */
{
	if(b->nrune<0 || b->nrune<n)
		drawerror(f->display, "truncatebox");
	b->nrune -= n;
        b->rptr[b->nrune] = 0;
	b->wid = runestringwidth(_frboxfont(f, b), b->rptr);
}

static
void
chopbox(Frame *f, Frbox *b, int n)	/* drop first n chars; no allocation done */
{
	if(b->nrune<0 || b->nrune<n)
		drawerror(f->display, "chopbox");
        assert(b->nrune == runestrlen(b->rptr));
        memmove(b->rptr, b->rptr + n, sizeof(Rune) * (b->nrune - n + 1));
	b->nrune -= n;
	b->wid = runestringwidth(_frboxfont(f, b), b->rptr);
}

void
_frsplitbox(Frame *f, int bn, int n)
{
	dupbox(f, bn);
	truncatebox(f, &f->box[bn], f->box[bn].nrune-n);
	chopbox(f, &f->box[bn+1], n);
}

void
_frmergebox(Frame *f, int bn)		/* merge bn and bn+1 */
{
	Frbox *b;
	b = &f->box[bn];
        assert(b[0].attr == b[1].attr);
        b[0].rptr = _frrealloc(f, b[0].rptr, (b[0].nrune + b[1].nrune + 1) * sizeof(Rune));
        memcpy(b[0].rptr + b[0].nrune, b[1].rptr, (b[1].nrune + 1) * sizeof(Rune));
	b[0].wid += b[1].wid;
	b[0].nrune += b[1].nrune;
	_frdelbox(f, bn+1, bn+1);
}

int
_frfindbox(Frame *f, int bn, ulong p, ulong q)	/* find box containing q and put q on a box boundary */
{
	Frbox *b;

	for(b = &f->box[bn]; bn<f->nbox && p+NRUNE(b)<=q; bn++, b++)
		p += NRUNE(b);
	if(p != q)
		_frsplitbox(f, bn++, (int)(q-p));
	return bn;
}
