#ifndef _LSYM_H
#define _LSYM_H 1

extern int nfields;		/* number of fields (rows) in field table */

struct gentry *putglobal(char *name, int flag, struct lfile *lf, struct loc *pos);
struct gentry *glocate(char *name);
void add_local(struct lfunction *func, char *name, int flags, struct loc *pos);
void add_constant(struct lfunction *func, 
                  int flags, int len, union xval *valp);
struct fentry *flocate(char *name);
struct lclass_field *lookup_method(char *class, char *method);

#endif
