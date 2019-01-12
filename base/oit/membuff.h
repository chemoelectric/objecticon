#ifndef _TMEMBUFF_H
#define _TMEMBUFF_H 1

struct membuff_block {
    void *mem, *free;
    size_t size;
    struct membuff_block *next;
};

struct membuff {
    char *name;
    size_t init_size;
    struct membuff_block *first, *last, *curr;
};

void mb_init(struct membuff *mb, size_t n, char *name);
void *mb_alloc(struct membuff *mb, size_t n);
void mb_clear(struct membuff *mb);
void mb_free(struct membuff *mb);
void mb_show(struct membuff *mb);

#endif
