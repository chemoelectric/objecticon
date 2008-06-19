include ../../Makedefs

SRCFILES=main.icn outputter.icn htmloutputter.icn groffoutputter.icn comment.icn
UFILES=$(SRCFILES:.icn=.u)
DOCS=/home/rparlett/oidocs

.PHONY: all clean

all:  oidoc

clean:
	$(RM) *.u packages.txt oidoc

%.u: %.icn
	oicont -ncs $(SRCFILES)

oidoc: $(UFILES)
	oicont -o oidoc $(UFILES)
	$(CP) oidoc $(OIBIN)

docs:
	rm -rf $(DOCS)
	mkdir $(DOCS)
	./oidoc -html -d -o $(DOCS) -a $(OILIB)/ipl/*.icn
