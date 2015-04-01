#!/bin/sh
#
#  special test of preprocessing and related error detection
[ -f custom.sh ] && . ./custom.sh
touch empty
oit -E tpp.icn >tpp.out 2>tpp.err
set -e
cmp tpp.out tpp.std
cmp tpp.err tpp.stde
rm -f tpp.err empty

