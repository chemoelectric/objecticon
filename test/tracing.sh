#!/bin/sh
#
#  special test of procedure tracing output

rm -f tracing.out
oit -s tracing.icn 
./tracing 2>tracing.out
set -e 
cmp tracing.out tracing.std
