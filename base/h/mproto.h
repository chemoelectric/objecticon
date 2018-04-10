/*
 * mproto.h -- prototypes for functions common to several modules.
 */

void	clear_sbuf	(struct str_buf *sbuf);
int	cmp_pre		(char *pre1, char *pre2);
char *getdir(char *s);
char *getext(char *s);
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
void normalize(char *path);
char *canonicalize(char *path);
void *safe_calloc(size_t m, size_t n);
void *safe_zalloc(size_t size);
void *safe_realloc(void *ptr, size_t size);
void *safe_malloc(size_t size);

char *salloc(char *s);

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

#if MSWIN32 || PLAN9
int strcasecmp(char *s1, char *s2);
int strncasecmp(char *s1, char *s2, int n);
int mkstemp(char *path);
#endif

#if MSWIN32
int gettimeofday(struct timeval *tv, struct timezone *tz);
WCHAR *utf8_to_wchar(char *s);
char *wchar_to_utf8(WCHAR *s);
int stat64_utf8(char *path, struct _stat64 *st);
int stat_utf8(char *path, struct stat *st);
int open_utf8(char *path, int oflag, int pmode);
int rename_utf8(char *path1, char *path2);
int mkdir_utf8(char *path);
int remove_utf8(char *path);
int rmdir_utf8(char *path);
int access_utf8(char *path, int mode);
int chdir_utf8(char *path);
char *getcwd_utf8(char *buff, int maxlen);
char *getenv_utf8(char *var);
int setenv_utf8(char *var, char *value);
FILE *fopen_utf8(char *path, char *mode);
int system_utf8(char *cmd);
#endif

#if PLAN9
void readtzinfo(struct tzinfo *tz);
char* oi_getenv(char *name);
void procsetname(char *fmt, ...);
#endif

char *double2cstr(double n);
char *word2cstr(word n);
unsigned int hashcstr(char *s);

char *get_hostname(void);
int is_flowterm_tty(FILE *f);
char *getenv_nn(char *name);

char *buffvprintf(char *fmt, va_list ap);
char *buffprintf(char *fmt, ...);

void ssreserve(struct staticstr *ss, size_t n);
void ssexpand(struct staticstr *ss, size_t n);
char *sscpy(struct staticstr *ss, char *val);
char *sscat(struct staticstr *ss, char *val);
void ssdbg(struct staticstr *ss);

int oi_toupper(int c);
int oi_tolower(int c);

extern unsigned char oi_ctype[];

#define _CU     01
#define _CL     02
#define _CN     04
#define _CS     010
#define _CP     020
#define _CC     040
#define _CB     0100
#define _CX     0200

extern unsigned char    oi_ctype[];

#define oi_isalpha(c)      (oi_ctype[(unsigned char)(c)]&(_CU|_CL))
#define oi_isupper(c)      (oi_ctype[(unsigned char)(c)]&_CU)
#define oi_islower(c)      (oi_ctype[(unsigned char)(c)]&_CL)
#define oi_isdigit(c)      (oi_ctype[(unsigned char)(c)]&_CN)
#define oi_isxdigit(c)     (oi_ctype[(unsigned char)(c)]&_CX)
#define oi_isspace(c)      (oi_ctype[(unsigned char)(c)]&_CS)
#define oi_ispunct(c)      (oi_ctype[(unsigned char)(c)]&_CP)
#define oi_isalnum(c)      (oi_ctype[(unsigned char)(c)]&(_CU|_CL|_CN))
#define oi_isprint(c)      (oi_ctype[(unsigned char)(c)]&(_CP|_CU|_CL|_CN|_CB))
#define oi_isgraph(c)      (oi_ctype[(unsigned char)(c)]&(_CP|_CU|_CL|_CN))
#define oi_iscntrl(c)      (oi_ctype[(unsigned char)(c)]&_CC)
#define oi_isascii(c)      ((unsigned char)(c)<=0177)
#define oi_mtoupper(c)     ((c)-'a'+'A')
#define oi_mtolower(c)     ((c)-'A'+'a')
