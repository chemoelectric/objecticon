#!/bin/sh
#
#  special test of co-expression tracing
#  (edits output to match v9's omission of co-expression return count)
[ -f custom.sh ] && . custom.sh
set -e 
oit -s cxtrace.icn 
./cxtrace 2>cxtrace.out
cmp cxtrace.out cxtrace.std
