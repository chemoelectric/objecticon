include ../../Makedefs

LIBSRC=$(wildcard *.icn)

LIBU=$(LIBSRC:.icn=.u)

all: mkconsts $(LIBU) ioconsts.u posixconsts.u

clean:
	$(RM) mkconsts posixconsts.icn ioconsts.icn *.u packages.txt

ioconsts.icn posixconsts.icn: 	mkconsts
	./mkconsts

$(LIBU): %.u: %.icn
	oit -snc $(LIBSRC)
