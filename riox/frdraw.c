#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include "frame.h"

static Rectangle MkRect(int x, int y, int w, int h)
{
    return Rect(x, y, x + w, y + h); 
}

Font *
_frboxfont(Frame *f, Frbox *b)
{
    if (((b->attr & (AttrBold | AttrItalic)) == (AttrBold | AttrItalic)))
        return f->fonts[BOLD_ITALIC_FONT];
    if (b->attr & AttrBold)
        return f->fonts[BOLD_FONT];
    if (b->attr & AttrItalic)
        return f->fonts[ITALIC_FONT];
    return f->font;
}

static
void drawfrbox(Frame *f, Frbox *b, Point pt, int off, int n, Image *text, Image *back)
{
    Image *fg, *bg;
    Font *font;
    Rune *r = b->rptr + off;

    switch (b->attr & AttrFg) {
        case AttrBlackFg: fg = f->cols[ATTR_BLACK]; break;
        case AttrRedFg: fg = f->cols[ATTR_RED] ; break;
        case AttrGreenFg: fg = f->cols[ATTR_GREEN] ; break;
        case AttrYellowFg: fg = f->cols[ATTR_YELLOW] ; break;
        case AttrBlueFg: fg = f->cols[ATTR_BLUE] ; break;
        case AttrMagentaFg: fg = f->cols[ATTR_MAGENTA] ; break;
        case AttrCyanFg: fg = f->cols[ATTR_CYAN] ; break;
        case AttrWhiteFg: fg = f->cols[ATTR_WHITE] ; break;
        default: fg = text; break;
    }

    switch (b->attr & AttrBg) {
        case AttrBlackBg: bg = f->cols[ATTR_BLACK]; break;
        case AttrRedBg: bg = f->cols[ATTR_RED] ; break;
        case AttrGreenBg: bg = f->cols[ATTR_GREEN] ; break;
        case AttrYellowBg: bg = f->cols[ATTR_YELLOW] ; break;
        case AttrBlueBg: bg = f->cols[ATTR_BLUE] ; break;
        case AttrMagentaBg: bg = f->cols[ATTR_MAGENTA] ; break;
        case AttrCyanBg: bg = f->cols[ATTR_CYAN] ; break;
        case AttrWhiteBg: bg = f->cols[ATTR_WHITE] ; break;
        default: bg = back; break;
    }

    if (b->attr & AttrInverse) {
        Image *t;
        t = fg;
        fg = bg;
        bg = t;
    }

    font = _frboxfont(f, b);

    if (!(b->attr & AttrInvisible))
        runestringnbg(f->b, pt, 
                      fg, ZP,
                      font,
                      r, n,
                      bg, ZP);

    if (b->attr & AttrUnderline)
        gendrawop(f->b,
                  MkRect(pt.x, pt.y + font->ascent + 1, runestringnwidth(font, r, n), 1),
                  fg, ZP,
                  0, ZP, 
                  SoverD);
    if (b->attr & AttrCrossed)
        gendrawop(f->b,
                  MkRect(pt.x, pt.y + (2 * font->ascent) / 3, runestringnwidth(font, r, n), 1),
                  fg, ZP,
                  0, ZP, 
                  SoverD);
}


void
_frdrawtext(Frame *f, Point pt, Image *text, Image *back)
{
	Frbox *b;
	int nb;
	static int x;

	for(nb=0,b=f->box; nb<f->nbox; nb++, b++){
		_frcklinewrap(f, &pt, b);
		if(b->nrune >= 0)
                    drawfrbox(f, b, pt, 0, b->nrune, text, back);

		pt.x += b->wid;
	}
}

static int
nbytes(char *s0, int nr)
{
	char *s;
	Rune r;

	s = s0;
	while(--nr >= 0)
		s += chartorune(&r, s);
	return s-s0;
}

void
frdrawsel(Frame *f, Point pt, ulong p0, ulong p1, int issel)
{
	Image *back, *text;

	if(f->ticked)
		frtick(f, frptofchar(f, f->p0), 0);

	if(p0 == p1){
		frtick(f, pt, issel);
		return;
	}

	if(issel){
		back = f->cols[HIGH];
		text = f->cols[HTEXT];
	}else{
		back = f->cols[BACK];
		text = f->cols[TEXT];
	}

	frdrawsel0(f, pt, p0, p1, back, text);
}

Point
frdrawsel0(Frame *f, Point pt, ulong p0, ulong p1, Image *back, Image *text)
{
	Frbox *b;
	int nb, nr, w, x, trim;
	Point qt;
	uint p;
        Rune *rptr;

	p = 0;
	b = f->box;
	trim = 0;
	for(nb=0; nb<f->nbox && p<p1; nb++){
		nr = b->nrune;
		if(nr < 0)
			nr = 1;
		if(p+nr <= p0)
			goto Continue;
		if(p >= p0){
			qt = pt;
			_frcklinewrap(f, &pt, b);
			/* fill in the end of a wrapped line */
			if(pt.y > qt.y)
				draw(f->b, Rect(qt.x, qt.y, f->r.max.x, pt.y), back, nil, qt);
		}
                rptr = b->rptr;
		if(p < p0){	/* beginning of region: advance into box */
                        rptr += (p0-p);
			nr -= (p0-p);
			p = p0;
		}
		trim = 0;
		if(p+nr > p1){	/* end of region: trim box */
			nr -= (p+nr)-p1;
			trim = 1;
		}
		if(b->nrune<0 || nr==b->nrune)
			w = b->wid;
		else
                        w = runestringnwidth(_frboxfont(f, b), rptr, nr);
		x = pt.x+w;
		if(x > f->r.max.x)
			x = f->r.max.x;
		draw(f->b, Rect(pt.x, pt.y, x, pt.y+f->font->height), back, nil, pt);
		if(b->nrune >= 0)
                    drawfrbox(f, b, pt, rptr - b->rptr, nr, text, back);

		pt.x += w;
	    Continue:
		b++;
		p += nr;
	}
	/* if this is end of last plain text box on wrapped line, fill to end of line */
	if(p1>p0 &&  b>f->box && b<f->box+f->nbox && b[-1].nrune>0 && !trim){
		qt = pt;
		_frcklinewrap(f, &pt, b);
		if(pt.y > qt.y)
			draw(f->b, Rect(qt.x, qt.y, f->r.max.x, pt.y), back, nil, qt);
	}
	return pt;
}

void
frredraw(Frame *f)
{
	int ticked;
	Point pt;

	if(f->p0 == f->p1){
		ticked = f->ticked;
		if(ticked)
			frtick(f, frptofchar(f, f->p0), 0);
		frdrawsel0(f, frptofchar(f, 0), 0, f->nchars, f->cols[BACK], f->cols[TEXT]);
		if(ticked)
			frtick(f, frptofchar(f, f->p0), 1);
		return;
	}

	pt = frptofchar(f, 0);
	pt = frdrawsel0(f, pt, 0, f->p0, f->cols[BACK], f->cols[TEXT]);
	pt = frdrawsel0(f, pt, f->p0, f->p1, f->cols[HIGH], f->cols[HTEXT]);
	pt = frdrawsel0(f, pt, f->p1, f->nchars, f->cols[BACK], f->cols[TEXT]);
}

void
frtick(Frame *f, Point pt, int ticked)
{
	Rectangle r;

	if(f->ticked==ticked || f->tick==0 || !ptinrect(pt, f->r))
		return;
	pt.x--;	/* looks best just left of where requested */
	r = Rect(pt.x, pt.y, pt.x+FRTICKW, pt.y+f->font->height);
	/* can go into left border but not right */
	if(r.max.x > f->r.max.x)
		r.max.x = f->r.max.x;
	if(ticked){
		draw(f->tickback, f->tickback->r, f->b, nil, pt);
		draw(f->b, r, f->tick, nil, ZP);
	}else
		draw(f->b, r, f->tickback, nil, ZP);
	f->ticked = ticked;
}

Point
_frdraw(Frame *f, Point pt)
{
	Frbox *b;
	int nb, n;

	for(b=f->box,nb=0; nb<f->nbox; nb++, b++){
		_frcklinewrap0(f, &pt, b);
		if(pt.y == f->r.max.y){
			f->nchars -= _frstrlen(f, nb);
			_frdelbox(f, nb, f->nbox-1);
			break;
		}
		if(b->nrune > 0){
			n = _frcanfit(f, pt, b);
			if(n == 0)
				drawerror(f->display, "_frcanfit==0");
			if(n != b->nrune){
				_frsplitbox(f, nb, n);
				b = &f->box[nb];
			}
			pt.x += b->wid;
		}else{
			if(b->bc == '\n'){
				pt.x = f->r.min.x;
				pt.y+=f->font->height;
			}else
				pt.x += _frnewwid(f, pt, b);
		}
	}
	return pt;
}

int
_frstrlen(Frame *f, int nb)
{
	int n;

	for(n=0; nb<f->nbox; nb++)
		n += NRUNE(&f->box[nb]);
	return n;
}
