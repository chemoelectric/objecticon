#ifndef NATIVE_UTILS_H
#define NATIVE_UTILS_H

#include "rt.h"

struct descrip create_list(int n, dptr d);
struct descrip create_empty_list();
struct descrip create_string(char *s);
struct descrip create_string2(char *s, int len);

#endif
