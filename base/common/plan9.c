#include "../h/gsupport.h"

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
    int pid;
    if ((pid = rfork(RFPROC|RFFDG)) < 0)
        return -1;
    if (pid == 0) {
        execl("/bin/rc", "rc", "-c", command, 0);
        exits("execl returned in system()");
        return -1;
    }
    for (;;) {
        Waitmsg *w = wait();
        if (!w)
            return -1;
        if (w->pid == pid) {
            int rc = (w->msg[0] == 0 ? 0 : 1);
            free(w);
            return rc;
        }
        free(w);
    }
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

