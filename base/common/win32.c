#include "../h/gsupport.h"

int mkstemp(char *path)
{
    return _open(_mktemp(path), _O_CREAT | _O_TRUNC | _O_WRONLY |_O_BINARY, _S_IREAD | _S_IWRITE);
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
