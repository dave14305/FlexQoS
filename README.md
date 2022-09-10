# FlexQoS - Flexible QoS Enhancement Script for Adaptive QoS on ASUSWRT-Merlin

![Shellcheck](https://github.com/dave14305/FlexQoS/actions/workflows/shellcheck.yml/badge.svg)

This script has been tested on ASUS RT-AC86U, running ASUSWRT-Merlin 386.7_2, using Adaptive QoS with Manual Bandwidth Settings

## Quick Overview:

- Script allows reclassifying Untracked traffic (mark 000000) from current default class to any class
- Script changes Minimum Guaranteed Bandwidth per QoS category to user defined percentages for upload and download.
- Script allows for multiple custom QoS rules using iptables
- Script allows for redirection of existing identified traffic using AppDB rules

## Adaptive QoS Setup

1. Enable QoS in the router's GUI.
2. Set QoS Type to Adaptive QoS
3. Set Bandwidth Setting to Manual Setting
4. Set your Upload Bandwidth in Mb/s to 85-95% of your worst speedtest results without QoS enabled
5. Set your Download Bandwidth in Mb/s to 85-95% of your worst speedtest results without QoS enabled
6. Set your QoS priority mode to one of the predefined modes or choose Customize and set your own. If you customize, it is recommended that you keep Learn-From-Home at the bottom of the priority list.
7. Hit Apply.

## Installation:

FlexQoS requires ASUSWRT-Merlin version 384.15 or higher.

In your SSH Client:

``` /usr/sbin/curl "https://raw.githubusercontent.com/dave14305/FlexQoS/master/flexqos.sh" -o /jffs/addons/flexqos/flexqos.sh --create-dirs && chmod +x /jffs/addons/flexqos/flexqos.sh && sh /jffs/addons/flexqos/flexqos.sh -install ```

If you are reinstalling FlexQoS and a previous backup file is found at ```/jffs/addons/flexqos/restore_flexqos_settings.sh``` you will be prompted to restore the previous settings.

After installation, you will be prompted to restart QoS to enable the FlexQoS features.

## Basic Usage

The FlexQoS tab is located next to the original Classification tab in the Adaptive QoS section of the router GUI.

The page features Download and Upload line charts with accompanying legends and per-class rate details. Classes are ordered according to the user-selected priority order. Statistics are reset to zero whenever QoS is restarted.

Charts display 50 data points, with the total time window depending upon your selected Refresh Rate on the page (from 150 seconds to 500 seconds). By default the line charts show a linear y-axis for the bandwidth rate, but can be configured in the Customize section to display a logarithmic scale so that small rates are still visible compared to large rates. Rates are displayed in kilobits per second. For specific measurement values and timestamps, hover over a specific data point on the line. To freeze the chart, set the page Refresh Rate to "No refresh".

* Rate: a 10-second average of the current number of bits per second flowing through each QoS class displayed in kilobits per second.
* Total Data: the total number of bytes transferred within each QoS class in Bytes

![Traffic Charts](/images/graphs.png)

The Tracked connections table provides a detailed list of LAN-to-WAN connections and how they were categorized by the Adaptive QoS engine and FlexQoS custom rules. Connections originating or terminating at the router are not tracked in this table.

Local devices that have an associated hostname or custom client name from the router's Client List will be shown in the Local Device column and filter dropdown. To see the actual IP address, hover over the device name.

Applications identified for a specific connection are colored according to the resulting Class and priority assigned by Adaptive QoS and FlexQoS custom rules. By default, connections are sorted by Class in descending priority (highest to lowest), then by application name in ascending order. To see the name of the Class, hover your mouse over the Application name. To identify the equivalent AppDB Mark for an application, click on the application name to toggle the display of the hexadecimal Mark. This value can be used to create an AppDB rule when required.

The Tracked connections list will display up to 750 connections while still allowing auto-refresh. If more than 750 connections are tracked, auto-refresh is disabled for performance reasons. You may re-enable auto-refresh at your own risk.
If more than 500 connections are displayed, the Tracked connections list is limited to 500 connections for performance reasons, and the use of the filter fields is recommended.

The Filter connections bar allows real-time filtering of the Tracked connections list using any combination of the available fields:

* Protocol: any, tcp, udp
* Local IP: IP address of the local LAN client. There is a dropdown list for IPv4 clients from the Client List. IPv6 IPs can be entered manually.
* Local Port: the source port used for outgoing connections (partial matches allowed)
* Remote IP: IP address of the remote host (partial matches allowed)
* Remote Port: the destination port for outgoing connections (partial matches allowed)
* Application: filter on the Application name text displayed (partial matches allowed). There is a dropdown list for QoS Classes to focus the list on a connections from a single class. Hexadecimal Marks are not recognized in this field.

When filtered, the Tracked connections list will show the total number of tracked connections as well as the total number of connections shown as a result of the filter, or reaching the 500 connection limit.

To reset the filters to default at any time, click the Reset link on the far right side of the header.

The line charts and Tracked connections will auto-refresh every 3 seconds by default. You may change the refresh rate via the menu at the top of the page. Options are: No refresh, 3 seconds, 5 seconds, 10 seconds.

### Customizing FlexQoS

To customize your QoS experience to suit your browsing habits, click the Customize button in the upper right corner of the page to reveal the Customization options of FlexQoS.

![Customization](/images/customize.png)

To modify the default behavior of ASUS Adaptive QoS, we use iptables rules to modify our network packets in real-time to direct them to our preferred Class and QoS priority, and AppDB rules to change the Class assigned to traffic already identified by the Adaptive QoS engine.

In this way, we have tremendous flexibility to fine-tune the QoS prioritization of our network traffic.

#### Options

##### Queue Discipline

Default: FlexQoS works with the default QoS queue disciplines setup by the Adaptive QoS engine. As of Merlin v386.1, only Stochastic Fair Queuing (sfq) is supported in combination with Hierarchical Token Bucket (htb). Earlier versions of Merlin allow the selection of a queue discipline on the QoS page.

fq_codel: FlexQoS offers the option to override the QoS queue discipline structure by replacing the second-level htb structure with the fq_codel queue discipline.

##### Graph Scale

* Linear
* Logarithmic

##### Enable Conntrack Flushing

* Yes
* No

##### Router Outbound Traffic Class

##### Add Well-Known iptables Rule

#### iptables Rules
To change the Class that a specific connection is assigned by Adaptive QoS, you will create an iptables rule that will uniquely identify that connection by a combination of Local IP, Local Port, Protocol, Remote IP, Remote Port and pre-assigned AppDB Mark.

Through trial and error you will study the Tracked connections table for the specific connections you want to change, looking for combinations that will uniquely identify the traffic you want to change. This is where the Filtered connections can be useful to test.

To add a rule, click the ![plus](https://raw.githubusercontent.com/RMerl/asuswrt-merlin.ng/master/release/src/router/www/images/New_ui/accountadd.png) icon next to the iptables Rules ( Max Limit : 24 ) heading.

In the Create New Policy pop-up window, you will enter the data you gathered in your testing. Sample placeholder text is displayed in each field as a guide.

![Create New Rule](/images/iptablesrule.png)

* Local IP/CIDR: Enter a single IP or a CIDR block for a range of IP addresses. This should be from your LAN subnet. You may also negate the IP by preceding it with an exclamation point (!). As you type the IP address, it will auto-add the decimals. At any point while typing, you can type ! to negate the IP address. If the IP or CIDR entered is not valid, you will see an error below the field.
* Remote IP/CIDR: Enter a single IP or a CIDR block for a range of IP addresses. You may also negate the IP by preceding it with an exclamation point (!). As you type the IP address, it will auto-add the decimals. At any point while typing, you can type ! to negate the IP address. If the IP or CIDR entered is not valid, you will see an error below the field.
* Protocol: TCP, UDP or BOTH (required when Local or Remote ports are specified).
* Local Port: Enter a single port, a port range separated by a colon (:), or multiple ports separated by commas (,). Ports may also be negated with an exclamation point (!). You may not combine ranges with single or multiple ports. Valid ports are between 1-65535.
* Remote Port: Enter a single port, a port range separated by a colon (:), or multiple ports separated by commas (,). Ports may also be negated with an exclamation point (!). You may not combine ranges with single or multiple ports. Valid ports are between 1-65535.
* Mark: Enter the hexadecimal value assigned to an Application name, identified by clicking the Application name in the Tracked connections list, or by using the flexqos appdb search function. You may enter a mark for a specific application, or a wildcard Mark for all applications within a category by using '\*\*\*\*' as the last 4 characters. Mark may also be negated with an exclamation point (!).
* Class: Enter the Class you would like this traffic to be assigned. The resulting QoS priority of this Class is dependent upon your QoS priority customizations done in the standard QoS screens.

Click OK to add your rule. Rules are not saved and do not take effect until after you click the Apply button in the main FlexQoS page.

All iptables rules need at least an IP or port specification. A rule with only a Mark specified is better suited as an AppDB rule and will be rejected in the iptables Rules section.

To delete a rule, click the ![Delete](https://raw.githubusercontent.com/RMerl/asuswrt-merlin.ng/master/release/src/router/www/images/New_ui/accountdelete.png) icon to the right of the rule.

To edit an existing rule, click on any field within the row to toggle in-cell editing. Make the necessary changes and then click outside the area of the table to save your changes. The same shortcuts and validations apply to in-cell editing as when adding a rule via the add button.

![Customization Tables](/images/iptables_editing.png)

To reset the iptables rules to the default rules provided by FlexQoS, click the Reset link in the iptables Rules heading. Changes do not take effect until you click Apply.

There is currently a limit of 24 iptables rules to ensure we do not overflow the space available in the Merlin API custom settings repository.

Every connection is evaluated against all iptables rules in your rule list, and the last rule to match your connection is the rule that will determine the final priority of that connection. If multiple iptables rules can match your connection, be sure that your most important rule is at the bottom of the list.

FlexQoS installs with the following default iptables rules:

* WiFi Calling: Remote UDP ports 500 and 4500 to Work-From-Home
* FaceTime: Local UDP port range 16384-16415 to Work-From-Home
* UseNet/NNTP: Remote TCP ports 119 and 563 to File Downloads
* Game Downloads: Identified Gaming applications with Remote TCP ports 80 and 443 to Game Downloads

All default rules are editable or removable to suit your needs.

The Gaming rule is useful for LAN devices whose primary purpose is gaming and you want their Untracked traffic that isn't HTTP/HTTPS traffic to be prioritized as Gaming. You can add the Gaming rule by selecting it from the "Add Well-Known iptables Rule" dropdown list. By default, it adds the rule with the local IP of the device you are logged into the router GUI with at the time. You should update the rule with the correct IP or CIDR after it's added.

If you wish to create the Gaming rule manually, add a rule with these parameters:

- Local IP/CIDR: 192.168.1.100/30 (unique to your gaming devices)
- Remote IP/CIDR: blank
- Proto: BOTH
- Local Port: blank
- Remote Port: !80,443 (note the exclamation point to invert, i.e. NOT port 80 and NOT port 443)
- Mark: 000000
- Class: Gaming

Additional well-known rules are available in the "Add Well-Known iptables Rule" dropdown list, including the built-in default rules in case you delete them and want to later put them back.

To re-order your rules, you can delete rules from the list and re-add them in your preferred order by selecting them from the "Add Well-Known iptables Rule" menu under the *User-defined rules* section. Duplicate rules are not allowed.

iptables rules that do not specify any IPv4 remote IP addresses will also apply to IPv6 traffic. IPv6 addresses are not permitted in any rule.

#### AppDB Redirection Rules

If your application traffic is properly identified by the Adaptive QoS engine, but you want it to be prioritized in a different class from its default class, you will use an AppDB Redirection rule to achieve this.

To create an AppDB Redirection rule:

1. Click in the search box for Application and begin typing the name of the application as seen in the Tracked connections list. Click on the correct match in the popup list. The hexadecimal Mark will auto-populate.
**OR**
2. Enter the Mark from the Tracked connections list (click on the Application label to reveal the underlying Mark value). When you click or tab out of the entry box, the matching Application name will auto-populate to confirm your choice.
3. Assign a new Class to the application. The resulting QoS priority of this Class is dependent upon your QoS priority customizations done in the standard QoS screens.
4. Click the Add icon to add the rule. Rules are not saved and do not take effect until after you click the Apply button in the main FlexQoS page.

If you want enter a wildcard Mark (e.g. 09\*\*\*\* Management tools and protocols), all traffic identified under that category of applications will be redirected to the chosen Class. Non-wildcard Marks will override wildcard Marks. For example, by default, wildcard Mark 14\*\*\*\* is directed to Web Surfing. But Mark 1400C5 (DNS over TLS) can also be added to go to Net Control. The more specific 1400C5 rule will be applied before the generic 14\*\*\*\* rule.

To delete a rule, click the Delete icon in the Edit column of the rule.

To edit a rule, click the Edit icon in the Edit column of the rule. The rule contents are moved back to the editing row at the top of the list. When you add the rule after making changes, it is added to the bottom of the list.

Only one rule per Mark is allowed in the AppDB Redirection Rules. Wildcard Marks are still allowed.

When you click Apply in the FlexQoS page to apply your changes, rules with Wildcard Marks will be sorted to the bottom of the rules list to ensure correct interpretation of rule precedence when displaying the Tracked connections list.

FlexQoS installs with the following default AppDB Redirection rules:

* Untracked (000000): Others
* Snapchat (00006B): Others
* Speedtest.net (0D0007): File Downloads
* Google Play (0D0086): File Downloads
* Apple Store (0D00A0): File Downloads
* World Wide Web HTTP (12003F): Web Surfing
* Network protocols (13\*\*\*\* and 14\*\*\*\*): Web Surfing

All default rules are editable or removable to suit your needs. It is recommended to keep a rule for Untracked (000000) traffic at a minimum.

To reset your AppDB Redirection rules to the default rules provided by FlexQoS, click the Reset link in the AppDB Redirection Rules heading. Changes do not take effect until you click Apply.

There is currently a limit of 32 AppDB Redirection rules. In theory, we can allow up to 333 rules and be within the limits of the Merlin Addon API. 32 rules should be adequate for most users.

#### Bandwidth Allocations

FlexQoS enables you to allocate up to 100% of your bandwidth to specific named Classes. Download and Upload bandwidth can be allocated independently, allowing for minimum and maximum allocations (rate and ceiling, respectively, in QoS terminology).

Classes are listed in the same order as your chosen priority, with a matching color indicator.

Minimum Reserved Bandwidth: This is known as "rate" in QoS terminology. This is the guaranteed bandwidth allocated to this Class before lower priority Classes will be served. Valid range is 1-99%. The total of all Minimums should not exceed 100%.
Maximum Reserved Bandwidth: This is known as "ceiling" in QoS terminology. This is the maximum bandwidth this Class may be allocated assuming bandwidth is available from higher priority Classes. Valid range is 1-100%.

If you enter an invalid value, the field will turn red and you must correct the value before hitting Apply. If your Minimum bandwidth allocations exceed 100%, you will see a yellow warning message below the table. You can still hit Apply and save the values, but it is not recommended to exceed 100%.

You might choose to limit the Maximum bandwidth for a Class such as File Downloads to ensure it will never consume all available bandwidth. In general, it is a best practice to leave the Maximum values at 100% to allow all bandwidth to be used if available.

To reset your Download or Upload bandwidth allocations to the FlexQoS default values, click the Reset link in the corresponding header (Bandwidth, Download or Upload). Click Apply to save your changes.

#### Saving

To save all your changes and restart QoS to apply them, always use the Apply button in the upper right corner of the FlexQoS page. If you make a change and do not want to save it, you can reload the page with the F5 key or your browser's reload button to revert to the previously saved settings. No changes made in the FlexQoS WebUI are saved until you click Apply, including any of the Reset to defaults links.

When clicking Apply, if the total size of iptables rules or AppDB Redirection rules exceeds 2999 characters, an error message will appear and one or more rules will need to be deleted to remain within the 2999 character limit.

If the total size of all Merlin addons settings exceeds 8192 characters (8KB), an error message will appear and further investigation will be necessary to see why your settings are so large.

FlexQoS relies solely on the Merlin Addon API custom settings repository, so it is likely the largest consumer of the available space. But in normal usage, it should never exceed 4KB.

## Command Line

FlexQoS is included in amtm, courtesy of @decoderman. Check option 3 in amtm to install FlexQoS or invoke the command line menu system.

Advanced users can invoke the CLI menu with either:

#### Fully qualified path with menu parameter:
``` /jffs/addons/flexqos/flexqos.sh -menu ```

#### Fully qualified path without parameters:
``` /jffs/addons/flexqos/flexqos.sh ```

#### Entware shortcut or shell alias:
``` flexqos -menu ```

``` flexqos ```

### Menu

The menu system allows access to functions not yet available in the WebUI:

1. About
2. Update
3. Debug
4. Restart
5. Backup
6. Restore (backup)
7. Delete (backup)
9. Uninstall

#### About

The About option (1) displays version information and help text related to the script.

Command Line equivalent: ``` flexqos about ```

#### Update

The Update option (2) checks for FlexQoS updates on GitHub and offers to update your installed version to the latest version.

If an update includes a change in version number, it will be indicated in the update message. If there is no change in version, but a different version is available on GitHub, it will be described as a "hotfix".

In both cases you will be given the chance to accept or defer the update.

When updating the script, you will be prompted to restart QoS to ensure the latest changes take effect in your router. If you defer this restart, you can invoke the QoS restart later using menu option 4 or the command line function ``` flexqos restart ```

Command Line equivalent: ``` flexqos update ```

#### Debug

The Debug option (3) generates useful information about your QoS setup to share with the developer and other users to help troubleshoot any issues you may be having with the script or your custom rules.  The debug output includes snbforums.com SPOILER and CODE tags to allow clean copy and paste into a forum post. Please include both the beginning and ending tags. The debug output may be long and you may have to scroll up in your terminal window to capture the beginning of the output.

If you edit or redact any sensitive information in the debug output (e.g. if one of your rules includes your employer's IP address range), please note the change when posting the output to prevent confusion.

Command Line equivalent: ``` flexqos debug ```

#### Restart

The Restart option (4) restarts QoS and the router's firewall. The same can be achieved by clicking Apply in the FlexQoS WebUI. This command does not reboot the router.

Command Line equivalent: ``` flexqos restart ```

#### Backup

The Backup option (5) creates a backup of your FlexQoS custom settings under ```/jffs/addons/flexqos/restore_flexqos_settings.sh```. It is a good idea to copy this file to an alternate location or perform regular JFFS backups since the original settings and the backup both reside in JFFS.

If a previous backup already exists, you will be shown the date of the existing backup and prompted to overwrite it.

Command Line equivalent: ``` flexqos backup ```

#### Restore

The Restore option (6) is only shown if an existing backup file is detected at ```/jffs/addons/flexqos/restore_flexqos_settings.sh```. When you select Restore, the date of the backup file is shown and you are prompted to restore the backup.

When restoring a backup, you will be prompted to restart QoS when exiting the menu, to allow the restored settings to take effect. If you do not restart QoS after the restore, you may see inconsistent behavior in the FlexQoS WebUI because it is reading the restored settings, but they have not been applied yet.

#### Delete

The Delete option (7) is only shown if an existing backup file is detected at ```/jffs/addons/flexqos/restore_flexqos_settings.sh```. This option will delete the existing backup file without confirmation.

#### Uninstall

The Uninstall option (9) will remove the script and its files and directories. You will be prompted to create a backup of your settings before uninstalling, if no backup exists. If a backup does exist, you will be prompted to keep or delete it, in case you plan to reinstall later. In all cases FlexQoS custom settings are deleted during uninstall.

After uninstalling, you will be prompted to restart QoS to undo the FlexQoS customizations and revert to stock Adaptive QoS settings. No reboots are forced during uninstall.

Command Line equivalent: ``` flexqos uninstall ```

### Command Line functions

Some FlexQoS commands can be invoked directly via the command line by passing the command as a parameter to the flexqos script. Below are the command line functions not covered in the menu section above.

#### appdb

``` flexqos appdb <string> ```

The appdb sub-command will search the ASUS/Trend Micro application database for an application name and display the necessary hexadecimal Mark to create a custom AppDB Redirection rule in the WebUI.

The output also includes the original target Class for the application for reference.

```
# flexqos appdb itunes
iTunes/App Store
 Originally:  Streaming
 Mark:        04000A

iTunes Festival
 Originally:  Streaming
 Mark:        040037
```

The appdb search will return up to 25 results per search.

Similar functionality can be used in the WebUI by searching in the Application search box under AppDB Redirection Rules in the Customize view.

#### disable / enable

``` flexqos disable ```

``` flexqos enable ```

The disable and enable sub-commands allow disabling and enabling of FlexQoS without uninstalling. Disabling FlexQoS will restart QoS and the firewall immediately.

Enabling FlexQoS will follow the installation process to ensure a consistent installation after disabling.

#### develop / stable

``` flexqos develop ```

``` flexqos stable ```

From time to time, the developer may have preview versions of upcoming FlexQoS updates available in the "develop" branch of the GitHub repository. Most users will want to remain on the stable branch (called "master" on GitHub). But advanced users can toggle between stable and develop by invoking the commands above.

When switching from one branch to another, an update check is immediately invoked to download the appropriate version from GitHub. If you are already on the branch requested, a confirmation is displayed and no update is performed. To check for an available update for your branch, use the normal update function.

When you are running the develop branch, the FlexQoS CLI menu headings will indicate "Development channel", and the WebUI will indicate "Dev" next to the version number.

#### flushct / noflushct

``` flexqos flushct ```

``` flexqos noflushct ```

By default, FlexQoS will force all existing connections to be re-evaluated by new iptables rules when applying FlexQoS changes. To disable this feature, use the noflushct command. To re-enable it, use the flushct command.

This may be useful for users with IOT devices or cameras that establish connections before QoS and the firewall starts up during boot or any other restart activity.

## Support

See <a href="https://www.snbforums.com/forums/asuswrt-merlin-addons.60/?prefix_id=8" rel="nofollow">SmallNetBuilder Forums</a> for more information & discussion

Development issues can be posted here on GitHub under the Issues tab.
