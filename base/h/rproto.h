/*
 * Prototypes for run-time functions.
 */

/*
 * Prototypes common to the compiler and interpreter.
 */
void            EVInit          (void);
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
void            table_insert    (dptr t, dptr key, dptr val, int overwrite);
void            set_insert      (dptr s, dptr entry);

void            list_clear       (dptr l);
void            set_clear        (dptr s);
void            table_clear      (dptr t);

int             cnv_c_dbl       (dptr s, double *d);
int             cnv_c_int       (dptr s, word *d);
int             cnv_c_str       (dptr s, dptr d);
int             cnv_cset        (dptr s, dptr d);
int             cnv_ucs         (dptr s, dptr d);
int             cnv_str_or_ucs  (dptr s, dptr d);
int             cnv_ec_int      (dptr s, word *d);
int             cnv_eint        (dptr s, dptr d);
int             cnv_int         (dptr s, dptr d);
int             cnv_real        (dptr s, dptr d);
int             cnv_str         (dptr s, dptr d);

void            cplist          (dptr dp1,dptr dp2,word i,word size);
void            cpset           (dptr dp1,dptr dp2,word size);
void            cptable         (dptr dp1,dptr dp2,word size);
void            cpslots         (dptr dp1, dptr slotptr, word i, word size);
word            cvpos           (word pos, word len);
word            cvpos_item      (word pos, word len);
int             cvslice         (word *i, word *j, word len);
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
int             doasgn          (dptr dp1,dptr dp2);
int             doimage         (int c,int q);
int             equiv           (dptr dp1,dptr dp2);
void            err_msg         (int n, dptr v);
void            activate_handler(void);
void            push_fatalerr_139_frame(void);
void            fatalerr        (int n,dptr v);
void            ffatalerr       (char *fmt, ...);
void            checkfatalrecurse(void);
struct ipc_fname *find_ipc_fname(word *ipc, struct progstate *p);
void abbr_fname(dptr s, dptr d);
void begin_link(FILE *f, dptr fname, word line);
void end_link(FILE *f);
struct ipc_line *find_ipc_line(word *ipc, struct progstate *p);
int             getvar          (dptr s,dptr vp,struct progstate *p);
uword           hash            (dptr dp);
union block     **hchain        (union block *pb,uword hn);
union block     *hgfirst        (union block *bp, struct hgstate *state);
union block     *hgnext         (union block*b,struct hgstate*s,union block *e);
union block     *hmake          (int tcode,word nslots,word nelem);
int             lexcmp          (dptr dp1,dptr dp2);
int             caseless_lexcmp       (dptr dp1, dptr dp2);
int             consistent_lexcmp       (dptr dp1, dptr dp2);
union block     **memb          (union block *pb,dptr x,uword hn, int *res);
void            mksubs          (dptr var,dptr val,word i,word j, dptr result);
void            outimage        (FILE *f,dptr dp,int noimage);
void            outimage1       (FILE *f, dptr dp, int noimage, word stringlimit, word listlimit);
uint64_t        physicalmemorysize(void);
word            prescan         (dptr d);
int             putstr          (FILE *f,dptr d);
int             putn            (FILE *f, char *s, size_t n);
char            *reserve_0      (int region, uword nbytes);
char            *reserve_1      (int region, uword nbytes);
void            retderef        (dptr valp, struct frame_vars *dynamics);
void            syserr          (char *fmt, ...);

void showcurrstack(void);
void showstack(FILE *f, struct b_coexpr *c);
void showbig(FILE *f, struct b_bignum *x);
struct progstate *find_global(dptr s);
struct progstate *find_class_static(dptr s);
struct progstate *find_procedure_static(dptr s);
struct class_field *find_class_field_for_dptr(dptr d, struct progstate *prog);

void print_desc(FILE *f, dptr d);
void print_vword(FILE *f, dptr d);
void print_dword(FILE *f, dptr d);


struct b_bignum *alcbignum_0    (word n);
struct b_bignum *alcbignum_1    (word n);
int   bigradix(int sign, int r, dptr sd, dptr result);
int   bigtoreal       (dptr da, double *d);
int   realtobig       (double x, dptr dx);
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

#define declare_convert_from_macro(TYPE) void convert_from_##TYPE(TYPE src, dptr dest);
#define declare_convert_to_macro(TYPE) int convert_to_##TYPE(dptr src, TYPE *dest);

declare_convert_to_macro(off_t)
declare_convert_from_macro(off_t)
declare_convert_to_macro(time_t)
declare_convert_from_macro(time_t)
declare_convert_to_macro(mode_t)
declare_convert_from_macro(mode_t)
declare_convert_from_macro(dev_t)
#if UNIX
declare_convert_from_macro(ino_t)
declare_convert_from_macro(blkcnt_t)
declare_convert_to_macro(uid_t)
declare_convert_from_macro(uid_t)
declare_convert_to_macro(gid_t)
declare_convert_from_macro(gid_t)
declare_convert_to_macro(pid_t)
declare_convert_from_macro(pid_t)
#endif
declare_convert_from_macro(uint64_t)
declare_convert_from_macro(uword)

char *buffstr(dptr d);
void buffnstr(dptr d, char **s, ...);


int  parsecolor      (char *s, int *r, int *g, int *b, int *a);
int  parseopaquecolor(char *s, int *r, int *g, int *b);
int  parsepalette    (char *s, int *p);
struct palentry *palsetup(int p);
char *rgbkey         (int p, int r, int g, int b);
char *tocolorstring(int r, int g, int b, int a);

int pixels_rectargs(struct imgdata *img, dptr argv, word *px, word *py, word *pw, word *ph);
int pixels_reducerect(struct imgdata *img, word *x, word *y, word *width, word *height);

struct imgdataformat *parseimgdataformat(char *s);
void registerimgdataformat(struct imgdataformat *fmt);
int getlength_1(struct imgdata *imd);
int getlength_2(struct imgdata *imd);
int getlength_4(struct imgdata *imd);
int getlength_8(struct imgdata *imd);
int getlength_16(struct imgdata *imd);
int getlength_24(struct imgdata *imd);
int getlength_32(struct imgdata *imd);
int getlength_48(struct imgdata *imd);
int getlength_64(struct imgdata *imd);

struct imgdata *newimgdata(void);
struct imgdata *initimgdata(int width, int height, struct imgdataformat *fmt);
struct imgdata *linkimgdata(struct imgdata *imd);
void unlinkimgdata(struct imgdata *imd);
void copyimgdata(struct imgdata *dest, struct imgdata *src);

#if Graphics
   /*
    * portable graphics routines in rwindow.r and rwinrsc.r
    */

   wsp  linkwindow      (wsp ws);
   wcp  linkcontext     (wcp wc);
   wbp  clonewindow     (wbp w);
   wbp  couplewindows   (wbp w1, wbp w2);
   void freewbinding(wbp w);
   void drawcurve       (wbp w, struct point *p, int n);
   int  parsefilter     (wbp w, char *s, struct filter *res);
   int  parsefont       (char *s, char *fam, int *sty, double *sz);
   void qevent          (wsp ws, dptr e, int x, int y, word t, int mod);
   void qeventcode      (wsp, int);
   void qmouseevents    (wsp ws, int state, int x, int y, word t, int mod);
   void wgetevent       (wbp w, dptr res);
   int  readimagefile   (char *filename, struct imgdata *imd);
   int  writeimagefile  (char *filename, struct imgdata *imd);
   int rectargs(wbp w, dptr argv, word *px, word *py, word *pw, word *ph);
   int pointargs_def(wbp w, dptr argv, word *px, word *py);
   int pointargs(wbp w, dptr argv, word *px, word *py);
   int dpointargs(wbp w, dptr argv, double *px, double *py);
   int interpimage(dptr d,  struct imgdata *imd);
   int reducerect(wbp w, int clip, word *x, word *y, word *width, word *height);
   void captureimgdata(wbp w, int x, int y, struct imgdata *imd);
   void drawimgdata(wbp w, int x, int y, struct imgdata *imd, int copy);
   struct imgdataformat *getimgdataformat(wbp w);
   int is_png(dptr data);
   int is_jpeg(dptr data);
   int is_gif(dptr data);
   int  copyarea        (wbp w, int x, int y, int wd, int h, wbp w2, int x2, int y2, wbp w3, int x3, int y3);
   void doconfig        (wbp w, int status);
   void erasearea       (wbp w, int x, int y, int width, int height);
   void fillrectangle   (wbp w, int x, int y, int width, int height);
   char *getbg          (wbp w);
   char *getcanvas      (wbp w);
   char *getdisplay     (wbp w);
   char *getdrawop      (wbp w);
   char *getfg          (wbp w);
   double getlinewidth    (wbp w);
   int  getdepth        (wbp w, int *res);
   char *getlinestyle   (wbp w);
   char *getpointer     (wbp w);
   int  lowerwindow     (wbp w);
   void pollevent       (wbp w);
   void restore         (wbp w, int x, int y, int width, int height);
   int  querypointer    (wbp w, int *x, int *y);
   int  queryrootpointer(wbp w, int *x, int *y);
   int  getdisplaysize  (wbp w, int *width, int *height);
   int  getdisplaysizemm(wbp w, int *width, int *height);
   int  raisewindow     (wbp w);
   int  focuswindow     (wbp w);
   int  setbg           (wbp w, char *s);
   int  setcanvas       (wbp w, char *s);
   int  setdrawop       (wbp w, char *val);
   int  setfg           (wbp w, char *s);
   int  setfont         (wbp w, char *s);
   int  setlinestyle    (wbp w, char *s);
   int  setlinewidth    (wbp w, double linewid);
   int  setpointer      (wbp w, char *val);
   int  ownselection    (wbp w, char *selection);
   int  requestselection(wbp w, char *selection, char *targetname);
   int  sendselectionresponse(wbp w, word requestor, char *property, char *selection, char *target, word time, dptr data);
   int  setwindowicon   (wbp w, struct imgdata *imd);
   int  setpattern  (wbp w, struct imgdata *imd);
   int  setwindowlabel  (wbp w, dptr val);
   int  walert          (wbp w, int volume);
   int  warppointer     (wbp w, int x, int y);
   wbp  wopen           (char *display);
   int  grabpointer      (wbp w);
   int  ungrabpointer    (wbp w);
   int  grabkeyboard      (wbp w);
   int  ungrabkeyboard    (wbp w);
   void fillarc(wbp w, double cx, double cy, double rx, double ry, double angle1, double angle2);
   void drawarc(wbp w, double cx, double cy, double rx, double ry, double angle1, double angle2);
   void drawlines       (wbp w, struct point *points, int npoints);
   void drawrectangle   (wbp w, int x, int y, int width, int height, int thick);
   void fillpolygon     (wbp w, struct point *pts, int npts);
   void filltrapezoids  (wbp w, struct trapezoid *traps, int ntraps);
   void filltriangles   (wbp w, struct triangle *tris, int ntris);
   void drawstring      (wbp w, int x, int y, dptr str);
   int  textwidth       (wbp w, dptr str);
   int  readimagefileimpl(char *filename, struct imgdata *imd);
   int  writeimagefileimpl(char *filename, struct imgdata *imd);
   int  readimagedataimpl(dptr data, struct imgdata *imd);
   int  settransientfor(wbp w, wbp other);
   void registerplatformimgdataformats(void);
   int definepointer(wbp w, char *name, struct imgdata *imd, int x, int y);
   int copypointer(wbp w, char *dest, char *src);

#if XWindows
   struct SharedColor *new_sharedcolor(wdp wd, char *name, int r, int g, int b, int a);
   struct SharedColor *link_sharedcolor(struct SharedColor *x);
   void unlink_sharedcolor(struct SharedColor *x);
   struct SharedPicture *new_sharedpicture(wdp wd, struct imgdata *imd);
   struct SharedPicture *link_sharedpicture(struct SharedPicture *x);
   void unlink_sharedpicture(struct SharedPicture *x);
   wfp loadfont(wdp wd, char *s);
   char *tofcpatternstr(char *s);
   Pixmap imgdata_to_Pixmap(wdp wd, struct imgdata *imd);
   wbp alcwbinding(wdp wd);
   wbp findwbp(wsp ws);
#endif

void points_extent(struct point *points, int npoints, int *x, int *y, int *width, int *height);
void trapezoids_extent(struct trapezoid *traps, int ntraps, int *x, int *y, int *width, int *height);
void triangles_extent(struct triangle *tris, int ntris, int *x, int *y, int *width, int *height);
void range_extent(double x1, double y1, double x2, double y2, int *x, int *y, int *width, int *height);
int is_hidden(wbp w);

#endif                                  /* Graphics */


#if MSWIN32
LRESULT_CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
WCHAR *ucs_to_wchar(dptr str, int nullterm, word *len);
void wchar_to_utf8_string(WCHAR *src, dptr res);
void wchar_to_ucs(WCHAR *src, dptr res);
WCHAR *string_to_wchar(dptr str, int nullterm, word *len);
void win32error2why(void);
#endif

/*
 * Prototypes for the run-time system.
 */

struct b_record *alcrecd_0      (struct b_constructor *con);
struct b_record *alcrecd_1      (struct b_constructor *con);
struct b_object *alcobject_0    (struct b_class *class);
struct b_object *alcobject_1    (struct b_class *class);
struct b_methp  *alcmethp_0     (void);
struct b_methp  *alcmethp_1     (void);
struct b_ucs    *alcucs_0     (int n);
struct b_ucs    *alcucs_1     (int n);
struct b_tvsubs *alcsubs_0      (void);
struct b_tvsubs *alcsubs_1      (void);
struct b_weakref  *alcweakref_0     (void);
struct b_weakref  *alcweakref_1     (void);
int     check_access(struct class_field *cf, struct b_class *instance_class);
int     check_access_ic(struct class_field *cf, struct b_class *instance_class, struct inline_field_cache *ic);
int     lookup_global_index(dptr name, struct progstate *prog);
int     lookup_global(dptr query, struct progstate *prog);
dptr    lookup_named_global(dptr name, int incl, struct progstate *prog);
int     lookup_class_field(struct b_class *class, dptr query, struct inline_field_cache *ic);
int     lookup_class_field_by_name(struct b_class *class, dptr name);
int     lookup_class_field_by_fnum(struct b_class *class, int fnum);
int     lookup_record_field(struct b_constructor *recdef, dptr query, struct inline_field_cache *ic);
int     lookup_record_field_by_name(struct b_constructor *recdef, dptr name);
int     lookup_record_field_by_fnum(struct b_constructor *recdef, int fnum);
struct loc *lookup_global_loc(dptr name, struct progstate *prog);

void    collect         (int region);
void    deref_0         (dptr dp1, dptr dp2);
void    deref_1         (dptr dp1, dptr dp2);
int     eq              (dptr dp1,dptr dp2);
int     getname        (dptr dp1, dptr dp2);
void    getimage        (dptr dp1, dptr dp2);
void    print_location  (FILE *f, struct p_frame *pf);

void    hgrow           (union block *bp);
void    hshrink         (union block *bp);
int     order           (dptr dp);

void dptr_list_add(struct dptr_list **head, dptr d);
void dptr_list_rm(struct dptr_list **head, dptr d);
void add_gc_global(dptr d);
void del_gc_global(dptr d);


struct progstate *alcprog(word base, word icodesize);

int get_proc_kind(struct b_proc *bp);

void call_trace(struct p_frame *pf);
void fail_trace(struct p_frame *pf);
void suspend_trace(struct p_frame *pf, dptr val);
void return_trace(struct p_frame *pf, dptr val);

void c_call_trace(struct c_frame *cf);
void c_fail_trace(struct c_frame *cf);
void c_return_trace(struct c_frame *cf);


void trace_coact(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_coret(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_cofail(struct b_coexpr *from, struct b_coexpr *to);
void trace_cofail_to_handler(struct b_coexpr *from, struct b_coexpr *to);

void xdisp(struct b_coexpr *ce, int count, FILE *f);

void create_list(word nslots, dptr d);
void create_table(word nslots, word nelem, dptr d);
void create_set(word nslots, word nelem, dptr d);
struct b_lelem *get_lelem_for_index(struct b_list *bp, word i, word *pos);
struct b_lelem *lginit(struct b_list *lb, word i, struct lgstate *state);
struct b_lelem *lgfirst(struct b_list *lb, struct lgstate *state);
struct b_lelem *lgnext(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
struct b_lelem *lglast(struct b_list *lb, struct lgstate *state);
struct b_lelem *lgprev(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
void cstr2string(char *s, dptr d);
void bytes2string(char *s, word len, dptr d);
void cstrs2string(char **s, char *delim, dptr d);
int eq(dptr d1, dptr d2);
int ceq(dptr dp, char *s);
void env_int(char *name, int *variable, int min, int max);
void env_word(char *name, word *variable, word min, word max);
void env_uword(char *name, uword *variable, uword min, uword max);
void env_double(char *name, double *variable, double min, double max);
void env_string(char *name, char **variable);

int stringint_str2int(stringint * sip, char *s);
char *stringint_int2str(stringint * sip, int i);
stringint *stringint_lookup(stringint *sip, char *s);
char *lookup_err_msg(int n);
void set_errno(int n);
void errno2why(void);
dptr c_get_instance_data(dptr x, dptr fname, struct inline_field_cache *ic);
int c_is(dptr x, dptr cname, struct inline_global_cache *ic);
void why(char *s);
void whyf(char *fmt, ...);
int class_is(struct b_class *class1, struct b_class *class2);
int mem_eq(char *s1, char *s2, word n);
int str_mem_eq(dptr s, char *t);
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
struct descrip block_to_descriptor(union block *ptr);

struct b_class *get_class_for(dptr x);
struct b_constructor *get_constructor_for(dptr x);
struct b_proc *get_proc_for(dptr x);
struct progstate *get_program_for(dptr x);
struct b_coexpr *get_coexpr_for(dptr x);

/* Debug func. */
void show_regions(void);

struct p_frame *alc_p_frame(struct p_proc *pb, struct frame_vars *dynamics);
struct c_frame *alc_c_frame(struct c_proc *pb, int nargs);
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
void fail_to(struct b_coexpr *ce);
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
int is_flag(dptr d);
int is_ascii_string(dptr d);
char *datatofile(dptr data);

void *safe_calloc(size_t m, size_t n);
void *safe_zalloc(size_t size);
void *safe_malloc(size_t size);
void *safe_realloc(void *ptr, size_t size);
void *icode_alloc(void *base, size_t size);

void do_op_cat(void);
void do_op_conj(void);
void do_op_diff(void);
void do_op_div(void);
void do_op_inter(void);
void do_op_lconcat(void);
void do_op_minus(void);
void do_op_mod(void);
void do_op_mult(void);
void do_op_plus(void);
void do_op_power(void);
void do_op_union(void);
void do_op_eqv(void);
void do_op_lexeq(void);
void do_op_lexge(void);
void do_op_lexgt(void);
void do_op_lexle(void);
void do_op_lexlt(void);
void do_op_lexne(void);
void do_op_neqv(void);
void do_op_numeq(void);
void do_op_numge(void);
void do_op_numgt(void);
void do_op_numle(void);
void do_op_numlt(void);
void do_op_numne(void);
void do_op_asgn(void);
void do_op_swap(void);
void do_op_value(void);
void do_op_size(void);
void do_op_refresh(void);
void do_op_number(void);
void do_op_compl(void);
void do_op_neg(void);
void do_op_null(void);
void do_op_nonnull(void);
void do_op_random(void);
void do_op_sect(void);
void do_op_subsc(void);
void do_op_activate(void);

#define KDef(p,n) void do_key_##p(void);
#include "../h/kdefs.h"
#undef KDef
