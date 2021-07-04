/*
 *  Definitions for macros and manifest constants used in the compiler
 *  interpreter.
 */

/*
 *  Definitions common to the compiler and interpreter.
 */

#define MinListSlots	    8	/* number of elements in an expansion
				 * list element block  */

#define NextRand (k_random = (RandA * k_random + RandC) & MaxWord)
#define RandVal (RandScale * NextRand)

#define Pi 3.14159265358979323846264338327950288419716939937511
#define TwoPi (2 * Pi)
#define HalfPi (Pi / 2)

/*
 * Initialization states for classes and objects.
 */
#define Uninitialized 01
#define Initializing  02
#define Initialized   04

/*
 * Codes returned by runtime support routines.
 *  Note, some conversion routines also return type codes. Other routines may
 *  return positive values other than return codes. sort() places restrictions
 *  on Less, Equal, and Greater.
 */

#define Less		-1
#define Equal		0
#define Greater		1

#define CvtFail		-2
#define Cvt		-3
#define NoCvt		-4
#define Failed		-5
#define Defaulted	-6
#define Succeeded	-7
#define Error		-8
#define Readable	-9

#define GlobalName	0
#define StaticName	1
#define ParamName	2
#define LocalName	3
#define FieldName	4

/*
 * Pointer to block.
 */
#define BlkLoc(d)	((d).vword.bptr)

/*
 * Check for null-valued descriptor.
 */
#define ChkNull(d)	((d).dword==D_Null)

/*
 * Check for equivalent descriptors.
 */
#define EqlDesc(d1,d2)	((d1).dword == (d2).dword && BlkLoc(d1) == BlkLoc(d2))

/*
 * Integer value.
 */
#define IntVal(d)	((d).vword.integer)

/*
 * Offset from top of block to value of variable.
 */
#define Offset(d)	((d).dword & OffsetMask)

/*
 * Check for pointer.
 */
#define Pointer(d)	((d).dword & F_Ptr)

/*
 * Check for qualifier.
 */
#define Qual(d)		(!((d).dword & F_Nqual))

/*
 * Length of string.
 */
#define StrLen(q)	((q).dword)

/*
 * Location of first character of string.
 */
#define StrLoc(q)	((q).vword.sptr)

/*
 * Type of descriptor.
 */
#define Type(d)		(int)((d).dword & TypeMask)

/*
 * Check for variable.
 */
#define Var(d)		((d).dword & F_Var)

/*
 * Location of the value of a variable
 */
#define VarLoc(d)	((d).vword.descptr)

/*
 * Location of the value of a variable (given a D_StructVar in the dword)
 */
#define OffsetVarLoc(d)	((dptr)((word *)BlkLoc(d) + Offset(d)))

/*
 * Given a pointer p into part of string s, return the length of the
 * substring starting at p.
 */
#define SubStrLen(p, s) (StrLen(s) - DiffPtrs(p, StrLoc(s)))

/*
 * Given a pointer p and a string s, memcmp() p with the contents of
 * s.  NB: the caller must ensure that StrLen(s) bytes starting at p
 * are accessible.
 */
#define StrMemcmp(p, s) (memcmp(p, StrLoc(s), StrLen(s)))

/*
 * Check whether the string region has sufficient space remaining for
 * n UTF-8 characters of the maximum length.
 */
#define AmpleForUtf8(n) (UDiffPtrs(strend, strfree) / MAX_UTF8_SEQ_LEN >= (n))

/*
 * Macros for testing whether a descriptor is a large integer (stored
 * in a block) or a C integer (stored in the descriptor).
 */
#define IsLrgint(d)      ((d).dword == D_Lrgint)
#define IsCInteger(d)    ((d).dword == D_Integer)

#define MemProtect(notnull) do {if (!(notnull)) fatalerr(309,NULL);} while(0)

/*
 * This macro can be used with printf's "%.*s" format to output string descriptors.
 */
#define StrF(d) (int)StrLen(d), StrLoc(d)

#if RealInDesc
   #define DGetReal(d, r)    r = (d).vword.realval
   #define DSetReal(r, d)    (d).vword.realval = r
#else
   /*
    * Get floating-point number from real block.
    */
   #if DOUBLE_HAS_WORD_ALIGNMENT
      #define BGetReal(b, r)      r = (b).realval
      #define BSetReal(r, b)      (b).realval = r
   #else
      #define BGetReal(b, r)      memcpy(&r, (b).realval, sizeof(double))
      #define BSetReal(r, b)      memcpy((b).realval, &r, sizeof(double))
   #endif
   #define DGetReal(d, r)    BGetReal(RealBlk(d), r)
   #define DSetReal(r, d)    BSetReal(r, RealBlk(d))
#endif

/*
 * Construct an real descriptor
 */
#if RealInDesc
#define MakeReal(r, dp)   do {\
      DSetReal(r, *(dp));                             \
      (dp)->dword = D_Real;                     \
 } while (0)
#else
#define MakeReal(r, dp)  MakeDescMemProtect(D_Real, alcreal(r), dp)
#endif

/*
 * Construct an integer descriptor.
 */
#define MakeInt(i, dp)		do { \
                 	 (dp)->dword = D_Integer; \
                         IntVal(*dp) = (word)(i); \
			 } while (0)

/*
 * Construct a string descriptor.
 */
#define MakeStr(s, len, dp)      do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = (len); \
			 } while (0)

/*
 * Assign a C string to a descriptor. Assume it is reasonable to use the
 *   descriptor expression more than once, but not the string expression.
 */
#define CMakeStr(s, dp) do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = strlen(StrLoc(*dp));  \
			 } while (0)

/*
 * Construct a descriptor for a block type.  type is assumed to be a
 * simple integer expression.
 */
#define MakeDesc(type, expr, dp)  do {  \
                         BlkLoc(*dp) = (union block *)(expr);  \
                         (*dp).dword = (type);                 \
                         } while (0)


/*
 * Like MakeDesc, but expr is subject to MemProtect.  The macro
 * ensures that dp is changed atomically, even in the event that the
 * memory allocation fails.
 */
#define MakeDescMemProtect(type, expr, dp) do {  \
                         union block *_tmp;  \
                         MemProtect(_tmp = (union block *)(expr));  \
                         BlkLoc(*dp) = _tmp;  \
                         (*dp).dword = (type);  \
                         } while (0)

/*
 * Like MakeStr, but expr is subject to MemProtect.  Assuming that len
 * is a simple non-allocating expression, the macro ensures that dp is
 * changed atomically, even in the event that the memory allocation
 * fails.
 */
#define MakeStrMemProtect(expr, len, dp)  do {  \
                         char *_tmp;  \
                         MemProtect(_tmp = (expr));  \
                         StrLoc(*dp) = _tmp;  \
                         StrLen(*dp) = (len);  \
                         } while (0)


/*
 * Make a string descriptor from a string literal.
 */
#define LitStr(s, dp) do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = sizeof(s) - 1;       \
			 } while (0)

/*
 * Construct a descriptor for a variable.
 */
#define MakeVarDesc(type, expr, dp)  do {  \
                         VarLoc(*dp) = (expr);  \
                         (*dp).dword = (type);                 \
                         } while (0)

/*
 * Set &why to a string literal.
 */
#define LitWhy(s) LitStr(s,&kywd_why)

/*
 * Csets
 */

#define CsetSize (256/WordBits)	/* number of ints to hold 256 cset
				 *  bits. Use (256/WordBits)+1 if
				 *  256 % WordBits != 0 */

#define DoubleWords ((SIZEOF_DOUBLE + SIZEOF_VOIDP - 1) / SIZEOF_VOIDP)

/*
 * Address of word containing cset bit b
 */
#define CsetPtr(b,c)	((c) + (((b)&0377) >> LogWordBits))

/*
 * Offset in word of cset bit.
 */
#define CsetOff(b)	((b) & (WordBits-1))

/*
 * Set bit b in cset c.
 */
#define Setb(b,c)	(*CsetPtr(b,c) |= ((word)01 << CsetOff(b)))

/*
 * Test bit b in cset c.
 */
#define Testb(b,c)	((*CsetPtr(b,c) >> CsetOff(b)) & 01)

/*
 * Check whether a set or table needs resizing.
 */
#define SETP(p) ((struct b_set *)p)
#define TooCrowded(p) \
   ((SETP(p)->size > MaxHLoad*(SETP(p)->mask+1)) && (SETP(p)->hdir[HSegs-1] == NULL))
#define TooSparse(p) \
   ((SETP(p)->hdir[1] != NULL) && (SETP(p)->size < MinHLoad*(SETP(p)->mask+1)))

/*
 * Argument values for the built-in Icon user function "collect()".
 */
#define User    0                       /* collection triggered by user 
                                         * (calling collect function) */
#define Stack   1			/* collection triggered by stack allocation */
#define Strings	2			/* collection is for strings */
#define Blocks	3			/* collection is for blocks */

/*
 * Struct types for proc blocks and frames.
 */

#define C_Frame 0
#define P_Frame 1

#define C_Proc 0
#define P_Proc 1

/*
 * procedure block kinds (Proc.get_kind)
 */
#define Procedure  0
#define Function   1
#define Keyword    2
#define Operator   3
#define Internal   4

/*
 * Kinds of locals (Proc.get_local_kind)
 */
#define Argument   0
#define Dynamic    1
#define Static     2


/*
 * Get type of block pointed at by x.
 */
#define BlkType(x)   (*(word *)x)

/*
 * Type codes (descriptors and blocks).
 */
#define T_String	-1	/* string -- for reference; not used */
#define T_Null		 0	/* null value */
#define T_Integer	 1	/* integer */
#define T_Lrgint	 2	/* long integer */
#define T_Real		 3	/* real number */
#define T_Cset		 4	/* cset */
#define T_Constructor    5      /* record constructor */
#define T_Proc		 6	/* procedure */
#define T_Record	 7	/* record */
#define T_List		 8	/* list header */
#define T_Lelem		 9	/* list element */
#define T_Set		10	/* set header */
#define T_Selem		11	/* set element */
#define T_Table		12	/* table header */
#define T_Telem		13	/* table element */
#define T_Tvtbl		14	/* table element trapped variable */
#define T_Slots		15	/* set/table hash slots */
#define T_Tvsubs	16	/* substring trapped variable */
#define T_Methp         17      /* method pointer */
#define T_Coexpr	18	/* co-expression */
#define T_Ucs           19      /* unicode character string */
#define T_Kywdint	20	/* integer keyword */
#define T_Kywdpos	21	/* keyword &pos */
#define T_Kywdsubj	22	/* keyword &subject */
#define T_Kywdstr	23	/* string keyword */
#define T_Kywdany	24	/* keyword of any type */
#define T_Class         25      /* class */
#define T_Object        26      /* object */
#define T_Kywdhandler   27      /* keyword &handler */
#define T_Weakref       28      /* weak reference */
#define T_Yes           29      /* keyword &yes */
#define MaxType		29	/* maximum type number */

/*
 * Convenient macros for access to a block from a descriptor
 */
#define RealBlk(x) BlkLoc(x)->real
#define CsetBlk(x) BlkLoc(x)->cset
#define ProcBlk(x) BlkLoc(x)->proc
#define ListBlk(x) BlkLoc(x)->list
#define LelemBlk(x) BlkLoc(x)->lelem
#define TableBlk(x) BlkLoc(x)->table
#define TelemBlk(x) BlkLoc(x)->telem
#define SetBlk(x) BlkLoc(x)->set
#define SelemBlk(x) BlkLoc(x)->selem
#define RecordBlk(x) BlkLoc(x)->record
#define TvsubsBlk(x) BlkLoc(x)->tvsubs
#define TvtblBlk(x) BlkLoc(x)->tvtbl
#define CoexprBlk(x) BlkLoc(x)->coexpr
#define SlotsBlk(x) BlkLoc(x)->slots
#define ClassBlk(x) BlkLoc(x)->class
#define ObjectBlk(x) BlkLoc(x)->object
#define MethpBlk(x) BlkLoc(x)->methp
#define ConstructorBlk(x) BlkLoc(x)->constructor
#define UcsBlk(x) BlkLoc(x)->ucs
#define BignumBlk(x) BlkLoc(x)->bignum
#define WeakrefBlk(x) BlkLoc(x)->weakref

/*
 * Definitions for keywords.
 */

#define k_pos kywd_pos.vword.integer	/* value of &pos */
#define k_random kywd_ran.vword.integer	/* value of &random */
#define k_trace kywd_trace.vword.integer	/* value of &trace */
#define k_dump kywd_dump.vword.integer	/* value of &dump */
#define k_maxlevel kywd_maxlevel.vword.integer	/* value of &trace */
#define k_level k_current->level        /* value of &level */
/*
 * Descriptor types and flags.
 */

#define D_Null		(T_Null     | D_Typecode)
#define D_Integer	(T_Integer  | D_Typecode)
#define D_Lrgint	(T_Lrgint | D_Typecode | F_Ptr)
#if RealInDesc
#define D_Real		(T_Real     | D_Typecode)
#else
#define D_Real		(T_Real     | D_Typecode | F_Ptr)
#endif
#define D_Cset		(T_Cset     | D_Typecode | F_Ptr)
#define D_Proc		(T_Proc     | D_Typecode)
#define D_Class		(T_Class    | D_Typecode)
#define D_Object	(T_Object   | D_Typecode | F_Ptr)
#define D_Methp 	(T_Methp    | D_Typecode | F_Ptr)
#define D_Constructor 	(T_Constructor | D_Typecode)
#define D_List		(T_List     | D_Typecode | F_Ptr)
#define D_Lelem		(T_Lelem    | D_Typecode | F_Ptr)
#define D_Table		(T_Table    | D_Typecode | F_Ptr)
#define D_Telem		(T_Telem    | D_Typecode | F_Ptr)
#define D_Set		(T_Set      | D_Typecode | F_Ptr)
#define D_Selem		(T_Selem    | D_Typecode | F_Ptr)
#define D_Record	(T_Record   | D_Typecode | F_Ptr)
#define D_Tvsubs	(T_Tvsubs   | D_Typecode | F_Ptr | F_Var)
#define D_Tvtbl		(T_Tvtbl    | D_Typecode | F_Ptr | F_Var)
#define D_Kywdint	(T_Kywdint  | D_Typecode | F_Var)
#define D_Kywdpos	(T_Kywdpos  | D_Typecode | F_Var)
#define D_Kywdsubj	(T_Kywdsubj | D_Typecode | F_Var)
#define D_Coexpr	(T_Coexpr   | D_Typecode | F_Ptr)
#define D_Slots		(T_Slots    | D_Typecode | F_Ptr)
#define D_Kywdstr	(T_Kywdstr  | D_Typecode | F_Var)
#define D_Kywdany	(T_Kywdany  | D_Typecode | F_Var)
#define D_Ucs   	(T_Ucs      | D_Typecode | F_Ptr)
#define D_Kywdhandler	(T_Kywdhandler | D_Typecode | F_Var)
#define D_Weakref 	(T_Weakref  | D_Typecode | F_Ptr)
#define D_Yes		(T_Yes      | D_Typecode)

#define D_StructVar	(F_Var | F_Nqual | F_Ptr)
#define D_NamedVar     	(F_Var | F_Nqual)
#define D_Typecode	(F_Nqual | F_Typecode)
#define D_TendPtr       (F_Ptr | F_Nqual)
#define TypeMask	63	/* type mask */
#define OffsetMask	(~(F_Var | F_Nqual | F_Ptr | F_Typecode)) /* offset mask for variables */

#define G_Const         1
#define G_Package       2
#define G_Readable      4
#define G_Builtin       8

/*
 * "In place" dereferencing.
 */
#define Deref(d) if (Var(d)) deref(&d, &d)

#define ssize    (curstring->size)
#define strbase  (curstring->base)
#define strend   (curstring->end)
#define strfree  (curstring->free)

#define abrsize  (curblock->size)
#define blkbase  (curblock->base)
#define blkend   (curblock->end)
#define blkfree  (curblock->free)

   
/*
 * Macros related to function and operator definition.
 */
   
/*
 * Procedure block for a function.
 */
#define FncBlock(f,nargs,vararg,ntend,underef)                          \
        static struct sdescrip f##_name_desc = {sizeof(#f)-1,#f}; \
      	struct c_proc B##f = {\
      	T_Proc,\
        C_Proc, \
      	nargs,\
        vararg,\
        0,\
      	(dptr)&f##_name_desc, \
        (int (*)(struct c_frame *))Z##f,     \
        sizeof(struct f##_frame),\
        ntend,\
        underef};

#if MSWIN32
/*
 * Procedure block for a function in an exported windows DLL.
 */
#define FncBlockDLL(f,nargs,vararg,ntend,underef)                          \
        static struct sdescrip f##_name_desc = {sizeof(#f)-1,#f}; \
__declspec(dllexport)  \
      	struct c_proc B##f = {\
      	T_Proc,\
        C_Proc, \
      	nargs,\
        vararg,\
        0,\
      	(dptr)&f##_name_desc, \
        (int (*)(struct c_frame *))Z##f,     \
        sizeof(struct f##_frame),\
        ntend,\
        underef};
#endif				/* MSWIN32 */

/*
 * Procedure block for an operator.
 */
#define OpBlock(f,nargs,ntend,sname,underef)                            \
        static struct sdescrip f##_name_desc = {sizeof(sname)-1,sname}; \
   	struct c_proc B##f = {\
   	T_Proc,\
        C_Proc, \
   	nargs,\
        0,\
        0,\
      	(dptr)&f##_name_desc, \
   	(int (*)(struct c_frame *))O##f,\
        sizeof(struct f##_frame),\
        ntend,\
        underef};

#define KeywordBlock(f,ntend)                                           \
        static struct sdescrip f##_name_desc = {sizeof("&" #f)-1, "&" #f}; \
   	struct c_proc L##f = {\
   	T_Proc,\
        C_Proc, \
        0,\
        0,\
        0,\
      	(dptr)&f##_name_desc, \
   	(int (*)(struct c_frame *))K##f,\
        sizeof(struct f##_frame),\
        ntend,\
        0};


#define CustomProc(f,code,creates,nparam,ndynam,nclo,ntmp,nlab,nmark,sname) \
    static struct sdescrip f##_name_desc = {sizeof(sname) - 1, sname};\
    struct p_proc B##f = {\
   	T_Proc,\
        P_Proc,\
   	nparam,\
   	0,\
   	0,\
      	(dptr)&f##_name_desc, \
        code,\
        creates,\
   	ndynam,\
        0,0,0,\
        nclo,ntmp,nlab,nmark,\
        0,0,0};
   

/*
 * Miscellaneous macro definitions.
 */
   
#define kywd_handler (curpstate->Kywd_handler)
#define kywd_pos  (curpstate->Kywd_pos)
#define kywd_prog  (curpstate->Kywd_prog)
#define kywd_why  (curpstate->Kywd_why)
#define kywd_ran  (curpstate->Kywd_ran)
#define k_eventcode (curpstate->eventcode)
#define k_eventsource (curpstate->eventsource)
#define k_eventvalue (curpstate->eventval)
#define k_subject (curpstate->Kywd_subject)
#define kywd_trace  (curpstate->Kywd_trace)
#define kywd_dump  (curpstate->Kywd_dump)
#define kywd_maxlevel  (curpstate->Kywd_maxlevel)
#define code (curpstate->Code)
#define ecode (curpstate->Ecode)
#define classstatics (curpstate->ClassStatics)
#define eclassstatics (curpstate->EClassStatics)
#define classmethods (curpstate->ClassMethods)
#define eclassmethods (curpstate->EClassMethods)
#define classfields (curpstate->ClassFields)
#define eclassfields (curpstate->EClassFields)
#define classfieldlocs (curpstate->ClassFieldLocs)
#define eclassfieldlocs (curpstate->EClassFieldLocs)
#define fnames (curpstate->Fnames)
#define efnames (curpstate->Efnames)
#define globals (curpstate->Globals)
#define eglobals (curpstate->Eglobals)
#define gnames (curpstate->Gnames)
#define egnames (curpstate->Egnames)
#define gpackageflags (curpstate->GpackageFlags)
#define egpackageflags (curpstate->EgpackageFlags)
#define glocs (curpstate->Glocs)
#define eglocs (curpstate->Eglocs)
#define statics (curpstate->Statics)
#define estatics (curpstate->Estatics)
#define constants (curpstate->Constants)
#define econstants (curpstate->Econstants)
#define n_globals (curpstate->NGlobals)
#define n_statics (curpstate->NStatics)
#define n_constants (curpstate->NConstants)
#define strcons (curpstate->Strcons)
#define asciistrcons (curpstate->AsciiStrcons)
#define estrcons (curpstate->Estrcons)
#define filenms (curpstate->Filenms)
#define efilenms (curpstate->Efilenms)
#define ilines (curpstate->Ilines)
#define elines (curpstate->Elines)
#define current_line_ptr (curpstate->Current_line_ptr)
#define current_fname_ptr (curpstate->Current_fname_ptr)

#define curstring (curpstate->stringregion)
#define curblock  (curpstate->blockregion)
#define strtotal  (curpstate->stringtotal)
#define blktotal  (curpstate->blocktotal)
      
#define k_errornumber (curpstate->K_errornumber)
#define k_errortext   (curpstate->K_errortext)
#define k_errorvalue  (curpstate->K_errorvalue)
#define k_errorcoexpr (curpstate->K_errorcoexpr)
#define have_errval   (curpstate->Have_errval)
#define t_errornumber (curpstate->T_errornumber)
#define t_have_val    (curpstate->T_have_val)
#define t_errorvalue  (curpstate->T_errorvalue)
#define t_errortext   (curpstate->T_errortext)
      
#define k_main        (curpstate->K_main)
      
#define alcbignum	    (curpstate->Alcbignum)
#define alccoexp	    (curpstate->Alccoexp)
#define alccset	    (curpstate->Alccset)
#define alchash	    (curpstate->Alchash)
#define alcsegment    (curpstate->Alcsegment)
#define alclist_raw   (curpstate->Alclist_raw)
#define alclist	    (curpstate->Alclist)
#define alclstb	    (curpstate->Alclstb)
#define alcreal	    (curpstate->Alcreal)
#define alcrecd	    (curpstate->Alcrecd)
#define alcobject	    (curpstate->Alcobject)
#define alcmethp      (curpstate->Alcmethp)
#define alcweakref    (curpstate->Alcweakref)
#define alcucs        (curpstate->Alcucs)
#define alcselem      (curpstate->Alcselem)
#define alcstr        (curpstate->Alcstr)
#define alcsubs       (curpstate->Alcsubs)
#define alctelem      (curpstate->Alctelem)
#define alctvtbl      (curpstate->Alctvtbl)
#define dealcblk      (curpstate->Dealcblk)
#define dealcstr      (curpstate->Dealcstr)
#define reserve       (curpstate->Reserve)
#define general_call  (curpstate->GeneralCall)
#define general_access (curpstate->GeneralAccess)
#define general_invokef (curpstate->GeneralInvokef)

#define GetWord (*ipc++)
#define GetAddr ((word *)GetWord)
#if RealInDesc
#define GetReal (*(double *)(ipc++))
#endif

