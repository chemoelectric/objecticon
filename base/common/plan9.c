#include "../h/gsupport.h"

int errno;
static char *xyz = "";
char **environ = &xyz;

static uvlong order = 0x0001020304050607ULL;

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
    if(f >= 0) {
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

    if(access(path, AEXIST) == 0){
        werrstr("mkdir: %s already exists", path);
        return -1;
    }
    f = create(path, OREAD, DMDIR | mode);
    if(f < 0){
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
    return getwd(buf, size);
}

void exit(int status)
{
    if (status == EXIT_SUCCESS)
        exits(0);
    if (status == EXIT_FAILURE)
        exits("Failure");
    exits("Unknown exit code");
}

int setenv(const char *name, const char *value, int overwrite)
{
    return putenv(name, value);
}

int unsetenv(const char *name)
{
    char buf[128];
    snprint(buf, sizeof(buf), "/env/%s", name);
    if(strcmp(buf+5, name) != 0) {
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
        if(i == 0)
            return p;
        if(i > 0)
            bot = new + 1;
        else
            top = new - 1;
    }
    return 0;
}

int system(const char *command)
{
    return 0;
}

int gethostname(char *name, size_t len)
{
    int n, fd;
    char buf[128];

    fd = open("/dev/sysname", OREAD);
    if(fd < 0)
        return -1;
    n = read(fd, buf, sizeof(buf)-1);
    close(fd);
    if(n <= 0)
        return -1;
    buf[n] = 0;
    strncpy(name, buf, len);
    name[len-1] = 0;
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

int rename(const char *old, const char *new)
{
    struct Dir st;
    nulldir(&st);
    st.name = new;
    return dirwstat(old, &st);
}

int unlink(const char *path)
{
    return 0;
}

