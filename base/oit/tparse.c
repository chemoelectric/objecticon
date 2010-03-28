#define	IDENT	57346
#define	INTLIT	57347
#define	REALLIT	57348
#define	STRINGLIT	57349
#define	CSETLIT	57350
#define	UCSLIT	57351
#define	EOFX	57352
#define	BREAK	57353
#define	BY	57354
#define	CASE	57355
#define	CLASS	57356
#define	CONST	57357
#define	CREATE	57358
#define	DEFAULT	57359
#define	DEFER	57360
#define	DO	57361
#define	ELSE	57362
#define	END	57363
#define	EVERY	57364
#define	FAIL	57365
#define	FINAL	57366
#define	GLOBAL	57367
#define	IF	57368
#define	IMPORT	57369
#define	INITIAL	57370
#define	INVOCABLE	57371
#define	LOCAL	57372
#define	NEXT	57373
#define	NOT	57374
#define	OF	57375
#define	PACKAGE	57376
#define	PRIVATE	57377
#define	PROCEDURE	57378
#define	PROTECTED	57379
#define	PUBLIC	57380
#define	READABLE	57381
#define	RECORD	57382
#define	REPEAT	57383
#define	RETURN	57384
#define	STATIC	57385
#define	SUSPEND	57386
#define	THEN	57387
#define	TO	57388
#define	UNTIL	57389
#define	WHILE	57390
#define	BANG	57391
#define	MOD	57392
#define	AUGMOD	57393
#define	AND	57394
#define	AUGAND	57395
#define	STAR	57396
#define	AUGSTAR	57397
#define	INTER	57398
#define	AUGINTER	57399
#define	PLUS	57400
#define	AUGPLUS	57401
#define	UNION	57402
#define	AUGUNION	57403
#define	MINUS	57404
#define	AUGMINUS	57405
#define	DIFF	57406
#define	AUGDIFF	57407
#define	DOT	57408
#define	SLASH	57409
#define	AUGSLASH	57410
#define	ASSIGN	57411
#define	SWAP	57412
#define	NMLT	57413
#define	AUGNMLT	57414
#define	REVASSIGN	57415
#define	REVSWAP	57416
#define	SLT	57417
#define	AUGSLT	57418
#define	SLE	57419
#define	AUGSLE	57420
#define	NMLE	57421
#define	AUGNMLE	57422
#define	NMEQ	57423
#define	AUGNMEQ	57424
#define	SEQ	57425
#define	AUGSEQ	57426
#define	EQUIV	57427
#define	AUGEQUIV	57428
#define	NMGT	57429
#define	AUGNMGT	57430
#define	NMGE	57431
#define	AUGNMGE	57432
#define	SGT	57433
#define	AUGSGT	57434
#define	SGE	57435
#define	AUGSGE	57436
#define	QMARK	57437
#define	AUGQMARK	57438
#define	AT	57439
#define	AUGAT	57440
#define	BACKSLASH	57441
#define	CARET	57442
#define	AUGCARET	57443
#define	BAR	57444
#define	CONCAT	57445
#define	AUGCONCAT	57446
#define	LCONCAT	57447
#define	AUGLCONCAT	57448
#define	TILDE	57449
#define	NMNE	57450
#define	AUGNMNE	57451
#define	SNE	57452
#define	AUGSNE	57453
#define	NEQUIV	57454
#define	AUGNEQUIV	57455
#define	LPAREN	57456
#define	RPAREN	57457
#define	PCOLON	57458
#define	COMMA	57459
#define	MCOLON	57460
#define	COLON	57461
#define	SEMICOL	57462
#define	LBRACK	57463
#define	RBRACK	57464
#define	LBRACE	57465
#define	RBRACE	57466

#line	152	"/usr/rparlett/objecticon/base/oit/tgram.g"
/*
 * These commented directives are passed through the first application
 * of cpp, then turned into real includes in tgram.g by fixgram.icn.
 */
#include "icont.h"
#include "lexdef.h"
#include "tsym.h"
#include "tmem.h"
#include "tree.h"
#include "tlex.h"
#include "trans.h"
#include "keyword.h"
#undef YYSTYPE
#define YYSTYPE nodeptr
#define YYMAXDEPTH 5000

/* Avoids some spurious compiler warnings */
#define lint 1

extern int fncargs[];
int idflag;
int modflag;
extern	int	yyerrflag;
#ifndef	YYMAXDEPTH
#define	YYMAXDEPTH	150
#endif
#ifndef	YYSTYPE
#define	YYSTYPE	int
#endif
YYSTYPE	yylval;
YYSTYPE	yyval;
#define YYEOFCODE 1
#define YYERRCODE 2

#line	483	"/usr/rparlett/objecticon/base/oit/tgram.g"

short	yyexca[] =
{-1, 0,
	10, 3,
	14, 3,
	24, 3,
	25, 3,
	27, 3,
	29, 3,
	36, 3,
	40, 3,
	-2, 0,
-1, 1,
	1, -1,
	-2, 0,
-1, 13,
	10, 2,
	-2, 32,
-1, 30,
	114, 30,
	-2, 29,
-1, 36,
	21, 81,
	120, 81,
	-2, 0,
-1, 101,
	12, 196,
	19, 196,
	20, 196,
	21, 196,
	33, 196,
	45, 196,
	46, 196,
	50, 196,
	51, 196,
	53, 196,
	55, 196,
	57, 196,
	59, 196,
	61, 196,
	63, 196,
	65, 196,
	68, 196,
	69, 196,
	70, 196,
	71, 196,
	72, 196,
	73, 196,
	74, 196,
	75, 196,
	76, 196,
	77, 196,
	78, 196,
	79, 196,
	80, 196,
	82, 196,
	84, 196,
	86, 196,
	87, 196,
	88, 196,
	89, 196,
	90, 196,
	91, 196,
	92, 196,
	93, 196,
	94, 196,
	96, 196,
	98, 196,
	101, 196,
	104, 196,
	106, 196,
	109, 196,
	111, 196,
	113, 196,
	115, 196,
	116, 196,
	117, 196,
	118, 196,
	119, 196,
	120, 196,
	122, 196,
	124, 196,
	-2, 0,
-1, 102,
	115, 81,
	117, 81,
	-2, 0,
-1, 103,
	120, 81,
	124, 81,
	-2, 0,
-1, 104,
	117, 81,
	122, 81,
	-2, 0,
-1, 112,
	12, 215,
	19, 215,
	20, 215,
	21, 215,
	33, 215,
	45, 215,
	46, 215,
	50, 215,
	51, 215,
	53, 215,
	55, 215,
	57, 215,
	59, 215,
	61, 215,
	63, 215,
	65, 215,
	68, 215,
	69, 215,
	70, 215,
	71, 215,
	72, 215,
	73, 215,
	74, 215,
	75, 215,
	76, 215,
	77, 215,
	78, 215,
	79, 215,
	80, 215,
	82, 215,
	84, 215,
	86, 215,
	87, 215,
	88, 215,
	89, 215,
	90, 215,
	91, 215,
	92, 215,
	93, 215,
	94, 215,
	96, 215,
	98, 215,
	101, 215,
	104, 215,
	106, 215,
	109, 215,
	111, 215,
	113, 215,
	115, 215,
	116, 215,
	117, 215,
	118, 215,
	119, 215,
	120, 215,
	122, 215,
	124, 215,
	-2, 0,
-1, 113,
	12, 217,
	19, 217,
	20, 217,
	21, 217,
	33, 217,
	45, 217,
	46, 217,
	50, 217,
	51, 217,
	53, 217,
	55, 217,
	57, 217,
	59, 217,
	61, 217,
	63, 217,
	65, 217,
	68, 217,
	69, 217,
	70, 217,
	71, 217,
	72, 217,
	73, 217,
	74, 217,
	75, 217,
	76, 217,
	77, 217,
	78, 217,
	79, 217,
	80, 217,
	82, 217,
	84, 217,
	86, 217,
	87, 217,
	88, 217,
	89, 217,
	90, 217,
	91, 217,
	92, 217,
	93, 217,
	94, 217,
	96, 217,
	98, 217,
	101, 217,
	104, 217,
	106, 217,
	109, 217,
	111, 217,
	113, 217,
	115, 217,
	116, 217,
	117, 217,
	118, 217,
	119, 217,
	120, 217,
	122, 217,
	124, 217,
	-2, 0,
-1, 130,
	21, 81,
	120, 81,
	124, 81,
	-2, 0,
-1, 195,
	117, 81,
	122, 81,
	-2, 0,
-1, 196,
	117, 81,
	124, 81,
	-2, 0,
-1, 197,
	115, 81,
	117, 81,
	-2, 0,
-1, 319,
	115, 81,
	117, 81,
	122, 81,
	124, 81,
	-2, 0,
-1, 376,
	21, 81,
	120, 81,
	-2, 0,
-1, 402,
	114, 45,
	-2, 73,
-1, 416,
	21, 81,
	120, 81,
	-2, 0,
};
#define	YYNPROD	243
#define	YYPRIVATE 57344
#define	YYLAST	818
short	yyact[] =
{
  49, 376, 363, 352, 387,  96, 246,  51,  56, 247,
 358,  63,  50,  58,  60,  52, 242, 198, 371, 319,
 320,  39, 370,  61, 225, 319, 340, 345, 353, 377,
 335, 130, 177,  40,  59, 131, 171, 239, 170, 131,
 176, 333, 173, 341, 167, 319, 179, 120, 175, 239,
 174, 319, 169, 362, 168, 123, 321, 318, 122, 319,
  44, 415, 410, 166, 361, 197, 131, 332, 330, 178,
 329, 172, 195, 180, 196, 132, 411, 199, 200, 201,
 202, 203, 204, 205, 206, 207, 208, 209, 210, 211,
 212, 213, 214, 215, 216, 217, 218, 219, 220, 221,
 222,  54, 406, 194, 227, 368, 373, 223, 372, 224,
 331, 128, 126, 125, 181, 226, 182, 226,  16, 123,
 231, 232, 233, 234, 235, 236, 237, 238,  40, 228,
 338, 248, 339, 337, 356, 243, 243, 327, 326, 325,
 322, 131, 190, 244, 240, 324, 187, 249, 188,   6,
 323, 193,  29, 192, 191,  15, 183, 131, 185, 189,
 186, 365, 184, 366, 131,  34, 131, 418, 396, 383,
 131, 131, 131, 131, 283, 284, 367, 230, 129,  47,
 334, 285, 286, 287, 288, 289, 290, 291, 292, 293,
 294, 295, 296, 297, 298,   3, 229, 124, 301, 302,
 303, 304,  12, 314, 310, 311, 312,   7, 226, 226,
 226, 305, 306, 307, 308, 309, 299, 300,  11, 121,
 313, 315, 316,  36, 407,  35, 328,   6, 317, 241,
 127,  42,  11,  32, 250, 251, 252, 253, 254, 255,
 256, 257, 258, 259, 260, 261, 262, 263, 264, 265,
 266, 267, 268, 269, 270, 271, 272, 273, 274, 275,
 276, 277, 278, 279, 280, 281, 282, 402,  43,  11,
  31, 393,  41,   2, 336,  10, 357,   8, 393,  98,
 395, 403,  42,  97,  30,  95,  94, 395,  93,  92,
 391, 388,  26, 390, 389, 394,  27, 391, 388, 392,
 390, 389, 394,  25,  91,  90, 392,  23,  89,  64,
  62,  57,  55,  30, 364,  48,  46,  37, 409, 405,
 404, 401, 400, 397, 386, 384, 350, 374, 349, 245,
 343, 344, 342, 346, 347, 348,  33, 351,  24,  45,
  28,  38,  22, 354, 355,  21,  20,  19,  18,  17,
  14,   5,  13, 360,   9,   4,   1,   0,   0,   0,
   0,   0,   0,   0, 369,   0,   0,   0, 375,   0,
   0,   0,   0, 379, 378,   0,   0, 385,   0, 360,
 381, 382, 380,   0,   0,   0,   0,   0,   0,   0,
   0, 398,   0,   0,   0,   0, 399,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0, 408, 412, 414, 416, 417, 413,  53,
   0,  11, 106, 107, 108, 109, 110,   0, 101,   0,
 115,   0,   0,  99,  42,   0,   0,   0,   0, 118,
 111,   0,   0, 114,   0,   0,   0,   0, 100,  66,
   0,   0,   0,   0,   0,   0,   0,   0, 119, 112,
   0, 113,   0,   0, 117, 116,  71,   0,   0, 105,
   0,  74,   0,  77,   0,  73,   0,  85,   0,  79,
   0,  72,   0,  70,  75,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,  80,   0,
  82,   0,  84,   0,   0,   0,   0,   0,   0,   0,
   0,   0,  86,   0,  65,   0,  88,  76,   0,  67,
  68,   0,  69,   0,  78,  81,   0,  83,   0,  87,
  53, 102,  11, 106, 107, 108, 109, 110, 104, 101,
 103, 115,   0,   0,  99, 359,   0,   0,   0,   0,
 118, 111,   0,   0, 114,   0,   0,   0,   0, 100,
  66,   0,   0,   0,   0,   0,   0,   0,   0, 119,
 112,   0, 113,   0,   0, 117, 116,  71,   0,   0,
 105,   0,  74,   0,  77,   0,  73,   0,  85,   0,
  79,   0,  72,   0,  70,  75,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,  80,
   0,  82,   0,  84,   0,   0,   0,   0,   0,   0,
   0,   0,   0,  86,   0,  65,   0,  88,  76,   0,
  67,  68,   0,  69,   0,  78,  81,   0,  83,   0,
  87,   0, 102,  11, 106, 107, 108, 109, 110, 104,
 101, 103, 115,   0,   0,  99,  42,   0,   0,   0,
   0, 118, 111,   0,   0, 114,   0,   0,   0,   0,
 100,  66,   0,   0,   0,   0,   0,   0,   0,   0,
 119, 112,   0, 113,   0,   0, 117, 116,  71,   0,
   0, 105,   0,  74,   0,  77,   0,  73,   0,  85,
   0,  79,   0,  72,   0,  70,  75,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
  80,   0,  82,   0,  84,   0,   0,   0,   0,   0,
   0,   0,   0,   0,  86,   0,  65,   0,  88,  76,
   0,  67,  68,   0,  69,   0,  78,  81,   0,  83,
 165,  87,   0, 102,   0, 146,   0, 163,   0, 143,
 104, 144, 103, 141,   0, 140,   0, 142,   0, 139,
   0,   0, 145, 134, 133,   0, 153, 136, 135,   0,
 160,   0, 159,   0, 152,   0, 148,   0, 156,   0,
 149,   0, 151,   0, 150,   0, 158,   0, 157,   0,
 162,   0, 164,   0,   0, 147,   0,   0, 137,   0,
 138,   0,   0, 154,   0, 161,   0, 155
};
short	yypact[] =
{
 193,-1000, 197, 115,-1000,-1000, 228,-1000, 192, 128,
  52,-1000,-1000, 267,-1000, 228, 266,-1000,-1000,-1000,
-1000,-1000,-1000, 229, 141, 221,-1000, 265, -57,-1000,
  52,-1000,-1000, 165,-1000,-1000, 417, 215, -59,-1000,
-1000,-1000,  53,  52, 228,  -1,  -2, 226,  -3, 157,
 -89,  89, -20,-1000,-1000, 704,-1000, -39,  11,  98,
  92,-1000,  54,-1000, -49, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000, 417,
-1000, 417, 417, 417, 417, 173,-1000,-1000,-1000,-1000,
-1000,-1000, 417, 417, 417, 417, 417, 417, 417, 417,
 -68,-1000, 265, 225,-1000, 215, 215,-1000, 215,-1000,
 417, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 639, 639, 639, 639, 639,
 639, 639, 639, 639, 639, 417, 417, 417, 224,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000,  89,  89, -58,-1000,-104, -66,-1000,
-1000,  89, 121, 105, 112, 120, 119, 118,  89, 222,
-1000,-1000, -45, -68, -47,  -4, -48, -80,-1000, -20,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000, 168,-1000,  11,  11,  11,  11,  11,
  11,  11,  11,  11,  11,  11,  11,  11,  11,  98,
  98,  92,  92,  92,  92,-1000,-1000,-1000,-1000,-1000,
-1000,-1000,-1000, -92,  14, -98, -72,-1000,-1000, 417,
-1000,-1000, 417, 417, -96, 417, 417, 417,-1000,-1000,
-1000, 214,-1000, -94, 639,-1000, 417,-1000,-1000,-1000,
-1000,-1000,-1000,  89, 114, 528,  89,  89,  89, -51,
 -64,-1000, 133,-1000,-1000, -17, 417,-102,-1000, -11,
 -13,-1000, 214, -91, 215, 417,-1000,-1000,-1000,  89,
-1000, 528, 417, 417, 148,-1000, 417,-1000, -68,  89,
-1000,  89,  89,-1000, 256, 147, 263,-1000,-1000,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000, -68,
-1000,-1000,-1000,-1000, -12, 220, 215,-1000, -53, -38,
-1000, 215, 133, -54, -91,-1000, 417, 146,-1000
};
short	yypgo[] =
{
   0, 356, 273, 355, 354, 352, 351, 350, 349, 348,
 347, 346, 345, 342,   1, 268,   5, 341,  21, 340,
 152, 339,  16, 338, 336, 329, 328, 327, 326, 325,
 324, 323,   9, 322, 321, 320,   6,   3,   2,   0,
 319, 318,   4, 317, 316, 315, 314,   7,  12,  15,
 101, 312,   8, 311,  13,  34,  14,  23, 310,  11,
 309, 308, 305, 304, 289, 288, 286, 285, 283, 279,
  24, 276,  10, 274
};
short	yyr1[] =
{
   0,   1,   2,   3,   3,   4,   4,   5,   5,   8,
   8,   8,   8,   8,  14,  14,  15,  15,  16,  16,
   6,  13,  17,  17,  18,  18,   7,  19,  19,  20,
  21,  20,  23,  25,  10,  26,  26,  28,  28,  27,
  29,  27,  31,  31,  31,  35,  33,  40,  41,  34,
  24,  24,  30,  30,  42,  42,  42,  42,  42,  42,
  42,  42,  43,  12,  44,   9,  22,  22,  45,  11,
  36,  36,  36,  32,  32,  37,  37,  46,  46,  38,
  38,  48,  48,  47,  47,  49,  49,  50,  50,  50,
  50,  50,  50,  50,  50,  50,  50,  50,  50,  50,
  50,  50,  50,  50,  50,  50,  50,  50,  50,  50,
  50,  50,  50,  50,  50,  50,  50,  50,  50,  50,
  51,  51,  51,  52,  52,  53,  53,  53,  53,  53,
  53,  53,  53,  53,  53,  53,  53,  53,  53,  53,
  54,  54,  54,  55,  55,  55,  55,  55,  56,  56,
  56,  56,  56,  57,  57,  58,  58,  58,  58,  59,
  59,  59,  59,  59,  59,  59,  59,  59,  59,  59,
  59,  59,  59,  59,  59,  59,  59,  59,  59,  59,
  59,  59,  59,  59,  60,  60,  60,  60,  60,  60,
  60,  60,  60,  60,  60,  60,  60,  60,  60,  60,
  60,  60,  60,  60,  60,  60,  60,  66,  66,  67,
  67,  68,  68,  69,  63,  63,  63,  63,  63,  63,
  64,  64,  65,  71,  71,  72,  72,  70,  70,  61,
  61,  61,  61,  61,  62,  73,  73,  73,  39,  39,
   1,  11,  47
};
short	yyr2[] =
{
   0,   2,   3,   0,   1,   0,   2,   0,   2,   1,
   1,   1,   1,   1,   0,   1,   1,   3,   3,   1,
   2,   2,   1,   3,   1,   1,   2,   1,   3,   1,
   0,   5,   0,   0,  10,   0,   1,   1,   3,   0,
   0,   4,   1,   1,   1,   0,  10,   0,   0,   7,
   0,   1,   1,   2,   1,   1,   1,   1,   1,   1,
   1,   1,   0,   3,   0,   6,   0,   1,   0,  11,
   0,   1,   3,   1,   3,   0,   3,   1,   1,   0,
   2,   0,   1,   1,   3,   1,   3,   1,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   1,   3,   5,   1,   3,   1,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   1,   3,   3,   1,   3,   3,   3,   3,   1,   3,
   3,   3,   3,   1,   3,   1,   3,   3,   3,   1,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   2,   2,   2,   2,   2,   2,
   2,   2,   2,   2,   1,   1,   1,   1,   1,   1,
   1,   1,   1,   1,   2,   1,   1,   2,   3,   3,
   3,   4,   4,   4,   3,   2,   2,   2,   4,   2,
   4,   2,   4,   2,   1,   1,   2,   1,   2,   4,
   4,   6,   6,   1,   3,   3,   3,   1,   3,   1,
   1,   1,   1,   1,   6,   1,   1,   1,   1,   3,
   3,   4,   1
};
short	yychk[] =
{
-1000,  -1,  -2,   2,  -3,  -6,  34,  10,  -2,  -4,
 -15,   4,  10,  -5,  -7,  27,  66,  -8,  -9, -10,
 -11, -12, -13,  40, -23,  36,  25,  29, -19, -20,
 -15,   4,   4, -24,  24,   4,   2, -43, -17, -18,
 -16,   7,  17, -15, 117, -21, -44,  14, -45, -39,
 -48, -47, -49,   2, -50, -51, -52, -53, -54, -55,
 -56, -57, -58, -59, -60,  97,  32, 102, 103, 105,
  66,  49,  64,  58,  54,  67, 100,  56, 107,  62,
  81, 108,  83, 110,  85,  60,  95, 112,  99, -61,
 -62, -63, -64, -65, -66, -67, -16, -68, -69,  16,
  31,  11, 114, 123, 121,  52,   5,   6,   7,   8,
   9,  23,  42,  44,  26,  13,  48,  47,  22,  41,
 -32,   4, 117,  66, -20, 114, 114,   4, 114,  21,
 120,  52,  95,  70,  69,  74,  73, 104, 106,  65,
  61,  59,  63,  55,  57,  68,  51, 101,  82,  86,
  90,  88,  80,  72, 109, 113,  84,  94,  92,  78,
  76, 111,  96,  53,  98,  46, 102,  83,  93,  91,
  77,  75, 110,  81,  89,  87,  79,  71, 108,  85,
 112, 103, 105,  58,  64,  60,  62,  54,  56,  67,
  50, 100,  99,  97,  49, 121, 123, 114,  66, -59,
 -59, -59, -59, -59, -59, -59, -59, -59, -59, -59,
 -59, -59, -59, -59, -59, -59, -59, -59, -59, -59,
 -59, -59, -59, -47, -47, -70, -48, -39, -70,  23,
   4, -47, -47, -47, -47, -47, -47, -47, -47, 117,
 -18,   4, -22, -32, -22, -25, -36, -32, -39, -49,
 -50, -50, -50, -50, -50, -50, -50, -50, -50, -50,
 -50, -50, -50, -50, -50, -50, -50, -50, -50, -50,
 -50, -50, -50, -50, -50, -50, -50, -50, -50, -50,
 -50, -50, -50, -52, -52, -54, -54, -54, -54, -54,
 -54, -54, -54, -54, -54, -54, -54, -54, -54, -55,
 -55, -56, -56, -56, -56, -57, -57, -57, -57, -57,
 -59, -59, -59, -70, -47, -70, -70,   4, 115, 117,
 124, 122,  19,  45,  33,  19,  19,  19,   4, 115,
 115, 114, 115, 121,  12, 122, -73, 119, 116, 118,
 124, 115, -48, -47, -47, 123, -47, -47, -47, -26,
 -28, -16, -37, 122, -52, -47,  20, -71, -72,  17,
 -47, 115, 117, -38, -46,  28,  30,  43, 122, -47,
 124, 120, 119, 119, -27, -16, -14, 120, -32, -47,
 -72, -47, -47,  21, -29, -39, -30, -42,  35,  38,
  37,  34,  43,  15,  39,  24,  21, -31, -42, -32,
 -33, -34,   4,  18, -35, -40, 114,   4, -36, -41,
 115, 114, -37, -36, -38, 115, -14, -39,  21
};
short	yydef[] =
{
  -2,  -2,   0,   3,   5,   4,   0,   1,   0,   7,
  20,  16, 240,  -2,   6,   0,   0,   8,   9,  10,
  11,  12,  13,   0,  50,   0,  62,   0,  26,  27,
  -2,  17,  64,   0,  51,  68,  -2,   0,  21,  22,
  24,  25,   0,  19,   0,   0,   0,   0,   0,   0,
 238,  82,  83, 242,  85,  87, 120, 123, 125, 140,
 143, 148, 153, 155, 159,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0, 184,
 185, 186, 187, 188, 189, 190, 191, 192, 193,   0,
 195,  -2,  -2,  -2,  -2,   0, 229, 230, 231, 232,
 233, 214,  -2,  -2,   0,   0,   0,   0,   0,   0,
  63,  73,   0,   0,  28,  66,  66,  33,  70, 241,
  -2,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,  -2,  -2,  -2,   0, 160,
 161, 162, 163, 164, 165, 166, 167, 168, 169, 170,
 171, 172, 173, 174, 175, 176, 177, 178, 179, 180,
 181, 182, 183, 194, 197,   0, 227,   0,   0, 205,
 206, 216, 218,   0,   0, 207, 209, 211, 213,   0,
  23,  18,   0,  67,   0,   0,   0,  71, 239,  84,
  86,  88,  89,  90,  91,  92,  93,  94,  95,  96,
  97,  98,  99, 100, 101, 102, 103, 104, 105, 106,
 107, 108, 109, 110, 111, 112, 113, 114, 115, 116,
 117, 118, 119, 121, 124, 126, 127, 128, 129, 130,
 131, 132, 133, 134, 135, 136, 137, 138, 139, 141,
 142, 144, 145, 146, 147, 149, 150, 151, 152, 154,
 156, 157, 158,   0,  82,   0,   0, 204, 198,  -2,
 199, 200,   0,   0,   0,   0,   0,   0,  74,  31,
  65,  35,  75,   0,   0, 201,   0, 235, 236, 237,
 202, 203, 228, 219, 220,   0, 208, 210, 212,   0,
  36,  37,  79,  72, 122,   0,   0,   0, 223,   0,
   0,  39,   0,  14,   0,   0,  77,  78, 234, 221,
 222,   0,   0,   0,  40,  38,  -2,  15,  76,  80,
 224, 225, 226,  34,   0,   0,   0,  52,  54,  55,
  56,  57,  58,  59,  60,  61,  69,  41,  53,  42,
  43,  44,  -2,  47,   0,   0,  70,  48,   0,   0,
  75,  70,  79,   0,  14,  49,  -2,   0,  46
};
short	yytok1[] =
{
   1
};
short	yytok2[] =
{
   2,   3,   4,   5,   6,   7,   8,   9,  10,  11,
  12,  13,  14,  15,  16,  17,  18,  19,  20,  21,
  22,  23,  24,  25,  26,  27,  28,  29,  30,  31,
  32,  33,  34,  35,  36,  37,  38,  39,  40,  41,
  42,  43,  44,  45,  46,  47,  48,  49,  50,  51,
  52,  53,  54,  55,  56,  57,  58,  59,  60,  61,
  62,  63,  64,  65,  66,  67,  68,  69,  70,  71,
  72,  73,  74,  75,  76,  77,  78,  79,  80,  81,
  82,  83,  84,  85,  86,  87,  88,  89,  90,  91,
  92,  93,  94,  95,  96,  97,  98,  99, 100, 101,
 102, 103, 104, 105, 106, 107, 108, 109, 110, 111,
 112, 113, 114, 115, 116, 117, 118, 119, 120, 121,
 122, 123, 124
};
long	yytok3[] =
{
   0
};
#define YYFLAG 		-1000
#define	yyclearin	yychar = -1
#define	yyerrok		yyerrflag = 0

#ifdef	yydebug
#include	"y.debug"
#else
#define	yydebug		0
char*	yytoknames[1];		/* for debugging */
char*	yystates[1];		/* for debugging */
#endif

/*	parser for yacc output	*/

int	yynerrs = 0;		/* number of errors */
int	yyerrflag = 0;		/* error recovery flag */

extern	int	fprint(int, char*, ...);
extern	int	sprint(char*, char*, ...);

char*
yytokname(int yyc)
{
	static char x[16];

	if(yyc > 0 && yyc <= sizeof(yytoknames)/sizeof(yytoknames[0]))
	if(yytoknames[yyc-1])
		return yytoknames[yyc-1];
	sprint(x, "<%d>", yyc);
	return x;
}

char*
yystatname(int yys)
{
	static char x[16];

	if(yys >= 0 && yys < sizeof(yystates)/sizeof(yystates[0]))
	if(yystates[yys])
		return yystates[yys];
	sprint(x, "<%d>\n", yys);
	return x;
}

long
yylex1(void)
{
	long yychar;
	long *t3p;
	int c;

	yychar = yylex();
	if(yychar <= 0) {
		c = yytok1[0];
		goto out;
	}
	if(yychar < sizeof(yytok1)/sizeof(yytok1[0])) {
		c = yytok1[yychar];
		goto out;
	}
	if(yychar >= YYPRIVATE)
		if(yychar < YYPRIVATE+sizeof(yytok2)/sizeof(yytok2[0])) {
			c = yytok2[yychar-YYPRIVATE];
			goto out;
		}
	for(t3p=yytok3;; t3p+=2) {
		c = t3p[0];
		if(c == yychar) {
			c = t3p[1];
			goto out;
		}
		if(c == 0)
			break;
	}
	c = 0;

out:
	if(c == 0)
		c = yytok2[1];	/* unknown char */
	if(yydebug >= 3)
		fprint(2, "lex %.4lux %s\n", yychar, yytokname(c));
	return c;
}

int
yyparse(void)
{
	struct
	{
		YYSTYPE	yyv;
		int	yys;
	} yys[YYMAXDEPTH], *yyp, *yypt;
	short *yyxi;
	int yyj, yym, yystate, yyn, yyg;
	long yychar;
	YYSTYPE save1, save2;
	int save3, save4;

	save1 = yylval;
	save2 = yyval;
	save3 = yynerrs;
	save4 = yyerrflag;

	yystate = 0;
	yychar = -1;
	yynerrs = 0;
	yyerrflag = 0;
	yyp = &yys[-1];
	goto yystack;

ret0:
	yyn = 0;
	goto ret;

ret1:
	yyn = 1;
	goto ret;

ret:
	yylval = save1;
	yyval = save2;
	yynerrs = save3;
	yyerrflag = save4;
	return yyn;

yystack:
	/* put a state and value onto the stack */
	if(yydebug >= 4)
		fprint(2, "char %s in %s", yytokname(yychar), yystatname(yystate));

	yyp++;
	if(yyp >= &yys[YYMAXDEPTH]) {
		yyerror("yacc stack overflow");
		goto ret1;
	}
	yyp->yys = yystate;
	yyp->yyv = yyval;

yynewstate:
	yyn = yypact[yystate];
	if(yyn <= YYFLAG)
		goto yydefault; /* simple state */
	if(yychar < 0)
		yychar = yylex1();
	yyn += yychar;
	if(yyn < 0 || yyn >= YYLAST)
		goto yydefault;
	yyn = yyact[yyn];
	if(yychk[yyn] == yychar) { /* valid shift */
		yychar = -1;
		yyval = yylval;
		yystate = yyn;
		if(yyerrflag > 0)
			yyerrflag--;
		goto yystack;
	}

yydefault:
	/* default state action */
	yyn = yydef[yystate];
	if(yyn == -2) {
		if(yychar < 0)
			yychar = yylex1();

		/* look through exception table */
		for(yyxi=yyexca;; yyxi+=2)
			if(yyxi[0] == -1 && yyxi[1] == yystate)
				break;
		for(yyxi += 2;; yyxi += 2) {
			yyn = yyxi[0];
			if(yyn < 0 || yyn == yychar)
				break;
		}
		yyn = yyxi[1];
		if(yyn < 0)
			goto ret0;
	}
	if(yyn == 0) {
		/* error ... attempt to resume parsing */
		switch(yyerrflag) {
		case 0:   /* brand new error */
			yyerror("syntax error");
			yynerrs++;
			if(yydebug >= 1) {
				fprint(2, "%s", yystatname(yystate));
				fprint(2, "saw %s\n", yytokname(yychar));
			}

		case 1:
		case 2: /* incompletely recovered error ... try again */
			yyerrflag = 3;

			/* find a state where "error" is a legal shift action */
			while(yyp >= yys) {
				yyn = yypact[yyp->yys] + YYERRCODE;
				if(yyn >= 0 && yyn < YYLAST) {
					yystate = yyact[yyn];  /* simulate a shift of "error" */
					if(yychk[yystate] == YYERRCODE)
						goto yystack;
				}

				/* the current yyp has no shift onn "error", pop stack */
				if(yydebug >= 2)
					fprint(2, "error recovery pops state %d, uncovers %d\n",
						yyp->yys, (yyp-1)->yys );
				yyp--;
			}
			/* there is no state on the stack with an error shift ... abort */
			goto ret1;

		case 3:  /* no shift yet; clobber input char */
			if(yydebug >= 2)
				fprint(2, "error recovery discards %s\n", yytokname(yychar));
			if(yychar == YYEOFCODE)
				goto ret1;
			yychar = -1;
			goto yynewstate;   /* try again in the same state */
		}
	}

	/* reduction by production yyn */
	if(yydebug >= 2)
		fprint(2, "reduce %d in:\n\t%s", yyn, yystatname(yystate));

	yypt = yyp;
	yyp -= yyr2[yyn];
	yyval = (yyp+1)->yyv;
	yym = yyn;

	/* consult goto table to find next state */
	yyn = yyr1[yyn];
	yyg = yypgo[yyn];
	yyj = yyg + yyp->yys + 1;

	if(yyj >= YYLAST || yychk[yystate=yyact[yyj]] != -yyn)
		yystate = yyact[yyg];
	switch(yym) {
		
case 1:
#line	182	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 17:
#line	205	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Dottedid,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 18:
#line	207	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Dottedid,yypt[-1].yyv,IdNode(default_string),yypt[-0].yyv);} break;
case 20:
#line	210	"/usr/rparlett/objecticon/base/oit/tgram.g"
{set_package(dottedid2string(yypt[-0].yyv), yypt[-0].yyv);;} break;
case 21:
#line	212	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 23:
#line	215	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 24:
#line	217	"/usr/rparlett/objecticon/base/oit/tgram.g"
{add_invocable(dottedid2string(yypt[-0].yyv),1,yypt[-0].yyv);} break;
case 25:
#line	218	"/usr/rparlett/objecticon/base/oit/tgram.g"
{add_invocable(Str0(yypt[-0].yyv),2,yypt[-0].yyv);} break;
case 29:
#line	225	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_import(dottedid2string(yypt[-0].yyv),0,yypt[-0].yyv);; } break;
case 30:
#line	226	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_import(dottedid2string(yypt[-0].yyv),1,yypt[-0].yyv);idflag = F_Importsym;} break;
case 32:
#line	228	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag = 0;} break;
case 33:
#line	228	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_class(Str0(yypt[-0].yyv),modflag, yypt[-0].yyv);;} break;
case 37:
#line	233	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_super(dottedid2string(yypt[-0].yyv),yypt[-0].yyv);; } break;
case 38:
#line	234	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_super(dottedid2string(yypt[-0].yyv),yypt[-0].yyv);; } break;
case 40:
#line	237	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag = 0; idflag = F_Class;} break;
case 42:
#line	239	"/usr/rparlett/objecticon/base/oit/tgram.g"
{check_flags(modflag, yypt[-0].yyv); } break;
case 45:
#line	243	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_method(Str0(yypt[-0].yyv), modflag, yypt[-0].yyv); idflag = F_Argument;} break;
case 46:
#line	244	"/usr/rparlett/objecticon/base/oit/tgram.g"
{curr_func->code = tree6(N_Proc,yypt[-9].yyv,yypt[-9].yyv,yypt[-3].yyv,yypt[-1].yyv,yypt[-0].yyv); } break;
case 47:
#line	246	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Defer; } break;
case 48:
#line	246	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_method(Str0(yypt[-0].yyv), modflag, yypt[-0].yyv); idflag = F_Argument;} break;
case 51:
#line	249	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Final;} break;
case 54:
#line	254	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Private;} break;
case 55:
#line	255	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Public;} break;
case 56:
#line	256	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Protected;} break;
case 57:
#line	257	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Package;} break;
case 58:
#line	258	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Static;} break;
case 59:
#line	259	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Const;} break;
case 60:
#line	260	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Readable;} break;
case 61:
#line	261	"/usr/rparlett/objecticon/base/oit/tgram.g"
{modflag |= M_Final;} break;
case 62:
#line	263	"/usr/rparlett/objecticon/base/oit/tgram.g"
{idflag = F_Global;} break;
case 63:
#line	263	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 64:
#line	265	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_function(F_Record); idflag = F_Argument;} break;
case 65:
#line	265	"/usr/rparlett/objecticon/base/oit/tgram.g"
{
  curr_func->global = next_global(Str0(yypt[-4].yyv),F_Record|F_Global,yypt[-4].yyv); curr_func->global->func = curr_func; yyval = yypt[-4].yyv;
  } break;
case 68:
#line	272	"/usr/rparlett/objecticon/base/oit/tgram.g"
{next_procedure(Str0(yypt[-0].yyv), yypt[-0].yyv); idflag = F_Argument;} break;
case 69:
#line	272	"/usr/rparlett/objecticon/base/oit/tgram.g"
{
                curr_func->code = tree6(N_Proc,yypt[-9].yyv,yypt[-9].yyv,yypt[-3].yyv,yypt[-1].yyv,yypt[-0].yyv);
  } break;
case 70:
#line	276	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 71:
#line	277	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 72:
#line	278	"/usr/rparlett/objecticon/base/oit/tgram.g"
{curr_func->llast->l_flag |= F_Vararg;} break;
case 73:
#line	281	"/usr/rparlett/objecticon/base/oit/tgram.g"
{install(Str0(yypt[-0].yyv),idflag,yypt[-0].yyv);} break;
case 74:
#line	282	"/usr/rparlett/objecticon/base/oit/tgram.g"
{install(Str0(yypt[-0].yyv),idflag,yypt[-0].yyv);} break;
case 75:
#line	284	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 76:
#line	285	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 77:
#line	287	"/usr/rparlett/objecticon/base/oit/tgram.g"
{idflag = F_Dynamic;} break;
case 78:
#line	288	"/usr/rparlett/objecticon/base/oit/tgram.g"
{idflag = F_Static;} break;
case 79:
#line	290	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree1(N_Empty);} break;
case 80:
#line	291	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = yypt[-0].yyv;} break;
case 81:
#line	293	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree1(N_Empty);} break;
case 84:
#line	297	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 86:
#line	300	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 88:
#line	303	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 89:
#line	304	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 90:
#line	305	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 91:
#line	306	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 92:
#line	307	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 93:
#line	308	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 94:
#line	309	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 95:
#line	310	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 96:
#line	311	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 97:
#line	312	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 98:
#line	313	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 99:
#line	314	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 100:
#line	315	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 101:
#line	316	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 102:
#line	317	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 103:
#line	318	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 104:
#line	319	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 105:
#line	320	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 106:
#line	321	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 107:
#line	322	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 108:
#line	323	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 109:
#line	324	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 110:
#line	325	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 111:
#line	326	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 112:
#line	327	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 113:
#line	328	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 114:
#line	329	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 115:
#line	330	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 116:
#line	331	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 117:
#line	332	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 118:
#line	333	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 119:
#line	334	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Augop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 121:
#line	337	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_To,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 122:
#line	338	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_ToBy,yypt[-3].yyv,yypt[-4].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 124:
#line	341	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Alt,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 126:
#line	344	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 127:
#line	345	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 128:
#line	346	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 129:
#line	347	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 130:
#line	348	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 131:
#line	349	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 132:
#line	350	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 133:
#line	351	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 134:
#line	352	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 135:
#line	353	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 136:
#line	354	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 137:
#line	355	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 138:
#line	356	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 139:
#line	357	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 141:
#line	360	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 142:
#line	361	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 144:
#line	364	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 145:
#line	365	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 146:
#line	366	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 147:
#line	367	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 149:
#line	370	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 150:
#line	371	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 151:
#line	372	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 152:
#line	373	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 154:
#line	376	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 156:
#line	379	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Limit,yypt[-2].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 157:
#line	380	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Binop,yypt[-1].yyv,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 158:
#line	381	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Apply,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 160:
#line	384	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 161:
#line	385	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_Not,yypt[-0].yyv,yypt[-0].yyv);} break;
case 162:
#line	386	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 163:
#line	387	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 164:
#line	388	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 165:
#line	389	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 166:
#line	390	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 167:
#line	391	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 168:
#line	392	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 169:
#line	393	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 170:
#line	394	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 171:
#line	395	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 172:
#line	396	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 173:
#line	397	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 174:
#line	398	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 175:
#line	399	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 176:
#line	400	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 177:
#line	401	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 178:
#line	402	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 179:
#line	403	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 180:
#line	404	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 181:
#line	405	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 182:
#line	406	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 183:
#line	407	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Unop,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 191:
#line	416	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = convert_dottedidentexpr(yypt[-0].yyv);} break;
case 194:
#line	419	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_Create,yypt[-1].yyv,yypt[-0].yyv);} break;
case 195:
#line	420	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree2(N_Next,yypt[-0].yyv);} break;
case 196:
#line	421	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree2(N_Break,yypt[-0].yyv);} break;
case 197:
#line	422	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_Breakexpr,yypt[-1].yyv,yypt[-0].yyv);} break;
case 198:
#line	423	"/usr/rparlett/objecticon/base/oit/tgram.g"
{if ((yypt[-1].yyv)->n_type == N_Elist) yyval = tree3(N_Mutual,yypt[-2].yyv,yypt[-1].yyv); else yyval = yypt[-1].yyv;} break;
case 199:
#line	424	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = yypt[-1].yyv;} break;
case 200:
#line	425	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_List,yypt[-2].yyv,yypt[-1].yyv);} break;
case 201:
#line	426	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = buildarray(yypt[-3].yyv,yypt[-2].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 202:
#line	427	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_CoInvoke,yypt[-2].yyv,yypt[-3].yyv,yypt[-1].yyv);} break;
case 203:
#line	428	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Invoke,yypt[-2].yyv,yypt[-3].yyv,yypt[-1].yyv);} break;
case 204:
#line	429	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Field,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 205:
#line	430	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = int_leaf(N_Key,yypt[-1].yyv,K_FAIL);} break;
case 206:
#line	431	"/usr/rparlett/objecticon/base/oit/tgram.g"
{int kn = klookup(Str0(yypt[-0].yyv)); if (kn == 0) tfatal("invalid keyword: %s",Str0(yypt[-0].yyv)); yyval = int_leaf(N_Key,yypt[-1].yyv,kn);;} break;
case 207:
#line	433	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_While,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 208:
#line	434	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Whiledo,yypt[-3].yyv,yypt[-3].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 209:
#line	436	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Until,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 210:
#line	437	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Untildo,yypt[-3].yyv,yypt[-3].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 211:
#line	439	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Every,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 212:
#line	440	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Everydo,yypt[-3].yyv,yypt[-3].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 213:
#line	442	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Repeat,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 214:
#line	444	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree2(N_Fail,yypt[-0].yyv);} break;
case 215:
#line	445	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_Return,yypt[-0].yyv,yypt[-0].yyv);} break;
case 216:
#line	446	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Returnexpr,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 217:
#line	447	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree3(N_Suspend,yypt[-0].yyv,yypt[-0].yyv);} break;
case 218:
#line	448	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Suspendexpr,yypt[-1].yyv,yypt[-1].yyv,yypt[-0].yyv);} break;
case 219:
#line	449	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Suspenddo,yypt[-3].yyv,yypt[-3].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 220:
#line	451	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_If,yypt[-3].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 221:
#line	452	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree5(N_Ifelse,yypt[-5].yyv,yypt[-4].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 222:
#line	454	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Case,yypt[-5].yyv,yypt[-4].yyv,yypt[-1].yyv);} break;
case 224:
#line	457	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Clist,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 225:
#line	459	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Cdef,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 226:
#line	460	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Ccls,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 227:
#line	462	"/usr/rparlett/objecticon/base/oit/tgram.g"
{;} break;
case 228:
#line	463	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Elist,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
case 229:
#line	465	"/usr/rparlett/objecticon/base/oit/tgram.g"
{if (yypt[-0].yyv->n_type == N_Int) Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_IntLit,(int)Val1(yypt[-0].yyv)); else Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_LrgintLit,(int)Val1(yypt[-0].yyv));} break;
case 230:
#line	466	"/usr/rparlett/objecticon/base/oit/tgram.g"
{Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_RealLit,(int)Val1(yypt[-0].yyv));} break;
case 231:
#line	467	"/usr/rparlett/objecticon/base/oit/tgram.g"
{Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_StrLit,(int)Val1(yypt[-0].yyv));} break;
case 232:
#line	468	"/usr/rparlett/objecticon/base/oit/tgram.g"
{Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_CsetLit,(int)Val1(yypt[-0].yyv));} break;
case 233:
#line	469	"/usr/rparlett/objecticon/base/oit/tgram.g"
{Val0(yypt[-0].yyv) = putlit(Str0(yypt[-0].yyv),F_UcsLit,(int)Val1(yypt[-0].yyv));} break;
case 234:
#line	471	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree6(N_Sect,yypt[-2].yyv,yypt[-2].yyv,yypt[-5].yyv,yypt[-3].yyv,yypt[-1].yyv);} break;
case 235:
#line	473	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = yypt[-0].yyv;} break;
case 236:
#line	474	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = yypt[-0].yyv;} break;
case 237:
#line	475	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = yypt[-0].yyv;} break;
case 239:
#line	478	"/usr/rparlett/objecticon/base/oit/tgram.g"
{yyval = tree4(N_Slist,yypt[-1].yyv,yypt[-2].yyv,yypt[-0].yyv);} break;
	}
	goto yystack;  /* stack new state and value */
}
