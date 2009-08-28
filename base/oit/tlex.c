/*
 * tlex.c -- the lexical analyzer for icont.
 */

#include "icont.h"
#include "ttoken.h"
#include "tsym.h"
#include "tmem.h"
#include "tree.h"
#include "tmain.h"
#include "trans.h"

/* Used by auto-generated func in ../common/lextab.h */
static  int nextchar();

#include "lexdef.h"
#include "lextab.h"
#include "../h/esctab.h"

/*
 * Prototypes.
 */

static  int             bufcmp          (char *s);
static	struct toktab   *findres	(void);
static	struct toktab   *getident	(int ac,int *cc);
static	struct toktab   *getnum		(int ac,int *cc);
static	struct toktab   *getstring	(int ac,int *cc);
static	struct toktab   *getucs     	(int ac,int *cc);
static	struct toktab   *getcset	(int ac,int *cc);
static	int		setfilenm	(int c);
static	int		setlineno	(void);
static	int	ctlesc		(void);
static	int	hexesc		(int digs);
static	int	octesc		(int ac);
static  int     read_utf_char(int c);

#define isletter(c)	(isupper(c) | islower(c))
#define tonum(c)        (isdigit(c) ? (c - '0') : ((c & 037) + 9))

struct node tok_loc =
{0, NULL, 0, 0};	/* "model" node containing location of current token */

static struct str_buf lex_sbuf;	/* string buffer for lexical analyzer */

/*
 * yylex - find the next token in the input stream, and return its token
 *  type and value to the parser.
 *
 * Variables of interest:
 *
 *  cc - character following last token.
 *  nlflag - set if a newline was between the last token and the current token
 *  lastend - set if the last token was an Ender.
 *  lastval - when a semicolon is inserted and returned, lastval gets the
 *   token value that would have been returned if the semicolon hadn't
 *   been inserted.
 */

static struct toktab *lasttok = NULL;
static int lastend = 0;
static int eofflag = 0;
static int cc = '\n';
int nlflag;

int yylex()
{
    register struct toktab *t;
    register int c;
    int n;
    static nodeptr lastval;
    static struct node semi_loc;
    nlflag = 0;
    zero_sbuf(&lex_sbuf);
    if (lasttok != NULL) {
        /*
         * A semicolon was inserted and returned on the last call to yylex,
         *  instead of going to the input, return lasttok and set the
         *  appropriate variables.
         */

        yylval = lastval;
        tok_loc = *lastval;
        t = lasttok;
        goto ret;
    }
    nlflag = 0;
  loop:
    c = cc;
    /*
     * Remember where a semicolon will go if we insert one.
     */
    semi_loc.n_file = tok_loc.n_file;
    semi_loc.n_line = in_line;
    if (cc == '\n')
        --semi_loc.n_line;
    semi_loc.n_col = incol;
    /*
     * Skip whitespace and comments and process #line directives.
     */
    while (c == Comment || isspace(c)) {
        if (c == '\n') {
            nlflag++;
            c = NextChar;
            if (c == Comment) {
                /*
                 * Check for #line directive at start of line.
                 */
                if (('l' == (c = NextChar)) &&
                    ('i' == (c = NextChar)) &&
                    ('n' == (c = NextChar)) &&
                    ('e' == (c = NextChar))) {
                    c = setlineno();
                    while ((c == ' ') || (c == '\t'))
                        c = NextChar;
                    if (c != EOF && c != '\n')
                        c = setfilenm(c);
                }
                while (c != EOF && c != '\n')
                    c = NextChar;
	    }
        }
        else {
            if (c == Comment) {
                while (c != EOF && c != '\n')
                    c = NextChar;
	    }
            else {
                c = NextChar;
            }
        }
    }
    /*
     * A token is the next thing in the input.  Set token location to
     *  the current line and column.
     */
    tok_loc.n_line = in_line;
    tok_loc.n_col = incol;

    if (c == EOF) {
        /*
         * End of file has been reached.	Set eofflag, return T_Eof, and
         *  set cc to EOF so that any subsequent scans also return T_Eof.
         */
        if (eofflag++) {
            eofflag = 0;
            cc = '\n';
            yylval = NULL;
            return 0;
        }
        cc = EOF;
        t = T_Eof;
        yylval = NULL;
        goto ret;
    }

    /*
     * Look at current input character to determine what class of token
     *  is next and take the appropriate action.  Note that the various
     *  token gathering routines write a value into cc.
     */
    if (c == 'u' || c == 'U') {
        int c1 = NextChar;
        if (c1 == '"') {
            if ((t = getucs(c1, &cc)) == NULL)
                goto loop;
        } else {
            PushChar(c1);
            if ((t = getident(c, &cc)) == NULL)
                goto loop;
        }
    }
    else if (isalpha(c) || (c == '_')) {   /* gather ident or reserved word */
        if ((t = getident(c, &cc)) == NULL)
            goto loop;
    }
    else if (isdigit(c) || (c == '.')) {	/* gather numeric literal or "." */
        if ((t = getnum(c, &cc)) == NULL)
            goto loop;
    }
    else if (c == '"') {    /* gather string literal */
        if ((t = getstring(c, &cc)) == NULL)
            goto loop;
    }
    else if (c == '\'') {    /* gather cset literal */
        if ((t = getcset(c, &cc)) == NULL)
            goto loop;
    }
    else {			/* gather longest legal operator */
        if ((n = getopr(c, &cc)) == -1)
            goto loop;
        t = &(optab[n].tok);
        yylval = OpNode(n);
    }
    if (nlflag && lastend && (t->t_flags & Beginner)) {
        /*
         * A newline was encountered between the current token and the last,
         *  the last token was an Ender, and the current token is a Beginner.
         *  Return a semicolon and save the current token in lastval.
         */
        lastval = yylval;
        lasttok = t;
        tok_loc = semi_loc;
        yylval = OpNode(semicol_loc);
        return SEMICOL;
    }
  ret:
    /*
     * Clear lasttok, set lastend if the token being returned is an
     *  Ender, and return the token.
     */
    lasttok = 0;
    lastend = t->t_flags & Ender;

    return (t->t_type);
}

/*
 * getident - gather an identifier beginning with ac.  The character
 *  following identifier goes in cc.
 */

static struct toktab *getident(ac, cc)
    int ac;
    int *cc;
{
    register int c;
    register struct toktab *t;

    c = ac;
    /*
     * Copy characters into string space until a non-alphanumeric character
     *  is found.
     */
    do {
        AppChar(lex_sbuf, c);
        c = NextChar;
    } while (isalnum(c) || (c == '_'));
    *cc = c;
    /*
     * If the identifier is a reserved word, make a ResNode for it and return
     *  the token value.  Otherwise, install it with putid, make an
     *  IdNode for it, and return.
     */
    if ((t = findres()) != NULL) {
        lex_sbuf.endimage = lex_sbuf.strtimage;
        yylval = ResNode(t->t_type);
        return t;
    }
    else {
        yylval = IdNode(str_install(&lex_sbuf));
        return (struct toktab *)T_Ident;
    }
}

/*
 * findres - if the string just copied into the string space by getident
 *  is a reserved word, return a pointer to its entry in the token table.
 *  Return NULL if the string isn't a reserved word.
 */

static struct toktab *findres()
{
    register struct toktab *t;
    register char c;

    c = *lex_sbuf.strtimage;
    if (!islower(c))
        return NULL;
    /*
     * Point t at first reserved word that starts with c (if any).
     */
    if ((t = restab[c - 'a']) == NULL)
        return NULL;
    /*
     * Search through reserved words, stopping when a match is found
     *  or when the current reserved word doesn't start with c.
     */
    while (t->t_word[0] == c) {
        if (bufcmp(t->t_word))
            return t;
        t++;
    }
    return NULL;
}

/*
 * bufcmp - compare a null terminated string to what is in the string buffer.
 */
static int bufcmp(s)
    char *s;
{
    register char *s1;
    s1 = lex_sbuf.strtimage;
    while (s != '\0' && s1 < lex_sbuf.endimage && *s == *s1) {
        ++s;
        ++s1;
    }
    if (*s == '\0' && s1 == lex_sbuf.endimage)
        return 1;
    else
        return 0;
}

/*
 * getnum - gather a numeric literal starting with ac and put the
 *  character following the literal into *cc.
 *
 * getnum also handles the "." operator, which is distinguished from
 *  a numeric literal by what follows it.
 */

static struct toktab *getnum(ac, cc)
    int ac;
    int *cc;
{
    register int c, state;
    int i, realflag, n, dummy;
    int radix = 0;
    word wval = 0;
    double rval = 0;
    int over = 0;
    char *p;

    c = ac;
    if (c == '.') {
        state = 7;
        realflag = 1;
    }
    else {
        rval = wval = tonum(c);
        state = 0;
        realflag = 0;
    }
    for (;;) {
        AppChar(lex_sbuf, c);
        c = NextChar;
        switch (state) {
            case 0:		/* integer part */
                if (isdigit(c))	    { 
                    if (!over) {
                        rval = rval * 10 + (c - '0');
                        if (rval >= MaxWord)
                            over = 1;			/* flag overflow */
                        else
                            wval = wval * 10 + (c - '0');
                    }
                    continue; 
                }
                if (c == '.')           { state = 1; realflag++; continue; }
                if (c == 'e' || c == 'E')  { state = 2; realflag++; continue; }
                if (c == 'r' || c == 'R')  {
                    state = 5;
                    if (over || (wval < 2 || wval > 36))
                        tfatal("invalid radix for integer literal");
                    radix = wval;
                    rval = wval = 0;
                    continue;
                }
                break;
            case 1:		/* fractional part */
                if (isdigit(c))   continue;
                if (c == 'e' || c == 'E')   { state = 2; continue; }
                break;
            case 2:		/* optional exponent sign */
                if (c == '+' || c == '-') { state = 3; continue; }
            case 3:		/* first digit after e, e+, or e- */
                if (isdigit(c)) { state = 4; continue; }
                tfatal("invalid real literal");
                break;
            case 4:		/* remaining digits after e */
                if (isdigit(c))   continue;
                break;
            case 5:		/* first digit after r */
                if ((isdigit(c) || isletter(c)) && tonum(c) < radix) {
                    state = 6; 
                    rval = wval = tonum(c);
                    continue; 
                }
                tfatal("invalid integer literal");
                break;
            case 6:		/* remaining digits after r */
                if (isdigit(c) || isletter(c)) {
                    int d = tonum(c);
                    if (d < radix) {
                        if (!over) {
                            rval = rval * radix + d;
                            if (rval >= MaxWord)
                                over = 1;			/* flag overflow */
                            else
                                wval = wval * radix + d;
                        }
                    } else {	/* illegal digit for radix r */
                        tfatal("invalid digit in integer literal");
                        radix = tonum('z');       /* prevent more messages */
                    }
                    continue;
                }
                break;
            case 7:		/* token began with "." */
                if (isdigit(c)) {
                    state = 1;		/* followed by digit is a real const */
                    realflag = 1;
                    continue;
                }
                *cc = c;			/* anything else is just a dot */
                lex_sbuf.endimage--;	/* remove dot (undo AppChar) */
                n = getopr((int)'.', &dummy);
                yylval = OpNode(n);
                return &(optab[n].tok);
        }
        break;
    }
    *cc = c;

    if (realflag) {
        /*
         * Double - data is a double
         */
        AppChar(lex_sbuf, 0);
        errno = 0;
        rval = strtod(lex_sbuf.strtimage,0);
        if (errno == ERANGE)
            tfatal("real literal out of representable range");
        zero_sbuf(&lex_sbuf);
        p = (char *)&rval;
        for (i = 0; i < sizeof(double); ++i)
            AppChar(lex_sbuf, *p++);
        yylval = RealNode(str_install(&lex_sbuf));
        return T_Real;
    } else if (over) {
        /*
         * Large int - data is the string of chars.  Note the token is still
         * a T_Int - gramatically it is the same as a normal integer.
         */
        n = CurrLen(lex_sbuf);
        yylval = LrgintNode(str_install(&lex_sbuf), n);
        return T_Int;
    } else {
        /*
         * Normal int - data is a word
         */
        zero_sbuf(&lex_sbuf);
        p = (char *)&wval;
        for (i = 0; i < sizeof(word); ++i)
            AppChar(lex_sbuf, *p++);
        yylval = IntNode(str_install(&lex_sbuf));
        return T_Int;
    }
}

/*
 * getstring - gather a string literal starting with ac and place the
 *  character following the literal in *cc.
 */
static struct toktab *getstring(ac, cc)
    int ac;
    int *cc;
{
    int c, i, n;
    int len;
    char utf8[MAX_UTF8_SEQ_LEN];

    c = NextChar;
    while (c != '"' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextChar) != EOF && isspace(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        if (c == Escape) {
            c = NextChar;
            if (c == EOF)
                break;
            if (isoctal(c))
                AppChar(lex_sbuf, octesc(c));
            else if (c == 'x')
                AppChar(lex_sbuf, hexesc(2));
            else if (c == 'u') {
                c = hexesc(4);
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == 'U') {
                c = hexesc(6);
                if (c > MAX_CODE_POINT) {
                    tfatal("code point out of range");
                    c = 0;
                }
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == '^')
                AppChar(lex_sbuf, ctlesc());
            else
                AppChar(lex_sbuf, esctab[c]);
        } else {
            if (uflag && c > 127) {
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            } else
                AppChar(lex_sbuf, c);
        }

        c = NextChar;
    }
    if (c == '"')
        *cc = ' ';
    else {
        tfatal("unclosed quote");
        *cc = c;
    }
    len = lex_sbuf.endimage - lex_sbuf.strtimage;
    yylval = StrNode(str_install(&lex_sbuf), len);
    return T_String;
}

/*
 * getstring - gather a ucs string literal starting with ac and place the
 *  character following the literal in *cc.
 */
static struct toktab *getucs(ac, cc)
    int ac;
    int *cc;
{
    int c, i, n;
    int len;
    char utf8[MAX_UTF8_SEQ_LEN];
    char *p;

    c = NextChar;
    while (c != '"' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextChar) != EOF && isspace(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        if (c == Escape) {
            c = NextChar;
            if (c == EOF)
                break;
            if (isoctal(c))
                AppChar(lex_sbuf, octesc(c));
            else if (c == 'x')
                AppChar(lex_sbuf, hexesc(2));
            else if (c == 'u') {
                c = hexesc(4);
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == 'U') {
                c = hexesc(6);
                if (c > MAX_CODE_POINT) {
                    tfatal("code point out of range");
                    c = 0;
                }
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == '^')
                AppChar(lex_sbuf, ctlesc());
            else
                AppChar(lex_sbuf, esctab[c]);
        } else {
            if (uflag && c > 127) {
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            } else
                AppChar(lex_sbuf, c);
        }

        c = NextChar;
    }
    if (c == '"')
        *cc = ' ';
    else {
        tfatal("unclosed quote");
        *cc = c;
    }

    /*
     * Validate the utf-8.
     */
    p = lex_sbuf.strtimage;
    while (p < lex_sbuf.endimage) {
        char *t = p;
        int i = utf8_check(&p, lex_sbuf.endimage);
        if (i == -1) {
            tfatal("Invalid utf-8 sequence beginning at char %d", 1 + (t - lex_sbuf.strtimage));
            break;
        }
        if (i < 0 || i > MAX_CODE_POINT) {
            tfatal("utf-8 code point out of range beginning at char %d", 1 + (t - lex_sbuf.strtimage));
            break;
        }
    }

    len = lex_sbuf.endimage - lex_sbuf.strtimage;
    yylval = UcsNode(str_install(&lex_sbuf), len);
    return T_Ucs;
}


/*
 * getcset - gather a cset literal starting with ac and place the
 *  character following the literal in *cc.
 */
static struct toktab *getcset(ac, cc)
    int ac;
    int *cc;
{
    register int c, prev = 0, i, len;
    struct rangeset *cs;
    int state = 0;
    int esc_flag;
    char *p;

    MemProtect(cs = init_rangeset());

    c = NextChar;
    while (c != '\'' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextChar) != EOF && isspace(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        esc_flag = (c == Escape);
        if (esc_flag) {
            c = NextChar;
            if (c == EOF)
                break;
            if (isoctal(c))
                c = octesc(c);
            else if (c == 'x')
                c = hexesc(2);
            else if (c == 'u')
                c = hexesc(4);
            else if (c == 'U') {
                c = hexesc(6);
                if (c > MAX_CODE_POINT) {
                    tfatal("code point out of range");
                    c = 0;
                }
            }
            else if (c == '^')
                c = ctlesc();
            else
                c = esctab[c];
        }

        switch (state) {
            case 0:
                prev = c;
                ++state;
                break;
            case 1:
                if (!esc_flag && c == '-')
                    ++state;
                else {
                    MemProtect(add_range(cs, prev, prev));
                    prev = c;
                }
                break;
            case 2:
                MemProtect(add_range(cs, prev, c));
                state = 0;
                break;
        }
        c = NextChar;
    }
    if (c == '\'') {
        if (state == 1) {
            MemProtect(add_range(cs, prev, prev));
        } else if (state == 2)
            tfatal("incomplete cset range");
        *cc = ' ';
    } else {
        tfatal("unclosed quote");
        *cc = c;
    }

    /*
     * Turn into a string for output to u file.
     */
    p = (char *)cs->range;
    len = cs->n_ranges * sizeof(struct range);
    for (i = 0; i < len; ++i)
        AppChar(lex_sbuf, *p++);
    yylval = CsetNode(str_install(&lex_sbuf), len);

    free_rangeset(cs);

    return T_Cset;
}



static int ctlesc()
{
    register int c;

    c = NextChar;
    if (c == EOF)
        return EOF;

    return (c & 037);
}

/*
 * octesc - translate an octal escape -- backslash followed by
 *  one, two, or three octal digits.
 */

static int octesc(ac)
    int ac;
{
    register int c, nc, i;

    c = 0;
    nc = ac;
    i = 1;
    do {
        c = (c << 3) | (nc - '0');
        nc = NextChar;
        if (nc == EOF)
            return EOF;
    } while (isoctal(nc) && i++ < 3);
    PushChar(nc);

    return (c & 0377);
}

/*
 * hexesc - translate a hexadecimal escape -- backslash-x
 *  followed by up to 'digs' hexadecimal digits.
 */

static int hexesc(int digs)
{
    register int c, nc, i;

    c = 0;
    i = 0;
    while (i++ < digs) {
        nc = NextChar;
        if (nc == EOF)
            return EOF;
        if (nc >= 'a' && nc <= 'f')
            nc -= 'a' - 10;
        else if (nc >= 'A' && nc <= 'F')
            nc -= 'A' - 10;
        else if (isdigit(nc))
            nc -= '0';
        else {
            PushChar(nc);
            break;
        }
        c = (c << 4) | nc;
    }

    return c;
}


/*
 * setlineno - set line number from #line comment, return following char.
 */

static int setlineno()
{
    register int c;

    while ((c = NextChar) == ' ' || c == '\t')
        ;
    if (c < '0' || c > '9') {
        tfatal("no line number in #line directive");
        while (c != EOF && c != '\n')
            c = NextChar;
        return c;
    }
    in_line = 0;
    while (c >= '0' && c <= '9') {
        in_line = in_line * 10 + (c - '0');
        c = NextChar;
    }
    return c;
}


/*
 * setfilenm -	set file name from #line comment, return following char.
 */

static int setfilenm(c)
    register int c;
{
    while (c == ' ' || c == '\t')
        c = NextChar;
    if (c != '"') {
        tfatal("'\"' missing from file name in #line directive");
        while (c != EOF && c != '\n')
            c = NextChar;
        return c;
    }
    while ((c = NextChar) != '"' && c != EOF && c != '\n')
        AppChar(lex_sbuf, c);
    if (c == '"') {
        char *s = str_install(&lex_sbuf);
        tok_loc.n_file = intern(canonicalize(s));
        return NextChar;
    }
    else {
        tfatal("'\"' missing from file name in #line directive");
        return c;
    }
}

/*
 * nextchar - return the next character in the input.
 *
 *  Called from the lexical analyzer; interfaces it to the preprocessor.
 */

static int nextchar()
{
    register int c;

    if ((c = peekc) != 0) {
        peekc = 0;
        return c;
    }
    c = ppch();
    switch (c) {
        case EOF:
            if (incol) {
                c = '\n';
                in_line++;
                incol = 0;
                peekc = EOF;
                break;
	    }
            else {
                in_line = 0;
                incol = 0;
                break;
	    }
        case '\n':
            in_line++;
            incol = 0;
            break;
        case '\t':
            incol = (incol | 7) + 1;
            break;
        case '\b':
            if (incol)
                incol--;
            break;
        default: {
            if (c > 127 && uflag)
                c = read_utf_char(c);
            incol++;
        }
    }
    return c;
}

static int read_utf_char(int c)
{
    char utf8[MAX_UTF8_SEQ_LEN], *p = utf8;
    int i, n = UTF8_SEQ_LEN(c);
    if (n < 1) {
        tfatal("invalid utf-8 start char");
        return ' ';  /* Returning space keeps down follow-through error messages */
    }
    utf8[0] = c;
    for (i = 1; i < n; ++i) {
        c = ppch();
        if (c == EOF)
            return c;
        utf8[i] = c;
    }
    c = utf8_check(&p, utf8 + n);
    if (c == -1) {
        tfatal("invalid utf-8 sequence");
        return ' ';
    }
    if (c < 0 || c > MAX_CODE_POINT) {
        tfatal("utf-8 code point out of range");
        return ' ';
    }

    return c;
}


/*
 * Prototype.
 */

static	char	*mapterm	(int typ,struct node *val);

/*
 * yyerror produces syntax error messages. 
 */
void yyerror(char *msg)
{
    int line;

    if (yylval == NULL)
        line = 0;
    else
        line = Line(yylval);

    if (tok_loc.n_file)
        fprintf(stderr, "File %s; ", abbreviate(tok_loc.n_file));
    if (yychar == EOFX)   /* special case end of file */
        fprintf(stderr, "unexpected end of file\n");
    else {
        fprintf(stderr, "Line %d # ", line);
        if (Col(yylval))
            fprintf(stderr, "\"%s\": ", mapterm(yychar, yylval));
        fprintf(stderr, "%s\n", msg);
    }

    tfatals++;
    nocode++;
}

/*
 * mapterm finds a printable string for the given token type
 *  and value.
 */
static char *mapterm(int typ, nodeptr val)
{
    register struct toktab *t;
    register struct optab *ot;
    register int i;

    i = typ;
    if (i == IDENT || i == INTLIT || i == REALLIT || i == STRINGLIT ||
        i == CSETLIT)
        return Str0(val);
    for (t = toktab; t->t_type != 0; t++)
        if (t->t_type == i)
            return t->t_word;
    for (ot = optab; ot->tok.t_type != 0; ot++)
        if (ot->tok.t_type == i)
            return ot->tok.t_word;
    return "???";
}
