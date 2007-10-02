# Sample extensions for .bashrc to optimize ELDK functionality

# This is the main interface to eldk-switch.sh
eldk-switch () {
    eval `eldk-switch.sh $*`;
}

# This is a nice wrapper for PS1 strings
__eldk_ps1 ()
{
    if [ -n "$CROSS_COMPILE" ]; then
	local CC=`echo $CROSS_COMPILE | sed 's/-$//; s/ppc_//;'`
	if [ -n "$1" ]; then
	    printf "$1" "$CC"
	else
	    printf " (%s)" "$CC"
	fi
    fi
}

# Sample PS1:
#PS1='[\u@\h \W$(__eldk_ps1 " (%s)")]\$ '

# Add the eldk prompt to PS1
add-eldk-to-ps1 () {
    if echo $PS1 | grep -qv __eldk_ps1
    then
	PS1=$(echo -n "$PS1" | sed 's/\]\\\$/$(__eldk_ps1 " (%s)")\]\\$/')
    fi
}
