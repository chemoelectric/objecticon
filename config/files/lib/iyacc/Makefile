#  Makefile for iyacc, the Icon-enabled version of Berkeley YACC

include ../../Makedefs

OBJS	      = closure.o \
		error.o \
		lalr.o \
		lr0.o \
		main.o \
		mkpar.o \
		output.o \
		reader.o \
		skeleton.o \
		symtab.o \
		verbose.o \
		warshall.o

COBJS         = ../../base/common/mlocal.o ../../base/common/alloc.o

PROGRAM	      = ../../bin/iyacc

all:		$(PROGRAM)

$(PROGRAM):     $(OBJS)
		$(CC) $(CFLAGS) $(LDFLAGS) -o $(PROGRAM) $(OBJS) $(COBJS) $(LIBS)

clean:
		$(RM) *.o $(PROGRAM)

test:		$(PROGRAM)
		$(MAKE) -C test

###
closure.o: defs.h
error.o: defs.h
lalr.o: defs.h
lr0.o: defs.h
main.o: defs.h
mkpar.o: defs.h
output.o: defs.h
reader.o: defs.h
skeleton.o: defs.h
symtab.o: defs.h
verbose.o: defs.h
warshall.o: defs.h
