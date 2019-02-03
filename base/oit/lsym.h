#ifndef _LSYM_H
#define _LSYM_H 1

extern int nfields;		/* number of fields (rows) in field table */

struct gentry *putglobal(char *name, int flag, struct lfile *lf, struct loc *pos);
struct gentry *glocate(char *name);
struct lentry *add_local(struct lfunction *func, char *name, int flags, struct loc *pos);
struct centry *add_constant(struct lfunction *func, int flags, char *data, int len);
struct fentry *flocate(char *name);
struct lclass_field *lookup_field(struct lclass *class, char *fname);
struct lclass_field_ref *lookup_implemented_field_ref(struct lclass *class, char *fname);
struct lclass_field *lookup_implemented_field(struct lclass *class, char *fname);


#endif
