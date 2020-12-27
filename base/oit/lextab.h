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
   { "abstract",         ABSTRACT,      0},                /*   7 */
   { "break",            BREAK,         Beginner+Ender},   /*   8 */
   { "by",               BY,            0},                /*   9 */
   { "case",             CASE,          Beginner},         /*  10 */
   { "class",            CLASS,         0},                /*  11 */
   { "const",            CONST,         0},                /*  12 */
   { "create",           CREATE,        Beginner},         /*  13 */
   { "default",          DEFAULT,       Beginner},         /*  14 */
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
   { "link",             LINK,          Beginner+Ender},   /*  26 */
   { "local",            LOCAL,         0},                /*  27 */
   { "native",           NATIVE,        0},                /*  28 */
   { "next",             NEXT,          Beginner+Ender},   /*  29 */
   { "not",              NOT,           Beginner},         /*  30 */
   { "of",               OF,            0},                /*  31 */
   { "optional",         OPTIONAL,      0},                /*  32 */
   { "override",         OVERRIDE,      0},                /*  33 */
   { "package",          PACKAGE,       0},                /*  34 */
   { "private",          PRIVATE,       0},                /*  35 */
   { "procedure",        PROCEDURE,     0},                /*  36 */
   { "protected",        PROTECTED,     0},                /*  37 */
   { "public",           PUBLIC,        0},                /*  38 */
   { "readable",         READABLE,      0},                /*  39 */
   { "record",           RECORD,        0},                /*  40 */
   { "repeat",           REPEAT,        Beginner},         /*  41 */
   { "return",           RETURN,        Beginner+Ender},   /*  42 */
   { "static",           STATIC,        0},                /*  43 */
   { "succeed",          SUCCEED,       Beginner+Ender},   /*  44 */
   { "suspend",          SUSPEND,       Beginner+Ender},   /*  45 */
   { "then",             THEN,          0},                /*  46 */
   { "to",               TO,            0},                /*  47 */
   { "unless",           UNLESS,        Beginner},         /*  48 */
   { "until",            UNTIL,         Beginner},         /*  49 */
   { "while",            WHILE,         Beginner},         /*  50 */
   { "end-of-file",      0,             0},
   };

/*
 * restab[c] points to the first reserved word in toktab which
 * begins with the letter c.
 */

struct toktab *restab[] = {
   &toktab[ 7], &toktab[ 8], &toktab[10], &toktab[14], /* 61-64 abcd */
   &toktab[16], &toktab[19], &toktab[21], NULL,        /* 65-68 efgh */
   &toktab[22], NULL,        NULL,        &toktab[26], /* 69-6C ijkl */
   NULL,        &toktab[28], &toktab[31], &toktab[34], /* 6D-70 mnop */
   NULL,        &toktab[39], &toktab[43], &toktab[46], /* 71-74 qrst */
   &toktab[48], NULL,        &toktab[50], NULL,        /* 75-78 uvwx */
   NULL,        NULL,                                  /* 79-7A yz */
   };

/*
 * The operator table acts to extend the token table, it
 *  indicates what implementations are expected from rtt,
 *  and it has pointers for the implementation information.
 */

struct optab optab[] = {
   {{"!",      BANG,       Beginner}, Unary},         /* 0 */
   {{"!:=",    AUGBANG,    0},        0},             /* 1 */
   {{"%",      MOD,        0},        Binary},        /* 2 */
   {{"%:=",    AUGMOD,     0},        0},             /* 3 */
   {{"&",      AND,        Beginner}, Binary},        /* 4 */
   {{"&:=",    AUGAND,     0},        0},             /* 5 */
   {{"*",      STAR,       Beginner}, Unary | Binary},/* 6 */
   {{"*:=",    AUGSTAR,    0},        0},             /* 7 */
   {{"**",     INTER,      Beginner}, Binary},        /* 8 */
   {{"**:=",   AUGINTER,   0},        0},             /* 9 */
   {{"+",      PLUS,       Beginner}, Unary | Binary},/* 10 */
   {{"+:=",    AUGPLUS,    0},        0},             /* 11 */
   {{"++",     UNION,      Beginner}, Binary},        /* 12 */
   {{"++:=",   AUGUNION,   0},        0},             /* 13 */
   {{"-",      MINUS,      Beginner}, Unary | Binary},/* 14 */
   {{"-:=",    AUGMINUS,   0},        0},             /* 15 */
   {{"--",     DIFF,       Beginner}, Binary},        /* 16 */
   {{"--:=",   AUGDIFF,    0},        0},             /* 17 */
   {{".",      DOT,        Beginner}, Unary},         /* 18 */
   {{"/",      SLASH,      Beginner}, Unary | Binary},/* 19 */
   {{"/:=",    AUGSLASH,   0},        0},             /* 20 */
   {{":=",     ASSIGN,     0},        Binary},        /* 21 */
   {{":=:",    SWAP,       0},        Binary},        /* 22 */
   {{"<",      NMLT,       0},        Binary},        /* 23 */
   {{"<:=",    AUGNMLT,    0},        0},             /* 24 */
   {{"<-",     REVASSIGN,  0},        Binary},        /* 25 */
   {{"<->",    REVSWAP,    0},        Binary},        /* 26 */
   {{"<<",     SLT,        0},        Binary},        /* 27 */
   {{"<<:=",   AUGSLT,     0},        0},             /* 28 */
   {{"<<=",    SLE,        0},        Binary},        /* 29 */
   {{"<<=:=",  AUGSLE,     0},        0},             /* 30 */
   {{"<=",     NMLE,       0},        Binary},        /* 31 */
   {{"<=:=",   AUGNMLE,    0},        0},             /* 32 */
   {{"=",      NMEQ,       Beginner}, Unary | Binary},/* 33 */
   {{"=:=",    AUGNMEQ,    0},        0},             /* 34 */
   {{"==",     SEQ,        Beginner}, Binary},        /* 35 */
   {{"==:=",   AUGSEQ,     0},        0},             /* 36 */
   {{"===",    EQUIV,      Beginner}, Binary},        /* 37 */
   {{"===:=",  AUGEQUIV,   0},        0},             /* 38 */
   {{">",      NMGT,       0},        Binary},        /* 39 */
   {{">:=",    AUGNMGT,    0},        0},             /* 40 */
   {{">=",     NMGE,       0},        Binary},        /* 41 */
   {{">=:=",   AUGNMGE,    0},        0},             /* 42 */
   {{">>",     SGT,        0},        Binary},        /* 43 */
   {{">>:=",   AUGSGT,     0},        0},             /* 44 */
   {{">>=",    SGE,        0},        Binary},        /* 45 */
   {{">>=:=",  AUGSGE,     0},        0},             /* 46 */
   {{"?",      QMARK,      Beginner}, Unary},         /* 47 */
   {{"?:=",    AUGQMARK,   0},        0},             /* 48 */
   {{"@",      AT,         Beginner}, 0},             /* 49 */
   {{"@:=",    AUGAT,      0},        0},             /* 50 */
   {{"\\",     BACKSLASH,  Beginner}, Unary},         /* 51 */
   {{"^",      CARET,      Beginner}, Unary | Binary},/* 52 */
   {{"^:=",    AUGCARET,   0},        0},             /* 53 */
   {{"|",      BAR,        Beginner}, 0},             /* 54 */
   {{"||",     CONCAT,     Beginner}, Binary},        /* 55 */
   {{"||:=",   AUGCONCAT,  0},        0},             /* 56 */
   {{"|||",    LCONCAT,    Beginner}, Binary},        /* 57 */
   {{"|||:=",  AUGLCONCAT, 0},        0},             /* 58 */
   {{"~",      TILDE,      Beginner}, Unary},         /* 59 */
   {{"~=",     NMNE,       Beginner}, Binary},        /* 60 */
   {{"~=:=",   AUGNMNE,    0},        0},             /* 61 */
   {{"~==",    SNE,        Beginner}, Binary},        /* 62 */
   {{"~==:=",  AUGSNE,     0},        0},             /* 63 */
   {{"~===",   NEQUIV,     Beginner}, Binary},        /* 64 */
   {{"~===:=", AUGNEQUIV,  0},        0},             /* 65 */
   {{"(",      LPAREN,     Beginner}, 0},             /* 66 */
   {{")",      RPAREN,     Ender},    0},             /* 67 */
   {{"+:",     PCOLON,     0},        0},             /* 68 */
   {{",",      COMMA,      0},        0},             /* 69 */
   {{"-:",     MCOLON,     0},        0},             /* 70 */
   {{":",      COLON,      0},        0},             /* 71 */
   {{";",      SEMICOL,    0},        0},             /* 72 */
   {{"[",      LBRACK,     Beginner}, 0},             /* 73 */
   {{"]",      RBRACK,     Ender},    0},             /* 74 */
   {{"{",      LBRACE,     Beginner}, 0},             /* 75 */
   {{"}",      RBRACE,     Ender},    0},             /* 76 */
   {{"$(",     LBRACE,     Beginner}, 0},             /* 77 */
   {{"$)",     RBRACE,     Ender},    0},             /* 78 */
   {{"$<",     LBRACK,     Beginner}, 0},             /* 79 */
   {{"$>",     RBRACK,     Ender},    0},             /* 80 */
   {{NULL,          0,     0},        0}
   };

int asgn_loc = 21;
int semicol_loc = 72;
int plus_loc = 10;
int minus_loc = 14;

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
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 1;   /* !:= */
               }
            }
         else {
            *cc = c;
            return 0;   /* ! */
            }
         break;
      case '$':
         switch (c = NextChar) {
            case '(':
               return 77;   /* $( */
            case ')':
               return 78;   /* $) */
            case '<':
               return 79;   /* $< */
            case '>':
               return 80;   /* $> */
            }
         break;
      case '%':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 3;   /* %:= */
               }
            }
         else {
            *cc = c;
            return 2;   /* % */
            }
         break;
      case '&':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 5;   /* &:= */
               }
            }
         else {
            *cc = c;
            return 4;   /* & */
            }
         break;
      case '(':
         return 66;   /* ( */
      case ')':
         return 67;   /* ) */
      case '*':
         switch (c = NextChar) {
            case '*':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 9;   /* **:= */
                     }
                  }
               else {
                  *cc = c;
                  return 8;   /* ** */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 7;   /* *:= */
                  }
               break;
            default:
               *cc = c;
               return 6;   /* * */
            }
         break;
      case '+':
         switch (c = NextChar) {
            case '+':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 13;   /* ++:= */
                     }
                  }
               else {
                  *cc = c;
                  return 12;   /* ++ */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 11;   /* +:= */
                  }
               else {
                  *cc = c;
                  return 68;   /* +: */
                  }
            default:
               *cc = c;
               return 10;   /* + */
            }
         break;
      case ',':
         return 69;   /* , */
      case '-':
         switch (c = NextChar) {
            case '-':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 17;   /* --:= */
                     }
                  }
               else {
                  *cc = c;
                  return 16;   /* -- */
                  }
               break;
            case ':':
               if ((c = NextChar) == '=') {
                  return 15;   /* -:= */
                  }
               else {
                  *cc = c;
                  return 70;   /* -: */
                  }
            default:
               *cc = c;
               return 14;   /* - */
            }
         break;
      case '.':
         return 18;   /* . */
      case '/':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 20;   /* /:= */
               }
            }
         else {
            *cc = c;
            return 19;   /* / */
            }
         break;
      case ':':
         if ((c = NextChar) == '=') {
            if ((c = NextChar) == ':') {
               return 22;   /* :=: */
               }
            else {
               *cc = c;
               return 21;   /* := */
               }
            }
         else {
            *cc = c;
            return 71;   /* : */
            }
      case ';':
         return 72;   /* ; */
      case '<':
         switch (c = NextChar) {
            case '-':
               if ((c = NextChar) == '>') {
                  return 26;   /* <-> */
                  }
               else {
                  *cc = c;
                  return 25;   /* <- */
                  }
            case ':':
               if ((c = NextChar) == '=') {
                  return 24;   /* <:= */
                  }
               break;
            case '<':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 28;   /* <<:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 30;   /* <<=:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 29;   /* <<= */
                        }
                     break;
                  default:
                     *cc = c;
                     return 27;   /* << */
                  }
               break;
            case '=':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 32;   /* <=:= */
                     }
                  }
               else {
                  *cc = c;
                  return 31;   /* <= */
                  }
               break;
            default:
               *cc = c;
               return 23;   /* < */
            }
         break;
      case '=':
         switch (c = NextChar) {
            case ':':
               if ((c = NextChar) == '=') {
                  return 34;   /* =:= */
                  }
               break;
            case '=':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 36;   /* ==:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 38;   /* ===:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 37;   /* === */
                        }
                     break;
                  default:
                     *cc = c;
                     return 35;   /* == */
                  }
               break;
            default:
               *cc = c;
               return 33;   /* = */
            }
         break;
      case '>':
         switch (c = NextChar) {
            case ':':
               if ((c = NextChar) == '=') {
                  return 40;   /* >:= */
                  }
               break;
            case '=':
               if ((c = NextChar) == ':') {
                  if ((c = NextChar) == '=') {
                     return 42;   /* >=:= */
                     }
                  }
               else {
                  *cc = c;
                  return 41;   /* >= */
                  }
               break;
            case '>':
               switch (c = NextChar) {
                  case ':':
                     if ((c = NextChar) == '=') {
                        return 44;   /* >>:= */
                        }
                     break;
                  case '=':
                     if ((c = NextChar) == ':') {
                        if ((c = NextChar) == '=') {
                           return 46;   /* >>=:= */
                           }
                        }
                     else {
                        *cc = c;
                        return 45;   /* >>= */
                        }
                     break;
                  default:
                     *cc = c;
                     return 43;   /* >> */
                  }
               break;
            default:
               *cc = c;
               return 39;   /* > */
            }
         break;
      case '?':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 48;   /* ?:= */
               }
            }
         else {
            *cc = c;
            return 47;   /* ? */
            }
         break;
      case '@':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 50;   /* @:= */
               }
            }
         else {
            *cc = c;
            return 49;   /* @ */
            }
         break;
      case '[':
         return 73;   /* [ */
      case '\\':
         return 51;   /* \ */
      case ']':
         return 74;   /* ] */
      case '^':
         if ((c = NextChar) == ':') {
            if ((c = NextChar) == '=') {
               return 53;   /* ^:= */
               }
            }
         else {
            *cc = c;
            return 52;   /* ^ */
            }
         break;
      case '{':
         return 75;   /* { */
      case '|':
         if ((c = NextChar) == '|') {
            switch (c = NextChar) {
               case ':':
                  if ((c = NextChar) == '=') {
                     return 56;   /* ||:= */
                     }
                  break;
               case '|':
                  if ((c = NextChar) == ':') {
                     if ((c = NextChar) == '=') {
                        return 58;   /* |||:= */
                        }
                     }
                  else {
                     *cc = c;
                     return 57;   /* ||| */
                     }
                  break;
               default:
                  *cc = c;
                  return 55;   /* || */
               }
            }
         else {
            *cc = c;
            return 54;   /* | */
            }
         break;
      case '}':
         return 76;   /* } */
      case '~':
         if ((c = NextChar) == '=') {
            switch (c = NextChar) {
               case ':':
                  if ((c = NextChar) == '=') {
                     return 61;   /* ~=:= */
                     }
                  break;
               case '=':
                  switch (c = NextChar) {
                     case ':':
                        if ((c = NextChar) == '=') {
                           return 63;   /* ~==:= */
                           }
                        break;
                     case '=':
                        if ((c = NextChar) == ':') {
                           if ((c = NextChar) == '=') {
                              return 65;   /* ~===:= */
                              }
                           }
                        else {
                           *cc = c;
                           return 64;   /* ~=== */
                           }
                        break;
                     default:
                        *cc = c;
                        return 62;   /* ~== */
                     }
                  break;
               default:
                  *cc = c;
                  return 60;   /* ~= */
               }
            }
         else {
            *cc = c;
            return 59;   /* ~ */
            }
         break;
      }
   lexfatal("Invalid character");
   return -1;
   }
