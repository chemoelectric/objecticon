#include "icont.h"
#include "tmain.h"
#include "membuff.h"

void mb_init(struct membuff *mb, size_t n, char *name)
{
    mb->name = name;
    mb->init_size = n;
    mb->first = mb->last = mb->curr = 0;
}

void *mb_zalloc(struct membuff *mb, size_t n)
{
    void *t;
    t = mb_alloc(mb, n);
    memset(t, 0, n);
    return t;
}

void *mb_alloc(struct membuff *mb, size_t n)
{
    char *t;
    struct membuff_block *nb;
    int new_size;

    /* Ensure all allocations are word aligned */
    n = WordRound(n);

    while (mb->curr) {
        struct membuff_block *b = mb->curr;
        if (n <= b->size - DiffPtrs(b->free, b->mem)) {
            t = b->free;
            b->free += n;
            return t;
        }
        mb->curr = b->next;
    }

    if (mb->last)
        new_size = 2 * mb->last->size;
    else
        new_size = mb->init_size;

    if (n > new_size)
        quit("Request too big for membuff %s", mb->name);

    nb = Alloc1(struct membuff_block);
    nb->size = new_size;
    nb->mem = t = safe_malloc(new_size);
    nb->free = t + n;
    nb->next = 0;
    if (mb->last)
        mb->last->next = nb;
    else
        mb->first = nb;
    mb->curr = mb->last = nb;

    return t;
}

void mb_clear(struct membuff *mb)
{
    struct membuff_block *t = mb->first;
    while (t) {
        t->free = t->mem;
        t = t->next;
    }
    mb->curr = mb->first;
}

void mb_free(struct membuff *mb)
{
    struct membuff_block *t = mb->first, *t2;
    while (t) {
        free(t->mem);
        t2 = t->next;
        free(t);
        t = t2;
    }
    mb->curr = mb->first = mb->last = 0;
}

void mb_show(struct membuff *mb)
{
    struct membuff_block *t = mb->first;
    fprintf(stderr, "Membuff %p, init_size=%ld curr=%p\n", mb, (long)mb->init_size, mb->curr);
    while (t) {
        fprintf(stderr, "\tBlock %p mem=%p size=%ld free=%ld\n", t, t->mem,
                (long)t->size, (long)(t->size - ((char *)t->free - (char *)t->mem)));
        t = t->next;
    }
}
