include ../../Makedefs

OBJS=	getopt.o strtbl.o membuff.o \
	mlocal.o alloc.o

CSRC=$(OBJS:.o=.c)

all:		$(OBJS)

clean:		
		rm -f *.o

etags:
		$(ETAGS) $(CSRC) gdip.cpp win32.c

$(OBJS): ../h/define.h ../h/config.h ../h/cstructs.h ../h/mproto.h \
	  ../h/typedefs.h

identify.o: ../h/version.h

literals.o: ../h/esctab.h

xwindow.o: ../h/graphics.h ../h/xwin.h

