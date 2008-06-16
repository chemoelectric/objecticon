#ifndef _TLEX_H
#define _TLEX_H 1

int yylex();
void yyerror(char *msg);

extern struct str_buf lex_sbuf;

#endif
