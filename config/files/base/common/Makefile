include ../../Makedefs

CWARN = -Wall

OBJS=	long.o getopt.o time.o identify.o strtbl.o \
	mlocal.o literals.o rswitch.o alloc.o\
	rswitch.o

all:		$(OBJS)

clean:		
		rm -f *.o

$(OBJS): ../h/define.h ../h/config.h ../h/cstructs.h ../h/mproto.h \
	  ../h/typedefs.h ../h/cpuconf.h

identify.o: ../h/version.h

literals.o: ../h/esctab.h

xwindow.o: ../h/graphics.h ../h/xwin.h

