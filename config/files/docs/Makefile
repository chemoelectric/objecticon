include ../Makedefs

.PHONY:	libref

ifeq (@MAKEINFO@,yes)
all: objecticon.info html

clean:
	rm -f objecticon.info
	rm -rf html libref

objecticon.info:  objecticon.texi
	makeinfo -o objecticon.info objecticon.texi

html:	objecticon.texi
	makeinfo --html -o html objecticon.texi
	touch html
else
all:
endif

libref:
	rm -rf libref
	mkdir libref
	oidoc -html -d -o libref -a
