include ../../Makedefs

OITOBJS=	trans.o tlex.o tparse.o tsym.o tmem.o \
		tree.o ucode.o ipp.o membuff.o ir.o \
		package.o resolve.o tmain.o \
		link.o lglob.o lcode.o lmem.o lsym.o ltree.o optimize.o

COBJS=		../common/getopt.o ../common/alloc.o \
		../common/strtbl.o ../common/mlocal.o

OBJS=		$(OITOBJS) $(COBJS)

OITC=$(OITOBJS:.o=.c)

all:		oit

clean:		
		rm -f *.o tgram.g y.tab.c y.tab.h y.output oit mkkwd fixgram mktoktab

etags:
		$(ETAGS) $(OITC) tgrammar.c *.h

oit:		$(OBJS)
		$(CC) $(CFLAGS) $(LDFLAGS) -o oit $(OBJS) $(LIBS)
		$(INSTALL) oit "$(OI_BIN)"
		(cd "$(OI_BIN)" && $(RM) udis && $(LN_S) oit udis)

$(OBJS):   ../h/define.h ../h/config.h ../h/cpuconf.h ../h/gsupport.h \
		   ../h/mproto.h ../h/typedefs.h ../h/cstructs.h

$(COBJS):	../h/mproto.h

tmain.o:	tree.h lexdef.h
package.o:	package.h
resolve.o:	link.h

# translator files
ipp.o:		../h/features.h
trans.o:	tsym.h ttoken.h tree.h ../h/version.h ../h/kdefs.h
tparse.o:	lexdef.h tsym.h tree.h keyword.h
tlex.o:		lexdef.h ttoken.h tree.h  lextab.h
tmem.o:		tsym.h tree.h
tree.o:		tree.h
tsym.o:		tsym.h ttoken.h keyword.h ../h/kdefs.h
ucode.o:	tsym.h ttoken.h keyword.h ../h/kdefs.h
link.o:		../h/header.h
lcode.o:	keyword.h ../h/header.h \
			../h/opdefs.h ../h/version.h ../h/nativedefs.h
lglob.o:	../h/opdefs.h ../h/version.h
lmem.o:		
lsym.o:		

# Compile with make GRAM=Y
ifeq ($(GRAM),Y)

mkkwd:		mkkwd.icn
		oit -s mkkwd.icn

fixgram:	fixgram.icn
		oit -s fixgram.icn

mktoktab:	mktoktab.icn
		oit -s mktoktab.icn

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

../h/kdefs.h keyword.h:	../oix/keyword.r mkkwd
		./mkkwd <../oix/keyword.r
endif
