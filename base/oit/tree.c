/*
 * tree.c -- functions for constructing parse trees
 */

#include "icont.h"
#include "tree.h"
#include "tmem.h"
#include "membuff.h"

#define NewNode(size) mb_zalloc(&file_mb, sizeof(struct node) + (size-1) * sizeof(union field))

/*
 *  tree[1-6] construct parse tree nodes with specified values.
 *   Parameters a and b are line and column information,
 *   while parameters c through f are values to be assigned to n_field[0-3].
 *   Note that this could be done with a single routine; a separate routine
 *   for each node size is used for speed and simplicity.
 */

nodeptr tree1(int type)
   {
   nodeptr t;

   t = NewNode(0);
   t->n_type = type;
   t->n_file = tok_loc.n_file;
   t->n_line = tok_loc.n_line;
   t->n_col = tok_loc.n_col;
   return t;
   }

nodeptr tree2(int type, nodeptr loc_model)
   {
   nodeptr t;

   t = NewNode(0);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   return t;
   }

nodeptr tree3(int type, nodeptr loc_model, nodeptr c)
   {
   nodeptr t;

   t = NewNode(1);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_ptr = c;
   return t;
   }

nodeptr tree4(int type, nodeptr loc_model, nodeptr c, nodeptr d)
   {
   nodeptr t;

   t = NewNode(2);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_ptr = c;
   t->n_field[1].n_ptr = d;
   return t;
   }

nodeptr tree5(int type, nodeptr loc_model, nodeptr c, nodeptr d, nodeptr e)
   {
   nodeptr t;

   t = NewNode(3);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_ptr = c;
   t->n_field[1].n_ptr = d;
   t->n_field[2].n_ptr = e;
   return t;
   }

nodeptr tree6(int type, nodeptr loc_model, nodeptr c, nodeptr d, nodeptr e, nodeptr f)
   {
   nodeptr t;

   t = NewNode(4);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_ptr = c;
   t->n_field[1].n_ptr = d;
   t->n_field[2].n_ptr = e;
   t->n_field[3].n_ptr = f;
   return t;
   }

nodeptr int_leaf(int type, nodeptr loc_model, int c)
   {
   nodeptr t;

   t = NewNode(1);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_val = c;
   return t;
   }

nodeptr c_str_leaf(int type, nodeptr loc_model, char *c)
   {
   nodeptr t;

   t = NewNode(1);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_str = c;
   return t;
   }

nodeptr i_str_leaf(int type, nodeptr loc_model, char *c, int d)
   {
   nodeptr t;

   t = NewNode(2);
   t->n_type = type;
   t->n_file = loc_model->n_file;
   t->n_line = loc_model->n_line;
   t->n_col = loc_model->n_col;
   t->n_field[0].n_str = c;
   t->n_field[1].n_val = d;
   return t;
   }
