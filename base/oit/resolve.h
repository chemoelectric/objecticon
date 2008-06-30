#ifndef _RESOLVE_H
#define _RESOLVE_H 1

void resolve_local(struct lfunction *func, struct lentry *lp);
void resolve_supers();
void compute_inheritance();
void resolve_invocables();

#define is_absolute(s) (index(s, '.'))

#endif
