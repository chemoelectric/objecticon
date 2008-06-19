all: objecticon.info html

clean:
	rm -f objecticon.info
	rm -rf html

objecticon.info:  objecticon.texi
	makeinfo -o objecticon.info objecticon.texi

html:	objecticon.texi
	makeinfo --html -o html objecticon.texi
