/*  
 * Icon configuration file for Linux v2 on Intel
 */

#define UNIX 1
#define LoadFunc
/* no SysOpt: Linux getopt() is POSIX-compatible only if an envmt var is set */

#define CComp "gcc"
#define COpts "-O2 -fomit-frame-pointer"
#define NEED_UTIME

/*
 * Some Linuxen have -lcrypt, some dont.
 * If you have crypt, you can remove this.
 */
#define NoCrypt
#define Graphics 1

#define NoMessaging 1
#define DeBugLinker 1
#define NoDbm       1
