include Makedefs

.PHONY:	libref test bmark tar install install-libref

all :
	$(MAKE) -C base all
	$(MAKE) -C lib all
	$(MAKE) -C apps all
	$(MAKE) -C examples all

clean :
	$(MAKE) -C base clean
	$(MAKE) -C lib clean
	$(MAKE) -C apps clean
	$(MAKE) -C examples clean

etags :
	rm -f TAGS
	$(MAKE) -C base etags
	$(MAKE) -C lib etags
	$(MAKE) -C apps etags

test :
	$(MAKE) -C test all

bmark :
	$(MAKE) -C bmark all

PACKAGE_NAME=@PACKAGE_NAME@
PACKAGE_TARNAME=@PACKAGE_TARNAME@
PACKAGE_VERSION=@PACKAGE_VERSION@
PACKAGE_STRING=@PACKAGE_STRING@
PACKAGE_BUGREPORT=@PACKAGE_BUGREPORT@
prefix=@prefix@
exec_prefix=@exec_prefix@
datarootdir=@datarootdir@
docdir=@docdir@
OIBIN=@bindir@
OILIB=@libdir@/@PACKAGE_TARNAME@-@PACKAGE_VERSION@
LIBREF=@htmldir@/@PACKAGE_TARNAME@-libref-@PACKAGE_VERSION@
PATHS=$(OILIB)/paths.sh
MKDEFS=$(OILIB)/Makedefs
UNINST=$(OILIB)/uninstall.sh

install :
	$(INSTALL) -d "$(OIBIN)"
	$(INSTALL) -d "$(OILIB)/gui"
	$(INSTALL) -d "$(OILIB)/incl"
	$(INSTALL) -d "$(OILIB)/ipl"
	$(INSTALL) -d "$(OILIB)/main"
	$(INSTALL) -d "$(OILIB)/native"
	$(INSTALL) -d "$(OILIB)/parser"
	$(INSTALL) -d "$(OILIB)/xml"
	$(INSTALL) -d "$(OILIB)/h"
	$(INSTALL) -d "$(OILIB)/ivib_plugins"
	$(INSTALL) -m 755 bin/ivib "$(OIBIN)"
	$(INSTALL) -m 755 bin/ieval "$(OIBIN)"
	$(INSTALL) -m 755 bin/fiximports "$(OIBIN)"
	$(INSTALL) -m 755 bin/oidoc "$(OIBIN)"
	$(INSTALL) -m 755 bin/iyacc "$(OIBIN)"
	$(INSTALL) -m 755 bin/oit "$(OIBIN)"
	$(INSTALL) -m 755 bin/oix "$(OIBIN)"
	$(INSTALL) -m 755 bin/rtt "$(OIBIN)"
	$(INSTALL) -m 755 bin/oiscript "$(OIBIN)"
	(cd "$(OIBIN)" && $(RM) udis && $(LN_S) oit udis)
	$(INSTALL) -m 644 lib/gui/*.u lib/gui/packages.txt "$(OILIB)/gui"
	$(INSTALL) -m 644 lib/incl/*.icn "$(OILIB)/incl"
	$(INSTALL) -m 644 lib/ipl/*.u lib/ipl/packages.txt "$(OILIB)/ipl"
	$(INSTALL) -m 644 lib/main/*.u lib/main/packages.txt "$(OILIB)/main"
	if test -n "$$(find lib/native -name '*.so')" ; then \
		$(INSTALL) -m 755 lib/native/*.so "$(OILIB)/native" ; \
	fi
	$(INSTALL) -m 644 lib/parser/*.u lib/parser/packages.txt "$(OILIB)/parser"
	$(INSTALL) -m 644 lib/xml/*.u lib/xml/packages.txt "$(OILIB)/xml"
	$(INSTALL) -m 755 apps/ivib/plugins/okcancelplugin "$(OILIB)/ivib_plugins"
	$(INSTALL) -m 644 base/h/*.h "$(OILIB)/h"
	@echo "# Object Icon path settings" >"$(PATHS)"
	@echo "export OIHOME=\"$(prefix)\"" >>"$(PATHS)"
	@echo "export OIBIN=\"$(OIBIN)\"" >>"$(PATHS)"
	@echo "export OILIB=\"$(OILIB)\"" >>"$(PATHS)"
	@echo "# Object Icon Makedefs" >"$(MKDEFS)"
	@echo "OIHOME=$(prefix)" >>"$(MKDEFS)"
	@echo "OIBIN=$(OIBIN)" >>"$(MKDEFS)"
	@echo "OILIB=$(OILIB)" >>"$(MKDEFS)"
	@echo "LDFLAGS=$(LDFLAGS)" >>"$(MKDEFS)"
	@echo "LIBS=$(LIBS)" >>"$(MKDEFS)"
	@echo "CFLAGS=$(CFLAGS)" >>"$(MKDEFS)"
	@echo "CPPFLAGS=$(CPPFLAGS)" >>"$(MKDEFS)"
	@echo "RTT=rtt -r \"\$$(OILIB)/h/\"" >>"$(MKDEFS)"
	@echo "export OIPATH:=\$$(OILIB)/main:\$$(OILIB)/gui:\$$(OILIB)/xml:\$$(OILIB)/parser:\$$(OILIB)/ipl" >>"$(MKDEFS)"
	@echo "export OIINCL:=\$$(OILIB)/incl" >>"$(MKDEFS)"
	@echo "export PATH:=\$$(OIBIN):\$$(PATH)" >>"$(MKDEFS)"
	@echo
	@echo "%.u: %.icn" >>"$(MKDEFS)"
	@echo "	oit -c -s \$$<" >>"$(MKDEFS)"
	@echo "export OIPATH=\"\$$OILIB/main:\$$OILIB/gui:\$$OILIB/xml:\$$OILIB/parser:\$$OILIB/ipl\"" >>"$(PATHS)"
	@echo "export OIINCL=\"\$$OILIB/incl\"" >>"$(PATHS)"
	@if [ "$(prefix)" != /usr/local ] ; then \
		echo "PATH=\"\$$PATH:\$$OIBIN\"" >>"$(PATHS)" ; \
	fi
	@echo "export OINATIVE=\"$(OILIB)/native\"" >>"$(PATHS)"
	@echo "export TRACE OIMAXLEVEL" >>"$(PATHS)" ; \

	@echo rm -f \"$(OIBIN)/ivib\" \"$(OIBIN)/ieval\" \"$(OIBIN)/fiximports\" \"$(OIBIN)/oidoc\" \"$(OIBIN)/iyacc\" \"$(OIBIN)/oit\" \"$(OIBIN)/oix\" \"$(OIBIN)/udis\" \"$(OIBIN)/rtt\" \"$(OIBIN)/oiscript\" >"$(UNINST)"
	@echo rm -rf \"$(OILIB)\" >>"$(UNINST)"
	@echo rm -rf \"$(LIBREF)\" >>"$(UNINST)"

	@echo
	@echo "Installation complete.  Some helpful files :-"
	@echo "   $(PATHS) - environment variables"
	@echo "   $(MKDEFS) - useful Makefile definitions"
	@echo "   $(UNINST) - uninstallation script"

install-libref :
	$(INSTALL) -d "$(LIBREF)"
	oidoc -html -d -o "$(LIBREF)" -a
	@echo
	@echo "Installation complete to file://$(LIBREF)/index.html"

libref :
	rm -rf libref
	mkdir libref
	oidoc -html -d -o libref -a

T=$(PACKAGE_TARNAME)-$(PACKAGE_VERSION)
tar :
	@rm -rf $(T)
	@mkdir -p $(T)
	@for f in $$( find apps base lib \
		-regex ".*\.\(icn\|c\|r\|ri\|h\|y\|gif\|png\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find riox \
		-regex "riox/mkfile\|.*\.\(c\|h\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find base/oix/p9cursors -type f -not -regex ".*\.svn.*" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find test \
		-regex ".*\.\(icn\|std\|p9\|stde\|dat\|gif\|sh\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find examples \
		-regex ".*\.\(icn\|layout\|gif\|jpg\|png\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find misc -type f -not -regex ".*\.svn.*" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find bmark \
		-regex ".*\.\(icn\|dat\|sh\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find config -type f -not -regex ".*\.svn.*" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@cp README configure configure.rc config.guess config.sub install-sh $(T)
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
