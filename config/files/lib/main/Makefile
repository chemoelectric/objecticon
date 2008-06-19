SRCFILES=$(wildcard *.icn)

UFILES=$(SRCFILES:.icn=.u)

all: $(UFILES)

clean:
	rm -f *.u packages.txt

%.u: %.icn
	oicont -s -n -c $(SRCFILES)

