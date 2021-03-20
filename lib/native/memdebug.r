
struct marked_block {
    struct marked_block *next;
    void *addr;
};

static uword marked_block_hash_func(struct marked_block *p) {  return hashptr(p->addr); }
#passthru static DefineHash(, struct marked_block) marked_blocks = { 512, marked_block_hash_func };

enum { AddrQuery=1, TitleQuery };

struct query {
    int type;
    union {
        struct {
            word title;           /* block title */
            uword id;             /* block id */
            union block *class;   /* class or constructor block */
        } by_title;
        struct {
            void *addr;
        } by_addr;
    } u;
};

static struct progstate *prog;
static struct query query;
static int mode;
static int a_flag;
static int r_flag;
static int verbose;
static int finished;
static word slim = 64;
static word llim = 6;
static int addrs = 1;
static FILE *out;
static int flowterm;

enum { Global=1, ClassStatic, ProcStatic, ObjectMember, SetMember, 
       RecordMember, TableDefault, TableKey, TableValue, ListElement, 
       CoexprActivator, CFrameArg, CFrameTended, PFrameTmp, PFrameVar, 
       UcsUtf8, WeakrefVal, MethpObject, StuckListElement, Other,
       OrphanedListBlockParent, OrphanedListBlockLink, OrphanedListBlockMember,
       OrphanedTableBlockParent, OrphanedTableBlockLink, OrphanedTableBlockKey, OrphanedTableBlockValue };

enum { ListMode=1, RefsMode, DumpMode };

struct q_element {
    int type;
    union {
        struct {
            struct progstate *prog;
            int no;
        } global;
        struct {
            struct p_proc  *proc;
            int no;
        } proc;
        struct {
            struct class_field  *field;
        } field;
        struct {
            struct b_object *object;
            int no;
        } object_member;
        struct {
            struct b_lelem *src;
            int dir;
        } orphaned_list_block_link;
        struct {
            struct b_lelem *src;
        } orphaned_list_block_parent;
        struct {
            struct b_lelem *le;
            word no;
        } orphaned_list_block_member;
        struct {
            struct b_telem *src;
        } orphaned_table_block_link;
        struct {
            struct b_telem *src;
        } orphaned_table_block_parent;
        struct {
            struct b_telem *te;
        } orphaned_table_block_key;
        struct {
            struct b_telem *te;
        } orphaned_table_block_value;
        struct {
            struct b_record *record;
            int no;
        } record_member;
        struct {
            struct b_set *set;
        } set_member;
        struct {
            struct b_table *table;
        } table_default;
        struct {
            struct b_table *table;
        } table_key;
        struct {
            struct b_table *table;
            struct b_telem *elem;
        } table_value;
        struct {
            struct b_list *list;
            word no;
        } list_member;
        struct {
            struct b_list *list;
        } stuck_list_element;
        struct {
            struct b_coexpr *coexpr;
        } coexpr_activator;
        struct {
            struct b_coexpr *coexpr;
            struct c_frame  *frame;
            int no;
        } c_frame_arg;
        struct {
            struct b_coexpr *coexpr;
            struct c_frame  *frame;
            int no;
        } c_frame_tended;
        struct {
            struct b_coexpr *coexpr;
            struct p_frame  *frame;
            int no;
        } p_frame_tmp;
        struct {
            struct b_coexpr *coexpr;
            struct p_frame  *frame;
            int no;
        } p_frame_var;
        struct {
            struct b_ucs *ucs;
        } ucs_utf8;
        struct {
            struct b_weakref *weakref;
        } weakref_val;
        struct {
            struct b_methp *methp;
        } methp_object;
        struct {
            struct progstate *prog;
            char *desc;
        } other;
    } u;
    struct descrip dest;
    struct q_element *qlink;     /* Next in queue */
    struct q_element *prev;      /* Trace to root; only used with refs -r */
    word rc;                     /* Reference count; only ever non-zero with refs -r */
};

static struct q_element *curr;

static struct {
    int chk;                     /* For checking we don't leak memory */
    struct q_element *front, *back;
} q;

static struct descrip normalize_descriptor(dptr dp);
static void outblock(union block *b);
static void addrout(void *p);
static void outimagey(dptr d, struct frame *frame);
static void display(dptr dp);
static void proc_statics(char *indent, struct p_proc *pp);
static void traverse_proc(struct b_proc *proc);
static void print_q_element(struct q_element *e);
static void traverse_element(struct q_element *e);
static int is_prog_region(struct region *rp);
static void begin_linkx(dptr fname, word line);
static void end_linkx();
static void print_locationx(struct p_frame *pf);
static int is_marked(void *addr);
static void mark(void *addr);
static void outimagex(dptr d);

/* Is the queue empty? */
static int q_empty()
{
    return q.front == 0;
}

/* Get from queue, assumes it's not empty */
static struct q_element *q_get()
{
    struct q_element *e;
    e = q.front;
    q.front = e->qlink;
    e->qlink = 0;
    if (q_empty())
        q.back = 0;
    return e;
}

/* Free the given element, if its reference count is zero. */
static void q_free(struct q_element *e)
{
    struct q_element *t;
    while (e && e->rc == 0) {
        t = e->prev;
        if (t) t->rc--;
        free(e);
        --q.chk;
        e = t;
    }
}

/* Reset queue */
static void q_clear()
{
    while (!q_empty())
        q_free(q_get());
    if (q.front)
        fprintf(out, "!!! queue front not nil after q_clear\n");
    if (q.back)
        fprintf(out, "!!! queue back not nil after q_clear\n");
    if (q.chk != 0)
        fprintf(out, "!!! chk == %d in q_clear()\n", q.chk);
}

/* Add a new item to the back of the queue.  q.back must then be
 * filled in. */
static void q_add()
{
    struct q_element *e;
    e = safe_zalloc(sizeof(struct q_element));
    ++q.chk;
    if (q_empty())
        q.front = e;
    else
        q.back->qlink = e;
    q.back = e;
    if (curr) {
        e->prev = curr;
        curr->rc++;
    }
}

/* Process items in the queue until it's empty */
static void q_traverse_elements()
{
    struct q_element *e;
    while (!finished && !q_empty()) {
        e = q_get();
        if (r_flag)
            curr = e;
        traverse_element(e);
        q_free(e);
    }
}

static struct region *which_block_region(union block *p)
{
    struct region *rp;
    for (rp = curblock;rp;rp = rp->Gnext)
        if (InRange(rp->base, p, rp->free)) break;

    if (rp == NULL)
        for (rp = curblock->Gprev;rp;rp = rp->Gprev)
            if (InRange(rp->base, p, rp->free)) break;

    return rp;
}

static struct region *which_string_region(char *p)
{
    struct region *rp;
    for (rp = curstring;rp;rp = rp->Gnext)
        if (InRange(rp->base, p, rp->free + 1)) break;

    if (rp == NULL)
        for (rp = curstring->Gprev;rp;rp = rp->Gprev)
            if (InRange(rp->base, p, rp->free + 1)) break;

    return rp;
}

static void q_add_desc(struct progstate *prog, char *desc, int no, dptr dp)
{
    struct descrip d;
    d = normalize_descriptor(dp);
    if (is:null(d))
        return;
    q_add();
    q.back->type = Other;
    q.back->u.other.prog = prog;
    q.back->u.other.desc = desc;
    q.back->dest = d;
}

static void q_add_block(struct progstate *prog, char *desc, int no, union block *blk)
{
    struct descrip d;
    d = block_to_descriptor(blk);
    d = normalize_descriptor(&d);
    if (is:null(d))
        return;
    q_add();
    q.back->type = Other;
    q.back->u.other.prog = prog;
    q.back->u.other.desc = desc;
    q.back->dest = d;
}

static void q_add_orphaned_list_block_member(struct b_lelem *le, int no)
{
    struct descrip d;
    d = normalize_descriptor(&le->lslots[no]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = OrphanedListBlockMember;
    q.back->u.orphaned_list_block_member.le = le;
    q.back->u.orphaned_list_block_member.no = no;
    q.back->dest = d;
}

static void q_add_orphaned_list_block_link(struct b_lelem *src, int dir, union block *le)
{
    q_add();
    q.back->type = OrphanedListBlockLink;
    q.back->u.orphaned_list_block_link.src = src;
    q.back->u.orphaned_list_block_link.dir = dir;
    MakeDesc(D_Lelem, le, &q.back->dest);
}

static void q_add_orphaned_list_block_parent(struct b_lelem *src, dptr par)
{
    q_add();
    q.back->type = OrphanedListBlockParent;
    q.back->u.orphaned_list_block_parent.src = src;
    q.back->dest = *par;
}

static void q_add_orphaned_table_block_key(struct b_telem *te)
{
    struct descrip d;
    d = normalize_descriptor(&te->tref);
    if (is:null(d))
        return;
    q_add();
    q.back->type = OrphanedTableBlockKey;
    q.back->u.orphaned_table_block_key.te = te;
    q.back->dest = d;
}

static void q_add_orphaned_table_block_value(struct b_telem *te)
{
    struct descrip d;
    d = normalize_descriptor(&te->tval);
    if (is:null(d))
        return;
    q_add();
    q.back->type = OrphanedTableBlockValue;
    q.back->u.orphaned_table_block_key.te = te;
    q.back->dest = d;
}

static void q_add_orphaned_table_block_link(struct b_telem *src)
{
    q_add();
    q.back->type = OrphanedTableBlockLink;
    q.back->u.orphaned_table_block_link.src = src;
    MakeDesc(D_Telem, src->clink, &q.back->dest);
}

static void q_add_orphaned_table_block_parent(struct b_telem *src, dptr par)
{
    q_add();
    q.back->type = OrphanedTableBlockParent;
    q.back->u.orphaned_table_block_parent.src = src;
    q.back->dest = *par;
}

static void q_add_object_member(struct b_object *obj, int no)
{
    struct descrip d;
    d = normalize_descriptor(&obj->fields[no]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = ObjectMember;
    q.back->u.object_member.object = obj;
    q.back->u.object_member.no = no;
    q.back->dest = d;
}

static void q_add_record_member(struct b_record *rec, int no)
{
    struct descrip d;
    d = normalize_descriptor(&rec->fields[no]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = RecordMember;
    q.back->u.record_member.record = rec;
    q.back->u.record_member.no = no;
    q.back->dest = d;
}

static void q_add_list_element(struct b_list *list, dptr val, word no)
{
    struct descrip d;
    d = normalize_descriptor(val);
    if (is:null(d))
        return;
    q_add();
    q.back->type = ListElement;
    q.back->u.list_member.list = list;
    q.back->u.list_member.no = no;
    q.back->dest = d;
}

static void q_add_stuck_list_element(struct b_list *list, dptr val)
{
    struct descrip d;
    d = normalize_descriptor(val);
    if (is:null(d))
        return;
    q_add();
    q.back->type = StuckListElement;
    q.back->u.stuck_list_element.list = list;
    q.back->dest = d;
}

static void q_add_set_member(struct b_set *set, struct b_selem *elem)
{
    struct descrip d;
    d = normalize_descriptor(&elem->setmem);
    if (is:null(d))
        return;
    q_add();
    q.back->type = SetMember;
    q.back->u.set_member.set = set;
    q.back->dest = d;
}

static void q_add_table_default(struct b_table *table)
{
    struct descrip d;
    d = normalize_descriptor(&table->defvalue);
    if (is:null(d))
        return;
    q_add();
    q.back->type = TableDefault;
    q.back->u.table_default.table = table;
    q.back->dest = d;
}

static void q_add_table_key(struct b_table *table, struct b_telem *elem)
{
    struct descrip d;
    d = normalize_descriptor(&elem->tref);
    if (is:null(d))
        return;
    q_add();
    q.back->type = TableKey;
    q.back->u.table_key.table = table;
    q.back->dest = d;
}

static void q_add_table_value(struct b_table *table, struct b_telem *elem)
{
    struct descrip d;
    d = normalize_descriptor(&elem->tval);
    if (is:null(d))
        return;
    q_add();
    q.back->type = TableValue;
    q.back->u.table_value.table = table;
    q.back->u.table_value.elem = elem;
    q.back->dest = d;
}

static void q_add_class_static(struct class_field *field)
{
    struct descrip d;
    d = normalize_descriptor(field->field_descriptor);
    if (is:null(d))
        return;
    q_add();
    q.back->type = ClassStatic;
    q.back->u.field.field = field;
    q.back->dest = d;
}

static void q_add_proc_static(struct p_proc *proc, int num)
{
    struct descrip d;
    d = normalize_descriptor(&proc->fstatic[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = ProcStatic;
    q.back->u.proc.proc = proc;
    q.back->u.proc.no = num;
    q.back->dest = d;
}

static void q_add_global(struct progstate *prog, int num)
{
    struct descrip d;
    d = normalize_descriptor(&prog->Globals[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = Global;
    q.back->u.global.prog = prog;
    q.back->u.global.no = num;
    q.back->dest = d;
}

static void q_add_coexpr_activator(struct b_coexpr *cp)
{
    q_add();
    q.back->type = CoexprActivator;
    q.back->u.coexpr_activator.coexpr = cp;
    q.back->dest = block_to_descriptor((union block *)cp->activator);
}

static void q_add_c_frame_arg(struct b_coexpr *coexpr, struct c_frame *cf, int num)
{
    struct descrip d;
    d = normalize_descriptor(&cf->args[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = CFrameArg;
    q.back->u.c_frame_arg.coexpr = coexpr;
    q.back->u.c_frame_arg.frame = cf;
    q.back->u.c_frame_arg.no = num;
    q.back->dest = d;
}

static void q_add_c_frame_tended(struct b_coexpr *coexpr, struct c_frame *cf, int num)
{
    struct descrip d;
    d = normalize_descriptor(&cf->tend[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = CFrameTended;
    q.back->u.c_frame_tended.coexpr = coexpr;
    q.back->u.c_frame_tended.frame = cf;
    q.back->u.c_frame_tended.no = num;
    q.back->dest = d;
}

static void q_add_p_frame_tmp(struct b_coexpr *coexpr, struct p_frame *pf, int num)
{
    struct descrip d;
    d = normalize_descriptor(&pf->tmp[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = PFrameTmp;
    q.back->u.p_frame_tmp.coexpr = coexpr;
    q.back->u.p_frame_tmp.frame = pf;
    q.back->u.p_frame_tmp.no = num;
    q.back->dest = d;
}

static void q_add_p_frame_var(struct b_coexpr *coexpr, struct p_frame *pf, int num)
{
    struct descrip d;
    d = normalize_descriptor(&pf->fvars->desc[num]);
    if (is:null(d))
        return;
    q_add();
    q.back->type = PFrameVar;
    q.back->u.p_frame_var.coexpr = coexpr;
    q.back->u.p_frame_var.frame = pf;
    q.back->u.p_frame_var.no = num;
    q.back->dest = d;
}

static void q_add_ucs_utf8(struct b_ucs *ucs)
{
    q_add();
    q.back->type = UcsUtf8;
    q.back->u.ucs_utf8.ucs = ucs;
    q.back->dest = ucs->utf8;
}

static void q_add_weakref_val(struct b_weakref *weakref)
{
    q_add();
    q.back->type = WeakrefVal;
    q.back->u.weakref_val.weakref = weakref;
    q.back->dest = weakref->val;
}

static void q_add_methp_object(struct b_methp *methp)
{
    q_add();
    q.back->type = MethpObject;
    q.back->u.methp_object.methp = methp;
    q.back->dest = block_to_descriptor((union block *)methp->object);
}

static struct descrip normalize_descriptor(dptr dp)
{
    struct descrip d = *dp;

    type_case d of {
      tvsubs: return normalize_descriptor(&TvsubsBlk(d).ssvar);
      /* Like the garbage collector, named_var descriptor pointers aren't traversed */
      named_var: return nulldesc;  
      tvtbl: return block_to_descriptor(TvtblBlk(d).clink);
      struct_var: {
            struct descrip r;
            union block *bp = BlkLoc(d);
            r = block_to_descriptor(bp);
            /* Orphaned list/table blocks are converted to block
             * descriptors pointing to them, rather than pointers to
             * the parent.
             */
            switch (BlkType(bp)) {
                case T_Lelem: { 		/* list */
                    if (orphaned_lelem(&r, bp))
                        MakeDesc(D_Lelem, bp, &r);
                    break;
                }
                case T_Telem: { 		/* table */
                    if (orphaned_telem(&r, bp))
                        MakeDesc(D_Telem, bp, &r);
                    break;
                }
            }
            return r;
        }
    }

    if (d.dword == D_TendPtr) {
        if (!BlkLoc(d))
            return nulldesc;
        d = block_to_descriptor(BlkLoc(d));
    }

    if (!Qual(d) && !Pointer(d))
        return nulldesc;

    return d;
}

static void progout(struct progstate *p)
{
    fputs("(prog=", out);
    outblock((union block *)p->K_main);
    fputc(')', out);
}

static void kywdout(dptr d)
{
    struct descrip t, v;
    struct progstate *p;
    getvimage(d, &t);
    for (p = progs; p; p = p->next) {
        if (getvar(&t, &v, p) == Succeeded && VarLoc(v) == VarLoc(*d)) {
            if (p != prog)
                progout(p);
            break;
        }
    }
    putstr(out, &t);
}

static void structout(char *name, uword id, dptr d)
{
    if (flowterm)
        fprintf(out, "\x1b[!\"text:%s%%23" UWordFmt "\"L", name, id);
    if (addrs > 1)
        addrout(BlkLoc(*d));
    outimage1(out, d, 1, slim, llim);
    if (flowterm)
        end_linkx();
    return;
}

static void structout2(char *name, dptr d)
{
    fputs(name, out);
    if (flowterm)
        fprintf(out, "\x1b[!\"text:%p\"L", BlkLoc(*d));
    addrout(BlkLoc(*d));
    if (flowterm)
        end_linkx();
    return;
}

static void litblockout(dptr d)
{
    int link = 0;
    if (addrs > 0 && which_block_region(BlkLoc(*d))) {
        if (flowterm) {
            link = 1;
            fprintf(out, "\x1b[!\"text:%p\"L", BlkLoc(*d));
        }
        addrout(BlkLoc(*d));
    }
    outimage1(out, d, 1, slim, llim);
    if (link)
        end_linkx();
}

static void addrout(void *p)
{
    fprintf(out, "(%p)", p);
}

static void outimagex(dptr d)
{
    outimagey(d, 0);
}

static void begin_linkx(dptr fname, word line)
{
    char *s;
    int i;
    if (!flowterm || StrLen(*fname) == 0 || StrLoc(*fname)[0] != '/')
        return;
    fputs("\x1b[!\"file://", out);
    if ((s = get_hostname()))
        fputs(s, out);
    i = StrLen(*fname);
    s = StrLoc(*fname);
    while (i-- > 0) {
        if (strchr(URL_UNRESERVED, *s))
            fputc(*s, out);
        else
            fprintf(out, "%%%02x", *s & 0xff);
        s++;
    }
    if (line)
        fprintf(out, "?line=" WordFmt, line);
    fputs("\"L", out);
}

static void end_linkx()
{
    fputs("\x1b[!L", out);
}

/*
 * Print the current location in the given frame in the standard
 * format.
 */
static void print_locationx(struct p_frame *pf)
{
    struct ipc_line *pline;
    struct ipc_fname *pfile;
    pline = frame_ipc_line(pf);
    pfile = frame_ipc_fname(pf);
    if (pline && pfile) {
        struct descrip t;
        abbr_fname(pfile->fname, &t);
        begin_linkx(pfile->fname, pline->line);
        fprintf(out, "File %.*s; Line " WordFmt, StrF(t), pline->line);
        if (flowterm) end_linkx();
        fputc('\n', out);
    } else
        fprintf(out, "File ?; Line ?\n");
}

static void outimagey(dptr d, struct frame *frame)
{
    int link = 0;
    struct descrip tmp;

    if (d->dword == D_TendPtr) {
        fputs("D_TendPtr -> ", out);
        tmp = normalize_descriptor(d);
        outimagex(&tmp);
        return;
    }

    if (d->dword == D_Lelem) {
        structout2("Orphaned list element block", d);
        return;
    }

    if (d->dword == D_Telem) {
        structout2("Orphaned table element block", d);
        return;
    }

    type_case *d of {
      string: {
            if (addrs > 0 && which_string_region(StrLoc(*d))) {
                if (flowterm) {
                    link = 1;
                    fprintf(out, "\x1b[!\"text:%p\"L", StrLoc(*d));
                }
                addrout(StrLoc(*d));
            }
            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      cset: {
            litblockout(d);
        }
      ucs: {
            litblockout(d);
        }
      integer: {
            if (IsLrgint(*d))
                litblockout(d);
            else
                outimage1(out, d, 1, slim, llim);
        }
#if !RealInDesc
      real: {
            litblockout(d);
        }
#endif
      list: {
            structout("list", ListBlk(*d).id, d);
        }
      set: {
            structout("set", SetBlk(*d).id, d);
        }
      table: {
            structout("table", TableBlk(*d).id, d);
        }
      coexpr: {
            structout("co-expression", CoexprBlk(*d).id, d);
        }
      object: {
            if (ObjectBlk(*d).class->program == prog) {
                if (flowterm) {
                    link = 1;
                    fprintf(out, "\x1b[!\"text:%.*s%%23" UWordFmt "\"L", StrF(*ObjectBlk(*d).class->name), ObjectBlk(*d).id);
                }
                if (addrs > 1)
                    addrout(BlkLoc(*d));
            } else {
                progout(ObjectBlk(*d).class->program);
                if (addrs > 0) {
                    if (flowterm) {
                        link = 1;
                        fprintf(out, "\x1b[!\"text:%p\"L", BlkLoc(*d));
                    }
                    addrout(BlkLoc(*d));
                }
            }

            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      record: {
            if (RecordBlk(*d).constructor->program == prog) {
                if (flowterm) {
                    link = 1;
                    fprintf(out, "\x1b[!\"text:%.*s%%23" UWordFmt "\"L", StrF(*RecordBlk(*d).constructor->name), RecordBlk(*d).id);
                }
                if (addrs > 1)
                    addrout(BlkLoc(*d));
            } else {
                progout(RecordBlk(*d).constructor->program);
                if (addrs > 0) {
                    if (flowterm) {
                        link = 1;
                        fprintf(out, "\x1b[!\"text:%p\"L", BlkLoc(*d));
                    }
                    addrout(BlkLoc(*d));
                }
            }
            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      class: {
            if (ClassBlk(*d).program == prog) {
                if (flowterm) {
                    link = 1;
                    fprintf(out, "\x1b[!\"text:%.*s\"L", StrF(*ClassBlk(*d).name));
                }
            } else
                progout(ClassBlk(*d).program);
            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      constructor: {
            if (ConstructorBlk(*d).program == prog) {
                if (flowterm) {
                    link = 1;
                    fprintf(out, "\x1b[!\"text:%.*s\"L", StrF(*ConstructorBlk(*d).name));
                }
            } else
                progout(ConstructorBlk(*d).program);
            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      proc: {
            if (ProcBlk(*d).type == P_Proc) {
                struct p_proc *pp = (struct p_proc *)&ProcBlk(*d);
                if (pp->program == prog) {
                    if (flowterm) {
                        struct class_field *field = ProcBlk(*d).field;
                        link = 1;
                        fputs("\x1b[!\"text:", out);
                        if (field) {
                            putstr(out, field->defining_class->name);
                            fputs(".", out);
                        }
                        putstr(out, ProcBlk(*d).name);
                        fputs("\"L", out);
                    }
                } else if (pp->program)
                    progout(pp->program);
            }
            outimage1(out, d, 1, slim, llim);
            if (link)
                end_linkx();
        }
      methp: {
            if (flowterm)
                fprintf(out, "\x1b[!\"text:methp%%23" UWordFmt "\"L", MethpBlk(*d).id);
            if (addrs > 1)
                addrout(BlkLoc(*d));
            fprintf(out, "methp#" UWordFmt, MethpBlk(*d).id);
            if (flowterm)
                end_linkx();
            fputc('(', out);
            outblock((union block *)MethpBlk(*d).object);
            fputc(',', out);
            outblock((union block *)MethpBlk(*d).proc);
            fputc(')', out);
        }
      weakref: {
            if (flowterm)
                fprintf(out, "\x1b[!\"text:weakref%%23" UWordFmt "\"L", WeakrefBlk(*d).id);
            if (addrs > 1)
                addrout(BlkLoc(*d));
            fprintf(out, "weakref#" UWordFmt, WeakrefBlk(*d).id);
            if (flowterm)
                end_linkx();
             if (is:null(WeakrefBlk(*d).val))
                 fprintf(out, "()");
             else {
                 putc('(', out);
                 outimagex(&WeakrefBlk(*d).val);
                 putc(')', out);
             }
        }
      tvtbl: {
            fputs("tvtbl -> ", out);
            tmp = block_to_descriptor(TvtblBlk(*d).clink);
            outimagex(&tmp);
            putc('[', out);
            tmp = TvtblBlk(*d).tref;
            outimagex(&tmp);
            putc(']', out);
        }
      tvsubs: {
            fputs("tvsubs -> ", out);
            outimagey(&TvsubsBlk(*d).ssvar, frame);
            if (TvsubsBlk(*d).sslen == 1)
                fprintf(out, "[" WordFmt "]", TvsubsBlk(*d).sspos);
            else
                fprintf(out, "[" WordFmt "+:" WordFmt "]", TvsubsBlk(*d).sspos, TvsubsBlk(*d).sslen);
        }
      named_var: {
            struct progstate *other;
            dptr vp;
            fputs("named_var -> ", out);
            vp = VarLoc(*d);
            if ((other = find_global(vp))) {
                if (other != prog)
                    progout(other);
                fprintf(out, "global %.*s", StrF(*other->Gnames[vp - other->Globals]));       /* global */
            } else if ((other = find_class_static(vp))) {
                /*
                 * Class static field
                 */
                struct class_field *cf = find_class_field_for_dptr(vp, other);
                struct b_class *c = cf->defining_class;
                dptr fname = c->program->Fnames[cf->fnum];
                if (other != prog)
                    progout(other);
                fprintf(out, "class %.*s.%.*s", StrF(*c->name), StrF(*fname));
            } else if ((other = find_procedure_static(vp))) {
                if (other != prog)
                    progout(other);
                fprintf(out, "static %.*s", StrF(*other->Snames[vp - other->Statics]));         /* static in procedure */
            } else {
                while (frame) {
                    if (frame->type == P_Frame) {
                        struct p_frame *pf = (struct p_frame *)frame;
                        if (pf->proc->program &&
                            InRange(pf->fvars->desc, vp, pf->fvars->desc_end)) {
                            fprintf(out, "local %.*s", StrF(*pf->proc->lnames[vp - pf->fvars->desc]));   /* argument/local */
                            break;
                        }
                    }
                    frame = frame->parent_sp;
                }                        
                if (!frame)
                    fputs("?", out);
            }
        }
      kywdint: {
            kywdout(d);
        }

      kywdhandler: {
            kywdout(d);
        }

      kywdstr: {
            kywdout(d);
        }

      kywdpos: {
            kywdout(d);
        }

      kywdsubj: {
            kywdout(d);
      }
      struct_var: {
            union block *bp = BlkLoc(*d);
            dptr varptr = OffsetVarLoc(*d);
            fputs("struct_var -> ", out);
            switch (BlkType(bp)) {
                case T_Telem: { 		/* table */
                    struct descrip par;
                    par = block_to_descriptor(bp);
                    if (orphaned_telem(&par, bp)) {
                        MakeDesc(D_Telem, bp, &tmp);
                        outimagex(&tmp);
                    } else {
                        outimagex(&par);
                        /* Print the element key */
                        putc('[', out);
                        tmp = TelemBlk(*d).tref;
                        outimagex(&tmp);
                        putc(']', out);
                    }
                    break;
                }
                case T_Lelem: { 		/* list */
                    word i;
                    struct descrip par;
                    par = block_to_descriptor(bp);
                    if (orphaned_lelem(&par, bp)) {
                        MakeDesc(D_Lelem, bp, &tmp);
                        outimagex(&tmp);
                    } else {
                        outimagex(&par);
                        i = varptr - &bp->lelem.lslots[bp->lelem.first] + 1;
                        if (i < 1)
                            i += bp->lelem.nslots;
                        if (i > bp->lelem.nused) {
                            fprintf(out, "[Unused slot]");
                        } else {
                            while (BlkType(bp->lelem.listprev) == T_Lelem) {
                                bp = bp->lelem.listprev;
                                i += bp->lelem.nused;
                            }
                            fprintf(out, "[" WordFmt "]", i);
                        }
                    }
                    break;
                }
                case T_Object: { 		/* object */
                    struct b_class *c = ObjectBlk(*d).class;
                    dptr fname;
                    word i = varptr - ObjectBlk(*d).fields;
                    fname =  c->program->Fnames[c->fields[i]->fnum];
                    MakeDesc(D_Object, BlkLoc(*d), &tmp);
                    outimagex(&tmp);
                    fprintf(out, ".%.*s", StrF(*fname));
                    break;
                }
                case T_Record: { 		/* record */
                    struct b_constructor *c = RecordBlk(*d).constructor;
                    dptr fname;
                    word i = varptr - RecordBlk(*d).fields;
                    fname = c->program->Fnames[c->fnums[i]];
                    MakeDesc(D_Record, BlkLoc(*d), &tmp);
                    outimagex(&tmp);
                    fprintf(out,".%.*s", StrF(*fname));
                    break;
                }
                default: {		/* none of the above */
                    fprintf(out, "struct_var");
                }
            }
        }
        default: {
            outimage1(out, d, 1, slim, llim);
        }
    }
}

static void outblock(union block *b)
{
    struct descrip tmp;
    tmp = block_to_descriptor(b);
    outimagex(&tmp);
}

static void print_q_element(struct q_element *e)
{
    dptr name;
    switch (e->type) {
        case Other: {
            fprintf(out, "%s", e->u.other.desc);
            if (e->u.other.prog && (e->u.other.prog != prog)) {
                fputs(" of program ", out);
                outblock((union block *)e->u.other.prog->K_main);
            }
            break;
        }
        case Global: {
            name = e->u.global.prog->Gnames[e->u.global.no];
            fprintf(out, "Global variable %.*s", StrF(*name));
            if (e->u.global.prog != prog) {
                fputs(" of program ", out);
                outblock((union block *)e->u.global.prog->K_main);
            }
            break;
        }
        case ProcStatic: {
            name = e->u.proc.proc->lnames[e->u.proc.no + e->u.proc.proc->ndynam + e->u.proc.proc->nparam];
            fprintf(out, "Static variable %.*s in ", StrF(*name));
            outblock((union block *)e->u.proc.proc);
            break;
        }
        case ClassStatic: {
            name = e->u.field.field->defining_class->program->Fnames[e->u.field.field->fnum];
            fprintf(out, "Class static variable %.*s in ", StrF(*name));
            outblock((union block *)e->u.field.field->defining_class);
            break;
        }
        case ObjectMember: {
            name = e->u.object_member.object->class->program->Fnames[e->u.object_member.object->class->fields[e->u.object_member.no]->fnum];
            fprintf(out, "Instance variable %.*s in ", StrF(*name));
            outblock((union block *)e->u.object_member.object);
            break;
        }
        case OrphanedListBlockParent: {
            struct descrip tmp;
            fputs("Parent of ",out);
            MakeDesc(D_Lelem, e->u.orphaned_list_block_parent.src,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedListBlockLink: {
            struct descrip tmp;
            if (e->u.orphaned_list_block_link.dir > 0)
                fputs("Next link of ",out);
            else
                fputs("Previous link of ",out);
            MakeDesc(D_Lelem, e->u.orphaned_list_block_link.src,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedListBlockMember: {
            struct descrip tmp;
            fprintf(out, "Slot " WordFmt " in ", e->u.orphaned_list_block_member.no);
            MakeDesc(D_Lelem, e->u.orphaned_list_block_member.le,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedTableBlockParent: {
            struct descrip tmp;
            fputs("Parent of ",out);
            MakeDesc(D_Telem, e->u.orphaned_table_block_parent.src,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedTableBlockLink: {
            struct descrip tmp;
            fputs("Next link of ",out);
            MakeDesc(D_Telem, e->u.orphaned_table_block_link.src,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedTableBlockKey: {
            struct descrip tmp;
            fputs("Key of ",out);
            MakeDesc(D_Telem, e->u.orphaned_table_block_key.te,  &tmp);
            outimagex(&tmp);
            break;
        }
        case OrphanedTableBlockValue: {
            struct descrip tmp;
            fputs("Value of ",out);
            MakeDesc(D_Telem, e->u.orphaned_table_block_value.te,  &tmp);
            outimagex(&tmp);
            break;
        }
        case RecordMember: {
            name = e->u.record_member.record->constructor->program->Fnames[e->u.record_member.record->constructor->fnums[e->u.record_member.no]];
            fprintf(out, "Record variable %.*s in ", StrF(*name));
            outblock((union block *)e->u.record_member.record);
            break;
        }
        case ListElement: {
            fprintf(out, "List element ");
            outblock((union block *)e->u.list_member.list);
            fprintf(out, "[" WordFmt "]", e->u.list_member.no);
            break;
        }
        case StuckListElement: {
            fprintf(out, "Stuck list element in ");
            outblock((union block *)e->u.stuck_list_element.list);
            break;
        }
        case SetMember: {
            fprintf(out, "Member of ");
            outblock((union block *)e->u.set_member.set);
            break;
        }
        case TableDefault: {
            fprintf(out, "Table default value of ");
            outblock((union block *)e->u.table_default.table);
            break;
        }
        case TableKey: {
            fprintf(out, "Table key of ");
            outblock((union block *)e->u.table_key.table);
            break;
        }
        case TableValue: {
            fprintf(out, "Table value ");
            outblock((union block *)e->u.table_value.table);
            fputc('[', out);
            outimagex(&e->u.table_value.elem->tref);
            fputc(']', out);
            break;
        }
        case CoexprActivator: {
            fprintf(out, "Activator of ");
            outblock((union block *)e->u.coexpr_activator.coexpr);
            break;
        }
        case CFrameArg: {
            fprintf(out, "Argument %d in frame of ", e->u.c_frame_arg.no);
            outblock((union block *)e->u.c_frame_arg.frame->proc);
            fprintf(out, " in chain of ");
            outblock((union block *)e->u.c_frame_arg.coexpr);
            break;
        }
        case CFrameTended: {
            fprintf(out, "Tended descriptor %d in frame of ", e->u.c_frame_tended.no);
            outblock((union block *)e->u.c_frame_tended.frame->proc);
            fprintf(out, " in chain of ");
            outblock((union block *)e->u.c_frame_arg.coexpr);
            break;
        }
        case PFrameTmp: {
            fprintf(out, "Temporary descriptor %d in frame of ", e->u.p_frame_tmp.no);
            outblock((union block *)e->u.p_frame_tmp.frame->proc);
            fprintf(out, " in chain of ");
            outblock((union block *)e->u.c_frame_arg.coexpr);
            break;
        }
        case PFrameVar: {
            name = e->u.p_frame_var.frame->proc->lnames[e->u.p_frame_var.no];
            fprintf(out, "Variable %.*s in frame of ", StrF(*name));
            outblock((union block *)e->u.p_frame_var.frame->proc);
            fprintf(out, " in chain of ");
            outblock((union block *)e->u.c_frame_arg.coexpr);
            break;
        }
        case UcsUtf8: {
            fprintf(out, "UTF-8 string in ucs block ");
            outblock((union block *)e->u.ucs_utf8.ucs);
            break;
        }
        case WeakrefVal: {
            fprintf(out, "Value in weakref block ");
            outblock((union block *)e->u.weakref_val.weakref);
            break;
        }
        case MethpObject: {
            fprintf(out, "Object in methp block ");
            outblock((union block *)e->u.methp_object.methp);
            break;
        }
        default: {
            fprintf(out, "!!! Nonsensical q_element type=%d", e->type);
            break;
        }
    }
}

static int is_marked(void *addr)
{
    struct marked_block *m;
    for (m = Bucket(marked_blocks, hashptr(addr)); m; m = m->next)
        if (m->addr == addr)
            return 1;
    return 0;
}

static void mark(void *addr)
{
    struct marked_block *m;
    m = safe_malloc(sizeof(struct marked_block));
    m->addr = addr;
    add_to_hash(&marked_blocks, m);
}

#if 0
static void dump_marked_blocks()
{
    int i;
    struct marked_block *m;
    printf("marked_blocks size=%d nbuckets=%d\n",
           marked_blocks.size, marked_blocks.nbuckets);
    for (i = 0; i < marked_blocks.nbuckets; ++i) {
        if (marked_blocks.l[i]) {
            printf("Bucket %d\n", i);
            for (m = marked_blocks.l[i]; m; m = m->next) {
                printf("\tEntry %p = %p", m, m->addr);
                printf("\n");
            }
        }
    }
    printf("=============\n");
}
#endif

static void marked_blocks_dispose()
{
    int i;
    for (i = 0; i < marked_blocks.nbuckets; ++i) {
        struct marked_block *m, *n;
        m = marked_blocks.l[i];
        while (m) {
            n = m;
            m = m->next;
            free(n);
        }
    }
    clear_hash(&marked_blocks);
}

static void traverse_class(struct b_class *class)
{
    struct class_field *field;
    int n = class->n_instance_fields + class->n_class_fields;
    int i;
    for (i = 0; i < n; ++i) {
        field = class->fields[i];
        if (field->defining_class == class) {
            if ((field->flags & M_Method))
                traverse_proc(&ProcBlk(*field->field_descriptor));
            else if ((field->flags & M_Static))
                q_add_class_static(field);
        }
    }
}

static void traverse_proc(struct b_proc *proc)
{
    struct p_proc *pp;
    int i;
    if (proc->type != P_Proc)
        return;
    pp = (struct p_proc *)proc;
    for (i = 0; i < pp->nstatic; ++i) {
        q_add_proc_static(pp, i);
    }
}

static void traverse_program(struct progstate *pstate)
{
    struct prog_event *pe;
    dptr dp;
    int i;

    q_add_desc(pstate, "&handler", 0, &pstate->Kywd_handler);
    q_add_desc(pstate, "&subject", 0, &pstate->Kywd_subject);
    q_add_desc(pstate, "&progname", 0, &pstate->Kywd_prog);
    q_add_desc(pstate, "&why", 0, &pstate->Kywd_why);
    q_add_block(pstate, "&main", 0, (union block *)pstate->K_main);
    q_add_block(pstate, "&current", 0, (union block *)pstate->K_current);
    q_add_desc(pstate, "&errorvalue", 0, &pstate->K_errorvalue);
    q_add_desc(pstate, "&errortext", 0, &pstate->K_errortext);
    if (pstate->K_errorcoexpr)
        q_add_block(pstate, "&errorcoexpr", 0, (union block *)pstate->K_errorcoexpr);

    i = 0;
    for (i = 0; i < pstate->NGlobals; ++i) {
        dptr val;
        val = &pstate->Globals[i];
        if (pstate->Gflags[i] & G_Const) {
            type_case *val of {
              class: traverse_class(&ClassBlk(*val));
              proc:  traverse_proc(&ProcBlk(*val));
            }
        } else {
            q_add_global(pstate, i);
        }
    }

    q_add_desc(pstate, "Temp error value", 0, &pstate->T_errorvalue);
    q_add_desc(pstate, "Temp error text", 0, &pstate->T_errortext);
    q_add_block(pstate, "Program event mask", 0, (union block *)pstate->eventmask);
    i = 0;
    for (pe = pstate->event_queue_head; pe; pe = pe->next) {
        q_add_desc(pstate, "Program event queue code", i, &pe->eventcode);
        q_add_desc(pstate, "Program event queue value", i, &pe->eventval);
        ++i;
    }

    i = 0;
    for (dp = pstate->TCaseTables; dp < pstate->ETCaseTables; dp++) {
        q_add_desc(pstate, "Case table entry", i, dp);
        ++i;
    }
}

static void traverse_tended()
{
    struct tend_desc *tp;
    int i, j;

    j = 0;
    for (tp = tendedlist; tp != NULL; tp = tp->previous) {
        for (i = 0; i < tp->num; ++i) {
            q_add_desc(0, "Tended descriptor", j, &tp->d[i]);
            ++j;
        }
    }
}

static void traverse_others()
{
    struct dptr_list *dl;
    int i, j;
    /* Mark any other global descriptors which have been noted. */
    j = 0;
    for (i = 0; i < og_table.nbuckets; ++i)
        for (dl = og_table.l[i]; dl; dl = dl->next) {
            q_add_desc(0, "Other global", j, dl->dp);
            ++j;
        }
}

static void traverse(int m)
{
    struct progstate *prog;

    mode = m;

    /* Traverse the various roots */
    for (prog = progs; prog; prog = prog->next)
        traverse_program(prog);
    traverse_tended();
    traverse_others();

    /* Traverse the graph */
    q_traverse_elements();

    /* Reset everything. */
    finished = 0;
    curr = 0;
    q_clear();
    marked_blocks_dispose();
    mode = 0;
}

static void traverse_stack(struct b_coexpr *cp)
{
    struct frame *f;
    int i;
    f = cp->sp;
    while (f) {
        switch (f->type) {
            case C_Frame: {
                struct c_frame *cf = (struct c_frame *)f;
                for (i = 0; i < cf->nargs; ++i)
                    q_add_c_frame_arg(cp, cf, i);
                for (i = 0; i < cf->proc->ntend; ++i)
                    q_add_c_frame_tended(cp, cf, i);
                break;
            }
            case P_Frame: {
                struct p_frame *pf = (struct p_frame *)f;
                for (i = 0; i < pf->proc->ndynam + pf->proc->nparam; ++i)
                    q_add_p_frame_var(cp, pf, i);
                for (i = 0; i < pf->proc->ntmp; ++i)
                    q_add_p_frame_tmp(cp, pf, i);
                break;
            }
            default: syserr("Unknown frame type");
        }
        f = f->parent_sp;
    }
}

static int query_match(dptr dp)
{
    if (Qual(*dp)) {
        if (query.type == AddrQuery)
            return (void *)StrLoc(*dp) == query.u.by_addr.addr;
        else
            return 0;
    }

    if (query.type == AddrQuery)
        return (void *)BlkLoc(*dp) == query.u.by_addr.addr;

    if (BlkType(BlkLoc(*dp)) != query.u.by_title.title)
        return 0;

    if (is:object(*dp)) {
        if ((union block *)ObjectBlk(*dp).class != query.u.by_title.class)
            return 0;
    } else if (is:record(*dp)) {
        if ((union block *)RecordBlk(*dp).constructor != query.u.by_title.class)
            return 0;
    }
    
    if (query.u.by_title.id != 0) {
        uword id;
        type_case *dp of {
          list:     id = ListBlk(*dp).id;
          set:      id = SetBlk(*dp).id;
          table:    id = TableBlk(*dp).id;
          record:   id = RecordBlk(*dp).id;
          object:   id = ObjectBlk(*dp).id;
          coexpr:   id = CoexprBlk(*dp).id;
          methp:    id = MethpBlk(*dp).id;
          weakref:  id = WeakrefBlk(*dp).id;
          default: return 0;   /* should never happen */
        }
        if (id != query.u.by_title.id)
            return 0;
    }
    return 1;
}

static int is_prog_region(struct region *rp)
{
    struct region *rq;
    for (rq = prog->stringregion; rq->prev; rq = rq->prev);
    for (; rq; rq = rq->next) {
        if (rp == rq)
            return 1;
    }
    for (rq = prog->blockregion; rq->prev; rq = rq->prev);
    for (; rq; rq = rq->next) {
        if (rp == rq)
            return 1;
    }
    return 0;
}

static void do_dump(struct q_element *e, struct region *rp)
{
    if (is_prog_region(rp))
        display(&e->dest);
}

static void display(dptr dp)
{
    struct descrip d;
    d = *dp;
    outimagex(&d);
    fputc('\n', out);
    if (d.dword == D_Lelem) {
        struct b_lelem *le;
        struct descrip tmp, par;
        word i;
        le = &LelemBlk(d);
        par = block_to_descriptor((union block *)le);
        for (i = 0; i < le->nslots; ++i) {
            if (!is:null(le->lslots[i])) {
                fprintf(out, "\tSlot " WordFmt "=", i);
                outimagex(&le->lslots[i]);
                fputc('\n', out);
            }
        }
        if (BlkType(le->listnext) == T_Lelem && orphaned_lelem(&par, le->listnext)) {
            MakeDesc(D_Lelem, le->listnext, &tmp);
            fputs("\tNext=", out);
            outimagex(&tmp);
            fputc('\n', out);
        }
        if (BlkType(le->listprev) == T_Lelem && orphaned_lelem(&par, le->listprev)) {
            MakeDesc(D_Lelem, le->listprev, &tmp);
            fputs("\tPrevious=", out);
            outimagex(&tmp);
            fputc('\n', out);
        }
        fputs("\tParent block=", out);
        outimagex(&par);
        fputc('\n', out);
        return;
    }
    if (d.dword == D_Telem) {
        struct b_telem *te;
        struct descrip tmp, par;
        te = &TelemBlk(d);
        par = block_to_descriptor((union block *)te);
        fprintf(out, "\tKey=");
        outimagex(&te->tref);
        fputc('\n', out);
        fprintf(out, "\tValue=");
        outimagex(&te->tval);
        fputc('\n', out);
        if (BlkType(te->clink) == T_Telem && orphaned_telem(&par, te->clink)) {
            MakeDesc(D_Telem, te->clink, &tmp);
            fputs("\tNext=", out);
            outimagex(&tmp);
            fputc('\n', out);
        }
        fputs("\tParent block=", out);
        outimagex(&par);
        fputc('\n', out);
        return;
    }
    type_case d of {
      cset: { 
            fprintf(out, "\tsize=" WordFmt "\n", CsetBlk(d).size);
        }
      string: {
            fprintf(out, "\tlength=" WordFmt "\n", StrLen(d));
        }
      ucs: {
            fprintf(out, "\tlength=" WordFmt "\n", UcsBlk(d).length);
            fputs("\tUTF-8=", out);
            outimagex(&UcsBlk(d).utf8);
            fputc('\n', out);
        }
      object: {
            word i;
            for (i = 0; i < ObjectBlk(d).class->n_instance_fields; ++i) {
                dptr name = ObjectBlk(d).class->program->Fnames[ObjectBlk(d).class->fields[i]->fnum];
                fprintf(out, "\t%.*s=", StrF(*name));
                outimagex(&ObjectBlk(d).fields[i]);
                fputc('\n', out);
            }
        }
      record:{
            word i;
            for (i = 0; i < RecordBlk(d).constructor->n_fields; ++i) {
                dptr name = RecordBlk(d).constructor->program->Fnames[RecordBlk(d).constructor->fnums[i]];
                fprintf(out, "\t%.*s=", StrF(*name));
                outimagex(&RecordBlk(d).fields[i]);
                fputc('\n', out);
            }
        }
      list: {
            struct lgstate state;
            struct b_lelem *le;
            word i, j;
            for (le = lgfirst(&ListBlk(d), &state); le;
                 le = lgnext(&ListBlk(d), &state, le)) {
                fprintf(out, "\t" WordFmt "=", state.listindex);
                outimagex(&le->lslots[state.result]);
                fputc('\n', out);
            }
            /* Now iterate again looking for stuck elements. */
            le = (struct b_lelem *)ListBlk(d).listhead;
            while (BlkType(le) == T_Lelem) {
                for (i = le->nused; i < le->nslots; ++i) {
                    j = le->first + i;
                    if (j >= le->nslots)
                        j -= le->nslots;
                    if (!is:null(le->lslots[j])) {
                        fprintf(out, "\tStuck element=");
                        outimagex(&le->lslots[j]);
                        fputc('\n', out);
                    }
                }
                le = (struct b_lelem *)le->listnext;
            }
        }
      set: {
            struct hgstate state;
            union block *ep;
            for (ep = hgfirst(BlkLoc(d), &state); ep;
                 ep = hgnext(BlkLoc(d), &state, ep)) {
                fputc('\t', out);
                outimagex(&ep->selem.setmem);
                fputc('\n', out);
            }
        }
      table: {
            struct hgstate state;
            union block *ep;
            fprintf(out, "\tdefault=");
            outimagex(&TableBlk(d).defvalue);
            fputc('\n', out);
            for (ep = hgfirst(BlkLoc(d), &state); ep;
                 ep = hgnext(BlkLoc(d), &state, ep)) {
                fputc('\t', out);
                outimagex(&ep->telem.tref);
                fputs("->", out);
                outimagex(&ep->telem.tval);
                fputc('\n', out);
            }
        }
      coexpr: {
            struct frame *f;
            int i;
            f = CoexprBlk(d).sp;
            fprintf(out, "\tSP=%p\n\tPF=%p\n", CoexprBlk(d).sp, CoexprBlk(d).curr_pf);
            while (f) {
                switch (f->type) {
                    case C_Frame: {
                        struct c_frame *cf = (struct c_frame *)f;
                        fputc('\t', out);
                        outblock((union block *)cf->proc);
                        fputc('\n', out);
                        fprintf(out, "\t\t%p\n", f);
                        for (i = 0; i < cf->nargs; ++i) {
                            fprintf(out, "\t\tArg %d=", i);
                            outimagey(&cf->args[i], f);
                            fputc('\n', out);
                        }
                        for (i = 0; i < cf->proc->ntend; ++i) {
                            fprintf(out, "\t\tTended %d=", i);
                            outimagey(&cf->tend[i], f);
                            fputc('\n', out);
                        }
                        break;
                    }
                    case P_Frame: {
                        struct p_frame *pf = (struct p_frame *)f;
                        fputc('\t', out);
                        outblock((union block *)pf->proc);
                        fputc('\n', out);
                        fprintf(out, "\t\t%p, caller=%p\n", f, pf->caller);
                        if (pf->proc->program && pf->curr_inst) {
                            fputs("\t\t", out);
                            print_locationx(pf);
                        }
                        for (i = 0; i < pf->proc->ntmp; ++i) {
                            fprintf(out, "\t\tTemp %d=", i);
                            outimagey(&pf->tmp[i], f);
                            fputc('\n', out);
                        }
                        for (i = 0; i < pf->proc->ndynam + pf->proc->nparam; ++i) {
                            dptr name = pf->proc->lnames[i];
                            fprintf(out, "\t\t%.*s=", StrF(*name));
                            outimagex(&pf->fvars->desc[i]);
                            fputc('\n', out);
                        }
                        break;
                    }
                    default: syserr("Unknown frame type");
                }
                f = f->parent_sp;
            }
        }
    }
}

static void do_list(struct q_element *e, struct region *rp)
{
    if (!query_match(&e->dest))
        return;
    if (query.type == TitleQuery && query.u.by_title.id == 0) {
        if (is_prog_region(rp)) {
            outimagex(&e->dest);
            fputc('\n', out);
        } else if (a_flag) {
            outimagex(&e->dest);
            fprintf(out, " in foreign region %p\n", rp);
        }
    } else {
        finished = 1;
        display(&e->dest);
    }
}

/* Returns a flag indicating whether to traverse further in the
 * graph. */
static int do_refs(struct q_element *e)
{
    if (!query_match(&e->dest))
        return 0;
    print_q_element(e);
    fputc('\n', out);
    while ((e = e->prev)) {
        fputc('\t', out);
        print_q_element(e);
        fputc('\n', out);
    };
    return !a_flag;
}

static void traverse_element(struct q_element *e)
{
    void *addr;
    struct region *rp;

    if (verbose) {
        fprintf(out, "Traversing ");
        print_q_element(e);
        fputs(" = ", out);
        outimagex(&e->dest);
        fputc('\n', out);
    }

    if (Var(e->dest)) {
        fprintf(out, "!!! Variable encountered: ");
        print_desc(out, &e->dest);
        fputc('\n', out);
    }

    if (Qual(e->dest))
        rp = which_string_region(StrLoc(e->dest));
    else
        rp = which_block_region(BlkLoc(e->dest));

    if (rp) {
        if (verbose) fprintf(out, "\tin region %p\n", rp);
    } else {
        if (verbose) fprintf(out, "\tnot in a region\n");
        return;
    }

    if (mode == RefsMode) {
        if (do_refs(e))
            return;
    }

    if (Qual(e->dest))
        addr = StrLoc(e->dest);
    else
        addr = BlkLoc(e->dest);

    if (is_marked(addr)) {
        if (verbose) fprintf(out, "\talready marked\n");
        return;
    }
    mark(addr);

    switch (mode) {
        case ListMode: do_list(e, rp); break;
        case DumpMode: do_dump(e, rp); break;
    }

    if (e->dest.dword == D_Lelem) {
        struct b_lelem *le;
        word i;
        struct descrip par;
        le = &LelemBlk(e->dest);
        par = block_to_descriptor((union block *)le);
        /* Add all slots, ignoring first, used etc. */
        for (i = 0; i < le->nslots; ++i)
            q_add_orphaned_list_block_member(le, i);
        /* Add adjoining orphaned blocks.  If they,re not orphaned then they
         * will be traversed via the parent table. */
        if (BlkType(le->listnext) == T_Lelem && orphaned_lelem(&par, le->listnext))
            q_add_orphaned_list_block_link(le, 1, le->listnext);
        if (BlkType(le->listprev) == T_Lelem && orphaned_lelem(&par, le->listprev))
            q_add_orphaned_list_block_link(le, -1, le->listprev);
        q_add_orphaned_list_block_parent(le, &par);
        return;
    }

    if (e->dest.dword == D_Telem) {
        struct b_telem *te;
        struct descrip par;
        te = &TelemBlk(e->dest);
        par = block_to_descriptor((union block *)te);
        q_add_orphaned_table_block_key(te);
        q_add_orphaned_table_block_value(te);
        /* Add the next block if present and orphaned too. */
        if (BlkType(te->clink) == T_Telem && orphaned_telem(&par, te->clink))
            q_add_orphaned_table_block_link(te);
        q_add_orphaned_table_block_parent(te, &par);
        return;
    }

    type_case e->dest of {
      object:{
            word i;
            for (i = 0; i < ObjectBlk(e->dest).class->n_instance_fields; ++i) {
                q_add_object_member(&ObjectBlk(e->dest), i);
            }
        }
      record:{
            word i;
            for (i = 0; i < RecordBlk(e->dest).constructor->n_fields; ++i) {
                q_add_record_member(&RecordBlk(e->dest), i);
            }
        }
      set: {
            struct hgstate state;
            union block *ep;
            for (ep = hgfirst(BlkLoc(e->dest), &state); ep;
                 ep = hgnext(BlkLoc(e->dest), &state, ep)) {
                q_add_set_member(&SetBlk(e->dest), &ep->selem);
            }
        }
      table: {
            struct hgstate state;
            union block *ep;
            q_add_table_default(&TableBlk(e->dest));
            for (ep = hgfirst(BlkLoc(e->dest), &state); ep;
                 ep = hgnext(BlkLoc(e->dest), &state, ep)) {
                q_add_table_key(&TableBlk(e->dest), &ep->telem);
                q_add_table_value(&TableBlk(e->dest), &ep->telem);
            }
        }
      list:{
            struct lgstate state;
            struct b_lelem *le;
            word i, j;
            for (le = lgfirst(&ListBlk(e->dest), &state); le;
                 le = lgnext(&ListBlk(e->dest), &state, le)) {
                q_add_list_element(&ListBlk(e->dest), &le->lslots[state.result], state.listindex);
            }
            /* Now iterate again looking for stuck elements. */
            le = (struct b_lelem *)ListBlk(e->dest).listhead;
            while (BlkType(le) == T_Lelem) {
                for (i = le->nused; i < le->nslots; ++i) {
                    j = le->first + i;
                    if (j >= le->nslots)
                        j -= le->nslots;
                    if (!is:null(le->lslots[j]))
                        q_add_stuck_list_element(&ListBlk(e->dest), &le->lslots[j]);
                }
                le = (struct b_lelem *)le->listnext;
            }
        }
      ucs: {
            q_add_ucs_utf8(&UcsBlk(e->dest));
        }
      weakref: {
            q_add_weakref_val(&WeakrefBlk(e->dest));
        }
      methp: {
            q_add_methp_object(&MethpBlk(e->dest));
        }
      coexpr: {
            struct b_coexpr *cp = &CoexprBlk(e->dest);
            if (cp->activator)
                q_add_coexpr_activator(cp);
            traverse_stack(cp);
        }
    }
}

static stringint titles[] = {
   { 0, 6},
   {"co-expression",  T_Coexpr},
   {"list",  T_List},
   {"methp",  T_Methp},
   {"set",  T_Set},
   {"table",  T_Table},
   {"weakref",  T_Weakref},
};

static int parsequery(char *buf, struct query *ret)
{
    void *p;
    char c, *s;
    union block *class0;
    word title;
    uword id;
    stringint *e;
    struct descrip nd;
    dptr glob;

    if (sscanf(buf, "%p%c", &p, &c) == 1) {
        ret->type = AddrQuery;
        ret->u.by_addr.addr = p;
        return 1;
    }
    s = strpbrk(buf, "#");
    if (s)
        *s++ = 0;
    e = stringint_lookup(titles, buf);
    if (e) {
        title = e->i;
        class0 = 0;
    } else {
        CMakeStr(buf, &nd);
        glob = lookup_named_global(&nd, 1, prog);
        if (!glob) {
            LitWhy("Invalid structure type");
            return 0;
        }
        type_case *glob of {
          class: title = T_Object;
          constructor: title = T_Record;
          default: {
              LitWhy("Invalid structure type");
              return 0;
          }
        }
        class0 = (union block *)BlkLoc(*glob);
    }
    if (s) {
        char c;
        if (sscanf(s, UWordFmt "%c", &id, &c) != 1) {
            LitWhy("Invalid id number");
            return 0;
        }
    } else
        id = 0;
    ret->type = TitleQuery;
    ret->u.by_title.title = title;
    ret->u.by_title.id = id;
    ret->u.by_title.class = class0;
    return 1;
}

function MemDebug_list(s, flag)
   if !cnv:string(s) then
      runerr(103, s)
    body {
       if (!is_flag(&flag))
          runerr(171, flag);
       if (!parsequery(buffstr(&s), &query))
           fail;
       a_flag = is:yes(flag);
       traverse(ListMode);
       a_flag = 0;
       ReturnDefiningClass;
    }
end

static void output_named_global(dptr glob)
{
    outimagex(glob);
    fputc('\n', out);
    type_case *glob of {
      proc: {
            if (ProcBlk(*glob).type == P_Proc)
                proc_statics("\t", (struct p_proc *)&ProcBlk(*glob));
        }
      class: {
            struct b_class *class0;
            struct class_field *field;
            int i;
            class0 = &ClassBlk(*glob);
            for (i = 0; i < class0->n_instance_fields + class0->n_class_fields; ++i) {
                field = class0->fields[i];
                if (field->defining_class == class0) {
                    if ((field->flags & M_Method)) {
                        if (ProcBlk(*field->field_descriptor).type == P_Proc) {
                            struct p_proc *pp = (struct p_proc *)&ProcBlk(*field->field_descriptor);
                            if (pp->nstatic > 0) {
                                fputc('\t', out);
                                outimagex(field->field_descriptor);
                                fputc('\n', out);
                                /*fprintf(out, "\tStatics in %.*s\n", StrF(*pp->name));*/
                                proc_statics("\t\t", pp);
                            }
                        }
                    } else if ((field->flags & M_Static)) {
                        dptr name = class0->program->Fnames[field->fnum];
                        fprintf(out, "\t%.*s=", StrF(*name));
                        outimagex(field->field_descriptor);
                        fputc('\n', out);
                    }
                }
            }
        }
      constructor: {
        }
    }
}

static void output_global(int i)
{
    fprintf(out, "%.*s=", StrF(*prog->Gnames[i]));
    outimagex(&prog->Globals[i]);
    fputc('\n', out);
}

static void output_all_statics()
{
    int i;
    for (i = 0; i < prog->NGlobals; ++i) {
        if (prog->Gflags[i] & G_Const)
            output_named_global(&prog->Globals[i]);
        else
            output_global(i);
    }
}

static void output_keywords()
{
    struct ipc_fname *fn;
    struct ipc_line *ln;
    fprintf(out, "&pos=");
    outimagex(&prog->Kywd_pos);
    fputc('\n', out);
    fprintf(out, "&subject=");
    outimagex(&prog->Kywd_subject);
    fputc('\n', out);
    fprintf(out, "&why=");
    outimagex(&prog->Kywd_why);
    fputc('\n', out);
    fprintf(out, "&progname=");
    outimagex(&prog->Kywd_prog);
    fputc('\n', out);
    fprintf(out, "&random=");
    outimagex(&prog->Kywd_ran);
    fputc('\n', out);
    fprintf(out, "&trace=");
    outimagex(&prog->Kywd_trace);
    fputc('\n', out);
    fprintf(out, "&maxlevel=");
    outimagex(&prog->Kywd_maxlevel);
    fputc('\n', out);
    fprintf(out, "&dump=");
    outimagex(&prog->Kywd_dump);
    fputc('\n', out);
    fprintf(out, "&handler=");
    outimagex(&prog->Kywd_handler);
    fputc('\n', out);
    fprintf(out, "&main=");
    outblock((union block *)prog->K_main);
    fputc('\n', out);
    fprintf(out, "&current=");
    outblock((union block *)prog->K_current);
    fputc('\n', out);
    fprintf(out, "&source=");
    outblock((union block *)prog->K_current->activator);
    fputc('\n', out);
    fprintf(out, "&errortext=");
    if (prog->K_errornumber > 0)
        outimagex(&prog->K_errortext);
    fputc('\n', out);
    fprintf(out, "&errorvalue=");
    if (prog->Have_errval)
        outimagex(&prog->K_errorvalue);
    fputc('\n', out);
    fprintf(out, "&errorcoexpr=");
    if (prog->K_errornumber != 0) 
        outblock((union block *)prog->K_errorcoexpr);
    fputc('\n', out);
    fprintf(out, "&errornumber=");
    if (prog->K_errornumber > 0)
        fprintf(out, "%d", prog->K_errornumber);
    fputc('\n', out);
    fprintf(out, "&file=");
    fn = frame_ipc_fname(prog->K_current->curr_pf);
    if (fn)
        outimagex(fn->fname);
    fputc('\n', out);
    fprintf(out, "&line=");
    ln = frame_ipc_line(prog->K_current->curr_pf);
    if (ln)
        fprintf(out, WordFmt, ln->line);
    fputc('\n', out);
    fprintf(out, "&level=");
    fprintf(out, WordFmt, prog->K_current->level);
    fputc('\n', out);
}

function MemDebug_dump()
    body {
       fprintf(out, "Keywords\n========\n");
       output_keywords();
       fprintf(out, "\nGlobals and statics\n===================\n"); 
       output_all_statics();
       fprintf(out, "\nRegion dump\n===========\n");
       traverse(DumpMode);
       ReturnDefiningClass;
    }
end

function MemDebug_refs(s, flag1, flag2)
   if !cnv:string(s) then
      runerr(103, s)
    body {
       if (!is_flag(&flag1))
          runerr(171, flag1);
       if (!is_flag(&flag2))
          runerr(171, flag2);
       if (!parsequery(buffstr(&s), &query))
           fail;
       if (query.type == TitleQuery && query.u.by_title.id == 0) {
           LitWhy("refs needs an id number to uniquely identify an object");
           fail;
       }
       r_flag = is:yes(flag1);
       a_flag = is:yes(flag2);
       traverse(RefsMode);
       r_flag = a_flag = 0;
       ReturnDefiningClass;
    }
end

function MemDebug_globals()
    body {
       int i;
       for (i = 0; i < prog->NGlobals; ++i) {
           if (!(prog->Gflags[i] & G_Const))
               output_global(i);
       }
       output_keywords();
       ReturnDefiningClass;
    }
end

static void proc_statics(char *indent, struct p_proc *pp)
{
    int i;
    for (i = 0; i < pp->nstatic; ++i) {
        dptr name = pp->lnames[i + pp->ndynam + pp->nparam];
        fprintf(out, "%s%.*s=", indent, StrF(*name));
        outimagex(&pp->fstatic[i]);
        fputc('\n', out);
    }
}

function MemDebug_statics(s)
   if !cnv:string(s) then
      runerr(103, s)
    body {
        dptr glob;
        glob = lookup_named_global(&s, 1, prog);
        if (glob) {
            outimagex(glob);
            fputc('\n', out);
            type_case *glob of {
              proc: {
                    if (ProcBlk(*glob).type == P_Proc)
                        proc_statics("\t",(struct p_proc *)&ProcBlk(*glob));
                }
              class: {
                    struct b_class *class0;
                    struct class_field *field;
                    int i;
                    class0 = &ClassBlk(*glob);
                    for (i = 0; i < class0->n_instance_fields + class0->n_class_fields; ++i) {
                        field = class0->fields[i];
                        if (field->defining_class == class0) {
                            if ((field->flags & (M_Method | M_Static)) == M_Static) {
                                dptr name = class0->program->Fnames[field->fnum];
                                fprintf(out, "\t%.*s=", StrF(*name));
                                outimagex(field->field_descriptor);
                                fputc('\n', out);
                            }
                        }
                    }
                }
              constructor: {
                    LitWhy("A constructor has no statics");
                    fail;
                }
            }
        } else {
            char *p = StrLoc(s);
            word i = StrLen(s) - 1;
            struct descrip cl, meth;
            int f;
            struct class_field *field;

            while (i > 0 && p[i] != '.')
                --i;
            if (i <= 0) {
                LitWhy("Unknown global name");
                fail;
            }

            MakeStr(p, i, &cl);
            ++i;
            MakeStr(p + i, StrLen(s) - i, &meth);
            glob = lookup_named_global(&cl, 1, prog);
            if (!glob || !is:class(*glob)) {
                LitWhy("Unknown global name");
                fail;
            }
            f = lookup_class_field_by_name(&ClassBlk(*glob), &meth);
            if (f < 0) {
                LitWhy("Unknown field name");
                fail;
            }
            field = ClassBlk(*glob).fields[f];
            if (!(field->flags & M_Method)) {
                LitWhy("Field not a method");
                fail;
            }
            outimagex(field->field_descriptor);
            fputc('\n', out);
            if (ProcBlk(*field->field_descriptor).type == P_Proc)
                proc_statics("\t", (struct p_proc *)&ProcBlk(*field->field_descriptor));
        }
        ReturnDefiningClass;
    }
end

function MemDebug_progs()
    body {
       struct progstate *p;
       for (p = progs; p; p = p->next) {
           fprintf(out, "Program %p", p);
           if (p == prog)
               fputs(" (current)", out);
           fputc('\n', out);
           fprintf(out, "\t&main=");
           outblock((union block *)p->K_main);
           fputc('\n', out);
       }
       ReturnDefiningClass;
    }
end

function MemDebug_prog(s)
   if !cnv:string(s) then
      runerr(103, s)
    body {
       struct progstate *p;
       if (!parsequery(buffstr(&s), &query))
           fail;
       if (query.type == TitleQuery && (query.u.by_title.title != T_Coexpr || query.u.by_title.id == 0)) {
           LitWhy("prog needs an unique co-expression as parameter");
           fail;
       }
       for (p = progs; p; p = p->next) {
           struct descrip km = block_to_descriptor((union block *)p->K_main);
           if (query_match(&km))
               break;
       }
       if (!p) {
           LitWhy("co-expression is not &main of a program");
           fail;
       }
       prog = p;
       fprintf(out, "prog set to %p\n", prog);

       ReturnDefiningClass;
    }
end

function MemDebug_set_program(c)
    body {
       if (!(prog = get_program_for(&c)))
          runerr(0);
       ReturnDefiningClass;
    }
end

function MemDebug_set_output(f)
    body {
       FILE *t;
       FdStaticParam(f, fd);
       t = fdopen(dup(fd), "w");
       if (t == NULL) {
           errno2why();
           fail;
       }
       setvbuf(t, NULL, _IOLBF, 0);
       if (out)
           fclose(out);
       out = t;
       ReturnDefiningClass;
    }
end

function MemDebug_set_slim(val)
   if !cnv:C_integer(val) then
       runerr(101, val)
    body {
       slim = val;
       ReturnDefiningClass;
    }
end

function MemDebug_set_addrs(val)
   if !cnv:C_integer(val) then
       runerr(101, val)
    body {
       addrs = val;
       ReturnDefiningClass;
    }
end

function MemDebug_set_flowterm(flag)
    body {
       if (!is_flag(&flag))
          runerr(171, flag);
       flowterm = !is:null(flag);
       ReturnDefiningClass;
    }
end

function MemDebug_nglobals()
    body {
       int i;
       for (i = 0; i < prog->NGlobals; ++i) {
           if (prog->Gflags[i] & G_Const) {
               outimagex(&prog->Globals[i]);
               fputc('\n',out);
           }
       }
       ReturnDefiningClass;
    }
end

static void print_region(char *type, struct region *rp)
{
    uword used;
    used = UDiffPtrs(rp->free,rp->base);
    fprintf(out, "%s region %p", type, rp);
    if (rp == prog->stringregion || rp == prog->blockregion)
        fputs(" (current)", out);
    fputc('\n', out);
    fprintf(out, "\tSize=%'" UWordFmtCh "\n", rp->size);
    fprintf(out, "\tUsage=%'" UWordFmtCh " (%.2f%%)\n", used, (100.0 * (double)used) / rp->size);
    fprintf(out, "\tAddresses=%p - %p\n", rp->base, rp->free);
    fprintf(out, "\tCompacted=%d\n", rp->compacted);
}

function MemDebug_regions()
    body {
       struct region *rp;
       for (rp = prog->stringregion; rp->prev; rp = rp->prev);
       for (; rp; rp = rp->next)
           print_region("String", rp);

       for (rp = prog->blockregion; rp->prev; rp = rp->prev);
       for (; rp; rp = rp->next)
           print_region("Block", rp);

       fprintf(out, "\nStack usage=%'" UWordFmtCh "\n", prog->stackcurr);
       fprintf(out, "String collections=%d\n", prog->collected_string);
       fprintf(out, "Block collections=%d\n", prog->collected_block);
       fprintf(out, "Stack collections=%d\n", prog->collected_stack); 
       fprintf(out, "User collections=%d\n", prog->collected_user);
       fprintf(out, "Total string allocations=%'llu\n", (ulonglong)prog->stringtotal);
       fprintf(out, "Total block allocations=%'llu\n", (ulonglong)prog->blocktotal);

       ReturnDefiningClass;
    }
end
