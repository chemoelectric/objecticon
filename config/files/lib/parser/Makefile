include ../../Makedefs

SRCFILES=lex.icn parser.icn utils.icn tokens.icn tree.icn symboltable.icn

UFILES=$(SRCFILES:.icn=.u) oigram.u

.PHONY: all clean

all:  oigram.icn $(UFILES)

clean:
	$(RM) *.u ../incl/oigram_tab.icn oigram.icn packages.txt

%.u: %.icn
	oicont -ncs $(SRCFILES) oigram.icn

oigram.icn : oigram.y
	iyacc -v -k parser -d -i oigram.y
	mv oigram_tab.icn ../incl
