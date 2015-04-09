include ../../Makedefs

LIBSRC=$(wildcard *.icn)

LIBU=$(LIBSRC:.icn=.u)

all: $(LIBU)

clean:
	$(RM) *.u packages.txt

$(LIBU): %.u: %.icn
	oit -snc $(LIBSRC)

