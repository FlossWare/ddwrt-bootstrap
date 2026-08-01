#!/bin/sh

# DD-WRT nvram rc_startup script (Entware-only example)
#
# Set via: nvram set rc_startup="$(cat nvram-rc_startup.sh)" && nvram commit
#
# For routers that don't need static IP (e.g., running DHCP server),
# this can be left empty or contain only comments.

# Uncomment and adjust for static IP configuration:
#ifconfig br0 192.168.1.2 netmask 255.255.255.0 up
#ifconfig wlan0 192.168.1.2 netmask 255.255.255.0 up
#ip route del default
#ip route add default via 192.168.1.1 dev wlan0
