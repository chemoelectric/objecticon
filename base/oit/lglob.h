#ifndef _LGLOB_H
#define _LGLOB_H 1

int get_package_id(char *s);
void readglob(struct lfile *lf);
void resolve_locals(void);
void scanrefs(void);
void scanrefs2(void);
void build_fieldtable(void);
void sort_global_table(void);
void resolve_native_methods(void);

#endif
