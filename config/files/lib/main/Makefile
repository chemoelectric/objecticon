include ../../Makedefs

LIBSRC=$(wildcard *.icn)
AUTOSRC=posixconsts.icn ioconsts.icn evmonconsts.icn ucodeconsts.icn

LIBU=$(LIBSRC:.icn=.u)
AUTOU=$(AUTOSRC:.icn=.u)

all: mkconsts $(LIBU) $(AUTOU)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) mkconsts $(AUTOSRC) *.u packages.txt

$(AUTOSRC): 	mkconsts
	./mkconsts

$(LIBU): %.u: %.icn
	oit -snc $(LIBSRC)
