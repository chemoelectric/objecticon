/*
 * tsym.c -- functions for symbol table management.
 */

#include "icont.h"
#include "tsym.h"
#include "tmem.h"
#include "keyword.h"
#include "ucode.h"
#include "tree.h"
#include "tmain.h"
#include "tcode.h"
#include "trans.h"
#include "../h/opdefs.h"

/*
 * Prototypes.
 */

static struct	tcentry *alclit	(struct tcentry *blink, char *name, int len,int flag);
static struct	tcentry *clookup	(char *id,int flag);

/*
 * Keyword table.
 */

struct keyent {
    char *keyname;
    int keyid;
};

#define KDef(p,n) { Lit(p), n },
static struct keyent keytab[] = {
#include "../h/kdefs.h"
};

/*
 * install - put an identifier into the global or local symbol table.
 *  The basic idea here is to look in the right table and install
 *  the identifier if it isn't already there.  Some semantic checks
 *  are performed.
 */
void install(char *name, int flag, struct node *n)
{
    switch (flag) {
        case F_Global:	/* a variable in a global declaration */
            next_global(name, flag, n);
            break;

        case F_Static:	/* static declaration */
        case F_Dynamic:	/* local declaration (possibly implicit?) */
        case F_Argument:	/* formal parameter */
            put_local(name, flag, n, 1);
            if (flag & F_Argument)
                ++curr_func->nargs;
            break;

        case F_Class:
            next_field(name, modflag, n);
            break;

        case F_Importsym:
            add_import_symbol(name, n);
            break;

        default:
            tsyserr("install: unrecognized symbol table flag.");
    }
}

struct tgentry *next_global(char *name, int flag, struct node *n)
{
    int i = hasher(name, ghash);
    struct tgentry *x = ghash[i];
    while (x && x->g_name != name)
        x = x->g_blink;
    if (x)
        tfatal_at(n, "global redeclaration: %s previously declared at line %d", name, Line(x->pos));
    x = Alloc(struct tgentry);
    x->g_blink = ghash[i];
    ghash[i] = x;
    x->g_name = name;
    x->pos = n;
    x->g_flag = flag;
    if (glast) {
        glast->g_next = x;
        glast = x;
    } else
        gfirst = glast = x;
    return x;
}

/*
 * Create, or return an existing, local symbol entry.
 */
struct tlentry *put_local(char *name, int flag, struct node *n, int unique)
{
    int i = hasher(name, curr_func->lhash);
    struct tlentry *x = curr_func->lhash[i];
    while (x && x->l_name != name)
        x = x->l_blink;
    if (x) {
        if (unique)
            tfatal_at(n, "local redeclaration: %s previously declared at line %d", name, Line(x->pos));
        return x;
    }
    x = Alloc(struct tlentry);
    x->l_blink = curr_func->lhash[i];
    curr_func->lhash[i] = x;
    x->l_name = name;
    x->pos = n;
    x->l_flag = flag;
    if (curr_func->llast) {
        x->l_index = curr_func->llast->l_index + 1;
        curr_func->llast->l_next = x;
        curr_func->llast = x;
    } else {
        x->l_index = 0;
        curr_func->lfirst = curr_func->llast = x;
    }
    return x;
}


/*
 * putlit makes a constant symbol table entry and returns the table "index"
 *  of the constant.  alclit does the work if there is a collision.
 */
int putlit(char *id, int idtype, int len)
{
    register struct tcentry *ptr;
    int i = hasher(id, curr_func->chash);
    if ((ptr = clookup(id,idtype)) == NULL) {   /* add to head of hash chain */
        ptr = curr_func->chash[i];
        curr_func->chash[i] = alclit(ptr, id, len, idtype);
        return curr_func->chash[i]->c_index;
    }
    return ptr->c_index;
}

/*
 * clookup looks up id in constant symbol table and returns pointer to
 *  to it if found or NULL if not present.
 */
static struct tcentry *clookup(char *id, int flag)
{
    register struct tcentry *ptr;

    ptr = curr_func->chash[hasher(id, curr_func->chash)];
    while (ptr != NULL && (ptr->c_name != id || ptr->c_flag != flag))
        ptr = ptr->c_blink;

    return ptr;
}

static int keytab_cmp(char *key, struct keyent *item)
{
    return strcmp(key, item->keyname);
}

/*
 * klookup looks up keyword named by id in keyword table and returns
 *  its number (keyid).
 */
int klookup(char *id)
{
    struct keyent *ke = bsearch(id, keytab, ElemCount(keytab), 
                                ElemSize(keytab), 
                                (BSearchFncCast)keytab_cmp);
    if (!ke)
        return 0;

    return ke->keyid;
}

/*
 * alclit allocates a constant symbol table entry, fills in fields with
 *  specified values and returns the new entry.  
 */
static struct tcentry *alclit(struct tcentry *blink, char *name, int len, int flag)
{
    register struct tcentry *cp;

    cp = Alloc(struct tcentry);
    cp->c_blink = blink;
    cp->c_name = name;
    cp->c_length = len;
    cp->c_flag = flag;
    if (curr_func->cfirst == NULL) {
        curr_func->cfirst = cp;
        cp->c_index = 0;
    }
    else {
        curr_func->clast->c_next = cp;
        cp->c_index = curr_func->clast->c_index + 1;
    }
    curr_func->clast = cp;
    return cp;
}

static char *curr_file;
static int curr_line;

void ensure_pos(struct node *x)
{
    if (File(x) != curr_file) {
        uout_op(Op_Filen);
        uout_str(File(x));
        curr_file = File(x);
        curr_line = 0;
    }
    if (Line(x) != curr_line) {
        uout_op(Op_Line);
        uout_16(Line(x));
        curr_line = Line(x);
    }
}

void reset_pos()
{
    curr_file = 0;
    curr_line = 0;
}

/*
 * lout dumps local tables of a function f
 */
static void fout(struct tfunction *f)
{
    struct tlentry *lp;
    struct tcentry *cp;

    uout_op(Op_Nargs);
    uout_16(f->nargs);

    for (lp = f->lfirst; lp; lp = lp->l_next) {
        ensure_pos(lp->pos);
        uout_op(Op_Local);
        uout_32(lp->l_flag);
        uout_str(lp->l_name);
    }

    for (cp = f->cfirst; cp; cp = cp->c_next) {
        uout_op(Op_Con);
        uout_32(cp->c_flag);
        uout_bin(cp->c_length, cp->c_name);
    }
}

static void clout(struct tclass *class)
{
    struct tclass_super *cs;
    struct tclass_field *cf;

    ensure_pos(class->global->pos);
    uout_op(Op_Class);
    uout_32(class->flag);
    uout_str(class->global->g_name);

    for (cs = class->supers; cs; cs = cs->next) {
        ensure_pos(cs->pos);
        uout_op(Op_Super);
        uout_str(cs->name);
    }
   
    for (cf = class->fields; cf; cf = cf->next) {
        ensure_pos(cf->pos);
        uout_op(Op_Classfield);
        uout_32(cf->flag);
        uout_str(cf->name);
        if (cf->f)
            fout(cf->f);
    }
}

static void recout(struct tfunction *rec)
{
    struct tlentry *lp;
    ensure_pos(rec->global->pos);
    uout_op(Op_Record);
    uout_str(rec->global->g_name);
    for (lp = rec->lfirst; lp; lp = lp->l_next) {
        ensure_pos(lp->pos);
        uout_op(Op_Recordfield);
        uout_str(lp->l_name);
    }
}

static void procout(struct tfunction *proc)
{
    ensure_pos(proc->global->pos);
    uout_op(Op_Procdecl);
    uout_str(proc->global->g_name);
    fout(proc);
}

void output_code()
{
    struct tgentry *gp;
    struct link *li;
    struct tinvocable *iv;
    struct timport *im;
    struct timport_symbol *ims;

    uout_op(Op_Version);
    uout_str(UVersion);

    reset_pos();

    if (trace)
        uout_op(Op_Trace);
   
    if (package_name) {
        uout_op(Op_Package);
        uout_str(package_name);
    }

    for (im = imports; im; im = im->next) {
        ensure_pos(im->pos);
        uout_op(Op_Import);
        uout_str(im->name);
        uout_16(im->qualified);
        if (im->qualified) {
            for (ims = im->symbols; ims; ims = ims->next) {
                ensure_pos(ims->pos);
                uout_op(Op_Importsym);
                uout_str(ims->name);
            }
        }
    }

    for (li = links; li; li = li->next) {
        ensure_pos(li->pos);
        uout_op(Op_Link);
        uout_str(li->name);
    }

    for (iv = tinvocables; iv; iv = iv->next) {
        ensure_pos(iv->pos);
        uout_op(Op_Invocable);
        uout_str(iv->name);
    }

    for (gp = gfirst; gp; gp = gp->g_next) {
        switch (gp->g_flag) {
            case F_Global:
                ensure_pos(gp->pos);
                uout_op(Op_Global);
                uout_str(gp->g_name);
                break;
            case F_Global|F_Class:
                clout(gp->class);
                break;
            case F_Global|F_Proc:
                procout(gp->func);
                break;
            case F_Global|F_Record:
                recout(gp->func);
                break;
        }
    }
    uout_op(Op_Declend);

    reset_pos();
    for (curr_func = functions; curr_func; curr_func = curr_func->next) {
        switch (curr_func->flag) {
            case F_Proc: 
                ensure_pos(curr_func->global->pos);
                uout_op(Op_Proc);
                uout_str(curr_func->global->g_name);
                codegen(curr_func->code);
                break;

            case F_Method: 
                if (!(curr_func->field->flag & M_Defer)) {
                    ensure_pos(curr_func->field->pos);
                    uout_op(Op_Method);
                    uout_str(curr_func->field->class->global->g_name);
                    uout_str(curr_func->field->name);
                    codegen(curr_func->code);
                }
                break;
        }
    }
}

