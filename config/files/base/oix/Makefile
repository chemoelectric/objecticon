#  Makefile for the (Un)Icon run-time system.

include ../../Makedefs

HDRS = ../h/define.h ../h/config.h ../h/typedefs.h ../h/monitor.h\
	  ../h/proto.h ../h/cstructs.h ../h/cpuconf.h ../h/grttin.h\
	  ../h/rmacros.h ../h/rexterns.h ../h/rstructs.h \
	  ../h/rproto.h ../h/mproto.h ../h/sys.h

GRAPHICSHDRS = ../h/graphics.h ../h/xwin.h

default: oix

####################################################################
#
# Make entries for oix
#

XOBJS=	cnv.o data.o def.o errmsg.o extcall.o fconv.o fload.o fmath.o\
	fmisc.o fmonitr.o fscan.o fstr.o fstranl.o fstruct.o fsys.o\
	fwindow.o imain.o imisc.o init.o interp.o invoke.o \
	keyword.o lmisc.o oarith.o oasgn.o ocat.o ocomp.o native.o \
	omisc.o oref.o oset.o ovalue.o ralc.o rcoexpr.o rcomp.o \
	rdebug.o rlocal.o rlrgint.o rmemmgt.o rmisc.o rstruct.o rsys.o\
	rwinrsc.o rgfxsys.o rwinsys.o rwindow.o fxtra.o rposix.o

COBJS=	../common/long.o ../common/time.o ../common/save.o \
	../common/rswitch.o ../common/redirerr.o ../common/xwindow.o \
	../common/alloc.o ../common/mlocal.o

OBJS=	$(XOBJS) $(COBJS)

all:	oix

oix:	$(OBJS)
	$(CC) $(CFLAGS) -Wl,-E $(LDFLAGS) -o oix $(OBJS) $(LIBS)
	cp oix $(OIBIN)

cnv.o: cnv.r $(HDRS)
	rtt cnv.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c cnv.c
	$(RM) cnv.c

data.o: data.r $(HDRS) ../h/kdefs.h ../h/fdefs.h ../h/odefs.h
	rtt data.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c data.c
	$(RM) data.c

def.o: def.r $(HDRS)
	rtt def.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c def.c
	$(RM) def.c

errmsg.o: errmsg.r $(HDRS)
	rtt errmsg.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c errmsg.c
	$(RM) errmsg.c

extcall.o: extcall.r $(HDRS)
	rtt extcall.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c extcall.c
	$(RM) extcall.c

fconv.o: fconv.r $(HDRS)
	rtt fconv.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fconv.c
	$(RM) fconv.c

fdb.o: fdb.r $(HDRS)
	rtt fdb.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fdb.c
	$(RM) fdb.c

fload.o: fload.r $(HDRS)
	rtt fload.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fload.c
	$(RM) fload.c

fmath.o: fmath.r $(HDRS)
	rtt fmath.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fmath.c
	$(RM) fmath.c

fmisc.o: fmisc.r $(HDRS)
	rtt fmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fmisc.c
	$(RM) fmisc.c

fmonitr.o: fmonitr.r $(HDRS)
	rtt fmonitr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fmonitr.c
	$(RM) fmonitr.c

fscan.o: fscan.r $(HDRS)
	rtt fscan.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fscan.c
	$(RM) fscan.c

fstr.o: fstr.r $(HDRS)
	rtt fstr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fstr.c
	$(RM) fstr.c

fstranl.o: fstranl.r $(HDRS)
	rtt fstranl.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fstranl.c
	$(RM) fstranl.c

fstruct.o: fstruct.r $(HDRS)
	rtt fstruct.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fstruct.c
	$(RM) fstruct.c

fsys.o: fsys.r $(HDRS)
	rtt fsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fsys.c
	$(RM) fsys.c

fwindow.o: fwindow.r $(HDRS) $(GRAPHICSHDRS)
	rtt fwindow.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fwindow.c
	$(RM) fwindow.c

imain.o: imain.r $(HDRS) ../h/nativedefs.h
	rtt imain.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c imain.c
	$(RM) imain.c

imisc.o: imisc.r $(HDRS)
	rtt imisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c imisc.c
	$(RM) imisc.c

native.o: native.r $(HDRS)
	rtt native.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c native.c
	$(RM) native.c

init.o: init.r $(HDRS) ../h/odefs.h ../h/version.h
	rtt init.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c init.c
	$(RM) init.c

interp.o: interp.r $(HDRS)
	rtt interp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c interp.c
	$(RM) interp.c

invoke.o: invoke.r $(HDRS)
	rtt invoke.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c invoke.c
	$(RM) invoke.c

keyword.o: keyword.r $(HDRS) ../h/features.h ../h/version.h
	rtt keyword.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c keyword.c
	$(RM) keyword.c

lmisc.o: lmisc.r $(HDRS)
	rtt lmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c lmisc.c
	$(RM) lmisc.c

oarith.o: oarith.r $(HDRS)
	rtt oarith.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c oarith.c
	$(RM) oarith.c

oasgn.o: oasgn.r $(HDRS)
	rtt oasgn.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c oasgn.c
	$(RM) oasgn.c

ocat.o: ocat.r $(HDRS)
	rtt ocat.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ocat.c
	$(RM) ocat.c

ocomp.o: ocomp.r $(HDRS)
	rtt ocomp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ocomp.c
	$(RM) ocomp.c

omisc.o: omisc.r $(HDRS)
	rtt omisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c omisc.c
	$(RM) omisc.c

oref.o: oref.r $(HDRS)
	rtt oref.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c oref.c
	$(RM) oref.c

oset.o: oset.r $(HDRS)
	rtt oset.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c oset.c
	$(RM) oset.c

ovalue.o: ovalue.r $(HDRS)
	rtt ovalue.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ovalue.c
	$(RM) ovalue.c

ralc.o: ralc.r $(HDRS)
	rtt ralc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ralc.c
	$(RM) ralc.c

rcoexpr.o: rcoexpr.r $(HDRS)
	rtt rcoexpr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rcoexpr.c
	$(RM) rcoexpr.c

rcomp.o: rcomp.r $(HDRS)
	rtt rcomp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rcomp.c
	$(RM) rcomp.c

rdebug.o: rdebug.r $(HDRS)
	rtt rdebug.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rdebug.c
	$(RM) rdebug.c

rlocal.o: rlocal.r $(HDRS)
	rtt rlocal.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rlocal.c
	$(RM) rlocal.c

rlrgint.o: rlrgint.r $(HDRS)
	rtt rlrgint.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rlrgint.c
	$(RM) rlrgint.c

rmemmgt.o: rmemmgt.r $(HDRS)
	rtt rmemmgt.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rmemmgt.c
	$(RM) rmemmgt.c

rmisc.o: rmisc.r $(HDRS)
	rtt rmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rmisc.c
	$(RM) rmisc.c

rposix.o: rposix.r $(HDRS) ../h/posix.h
	rtt rposix.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rposix.c
	$(RM) rposix.c

rstruct.o: rstruct.r $(HDRS)
	rtt rstruct.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rstruct.c
	$(RM) rstruct.c

rsys.o: rsys.r $(HDRS)
	rtt rsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rsys.c
	$(RM) rsys.c

rwinrsc.o: rwinrsc.r $(HDRS) $(GRAPHICSHDRS) rxrsc.ri
	rtt rwinrsc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rwinrsc.c
	$(RM) rwinrsc.c

rgfxsys.o: rgfxsys.r $(HDRS) $(GRAPHICSHDRS)
	rtt rgfxsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rgfxsys.c
	$(RM) rgfxsys.c

rwinsys.o: rwinsys.r $(HDRS) $(GRAPHICSHDRS) rxwin.ri
	rtt rwinsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rwinsys.c
	$(RM) rwinsys.c

rwindow.o: rwindow.r $(HDRS) $(GRAPHICSHDRS)
	rtt rwindow.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c rwindow.c
	$(RM) rwindow.c

fxtra.o: fxtra.r $(HDRS) ../h/posix.h fxposix.ri
	rtt fxtra.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c fxtra.c
	$(RM) fxtra.c

clean:		
	rm -f *.o *.c rt.db rt.a rttcur.lst rttfull.lst oix
