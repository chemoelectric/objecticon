#include "../h/gsupport.h"

static char *xyz = "";
char **environ = &xyz;

static rd_name(char **f, char *p);
static rd_long(char **f, long *p);

int gettimeofday(struct timeval *tv, struct timezone *tz)
{

    int f;
    uchar b[8];
    vlong t;

    t = nsec();

    tv->tv_sec = t/1000000000;
    tv->tv_usec = (t/1000)%1000000;

    if (tz) {
        tz->tz_minuteswest = 0;
        tz->tz_dsttime = 0;
    }

    return 0;
}

int mkdir(const char *path, mode_t mode)
{
    int f;

    if (access(path, AEXIST) == 0){
        werrstr("mkdir: %s already exists", path);
        return -1;
    }
    f = create(path, OREAD, DMDIR | mode);
    if (f < 0){
        werrstr("mkdir: can't create %s: %r", path);
        return -1;
    }
    close(f);
    return 0;
}

int rmdir(const char *path)
{
    return remove(path);
}

char *getcwd(char *buf, size_t size)
{
    int n, fd;
    fd = open(".", OREAD);
    if (fd < 0)
        return 0;
    n = fd2path(fd, buf, size);
    close(fd);
    if (n != 0)
        return 0;
    if (strlen(buf) > size - 6) {
        werrstr("buffer too short");
        return 0;
    }
    return buf;
}

void exit(int status)
{
    char buff[64];
    if (status == EXIT_SUCCESS)
        exits(0);
    if (status == EXIT_FAILURE)
        exits("Failure");
    sprint(buff, "Unknown exit code: %d", status);
    exits(buff);
}

int setenv(const char *name, const char *value, int overwrite)
{
    return putenv(name, value);
}

int unsetenv(const char *name)
{
    char buf[128];
    snprint(buf, sizeof(buf), "/env/%s", name);
    if (strcmp(buf + 5, name) != 0) {
        werrstr("name too long");
        return -1;
    }
    remove(buf);
    return 0;
}

int mkstemp(char *template)
{
    return create(mktemp(template), ORDWR, 0777);
}

int dup2(int oldfd, int newfd)
{
    return dup(oldfd, newfd);
}

off_t lseek(int fd, off_t offset, int whence)
{
    return seek(fd, offset, whence);
}

void *bsearch(const void *key, const void *base,
              size_t nmemb, size_t size,
              int (*compar)(const void *, const void *))
{
    long i, bot, top, new;
    void *p;

    bot = 0;
    top = bot + nmemb - 1;
    while(bot <= top){
        new = (top + bot)/2;
        p = (char *)base+new*size;
        i = (*compar)(key, p);
        if (i == 0)
            return p;
        if (i > 0)
            bot = new + 1;
        else
            top = new - 1;
    }
    return 0;
}

int gethostname(char *name, size_t len)
{
    int n, fd;
    char buf[128];

    fd = open("/dev/sysname", OREAD);
    if (fd < 0)
        return -1;
    n = read(fd, buf, sizeof(buf));
    close(fd);
    if (n <= 0)
        return -1;
    if (n >= sizeof(buf)) {
        werrstr("buffer too short");
        return -1;
    }
    buf[n] = 0;
    strncpy(name, buf, len);
    name[len - 1] = 0;
    return 0;
}

int execv(const char *path, char *const argv[])
{
    return exec(path, argv);
}

int execve(const char *path, char *const argv[], char *const envp[])
{
    return exec(path, argv);
}

int rename(const char *from, const char *to)
{
    int n, i;
    char *f, *t;
    struct Dir *d, nd;
    long mode;

    if(access(to, 0) >= 0){
        if(remove(to) < 0){
            return -1;
        }
    }
    if((d = dirstat(to)) != 0){
        free(d);
        werrstr("rename: can't get rid of dest");
        return -1;
    }
    if((d = dirstat(from)) == 0){
        werrstr("rename: can't stat src");
        return -1;
    }
    f = strrchr(from, '/');
    t = strrchr(to, '/');
    f = f? f+1 : from;
    t = t? t+1 : to;
    n = 0;
    if(f-from==t-to && strncmp(from, to, f-from)==0){
        /* from and to are in same directory (we miss some cases) */
        i = strlen(t);
        nulldir(&nd);
        nd.name = t;
        if(dirwstat(from, &nd) < 0){
            n = -1;
        }
    }else{
        /* different directories: have to copy */
        int ffd, tfd;
        char buf[8192];

        if((ffd = open(from, 0)) < 0 ||
           (tfd = create(to, 1, d->mode)) < 0){
            close(ffd);
            n = -1;
        }
        while(n>=0 && (n = read(ffd, buf, 8192)) > 0)
            if(write(tfd, buf, n) != n){
                n = -1;
            }
        close(ffd);
        close(tfd);
        if(n>0)
            n = 0;
        if(n == 0) {
            if(remove(from) < 0){
                return -1;
            }
        }
    }
    free(d);
    return n;
}

int unlink(const char *path)
{
    return remove(path);
}

/* Adapted from libc/9sys/ctime.c */
void readtzinfo(struct tzinfo *tz)
{
    char buf[TZSIZE*11+30], *p;
    int i;

    memset(buf, 0, sizeof(buf));
    i = open("/env/timezone", 0);
    if(i < 0)
        goto error;
    if(read(i, buf, sizeof(buf)) >= sizeof(buf)){
        close(i);
        goto error;
    }
    close(i);
    p = buf;
    if(rd_name(&p, tz->stname))
        goto error;
    if(rd_long(&p, &tz->stdiff))
        goto error;
    if(rd_name(&p, tz->dlname))
        goto error;
    if(rd_long(&p, &tz->dldiff))
        goto error;
    for(i=0; i<TZSIZE; i++) {
        if(rd_long(&p, &tz->dlpairs[i]))
            goto error;
        if(tz->dlpairs[i] == 0)
            return;
    }

  error:
    tz->stdiff = 0;
    strcpy(tz->stname, "GMT");
    tz->dlpairs[0] = 0;
}

static
rd_name(char **f, char *p)
{
    int c, i;

    for(;;) {
        c = *(*f)++;
        if(c != ' ' && c != '\n')
            break;
    }
    for(i=0; i<3; i++) {
        if(c == ' ' || c == '\n')
            return 1;
        *p++ = c;
        c = *(*f)++;
    }
    if(c != ' ' && c != '\n')
        return 1;
    *p = 0;
    return 0;
}

static
rd_long(char **f, long *p)
{
    int c, s;
    long l;

    s = 0;
    for(;;) {
        c = *(*f)++;
        if(c == '-') {
            s++;
            continue;
        }
        if(c != ' ' && c != '\n')
            break;
    }
    if(c == 0) {
        *p = 0;
        return 0;
    }
    l = 0;
    for(;;) {
        if(c == ' ' || c == '\n')
            break;
        if(c < '0' || c > '9')
            return 1;
        l = l*10 + c-'0';
        c = *(*f)++;
    }
    if(s)
        l = -l;
    *p = l;
    return 0;
}

/*
 * getopt() get command-line options.
 *
 * Based on a public domain implementation of System V
 *  getopt(3) by Keith Bostic (keith@seismo), Aug 24, 1984.
 */

#define BadCh	(int)'?'
#define EMSG	""
#define tell(m)	fprintf(stderr,"%s: %s -- %c\n",nargv[0],m,optopt);return BadCh;

int optind = 1;		/* index into parent argv vector */
int optopt;		/* character checked for validity */
char *optarg;		/* argument associated with option */

int getopt(int nargc, char *const nargv[], const char *ostr)
   {
   static char *place = EMSG;		/* option letter processing */
   char *oli;			/* option letter list index */

   if(!*place) {			/* update scanning pointer */
      if(optind >= nargc || *(place = nargv[optind]) != '-' || !*++place)
         return(EOF);
      if (*place == '-') {		/* found "--" */
         ++optind;
         return(EOF);
         }
      }					/* option letter okay? */

   if (((optopt=(int)*place++) == (int)':') || (oli=strchr(ostr,optopt)) == 0) {
      if(!*place) ++optind;
      tell("illegal option");
      }
   if (*++oli != ':') {			/* don't need argument */
      optarg = NULL;
      if (!*place) ++optind;
      }
   else {				/* need an argument */
      if (*place) optarg = place;	/* no white space */
      else if (nargc <= ++optind) {	/* no arg */
         place = EMSG;
         tell("option requires an argument");
         }
      else optarg = nargv[optind];	/* white space */
      place = EMSG;
      ++optind;
      }
   return(optopt);			/* dump back option letter */
   }

