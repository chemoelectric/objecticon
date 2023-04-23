#!/bin/bash
if ! emacsclient -n "$@" &>/dev/null; then
    setsid -f emacs "$@" </dev/null &>/dev/null
fi
