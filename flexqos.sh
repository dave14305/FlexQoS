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
version=1.1.0
release=2020-12-13
# Forked from FreshJR_QOS v8.8, written by FreshJR07 https://github.com/FreshJR07/FreshJR_QOS
#
# Script Changes Unidentified traffic destination away from "Work-From-Home" into "Others"
# Script Changes HTTPS traffic destination away from "Net Control" into "Web Surfing"
# Script Changes Guaranteed Bandwidth per QoS category into logical percentages of upload and download.
# Script includes other default rules:
#   (Wifi Calling)  -  UDP traffic on remote ports 500 & 4500 moved into Work-From-Home
#   (Facetime)      -  UDP traffic on local  ports 16384 - 16415 moved into Work-From-Home
#   (Usenet)        -  TCP traffic on remote ports 119 & 563 moved into Downloads
#   (Gaming)        -  Gaming TCP traffic from remote ports 80 & 443 moved into Game Downloads.
#   (Snapchat)      -  Moved into Others
#   (Speedtest.net) -  Moved into Downloads
#   (Google Play)   -  Moved into Downloads
#   (Apple AppStore)-  Moved into Downloads
#   (Advertisement) -  Moved into Downloads
#   (VPN Fix)       -  Router VPN Client upload traffic moved into Downloads instead of whitelisted
#   (Gaming Manual) -  Unidentified traffic for specified devices, not originating from ports 80/443, moved into "Gaming"
#
#  Gaming traffic originating from ports 80 & 443 is primarily downloads & patches (some lobby/login protocols mixed within)
#  Manually configurable rule will take untracked traffic, not originating from 80/443, for specified devices and place it into Gaming
#  Use of this gaming rule REQUIRES devices to have a continuous static ip assignment && this range needs to be defined in the script
# License
#  FlexQoS is free to use under the GNU General Public License, version 3 (GPL-3.0).
#  https://opensource.org/licenses/GPL-3.0

# initialize Merlin Addon API helper functions
. /usr/sbin/helper.sh

# -x is a flag to show verbose script output for debugging purposes only
if [ "$1" = "-x" ]; then
	shift
	set -x
fi

# Global variables
SCRIPTNAME_DISPLAY="FlexQoS"
SCRIPTNAME="$(echo $SCRIPTNAME_DISPLAY | tr A-Z a-z)"
GIT_REPO="https://raw.githubusercontent.com/dave14305/${SCRIPTNAME_DISPLAY}"
if [ "$(am_settings_get "${SCRIPTNAME}_branch")" != "develop" ]; then
	GIT_BRANCH="master"
else
	GIT_BRANCH="$(am_settings_get "${SCRIPTNAME}_branch")"
fi
GIT_URL="${GIT_REPO}/${GIT_BRANCH}"

ADDON_DIR="/jffs/addons/${SCRIPTNAME}"
WEBUIPATH="${ADDON_DIR}/${SCRIPTNAME}.asp"
SCRIPTPATH="${ADDON_DIR}/${SCRIPTNAME}.sh"
IPv6_enabled="$(nvram get ipv6_service)"

# Update version number in custom_settings.txt for reading in WebUI
if [ "$(am_settings_get flexqos_ver)" != "$version" ]; then
	am_settings_set flexqos_ver "$version"
fi

# If Merlin fq_codel patch is active, use original tc binary for passing commands
# Will be obsolete in 386.1 and higher.
if [ -e "/usr/sbin/realtc" ]; then
	tc="/usr/sbin/realtc"
else
	tc="/usr/sbin/tc"
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
Net_mark_down="0x8009ffff"
Work_mark_down="0x8006ffff"
Gaming_mark_down="0x8008ffff"
Others_mark_down="0x800affff"
Web_mark_down="0x8018ffff"
Streaming_mark_down="0x8004ffff"
Downloads_mark_down="0x8003ffff"
Learn_mark_down="0x803fffff"

Net_mark_up="0x4009ffff"
Work_mark_up="0x4006ffff"
Gaming_mark_up="0x4008ffff"
Others_mark_up="0x400affff"
Web_mark_up="0x4018ffff"
Streaming_mark_up="0x4004ffff"
Downloads_mark_up="0x4003ffff"
Learn_mark_up="0x403fffff"

logmsg() {
	if [ "$#" = "0" ]; then
		return
	fi
	logger -t "$SCRIPTNAME_DISPLAY" "$*"
} # logmsg

Red() {
	printf -- '\033[1;31m%s\033[0m\n' "$1"
}

Green() {
	printf -- '\033[1;32m%s\033[0m\n' "$1"
}

Blue() {
	printf -- '\033[1;36m%s\033[0m\n' "$1"
}

Yellow() {
	printf -- '\033[1;33m%s\033[0m\n' "$1"
}

iptables_static_rules() {
	printf "Applying iptables static rules\n"
	# Reference for VPN Fix origin: https://www.snbforums.com/threads/36836/page-78#post-412034
	# Partially fixed in https://github.com/RMerl/asuswrt-merlin.ng/commit/f7d6478df7b934c9540fa9740ad71d49d84a1756
	iptables -t mangle -D OUTPUT -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -t mangle -A OUTPUT -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff
	iptables -t mangle -D OUTPUT -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -t mangle -A OUTPUT -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff
	iptables -t mangle -N "$SCRIPTNAME_DISPLAY" 2>/dev/null
	iptables -t mangle -A POSTROUTING -j "$SCRIPTNAME_DISPLAY"
	if [ "$IPv6_enabled" != "disabled" ]; then
		printf "Applying ip6tables static rules\n"
		ip6tables -t mangle -D OUTPUT -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -t mangle -A OUTPUT -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff
		ip6tables -t mangle -D OUTPUT -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -t mangle -A OUTPUT -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}/0x3fffff
		ip6tables -t mangle -N "$SCRIPTNAME_DISPLAY" 2>/dev/null
		ip6tables -t mangle -A POSTROUTING -j "$SCRIPTNAME_DISPLAY"
	fi
}

write_appdb_static_rules() {
	# These rules define the flowid (priority level) of the Class destinations selected by users in iptables rules.
	# Previous versions of the script were susceptible to the chosen Class being overridden by the users AppDB rules.
	# Adding these filters ensures the Class you select in iptables rules is strictly observed.
	# prio 5 is used because the first default filter rule (mark 0x80030000 0xc03f0000) is found at prio 6 as of this writing,
	# so we want these filters to always take precedence over the built-in filters.
	# File is overwritten (>) if it exists and later appended by write_appdb_rules() and write_custom_rates().
	{
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Net_mark_down" "$Net"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Net_mark_up" "$Net"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Work_mark_down" "$Work"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Work_mark_up" "$Work"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Gaming_mark_down" "$Gaming"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Gaming_mark_up" "$Gaming"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Others_mark_down" "$Others"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Others_mark_up" "$Others"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Web_mark_down" "$Web"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Web_mark_up" "$Web"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Streaming_mark_down" "$Streaming"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Streaming_mark_up" "$Streaming"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Downloads_mark_down" "$Downloads"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Downloads_mark_up" "$Downloads"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tclan" "$Learn_mark_down" "$Learn"
		printf "filter add dev %s protocol all prio 5 u32 match mark %s 0xc03fffff flowid %s\n" "$tcwan" "$Learn_mark_up" "$Learn"
	} > /tmp/${SCRIPTNAME}_tcrules
} # write_appdb_static_rules

write_custom_rates() {
	# For all 8 classes (0-7), write the tc commands needed to modify the bandwidth rates and related parameters
	# that get assigned in set_tc_variables().
	# File is appended (>>) because it is initially created in write_appdb_static_rules().
	{
		for i in 0 1 2 3 4 5 6 7
		do
			eval DownRate=\$DownRate$i
			eval DownCeil=\$DownCeil$i
			eval DownBurst=\$DownBurst$i
			eval DownCburst=\$DownCburst$i
			eval DownQuantum=\$DownQuantum$i
			printf "class change dev %s parent 1:1 classid 1:1%s htb %s prio %s rate %sKbit ceil %sKbit burst %sb cburst %sb quantum %s\n" \
					"br0" "$i" "$PARMS" "$i" "$DownRate" "$DownCeil" "$DownBurst" "$DownCburst" "$DownQuantum"
			eval UpRate=\$UpRate$i
			eval UpCeil=\$UpCeil$i
			eval UpBurst=\$UpBurst$i
			eval UpCburst=\$UpCburst$i
			eval UpQuantum=\$UpQuantum$i
			printf "class change dev %s parent 1:1 classid 1:1%s htb %s prio %s rate %sKbit ceil %sKbit burst %sb cburst %sb quantum %s\n" \
					"$tcwan" "$i" "$PARMS" "$i" "$UpRate" "$UpCeil" "$UpBurst" "$UpCburst" "$UpQuantum"
		done
	} >> /tmp/${SCRIPTNAME}_tcrules
} # write_custom_rates

set_tc_variables() {
	# Read various settings from the router and construct the variables needed to implement the custom rules.

	tclan="br0"
	# Determine the WAN interface name used by tc by finding the existing htb root qdisc that is NOT br0.
	# If not found, check the dev_wan file created by Adaptive QoS.
	# If still not determined, assume eth0 but something is probably wrong at this point.
	tcwan="$(${tc} qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')"
	if [ -z "$tcwan" ] && [ -s "/tmp/bwdpi/dev_wan" ]; then
		tcwan="$(/bin/grep -oE "eth[0-9]|usb[0-9]" /tmp/bwdpi/dev_wan)"
	fi
	if [ -z "$tcwan" ]; then
		tcwan="eth0"
	fi

	# Detect the default filter rule for Untracked traffic (Mark 000000) if it exists.
	# Newer 384 stock firmware dropped this rule, so Untracked traffic flows into the Work-From-Home priority by default.
	# First check for older ASUS default rule (0x80000000 0xc000ffff).
	# If not found, get the prio for the Work-From-Home Instant messengers category 00 (0x80000000 0xc03f0000) and subtract 1.
	undf_prio="$(${tc} filter show dev br0 | /bin/grep -i -m1 -B1 "0x80000000 0xc000ffff" | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
	if [ -z "$undf_prio" ]; then
		undf_prio="$(${tc} filter show dev br0 | /bin/grep -i -m1 -B1 "0x80000000 0xc03f0000" | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
		undf_prio="$((undf_prio-1))"
	fi

	# read priority order of QoS categories as set by user on the QoS page of the GUI
	flowid=0
	while read -r line;
	do
		if [ "${line:0:1}" = '[' ]; then
			flowid="${line:1:1}"
		fi
		case ${line} in
		'0')
			Work="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp1"
			eval "Cat${flowid}DownCeilPercent=$dcp1"
			eval "Cat${flowid}UpBandPercent=$urp1"
			eval "Cat${flowid}UpCeilPercent=$ucp1"
			;;
		'1')
			Downloads="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp7"
			eval "Cat${flowid}DownCeilPercent=$dcp7"
			eval "Cat${flowid}UpBandPercent=$urp7"
			eval "Cat${flowid}UpCeilPercent=$ucp7"
			;;
		'4')
			# Special handling for category 4 since it is duplicated between Streaming and Learn-From-Home.
			# We have to find the priority placement of Learn-From-Home versus Streaming in the QoS GUI to know
			# if the first time we encounter a 4 in the file if it is meant to be Streaming or Learn-From-Home.
			# The second time we encounter a 4, we know it is meant for the remaining option.
			if nvram get bwdpi_app_rulelist | /bin/grep -qE "<4,13(<.*)?<4<"; then
				# Learn-From-Home is higher priority than Streaming
				if [ -z "$Learn" ]; then
					Learn="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=$drp6"
					eval "Cat${flowid}DownCeilPercent=$dcp6"
					eval "Cat${flowid}UpBandPercent=$urp6"
					eval "Cat${flowid}UpCeilPercent=$ucp6"
				else
					Streaming="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=$drp5"
					eval "Cat${flowid}DownCeilPercent=$dcp5"
					eval "Cat${flowid}UpBandPercent=$urp5"
					eval "Cat${flowid}UpCeilPercent=$ucp5"
				fi
			else
				# Streaming is higher priority than Learn-From-Home
				if [ -z "$Streaming" ]; then
					Streaming="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=$drp5"
					eval "Cat${flowid}DownCeilPercent=$dcp5"
					eval "Cat${flowid}UpBandPercent=$urp5"
					eval "Cat${flowid}UpCeilPercent=$ucp5"
				else
					Learn="1:1${flowid}"
					eval "Cat${flowid}DownBandPercent=$drp6"
					eval "Cat${flowid}DownCeilPercent=$dcp6"
					eval "Cat${flowid}UpBandPercent=$urp6"
					eval "Cat${flowid}UpCeilPercent=$ucp6"
				fi
			fi  # Check Learn-From-Home and Streaming priority order
			;;
		'7')
			Others="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp3"
			eval "Cat${flowid}DownCeilPercent=$dcp3"
			eval "Cat${flowid}UpBandPercent=$urp3"
			eval "Cat${flowid}UpCeilPercent=$ucp3"
			;;
		'8')
			Gaming="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp2"
			eval "Cat${flowid}DownCeilPercent=$dcp2"
			eval "Cat${flowid}UpBandPercent=$urp2"
			eval "Cat${flowid}UpCeilPercent=$ucp2"
			;;
		'9')
			Net="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp0"
			eval "Cat${flowid}DownCeilPercent=$dcp0"
			eval "Cat${flowid}UpBandPercent=$urp0"
			eval "Cat${flowid}UpCeilPercent=$ucp0"
			;;
		'24')
			Web="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp4"
			eval "Cat${flowid}DownCeilPercent=$dcp4"
			eval "Cat${flowid}UpBandPercent=$urp4"
			eval "Cat${flowid}UpCeilPercent=$ucp4"
			;;
		'na')
			# This is how the old ASUS default category would appear, but this option will soon be deprecated
			# when all supported models are using the new QoS Categories.
			Learn="1:1${flowid}"
			eval "Cat${flowid}DownBandPercent=$drp6"
			eval "Cat${flowid}DownCeilPercent=$dcp6"
			eval "Cat${flowid}UpBandPercent=$urp6"
			eval "Cat${flowid}UpCeilPercent=$ucp6"
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
	if [ "$DownCeil" -gt "0" ] && [ "$UpCeil" -gt "0" ]; then
		# Automatic bandwidth mode incompatible with custom rates
		WANMTU="$(nvram get wan_mtu)"
		i=0
		while [ "$i" -lt "8" ]
		do
			eval "DownRate$i=\$((DownCeil\*Cat${i}DownBandPercent/100))"
			eval "UpRate$i=\$((UpCeil\*Cat${i}UpBandPercent/100))"
			eval "DownCeil$i=\$((DownCeil\*Cat${i}DownCeilPercent/100))"
			eval "UpCeil$i=\$((UpCeil\*Cat${i}UpCeilPercent/100))"
			downquantum=$((DownRate${i}*1000/8/10))
			# If the calculated quantum is less than the MTU, use MTU+14 as the quantum
			if [ "$downquantum" -lt "$((WANMTU+14))" ]; then
				downquantum="$((WANMTU+14))"
			fi
			upquantum=$((UpRate${i}*1000/8/10))
			if [ "$upquantum" -lt "$((WANMTU+14))" ]; then
				upquantum="$((WANMTU+14))"
			fi
			# If the calculated burst and cburst is less than ASUS' minimum value of 3200, use 3200
			# to avoid problems with child and leaf classes outside of FlexQoS scope that use 3200.
			# This calculation was reverse engineered from observing ASUS' rules
			downburst=$((DownRate${i}*1000/1280000*1600))
			if [ "$downburst" -lt "3200" ]; then
				downburst=3200
			fi
			downcburst=$((DownCeil${i}*1000/1280000*1600))
			if [ "$downcburst" -lt "3200" ]; then
				downcburst=3200
			fi
			upburst=$((UpRate${i}*1000/1280000*1600))
			if [ "$upburst" -lt "3200" ]; then
				upburst=3200
			fi
			upcburst=$((UpCeil${i}*1000/1280000*1600))
			if [ "$upcburst" -lt "3200" ]; then
				upcburst=3200
			fi
			eval "DownQuantum${i}=$downquantum"
			eval "UpQuantum${i}=$upquantum"
			eval "DownBurst${i}=$downburst"
			eval "DownCburst${i}=$downcburst"
			eval "UpBurst${i}=$upburst"
			eval "UpCburst${i}=$upcburst"
			i="$((i+1))"
		done

		OVERHEAD="$(nvram get qos_overhead)"
		if [ -n "$OVERHEAD" ] && [ "$OVERHEAD" -gt "0" ]; then
			ATM="$(nvram get qos_atm)"
			if [ "$ATM" = "1" ]; then
				PARMS="overhead $OVERHEAD linklayer atm"
			else
				PARMS="overhead $OVERHEAD linklayer ethernet"
			fi
		else
			PARMS=""
		fi
	fi # Auto Bandwidth check
} # set_tc_variables

appdb() {
	# Search TrendMicro appdb file for matches to user-specified string. Return up to 25 matches
	/bin/grep -m 25 -i "$1" /tmp/bwdpi/bwdpi.app.db | while read -r line; do
		echo "$line" | awk -F "," '{printf "  Application: %s\n         Mark: %02X%04X\nDefault Class: ", $4, $1, $2}'
		cat_decimal=$(echo "$line" | cut -f 1 -d "," )
		case "$cat_decimal" in
		'9'|'18'|'19'|'20')
			printf "Net Control"
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
			printf "Web"
			;;
		'4')
			printf "Streaming"
			;;
		'1'|'3'|'14')
			printf "Downloads"
			;;
		*)
			printf "Unknown"
			;;
		esac
		printf "\n\n"
	done
} # appdb

webconfigpage() {
	# Eye candy function that will construct a URL to display after install or upgrade so a user knows where to
	# find the webUI page. In most cases though, they will go to the Adaptive QoS tab and find the FlexQoS sub-tab anyway.
	urlpage="$(sed -nE "/$SCRIPTNAME_DISPLAY/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)"
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

	if echo "$urlpage" | grep -qE "user[0-9]+\.asp"; then
		printf "Advanced configuration available via:\n"
		Blue "  ${urlproto}://${urldomain}${urlport}/${urlpage}"
	fi
} # webconfigpage

scriptinfo() {
	# Version header used in interactive sessions
	[ "$mode" = "interactive" ] || return
	printf "\n"
	Green "$SCRIPTNAME_DISPLAY v${version} released ${release}"
	if [ "$GIT_BRANCH" != "master" ]; then
		Yellow " Development channel"
	fi
	printf "\n"
} # scriptinfo

debug() {
	[ -z "$(nvram get odmpid)" ] && RMODEL="$(nvram get productid)" || RMODEL="$(nvram get odmpid)"
	Green "[SPOILER=\"$SCRIPTNAME_DISPLAY Debug\"][CODE]"
	scriptinfo
	printf "Debug date    : %s\n" "$(date +'%Y-%m-%d %H:%M:%S%z')"
	printf "Router Model  : %s\n" "$RMODEL"
	printf "Firmware Ver  : %s_%s\n" "$(nvram get buildno)" "$(nvram get extendno)"
	printf "DPI/Sig Ver   : %s / %s\n" "$(nvram get bwdpi_dpi_ver)" "$(nvram get bwdpi_sig_ver)"
	get_config
	set_tc_variables

	printf "WAN iface     : %s\n" "$wan"
	printf "tc WAN iface  : %s\n" "$tcwan"
	printf "IPv6          : %s\n" "$IPv6_enabled"
	printf "Undf Prio     : %s\n" "$undf_prio"
	printf "Down Band     : %s\n" "$DownCeil"
	printf "Up Band       : %s\n" "$UpCeil"
	printf "***********\n"
	printf "Net Control   : %s\n" "$Net"
	printf "Work-From-Home: %s\n" "$Work"
	printf "Gaming        : %s\n" "$Gaming"
	printf "Others        : %s\n" "$Others"
	printf "Web Surfing   : %s\n" "$Web"
	printf "Streaming     : %s\n" "$Streaming"
	printf "File Downloads: %s\n" "$Downloads"
	printf "Game Downloads: %s\n" "$Learn"
	printf "***********\n"
	# Only print custom rates if Manual Bandwidth setting is enabled on QoS page
	if [ "$DownCeil" -gt "0" ] && [ "$UpCeil" -gt "0" ]; then
		printf "Downrates     : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$DownRate0" "$DownRate1" "$DownRate2" "$DownRate3" "$DownRate4" "$DownRate5" "$DownRate6" "$DownRate7"
		printf "Downceils     : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$DownCeil0" "$DownCeil1" "$DownCeil2" "$DownCeil3" "$DownCeil4" "$DownCeil5" "$DownCeil6" "$DownCeil7"
		printf "Downbursts    : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$DownBurst0" "$DownBurst1" "$DownBurst2" "$DownBurst3" "$DownBurst4" "$DownBurst5" "$DownBurst6" "$DownBurst7"
		printf "DownCbursts   : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$DownCburst0" "$DownCburst1" "$DownCburst2" "$DownCburst3" "$DownCburst4" "$DownCburst5" "$DownCburst6" "$DownCburst7"
		printf "DownQuantums  : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$DownQuantum0" "$DownQuantum1" "$DownQuantum2" "$DownQuantum3" "$DownQuantum4" "$DownQuantum5" "$DownQuantum6" "$DownQuantum7"
		printf "***********\n"
		printf "Uprates       : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$UpRate0" "$UpRate1" "$UpRate2" "$UpRate3" "$UpRate4" "$UpRate5" "$UpRate6" "$UpRate7"
		printf "Upceils       : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$UpCeil0" "$UpCeil1" "$UpCeil2" "$UpCeil3" "$UpCeil4" "$UpCeil5" "$UpCeil6" "$UpCeil7"
		printf "Upbursts      : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$UpBurst0" "$UpBurst1" "$UpBurst2" "$UpBurst3" "$UpBurst4" "$UpBurst5" "$UpBurst6" "$UpBurst7"
		printf "UpCbursts     : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$UpCburst0" "$UpCburst1" "$UpCburst2" "$UpCburst3" "$UpCburst4" "$UpCburst5" "$UpCburst6" "$UpCburst7"
		printf "UpQuantums    : %7s, %7s, %7s, %7s, %7s, %7s, %7s, %7s\n" "$UpQuantum0" "$UpQuantum1" "$UpQuantum2" "$UpQuantum3" "$UpQuantum4" "$UpQuantum5" "$UpQuantum6" "$UpQuantum7"
		printf "***********\n"
	else
		printf "Custom rates disabled with Automatic Bandwidth mode!\n"
		printf "***********\n"
	fi
	printf "iptables settings: %s\n" "$(am_settings_get flexqos_iptables)"
	write_iptables_rules
	# Remove superfluous commands from the output in order to focus on the parsed details
	/bin/sed -E "/^ip[6]?tables -t mangle -D $SCRIPTNAME_DISPLAY/d; s/ip[6]?tables -t mangle -A $SCRIPTNAME_DISPLAY //g; s/[[:space:]]{2,}/ /g" /tmp/${SCRIPTNAME}_iprules
	printf "***********\n"
	printf "appdb rules: %s\n" "$(am_settings_get flexqos_appdb)"
	true > /tmp/${SCRIPTNAME}_tcrules
	write_appdb_rules
	cat /tmp/${SCRIPTNAME}_tcrules
	Green "[/CODE][/SPOILER]"
	# Since these tmp files aren't being used to apply rules, we delete them to avoid confusion about the last known ruleset
	rm /tmp/${SCRIPTNAME}_iprules /tmp/${SCRIPTNAME}_tcrules
	printf "\n"
	Yellow "Copy the text from [SPOILER] to [/SPOILER] and paste into a forum post at snbforums.com"
} # debug

get_flowid() {
	# Map class destination field from webui settings to the established class/flowid based on user priorities
	# flowid will be one of 1:10 - 1:17, depending on the user priority sequencing in the QoS GUI
	# Input: numeric class destination from iptables rule
	case "$1" in
		0)	flowid="$Net" ;;
		1)	flowid="$Gaming" ;;
		2)	flowid="$Streaming" ;;
		3)	flowid="$Work" ;;
		4)	flowid="$Web" ;;
		5)	flowid="$Downloads" ;;
		6)	flowid="$Others" ;;
		7)	flowid="$Learn" ;;
		# return empty if destination missing
		*)	flowid="" ;;
	esac
	printf "%s\n" "$flowid"
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

parse_appdb_rule() {
	# Process an appdb custom rule into the appropriate tc filter syntax
	# Input: $1 = Mark from appdb rule XXYYYY XX=Category(hex) YYYY=ID(hex or ****)
	#        $2 = Class destination
	# Output: stdout is written directly to the /tmp/flexqos_appdb_rules file via redirect in write_appdb_rules(),
	#         so don't add unnecessary output in this function.

	# Only process if Mark is a valid format
	if echo "$1" | Is_Valid_Mark; then
		# Extract category and appid from mark
		cat="${1:0:2}"
		id="${1:2:4}"
		# check if wildcard mark
		if [ "$id" = "****" ]; then
			# Replace asterisks with zeros and use category mask
			# This mark and mask
			DOWN_mark="0x80${1//\*/0} 0xc03f0000"
			UP_mark="0x40${1//\*/0} 0xc03f0000"
		elif [ "$1" = "000000" ]; then
			# unidentified traffic needs a special mask
			DOWN_mark="0x80${1} 0xc000ffff"
			UP_mark="0x40${1} 0xc000ffff"
		else
			# specific application mark
			DOWN_mark="0x80${1} 0xc03fffff"
			UP_mark="0x40${1} 0xc03fffff"
		fi

		# get destination class
		flowid="$(get_flowid "$2")"

		# To override the default tc filters with our custom filter rules, we need to insert our rules
		# at a higher priority (lower number) than the built-in filter for each category.
		if [ "$1" = "000000" ]; then
			# special mask for unidentified traffic
			currmask="0xc000ffff"
		else
			currmask="0xc03f0000"
		fi
		# search the tc filter temp file we made in write_appdb_rules() for the existing priority of the
		# category we are going to override with a custom appdb filter rule.
		# e.g. If we are going to make a rule for appdb mark 1400C5, we need to find the current priority of category 14.
		prio="$(/bin/grep -i -m 1 -B1 "0x80${cat}0000 ${currmask}" /tmp/${SCRIPTNAME}_tmp_tcfilterdown | sed -nE 's/.* pref ([0-9]+) .*/\1/p')"
		currprio="$prio"

		# If there is no existing filter for the category, use the undf_prio defined in set_tc_variables().
		# This is usually only necessary for Untracked traffic (mark 000000).
		# Otherwise, take the current priority and subtract 1 so that our rule will be processed earlier than the default rule.
		if [ -z "$prio" ]; then
			prio="$undf_prio"
		else
			prio="$((prio-1))"
		fi

		# Build and echo the tc filter commands based on the possible actions required:
		# 1. Change an existing filter to point to a new flowid (mostly relevant for wildcard appdb rules).
		# 2. Insert a new filter at a higher priority than the existing filter that would otherwise match this mark.
		if [ "$id" = "****" -o "$1" = "000000" ] && [ -n "$currprio" ]; then
			# change existing rule for wildcard marks and Untracked mark only if current priority already determined.
			# Need to get handle of existing filter for proper tc filter change syntax.
			currhandledown="$(/bin/grep -i -m 1 -B1 "0x80${cat}0000 ${currmask}" /tmp/${SCRIPTNAME}_tmp_tcfilterdown | sed -nE 's/.* fh ([0-9a-f:]+) .*/\1/p')"
			currhandleup="$(/bin/grep -i -m 1 -B1 "0x40${cat}0000 ${currmask}" /tmp/${SCRIPTNAME}_tmp_tcfilterup | sed -nE 's/.* fh ([0-9a-f:]+) .*/\1/p')"
			printf "filter change dev %s prio %s protocol all handle %s u32 flowid %s\n" "$tclan" "$currprio" "$currhandledown" "$flowid"
			printf "filter change dev %s prio %s protocol all handle %s u32 flowid %s\n" "$tcwan" "$currprio" "$currhandleup" "$flowid"
		else
			# add new rule for individual app one priority level higher (-1)
			printf "filter add dev %s protocol all prio %s u32 match mark %s flowid %s\n" "$tclan" "$prio" "$DOWN_mark" "$flowid"
			printf "filter add dev %s protocol all prio %s u32 match mark %s flowid %s\n" "$tcwan" "$prio" "$UP_mark" "$flowid"
		fi
	fi # Is_Valid_Mark
} # parse_appdb_rule

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

	# local IP
	# Check for acceptable IP format
	if echo "$1" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		DOWN_Lip="${1//[^!]*/} -d ${1//!/}"
		UP_Lip="${1//[^!]*/} -s ${1//!/}"
	else
		DOWN_Lip=""
		UP_Lip=""
	fi

	# remote IP
	# Check for acceptable IP format
	if echo "$2" | Is_Valid_CIDR; then
		# print ! (if present) and remaining CIDR
		DOWN_Rip="${2//[^!]*/} -s ${2//!/}"
		UP_Rip="${2//[^!]*/} -d ${2//!/}"
	else
		DOWN_Rip=""
		UP_Rip=""
	fi

	# protocol (required when port specified)
	if [ "$3" = "tcp" ] || [ "$3" = "udp" ]; then
		# print protocol directly
		PROTO="-p ${3}"
	elif [ "${#4}" -gt "1" ] || [ "${#5}" -gt "1" ]; then
		# proto=both & ports are defined
		PROTO="-p both"		# "both" gets replaced with individual tcp & udp statements later on
	else
		# neither proto nor ports defined
		PROTO=""
	fi

	# local port
	if echo "$4" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		DOWN_Lport="-m multiport ${4//[^!]*/} --dports ${4//!/}"
		UP_Lport="-m multiport ${4//[^!]*/} --sports ${4//!/}"
	else
		DOWN_Lport=""
		UP_Lport=""
	fi

	#remote port
	if echo "$5" | Is_Valid_Port; then
		# Use multiport to specify any port specification:
		# single port, multiple ports, port range
		DOWN_Rport="-m multiport ${5//[^!]*/} --sports ${5//!/}"
		UP_Rport="-m multiport ${5//[^!]*/} --dports ${5//!/}"
	else
		DOWN_Rport=""
		UP_Rport=""
	fi

	# mark
	if echo "$6" | Is_Valid_Mark; then
		tmpMark="$6"		# Use a tmp variable since we have to manipulate the contents for ! and ****
		DOWN_mark="-m mark"
		UP_mark="-m mark"
		if [ "${6:0:1}" = "!" ]; then		# first char is !
			DOWN_mark="${DOWN_mark} !"
			UP_mark="${UP_mark} !"
			tmpMark="${tmpMark//!/}"		# strip the !
		fi
		if [ "${tmpMark:2:4}" = "****" ]; then		# wildcard mark
			# replace **** with 0000 and use special mask
			DOWN_mark="${DOWN_mark} --mark 0x80${tmpMark//\*/0}/0xc03f0000"
			UP_mark="${UP_mark} --mark 0x40${tmpMark//\*/0}/0xc03f0000"
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
	case "$7" in
		0)
			DOWN_dst="-j MARK --set-mark ${Net_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Net_mark_up}/0x3fffff"
			;;
		1)
			DOWN_dst="-j MARK --set-mark ${Gaming_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Gaming_mark_up}/0x3fffff"
			;;
		2)
			DOWN_dst="-j MARK --set-mark ${Streaming_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Streaming_mark_up}/0x3fffff"
			;;
		3)
			DOWN_dst="-j MARK --set-mark ${Work_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Work_mark_up}/0x3fffff"
			;;
		4)
			DOWN_dst="-j MARK --set-mark ${Web_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Web_mark_up}/0x3fffff"
			;;
		5)
			DOWN_dst="-j MARK --set-mark ${Downloads_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Downloads_mark_up}/0x3fffff"
			;;
		6)
			DOWN_dst="-j MARK --set-mark ${Others_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Others_mark_up}/0x3fffff"
			;;
		7)
			DOWN_dst="-j MARK --set-mark ${Learn_mark_down}/0x3fffff"
			UP_dst="-j MARK --set-mark ${Learn_mark_up}/0x3fffff"
			;;
		*)
			#if destination is empty stop processing rule
			return
			;;
	esac

	# This block is redirected to the /tmp/flexqos_iprules file, so no extraneous output, please
	# If proto=both we have to create 2 statements, one for tcp and one for udp.
	# This is done by parameter expansion search and replace ${PROTO//both/tcp} ${PROTO//both/udp}
	if [ "$PROTO" = "-p both" ]; then
		# download ipv4
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "${PROTO//both/tcp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "${PROTO//both/tcp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "${PROTO//both/udp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "${PROTO//both/udp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		# upload ipv4
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "${PROTO//both/tcp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "${PROTO//both/tcp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "${PROTO//both/udp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "${PROTO//both/udp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		# If rule contains no IPv4 local or remote addresses, and IPv6 is enabled, add a corresponding rule for IPv6
		if [ -z "$DOWN_Lip" ] && [ -z "$DOWN_Rip" ] && [ "$IPv6_enabled" != "disabled" ]; then
			# download ipv6
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "${PROTO//both/tcp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "${PROTO//both/tcp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "${PROTO//both/udp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "${PROTO//both/udp}" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			# upload ipv6
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "${PROTO//both/tcp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "${PROTO//both/tcp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "${PROTO//both/udp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "${PROTO//both/udp}" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		fi
	else
		# download ipv4
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "$PROTO" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "$DOWN_Lip" "$DOWN_Rip" "$PROTO" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
		# upload ipv4
		printf "iptables -t mangle -D %s -o %s %s %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "$PROTO" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		printf "iptables -t mangle -A %s -o %s %s %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "$UP_Lip" "$UP_Rip" "$PROTO" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		# If rule contains no local or remote addresses, and IPv6 is enabled, add a corresponding rule for IPv6
		if [ -z "$DOWN_Lip" ] && [ -z "$DOWN_Rip" ] && [ "$IPv6_enabled" != "disabled" ]; then
			# download ipv6
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$lan" "$PROTO" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$lan" "$PROTO" "$DOWN_Lport" "$DOWN_Rport" "$DOWN_mark" "$DOWN_dst"
			# upload ipv6
			printf "ip6tables -t mangle -D %s -o %s %s %s %s %s %s >/dev/null 2>&1\n" "$SCRIPTNAME_DISPLAY" "$wan" "$PROTO" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
			printf "ip6tables -t mangle -A %s -o %s %s %s %s %s %s\n" "$SCRIPTNAME_DISPLAY" "$wan" "$PROTO" "$UP_Lport" "$UP_Rport" "$UP_mark" "$UP_dst"
		fi
	fi
} # parse_iptablerule

about() {
	scriptinfo
	printf "License\n"
	printf "  %s is free to use under the GNU General Public License, version 3 (GPL-3.0).\n" $SCRIPTNAME_DISPLAY
	Blue "  https://opensource.org/licenses/GPL-3.0"
	printf "\nFor discussion visit this thread:\n"
	Blue "  https://www.snbforums.com/threads/64882/"
	Blue "  https://github.com/dave14305/FlexQoS (Source Code)"
	printf "\nAbout\n"
	printf "  Script Changes Unidentified traffic destination away from Work-From-Home into Others\n"
	printf "  Script Changes HTTPS traffic destination away from Net Control into Web Surfing\n"
	printf "  Script Changes Guaranteed Bandwidth per QoS category into logical percentages of upload and download.\n"
	printf "  Script Repurposes Learn-From-Home to contain Game Downloads\n\n"
	printf "  Script includes misc default rules\n"
	printf "   (Wifi Calling)  -  UDP traffic on remote ports 500 & 4500 moved into Work-From-Home\n"
	printf "   (Facetime)      -  UDP traffic on local  ports 16384 - 16415 moved into Work-From-Home\n"
	printf "   (Usenet)        -  TCP traffic on remote ports 119 & 563 moved into Downloads\n"
	printf "   (Gaming)        -  Gaming TCP traffic from remote ports 80 & 443 moved into Game Downloads.\n"
	printf "   (Snapchat)      -  Moved into Others\n"
	printf "   (Speedtest.net) -  Moved into Downloads\n"
	printf "   (Google Play)   -  Moved into Downloads\n"
	printf "   (Apple AppStore)-  Moved into Downloads\n"
	printf "   (Advertisement) -  Moved into Downloads\n"
	printf "   (VPN Fix)       -  Router VPN Client upload traffic moved into Downloads instead of whitelisted\n"
	printf "   (Gaming Manual) -  Unidentified traffic for specified devices, not originating from ports 80/443, moved into Gaming\n\n"
	Red  "Gaming Rule Note"
	printf "  Gaming traffic originating from ports 80 & 443 is primarily downloads & patches (some lobby/login protocols mixed within)\n"
	printf "  Manually configurable rule will take untracked traffic for specified devices, not originating from server ports 80/443, and place it into Gaming\n"
	printf "  Use of this gaming rule REQUIRES devices to have a continous static ip assignment & this range needs to be passed into the script\n"
}

backup() {
	# Backup existing user rules in /jffs/addons/custom_settings.txt
	# Input: create [force]|restore|remove
	case "$1" in
		'create')
			if [ "$2" != "force" ] && [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
				printf "A backup already exists. Do you want to overwrite this backup? [1=Yes 2=No]: "
				read -r yn
				if [ "$yn" != "1" ]; then
					Yellow "Backup cancelled."
					return
				fi
			fi
			printf "Running backup...\n"
			{
				printf "#!/bin/sh\n"
				printf "# Backup date: %s\n" "$(date +'%Y-%m-%d %H:%M:%S%z')"
				printf ". /usr/sbin/helper.sh\n"
				printf "am_settings_set flexqos_iptables \"%s\"\n" "$(am_settings_get flexqos_iptables)"
				printf "am_settings_set flexqos_iptables_names \"%s\"\n" "$(am_settings_get flexqos_iptables_names)"
				printf "am_settings_set flexqos_appdb \"%s\"\n" "$(am_settings_get flexqos_appdb)"
				printf "am_settings_set flexqos_bandwidth \"%s\"\n" "$(am_settings_get flexqos_bandwidth)"
			} > "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			Green "Backup done to ${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			;;
		'restore')
			if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				Yellow "$(grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh")"
				printf "Do you want to restore this backup? [1=Yes 2=No]: "
				read -r yn
				if [ "$yn" = "1" ]; then
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
		if [ "$(md5sum "/tmp/${1}" | awk '{print $1}')" != "$(md5sum "$2" 2>/dev/null | awk '{print $1}')" ]; then
			mv -f "/tmp/${1}" "$2"
			logmsg "Updated $(echo "$1" | awk -F / '{print $NF}')"
		else
			logmsg "File $(echo "$2" | awk -F / '{print $NF}') is already up-to-date"
		fi
	else
		logmsg "Updating $(echo "$1" | awk -F / '{print $NF}') failed"
	fi
} # download_file

compare_remote_version() {
	# Check version on Github and determine the difference with the installed version
	# Outcomes: Version update, Hotfix (w/o version change), or no update

	# Fetch version of the shell script on Github
	remotever="$(curl -fsN --retry 3 --connect-timeout 3 "${GIT_URL}/$(basename $SCRIPTPATH)" | /bin/grep "^version=" | sed -e 's/version=//')"
	if [ "${version//.}" -lt "${remotever//.}" ]; then		# strip the . from version string for numeric comparison
		# version upgrade
		echo "$remotever"
	else
		# If no version change, calculate md5sum of local and remote files
		# to determine if a hotfix has been published
		localmd5="$(md5sum "$0" | awk '{print $1}')"
		remotemd5="$(curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/$(basename $SCRIPTPATH)" | md5sum | awk '{print $1}')"
		localmd5asp="$(md5sum "$WEBUIPATH" | awk '{print $1}')"
		remotemd5asp="$(curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/$(basename $WEBUIPATH)" | md5sum | awk '{print $1}')"
		if [ "$localmd5" != "$remotemd5" ] || [ "$localmd5asp" != "$remotemd5asp" ]; then
			# hotfix
			printf "Hotfix\n"
		else
			printf "NoUpdate\n"
		fi
	fi
} # compare_remote_version

update() {
	# Check for, and optionally apply updates.
	# Parameter options: check (do not update), silent (update without prompting)
	scriptinfo
	printf "Checking for updates\n"
	# Update the webui status thorugh detect_update.js ajax call.
	printf "var verUpdateStatus = \"%s\";\n" "InProgress" > /www/ext/${SCRIPTNAME}/detect_update.js
	updatestatus="$(compare_remote_version)"
	# Check to make sure we got back a valid status from compare_remote_version(). If not, indicate Error.
	case "$updatestatus" in
		'NoUpdate'|'Hotfix'|[0-9].[0-9].[0-9]) ;;
		*) updatestatus="Error"
	esac
	printf "var verUpdateStatus = \"%s\";\n" "$updatestatus" > /www/ext/${SCRIPTNAME}/detect_update.js

	if [ "$1" = "check" ]; then
		# Do not proceed with any updating if check function requested
		return
	fi
	if [ "$mode" = "interactive" ] && [ -z "$1" ]; then
		case "$updatestatus" in
		'NoUpdate')
			Green " You have the latest version installed"
			printf " Would you like to overwrite your existing installation anyway? [1=Yes 2=No]: "
			;;
		'Hotfix')
			Green " $SCRIPTNAME_DISPLAY hotfix is available."
			printf " Would you like to update now? [1=Yes 2=No]: "
			;;
		'Error')
			Red " Error determining remote version status!"
			PressEnter
			return
			;;
		*)
			# New Version Number
			Green " $SCRIPTNAME_DISPLAY v${updatestatus} is now available!"
			printf " Would you like to update now? [1=Yes 2=No]: "
			;;
		esac
		read -r yn
		printf "\n"
		if [ "$yn" != "1" ]; then
			Green " No Changes have been made"
			return 0
		fi
	fi
	printf "Installing: %s...\n\n" "$SCRIPTNAME_DISPLAY"
	download_file "$(basename $SCRIPTPATH)" "$SCRIPTPATH"
	exec sh "$SCRIPTPATH" -install "$1"
	exit
} # update

prompt_restart() {
	# Restart QoS so that FlexQoS changes can take effect.
	# Possible values for $needrestart:
	#  0: No restart needed (initialized in main)
	#  1: Restart needed, but prompt user if interactive session
	#  2: Restart needed, do not prompt (force)
	if [ "$needrestart" -gt "0" ]; then
		if [ "$mode" = "interactive" ]; then
			if [ "$needrestart" = "1" ]; then
				printf "\nWould you like to restart QoS for modifications to take effect? [1=Yes 2=No]: "
				read -r yn
				if [ "$yn" = "2" ]; then
					needrestart=0
					return
				fi
			fi
		fi
		printf "Restarting QoS...\n"
		service restart_qos
		needrestart=0
	fi
} # prompt_restart

menu() {
	# Minimal interactive, menu-driven interface for basic maintenance functions.
	[ "$mode" = "interactive" ] || return
	clear
	sed -n '2,10p' "$0"		# display banner
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
	case $input in
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
			printf " Do you want to uninstall %s [1=Yes 2=No]: " "$SCRIPTNAME_DISPLAY"
			read -r yn
			if [ "$yn" = "1" ]; then
				printf "\n"
				sh ${SCRIPTPATH} -uninstall
				printf "\n"
				exit
			fi
			printf "\n"
			Yellow "$SCRIPTNAME_DISPLAY has NOT been uninstalled"
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
	printf "Removing WebUI...\n"
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPTNAME_DISPLAY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "$prev_webui_page" ]; then
		# Remove page from the UI menu system
		umount /www/require/modules/menuTree.js 2>/dev/null
		sed -i "\~tabName: \"${SCRIPTNAME_DISPLAY}\"},~d" /tmp/menuTree.js
		if diff -q /tmp/menuTree.js /www/require/modules/menuTree.js >/dev/null 2>&1; then
			# no more custom pages mounted, so remove the file
			rm /tmp/menuTree.js
		else
			# Still some modifications from another script so remount
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		# Remove last mounted asp page
		rm -f /www/user/"$prev_webui_page" 2>/dev/null
		# Look for previously mounted asp pages that are orphaned now and delete them
		/bin/grep -l "$SCRIPTNAME_DISPLAY maintained by dave14305" /www/user/user*.asp 2>/dev/null | while read -r oldfile
		do
			rm "$oldfile"
		done
	fi
	rm -rf /www/ext/${SCRIPTNAME} 2>/dev/null		# remove js helper scripts
} # remove_webui

install_webui() {
	# if this is an install or update...otherwise it's a normal startup/mount
	if [ -z "$1" ]; then
		printf "Downloading WebUI files...\n"
		download_file "$(basename $WEBUIPATH)" "$WEBUIPATH"
		# cleanup obsolete files from previous versions
		[ -L "/www/ext/${SCRIPTNAME}" ] && rm "/www/ext/${SCRIPTNAME}" 2>/dev/null
		[ -d "${ADDON_DIR}/table" ] && rm -r "${ADDON_DIR}/table"
		[ -f "${ADDON_DIR}/${SCRIPTNAME}_arrays.js" ] && rm "${ADDON_DIR}/${SCRIPTNAME}_arrays.js"
	fi
	# Check if the webpage is already mounted in the GUI and reuse that page
	prev_webui_page="$(sed -nE "s/^\{url\: \"(user[0-9]+\.asp)\"\, tabName\: \"${SCRIPTNAME_DISPLAY}\"\}\,$/\1/p" /tmp/menuTree.js 2>/dev/null)"
	if [ -n "$prev_webui_page" ]; then
		# use the same filename as before
		am_webui_page="$prev_webui_page"
	else
		# get a new mountpoint
		am_get_webui_page "$WEBUIPATH"
	fi
	if [ "$am_webui_page" = "none" ]; then
		logmsg "No API slots available to install web page"
	else
		cp -p "$WEBUIPATH" /www/user/"$am_webui_page"
		if [ ! -f /tmp/menuTree.js ]; then
			cp /www/require/modules/menuTree.js /tmp/
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
		if ! /bin/grep -q "{url: \"$am_webui_page\", tabName: \"${SCRIPTNAME_DISPLAY}\"}," /tmp/menuTree.js; then
			umount /www/require/modules/menuTree.js 2>/dev/null
			sed -i "\~tabName: \"${SCRIPTNAME_DISPLAY}\"},~d" /tmp/menuTree.js
			sed -i "/url: \"QoS_Stats.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"${SCRIPTNAME_DISPLAY}\"}," /tmp/menuTree.js
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
	fi
	[ ! -d "/www/ext/${SCRIPTNAME}" ] && mkdir -p "/www/ext/${SCRIPTNAME}"
}

Init_UserScript() {
	# Properly setup an empty Merlin user script
	if [ -z "$1" ]; then
		return
	fi
	userscript="/jffs/scripts/$1"
	if [ ! -f "$userscript" ]; then
		# If script doesn't exist yet, create with shebang
		printf "#!/bin/sh\n\n" > "$userscript"
	elif [ -f "$userscript" ] && ! head -1 "$userscript" | /bin/grep -qE "^#!/bin/sh"; then
		#  Script exists but no shebang, so insert it at line 1
		sed -i '1s~^~#!/bin/sh\n~' "$userscript"
	elif [ "$(tail -c1 "$userscript" | wc -l)" = "0" ]; then
		# Script exists with shebang, but no linefeed before EOF; makes appending content unpredictable if missing
		printf "\n" >> "$userscript"
	fi
	if [ ! -x "$userscript" ]; then
		# Ensure script is executable by owner
		chmod 755 "$userscript"
	fi
} # Init_UserScript

Auto_ServiceEventEnd() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	Init_UserScript "service-event-end"
	# Delete existing lines related to this script
	sed -i "\~$SCRIPTNAME_DISPLAY Addition~d" /jffs/scripts/service-event-end
	# Add line to handle qos, wrs and sig_check events that require reapplying settings
	cmdline="if [ \"\$2\" = \"qos\" ] || [ \"\$2\" = \"wrs\" ] || [ \"\$2\" = \"sig_check\" ]; then { sh ${SCRIPTPATH} -start & } ; fi # $SCRIPTNAME_DISPLAY Addition"
	echo "$cmdline" >> /jffs/scripts/service-event-end
	# Add line to handle other events triggered from webui
	cmdline="if echo \"\$2\" | /bin/grep -q \"^${SCRIPTNAME}\"; then { sh ${SCRIPTPATH} \"\${2#${SCRIPTNAME}}\" & } ; fi # $SCRIPTNAME_DISPLAY Addition"
	echo "$cmdline" >> /jffs/scripts/service-event-end
} # Auto_ServiceEventEnd

Auto_FirewallStart() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	Init_UserScript "firewall-start"
	# Delete existing lines related to this script
	sed -i "\~$SCRIPTNAME_DISPLAY Addition~d" /jffs/scripts/firewall-start
	# Add line to trigger script on firewall startup
	cmdline="sh ${SCRIPTPATH} -start & # $SCRIPTNAME_DISPLAY Addition"
	if /bin/grep -vE "^#" /jffs/scripts/firewall-start | /bin/grep -q "Skynet"; then
		# If Skynet also installed, insert this script before Skynet so it doesn't have to wait for Skynet to startup before applying QoS
		# Won't delay Skynet startup since we fork into the background
		sed -i "/Skynet/i $cmdline" /jffs/scripts/firewall-start
	else
		# Skynet not installed, so just append
		echo "$cmdline" >> /jffs/scripts/firewall-start
	fi # is Skynet also installed?
} # Auto_FirewallStart

Auto_Crontab() {
	# Setup cronjob for nightly check of QoS settings
	cru a ${SCRIPTNAME} "30 3 * * * ${SCRIPTPATH} -check"
	Init_UserScript "services-start"
	sed -i "\~$SCRIPTNAME_DISPLAY Addition~d" /jffs/scripts/services-start
	cmdline="cru a ${SCRIPTNAME} \"30 3 * * * ${SCRIPTPATH} -check\" # $SCRIPTNAME_DISPLAY Addition"
	echo "$cmdline" >> /jffs/scripts/services-start
} # Auto_Crontab

setup_aliases() {
	# shortcuts to launching script
	if [ -d /opt/bin ]; then
		# Entware is installed, so setup link to /opt/bin
		printf "Adding %s link in Entware /opt/bin...\n" "$SCRIPTNAME"
		ln -sf "$SCRIPTPATH" /opt/bin/${SCRIPTNAME}
	else
		# Setup shell alias
		printf "Adding %s alias in profile.add...\n" "$SCRIPTNAME"
		sed -i "/alias ${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
		cmdline="alias ${SCRIPTNAME}=\"sh ${SCRIPTPATH}\" # $SCRIPTNAME_DISPLAY Addition"
		echo "$cmdline" >> /jffs/configs/profile.add
	fi
} # setup_aliases

Firmware_Check() {
	printf "Checking firmware support...\n"
	if ! nvram get rc_support | grep -q am_addons; then
		Red "$SCRIPTNAME_DISPLAY requires ASUSWRT-Merlin Addon API support. Installation aborted."
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
	if [ "$mode" = "interactive" ]; then
		clear
		scriptinfo
		printf "Installing %s...\n" "$SCRIPTNAME_DISPLAY"
		if ! Firmware_Check; then
			PressEnter
			rm -f "$0" 2>/dev/null
			exit 5
		fi
	fi
	if [ ! -d "$ADDON_DIR" ]; then
		printf "Creating directories...\n"
		mkdir -p "$ADDON_DIR"
		chmod 755 "$ADDON_DIR"
	fi
	if [ ! -f "$SCRIPTPATH" ]; then
		cp -p "$0" "$SCRIPTPATH"
	fi
	if [ ! -x "$SCRIPTPATH" ]; then
		chmod 755 "$SCRIPTPATH"
	fi
	install_webui
	generate_bwdpi_arrays force
	printf "Adding %s entries to Merlin user scripts...\n" "$SCRIPTNAME_DISPLAY"
	Auto_FirewallStart
	Auto_ServiceEventEnd
	printf "Adding nightly cron job...\n"
	Auto_Crontab
	setup_aliases

	if [ "$mode" = "interactive" ]; then
		Green "$SCRIPTNAME_DISPLAY installation complete!"
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
} # install

uninstall() {
	printf "Removing entries from Merlin user scripts...\n"
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/firewall-start 2>/dev/null
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/service-event-end 2>/dev/null
	sed -i "\~${SCRIPTNAME_DISPLAY}~d" /jffs/scripts/services-start 2>/dev/null
	printf "Removing aliases and shortcuts...\n"
	sed -i "/alias ${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
	rm -f "/opt/bin/$SCRIPTNAME" 2>/dev/null
	printf "Removing cron job...\n"
	cru d "$SCRIPTNAME"
	cru d "${SCRIPTNAME}_5min" 2>/dev/null
	remove_webui
	printf "Removing %s settings...\n" "$SCRIPTNAME_DISPLAY"
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		printf "Backup found! Would you like to delete it? [1=Yes 2=No]: "
		read -r yn
		if [ "$yn" = "1" ]; then
			printf "Deleting Backup...\n"
			rm "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
		fi
	else
		printf "Do you want to backup your settings before uninstall? [1=Yes 2=No]: "
		read -r yn
		if [ "$yn" = "1" ]; then
			printf "Backing up %s settings...\n" "$SCRIPTNAME_DISPLAY"
			backup create force
		fi
	fi
	sed -i "/^${SCRIPTNAME}_/d" /jffs/addons/custom_settings.txt
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		printf "Deleting %s folder contents except Backup file...\n" "$SCRIPTNAME_DISPLAY"
		/usr/bin/find ${ADDON_DIR} ! -name restore_${SCRIPTNAME}_settings.sh ! -exec test -d {} \; -a -exec rm {} +
	else
		printf "Deleting %s directory...\n" "$SCRIPTNAME_DISPLAY"
		rm -rf "$ADDON_DIR"
	fi
	Green "$SCRIPTNAME_DISPLAY has been uninstalled"
	needrestart=1
} # uninstall

get_config() {
	# Read settings from Addon API config file. If not defined, set default values
	if [ -z "$(am_settings_get ${SCRIPTNAME}_iptables)" ]; then
		am_settings_set "${SCRIPTNAME}_iptables" "<>>udp>>500,4500>>3<>>udp>16384:16415>>>3<>>tcp>>119,563>>5<>>tcp>>80,443>08****>7"
		am_settings_set "${SCRIPTNAME}_iptables_names" "<WiFi%20Calling<Facetime<Usenet<Game%20Downloads"
	fi
	iptables_rules="$(am_settings_get ${SCRIPTNAME}_iptables)"
	if [ -z "$(am_settings_get ${SCRIPTNAME}_iptables_names)" ]; then
		iptables_rules_defined="$(echo "$iptables_rules" | sed 's/</\n/g' | /bin/grep -vc "^$")"
		n=1
		names=""
		while [ "$n" -le "$iptables_rules_defined" ]; do
			names="${names}<Rule%20${n}"
			n="$((n+1))"
		done
		am_settings_set "${SCRIPTNAME}_iptables_names" "$names"
	fi
	if [ -z "$(am_settings_get ${SCRIPTNAME}_appdb)" ]; then
		am_settings_set "${SCRIPTNAME}_appdb" "<000000>6<00006B>6<0D0007>5<0D0086>5<0D00A0>5<12003F>4<13****>4<14****>4<1A****>5"
	fi
	appdb_rules="$(am_settings_get ${SCRIPTNAME}_appdb)"
	if [ -z "$(am_settings_get ${SCRIPTNAME}_bandwidth)" ]; then
		am_settings_set "${SCRIPTNAME}_bandwidth" "<5>20>15>10>10>30>5>5<100>100>100>100>100>100>100>100<5>20>15>30>10>10>5>5<100>100>100>100>100>100>100>100"
	fi
	read \
		drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7 \
		dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7 \
		urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7 \
		ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7 \
<<EOF
$(am_settings_get ${SCRIPTNAME}_bandwidth | sed 's/^<//g;s/[<>]/ /g')
EOF
} # get_config

validate_iptables_rules() {
	# Basic check to ensure the number of rules present in the iptables chain matches the number of expected rules
	# Does not verify that the rules present match the rules in the config, since the config hasn't been parsed at this point.
	iptables_rules_defined="$(echo "$iptables_rules" | sed 's/</\n/g' | /bin/grep -vc "^$")"
	iptables_rules_expected=$((iptables_rules_defined*2+1)) # 1 downlaod and upload rule per user rule, plus 1 for chain definition
	iptables_rulespresent="$(iptables -t mangle -S $SCRIPTNAME_DISPLAY | wc -l)" # count rules in chain plus chain itself
	if [ "$iptables_rulespresent" -lt "$iptables_rules_expected" ]; then
		return 1
	else
		return 0
	fi
} # validate_iptables_rules

write_iptables_rules() {
	# loop through iptables rules and write an iptables command to a temporary file for later execution
	OLDIFS="$IFS"		# Save existing field separator
	IFS=">"				# Set custom field separator to match rule format
	# Remove previous script file if it exists
	if [ -f "/tmp/${SCRIPTNAME}_iprules" ]; then
		rm -f "/tmp/${SCRIPTNAME}_iprules"
	fi

	# read the rules, 1 per line and break into separate fields
	echo "$iptables_rules" | sed 's/</\n/g' | while read -r localip remoteip proto lport rport mark class
	do
		# Ensure at least one criteria field is populated
		if [ -n "${localip}${remoteip}${proto}${lport}${rport}${mark}" ]; then
			# Process the rule and the stdout containing the resulting rule gets saved to the temporary script file
			parse_iptablerule "$localip" "$remoteip" "$proto" "$lport" "$rport" "$mark" "$class" >> /tmp/${SCRIPTNAME}_iprules 2>/dev/null
		fi
	done
	IFS="$OLDIFS"		# Restore saved field separator
} # write_iptables_rules

write_appdb_rules() {
	# Write the user appdb rules to the existing tcrules file created during write_appdb_static_rules()

	# Save the current filter rules once to avoid repeated calls in parse_appdb_rule() to determine existing prios
	${tc} filter show dev $tclan parent 1: > /tmp/${SCRIPTNAME}_tmp_tcfilterdown
	${tc} filter show dev $tcwan parent 1: > /tmp/${SCRIPTNAME}_tmp_tcfilterup

	# loop through appdb rules and write a tc command to a temporary script file
	OLDIFS="$IFS"		# Save existing field separator
	IFS=">"				# Set custom field separator to match rule format

	# read the rules, 1 per line and break into separate fields
	echo "$appdb_rules" | sed 's/</\n/g' | while read -r mark class
	do
		# Ensure the appdb mark is populated
		if [ -n "$mark" ]; then
			parse_appdb_rule "$mark" "$class" >> /tmp/${SCRIPTNAME}_tcrules 2>/dev/null
		fi
	done
	IFS="$OLDIFS"		# Restore old field separator
} # write_appdb_rules

check_qos_tc() {
	# Check the status of the existing tc class and filter setup by stock Adaptive QoS before custom settings applied.
	# Only br0 interface is checked since we have not yet identified the tcwan interface name yet.
	dlclasscnt="$(${tc} class show dev br0 parent 1: | /bin/grep -c "parent")" # should be 8
	dlfiltercnt="$(${tc} filter show dev br0 parent 1: | /bin/grep -cE "flowid 1:1[0-7] *$")" # should be 39 or 40
	# Check class count, filter count, and tcwan interface name defined with an htb qdisc
	if [ "$dlclasscnt" -lt "8" ] || [ "$dlfiltercnt" -lt "39" ] || [ -z "$(${tc} qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')" ]; then
		return 0
	else
		return 1
	fi
} # check_qos_tc

validate_tc_rules() {
	# Check the existing tc filter rules against the user configuration. If any rule missing, force creation of all rules
	# Must run after set_tc_variables() to ensure flowid can be determined
	{
		# print a list of existing filters in the format of an appdb rule for easy comparison. Write to tmp file
		${tc} filter show dev "$tclan" parent 1: | sed -nE '/flowid/ { N; s/\n//g; s/.*flowid (1:1[0-7]).*mark 0x[48]0([0-9a-fA-F]{6}).*/<\2>\1/p }'
		${tc} filter show dev "$tcwan" parent 1: | sed -nE '/flowid/ { N; s/\n//g; s/.*flowid (1:1[0-7]).*mark 0x[48]0([0-9a-fA-F]{6}).*/<\2>\1/p }'
	} > /tmp/${SCRIPTNAME}_checktcrules 2>/dev/null
	OLDIFS="$IFS"
	IFS=">"
	filtermissing="0"
	while read -r mark class
	do
		if [ -n "$mark" ]; then
			flowid="$(get_flowid "$class")"
			mark="${mark//\*/0}"
			if [ "$(/bin/grep -ic "<${mark}>${flowid}" /tmp/${SCRIPTNAME}_checktcrules)" -lt "2" ]; then
				filtermissing="$((filtermissing+1))"
				break		# stop checking after the first missing rule is identified
			fi
		fi
	done <<EOF
$(echo "$appdb_rules" | sed 's/</\n/g')
EOF
	IFS="$OLDIFS"
	if [ "$filtermissing" -gt "0" ]; then
		# reapply tc rules
		return 1
	else
		rm /tmp/${SCRIPTNAME}_checktcrules 2>/dev/null
		return 0
	fi
} # validate_tc_rules

schedule_check_job() {
	# Schedule check for 5 minutes after startup to ensure no qos tc resets
	cru a ${SCRIPTNAME}_5min "$(date -D '%s' +'%M %H %d %m %a' -d $(($(date +%s)+300))) $SCRIPTPATH -check"
} # schedule_check_job

startup() {
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "1" ]; then
		logmsg "Adaptive QoS is not enabled. Skipping $SCRIPTNAME_DISPLAY startup."
		return 1
	fi # adaptive qos not enabled

	Check_Lock
	install_webui mount
	generate_bwdpi_arrays
	get_config

	if ! validate_iptables_rules; then
		write_iptables_rules
		iptables_static_rules 2>&1 | logger -t "$SCRIPTNAME_DISPLAY"
		if [ -s "/tmp/${SCRIPTNAME}_iprules" ]; then
			logmsg "Applying iptables custom rules"
			. /tmp/${SCRIPTNAME}_iprules 2>&1 | logger -t "$SCRIPTNAME_DISPLAY"
			if [ "$(am_settings_get ${SCRIPTNAME}_conntrack)" != "0" ]; then
				# Flush conntrack table so that existing connections will be processed by new iptables rules
				logmsg "Flushing conntrack table"
				/usr/sbin/conntrack -F conntrack >/dev/null 2>&1
			fi
		fi
	else
		logmsg "iptables rules already present"
	fi

	cru d ${SCRIPTNAME}_5min 2>/dev/null
	sleepdelay=0
	while check_qos_tc;
	do
		[ "$sleepdelay" = "0" ] && logmsg "TC Modification Delayed Start"
		sleep 10s
		if [ "$sleepdelay" -ge "300" ]; then
			logmsg "TC Modification Delay reached maximum 300 seconds. Aborting startup!"
			schedule_check_job
			break
		else
			sleepdelay=$((sleepdelay+10))
		fi
	done
	[ "$sleepdelay" -gt "0" ] && logmsg "TC Modification delayed for $sleepdelay seconds"

	set_tc_variables

	# if TC modifcations have not been applied then run modification script
	if ! validate_tc_rules; then
		write_appdb_static_rules
		write_appdb_rules

		if [ "$DownCeil" -gt "500" ] && [ "$UpCeil" -gt "500" ]; then
			write_custom_rates
		else
			logmsg "Bandwidth too low for custom rates. Skipping."
		fi

		if [ -s "/tmp/${SCRIPTNAME}_tcrules" ]; then
			logmsg "Applying AppDB rules and TC rates"
			if ! ${tc} -force -batch /tmp/${SCRIPTNAME}_tcrules >/tmp/${SCRIPTNAME}_tcrules.log 2>&1; then
				cp -f /tmp/${SCRIPTNAME}_tcrules /tmp/${SCRIPTNAME}_tcrules.err
				logmsg "ERROR! Check /tmp/${SCRIPTNAME}_tcrules.log"
			else
				rm /tmp/${SCRIPTNAME}_tmp_tcfilterdown /tmp/${SCRIPTNAME}_tmp_tcfilterup /tmp/${SCRIPTNAME}_tcrules.log /tmp/${SCRIPTNAME}_checktcrules /tmp/${SCRIPTNAME}_tcrules.err 2>/dev/null
			fi
		fi

		schedule_check_job
	else
		logmsg "No TC modifications necessary"
	fi
} # startup

show_help() {
	scriptinfo
	Red "You have entered an invalid command"
	printf "\nAvailable commands:\n\n"
	printf "  %s -about              explains functionality\n" $SCRIPTNAME
	printf "  %s -appdb string       search appdb for application marks\n" $SCRIPTNAME
	printf "  %s -update             checks for updates\n" $SCRIPTNAME
	printf "  %s -restart            restart QoS and Firewall\n" $SCRIPTNAME
	printf "  %s -install            install   script\n" $SCRIPTNAME
	printf "  %s -uninstall          uninstall script & delete from disk\n" $SCRIPTNAME
	printf "  %s -enable             enable    script\n" $SCRIPTNAME
	printf "  %s -disable            disable   script but do not delete from disk\n" $SCRIPTNAME
	printf "  %s -backup             backup user settings\n" $SCRIPTNAME
	printf "  %s -debug              print debug info\n" $SCRIPTNAME
	printf "  %s -develop            switch to development channel\n" $SCRIPTNAME
	printf "  %s -stable             switch to stable channel\n" $SCRIPTNAME
	printf "  %s -menu               interactive main menu\n" $SCRIPTNAME
	printf "\n"
	webconfigpage
} # show_help

generate_bwdpi_arrays() {
	# generate if not exist, plus after wrs restart (signature update)
	# generate if signature rule file is newer than js file
	# generate if js file is smaller than source file (source not present yet during boot)
	# prepend wc variables with zero in case file doesn't exist, to avoid bad number error
	if [ ! -f "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js" ] || \
		[ /jffs/signature/rule.trf -nt "/www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js" ] || \
		[ "$1" = "force" ] || \
		[ "0$(wc -c < /www/user/${SCRIPTNAME}/${SCRIPTNAME}_arrays.js)" -lt "0$(wc -c 2>/dev/null < /tmp/bwdpi/bwdpi.app.db)" ]; then
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
	[ "$mode" = "interactive" ] || return
	printf "\n"
	while true; do
		printf "Press enter to continue..."
		read -r "key"
		case "$key" in
			*)
				break
			;;
		esac
	done
	return 0
}

Kill_Lock() {
	if [ -f "/tmp/${SCRIPTNAME}.lock" ] && [ -d "/proc/$(sed -n '1p' /tmp/${SCRIPTNAME}.lock)" ]; then
		logmsg "[*] Killing Delayed Process (pid=$(sed -n '1p' /tmp/${SCRIPTNAME}.lock))"
		logmsg "[*] $(ps | awk -v pid="$(sed -n '1p' /tmp/${SCRIPTNAME}.lock)" '$1 == pid')"
		kill "$(sed -n '1p' /tmp/${SCRIPTNAME}.lock)"
	fi
	rm -rf /tmp/${SCRIPTNAME}.lock
} # Kill_Lock

Check_Lock() {
	if [ -f "/tmp/${SCRIPTNAME}.lock" ] && [ -d "/proc/$(sed -n '1p' /tmp/${SCRIPTNAME}.lock)" ] && [ "$(sed -n '1p' /tmp/${SCRIPTNAME}.lock)" != "$$" ]; then
		Kill_Lock
	fi
	printf "%s\n" "$$" > /tmp/${SCRIPTNAME}.lock
	lock="true"
} # Check_Lock

get_wanif() {
	prefixes="wan0_ wan1_"

	if [ "$(nvram get wans_mode)" = "lb" ] ; then
		for prefix in $prefixes; do
			state=$(nvram get "${prefix}"state_t)
			sbstate=$(nvram get "${prefix}"sbstate_t)
			auxstate=$(nvram get "${prefix}"auxstate_t)

			# is_wan_connect()
			[ "$state" = "2" ] || continue
			[ "$sbstate" = "0" ] || continue
			[ "$auxstate" = "0" ] || [ "$auxstate" = "2" ] || continue

			# get_wan_ifname()
			proto=$(nvram get "${prefix}"proto)
			if [ "$proto" = "pppoe" ] || [ "$proto" = "pptp" ] || [ "$proto" = "l2tp" ] ; then
				ifname=$(nvram get "${prefix}"pppoe_ifname)
			else
				ifname=$(nvram get "${prefix}"ifname)
			fi
		done
	else
		for prefix in $prefixes; do
			primary=$(nvram get "${prefix}"primary)
			[ "$primary" = "1" ] && break
		done

		[ "$primary" = "1" ] || ifname="eth0"

		# get_wan_ifname()
		proto=$(nvram get "${prefix}"proto)
		if [ "$proto" = "pppoe" ] || [ "$proto" = "pptp" ] || [ "$proto" = "l2tp" ] ; then
			ifname=$(nvram get "${prefix}"pppoe_ifname)
		else
			ifname=$(nvram get "${prefix}"ifname)
		fi
	fi
	printf "%s" "$ifname"
} # get_wanif

arg1="${1#-}"
if [ -z "$arg1" ] || [ "$arg1" = "menu" ] && ! /bin/grep -qE "${SCRIPTPATH} .* # FlexQoS" /jffs/scripts/firewall-start; then
	arg1="install"
fi

wan="$(get_wanif)"
lan="$(nvram get lan_ifname)"
needrestart=0		# initialize variable used in prompt_restart()

case "$arg1" in
	'start'|'check')
		logmsg "$0 (pid=$$) called in $mode mode with $# args: $*"
		startup
		;;
	'appdb')
		appdb "$2"
		;;
	'install'|'enable')
		install "$2"
		;;
	'uninstall')
		uninstall
		;;
	'disable')
		sed -i "/${SCRIPTNAME}/d" /jffs/scripts/firewall-start  2>/dev/null
		sed -i "/${SCRIPTNAME}/d" /jffs/scripts/service-event-end  2>/dev/null
		sed -i "/${SCRIPTNAME}/d" /jffs/scripts/services-start  2>/dev/null
		cru d "$SCRIPTNAME"
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
			exec "$0" updatesilent
		fi
		;;
	'stable')
		if [ -z "$(am_settings_get "${SCRIPTNAME}_branch")" ]; then
			printf "Already set to stable branch.\n"
		else
			sed -i "/^${SCRIPTNAME}_branch /d" /jffs/addons/custom_settings.txt
			printf "Set to stable branch. Triggering update...\n"
			exec "$0" updatesilent
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
		echo "Enabled conntrack flushing."
		;;
	'noflushct')
		am_settings_set "${SCRIPTNAME}_conntrack" "0"
		echo "Disabled conntrack flushing."
		;;
	'flushct')
		sed -i "/^${SCRIPTNAME}_conntrack /d" /jffs/addons/custom_settings.txt
		Green "Enabled conntrack flushing."
		;;
	'noflushct')
		am_settings_set "${SCRIPTNAME}_conntrack" "0"
		Yellow "Disabled conntrack flushing."
		;;
	*)
		show_help
		;;
esac

prompt_restart
if [ "$lock" = "true" ]; then rm -rf "/tmp/${SCRIPTNAME}.lock"; fi
