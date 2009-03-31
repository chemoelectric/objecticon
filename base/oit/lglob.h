#ifndef _LGLOB_H
#define _LGLOB_H 1

int get_package_id(char *s);
void readglob(struct lfile *lf);
void resolve_locals();
void scanrefs();
void build_fieldtable();
void sort_global_table();
void resolve_native_methods();
double parse_real(char *data);
long parse_int(char *data);

#endif
