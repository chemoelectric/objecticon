/*
 * monitor.h - This file contains definitions for the various
 * event codes and values that go to make up event streams.
 *
 */

/*
 * Note: the blank character should *not* be used as an event code.
 */

/*
 * Allocation events use lowercase codes.
 */

#define E_Lrgint	'\114'		/* Large integer allocation */
#define E_Real		'\144'		/* Real allocation */
#define E_Cset		'\145'		/* Cset allocation */
#define E_Record	'\150'		/* Record allocation */
#define E_Object	'\200'		/* Object allocation */
#define E_Cast	        '\201'		/* Cast allocation */
#define E_Methp	        '\202'		/* Methp allocation */
#define E_Ucs	        '\203'		/* Ucs allocation */
#define E_Tvsubs	'\151'		/* Substring tv allocation */
#define E_List		'\153'		/* List allocation */
#define E_Lelem		'\155'		/* List element allocation */
#define E_Table		'\156'		/* Table allocation */
#define E_Telem		'\157'		/* Table element allocation */
#define E_Tvtbl		'\160'		/* Table-element tv allocation */
#define E_Set		'\161'		/* Set allocation */
#define E_Selem		'\164'		/* Set element allocation */
#define E_Slots		'\167'		/* Hash header allocation */
#define E_Coexpr	'\170'		/* Co-expression allocation */
#define E_Refresh	'\171'		/* Refresh allocation */
#define E_Alien		'\172'		/* Alien allocation */
#define E_Free		'\132'		/* Free region */
#define E_String	'\163'		/* String allocation */

#define E_Prog          '\177'          /* Loaded program allocation */

/*
 * Some other monitoring codes.
 */
#define	E_BlkDeAlc	'\055'		/* Block deallocation */
#define	E_StrDeAlc	'\176'		/* String deallocation */

/*
 * These are not "events"; they are provided for uniformity in tools
 *  that deal with types.
 */
#define E_Integer	'\100'		/* Integer value pseudo-event */
#define E_Null		'\044'		/* Null value pseudo-event */
#define E_Proc		'\045'		/* Procedure value pseudo-event */
#define E_Kywdint	'\136'		/* Integer keyword value pseudo-event */
#define E_Kywdpos	'\046'		/* Position value pseudo-event */
#define E_Kywdsubj	'\052'		/* Subject value pseudo-event */

/*
 * Codes for main sequence events
 */

   /*
    * Timing events
    */
#define E_Tick		'\056'		/* Clock tick */


   /*
    * Code-location event
    */
#define E_Line		'\355'		/* Line change */
#define E_Fname		'\147'		/* Filename change */

   /*
    * Virtual-machine instructions
    */
#define E_Opcode	'\117'		/* Virtual-machine instruction */

   /*
    * Type-conversion events
    */
#define E_Aconv		'\111'		/* Conversion attempt */
#define E_Tconv		'\113'		/* Conversion target */
#define E_Nconv		'\116'		/* Conversion not needed */
#define E_Sconv		'\121'		/* Conversion success */
#define E_Fconv		'\112'		/* Conversion failure */

   /*
    * Structure events
    */
#define	E_Lbang		'\301'		/* List generation */
#define	E_Lcreate	'\302'		/* List creation */
#define	E_Lget		'\356'		/* List get/pop -- only E_Lget used */
#define	E_Lpop		'\356'		/* List get/pop */
#define	E_Lpull		'\304'		/* List pull */
#define	E_Lpush		'\305'		/* List push */
#define	E_Lput		'\306'		/* List put */
#define	E_Lrand		'\307'		/* List random reference */
#define	E_Lref		'\310'		/* List reference */
#define E_Lsub		'\311'		/* List subscript */
#define E_Ldelete	'\357'		/* List delete */
#define	E_Linsert	'\367'		/* List insertion */
#define	E_Rbang		'\312'		/* Record generation */
#define	E_Rcreate	'\313'		/* Record creation */
#define	E_Rrand		'\314'		/* Record random reference */
#define	E_Rref		'\315'		/* Record reference */
#define E_Rsub		'\316'		/* Record subscript */
#define	E_Sbang		'\317'		/* Set generation */
#define	E_Screate	'\320'		/* Set creation */
#define	E_Sdelete	'\321'		/* Set deletion */
#define	E_Sinsert	'\322'		/* Set insertion */
#define	E_Smember	'\323'		/* Set membership */
#define	E_Srand		'\336'		/* Set random reference */
#define	E_Sval		'\324'		/* Set value */
#define	E_Tbang		'\325'		/* Table generation */
#define	E_Tcreate	'\326'		/* Table creation */
#define	E_Tdelete	'\327'		/* Table deletion */
#define	E_Tinsert	'\330'		/* Table insertion */
#define	E_Tkey		'\331'		/* Table key generation */
#define	E_Tmember	'\332'		/* Table membership */
#define	E_Trand		'\337'		/* Table random reference */
#define	E_Tref		'\333'		/* Table reference */
#define	E_Tsub		'\334'		/* Table subscript */
#define	E_Tval		'\335'		/* Table value */
#define	E_Objectref	'\210'		/* Object reference */
#define E_Objectsub	'\211'		/* Object subscript */
#define	E_Classref	'\212'		/* Class reference */
#define E_Classsub	'\213'		/* Class subscript */
#define	E_Castref	'\214'		/* Cast reference */
#define E_Castsub	'\215'		/* Cast subscript */
#define	E_Objectcreate	'\216'		/* Object creation */

   /*
    * Scanning events
    */

#define E_Snew		'\340'		/* Scanning environment creation */
#define E_Sfail		'\341'		/* Scanning failure */
#define E_Ssusp		'\342'		/* Scanning suspension */
#define E_Sresum	'\343'		/* Scanning resumption */
#define E_Srem		'\344'		/* Scanning environment removal */
#define E_Spos		'\346'		/* Scanning position */

   /*
    * Assignment
    */

#define E_Assign	'\347'		/* Assignment */
#define	E_Value		'\350'		/* Value assigned */
#define E_Deref		'\363'		/* Dereference */


   /*
    * Sub-string assignment
    */

#define E_Ssasgn	'\354'		/* Sub-string assignment */

   /*
    * Co-expression events
    */

#define E_Coact		'\101'		/* Co-expression activation */
#define E_Coret		'\102'		/* Co-expression return */
#define E_Cofail	'\104'		/* Co-expression failure */
#define E_Cocreate	'\110'		/* Co-expression create operation */
#define	E_Cobang	'\222'		/* Co-expression generation */

   /*
    * Procedure events
    */

#define E_Pcall		'\103'		/* Procedure call */
#define E_Pfail		'\106'		/* Procedure failure */
#define E_Pret		'\122'		/* Procedure return */
#define E_Psusp		'\123'		/* Procedure suspension */
#define E_Presum	'\125'		/* Procedure resumption */
#define E_Prem		'\126'		/* Suspended procedure removal */


   /*
    * Garbage collections
    */

#define E_Collect	'\107'		/* Garbage collection */
#define E_EndCollect	'\360'		/* End of garbage collection */
#define E_TenureString	'\361'		/* Tenure a string region */
#define E_TenureBlock	'\362'		/* Tenure a block region */

/*
 * Termination Events
 */
#define E_Error		'\105'		/* Run-time error */

   /*
    * I/O events
    */
#define E_MXevent	'\370'		/* monitor input event */
#define E_Literal	'\364'          /* literal */




/* unused pool.  how many event codes are unused?

000 001 002 003 004 005 006 007
010 011 012 013 014 015 016 017
020 021 022 023 024 025 026 027
030 031 032 033 034 035 036 037
040 041 042 043 047
050 051 053 054 057
060 061 062 063 064 065 066 067
070 071 072 073 074 075 076 077

115 120
124 127 130 131 133 134 135
137 140 141 142 143 146
152 154
162 165 166
173 174 175 
204 205 206 207 217 220 221
223 224 225 226 227
230 231 232 233 234 235 236 237
240 241 242 243 244 245 246 247
250 251 252 253 254 255 256 257
260 261 262 263 264 265 266 267
270 271 272 273 274 275 276 277

300 303
345 351 352 353
365 366
371 372 373 374 375 376 377

 
*/
