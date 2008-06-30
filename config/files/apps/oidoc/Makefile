include ../../Makedefs

SRCFILES=main.icn outputter.icn htmloutputter.icn groffoutputter.icn comment.icn
UFILES=$(SRCFILES:.icn=.u)

all:  oidoc

clean:
	$(RM) *.u packages.txt oidoc

%.u: %.icn
	oit -ncs $(SRCFILES)

oidoc: $(UFILES)
	oit -o oidoc $(UFILES)
	$(CP) oidoc $(OIBIN)
