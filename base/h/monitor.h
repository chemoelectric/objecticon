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
#define E_String	'\163'		/* String allocation */
#define E_Weakref	'\162'		/* Weakref allocation */

#define E_Prog          '\177'          /* Loaded program allocation */

/*
 * Some other monitoring codes.
 */
#define	E_BlkDeAlc	'\055'		/* Block deallocation */
#define	E_StrDeAlc	'\176'		/* String deallocation */
#define E_Scan		'\300'		/* String scanning operation */
#define E_Limit		'\303'		/* Limitation operation */
#define E_Timer         '\340'		/* Timer expiry event */


   /*
    * Type-conversion events
    */
#define E_CnvCDbl	'\111'		/* Conversion to C double */
#define E_CnvCInt	'\113'		/* Conversion to C integer */
#define E_CnvCset	'\116'		/* Conversion to cset */
#define E_CnvUcs	'\121'		/* Conversion to ucs */
#define E_CnvStrOrUcs	'\112'		/* Conversion to string or ucs */
#define E_CnvECInt	'\270'		/* Conversion to exact C integer */
#define E_CnvEInt	'\271'		/* Conversion to exact integer */
#define E_CnvInt	'\272'		/* Conversion to integer */
#define E_CnvReal	'\273'		/* Conversion to real */
#define E_CnvStr	'\274'		/* Conversion to string */
#define E_CnvCStr	'\275'		/* Conversion to C string */

   /*
    * Structure events
    */
#define	E_Lbang		'\301'		/* List generation */
#define	E_Lcreate	'\302'		/* List creation */
#define	E_Lget		'\356'		/* List get/pop */
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
#define	E_Objectcreate	'\216'		/* Object creation */
#define E_Lclear	'\223'		/* List clear */
#define	E_Sclear	'\224'		/* Set clear */
#define	E_Tclear	'\225'		/* Table clear */

   /*
    * Assignment
    */

#define E_Assign	'\347'		/* Assignment */
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
#define E_Cocreate	'\110'		/* Co-expression create */
#define	E_Cobang	'\222'		/* Co-expression generation */

   /*
    * Procedure events
    */

#define E_Pcall		'\103'		/* Procedure call */
#define E_Pfail		'\106'		/* Procedure failure */
#define E_Pret		'\122'		/* Procedure return */
#define E_Psusp		'\123'		/* Procedure suspension */
#define E_Presum	'\125'		/* Procedure resumption */


   /*
    * Garbage collections
    */

#define E_Collect	'\107'		/* Garbage collection */
#define E_EndCollect	'\360'		/* End of garbage collection */
#define E_Tenure	'\361'		/* Tenure a region */

/*
 * Termination Events
 */
#define E_Error		'\105'		/* Run-time error */
#define E_Exit		'\115'		/* exit() called */


/*
 * Location events
 */
#define E_Break		'\352'		/* &break evaluated */
#define E_Line		'\353'		/* Line number changed */
#define E_File		'\355'		/* Source file changed */



/* unused pool.  how many event codes are unused?

000 001 002 003 004 005 006 007
010 011 012 013 014 015 016 017
020 021 022 023 024 025 026 027
030 031 032 033 034 035 036 037
040 041 042 043 044 045 046 047
050 051 052 053 054 056 057
060 061 062 063 064 065 066 067
070 071 072 073 074 075 076 077


100 117 120
124 126 127 130 131 132 133 134 135 136
137 140 141 142 143 146 147
152 154
165 166
172 173 174 175 
204 205 206 207 217 220 221
226 227
230 231 232 233 234 235 236 237
240 241 242 243 244 245 246 247
250 251 252 253 254 255 256 257
260 261 262 263 264 265 266 267
276 277

341 342 343 344 345 346
350 351
364 365 366 370
371 372 373 374 375 376 377

 
*/
