#ifndef _IR_H
#define _IR_H 1

#define Ir_Goto      1
#define Ir_Fail      2
#define Ir_EnterInit 3
#define Ir_Mark      4
#define Ir_Unmark    5
#define Ir_Move      6
#define Ir_BinOp     7
#define Ir_BinClo    8
#define Ir_UnOp      9
#define Ir_UnClo     10
#define Ir_ResumeValue  11
#define Ir_Deref     12
#define Ir_Invoke    13
#define Ir_KeyOp     14
#define Ir_KeyClo    15
#define Ir_IGoto     16
#define Ir_MoveLabel 17

struct ir_info {
    char *desc;
    int start, success, resume, failure;
    struct lnode *node;
    int uses_stack;
};

struct ir_stack {
    int clo, tmp, lab, mark;
};


enum ir_vartype { CONST, LOCAL, GLOBAL, TMP, CLOSURE, KEYWORD };

struct ir_var {
    int type;
    int index;
    struct centry *con;
    struct lentry *local;
    struct gentry *global;
};


#define IR_SUB int op; \
               struct lnode *node;

struct ir {
    IR_SUB
};

struct ir_enterinit {
    IR_SUB
    int dest;
};

struct ir_goto {
    IR_SUB
    int dest;
};

struct ir_igoto {
    IR_SUB
    int no;
};

struct ir_movelabel {
    IR_SUB
    int lab;
    int destno;
};

struct ir_binop {
    IR_SUB
    struct ir_var *lhs;
    int operation;
    struct ir_var *arg1;
    struct ir_var *arg2;
    int rval;
    int fail_label;
};

struct ir_keyop {
    IR_SUB
    struct ir_var *lhs;
    int keyword;
    int rval;
    int fail_label;
};

struct ir_binclo {
    IR_SUB
    int clo;
    int operation;
    struct ir_var *arg1;
    struct ir_var *arg2;
    int rval;
    int fail_label;
};

struct ir_keyclo {
    IR_SUB
    int clo;
    int keyword;
    int rval;
    int fail_label;
};

struct ir_invoke {
    IR_SUB
    int clo;
    struct ir_var *expr;
    int argc;
    struct ir_var **args;
    int fail_label;
};

struct ir_unop {
    IR_SUB
    struct ir_var *lhs;
    int operation;
    struct ir_var *arg;
    int rval;
    int fail_label;
};

struct ir_unclo {
    IR_SUB
    int clo;
    int operation;
    struct ir_var *arg;
    int rval;
    int fail_label;
};

struct ir_mark {
    IR_SUB
    int no;
};

struct ir_unmark {
    IR_SUB
    int no;
};

struct ir_move {
    IR_SUB
    struct ir_var *lhs;
    struct ir_var *rhs;
    int rval;
};

struct ir_deref {
    IR_SUB
    struct ir_var *src;
    struct ir_var *dest;
    int rval;
};

struct ir_resumevalue {
    IR_SUB
    struct ir_var *lhs;
    int clo;
    int fail_label;
};

struct chunk {
    int id;
    int n_inst;
    int circle;
    int seen;
    word pc;     /* pc of chunk */
    word refs;   /* Chain of usage (gotos etc) in code */
    struct ir *inst[1];
};

extern struct chunk **chunks;
extern int hi_chunk;
extern int ir_start;
extern struct lfunction *curr_ir_func;
extern int n_clo, n_tmp, n_lab, n_mark;

void generate_ir();
void dump_ir();

#endif
