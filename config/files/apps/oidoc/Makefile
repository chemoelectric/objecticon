include ../../Makedefs

.NOTPARALLEL:

COMMONSRC=outputter.icn htmloutputter.icn groffoutputter.icn comment.icn
COMMONU=$(COMMONSRC:.icn=.u)

PROGS=oidoc
PROGSRC=$(PROGS:=.icn)
PROGU=$(PROGSRC:.icn=.u)

all:	$(PROGS)

etags:
	$(ETAGS) $(ICNTAGS) $(COMMONSRC) $(PROGSRC)

clean:
	$(RM) *.u packages.txt $(PROGS)

$(COMMONU) $(PROGU): %.u: %.icn
	oit -snc $(COMMONSRC) $(PROGSRC)

%:      %.u $(COMMONU)
	oit -o $@ $@.u $(COMMONU)
	cp $@ "$(OI_BIN)"
