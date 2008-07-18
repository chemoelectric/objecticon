include Makedefs

all :
	make -C base all
	make -C lib all
	make -C apps all
	make -C docs all

clean :
	make -C base clean
	make -C lib clean
	make -C apps clean
	make -C docs clean

PACKAGE_NAME=@PACKAGE_NAME@
PACKAGE_TARNAME=@PACKAGE_TARNAME@
PACKAGE_VERSION=@PACKAGE_VERSION@
PACKAGE_STRING=@PACKAGE_STRING@
PACKAGE_BUGREPORT=@PACKAGE_BUGREPORT@
prefix=@prefix@
exec_prefix=@exec_prefix@
datarootdir=@datarootdir@
docdir=@docdir@
infodir=@infodir@
OIBIN=@bindir@
OILIB=@libdir@/@PACKAGE_TARNAME@
SOLIB=@libdir@
HTMLINFO=@htmldir@/@PACKAGE_TARNAME@-htmlinfo
INFO=@infodir@
LIBREF=@htmldir@/@PACKAGE_TARNAME@-libref
PATHS=$(OILIB)/paths.sh
MKDEFS=$(OILIB)/Makedefs
UNINST=$(OILIB)/uninstall.sh

install :
	$(INSTALL) -d $(OIBIN)
	$(INSTALL) -d $(OILIB)/gui
	$(INSTALL) -d $(OILIB)/incl
	$(INSTALL) -d $(OILIB)/ipl
	$(INSTALL) -d $(OILIB)/main
	$(INSTALL) -d $(OILIB)/parser
	$(INSTALL) -d $(OILIB)/xml
	$(INSTALL) -d $(HTMLINFO)
	$(INSTALL) -d $(INFO)
	$(INSTALL) -m 755 bin/ivib $(OIBIN)
	$(INSTALL) -m 755 bin/iyacc $(OIBIN)
	$(INSTALL) -m 755 bin/oit $(OIBIN)
	$(INSTALL) -m 755 bin/oix $(OIBIN)
	(cd $(OIBIN) && $(RM) udis && $(LN_S) oit udis)
	$(INSTALL) -m 644 lib/gui/*.u lib/gui/packages.txt $(OILIB)/gui
	$(INSTALL) -m 644 lib/incl/*.icn $(OILIB)/incl
	$(INSTALL) -m 644 lib/ipl/*.u lib/ipl/packages.txt $(OILIB)/ipl
	$(INSTALL) -m 644 lib/main/*.u lib/main/packages.txt $(OILIB)/main
	$(INSTALL) -m 755 lib/native/*.so $(SOLIB)
	$(INSTALL) -m 644 lib/parser/*.u lib/parser/packages.txt $(OILIB)/parser
	$(INSTALL) -m 644 lib/xml/*.u lib/xml/packages.txt $(OILIB)/xml
ifeq (@MAKEINFO@,yes)
	$(INSTALL) -m 644 docs/htmlinfo/*.html $(HTMLINFO)
	$(INSTALL) -m 644 docs/objecticon.info $(INFO)
ifeq (@INSTALLINFO@,yes)
	install-info docs/objecticon.info $(INFO)/dir
endif
endif
	@echo -e "# Object Icon path settings" >$(PATHS)
	@echo -e "export OIHOME=\"$(prefix)\"" >>$(PATHS)
	@echo -e "export OIBIN=\"$(OIBIN)\"" >>$(PATHS)
	@echo -e "export OILIB=\"$(OILIB)\"" >>$(PATHS)
	@echo -e "# Object Icon Makedefs" >$(MKDEFS)
	@echo -e "OIHOME=$(prefix)" >>$(MKDEFS)
	@echo -e "OIBIN=$(OIBIN)" >>$(MKDEFS)
	@echo -e "OILIB=$(OILIB)" >>$(MKDEFS)
	@echo -e "export OIPATH:=\$$(OILIB)/main:\$$(OILIB)/gui:\$$(OILIB)/xml:\$$(OILIB)/parser:\$$(OILIB)/ipl" >>$(MKDEFS)
	@echo -e "export OLPATH:=\$$(OILIB)/incl" >>$(MKDEFS)
	@echo -e "export PATH:=\$$(OIBIN):\$$(PATH)" >>$(MKDEFS)
	@echo -e "\n%.u: %.icn\n\toit -c -s \$$<" >>$(MKDEFS)
	@echo -e "export OIPATH=\"\$$OILIB/main:\$$OILIB/gui:\$$OILIB/xml:\$$OILIB/parser:\$$OILIB/ipl\"" >>$(PATHS)
	@echo -e "export OLPATH=\"\$$OILIB/incl\"" >>$(PATHS)
	@if [ $(prefix) != /usr/local ] ; then \
		echo -e "PATH=\"\$$PATH:\$$OIBIN\"" >>$(PATHS) ; \
	fi
	@echo -e "export TRACE" >>$(PATHS) ; \

	@echo -e rm -f $(OIBIN)/ivib $(OIBIN)/iyacc $(OIBIN)/oit $(OIBIN)/oix $(OIBIN)/udis >$(UNINST)
	@echo -e rm -f $(SOLIB)/objecticonipclib.so  $(SOLIB)/objecticonmysqllib.so >>$(UNINST)
	@echo -e rm -rf $(OILIB) >>$(UNINST)
	@echo -e rm -rf $(HTMLINFO) >>$(UNINST)
	@echo -e rm -f $(INFO)/objecticon.info >>$(UNINST)
	@echo -e rm -rf $(LIBREF) >>$(UNINST)
ifeq (@INSTALLINFO@,yes)
	@echo -e install-info --delete objecticon $(INFO)/dir >>$(UNINST)
endif

	@echo -e "\nInstallation complete.  Some helpful files :-"
	@echo "   $(PATHS) - environment variables"
	@echo "   $(MKDEFS) - useful Makefile definitions"
	@echo "   $(UNINST) - uninstallation script"

install-libref :
	$(INSTALL) -d $(LIBREF)
	oidoc -html -d -o $(LIBREF) -a

T=$(PACKAGE_TARNAME)-$(PACKAGE_VERSION)
tar :
	@rm -rf $(T)
	@mkdir -p $(T)
	@for f in $$( find apps base docs lib \
		-regex ".*\.\(icn\|c\|r\|ri\|h\|y\|icon\|texi\)" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@for f in $$( find config -type f -not -regex ".*\.svn.*" ) ; do \
		cp --parents $$f $(T) ;\
	done
	@cp configure config.guess config.sub install-sh $(T)
	@rm -f $(T)/base/h/auto.h $(T)/base/h/version.h $(T)/base/h/define.h \
		$(T)/base/common/rswitch.?
	tar cfz $(T).tar.gz $(T)
	@rm -rf $(T)
