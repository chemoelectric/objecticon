/*
 * alloc.c -- allocation routines which exit on out-of-memory
 */

#include "../h/gsupport.h"


/*
 * safe_calloc - allocate and zero m*n bytes
 */
void *safe_calloc(size_t m, size_t n)
{
    void *a = calloc(m, n);
    if (!a && (m * n > 0)) {
        fprintf(stderr, "safe_calloc(%lu, %lu): out of memory\n", (unsigned long)m, (unsigned long)n);
        exit(EXIT_FAILURE);
    }
    return a;
}

/*
 * safe_alloc - allocate and zero n bytes
 */
void *safe_alloc(size_t size)
{
    void *a = calloc(size, 1);
    if (!a && size > 0) {
        fprintf(stderr, "safe_alloc(%lu): out of memory\n", (unsigned long)size);
        exit(EXIT_FAILURE);
    }
    return a;
}

/*
 * safe_realloc - reallocate ptr to size bytes.
 */
void *safe_realloc(void *ptr, size_t size)
{
    void *a = realloc(ptr, size);
    if (!a && size > 0) {
        fprintf(stderr, "safe_realloc(%lu): out of memory\n", (unsigned long)size);
        exit(EXIT_FAILURE);
    }
    return a;
}

