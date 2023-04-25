include ../Makedefs

PROGS=  ieval fiximports memdebug memorytracker oipatch
SRC=$(PROGS:=.icn)
BIN=$(addprefix ../bin/, $(PROGS))

all :	$(BIN)
	$(MAKE) -C ivib all
	$(MAKE) -C oidoc all

clean :
	$(RM) *.u packages.txt $(BIN)
	$(MAKE) -C ivib clean
	$(MAKE) -C oidoc clean

etags :
	$(ETAGS) $(ICNTAGS) $(SRC)
	$(MAKE) -C ivib etags
	$(MAKE) -C oidoc etags

../bin/%: 	%.icn
	oit -sW -o $@ $<
