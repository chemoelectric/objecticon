/*
 * rttdb.c - routines to read, manipulate, and write the data base of
 *  information about run-time routines.
 */

#include "rtt.h"
#include "../h/version.h"

#define DHSize 47
#define MaxLine 80

/*
 * prototypes for static functions.
 */
static void max_pre   (struct implement **tbl, char *pre);
static int     set_impl  (struct token *name, struct implement **tbl,
                           int num_impl, char *pre);
static void set_prms  (struct implement *ptr);

static struct implement *bhash[IHSize];	/* hash area for built-in func table */
static struct implement *ohash[IHSize]; /* hash area for operator table */
static struct implement *khash[IHSize];	/* hash area for keyword table */

static struct srcfile *dhash[DHSize];	/* hash area for file dependencies */

static int num_fnc;		/* number of function in data base */
static int num_op = 0;		/* number of operators in data base */
static int num_key;		/* number of keywords in data base */
static int num_src = 0;		/* number of source files in dependencies */

static char fnc_pre[2];		/* next prefix available for functions */
static char op_pre[2];		/* next prefix available for operators */
static char key_pre[2];		/* next prefix available for keywords */

static long min_rs;		/* min result sequence of current operation */
static long max_rs;		/* max result sequence of current operation */
static int rsm_rs;		/* '+' at end of result sequencce of cur. oper. */

static int newdb = 0;		/* flag: this is a new data base */
struct token *comment;		/* comment associated with current operation */
struct implement *cur_impl;	/* data base entry for current operation */

/*
 * loaddb - load data base.
 */
void loaddb(dbname)
char *dbname;
   {
   int i;

   /*
    * Initialize internal data base.
    */
   for (i = 0; i < IHSize; i++) {
       bhash[i] = NULL;   /* built-in function table */
       ohash[i] = NULL;   /* operator table */
       khash[i] = NULL;   /* keyword table */
       }
   for (i = 0; i < DHSize; i++)
       dhash[i] = NULL;   /* dependency table */

   /*
    * Determine if this is a new data base or an existing one.
    */
   newdb = 1;

   /*
    * Determine the next available operation prefixes by finding the
    *  maximum prefixes currently in use.
    */
   max_pre(bhash, fnc_pre);
   max_pre(ohash, op_pre);
   max_pre(khash, key_pre);
   }

/*
 * max_pre - find the maximum prefix in an implemetation table and set the
 *  prefix array to the next value.
 */
static void max_pre(tbl, pre)
struct implement **tbl;
char *pre;
   {
   register struct implement *ptr;
   unsigned hashval;
   int empty = 1;
   char dmy_pre[2];

   pre[0] = '0';
   pre[1] = '0';
   for (hashval = 0; hashval < IHSize; ++hashval) 
      for (ptr = tbl[hashval]; ptr != NULL; ptr = ptr->blink) {
         empty = 0;
         /*
          * Determine if this prefix is larger than any found so far.
          */
         if (cmp_pre(ptr->prefix, pre) > 0) {
            pre[0] = ptr->prefix[0];
            pre[1] = ptr->prefix[1];
            }
         }
   if (!empty)
      nxt_pre(dmy_pre, pre, 2);
   }


/*
 * src_lkup - return pointer to dependency information for the given
 *   source file.
 */
struct srcfile *src_lkup(srcname)
char *srcname;
   {
   unsigned hashval;
   struct srcfile *sfile;

   /*
    * See if the source file is already in the dependancy section of
    *  the data base.
    */
   hashval = (unsigned int)(unsigned long)srcname % DHSize;
   for (sfile = dhash[hashval]; sfile != NULL && sfile->name != srcname;
        sfile = sfile->next)
      ;

   /*
    * If an entry for the source file was not found, create one.
    */
   if (sfile == NULL) {
      sfile = NewStruct(srcfile);
      sfile->name = srcname;
      sfile->dependents = NULL;
      sfile->next = dhash[hashval];
      dhash[hashval] = sfile;
      ++num_src;
      }
   return sfile;
   }

/*
 * add_dpnd - add the given source/dependency relation to the dependency
 *   table.
 */
void add_dpnd(sfile, c_name)
struct srcfile *sfile;
char *c_name;
   {
   struct cfile *cf;

   cf = NewStruct(cfile);
   cf->name = c_name;
   cf->next = sfile->dependents;
   sfile->dependents = cf;
   }

/*
 * clr_dpnd - delete all dependencies for the given source file.
 */
void clr_dpnd(srcname)
char *srcname;
   {
   src_lkup(srcname)->dependents = NULL;
   }

/*
 * dumpdb - write the updated data base.
 */
void dumpdb(dbname)
char *dbname;
   {
   fprintf(stdout, "rtt was compiled to only support the intepreter, use -x\n");
   exit(EXIT_FAILURE);
   }


/*
 * full_lst - print a full list of all files produced by translations
 *  as represented in the dependencies section of the data base.
 */
void full_lst(fname)
char *fname;
   {
   unsigned hashval;
   struct srcfile *sfile;
   struct cfile *clst;
   struct fileparts *fp;
   FILE *f;

   f = fopen(fname, "w");
   if (f == NULL)
      err2("cannot open ", fname);
   for (hashval = 0; hashval < DHSize; ++hashval)
      for (sfile = dhash[hashval]; sfile != NULL; sfile = sfile->next)
         for (clst = sfile->dependents; clst != NULL; clst = clst->next) {
            /*
             * Remove the suffix from the name before printing.
             */
            fp = fparse(clst->name);

            fprintf(f, "%s\n", fp->name);
            }
   if (fclose(f) != 0)
      err2("cannot close ", fname);
   }

/*
 * impl_fnc - find or create implementation struct for function currently
 *  being parsed.
 */
void impl_fnc(name)
struct token *name;
   {
   /*
    * Set the global operation type for later use. If this is a
    *  new function update the number of them.
    */
   op_type = TokFunction;
   num_fnc = set_impl(name, bhash, num_fnc, fnc_pre);
   }

/*
 * impl_key - find or create implementation struct for keyword currently
 *  being parsed.
 */
void impl_key(name)
struct token *name;
   {
   /*
    * Set the global operation type for later use. If this is a
    *  new keyword update the number of them.
    */
   op_type = Keyword;
   num_key = set_impl(name, khash, num_key, key_pre);
   }

/*
 * set_impl - lookup a function or keyword in a hash table and update the
 *  entry, creating the entry if needed.
 */
static int set_impl(name, tbl, num_impl, pre)
struct token *name;
struct implement **tbl;
int num_impl;
char *pre;
   {
   register struct implement *ptr;
   char *name_s;
   unsigned hashval;

   /*
    * we only need the operation name and not the entire token.
    */
   name_s = name->image;
   free_t(name);

   /*
    * If the operation is not in the hash table, put it there.
    */
   if ((ptr = db_ilkup(name_s, tbl)) == NULL) {
      ptr = NewStruct(implement);
      hashval = IHasher(name_s);
      ptr->blink = tbl[hashval];
      ptr->oper_typ = ((op_type == TokFunction) ? 'F' : 'K');
      nxt_pre(ptr->prefix, pre, 2);    /* allocate a unique prefix */
      ptr->name = name_s;
      ptr->op = NULL;
      tbl[hashval] = ptr;
      ++num_impl;
      }

   cur_impl = ptr;   /* put entry in global variable for later access */

   /*
    * initialize the entry based on global information set during parsing.
    */
   set_prms(ptr);
   ptr->min_result = min_rs;
   ptr->max_result = max_rs;
   ptr->resume = rsm_rs;
   ptr->ret_flag = 0;
   if (comment == NULL)
      ptr->comment = "";
   else {
      ptr->comment = comment->image;
      free_t(comment);
      comment = NULL;
      }
   ptr->ntnds = 0;
   ptr->tnds = NULL;
   ptr->nvars = 0;
   ptr->vars = NULL;
   ptr->in_line = NULL;
   ptr->iconc_flgs = 0;
   return num_impl;
   }

/*
 * set_prms - set the parameter information of an implementation based on
 *   the params list constructed during parsing.
 */
static void set_prms(ptr)
struct implement *ptr;
   {
   struct sym_entry *sym;
   int nargs;
   int i;

   /*
    * Create an array of parameter flags for the operation. The flag
    * indicates the deref/underef and varargs status for each parameter.
    */
   if (params == NULL) {
      ptr->nargs = 0;
      ptr->arg_flgs = NULL;
      }
   else {
      /*
       * The parameters are in reverse order, so the number of the parameters
       *  can be determined by the number assigned to the first one on the
       *  list.
       */
      nargs = params->u.param_info.param_num + 1;
      ptr->nargs = nargs;
      ptr->arg_flgs = (int *)alloc((unsigned int)(sizeof(int) * nargs));
      for (i = 0; i < nargs; ++i)
         ptr->arg_flgs[i] = 0;
      for (sym = params; sym != NULL; sym = sym->u.param_info.next)
         ptr->arg_flgs[sym->u.param_info.param_num] |= sym->id_type;
      }
   }

/*
 * impl_op - find or create implementation struct for operator currently
 *  being parsed.
 */
void impl_op(op_sym, name)
struct token *op_sym;
struct token *name;
   {
   register struct implement *ptr;
   char *op;
   int nargs;
   unsigned hashval;

   /*
    * The operator symbol is needed but not the entire token.
    */
   op = op_sym->image;
   free_t(op_sym);

   /*
    * The parameters are in reverse order, so the number of the parameters
    *  can be determined by the number assigned to the first one on the
    *  list.
    */
   if (params == NULL)
      nargs = 0;
   else
      nargs = params->u.param_info.param_num + 1;

   /*
    * Locate the operator in the hash table; it must match both the
    *  operator symbol and the number of arguments. If the operator is
    *  not there, create an entry.
    */
   hashval = IHasher(op);
   ptr = ohash[hashval];
   while (ptr != NULL && (ptr->op != op || ptr->nargs != nargs))
      ptr = ptr->blink;
   if (ptr == NULL) {
      ptr = NewStruct(implement);
      ptr->blink = ohash[hashval];
      ptr->oper_typ = 'O';
      nxt_pre(ptr->prefix, op_pre, 2);   /* allocate a unique prefix */
      ptr->op = op;
      ohash[hashval] = ptr;
      ++num_op;
      }

   /* 
    * Put the entry and operation type in global variables for
    *  later access.
    */
   cur_impl = ptr;
   op_type = Operator;

   /*
    * initialize the entry based on global information set during parsing.
    */
   ptr->name = name->image;
   free_t(name);
   set_prms(ptr);
   ptr->min_result = min_rs;
   ptr->max_result = max_rs;
   ptr->resume = rsm_rs;
   ptr->ret_flag = 0;
   if (comment == NULL)
      ptr->comment = "";
   else {
      ptr->comment = comment->image;
      free_t(comment);
      comment = NULL;
      }
   ptr->ntnds = 0;
   ptr->tnds = NULL;
   ptr->nvars = 0;
   ptr->vars = NULL;
   ptr->in_line = NULL;
   ptr->iconc_flgs = 0;
   }

/*
 * set_r_seq - save result sequence information for updating the
 *  operation entry.
 */
void set_r_seq(min, max, resume)
long min;
long max;
int resume;
   {
   if (min == UnbndSeq)
      min = 0;
   min_rs = min;
   max_rs = max;
   rsm_rs = resume;
   }

