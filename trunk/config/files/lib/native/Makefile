include ../../Makedefs

CWARN=-Wall -fno-strict-aliasing
CFLAGS:=-fPIC $(CFLAGS)
CPPFLAGS:=$(CPPFLAGS) @MYSQL_CFLAGS@

ifeq (@MYSQL_VERSION@,)
all : objecticonipclib.so

else
all : objecticonipclib.so objecticonmysqllib.so

objecticonmysqllib.so : mysql.o
	$(CC) $(LDFLAGS) -shared -fPIC -o objecticonmysqllib.so mysql.o @MYSQL_LDFLAGS@

mysql.o : mysql.r
	$(RTT) -h gmysql.h mysql.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c mysql.c -o mysql.o
	$(RM) mysql.c
endif

objecticonipclib.so : ipc.o
	$(CC) $(LDFLAGS) -shared -fPIC -o objecticonipclib.so ipc.o

ipc.o : ipc.r
	$(RTT) -h gipc.h ipc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ipc.c -o ipc.o
	$(RM) ipc.c

clean :
	rm -f *.u *.o *.so *.a mysql.c ipc.c
