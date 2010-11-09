/*
 * Prototypes for run-time functions.
 */

/*
 * Prototypes common to the compiler and interpreter.
 */
void            EVInit          (void);
word            add             (word a,word b);
void            addmem  (struct b_set *ps,struct b_selem *pe, union block **pl);
struct b_cset   *alccset_0      (word n);
struct b_cset   *alccset_1      (word n);
union block     *alchash_0      (int tcode);
union block     *alchash_1      (int tcode);
struct b_slots  *alcsegment_0   (word nslots);
struct b_slots  *alcsegment_1   (word nslots);
struct b_list   *alclist_raw_0  (uword size, uword nslots);
struct b_list   *alclist_raw_1  (uword size, uword nslots);
struct b_list   *alclist_0      (uword size, uword nslots);
struct b_list   *alclist_1      (uword size, uword nslots);
struct b_lelem  *alclstb_0      (uword nslots);
struct b_lelem  *alclstb_1      (uword nslots);
struct b_real   *alcreal_0      (double val);
struct b_real   *alcreal_1      (double val);
struct b_selem  *alcselem_0     (void);
struct b_selem  *alcselem_1     (void);
char            *alcstr_0       (char   *s,word slen);
char            *alcstr_1       (char   *s,word slen);
struct b_telem  *alctelem_0     (void);
struct b_telem  *alctelem_1     (void);
struct b_tvtbl  *alctvtbl_0     (void);
struct b_tvtbl  *alctvtbl_1     (void);
void set_event_mask(struct progstate *p, struct b_cset *cs);
int             anycmp          (dptr dp1,dptr dp2);
int             bfunc           (void);
struct b_proc *string_to_proc(dptr s, int arity, struct progstate *prog);

void            c_exit          (int i);

int             list_get        (dptr l, dptr res);
int             list_pull       (dptr l, dptr res);
void            list_put        (dptr l, dptr val);
void            list_push       (dptr l, dptr val);
void            list_insert     (dptr l, word pos, dptr val);
void            list_del        (dptr l, word pos);

int             set_del         (dptr s, dptr key);
int             table_del       (dptr t, dptr key);
void            table_insert    (dptr t, dptr key, dptr val);
void            set_insert      (dptr s, dptr entry);

void            list_clear       (dptr l);
void            set_clear        (dptr s);
void            table_clear      (dptr t);

int             cnv_c_dbl       (dptr s, double *d);
int             cnv_c_int       (dptr s, word *d);
int             cnv_c_str       (dptr s, dptr d);
int             cnv_cset_0      (dptr s, dptr d);
int             cnv_cset_1      (dptr s, dptr d);
int             cnv_ucs_0       (dptr s, dptr d);
int             cnv_ucs_1       (dptr s, dptr d);
int             cnv_str_or_ucs  (dptr s, dptr d);
int             cnv_ec_int      (dptr s, word *d);
int             cnv_eint        (dptr s, dptr d);
int             cnv_int_0       (dptr s, dptr d);
int             cnv_int_1       (dptr s, dptr d);
int             cnv_real_0      (dptr s, dptr d);
int             cnv_real_1      (dptr s, dptr d);
int             cnv_str_0       (dptr s, dptr d);
int             cnv_str_1       (dptr s, dptr d);
void            cplist_0        (dptr dp1,dptr dp2,word i,word j);
void            cplist_1        (dptr dp1,dptr dp2,word i,word j);
void            cpset_0         (dptr dp1,dptr dp2,word size);
void            cpset_1         (dptr dp1,dptr dp2,word size);
void            cptable_0       (dptr dp1,dptr dp2,word size);
void            cptable_1       (dptr dp1,dptr dp2,word size);
void            cpslots         (dptr dp1,dptr slotptr,word i, word j);
int             csetcmp         (unsigned int *cs1,unsigned int *cs2);
word            cvpos           (word pos,word len);
void            dealcblk_0      (union block *bp);
void            dealcblk_1      (union block *bp);
void            dealcstr_0      (char *p);
void            dealcstr_1      (char *p);
int             def_c_dbl       (dptr s, double df, double * d);
int             def_c_int       (dptr s, word df, word * d);
int             def_c_str       (dptr s, char * df, dptr d);
int             def_cset        (dptr s, struct b_cset * df, dptr d);
int             def_ucs         (dptr s, struct b_ucs * df, dptr d);
int             def_ec_int      (dptr s, word df, word * d);
int             def_eint        (dptr s, word df, dptr d);
int             def_int         (dptr s, word df, dptr d);
int             def_real        (dptr s, double df, dptr d);
int             def_str         (dptr s, dptr df, dptr d);
word            div3            (word a,word b);
int             doasgn          (dptr dp1,dptr dp2);
int             doimage         (int c,int q);
int             equiv           (dptr dp1,dptr dp2);
void            err_msg         (int n, dptr v);
void            activate_handler(void);
void            fatalerr        (int n,dptr v);
void            ffatalerr       (char *fmt, ...);
struct ipc_fname *find_ipc_fname(word *ipc, struct progstate *p);
void abbr_fname(dptr s, dptr d);
struct ipc_line *find_ipc_line(word *ipc, struct progstate *p);
void            fpetrap         (int);
int             getvar          (dptr s,dptr vp,struct progstate *p);
uword           hash            (dptr dp);
union block     **hchain        (union block *pb,uword hn);
union block     *hgfirst        (union block *bp, struct hgstate *state);
union block     *hgnext         (union block*b,struct hgstate*s,union block *e);
union block     *hmake          (int tcode,word nslots,word nelem);
int             idelay          (int n);
int             lexcmp          (dptr dp1,dptr dp2);
union block     **memb          (union block *pb,dptr x,uword hn, int *res);
void            mksubs          (dptr var,dptr val,word i,word j, dptr result);
word            mod3            (word a,word b);
word            mul             (word a,word b);
word            neg             (word a);
void            outimage        (FILE *f,dptr dp,int noimage);
longlong        physicalmemorysize(void);
word            prescan         (dptr d);
int             putstr          (FILE *f,dptr d);
int             putn            (FILE *f, char *s, int n);
int             radix           (int sign, register int r, register char *s,
                                   register char *end_s, union numeric *result);
char            *reserve_0      (int region, word nbytes);
char            *reserve_1      (int region, word nbytes);
void            retderef        (dptr valp, struct frame_vars *dynamics);
word            sub             (word a,word b);
void            syserr          (char *fmt, ...);

void    resolve                 (struct progstate *pstate);
void showcurrstack(void);
void showstack(FILE *f, struct b_coexpr *c);
void showbig(FILE *f, struct b_bignum *x);

void print_desc(FILE *f, dptr d);
void print_vword(FILE *f, dptr d);
void print_dword(FILE *f, dptr d);


struct b_bignum *alcbignum_0    (word n);
struct b_bignum *alcbignum_1    (word n);
word   bigradix(int sign, int r, dptr sd,
                   union numeric *result);
int   bigtoreal       (dptr da, double *d);
int   realtobig       (dptr da, dptr dx);
void  bigtos          (dptr da, dptr dx);
void  bigprint        (FILE *f, dptr da);
void  cpbignum        (dptr da, dptr db);
void  bigadd          (dptr da, dptr db, dptr dx);
void  bigsub          (dptr da, dptr db, dptr dx);
void  bigmul          (dptr da, dptr db, dptr dx);
void  bigdiv          (dptr da, dptr db, dptr dx);
void  bigmod          (dptr da, dptr db, dptr dx);
void  bigneg          (dptr da, dptr dx);
int   bigpow          (dptr da, dptr db, dptr dx);
int   bigpowri        (double a, dptr db, dptr drslt);
void  bigand          (dptr da, dptr db, dptr dx);
void  bigor           (dptr da, dptr db, dptr dx);
void  bigxor          (dptr da, dptr db, dptr dx);
void  bigshift        (dptr da, word n, dptr dx);
int   bigcmp          (dptr da, dptr db);
void  bigrand         (dptr da, dptr dx);
int   bigsign         (dptr da);

char *buffstr(dptr d);
void buffnstr(dptr d, char **s, ...);


#if Graphics
   /*
    * portable graphics routines in rwindow.r and rwinrsc.r
    */

   wbp  alcwbinding    (void);
   wbp  findwbp        (wsp ws);
   int  docircle        (wbp w, dptr argv, int fill);
   void drawCurve       (wbp w, XPoint *p, int n);
   void genCurve        (wbp w, XPoint *p, int n, void (*h)(wbp, XPoint [], int));
   struct palentry *palsetup(int p);
   int  parsepalette    (char *s, int *p);
   int  parsefilter     (wbp w, char *s, struct filter *res);
   int  parsecolor      (char *s, int *r, int *g, int *b);
   int  parsefont       (char *s, char *fam, int *sty, int *sz);
   int  parsepattern    (char *s, int *w, int *height, int **data);
   int  parseinputmask  (char *s, int *res);
   void qevent          (wsp ws, dptr e, int x, int y, uword t, int mod);
   void qeventcode      (wsp, int);
   void qmouseevents    (wsp ws, int state, int x, int y, uword t, int mod);
   void wgetevent       (wbp w, dptr res);
   int  readimagefile   (char *filename, struct imgdata *imd);
   int  writeimagefile  (wbp w, char *filename, int x, int y, int width, int height);
   int rectargs(wbp w, dptr argv, word *px, word *py, word *pw, word *ph);
   int pointargs(wbp w, dptr argv, word *px, word *py);
   char *rgbkey         (int p, int r, int g, int b);

   int  initimgmem      (wbp w, struct imgmem *i, int copy, int clip, int x, int y, int width, int height);
   int  gotopixel       (struct imgmem *i, int x, int y);
   void drawimgdata     (wbp w, int x, int y, struct imgdata *img);
   void freeimgdata     (struct imgdata *img);
   void nextimgdata     (struct imgdata *imd, unsigned char **s, int *r, int *g, int *b, int *a);
   int  getdefaultfontsize(int);
   char *getdefaultfont(void);
   int interpimage(wbp w, dptr d,  struct imgdata *imd);

   int is_png(dptr data);
   int is_jpeg(dptr data);
   int is_gif(dptr data);

   

   /*
    * graphics implementation routines supplied for each platform
    * (excluding those defined as macros for X-windows)
    */
   void loadimgmem       (wbp w, struct imgmem *imem, int copy);
   void getpixel        (struct imgmem *imem, int *r, int *g, int *b);
   void setpixel        (struct imgmem *imem, int r, int g, int b);
   void saveimgmem       (wbp w, struct imgmem *imem);
   void freeimgmem       (struct imgmem *imem);
   int  setpattern      (wbp w, char *name);
   wcp  clonecontext   (wbp w);
   void copyarea        (wbp w,wbp w2,int x,int y,int wd,int h,int x2,int y2);
   void doconfig        (wbp w, int status);
   void erasearea       (wbp w, int x, int y, int width, int height);
   void fillrectangle   (wbp w, int x, int y, int width, int height);
   void freewbinding    (wbp w);
   void freecontext     (wcp wc);
   void freewindow      (wsp ws);
   char *getbg          (wbp w);
   char *getcanvas      (wbp w);
   char *getdisplay     (wbp w);
   char *getdrawop      (wbp w);
   char *getfillstyle   (wbp w);
   char *getfg          (wbp w);
   char *getpattern     (wbp w);
   int  getlinewidth    (wbp w);
   int  getdepth        (wbp w, int *res);
   char *getwindowlabel (wbp w);
   char *getlinestyle   (wbp w);
   char *getpointer     (wbp w);
   int  getpos          (wbp w);
   int  lowerwindow     (wbp w);
   void pollevent       (void);
   int  querypointer    (wbp w, int *x, int *y);
   int  queryrootpointer(wbp w, int *x, int *y);
   int  getdisplaysize  (wbp w, int *width, int *height);
   int  raisewindow     (wbp w);
   int  rebind          (wbp w, wbp w2);
   int  setbg           (wbp w, char *s);
   int  setcanvas       (wbp w, char *s);
   int  setdrawop       (wbp w, char *val);
   int  setfg           (wbp w, char *s);
   int  setfillstyle    (wbp w, char *s);
   int  setfont         (wbp w, char *s);
   int  setlinestyle    (wbp w, char *s);
   int  setlinewidth    (wbp w, int linewid);
   int  setpointer      (wbp w, char *val);
   int  ownselection    (wbp w, char *selection);
   int  requestselection(wbp w, char *selection, char *targetname);
   int  sendselectionresponse(wbp w, word requestor, char *property, char *selection, char *target, word time, dptr data);
   int  setwindowicon   (wbp w, struct imgdata *imd);
   int  setwindowlabel  (wbp w, char *val);
   int  walert          (wbp w, int volume);
   int  warppointer     (wbp w, int x, int y);
   void wclose          (wbp w);
   wbp  wcreate         (char *display);
   int  wopen           (wbp w);
   int  grabpointer      (wbp w);
   int  ungrabpointer    (wbp w);
   void wflush          (wbp w);
   void wsync           (wbp w);
   void xdis            (wbp w, char *s, int n);
   void fillarc         (wbp w, int x, int y, int width, int height, double angle1, double angle2);
   void drawarc         (wbp w, int x, int y, int width, int height, double angle1, double angle2);
   void drawlines       (wbp w, XPoint *points, int npoints);
   void drawpoint       (wbp w, int x, int y);
   void drawrectangle   (wbp w, int x, int y, int width, int height);
   void fillpolygon     (wbp w, XPoint *pts, int npts);
   void drawstring      (wbp w, int x, int y, char *str, int slen);
   void drawutf8        (wbp w, int x, int y, char *str, int slen, int nchars);
   int  textwidth       (wbp w, char *s, int n);
   int  utf8width       (wbp w, char *s, int n, int nchars);
   int  readimagefileimpl(char *filename, struct imgdata *imd);
   int  writeimagefileimpl(wbp w, char *filename, int x, int y, int width, int height);
   int  readimagedataimpl(dptr data, struct imgdata *imd);
   int  settransientfor(wbp w, wbp other);

#endif                                  /* Graphics */

#ifdef MSWIN32
LRESULT_CALLBACK WndProc  (HWND, UINT, WPARAM, LPARAM);
void wfreersc(void);
#endif

/*
 * Prototypes for the run-time system.
 */

struct b_record *alcrecd_0      (struct b_constructor *con);
struct b_record *alcrecd_1      (struct b_constructor *con);
struct b_object *alcobject_0    (struct b_class *class);
struct b_object *alcobject_1    (struct b_class *class);
struct b_cast   *alccast_0      (void);
struct b_cast   *alccast_1      (void);
struct b_methp  *alcmethp_0     (void);
struct b_methp  *alcmethp_1     (void);
struct b_ucs    *alcucs_0     (int n);
struct b_ucs    *alcucs_1     (int n);
struct b_tvsubs *alcsubs_0      (void);
struct b_tvsubs *alcsubs_1      (void);
int     check_access(struct class_field *cf, struct b_class *instance_class);
dptr    lookup_global(dptr name, struct progstate *prog);
dptr    lookup_named_global(dptr name, struct progstate *prog);
int     lookup_class_field(struct b_class *class, dptr query, struct inline_field_cache *ic);
int     lookup_class_field_by_name(struct b_class *class, dptr name);
int     lookup_class_field_by_fnum(struct b_class *class, int fnum);
int     lookup_record_field(struct b_constructor *recdef, dptr query, struct inline_field_cache *ic);
int     lookup_record_field_by_name(struct b_constructor *recdef, dptr name);
int     lookup_record_field_by_fnum(struct b_constructor *recdef, int fnum);
struct loc *lookup_global_loc(dptr name, struct progstate *prog);

long    ckadd           (long i, long j);
long    ckmul           (long i, long j);
long    cksub           (long i, long j);
void    cmd_line        (int argc, char **argv, dptr rslt);
void    collect         (int region);
int     cvcset          (dptr dp,int * *cs,int *csbuf);
int     cvnum           (dptr dp,union numeric *result);
int     cvreal          (dptr dp,double *r);
void    deref_0         (dptr dp1, dptr dp2);
void    deref_1         (dptr dp1, dptr dp2);
void    envset          (void);
int     eq              (dptr dp1,dptr dp2);
int     get_name        (dptr dp1, dptr dp2);
int     getch           (void);
int     getche          (void);
void    getimage        (dptr dp1, dptr dp2);

void    hgrow           (union block *bp);
void    hshrink         (union block *bp);
word iipow         (word n1, word n2);
void    init            (char *name, int *argcp, char *argv[], int trc_init);
int     kbhit           (void);
int     order           (dptr dp);


struct progstate *alcprog(long icodesize);

struct sockaddr *parse_sockaddr(char *s, int *size);
int get_proc_kind(struct b_proc *bp);

void call_trace(struct p_frame *pf);
void fail_trace(struct p_frame *pf);
void suspend_trace(struct p_frame *pf, dptr val);
void return_trace(struct p_frame *pf, dptr val);

void trace_coact(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_coret(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_cofail(struct b_coexpr *from, struct b_coexpr *to);
void trace_cofail_to_handler(struct b_coexpr *from, struct b_coexpr *to);

void xdisp(struct b_coexpr *ce, int count, FILE *f);

void create_list(uword nslots, dptr d);
struct b_lelem *get_lelem_for_index(struct b_list *bp, word i, word *pos);
struct b_lelem *lgfirst(struct b_list *lb, struct lgstate *state);
struct b_lelem *lgnext(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
struct b_lelem *lglast(struct b_list *lb, struct lgstate *state);
struct b_lelem *lgprev(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
void cstr2string(char *s, dptr d);
void bytes2string(char *s, word len, dptr d);
void cstrs2string(char **s, char *delim, dptr d);
int eq(dptr d1, dptr d2);
int ceq(dptr dp, char *s);

int stringint_str2int(stringint * sip, char *s);
char *stringint_int2str(stringint * sip, int i);
stringint *stringint_lookup(stringint *sip, char *s);
char *lookup_err_msg(int n);
void errno2why(void);
dptr c_get_instance_data(dptr x, dptr fname, struct inline_field_cache *ic);
int c_is(dptr x, dptr cname, struct inline_global_cache *ic);
void why(char *s);
void whyf(char *fmt, ...);
char *salloc(char *s);
int class_is(struct b_class *class1, struct b_class *class2);
struct b_cset *rangeset_to_block(struct rangeset *rs);
struct b_ucs *make_ucs_block(dptr utf8, word length);
struct b_ucs *make_one_char_ucs_block(int i);
void utf8_substr(struct b_ucs *b, word pos, word len, dptr res);
int ucs_char(struct b_ucs *b, word pos);
int in_cset(struct b_cset *b, int c);
char *ucs_utf8_ptr(struct b_ucs *b, word pos);
struct b_ucs *cset_to_ucs_block(struct b_cset *b0, word pos, word len);
void cset_to_string(struct b_cset *b, word pos, word len, dptr res);
struct b_ucs *make_ucs_substring(struct b_ucs *b, word pos, word len);
int cset_range_of_pos(struct b_cset *b, word pos);
int need_ucs(dptr s);
long millisec(void);

/* Debug func. */
void show_regions(void);

struct p_frame *alc_p_frame(struct p_proc *pb, struct frame_vars *dynamics);
struct c_frame *alc_c_frame(struct c_proc *pb, int nargs);
void dyn_free(void *p);
void free_frame(struct frame *f);

void push_frame(struct frame *f);
void push_p_frame(struct p_frame *f);
void interp(void);
dptr get_dptr(void);
void get_deref(dptr dest);
void get_variable(dptr dest);
void skip_descrip(void);
void pop_to(struct frame *f);
void do_apply(void);
void do_invoke(void);
void do_applyf(void);
void do_invokef(void);
word get_offset(word *w);
void do_ensure_class_init(void);
void tail_invoke_frame(struct frame *f);
dptr get_element(dptr d, word i);
void do_field(void);
struct inline_field_cache *get_inline_field_cache(void);
void traceback(struct b_coexpr *ce, int with_xtrace, int act_chain);
struct ipc_line *frame_ipc_line(struct p_frame *pf);
struct ipc_fname *frame_ipc_fname(struct p_frame *pf);
struct p_proc *get_current_user_proc(void);
struct p_frame *get_current_user_frame(void);
struct p_frame *get_current_user_frame_of(struct b_coexpr *ce);
struct progstate *get_current_program_of(struct b_coexpr *ce);
void switch_to(struct b_coexpr *ce);
void add_to_prog_event_queue(dptr value, int event);
void general_call_0(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
void general_call_1(word clo, dptr lhs, dptr expr, int argc, dptr args, word rval, word *failure_label);
void general_access_0(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                      word *failure_label);
void general_access_1(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                      word *failure_label);

void general_invokef_0(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                       int argc, dptr args, word rval, word *failure_label);
void general_invokef_1(word clo, dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                       int argc, dptr args, word rval, word *failure_label);
void test_collect(int time_interval, long call_interval, int quiet);
struct b_coexpr *alccoexp_0 (void);
struct b_coexpr *alccoexp_1 (void);
struct b_proc *clone_b_proc(struct b_proc *bp);

void set_curpstate(struct progstate *p);
void set_curr_pf(struct p_frame *x);
void synch_ipc(void);
