#!/bin/sh
#
#  special test of MT icon - dynamic loading of icon code
[ -f custom.sh ] && . ./custom.sh
rm -f packages.txt
oit -s -c mt_packtest.icn
oit -s mt_c1.icn
oit -s mt_c2.icn
oit -s mt_c3.icn
oit -s mt_p1.icn
oit -s kwds.icn
./mt_p1 >mt.out 2>&1
rm -f mt_c1 mt_c2  mt_c3  mt_p1 kwds mt_packtest.u packages.txt
set -e
cmp mt.out mt.std
