# FlexQoS - Flexible QoS Enhancement Script for Adaptive QoS on ASUSWRT-Merlin

This script has been tested on ASUS RT-AC68U, running ASUSWRT-Merlin 384.18, using Adaptive QoS with Manual Bandwidth Settings

## Quick Overview:

-- Script allows reclassifying Untracked traffic (mark 000000) from current default class to any class

-- Script Changes Minimum Guaranteed Bandwidth per QoS category to user defined percentages for upload and download.

-- Script allows for multiple custom QoS rules using iptables rules

-- Script allows for redirection of existing identified traffic using AppDB rules

## Full Overview:

See <a href="https://www.snbforums.com/threads/64882/" rel="nofollow">SmallNetBuilder Forums</a> for more information & discussion

## Adaptive QoS Setup

Enable Adaptive QoS in the router's GUI.
Set QoS Type to Adaptive QoS
Set Bandwidth Setting to Manual Setting
Set Queue Discipline to fq_codel
Set WAN packet overhead to match your WAN connection type
Set your Upload Bandwidth in Mb/s to 85-95% of your worst speedtest results without QoS enabled
Set your Download Bandwidth in Mb/s to 85-95% of your worst speedtest results without QoS enabled
Set your QoS priority mode to one of the predefined modes or choose Customize and set your own. Recommend that Learn-From-Home be lower priority than Streaming for proper script functionality.
Hit Apply.

## Installation:

FlexQoS requires ASUSWRT-Merlin version 384.18 or higher.

In your SSH Client:

``` /usr/sbin/curl "https://raw.githubusercontent.com/dave14305/FlexQoS/master/flexqos.sh" -o /jffs/addons/flexqos/flexqos.sh --create-dirs && chmod +x /jffs/addons/flexqos/flexqos.sh && sh /jffs/addons/flexqos/flexqos.sh -install ```

## Basic Usage

The FlexQoS tab is located next to the original Classification tab in the Adaptive QoS section of the router GUI.

The page features Download and Upload pie charts with accompanying legends and per-class rate details. Classes are ordered according to the user-selected priority order. Statistics reset whenever QoS is restarted.
Total: the total number of bytes transferred within each QoS class in Bytes
Rate: a 10-second average of the current number of bits per second flowing through each QoS class displayed in kilobits per second.
Packet rate: a 10-second average of the current number of packets per second (pps) flowing through each QoS class.

The Tracked connections table provides a detailed list of tracked connections and how they were categorized by the Adaptive QoS engine and FlexQoS custom rules.
Local devices that have an associated hostname or custom client name from the router's Client List will be shown in the Local Device column and filter dropdown. To see the actual IP address, hover over the device name.
Applications identified for a specific connection are colored according to the resulting Class and priority assigned by Adaptive QoS and FlexQoS custom rules. Connections are sorted by Class in descending priority, then by application name in ascending order. To see the name of the Class, hover your mouse over the Application name. To identify the equivalent AppDB Mark for an application, click on the application name to toggle the display of the hexadecimal Mark.
The Tracked connections list will display up to 750 connections while still allowing auto-refresh. If more than 750 connections are tracked, auto-refresh is disabled for performance reasons. You may re-enable auto-refresh at your own risk.
If more than 500 connections are displayed, the Tracked connections list is limited to 500 connections for performance reasons, and the use of a filter is recommended.
The Filter connections bar allows real-time filtering of the Tracked connections list using any combination of the available fields:
Protocol: any, tcp, udp
Local IP: a dynamically generated list of client names and IPs with some support for IPv6 clients
Local Port: the source port used for outgoing connections (partial matches allowed)
Remote IP: IP address of the remote host (partial matches allowed)
Remote Port: the destination port for outgoing connections (partial matches allowed)
Application: filter on the Application name text displayed (partial matches allowed). Marks and Class names do not work in this field.
When filtered, the Tracked connections list will show the total number of tracked connections as well as the total number of connections shown as a result of the filter, or reaching the 500 connection limit.
To reset the filters to default at any time, click the Reset link on the far right side of the header.

The pie charts and Tracked connections will auto-refresh every 3 seconds by default. You may change the refresh rate via the menu at the top of the page. Options are: No refresh, 3 seconds, 5 seconds, 10 seconds.

## Customizing Rules

To customize your QoS experience to suit your browsing habits, click the Customize button in the upper right corner of the page to reveal the Customization options of FlexQoS.

To modify the default behavior of ASUS Adaptive QoS, we use iptables rules to modify our network packets in real-time to direct them to our preferred Class and QoS priority, and AppDB rules to change the Class assigned to traffic already identified by the Adaptive QoS engine.
In this way, we have tremendous flexibility to fine-tune the QoS prioritization of our network traffic.

## iptables Rules
To change the Class that a specific connection is assigned by Adaptive QoS, you will create an iptables rule that will uniquely identify that connection by a combination of Local IP, Local Port, Protocol, Remote IP, Remote Port and pre-assigned AppDB Mark.
Through trial and error you will study the Tracked connections table for the specific connections you want to change, looking for combinations that will uniquely isolate your connections. This is where the Filtered connections can be useful to test.
To add a rule, click the plus icon next to the iptables Rules ( Max Limit : 24 ) heading.
In the Create New Policy pop-up window, you will enter the data you gathered in your testing. Example placeholder text is displayed in each field as a guide.
Local IP/CIDR: Enter a single IP or a CIDR block for a range of IP addresses. This should be from your LAN subnet. You may also negate the IP by preceding it with an exclamation point (!). As you type the IP address, it will auto-add the decimals. At any point while typing, you can type ! to negate the IP address. If the IP or CIDR entered is not valid, you will see an error below the field.
Remote IP/CIDR: Enter a single IP or a CIDR block for a range of IP addresses. You may also negate the IP by preceding it with an exclamation point (!). As you type the IP address, it will auto-add the decimals. At any point while typing, you can type ! to negate the IP address. If the IP or CIDR entered is not valid, you will see an error below the field.
Protocol: TCP, UDP or BOTH (only relevant when Local or Remote ports are specified).
Local Port: Enter a single port, a port range separated by a colon (:), or multiple ports separated by commas (,). Ports may also be negated with an exclamation point (!). You may not combine ranges with single or multiple ports. Valid ports are between 1-65535.
Remote Port: Enter a single port, a port range separated by a colon (:), or multiple ports separated by commas (,). Ports may also be negated with an exclamation point (!). You may not combine ranges with single or multiple ports. Valid ports are between 1-65535.
Mark: Enter the hexadecimal value assigned to an Application name, identified by clicking the Application name in the Tracked connections list, or by using the flexqos appdb search function. You may enter a mark for a specific application, or a wildcard Mark for all applications within a category by using '****' as the last 4 characters.
Class: Enter the Class you would like this traffic to be assigned. The resulting QoS priority of this Class is dependent upon your QoS priority customizations done in the standard QoS screens.
Click OK to add your rule. Rules are not saved and do not take effect until after you click the Apply button in the main FlexQoS page.
All iptables rules need at least an IP or port specification. A rule with only a Mark specified is better suited as an AppDB rule and will be rejected in the iptables Rules section.

To delete a rule, click the Delete icon to the right of the rule.

To edit an existing rule, click on any field within the row to toggle in-cell editing. Make the necessary changes and then click outside the area of the table to save your changes. The same shortcuts and validations apply to in-cell editing as when adding a rule via the add button.

To reset the iptables rules to the default rules provided by FlexQoS, click the Reset link in the iptables Rules heading. Changes do not take effect until you click Apply.

There is currently a limit of 24 iptables rules to ensure we do not overflow the space available in the Merlin custom settings API.

Every connection is evaluated against all iptables rules in your rule list, and the last rule to match your connection is the rule that will determine the final priority of that connection. If multiple iptables rules can match your connection, be sure that your most important rule is at the bottom of the list.

Add your rules carefully because you cannot change the order of existing rules once created. You will need to delete and re-add to the bottom of the list to get the desired sequence of rules. Duplicate rules are not allowed.

FlexQoS installs with the following default iptables rules:
- WiFi Calling: Remote UDP ports 500 and 4500 to Work-From-Home
- FaceTime: Local UDP port range 16384-16415 to Work-From-Home
- UseNet/NNTP: Remote TCP ports 119 and 563 to File Downloads
- Game Downloads: Identified Gaming applications with Remote TCP ports 80 and 443 to Game Downloads

All default rules are editable or removable to suit your needs.

During installation, if the older FreshJR_QOS script is installed, those rules are migrated to the new FlexQoS format. FreshJR_QOS also included a Gaming Rule and if it was populated in FreshJR_QOS, it will be converted into an equivalent iptables rule in FlexQoS.
The Gaming rule is useful for LAN devices whose primary purpose is gaming and you want their Untracked traffic that isn't HTTP/HTTPS traffic to be prioritized as Gaming.
If you wish to create the Gaming rule from scratch, add a rule with these parameters:
Local IP/CIDR: 192.168.1.100/30 (unique to your gaming devices)
Remote IP/CIDR: blank
Proto: BOTH
Local Port: blank
Remote Port: !80,443 (note the exclamation point to invert, i.e. NOT port 80 and NOT port 443)
Mark: 000000
Class: Gaming

## AppDB Redirection Rules

If your application traffic is properly identified by the Adaptive QoS engine, but you want it to be prioritized in a different class from its default class, you will use an AppDB Redirection rule to achieve this.

To create an AppDB Redirection rule, you have two options:
1. Click in the search box for Application and begin typing the name of the application as seen in the Tracked connections list. Click on the correct match in the popup list. The hexadecimal Mark will auto-populate.
2. Enter the Mark from the Tracked connections list (click on the Application label to reveal the underlying Mark value). When you click or tab out of the entry box, the matching Application name will auto-populate to confirm your choice.
3. Assign a new Class to the application. The resulting QoS priority of this Class is dependent upon your QoS priority customizations done in the standard QoS screens.
4. Click the Add icon to add the rule. Rules are not saved and do not take effect until after you click the Apply button in the main FlexQoS page.

If you want enter a wildcard Mark (e.g. 09**** Management tools and protocols), all traffic identified under that category of applications will be redirected to the chosen Class. Non-wildcard Marks will override wildcard Marks. For example, by default, wildcard Mark 14**** is directed to Web Surfing. But Mark 1400C5 (DNS over TLS) can also be added to go to Net Control. The more specific 1400C5 rule will be applied before the generic 14**** rule.

To delete a rule, click the Delete icon in the Edit column of the rule.

To edit a rule, click the Edit icon in the Edit column of the rule. The rule contents are moved back to the editing row at the top of the list. When you add the rule after making changes, it is added to the bottom of the list.

Only one rule per Mark is allowed in the AppDB Redirection Rules. Wildcard Marks are still allowed.

When you click Apply in the FlexQoS page to apply your changes, rules with Wildcard Marks will be sorted to the bottom of the rules list to ensure correct interpretation of rule precedence when displaying the Tracked connections list.

FlexQoS installs with the following default AppDB Redirection rules:
- Untracked (000000): Others
- Snapchat (00006B): Others
- Speedtest.net (0D0007): File Downloads
- Google Play (0D0086): File Downloads
- Apple Store (0D00A0): File Downloads
- World Wide Web HTTP (12003F): Web Surfing
- Network protocols (13**** and 14****): Web Surfing
- Advertisement (1A****): File Downloads

All default rules are editable or removable to suit your needs. It is recommended to keep a rule for Untracked (000000) traffic at a minimum.

To reset your AppDB Redirection rules to the default rules provided by FlexQoS, click the Reset link in the AppDB Redirection Rules heading. Changes do not take effect until you click Apply.

There is currently a limit of 32 AppDB Redirection rules. In theory, we can allow up to 333 rules and be within the limits of the Merlin Addon API. 32 rules should be adequate for most users.

## Bandwidth Allocations

ASUS Adaptive QoS allocates only 50% of your upload and download bandwidth as guaranteed minimums for each priority level.
Priority 0:  5%
Priority 1: 20%
Priority 2: 10%
Priority 3:  5%
Priority 4:  4%
Priority 5:  3%
Priority 6:  2%
Priority 7:  1%

FlexQoS enables you to pre-allocate up to 100% of your bandwidth to specific named Classes, regardless of what priority level you assign to them in the router GUI.

Download and Upload bandwidth can be allocated independently, allowing for minimum and maximum allocations (rate and ceiling, respectively, in QoS terminology).

Minimum Reserved Bandwidth: This is known as "rate" in QoS terminology. This is the guaranteed bandwidth allocated to this Class before lower priority Classes will be served. Valid range is 5-99%. The total of all Minimums should not exceed 100%.
Maximum Reserved Bandwidth: This is known as "ceiling" in QoS terminology. This is the maximum bandwidth this Class may be allocated assuming bandwidth is available from higher priority Classes. Valid range is 5-100%.

If you enter an invalid value, the field will turn red and you must correct the value before hitting Apply. If your Minimum bandwidth allocations exceed 100%, you will see a yellow warning message below the table. You can still hit Apply and save the values, but it is not recommended to exceed 100%.

You might choose to limit the Maximum bandwidth for a Class such as File Downloads to ensure it does not ever consume all available bandwidth. In general, it is a best practice to leave the Maximum values at 100% to allow all bandwidth to be used if available.

To reset your Download or Upload bandwidth allocations to the FlexQoS default values, click the Reset link in the header. Click Apply to save your changes.

## Saving

To save all your changes and restart QoS to apply them, always use the Apply button in the upper right corner of the FlexQoS page. If you make a change and do not want to save it, you can reload the page with the F5 key or your browser's reload button to revert to the previously saved settings. No changes made in the FlexQoS WebUI are saved until you click Apply, including any of the Reset to defaults links.

## Command Line


## Uninstall:

In your SSH Client:

``` /jffs/addons/flexqos/flexqos.sh -uninstall ```


## Screenshots

### Traffic Pie Chart
[![Traffic Pie Chart](https://i.imgur.com/htAkaDq.png "Traffic Pie Chart")](https://i.imgur.com/htAkaDq.png "Traffic Pie Chart")

### Customization Tables
[![Customization Tables](https://i.imgur.com/cvus7VE.png "Customization Tables")](https://i.imgur.com/cvus7VE.png "Customization Tables")

### Create New Rule
[![Create New Rule](https://i.imgur.com/dbpABjg.png "Create New Rule")](https://i.imgur.com/dbpABjg.png "Create New Rule")
