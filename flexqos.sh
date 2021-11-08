#!/bin/sh
###########################################################
#       ______  _               ____          _____       #
#      |  ____|| |             / __ \        / ____|      #
#      | |__   | |  ___ __  __| |  | |  ___ | (___        #
#      |  __|  | | / _ \\ \/ /| |  | | / _ \ \___ \       #
#      | |     | ||  __/ >  < | |__| || (_) |____) |      #
#      |_|     |_| \___|/_/\_\ \___\_\ \___/|_____/       #
#                                                         #
###########################################################
# FlexQoS maintained by dave14305
# Contributors: @maghuro
# shellcheck disable=SC1090,SC1091,SC2039,SC2154,SC3043
version=2.0.0
release=2021-11-07
# Forked from FreshJR_QOS v8.8, written by FreshJR07 https://github.com/FreshJR07/FreshJR_QOS
# License
#  FlexQoS is free to use under the GNU General Public License, version 3 (GPL-3.0).
#  https://opensource.org/licenses/GPL-3.0

# initialize Merlin Addon API helper functions
. /usr/sbin/helper.sh

# -x is a flag to show verbose script output for debugging purposes only
if [ "${1}" = "-x" ]; then
	shift
	set -x
fi

# Global variables
readonly SCRIPTNAME_DISPLAY="FlexQoS"
readonly SCRIPTNAME="flexqos"
readonly GIT_REPO="https://raw.githubusercontent.com/dave14305/${SCRIPTNAME_DISPLAY}"
GIT_BRANCH="$(am_settings_get "${SCRIPTNAME}_branch")"
if [ -z "${GIT_BRANCH}" ]; then
	GIT_BRANCH="master"
fi
GIT_URL="${GIT_REPO}/${GIT_BRANCH}"

readonly ADDON_DIR="/jffs/addons/${SCRIPTNAME}"
readonly WEBUIPATH="${ADDON_DIR}/${SCRIPTNAME}.asp"
readonly SCRIPTPATH="${ADDON_DIR}/${SCRIPTNAME}.sh"
readonly LOCKFILE="/tmp/addonwebui.lock"
IPv6_enabled="$(nvram get ipv6_service)"
qdisc="$(am_settings_get "${SCRIPTNAME}"_qdisc)"
qdisc="${qdisc:=1}"	# default to fq_codel (1) if not set

# Update version number in custom_settings.txt for reading in WebUI
if [ "$(am_settings_get "${SCRIPTNAME}"_ver)" != "${version}" ]; then
	am_settings_set "${SCRIPTNAME}"_ver "${version}"
fi

# If Merlin fq_codel patch is active, use original tc binary for passing commands
# Will be obsolete in 386.1 and higher.
if [ -e "/usr/sbin/realtc" ]; then
	TC="/usr/sbin/realtc"
else
	TC="/usr/sbin/tc"
fi

# Detect if script is run from an SSH shell interactively or being invoked via cron or from the WebUI (unattended)
if tty >/dev/null 2>&1; then
	mode="interactive"
else
	mode="unattended"
fi

# marks for iptables rules
# We use the ffff value to avoid conflicts with predefined apps in AppDB so there would be no conflict
# with any user-defined AppDB rules.
Net_mark="09"
Work_mark="06"
Gaming_mark="08"
Others_mark="0a"
Web_mark="18"
Streaming_mark="04"
Downloads_mark="03"
Learn_mark="3f"

Net_DSCP="CS6"
Work_DSCP="AF41"
Gaming_DSCP="CS6"
Others_DSCP="CS0"
Web_DSCP="CS0"
Streaming_DSCP="AF41"
Downloads_DSCP="CS1"
Learn_DSCP="CS0"

logmsg() {
	if [ "$#" = "0" ]; then
		return
	fi
	logger -t "${SCRIPTNAME_DISPLAY}" "$*"
} # logmsg

Red() {
	printf -- '\033[1;31m%s\033[0m\n' "${1}"
}

Green() {
	printf -- '\033[1;32m%s\033[0m\n' "${1}"
}

Blue() {
	printf -- '\033[1;36m%s\033[0m\n' "${1}"
}

Yellow() {
	printf -- '\033[1;33m%s\033[0m\n' "${1}"
}

get_class_mark() {
	case "${1}" in
		0) printf "%s\n" "${Net_mark}" ;;
		1) printf "%s\n" "${Gaming_mark}" ;;
		2) printf "%s\n" "${Streaming_mark}" ;;
		3) printf "%s\n" "${Work_mark}" ;;
		4) printf "%s\n" "${Web_mark}" ;;
		5) printf "%s\n" "${Downloads_mark}" ;;
		6) printf "%s\n" "${Others_mark}" ;;
		7) printf "%s\n" "${Learn_mark}" ;;
		*) printf "%s\n" ""	;;
	esac
}

iptables_static_rules() {
	local OUTPUTCLS
	OUTPUTCLS="$(am_settings_get "${SCRIPTNAME}"_outputcls)"
	OUTPUTCLS="$(get_class_mark "${OUTPUTCLS:-5}")"		# If setting not found, use default value of 5 (File Transfers)
	printf "Applying iptables static rules\n"
	# Reference for VPN Fix origin: https://www.snbforums.com/threads/36836/page-78#post-412034
	# Partially fixed in https://github.com/RMerl/asuswrt-merlin.ng/commit/f7d6478df7b934c9540fa9740ad71d49d84a1756
	iptables -t mangle -D OUTPUT -o "${wan}" -p udp -m multiport --dports 53,123 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff > /dev/null 2>&1		# Outbound DNS & NTP
	iptables -t mangle -A OUTPUT -o "${wan}" -p udp -m multiport --dports 53,123 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff
	iptables -t mangle -D OUTPUT -o "${wan}" -p tcp -m multiport --dports 53,853 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff > /dev/null 2>&1		# Outbound DNS and DoT
	iptables -t mangle -A OUTPUT -o "${wan}" -p tcp -m multiport --dports 53,853 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff
	iptables -t mangle -D OUTPUT -o "${wan}" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -t mangle -A OUTPUT -o "${wan}" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff
	iptables -t mangle -D OUTPUT -o "${wan}" -p tcp -m multiport ! --dports 53,853 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -t mangle -A OUTPUT -o "${wan}" -p tcp -m multiport ! --dports 53,853 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff
	iptables -t mangle -N "${SCRIPTNAME_DISPLAY}" 2>/dev/null
	iptables -t mangle -F "${SCRIPTNAME_DISPLAY}" 2>/dev/null
	iptables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}" 2>/dev/null
	iptables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}"
	if [ "${IPv6_enabled}" != "disabled" ]; then
		ip6tables -t mangle -D OUTPUT -o "${wan}" -p udp -m multiport --dports 53,123 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff > /dev/null 2>&1		# Outbound DNS & NTP
		ip6tables -t mangle -A OUTPUT -o "${wan}" -p udp -m multiport --dports 53,123 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff
		ip6tables -t mangle -D OUTPUT -o "${wan}" -p tcp -m multiport --dports 53,853 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff > /dev/null 2>&1		# Outbound DNS and DoT
		ip6tables -t mangle -A OUTPUT -o "${wan}" -p tcp -m multiport --dports 53,853 -j MARK --set-mark 0x40"${Net_mark}"0fff/0xc03f0fff
		ip6tables -t mangle -D OUTPUT -o "${wan}" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -t mangle -A OUTPUT -o "${wan}" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff
		ip6tables -t mangle -D OUTPUT -o "${wan}" -p tcp -m multiport ! --dports 53,853 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -t mangle -A OUTPUT -o "${wan}" -p tcp -m multiport ! --dports 53,853 -j MARK --set-mark 0x40"${OUTPUTCLS}"ffff/0xc03fffff
		ip6tables -t mangle -N "${SCRIPTNAME_DISPLAY}" 2>/dev/null
		ip6tables -t mangle -F "${SCRIPTNAME_DISPLAY}" 2>/dev/null
		ip6tables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}" 2>/dev/null
		ip6tables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}"
	fi
	if [ "${qdisc}" = "2" ]; then
		modprobe xt_comment
		# Setup mark to DSCP mappings for CAKE tins
		iptables -t mangle -N "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
		iptables -t mangle -F "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
		iptables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
		iptables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}_DSCP"
		# Setup chain for AppDB rules
		iptables -t mangle -N "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
		iptables -t mangle -F "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
		iptables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
		iptables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}_AppDB"
		# Voice tin
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x060000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "VoIP services"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x060000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x080000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Online games"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x080000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x090000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Management tools and protocols"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x090000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x120000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Network protocols"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x120000/0x3f0000 -j RETURN
		# Video tin
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x000000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Instant messengers"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x000000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x040000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Media streaming services"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x040000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x050000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Email messaging services"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x050000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x110000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Business tools"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x110000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0f0000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Web instant messengers"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0f0000/0x3f0000 -j RETURN
		# Bulk tin
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x010000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Peer-to-peer networks"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x010000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x030000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "File sharing services and tools"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x030000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0e0000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Security update tools"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0e0000/0x3f0000 -j RETURN
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x1a0000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Advertisements"
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x1a0000/0x3f0000 -j RETURN
		# Besteffort - default
		iptables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -j DSCP --set-dscp-class CS0
		if [ "${IPv6_enabled}" != "disabled" ]; then
			# Setup mark to DSCP mappings for CAKE tins
			ip6tables -t mangle -N "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
			ip6tables -t mangle -F "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
			ip6tables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}_DSCP" 2>/dev/null
			ip6tables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}_DSCP"
			# Setup chain for AppDB rules
			ip6tables -t mangle -N "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
			ip6tables -t mangle -F "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
			ip6tables -t mangle -D POSTROUTING -j "${SCRIPTNAME_DISPLAY}_AppDB" 2>/dev/null
			ip6tables -t mangle -A POSTROUTING -j "${SCRIPTNAME_DISPLAY}_AppDB"
			# Voice tin
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x060000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "VoIP services"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x060000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x080000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Online games"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x080000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x090000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Management tools and protocols"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x090000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x120000/0x3f0000 -j DSCP --set-dscp-class CS6 -m comment --comment "Network protocols"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x120000/0x3f0000 -j RETURN
			# Video tin
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x000000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Instant messengers"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x000000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x040000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Media streaming services"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x040000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x050000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Email messaging services"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x050000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x110000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Business tools"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x110000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0f0000/0x3f0000 -j DSCP --set-dscp-class AF41 -m comment --comment "Web instant messengers"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0f0000/0x3f0000 -j RETURN
			# Bulk tin
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x010000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Peer-to-peer networks"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x010000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x030000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "File sharing services and tools"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x030000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0e0000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Security update tools"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x0e0000/0x3f0000 -j RETURN
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x1a0000/0x3f0000 -j DSCP --set-dscp-class CS1 -m comment --comment "Advertisements"
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -m mark --mark 0x1a0000/0x3f0000 -j RETURN
			# Besteffort - default
			ip6tables -t mangle -A "${SCRIPTNAME_DISPLAY}_DSCP" -j DSCP --set-dscp-class CS0
		fi
	fi
}

get_static_filter() {
	local MARK
	local FLOWID

	MARK="${1}"
	FLOWID="${2}"

	printf "filter add dev %s protocol all prio 5 u32 match mark 0x80%sffff 0xc03fffff flowid %s\n" "${tclan}" "${MARK}" "${FLOWID}"
	printf "filter add dev %s protocol all prio 5 u32 match mark 0x40%sffff 0xc03fffff flowid %s\n" "${tcwan}" "${MARK}" "${FLOWID}"
} # get_static_filter

write_appdb_static_rules() {
	# These rules define the flowid (priority level) of the Class destinations selected by users in iptables rules.
	# Previous versions of the script were susceptible to the chosen Class being overridden by the users AppDB rules.
	# Adding these filters ensures the Class you select in iptables rules is strictly observed.
	# prio 5 is used because the first default filter rule (mark 0x80030000 0xc03f0000) is found at prio 6 as of this writing,
	# so we want these filters to always take precedence over the built-in filters.
	# File is overwritten (>) if it exists and later appended by write_appdb_rules() and write_custom_rates().
	{
		get_static_filter "${Net_mark}" "${Net_flow}"
		get_static_filter "${Work_mark}" "${Work_flow}"
		get_static_filter "${Gaming_mark}" "${Gaming_flow}"
		get_static_filter "${Others_mark}" "${Others_flow}"
		get_static_filter "${Web_mark}" "${Web_flow}"
		get_static_filter "${Streaming_mark}" "${Streaming_flow}"
		get_static_filter "${Downloads_mark}" "${Downloads_flow}"
		get_static_filter "${Learn_mark}" "${Learn_flow}"
	} >> "/tmp/${SCRIPTNAME}_tcrules"
} # write_appdb_static_rules

get_burst() {
	local RATE
	local DURATION
	local BURST
	local MIN_BURST

	RATE="${1}"
	DURATION="${2}"	# acceptable added latency in microseconds (1ms)

	# https://github.com/tohojo/sqm-scripts/blob/master/src/functions.sh
	# let's assume ATM/AAL5 to be the worst case encapsulation
	# and 48 Bytes a reasonable worst case per packet overhead
	MIN_BURST=$(( WANMTU + 48 ))		# add 48 bytes to MTU for the  overhead
	MIN_BURST=$(( MIN_BURST + 47 ))		# now do ceil(Min_BURST / 48) * 53 in shell integer arithmic
	MIN_BURST=$(( MIN_BURST / 48 ))
	MIN_BURST=$(( MIN_BURST * 53 ))		# for MTU 1489 to 1536 this will result in MIN_BURST = 1749 Bytes

	BURST=$((DURATION*RATE/8000))

	# If the calculated burst is less than ASUS' minimum value of 3200, use 3200
	# to avoid problems with child and leaf classes outside of FlexQoS scope that use 3200.
	# If using fq_codel option, use 1600 as a minimum burst.
	if [ "$(am_settings_get "${SCRIPTNAME}"_qdisc)" = "0" ]; then
		if [ "${BURST}" -lt 3200 ]; then
			BURST=3200
		fi
	elif [ "${BURST}" -lt "${MIN_BURST}" ]; then
		BURST="${MIN_BURST}"
	fi

	printf "%s" "${BURST}"
} # get_burst

get_cburst() {
	local RATE
	local BURST
	local MIN_BURST

	RATE="${1}"

	# https://github.com/tohojo/sqm-scripts/blob/master/src/functions.sh
	# let's assume ATM/AAL5 to be the worst case encapsulation
	# and 48 Bytes a reasonable worst case per packet overhead
	MIN_BURST=$(( WANMTU + 48 ))		# add 48 bytes to MTU for the  overhead
	MIN_BURST=$(( MIN_BURST + 47 ))		# now do ceil(Min_BURST / 48) * 53 in shell integer arithmic
	MIN_BURST=$(( MIN_BURST / 48 ))
	MIN_BURST=$(( MIN_BURST * 53 ))		# for MTU 1489 to 1536 this will result in MIN_BURST = 1749 Bytes

	BURST=$((RATE*1000/1280000))
	BURST=$((BURST*1600))

	# If the calculated burst is less than ASUS' minimum value of 3200, use 3200
	# to avoid problems with child and leaf classes outside of FlexQoS scope that use 3200.
	if [ "${BURST}" -lt 3200 ]; then
		if [ "$(am_settings_get "${SCRIPTNAME}"_qdisc)" = "0" ]; then
			BURST=3200
		else
			BURST="${MIN_BURST}"
		fi
	fi

	printf "%s" "${BURST}"
} # get_cburst

get_quantum() {
	local RATE
	local QUANTUM
	local MIN_QUANTUM

	RATE="${1}"

	# https://github.com/tohojo/sqm-scripts/blob/master/src/functions.sh
	# let's assume ATM/AAL5 to be the worst case encapsulation
	# and 48 Bytes a reasonable worst case per packet overhead
	MIN_QUANTUM=$(( WANMTU + 48 ))		# add 48 bytes to MTU for the  overhead
	MIN_QUANTUM=$(( MIN_QUANTUM + 47 ))		# now do ceil(Min_BURST / 48) * 53 in shell integer arithmic
	MIN_QUANTUM=$(( MIN_QUANTUM / 48 ))
	MIN_QUANTUM=$(( MIN_QUANTUM * 53 ))		# for MTU 1489 to 1536 this will result in MIN_BURST = 1749 Bytes

	QUANTUM=$((RATE*1000/8/10))

	# If the calculated quantum is less than the MTU, use MTU+14 as the quantum
	if [ "${QUANTUM}" -lt "${MIN_QUANTUM}" ]; then
		QUANTUM="${MIN_QUANTUM}"
	fi

	printf "%s" "${QUANTUM}"
} # get_quantum

get_overhead() {
	local NVRAM_OVERHEAD
	local NVRAM_ATM
	local NVRAM_MPU
	local OVERHEAD

	NVRAM_OVERHEAD="$(nvram get qos_overhead)"

	if [ -n "${NVRAM_OVERHEAD}" ] && [ "${NVRAM_OVERHEAD}" -gt "0" ]; then
		OVERHEAD="overhead ${NVRAM_OVERHEAD}"
		NVRAM_ATM="$(nvram get qos_atm)"
		case ${qdisc} in
		2)  # CAKE
			NVRAM_MPU="$(nvram get qos_mpu)"
			if [ -n "${NVRAM_MPU}" ] && [ "${NVRAM_MPU}" -gt "0" ]; then
				OVERHEAD="${OVERHEAD} mpu ${NVRAM_MPU}"
			fi
			if [ "${NVRAM_ATM}" = "1" ]; then
				OVERHEAD="${OVERHEAD} atm"
			elif [ "${NVRAM_ATM}" = "2" ]; then
				OVERHEAD="${OVERHEAD} ptm"
			fi
			;;
		*)
			if [ "${NVRAM_ATM}" = "1" ]; then
				OVERHEAD="${OVERHEAD} linklayer atm"
			fi
			;;
		esac
	fi
	printf "%s" "${OVERHEAD}"
} # get_overhead

get_custom_rate_rule() {
	local IFACE
	local PRIO
	local RATE
	local CEIL
	local DURATION

	IFACE="${1}"
	PRIO="${2}"
	RATE="${3}"
	CEIL="${4}"
	DURATION=1000	# 1000 microseconds = 1 ms

	printf "class change dev %s parent 1:1 classid 1:1%s htb %s prio %s rate %sKbit ceil %sKbit burst %sb cburst %sb quantum %s\n" \
			"${IFACE}" "${PRIO}" "$(get_overhead)" "${PRIO}" "${RATE}" "${CEIL}" "$(get_burst "${CEIL}" "${DURATION}")" "$(get_cburst "${CEIL}")" "$(get_quantum "${RATE}")"
} # get_custom_rate_rule

write_custom_rates() {
	local i
	if [ "${DownCeil}" -gt "0" ] && [ "${UpCeil}" -gt "0" ]; then
		# For all 8 classes (0-7), write the tc commands needed to modify the bandwidth rates and related parameters
		# that get assigned in set_tc_variables().
		# File is appended (>>) because it is initially created in write_appdb_static_rules().
		{
			for i in 0 1 2 3 4 5 6 7
			do
				eval get_custom_rate_rule "${tclan}" "${i}" \$DownRate${i} \$DownCeil${i}
				eval get_custom_rate_rule "${tcwan}" "${i}" \$UpRate${i} \$UpCeil${i}
			done
		} >> "/tmp/${SCRIPTNAME}_tcrules"
	fi
} # write_custom_rates

set_tc_variables() {
	# Read various settings from the router and construct the variables needed to implement the custom rules.
	local drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7
	local dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7
	local urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7
	local ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7
	# shellcheck disable=SC2034
	local Cat0DownBandPercent Cat1DownBandPercent Cat2DownBandPercent Cat3DownBandPercent Cat4DownBandPercent Cat5DownBandPercent Cat6DownBandPercent Cat7DownBandPercent
	# shellcheck disable=SC2034
	local Cat0DownCeilPercent Cat1DownCeilPercent Cat2DownCeilPercent Cat3DownCeilPercent Cat4DownCeilPercent Cat5DownCeilPercent Cat6DownCeilPercent Cat7DownCeilPercent
	# shellcheck disable=SC2034
	local Cat0UpBandPercent Cat1UpBandPercent Cat2UpBandPercent Cat3UpBandPercent Cat4UpBandPercent Cat5UpBandPercent Cat6UpBandPercent Cat7UpBandPercent
	# shellcheck disable=SC2034
	local Cat0UpCeilPercent Cat1UpCeilPercent Cat2UpCeilPercent Cat3UpCeilPercent Cat4UpCeilPercent Cat5UpCeilPercent Cat6UpCeilPercent Cat7UpCeilPercent
	local flowid
	local line
	local i

	tclan="br0"
	# Determine the WAN interface name used by tc by finding the existing htb root qdisc that is NOT br0.
	# If not found, check the dev_wan file created by Adaptive QoS.
	# If still not determined, assume eth0 but something is probably wrong at this point.
	tcwan="$("${TC}" qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')"
	if [ -z "${tcwan}" ] && [ -s "/tmp/bwdpi/dev_wan" ]; then
		tcwan="$(/bin/grep -oE "eth[0-9]|usb[0-9]" /tmp/bwdpi/dev_wan)"
	fi
	if [ -z "${tcwan}" ]; then
		tcwan="eth0"
	fi

	# Detect the default filter rule for Untracked traffic (Mark 000000) if it exists.
	# Newer 384 stock firmware dropped this rule, so Untracked traffic flows into the Work-From-Home priority by default.
	# First check for older ASUS default rule (0x80000000 0xc000ffff).
	# If not found, get the prio for the Work-From-Home Instant messengers category 00 (0x80000000 0xc03f0000) and subtract 1.
	undf_prio="$("${TC}" filter show dev br0 | /bin/grep -i -m1 -B1 "0x80000000 0xc000ffff" | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
	if [ -z "${undf_prio}" ]; then
		undf_prio="$("${TC}" filter show dev br0 | /bin/grep -i -m1 -B1 "0x80000000 0xc03f0000" | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
		undf_prio="$((undf_prio-1))"
	fi

	read -r \
		drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7 \
		dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7 \
		urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7 \
		ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7 \
<<EOF
$(echo "${bwrates}" | sed 's/^<//g;s/[<>]/ /g')
EOF

	# read priority order of QoS categories as set by user on the QoS page of the GUI
	flowid=0
	while read -r line;
	do
		if [ "$(echo "${line}" | cut -c 1)" = '[' ]; then
			flowid="$(echo "${line}" | cut -c 2)"
		fi
		case "${line}" in
		'0')
			Work_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp3}"
			eval "Cat${flowid}DownCeilPercent=${dcp3}"
			eval "Cat${flowid}UpBandPercent=${urp3}"
			eval "Cat${flowid}UpCeilPercent=${ucp3}"
			;;
		'1')
			Downloads_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp5}"
			eval "Cat${flowid}DownCeilPercent=${dcp5}"
			eval "Cat${flowid}UpBandPercent=${urp5}"
			eval "Cat${flowid}UpCeilPercent=${ucp5}"
			;;
		'4')
			# Special handling for category 4 since it is duplicated between Streaming and Learn-From-Home.
			# We have to find the priority placement of Learn-From-Home versus Streaming in the QoS GUI to know
			# if the first time we encounter a 4 in the file if it is meant to be Streaming or Learn-From-Home.
			# The second time we encounter a 4, we know it is meant for the remaining option.
			if nvram get bwdpi_app_rulelist | /bin/grep -qE "<4,13(<.*)?<4<"; then
				# Learn-From-Home is higher priority than Streaming
				if [ -z "${Learn_flow}" ]; then
					Learn_flow="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=${drp7}"
					eval "Cat${flowid}DownCeilPercent=${dcp7}"
					eval "Cat${flowid}UpBandPercent=${urp7}"
					eval "Cat${flowid}UpCeilPercent=${ucp7}"
				else
					Streaming_flow="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=${drp2}"
					eval "Cat${flowid}DownCeilPercent=${dcp2}"
					eval "Cat${flowid}UpBandPercent=${urp2}"
					eval "Cat${flowid}UpCeilPercent=${ucp2}"
				fi
			else
				# Streaming is higher priority than Learn-From-Home
				if [ -z "${Streaming_flow}" ]; then
					Streaming_flow="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=${drp2}"
					eval "Cat${flowid}DownCeilPercent=${dcp2}"
					eval "Cat${flowid}UpBandPercent=${urp2}"
					eval "Cat${flowid}UpCeilPercent=${ucp2}"
				else
					Learn_flow="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=${drp7}"
					eval "Cat${flowid}DownCeilPercent=${dcp7}"
					eval "Cat${flowid}UpBandPercent=${urp7}"
					eval "Cat${flowid}UpCeilPercent=${ucp7}"
				fi
			fi  # Check Learn-From-Home and Streaming priority order
			;;
		'7')
			Others_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp6}"
			eval "Cat${flowid}DownCeilPercent=${dcp6}"
			eval "Cat${flowid}UpBandPercent=${urp6}"
			eval "Cat${flowid}UpCeilPercent=${ucp6}"
			;;
		'8')
			Gaming_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp1}"
			eval "Cat${flowid}DownCeilPercent=${dcp1}"
			eval "Cat${flowid}UpBandPercent=${urp1}"
			eval "Cat${flowid}UpCeilPercent=${ucp1}"
			;;
		'9')
			Net_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp0}"
			eval "Cat${flowid}DownCeilPercent=${dcp0}"
			eval "Cat${flowid}UpBandPercent=${urp0}"
			eval "Cat${flowid}UpCeilPercent=${ucp0}"
			;;
		'24')
			Web_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp4}"
			eval "Cat${flowid}DownCeilPercent=${dcp4}"
			eval "Cat${flowid}UpBandPercent=${urp4}"
			eval "Cat${flowid}UpCeilPercent=${ucp4}"
			;;
		'na')
			# This is how the old ASUS default category would appear, but this option will soon be deprecated
			# when all supported models are using the new QoS Categories.
			Learn_flow="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=${drp7}"
			eval "Cat${flowid}DownCeilPercent=${dcp7}"
			eval "Cat${flowid}UpBandPercent=${urp7}"
			eval "Cat${flowid}UpCeilPercent=${ucp7}"
			;;
		esac
	done <<EOF
$(sed -E '/^ceil_/d;s/rule=//g;/\{/q' /tmp/bwdpi/qosd.conf | head -n -1)
EOF

	#calculate up/down rates based on user-provided bandwidth from GUI
	#GUI shows in Mb/s; nvram stores in Kb/s
	DownCeil="$(printf "%.0f" "$(nvram get qos_ibw)")"
	UpCeil="$(printf "%.0f" "$(nvram get qos_obw)")"

	# Only apply custom rates if Manual Bandwidth mode set in QoS page
	if [ "${DownCeil}" -gt "0" ] && [ "${UpCeil}" -gt "0" ]; then
		# Automatic bandwidth mode incompatible with custom rates
		i=0
		while [ "${i}" -lt "8" ]
		do
			eval "DownRate${i}=\$((DownCeil\*Cat${i}DownBandPercent/100))"
			eval "UpRate${i}=\$((UpCeil\*Cat${i}UpBandPercent/100))"
			eval "DownCeil${i}=\$((DownCeil\*Cat${i}DownCeilPercent/100))"
			eval "UpCeil${i}=\$((UpCeil\*Cat${i}UpCeilPercent/100))"
			i="$((i+1))"
		done
	fi # Auto Bandwidth check
} # set_tc_variables

appdb() {
	# Search TrendMicro appdb file for matches to user-specified string. Return up to 25 matches
	local line cat_decimal
	/bin/grep -m 25 -i "${1}" /tmp/bwdpi/bwdpi.app.db | while read -r line; do
		echo "${line}" | awk -F "," '{printf "  Application: %s, Mark: %02X%04X, Default Class: ", $4, $1, $2}'
		cat_decimal=$(echo "${line}" | cut -f 1 -d "," )
		case "${cat_decimal}" in
		'9'|'18'|'19'|'20')
			printf "Net Control Packets"
			;;
		'0'|'5'|'6'|'15'|'17')
			printf "Work-From-Home"
			;;
		'8')
			printf "Gaming"
			;;
		'7'|'10'|'11'|'21'|'23')
			printf "Others"
			;;
		'13'|'24')
			printf "Web Surfing"
			;;
		'4')
			printf "Video and Audio Streaming"
			;;
		'1'|'3'|'14')
			printf "File Transferring"
			;;
		*)
			printf "Unknown"
			;;
		esac
		printf "\n"
	done
} # appdb

webconfigpage() {
	local urlpage urlproto urldomain urlport

	# Eye candy function that will construct a URL to display after install or upgrade so a user knows where to
	# find the webUI page. In most cases though, they will go to the Adaptive QoS tab and find the FlexQoS sub-tab anyway.
	urlpage="$(sed -nE "/${SCRIPTNAME_DISPLAY}/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)"
	if [ "$(nvram get http_enable)" = "1" ]; then
		urlproto="https"
	else
		urlproto="http"
	fi
	if [ -n "$(nvram get lan_domain)" ]; then
		urldomain="$(nvram get lan_hostname).$(nvram get lan_domain)"
	else
		urldomain="$(nvram get lan_ipaddr)"
	fi
	if [ "$(nvram get ${urlproto}_lanport)" = "80" ] || [ "$(nvram get ${urlproto}_lanport)" = "443" ]; then
		urlport=""
	else
		urlport=":$(nvram get ${urlproto}_lanport)"
	fi

	if echo "${urlpage}" | grep -qE "user[0-9]+\.asp"; then
		printf "Advanced configuration available via:\n"
		Blue "  ${urlproto}://${urldomain}${urlport}/${urlpage}"
	fi
} # webconfigpage

scriptinfo() {
	# Version header used in interactive sessions
	[ "${mode}" = "interactive" ] || return
	printf "\n"
	Green "${SCRIPTNAME_DISPLAY} v${version} released ${release}"
	if [ "${GIT_BRANCH}" != "master" ]; then
		Yellow " Development channel"
	fi
	printf "\n"
} # scriptinfo

debug() {
	local RMODEL ipt_debug appdb_debug
	[ -z "$(nvram get odmpid)" ] && RMODEL="$(nvram get productid)" || RMODEL="$(nvram get odmpid)"
	Green "[SPOILER=\"${SCRIPTNAME_DISPLAY} Debug\"][CODE]"
	scriptinfo
	printf "Debug date    : %s\n" "$(date +'%Y-%m-%d %H:%M:%S%z')"
	printf "Router Model  : %s\n" "${RMODEL}"
	printf "Firmware Ver  : %s_%s\n" "$(nvram get buildno)" "$(nvram get extendno)"
	printf "DPI/Sig Ver   : %s / %s\n" "$(nvram get bwdpi_dpi_ver)" "$(nvram get bwdpi_sig_ver)"
	get_config
	set_tc_variables

	printf "WAN iface     : %s\n" "${wan}"
	printf "tc WAN iface  : %s\n" "${tcwan}"
	printf "IPv6          : %s\n" "${IPv6_enabled}"
	printf "Undf Prio     : %s\n" "${undf_prio}"
	printf "Down Band     : %s\n" "${DownCeil}"
	printf "Up Band       : %s\n" "${UpCeil}"
	printf "**************\n"
	printf "Net Control   : %s\n" "${Net_flow}"
	printf "Work-From-Home: %s\n" "${Work_flow}"
	printf "Gaming        : %s\n" "${Gaming_flow}"
	printf "Others        : %s\n" "${Others_flow}"
	printf "Web Surfing   : %s\n" "${Web_flow}"
	printf "Streaming     : %s\n" "${Streaming_flow}"
	printf "File Transfers: %s\n" "${Downloads_flow}"
	printf "Learn-From-Home: %s\n" "${Learn_flow}"
	printf "**************\n"
	# Only print custom rates if Manual Bandwidth setting is enabled on QoS page
	if [ "${DownCeil}" -gt "0" ] && [ "${UpCeil}" -gt "0" ]; then
		printf "Downrates     : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "${DownRate0}" "${DownRate1}" "${DownRate2}" "${DownRate3}" "${DownRate4}" "${DownRate5}" "${DownRate6}" "${DownRate7}"
		printf "Downceils     : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "${DownCeil0}" "${DownCeil1}" "${DownCeil2}" "${DownCeil3}" "${DownCeil4}" "${DownCeil5}" "${DownCeil6}" "${DownCeil7}"
		printf "Uprates       : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "${UpRate0}" "${UpRate1}" "${UpRate2}" "${UpRate3}" "${UpRate4}" "${UpRate5}" "${UpRate6}" "${UpRate7}"
		printf "Upceils       : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "${UpCeil0}" "${UpCeil1}" "${UpCeil2}" "${UpCeil3}" "${UpCeil4}" "${UpCeil5}" "${UpCeil6}" "${UpCeil7}"
		printf "**************\n"
	else
		printf "Custom rates disabled with Automatic Bandwidth mode!\n"
		printf "**************\n"
	fi
	ipt_debug="$(am_settings_get "${SCRIPTNAME}"_iptables)"
	printf "iptables settings: %s\n" "${ipt_debug:-Defaults}"
	write_iptables_rules
	# Remove superfluous commands from the output in order to focus on the parsed details
	/bin/sed -E "/^ip[6]?tables -t mangle -F ${SCRIPTNAME_DISPLAY}/d; s/ip[6]?tables -t mangle -A ${SCRIPTNAME_DISPLAY} //g; s/[[:space:]]{2,}/ /g" "/tmp/${SCRIPTNAME}_iprules"
	printf "**************\n"
	appdb_debug="$(am_settings_get "${SCRIPTNAME}"_appdb)"
	printf "appdb rules: %s\n" "${appdb_debug:-Defaults}"
	true > "/tmp/${SCRIPTNAME}_tcrules"
	write_custom_qdisc
	write_appdb_rules
	write_custom_rates
	cat "/tmp/${SCRIPTNAME}_tcrules"
	Green "[/CODE][/SPOILER]"
	# Since these tmp files aren't being used to apply rules, we delete them to avoid confusion about the last known ruleset
	rm "/tmp/${SCRIPTNAME}_iprules" "/tmp/${SCRIPTNAME}_tcrules"
	printf "\n"
	Yellow "Copy the text from [SPOILER] to [/SPOILER] and paste into a forum post at snbforums.com"
} # debug

get_dscp_class() {
	# Map class destination field from webui settings to the established class/flowid based on user priorities
	# flowid will be one of 1:10 - 1:17, depending on the user priority sequencing in the QoS GUI
	# Input: numeric class destination from iptables rule
	local dscp
	case "${1}" in
		0)	dscp="${Net_DSCP}" ;;
		1)	dscp="${Gaming_DSCP}" ;;
		2)	dscp="${Streaming_DSCP}" ;;
		3)	dscp="${Work_DSCP}" ;;
		4)	dscp="${Web_DSCP}" ;;
		5)	dscp="${Downloads_DSCP}" ;;
		6)	dscp="${Others_DSCP}" ;;
		7)	dscp="${Learn_DSCP}" ;;
		# return empty if destination missing
		*)	dscp="CS0" ;;
	esac
	printf "%s\n" "${dscp}"
} # get_dscp_class

get_flowid() {
	# Map class destination field from webui settings to the established class/flowid based on user priorities
	# flowid will be one of 1:10 - 1:17, depending on the user priority sequencing in the QoS GUI
	# Input: numeric class destination from iptables rule
	local flowid
	case "${1}" in
		0)	flowid="${Net_flow}" ;;
		1)	flowid="${Gaming_flow}" ;;
		2)	flowid="${Streaming_flow}" ;;
		3)	flowid="${Work_flow}" ;;
		4)	flowid="${Web_flow}" ;;
		5)	flowid="${Downloads_flow}" ;;
		6)	flowid="${Others_flow}" ;;
		7)	flowid="${Learn_flow}" ;;
		# return empty if destination missing
		*)	flowid="" ;;
	esac
	printf "%s\n" "${flowid}"
} # get_flowid

Is_Valid_CIDR() {
	/bin/grep -qE '^[!]?([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'
} # Is_Valid_CIDR

Is_Valid_Port() {
	/bin/grep -qE '^[!]?([0-9]{1,5})((:[0-9]{1,5})?|(,[0-9]{1,5})*)$'
} # Is_Valid_Port

Is_Valid_Mark() {
	/bin/grep -qE '^[!]?[A-Fa-f0-9]{2}([A-Fa-f0-9]{4}|[\*]{4})$'
} # Is_Valid_Mark

parse_appdb_rule_cake() {
	# Process an appdb custom rule into the appropriate tc filter syntax
	# Input: $1 = Mark from appdb rule XXYYYY XX=Category(hex) YYYY=ID(hex or ****)
	#        $2 = Class destination
	# Output: stdout is written directly to the /tmp/flexqos_iptables_rules file via redirect in write_appdb_rules(),
	#         so don't add unnecessary output in this function.
	local cat id
	local mark
	local dscp
	# Only process if Mark is a valid format
	if echo "${1}" | Is_Valid_Mark; then
		# Extract category and appid from mark
		cat="$(echo "${1}" | cut -c 1-2)"
		id="$(echo "${1}" | cut -c 3-6)"
		# check if wildcard mark
		if [ "${id}" = "****" ]; then
			# Replace asterisks with zeros and use category mask
			# This mark and mask
			mark="0x${cat}0000/0x3f0000"
			appid="$(printf '%d,' 0x${cat})"
			appname="$( grep ^${appid} /tmp/bwdpi/bwdpi.cat.db | cut -d, -f2 )"
		elif [ "${1}" = "000000" ]; then
			# unidentified traffic needs a special mask
			mark="0x${1}/0x00ffff"
			appname="Untracked"
		else
			# specific application mark
			mark="0x${1}/0x3fffff"
			appid="$(printf '%d,%d,' 0x${cat} 0x${id})"
			appname="$( grep ^${appid} /tmp/bwdpi/bwdpi.app.db | cut -d, -f4 )"
		fi

		# get destination dscp class
		dscp="$(get_dscp_class "${2}")"

		printf "iptables -t mangle -A %s_AppDB -m mark --mark %s -j DSCP --set-dscp-class %s -m comment --comment \"%s\"\n" "${SCRIPTNAME_DISPLAY}" "${mark}" "${dscp}" "${appname}"
		printf "iptables -t mangle -A %s_AppDB -m mark --mark %s -j RETURN\n" "${SCRIPTNAME_DISPLAY}" "${mark}"
		if [ "${IPv6_enabled}" != "disabled" ]; then
			printf "ip6tables -t mangle -A %s_AppDB -m mark --mark %s -j DSCP --set-dscp-class %s -m comment --comment \"%s\"\n" "${SCRIPTNAME_DISPLAY}" "${mark}" "${dscp}" "${appname}"
			printf "ip6tables -t mangle -A %s_AppDB -m mark --mark %s -j RETURN\n" "${SCRIPTNAME_DISPLAY}" "${mark}"
		fi
	fi # Is_Valid_Mark
} # parse_appdb_rule_cake

parse_appdb_rule() {
	# Process an appdb custom rule into the appropriate tc filter syntax
	# Input: $1 = Mark from appdb rule XXYYYY XX=Category(hex) YYYY=ID(hex or ****)
	#        $2 = Class destination
	# Output: stdout is written directly to the /tmp/flexqos_appdb_rules file via redirect in write_appdb_rules(),
	#         so don't add unnecessary output in this function.
	local cat id
	local DOWN_mark UP_mark
	local flowid
	local currmask
	local prio currprio
	local currhandledown currhandleup
	# Only process if Mark is a valid format
	if echo "${1}" | Is_Valid_Mark; then
		# Extract category and appid from mark
		cat="$(echo "${1}" | cut -c 1-2)"
		id="$(echo "${1}" | cut -c 3-6)"
		# check if wildcard mark
		if [ "${id}" = "****" ]; then
			# Replace asterisks with zeros and use category mask
			# This mark and mask
			DOWN_mark="0x80${cat}0000 0xc03f0000"
			UP_mark="0x40${cat}0000 0xc03f0000"
		elif [ "${1}" = "000000" ]; then
			# unidentified traffic needs a special mask
			DOWN_mark="0x80${1} 0xc000ffff"
			UP_mark="0x40${1} 0xc000ffff"
		else
			# specific application mark
			DOWN_mark="0x80${1} 0xc03fffff"
			UP_mark="0x40${1} 0xc03fffff"
		fi

		# get destination class
		flowid="$(get_flowid "${2}")"

		# To override the default tc filters with our custom filter rules, we need to insert our rules
		# at a higher priority (lower number) than the built-in filter for each category.
		if [ "${1}" = "000000" ]; then
			# special mask for unidentified traffic
			currmask="0xc000ffff"
		else
			currmask="0xc03f0000"
		fi
		# search the tc filter temp file we made in write_appdb_rules() for the existing priority of the
		# category we are going to override with a custom appdb filter rule.
		# e.g. If we are going to make a rule for appdb mark 1400C5, we need to find the current priority of category 14.
		prio="$(/bin/grep -i -m 1 -B1 "0x80${cat}0000 ${currmask}" "/tmp/${SCRIPTNAME}_tmp_tcfilterdown" | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
		currprio="${prio}"

		# If there is no existing filter for the category, use the undf_prio defined in set_tc_variables().
		# This is usually only necessary for Untracked traffic (mark 000000).
		# Otherwise, take the current priority and subtract 1 so that our rule will be processed earlier than the default rule.
		if [ -z "${prio}" ]; then
			prio="${undf_prio}"
		else
			prio="$((prio-1))"
		fi

		# Build and echo the tc filter commands based on the possible actions required:
		# 1. Change an existing filter to point to a new flowid (mostly relevant for wildcard appdb rules).
		# 2. Insert a new filter at a higher priority than the existing filter that would otherwise match this mark.
		if { [ "${id}" = "****" ] || [ "${1}" = "000000" ]; } && [ -n "${currprio}" ]; then
			# change existing rule for wildcard marks and Untracked mark only if current priority already determined.
			# Need to get handle of existing filter for proper tc filter change syntax.
			currhandledown="$(/bin/grep -i -m 1 -B1 "0x80${cat}0000 ${currmask}" "/tmp/${SCRIPTNAME}_tmp_tcfilterdown" | sed -nE 's/.* fh ([0-9a-f:]+) .*/\1/p')"
			currhandleup="$(/bin/grep -i -m 1 -B1 "0x40${cat}0000 ${currmask}" "/tmp/${SCRIPTNAME}_tmp_tcfilterup" | sed -nE 's/.* fh ([0-9a-f:]+) .*/\1/p')"
			printf "filter change dev %s prio %s protocol all handle %s u32 flowid %s\n" "${tclan}" "${currprio}" "${currhandledown}" "${flowid}"
			printf "filter change dev %s prio %s protocol all handle %s u32 flowid %s\n" "${tcwan}" "${currprio}" "${currhandleup}" "${flowid}"
		else
			# add new rule for individual app one priority level higher (-1)
			printf "filter add dev %s protocol all prio %s u32 match mark %s flowid %s\n" "${tclan}" "${prio}" "${DOWN_mark}" "${flowid}"
			printf "filter add dev %s protocol all prio %s u32 match mark %s flowid %s\n" "${tcwan}" "${prio}" "${UP_mark}" "${flowid}"
		fi
	fi # Is_Valid_Mark
} # parse_appdb_rule

create_ipset() {
	# To translate IPv4 iptables rules using local IPv4 addresses, create 2 ipsets and 2 iptables rules to track
	# corresponding IPv6 addresses for a given IPv4 local address
	# Input: $1 = local IP/CIDR (minus optional negation)
	# Output: stdout ipset and iptables commands
	local LOCALIP IPV6LIFETIME IPV6RASTATE

	# If IPv6 is disabled, return early
	[ "${IPv6_enabled}" = "disabled" ] && return

	# Strip optional negation if present
	LOCALIP="${1}"
	IPV6RASTATE="$(nvram get ipv6_autoconf_type)" # 0=Stateless, 1=Stateful
	ipset -! create "${LOCALIP}-mac" hash:mac timeout "$(nvram get dhcp_lease)" 2>/dev/null
	ipset -! flush "${LOCALIP}-mac" 2>/dev/null

	case "${IPv6_enabled}" in
	dhcp6|other) #Native or Static
		if [ "${IPV6RASTATE}" = "1" ]; then
			# Stateful, get DHCP Lifetime
			IPV6LIFETIME="$(nvram get ipv6_dhcp_lifetime)"
		else
			# Stateless, use hard-coded value from firmware
			IPV6LIFETIME=600
		fi
		;;
	*)
		IPV6LIFETIME=600
		;;
	esac

	ipset -! create "${LOCALIP}" hash:ip family inet6 timeout "${IPV6LIFETIME}" 2>/dev/null
	ipset -! flush "${LOCALIP}" 2>/dev/null

	printf "iptables -t mangle -D PREROUTING -i %s -m conntrack --ctstate NEW -s %s -j SET --add-set %s-mac src --exist 2>/dev/null\n" "${lan}" "${LOCALIP}" "${LOCALIP}"
	printf "ip6tables -t mangle -D PREROUTING -i %s -m conntrack --ctstate NEW -m set --match-set %s-mac src -j SET --add-set %s src --exist 2>/dev/null\n" "${lan}" "${LOCALIP}" "${LOCALIP}"
	printf "iptables -t mangle -I PREROUTING -i %s -m conntrack --ctstate NEW -s %s -j SET --add-set %s-mac src --exist\n" "${lan}" "${LOCALIP}" "${LOCALIP}"
	printf "ip6tables -t mangle -I PREROUTING -i %s -m conntrack --ctstate NEW -m set --match-set %s-mac src -j SET --add-set %s src --exist\n" "${lan}" "${LOCALIP}" "${LOCALIP}"
}

parse_iptablerule() {
	# Process an iptables custom rule into the appropriate iptables syntax
	# Input: $1 = local IP (e.g. 192.168.1.100 !192.168.1.100 192.168.1.100/31 !192.168.1.100/31)
	#        $2 = remote IP (e.g. 9.9.9.9 !9.9.9.9 9.9.9.0/24 !9.9.9.0/24)
	#        $3 = protocol (e.g. both, tcp, or udp)
	#        $4 = local port (e.g. 443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853)
	#        $5 = remote port (e.g. 443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853)
	#        $6 = mark (e.g. XXYYYY !XXYYYY XX=Category(hex) YYYY=ID(hex or ****))
	#        $7 = class destination (e.g. 0-7)
	# Output: stdout is written directly to the /tmp/flexqos_iprules file via redirect in write_iptables_rules(),
	#         so don't add unnecessary output in this function.
	local DOWN_Lip UP_Lip CIDR
	local DOWN_Lip6 UP_Lip6
	local DOWN_Rip UP_Rip
	local PROTOS proto
	local DOWN_Lport UP_Lport
	local DOWN_Rport UP_Rport
	local tmpMark DOWN_mark UP_mark
	local DOWN_dst UP_dst Dst_mark
	# local IP
	# Check for acceptable IP format
	if echo "${1}" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		DOWN_Lip="$(echo "${1}" | sed -E 's/^([!])?/\1 -d /')"
		UP_Lip="$(echo "${1}" | sed -E 's/^([!])?/\1 -s /')"
		# Only create ipset if there is no remote IP/CIDR defined, since the IPv6 rule would not work with remote IPv4 CIDR
		if ! echo "${2}" | Is_Valid_CIDR; then
			# Alternate syntax for IPv6 ipset matching
			CIDR="$(echo "${1}" | sed -E 's/^!//')"
			create_ipset "${CIDR}" # 2>/dev/null
			DOWN_Lip6="$(echo "${1}" | sed -E 's/^([!])?(([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?)/-m set \1 --match-set \2 dst/')"
			UP_Lip6="$(echo "${1}" | sed -E 's/^([!])?(([0-9]{1,3}\.){3}[0-9]{1,3}(\/[0-9]{1,2})?)/-m set \1 --match-set \2 src/')"
		fi
	else
		DOWN_Lip=""
		UP_Lip=""
		DOWN_Lip6=""
		UP_Lip6=""
	fi

	# remote IP
	# Check for acceptable IP format
	if echo "${2}" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		DOWN_Rip="$(echo "${2}" | sed -E 's/^([!])?/\1 -s /')"
		UP_Rip="$(echo "${2}" | sed -E 's/^([!])?/\1 -d /')"
	else
		DOWN_Rip=""
		UP_Rip=""
	fi

	# protocol (required when port specified)
	if [ "${3}" = "tcp" ] || [ "${3}" = "udp" ]; then
		# print protocol directly
		PROTOS="${3}"
	elif [ "${#4}" -gt "1" ] || [ "${#5}" -gt "1" ]; then
		# proto=both & ports are defined
		PROTOS="tcp>udp"		# separated by > because IFS will be temporarily set to '>' by calling function. TODO Fix Me
	else
		# neither proto nor ports defined
		PROTOS="all"
	fi

	# local port
	if echo "${4}" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		DOWN_Lport="-m multiport $(echo "${4}" | sed -E 's/^([!])?/\1 --dports /')"
		UP_Lport="-m multiport $(echo "${4}" | sed -E 's/^([!])?/\1 --sports /')"
	else
		DOWN_Lport=""
		UP_Lport=""
	fi

	# remote port
	if echo "${5}" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		DOWN_Rport="-m multiport $(echo "${5}" | sed -E 's/^([!])?/\1 --sports /')"
		UP_Rport="-m multiport $(echo "${5}" | sed -E 's/^([!])?/\1 --dports /')"
	else
		DOWN_Rport=""
		UP_Rport=""
	fi

	# mark
	if echo "${6}" | Is_Valid_Mark; then
		tmpMark="${6}"		# Use a tmp variable since we have to manipulate the contents for ! and ****
		DOWN_mark="-m mark"
		UP_mark="-m mark"
		if [ "$(echo "${tmpMark}" | cut -c 1)" = "!" ]; then		# first char is !
			DOWN_mark="${DOWN_mark} !"
			UP_mark="${UP_mark} !"
			tmpMark="$(echo "${tmpMark}" | sed -E 's/^!//')"		# strip the !
		fi
		# Extract category and appid from mark
		cat="$(echo "${tmpMark}" | cut -c 1-2)"
		id="$(echo "${tmpMark}" | cut -c 3-6)"
		# check if wildcard mark
		if [ "${id}" = "****" ]; then
			# replace **** with 0000 and use category mask
			DOWN_mark="${DOWN_mark} --mark 0x80${cat}0000/0xc03f0000"
			UP_mark="${UP_mark} --mark 0x40${cat}0000/0xc03f0000"
		else
			DOWN_mark="${DOWN_mark} --mark 0x80${tmpMark}/0xc03fffff"
			UP_mark="${UP_mark} --mark 0x40${tmpMark}/0xc03fffff"
		fi
	else
		DOWN_mark=""
		UP_mark=""
	fi

	# if all parameters are empty stop processing the rule
	if [ -z "${DOWN_Lip}${DOWN_Rip}${DOWN_Lport}${DOWN_Rport}${DOWN_mark}" ]; then
		return
	fi

	# destination mark
	# numbers come from webui select options for class field
	Dst_mark="$(get_class_mark "${7}")"
	if [ -z "${Dst_mark}" ]; then
		return
	fi
	DOWN_dst="-j MARK --set-mark 0x80${Dst_mark}ffff/0xc03fffff"
	UP_dst="-j MARK --set-mark 0x40${Dst_mark}ffff/0xc03fffff"

	# This block is redirected to the /tmp/flexqos_iprules file, so no extraneous output, please
	# If proto=both we have to create 2 statements, one for tcp and one for udp.
	for proto in ${PROTOS}; do
		# download ipv4
		printf "iptables -t mangle -A %s -o %s %s %s -p %s %s %s %s %s\n" "${SCRIPTNAME_DISPLAY}" "${lan}" "${DOWN_Lip}" "${DOWN_Rip}" "${proto}" "${DOWN_Lport}" "${DOWN_Rport}" "${DOWN_mark}" "${DOWN_dst}"
		# upload ipv4
		printf "iptables -t mangle -A %s -o %s %s %s -p %s %s %s %s %s\n" "${SCRIPTNAME_DISPLAY}" "${wan}" "${UP_Lip}" "${UP_Rip}" "${proto}" "${UP_Lport}" "${UP_Rport}" "${UP_mark}" "${UP_dst}"
		# If rule contains no IPv4 remote addresses, and IPv6 is enabled, add a corresponding rule for IPv6
		if [ "${IPv6_enabled}" != "disabled" ] && [ -z "${DOWN_Rip}" ]; then
			# download ipv6
			printf "ip6tables -t mangle -A %s -o %s %s -p %s %s %s %s %s\n" "${SCRIPTNAME_DISPLAY}" "${lan}" "${DOWN_Lip6}" "${proto}" "${DOWN_Lport}" "${DOWN_Rport}" "${DOWN_mark}" "${DOWN_dst}"
			# upload ipv6
			printf "ip6tables -t mangle -A %s -o %s %s -p %s %s %s %s %s\n" "${SCRIPTNAME_DISPLAY}" "${wan}" "${UP_Lip6}" "${proto}" "${UP_Lport}" "${UP_Rport}" "${UP_mark}" "${UP_dst}"
		fi
	done
} # parse_iptablerule

about() {
	scriptinfo
	cat <<EOF
License
  ${SCRIPTNAME_DISPLAY} is free to use under the GNU General Public License, version 3 (GPL-3.0).
  https://opensource.org/licenses/GPL-3.0

For discussion visit this thread:
  https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=8
  https://github.com/dave14305/FlexQoS (Source Code)

About
  Script Changes Unidentified traffic destination away from Work-From-Home into Others
  Script Changes HTTPS traffic destination away from Net Control into Web Surfing
  Script Changes Guaranteed Bandwidth per QoS category into logical percentages of upload and download.
  Script includes misc default rules
   (Wifi Calling)  -  UDP traffic on remote ports 500 & 4500 moved into Work-From-Home
   (Facetime)      -  UDP traffic on local  ports 16384 - 16415 moved into Work-From-Home
   (Usenet)        -  TCP traffic on remote ports 119 & 563 moved into File Transfers
   (Gaming)        -  Gaming TCP traffic from remote ports 80 & 443 moved into File Transfers.
   (Snapchat)      -  Moved into Others
   (Speedtest.net) -  Moved into File Transfers
   (Google Play)   -  Moved into File Transfers
   (Apple AppStore)-  Moved into File Transfers
   (VPN Fix)       -  Router VPN Client upload traffic moved into File Transfers instead of whitelisted
   (Gaming Manual) -  Unidentified traffic for specified devices, not originating from ports 80/443, moved into Gaming

Gaming Rule Note
  Gaming traffic originating from ports 80 & 443 is primarily downloads & patches (some lobby/login protocols mixed within)
  Manually configurable rule will take untracked traffic for specified devices, not originating from server ports 80/443, and place it into Gaming
  Use of this gaming rule REQUIRES devices to have a continuous static ip assignment & this range needs to be passed into the script
EOF
}

backup() {
	# Backup existing user rules in /jffs/addons/custom_settings.txt
	# Input: create [force]|restore|remove
	case "${1}" in
		'create')
			if [ "${2}" != "force" ] && [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
				printf "A backup already exists. Do you want to overwrite this backup? [1=Yes 2=No]: "
				read -r yn
				if [ "${yn}" != "1" ]; then
					Yellow "Backup cancelled."
					return
				fi
			fi
			printf "Running backup...\n"
			{
				printf "#!/bin/sh\n"
				printf "# Backup date: %s\n" "$(date +'%Y-%m-%d %H:%M:%S%z')"
				printf ". /usr/sbin/helper.sh\n"
				[ -n "$(am_settings_get "${SCRIPTNAME}"_iptables)" ]       && printf "am_settings_set %s_iptables \"%s\"\n" "${SCRIPTNAME}" "$(am_settings_get "${SCRIPTNAME}"_iptables)"
				[ -n "$(am_settings_get "${SCRIPTNAME}"_iptables_names)" ] && printf "am_settings_set %s_iptables_names \"%s\"\n" "${SCRIPTNAME}" "$(am_settings_get "${SCRIPTNAME}"_iptables_names)"
				[ -n "$(am_settings_get "${SCRIPTNAME}"_appdb)" ]          && printf "am_settings_set %s_appdb \"%s\"\n" "${SCRIPTNAME}" "$(am_settings_get "${SCRIPTNAME}"_appdb)"
				[ -n "$(am_settings_get "${SCRIPTNAME}"_bwrates)" ]        && printf "am_settings_set %s_bwrates \"%s\"\n" "${SCRIPTNAME}" "$(am_settings_get "${SCRIPTNAME}"_bwrates)"
				[ -n "$(am_settings_get "${SCRIPTNAME}"_qdisc)" ]          && printf "am_settings_set %s_qdisc \"%s\"\n" "${SCRIPTNAME}" "$(am_settings_get "${SCRIPTNAME}"_qdisc)"
			} > "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			if /bin/grep -q "${SCRIPTNAME}_" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"; then
				Green "Backup done to ${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			else
				rm "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
				Yellow "Backup cancelled. All settings using default values."
			fi
			;;
		'restore')
			if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				Yellow "$(grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh")"
				printf "Do you want to restore this backup? [1=Yes 2=No]: "
				read -r yn
				if [ "${yn}" = "1" ]; then
					sh "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
					Green "Backup restored!"
					needrestart=1
				else
					Yellow "Restore cancelled."
				fi
			else
				Red "No backup file exists!"
			fi
			;;
		'remove')
			[ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ] && rm "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			Green "Backup deleted."
		;;
	esac
} # backup

download_file() {
	# Download file from Github once to a temp location. If the same as the destination file, don't replace.
	# Otherwise move it from the temp location to the destination.
	if curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/${1}" -o "/tmp/${1}"; then
		if [ "$(md5sum "/tmp/${1}" | awk '{print $1}')" != "$(md5sum "${2}" 2>/dev/null | awk '{print $1}')" ]; then
			mv -f "/tmp/${1}" "${2}"
			logmsg "Updated $(basename "${1}")"
		else
			logmsg "File $(basename "${2}") is already up-to-date"
			rm -f "/tmp/${1}" 2>/dev/null
		fi
	else
		logmsg "Updating $(basename "${1}") failed"
	fi
} # download_file

compare_remote_version() {
	# Check version on Github and determine the difference with the installed version
	# Outcomes: Version update, or no update
	local remotever
	# Fetch version of the shell script on Github
	remotever="$(curl -fsN --retry 3 --connect-timeout 3 "${GIT_URL}/$(basename "${SCRIPTPATH}")" | /bin/grep "^version=" | sed -e 's/version=//')"
	if [ "$( echo "${version}" | sed 's/\.//g' )" -lt "$( echo "${remotever}" | sed 's/\.//g' )" ]; then		# strip the . from version string for numeric comparison
		# version upgrade
		echo "${remotever}"
	else
		printf "NoUpdate\n"
	fi
} # compare_remote_version

update() {
	# Check for, and optionally apply updates.
	# Parameter options: check (do not update), silent (update without prompting)
	local updatestatus yn
	scriptinfo
	printf "Checking for updates\n"
	# Update the webui status thorugh detect_update.js ajax call.
	printf "var verUpdateStatus = \"%s\";\n" "InProgress" > "/www/ext/${SCRIPTNAME}/detect_update.js"
	updatestatus="$(compare_remote_version)"
	# Check to make sure we got back a valid status from compare_remote_version(). If not, indicate Error.
	case "${updatestatus}" in
		'NoUpdate'|[0-9].[0-9].[0-9]) ;;
		*) updatestatus="Error"
	esac
	printf "var verUpdateStatus = \"%s\";\n" "${updatestatus}" > "/www/ext/${SCRIPTNAME}/detect_update.js"

	if [ "${1}" = "check" ]; then
		# Do not proceed with any updating if check function requested
		return
	fi
	if [ "${mode}" = "interactive" ] && [ -z "${1}" ]; then
		case "${updatestatus}" in
		'NoUpdate')
			Green " You have the latest version installed"
			printf " Would you like to overwrite your existing installation anyway? [1=Yes 2=No]: "
			;;
		'Error')
			Red " Error determining remote version status!"
			PressEnter
			return
			;;
		*)
			# New Version Number
			Green " ${SCRIPTNAME_DISPLAY} v${updatestatus} is now available!"
			printf " Would you like to update now? [1=Yes 2=No]: "
			;;
		esac
		read -r yn
		printf "\n"
		if [ "${yn}" != "1" ]; then
			Green " No Changes have been made"
			return 0
		fi
	fi
	printf "Installing: %s...\n\n" "${SCRIPTNAME_DISPLAY}"
	download_file "$(basename "${SCRIPTPATH}")" "${SCRIPTPATH}"
	exec sh "${SCRIPTPATH}" -install "${1}"
	exit
} # update

prompt_restart() {
	# Restart QoS so that FlexQoS changes can take effect.
	# Possible values for $needrestart:
	#  0: No restart needed (initialized in main)
	#  1: Restart needed, but prompt user if interactive session
	#  2: Restart needed, do not prompt (force)
	local yn
	if [ "${needrestart}" -gt "0" ]; then
		if [ "${mode}" = "interactive" ]; then
			if [ "${needrestart}" = "1" ]; then
				printf "\nWould you like to restart QoS for modifications to take effect? [1=Yes 2=No]: "
				read -r yn
				if [ "${yn}" = "2" ]; then
					needrestart=0
					return
				fi
			fi
		fi
		printf "Restarting QoS and firewall...\n"
		service "restart_qos;restart_firewall"
		needrestart=0
	fi
} # prompt_restart

menu() {
	# Minimal interactive, menu-driven interface for basic maintenance functions.
	local yn
	[ "${mode}" = "interactive" ] || return
	clear
	sed -n '2,10p' "${0}"		# display banner
	scriptinfo
	printf "  (1) about        explain functionality\n"
	printf "  (2) update       check for updates\n"
	printf "  (3) debug        traffic control parameters\n"
	printf "  (4) restart      restart QoS\n"
	printf "  (5) backup       create settings backup\n"
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		printf "  (6) restore      restore settings from backup\n"
		printf "  (7) delete       remove backup\n"
	fi
	printf "\n  (9) uninstall    uninstall script\n"
	printf "  (e) exit\n"
	printf "\nMake a selection: "
	read -r input
	case "${input}" in
		'1')
			about
		;;
		'2')
			update
		;;
		'3')
			debug
		;;
		'4')
			needrestart=1
			prompt_restart
		;;
		'5')
			backup create
		;;
		'6')
			if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				backup restore
			else
				Red "$input is not a valid option!"
			fi
		;;
		'7')
			if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				backup remove
			else
				Red "$input is not a valid option!"
			fi
		;;
		'9')
			scriptinfo
			printf " Do you want to uninstall %s [1=Yes 2=No]: " "${SCRIPTNAME_DISPLAY}"
			read -r yn
			if [ "${yn}" = "1" ]; then
				printf "\n"
				sh "${SCRIPTPATH}" -uninstall
				printf "\n"
				exit
			fi
			printf "\n"
			Yellow "${SCRIPTNAME_DISPLAY} has NOT been uninstalled"
		;;
		'e'|'E'|'exit')
			return
		;;
		*)
			Red "$input is not a valid option!"
		;;
	esac
	PressEnter
	menu		# stay in the menu loop until exit is chosen
} # menu

remove_webui() {
	local prev_webui_page
	local FD
	printf "Removing WebUI...\n"
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPTNAME_DISPLAY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "${prev_webui_page}" ]; then
		# Remove page from the UI menu system
		FD=386
		eval exec "${FD}>${LOCKFILE}"
		/usr/bin/flock -x "${FD}"
		umount /www/require/modules/menuTree.js 2>/dev/null
		sed -i "\~tabName: \"${SCRIPTNAME_DISPLAY}\"},~d" /tmp/menuTree.js
		if diff -q /tmp/menuTree.js /www/require/modules/menuTree.js >/dev/null 2>&1; then
			# no more custom pages mounted, so remove the file
			rm /tmp/menuTree.js
		else
			# Still some modifications from another script so remount
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		/usr/bin/flock -u "${FD}"
		# Remove last mounted asp page
		rm -f "/www/user/${prev_webui_page}" 2>/dev/null
		# Look for previously mounted asp pages that are orphaned now and delete them
		/bin/grep -l "${SCRIPTNAME_DISPLAY} maintained by dave14305" /www/user/user*.asp 2>/dev/null | while read -r oldfile
		do
			rm "${oldfile}"
		done
	fi
	rm -rf "/www/ext/${SCRIPTNAME}" 2>/dev/null		# remove js helper scripts
} # remove_webui

install_webui() {
	local prev_webui_page
	local FD
	# if this is an install or update...otherwise it's a normal startup/mount
	if [ -z "${1}" ]; then
		printf "Downloading WebUI files...\n"
		download_file "$(basename "${WEBUIPATH}")" "${WEBUIPATH}"
		# cleanup obsolete files from previous versions
		[ -L "/www/ext/${SCRIPTNAME}" ] && rm "/www/ext/${SCRIPTNAME}" 2>/dev/null
		[ -d "${ADDON_DIR}/table" ] && rm -r "${ADDON_DIR}/table"
		[ -f "${ADDON_DIR}/${SCRIPTNAME}_arrays.js" ] && rm "${ADDON_DIR}/${SCRIPTNAME}_arrays.js"
	fi
	FD=386
	eval exec "${FD}>${LOCKFILE}"
	/usr/bin/flock -x "${FD}"
	# Check if the webpage is already mounted in the GUI and reuse that page
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPTNAME_DISPLAY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "${prev_webui_page}" ]; then
		# use the same filename as before
		am_webui_page="${prev_webui_page}"
	else
		# get a new mountpoint
		am_get_webui_page "${WEBUIPATH}"
	fi
	if [ "${am_webui_page}" = "none" ]; then
		logmsg "No API slots available to install web page"
	else
		cp -p "${WEBUIPATH}" "/www/user/${am_webui_page}"
		if [ ! -f /tmp/menuTree.js ]; then
			cp /www/require/modules/menuTree.js /tmp/
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		if ! /bin/grep -q "{url: \"$am_webui_page\", tabName: \"${SCRIPTNAME_DISPLAY}\"}," /tmp/menuTree.js; then
			umount /www/require/modules/menuTree.js 2>/dev/null
			sed -i "\~{url: \"$am_webui_page\"~d; \~tabName: \"${SCRIPTNAME_DISPLAY}\"},~d" /tmp/menuTree.js
			sed -i "/url: \"QoS_Stats.asp\", tabName:/i {url: \"$am_webui_page\", tabName: \"${SCRIPTNAME_DISPLAY}\"}," /tmp/menuTree.js
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
	fi
	/usr/bin/flock -u "${FD}"
	[ ! -d "/www/ext/${SCRIPTNAME}" ] && mkdir -p "/www/ext/${SCRIPTNAME}"
}

Init_UserScript() {
	# Properly setup an empty Merlin user script
	local userscript
	if [ -z "${1}" ]; then
		return
	fi
	userscript="/jffs/scripts/$1"
	if [ ! -f "${userscript}" ]; then
		# If script doesn't exist yet, create with shebang
		printf "#!/bin/sh\n\n" > "${userscript}"
	elif [ -f "${userscript}" ] && ! head -1 "${userscript}" | /bin/grep -qE "^#!/bin/sh"; then
		#  Script exists but no shebang, so insert it at line 1
		sed -i '1s~^~#!/bin/sh\n~' "${userscript}"
	elif [ "$(tail -c1 "${userscript}" | wc -l)" = "0" ]; then
		# Script exists with shebang, but no linefeed before EOF; makes appending content unpredictable if missing
		printf "\n" >> "${userscript}"
	fi
	if [ ! -x "${userscript}" ]; then
		# Ensure script is executable by owner
		chmod 755 "${userscript}"
	fi
} # Init_UserScript

Auto_ServiceEventEnd() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	local cmdline
	Init_UserScript "service-event-end"
	# Delete existing lines related to this script
	sed -i "\~${SCRIPTNAME_DISPLAY} Addition~d" /jffs/scripts/service-event-end
	# Add line to handle wrs and sig_check events that require reapplying settings
	cmdline="if [ \"\$2\" = \"wrs\" ] || [ \"\$2\" = \"sig_check\" ]; then { sh ${SCRIPTPATH} -start & } ; fi # ${SCRIPTNAME_DISPLAY} Addition"
	echo "${cmdline}" >> /jffs/scripts/service-event-end
	# Add line to handle other events triggered from webui
	cmdline="if echo \"\$2\" | /bin/grep -q \"^${SCRIPTNAME}\"; then { sh ${SCRIPTPATH} \"\${2#${SCRIPTNAME}}\" & } ; fi # ${SCRIPTNAME_DISPLAY} Addition"
	echo "${cmdline}" >> /jffs/scripts/service-event-end
} # Auto_ServiceEventEnd

Auto_FirewallStart() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	local cmdline
	Init_UserScript "firewall-start"
	# Delete existing lines related to this script
	sed -i "\~${SCRIPTNAME_DISPLAY} Addition~d" /jffs/scripts/firewall-start
	# Add line to trigger script on firewall startup
	cmdline="sh ${SCRIPTPATH} -start & # ${SCRIPTNAME_DISPLAY} Addition"
	if /bin/grep -vE "^#" /jffs/scripts/firewall-start | /bin/grep -q "Skynet"; then
		# If Skynet also installed, insert this script before Skynet so it doesn't have to wait for Skynet to startup before applying QoS
		# Won't delay Skynet startup since we fork into the background
		sed -i "/Skynet/i ${cmdline}" /jffs/scripts/firewall-start
	else
		# Skynet not installed, so just append
		echo "${cmdline}" >> /jffs/scripts/firewall-start
	fi # is Skynet also installed?
} # Auto_FirewallStart

setup_aliases() {
	# shortcuts to launching script
	local cmdline
	if [ -d /opt/bin ]; then
		# Entware is installed, so setup link to /opt/bin
		printf "Adding %s link in Entware /opt/bin...\n" "${SCRIPTNAME}"
		ln -sf "${SCRIPTPATH}" "/opt/bin/${SCRIPTNAME}"
	else
		# Setup shell alias
		printf "Adding %s alias in profile.add...\n" "${SCRIPTNAME}"
		sed -i "/alias ${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
		cmdline="alias ${SCRIPTNAME}=\"sh ${SCRIPTPATH}\" # ${SCRIPTNAME_DISPLAY} Addition"
		echo "${cmdline}" >> /jffs/configs/profile.add
	fi
} # setup_aliases

Firmware_Check() {
	printf "Checking firmware support...\n"
	if ! nvram get rc_support | grep -q am_addons; then
		Red "${SCRIPTNAME_DISPLAY} requires ASUSWRT-Merlin Addon API support. Installation aborted."
		printf "\nInstall FreshJR_QOS via amtm as an alternative for your firmware version.\n"
		return 1
	fi
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "1" ]; then
		Red "Adaptive QoS is not enabled. Please enable it in the GUI. Aborting installation."
		return 1
	fi
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		Red "\"Enable JFFS custom scripts and configs\" is not enabled. Please enable it in the GUI. Aborting installation."
		return 1
	fi
} # Firmware_Check

install() {
	# Install script and download webui file
	# This is also called by the update process once a new script is downlaoded by update() function
	if [ "${mode}" = "interactive" ]; then
		clear
		scriptinfo
		printf "Installing %s...\n" "${SCRIPTNAME_DISPLAY}"
		if ! Firmware_Check; then
			PressEnter
			rm -f "${0}" 2>/dev/null
			exit 5
		fi
	fi
	if [ ! -d "${ADDON_DIR}" ]; then
		printf "Creating directories...\n"
		mkdir -p "${ADDON_DIR}"
		chmod 755 "${ADDON_DIR}"
	fi
	if [ ! -f "${SCRIPTPATH}" ]; then
		cp -p "${0}" "${SCRIPTPATH}"
	fi
	if [ ! -x "${SCRIPTPATH}" ]; then
		chmod 755 "${SCRIPTPATH}"
	fi
	install_webui
	generate_bwdpi_arrays force
	printf "Adding %s entries to Merlin user scripts...\n" "${SCRIPTNAME_DISPLAY}"
	Auto_FirewallStart
	Auto_ServiceEventEnd
	setup_aliases

	if [ "${mode}" = "interactive" ]; then
		Green "${SCRIPTNAME_DISPLAY} installation complete!"
		scriptinfo
		webconfigpage

		if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ] && ! /bin/grep -qE "^${SCRIPTNAME}_[^(ver )]" /jffs/addons/custom_settings.txt ; then
			Green "Backup found!"
			backup restore
		fi
		[ "$(nvram get qos_enable)" = "1" ] && needrestart=1
	else
		[ "$(nvram get qos_enable)" = "1" ] && needrestart=2
	fi
	# Remove setting if set to default value 1 (enabled)
	sed -i "/^${SCRIPTNAME}_conntrack 1/d" /jffs/addons/custom_settings.txt
	# Remove deprecated 3:30 AM cron job if exists
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/services-start 2>/dev/null
	cru d "${SCRIPTNAME}" 2>/dev/null
} # install

uninstall() {
	local yn
	printf "Removing entries from Merlin user scripts...\n"
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/firewall-start 2>/dev/null
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/service-event-end 2>/dev/null
	printf "Removing aliases and shortcuts...\n"
	sed -i "/alias ${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
	rm -f "/opt/bin/${SCRIPTNAME}" 2>/dev/null
	printf "Removing delayed cron job...\n"
	cru d "${SCRIPTNAME}_5min" 2>/dev/null
	remove_webui
	printf "Removing %s settings...\n" "${SCRIPTNAME_DISPLAY}"
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		printf "Backup found! Would you like to keep it? [1=Yes 2=No]: "
		read -r yn
		if [ "${yn}" = "2" ]; then
			printf "Deleting Backup...\n"
			rm "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
		fi
	else
		printf "Do you want to backup your settings before uninstall? [1=Yes 2=No]: "
		read -r yn
		if [ "${yn}" = "1" ]; then
			printf "Backing up %s settings...\n" "${SCRIPTNAME_DISPLAY}"
			backup create force
		fi
	fi
	sed -i "/^${SCRIPTNAME}_/d" /jffs/addons/custom_settings.txt
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		printf "Deleting %s folder contents except Backup file...\n" "${SCRIPTNAME_DISPLAY}"
		/usr/bin/find "${ADDON_DIR}" ! -name restore_"${SCRIPTNAME}"_settings.sh ! -exec test -d {} \; -a -exec rm {} +
	else
		printf "Deleting %s directory...\n" "${SCRIPTNAME_DISPLAY}"
		rm -rf "${ADDON_DIR}"
	fi
	Green "${SCRIPTNAME_DISPLAY} has been uninstalled"
	needrestart=1
} # uninstall

get_config() {
	local iptables_rules_defined
	local drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7
	local dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7
	local urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7
	local ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7

	# Read settings from Addon API config file. If not defined, set default values
	iptables_rules="$(am_settings_get "${SCRIPTNAME}"_iptables)"
	if [ -z "${iptables_rules}" ]; then
		iptables_rules="<>>udp>>500,4500>>3<>>udp>16384:16415>>>3<>>tcp>>119,563>>5<>>tcp>>80,443>08****>5"
	fi
	appdb_rules="$(am_settings_get "${SCRIPTNAME}"_appdb)"
	if [ -z "${appdb_rules}" ]; then
		appdb_rules="<000000>6<00006B>6<0D0007>5<0D0086>5<0D00A0>5<12003F>4<13****>4<14****>4"
	fi
	bwrates="$(am_settings_get "${SCRIPTNAME}"_bwrates)"
	if [ -z "${bwrates}" ]; then
		# New settings not set
		if [ -z "$(am_settings_get "${SCRIPTNAME}"_bandwidth)" ]; then
			# Old settings not set either, so set the defaults
			bwrates="<5>15>30>20>10>5>10>5<100>100>100>100>100>100>100>100<5>15>10>20>10>5>30>5<100>100>100>100>100>100>100>100"
		else
			# Convert bandwidth to bwrates by reading existing values into the re-sorted order
			read -r \
				drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7 \
				dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7 \
				urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7 \
				ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7 \
<<EOF
$(am_settings_get "${SCRIPTNAME}"_bandwidth | sed 's/^<//g;s/[<>]/ /g')
EOF
			am_settings_set "${SCRIPTNAME}"_bwrates "<${drp0}>${drp2}>${drp5}>${drp1}>${drp4}>${drp7}>${drp3}>${drp6}<${dcp0}>${dcp2}>${dcp5}>${dcp1}>${dcp4}>${dcp7}>${dcp3}>${dcp6}<${urp0}>${urp2}>${urp5}>${urp1}>${urp4}>${urp7}>${urp3}>${urp6}<${ucp0}>${ucp2}>${ucp5}>${ucp1}>${ucp4}>${ucp7}>${ucp3}>${ucp6}"
			bwrates="<${drp0}>${drp2}>${drp5}>${drp1}>${drp4}>${drp7}>${drp3}>${drp6}<${dcp0}>${dcp2}>${dcp5}>${dcp1}>${dcp4}>${dcp7}>${dcp3}>${dcp6}<${urp0}>${urp2}>${urp5}>${urp1}>${urp4}>${urp7}>${urp3}>${urp6}<${ucp0}>${ucp2}>${ucp5}>${ucp1}>${ucp4}>${ucp7}>${ucp3}>${ucp6}"
			if [ "${bwrates}" != "<5>15>30>20>10>5>10>5<100>100>100>100>100>100>100>100<5>15>10>20>10>5>30>5<100>100>100>100>100>100>100>100" ]; then
				am_settings_set "${SCRIPTNAME}"_bwrates "<${drp0}>${drp2}>${drp5}>${drp1}>${drp4}>${drp7}>${drp3}>${drp6}<${dcp0}>${dcp2}>${dcp5}>${dcp1}>${dcp4}>${dcp7}>${dcp3}>${dcp6}<${urp0}>${urp2}>${urp5}>${urp1}>${urp4}>${urp7}>${urp3}>${urp6}<${ucp0}>${ucp2}>${ucp5}>${ucp1}>${ucp4}>${ucp7}>${ucp3}>${ucp6}"
			fi
			sed -i "/^${SCRIPTNAME}_bandwidth /d" /jffs/addons/custom_settings.txt
		fi
	fi
} # get_config

validate_iptables_rules() {
	# Basic check to ensure the number of rules present in the iptables chain matches the number of expected rules
	# Does not verify that the rules present match the rules in the config, since the config hasn't been parsed at this point.
	local iptables_rules_defined iptables_rules_expected iptables_rulespresent
	local fail
	fail=0
	iptables_rules_defined="$(echo "${iptables_rules}" | sed 's/</\n/g' | /bin/grep -vc "^$")"
	iptables_rules_expected=$((iptables_rules_defined*2+1)) # 1 download and upload rule per user rule, plus 1 for chain definition
	iptables_rulespresent="$(iptables -t mangle -S ${SCRIPTNAME_DISPLAY} | wc -l)" # count rules in chain plus chain itself
	if [ "${iptables_rulespresent}" -lt "${iptables_rules_expected}" ]; then
		fail=1
	fi
	if [ "${qdisc}" = "2" ]; then
		iptables_rulespresent="$(iptables -t mangle -S ${SCRIPTNAME_DISPLAY}_DSCP | wc -l)" # count rules in DSCP chain plus chain itself
		if [ "${iptables_rulespresent}" -lt "13" ]; then
			fail=1
		fi
		iptables_rules_defined="$(echo "${appdb_rules}" | sed 's/</\n/g' | /bin/grep -vc "^$")"
		iptables_rules_expected=$((iptables_rules_defined*2+1)) # 1 set and 1 return rule per user rule, plus 1 for chain definition
		iptables_rulespresent="$(iptables -t mangle -S ${SCRIPTNAME_DISPLAY}_AppDB | wc -l)" # count rules in AppDB chain plus chain itself
		if [ "${iptables_rulespresent}" -lt "${iptables_rules_expected}" ]; then
			fail=1
		fi
	fi
	return ${fail}
} # validate_iptables_rules

write_iptables_rules() {
	# loop through iptables rules and write an iptables command to a temporary file for later execution
	local OLDIFS
	local localip remoteip proto lport rport mark class
	true > "/tmp/${SCRIPTNAME}_iprules"
	OLDIFS="${IFS}"		# Save existing field separator
	IFS=">"				# Set custom field separator to match rule format
	# read the rules, 1 per line and break into separate fields
	echo "${iptables_rules}" | sed 's/</\n/g' | while read -r localip remoteip proto lport rport mark class
	do
		# Ensure at least one criteria field is populated
		if [ -n "${localip}${remoteip}${proto}${lport}${rport}${mark}" ]; then
			# Process the rule and the stdout containing the resulting rule gets saved to the temporary script file
			parse_iptablerule "${localip}" "${remoteip}" "${proto}" "${lport}" "${rport}" "${mark}" "${class}" >> "/tmp/${SCRIPTNAME}_iprules" 2>/dev/null
		fi
	done
	IFS="${OLDIFS}"		# Restore saved field separator
} # write_iptables_rules

write_appdb_rules() {
	# Write the user appdb rules to the existing tcrules file created during write_appdb_static_rules()
	local OLDIFS
	local mark class
	# Save the current filter rules once to avoid repeated calls in parse_appdb_rule() to determine existing prios
	"${TC}" filter show dev "${tclan}" parent 1: > "/tmp/${SCRIPTNAME}_tmp_tcfilterdown"
	"${TC}" filter show dev "${tcwan}" parent 1: > "/tmp/${SCRIPTNAME}_tmp_tcfilterup"

	# loop through appdb rules and write a tc command to a temporary script file
	OLDIFS="${IFS}"		# Save existing field separator
	IFS=">"				# Set custom field separator to match rule format

	# read the rules, 1 per line and break into separate fields
	echo "${appdb_rules}" | sed 's/</\n/g' | while read -r mark class
	do
		# Ensure the appdb mark is populated
		if [ -n "${mark}" ]; then
			case "${qdisc}" in
			2) parse_appdb_rule_cake "${mark}" "${class}" >> "/tmp/${SCRIPTNAME}_iprules" 2>/dev/null
			;;
			*) parse_appdb_rule "${mark}" "${class}" >> "/tmp/${SCRIPTNAME}_tcrules" 2>/dev/null
			;;
			esac
		fi
	done
	IFS="${OLDIFS}"		# Restore old field separator
} # write_appdb_rules

get_fq_quantum() {
	local BANDWIDTH
	BANDWIDTH="${1}"

	if [ "${BANDWIDTH}" -lt "51200" ]; then
		printf "quantum 300\n"
	fi
} # get_fq_quantum

get_fq_target() {
	# Adapted from sqm-scripts adapt_target_to_slow_link() and adapt_interval_to_slow_link().
	# https://github.com/tohojo/sqm-scripts/blob/master/src/functions.sh
	local BANDWIDTH
	local TARGET INTERVAL
	BANDWIDTH="${1}"

	# for ATM the worst case expansion including overhead seems to be 33 cells of 53 bytes each
	# MAX DELAY = 1000 * 1000 * 33 * 53 * 8 / 1000  max delay in microseconds at 1kbps
	TARGET=$(/usr/bin/awk -vBANDWIDTH="${BANDWIDTH}" 'BEGIN { print int( 1000 * 1000 * 33 * 53 * 8 / 1000 / BANDWIDTH ) }')
	if [ "${TARGET}" -gt "5000" ]; then
		# Increase interval by the same amount that target got increased
		INTERVAL=$(( (100 - 5) * 1000 + TARGET ))
		printf "target %sus interval %sus\n" "${TARGET}" "${INTERVAL}"
	fi
} # get_fq_target

check_nvram() {
	case ${qdisc} in
	2)  # CAKE
		if [ "$(nvram get runner_disable_force)" != "1" ]; then
			nvram set runner_disable_force=1
			nvram set runner_disable=1
			nvram commit
			runner disable
			fc config --hw-accel 0 2>/dev/null
		fi
		if [ "$(nvram get fc_disable_force)" != "1" ]; then
			nvram set fc_disable_force=1
			nvram set fc_disable=1
			nvram commit
			fc disable
			fc flush
		fi
		;;
	*)	# fq_codel
		if [ "$(nvram get runner_disable_force)" = "1" ]; then
			nvram unset runner_disable_force
			nvram set runner_disable=0
			nvram commit
			runner enable
			fc config --hw-accel 1 2>/dev/null
			archerctl sysport_tm disable 2>/dev/null
		fi
		if [ "$(nvram get fc_disable_force)" = "1" ]; then
			nvram unset fc_disable_force
			nvram set fc_disable=0
			nvram commit
			fc enable
			fc flush
		fi
		;;
	esac
}

write_custom_qdisc() {
	local i
	case ${qdisc} in
	1)	# fq_codel
		check_nvram
		if [ "$(${TC} qdisc show dev ${tclan} parent 1: | grep -c fq_codel)" -lt "9" ]; then
			{
				printf "qdisc replace dev %s parent 1:2 handle 102: fq_codel limit 1000 noecn\n" "${tclan}"
				printf "qdisc replace dev %s parent 1:2 handle 102: fq_codel limit 1000 noecn\n" "${tcwan}"
				for i in 0 1 2 3 4 5 6 7
				do
					printf "qdisc replace dev %s parent 1:1%s handle 11%s: fq_codel %s limit 1000 %s\n" "${tclan}" "${i}" "${i}" "$(get_fq_quantum "${DownCeil}")" "$(get_fq_target "${DownCeil}")"
					printf "qdisc replace dev %s parent 1:1%s handle 11%s: fq_codel %s limit 1000 %s noecn\n" "${tcwan}" "${i}" "${i}" "$(get_fq_quantum "${UpCeil}")" "$(get_fq_target "${UpCeil}")"
				done
			} >> "/tmp/${SCRIPTNAME}_tcrules" 2>/dev/null
		fi
		;;
	2)  # CAKE
		check_nvram
		if [ "$(${TC} qdisc show dev ${tclan} parent 1:1 | grep -c cake)" -lt "1" ]; then
			{
				# Download
				printf "qdisc del dev %s root\n" "${tclan}"
				printf "qdisc add dev %s root handle 1: htb default 1\n" "${tclan}"
				printf "class add dev %s parent 1: classid 1:2 htb prio 0 rate 10Gbit ceil 10Gbit quantum 200000\n" "${tclan}"
				printf "filter add dev %s parent 1: protocol all prio 1 u32 match mark 0x0000 0xc0000000 flowid 1:2\n" "${tclan}"
				printf "class add dev %s parent 1: classid 1:1 htb prio 0 rate 10Gbit ceil 10Gbit quantum 200000\n" "${tclan}"
				printf "qdisc add dev %s parent 1:1 handle 110: cake bandwidth %skbit diffserv4 dual-dsthost ingress %s\n"  "${tclan}" "${DownCeil}" "$(get_overhead)"
				# Upload
				printf "qdisc del dev %s root\n" "${tcwan}"
				printf "qdisc add dev %s root handle 120: cake bandwidth %skbit diffserv4 dual-srchost nat %s\n" "${tcwan}" "${UpCeil}" "$(get_overhead)"
			} >> "/tmp/${SCRIPTNAME}_tcrules" 2>/dev/null
		fi
		;;
	esac
} # write_custom_qdisc

check_qos_tc() {
	# Check the status of the existing tc class and filter setup by stock Adaptive QoS before custom settings applied.
	# Only br0 interface is checked since we have not yet identified the tcwan interface name yet.
	dlclasscnt="$("${TC}" class show dev br0 parent 1: | /bin/grep -c "parent")" # should be 8
	dlfiltercnt="$("${TC}" filter show dev br0 parent 1: | /bin/grep -cE "flowid 1:1[0-7] *$")" # should be 39 or 40
	dlqdisccnt="$("${TC}" qdisc show dev br0 | /bin/grep -c " parent 1:1[0-7] ")" # should be 8
	# Check class count, filter count, qdisc count, and tcwan interface name defined with an htb qdisc
	if [ "${dlclasscnt}" -lt "8" ] || [ "${dlfiltercnt}" -lt "39" ] || [ "${dlqdisccnt}" -lt "8" ] || [ -z "$("${TC}" qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')" ]; then
		if [ "${qdisc}" = "2" ]; then
			# CAKE might already be active, so Adaptive QoS tc structures may not be present
			dlqdisccnt="$("${TC}" qdisc show dev br0 | /bin/grep -c " cake ")" # should be 1
			if [ "${dlqdisccnt}" -eq 1 ]; then
				return 1
			fi
		else
			return 0
		fi
	else
		return 1
	fi
} # check_qos_tc

validate_tc_rules() {
	# Check the existing tc filter rules against the user configuration. If any rule missing, force creation of all rules
	# Must run after set_tc_variables() to ensure flowid can be determined
	local OLDIFS filtermissing
	local mark class flowid
	{
		# print a list of existing filters in the format of an appdb rule for easy comparison. Write to tmp file
		"${TC}" filter show dev "${tclan}" parent 1: | sed -nE '/flowid/ { N; s/\n//g; s/.*flowid (1:1[0-7]).*mark 0x[48]0([0-9a-fA-F]{6}).*/<\2>\1/p }'
		"${TC}" filter show dev "${tcwan}" parent 1: | sed -nE '/flowid/ { N; s/\n//g; s/.*flowid (1:1[0-7]).*mark 0x[48]0([0-9a-fA-F]{6}).*/<\2>\1/p }'
	} > "/tmp/${SCRIPTNAME}_checktcrules" 2>/dev/null
	OLDIFS="${IFS}"
	IFS=">"
	filtermissing="0"
	while read -r mark class
	do
		if [ -n "${mark}" ]; then
			flowid="$(get_flowid "${class}")"
			mark="$(echo "${mark}" | sed 's/\*/0/g')"
			if [ "$(/bin/grep -ic "<${mark}>${flowid}" "/tmp/${SCRIPTNAME}_checktcrules")" -lt "2" ]; then
				filtermissing="$((filtermissing+1))"
				break		# stop checking after the first missing rule is identified
			fi
		fi
	done <<EOF
$(echo "${appdb_rules}" | sed 's/</\n/g')
EOF
	IFS="${OLDIFS}"
	if [ "${filtermissing}" -gt "0" ]; then
		# reapply tc rules
		return 1
	else
		rm "/tmp/${SCRIPTNAME}_checktcrules" 2>/dev/null
		return 0
	fi
} # validate_tc_rules

schedule_check_job() {
	# Schedule check for 5 minutes after startup to ensure no qos tc resets
	cru a "${SCRIPTNAME}"_5min "$(/bin/date -D '%s' +'%M %H %d %m %a' -d $(($(/bin/date +%s)+300))) ${SCRIPTPATH} -check"
} # schedule_check_job

get_cake_stats(){
	local wanif refresh
	refresh="$(am_settings_get flexqos_refresh)"
	refresh="${refresh:=3}"  # default to 3 seconds if unset
	wanif="$(tc qdisc ls | grep -v br0 | grep cake | cut -d' ' -f5)"
	while true; do
		[ -z "$(nvram get login_timestamp)" ] && break
		STATS_TIME="$(/bin/date +%s)"
		STATS_UPLOAD="$(tc -s -j qdisc show dev ${wanif} root 2>/dev/null)"
		STATS_DOWNLOAD="$(tc -s -j qdisc show dev br0 parent 1:1 2>/dev/null)"
		[ -z "$STATS_UPLOAD" ] && STATS_UPLOAD='[]'
		[ -z "$STATS_DOWNLOAD" ] && STATS_DOWNLOAD='[]'
		printf "var tcdata_wan_array=%s;\nvar tcdata_lan_array=%s;\nvar cake_statstime=%d;\n<%% bwdpi_conntrack(); %%>;\n" "$STATS_UPLOAD" "$STATS_DOWNLOAD" "$STATS_TIME" > /www/ext/${SCRIPTNAME}/ajax_gettcdata.asp
		sleep ${refresh}
	done &
}

startup() {
	local sleepdelay
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "1" ]; then
		logmsg "Adaptive QoS is not enabled. Skipping ${SCRIPTNAME_DISPLAY} startup."
		return 1
	fi # adaptive qos not enabled

	if [ "${qdisc}" = "2" ] && ! nvram get rc_support | tr ' ' '\n' | grep -q "^cake$"; then
		logmsg "CAKE is not available in this firmware version. Reverting to fq_codel qdisc."
		qdisc=1
	fi

	Check_Lock
	install_webui mount
	generate_bwdpi_arrays
	get_config

	# Check if iptables rules present
		# htb+fq_codel: compare existing rules in FlexQoS chain to settings
		# cake: compare existing rules in FlexQoS chain to settings; check for full FlexQoS_DSCP chain populated; check for FlexQoS_AppDB chain populated
	[ -f "/tmp/${SCRIPTNAME}_iprules" ] && rm "/tmp/${SCRIPTNAME}_iprules"
	if ! validate_iptables_rules; then
		iptables_static_rules 2>&1 | logger -t "${SCRIPTNAME_DISPLAY}"
		write_iptables_rules
		[ "${qdisc}" = "2" ] && write_appdb_rules
		if [ -s "/tmp/${SCRIPTNAME}_iprules" ]; then
			logmsg "Applying iptables custom rules"
			. "/tmp/${SCRIPTNAME}_iprules" 2>&1 | logger -t "${SCRIPTNAME_DISPLAY}"
			if [ "$(am_settings_get "${SCRIPTNAME}"_conntrack)" != "0" ]; then
				# Flush conntrack table so that existing connections will be processed by new iptables rules
				logmsg "Flushing conntrack table"
				/usr/sbin/conntrack -F conntrack >/dev/null 2>&1
			fi
		fi
	else
		logmsg "iptables rules already present"
	fi

	cru d "${SCRIPTNAME}"_5min 2>/dev/null

	# Wait for QoS to finish starting up
		# is it starting from scratch ?  Count classes, qdiscs and filters
		# is it a check after a successful start ?
			# if htb+fq_codel, count classes, qdiscs and filters again.
			# if cake, check for 2 cake qdiscs and continue
	sleepdelay=0
	while check_qos_tc;
	do
		[ "${sleepdelay}" = "0" ] && logmsg "TC Modification Delayed Start"
		sleep 10s
		if [ "${sleepdelay}" -ge "180" ]; then
			logmsg "QoS state: Classes=${dlclasscnt} | Filters=${dlfiltercnt} | qdiscs=${dlqdisccnt}"
			if [ ! -f "/tmp/${SCRIPTNAME}_restartonce" ]; then
				touch "/tmp/${SCRIPTNAME}_restartonce"
				logmsg "TC Modification Delay reached maximum 180 seconds. Restarting QoS."
				service "restart_qos;restart_firewall"
			else
				logmsg "TC Modification Delay reached maximum 180 seconds again. Canceling startup!"
				rm "/tmp/${SCRIPTNAME}_restartonce" 2>/dev/null
			fi
			return 1
		else
			sleepdelay=$((sleepdelay+10))
		fi
	done
	[ "${sleepdelay}" -gt "0" ] && logmsg "TC Modification delayed for ${sleepdelay} seconds"
	rm "/tmp/${SCRIPTNAME}_restartonce" 2>/dev/null

	set_tc_variables

	[ -f "/tmp/${SCRIPTNAME}_tcrules" ] && rm "/tmp/${SCRIPTNAME}_tcrules"

	# Update qdisc if not present (fq_codel or cake)
	# Update classes (htb+fq_codel)
	# Update appdb filter rules (htb/fq_codel)
	write_custom_qdisc

	if [ "${qdisc}" != "2" ]; then
		# if TC modifcations have not been applied then run modification script
		if ! validate_tc_rules; then
				write_appdb_static_rules
				write_appdb_rules
				write_custom_rates
		else
			logmsg "No TC modifications necessary"
		fi
	fi
	if [ -s "/tmp/${SCRIPTNAME}_tcrules" ]; then
		logmsg "Applying AppDB rules and TC rates"
		if ! "${TC}" -force -batch "/tmp/${SCRIPTNAME}_tcrules" >"/tmp/${SCRIPTNAME}_tcrules.log" 2>&1; then
			cp -f "/tmp/${SCRIPTNAME}_tcrules" "/tmp/${SCRIPTNAME}_tcrules.err"
			logmsg "ERROR! Check /tmp/${SCRIPTNAME}_tcrules.log"
		else
			rm "/tmp/${SCRIPTNAME}_tmp_tcfilterdown" "/tmp/${SCRIPTNAME}_tmp_tcfilterup" "/tmp/${SCRIPTNAME}_tcrules.log" "/tmp/${SCRIPTNAME}_checktcrules" "/tmp/${SCRIPTNAME}_tcrules.err" 2>/dev/null
			schedule_check_job
		fi
	fi
} # startup

show_help() {
	scriptinfo
	Red "You have entered an invalid command"
	cat <<EOF

Available commands:

  ${SCRIPTNAME} -about              explains functionality
  ${SCRIPTNAME} -appdb string       search appdb for application marks
  ${SCRIPTNAME} -update             checks for updates
  ${SCRIPTNAME} -restart            restart QoS and Firewall
  ${SCRIPTNAME} -install            install   script
  ${SCRIPTNAME} -uninstall          uninstall script & delete from disk
  ${SCRIPTNAME} -enable             enable    script
  ${SCRIPTNAME} -disable            disable   script but do not delete from disk
  ${SCRIPTNAME} -backup             backup user settings
  ${SCRIPTNAME} -debug              print debug info
  ${SCRIPTNAME} -develop            switch to development channel
  ${SCRIPTNAME} -stable             switch to stable channel
  ${SCRIPTNAME} -menu               interactive main menu

EOF
	webconfigpage
} # show_help

generate_bwdpi_arrays() {
	# generate if not exist, plus after wrs restart (signature update)
	# generate if signature rule file is newer than js file
	# generate if js file is smaller than source file (source not present yet during boot)
	# prepend wc variables with zero in case file doesn't exist, to avoid bad number error
	if [ ! -f "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js" ] || \
		[ "$(/bin/date -r /jffs/signature/rule.trf +%s)" -gt "$(/bin/date -r "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js" +%s)" ] || \
		[ "${1}" = "force" ] || \
		[ "0$(wc -c < "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js")" -lt "0$(wc -c 2>/dev/null < /tmp/bwdpi/bwdpi.app.db)" ]; then
	{
		printf "var catdb_mark_array = [ \"000000\""
		awk -F, '{ printf(", \"%02X****\"",$1) }' /tmp/bwdpi/bwdpi.cat.db 2>/dev/null
		awk -F, '{ printf(", \"%02X%04X\"",$1,$2) }' /tmp/bwdpi/bwdpi.app.db 2>/dev/null
		printf ", \"\" ];"
		printf "var catdb_label_array = [ \"Untracked\""
		awk -F, '{ printf(", \"%s (%02X)\"",$2, $1) }' /tmp/bwdpi/bwdpi.cat.db 2>/dev/null
		awk -F, '{ printf(", \"%s\"",$4) }' /tmp/bwdpi/bwdpi.app.db 2>/dev/null
		printf ", \"\" ];"
	} > "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js"
	fi
}

PressEnter(){
	[ "${mode}" = "interactive" ] || return
	printf "\n"
	while true; do
		printf "Press enter to continue..."
		read -r "key"
		case "${key}" in
			*)
				break
			;;
		esac
	done
	return 0
}

Kill_Lock() {
	if [ -f "/tmp/${SCRIPTNAME}.lock" ] && [ -d "/proc/$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock")" ]; then
		logmsg "[*] Killing Delayed Process (pid=$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock"))"
		logmsg "[*] $(ps | awk -v pid="$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock")" '$1 == pid')"
		kill "$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock")"
	fi
	rm -rf "/tmp/${SCRIPTNAME}.lock"
} # Kill_Lock

Check_Lock() {
	if [ -f "/tmp/${SCRIPTNAME}.lock" ] && [ -d "/proc/$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock")" ] && [ "$(sed -n '1p' "/tmp/${SCRIPTNAME}.lock")" != "$$" ]; then
		Kill_Lock
	fi
	printf "%s\n" "$$" > "/tmp/${SCRIPTNAME}.lock"
	lock="true"
} # Check_Lock

get_wan_setting() {
	local varname varval
	varname="${1}"
	prefixes="wan0_ wan1_"

	if [ "$(nvram get wans_mode)" = "lb" ] ; then
		for prefix in $prefixes; do
			state="$(nvram get "${prefix}"state_t)"
			sbstate="$(nvram get "${prefix}"sbstate_t)"
			auxstate="$(nvram get "${prefix}"auxstate_t)"

			# is_wan_connect()
			[ "${state}" = "2" ] || continue
			[ "${sbstate}" = "0" ] || continue
			[ "${auxstate}" = "0" ] || [ "${auxstate}" = "2" ] || continue

			# get_wan_ifname()
			proto="$(nvram get "${prefix}"proto)"
			if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
				varval="$(nvram get "${prefix}"pppoe_"${varname}")"
			else
				varval="$(nvram get "${prefix}""${varname}")"
			fi
		done
	else
		for prefix in $prefixes; do
			primary="$(nvram get "${prefix}"primary)"
			[ "${primary}" = "1" ] && break
		done

		proto="$(nvram get "${prefix}"proto)"
		if [ "${proto}" = "pppoe" ] || [ "${proto}" = "pptp" ] || [ "${proto}" = "l2tp" ] ; then
			varval="$(nvram get "${prefix}"pppoe_"${varname}")"
		else
			varval="$(nvram get "${prefix}""${varname}")"
		fi
	fi
	printf "%s" "${varval}"
} # get_wan_setting

arg1="${1#-}"
if [ -z "${arg1}" ] || [ "${arg1}" = "menu" ] && ! /bin/grep -qE "${SCRIPTPATH} .* # ${SCRIPTNAME_DISPLAY}" /jffs/scripts/firewall-start; then
	arg1="install"
fi

wan="$(get_wan_setting 'ifname')"
WANMTU="$(get_wan_setting 'mtu')"
lan="$(nvram get lan_ifname)"
needrestart=0		# initialize variable used in prompt_restart()

case "${arg1}" in
	'start'|'check')
		logmsg "$0 (pid=$$) called in ${mode} mode with $# args: $*"
		startup
		;;
	'appdb')
		appdb "${2}"
		;;
	'install'|'enable')
		install "${2}"
		;;
	'uninstall')
		uninstall
		;;
	'disable')
		sed -i "/${SCRIPTNAME}/d" /jffs/scripts/firewall-start  2>/dev/null
		sed -i "/${SCRIPTNAME}/d" /jffs/scripts/service-event-end  2>/dev/null
		remove_webui
		needrestart=2
		;;
	'backup')
		backup create force
		;;
	'debug')
		debug
		;;
	'about')
		about
		;;
	update*)		# updatecheck, updatesilent, or plain update
		update "${arg1#update}"		# strip 'update' from arg1 to pass to update function
		;;
	'develop')
		if [ "$(am_settings_get "${SCRIPTNAME}_branch")" = "develop" ]; then
			printf "Already set to development branch.\n"
		else
			am_settings_set "${SCRIPTNAME}_branch" "develop"
			printf "Set to development branch. Triggering update...\n"
			exec "${0}" updatesilent
		fi
		;;
	'stable')
		if [ -z "$(am_settings_get "${SCRIPTNAME}_branch")" ]; then
			printf "Already set to stable branch.\n"
		else
			sed -i "/^${SCRIPTNAME}_branch /d" /jffs/addons/custom_settings.txt
			printf "Set to stable branch. Triggering update...\n"
			exec "${0}" updatesilent
		fi
		;;
	'menu'|'')
		menu
		;;
	'restart')
		needrestart=2
		;;
	'flushct')
		sed -i "/^${SCRIPTNAME}_conntrack /d" /jffs/addons/custom_settings.txt
		Green "Enabled conntrack flushing."
		;;
	'noflushct')
		am_settings_set "${SCRIPTNAME}_conntrack" "0"
		Yellow "Disabled conntrack flushing."
		;;
	stats)
		get_cake_stats
		;;
	*)
		show_help
		;;
esac

prompt_restart
if [ "${lock}" = "true" ]; then rm -rf "/tmp/${SCRIPTNAME}.lock"; fi
