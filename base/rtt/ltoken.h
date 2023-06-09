#define Identifier 257
#define StrLit 258
#define LStrLit 259
#define FltConst 260
#define DblConst 261
#define LDblConst 262
#define CharConst 263
#define LCharConst 264
#define IntConst 265
#define UIntConst 266
#define LIntConst 267
#define ULIntConst 268
#define Arrow 269
#define Incr 270
#define Decr 271
#define LShft 272
#define RShft 273
#define Leq 274
#define Geq 275
#define TokEqual 276
#define Neq 277
#define And 278
#define Or 279
#define MultAsgn 280
#define DivAsgn 281
#define ModAsgn 282
#define PlusAsgn 283
#define MinusAsgn 284
#define LShftAsgn 285
#define RShftAsgn 286
#define AndAsgn 287
#define XorAsgn 288
#define OrAsgn 289
#define Sizeof 290
#define Intersect 291
#define OpSym 292
#define Typedef 293
#define Extern 294
#define Static 295
#define Auto 296
#define TokRegister 297
#define Tended 298
#define TokChar 299
#define TokShort 300
#define Int 301
#define TokLong 302
#define Signed 303
#define Unsigned 304
#define Float 305
#define Doubl 306
#define Const 307
#define Volatile 308
#define Void 309
#define TypeDefName 310
#define Struct 311
#define Union 312
#define TokEnum 313
#define Ellipsis 314
#define Case 315
#define Default 316
#define If 317
#define Else 318
#define Switch 319
#define While 320
#define Do 321
#define For 322
#define Goto 323
#define Continue 324
#define Break 325
#define Return 326
#define Runerr 327
#define Is 328
#define Cnv 329
#define Def 330
#define Exact 331
#define Empty_type 332
#define IconType 333
#define Component 334
#define Variable 335
#define Any_value 336
#define Named_var 337
#define Struct_var 338
#define C_Integer 339
#define Str_Or_Ucs 340
#define C_Double 341
#define C_String 342
#define Body 343
#define End 344
#define TokFunction 345
#define Keyword 346
#define Operator 347
#define Underef 348
#define Declare 349
#define Suspend 350
#define Fail 351
#define TokType 352
#define New 353
#define All_fields 354
#define Then 355
#define Type_case 356
#define Of 357
#define IfStmt 358
#ifdef YYSTYPE
#undef  YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
#endif
#ifndef YYSTYPE_IS_DECLARED
#define YYSTYPE_IS_DECLARED 1
typedef union {
   struct token *t;
   struct node *n;
   long i;
   } YYSTYPE;
#endif /* !YYSTYPE_IS_DECLARED */
extern YYSTYPE yylval;
