#  Makefile for the (Un)Icon run-time system.

include ../../Makedefs

HDRS = ../h/define.h ../h/config.h ../h/typedefs.h ../h/monitor.h\
	  ../h/cstructs.h ../h/cpuconf.h ../h/grttin.h\
	  ../h/rmacros.h ../h/rexterns.h ../h/rstructs.h \
	  ../h/rproto.h ../h/mproto.h ../h/sys.h

GRAPHICSHDRS = ../h/graphics.h ../h/xwin.h

default: oix

XOBJS=	cnv.o def.o errmsg.o fconv.o fmath.o\
	fmisc.o fmonitr.o fscan.o fstr.o fstranl.o fstruct.o fsys.o\
	fwindow.o imisc.o init.o interp.o invoke.o \
	keyword.o oarith.o oasgn.o ocat.o ocomp.o native.o \
	omisc.o oref.o oset.o ovalue.o ralc.o rcomp.o \
	rdebug.o rlrgint.o rmemmgt.o rmisc.o rstruct.o rsys.o\
	rwinsys.o rwindow.o posix.o cstruct.o

RTTC=$(XOBJS:.o=.c)
RFILES=$(XOBJS:.o=.r)
RTTTMP=$(XOBJS:.o=.tmp)

COBJS=	../common/mlocal.o

OBJS=	$(XOBJS) $(COBJS)

rwinsys.o: rxwin.ri rmswin.ri rxkeysyms.ri
invoke.o: invokeiasm.ri
interp.o: interpiasm.ri
init.o: initiasm.ri
oref.o: orefiasm.ri

all:	oix

oix:	$(OBJS)
	$(CC) $(CFLAGS) $(DYNAMIC_EXPORT_LDFLAGS) $(LDFLAGS) -o oix $(OBJS) $(LIBS)
	$(INSTALL) oix "$(OI_BIN)"

%.o: %.r $(HDRS)
	$(RTT) $<
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $*.c
	$(RM) $*.c

clean:		
	rm -f *.o $(RTTC) $(RTTTMP) rt.db rt.a rttcur.lst rttfull.lst oix keysymtocodepoint iasm

etags:
	$(ETAGS) $(RTLTAGS) $(RFILES) rmswin.ri rxwin.ri

# Compile with make IASM=Y
ifeq ($(IASM),Y)
iasm: iasm.icn
	oit -s iasm.icn
invokeiasm.ri:	invokeiasm.in iasm
	./iasm <invokeiasm.in >invokeiasm.ri
interpiasm.ri:	interpiasm.in iasm
	./iasm <interpiasm.in >interpiasm.ri
initiasm.ri:	initiasm.in iasm
	./iasm <initiasm.in >initiasm.ri
orefiasm.ri:	orefiasm.in iasm
	./iasm <orefiasm.in >orefiasm.ri
endif

# Compile with make KEYSYMS=Y
ifeq ($(KEYSYMS),Y)

keysymtocodepoint: keysymtocodepoint.icn
	oit -s keysymtocodepoint.icn

rxkeysyms.ri:	keysyms.txt keysymtocodepoint
	./keysymtocodepoint <keysyms.txt >rxkeysyms.ri

endif
