include ../../Makedefs

LIBSRC=$(wildcard *.icn)

LIBU=$(LIBSRC:.icn=.u)

all: mkposixconsts $(LIBU) posixconsts.u

clean:
	$(RM) mkposixconsts posixconsts.icn *.u packages.txt

posixconsts.icn: 	mkposixconsts
	./mkposixconsts >posixconsts.icn

$(LIBU): %.u: %.icn
	oit -snc $(LIBSRC)
