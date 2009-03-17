#!/bin/sh
#
#  special test of traceback 
rm -f traceback.out
oit -s traceback.icn 
./traceback >/dev/null 2>traceback.out
set -e 
cmp traceback.std traceback.out
