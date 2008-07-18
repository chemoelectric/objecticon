#  Makefile for the (Un)Icon run-time system.

include ../../Makedefs

HDRS = ../h/define.h ../h/config.h ../h/typedefs.h ../h/monitor.h\
	  ../h/proto.h ../h/cstructs.h ../h/cpuconf.h ../h/grttin.h\
	  ../h/rmacros.h ../h/rexterns.h ../h/rstructs.h \
	  ../h/rproto.h ../h/mproto.h ../h/sys.h

GRAPHICSHDRS = ../h/graphics.h ../h/xwin.h

default: oix

XOBJS=	cnv.o data.o def.o errmsg.o extcall.o fconv.o fload.o fmath.o\
	fmisc.o fmonitr.o fscan.o fstr.o fstranl.o fstruct.o fsys.o\
	fwindow.o imain.o imisc.o init.o interp.o invoke.o \
	keyword.o lmisc.o oarith.o oasgn.o ocat.o ocomp.o native.o \
	omisc.o oref.o oset.o ovalue.o ralc.o rcoexpr.o rcomp.o \
	rdebug.o rlocal.o rlrgint.o rmemmgt.o rmisc.o rstruct.o rsys.o\
	rwinrsc.o rgfxsys.o rwinsys.o rwindow.o fxtra.o rposix.o

COBJS=	../common/long.o ../common/time.o \
	../common/rswitch.o ../common/redirerr.o ../common/xwindow.o \
	../common/alloc.o ../common/mlocal.o

OBJS=	$(XOBJS) $(COBJS)

all:	oix

oix:	$(OBJS)
	$(CC) $(CFLAGS) -Wl,-E $(LDFLAGS) -o oix $(OBJS) $(LIBS)
	cp oix $(OIBIN)

%.o: %.r $(HDRS)
	rtt $<
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $*.c
	$(RM) $*.c

clean:		
	rm -f *.o *.c rt.db rt.a rttcur.lst rttfull.lst oix
