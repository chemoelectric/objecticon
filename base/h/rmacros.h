/*
 *  Definitions for macros and manifest constants used in the compiler
 *  interpreter.
 */

/*
 *  Definitions common to the compiler and interpreter.
 */

#define MinListSlots	    8	/* number of elements in an expansion
				 * list element block  */

#define MaxCvtLen	    32	/* sufficient for holding result of real to string (rtos)
                                 * and integer to string (itos) in cnv.r */
#define MaxIn		  32767	/* largest number of bytes to read() at once */
#define RandA        1103515245	/* random seed multiplier */
#define RandC	      453816694	/* random seed additive constant */
#define RanScale 4.65661286e-10	/* random scale factor = 1/(2^31-1) */

#define Pi 3.14159265358979323846264338327950288419716939937511

/*
 * Initialization states for classes and objects.
 */
#define Uninitialized 01
#define Initializing  02
#define Initialized   04

#ifdef Graphics
   #define XKey_Window 0
   #define XKey_Fg 1
   
   #ifndef SHORT
      #define SHORT int
   #endif				/* SHORT */
   #ifndef LONG
      #define LONG int
   #endif				/* LONG */
   
   /*
    * Perform a "C" return, not processed by RTT
    */
   #define VanquishReturn(s) return s;
#endif					/* Graphics */

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
 *  Important note:  The code that follows is not strictly legal C.
 *   It tests to see if pointer p2 is between p1 and p3. This may
 *   involve the comparison of pointers in different arrays, which
 *   is not well-defined.  The casts of these pointers to unsigned "words"
 *   (longs or ints, depending) works with all C compilers and architectures
 *   on which Icon has been implemented.  However, it is possible it will
 *   not work on some system.  If it doesn't, there may be a "false
 *   positive" test, which is likely to cause a memory violation or a
 *   loop. It is not practical to implement Icon on a system on which this
 *   happens.
 */

#define InRange(p1,p2,p3) ((uword)(p2) >= (uword)(p1) && (uword)(p2) < (uword)(p3))

/*
 * Get floating-point number from real block.
 */
#ifdef DOUBLE_HAS_WORD_ALIGNMENT
   #define GetReal(b, r)      r = (b).realval
   #define SetReal(r, b)      (b).realval = r;
#else
   #define GetReal(b, r)      memcpy(&r, (b).realval, sizeof(double))
   #define SetReal(r, b)      memcpy((b).realval, &r, sizeof(double))
#endif

/*
 * Absolute value, maximum, and minimum.
 */
   #define Abs(x) (((x) < 0) ? (-(x)) : (x))
   #define Max(x,y)        ((x)>(y)?(x):(y))
   #define Min(x,y)        ((x)<(y)?(x):(y))


/*
 * Some C compilers take '\n' and '\r' to be the same, so the
 *  following definitions are used.
 */
   #define LineFeed  10
   #define CarriageReturn 13

/*
 * Construct an integer descriptor.
 */
#define MakeInt(i,dp)		do { \
                 	 (dp)->dword = D_Integer; \
                         IntVal(*dp) = (word)(i); \
			 } while (0)

/*
 * Construct a string descriptor.
 */
#define MakeStr(s,len,dp)      do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = (len); \
			 } while (0)

/*
 * Assign a C string to a descriptor. Assume it is reasonable to use the
 *   descriptor expression more than once, but not the string expression.
 */
#define CMakeStr(s,dp) do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = strlen(StrLoc(*dp));  \
			 } while (0)

/*
 * Make a string descriptor from a string literal.
 */
#define LitStr(s,dp) do { \
                 	 StrLoc(*dp) = (s); \
                         StrLen(*dp) = sizeof(s) - 1;       \
			 } while (0)

/*
 * Set &why to a string literal.
 */
#define LitWhy(s) LitStr(s,&kywd_why)

#define DiffPtrsBytes(p1,p2) DiffPtrs((char*)(p1), (char*)(p2))

#define StackAlign(x) ((word)(x) & ~((word)STACK_ALIGN_BYTES-1))

/*
 * Check for stack overflow
 */
#define CheckStack() \
do { \
    if (k_current == rootpstate.K_main) {  \
        if (DiffPtrsBytes(stackend,sp) < 4096)     \
            fatalerr(311, NULL); \
    } else { \
        int dummy = 0; \
        if (DiffPtrsBytes(&dummy, sp) < 4096)        \
            fatalerr(312, NULL); \
    } \
} while(0)

#define Unsupported \
do { \
       LitWhy("Function not supported"); \
       fail; \
} while(0)

#define CallerProc (&BlkLoc(*argp)->proc)

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
#define SP(p) ((struct b_set *)p)
#define TooCrowded(p) \
   ((SP(p)->size > MaxHLoad*(SP(p)->mask+1)) && (SP(p)->hdir[HSegs-1] == NULL))
#define TooSparse(p) \
   ((SP(p)->hdir[1] != NULL) && (SP(p)->size < MinHLoad*(SP(p)->mask+1)))

/*
 * Definitions and declarations used for storage management.
 */
#define F_Mark		0100000 	/* bit for marking blocks */

/*
 * Argument values for the built-in Icon user function "collect()".
 */
#define User    0                       /* collection triggered by user 
                                         * (calling collect function) */
#define Static  1			/* collection is for static region */
#define Strings	2			/* collection is for strings */
#define Blocks	3			/* collection is for blocks */

/*
 * Get type of block pointed at by x.
 */
#define BlkType(x)   (*(word *)x)

/*
 * BlkSize(x) takes the block pointed to by x and if the size of
 *  the block as indicated by bsizes[] is nonzero it returns the
 *  indicated size; otherwise it returns the second word in the
 *  block contains the size.
 */
#define BlkSize(x) (bsizes[*(word *)x & ~F_Mark] ? \
		     bsizes[*(word *)x & ~F_Mark] : *((word *)x + 1))

/*
 * Here are the events we support (in addition to keyboard characters)
 */
#define MOUSELEFT	(-1)
#define MOUSEMID	(-2)
#define MOUSERIGHT	(-3)
#define MOUSELEFTUP	(-4)
#define MOUSEMIDUP	(-5)
#define MOUSERIGHTUP	(-6)
#define MOUSELEFTDRAG	(-7)
#define MOUSEMIDDRAG	(-8)
#define MOUSERIGHTDRAG	(-9)
#define RESIZED		(-10)
#define WINDOWCLOSED    (-11)
#define MOUSEMOVED      (-12)
#define MOUSE4          (-13)
#define MOUSE5          (-14)
#define MOUSE4UP        (-16)
#define MOUSE5UP        (-17)
#define LASTEVENTCODE	MOUSE5UP

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
#define T_Refresh	17	/* refresh block */
#define T_Coexpr	18	/* co-expression */
#define T_Ucs           19      /* unicode character string */
#define T_Kywdint	20	/* integer keyword */
#define T_Kywdpos	21	/* keyword &pos */
#define T_Kywdsubj	22	/* keyword &subject */
#define T_Kywdstr	23	/* string keyword */
#define T_Kywdany	24	/* keyword &eventsource, etc. */
#define T_Class         25      /* class */
#define T_Object        26      /* object */
#define T_Cast          27      /* cast */
#define T_Methp         28      /* method pointer */
#define MaxType		28	/* maximum type number */

/*
 * Definitions for keywords.
 */

#define k_pos kywd_pos.vword.integer	/* value of &pos */
#define k_random kywd_ran.vword.integer	/* value of &random */
#define k_trace kywd_trc.vword.integer	/* value of &trace */
#define k_dump kywd_dmp.vword.integer	/* value of &dump */

/*
 * Descriptor types and flags.
 */

#define D_Null		(T_Null     | D_Typecode)
#define D_Integer	(T_Integer  | D_Typecode)
#define D_Lrgint	(T_Lrgint | D_Typecode | F_Ptr)
#define D_Real		(T_Real     | D_Typecode | F_Ptr)
#define D_Cset		(T_Cset     | D_Typecode | F_Ptr)
#define D_Proc		(T_Proc     | D_Typecode)
#define D_Class		(T_Class    | D_Typecode)
#define D_Object	(T_Object   | D_Typecode | F_Ptr)
#define D_Cast  	(T_Cast     | D_Typecode | F_Ptr)
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
#define D_Refresh	(T_Refresh  | D_Typecode | F_Ptr)
#define D_Coexpr	(T_Coexpr   | D_Typecode | F_Ptr)
#define D_Slots		(T_Slots    | D_Typecode | F_Ptr)
#define D_Kywdstr	(T_Kywdstr  | D_Typecode | F_Var)
#define D_Kywdany	(T_Kywdany  | D_Typecode | F_Var)
#define D_Ucs   	(T_Ucs      | D_Typecode | F_Ptr)

#define D_StructVar	(F_Var | F_Nqual | F_Ptr)
#define D_NamedVar     	(F_Var | F_Nqual)
#define D_Typecode	(F_Nqual | F_Typecode)

#define TypeMask	63	/* type mask */
#define OffsetMask	(~(F_Var | F_Nqual | F_Ptr | F_Typecode)) /* offset mask for variables */

/*
 * "In place" dereferencing.
 */
#define Deref(d) if (Var(d)) deref(&d, &d)

/*
 * Construct a substring trapped variable.
 */
#define SubStr(dest,var,len,pos)\
   if ((var)->dword == D_Tvsubs)\
      (dest)->vword.bptr = (union block *)alcsubs(len, (pos) +\
         BlkLoc(*(var))->tvsubs.sspos - 1, &BlkLoc(*(var))->tvsubs.ssvar);\
   else\
      (dest)->vword.bptr = (union block *)alcsubs(len, pos, (var));\
   (dest)->dword = D_Tvsubs;


#define ssize    (curstring->size)
#define strbase  (curstring->base)
#define strend   (curstring->end)
#define strfree  (curstring->free)

#define abrsize  (curblock->size)
#define blkbase  (curblock->base)
#define blkend   (curblock->end)
#define blkfree  (curblock->free)

   
   /*
    * Definitions for the interpreter.
    */
   
   /*
    * Codes returned by invoke to indicate action.
    */
   #define I_Builtin	201	/* A built-in routine is to be invoked */
   #define I_Fail	202	/* goal-directed evaluation failed */
   #define I_Continue	203	/* Continue execution in the interp loop */
   #define I_Vararg	204	/* A function with a variable number of args */
   
   /*
    * Generator types.
    */
   #define G_Csusp		1
   #define G_Esusp		2
   #define G_Psusp		3
   #define G_Fsusp		4
   #define G_Osusp		5
   
   /*
    * Evaluation stack overflow margin
    */
   #define PerilDelta 100
   
   /*
    * Macro definitions related to descriptors.
    */
   
   /*
    * The following code is operating-system dependent [@rt.01].  Define
    *  PushAval for computers that store longs and pointers differently.
    */
   
   #if PORT
      #define PushAVal(x) PushVal(x)
      Deliberate Syntax Error
   #endif				/* PORT */
   
   #if UNIX
      #define PushAVal(x) PushVal(x)
   #endif		
   
   #if MSWIN32
         static union {
                char *stkadr;
                word stkint;
            } stkword;
         
         #define PushAVal(x)  {sp++; \
         			stkword.stkadr = (char *)(x); \
         			*sp = stkword.stkint;}
   #endif				/* MSWIN32 */
   
   /*
    * End of operating-system specific code.
    */
   
   /*
    * Macros for pushing values on the interpreter stack.
    */
   
   /*
    * Push descriptor.
    */
   #define PushDesc(d)	{*++sp = ((d).dword); sp++;*sp =((d).vword.integer);}
   
   /*
    * Push null-valued descriptor.
    */
   #define PushNull	{*++sp = D_Null; sp++; *sp = 0;}
   
   /*
    * Push word.
    */
   #define PushVal(v)	{*++sp = (word)(v);}
   
   /*
    * Macros related to function and operator definition.
    */
   
   /*
    * Procedure block for a function.
    */
   #define FncBlock(f,nargs,deref) \
      	struct b_iproc Cat(B,f) = {\
      	T_Proc,\
      	sizeof(struct b_proc),\
      	Cat(Z,f),\
      	nargs,\
      	0,\
      	deref,\
        0,0,0,0,  \
      	{sizeof(Lit(f))-1,Lit(f)},\
        0,0};

   /*
    * Procedure block for an operator.
    */
   #define OpBlock(f,nargs,sname,deref)\
   	struct b_iproc Cat(B,f) = {\
   	T_Proc,\
   	sizeof(struct b_proc),\
   	Cat(O,f),\
   	nargs,\
   	0,\
   	deref,\
   	0,0,0,0,                                \
   	{sizeof(sname)-1,sname},\
        0,0};


   #define KeywordBlock(f)
   
   /*
    * Macros to access Icon arguments in C functions.
    */
   
   /*
    * n-th argument.
    */
   #define Arg(n)	 	(cargp[n])
   
   /*
    * Type field of n-th argument.
    */
   #define ArgType(n)	(cargp[n].dword)

   /*
    * Value field of n-th argument.
    */
   #define ArgVal(n)	(cargp[n].vword.integer)
   
   /*
    * Specific arguments.
    */
   #define Arg0	(cargp[0])
   #define Arg1	(cargp[1])
   #define Arg2	(cargp[2])
   #define Arg3	(cargp[3])
   #define Arg4	(cargp[4])
   #define Arg5	(cargp[5])
   #define Arg6	(cargp[6])
   #define Arg7	(cargp[7])
   #define Arg8	(cargp[8])
   
   /*
    * Miscellaneous macro definitions.
    */
   
      #define kywd_err  (curpstate->Kywd_err)
      #define kywd_pos  (curpstate->Kywd_pos)
      #define kywd_prog  (curpstate->Kywd_prog)
      #define kywd_why  (curpstate->Kywd_why)
      #define kywd_ran  (curpstate->Kywd_ran)
      #define k_eventcode (curpstate->eventcode)
      #define k_eventsource (curpstate->eventsource)
      #define k_eventvalue (curpstate->eventval)
      #define k_subject (curpstate->Kywd_subject)
      #define kywd_trc  (curpstate->Kywd_trc)
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
      #define classes (curpstate->Classes)
      #define records (curpstate->Records)
      #define fnames (curpstate->Fnames)
      #define efnames (curpstate->Efnames)
      #define globals (curpstate->Globals)
      #define eglobals (curpstate->Eglobals)
      #define gnames (curpstate->Gnames)
      #define egnames (curpstate->Egnames)
      #define glocs (curpstate->Glocs)
      #define eglocs (curpstate->Eglocs)
      #define statics (curpstate->Statics)
      #define estatics (curpstate->Estatics)
      #define n_globals (curpstate->NGlobals)
      #define n_statics (curpstate->NStatics)
      #define strcons (curpstate->Strcons)
      #define estrcons (curpstate->Estrcons)
      #define filenms (curpstate->Filenms)
      #define efilenms (curpstate->Efilenms)
      #define ilines (curpstate->Ilines)
      #define elines (curpstate->Elines)
      #define current_line_ptr (curpstate->Current_line_ptr)
      #define current_fname_ptr (curpstate->Current_fname_ptr)
      #define main_proc (curpstate->MainProc)

      #define coexp_ser (curpstate->Coexp_ser)
      #define list_ser  (curpstate->List_ser)
      #define set_ser   (curpstate->Set_ser)
      #define table_ser (curpstate->Table_ser)
      
      #define curstring (curpstate->stringregion)
      #define curblock  (curpstate->blockregion)
      #define strtotal  (curpstate->stringtotal)
      #define blktotal  (curpstate->blocktotal)
      
      #define coll_user (curpstate->colluser)
      #define coll_stat (curpstate->collstat)
      #define coll_str  (curpstate->collstr)
      #define coll_blk  (curpstate->collblk)
      
      #define lastop    (curpstate->Lastop)
      #define lastopnd  (curpstate->Lastopnd)

      #define xargp     (curpstate->Xargp)
      #define xnargs    (curpstate->Xnargs)
      #define xfno      (curpstate->Xfno)
      #define value_tmp (curpstate->Value_tmp)
      
      #define k_current     (curpstate->K_current)
      #define k_errornumber (curpstate->K_errornumber)
      #define k_errortext   (curpstate->K_errortext)
      #define k_errorvalue  (curpstate->K_errorvalue)
      #define have_errval   (curpstate->Have_errval)
      #define t_errornumber (curpstate->T_errornumber)
      #define t_have_val    (curpstate->T_have_val)
      #define t_errorvalue  (curpstate->T_errorvalue)
      #define t_errortext   (curpstate->T_errortext)
      
      #define k_main        (curpstate->K_main)
      
      #define cplist	    (curpstate->Cplist)
      #define cpset	    (curpstate->Cpset)
      #define cptable	    (curpstate->Cptable)
      #define interp	    (curpstate->Interp)
      #define cnv_cset	    (curpstate->Cnvcset)
      #define cnv_ucs	    (curpstate->Cnvucs)
      #define cnv_int	    (curpstate->Cnvint)
      #define cnv_real	    (curpstate->Cnvreal)
      #define cnv_str	    (curpstate->Cnvstr)
      #define cnv_tstr	    (curpstate->Cnvtstr)
      #define deref	    (curpstate->Deref)
      #define alcbignum	    (curpstate->Alcbignum)
      #define alccset	    (curpstate->Alccset)
      #define alchash	    (curpstate->Alchash)
      #define alcsegment    (curpstate->Alcsegment)
      #define alclist_raw   (curpstate->Alclist_raw)
      #define alclist	    (curpstate->Alclist)
      #define alclstb	    (curpstate->Alclstb)
      #define alcreal	    (curpstate->Alcreal)
      #define alcrecd	    (curpstate->Alcrecd)
      #define alcobject	    (curpstate->Alcobject)
      #define alccast  	    (curpstate->Alccast)
      #define alcmethp      (curpstate->Alcmethp)
      #define alcucs        (curpstate->Alcucs)
      #define alcrefresh    (curpstate->Alcrefresh)
      #define alcselem      (curpstate->Alcselem)
      #define alcstr        (curpstate->Alcstr)
      #define alcsubs       (curpstate->Alcsubs)
      #define alctelem      (curpstate->Alctelem)
      #define alctvtbl      (curpstate->Alctvtbl)
      #define dealcblk      (curpstate->Dealcblk)
      #define dealcstr      (curpstate->Dealcstr)
      #define reserve       (curpstate->Reserve)
      #define field_access  (curpstate->FieldAccess)
      #define invokef_access (curpstate->InvokefAccess)
      #define invoke        (curpstate->Invoke)

      #define CHANGEPROGSTATE(p) if (((p)!=curpstate)) { changeprogstate(p); }
   

/*
 * Constants controlling expression evaluation.
 */
   #define A_Resume	1	/* routine failed */
   #define A_Pret_uw	2	/* interp unwind for Op_Pret */
   #define A_Unmark_uw	3	/* interp unwind for Op_Unmark */
   #define A_Pfail_uw	4	/* interp unwind for Op_Pfail */
   #define A_Lsusp_uw	5	/* interp unwind for Op_Lsusp */
   #define A_Eret_uw	6	/* interp unwind for Op_Eret */
   #define A_Continue	7	/* routine returned */
   #define A_Coact	8	/* co-expression activated */
   #define A_Coret	9	/* co-expression returned */
   #define A_Cofail	10	/* co-expression failed */
   #define A_MTEvent	11	/* multithread event */
   #define A_Trapret	12	/* Return from stub  */
   #define A_Trapfail	13	/* Fail from stub  */

#if MSWIN32
      #define ptr2word(x) (uword)x
      #define word2ptr(x) ((char *)x)
#endif					/* MSWIN32 */

#if MSWIN32
#ifndef S_ISDIR
#define S_ISDIR(mod) ((mod) & _S_IFDIR)
#endif					/* no S_ISDIR */
#endif					/* MSWIN32 */
