include ../Makedefs

PROGS=  ieval fiximports
PROGSRC=$(PROGS:=.icn)

all :	$(PROGS)
	$(MAKE) -C ivib all
	$(MAKE) -C oidoc all

clean :
	$(RM) *.u packages.txt $(PROGS)
	$(MAKE) -C ivib clean
	$(MAKE) -C oidoc clean

etags :
	$(ETAGS) $(ICNTAGS) $(PROGSRC)
	$(MAKE) -C ivib etags
	$(MAKE) -C oidoc etags

%: 	%.icn
	oit -s $<
	cp $@ "$(OI_BIN)"
