/*
 * mproto.h -- prototypes for functions common to several modules.
 */

void	clear_sbuf	(struct str_buf *sbuf);
int	cmp_pre		(char *pre1, char *pre2);
char *getdir(char *s);
struct fileparts *fparse(char *s);
void	free_stbl	(void);
void	init_sbuf	(struct str_buf *sbuf);
void	init_str	(void);
char	*makename	(char *d,char *name,char *e);
char    *maketemp       (char *fn);
char    *get_system_error(void);
struct il_code *new_il	(int il_type, int size);
void	new_sbuf	(struct str_buf *sbuf);
int     isabsolute      (char *s);
char	*pathfind	(char *cd, char *path, char *name, char *extn);
char    *pathelem       (char **s);
int     newer_than(char *f1, char *f2);
char    *last_pathelem(char *s);
char	*spec_str	(char *s);
char	*str_install	(struct str_buf *sbuf);
int	tonum		(int c);
void 	zero_sbuf	(struct str_buf *sbuf);
void    append_n        (struct str_buf *sbuf, char *s, int n);
char    *intern(char *s);
char    *intern_n(char *s, int n);
char    *join(char *s, ...);
struct str_buf *get_sbuf(void);
void    rel_sbuf(struct str_buf *sbuf);
void    clear_local_sbufs(void);

/*
 * oi_getopt()  variables and func.
 */
extern int oi_optind;		/* index into parent argv vector */
extern int oi_optopt;		/* character checked for validity */
extern char *oi_optarg;		/* argument associated with option */
int oi_getopt(int nargc, char *const nargv[], const char *ostr);

char *findexe(char *name);
char *relfile	(char *prog, char *mod);
void normalize(char *path);
char *canonicalize(char *path);
void *safe_calloc(size_t m, size_t n);
void *safe_zalloc(size_t size);
void *safe_realloc(void *ptr, size_t size);
void *safe_malloc(size_t size);

int utf8_check(char **p, char *end);
int utf8_iter(char **p);
int utf8_rev_iter(char **p);
void utf8_rev_iter0(char **p);
int utf8_seq(int c, char *s);

struct rangeset *init_rangeset(void);
void free_rangeset(struct rangeset *rs);
void add_range(struct rangeset *cs, int from, int to);
void print_rangeset(struct rangeset *rs);

void calc_ucs_index_settings(word utf8_len, word len, word *index_step, word *n_offs, word *offset_bits, word *n_off_words);

#if MSWIN32
int strcasecmp(char *s1, char *s2);
int strncasecmp(char *s1, char *s2, int n);
int mkstemp(char *path);
WCHAR *utf8_to_wchar(char *s);
char *wchar_to_utf8(WCHAR *s);
int stat_utf8(char *path, struct stat *st);
int open_utf8(char *path, int oflag, int pmode);
int rename_utf8(char *path1, char *path2);
int mkdir_utf8(char *path);
int remove_utf8(char *path);
int rmdir_utf8(char *path);
int access_utf8(char *path, int mode);
int chdir_utf8(char *path);
char *getcwd_utf8(char *buff, int maxlen);
#endif

char *double2cstr(double n);
char *word2cstr(word n);
unsigned int hashcstr(char *s);

char *get_hostname(void);
int is_flowterm_tty(FILE *f);
