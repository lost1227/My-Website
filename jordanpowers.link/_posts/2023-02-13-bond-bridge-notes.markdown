---
layout: post
title:  "Advanced configuration for a Bond Bridge"
date:   2023-02-13 12:00:00 -0800
categories:
---
## Rationale
I recently just wasted an evening trying to get a
[Bond Bridge](https://bondhome.io/product/bond-bridge/) setup and connected to my network. Our
network is somewhat more complicated than usual, with multiple access points on both the
2.4GHz and 5GHz spectrums sharing the same SSID. Also, we use
a separate SSID and vlan that is isolated from our normal network for all our IoT devices, to try
and minimize the risk of a malware infected IoT device spreading the virus on to our personal
devices. Unfortunately, this nonstandard configuration caused a few hicccups with the bridge which
where fairly annoying to figure out. And so, with this post
I hope to save some time for anyone in the future (mostly myself if I ever need to reconnect the
bridge).

## DNS
This is the real kicker that wasted the majority of the evening. It turns out, the Bond Bridge
**ignores the DNS value** from the DHCP server. It just hardcodes the 8.8.8.8 Google DNS.
I use a [pi-hole](https://pi-hole.net/) on my network (which reduces both spying/tracking and
advertisements), and I force the IoT devices to use the pihole by blocking all external traffic on
port 53 (which is the port DNS uses). Unfortunately, this means the Bond Bridge would connect to the
wifi and show a connection-good status, but then not show up in the Bond app since it couldn't
resolve the Bond servers.

The solution was twofold:
1. First, I had to set a static DHCP reservation for the Bond Bridge in my router, so that it
would always receive the same static ip.
2. Then, I had to add an exception to the firewall to allow DNS traffic from that static ip.

This seems to be working now, but it really shouldn't be necessary. After all, what's the point
of including a DNS server in the DHCP information if the device is just going to ignore it?

## Multiple APs and 2.4GHz vs 5GHz
For some reason the Bond Bridge refused to connect to our network. We would select the SSID and enter
the password as expected from the Bond app, and the Bond Bridge would restart then refuse to connect
to the wifi. I'm not certain what the issue was (I believe it to be a combination of the fact that
we have mutliple access points on both 2.4GHz and 5GHz under the same SSID), but the solution was
actually pretty simple.

To resolve the issue, we just had to choose the "Other" option in the list of SSIDs. The app would
then ask for both the SSID and the *BSSID* of the desired network (which it calls the MAC address).
While all our APs share the same SSID, they all have different BSSIDs (by definition), so we were
able to look up the BSSID of the 2.4GHz band on the desired AP. Entering both these values
(as well as the network password) allowed the Bond Bridge to finally connect to the network.
