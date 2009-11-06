#include "rtt.h"

int n_tmp_str  = 0;
struct sym_entry *params = NULL;

/*
 * clr_def - clear any information related to definitions.
 */
void clr_def()
   {
   struct sym_entry *sym;

   n_tmp_str = 0;
   while (params != NULL) {
      sym = params;
      params = params->u.param_info.next;
      free_sym(sym);
      }
   free_tend();
   if (v_len != NULL)
      free_sym(v_len);
   v_len = NULL;
   il_indx = 0;
   lbl_num = 0;
   abs_ret = SomeType;
   }

struct token *chk_exct(tok)
struct token *tok;
   {
   struct sym_entry *sym;

   sym = sym_lkup(tok->image);
   if (sym->u.typ_indx != int_typ)
      errt2(tok, "exact conversions do not apply  to ", tok->image);
   return tok;
   }

/*
 * icn_typ - convert a type node into a type code for the internal
 *   representation of the data base.
 */
int icn_typ(typ)
struct node *typ;
   {
   switch (typ->nd_id) {
      case PrimryNd:
         switch (typ->tok->tok_id) {
            case Any_value:
               return TypAny;
            case Empty_type:
               return TypEmpty;
            case Variable:
               return TypVar;
            case C_Integer:
               return TypCInt;
            case C_Double:
               return TypCDbl;
            case C_String:
               return TypCStr;
            case Tmp_string:
               return TypTStr;
            case Str_Or_Ucs:
               return TypStrOrUcs;
            case Named_var:
               return TypNamedVar;
            case Struct_var:
               return TypStructVar;
            }

      case SymNd:
         return typ->u[0].sym->u.typ_indx;

      default:  /* must be exact conversion */
         if (typ->tok->tok_id == C_Integer)
            return TypECInt;
         else     /* integer */
            return TypEInt;
      }
   }

/*
 * salloc - allocate and initialize string
 */

char *salloc(char *s)
   {
   register char *s1;
   s1 = (char *)safe_alloc(strlen(s) + 1);
   return strcpy(s1, s);
   }
