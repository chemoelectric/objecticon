/*
 * mproto.h -- prototypes for functions common to several modules.
 */

unsigned short *bitvect	(char *image, int len);
void	clear_sbuf	(struct str_buf *sbuf);
int	cmp_pre		(char *pre1, char *pre2);
void	cset_init	(FILE *f, unsigned short *bv);
struct fileparts *fparse(char *s);
void	free_stbl	(void);
void	id_comment	(FILE *f);
void	init_sbuf	(struct str_buf *sbuf);
void	init_str	(void);
char	*makename	(char *d,char *name,char *e);
long	millisec	(void);
struct il_code *new_il	(int il_type, int size);
void	new_sbuf	(struct str_buf *sbuf);
void	nxt_pre		(char *pre, char *nxt, int n);
int     isabsolute      (char *s);
char	*pathfind	(char *path, char *name, char *extn);
char    *pathelem       (char **s);
int     newer_than(char *f1, char *f2);
char    *last_pathelem(char *s);
int	ppch		(void);
void	ppdef		(char *name, char *value);
void	ppecho		(void);
int	ppinit		(char *fname, char *inclpath, int m4flag);
int	prt_i_str	(FILE *f, char *s, int len);
int	smatch		(char *s,char *t);
char	*spec_str	(char *s);
char	*str_install	(struct str_buf *sbuf);
int	tonum		(int c);
void 	zero_sbuf	(struct str_buf *sbuf);
char    *intern(char *s);
char    *join(char *s, ...);
struct str_buf *get_sbuf();
void    rel_sbuf(struct str_buf *sbuf);
void    clear_local_sbufs();

int	getopt		(int argc, char * const argv[], const char *optstring);

char *findexe(char *name);
char *relfile	(char *prog, char *mod);
void normalize(char *path);
char *canonicalize(char *path);
void *safe_calloc(size_t m, size_t n);
void *safe_alloc(size_t size);
void *safe_realloc(void *ptr, size_t size);

int utf8_check(char **p, char *end);
int utf8_iter(char **p);
int utf8_rev_iter(char **p);
int utf8_seq(int c, char *s);

struct rangeset *init_rangeset(void);
void free_rangeset(struct rangeset *rs);
int add_range(struct rangeset *cs, int from, int to);
void print_rangeset(struct rangeset *rs);

int calc_ucs_index_step(word length);
