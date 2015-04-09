#!/bin/sh
#
[ -f custom.sh ] && . ./custom.sh
rm -f packages.txt
oit -s -c classes_packtest?.icn
oit -l 2 -s classes.icn
./classes >classes.out 2>&1
rm -f classes classes_packtest?.u packages.txt
set -e
cmp classes.out classes.std
