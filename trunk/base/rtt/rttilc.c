/*
 * rttilc.c - routines to construct pieces of C code to put in the data base
 *  as in-line code.
 *
 * In-line C code is represented internally as a linked list of structures.
 * The information contained in each structure depends on the type of code
 * being represented. Some structures contain other fragments of C code.
 * Code that does not require special processing is stored as strings. These
 * strings are accumulated in a buffer until it is full or code that cannot
 * be represented as a string must be produced. At that point, the string
 * in placed in a structure and put on the list.
 */
#include "rtt.h"


/*
 * chkabsret - make sure a previous abstract return statement
 *  was encountered and that it is consistent with this return,
 *  suspend, or fail.
 */
void chkabsret(tok, ret_typ)
struct token *tok;
int ret_typ;
   {
   if (abs_ret == NoAbstr)
      errt2(tok, tok->image, " with no preceding abstract return");

   /*
    * We only check for type consistency when it is easy, otherwise
    *   we don't bother.
    */
   if (abs_ret == SomeType || ret_typ == SomeType || abs_ret == TypAny)
      return;

   /*
    * Some return types match the generic "variable" type.
    */
   if (abs_ret == TypVar && ret_typ >= 0 && icontypes[ret_typ].deref != DrfNone)
      return;

   /*
    * Otherwise the abstract return must match the real one.
    */
   if (abs_ret != ret_typ)
      errt2(tok, tok->image,  " is inconsistent with abstract return");
   }

/*
 * just_type - strip non-type information from a type-qualifier list. Print
 *   it in the output file and if ilc is set, produce in-line C code.
 */
void just_type(typ, indent, ilc)
struct node *typ;
int indent;
int ilc;
   {
   if (typ->nd_id == LstNd) {
      /*
       * Simple list of type-qualifier elements - concatenate them.
       */
      just_type(typ->u[0].child, indent, ilc); 
      just_type(typ->u[1].child, indent, ilc);
      }
   else if (typ->nd_id == PrimryNd) {
      switch (typ->tok->tok_id) {
         case Typedef:
         case Extern:
         case Static:
         case Auto:
         case TokRegister:
         case Const:
         case Volatile:
            return;         /* Don't output these declaration elements */
         default:
            c_walk(typ, indent, 0);
         }
      }
   else {
      c_walk(typ, indent, 0);
      }
   }
