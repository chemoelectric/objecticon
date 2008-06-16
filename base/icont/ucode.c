#include "link.h"
#include "ucode.h"
#include "lmem.h"

#include "../h/opdefs.h"

#define INVALID { 0, 0, {}, 0 }

struct ucode_op ucode_op_table[] = {
    /*   0 */         INVALID,                                    
    /*   1 */         { Op_Asgn, "asgn", {}, "\t%-12s" },                 
    /*   2 */         { Op_Bang, "bang", {}, "\t%-12s" },                 
    /*   3 */         { Op_Cat, "cat", {}, "\t%-12s" },                   
    /*   4 */         { Op_Compl, "compl", {}, "\t%-12s" },               
    /*   5 */         { Op_Diff, "diff", {}, "\t%-12s" },                 
    /*   6 */         { Op_Div, "div", {}, "\t%-12s" },                   
    /*   7 */         { Op_Eqv, "eqv", {}, "\t%-12s" },                   
    /*   8 */         { Op_Inter, "inter", {}, "\t%-12s" },               
    /*   9 */         { Op_Lconcat, "lconcat", {}, "\t%-12s" },           
    /*  10 */         { Op_Lexeq, "lexeq", {}, "\t%-12s" },               
    /*  11 */         { Op_Lexge, "lexge", {}, "\t%-12s" },               
    /*  12 */         { Op_Lexgt, "lexgt", {}, "\t%-12s" },               
    /*  13 */         { Op_Lexle, "lexle", {}, "\t%-12s" },               
    /*  14 */         { Op_Lexlt, "lexlt", {}, "\t%-12s" },               
    /*  15 */         { Op_Lexne, "lexne", {}, "\t%-12s" },               
    /*  16 */         { Op_Minus, "minus", {}, "\t%-12s" },               
    /*  17 */         { Op_Mod, "mod", {}, "\t%-12s" },                   
    /*  18 */         { Op_Mult, "mult", {}, "\t%-12s" },                 
    /*  19 */         { Op_Neg, "neg", {}, "\t%-12s" },                   
    /*  20 */         { Op_Neqv, "neqv", {}, "\t%-12s" },                 
    /*  21 */         { Op_Nonnull, "nonnull", {}, "\t%-12s" },           
    /*  22 */         { Op_Null, "null", {}, "\t%-12s" },                 
    /*  23 */         { Op_Number, "number", {}, "\t%-12s" },             
    /*  24 */         { Op_Numeq, "numeq", {}, "\t%-12s" },               
    /*  25 */         { Op_Numge, "numge", {}, "\t%-12s" },               
    /*  26 */         { Op_Numgt, "numgt", {}, "\t%-12s" },               
    /*  27 */         { Op_Numle, "numle", {}, "\t%-12s" },               
    /*  28 */         { Op_Numlt, "numlt", {}, "\t%-12s" },               
    /*  29 */         { Op_Numne, "numne", {}, "\t%-12s" },               
    /*  30 */         { Op_Plus, "plus", {}, "\t%-12s" },                 
    /*  31 */         { Op_Power, "power", {}, "\t%-12s" },               
    /*  32 */         { Op_Random, "random", {}, "\t%-12s" },             
    /*  33 */         { Op_Rasgn, "rasgn", {}, "\t%-12s" },               
    /*  34 */         { Op_Refresh, "refresh", {}, "\t%-12s" },           
    /*  35 */         { Op_Rswap, "rswap", {}, "\t%-12s" },               
    /*  36 */         { Op_Sect, "sect", {}, "\t%-12s" },                 
    /*  37 */         { Op_Size, "size", {}, "\t%-12s" },                 
    /*  38 */         { Op_Subsc, "subsc", {}, "\t%-12s" },               
    /*  39 */         { Op_Swap, "swap", {}, "\t%-12s" },                 
    /*  40 */         { Op_Tabmat, "tabmat", {}, "\t%-12s" },             
    /*  41 */         { Op_Toby, "toby", {}, "\t%-12s" },                 
    /*  42 */         { Op_Unions, "unions", {}, "\t%-12s" },             
    /*  43 */         { Op_Value, "value", {}, "\t%-12s" },               
    /*  44 */         { Op_Bscan, "bscan", {}, "\t%-12s" },               
    /*  45 */         { Op_Ccase, "ccase", {}, "\t%-12s" },               
    /*  46 */         { Op_Chfail, "chfail", { TYPE_SHORT }, "\t%-12s L%d" },            
    /*  47 */         { Op_Coact, "coact", {}, "\t%-12s" },               
    /*  48 */         { Op_Cofail, "cofail", {}, "\t%-12s" },             
    /*  49 */         { Op_Coret, "coret", {}, "\t%-12s" },               
    /*  50 */         { Op_Create, "create", { TYPE_SHORT }, "\t%-12s L%d" },            
    /*  51 */         { Op_Cset, "cset", { TYPE_SHORT }, "\t%-12s %d" },                
    /*  52 */         { Op_Dup, "dup", {}, "\t%-12s" },                   
    /*  53 */         { Op_Efail, "efail", {}, "\t%-12s" },               
    /*  54 */         { Op_Eret, "eret", {}, "\t%-12s" },                 
    /*  55 */         { Op_Escan, "escan", {}, "\t%-12s" },               
    /*  56 */         { Op_Esusp, "esusp", {}, "\t%-12s" },               
    /*  57 */         { Op_Field, "field", { TYPE_STR }, "\t%-12s %s" },                
    /*  58 */         { Op_Goto, "goto", { TYPE_SHORT }, "\t%-12s L%d" },                
    /*  59 */         { Op_Init, "init", { TYPE_SHORT }, "\t%-12s L%d" },                
    /*  60 */         { Op_Int, "int", { TYPE_SHORT }, "\t%-12s %d" },                  
    /*  61 */         { Op_Invoke, "invoke", { TYPE_SHORT }, "\t%-12s %d" },            
    /*  62 */         { Op_Keywd, "keywd", { TYPE_STR }, "\t%-12s %s" },                
    /*  63 */         { Op_Limit, "limit", {}, "\t%-12s" },               
    /*  64 */         { Op_Line, "line", { TYPE_SHORT }, "\t%-12s %d" },                
    /*  65 */         { Op_Llist, "llist", { TYPE_WORD }, "\t%-12s %d" },               
    /*  66 */         { Op_Lsusp, "lsusp", {}, "\t%-12s" },               
    /*  67 */         { Op_Mark, "mark", { TYPE_SHORT }, "\t%-12s L%d" },                
    /*  68 */         { Op_Pfail, "pfail", {}, "\t%-12s" },               
    /*  69 */         { Op_Pnull, "pnull", {}, "\t%-12s" },               
    /*  70 */         { Op_Pop, "pop", {}, "\t%-12s" },                   
    /*  71 */         { Op_Pret, "pret", {}, "\t%-12s" },                 
    /*  72 */         { Op_Psusp, "psusp", {}, "\t%-12s" },               
    /*  73 */         { Op_Push1, "push1", {}, "\t%-12s" },               
    /*  74 */         { Op_Pushn1, "pushn1", {}, "\t%-12s" },             
    /*  75 */         { Op_Real, "real", { TYPE_SHORT }, "\t%-12s %d" },                
    /*  76 */         { Op_Sdup, "sdup", {}, "\t%-12s" },                 
    /*  77 */         { Op_Str, "str", { TYPE_SHORT }, "\t%-12s %d" },                  
    /*  78 */         { Op_Unmark, "unmark", {}, "\t%-12s" },             
    /*  79 */         INVALID,                                    
    /*  80 */         { Op_Var, "var", { TYPE_SHORT }, "\t%-12s %d" },                  
    /*  81 */         { Op_Arg, "arg", {}, "\t%-12s" },                   
    /*  82 */         { Op_Static, "static", {}, "\t%-12s" },             
    /*  83 */         { Op_Local, "local", { TYPE_WORD,TYPE_STR }, "\t%-12s %08o %s" },
    /*  84 */         { Op_Global, "global", { TYPE_STR }, "\t%-12s %s" },
    /*  85 */         { Op_Mark0, "mark0", {}, "\t%-12s" },               
    /*  86 */         { Op_Quit, "quit", {}, "\t%-12s" },                 
    /*  87 */         { Op_FQuit, "fquit", {}, "\t%-12s" },               
    /*  88 */         { Op_Tally, "tally", {}, "\t%-12s" },               
    /*  89 */         { Op_Apply, "apply", {}, "\t%-12s" },               
    /*  90 */         INVALID,                                    
    /*  91 */         INVALID,                                    
    /*  92 */         INVALID,                                    
    /*  93 */         INVALID,                                    
    /*  94 */         INVALID,                                    
    /*  95 */         INVALID,                                    
    /*  96 */         INVALID,                                    
    /*  97 */         INVALID,                                    
    /*  98 */         { Op_Noop, "noop", {}, "\t%-12s" },                 
    /*  99 */         INVALID,                                    
    /* 100 */         INVALID,                                    
    /* 101 */         INVALID,                                    
    /* 102 */         INVALID,                                    
    /* 103 */         INVALID,                                    
    /* 104 */         INVALID,                                    
    /* 105 */         INVALID,                                    
    /* 106 */         INVALID,                                    
    /* 107 */         INVALID,                                    
    /* 108 */         INVALID,
    /* 109 */         INVALID,                                    
    /* 110 */         INVALID,                                    
    /* 111 */         INVALID,                                    
    /* 112 */         INVALID,                                    
    /* 113 */         INVALID,                                    
    /* 114 */         INVALID,                                    
    /* 115 */         INVALID,                                    
    /* 116 */         INVALID,                                    
    /* 117 */         INVALID,                                    
    /* 118 */         INVALID,                                    
    /* 119 */         INVALID,                                    
    /* 120 */         INVALID,                                    
    /* 121 */         INVALID,                                    
    /* 122 */         INVALID,                                    
    /* 123 */         INVALID,                                    
    /* 124 */         INVALID,                                    
    /* 125 */         INVALID,                                    
    /* 126 */         INVALID,                                    
    /* 127 */         INVALID,                                    
    /* 128 */         INVALID,                                    
    /* 129 */         INVALID,                                    
    /* 130 */         INVALID,                                    
    /* 131 */         INVALID,                                    
    /* 132 */         INVALID,                                    
    /* 133 */         INVALID,                                    
    /* 134 */         INVALID,                                    
    /* 135 */         INVALID,                                    
    /* 136 */         INVALID,                                    
    /* 137 */         INVALID,                                    
    /* 138 */         INVALID,                                    
    /* 139 */         INVALID,                                    
    /* 140 */         INVALID,                                    
    /* 141 */         INVALID,                                    
    /* 142 */         INVALID,                                    
    /* 143 */         INVALID,                                    
    /* 144 */         INVALID,                                    
    /* 145 */         INVALID,                                    
    /* 146 */         INVALID,                                    
    /* 147 */         INVALID,                                    
    /* 148 */         INVALID,                                    
    /* 149 */         INVALID,                                    
    /* 150 */         INVALID,                                    
    /* 151 */         INVALID,                                    
    /* 152 */         INVALID,                                    
    /* 153 */         INVALID,                                    
    /* 154 */         INVALID,                                    
    /* 155 */         INVALID,                                    
    /* 156 */         INVALID,                                    
    /* 157 */         INVALID,                                    
    /* 158 */         INVALID,                                    
    /* 159 */         INVALID,                                    
    /* 160 */         INVALID,                                    
    /* 161 */         INVALID,                                    
    /* 162 */         INVALID,                                    
    /* 163 */         INVALID,                                    
    /* 164 */         INVALID,                                    
    /* 165 */         INVALID,                                    
    /* 166 */         INVALID,                                    
    /* 167 */         INVALID,                                    
    /* 168 */         INVALID,                                    
    /* 169 */         INVALID,                                    
    /* 170 */         INVALID,                                    
    /* 171 */         INVALID,                                    
    /* 172 */         INVALID,                                    
    /* 173 */         INVALID,                                    
    /* 174 */         INVALID,                                    
    /* 175 */         INVALID,                                    
    /* 176 */         INVALID,                                    
    /* 177 */         INVALID,                                    
    /* 178 */         INVALID,                                    
    /* 179 */         INVALID,                                    
    /* 180 */         INVALID,                                    
    /* 181 */         INVALID,                                    
    /* 182 */         INVALID,                                    
    /* 183 */         INVALID,                                    
    /* 184 */         INVALID,                                    
    /* 185 */         INVALID,                                    
    /* 186 */         INVALID,                                    
    /* 187 */         INVALID,                                    
    /* 188 */         INVALID,                                    
    /* 189 */         INVALID,                                    
    /* 190 */         INVALID,                                    
    /* 191 */         INVALID,                                    
    /* 192 */         INVALID,                                    
    /* 193 */         INVALID,                                    
    /* 194 */         INVALID,                                    
    /* 195 */         INVALID,                                    
    /* 196 */         INVALID,                                    
    /* 197 */         INVALID,                                    
    /* 198 */         INVALID,                                    
    /* 199 */         INVALID,                                    
    /* 200 */         INVALID,                                    
    /* 201 */         { Op_Proc, "proc", { TYPE_STR }, "%s %s" },             
    /* 202 */         { Op_Declend, "declend", {}, "\t%-12s" },           
    /* 203 */         { Op_End, "end", {}, "\t%-12s" },                   
    /* 204 */         { Op_Link, "link", { TYPE_STR }, "\t%-12s %s" },    
    /* 205 */         { Op_Version, "version", { TYPE_STR }, "\t%-12s %s" },            
    /* 206 */         { Op_Con, "con", { TYPE_WORD, TYPE_BIN }, "\t%-12s %08o %s" },
    /* 207 */         { Op_Filen, "filen", { TYPE_STR }, "\t%-12s %s" },                
    /* 208 */         { Op_Package, "package", { TYPE_STR }, "\t%-12s %s" },            
    /* 209 */         { Op_Import, "import", { TYPE_STR, TYPE_SHORT }, "\t%-12s %s %d" },          
    /* 210 */         { Op_Classfield, "classfield", { TYPE_WORD,TYPE_STR }, "\t%-12s %08o %s" }, 
    /* 211 */         { Op_Recordfield, "recordfield", { TYPE_STR }, "\t%-12s %s" },
    /* 212 */         { Op_Procdecl, "procdecl", { TYPE_STR }, "\t%-12s %s" },
    /* 213 */         { Op_Nargs, "nargs", { TYPE_SHORT }, "\t%-12s %d" },
    /* 214 */         { Op_Importsym, "importsym", { TYPE_STR }, "\t%-12s %s" },
    /* 215 */         { Op_Record, "record", { TYPE_STR }, "\t%-12s %s" },
    /* 216 */         INVALID,
    /* 217 */         { Op_Error, "error", {}, "\t%-12s" },               
    /* 218 */         { Op_Trace, "trace", {}, "\t%-12s" },               
    /* 219 */         { Op_Lab, "lab", { TYPE_SHORT }, "%s L%d" },                  
    /* 220 */         { Op_Invocable, "invocable", { TYPE_STR }, "\t%-12s %s" },
    /* 221 */         { Op_Class, "class", { TYPE_WORD,TYPE_STR }, "\t%-12s %08o %s" }, 
    /* 222 */         { Op_Super, "super", { TYPE_STR }, "\t%-12s %s" },
    /* 223 */         { Op_Method, "method", { TYPE_STR, TYPE_STR }, "%s %s.%s" },         
};

static int last_opcode = 0, n_params = 0;

static void check_param(int type)
{
    if (n_params > 2)
        quitf("Too many params opcode %d", last_opcode);
    if (ucode_op_table[last_opcode].param_type[n_params] != type)
        quitf("Wrong param type %d for opcode %d", type, last_opcode);
    ++n_params;
}

void uout_op(int opcode)
{
    if (ucode_op_table[opcode].opcode != opcode)
        quitf("Illegal opcode output: %d", opcode);
    last_opcode = opcode;
    n_params = 0;
    putc(opcode, ucodefile);
}

void uout_short(int n)
{
    union {
        unsigned char c[2];
        signed int s:16;
    } i;
    check_param(TYPE_SHORT);
    if (n > 0x7fff || n < -0x8000)
        quitf("Param to uout_short out of range");
    i.s = n;
    putc(i.c[0], ucodefile);
    putc(i.c[1], ucodefile);
}

void uout_word(word n)
{
    union {
        unsigned char c[4];
        signed long int w:32;
    } i;
    check_param(TYPE_WORD);
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

void uout_bin(int len, char *s)
{
    union {
        unsigned char c[2];
        unsigned int s:16;
    } i;
    check_param(TYPE_BIN);
    if (len > 0xffff)
        quitf("Param to uout_bin out of range");
    i.s = len;
    putc(i.c[0], ucodefile);
    putc(i.c[1], ucodefile);
    while (len-- > 0)
        putc(*s++, ucodefile);
}

static int uin_nextch()
{
    int c = getc(ucodefile);
    if (c == EOF)
        quitf("Unexpected EOF in ufile %s", inname);
    return c;
}

word uin_word()
{
    union {
        unsigned char c[4];
        signed long int w:32;
    } i;
    check_param(TYPE_WORD);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    i.c[2] = uin_nextch();
    i.c[3] = uin_nextch();
    return (word)i.w;
}

int uin_short()
{
    union {
        unsigned char c[2];
        signed int s:16;
    } i;
    check_param(TYPE_SHORT);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    return (int)i.s;
}

char *uin_str()
{
    int c;
    check_param(TYPE_STR);
    zero_sbuf(&llex_sbuf);
    for (;;) {
        c = uin_nextch();
        if (!c)
            break;
        AppChar(llex_sbuf, c);
    }
    return str_install(&llex_sbuf);
}

char *uin_bin(int *n)
{
    union {
        unsigned char c[2];
        unsigned int s:16;
    } i;
    int c, l;
    check_param(TYPE_BIN);
    i.c[0] = uin_nextch();
    i.c[1] = uin_nextch();
    l = (int)i.s;
    if (n)
        *n = l;
    zero_sbuf(&llex_sbuf);
    while (l-- > 0) {
        c = uin_nextch();
        AppChar(llex_sbuf, c);
    }
    return str_install(&llex_sbuf);
}

struct ucode_op *uin_expectop()
{
    struct ucode_op* op = uin_op();
    if (!op)
        quitf("Unexpected EOF in ufile %s", inname);
    return op;
}

/*
 * Like uin_str, but prepends package to the returned result.
 */
char *uin_fqid(char *package)
{
    register int c;
    check_param(TYPE_STR);
    zero_sbuf(&llex_sbuf);
    if (package) {
        while (*package) {
            AppChar(llex_sbuf, *package++);
        }
        /* Add a "." between package and string */
        AppChar(llex_sbuf, '.');
    }
    for (;;) {
        c = uin_nextch();
        if (!c)
            break;
        AppChar(llex_sbuf, c);
    }
    return str_install(&llex_sbuf);
}

struct ucode_op *uin_op()
{
    int opcode;
    struct ucode_op *op;
    opcode = getc(ucodefile);
    if (opcode == EOF)
        return 0;
    if (opcode >= asize(ucode_op_table))
        quitf("Illegal opcode: %d", opcode);
    op = &ucode_op_table[opcode];
    if (op->opcode == 0)
        quitf("Illegal opcode: %d", opcode);
    last_opcode = opcode;
    n_params = 0;
    return op;
}

void uin_skip(int opcode)
{
    int i;
    for (i = 0; i < 3; ++i) {
        switch (ucode_op_table[opcode].param_type[i]) {
            case TYPE_NONE:
                break;
            case TYPE_WORD:
                uin_word();
                break;
            case TYPE_SHORT:
                uin_short();
                break;
            case TYPE_STR:
                uin_str();
                break;
            case TYPE_BIN:
                uin_bin(0);
                break;
            default:
                quitf("Internal error");
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
        exit(1);
    }
    strcpy(inname, argv[1]);
    ucodefile = fopen(inname, ReadBinary);
    if (!ucodefile) {
        fprintf(stderr, "Couldn't open %s\n", inname);
        exit(1);
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
                clear(buff);
            }
        }
    }
    fclose(ucodefile);
    return 0;
}

static void read_params(struct ucode_op *op)
{
    int i;
    long args[3];
    for (i = 0; i < 3; ++i) {
        switch (op->param_type[i]) {
            case TYPE_NONE:
                args[i] = 0;
                break;
            case TYPE_WORD:
                args[i] = uin_word();
                break;
            case TYPE_SHORT:
                args[i] = uin_short();
                break;
            case TYPE_STR:
                args[i] = (long)uin_str();
                break;
            case TYPE_BIN: {
                int l, t;
                char *s1 = uin_bin(&l);
                t = l;
                zero_sbuf(&llex_sbuf);
                while (l-- > 0) {
                    if (isprint(*s1))
                        AppChar(llex_sbuf, *s1);
                    else
                        AppChar(llex_sbuf, '?');
                    ++s1;
                }
                args[i] = (long)str_install(&llex_sbuf);
                break;
            }
            default:
                quitf("Internal error");
        }
    }
    snprintf(buff, sizeof(buff), op->fmt, op->name, args[0], args[1], args[2]);
}

