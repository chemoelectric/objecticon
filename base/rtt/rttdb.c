/*
 * rttdb.c - routines to read, manipulate, and write the data base of
 *  information about run-time routines.
 */

#include "rtt.h"
#include "../h/version.h"

/*
 * prototypes for static functions.
 */
static int     set_impl  (struct token *name,
                           int num_impl, char *pre);
static void set_prms  (struct implement *ptr);
static void nxt_pre(char *pre, char *nxt, int n);

static int num_fnc;		/* number of function in data base */
static int num_op = 0;		/* number of operators in data base */
static int num_key;		/* number of keywords in data base */

static char fnc_pre[] = "00";		/* next prefix available for functions */
static char op_pre[] = "00";		/* next prefix available for operators */
static char key_pre[] = "00";		/* next prefix available for keywords */

static long min_rs;		/* min result sequence of current operation */
static long max_rs;		/* max result sequence of current operation */
static int rsm_rs;		/* '+' at end of result sequencce of cur. oper. */

struct token *comment;		/* comment associated with current operation */
struct implement *cur_impl;	/* data base entry for current operation */



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
   num_fnc = set_impl(name, num_fnc, fnc_pre);
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
   num_key = set_impl(name, num_key, key_pre);
   }

/*
 * set_impl - lookup a function or keyword in a hash table and update the
 *  entry, creating the entry if needed.
 */
static int set_impl(name, num_impl, pre)
struct token *name;
int num_impl;
char *pre;
   {
   register struct implement *ptr;
   char *name_s;

   /*
    * we only need the operation name and not the entire token.
    */
   name_s = name->image;
   free_t(name);

   ptr = Alloc(struct implement);
   ptr->oper_typ = ((op_type == TokFunction) ? 'F' : 'K');
   nxt_pre(ptr->prefix, pre, 2);    /* allocate a unique prefix */
   ptr->name = name_s;
   ptr->op = NULL;
   ++num_impl;

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
      ptr->arg_flgs = safe_alloc((unsigned int)(sizeof(int) * nargs));
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

   ptr = Alloc(struct implement);
   ptr->oper_typ = 'O';
   nxt_pre(ptr->prefix, op_pre, 2);   /* allocate a unique prefix */
   ptr->op = op;
   ++num_op;

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


/*
 * nxt_pre - assign next prefix. A prefix consists of n characters each from
 *   the range 0-9 and a-z, at least one of which is a digit.
 *
 */
void nxt_pre(char *pre, char *nxt, int n)
   {
   int i, num_dig;

   if (nxt[0] == '\0') {
      fprintf(stderr, "out of unique prefixes\n");
      exit(EXIT_FAILURE);
      }

   /*
    * copy the next prefix into the output string.
    */
   for (i = 0; i < n; ++i)
      pre[i] = nxt[i];

   /*
    * Increment next prefix. First, determine how many digits there are in
    *  the current prefix.
    */
   num_dig = 0;
   for (i = 0; i < n; ++i)
      if (isdigit(nxt[i]))
         ++num_dig;

   for (i = n - 1; i >= 0; --i) {
      switch (nxt[i]) {
         case '9':
            /*
             * If there is at least one other digit, increment to a letter.
             *  Otherwise, start over at zero and continue to the previous
             *  character in the prefix.
             */
            if (num_dig > 1) {
               nxt[i] = 'a';
               return;
               }
            else
               nxt[i] = '0';
            break;

         case 'z':
            /*
             * Start over at zero and continue to previous character in the
             *  prefix.
             */
            nxt[i] = '0';
            ++num_dig;
            break;
         default:
            ++nxt[i];
            return;
         }
      }

   /*
    * Indicate that there are no more prefixes.
    */
   nxt[0] = '\0';
   }
