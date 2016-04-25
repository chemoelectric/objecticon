/*
 * The functions in this file print error messages.
 */
#include "rtt.h"

/*
 * Prototypes for static functions.
 */
static void rm_files (void);


/*
 * File list.
 */
struct finfo_lst {
   char *name;                  /* file name */
   FILE *file;                  /* file */
   struct finfo_lst *next;      /* next entry in list */
   };

static struct finfo_lst *file_lst = NULL;


void err(char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr,"%s: ",progname);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    rm_files();
    exit(EXIT_FAILURE);
}

void err_loc(char *file, int line, char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr, "%s: File %s; Line %d: ", progname, file, line);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    rm_files();
    exit(EXIT_FAILURE);
}

void err_tok(struct token *t, char *fmt, ...)
{
    va_list argp;
    va_start(argp, fmt);
    fprintf(stderr, "%s: File %s; Line %d: ", progname, t->fname, t->line);
    vfprintf(stderr, fmt, argp);
    fprintf(stderr,"\n");
    fflush(stderr);
    va_end(argp);
    rm_files();
    exit(EXIT_FAILURE);
}


/*
 * errt1 - error message in one string, location indicated by a token.
 */
void errt1(struct token *t, char *s)
   {
   errfl1(t->fname, t->line, s);
   }

/*
 * errfl1 - error message in one string, location given by file and line.
 */
void errfl1(char *f, int l, char *s)
   {
       err_loc(f, l, "%s", s);
   }

/*
 * err1 - error message in one string, no location given
 */
void err1(char *s)
   {
       err("%s", s);
   }

/*
 * errt2 - error message in two strings, location indicated by a token.
 */
void errt2(struct token *t, char *s1, char *s2)
   {
   errfl2(t->fname, t->line, s1, s2);
   }

/*
 * errfl2 - error message in two strings, location given by file and line.
 */
void errfl2(char *f, int l, char *s1, char *s2)
   {
       err_loc(f, l, "%s%s", s1, s2);
   }

/*
 * err2 - error message in two strings, no location given
 */
void err2(char *s1, char *s2)
   {
       err("%s%s", s1, s2);
   }

/*
 * errt3 - error message in three strings, location indicated by a token.
 */
void errt3(struct token *t, char *s1, char *s2, char *s3)
   {
   errfl3(t->fname, t->line, s1, s2, s3);
   }

/*
 * errfl3 - error message in three strings, location given by file and line.
 */
void errfl3(char *f, int l, char *s1, char *s2, char *s3)
   {
       err_loc(f, l, "%s%s%s", s1, s2, s3);
   }

/*
 * addrmlst - add a file name to the list of files to be removed if
 *   an error occurs.
 */
void addrmlst(fname, f)
char *fname;
FILE *f;
   {
   struct finfo_lst *id;

   id = Alloc(struct finfo_lst);
   id->name = fname;
   id->file = f;
   id->next = file_lst;
   file_lst = id;
   }

/*
 * rm_files - remove files that must be cleaned up in the event of an
 *   error.
 */
static void rm_files()
   {
   while (file_lst != NULL) {
      if (file_lst->file != NULL)
         fclose ( file_lst->file );
      remove(file_lst->name);
      file_lst = file_lst->next;
      }
   }

void markrmlst(FILE *closefile)
{
  struct finfo_lst *f = file_lst;
  for(f=file_lst;f!=NULL;f=f->next)
    if (f->file == closefile) f->file = NULL;
}

int rmlst_empty_p()
{
  return file_lst == NULL;
}
