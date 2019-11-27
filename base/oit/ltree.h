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
    struct fentry *ftab_entry;
    struct lnode *child;
    struct lclass_field_ref *ref;       /* Cached lookup for a node where child is a class */
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
    int use_tcase;
    struct lnode *expr;
    struct lnode **selector;
    struct lnode **clause;
    struct lnode *def;
};

struct lnode_global {
    LNODE_SUB
    struct gentry *global;
    struct lentry *local;    /* Null (for an implicit class field ref), 
                              * or corresponding entry in func's locals list */
};

struct lnode_local {
    LNODE_SUB
    struct lentry *local;
};

struct lnode_const {
    LNODE_SUB
    struct centry *con;
};

void loadtrees(void);

/*
 * Allocation funcs.
 */
struct lnode *lnode_0(int op, struct loc *pos);
struct lnode_1 *lnode_1(int op, struct loc *pos, struct lnode *c);
struct lnode_2 *lnode_2(int op, struct loc *pos, struct lnode *c1, struct lnode *c2);
struct lnode_3 *lnode_3(int op, struct loc *pos, struct lnode *c1, struct lnode *c2, struct lnode *c3);
struct lnode_n *lnode_n(int op, struct loc *pos, int x);
struct lnode_field *lnode_field(struct loc *loc, struct lnode *c, char *fname);
struct lnode_invoke *lnode_invoke(int op, struct loc *loc, struct lnode *expr, int x);
struct lnode_apply *lnode_apply(struct loc *loc, struct lnode *expr, struct lnode *args);
struct lnode_keyword *lnode_keyword(struct loc *loc, int num);
struct lnode_local *lnode_local(struct loc *loc, struct lentry *local);
struct lnode_const *lnode_const(struct loc *loc, struct centry *con);
struct lnode_global *lnode_global(struct loc *loc, struct gentry *global, struct lentry *local);
struct lnode_case *lnode_case(int op, struct loc *loc, struct lnode *expr, int x);

/*
 * Visitor funcs.
 */
typedef int (*visitf)(struct lnode *n);
extern struct lfunction *curr_vfunc;
void visitfunc_pre(struct lfunction *f, visitf v);
void visitfunc_post(struct lfunction *f, visitf v);
void visit_pre(visitf v);
void visit_post(visitf v);
void visitnode_pre(struct lnode *n, visitf v);
void visitnode_post(struct lnode *n, visitf v);

void replace_node(struct lnode *old, struct lnode *new);
int get_class_field_ref(struct lnode_field *x, struct lclass **class, struct lclass_field_ref **field);
int check_access(struct lfunction *func, struct lclass_field *f);

#endif
