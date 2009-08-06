/*
 * File: rlrgint.r
 *  Large integer arithmetic
 */


/*
 *  Conventions:
 *
 *  Lrgints entering this module and leaving it are too large to
 *  be represented with T_Integer.  So, externally, a given value
 *  is always T_Integer or always T_Lrgint.
 *
 *  Routines outside this module operate on bignums by calling
 *  a routine like
 *
 *      bigadd(da, db, dx)
 *
 *  where da, db, and dx are pointers to tended descriptors.
 *  For the common case where one argument is a T_Integer, these
 *  call routines like
 *
 *      bigaddi(da, IntVal(*db), dx).
 *
 *  The bigxxxi routines can convert an integer to bignum form;
 *  they use itobig.
 *
 *  The routines that actually do the work take (length, address)
 *  pairs specifying unsigned base-B digit strings.  The sign handling
 *  is done in the bigxxx routines.
 */

/* The bignum radix, B */

#define B            ((word)1 << NB)

/* Lrgint digits in a word */

#define WORDLEN  (WordBits / NB + (WordBits % NB != 0))


/* lo(uword d) :            the low digit of a uword
   hi(uword d) :            the rest, d is unsigned
   signed_hi(uword d) :     the rest, d is signed
   dbl(DIGIT a, DIGIT b) : the two-digit uword [a,b] */

#define lo(d)        ((d) & (B - 1))
#define hi(d)        ((uword)(d) >> NB)
#define dbl(a,b)     (((uword)(a) << NB) + (b))

/* structure for a temporary bignum block that will hold an integer */
union word_b_bignum {
    char t[sizeof(struct b_bignum) + sizeof(DIGIT) * (WORDLEN - 1)];
    struct b_bignum blk;
};

#if ((-1) >> 1) < 0
#define signed_hi(d) ((word)(d) >> NB)
#else
#define signbit      ((uword)1 << (WordBits - NB - 1))
#define signed_hi(d) ((word)((((uword)(d) >> NB) ^ signbit) - signbit))
#endif

/* LrgInt(dptr dp) : the struct b_bignum pointed to by dp */

#define LrgInt(dp)   ((struct b_bignum *)&BlkLoc(*dp)->bignum)

/* LEN(struct b_bignum *b) : number of significant digits */

#define LEN(b)       ((b)->lsd - (b)->msd + 1)

/* DIG(struct b_bignum *b, word i): pointer to ith most significant digit */
/*  (NOTE: This macro expansion often results in a very long string,
 *   that has been known to cause problems with the C compiler under VMS.
 *   So when DIG is used, keep it to one use per line.)
 */

#define DIG(b,i)     (&(b)->digits[(b)->msd+(i)])

/* ceil, ln: ceil may be 1 too high in case ln is inaccurate */

#undef ceil
#define ceil(x)      ((word)((x) + 1.01))
#define ln(n)        (log((double)n))

/* determine the number of words needed for a bignum block with n digits */

#define LrgNeed(n)   ( ((sizeof(struct b_bignum) + ((n) - 1) * sizeof(DIGIT)) \
                        + WordSize - 1) & -WordSize )

/* copied from rconv.c */

#define tonum(c)     (isdigit(c) ? (c)-'0' : 10+(((c)|(040))-'a'))


/* copied from oref.c */

#define RandVal (RanScale*(k_random=(RandA*(long)k_random+RandC)&0x7fffffffL))

/*
 * Prototypes.
 */

static void mkdesc	(struct b_bignum *x, dptr dx);
static void itobig	(word i, struct b_bignum *x, dptr dx);

static void decout	(FILE *f, DIGIT *n, word l);

static void bigaddi	(dptr da, word i, dptr dx);
static void bigsubi	(dptr da, word i, dptr dx);
static void bigmuli	(dptr da, word i, dptr dx);
static void bigdivi	(dptr da, word i, dptr dx);
static void bigmodi	(dptr da, word i, dptr dx);
static int bigpowi	(dptr da, word i, dptr dx);
static int bigpowii	(word a, word i, dptr dx);
static word bigcmpi	(dptr da, word i);

static DIGIT add1	(DIGIT *u, DIGIT *v, DIGIT *w, word n);
static word sub1	(DIGIT *u, DIGIT *v, DIGIT *w, word n);
static void mul1	(DIGIT *u, DIGIT *v, DIGIT *w, word n, word m);
static void div1	
(DIGIT *a, DIGIT *b, DIGIT *q, DIGIT *r, word m, word n, struct b_bignum *b1, struct b_bignum *b2);
static void compl1	(DIGIT *u, DIGIT *w, word n);
static word cmp1	(DIGIT *u, DIGIT *v, word n);
static DIGIT addi1	(DIGIT *u, word k, DIGIT *w, word n);
static void subi1	(DIGIT *u, word k, DIGIT *w, word n);
static DIGIT muli1	(DIGIT *u, word k, int c, DIGIT *w, word n);
static DIGIT divi1	(DIGIT *u, word k, DIGIT *w, word n);
static DIGIT shifti1	(DIGIT *u, word k, DIGIT c, DIGIT *w, word n);
static word cmpi1	(DIGIT *u, word k, word n);

#define bdzero(dest,l)  memset(dest, '\0', (l) * sizeof(DIGIT))
#define bdcopy(src, dest, l)  memcpy(dest, src, (l) * sizeof(DIGIT))

/*
 * mkdesc -- put value into a descriptor
 */

static void mkdesc(x, dx)
    struct b_bignum *x;
    dptr dx;
{
    word xlen, cmp;
    static DIGIT maxword[WORDLEN] = { (DIGIT)1 << ((WordBits - 1) % NB) };

    /* suppress leading zero digits */

    while (x->msd != x->lsd &&
           *DIG(x,0) == 0)
        x->msd++;

    /* put it into a word if it fits, otherwise return the bignum */

    xlen = LEN(x);

    if (xlen < WORDLEN ||
        (xlen == WORDLEN &&
         ((cmp = cmp1(DIG(x,0), maxword, (word)WORDLEN)) < 0 ||
          (cmp == (word)0 && x->sign)))) {
        word val = -(word)*DIG(x,0);
        word i;

        for (i = x->msd; ++i <= x->lsd; )
            val = (val << NB) - x->digits[i];
        if (!x->sign)
            val = -val;
        dx->dword = D_Integer;
        IntVal(*dx) = val;
    }
    else {
        dx->dword = D_Lrgint;
        BlkLoc(*dx) = (union block *)x;
    }
}

/*
 *  i -> big
 */

static void itobig(i, x, dx)
    word i;
    struct b_bignum *x;
    dptr dx;
{
    x->lsd = WORDLEN - 1;
    x->msd = WORDLEN;
    x->sign = 0;

    if (i == 0) {
        x->msd--;
        *DIG(x,0) = 0;
    }
    else if (i < 0) {
        word d = lo(i);

        if (d != 0) {
            d = B - d;
            i += B;
        }
        i = - signed_hi(i);
        x->msd--;
        *DIG(x,0) = d;
        x->sign = 1;
    }
            
    while (i != 0) {
        x->msd--;
        *DIG(x,0) = lo(i);
        i = hi(i);
    }

    dx->dword = D_Lrgint;
    BlkLoc(*dx) = (union block *)x;
}

/*
 *  string -> bignum 
 */

word bigradix(sign, r, s, end_s, result)
    int sign;                      /* '-' or not */
    int r;                          /* radix 2 .. 36 */
    char *s, *end_s;                        /* input string */
    union numeric *result;          /* output T_Integer or T_Lrgint */
{
    struct b_bignum *b;
    DIGIT *bd;
    word len;
    int c;

    if (r == 0)
        return CvtFail;
    len = ceil((end_s - s) * ln(r) / ln(B));
    MemProtect(b = alcbignum(len));
    bd = DIG(b,0);

    bdzero(bd, len);

    if (r < 2 || r > 36)
        return CvtFail;

    for (c = ((s < end_s) ? *s++ : ' '); isalnum(c);
         c = ((s < end_s) ? *s++ : ' ')) {
        c = tonum(c);
        if (c >= r)
            return CvtFail;
        muli1(bd, (word)r, c, bd, len);
    }

    /*
     * Skip trailing white space and make sure there is nothing else left
     *  in the string. Note, if we have already reached end-of-string,
     *  c has been set to a space.
     */
    while (isspace(c) && s < end_s)
        c = *s++;
    if (!isspace(c))
        return CvtFail;

    if (sign == '-')
        b->sign = 1;

    /* put value into dx and return the type */

    { struct descrip dx;
        mkdesc(b, &dx);
        if (Type(dx) == T_Lrgint)
            result->big = (struct b_bignum *)BlkLoc(dx);
        else
            result->integer = IntVal(dx);
        return Type(dx);
    }
}

/*
 *  bignum -> real
 */

int bigtoreal(dptr da, double *d)
{
    word i;
    double r = 0;
    struct b_bignum *b = &BlkLoc(*da)->bignum;

    for (i = b->msd; i <= b->lsd; i++)
        r = r * B + b->digits[i];
    if (b->sign)
        r = -r;

    /* Check for inf */
    if (r > DBL_MAX || r < -DBL_MAX)
        return CvtFail;

    *d = r;
    return Succeeded;
}

/*
 *  real -> bignum
 */

int realtobig(da, dx)
    dptr da, dx;
{

    double x;
    struct b_bignum *b;
    word i, blen;
    word d;
    int sgn;

    GetReal(BlkLoc(*da)->real, x);


    /* Try to catch the case of x being +/-"inf" - these values produce a spurious value of
     * blen below, which causes a segfault.
     */
    if (x > DBL_MAX || x < -DBL_MAX)
        return CvtFail;

    if (x > 0.9999 * MinWord && x < 0.9999 * MaxWord) {
        MakeInt((word)x, dx);
        return Succeeded;		/* got lucky; a simple integer suffices */
    }

    if ((sgn = x < 0))
        x = -x;
    blen = ln(x) / ln(B) + 0.99;
    for (i = 0; i < blen; i++)
        x /= B;
    if (x >= 1.0) {
        x /= B;
        blen += 1;
    }

    MemProtect(b = alcbignum(blen));
    for (i = 0; i < blen; i++) {
        d = (x *= B);
        *DIG(b,i) = d;
        x -= d;
    }
     
    b->sign = sgn;
    mkdesc(b, dx);
    return Succeeded;
}

/*
 *  bignum -> string
 */

void bigtos(da, dx)
    dptr da, dx;
{
    tended struct b_bignum *a, *temp;
    word alen = LEN(LrgInt(da));
    word slen = ceil(alen * ln(B) / ln(10));
    char *p, *q;

    a = LrgInt(da);
    MemProtect(temp = alcbignum(alen));
    if (a->sign)
        slen++;
    MemProtect(q = alcstr(NULL,slen));
    bdcopy(DIG(a,0),
           DIG(temp,0),
           alen);
    p = q += slen;
    while (cmpi1(DIG(temp,0),
                 (word)0, alen))
        *--p = '0' + divi1(DIG(temp,0),
                           (word)10,
                           DIG(temp,0),
                           alen);

    if (a->sign)
        *--p = '-';
    StrLen(*dx) = q - p;
    StrLoc(*dx) = p;
}

/*
 *  bignum -> file 
 */

void bigprint(f, da)
    FILE *f;
    dptr da;
{
    struct b_bignum *a, *temp;
    word alen = LEN(LrgInt(da));
    word slen, dlen;
    struct b_bignum *blk = &BlkLoc(*da)->bignum;

    slen = blk->lsd - blk->msd;
    dlen = slen * NB * 0.3010299956639812	/* 1 / log2(10) */
        + log((double)blk->digits[blk->msd]) * 0.4342944819032518 + 0.5;
    /* 1 / ln(10) */
    if (dlen >= MaxDigits) {
        fprintf(f, "integer(~10^%ld)",(long)dlen);
        return;
    }

    /* not worth passing this one back */
    MemProtect(temp = alcbignum(alen));

    a = LrgInt(da);
    bdcopy(DIG(a,0),
           DIG(temp,0),
           alen);
    if (a->sign)
        putc('-', f);
    decout(f,
           DIG(temp,0),
           alen);
}

/*
 * decout - given a base B digit string, print the number in base 10.
 */
static void decout(f, n, l)
    FILE *f;
    DIGIT *n;
    word l;
{
    DIGIT i = divi1(n, (word)10, n, l);

    if (cmpi1(n, (word)0, l))
        decout(f, n, l);
    putc('0' + i, f);
}

/*
 *  da -> dx
 */

void cpbignum(da, dx)
    dptr da, dx;
{
    struct b_bignum *a, *x;
    word alen = LEN(LrgInt(da));

    MemProtect(x = alcbignum(alen));
    a = LrgInt(da);
    bdcopy(DIG(a,0),
           DIG(x,0),
           alen);
    x->sign = a->sign;
    mkdesc(x, dx);
}

/*
 *  da + db -> dx
 */

void bigadd(da, db, dx)
    dptr da, db;
    dptr dx;
{
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;
    word c;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        a = LrgInt(da);
        b = LrgInt(db);
        if (a->sign == b->sign) {
            if (alen > blen) {
                MemProtect(x = alcbignum(alen + 1));
                c = add1(DIG(a,alen-blen),
                         DIG(b,0),
                         DIG(x,alen-blen+1),
                         blen);
                *DIG(x,0) =
                    addi1(DIG(a,0),
                          c,
                          DIG(x,1),
                          alen-blen);
            }
            else if (alen == blen) {
                MemProtect(x = alcbignum(alen + 1));
                *DIG(x,0) =
                    add1(DIG(a,0),
                         DIG(b,0),
                         DIG(x,1),
                         alen);
            }
            else {
                MemProtect(x = alcbignum(blen + 1));
                c = add1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen+1),
                         alen);
                *DIG(x,0) =
                    addi1(DIG(b,0),
                          c,
                          DIG(x,1),
                          blen-alen);
            }
            x->sign = a->sign;
        }
        else {
            if (alen > blen) {
                MemProtect(x = alcbignum(alen));
                c = sub1(DIG(a,alen-blen),
                         DIG(b,0),
                         DIG(x,alen-blen),
                         blen);
                subi1(DIG(a,0),
                      -c,
                      DIG(x,0),
                      alen-blen);
                x->sign = a->sign;
            }
            else if (alen == blen) {
                MemProtect(x = alcbignum(alen));
                if (cmp1(DIG(a,0),
                         DIG(b,0),
                         alen) > 0) {
                    (void)sub1(DIG(a,0),
                               DIG(b,0),
                               DIG(x,0),
                               alen);
                    x->sign = a->sign;
                }
                else {
                    (void)sub1(DIG(b,0),
                               DIG(a,0),
                               DIG(x,0),
                               alen);
                    x->sign = b->sign;
                }
            }
            else {
                MemProtect(x = alcbignum(blen));
                c = sub1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen),
                         alen);
                subi1(DIG(b,0),
                      -c,
                      DIG(x,0),
                      blen-alen);
                x->sign = b->sign;
            }
        }
        mkdesc(x, dx);
    }
    else if (Type(*da) == T_Lrgint)    /* bignum + integer */
        bigaddi(da, IntVal(*db), dx);
    else if (Type(*db) == T_Lrgint)    /* integer + bignum */
        bigaddi(db, IntVal(*da), dx);
    else {                             /* integer + integer */
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(IntVal(*da), &tdigits.blk, &td);
        bigaddi(&td, IntVal(*db), dx);
    }
}

/*
 *  da - db -> dx
 */ 

void bigsub(da, db, dx)
    dptr da, db, dx;
{
    struct descrip td;
    union word_b_bignum tdigits;
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;
    word c;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        a = LrgInt(da);
        b = LrgInt(db);
        if (a->sign != b->sign) {
            if (alen > blen) {
                MemProtect(x = alcbignum(alen + 1));
                c = add1(DIG(a,alen-blen),
                         DIG(b,0),
                         DIG(x,alen-blen+1),
                         blen);
                *DIG(x,0) =
                    addi1(DIG(a,0),
                          c,
                          DIG(x,1),
                          alen-blen);
            }
            else if (alen == blen) {
                MemProtect(x = alcbignum(alen + 1));
                *DIG(x,0) =
                    add1(DIG(a,0),
                         DIG(b,0),
                         DIG(x,1),
                         alen);
            }
            else {
                MemProtect(x = alcbignum(blen + 1));
                c = add1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen+1),
                         alen);
                *DIG(x,0) =
                    addi1(DIG(b,0),
                          c,
                          DIG(x,1),
                          blen-alen);
            }
            x->sign = a->sign;
        }
        else {
            if (alen > blen) {
                MemProtect(x = alcbignum(alen));
                c = sub1(DIG(a,alen-blen),
                         DIG(b,0),
                         DIG(x,alen-blen),
                         blen);
                subi1(DIG(a,0),
                      -c,
                      DIG(x,0),
                      alen-blen);
                x->sign = a->sign;
            }
            else if (alen == blen) {
                MemProtect(x = alcbignum(alen));
                if (cmp1(DIG(a,0),
                         DIG(b,0),
                         alen) > 0) {
                    (void)sub1(DIG(a,0),
                               DIG(b,0),
                               DIG(x,0),
                               alen);
                    x->sign = a->sign;
                }
                else {
                    (void)sub1(DIG(b,0),
                               DIG(a,0),
                               DIG(x,0),
                               alen);
                    x->sign = 1 ^ b->sign;
                }
            }
            else {
                MemProtect(x = alcbignum(blen));
                c = sub1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen),
                         alen);
                subi1(DIG(b,0),
                      -c,
                      DIG(x,0),
                      blen-alen);
                x->sign = 1 ^ b->sign;
            }
        }
        mkdesc(x, dx);
    }
    else if (Type(*da) == T_Lrgint)     /* bignum - integer */
        bigsubi(da, IntVal(*db), dx);
    else if (Type(*db) == T_Lrgint) {   /* integer - bignum */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(LrgInt(&td));
        blen = LEN(LrgInt(db));
        a = LrgInt(&td);
        b = LrgInt(db);
        if (a->sign != b->sign) {
            if (alen == blen) {
                MemProtect(x = alcbignum(alen + 1));
                *DIG(x,0) =
                    add1(DIG(a,0),
                         DIG(b,0),
                         DIG(x,1),
                         alen);
            }
            else {
                MemProtect(x = alcbignum(blen + 1));
                c = add1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen+1),
                         alen);
                *DIG(x,0) =
                    addi1(DIG(b,0),
                          c,
                          DIG(x,1),
                          blen-alen);
            }
            x->sign = a->sign;
        }
        else {
            if (alen == blen) {
                MemProtect(x = alcbignum(alen));
                if (cmp1(DIG(a,0),
                         DIG(b,0),
                         alen) > 0) {
                    (void)sub1(DIG(a,0),
                               DIG(b,0),
                               DIG(x,0),
                               alen);
                    x->sign = a->sign;
                }
                else {
                    (void)sub1(DIG(b,0),
                               DIG(a,0),
                               DIG(x,0),
                               alen);
                    x->sign = 1 ^ b->sign;
                }
            }
            else {
                MemProtect(x = alcbignum(blen));
                c = sub1(DIG(b,blen-alen),
                         DIG(a,0),
                         DIG(x,blen-alen),
                         alen);
                subi1(DIG(b,0),
                      -c,
                      DIG(x,0),
                      blen-alen);
                x->sign = 1 ^ b->sign;
            }
        }
        mkdesc(x, dx);
    }
    else {                              /* integer - integer */
        itobig(IntVal(*da), &tdigits.blk, &td);
        bigsubi(&td, IntVal(*db), dx);
    }
      
}

/*
 *  da * db -> dx
 */

void bigmul(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(alen + blen));
        mul1(DIG(a,0),
             DIG(b,0),
             DIG(x,0),
             alen, blen);
        x->sign = a->sign ^ b->sign;
        mkdesc(x, dx);
    }
    else if (Type(*da) == T_Lrgint)    /* bignum * integer */
        bigmuli(da, IntVal(*db), dx);
    else if (Type(*db) == T_Lrgint)    /* integer * bignum */
        bigmuli(db, IntVal(*da), dx);
    else {                             /* integer * integer */
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(IntVal(*da), &tdigits.blk, &td);
        bigmuli(&td, IntVal(*db), dx);
    }
}

/*
 *  da / db -> dx
 */
 
void bigdiv(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b, *x, *tu, *tv;
    word alen, blen;
    struct descrip td;
    union word_b_bignum tdigits;

    /* Put *da into large integer format. */
    if (Type(*da) != T_Lrgint) {
        itobig(IntVal(*da), &tdigits.blk, &td);
        da = &td;
    }

    if (Type(*db) == T_Lrgint) {         /* bignum / bignum */
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        if (alen < blen) {
            *dx = zerodesc;
            return;
        }
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(alen - blen + 1));
        if (blen == 1)
            divi1(DIG(a,0),
                  (word)*DIG(b,0),
                  DIG(x,0),
                  alen);
        else {
            MemProtect(tu = alcbignum(alen + 1));
            MemProtect(tv = alcbignum(blen));
            div1(DIG(a,0),
                 DIG(b,0),
                 DIG(x,0),
                 NULL, alen-blen, blen, tu, tv);
        }
        x->sign = a->sign ^ b->sign;
        mkdesc(x, dx);
    }
    else                                 /* bignum / integer */
        bigdivi(da, IntVal(*db), dx);
}

/*
 *  da % db -> dx
 */

void bigmod(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b, *x, *temp, *tu, *tv;
    word alen, blen;
    struct descrip td;
    union word_b_bignum tdigits;

    /* Put *da into large integer format. */
    if (Type(*da) != T_Lrgint) {
        itobig(IntVal(*da), &tdigits.blk, &td);
        da = &td;
    }

    if (Type(*db) == T_Lrgint) {        /* bignum % bignum */
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        if (alen < blen) {
            cpbignum(da, dx);
            return;
        }
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(blen));
        if (blen == 1) {
            MemProtect(temp = alcbignum(alen));
            *DIG(x,0) =
                divi1(DIG(a,0),
                      (word)*DIG(b,0),
                      DIG(temp,0),
                      alen);
        }
        else {
            MemProtect(tu = alcbignum(alen + 1));
            MemProtect(tv = alcbignum(blen));
            div1(DIG(a,0),
                 DIG(b,0),
                 NULL,
                 DIG(x,0),
                 alen-blen, blen, tu, tv);
        }
        x->sign = a->sign;
        mkdesc(x, dx);
    }
    else				       /* bignum % integer */
        bigmodi(da, IntVal(*db), dx);
}

/*
 *  -i -> dx
 */

void bigneg(da, dx)
    dptr da, dx;
{
    struct descrip td;
    union word_b_bignum tdigits;

    /* Put *da into large integer format. */
    if (Type(*da) != T_Lrgint) {
        itobig(IntVal(*da), &tdigits.blk, &td);
        da = &td;
    }
    LrgInt(da)->sign ^= 1;       /* Temporarily change the sign */
    cpbignum(da, dx);
    LrgInt(da)->sign ^= 1;       /* Change it back */
}

/*
 *  da ^ db -> dx
 */

int bigpow(da, db, dx)
    dptr da, db, dx;
{

    if (Type(*db) == T_Lrgint) {
        struct b_bignum *b;

        b = LrgInt ( db );


        if (Type(*da) == T_Lrgint) {
            if ( b->sign ) {
                /* bignum ^ -bignum = 0 */
                *dx = zerodesc;
                return Succeeded;
	    }
            else
                /* bignum ^ +bignum = guaranteed overflow */
                ReturnErrNum(307, Error);
        }
        else if ( b->sign )
            /* integer ^ -bignum */
            switch ( IntVal ( *da ) ) {
                case 1:
                    *dx = onedesc;
                    return Succeeded;
                case -1:
                    /* Result is +1 / -1, depending on whether *b is even or odd. */
                    if ( ( b->digits[ b->lsd ] ) & 01 )
                        MakeInt ( -1, dx );
                    else
                        *dx = onedesc;
                    return Succeeded;
                case 0:
                    ReturnErrNum(204,Error);
                default:
                    /* da ^ (negative int) = 0 for all non-special cases */
                    *dx = zerodesc;
                    return Succeeded;
	    }
        else {
            /* integer ^ +bignum */
            word n, blen;
            register DIGIT nth_dig, mask;

            b = LrgInt ( db );
            blen = LEN ( b );

            /* We scan the bits of b from the most to least significant.
             * The bit position in b is represented by the pair ( n, mask )
             * where n is the DIGIT number (0 = most sig.) and mask is the
             * the bit mask for the current bit.
             *
             * For each bit (most sig to least) in b,
             *  for each zero, square the partial result;
             *  for each one, square it and multiply it by a */
            *dx = onedesc;
            for ( n = 0; n < blen; ++n ) {
                nth_dig = *DIG ( b, n );
                for ( mask = 1 << ( NB - 1 ); mask; mask >>= 1 ) {
                    bigmul( dx, dx, dx);
                    if ( nth_dig & mask )
                        bigmul ( dx, da, dx );
                }
	    }
        }
        return Succeeded;
    }
    else if (Type(*da) == T_Lrgint)    /* bignum ^ integer */
        return bigpowi(da, IntVal(*db), dx);
    else                               /* integer ^ integer */
        return bigpowii(IntVal(*da), IntVal(*db), dx);
}

int bigpowri( a, db, drslt )
    double a;
    dptr   db, drslt;
{
    register double retval;
    register word n;
    register DIGIT nth_dig, mask;
    struct b_bignum *b;
    word blen;

    b = LrgInt ( db );
    blen = LEN ( b );
    if ( b->sign ) {
        if ( a == 0.0 )
            ReturnErrNum(204, Error);
        else
            a = 1.0 / a;
    }

    /* We scan the bits of b from the most to least significant.
     * The bit position in b is represented by the pair ( n, mask )
     * where n is the DIGIT number (0 = most sig.) and mask is the
     * the bit mask for the current bit.
     *
     * For each bit (most sig to least) in b,
     *  for each zero, square the partial result;
     *  for each one, square it and multiply it by a */
    retval = 1.0;
    for ( n = 0; n < blen; ++n ) {
        nth_dig = *DIG ( b, n );
        for ( mask = 1 << ( NB - 1 ); mask; mask >>= 1 ) {
            retval *= retval;
            if ( nth_dig & mask )
                retval *= a;
        }
    }

    MemProtect(BlkLoc(*drslt) = (union block *)alcreal(retval));
    drslt->dword = D_Real;
    return Succeeded;
}

/*
 *  iand(da, db) -> dx
 */

void bigand(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(xlen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] & bd[i];

        if (a->sign & b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*da) == T_Lrgint) {   /* iand(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(&td));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(&td);
        MemProtect(x = alcbignum(alen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] & bd[i];

        if (a->sign & b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*db) == T_Lrgint) {   /* iand(integer,bignum) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(LrgInt(&td));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(&td);
        b = LrgInt(db);
        MemProtect(x = alcbignum(blen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] & bd[i];

        if (a->sign & b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else {   /* iand(integer,integer) */
        MakeInt(IntVal(*da) & IntVal(*db), dx);
        return;
    }

    mkdesc(x, dx);
}

/*
 *  ior(da, db) -> dx
 */

void bigor(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(xlen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] | bd[i];

        if (a->sign | b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*da) == T_Lrgint) {   /* ior(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(&td));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(&td);
        MemProtect(x = alcbignum(alen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] | bd[i];

        if (a->sign | b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*db) == T_Lrgint) {   /* ior(integer,bignym) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(LrgInt(&td));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(&td);
        b = LrgInt(db);
        MemProtect(x = alcbignum(blen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }
        
        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] | bd[i];

        if (a->sign | b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else {   /* ior(integer,integer) */
        MakeInt(IntVal(*da) | IntVal(*db), dx);
        return;
    }

    mkdesc(x, dx);
}

/*
 *  xor(da, db) -> dx
 */

void bigxor(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(db);
        MemProtect(x = alcbignum(xlen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }

        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] ^ bd[i];

        if (a->sign ^ b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*da) == T_Lrgint) {   /* ixor(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(LrgInt(da));
        blen = LEN(LrgInt(&td));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(da);
        b = LrgInt(&td);
        MemProtect(x = alcbignum(alen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }

        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] ^ bd[i];

        if (a->sign ^ b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else if (Type(*db) == T_Lrgint) {   /* ixor(integer,bignum) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(LrgInt(&td));
        blen = LEN(LrgInt(db));
        xlen = alen > blen ? alen : blen;
        a = LrgInt(&td);
        b = LrgInt(db);
        MemProtect(x = alcbignum(blen));

        if (alen == xlen && !a->sign)
            ad = DIG(a,0);
        else {
            MemProtect(tad = alcbignum(xlen));
            ad = DIG(tad,0);
            bdzero(ad, xlen - alen);
            bdcopy(DIG(a,0),
                   &ad[xlen-alen], alen);
            if (a->sign)
                compl1(ad, ad, xlen);
        }

        if (blen == xlen && !b->sign)
            bd = DIG(b,0);
        else {
            MemProtect(tbd = alcbignum(xlen));
            bd = DIG(tbd,0);
            bdzero(bd, xlen - blen);
            bdcopy(DIG(b,0),
                   &bd[xlen-blen], blen);
            if (b->sign)
                compl1(bd, bd, xlen);
        }

        for (i = 0; i < xlen; i++)
            *DIG(x,i) =
                ad[i] ^ bd[i];

        if (a->sign ^ b->sign) {
            x->sign = 1;
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
    }
    else {   /* ixor(integer,integer) */
        MakeInt(IntVal(*da) ^ IntVal(*db), dx);
        return;
    }

    mkdesc(x, dx);
}

/*
 *  bigshift(da, db) -> dx
 */

void bigshift(da, db, dx)
    dptr da, db, dx;
{
    tended struct b_bignum *a, *x, *tad;
    word alen;
    word r = IntVal(*db) % NB;
    word q = (r >= 0 ? IntVal(*db) : (IntVal(*db) - (r += NB))) / NB;
    word xlen;
    DIGIT *ad;
    struct descrip td;
    union word_b_bignum tdigits;

    if (Type(*da) == T_Integer) {
        itobig(IntVal(*da), &tdigits.blk, &td);
        da = &td;
    }

    alen = LEN(LrgInt(da));
    xlen = alen + q + 1;
    if (xlen <= 0) {
        MakeInt(-LrgInt(da)->sign, dx);
        return;
    }
    else {
        a = LrgInt(da);
        MemProtect(x = alcbignum(xlen));

        if (a->sign) {
            MemProtect(tad = alcbignum(alen));
            ad = DIG(tad,0);
            bdcopy(DIG(a,0),
                   ad, alen);
            compl1(ad, ad, alen);
        }
        else
            ad = DIG(a,0);

        if (q >= 0) {
            *DIG(x,0) =
                shifti1(ad, r, (DIGIT)0,
                        DIG(x,1),
                        alen);
            bdzero(DIG(x,alen+1),
                   q);
        }
        else
            *DIG(x,0) =
                shifti1(ad, r, ad[alen+q] >> (NB-r),
                        DIG(x,1), alen+q);

        if (a->sign) {
            x->sign = 1;
            *DIG(x,0) |=
                B - (1 << r);
            compl1(DIG(x,0),
                   DIG(x,0),
                   xlen);
        }
        mkdesc(x, dx);
    }
}

/*
 *  negative if da < db
 *  zero if da == db
 *  positive if da > db
 */

word bigcmp(da, db)
    dptr da, db;
{
    struct b_bignum *a = LrgInt(da);
    struct b_bignum *b = LrgInt(db);
    word alen, blen; 

    if (Type(*da) == T_Lrgint && Type(*db) == T_Lrgint) {
        if (a->sign != b->sign)
            return (b->sign - a->sign);
        alen = LEN(a);
        blen = LEN(b);
        if (alen != blen)
            return (a->sign ? blen - alen : alen - blen);

        if (a->sign)
            return cmp1(DIG(b,0),
                        DIG(a,0),
                        alen);
        else
            return cmp1(DIG(a,0),
                        DIG(b,0),
                        alen);
    }
    else if (Type(*da) == T_Lrgint)    /* cmp(bignum, integer) */
        return bigcmpi(da, IntVal(*db));
    else if (Type(*db) == T_Lrgint)    /* cmp(integer, bignum) */
        return -bigcmpi(db, IntVal(*da));
    else { /* Two integers */
        if (IntVal(*da) > IntVal(*db))
            return 1;
        if (IntVal(*da) < IntVal(*db))
            return -1;
        return 0;
    }
}

/*
 *  ?da -> dx
 */  

void bigrand(da, dx)
    dptr da, dx;
{
    tended struct b_bignum *x, *a, *td, *tu, *tv;
    word alen = LEN(LrgInt(da));
    DIGIT *d;
    word i;
    double rval;

    MemProtect(x = alcbignum(alen));
    MemProtect(td = alcbignum(alen + 1));
    d = DIG(td,0);
    a = LrgInt(da);

    for (i = alen; i >= 0; i--) {
        rval = RandVal;
        d[i] = rval * B;
    }
    
    MemProtect(tu = alcbignum(alen + 2));
    MemProtect(tv = alcbignum(alen));
    div1(d, DIG(a,0),
         NULL,
         DIG(x,0),
         (word)1, alen, tu, tv);
    addi1(DIG(x,0),
          (word)1,
          DIG(x,0),
          alen);
    mkdesc(x, dx);
}

/*
 *  da + i -> dx
 */

static void bigaddi(da, i, dx)
    dptr da, dx;
    word i;
{
    tended struct b_bignum *a; 
    struct b_bignum *x; 
    word alen; 

    if (i < 0 && i > MinWord)
        bigsubi(da, -i, dx);
    else if (i < 0 || i >= B ) {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        bigadd(da, &td, dx);
    }
    else {
        alen = LEN(LrgInt(da));
        a = LrgInt(da);
        if (a->sign) {
            MemProtect(x = alcbignum(alen));
            subi1(DIG(a,0),
                  i,
                  DIG(x,0),
                  alen);
        }
        else {
            MemProtect(x = alcbignum(alen + 1));
            *DIG(x,0) =
                addi1(DIG(a,0),
                      i,
                      DIG(x,1),
                      alen);
        }
        x->sign = a->sign;
        mkdesc(x, dx);
    }
}

/*
 *  da - i -> dx
 */

static void bigsubi(da, i, dx)
    dptr da, dx;
    word i;
{
    tended struct b_bignum *a; 
    struct b_bignum *x; 
    word alen;

    if (i < 0 && i > MinWord)
        bigaddi(da, -i, dx);
    else if (i < 0 || i >= B) {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        bigsub(da, &td, dx);
    }
    else {
        alen = LEN(LrgInt(da));
        a = LrgInt(da);
        if (a->sign) {
            MemProtect(x = alcbignum(alen + 1));
            *DIG(x,0) =
                addi1(DIG(a,0),
                      i,
                      DIG(x,1),
                      alen);
        }
        else {
            MemProtect(x = alcbignum(alen));
            subi1(DIG(a,0),
                  i,
                  DIG(x,0),
                  alen);
        }
        x->sign = a->sign;
        mkdesc(x, dx);
    }
}

/*
 *  da * i -> dx
 */

static void bigmuli(da, i, dx)
    dptr da, dx;
    word i;
{
    tended struct b_bignum *a; 
    struct b_bignum *x; 
    word alen;

    if (i <= -B || i >= B) {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        bigmul(da, &td, dx);
    }
    else {
        alen = LEN(LrgInt(da));
        a = LrgInt(da);
        MemProtect(x = alcbignum(alen + 1));
        if (i >= 0)
            x->sign = a->sign;
        else {
            x->sign = 1 ^ a->sign;
            i = -i;
        }
        *DIG(x,0) =
            muli1(DIG(a,0),
                  i, 0,
                  DIG(x,1),
                  alen);
        mkdesc(x, dx);
    }
}

/*
 *  da / i -> dx
 */

static void bigdivi(da, i, dx)
    dptr da, dx;
    word i;
{
    tended struct b_bignum *a; 
    struct b_bignum *x; 
    word alen;

    if (i <= -B || i >= B) {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        bigdiv(da, &td, dx);
    }
    else {
        alen = LEN(LrgInt(da));
        a = LrgInt(da);
        MemProtect(x = alcbignum(alen));
        if (i >= 0)
            x->sign = a->sign;
        else {
            x->sign = 1 ^ a->sign;
            i = -i;
        }
        divi1(DIG(a,0),
              i,
              DIG(x,0),
              alen);
        mkdesc(x, dx);
    }
}

/*
 *  da % i -> dx
 */

static void bigmodi(da, i, dx)
    dptr da, dx;
    word i;
{
    tended struct b_bignum *a, *temp;
    word alen;
    word x;

    if (i <= -B || i >= B) {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        bigmod(da, &td, dx);
    }
    else {
        alen = LEN(LrgInt(da));
        a = LrgInt(da);
        temp = a;			/* avoid trash pointer */
        MemProtect(temp = alcbignum(alen));
        x = divi1(DIG(a,0),
                  Abs(i),
                  DIG(temp,0),
                  alen);
        if (a->sign)
            x = -x;
        MakeInt(x, dx);
    }
}

/*
 *  da ^ i -> dx
 */

static int bigpowi(da, i, dx)
    dptr da, dx;
    word i;
{
    int n = WordBits;
   
    if (i > 0) {
        /* scan bits left to right.  skip leading 1. */
        while (--n >= 0)
            if (i & ((word)1 << n))
                break;
        /* then, for each zero, square the partial result;
           for each one, square it and multiply it by a */
        *dx = *da;
        while (--n >= 0) {
            bigmul(dx, dx, dx);
            if (i & ((word)1 << n))
                bigmul(dx, da, dx);
        }
    }
    else if (i == 0) {
        *dx = onedesc;
    }
    else {
        *dx = zerodesc;
    }
    return Succeeded;
}

/*
 *  a ^ i -> dx
 */

static int bigpowii(a, i, dx)
    word a, i;
    dptr dx;
{
    word x, y;
    int n = WordBits;
    int isbig = 0;

    if (a == 0 || i <= 0) {              /* special cases */
        if (a == 0 && i <= 0)             /* 0 ^ negative -> error */
            ReturnErrNum(204,Error);
        if (i == 0) {
            *dx = onedesc;
            return Succeeded;
        }
        if (a == -1) {                    /* -1 ^ [odd,even] -> [-1,+1] */
            if (!(i & 1))
                a = 1;
        }
        else if (a != 1) {                /* 1 ^ any -> 1 */
            a = 0;
        }                   /* others ^ negative -> 0 */
        MakeInt(a, dx);
    }
    else {
        struct descrip td;
        union word_b_bignum tdigits;

        /* scan bits left to right.  skip leading 1. */
        while (--n >= 0)
            if (i & ((word)1 << n))
                break;
        /* then, for each zero, square the partial result;
           for each one, square it and multiply it by a */
        x = a;
        while (--n >= 0) {
            if (isbig) {
                bigmul(dx, dx, dx);
	    }
            else {
                y = mul(x, x);
                if (!over_flow)
                    x = y;
                else {
                    itobig(x, &tdigits.blk, &td);
                    bigmul(&td, &td, dx);
                    isbig = (Type(*dx) == T_Lrgint);
                } 
            }
            if (i & ((word)1 << n)) {
                if (isbig) {
                    bigmuli(dx, a, dx);
                }
                else {
                    y = mul(x, a);
                    if (!over_flow)
                        x = y;
                    else {
                        itobig(x, &tdigits.blk, &td);
                        bigmuli(&td, a, dx);
                        isbig = (Type(*dx) == T_Lrgint);
                    }
                }
            }
        }
        if (!isbig) {
            MakeInt(x, dx);
        }
    }
    return Succeeded;
}

/*
 *  negative if da < i
 *  zero if da == i
 *  positive if da > i
 */  
  
static word bigcmpi(da, i)
    dptr da;
    word i;
{
    struct b_bignum *a = LrgInt(da);
    word alen = LEN(a);

    if (i > -B && i < B) {
        if (i >= 0)
            if (a->sign)
                return -1;
            else
                return cmpi1(DIG(a,0),
                             i, alen);
        else
            if (a->sign)
                return -cmpi1(DIG(a,0),
                              -i, alen);
            else
                return 1;
    }
    else {
        struct descrip td;
        union word_b_bignum tdigits;

        itobig(i, &tdigits.blk, &td);
        return bigcmp(da, &td);
    }
}


/* These are all straight out of Knuth vol. 2, Sec. 4.3.1. */

/*
 *  (u,n) + (v,n) -> (w,n)
 *
 *  returns carry, 0 or 1
 */

static DIGIT add1(u, v, w, n)
    DIGIT *u, *v, *w;
    word n;
{
    uword dig, carry; 
    word i;

    carry = 0;
    for (i = n; --i >= 0; ) {
        dig = (uword)u[i] + v[i] + carry;
        w[i] = lo(dig);
        carry = hi(dig);
    }
    return carry;
}

/*
 *  (u,n) - (v,n) -> (w,n)
 *
 *  returns carry, 0 or -1
 */

static word sub1(u, v, w, n)
    DIGIT *u, *v, *w;
    word n;
{
    uword dig, carry; 
    word i;

    carry = 0;
    for (i = n; --i >= 0; ) {
        dig = (uword)u[i] - v[i] + carry;
        w[i] = lo(dig);
        carry = signed_hi(dig);
    }
    return carry;
}

/*
 *  (u,n) * (v,m) -> (w,m+n)
 */

static void mul1(u, v, w, n, m)
    DIGIT *u, *v, *w;
    word n, m;
{
    word i, j;
    uword dig, carry;

    bdzero(&w[m], n);

    for (j = m; --j >= 0; ) {
        carry = 0;
        for (i = n; --i >= 0; ) {
            dig = (uword)u[i] * v[j] + w[i+j+1] + carry;
            w[i+j+1] = lo(dig);
            carry = hi(dig);
        }
        w[j] = carry;
    }
}

/*
 *  (a,m+n) / (b,n) -> (q,m+1) (r,n)
 *
 *  if q or r is NULL, the quotient or remainder is discarded
 */

static void div1(a, b, q, r, m, n, tu, tv)
    DIGIT *a, *b, *q, *r;
    word m, n;
    struct b_bignum *tu, *tv;
{
    uword qhat, rhat;
    uword dig, carry;
    DIGIT *u, *v;
    word d;
    word i, j;

    u = DIG(tu,0);
    v = DIG(tv,0);

    /* D1 */
    for (d = 0; d < NB; d++)
        if (b[0] & (1 << (NB - 1 - d)))
            break;

    u[0] = shifti1(a, d, (DIGIT)0, &u[1], m+n);
    shifti1(b, d, (DIGIT)0, v, n);

    /* D2, D7 */
    for (j = 0; j <= m; j++) {
        /* D3 */
        if (u[j] == v[0]) {
            qhat = B - 1;
            rhat = (uword)v[0] + u[j+1];
        }
        else {
            uword numerator = dbl(u[j], u[j+1]);
            qhat = numerator / (uword)v[0];
            rhat = numerator % (uword)v[0];
        }

        while (rhat < (uword)B && qhat * (uword)v[1] > (uword)dbl(rhat, u[j+2])) {
            qhat -= 1;
            rhat += v[0];
        }
            
        /* D4 */
        carry = 0;
        for (i = n; i > 0; i--) {
            dig = u[i+j] - v[i-1] * qhat + carry;       /* -BSQ+B .. B-1 */
            u[i+j] = lo(dig);
            if ((uword)dig < (uword)B)
                carry = hi(dig);
            else carry = hi(dig) | -B;
        }
        carry = (word)(carry + u[j]) < 0;

        /* D5 */
        if (q)
            q[j] = qhat;

        /* D6 */
        if (carry) {
            if (q)
                q[j] -= 1;
            carry = 0;
            for (i = n; i > 0; i--) {
                dig = (uword)u[i+j] + v[i-1] + carry;
                u[i+j] = lo(dig);
                carry = hi(dig);
            }
        }
    }

    if (r) {
        if (d == 0)
            shifti1(&u[m+1], (word)d, (DIGIT)0, r, n);
        else
            r[0] = shifti1(&u[m+1], (word)(NB - d), u[m+n]>>d, &r[1], n - 1);
    }
}

/*
 *  - (u,n) -> (w,n)
 *
 */

static void compl1(u, w, n)
    DIGIT *u, *w;
    word n;
{
    uword dig, carry = 0;
    word i;

    for (i = n; --i >= 0; ) {
        dig = carry - u[i];
        w[i] = lo(dig);
        carry = signed_hi(dig);
    }
}

/*
 *  (u,n) : (v,n)
 */

static word cmp1(u, v, n)
    DIGIT *u, *v;
    word n;
{
    word i;

    for (i = 0; i < n; i++)
        if (u[i] != v[i])
            return u[i] > v[i] ? 1 : -1;
    return 0;
}

/*
 *  (u,n) + k -> (w,n)
 *
 *  k in 0 .. B-1
 *  returns carry, 0 or 1
 */

static DIGIT addi1(u, k, w, n)
    DIGIT *u, *w;
    word k;
    word n;
{
    uword dig, carry;
    word i;
    
    carry = k;
    for (i = n; --i >= 0; ) {
        dig = (uword)u[i] + carry;
        w[i] = lo(dig);
        carry = hi(dig);
    }
    return carry;
}

/*
 *  (u,n) - k -> (w,n)
 *
 *  k in 0 .. B-1
 *  u must be greater than k
 */

static void subi1(u, k, w, n)
    DIGIT *u, *w;
    word k;
    word n;
{
    uword dig, carry;
    word i;
    
    carry = -k;
    for (i = n; --i >= 0; ) {
        dig = (uword)u[i] + carry;
        w[i] = lo(dig);
        carry = signed_hi(dig);
    }
}

/*
 *  (u,n) * k + c -> (w,n)
 *
 *  k in 0 .. B-1
 *  returns carry, 0 .. B-1
 */

static DIGIT muli1(u, k, c, w, n)
    DIGIT *u, *w;
    word k;
    int c;
    word n;
{
    uword dig, carry;
    word i;

    carry = c;
    for (i = n; --i >= 0; ) {
        dig = (uword)k * u[i] + carry;
        w[i] = lo(dig);
        carry = hi(dig);
    }
    return carry;
}

/*
 *  (u,n) / k -> (w,n)
 *
 *  k in 0 .. B-1
 *  returns remainder, 0 .. B-1
 */

static DIGIT divi1(u, k, w, n)
    DIGIT *u, *w;
    word k;
    word n;
{
    uword dig, remain;
    word i;

    remain = 0;
    for (i = 0; i < n; i++) {
        dig = dbl(remain, u[i]);
        w[i] = dig / k;
        remain = dig % k;
    }
    return remain;
}

/*
 *  ((u,n) << k) + c -> (w,n)
 *
 *  k in 0 .. NB-1
 *  c in 0 .. B-1 
 *  returns carry, 0 .. B-1
 */

static DIGIT shifti1(u, k, c, w, n)
    DIGIT *u, c, *w;
    word k;
    word n;
{
    uword dig;
    word i;

    if (k == 0) {
        bdcopy(u, w, n);
        return 0;
    }
    
    for (i = n; --i >= 0; ) {
        dig = ((uword)u[i] << k) + c;
        w[i] = lo(dig);
        c = hi(dig);
    }
    return c;
}

/*
 *  (u,n) : k
 *
 *  k in 0 .. B-1
 */

static word cmpi1(u, k, n)
    DIGIT *u;
    word k;
    word n;
{
    word i;

    for (i = 0; i < n-1; i++)
        if (u[i])
            return 1;
    if (u[n - 1] == (DIGIT)k)
        return 0;
    return u[n - 1] > (DIGIT)k ? 1 : -1;
}

