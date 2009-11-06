#!/bin/sh
#
[ -f custom.sh ] && . custom.sh
rm -f packages.txt
oit -s -c classes_packtest?.icn
oit -l 2 -s classes.icn utils.icn
./classes >classes.out
rm -f classes classes_packtest?.u
set -e
cmp classes.out classes.std
