include ../../Makedefs

CFLAGS:=-fPIC $(CFLAGS)

ifeq (@CYGWIN@, yes)
all :
else
ifeq (@MYSQL_VERSION@,)
all : objecticonipclib.so

else
all : objecticonipclib.so objecticonmysqllib.so

objecticonmysqllib.so : mysql.o
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o objecticonmysqllib.so mysql.o @MYSQL_LDFLAGS@

mysql.o : mysql.r
	$(RTT) -h gmysql.h mysql.r
	$(CC) $(CPPFLAGS) @MYSQL_CFLAGS@ $(CFLAGS) -c mysql.c -o mysql.o
	$(RM) mysql.c
endif
endif

objecticonipclib.so : ipc.o
	$(CC) $(CFLAGS) $(LDFLAGS) -shared -o objecticonipclib.so ipc.o

ipc.o : ipc.r
	$(RTT) -h gipc.h ipc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ipc.c -o ipc.o
	$(RM) ipc.c

clean :
	rm -f *.u *.o *.so *.a mysql.c ipc.c

etags:
	etags --lang=c *.r *.h
