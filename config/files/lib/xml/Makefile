include ../../Makedefs

.NOTPARALLEL:

LIBSRC=attlist.icn attributedef.icn canonicalxmlformatter.icn cdata.icn \
	comment.icn contentspec.icn xmlerrorhandler.icn defaultresolver.icn \
	doctype.icn document.icn element.icn elementdecl.icn entitydef.icn \
	externalid.icn formatter.icn globalname.icn htmldocument.icn \
	htmlelement.icn htmlformatter.icn htmlparser.icn node.icn notationdecl.icn \
	processinginstruction.icn resolver.icn xmldecl.icn xmldocument.icn \
	xmlelement.icn xmlformatter.icn xmlparser.icn

LIBU=$(LIBSRC:.icn=.u)

PROGS=testhtml testxml testpatterns testvalid testwf \
	testnotwf testinvalid globaldemo createdemo
PROGSRC=$(PROGS:=.icn)
PROGU=$(PROGSRC:.icn=.u)

all: $(LIBU) $(PROGS)

etags:
	$(ETAGS) $(ICNTAGS) $(LIBSRC)

clean:
	$(RM) $(PROGS) *.u packages.txt

$(LIBU): %.u: %.icn
	oit -snc $(LIBSRC)

%: 	%.icn
	oit -s $<

%: %.u $(LIBU)
	oit -so $@ $@.u
