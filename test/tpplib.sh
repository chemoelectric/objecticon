#!/bin/sh
#
#  special test of preprocessing and related error detection
[ -f custom.sh ] && . ./custom.sh
touch empty
oit -s tpplib.icn
./tpplib tpp.icn >tpplib.out 2>tpplib.err
set -e
# should give same output as tpp.sh (tpplib.std is a dummy file)
cmp tpplib.out tpp.std
# but slightly different errors
cmp tpplib.err tpplib.stde
rm -f tpplib.err empty

