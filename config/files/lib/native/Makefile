include ../../Makedefs

.PHONY: all clean

CWARN = -Wall -fno-strict-aliasing
CFLAGS=-fPIC $(CWARN) @CFLAGS@
CPPFLAGS=-I$(OIHOME)/base/h -I- @CPPFLAGS@ @MYSQL_CFLAGS@

ifeq (@MYSQL_VERSION@,)
all : objecticonipclib.so

else
all : objecticonipclib.so objecticonmysqllib.so

objecticonmysqllib.so : mysql.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonmysqllib.so mysql.o @MYSQL_LDFLAGS@

mysql.o : mysql.r
	rtt -h gmysql.h mysql.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xmysql.c -o mysql.o
	$(RM) xmysql.c
endif

objecticonipclib.so : ipc.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonipclib.so ipc.o

ipc.o : ipc.r
	rtt -h gipc.h ipc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xipc.c -o ipc.o
	$(RM) xipc.c

clean :
	rm -f *.u *.o *.so *.a x*.c
