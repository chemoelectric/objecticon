include ../Makedefs

PROGS=browser canvasstate colors cursors directorydialogtest \
	dndtest dyncomps editor explorer filedialogtest \
	fonttest geturl grabtest imageview lslinks \
	multi selection sieve sizetest \
	sliders stock suggest tooltip treetest \
	ttexplorer fields flowterm bus lscookies \
	showtemplate cairotest lsxdg fl note

BIN=$(addprefix bin/, $(PROGS))

all :	$(BIN)

clean :
	-$(RM) *.u packages.txt bin/*

bin/%: 	%.icn
	oit -sW -o $@ $<
