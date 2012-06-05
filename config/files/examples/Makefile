include ../Makedefs

PROGS=browser canvasstate colors cursors directorydialogtest \
	dndtest dyncomps editor explorer filedialogtest \
	fonttest geturl grabtest imageview lslinks \
	memorytracker multi selection sieve sizetest \
	sliders stock suggest tooltip treetest \
	ttexplorer

all :	$(PROGS)

clean :
	$(RM) *.u packages.txt $(PROGS)

browser : browser.icn textflow.icn tablelayout.icn
	oit -s -o browser browser.icn textflow.icn tablelayout.icn

%: 	%.icn
	oit -s $<
