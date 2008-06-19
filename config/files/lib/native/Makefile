include ../../Makedefs

.PHONY: all clean

all : objecticonipclib.so objecticonmysqllib.so

clean :
	rm -f *.u *.o *.so *.a

CWARN = -Wall
CFLAGS=-fPIC $(CWARN) @CFLAGS@
CPPFLAGS=-I$(OIHOME)/base/h -I- @CPPFLAGS@ -I$(MYSQL_HOME)/include

objecticonipclib.so : ipc.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonipclib.so ipc.o $(OIHOME)/base/common/nativeutils.o

objecticonmysqllib.so : mysql.o
	$(CC) $(CDBG) -shared -fPIC -o objecticonmysqllib.so mysql.o \
		$(OIHOME)/base/common/nativeutils.o \
		-L$(MYSQL_HOME)/lib \
		-lmysqlclient -lz -lm -lcrypt
