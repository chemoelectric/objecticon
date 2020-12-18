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

#define B            ((word)1 << DigitBits)

/* Lrgint digits in a word, always 2 since a DIGIT contains half the number
 * of bits in a word. */

#define WORDLEN  2


/* lo(uword d) :            the low digit of a uword
   hi(uword d) :            the rest, d is unsigned
   signed_hi(uword d) :     the rest, d is signed
   dbl(DIGIT a, DIGIT b) : the two-digit uword [a,b] */

#define lo(d)        ((d) & (B - 1))
#define hi(d)        ((uword)(d) >> DigitBits)
#define dbl(a,b)     (((uword)(a) << DigitBits) + (b))

/* structure for a temporary bignum block that will hold an integer */
union word_b_bignum {
    char t[sizeof(struct b_bignum) + sizeof(DIGIT) * (WORDLEN - 1)];
    struct b_bignum blk;
};

/* temporary structure for bigprint.  Note that n decimal digits needs
 * about n * log(10)/log(2) = n * 3.32 binary digits, so rounding up
 * gives BigPrintDigits.
 */
#define BigPrintDigits (1 + ((MaxDigits + 1) * 4) / DigitBits)
union bigprint_b_bignum {
    char t[sizeof(struct b_bignum) + sizeof(DIGIT) * (BigPrintDigits - 1)];
    struct b_bignum blk;
};

#if ((-1) >> 1) < 0
#define signed_hi(d) ((word)(d) >> DigitBits)
#else
#define signbit      ((uword)1 << (WordBits - DigitBits - 1))
#define signed_hi(d) ((word)((((uword)(d) >> DigitBits) ^ signbit) - signbit))
#endif

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
static int bigcmpi	(dptr da, word i);

static DIGIT add1	(DIGIT *u, DIGIT *v, DIGIT *w, word n);
static word sub1	(DIGIT *u, DIGIT *v, DIGIT *w, word n);
static void mul1	(DIGIT *u, DIGIT *v, DIGIT *w, word n, word m);
static void div1	
(DIGIT *a, DIGIT *b, DIGIT *q, DIGIT *r, word m, word n, struct b_bignum *b1, struct b_bignum *b2);
static void compl1	(DIGIT *u, DIGIT *w, word n);
static int cmp1	(DIGIT *u, DIGIT *v, word n);
static DIGIT addi1	(DIGIT *u, word k, DIGIT *w, word n);
static void subi1	(DIGIT *u, word k, DIGIT *w, word n);
static DIGIT muli1	(DIGIT *u, word k, int c, DIGIT *w, word n);
static DIGIT divi1	(DIGIT *u, word k, DIGIT *w, word n);
static DIGIT shifti1	(DIGIT *u, word k, DIGIT c, DIGIT *w, word n);
static int cmpi1	(DIGIT *u, word k, word n);

#define bdzero(dest,l)  memset(dest, '\0', (l) * sizeof(DIGIT))
#define bdcopy(src, dest, l)  memcpy(dest, src, (l) * sizeof(DIGIT))


/* Debug function */
void showbig(FILE *f, struct b_bignum *x)
{
    int i;
    fprintf(f, "Sign=%d\n", x->sign);
    for (i = 0; i < LEN(x); ++i)
        fprintf(f, "   Dig %d = %.*lx\n", i, DigitBits/4, (long)*DIG(x, i));
}


/*
 * mkdesc -- put value into a descriptor
 */

static void mkdesc(struct b_bignum *x, dptr dx)
{
    word xlen, cmp;
    static DIGIT maxword[WORDLEN] = { (DIGIT)1 << ((WordBits - 1) % DigitBits) };

    /* suppress leading zero digits */

    while (x->msd != x->lsd &&
           *DIG(x,0) == 0)
        x->msd++;

    /* put it into a word if it fits, otherwise return the bignum */

    xlen = LEN(x);

    if (xlen < WORDLEN ||
        (xlen == WORDLEN &&
         ((cmp = cmp1(DIG(x,0), maxword, (word)WORDLEN)) < 0 ||
          (cmp == 0 && x->sign)))) {
        word val = -(word)*DIG(x,0);
        word i;

        for (i = x->msd; ++i <= x->lsd; )
            val = (val << DigitBits) - x->digits[i];
        if (!x->sign)
            val = -val;
        MakeInt(val, dx);
    }
    else {
        MakeDesc(D_Lrgint, x, dx);
    }
}

/*
 *  i -> big
 */

static void itobig(word i, struct b_bignum *x, dptr dx)
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

    MakeDesc(D_Lrgint, x, dx);
}

/*
 *  string -> bignum 
 */

int bigradix(int sign,                      /* '-' or not */
             int r,                         /* radix 2 .. 36 */
             dptr sd,                       /* input string (pointer to tended descriptor) */
             dptr result)                   /* result (also a pointer to tended descriptor) */
{
    struct b_bignum *b;   /* Doesn't need to be tended */
    DIGIT *bd;
    word len;
    int c;
    char *s, *end_s;     /* Don't need to be tended */

    if (r < 2 || r > 36)
        return 0;

    len = ceil(StrLen(*sd) * ln(r) / ln(B));

    MemProtect(b = alcbignum(len));
    bd = DIG(b,0);

    bdzero(bd, len);

    s = StrLoc(*sd);
    end_s = s + StrLen(*sd);
    while (s < end_s && oi_isalnum(*s)) {
        c = oi_isdigit(*s) ? (*s)-'0' : 10+(((*s)|(040))-'a');
        if (c >= r)
            return 0;
        muli1(bd, (word)r, c, bd, len);
        ++s;
    }

    /* Check for no digits */
    if (s == StrLoc(*sd))
        return 0;

    /*
     * Skip trailing white space and make sure there is nothing else left
     *  in the string.
     */
    while (s < end_s && oi_isspace(*s))
       ++s;
    if (s < end_s)
        return 0;

    if (sign == '-')
        b->sign = 1;

    /* put value into result and return success */
    mkdesc(b, result);
    return 1;
}

/*
 *  bignum -> real
 */

int bigtoreal(dptr da, double *d)
{
    word i;
    double r = 0;
    struct b_bignum *b = &BignumBlk(*da);

    for (i = b->msd; i <= b->lsd; i++)
        r = r * B + b->digits[i];
    if (b->sign)
        r = -r;

    /* Check for inf */
    if (!isfinite(r))
        return 0;

    *d = r;
    return 1;
}

/*
 *  double -> bignum
 */

int realtobig(double x, dptr dx)
{

    struct b_bignum *b;
    word i, blen;
    word d;
    int sgn;

    /* Try to catch the case of x being +/-"inf" - these values produce a spurious value of
     * blen below, which causes a segfault.
     */
    if (!isfinite(x))
        return 0;

    if (x >= Max((double)MinWord, -Big) && x <= Min((double)MaxWord, Big)) {
        MakeInt((word)x, dx);
        return 1;		/* got lucky; a simple integer suffices */
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
    return 1;
}

/*
 *  bignum -> string
 */

void bigtos(dptr da, dptr dx)
{
    tended struct b_bignum *a, *temp;
    word alen = LEN(&BignumBlk(*da));
    word slen = ceil(alen * ln(B) / ln(10));
    char *p, *q;

    a = &BignumBlk(*da);
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
    MakeStr(p, q - p, dx);
}

/*
 *  bignum -> file 
 * 
 *  This function does no allocation of any kind.
 */

void bigprint(FILE *f, dptr da)
{
    union bigprint_b_bignum tdigits;
    word alen = LEN(&BignumBlk(*da));
    word slen, dlen;
    tended struct b_bignum *blk = &BignumBlk(*da);

    slen = blk->lsd - blk->msd;
    dlen = slen * DigitBits * 0.3010299956639812	/* 1 / log2(10) */
        + log((double)blk->digits[blk->msd]) * 0.4342944819032518 + 0.5;
    /* 1 / ln(10) */
    if (dlen >= MaxDigits) {
        if (blk->sign)
            fprintf(f, "integer(-~10^" WordFmt ")", dlen);
        else
            fprintf(f, "integer(~10^" WordFmt ")", dlen);
        return;
    }

    tdigits.blk.msd = tdigits.blk.sign = 0;
    tdigits.blk.lsd = alen - 1;
    bdcopy(DIG(blk,0),
           DIG(&tdigits.blk,0),
           alen);
    if (blk->sign)
        putc('-', f);
    decout(f,
           DIG(&tdigits.blk,0),
           alen);
}

/*
 * decout - given a base B digit string, print the number in base 10.
 */
static void decout(FILE *f, DIGIT *n, word l)
{
    DIGIT i = divi1(n, (word)10, n, l);

    if (cmpi1(n, (word)0, l))
        decout(f, n, l);
    putc('0' + i, f);
}

/*
 *  da -> dx
 */

void cpbignum(dptr da, dptr dx)
{
    struct b_bignum *a, *x;
    word alen = LEN(&BignumBlk(*da));

    MemProtect(x = alcbignum(alen));
    a = &BignumBlk(*da);
    bdcopy(DIG(a,0),
           DIG(x,0),
           alen);
    x->sign = a->sign;
    mkdesc(x, dx);
}

/*
 *  da + db -> dx
 */

void bigadd(dptr da, dptr db, dptr dx)
{
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;
    word c;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da))    /* bignum + integer */
        bigaddi(da, IntVal(*db), dx);
    else if (IsLrgint(*db))    /* integer + bignum */
        bigaddi(db, IntVal(*da), dx);
    else {                             /* integer + integer */
        word irslt = add(IntVal(*da), IntVal(*db));
        if (over_flow) {
            struct descrip td;
            union word_b_bignum tdigits;
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigaddi(&td, IntVal(*db), dx);
        } else
            MakeInt(irslt, dx);
    }
}

/*
 *  da - db -> dx
 */ 

void bigsub(dptr da, dptr db, dptr dx)
{
    struct descrip td;
    union word_b_bignum tdigits;
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;
    word c;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da))     /* bignum - integer */
        bigsubi(da, IntVal(*db), dx);
    else if (IsLrgint(*db)) {   /* integer - bignum */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(td));
        blen = LEN(&BignumBlk(*db));
        a = &BignumBlk(td);
        b = &BignumBlk(*db);
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
        word irslt = sub(IntVal(*da), IntVal(*db));
        if (over_flow) {
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigsubi(&td, IntVal(*db), dx);
        } else
            MakeInt(irslt, dx);
    }
}

/*
 *  da * db -> dx
 */

void bigmul(dptr da, dptr db, dptr dx)
{
    tended struct b_bignum *a, *b;
    struct b_bignum *x;
    word alen, blen;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
        MemProtect(x = alcbignum(alen + blen));
        mul1(DIG(a,0),
             DIG(b,0),
             DIG(x,0),
             alen, blen);
        x->sign = a->sign ^ b->sign;
        mkdesc(x, dx);
    }
    else if (IsLrgint(*da))    /* bignum * integer */
        bigmuli(da, IntVal(*db), dx);
    else if (IsLrgint(*db))    /* integer * bignum */
        bigmuli(db, IntVal(*da), dx);
    else {                             /* integer * integer */
        word irslt = mul(IntVal(*da), IntVal(*db));
        if (over_flow) {
            struct descrip td;
            union word_b_bignum tdigits;
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigmuli(&td, IntVal(*db), dx);
        } else
            MakeInt(irslt, dx);
    }
}

/*
 *  da / db -> dx
 */
 
void bigdiv(dptr da, dptr db, dptr dx)
{
    struct descrip td;
    union word_b_bignum tdigits;

    if (IsLrgint(*da) && IsLrgint(*db)) {      /* bignum / bignum */
        tended struct b_bignum *a, *b, *x, *tu, *tv;
        word alen, blen;
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        if (alen < blen) {
            *dx = zerodesc;
            return;
        }
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da))    /* bignum / integer */
        bigdivi(da, IntVal(*db), dx);
    else if (IsLrgint(*db)) {   /* integer / bignum */
        /* Put *da into large integer format, recurse */
        itobig(IntVal(*da), &tdigits.blk, &td);
        bigdiv(&td, db, dx);
    } else {                             /* integer / integer */
        word irslt = div3(IntVal(*da), IntVal(*db));
        if (over_flow) {
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigdivi(&td, IntVal(*db), dx);
        }
        else
            MakeInt(irslt, dx);
    }
}

/*
 *  da % db -> dx
 */

void bigmod(dptr da, dptr db, dptr dx)
{
    struct descrip td;
    union word_b_bignum tdigits;

    if (IsLrgint(*da) && IsLrgint(*db)) {      /* bignum % bignum */
        tended struct b_bignum *a, *b, *x, *temp, *tu, *tv;
        word alen, blen;
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        if (alen < blen) {
            cpbignum(da, dx);
            return;
        }
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da))    /* bignum % integer */
        bigmodi(da, IntVal(*db), dx);
    else if (IsLrgint(*db)) {   /* integer % bignum */
        /* Put *da into large integer format, recurse */
        itobig(IntVal(*da), &tdigits.blk, &td);
        bigmod(&td, db, dx);
    } else {                             /* integer % integer */
        word irslt = mod3(IntVal(*da), IntVal(*db));
        if (over_flow) {
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigmodi(&td, IntVal(*db), dx);
        }
        else
            MakeInt(irslt, dx);
    }
}

/*
 *  -i -> dx
 */

void bigneg(dptr da, dptr dx)
{
    if (IsLrgint(*da)) {
        BignumBlk(*da).sign ^= 1;       /* Temporarily change the sign */
        cpbignum(da, dx);
        BignumBlk(*da).sign ^= 1;       /* Change it back */
    } else {                /* - integer */
        word irslt = neg(IntVal(*da));
        if (over_flow) {
            struct descrip td;
            union word_b_bignum tdigits;
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigneg(&td, dx);
        } else
            MakeInt(irslt, dx);
    }
}

/*
 *  da ^ db -> dx
 */

int bigpow(dptr da, dptr db, dptr dx)
{

    if (IsLrgint(*db)) {
        struct b_bignum *b;

        b = &BignumBlk(*db);

        if (IsLrgint(*da)) {
            if ( b->sign ) {
                /* bignum ^ -bignum = 0 */
                *dx = zerodesc;
                return Succeeded;
	    }
            else
                /* bignum ^ +bignum = guaranteed overflow */
                ReturnErrNum(203, Error);
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
                        *dx = minusonedesc;
                    else
                        *dx = onedesc;
                    return Succeeded;
                case 0:
                    ReturnErrNum(209,Error);
                default:
                    /* da ^ (negative int) = 0 for all non-special cases */
                    *dx = zerodesc;
                    return Succeeded;
	    }
        else {
            /* integer ^ +bignum */
            word n, blen;
            DIGIT nth_dig, mask;

            b = &BignumBlk(*db);
            blen = LEN(b);

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
                for ( mask = (DIGIT)1 << ( DigitBits - 1 ); mask; mask >>= 1 ) {
                    bigmul( dx, dx, dx);
                    if ( nth_dig & mask )
                        bigmul ( dx, da, dx );
                }
	    }
        }
        return Succeeded;
    }
    else if (IsLrgint(*da))    /* bignum ^ integer */
        return bigpowi(da, IntVal(*db), dx);
    else                               /* integer ^ integer */
        return bigpowii(IntVal(*da), IntVal(*db), dx);
}


/*
 *  a ^ db -> dx
 */

int bigpowri(double a, dptr db, dptr dx)
{
    double retval;

    if (IsCInteger(*db)) {   /* real ^ integer */
        word n = IntVal(*db);
        if (n < 0) {
            /*
             * a ^ n = ( 1/a ) * ( ( 1/a ) ^ ( -1 - n ) )
             *
             * (-1) - n never overflows, even when n == MinWord.
             */
            if (a == 0.0) 
                ReturnErrNum(209, Error);
            n = (-1) - n;
            a = 1.0 / a;
            retval = a;
        }
        else 	
            retval = 1.0;

        /* multiply retval by a ^ n */
        while (n > 0) {
            if (n & 01L)
                retval *= a;
            a *= a;
            n >>= 1;
        }
    } else {                    /* real ^ bignum */
        word n;
        DIGIT nth_dig, mask;
        struct b_bignum *b;
        word blen;
        b = &BignumBlk(*db);
        blen = LEN(b);
        if ( b->sign ) {
            if ( a == 0.0 )
                ReturnErrNum(209, Error);
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
            for ( mask = (DIGIT)1 << ( DigitBits - 1 ); mask; mask >>= 1 ) {
                retval *= retval;
                if ( nth_dig & mask )
                    retval *= a;
            }
        }
    }

    if (!isfinite(retval))
        ReturnErrNum(204, Error);

    MakeReal(retval, dx);
    return Succeeded;
}

/*
 *  iand(da, db) -> dx
 */

void bigand(dptr da, dptr db, dptr dx)
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da)) {   /* iand(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(td));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(td);
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
    else if (IsLrgint(*db)) {   /* iand(integer,bignum) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(td));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(td);
        b = &BignumBlk(*db);
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

void bigor(dptr da, dptr db, dptr dx)
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da)) {   /* ior(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(td));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(td);
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
    else if (IsLrgint(*db)) {   /* ior(integer,bignym) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(td));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(td);
        b = &BignumBlk(*db);
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

void bigxor(dptr da, dptr db, dptr dx)
{
    tended struct b_bignum *a, *b, *x, *tad, *tbd;
    word alen, blen, xlen;
    word i;
    DIGIT *ad, *bd;
    struct descrip td;
    union word_b_bignum tdigits;

    if (IsLrgint(*da) && IsLrgint(*db)) {
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(*db);
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
    else if (IsLrgint(*da)) {   /* ixor(bignum,integer) */
        itobig(IntVal(*db), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(*da));
        blen = LEN(&BignumBlk(td));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(*da);
        b = &BignumBlk(td);
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
    else if (IsLrgint(*db)) {   /* ixor(integer,bignum) */
        itobig(IntVal(*da), &tdigits.blk, &td);
        alen = LEN(&BignumBlk(td));
        blen = LEN(&BignumBlk(*db));
        xlen = alen > blen ? alen : blen;
        a = &BignumBlk(td);
        b = &BignumBlk(*db);
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
 *  bigshift(da, n) -> dx
 */

void bigshift(dptr da, word n, dptr dx)
{
    if (IsLrgint(*da)) {
        tended struct b_bignum *a, *x, *tad;
        word alen;
        word r = n % DigitBits;
        word q = (r >= 0 ? n : (n - (r += DigitBits))) / DigitBits;
        word xlen;
        DIGIT *ad;

        alen = LEN(&BignumBlk(*da));
        xlen = alen + q + 1;
        if (xlen <= 0) {
            MakeInt(-BignumBlk(*da).sign, dx);
            return;
        }
        else {
            a = &BignumBlk(*da);
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
                    shifti1(ad, r, (DIGIT)(ad[alen+q] >> (DigitBits-r)),
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
    } else {                     /* shift( integer, n ) */
        uword ci;			 /* shift in 0s, even if negative */
        struct descrip td;
        union word_b_bignum tdigits;
        if (n >= WordBits || 
            ((ci = (uword)IntVal(*da)) != 0 && n > 0 && (ci >= ((uword)1 << (WordBits - n -1))))) {
            /* Convert to bignum and recurse */
            itobig(IntVal(*da), &tdigits.blk, &td);
            bigshift(&td, n, dx);
        } else {
            /* Result will fit in a word */
            if (n <= -WordBits)
                MakeInt(IntVal(*da) >= 0 ? 0 : -1, dx);
            else if (n >= 0)
                MakeInt(ci << n, dx);
            else if (IntVal(*da) >= 0)
                MakeInt(ci >> -n, dx);
            else
                MakeInt(~(~ci >> -n), dx);	/* sign extending shift */
        }
    }
}

/*
 *  Less if da < db
 *  Equal if da == db
 *  Greater if da > db
 */

int bigcmp(dptr da, dptr db)
{
    if (IsLrgint(*da) && IsLrgint(*db)) {
        struct b_bignum *a = &BignumBlk(*da);
        struct b_bignum *b = &BignumBlk(*db);
        word alen, blen; 

        if (a->sign != b->sign)
            return (b->sign > a->sign) ? Greater : Less;
        alen = LEN(a);
        blen = LEN(b);
        if (alen != blen) {
            if (a->sign)
                return blen > alen ? Greater : Less;
            else
                return alen > blen ? Greater : Less;
        }

        if (a->sign)
            return cmp1(DIG(b,0),
                        DIG(a,0),
                        alen);
        else
            return cmp1(DIG(a,0),
                        DIG(b,0),
                        alen);
    }
    else if (IsLrgint(*da))    /* cmp(bignum, integer) */
        return bigcmpi(da, IntVal(*db));
    else if (IsLrgint(*db))    /* cmp(integer, bignum) */
        return -bigcmpi(db, IntVal(*da));
    else { /* Two integers */
        if (IntVal(*da) == IntVal(*db))
            return Equal;
        return (IntVal(*da) > IntVal(*db)) ? Greater : Less;
    }
}

/*
 *  Less if da < 0
 *  Equal if da == 0
 *  Greater if da > 0
 */

int bigsign(dptr da)
{
    if (IsLrgint(*da))
        return bigcmpi(da, 0);
    else {
        if (IntVal(*da) == 0)
            return Equal;
        return (IntVal(*da) > 0) ? Greater : Less;
    }
}

/*
 *  ?da -> dx
 */  

void bigrand(dptr da, dptr dx)
{
    if (IsLrgint(*da)) {
        tended struct b_bignum *x, *a, *td, *tu, *tv;
        word alen = LEN(&BignumBlk(*da));
        DIGIT *d;
        word i;

        MemProtect(x = alcbignum(alen));
        MemProtect(td = alcbignum(alen + 1));
        d = DIG(td,0);
        a = &BignumBlk(*da);

        for (i = alen; i >= 0; i--) {
            NextRand;
            /* Take the top DigitBits of k_random. */
            d[i] = k_random >> (DigitBits - 1);
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
    } else {
        double rval;
        word v = IntVal(*da);

        /*
         * v contains the integer value of da. If v is 0, return a
         * real in the range [0,1), else return an integer in the
         * range [1,v].
         */
        if (v == 0) {
            rval = RandVal;
            MakeReal(rval, dx);
        }
        else {
            rval = RandVal;
            rval *= v;
            MakeInt((word)rval + 1, dx);
        }
    }
}

/*
 *  da + i -> dx
 */

static void bigaddi(dptr da, word i, dptr dx)
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
        alen = LEN(&BignumBlk(*da));
        a = &BignumBlk(*da);
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

static void bigsubi(dptr da, word i, dptr dx)
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
        alen = LEN(&BignumBlk(*da));
        a = &BignumBlk(*da);
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

static void bigmuli(dptr da, word i, dptr dx)
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
        alen = LEN(&BignumBlk(*da));
        a = &BignumBlk(*da);
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

static void bigdivi(dptr da, word i, dptr dx)
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
        alen = LEN(&BignumBlk(*da));
        a = &BignumBlk(*da);
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

static void bigmodi(dptr da, word i, dptr dx)
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
        alen = LEN(&BignumBlk(*da));
        a = &BignumBlk(*da);
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

static int bigpowi(dptr da, word i, dptr dx)
{
    int n = WordBits;
   
    if (i > 0) {
        tended struct descrip tmp;
        /* scan bits left to right.  skip leading 1. */
        while (--n >= 0)
            if (i & ((word)1 << n))
                break;
        /* then, for each zero, square the partial result;
           for each one, square it and multiply it by a */
        tmp = *da;
        while (--n >= 0) {
            bigmul(&tmp, &tmp, &tmp);
            if (i & ((word)1 << n))
                bigmul(&tmp, da, &tmp);
        }
        *dx = tmp;
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

static int bigpowii(word a, word i, dptr dx)
{
    word x, y;
    int n = WordBits;
    int isbig = 0;

    if (a == 0 || i <= 0) {              /* special cases */
        if (a == 0 && i < 0)             /* 0 ^ negative -> error */
            ReturnErrNum(209,Error);
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
                    isbig = IsLrgint(*dx);
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
                        isbig = IsLrgint(*dx);
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
 *  Less if da < i
 *  Equal if da == i
 *  Greater if da > i
 */  
  
static int bigcmpi(dptr da, word i)
{
    struct b_bignum *a = &BignumBlk(*da);
    word alen = LEN(a);

    if (i > -B && i < B) {
        if (i >= 0)
            if (a->sign)
                return Less;
            else
                return cmpi1(DIG(a,0),
                             i, alen);
        else
            if (a->sign)
                return -cmpi1(DIG(a,0),
                              -i, alen);
            else
                return Greater;
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

static DIGIT add1(DIGIT *u, DIGIT *v, DIGIT *w, word n)
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

static word sub1(DIGIT *u, DIGIT *v, DIGIT *w, word n)
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

static void mul1(DIGIT *u, DIGIT *v, DIGIT *w, word n, word m)
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

static void div1(DIGIT *a, DIGIT *b, DIGIT *q, DIGIT *r,
                 word m, word n,
                 struct b_bignum *tu, struct b_bignum*tv)
{
    uword qhat, rhat;
    uword dig, carry;
    DIGIT *u, *v;
    word d;
    word i, j;

    u = DIG(tu,0);
    v = DIG(tv,0);

    /* D1 */
    for (d = 0; d < DigitBits; d++)
        if (b[0] & (1 << (DigitBits - 1 - d)))
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
            r[0] = shifti1(&u[m+1], (word)(DigitBits - d), (DIGIT)(u[m+n]>>d), &r[1], n - 1);
    }
}

/*
 *  - (u,n) -> (w,n)
 *
 */

static void compl1(DIGIT *u, DIGIT *w, word n)
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

static int cmp1(DIGIT *u, DIGIT *v, word n)
{
    word i;

    for (i = 0; i < n; i++)
        if (u[i] != v[i])
            return u[i] > v[i] ? Greater : Less;
    return Equal;
}

/*
 *  (u,n) + k -> (w,n)
 *
 *  k in 0 .. B-1
 *  returns carry, 0 or 1
 */

static DIGIT addi1(DIGIT *u, word k, DIGIT *w, word n)
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

static void subi1(DIGIT *u, word k, DIGIT *w, word n)
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

static DIGIT muli1(DIGIT *u, word k, int c, DIGIT *w, word n)
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

static DIGIT divi1(DIGIT *u, word k, DIGIT *w, word n)
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
 *  k in 0 .. DigitBits-1
 *  c in 0 .. B-1 
 *  returns carry, 0 .. B-1
 */

static DIGIT shifti1(DIGIT *u, word k, DIGIT c, DIGIT *w, word n)
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

static int cmpi1(DIGIT *u, word k, word n)
{
    word i;

    for (i = 0; i < n-1; i++)
        if (u[i])
            return Greater;
    if (u[n - 1] == (DIGIT)k)
        return Equal;
    return u[n - 1] > (DIGIT)k ? Greater : Less;
}

