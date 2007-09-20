#/bin/bash
# 
# Call with "eval `switch-eldk.sh <arch, or board>`"
# e.g. put "switch-eldk() { eval `switch-eldk.sh $*`; }"
# in your .bashrc
#
# (C) by Detlev Zundel, <dzu@denx.de> DENX Software Engineering GmbH
#

function usage {
    echo "usage: `basename $0` [-r <release>] <board, cpu or eldkcc>"	1>&2
    echo "	Switches to using the ELDK <release> for"		1>&2
    echo "	<board>, <cpu> or <eldkcc>."				1>&2
    exit 1
}

function add_path {
    if echo $PATH | grep -vq $1
    then
	PATH=$PATH:$1
    fi
}

function prune_path {
    if echo $PATH | grep -q $1
    then
        PATH=`echo $PATH | tr : "\n" | grep -v $1 | tr "\n" : | sed 's/:$//'`
    fi
}

# Parse options (bash extension)
while getopts r: OPTION
do
    case $OPTION in
        r)      REV=$OPTARG
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
CPU=`eldk-map board cpu $1`
if [ -n "$CPU" ]
then
    echo "echo \"[ $1 is using $CPU ]\";"
    ELDKCC=`eldk-map cpu eldkcc $CPU`
else
    ELDKCC=`eldk-map cpu eldkcc $1`
    if [ -z "$ELDKCC" ]
    then
	if eldk-map eldkcc | grep -q "^${1}\$"
	then
	    ELDKCC=$1
	else
	    echo "`basename $0`: don't know what $1 might be, giving up."  1>&2
	    exit 1
	fi
    fi
fi

if [ -z "$ELDKCC" ]
then
    echo "Internal error" >&2
else
    case $REV in
	3.1.1)
	    ELDK=eldk-3.1.1
	    ;;
	4.0)
	    ELDK=eldk-4.0
	    ;;
	4.1)
	    ELDK=eldk-4.1
	    ;;
	*)
	    ELDK=eldk-4.2
	    ;;
    esac
    
    prune_path eldk
    add_path /opt/${ELDK}/bin
    add_path /opt/${ELDK}/usr/bin
    echo "PATH=$PATH ;"
    echo "export CROSS_COMPILE=${ELDKCC}- ;"
    echo "echo \"Setup for ${ELDKCC} (using $ELDK)\""
fi
