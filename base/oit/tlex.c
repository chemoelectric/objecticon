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
#include "ipp.h"

/* Used by auto-generated func in ../common/lextab.h */
static  int nextchar(int);
static void lexfatal(char *fmt, ...);

#include "lexdef.h"
#include "lextab.h"

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
static	int		setencoding	(int c);
static	int		setlineno	(void);
static	int	ctlesc	(int c);
static	int	escchar	(int c);
static	int	hexesc		(int digs);
static	int	octesc		(int ac);
static  int     read_utf_char(int c);
static  char    *encoding;

/* Wrappers for Char test functions */
static int isalnum_ex(int c);
static int isalpha_ex(int c);
static int isdigit_ex(int c);
static int islower_ex(int c);
static int isspace_ex(int c);
static int isupper_ex(int c);

#define isletter(c)	(isupper_ex(c) | islower_ex(c))
#define tonum(c)        (isdigit_ex(c) ? (c - '0') : ((c & 037) + 9))

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

/*
 * Identical to tfatal, except for the handling of the line number.
 */
static void lexfatal(char *fmt, ...)
{
    va_list argp;
    if (File(&tok_loc)) {
        begin_link(stderr, File(&tok_loc), in_line);
        fprintf(stderr, "File %s; ", abbreviate(File(&tok_loc)));
    }
    if (in_line)
        fprintf(stderr, "Line %d", in_line);
    if (File(&tok_loc))
        end_link(stderr);
    if (in_line)
        fputs(" # ", stderr);

    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    tfatals++;
}

int yylex()
{
    struct toktab *t;
    int c;
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
    while (c == Comment || isspace_ex(c)) {
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
                    while ((c == ' ') || (c == '\t'))
                        c = NextChar;
                    if (c != EOF && c != '\n')
                        c = setencoding(c);
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
    else if (isalpha_ex(c) || (c == '_')) {   /* gather ident or reserved word */
        if ((t = getident(c, &cc)) == NULL)
            goto loop;
    }
    else if (isdigit_ex(c) || (c == '.')) {	/* gather numeric literal or "." */
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

static struct toktab *getident(int ac, int *cc)
{
    int c;
    struct toktab *t;

    c = ac;
    /*
     * Copy characters into string space until a non-alphanumeric character
     *  is found.
     */
    do {
        AppChar(lex_sbuf, c);
        c = NextChar;
    } while (isalnum_ex(c) || (c == '_'));
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
    struct toktab *t;
    char c;

    c = *lex_sbuf.strtimage;
    if (!islower((unsigned char)c))
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
static int bufcmp(char *s)
{
    char *s1;
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

static struct toktab *getnum(int ac, int *cc)
{
    int c, state;
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
                if (isdigit_ex(c))	    { 
                    if (!over) {
                        rval = rval * 10 + (c - '0');
                        /* Check whether we've possibly lost double precision, or have exceeded MaxWord */
                        if (rval >= Big || rval > MaxWord)
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
                        lexfatal("invalid radix for integer literal");
                    radix = wval;
                    rval = wval = 0;
                    continue;
                }
                break;
            case 1:		/* fractional part */
                if (isdigit_ex(c))   continue;
                if (c == 'e' || c == 'E')   { state = 2; continue; }
                break;
            case 2:		/* optional exponent sign */
                if (c == '+' || c == '-') { state = 3; continue; }
            case 3:		/* first digit after e, e+, or e- */
                if (isdigit_ex(c)) { state = 4; continue; }
                lexfatal("invalid real literal");
                break;
            case 4:		/* remaining digits after e */
                if (isdigit_ex(c))   continue;
                break;
            case 5:		/* first digit after r */
                if ((isdigit_ex(c) || isletter(c)) && tonum(c) < radix) {
                    state = 6; 
                    rval = wval = tonum(c);
                    continue; 
                }
                lexfatal("invalid integer literal");
                break;
            case 6:		/* remaining digits after r */
                if (isdigit_ex(c) || isletter(c)) {
                    int d = tonum(c);
                    if (d < radix) {
                        if (!over) {
                            rval = rval * radix + d;
                            if (rval >= Big || rval > MaxWord)
                                over = 1;			/* flag overflow */
                            else
                                wval = wval * radix + d;
                        }
                    } else {	/* illegal digit for radix r */
                        lexfatal("invalid digit in integer literal");
                        radix = tonum('z');       /* prevent more messages */
                    }
                    continue;
                }
                break;
            case 7:		/* token began with "." */
                if (isdigit_ex(c)) {
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
            lexfatal("real literal out of representable range");
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
static struct toktab *getstring(int ac, int *cc)
{
    int c, i, n;
    int len;
    char utf8[MAX_UTF8_SEQ_LEN];
    c = NextLitChar;
    while (c != '"' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextLitChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextLitChar) != EOF && isspace_ex(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        if (c == Escape) {
            c = NextLitChar;
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
                    lexfatal("code point out of range");
                    c = 0;
                }
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == '^') {
                c = NextLitChar;
                if (c < 256) 
                    AppChar(lex_sbuf, ctlesc(c));
                else
                    lexfatal("string literal character out of range (codepoint %d)", c);
            } else {
                c = escchar(c);
                if (c < 256) 
                    AppChar(lex_sbuf, c);
                else
                    lexfatal("string literal character out of range (codepoint %d)", c);
            }
        } else {
            if (c < 256) 
                AppChar(lex_sbuf, c);
            else
                lexfatal("string literal character out of range (codepoint %d)", c);
        }

        c = NextLitChar;
    }
    if (c == '"')
        *cc = ' ';
    else {
        lexfatal("unclosed quote");
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
static struct toktab *getucs(int ac, int *cc)
{
    int c, i, n;
    int len;
    char utf8[MAX_UTF8_SEQ_LEN];
    char *p;

    c = NextLitChar;
    while (c != '"' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextLitChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextLitChar) != EOF && isspace_ex(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        if (c == Escape) {
            c = NextLitChar;
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
                    lexfatal("code point out of range");
                    c = 0;
                }
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            }
            else if (c == '^') {
                c = NextLitChar;
                AppChar(lex_sbuf, ctlesc(c));
            } else {
                c = escchar(c);
                if (c > 127) {
                    n = utf8_seq(c, utf8);
                    for (i = 0; i < n; ++i)
                        AppChar(lex_sbuf, utf8[i]);
                } 
                else 
                    AppChar(lex_sbuf, c);
            }
        } else {
            if (c > 127) {
                n = utf8_seq(c, utf8);
                for (i = 0; i < n; ++i)
                    AppChar(lex_sbuf, utf8[i]);
            } else
                AppChar(lex_sbuf, c);
        }

        c = NextLitChar;
    }
    if (c == '"')
        *cc = ' ';
    else {
        lexfatal("unclosed quote");
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
            lexfatal("Invalid utf-8 sequence beginning at char %d", 1 + (t - lex_sbuf.strtimage));
            break;
        }
        if (i < 0 || i > MAX_CODE_POINT) {
            lexfatal("utf-8 code point out of range beginning at char %d", 1 + (t - lex_sbuf.strtimage));
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
static struct toktab *getcset(int ac, int *cc)
{
    int c, prev = 0, i, len;
    struct rangeset *cs;
    int state = 0;
    int esc_flag;
    char *p;

    cs = init_rangeset();

    c = NextLitChar;
    while (c != '\'' && c != '\n' && c != EOF) {
        /*
         * If a '_' is the last before a new-line, skip over any whitespace.
         */
        if (c == '_') {
            int t = NextLitChar;
            if (t == '\n' || t == '\r') {
                while ((c = NextLitChar) != EOF && isspace_ex(c))
                    ;
                continue;
            } else
                PushChar(t);
        }

        esc_flag = (c == Escape);
        if (esc_flag) {
            c = NextLitChar;
            if (isoctal(c))
                c = octesc(c);
            else if (c == 'x')
                c = hexesc(2);
            else if (c == 'u')
                c = hexesc(4);
            else if (c == 'U') {
                c = hexesc(6);
                if (c > MAX_CODE_POINT) {
                    lexfatal("code point out of range");
                    c = 0;
                }
            }
            else if (c == '^') {
                c = NextLitChar;
                c = ctlesc(c);
            } else
                c = escchar(c);
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
                    add_range(cs, prev, prev);
                    prev = c;
                }
                break;
            case 2:
                add_range(cs, prev, c);
                state = 0;
                break;
        }
        c = NextLitChar;
    }
    if (c == '\'') {
        if (state == 1) {
            add_range(cs, prev, prev);
        } else if (state == 2)
            lexfatal("incomplete cset range");
        *cc = ' ';
    } else {
        lexfatal("unclosed quote");
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


static int escchar(int c)
{
    switch(c) {
        case 'n' : return '\n';
        case 'l' : return '\n';
        case 'b' : return '\b';
        case 'd' : return 0177;
        case 'e' : return 033;
        case 'r' : return '\r';
        case 't' : return '\t';
        case 'v' : return '\v';
        case 'f' : return '\f';
        default: return c;
    }
}


static int ctlesc(int c)
{
    return (c & 037);
}

/*
 * octesc - translate an octal escape -- backslash followed by
 *  one, two, or three octal digits.
 */

static int octesc(int ac)
{
    int c, nc, i;

    c = 0;
    nc = ac;
    i = 1;
    do {
        c = (c << 3) | (nc - '0');
        nc = NextLitChar;
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
    int c, nc, i;

    c = 0;
    i = 0;
    while (i++ < digs) {
        nc = NextLitChar;
        if (nc >= 'a' && nc <= 'f')
            nc -= 'a' - 10;
        else if (nc >= 'A' && nc <= 'F')
            nc -= 'A' - 10;
        else if (isdigit_ex(nc))
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
    int c;

    while ((c = NextChar) == ' ' || c == '\t')
        ;
    if (c < '0' || c > '9') {
        lexfatal("no line number in #line directive");
        while (c != EOF && c != '\n')
            c = NextChar;
        return c;
    }
    in_line = 0;
    while (c >= '0' && c <= '9') {
        in_line = in_line * 10 + (c - '0');
        c = NextChar;
    }
    --in_line;
    return c;
}


/*
 * setfilenm -	set file name from #line comment, return following char.
 */

static int setfilenm(int c)
{
    while (c == ' ' || c == '\t')
        c = NextChar;
    if (c != '"') {
        lexfatal("'\"' missing from file name in #line directive");
        while (c != EOF && c != '\n')
            c = NextChar;
        return c;
    }
    zero_sbuf(&lex_sbuf);
    while ((c = NextChar) != '"' && c != EOF && c != '\n')
        AppChar(lex_sbuf, c);
    if (c == '"') {
        char *s = str_install(&lex_sbuf);
        if (s == stdin_string)
            tok_loc.n_file = s;
        else
            tok_loc.n_file = intern(canonicalize(s));
        return NextChar;
    }
    else {
        lexfatal("'\"' missing from file name in #line directive");
        return c;
    }
}

/*
 * setencoding -	set encoding from #line comment, return following char.
 */

static int setencoding(int c)
{
    char *s;
    while (c == ' ' || c == '\t')
        c = NextChar;

    zero_sbuf(&lex_sbuf);
    while (isalnum_ex(c) || (c == '-')) {
        AppChar(lex_sbuf, c);
        c = NextChar;
    }

    s = str_install(&lex_sbuf);
    if (s == empty_string)
        lexfatal("no encoding in #line directive");
    else if (s == ascii_string || s == utf8_string || s == iso_8859_1_string)
        encoding = s;
    else {
        lexfatal("invalid encoding:%s", s);
        encoding = ascii_string;
    }

    return c;
}

/*
 * nextchar - return the next character in the input.
 *
 *  Called from the lexical analyzer; interfaces it to the preprocessor.
 */

static int nextchar(int in_literal)
{
    int c;

    if ((c = peekc) != 0) {
        peekc = 0;
        return c;
    }
    c = ppch();
    switch (c) {
        case EOF:
            /* Note that the preprocessor always gives a \n right before the EOF */
            break;
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
            if (c > 127 && in_literal) {
                if (encoding == utf8_string)
                    c = read_utf_char(c);
                else if (encoding == ascii_string)
                    lexfatal("non-ascii character (codepoint %d)", c);
                /* else encoding == iso_8859_1_string in which case the codepoint is c */
            }
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
        lexfatal("invalid utf-8 start char");
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
        lexfatal("invalid utf-8 sequence");
        return ' ';
    }
    if (c < 0 || c > MAX_CODE_POINT) {
        lexfatal("utf-8 code point out of range");
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

    if (tok_loc.n_file) {
        begin_link(stderr, tok_loc.n_file, line);
        fprintf(stderr, "File %s; ", abbreviate(tok_loc.n_file));
    }

    if (yychar == EOFX) {   /* special case end of file */
        if (tok_loc.n_file)
            end_link(stderr);
        fprintf(stderr, "unexpected end of file\n");
    } else {
        fprintf(stderr, "Line %d", line);
        if (tok_loc.n_file)
            end_link(stderr);
        fputs(" # ", stderr);
        if (Col(yylval))
            fprintf(stderr, "\"%s\": ", mapterm(yychar, yylval));
        fprintf(stderr, "%s\n", msg);
    }

    tfatals++;
}

/*
 * mapterm finds a printable string for the given token type
 *  and value.
 */
static char *mapterm(int typ, nodeptr val)
{
    struct toktab *t;
    struct optab *ot;
    int i;

    i = typ;
    if (i == IDENT || i == STRINGLIT)
        return Str0(val);
    for (t = toktab; t->t_type != 0; t++)
        if (t->t_type == i)
            return t->t_word;
    for (ot = optab; ot->tok.t_type != 0; ot++)
        if (ot->tok.t_type == i)
            return ot->tok.t_word;
    return "???";
}

static int isalnum_ex(int c)
{
    return c < 128 && isalnum((unsigned char)c);
}

static int isalpha_ex(int c)
{
    return c < 128 && isalpha((unsigned char)c);
}

static int isdigit_ex(int c)
{
    return c < 128 && isdigit((unsigned char)c);
}

static int islower_ex(int c)
{
    return c < 128 && islower((unsigned char)c);
}

static int isspace_ex(int c)
{
    return c < 128 && isspace((unsigned char)c);
}

static int isupper_ex(int c)
{
    return c < 128 && isupper((unsigned char)c);
}
