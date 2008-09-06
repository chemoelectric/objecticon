#ifndef _LGLOB_H
#define _LGLOB_H 1

void readglob(struct lfile *lf);
void resolve_locals();
void scanrefs();
void build_fieldtable();
void sort_global_table();

#endif
