#!/bin/sh
#
#  special test of preprocessing and related error detection

oit -E tpp.icn >tpp.out 2>tpp.err
set -e
cmp tpp.std tpp.out
cmp tpp.stde tpp.err
rm -f tpp.err
