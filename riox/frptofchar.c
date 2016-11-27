#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include "frame.h"

Point
_frptofcharptb(Frame *f, ulong p, Point pt, int bn)
{
	Frbox *b;
	int l;

	for(b = &f->box[bn]; bn<f->nbox; bn++,b++){
		_frcklinewrap(f, &pt, b);
		if(p < (l=NRUNE(b))){
			if(b->nrune > 0) 
                            pt.x += runestringnwidth(_frboxfont(f,b), b->rptr, p);
			break;
		}
		p -= l;
		_fradvance(f, &pt, b);
	}
	return pt;
}

Point
frptofchar(Frame *f, ulong p)
{
	return _frptofcharptb(f, p, f->r.min, 0);
}

Point
_frptofcharnb(Frame *f, ulong p, int nb)	/* doesn't do final _fradvance to next line */
{
	Point pt;
	int nbox;

	nbox = f->nbox;
	f->nbox = nb;
	pt = _frptofcharptb(f, p, f->r.min, 0);
	f->nbox = nbox;
	return pt;
}

static
Point
_frgrid(Frame *f, Point p)
{
	p.y -= f->r.min.y;
	p.y -= p.y%f->font->height;
	p.y += f->r.min.y;
	if(p.x > f->r.max.x)
		p.x = f->r.max.x;
	return p;
}

ulong
frcharofpt(Frame *f, Point pt)
{
	Point qt;
	int bn;
	Frbox *b;
	ulong p;
	Rune r, *rs;

	pt = _frgrid(f, pt);
	qt = f->r.min;
	for(b=f->box,bn=0,p=0; bn<f->nbox && qt.y<pt.y; bn++,b++){
		_frcklinewrap(f, &qt, b);
		if(qt.y >= pt.y)
			break;
		_fradvance(f, &qt, b);
		p += NRUNE(b);
	}
	for(; bn<f->nbox && qt.x<=pt.x; bn++,b++){
		_frcklinewrap(f, &qt, b);
		if(qt.y > pt.y)
			break;
		if(qt.x+b->wid > pt.x){
			if(b->nrune < 0)
				_fradvance(f, &qt, b);
			else{
                                rs = b->rptr;
				for(;;){
                                        r = *rs++;
                                        if(r == 0)
						drawerror(f->display, "end of string in frcharofpt");
					qt.x += runestringnwidth(_frboxfont(f,b), &r, 1);
					if(qt.x > pt.x)
						break;
					p++;
				}
			}
		}else{
			p += NRUNE(b);
			_fradvance(f, &qt, b);
		}
	}
	return p;
}
