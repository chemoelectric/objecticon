include ../../Makedefs

LIBSRC=ucode.icn lex.icn parser.icn tokens.icn tree.icn symboltable.icn oigram.icn preprocessor.icn evaluator.icn

LIBU=$(LIBSRC:.icn=.u)

all:  $(LIBU)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) *.u oigram.icn packages.txt

$(LIBU): %.u: %.icn oigram.icn
	oit -ncs $(LIBSRC)

oigram.icn : oigram.y
	iyacc -v -k parser -f YY -i oigram.y
