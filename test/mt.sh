#!/bin/sh
#
#  special test of MT icon - dynamic loading of icon code
rm -f packages.txt
oit -s -c mt_packtest.icn
oit -s mt_c1.icn utils.icn
oit -s mt_c2.icn utils.icn
oit -s mt_c3.icn utils.icn
oit -s mt_p1.icn utils.icn
oit -s kwds.icn utils.icn
./mt_p1 >mt.out
rm -f mt_c1 mt_c2  mt_c3  mt_p1 kwds
set -e
cmp mt.out mt.std
