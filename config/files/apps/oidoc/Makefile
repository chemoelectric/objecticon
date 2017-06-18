include ../../Makedefs

.NOTPARALLEL:

SRC=oidoc.icn outputter.icn htmloutputter.icn groffoutputter.icn
UFILES=$(SRC:.icn=.u)
PROG=../../bin/oidoc

all:	$(PROG)

etags:
	$(ETAGS) $(ICNTAGS) $(SRC)

clean:
	$(RM) *.u packages.txt $(PROG)

%.u: %.icn
	oit -snc $(SRC)

$(PROG):	$(UFILES)
	oit -o $@ $(UFILES)
