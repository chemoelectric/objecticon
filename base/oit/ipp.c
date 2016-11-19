/*
 * ipp.c -- the Icon preprocessor.
 *
 *  All Icon source passes through here before translation or compilation.
 *  Directives recognized are:
 *	#line n [filename]
 *	$line n [filename]
 *	$include filename
 *	$define identifier text
 *	$undef identifier
 *	$ifdef identifier
 *	$ifndef identifier
 *	$else
 *	$endif
 *      $encoding name
 *	$error [text]
 *
 *  Entry points are
 *	ppinit(fname,inclpath,m4flag) -- open input file
 *	ppdef(s,v) -- "$define s v", or "$undef s" if v is a null pointer
 *	ppch() -- return next preprocessed character
 *	ppecho() -- preprocess to stdout (for icont/iconc -E)
 *
 *  See ../h/features.h for the set of predefined symbols.
 */
 
#include "icont.h"
#include "tmain.h"
#include "trans.h"
#include "ipp.h"

#define HTBINS 256			/* number of hash bins */

typedef struct fstruct {		/* input file structure */
   struct fstruct *prev;		/* previous file */
   char *fname;				/* file name */
   char *encoding;                      /* encoding */
   long lno;				/* line number */
   FILE *fp;				/* stdio file pointer */
   int m4flag;				/* nz if preprocessed by m4 */
   int ifdepth;				/* $if nesting depth when opened */
   } infile;

typedef struct bstruct {		/* buffer pointer structure */
   struct bstruct *prev;		/* previous pointer structure */
   struct cd *defn;			/* definition being processed */
   char *ptr;				/* saved pointer value */
   char *stop;				/* saved stop value */
   char *lim;				/* saved limit value */
   } buffer;

typedef struct {			/* preprocessor token structure */
   char *addr;				/* beginning of token */
   short len;				/* length */
   } ptok;

typedef struct cd {			/* structure holding a definition */
   struct cd *next;			/* link to next defn */
   struct cd *prev;			/* link to previous defn */
   int nlen, vlen;			/* length of name & val */
   char inuse;				/* nonzero if curr being expanded */
   char *name;                          /* name */
   char *val;                           /* value */
   } cdefn;

static	int	ppopen	(char *fname, int m4);
static	FILE *	m4pipe	(char *fname);
static  char *  rmnl    (char *s);
static	char *	rline	(FILE *fp);
static	void	pushdef	(cdefn *d);
static	void	pushline (void);
static	void	ppdir	(char *line);
static  void    pfatal(char *fmt, ...);
static	void	skipcode (int doelse, int report, char **cmd0, char **args0);
static	char *	define	(char *s);
static	char *	undef	(char *s);
static	char *	ifdef	(char *s);
static	char *	ifndef	(char *s);
static	char *	ifxdef	(char *s, int f);
static	char *	elsedir	(char *s);
static	char *	elsif	(char *s);
static	char *	endif	(char *s);
static	char *	encoding(char *s);
static  char *  load    (char *s);
static  char *  uload   (char *s);
static	char *	errdir	(char *s);
static	char *	include	(char *s);
static	char *	setline	(char *s);
static	char *	wskip	(char *s);
static	char *	nskip	(char *s);
static	char *	matchq	(char *s);
static	char *	getidt	(char *dst, char *src);
static	char *	getencoding(char *dst, char *src);
static	char *	getfnm	(char *dst, char *src);
static  void   freecdefn(cdefn *d);
static cdefn *dquery(char *name, int len);
static void  dremove(char *name);
static void  dinsert(char *name, char *val);
static void  dinsert_pre(char *name, char *val, int vlen);

struct ppcmd {
   char *name;
   char *(*func)(char *);
   }
pplist[] = {
   { "define",  define  },
   { "undef",   undef   },
   { "ifdef",   ifdef   },
   { "ifndef",  ifndef  },
   { "elsifdef",   elsif   },
   { "elsifndef",  elsif  },
   { "else",    elsedir },
   { "endif",   endif   },
   { "include", include },
   { "line",    setline },
   { "error",   errdir  },
   { "encoding",encoding  },
   { "load",    load  },
   { "uload",   uload  },
   { 0,         0       }};

static infile nofile;			/* ancestor of all files; all zero */
static infile *curfile;			/* pointer to current entry */

static buffer *bstack;			/* stack of pending buffers */
static buffer *bfree;			/* pool of free bstructs */

static char *buf;			/* input line buffer */
static char *bnxt;			/* next character */
static char *bstop;			/* limit of preprocessed chars */
static char *blim;			/* limit of all chars */
static cdefn *cbin[HTBINS];		/* hash bins for defn table */

static char *lpath;				/* LPATH for finding source files */

static int ifdepth;			/* depth of $if nesting */
static char *last_line_file, 
            *last_line_encoding;        /* last file/encoding on a #line directive */


/*
 * ppinit(fname, m4) -- initialize preprocessor to read from fname.
 *
 *  Returns 1 if successful, 0 if open failed.
 */
int ppinit(char *fname, int m4)
   {
   int i;
   cdefn *d, *n;

   /*
    * clear out any existing definitions from previous files
    */
   for (i = 0; i < HTBINS; i++) {
      for (d = cbin[i]; d != NULL; d = n) {
         n = d->next;
         freecdefn(d);
         }
      cbin[i] = NULL;
      }

   /*
    * install predefined symbols
    */
#define Feature(symname,kwval) dinsert(symname, "1");
#include "../h/features.h"

   /*
    * initialize variables and open source file 
    */
   lpath = getenv(OI_INCL);
   curfile = &nofile;			/* init file struct pointer */
   last_line_file = last_line_encoding = 0;
   return ppopen(fname, m4);		/* open main source file */
   }

/*
 * ppopen(fname, m4) -- open a new file for reading by the preprocessor.
 *
 *  Returns 1 if successful, 0 if open failed.
 *
 *  Open calls may be nested.  Files are closed when EOF is read.
 */
static int ppopen(char *fname, int m4)
   {
   FILE *f;
   infile *fs;

   fname = intern(fname);
   for (fs = curfile; fs->fname != NULL; fs = fs->prev)
      if (fname == fs->fname) {
         pfatal("circular include: %s", fname);	/* issue error message */
         return 1;				/* treat as success */
         }
   if (m4)
      f = m4pipe(fname);
   else if (curfile == &nofile && fname == stdin_string) { /* 1st file only */
      f = stdin;
      }
   else
      f = fopen(fname, ReadText);
   if (f == NULL) {
      return 0;
      }
   fs = safe_zalloc(sizeof(infile));
   fs->prev = curfile;
   fs->fp = f;
   fs->fname = fname;
   fs->encoding = ascii_string;
   fs->lno = 0;
   fs->m4flag = m4;
   fs->ifdepth = ifdepth;
   curfile = fs;
   pushline();
   return 1;
   }

/*
 * m4pipe -- open a pipe from m4.
 */
static FILE *m4pipe(char *filename)
   {
#if UNIX
      {
      FILE *f;
      char *s = safe_zalloc(7 + strlen(filename));
      if (filename == stdin_string)
          sprintf(s, "m4 -s -");
      else
          sprintf(s, "m4 -s %s", filename);
      f = popen(s, ReadText);
      free(s);
      return f;
      }
#else					
   return NULL;
#endif					
   }

/*
 * ppdef(s,v) -- define/undefine a symbol
 *
 *  If v is a null pointer, undefines symbol s.
 *  Otherwise, defines s to have the value v.
 *  No error is given for a redefinition.
 */
void ppdef(char *s, char *v)
{
   dremove(s);
   if (v != NULL)
       dinsert(s, v);
}

/*
 * ppecho() -- run input through preprocessor and echo directly to stdout.
 */
void ppecho()
   {
   int c;

   while ((c = ppch()) != EOF)
      putchar(c);
   }

/*
 * ppch() -- get preprocessed character.
 */
int ppch()
   {
   int c, f;
   char *p;
   buffer *b;
   cdefn *d;
   infile *fs;

   for (;;) {
      if (bnxt < bstop)			/* if characters ready to go */
         return (*bnxt++) & 0xFF;		/* return first one */

      if (bnxt < blim) {
         /*
          * There are characters in the buffer, but they haven't been
          *  checked for substitutions yet.  Process either one id, if
          *  that's what's next, or as much else as we can.
          */
         f = *bnxt & 0xFF;
         if (isalpha((unsigned char)f) || f == '_') {
            /*
             * This is the first character of an identifier.  It could
             *  be the name of a definition.  If so, the name will be
             *  contiguous in this buffer.  Check it.
             */
            p = bnxt + 1;
            while (p < blim && (isalnum((unsigned char)(c = *p)) || c == '_'))	/* find end */
               p++;
            bstop = p;			/* safe to consume through end */
            if (((d = dquery(bnxt, p-bnxt)) == 0)  || (d->inuse == 1)) {
               bnxt++;
               return f;		/* not defined; just use it */
               }
            /*
             * We got a match.  Remove the token from the input stream and
             *  push the replacement value.
             */
            bnxt = p;
            pushdef(d);			/* make defn the curr buffer */
            continue;			/* loop to preprocess */
            }
         else {
            /*
             * Not an id.  Find the end of non-id stuff and mark it as
             *  having been preprocessed.  This is where we skip over
             *  string and cset literals to avoid processing them.
             */
            p = bnxt++;
            while (p < blim) {
               c = *p;
               if (isalpha((unsigned char)c) || c == '_') {	/* there's an id ahead */
                  bstop = p;
                  return f;
                  }
               else if (isdigit((unsigned char)c)) {		/* numeric constant */
                  p = nskip(p);
                  }
               else if (c == '#') {		/* comment: skip to EOL */
                  bstop = blim;
                  return f;
                  }
               else if (c == '"' || c == '\''){	/* quoted literal */
                  p = matchq(p);		/* skip to end */
                  if (*p != '\0')
                     p++;
                  }
               else
                  p++;				/* else advance one char */
               }
            bstop = blim;			/* mark end of processed chrs */
            return f;				/* return first char */
            }
         }

      /*
       * The buffer is empty.  Revert to a previous buffer.
       */
      if (bstack != NULL) {
         b = bstack;
         b->defn->inuse = 0;
         bnxt = b->ptr;
         bstop = b->stop;
         blim = b->lim;
         bstack = b->prev;
         b->prev = bfree;
         bfree = b;
         continue;				/* loop to preprocess */
         }
   
      /*
       * There's nothing at all in memory.  Read a new line.
       */
      if ((buf = rline(curfile->fp)) != NULL) {
         /*
          * The read was successful.
          */
         p = bnxt = bstop = blim = buf;		/* reset buffer pointers */
         curfile->lno++;			/* bump line number */
         while (isspace((unsigned char)(c = *p)))
            p++;				/* find first nonwhite */
         if (c == '$' && (!ispunct((unsigned char)p[1]) || p[1]==' '))
            ppdir(p + 1);			/* handle preprocessor cmd */
         else if (buf[1]=='l' && buf[2]=='i' && buf[3]=='n' && buf[4]=='e' &&
                  buf[0]=='#' && buf[5]==' ')
            ppdir(p + 1);			/* handle #line form */
         else {
            /*
             * Not a preprocessor line; will need to scan for symbols.
             */
            bnxt = buf;
            blim = buf + strlen(buf);
            bstop = bnxt;			/* no chars scanned yet */
            }
         }
   
      else {
         /*
          * The read hit EOF.
          */
         if (curfile->ifdepth != ifdepth) {
            pfatal("unterminated $if");
            ifdepth = curfile->ifdepth;
            }

         /*
          * switch to previous file and close current file.
          */
         fs = curfile;
         curfile = fs->prev;

         if (ferror(fs->fp) != 0)
            equit("failed to read from source file %s", fs->fname);

#if UNIX
         if (fs->m4flag) {			/* if m4 preprocessing */
            if (pclose(fs->fp) != 0)		/* close pipe */
               equit("m4 terminated abnormally");
            }
         else
#endif					/* UNIX */
            fclose(fs->fp);		/* close current file */
           
         free(fs);
         if (curfile == &nofile)	/* if at outer level, return EOF */
            return EOF;
         else				/* else generate #line comment */
             pushline();
         }
      }
   }

/*
 * rline(fp) -- read arbitrarily long line and return pointer.
 *
 *  Allocates memory as needed.  Returns NULL for EOF.  Lines end with "\n\0".
 */
static char *rline(FILE *fp)
   {
#define LINE_SIZE_INIT 100
#define LINE_SIZE_INCR 100
   static char *lbuf = NULL;	/* line buffer */
   static int llen = 0;		/* current buffer length */
   char *p;
   int c, n;

   /* if first time, allocate buffer */
   if (!lbuf) {
      lbuf = safe_zalloc(LINE_SIZE_INIT);
      llen = LINE_SIZE_INIT;
      }

   /* first character is special; return NULL if hit EOF here */
   c = getc(fp);
   if (c == EOF)
      return NULL;
   if (c == '\n')
      return "\n";

   p = lbuf;
   n = llen - 3;
   *p++ = c;

   for (;;)  {
      /* read until buffer full; return after newline or EOF */
      while (--n >= 0 && (c = getc(fp)) != '\n' && c != EOF)
         *p++ = c;
      if (n >= 0) {
         *p++ = '\n';			/* always terminate with \n\0 */
         *p++ = '\0';
         return lbuf;
         }

      /* need to read more, so we need a bigger buffer */
      llen += LINE_SIZE_INCR;
      lbuf = safe_realloc(lbuf, llen);
      p = lbuf + llen - LINE_SIZE_INCR - 2;
      n = LINE_SIZE_INCR;
      }
   }

/*
 * pushdef(d) -- insert definition into the input stream.
 */
static void pushdef(cdefn *d)
   {
   buffer *b;
   d->inuse = 1;
   b = bfree;
   if (b == NULL)
      b = safe_zalloc(sizeof(buffer));
   else
      bfree = b->prev;
   b->prev = bstack;
   b->defn = d;
   b->ptr = bnxt;
   b->stop = bstop;
   b->lim = blim;
   bstack = b;
   bnxt = bstop = d->val;
   blim = bnxt + d->vlen;
   }

/*
 * pushline() -- push #line directive into input stream.
 */
static void pushline()
   {
   static char tbuf[256];
  
   if (curfile->encoding != last_line_encoding ||
       curfile->fname != last_line_file) 
   {
       snprintf(tbuf, sizeof(tbuf), "#line %ld \"%s\" %s\n", curfile->lno + 1, curfile->fname, curfile->encoding);
       last_line_file = curfile->fname;
       last_line_encoding = curfile->encoding;
   } else
       snprintf(tbuf, sizeof(tbuf), "#line %ld\n", curfile->lno + 1);
   bnxt = tbuf;
   bstop = blim = tbuf + strlen(tbuf);
   }

/*
 * ppdir(s) -- handle preprocessing directive.
 *
 *  s is the portion of the line following the $.
 */
static void ppdir(char *s)
   {
   char b0, *cmd, *errmsg;
   struct ppcmd *p;

   b0 = buf[0];				/* remember first char of line */
   bnxt = "\n";				/* set buffer pointers to empty line */
   bstop = blim = bnxt + 1;

   s = wskip(s);			/* skip whitespace */
   s = getidt(cmd = s - 1, s);		/* get command name */
   s = wskip(s);			/* skip whitespace */

   for (p = pplist; p->name != NULL; p++) /* find name in table */
      if (strcmp(cmd, p->name) == 0) {
         errmsg = (*p->func)(s);	/* process directive */
         if (errmsg != NULL && (p->func != setline || b0 != '#'))
             pfatal("%s", errmsg);	/* issue err if not from #line form */
      return;
      }

   pfatal("invalid preprocessing directive: %s", cmd);
   }

/*
 * pfatal(fmt,...) -- output a preprocessing error message.
 *
 *  We can't use tfatal() because we have our own line counter which may be
 *  out of sync with the lexical analyzer's.
 */
static void pfatal(char *fmt, ...)
{
    va_list argp;
    begin_link(stderr, canonicalize(curfile->fname), curfile->lno);
    fprintf(stderr, "File %s; Line %ld", curfile->fname, curfile->lno);
    end_link(stderr);
    fputs(" # ", stderr);
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    putc('\n', stderr);
    fflush(stderr);
    va_end(argp);
    tfatals++;
}

/*
 * errdir(s) -- handle deliberate $error.
 */
static char *errdir(char *s)
{
    pfatal("explicit $error: %s", rmnl(s));		/* issue msg with text */
    return NULL;
}

static char* rmnl(char *s)
{
    int n = strlen(s);
    if (n > 0 && s[n - 1] == '\n')
        s[n - 1] = 0;
    return s;
}


/*
 * define(s) -- handle $define directive.
 */
static char *define(char *s)
   {
   char c, *name, *val;

   if (isalpha((unsigned char)(c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$define: missing name";
   if (*s == '(')
      return "$define: \"(\" after name requires preceding space";
   val = s = wskip(s);
   if (*s != '\0') {
      while ((c = *s) != '\0' && c != '#') {	/* scan value */
         if (c == '"' || c == '\'') {
            s = matchq(s);
            if (*s == '\0')
               return "$define: unterminated literal";
            }
         s++;
         }
      while (isspace((unsigned char)s[-1]))			/* trim trailing whitespace */
         s--;
      }
   *s = '\0';
   dinsert(name, val);		/* install in table */
   return NULL;
   }

/*
 * Adapted from rmisc.r; should give the same result as image(s) for a string s.
 */

static int charstr(int c, char *b)
{
    static char cbuf[12];
    if (c < 128 && isprint((unsigned char)c)) {
        /*
         * c is printable, but special case ", ', - and \.
         */
        switch (c) {
            case '"':
                memcpy(b, "\\\"", 2);
                return 2;
            case '\\':
                memcpy(b, "\\\\", 2);
                return 2;
            default:
                *b = c;
                return 1;
        }
    }

    /*
     * c is some sort of unprintable character.	If it one of the common
     *  ones, produce a special representation for it, otherwise, produce
     *  its hex value.
     */
    switch (c) {
        case '\b':			/* backspace */
            memcpy(b, "\\b", 2);
            return 2;

        case '\177':			/* delete */
            memcpy(b, "\\d", 2);
            return 2;
        case '\33':			/* escape */
            memcpy(b, "\\e", 2);
            return 2;
        case '\f':			/* form feed */
            memcpy(b, "\\f", 2);
            return 2;
        case '\n':			/* new line */
            memcpy(b, "\\n", 2);
            return 2;
        case '\r':     		/* carriage return b */
            memcpy(b, "\\r", 2);
            return 2;
        case '\t':			/* horizontal tab */
            memcpy(b, "\\t", 2);
            return 2;
        case '\13':			/* vertical tab */
            memcpy(b, "\\v", 2);
            return 2;
        default: {				/* hex escape sequence */
            sprintf(cbuf, "\\x%02x", c);
            memcpy(b, cbuf, 4);
            return 4;
        }
    }
}

static char *loadfile(char *fname, int *vlen, int ucs)
{
    FILE *f;
    int ch;
    int len, i, n;
    char *s;

    f = fopen(fname, ReadBinary);
    if (f == NULL)
        return 0;

    len = 1024;
    s = safe_zalloc(len);
    if (ucs) {
        *s = 'u';
        *(s + 1) = '\"';
        i = 2;
    } else {
        *s = '\"';
        i = 1;
    }
    while ((ch = getc(f)) != EOF) {
        /* Ensure enough room for maximum 4 bytes from charstr + 2 for
         * the closing quote and null byte */
        if (i >= len - 6) {
            len *= 2;
            s = safe_realloc(s, len);
        }
        n = charstr(ch, s + i);
        i += n;
    }
    s[i++] = '\"';
    s[i] = 0;

    if (ferror(f) != 0)
        equit("failed to read $load file %s", fname);

    fclose(f);
    *vlen = i;
    return s;
}

/*
 * load(s) -- handle $load directive.
 */
static char *load(char *s)
   {
   char c, *name, *val, *fname, *fullpath;
   int vlen = 0;

   if (isalpha((unsigned char)(c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$load: missing name";
   s = wskip(s);
   s = getfnm(fname = s - 1, s);
   if (*fname == '\0')
      return "$load: invalid file name";
   if (*wskip(s) != '\0')
      return "$load: too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
       pfatal("cannot find on path: %s", fname);
   else if ((val = loadfile(fullpath, &vlen, 0)))
       dinsert_pre(name, val, vlen);		/* install in table */
   else
       pfatal("cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * uload(s) -- handle $uload directive.
 */
static char *uload(char *s)
   {
   char c, *name, *val, *fname, *fullpath;
   int vlen = 0;

   if (isalpha((unsigned char)(c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$uload: missing name";
   s = wskip(s);
   s = getfnm(fname = s - 1, s);
   if (*fname == '\0')
      return "$uload: invalid file name";
   if (*wskip(s) != '\0')
      return "$uload: too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
       pfatal("cannot find on path: %s", fname);
   else if ((val = loadfile(fullpath, &vlen, 1)))
       dinsert_pre(name, val, vlen);		/* install in table */
   else
       pfatal("cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * undef(s) -- handle $undef directive.
 */
static char *undef(char *s)
   {
   char c, *name;

   if (isalpha((unsigned char)(c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$undef: missing name";
   if (*wskip(s) != '\0')
      return "$undef: too many arguments";
   dremove(name);
   return NULL;
   }

/*
 * include(s) -- handle $include directive.
 */
static char *include(char *s)
   {
   char *fname, *fullpath;

   s = getfnm(fname = s - 1, s);
   if (*fname == '\0')
      return "$include: invalid file name";
   if (*wskip(s) != '\0')
      return "$include: too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
      pfatal("cannot find on path: %s", fname);
   else if (!ppopen(fullpath, 0))
      pfatal("cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * setline(s) -- handle $line (or #line) directive.
 */
static char *setline(char *s)
{
    long n;
    char c, *fname = 0, *code = 0;

    if (!isdigit((unsigned char)(c = *s)))
        return "$line: no line number";
    n = c - '0';

    while (isdigit((unsigned char)(c = *++s)))		/* extract line number */
        n = 10 * n + c - '0';

    s = wskip(s);			/* skip whitespace */

    if (isalpha((unsigned char)(c = *s)) || c == '_' || c == '"') {	/* if filename */
        s = getfnm(fname = s - 1, s);			/* extract it */
        if (*fname == '\0')
            return "$line: invalid file name";
        s = wskip(s);			/* skip whitespace */
        if (isalpha((unsigned char)(c = *s))) {	/* if encoding */
            s = getencoding(code = s - 1, s);		/* get encoding name */
        }
    }

    if (*wskip(s) != '\0')
        return "$line: too many arguments";

    /* Set the changed fields */
    curfile->lno = n - 1;			
    if (fname) {
        char *t;
        /* If fname="/tmp/abc.icn" and we have "#line 100 "xyz.icn" then we set the new fname
         * to /tmp/xyz.icn, if it exists.
         */
        t = pathfind(intern(getdir(curfile->fname)), 0, fname, 0);
        if (t)
            fname = t;
        curfile->fname = intern(fname);
    }
    if (code)
        curfile->encoding = intern(code);

    pushline();
    return NULL;
}

/*
 * ifdef(s), ifndef(s) -- conditional processing if s is/isn't defined.
 */
static char *ifdef(char *s)
   {
   return ifxdef(s, 1);
   }

static char *ifndef(char *s)
   {
   return ifxdef(s, 0);
   }

/*
 * ifxdef(s) -- handle $ifdef (if n is 1) or $ifndef (if n is 0).
 */
static char *ifxdef(char *s, int f)
   {
   char c, *name;
   ifdepth++;
   if (isalpha((unsigned char)(c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$ifdef/$ifndef: missing name";
   if (*wskip(s) != '\0')
      return "$ifdef/$ifndef: too many arguments";
   for (;;) {
       if ((dquery(name, -1) != NULL) ^ f) {
           char *cmd;
           skipcode(1, 1, &cmd, &s);	/* skip to $else, $elsifdef, $elsifndef or $endif */

           if (strcmp(cmd, "elsifdef") != 0 && strcmp(cmd, "elsifndef") != 0)
               break;
           
           if (isalpha((unsigned char)(c = *s)) || c == '_')
               s = getidt(name = s - 1, s);		/* get name */
           else
               return "$elsifdef/$elsifndef: missing name";
           if (*wskip(s) != '\0')
               return "$elsifdef/$elsifndef: too many arguments";

           f = (strcmp(cmd, "elsifdef") == 0) ? 1 : 0;
       } else
           break;
   }
   return NULL;
   }

/*
 * elsedir(s) -- handle $else by skipping to $endif.
 */
static char *elsedir(char *s)
   {
   if (ifdepth <= curfile->ifdepth)
      return "unexpected $else";
   if (*s != '\0')
      pfatal ("extraneous arguments on $else/$endif: %s", rmnl(s));
   skipcode(0, 1, 0, 0);			/* skip the $else section */
   return NULL;
   }

/*
 * elsif(s) -- handle $elsif(n)def by skipping to $endif.
 */
static char *elsif(char *s)
   {
   if (ifdepth <= curfile->ifdepth)
      return "unexpected $elsifdef/$elsifndef";
   skipcode(0, 1, 0, 0);			/* skip the $elsif section */
   return NULL;
   }


/*
 * endif(s) -- handle $endif.
 */
static char *endif(char *s)
   {
   if (ifdepth <= curfile->ifdepth)
      return "unexpected $endif";
   if (*s != '\0')
      pfatal ("extraneous arguments on $else/$endif: %s", rmnl(s));
   ifdepth--;
   return NULL;
   }

/*
 * encoding(s) -- handle $encoding.
 */
static char *encoding(char *s)
   {
   char *code;
   if (isalpha((unsigned char)*s))
       s = getencoding(code = s - 1, s);		/* get encoding name */
   else
      return "$encoding: missing name";
   if (*wskip(s) != '\0')
      return "$encoding: too many arguments";
   curfile->encoding = intern(code);
   pushline();
   return NULL;
   }

/*
 * skipcode(doelse,report) -- skip code to $else (doelse=1) or $endif (=0).
 *
 *  If report is nonzero, generate #line directive at end of skip.
 */
static void skipcode(int doelse, int report, char **cmd0, char **args0)
{
    char c, *p, *cmd;

    while ((p = buf = rline(curfile->fp)) != NULL) {
        curfile->lno++;			/* bump line number */

        /*
         * Handle #line form encountered while skipping.
         */
        if (buf[1]=='l' && buf[2]=='i' && buf[3]=='n' && buf[4]=='e' &&
            buf[0]=='#' && buf[5]==' ') {
            ppdir(buf + 1);			/* interpret #line */
            continue;
        }

        /*
         * Check for any other kind of preprocessing directive.
         */
        while (isspace((unsigned char)(c = *p)))
            p++;				/* find first nonwhite */
        if (c != '$' || (ispunct((unsigned char)p[1]) && p[1]!=' '))
            continue;			/* not a preprocessing directive */
        p = wskip(p+1);			/* skip whitespace */
        p = getidt(cmd = p-1, p);		/* get command name */
        p = wskip(p);			/* skip whitespace */

        /*
         * Check for a directive that needs special attention.
         *  Deliberately accept any form of $if... as valid
         *  in anticipation of possible future extensions;
         *  this allows them to appear here if commented out.
         */
        if (cmd[0] == 'i' && cmd[1] == 'f') {
            ifdepth++;
            skipcode(0, 0, 0, 0);		/* skip to $endif */
        }
        else if (strcmp(cmd, "line") == 0)
            setline(p);			/* process $line, ignore errors */
        else if (strcmp(cmd, "endif") == 0 ||
                 (doelse == 1 && strncmp(cmd, "els", 3) == 0)) {
            /*
             * Time to stop skipping.
             */
            if (*p != '\0' &&
                (strcmp(cmd, "endif") == 0 || strcmp(cmd, "else") == 0))
                pfatal ("extraneous arguments on $else/$endif: %s", rmnl(p));

            if (cmd[1] == 'n')		/* if $endif */
                ifdepth--;
            if (report)
                pushline();
            if (cmd0)
                *cmd0 = cmd;
            if (args0)
                *args0 = p;
            return;
        }
    }
     
    /*
     *  At EOF, just return; main loop will report unterminated $if.
     */
    if (cmd0)
        *cmd0 = "";
    if (args0)
        *args0 = "";
}

/*
 * Token scanning functions.
 */

/*
 * wskip(s) -- skip whitespace and return updated pointer
 *
 *  If '#' is encountered, skips to end of string.
 */
static char *wskip(char *s)
   {
   char c;

   while (isspace((unsigned char)(c = *s)))
      s++;
   if (c == '#')
      while ((c = *++s) != 0)
         ;
   return s;
   }

/*
 * nskip(s) -- skip over numeric constant and return updated pointer.
 */
static char *nskip(char *s)
   {
      char c;

      while (isdigit((unsigned char)(c = *++s)))
         ;
      if (c == 'r' || c == 'R') {
         while (isalnum((unsigned char)(c = *++s)))
            ;
         return s;
         }
      if (c == '.')
         while (isdigit((unsigned char)(c = *++s)))
            ;
      if (c == 'e' || c == 'E') {
         c = s[1];
         if (c == '+' || c == '-')
            s++;
         while (isdigit((unsigned char)(c = *++s)))
            ;
         }
      return s;
   }

/*
 * matchq(s) -- scan for matching quote character and return pointer.
 *
 *  Taking *s as the quote character, s is incremented until it points
 *  to either another occurrence of the character or the '\0' terminating
 *  the string.  Escaped quote characters do not stop the scan.  The
 *  updated pointer is returned.
 */
static char *matchq(char *s)
   {
   char c, q;

   q = *s;
   if (q == '\0')
      return s;
   while ((c = *++s) != q && c != '\0') {
      if (c == '\\')
         if (*++s == '\0')
            return s;
      }
   return s;
   }

/*
 * getidt(dst,src) -- extract identifier, return updated pointer
 *
 *  The identifier (in Icon terms, "many(&letters++&digits++'_')")
 *  at src is copied to dst and '\0' is appended.  A pointer to the
 *  character following the identifier is returned.
 *
 *  dst may partially overlap src if dst has a lower address.  This
 *  is typically done to avoid the need for another arbitrarily-long
 *  buffer.  An offset of -1 allows room for insertion of the '\0'.
 */
static char *getidt(char *dst, char *src)
   {
   char c;

   while (isalnum((unsigned char)(c = *src)) || (c == '_')) {
      *dst++ = c;
      src++;
      }
   *dst = '\0';
   return src;
   }

/*
 * As above, but slightly different permissible chars.
 */
static char *getencoding(char *dst, char *src)
   {
   char c;

   while (isalnum((unsigned char)(c = *src)) || (c == '-')) {
      *dst++ = c;
      src++;
      }
   *dst = '\0';
   return src;
   }

/*
 * getfnm(dst,src) -- extract filename, return updated pointer
 *
 *  Similarly to getidt, getfnm extracts a quoted or unquoted file name.
 *  An empty string at dst indicates a missing or unterminated file name.
 */
static char *getfnm(char *dst, char *src)
   {
       char *lim, c;

   if (*src != '"')
      return getidt(dst, src);

   lim = src;
   while ((c = *++lim) != '"' && c != '\0');

   if (*lim != '"') {
      *dst = '\0';
      return lim;
      }
   while (++src < lim)
       *dst++ = *src;
   *dst = '\0';
   return lim + 1;
   }

static void freecdefn(cdefn *d)
{
    free(d->name);
    free(d->val);
    free(d);
}

static cdefn *dquery(char *name, int len)
{
    int h, i;
    unsigned int t;
    cdefn *d, **p;
    if (len < 0)
        len = strlen(name);
    if (len == 0)
        return NULL;
    for (t = i = 0; i < len; i++)
        t = 37 * t + (name[i] & 0xFF);	/* calc hash value */
    h = t % HTBINS;			/* calc bin number */
    p = &cbin[h];			/* get head of list */
    while ((d = *p) != NULL) {
        if (d->nlen == len && strncmp(name, d->name, len) == 0)
            return d;			/* return pointer to entry */
        p = &d->next;
    }
    /*
     * No match
     */
    return NULL;
}

static void dremove(char *name)
{
    int nlen, h, i;
    unsigned int t;
    cdefn *d, **p;
    nlen = strlen(name);
    if (nlen == 0)
        return;
    for (t = i = 0; i < nlen; i++)
        t = 37 * t + (name[i] & 0xFF);	/* calc hash value */
    h = t % HTBINS;			/* calc bin number */
    p = &cbin[h];			/* get head of list */
    while ((d = *p) != NULL) {
        if (d->nlen == nlen && strncmp(name, d->name, nlen) == 0) {
            *p = d->next;		/* delete from table */
            freecdefn(d);
            return;
        }
        p = &d->next;
    }
}

static void dinsert(char *name, char *val)
{
    int h, i, nlen, vlen;
    unsigned int t;
    cdefn *d, **p;
    nlen = strlen(name);
    if (nlen == 0)
        return;
    vlen = strlen(val);
    for (t = i = 0; i < nlen; i++)
        t = 37 * t + (name[i] & 0xFF);	/* calc hash value */
    h = t % HTBINS;			/* calc bin number */
    p = &cbin[h];			/* get head of list */
    while ((d = *p) != NULL) {
        if (d->nlen == nlen && strncmp(name, d->name, nlen) == 0) {
            /*
             * We found a match in the table.
             */
            if (strcmp(val, d->val) != 0) 
                pfatal("value redefined: %s", name);
            return;
        }
        p = &d->next;
    }
    d = safe_zalloc(sizeof(*d));
    d->nlen = nlen;
    d->vlen = vlen;
    d->inuse = 0;
    d->name = salloc(name);
    d->val = salloc(val);
    d->prev = NULL;
    d->next = cbin[h];
    if (d->next != NULL)
        d->next->prev = d;
    cbin[h] = d;
}

/*
 * Like dinsert, but val is pre-allocated and its length given.
 */
static void dinsert_pre(char *name, char *val, int vlen)
{
    int h, i, nlen;
    unsigned int t;
    cdefn *d, **p;
    nlen = strlen(name);
    if (nlen == 0)
        return;
    for (t = i = 0; i < nlen; i++)
        t = 37 * t + (name[i] & 0xFF);	/* calc hash value */
    h = t % HTBINS;			/* calc bin number */
    p = &cbin[h];			/* get head of list */
    while ((d = *p) != NULL) {
        if (d->nlen == nlen && strncmp(name, d->name, nlen) == 0) {
            /*
             * We found a match in the table.
             */
            if (strcmp(val, d->val) != 0) 
                pfatal("value redefined: %s", name);
            return;
        }
        p = &d->next;
    }
    d = safe_zalloc(sizeof(*d));
    d->nlen = nlen;
    d->vlen = vlen;
    d->inuse = 0;
    d->name = salloc(name);
    d->val = val;
    d->prev = NULL;
    d->next = cbin[h];
    if (d->next != NULL)
        d->next->prev = d;
    cbin[h] = d;
}
