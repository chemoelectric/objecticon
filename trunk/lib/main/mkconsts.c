#include "../../base/h/rt.h"

struct entry {
    char *name;
    char *origname;
    char *val;
    char *comment;
};

void add_entry(char *name, char *val, char *comment);

struct entry buff[400];
int n_entries;
char *abbr;
FILE *out = 0;
int tab_flag = 0;
int desc_flag = 0;

void start_file(char *name, char *pkg)
{
    if (out)
        fclose(out);

    out = fopen(name, "w");
    if (!out)
        exit(1);

    fprintf(out, "#\n# Auto generated by mkconsts - do not edit\n#\n\n");
    fprintf(out, "package %s\n\n", pkg);
}

void scan_file(char *path)
{
    FILE *f;
    char buff[128];
    if ((f = fopen(path, "r")) == NULL) {
        fprintf(stderr, "Couldn't open %s\n", path);
        exit(1);
    }
    while (fgets(buff, sizeof(buff), f)) {
        char *p;
        p = strtok(buff, " \t\r\n");
        if (p && strcmp(p, "#define") == 0) {
            char *key, *val;
            key = strtok(0, " \t\r\n");
            val = strtok(0, " \t\r\n");
            /*printf("key='%s' val='%s'\n",key,val);*/
            add_entry(strdup(key), strdup(val), 0);
        }
    }
    fclose(f);
}

void start_class(char *s, char *a, int t1, int t2)
{
    fprintf(out, "class %s()\n", s);
    abbr = a;
    n_entries = 0;
    tab_flag = t1;
    desc_flag = t2;
}

void end_class()
{
    int i;
    fprintf(out, "   public static const\n");
    for (i = 0; i < n_entries; ++i) {
        if (strcmp(buff[i].name, buff[i].origname) != 0)
            fprintf(out, "      # %s\n", buff[i].origname);
        if (i == n_entries - 1)
            fprintf(out, "      %s\n\n", buff[i].name);
        else
            fprintf(out, "      %s,\n", buff[i].name);
    }
    if (tab_flag) {
        fprintf(out, "   private static const\n      map\n\n");
    }
    if (desc_flag) {
        fprintf(out, "   private static const\n      desc\n\n");
    }

    fprintf(out, "   private static init()\n");
    for (i = 0; i < n_entries; ++i) {
        fprintf(out, "      %s := %s\n", buff[i].name, buff[i].val);
    }
    if (tab_flag) {
        fprintf(out, "      map := table()\n");
        for (i = 0; i < n_entries; ++i) {
            fprintf(out, "      map[%s] := \"%s\"\n", buff[i].val, buff[i].origname);
        }
    }
    if (desc_flag) {
        fprintf(out, "      desc := table()\n");
        for (i = 0; i < n_entries; ++i) {
            if (buff[i].comment)
                fprintf(out, "      desc[%s] := \"%s\"\n", buff[i].val, buff[i].comment);
        }
    }
    fprintf(out, "   end\n");
    if (tab_flag) {
        fprintf(out, "\n   public static get_sym(k)\n");
        fprintf(out, "      return .\\map[k]\n");
        fprintf(out, "   end\n");
    }
    if (desc_flag) {
        fprintf(out, "\n   public static get_desc(k)\n");
        fprintf(out, "      return .\\desc[k]\n");
        fprintf(out, "   end\n");
    }
    fprintf(out, "end\n\n");
}

void add_ientry(char *name, int val)
{
    char buff[32];
    sprintf(buff, "%d", val);
    add_entry(name, strdup(buff), 0);
}

void add_entry(char *name, char *val, char *comment)
{
    if (n_entries >= ElemCount(buff)) {
        fprintf(stderr, "mkconsts:Too many entries\n");
        exit(1);
    }
    buff[n_entries].origname = name;
    if (abbr && strncmp(name, abbr, strlen(abbr)) == 0)
        buff[n_entries].name = name + strlen(abbr); 
    else
        buff[n_entries].name = name;
    buff[n_entries].val = val; 
    buff[n_entries].comment = comment; 
    n_entries++;
}

void scan_monitor_h(char *path)
{
    FILE *f;
    char buff[128];
    if ((f = fopen(path, "r")) == NULL) {
        fprintf(stderr, "Couldn't open %s\n", path);
        exit(1);
    }
    while (fgets(buff, sizeof(buff), f)) {
        char *p;
        p = strtok(buff, " \t\r\n");
        if (p && strcmp(p, "#define") == 0) {
            char *key, *val, *comm;
            key = strtok(0, " \t\r\n");
            val = strtok(0, " \t\r\n");
            comm = val + strlen(val) + 1;
            while (isspace(*comm) || *comm == '/' || *comm == '*')
                ++comm;
            comm[strlen(comm) - 4] = 0;
            val[0] = val[strlen(val)-1] = '\"';
            add_entry(strdup(key), strdup(val), strdup(comm));
        }
    }
    fclose(f);
}

int main(void)
{
    start_file("posixconsts.icn", "posix");

    start_class("Errno", 0, 0, 0);

#define Const(x) add_ientry(#x,x);

#ifdef EPERM
    Const(EPERM)
#endif
#ifdef ENOENT
    Const(ENOENT)
#endif
#ifdef ESRCH
    Const(ESRCH)
#endif
#ifdef EINTR
    Const(EINTR)
#endif
#ifdef EIO
    Const(EIO)
#endif
#ifdef ENXIO
    Const(ENXIO)
#endif
#ifdef E2BIG
    Const(E2BIG)
#endif
#ifdef ENOEXEC
    Const(ENOEXEC)
#endif
#ifdef EBADF
    Const(EBADF)
#endif
#ifdef ECHILD
    Const(ECHILD)
#endif
#ifdef EAGAIN
    Const(EAGAIN)
#endif
#ifdef ENOMEM
    Const(ENOMEM)
#endif
#ifdef EACCES
    Const(EACCES)
#endif
#ifdef EFAULT
    Const(EFAULT)
#endif
#ifdef ENOTBLK
    Const(ENOTBLK)
#endif
#ifdef EBUSY
    Const(EBUSY)
#endif
#ifdef EEXIST
    Const(EEXIST)
#endif
#ifdef EXDEV
    Const(EXDEV)
#endif
#ifdef ENODEV
    Const(ENODEV)
#endif
#ifdef ENOTDIR
    Const(ENOTDIR)
#endif
#ifdef EISDIR
    Const(EISDIR)
#endif
#ifdef EINVAL
    Const(EINVAL)
#endif
#ifdef ENFILE
    Const(ENFILE)
#endif
#ifdef EMFILE
    Const(EMFILE)
#endif
#ifdef ENOTTY
    Const(ENOTTY)
#endif
#ifdef ETXTBSY
    Const(ETXTBSY)
#endif
#ifdef EFBIG
    Const(EFBIG)
#endif
#ifdef ENOSPC
    Const(ENOSPC)
#endif
#ifdef ESPIPE
    Const(ESPIPE)
#endif
#ifdef EROFS
    Const(EROFS)
#endif
#ifdef EMLINK
    Const(EMLINK)
#endif
#ifdef EPIPE
    Const(EPIPE)
#endif
#ifdef EDOM
    Const(EDOM)
#endif
#ifdef ERANGE
    Const(ERANGE)
#endif
#ifdef ENAMETOOLONG
    Const(ENAMETOOLONG)
#endif
#ifdef ENOLCK
    Const(ENOLCK)
#endif
#ifdef ENOSYS
    Const(ENOSYS)
#endif
#ifdef ENOTEMPTY
    Const(ENOTEMPTY)
#endif
#ifdef ELOOP
    Const(ELOOP)
#endif
#ifdef EWOULDBLOCK
    Const(EWOULDBLOCK)
#endif
#ifdef ENOMSG
    Const(ENOMSG)
#endif
#ifdef EIDRM
    Const(EIDRM)
#endif
#ifdef ECHRNG
    Const(ECHRNG)
#endif
#ifdef EL2NSYNC
    Const(EL2NSYNC)
#endif
#ifdef EL3HLT
    Const(EL3HLT)
#endif
#ifdef EL3RST
    Const(EL3RST)
#endif
#ifdef ELNRNG
    Const(ELNRNG)
#endif
#ifdef EUNATCH
    Const(EUNATCH)
#endif
#ifdef ENOCSI
    Const(ENOCSI)
#endif
#ifdef EL2HLT
    Const(EL2HLT)
#endif
#ifdef EBADE
    Const(EBADE)
#endif
#ifdef EBADR
    Const(EBADR)
#endif
#ifdef EXFULL
    Const(EXFULL)
#endif
#ifdef ENOANO
    Const(ENOANO)
#endif
#ifdef EBADRQC
    Const(EBADRQC)
#endif
#ifdef EBADSLT
    Const(EBADSLT)
#endif
#ifdef EDEADLOCK
    Const(EDEADLOCK)
#endif
#ifdef EDEADLK
    Const(EDEADLK)
#endif
#ifdef ENOSTR
    Const(ENOSTR)
#endif
#ifdef ENODATA
    Const(ENODATA)
#endif
#ifdef ETIME
    Const(ETIME)
#endif
#ifdef ENOSR
    Const(ENOSR)
#endif
#ifdef ENONET
    Const(ENONET)
#endif
#ifdef ENOPKG
    Const(ENOPKG)
#endif
#ifdef EREMOTE
    Const(EREMOTE)
#endif
#ifdef ENOLINK
    Const(ENOLINK)
#endif
#ifdef EADV
    Const(EADV)
#endif
#ifdef ESRMNT
    Const(ESRMNT)
#endif
#ifdef ECOMM
    Const(ECOMM)
#endif
#ifdef EPROTO
    Const(EPROTO)
#endif
#ifdef EMULTIHOP
    Const(EMULTIHOP)
#endif
#ifdef EDOTDOT
    Const(EDOTDOT)
#endif
#ifdef EBADMSG
    Const(EBADMSG)
#endif
#ifdef EOVERFLOW
    Const(EOVERFLOW)
#endif
#ifdef ENOTUNIQ
    Const(ENOTUNIQ)
#endif
#ifdef EBADFD
    Const(EBADFD)
#endif
#ifdef EREMCHG
    Const(EREMCHG)
#endif
#ifdef ELIBACC
    Const(ELIBACC)
#endif
#ifdef ELIBBAD
    Const(ELIBBAD)
#endif
#ifdef ELIBSCN
    Const(ELIBSCN)
#endif
#ifdef ELIBMAX
    Const(ELIBMAX)
#endif
#ifdef ELIBEXEC
    Const(ELIBEXEC)
#endif
#ifdef EILSEQ
    Const(EILSEQ)
#endif
#ifdef ERESTART
    Const(ERESTART)
#endif
#ifdef ESTRPIPE
    Const(ESTRPIPE)
#endif
#ifdef EUSERS
    Const(EUSERS)
#endif
#ifdef ENOTSOCK
    Const(ENOTSOCK)
#endif
#ifdef EDESTADDRREQ
    Const(EDESTADDRREQ)
#endif
#ifdef EMSGSIZE
    Const(EMSGSIZE)
#endif
#ifdef EPROTOTYPE
    Const(EPROTOTYPE)
#endif
#ifdef ENOPROTOOPT
    Const(ENOPROTOOPT)
#endif
#ifdef EPROTONOSUPPORT
    Const(EPROTONOSUPPORT)
#endif
#ifdef ESOCKTNOSUPPORT
    Const(ESOCKTNOSUPPORT)
#endif
#ifdef EOPNOTSUPP
    Const(EOPNOTSUPP)
#endif
#ifdef EPFNOSUPPORT
    Const(EPFNOSUPPORT)
#endif
#ifdef EAFNOSUPPORT
    Const(EAFNOSUPPORT)
#endif
#ifdef EADDRINUSE
    Const(EADDRINUSE)
#endif
#ifdef EADDRNOTAVAIL
    Const(EADDRNOTAVAIL)
#endif
#ifdef ENETDOWN
    Const(ENETDOWN)
#endif
#ifdef ENETUNREACH
    Const(ENETUNREACH)
#endif
#ifdef ENETRESET
    Const(ENETRESET)
#endif
#ifdef ECONNABORTED
    Const(ECONNABORTED)
#endif
#ifdef ECONNRESET
    Const(ECONNRESET)
#endif
#ifdef ENOBUFS
    Const(ENOBUFS)
#endif
#ifdef EISCONN
    Const(EISCONN)
#endif
#ifdef ENOTCONN
    Const(ENOTCONN)
#endif
#ifdef ESHUTDOWN
    Const(ESHUTDOWN)
#endif
#ifdef ETOOMANYREFS
    Const(ETOOMANYREFS)
#endif
#ifdef ETIMEDOUT
    Const(ETIMEDOUT)
#endif
#ifdef ECONNREFUSED
    Const(ECONNREFUSED)
#endif
#ifdef EHOSTDOWN
    Const(EHOSTDOWN)
#endif
#ifdef EHOSTUNREACH
    Const(EHOSTUNREACH)
#endif
#ifdef EALREADY
    Const(EALREADY)
#endif
#ifdef EINPROGRESS
    Const(EINPROGRESS)
#endif
#ifdef ESTALE
    Const(ESTALE)
#endif
#ifdef EUCLEAN
    Const(EUCLEAN)
#endif
#ifdef ENOTNAM
    Const(ENOTNAM)
#endif
#ifdef ENAVAIL
    Const(ENAVAIL)
#endif
#ifdef EISNAM
    Const(EISNAM)
#endif
#ifdef EREMOTEIO
    Const(EREMOTEIO)
#endif
#ifdef EDQUOT
    Const(EDQUOT)
#endif
#ifdef ENOMEDIUM
    Const(ENOMEDIUM)
#endif
#ifdef EMEDIUMTYPE
    Const(EMEDIUMTYPE)
#endif
#ifdef ECANCELED
    Const(ECANCELED)
#endif
#ifdef ENOKEY
    Const(ENOKEY)
#endif
#ifdef EKEYEXPIRED
    Const(EKEYEXPIRED)
#endif
#ifdef EKEYREVOKED
    Const(EKEYREVOKED)
#endif
#ifdef EKEYREJECTED
    Const(EKEYREJECTED)
#endif

    end_class();

    start_class("Signal",0, 0, 0);

#ifdef SIGHUP 
        Const(SIGHUP)
#endif
#ifdef SIGINT 
        Const(SIGINT)
#endif
#ifdef SIGQUIT 
        Const(SIGQUIT)
#endif
#ifdef SIGILL 
        Const(SIGILL)
#endif
#ifdef SIGTRAP 
        Const(SIGTRAP)
#endif
#ifdef SIGABRT 
        Const(SIGABRT)
#endif
#ifdef SIGIOT 
        Const(SIGIOT)
#endif
#ifdef SIGBUS 
        Const(SIGBUS)
#endif
#ifdef SIGFPE 
        Const(SIGFPE)
#endif
#ifdef SIGKILL 
        Const(SIGKILL)
#endif
#ifdef SIGUSR1 
        Const(SIGUSR1)
#endif
#ifdef SIGSEGV 
        Const(SIGSEGV)
#endif
#ifdef SIGUSR2 
        Const(SIGUSR2)
#endif
#ifdef SIGPIPE 
        Const(SIGPIPE)
#endif
#ifdef SIGALRM 
        Const(SIGALRM)
#endif
#ifdef SIGTERM 
        Const(SIGTERM)
#endif
#ifdef SIGSTKFLT 
        Const(SIGSTKFLT)
#endif
#ifdef SIGCLD 
        Const(SIGCLD)
#endif
#ifdef SIGCHLD 
        Const(SIGCHLD)
#endif
#ifdef SIGCONT 
        Const(SIGCONT)
#endif
#ifdef SIGSTOP 
        Const(SIGSTOP)
#endif
#ifdef SIGTSTP 
        Const(SIGTSTP)
#endif
#ifdef SIGTTIN 
        Const(SIGTTIN)
#endif
#ifdef SIGTTOU 
        Const(SIGTTOU)
#endif
#ifdef SIGURG 
        Const(SIGURG)
#endif
#ifdef SIGXCPU 
        Const(SIGXCPU)
#endif
#ifdef SIGXFSZ 
        Const(SIGXFSZ)
#endif
#ifdef SIGVTALRM 
        Const(SIGVTALRM)
#endif
#ifdef SIGPROF 
        Const(SIGPROF)
#endif
#ifdef SIGWINCH 
        Const(SIGWINCH)
#endif
#ifdef SIGPOLL 
        Const(SIGPOLL)
#endif
#ifdef SIGIO 
        Const(SIGIO)
#endif
#ifdef SIGPWR 
        Const(SIGPWR)
#endif
#ifdef SIGSYS 
        Const(SIGSYS)
#endif
#ifdef SIGUNUSED 
        Const(SIGUNUSED)
#endif

    end_class();

    start_class("WaitOpt", 0, 0, 0);
#ifdef WNOHANG
    Const(WNOHANG)
#endif
#ifdef WUNTRACED
        Const(WUNTRACED)
#endif
#ifdef WCONTINUED
        Const(WCONTINUED)
#endif
    end_class();

    start_file("ioconsts.icn", "io");

    start_class("FileOpt", "O_", 0, 0);

#ifdef O_ACCMODE
        Const(O_ACCMODE)
#endif
#ifdef O_RDONLY
        Const(O_RDONLY)
#endif
#ifdef O_WRONLY
        Const(O_WRONLY)
#endif
#ifdef O_RDWR
        Const(O_RDWR)
#endif
#ifdef O_CREAT
        Const(O_CREAT)
#endif
#ifdef O_EXCL
        Const(O_EXCL)
#endif
#ifdef O_NOCTTY
        Const(O_NOCTTY)
#endif
#ifdef O_TRUNC
        Const(O_TRUNC)
#endif
#ifdef O_APPEND
        Const(O_APPEND)
#endif
#ifdef O_NONBLOCK
        Const(O_NONBLOCK)
#endif
#ifdef O_NDELAY
        Const(O_NDELAY)
#endif
#ifdef O_SYNC
        Const(O_SYNC)
#endif
#ifdef O_FSYNC
        Const(O_FSYNC)
#endif
#ifdef O_ASYNC
        Const(O_ASYNC)
#endif
#ifdef O_DIRECT
        Const(O_DIRECT)
#endif
#ifdef O_DIRECTORY
        Const(O_DIRECTORY)
#endif
#ifdef O_NOFOLLOW
        Const(O_NOFOLLOW)
#endif
#ifdef O_NOATIME
        Const(O_NOATIME)
#endif
#ifdef O_DSYNC
        Const(O_DSYNC)
#endif
#ifdef O_RSYNC
        Const(O_RSYNC)
#endif
#ifdef O_LARGEFILE
        Const(O_LARGEFILE)
#endif

    end_class();
        start_class("Mode", "S_", 0, 0);

#ifdef S_IFMT
        Const(S_IFMT)
#endif
#ifdef S_IFSOCK
        Const(S_IFSOCK)
#endif
#ifdef S_IFLNK
        Const(S_IFLNK)
#endif
#ifdef S_IFREG
        Const(S_IFREG)
#endif
#ifdef S_IFBLK
        Const(S_IFBLK)
#endif
#ifdef S_IFDIR
        Const(S_IFDIR)
#endif
#ifdef S_IFCHR
        Const(S_IFCHR)
#endif
#ifdef S_IFIFO
        Const(S_IFIFO)
#endif
#ifdef S_ISUID
        Const(S_ISUID)
#endif
#ifdef S_ISGID
        Const(S_ISGID)
#endif
#ifdef S_ISVTX
        Const(S_ISVTX)
#endif

#ifdef S_IRUSR
        Const(S_IRUSR)
#endif
#ifdef S_IWUSR
        Const(S_IWUSR)
#endif
#ifdef S_IXUSR
        Const(S_IXUSR)
#endif
#ifdef S_IRWXU
        Const(S_IRWXU)
#endif
#ifdef S_IREAD
        Const(S_IREAD)
#endif
#ifdef S_IWRITE
        Const(S_IWRITE)
#endif
#ifdef S_IEXEC
        Const(S_IEXEC)
#endif
#ifdef S_IRGRP
        Const(S_IRGRP)
#endif
#ifdef S_IWGRP
        Const(S_IWGRP)
#endif
#ifdef S_IXGRP
        Const(S_IXGRP)
#endif
#ifdef S_IRWXG
        Const(S_IRWXG)
#endif
#ifdef S_IROTH
        Const(S_IROTH)
#endif
#ifdef S_IWOTH
        Const(S_IWOTH)
#endif
#ifdef S_IXOTH
        Const(S_IXOTH)
#endif
#ifdef S_IRWXO
        Const(S_IRWXO)
#endif

    end_class();
        start_class("ProtocolFormat", "PF_", 0, 0);

#ifdef PF_UNSPEC
        Const(PF_UNSPEC)
#endif
#ifdef PF_LOCAL
        Const(PF_LOCAL)
#endif
#ifdef PF_UNIX
        Const(PF_UNIX)
#endif
#ifdef PF_FILE
        Const(PF_FILE)
#endif
#ifdef PF_INET
        Const(PF_INET)
#endif
#ifdef PF_AX25
        Const(PF_AX25)
#endif
#ifdef PF_IPX
        Const(PF_IPX)
#endif
#ifdef PF_APPLETALK
        Const(PF_APPLETALK)
#endif
#ifdef PF_NETROM
        Const(PF_NETROM)
#endif
#ifdef PF_BRIDGE
        Const(PF_BRIDGE)
#endif
#ifdef PF_ATMPVC
        Const(PF_ATMPVC)
#endif
#ifdef PF_X25
        Const(PF_X25)
#endif
#ifdef PF_INET6
        Const(PF_INET6)
#endif
#ifdef PF_ROSE
        Const(PF_ROSE)
#endif
#ifdef PF_DECnet
        Const(PF_DECnet)
#endif
#ifdef PF_NETBEUI
        Const(PF_NETBEUI)
#endif
#ifdef PF_SECURITY
        Const(PF_SECURITY)
#endif
#ifdef PF_KEY
        Const(PF_KEY)
#endif
#ifdef PF_NETLINK
        Const(PF_NETLINK)
#endif
#ifdef PF_ROUTE
        Const(PF_ROUTE)
#endif
#ifdef PF_PACKET
        Const(PF_PACKET)
#endif
#ifdef PF_ASH
        Const(PF_ASH)
#endif
#ifdef PF_ECONET
        Const(PF_ECONET)
#endif
#ifdef PF_ATMSVC
        Const(PF_ATMSVC)
#endif
#ifdef PF_SNA
        Const(PF_SNA)
#endif
#ifdef PF_IRDA
        Const(PF_IRDA)
#endif
#ifdef PF_PPPOX
        Const(PF_PPPOX)
#endif
#ifdef PF_WANPIPE
        Const(PF_WANPIPE)
#endif
#ifdef PF_BLUETOOTH
        Const(PF_BLUETOOTH)
#endif
#ifdef PF_MAX
        Const(PF_MAX)
#endif

    end_class();
        start_class("AddressFormat", "AF_", 0, 0);

#ifdef AF_UNSPEC
        Const(AF_UNSPEC)
#endif
#ifdef AF_LOCAL
        Const(AF_LOCAL)
#endif
#ifdef AF_UNIX
        Const(AF_UNIX)
#endif
#ifdef AF_FILE
        Const(AF_FILE)
#endif
#ifdef AF_INET
        Const(AF_INET)
#endif
#ifdef AF_AX25
        Const(AF_AX25)
#endif
#ifdef AF_IPX
        Const(AF_IPX)
#endif
#ifdef AF_APPLETALK
        Const(AF_APPLETALK)
#endif
#ifdef AF_NETROM
        Const(AF_NETROM)
#endif
#ifdef AF_BRIDGE
        Const(AF_BRIDGE)
#endif
#ifdef AF_ATMPVC
        Const(AF_ATMPVC)
#endif
#ifdef AF_X25
        Const(AF_X25)
#endif
#ifdef AF_INET6
        Const(AF_INET6)
#endif
#ifdef AF_ROSE
        Const(AF_ROSE)
#endif
#ifdef AF_DECnet
        Const(AF_DECnet)
#endif
#ifdef AF_NETBEUI
        Const(AF_NETBEUI)
#endif
#ifdef AF_SECURITY
        Const(AF_SECURITY)
#endif
#ifdef AF_KEY
        Const(AF_KEY)
#endif
#ifdef AF_NETLINK
        Const(AF_NETLINK)
#endif
#ifdef AF_ROUTE
        Const(AF_ROUTE)
#endif
#ifdef AF_PACKET
        Const(AF_PACKET)
#endif
#ifdef AF_ASH
        Const(AF_ASH)
#endif
#ifdef AF_ECONET
        Const(AF_ECONET)
#endif
#ifdef AF_ATMSVC
        Const(AF_ATMSVC)
#endif
#ifdef AF_SNA
        Const(AF_SNA)
#endif
#ifdef AF_IRDA
        Const(AF_IRDA)
#endif
#ifdef AF_PPPOX
        Const(AF_PPPOX)
#endif
#ifdef AF_WANPIPE
        Const(AF_WANPIPE)
#endif
#ifdef AF_BLUETOOTH
        Const(AF_BLUETOOTH)
#endif
#ifdef AF_MAX
        Const(AF_MAX)
#endif

    end_class();
        start_class("SocketType", "SOCK_", 0, 0);

#ifdef SOCK_STREAM
        Const(SOCK_STREAM)
#endif

#ifdef SOCK_DGRAM
        Const(SOCK_DGRAM)
#endif

#ifdef SOCK_SEQPACKET
        Const(SOCK_SEQPACKET)
#endif

#ifdef SOCK_RAW
        Const(SOCK_RAW)
#endif

#ifdef SOCK_RDM
        Const(SOCK_RDM)
#endif

#ifdef SOCK_PACKET
        Const(SOCK_PACKET)
#endif

    end_class();
        start_class("Lock", "LOCK_", 0, 0);

#ifdef LOCK_SH
        Const(LOCK_SH)
#endif
#ifdef LOCK_EX
        Const(LOCK_EX)
#endif
#ifdef LOCK_UN
        Const(LOCK_UN)
#endif
#ifdef LOCK_NB
        Const(LOCK_NB)
#endif

    end_class();
        start_class("Poll","POLL", 0, 0);

#ifdef POLLIN
Const(POLLIN)
#endif
#ifdef POLLPRI
Const(POLLPRI)
#endif
#ifdef POLLOUT
Const(POLLOUT)
#endif
#ifdef POLLERR
Const(POLLERR)
#endif
#ifdef POLLHUP
Const(POLLHUP)
#endif
#ifdef POLLNVAL
Const(POLLNVAL)
#endif
#ifdef POLLRDNORM
Const(POLLRDNORM)
#endif
#ifdef POLLRDBAND
Const(POLLRDBAND)
#endif
#ifdef POLLWRNORM
Const(POLLWRNORM)
#endif
#ifdef POLLWRBAND
Const(POLLWRBAND)
#endif
#ifdef POLLMSG
Const(POLLMSG)
#endif

    end_class();
start_class("Access", 0, 0, 0);

#ifdef R_OK
        Const(R_OK)
#endif
#ifdef W_OK
        Const(W_OK)
#endif
#ifdef X_OK
        Const(X_OK)
#endif
#ifdef F_OK
        Const(F_OK)
#endif


    end_class();
        start_class("Seek", "SEEK_", 0, 0);

Const(SEEK_SET)
Const(SEEK_CUR)
Const(SEEK_END)

    end_class();

    start_file("ucodeconsts.icn", "lang");
    start_class("UcodeOp", "Uop_", 1, 0);
    scan_file("../../base/oit/ucode.h");
    end_class();

    start_file("evmonconsts.icn", "lang");

    start_class("OpCode", "Op_", 1, 0);
    scan_file("../../base/h/opdefs.h");
    end_class();

    start_class("MonitorCode", "E_", 1, 1);
    scan_monitor_h("../../base/h/monitor.h");
    end_class();

    start_class("TypeCode", "T_", 1, 0);
    Const(T_String)
        Const(T_Null)
        Const(T_Integer)
        Const(T_Lrgint)
        Const(T_Real)
        Const(T_Cset)
        Const(T_Constructor)
        Const(T_Proc)
        Const(T_Record)
        Const(T_List)
        Const(T_Lelem)
        Const(T_Set)
        Const(T_Selem)
        Const(T_Table)
        Const(T_Telem)
        Const(T_Tvtbl)
        Const(T_Slots)
        Const(T_Tvsubs)
        Const(T_Refresh)
        Const(T_Coexpr)
        Const(T_Ucs)
        Const(T_Kywdint)
        Const(T_Kywdpos)
        Const(T_Kywdsubj)
        Const(T_Kywdstr)
        Const(T_Kywdevent)
        Const(T_Class)
        Const(T_Object)
        Const(T_Cast)
        Const(T_Methp)
    end_class();

    fclose(out);
    exit(0);
}
