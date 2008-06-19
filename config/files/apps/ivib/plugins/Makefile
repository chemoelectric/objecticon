include ../../../Makedefs

export OIPATH:=$(OIPATH) $(OIHOME)/apps/ivib

SRCFILES:=$(wildcard *.icn)
UFILES=$(SRCFILES:.icn=.u)
PROGS=$(SRCFILES:.icn=)

.PHONY: all clean
.PRECIOUS:      %.u

all:    $(PROGS)

clean:
	rm -f *.u packages.txt $(UFILES) $(PROGS)

%.u:    %.icn
	oicont -nsc $(SRCFILES)

%:      %.u $(UFILES)
	oicont -o $@ $@.u $(UFILES)
