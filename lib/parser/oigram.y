
/* primitive tokens */

%token  IDENT
%token  INTLIT
%token  REALLIT
%token  STRINGLIT
%token  CSETLIT
%token  UCSLIT
%token  EOFX

/* reserved words */

%token  ABSTRACT    /* abstract    */
%token  BREAK       /* break     */
%token  BY          /* by        */
%token  CASE        /* case      */
%token  CLASS       /* class     */
%token  CONST       /* const     */
%token  CREATE      /* create    */
%token  DEFAULT     /* default   */
%token  DO          /* do        */
%token  ELSE        /* else      */
%token  END         /* end       */
%token  EVERY       /* every     */
%token  FAIL        /* fail      */
%token  FINAL       /* final     */
%token  GLOBAL      /* global    */
%token  IF          /* if        */
%token  IMPORT      /* import    */
%token  INITIAL     /* initial   */
%token  INVOCABLE   /* invocable */
%token  LINK        /* link      */
%token  LOCAL       /* local     */
%token  NATIVE      /* native    */
%token  NEXT        /* next      */
%token  NOT         /* not       */
%token  OF          /* of        */
%token  OPTIONAL    /* optional  */
%token	OVERRIDE    /* override  */
%token  PACKAGE     /* package   */
%token  PRIVATE     /* private   */
%token  PROCEDURE   /* procedure */
%token  PROTECTED   /* protected */
%token  PUBLIC      /* public    */
%token  READABLE    /* readable  */
%token  RECORD      /* record    */
%token  REPEAT      /* repeat    */
%token  RETURN      /* return    */
%token  STATIC      /* static    */
%token	SUCCEED     /* succeed   */
%token  SUSPEND     /* suspend   */
%token  THEN        /* then      */
%token  TO          /* to        */
%token  UNLESS      /* unless    */
%token  UNTIL       /* until     */
%token  WHILE       /* while     */

/* operators */

%token  BANG        /* !         */
%token  AUGBANG     /* !:=       */
%token  MOD         /* %         */
%token  AUGMOD      /* %:=       */
%token  AND         /* &         */
%token  AUGAND      /* &:=       */
%token  STAR        /* *         */
%token  AUGSTAR     /* *:=       */
%token  INTER       /* **        */
%token  AUGINTER    /* **:=      */
%token  PLUS        /* +         */
%token  AUGPLUS     /* +:=       */
%token  UNION       /* ++        */
%token  AUGUNION    /* ++:=      */
%token  MINUS       /* -         */
%token  AUGMINUS    /* -:=       */
%token  DIFF        /* --        */
%token  AUGDIFF     /* --:=      */
%token  DOT         /* .         */
%token  SLASH       /* /         */
%token  AUGSLASH    /* /:=       */
%token  ASSIGN      /* :=        */
%token  SWAP        /* :=:       */
%token  NMLT        /* <         */
%token  AUGNMLT     /* <:=       */
%token  REVASSIGN   /* <-        */
%token  REVSWAP     /* <->       */
%token  SLT         /* <<        */
%token  AUGSLT      /* <<:=      */
%token  SLE         /* <<=       */
%token  AUGSLE      /* <<=:=     */
%token  NMLE        /* <=        */
%token  AUGNMLE     /* <=:=      */
%token  NMEQ        /* =         */
%token  AUGNMEQ     /* =:=       */
%token  SEQ         /* ==        */
%token  AUGSEQ      /* ==:=      */
%token  EQUIV       /* ===       */
%token  AUGEQUIV    /* ===:=     */
%token  NMGT        /* >         */
%token  AUGNMGT     /* >:=       */
%token  NMGE        /* >=        */
%token  AUGNMGE     /* >=:=      */
%token  SGT         /* >>        */
%token  AUGSGT      /* >>:=      */
%token  SGE         /* >>=       */
%token  AUGSGE      /* >>=:=     */
%token  QMARK       /* ?         */
%token  AUGQMARK    /* ?:=       */
%token  AT          /* @         */
%token  AUGAT       /* @:=       */
%token  BACKSLASH   /* \         */
%token  CARET       /* ^         */
%token  AUGCARET    /* ^:=       */
%token  BAR         /* |         */
%token  CONCAT      /* ||        */
%token  AUGCONCAT   /* ||:=      */
%token  LCONCAT     /* |||       */
%token  AUGLCONCAT  /* |||:=     */
%token  TILDE       /* ~         */
%token  NMNE        /* ~=        */
%token  AUGNMNE     /* ~=:=      */
%token  SNE         /* ~==       */
%token  AUGSNE      /* ~==:=     */
%token  NEQUIV      /* ~===      */
%token  AUGNEQUIV   /* ~===:=    */
%token  LPAREN      /* (         */
%token  RPAREN      /* )         */
%token  PCOLON      /* +:        */
%token  COMMA       /* ,         */
%token  MCOLON      /* -:        */
%token  COLON       /* :         */
%token  SEMICOL     /* ;         */
%token  LBRACK      /* [         */
%token  RBRACK      /* ]         */
%token  LBRACE      /* {         */
%token  RBRACE      /* }         */
%{

%}

%%

/*
 * igram.y -- iYacc grammar for Object Icon
 *
 */

program : decls EOFX {$$ := Node("prog", $1,$2);} ;

decls   : packagedecl importdecls bodydecls { $$ := Node("decls", $1, $2, $3); } ;

packagedecl : { $$ := Node.EMPTY } ;
        | package ;

importdecls : { $$ := Node.EMPTY } ;
        | importdecls import { $$ := Node("importdecls", $1, $2); } ;

bodydecls : { $$ := Node.EMPTY } ;
        | bodydecls body { $$ := Node("bodydecls", $1, $2); } ;

body :    invocable ;
        | optpackage body1 { $$ := Node("body", $1, $2) } ;

optpackage : { $$ := Node.EMPTY } ;
        | PACKAGE;

optreadable : { $$ := Node.EMPTY } ;
        | READABLE;

body1    : record ;
        | class ;
	| proc ;
	| global ;

optsemi : { $$ := Node.EMPTY } ; 
        | SEMICOL;

rdottedident : IDENT ;
        | rdottedident DOT IDENT {$$ := Node("dottedident", $1,$2,$3) }

dottedident : DEFAULT DOT IDENT {$$ := Node("dottedident",$1,$2,$3) }
        | rdottedident ;

package : PACKAGE rdottedident {$$ := Node("package",$1,$2) }

invocable : INVOCABLE invoclist { $$ := Node("invocable", $1, $2);} ;

invoclist : invocop;
          | invoclist COMMA invocop { $$ := Node("invoclist", $1,$2,$3);} ;

invocop  : dottedident ;
         | STRINGLIT ;
         | DOT IDENT { $$ := Node("dotident", $1,$2);} ;

import  : IMPORT importlist {$$ := Node("import",$1,$2) } ;

importlist : importspec;
        | importlist COMMA importspec {$$ := Node("importlist",$1,$2,$3)};

importspec : rdottedident
        |  rdottedident LPAREN eidlist RPAREN {$$ := Node("importspec", $1,$2,$3,$4)} ;
        |  rdottedident MINUS LPAREN eidlist RPAREN {$$ := Node("importspec", $1,$2,$3,$4,$5)} ;

class   : classaccess CLASS IDENT LPAREN supers RPAREN classbody END 
             {$$ := Node("class", $1,$2,$3,$4,$5,$6,$7,$8)};

supers  :  { $$ := Node.EMPTY } ;
        | superlist;

superlist : dottedident
        | superlist COMMA dottedident { $$ := Node("super", $1,$2,$3) } ;

classbody :  { $$ := Node.EMPTY } ;
        | classbody fieldaccess fielddecl {$$ := Node("classbody", $1,$2,$3) } ;

fielddecl : idlist
        | method ;
        | deferredmethod ;

method : IDENT LPAREN arglist RPAREN locals initial optsemi compound END
                   { $$ := Node("method", $1,$2,$3,$4,$5,$6,$7,$8,$9) } ;

deferredmethod : deferredtype IDENT LPAREN arglist RPAREN
                   { $$ := Node("deferredmethod", $1,$2,$3,$4,$5) };

deferredtype : OPTIONAL
        | ABSTRACT
        | NATIVE

classaccess : classaccess1 ;
        | classaccess classaccess1 { $$ := Node("classaccess", $1,$2) } ;

classaccess1 : { $$ := Node.EMPTY } ;
        | FINAL
        | ABSTRACT

fieldaccess : fieldaccess1 ;
        | fieldaccess fieldaccess1 { $$ := Node("fieldaccess", $1,$2) } ;

fieldaccess1 : PRIVATE
        | PUBLIC
        | PROTECTED
        | PACKAGE
        | STATIC
        | CONST
        | READABLE
        | FINAL
        | OVERRIDE

global  : optreadable GLOBAL idlist { $$ := Node("global", $1,$2,$3) } ;

record  : RECORD IDENT LPAREN eidlist RPAREN { $$ := Node("record", $1,$2,$3,$4,$5) } ;

eidlist : { $$ := Node.EMPTY } ;
        | idlist ;

proc    : PROCEDURE IDENT LPAREN arglist RPAREN locals initial optsemi compound END 
                        { $$ := Node("proc", $1,$2,$3,$4,$5,$6,$7,$8,$9,$10) } ;

arglist : { $$ := Node.EMPTY } ;
        | idlist
        | idlist LBRACK RBRACK { $$ := Node("arglist", $1,$2,$3) } ;

idlist  : IDENT ;
        | idlist COMMA IDENT { $$ := Node("idlist", $1,$2,$3) } ;

locals  : { $$ := Node.EMPTY;} ;
        | locals retention idlist { $$ := Node("locals", $1,$2,$3);} ;

retention: LOCAL ;
        | STATIC ;

initial : { $$ := Node.EMPTY } ;
        | INITIAL expr { $$ := Node("initial", $1, $2) } ;

nexpr   : { $$ := Node.EMPTY } ;
        | expr ;

expr    : expr1a ;
        | expr AND expr1a       { $$ := Node("and", $1,$2,$3) } ;

expr1a  : expr1 ;
        | expr1a QMARK expr1    { $$ := Node("Bqmark", $1,$2,$3);} ;

expr1   : expr2 ;
        | expr2 SWAP expr1      { $$ := Node("swap", $1,$2,$3);} ;
        | expr2 ASSIGN expr1    { $$ := Node("assign", $1,$2,$3);} ;
        | expr2 REVSWAP expr1   { $$ := Node("revswap", $1,$2,$3);} ;
        | expr2 REVASSIGN expr1 { $$ := Node("revassign", $1,$2,$3);} ;
        | expr2 AUGCONCAT expr1 { $$ := Node("augconcat", $1,$2,$3);} ;
        | expr2 AUGLCONCAT expr1 { $$ := Node("auglconcat", $1,$2,$3);} ;
        | expr2 AUGDIFF expr1   { $$ := Node("augdiff", $1,$2,$3);} ;
        | expr2 AUGUNION expr1  { $$ := Node("augunion", $1,$2,$3);} ;
        | expr2 AUGPLUS expr1   { $$ := Node("augplus", $1,$2,$3);} ;
        | expr2 AUGMINUS expr1  { $$ := Node("augminus", $1,$2,$3);} ;
        | expr2 AUGSTAR expr1   { $$ := Node("augstar", $1,$2,$3);} ;
        | expr2 AUGINTER expr1  { $$ := Node("auginter", $1,$2,$3);} ;
        | expr2 AUGSLASH expr1  { $$ := Node("augslash", $1,$2,$3);} ;
        | expr2 AUGMOD expr1    { $$ := Node("augmod", $1,$2,$3);} ;
        | expr2 AUGCARET expr1  { $$ := Node("augcaret", $1,$2,$3);} ;
        | expr2 AUGNMEQ expr1   { $$ := Node("augnmeq", $1,$2,$3);} ;
        | expr2 AUGEQUIV expr1  { $$ := Node("augequiv", $1,$2,$3);} ;
        | expr2 AUGNMGE expr1   { $$ := Node("augnmge", $1,$2,$3);} ;
        | expr2 AUGNMGT expr1   { $$ := Node("augnmgt", $1,$2,$3);} ;
        | expr2 AUGNMLE expr1   { $$ := Node("augnmle", $1,$2,$3);} ;
        | expr2 AUGNMLT expr1   { $$ := Node("augnmlt", $1,$2,$3);} ;
        | expr2 AUGNMNE expr1   { $$ := Node("augnmne", $1,$2,$3);} ;
        | expr2 AUGNEQUIV expr1 { $$ := Node("augnequiv", $1,$2,$3);} ;
        | expr2 AUGSEQ expr1    { $$ := Node("augseq", $1,$2,$3);} ;
        | expr2 AUGSGE expr1    { $$ := Node("augsge", $1,$2,$3);} ;
        | expr2 AUGSGT expr1    { $$ := Node("augsgt", $1,$2,$3);} ;
        | expr2 AUGSLE expr1    { $$ := Node("augsle", $1,$2,$3);} ;
        | expr2 AUGSLT expr1    { $$ := Node("augslt", $1,$2,$3);} ;
        | expr2 AUGSNE expr1    { $$ := Node("augsne", $1,$2,$3);} ;
        | expr2 AUGQMARK expr1  { $$ := Node("augqmark", $1,$2,$3);} ;
        | expr2 AUGBANG expr1  { $$ := Node("augbang", $1,$2,$3);} ;
        | expr2 AUGAND expr1    { $$ := Node("augand", $1,$2,$3);} ;
        | expr2 AUGAT expr1     { $$ := Node("augat", $1,$2,$3);} ;

expr2   : expr3 ;
        | expr2 TO expr3 { $$ := Node("to", $1,$2,$3);} ;
        | expr2 TO expr3 BY expr3 { $$ := Node("toby", $1,$2,$3,$4,$5);} ;

expr3   : expr4 ;
        | expr4 BAR expr3 {$$ := Node("Bbar", $1,$2,$3);} ;

expr4   : expr5 ;
        | expr4 SEQ expr5 { $$ := Node("Bseq", $1,$2,$3);} ;
        | expr4 SGE expr5 { $$ := Node("Bsge", $1,$2,$3);} ;
        | expr4 SGT expr5 { $$ := Node("Bsgt", $1,$2,$3);} ;
        | expr4 SLE expr5 { $$ := Node("Bsle", $1,$2,$3);} ;
        | expr4 SLT expr5 { $$ := Node("Bslt", $1,$2,$3);} ;
        | expr4 SNE expr5 { $$ := Node("Bsne", $1,$2,$3);} ;
        | expr4 NMEQ expr5 { $$ := Node("Bnmeq", $1,$2,$3);} ;
        | expr4 NMGE expr5 { $$ := Node("Bnmge", $1,$2,$3);} ;
        | expr4 NMGT expr5 { $$ := Node("Bnmgt", $1,$2,$3);} ;
        | expr4 NMLE expr5 { $$ := Node("Bnmle", $1,$2,$3);} ;
        | expr4 NMLT expr5 { $$ := Node("Bnmlt", $1,$2,$3);} ;
        | expr4 NMNE expr5 { $$ := Node("Bnmne", $1,$2,$3);} ;
        | expr4 EQUIV expr5 { $$ := Node("Bequiv", $1,$2,$3);} ;
        | expr4 NEQUIV expr5 { $$ := Node("Bnequiv", $1,$2,$3);} ;

expr5   : expr6 ;
        | expr5 CONCAT expr6 { $$ := Node("Bconcat", $1,$2,$3);} ;
        | expr5 LCONCAT expr6 { $$ := Node("Blconcat", $1,$2,$3);} ;

expr6   : expr7 ;
        | expr6 PLUS expr7 { $$ := Node("Bplus", $1,$2,$3);} ;
        | expr6 DIFF expr7 { $$ := Node("Bdiff", $1,$2,$3);} ;
        | expr6 UNION expr7 { $$ := Node("Bunion", $1,$2,$3);} ;
        | expr6 MINUS expr7 { $$ := Node("Bminus", $1,$2,$3);} ;

expr7   : expr8 ;
        | expr7 STAR expr8 { $$ := Node("Bstar", $1,$2,$3);} ;
        | expr7 INTER expr8 { $$ := Node("Binter", $1,$2,$3);} ;
        | expr7 SLASH expr8 { $$ := Node("Bslash", $1,$2,$3);} ;
        | expr7 MOD expr8 { $$ := Node("Bmod", $1,$2,$3);} ;

expr8   : expr9 ;
        | expr9 CARET expr8 { $$ := Node("Bcaret", $1,$2,$3);} ;

expr9   : expr10 ;
        | expr9 BACKSLASH expr10 { $$ := Node("Bbackslash", $1,$2,$3);} ;
        | expr9 AT expr10 { $$ := Node("Bat", $1,$2,$3) };
        | expr9 BANG expr10 { $$ := Node("Bbang", $1,$2,$3);};

expr10  : expr11 ;
        | AT expr10 { $$ := Node("Uat", $1,$2);} ;
        | NOT expr10 { $$ := Node("Unot", $1,$2);} ;
        | BAR expr10 { $$ := Node("Ubar", $1,$2);} ;
        | CONCAT expr10 { $$ := Node("Uconcat", $1,$2);} ;
        | LCONCAT expr10 { $$ := Node("Ulconcat", $1,$2);} ;
        | DOT expr10 { $$ := Node("Udot", $1,$2);} ;
        | BANG expr10 { $$ := Node("Ubang", $1,$2);} ;
        | DIFF expr10 { $$ := Node("Udiff", $1,$2);} ;
        | PLUS expr10 { $$ := Node("Uplus", $1,$2);} ;
        | STAR expr10 { $$ := Node("Ustar", $1,$2);} ;
        | SLASH expr10 { $$ := Node("Uslash", $1,$2);} ;
        | CARET expr10 { $$ := Node("Ucaret", $1,$2);} ;
        | INTER expr10 { $$ := Node("Uinter", $1,$2);} ;
        | TILDE expr10 { $$ := Node("Utilde", $1,$2);} ;
        | MINUS expr10 { $$ := Node("Uminus", $1,$2);} ;
        | NMEQ expr10 { $$ := Node("Unmeq", $1,$2);} ;
        | NMNE expr10 { $$ := Node("Unmne", $1,$2);} ;
        | SEQ expr10 { $$ := Node("Useq", $1,$2);} ;
        | SNE expr10 { $$ := Node("Usne", $1,$2);} ;
        | EQUIV expr10 { $$ := Node("Uequiv", $1,$2);} ;
        | UNION expr10 { $$ := Node("Uunion", $1,$2);} ;
        | QMARK expr10 { $$ := Node("Uqmark", $1,$2);} ;
        | NEQUIV expr10 { $$ := Node("Unequiv", $1,$2);} ;
        | BACKSLASH expr10 { $$ := Node("Ubackslash", $1,$2);} ;

expr11  : literal ;
        | section ;
        | return ;
        | if ;
        | case ;
        | while ;
        | until ;
        | dottedident ;
        | every ;
        | repeat ;
        | CREATE expr { $$ := Node("create", $1,$2);} ;
        | NEXT { $$ := Node("next", $1);} ;
        | BREAK { $$ := Node("break", $1);} ;
        | BREAK expr { $$ := Node("breakexpr", $1,$2);} ;
        | LPAREN exprlist RPAREN { $$ := Node("paren", $1,$2,$3);} ;
        | LBRACE compound RBRACE { $$ := Node("brace", $1,$2,$3);} ;
        | LBRACK exprlist RBRACK { $$ := Node("brack", $1,$2,$3);} ;
        | expr11 LBRACK exprlist RBRACK { $$ := Node("subscript", $1,$2,$3,$4);} ;
        | expr11 LBRACE exprlist RBRACE { $$ := Node("coinvoke", $1,$2,$3,$4);} ;
        | expr11 LPAREN exprlist RPAREN { $$ := Node("invoke", $1,$2,$3,$4);} ;
        | expr11 DOT IDENT { $$ := Node("field",$1,$2,$3);} ;
        | AND FAIL { $$ := Node("keyword",$1,$2);} ;
	| AND BREAK { $$ := Node("keyword",$1,$2);} ;
        | AND IDENT { $$ := Node("keyword",$1,$2);} ;

while   : WHILE expr { $$ := Node("while", $1,$2);} ;
        | WHILE expr DO expr { $$ := Node("whiledo", $1,$2,$3,$4);} ;

until   : UNTIL expr { $$ := Node("until", $1,$2);} ;
        | UNTIL expr DO expr { $$ := Node("untildo", $1,$2,$3,$4);} ;

every   : EVERY expr { $$ := Node("every", $1,$2);} ;
        | EVERY expr DO expr { $$ := Node("everydo", $1,$2,$3,$4);} ;

repeat  : REPEAT expr { $$ := Node("repeat", $1,$2);} ;

return  : FAIL { $$ := Node("fail", $1);} ;
        | RETURN { $$ := Node("return", $1);} ;
        | RETURN expr { $$ := Node("returnexpr", $1, $2);} ;
        | SUSPEND { $$ := Node("suspend", $1);} ;
        | SUSPEND expr { $$ := Node("suspendexpr", $1,$2);} ;
        | SUSPEND expr DO expr { $$ := Node("suspendexprdo", $1,$2,$3,$4);};
        | SUCCEED { $$ := Node("succeed", $1);} ;
        | SUCCEED expr { $$ := Node("succeedexpr", $1, $2);} ;
        | LINK { $$ := Node("link", $1);} ;
        | LINK expr { $$ := Node("linkexpr", $1, $2);} ;

if      : IF expr THEN expr { $$ := Node("if", $1,$2,$3,$4);} ;
        | IF expr THEN expr ELSE expr { $$ := Node("ifelse", $1,$2,$3,$4,$5,$6);} ;
        | UNLESS expr THEN expr { $$ := Node("unless", $1,$2,$3,$4);} ;
        | UNLESS expr THEN expr ELSE expr { $$ := Node("unlesselse", $1,$2,$3,$4,$5,$6);} ;

case    : CASE expr OF LBRACE caselist RBRACE { $$ := Node("case", $1,$2,$3,$4,$5,$6);} ;

caselist: cclause ;
        | caselist SEMICOL cclause { $$ := Node("caselist", $1,$2,$3);} ;

cclause : DEFAULT COLON expr { $$ := Node("defaultcclause", $1,$2,$3);} ;
        | expr COLON expr { $$ := Node("cclause", $1,$2,$3);} ;

exprlist: nexpr ;
        | exprlist COMMA nexpr { $$ := Node("exprlist", $1,$2,$3) } ;

literal : INTLIT ;
        | REALLIT ;
        | STRINGLIT ;
        | CSETLIT ;
        | UCSLIT ;

section : expr11 LBRACK expr sectop expr RBRACK { $$ := Node("section", $1,$2,$3,$4,$5,$6);} ;

sectop  : COLON ;
        | PCOLON ;
        | MCOLON ;

compound: nexpr ;
        | nexpr SEMICOL compound { $$ := Node("compound", $1,$2,$3);} ;

program : error decls EOFX ;
proc    : PROCEDURE error compound END { $$ := Node("error", $1,$3,$4); } ;
expr    : error { $$ := Node("error"); } ;

%%
