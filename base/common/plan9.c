#include "../h/gsupport.h"

static char *xyz = "";
char **environ = &xyz;

static rd_name(char **f, char *p);
static rd_long(char **f, long *p);

int gettimeofday(struct timeval *tv, struct timezone *tz)
{
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
        werrstr("mkdir: '%s' already exists", path);
        return -1;
    }
    f = create(path, OREAD, DMDIR | mode);
    if (f < 0){
        werrstr("mkdir: can't create '%s': %r", path);
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

int unsetenv(const char *name)
{
    char *ename;
    ename = safe_malloc(strlen(name) + 6);
    sprint(ename, "/env/%s", name);
    remove(ename);
    free(ename);
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
    ulong mode;
    char *f, *t;
    struct Dir *d, nd;

    if ((d = dirstat(from)) == 0)
        return -1;
    mode = d->mode;
    free(d);

    if ((d = dirstat(to)) != 0) {
        if (d->mode & DMDIR) {
            free(d);
            werrstr("rename: target '%s' is a directory", to);
            return -1;
        }
        free(d);
        if (remove(to) < 0)
            return -1;
    }

    f = strrchr(from, '/');
    t = strrchr(to, '/');
    f = f ? f+1 : from;
    t = t ? t+1 : to;
    if (f - from == t - to && strncmp(from, to, f - from) == 0) {
        /* from and to are in same directory (we miss some cases) */
        nulldir(&nd);
        nd.name = t;
        if (dirwstat(from, &nd) < 0)
            return -1;
    } else {
        /* different directories: have to copy */
        int ffd, tfd, n;
        char buf[8192];

        if (mode & DMDIR) {
            werrstr("rename: can't move a directory to another directory");
            return -1;
        }

        ffd = tfd = -1;
        n = 0;
        if ((ffd = open(from, OREAD)) < 0 ||
           (tfd = create(to, OWRITE, mode)) < 0) {
            n = -1;
        }
        while (n >= 0 && (n = read(ffd, buf, sizeof buf)) > 0) {
            if (write(tfd, buf, n) != n)
                n = -1;
        }
        if (ffd >= 0) close(ffd);
        if (tfd >= 0) close(tfd);
        if (n < 0)
            return -1;
        if (remove(from) < 0)
            return -1;
    }
    return 0;
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

/* Adapted from libc/9sys/getenv.c, so that the result needn't be freed. */
char*
oi_getenv(char *name)
{
    int f;
    long r, n;
    char *p, *ep, *ename;
    static struct staticstr buf = {128};
    ename = safe_malloc(strlen(name) + 6);
    sprint(ename, "/env/%s", name);
    f = open(ename, OREAD);
    free(ename);
    if (f < 0)
        return 0;
    n = seek(f, 0, 2);
    if (n < 0) {
        close(f);
        return 0;
    }
    ssreserve(&buf, n + 1);
    seek(f, 0, 0);
    r = readn(f, buf.s, n);
    if (r != n) {
        close(f);
        return 0;
    }
    /* Replace the \0 separators used by rc list variables. */
    ep = buf.s + n - 1;
    for(p = buf.s; p < ep; p++)
        if(*p == '\0')
            *p = ' ';
    buf.s[n] = '\0';
    close(f);
    return buf.s;
}

void
procsetname(char *fmt, ...)
{
    int fd;
    char buf[128];
    va_list arg;

    snprint(buf, sizeof buf, "#p/%d/args", getpid());
    if((fd = open(buf, OWRITE)) < 0)
        return;

    va_start(arg, fmt);
    vsnprint(buf, sizeof(buf), fmt, arg);
    va_end(arg);
    write(fd, buf, strlen(buf));
    close(fd);
}
