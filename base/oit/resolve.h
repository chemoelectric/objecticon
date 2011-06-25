#ifndef _RESOLVE_H
#define _RESOLVE_H 1

void resolve_local(struct lfunction *func, struct lentry *lp);
void resolve_supers(void);
void compute_inheritance(void);
void resolve_invocables(void);
void add_functions();

#endif
