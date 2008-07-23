#  Makefile for the Icon run-time translator, rtt,
#  which is used to build the Icon run-time system.

include ../../Makedefs

CWARN = -Wall

ROBJS = rttparse.o rttmain.o rttlex.o rttsym.o rttnode.o rttout.o rttmisc.o\
	rtdb.o rttdb.o rttinlin.o rttilc.o yyerror.o \
	pout.o pchars.o  perr.o pmem.o  bldtok.o macro.o \
	preproc.o evaluate.o files.o gettok.o pinit.o

COBJS = ../common/getopt.o ../common/time.o \
	  ../common/identify.o ../common/strtbl.o\
	  ../common/mlocal.o ../common/literals.o \
	  ../common/alloc.o

OBJ = $(ROBJS) $(COBJS)

all:	rtt

clean:		
	rm -f *.o rtt typespec

rtt:	$(OBJ)
	$(CC) $(LDFLAGS) -o rtt $(OBJ)
	cp rtt $(OIBIN)

library:	$(OBJ)
		rm -rf rtt.a
		ar qc rtt.a $(OBJ)
		-(test -f ../../NoRanlib) || (ranlib rtt.a)

$(ROBJS): rtt.h rtt1.h rttproto.h preproc.h pproto.h ltoken.h ../h/mproto.h\
	        ../h/define.h ../h/config.h ../h/typedefs.h \
	        ../h/cstructs.h ../h/cpuconf.h

rtdb.o: ../h/version.h icontype.h

rttdb.o: ../h/version.h
rttparse.o : ../h/gsupport.h ../h/config.h ../h/cstructs.h \
	../h/typedefs.h ../h/cpuconf.h ../h/define.h


#  The following section is commented out because it does not need to be
#  performed unless changes are made to typespec.txt. Such changes
#  and are not part of the installation process.  However, if the
#  distribution files are unloaded in a fashion such that their dates
#  are not set properly, the following section would be attempted.
#
#  Note that if any changes are made to the file mentioned above, the
#  comment characters at the beginning of the following lines should be
#  removed.
#
#  Note that icont must be on your search path for this.
#
#
ifeq ($(TYPES),Y)
icontype.h: typespec.txt typespec
	typespec <typespec.txt >icontype.h

typespec: typespec.icn
	oit -s typespec
endif
#
# The following entry is commented out because it is not normally
# necessary to recreate rttparse.c and ltoken.h unless the grammar
# in rttgram.y for the run-time langauge is changed. Recreating these
# files is not normally a part of the installation process. Note that
# on some systems, yacc may not have large enough internal tables to
# translate this grammar.
#
#rttparse.c ltoken.h: rttgram.y
#	yacc -d $(YFLAGS) rttgram.y
#	fgrep -v -x "extern char *malloc(), *realloc();" y.tab.c > rttparse.c
#	rm y.tab.c
#	mv y.tab.h ltoken.h
