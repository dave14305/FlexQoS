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
version=1.0.6
release=2020-11-15
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

if [ "$1" = "-x" ]; then
	shift
	set -x
fi

# Global variables
SCRIPTNAME="flexqos"
SCRIPTNAME_DISPLAY="FlexQoS"
GIT_REPO="https://raw.githubusercontent.com/dave14305/FlexQoS"
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

if [ "$(am_settings_get flexqos_ver)" != "$version" ]; then
	am_settings_set flexqos_ver "$version"
fi

if [ -e "/usr/sbin/realtc" ]; then
	tc="realtc"
else
	tc="tc"
fi

# marks for iptable rules
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
	echo "Applying iptables static rules"
	# Reference for VPN Fix origin: https://www.snbforums.com/threads/36836/page-78#post-412034
	# Partially fixed in https://github.com/RMerl/asuswrt-merlin.ng/commit/f7d6478df7b934c9540fa9740ad71d49d84a1756
	iptables -D OUTPUT -t mangle -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up} > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -A OUTPUT -t mangle -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}
	iptables -D OUTPUT -t mangle -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up} > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
	iptables -A OUTPUT -t mangle -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}
	if [ "$IPv6_enabled" != "disabled" ]; then
		echo "Applying ip6tables static rules"
		ip6tables -D OUTPUT -t mangle -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up} > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -A OUTPUT -t mangle -o "$wan" -p udp -m multiport ! --dports 53,123 -j MARK --set-mark ${Downloads_mark_up}
		ip6tables -D OUTPUT -t mangle -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up} > /dev/null 2>&1		#VPN Fix - (Fixes upload traffic not detected when the router is acting as a VPN Client)
		ip6tables -A OUTPUT -t mangle -o "$wan" -p tcp -m multiport ! --dports 53,123,853 -j MARK --set-mark ${Downloads_mark_up}
	fi
}

write_appdb_static_rules() {
	{
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Net_mark_down} 0xc03fffff flowid $Net"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Net_mark_up} 0xc03fffff flowid $Net"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Work_mark_down} 0xc03fffff flowid $Work"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Work_mark_up} 0xc03fffff flowid $Work"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Gaming_mark_down} 0xc03fffff flowid $Gaming"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Gaming_mark_up} 0xc03fffff flowid $Gaming"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Others_mark_down} 0xc03fffff flowid $Others"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Others_mark_up} 0xc03fffff flowid $Others"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Web_mark_down} 0xc03fffff flowid $Web"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Web_mark_up} 0xc03fffff flowid $Web"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Streaming_mark_down} 0xc03fffff flowid $Streaming"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Streaming_mark_up} 0xc03fffff flowid $Streaming"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Downloads_mark_down} 0xc03fffff flowid $Downloads"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Downloads_mark_up} 0xc03fffff flowid $Downloads"
		echo "filter add dev br0 protocol all prio 5 u32 match mark ${Learn_mark_down} 0xc03fffff flowid $Learn"
		echo "filter add dev $tcwan protocol all prio 5 u32 match mark ${Learn_mark_up} 0xc03fffff flowid $Learn"
	} > /tmp/${SCRIPTNAME}_tcrules
} # write_appdb_static_rules

write_custom_rates() {
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

set_tc_variables(){
	tcwan="$(${tc} qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')"
	if [ -z "$tcwan" ] && [ -s "/tmp/bwdpi/dev_wan" ]; then
		tcwan="$(/bin/grep -oE "eth[0-9]|usb[0-9]" /tmp/bwdpi/dev_wan)"
	fi
	if [ -z "$tcwan" ]; then
		tcwan="eth0"
	fi

	current_undf_rule="$(${tc} filter show dev br0 | /bin/grep -i "0x80000000 0xc000ffff" -B1 | head -1)"
	if [ -n "$current_undf_rule" ]; then
		undf_prio="$(echo "$current_undf_rule" | /bin/grep -o "pref.*" | cut -d" " -f2)"
	else
		undf_prio="$(${tc} filter show dev br0 | /bin/grep -i "0x80000000 0xc03f0000" -B1 | head -1 | /bin/grep -o "pref.*" | cut -d" " -f2)"
		undf_prio="$((undf_prio-1))"
	fi

	# read priority order of QoS categories as set by user in GUI
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
			if echo "$(nvram get bwdpi_app_rulelist)" | /bin/grep -qE "<4,13(<.*)?<4<"; then
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
			if [ "$downquantum" -lt "$((WANMTU+14))" ]; then
				downquantum="$((WANMTU+14))"
			fi
			upquantum=$((UpRate${i}*1000/8/10))
			if [ "$upquantum" -lt "$((WANMTU+14))" ]; then
				upquantum="$((WANMTU+14))"
			fi
			downburst=$((((DownRate${i}*1000/1280000))*1600))
			if [ "$downburst" -lt "3200" ]; then
				downburst=3200
			fi
			downcburst=$((((DownCeil${i}*1000/1280000))*1600))
			if [ "$downcburst" -lt "3200" ]; then
				downcburst=3200
			fi
			upburst=$((((UpRate${i}*1000/1280000))*1600))
			if [ "$upburst" -lt "3200" ]; then
				upburst=3200
			fi
			upcburst=$((((UpCeil${i}*1000/1280000))*1600))
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

		#read parameters for fakeTC
		PARMS=""
		OVERHEAD="$(nvram get qos_overhead)"
		if [ -n "$OVERHEAD" ] && [ "$OVERHEAD" -gt "0" ]; then
			ATM="$(nvram get qos_atm)"
			if [ "$ATM" = "1" ]; then
				PARMS="overhead $OVERHEAD linklayer atm"
			else
				PARMS="overhead $OVERHEAD linklayer ethernet"
			fi
		fi
	fi # Auto Bandwidth check
} # set_tc_variables

appdb(){
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
	urlpage=$(sed -nE "/$SCRIPTNAME_DISPLAY/ s/.*url\: \"(user[0-9]+\.asp)\".*/\1/p" /tmp/menuTree.js)
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
		echo "Advanced configuration available via:"
		Blue "  ${urlproto}://${urldomain}${urlport}/${urlpage}"
	fi
} # webconfigpage

scriptinfo() {
	echo ""
	Green "$SCRIPTNAME_DISPLAY v${version} released ${release}"
	if [ "$GIT_BRANCH" != "master" ]; then
		Yellow " Development channel"
	fi
	echo ""
} # scriptinfo

debug(){
	[ -z "$(nvram get odmpid)" ] && RMODEL=$(nvram get productid) || RMODEL=$(nvram get odmpid) 
	echo -n "[SPOILER=\"$SCRIPTNAME_DISPLAY Debug\"][CODE]"
	scriptinfo
	echo "Debug date: $(date +'%Y-%m-%d %H:%M:%S%z')"
	echo "Router Model: $RMODEL"
	echo "Firmware Ver: $(nvram get buildno)_$(nvram get extendno)"
	get_config
	set_tc_variables

	echo "WAN iface: $wan"
	echo "tc WAN iface: $tcwan"
	echo "Undf Prio: $undf_prio"
	echo "Down Band: $DownCeil"
	echo "Up Band  : $UpCeil"
	echo "***********"
	echo "Net Control: $Net"
	echo "Work-From-Home: $Work"
	echo "Gaming: $Gaming"
	echo "Others: $Others"
	echo "Web Surfing: $Web"
	echo "Streaming: $Streaming"
	echo "File Downloads: $Downloads"
	echo "Game Downloads: $Learn"
	echo "***********"
	if [ "$DownCeil" -gt "0" ] && [ "$UpCeil" -gt "0" ]; then
		echo "Downrates: $DownRate0, $DownRate1, $DownRate2, $DownRate3, $DownRate4, $DownRate5, $DownRate6, $DownRate7"
		echo "Downceils: $DownCeil0, $DownCeil1, $DownCeil2, $DownCeil3, $DownCeil4, $DownCeil5, $DownCeil6, $DownCeil7"
		echo "Downbursts: $DownBurst0, $DownBurst1, $DownBurst2, $DownBurst3, $DownBurst4, $DownBurst5, $DownBurst6, $DownBurst7"
		echo "DownCbursts: $DownCburst0, $DownCburst1, $DownCburst2, $DownCburst3, $DownCburst4, $DownCburst5, $DownCburst6, $DownCburst7"
		echo "DownQuantums: $DownQuantum0, $DownQuantum1, $DownQuantum2, $DownQuantum3, $DownQuantum4, $DownQuantum5, $DownQuantum6, $DownQuantum7"
		echo "***********"
		echo "Uprates: $UpRate0, $UpRate1, $UpRate2, $UpRate3, $UpRate4, $UpRate5, $UpRate6, $UpRate7"
		echo "Upceils: $UpCeil0, $UpCeil1, $UpCeil2, $UpCeil3, $UpCeil4, $UpCeil5, $UpCeil6, $UpCeil7"
		echo "Upbursts: $UpBurst0, $UpBurst1, $UpBurst2, $UpBurst3, $UpBurst4, $UpBurst5, $UpBurst6, $UpBurst7"
		echo "UpCbursts: $UpCburst0, $UpCburst1, $UpCburst2, $UpCburst3, $UpCburst4, $UpCburst5, $UpCburst6, $UpCburst7"
		echo "UpQuantums: $UpQuantum0, $UpQuantum1, $UpQuantum2, $UpQuantum3, $UpQuantum4, $UpQuantum5, $UpQuantum6, $UpQuantum7"
		echo "***********"
	else
		echo "Custom rates disabled with Automatic Bandwidth mode!"
		echo "***********"
	fi
	echo "iptables settings: $(am_settings_get flexqos_iptables)"
	write_iptables_rules
	/bin/sed -E '/^iptables -D POSTROUTING/d; s/iptables -A POSTROUTING -t mangle //g; s/[[:space:]]{2,}/ /g' /tmp/${SCRIPTNAME}_iprules
	echo "***********"
	echo "appdb rules: $(am_settings_get flexqos_appdb)"
	true > /tmp/${SCRIPTNAME}_tcrules
	write_appdb_rules
	cat /tmp/${SCRIPTNAME}_tcrules
	echo "[/CODE][/SPOILER]"
	rm /tmp/${SCRIPTNAME}_iprules /tmp/${SCRIPTNAME}_tcrules
	echo ""
	echo "Copy the text from [SPOILER] to [/SPOILER] and paste into a forum post at snbforums.com"
} # debug

get_flowid() {
	# destination field
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
	echo "$flowid"
} # get_flowid

parse_appdb_rule() {
	#requires global variables previously set by set_tc_variables
	#----------input-----------
	#$1 = mark
	#$2 = dst

	cat="${1:0:2}"
	id="${1:2:4}"

	#filter field
	if [ "${#1}" -eq "6" ]; then
		# check if wildcard mark
		if [ "$id" = "****" ]; then
			DOWN_mark="0x80${1//\*/0} 0xc03f0000"
			UP_mark="0x40${1//\*/0} 0xc03f0000"
		elif [ "$1" = "000000" ]; then
			# unidentified traffic needs a special mask
			DOWN_mark="0x80${1} 0xc000ffff"
			UP_mark="0x40${1} 0xc000ffff"
		else
			DOWN_mark="0x80${1} 0xc03fffff"
			UP_mark="0x40${1} 0xc03fffff"
		fi
	else
		# return early if mark is less than 6 characters
		return
	fi

	# destination field
	flowid="$(get_flowid "$2")"

	#prio field
	if [ "$1" = "000000" ]; then
		# special mask for unidentified traffic
		currmask="0xc000ffff"
	else
		currmask="0xc03f0000"
	fi
	prio="$(/bin/grep -i "0x80${cat}0000 ${currmask}" -B1 /tmp/${SCRIPTNAME}_tmp_tcfilterdown | head -1 | cut -d " " -f5)"
	currprio=$prio

	if [ -z "$prio" ]; then
		prio="$undf_prio"
	else
		prio="$((prio-1))"
	fi

	{
		if [ "$id" = "****" -o "$1" = "000000" ] && [ -n "$currprio" ]; then
			# change existing rule
			currhandledown="$(/bin/grep -i -m 1 -B1 "0x80${cat}0000 ${currmask}" /tmp/${SCRIPTNAME}_tmp_tcfilterdown | head -1 | cut -d " " -f8)"
			currhandleup="$(/bin/grep -i -m 1 -B1 "0x40${cat}0000 ${currmask}" /tmp/${SCRIPTNAME}_tmp_tcfilterup | head -1 | cut -d " " -f8)"
			echo "filter change dev br0 prio $currprio protocol all handle $currhandledown u32 flowid $flowid"
			echo "filter change dev $tcwan prio $currprio protocol all handle $currhandleup u32 flowid $flowid"
		else
			# add new rule for individual app one priority level higher (-1)
			echo "filter add dev br0 protocol all prio $prio u32 match mark $DOWN_mark flowid $flowid"
			echo "filter add dev $tcwan protocol all prio $prio u32 match mark $UP_mark flowid $flowid"
		fi
	}
}

parse_iptablerule() {
	#----------input-----------
	#$1=local IP			accepted XXX.XXX.XXX.XXX or !XXX.XXX.XXX.XXX
	#$2=remote IP			accepted XXX.XXX.XXX.XXX or !XXX.XXX.XXX.XXX
	#$3=protocol  			accepted tcp or udp
	#$4=local port			accepted XXXXX or XXXXX:YYYYY or XXX,YYY,ZZZ or  !XXXXX or !XXXXX:YYYYY or !XXX,YYY,ZZZ
	#$5=remote port			accepted XXXXX or XXXXX:YYYYY or XXX,YYY,ZZZ or  !XXXXX or !XXXXX:YYYYY or !XXX,YYY,ZZZ
	#$6=mark				accepted XXYYYY   (setting YYYY to **** will filter entire "XX" parent category)
	#$7=qos destination		accepted 0-7

	#local IP
	if [ "${#1}" -ge "7" ]; then
		DOWN_Lip="${1//[^!]*/} -d ${1//!/}"
		UP_Lip="${1//[^!]*/} -s ${1//!/}"
	else
		DOWN_Lip=""
		UP_Lip=""
	fi

	#remote IP
	if [ "${#2}" -ge "7" ]; then
		DOWN_Rip="${2//[^!]*/} -s ${2//!/}"
		UP_Rip="${2//[^!]*/} -d ${2//!/}"
	else
		DOWN_Rip=""
		UP_Rip=""
	fi

	#protocol (required for port rules)
	if [ "$3" = 'tcp' ] || [ "$3" = 'udp' ]; then		#if tcp/udp
		PROTO="-p ${3}"
	else
		if [ "${#4}" -gt "1" ] || [ "${#5}" -gt "1" ]; then		#if both & port rules defined
			PROTO="-p both"		#"BOTH" gets replaced with tcp & udp during later prior to rule execution
		else		#if both & port rules not defined
			PROTO=""
		fi
	fi

	#local port
	if [ "${#4}" -gt "1" ]; then
		if [ "$( echo "$4" | tr -cd ',' | wc -c )" -ge "1" ]; then
			#multiport XXX,YYY,ZZZ
			DOWN_Lport="-m multiport ${4//[^!]*/} --dports ${4//!/}"
			UP_Lport="-m multiport ${4//[^!]*/} --sports ${4//!/}"
		else
			#single port XXX or port range XXX:YYY
			DOWN_Lport="${4//[^!]*/} --dport ${4//!/}"
			UP_Lport="${4//[^!]*/} --sport ${4//!/}"
		fi
	else
		DOWN_Lport=""
		UP_Lport=""
	fi

	#remote port
	if [ "${#5}" -gt "1" ]; then
		if [ "$( echo "$5" | tr -cd ',' | wc -c )" -ge "1" ]; then
			#multiport XXX,YYY,ZZZ
			DOWN_Rport="-m multiport ${5//[^!]*/} --sports ${5//!/}"
			UP_Rport="-m multiport ${5//[^!]*/} --dports ${5//!/}"
		else
			#single port XXX or port range XXX:YYY
			DOWN_Rport="${5//[^!]*/} --sport ${5//!/}"
			UP_Rport="${5//[^!]*/} --dport ${5//!/}"
		fi
	else
		DOWN_Rport=""
		UP_Rport=""
	fi

	#match mark
	if [ "${#6}" -ge "6" ] && [ "${#6}" -le "7" ]; then
		tmpMark="$6"
		DOWN_mark="-m mark"
		UP_mark="-m mark"
		if [ "${6:0:1}" = "!" ]; then
			DOWN_mark="${DOWN_mark} !"
			UP_mark="${UP_mark} !"
			tmpMark="${tmpMark//!/}"
		fi
		if [ "${tmpMark:2:4}" = "****" ]; then
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

	#if parameters are empty return early
	if [ -z "${DOWN_Lip}${DOWN_Rip}${DOWN_Lport}${DOWN_Rport}${DOWN_mark}" ]; then
		return
	fi

	#destination mark
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
			#if destinations is empty return early
			return
			;;
	esac

	{
		if [ "$PROTO" = "-p both" ]; then
			# download ipv4
			echo "iptables -D POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO//both/tcp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO//both/tcp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
			echo "iptables -D POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO//both/udp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO//both/udp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
			# upload ipv4
			echo "iptables -D POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO//both/tcp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO//both/tcp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
			echo "iptables -D POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO//both/udp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO//both/udp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
			if [ -z "$DOWN_Lip" ] && [ -z "$DOWN_Rip" ] && [ "$IPv6_enabled" != "disabled" ]; then
				# download ipv6
				echo "ip6tables -D POSTROUTING -t mangle -o br0 ${PROTO//both/tcp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o br0 ${PROTO//both/tcp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
				echo "ip6tables -D POSTROUTING -t mangle -o br0 ${PROTO//both/udp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o br0 ${PROTO//both/udp} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
				# upload ipv6
				echo "ip6tables -D POSTROUTING -t mangle -o ${wan} ${PROTO//both/tcp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o ${wan} ${PROTO//both/tcp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
				echo "ip6tables -D POSTROUTING -t mangle -o ${wan} ${PROTO//both/udp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o ${wan} ${PROTO//both/udp} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
			fi
		else
			# download ipv4
			echo "iptables -D POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o br0 ${DOWN_Lip} ${DOWN_Rip} ${PROTO} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
			# upload ipv4
			echo "iptables -D POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
			echo "iptables -A POSTROUTING -t mangle -o ${wan} ${UP_Lip} ${UP_Rip} ${PROTO} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
			if [ -z "$DOWN_Lip" ] && [ -z "$DOWN_Rip" ] && [ "$IPv6_enabled" != "disabled" ]; then
				# download ipv6
				echo "ip6tables -D POSTROUTING -t mangle -o br0 ${PROTO} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o br0 ${PROTO} ${DOWN_Lport} ${DOWN_Rport} ${DOWN_mark} ${DOWN_dst}"
				# upload ipv6
				echo "ip6tables -D POSTROUTING -t mangle -o ${wan} ${PROTO} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst} >/dev/null 2>&1"
				echo "ip6tables -A POSTROUTING -t mangle -o ${wan} ${PROTO} ${UP_Lport} ${UP_Rport} ${UP_mark} ${UP_dst}"
			fi
		fi
	} >> /tmp/${SCRIPTNAME}_iprules
}

about() {
	scriptinfo
	echo "License"
	echo "  $SCRIPTNAME_DISPLAY is free to use under the GNU General Public License, version 3 (GPL-3.0)."
	Blue "  https://opensource.org/licenses/GPL-3.0"
	echo ""
	echo "For discussion visit this thread:"
	Blue "  https://www.snbforums.com/threads/64882/"
	Blue "  https://github.com/dave14305/FlexQoS (Source Code)"
	echo ""
	echo "About"
	echo "  Script Changes Unidentified traffic destination away from Work-From-Home into Others"
	echo "  Script Changes HTTPS traffic destination away from Net Control into Web Surfing"
	echo "  Script Changes Guaranteed Bandwidth per QoS category into logical percentages of upload and download."
	echo "  Script Repurposes Learn-From-Home to contain Game Downloads"
	echo ""
	echo "  Script includes misc default rules"
	echo "   (Wifi Calling)  -  UDP traffic on remote ports 500 & 4500 moved into Work-From-Home"
	echo "   (Facetime)      -  UDP traffic on local  ports 16384 - 16415 moved into Work-From-Home"
	echo "   (Usenet)        -  TCP traffic on remote ports 119 & 563 moved into Downloads"
	echo "   (Gaming)        -  Gaming TCP traffic from remote ports 80 & 443 moved into Game Downloads."
	echo "   (Snapchat)      -  Moved into Others"
	echo "   (Speedtest.net) -  Moved into Downloads"
	echo "   (Google Play)   -  Moved into Downloads"
	echo "   (Apple AppStore)-  Moved into Downloads"
	echo "   (Advertisement) -  Moved into Downloads"
	echo "   (VPN Fix)       -  Router VPN Client upload traffic moved into Downloads instead of whitelisted"
	echo "   (Gaming Manual) -  Unidentified traffic for specified devices, not originating from ports 80/443, moved into Gaming"
	echo ""
	Red  "Gaming Rule Note"
	echo "  Gaming traffic originating from ports 80 & 443 is primarily downloads & patches (some lobby/login protocols mixed within)"
	echo "  Manually configurable rule will take untracked traffic for specified devices, not originating from server ports 80/443, and place it into Gaming"
	echo "  Use of this gaming rule REQUIRES devices to have a continous static ip assignment & this range needs to be passed into the script"
}

backup() {
	case "$1" in
		'create')
			if [ "$2" != "force" ] && [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
				echo -n "A backup already exists. Do you want to overwrite this backup? [1=Yes 2=No] "
				read -r yn
				if [ "$yn" != "1" ]; then
					Yellow "Backup cancelled."
					return
				fi
			fi
			echo "Running backup..."
			{
				echo "#!/bin/sh"
				echo "# Backup date: $(date +'%Y-%m-%d %H:%M:%S%z')"
				echo ". /usr/sbin/helper.sh"
				echo "am_settings_set flexqos_iptables \"$(am_settings_get flexqos_iptables)\""
				echo "am_settings_set flexqos_iptables_names \"$(am_settings_get flexqos_iptables_names)\""
				echo "am_settings_set flexqos_appdb \"$(am_settings_get flexqos_appdb)\""
				echo "am_settings_set flexqos_bandwidth \"$(am_settings_get flexqos_bandwidth)\""
			} > "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
			Green "Backup done to ${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
		;;
		'restore')
			if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
				Yellow "$(grep "# Backup date" "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh")"
				echo -n "Do you want to restore this backup? [1=Yes 2=No] "
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
}

download_file() {
	if [ "$(curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/${1}" | md5sum | awk '{print $1}')" != "$(md5sum "$2" 2>/dev/null | awk '{print $1}')" ]; then
		if curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/${1}" -o "$2"; then
			logmsg "Updated $(echo "$1" | awk -F / '{print $NF}')"
		else
			logmsg "Updating $(echo "$1" | awk -F / '{print $NF}') failed"
		fi
	else
		logmsg "File $(echo "$2" | awk -F / '{print $NF}') is already up-to-date"
	fi
} # download_file

compare_remote_version() {
	remotever="$(curl -fsN --retry 3 --connect-timeout 3 "${GIT_URL}/${SCRIPTNAME}.sh" | /bin/grep "^version=" | sed -e 's/version=//')"
	if [ "${version//.}" -lt "${remotever//.}" ]; then
		# version upgrade
		echo "$remotever"
		return
	fi
	localmd5="$(md5sum "$0" | awk '{print $1}')"
	remotemd5="$(curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/${SCRIPTNAME}.sh" | md5sum | awk '{print $1}')"
	localmd5asp="$(md5sum "$WEBUIPATH" | awk '{print $1}')"
	remotemd5asp="$(curl -fsL --retry 3 --connect-timeout 3 "${GIT_URL}/${SCRIPTNAME}.asp" | md5sum | awk '{print $1}')"
	if [ "$localmd5" != "$remotemd5" ] || [ "$localmd5asp" != "$remotemd5asp" ]; then
		# hotfix
		echo "Hotfix"
		return
	fi
	echo "NoUpdate"
} # compare_remote_version

update() {
	scriptinfo
	echo "Checking for updates"
	printf "var verUpdateStatus = \"%s\";\n" "InProgress" > /www/ext/${SCRIPTNAME}/detect_update.js
	updateversion="$(compare_remote_version)"
	printf "var verUpdateStatus = \"%s\";\n" "$updateversion" > /www/ext/${SCRIPTNAME}/detect_update.js

	if [ "$1" = "check" ]; then
		return
	fi
	if ! [ "$1" = "silent" ]; then
		case "$updateversion" in
		'NoUpdate')
			Green " You have the latest version installed"
			echo -n " Would you like to overwrite your existing installation anyway? [1=Yes 2=No] : "
			;;
		'Hotfix')
			Green " $SCRIPTNAME_DISPLAY hotfix is available."
			echo -n " Would you like to update now? [1=Yes 2=No] : "
			;;
		*)
			# New Version Number
			Green " $SCRIPTNAME_DISPLAY v${updateversion} is now available!"
			echo -n " Would you like to update now? [1=Yes 2=No] : "
			;;
		esac
		read -r yn
		echo ""
		if ! [ "$yn" = "1" ]; then
			Green " No Changes have been made"
			return 0
		fi
	else
		echo "Installing: ${SCRIPTNAME_DISPLAY}..."
		echo ""
		download_file "${SCRIPTNAME}.sh" "$SCRIPTPATH"
		exec sh "$SCRIPTPATH" -install "$1"
		exit
	fi
}

prompt_restart() {
	unset yn
	if [ "$1" = "force" ]; then
		yn="1"
		needrestart=1
	fi
	if [ "$needrestart" = "1" ]; then
		if [ -z "$yn" ]; then
			echo ""
			echo -n "Would you like to restart QoS for modifications to take effect? [1=Yes 2=No]: "
			read -r yn
		fi
		if [ "$yn" = "1" ]; then
			if /bin/grep -q "${SCRIPTPATH} -start & " /jffs/scripts/service-event-end ; then
				echo "Restarting QoS..."
				service restart_qos
			else
				Red "$SCRIPTNAME_DISPLAY is not installed correctly. Please update or reinstall."
			fi
		else
			echo ""
			Yellow "$SCRIPTNAME_DISPLAY customizations will not take effect until QoS is restarted."
		fi
		unset needrestart
	fi
} # prompt_restart

menu() {
	clear
	sed -n '2,10p' "$0"
	scriptinfo
	echo "  (1) about        explain functionality"
	echo "  (2) update       check for updates "
	echo "  (3) debug        traffic control parameters"
	echo "  (4) restart      restart QoS and firewall"
	echo "  (5) backup       create settings backup"
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		echo "  (6) restore      restore settings from backup"
		echo "  (7) delete       remove backup"
	fi
	echo ""
	echo "  (9) uninstall    uninstall script"
	echo "  (e) exit"
	echo ""
	echo -n "Make a selection: "
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
			backup restore
		;;
		'7')
			backup remove
		;;
		'9')
			scriptinfo
			echo -n " Confirm you want to uninstall $SCRIPTNAME_DISPLAY [1=Yes 2=No] : "
			read -r yn
			if [ "$yn" = "1" ]; then
				echo ""
				sh ${SCRIPTPATH} -uninstall
				echo ""
				exit
			fi
			echo ""
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
	menu
}

remove_webui() {
	echo "Removing WebUI..."
	am_get_webui_page "$WEBUIPATH"

	if [ -n "$am_webui_page" ] && [ "$am_webui_page" != "none" ]; then
		if [ -f /tmp/menuTree.js ]; then
			umount /www/require/modules/menuTree.js 2>/dev/null
			sed -i "\~tabName: \"FlexQoS\"},~d" /tmp/menuTree.js
			if diff -q /tmp/menuTree.js /www/require/modules/menuTree.js > /dev/null 2>&1 ; then
				rm /tmp/menuTree.js
			else
				# Still some modifications from another script so remount
				mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
			fi
			if [ -f /www/user/"$am_webui_page" ]; then
				rm /www/user/"$am_webui_page"
			fi
		fi
		/bin/grep -l "FlexQoS maintained by dave14305" /www/user/user*.asp 2>/dev/null | while read -r oldfile
		do
			rm "$oldfile"
		done
	fi
	rm -rf /www/ext/${SCRIPTNAME}		# remove js helper scripts
}

install_webui() {
	# if this is an install or update...otherwise it's a normal startup/mount
	if [ -z "$1" ]; then
		echo "Downloading WebUI files..."
		download_file "${SCRIPTNAME}.asp" "$WEBUIPATH"
		# cleanup obsolete files
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
		if ! /bin/grep -q "{url: \"$am_webui_page\", tabName: \"FlexQoS\"}," /tmp/menuTree.js; then
			umount /www/require/modules/menuTree.js 2>/dev/null
			sed -i "\~tabName: \"FlexQoS\"},~d" /tmp/menuTree.js
			sed -i "/url: \"QoS_Stats.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"FlexQoS\"}," /tmp/menuTree.js
			mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
		fi
	fi
	[ ! -d "/www/ext/${SCRIPTNAME}" ] && mkdir -p "/www/ext/${SCRIPTNAME}"
}

Init_UserScript() {
	if [ -z "$1" ]; then
		return
	fi
	userscript="/jffs/scripts/$1"
	if [ ! -f "$userscript" ]; then
		printf "#!/bin/sh\n\n" > "$userscript"
	elif [ -f "$userscript" ] && ! head -1 "$userscript" | /bin/grep -qE "^#!/bin/sh"; then
		sed -i '1s~^~#!/bin/sh\n~' "$userscript"
	elif [ "$(tail -c1 "$userscript" | wc -l)" = "0" ]; then
		printf "\n" >> "$userscript"
	fi
	if [ ! -x "$userscript" ]; then
		chmod 755 "$userscript"
	fi
} # Init_UserScript

Auto_ServiceEventEnd() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	Init_UserScript "service-event-end"
	sed -i '\~FlexQoS Addition~d' /jffs/scripts/service-event-end
	cmdline="if [ \"\$2\" = \"qos\" ] || [ \"\$2\" = \"wrs\" ] || [ \"\$2\" = \"sig_check\" ]; then { sh ${SCRIPTPATH} -start & } ; fi # FlexQoS Addition"
	echo "$cmdline" >> /jffs/scripts/service-event-end
	cmdline="if echo \"\$2\" | /bin/grep -q \"^${SCRIPTNAME}\"; then { sh ${SCRIPTPATH} \"\${2#${SCRIPTNAME}}\" & } ; fi # FlexQoS Addition"
	echo "$cmdline" >> /jffs/scripts/service-event-end
}

Auto_FirewallStart() {
	# Borrowed from Adamm00
	# https://github.com/Adamm00/IPSet_ASUS/blob/master/firewall.sh
	Init_UserScript "firewall-start"
	sed -i '\~FlexQoS Addition~d' /jffs/scripts/firewall-start
	cmdline="sh ${SCRIPTPATH} -start & # FlexQoS Addition"
	if /bin/grep -vE "^#" /jffs/scripts/firewall-start | /bin/grep -q "Skynet"; then
		# If Skynet also installed, insert this script before it so it doesn't have to wait until Skynet to startup before applying QoS
		# Won't delay Skynet startup since we fork into the background
		sed -i "/Skynet/i $cmdline" /jffs/scripts/firewall-start
	else
		# Skynet not installed, so just append
		echo "$cmdline" >> /jffs/scripts/firewall-start
	fi # is Skynet also installed?
} # Auto_FirewallStart

Auto_Crontab() {
	cru a ${SCRIPTNAME} "30 3 * * * ${SCRIPTPATH} -check"
	Init_UserScript "services-start"
	sed -i '\~FlexQoS Addition~d' /jffs/scripts/services-start
	cmdline="cru a ${SCRIPTNAME} \"30 3 * * * ${SCRIPTPATH} -check\" # FlexQoS Addition"
	echo "$cmdline" >> /jffs/scripts/services-start
} # Auto_Crontab

setup_aliases() {
	# shortcuts to launching script
	if [ -d /opt/bin ]; then
		echo "Adding ${SCRIPTNAME} link in Entware /opt/bin..."
		ln -sf "$SCRIPTPATH" /opt/bin/${SCRIPTNAME}
	else
		echo "Adding ${SCRIPTNAME} alias in profile.add..."
		sed -i "/alias ${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
		alias ${SCRIPTNAME}="sh ${SCRIPTPATH}"
		echo "alias ${SCRIPTNAME}=\"sh ${SCRIPTPATH}\" # FlexQoS Addition" >> /jffs/configs/profile.add
	fi
} # setup_aliases

Firmware_Check() {
	echo "Checking firmware support..."
	if ! nvram get rc_support | grep -q am_addons; then
		Red "$SCRIPTNAME_DISPLAY requires ASUSWRT-Merlin Addon API support. Installation aborted."
		echo ""
		echo "Install FreshJR_QOS via amtm as an alternative for your firmware version."
		return 1
	fi
	if [ "$(nvram get qos_enable)" != "1" ] || [ "$(nvram get qos_type)" != "1" ]; then
		Red "Adaptive QoS is not enabled. Please enable it in the GUI. Aborting installation."
		return 1
	fi # adaptive qos not enabled
	if [ "$(nvram get jffs2_scripts)" != "1" ]; then
		Red "\"Enable JFFS custom scripts and configs\" is not enabled. Please enable it in the GUI. Aborting installation."
		return 1
	fi # JFFS custom scripts not enabled
} # Firmware_Check

install() {
	if ! [ "$1" = "silent" ]; then
		clear
		scriptinfo
		echo "Installing $SCRIPTNAME_DISPLAY..."
		if ! Firmware_Check; then
			PressEnter
			rm -f "$0" 2>/dev/null
			exit 5
		fi
	fi
	if ! [ -d "$ADDON_DIR" ]; then
		echo "Creating directories..."
		mkdir -p "$ADDON_DIR"
		chmod 755 "$ADDON_DIR"
	fi
	if ! [ -f "$SCRIPTPATH" ]; then
		cp -p "$0" "$SCRIPTPATH"
	fi
	if ! [ -x "$SCRIPTPATH" ]; then
		chmod +x "$SCRIPTPATH"
	fi
	install_webui
	generate_bwdpi_arrays force
	echo "Adding $SCRIPTNAME_DISPLAY entries to Merlin user scripts..."
	Auto_FirewallStart
	Auto_ServiceEventEnd
	echo "Adding nightly cron job..."
	Auto_Crontab
	setup_aliases

	if ! [ "$1" = "silent" ]; then
		Green "$SCRIPTNAME_DISPLAY installation complete!"
		scriptinfo
		webconfigpage

		if [ -f "${ADDON_DIR}/restore_flexqos_settings.sh" ] && ! /bin/grep -qE "^flexqos_[^(ver )]" /jffs/addons/custom_settings.txt ; then
			echo ""
			Green "Backup found!"
			backup restore
		fi
		[ "$(nvram get qos_enable)" = "1" ] && needrestart=1
	else
		[ "$(nvram get qos_enable)" = "1" ] && prompt_restart force
	fi
	sed -i "/^${SCRIPTNAME}_conntrack /d" /jffs/addons/custom_settings.txt
} # install

uninstall() {
	echo "Removing entries from Merlin user scripts..."
	sed -i '/FlexQoS/d' /jffs/scripts/firewall-start 2>/dev/null
	sed -i '/FlexQoS/d' /jffs/scripts/service-event-end 2>/dev/null
	sed -i '/FlexQoS/d' /jffs/scripts/services-start 2>/dev/null
	echo "Removing aliases and shortcuts..."
	sed -i "/${SCRIPTNAME}/d" /jffs/configs/profile.add 2>/dev/null
	rm -f /opt/bin/${SCRIPTNAME} 2>/dev/null
	echo "Removing cron job..."
	cru d "$SCRIPTNAME"
	cru d "${SCRIPTNAME}_5min" 2>/dev/null
	remove_webui
	echo "Removing $SCRIPTNAME_DISPLAY settings..."
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		echo -n "Backup found! Would you like to delete it? [1=Yes 2=No]: "
		read -r yn
		if [ "$yn" = "1" ]; then
			echo "Deleting Backup..."
			rm "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh"
		fi
	else
		echo -n "Do you want to backup your settings before uninstall? [1=Yes 2=No]: "
		read -r yn
		if [ "$yn" = "1" ]; then
			echo "Backing up $SCRIPTNAME_DISPLAY settings..."
			backup create force
		fi
	fi
	sed -i "/^${SCRIPTNAME}_/d" /jffs/addons/custom_settings.txt
	if [ -f "${ADDON_DIR}/restore_${SCRIPTNAME}_settings.sh" ]; then
		echo "Deleting $SCRIPTNAME_DISPLAY folder contents except Backup file..."
		/usr/bin/find ${ADDON_DIR} ! -name restore_${SCRIPTNAME}_settings.sh ! -exec test -d {} \; -a -exec rm {} +
	else
		echo "Deleting $SCRIPTNAME_DISPLAY directory..."
		rm -rf "$ADDON_DIR"
	fi
	Green "$SCRIPTNAME_DISPLAY has been uninstalled"
	needrestart=1
} # uninstall

get_config() {
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
#	iptables_names="$(am_settings_get ${SCRIPTNAME}_iptables_names)"
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
	iptables_rules_defined="$(echo "$iptables_rules" | sed 's/</\n/g' | /bin/grep -vc "^$")"
	iptables_rules_expected=$((iptables_rules_defined*2))
	iptables_rulespresent="$(/usr/sbin/iptables -t mangle -S POSTROUTING | /bin/grep -c MARK)"
	if [ "$iptables_rulespresent" -lt "$iptables_rules_expected" ]; then
		return 1
	else
		return 0
	fi
} # validate_iptables_rules

write_iptables_rules() {
	# loop through iptables rules and write an iptables command to a temporary script file
	OLDIFS="$IFS"
	IFS=">"
	if [ -f "/tmp/${SCRIPTNAME}_iprules" ]; then
		rm -f "/tmp/${SCRIPTNAME}_iprules"
	fi

	echo "$iptables_rules" | sed 's/</\n/g' | while read -r localip remoteip proto lport rport mark class
	do
		if [ -n "${localip}${remoteip}${proto}${lport}${rport}${mark}" ]; then
			parse_iptablerule "$localip" "$remoteip" "$proto" "$lport" "$rport" "$mark" "$class"
		fi
	done
	IFS="$OLDIFS"
} # write_iptables_rules

write_appdb_rules() {
	${tc} filter show dev br0 parent 1: > /tmp/${SCRIPTNAME}_tmp_tcfilterdown
	${tc} filter show dev ${tcwan} parent 1: > /tmp/${SCRIPTNAME}_tmp_tcfilterup

	# loop through appdb rules and write a tc command to a temporary script file
	OLDIFS="$IFS"
	IFS=">"
	echo "$appdb_rules" | sed 's/</\n/g' | while read -r mark class
	do
		if [ -n "$mark" ]; then
			parse_appdb_rule "$mark" "$class" >> /tmp/${SCRIPTNAME}_tcrules
		fi
	done
	IFS="$OLDIFS"
} # write_appdb_rules

check_qos_tc() {
	dlclasscnt="$(${tc} class show dev br0 parent 1: | /bin/grep -c "parent")" # should be 8
	dlfiltercnt="$(${tc} filter show dev br0 parent 1: | /bin/grep -cE "flowid 1:1[0-7] *$")" # should be 39 or 40
	if [ "$dlclasscnt" -lt "8" ] || [ "$dlfiltercnt" -lt "39" ] || [ -z "$(${tc} qdisc ls | sed -n 's/qdisc htb.*dev \([^b][^r].*\) root.*/\1/p')" ]; then
		return 0
	fi
	return 1
} # check_qos_tc

validate_tc_rules() {
	{
		${tc} filter show dev br0 parent 1: | sed -nE '/flowid/ { N; s/\n//g; s/.*flowid (1:1[0-7]).*mark 0x[48]0([0-9a-fA-F]{6}).*/<\2>\1/p }'
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
				break
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
			# Flush conntrack table so that existing connections will be processed by new iptables rules
			logmsg "Flushing conntrack table"
			/usr/sbin/conntrack -F conntrack >/dev/null 2>&1
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
	echo ""
	echo "Available commands:"
	echo ""
	echo "  ${SCRIPTNAME} -about              explains functionality"
	echo "  ${SCRIPTNAME} -appdb string       search appdb for application marks"
	echo "  ${SCRIPTNAME} -update             checks for updates"
	echo "  ${SCRIPTNAME} -restart            restart QoS and Firewall"
	echo "  ${SCRIPTNAME} -install            install   script"
	echo "  ${SCRIPTNAME} -uninstall          uninstall script & delete from disk"
	echo "  ${SCRIPTNAME} -enable             enable    script"
	echo "  ${SCRIPTNAME} -disable            disable   script but do not delete from disk"
	echo "  ${SCRIPTNAME} -backup             backup user settings"
	echo "  ${SCRIPTNAME} -debug              print debug info"
	echo "  ${SCRIPTNAME} -develop            switch to development channel"
	echo "  ${SCRIPTNAME} -stable             switch to stable channel"
	echo "  ${SCRIPTNAME} -menu               interactive main menu"
	echo ""
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
	echo ""
	while true; do
		echo -n "Press enter to continue..."
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
	echo "$$" > /tmp/${SCRIPTNAME}.lock
	lock="true"
} # Check_Lock

get_wanif() {
prefixes="wan0_ wan1_"

if [ "$(nvram get wans_mode)" = "lb" ] ; then
	primary="0"
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

	[ "$primary" = "1" ] || exit 1

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
#if [ -z "$2" ]; then
#	wan="$(nvram get wan0_ifname)"
#else
#	wan="$2"
#fi

case "$arg1" in
	'start'|'check')
		logmsg "$0 (pid=$$) called with $# args: $*"
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
		prompt_restart force
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
			echo "Already set to development branch."
		else
			am_settings_set "${SCRIPTNAME}_branch" "develop"
			echo "Set to development branch. Triggering update..."
			exec "$0" updatesilent
		fi
		;;
	'stable')
		if [ -z "$(am_settings_get "${SCRIPTNAME}_branch")" ]; then
			echo "Already set to stable branch."
		else
			sed -i "/^${SCRIPTNAME}_branch /d" /jffs/addons/custom_settings.txt
			echo "Set to stable branch. Triggering update..."
			exec "$0" updatesilent
		fi
		;;
	'menu'|'')
		menu
		;;
	'restart')
		prompt_restart force
		;;
	*)
		show_help
		;;
esac

prompt_restart
if [ "$lock" = "true" ]; then rm -rf "/tmp/${SCRIPTNAME}.lock"; fi
