include ../../Makedefs

.PHONY: all clean

SRCFILES=attlist.icn attributedef.icn canonicalxmlformatter.icn cdata.icn \
	comment.icn contentspec.icn xmlerrorhandler.icn defaultresolver.icn \
	doctype.icn document.icn element.icn elementdecl.icn entitydef.icn \
	externalid.icn formatter.icn globalname.icn htmldocument.icn \
	htmlelement.icn htmlformatter.icn htmlparser.icn node.icn notationdecl.icn \
	processinginstruction.icn resolver.icn xmldecl.icn xmldocument.icn \
	xmlelement.icn xmlformatter.icn xmlparser.icn webscraper.icn

UFILES=$(SRCFILES:.icn=.u)

PROGS=testhtml testxml testpatterns testvalid testwf \
	testnotwf testinvalid globaldemo createdemo

all: $(UFILES) $(PROGS)
#all: $(UFILES) testxml

clean:
	$(RM) $(PROGS) *.u packages.txt

%.u: %.icn
	oicont -s -n -c $(SRCFILES)

%: %.icn
	oicont -s -o $@ $<
