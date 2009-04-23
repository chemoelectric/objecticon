#ifndef _LTREE_H
#define _LTREE_H 1

#define LNODE_SUB int op; \
                  struct lnode *parent; \
                  struct loc loc;

struct lnode {
    LNODE_SUB
};

struct lnode_n {
    LNODE_SUB
    int n;
    struct lnode **child;
};

struct lnode_1 {
    LNODE_SUB
    struct lnode *child;
};

struct lnode_2 {
    LNODE_SUB
    struct lnode *child1, *child2;
};

struct lnode_3 {
    LNODE_SUB
    struct lnode *child1, *child2, *child3;
};

struct lnode_field {
    LNODE_SUB
    char *fname;
    struct lnode *child;
};

struct lnode_invoke {
    LNODE_SUB
    int n;
    struct lnode *expr;
    struct lnode **child;
};

struct lnode_apply {
    LNODE_SUB
    struct lnode *expr;
    struct lnode *args;
};

struct lnode_keyword {
    LNODE_SUB
    int num;
};

struct lnode_case {
    LNODE_SUB
    int n;
    struct lnode *expr;
    struct lnode **selector;
    struct lnode **clause;
    struct lnode *def;
};

struct lnode_global {
    LNODE_SUB
    struct gentry *global;
};

struct lnode_local {
    LNODE_SUB
    struct lentry *local;
};

struct lnode_con {
    LNODE_SUB
    struct centry *con;
};

void loadtrees();

#endif
