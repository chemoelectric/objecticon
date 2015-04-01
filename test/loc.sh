#!/bin/sh
#
[ -f custom.sh ] && . ./custom.sh
oit -l 1 -s loc.icn
./loc >loc.out 2>&1
oit -l 2 -s loc.icn
./loc >>loc.out 2>&1
set -e
cmp loc.out loc.std
