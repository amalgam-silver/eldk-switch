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

# Parse options (bash extension)
while getopts r: option
do
    case $option in
	r)      rev=$OPTARG
		;;
	*)      echo "unknown option $OPTARG" 1>&2
		usage
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
    prune_path eldk
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
