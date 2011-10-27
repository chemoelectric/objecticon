include ../Makedefs

PROGS=$(patsubst %.icn,%,$(wildcard *.icn))

all :	$(PROGS)

clean :
	$(RM) *.u packages.txt $(PROGS)

%: 	%.icn
	oit -s $<
