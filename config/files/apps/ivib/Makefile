include ../../Makedefs

.NOTPARALLEL:

SRC=canvas.icn canvasborder.icn canvasborderdialog.icn \
	canvasborderui.icn canvasbutton.icn canvasbuttondialog.icn \
	canvasbuttongroup.icn canvascheckbox.icn canvascheckboxdialog.icn \
	canvascheckboxgroup.icn canvascheckboxmenuedit.icn canvascheckboxmenuitem.icn \
	canvascheckboxui.icn canvascomponent.icn canvascomponentdialog.icn \
	canvascomponentui.icn canvascustom.icn canvascustomdialog.icn \
	canvascustomui.icn canvaseditabletextlist.icn canvaseditabletextlistdialog.icn \
	canvaseditabletextlistui.icn canvaseditlist.icn canvaseditlistdialog.icn \
	canvaseditlistui.icn canvashscrollbarui.icn canvasicon.icn \
	canvasiconbutton.icn canvasiconbuttondialog.icn canvasiconbuttonui.icn \
	canvasiconui.icn canvasimage.icn canvasimagedialog.icn \
	canvasimageui.icn canvaslabel.icn canvaslabeldialog.icn \
	canvaslabelui.icn canvaslist.icn canvaslistdialog.icn \
	canvaslistui.icn canvasmenu.icn canvasmenubar.icn \
	canvasmenubardialog.icn canvasmenubarui.icn canvasmenubutton.icn \
	canvasmenubuttonui.icn canvasmenucomponent.icn canvasmenucomponentdialog.icn \
	canvasmenuseparator.icn canvasmenuseparatoredit.icn canvasoverlayitem.icn \
	canvasoverlayset.icn canvasoverlaysetdialog.icn canvasoverlaysetui.icn \
	canvaspanel.icn canvaspaneldialog.icn canvaspanelui.icn \
	canvasscrollbar.icn canvasscrollbardialog.icn canvastabitem.icn \
	canvastabitemdialog.icn canvastable.icn canvastablecolumn.icn \
	canvastablecolumndialog.icn canvastabledialog.icn canvastableui.icn \
	canvastabset.icn canvastabsetdialog.icn canvastabsetui.icn \
	canvastextbutton.icn canvastextbuttondialog.icn canvastextbuttonui.icn \
	canvastextfield.icn canvastextfielddialog.icn canvastextfieldui.icn \
	canvastextlist.icn canvastextlistdialog.icn canvastextlistui.icn \
	canvastextmenuitem.icn canvasvscrollbarui.icn cdialog.icn \
	code.icn custom.icn eventtab.icn gridset.icn infodialog.icn \
	ivibmigrate.icn main.icn menucomponentedit.icn menutree.icn \
	menutreenode.icn savechangesdialog.icn utils.icn version.icn \
	canvashlineui.icn  canvasline.icn  canvaslinedialog.icn  canvasvlineui.icn \
	canvastreeui.icn canvastree.icn canvastreedialog.icn \
	canvaslistspinui.icn canvaslistspin.icn canvaslistspindialog.icn \
	canvasrangespinui.icn canvasrangespin.icn canvasrangespindialog.icn \
	canvashsliderui.icn  canvasslider.icn  canvassliderdialog.icn  \
	canvasvsliderui.icn canvashsizerui.icn canvassizer.icn  \
	canvassizerdialog.icn  canvasvsizerui.icn componenttreedialog.icn \
	canvasprogressbarui.icn canvasprogressbar.icn canvastextdisplay.icn \
	canvastextdisplayui.icn canvastextdisplaydialog.icn layoutedit.icn \
	okcancel.icn canvaslayout.icn canvaspreferencesdialog.icn \
	xyalignlist.icn canvasborders.icn borderedit.icn \
	codetab.icn canvaspaint.icn paintfield.icn canvasobject.icn \
	groupsdialog.icn layoutfield.icn \
	borderfield.icn paintedit.icn canvasvsplitui.icn canvashsplitui.icn \
	canvassplit.icn canvassplitdialog.icn canvasoverlayitemdialog.icn \
	selectmodelist.icn maptab.icn canvasplugin.icn ivib.icn

UFILES=$(SRC:.icn=.u)
PROG=../../bin/ivib

all: $(PROG) plugin.u
	$(MAKE) -C plugins

etags:
	$(ETAGS) $(ICNTAGS) $(SRC) plugin.icn

clean:
	$(RM) *.u packages.txt $(PROG)
	$(MAKE) -C plugins clean

%.u: %.icn
	oit -sncW $(SRC) plugin.icn

$(PROG):	$(UFILES)
	oit -sW -o $@ $(UFILES)
