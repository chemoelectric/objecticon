/* Auto-generated by mkexports.icn */

struct oisymbols {
    struct progstate **curpstate;
    struct b_coexpr **k_current;
    struct p_frame **curr_pf;
    struct c_frame **curr_cf;
    struct progstate **progs;
    struct tend_desc **tendedlist;
    struct b_cset **emptycs;
    struct b_cset **blankcs;
    struct b_cset **lparcs;
    struct b_cset **rparcs;
    struct b_cset **k_ascii;
    struct b_cset **k_cset;
    struct b_cset **k_uset;
    struct b_cset **k_digits;
    struct b_cset **k_lcase;
    struct b_cset **k_letters;
    struct b_cset **k_ucase;
    struct b_ucs **emptystr_ucs;
    struct b_ucs **blank_ucs;
    struct descrip *blank;
    struct descrip *emptystr;
    struct descrip *nullptr;
    struct descrip *lcase;
    struct descrip *nulldesc;
    struct descrip *yesdesc;
    struct descrip *onedesc;
    struct descrip *ucase;
    struct descrip *zerodesc;
    struct descrip *minusonedesc;
    struct descrip *thousanddesc;
    struct descrip *milliondesc;
    struct descrip *billiondesc;
    struct descrip *csetdesc;
    struct descrip *rzerodesc;
    struct sdescrip *fdf;
    struct sdescrip *ptrf;
    struct sdescrip *dsclassname;
    struct sdescrip *pixclassname;
#if Graphics
    struct sdescrip *wclassname;
#endif
    struct descrip *defaultwindowlabel;
    double *defaultfontsize;
    char **defaultfont;
    double *defaultleading;
    struct imgdataformat *imgdataformat_A8;
    struct imgdataformat *imgdataformat_A16;
    struct imgdataformat *imgdataformat_RGB24;
    struct imgdataformat *imgdataformat_BGR24;
    struct imgdataformat *imgdataformat_RGBA32;
    struct imgdataformat *imgdataformat_ABGR32;
    struct imgdataformat *imgdataformat_RGB48;
    struct imgdataformat *imgdataformat_RGBA64;
    struct imgdataformat *imgdataformat_G8;
    struct imgdataformat *imgdataformat_GA16;
    struct imgdataformat *imgdataformat_AG16;
    struct imgdataformat *imgdataformat_G16;
    struct imgdataformat *imgdataformat_GA32;
    struct imgdataformat *imgdataformat_PALETTE1;
    struct imgdataformat *imgdataformat_PALETTE2;
    struct imgdataformat *imgdataformat_PALETTE4;
    struct imgdataformat *imgdataformat_PALETTE8;
    int (*eq)(dptr d1, dptr d2);
    int (*ceq)(dptr dp, char *s);
    int (*anycmp)(dptr dp1,dptr dp2);
    int (*lexcmp)(dptr dp1,dptr dp2);
    int (*equiv)(dptr dp1,dptr dp2);
    int (*caseless_lexcmp)(dptr dp1, dptr dp2);
    int (*consistent_lexcmp)(dptr dp1, dptr dp2);
    void (*create_list)(word nslots, dptr d);
    void (*create_table)(word nslots, word nelem, dptr d);
    void (*create_set)(word nslots, word nelem, dptr d);
    int (*list_get)(dptr l, dptr res);
    int (*list_pull)(dptr l, dptr res);
    void (*list_put)(dptr l, dptr val);
    void (*list_push)(dptr l, dptr val);
    void (*list_insert)(dptr l, word pos, dptr val);
    void (*list_del)(dptr l, word pos);
    int (*set_del)(dptr s, dptr key);
    int (*table_del)(dptr t, dptr key);
    void (*table_insert)(dptr t, dptr key, dptr val, int overwrite);
    void (*set_insert)(dptr s, dptr entry);
    void (*list_clear)(dptr l);
    void (*set_clear)(dptr s);
    void (*table_clear)(dptr t);
    dptr (*get_element)(dptr d, word i);
    struct b_lelem * (*get_lelem_for_index)(struct b_list *bp, word i, word *pos);
    struct b_lelem * (*lginit)(struct b_list *lb, word i, struct lgstate *state);
    struct b_lelem * (*lgfirst)(struct b_list *lb, struct lgstate *state);
    struct b_lelem * (*lgnext)(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
    struct b_lelem * (*lglast)(struct b_list *lb, struct lgstate *state);
    struct b_lelem * (*lgprev)(struct b_list *lb, struct lgstate *state, struct b_lelem *le);
    void (*cplist)(dptr dp1,dptr dp2,word i,word size);
    void (*cpset)(dptr dp1,dptr dp2,word size);
    void (*cptable)(dptr dp1,dptr dp2,word size);
    void (*C_to_list)(dptr result, char *spec, ...);
    void (*C_to_record)(dptr result, char *spec, ...);
    void (*deref)(dptr dp1, dptr dp2);
    int (*cnv_c_dbl)(dptr s, double *d);
    int (*cnv_c_int)(dptr s, word *d);
    int (*cnv_c_str)(dptr s, dptr d);
    int (*cnv_cset)(dptr s, dptr d);
    int (*cnv_ucs)(dptr s, dptr d);
    int (*cnv_str_or_ucs)(dptr s, dptr d);
    int (*cnv_ec_int)(dptr s, word *d);
    int (*cnv_eint)(dptr s, dptr d);
    int (*cnv_int)(dptr s, dptr d);
    int (*cnv_real)(dptr s, dptr d);
    int (*cnv_str)(dptr s, dptr d);
    word (*cvpos)(word pos, word len);
    word (*cvpos_item)(word pos, word len);
    int (*cvslice)(word *i, word *j, word len);
    int (*def_c_dbl)(dptr s, double df, double * d);
    int (*def_c_int)(dptr s, word df, word * d);
    int (*def_c_str)(dptr s, char * df, dptr d);
    int (*def_cset)(dptr s, struct b_cset * df, dptr d);
    int (*def_ucs)(dptr s, struct b_ucs * df, dptr d);
    int (*def_ec_int)(dptr s, word df, word * d);
    int (*def_eint)(dptr s, word df, dptr d);
    int (*def_int)(dptr s, word df, dptr d);
    int (*def_real)(dptr s, double df, dptr d);
    int (*def_str)(dptr s, dptr df, dptr d);
    struct b_class * (*get_class_for)(dptr x);
    struct b_constructor * (*get_constructor_for)(dptr x);
    struct b_proc * (*get_proc_for)(dptr x);
    struct progstate * (*get_program_for)(dptr x);
    struct b_coexpr * (*get_coexpr_for)(dptr x);
    void (*cstr2string)(char *s, dptr d);
    void (*bytes2string)(char *s, word len, dptr d);
    void (*cstrs2string)(char **s, char *delim, dptr d);
    char * (*double2cstr)(double n);
    char * (*word2cstr)(word n);
    void (*bigadd)(dptr da, dptr db, dptr dx);
    void (*bigsub)(dptr da, dptr db, dptr dx);
    void (*bigmul)(dptr da, dptr db, dptr dx);
    void (*bigdiv)(dptr da, dptr db, dptr dx);
    void (*bigmod)(dptr da, dptr db, dptr dx);
    void (*bigneg)(dptr da, dptr dx);
    int (*bigpow)(dptr da, dptr db, dptr dx);
    int (*bigpowri)(double a, dptr db, dptr drslt);
    void (*bigand)(dptr da, dptr db, dptr dx);
    void (*bigor)(dptr da, dptr db, dptr dx);
    void (*bigxor)(dptr da, dptr db, dptr dx);
    void (*bigshift)(dptr da, word n, dptr dx);
    int (*bigcmp)(dptr da, dptr db);
    void (*bigrand)(dptr da, dptr dx);
    int (*bigsign)(dptr da);
    void (*fatalerr)(int n,dptr v);
    void (*ffatalerr)(char *fmt, ...);
    void (*syserr)(char *fmt, ...);
    void (*err_msg)(int n, dptr v);
    void (*set_errno)(int n);
    char    * (*get_system_error)(void);
    void (*errno2why)(void);
    void (*why)(char *s);
    void (*whyf)(char *fmt, ...);
    void (*env_int)(char *name, int *variable, int min, int max);
    void (*env_word)(char *name, word *variable, word min, word max);
    void (*env_uword)(char *name, uword *variable, uword min, uword max);
    void (*env_double)(char *name, double *variable, double min, double max);
    void (*env_string)(char *name, char **variable);
    dptr (*c_get_instance_data)(dptr x, dptr fname, struct inline_field_cache *ic);
    int (*c_is)(dptr x, dptr cname, struct inline_global_cache *ic);
    int (*class_is)(struct b_class *class1, struct b_class *class2);
    int (*get_proc_kind)(struct b_proc *bp);
    struct b_cset * (*rangeset_to_block)(struct rangeset *rs);
    struct b_ucs * (*make_ucs_block)(dptr utf8, word length);
    struct b_ucs * (*make_one_char_ucs_block)(int i);
    void (*utf8_substr)(struct b_ucs *b, word pos, word len, dptr res);
    int (*ucs_char)(struct b_ucs *b, word pos);
    int (*in_cset)(struct b_cset *b, int c);
    char * (*ucs_utf8_ptr)(struct b_ucs *b, word pos);
    struct b_ucs * (*cset_to_ucs_block)(struct b_cset *b0, word pos, word len);
    void (*cset_to_string)(struct b_cset *b, word pos, word len, dptr res);
    struct b_ucs * (*make_ucs_substring)(struct b_ucs *b, word pos, word len);
    int (*cset_range_of_pos)(struct b_cset *b, word pos);
    int (*need_ucs)(dptr s);
    int (*stringint_str2int)(stringint * sip, char *s);
    char * (*stringint_int2str)(stringint * sip, int i);
    stringint * (*stringint_lookup)(stringint *sip, char *s);
    stringint * (*stringint_rev_lookup)(stringint *sip, int i);
    int (*utf8_check)(char **p, char *end);
    int (*utf8_iter)(char **p);
    int (*utf8_rev_iter)(char **p);
    void (*utf8_rev_iter0)(char **p);
    int (*utf8_seq)(int c, char *s);
    struct rangeset * (*init_rangeset)(void);
    void (*free_rangeset)(struct rangeset *rs);
    void (*add_range)(struct rangeset *cs, int from, int to);
    word (*millisec)(void);
    struct descrip (*block_to_descriptor)(union block *ptr);
    int (*is_flag)(dptr d);
    int (*is_ascii_string)(dptr d);
    uword (*hashcstr)(char *s);
    char * (*get_hostname)(void);
    char    * (*maketemp)(char *fn);
    int (*is_flowterm_tty)(FILE *f);
    void (*begin_link)(FILE *f, dptr fname, word line);
    void (*end_link)(FILE *f);
    char * (*getenv_nn)(char *name);
    char * (*buffvprintf)(char *fmt, va_list ap);
    char * (*buffprintf)(char *fmt, ...);
    int (*oi_toupper)(int c);
    int (*oi_tolower)(int c);
    char * (*buffstr)(dptr d);
    void (*buffnstr)(dptr d, char **s, ...);
    int (*is_little_endian)(void);
    void (*ensure_hash)(void *tbl0);
    void (*add_to_hash_pre)(void *tbl0, void *item0, uword h);
    void (*add_to_hash)(void *tbl0, void *item0);
    void (*free_hash)(void *tbl0);
    void (*clear_hash)(void *tbl0);
    void (*check_hash)(void *tbl0);
    void * (*safe_calloc)(size_t m, size_t n);
    void * (*safe_zalloc)(size_t size);
    void * (*safe_malloc)(size_t size);
    void * (*safe_realloc)(void *ptr, size_t size);
    int (*safe_imul)(int x, int y, int z);
    char * (*salloc)(char *s);
    void * (*padded_malloc)(size_t size);
#if MSWIN32
    struct sdescrip *socketf;
    struct sdescrip *wsclassname;
    WCHAR * (*ucs_to_wchar)(dptr str, int nullterm, word *len);
    WCHAR * (*utf8_string_to_wchar)(dptr str, int nullterm, word *len);
    void (*wchar_to_utf8_string)(WCHAR *src, dptr res);
    void (*wchar_to_ucs)(WCHAR *src, dptr res);
    WCHAR * (*string_to_wchar)(dptr str, int nullterm, word *len);
    WCHAR * (*utf8_to_wchar)(char *s);
    char * (*wchar_to_utf8)(WCHAR *s);
    void (*win32error2why)(void);
    int (*strcasecmp)(char *s1, char *s2);
    int (*strncasecmp)(char *s1, char *s2, int n);
    int (*mkstemp)(char *path);
    int (*gettimeofday)(struct timeval *tv, struct timezone *tz);
    int (*stat64_utf8)(char *path, struct _stat64 *st);
    int (*stat_utf8)(char *path, struct stat *st);
    int (*open_utf8)(char *path, int oflag, int pmode);
    int (*rename_utf8)(char *path1, char *path2);
    int (*mkdir_utf8)(char *path);
    int (*remove_utf8)(char *path);
    int (*rmdir_utf8)(char *path);
    int (*access_utf8)(char *path, int mode);
    int (*chdir_utf8)(char *path);
    char * (*getcwd_utf8)(char *buff, int maxlen);
    char * (*getenv_utf8)(char *var);
    int (*setenv_utf8)(char *var, char *value);
    FILE * (*fopen_utf8)(char *path, char *mode);
    int (*system_utf8)(char *cmd);
#endif
};
