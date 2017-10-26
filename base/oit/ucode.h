#ifndef _UCODE_H
#define _UCODE_H 1

/*
 * Output routines for the opcode and the parameters.
 */

/* Output the opcode */
void uout_op(int opcode);

/* 16 bits signed */
void uout_16(int n);

/* 32 bits signed */
void uout_32(word n);

/* null-terminated string */
void uout_str(char *s);

/* len bytes of binary data; len <= 0xff */
void uout_sbin(int len, char *s);

/* len bytes of binary data; len 32 bit int */
void uout_lbin(int len, char *s);

/*
 * The input routines follow a similar pattern.
 */

/* Get the next op, returning null on EOF */
struct ucode_op *uin_op(void);

/* Get the next op, but quit on EOF */
struct ucode_op *uin_expectop(void);

/* Get a word */
word uin_32(void);

/* Get and intern a null-terminated string */
char *uin_str(void);

/* Get and intern a null-terminated string, prefix with package plus a . */
char *uin_fqid(char *package);

/* Get and intern binary data, storing the length in n */
char *uin_sbin(int *n);

/* Get and intern binary data, storing the length in n */
char *uin_lbin(int *n);

/* Get a 16 bit signed short */
int uin_16(void);

/* Given the last opcode just read, skip over the instruction's parameters */
void uin_skip(int opcode);

int     udis(int argc, char **argv);

/*
 * Definition of a particular instruction.
 */
struct ucode_op {
    int opcode;
    char *name;          /* Printable name */
    int param_type[2];   /* The types of the parameters */
    char *fmt;           /* Format for disassembly */
};

extern struct ucode_op ucode_op_table[];

/*
 * The parameter types.
 */
#define TYPE_NONE      0   /* no params */
#define TYPE_32        1   /* signed 32 bits */
#define TYPE_16        2   /* signed 16 bits */
#define TYPE_STR       3   /* null terminated string */
#define TYPE_SBIN      4   /* binary data (8 bit length + bytes) */
#define TYPE_LBIN      5   /* binary data (32 bit length + bytes) */


/*
 * Ucode opcodes.
 */


/*
 * Binary ops
 */
#define Uop_Asgn        100
#define Uop_Power       101
#define Uop_Cat         102
#define Uop_Diff        103
#define Uop_Eqv         104
#define Uop_Inter       105
#define Uop_Subsc       106
#define Uop_Lconcat     107
#define Uop_Lexeq       108
#define Uop_Lexge       109
#define Uop_Lexgt       110
#define Uop_Lexle       111
#define Uop_Lexlt       112
#define Uop_Lexne       113
#define Uop_Minus       114
#define Uop_Mod         115
#define Uop_Neqv        116
#define Uop_Numeq       117
#define Uop_Numge       118
#define Uop_Numgt       119
#define Uop_Numle       120
#define Uop_Numlt       121
#define Uop_Numne       122
#define Uop_Plus        123
#define Uop_Rasgn       124
#define Uop_Rswap       125
#define Uop_Div         126
#define Uop_Mult        127
#define Uop_Swap        128
#define Uop_Union       129

/*
 * Augmented ops
 */
#define Uop_Augpower    130
#define Uop_Augcat      131
#define Uop_Augdiff     132
#define Uop_Augeqv      133
#define Uop_Auginter    134
#define Uop_Auglconcat  135
#define Uop_Auglexeq    136
#define Uop_Auglexge    137
#define Uop_Auglexgt    138
#define Uop_Auglexle    139
#define Uop_Auglexlt    140
#define Uop_Auglexne    141
#define Uop_Augminus    142
#define Uop_Augmod      143
#define Uop_Augneqv     144
#define Uop_Augnumeq    145
#define Uop_Augnumge    146
#define Uop_Augnumgt    147
#define Uop_Augnumle    148
#define Uop_Augnumlt    149
#define Uop_Augnumne    150
#define Uop_Augplus     151
#define Uop_Augdiv      152
#define Uop_Augmult     153
#define Uop_Augunion    154
#define Uop_Augapply    197

#define Uop_PkRecord	155
#define Uop_PkProcdecl	156
#define Uop_PkClass     157
#define Uop_PkGlobal    158
#define Uop_PkRdGlobal  159

/*
 * Unary ops
 */
#define Uop_Value	160
#define Uop_Nonnull	161
#define Uop_Bang	162
#define Uop_Refresh	163
#define Uop_Number	164
#define Uop_Compl	165
#define Uop_Neg		166
#define Uop_Tabmat	167
#define Uop_Size	168
#define Uop_Random	169
#define Uop_Null	170

#define Uop_Case        171
#define Uop_Casedef     172
#define Uop_Keyword     173
#define Uop_Limit       174
#define Uop_List        175
#define Uop_Next        176
#define Uop_Break       177
#define Uop_Returnexpr  178
#define Uop_Suspendexpr 179
#define Uop_Breakexpr   180
#define Uop_Fail        181
#define Uop_Return      182
#define Uop_Create      183
#define Uop_To          184
#define Uop_Toby        185
#define Uop_Sect        186
#define Uop_Sectm       187
#define Uop_Sectp       188
#define Uop_Scan        189
#define Uop_Augscan     190
#define Uop_Not         191
#define Uop_Real        192
#define Uop_Global      193
#define Uop_Local       194
#define Uop_Var         196
#define Uop_Field       200
#define Uop_Const       201
#define Uop_Declend	202
#define Uop_End		203
#define Uop_Ldata	204
#define Uop_Version	205
#define Uop_Sdata	206
#define Uop_Filen	207
#define Uop_Package     208
#define Uop_Import      209
#define Uop_Classfield  210
#define Uop_Recordfield 211
#define Uop_Procdecl	212
#define Uop_Importsym   214
#define Uop_Record	215
#define Uop_Impl	216
#define Uop_Error	217
#define Uop_Invocable	220
#define Uop_Class       221
#define Uop_Super       222
#define Uop_Proc        223
#define Uop_Start       224
#define Uop_Method      226
#define Uop_Empty       228
#define Uop_Slist       229
#define Uop_Alt         232
#define Uop_Conj        233
#define Uop_Augconj     234
#define Uop_If          235
#define Uop_Ifelse      236
#define Uop_Repeat      237
#define Uop_While       238
#define Uop_Suspend     239
#define Uop_Until       240
#define Uop_Every       241
#define Uop_Line  	242
#define Uop_Whiledo     243
#define Uop_Suspenddo   244
#define Uop_Untildo     245
#define Uop_Everydo     246
#define Uop_Uactivate   247
#define Uop_Bactivate   248
#define Uop_Augactivate 249
#define Uop_Rptalt      250

#define Uop_Invoke      251
#define Uop_CoInvoke    252
#define Uop_Mutual      253
#define Uop_Apply       254

#endif
