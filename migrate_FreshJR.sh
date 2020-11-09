#!/bin/sh

# initialize Merlin Addon API helper functions
. /usr/sbin/helper.sh

if [ ! -f /jffs/scripts/FreshJR_QOS ]; then
	# FreshJR_QOS not installed
	exit
fi
echo "Removing old FreshJR_QOS files. Reinstall with amtm if necessary."
# Remove profile aliases
echo -n "Removing profile aliases..."
sed -i '/FreshJR_QOS/d' /jffs/configs/profile.add 2>/dev/null && Green "Done." || Red "Failed!"
# Remove cron
echo -n "Removing cron job..."
cru d FreshJR_QOS 2>/dev/null && Green "Done." || Red "Failed!"
# Remove mount
if mount | /bin/grep -q QoS_Stats.asp; then
	echo -n "Removing old webui mount..."
	umount /www/QoS_Stats.asp 2>/dev/null && Green "Done." || Red "Failed!"
fi
# Remove entries from scripts
echo -n "Removing firewall-start entry..."
sed -i '/FreshJR_QOS/d' /jffs/scripts/firewall-start 2>/dev/null && Green "Done." || Red "Failed!"
# Remove script file
if [ -f /jffs/scripts/FreshJR_QOS ]; then
	echo -n "Removing FreshJR_QOS script..."
	rm -f /jffs/scripts/FreshJR_QOS 2>/dev/null && Green "Done." || Red "Failed!"
fi
# Remove asp file
if [ -f /jffs/scripts/www_FreshJR_QoS_Stats.asp ]; then
	echo -n "Removing FreshJR_QOS webpage..."
	rm -f /jffs/scripts/www_FreshJR_QoS_Stats.asp 2>/dev/null && Green "Done." || Red "Failed!"
fi
# convert_nvram
OLDIFS=$IFS
IFS=";"

if [ "$(nvram get fb_comment | sed 's/>/;/g' | tr -cd ';' | wc -c)" = "20" ] && [ -z "$(am_settings_get flexqos_iptables)" ]; then
	read \
		e1 e2 e3 e4 e5 e6 e7 \
		f1 f2 f3 f4 f5 f6 f7 \
		g1 g2 g3 g4 g5 g6 g7 \
	<<EOF
$(nvram get fb_comment | sed 's/>/;/g' )
EOF
fi
if [ "$(nvram get fb_email_dbg | sed 's/>/;/g' | tr -cd ';' | wc -c)" = "48" ]; then
	read \
		h1 h2 h3 h4 h5 h6 h7 \
		r1 d1 \
		r2 d2 \
		r3 d3 \
		r4 d4 \
		gameCIDR \
		ruleFLAG \
		drp0 drp1 drp2 drp3 drp4 drp5 drp6 drp7 \
		dcp0 dcp1 dcp2 dcp3 dcp4 dcp5 dcp6 dcp7 \
		urp0 urp1 urp2 urp3 urp4 urp5 urp6 urp7 \
		ucp0 ucp1 ucp2 ucp3 ucp4 ucp5 ucp6 ucp7 \
	<<EOF
$(nvram get fb_email_dbg | sed 's/>/;/g' )
EOF
fi

IFS=$OLDIFS

if [ -z "$(am_settings_get flexqos_iptables)" ]; then
	if [ "$gameCIDR" ]; then
		tmp_iptables_rules="<${gameCIDR}>>both>>!80,443>000000>1"
		tmp_iptables_names="<Gaming"
	fi
	tmp_iptables_rules="${tmp_iptables_rules}<>>udp>>500,4500>>3<>>udp>16384:16415>>>3<>>tcp>>119,563>>5<>>tcp>>80,443>08****>7"
	tmp_iptables_names="${tmp_iptables_names}<WiFi%20Calling<Facetime<Usenet<Game%20Downloads"
	# if e1-7 blank, don't write name
	if [ -n "${e1}${e2}${e4}${e5}${e6}" ]; then
		tmp_iptables_rules="${tmp_iptables_rules}<${e1}>${e2}>${e3}>${e4}>${e5}>${e6}>${e7}"
		tmp_iptables_names="${tmp_iptables_names}<FreshJR%20Rule%201"
	fi
	if [ -n "${f1}${f2}${f4}${f5}${f6}" ]; then
		tmp_iptables_rules="${tmp_iptables_rules}<${f1}>${f2}>${f3}>${f4}>${f5}>${f6}>${f7}"
		tmp_iptables_names="${tmp_iptables_names}<FreshJR%20Rule%202"
	fi
	if [ -n "${g1}${g2}${g4}${g5}${g6}" ]; then
		tmp_iptables_rules="${tmp_iptables_rules}<${g1}>${g2}>${g3}>${g4}>${g5}>${g6}>${g7}"
		tmp_iptables_names="${tmp_iptables_names}<FreshJR%20Rule%203"
	fi
	if [ -n "${h1}${h2}${h4}${h5}${h6}" ]; then
		tmp_iptables_rules="${tmp_iptables_rules}<${h1}>${h2}>${h3}>${h4}>${h5}>${h6}>${h7}"
		tmp_iptables_names="${tmp_iptables_names}<FreshJR%20Rule%204"
	fi
	am_settings_set flexqos_iptables "$tmp_iptables_rules"
	am_settings_set flexqos_iptables_names "$tmp_iptables_names"
fi

if [ -z "$(am_settings_get flexqos_appdb)" ]; then
	tmp_appdb_rules="<000000>6<00006B>6<0D0007>5<0D0086>5<0D00A0>5<12003F>4"
	if [ -n "$r1" ]; then
		tmp_appdb_rules="${tmp_appdb_rules}<${r1}>${d1}"
	fi
	if [ -n "$r2" ]; then
		tmp_appdb_rules="${tmp_appdb_rules}<${r2}>${d2}"
	fi
	if [ -n "$r3" ]; then
		tmp_appdb_rules="${tmp_appdb_rules}<${r3}>${d3}"
	fi
	if [ -n "$r4" ]; then
		tmp_appdb_rules="${tmp_appdb_rules}<${r4}>${d4}"
	fi
	tmp_appdb_rules="${tmp_appdb_rules}<13****>4<14****>4<1A****>5"
	am_settings_set flexqos_appdb "$tmp_appdb_rules"
fi

if [ -z "$(am_settings_get flexqos_bandwidth)" ]; then
	am_settings_set flexqos_bandwidth "<${drp0}>${drp1}>${drp2}>${drp3}>${drp4}>${drp5}>${drp6}>${drp7}<${dcp0}>${dcp1}>${dcp2}>${dcp3}>${dcp4}>${dcp5}>${dcp6}>${dcp7}<${urp0}>${urp1}>${urp2}>${urp3}>${urp4}>${urp5}>${urp6}>${urp7}<${ucp0}>${ucp1}>${ucp2}>${ucp3}>${ucp4}>${ucp5}>${ucp6}>${ucp7}"
fi

if [ ! -f "/jffs/addons/flexqos/restore_freshjr_nvram.sh" ]; then
	{
		echo "nvram set fb_comment=\"$(nvram get fb_comment)\""
		echo "nvram set fb_email_dbg=\"$(nvram get fb_email_dbg)\""
		echo "nvram commit"
	} > "/jffs/addons/flexqos/restore_freshjr_nvram.sh"
	echo "FreshJR_QOS settings backed up to /jffs/addons/flexqos/restore_freshjr_nvram.sh"
fi
nvram set fb_comment=""
nvram set fb_email_dbg=""
nvram commit
