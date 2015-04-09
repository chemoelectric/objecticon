#!/bin/sh
#
#  special test of traceback 
[ -f custom.sh ] && . ./custom.sh
rm -f traceback.out
oit -s traceback.icn 
./traceback >/dev/null 2>traceback.out
set -e 
cmp traceback.out traceback.std
