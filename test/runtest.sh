#!/bin/sh

. ../paths.sh

unset TRACE OI_MAX_LEVEL

[ -f custom.sh ] && . ./custom.sh

# if no files specifies, use all
if [ $# = 0 ]; then
   set *.std
fi

# initialize list of failures
FAILED=""

# process files
for FNAME; do
    BASE=${FNAME%.*}
    echo ${BASE}:

    # if $BASE.sh exists, run that instead of preprogrammed script
    if [ -r $BASE.sh ]; then
	if ./$BASE.sh ; then
            rm -f $BASE $BASE.out
        else
            FAILED="$FAILED $BASE"
        fi
	continue
    fi

    # ensure that $BASE.icn and $BASE.std exist
    if [ ! -r $BASE.icn -o ! -r $BASE.std ]; then
	echo "   invalid test: missing $BASE.icn or $BASE.std"
	FAILED="$FAILED $BASE"
	continue
    fi

    # compile program; abort on failure
    if ! oit -s $BASE ; then
        FAILED="$FAILED $BASE"
        exit 1
        continue
    fi

    # run program, with stdin from $BASE.dat if it exists
    if [ -r $BASE.dat ]; then
	./$BASE $BASE.dat <$BASE.dat >$BASE.out 2>&1
    else
	./$BASE </dev/null >$BASE.out 2>&1
    fi

    rm -f $BASE *.u packages.txt

    if cmp $BASE.out $BASE.std  ; then
        rm -f $BASE.out
    else
        FAILED="$FAILED $BASE"
    fi        
done

# report summary of results
case "X$FAILED"  in
    X)  echo "Testing successful.";  exit 0;;
    *)  echo "Testing FAILED for: $FAILED"; exit 1;;
esac
