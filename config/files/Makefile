include Makedefs

.PHONY:	libref test bmark tar

all :	bin/oiscript
	$(MAKE) -C base all
	$(MAKE) -C lib all
	$(MAKE) -C apps all
	$(MAKE) -C examples all

clean :
	$(MAKE) -C base clean
	$(MAKE) -C lib clean
	$(MAKE) -C apps clean
	$(MAKE) -C examples clean
	-$(RM) bin/*

etags :
	rm -f TAGS
	$(MAKE) -C base etags
	$(MAKE) -C lib etags
	$(MAKE) -C apps etags

test :
	cd test && ./runtest.sh

testipllink :
	cd test && ./testipllink.sh

bmark :
	cd bmark && ./runbmark.sh

bin/oiscript :	config/files/bin/oiscript
	cp config/files/bin/oiscript bin
	chmod +x bin/oiscript

PACKAGE_NAME=@PACKAGE_NAME@
PACKAGE_TARNAME=@PACKAGE_TARNAME@
PACKAGE_VERSION=@PACKAGE_VERSION@
PACKAGE_STRING=@PACKAGE_STRING@
PACKAGE_BUGREPORT=@PACKAGE_BUGREPORT@

libref :
	rm -rf libref
	mkdir libref
	oidoc -d -o libref -a

T=$(PACKAGE_TARNAME)-$(PACKAGE_VERSION)
tar :
	@rm -rf $(T)
	@mkdir -p $(T)
	@for f in $$( find apps base lib \
		-regex ".*\.\(icn\|c\|cpp\|r\|ri\|h\|y\|gif\|png\|svg\|svgz\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find test \
		-regex ".*\.\(icn\|std\|stde\|dat\|gif\|sh\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find examples \
		-regex ".*\.\(icn\|layout\|gif\|jpg\|png\|svg\|svgz\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find misc -type f ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find bmark \
		-regex ".*\.\(icn\|dat\|sh\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find config -type f ) ; do \
		cp --parents $$f $(T) ;\
	done
	@echo $(PACKAGE_VERSION) >$(T)/tar-version
	@cp README configure-win32 configure config.guess config.sub install-sh $(T)
	@rm -rf $(T)/base/h/auto.h $(T)/base/h/version.h $(T)/base/h/define.h \
		$(T)/lib/main/posixconsts.icn \
		$(T)/lib/main/ioconsts.icn \
		$(T)/lib/main/evmonconsts.icn \
		$(T)/lib/main/ucodeconsts.icn \
		$(T)/lib/incl/oigram_tab.icn \
		$(T)/lib/parser/oigram.icn \
		$(T)/lib/xml/xmlconf
	tar cfz $(T).tar.gz $(T)
	@rm -rf $(T)
