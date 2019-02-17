include ../../Makedefs

.NOTPARALLEL:

LIBSRC=ucode.icn lex.icn parser.icn tree.icn symboltable.icn oigram.icn preprocessor.icn evaluator.icn

LIBU=$(LIBSRC:.icn=.u)

all:  $(LIBU)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) *.u oigram.icn packages.txt

$(LIBU): %.u: %.icn oigram.icn
	oit -ncsW $(LIBSRC)

oigram.icn : oigram.y
	iyacc -k parser oigram.y
