#!/bin/sh
set -e

bm()
{
    name=$1
    shift
    echo $name
    echo "----------------------"
    oit -s $name.icn post.icn
    ./$name "$@"
    if [ -x "$BM_ICONT" ] ; then
        $BM_ICONT -s $name.icn post.icn
        ./$name "$@"
    fi
    if [ -x "$BM_ICONC" ] ; then
        $BM_ICONC -s $name.icn post.icn
        ./$name "$@"
    fi
    if [ -x "$BM_JCONT" ] ; then
        $BM_JCONT -s $name.icn post.icn
        ./$name "$@"
    fi
    rm -f $name
    echo
    echo
}

. ../paths.sh

unset TRACE OIMAXLEVEL

[ -f custom.sh ] && . custom.sh

export BM_VERBOSE BM_OUTPUT
OPTIND=1
while getopts "voq" options; do
    case $options in
        v) BM_VERBOSE=1 ;;
        o) BM_OUTPUT=1 ;;
        q) unset BM_ICONT BM_ICONC BM_JCONT ;;
    esac
done
shift $((OPTIND-1))

if [ $# -eq 0 ] ; then
    set tgrlink geddump deal ipxref queens rsg concord cochain case operators
fi

while [ $# -gt 0 ] ; do
    case $1 in
        tgrlink) bm tgrlink tgrlink.dat;;
        geddump) bm geddump geddump.dat;;
        deal) bm deal -h 5000;;
        ipxref) bm ipxref bytecode.icn;;
        queens) bm queens -n10;;
        rsg) bm rsg rsg.dat;;
        concord) bm concord concord.dat;;
        cochain) bm cochain 2000;;
        case) bm case ;;
        operators) bm operators ;;
        *) echo "Unknown prog: $1"
            exit 1;;
    esac
    shift
done
