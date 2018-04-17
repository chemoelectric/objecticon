#include "rtt.h"
#include "../h/version.h"

#define NotId 0  /* declarator is not simple identifier */
#define IsId  1  /* declarator is simple identifier */

#define OrdFunc -1   /* indicates ordinary C function - non-token value */

/*
 * VArgAlwnc - allowance for the variable part of an argument list in the
 *  most general version of an operation. If it is too small, storage must
 *  be malloced. 3 was chosen because over 90 percent of all writes have
 *  3 or fewer arguments. It is possible that 4 would be a better number,
 *  but 5 is probably overkill.
 */
#define VArgAlwnc 3

/*
 * Prototypes for static functions.
 */
static void cnv_fnc       (struct token *t, int typcd,
                               struct node *src, struct node *dflt,
                               struct node *dest, int indent);
static void chk_conj      (struct node *n);
static void chk_nl        (int indent);
static int     does_call     (struct node *expr);
static void failure       (int indent, int brace);
static void interp_def    (struct node *n);
static void line_dir      (int nxt_line, char *new_fname);
static int     only_proto    (struct node *n);
static void parm_locs     (struct sym_entry *op_params);
static void prt_runerr    (struct token *t, struct node *num,
                               struct node *val, int indent);
static void prt_tok       (struct token *t, int indent);
static void prt_var       (struct node *n, int indent);
static int     real_def      (struct node *n);
static int     retval_dcltor (struct node *dcltor, int indent);
static void ret_value1     (struct token *t, struct node *n,
                               int indent);
static void ret_value     (struct token *t, struct node *n,
                               int indent);
static void ret_1_arg     (struct token *t, struct node *args,
                               int typcd, char *vwrd_asgn, char *arg_rep,
                               int indent);
static int     rt_walk       (struct node *n, int indent, int brace);
static int     tdef_or_extr  (struct node *n);
static void tend_ary      (int n);
static void tend_init     (void);
static void tnd_var       (struct sym_entry *sym, char *strct_ptr, char *access, int indent);
static void tok_line      (struct token *t, int indent);
static void typ_asrt      (int typcd, struct node *desc,
                               struct token *tok, int indent);
static int in_frame(struct node *tqual);
static int     typ_case      (struct node *var, struct node *slct_lst,
                               struct node *dflt,
                               int (*walk)(struct node *n, int xindent,
                                 int brace), int maybe_var, int indent);
static void just_type(struct node *typ, int indent, int ilc);
static void untend        (int indent);
static void count_ntend(void);
static void print_func_vars(void);

static int in_struct = 0;
static int in_quick = 0;
static int lab_seq = 0;
 
int op_type = OrdFunc;  /* type of operation */
char *op_name;
char *op_sym;
char *fname = "";       /* current source file name */
static int line = 0;           /* current source line number */
static int nxt_sbuf;           /* next string buffer index */
static int nxt_cbuf;           /* next cset buffer index */

#define ForceNl() nl = 1;
static int nl = 0;             /* flag indicating the a new-line should be output */
static int no_nl = 0;   /* flag to suppress line directives */
static int nparms = 0;     /* number of params for operator/function */

static int ntend;       /* number of tended descriptor needed */
static char *tend_struct_loc; /* expression to access struct of tended descriptors */
static char *tend_loc; /* expression to access array tended descriptors */
static char *n_args;    /* expression for num args */

static int no_ret_val;  /* function has return statement with no value */
static struct node *fnc_head; /* header of function being "copied" to output */

/*
 * chk_nl - if a new-line is required, output it and indent the next line.
 */
static void chk_nl(indent)
int indent;
   {
   int col;

   if (nl)  {
      /*
       * new-line required.
       */
      putc('\n', out_file);
      ++line;
      for (col = 0; col < indent; ++col)
         putc(' ', out_file);
      nl = 0;
      }
   }

/*
 * line_dir - Output a line directive.
 */
static void line_dir(nxt_line, new_fname)
int nxt_line;
char *new_fname;
   {
   char *s;
 
   /*
    * Make sure line directives are desired in the output. Normally,
    *  blank lines surround the directive for readability. However,`
    *  a preceding blank line is suppressed at the beginning of the
    *  output file. In addition, a blank line is suppressed after
    *  the directive if it would force the line number on the directive
    *  to be 0.
    */
   if (line_cntrl) {
      fprintf(out_file, "\n");
      if (line != 0)
         fprintf(out_file, "\n");
      if (nxt_line == 1)
         fprintf(out_file, "#line %d \"", nxt_line);
      else
         fprintf(out_file, "#line %d \"", nxt_line - 1);
      for (s = new_fname; *s != '\0'; ++s) {
         if (*s == '"' || *s == '\\')
            putc('\\', out_file);
         putc(*s, out_file);
         }
      if (nxt_line == 1)
         fprintf(out_file, "\"");
      else
         fprintf(out_file, "\"\n");
      nl = 1;
      --nxt_line;
      }
    else if ((nxt_line > line || fname != new_fname) && line != 0) {
      /*
       * Line directives are disabled, but we are in a situation where
       *  one or two new-lines are desirable.
       */
      if (nxt_line > line + 1 || fname != new_fname)
         fprintf(out_file, "\n");
      nl = 1;
      --nxt_line;
      }
   line = nxt_line;
   fname = new_fname;
   }

/*
 * prt_str - print a string to the output file, possibly preceded by
 *   a new-line and indenting.
 */
void prt_str(s, indent)
char *s;
int indent;
   {
   chk_nl(indent);
   fprintf(out_file, "%s", s);
   }

/*
 * tok_line - determine if a line directive is needed to synchronize the
 *  output file name and line number with an input token.
 */
static void tok_line(t, indent)
struct token *t;
int indent;
   {
   int nxt_line;

   /*
    * Line directives may be suppressed at certain points during code
    *  output. This is done either by rtt itself using the no_nl flag, or
    *  for macros, by the preprocessor using a flag in the token.
    */
   if (no_nl)
      return;
   if (t->flag & LineChk) {
      /*
       * If blank lines can be used in place of a line directive and no
       *  more than 3 are needed, use them. If the line number and file
       *  name are correct, but we need a new-line, we must output a
       *  line directive so the line number is reset after the "new-line".
       */
      nxt_line = t->line;
      if (fname != t->fname  || line > nxt_line || line + 2 < nxt_line)
         line_dir(nxt_line, t->fname);
      else if (nl && line == nxt_line)
         line_dir(nxt_line, t->fname);
      else if (line != nxt_line) {
         nl = 1;
         --nxt_line;
         while (line < nxt_line) { /* above condition limits # interactions */
            putc('\n', out_file);
            ++line;
            }
         }
      }
   chk_nl(indent);
   }

/*
 * prt_tok - print a token.
 */
static void prt_tok(t, indent)
struct token *t;
int indent;
   {
   char *s;

   tok_line(t, indent); /* synchronize file name and line number */

   /*
    * Most tokens contain a string of their exact image. However, string
    *  and character literals lack the surrounding quotes.
    */
   s = t->image;
   switch (t->tok_id) {
      case StrLit:
         fprintf(out_file, "\"%s\"", s);
         break;
      case LStrLit:
         fprintf(out_file, "L\"%s\"", s);
         break;
      case CharConst:
         fprintf(out_file, "'%s'", s);
         break;
      case LCharConst:
         fprintf(out_file, "L'%s'", s);
         break;
      default:
         fprintf(out_file, "%s", s);
      }
   }

/*
 * untend - output code to removed the tended descriptors in this
 *  function from the global tended list.
 */
static void untend(indent)
int indent;
   {
   if (op_type != OrdFunc && !in_quick)
       return;
   ForceNl();
   prt_str("tendedlist = ", indent);
   fprintf(out_file, "%s.previous;", tend_struct_loc);
   ForceNl();
   }

/*
 * tnd_var - output an expression to accessed a tended variable.
 */
static void tnd_var(sym, strct_ptr, access, indent)
struct sym_entry *sym;
char *strct_ptr;
char *access;
int indent;
   {
   /*
    * A variable that is a specific block pointer type must be cast
    *  to that pointer type in such a way that it can be used as either
    *  an lvalue or an rvalue:  *(struct b_??? **)&???.vword.bptr
    */
   if (strct_ptr != NULL) {
      prt_str("(*(struct ", indent);
      prt_str(strct_ptr, indent);
      prt_str("**)&", indent);
      }

   if (sym->id_type & ByRef) {
      /*
       * The tended variable is being accessed indirectly through
       *  a pointer (that is, it is accessed as the argument to a body
       *  function); dereference its identifier.
       */
      prt_str("(*", indent);
      prt_str(sym->image, indent);
      prt_str(")", indent);
      }
   else {
      if (sym->t_indx >= 0) {
         /*
          * The variable is accessed directly as part of the tended structure.
          */
         prt_str(tend_loc, indent);
         fprintf(out_file, "[%d]", sym->t_indx);
         }
      else {
         /*
          * This is a direct access to an operation parameter.
          */
          if (in_quick)
              fprintf(out_file, "r_tend.d[%d]", ntend - nparms + sym->u.param_info.param_num);
          else
              fprintf(out_file, "frame->args[%d]", sym->u.param_info.param_num);
         }
      }
   prt_str(access, indent);  /* access the vword for tended pointers */
   if (strct_ptr != NULL)
      prt_str(")", indent);
   }

/*
 * prt_var - print a variable.
 */
static void prt_var(n, indent)
struct node *n;
int indent;
   {
   struct token *t;
   struct sym_entry *sym;

   t = n->tok;
   tok_line(t, indent); /* synchronize file name and line nuber */
   sym = n->u[0].sym;
   switch (sym->id_type & ~ByRef) {
      case TndDesc:
         /*
          * Simple tended descriptor.
          */
         tnd_var(sym, NULL, "", indent);
         break;
      case TndStr:
         /*
          * Tended character pointer.
          */
         tnd_var(sym, NULL, ".vword.sptr", indent);
         break;
      case TndBlk:
         /*
          * Tended block pointer.
          */
         tnd_var(sym, sym->u.tnd_var.blk_name, ".vword.bptr",
            indent);
         break;
      case RtParm:
      case DrfPrm:
         switch (sym->u.param_info.cur_loc) {
            case PrmTend:
               /*
                * Simple tended parameter.
                */
               tnd_var(sym, NULL, "", indent);
               break;
            case PrmCStr:
               /*
                * Parameter converted to a (tended) string.
                */
               tnd_var(sym, NULL, ".vword.sptr", indent);
               break;
            case PrmInt:
               /*
                * Parameter converted to a C integer.
                */
               chk_nl(indent);
               if (op_generator)
                   fprintf(out_file, "frame->r_i%d", sym->u.param_info.param_num);
               else
                   fprintf(out_file, "r_i%d", sym->u.param_info.param_num);
               break;
            case PrmDbl:
               /*
                * Parameter converted to a C double.
                */
               chk_nl(indent);
               if (op_generator)
                   fprintf(out_file, "frame->r_d%d", sym->u.param_info.param_num);
               else
                   fprintf(out_file, "r_d%d", sym->u.param_info.param_num);
               break;
             default: {
               errt2(t, "Conflicting conversions for: ", t->image);
             }
            }
         break;
      case RtParm | VarPrm:
      case DrfPrm | VarPrm:
         /*
          * Parameter representing variable part of argument list.
          */
         prt_str("(&", indent);
         if (sym->t_indx >= 0)
            fprintf(out_file, "%s[%d])", tend_loc, sym->t_indx);
         else
            fprintf(out_file, "frame->args[%d])", sym->u.param_info.param_num);
         break;
      case VArgLen:
         /*
          * Length of variable part of argument list.
          */
         chk_nl(indent);
         fprintf(out_file, "(%s - %d)", n_args, params->u.param_info.param_num);
         break;
      case Label:
         /*
          * Statement label.
          */
         prt_str(sym->image, indent);
         break;
      case OtherDcl:
         /*
          * Some other type of variable: accessed by identifier. If this
          *  is a body function, it may be passed by reference and need
          *  a level of pointer dereferencing.
          */
         if (sym->id_type & ByRef)
            prt_str("(*",indent);
         if (op_type != OrdFunc && 
             in_frame(sym->u.declare_var.tqual)) {
             if (op_generator)
                 fprintf(out_file, "frame->L%d_", sym->f_indx);
             else
                 fprintf(out_file, "L%d_", sym->f_indx);
         }
         prt_str(sym->image, indent);
         if (sym->id_type & ByRef)
            prt_str(")",indent);
         break;
      }
   }

/*
 * does_call - determine if an expression contains a function call by
 *  walking its syntax tree.
 */
static int does_call(expr)
struct node *expr;
   {
   int n_subs;
   int i;

   if (expr == NULL)
      return 0;
   if (expr->nd_id == BinryNd && expr->tok->tok_id == ')')
      return 1;      /* found a function call */

   switch (expr->nd_id) {
      case ExactCnv: case PrimryNd: case SymNd:
         n_subs = 0;
         break;
      case CompNd:
         /*
          * Check field 0 below, field 1 is not a subtree, check field 2 here.
          */
         n_subs = 1;
         if (does_call(expr->u[2].child))
             return 1;
         break;
      case IcnTypNd: case PstfxNd: case PreSpcNd: case PrefxNd:
         n_subs = 1;
         break;
      case AbstrNd: case BinryNd: case CommaNd: case ConCatNd: case LstNd:
      case StrDclNd:
         n_subs = 2;
         break;
      case TrnryNd:
         n_subs = 3;
         break;
      case QuadNd:
         n_subs = 4;
         break;
      default:
         fprintf(stdout, "rtt internal error: unknown node type\n");
         exit(EXIT_FAILURE);
         }

   for (i = 0; i < n_subs; ++i)
      if (does_call(expr->u[i].child))
          return 1;

   return 0;
   }

/*
 * prt_runerr - print code to implement runerr().
 */
static void prt_runerr(t, num, val, indent)
struct token *t;
struct node *num;
struct node *val;
int indent;
   {
   if (op_type == OrdFunc)
      errt1(t, "'runerr' may not be used in an ordinary C function");

   tok_line(t, indent);  /* synchronize file name and line number */
   prt_str("{", indent);
   ForceNl();
   if (in_quick) {
       int i;
       for (i = 0; i < nparms; ++i) {
           prt_str("xarg", indent);
           fprintf(out_file, "%d = &r_tend.d[%d];", i+1, ntend - nparms + i);
           ForceNl();
       }
       ForceNl();
   }
   prt_str("err_msg(", indent);
   c_walk(num, indent, 0);                /* error number */
   if (val == NULL)
      prt_str(", NULL);", indent);        /* no offending value */
   else {
      prt_str(", &(", indent);
      c_walk(val, indent, 0);             /* offending value */
      prt_str("));", indent);
      }
   /*
    * Now do a return so that any error handler is run (err_msg pushes the frame).
    */
   if (ntend != 0)
       untend(indent);
   ForceNl();
   if (in_quick)
       prt_str("return;", indent);
   else {
       prt_str("frame->exhausted = 1;", indent);
       ForceNl();
       prt_str("return 1;", indent);
   }
   ForceNl();
   prt_str("}", indent);
   ForceNl();
   }

/*
 * typ_name - convert a type code to a string that can be used to
 *  output "T_" or "D_" type codes.
 */
char *typ_name(typcd, tok)
int typcd;
struct token *tok;
   {
   if (typcd == Empty_type)
      errt1(tok, "it is meaningless to assert a type of empty_type");
   else if (typcd == Any_value)
      errt1(tok, "it is useless to assert a type of any_value");
   else if (typcd < 0 || typcd == str_typ)
      return NULL;
   else
      return icontypes[typcd].cap_id;
   /*NOTREACHED*/
   return 0; 	/* avoid gcc warning */
   }

/*
 * Produce a C conditional expression to check a descriptor for a
 *  particular type.
 */
static void typ_asrt(typcd, desc, tok, indent)
int typcd;
struct node *desc;
struct token *tok;
int indent;
   {
   tok_line(tok, indent);

   if (typcd == str_typ) {
      /*
       * Check dword for the absense of a "not qualifier" flag.
       */
      prt_str("(!((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword & F_Nqual))", indent);
      }
   else if (typcd == TypVar) {
      /*
       * Check dword for the presense of a "variable" flag.
       */
      prt_str("((((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword & (F_Var | F_Nqual)) == (F_Var | F_Nqual)))", indent);
      }
   else if (typcd == int_typ) {
      /*
       * If large integers are supported, an integer can be either
       *  an ordinary integer or a large integer.
       */
      ForceNl();

      ForceNl();
      prt_str("(((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword == D_Integer) || ((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword == D_Lrgint))", indent);
      ForceNl();

      ForceNl();
      }
   else if (typcd == TypNamedVar) {
      prt_str("(((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword == D_NamedVar))", indent);
   }
   else if (typcd == TypStructVar) {
      prt_str("((((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword & (F_Var | F_Nqual | F_Ptr | F_Typecode)) == D_StructVar))", indent);
   }
   else {
      /*
       * Check dword for a specific type code.
       */
      prt_str("((", indent);
      c_walk(desc, indent, 0);
      prt_str(").dword == D_", indent);
      prt_str(typ_name(typcd, tok), indent);
      prt_str(")", indent);
      }
   }

/*
 * retval_dcltor - convert the "declarator" part of function declaration
 *  into a declarator for the variable "r_retval" of the same type
 *  as the function result type, outputing the new declarator. This
 *  variable is a temporary location to store the result of the argument
 *  to a C return statement.
 */
static int retval_dcltor(dcltor, indent)
struct node *dcltor;
int indent;
   {
   int flag;

   switch (dcltor->nd_id) {
      case ConCatNd:
         c_walk(dcltor->u[0].child, indent, 0);
         retval_dcltor(dcltor->u[1].child, indent);
         return NotId;
      case PrimryNd:
         /*
          * We have reached the function name. Replace it with "r_retval"
          *  and tell caller we have found it.
          */
         prt_str("r_retval", indent);
         return IsId;
      case PrefxNd:
         /*
          * (...)
          */
         prt_str("(", indent);
         flag = retval_dcltor(dcltor->u[0].child, indent);
         prt_str(")", indent);
         return flag;
      case BinryNd:
         if (dcltor->tok->tok_id == ')') {
            /*
             * Function declaration. If this is the declarator that actually
             *  defines the function being processed, discard the paramater
             *  list including parentheses.
             */
            if (retval_dcltor(dcltor->u[0].child, indent) == NotId) {
               prt_str("(", indent);
               c_walk(dcltor->u[1].child, indent, 0);
               prt_str(")", indent);
               }
            }
         else {
            /*
             * Array.
             */
            retval_dcltor(dcltor->u[0].child, indent);
            prt_str("[", indent);
            c_walk(dcltor->u[1].child, indent, 0);
            prt_str("]", indent);
            }
         return NotId;
      }
   err1("rtt internal error detected in function retval_dcltor()");
   /*NOTREACHED*/
   return 0; 	/* avoid gcc warning */
   }

/*
 * cnv_fnc - produce code to handle RTT cnv: and def: constructs.
 */
static void cnv_fnc(t, typcd, src, dflt, dest, indent)
struct token *t;
int typcd;
struct node *src;
struct node *dflt;
struct node *dest;
int indent;
   {
   int dflt_to_ptr;
   int loc;
   int is_cstr;

   if (src->nd_id == SymNd && src->u[0].sym->id_type & VarPrm)
      errt1(t, "converting entire variable part of param list not supported");

   tok_line(t, indent); /* synchronize file name and line number */

   /*
    * Initial assumptions: result of conversion is a tended location
    *   and is not tended C string.
    */
   loc = PrmTend;
   is_cstr = 0;

  /*
   * Print the name of the conversion function. If it is a conversion
   *  with a default value, determine (through dflt_to_prt) if the
   *  default value is passed by-reference instead of by-value.
   */
   prt_str(cnv_name(typcd, dflt, &dflt_to_ptr), indent);
   prt_str("(", indent);

   /*
    * Determine what parameter scope, if any, is established by this
    *  conversion. If the conversion needs a buffer, allocate it and
    *  put it in the argument list.
    */
   switch (typcd) {
      case TypCInt:
      case TypECInt:
         loc = PrmInt;
         break;
      case TypCDbl:
         loc = PrmDbl;
         break;
      case TypCStr:
         is_cstr = 1;
         break;
      }

   /*
    * Output source of conversion.
    */
   prt_str("&(", indent);
   c_walk(src, indent, 0);
   prt_str("), ", indent);

   /*
    * If there is a default value, output it, taking its address if necessary.
    */
   if (dflt != NULL) {
      if (dflt_to_ptr)
         prt_str("&(", indent);
      c_walk(dflt, indent, 0);
      if (dflt_to_ptr)
         prt_str("), ", indent);
      else
         prt_str(", ", indent);
      }

   /*
    * Output the destination of the conversion. This may or may not be
    *  the same as the source.
    */
   prt_str("&(", indent);
   if (dest == NULL) {
      /*
       * Convert "in place", changing the location of a paramater if needed.
       */
      if (src->nd_id == SymNd && src->u[0].sym->id_type & (RtParm | DrfPrm)) {
         if (src->u[0].sym->id_type & DrfPrm)
            src->u[0].sym->u.param_info.cur_loc = loc;
         else
            errt1(t, "only dereferenced parameter can be converted in-place");
         }
      else if ((loc != PrmTend) | is_cstr)
         errt1(t,
            "only ordinary parameters can be converted in-place to C values");
      c_walk(src, indent, 0);
      if (is_cstr) {
         /*
          * The parameter must be accessed as a tended C string, but only
          *  now, after the "destination" code has been produced as a full
          *  descriptor.
          */
         src->u[0].sym->u.param_info.cur_loc = PrmCStr;
         }
      }
   else {
      /*
       * Convert to an explicit destination.
       */
      if (is_cstr) {
         /*
          * Access the destination as a full descriptor even though it
          *  must be declared as a tended C string.
          */
         if (dest->nd_id != SymNd || (dest->u[0].sym->id_type != TndStr &&
               dest->u[0].sym->id_type != TndDesc))
            errt1(t,
             "dest. of C_string conv. must be tended descriptor or char *");
         tnd_var(dest->u[0].sym, NULL, "", indent);
         }
      else
         c_walk(dest, indent, 0);
      }
   prt_str("))", indent);
   }

/*
 * cnv_name - produce name of conversion routine. Warning, name is
 *   constructed in a static buffer. Also determine if a default
 *   must be passed "by reference".
 */
char *cnv_name(typcd, dflt, dflt_to_ptr)
int typcd;
struct node *dflt;
int *dflt_to_ptr;
   {
   static char buf[25];
   int by_ref;

   /*
    * The names of simple conversion and defaulting conversions have
    *  the same suffixes, but different prefixes.
    */
   if (dflt == NULL)
      strcpy(buf , "cnv_");
   else
       strcpy(buf, "def_");

   by_ref = 0;
   switch (typcd) {
      case TypCInt:
         strcat(buf, "c_int");
         break;
      case TypCDbl:
         strcat(buf, "c_dbl");
         break;
      case TypCStr:
         strcat(buf, "c_str");
         break;
      case TypEInt:
         strcat(buf, "eint");
         break;
      case TypECInt:
         strcat(buf, "ec_int");
         break;
      case TypStrOrUcs:
         strcat(buf, "str_or_ucs");
         by_ref = 1;
         break;
      default:
         if (typcd == cset_typ) {
            strcat(buf, "cset");
            by_ref = 1;
            }
         else if (typcd == int_typ)
            strcat(buf, "int");
         else if (typcd == ucs_typ) {
            strcat(buf, "ucs");
            by_ref = 1;
            }
         else if (typcd == real_typ)
            strcat(buf, "real");
         else if (typcd == str_typ) {
            strcat(buf, "str");
            by_ref = 1;
            }
      }
   if (dflt_to_ptr != NULL)
      *dflt_to_ptr = by_ref;
   return buf;
   }

/*
 * ret_value - produce code to set the result location of an operation
 *  using the expression on a return or suspend.
 */
static void ret_value(struct token *t, struct node *n, int indent)
{
   if (n == NULL)
       return;
    prt_str("struct descrip result;", indent);
    ForceNl();
    ret_value1(t, n, indent);
    ForceNl();
    if (in_quick)
        prt_str("if (_lhs) *_lhs = result;", indent);
    else
        prt_str("if (frame->lhs) *frame->lhs = result;", indent);
}

static void ret_value1(struct token *t, struct node *n, int indent)
   {
   struct node *caller;
   struct node *args;
   int typcd;

   if (n->nd_id == PrefxNd && n->tok != NULL) {
      switch (n->tok->tok_id) {
         case C_Integer:
            /*
             * return/suspend C_integer <expr>;
             */
            prt_str("result.vword.integer = ", indent);
            c_walk(n->u[0].child, indent + IndentInc, 0);
            prt_str(";", indent);
            ForceNl();
            prt_str("result.dword = D_Integer;", indent);
            return;
         case C_Double:
            /*
             * return/suspend C_double <expr>;
             */
#if RealInDesc
            prt_str("result.vword.realval = ", indent);
            c_walk(n->u[0].child, indent + IndentInc, 0);
            prt_str(";", indent);
            ForceNl();
            prt_str("result.dword = D_Real;", indent);
            return;
#else
            prt_str("result.vword.bptr = (union block *)alcreal(", indent);
            c_walk(n->u[0].child, indent + IndentInc, 0);
            prt_str(");", indent + IndentInc);
            ForceNl();
            prt_str("result.dword = D_Real;", indent);
            /*
             * The allocation of the real block may fail.
             */
            ForceNl();
            prt_str("if (!result.vword.bptr) fatalerr(309, NULL);", indent);
            ForceNl();
#endif
            return;
         case C_String:
            /*
             * return/suspend C_string <expr>;
             */
            prt_str("result.vword.sptr = ", indent);
            c_walk(n->u[0].child, indent + IndentInc, 0);
            prt_str(";", indent);
            ForceNl();
            if (n->u[0].child->tok->tok_id == StrLit) {
                prt_str("result.dword = ", indent);
                fprintf(out_file, "%d;", (int)strlen(n->u[0].child->tok->image));
            } else
                prt_str("result.dword = strlen(result.vword.sptr);", indent);
            return;
         }
      }
   else if (n->nd_id == BinryNd && n->tok->tok_id == ')') {
      /*
       * Return value is in form of function call, see if it is really
       *  a descriptor constructor.
       */
      caller = n->u[0].child;
      args = n->u[1].child;
      if (caller->nd_id == SymNd) {
         switch (caller->tok->tok_id) {
            case IconType:
               typcd = caller->u[0].sym->u.typ_indx;
               switch (icontypes[typcd].rtl_ret) {
                  case TRetBlkP:
                     /*
                      * return/suspend <type>(<block-pntr>);
                      */
                     ret_1_arg(t, args, typcd, ".vword.bptr = (union block *)",
                        "(bp)", indent);
                     break;
                  case TRetDescP:
                     /*
                      * return/suspend <type>(<desc-pntr>);
                      */
                     ret_1_arg(t, args, typcd, ".vword.descptr = (dptr)",
                        "(dp)", indent);
                     break;
                  case TRetCharP:
                     /*
                      * return/suspend <type>(<char-pntr>);
                      */
                     ret_1_arg(t, args, typcd, ".vword.sptr = (char *)",
                        "(s)", indent);
                     break;
                  case TRetCInt:
                     /*
                      * return/suspend <type>(<integer>);
                      */
                     ret_1_arg(t, args, typcd, ".vword.integer = (word)",
                        "(i)", indent);
                     break;
                  case TRetSpcl:
                     if (typcd == str_typ) {
                        /*
                         * return/suspend string(<len>, <char-pntr>);
                         */
                        if (args == NULL || args->nd_id != CommaNd ||
                           args->u[0].child->nd_id == CommaNd)
                           errt1(t, "wrong no. of args for string(n, s)");
                        prt_str("result.vword.sptr = ", indent);
                        c_walk(args->u[1].child, indent + IndentInc, 0);
                        prt_str(";", indent);
                        ForceNl();
                        prt_str("result.dword = ", indent);
                        c_walk(args->u[0].child, indent + IndentInc, 0);
                        prt_str(";", indent);
                        }
                     break;
                  }
               return;
            case Named_var:
               /*
                * return/suspend named_var(<desc-pntr>);
                */
               if (args == NULL || args->nd_id == CommaNd)
                  errt1(t, "wrong no. of args for named_var(dp)");
               prt_str("result.vword.descptr = ", indent);
               c_walk(args, indent + IndentInc, 0);
               prt_str(";", indent);
               ForceNl();
               prt_str("result.dword = D_NamedVar;", indent);
               return;
            case Struct_var:
               /*
                * return/suspend struct_var(<desc-pntr>, <block_pntr>);
                */
               if (args == NULL || args->nd_id != CommaNd ||
                  args->u[0].child->nd_id == CommaNd)
                  errt1(t, "wrong no. of args for struct_var(dp, bp)");
               prt_str("result.vword.descptr = (dptr)", indent);
               c_walk(args->u[1].child, indent + IndentInc, 0);
               prt_str(";", indent);
               ForceNl();
               prt_str("result.dword = D_StructVar + ((word *)", indent);
               c_walk(args->u[0].child, indent + IndentInc, 0);
               prt_str(" - (word *)", indent+IndentInc);
               prt_str("result.vword.descptr);", indent+IndentInc);
               ForceNl();
               return;
            }
         }
      }

   /*
    * If it is not one of the special returns, it is just a return of
    *  a descriptor.
    */
   prt_str("result = ", indent);
   c_walk(n, indent + IndentInc, 0);
   prt_str(";", indent);
   }

/*
 * ret_1_arg - produce code for a special return/suspend with one argument.
 */
static void ret_1_arg(t, args, typcd, vwrd_asgn, arg_rep, indent)
struct token *t;
struct node *args;
int typcd;
char *vwrd_asgn;
char *arg_rep;
int indent;
   {
   if (args == NULL || args->nd_id == CommaNd)
      errt3(t, "wrong no. of args for", icontypes[typcd].id, arg_rep);

   /*
    * Assignment to vword of result descriptor.
    */
   prt_str("result", indent);
   prt_str(vwrd_asgn, indent);
   c_walk(args, indent + IndentInc, 0);
   prt_str(";", indent);
   ForceNl();

   /*
    * Assignment to dword of result descriptor.
    */
   prt_str("result.dword = D_", indent);
   prt_str(icontypes[typcd].cap_id, indent);
   prt_str(";", indent);
   }


/*
 * failure - produce code for fail or efail.
 */
static void failure(indent, brace)
int indent;
int brace;
   {
   /*
    * If there are tended variables, they must be removed from the tended
    *  list. The C function may or may not return an explicit signal.
    */
   ForceNl();
   if (ntend != 0) {
      if (!brace)
         prt_str("{", indent);
      ForceNl();
      untend(indent);
      ForceNl();
      if (in_quick) {
          prt_str("ipc = _failure_label;", indent);
          ForceNl();
          prt_str("return;", indent);
      }          
      else
          prt_str("return 0;", indent);
      if (!brace) {
         ForceNl();
         prt_str("}", indent);
         }
      }
   else {
      if (in_quick) {
          prt_str("{", indent);
          ForceNl();
          prt_str("ipc = _failure_label;", indent);
          ForceNl();
          prt_str("return;", indent);
          ForceNl();
          prt_str("}", indent);
      }          
      else
          prt_str("return 0;", indent);
   }
   ForceNl();
   }

static int in_frame(struct node *tqual)
{
    for (;;) {
        if (!tqual)
            return 0;

        switch (tqual->nd_id) { 
            case BinryNd:
            case LstNd:
                tqual = tqual->u[0].child;
                break;
            case PrimryNd: {
                int t = tqual->tok->tok_id;
                if (t == Typedef || t == Extern || t == Static || t == Auto)
                    return 0;
                return 1;
            }
            default:
                err1("expected something else in type qualifier");
        }
    }
}

static void decl_walk3(struct node *tqual, struct node *dcltor, int indent)
   {
   struct node *part_dcltor;
   struct token *t;

   if (dcltor->nd_id == BinryNd && dcltor->tok->tok_id == '=') {
      dcltor = dcltor->u[0].child;
      }
   part_dcltor = dcltor;
   for (;;) {
      switch (part_dcltor->nd_id) { 
         case BinryNd:
            /* ')' or '[' */
            part_dcltor = part_dcltor->u[0].child;
            break;
         case ConCatNd:
            /* pointer direct-declarator */
            part_dcltor = part_dcltor->u[1].child;
            break;
         case PrefxNd:
            /* ( ... ) */
            part_dcltor =  part_dcltor->u[0].child;
            break;
         case PrimryNd:
            t = part_dcltor->tok;
            if (t->tok_id == Identifier || t->tok_id == TypeDefName) {
                struct sym_entry *sym = part_dcltor->u[0].sym;
                if (sym) {
                    /*printf("FOUND L%d_%s\n",part_dcltor->u[0].sym->f_indx,t->image);*/
                    if (sym->id_type == OtherDcl &&
                        sym->u.declare_var.init) {
                        chk_nl(indent);
                        if (op_generator)
                            fprintf(out_file, "frame->L%d_%s =",sym->f_indx,t->image);
                        else
                            fprintf(out_file, "L%d_%s =",sym->f_indx,t->image);
                        c_walk(sym->u.declare_var.init, 2 * IndentInc, 0);
                        prt_str(";", indent);
                    }
                } else
                    err1("Symbol declaration with no matching symbol table entry");
            }
            return;
         default:
            return;
         }
      }
   }

static void decl_walk2(struct node *tqual, struct node *n, int indent)
{
   if (n->nd_id == CommaNd) {
        decl_walk2(tqual, n->u[0].child, indent);
        decl_walk2(tqual, n->u[1].child, indent);
   }
    else
        decl_walk3(tqual, n, indent);
}

static void decl_walk1(struct node *dcl, int indent)
{
   if (dcl == NULL)
      return;
   if (in_frame(dcl->u[0].child))
       decl_walk2(dcl->u[0].child, dcl->u[1].child, indent);
   else
       c_walk(dcl, indent, 0);
}

static void decl_walk(struct node *dcls, int indent)
{
   if (dcls == NULL)
      return;
   if (dcls->nd_id == LstNd) {
       decl_walk(dcls->u[0].child, indent);
       decl_walk(dcls->u[1].child, indent);
   } else
       decl_walk1(dcls, indent);
}


/*
 * c_walk - walk the syntax tree for extended C code and output the
 *  corresponding ordinary C. Return and indication of whether execution
 *  falls through the code.
 */
int c_walk(n, indent, brace)
struct node *n;
int indent;
int brace;
   {
   struct token *t;
   struct node *n1;
   struct sym_entry *sym;
   int fall_thru;
   int save_break;
   static int does_break = 0;
   static int may_brnchto;  /* may reach end of code by branching into middle */

   if (n == NULL)
      return 1;

   t =  n->tok;
   switch (n->nd_id) {
      case PrimryNd:
         switch (t->tok_id) {
            case Fail:
               if (op_type == OrdFunc)
                  errt1(t, "'fail' may not be used in an ordinary C function");
               failure(indent, brace);
	       return 0;
            case Break:
	       prt_tok(t, indent);
	       prt_str(";", indent);
               does_break = 1;
               return 0;
	    default:
               /*
                * Other "primary" expressions are just their token image,
                *  possibly followed by a semicolon.
                */
                if (op_type != OrdFunc && 
                    n->u[0].sym && 
                    n->u[0].sym->id_type == OtherDcl && 
                    in_frame(n->u[0].sym->u.declare_var.tqual)) {
                    /* Must be an identifier as a declaration which added an entry to the sym table */
                    tok_line(t, indent);
                    fprintf(out_file, "L%d_%s", n->u[0].sym->f_indx,t->image);
                } else if (t->tok_id != TokRegister || !in_struct) { /* Don't print "register" in header */
                    if (strcmp(t->image, "_rval") == 0 && op_type != OrdFunc && !in_quick)
                        fprintf(out_file, "frame->rval");
                    else
                        prt_tok(t, indent);
                }
	       if (t->tok_id == Continue)
		  prt_str(";", indent);
               return 1;
	    }
      case PrefxNd:
	 switch (t->tok_id) {
	    case Sizeof:
	       prt_tok(t, indent);                /* sizeof */
	       prt_str("(", indent);
	       c_walk(n->u[0].child, indent, 0);
	       prt_str(")", indent);
	       return 1;
	    case '{':
               /*
                * Initializer list.
                */
	       prt_tok(t, indent + IndentInc);     /* { */
	       c_walk(n->u[0].child, indent + IndentInc, 0);
	       prt_str("}", indent + IndentInc);
	       return 1;
	    case Default:
	       prt_tok(t, indent - IndentInc);     /* default (un-indented) */
	       prt_str(": ", indent - IndentInc);
	       fall_thru = c_walk(n->u[0].child, indent, 0);
               may_brnchto = 1;
               return fall_thru;
	    case Goto:
	       prt_tok(t, indent);                 /* goto */
	       prt_str(" ", indent);
	       c_walk(n->u[0].child, indent, 0);
	       prt_str(";", indent);
	       return 0;
	    case Return:
	       if (n->u[0].child != NULL)
		  no_ret_val = 0;  /* note that return statement has no value */

	       if (op_type == OrdFunc) {
		  /*
		   * ordinary C return: ignore C_integer, C_double, and
		   *  C_string qualifiers on return expression (the first
		   *  two may legally occur when fnc_ret is RetInt or RetDbl).
		   */
		  n1 = n->u[0].child;
		  if (n1 != NULL && n1->nd_id == PrefxNd && n1->tok != NULL) {
		     switch (n1->tok->tok_id) {
			case C_Integer:
			case C_Double:
			case C_String:
			   n1 = n1->u[0].child;
			}
		     }
		  if (ntend != 0) {
                     /*
                      * There are tended variables that must be removed from
                      *  the tended list.
                      */
		     if (!brace)
			prt_str("{", indent);
		     if (does_call(n1)) {
			/*
			 * The return expression contains a function call;
                         *  the variables must remain tended while it is
                         *  computed, so compute it into a temporary variable
                         *  named r_retval.Output a declaration for r_retval;
                         *  its type must match the return type of the C
                         *  function.
                         */
			ForceNl();
			prt_str("register ", indent);

                        no_nl = 1;
                        just_type(fnc_head->u[0].child, indent, 0);
                        prt_str(" ", indent);
                        retval_dcltor(fnc_head->u[1].child, indent);
                        prt_str(";", indent);
                        no_nl = 0;

			ForceNl();

                        /*
                         * Output code to compute the return value, untend
                         *  the variable, then return the value.
                         */
			prt_str("r_retval = ", indent);
			c_walk(n1, indent + IndentInc, 0);
			prt_str(";", indent);
			untend(indent);
			ForceNl();
			prt_str("return r_retval;", indent);
			}
		     else {
                        /*
                         * It is safe to untend the variables and return
                         *  the result value directly with a return
                         *  statement.
                         */
			untend(indent);
			ForceNl();
			prt_tok(t, indent);    /* return */
			prt_str(" ", indent);
			c_walk(n1, indent, 0);
			prt_str(";", indent);
			}
		     if (!brace) {
			ForceNl();
			prt_str("}", indent);
			}
		     ForceNl();
		     }
		  else {
                     /*
                      * There are no tended variable, just output the
                      *  return expression.
                      */
		     prt_tok(t, indent);     /* return */
		     prt_str(" ", indent);
		     c_walk(n1, indent, 0);
		     prt_str(";", indent);
		     }

                  }
               else {
                  /*
                   * Return from Icon operation. Indicate that the operation
                   *  returns, compute the value into the result location,
                   *  untend variables if necessary, and return a signal
                   *  if the function requires one.
                   */
                  ForceNl();
                  if (!brace) {
                     prt_str("{", indent);
                     ForceNl();
                     }
                  ret_value(t, n->u[0].child, indent);
                  if (ntend != 0)
                     untend(indent);
                  ForceNl();
                  if (in_quick)
                      prt_str("return;", indent);
                  else {
                      prt_str("frame->exhausted = 1;", indent);
                      ForceNl();
                      prt_str("return 1;", indent);
                  }
                  ForceNl();
                  if (!brace) {
                     prt_str("}", indent);
                     ForceNl();
                     }
                  }
               return 0;
            case Suspend:
               if (op_type == OrdFunc)
                  errt1(t, "'suspend' may not be used in an ordinary C function"
                     );
               if (!op_generator)
                   err1("rtt internal error detected, op_generator flag expected");

               ForceNl();
               if (!brace) {
                  prt_str("{", indent);
                  ForceNl();
                  }
               ForceNl();
               ret_value(t, n->u[0].child, indent);
               ForceNl();
#if HAVE_COMPUTED_GOTO
               prt_str("frame->pc = (word)&&Lab", indent);
#else
               prt_str("frame->pc = ", indent);
#endif
               fprintf(out_file, "%d;", ++lab_seq);
               ForceNl();
               prt_str("return 1;", indent);
               fprintf(out_file, "\nLab%d:;", lab_seq);
               ForceNl();
               if (!brace) {
                  prt_str("}", indent);
                  ForceNl();
                  }
               return 1;
            case '(':
               /*
                * Parenthesized expression.
                */
               prt_tok(t, indent);     /* ( */
               fall_thru = c_walk(n->u[0].child, indent, 0);
               prt_str(")", indent);
               return fall_thru;
            default:
               /*
                * All other prefix expressions are printed as the token
                *  image of the operation followed by the operand.
                */
               prt_tok(t, indent);
               c_walk(n->u[0].child, indent, 0);
               return 1;
            }
      case PstfxNd:
         /*
          * All postfix expressions are printed as the operand followed
          *  by the token image of the operation.
          */
         fall_thru = c_walk(n->u[0].child, indent, 0);
         prt_tok(t, indent);
         return fall_thru;
      case PreSpcNd:
         /*
          * This prefix expression (pointer indication in a declaration) needs
          *  a space after it.
          */
         prt_tok(t, indent);
         c_walk(n->u[0].child, indent, 0);
         prt_str(" ", indent);
         return 1;
      case SymNd:
         /*
          * Identifier.
          */
         prt_var(n, indent);
         return 1;
      case BinryNd:
         switch (t->tok_id) {
            case '[':
               /*
                * subscripting expression or declaration: <expr> [ <expr> ]
                */
               n1 = n->u[0].child;
               c_walk(n->u[0].child, indent, 0);
               prt_str("[", indent);
               c_walk(n->u[1].child, indent, 0);
               prt_str("]", indent);
               return 1;
            case '(':
               /*
                * cast: ( <type> ) <expr>
                */
               prt_tok(t, indent);  /* ) */
               c_walk(n->u[0].child, indent, 0);
               prt_str(")", indent);
               c_walk(n->u[1].child, indent, 0);
               return 1;
            case ')':
               /*
                * function call or declaration: <expr> ( <expr-list> )
                */
               c_walk(n->u[0].child, indent, 0);
               prt_str("(", indent);
               c_walk(n->u[1].child, indent, 0);
               prt_tok(t, indent);   /* ) */
               return call_ret(n->u[0].child);
            case Struct:
            case Union:
               /*
                * struct/union <ident>
                * struct/union <opt-ident> { <field-list> }
                */
               prt_tok(t, indent);   /* struct or union */
               prt_str(" ", indent);
               c_walk(n->u[0].child, indent, 0);
               if (n->u[1].child != NULL) {
                  /*
                   * Field declaration list.
                   */
                  prt_str(" {", indent);
                  c_walk(n->u[1].child, indent + IndentInc, 0);
                  ForceNl();
                  prt_str("}", indent);
                  }
               return 1;
            case TokEnum:
               /*
                * enum <ident>
                * enum <opt-ident> { <enum-list> }
                */
               prt_tok(t, indent);   /* enum */
               prt_str(" ", indent);
               c_walk(n->u[0].child, indent, 0);
               if (n->u[1].child != NULL) {
                  /*
                   * enumerator list.
                   */
                  prt_str(" {", indent);
                  c_walk(n->u[1].child, indent + IndentInc, 0);
                  prt_str("}", indent);
                  }
               return 1;
            case ';':
               /*
                * <type-specs> <declarator> ;
                */
               c_walk(n->u[0].child, indent, 0);
               prt_str(" ", indent);
               c_walk(n->u[1].child, indent, 0);
               prt_tok(t, indent);  /* ; */
               return 1;
            case ':':
               /*
                * <label> : <statement>
                */
               c_walk(n->u[0].child, indent, 0);
               prt_tok(t, indent);   /* : */
               prt_str(" ", indent);
               fall_thru = c_walk(n->u[1].child, indent, 0);
               may_brnchto = 1;
               return fall_thru;
            case Case:
               /*
                * case <expr> : <statement>
                */
               prt_tok(t, indent - IndentInc);  /* case (un-indented) */
               prt_str(" ", indent);
               c_walk(n->u[0].child, indent - IndentInc, 0);
               prt_str(": ", indent - IndentInc);
               fall_thru = c_walk(n->u[1].child, indent, 0);
               may_brnchto = 1;
               return fall_thru;
            case Switch:
               /*
                * switch ( <expr> ) <statement>
                *
                * <statement> is double indented so that case and default
                * statements can be un-indented and come out indented 1
                * with respect to the switch. Statements that are not
                * "labeled" with case or default are indented one more
                * than those that are labeled.
                */
               prt_tok(t, indent);  /* switch */
               prt_str(" (", indent);
               c_walk(n->u[0].child, indent, 0);
               prt_str(")", indent);
               prt_str(" ", indent);
               save_break = does_break;
               fall_thru = c_walk(n->u[1].child, indent + 2 * IndentInc, 0);
               fall_thru |= does_break;
               does_break = save_break;
               return fall_thru;
            case While: {
               struct node *n0;
               /*
                * While ( <expr> ) <statement>
                */
               n0 = n->u[0].child;
               prt_tok(t, indent);  /* while */
               prt_str(" (", indent);
               c_walk(n0, indent, 0);
               prt_str(")", indent);
               prt_str(" ", indent);
               save_break = does_break;
               c_walk(n->u[1].child, indent + IndentInc, 0);
               /*
                * check for an infinite loop, while (1) ... :
                *  a condition consisting of an IntConst with image=="1"
                *  and no breaks in the body.
                */
               if (n0->nd_id == PrimryNd && n0->tok->tok_id == IntConst &&
                   !strcmp(n0->tok->image,"1") && !does_break)
                  fall_thru = 0;
               else
                  fall_thru = 1;
               does_break = save_break;
               return fall_thru;
               }
            case Do:
               /*
                * do <statement> <while> ( <expr> )
                */
               prt_tok(t, indent);  /* do */
               prt_str(" ", indent);
               c_walk(n->u[0].child, indent + IndentInc, 0);
               ForceNl();
               prt_str("while (", indent);
               save_break = does_break;
               c_walk(n->u[1].child, indent, 0);
               does_break = save_break;
               prt_str(");", indent);
               return 1;
            case '.':
            case Arrow:
               /*
                * Field access: <expr> . <expr>  and  <expr> -> <expr>
                */
               c_walk(n->u[0].child, indent, 0);
               prt_tok(t, indent);   /* . or -> */
               c_walk(n->u[1].child, indent, 0);
               return 1;
            case Runerr:
               /*
                * runerr ( <error-number> )
                * runerr ( <error-number> , <offending-value> )
                */
               prt_runerr(t, n->u[0].child, n->u[1].child, indent);
               return 0;
            case Is:
               /*
                * is : <type> ( <expr> )
                */
               typ_asrt(icn_typ(n->u[0].child), n->u[1].child,
                  n->u[0].child->tok, indent);
               return 1;
            default:
               /*
                * All other binary expressions are infix notation and
                *  are printed with spaces around the operator.
                */
               c_walk(n->u[0].child, indent, 0);
               prt_str(" ", indent);
               prt_tok(t, indent);
               prt_str(" ", indent);
               c_walk(n->u[1].child, indent, 0);
               return 1;
            }
      case LstNd:
         /*
          * <declaration-part> <declaration-part>
          *
          * Need space between parts
          */
         c_walk(n->u[0].child, indent, 0);
         prt_str(" ", indent);
         c_walk(n->u[1].child, indent, 0);
         return 1;
      case ConCatNd:
         /*
          * <some-code> <some-code>
          *
          * Various lists of code parts that do not need space between them.
          */
         if (c_walk(n->u[0].child, indent, 0))
            return c_walk(n->u[1].child, indent, 0);
         else {
            /*
             * Cannot directly reach the second piece of code, see if
             *  it is possible to branch into it.
             */
            may_brnchto = 0;
            fall_thru = c_walk(n->u[1].child, indent, 0);
            return may_brnchto & fall_thru;
            }
      case CommaNd:
         /*
          * <expr> , <expr>
          */
         c_walk(n->u[0].child, indent, 0);
         prt_tok(t, indent);
         prt_str(" ", indent);
         return c_walk(n->u[1].child, indent, 0);
      case StrDclNd:
         /*
          * Structure field declaration. Bit field declarations have
          *  a semicolon and a field width.
          */
         c_walk(n->u[0].child, indent, 0);
         if (n->u[1].child != NULL) {
            prt_str(": ", indent);
            c_walk(n->u[1].child, indent, 0);
            }
         return 1;
      case CompNd:
         /*
          * Compound statement.
          */
         if (brace)
            tok_line(t, indent); /* just synch. file name and line number */
         else
            prt_tok(t, indent);  /* { */
         if (op_type != OrdFunc)
             decl_walk(n->u[0].child, indent);
         else
             c_walk(n->u[0].child, indent, 0);
         /*
          * we are in an inner block. tended locations may need to
          *  be set to values from declaration initializations.
          */
         for (sym = n->u[1].sym; sym!= NULL; sym = sym->u.tnd_var.next) {
            if (sym->u.tnd_var.init != NULL) {
               prt_str(tend_loc, IndentInc);
               fprintf(out_file, "[%d]", sym->t_indx);
               switch (sym->id_type) {
                  case TndDesc:
                     prt_str(" = ", IndentInc);
                     break;
                  case TndStr:
                     prt_str(".vword.sptr = ", IndentInc);
                     break;
                  case TndBlk:
                     prt_str(".vword.bptr = (union block *)",
                        IndentInc);
                     break;
                  }
               c_walk(sym->u.tnd_var.init, 2 * IndentInc, 0);
               prt_str(";", 2 * IndentInc);
               ForceNl();
               }
            }
         /*
          * If there are no declarations, suppress braces that
          *  may be required for a one-statement body; we already
          *  have a set.
          */
         if (n->u[0].child == NULL && n->u[1].sym == NULL)
            fall_thru = c_walk(n->u[2].child, indent, 1);
         else
            fall_thru = c_walk(n->u[2].child, indent, 0);
         if (!brace) {
            ForceNl();
            prt_str("}", indent);
            }
         return fall_thru;
      case TrnryNd:
         switch (t->tok_id) {
            case '?':
               /*
                * <expr> ? <expr> : <expr>
                */
               c_walk(n->u[0].child, indent, 0);
               prt_str(" ", indent);
               prt_tok(t, indent);  /* ? */
               prt_str(" ", indent);
               c_walk(n->u[1].child, indent, 0);
               prt_str(" : ", indent);
               c_walk(n->u[2].child, indent, 0);
               return 1;
            case If:
               /*
                * if ( <expr> ) <statement>
                * if ( <expr> ) <statement> else <statement>
                */
               prt_tok(t, indent);  /* if */
               prt_str(" (", indent);
               c_walk(n->u[0].child, indent + IndentInc, 0);
               prt_str(") ", indent);
               fall_thru = c_walk(n->u[1].child, indent + IndentInc, 0);
               n1 = n->u[2].child;
               if (n1 == NULL)
                  fall_thru = 1;
               else {
                  /*
                   * There is an else statement. Don't indent an
                   *  "else if"
                   */
                  ForceNl();
                  prt_str("else ", indent);
                  if (n1->nd_id == TrnryNd && n1->tok->tok_id == If)
                     fall_thru |= c_walk(n1, indent, 0);
                  else
                     fall_thru |= c_walk(n1, indent + IndentInc, 0);
                  }
               return fall_thru;
            case Type_case:
               /*
                * type_case <expr> of { <section-list> }
                * type_case <expr> of { <section-list> <default-clause> }
                */
               return typ_case(n->u[0].child, n->u[1].child, n->u[2].child,
                  c_walk, 1, indent);
            case Cnv:
               /*
                * cnv : <type> ( <source> , <destination> )
                */
               cnv_fnc(t, icn_typ(n->u[0].child), n->u[1].child, NULL,
                  n->u[2].child,
                  indent);
               return 1;
            }
      case QuadNd:
         switch (t->tok_id) {
            case For:
               /*
                * for ( <expr> ; <expr> ; <expr> ) <statement>
                */
               prt_tok(t, indent);  /* for */
               prt_str(" (", indent);
               c_walk(n->u[0].child, indent, 0);
               prt_str("; ", indent);
               c_walk(n->u[1].child, indent, 0);
               prt_str("; ", indent);
               c_walk(n->u[2].child, indent, 0);
               prt_str(") ", indent);
               save_break = does_break;
               c_walk(n->u[3].child, indent + IndentInc, 0);
               if (n->u[1].child == NULL && !does_break)
                  fall_thru = 0;
               else
                  fall_thru = 1;
               does_break = save_break;
               return fall_thru;
            case Def:
               /*
                * def : <type> ( <source> , <default> , <destination> )
                */
               cnv_fnc(t, icn_typ(n->u[0].child), n->u[1].child, n->u[2].child,
                  n->u[3].child, indent);
               return 1;
            }
      }
   /*NOTREACHED*/
   return 0; 	/* avoid gcc warning */
   }

/*
 * call_ret - decide whether a function being called might return.
 */
int call_ret(n)
struct node *n;
   {
   /*
    * Assume functions return except for c_exit(), fatalerr(), and syserr().
    */
   if (n->tok != NULL &&
      (strcmp("c_exit",   n->tok->image) == 0 ||
       strcmp("fatalerr", n->tok->image) == 0 ||
       strcmp("syserr",   n->tok->image) == 0))
      return 0;
   else
      return 1;
   }

/*
 * new_prmloc - allocate an array large enough to hold a flag for every
 *  parameter of the current operation. This flag indicates where
 *  the parameter is in terms of scopes created by conversions.
 */
struct parminfo *new_prmloc()
   {
   struct parminfo *parminfo;
   int nparams;
   int i;

   if (params == NULL)
      return NULL;
   nparams = params->u.param_info.param_num + 1;
   parminfo = safe_zalloc((unsigned)nparams *
     sizeof(struct parminfo));
   for (i = 0; i < nparams; ++i) {
      parminfo[i].cur_loc = 0;
      parminfo [i].parm_mod = 0;
      }
   return parminfo;
   }

/*
 * ld_prmloc - load parameter location information that has been
 *  saved in an arrary into the symbol table.
 */
void ld_prmloc(parminfo)
struct parminfo *parminfo;
   {
   struct sym_entry *sym;
   int param_num;

   for (sym = params; sym != NULL; sym = sym->u.param_info.next) {
      param_num = sym->u.param_info.param_num;
      if (sym->id_type & DrfPrm) {
         sym->u.param_info.cur_loc = parminfo[param_num].cur_loc;
         sym->u.param_info.parm_mod = parminfo[param_num].parm_mod;
         }
      }
   }

/*
 * sv_prmloc - save parameter location information from the the symbol table
 *  into an array.
 */
void sv_prmloc(parminfo)
struct parminfo *parminfo;
   {
   struct sym_entry *sym;
   int param_num;

   for (sym = params; sym != NULL; sym = sym->u.param_info.next) {
      param_num = sym->u.param_info.param_num;
      if (sym->id_type & DrfPrm) {
         parminfo[param_num].cur_loc = sym->u.param_info.cur_loc;
         parminfo[param_num].parm_mod = sym->u.param_info.parm_mod;
         }
      }
   }

/*
 * mrg_prmloc - merge parameter location information in the symbol table
 *  with other information already saved in an array. This may result
 *  in conflicting location information, but conflicts are only detected
 *  when a parameter is actually used.
 */
void mrg_prmloc(parminfo)
struct parminfo *parminfo;
   {
   struct sym_entry *sym;
   int param_num;

   for (sym = params; sym != NULL; sym = sym->u.param_info.next) {
      param_num = sym->u.param_info.param_num;
      if (sym->id_type & DrfPrm) {
         parminfo[param_num].cur_loc |= sym->u.param_info.cur_loc;
         parminfo[param_num].parm_mod |= sym->u.param_info.parm_mod;
         }
      }
   }

/*
 * clr_prmloc - indicate that this execution path contributes nothing
 *   to the location of parameters.
 */
void clr_prmloc()
   {
   struct sym_entry *sym;

   for (sym = params; sym != NULL; sym = sym->u.param_info.next) {
      if (sym->id_type & DrfPrm) {
         sym->u.param_info.cur_loc = 0;
         sym->u.param_info.parm_mod = 0;
         }
      }
   }

/*
 * Reverse the type_select_lst and the selector_lst within it so that
 * the elements come out in the same order as the source file.
 */
static struct node *reverse_list(struct node *in)
{
    struct node *n = 0, *x;
    struct node *n2 = 0, *y, *z, *n3;
    for (x = in; x != NULL; x = x->u[0].child) {
        y = x->u[1].child;
        n2 = 0;
        for (z = y->u[0].child; z; z = z->u[0].child) {
            n2 = node2(z->nd_id, z->tok, n2, z->u[1].child);
        }
        n3 = node2(y->nd_id, y->tok, n2, y->u[1].child);
        n = node2(x->nd_id, x->tok, n, n3);
    }
    return n;
}

/*
 * typ_case - translate a type_case statement into C. This is called
 *  while walking a syntax tree of either RTL code or C code; the parameter
 *  "walk" is a function used to process the subtrees within the type_case
 *  statement.
 */
static int typ_case(var, slct_lst, dflt, walk, maybe_var, indent)
struct node *var;
struct node *slct_lst;
struct node *dflt;
int (*walk)(struct node *n, int xindent, int brace);
int maybe_var;
int indent;
   {
   struct node *lst;
   struct node *select;
   struct node *slctor;
   struct parminfo *strt_prms;
   struct parminfo *end_prms;
   int remaining;
   int first;
   int fnd_slctrs;
   int maybe_str = 1;
   int dflt_lbl = 0;
   int typcd;
   int fall_thru;
   char *s;

   /*
    * This statement involves multiple paths that may establish new
    *  scopes for parameters. Remember the starting scope information
    *  and initialize an array in which to compute the final information.
    */
   strt_prms = new_prmloc();
   sv_prmloc(strt_prms);
   end_prms = new_prmloc();

   /*
    * Create a copy of the list with the elements in the order they appear
    * in the source file.
    */
   slct_lst = reverse_list(slct_lst);

   /*
    * First look for cases that must be checked with "if" statements.
    *  These include string qualifiers and variables.
    */
   remaining = 0;      /* number of cases skipped in first pass */
   first = 1;          /* next case to be output is the first */
   if (dflt == NULL)
      fall_thru = 1;
   else
      fall_thru = 0;
   for (lst = slct_lst; lst != NULL; lst = lst->u[0].child) {
      select = lst->u[1].child;
      fnd_slctrs = 0; /* flag: found type selections for clause for this pass */
      /*
       * A selection clause may include several types. 
       */
      for (slctor = select->u[0].child; slctor != NULL; slctor =
        slctor->u[0].child) {
         typcd = icn_typ(slctor->u[1].child);
         if(typ_name(typcd, slctor->u[1].child->tok) == NULL) {
            /*
             * This type must be checked with the "if". Is this the
             *  first condition checked for this clause? Is this the
             *  first clause output?
             */
            if (fnd_slctrs)
               prt_str(" || ", indent);
            else {
               if (first)
                  first = 0;
               else {
                  ForceNl();
                  prt_str("else ", indent);
                  }
               prt_str("if (", indent);
               fnd_slctrs = 1;
               }
            
            /*
             * Output type check
             */
            typ_asrt(typcd, var, slctor->u[1].child->tok, indent + IndentInc);

            if (typcd == str_typ)
               maybe_str = 0;  /* string has been taken care of */
            else if (typcd == Variable)
               maybe_var = 0;  /* variable has been taken care of */
            }
         else
            ++remaining;
         }
      if (fnd_slctrs) {
         /*
          * We have found and output type selections for this clause;
          *  output the body of the clause. Remember any changes to
          *  paramter locations caused by type conversions within the
          *  clause.
          */
         prt_str(") {", indent + IndentInc);
         ForceNl();
         if ((*walk)(select->u[1].child, indent + IndentInc, 1)) {
            fall_thru |= 1;
            mrg_prmloc(end_prms);
            }
         prt_str("}", indent + IndentInc);
         ForceNl();
         ld_prmloc(strt_prms);
         }
      }
   /*
    * The rest of the cases can be checked with a "switch" statement, look
    *  for them..
    */
   if (remaining == 0) {
      if (dflt != NULL) {
         /*
          * There are no cases to handle with a switch statement, but there
          *  is a default clause; handle it with an "else".
          */
         prt_str("else {", indent);
         ForceNl();
         fall_thru |= (*walk)(dflt, indent + IndentInc, 1);
         ForceNl();
         prt_str("}", indent + IndentInc);
         ForceNl();
         }
      }
   else {
      /*
       * If an "if" statement was output, the "switch" must be in its "else"
       *   clause.
       */
      if (!first)
         prt_str("else ", indent);

      /*
       * A switch statement cannot handle types that are not simple type
       *  codes. If these have not taken care of, output code to check them.
       *  This will either branch around the switch statement or into
       *  its default clause.
       */
      if (maybe_str || maybe_var) {
         dflt_lbl = lbl_num++;      /* allocate a label number */
         prt_str("{", indent);
         ForceNl();
         prt_str("if (((", indent);
         c_walk(var, indent + IndentInc, 0);
         prt_str(").dword & D_Typecode) != D_Typecode) ", indent);
         ForceNl();
         prt_str("goto L", indent + IndentInc);
         fprintf(out_file, "%d;  /* default */ ", dflt_lbl);
         ForceNl();
         }

      no_nl = 1; /* suppress #line directives */
      prt_str("switch (Type(", indent);
      c_walk(var, indent + IndentInc, 0);
      prt_str(")) {", indent + IndentInc);
      no_nl = 0;
      ForceNl();

      /*
       * Loop through the case clauses producing code for them.
       */
      for (lst = slct_lst; lst != NULL; lst = lst->u[0].child) {
         select = lst->u[1].child;
         fnd_slctrs = 0;
         /*
          * A selection clause may include several types. 
          */
         for (slctor = select->u[0].child; slctor != NULL; slctor =
           slctor->u[0].child) {
            typcd = icn_typ(slctor->u[1].child);
            s = typ_name(typcd, slctor->u[1].child->tok);
            if (s != NULL) {
               /*
                * A type selection has been found that can be checked
                *  in the switch statement. Note that large integers
                *  require special handling.
                */
               fnd_slctrs = 1;

	       if (typcd == int_typ) {
		 ForceNl();

		 ForceNl();
		 prt_str("case T_Lrgint:  ", indent + IndentInc);
		 ForceNl();

		 ForceNl();
	       }

               prt_str("case T_", indent + IndentInc);
               prt_str(s, indent + IndentInc);
               prt_str(": ", indent + IndentInc);
               }
            }
         if (fnd_slctrs) {
            /*
             * We have found and output type selections for this clause;
             *  output the body of the clause. Remember any changes to
             *  paramter locations caused by type conversions within the
             *  clause.
             */
            ForceNl();
            if ((*walk)(select->u[1].child, indent + 2 * IndentInc, 0)) {
               fall_thru |= 1;
               ForceNl();
               prt_str("break;", indent + 2 * IndentInc);
               mrg_prmloc(end_prms);
               }
            ForceNl();
            ld_prmloc(strt_prms);
            }
         }
      if (dflt != NULL) {
         /*
          * This type_case statement has a default clause. If there is
          *  a branch into this clause, output the label. Remember any
          *  changes to paramter locations caused by type conversions
          *  within the clause.
          */
         ForceNl();
         prt_str("default:", indent + 1 * IndentInc);
         ForceNl();
         if (maybe_str || maybe_var) {
            prt_str("L", 0);
            fprintf(out_file, "%d: ;  /* default */", dflt_lbl);
            ForceNl();
            }
         if ((*walk)(dflt, indent + 2 * IndentInc, 0)) {
            fall_thru |= 1;
            mrg_prmloc(end_prms);
            }
         ForceNl();
         ld_prmloc(strt_prms);
         }
      prt_str("}", indent + IndentInc);

      if (maybe_str || maybe_var) {
         if (dflt == NULL) {
            /*
             * There is a branch around the switch statement. Output
             *  the label.
             */
            ForceNl();
            prt_str("L", 0);
            fprintf(out_file, "%d: ;  /* default */", dflt_lbl);
            }
         ForceNl();
         prt_str("}", indent + IndentInc);
         }
      ForceNl();
      }

   /*
    * Put ending parameter locations into effect.
    */
   mrg_prmloc(end_prms);
   ld_prmloc(end_prms);
   if (strt_prms != NULL)
      free(strt_prms);
   if (end_prms != NULL)
      free(end_prms);
   return fall_thru;
   }

/*
 * chk_conj - see if the left argument of a conjunction is an in-place
 *   conversion of a parameter other than a conversion to C_integer or
 *   C_double. If so issue a warning.
 */
static void chk_conj(n)
struct node *n;
   {
   struct node *cnv_type;
   struct node *src;
   struct node *dest;
   int typcd;

   if (n->nd_id == BinryNd && n->tok->tok_id == And)
      n = n->u[1].child;

   switch (n->nd_id) {
      case TrnryNd:
         /*
          * Must be Cnv.
          */
         cnv_type = n->u[0].child;
         src = n->u[1].child;
         dest = n->u[2].child;
         break;
      case QuadNd:
         /*
          * Must be Def.
          */
         cnv_type = n->u[0].child;
         src = n->u[1].child;
         dest = n->u[3].child;
         break;
      default:
         return;   /* not a  conversion */
      }

   /*
    * A conversion has been found. See if it meets the criteria for
    *  issuing a warning.
    */

   if (src->nd_id != SymNd || !(src->u[0].sym->id_type & DrfPrm))
      return;  /* not a dereferenced parameter */

   typcd = icn_typ(cnv_type);
   switch (typcd) {
      case TypCInt:
      case TypCDbl:
      case TypECInt:
         return;
      }

   if (dest != NULL)
      return;   /* not an in-place convertion */

   fprintf(stderr,
    "%s: file %s, line %d, warning: in-place conversion may or may not be\n",
      progname, cnv_type->tok->fname, cnv_type->tok->line);
   fprintf(stderr, "\tundone on subsequent failure.\n");
   }


/*
 * rt_walk - walk the part of the syntax tree containing rtt code, producing
 *   code for the most-general version of the routine.
 */
static int rt_walk(n, indent, brace)
struct node *n;
int indent;
int brace;
   {
   struct token *t;
   struct node *n1;
   int fall_thru;

   if (n == NULL)
      return 1;

   t =  n->tok;

   switch (n->nd_id) {
      case PrefxNd:
         switch (t->tok_id) {
            case '{':
               /*
                * RTL code: { <actions> }
                */
               if (brace) 
                  tok_line(t, indent); /* just synch file name and line num */
               else
                  prt_tok(t, indent);  /* { */
               fall_thru = rt_walk(n->u[0].child, indent, 1);
               if (!brace)
                  prt_str("}", indent);
               return fall_thru;
            case '!':
               /*
                * RTL type-checking and conversions: ! <simple-type-check>
                */
               prt_tok(t, indent);
               rt_walk(n->u[0].child, indent, 0);
               return 1;
            case Body:
               /*
                * RTL code: body { <c-code> }
                */
               fall_thru = c_walk(n->u[0].child, indent, brace);
               if (!fall_thru)
                  clr_prmloc();
               return fall_thru;
            }
         break;
      case BinryNd:
         switch (t->tok_id) {
            case Runerr:
               /*
                * RTL code: runerr( <message-number> )
                *           runerr( <message-number>, <descriptor> )
                */
               prt_runerr(t, n->u[0].child, n->u[1].child, indent);

               /*
                * Execution cannot continue on this execution path.
                */
               clr_prmloc();
               return 0;
            case And:
               /*
                * RTL type-checking and conversions:
                *   <type-check> && <type_check>
                */
               chk_conj(n->u[0].child);  /* is a warning needed? */
               rt_walk(n->u[0].child, indent, 0);
               prt_str(" ", indent);
               prt_tok(t, indent);       /* && */
               prt_str(" ", indent);
               rt_walk(n->u[1].child, indent, 0);
               return 1;
            case Is:
               /*
                * RTL type-checking and conversions:
                *   is: <icon-type> ( <variable> )
                */
               typ_asrt(icn_typ(n->u[0].child), n->u[1].child,
                  n->u[0].child->tok, indent);
               return 1;
            }
         break;
      case ConCatNd:
         /*
          * "Glue" for two constructs.
          */
         fall_thru = rt_walk(n->u[0].child, indent, 0);
         return fall_thru & rt_walk(n->u[1].child, indent, 0);
      case AbstrNd:
         /*
          * Ignore abstract type computations while producing C code
          *  for library routines.
          */
         return 1;
      case TrnryNd:
         switch (t->tok_id) {
            case If: {
               /*
                * RTL code for "if" statements:
                *  if <type-check> then <action>
                *  if <type-check> then <action> else <action>
                *
                *  <type-check> may include parameter conversions that create
                *  new scoping. It is necessary to keep track of paramter
                *  types and locations along success and failure paths of
                *  these conversions. The "then" and "else" actions may
                *  also establish new scopes.
                */
               struct parminfo *then_prms = NULL;
               struct parminfo *else_prms;

               /*
                * Save the current parameter locations. These are in
                *  effect on the failure path of any type conversions
                *  in the condition of the "if".
                */
               else_prms = new_prmloc();
               sv_prmloc(else_prms);

               prt_tok(t, indent);       /* if */
               prt_str(" (", indent);
               n1 = n->u[0].child;
               rt_walk(n1, indent + IndentInc, 0);   /* type check */
               prt_str(") {", indent);

               /*
                * If the condition is negated, the failure path is to the "then"
                *  and the success path is to the "else".
                */
               if (n1->nd_id == PrefxNd && n1->tok->tok_id == '!') {
                  then_prms = else_prms;
                  else_prms = new_prmloc();
                  sv_prmloc(else_prms);
                  ld_prmloc(then_prms);
                  }

               /*
                * Then Clause.
                */
               fall_thru = rt_walk(n->u[1].child, indent + IndentInc, 1);
               ForceNl();
               prt_str("}", indent + IndentInc);

               /*
                * Determine if there is an else clause and merge parameter
                *  location information from the alternate paths through
                *  the statement.
                */
               n1 = n->u[2].child;
               if (n1 == NULL) {
                  if (fall_thru)
                     mrg_prmloc(else_prms);
                  ld_prmloc(else_prms);
                  fall_thru = 1;
                  }
               else {
                  if (then_prms == NULL)
                     then_prms = new_prmloc();
                  if (fall_thru)
                     sv_prmloc(then_prms);
                  ld_prmloc(else_prms);
                  ForceNl();
                  prt_str("else {", indent);
                  if (rt_walk(n1, indent + IndentInc, 1)) {  /* else clause */
                     fall_thru = 1;
                     mrg_prmloc(then_prms);
                     }
                  ForceNl();
                  prt_str("}", indent + IndentInc);
                  ld_prmloc(then_prms);
                  }
               ForceNl();
               if (then_prms != NULL)
                  free(then_prms);
               if (else_prms != NULL)
                  free(else_prms);
               }
               return fall_thru;
            case Type_case: {
               /*
                * RTL code:
                *   type_case <variable> of {
                *       <icon_type> : ... <icon_type> : <action>
                *          ...
                *       }
                *
                *   last clause may be: default: <action>
                */
               int maybe_var;
               struct node *var;
               struct sym_entry *sym;

               /*
                * If we can determine that the value being checked is
                *  not a variable reference, we don't have to produce code
                *  to check for that possibility.
                */
               maybe_var = 1;
               var = n->u[0].child;
               if (var->nd_id == SymNd) {
                  sym = var->u[0].sym;
                  switch(sym->id_type) {
                     case DrfPrm:
                     case OtherDcl:
                     case TndDesc:
                     case TndStr:
                        if (sym->nest_lvl > 1) {
                           /*
                            * The thing being tested is either a
                            *  dereferenced parameter or a local
                            *  descriptor which could only have been
                            *  set by a conversion which does not
                            *  produce a variable reference.
                            */
                           maybe_var = 0;
                           }
                      }
                  }
               return typ_case(var, n->u[1].child, n->u[2].child, rt_walk,
                  maybe_var, indent);
               }
            case Cnv:
               /*
                * RTL code: cnv: <type> ( <source> )
                *           cnv: <type> ( <source> , <destination> )
                */
               cnv_fnc(t, icn_typ(n->u[0].child), n->u[1].child, NULL,
                  n->u[2].child, indent);
               return 1;
            }
      case QuadNd:
         /*
          * RTL code: def: <type> ( <source> , <default>)
          *           def: <type> ( <source> , <default> , <destination> )
          */
         cnv_fnc(t, icn_typ(n->u[0].child), n->u[1].child, n->u[2].child,
            n->u[3].child, indent);
         return 1;
      }
   /*NOTREACHED*/
   return 0;  /* avoid gcc warning */
   }

/*
 * spcl_dcls - print special declarations for tended variables, parameter
 *  conversions, and buffers.
 */
void spcl_dcls()
{
    tend_ary(ntend);

    tend_struct_loc = "r_tend";
    tend_loc = "r_tend.d";

    /*
     * Produce code to initialize the tended array. These are for tended
     *  declarations and parameters.
     */
    tend_init();  /* initializations for tended declarations. */

    /*
     * Finish setting up the tended array structure and link it into the tended
     *  list.
     */
    if (ntend != 0) {
        prt_str(tend_struct_loc, IndentInc);
        fprintf(out_file, ".num = %d;", ntend);
        ForceNl();
        prt_str(tend_struct_loc, IndentInc);
        prt_str(".previous = tendedlist;", IndentInc);
        ForceNl();
        prt_str("tendedlist = (struct tend_desc *)&", IndentInc);
        fprintf(out_file, "%s;", tend_struct_loc);
        ForceNl();
    }
}


/*
 * tend_ary - write struct containing array of tended descriptors.
 */
static void tend_ary(n)
int n;
   {
   if (n == 0)
      return;
   prt_str("struct {", IndentInc);
   ForceNl();
   prt_str("struct tend_desc *previous;", 2 * IndentInc);
   ForceNl();
   prt_str("int num;", 2 * IndentInc);
   ForceNl();
   prt_str("struct descrip d[", 2 * IndentInc);
   fprintf(out_file, "%d];", n);
   ForceNl();
   prt_str("} r_tend;\n", 2 * IndentInc);
   ++line;
   ForceNl();
   }

/*
 * tend_init - produce code to initialize entries in the tended array
 *  corresponding to tended declarations. Default initializations are
 *  supplied when there is none in the declaration.
 */
static void tend_init()
{
    register struct init_tend *tnd;
    int n = 0;

    for (tnd = tend_lst; tnd != NULL; tnd = tnd->next) {
        n++;
        switch (tnd->init_typ) {
            case TndDesc:
                /*
                 * Simple tended declaration.
                 */
                if (tnd->init == NULL) {
                    /* For a frame, the tended descriptors are initialized to nulldesc by alc_c_frame */
                    if (op_type == OrdFunc || in_quick) {
                        prt_str(tend_loc, IndentInc);
                        fprintf(out_file, "[%d] = nulldesc;", tnd->t_indx);
                    }
                } else {
                    prt_str(tend_loc, IndentInc);
                    fprintf(out_file, "[%d] = ", tnd->t_indx);
                    c_walk(tnd->init, 2 * IndentInc, 0);
                    prt_str(";", 2 * IndentInc);
                }
                break;
            case TndStr:
                /*
                 * Tended character pointer.
                 */
                prt_str(tend_loc, IndentInc);
                if (tnd->init == NULL)
                    fprintf(out_file, "[%d] = emptystr;", tnd->t_indx);
                else {
                    fprintf(out_file, "[%d].dword = 0;", tnd->t_indx);
                    ForceNl();
                    prt_str(tend_loc, IndentInc);
                    fprintf(out_file, "[%d].vword.sptr = ", tnd->t_indx);
                    c_walk(tnd->init, 2 * IndentInc, 0);
                    prt_str(";", 2 * IndentInc);
                }
                break;
            case TndBlk:
                /*
                 * A tended block pointer of some kind.
                 */
                prt_str(tend_loc, IndentInc);
                if (tnd->init == NULL)
                    fprintf(out_file, "[%d] = nullptr;", tnd->t_indx);
                else {
                    fprintf(out_file, "[%d].dword = D_TendPtr;",tnd->t_indx);
                    ForceNl();
                    prt_str(tend_loc, IndentInc);
                    fprintf(out_file, "[%d].vword.bptr = (union block *)",
                            tnd->t_indx);
                    c_walk(tnd->init, 2 * IndentInc, 0);
                    prt_str(";", 2 * IndentInc);
                }
                break;
        }
        ForceNl();
    }

    if (in_quick) {
       /* Init remaining tended descs to nulldesc.  These will be
        * dereferenced params in an underef operator, and operator
        * params.  Eg operator / null(underef x -> dx) has two extra, 
        * one for x and dx.
        */
        while (n < ntend) {
            prt_str(tend_loc, IndentInc);
            fprintf(out_file, "[%d] = nulldesc;", n);
            ForceNl();
            ++n;
        }
    }
}

/*
 * parm_locs - determine what locations are needed to hold parameters and
 *  their conversions. Produce declarations for the C_integer and C_double
 *  locations.
 */
static void parm_locs(op_params)
struct sym_entry *op_params;
   {
   struct sym_entry *next_parm;

   /*
    * Parameters are stored in reverse order: Recurse down the list
    *  and perform processing on the way back.
    */
   if (op_params == NULL)
      return;
   next_parm = op_params->u.param_info.next;
   parm_locs(next_parm);

   /*
    * For interpreter routines, extra tended descriptors are only needed
    *  when both dereferenced and undereferenced values are requested.
    */
   if ((next_parm == NULL ||
      op_params->u.param_info.param_num != next_parm->u.param_info.param_num))
      op_params->t_indx = -1;
   else
      op_params->t_indx = ntend++;

   }

/*
 * real_def - see if a declaration really defines storage.
 */
static int real_def(n)
struct node *n;
   {
   struct node *dcl_lst;

   dcl_lst = n->u[1].child;
   /*
    * If no variables are being defined this must be a tag declaration.
    */
   if (dcl_lst == NULL)
      return 0;
   
   if (only_proto(dcl_lst))
      return 0;

   if (tdef_or_extr(n->u[0].child))
      return 0;

   return 1;
   }

/*
 * only_proto - see if this declarator list contains only function prototypes.
 */
static int only_proto(n)
struct node *n;
   {
   switch (n->nd_id) {
      case CommaNd:
         return only_proto(n->u[0].child) & only_proto(n->u[1].child);
      case ConCatNd:
         /*
          * Optional pointer.
          */
         return only_proto(n->u[1].child);
      case BinryNd:
         switch (n->tok->tok_id) {
            case '=':
               return only_proto(n->u[0].child);
            case '[':
               /*
                * At this point, assume array declarator is not part of
                *  prototype.
                */
               return 0;
            case ')':
               /*
                * Prototype (or forward declaration).
                */
               return 1;
            }
      case PrefxNd:
         /*
          * Parenthesized.
          */
         return only_proto(n->u[0].child);
      case PrimryNd:
         /*
          * At this point, assume it is not a prototype.
          */
         return 0;
      }
   err1("rtt internal error detected in function only_proto()");
   /*NOTREACHED*/
   return 0;  /* avoid gcc warning */
   }

/*
 * tdef_or_extr - see if this is a typedef or extern.
 */
static int tdef_or_extr(n)
struct node *n;
   {
   switch (n->nd_id) {
      case LstNd:
         return tdef_or_extr(n->u[0].child) | tdef_or_extr(n->u[1].child);
      case BinryNd:
         /*
          * struct, union, or enum.
          */
         return 0;
      case PrimryNd:
         if (n->tok->tok_id == Extern || n->tok->tok_id == Typedef)
            return 1;
         else
            return 0;
      }
   err1("rtt internal error detected in function tdef_or_extr()");
   /*NOTREACHED*/
   return 0;  /* avoid gcc warning */
   }

/*
 * dclout - output an ordinary global C declaration.
 */
void dclout(n)
struct node *n;
   {
   if (!enable_out)
      return;        /* output disabled */
   if (real_def(n))
      def_fnd = 1;   /* this declaration defines a run-time object */
   c_walk(n, 0, 0);
   free_tree(n);
   }

static void count_ntend()
{
    struct init_tend *t = tend_lst;
    ntend = 0;
    while (t) {
        ++ntend;
        t = t->next;
    }
}

/*
 * fncout - output code for a C function.
 */
void fncout(head, prm_dcl, block)
struct node *head;
struct node *prm_dcl;
struct node *block;
   {
   if (!enable_out)
      return;       /* output disabled */

   def_fnd = 1;     /* this declaration defines a run-time object */
   nxt_sbuf = 0;    /* clear number of string buffers */
   nxt_cbuf = 0;    /* clear number of cset buffers */

   count_ntend();

   /*
    * Output the function header and the parameter declarations.
    */
   fnc_head = head;
   c_walk(head, 0, 0);
   prt_str(" ",  0);
   c_walk(prm_dcl, 0, 0);
   prt_str(" ", 0);

   /* 
    * Handle outer block.
    */
   prt_tok(block->tok, IndentInc);          /* { */
   c_walk(block->u[0].child, IndentInc, 0); /* non-tended declarations */
   spcl_dcls();                         /* tended declarations */
   no_ret_val = 1;
   c_walk(block->u[2].child, IndentInc, 0); /* statement list */
   if (ntend != 0 && no_ret_val) {
      /*
       * This function contains no return statements with values, assume
       *  that the programmer is using the implicit return at the end
       *  of the function and update the tending of descriptors.
       */
      untend(IndentInc);
      }
   ForceNl();
   prt_str("}", IndentInc);
   ForceNl();

   /*
    * free storage.
    */
   free_tree(head);
   free_tree(prm_dcl);
   free_tree(block);
   pop_cntxt();
   clr_def();
   }

/*
 * defout - output operation definitions (except for constant keywords)
 */
void defout(n)
struct node *n;
   {
   struct sym_entry *sym, *sym1;

   if (!enable_out)
      return;       /* output disabled */

   nxt_sbuf = 0;
   nxt_cbuf = 0;
   lab_seq = 0;

   interp_def(n);

   free_tree(n);
   /*
    * The declarations for the declare statement are not associated with
    *  any compound statement and must be freed here.
    */
   sym = dcl_stk->tended;
   while (sym != NULL) {
      sym1 = sym;
      sym = sym->u.tnd_var.next;
      free_sym(sym1);
      }
   while (decl_lst != NULL) {
      sym1 = decl_lst;
      decl_lst = decl_lst->u.declare_var.next;
      free_sym(sym1);
      }
   op_type = OrdFunc;
   pop_cntxt();
   clr_def();
   }

static void print_func_vars()
{
   struct sym_entry *t;

   t = ffirst;

   while (t) {
       if (t->id_type == OtherDcl && in_frame(t->u.declare_var.tqual)) {
           ForceNl();
           c_walk(t->u.declare_var.tqual,3,0);
           fprintf(out_file, " ");
           c_walk(t->u.declare_var.dcltor,3,0);
           prt_str(";",0);
       }
       t = t->fnext;
   }

   /*
    * Temporary vars
    */
   t = params;
   while (t) {
       if (t->u.param_info.non_tend & PrmInt) {
           fprintf(out_file, "   word r_i%d;\n", t->u.param_info.param_num); ++line;
       }
       if (t->u.param_info.non_tend & PrmDbl) {
           fprintf(out_file, "   double r_d%d;\n", t->u.param_info.param_num); ++line;
       }
       t = t->u.param_info.next;
   }
}

/*
 * interp_def - output code for the interpreter for operation definitions.
 */
static void interp_def(n)
struct node *n;
   {
   struct sym_entry *sym;
   int has_underef;
   int vararg = 0;
   char letter = 0;
   char *name;
   char *s;
   int i;
   struct parminfo *saved;
   
   /*
    * Note how result location is accessed in generated code.
    */
   tend_struct_loc = "???";
   tend_loc = "frame->tend";
   n_args = "frame->nargs";

   /*
    * Determine if the operation has any undereferenced parameters.
    */
   has_underef = 0;
   for (sym = params; sym != NULL; sym = sym->u.param_info.next)
      if (sym->id_type  & RtParm) {
         has_underef = 1;
         break;
         }

   /*
    * Determine the nuber of parameters, and whether they are varags
    */
   if (params == NULL)
      nparms = 0;
   else {
       nparms = params->u.param_info.param_num + 1;
       if (params->id_type & VarPrm) 
           vararg = 1;
   }

   count_ntend();

   name = op_name;

   /*
    * Determine what letter is used to prefix the operation name.
    */
   switch (op_type) {
      case TokFunction:
         letter = 'Z';
         break;
      case Keyword:
         letter = 'K';
         break;
      case Operator:
         letter = 'O';
         }

   fprintf(out_file, "\n"); ++line;

   /*
    * Output the header struct.
    */

   in_struct = 1;
   fprintf(out_file, "\nstruct %s_frame {\n   C_FRAME\n", op_name);
   line += 3;

   if (op_generator)
       print_func_vars();

   fprintf(out_file, "\n};\n"); line += 2;

   in_struct = 0;

   /*
    * Output function header.
    */
   fprintf(out_file, "static int %c%s(struct %s_frame *frame)\n{\n", letter, name, name);

   if (op_generator) {
#if HAVE_COMPUTED_GOTO
       fprintf(out_file, "       if (frame->pc)\n");
       fprintf(out_file, "          goto *((void *)(frame->pc));\n");
#else
       {
           int i;
           fprintf(out_file, "   switch (frame->pc) {\n");
           fprintf(out_file, "      case 0: break;\n");
           for (i = 1; i <= op_generator; ++i)
               fprintf(out_file, "      case %d: goto Lab%d;\n", i, i);
           fprintf(out_file, "      default: syserr(\"Invalid pc in %s\");\n", name);
           fprintf(out_file, "   }\n");
       }
#endif
   } else
       print_func_vars();

   /* Force a line directive at next token */
   line = 0;

   /*
    * Output special declarations and initial processing.
    */
   ForceNl();
   parm_locs(params);

   if (has_underef && params != NULL && params->id_type == (VarPrm | DrfPrm))
       prt_str("int r_n;\n", IndentInc);

   tend_init();
   ForceNl();

   /*
    * See which parameters need to be dereferenced. If all are dereferenced,
    *  it is done by before the routine is called.
    */
   if (has_underef) {
       sym = params;
       if (sym != NULL && sym->id_type & VarPrm) {
           if (sym->id_type & DrfPrm) {
               /*
                * There is a variable part of the parameter list and it
                *  must be dereferenced.
                */
               prt_str("for (r_n = ", IndentInc);
               fprintf(out_file, "%d; r_n <= frame->nargs; ++r_n)",
                       sym->u.param_info.param_num);
               ForceNl();
               prt_str("Deref(frame->args[r_n]);", IndentInc * 2);
               ForceNl();
           }
           sym = sym->u.param_info.next;
       }

       /*
        * Produce code to dereference any fixed parameters that need to be.
        */
       while (sym != NULL) {
           if (sym->id_type & DrfPrm) {
               /*
                * Tended index of -1 indicates that the parameter can be
                *  dereferened in-place (this is the usual case).
                */
               if (sym->t_indx == -1) {
                   chk_nl(IndentInc);
                   fprintf(out_file, "Deref(frame->args[%d]);", sym->u.param_info.param_num);
               }
               else {
                   chk_nl(IndentInc);
                   fprintf(out_file, "deref(&frame->args[%d], &%s[%d]);",
                           sym->u.param_info.param_num, 
                           tend_loc, sym->t_indx);
               }
           }
           ForceNl();
           sym = sym->u.param_info.next;
       }
   }

   /*
    * Output ordinary declarations from the declare clause.
    */
   for (sym = decl_lst; sym != NULL; sym = sym->u.declare_var.next) {
       decl_walk3(sym->u.declare_var.tqual, sym->u.declare_var.dcltor, IndentInc);
   }

   saved = new_prmloc();
   sv_prmloc(saved);

   /*
    * Finish setting up the tended array structure and link it into the tended
    *  list.
    */
   if (rt_walk(n, IndentInc, 0)) { /* body of operation */
       if (n->nd_id == ConCatNd)
           s = n->u[1].child->tok->fname;
       else
           s = n->tok->fname;
       fprintf(stderr, "%s: file %s, warning: ", progname, s);
       fprintf(stderr, "execution may fall off end of operation \"%s\"\n",
               op_name);
   }
   ForceNl();

   if (op_generator != lab_seq)
       err1("internal error, lab_seq should end up == op_generator");

   /* Force a line directive at next token */
   line = 0;
   prt_str("}\n", IndentInc);

   /*
    * Output procedure block.
    */
   switch (op_type) {
       case Keyword:
           fprintf(out_file, "KeywordBlock(%s, %d)\n\n", name, ntend);
           line += 2;
           break;

       case TokFunction:
#if MSWIN32
           if (importing)
               fprintf(out_file, "FncBlockDLL(%s, %d, %d, %d, %d)\n\n", name, nparms, vararg, ntend, has_underef);
           else
               fprintf(out_file, "FncBlock(%s, %d, %d, %d, %d)\n\n", name, nparms, vararg, ntend, has_underef);
#else
           fprintf(out_file, "FncBlock(%s, %d, %d, %d, %d)\n\n", name, nparms, vararg, ntend, has_underef);
#endif
           line += 2;
           break;

       case Operator: {
           if (strcmp(op_sym,"\\") == 0)
               fprintf(out_file, "OpBlock(%s, %d, %d, \"%s\", %d)\n\n", name, nparms, 
                       ntend, "\\\\", has_underef);
           else
               fprintf(out_file, "OpBlock(%s, %d, %d, \"%s\", %d)\n\n", name, nparms, 
                       ntend, op_sym, has_underef);
           line += 2;
       }
   }


   if ((op_type == Operator || op_type == Keyword) && !op_generator) {
       int monogenic = 0;
       int has_rval = 0;

       ntend += nparms;
       /*
        * Output quick function.
        */
       if (op_type == Keyword)
           fprintf(out_file, "void do_key_%s()\n{\n", name);
       else
           fprintf(out_file, "void do_op_%s()\n{\n", name);
       in_quick = 1;
       ForceNl();
       print_func_vars();
       ForceNl();
       ld_prmloc(saved);

       /* Force a line directive at next token */
       line = 0;

       if (op_type == Operator) {
           if (strcmp(name, "cat") == 0 ||
               strcmp(name, "diff") == 0 ||
               strcmp(name, "div") == 0 ||
               strcmp(name, "inter") == 0 ||
               strcmp(name, "lconcat") == 0 ||
               strcmp(name, "minus") == 0 ||
               strcmp(name, "mod") == 0 ||
               strcmp(name, "mult") == 0 ||
               strcmp(name, "plus") == 0 ||
               strcmp(name, "power") == 0 ||
               strcmp(name, "union") == 0 ||
               strcmp(name, "value") == 0 ||
               strcmp(name, "size") == 0 ||
               strcmp(name, "refresh") == 0 ||
               strcmp(name, "number") == 0 ||
               strcmp(name, "compl") == 0 ||
               strcmp(name, "neg") == 0)
               monogenic = 1;

           if (strcmp(name, "random") == 0 ||
               strcmp(name, "sect") == 0 ||
               strcmp(name, "subsc") == 0)
               has_rval = 1;
       }

       /*
        * Output special declarations and initial processing.
        */
       ForceNl();
#if __GNUC__
       /* Avoid spurious unused variable warnings if using gcc. */
       fprintf(out_file, "\n   dptr __attribute__((unused)) _lhs;\n");
       if (!monogenic)
           fprintf(out_file, "   word __attribute__((unused)) *_failure_label;\n");
       if (has_rval)
           fprintf(out_file, "   int __attribute__((unused)) _rval;");
#else
       fprintf(out_file, "\n   dptr _lhs;\n");
       if (!monogenic)
           fprintf(out_file, "   word *_failure_label;\n");
       if (has_rval)
           fprintf(out_file, "   int _rval;");
#endif

       spcl_dcls();                         /* tended declarations */
       ForceNl();

       fprintf(out_file, "\n   _lhs = get_dptr();\n");
       for (i = 0; i < nparms; ++i) {
           if (has_underef)
               fprintf(out_file, "   get_variable(&r_tend.d[%d]);\n", ntend - nparms + i);
           else
               fprintf(out_file, "   get_deref(&r_tend.d[%d]);\n", ntend - nparms + i);
       }
       if (has_rval)
           fprintf(out_file, "   _rval = GetWord;\n");
       if (!monogenic)
           fprintf(out_file, "   _failure_label = GetAddr;\n");
    
       if (has_underef) {
           sym = params;
           /*
            * Produce code to dereference any fixed parameters that need to be.
            */
           while (sym != NULL) {
               if (sym->id_type & DrfPrm) {
                   /*
                    * Tended index of -1 indicates that the parameter can be
                    *  dereferened in-place (this is the usual case).
                    */
                   if (sym->t_indx == -1) {
                       chk_nl(IndentInc);
                       fprintf(out_file, "Deref(r_tend.d[%d]);", ntend - nparms + sym->u.param_info.param_num);
                   }
                   else {
                       chk_nl(IndentInc);
                       fprintf(out_file, "deref(&r_tend.d[%d], &%s[%d]);",
                               ntend - nparms + sym->u.param_info.param_num, 
                               tend_loc, sym->t_indx);
                   }
               }
               ForceNl();
               sym = sym->u.param_info.next;
           }
       }

       /*
        * Output ordinary declarations from the declare clause.
        */
       for (sym = decl_lst; sym != NULL; sym = sym->u.declare_var.next) {
           decl_walk3(sym->u.declare_var.tqual, sym->u.declare_var.dcltor, IndentInc);
       }

       if (rt_walk(n, IndentInc, 0)) { /* body of operation */
           if (n->nd_id == ConCatNd)
               s = n->u[1].child->tok->fname;
           else
               s = n->tok->fname;
           fprintf(stderr, "%s: file %s, warning: ", progname, s);
           fprintf(stderr, "execution may fall off end of operation \"%s\"\n",
                   op_name);
       }

       in_quick = 0;
       fprintf(out_file, "\n}\n");
   } else {
   }
}


/*
 * keepdir - A preprocessor directive to be kept has been encountered.
 *   If it is #passthru, print just the body of the directive, otherwise
 *   print the whole thing.
 */
void keepdir(t)
struct token *t;
   {
   char *s;

   tok_line(t, 0);
   s = t->image;
   if (strncmp(s, "#passthru", 9) == 0)
      s = s + 10;
   fprintf(out_file, "%s\n", s);
   line += 1;
   }

/*
 * prologue - print standard comments and preprocessor directives at the
 *   start of an output file.
 */
void prologue()
{
   static char sbuf[26];
   static int first_time = 1;
   time_t ct;

   if (first_time) {
      time(&ct);
      strcpy(sbuf, ctime(&ct));
      first_time = 0;
      }
   fprintf(out_file, "/*\n");
   fprintf(out_file, " * %s", sbuf);
   fprintf(out_file, " * This file was produced by\n");
   fprintf(out_file, " *   %s: %s\n", progname, Version);
   fprintf(out_file, " */\n");
   fprintf(out_file, "#include \"%s\"\n\n", inclname);
   if (importing) {
       fprintf(out_file, "#include \"%s\"\n\n", importedhname);
       if (subsid)
           fprintf(out_file, "extern struct oisymbols *imported;\n\n");
       else {
           fprintf(out_file, "/* Initialized by oix when the library is loaded. */\n");
#if MSWIN32
           fprintf(out_file, "__declspec(dllexport)\n");
#endif
           fprintf(out_file, "struct oisymbols *imported;\n\n");
       }
   }
}

/*
 * just_type - strip non-type information from a type-qualifier list. Print
 *   it in the output file and if ilc is set, produce in-line C code.
 */
static void just_type(struct node *typ, int indent, int ilc)
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

