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

XOBJS=	xcnv.o xdata.o xdef.o xerrmsg.o xextcall.o xfconv.o xfload.o xfmath.o\
	xfmisc.o xfmonitr.o xfscan.o xfstr.o xfstranl.o xfstruct.o xfsys.o\
	xfwindow.o ximain.o ximisc.o xinit.o xinterp.o xinvoke.o xfdb.o\
	xkeyword.o xlmisc.o xoarith.o xoasgn.o xocat.o xocomp.o xnative.o \
	xomisc.o xoref.o xoset.o xovalue.o xralc.o xrcoexpr.o xrcomp.o xrdb.o\
	xrdebug.o xrlocal.o xrlrgint.o xrmemmgt.o xrmisc.o xrstruct.o xrsys.o\
	xrwinrsc.o xrgfxsys.o xrwinsys.o xrwindow.o xfxtra.o xrposix.o

COBJS=	../common/long.o ../common/time.o ../common/save.o \
	../common/rswitch.o ../common/redirerr.o ../common/xwindow.o \
	../common/alloc.o ../common/mlocal.o

OBJS=	$(XOBJS) $(COBJS)

all:	oix

oix:	$(OBJS)
	$(CC) $(CFLAGS) -Wl,-E $(LDFLAGS) -o oix $(OBJS) $(LIBS)
	cp oix $(OIBIN)

xcnv.o: cnv.r $(HDRS)
	rtt cnv.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xcnv.c
	$(RM) xcnv.c

xdata.o: data.r $(HDRS) ../h/kdefs.h ../h/fdefs.h ../h/odefs.h
	rtt data.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xdata.c
	$(RM) xdata.c

xdef.o: def.r $(HDRS)
	rtt def.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xdef.c
	$(RM) xdef.c

xerrmsg.o: errmsg.r $(HDRS)
	rtt errmsg.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xerrmsg.c
	$(RM) xerrmsg.c

xextcall.o: extcall.r $(HDRS)
	rtt extcall.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xextcall.c
	$(RM) xextcall.c

xfconv.o: fconv.r $(HDRS)
	rtt fconv.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfconv.c
	$(RM) xfconv.c

xfdb.o: fdb.r $(HDRS)
	rtt fdb.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfdb.c
	$(RM) xfdb.c

xfload.o: fload.r $(HDRS)
	rtt fload.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfload.c
	$(RM) xfload.c

xfmath.o: fmath.r $(HDRS)
	rtt fmath.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfmath.c
	$(RM) xfmath.c

xfmisc.o: fmisc.r $(HDRS)
	rtt fmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfmisc.c
	$(RM) xfmisc.c

xfmonitr.o: fmonitr.r $(HDRS)
	rtt fmonitr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfmonitr.c
	$(RM) xfmonitr.c

xfscan.o: fscan.r $(HDRS)
	rtt fscan.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfscan.c
	$(RM) xfscan.c

xfstr.o: fstr.r $(HDRS)
	rtt fstr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfstr.c
	$(RM) xfstr.c

xfstranl.o: fstranl.r $(HDRS)
	rtt fstranl.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfstranl.c
	$(RM) xfstranl.c

xfstruct.o: fstruct.r $(HDRS)
	rtt fstruct.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfstruct.c
	$(RM) xfstruct.c

xfsys.o: fsys.r $(HDRS)
	rtt fsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfsys.c
	$(RM) xfsys.c

xfwindow.o: fwindow.r $(HDRS) $(GRAPHICSHDRS)
	rtt fwindow.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfwindow.c
	$(RM) xfwindow.c

ximain.o: imain.r $(HDRS) ../h/nativedefs.h
	rtt imain.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ximain.c
	$(RM) ximain.c

ximisc.o: imisc.r $(HDRS)
	rtt imisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c ximisc.c
	$(RM) ximisc.c

xnative.o: native.r $(HDRS)
	rtt native.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xnative.c
	$(RM) xnative.c

xinit.o: init.r $(HDRS) ../h/odefs.h ../h/version.h
	rtt init.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xinit.c
	$(RM) xinit.c

xinterp.o: interp.r $(HDRS)
	rtt interp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xinterp.c
	$(RM) xinterp.c

xinvoke.o: invoke.r $(HDRS)
	rtt invoke.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xinvoke.c
	$(RM) xinvoke.c

xkeyword.o: keyword.r $(HDRS) ../h/features.h ../h/version.h
	rtt keyword.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xkeyword.c
	$(RM) xkeyword.c

xlmisc.o: lmisc.r $(HDRS)
	rtt lmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xlmisc.c
	$(RM) xlmisc.c

xoarith.o: oarith.r $(HDRS)
	rtt oarith.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xoarith.c
	$(RM) xoarith.c

xoasgn.o: oasgn.r $(HDRS)
	rtt oasgn.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xoasgn.c
	$(RM) xoasgn.c

xocat.o: ocat.r $(HDRS)
	rtt ocat.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xocat.c
	$(RM) xocat.c

xocomp.o: ocomp.r $(HDRS)
	rtt ocomp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xocomp.c
	$(RM) xocomp.c

xomisc.o: omisc.r $(HDRS)
	rtt omisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xomisc.c
	$(RM) xomisc.c

xoref.o: oref.r $(HDRS)
	rtt oref.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xoref.c
	$(RM) xoref.c

xoset.o: oset.r $(HDRS)
	rtt oset.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xoset.c
	$(RM) xoset.c

xovalue.o: ovalue.r $(HDRS)
	rtt ovalue.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xovalue.c
	$(RM) xovalue.c

xralc.o: ralc.r $(HDRS)
	rtt ralc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xralc.c
	$(RM) xralc.c

xrcoexpr.o: rcoexpr.r $(HDRS)
	rtt rcoexpr.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrcoexpr.c
	$(RM) xrcoexpr.c

xrcomp.o: rcomp.r $(HDRS)
	rtt rcomp.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrcomp.c
	$(RM) xrcomp.c

xrdb.o: rdb.r $(HDRS)
	rtt rdb.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrdb.c
	$(RM) xrdb.c

xrdebug.o: rdebug.r $(HDRS)
	rtt rdebug.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrdebug.c
	$(RM) xrdebug.c

xrlocal.o: rlocal.r $(HDRS)
	rtt rlocal.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrlocal.c
	$(RM) xrlocal.c

xrlrgint.o: rlrgint.r $(HDRS)
	rtt rlrgint.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrlrgint.c
	$(RM) xrlrgint.c

xrmemmgt.o: rmemmgt.r $(HDRS)
	rtt rmemmgt.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrmemmgt.c
	$(RM) xrmemmgt.c

xrmisc.o: rmisc.r $(HDRS)
	rtt rmisc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrmisc.c
	$(RM) xrmisc.c

xrposix.o: rposix.r $(HDRS) ../h/posix.h
	rtt rposix.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrposix.c
	$(RM) xrposix.c

xrstruct.o: rstruct.r $(HDRS)
	rtt rstruct.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrstruct.c
	$(RM) xrstruct.c

xrsys.o: rsys.r $(HDRS)
	rtt rsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrsys.c
	$(RM) xrsys.c

xrwinrsc.o: rwinrsc.r $(HDRS) $(GRAPHICSHDRS) rxrsc.ri
	rtt rwinrsc.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrwinrsc.c
	$(RM) xrwinrsc.c

xrgfxsys.o: rgfxsys.r $(HDRS) $(GRAPHICSHDRS)
	rtt rgfxsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrgfxsys.c
	$(RM) xrgfxsys.c

xrwinsys.o: rwinsys.r $(HDRS) $(GRAPHICSHDRS) rxwin.ri
	rtt rwinsys.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrwinsys.c
	$(RM) xrwinsys.c

xrwindow.o: rwindow.r $(HDRS) $(GRAPHICSHDRS)
	rtt rwindow.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xrwindow.c
	$(RM) xrwindow.c

xfxtra.o: fxtra.r $(HDRS) ../h/posix.h fxposix.ri
	rtt fxtra.r
	$(CC) $(CPPFLAGS) $(CFLAGS) -c xfxtra.c
	$(RM) xfxtra.c

clean:		
	rm -f *.o *.c rt.db rt.a rttcur.lst rttfull.lst oix
