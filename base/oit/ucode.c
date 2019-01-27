#include "link.h"
#include "ucode.h"
#include "lmem.h"

#define INVALID { 0, 0, {0,0}, 0 }

struct ucode_op ucode_op_table[] = {
    /*   0 */         INVALID,                                    
    /*   1 */         INVALID,
    /*   2 */         INVALID,
    /*   3 */         INVALID,
    /*   4 */         INVALID,
    /*   5 */         INVALID,
    /*   6 */         INVALID,
    /*   7 */         INVALID,
    /*   8 */         INVALID,
    /*   9 */         INVALID,
    /*  10 */         { Uop_Asgn1, "asgn1", {0,0}, "\t%-12s" },
    /*  11 */         { Uop_Swap1, "swap1", {0,0}, "\t%-12s" },
    /*  12 */         INVALID,
    /*  13 */         INVALID,
    /*  14 */         INVALID,
    /*  15 */         INVALID,
    /*  16 */         INVALID,
    /*  17 */         INVALID,
    /*  18 */         INVALID,
    /*  19 */         INVALID,
    /*  20 */         INVALID,
    /*  21 */         INVALID,
    /*  22 */         INVALID,
    /*  23 */         INVALID,
    /*  24 */         INVALID,
    /*  25 */         INVALID,
    /*  26 */         INVALID,
    /*  27 */         INVALID,
    /*  28 */         INVALID,
    /*  29 */         INVALID,
    /*  30 */         INVALID,
    /*  31 */         INVALID,
    /*  32 */         INVALID,
    /*  33 */         INVALID,
    /*  34 */         INVALID,
    /*  35 */         INVALID,
    /*  36 */         INVALID,
    /*  37 */         INVALID,
    /*  38 */         INVALID,
    /*  39 */         INVALID,
    /*  40 */         INVALID,
    /*  41 */         INVALID,
    /*  42 */         INVALID,
    /*  43 */         INVALID,
    /*  44 */         INVALID,
    /*  45 */         INVALID,
    /*  46 */         INVALID,
    /*  47 */         INVALID,
    /*  48 */         INVALID,
    /*  49 */         INVALID,
    /*  50 */         INVALID,
    /*  51 */         INVALID,
    /*  52 */         INVALID,
    /*  53 */         INVALID,
    /*  54 */         INVALID,
    /*  55 */         INVALID,
    /*  56 */         INVALID,
    /*  57 */         INVALID,
    /*  58 */         INVALID,
    /*  59 */         INVALID,
    /*  60 */         INVALID,
    /*  61 */         INVALID,
    /*  62 */         INVALID,
    /*  63 */         INVALID,
    /*  64 */         INVALID,
    /*  65 */         INVALID,
    /*  66 */         INVALID,
    /*  67 */         INVALID,
    /*  68 */         INVALID,
    /*  69 */         INVALID,
    /*  70 */         INVALID,
    /*  71 */         INVALID,
    /*  72 */         INVALID,
    /*  73 */         INVALID,
    /*  74 */         INVALID,
    /*  75 */         INVALID,
    /*  76 */         INVALID,
    /*  77 */         INVALID,
    /*  78 */         INVALID,
    /*  79 */         INVALID,
    /*  80 */         INVALID,
    /*  81 */         INVALID,
    /*  82 */         INVALID,
    /*  83 */         INVALID,
    /*  84 */         INVALID,
    /*  85 */         INVALID,
    /*  86 */         INVALID,
    /*  87 */         INVALID,
    /*  88 */         INVALID,
    /*  89 */         INVALID,
    /*  90 */         INVALID,
    /*  91 */         INVALID,
    /*  92 */         INVALID,
    /*  93 */         INVALID,
    /*  94 */         INVALID,                                    
    /*  95 */         INVALID,                                    
    /*  96 */         INVALID,                                    
    /*  97 */         INVALID,                                    
    /*  98 */         INVALID,
    /*  99 */         INVALID,                                    
    /* 100 */         { Uop_Asgn, "asgn", {0,0}, "\t%-12s" },
    /* 101 */         { Uop_Power, "power", {0,0}, "\t%-12s" },
    /* 102 */         { Uop_Cat, "cat", {0,0}, "\t%-12s" },
    /* 103 */         { Uop_Diff, "diff", {0,0}, "\t%-12s" },
    /* 104 */         { Uop_Eqv, "eqv", {0,0}, "\t%-12s" },
    /* 105 */         { Uop_Inter, "inter", {0,0}, "\t%-12s" },
    /* 106 */         { Uop_Subsc, "subsc", { TYPE_16,0 }, "\t%-12s %d" },
    /* 107 */         { Uop_Lconcat, "lconcat", {0,0}, "\t%-12s" },
    /* 108 */         { Uop_Lexeq, "lexeq", {0,0}, "\t%-12s" },
    /* 109 */         { Uop_Lexge, "lexge", {0,0}, "\t%-12s" },
    /* 110 */         { Uop_Lexgt, "lexgt", {0,0}, "\t%-12s" },
    /* 111 */         { Uop_Lexle, "lexle", {0,0}, "\t%-12s" },
    /* 112 */         { Uop_Lexlt, "lexlt", {0,0}, "\t%-12s" },
    /* 113 */         { Uop_Lexne, "lexne", {0,0}, "\t%-12s" },
    /* 114 */         { Uop_Minus, "minus", {0,0}, "\t%-12s" },
    /* 115 */         { Uop_Mod, "mod", {0,0}, "\t%-12s" },
    /* 116 */         { Uop_Neqv, "neqv", {0,0}, "\t%-12s" },
    /* 117 */         { Uop_Numeq, "numeq", {0,0}, "\t%-12s" },
    /* 118 */         { Uop_Numge, "numge", {0,0}, "\t%-12s" },
    /* 119 */         { Uop_Numgt, "numgt", {0,0}, "\t%-12s" },
    /* 120 */         { Uop_Numle, "numle", {0,0}, "\t%-12s" },
    /* 121 */         { Uop_Numlt, "numlt", {0,0}, "\t%-12s" },
    /* 122 */         { Uop_Numne, "numne", {0,0}, "\t%-12s" },
    /* 123 */         { Uop_Plus, "plus", {0,0}, "\t%-12s" },
    /* 124 */         { Uop_Rasgn, "rasgn", {0,0}, "\t%-12s" },
    /* 125 */         { Uop_Rswap, "rswap", {0,0}, "\t%-12s" },
    /* 126 */         { Uop_Div, "div", {0,0}, "\t%-12s" },
    /* 127 */         { Uop_Mult, "mult", {0,0}, "\t%-12s" },
    /* 128 */         { Uop_Swap, "swap", {0,0}, "\t%-12s" },
    /* 129 */         { Uop_Union, "union", {0,0}, "\t%-12s" },
    /* 130 */         { Uop_Augpower, "augpower", {0,0}, "\t%-12s" },
    /* 131 */         { Uop_Augcat, "augcat", {0,0}, "\t%-12s" },
    /* 132 */         { Uop_Augdiff, "augdiff", {0,0}, "\t%-12s" },
    /* 133 */         { Uop_Augeqv, "augeqv", {0,0}, "\t%-12s" },
    /* 134 */         { Uop_Auginter, "auginter", {0,0}, "\t%-12s" },
    /* 135 */         { Uop_Auglconcat, "auglconcat", {0,0}, "\t%-12s" },
    /* 136 */         { Uop_Auglexeq, "auglexeq", {0,0}, "\t%-12s" },
    /* 137 */         { Uop_Auglexge, "auglexge", {0,0}, "\t%-12s" },
    /* 138 */         { Uop_Auglexgt, "auglexgt", {0,0}, "\t%-12s" },
    /* 139 */         { Uop_Auglexle, "auglexle", {0,0}, "\t%-12s" },
    /* 140 */         { Uop_Auglexlt, "auglexlt", {0,0}, "\t%-12s" },
    /* 141 */         { Uop_Auglexne, "auglexne", {0,0}, "\t%-12s" },
    /* 142 */         { Uop_Augminus, "augminus", {0,0}, "\t%-12s" },
    /* 143 */         { Uop_Augmod, "augmod", {0,0}, "\t%-12s" },
    /* 144 */         { Uop_Augneqv, "augneqv", {0,0}, "\t%-12s" },
    /* 145 */         { Uop_Augnumeq, "augnumeq", {0,0}, "\t%-12s" },
    /* 146 */         { Uop_Augnumge, "augnumge", {0,0}, "\t%-12s" },
    /* 147 */         { Uop_Augnumgt, "augnumgt", {0,0}, "\t%-12s" },
    /* 148 */         { Uop_Augnumle, "augnumle", {0,0}, "\t%-12s" },
    /* 149 */         { Uop_Augnumlt, "augnumlt", {0,0}, "\t%-12s" },
    /* 150 */         { Uop_Augnumne, "augnumne", {0,0}, "\t%-12s" },
    /* 151 */         { Uop_Augplus, "augplus", {0,0}, "\t%-12s" },
    /* 152 */         { Uop_Augdiv, "augdiv", {0,0}, "\t%-12s" },
    /* 153 */         { Uop_Augmult, "augmult", {0,0}, "\t%-12s" },
    /* 154 */         { Uop_Augunion, "augunion", {0,0}, "\t%-12s" },
    /* 155 */         { Uop_PkRecord, "pkrecord", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 156 */         { Uop_PkProcdecl, "pkprocdecl", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 157 */         { Uop_PkClass, "pkclass", { TYPE_32,TYPE_STR }, "\t%-12s %08o %s" }, 
    /* 158 */         { Uop_PkGlobal, "pkglobal", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 159 */         { Uop_PkRdGlobal, "pkrdglobal", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 160 */         { Uop_Value, "value", {0,0}, "\t%-12s" },
    /* 161 */         { Uop_Nonnull, "nonnull", {0,0}, "\t%-12s" },
    /* 162 */         { Uop_Bang, "bang", {0,0}, "\t%-12s" },
    /* 163 */         { Uop_Refresh, "refresh", {0,0}, "\t%-12s" },
    /* 164 */         { Uop_Number, "number", {0,0}, "\t%-12s" },
    /* 165 */         { Uop_Compl, "compl", {0,0}, "\t%-12s" },
    /* 166 */         { Uop_Neg, "neg", {0,0}, "\t%-12s" },
    /* 167 */         { Uop_Tabmat, "tabmat", {0,0}, "\t%-12s" },
    /* 168 */         { Uop_Size, "size", {0,0}, "\t%-12s" },
    /* 169 */         { Uop_Random, "random", {0,0}, "\t%-12s" },
    /* 170 */         { Uop_Null, "null", {0,0}, "\t%-12s" },
    /* 171 */         { Uop_Case, "case", { TYPE_16,0 }, "\t%-12s %d" },
    /* 172 */         { Uop_Casedef, "casedef", { TYPE_16,0 }, "\t%-12s %d" },
    /* 173 */         { Uop_Keyword, "keyword", { TYPE_16,0 }, "\t%-12s %d" },
    /* 174 */         { Uop_Limit, "limit", {0,0}, "\t%-12s" },                               
    /* 175 */         { Uop_List, "list", { TYPE_16,0 }, "\t%-12s %d" },
    /* 176 */         { Uop_Next, "next", {0,0}, "\t%-12s" },                      
    /* 177 */         { Uop_Break, "break", {0,0}, "\t%-12s" },                      
    /* 178 */         { Uop_Returnexpr, "returnexpr", {0,0}, "\t%-12s" }, 
    /* 179 */         { Uop_Suspendexpr, "suspendexpr", { 0,0 }, "\t%-12s" },
    /* 180 */         { Uop_Breakexpr, "breakexpr", {0,0}, "\t%-12s" },
    /* 181 */         { Uop_Fail, "fail", {0,0}, "\t%-12s" }, 
    /* 182 */         { Uop_Return, "return", {0,0}, "\t%-12s" }, 
    /* 183 */         { Uop_Create, "create", {0,0}, "\t%-12s" },                 
    /* 184 */         { Uop_To, "to", {0,0}, "\t%-12s" },                 
    /* 185 */         { Uop_Toby, "toby", {0,0}, "\t%-12s" },                 
    /* 186 */         { Uop_Sect, "sect", {0,0}, "\t%-12s" },                 
    /* 187 */         { Uop_Sectm, "sectm", {0,0}, "\t%-12s" },                 
    /* 188 */         { Uop_Sectp, "sectp", {0,0}, "\t%-12s" },                 
    /* 189 */         { Uop_Scan, "scan", {0,0}, "\t%-12s" },                 
    /* 190 */         { Uop_Augscan, "augscan", {0,0}, "\t%-12s" },                 
    /* 191 */         { Uop_Not, "not", {0,0}, "\t%-12s" },                 
    /* 192 */         { Uop_Real, "real", { TYPE_16,0 }, "\t%-12s %d" },
    /* 193 */         { Uop_Global, "global", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 194 */         { Uop_Local, "local", { TYPE_32,TYPE_STR }, "\t%-12s %08o %s" },
    /* 195 */         INVALID,
    /* 196 */         { Uop_Var, "var", { TYPE_16,0 }, "\t%-12s %d" },
    /* 197 */         { Uop_Augapply, "augapply", {0,0}, "\t%-12s" },                 
    /* 198 */         INVALID,
    /* 199 */         INVALID,
    /* 200 */         { Uop_Field, "field", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 201 */         { Uop_Const, "const", { TYPE_16,0 }, "\t%-12s %d" },
    /* 202 */         { Uop_Declend, "declend", {0,0}, "\t%-12s" },           
    /* 203 */         { Uop_End, "end", {0,0}, "\t%-12s" },                   
    /* 204 */         { Uop_Ldata, "ldata", { TYPE_32, TYPE_LBIN }, "\t%-12s %08o %s" },
    /* 205 */         { Uop_Version, "version", { TYPE_STR,0 }, "\t%-12s %s" },            
    /* 206 */         { Uop_Sdata, "sdata", { TYPE_32, TYPE_SBIN }, "\t%-12s %08o %s" },
    /* 207 */         { Uop_Filen, "filen", { TYPE_STR,0 }, "\t%-12s %s" },                
    /* 208 */         { Uop_Package, "package", { TYPE_STR,0 }, "\t%-12s %s" },            
    /* 209 */         { Uop_Import, "import", { TYPE_STR, TYPE_16 }, "\t%-12s %s %d" },          
    /* 210 */         { Uop_Classfield, "classfield", { TYPE_32,TYPE_STR }, "\t%-12s %08o %s" }, 
    /* 211 */         { Uop_Recordfield, "recordfield", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 212 */         { Uop_Procdecl, "procdecl", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 213 */         INVALID,
    /* 214 */         { Uop_Importsym, "importsym", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 215 */         { Uop_Record, "record", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 216 */         INVALID,
    /* 217 */         { Uop_Error, "error", {0,0}, "\t%-12s" },               
    /* 218 */         { Uop_Link, "link", {0,0}, "\t%-12s" }, 
    /* 219 */         { Uop_Linkexpr, "linkexpr", {0,0}, "\t%-12s" }, 
    /* 220 */         { Uop_Invocable, "invocable", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 221 */         { Uop_Class, "class", { TYPE_32,TYPE_STR }, "\t%-12s %08o %s" }, 
    /* 222 */         { Uop_Super, "super", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 223 */         { Uop_Proc, "proc", { TYPE_STR,0 }, "\t%-12s %s" },
    /* 224 */         { Uop_Start, "start", {0,0}, "\t%-12s" }, 
    /* 225 */         INVALID,
    /* 226 */         { Uop_Method, "method", { TYPE_STR,TYPE_STR }, "\t%-12s %s.%s" },
    /* 227 */         INVALID,
    /* 228 */         { Uop_Empty, "empty", {0,0}, "\t%-12s" },               
    /* 229 */         { Uop_Slist, "slist", { TYPE_16,0 }, "\t%-12s %d" },                  
    /* 230 */         { Uop_Succeed, "succeed", {0,0}, "\t%-12s" }, 
    /* 231 */         { Uop_Succeedexpr, "succeedexpr", {0,0}, "\t%-12s" }, 
    /* 232 */         { Uop_Alt, "alt", {0,0}, "\t%-12s" },                 
    /* 233 */         { Uop_Conj, "conj", {0,0}, "\t%-12s" },                 
    /* 234 */         { Uop_Augconj, "augconj", {0,0}, "\t%-12s" },                 
    /* 235 */         { Uop_If, "if", { 0,0 }, "\t%-12s" },                  
    /* 236 */         { Uop_Ifelse, "ifelse", { 0,0 }, "\t%-12s" },                  
    /* 237 */         { Uop_Repeat, "repeat", {0,0}, "\t%-12s" },                 
    /* 238 */         { Uop_While, "while", { 0,0 }, "\t%-12s" },                  
    /* 239 */         { Uop_Suspend, "suspend", { 0,0 }, "\t%-12s" },                  
    /* 240 */         { Uop_Until, "until", { 0,0 }, "\t%-12s" },                  
    /* 241 */         { Uop_Every, "every", { 0,0 }, "\t%-12s" },                  
    /* 242 */         { Uop_Line, "line", { TYPE_16,0 }, "\t%-12s %d" },                
    /* 243 */         { Uop_Whiledo, "whiledo", { 0,0 }, "\t%-12s" },                  
    /* 244 */         { Uop_Suspenddo, "suspenddo", { 0,0 }, "\t%-12s" },                  
    /* 245 */         { Uop_Untildo, "untildo", { 0,0 }, "\t%-12s" },                  
    /* 246 */         { Uop_Everydo, "everydo", { 0,0 }, "\t%-12s" },                  
    /* 247 */         { Uop_Uactivate, "uactivate", { 0,0 }, "\t%-12s" },                  
    /* 248 */         { Uop_Bactivate, "bactivate", { 0,0 }, "\t%-12s" },                  
    /* 249 */         { Uop_Augactivate, "augactivate", { 0,0 }, "\t%-12s" },                  
    /* 250 */         { Uop_Rptalt, "rptalt", { 0,0 }, "\t%-12s" },                  
    /* 251 */         { Uop_Invoke, "invoke", { TYPE_16,0 }, "\t%-12s %d" },
    /* 252 */         { Uop_CoInvoke, "coinvoke", { TYPE_16,0 }, "\t%-12s %d" },
    /* 253 */         { Uop_Mutual, "mutual", { TYPE_16,0 }, "\t%-12s %d" },
    /* 254 */         { Uop_Apply, "apply", { 0,0 }, "\t%-12s" },
    /* 255 */         INVALID,
};

static int last_opcode = 0, n_params = 0;

static struct str_buf ucode_sbuf;

static void check_param(int type)
{
    if (n_params > 1)
        quit("Too many params opcode %d", last_opcode);
    if (ucode_op_table[last_opcode].param_type[n_params] != type)
        quit("Wrong param type %d for opcode %d", type, last_opcode);
    ++n_params;
}

void uout_op(int opcode)
{
    if (ucode_op_table[opcode].opcode != opcode)
        quit("Illegal opcode output: %d", opcode);
    last_opcode = opcode;
    n_params = 0;
    putc(opcode, ucodefile);
}

void uout_16(int n)
{
    union {
        unsigned char c[2];
        int16_t s;
    } i;
    check_param(TYPE_16);
    if (n > 0x7fff || n < -0x8000)
        quit("Param to uout_16 out of range");
    i.s = n;
    putc(i.c[0], ucodefile);
    putc(i.c[1], ucodefile);
}

void uout_32(word n)
{
    union {
        unsigned char c[4];
        int32_t w;
    } i;
    check_param(TYPE_32);
    i.w = n;
    putc(i.c[0], ucodefile);
    putc(i.c[1], ucodefile);
    putc(i.c[2], ucodefile);
    putc(i.c[3], ucodefile);
}

void uout_str(char *s)
{
    check_param(TYPE_STR);
    while(*s)
        putc(*s++, ucodefile);
    putc(0, ucodefile);
}

void uout_sbin(int len, char *s)
{
    check_param(TYPE_SBIN);
    if (len > 0xff)
        quit("Param to uout_sbin out of range");
    putc(len, ucodefile);
    while (len-- > 0)
        putc(*s++, ucodefile);
}

void uout_lbin(int len, char *s)
{
    union {
        unsigned char c[4];
        uint32_t s;
    } i;
    check_param(TYPE_LBIN);
    i.s = len;
    putc(i.c[0], ucodefile);
    putc(i.c[1], ucodefile);
    putc(i.c[2], ucodefile);
    putc(i.c[3], ucodefile);
    while (len-- > 0)
        putc(*s++, ucodefile);
}

static int uin_nextch(void)
{
    int c = getc(ucodefile);
    if (c == EOF)
        quit("Unexpected EOF in ufile %s", inname);
    return c;
}

word uin_32()
{
    union {
        unsigned char c[4];
        int32_t w;
    } i;
    check_param(TYPE_32);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    i.c[2] = uin_nextch();
    i.c[3] = uin_nextch();
    return (word)i.w;
}

int uin_16()
{
    union {
        unsigned char c[2];
        int16_t s;
    } i;
    check_param(TYPE_16);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    return (int)i.s;
}

char *uin_str()
{
    int c;
    check_param(TYPE_STR);
    zero_sbuf(&ucode_sbuf);
    for (;;) {
        c = uin_nextch();
        if (!c)
            break;
        AppChar(ucode_sbuf, c);
    }
    return str_install(&ucode_sbuf);
}

char *uin_sbin(int *n)
{
    int c, l;
    check_param(TYPE_SBIN);
    l = uin_nextch();
    if (n)
        *n = l;
    zero_sbuf(&ucode_sbuf);
    while (l-- > 0) {
        c = uin_nextch();
        AppChar(ucode_sbuf, c);
    }
    return str_install(&ucode_sbuf);
}

char *uin_lbin(int *n)
{
    union {
        unsigned char c[4];
        uint32_t s;
    } i;
    int c, l;
    check_param(TYPE_LBIN);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    i.c[2] = uin_nextch();
    i.c[3] = uin_nextch();
    l = (int)i.s;
    if (n)
        *n = l;
    zero_sbuf(&ucode_sbuf);
    while (l-- > 0) {
        c = uin_nextch();
        AppChar(ucode_sbuf, c);
    }
    return str_install(&ucode_sbuf);
}

struct ucode_op *uin_expectop()
{
    struct ucode_op* op = uin_op();
    if (!op)
        quit("Unexpected EOF in ufile %s", inname);
    return op;
}

/*
 * Like uin_str, but prepends package to the returned result.
 */
char *uin_fqid(char *package)
{
    int c;
    check_param(TYPE_STR);
    zero_sbuf(&ucode_sbuf);
    if (package) {
        while (*package) {
            AppChar(ucode_sbuf, *package++);
        }
        /* Add a "." between package and string */
        AppChar(ucode_sbuf, '.');
    }
    for (;;) {
        c = uin_nextch();
        if (!c)
            break;
        AppChar(ucode_sbuf, c);
    }
    return str_install(&ucode_sbuf);
}

struct ucode_op *uin_op()
{
    int opcode;
    struct ucode_op *op;
    opcode = getc(ucodefile);
    if (opcode == EOF)
        return 0;
    if (opcode >= ElemCount(ucode_op_table))
        quit("Illegal opcode: %d", opcode);
    op = &ucode_op_table[opcode];
    if (op->opcode == 0)
        quit("Illegal opcode: %d", opcode);
    last_opcode = opcode;
    n_params = 0;
    return op;
}

void uin_skip(int opcode)
{
    int i;
    for (i = 0; i < 2; ++i) {
        switch (ucode_op_table[opcode].param_type[i]) {
            case TYPE_NONE:
                break;
            case TYPE_32:
                uin_32();
                break;
            case TYPE_16:
                uin_16();
                break;
            case TYPE_STR:
                uin_str();
                break;
            case TYPE_SBIN:
                uin_sbin(0);
                break;
            case TYPE_LBIN:
                uin_lbin(0);
                break;
            default:
                quit("Internal error");
        }
    }
}

/*
 * 
 * Udis ucode disassembler.
 * 
 * 
 */

static char buff[256];
static void read_params(struct ucode_op *op);

int udis(int argc, char **argv)
{
    struct ucode_op *op;
    if (argc < 2) {
        fprintf(stderr, "Usage: udis ufile\n");
        exit(EXIT_FAILURE);
    }
    inname = intern(argv[1]);
    ucodefile = fopen(inname, ReadBinary);
    if (!ucodefile) {
        fprintf(stderr, "Couldn't open %s\n", inname);
        exit(EXIT_FAILURE);
    }
    while ((op = uin_op())) {
        int i, n, spos = ftell(ucodefile) - 1;
        read_params(op);
        n = ftell(ucodefile) - spos;
        fseek(ucodefile, spos, SEEK_SET);
        printf("%06x: ", spos);
        for (i = 0; i < n; ++i) {
            int c = uin_nextch();
            printf("%02x ", c);
            if (i == n - 1) {
                while (i++ < 8)
                    printf("   ");
                printf("\t%s\n", buff);
            } else if (i % 8 == 7) {
                printf("\t%s\n        ", buff);
                ArrClear(buff);
            }
        }
    }
    fclose(ucodefile);
    return 0;
}

static void read_params(struct ucode_op *op)
{
    int i;
    word args[3];
    for (i = 0; i < 2; ++i) {
        switch (op->param_type[i]) {
            case TYPE_NONE:
                args[i] = 0;
                break;
            case TYPE_32:
                args[i] = uin_32();
                break;
            case TYPE_16:
                args[i] = uin_16();
                break;
            case TYPE_STR:
                args[i] = (word)uin_str();
                break;
            case TYPE_SBIN: {
                int l;
                char *s1 = uin_sbin(&l);
                zero_sbuf(&ucode_sbuf);
                while (l-- > 0) {
                    if (oi_isprint(*s1))
                        AppChar(ucode_sbuf, *s1);
                    else
                        AppChar(ucode_sbuf, '?');
                    ++s1;
                }
                args[i] = (word)str_install(&ucode_sbuf);
                break;
            }
            case TYPE_LBIN: {
                int l;
                char *s1 = uin_lbin(&l);
                zero_sbuf(&ucode_sbuf);
                while (l-- > 0) {
                    if (oi_isprint(*s1))
                        AppChar(ucode_sbuf, *s1);
                    else
                        AppChar(ucode_sbuf, '?');
                    ++s1;
                }
                args[i] = (word)str_install(&ucode_sbuf);
                break;
            }
            default:
                quit("Internal error");
        }
    }
    snprintf(buff, sizeof(buff), op->fmt, op->name, args[0], args[1], args[2]);
}

