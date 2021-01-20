#ifndef _LMEM_H
#define _LMEM_H 1

/*
 * Symbol table region pointers.
 */

/* files to link */
extern struct lfile *lfiles, *lfiles_last;   

extern struct fentry *lffirst;	/* first field table entry */
extern struct fentry *lflast;	/* last field table entry */
extern struct gentry *lgfirst;	/* first global table entry */
extern struct gentry *lglast;	/* last global table entry */

extern struct lclass *lclasses, *lclass_last;
extern struct lrecord *lrecords, *lrecord_last;

extern struct linvocable *linvocables,
                    *last_linvocable; /* invocables in link stage */

void linit(void);
void dumplfiles(void);
void paramlink(char *name);
void alsoimport(char *package, struct lfile *lf, struct loc *pos);
void addinvk(char *name, struct lfile *lf, struct loc *pos);
void lmfree(void);
void add_super(struct lclass *x, char *name, struct loc *pos);
void add_field(struct lclass *x, char *name, int flag, struct loc *pos);
void add_method(struct lfile *lf, struct lclass *x, char *name, int flag, struct loc *pos);
void add_fimport(struct lfile *lf, char *package, int mode, struct loc *pos);
struct fimport *lookup_fimport(struct lfile *lf, char *package);
void add_fimport_symbol(struct lfile *lf, char *symbol, struct loc *pos);
struct fimport_symbol *lookup_fimport_symbol(struct fimport *p, char *symbol);
void add_record_field(struct lrecord *lr, char *name, struct loc *pos);

#endif
