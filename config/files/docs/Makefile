include ../Makedefs

all: objecticon.info html

.PHONY:	libref

clean:
	rm -f objecticon.info
	rm -rf html libref

objecticon.info:  objecticon.texi
	makeinfo -o objecticon.info objecticon.texi

html:	objecticon.texi
	makeinfo --html -o html objecticon.texi
	touch html

libref:
	rm -rf libref
	mkdir libref
	oidoc -html -d -o libref -a $(OILIB)/ipl/*.icn
