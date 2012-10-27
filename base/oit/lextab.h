/*
 * NOTE: this file is generated automatically by mktoktab
 *  from tokens.txt and op.txt.
 */

/*
 * Token table - contains an entry for each token type
 * with printable name of token, token type, and flags
 * for semicolon insertion.
 */

struct toktab toktab[] = {
/*  token		token type	flags */

   /* primitives */
   { "identifier",       IDENT,         Beginner+Ender},   /*   0 */
   { "integer-literal",  INTLIT,        Beginner+Ender},   /*   1 */
   { "real-literal",     REALLIT,       Beginner+Ender},   /*   2 */
   { "string-literal",   STRINGLIT,     Beginner+Ender},   /*   3 */
   { "cset-literal",     CSETLIT,       Beginner+Ender},   /*   4 */
   { "ucs-literal",      UCSLIT,        Beginner+Ender},   /*   5 */
   { "end-of-file",      EOFX,          0},                /*   6 */

   /* reserved words */
   { "break",            BREAK,         Beginner+Ender},   /*   7 */
   { "by",               BY,            0},                /*   8 */
   { "case",             CASE,          Beginner},         /*   9 */
   { "class",            CLASS,         0},                /*  10 */
   { "const",            CONST,         0},                /*  11 */
   { "create",           CREATE,        Beginner},         /*  12 */
   { "default",          DEFAULT,       Beginner},         /*  13 */
   { "defer",            DEFER,         0},                /*  14 */
   { "do",               DO,            0},                /*  15 */
   { "else",             ELSE,          0},                /*  16 */
   { "end",              END,           0},                /*  17 */
   { "every",            EVERY,         Beginner},         /*  18 */
   { "fail",             FAIL,          Beginner+Ender},   /*  19 */
   { "final",            FINAL,         0},                /*  20 */
   { "global",           GLOBAL,        0},                /*  21 */
   { "if",               IF,            Beginner},         /*  22 */
   { "import",           IMPORT,        0},                /*  23 */
   { "initial",          INITIAL,       0},                /*  24 */
   { "invocable",        INVOCABLE,     0},                /*  25 */
   { "local",            LOCAL,         0},                /*  26 */
   { "next",             NEXT,          Beginner+Ender},   /*  27 */
   { "not",              NOT,           Beginner},         /*  28 */
   { "of",               OF,            0},                /*  29 */
   { "package",          PACKAGE,       0},                /*  30 */
   { "private",          PRIVATE,       0},                /*  31 */
   { "procedure",        PROCEDURE,     0},                /*  32 */
   { "protected",        PROTECTED,     0},                /*  33 */
   { "public",           PUBLIC,        0},                /*  34 */
   { "readable",         READABLE,      0},                /*  35 */
   { "record",           RECORD,        0},                /*  36 */
   { "repeat",           REPEAT,        Beginner},         /*  37 */
   { "return",           RETURN,        Beginner+Ender},   /*  38 */
   { "static",           STATIC,        0},                /*  39 */
   { "suspend",          SUSPEND,       Beginner+Ender},   /*  40 */
   { "then",             THEN,          0},                /*  41 */
   { "to",               TO,            0},                /*  42 */
   { "uninst",           UNINST,        0},                /*  43 */
   { "until",            UNTIL,         Beginner},         /*  44 */
   { "while",            WHILE,         Beginner},         /*  45 */
   { "end-of-file",      0,             0},
   };

/*
 * restab[c] points to the first reserved word in toktab which
 * begins with the letter c.
 */

struct toktab *restab[] = {
   NULL,        &toktab[ 7], &toktab[ 9], &toktab[13], /* 61-64 abcd */
   &toktab[16], &toktab[19], &toktab[21], NULL,        /* 65-68 efgh */
   &toktab[22], NULL,        NULL,        &toktab[26], /* 69-6C ijkl */
   NULL,        &toktab[27], &toktab[29], &toktab[30], /* 6D-70 mnop */
   NULL,        &toktab[35], &toktab[39], &toktab[41], /* 71-74 qrst */
   &toktab[43], NULL,        &toktab[45], NULL,        /* 75-78 uvwx */
   NULL,        NULL,                                  /* 79-7A yz */
   };

/*
 * The operator table acts to extend the token table, it
 *  indicates what implementations are expected from rtt,
 *  and it has pointers for the implementation information.
 */

struct optab optab[] = {
   {{"!",      BANG,       Beginner}, Unary},         /* 0 */
   {{"%",      MOD,        0},        Binary},        /* 1 */
   {{"%:=",    AUGMOD,     0},        0},             /* 2 */
   {{"&",      AND,        Beginner}, Binary},        /* 3 */
   {{"&:=",    AUGAND,     0},        0},             /* 4 */
   {{"*",      STAR,       Beginner}, Unary | Binary},/* 5 */
   {{"*:=",    AUGSTAR,    0},        0},             /* 6 */
   {{"**",     INTER,      Beginner}, Binary},        /* 7 */
   {{"**:=",   AUGINTER,   0},        0},             /* 8 */
   {{"+",      PLUS,       Beginner}, Unary | Binary},/* 9 */
   {{"+:=",    AUGPLUS,    0},        0},             /* 10 */
   {{"++",     UNION,      Beginner}, Binary},        /* 11 */
   {{"++:=",   AUGUNION,   0},        0},             /* 12 */
   {{"-",      MINUS,      Beginner}, Unary | Binary},/* 13 */
   {{"-:=",    AUGMINUS,   0},        0},             /* 14 */
   {{"--",     DIFF,       Beginner}, Binary},        /* 15 */
   {{"--:=",   AUGDIFF,    0},        0},             /* 16 */
   {{".",      DOT,        Beginner}, Unary},         /* 17 */
   {{"/",      SLASH,      Beginner}, Unary | Binary},/* 18 */
   {{"/:=",    AUGSLASH,   0},        0},             /* 19 */
   {{":=",     ASSIGN,     0},        Binary},        /* 20 */
   {{":=:",    SWAP,       0},        Binary},        /* 21 */
   {{"<",      NMLT,       0},        Binary},        /* 22 */
   {{"<:=",    AUGNMLT,    0},        0},             /* 23 */
   {{"<-",     REVASSIGN,  0},        Binary},        /* 24 */
   {{"<->",    REVSWAP,    0},        Binary},        /* 25 */
   {{"<<",     SLT,        0},        Binary},        /* 26 */
   {{"<<:=",   AUGSLT,     0},        0},             /* 27 */
   {{"<<=",    SLE,        0},        Binary},        /* 28 */
   {{"<<=:=",  AUGSLE,     0},        0},             /* 29 */
   {{"<=",     NMLE,       0},        Binary},        /* 30 */
   {{"<=:=",   AUGNMLE,    0},        0},             /* 31 */
   {{"=",      NMEQ,       Beginner}, Unary | Binary},/* 32 */
   {{"=:=",    AUGNMEQ,    0},        0},             /* 33 */
   {{"==",     SEQ,        Beginner}, Binary},        /* 34 */
   {{"==:=",   AUGSEQ,     0},        0},             /* 35 */
   {{"===",    EQUIV,      Beginner}, Binary},        /* 36 */
   {{"===:=",  AUGEQUIV,   0},        0},             /* 37 */
   {{">",      NMGT,       0},        Binary},        /* 38 */
   {{">:=",    AUGNMGT,    0},        0},             /* 39 */
   {{">=",     NMGE,       0},        Binary},        /* 40 */
   {{">=:=",   AUGNMGE,    0},        0},             /* 41 */
   {{">>",     SGT,        0},        Binary},        /* 42 */
   {{">>:=",   AUGSGT,     0},        0},             /* 43 */
   {{">>=",    SGE,        0},        Binary},        /* 44 */
   {{">>=:=",  AUGSGE,     0},        0},             /* 45 */
   {{"?",      QMARK,      Beginner}, Unary},         /* 46 */
   {{"?:=",    AUGQMARK,   0},        0},             /* 47 */
   {{"@",      AT,         Beginner}, 0},             /* 48 */
   {{"@:=",    AUGAT,      0},        0},             /* 49 */
   {{"\\",     BACKSLASH,  Beginner}, Unary},         /* 50 */
   {{"^",      CARET,      Beginner}, Unary | Binary},/* 51 */
   {{"^:=",    AUGCARET,   0},        0},             /* 52 */
   {{"|",      BAR,        Beginner}, 0},             /* 53 */
   {{"||",     CONCAT,     Beginner}, Binary},        /* 54 */
   {{"||:=",   AUGCONCAT,  0},        0},             /* 55 */
   {{"|||",    LCONCAT,    Beginner}, Binary},        /* 56 */
   {{"|||:=",  AUGLCONCAT, 0},        0},             /* 57 */
   {{"~",      TILDE,      Beginner}, Unary},         /* 58 */
   {{"~=",     NMNE,       Beginner}, Binary},        /* 59 */
   {{"~=:=",   AUGNMNE,    0},        0},             /* 60 */
   {{"~==",    SNE,        Beginner}, Binary},        /* 61 */
   {{"~==:=",  AUGSNE,     0},        0},             /* 62 */
   {{"~===",   NEQUIV,     Beginner}, Binary},        /* 63 */
   {{"~===:=", AUGNEQUIV,  0},        0},             /* 64 */
   {{"(",      LPAREN,     Beginner}, 0},             /* 65 */
   {{")",      RPAREN,     Ender},    0},             /* 66 */
   {{"+:",     PCOLON,     0},        0},             /* 67 */
   {{",",      COMMA,      0},        0},             /* 68 */
   {{"-:",     MCOLON,     0},        0},             /* 69 */
   {{":",      COLON,      0},        0},             /* 70 */
   {{";",      SEMICOL,    0},        0},             /* 71 */
   {{"[",      LBRACK,     Beginner}, 0},             /* 72 */
   {{"]",      RBRACK,     Ender},    0},             /* 73 */
   {{"{",      LBRACE,     Beginner}, 0},             /* 74 */
   {{"}",      RBRACE,     Ender},    0},             /* 75 */
   {{"$(",     LBRACE,     Beginner}, 0},             /* 76 */
   {{"$)",     RBRACE,     Ender},    0},             /* 77 */
   {{"$<",     LBRACK,     Beginner}, 0},             /* 78 */
   {{"$>",     RBRACK,     Ender},    0},             /* 79 */
   {{NULL,          0,     0},        0}
   };

int asgn_loc = 20;
int semicol_loc = 71;
int plus_loc = 9;
int minus_loc = 13;

/*
 * getopr - find the longest legal operator and return the
 *  index to its entry in the operator table.
 */

int getopr(int ac, int *cc)
   {
   int c;

   *cc = ' ';
   switch (c = ac) {
      case '!':
         return 0;   /* ! */
      case '$':
         switch (c = NextChar) {
            case '(':
               return 76;   /* $( */
            case ')':
               return 77;   /* $) */
            case '<':
               return 78;   /* $< */
            case '>':
               return 79;   /* $> */
            }
         break;
      case '%':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 2;   /* %:= */
               }
            }
         else {
            *cc = c;
            return 1;   /* % */
            }
         break;
      case '&':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 4;   /* &:= */
               }
            }
         else {
            *cc = c;
            return 3;   /* & */
            }
         break;
      case '(':
         return 65;   /* ( */
      case ')':
         return 66;   /* ) */
      case '*':
         switch (c = NextChar) {
            case '*':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 8;   /* **:= */
                     }
                  }
               else {
                  *cc = c;
                  return 7;   /* ** */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 6;   /* *:= */
                  }
               break;
            default:
               *cc = c;
               return 5;   /* * */
            }
         break;
      case '+':
         switch (c = NextChar) {
            case '+':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 12;   /* ++:= */
                     }
                  }
               else {
                  *cc = c;
                  return 11;   /* ++ */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 10;   /* +:= */
                  }
               else {
                  *cc = c;
                  return 67;   /* +: */
                  }
            default:
               *cc = c;
               return 9;   /* + */
            }
         break;
      case ',':
         return 68;   /* , */
      case '-':
         switch (c = NextChar) {
            case '-':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 16;   /* --:= */
                     }
                  }
               else {
                  *cc = c;
                  return 15;   /* -- */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 14;   /* -:= */
                  }
               else {
                  *cc = c;
                  return 69;   /* -: */
                  }
            default:
               *cc = c;
               return 13;   /* - */
            }
         break;
      case '.':
         return 17;   /* . */
      case '/':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 19;   /* /:= */
               }
            }
         else {
            *cc = c;
            return 18;   /* / */
            }
         break;
      case ':':
         if ((c = NextChar) == '=') {
            if ((c = NextChar) == ':') {
               return 21;   /* :=: */
               }
            else {
               *cc = c;
               return 20;   /* := */
               }
            }
         else {
            *cc = c;
            return 70;   /* : */
            }
      case ';':
         return 71;   /* ; */
      case '<':
         switch (c = NextChar) {
            case '-':
               if ((c = NextChar) == '>') {
                  return 25;   /* <-> */
                  }
               else {
                  *cc = c;
                  return 24;   /* <- */
                  }
            case ':':
               if ((c = NextChar) == '=') {
                  return 23;   /* <:= */
                  }
               break;
            case '<':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 27;   /* <<:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 29;   /* <<=:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 28;   /* <<= */
                        }
                     break;
                  default:
                     *cc = c;
                     return 26;   /* << */
                  }
               break;
            case '=':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 31;   /* <=:= */
                     }
                  }
               else {
                  *cc = c;
                  return 30;   /* <= */
                  }
               break;
            default:
               *cc = c;
               return 22;   /* < */
            }
         break;
      case '=':
         switch (c = NextChar) {
            case ':':
               if ((c = NextChar) == '=') {
                  return 33;   /* =:= */
                  }
               break;
            case '=':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 35;   /* ==:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 37;   /* ===:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 36;   /* === */
                        }
                     break;
                  default:
                     *cc = c;
                     return 34;   /* == */
                  }
               break;
            default:
               *cc = c;
               return 32;   /* = */
            }
         break;
      case '>':
         switch (c = NextChar) {
            case ':':
               if ((c = NextChar) == '=') {
                  return 39;   /* >:= */
                  }
               break;
            case '=':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 41;   /* >=:= */
                     }
                  }
               else {
                  *cc = c;
                  return 40;   /* >= */
                  }
               break;
            case '>':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 43;   /* >>:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 45;   /* >>=:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 44;   /* >>= */
                        }
                     break;
                  default:
                     *cc = c;
                     return 42;   /* >> */
                  }
               break;
            default:
               *cc = c;
               return 38;   /* > */
            }
         break;
      case '?':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 47;   /* ?:= */
               }
            }
         else {
            *cc = c;
            return 46;   /* ? */
            }
         break;
      case '@':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 49;   /* @:= */
               }
            }
         else {
            *cc = c;
            return 48;   /* @ */
            }
         break;
      case '[':
         return 72;   /* [ */
      case '\\':
         return 50;   /* \ */
      case ']':
         return 73;   /* ] */
      case '^':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 52;   /* ^:= */
               }
            }
         else {
            *cc = c;
            return 51;   /* ^ */
            }
         break;
      case '{':
         return 74;   /* { */
      case '|':
         if ((c = NextChar) == '|') {
            switch (c = NextChar) {
               case ':':
                  if ((c = NextChar) == '=') {
                     return 55;   /* ||:= */
                     }
                  break;
               case '|':
                  if ((c = NextChar) == ':') {
                     if ((c = NextChar) == '=') {
                        return 57;   /* |||:= */
                        }
                     }
                  else {
                     *cc = c;
                     return 56;   /* ||| */
                     }
                  break;
               default:
                  *cc = c;
                  return 54;   /* || */
               }
            }
         else {
            *cc = c;
            return 53;   /* | */
            }
         break;
      case '}':
         return 75;   /* } */
      case '~':
         if ((c = NextChar) == '=') {
            switch (c = NextChar) {
               case ':':
                  if ((c = NextChar) == '=') {
                     return 60;   /* ~=:= */
                     }
                  break;
               case '=':
                  switch (c = NextChar) {
                     case ':':
                        if ((c = NextChar) == '=') {
                           return 62;   /* ~==:= */
                           }
                        break;
                     case '=':
                        if ((c = NextChar) == ':') {
                           if ((c = NextChar) == '=') {
                              return 64;   /* ~===:= */
                              }
                           }
                        else {
                           *cc = c;
                           return 63;   /* ~=== */
                           }
                        break;
                     default:
                        *cc = c;
                        return 61;   /* ~== */
                     }
                  break;
               default:
                  *cc = c;
                  return 59;   /* ~= */
               }
            }
         else {
            *cc = c;
            return 58;   /* ~ */
            }
         break;
      }
   lexfatal("invalid character");
   return -1;
   }
