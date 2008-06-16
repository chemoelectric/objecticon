#ifndef _LGLOB_H
#define _LGLOB_H 1

extern int fieldtable_cols;	/* number of columns in fieldtable (= #records + #classes) */

void readglob(struct lfile *lf);
void resolve_locals();
void scanrefs();
void build_fieldtable();
void sort_global_table();

#endif
