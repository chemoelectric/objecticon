include ../Makedefs

PROGS=browser canvasstate colors cursors directorydialogtest \
	dndtest dyncomps editor explorer filedialogtest \
	fonttest geturl grabtest imageview lslinks \
	memorytracker multi selection sieve sizetest \
	sliders stock suggest tooltip treetest \
	ttexplorer fields flowterm bus lscookies \
	showtemplate cairotest

all :	$(PROGS)

clean :
	$(RM) *.u packages.txt $(PROGS)

%: 	%.icn
	oit -s $<
