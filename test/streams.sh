#!/bin/sh
#
[ -f custom.sh ] && . ./custom.sh
mkdir -p testdir
echo a >testdir/one
echo a >testdir/two
echo a >testdir/three
oit -s streams.icn
./streams >streams.out 2>&1
rm -rf testdir
set -e
if [ -e /env/sysname ] ; then
   cmp streams.out streams.std.p9
else
   cmp streams.out streams.std
fi