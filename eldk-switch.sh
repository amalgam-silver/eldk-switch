#!/bin/bash
#
# Call with "eval `eldk-switch.sh <arch, or board>`"
# e.g. put "eldk-switch() { eval `eldk-switch.sh $*`; }"
# in your .bashrc
#
# (C) 2007-2008 by Detlev Zundel, <dzu@denx.de> DENX Software Engineering GmbH
#

eldk_prefix=/opt/eldk-
rev=4.2
root_symlink=~/target-root

usage () {
    echo "usage: $(basename $0) [-v] [-r <release>] <board, cpu or eldkcc>"	1>&2
    echo "	Switches to using the ELDK <release> for"			1>&2
    echo "	<board>, <cpu> or <eldkcc>."					1>&2
    echo "       $(basename $0) -l"						1>&2
    echo "	Lists the installed ELDKs"					1>&2
    echo "       $(basename $0) -q"						1>&2
    echo "	Queries the currently used ELDK"				1>&2
    exit 1
}

# Add $1 at the end of path only if not already present
add_path () {
    if echo $PATH | grep -vq $1
    then
	PATH=$PATH:$1
    fi
}

# Prune PATH of components starting with $1
prune_path () {
    if echo $PATH | grep -q $1
    then
	PATH=$(echo $PATH | tr : "\n" | grep -v $1 | tr "\n" : | sed 's/:$//')
    fi
}

# Get version information by looking at the version file in an ELDK installation
eldk_version () {
    if [ -r ${1}/version ]; then
	sed -n '1 { s/^[^0-9]*\(.*\)$/\1/ ; p }' ${1}/version
    else
	echo "unknown"
    fi
}

# Get supported architectures by looking at the version file in an ELDK installation
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

# Iterate over all installed ELDK versions and show info
show_versions () {
    local dir
    local ver

    echo ",+--- Installed ELDK versions:" 1>&2
    for dir in ${eldk_prefix}*
    do
	ver=$(eldk_version $dir)
	if [ ! -L $dir ]; then
	    if [ "$ver" != "unknown" ]; then
		echo -en "eldk ${ver}: $dir " 1>&2
		unexpand $(eldk_arches $dir | sort)  1>&2
	    fi
	else
	    echo "eldk ${ver}: $dir  ->  $(readlink $dir)" 1>&2
	fi
    done
}

# Show currently used ELDK
query_version () {
    dir=$(echo $PATH | tr : "\n" | grep ${eldk_prefix/%-} | head -1 | sed 's/\/bin//; s/\/usr\/bin//')
    ver=$(eldk_version $dir)
    if [ -n "$dir" ]; then
	echo "Currently using eldk ${ver} from ${dir}"	1>&2
	echo "CROSS_COMPILE=$CROSS_COMPILE"			1>&2
	[ -n "$ARCH" ] && echo "ARCH=$ARCH"			1>&2
    else
	echo "Environment is not setup to use an ELDK." 1>&2
    fi
}

# Check if ARCH setting needs to be changed for eldkcc provided as first parameter
need_arch_change () {
    [ -z "$ARCH" ] && return 0
    if eldk-map e a $1 | sed 's/:/\n/g' | grep -q "^${ARCH}$"; then
	return 1
    fi
    return 0
}

# Parse options (bash extension)
while getopts lqr:v option
do
    case $option in
	l)      show_versions
		exit 1
		;;
	q)	query_version
		exit 1
		;;
	r)      rev=$OPTARG
		;;
	v)	verbose=1
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

# This is our "smart as a collie" lookup logic.  We try to interpret
# the argument as a board, as a cpu, as an alias and finally only as
# the ELDK CROSS_COMPILE value.
cpu=$(eldk-map board cpu $1 2>/dev/null)
if [ -n "$cpu" ]
then
    echo "[ $1 is using $cpu ]" 1>&2
    eldkcc=$(eldk-map cpu eldkcc $cpu 2>/dev/null)
else
    eldkcc=$(eldk-map cpu eldkcc $1 2>/dev/null)
    if [ -z "$eldkcc" ]
    then
	eldkcc=$(eldk-map lias eldkcc $1 2>/dev/null)
	if [ -z "$eldkcc" ]
	then
	    if eldk-map eldkcc | grep -q "^${1}\$"
	    then
		eldkcc=$1
	    else
		echo "$(basename $0): don't know what $1 might be, giving up."  1>&2
		exit 1
	    fi
	fi
    fi
fi

if [ -z "$eldkcc" ]
then
    echo "Internal error" 1>&2
else
    prune_path ${eldk_prefix/%-}
    if [ ! -x ${eldk_prefix}${rev}/usr/bin/${eldkcc}-gcc ]
    then
	echo "$(basename $0): ELDK $rev for $eldkcc is not installed!" 1>&2
	exit 1
    fi
    echo "Setup for ${eldkcc} (using ELDK $rev)" 1>&2
    add_path ${eldk_prefix}${rev}/bin
    add_path ${eldk_prefix}${rev}/usr/bin
    cmds="PATH=$PATH"
    cmds="$cmds ; export CROSS_COMPILE=${eldkcc}-"
    cmds="$cmds ; export DEPMOD=${eldk_prefix}${rev}/usr/bin/depmod.pl"
    if need_arch_change $eldkcc
    then
	cmds="$cmds ; export ARCH=$(eldk-map e a $eldkcc | sed 's/:.*$//g')"
    fi
    echo $cmds
    [ -n "$verbose" ] && echo $cmds | sed 's/ ; /\n/g' 1>&2
    if [ -L $root_symlink ]
    then
	rm $root_symlink
	ln -s ${eldk_prefix}${rev}/${eldkcc} $root_symlink
	echo "Adjusted $root_symlink pointing to $(readlink $root_symlink)" 1>&2
    fi
fi
