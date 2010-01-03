#!/bin/sh
#
[ -f custom.sh ] && . custom.sh
mkdir -p testdir
echo a >testdir/one
echo a >testdir/two
echo a >testdir/three
oit -s streams.icn utils.icn
./streams >streams.out
rm -rf testdir
set -e
cmp streams.out streams.std
