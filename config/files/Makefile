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
HTML=@htmldir@
INFO=@infodir@
LIBREF=@htmldir@/libref
PATHS=$(OILIB)/paths.txt
MKDEFS=$(OILIB)/Makedefs

install :
	install -d $(OIBIN)
	install -d $(OILIB)/gui
	install -d $(OILIB)/incl
	install -d $(OILIB)/ipl
	install -d $(OILIB)/main
	install -d $(OILIB)/parser
	install -d $(OILIB)/xml
	install -d $(HTML)
	install -d $(INFO)
	install -m 755 bin/ivib $(OIBIN)
	install -m 755 bin/iyacc $(OIBIN)
	install -m 755 bin/oit $(OIBIN)
	install -m 755 bin/oix $(OIBIN)
	ln -f -s oit $(OIBIN)/udis
	install -m 644 lib/gui/*.u lib/gui/packages.txt $(OILIB)/gui
	install -m 644 lib/incl/*.icn $(OILIB)/incl
	install -m 644 lib/ipl/*.u $(OILIB)/ipl
	install -m 644 lib/main/*.u lib/main/packages.txt $(OILIB)/main
	install -m 755 lib/native/*.so $(SOLIB)
	install -m 644 lib/parser/*.u lib/parser/packages.txt $(OILIB)/parser
	install -m 644 lib/xml/*.u lib/xml/packages.txt $(OILIB)/xml
	install -m 644 docs/html/*.html $(HTML)
	install -m 644 docs/objecticon.info $(INFO)
	/sbin/install-info docs/objecticon.info $(INFO)/dir
	@echo -e "# Object Icon path settings" >$(PATHS)
	@echo -e "export OIHOME=$(prefix)" >>$(PATHS)
	@echo -e "export OIBIN=$(OIBIN)" >>$(PATHS)
	@echo -e "export OILIB=$(OILIB)" >>$(PATHS)
	@echo -e "# Object Icon Makedefs" >$(MKDEFS)
	@echo -e "OIHOME=$(prefix)" >>$(MKDEFS)
	@echo -e "OIBIN=$(OIBIN)" >>$(MKDEFS)
	@echo -e "OILIB=$(OILIB)" >>$(MKDEFS)
	@echo -e "export OIPATH:=\$$(OILIB)/main \$$(OILIB)/gui\
                  \$$(OILIB)/xml \$$(OILIB)/parser \$$(OILIB)/ipl" >>$(MKDEFS)
	@echo -e "export OLPATH:=\$$(OILIB)/incl" >>$(MKDEFS)
	@echo -e "export PATH:=\$$(OIBIN):\$$(PATH)" >>$(MKDEFS)
	@echo -e "export OIPATH=\"\$$OILIB/main \$$OILIB/gui\
                  \$$OILIB/xml \$$OILIB/parser \$$OILIB/ipl\"" >>$(PATHS)
	@echo -e "export OLPATH=\"\$$OILIB/incl\"" >>$(PATHS)
	@if [ $(prefix) != /usr/local ] ; then \
		echo -e "PATH=\"\$$PATH:\$$OIBIN\"" >>$(PATHS) ; \
		echo -e "# This last one is only needed if you intend to\
                            use the mysql or ipc packages" >>$(PATHS) ; \
		echo -e "LD_LIBRARY_PATH=\"\$$LD_LIBRARY_PATH:$(SOLIB)\"" >>$(PATHS) ; \
	fi
	@echo "Installation complete.  Some helpful files :-"
	@echo "   $(PATHS) - environment variables"
	@echo "   $(MKDEFS) - useful Makefile definitions"

install-libref :
	install -d $(LIBREF)
	oidoc -html -d -o $(LIBREF) -a $(OILIB)/ipl/*.icn

uninstall :
	rm -f $(OIBIN)/ivib $(OIBIN)/iyacc $(OIBIN)/oit $(OIBIN)/oix \
		$(OIBIN)/udis
	rm -f $(SOLIB)/objecticonipclib.so  $(SOLIB)/objecticonmysqllib.so
	rm -rf $(OILIB)
	rm -f $(HTML)/*.html
	rm -f $(INFO)/objecticon.info
	rm -rf $(LIBREF)
	/sbin/install-info --delete objecticon $(INFO)/dir
	rm -f $(PATHS) $(MKDEFS)
