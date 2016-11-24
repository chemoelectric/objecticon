#include <u.h>
#include <libc.h>
#include <draw.h>
#include <thread.h>
#include <mouse.h>
#include "frame.h"

#define	CHUNK	16
#define	ROUNDUP(n)	((n+CHUNK)&~(CHUNK-1))

Rune *
_frallocrunestr(Frame *f, unsigned n)
{
	Rune *p;

	p = malloc(ROUNDUP(n)*sizeof(Rune));
	if(p == 0)
		drawerror(f->display, "out of memory");
	return p;
}

void
_frinsure(Frame *f, int bn, unsigned n)
{
	Frbox *b;

	b = &f->box[bn];
	if(b->nrune < 0)
		drawerror(f->display, "_frinsure");
        b->rptr = realloc(b->rptr, (n + 1) * sizeof(Rune));
	if(b->rptr == 0)
		drawerror(f->display, "out of memory");
}
