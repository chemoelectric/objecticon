/*
 * NOTE: these %token declarations are generated
 *  automatically by mktoktab from tokens.txt and 
 *  op.txt.
 */

/* primitive tokens */

%token	IDENT
%token	INTLIT
%token	REALLIT
%token	STRINGLIT
%token	CSETLIT
%token	UCSLIT
%token	EOFX

/* reserved words */

%token	ABSTRACT    /* abstract  */
%token	BREAK       /* break     */
%token	BY          /* by        */
%token	CASE        /* case      */
%token	CLASS       /* class     */
%token	CONST       /* const     */
%token	CREATE      /* create    */
%token	DEFAULT     /* default   */
%token	DO          /* do        */
%token	ELSE        /* else      */
%token	END         /* end       */
%token	EVERY       /* every     */
%token	FAIL        /* fail      */
%token	FINAL       /* final     */
%token	GLOBAL      /* global    */
%token	IF          /* if        */
%token	IMPORT      /* import    */
%token	INITIAL     /* initial   */
%token	INVOCABLE   /* invocable */
%token	LOCAL       /* local     */
%token	NATIVE      /* native    */
%token	NEXT        /* next      */
%token	NOT         /* not       */
%token	OF          /* of        */
%token	OPTIONAL    /* optional  */
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
%token	AUGBANG     /* !:=       */
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
