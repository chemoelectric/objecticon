#ifndef _IR_H
#define _IR_H 1

#define Ir_Goto         1
#define Ir_Fail         2
#define Ir_EnterInit    3
#define Ir_Mark         4
#define Ir_Unmark       5
#define Ir_Move         6
#define Ir_Op           7
#define Ir_OpClo        8
#define Ir_Deref       10
#define Ir_Resume      11
#define Ir_Invoke      13
#define Ir_KeyOp       14
#define Ir_KeyClo      15
#define Ir_IGoto       16
#define Ir_MoveLabel   17
#define Ir_ScanSwap    18
#define Ir_ScanSave    19
#define Ir_ScanRestore 20
#define Ir_Suspend     21
#define Ir_SysErr      22
#define Ir_MakeList    23
#define Ir_Apply       24
#define Ir_Field       25
#define Ir_Invokef     26
#define Ir_Applyf      27
#define Ir_Create      28
#define Ir_Coret       29
#define Ir_Cofail      31
#define Ir_Limit       32
#define Ir_Return      33
#define Ir_MgOp        34
#define Ir_TCaseInit   35
#define Ir_TCaseInsert 36
#define Ir_TCaseChoose 37
#define Ir_TCaseChoosex 38

struct scan_info {
    struct ir_var *old_subject, *old_pos;
    struct ir_info *next;
};

struct loop_info {
    struct ir_info *scan_stack;   /* Top of scan stack at loop's location */
    int next_chunk;
    int continue_tmploc;
    struct ir_stack *st, *loop_st;
    struct mark_pair *loop_mk;
    struct ir_var *target;
    int bounded, rval;
    struct ir_info *next;
    int has_break, has_next, next_fails_flag;
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

struct mark_pair {
    int no;    /* Mark number in frame */
    int id;    /* Unique id, for pairing mark/unmark during optimisation. */
};

enum ir_vartype { CONST, LOCAL, GLOBAL, TMP, WORD, KNULL, KYES };

struct ir_var {
    int type;
    int index;
    word w;
    int renumbered;
    int tmp_id;     /* For type TMP, a unique id used during optimisation */
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

struct ir_mgop {
    IR_SUB
    struct ir_var *lhs;
    int operation;
    struct ir_var *arg1;
    struct ir_var *arg2;
    int rval;
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
    struct ir_var *lhs;
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
    struct ir_var *lhs;
    int keyword;
    int rval;
    int fail_label;
};

struct ir_invoke {
    IR_SUB
    int clo;
    struct ir_var *lhs;
    struct ir_var *expr;
    int argc;
    struct ir_var **args;
    int rval;
    int fail_label;
};

struct ir_apply {
    IR_SUB
    int clo;
    struct ir_var *lhs;
    struct ir_var *arg1;
    struct ir_var *arg2;
    int rval;
    int fail_label;
};

struct ir_invokef {
    IR_SUB
    int clo;
    struct ir_var *lhs;
    struct ir_var *expr;
    struct fentry *ftab_entry;
    int argc;
    struct ir_var **args;
    int rval;
    int fail_label;
};

struct ir_applyf {
    IR_SUB
    int clo;
    struct ir_var *lhs;
    struct ir_var *arg1;
    struct fentry *ftab_entry;
    struct ir_var *arg2;
    int rval;
    int fail_label;
};

struct ir_field {
    IR_SUB
    struct ir_var *lhs;
    struct ir_var *expr;
    struct fentry *ftab_entry;
};

struct ir_makelist {
    IR_SUB
    struct ir_var *lhs;
    int argc;
    struct ir_var **args;
};

struct ir_mark {
    IR_SUB
    int no;     /* Mark number in frame */
    int id;     /* Unique id for pairing with unmark */
};

struct ir_unmark {
    IR_SUB
    int no;     /* Mark number in frame */
    int id;     /* Unique id for pairing with mark */
};

struct ir_suspend {
    IR_SUB
    struct ir_var *val;
};

struct ir_return {
    IR_SUB
    struct ir_var *val;
};

struct ir_move {
    IR_SUB
    struct ir_var *lhs;
    struct ir_var *rhs;
};

struct ir_deref {
    IR_SUB
    struct ir_var *lhs;
    struct ir_var *rhs;
};

struct ir_resume {
    IR_SUB
    int clo;
};

struct ir_create {
    IR_SUB
    struct ir_var *lhs;
    int start_label;
};

struct ir_coret {
    IR_SUB
    struct ir_var *value;
};

struct ir_limit {
    IR_SUB
    struct ir_var *limit;
};

struct ir_tcaseinit {
    IR_SUB
    int def;
    int no;         /* Sequence number used during code generation */
    int id;         /* Unique id used for -I output only */
};

struct ir_tcaseinsert {
    IR_SUB
    struct ir_tcaseinit *tci;
    struct ir_var *val;
    int entry;
};

struct ir_tcasechoosex {
    IR_SUB
    struct ir_tcaseinit *tci;
    struct ir_var *val;
    int labno;
    int tblc;
    int *tbl;
};

struct ir_tcasechoose {
    IR_SUB
    struct ir_tcaseinit *tci;
    struct ir_var *val;
    int tblc;
    int *tbl;
};

struct chunk {
    int id;
    char *desc;  /* description, for debugging */
    int line;    /* source line, for debugging */
    int n_inst;
    int circle;  /* goto circle check marker */
    int seen;    /* no. of references, used during optimization */
    int joined_above;   /* is the chunk joined to the chunk above (does control flow from it) */
    int joined_below;   /* is the chunk joined to the one below (does control flow to it) */
    word pc;     /* pc of chunk */
    word refs;   /* Chain of usage (gotos etc) in code */
    struct ir *inst[1];
};

extern struct chunk **chunks;
extern int hi_chunk;
extern struct lfunction *curr_ir_func;
extern int n_clo, n_tmp, n_lab, n_mark;

void generate_ir(void);
void dump_ir(void);
int is_readable_global(struct gentry *ge);
int is_self(struct lentry *le);

#endif
