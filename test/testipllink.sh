#!/bin/bash

#
# Script to make sure that each IPL package can be imported
# without error/warning.
#
[ -f custom.sh ] && . ./custom.sh
. ../paths.sh
cd ../lib/ipl

grep -h ^package\ ipl *.icn | sort | uniq | cut -c13- | while read pack ; do
    echo -n "Testing package $pack..."
    # Get a symbol in the package, to avoid an unused import warning
    proc=$( cat `grep -l "package ipl.${pack}$" *.icn` | grep ^\\\(procedure\\\|record\\\|class\\\).*\( |  awk '{ print substr($2,0,index($2,"(")-1) }' | head -1)

    cat >/tmp/oi_ipl_test.icn <<EOF
import ipl.$pack

procedure main()
    ipl.$pack.$proc
end
EOF
rm -f /tmp/oi_ipl_test
oit -s /tmp/oi_ipl_test.icn &>/tmp/oi_ipl_test_out

if test -e /tmp/oi_ipl_test ; then 
    x=$( wc /tmp/oi_ipl_test_out  -l )
    if test "$x" == "0 /tmp/oi_ipl_test_out" ; then
        echo OK
    else
        echo WARN
        cat /tmp/oi_ipl_test_out
        exit 1
    fi
else
    echo Failed for $pack
    cat /tmp/oi_ipl_test_out
    exit 1
fi
done
r=$?
rm -f /tmp/oi_ipl_test /tmp/oi_ipl_test_out
exit $r
