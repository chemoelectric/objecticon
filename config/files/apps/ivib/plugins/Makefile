include ../../../Makedefs

export OIPATH:=$(OIPATH) $(OIHOME)/apps/ivib

PROGSRC:=$(wildcard *.icn)
PROGU=$(PROGSRC:.icn=.u)
PROGS=$(PROGSRC:.icn=)

all:    $(PROGS)

clean:
	rm -f *.u packages.txt $(PROGS)

$(PROGU): %.u: %.icn
	oit -snc $(PROGSRC)

%:      %.u
	oit -o $@ $@.u
