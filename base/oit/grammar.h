/*
 * grammar.h -- Yacc grammar for Object Icon
 *
 */

program	: decls EOFX {Progend($1,$2);} ;

decls   : packagedecl importdecls bodydecls ;

packagedecl : ;
        | package ;

importdecls : ;
        | importdecls import ;

bodydecls : ;	
	| bodydecls body ;

body :    invocable ;
        | optpackage body1 ;

optpackage : {OptPackage0();} ;
        | PACKAGE {OptPackage1();} ;

optreadable : {OptReadable0();} ;
        | READABLE {OptReadable1();} ;

body1    : record ;
        | class ;
	| proc ;
	| global ;

optsemi : ;
        | SEMICOL ;

rdottedident : IDENT ;
        | rdottedident DOT IDENT {Dottedident($1,$2,$3);} ;

dottedident : DEFAULT DOT IDENT {Toplevelident($1,$2,$3);} ;
        | rdottedident ;

package : PACKAGE rdottedident {Package($1,$2);} ;

invocable : INVOCABLE invoclist {Invocable($1, $2);} ;

invoclist : invocop;
	  | invoclist COMMA invocop {Invoclist($1,$2,$3);} ;

invocop  : dottedident {Invocop1($1);} ;
	 | STRINGLIT {Invocop2($1);} ;
         | DOT IDENT {Invocop3($1,$2);} ;

import  : IMPORT importlist ;

importlist : importspec;
        | importlist COMMA importspec;

importspec : rdottedident {Importspec1($1); };
        |  rdottedident {Importspec2($1);} LPAREN eidlist RPAREN;
        |  rdottedident MINUS {Importspec3($1);} LPAREN eidlist RPAREN;

class   : {Modifier0();} classaccess CLASS IDENT {Class1($3,$4);} LPAREN supers RPAREN classbody END ;

supers  : ;
        | superlist;

superlist : dottedident { Super($1); } ;
        | superlist COMMA dottedident { Super($3); } ;

classbody : ;
        | classbody { Classbody0();} fieldaccess fielddecl ;

fielddecl : idlist { Fielddecl1($1); } ;
        | method ;
        | deferredmethod ;

method :  IDENT { Method1($1);} LPAREN arglist RPAREN locals initial optsemi compound END
                   { Method2($1,$7,$9,$10); } ;

deferredmethod : deferredtype IDENT { Method1($2);} LPAREN arglist RPAREN ;

deferredtype : OPTIONAL { Modifier9(); };
        | ABSTRACT { Modifier10();};
        | NATIVE { Modifier11();};

classaccess : classaccess1 ;
        | classaccess classaccess1 ;

classaccess1 : ;
        | FINAL {Modifier8();};
        | PROTECTED {Modifier3();};
        | ABSTRACT {Modifier10();};

fieldaccess : fieldaccess1 ;
        | fieldaccess fieldaccess1 ;

fieldaccess1 : PRIVATE {Modifier1();};
        | PUBLIC {Modifier2();};
        | PROTECTED {Modifier3();};
        | PACKAGE {Modifier4();};
        | STATIC {Modifier5();};
        | CONST {Modifier6();};
        | READABLE {Modifier7();};
        | FINAL {Modifier8();};
        | OVERRIDE {Modifier12();};

global	: optreadable GLOBAL {Global0($2);} idlist  {Global1($1,$2,$3,$4);} ;

record	: RECORD IDENT {Record1($1,$2);} LPAREN eidlist RPAREN {
		Record2($1,$2,$3,$4,$5,$6);
		} ;

eidlist	: ;
	| idlist ;

proc	: PROCEDURE IDENT {Proc1($1,$2);} LPAREN arglist RPAREN locals initial optsemi compound END {
                Proc2($2,$8,$10,$11);
		} ;

arglist	: {Arglist1();} ;
	| idlist {Arglist2($1);} ;
	| idlist LBRACK RBRACK {Arglist3($1,$2,$3);} ;


idlist	: IDENT { Ident($1);} ;
	| idlist COMMA IDENT {Idlist($1,$2,$3);} ;

locals	: {Locals1();} ;
	| locals retention idlist {Locals2($1,$2,$3);} ;

retention: LOCAL {Local($1);} ;
	| STATIC {Static($1);} ;

initial	: {Initial1();} ;
	| INITIAL expr {Initial2($1,$2);} ;

nexpr	: {Nexpr();} ;
	| expr ;

expr	: expr1a ;
	| expr AND expr1a	{Bamper($1,$2,$3);} ;

expr1a	: expr1 ;
	| expr1a QMARK expr1	{Bques($1,$2,$3);} ;

expr1	: expr2 ;
	| expr2 SWAP expr1 {Bswap($1,$2,$3);} ;
	| expr2 ASSIGN expr1 {Bassgn($1,$2,$3);} ;
	| expr2 REVSWAP expr1 {Brswap($1,$2,$3);} ;
	| expr2 REVASSIGN expr1 {Brassgn($1,$2,$3);} ;
	| expr2 AUGCONCAT expr1 {Baugcat($1,$2,$3);} ;
	| expr2 AUGLCONCAT expr1 {Bauglcat($1,$2,$3);} ;
	| expr2 AUGDIFF expr1 {Bdiffa($1,$2,$3);} ;
	| expr2 AUGUNION expr1 {Buniona($1,$2,$3);} ;
	| expr2 AUGPLUS expr1 {Bplusa($1,$2,$3);} ;
	| expr2 AUGMINUS expr1 {Bminusa($1,$2,$3);} ;
	| expr2 AUGSTAR expr1 {Bstara($1,$2,$3);} ;
	| expr2 AUGINTER expr1 {Bintera($1,$2,$3);} ;
	| expr2 AUGSLASH expr1 {Bslasha($1,$2,$3);} ;
	| expr2 AUGMOD expr1 {Bmoda($1,$2,$3);} ;
	| expr2 AUGCARET expr1 {Bcareta($1,$2,$3);} ;
	| expr2 AUGNMEQ expr1 {Baugeq($1,$2,$3);} ;
	| expr2 AUGEQUIV expr1 {Baugeqv($1,$2,$3);} ;
	| expr2 AUGNMGE expr1 {Baugge($1,$2,$3);} ;
	| expr2 AUGNMGT expr1 {Bauggt($1,$2,$3);} ;
	| expr2 AUGNMLE expr1 {Baugle($1,$2,$3);} ;
	| expr2 AUGNMLT expr1 {Bauglt($1,$2,$3);} ;
	| expr2 AUGNMNE expr1 {Baugne($1,$2,$3);} ;
	| expr2 AUGNEQUIV expr1 {Baugneqv($1,$2,$3);} ;
	| expr2 AUGSEQ expr1 {Baugseq($1,$2,$3);} ;
	| expr2 AUGSGE expr1 {Baugsge($1,$2,$3);} ;
	| expr2 AUGSGT expr1 {Baugsgt($1,$2,$3);} ;
	| expr2 AUGSLE expr1 {Baugsle($1,$2,$3);} ;
	| expr2 AUGSLT expr1 {Baugslt($1,$2,$3);} ;
	| expr2 AUGSNE expr1 {Baugsne($1,$2,$3);} ;
	| expr2 AUGQMARK expr1 {Baugques($1,$2,$3);} ;
	| expr2 AUGBANG expr1 {Baugbang($1,$2,$3);} ;
	| expr2 AUGAND expr1 {Baugamper($1,$2,$3);} ;
	| expr2 AUGAT expr1 {Baugact($1,$2,$3);} ;

expr2	: expr3 ;
	| expr2 TO expr3 {To0($1,$2,$3);} ;
	| expr2 TO expr3 BY expr3 {To1($1,$2,$3,$4,$5);} ;

expr3	: expr4 ;
	| expr4 BAR expr3 {Alt($1,$2,$3);} ;

expr4	: expr5 ;
	| expr4 SEQ expr5 {Bseq($1,$2,$3);} ;
	| expr4 SGE expr5 {Bsge($1,$2,$3);} ;
	| expr4 SGT expr5 {Bsgt($1,$2,$3);} ;
	| expr4 SLE expr5 {Bsle($1,$2,$3);} ;
	| expr4 SLT expr5 {Bslt($1,$2,$3);} ;
	| expr4 SNE expr5 {Bsne($1,$2,$3);} ;
	| expr4 NMEQ expr5 {Beq($1,$2,$3);} ;
	| expr4 NMGE expr5 {Bge($1,$2,$3);} ;
	| expr4 NMGT expr5 {Bgt($1,$2,$3);} ;
	| expr4 NMLE expr5 {Ble($1,$2,$3);} ;
	| expr4 NMLT expr5 {Blt($1,$2,$3);} ;
	| expr4 NMNE expr5 {Bne($1,$2,$3);} ;
	| expr4 EQUIV expr5 {Beqv($1,$2,$3);} ;
	| expr4 NEQUIV expr5 {Bneqv($1,$2,$3);} ;

expr5	: expr6 ;
	| expr5 CONCAT expr6 {Bcat($1,$2,$3);} ;
	| expr5 LCONCAT expr6 {Blcat($1,$2,$3);} ;

expr6	: expr7 ;
	| expr6 PLUS expr7 {Bplus($1,$2,$3);} ;
	| expr6 DIFF expr7 {Bdiff($1,$2,$3);} ;
	| expr6 UNION expr7 {Bunion($1,$2,$3);} ;
	| expr6 MINUS expr7 {Bminus($1,$2,$3);} ;

expr7	: expr8 ;
	| expr7 STAR expr8 {Bstar($1,$2,$3);} ;
	| expr7 INTER expr8 {Binter($1,$2,$3);} ;
	| expr7 SLASH expr8 {Bslash($1,$2,$3);} ;
	| expr7 MOD expr8 {Bmod($1,$2,$3);} ;

expr8	: expr9 ;
	| expr9 CARET expr8 {Bcaret($1,$2,$3);} ;

expr9	: expr10 ;
	| expr9 BACKSLASH expr10 {Blim($1,$2,$3);} ;
	| expr9 AT expr10 {Bact($1,$2,$3);};
	| expr9 BANG expr10 {Apply($1,$2,$3);};

expr10	: expr11 ;
	| AT expr10 {Uat($1,$2);} ;
	| NOT expr10 {Unot($1,$2);} ;
	| BAR expr10 {Ubar($1,$2);} ;
	| CONCAT expr10 {Uconcat($1,$2);} ;
	| LCONCAT expr10 {Ulconcat($1,$2);} ;
	| DOT expr10 {Udot($1,$2);} ;
	| BANG expr10 {Ubang($1,$2);} ;
	| DIFF expr10 {Udiff($1,$2);} ;
	| PLUS expr10 {Uplus($1,$2);} ;
	| STAR expr10 {Ustar($1,$2);} ;
	| SLASH expr10 {Uslash($1,$2);} ;
	| CARET expr10 {Ucaret($1,$2);} ;
	| INTER expr10 {Uinter($1,$2);} ;
	| TILDE expr10 {Utilde($1,$2);} ;
	| MINUS expr10 {Uminus($1,$2);} ;
	| NMEQ expr10 {Unumeq($1,$2);} ;
	| NMNE expr10 {Unumne($1,$2);} ;
	| SEQ expr10 {Ulexeq($1,$2);} ;
	| SNE expr10 {Ulexne($1,$2);} ;
	| EQUIV expr10 {Uequiv($1,$2);} ;
	| UNION expr10 {Uunion($1,$2);} ;
	| QMARK expr10 {Uqmark($1,$2);} ;
	| NEQUIV expr10 {Unotequiv($1,$2);} ;
	| BACKSLASH expr10 {Ubackslash($1,$2);} ;

expr11	: literal ;
	| section ;
	| return ;
	| if ;
	| case ;
	| while ;
	| until ;
        | dottedident {Dottedidentexpr($1);} ;
	| every ;
	| repeat ;
	| CREATE expr {Create($1,$2);} ;
	| NEXT {Next($1);} ;
	| BREAK {Break0($1);} ;
	| BREAK expr {Break1($1,$2);} ;
	| LPAREN exprlist RPAREN {Paren($1,$2,$3);} ;
	| LBRACE compound RBRACE {Brace($1,$2,$3);} ;
	| LBRACK exprlist RBRACK {Brack($1,$2,$3);} ;
	| expr11 LBRACK exprlist RBRACK {Subscript($1,$2,$3,$4);} ;
	| expr11 LBRACE exprlist RBRACE {CoInvoke($1,$2,$3,$4);} ;
	| expr11 LPAREN exprlist RPAREN {Invoke($1,$2,$3,$4);} ;
	| expr11 DOT IDENT {Field($1,$2,$3);} ;
	| AND FAIL {Kfail($1,$2);} ;
	| AND BREAK {Kbreak($1,$2);} ;
	| AND IDENT {Keyword($1,$2);} ;

while	: WHILE expr {While0($1,$2);} ;
	| WHILE expr DO expr {While1($1,$2,$3,$4);} ;

until	: UNTIL expr {Until0($1,$2);} ;
	| UNTIL expr DO expr {Until1($1,$2,$3,$4);} ;

every	: EVERY expr {Every0($1,$2);} ;
	| EVERY expr DO expr {Every1($1,$2,$3,$4);} ;

repeat	: REPEAT expr {Repeat($1,$2);} ;

return	: FAIL {Fail($1);} ;
	| RETURN {Return0($1);} ;
	| RETURN expr {Return1($1,$2);} ;
	| SUSPEND {Suspend0($1);} ;
	| SUSPEND expr {Suspend1($1,$2);} ;
        | SUSPEND expr DO expr {Suspend2($1,$2,$3,$4);};
	| SUCCEED {Succeed0($1);} ;
	| SUCCEED expr {Succeed1($1,$2);} ;
	| LINK {Link0($1);} ;
	| LINK expr {Link1($1,$2);} ;

if	: IF expr THEN expr {If0($1,$2,$3,$4);} ;
	| IF expr THEN expr ELSE expr {If1($1,$2,$3,$4,$5,$6);} ;
	| UNLESS expr THEN expr {Unless0($1,$2,$3,$4);} ;
	| UNLESS expr THEN expr ELSE expr {Unless1($1,$2,$3,$4,$5,$6);} ;

case	: CASE expr OF LBRACE caselist RBRACE {Case($1,$2,$3,$4,$5,$6);} ;

caselist: cclause ;
	| caselist SEMICOL cclause {Caselist($1,$2,$3);} ;

cclause	: DEFAULT COLON expr {Cclause0($1,$2,$3);} ;
	| expr COLON expr {Cclause1($1,$2,$3);} ;

exprlist: nexpr                {Elst0($1);}
	| exprlist COMMA nexpr {Elst1($1,$2,$3);} ;

literal	: INTLIT {Iliter($1);} ;
	| REALLIT {Rliter($1);} ;
	| STRINGLIT {Sliter($1);} ;
	| CSETLIT {Cliter($1);} ;
	| UCSLIT {Uliter($1);} ;

section	: expr11 LBRACK expr sectop expr RBRACK {Section($1,$2,$3,$4,$5,$6);} ;

sectop	: COLON {Colon($1);} ;
	| PCOLON {Pcolon($1);} ;
	| MCOLON {Mcolon($1);} ;

compound: nexpr ;
	| nexpr SEMICOL compound {Compound($1,$2,$3);} ;

program	: error decls EOFX ;
proc	: PROCEDURE error compound END ;
expr	: error ;
