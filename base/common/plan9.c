#include "../h/gsupport.h"

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

int execv(const char *path, char *const argv[])
{
    return exec(path, argv);
}

int rename(const char *old, const char *new)
{
    return 0;
}

int unlink(const char *path)
{
    return 0;
}

