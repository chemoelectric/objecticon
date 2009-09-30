#ifndef _IR_H
#define _IR_H 1

#define Ir_Goto      1
#define Ir_Fail      2
#define Ir_EnterInit 3
#define Ir_Mark      4
#define Ir_Unmark    5
#define Ir_Move      6
#define Ir_Op        7
#define Ir_OpClo     8
#define Ir_Resume    11
#define Ir_Deref     12
#define Ir_Invoke    13
#define Ir_KeyOp     14
#define Ir_KeyClo    15
#define Ir_IGoto     16
#define Ir_MoveLabel 17
#define Ir_ScanSwap  18
#define Ir_ScanSave  19
#define Ir_ScanRestore 20
#define Ir_Succeed   21
#define Ir_SysErr    22
#define Ir_MakeList  23
#define Ir_Apply     24
#define Ir_Field     25
#define Ir_Invokef   26
#define Ir_Applyf    27

struct scan_info {
    struct ir_var *old_subject, *old_pos;
    struct ir_info *next;
};

struct loop_info {
    struct ir_info *scan_stack;   /* Top of scan stack at loop's location */
    int next_chunk;
    int continue_tmploc;
    struct ir_stack *st, *loop_st;
    int loop_mk;
    struct ir_var *target;
    int bounded, rval;
    struct ir_info *next;
    int has_break;
};

struct ir_info {
    char *desc;
    int start, success, resume, failure;
    struct lnode *node;
    int uses_stack;
    struct scan_info *scan;
    struct loop_info *loop;
};

struct ir_stack {
    int clo, tmp, lab, mark;
};


enum ir_vartype { CONST, LOCAL, GLOBAL, TMP, CLOSURE, WORD, KNULL };

struct ir_var {
    int type;
    int index;
    word w;
    int renumbered;
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

struct ir_scanswap {
    IR_SUB
    struct ir_var *tmp_subject;
    struct ir_var *tmp_pos;
};

struct ir_scansave {
    IR_SUB
    struct ir_var *new_subject;
    struct ir_var *tmp_subject;
    struct ir_var *tmp_pos;
};

struct ir_scanrestore {
    IR_SUB
    struct ir_var *tmp_subject;
    struct ir_var *tmp_pos;
};

struct ir_op {
    IR_SUB
    struct ir_var *lhs;
    int operation;
    struct ir_var *arg1;
    struct ir_var *arg2;
    struct ir_var *arg3;
    int rval;
    int fail_label;
};

struct ir_opclo {
    IR_SUB
    int clo;
    int operation;
    struct ir_var *arg1;
    struct ir_var *arg2;
    struct ir_var *arg3;
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

struct ir_apply {
    IR_SUB
    int clo;
    struct ir_var *arg1;
    struct ir_var *arg2;
    int fail_label;
};

struct ir_invokef {
    IR_SUB
    int clo;
    struct ir_var *expr;
    char *fname;
    int argc;
    struct ir_var **args;
    int fail_label;
};

struct ir_applyf {
    IR_SUB
    int clo;
    struct ir_var *arg1;
    char *fname;
    struct ir_var *arg2;
    int fail_label;
};

struct ir_field {
    IR_SUB
    struct ir_var *lhs;
    struct ir_var *expr;
    char *fname;
    int fail_label;
};

struct ir_makelist {
    IR_SUB
    struct ir_var *lhs;
    int argc;
    struct ir_var **args;
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

struct ir_succeed {
    IR_SUB
    struct ir_var *val;
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

struct ir_resume {
    IR_SUB
    int clo;
    int fail_label;
};

struct chunk {
    int id;
    char *desc;  /* description, for debugging */
    int line;    /* source line, for debugging */
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
