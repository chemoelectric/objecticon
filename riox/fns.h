void	keyboardsend(char*, int);
int	whide(Window*);
int	wunhide(Window*);
void    wkeepbelow(Window *w);
void    wkeepabove(Window *w);
void    wclosereq(Window *w);
int      dbgalt(Alt *alts, char *lab);

void	freescrtemps(void);
int	parsewctl(char**, Rectangle, Rectangle*, int*, int*, int*, int*, int*, 
                  int *, int*, int*, int*, int*, int*, int *, char**, char*, char*);
int	writewctl(Xfid*, char*);
int     wlimitrect(Window *w, Rectangle *r);
int     limitrect(int noborder, int mindx, int maxdx, int mindy, int maxdy, Rectangle *r);
int     resizable(Window *w);
void    ensurestacking(void);

Window *new(Image*, int, int, int, int, int, int, int, int, int, int, int, char*, char*, char**);
void	riosetcursor(Cursor*, int);
int	min(int, int);
int	max(int, int);
Rune*	strrune(Rune*, Rune);
int	isalnum(Rune);
void	timerstop(Timer*);
void	timercancel(Timer*);
Timer*	timerstart(int);
void	error(char*);
void	killprocs(void);
int	shutdown(void*, char*);
void	iconinit(void);
void	*erealloc(void*, uint);
void *emalloc(uint);
char *estrdup(char*);
void	button3menu(void);
void	button3txtmenu(Window*);
void	button3wmenu(Window*);
void	cvttorunes(char*, int, Rune*, int*, int*, int*);
/* was (byte*,int)	runetobyte(Rune*, int); */
char* runetobyte(Rune*, int, int*);
void	putsnarf(void);
void	getsnarf(void);
void	timerinit(void);
int	goodrect(Rectangle);
int     readmouseex(MousectlEx *mc);
void    sendmouseevent(Window *w, uchar type);

#define	runemalloc(n)		malloc((n)*sizeof(Rune))
#define	runerealloc(a, n)	realloc(a, (n)*sizeof(Rune))
#define	runemove(a, b, n)	memmove(a, b, (n)*sizeof(Rune))
