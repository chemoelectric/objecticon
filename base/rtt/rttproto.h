int               alloc_tnd (int typ, struct node *init, int lvl);
int               c_walk    (struct node *n, int indent, int brace);
int               call_ret  (struct node *n);
struct token     *chk_exct  (struct token *tok);
void           clr_def   (void);
void           clr_prmloc (void);
struct token     *cnv_to_id (struct token *t);
char             *cnv_name  (int typcd, struct node *dflt, int *dflt_to_ptr);
struct node      *comp_nd   (struct token *tok, struct node *dcls,
                              struct node *stmts);
int               creat_obj (void);
void           d_lst_typ (struct node *dcls, int in_declare);
void           dclout    (struct node *n);
struct node      *dest_node (struct token *tok);
void           dst_alloc (struct node *cnv_typ, struct node *var);
void           fncout    (struct node *head, struct node *prm_dcl,
                              struct node *block);
void           force_nl  (int indent);
void           free_sym  (struct sym_entry *sym);
void           free_tree (struct node *n);
void           free_tend (void);
void           func_def  (struct node *dcltor);
void           id_def    (struct node *dcltor, struct node *x);
void           keepdir   (struct token *s);
int               icn_typ   (struct node *n);
void           impl_fnc  (struct token *name);
void           impl_key  (struct token *name);
void           impl_op   (struct token *op_sym, struct token *name);
void           init_lex  (void);
void           init_sym  (void);
void           in_line   (struct node *n);
struct node      *lbl       (struct token *t);
void           ld_prmloc (struct parminfo *parminfo);
void           mrg_prmloc (struct parminfo *parminfo);
struct parminfo  *new_prmloc (void);
struct node      *node0     (int id, struct token *tok);
struct node      *node1     (int id, struct token *tok, struct node *n1);
struct node      *node2     (int id, struct token *tok, struct node *n1,
                              struct node *n2);
struct node      *node3     (int id, struct token *tok, struct node *n1,
                              struct node *n2, struct node *n3);
struct node      *node4     (int id, struct token *tok, struct node *n1,
                              struct node *n2, struct node *n3,
                              struct node *n4);
void	pop_cntxt	(void);
void           pop_lvl   (void);
void           prologue  (void);
void           prt_str   (char *s, int indent);
void		  ptout	    (struct token * x);
void	push_cntxt	(int lvl_incr);
void           push_lvl  (void);
void           defout    (struct node *n);
void           spcl_dcls (void);
void           strt_def  (void);
void           sv_prmloc (struct parminfo *parminfo);
struct sym_entry *sym_add  (int tok_id, char *image, int id_type, int nest_lvl);
struct sym_entry *sym_lkup  (char *image);
struct node      *sym_node  (struct token *tok);
void           s_prm_def (struct token *u_ident, struct token *d_ident);
void           tnd_char  (void);
void           tnd_strct (struct token *t);
void           tnd_union (struct token *t);
void           trans     (char *src_file);
char             *typ_name  (int typ, struct token *tok);
void           unuse     (struct init_tend *t_lst, int lvl);
void           var_args  (struct token *ident);
void           yyerror   (char *s);
int               yylex     (void);
int               yyparse   (void);
