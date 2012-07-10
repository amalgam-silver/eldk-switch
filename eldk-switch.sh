#!/bin/bash
#
# Call with "eval `eldk-switch.sh <arch, or board>`"
# e.g. put "eldk-switch() { eval `eldk-switch.sh $*`; }"
# in your .bashrc
#
# (C) 2007-2012 by Detlev Zundel, <dzu@denx.de> DENX Software Engineering GmbH
#

eldk_prefix=/opt/eldk-
rev=5.2
root_symlink=~/target-root

usage () {
    echo "usage: $(basename $0) [-v] [-m] [-r <release>] <board, cpu, eldkcc/target>"1>&2
    echo "	Switches to using the ELDK <release> for"			1>&2
    echo "	<board>, <cpu> or <eldkcc>/<target>."				1>&2
    echo "      -m will only affact a minimal amount of environment variables." 1>&2
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

# Get a field from a "colon separated key value file" which looks like this:
# Key 1: Value
# Another Key: Yet another value
cskv_getfield () {
    sed -n "/^${2}:/ { s/${2}: *//; p; q }" $1
}

strip_last_path () {
    echo $1 | sed 's|/[^/]\+$||'
}

# Determine ELDK generation
eldk_generation () {
    if [ -r ${1}/version ]; then
	echo "pre5"
    elif [ -n "$(ls ${1}/*/version* 2>/dev/null )" ] ;then
	echo "yocto"
    else
	echo "unknown"
    fi
}

# Get version information by looking at the version file in an ELDK installation
eldk_version () {
    eldk_root=$(strip_last_path $1)
    case $(eldk_generation ${eldk_root}) in
	pre5)
	    sed -n '1 { s/^[^0-9]*\(.*\)$/\1/ ; p }' ${eldk_root}/version
	    ;;
	yocto)
	    cskv_getfield ${1}/version-* "Distro Version"
	    ;;
	*)
	    echo "unknown"
	    ;;
    esac
}

# Enumerate ELDK installations
enum_eldk_roots () {
    for root in ${1}*
    do
	if [ "unknown" != "$(eldk_generation ${root})" ]
	then
	    echo $root
	fi
    done
}

# Enumerate installed arches
enum_eldk_arches () {
    case $(eldk_generation $1) in
	pre5)
	    # Get supported architectures by looking at the version
	    # file in an ELDK installation
	    sed -n '2~1 { s/^\(.*\):.*$/\1/ ; p }' ${1}/version
	    ;;
	yocto)
	    ls ${1}
	    ;;
    esac
}

# Iterate over all installed ELDK versions and show info
show_versions () {
    local dir
    local ver

    echo ",+--- Installed ELDK versions:" 1>&2
    for dir in $(enum_eldk_roots ${eldk_prefix/%-})
    do
	if [ ! -L $dir ]; then
	    set -- $(enum_eldk_arches $dir)
	    ver=$(eldk_version ${dir}/$1)
	    if [ "$ver" != "unknown" ]; then
		echo -en "eldk ${ver}: $dir " 1>&2
		unexpand $(enum_eldk_arches $dir | sort)  1>&2
	    fi
	else
	    set -- $(enum_eldk_arches $dir)
	    ver=$(eldk_version ${dir}/$1)
	    echo "eldk ${ver}: $dir  ->  $(readlink $dir)" 1>&2
	fi
    done
}

# Show currently used ELDK
query_version () {
    dir=$(echo $PATH | tr : "\n" | grep ${eldk_prefix/%-} | \
	head -1 | sed 's/\/bin//; s/\/usr\/bin//; s/\/sysroots.*$//';)
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
need_eldkcc_arch_change () {
    [ -z "$ARCH" ] && return 0
    if eldk-map eldkcc arch $1 | sed 's/:/\n/g' | grep -q "^${ARCH}$"; then
	return 1
    fi
    return 0
}

# Check if ARCH setting needs to be changed for target provided as first parameter
need_target_arch_change () {
    [ -z "$ARCH" ] && return 0
    if eldk-map target arch $1 | sed 's/:/\n/g' | grep -q "^${ARCH}$"; then
	return 1
    fi
    return 0
}

# Most unusual usage of sort :)
version_lte () {
    first=$(echo $1 | sed 's/[^.0-9]//g')
    second=$(echo $2 | sed 's/[^.0-9.]//g')
    [ "$(echo -e "${first}\n${second}" | sort --version-sort | head -1)" == "${first}" ]
}

# Parse options (bash extension)
while getopts mlqr:v option
do
    case $option in
	m)      minimal=1
		;;
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

if version_lte $rev "4.2"
then

    # Before version 5.0 (legacy)

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
	    eldkcc=$(eldk-map alias eldkcc $1 2>/dev/null)
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
	if need_eldkcc_arch_change $eldkcc
	then
	    cmds="$cmds ; export ARCH=$(eldk-map eldkcc arch $eldkcc | sed 's/:.*$//g')"
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

else

    # Post 5.0 (Yocto)

    # This is our "smart as a collie" lookup logic.  We try to interpret
    # the argument as a board, as a cpu, as an alias and finally only as
    # the ELDK CROSS_COMPILE value.
    cpu=$(eldk-map board cpu $1 2>/dev/null)
    if [ -n "$cpu" ]
    then
	echo "[ $1 is using $cpu ]" 1>&2
	target=$(eldk-map cpu target $cpu 2>/dev/null)
    else
	target=$(eldk-map cpu target $1 2>/dev/null)
	if [ -z "$target" ]
	then
	    target=$(eldk-map alias target $1 2>/dev/null)
	    if [ -z "$target" ]
	    then
		if eldk-map target | grep -q "^${1}\$"
		then
		    target=$1
		else
		    echo "$(basename $0): don't know what $1 might be, giving up."  1>&2
		    exit 1
		fi
	    fi
	fi
    fi

    if [ -z "$target" ]
    then
	echo "Internal error" 1>&2
    else
	prune_path ${eldk_prefix/%-}
	config=$(ls ${eldk_prefix}${rev}/${target}/environment-setup-* 2>/dev/null)
	if [ ! -r "${config}" ]
	then
	    echo "$(basename $0): ELDK $rev for $target is not installed!" 1>&2
	    exit 1
	fi
	echo "Setup for ${target} (using ELDK $rev)" 1>&2
	# Use our pruned path to add the new path in our environment
	pathcmd=$(cat ${config} | grep " PATH=")
	eval $pathcmd
	cmds=$(cat ${config} | grep -v " PATH=" | sed 's/$/ ; /g')
	# We want to reference ${TARGET_PREFIX}, so evaluate the settings
	eval $cmds
	# Built minimal set of variables, i.e. PATH, CROSS_COMPILE and ARCH
	min_cmds="export PATH=$PATH ; export CROSS_COMPILE=${TARGET_PREFIX}"
#	cmds="$cmds ; export DEPMOD=${eldk_prefix}${rev}/usr/bin/depmod.pl"
	if need_target_arch_change $target
	then
	    min_cmds="$min_cmds ; export ARCH=$(eldk-map target arch $target | sed 's/:.*$//g')"
	fi
	if [ -n "${minimal}" ]; then
	    cmds="$min_cmds"
	else
	    cmds="$min_cmds ; $cmds"
	fi
	echo $cmds
	[ -n "$verbose" ] && echo $cmds | sed 's/ ; /\n/g' 1>&2
	if [ -L $root_symlink ]
	then
	    rm $root_symlink
	    ln -s ${eldk_prefix}${rev}/${target}/rootfs $root_symlink
	    echo "Adjusted $root_symlink pointing to $(readlink $root_symlink)" 1>&2
	fi
    fi
fi
