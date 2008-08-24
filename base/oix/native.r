#include "../h/modflags.h"

/*
 * Helper method to get a class from a descriptor; if a class
 * descriptor then obviously the block is returned; if an object then
 * the object's class is returned.
 */
static struct b_class *get_class_for(dptr x)
{
    type_case *x of {
      class: {
            return &BlkLoc(*x)->class;
        }
      object: {
            return BlkLoc(*x)->object.class;
        }
     default: {
            return 0;
        }
    }
}

function{1} classof(o)
   if !is:object(o) then
       runerr(602, o)
    body {
       return class(BlkLoc(o)->object.class);
    }
end

function{0,1} is(x,c)
   if !is:class(c) then
       runerr(603, c)
    body {
        struct b_class *class, *target = &BlkLoc(c)->class;
        int i;
        if (!(class = get_class_for(&x)))
            runerr(619, x);
        for (i = 0; i < class->n_implemented_classes; ++i) {
            if (class->implemented_classes[i] == target)
                return c;
        }
        fail;
    }
end

function{0,1} glob(s, c)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;
       if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           prog = curpstate;
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
       if (rc != 0) 
           runerr(rc, obj);
       res = *((dptr)(sp + 1));
       return res;
   }
end

function{0,1} lang_Class_getf(obj, field)
   body {
       struct descrip res;
       int rc;
       PushNull;
       PushDesc(obj);
       PushDesc(field);
       rc = field_access((dptr)(sp - 5));
       sp -= 6;
       if (rc != 0) 
           fail;
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
        new_proc->field = cf;

        return pr;
   }
end

function{0,1} lang_Class_for_name(s, c)
   if !cnv:tmp_string(s) then
      runerr(103, s)
   body {
       struct progstate *prog;
       dptr p;
       if (is:coexpr(c))
           prog = BlkLoc(c)->coexpr.program;
       else
           prog = curpstate;
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
        Protect(obj = alcobject(class), runerr(0));
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
function{*} util_WindowsFileSystem_get_roots()
    body {
        DWORD n = GetLogicalDrives();
        char t[4], c = 'A';
	strcpy(t, "?:\\");
        while (n) {
	   if (n & 1) {
	      t[0] = c;
	      suspend cstr2string(t);
	   }
	   n /= 2;
	   ++c;
	}
        fail;
    }
end

function{0,1} util_WindowsFilePath_getdcwd(d)
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
      result = cstr2string(p);
      free(p);
      return result;
   }
end

#endif

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
           on_error(errno);
           fail;
       }

       return C_integer fd;
   }
end

function{0,1} io_FileStream_in_impl(fd, i)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       Protect(StrLoc(s) = alcstr(NULL, i), runerr(0));

       nread = read(fd, StrLoc(s), i);
       if (nread < 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           on_error(errno);
           fail;
       }

       if (nread == 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           on_error(XE_EOF);
           fail;
       }

       StrLen(s) = nread;
       /*
        * We may not have used the entire amount of storage we reserved.
        */
       strtotal += DiffPtrs(StrLoc(s) + nread, strfree);
       strfree = StrLoc(s) + nread;

       return s;
   }

end

function{0,1} io_FileStream_out_impl(fd, s)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       if ((rc = write(fd, StrLoc(s), StrLen(s))) < 0) {
           on_error(errno);
           fail;
       }
       return C_integer rc;
   }
end

function{0,1} io_FileStream_close_impl(fd)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   body {
       if (close(fd) < 0) {
           on_error(errno);
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_FileStream_seek_impl(fd, offset, whence)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:C_integer(offset) then
      runerr(101, offset)
   if !cnv:C_integer(whence) then
      runerr(101, whence)
   body {
       int rc;
       if ((rc = lseek(fd, offset, whence)) < 0) {
           on_error(errno);
           fail;
       }
       return C_integer rc;
   }
end

function{0,1} io_SocketStream_in_impl(fd, i)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:C_integer(i) then
      runerr(101, i)
   body {
       int nread;
       tended struct descrip s;

       if (i <= 0) {
           irunerr(205, i);
           errorfail;
       }
       /*
        * For now, assume we can read the full number of bytes.
        */
       Protect(StrLoc(s) = alcstr(NULL, i), runerr(0));

       nread = recv(fd, StrLoc(s), i, 0);
       if (nread < 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           on_error(errno);
           fail;
       }

       if (nread == 0) {
           /* Reset the memory just allocated */
           strtotal += DiffPtrs(StrLoc(s), strfree);
           strfree = StrLoc(s);
           on_error(XE_EOF);
           fail;
       }

       StrLen(s) = nread;
       /*
        * We may not have used the entire amount of storage we reserved.
        */
       strtotal += DiffPtrs(StrLoc(s) + nread, strfree);
       strfree = StrLoc(s) + nread;

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
           on_error(errno);
           fail;
       }
       return C_integer sockfd;
   }
end

function{0,1} io_SocketStream_out_impl(fd, s)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:string(s) then
      runerr(103, s)
   body {
       int rc;
       /* 
        * If possible use MSG_NOSIGNAL so that we get the EPIPE error
        * code, rather than the SIGPIPE signal.
        */
#ifdef HAVE_MSG_NOSIGNAL
       rc = send(fd, StrLoc(s), StrLen(s), MSG_NOSIGNAL);
#else
       rc = send(fd, StrLoc(s), StrLen(s), 0);
#endif
       if (rc < 0) {
           on_error(errno);
           fail;
       }
       return C_integer rc;
   }
end

function{0,1} io_SocketStream_close_impl(fd)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   body {
       if (close(fd) < 0) {
           on_error(errno);
           fail;
       }
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
           on_error(errno);
           fail;
       }

      result = create_list(2);

      MakeInt(fds[0], &t);
      c_put(&result, &t);

      MakeInt(fds[1], &t);
      c_put(&result, &t);

      return result;
   }
end

function{0,1} io_SocketStream_connect_impl(fd, addr)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   
   if !cnv:C_string(addr) then
      runerr(103, addr)

   body {
       struct sockaddr *sa;
       int len;

       sa = parse_sockaddr(addr, &len);
       if (!sa) {
           on_error(errno);
           fail;
       }

       if (connect(fd, sa, len) < 0) {
           on_error(errno);
           fail;
       }

       return nulldesc;
   }
end

function{0,1} io_SocketStream_bind_impl(fd, addr)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   
   if !cnv:string(addr) then
      runerr(103, addr)

   body {
       tended char *addrstr;
       struct sockaddr *sa;
       int len;

       /*
        * get a C string for the address.
        */
       if (!cnv:C_string(addr, addrstr))
           runerr(103, addr);

       sa = parse_sockaddr(addrstr, &len);
       if (!sa) {
           on_error(errno);
           fail;
       }

       if (bind(fd, sa, len) < 0) {
           on_error(errno);
           fail;
       }

       return nulldesc;
   }
end

function{0,1} io_SocketStream_listen_impl(fd, backlog)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   
   if !cnv:C_integer(backlog) then
      runerr(101, backlog)

   body {
       if (listen(fd, backlog) < 0) {
           on_error(errno);
           fail;
       }
       return nulldesc;
   }
end

function{0,1} io_SocketStream_accept_impl(fd)
   if !cnv:C_integer(fd) then
      runerr(101, fd)

   body {
       SOCKET sockfd;

       if ((sockfd = accept(fd, 0, 0)) < 0) {
           on_error(errno);
           fail;
       }

       return C_integer sockfd;
   }
end



static int list2fd_set(dptr l, dptr tmpl, fd_set *s)
{
    tended struct descrip e;

    FD_ZERO(s);
    if (is:null(*l))
        return 0;
    if (!is:list(*l)) {
        err_msg(108, l);
        return -1;
    }
    *tmpl = create_list(BlkLoc(*l)->list.size);

    while (c_get(&BlkLoc(*l)->list, &e)) {
        C_integer t;
        if (!cnv:C_integer(e, t)) {
            err_msg(101, &e);
            return -1;
        }
        c_put(tmpl, &e);
        FD_SET(t, s);
    }
    return 0;
}

static void fd_set2list(dptr l, dptr tmpl, fd_set *s)
{
    tended struct descrip e;

    if (is:null(*l))
        return;

    while (c_get(&BlkLoc(*tmpl)->list, &e)) {
        C_integer t;
        if (!cnv:C_integer(e, t))
            continue; /* Should never happen */
        if (FD_ISSET(t, s))
            c_put(l, &e);
    }
}

function{0,1} io_DescStream_select_impl(rl, wl, el, timeout)
    body {
       fd_set rset, wset, eset;
       struct timeval tv, *ptv;
       tended struct descrip rtmp, wtmp, etmp;
       int rc;

       if ((list2fd_set(&rl, &rtmp, &rset) < 0) ||
           (list2fd_set(&wl, &wtmp, &wset) < 0) ||
           (list2fd_set(&el, &etmp, &eset) < 0)) {
           on_error(errno);
           fail;
       }

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
           on_error(errno);
           fail;
       }
       /* A rc of zero means timeout; we fail with a custom &errno */
       if (rc == 0) {
           on_error(XE_TIMEOUT);
           fail;
       }

       fd_set2list(&rl, &rtmp, &rset);
       fd_set2list(&wl, &wtmp, &wset);
       fd_set2list(&el, &etmp, &eset);

       return C_integer rc;
    }
end

function{0,1} io_DescStream_poll_impl(a[n])
   body {
#ifdef HAVE_POLL
       struct pollfd *ufds;
       unsigned int nfds;
       int timeout, i, rc;

       nfds = n / 2;
       if (n % 2 == 0)
           timeout = -1;
       else {
           if (!cnv:C_integer(a[n - 1], timeout))
               runerr(101, a[n - 1]);
       }

       Protect(ufds = calloc(nfds, sizeof(struct pollfd)), runerr(0));
       for (i = 0; i < nfds; ++i) {
           int events, fd;
           if (!cnv:C_integer(a[2 * i], fd)) {
               free(ufds);
               runerr(101, a[2 * i]);
           }
           if (!cnv:C_integer(a[2 * i + 1], events)) {
               free(ufds);
               runerr(101, a[2 * i + 1]);
           }
           ufds[i].fd = fd;
           ufds[i].events = events;
       }

       rc = poll(ufds, nfds, timeout);
       if (rc < 0) {
           free(ufds);
           on_error(errno);
           fail;
       }
       /* A rc of zero means timeout; we fail with a custom &errno */
       if (rc == 0) {
           free(ufds);
           on_error(XE_TIMEOUT);
           fail;
       }

       result = create_list(nfds);
       for (i = 0; i < nfds; ++i) {
           struct descrip tmp;
           MakeInt(ufds[i].revents, &tmp);
           c_put(&result, &tmp);
       }

       free(ufds);

       return result;
#else
       runerr(121);
#endif  /* HAVE_POLL */
   }
end

function{0,1} io_DescStream_flag_impl(fd, on, off)
   if !cnv:C_integer(fd) then
      runerr(101, fd)

    if !def:C_integer(on, 0) then
      runerr(101, on)

    if !def:C_integer(off, 0) then
      runerr(101, off)

    body {
        int i;

        if ((i = fcntl(fd, F_GETFL, 0)) < 0) {
           on_error(errno);
           fail;
        }
        if (on || off) {
            i = (i | on) & (~off);
            if (fcntl(fd, F_SETFL, i) < 0) {
                on_error(errno);
                fail;
            }
        }

        return C_integer i;
    }
end

function{0,1} io_DirStream_open_impl(path)
   if !cnv:C_string(path) then
      runerr(103, path)
   body {
       DIR *dd;

       dd = opendir(path);
       if (!dd) {
           on_error(errno);
           fail;
       }

       return C_integer((long int)dd);
   }
end

function{0,1} io_DirStream_read_impl(dd)
   if !cnv:C_integer(dd) then
      runerr(101, dd)
   body {
       struct dirent *de;
       errno = 0;
       de = readdir((DIR*)dd);
       if (!de) {
           if (errno)
               on_error(errno);
           else
               on_error(XE_EOF);
           fail;
       }
       return cstr2string(de->d_name);
   }
end

function{0,1} io_DirStream_close_impl(dd)
   if !cnv:C_integer(dd) then
      runerr(101, dd)
   body {
       int rc;
       if ((rc = closedir((DIR*)dd)) < 0) {
           on_error(errno);
           fail;
       }
       return nulldesc;
   }
end

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
           on_error(errno);
           fail;
       }

       if ((pid = fork()) < 0) {
           on_error(errno);
           close(fd[0]);
           close(fd[1]);
           fail;
       }

       if (pid) {
           struct descrip t;
           result = create_list(2);
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

function{0,1} io_ProgStream_close_impl(fd, pid)
   if !cnv:C_integer(fd) then
      runerr(101, fd)
   if !cnv:C_integer(pid) then
      runerr(101, pid)
   body {
       if (close(fd) < 0) {
           on_error(errno);
           fail;
       }
       
       if (waitpid(pid, 0, 0) < 0) {
           on_error(errno);
           fail;
       }

       return nulldesc;
   }
end
