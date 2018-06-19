include ../../../Makedefs

export OI_PATH:=$(OI_PATH):$(OI_HOME)/apps/ivib

PROGSRC:=$(wildcard *.icn)
PROGU=$(PROGSRC:.icn=.u)
PROGS=$(PROGSRC:.icn=)

all:    $(PROGS)

clean:
	rm -f *.u packages.txt $(PROGS)

$(PROGU): %.u: %.icn
	oit -snc $(PROGSRC)

%:      %.u
	oit -s -b2 -o $@ $@.u
