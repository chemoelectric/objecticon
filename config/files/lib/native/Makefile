include ../../Makedefs

CFLAGS:=-fPIC $(CFLAGS)
ifeq (@CYGWIN@, yes)
  TARGET=
else
  TARGET=objecticonipclib.so
  ifneq (@MYSQL_VERSION@,)
    TARGET:=$(TARGET) objecticonmysqllib.so
  endif
  ifneq (@CAIRO_VERSION@,)
    TARGET:=$(TARGET) objecticoncairolib.so
  endif
endif

all : $(TARGET)

objecticonmysqllib.so : mysql.o
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o objecticonmysqllib.so mysql.o @MYSQL_LDFLAGS@

mysql.o : mysql.r
	$(RTT) -h gmysql.h mysql.r
	$(CC) $(CPPFLAGS) @MYSQL_CFLAGS@ $(CFLAGS) -c mysql.c -o mysql.o
	$(RM) mysql.c

objecticonipclib.so : ipc.o
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o objecticonipclib.so ipc.o

ipc.o : ipc.r
	$(RTT) -h gipc.h ipc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ipc.c -o ipc.o
	$(RM) ipc.c

objecticoncairolib.so : cairo.o
	$(CC) @CAIRO_LDFLAGS@ -shared -fPIC -o objecticoncairolib.so cairo.o @CAIRO_LIBS@

cairo.o : cairo.r
	$(RTT) -h gcairo.h cairo.r
	$(CC) @CAIRO_CPPFLAGS@ $(CPPFLAGS) $(CFLAGS) -fPIC -c cairo.c -o cairo.o
	$(RM) cairo.c

clean :
	rm -f *.u *.o *.so *.a mysql.c ipc.c cairo.c

etags:
	$(ETAGS) $(RTLTAGS) *.r *.h
