/*
 * File: fsys.r
 *  Contents: close, chdir, exit, getenv, open, read, reads, remove, rename,
 *  [save], seek, stop, system, where, write, writes, [getch, getche, kbhit]
 */

/*
 * The following code is operating-system dependent [@fsys.01]. Include
 *  system-dependent files and declarations.
 */

#if PORT
   /* nothing to do */
Deliberate Syntax Error
#endif					/* PORT */

#if MSWIN32 || UNIX
   /* nothing to do */
#endif			

extern int errno;
/*
 * End of operating-system specific code.
 */


/* (should) change the mixed case of string s1 to the lower case string s2 */

void UtoL (char *s1, char *s2)
{
   int i, l = strlen(s2);

   for (i = 0; i < l; i++)
      *(s1+i) = *(s2+i);
}

/*
 * is_url() takes a string s as its parameter. If s starts with a URL scheme,
 * is_url() returns 1. If s starts with "net:", it returns 2. Otherwise,
 * for normal files, is_url() returns 0.
*/

int is_url(char *s)
{
   char *tmp = s;

   while ( *tmp == ' ' || *tmp == '\t' || *tmp == '\n' )
      tmp++;

   if (!strncasecmp (tmp, "http:", 5) ){
      UtoL(tmp, "http");
      return 1;
      }
   if (!strncasecmp (tmp, "file:", 5) ) {
      UtoL(tmp, "file");
      return 1;
      }
   if (!strncasecmp (tmp, "ftp:", 4) ) {
      UtoL(tmp, "ftp");
      return 1;
      }
   if (!strncasecmp (tmp, "gopher:", 7) ) {
      UtoL(tmp, "gopher");
      return 1;
      }
   if (!strncasecmp (tmp, "telnet:", 7) )  {
      UtoL(tmp, "telnet");
      return 1;
      }
   if ( !strncasecmp(tmp, "net:", 4) )
      return 2;
   return 0;
}

"close(f) - close file f."

function{1} close(f)

   if !is:file(f) then
      runerr(105, f)

   abstract {
      return file ++ integer
      }

   body {
      FILE *fp = BlkLoc(f)->file.fd.fp;
      int status = BlkLoc(f)->file.status;
      if ((status & (Fs_Read|Fs_Write)) == 0) return f;

      /*
       * Close f, using fclose, pclose, closedir, or wclose as appropriate.
       */

      if (BlkLoc(f)->file.status & Fs_Socket) {
	 BlkLoc(f)->file.status = 0;
#if MSWIN32
	 return C_integer closesocket((SOCKET)BlkLoc(f)->file.fd.fd);
#else					/* MSWIN32 */
	 return C_integer close(BlkLoc(f)->file.fd.fd);
#endif					/* MSWIN32 */
	 }

#if !MSWIN32
      if (BlkLoc(f)->file.status & Fs_Directory) {
	 BlkLoc(f)->file.status = 0;
	 closedir((DIR *)fp);
	 return f;
         }
#endif

#ifdef HAVE_LIBZ
      if (BlkLoc(f)->file.status & Fs_Compress) {
	 BlkLoc(f)->file.status = 0;
	 if (gzclose((gzFile) fp)) fail;
	 return C_integer 0;
	 }
#endif					/* HAVE_LIBZ */





#if MSWIN32
#ifndef NTGCC
#define pclose _pclose
#define popen _popen
#endif					/* NTGCC */
#endif					/* MSWIN32 */

#if UNIX || MSWIN32
      /*
       * Close pipe if pipes are supported.
       */

      if (BlkLoc(f)->file.status & Fs_Pipe) {
	 BlkLoc(f)->file.status = 0;
	 return C_integer((pclose(fp) >> 8) & 0377);
	 }
      else
#endif					

      fclose(fp);
      BlkLoc(f)->file.status = 0;

      /*
       * Return the closed file.
       */
      return f;
      }
end

#undef exit
#passthru #undef exit

"exit(i) - exit process with status i, which defaults to 0."

function{} exit(status)
   if !def:C_integer(status, EXIT_SUCCESS) then
      runerr(101, status)
   inline {
      c_exit((int)status);
      fail;
      }
end


"getenv(s) - return contents of environment variable s."

function{0,1} getenv(s)

   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)
   abstract {
      return string
      }

   inline {
      register char *p;
      long l;

      if ((p = getenv(s)) != NULL) {	/* get environment variable */
	 l = strlen(p);
	 Protect(p = alcstr(p,l),runerr(0));
	 return string(l,p);
	 }
      else 				/* fail if not in environment */
	 fail;

      }
end



"open(s1, s2, ...) - open file named s1 with options s2"
" and attributes given in trailing arguments."
function{0,1} open(fname, spec, attr[n])
   declare {
      tended struct descrip filename;
      }

   /*
    * fopen and popen require a C string, but it looks terrible in
    *  error messages, so convert it to a string here and use a local
    *  variable (fnamestr) to store the C string.
    */
   if !cnv:string(fname) then
      runerr(103, fname)

   /*
    * spec defaults to "r".
    */
   if !def:tmp_string(spec, letr) then
      runerr(103, spec)


   abstract {
      return file
      }

   body {
      tended char *fnamestr;
      register word slen;
      register int i;
      register char *s;
      int status;
      char mode[4], sbuf[MaxCvtLen+1], sbuf2[MaxCvtLen+1];
      extern FILE *fopen();
      FILE *f;
      SOCKET fd;
      struct b_file *fl;
      struct stat st;


/*
 * The following code is operating-system dependent [@fsys.02].  Make
 *  declarations as needed for opening files.
 */

#if PORT
Deliberate Syntax Error
#endif					/* PORT */

#if MSWIN32
   /* nothing is needed */
#endif

      int is_udp_or_listener = 0;	/* UDP = 1, listener = 2 */

#if UNIX || MSWIN32
      extern FILE *popen();
#endif

/*
 * End of operating-system specific code.
 */

      /*
       * get a C string for the file name
       */
      if (!cnv:C_string(fname, fnamestr))
	 runerr(103,fname);

      if (strlen(fnamestr) != StrLen(fname)) {
	 fail;
	 }

      status = 0;

      /*
       * Scan spec, setting appropriate bits in status.  Produce a
       *  run-time error if an unknown character is encountered.
       */
      s = StrLoc(spec);
      slen = StrLen(spec);

      for (i = 0; i < slen; i++) {
	 switch (*s++) {
	    case 'a':
	    case 'A':
	       status |= Fs_Write|Fs_Append;
	       continue;
	    case 'b':
	    case 'B':
	       status |= Fs_Read|Fs_Write;
	       continue;
	    case 'c':
	    case 'C':
	       status |= Fs_Create|Fs_Write;
	       continue;
	    case 'r':
	    case 'R':
	       status |= Fs_Read;
	       continue;
	    case 'w':
	    case 'W':
	       status |= Fs_Write;
	       continue;

	    case 's':
	    case 'S':
	       continue;

	    case 't':
	    case 'T':
	       status &= ~Fs_Untrans;
	       continue;

	    case 'u':
	    case 'U':
	       is_udp_or_listener = 1;
	       if ((status & Fs_Socket)==0)
		  status |= Fs_Untrans;
	       continue;

#if UNIX || MSWIN32
	    case 'p':
	    case 'P':
	       status |= Fs_Pipe;
	       continue;
#endif				

	    case 'l':
	    case 'L':
	       if (status & Fs_Socket) {
		  status |= Fs_Listen | Fs_Append;
		  is_udp_or_listener = 2;
		  continue;
		  }
	       fail;


	    case 'd':
	    case 'D':
	       fail;

	    case 'm':
	    case 'M':
	       fail;

	    case 'n':
	    case 'N':
	       status |= Fs_Socket|Fs_Read|Fs_Write|Fs_Unbuf;
	       continue;



	    case 'o':
	    case 'O':
	       fail;

            case 'z':
	    case 'Z':

#ifdef HAVE_LIBZ      
	       status |= Fs_Compress;

               continue; 
#else					/* HAVE_LIBZ */
               fail; 
#endif					/* HAVE_LIBZ */



	    default:
	       runerr(209, spec);
	    }
	 }

      /*
       * Construct a mode field for fopen/popen.
       */
      mode[0] = '\0';
      mode[1] = '\0';
      mode[2] = '\0';
      mode[3] = '\0';


      if ((status & (Fs_Read|Fs_Write)) == 0)	/* default: read only */
	 status |= Fs_Read;
      if (status & Fs_Create)
	 mode[0] = 'w';
      else if (status & Fs_Append)
	 mode[0] = 'a';
      else if (status & Fs_Read)
	 mode[0] = 'r';
      else
	 mode[0] = 'w';

/*
 * The following code is operating-system dependent [@fsys.05].  Handle open
 *  modes.
 */

#if PORT
      if ((status & (Fs_Read|Fs_Write)) == (Fs_Read|Fs_Write))
	 mode[1] = '+';
Deliberate Syntax Error
#endif					/* PORT */

#if UNIX
      if ((status & (Fs_Read|Fs_Write)) == (Fs_Read|Fs_Write))
	 mode[1] = '+';
#endif

#if MSWIN32
      if ((status & (Fs_Read|Fs_Write)) == (Fs_Read|Fs_Write)) {
	 mode[1] = '+';
	 mode[2] = ((status & Fs_Untrans) != 0) ? 'b' : 't';
	 }
      else mode[1] = ((status & Fs_Untrans) != 0) ? 'b' : 't';
#endif					/* MSWIN32 */

/*
 * End of operating-system specific code.
 */

      /*
       * Open the file with fopen or popen.
       */




#if UNIX || MSWIN32
      if (status & Fs_Pipe) {
	 int c;
         char *ploc;
	 if (status != (Fs_Read|Fs_Pipe) && status != (Fs_Write|Fs_Pipe))
	    runerr(209, spec);
	 strcpy(sbuf, fnamestr);
	 if ((s = strchr(sbuf, ' ')) != NULL) *s = '\0';
         ploc = findexe(sbuf);
	 if (!ploc)
	    fail;
         fnamestr = sbuf2;
         strcpy(fnamestr, ploc);
	 if (s) {
	    strcat(fnamestr, " ");
	    strcat(fnamestr, s+1);
	    }
         errno = 0;
	 f = popen(fnamestr, mode);
         if (f && !strcmp(mode,"r")) {
             if ((c = getc(f)) == EOF) {
                 pclose(f);
                 fail;
             }
             else
                 ungetc(c, f);
         }
      }
      else
#endif			


#ifdef HAVE_LIBZ
      if (status & Fs_Compress) {
         /*add new code here*/
         f = (FILE *)gzopen(fnamestr, mode);
         }
      else 
#endif					/* HAVE_LIBZ */


      {
	 if (status & Fs_Socket) {
	    /* The only allowed values for flags are "n" and "na" */
	    if (status & ~(Fs_Read|Fs_Write|Fs_Socket|Fs_Append|Fs_Unbuf|Fs_Listen))
	       runerr(209, spec);
	    if (status & Fs_Append) {
	       /* "na" => listen for connections */
	       fd = sock_listen(fnamestr, is_udp_or_listener);
	    } else {
	       C_integer timeout = 0;
	       if (n > 0 && !is:null(attr[0])) {
                  if (!cnv:C_integer(attr[0], timeout))
                     runerr(101, attr[0]);
               }
	       /* connect to a port */
	       fd = sock_connect(fnamestr, is_udp_or_listener, timeout);
	    }
	    /*
	     * read/reads is not allowed on a listener socket, only select
	     * read/reads is not allowed on a UDP socket, only receive
	     */
	    if (is_udp_or_listener == 2)
	       status = Fs_Socket | Fs_Listen;
	    else if (is_udp_or_listener == 1)
	       status = Fs_Socket | Fs_Write;
	    else
	       status = Fs_Socket | Fs_Read | Fs_Write;


	    if (!fd) {
	       IntVal(amperErrno) = errno;
	       fail;
	       }

	    StrLen(filename) = strlen(fnamestr);
	    StrLoc(filename) = fnamestr;
	    Protect(fl = alcfile(0, status, &filename), runerr(0));
	    fl->fd.fd = fd;
	    return file(fl);
	    }
	 else if (stat(fnamestr, &st) < 0) {
	    if (errno == ENOENT && (status & Fs_Read))
	       fail;
	    else
	       f = fopen(fnamestr, mode);
	 }
	 else {
	    /*
	     * check and see if the file was actually a directory
	     */
	    if (S_ISDIR(st.st_mode)) {
	       if (status & Fs_Write)
		  runerr(173, fname);
	       else {
#if !MSWIN32
		  f = (FILE *)opendir(fnamestr);
		  status |= Fs_Directory;
#else					/* !MSWIN32 */
		  char tempbuf[512];
		  strcpy(tempbuf, fnamestr);
		  if (tempbuf[strlen(tempbuf)-1] != '\\')
		     strcat(tempbuf, "\\");
		  strcat(tempbuf, "*.*");
		  if (*tempbuf) {
		     FINDDATA_T fd;
		     if (!FINDFIRST(tempbuf, &fd)) fail;
		     f = tmpfile();
		     if (f == NULL) fail;
		     do {
			fprintf(f, "%s\n", FILENAME(&fd));
			}
		     while (FINDNEXT(&fd));
		     FINDCLOSE(&fd);
		     fflush(f);
		     fseek(f, 0, SEEK_SET);
		     }
#endif					/* MSWIN32 */
		  }
	       }
	    else {
	       f = fopen(fnamestr, mode);
	       }
	    }
	 }

      /*
       * Fail if the file cannot be opened.
       */
      if (f == NULL) {
#if MSWIN32
         char tempbuf[512];
	 *tempbuf = '\0';
         if (strchr(fnamestr, '*') || strchr(fnamestr, '?')) {
            /*
	     * attempted to open a wildcard, do file completion
	     */
	    strcpy(tempbuf, fnamestr);
            }
	 else {
            /*
	     * check and see if the file was actually a directory
	     */
            struct stat fs;

            if (stat(fnamestr, &fs) == -1) fail;
	    if (S_ISDIR(fs.st_mode)) {
	       strcpy(tempbuf, fnamestr);
	       if (tempbuf[strlen(tempbuf)-1] != '\\')
	          strcat(tempbuf, "\\");
	       strcat(tempbuf, "*.*");
	       }
	    }
         if (*tempbuf) {
            FINDDATA_T fd;
	    if (!FINDFIRST(tempbuf, &fd)) fail;
            f = tmpfile();
            if (f == NULL) fail;
            do {
               fprintf(f, "%s\n", FILENAME(&fd));
               } while (FINDNEXT(&fd));
            FINDCLOSE(&fd);
            fflush(f);
            fseek(f, 0, SEEK_SET);
            if (f == NULL) fail;
	    }
#else					/* MSWIN32 */
	 fail;
#endif					/* MSWIN32 */
	 }

      /*
       * Return the resulting file value.
       */
      StrLen(filename) = strlen(fnamestr);
      StrLoc(filename) = fnamestr;

      Protect(fl = alcfile(f, status, &filename), runerr(0));

      return file(fl);
      }
end


"read(f) - read line on file f."

function{0,1} read(f)
   /*
    * Default f to &input.
    */
   if is:null(f) then
      inline {
	 f.dword = D_File;
	 BlkLoc(f) = (union block *)&k_input;
	 }
   else if !is:file(f) then
      runerr(105, f)

   abstract {
      return string
      }

   body {
      register word slen, rlen;
      register char *sp;
      int status;
      static char sbuf[MaxReadStr];
      tended struct descrip s;
      FILE *fp;
      SOCKET ws;

      /*
       * Get a pointer to the file and be sure that it is open for reading.
       */
      fp = BlkLoc(f)->file.fd.fp;
      status = BlkLoc(f)->file.status;
      if ((status & Fs_Read) == 0)
	 runerr(212, f);

       if (status & Fs_Socket) {
	  StrLen(s) = 0;
          do {
	     ws = (SOCKET)BlkLoc(f)->file.fd.fd;
	     if ((slen = sock_getstrg(sbuf, MaxReadStr, ws)) == -1) {
	        /*IntVal(amperErrno) = errno; */
	        fail;
		}
	     if (slen == -3)
		fail;
	     if (slen == 1 && *sbuf == '\n')
		break;
	     rlen = slen < 0 ? (word)MaxReadStr : slen;

	     Protect(reserve(Strings, rlen), runerr(0));
	     if (StrLen(s) > 0 && !InRange(strbase,StrLoc(s),strfree)) {
	        Protect(reserve(Strings, StrLen(s)+rlen), runerr(0));
	        Protect((StrLoc(s) = alcstr(StrLoc(s),StrLen(s))), runerr(0));
		}

	     Protect(sp = alcstr(sbuf,rlen), runerr(0));
	     if (StrLen(s) == 0)
	        StrLoc(s) = sp;
	     StrLen(s) += rlen;
	     if (StrLoc(s) [ StrLen(s) - 1 ] == '\n') { StrLen(s)--; break; }
	     else {
		/* no newline to trim; EOF? */
		}
	     }
	  while (slen > 0);

         return s;
	  }

      /*
       * well.... switching from unbuffered to buffered actually works so
       * we will allow it except for sockets.
       */
      if (status & Fs_Unbuf) {
	 if (status & Fs_Socket)
	    runerr(1048, f);
	 status &= ~Fs_Unbuf;
	 status |= Fs_Buff;
	 BlkLoc(f)->file.status = status;
	 }

      if (status & Fs_Writing) {
	 fseek(fp, 0L, SEEK_CUR);
	 BlkLoc(f)->file.status &= ~Fs_Writing;
	 }
      BlkLoc(f)->file.status |= Fs_Reading;

      /*
       * Use getstrg to read a line from the file, failing if getstrg
       *  encounters end of file. [[ What about -2?]]
       */
      StrLen(s) = 0;
      do {


#if !MSWIN32
	  if (status & Fs_Directory) {
	     struct dirent *d;
	     char *s, *p=sbuf;
	     IntVal(amperErrno) = 0;
	     slen = 0;
	     d = readdir((DIR *)fp);
	     if (!d)
	        fail;
	     s = d->d_name;
	     while(*s && slen++ < MaxReadStr)
	        *p++ = *s++;
	     if (slen == MaxReadStr)
		slen = -2;
	  }
	  else
#endif


#ifdef HAVE_LIBZ
        /*
	 * Read a line from a compressed file
	 */
	if (status & Fs_Compress) {
            
            if (gzeof(fp)) fail;

            if (gzgets((gzFile)fp,sbuf,MaxReadStr+1) == Z_NULL) {
	       runerr(214);
               }

	    slen = strlen(sbuf);

            if (slen==MaxReadStr && sbuf[slen-1]!='\n') slen = -2;
	    else if (sbuf[slen-1] == '\n') {
               sbuf[slen-1] = '\0';
               slen--;
               }
           
	    }
           
	else 
#endif					/* HAVE_LIBZ */

	 if ((slen = getstrg(sbuf, MaxReadStr, &BlkLoc(f)->file)) == -1) {
	    IntVal(amperErrno) = errno;
	    fail;
	    }

	 /*
	  * Allocate the string read and make s a descriptor for it.
	  */
	 rlen = slen < 0 ? (word)MaxReadStr : slen;

	 Protect(reserve(Strings, rlen), runerr(0));
	 if (StrLen(s) > 0 && !InRange(strbase,StrLoc(s),strfree)) {
	    Protect(reserve(Strings, StrLen(s)+rlen), runerr(0));
	    Protect((StrLoc(s) = alcstr(StrLoc(s),StrLen(s))), runerr(0));
	    }

	 Protect(sp = alcstr(sbuf,rlen), runerr(0));
	 if (StrLen(s) == 0)
	    StrLoc(s) = sp;
	 StrLen(s) += rlen;
	 } while (slen < 0);
      return s;
      }
end


"reads(f,i) - read i characters on file f."

function{0,1} reads(f,i)
   /*
    * Default f to &input.
    */
   if is:null(f) then
      inline {
	 f.dword = D_File;
	 BlkLoc(f) = (union block *)&k_input;
	 }
   else if !is:file(f) then
      runerr(105, f)

   /*
    * i defaults to 1 (read a single character)
    */
   if !def:C_integer(i,1L) then
      runerr(101, i)

   abstract {
      return string
      }

   body {
      register word slen, rlen;
      register char *sp;
      static char sbuf[MaxReadStr];
      SOCKET ws;
      int bytesread = 0;
      int Maxread = 0;
      long tally, nbytes;
      int status;
      FILE *fp;
      tended struct descrip s;

      /*
       * Get a pointer to the file and be sure that it is open for reading.
       */
      status = BlkLoc(f)->file.status;
      if ((status & Fs_Read) == 0)
	 runerr(212, f);


        if (status & Fs_Socket) {
	    StrLen(s) = 0;
	    Maxread = (i <= MaxReadStr)? i : MaxReadStr;
	    do {
	        ws = (SOCKET)BlkLoc(f)->file.fd.fd;
		if (bytesread > 0) {
                    if (i - bytesread <= MaxReadStr)
                        Maxread = i - bytesread;
                    else
                        Maxread = MaxReadStr;
                }

		if ((slen = sock_getstrg(sbuf, Maxread, ws)) == -1) {
		    /*IntVal(amperErrno) = errno; */
		    if (bytesread == 0)
		        fail;
		    else
		        return s;
		}
		if (slen == -3)
		    fail;

		if (slen > 0)
		    bytesread += slen;
		rlen = slen < 0 ? (word)MaxReadStr : slen;

		Protect(reserve(Strings, rlen), runerr(0));
		if (StrLen(s) > 0 && !InRange(strbase, StrLoc(s), strfree)) {
		    Protect(reserve(Strings, StrLen(s) + rlen), runerr(0));
		    Protect((StrLoc(s) =
                        alcstr(StrLoc(s), StrLen(s))), runerr(0));
		}

		Protect(sp = alcstr(sbuf, rlen), runerr(0));
		if (StrLen(s) == 0)
		    StrLoc(s) = sp;
		StrLen(s) += rlen;
	    } while (bytesread < i);
	    return s;
	}

        /* This is a hack to fix things for the release. The solution to be
	 * implemented after release: all I/O is low-level, no stdio. This
	 * makes the Fs_Buff/Fs_Unbuf go away and select will work -- 
	 * correctly. */
        if (strcmp(StrLoc(BlkLoc(f)->file.fname), "pipe") != 0) {
	    status |= Fs_Buff;
	    BlkLoc(f)->file.status = status;
	}

      fp = BlkLoc(f)->file.fd.fp;
      if (status & Fs_Writing) {
	 fseek(fp, 0L, SEEK_CUR);
	 BlkLoc(f)->file.status &= ~Fs_Writing;
	 }
      BlkLoc(f)->file.status |= Fs_Reading;


#if !MSWIN32
      /*
       *  If reading a directory, return up to i bytes of next entry.
       */
      if ((BlkLoc(f)->file.status & Fs_Directory) != 0) {
         char *sp;
         struct dirent *de = readdir((DIR*) fp);
         if (de == NULL)
            fail;
         nbytes = strlen(de->d_name);
         if (nbytes > i)
            nbytes = i;
         Protect(sp = alcstr(de->d_name, nbytes), runerr(0));
         return string(nbytes, sp);
         }
#endif

      /*
       * Be sure that a positive number of bytes is to be read.
       */
      if (i <= 0) {
	 irunerr(205, i);

	 errorfail;
	 }

      /* Remember, sockets are always unbuffered */
      if (status & Fs_Unbuf) {
	 /* We do one read(2) call here to avoid interactions with stdio */

	 int fd;

	 if ((fd = get_fd(f, 0)) < 0)
	    runerr(174, f);

	 IntVal(amperErrno) = 0;
	 if (u_read(fd, i, &s) == 0)
	    fail;
	 return s;
      }

      /*
       * For now, assume we can read the full number of bytes.
       */
      Protect(StrLoc(s) = alcstr(NULL, i), runerr(0));
      StrLen(s) = 0;

#ifdef HAVE_LIBZ
      /*
       * Read characters from a compressed file
       */
      if (status & Fs_Compress) {
	 if (gzeof(fp)) fail;
	 slen = gzread((gzFile)fp,StrLoc(s),i);
	 if (slen == 0)
	    fail;
	 else if (slen == -1)
	    runerr(214);
	 return string(slen, StrLoc(s));
	 }
#endif					/* HAVE_LIBZ */


      tally = longread(StrLoc(s),sizeof(char),i,fp);

      if (tally == 0)
	 fail;
      StrLen(s) = tally;
      /*
       * We may not have used the entire amount of storage we reserved.
       */
      nbytes = DiffPtrs(StrLoc(s) + tally, strfree);
      EVStrAlc(nbytes);
      strtotal += nbytes;
      strfree = StrLoc(s) + tally;
      return s;
      }
end


"remove(s) - remove the file named s."

function{0,1} remove(s)

   /*
    * Make a C-style string out of s
    */
   if !cnv:C_string(s) then
      runerr(103,s)
   abstract {
      return null
      }

   inline {
      if (remove(s) != 0) {
	 IntVal(amperErrno) = 0;
#if MSWIN32
#define rmdir _rmdir
#endif					/* MSWIN32 */
	 if (rmdir(s) != 0) {
	    IntVal(amperErrno) = errno;
	    fail;
            }
	 fail;
         }
      return nulldesc;
      }
end


"rename(s1,s2) - rename the file named s1 to have the name s2."

function{0,1} rename(s1,s2)

   /*
    * Make C-style strings out of s1 and s2
    */
   if !cnv:C_string(s1) then
      runerr(103,s1)
   if !cnv:C_string(s2) then
      runerr(103,s2)

   abstract {
      return null
      }

   body {
#if MSWIN32
      int i=0;
      if ((i = rename(s1,s2)) != 0) {
	 remove(s2);
	 if (rename(s1,s2) != 0)
	    fail;
	 }
      return nulldesc;
#else					/*NT*/
      if (rename(s1,s2) != 0)
	 fail;
      return nulldesc;
#endif					/* MSWIN32 */
      }
end


"seek(f,i) - seek to offset i in file f."
" [[ What about seek error ? ]] "

function{0,1} seek(f,o)

   /*
    * f must be a file
    */
   if !is:file(f) then
      runerr(105,f)

   /*
    * o must be an integer and defaults to 1.
    */
   if !def:C_integer(o,1L) then
      runerr(0)

   abstract {
      return file
      }

   body {
      FILE *fd;

      fd = BlkLoc(f)->file.fd.fp;
      if (BlkLoc(f)->file.status == 0)
	 fail;

      if (BlkLoc(f)->file.status & Fs_Directory)
	 fail;

#ifdef HAVE_LIBZ
        if ( BlkLoc(f)->file.status & Fs_Compress) {
            if (o<0)
               fail;
            else
               if (gzseek(fd, o - 1, SEEK_SET)==-1)
                   fail;
               else
                   return f;        
             }
#endif                                 /* HAVE_LIBZ */

      if (o > 0) {
	 if (fseek(fd, o - 1, SEEK_SET) == -1)
	    fail;

	 }

      else {

	 if (fseek(fd, o, SEEK_END) == -1)
	    fail;

	 }
      BlkLoc(f)->file.status &= ~(Fs_Reading | Fs_Writing);
      return f;
      }
end




"where(f) - return current offset position in file f."

function{0,1} where(f)

   if !is:file(f) then
      runerr(105,f)

   abstract {
      return integer
      }

   body {
      FILE *fd;
      long ftell();
      long pos;

      fd = BlkLoc(f)->file.fd.fp;

      if (BlkLoc(f)->file.status == 0)
	 fail;

      if ((BlkLoc(f)->file.status & Fs_Directory) != 0)
         fail;

      pos = ftell(fd) + 1;
      if (pos == 0)
	 fail;	/* may only be effective on ANSI systems */

      return C_integer pos;
      }
end

/*
 * stop(), write(), and writes() differ in whether they stop the program
 *  and whether they output newlines. The macro GenWrite is used to
 *  produce all three functions.
 */
#define False 0
#define True 1

#begdef DefaultFile(error_out)
   inline {
#if error_out
      if ((k_errout.status & Fs_Write) == 0)
	 runerr(213);
      else {
	 f.fp = k_errout.fd.fp;
	 }
#else					/* error_out */
      if ((k_output.status & Fs_Write) == 0)
	 runerr(213);
      else {
	 f.fp = k_output.fd.fp;
	 }
#endif					/* error_out */
      }
#enddef					/* DefaultFile */

#begdef Finish(retvalue, nl, terminate)
#if nl
   /*
    * Append a newline to the file.
    */

#ifdef HAVE_LIBZ
   if (status & Fs_Compress) {
      if (gzputc((gzFile)(f.fp),'\n')==-1) {
          runerr(214);
          }
      }
   else
#endif					/* HAVE_LIBZ */

      if (status & Fs_Socket) {
	 if (sock_write(f.fd, "\n", 1) < 0)
#if terminate
	    syserr("sock_write failed in stop()");
#else
	    fail;
#endif
         }
      else
	 putc('\n', f.fp);

#endif					/* nl */

   /*
    * Flush the file.
    */

      if (!(status & Fs_Socket)) {

#ifdef HAVE_LIBZ
      if (status & (Fs_Compress
		    )) {

       /*if (ferror(f))
	    runerr(214);
         gzflush(f, Z_SYNC_FLUSH);  */
         }
      else{
         if (ferror(f.fp))
	    runerr(214);
         fflush(f.fp);
      }
#else					/* HAVE_LIBZ */
         if (ferror(f.fp))
	    runerr(214);
         fflush(f.fp);
      
#endif					/* HAVE_LIBZ */

      }

#if terminate
	    c_exit(EXIT_FAILURE);
            fail; /* Not reached */
#else					/* terminate */
	    return retvalue;
#endif					/* terminate */
#enddef					/* Finish */

#begdef GenWrite(name, nl, terminate)

#name "(a,b,...) - write arguments"
#if !nl
   " without newline terminator"
#endif					/* nl */
#if terminate
   " (starting on error output) and stop"
#endif					/* terminate */
"."

#if terminate
function {} name(x[nargs])
#else					/* terminate */
function {1} name(x[nargs])
#endif					/* terminate */

   declare {
      union {
      FILE *fp;
#ifdef Graphics
      struct _wbinding *wb;
#endif					/* Graphics */
      int  fd;
      } f;
      word status =
#if terminate
	k_errout.status;
#else					/* terminate */
	k_output.status;
#endif					/* terminate */

#ifdef BadCode
      struct descrip temp;
#endif					/* BadCode */
      }

#if terminate
   abstract {
      return empty_type
      }
#endif					/* terminate */

   len_case nargs of {
      0: {
#if !terminate
	 abstract {
	    return null
	    }
#endif					/* terminate */
	 DefaultFile(terminate)
	 body {
	    Finish(nulldesc, nl, terminate)
	    }
	 }

      default: {
#if !terminate
	 abstract {
	    return type(x)
	    }
#endif					/* terminate */
	 /*
	  * See if we need to start with the default file.
	  */
	 if !is:file(x[0]) then
	    DefaultFile(terminate)

	 body {
	    tended struct descrip t;
	    register word n;

	    /*
	     * Loop through the arguments.
	     */
	    for (n = 0; n < nargs; n++) {
	       if (is:file(x[n])) {	/* Current argument is a file */
#if nl
		  /*
		   * If this is not the first argument, output a newline to the
		   * current file and flush it.
		   */
		  if (n > 0) {

		     /*
		      * Append a newline to the file and flush it.
		      */
#ifdef HAVE_LIBZ
                     if (status & Fs_Compress) {
			if (gzputc(f.fp,'\n')==-1)
                            runerr(214);
/*			gzflush(f.fp,4); */
			  }
		     else {
                          }
#endif					/* HAVE_LIBZ */


			if (status & Fs_Socket) {
			   if (sock_write(f.fd, "\n", 1) < 0)
#if terminate
			      syserr("sock_write failed in stop()");
#else
			      fail;
#endif
			   }
			else {
			putc('\n', f.fp);
			if (ferror(f.fp))
			   runerr(214);
			fflush(f.fp);
                        }
		     }
#endif					/* nl */


		  /*
		   * Switch the current file to the file named by the current
		   * argument providing it is a file.
		   */
		  status = BlkLoc(x[n])->file.status;
		  if ((status & Fs_Write) == 0)
		     runerr(213, x[n]);
		  f.fp = BlkLoc(x[n])->file.fd.fp;
		  }
	       else {
		  /*
		   * Convert the argument to a string, defaulting to a empty
		   *  string.
		   */
		  if (!def:tmp_string(x[n],emptystr,t))
		     runerr(109, x[n]);

		  /*
		   * Output the string.
		   */

#ifdef HAVE_LIBZ
	          if (status & Fs_Compress){
                     if (gzputs(f.fp, StrLoc(t))==-1) 
			runerr(214);
                     }
		  else
#endif					/* HAVE_LIBZ */



		     if (status & Fs_Socket) {

			if (sock_write(f.fd, StrLoc(t), StrLen(t)) < 0) {
#if terminate
			   syserr("sock_write failed in stop()");
#else
			   fail;
#endif
			   }
		     } else {
		     if (putstr(f.fp, &t) == Failed)
			runerr(214, x[n]);
			}
		  }
	       }

	    Finish(x[n-1], nl, terminate)
	    }
	 }
      }
end
#enddef					/* GenWrite */

GenWrite(stop,	 True,	True)  /* stop(s, ...) - write message and stop */
GenWrite(write,  True,	False) /* write(s, ...) - write with new-line */
GenWrite(writes, False, False) /* writes(s, ...) - write with no new-line */



"getch() - return a character from console."

function{0,1} getch()
   abstract {
      return string;
      }
   body {
      int i;
      i = getch();
      if (i<0 || i>255)
	 fail;
      return string(1, (char *)&allchars[FromAscii(i) & 0xFF]);
      }
end

"getche() -- return a character from console with echo."

function{0,1} getche()
   abstract {
      return string;
      }
   body {
      int i;
      i = getche();
      if (i<0 || i>255)
	 fail;
      return string(1, (char *)&allchars[FromAscii(i) & 0xFF]);
      }
end


"kbhit() -- Check to see if there is a keyboard character waiting to be read."

function{0,1} kbhit()
   abstract {
      return null
      }
   inline {
      if (kbhit())
	 return nulldesc;
      else fail;
      }
end


"chdir(s) - change working directory to s."
function{0,1} chdir(s)
   if !cnv:string(s) then
       if !is:null(s) then
	  runerr(103, s)
   abstract {
      return string
   }
   body {

#if PORT
   Deliberate Syntax Error
#endif                                  /* PORT */

#if MSWIN32 || UNIX

      char path[MaxPath];
      int len;

      if (is:string(s)) {
	 tended char *dir;
	 cnv:C_string(s, dir);
	 if (chdir(dir) != 0)
	    fail;
	 }
      if (getcwd(path, sizeof(path)) == NULL)
	  fail;

      len = strlen(path);
      Protect(StrLoc(result) = alcstr(path, len), runerr(0));
      StrLen(result) = len;
      return result;

#endif
   }
end


"delay(i) - delay for i milliseconds."

function{0,1} delay(n)

   if !cnv:C_integer(n) then
      runerr(101,n)
   abstract {
      return null
      }

   inline {
      if (idelay(n) == Failed)
        fail;
#ifdef Graphics
      pollctr >>= 1;
      pollctr++;
#endif					/* Graphics */
      return nulldesc;
      }
end

"flush(f) - flush file f."

function{1} flush(f)
   if !is:file(f) then
      runerr(105, f)
   abstract {
      return type(f)
      }

   body {
      FILE *fp = BlkLoc(f)->file.fd.fp;
      int status = BlkLoc(f)->file.status;

      /*
       * File types for which no flushing is possible, or is a no-op.
       */
      if (((status & (Fs_Read | Fs_Write)) == 0)	/* if already closed */
	  || (status & Fs_Directory)
	  || (status & Fs_Socket)
	  )
	 return f;

	 fflush(fp);

      /*
       * Return the flushed file.
       */
      return f;
      }
end
