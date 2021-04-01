/*
 * ipp.c -- the Icon preprocessor.
 *
 *  All Icon source passes through here before translation or compilation.
 *  Directives recognized are:
 *	#line n [filename]
 *	$line n [filename]
 *	$include filename
 *	$load identifier filename
 *	$uload identifier filename
 *	$define identifier text
 *	$undef identifier
 *	$if expression
 *	$elsif expression
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

typedef struct fstruct {		/* input file structure */
   struct fstruct *prev;		/* previous file */
   char *fname;				/* file name */
   char *sc_fname;			/* standard-cased (original) fname */
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

typedef struct cd {			/* structure holding a definition */
   struct cd *next;			/* link to next defn */
   int nlen, vlen;			/* length of name & val */
   char inuse;				/* nonzero if curr being expanded */
   char *name;                          /* name */
   char *val;                           /* value */
   } cdefn;


static uword hashstr(char *s, int len);
static uword cdefn_hashstr(cdefn *p);
static int ppopen  (char *fname, int m4);
static FILE *m4pipe  (char *fname);
static char *rmnl    (char *s);
static char *rline   (FILE *fp);
static void pushdef (cdefn *d);
static void pushline (void);
static void ppdir   (char *line);
static void pfatal(char *fmt, ...);
static void skipcode (int doelse, int report, char **cmd0, char **args0);
static char *define  (char *s);
static char *undef   (char *s);
static char *ifdir   (char *s);
static char *elsifdir(char *s);
static char *elsedir (char *s);
static char *endif   (char *s);
static char *encoding(char *s);
static char *load    (char *s);
static char *uload   (char *s);
static char *errdir  (char *s);
static char *include (char *s);
static char *setline (char *s);
static char *setline1(char *s, int report);
static char *wskip   (char *s);
static char *nskip   (char *s);
static char *matchq  (char *s);
static char *getidt  (char *dst, char *src);
static char *getencoding(char *dst, char *src);
static char *getfnm  (char *dst, char *src);
static void freecdefn(cdefn *d);
static int eqname(cdefn *d, char *name, int len);
static int eqval(cdefn *d, char *val, int vlen);
static cdefn *dquery(char *name, int len);
static void dremove(char *name);
static void dinsert(char *name, char *val);
static void dinsert_pre(char *name, char *val, int vlen);
static char *skipstring(char q, char *s);
static int multistart(char *s);
static char *evalexpr(char *s, int *val);
static char *evalexpr1(char **ss, int *val);
static char *evalexpr2(char **ss, int *val);
static char *evalexpr3(char **ss, int *val);

/*
 * Hash table for macro definitions.
 */
static DefineHash(, cdefn) cbin = { 64, cdefn_hashstr };

struct ppcmd {
   char *name;
   char *(*func)(char *);
   }
pplist[] = {
   { "define",  define  },
   { "undef",   undef   },
   { "if",      ifdir   },
   { "elsif",   elsifdir   },
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

static char *lpath;				/* LPATH for finding source files */

static int ifdepth;			/* depth of $if nesting */
static int quoting;
static char *last_line_file, 
            *last_line_encoding;        /* last file/encoding on a #line directive */


/*
 * ppinit(fname, m4) -- initialize preprocessor to read from fname.
 *
 *  Returns 1 if successful, 0 if open failed.
 */
int ppinit(char *fname, int m4)
   {
   static int inited;
   int i;
   cdefn *d, *n;

    if (!inited) {
        lpath = getenv_nn("OI_INCL");
        if (lpath)
            lpath = salloc(lpath);
        inited = 1;
    }

   /*
    * clear out any existing definitions from previous files
    */
   for (i = 0; i < cbin.nbuckets; i++) {
       d = cbin.l[i];
       while (d) {
           n = d;
           d = d->next;
           freecdefn(n);
       }
   }
   clear_hash(&cbin);

   /*
    * install predefined symbols
    */
#define Feature(symname,kwval) dinsert(symname, "1");
#include "../h/features.h"

   /*
    * initialize variables and open source file 
    */
   curfile = &nofile;			/* init file struct pointer */
   last_line_file = last_line_encoding = 0;
   quoting = 0;
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
   char *sc_fname;

   fname = intern(fname);
   sc_fname = intern_standard_case(fname);
   for (fs = curfile; fs->sc_fname != NULL; fs = fs->prev) {
      if (sc_fname == fs->sc_fname) {
         pfatal("Circular include: %s", fname);	/* issue error message */
         return 1;				/* treat as success */
         }
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
   fs = Alloc1(infile);
   fs->prev = curfile;
   fs->fp = f;
   fs->fname = fname;
   fs->sc_fname = sc_fname;
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
      char *s = safe_malloc(7 + strlen(filename));
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
          if (quoting) {
             /*
              * We are on a string literal continuation line; search for end of
              * the string.
              */
             p = skipstring(quoting, bnxt);		/* skip to end */
             if (p) {
                bstop = p;
                quoting = 0;                            /* found end of string (may be end of line) */
                }
             else {
                bstop = blim;                           /* another continuation line follows */
             }
             continue;                           /* go round to top to return first char */
            }
         f = *bnxt & 0xFF;
         if ((oi_isalpha(f) || f == '_') && !(f == 'u' && *(bnxt + 1) == '"')) {
            /*
             * This is the first character of an identifier.  It could
             *  be the name of a definition.  If so, the name will be
             *  contiguous in this buffer.  Check it.
             */
            p = bnxt + 1;
            while (p < blim && (oi_isalnum((c = *p)) || c == '_'))	/* find end */
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
               if (c == 'u' && *(p + 1) == '"') {  /* ucs literal */
                  p = skipstring('"', p + 2);		/* skip to end */
                  if (!p) {
                     quoting = '"';
                     break;
                     }
               }
               else if (oi_isalpha(c) || c == '_') {	/* there's an id ahead */
                  bstop = p;
                  return f;
                  }
               else if (oi_isdigit(c)) {		/* numeric constant */
                  p = nskip(p);
                  }
               else if (c == '#') {		/* comment: skip to EOL */
                  bstop = blim;
                  return f;
                  }
               else if (c == '"' || c == '\'') {	/* quoted literal */
                  p = skipstring(c, p + 1);		/* skip to end */
                  if (!p) {
                     quoting = c;
                     break;
                     }
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
         if (quoting) {
            /*
             * We're in a multi-line quote
             */
            bnxt = buf;
            blim = buf + strlen(buf);
            bstop = bnxt;			/* no chars scanned yet */
            }
         else {
            while (oi_isspace((c = *p)))
               p++;				/* find first nonwhite */
            if (c == '$' && (!oi_ispunct(p[1]) || p[1]==' '))
               ppdir(p + 1);			/* handle preprocessor cmd */
            else if (strncmp(buf, "#line ", 6) == 0)
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
         }
   
      else {
         /*
          * The read hit EOF.
          */
         if (curfile->ifdepth != ifdepth) {
            pfatal("Unterminated $if");
            ifdepth = curfile->ifdepth;
            }

         quoting = 0;

         /*
          * switch to previous file and close current file.
          */
         fs = curfile;
         curfile = fs->prev;

         if (ferror(fs->fp) != 0)
            equit("Failed to read from source file %s", fs->fname);

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
      lbuf = safe_malloc(LINE_SIZE_INIT);
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
      b = Alloc1(buffer);
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

   pfatal("Invalid preprocessing directive: %s", cmd);
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
    char *p = intern(canonicalize(curfile->fname));
    begin_link(stderr, p, curfile->lno);
    fprintf(stderr, "File %s; Line %ld", abbreviate(p), curfile->lno);
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
    pfatal("Explicit $error: %s", rmnl(s));		/* issue msg with text */
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

   if (oi_isalpha((c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$define: Missing name";
   if (*s == '(')
      return "$define: \"(\" after name requires preceding space";
   val = s = wskip(s);
   if (*s != '\0') {
      while ((c = *s) != '\0' && c != '#') {	/* scan value */
         if (c == '"' || c == '\'') {
            s = matchq(s);
            if (*s == '\0')
               return "$define: Unterminated literal";
            }
         s++;
         }
      while (oi_isspace(s[-1]))			/* trim trailing whitespace */
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
    if (c < 128 && oi_isprint(c)) {
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
    s = safe_malloc(len);
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
        if (i > 24 * 1024 * 1024) {
            pfatal("File too big: %s", fname);
            break;
        }
    }
    s[i++] = '\"';
    s[i] = 0;

    if (ferror(f) != 0)
        equit("Failed to read $load file %s", fname);

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

   if (oi_isalpha((c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$load: Missing name";
   s = wskip(s);
   s = getfnm(fname = s - 1, s);
   if (*fname == '\0')
      return "$load: Invalid file name";
   if (*wskip(s) != '\0')
      return "$load: Too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
       pfatal("Cannot find on path: %s", fname);
   else if ((val = loadfile(fullpath, &vlen, 0)))
       dinsert_pre(name, val, vlen);		/* install in table */
   else
       pfatal("Cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * uload(s) -- handle $uload directive.
 */
static char *uload(char *s)
   {
   char c, *name, *val, *fname, *fullpath;
   int vlen = 0;

   if (oi_isalpha((c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$uload: Missing name";
   s = wskip(s);
   s = getfnm(fname = s - 1, s);
   if (*fname == '\0')
      return "$uload: Invalid file name";
   if (*wskip(s) != '\0')
      return "$uload: Too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
       pfatal("Cannot find on path: %s", fname);
   else if ((val = loadfile(fullpath, &vlen, 1)))
       dinsert_pre(name, val, vlen);		/* install in table */
   else
       pfatal("Cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * undef(s) -- handle $undef directive.
 */
static char *undef(char *s)
   {
   char c, *name;

   if (oi_isalpha((c = *s)) || c == '_')
      s = getidt(name = s - 1, s);		/* get name */
   else
      return "$undef: Missing name";
   if (*wskip(s) != '\0')
      return "$undef: Too many arguments";
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
      return "$include: Invalid file name";
   if (*wskip(s) != '\0')
      return "$include: Too many arguments";
   fullpath = pathfind(intern(getdir(curfile->fname)), lpath, fname, 0);
   if (!fullpath)
      pfatal("Cannot find on path: %s", fname);
   else if (!ppopen(fullpath, 0))
      pfatal("Cannot open: %s: %s", fullpath, get_system_error());
   return NULL;
   }

/*
 * setline1(s) -- handle $line (or #line) directive.
 */
static char *setline1(char *s, int report)
{
    long n;
    char c, *fname = 0, *code = 0;

    if (!oi_isdigit((c = *s)))
        return "$line: No line number";
    n = c - '0';

    while (oi_isdigit((c = *++s)))		/* extract line number */
        n = 10 * n + c - '0';

    s = wskip(s);			/* skip whitespace */

    if (oi_isalpha((c = *s)) || c == '_' || c == '"') {	/* if filename */
        s = getfnm(fname = s - 1, s);			/* extract it */
        if (*fname == '\0')
            return "$line: Invalid file name";
        s = wskip(s);			/* skip whitespace */
        if (oi_isalpha(*s)) {	/* if encoding */
            s = getencoding(code = s - 1, s);		/* get encoding name */
        }
    }

    if (*wskip(s) != '\0')
        return "$line: Too many arguments";

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
        /* Note that we leave sc_fname alone deliberately; so that we
         * check for circular includes against the actual opened
         * filename. */
        curfile->fname = intern(fname);
    }
    if (code)
        curfile->encoding = intern(code);

    if (report)
        pushline();
    return NULL;
}

/*
 * setline(s) -- handle $line (or #line) directive.
 */
static char *setline(char *s)
{
    return setline1(s, 1);
}

/*
 * ifdir(s) -- handle $if
 */
static char *ifdir(char *s)
   {
   char *r;
   int val;

   ifdepth++;
   if ((r = evalexpr(s, &val)))
       return r;
   while (!val) {
       char *cmd;
       skipcode(1, 1, &cmd, &s);	/* skip to $else, $elsif or $endif */

       if (strcmp(cmd, "elsif") != 0)
           break;

       if ((r = evalexpr(s, &val)))
           return r;
       }
   return NULL;
   }

/*
 * elsedir(s) -- handle $else by skipping to $endif.
 */
static char *elsedir(char *s)
   {
   if (ifdepth <= curfile->ifdepth)
      return "Unexpected $else";
   if (*s != '\0')
      pfatal ("Extraneous arguments on $else/$endif: %s", rmnl(s));
   skipcode(0, 1, 0, 0);			/* skip the $else section */
   return NULL;
   }

/*
 * elsifdir(s) -- handle $elsif by skipping to $endif.
 */
static char *elsifdir(char *s)
   {
   char *r;
   int val;
   if (ifdepth <= curfile->ifdepth)
      return "Unexpected $elsif";

   /* Check for valid syntax. */
   r =  evalexpr(s, &val);

   skipcode(0, 1, 0, 0);			/* skip the $elsif section */

   return r;
   }

/*
 * endif(s) -- handle $endif.
 */
static char *endif(char *s)
   {
   if (ifdepth <= curfile->ifdepth)
      return "Unexpected $endif";
   if (*s != '\0')
      pfatal ("Extraneous arguments on $else/$endif: %s", rmnl(s));
   ifdepth--;
   return NULL;
   }

/*
 * encoding(s) -- handle $encoding.
 */
static char *encoding(char *s)
   {
   char *code;
   if (oi_isalpha(*s))
       s = getencoding(code = s - 1, s);		/* get encoding name */
   else
      return "$encoding: Missing name";
   if (*wskip(s) != '\0')
      return "$encoding: Too many arguments";
   curfile->encoding = intern(code);
   pushline();
   return NULL;
   }
   
/*
 * If this line ends on a multi-line literal, return the
 * relevant opening quote char; otherwise return 0.
 * Eg :-
 *    abc 'def' "xyz_  -> returns "
 *    abc 'def' "xyz"  -> returns 0
 */
static int multistart(char *s)
{
   char c;
   while (*s) {
       c = *s++;
       if (c == '\'' || c == '\"') {
           s = skipstring(c, s);
           if (!s)
               return c;
       }
   }
   return 0;
}

/*
 * Skip a string/cset literal. q is " or ', and s should be just
 * after the opening quote.  Returns a pointer to just after the
 * closing quote, or at end of line if not closing quote was found.
 * 
 * Returns 0 iff the literal is a multi-line, ie the end is not
 * in the string.
 *
 * Examples (q=") :-
 *  one"blah -> returns a pointer to the 'b'.
 *  noquote -> returns a pointer to the \0 at the end.
 *  noend_ -> returns 0.
 */
static char *skipstring(char q, char *s)
{
   char c;
   while (*s) {
       c = *s++;
       if (c == '_') {
           if (*s == '\n' && *(s + 1) == '\0')
               return 0;
       } else if (c == '\\') {
           if (*s)
               ++s;
       } else if (c == q)
           return s;
   }
   return s;
}

/*
 * skipcode(doelse,report) -- skip code to $else (doelse=1) or $endif (=0).
 *
 *  If report is nonzero, generate #line directive at end of skip.
 */
static void skipcode(int doelse, int report, char **cmd0, char **args0)
{
    char c, *p, *cmd;
    int quoting = 0;

    while ((p = buf = rline(curfile->fp)) != NULL) {
        curfile->lno++;			/* bump line number */

        if (quoting) {
            char *p;
            p = skipstring(quoting, buf);
            if (p)
                quoting = multistart(p);
            continue;
        }

        /*
         * Handle #line form encountered while skipping.
         */
        if (strncmp(buf, "#line ", 6) == 0) {
            ppdir(buf + 1);			/* interpret #line */
            continue;
        }

        /*
         * Check for any other kind of preprocessing directive.
         */
        while (oi_isspace((c = *p)))
            p++;				/* find first nonwhite */
        if (c != '$' || (oi_ispunct(p[1]) && p[1]!=' ')) {
            /* Not a preprocessing directive */
            /* Check for multi-line string */
            quoting = multistart(buf);
            continue;
        }
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
            setline1(p, 0);			/* process $line, ignore errors */
        else if (strcmp(cmd, "endif") == 0 ||
                 (doelse == 1 && strncmp(cmd, "els", 3) == 0)) {
            /*
             * Time to stop skipping.
             */
            if (*p != '\0' &&
                (strcmp(cmd, "endif") == 0 || strcmp(cmd, "else") == 0))
                pfatal ("Extraneous arguments on $else/$endif: %s", rmnl(p));

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


    /*
     * Since bnxt will be set to point to a "\n" (see ppdir), that
     * would create an extra line of output (normally this replaces an
     * erroneous directive.  We don't have a directive in this case,
     * so set to the empty string.
     */
    bnxt = "";
    bstop = blim = bnxt;
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

   while (oi_isspace((c = *s)))
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

      while (oi_isdigit((c = *++s)))
         ;
      if (c == 'r' || c == 'R') {
         while (oi_isalnum((c = *++s)))
            ;
         return s;
         }
      if (c == '.')
         while (oi_isdigit((c = *++s)))
            ;
      if (c == 'e' || c == 'E') {
         c = s[1];
         if (c == '+' || c == '-')
            s++;
         while (oi_isdigit((c = *++s)))
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

   while (oi_isalnum((c = *src)) || (c == '_')) {
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

   while (oi_isalnum((c = *src)) || (c == '-')) {
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

static uword hashstr(char *s, int len)
{
    uword h;
    h = 0;
    if (len > 5) len = 5;
    while (len-- > 0) {
        h = 37 * h + (*s & 0377);
        ++s;
    }
    return h;
}

static uword cdefn_hashstr(cdefn *p)
{
    return hashstr(p->name, p->nlen);
}

static int eqname(cdefn *d, char *name, int len)
{
    return (d->nlen == len && memcmp(name, d->name, len) == 0);
}

static int eqval(cdefn *d, char *val, int vlen)
{
    return (d->vlen == vlen && memcmp(val, d->val, vlen) == 0);
}

static cdefn *dquery(char *name, int len)
{
    cdefn *d;
    for (d = Bucket(cbin, hashstr(name, len)); d; d = d->next)
        if (eqname(d, name, len))
            return d;			/* return pointer to entry */
    /*
     * No match
     */
    return NULL;
}

static void dremove(char *name)
{
    int nlen;
    cdefn *d, **p;
    uword h;
    if (cbin.nbuckets == 0)
        return;
    nlen = strlen(name);
    h = hashstr(name, nlen);
    p = &cbin.l[h % cbin.nbuckets];
    while ((d = *p)) {
        if (eqname(d, name, nlen)) {
            *p = d->next;		/* delete from table */
            freecdefn(d);
            --cbin.size;
            return;
        }
        p = &d->next;
    }
}

static void dinsert(char *name, char *val)
{
    int nlen, vlen;
    cdefn *d;
    uword h;
    nlen = strlen(name);
    vlen = strlen(val);
    h = hashstr(name, nlen);
    for (d = Bucket(cbin, h); d; d = d->next) {
        if (eqname(d, name, nlen)) {
            /*
             * We found a match in the table.
             */
            if (!eqval(d, val, vlen))
                pfatal("Value redefined: %s", name);
            return;
        }
    }
    d = Alloc1(*d);
    d->nlen = nlen;
    d->vlen = vlen;
    d->inuse = 0;
    d->name = salloc(name);
    d->val = salloc(val);
    add_to_hash_pre(&cbin, d, h);
}

/*
 * Like dinsert, but val is pre-allocated and its length given.
 */
static void dinsert_pre(char *name, char *val, int vlen)
{
    int nlen;
    cdefn *d;
    uword h;
    nlen = strlen(name);
    h = hashstr(name, nlen);
    for (d = Bucket(cbin, h); d; d = d->next) {
        if (eqname(d, name, nlen)) {
            /*
             * We found a match in the table.
             */
            if (!eqval(d, val, vlen))
                pfatal("Value redefined: %s", name);
            return;
        }
    }
    d = Alloc1(*d);
    d->nlen = nlen;
    d->vlen = vlen;
    d->inuse = 0;
    d->name = salloc(name);
    d->val = val;
    add_to_hash_pre(&cbin, d, h);
}

/*
 * Evaluate a logical expression in an $if or $elsif line.  s is the
 * start of the expression, the boolean value is returned in *val.  On
 * error, the message is returned; on success NULL is returned.
 */
static char *evalexpr(char *s, int *val)
{
    char *r;
    if ((r = evalexpr1(&s, val)))
        return r;
    s = wskip(s);			/* skip whitespace */
    if (*s != '\0')
        return "$if/$elsif: Extraneous characters";
    return NULL;
}

static char *evalexpr1(char **ss, int *val)
{
    char *r;
    int v;
    if ((r = evalexpr2(ss, val)))
        return r;
    for (;;) {
        *ss = wskip(*ss);			/* skip whitespace */
        if (**ss != '|')
            break;
        ++*ss;
        if ((r = evalexpr2(ss, &v)))
            return r;
        *val = (*val || v);
    }
    return NULL;
}

static char *evalexpr2(char **ss, int *val)
{
    char *r;
    int v;
    if ((r = evalexpr3(ss, val)))
        return r;
    for (;;) {
        *ss = wskip(*ss);			/* skip whitespace */
        if (**ss != '&')
            break;
        ++*ss;
        if ((r = evalexpr3(ss, &v)))
            return r;
        *val = (*val && v);
    }
    return NULL;
}

static char *evalexpr3(char **ss, int *val)
{
    char c, *name, *r;
    int v;
    *ss = wskip(*ss);			/* skip whitespace */
    if (**ss == '\0')
        return "$if/$elsif: Identifier expected";
    c = **ss;
    if (oi_isalpha(c) || c == '_') {
        *ss = getidt(name = *ss - 1, *ss);		/* get name */
        *val = (dquery(name, strlen(name)) != NULL);
    } else {
        ++*ss;
        switch (c) {
            case '~' : {
                if ((r = evalexpr3(ss, &v)))
                    return r;
                *val = !v;
                break;
            }
            case '(' : {
                if ((r = evalexpr1(ss, val)))
                    return r;
                *ss = wskip(*ss);			/* skip whitespace */
                if (**ss != ')')
                    return "$if/$elsif: ) expected";
                ++*ss;
                break;
            }
            default:
                return "$if/$elsif: Unexpected character";
        }
    }
    return NULL;
}
