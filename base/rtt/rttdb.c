/*
 * rttdb.c - routines to read, manipulate, and write the data base of
 *  information about run-time routines.
 */

#include "rtt.h"
#include "../h/version.h"

/*
 * prototypes for static functions.
 */

struct token *comment;		/* comment associated with current operation */


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
   op_name = name->image;
   free_t(name);
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
   op_name = name->image;
   free_t(name);
   }

/*
 * impl_op - find or create implementation struct for operator currently
 *  being parsed.
 */
void impl_op(op_sym0, name)
struct token *op_sym0;
struct token *name;
   {
   op_type = Operator;
   op_name = name->image;
   op_sym = op_sym0->image;
   free_t(op_sym0);
   free_t(name);
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
   }

