/*
 * Prototypes for run-time functions.
 */

/*
 * Prototypes common to the compiler and interpreter.
 */
void		EVInit		(void);
int		activate	(dptr val, struct b_coexpr *ncp, dptr result);
word		add		(word a,word b);
void		addmem 	(struct b_set *ps,struct b_selem *pe, union block **pl);
struct b_cset	*alccset_0	(word n);
struct b_cset	*alccset_1	(word n);
#ifdef Graphics
struct b_window	*alcwindow_0	(wbp w, word isopen);
struct b_window	*alcwindow_1	(wbp w, word isopen);
#endif
union block	*alchash_0	(int tcode);
union block	*alchash_1	(int tcode);
struct b_slots	*alcsegment_0	(word nslots);
struct b_slots	*alcsegment_1	(word nslots);
struct b_list	*alclist_raw_0	(uword size, uword nslots);
struct b_list	*alclist_raw_1	(uword size, uword nslots);
struct b_list	*alclist_0	(uword size, uword nslots);
struct b_list	*alclist_1	(uword size, uword nslots);
struct b_lelem	*alclstb_0	(uword nslots);
struct b_lelem	*alclstb_1	(uword nslots);
struct b_real	*alcreal_0	(double val);
struct b_real	*alcreal_1	(double val);
struct b_selem	*alcselem_0	(void);
struct b_selem	*alcselem_1	(void);
char		*alcstr_0	(char	*s,word slen);
char		*alcstr_1	(char	*s,word slen);
struct b_telem	*alctelem_0	(void);
struct b_telem	*alctelem_1	(void);
struct b_tvtbl	*alctvtbl_0	(dptr tbl,dptr ref,uword hashnum);
struct b_tvtbl	*alctvtbl_1	(dptr tbl,dptr ref,uword hashnum);
void set_event_mask(struct progstate *p, struct b_cset *cs);
int		anycmp		(dptr dp1,dptr dp2);
int		bfunc		(void);
struct b_proc *string_to_proc(dptr s, int arity, struct progstate *prog);

void		c_exit		(int i);

int		list_get	(dptr l, dptr res);
int             list_pull       (dptr l, dptr res);
void		list_put	(dptr l, dptr val);
void            list_push       (dptr l, dptr val);
void            list_insert     (dptr l, word pos, dptr val);
void            list_del        (dptr l, word pos);

int             set_del(dptr s, dptr key);
int             table_del(dptr t, dptr key);
void            table_insert(dptr t, dptr key, dptr val);
void            set_insert(dptr s, dptr entry);

int		cnv_c_dbl	(dptr s, double *d);
int		cnv_c_int	(dptr s, C_integer *d);
int		cnv_c_str	(dptr s, dptr d);
int		cnv_cset_0	(dptr s, dptr d);
int		cnv_cset_1	(dptr s, dptr d);
int		cnv_ucs_0	(dptr s, dptr d);
int		cnv_ucs_1	(dptr s, dptr d);
int		cnv_str_or_ucs	(dptr s, dptr d);
int		cnv_ec_int	(dptr s, C_integer *d);
int		cnv_eint	(dptr s, dptr d);
int		cnv_int_0	(dptr s, dptr d);
int		cnv_int_1	(dptr s, dptr d);
int		cnv_real_0	(dptr s, dptr d);
int		cnv_real_1	(dptr s, dptr d);
int		cnv_str_0	(dptr s, dptr d);
int		cnv_str_1	(dptr s, dptr d);
int		cnv_tstr_0	(char *sbuf, dptr s, dptr d);
int		cnv_tstr_1	(char *sbuf, dptr s, dptr d);
void		cplist_0	(dptr dp1,dptr dp2,word i,word j);
void		cplist_1	(dptr dp1,dptr dp2,word i,word j);
void		cpset_0		(dptr dp1,dptr dp2,word size);
void		cpset_1		(dptr dp1,dptr dp2,word size);
void		cptable_0	(dptr dp1,dptr dp2,word size);
void		cptable_1	(dptr dp1,dptr dp2,word size);
void		cpslots		(dptr dp1,dptr slotptr,word i, word j);
int		csetcmp		(unsigned int *cs1,unsigned int *cs2);
word		cvpos		(long pos,long len);
void		datainit	(void);
void		dealcblk_0	(union block *bp);
void		dealcblk_1	(union block *bp);
void            dealcstr_0      (char *p);
void            dealcstr_1      (char *p);
int		def_c_dbl	(dptr s, double df, double * d);
int		def_c_int	(dptr s, C_integer df, C_integer * d);
int		def_c_str	(dptr s, char * df, dptr d);
int		def_cset	(dptr s, struct b_cset * df, dptr d);
int		def_ucs	        (dptr s, struct b_ucs * df, dptr d);
int		def_ec_int	(dptr s, C_integer df, C_integer * d);
int		def_eint	(dptr s, C_integer df, dptr d);
int		def_int		(dptr s, C_integer df, dptr d);
int		def_real	(dptr s, double df, dptr d);
int		def_str		(dptr s, dptr df, dptr d);
int		def_tstr	(char *sbuf, dptr s, dptr df, dptr d);
word		div3		(word a,word b);
int		doasgn		(dptr dp1,dptr dp2);
int		doimage		(int c,int q);
void		drunerr		(int n, double v);
void		env_int	(char *name,word *variable,int non_neg, uword limit);
int		equiv		(dptr dp1,dptr dp2);
int		err		(void);
void		err_msg		(int n, dptr v);
void		startuperr  	(char *fmt, ...);
void		fatalerr	(int n,dptr v);
void            ffatalerr       (char *fmt, ...);
struct ipc_fname *find_ipc_fname(word *ipc, struct progstate *p);
void abbr_fname(dptr s, dptr d);
struct ipc_line *find_ipc_line(word *ipc, struct progstate *p);
dptr     	findfile	(word *ipc);
int		findline	(word *ipc);
void		fpetrap		(int);
int             getvar          (dptr s,dptr vp,struct progstate *p);
uword		hash		(dptr dp);
union block	**hchain	(union block *pb,uword hn);
union block	*hgfirst	(union block *bp, struct hgstate *state);
union block	*hgnext		(union block*b,struct hgstate*s,union block *e);
union block	*hmake		(int tcode,word nslots,word nelem);
int		idelay		(int n);
void		irunerr		(int n, C_integer v);
int		lexcmp		(dptr dp1,dptr dp2);
union block	**memb		(union block *pb,dptr x,uword hn, int *res);
void		mksubs		(dptr var,dptr val,word i,word j, dptr result);
word		mod3		(word a,word b);
word		mul		(word a,word b);
word		neg		(word a);
int		numcmp		(dptr dp1,dptr dp2,dptr dp3);
void		outimage	(FILE *f,dptr dp,int noimage);
longlong        physicalmemorysize();
word		prescan		(dptr d);
int		putstr		(FILE *f,dptr d);
int    		 radix		(int sign, register int r, register char *s,
				   register char *end_s, union numeric *result);
char		*reserve_0	(int region, word nbytes);
char		*reserve_1	(int region, word nbytes);
void		retderef	(dptr valp, struct frame_vars *dynamics);
void		stkdump		(int);
word		sub		(word a,word b);
void		syserr		(char *fmt, ...);
void		xmfree		(void);

void	resolve			(struct progstate *pstate);
void showcurrstack();
void showstack(struct b_coexpr *c);

char *cstr(struct descrip *sd);
void print_desc(FILE *f, dptr d);
void print_vword(FILE *f, dptr d);
void print_dword(FILE *f, dptr d);

   dptr	extcall			(dptr x, int nargs, int *signal);


   struct b_bignum *alcbignum_0	(word n);
   struct b_bignum *alcbignum_1	(word n);
   word		bigradix	(int sign, int r, char *s, char *x,
						   union numeric *result);
   int   	bigtoreal	(dptr da, double *d);
   int		realtobig	(dptr da, dptr dx);
   void		bigtos		(dptr da, dptr dx);
   void		bigprint	(FILE *f, dptr da);
   void		cpbignum	(dptr da, dptr db);
   void		bigadd		(dptr da, dptr db, dptr dx);
   void		bigsub		(dptr da, dptr db, dptr dx);
   void		bigmul		(dptr da, dptr db, dptr dx);
   void		bigdiv		(dptr da, dptr db, dptr dx);
   void		bigmod		(dptr da, dptr db, dptr dx);
   void		bigneg		(dptr da, dptr dx);
   int		bigpow		(dptr da, dptr db, dptr dx);
   int		bigpowri        (double a, dptr db, dptr drslt);
   void		bigand		(dptr da, dptr db, dptr dx);
   void		bigor		(dptr da, dptr db, dptr dx);
   void		bigxor		(dptr da, dptr db, dptr dx);
   void		bigshift	(dptr da, dptr db, dptr dx);
   word		bigcmp		(dptr da, dptr db);
   void		bigrand		(dptr da, dptr dx);


#ifdef Graphics
   /*
    * portable graphics routines in rwindow.r and rwinrsc.r
    */
   wcp	alc_context	(wbp w);
   wbp	alc_wbinding	(void);
   wsp	alc_winstate	(void);
   int	atobool		(char *s);
   int	docircles	(wbp w, int argc, dptr argv, int fill);
   void	drawCurve	(wbp w, XPoint *p, int n);
   void	genCurve	(wbp w, XPoint *p, int n, void (*h)(wbp, XPoint [], int));
   int	getpattern	(wbp w, char *answer);
   struct palentry *palsetup(int p);
   int	palnum		(dptr d);
   int	parsecolor	(wbp w, char *s, long *r, long *g, long *b, long *a);
   int	parsefont	(char *s, char *fam, int *sty, int *sz);
   int	parsegeometry	(char *buf, SHORT *x, SHORT *y, SHORT *w, SHORT *h);
   int	parsepattern	(char *s, int len, int *w, int *nbits, C_integer *bits);
void	qevent		(wsp ws, dptr e, int x, int y, uword t, long f, int krel);
   int	readGIF		(char *fname, int p, struct imgdata *d);
#ifdef HAVE_LIBJPEG
   int	readJPEG	(char *fname, int p, struct imgdata *d);
#endif					/* HAVE_LIBJPEG */
   int	rectargs	(wbp w, int argc, dptr argv, int i,
   			   word *px, word *py, word *pw, word *ph);
   char	*rgbkey		(int p, double r, double g, double b);

   int	setselection	(wbp w, dptr val);
   int	setsize		(wbp w, char *s);
   int	setminsize	(wbp w, char *s);
   int	wattrib		(wbp w, char *s, long len, dptr answer, char *abuf);
   int	wgetevent	(wbp w, dptr res, int t);
   int	writeGIF	(wbp w, char *filename,
   			  int x, int y, int width, int height);
   int	writeBMP	(wbp w, char *filename,
   			  int x, int y, int width, int height);
   /*
    * graphics implementation routines supplied for each platform
    * (excluding those defined as macros for X-windows)
    */
   int	SetPattern	(wbp w, char *name, int len);
   int	SetPatternBits	(wbp w, int width, C_integer *bits, int nbits);
   int	allowresize	(wbp w, int on);
   int	blimage		(wbp w, int x, int y, int wd, int h,
   			  int ch, unsigned char *s, word len);
   wcp	clone_context	(wbp w);
   int	copyArea	(wbp w,wbp w2,int x,int y,int wd,int h,int x2,int y2);
   int	do_config	(wbp w, int status);
   int	dumpimage	(wbp w, char *filename, unsigned int x, unsigned int y,
			   unsigned int width, unsigned int height);
   void	eraseArea	(wbp w, int x, int y, int width, int height);
   void	fillrectangles	(wbp w, XRectangle *recs, int nrecs);
   void	free_binding	(wbp w);
   void	free_context	(wcp wc);
   void	free_mutable	(wbp w, int mute_index);
   int	free_window	(wsp ws);
   void	freecolor	(wbp w, char *s);
   char	*get_mutable_name (wbp w, int mute_index);
   void	getbg		(wbp w, char *answer);
   void	getcanvas	(wbp w, char *s);
   int	getdefault	(wbp w, char *prog, char *opt, char *answer);
   void	getdisplay	(wbp w, char *answer);
   void	getdrawop	(wbp w, char *answer);
   void	getfg		(wbp w, char *answer);
   void	getfntnam	(wbp w, char *answer);
   void	geticonic	(wbp w, char *answer);
   int	geticonpos	(wbp w, char *s);
   int	getimstr	(wbp w, int x, int y, int width, int hgt,
   			  struct palentry *ptbl, unsigned char *data);
   void	getlinestyle	(wbp w, char *answer);
   int	getpixel_init	(wbp w, struct imgmem *imem);
   int	getpixel_term	(wbp w, struct imgmem *imem);
   int	getpixel	(wbp w,int x,int y,word *rv,char *s,struct imgmem *im);
   void	getpointername	(wbp w, char *answer);
   int	getpos		(wbp w);
   int	getvisual	(wbp w, char *answer);
   int	isetbg		(wbp w, int bg);
   int	isetfg		(wbp w, int fg);
   int	lowerWindow	(wbp w);
   int	mutable_color	(wbp w, dptr argv, int ac, int *retval);
   int	nativecolor	(wbp w, char *s, long *r, long *g, long *b);

   /* Exclude those functions defined as macros */
   void pollevent	(void);

   int	query_pointer	(wbp w, XPoint *pp);
   int	query_rootpointer (XPoint *pp);
   int	raiseWindow	(wbp w);
   int	readimage	(wbp w, char *filename, int x, int y, int *status);
   int	rebind		(wbp w, wbp w2);
   int	set_mutable	(wbp w, int i, char *s);
   int	setbg		(wbp w, char *s);
   int	setcanvas	(wbp w, char *s);
   void	setclip		(wbp w);
   int	setdisplay	(wbp w, char *s);
   int	setdrawop	(wbp w, char *val);
   int	setfg		(wbp w, char *s);
   int	setfillstyle	(wbp w, char *s);
   int	setfont		(wbp w, char **s);
   int	setgamma	(wbp w, double gamma);
   int	setgeometry	(wbp w, char *geo);
   int	setheight	(wbp w, SHORT new_height);
   int	setminheight	(wbp w, SHORT new_height);
   int	seticonicstate	(wbp w, char *s);
   int	seticonlabel	(wbp w, char *val);
   int	seticonpos	(wbp w, char *s);
   int	setimage	(wbp w, char *val);
   int	setleading	(wbp w, int i);
   int	setlinestyle	(wbp w, char *s);
   int	setlinewidth	(wbp w, LONG linewid);
   int	setpointer	(wbp w, char *val);
   int	setwidth	(wbp w, SHORT new_width);
   int	setminwidth	(wbp w, SHORT new_width);
   int  own_selection    (wbp w, char *selection);
   int  request_selection(wbp w, char *selname, char *targetname);
   int  send_selection_response(wbp w, word requestor, char *property, char *target, char *selection, word time, dptr data);
   int	setwindowlabel	(wbp w, char *val);
   int setinputmask(wbp w, char *val);
   int	strimage	(wbp w, int x, int y, int width, int height,
			   struct palentry *e, unsigned char *s,
			   word len, int on_icon);
   void	toggle_fgbg	(wbp w);
   int	walert		(wbp w, int volume);
   void	warpPointer	(wbp w, int x, int y);
   int	wclose		(wbp w);
   int	wgetq		(wbp w, dptr res, word t);
   wbp  wopen		(wbp parent, char *nm, struct b_list *hp, dptr attr, int n, int *e);
#ifndef MSWindows
   void	wflush		(wbp w);
   void	wsync		(wbp w);
#endif					/* MSWindows */
   void	xdis		(wbp w, char *s, int n);


   #ifdef XWindows
      /*
       * Implementation routines specific to X-Windows
       */
      void	unsetclip		(wbp w);
      int	resetfg			(wbp w);
      int	setfgrgb		(wbp w, int r, int g, int b);
      int	setbgrgb		(wbp w, int r, int g, int b);

      XColor	xcolor			(wbp w, LinearColor clr);
      LinearColor	lcolor		(wbp w, XColor color);
      int	pixmap_open		(wbp w, dptr attribs, int argc);
      int	pixmap_init		(wbp w);
      int	remap			(wbp w, int x, int y);
      int	seticonimage		(wbp w, dptr dp);
      int	translate_key_event	(XKeyEvent *k1, char *s, KeySym *k2);
      wdp	alc_display		(char *s);
      void	free_display		(wdp wd);
      wfp	alc_font		(wbp w, char **s);
      wfp	tryfont			(wbp w, char *s);
      wclrp	alc_rgb			(wbp w, char *s, unsigned int r,
					   unsigned int g, unsigned int b,
					   int is_iconcolor);
      int	alc_centry		(wdp wd);
      wclrp	alc_color		(wbp w, char *s);
      void	copy_colors		(wbp w1, wbp w2);
      void	free_xcolor		(wbp w, unsigned long c);
      void	free_xcolors		(wbp w, int extent);
      int	go_virtual		(wbp w);
      int	resizePixmap		(wbp w, int width, int height);
      void	wflushall		(void);
      void postcursor(wbp);
      void scrubcursor(wbp);
int wgetevent2(wbp w, dptr res, word timeout);
int readBMP(char *filename, int p, struct imgdata *imd);
int writeJPEG(wbp w, char *filename, int x, int y, int width, int height);
#ifdef HAVE_LIBXFT
      void drawstrng(wbp w, int x, int y, char *str, int slen);
      void drawutf8(wbp w, int x, int y, char *str, int slen);
      int xft_stringwidth(wbp w, char *s, int n);
      int xft_utf8width(wbp w, char *s, int n);
#endif
      char my_wmap(wbp w);

   #endif				/* XWindows */


   #ifdef MSWindows
      /*
       * Implementation routines specific to MS Windows
       */
      int playmedia		(wbp w, char *s);
      char *nativecolordialog	(wbp w,long r,long g, long b,char *s);
      int nativefontdialog	(wbp w, char *buf, int flags, int fheight);
      char *nativeselectdialog	(wbp w,struct b_list *,char *s);
      char *nativefiledialog	(wbp w,char *s1,char *s2,char *s3,int i,int j,int k);
      HFONT mkfont		(char *s);
      int sysTextWidth		(wbp w, char *s, int n);
      int sysFontHeight		(wbp w);
      int mswinsystem		(char *s);
      void UpdateCursorPos	(wsp ws, wcp wc);
      LRESULT_CALLBACK WndProc	(HWND, UINT, WPARAM, LPARAM);
      HDC CreateWinDC		(wbp);
      HDC CreatePixDC		(wbp, HDC);
      HBITMAP loadimage	(wbp wb, char *filename, unsigned int *width,
      			unsigned int *height, int atorigin, int *status);
      void wfreersc();
      int getdepth(wbp w);
      HBITMAP CreateBitmapFromData(char *data);
      int resizePixmap(wbp w, int width, int height);
      int textWidth(wbp w, char *s, int n);
      int	seticonimage		(wbp w, dptr dp);
      int devicecaps(wbp w, int i);
      void fillarcs(wbp wb, XArc *arcs, int narcs);
      void drawarcs(wbp wb, XArc *arcs, int narcs);
      void drawlines(wbinding *wb, XPoint *points, int npoints);
      void drawpoints(wbinding *wb, XPoint *points, int npoints);
      void drawrectangles(wbp wb, XRectangle *recs, int nrecs);
      void fillpolygon(wbp w, XPoint *pts, int npts);
      void drawsegments(wbinding *wb, XSegment *segs, int nsegs);
      void drawstrng(wbinding *wb, int x, int y, char *s, int slen);
      void unsetclip(wbp w);

   #endif				/* MSWindows */

#endif					/* Graphics */


/*
 * Prototypes for the run-time system.
 */

struct b_record *alcrecd_0	(struct b_constructor *con);
struct b_record *alcrecd_1	(struct b_constructor *con);
struct b_object *alcobject_0	(struct b_class *class);
struct b_object *alcobject_1	(struct b_class *class);
struct b_cast   *alccast_0      ();
struct b_cast   *alccast_1      ();
struct b_methp  *alcmethp_0     ();
struct b_methp  *alcmethp_1     ();
struct b_ucs    *alcucs_0     (int n);
struct b_ucs    *alcucs_1     (int n);
struct b_tvsubs *alcsubs_0	(word len,word pos,dptr var);
struct b_tvsubs *alcsubs_1	(word len,word pos,dptr var);
int     invokef_access_0(int fno, int *nargs);
int     invokef_access_1(int fno, int *nargs);
int     field_access_0(dptr cargp,struct inline_field_cache *);
int     field_access_1(dptr cargp,struct inline_field_cache *);
int     check_access(struct class_field *cf, struct b_class *instance_class);
int     lookup_class_field(struct b_class *class, dptr query, struct inline_field_cache *ic);
dptr    lookup_global(dptr name, struct progstate *prog);
int     lookup_class_field_by_name(struct b_class *class, dptr name);
int     lookup_class_field_by_fnum(struct b_class *class, int fnum);
int     lookup_record_field_by_name(struct b_constructor *recdef, dptr name);
int     lookup_record_field_by_fnum(struct b_constructor *recdef, int fnum);
int     lookup_record_field(struct b_constructor *recdef, dptr query, struct inline_field_cache *ic);
struct loc *lookup_global_loc(dptr name, struct progstate *prog);

int	bfunc		(void);
long	ckadd		(long i, long j);
long	ckmul		(long i, long j);
long	cksub		(long i, long j);
void	cmd_line	(int argc, char **argv, dptr rslt);
void	collect		(int region);
int	cvcset		(dptr dp,int * *cs,int *csbuf);
int	cvnum		(dptr dp,union numeric *result);
int	cvreal		(dptr dp,double *r);
void	deref_0		(dptr dp1, dptr dp2);
void	deref_1		(dptr dp1, dptr dp2);
void	envset		(void);
int	eq		(dptr dp1,dptr dp2);
int	fixtrap		(void);
int	get_name	(dptr dp1, dptr dp2);
int	getch		(void);
int	getche		(void);
double	getdbl		(dptr dp);
void	getimage	(dptr dp1, dptr dp2);

void	hgrow		(union block *bp);
void	hshrink		(union block *bp);
C_integer iipow		(C_integer n1, C_integer n2);
void	init		(char *name, int *argcp, char *argv[], int trc_init);
int	kbhit		(void);
int	mkreal		(double r,dptr dp);
void	nxttab		(C_integer *col, dptr *tablst, dptr endlst,
			   C_integer *last, C_integer *interval);
int	order		(dptr dp);
int	printable	(int c);
int	ripow		(double r, C_integer n, dptr rslt);
void	rtos		(double n,dptr dp,char *s);
int	sig_rsm		(void);
void	varargs		(dptr argp, int nargs, dptr rslt);

struct progstate *alcprog(long icodesize);

dptr rec_structinate(dptr dp, char *name, int nfields, char *a[]);


#if MSWIN32
void stat2rec			(struct _stat *st, dptr dp, struct b_record **rp);
#else					/* MSWIN32 */
void stat2rec			(struct stat *st, dptr dp, struct b_record **rp);
#endif					/* MSWIN32 */
dptr rec_structor		(char *s);
dptr rec_structor3d		(char *s);
int tcp_connect		        (char *host, int port, int timeout);
int getmodefd			(int fd, char *mode);
int getmodenam			(char *path, char *mode);
int get_uid			(char *name);
int get_gid			(char *name);
#if !MSWIN32
dptr make_pwd			(struct passwd *pw, dptr result);
dptr make_group			(struct group *pw, dptr result);
#endif					/* MSWIN32 */
dptr make_host			(struct hostent *pw, dptr result);
dptr make_serv			(struct servent *pw, dptr result);

struct sockaddr *parse_sockaddr(char *s, int *size);

int get_fd			(struct descrip, unsigned int errmask);
dptr u_read			(int fd, int n, dptr d);


   struct b_refresh *alcrefresh_0(word *e, int nl, int nt);
   struct b_refresh *alcrefresh_1(word *e, int nl, int nt);

void call_trace(struct p_frame *pf);

void fail_trace(struct p_frame *pf);
void suspend_trace(struct p_frame *pf);
void return_trace(struct p_frame *pf);

void trace_coact(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_coret(struct b_coexpr *from, struct b_coexpr *to, dptr val);
void trace_cofail(struct b_coexpr *from, struct b_coexpr *to);

   int	invoke_0		(int nargs, dptr *cargs, int *n);
   int	invoke_1		(int nargs, dptr *cargs, int *n);

void xdisp(struct p_frame *pf, int count, FILE *f, struct progstate *p);


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
void errno2why();
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
void cset_to_str(struct b_cset *b, word pos, word len, dptr res);
struct b_ucs *make_ucs_substring(struct b_ucs *b, word pos, word len);
int cset_range_of_pos(struct b_cset *b, word pos);
void mmrefresh		(void);
int iselect(int fd, word t);
long	millisec	(void);

/* Debug func. */
char* dword2str(dptr d);
char *binstr(unsigned int n);
void show_regions();
void *get_csp();
void checkstack();

struct p_frame *alc_p_frame(struct b_proc *pb, struct frame_vars *dynamics);
struct c_frame *alc_c_frame(struct b_proc *pb, int nargs);
void dyn_free(void *p);
void free_frame(struct frame *f);

void push_frame(struct frame *f);
void push_p_frame(struct p_frame *f);
void interp();
dptr get_dptr();
void get_descrip(dptr dest);
void get_deref(dptr dest);
void get_variable(dptr dest);
void pop_to(struct frame *f);
void do_apply();
void do_invoke();
void do_applyf();
void do_invokef();
word get_offset(word *w);
void do_ensure_class_init();
void tail_invoke_frame(struct frame *f);
dptr get_element(dptr d, word i);
void do_field();
struct inline_field_cache *get_inline_field_cache();
void traceback();
struct ipc_line *frame_ipc_line(struct p_frame *pf, int prior);
struct ipc_fname *frame_ipc_fname(struct p_frame *pf, int prior);
struct b_proc *get_current_user_proc();
struct p_frame *get_current_user_frame();
struct p_frame *get_current_user_frame_of(struct b_coexpr *ce);
struct progstate *get_current_program_of(struct b_coexpr *ce);
void switch_to(struct b_coexpr *ce);
void add_to_prog_event_queue(dptr value, int event);
void general_call_0(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
void general_call_1(word clo, dptr expr, int argc, dptr args, word rval, word *failure_label);
void general_access_0(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                      int just_fail, word *failure_label);
void general_access_1(dptr lhs, dptr expr, dptr query, struct inline_field_cache *ic, 
                      int just_fail, word *failure_label);

void general_invokef_0(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                       int argc, dptr args, word rval, word *failure_label);
void general_invokef_1(word clo, dptr expr, dptr query, struct inline_field_cache *ic, 
                       int argc, dptr args, word rval, word *failure_label);
void test_collect(int time_interval, long call_interval, int quiet);
struct b_coexpr *alccoexp_0 (void);
struct b_coexpr *alccoexp_1 (void);
struct b_proc *clone_b_proc(struct b_proc *bp);

void set_curpstate(struct progstate *p);
void set_curr_pf(struct p_frame *x);
void synch_ipc();





