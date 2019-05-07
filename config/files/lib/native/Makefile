include ../../Makedefs

ifeq (@HAVE_DYNAMIC_LINKING@, no)
  TARGET=
else
  TARGET=objecticonipclib.so objecticonmemdebug.so
  ifneq (@MYSQL_VERSION@,)
    TARGET:=$(TARGET) objecticonmysqllib.so
  endif
  ifneq (@CAIRO_VERSION@,)
    TARGET:=$(TARGET) objecticoncairolib.so
  endif
  ifneq (@OPENSSL_VERSION@,)
    TARGET:=$(TARGET) objecticonssllib.so
  endif
endif

all : $(TARGET)

objecticonmysqllib.so : mysql.o
	$(CC) $(LDFLAGS) $(DYNAMIC_LIB_LDFLAGS) -o objecticonmysqllib.so mysql.o @MYSQL_LDFLAGS@

mysql.o : mysql.r
	$(RTT) -h gmysql.h mysql.r
	$(CC) @MYSQL_CFLAGS@ $(CPPFLAGS) $(CFLAGS) $(DYNAMIC_LIB_CFLAGS) -c mysql.c -o mysql.o
	$(RM) mysql.c

objecticonipclib.so : ipc.o
	$(CC) $(LDFLAGS) $(DYNAMIC_LIB_LDFLAGS) -o objecticonipclib.so ipc.o

ipc.o : ipc.r
	$(RTT) -h gipc.h ipc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DYNAMIC_LIB_CFLAGS) -c ipc.c -o ipc.o
	$(RM) ipc.c

objecticoncairolib.so : cairo.o
	$(CC) @CAIRO_LDFLAGS@ $(DYNAMIC_LIB_LDFLAGS) -o objecticoncairolib.so cairo.o @CAIRO_LIBS@

cairo.o : cairo.r
	$(RTT) -h gcairo.h cairo.r
	$(CC) @CAIRO_CPPFLAGS@ $(CPPFLAGS) $(CFLAGS) $(DYNAMIC_LIB_CFLAGS) -c cairo.c -o cairo.o
	$(RM) cairo.c

objecticonssllib.so : ssl.o
	$(CC) @OPENSSL_LDFLAGS@ $(DYNAMIC_LIB_LDFLAGS) -o objecticonssllib.so ssl.o @OPENSSL_LIBS@

ssl.o : ssl.r
	$(RTT) -h gssl.h ssl.r
	$(CC) @OPENSSL_CPPFLAGS@ $(CPPFLAGS) $(CFLAGS) $(DYNAMIC_LIB_CFLAGS) -c ssl.c -o ssl.o
	$(RM) ssl.c

objecticonmemdebug.so : memdebug.o
	$(CC) $(DYNAMIC_LIB_LDFLAGS) -o objecticonmemdebug.so memdebug.o

memdebug.o : memdebug.r
	$(RTT) memdebug.r
	$(CC) $(CPPFLAGS) $(CFLAGS) $(DYNAMIC_LIB_CFLAGS) -c memdebug.c -o memdebug.o
	$(RM) memdebug.c

clean :
	$(RM) *.u *.o *.so *.a mysql.c ipc.c cairo.c ssl.c

etags:
	$(ETAGS) $(RTLTAGS) *.r *.h
