include ../../Makedefs

CWARN = -Wall

TRANS=		trans.o tcode.o tlex.o tparse.o tsym.o tmem.o \
		 tree.o ucode.o ipp.o

LINKR=		link.o lglob.o lcode.o lmem.o lsym.o lcompres.o

COBJS=		../common/long.o ../common/getopt.o ../common/alloc.o \
		   ../common/filepart.o ../common/strtbl.o ../common/mlocal.o

OBJS=		package.o resolve.o tmain.o util.o tlocal.o $(TRANS) $(LINKR) $(COBJS)

all:		oicont

clean:		
		rm -f *.o tgram.g y.tab.c y.tab.h y.output oicont mkkwd fixgram mktoktab

pure:		
		rm -f *.o tparse.c tgram.g ttoken.h y.tab.c y.tab.h yacctok.h \
			lextab.h y.output oicont mkkwd fixgram mktoktab

oicont:		$(OBJS)
		$(CC) $(CFLAGS) $(LDFLAGS) -o oicont $(OBJS) $(LIBS)
		cp oicont $(OIBIN)
		ln -f -s oicont $(OIBIN)/udis

$(OBJS):   ../h/define.h ../h/config.h ../h/cpuconf.h ../h/gsupport.h \
		   ../h/proto.h ../h/mproto.h \
		   ../h/typedefs.h ../h/cstructs.h

$(COBJS):	../h/mproto.h

tmain.o:	tree.h ../h/lexdef.h
util.o:		tree.h ../h/fdefs.h
package.o:	package.h
resolve.o:	link.h

# translator files
ipp.o:		../h/features.h
trans.o:	tsym.h ttoken.h tree.h ../h/version.h ../h/kdefs.h
tparse.o:	../h/lexdef.h tsym.h tree.h keyword.h
tcode.o:	tsym.h ttoken.h tree.h
tlex.o:		../h/lexdef.h ../h/parserr.h ttoken.h tree.h ../h/esctab.h  lextab.h
tmem.o:		tsym.h tree.h
tree.o:		tree.h
tsym.o:		tsym.h ttoken.h keyword.h ../h/kdefs.h
ucode.o:	tsym.h ttoken.h keyword.h ../h/kdefs.h
# linker files
$(LINKR):	link.h ../h/rt.h ../h/sys.h ../h/monitor.h \
		   ../h/rstructs.h ../h/rmacros.h ../h/rexterns.h

link.o:		../h/header.h
lcode.o:	keyword.h ../h/header.h \
			../h/opdefs.h ../h/version.h ../h/nativedefs.h
lglob.o:	../h/opdefs.h ../h/version.h
lmem.o:		
lsym.o:		
lcompres.o:	../h/header.h

# Compile with make GRAM=Y
ifeq ($(GRAM),Y)

mkkwd:		mkkwd.icn
		oicont -s mkkwd.icn

fixgram:	fixgram.icn
		oicont -s fixgram.icn

mktoktab:	mktoktab.icn
		oicont -s mktoktab.icn

lextab.h yacctok.h:	tokens.txt op.txt mktoktab
		./mktoktab

tparse.c ttoken.h:	tgram.g
# expect 218 shift/reduce conflicts
		yacc -v -d tgram.g
		cp y.tab.c tparse.c
		mv y.tab.h ttoken.h
		rm -f y.tab.c

tgram.g:	tgrammar.c ../h/define.h grammar.h yacctok.h fixgram
		$(CC) -E -C tgrammar.c | ./fixgram >tgram.g

../h/kdefs.h keyword.h:	../runtime/keyword.r mkkwd
		./mkkwd <../runtime/keyword.r
endif
