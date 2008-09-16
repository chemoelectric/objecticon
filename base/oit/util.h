#ifndef _UTIL_H
#define _UTIL_H 1

void *expand_table(void * table,      /* table to be realloc()ed */
               void * tblfree,    /* reference to table free pointer if there is one */
               unsigned int *size, /* size of table */
               int unit_size,      /* number of bytes in a unit of the table */
               int min_units,      /* the minimum number of units that must be allocated. */
               char *tbl_name);     /* name of the table */

#endif
