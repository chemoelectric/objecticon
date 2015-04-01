#!/bin/sh
#
#  special test of package scope
[ -f custom.sh ] && . ./custom.sh
oit -c -s packscope_first.icn
oit -s packscope2.icn
./packscope2  >packscope2.out 2>&1
rm -f packscope2 packscope_first.u packages.txt
set -e
cmp packscope2.out packscope2.std
rm -f packscope2.out

