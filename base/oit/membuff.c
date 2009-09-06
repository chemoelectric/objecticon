#include "icont.h"
#include "tmain.h"
#include "membuff.h"

void mb_init(struct membuff *mb, size_t n, char *name)
{
    mb->name = name;
    mb->init_size = n;
    mb->first = mb->last = mb->curr = 0;
}

void *mb_alloc(struct membuff *mb, size_t n)
{
    void *t;
    struct membuff_block *nb;
    int new_size;

    while (mb->curr) {
        struct membuff_block *b = mb->curr;
        if (n <= b->size - ((char *)b->free - (char *)b->mem)) {
            t = b->free;
            b->free = (char *)b->free + n;
            return t;
        }
        mb->curr = b->next;
    }

    if (mb->last)
        new_size = 2 * mb->last->size;
    else
        new_size = mb->init_size;

    if (n > new_size)
        quitf("Request too big for membuff %s", mb->name);

    nb = Alloc(struct membuff_block);
    nb->size = new_size;
    t = nb->mem = safe_alloc(new_size);
    nb->free = (char *)t + n;
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
        memset(t->mem, 0, t->size);
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
