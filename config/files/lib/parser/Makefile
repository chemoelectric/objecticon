include ../../Makedefs

LIBSRC=ucode.icn lex.icn parser.icn tokens.icn tree.icn symboltable.icn oigram.icn evaluator.icn

LIBU=$(LIBSRC:.icn=.u)

all:  $(LIBU)

etags:
	etags $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) *.u ../incl/oigram_tab.icn oigram.icn packages.txt

$(LIBU): %.u: %.icn oigram.icn
	oit -ncs $(LIBSRC)

oigram.icn : oigram.y
	iyacc -v -k parser -d -i oigram.y
	mv oigram_tab.icn ../incl
