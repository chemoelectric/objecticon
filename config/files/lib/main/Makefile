include ../../Makedefs

.NOTPARALLEL:

LIBSRC=$(wildcard *.icn)
AUTOSRC=posixconsts.icn ioconsts.icn evmonconsts.icn ucodeconsts.icn

LIBU=$(LIBSRC:.icn=.u)
AUTOU=$(AUTOSRC:.icn=.u)

all: mkconsts $(LIBU) $(AUTOU)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) mkconsts mkconsts.o $(AUTOSRC) *.u packages.txt

$(AUTOSRC): 	mkconsts
	./mkconsts

mkconsts:	mkconsts.o
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ mkconsts.o ../../base/common/mlocal.o ../../base/common/alloc.o $(LIBS)

$(LIBU): %.u: %.icn
	oit -sncW $(LIBSRC)
