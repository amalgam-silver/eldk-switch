#/bin/bash
#
# Call with "eval `switch-eldk.sh <arch, or board>`"
# e.g. put "switch-eldk() { eval `switch-eldk.sh $*`; }"
# in your .bashrc
#
# (C) by Detlev Zundel, <dzu@denx.de> DENX Software Engineering GmbH
#

eldk_prefix=/opt/eldk-
rev=4.2

usage () {
    echo "usage: `basename $0` [-r <release>] <board, cpu or eldkcc>"	1>&2
    echo "	Switches to using the ELDK <release> for"		1>&2
    echo "	<board>, <cpu> or <eldkcc>."				1>&2
    echo "       `basename $0` -q"					1>&2
    echo "	Queries the installed ELDKs"				1>&2
    exit 1
}

add_path () {
    if echo $PATH | grep -vq $1
    then
	PATH=$PATH:$1
    fi
}

prune_path () {
    if echo $PATH | grep -q $1
    then
	PATH=`echo $PATH | tr : "\n" | grep -v $1 | tr "\n" : | sed 's/:$//'`
    fi
}

eldk_version () {
    if [ -r ${1}/version ]; then
	sed -n '1 { s/^[^0-9]*\(.*\)$/\1/ ; p }' ${1}/version
    else
	echo "unknown"
    fi
}

eldk_arches () {
    sed -n '2~1 { s/^\(.*\):.*$/\1/ ; p }' ${1}/version
}

# Unexpand sorted entries by common prefix elimination
unexpand () {
    local prefix len lenm2 active last

    active=0
    len=1
    last=$1
    shift
    for item in $*
    do
	if [ $active -eq 0 ]; then
	    # Searching a prefix
	    lenm2=-1
	    while [ "${last:$lenm2:1}" != "_" \
		    -a "${last:0:$len}" = "${item:0:$len}" ]; do
		len=$(expr $len + 1)
		lenm2=$(expr $len - 2)
	    done
	    if [ $len -eq 1 ]; then
		echo -n "$last "
		last=$item
		continue
	    fi
	    active=1
	    len=$(expr $len - 1)
	    prefix=${last:0:$len}
	    echo -n "${prefix}{${last:$len},${item:$len}"
	else
	    # unxepanding prefixes
	    last=$item
	    if [ "$prefix" = "${item:0:$len}" ]; then
		echo -n ",${item:$len}"
	    else
		active=0
		len=1
		echo -n "} "
	    fi
	fi
    done
    # Cleanup
    if [ $active -eq 0 ]; then
	echo "$last"
    else
	echo "}"
    fi
}

show_versions () {
    local dir
    local ver

    echo ",+--- Installed ELDK versions:" 1>&2
    for dir in ${eldk_prefix}*
    do
	if [ ! -L $dir ]; then
	    ver=$(eldk_version $dir)
	    if [ "$ver" != "unknown" ]; then
		echo -en "eldk ${ver}: $dir " 1>&2
		unexpand $(eldk_arches $dir | sort)  1>&2
	    fi
	else
	    echo "eldk ${ver}: $dir  ->  $(readlink $dir)"
	fi
    done
}

# Parse options (bash extension)
while getopts qr: option
do
    case $option in
	q)      show_versions
	        exit 1
		;;
	r)      rev=$OPTARG
		;;
	*)      usage
		exit 1
		;;
    esac
done
shift $(( $OPTIND - 1 ))

# We expect exactly one required parameter
if [ $# -ne 1 ]
then
    usage
fi

# This is our "smart as a collie" lookup logic.  First we try to
# interpret the argument as a board, then as a cpu and finally only as
# the ELDK CROSS_COMPILE value.
cpu=`eldk-map board cpu $1`
if [ -n "$cpu" ]
then
    echo "[ $1 is using $cpu ]" 1>&2
    eldkcc=`eldk-map cpu eldkcc $cpu`
else
    eldkcc=`eldk-map cpu eldkcc $1`
    if [ -z "$eldkcc" ]
    then
	if eldk-map eldkcc | grep -q "^${1}\$"
	then
	    eldkcc=$1
	else
	    echo "`basename $0`: don't know what $1 might be, giving up."  1>&2
	    exit 1
	fi
    fi
fi

if [ -z "$eldkcc" ]
then
    echo "Internal error" >&2
else
    prune_path ${eldk_prefix}
    if [ ! -x ${eldk_prefix}${rev}/usr/bin/${eldkcc}-gcc ]
    then
	echo "`basename $0`: ELDK $rev for $eldkcc is not installed!" 1>&2
	exit 1
    fi
    add_path ${eldk_prefix}${rev}/bin
    add_path ${eldk_prefix}${rev}/usr/bin
    echo "PATH=$PATH ;"
    echo "export CROSS_COMPILE=${eldkcc}-"
    echo "Setup for ${eldkcc} (using ELDK $rev)" 1>&2
fi
