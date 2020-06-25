# FlexQoS - Flexible QoS Enhancement Script for Adaptive QOS on ASUSWRT-Merlin

This script has been tested on ASUS RT-AC68U, running ASUSWRT-Merlin 384.18, using Adaptive QoS with Manual Bandwidth Settings

## Quick Overview:

-- Script allows reclassifying Untracked traffic (mark 000000) from current default class to any class

-- Script Changes Minimum Guaranteed Bandwidth per QoS category to user defined percentages for upload and download.

-- Script allows for multiple custom QoS rules using iptables rules

-- Script allows for redirection of existing identified traffic using AppDB rules

## Full Overview:

See <a href="https://www.snbforums.com/threads/release-freshjr-adaptive-qos-improvements-custom-rules-and-inner-workings.36836/" rel="nofollow">SmallNetBuilder Forums</a> for more information & discussion

## Installation:

FlexQoS requires ASUSWRT-Merlin version 384.18 or higher. Stock ASUS firmware is no longer supported since the script now depends on the Merlin Addon API.

In your SSH Client:

``` curl "https://raw.githubusercontent.com/dave14305/FlexQoS/master/flexqos.sh" -o /jffs/addons/flexqos/flexqos.sh --create-dirs && sh /jffs/addons/flexqos/flexqos.sh -install ```

## Uninstall:

In your SSH Client:

``` /jffs/addons/flexqos/flexqos.sh -uninstall ```

## Screenshots

###Traffic Pie Chart
[![Traffic Pie Chart](https://i.imgur.com/htAkaDq.png "Traffic Pie Chart")](https://i.imgur.com/htAkaDq.png "Traffic Pie Chart")

###Customization Tables
[![Customization Tables](https://i.imgur.com/cvus7VE.png "Customization Tables")](https://i.imgur.com/cvus7VE.png "Customization Tables")

###Create New Rule
[![Create New Rule](https://i.imgur.com/dbpABjg.png "Create New Rule")](https://i.imgur.com/dbpABjg.png "Create New Rule")
