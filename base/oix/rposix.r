
/*
 * Copyright 1997-2001 Shamim Mohamed.
 *
 * Modification and redistribution is permitted as long as this (and any
 * other) copyright notices are kept intact. If you make any changes,
 * please add a short note here with your name and what changes were
 * made.
 *
 * $Id: rposix.r,v 1.29 2005/06/24 09:13:44 jeffery Exp $
 */


#include "../h/opdefs.h"

/* Signal definitions */ 
#passthru #if !defined(SIGABRT) 
#passthru #define SIGABRT 0 
#passthru #endif 
#passthru #if !defined(SIGALRM) 
#passthru #define SIGALRM 0 
#passthru #endif 
#passthru #if !defined(SIGBREAK) 
#passthru #define SIGBREAK 0 
#passthru #endif 
#passthru #if !defined(SIGBUS) 
#passthru #define SIGBUS 0 
#passthru #endif 
#passthru #if !defined(SIGCHLD) 
#passthru #define SIGCHLD 0 
#passthru #endif 
#passthru #if !defined(SIGCLD) 
#passthru #define SIGCLD 0 
#passthru #endif 
#passthru #if !defined(SIGCONT) 
#passthru #define SIGCONT 0 
#passthru #endif 
#passthru #if !defined(SIGEMT) 
#passthru #define SIGEMT 0 
#passthru #endif 
#passthru #if !defined(SIGFPE) 
#passthru #define SIGFPE 0 
#passthru #endif 
#passthru #if !defined(SIGFREEZE) 
#passthru #define SIGFREEZE 0 
#passthru #endif 
#passthru #if !defined(SIGHUP) 
#passthru #define SIGHUP 0 
#passthru #endif 
#passthru #if !defined(SIGILL) 
#passthru #define SIGILL 0 
#passthru #endif 
#passthru #if !defined(SIGINT) 
#passthru #define SIGINT 0 
#passthru #endif 
#passthru #if !defined(SIGIO) 
#passthru #define SIGIO 0 
#passthru #endif 
#passthru #if !defined(SIGIOT) 
#passthru #define SIGIOT 0 
#passthru #endif 
#passthru #if !defined(SIGKILL) 
#passthru #define SIGKILL 0 
#passthru #endif 
#passthru #if !defined(SIGLOST) 
#passthru #define SIGLOST 0 
#passthru #endif 
#passthru #if !defined(SIGLWP) 
#passthru #define SIGLWP 0 
#passthru #endif 
#passthru #if !defined(SIGPIPE) 
#passthru #define SIGPIPE 0 
#passthru #endif 
#passthru #if !defined(SIGPOLL) 
#passthru #define SIGPOLL 0 
#passthru #endif 
#passthru #if !defined(SIGPROF) 
#passthru #define SIGPROF 0 
#passthru #endif 
#passthru #if !defined(SIGPWR) 
#passthru #define SIGPWR 0 
#passthru #endif 
#passthru #if !defined(SIGQUIT) 
#passthru #define SIGQUIT 0 
#passthru #endif 
#passthru #if !defined(SIGSEGV) 
#passthru #define SIGSEGV 0 
#passthru #endif 
#passthru #if !defined(SIGSTOP) 
#passthru #define SIGSTOP 0 
#passthru #endif 
#passthru #if !defined(SIGSYS) 
#passthru #define SIGSYS 0 
#passthru #endif 
#passthru #if !defined(SIGTERM) 
#passthru #define SIGTERM 0 
#passthru #endif 
#passthru #if !defined(SIGTHAW) 
#passthru #define SIGTHAW 0 
#passthru #endif 
#passthru #if !defined(SIGTRAP) 
#passthru #define SIGTRAP 0 
#passthru #endif 
#passthru #if !defined(SIGTSTP) 
#passthru #define SIGTSTP 0 
#passthru #endif 
#passthru #if !defined(SIGTTIN) 
#passthru #define SIGTTIN 0 
#passthru #endif 
#passthru #if !defined(SIGTTOU) 
#passthru #define SIGTTOU 0 
#passthru #endif 
#passthru #if !defined(SIGURG) 
#passthru #define SIGURG 0 
#passthru #endif 
#passthru #if !defined(SIGUSR1) 
#passthru #define SIGUSR1 0 
#passthru #endif 
#passthru #if !defined(SIGUSR2) 
#passthru #define SIGUSR2 0 
#passthru #endif 
#passthru #if !defined(SIGVTALRM) 
#passthru #define SIGVTALRM 0 
#passthru #endif 
#passthru #if !defined(SIGWAITING) 
#passthru #define SIGWAITING 0 
#passthru #endif 
#passthru #if !defined(SIGWINCH) 
#passthru #define SIGWINCH 0 
#passthru #endif 
#passthru #if !defined(SIGXCPU) 
#passthru #define SIGXCPU 0 
#passthru #endif 
#passthru #if !defined(SIGXFSZ) 
#passthru #define SIGXFSZ 0 
#passthru #endif 

#if MSWIN32
WORD wVersionRequested = MAKEWORD( 2, 0 );
WSADATA wsaData;
int werr;
int WINSOCK_INITIAL=0;
#define fileno _fileno
#endif					/* MSWIN32 */



int get_uid(name)
char *name;
{
#if MSWIN32
   return -1;
#else					/* MSWIN32 */
   struct passwd *pw;
   if (!(pw = getpwnam(name)))
      return -1;
   return pw->pw_uid;
#endif					/* MSWIN32 */
}

int get_gid(name)
char *name;
{
#if MSWIN32
   return -1;
#else					/* MSWIN32 */
   struct group *gr;
   if (!(gr = getgrnam(name)))
      return -1;
   return gr->gr_gid;
#endif					/* MSWIN32 */
}

static int newmode(mode, oldmode)
char *mode;
int oldmode;
{
   int i;
   
   /* The pattern is [ugoa]*[+-=][rwxRWXstugo]* */
   int which = 0, do_umask;
   char *p = mode, *q, op;
   char *fields = "ogua";
   int retmode = oldmode & 07777;

   /* Special case: if mode is of the pattern rwxrwxrwx (with some dashes)
    * then it's ok too.
    *
    * A little extra hook: if there's a leading -ldcb|s i.e. it came
    * directly from stat(), then we allow that.
    */
   do {
      char allperms[10];
      int cmode;
      int highbits = 0;
      int mlen;

      mlen = strlen(mode);
      if (mlen != 9 && (mlen != 10 || !strchr("-ldcb|s", mode[0])))
	 break;

      if (mlen == 10)
	 /* We know there's a leading char we're not interested in */
         mode++;

      strcpy(allperms, "rwxrwxrwx");

      if (mode[2] == 's' || mode[2] == 'S') {
          highbits |= 1;
          if (mode[2] == 's')
              mode[2] = 'x';
          else
              mode[2] = '-';
      }
      highbits <<= 1;
      if (mode[5] == 's' || mode[5] == 'S') {
          highbits |= 1;
          if (mode[5] == 's')
              mode[5] = 'x';
          else
              mode[5] = '-';
      }
      highbits <<= 1;
      if (mode[8] == 't' || mode[8] == 'T') {
          highbits |= 1;
          if (mode[8] == 't')
              mode[8] = 'x';
          else
              mode[8] = '-';
      }

      cmode = 0;
      for(i = 0; i < 9; i++) {
	 cmode = cmode << 1;
	 if (mode[i] == '-') {
	    cmode |= 1;
	 } else if (mode[i] != allperms[i]) {
	    cmode = -1;
	    break;
	 }
      }
      if (cmode < 0)
	 break;
      cmode |= highbits << 9;
      return cmode;
   } while(0);

   while ((q = strchr(fields, *p))) {
      if (!*p)
	 return -2;
      if (*p == 'a')
	 which = 7;
      else
	 which |= 1 << (q - fields);
      p++;
   }
   if (!strchr("+=-", *p))
      return -2;

   if ((do_umask = (which == 0)))
      which = 7;
      
   op = *p++;

   /* We have: which field(s) in "which", an operator in "op" */

   if (op == '=') {
      for(i = 0; i < 3; i++)
	if (which & (1 << i)) {
	    retmode &= ~(7 << i*3);
	    retmode &= ~(1 << i + 9);
	}
      op = '+';
   }

   while (*p) {
      int value = 0;
      switch (*p++) {
      case 'r': value = 4; break;
      case 'w': value = 2; break;
      case 'x': value = 1; break;
      case 'R': if (oldmode & 0444) value = 4; break;
      case 'W': if (oldmode & 0222) value = 2; break;
      case 'X': if (oldmode & 0111) value = 1; break;
      case 'u': value = (oldmode & 0700) >> 6; break;
      case 'g': value = (oldmode & 0070) >> 3; break;
      case 'o': value = oldmode & 0007; break;
      case 's':
	 if (which & 4)
	    value = 04000;
	 if (which & 2)
	    value |= 02000;
	 retmode |= value;
	 continue;
      case 't':
	 if (which & 1)
	    retmode |= 01000;
	 continue;
      default:
	 return -2;
      }

      for(i = 0; i < 3; i++) {
	 int nvalue;
	 if (which & (1 << i)) {
	    if (do_umask) {
#if MSWIN32
	       int u = _umask(0);
	       _umask(u);
#else					/* MSWIN32 */
	       int u = umask(0);
	       umask(u);
#endif					/* MSWIN32 */	
	       nvalue = value & ~u;
	    } else
	       nvalue = value;
	    switch (op) {
	    case '-': retmode &= ~nvalue; break;
	    case '+': retmode |= nvalue; break;
	    }
	 }
	 value = (value << 3);
      }
   }

   if (*p)
     /* Extra chars */
      return -2;

   return retmode;
}


int getmodefd(fd, mode)
int fd;
char *mode;
{
   struct stat st;
   if (fstat(fd, &st) < 0)
      return -1;
   return newmode(mode, st.st_mode);
}

int getmodenam(path, mode)
char *path;
char *mode;
{
   struct stat st;
   if (path) {
     if (stat(path, &st) < 0)
        return -1;
     return newmode(mode, st.st_mode);
   } else
     return newmode(mode, 0);
}



/*
 * Create a record of type posix_struct
 * (defined in posix.icn because it's too painful for iconc if we
 * add a new record type here) and initialise the fields with the
 * fields from the struct stat.  Because this allocates memory that
 * may trigger a garbage collection, the pointer parameters dp and rp
 * should point at tended variables.
 */
void stat2rec(st, dp, rp)
#if MSWIN32
struct _stat *st;
#else					/* MSWIN32 */
struct stat *st;
#endif					/* MSWIN32 */
struct descrip *dp;
struct b_record **rp;
{
   int i;
   char mode[12], *user, *group;
   struct passwd *pw;
   struct group *gr;

   dp->dword = D_Record;
   dp->vword.bptr = (union block *)(*rp);

   for (i = 0; i < 13; i++)
     (*rp)->fields[i].dword = D_Integer;

   IntVal((*rp)->fields[0]) = (int)st->st_dev;
   IntVal((*rp)->fields[1]) = (int)st->st_ino;
   IntVal((*rp)->fields[3]) = (int)st->st_nlink;
   IntVal((*rp)->fields[6]) = (int)st->st_rdev;
   IntVal((*rp)->fields[7]) = (int)st->st_size;
   IntVal((*rp)->fields[8]) = (int)st->st_atime;
   IntVal((*rp)->fields[9]) = (int)st->st_mtime;
   IntVal((*rp)->fields[10]) = (int)st->st_ctime;
#if MSWIN32
   IntVal((*rp)->fields[11]) = (int)0;
   IntVal((*rp)->fields[12]) = (int)0;
#else
   IntVal((*rp)->fields[11]) = (int)st->st_blksize;
   IntVal((*rp)->fields[12]) = (int)st->st_blocks;
#endif

   (*rp)->fields[13] = nulldesc;

   strcpy(mode, "----------");
#if MSWIN32
   if (st->st_mode & _S_IFREG) mode[0] = '-';
   else if (st->st_mode & _S_IFDIR) mode[0] = 'd';
   else if (st->st_mode & _S_IFCHR) mode[0] = 'c';
   else if (st->st_mode & _S_IFMT) mode[0] = 'm';

   if (st->st_mode & S_IREAD) mode[1] = mode[4] = mode[7] = 'r';
   if (st->st_mode & S_IWRITE) mode[2] = mode[5] = mode[8] = 'w';
   if (st->st_mode & S_IEXEC) mode[3] = mode[6] = mode[9] = 'x';
#else					/* MSWIN32 */
   if (S_ISLNK(st->st_mode)) mode[0] = 'l';
   else if (S_ISREG(st->st_mode)) mode[0] = '-';
   else if (S_ISDIR(st->st_mode)) mode[0] = 'd';
   else if (S_ISCHR(st->st_mode)) mode[0] = 'c';
   else if (S_ISBLK(st->st_mode)) mode[0] = 'b';
   else if (S_ISFIFO(st->st_mode)) mode[0] = '|';
   else if (S_ISSOCK(st->st_mode)) mode[0] = 's';

   if (S_IRUSR & st->st_mode) mode[1] = 'r';
   if (S_IWUSR & st->st_mode) mode[2] = 'w';
   if (S_IXUSR & st->st_mode) mode[3] = 'x';
   if (S_IRGRP & st->st_mode) mode[4] = 'r';
   if (S_IWGRP & st->st_mode) mode[5] = 'w';
   if (S_IXGRP & st->st_mode) mode[6] = 'x';
   if (S_IROTH & st->st_mode) mode[7] = 'r';
   if (S_IWOTH & st->st_mode) mode[8] = 'w';
   if (S_IXOTH & st->st_mode) mode[9] = 'x';

   if (S_ISUID & st->st_mode) mode[3] = (mode[3] == 'x') ? 's' : 'S';
   if (S_ISGID & st->st_mode) mode[6] = (mode[6] == 'x') ? 's' : 'S';
   if (S_ISVTX & st->st_mode) mode[9] = (mode[9] == 'x') ? 't' : 'T';
#endif					/* MSWIN32 */

   StrLoc((*rp)->fields[2]) = alcstr(mode, 10);
   StrLen((*rp)->fields[2]) = 10;

#if MSWIN32
   (*rp)->fields[4] = (*rp)->fields[5] = emptystr;
#else					/* MSWIN32 */
   pw = getpwuid(st->st_uid);
   if (!pw) {
      sprintf(mode, "%d", st->st_uid);
      user = mode;
   } else
      user = pw->pw_name;
   StrLoc((*rp)->fields[4]) = alcstr(user, strlen(user));
   StrLen((*rp)->fields[4]) = strlen(user);
   
   gr = getgrgid(st->st_gid);
   if (!gr) {
      sprintf(mode, "%d", st->st_gid);
      group = mode;
   } else
      group = gr->gr_name;
   StrLoc((*rp)->fields[5]) = alcstr(group, strlen(group));
   StrLen((*rp)->fields[5]) = strlen(group);
#endif					/* MSWIN32 */

}

struct descrip posix_lock = {D_Null};
struct descrip posix_timeval = {D_Null};
struct descrip posix_stat = {D_Null};
struct descrip posix_message = {D_Null};
struct descrip posix_passwd = {D_Null};
struct descrip posix_group = {D_Null};
struct descrip posix_servent = {D_Null};
struct descrip posix_hostent = {D_Null};

dptr rec_structor(name)
char *name;
{
   int i;
   struct descrip s;
   struct descrip fields[14];

   if (!strcmp(name, "posix_lock")) {
      if (is:null(posix_lock)) {
          MakeCStr("posix_lock", &s);
          MakeCStr("value", &fields[0]);
          MakeCStr("pid", &fields[1]);
          posix_lock.dword = D_Constructor;
          posix_lock.vword.bptr = (union block *)dynrecord(&s, fields, 2);
	 }
      return &posix_lock;
      }
   else if (!strcmp(name, "posix_message")) {
      if (is:null(posix_message)) {
          MakeCStr("posix_message", &s);
          MakeCStr("addr", &fields[0]);
          MakeCStr("msg", &fields[1]);
          posix_message.dword = D_Constructor;
          posix_message.vword.bptr = (union block *)dynrecord(&s, fields, 2);
	 }
      return &posix_message;
      }
   else if (!strcmp(name, "posix_servent")) {
      if (is:null(posix_servent)) {
          MakeCStr("posix_servent", &s);
          MakeCStr("name", &fields[0]);
          MakeCStr("aliases", &fields[1]);
          MakeCStr("port", &fields[2]);
          MakeCStr("proto", &fields[3]);
          posix_servent.dword = D_Constructor;
          posix_servent.vword.bptr = (union block *)dynrecord(&s, fields, 4);
	 }
      return &posix_servent;
      }
   else if (!strcmp(name, "posix_hostent")) {
      if (is:null(posix_hostent)) {
          MakeCStr("posix_hostent", &s);
          MakeCStr("name", &fields[0]);
          MakeCStr("aliases", &fields[1]);
          MakeCStr("addresses", &fields[2]);
          posix_hostent.dword = D_Constructor;
          posix_hostent.vword.bptr = (union block *)dynrecord(&s, fields, 3);
	 }
      return &posix_hostent;
      }
   else if (!strcmp(name, "posix_timeval")) {
      if (is:null(posix_timeval)) {
          MakeCStr("posix_timeval", &s);
          MakeCStr("sec", &fields[0]);
          MakeCStr("usec", &fields[1]);
          posix_timeval.dword = D_Constructor;
          posix_timeval.vword.bptr = (union block *)dynrecord(&s, fields, 2);
	 }
      return &posix_timeval;
      }
   else if (!strcmp(name, "posix_group")) {
      if (is:null(posix_group)) {
          MakeCStr("posix_group", &s);
          MakeCStr("name", &fields[0]);
          MakeCStr("passwd", &fields[1]);
          MakeCStr("gid", &fields[2]);
          MakeCStr("members", &fields[3]);
          posix_group.dword = D_Constructor;
          posix_group.vword.bptr = (union block *)dynrecord(&s, fields, 4);
	 }
      return &posix_group;
      }
   else if (!strcmp(name, "posix_passwd")) {
      if (is:null(posix_passwd)) {
          MakeCStr("posix_passwd", &s);
          MakeCStr("name", &fields[0]);
          MakeCStr("passwd", &fields[1]);
          MakeCStr("uid", &fields[2]);
          MakeCStr("gid", &fields[3]);
          MakeCStr("gecos", &fields[4]);
          MakeCStr("dir", &fields[5]);
          MakeCStr("shell", &fields[6]);
          posix_passwd.dword = D_Constructor;
          posix_passwd.vword.bptr = (union block *)dynrecord(&s, fields, 7);
	 }
      return &posix_passwd;
      }
   else if (!strcmp(name, "posix_stat")) {
      if (is:null(posix_stat)) {
          MakeCStr("posix_stat", &s);
          MakeCStr("dev", &fields[0]);
          MakeCStr("ino", &fields[1]);
          MakeCStr("mode", &fields[2]);
          MakeCStr("nlink", &fields[3]);
          MakeCStr("uid", &fields[4]);
          MakeCStr("gid", &fields[5]);
          MakeCStr("rdev", &fields[6]);
          MakeCStr("size", &fields[7]);
          MakeCStr("atime", &fields[8]);
          MakeCStr("mtime", &fields[9]);
          MakeCStr("ctime", &fields[10]);
          MakeCStr("blksize", &fields[11]);
          MakeCStr("blocks", &fields[12]);
          MakeCStr("symlink", &fields[13]);
          posix_stat.dword = D_Constructor;
          posix_stat.vword.bptr = (union block *)dynrecord(&s, fields, 14);
	 }
      return &posix_stat;
      }

   /*
    * called rec_structor on something else ?! try globals...
    */
   StrLoc(s) = name;
   StrLen(s) = strlen(name);
   for (i = 0; i < n_globals; ++i)
      if (eq(&s, &gnames[i]))
         if (is:constructor(globals[i]))
            return &globals[i];
         else
	    return 0;

   return 0;
}


#if !MSWIN32
dptr make_pwd(pw, result)
struct passwd *pw;
dptr result;
{
   tended struct b_record *rp;
   dptr constr;

   if (!(constr = rec_structor("posix_passwd")))
      return 0;

   rp = alcrecd(&BlkLoc(*constr)->constructor);

   result->dword = D_Record;
   result->vword.bptr = (union block *)rp;
   rp->fields[0] = cstr2string(pw->pw_name);
   rp->fields[1] = cstr2string(pw->pw_passwd);
   rp->fields[2].dword = rp->fields[3].dword = D_Integer;
   IntVal(rp->fields[2]) = pw->pw_uid;
   IntVal(rp->fields[3]) = pw->pw_gid;
   rp->fields[4] = cstr2string(pw->pw_gecos);
   rp->fields[5] = cstr2string(pw->pw_dir);
   rp->fields[6] = cstr2string(pw->pw_shell);
   return result;
}
#endif					/* !MSWIN32 */

#if !MSWIN32
dptr make_group(gr, result)
struct group *gr;
dptr result;
{
   tended struct b_record *rp;
   dptr constr;

   if (!(constr = rec_structor("posix_group")))
      return 0;

   rp = alcrecd(&BlkLoc(*constr)->constructor);

   result->dword = D_Record;
   result->vword.bptr = (union block *)rp;
   rp->fields[0] = cstr2string(gr->gr_name);
   rp->fields[1] = cstr2string(gr->gr_passwd);
   rp->fields[2].dword = D_Integer;
   IntVal(rp->fields[2]) = gr->gr_gid;
   rp->fields[3] = cstrs2string(gr->gr_mem, ",");
   return result;
}
#endif					/* !MSWIN32 */

dptr make_serv(s, result)
struct servent *s;
dptr result;
{
   tended struct b_record *rp;
   dptr constr;
   int nmem = 0, i, n;

   if (!(constr = rec_structor("posix_servent")))
      return 0;

   rp = alcrecd(&BlkLoc(*constr)->constructor);

   result->dword = D_Record;
   result->vword.bptr = (union block *)rp;

   rp->fields[0] = cstr2string(s->s_name);
   rp->fields[1] = cstrs2string(s->s_aliases, ",");
   rp->fields[2].dword = D_Integer;
   IntVal(rp->fields[2]) = ntohs((short)s->s_port);
   rp->fields[3] = cstr2string(s->s_proto);

   return result;
}

dptr make_host(hs, result)
struct hostent *hs;
 dptr result;
{
   tended struct b_record *rp;
   dptr constr;
   int nmem = 0, i, n;
   unsigned int *addr;
   char *p;

   if (!(constr = rec_structor("posix_hostent")))
     return 0;

   rp = alcrecd(&BlkLoc(*constr)->constructor);

   result->dword = D_Record;
   result->vword.bptr = (union block *)rp;

   rp->fields[0] = cstr2string(hs->h_name);
   rp->fields[1] = cstrs2string(hs->h_aliases, ",");

   while (hs->h_addr_list[nmem])
      nmem++;

   StrLoc(rp->fields[2]) = p = alcstr(NULL, nmem*16);
   
   addr = (unsigned int *) hs->h_addr_list[0];
   for (i = 0; i < nmem; i++) {
      int a = ntohl(*addr);
      sprintf(p, "%d.%d.%d.%d,", (a & 0xff000000) >> 24,
	      (a & 0xff0000) >> 16, (a & 0xff00)>>8, a & 0xff);
      while(*p) p++;
      addr++;
   }
   *--p = 0;

   StrLen(rp->fields[2]) = DiffPtrs(p,StrLoc(rp->fields[2]));
   n = DiffPtrs(p,strfree);             /* note the deallocation */
   EVStrAlc(n);
   strtotal += n;
   strfree = p;                         /* give back unused space */

   return result;
}

/*
 * Signals and trapping
 */

/* Systems don't have more than, oh, about 50 signals, eh? */
static struct descrip handlers[50];
static int inited = 0;

struct descrip register_sig(sig, handler)
int sig;
struct descrip handler;
{
   struct descrip old;
   if (!inited) {
      int i;
      for(i = 0; i < 50; i++)
	 handlers[i] = nulldesc;
      inited = 1;
   }

   old = handlers[sig];
   handlers[sig] = handler;
   return old;
}

void signal_dispatcher(sig)
int sig;
{
   struct descrip proc, p;

   if (!inited) {
      int i;
      for(i = 0; i < 50; i++)
	 handlers[i] = nulldesc;
      inited = 1;
   }

   proc = handlers[sig];

   if (is:null(proc))
      return;

   /* Invoke proc */
   MakeInt(sig, &p);
   call_icon(&proc, &p, 0);
   
   /* Restore signal just in case (for non-BSD systems) */
   signal(sig, signal_dispatcher);
}


void dup_fds(dptr d_stdin, dptr d_stdout, dptr d_stderr)
{
   if (is:file(*d_stdin)) {
       dup2(file_fd(&BlkLoc(*d_stdin)->file), 0);
   }
   if (is:file(*d_stdout)) {
       dup2(file_fd(&BlkLoc(*d_stdout)->file), 1);
   }
   if (is:file(*d_stderr)) {
       dup2(file_fd(&BlkLoc(*d_stderr)->file), 2);
   }
}


