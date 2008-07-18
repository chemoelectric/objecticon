include ../Makedefs

.PHONY:	libref

ifeq (@MAKEINFO@,yes)
all: objecticon.info htmlinfo

clean:
	rm -f objecticon.info
	rm -rf htmlinfo libref

objecticon.info:  objecticon.texi
	makeinfo -o objecticon.info objecticon.texi

htmlinfo:	objecticon.texi
	makeinfo --html -o htmlinfo objecticon.texi
	touch htmlinfo
else
all:
endif

libref:
	rm -rf libref
	mkdir libref
	oidoc -html -d -o libref -a
