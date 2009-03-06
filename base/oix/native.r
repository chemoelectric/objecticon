#include "../h/modflags.h"

static struct descrip stat2list(struct stat *st);

/*
 * Helper method to get a class from a descriptor; if a class
 * descriptor then obviously the block is returned; if an object then
 * the object's class is returned.
 */
static struct b_class *get_class_for(dptr x)
{
    type_case *x of {
      class: 
            return &BlkLoc(*x)->class;
        
      object: 
            return BlkLoc(*x)->object.class;
        
     default: 
            return 0;
        
    }
}

function{1} classof(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       return class(BlkLoc(o)->object.class);
    }
end

function{1} progof(x)
   body {
      struct progstate *p = 0;
      type_case x of {
         constructor:
            p = BlkLoc(x)->constructor.program;
         record: 
            p = BlkLoc(x)->record.constructor->program;
         class:
            p = BlkLoc(x)->class.program;
         object:
            p = BlkLoc(x)->object.class->program;
         proc:
            p = BlkLoc(x)->proc.program;
         default: 
            runerr(123, x);
      }
      if (!p)
         fail;
      return p->K_main;
   }
end

/*
 * Evaluate whether target is an implemented class of class.
 */
int class_is(struct b_class *class, struct b_class *target)
{
    int l, r, m, c;

    /* 
     * Different programs never share classes
     */
    if (class->program != target->program)
        return 0;

    l = 0;
    r = class->n_implemented_classes - 1;
    while (l <= r) {
        m = (l + r) / 2;
        /* c = class->implemented_classes[m]->class_id - target->class_id; */
        c = (char *)class->implemented_classes[m] - (char *)target;
        if (c > 0)
            r = m - 1;
        else if (c < 0)
            l = m + 1;
        else
            return 1;
    }
    return 0;
}


function{0,1} is(o, target)
   if !is:class(target) then
       runerr(603, target)
    body {
        if (is:object(o) && class_is(BlkLoc(o)->object.class, &BlkLoc(target)->class))
            return target;
        else
            fail;
    }
end

function{0,1} glob(s, c)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;

       if (is:null(c))
           prog = curpstate;
       else if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           runerr(118, c);
           
       p = lookup_global(&s, prog);
       if (p) {
           result.dword = D_Var;
           VarLoc(result) = p;
           return result;
       } else
           fail;
   }
end

function{*} lang_Class_get_supers(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_supers; ++i)
            suspend class(class->supers[i]);
        fail;
    }
end

function{*} lang_Class_get_implemented_classes(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_implemented_classes; ++i)
            suspend class(class->implemented_classes[i]);
        fail;
    }
end

function{0,1} lang_Class_implements(c, target)
   if !is:class(target) then
       runerr(603, target)
    body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        if (class_is(class, &BlkLoc(target)->class))
            return target;
        else
            fail;
    }
end

function{1} lang_Class_get_methp_object(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
       return object(BlkLoc(mp)->methp.object);
    }
end

function{1} lang_Class_get_methp_proc(mp)
   if !is:methp(mp) then
       runerr(613, mp)
    body {
        return proc(BlkLoc(mp)->methp.proc);
    }
end

function{1} lang_Class_get_cast_object(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return object(BlkLoc(c)->cast.object);
    }
end

function{1} lang_Class_get_cast_class(c)
   if !is:cast(c) then
       runerr(614, c)
    body {
       return class(BlkLoc(c)->cast.class);
    }
end

function{1} lang_Class_get_field_flags(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return C_integer class->fields[i]->flags;
     }
end

function{1} lang_Class_get_class_flags(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->flags;
     }
end

function{0,1} lang_Class_get_field_index(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return C_integer i + 1;
     }
end

function{0,1} lang_Class_get_field_name(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return class->fields[i]->name;
     }
end

function{0,1} lang_Class_get_field_defining_class(c, field)
   body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            fail;
        return class(class->fields[i]->defining_class);
     }
end

function{1} lang_Class_get_n_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->n_instance_fields + class->n_class_fields;
     }
end

function{1} lang_Class_get_n_class_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->n_class_fields;
     }
end

function{1} lang_Class_get_n_instance_fields(c)
   body {
        struct b_class *class;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        return C_integer class->n_instance_fields;
     }
end

function{*} lang_Class_get_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_instance_fields + class->n_class_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_instance_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = 0; i < class->n_instance_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

function{*} lang_Class_get_class_field_names(c)
    body {
        struct b_class *class;
        int i;
        if (!(class = get_class_for(&c)))
            runerr(619, c);
        for (i = class->n_instance_fields; 
             i < class->n_instance_fields + class->n_class_fields; ++i)
            suspend class->fields[i]->name;
        fail;
    }
end

#include "../h/opdefs.h"

function{1} lang_Class_get(obj, field)
   body {
       struct descrip res;
       int rc;
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc == Error) 
           runerr(0, obj);
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{0,1} lang_Class_getf(obj, field, quiet)
   body {
       struct descrip res;
       int rc;
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc == Error) {
           if (is:null(quiet))
               whyf("%s (error %d)", lookup_err_msg(t_errornumber), t_errornumber);
           fail;
       }
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{1} lang_Class_set_method(field, pr)
   body {
        dptr pp = (dptr)pfp - (pfp->pf_nargs + 1);
        struct b_proc *caller_proc, *new_proc;
        struct b_class *class;
        struct class_field *cf;
        int i;

        if (pp->dword != D_Proc) {
            showstack();
            syserr("couldn't find proc on stack");
        }
        if (!is:proc(pr))
            runerr(615, pr);

        caller_proc = &BlkLoc(*pp)->proc;
        if (!caller_proc->field)
            runerr(616);
        class = caller_proc->field->defining_class;

        i = lookup_class_field(class, &field, 0);
        if (i < 0)
            runerr(207, field);
        cf = class->fields[i];

        if (cf->defining_class != class)
            runerr(616);

        if (!(cf->flags & M_Method))
            runerr(617, field);

        new_proc = &BlkLoc(pr)->proc;
        if (new_proc->field)
            runerr(618, pr);

        if (BlkLoc(*cf->field_descriptor) != (union block *)&Bdeferred_method_stub)
            runerr(623, field);

        BlkLoc(*cf->field_descriptor) = (union block *)new_proc;

        return pr;
   }
end

static struct b_proc *try_load(void *handle, struct b_class *class,  struct class_field *cf)
{
    int i;
    char *fq, *p, *t;
    struct b_proc *blk;

    MemProtect(fq = malloc(StrLen(class->name) + StrLen(cf->name) + 3));
    p = fq;
    *p++ = 'B';
    t = StrLoc(class->name);
    for (i = 0; i < StrLen(class->name); ++i)
        *p++ = (t[i] == '.') ? '_' : t[i];
    *p++ = '_';
    strncpy(p, StrLoc(cf->name), StrLen(cf->name));
    p[StrLen(cf->name)] = 0;

    blk = (struct b_proc *)dlsym(handle, fq);
    if (!blk) {
        free(fq);
        return 0;
    }

    /* Sanity check. */
    if (blk->title != T_Proc) {
        fprintf(stderr, "\nlang.Class.load_library() - symbol %s not a procedure block\n", fq);
        fatalerr(218, NULL);
    }

    free(fq);

    return blk;
}

function{1} lang_Class_load_library(lib)
   if !cnv:C_string(lib) then
      runerr(103, lib)
   body {
        dptr pp = (dptr)pfp - (pfp->pf_nargs + 1);
        struct b_proc *caller_proc, *new_proc;
        struct b_class *class;
        struct class_field *cf;
        int i;
        void *handle;

        if (pp->dword != D_Proc) {
            showstack();
            syserr("couldn't find proc on stack");
        }
        caller_proc = &BlkLoc(*pp)->proc;
        if (!caller_proc->field)
            runerr(616);
        class = caller_proc->field->defining_class;

        handle = dlopen(lib, RTLD_LAZY);
        if (!handle) {
            why(dlerror());
            fail;
        }

        for (i = 0; i < class->n_instance_fields + class->n_class_fields; ++i) {
            struct class_field *cf = class->fields[i];
            if ((cf->defining_class == class) &&
                (cf->flags & M_Method) &&
                BlkLoc(*cf->field_descriptor) == (union block *)&Bdeferred_method_stub) {
                struct b_proc *bp = try_load(handle, class, cf);
                if (bp)
                    BlkLoc(*cf->field_descriptor) = (union block *)bp;
            }
        }

        return nulldesc;
   }
end

function{0,1} lang_Class_for_name(s, c)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;

       if (is:null(c))
           prog = curpstate;
       else if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           runerr(118, c);

       p = lookup_global(&s, prog);
       if (p && is:class(*p))
           return *p;
       else
           fail;
   }
end

function{1} lang_Class_create_raw(c)
   if !is:class(c) then
       runerr(603, c)
    body {
        struct b_object *obj;
        struct b_class *class = &BlkLoc(c)->class;
        ensure_initialized(class);
        MemProtect(obj = alcobject(class));
        obj->init_state = Initializing;
        return object(obj);
    }
end

function{0} lang_Class_complete_raw(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       BlkLoc(o)->object.init_state = Initialized;
       fail;
    }
end

function{1} lang_Class_ensure_initialized(c)
   if !is:class(c) then
       runerr(603, c)
    body {
        struct b_class *class = &BlkLoc(c)->class;
        ensure_initialized(class);
        return c;
   }
end

function{1} parser_UReader_raw_convert(s)
   if !is:string(s) then
      runerr(103, s)
   body {
       char *p = StrLoc(s);
       if (StrLen(s) == 2) {
           union {
               unsigned char c[2];
               unsigned int s:16;
           } i;
           i.c[0] = p[0];
           i.c[1] = p[1];
           return C_integer i.s;
       }
       if (StrLen(s) == 4) {
           union {
               unsigned char c[4];
               unsigned long int w:32;
           } i;
           i.c[0] = p[0];
           i.c[1] = p[1];
           i.c[2] = p[2];
           i.c[3] = p[3];
           return C_integer i.w;
       }
       fail;
   }
end

#if MSWIN32
function{*} io_WindowsFileSystem_get_roots()
    body {
        DWORD n = GetLogicalDrives();
        char t[4], c = 'A';
	strcpy(t, "?:\\");
        while (n) {
	   if (n & 1) {
	      t[0] = c;
	      cstr2string(t, &result);
              suspend result;
	   }
	   n /= 2;
	   ++c;
	}
        fail;
    }
end

function{0,1} io_WindowsFilePath_getdcwd(d)
   if !cnv:tmp_string(d) then
      runerr(103, d)
   body {
      char *p;
      int dir;
      if (StrLen(d) != 1)
	 fail;
      dir = toupper(*StrLoc(d)) - 'A' + 1;
      p = _getdcwd(dir, 0, 32);
      if (!p)
	 fail;
      cstr2string(p, &result);
      free(p);
      return result;
   }
end

#endif

static struct sdescrip fdf = {2, "fd"};
static struct sdescrip eof_flagf = {8, "eof_flag"};
static struct sdescrip dsclassname = {13, "io.DescStream"};

#begdef GetSelfEofFlag()
dptr self_eof_flag;
static struct inline_field_cache self_eof_flag_ic;
self_eof_flag = c_get_instance_data(&self, (dptr)&eof_flagf, &self_eof_flag_ic);
if (!self_eof_flag)
   syserr("Missing eof_flag field");
#enddef

#begdef FdStaticParam(p, m)
int m;
dptr m##_dptr;
static struct inline_field_cache m##_ic;
static struct inline_global_cache m##_igc;
if (!c_is(&p, (dptr)&dsclassname, &m##_igc))
    runerr(205, p);
m##_dptr = c_get_instance_data(&p, (dptr)&fdf, &m##_ic);
if (!m##_dptr)
    syserr("Missing fd field");
(m) = IntVal(*m##_dptr);
if (m < 0)
    runerr(219, p);
#enddef

#begdef GetSelfFd()
int self_fd;
dptr self_fd_dptr;
static struct inline_field_cache self_fd_ic;
self_fd_dptr = c_get_instance_data(&self, (dptr)&fdf, &self_fd_ic);
if (!self_fd_dptr)
    syserr("Missing fd field");
self_fd = IntVal(*self_fd_dptr);
if (self_fd < 0)
    runerr(219, self);
#enddef

function{0,1} io_FileStream_open_impl(path, flags, mode)
   if !cnv:C_string(path) then
      runerr(103, path)

   if !cnv:C_integer(flags) then
      runerr(101, flags)

   if !def:C_integer(mode, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH) then
      runerr(101, mode)

   body {
       int fd;

       fd = open(path, flags, mode);
       if (fd < 0) {
           errno2why();
           fail;
       }

       return C_integer fd;
   }
end

function{0,1} io_FileStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = read(self_fd, StrLoc(s), i);
       if (nread <= 0) {
           GetSelfEofFlag();

           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {  /* nread == 0 */
               *self_eof_flag = onedesc;
               why("End of file");
           }
           fail;
       }

       StrLen(s) = nread;
       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(StrLoc(s) + nread);

       return s;
   }
end

function{0,1} io_FileStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       GetSelfFd();
       if ((rc = write(self_fd, StrLoc(s), StrLen(s))) < 0) {
           errno2why();
           fail;
       }
       return C_integer rc;
   }
end

function{0,1} io_FileStream_close(self)
   body {
       GetSelfFd();
       if (close(self_fd) < 0) {
           errno2why();
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return nulldesc;
   }
end

function{0,1} io_FileStream_truncate(self, len)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
       GetSelfFd();
       if (lseek(self_fd, len, SEEK_SET) < 0) {
           errno2why();
           fail;
       }

       if (ftruncate(self_fd, len) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_FileStream_stat_impl(self)
   body {
       struct stat st;
       GetSelfFd();
       if (fstat(self_fd, &st) < 0) {
           errno2why();
           fail;
       }
       return stat2list(&st);
   }
end

function{0,1} io_FileStream_seek(self, offset)
   if !cnv:C_integer(offset) then
      runerr(101, offset)
   body {
       int whence, rc;
       GetSelfFd();
       if (offset > 0) {
           --offset;
           whence = SEEK_SET;
       } else
           whence = SEEK_END;
       if ((rc = lseek(self_fd, offset, whence)) < 0) {
           errno2why();
           fail;
       }
       return C_integer(rc + 1);
   }
end

function{0,1} io_FileStream_tell(self)
   body {
       int rc;
       GetSelfFd();
       if ((rc = lseek(self_fd, 0, SEEK_CUR)) < 0) {
           errno2why();
           fail;
       }
       return C_integer(rc + 1);
   }
end

function{0,1} io_FileStream_pipe_impl()
   body {
       int fds[2];
       struct descrip t;

       if (pipe(fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      c_put(&result, &t);

      MakeInt(fds[1], &t);
      c_put(&result, &t);

      return result;
   }
end

function{0,1} io_SocketStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;
       GetSelfFd();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       MemProtect(StrLoc(s) = alcstr(NULL, i));

       nread = recv(self_fd, StrLoc(s), i, 0);
       if (nread <= 0) {
           GetSelfEofFlag();

           /* Reset the memory just allocated */
           dealcstr(StrLoc(s));

           if (nread < 0) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {  /* nread == 0 */
               *self_eof_flag = onedesc;
               why("End of file");
           }
           fail;
       }

       StrLen(s) = nread;

       /*
        * We may not have used the entire amount of storage we reserved.
        */
       dealcstr(StrLoc(s) + nread);

       return s;
   }
end

function{0,1} io_SocketStream_socket_impl(domain, typ)
   if !def:C_integer(domain, PF_INET) then
      runerr(101, domain)

   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       SOCKET sockfd;
       struct descrip fname;
       sockfd = socket(domain, typ, 0);
       if (sockfd < 0) {
           errno2why();
           fail;
       }
       return C_integer sockfd;
   }
end

function{0,1} io_SocketStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       GetSelfFd();
       /* 
        * If possible use MSG_NOSIGNAL so that we get the EPIPE error
        * code, rather than the SIGPIPE signal.
        */
#ifdef HAVE_MSG_NOSIGNAL
       rc = send(self_fd, StrLoc(s), StrLen(s), MSG_NOSIGNAL);
#else
       rc = send(self_fd, StrLoc(s), StrLen(s), 0);
#endif
       if (rc < 0) {
           errno2why();
           fail;
       }
       return C_integer rc;
   }
end

function{0,1} io_SocketStream_close(self)
   body {
       GetSelfFd();
       if (close(self_fd) < 0) {
           errno2why();
           fail;
       }
       *self_fd_dptr = minusonedesc;
       return nulldesc;
   }
end

function{0,1} io_SocketStream_socketpair_impl(typ)
   if !def:C_integer(typ, SOCK_STREAM) then
      runerr(101, typ)

   body {
       int fds[2];
       struct descrip t;

       if (socketpair(AF_UNIX, typ, 0, fds) < 0) {
           errno2why();
           fail;
       }

       create_list(2, &result);

      MakeInt(fds[0], &t);
      c_put(&result, &t);

      MakeInt(fds[1], &t);
      c_put(&result, &t);

      return result;
   }
end

struct sockaddr *parse_sockaddr(char *s, int *len)
{
    if (strncmp(s, "unix:", 5) == 0) {
        static struct sockaddr_un us;
        char *t = s + 5;
        if (strlen(t) >= sizeof(us.sun_path)) {
            why("Name too long");
            return 0;
        }
        us.sun_family = AF_UNIX;
        strcpy(us.sun_path, t);
        *len = sizeof(us.sun_family) + strlen(us.sun_path);
        return (struct sockaddr *)&us;
    } 

    if (strncmp(s, "inet:", 5) == 0) {
        static struct sockaddr_in iss;
        char *t = s + 5, host[128], *p;
        int port;
        struct hostent *hp;

        if (strlen(t) >= sizeof(host)) {
            why("Name too long");
            return 0;
        }
        strcpy(host, t);
        p = strchr(host, ':');
        if (!p) {
            why("Bad socket address format");
            return 0;
        }
        *p++ = 0;
        port = atoi(p);
        iss.sin_family = AF_INET;
        iss.sin_port = htons((u_short)port);
        if (strcmp(host, "INADDR_ANY") == 0)
            iss.sin_addr.s_addr = INADDR_ANY;
        else {
            if ((hp = gethostbyname(host)) == NULL) {
                switch (h_errno) {
                    case HOST_NOT_FOUND: why("Name lookup failure: host not found"); break;
                    case NO_DATA: why("Name lookup failure: no IP address for host") ; break;
                    case NO_RECOVERY: why("Name lookup failure: name server error") ; break;
                    case TRY_AGAIN: why("Name lookup failure: temporary name server error") ; break;
                    default: why("Name lookup failure") ; break;
                }
                return 0;
            }
            memcpy(&iss.sin_addr, hp->h_addr, hp->h_length);
        }
        *len = sizeof(iss);
        return (struct sockaddr *)&iss;
    }

    why("Bad socket address format");
    return 0;
}

function{0,1} io_SocketStream_connect(self, addr)
   if !cnv:C_string(addr) then
      runerr(103, addr)
   body {
       struct sockaddr *sa;
       int len;
       GetSelfFd();

       sa = parse_sockaddr(addr, &len);
       if (!sa) {
           /* &why already set by parse_sockaddr */
           fail;
       }

       if (connect(self_fd, sa, len) < 0) {
           errno2why();
           fail;
       }

       return nulldesc;
   }
end

function{0,1} io_SocketStream_bind(self, addr)
   if !cnv:string(addr) then
      runerr(103, addr)

   body {
       tended char *addrstr;
       struct sockaddr *sa;
       int len;
       GetSelfFd();

       /*
        * get a C string for the address.
        */
       if (!cnv:C_string(addr, addrstr))
           runerr(103, addr);

       sa = parse_sockaddr(addrstr, &len);
       if (!sa) {
           /* &why already set by parse_sockaddr */
           fail;
       }

       if (bind(self_fd, sa, len) < 0) {
           errno2why();
           fail;
       }

       return nulldesc;
   }
end

function{0,1} io_SocketStream_listen(self, backlog)
   if !cnv:C_integer(backlog) then
      runerr(101, backlog)

   body {
       GetSelfFd();
       if (listen(self_fd, backlog) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_SocketStream_accept_impl(self)
   body {
       SOCKET sockfd;
       GetSelfFd();

       if ((sockfd = accept(self_fd, 0, 0)) < 0) {
           errno2why();
           fail;
       }

       return C_integer sockfd;
   }
end

/*
 * These two are macros since they call runerr (so does FdStaticParam).
 */

#begdef list2fd_set(l, tmpl, s)
{
    tended struct descrip e;

    FD_ZERO(&s);
    if (!is:null(l)) {
        if (!is:list(l))
            runerr(108, l);
        create_list(BlkLoc(l)->list.size, &tmpl);
        while (c_get(&BlkLoc(l)->list, &e)) {
            FdStaticParam(e, fd);
            c_put(&tmpl, &e);
            FD_SET(fd, &s);
        }
    }
}
#enddef

#begdef fd_set2list(l, tmpl, s)
{
    tended struct descrip e;

    if (!is:null(l)) {
        while (c_get(&BlkLoc(tmpl)->list, &e)) {
            FdStaticParam(e, fd);
            if (FD_ISSET(fd, &s)) {
                c_put(&l, &e);
                ++count;
            }
        }
    }
}
#enddef

function{0,1} io_DescStream_select(rl, wl, el, timeout)
    body {
       fd_set rset, wset, eset;
       struct timeval tv, *ptv;
       tended struct descrip rtmp, wtmp, etmp;
       int rc, count;

       list2fd_set(rl, rtmp, rset);
       list2fd_set(wl, wtmp, wset);
       list2fd_set(el, etmp, eset);

       if (is:null(timeout))
           ptv = 0;
       else {
           C_integer t;
           if (!cnv:C_integer(timeout, t))
               runerr(101, timeout);
           tv.tv_sec = t / 1000;
           tv.tv_usec = (t % 1000) * 1000;
           ptv = &tv;
       }

       rc = select(FD_SETSIZE, &rset, &wset, &eset, ptv);
       if (rc < 0) {
           errno2why();
           fail;
       }
       /* A rc of zero means timeout */
       if (rc == 0) {
           why("Timeout");
           fail;
       }

       count = 0;
       fd_set2list(rl, rtmp, rset);
       fd_set2list(wl, wtmp, wset);
       fd_set2list(el, etmp, eset);

       if (count != rc) {
           why("Unexpected mismatch between FD_SETs and list sizes");
           fail;
       }

       return C_integer rc;
    }
end

function{0,1} io_DescStream_poll(a[n])
   body {
#ifdef HAVE_POLL
       static struct pollfd *ufds = 0;
       unsigned int nfds;
       int timeout, i, rc;

       nfds = n / 2;
       if (n % 2 == 0 || is:null(a[n - 1]))
           timeout = -1;
       else if (!cnv:C_integer(a[n - 1], timeout))
           runerr(101, a[n - 1]);

       MemProtect(ufds = realloc(ufds, nfds * sizeof(struct pollfd)));

       for (i = 0; i < nfds; ++i) {
           int events;
           FdStaticParam(a[2 * i], fd);
           if (!cnv:C_integer(a[2 * i + 1], events))
               runerr(101, a[2 * i + 1]);
           ufds[i].fd = fd;
           ufds[i].events = events;
       }

       rc = poll(ufds, nfds, timeout);
       if (rc < 0) {
           errno2why();
           fail;
       }
       /* A rc of zero means timeout */
       if (rc == 0) {
           why("Timeout");
           fail;
       }

       create_list(nfds, &result);
       for (i = 0; i < nfds; ++i) {
           struct descrip tmp;
           MakeInt(ufds[i].revents, &tmp);
           c_put(&result, &tmp);
       }

       return result;
#else
       runerr(121);
#endif  /* HAVE_POLL */
   }
end

function{0,1} io_DescStream_flag(self, on, off)
    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
        int i;
        GetSelfFd();

        if ((i = fcntl(self_fd, F_GETFL, 0)) < 0) {
           errno2why();
           fail;
        }
        if (on || off) {
            i = (i | on) & (~off);
            if (fcntl(self_fd, F_SETFL, i) < 0) {
                errno2why();
                fail;
            }
        }

        return C_integer i;
    }
end

static struct sdescrip ddf = {2, "dd"};

#begdef GetSelfDir()
DIR *self_dir;
dptr self_dir_dptr;
static struct inline_field_cache self_dir_ic;
self_dir_dptr = c_get_instance_data(&self, (dptr)&ddf, &self_dir_ic);
if (!self_dir_dptr)
    syserr("Missing dd field");
self_dir = (DIR*)IntVal(*self_dir_dptr);
if (!self_dir)
    runerr(219, self);
#enddef

function{0,1} io_DirStream_open_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       DIR *dd = opendir(path);
       if (!dd) {
           errno2why();
           fail;
       }
       return C_integer((long int)dd);
   }
end

function{0,1} io_DirStream_read_impl(self)
   body {
       struct dirent *de;
       GetSelfDir();
       errno = 0;
       de = readdir(self_dir);
       if (!de) {
           GetSelfEofFlag();
           if (errno) {
               *self_eof_flag = nulldesc;
               errno2why();
           } else {
               *self_eof_flag = onedesc;
               why("End of file");
           }
           fail;
       }
       cstr2string(de->d_name, &result);
       return result;
   }
end

function{0,1} io_DirStream_close(self)
   body {
       GetSelfDir();
       if ((closedir(self_dir)) < 0) {
           errno2why();
           fail;
       }
       *self_dir_dptr = zerodesc;
       return nulldesc;
   }
end

static struct sdescrip pidf = {3, "pid"};

function{0,1} io_ProgStream_open_impl(cmd, flags)
   if !cnv:C_string(cmd) then
      runerr(103, cmd)
   if !cnv:C_integer(flags) then
      runerr(101, flags)
   body {
       int pid, fd[2];

       if (flags != O_RDONLY && flags != O_WRONLY) {
           irunerr(205, flags);
           errorfail;
       }

       if ((pipe(fd) < 0)) {
           errno2why();
           fail;
       }

       if ((pid = fork()) < 0) {
           errno2why();
           close(fd[0]);
           close(fd[1]);
           fail;
       }

       if (pid) {
           struct descrip t;
           create_list(2, &result);
           if (flags == O_RDONLY) {
               close(fd[1]);
               MakeInt(fd[0], &t);
           } else {
               close(fd[0]);
               MakeInt(fd[1], &t);
           }
           c_put(&result, &t);
           MakeInt(pid, &t);
           c_put(&result, &t);
           return result;
       } else {
           if (flags == O_RDONLY) {
               if (dup2(fd[1], 1) < 0) 
                   perror("dup2 of write side of pipe failed");
               if (dup2(fd[1], 2) < 0) 
                   perror("dup2 of write side of pipe failed");
           } else { 
               if (dup2(fd[0], 0) < 0) 
                   perror("dup2 of read side of pipe failed"); 
           } 
           close(fd[0]); /* close since we dup()'ed what we needed */ 
           close(fd[1]); 

           execl("/bin/sh", "sh", "-c", cmd, 0);
           perror("execl failed");        
           exit(1);
           fail;  /* Not reached */
       } 
   }    
end

function{0,1} io_ProgStream_close(self)
   body {
       dptr pid;
       static struct inline_field_cache pid_ic;
       GetSelfFd();

       pid = c_get_instance_data(&self, (dptr)&pidf, &pid_ic);
       if (!pid)
           runerr(207,*(dptr)&pidf);

       if (close(self_fd) < 0) {
           errno2why();
           fail;
       }
       *self_fd_dptr = minusonedesc;
       
       if (waitpid(IntVal(*pid), 0, 0) < 0) {
           errno2why();
           fail;
       }

       return nulldesc;
   }
end

function{0,1} io_Files_rename(s1,s2)
   /*
    * Make C-style strings out of s1 and s2
    */
   if !cnv:C_string(s1) then
      runerr(103,s1)
   if !cnv:C_string(s2) then
      runerr(103,s2)

   body {
       if (rename(s1, s2) < 0) {
           errno2why();
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_Files_hardlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if (link(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

function{0,1} io_Files_symlink(s1, s2)
   if !cnv:C_string(s1) then
      runerr(103, s1)
   if !cnv:C_string(s2) then
      runerr(103, s2)
   body {
#if MSWIN32
      runerr(121);
#else					/* MSWIN32 */
      if (symlink(s1, s2) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
#endif					/* MSWIN32 */
   }
end

function{0,1} io_Files_readlink(s)
   if !cnv:C_string(s) then
      runerr(103, s)
   body {
#if MSWIN32
       runerr(121);
#else					/* MSWIN32 */
       int buff_size, rc;
       char *buff;
       buff_size = 32;
       for (;;) {
           MemProtect(buff = alcstr(0, buff_size));
           rc = readlink(s, buff, buff_size);
           if (rc < 0) {
               dealcstr(buff);
               errno2why();
               fail;
           }
           if (rc < buff_size) {
               /* Fitted okay, so deallocate surplus and return */
               dealcstr(buff + rc);
               return string(rc, buff);
           }
           /* Didn't fit (or perhaps did fit exactly) - so deallocate
            * buff, increase buff_size and repeat */
           dealcstr(buff);
           buff_size *= 2;
       }
#endif					/* MSWIN32 */
      }
end

function{0,1} io_Files_mkdir(s, mode)
   if !cnv:C_string(s) then
      runerr(103, s)
   if !def:C_integer(mode, S_IRWXU|S_IRGRP|S_IXGRP|S_IROTH|S_IXOTH) then
      runerr(101, mode)
   body {
      if (mkdir(s, mode) < 0) {
	 errno2why();
	 fail;
      }
      return nulldesc;
   }
end

function{0,1} io_Files_remove(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      if (remove(s) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

function{0,1} io_Files_truncate(s, len)
   if !cnv:C_string(s) then
      runerr(103,s)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
      if (truncate(s, len) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

static struct descrip stat2list(struct stat *st)
{
   tended struct descrip tmp, res;
   char mode[12], *user, *group;
   struct passwd *pw;
   struct group *gr;

   create_list(13, &res);
   MakeInt((int)st->st_dev, &tmp);
   c_put(&res, &tmp);
   MakeInt((int)st->st_ino, &tmp);
   c_put(&res, &tmp);

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
   cstr2string(mode, &tmp);
   c_put(&res, &tmp);

   MakeInt((int)st->st_nlink, &tmp);
   c_put(&res, &tmp);

#if MSWIN32
   c_put(&res, emptystr);
   c_put(&res, emptystr);
#else					/* MSWIN32 */
   pw = getpwuid(st->st_uid);
   if (!pw) {
      sprintf(mode, "%d", st->st_uid);
      user = mode;
   } else
      user = pw->pw_name;
   cstr2string(user, &tmp);
   c_put(&res, &tmp);
   
   gr = getgrgid(st->st_gid);
   if (!gr) {
      sprintf(mode, "%d", st->st_gid);
      group = mode;
   } else
      group = gr->gr_name;
   cstr2string(group, &tmp);
   c_put(&res, &tmp);
#endif					/* MSWIN32 */

   MakeInt((int)st->st_rdev, &tmp);
   c_put(&res, &tmp);
   MakeInt((int)st->st_size, &tmp);
   c_put(&res, &tmp);
#if MSWIN32
   c_put(&res, zerodesc);
   c_put(&res, zerodesc);
#else
   MakeInt((int)st->st_blksize, &tmp);
   c_put(&res, &tmp);
   MakeInt((int)st->st_blocks, &tmp);
   c_put(&res, &tmp);
#endif
   MakeInt((int)st->st_atime, &tmp);
   c_put(&res, &tmp);
   MakeInt((int)st->st_mtime, &tmp);
   c_put(&res, &tmp);
   MakeInt((int)st->st_ctime, &tmp);
   c_put(&res, &tmp);

   return res;
}

function{0,1} io_Files_stat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      struct stat st;
      if (stat(s, &st) < 0) {
          errno2why();
          fail;
      }
      return stat2list(&st);
   }
end

function{0,1} io_Files_lstat_impl(s)
   if !cnv:C_string(s) then
      runerr(103,s)
   body {
      struct stat st;
      if (lstat(s, &st) < 0) {
          errno2why();
          fail;
      }
      return stat2list(&st);
   }
end

function{0,1} io_Files_access(s, mode)
   if !cnv:C_string(s) then
      runerr(103,s)
   if !def:C_integer(mode, F_OK) then
      runerr(101, mode)
   body {
      if (access(s, mode) < 0) {
          errno2why();
          fail;
      }
      return nulldesc;
   }
end

function{1} util_Timezone_get_system_timezone()
   body {
      int tz_sec;
      time_t t;
      struct tm *ct;
      tended struct descrip tmp;

      tzset();
      time(&t);
      ct = localtime(&t);

      create_list(2, &result);
      #if HAVE_STRUCT_TM_TM_GMTOFF
         MakeInt(ct->tm_gmtoff, &tmp);
         c_put(&result, &tmp);
         #if HAVE_TZNAME
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             c_put(&result, &tmp);
         }
         #endif
      #elif HAVE_TIMEZONE      
         MakeInt(timezone, &tmp);
         c_put(&result, &tmp);
         #if HAVE_TZNAME
         if (ct->tm_isdst >= 0) {
             cstr2string(tzname[ct->tm_isdst ? 1 : 0], &tmp);
             c_put(&result, &tmp);
         }
         #endif
      #else
         c_put(&result, &zerodesc);
      #endif

      return result;
   }
end

/* RamStream implementation */

static struct sdescrip ptrf = {3, "ptr"};

struct ramstream {
    int pos, size, avail, wiggle;
    char *data;
};

#begdef GetSelfRs()
struct ramstream *self_rs;
dptr self_rs_dptr;
static struct inline_field_cache self_rs_ic;
self_rs_dptr = c_get_instance_data(&self, (dptr)&ptrf, &self_rs_ic);
if (!self_rs_dptr)
    syserr("Missing ptr field");
self_rs = (struct ramstream*)IntVal(*self_rs_dptr);
if (!self_rs)
    runerr(219, self);
#enddef

function{1} io_RamStream_close(self)
   body {
       GetSelfRs();
       free(self_rs->data);
       free(self_rs);
       *self_rs_dptr = zerodesc;
       return nulldesc;
   }
end

function{0,1} io_RamStream_in(self, i)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       GetSelfRs();

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }

       if (self_rs->pos >= self_rs->size) {
           GetSelfEofFlag();
           *self_eof_flag = onedesc;
           why("End of file");
           fail;
       }

       i = Min(i, self_rs->size - self_rs->pos);
       bytes2string(&self_rs->data[self_rs->pos], i, &result);
       self_rs->pos += i;
       
       return result;
   }
end

function{1} io_RamStream_new_impl(s, wiggle)
   if !def:string(s, emptystr) then
      runerr(103, s)
   if !def:C_integer(wiggle, 512) then
      runerr(101, wiggle)
   body {
       struct ramstream *p;
       if (wiggle < 0) {
           irunerr(205, wiggle);
           errorfail;
       }
       MemProtect(p = malloc(sizeof(*p)));
       p->wiggle = wiggle;
       p->pos = p->size = StrLen(s);
       p->avail = p->size + p->wiggle;
       MemProtect(p->data = malloc(p->avail));
       memcpy(p->data, StrLoc(s), p->size);
       return C_integer((long int)p);
   }
end

function{1} io_RamStream_out(self, s)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       GetSelfRs();
       if (self_rs->pos + StrLen(s) > self_rs->avail) {
           self_rs->avail = 2 * (self_rs->pos + StrLen(s));
           MemProtect(self_rs->data = realloc(self_rs->data, self_rs->avail));
       }

       if (self_rs->pos > self_rs->size)
           memset(&self_rs->data[self_rs->size], 0, self_rs->pos - self_rs->size);

       memcpy(&self_rs->data[self_rs->pos], StrLoc(s), StrLen(s));
       self_rs->pos += StrLen(s);
       if (self_rs->pos > self_rs->size)
           self_rs->size = self_rs->pos;

       return C_integer StrLen(s);
   }
end

function{0,1} io_RamStream_seek(self, offset)
   if !cnv:C_integer(offset) then
      runerr(101, offset)
   body {
       GetSelfRs();
       if (offset > 0)
           self_rs->pos = offset - 1;
       else {
           if (self_rs->size < -offset) {
               why("Invalid value to seek");
               fail;
           }
           self_rs->pos = self_rs->size + offset;
       }
       return C_integer(self_rs->pos + 1);
   }
end

function{1} io_RamStream_tell(self)
   body {
       GetSelfRs();
       return C_integer(self_rs->pos + 1);
   }
end

function{1} io_RamStream_truncate(self, len)
   if !cnv:C_integer(len) then
      runerr(101, len)
   body {
       GetSelfRs();
       self_rs->pos = len;
       self_rs->avail = len + self_rs->wiggle;
       MemProtect(self_rs->data = realloc(self_rs->data, self_rs->avail));
       if (self_rs->size < len)
           memset(&self_rs->data[self_rs->size], 0, len - self_rs->size);
       self_rs->size = len;
       return nulldesc;
   }
end

function{1} io_RamStream_str(self)
   body {
       GetSelfRs();
       bytes2string(self_rs->data, self_rs->size, &result);
       return result;
   }
end

function{1} util_Connectable_is_methp_with_object(mp, o)
   if !is:object(o) then
       runerr(602, o)
    body {
       if (is:methp(mp) && BlkLoc(mp)->methp.object == &BlkLoc(o)->object)
           return nulldesc;
       else
           fail;
    }
end
