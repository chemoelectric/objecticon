#!/bin/sh
#
#  special test of package scope
[ -f custom.sh ] && . ./custom.sh
oit -c -s packscope_first.icn
oit -s packscope1.icn 2>err_tmp
# Filter out absolute ufile path info
grep ^File err_tmp >packscope1.err
rm -f packscope1 packscope_first.u packages.txt err_tmp
set -e
cmp packscope1.err packscope1.std
rm -f packscope1.err

