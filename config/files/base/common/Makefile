include ../../Makedefs

OBJS=	strtbl.o \
	mlocal.o alloc.o

CSRC=$(OBJS:.o=.c)

all:		$(OBJS)

clean:		
		rm -f *.o

etags:
		$(ETAGS) $(CSRC)

$(OBJS): ../h/define.h ../h/config.h ../h/cstructs.h ../h/mproto.h \
	  ../h/typedefs.h ../h/cpuconf.h

identify.o: ../h/version.h

literals.o: ../h/esctab.h

xwindow.o: ../h/graphics.h ../h/xwin.h

