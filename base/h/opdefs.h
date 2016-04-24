/*
 * Opcode definitions used in icode.
 */

/*
 * Operators. These must be in the same order as in odefs.h.  Not very nice,
 *  but it'll have to do until we think of another way to do this.  (It's
 *  always been thus.)
 */
#define Op_Asgn		  1
#define Op_Bang		  2
#define Op_Cat		  3
#define Op_Compl	  4
#define Op_Diff		  5
#define Op_Div		  6
#define Op_Eqv		  7
#define Op_Inter	  8
#define Op_Lconcat	  9
#define Op_Lexeq	 10
#define Op_Lexge	 11
#define Op_Lexgt	 12
#define Op_Lexle	 13
#define Op_Lexlt	 14
#define Op_Lexne	 15
#define Op_Minus	 16
#define Op_Mod		 17
#define Op_Mult		 18
#define Op_Neg		 19
#define Op_Neqv		 20
#define Op_Nonnull	 21
#define Op_Null		 22
#define Op_Number	 23
#define Op_Numeq	 24
#define Op_Numge	 25
#define Op_Numgt	 26
#define Op_Numle	 27
#define Op_Numlt	 28
#define Op_Numne	 29
#define Op_Plus		 30
#define Op_Power	 31
#define Op_Random	 32
#define Op_Rasgn	 33
#define Op_Refresh	 34
#define Op_Rswap	 35
#define Op_Sect		 36
#define Op_Size		 37
#define Op_Subsc	 38
#define Op_Swap		 39
#define Op_Tabmat	 40
#define Op_Toby		 41
#define Op_Union	 42
#define Op_Value	 43
#define Op_Activate      44
/*
 * Other instructions.
 */
#define Op_Coret         46
#define Op_Create        47
#define Op_Field         48
#define Op_Goto          49
#define Op_Int           50
#define Op_Keywd         51
#define Op_Limit         52
#define Op_Mark          53
#define Op_Unmark        54
#define Op_Cofail        55
#define Op_Static        56
#define Op_Global        57
#define Op_Apply         58
#define Op_Applyf        59
#define Op_Invoke        60
#define Op_Invokef       61
#define Op_IGoto         62
#define Op_EnterInit     63
#define Op_Fail          64
#define Op_Nil           65
#define Op_Const         66
#define Op_FrameVar      67
#define Op_Tmp           68
#if RealInDesc
#define Op_Real          69
#endif
#define Op_Move          70
#define Op_MoveLabel     71
#define Op_Deref         72
#define Op_Keyop         73
#define Op_Keyclo        74
#define Op_Resume        75
#define Op_Knull         76
#define Op_ScanSwap      77
#define Op_ScanSave      78
#define Op_ScanRestore   79
#define Op_SysErr        80
#define Op_Custom        81
#define Op_Halt          82
#define Op_MakeList      83
#define Op_Pop           84
#define Op_PopRepeat     85
#define Op_Suspend       87
#define Op_Return        88
#define Op_Exit          89
#define Op_EndProc       90
#define Op_CSuspend      91
#define Op_CReturn       92
#define Op_CFail         93
#define Op_TCaseInit     94
#define Op_TCaseInsert   95
#define Op_TCaseChoose   96
#define Op_TCaseChoosex  97
#define Op_GlobalVal     98
#define Op_Self          99
#define Op_Kyes         100
