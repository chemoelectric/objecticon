#!/bin/sh
#
[ -f custom.sh ] && . custom.sh
oit -l 1 -s loc.icn utils.icn
./loc >loc.out
oit -l 2 -s loc.icn utils.icn
./loc >>loc.out
set -e
cmp loc.out loc.std
