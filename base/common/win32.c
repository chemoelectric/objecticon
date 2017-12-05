#include "../h/gsupport.h"

int mkstemp(char *path)
{
    return _open(_mktemp(path), _O_CREAT | _O_TRUNC | _O_WRONLY |_O_BINARY, _S_IREAD | _S_IWRITE);
}

int gettimeofday(struct timeval *tv, struct timezone *tz)
{
    struct _timeb wtp;
    _ftime( &wtp );
    tv->tv_sec = wtp.time;
    tv->tv_usec = wtp.millitm * 1000;
    return 0;
}

WCHAR *utf8_to_wchar(char *s)
{
    WCHAR *mbs;
    int n;
    n = MultiByteToWideChar(CP_UTF8,
                            0,
                            s,
                            -1,
                            0,
                            0);
    mbs = safe_malloc(n * sizeof(WCHAR));
    MultiByteToWideChar(CP_UTF8,
                        0,
                        s,
                        -1,
                        mbs,
                        n);
    return mbs;
}

char *wchar_to_utf8(WCHAR *s)
{
    char *u;
    int n;
    n = WideCharToMultiByte(CP_UTF8,
                            0,
                            s,
                            -1,
                            0,
                            0,
                            NULL,
                            NULL);
    u = safe_malloc(n);
    WideCharToMultiByte(CP_UTF8,
                        0,
                        s,
                        -1,
                        u,
                        n,
                        NULL,
                        NULL);
    return u;
}

int stat_utf8(char *path, struct stat *st)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wstat(wpath, (struct _stat *)st);
    free(wpath);
    return v;
}

int stat64_utf8(char *path, struct _stat64 *st)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wstat64(wpath, st);
    free(wpath);
    return v;
}

int open_utf8(char *path, int oflag, int pmode)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wopen(wpath, oflag, pmode);
    free(wpath);
    return v;
}

int rename_utf8(char *path1, char *path2)
{
    WCHAR *wpath1, *wpath2;
    int v;
    wpath1 = utf8_to_wchar(path1);
    wpath2 = utf8_to_wchar(path2);
    v = _wrename(wpath1, wpath2);
    free(wpath1);
    free(wpath2);
    return v;
}

int mkdir_utf8(char *path)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wmkdir(wpath);
    free(wpath);
    return v;
}

int remove_utf8(char *path)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wremove(wpath);
    free(wpath);
    return v;
}

int rmdir_utf8(char *path)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wrmdir(wpath);
    free(wpath);
    return v;
}

int access_utf8(char *path, int mode)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _waccess(wpath, mode);
    free(wpath);
    return v;
}

int chdir_utf8(char *path)
{
    WCHAR *wpath;
    int v;
    wpath = utf8_to_wchar(path);
    v = _wchdir(wpath);
    free(wpath);
    return v;
}

char *getcwd_utf8(char *buff, int maxlen)
{
    WCHAR *t;
    char *u;
    t = _wgetcwd(NULL, 32);
    if (!t)
        return NULL;
    u = wchar_to_utf8(t);
    free(t);
    if (!buff)
        return u;
    if (strlen(u) + 1 > maxlen) {
        free(u);
        errno = ERANGE;
        return NULL;
    }
    strcpy(buff, u);
    free(u);
    return buff;
}

char *getenv_utf8(char *var)
{
    DWORD n;
    WCHAR *wvar, *wbuff;
    char *res;
    static struct staticstr buf = {128};
    wvar = utf8_to_wchar(var);
    n = GetEnvironmentVariableW(wvar, NULL, 0);
    if (n == 0) {
        free(wvar);
        return NULL;
    }
    ++n;
    wbuff = safe_zalloc(n * sizeof(WCHAR));
    GetEnvironmentVariableW(wvar, wbuff, n);
    free(wvar);
    res = wchar_to_utf8(wbuff);
    free(wbuff);
    sscpy(&buf, res);
    free(res);
    return buf.s;
}

int setenv_utf8(char *var, char *value)
{
    WCHAR *wvar, *wvalue;
    BOOL res;
    wvar = utf8_to_wchar(var);
    if (value)
        wvalue = utf8_to_wchar(value);
    else
        wvalue = NULL;
    res = SetEnvironmentVariableW(wvar, wvalue);
    free(wvar);
    free(wvalue);
    return res ? 0 : -1;
}

FILE *fopen_utf8(char *path, char *mode)
{
    WCHAR *wpath, *wmode;
    FILE *res;
    wpath = utf8_to_wchar(path);
    wmode = utf8_to_wchar(mode);
    res = _wfopen(wpath, wmode);
    free(wpath);
    free(wmode);
    return res;
}

int wmain(int argc, WCHAR *wargv[])
{
    char **argv;
    int i;
    argv = safe_malloc((argc + 1) * sizeof(char *));
    for (i = 0; i < argc; ++i)
        argv[i] = wchar_to_utf8(wargv[i]);
    argv[argc] = 0;
    return main(argc, argv);
}
