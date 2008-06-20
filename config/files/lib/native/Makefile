include ../../Makedefs

.PHONY: all clean

CWARN = -Wall
CFLAGS=-fPIC $(CWARN) @CFLAGS@
CPPFLAGS=-I$(OIHOME)/base/h -I- @CPPFLAGS@ @MYSQL_CFLAGS@

ifeq (@MYSQL_VERSION@,)
all : objecticonipclib.so

else
all : objecticonipclib.so objecticonmysqllib.so

objecticonmysqllib.so : mysql.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonmysqllib.so mysql.o \
		$(OIHOME)/base/common/nativeutils.o @MYSQL_LDFLAGS@
endif

objecticonipclib.so : ipc.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonipclib.so ipc.o $(OIHOME)/base/common/nativeutils.o

clean :
	rm -f *.u *.o *.so *.a
