<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<!--
FlexQoS v1.2.3 released 2021-03-07
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
<title>ASUS Wireless Router - FlexQoS</title>
<link rel="stylesheet" type="text/css" href="index_style.css">
<link rel="stylesheet" type="text/css" href="form_style.css">
<link rel="stylesheet" type="text/css" href="usp_style.css">
<link rel="stylesheet" type="text/css" href="device-map/device-map.css">
<link rel="stylesheet" type="text/css" href="/js/table/table.css">
<script type="text/javascript" src="/js/jquery.js"></script>
<script type="text/javascript" src="/js/chart.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/help.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script type="text/javascript" src="/client_function.js"></script>
<script type="text/javascript" src="/validator.js"></script>
<script type="text/javascript" src="/js/httpApi.js"></script>
<script type="text/javascript" src="/js/table/table.js"></script>
<script type="text/javascript" src="/ext/flexqos/flexqos_arrays.js"></script>
<style>
.input_3_table{
margin-top: 2px;
margin-bottom: 2px;
text-align: right;
padding-left: 1px;
padding-right: 4.8px;
}
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
/*the container must be positioned relative:*/
.autocomplete {
position: relative;
display: inline-block;
}

.autocomplete-items {
position: absolute;
border: 1px solid #929EA1;
border-bottom: none;
border-top: none;
z-index: 99;
/*position the autocomplete items to be the same width as the container:*/
top: 100%;
left: 0;
right: 0;
width:352.8px;
text-align:left;
font-size: 12px;
font-family: Lucida Console;
}

.autocomplete-items div {
cursor: pointer;
border:1px outset #999;
background-color:#576D73;
height:auto;
padding: 1px;
}

/*when hovering an item:*/
.autocomplete-items div:hover {
background-color: #2F3A3E;
}

/*when navigating through the items using the arrow keys:*/
.autocomplete-active {
background-color: #2F3A3E !important;
}
td.cat0{
box-shadow: #B3645B 5px 0px 0px 0px inset;
}
td.cat1{
box-shadow: #B98F53 5px 0px 0px 0px inset;
}
td.cat2{
box-shadow: #C6B36A 5px 0px 0px 0px inset;
}
td.cat3{
box-shadow: #849E75 5px 0px 0px 0px inset;
}
td.cat4{
box-shadow: #4C8FC0 5px 0px 0px 0px inset;
}
td.cat5{
box-shadow: #7C637A 5px 0px 0px 0px inset;
}
td.cat6{
box-shadow: #2B6692 5px 0px 0px 0px inset;
}
td.cat7{
box-shadow: #6C604F 5px 0px 0px 0px inset;
}
</style>

<script>
<% login_state_hook(); %>
var custom_settings = <% get_custom_settings(); %>;
var tabledata;		//tabled of tracked connections after device-filtered
var filter = Array(6);
var sortdir = 0;
var sortfield = 5;
var dhcp_start = '<% nvram_get("dhcp_start"); %>';
dhcp_start = dhcp_start.substr(0, dhcp_start.lastIndexOf(".")+1);
<% get_ipv6net_array(); %>

const iptables_default_rules = "<>>udp>>500,4500>>3<>>udp>16384:16415>>>3<>>tcp>>119,563>>5<>>tcp>>80,443>08****>5";
const iptables_default_rulenames = "<WiFi%20Calling<Facetime<Usenet<Game%20Downloads";
const appdb_default_rules = "<000000>6<00006B>6<0D0007>5<0D0086>5<0D00A0>5<12003F>4<13****>4<14****>4";
const bandwidth_default_rules = "<5>15>30>20>10>5>10>5<100>100>100>100>100>100>100>100<5>15>10>20>10>5>30>5<100>100>100>100>100>100>100>100";
var iptables_rulelist_array="";
var iptables_rulename_array="";
var iptables_temp_array=[];
var iptables_names_temp_array=[];
var appdb_temp_array=[];
var appdb_rulelist_array="";
var iptables_rules = [];	// array for iptables rules
var appdb_rules = [];	// array for appdb rules
var tableClassMenuCode = {};		// this object is used in the show_iptables_rules tableStruct
var qos_dlbw = '<% nvram_get("qos_ibw"); %>';		// download bandwidth set in QoS settings
var qos_ulbw = '<% nvram_get("qos_obw"); %>';		// upload bandwidth set in QoS settings
if (qos_dlbw > 0 && qos_ulbw > 0)
	var qos_bwmode = 1;	// Manual
else
	var qos_bwmode = 0;	// Auto

var qos_type = '<% nvram_get("qos_type"); %>';
if ('<% nvram_get("qos_enable"); %>' == 0) { // QoS disabled
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
	var bwdpi_app_rulelist = '<% nvram_get("bwdpi_app_rulelist"); %>'.replace(/&#60/g, "<");
	var bwdpi_app_rulelist_row = bwdpi_app_rulelist.split("<");
	if (bwdpi_app_rulelist == "" || bwdpi_app_rulelist_row.length != 9) {
		bwdpi_app_rulelist = "9,20<8<4<0,5,6,15,17<4,13<13,24<1,3,14<7,10,11,21,23<";
		bwdpi_app_rulelist_row = bwdpi_app_rulelist.split("<");
	}
	var category_title = ["Net Control Packets", "Gaming", "Video and Audio Streaming", "Work-From-Home", "Web Surfing", "File Transferring", "Others", "Learn-From-Home"];
	var class_title = ["Net Control", "Gaming", "Streaming", "Work-From-Home", "Web Surfing", "File Transfers", "Others", "Learn-From-Home"];
	var cat_id_array = [
		[9, 20],
		[8],
		[4],
		[0, 5, 6, 15, 17],
		[13, 24],
		[1, 3, 14],
		[7, 10, 11, 21, 23]
	];
	if ( bwdpi_app_rulelist_row.indexOf("4,13") < 0 ) {
		cat_id_array.push([]);
		var qos_default=7;
	} else {
		cat_id_array.push([4, 13]);
		var qos_default=bwdpi_app_rulelist_row.indexOf("0,5,6,15,17");
	}
} else {
	var category_title = ["", "Highest", "High", "Medium", "Low", "Lowest"];
}

/* ATM, overhead, pmu, label */
var overhead_presets = [
	["1", "48", "0", "Conservative default"],
	["0", "42", "84", "Ethernet with VLAN"],
	["0", "18", "64", "Cable (DOCSIS)"],
	["0", "27", "0", "PPPoE VDSL"],
	["1", "32", "0", "RFC2684/RFC1483 Bridged LLC/Snap"],
	["1", "32", "0", "ADSL PPPoE VC/Mux"],
	["1", "40", "0", "ADSL PPPoE LLC/Snap"],
	["0", "19", "0", "VDSL Bridged/IPoE"],
	["2", "30", "0", "VDSL2 PPPoE PTM"],
	["2", "22", "0", "VDSL2 Bridged PTM"]
	];

var line_obj_ul, line_obj_dl;
var refreshRate;
var timedEvent = 0;
var filter = Array(6);
const maxshown = 500;
const maxrendered = 750;
var maxdatapoints = 50;
var color = ["#B3645B", "#B98F53", "#C6B36A", "#849E75", "#4C8FC0",  "#7C637A", "#2B6692",  "#6C604F"];
var labels_array = [];
var line_labels_array = [];
var ulrate_array = new Array(8);
var dlrate_array = new Array(8);

/* prototype function to respect user locale number formatting for fixed decimal point numbers */
Number.prototype.toLocaleFixed = function(n) {
	return this.toLocaleString(undefined, {
		minimumFractionDigits: n,
		maximumFractionDigits: n
	});
};

/* helper function from https://github.com/chartjs/Chart.js/issues/4722#issuecomment-353067548 */
var helpers = Chart.helpers;
/* logarithmic formatter function */
var logarithmicFormatter = function(tickValue, index, ticks) {
	var me = this;
	var labelOpts =  me.options.ticks.labels || {};
	var labelIndex = labelOpts.index || ['min', 'max'];
	var labelSignificand = labelOpts.significand || [1, 2, 5];
	var significand = tickValue / (Math.pow(10, Math.floor(helpers.log10(tickValue))));
	var emptyTick = labelOpts.removeEmptyLines === true ? undefined : '';
	var namedIndex = '';
	 if (index === 0) {
		namedIndex = 'min';
	} else if (index === ticks.length - 1) {
		namedIndex = 'max';
	}
	 if (labelOpts === 'all'
		|| labelSignificand.indexOf(significand) !== -1
		|| labelIndex.indexOf(index) !== -1
		|| labelIndex.indexOf(namedIndex) !== -1
	) {
		if (tickValue === 0) {
			return '0';
		} else {
			return comma(tickValue).padStart(comma(qos_dlbw).length);
		}
	}
	return emptyTick;
};
var lineOptions = {
	title: {
		fontColor: '#FFFFFF',
		fontSize: 13,
		display: true,
		padding: 5
	},
	fill: false,
	animationEasing: "easeOutQuart",
	animationSteps: 100,
	animateScale: true,
	legend: {
		display: false
	},
	scales: {
		xAxes: [{
			display: false
		}],
		yAxes: [{
			type: 'linear',
			scaleLabel: {
				display: true,
				labelString: 'Rate (kb/s)',
				fontColor: '#FFCC00'
			},
			ticks: {
					display: true,
					fontColor: "#FFFFFF",
					fontSize: 11,
					callback: function(value, index, values) {
						return comma(value).padStart(comma(qos_dlbw).length);
					},
					labels: {
						index:  ['min', 'max'],
						significand:  [1, 2, 5],
						removeEmptyLines: true
					}
			}
		}]
	},
	elements: {
		line: {
			borderWidth: 2,
			tension: 0
		},
		point: {
			radius: 2,
			hoverRadius: 3
		}
	},
	tooltips: {
		callbacks: {
			label: function(tooltipItem, data) {
				var label = data.datasets[tooltipItem.datasetIndex].label;
				var value = data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index];
				return label + ': ' + comma(value) + ' kb/s';
			}
		}
	}
} // lineOptions
// Set default fonts to match rest of UI
Chart.defaults.global.defaultFontFamily = "'Arial', 'Helvetica', 'MS UI Gothic', 'MS P Gothic', sans-serif";

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
	if (o.value != "!") {
		if ( document.form.savefilter.checked )
			SetCookie("filter"+field,o.value);
		if (field == 5 && o.value.search(/^!?Class:[0-7]$/) >= 0)
			filter[field] = o.value.replace(/Class:/,"") + '>';
		else
			filter[field] = o.value.toLowerCase();
		draw_conntrack_table();
	}
}

function populate_filters() {
	var filterVal="";
	var saveFilter = GetCookie("savefilter","number");
	if ( saveFilter == "1" )
		document.form.savefilter.checked = true;
	else {
		document.form.savefilter.checked = false;
		return;	// don't load filters
	}

	for (var i=0;i<6;i++) {
		filterVal=GetCookie("filter"+i,"string");
		if (filterVal) {
			document.getElementById('filter'+i).value=filterVal;
			if (i == 5 && filterVal.search(/^!?Class:[0-7]$/) >= 0)
				filter[i] = filterVal.replace(/Class:/,"") + '>';
			else
				filter[i] = filterVal.toLowerCase();
		}
	}
}

function save_filter() {
	var saveFilter = document.form.savefilter.checked;
	if ( saveFilter ) {
		SetCookie("savefilter",1);
		for (var i=0;i<6;i++) {
			if ( document.getElementById('filter'+i).value )
				SetCookie('filter'+i,document.getElementById('filter'+i).value);
			else
				DelCookie('filter'+i);
		}
	}
	else {
		SetCookie("savefilter",0);
		for (var i=0;i<6;i++)
			DelCookie('filter'+i);
	}
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
		for (j = 0; j < 5; j++) { // only check proto, IP and ports; defer application check until after rule eval
			if (filter[j]) {
				switch (j) {
					case 0:
						if (bwdpi_conntrack[i][j].toLowerCase() != filter[j].toLowerCase())
							filtered = 1;
						break;
					default:
						if (filter[j].charAt(0)=="!") {
							if (bwdpi_conntrack[i][j].toLowerCase().indexOf(filter[j].replace("!", "")) >= 0)
								filtered = 1;
						} else if (filter[j].charAt(filter[j].length-1)=="$") {
							if (bwdpi_conntrack[i][j].toLowerCase() != filter[j].replace("$", "").toLowerCase())
								filtered = 1;
						} else {
							if (bwdpi_conntrack[i][j].toLowerCase().indexOf(filter[j]) < 0)
								filtered = 1;
						}
				}
				if (filtered) break;	// stop processing additional filters
			}
		}
		if (filtered) continue;
		shownlen++;

		var rule_result = eval_rule(bwdpi_conntrack[i][1], bwdpi_conntrack[i][3], bwdpi_conntrack[i][0], bwdpi_conntrack[i][2], bwdpi_conntrack[i][4], bwdpi_conntrack[i][7], bwdpi_conntrack[i][6], bwdpi_conntrack[i][5]);
		if (rule_result.qosclass == 99)		// 99 means no rule match so use default class for connection category
			rule_result.qosclass = get_qos_class(bwdpi_conntrack[i][7], bwdpi_conntrack[i][6]);
		// Prepend Class priority number for sorting, but only prepend it once
		if ( ! bwdpi_conntrack[i][5].startsWith(rule_result.qosclass+'>') )
			bwdpi_conntrack[i][5] =	rule_result.qosclass + '>' + rule_result.desc;
		if (filter[5]) { // Application filter to be evaluated after rules applied
			if (filter[5].charAt(0)=="!") {
				if (bwdpi_conntrack[i][5].toLowerCase().indexOf(filter[5].replace("!", "")) >= 0) {
					shownlen--;
					continue;
				}
			} else {
				if (bwdpi_conntrack[i][5].toLowerCase().indexOf(filter[5]) < 0) {
					shownlen--;
					continue;
				}
			}
		}
		tabledata.push(bwdpi_conntrack[i]);
	}
	//draw table
	document.getElementById('tracked_connections_total').innerText = "Tracked connections (total: " + tracklen + (shownlen < tracklen ? ", shown: " + shownlen : "") + ")";
	updateTable();
}

function setsort(newfield) {
	if (newfield != sortfield) {
		sortdir = 0;
		sortfield = newfield;
	 } else {
		sortdir = (sortdir ? 0 : 1);
	}
}

function table_sort(a, b){
	var aa, bb;
	switch (sortfield) {
		case 1:		// Source IP
		case 3:		// Destination IP
			if (sortdir) {
				aa = full_IPv6(a[sortfield].toString());
				bb = full_IPv6(b[sortfield].toString());
				if (aa == bb) return 0;
				else if (aa > bb) return -1;
				else return 1;
			} else {
				aa = full_IPv6(a[sortfield].toString());
				bb = full_IPv6(b[sortfield].toString());
				if (aa == bb) return 0;
				else if (aa > bb) return 1;
				else return -1;
			}
			break;
		case 2:		// Local Port
		case 4:		// Remote Port
			if (sortdir)
				return parseInt(b[sortfield]) - parseInt(a[sortfield]);
			else
				return parseInt(a[sortfield]) - parseInt(b[sortfield]);
			break;
		case 0:		// Proto
		case 5:		// Label
			aa = a[sortfield].toLowerCase();
			bb = b[sortfield].toLowerCase();
			if (sortdir) {
				if(aa == bb) return 0;
				else if(aa > bb) return -1;
				else return 1;
			} else {
				if(aa == bb) return 0;
				else if(aa > bb) return 1;
				else return -1;
			}
			break;
	}
}

function updateTable()
{
	var clientObj, clientName;
	//sort table data
	if (sortfield < 5)
		tabledata.sort(function(a,b) {return a[5].localeCompare(b[5])} );
	else
		tabledata.sort(function(a,b) {return a[1].localeCompare(b[1])} );
	tabledata.sort(table_sort);

	genClientList();

	//generate table
	var code = '<tr class="row_title">' +
		'<th width="5%" id="track_header_0" style="cursor: pointer;" onclick="setsort(0); updateTable()">Proto</th>' +
		'<th width="28%" id="track_header_1" style="cursor: pointer;" onclick="setsort(1); updateTable()">Local IP</th>' +
		'<th width="6%" id="track_header_2" style="cursor: pointer;" onclick="setsort(2); updateTable()">Port</th>' +
		'<th width="28%" id="track_header_3" style="cursor: pointer;" onclick="setsort(3); updateTable()">Remote IP</th>' +
		'<th width="6%" id="track_header_4" style="cursor: pointer;" onclick="setsort(4); updateTable()">Port</th>' +
		'<th width="27%" id="track_header_5" style="cursor: pointer;" onclick="setsort(5); updateTable()">Application</th></tr>';

	for(var i = 0; i < tabledata.length; i++){
		var qos_class = tabledata[i][5].split(">")[0];
		var label = tabledata[i][5].split(">")[1];
		var mark = (parseInt(tabledata[i][7]).toString(16).padStart(2,'0') + parseInt(tabledata[i][6]).toString(16).padStart(4,'0')).toUpperCase();
		// Retrieve hostname from networkmap
		clientObj = clientFromIP(tabledata[i][1]);
		if (clientObj) {
			clientName = (clientObj.nickName == "") ? clientObj.name : clientObj.nickName;
		}
		else if (tabledata[i][1].indexOf(":") >= 0) {		// IPv6 connection
			for ( var element of ipv6clientarray) {			// Loop through IPv6 leases to find a IPv6 match
				if ( element[2] ){
					if( element[2].replace(/[0-9a-f]{2},|[0-9a-f]{2}$/g,"00").indexOf(tabledata[i][1]) >= 0 ) {		// replace last 2 chars with 00 due to TM bug. Multiple comma-separated entries can be present.
						var clientMAC = element[1].toUpperCase(); // MAC address
						if ( clientList[clientMAC] ) {
							clientName = (clientList[clientMAC].nickName == "") ? clientList[clientMAC].name : clientList[clientMAC].nickName;
							break;
						}
					}
					else {		// No IPv6 lease match, so use raw IP
						srchost = tabledata[i][1];
						clientName = "";
					}
				}
			};
		}
		else {
			srchost = tabledata[i][1];
			clientName = "";
		}
		srchost = (clientName == "") ? tabledata[i][1] : clientName;

		code += '<tr>'
		+ '<td>' + tabledata[i][0] + '</td>'
		+ '<td title="' + tabledata[i][1]  + '"' + (srchost.length > 32 ? ' style="font-size: 80%;"' : '') + '>' + srchost + '</td>'
		+ '<td>' + tabledata[i][2] + '</td>'
		+ '<td' + (tabledata[i][3].length > 32 ? " style=\"font-size: 80%;\"" : "") + '>' + tabledata[i][3] +'</td>'
		+ '<td>' + tabledata[i][4] + '</td>'
		+ '<td class="t_item"' + 'title="' + labels_array[qos_class] + '">'
		+ '<span class="t_label catrow cat' + qos_class + '"' + (label.length > 29 ? 'style="font-size: 75%;"' : '') + '>' + label + '</span>'
		+ '<span class="t_mark  catrow cat' + qos_class + '"' + (label.length > 29 ? 'style="font-size: 75%;"' : '') + '>MARK:' + mark + '</span>'
		+ '</td></tr>';
	}
	if (tabledata.length == maxshown)
	{
		code += '<tr><td colspan="6"><span style="text-align: center;">List truncated to ' + maxshown + ' elements - use a filter</td></tr>';
	}
	document.getElementById('tableContainer').innerHTML = code;
	document.getElementById('track_header_' + sortfield).style.boxShadow = "rgb(255, 204, 0) 0px " + (sortdir == 1 ? "1" : "-1") + "px 0px 0px inset";
}

function comma(n) {
	return parseInt(n).toLocaleString();
}

function populate_class_menus(){
	var selectCode = "";
	var dropdownCode = "";
	for (i=0;i<bwdpi_app_rulelist_row.length-1;i++) {
		for (j=0;j<cat_id_array.length;j++) {
			if (cat_id_array[j] == bwdpi_app_rulelist_row[i]) {
				var index = j;
				break;
			}
		}
		selectCode += '<option value="' + index + '">' + class_title[index] + "</option>\n";
		dropdownCode += '<a><div onclick="setApplicationClass(' + i + ');">' + class_title[index] + '</div></a>';
		tableClassMenuCode[class_title[index]] = index;		// this object is used in the show_iptables_rules tableStruct
	}
	document.getElementById('appdb_class_x').innerHTML=selectCode;
	document.getElementById('flexqos_outputcls').innerHTML=selectCode;
	document.getElementById('QoS_Class_List').innerHTML=dropdownCode;
} // populate_class_menus

function populate_bandwidth_table() {
	var code = "";
	for (i=0;i<bwdpi_app_rulelist_row.length-1;i++) {
		for (j=0;j<cat_id_array.length;j++) {
			if (cat_id_array[j] == bwdpi_app_rulelist_row[i]) {
				var index = j;
				break;
			}
		}
		code += '<tr>' +
		'<td class="cat' + i + '">' + class_title[index] + '</td>' +
		'<td><input id="drp' + index + '" onfocusout="validate_percent(this)" type="text" class="input_3_table" maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>' +
		'<td><input id="dcp' + index + '" onfocusout="validate_percent(this)" type="text" class="input_3_table" maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>' +
		'<td align="center"><div id="dp' + index + '_desc"></div></td>' +
		'<td><input id="urp' + index + '" onfocusout="validate_percent(this)" type="text" class="input_3_table" maxlength="2" autocomplete="off" autocorrect="off" autocapitalize="off" value="5"> % </td>' +
		'<td><input id="ucp' + index + '" onfocusout="validate_percent(this)" type="text" class="input_3_table" maxlength="3" autocomplete="off" autocorrect="off" autocapitalize="off" value="100"> % </td>' +
		'<td align="center"><div id="up' + index + '_desc"></div></td>' +
		'</tr>';
	}
	code += '<tr id="qos_rates_warn" style="display:none;"><td>' +
	'<td colspan="3"><div id="qos_drates_warn" style="display:none;color:#FFCC00;text-align: center;">The total Minimum Bandwidth exceeds 100%!</div></td>' +
	'<td colspan="3"><div id="qos_urates_warn" style="display:none;color:#FFCC00;text-align: center;">The total Minimum Bandwidth exceeds 100%!</div></td>' +
	'</tr>';
	document.getElementById('bandwidth_block').innerHTML=code;
} // populate_bandwidth_table

function setApplicationClass(val){
	document.form.appfilter_x.value = 'Class:' + val;
	hideClasses_Block();
	set_filter(5, document.form.appfilter_x);
}

function hideClasses_Block(){
	document.getElementById("class_pull_arrow").src = "/images/arrow-down.gif";
	document.getElementById('QoS_Class_List').style.display='none';
}

function pullClassList(obj) {
	var element = document.getElementById('QoS_Class_List');
	var isMenuopen = element.offsetWidth > 0 || element.offsetHeight > 0;
	if(isMenuopen == 0) {
		obj.src = "/images/arrow-top.gif"
		element.style.display = 'block';
		document.form.appfilter_x.focus();
	}
	else
		hideClasses_Block();
}

function initial() {
	SetCurrentPage();
	show_menu();
	if (qos_mode != 2){		//if Adaptive QoS is not enabled
		document.getElementById('no_aqos_notice').style.display = "";
		document.getElementById('refresh_data').style.display = "none";
		document.getElementById('dl_tr').style.display = "none";
		document.getElementById('ul_tr').style.display = "none";
		document.getElementById('tracked_filters').style.display = "none";
		document.getElementById('tracked_connections').style.display = "none";
		document.getElementById('refreshrate').value = "0";
		var element = document.getElementById('FlexQoS_mod_toggle');
		element.innerText="A.QoS Disabled";
		element.setAttribute("onclick","location.href='QoS_EZQoS.asp';");
		refreshRate = 0;
		return;
	}
	populate_bandwidth_table();
	populate_class_menus();
	set_FlexQoS_mod_vars();
	setTimeout("showDropdownClientList('setClientIP', 'ip', 'all', 'ClientList_Block_PC', 'lip_pull_arrow', 'all');", 1000);
	refreshRate = document.getElementById('refreshrate').value;
	populate_filters();
	initialize_charts();
	get_data();
	show_iptables_rules();
	show_appdb_rules();
	check_bandwidth();
	well_known_rules();
	// Setup appdb auto-complete menu
	autocomplete(document.getElementById("appdb_search_x"), catdb_label_array);
	build_overhead_presets();
}

function build_overhead_presets(){
	var code = "";
	for(var i = 0; i < overhead_presets.length; i++) {
		code += '<a><div onclick="set_overhead(' + i +');">' + overhead_presets[i][3] + '</div></a>';
	}
	document.getElementById("overhead_presets_list").innerHTML += code;
	$(".ovh_pull_arrow").show();
} // build_overhead_presets

function pullOverheadList(_this) {
	event.stopPropagation();
	var $element = $("#overhead_presets_list");
	var isMenuopen = $element[0].offsetWidth > 0 || $element[0].offsetHeight > 0;
	if(isMenuopen == 0) {
		$(_this).attr("src","/images/arrow-top.gif");
		$element.show();
	}
	else {
		$(_this).attr("src","/images/arrow-down.gif");
		$element.hide();
	}
} // pullOverheadList

function set_overhead(entry){
	var framing = overhead_presets[entry][0];
	document.getElementById('qos_overhead').value = overhead_presets[entry][1];
	if (framing == 2)
		framing = 0;	// fq_codel does not support ptm compensation
	document.getElementById('qos_atm_x').checked = (framing == "1" ? true : false);
	document.getElementById("ovh_pull_arrow").src = "/images/arrow-down.gif";
	document.getElementById('overhead_presets_list').style.display='none';
} // set_overhead

function get_qos_class(category, appid) {
	var i, j, catlist, rules;
	if (category == 0 && appid == 0)
		return qos_default;
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

function create_rule(Lip, Rip, Proto, Lport, Rport, Mark, Dst, Desc){
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
	//rule[19]=Rule Description
	//rule[20]=Mark inverse match (!) bool

	rule[0]=0;
	if (Dst)	rule[18]=bwdpi_app_rulelist_row.indexOf(cat_id_array[Dst].toString());
	if (Desc)	rule[19]=decodeURIComponent(Desc);
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

	if ( Mark )
	{
		rule[0]+=64;
		if(Mark.startsWith("!")) {
			rule[20]=1;
			Mark=Mark.replace("!", "");
		}

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

function eval_rule(CLip, CRip, CProto, CLport, CRport, CCat, CId, CDesc){
	for (i=0;i<iptables_rules.length;i++) {
		//eval false if rule has no filters or destination specified
		if (!iptables_rules[i] || !iptables_rules[i][0] || (iptables_rules[i][18]==undefined) )
		{
			// console.log("rule is not configured");
			continue;
		}

		if ( iptables_rules[i][1] && CProto != iptables_rules[i][1] && iptables_rules[i][1] != "both" )
		{
			// console.log("protocol mismatch");
			continue;
		}

		//if rule has local/remote ports specified
		if (iptables_rules[i][0] & 15)
		{
			if ((iptables_rules[i][0] & 15) <= 3 )							//if port rule is NOT a multiport match
			{
				if ( (iptables_rules[i][0] & 1) && !((CLport >= iptables_rules[i][3] && CLport <= iptables_rules[i][4])^(iptables_rules[i][2])) )
				{
					// console.log("local port mismatch");
					continue;
				}
				if ( (iptables_rules[i][0] & 2) && !((CRport >= iptables_rules[i][7] && CRport <= iptables_rules[i][8])^(iptables_rules[i][6])) )
				{
					// console.log("remote port mismatch");
					continue;
				}
			}
			else if ((iptables_rules[i][0] & 15) == "4" )						//if port rule is ONLY a local multiport match
			{
				var match=false;
				for (var j = 0; j < iptables_rules[i][5].length; j++) {
					if(iptables_rules[i][5][j] == CLport) 	match=true;
				}
				if (iptables_rules[i][2]) 					match=!(match);
				if (match == false)
				{
				  // console.log("local multiport mismatch");
				  continue;
				}
			}
			else if ((iptables_rules[i][0] & 15) == "8" )						//if port rule is ONLY a remote multiport match
			{
				var match=false;
				for (var j = 0; j < iptables_rules[i][9].length; j++) {
				  if(iptables_rules[i][9][j] == CRport) 	match=true;
				}
				if (iptables_rules[i][6]) 				match=!(match);
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
		if (iptables_rules[i][0] & 64)
		{
			var match=false;
			if (iptables_rules[i][16] == CCat)	match=true;
			if (iptables_rules[i][20])			match=!(match);
			if (match == false)
			{
				// console.log("category mismatch");
				continue;
			}
		}

		// if rule has mark id specified
		if (iptables_rules[i][0] & 128)
		{
			var match=false;
			if (iptables_rules[i][17] == CId)	match=true;
			if (iptables_rules[i][20])			match=!(match);
			if (match == false)
			{
				// console.log("traffic ID mismatch");
				continue;
			}
		}

		// if rule has local IP specified and is not IPv6
		if (iptables_rules[i][0] & 16)
		{
			if ( CLip.indexOf(":") < 0 ) {
				var tmpCLip=ip2dec(CLip);
				if ( !((tmpCLip >= iptables_rules[i][11] && tmpCLip <= iptables_rules[i][12])^(iptables_rules[i][10])) )
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
		if (iptables_rules[i][0] & 32)
		{
			if ( CRip.indexOf(":") < 0 ) {
				var tmpCRip=ip2dec(CRip);
				if ( !((tmpCRip >= iptables_rules[i][14] && tmpCRip <= iptables_rules[i][15])^(iptables_rules[i][13])) )
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
		// stop at first match
		return { qosclass: iptables_rules[i][18], desc: iptables_rules[i][19] };
	} // for each iptables rule in array

	for (i=0;i<appdb_rules.length;i++) {
		if (!appdb_rules[i] || !appdb_rules[i][0] || (appdb_rules[i][18]==undefined) )
		{
			// console.log("rule is not configured");
			continue;
		}

		// if rule has mark cat specified
		if ( (appdb_rules[i][0] & 64) && (appdb_rules[i][16] != CCat) )
		{
			// console.log("category mismatch");
			continue;
		}

		// if rule has mark id specified
		if ( (appdb_rules[i][0] & 128) && (appdb_rules[i][17] != CId) )
		{
			// console.log("traffic ID mismatch");
			continue;
		}

		// if rule has id specified, append ~
		if ((appdb_rules[i][0] & 128) && ! (CCat == "0" && CId == "0") )
			CDesc = CDesc + ' ~';

		// console.log("rule matches current connection");
		return { qosclass: appdb_rules[i][18], desc: CDesc };
	} // for each appdb rule in array
	// if we reach here, we either have a connection that matches nothing and will return 99
	return { qosclass: 99, desc: CDesc };
}  // eval_rule

function redraw() {
	var code;
	var timeLabel = new Date().toLocaleTimeString();
	line_labels_array.push(timeLabel);
	if (line_labels_array.length > maxdatapoints)
		line_labels_array.splice(0,1);

	tcdata_lan_array.sort(function(a, b) {
		return a[0] - b[0]
	});
	code = draw_chart(tcdata_lan_array, "dl");
	document.getElementById('legend_dl').innerHTML = code;

	tcdata_wan_array.sort(function(a, b) {
		return a[0] - b[0]
	});
	code = draw_chart(tcdata_wan_array, "ul");
	document.getElementById('legend_ul').innerHTML = code;

	lineOptions.animation = false; // Only animate first time
}

function get_data() {
	if (timedEvent) {
		clearTimeout(timedEvent);
		timedEvent = 0;
	}
	if (refreshRate == 0) return;
	$.ajax({
		url: '/ajax_gettcdata.asp',
		dataType: 'script',
		error: function(xhr) {
			get_data();
		},
		success: function(response) {
			redraw();
			draw_conntrack_table();
			timedEvent = setTimeout("get_data();", refreshRate * 1000);
		}
	});
}

function draw_chart(data_array, chartdir) {
	var code = '<table><thead style="text-align:left;"><tr><th style="padding-left:5px;">Class</th><th style="text-align:right;padding-left:5px;width:76px;">Rate</th><th style="text-align:right;padding-left:5px;width:76px;">Total Data</th></tr></thead>';
	var rate_array = window[chartdir+"rate_array"];
	var datasetarray = [];
	var rate = 0;
	labels_array = [];
	for (i = 0; i < data_array.length - 1; i++) {
		var sent = parseInt(data_array[i][1]);		// Sent
		var tcclass = parseInt(data_array[i][0]);
		rate = rate2kbs(data_array[i][2]);
		var index = 0;
		for (j = 1; j < cat_id_array.length; j++) {
			if (cat_id_array[j] == bwdpi_app_rulelist_row[i]) {
				index = j;
				break;
			}
		}
		var label = category_title[index];
		labels_array.push(label);
		var unit = " B";
		if (sent > 1024) {
			sent = sent / 1024;
			unit = " KB";
		}
		if (sent > 1024) {
			sent = sent / 1024;
			unit = " MB";
		}
		if (sent > 1024) {
			sent = sent / 1024;
			unit = " GB";
		}
		code += '<tr><td style="word-wrap:break-word;padding-left:5px;padding-right:5px;border:1px #2f3a3e solid; border-radius:5px;background-color:' + color[i] + ';margin-right:10px;line-height:20px;">' + label + '</td>';
		code += '<td style="text-align:right;padding-left:5px;width:76px;">' + comma(rate) + ' kb</td>';
		code += '<td style="text-align:right;padding-left:5px;">' + sent.toLocaleFixed(2) + unit + '</td></tr>';
		rate_array[i].push(rate);
		if (rate_array[i].length > maxdatapoints)
			rate_array[i].splice(0,1);
	}
	code += '</table>';

	for (var i=0;i<8;i++)
		datasetarray.push({ data: rate_array[i], label: labels_array[i], order: i, fill: false, borderColor: color[i], backgroundColor: color[i]});
	var lineData = {
			labels: line_labels_array,
			datasets: datasetarray
	};
	if (chartdir == "ul") {
		lineOptions.title.text = "Upload";
	} else {
		lineOptions.title.text = "Download";
	};
	var chartObj = window['line_obj_'+chartdir];
	chartObj.data = lineData;
	chartObj.options = lineOptions;
	chartObj.update();
	return code;
}

function initialize_charts() {
	// Instantiate the charts one time and update data later based on refresh rate
	var graphLoadTime = new Date();		// Get initial load time in milliseconds for further calculations of historic graph ticks
	var secondsOffset = 0;
	var ctx_dl = document.getElementById("line_chart_dl").getContext("2d");		// download chart canvas
	var ctx_ul = document.getElementById("line_chart_ul").getContext("2d");		// upload chart canvas
	for (var k=0;k<8;k++){
		// Initialize dl and ul arrays with zeros for flatline initial chart
		dlrate_array[k] = new Array();
		ulrate_array[k] = new Array();
		for (var l=0;l<maxdatapoints;l++){
			dlrate_array[k].push(0);
			ulrate_array[k].push(0);
		}
	}
	for (var k=0;k<maxdatapoints;k++){
		// Initialize x-axis time labels with historic intervals from the time the page was loaded
		secondsOffset = refreshRate*k*1000;		// use refresh rate * interval * 1000 ms (1 second)
		var timeLabel = new Date(graphLoadTime-secondsOffset);		// load time in ms less the calculated offset in ms
		line_labels_array.unshift(timeLabel.toLocaleTimeString());	// insert at start of label array in user locale time format
	}
	change_chart_scale();
	// Setup downlaod chart
	var lineData = {
			labels: line_labels_array,
			datasets: dlrate_array
	};
	lineOptions.title.text = "Download";
	var line_obj = new Chart(ctx_dl, {
		type: 'line',
		data: lineData,
		options: lineOptions
	});
	line_obj_dl=line_obj;		// actually draws the chart on the page
	// Setup uplaod chart
	var lineData = {
			labels: line_labels_array,
			datasets: ulrate_array
	};
	lineOptions.title.text = "Upload";
	var line_obj = new Chart(ctx_ul, {
		type: 'line',
		data: lineData,
		options: lineOptions
	});
	line_obj_ul=line_obj;		// actually draws the chart on the page
} // initialize_charts

function change_chart_scale(input) {
	var chart_scale = cookie.get('flexqos_rate_graph_scale');
	if ( input == null ) {
		// Set scale from user options
		if ( chart_scale != null ) {
			if ( chart_scale == "1" )
				document.form.rate_graph_scale.value = 1;
			else
				document.form.rate_graph_scale.value = 0;
		}
		else
			document.form.rate_graph_scale.value = 0;
		input = document.form.rate_graph_scale.value;
	}

	switch (input) {
		case "1":
			lineOptions.scales.yAxes[0].type = "logarithmic";
			lineOptions.scales.yAxes[0].ticks.labels = { index:  ['min', 'max'], significand:  [1, 2, 5], removeEmptyLines: true };
			lineOptions.scales.yAxes[0].ticks.userCallback = logarithmicFormatter;
			cookie.set("flexqos_rate_graph_scale", input, 31);
			break;
		default:
			lineOptions.scales.yAxes[0].type = "linear";
			lineOptions.scales.yAxes[0].ticks.labels = "";
			lineOptions.scales.yAxes[0].ticks.userCallback = "";
			cookie.unset("flexqos_rate_graph_scale");
			break;
	}
} // change_chart_scale

function rate2kbs(rate)
{
	if (rate)
	{
		if (rate.includes("Mbit"))
		{
			return ( parseInt(rate.replace(/[^0-9]/g,"")*1000) );
		}
		else if (rate.includes("Kbit"))
		{
			return ( parseInt(rate.replace(/[^0-9]/g,"")) );
		}
		else if (rate.includes("bit"))
		{
			return ( parseInt(rate.replace(/[^0-9]/g,"")/1000) );
		}
	}

	return 0
}

function check_duplicate(){
	var rule_num = document.getElementById('appdb_rulelist_table').rows.length;
	for(i=0; i<rule_num; i++){
		if(document.getElementById('appdb_rulelist_table').rows[i].cells[1].innerText == document.form.appdb_mark_x.value) {
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
	if(document.form.appdb_mark_x.value.length != 6)
		return false;
	if(!validate_mark(document.form.appdb_mark_x.value))
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
		document.form.appdb_desc_x.value="";
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
				appdb_rulelist_value += class_title.indexOf(document.getElementById('appdb_rulelist_table').rows[k].cells[j].innerText);
			else if (j == 1)
				appdb_rulelist_value += document.getElementById('appdb_rulelist_table').rows[k].cells[j].innerText;
		}
	}
	appdb_rulelist_array = appdb_rulelist_value;
	if(appdb_rulelist_array == "")
	show_appdb_rules();
}

function edit_appdb_Row(r){
	var i=r.parentNode.parentNode.rowIndex;
	document.form.appdb_desc_x.value = document.getElementById('appdb_rulelist_table').rows[i].cells[0].innerText;
	document.form.appdb_mark_x.value = document.getElementById('appdb_rulelist_table').rows[i].cells[1].innerText;
	document.form.appdb_class_x.value = class_title.indexOf(document.getElementById('appdb_rulelist_table').rows[i].cells[2].innerText);
	del_appdb_Row(r);
}

tableValidator.qosPortRange = {
	keyPress : function($obj,event) {
		var objValue = $obj.val();
		var keyPressed = event.keyCode ? event.keyCode : event.which;
		if (tableValid_isFunctionButton(event)) {
			return true;
		}
		if ((keyPressed > 47 && keyPressed < 58)) {	//0~9
			return true;
		}
		else if (keyPressed == 58 && objValue.length > 0) { // colon :
			for(var i = 0; i < objValue.length; i++) {
				var c = objValue.charAt(i);
				if (c == ':' || c == ',')
					return false;
			}
			return true;
		}
		else if (keyPressed == 33) { // exclamation !
			if(objValue.length > 0 && objValue.length < $obj[0].attributes.maxlength.value && objValue.charAt(0) != '!') { // field already has value; only allow ! as first char
				$obj.val('!' + objValue);
			}
			else if (objValue.length == 0)
				return true;
			return false;
		}
		else if (keyPressed == 44 && objValue.length > 0){ // comma ,
			for(var i = 0; i < objValue.length; i++) {
				var c = objValue.charAt(i);
				if (c == ':')
					return false;
			}
			return true;
		}
		return false;
	},
	blur : function(_$obj) {
		var eachPort = function(num, min, max) {
			if(num < min || num > max) {
				return false;
			}
			return true;
		};
		var hintMsg = "";
		var _value = _$obj.val();
		_value = $.trim(_value);
		_$obj.val(_value);

		if(_value == "") {
			if(_$obj.hasClass("valueMust"))
				hintMsg = "Fields cannot be blank.";
			else
				hintMsg = HINTPASS;
		}
		else {
			var mini = 1;
			var maxi = 65535;
			var PortRange = _value.replace(/^\!/g, "");
			var singlerangere = new RegExp("^([0-9]{1,5})\:([0-9]{1,5})$", "gi");
			var multiportre = new RegExp("^([0-9]{1,5})(\,[0-9]{1,5})+$", "gi");
			if(singlerangere.test(PortRange)) {  // single port range
				if(parseInt(RegExp.$1) >= parseInt(RegExp.$2)) {
					hintMsg = _value + " is not a valid port range!";
				}
				else{
					if(!eachPort(RegExp.$1, mini, maxi) || !eachPort(RegExp.$2, mini, maxi)) {
						hintMsg = "Please enter a value between " + mini + " to " + maxi;
					}
					else
						hintMsg =  HINTPASS;
					}
			}
			else if (multiportre.test(PortRange)) {
				var split = PortRange.split(",");
				for (var i = 0; i < split.length; i++) {
					if(!eachPort(split[i], mini, maxi)){
						hintMsg = "Please enter a value between " + mini + " to " + maxi;
					}
					else
						hintMsg =  HINTPASS;
				}
			}
			else {
				if(!tableValid_range(PortRange, mini, maxi)) {
					hintMsg = "Please enter a value between " + mini + " to " + maxi;
				}
				else
					hintMsg =  HINTPASS;
			}
		}
		if(_$obj.next().closest(".hint").length) {
			_$obj.next().closest(".hint").remove();
		}
		if(hintMsg != HINTPASS) {
			var $hintHtml = $('<div>');
			$hintHtml.addClass("hint");
			$hintHtml.html(hintMsg);
			_$obj.after($hintHtml);
			_$obj.focus();
			return false;
		}
		return true;
	}
};

tableValidator.qosMark = {
	keyPress : function($obj, event) {
		var objValue = $obj.val();
		var keyPressed = event.keyCode ? event.keyCode : event.which;
		if (tableValid_isFunctionButton(event)) {
			return true;
		}
		if ((keyPressed > 47 && keyPressed < 58) || (keyPressed > 64 && keyPressed < 71) || (keyPressed > 96 && keyPressed < 103)) {	//0~9 A~F
			return true;
		}
		if (keyPressed == 42) { // *
			if (objValue.length > 1) {
				for(var i=0;i<objValue.length;i++) {
					var c=objValue.charAt(i);
					if (c == '*' && i < 2)
						return false;
				}
				if(objValue.charAt(0)=='!')
					$obj.val(objValue.substr(0,3)+"****");
				else
					$obj.val(objValue.substr(0,2)+"****");
			}
		}
		else if (keyPressed == 33) { // exclamation !
			if(objValue.length > 0 && objValue.length < $obj[0].attributes.maxlength.value && objValue.charAt(0) != '!') { // field already has value; only allow ! as first char
				$obj.val('!' + objValue);
			}
			else if (objValue.length == 0)
				return true;
			return false;
		}
		return false;
	},
	blur : function(_$obj) {
		var hintMsg = "";
		var _value = _$obj.val();
		_value = $.trim(_value);
		_$obj.val(_value);
		if(_value == "") {
			if(_$obj.hasClass("valueMust"))
				hintMsg = "Fields cannot be blank.";
			else
				hintMsg = HINTPASS;
		}
		else {
			var markre = new RegExp("^[!]?([0-9a-fA-F]{2})([0-9a-fA-F]{4}|[\*]{4})$", "gi");
			if(markre.test(_value)) {
				hintMsg = HINTPASS;
			}
			else {
				hintMsg = "Please enter a valid mark or wildcard";
			}
		}
		if(_$obj.next().closest(".hint").length) {
			_$obj.next().closest(".hint").remove();
		}
		if(hintMsg != HINTPASS) {
			var $hintHtml = $('<div>');
			$hintHtml.addClass("hint");
			$hintHtml.html(hintMsg);
			_$obj.after($hintHtml);
			_$obj.focus();
			return false;
		}
		return true;
	}
};

tableValidator.qosIPCIDR = { // only IP or IP plus netmask
	keyPress : function($obj,event) {
		var objValue = $obj.val();
		var keyPressed = event.keyCode ? event.keyCode : event.which;
		if (tableValid_isFunctionButton(event)) {
			return true;
		}
		var i,j;
		if((keyPressed > 47 && keyPressed < 58)){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if(j < 3 && i >= 3){
				if(objValue.charAt(i-3) != '!' && objValue.charAt(i-3) != '.' && objValue.charAt(i-2) != '.' && objValue.charAt(i-1) != '.'){
					$obj.val(objValue + '.');
				}
			}
			return true;
		}
		else if(keyPressed == 46){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if(objValue.charAt(i-1) == '.' || j == 3){
				return false;
			}
			return true;
		}
		else if(keyPressed == 47){
			j = 0;
			for(i = 0; i < objValue.length; i++){
				if(objValue.charAt(i) == '.'){
					j++;
				}
			}
			if( j < 3){
				return false;
			}
			return true;
		}
		else if (keyPressed == 33) { // exclamation !
			if(objValue.length > 0 && objValue.length < $obj[0].attributes.maxlength.value && objValue.charAt(0) != '!') { // field already has value; only allow ! as first char
				$obj.val('!' + objValue);
			}
			else if (objValue.length == 0)
				return true;
			return false;
		}
		return false;
	},
	blur : function(_$obj) {
		var hintMsg = "";
		var _value = _$obj.val();
		_value = $.trim(_value);
		_value = _value.toLowerCase();
		_$obj.val(_value);
		var _firstChar = _value.charAt(0);
		_value = _value.replace(/^\!/g, "");
		if(_value == "") {
			if(_$obj.hasClass("valueMust"))
				hintMsg = "Fields cannot be blank.";
			else
				hintMsg = HINTPASS;
		}
		else {
			var startIPAddr = tableValid_ipAddrToIPDecimal("0.0.0.0");
			var endIPAddr = tableValid_ipAddrToIPDecimal("255.255.255.255");
			var ipNum = 0;
			if(_value.search("/") == -1) {	// only IP
				ipNum = tableValid_ipAddrToIPDecimal(_value);
				if(ipNum > startIPAddr && ipNum < endIPAddr) {
					hintMsg = HINTPASS;
					//convert number to ip address
					if(_firstChar=="!")
						_$obj.val(_firstChar + tableValid_decimalToIPAddr(ipNum));
					else
						_$obj.val(tableValid_decimalToIPAddr(ipNum));
				}
				else {
					hintMsg = _value + " is not a valid IP address!";
				}
			}
			else{ // IP plus netmask
				if(_value.split("/").length > 2) {
					hintMsg = _value + " is not a valid IP address!";
				}
				else {
					var ip_tmp = _value.split("/")[0];
					var mask_tmp = parseInt(_value.split("/")[1]);
					ipNum = tableValid_ipAddrToIPDecimal(ip_tmp);
					if(ipNum > startIPAddr && ipNum < endIPAddr) {
						if(mask_tmp == "" || isNaN(mask_tmp))
							hintMsg = _value + " is not a valid IP address!";
						else if(mask_tmp == 0 || mask_tmp > 32)
							hintMsg = _value + " is not a valid IP address!";
						else {
							hintMsg = HINTPASS;
							//convert number to ip address
							if(_firstChar=="!")
								_$obj.val(_firstChar + tableValid_decimalToIPAddr(ipNum) + "/" + mask_tmp);
							else
								_$obj.val(tableValid_decimalToIPAddr(ipNum) + "/" + mask_tmp);
						}
					}
					else {
						hintMsg = _value + " is not a valid IP address!";
					}
				}
			}
		}
		if(_$obj.next().closest(".hint").length) {
			_$obj.next().closest(".hint").remove();
		}
		if(hintMsg != HINTPASS) {
			var $hintHtml = $('<div>');
			$hintHtml.addClass("hint");
			$hintHtml.html(hintMsg);
			_$obj.after($hintHtml);
			_$obj.focus();
			return false;
		}
		return true;
	}
};

tableRuleDuplicateValidation = {
	iptables_rule : function(_newRuleArray, _currentRuleArray) {
		// Check that no 2 rules with the same values exist, ignoring the Description and Class
		if(_currentRuleArray.length == 0)
			return true;
		else {
			var newRuleArrayTemp = _newRuleArray.slice();
			newRuleArrayTemp.splice(0, 1); // Remove Description
			newRuleArrayTemp.splice(-1, 1); // Remove Class
			for(var i = 0; i < _currentRuleArray.length; i += 1) {
				var currentRuleArrayTemp = _currentRuleArray[i].slice();
				currentRuleArrayTemp.splice(0, 1); // Remove Description
				currentRuleArrayTemp.splice(-1, 1); // Remove Class
				if(newRuleArrayTemp.toString() == currentRuleArrayTemp.toString())
					return false;
			}
		}
		return true;
	}
} // tableRuleDuplicateValidation

tableRuleValidation = {
	iptables_rule : function(_newRuleArray) {
		if(_newRuleArray.length == 8) {
			if(_newRuleArray[1] == "" && _newRuleArray[2] == "" && _newRuleArray[4] == "" && _newRuleArray[5] == "" && _newRuleArray[6] == "") {
				return "Define at least one criterion for this rule!";
			}
			if(_newRuleArray[1] == "" && _newRuleArray[2] == "" && _newRuleArray[4] == "" && _newRuleArray[5] == "" && _newRuleArray[6] != "") {
				return "Create an AppDB rule instead or define additional criteria!";
			}
			return HINTPASS;
		}
	}
} // tableRuleValidation

function show_iptables_rules(){
	var tableStruct = {
		data: iptables_temp_array,
		container: "iptables_rules_block",
		title: "iptables Rules",
		titieHint: "Edit existing rules by clicking in the table below.<small style='float:right; font-weight:normal; color:white; margin-right:10px; cursor:pointer;' onclick='FlexQoS_reset_iptables()'>Reset</small>",
		capability: {
			add: true,
			del: true,
			clickEdit: true
		},
		header: [
			{
				"title" : "Name",
				"width" : "10%"
			},
			{
				"title" : "Local IP",
				"width" : "11%"
			},
			{
				"title" : "Remote IP",
				"width" : "11%"
			},
			{
				"title" : "Proto",
				"width" : "9%"
			},
			{
				"title" : "Local Port",
				"width" : "12%"
			},
			{
				"title" : "Remote Port",
				"width" : "12%"
			},
			{
				"title" : "Mark",
				"width" : "8%"
			},
			{
				"title" : "Class",
				"width" : "21%"
			}
		],
		createPanel: {
			inputs : [
				{
					"editMode" : "text",
					"title" : "Rule Description",
					"maxlength" : "27",
					"placeholder": "Rule Description",
					"validator" : "description"
				},
				{
					"editMode" : "text",
					"title" : "Local IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "192.168.1.100 !192.168.1.100 192.168.1.100/31 !192.168.1.100/31",
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "text",
					"title" : "Remote IP/CIDR",
					"maxlength" : "19",
					"valueMust" : false,
					"placeholder": "9.9.9.9 !9.9.9.9 9.9.9.0/24 !9.9.9.0/24",
					"validator" : "qosIPCIDR"
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
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"title" : "Remote Port",
					"maxlength" : "36",
					"valueMust" : false,
					"placeholder": "443 !443 1234:5678 !1234:5678 53,123,853 !53,123,853",
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"title" : "Mark",
					"maxlength" : "7",
					"valueMust" : false,
					"placeholder": "XXYYYY !XXYYYY XX=Category(hex) YYYY=ID(hex or ****)",
					"validator" : "qosMark"
				},
				{
					"editMode" : "select",
					"title" : "Class",
					"option" : tableClassMenuCode
				}
			],
			maximum: 24
		},
		clickRawEditPanel: {
			inputs : [
				{
					"editMode" : "text",
					"maxlength" : "27",
					"styleList" : {"word-wrap":"break-word","overflow-wrap":"break-word","font-size":"90%"},
					"validator" : "description"
				},
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "text",
					"maxlength" : "19",
					"valueMust" : false,
					"validator" : "qosIPCIDR"
				},
				{
					"editMode" : "select",
					"option" : {"BOTH" : "both", "TCP" : "tcp", "UDP" : "udp"}
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"maxlength" : "36",
					"valueMust" : false,
					"validator" : "qosPortRange"
				},
				{
					"editMode" : "text",
					"maxlength" : "7",
					"valueMust" : false,
					"validator" : "qosMark"
				},
				{
					"editMode" : "select",
					"option" : tableClassMenuCode
				}
			]
		},
		ruleDuplicateValidation : "iptables_rule",
		ruleValidation : "iptables_rule"
	}
	tableApi.genTableAPI(tableStruct);
}

function show_appdb_rules() {
	var appdb_rulelist_row = decodeURIComponent(appdb_rulelist_array).split('<');
	var code = "";

	code +='<table width="100%" border="1" cellspacing="0" cellpadding="4" align="center" class="list_table" id="appdb_rulelist_table">';
	if(appdb_rulelist_row.length == 1)
		code +='<tr><td style="color:#FFCC00;" colspan="4">No rules defined</td></tr>';
	else{
		for(var i = 1; i < appdb_rulelist_row.length; i++){
			code +='<tr id="row'+i+'">';
			var appdb_rulelist_col = appdb_rulelist_row[i].split('>');
			for(var j = 0; j < appdb_rulelist_col.length; j++){
				if (j==1){
					code +='<td width="21%">'+ class_title[appdb_rulelist_col[j]] +'</td>';
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
		FlexQoS_toggle.innerText = "Close";
	}
	else
	{
		FlexQoS_div.style.display = "none";
		FlexQoS_toggle.innerText = "Customize";
	}
}

function convert_BW_settings(settings) {
	var newSettings = "";
	var bandwidth_array = settings.split("<");
	bandwidth_array.shift();
	for (var b=0;b<bandwidth_array.length;b++) {
		bandwidth_array[b] = bandwidth_array[b].split(">");
	}
	for (var b=0;b<bandwidth_array.length;b++) {
		for (var c=0;c<bandwidth_array[b].length;c++) {
			switch (c) {
				case 0:
					newSettings += '<' + bandwidth_array[b][0];
					break;
				case 1:
					newSettings += '>' + bandwidth_array[b][2];
					break;
				case 2:
					newSettings += '>' + bandwidth_array[b][5];
					break;
				case 3:
					newSettings += '>' + bandwidth_array[b][1];
					break;
				case 4:
					newSettings += '>' + bandwidth_array[b][4];
					break;
				case 5:
					newSettings += '>' + bandwidth_array[b][7];
					break;
				case 6:
					newSettings += '>' + bandwidth_array[b][3];
					break;
				case 7:
					newSettings += '>' + bandwidth_array[b][6];
					break;
			}
		}
	}
	return newSettings;
} // convert_BW_Settings

function set_FlexQoS_mod_vars()
{
	if ( custom_settings.flexqos_ver != undefined )
		document.getElementById("flexqos_version").innerText = "v" + custom_settings.flexqos_ver;
	if ( custom_settings.flexqos_branch != undefined )
		document.getElementById("flexqos_version").innerText += " Dev";

	if ( custom_settings.flexqos_iptables == undefined )  // rules not yet converted to API format
		{
			// prepend default rules which can be later edited/deleted by user
			iptables_rulelist_array = iptables_default_rules;
			iptables_rulename_array = decodeURIComponent(iptables_default_rulenames);
		}
	else { // rules are migrated to new API variables
		iptables_rulelist_array = custom_settings.flexqos_iptables;
		if ( custom_settings.flexqos_iptables_names == undefined ) {
			iptables_rulename_array = "";
			var iptables_rulecount = iptables_rulelist_array.split("<").length;
			for (var i=0;i<iptables_rulecount;i++) {
				iptables_rulename_array += "<Rule " + eval(" i + 1 ");
			}
		}
		else
			iptables_rulename_array = decodeURIComponent(custom_settings.flexqos_iptables_names);
	}

	if ( custom_settings.flexqos_appdb == undefined )
		// start with default appdb rules which can be edited/deleted later by user
		appdb_rulelist_array = appdb_default_rules;
	else
		appdb_rulelist_array = custom_settings.flexqos_appdb;

	appdb_temp_array = appdb_rulelist_array.split("<");
	appdb_temp_array.shift();
	for (var a=0; a<appdb_temp_array.length;a++) {
		if (appdb_temp_array[a].length == 8) {
			appdb_temp_array[a]=appdb_temp_array[a].split(">");
			appdb_temp_array[a].unshift(catdb_label_array[catdb_mark_array.indexOf(appdb_temp_array[a][0])]);
			appdb_rules.push(create_rule("", "", "", "", "", appdb_temp_array[a][1], appdb_temp_array[a][2]));
		}
	}

	var r=0;
	iptables_temp_array = iptables_rulelist_array.split("<");
	var iptables_names_temp_array = iptables_rulename_array.split("<");
	iptables_temp_array.shift();
	iptables_names_temp_array.shift();
	for (r=0;r<iptables_temp_array.length;r++){
		if (iptables_temp_array[r] != "") {
			iptables_temp_array[r]=iptables_temp_array[r].split(">");
			if (iptables_names_temp_array[r])
				iptables_temp_array[r].unshift(iptables_names_temp_array[r]);
			iptables_rules.unshift(create_rule(iptables_temp_array[r][1], iptables_temp_array[r][2], iptables_temp_array[r][3], iptables_temp_array[r][4], iptables_temp_array[r][5], iptables_temp_array[r][6], iptables_temp_array[r][7], iptables_temp_array[r][0]));
		}
	}

	// get Bandwidth
	if ( custom_settings.flexqos_bwrates == undefined ) {
		if ( custom_settings.flexqos_bandwidth == undefined )
			bandwidth = bandwidth_default_rules;
		else {
			bandwidth = convert_BW_settings(custom_settings.flexqos_bandwidth);
			if (bandwidth) {
				custom_settings.flexqos_bwrates = bandwidth;
				delete custom_settings.flexqos_bandwidth;
			}
		}
	}
	else
		bandwidth = custom_settings.flexqos_bwrates;

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
			if (bandwidth_array[b][c] >=1 && bandwidth_array[b][c]<=maxpct)
				document.getElementById(temp_elemid + c).value=bandwidth_array[b][c];
		}
	}

	if ( custom_settings.flexqos_conntrack == undefined )		// disabled
		document.form.flexqos_conntrack.value = "1";
	else
		document.form.flexqos_conntrack.value = custom_settings.flexqos_conntrack;

	if ( custom_settings.flexqos_qdisc == undefined )
		document.form.flexqos_qdisc.value = "0";
	else
		document.form.flexqos_qdisc.value = custom_settings.flexqos_qdisc;

	if ( custom_settings.flexqos_outputcls == undefined )
		document.form.flexqos_outputcls.value = "5";
	else
		document.form.flexqos_outputcls.value = custom_settings.flexqos_outputcls;
}

function FlexQoS_reset_iptables() {
	iptables_rulelist_array = iptables_default_rules;
	iptables_rulename_array = decodeURIComponent(iptables_default_rulenames);
	iptables_temp_array = [];
	iptables_temp_array = iptables_rulelist_array.split("<");
	iptables_temp_array.shift();
	iptables_names_temp_array = [];
	iptables_names_temp_array = iptables_rulename_array.split("<");
	iptables_names_temp_array.shift();
	for (r=0;r<iptables_temp_array.length;r++){
		if (iptables_temp_array[r] != "") {
			iptables_temp_array[r]=iptables_temp_array[r].split(">");
			if (iptables_names_temp_array[r])
				iptables_temp_array[r].unshift(iptables_names_temp_array[r]);
		}
	}
	show_iptables_rules();
} // FlexQoS_reset_iptables()

function FlexQoS_reset_appdb() {
	appdb_rulelist_array = appdb_default_rules;
	show_appdb_rules();
} // FlexQoS_reset_appdb

function FlexQoS_reset_filter() {
	for (var i=0;i<6;i++) {
		document.getElementById('filter'+i).value="";
		filter[i]="";
		DelCookie('filter'+i);
	}
	draw_conntrack_table();
} // FlexQoS_reset_filter

function FlexQoS_mod_reset_down()
{
	document.getElementById('drp0').value=5;
	document.getElementById('drp1').value=15;
	document.getElementById('drp2').value=30;
	document.getElementById('drp3').value=20;
	document.getElementById('drp4').value=10;
	document.getElementById('drp5').value=5;
	document.getElementById('drp6').value=10;
	document.getElementById('drp7').value=5;

	document.getElementById('dcp0').value=100;
	document.getElementById('dcp1').value=100;
	document.getElementById('dcp2').value=100;
	document.getElementById('dcp3').value=100;
	document.getElementById('dcp4').value=100;
	document.getElementById('dcp5').value=100;
	document.getElementById('dcp6').value=100;
	document.getElementById('dcp7').value=100;

	check_bandwidth();
}

function FlexQoS_mod_reset_up()
{
	document.getElementById('urp0').value=5;
	document.getElementById('urp1').value=15;
	document.getElementById('urp2').value=10;
	document.getElementById('urp3').value=20;
	document.getElementById('urp4').value=10;
	document.getElementById('urp5').value=5;
	document.getElementById('urp6').value=30;
	document.getElementById('urp7').value=5;

	document.getElementById('ucp0').value=100;
	document.getElementById('ucp1').value=100;
	document.getElementById('ucp2').value=100;
	document.getElementById('ucp3').value=100;
	document.getElementById('ucp4').value=100;
	document.getElementById('ucp5').value=100;
	document.getElementById('ucp6').value=100;
	document.getElementById('ucp7').value=100;

	check_bandwidth();
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

	iptables_rulelist_array = "";
	iptables_rulename_array = "";
	for(var i = 0; i < iptables_temp_array.length; i++) {
		if(iptables_temp_array[i].length != 0) {
			iptables_rulelist_array += "<";
			iptables_rulename_array += "<";
			for(var j = 0; j < iptables_temp_array[i].length; j++) {
				if ( j == 0 )
					iptables_rulename_array += encodeURIComponent(iptables_temp_array[i][j]);
				else {
					iptables_rulelist_array += iptables_temp_array[i][j];
					if( (j + 1) != iptables_temp_array[i].length)
						iptables_rulelist_array += ">";
				}
			}
		}
	}

	appdb_temp_array = appdb_rulelist_array.split("<");
	appdb_temp_array.shift();
	var appdb_last_rules = "";
	appdb_rulelist_array = "";
	for (var a=0; a<appdb_temp_array.length;a++) {
		if (appdb_temp_array[a].substr(2,4) == "****")
			appdb_last_rules += '<' + appdb_temp_array[a];
		else
			appdb_rulelist_array += '<' + appdb_temp_array[a];
	}
	appdb_rulelist_array += appdb_last_rules;


	if (iptables_rulelist_array.length > 2999) {
		alert("Total iptables rules exceeds 2999 bytes! Please delete or consolidate!");
		return
	}
	if (iptables_rulename_array.length > 2999) {
		alert("Total iptables rule names exceed 2999 bytes! Please shorten or consolidate rules!");
		return
	}
	if (appdb_rulelist_array.length > 2999) {
		alert("Total AppDB rules exceeds 2999 bytes! Please delete or consolidate!");
		return
	}
	if (iptables_rulelist_array == iptables_default_rules && iptables_rulename_array == iptables_default_rulenames) {
		delete custom_settings.flexqos_iptables;
		delete custom_settings.flexqos_iptables_names;
	} else {
		custom_settings.flexqos_iptables = iptables_rulelist_array;
		custom_settings.flexqos_iptables_names = iptables_rulename_array;
	}
	if (appdb_rulelist_array == appdb_default_rules)
		delete custom_settings.flexqos_appdb;
	else
		custom_settings.flexqos_appdb = appdb_rulelist_array;
	if (bandwidth == bandwidth_default_rules)
		delete custom_settings.flexqos_bwrates;
	else
		custom_settings.flexqos_bwrates = bandwidth;
	if (custom_settings.flexqos_conntrack) {					// already saved so assume enabled
		if (document.form.flexqos_conntrack.value == 1)		// if enabled in the GUI
			delete custom_settings.flexqos_conntrack;
	}
	else {
		if (document.form.flexqos_conntrack.value == 0)		// if disabled in the GUI
			custom_settings.flexqos_conntrack = document.form.flexqos_conntrack.value;
	}
	if (document.form.flexqos_qdisc.value == 0)
		delete custom_settings.flexqos_qdisc;
	else
		custom_settings.flexqos_qdisc = document.form.flexqos_qdisc.value;

	if (document.form.flexqos_outputcls.value == 5)
		delete custom_settings.flexqos_outputcls;
	else
		custom_settings.flexqos_outputcls = document.form.flexqos_outputcls.value;

	document.getElementById('qos_atm').value = (document.getElementById('qos_atm_x').checked ? 1 : 0);

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
	if (!(input))		return 1;		//is blank
	if (input.length != 6 )		return false;	//console.log("fail length");
	if ( catdb_mark_array.indexOf(input.toUpperCase()) < 0 ) {
		document.form.appdb_desc_x.value="Unknown Mark";
		return false;
	}
	document.form.appdb_desc_x.value=catdb_label_array[catdb_mark_array.indexOf(input.toUpperCase())];
	document.form.appdb_mark_x.value=input.toUpperCase();
	return 1;
}

function get_cat_class(category) {
	var appdb_class=0;
	switch (category) {
		case  9:
		case 18:
		case 19:
		case 20:
			appdb_class=0;
			break;
		case  0:
		case  5:
		case  6:
		case 15:
		case 17:
			appdb_class=3;
			break;
		case  8:
			appdb_class=1;
			break;
		case  7:
		case 10:
		case 11:
		case 21:
		case 23:
			appdb_class=6;
			break;
		case 13:
		case 24:
			appdb_class=4;
			break;
		case  4:
			appdb_class=2;
			break;
		case  1:
		case  3:
		case 14:
			appdb_class=5;
			break;
		default:
			appdb_class=0;
			break;
	}
	return appdb_class;
} // get_cat_class

function validate_mark_desc(input)
{
	if (!(input))		return 1;		//is blank

	var mark=catdb_mark_array[catdb_label_array.indexOf(input)];
	if ( mark != undefined ) {
		var cat=parseInt(mark.substr(0,2),16);
		document.form.appdb_mark_x.value=mark;
		document.form.appdb_mark_x.style.removeProperty("background-color");
		document.form.appdb_class_x.value=get_cat_class(cat);
	}
	else {
		document.form.appdb_mark_x.value="";
		return false;
	}
	return 1;
}

function check_bandwidth() {
	var drptot=0;
	var urptot=0;
	for (var i=0;i<8;i++) {
		var drp=eval("document.form.drp"+i);
		var urp=eval("document.form.urp"+i);
		var dcp=eval("document.form.dcp"+i);
		var ucp=eval("document.form.ucp"+i);
		var dp_desc=eval('document.getElementById("dp'+i+'_desc")');
		var up_desc=eval('document.getElementById("up'+i+'_desc")');
		drptot += parseInt(drp.value);
		urptot += parseInt(urp.value);
		if ( qos_bwmode == 1 ) {
			// Manual
			dp_desc.innerText=(drp.value*qos_dlbw/100/(qos_dlbw>999 ? 1024 : 1)).toLocaleFixed(2) + " ~ " + (dcp.value*qos_dlbw/100/(qos_dlbw>999 ? 1024 : 1)).toLocaleFixed(2) + (qos_dlbw > 999 ? " Mb/s" : " Kb/s");
			up_desc.innerText=(urp.value*qos_ulbw/100/(qos_ulbw>999 ? 1024 : 1)).toLocaleFixed(2) + " ~ " + (ucp.value*qos_ulbw/100/(qos_ulbw>999 ? 1024 : 1)).toLocaleFixed(2) + (qos_ulbw > 999 ? " Mb/s" : " Kb/s");
		} else {
			// Auto
			dp_desc.innerText="Automatic BW mode";
			up_desc.innerText="Automatic BW mode";
		}
	}
	if ( drptot > 100 )
		document.getElementById('qos_drates_warn').style.display = "";
	else
		document.getElementById('qos_drates_warn').style.display = "none";
	if ( urptot > 100 )
		document.getElementById('qos_urates_warn').style.display = "";
	else
		document.getElementById('qos_urates_warn').style.display = "none";
	if ( drptot > 100 || urptot > 100 )
		document.getElementById('qos_rates_warn').style.display = "";
	else
		document.getElementById('qos_rates_warn').style.display = "none";
} // check_bandwidth

function validate_percent(input)
{
	var valid = true;
	if (!(input.value)) valid=false;	//cannot be blank
	if ( /[^0-9]/.test(input.value) ) valid=false;	//console.log("fail character");
	if ( input.value < 1 || input.value > 100) valid=false;	//console.log("fail range");
	if (valid)
		input.style.removeProperty("background-color");
	else
		input.style.backgroundColor="#A86262";
	check_bandwidth();
	return 1
}

function SetCurrentPage() {
	var model = '<% nvram_get("odmpid"); %>';
	if ( model == "" ) model = '<% nvram_get("productid"); %>';
	document.title = "ASUS Wireless Router " + model + " - FlexQoS";
	document.form.next_page.value = window.location.pathname.substring(1);
	document.form.current_page.value = window.location.pathname.substring(1);
}

function update_status(){
	$.ajax({
		url: '/ext/flexqos/detect_update.js',
		dataType: 'script',
		timeout: 3000,
		error:	function(xhr){
			setTimeout('update_status();', 1000);
		},
		success: function(){
			if ( verUpdateStatus == "InProgress" )
				setTimeout('update_status();', 1000);
			else {
				document.getElementById("ver_check").disabled = false;
				document.getElementById("ver_update_scan").style.display = "none";
				if ( verUpdateStatus == "NoUpdate" ) {
					document.getElementById("versionStatus").innerText = " You have the latest version.";
					document.getElementById("versionStatus").style.display = "";
					}
				else if ( verUpdateStatus == "Error" ) {
					document.getElementById("versionStatus").innerText = " Error getting remote version.";
					document.getElementById("versionStatus").style.display = "";
					}
				else {
					/* version update or hotfix available */
					/* toggle update button */
					document.getElementById("versionStatus").innerText = " " + verUpdateStatus + " available!";
					document.getElementById("versionStatus").style.display = "";
					document.getElementById("ver_check").style.display = "none";
					document.getElementById("ver_update").style.display = "";
				}
			}
		}
	});
}

function version_check() {
	document.getElementById("ver_check").disabled = true;
	document.ver_check.action_script.value="start_flexqosupdatecheck"
	document.ver_check.submit();
	document.getElementById("ver_update_scan").style.display = "";
	setTimeout("update_status();", 2000);
}

function version_update() {
	document.form.action_script.value="start_flexqosupdatesilent"
	document.form.submit();
}

function setClientIP(ipaddr){
	document.form.lipfilter_x.value = ipaddr + "$";
	hideClients_Block();
	set_filter(1, document.form.lipfilter_x);
}

function hideClients_Block(){
	document.getElementById("lip_pull_arrow").src = "/images/arrow-down.gif";
	document.getElementById('ClientList_Block_PC').style.display='none';
}

function pullLANIPList(obj) {
	var element = document.getElementById('ClientList_Block_PC');
	var isMenuopen = element.offsetWidth > 0 || element.offsetHeight > 0;
	if(isMenuopen == 0) {
		obj.src = "/images/arrow-top.gif"
		element.style.display = 'block';
		document.form.lipfilter_x.focus();
	}
	else
		hideClients_Block();
}

function well_known_rules(){
	var code = "";
	var wellKnownRule = new Array();
//		[ "Rule Name", "Local IP", "Remote IP", "Proto", "Local Port", "Remote Port", "Mark", "Class"],
	wItem = [
		[ "Facetime", "", "", "udp", "16384:16415", "", "", "3"],
		[ "Game Downloads", "", "", "tcp", "", "80,443", "08****", "5"],
		[ "Gaming Rule", "login_ip_str", "", "both", "", "!80,443", "000000", "1"],
		[ "Google Meet", "", "", "udp", "", "19302:19309", "", "3"],
		[ "Skype/Teams", "", "", "udp", "", "3478:3481", "000000", "3"],
		[ "Usenet", "", "", "tcp", "", "119,563", "", "5"],
		[ "WiFi Calling", "", "", "udp", "", "500,4500", "", "3"],
		[ "Zoom", "", "", "udp", "", "8801:8810", "000000", "3"]
	];

	code += '<option value="User Defined">Please select</option>';
	code += '<optgroup label="Pre-defined rules">';
	for (var i = 0; i < wItem.length; i++){
		code += '<option value="' + i + '">' + wItem[i][0] + '</option>';
	}
	var tmpCount=wItem.length;
	for (i=0;i<iptables_temp_array.length; i++) {
		if (i==0)
			code += '<optgroup label="User-defined rules">';
		code += '<option value="' + ( tmpCount + i ) + '">' + iptables_temp_array[i][0] + '</option>';
		wItem.push(iptables_temp_array[i]);
	}
	document.form.WellKnownRules.innerHTML = code;
} // well_known_rules

function change_wizard(o){
	var i = o.value;
	var wellKnownRule = new Array();
	wellKnownRule.push(wItem[i][0]);
	if (wItem[i][1] == "login_ip_str")
		wellKnownRule.push(login_ip_str());
	else
		wellKnownRule.push(wItem[i][1]);
	wellKnownRule.push(wItem[i][2]);
	wellKnownRule.push(wItem[i][3]);
	wellKnownRule.push(wItem[i][4]);
	wellKnownRule.push(wItem[i][5]);
	wellKnownRule.push(wItem[i][6]);
	wellKnownRule.push(wItem[i][7]);

	var validDuplicateFlag = true;
	if(tableApi._attr.hasOwnProperty("ruleDuplicateValidation")) {
		var currentEditRuleArray = wellKnownRule;
		var filterCurrentEditRuleArray = iptables_temp_array;
		validDuplicateFlag = tableRuleDuplicateValidation[tableApi._attr.ruleDuplicateValidation](currentEditRuleArray, filterCurrentEditRuleArray);
		if(!validDuplicateFlag) {
			document.form.WellKnownRules.selectedIndex = 0;
			alert("This rule already exists.");
			return false;
		}
		iptables_temp_array.push(currentEditRuleArray);
		show_iptables_rules();
		}
	document.form.WellKnownRules.selectedIndex = 0;
} // change_wizard

function autocomplete(inp, arr) {
	/*the autocomplete function takes two arguments,
	the text field element and an array of possible autocompleted values:*/
	var currentFocus;
	/*execute a function when someone writes in the text field:*/
	inp.addEventListener("input", function(e) {
		var a, b, i, val = this.value;
		/*close any already open lists of autocompleted values*/
		closeAllLists();
		if (!val) { return false;}
		if (val.length<3) { return false;}
		currentFocus = -1;
		/*create a DIV element that will contain the items (values):*/
		a = document.createElement("DIV");
		a.setAttribute("id", this.id + "autocomplete-list");
		a.setAttribute("class", "autocomplete-items");
		/*append the DIV element as a child of the autocomplete container:*/
		this.parentNode.appendChild(a);
		/*for each item in the array...*/
		for (i = 0; i < arr.length; i++) {
			/*check if the item starts with the same letters as the text field value:*/
			if (arr[i].toUpperCase().indexOf(val.toUpperCase()) > -1) {
				/*create a DIV element for each matching element:*/
				b = document.createElement("DIV");
				b.innerHTML = arr[i];
				/*insert a input field that will hold the current array item's value:*/
				b.innerHTML += "<input type='hidden' value='" + arr[i] + "'>";
				/*execute a function when someone clicks on the item value (DIV element):*/
				b.addEventListener("click", function(e) {
					/*insert the value for the autocomplete text field:*/
					inp.value = this.getElementsByTagName("input")[0].value;
					validate_mark_desc(inp.value);
					/*close the list of autocompleted values,
					(or any other open lists of autocompleted values:*/
					closeAllLists();
				});
				a.appendChild(b);
			}
		}
	});
	/*execute a function presses a key on the keyboard:*/
	inp.addEventListener("keydown", function(e) {
		var x = document.getElementById(this.id + "autocomplete-list");
		if (x) x = x.getElementsByTagName("div");
		if (e.keyCode == 40) {
			/*If the arrow DOWN key is pressed,
			increase the currentFocus variable:*/
			currentFocus++;
			/*and and make the current item more visible:*/
			addActive(x);
		} else if (e.keyCode == 38) { //up
			/*If the arrow UP key is pressed,
			decrease the currentFocus variable:*/
			currentFocus--;
			/*and and make the current item more visible:*/
			addActive(x);
		} else if (e.keyCode == 13) {
			/*If the ENTER key is pressed, prevent the form from being submitted,*/
			e.preventDefault();
			if (currentFocus > -1) {
				/*and simulate a click on the "active" item:*/
				if (x) x[currentFocus].click();
			}
		}
	});
	function addActive(x) {
		/*a function to classify an item as "active":*/
		if (!x) return false;
		/*start by removing the "active" class on all items:*/
		removeActive(x);
		if (currentFocus >= x.length) currentFocus = 0;
		if (currentFocus < 0) currentFocus = (x.length - 1);
		/*add class "autocomplete-active":*/
		x[currentFocus].classList.add("autocomplete-active");
	}
	function removeActive(x) {
		/*a function to remove the "active" class from all autocomplete items:*/
		for (var i = 0; i < x.length; i++) {
			x[i].classList.remove("autocomplete-active");
		}
	}
	function closeAllLists(elmnt) {
		/*close all autocomplete lists in the document,
		except the one passed as an argument:*/
		var x = document.getElementsByClassName("autocomplete-items");
		for (var i = 0; i < x.length; i++) {
			if (elmnt != x[i] && elmnt != inp) {
				x[i].parentNode.removeChild(x[i]);
			}
		}
	}
	/*execute a function when someone clicks in the document:*/
	document.addEventListener("click", function (e) {
		closeAllLists(e.target);
	});
}

function GetCookie(cookiename,returntype){
	var s;
	if((s = cookie.get("flexqos_"+cookiename)) != null){
		return cookie.get("flexqos_"+cookiename);
	}
	else{
		if(returntype == "string"){
			return "";
		}
		else if(returntype == "number"){
			return 0;
		}
	}
}

function SetCookie(cookiename,cookievalue){
	cookie.set("flexqos_"+cookiename, cookievalue, 31);
}

function DelCookie(cookiename){
	cookie.set("flexqos_"+cookiename, "", -1);
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
<input type="hidden" name="action_wait" value="30">
<input type="hidden" name="flag" value="">
<input type="hidden" name="amng_custom" id="amng_custom" value="">
<input type="hidden" name="qos_atm" id="qos_atm">
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
<div class="formfonttitle" style="margin:10px 0px 10px 5px; display:inline-block;">FlexQoS</div>
<div id="FlexQoS_mod_toggle" style="margin:10px 0px 0px 0px; padding:0 0 0 0; height:22px; width:136px; float:right; font-weight:bold;" class="titlebtn" onclick="FlexQoS_mod_toggle();"><span style="padding:0 0 0" align="center">Customize</span></div>
<div style="margin-bottom:10px" class="splitLine"></div>

<!-- FlexQoS UI Start-->
<div id="FlexQoS_mod" style="display:none;">
<div style="display:inline-block; margin:0px 0px 10px 5px; font-size:14px; text-shadow: 1px 1px 0px black;"><b>QoS Customization</b></div>
<div style="margin:0px 0px 0px 0px; padding:0 0 0 0; height:22px; width:136px; float:right; font-weight:bold;" class="titlebtn" onclick="FlexQoS_mod_apply();"><span style="padding:0 0 0 0" align="center">Apply</span></div>
<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable">
	<thead>
		<tr>
			<td colspan="2">Options</td>
		</tr>
	</thead>
	<tr>
		<th>Version</th>
		<td>
			<span id="flexqos_version" style="color:#FFFFFF;"></span>
			&nbsp;&nbsp;&nbsp;
			<input type="button" id="ver_check" class="button_gen" style="width:135px;height:24px;" onclick="version_check();" value="Check for Update">
			<input type="button" id="ver_update" class="button_gen" style="display:none;width:135px;height:24px;" onclick="version_update();" value="Update">
			&nbsp;&nbsp;&nbsp;
			<img id="ver_update_scan" style="display:none;vertical-align:middle;" src="images/InternetScan.gif">
			<span id="versionStatus" style="color:#FC0;display:none;"></span>
		</td>
	</tr>
	<tr>
		<th>Queue Discipline</th>
		<td>
			<input type="radio" name="flexqos_qdisc" class="input" value="0">Default
			<input type="radio" name="flexqos_qdisc" class="input" value="1">fq_codel
		</td>
	</tr>
	<tr>
		<th><a class="hintstyle" href="javascript:void(0);" onClick="openHint(50, 28);">WAN packet overhead</a></th>
		<td>
			<input type="text" maxlength="4" class="input_6_table" name="qos_overhead" id="qos_overhead" onKeyPress="return validator.isNumber(this,event);" onblur="validator.numberRange(this, -127, 128);" value="<% nvram_get("qos_overhead"); %>" style="float:left;">
			<img id="ovh_pull_arrow" class="pull_arrow" height="14px;" src="/images/arrow-down.gif" onclick="pullOverheadList(this);">
			<div id="overhead_presets_list" style="margin-left:2px;margin-top:25px;height:auto;" class="clientlist_dropdown"></div>
			<input style="margin-left:40px;" type="checkbox" name="qos_atm_x" id="qos_atm_x" <% nvram_match("qos_atm", "1", "checked"); %>>
			<label for="qos_atm_x">ATM</label>
		</td>
	</tr>
	<tr>
		<th>Enable Conntrack Flushing</th>
		<td>
			<input type="radio" name="flexqos_conntrack" class="input" value="1">Yes
			<input type="radio" name="flexqos_conntrack" class="input" value="0">No
		</td>
	</tr>
	<tr>
		<th>Router/VPN Client Outbound Traffic Class</th>
		<td>
			<select name="flexqos_outputcls" id="flexqos_outputcls" class="input_option">
			</select>
		</td>
	</tr>
	<tr>
		<th>Add Well-Known iptables Rule</th>
		<td>
			<select name="WellKnownRules" class="input_option" onChange="change_wizard(this);">
				<option value="User Defined">Please select</option>
			</select>
		</td>
	</tr>
</table>
<div id="iptables_rules_block"></div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable_table">
	<thead>
		<tr>
			<td colspan="4">AppDB Redirection Rules&nbsp;(Max Limit : 32)<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick="FlexQoS_reset_appdb()">Reset</small></td>
		</tr>
	</thead>
	<tbody>
	<tr>
		<th width="auto"><div class="table_text">Application</div></th>
		<th width="10%"><div class="table_text">Mark</div></th>
		<th width="21%"><div class="table_text">Class</div></th>
		<th width="15%">Edit</th>
	</tr>
	<tr>
		<td width="auto">
			<div class="autocomplete">
				<input id="appdb_search_x" type="text" maxlength="52" class="input_32_table" name="appdb_desc_x" autocomplete="off" autocorrect="off" autocapitalize="off" placeholder="Type to search application names...">
			</div>
		</td>
		<td width="10%">
			<input type="text" maxlength="6" class="input_6_table" name="appdb_mark_x" onfocusout='validate_mark(this.value) ? this.style.removeProperty("background-color") : this.style.backgroundColor="#A86262"' autocomplete="off" autocorrect="off" autocapitalize="off">
		</td>
		<td width="21%">
			<select name="appdb_class_x" id="appdb_class_x" class="input_option">
			</select>
		</td>
		<td width="15%">
			<div><input type="button" class="add_btn" onClick="addRow_AppDB_Group(32);" value=""></div>
		</td>
	</tr>
</tbody>
</table>
<div id="appdb_rules_block"></div>

<table width="100%" border="1" align="center" cellpadding="4" cellspacing="0" class="FormTable_table">
	<thead>
	<tr>
		<td colspan="7">Bandwidth<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick="FlexQoS_mod_reset_down();FlexQoS_mod_reset_up();">Reset</small></td>
	</tr>
	</thead>
	<tr>
		<th rowspan="2">Class</th>
		<th colspan="3">Download<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick="FlexQoS_mod_reset_down()">Reset</small></th>
		<th colspan="3">Upload<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick="FlexQoS_mod_reset_up()">Reset</small></th>
	<tr>
		<th>Minimum</th>
		<th>Maximum</th>
		<th>Current Settings</th>
		<th>Minimum</th>
		<th>Maximum</th>
		<th>Current Settings</th>
	</tr>
	<tbody id="bandwidth_block">
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
<tr>
<th>Graph Scale:</th>
<td>
	<input type="radio" name="rate_graph_scale" class="input" value="0" onChange="change_chart_scale(this.value)">Linear
	<input type="radio" name="rate_graph_scale" class="input" value="1" onChange="change_chart_scale(this.value)">Logarithmic
</td>
</tr>
</table>
<br>
<div id="no_aqos_notice" style="display:none;font-size:125%;color:#FFCC00;">Note: Adaptive QoS is not enabled.</div>
<table>
<tr id="dl_tr">
<td style="padding-right:10px;font-size:125%;color:#FFCC00;">
<canvas id="line_chart_dl" width="390" height="235"></canvas>
</td>
<td><span id="legend_dl"></span></td>
</tr>
<tr style="height:25px;">
<td colspan="2">&nbsp;</td>
</tr>
<tr id="ul_tr">
<td style="padding-right:10px;font-size:125%;color:#FFCC00;">
<canvas id="line_chart_ul" width="390" height="235"></canvas>
</td>
<td><span id="legend_ul"></span></td>
</tr>
</table>
<br>
<!-- FlexQoS Connection Table Start-->

<table cellpadding="4" class="FormTable_table" id="tracked_filters" style="display:none;">
<thead>
	<tr>
		<td colspan="6">Filter connections
			<input style="margin-left:25px; vertical-align:middle;" type="checkbox" name="savefilter" id="savefilter" onChange="save_filter();">
			<label for="savefilter"><small style="font-weight:normal;">Save Filter</small></label>
			<small style="float:right; font-weight:normal; margin-right:10px; cursor:pointer;" onclick="FlexQoS_reset_filter()">Reset</small>
		</td>
	</tr>
</thead>
	<tr>
		<th width="5%">Proto</th>
		<th width="28%">Local IP</th>
		<th width="6%">Port</th>
		<th width="28%">Remote IP</th>
		<th width="6%">Port</th>
		<th width="27%">Application</th>
	</tr>
	<tr>
		<td><select id="filter0" class="input_option" onchange="set_filter(0, this);">
			<option value="">any</option>
			<option value="tcp">tcp</option>
			<option value="udp">udp</option>
		</select></td>
		<td style="text-align:left;">
			<input id="filter1" type="text" class="input_18_table" style="width:140px;" maxlength="40" name="lipfilter_x" oninput="set_filter(1, this);" onClick="hideClients_Block();">
			<img id="lip_pull_arrow" height="14px;" src="/images/arrow-down.gif" class="pull_arrow" style="position:absolute;" onclick="pullLANIPList(this);" title="Select the Local Client">
			<div id="ClientList_Block_PC" class="clientlist_dropdown" style="margin-left:2px;width:200px;"></div>
		</td>
		<td><input id="filter2" type="text" class="input_6_table" maxlength="6" oninput="set_filter(2, this);"></td>
		<td><input id="filter3" type="text" class="input_18_table" maxlength="40" oninput="set_filter(3, this);"></td>
		<td><input id="filter4" type="text" class="input_6_table" maxlength="6" oninput="set_filter(4, this);"></td>
		<td style="text-align:left;">
			<input id="filter5" type="text" class="input_18_table" style="width:140px;" maxlength="49" name="appfilter_x" oninput="set_filter(5, this);" onClick="hideClasses_Block();">
			<img id="class_pull_arrow" height="14px;" src="/images/arrow-down.gif" class="pull_arrow" style="position:absolute;" onclick="pullClassList(this);" title="Select the QoS Class">
			<div id="QoS_Class_List" class="clientlist_dropdown" style="margin-left:2px;width:165px;"></div>
		</td>
	</tr>
</table>
<table cellpadding="4" class="FormTable_table" id="tracked_connections">
<thead>
	<tr><td id="tracked_connections_total" colspan="6">Tracked connections</td></tr>
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
<form method="post" name="ver_check" action="/start_apply.htm" target="hidden_frame">
	<input type="hidden" name="productid" value="<% nvram_get("productid"); %>">
	<input type="hidden" name="current_page" value="">
	<input type="hidden" name="next_page" value="">
	<input type="hidden" name="action_mode" value="apply">
	<input type="hidden" name="action_script" value="">
	<input type="hidden" name="action_wait" value="">
</form>
<div id="footer"></div>
</body>
