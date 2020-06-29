<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
FlexQoS v0.9.0 released 06/xx/2020
FlexQoS maintained by dave14305
Forked from FreshJR_QOS v8.8, written by FreshJR07 https://github.com/FreshJR07/FreshJR_QOS
-->
<html xmlns="http://www.w3.org/1999/xhtml">
<html xmlns:v>
<head>
<meta http-equiv="X-UA-Compatible" content="IE=Edge"/>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<meta HTTP-EQUIV="Pragma" CONTENT="no-cache">
<meta HTTP-EQUIV="Expires" CONTENT="-1">
<link rel="shortcut icon" href="images/favicon.png">
<link rel="icon" href="images/favicon.png">
<title>FlexQoS</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="usp_style.css">
<link rel="stylesheet" type="text/css" href="/js/table/table.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/js/chart.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<script type="text/javascript" src="/ext/flexqos/table.js"></script>
<script type="text/javascript" src="/ext/flexqos/flexqos_arrays.js"></script>
<style>
.list_table td {
font-family: Arial, Verdana, Helvetica;
}
span.cat0{
background-color:#B3645B;
}
span.cat1{
background-color:#B98F53;
}
span.cat2{
background-color:#C6B36A;
}
span.cat3{
background-color:#849E75;
}
span.cat4{
background-color:#4C8FC0;
}
span.cat5{
background-color:#7C637A;
}
span.cat6{
background-color:#2B6692;
}
span.cat7{
background-color:#6C604F;
}
span.catrow{
padding: 4px 8px 4px 8px; color: white !important;
border-radius: 5px; border: 1px #2C2E2F solid;
white-space: nowrap;
}
td.t_item{
cursor:default;
}
span.t_mark{
display:none;
}
td.t_item:active span.t_label{
display:none;
}
td.t_item:active span.t_mark{
display:inline;
}
</style>

<script>
var custom_settings = <% get_custom_settings(); %>;
var device = {};		// devices database --> device["IP"] = { mac: "AA:BB:CC:DD:EE:FF" , name:"name" }
var clientlist = <% get_clientlist_from_json_database(); %>;		// data from /jffs/nmp_cl_json.js (used to correlate mac addresses to corresponding device names  )
var tablesize = 500;		//max size of tracked connections table
var tabledata;		//tabled of tracked connections after device-filtered
var filter = Array(6);
var sortmode=6;		//current sort mode of tracked connections table (default =6)
var dhcp_start = "<% nvram_get("dhcp_start"); %>";
dhcp_start = dhcp_start.substr(0, dhcp_start.lastIndexOf(".")+1);
var ipv6prefix = "<% nvram_get("ipv6_prefix"); %>".replace(/::$/,":");

var iptables_rulelist_array="";
var iptables_temp_array=[];
var appdb_temp_array=[];
var appdb_rulelist_array="";
var rules = [];	// array for iptables rules
var gameCIDR;		// CIDR/IP of game devices
//Syntax Hints
var ipsyntaxL = '<b>Syntax:</b> <p>&emsp;&nbsp;192.168.X.XXX</p> <p>&emsp;!192.168.X.XXX</p> <p>&nbsp;</p> <p>&emsp;&nbsp;192.168.X.XXX/CIDR</p> <p>&emsp;!192.168.X.XXX/CIDR</p>';
var ipsyntaxR = '<b>Syntax:</b> <p>&emsp;&nbsp;75.75.75.75</p> <p>&emsp;!75.75.75.75</p> <p>&nbsp;</p> <p>&emsp;&nbsp;75.75.75.75/CIDR</p> <p>&emsp;!75.75.75.75/CIDR</p>';
var protosyntax = '<b>Protocol</b> <p>&nbsp;&nbsp;TCP OR UDP</p> <p>&nbsp;</p> <b>Note:</b> <p>Conditional Evaluation</p> <p>(only with port rules)</p>' ;
var portsyntax = '<b>Syntax:</b> <p>&emsp;&nbsp;XXX</p> <p>&emsp;!XXX</p> <p>&nbsp;</p> <p>&emsp;&nbsp;XXXX:YYYY</p> <p>&emsp;!XXXX:YYYY</p> <p>&nbsp;</p> <p>&emsp;&nbsp;XXX,YYY,ZZZ</p> <p>&emsp;!XXX,YYY,ZZZ</p>';
var marksyntax = '<b>Syntax:</b> <p>&nbsp;&nbsp;XXYYYY</p> <p>&nbsp;</p> <p><b>Note:</b></p> <p>XX&nbsp;&nbsp;&nbsp; - Cat (hex)</p> <p>YYYY - ID &nbsp;(hex or ****)</p> ';
var classsyntax = '<b>Class:</b> <p>&nbsp;&nbsp;Traffic Destination</p>';

var qos_type = "<% nvram_get("qos_type"); %>";
if ("<% nvram_get("qos_enable"); %>" == 0) { // QoS disabled
	var qos_mode = 0;
} else if (bwdpi_support && (qos_type == "1")) { // aQoS
	var qos_mode = 2;
} else if (qos_type == "0") { // tQoS
	var qos_mode = 1;
} else if (qos_type == "2") { // BW limiter
	var qos_mode = 3;
} else { // invalid mode
	var qos_mode = 0;
}

if (qos_mode == 2) {
	var bwdpi_app_rulelist = "<% nvram_get("bwdpi_app_rulelist"); %>".replace(/&#60/g, "<");
	var bwdpi_app_rulelist_row = bwdpi_app_rulelist.split("<");
	if (bwdpi_app_rulelist == "" || bwdpi_app_rulelist_row.length != 9) {
		bwdpi_app_rulelist = "9,20<8<4<0,5,6,15,17<4,13<13,24<1,3,14<7,10,11,21,23<";
		bwdpi_app_rulelist_row = bwdpi_app_rulelist.split("<");
	}
	var category_title = ["Net Control Packets", "Gaming", "Video and Audio Streaming", "Work-From-Home", "Web Surfing", "File Transferring", "Others", "Game Transferring"];
	var class_title = ["Net Control", "Gaming", "Streaming", "Work-From-Home", "Web Surfing", "File Downloads", "Others", "Game Downloads"];
	var cat_id_array = [
		[9, 20],
		[8],
		[4],
		[0, 5, 6, 15, 17],
		[13, 24],
		[1, 3, 14],
		[7, 10, 11, 21, 23],
		[4, 13]
	];

	var c_net=bwdpi_app_rulelist_row.indexOf(cat_id_array[0].toString())
	var c_gaming=bwdpi_app_rulelist_row.indexOf(cat_id_array[1].toString())
	var c_streaming=bwdpi_app_rulelist_row.indexOf(cat_id_array[2].toString())
	var c_voip=bwdpi_app_rulelist_row.indexOf(cat_id_array[3].toString())
	var c_web=bwdpi_app_rulelist_row.indexOf(cat_id_array[4].toString())
	var c_downloads=bwdpi_app_rulelist_row.indexOf(cat_id_array[5].toString())
	var c_others=bwdpi_app_rulelist_row.indexOf(cat_id_array[6].toString())
	var c_default=bwdpi_app_rulelist_row.indexOf(cat_id_array[7].toString())
} else {
	var category_title = ["", "Highest", "High", "Medium", "Low", "Lowest"];
}

var pie_obj_ul, pie_obj_dl;
var refreshRate;
var timedEvent = 0;
var filter = Array(6);
const maxshown = 500;
const maxrendered = 750;
var color = ["#B3645B", "#B98F53", "#C6B36A", "#849E75", "#4C8FC0",  "#7C637A", "#2B6692",  "#6C604F"];
var labels_array = [];
var pieOptions = {
	segmentShowStroke: false,
	segmentStrokeColor: "#000",
	animationEasing: "easeOutQuart",
	animationSteps: 100,
	animateScale: true,
	legend: {
		display: false
	},
	tooltips: {
		callbacks: {
			title: function(tooltipItem, data) {
				return data.labels[tooltipItem[0].index];
			},
			label: function(tooltipItem, data) {
				var value = data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index];
				var orivalue = value;
				var total = eval(data.datasets[tooltipItem.datasetIndex].data.join("+"));
				var unit = " bytes";
				if (value > 1024) {
					value = value / 1024;
					unit = " KB";
				}
				if (value > 1024) {
					value = value / 1024;
					unit = " MB";
				}
				if (value > 1024) {
					value = value / 1024;
					unit = " GB";
				}
				return value.toFixed(2) + unit + ' ( ' + parseFloat(orivalue * 100 / total).toFixed(2) + '% )';
			},
		}
	},
}

function ip2dec(addr) {
	if( /\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b$/.test(addr) )		//regex that accepts ipv4 addresses ###.###.###.### (no cidr flag allowed)
	{
		var parts = addr.split('.').map(Number);
		return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + (parts[3]) >>> 0;
	}
	else return 0;
};

function cidr_start(addr) {
	addr=addr.split('/');
	var parts = addr[0].split('.').map(Number);
	var dec_ip = (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + (parts[3]) >>> 0;
	var dec_mask= (4294967295 << 32-addr[1]) >>> 0;
	return (dec_ip&dec_mask)>>>0;
};

function cidr_end(addr) {
	addr=addr.split('/');
	var parts = addr[0].split('.').map(Number);
	var dec_ip = (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + (parts[3]) >>> 0;
	var dec_mask= ~(4294967295 << 32-addr[1]) >>> 0;
	return (dec_ip|dec_mask)>>>0;
};

function set_filter(field, o) {
	filter[field] = o.value.toLowerCase();
	draw_conntrack_table();
}

function draw_conntrack_table() {
	//bwdpi_conntrack[i][0] = protocol
	//bwdpi_conntrack[i][1] = Source IP
	//bwdpi_conntrack[i][2] = Source Port
	//bwdpi_conntrack[i][3] = Destination IP
	//bwdpi_conntrack[i][4] = Destination Port
	//bwdpi_conntrack[i][5] = Pre-formatted Title
	//bwdpi_conntrack[i][6] = Traffic ID
	//bwdpi_conntrack[i][7] = Traffic Category
	tabledata = [];
	var tracklen, shownlen = 0;
	tracklen = bwdpi_conntrack.length;
	if (tracklen == 0 ) {
		showhide("tracked_filters", 0);
		document.getElementById('tracked_connections').innerHTML = "";
		return;
	}
	showhide("tracked_filters", 1);

	if (tracklen > maxrendered && sessionStorage.warntoomanyconns != 1) {
		sessionStorage.warntoomanyconns = 1;
		document.getElementById('refreshrate').value = "0";
		refreshRate = 0;
		document.getElementById('toomanyconns').style.display = "";
	} else {
		document.getElementById('toomanyconns').style.display = "none";
	}

	for (var i = 0; (i < tracklen && shownlen < maxshown); i++)
	{
		if (bwdpi_conntrack[i][1].indexOf(":") >= 0) {
			bwdpi_conntrack[i][1] = compIPV6(bwdpi_conntrack[i][1]);
		}
		if (bwdpi_conntrack[i][3].indexOf(":") >= 0) {
			bwdpi_conntrack[i][3] = compIPV6(bwdpi_conntrack[i][3]);
		}

		//SHOW LOCAL DEVICES AT LEFT SIDE OF TABLE (FLIP POSITION IF REQUIRED)
		if (bwdpi_conntrack[i][3].startsWith(dhcp_start))
		{
			var temp = bwdpi_conntrack[i][3];
			bwdpi_conntrack[i][3] = bwdpi_conntrack[i][1];
			bwdpi_conntrack[i][1] = temp;

			temp = bwdpi_conntrack[i][4];
			bwdpi_conntrack[i][4] = bwdpi_conntrack[i][2];
			bwdpi_conntrack[i][2] = temp;
		}

		// Filter in place?
		var filtered = 0;
		for (j = 0; j < 6; j++) {
			if (filter[j]) {
				switch (j) {
					case 1:
						if (bwdpi_conntrack[i][1].toLowerCase() != filter[1].toLowerCase())
							filtered = 1;
						break;
					default:
						if (bwdpi_conntrack[i][j].toLowerCase().indexOf(filter[j]) < 0)
							filtered = 1;
				}
				if (bwdpi_conntrack[i][j].toLowerCase().indexOf(filter[j]) < 0)
					filtered = 1;
				if (filtered) continue;
			}
		}
		if (filtered) continue;
		shownlen++;

//		if (( deviceFilter == "*" || deviceFilter == compIPV6(bwdpi_conntrack[i][1]) ) && ( j < tablesize ))
		//function eval_rule(CLip, CRip, CProto, CLport, CRport, CCat, CId)
		var qos_class = eval_rule(bwdpi_conntrack[i][1], bwdpi_conntrack[i][3], bwdpi_conntrack[i][0], bwdpi_conntrack[i][2], bwdpi_conntrack[i][4], bwdpi_conntrack[i][7], bwdpi_conntrack[i][6]);
		if (qos_class == 99)
			qos_class = get_qos_class(bwdpi_conntrack[i][7], bwdpi_conntrack[i][6]);
		if ( ! bwdpi_conntrack[i][5].startsWith(qos_class+'_') )
			bwdpi_conntrack[i][5] =	qos_class + '_' + bwdpi_conntrack[i][5];

		tabledata.push(bwdpi_conntrack[i]);
	}
	//draw table
	document.getElementById('tracked_connections_total').innerHTML = "Tracked connections (total: " + tracklen + (shownlen < tracklen ? ", shown: " + shownlen : "") + ")";
	updateTable()
}

function updateTable()
{
	//table header
	var header = new Array(6);
	header[0]='<th width="5%"  style="cursor: pointer;" onclick="sortmode=1; updateTable()" >Proto</th>';
	header[1]='<th width="28%" style="cursor: pointer;" onclick="sortmode=2; updateTable()" >Local IP</th>';
	header[2]='<th width="6%"  style="cursor: pointer;" onclick="sortmode=3; updateTable()" >Port</th>';
	header[3]='<th width="28%" style="cursor: pointer;" onclick="sortmode=4; updateTable()" >Remote IP</th>';
	header[4]='<th width="6%"  style="cursor: pointer;" onclick="sortmode=5; updateTable()" >Port</th>';
	header[5]='<th width="27%" style="cursor: pointer;" onclick="sortmode=6; updateTable()" >Application</th>';

	//sort table data
	switch(sortmode) {
	case 1:
		// sort by protocol
		header[0]='<th width="5%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=7; updateTable()" >Proto</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return a[0].localeCompare(b[0])} );
		break;
	case 2:
		// sort by local IP
		header[1]='<th width="28%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=8; updateTable()" >Local IP</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return a[1].localeCompare(b[1])} );
		break;
	case 3:
		// sort by local port
		header[2]='<th width="6%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=9; updateTable()" >Port</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return a[2]-b[2]} );
		break;
	case 4:
		// sort by remote IP
		header[3]='<th width="28%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=10; updateTable()" >Remote IP</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return full_IPv6(a[3]).localeCompare(full_IPv6(b[3]))} );
		break;
	case 5:
		// sort by remote port
		header[4]='<th width="6%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=11; updateTable()" >Port</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return a[4]-b[4]} );
		break;
	case 6:
		// sort by label
		header[5]='<th width="27%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px -1px 0px 0px inset;" onclick="sortmode=12; updateTable()" >Application</th>';
		tabledata.sort(function(a,b) {return a[1].localeCompare(b[1])} );
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		break;
	case 7:
		// sort by protocol
		header[0]='<th width="5%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=1; updateTable()" >Proto</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return b[0].localeCompare(a[0])} );
		break;
	case 8:
		// sort by local IP
		header[1]='<th width="28%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=2; updateTable()" >Local IP</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return b[1].localeCompare(a[1])} );
		break;
	case 9:
		// sort by local port
		header[2]='<th width="6%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=3; updateTable()" >Port</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return b[2]-a[2]} );
		break;
	case 10:
		// sort by remote IP
		header[3]='<th width="28%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=4; updateTable()" >Remote IP</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return full_IPv6(b[3]).localeCompare(full_IPv6(a[3]))} );
		break;
	case 11:
		// sort by remote port
		header[4]='<th width="6%"  style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=5; updateTable()" >Port</th>';
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
		tabledata.sort(function(a,b) {return b[4]-a[4]} );
		break;
	case 12:
		// sort by label
		header[5]='<th width="27%" style="cursor: pointer; box-shadow: rgb(255, 204, 0) 0px 1px 0px 0px inset;" onclick="sortmode=6; updateTable()" >Application</th>';
		tabledata.sort(function(a,b) {return a[1].localeCompare(b[1])} );
		tabledata.sort(function(a,b) {return b[5].localeCompare(a[5])} );
		break;
	}

	//generate table
	var tbl  = document.getElementById('tableContainer');
	var code = '<tr class="row_title">'+header[0]+header[1]+header[2]+header[3]+header[4]+header[5]+'</tr>';

	for(var i = 0; i < tabledata.length; i++){
		if(tabledata[i])
		{
			qos_class = tabledata[i][5].split("_")[0];
			label = tabledata[i][5].split("_")[1];
			var mark = (parseInt(tabledata[i][7]).toString(16).padStart(2,'0') + parseInt(tabledata[i][6]).toString(16).padStart(4,'0')).toUpperCase();
			if (device[tabledata[i][1]]) {
				srchost = (device[tabledata[i][1]].name == "") ? tabledata[i][1] : device[tabledata[i][1]].name;
			} else {
				srchost = tabledata[i][1];
			}

			code += '<tr>'
			+ '<td>' + tabledata[i][0] + '</td>'
			+ '<td title="' + tabledata[i][1] + '"' + (srchost.length > 32 ? ' style="font-size: 80%;"' : '') + '>' + srchost + '</td>'
			+ '<td>' + tabledata[i][2] + '</td>'
			+ '<td' + (tabledata[i][3].length > 32 ? " style=\"font-size: 80%;\"" : "") + '>' + tabledata[i][3] +'</td>'
			+ '<td>' + tabledata[i][4] + '</td>'
			+ '<td class="t_item"' + 'title="' + labels_array[qos_class] + '">'
			+ '<span class="t_label catrow cat' + qos_class + '"' + (label.length > 27 ? 'style="font-size: 75%;"' : '') + '>' + label + '</span>'
			+ '<span class="t_mark  catrow cat' + qos_class + '"' + (label.length > 27 ? 'style="font-size: 75%;"' : '') + '>MARK:' + mark + '</span>'
			+ '</td></tr>';
		}
		else
		{
			code += '<tr></tr>';
		}
	}
	if (tabledata.length == maxshown)
	{
		code += '<tr><td colspan="6"><span style="text-align: center;">List truncated to ' + maxshown + ' elements - use a filter</td></tr>';
	}
	tbl.innerHTML = code;
}

function comma(n) {
	n = '' + n;
	var p = n;
	while ((n = n.replace(/(\d+)(\d{3})/g, '$1,$2')) != p) p = n;
	return n;
}

function get_devicenames()
{
	// populate device["IP"].mac from nvram variable "dhcp_staticlist"
	decodeURIComponent('<% nvram_char_to_ascii("", "dhcp_staticlist"); %>').split("<").forEach( element => {
		if ( element.split(">")[1] ){
			//device[element.split(">")[1]] = { mac:element.split(">")[0].toUpperCase() , name:"DEBUG: NVRAM" };
			device[element.split(">")[1]] = { mac:element.split(">")[0].toUpperCase() , name:"*" };
		}
	});

	// populate device["IP"].mac from arp table
	[<% get_arp_table(); %>].forEach( element => {
		if ( element[3] ){
			//device[element[0]] = { mac:element[3].toUpperCase() , name:"DEBUG: ARP" };
			device[element[0]] = { mac:element[3].toUpperCase() , name:element[4] };
		}
	 });

	//instead temporarily populate device["IP"].name from dhcp table
	// used as stopgap source of partial information on page load until complete information is later available from asynchronous code
	// is NOT ideal since the names using this method do not reflect nicknames and sometimes return "*" instead of a device name
	dhcpnamelist = <% IP_dhcpLeaseInfo(); %>
	dhcpnamelist.forEach( element => {
		if ( element[0] ){
			if( device[element[0]] )
				device[element[0]].name = element[1];
			else
				device[element[0]] = { mac:undefined , name:element[1]};
		}
	});

	<% get_ipv6net_array(); %>

	ipv6clientarray.forEach( element => {
		if ( element[2] ){
			if( device[element[2].replace(/[0-9a-f]{2}$/,"00")] )
				device[element[2].replace(/[0-9a-f]{2}$/,"00")].name = element[0];
			else
				device[element[2].replace(/[0-9a-f]{2}$/,"00")] = { mac:element[1] , name:element[0]};
		}
	});

	// populate device["IP"].name from device["IP"].mac saved in /jffs/nmp_cl_json.js
	// clientlist = is data set from /jffs/nmp_cl_json.js
	for (var i in device) {
		if (typeof clientlist[device[i].mac] != "undefined")
		{
			if(clientlist[device[i].mac].nickName != "")
			{
				device[i].name = clientlist[device[i].mac].nickName;
			}
			else if(clientlist[device[i].mac].name != "")
			{
				device[i].name = clientlist[device[i].mac].name;
			}
		}
	}
}

function update_devicenames(leasearray)
{
	// this code is after ajax call
	leasearray.forEach( element => {
		if ( element[1] ){

			mac = element[1].toUpperCase();
			ip = element[2];
			name = element[3];

			//update device["IP"].mac from DHCP table
			//device[ip] = { mac:mac , name:"DEBUG: DHCP" };
			device[ip] = { mac:mac , name:name };

			//update device{"IP"].name from /jffs/nmp_cl_json.js
			if (typeof clientlist[mac] != "undefined")
			{
				if(clientlist[mac].nickName != "")
				{
					device[ip].name = clientlist[mac].nickName;
				}
				else if(clientlist[mac].name != "")
				{
					device[ip].name = clientlist[mac].name;
				}
			}

			//update device filter drop down formated values
			document.getElementById(ip).innerHTML = ip.padEnd(21," ").replace(/ /g,"&nbsp;") + device[ip].name;
		}
	});
}

function populate_classmenu(){
	var code = "";
	for (i = 0; i < class_title.length; i++) {
	  code += '<option value="' + i + '">' + class_title[i] + "</option>\n";
	}
	document.getElementById('appdb_class_x').innerHTML=code;
}

function populate_devicefilter(){
	var code = '<option value=""> </option>';

	//Presort clients before adding clients into devicefilter to make it easier to read
	keysSorted = Object.keys(device).sort(function(a,b){ return ip2dec(a)-ip2dec(b) })									// sort by IP
	//keysSorted = Object.keys(device).sort(function(a,b){ return device[a].name.localeCompare(device[b].name) })		// sort by device name
	for (i = 0; i < keysSorted.length; i++) {
		key = keysSorted[i];
		code += '<option id="' + key + '" value="' + key + '">' + key.replace(ipv6prefix,"").padEnd(21," ").replace(/ /g,"&nbsp;") + device[key].name + "</option>\n";
	}
	document.getElementById('devicefilter').innerHTML=code;
}

function initial() {
	SetCurrentPage();
	show_menu();
	set_FlexQoS_mod_vars();
	get_devicenames();		//used for printing name next to IP
	populate_devicefilter();		//used to populate drop down filter
	populate_classmenu();
	refreshRate = document.getElementById('refreshrate').value;
	deviceFilter = document.getElementById('devicefilter').value;
	get_data();
	show_iptables_rules();
	show_appdb_rules();
	if (qos_mode == 0){		//if QoS is invalid
		document.getElementById('filter_device').style.display = "none";
		document.getElementById('tracked_connections').style.display = "none";
		document.getElementById('refresh_data').style.display = "none";
	}
	$.ajax({
		url: "Main_DHCPStatus_Content.asp",
		success: function(result){
			result = result.match(/leasearray=([\s\S]*?);/);
			if (result[1]){
				update_devicenames(eval(result[1])); //regex data string into actual array
			}
		}
	});
}

function get_qos_class(category, appid) {
	var i, j, catlist, rules;
	if ((category == 0 && appid == 0) || (qos_mode != 2))
		return 7;
	for (i = 0; i < bwdpi_app_rulelist_row.length - 2; i++) {
		rules = bwdpi_app_rulelist_row[i];
		if (i == 0)
			rules += ",18,19";
		else if (i == 4)
			rules += ",28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43";
		else if (i == 5)
			rules += ",12";
		catlist = rules.split(",");
		for (j = 0; j < catlist.length; j++) {
			if (catlist[j] == category) {
				return i;
			}
		}
	}
	return 7;
}

function compIPV6(input) {
	input = input.replace(/\b(?:0+:){2,}/, ':');
	return input.replace(/(^|:)0{1,4}/g, ':');
}

function create_rule(Lip, Rip, Proto, Lport, Rport, Mark, Dst){
	var rule =[];		//user rule in specific format later used for quick evaluation
	//rule[0]=enabled filters flag (8bit)
	//rule[1]=protocol
	//rule[2]=Local port inverse match (!) bool
	//rule[3]=Local port start
	//rule[4]=Local port end
	//rule[5]=Local port multimatch array
	//rule[6]=Remote port inverse match (!) bool
	//rule[7]=Remote port start
	//rule[8]=Remote port end
	//rule[9]=Remote port multimatch array
	//rule[10]=Local IP inverse match (!) bool
	//rule[11]=Local IP start
	//rule[12]=Local IP end
	//rule[13]=Remote IP inverse match (!) bool
	//rule[14]=Remote IP start
	//rule[15]=Remote IP end
	//rule[16]=Mark (General Category Match)
	//rule[17]=Mark (Specific Traffic Match)
	//rule[18]=QoS Destination

	rule[0]=0;
	if (Dst)	rule[18]=bwdpi_app_rulelist_row.indexOf(cat_id_array[Dst].toString());
	Proto = Proto.toLowerCase();
	if ( Proto )
	{
		rule[1]=Proto;
		if( Lport )
		{
			if(Lport.startsWith("!")) {
				rule[2]=1;
				Lport=Lport.replace("!", "");
			}
			if(Lport.includes(",")) {
				rule[0]+=4;
				rule[5]=Lport.split(",").map(Number);;
			}
			else if (Lport.includes(":")) {
				rule[0]+=1;
				rule[3]=parseInt(Lport.split(':')[0]);
				rule[4]=parseInt(Lport.split(':')[1]);
			}
			else{
				rule[0]+=1;
				rule[3]=parseInt(Lport);
				rule[4]=rule[3];
			}
		}

		if( Rport )
		{
			if(Rport.startsWith("!")) {
				rule[6]=1;
				Rport=Rport.replace("!", "");
			}
			if(Rport.includes(",")) {
				rule[0]+=8;
				rule[9]=Rport.split(",").map(Number);;
			}
			else if (Rport.includes(":")) {
				rule[0]+=2;
				rule[7]=parseInt(Rport.split(':')[0]);
				rule[8]=parseInt(Rport.split(':')[1]);
			}
			else{
				rule[0]+=2;
				rule[7]=parseInt(Rport);
				rule[8]=rule[7];
			}
		}
	}

	if ( Lip )
	{
		rule[0]+=16;
		if(Lip.startsWith("!")) {
			rule[10]=1;
			Lip=Lip.replace("!", "");
		}

		if(Lip.includes("/")) {
			rule[11]=cidr_start(Lip);
			rule[12]=cidr_end(Lip);
		}
		else{
			rule[11]=ip2dec(Lip);
			rule[12]=rule[11];
		}
	}

	if ( Rip )
	{
		rule[0]+=32;
		if(Rip.startsWith("!")) {
			rule[13]=1;
			Rip=Rip.replace("!", "");
		}

		if(Rip.includes("/")) {
			rule[14]=cidr_start(Rip);
			rule[15]=cidr_end(Rip);
		}
		else{
			rule[14]=ip2dec(Rip);
			rule[15]=rule[14];
		}
	}

	if ( Mark.length == 6 )
	{
		rule[0]+=64;
		rule[16]=parseInt(Mark.substr(0,2),16);

		if (Mark.substr(-4) != "****")
		{
			rule[0]+=128;
			rule[17]=parseInt(Mark.substr(-4),16);
		}

	}

	// console.log(rule);
	return rule;
};

function eval_rule(CLip, CRip, CProto, CLport, CRport, CCat, CId){
	// return the rules[i][18] when a match
	for (i=0;i<rules.length;i++) {
		//eval false if rule has no filters or destination specified
		if (!rules[i] || !rules[i][0] || (rules[i][18]==undefined) )
		{
			// console.log("rule is not configured");
			continue;
		}

		if ( rules[i][1] && CProto != rules[i][1] && rules[i][1] != "both" )
		{
			// console.log("protocol mismatch");
			continue;
		}

		//if rule has local/remote ports specified
		if (rules[i][0] & 15)
		{
			if ((rules[i][0] & 15) <= 3 )							//if port rule is NOT a multiport match
			{
				if ( (rules[i][0] & 1) && !((CLport >= rules[i][3] && CLport <= rules[i][4])^(rules[i][2])) )
				{
					// console.log("local port mismatch");
					continue;
				}
				if ( (rules[i][0] & 2) && !((CRport >= rules[i][7] && CRport <= rules[i][8])^(rules[i][6])) )
				{
					// console.log("remote port mismatch");
					continue;
				}
			}
			else if ((rules[i][0] & 15) == "4" )						//if port rule is ONLY a local multiport match
			{
				var match=false;
				for (var j = 0; j < rules[i][5].length; j++) {
					if(rules[i][5][j] == CLport) 	match=true;
				}
				if (rules[i][2]) 					match=!(match);
				if (match == false)
				{
				  // console.log("local multiport mismatch");
				  continue;
				}
			}
			else if ((rules[i][0] & 15) == "8" )						//if port rule is ONLY a remote multiport match
			{
				var match=false;
				for (var j = 0; j < rules[i][9].length; j++) {
			  	  if(rules[i][9][j] == CRport) 	match=true;
				}
				if (rules[i][6]) 				match=!(match);
				if (match == false)
				{
				  // console.log("remote multiport mismatch");
				  continue;
				}
			}
			else
			{
				//console.log("improper configuration of port rule");
				continue;		//false since multiport match cannot be simultanously used with other port match
			}
		}

		// if rule has mark cat specified
		if ( (rules[i][0] & 64) && (rules[i][16] != CCat) )
		{
			// console.log("category mismatch");
			continue;
		}

		// if rule has mark id specified
		if ( (rules[i][0] & 128) && (rules[i][17] != CId) )
		{
			// console.log("traffic ID mismatch");
			continue;
		}

		// if rule has local IP specified and is not IPv6
		if (rules[i][0] & 16)
		{
			if ( CLip.indexOf(":") < 0 ) {
				var tmpCLip=ip2dec(CLip);
				if ( !((tmpCLip >= rules[i][11] && tmpCLip <= rules[i][12])^(rules[i][10])) )
				{
					// console.log("local ip mismatch");
					continue;
					}
			} // is IPv4
			else
				// is IPv6
				continue;
		 }

		// if rule has remote IP specified
		if (rules[i][0] & 32)
		{
			if ( CRip.indexOf(":") < 0 ) {
				var tmpCRip=ip2dec(CRip);
				if ( !((tmpCRip >= rules[i][14] && tmpCRip <= rules[i][15])^(rules[i][13])) )
				{
				//console.log("remote ip mismatch");
				continue;
				}
			} // is IPv4
			else
				// is IPv6
				continue;
		}

		// console.log("rule matches current connection");
		return rules[i][18];  // return the rule's target Class
	} // for each rule in array
	return 99;  // return 99 to indicate no matches
}  // eval_rule

function redraw() {
	var code;
	switch (qos_mode) {
		case 0: // Disabled
			document.getElementById('dl_tr').style.display = "none";
			document.getElementById('ul_tr').style.display = "none";
			document.getElementById('no_qos_notice').style.display = "";
			return;
		case 3: // Bandwith Limiter
			document.getElementById('dl_tr').style.display = "none";
			document.getElementById('ul_tr').style.display = "none";
			document.getElementById('limiter_notice').style.display = "";
			return;
		case 1: // Traditional
			document.getElementById('dl_tr').style.display = "none";
			document.getElementById('tqos_notice').style.display = "";
			break;
		case 2: // Adaptive
			if (pie_obj_dl != undefined) pie_obj_dl.destroy();
			var ctx_dl = document.getElementById("pie_chart_dl").getContext("2d");
			tcdata_lan_array.sort(function(a, b) {
				return a[0] - b[0]
			});
			code = draw_chart(tcdata_lan_array, ctx_dl, "dl");
			document.getElementById('legend_dl').innerHTML = code;
			break;
	}
	if (pie_obj_ul != undefined) pie_obj_ul.destroy();
	var ctx_ul = document.getElementById("pie_chart_ul").getContext("2d");
	tcdata_wan_array.sort(function(a, b) {
		return a[0] - b[0]
	});
	code = draw_chart(tcdata_wan_array, ctx_ul, "ul");
	document.getElementById('legend_ul').innerHTML = code;
	pieOptions.animation = false; // Only animate first time
}

function get_data() {
	if (timedEvent) {
		clearTimeout(timedEvent);
		timedEvent = 0;
	}
	$.ajax({
		url: '/ajax_gettcdata.asp',
		dataType: 'script',
		error: function(xhr) {
			get_data();
		},
		success: function(response) {
			redraw();
			draw_conntrack_table();
			if (refreshRate > 0)
				timedEvent = setTimeout("get_data();", refreshRate * 1000);
		}
	});
}

function draw_chart(data_array, ctx, pie) {
	var code = '<table><thead style="text-align:left;"><tr><th style="padding-left:5px;">Class</th><th style="padding-left:5px; width:76px;">Total</th><th style="padding-left:30px; padding-right:15px;">Rate</th><th style="padding-left:15px;">Packet rate</th></tr></thead>';
	var values_array = [];
	labels_array = [];
	for (i = 0; i < data_array.length - 1; i++) {
		var value = parseInt(data_array[i][1]);
		var tcclass = parseInt(data_array[i][0]);
		var rate;
		if (qos_mode == 2) {
			var index = 0;
			for (j = 1; j < cat_id_array.length; j++) {
				if (cat_id_array[j] == bwdpi_app_rulelist_row[i]) {
					index = j;
					break;
				}
			}
			var label = category_title[index];
		} else {
			tcclass = tcclass / 10;
			var label = category_title[tcclass];
			if (label == undefined) {
				label = "Class " + tcclass;
			}
		}
		labels_array.push(label);
		values_array.push(value);
		var unit = " Bytes";
		if (value > 1024) {
			value = value / 1024;
			unit = " KB";
		}
		if (value > 1024) {
			value = value / 1024;
			unit = " MB";
		}
		if (value > 1024) {
			value = value / 1024;
			unit = " GB";
		}
		if (qos_mode == 2) {
			code += '<tr><td style="word-wrap:break-word;padding-left:5px;padding-right:5px;border:1px #2f3a3e solid; border-radius:5px;background-color:' + color[i] + ';margin-right:10px;line-height:20px;">' + label + '</td>';
			code += '<td style="padding-left:5px;">' + value.toFixed(2) + unit + '</td>';
			rate = rate2kbs(data_array[i][2])
			code += '<td style="padding-left:5px; text-align:right;">' + rate + ' kB/s</td>';
			rate = comma(data_array[i][3]);
			code += '<td style="padding-left:5px; text-align:right;">' + rate.replace(/([0-9,])([a-zA-Z])/g, '$1 $2') + '</td></tr>';
		}
	}
	code += '</table>';
	var pieData = {
		labels: labels_array,
		datasets: [{
			data: values_array,
			backgroundColor: color,
			hoverBackgroundColor: color,
			borderColor: "#444",
			borderWidth: "1"
		}]
	};
	var pie_obj = new Chart(ctx, {
		type: 'pie',
		data: pieData,
		options: pieOptions
	});
	if (pie == "ul")
		pie_obj_ul = pie_obj;
	else
		pie_obj_dl = pie_obj;
	return code;
}

function rate2kbs(rate)
{
	if (rate)
	{
		if (rate.includes("Mbit"))
		{
			return ( comma(parseInt(rate.replace(/[^0-9]/g,"")*1024/8)));
		}
		else if (rate.includes("Kbit"))
		{
			return  ( comma(parseInt(rate.replace(/[^0-9]/g,"")/8)) );
		}
		else if (rate.includes("bit"))
		{
			return ( comma(parseInt(rate.replace(/[^0-9]/g,"")/1024/8)) )
		}
	}

	return 0
}

function check_duplicate(){
	var rule_num = document.getElementById('appdb_rulelist_table').rows.length;
	for(i=0; i<rule_num; i++){
		if(document.getElementById('appdb_rulelist_table').rows[i].cells[1].innerHTML == document.form.appdb_mark_x.value) {
			alert("A rule for this mark already exists.");
			return true;
		}
	}
	return false;
} // check_duplicate

function addAppDBRow(obj, head){
	if(head == 1)
		appdb_rulelist_array += "<"
	else
		appdb_rulelist_array += ">"

	appdb_rulelist_array += obj.value;
	obj.value = "";
}

function validAppDBForm(){
	if(!Block_chars(document.form.appdb_mark_x, ["<" ,">"]))
		return false;
	if(document.form.appdb_mark_x.value.length != 6)
		return false;
	return true;
}

function addRow_AppDB_Group(upper){
	if(validAppDBForm()){
		var rule_num = document.getElementById('appdb_rulelist_table').rows.length;
		if(rule_num >= upper){
			alert("This table only allows " + upper + " items!");
			return;
		}
		if(check_duplicate() == true)
			return false;
		addAppDBRow(document.form.appdb_mark_x, 1);
		addAppDBRow(document.form.appdb_class_x, 0);
		document.getElementById('appdb_desc_x').innerHTML="";
		document.form.appdb_class_x.value="0";
		show_appdb_rules();
	}
}

function del_appdb_Row(r){
	var i=r.parentNode.parentNode.rowIndex;
	document.getElementById('appdb_rulelist_table').deleteRow(i);
	var appdb_rulelist_value = "";
	for(k=0; k<document.getElementById('appdb_rulelist_table').rows.length; k++){
		for(j=1; j<document.getElementById('appdb_rulelist_table').rows[k].cells.length-1; j++){
			if(j == 1)
				appdb_rulelist_value += "<";
			else if (j == 2)
				appdb_rulelist_value += ">";
			if(j == 2)
				appdb_rulelist_value += class_title.indexOf(document.getElementById('appdb_rulelist_table').rows[k].cells[j].innerHTML);
			else if (j == 1)
				appdb_rulelist_value += document.getElementById('appdb_rulelist_table').rows[k].cells[j].innerHTML;
		}
	}
	appdb_rulelist_array = appdb_rulelist_value;
	if(appdb_rulelist_array == "")
	show_appdb_rules();
}

function edit_appdb_Row(r){
	var i=r.parentNode.parentNode.rowIndex;
	document.getElementById('appdb_desc_x').innerHTML = document.getElementById('appdb_rulelist_table').rows[i].cells[0].innerHTML;
	document.form.appdb_mark_x.value = document.getElementById('appdb_rulelist_table').rows[i].cells[1].innerHTML;
	document.form.appdb_class_x.value = class_title.indexOf(document.getElementById('appdb_rulelist_table').rows[i].cells[2].innerHTML);
	del_appdb_Row(r);
}

function show_iptables_rules(){
	var tableStruct = {
		data: iptables_temp_array,
		container: "iptables_rules_block",
		title: "iptables Rules",
		titieHint: "Edit existing rules by clicking in the table below.",
		capability: {
			add: true,
			del: true,
			clickEdit: true
		},
		header: [
			{
				"title" : "Local IP/CIDR",
				"width" : "14%"
			},
			{
				"title" : "Remote IP/CIDR",
				"width" : "14%"
			},
			{
				"title" : "Protocol",
				"width" : "9%"
			},
			{
				"title" : "Local Port",
				"width" : "15%"
			},
			{
				"title" : "Remote Port",
				"width" : "15%"
			},
			{
				"title" : "Mark",
				"width" : "9%"
			},
			{
				"title" : "Class",
				"width" : "18%"
			}
		],
		createPanel: {
			inputs : [
				{
					"editMode" : "text",
					"title" : "Local IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "192.168.1.100 !192.168.1.100 192.168.1.100/31 !192.168.1.100/31",
					"validator" : "dualWanRoutingRules"
				},
				{
					"editMode" : "text",
					"title" : "Remote IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "9.9.9.9 !9.9.9.9 9.9.9.0/24 !9.9.9.0/24",
					"validator" : "dualWanRoutingRules"
				},
				{
					"editMode" : "select",
					"title" : "Protocol",
					"option" : {"BOTH" : "both", "TCP" : "tcp", "UDP" : "udp"}
				},
				{
					"editMode" : "text",
					"title" : "Local Port",
					"maxlength" : "36",
					"valueMust" : false,
					"placeholder": "443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853",
					"validator" : "portRange"
				},
				{
					"editMode" : "text",
					"title" : "Remote Port",
					"maxlength" : "36",
					"valueMust" : false,
					"placeholder": "443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853",
					"validator" : "portRange"
				},
				{
					"editMode" : "text",
					"title" : "Mark",
					"maxlength" : "6",
					"valueMust" : false,
					"placeholder": "XXYYYY XX=Category(hex) YYYY=ID(hex or ****)",
					"validator" : "qosMark"
				},
				{
					"editMode" : "select",
					"title" : "Class",
					"option" : {"Net Control" : "0", "Gaming" : "1", "Streaming" : "2", "Work-From-Home" : "3", "Web Surfing" : "4", "File Downloads" : "5", "Others" : "6", "Game Downloads" : "7" }
				}
			],
			maximum: 24
		},
		clickRawEditPanel: {
			inputs : [
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "dualWanRoutingRules"
				},
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "dualWanRoutingRules"
				},
				{
					"editMode" : "select",
					"option" : {"BOTH" : "both", "TCP" : "tcp", "UDP" : "udp"}
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "portRange"
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "portRange"
				},
				{
					"editMode" : "text",
					"maxlength" : "6",
					"valueMust" : false,
					"validator" : "qosMark"
				},
				{
					"editMode" : "select",
					"option" : {"Net Control" : "0", "Gaming" : "1", "Streaming" : "2", "Work-From-Home" : "3", "Web Surfing" : "4", "File Downloads" : "5", "Others" : "6", "Game Downloads" : "7" }
				}
			]
		},
//		ruleDuplicateValidation : "triggerPort"
	}
	tableApi.genTableAPI(tableStruct);
}

function show_appdb_rules() {
	var appdb_rulelist_row = decodeURIComponent(appdb_rulelist_array).split('<');
	var code = "";
	var overlib_str = "";

	code +='<table width="100%" border="1" cellspacing="0" cellpadding="4" align="center" class="list_table" id="appdb_rulelist_table">';
	if(appdb_rulelist_row.length == 1)
		code +='<tr><td style="color:#FFCC00;" colspan="4">No rules defined</td></tr>';
	else{
		for(var i = 1; i < appdb_rulelist_row.length; i++){
			code +='<tr id="row'+i+'">';
			var appdb_rulelist_col = appdb_rulelist_row[i].split('>');
			for(var j = 0; j < appdb_rulelist_col.length; j++){
				if (j==1){
					code +='<td width="20%">'+ class_title[appdb_rulelist_col[j]] +'</td>';
				} else {
					code +='<td width="auto">'+ catdb_label_array[catdb_mark_array.indexOf(appdb_rulelist_col[j])] +'</td>';
					code +='<td width="10%">'+ appdb_rulelist_col[j] +'</td>';
				}
			}
			code +='<td width="15%"><input class="edit_btn" onclick="edit_appdb_Row(this);" value=""/>';
			code +='<input class="remove_btn" onclick="del_appdb_Row(this);" value=""/></td></tr>';
		}
	}
	code +='</table>';
	document.getElementById("appdb_rules_block").innerHTML = code;
}

function FlexQoS_mod_toggle()
{
	var FlexQoS_div = document.getElementById('FlexQoS_mod');
	var FlexQoS_toggle = document.getElementById('FlexQoS_mod_toggle');
	if (FlexQoS_div.style.display == "none")
	{
		FlexQoS_div.style.display = "block";
		FlexQoS_toggle.innerHTML = "Close";
	}
	else
	{
		FlexQoS_div.style.display = "none";
		FlexQoS_toggle.innerHTML = "Customize";
	}
}

function set_FlexQoS_mod_vars()
{
	if (qos_mode != 2) {
		var element = document.getElementById('FlexQoS_mod_toggle')
		element.innerHTML="Adaptive QoS is Disabled";
		element.removeAttribute("onclick");
		element.style.cursor = "";
	}
	else
	{
		if ( custom_settings.flexqos_iptables == undefined )  // rules not yet converted to API format
			{
				// prepend default rules which can be later edited/deleted by user
				iptables_rulelist_array = "<>>udp>>500,4500>>3<>>udp>16384:16415>>>3<>>tcp>>119,563>>5<>>tcp>>80,443>08****>7";
				var FreshJR_nvram = decodeURIComponent('<% nvram_char_to_ascii("",fb_comment); %>')+'>'+decodeURIComponent('<% nvram_char_to_ascii("",fb_email_dbg); %>');
				FreshJR_nvram = FreshJR_nvram.split('>');
				for (var j=0;j<FreshJR_nvram.length;j++) {
					var iptables_temp_rule = "";
					FreshJR_nvram[j] = FreshJR_nvram[j].split(";");
					if (FreshJR_nvram[j].length == 7) {
						for (var k=0;k<FreshJR_nvram[j].length;k++) {
							if (k==0)
								iptables_temp_rule += "<";
							else
								iptables_temp_rule += ">";
							iptables_temp_rule += FreshJR_nvram[j][k];
						} // for inner loop
					} // an iptables rule
				if (iptables_temp_rule != "<>>both>>>>0")
					iptables_rulelist_array += iptables_temp_rule;
				}
				if (FreshJR_nvram[8]) {
					gameCIDR=FreshJR_nvram[8].toString();
					if (gameCIDR.length > 1)
						iptables_rulelist_array = "<"+gameCIDR+">>both>>!80,443>000000>1" + iptables_rulelist_array;
					FreshJR_nvram = "";
				}
			}
		else // rules are migrated to new API variables
			iptables_rulelist_array = custom_settings.flexqos_iptables;

		if ( custom_settings.flexqos_appdb == undefined )
		{
			// start with default appdb rules which can be edited/deleted later by user
			appdb_rulelist_array = "<000000>6<00006B>6<0D0007>5<0D0086>5<0D00A0>5<12003F>4<13****>4<14****>4<1A****>5";
			var FreshJR_nvram = decodeURIComponent('<% nvram_char_to_ascii("",fb_email_dbg); %>').split(">");
			if (FreshJR_nvram.length > 5) {
				for (var j=1;j<5;j++) {
					var appdb_temp_rule = "";
					FreshJR_nvram[j] = FreshJR_nvram[j].split(";");
					for (var k=0;k<FreshJR_nvram[j].length;k++) {
						if (k==0)
							appdb_temp_rule += "<";
						else
							appdb_temp_rule += ">";
						appdb_temp_rule += FreshJR_nvram[j][k];
					} // for inner loop
				if (appdb_temp_rule != "<>0" || appdb_temp_rule != "<>")
					appdb_rulelist_array += appdb_temp_rule;
				}
				FreshJR_nvram = "";
			}
		}
		else
			appdb_rulelist_array = custom_settings.flexqos_appdb;

		var r=0;
		iptables_temp_array = iptables_rulelist_array.split("<");
		iptables_temp_array.shift();
		for (r=0;r<iptables_temp_array.length;r++){
			if (iptables_temp_array[r] != "") {
				iptables_temp_array[r]=iptables_temp_array[r].split(">");
				rules.push(create_rule(iptables_temp_array[r][0], iptables_temp_array[r][1], iptables_temp_array[r][2], iptables_temp_array[r][3], iptables_temp_array[r][4], iptables_temp_array[r][5], iptables_temp_array[r][6]));
			}
		}

		appdb_temp_array = appdb_rulelist_array.split("<");
		appdb_temp_array.shift();
		for (var a=0; a<appdb_temp_array.length;a++) {
			if (appdb_temp_array[a].length == 8) {
				appdb_temp_array[a]=appdb_temp_array[a].split(">");
				appdb_temp_array[a].unshift(catdb_label_array[catdb_mark_array.indexOf(appdb_temp_array[a][0])]);
				rules.push(create_rule("", "", "", "", "", appdb_temp_array[a][1], appdb_temp_array[a][2]));
			}
		}

		// get Bandwidth
		if ( custom_settings.flexqos_bandwidth == undefined )
		{
			var FreshJR_nvram = decodeURIComponent('<% nvram_char_to_ascii("",fb_email_dbg); %>').split(">");
			if (FreshJR_nvram.length > 10)
				bandwidth = "<" + FreshJR_nvram[7].replace(/\;/g,">") + "<" + FreshJR_nvram[8].replace(/\;/g,">") + "<" + FreshJR_nvram[9].replace(/\;/g,">") + "<" + FreshJR_nvram[10].replace(/\;/g,">");
			else
				bandwidth = "<5>20>15>10>10>30>5>5<100>100>100>100>100>100>100>100<5>20>15>30>10>10>5>5<100>100>100>100>100>100>100>100";
			FreshJR_nvram = "";
		}
		else
			bandwidth = custom_settings.flexqos_bandwidth;

		var bandwidth_array = bandwidth.split("<");
		bandwidth_array.shift();
		for (var b=0;b<bandwidth_array.length;b++) {
			bandwidth_array[b] = bandwidth_array[b].split(">");
			var temp_elemid;
			var maxpct;
			switch (b) {
				case 0:
					temp_elemid="drp"; maxpct=99;
					break;
				case 1:
					temp_elemid="dcp"; maxpct=100;
					break;
				case 2:
					temp_elemid="urp"; maxpct=99;
					break;
				case 3:
					temp_elemid="ucp"; maxpct=100;
					break;
			}
			for (var c=0;c<bandwidth_array[b].length;c++) {
				if (bandwidth_array[b][c] >=5 && bandwidth_array[b][c]<=maxpct)
					document.getElementById(temp_elemid + c).value=bandwidth_array[b][c];
			}
		}
	}
}

function FlexQoS_mod_reset_down()
{
	document.getElementById('drp0').value=5;
	document.getElementById('drp1').value=20;
	document.getElementById('drp2').value=15;
	document.getElementById('drp3').value=10;
	document.getElementById('drp4').value=10;
	document.getElementById('drp5').value=30;
	document.getElementById('drp6').value=5;
	document.getElementById('drp7').value=5;

	document.getElementById('dcp0').value=100;
	document.getElementById('dcp1').value=100;
	document.getElementById('dcp2').value=100;
	document.getElementById('dcp3').value=100;
	document.getElementById('dcp4').value=100;
	document.getElementById('dcp5').value=100;
	document.getElementById('dcp6').value=100;
	document.getElementById('dcp7').value=100;
}

function FlexQoS_mod_reset_up()
{
	document.getElementById('urp0').value=5;
	document.getElementById('urp1').value=20;
	document.getElementById('urp2').value=15;
	document.getElementById('urp3').value=30;
	document.getElementById('urp4').value=10;
	document.getElementById('urp5').value=10;
	document.getElementById('urp6').value=5;
	document.getElementById('urp7').value=5;

	document.getElementById('ucp0').value=100;
	document.getElementById('ucp1').value=100;
	document.getElementById('ucp2').value=100;
	document.getElementById('ucp3').value=100;
	document.getElementById('ucp4').value=100;
	document.getElementById('ucp5').value=100;
	document.getElementById('ucp6').value=100;
	document.getElementById('ucp7').value=100;
}

function FlexQoS_mod_apply() {
	bandwidth="";

	for (var b=0;b<4;b++) {
		var temp_elemid;
		switch (b) {
			case 0:
				temp_elemid="drp";
				break;
			case 1:
				temp_elemid="dcp";
				break;
			case 2:
				temp_elemid="urp";
				break;
			case 3:
				temp_elemid="ucp";
				break;
		}
		for (var c=0;c<8;c++) {
			if (c==0)
				bandwidth += "<";
			else
				bandwidth += ">";
			bandwidth += document.getElementById(temp_elemid + c).value;
		}
	}

	var iptables_rulelist_array = "";
	for(var i = 0; i < iptables_temp_array.length; i++) {
		if(iptables_temp_array[i].length != 0) {
			iptables_rulelist_array += "<";
			for(var j = 0; j < iptables_temp_array[i].length; j += 1) {
				iptables_rulelist_array += iptables_temp_array[i][j];
				if( (j + 1) != iptables_temp_array[i].length)
					iptables_rulelist_array += ">";
			}
		}
	}

	if (iptables_rulelist_array.length > 2999) {
		alert("Total iptables rules exceeds 2999 bytes! Please delete or consolidate!");
		return
	}
	if (appdb_rulelist_array.length > 2999) {
		alert("Total AppDB rules exceeds 2999 bytes! Please delete or consolidate!");
		return
	}
	custom_settings.flexqos_iptables = iptables_rulelist_array;
	custom_settings.flexqos_appdb = appdb_rulelist_array;
	custom_settings.flexqos_bandwidth = bandwidth;

	/* Store object as a string in the amng_custom hidden input field */
	if (JSON.stringify(custom_settings).length < 8192) {
		document.getElementById('amng_custom').value = JSON.stringify(custom_settings);
		document.form.action_script.value = "restart_qos;restart_firewall";
		document.form.submit();
	}
	else
		alert("Settings for all addons exceeds 8K limit! Cannot save!");
}

function validate_mark(input)
{
	document.getElementById('appdb_desc_x').innerHTML="";

	if (!(input))		return 1;		//is blank

	if (input.length != 6 )		return false;	//console.log("fail length");
	if (input.substr(-4) == "****")
	{
		if ( /[^0-9a-fA-F]/.test(input.substr(0,2) ))		return false;	//console.log("fail beg character");
	}
	else
	{
		if ( /[^0-9a-fA-F]/.test(input) )		return false;	//console.log("fail character");
	}
	var mark_desc=catdb_label_array[catdb_mark_array.indexOf(input.toUpperCase())];
	if ( mark_desc != undefined)
		document.getElementById('appdb_desc_x').innerHTML=mark_desc;
	else
		document.getElementById('appdb_desc_x').innerHTML="Unknown Mark";
	return 1;
}

function validate_percent(input)
{
	if (!(input)) 						return false;	//cannot be blank
	if ( /[^0-9]/.test(input) )			return false;	//console.log("fail character");
	if ( input < 5 || input > 100) 		return false;	//console.log("fail range");
	return 1
}

function SetCurrentPage() {
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

</script>
</head>
<body onload="initial();" class="bg">
<div id="TopBanner"></div>
<div id="Loading" class="popup_bg"></div>
<iframe name="hidden_frame" id="hidden_frame" width="0" height="0" frameborder="0"></iframe>
<form method="post" name="form" action="/start_apply.htm" target="hidden_frame">
<input type="hidden" name="preferred_lang" id="preferred_lang" value="<% nvram_get(" preferred_lang "); %>">
<input type="hidden" name="firmver" value="<% nvram_get(" firmver "); %>">
<input type="hidden" name="current_page" value="">
<input type="hidden" name="next_page" value="">
<input type="hidden" name="action_mode" value="apply">
<input type="hidden" name="action_script" value="">
<input type="hidden" name="action_wait" value="15">
<input type="hidden" name="flag" value="">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<table class="content" align="center" cellpadding="0" cellspacing="0">
<tr>
<td width="17">&nbsp;</td>
<td valign="top" width="202">
<div id="mainMenu"></div>
<div id="subMenu"></div>
</td>
<td valign="top">
<div id="tabMenu" class="submenuBlock"></div>
<table width="98%" border="0" align="left" cellpadding="0" cellspacing="0">
<tr>
<td valign="top">
<table width="760px" border="0" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTitle" id="FormTitle">
<tbody bgcolor="#4D595D">
<tr>
<td valign="top">
<div class="formfonttitle" style="margin:10px 0px 10px 5px; display:inline-block;">FlexQoS Traffic Classification</div>
<!-- <div id="FlexQoS_mod_toggle" style="float:right; color:#FFCC00; display:inline-block; margin:5px; cursor:pointer;" onclick='FlexQoS_mod_toggle()'>Customize</div> -->
<div id="FlexQoS_mod_toggle" style="margin:10px 0px 0px 0px; padding:0 0 0 0; height:22px; width:136px; float:right; font-weight:bold;" class="titlebtn" onclick="FlexQoS_mod_toggle();"><span style="padding:0 0 0" align="center">Customize</span></div>
<div style="margin-bottom:10px" class="splitLine"></div>

<!-- FlexQoS UI Start-->
<div id="FlexQoS_mod" style="display:none;">
<div style="display:inline-block; margin:0px 0px 10px 5px; font-size:14px; text-shadow: 1px 1px 0px black;"><b>QoS Customization</b></div>
<div style="margin:0px 0px 0px 0px; padding:0 0 0 0; height:22px; width:136px; float:right; font-weight:bold;" class="titlebtn" onclick="FlexQoS_mod_apply();"><span style="padding:0 0 0 0" align="center">Apply</span></div>
<div id="iptables_rules_block" style=""></div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable_table">
	<thead>
		<tr>
			<td colspan="4">AppDB Redirection Rules&nbsp;(Max Limit : 32)</td>
		</tr>
	</thead>
	<tbody>
	<tr>
		<th width="auto"><div class="table_text">Application</div></a></th>
		<th width="10%"><a href="javascript:void(0);" onClick="overlib(marksyntax, 500, 500);" onmouseout="nd();"><div class="table_text">Mark</div></a></th>
		<th width="20%"><a href="javascript:void(0);" onClick="overlib(classsyntax, 300, 500);" onmouseout="nd();"><div class="table_text">Class</div></a></th>
		<th width="15%">Edit</th>
	</tr>
	<tr>
		<td width="auto"><div id="appdb_desc_x"></div>
		</td>
		<td width="10%">
			<input type="text" maxlength="6" class="input_6_table" name="appdb_mark_x" onfocusout='validate_mark(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' autocomplete="off" autocorrect="off" autocapitalize="off">
		</td>
		<td width="20%">
			<select name="appdb_class_x" id="appdb_class_x" class="input_option">
			</select>
		</td>
		<td width="15%">
			<div><input type="button" class="add_btn" onClick="addRow_AppDB_Group(32);" value=""></div>
		</td>
	</tr>
</tbody>
</table>
<div id="appdb_rules_block" style=""></div>

<table border="0" cellpadding="0" cellspacing="0" class="FormTable" style="float:left; width:350px; display:inline-table; margin: 10px auto 10px auto">
<thead><td colspan="3">Download Bandwidth<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick='FlexQoS_mod_reset_down()'>Reset</small></td></thead>
	<tbody>
		<tr>
			<th style="min-width:125px;">Class</th>
			<th style="min-width:90px;">Minimum Reserved Bandwidth</th>
			<th style="min-width:90px;">Maximum Allowed Bandwidth</th>
		</tr>
		<tr>
			<th>Net Control</th>
			<td><input id="drp0" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="dcp0" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Work-From-Home</th>
			<td><input id="drp1" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="20"> % </td>
			<td><input id="dcp1" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Gaming</th>
			<td><input id="drp2" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="15"> % </td>
			<td><input id="dcp2" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Others</th>
			<td><input id="drp3" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="10"> % </td>
			<td><input id="dcp3" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Web Surfing</th>
			<td><input id="drp4" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="10"> % </td>
			<td><input id="dcp4" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Streaming</th>
			<td><input id="drp5" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="30"> % </td>
			<td><input id="dcp5" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Game Downloads</th>
			<td><input id="drp6" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="dcp6" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>File Downloads</th>
			<td><input id="drp7" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="dcp7" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
	</tbody>
</table>

<table border="0" cellpadding="0" cellspacing="0" class="FormTable" style="float:right; width:350px; display:inline-table; margin-top:10px; margin: 10px auto 10px auto">
<thead><td colspan="3">Upload Bandwidth<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick='FlexQoS_mod_reset_up()'>Reset</small></td></thead>
	<tbody>
		<tr>
			<th style="min-width:125px;">Class</th>
			<th style="min-width:90px;">Minimum Reserved Bandwidth</th>
			<th style="min-width:90px;">Maximum Allowed Bandwidth</th>
		</tr>
		<tr>
			<th>Net Control</th>
			<td><input id="urp0" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="ucp0" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Work-From-Home</th>
			<td><input id="urp1" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="20"> % </td>
			<td><input id="ucp1" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Gaming</th>
			<td><input id="urp2" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="15"> % </td>
			<td><input id="ucp2" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Others</th>
			<td><input id="urp3" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="30"> % </td>
			<td><input id="ucp3" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Web Surfing</th>
			<td><input id="urp4" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="10"> % </td>
			<td><input id="ucp4" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Streaming</th>
			<td><input id="urp5" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="10"> % </td>
			<td><input id="ucp5" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>Game Downloads</th>
			<td><input id="urp6" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="ucp6" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
		<tr>
			<th>File Downloads</th>
			<td><input id="urp7" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>
			<td><input id="ucp7" onfocusout='validate_percent(this.value)?this.style.removeProperty("background-color"):this.style.backgroundColor="#A86262"' type="text" class="input_6_table" style="margin-left:0px; height:18px;"  maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>
		</tr>
	</tbody>
</table>
<p style="clear:left;clear:right;"></p>
</div>
<!-- FlexQoS UI END-->
<table id="refresh_data" width="100%" border="1" align="center" cellpadding="4" cellspacing="0" bordercolor="#6b8fa3" class="FormTable" style="margin-top:10px;">
<tr>
<th>Automatically refresh data every</th>
<td>
<select name="refreshrate" class="input_option" onchange="refreshRate = this.value; get_data();" id="refreshrate">
<option value="0">No refresh</option>
<option value="3" selected>3 seconds</option>
<option value="5">5 seconds</option>
<option value="10">10 seconds</option>
</select>
<span id="toomanyconns" style="display:none; color:#FFCC00;">Disabled - too many tracked connections.</span>
</td>
</tr>
</table>
<br>
<div id="limiter_notice" style="display:none;font-size:125%;color:#FFCC00;">Note: Statistics not available in Bandwidth Limiter mode.</div>
<div id="no_qos_notice" style="display:none;font-size:125%;color:#FFCC00;">Note: QoS is not enabled.</div>
<div id="tqos_notice" style="display:none;font-size:125%;color:#FFCC00;">Note: Traditional QoS only classifies uploaded traffic.</div>
<table>
<tr id="dl_tr">
<td style="padding-right:50px;font-size:125%;color:#FFCC00;">
<div>Download</div>
<canvas id="pie_chart_dl" width="200" height="200"></canvas>
</td>
<td><span id="legend_dl"></span></td>
</tr>
<tr style="height:50px;">
<td colspan="2">&nbsp;</td>
</tr>
<tr id="ul_tr">
<td style="padding-right:50px;font-size:125%;color:#FFCC00;">
<div>Upload</div>
<canvas id="pie_chart_ul" width="200" height="200"></canvas>
</td>
<td><span id="legend_ul"></span></td>
</tr>
</table>
<br>
<!-- FlexQoS Connection Table Start-->

<table cellpadding="4" class="FormTable_table" id="tracked_filters" style="display:none;"><thead><tr><td colspan="6">Filter connections</td></tr></thead>
	<tr>
		<th width="5%">Proto</th>
		<th width="28%">Local IP</th>
		<th width="6%">Port</th>
		<th width="28%">Remote IP</th>
		<th width="6%">Port</th>
		<th width="27%">Application</th>
	</tr>
	<tr>
		<td><select class="input_option" onchange="set_filter(0, this);">
			<option value="">any</option>
			<option value="tcp">tcp</option>
			<option value="udp">udp</option>
		</select></td>
<!--		<td><input type="text" class="input_18_table" maxlength="39" oninput="set_filter(1, this);"></input></td> -->
		<td><select id="devicefilter" style="max-width: 168px" class="input_option" onchange="set_filter(1, this);">
				<option value=""> </option>
			</select>
		</td>
		<td><input type="text" class="input_6_table" maxlength="5" oninput="set_filter(2, this);"></input></td>
		<td><input type="text" class="input_18_table" maxlength="39" oninput="set_filter(3, this);"></input></td>
		<td><input type="text" class="input_6_table" maxlength="5" oninput="set_filter(4, this);"></input></td>
		<td><input type="text" class="input_18_table" maxlength="48" oninput="set_filter(5, this);"></input></td>
	</tr>
</table>
<table cellpadding="4" class="FormTable_table" id="tracked_connections">
<thead>
   <td id="tracked_connections_total" colspan="6">Tracked connections</td>
</thead>
<tbody id="tableContainer">
   <tr class="row_title">
	  <th width="5%"  style="cursor: pointer;">Proto</th>
	  <th width="28%" style="cursor: pointer;">Local IP</th>
	  <th width="6%"  style="cursor: pointer;">Port</th>
	  <th width="28%" style="cursor: pointer;">Remote IP</th>
	  <th width="6%"  style="cursor: pointer;">Port</th>
	  <th width="27%" style="cursor: pointer;">Application</th>
   </tr>
</tbody>
</table>
<!-- FlexQoS Connection Table End-->
</td>
</tr>
</tbody>
</table>
</td>
</tr>
</table>
</td>
<td width="10" align="center" valign="top">&nbsp;</td>
</tr>
</table>
</form>
<div id="footer"></div>
</body>
