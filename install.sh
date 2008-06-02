#!/bin/bash
###################################################################
# Centreon is developped with GPL Licence 2.0 
#
# GPL License: http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#
# Developped by : Julien Mathis - Romain Le Merlus 
# Contribute	: Guillaume Watteeux - Maximilien Bersoult
#
###################################################################
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
#    For information : infos@centreon.com
####################################################################
#
# SVN: $URL$
# SVN: $Rev$
# SVN: $Author$
# SVN: $Date$
# SVN  $Id$
#
#
# Todo list
# - upgrade process 
# -- 1.x --> 2.x
# -- 2.x --> 2.x+1
# -- on upgrade, overwrite existing ? backup ? 
# - Add centTraps.sh for SNMP TRAPS


# define where is a centreon source 
BASE_DIR=$(dirname $0)
## set directory
BASE_DIR=$( cd $BASE_DIR; pwd )
export BASE_DIR
if [ -z "${BASE_DIR#/}" ] ; then
	echo -e "I think it is not right to have Centreon source on slash"
	exit 1
fi
INSTALL_DIR="$BASE_DIR/libinstall"
export INSTALL_DIR
INSTALL_VARS_DIR="$BASE_DIR/varinstall"
export INSTALL_VARS_DIR

# define a locale directory for use gettext (LC_MESSAGE)
TEXTDOMAINDIR=$BASE_DIR/locale
export TEXTDOMAINDIR
TEXTDOMAIN=install.sh
export TEXTDOMAIN

# init variables
line="------------------------------------------------------------------------"
export line

## log default vars 
. $INSTALL_VARS_DIR/vars

## Test if gettext was installed
# I use PATH variable to find
found="0"
OLDIFS="$IFS"
IFS=:
for p in $PATH ; do
	[ -x "$p/gettext" ] && found="1"
done
IFS=$OLDIFS
if [ $found -eq 1 ] ; then 
	. $INSTALL_DIR/gettext.sh
else
	# if not, use my gettext dummy :p
	PATH="$PATH:$INSTALL_DIR"
fi

## load all functions used in this script
. $INSTALL_DIR/functions

## Define a default log file
LOG_FILE=${LOG_FILE:=log\/install_centreon.log}

## Valid if you are root 
USERID=`id -u`
if [ "$USERID" != "0" ]; then
    echo -e "$(gettext "You must exec with root user")"
    exit 1
fi

silent_install="0"
upgrade="0"
user_install_vars=""

#define cinstall options
cinstall_opts=""

## Getopts :)
# When you use options, by default I set silent_install to 1.
while getopts "f:u:hv" Options
do
	case ${Options} in
		f )	silent_install="1"
			user_install_vars="${OPTARG}" ;;
		u )	silent_install="1"
			# At this moment I use a template file to update 
			# centreon install.
			# After that I think I demand only a centreon_etc
			# directory
			user_install_vars="${OPTARG}"
			cinstall_opts="$cinstall_opts -f"
			upgrade="1" ;;
		v )	cinstall_opts="$cinstall_opts -v" 
			# need one variable to parse debug log 
			;;
		\?|h)	usage ; exit 0 ;;
		* )	usage ; exit 1 ;;
	esac
done

#Export variable for all programs
export silent_install user_install_vars CENTREON_CONF cinstall_opts

version="2.0-b4"

cat << __EOT__
###############################################################################
#                                                                             #
#                         Centreon (www.centreon.com)                         #
#                          Thanks for using Centreon                          #
#                                                                             #
#                                    v$version                                   #
#                                                                             #
#                             infos@oreon-project.org                         #
#                                                                             #
#                   Make sure you have installed and configured               #
#                   sudo - sed - php - apache - rrdtool - mysql               #
#                                                                             #
###############################################################################
__EOT__


## init LOG_FILE
# backup old log file...
[ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
if [ -e "$LOG_FILE" ] ; then
	mv "$LOG_FILE" "$LOG_FILE.`date +%Y%m%d-%H%M%S`"
fi
# Clean (and create) my log file
cat << __EOL__ > "$LOG_FILE"
__EOL__

## Test all binaries
BINARIES="rm cp mv chmod chown echo cat more mkdir find sed"

echo "$line"
echo -e "\t$(gettext "Checking all needed binaries")"
echo "$line"

binary_fail="0"
# For the moment, I check if all binary exists in path.
# After, I must look a solution to use complet path by binary
for binary in $BINARIES; do
	pathfind "$binary"
	if [ "$?" -eq 0 ] ; then
		echo_success "${binary}" "$ok"
	else 
		echo_failure "${binary}" "$fail"
		log "ERR" "$(gettext "\$binary not found in \$PATH")"
		binary_fail=1

	fi
done

# Script stop if one binary wasn't found
if [ "$binary_fail" -eq 1 ] ; then
	echo_info "$(gettext "Please check fail binary and retry")"
	exit 1
fi

# When you exec this script without file, you must valid a GPL licence.
if [ "$silent_install" -ne 1 ] ; then 
	echo -e "\n$(gettext "You will now read Centreon Licence.\\n\\tPress enter to continue.")"
	read 
	tput clear 
	more "$BASE_DIR/LICENSE"

	yes_no_default "$(gettext "Do you accept GPL license ?")" 
	if [ "$?" -ne 0 ] ; then 
		echo_info "$(gettext "You do not agree to GPL license ? Okay... have a nice day.")"
		exit 1
	else
		log "INFO" "$(gettext "You accepted GPL license")"
	fi
else 
	. $user_install_vars
fi

## Check if is an upgrade or new install
## Use this on silent install ???
# Check for old configfile
# use for centreon1.x upgrade
if [ ! -z "`ls $CENTREON_CONF_1_4 2>/dev/null`" -a "$silent_install" -ne 1 ] ; then 
	is_single "$CENTREON_CONF_1_4"
	if [ "$?" -eq 1 ] ; then
		echo -e "$(gettext "Please select a good centreon config file")"
		select_in_array "CENTREON_CONF" "${CENTREON_CONF_1_4[@]}"
	fi
fi

if [ -e "$CENTREON_CONF" -a "$silent_install" -ne 1 ] ; then
	echo "$line"
	echo -e "\t$(gettext "Detecting old installation")"
	echo "$line"
	echo -e "\n\n"
	echo_success "$(gettext "Finding configuration file \$CENTREON_CONF :")" "$ok"
	log "INFO" "$(gettext "Old configuration found in ") $CENTREON_CONF"
	echo_info "$(gettext "You seem to have an existing Centreon.")\n"
	yes_no_default "$(gettext "Do you want to use the last Centreon install parameters ?")" "$yes"
	if [ "$?" -eq 0 ] ; then
		echo_passed "\n$(gettext "Using \$CENTREON_CONF : ")" "$passed"
		log "INFO" "$(gettext "Import old install config")"
		. $CENTREON_CONF
	fi
fi

echo "$line"
echo -e "\t$(gettext "Please choose what you want to install")"
echo "$line"

## init install process
# I prefer split install script.
# 0 = do not install
# 1 = install
# 2 = question in console
[ -z $PROCESS_CENTREON_WWW ] && PROCESS_CENTREON_WWW="2"
## For a moment, isn't possible to install standalone CentStorage daemon
[ -z $PROCESS_CENTSTORAGE ] && PROCESS_CENTSTORAGE="0"
[ -z $PROCESS_CENTCORE ] && PROCESS_CENTCORE="2"
[ -z $PROCESS_CENTREON_PLUGINS ] && PROCESS_CENTREON_PLUGINS="2"
[ -z $PROCESS_CENTREON_SNMP_TRAPS ] && PROCESS_CENTREON_SNMP_TRAPS="2"

## resquest centreon_www
if [ "$PROCESS_CENTREON_WWW" -eq 2 ] ; then 
	yes_no_default "$(gettext "Do you want to install") : Centreon Web Front"
	if [ "$?" -eq 0 ] ; then
		PROCESS_CENTREON_WWW="1"
		log "INFO" "$(gettext "You chose to install") : Centreon Web Front"
		## CentStorage dependancy
		PROCESS_CENTSTORAGE="1"
	fi
fi

## resquest centreon_centstorage
# CentWeb/CentStorage dependancy
[ "$PROCESS_CENTREON_WWW" -eq 1 ] && PROCESS_CENTSTORAGE="1"
if [ "$PROCESS_CENTSTORAGE" -eq 2 ] ; then 
	yes_no_default "$(gettext "Do you want to install") : Centreon CentStorage"
	if [ "$?" -eq 0 ] ; then
		PROCESS_CENTSTORAGE="1"
		log "INFO" "$(gettext "You chose to install") : Centreon CentStorage"
	fi
fi

## resquest centreon_centcore
if [ "$PROCESS_CENTCORE" -eq 2 ] ; then 
	yes_no_default "$(gettext "Do you want to install") : Centreon CentCore"
	if [ "$?" -eq 0 ] ; then
		PROCESS_CENTCORE="1"
		log "INFO" "$(gettext "You chose to install") : Centreon CentCore"
	fi
fi

## resquest centreon_plugins
if [ "$PROCESS_CENTREON_PLUGINS" -eq 2 ] ; then 
	yes_no_default "$(gettext "Do you want to install") : Centreon Nagios Plugins"
	if [ "$?" -eq 0 ] ; then
		PROCESS_CENTREON_PLUGINS="1"
		log "INFO" "$(gettext "You chose to install") : Centreon Nagios Plugins"
	fi
fi

## resquest centreon_snmp_traps
if [ "$PROCESS_CENTREON_SNMP_TRAPS" -eq 2 ] ; then 
	yes_no_default "$(gettext "Do you want to install") : Centreon Snmp Traps process"
	if [ "$?" -eq 0 ] ; then
		PROCESS_CENTREON_SNMP_TRAPS="1"
		log "INFO" "$(gettext "You chose to install") : Centreon Snmp Traps process"
	fi
fi

## Start Centreon Web Front install
if [ "$PROCESS_CENTREON_WWW" -eq 1 ] ; then 
	. $INSTALL_DIR/CentWeb.sh
fi

## Start CentStorage install
if [ "$PROCESS_CENTSTORAGE" -eq 1 ] ; then
	. $INSTALL_DIR/CentStorage.sh
fi

## Start CentCore install
if [ "$PROCESS_CENTCORE" -eq 1 ] ; then
	. $INSTALL_DIR/CentCore.sh
fi

## Start CentPlugins install
if [ "$PROCESS_CENTREON_PLUGINS" -eq 1 ] ; then
	. $INSTALL_DIR/CentPlugins.sh
fi
exit 0

