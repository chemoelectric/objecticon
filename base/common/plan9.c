#include "../h/gsupport.h"

static char *xyz = "";
char **environ = &xyz;

static uvlong order = 0x0001020304050607ULL;

static rd_name(char **f, char *p);
static rd_long(char **f, long *p);

void be2vlong(vlong *to, uchar *f)
{
    uchar *t, *o;
    int i;

    t = (uchar*)to;
    o = (uchar*)&order;
    for(i = 0; i < 8; i++)
        t[o[i]] = f[i];
}

int gettimeofday(struct timeval *tv, struct timezone *tz)
{

    int f;
    uchar b[8];
    vlong t;

    memset(b, 0, sizeof b);
    f = open("/dev/bintime", OREAD);
    if (f >= 0) {
        pread(f, b, sizeof(b), 0);
        close(f);
    }
    be2vlong(&t, b);

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

int system(const char *command)
{
    int pid, rc;
    Waitmsg *w;
    switch (pid = rfork(RFPROC|RFFDG)) {
        case 0: {
            execl("/bin/rc", "rc", "-c", command, 0);
            exits("execl returned in system()");
            return -1;
        }
        case -1:
            return -1;
    }
    w = waitforpid(pid);
    if (!w)
        return -1;
    rc = (w->msg[0] == 0 ? 0 : 1);
    free(w);
    return rc;
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
    return 0;
}


/*
 * status not yet collected for processes that have exited
 */
typedef struct Waited Waited;
struct Waited {
   Waitmsg*        msg;
   Waited* next;
};
static Waited *wd;

static Waitmsg *lookpid(int pid)
{
    Waited **wl, *w;
    Waitmsg *msg;

    for(wl = &wd; (w = *wl) != nil; wl = &w->next)
        if(pid <= 0 || w->msg->pid == pid){
            msg = w->msg;
            *wl = w->next;
            free(w);
            return msg;
        }
    return 0;
}

static void addpid(Waitmsg *msg)
{
    Waited *w;

    w = malloc(sizeof(*w));
    if(w == nil){
        /* lost it; what can we do? */
        free(msg);
        return;
    }
    w->msg = msg;
    w->next = wd;
    wd = w;
}

Waitmsg *waitforpid(int pid)
{
    Waitmsg *w;
    
    w = lookpid(pid);
    if (w)
        return w;

    for (;;) {
        w = wait();
        if (!w)
            return 0;
        if (pid == -1 || w->pid == pid)
            break;
        addpid(w);
    }

    return w;
}

#define	TZSIZE	150

/* Adapted from libc/9sys/ctime.c */
int readtzinfo(struct tzinfo *tz)
{
    char buf[TZSIZE*11+30], *p;
    int i;
    memset(buf, 0, sizeof(buf));
    i = open("/env/timezone", 0);
    if(i < 0)
        return 0;
    if(read(i, buf, sizeof(buf)) >= sizeof(buf)){
        close(i);
        return 0;
    }
    close(i);
    p = buf;
    if(rd_name(&p, tz->stname))
        return 0;
    if(rd_long(&p, &tz->stdiff))
        return 0;
    if(rd_name(&p, tz->dlname))
        return 0;
    if(rd_long(&p, &tz->dldiff))
        return 0;
    return 1;
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
