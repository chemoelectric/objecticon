#  Makefile for the (Un)Icon run-time system.

include ../../Makedefs

CWARN = -Wall -fno-strict-aliasing

HDRS = ../h/define.h ../h/config.h ../h/typedefs.h ../h/monitor.h\
	  ../h/cstructs.h ../h/cpuconf.h ../h/grttin.h\
	  ../h/rmacros.h ../h/rexterns.h ../h/rstructs.h \
	  ../h/rproto.h ../h/mproto.h ../h/sys.h

GRAPHICSHDRS = ../h/graphics.h ../h/xwin.h

default: oix

XOBJS=	cnv.o data.o def.o errmsg.o fconv.o fload.o fmath.o\
	fmisc.o fmonitr.o fscan.o fstr.o fstranl.o fstruct.o fsys.o\
	fwindow.o imain.o imisc.o init.o interp.o invoke.o \
	keyword.o lmisc.o oarith.o oasgn.o ocat.o ocomp.o native.o \
	omisc.o oref.o oset.o ovalue.o ralc.o rcoexpr.o rcomp.o \
	rdebug.o rlocal.o rlrgint.o rmemmgt.o rmisc.o rstruct.o rsys.o\
	rwinrsc.o rwinsys.o rwindow.o posix.o

RTTC=$(XOBJS:.o=.c)

COBJS=	../common/mlocal.o rswitch.o

OBJS=	$(XOBJS) $(COBJS)

rwinsys.o: rxwin.ri rmswin.ri rxkeysyms.ri
rwinrsc.o: rxrsc.ri

all:	oix

oix:	$(OBJS)
	$(CC) $(CFLAGS) -Wl,-E $(LDFLAGS) -o oix $(OBJS) $(LIBS)
	$(CP) oix $(OIBIN)

%.o: %.r $(HDRS)
	$(RTT) $<
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $*.c
	$(RM) $*.c

%.o: %.s
	$(CC) $(CFLAGS) -c $<

clean:		
	rm -f *.o $(RTTC) rt.db rt.a rttcur.lst rttfull.lst oix keysymtocodepoint

# Compile with make KEYSYMS=Y
ifeq ($(KEYSYMS),Y)

keysymtocodepoint: keysymtocodepoint.icn
	oit -s keysymtocodepoint.icn

rxkeysyms.ri:	keysyms.txt keysymtocodepoint
	keysymtocodepoint <keysyms.txt >rxkeysyms.ri

endif
