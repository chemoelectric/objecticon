
/* primitive tokens */

%token	IDENT
%token	INTLIT
%token	REALLIT
%token	STRINGLIT
%token	CSETLIT
%token	EOFX

/* reserved words */

%token	BREAK       /* break     */
%token	BY          /* by        */
%token	CASE        /* case      */
%token	CLASS       /* class     */
%token	CONST       /* const     */
%token	CREATE      /* create    */
%token	DEFAULT     /* default   */
%token	DEFER       /* defer     */
%token	DO          /* do        */
%token	ELSE        /* else      */
%token	END         /* end       */
%token	EVERY       /* every     */
%token	FAIL        /* fail      */
%token	FINAL       /* final     */
%token	GLOBAL      /* global    */
%token	IF          /* if        */
%token  IMPORT      /* import    */
%token	INITIAL     /* initial   */
%token	INVOCABLE   /* invocable */
%token	LINK        /* link      */
%token	LOCAL       /* local     */
%token	NEXT        /* next      */
%token	NOT         /* not       */
%token	OF          /* of        */
%token	PACKAGE     /* package   */
%token	PRIVATE     /* private   */
%token	PROCEDURE   /* procedure */
%token	PROTECTED   /* protected */
%token	PUBLIC      /* public    */
%token	READABLE    /* readable  */
%token	RECORD      /* record    */
%token	REPEAT      /* repeat    */
%token	RETURN      /* return    */
%token	STATIC      /* static    */
%token	SUSPEND     /* suspend   */
%token	THEN        /* then      */
%token	TO          /* to        */
%token	UNTIL       /* until     */
%token	WHILE       /* while     */

/* operators */

%token	BANG        /* !         */
%token	MOD         /* %         */
%token	AUGMOD      /* %:=       */
%token	AND         /* &         */
%token	AUGAND      /* &:=       */
%token	STAR        /* *         */
%token	AUGSTAR     /* *:=       */
%token	INTER       /* **        */
%token	AUGINTER    /* **:=      */
%token	PLUS        /* +         */
%token	AUGPLUS     /* +:=       */
%token	UNION       /* ++        */
%token	AUGUNION    /* ++:=      */
%token	MINUS       /* -         */
%token	AUGMINUS    /* -:=       */
%token	DIFF        /* --        */
%token	AUGDIFF     /* --:=      */
%token	DOT         /* .         */
%token	SLASH       /* /         */
%token	AUGSLASH    /* /:=       */
%token	ASSIGN      /* :=        */
%token	SWAP        /* :=:       */
%token	NMLT        /* <         */
%token	AUGNMLT     /* <:=       */
%token	REVASSIGN   /* <-        */
%token	REVSWAP     /* <->       */
%token	SLT         /* <<        */
%token	AUGSLT      /* <<:=      */
%token	SLE         /* <<=       */
%token	AUGSLE      /* <<=:=     */
%token	NMLE        /* <=        */
%token	AUGNMLE     /* <=:=      */
%token	NMEQ        /* =         */
%token	AUGNMEQ     /* =:=       */
%token	SEQ         /* ==        */
%token	AUGSEQ      /* ==:=      */
%token	EQUIV       /* ===       */
%token	AUGEQUIV    /* ===:=     */
%token	NMGT        /* >         */
%token	AUGNMGT     /* >:=       */
%token	NMGE        /* >=        */
%token	AUGNMGE     /* >=:=      */
%token	SGT         /* >>        */
%token	AUGSGT      /* >>:=      */
%token	SGE         /* >>=       */
%token	AUGSGE      /* >>=:=     */
%token	QMARK       /* ?         */
%token	AUGQMARK    /* ?:=       */
%token	AT          /* @         */
%token	AUGAT       /* @:=       */
%token	BACKSLASH   /* \         */
%token	CARET       /* ^         */
%token	AUGCARET    /* ^:=       */
%token	BAR         /* |         */
%token	CONCAT      /* ||        */
%token	AUGCONCAT   /* ||:=      */
%token	LCONCAT     /* |||       */
%token	AUGLCONCAT  /* |||:=     */
%token	TILDE       /* ~         */
%token	NMNE        /* ~=        */
%token	AUGNMNE     /* ~=:=      */
%token	SNE         /* ~==       */
%token	AUGSNE      /* ~==:=     */
%token	NEQUIV      /* ~===      */
%token	AUGNEQUIV   /* ~===:=    */
%token	LPAREN      /* (         */
%token	RPAREN      /* )         */
%token	PCOLON      /* +:        */
%token	COMMA       /* ,         */
%token	MCOLON      /* -:        */
%token	COLON       /* :         */
%token	SEMICOL     /* ;         */
%token	LBRACK      /* [         */
%token	RBRACK      /* ]         */
%token	LBRACE      /* {         */
%token	RBRACE      /* }         */
%{

%}

%%

/*
 * igram.y -- iYacc grammar for Object Icon
 *
 */

program	: decls EOFX {$$ := Node("prog", $1,$2);} ;

decls	: { $$ := Node.EMPTY } ;
	| decls decl { $$ := Node("decls", $1, $2) } ;

decl	: record
        | class
	| proc
        | package
        | import
	| global
	| link
        | invocable
	;

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
	 | STRINGLIT COLON INTLIT {$$ := Node("invocop", $1,$2,$3);} ;

link	: LINK lnklist { $$ := Node("link", $1,$2) } ;

lnklist	: lnkfile ;
	| lnklist COMMA lnkfile { $$ := Node("lnklist", $1,$2,$3); } ;

lnkfile	: IDENT ;
	| STRINGLIT ;

import  : IMPORT importlist {$$ := Node("import",$1,$2) } ;

importlist : importspec;
        | importlist COMMA importspec {$$ := Node("importlist",$1,$2,$3)};

importspec : rdottedident
        |  rdottedident LPAREN eidlist RPAREN {$$ := Node("importspec", $1,$2,$3,$4)} ;

class   : classaccess CLASS IDENT LPAREN supers RPAREN classbody optsemi END 
             {$$ := Node("class", $1,$2,$3,$4,$5,$6,$7,$8,$9)};

supers  :  { $$ := Node.EMPTY } ;
        | superlist;

superlist : dottedident
        | superlist COMMA dottedident { $$ := Node("super", $1,$2,$3) } ;

classbody :  { $$ := Node.EMPTY } ;
        | classbody fieldaccess fielddecl {$$ := Node("classbody", $1,$2,$3) } ;

fielddecl : idlist
        | method ;
        | deferredmethod ;

method : IDENT LPAREN arglist RPAREN locals initial optsemi procbody END
                   { $$ := Node("method", $1,$2,$3,$4,$5,$6,$7,$8,$9) } ;

deferredmethod : DEFER IDENT LPAREN arglist RPAREN
                   { $$ := Node("deferredmethod", $1,$2,$3,$4,$5) };

classaccess : { $$ := Node.EMPTY } ;
        | FINAL ;

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

global	: GLOBAL idlist { $$ := Node("global", $1,$2) } ;

record	: RECORD IDENT LPAREN eidlist RPAREN { $$ := Node("record", $1,$2,$3,$4,$5) } ;

eidlist	: { $$ := Node.EMPTY } ;
	| idlist ;

proc	: PROCEDURE IDENT LPAREN arglist RPAREN locals initial optsemi procbody END 
                        { $$ := Node("proc", $1,$2,$3,$4,$5,$6,$7,$8,$9,$10) } ;

arglist	: { $$ := Node.EMPTY } ;
	| idlist
	| idlist LBRACK RBRACK { $$ := Node("arglist", $1,$2,$3) } ;

idlist	: IDENT ;
	| idlist COMMA IDENT { $$ := Node("idlist", $1,$2,$3) } ;

locals	: { $$ := Node.EMPTY;} ;
	| locals retention idlist { $$ := Node("locals", $1,$2,$3);} ;

retention: LOCAL ;
	| STATIC ;

initial	: { $$ := Node.EMPTY } ;
	| INITIAL expr { $$ := Node("initial", $1, $2) } ;

procbody: { $$ := Node.EMPTY } ;
	| nexpr SEMICOL procbody { $$ := Node("procbody", $1,$2,$3);} ;

nexpr	: { $$ := Node.EMPTY } ;
	| expr ;

expr	: expr1a ;
	| expr AND expr1a	{ $$ := Node("and", $1,$2,$3) } ;

expr1a	: expr1 ;
	| expr1a QMARK expr1	{ $$ := Node("binques", $1,$2,$3);} ;

expr1	: expr2 ;
	| expr2 SWAP expr1      { $$ := Node("swap", $1,$2,$3);} ;
	| expr2 ASSIGN expr1    { $$ := Node("assign", $1,$2,$3);} ;
	| expr2 REVSWAP expr1   { $$ := Node("revswap", $1,$2,$3);} ;
	| expr2 REVASSIGN expr1 { $$ := Node("revasgn", $1,$2,$3);} ;
	| expr2 AUGCONCAT expr1 { $$ := Node("augcat", $1,$2,$3);} ;
	| expr2 AUGLCONCAT expr1 { $$ := Node("auglcat", $1,$2,$3);} ;
	| expr2 AUGDIFF expr1   { $$ := Node("Bdiffa", $1,$2,$3);} ;
	| expr2 AUGUNION expr1  { $$ := Node("Buniona", $1,$2,$3);} ;
	| expr2 AUGPLUS expr1   { $$ := Node("Bplusa", $1,$2,$3);} ;
	| expr2 AUGMINUS expr1  { $$ := Node("Bminusa", $1,$2,$3);} ;
	| expr2 AUGSTAR expr1   { $$ := Node("Bstara", $1,$2,$3);} ;
	| expr2 AUGINTER expr1  { $$ := Node("Bintera", $1,$2,$3);} ;
	| expr2 AUGSLASH expr1  { $$ := Node("Bslasha", $1,$2,$3);} ;
	| expr2 AUGMOD expr1    { $$ := Node("Bmoda", $1,$2,$3);} ;
	| expr2 AUGCARET expr1  { $$ := Node("Bcareta", $1,$2,$3);} ;
	| expr2 AUGNMEQ expr1   { $$ := Node("Baugeq", $1,$2,$3);} ;
	| expr2 AUGEQUIV expr1  { $$ := Node("Baugeqv", $1,$2,$3);} ;
	| expr2 AUGNMGE expr1   { $$ := Node("Baugge", $1,$2,$3);} ;
	| expr2 AUGNMGT expr1   { $$ := Node("Bauggt", $1,$2,$3);} ;
	| expr2 AUGNMLE expr1   { $$ := Node("Baugle", $1,$2,$3);} ;
	| expr2 AUGNMLT expr1   { $$ := Node("Bauglt", $1,$2,$3);} ;
	| expr2 AUGNMNE expr1   { $$ := Node("Baugne", $1,$2,$3);} ;
	| expr2 AUGNEQUIV expr1 { $$ := Node("Baugneqv", $1,$2,$3);} ;
	| expr2 AUGSEQ expr1    { $$ := Node("Baugseq", $1,$2,$3);} ;
	| expr2 AUGSGE expr1    { $$ := Node("Baugsge", $1,$2,$3);} ;
	| expr2 AUGSGT expr1    { $$ := Node("Baugsgt", $1,$2,$3);} ;
	| expr2 AUGSLE expr1    { $$ := Node("Baugsle", $1,$2,$3);} ;
	| expr2 AUGSLT expr1    { $$ := Node("Baugslt", $1,$2,$3);} ;
	| expr2 AUGSNE expr1    { $$ := Node("Baugsne", $1,$2,$3);} ;
	| expr2 AUGQMARK expr1  { $$ := Node("Baugques", $1,$2,$3);} ;
	| expr2 AUGAND expr1    { $$ := Node("Baugamper", $1,$2,$3);} ;
	| expr2 AUGAT expr1     { $$ := Node("Baugact", $1,$2,$3);} ;

expr2	: expr3 ;
	| expr2 TO expr3 { $$ := Node("to", $1,$2,$3);} ;
	| expr2 TO expr3 BY expr3 { $$ := Node("toby", $1,$2,$3,$4,$5);} ;

expr3	: expr4 ;
	| expr4 BAR expr3 {$$ := Node(BAR, $1,$2,$3);} ;

expr4	: expr5 ;
	| expr4 SEQ expr5 { $$ := Node("Bseq", $1,$2,$3);} ;
	| expr4 SGE expr5 { $$ := Node("Bsge", $1,$2,$3);} ;
	| expr4 SGT expr5 { $$ := Node("Bsgt", $1,$2,$3);} ;
	| expr4 SLE expr5 { $$ := Node("Bsle", $1,$2,$3);} ;
	| expr4 SLT expr5 { $$ := Node("Bslt", $1,$2,$3);} ;
	| expr4 SNE expr5 { $$ := Node("Bsne", $1,$2,$3);} ;
	| expr4 NMEQ expr5 { $$ := Node("Beq", $1,$2,$3);} ;
	| expr4 NMGE expr5 { $$ := Node("Bge", $1,$2,$3);} ;
	| expr4 NMGT expr5 { $$ := Node("Bgt", $1,$2,$3);} ;
	| expr4 NMLE expr5 { $$ := Node("Ble", $1,$2,$3);} ;
	| expr4 NMLT expr5 { $$ := Node("Blt", $1,$2,$3);} ;
	| expr4 NMNE expr5 { $$ := Node("Bne", $1,$2,$3);} ;
	| expr4 EQUIV expr5 { $$ := Node("Beqv", $1,$2,$3);} ;
	| expr4 NEQUIV expr5 { $$ := Node("Bneqv", $1,$2,$3);} ;

expr5	: expr6 ;
	| expr5 CONCAT expr6 { $$ := Node("Bcat", $1,$2,$3);} ;
	| expr5 LCONCAT expr6 { $$ := Node("Blcat", $1,$2,$3);} ;

expr6	: expr7 ;
	| expr6 PLUS expr7 { $$ := Node("Bplus", $1,$2,$3);} ;
	| expr6 DIFF expr7 { $$ := Node("Bdiff", $1,$2,$3);} ;
	| expr6 UNION expr7 { $$ := Node("Bunion", $1,$2,$3);} ;
	| expr6 MINUS expr7 { $$ := Node("Bminus", $1,$2,$3);} ;

expr7	: expr8 ;
	| expr7 STAR expr8 { $$ := Node("Bstar", $1,$2,$3);} ;
	| expr7 INTER expr8 { $$ := Node("Binter", $1,$2,$3);} ;
	| expr7 SLASH expr8 { $$ := Node("Bslash", $1,$2,$3);} ;
	| expr7 MOD expr8 { $$ := Node("Bmod", $1,$2,$3);} ;

expr8	: expr9 ;
	| expr9 CARET expr8 { $$ := Node("Bcaret", $1,$2,$3);} ;

expr9	: expr10 ;
	| expr9 BACKSLASH expr10 { $$ := Node("limit", $1,$2,$3);} ;
	| expr9 AT expr10 { $$ := Node("at", $1,$2,$3) };
	| expr9 BANG expr10 { $$ := Node("apply", $1,$2,$3);};

expr10	: expr11 ;
	| AT expr10 { $$ := Node("uat", $1,$2);} ;
	| NOT expr10 { $$ := Node("unot", $1,$2);} ;
	| BAR expr10 { $$ := Node("ubar", $1,$2);} ;
	| CONCAT expr10 { $$ := Node("uconcat", $1,$2);} ;
	| LCONCAT expr10 { $$ := Node("ulconcat", $1,$2);} ;
	| DOT expr10 { $$ := Node("udot", $1,$2);} ;
	| BANG expr10 { $$ := Node("ubang", $1,$2);} ;
	| DIFF expr10 { $$ := Node("udiff", $1,$2);} ;
	| PLUS expr10 { $$ := Node("uplus", $1,$2);} ;
	| STAR expr10 { $$ := Node("ustar", $1,$2);} ;
	| SLASH expr10 { $$ := Node("uslash", $1,$2);} ;
	| CARET expr10 { $$ := Node("ucaret", $1,$2);} ;
	| INTER expr10 { $$ := Node("uinter", $1,$2);} ;
	| TILDE expr10 { $$ := Node("utilde", $1,$2);} ;
	| MINUS expr10 { $$ := Node("uminus", $1,$2);} ;
	| NMEQ expr10 { $$ := Node("unumeq", $1,$2);} ;
	| NMNE expr10 { $$ := Node("unumne", $1,$2);} ;
	| SEQ expr10 { $$ := Node("ulexeq", $1,$2);} ;
	| SNE expr10 { $$ := Node("ulexne", $1,$2);} ;
	| EQUIV expr10 { $$ := Node("uequiv", $1,$2);} ;
	| UNION expr10 { $$ := Node("uunion", $1,$2);} ;
	| QMARK expr10 { $$ := Node("uqmark", $1,$2);} ;
	| NEQUIV expr10 { $$ := Node("unotequiv", $1,$2);} ;
	| BACKSLASH expr10 { $$ := Node("ubackslash", $1,$2);} ;

expr11	: literal ;
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
	| NEXT { $$ := Node("Next", $1);} ;
	| BREAK nexpr { $$ := Node("Break", $1,$2);} ;
	| LPAREN exprlist RPAREN { $$ := Node("Paren", $1,$2,$3);} ;
	| LBRACE compound RBRACE { $$ := Node("Brace", $1,$2,$3);} ;
	| LBRACK exprlist RBRACK { $$ := Node("Brack", $1,$2,$3);} ;
	| expr11 LBRACK exprlist RBRACK { $$ := Node("Subscript", $1,$2,$3,$4);} ;
	| expr11 LBRACE	RBRACE { $$ := Node("Pdco0", $1,$2,$3);} ;
	| expr11 LBRACE pdcolist RBRACE { $$ := Node("Pdco1", $1,$2,$3,$4);} ;
	| expr11 LPAREN exprlist RPAREN { $$ := Node("invoke", $1,$2,$3,$4);} ;
	| expr11 DOT IDENT { $$ := Node("field",$1,$2,$3);} ;
	| AND FAIL { $$ := Node("keyword",$1,$2);} ;
        | AND IDENT { $$ := Node("keyword",$1,$2);} ;

while	: WHILE expr { $$ := Node("While0", $1,$2);} ;
	| WHILE expr DO expr { $$ := Node("While1", $1,$2,$3,$4);} ;

until	: UNTIL expr { $$ := Node("until", $1,$2);} ;
	| UNTIL expr DO expr { $$ := Node("until1", $1,$2,$3,$4);} ;

every	: EVERY expr { $$ := Node("every", $1,$2);} ;
	| EVERY expr DO expr { $$ := Node("every1", $1,$2,$3,$4);} ;

repeat	: REPEAT expr { $$ := Node("repeat", $1,$2);} ;

return	: FAIL ;
	| RETURN nexpr { $$ := Node("return", $1, $2);} ;
	| SUSPEND nexpr { $$ := Node("Suspend0", $1,$2);} ;
        | SUSPEND expr DO expr { $$ := Node("Suspend1", $1,$2,$3,$4);};

if	: IF expr THEN expr { $$ := Node("If0", $1,$2,$3,$4);} ;
	| IF expr THEN expr ELSE expr { $$ := Node("If1", $1,$2,$3,$4,$5,$6);} ;

case	: CASE expr OF LBRACE caselist RBRACE { $$ := Node("Case", $1,$2,$3,$4,$5,$6);} ;

caselist: cclause ;
	| caselist SEMICOL cclause { $$ := Node("Caselist", $1,$2,$3);} ;

cclause	: DEFAULT COLON expr { $$ := Node("cclause0", $1,$2,$3);} ;
	| expr COLON expr { $$ := Node("cclause1", $1,$2,$3);} ;

exprlist: nexpr ;
	| exprlist COMMA nexpr { $$ := Node("exprlist", $1,$2,$3) } ;

pdcolist: nexpr ;
	| pdcolist COMMA nexpr { $$ := Node("pdcolist", $1,$2,$3); } ;

literal	: INTLIT ;
	| REALLIT ;
	| STRINGLIT ;
	| CSETLIT ;

section	: expr11 LBRACK expr sectop expr RBRACK { $$ := Node("section", $1,$2,$3,$4,$5,$6);} ;

sectop	: COLON ;
	| PCOLON ;
	| MCOLON ;

compound: nexpr ;
	| nexpr SEMICOL compound { $$ := Node("compound", $1,$2,$3);} ;

program	: error decls EOFX ;
proc	: PROCEDURE error procbody END { $$ := Node("error", $1,$3,$4); } ;
expr	: error { $$ := Node("error"); } ;

%%
