include ../../Makedefs

CWARN = -Wall

all:		mkposix posix.icn

clean:
		rm -f mkposix posix.icn

posix.icn: 	mkposix
	./mkposix >posix.icn
