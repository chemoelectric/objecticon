include ../../Makedefs

.NOTPARALLEL:

LIBSRC=$(wildcard *.icn)

LIBU=$(LIBSRC:.icn=.u)

all: $(LIBU)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) *.u packages.txt

$(LIBU): %.u: %.icn
	oit -sncW $(LIBSRC)

