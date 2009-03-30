
/*
 * Copyright 1997-2001 Shamim Mohamed.
 *
 * Modification and redistribution is permitted as long as this (and any
 * other) copyright notices are kept intact. If you make any changes,
 * please add a short note here with your name and what changes were
 * made.
 *
 * $Id: rposix.r,v 1.29 2005/06/24 09:13:44 jeffery Exp $
 */


#include "../h/opdefs.h"

/* Signal definitions */ 
#passthru #if !defined(SIGABRT) 
#passthru #define SIGABRT 0 
#passthru #endif 
#passthru #if !defined(SIGALRM) 
#passthru #define SIGALRM 0 
#passthru #endif 
#passthru #if !defined(SIGBREAK) 
#passthru #define SIGBREAK 0 
#passthru #endif 
#passthru #if !defined(SIGBUS) 
#passthru #define SIGBUS 0 
#passthru #endif 
#passthru #if !defined(SIGCHLD) 
#passthru #define SIGCHLD 0 
#passthru #endif 
#passthru #if !defined(SIGCLD) 
#passthru #define SIGCLD 0 
#passthru #endif 
#passthru #if !defined(SIGCONT) 
#passthru #define SIGCONT 0 
#passthru #endif 
#passthru #if !defined(SIGEMT) 
#passthru #define SIGEMT 0 
#passthru #endif 
#passthru #if !defined(SIGFPE) 
#passthru #define SIGFPE 0 
#passthru #endif 
#passthru #if !defined(SIGFREEZE) 
#passthru #define SIGFREEZE 0 
#passthru #endif 
#passthru #if !defined(SIGHUP) 
#passthru #define SIGHUP 0 
#passthru #endif 
#passthru #if !defined(SIGILL) 
#passthru #define SIGILL 0 
#passthru #endif 
#passthru #if !defined(SIGINT) 
#passthru #define SIGINT 0 
#passthru #endif 
#passthru #if !defined(SIGIO) 
#passthru #define SIGIO 0 
#passthru #endif 
#passthru #if !defined(SIGIOT) 
#passthru #define SIGIOT 0 
#passthru #endif 
#passthru #if !defined(SIGKILL) 
#passthru #define SIGKILL 0 
#passthru #endif 
#passthru #if !defined(SIGLOST) 
#passthru #define SIGLOST 0 
#passthru #endif 
#passthru #if !defined(SIGLWP) 
#passthru #define SIGLWP 0 
#passthru #endif 
#passthru #if !defined(SIGPIPE) 
#passthru #define SIGPIPE 0 
#passthru #endif 
#passthru #if !defined(SIGPOLL) 
#passthru #define SIGPOLL 0 
#passthru #endif 
#passthru #if !defined(SIGPROF) 
#passthru #define SIGPROF 0 
#passthru #endif 
#passthru #if !defined(SIGPWR) 
#passthru #define SIGPWR 0 
#passthru #endif 
#passthru #if !defined(SIGQUIT) 
#passthru #define SIGQUIT 0 
#passthru #endif 
#passthru #if !defined(SIGSEGV) 
#passthru #define SIGSEGV 0 
#passthru #endif 
#passthru #if !defined(SIGSTOP) 
#passthru #define SIGSTOP 0 
#passthru #endif 
#passthru #if !defined(SIGSYS) 
#passthru #define SIGSYS 0 
#passthru #endif 
#passthru #if !defined(SIGTERM) 
#passthru #define SIGTERM 0 
#passthru #endif 
#passthru #if !defined(SIGTHAW) 
#passthru #define SIGTHAW 0 
#passthru #endif 
#passthru #if !defined(SIGTRAP) 
#passthru #define SIGTRAP 0 
#passthru #endif 
#passthru #if !defined(SIGTSTP) 
#passthru #define SIGTSTP 0 
#passthru #endif 
#passthru #if !defined(SIGTTIN) 
#passthru #define SIGTTIN 0 
#passthru #endif 
#passthru #if !defined(SIGTTOU) 
#passthru #define SIGTTOU 0 
#passthru #endif 
#passthru #if !defined(SIGURG) 
#passthru #define SIGURG 0 
#passthru #endif 
#passthru #if !defined(SIGUSR1) 
#passthru #define SIGUSR1 0 
#passthru #endif 
#passthru #if !defined(SIGUSR2) 
#passthru #define SIGUSR2 0 
#passthru #endif 
#passthru #if !defined(SIGVTALRM) 
#passthru #define SIGVTALRM 0 
#passthru #endif 
#passthru #if !defined(SIGWAITING) 
#passthru #define SIGWAITING 0 
#passthru #endif 
#passthru #if !defined(SIGWINCH) 
#passthru #define SIGWINCH 0 
#passthru #endif 
#passthru #if !defined(SIGXCPU) 
#passthru #define SIGXCPU 0 
#passthru #endif 
#passthru #if !defined(SIGXFSZ) 
#passthru #define SIGXFSZ 0 
#passthru #endif 

#if MSWIN32
WORD wVersionRequested = MAKEWORD( 2, 0 );
WSADATA wsaData;
int werr;
int WINSOCK_INITIAL=0;
#define fileno _fileno
#endif					/* MSWIN32 */


/*
 * Signals and trapping
 */

/* Systems don't have more than, oh, about 50 signals, eh? */
static struct descrip handlers[50];
static int inited = 0;

struct descrip register_sig(sig, handler)
int sig;
struct descrip handler;
{
   struct descrip old;
   if (!inited) {
      int i;
      for(i = 0; i < 50; i++)
	 handlers[i] = nulldesc;
      inited = 1;
   }

   old = handlers[sig];
   handlers[sig] = handler;
   return old;
}

void signal_dispatcher(sig)
int sig;
{
   struct descrip proc, p;

   if (!inited) {
      int i;
      for(i = 0; i < 50; i++)
	 handlers[i] = nulldesc;
      inited = 1;
   }

   proc = handlers[sig];

   if (is:null(proc))
      return;

   /* Invoke proc */
   MakeInt(sig, &p);
   call_icon(&proc, &p, 0);
   
   /* Restore signal just in case (for non-BSD systems) */
   signal(sig, signal_dispatcher);
}


