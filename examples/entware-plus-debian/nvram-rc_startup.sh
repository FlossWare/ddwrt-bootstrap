#!/bin/sh

# DD-WRT nvram rc_startup script (Entware + Debian chroot example)
#
# Set via: nvram set rc_startup="$(cat nvram-rc_startup.sh)" && nvram commit
#
# Runs before rc_usb. Use for static IP and regulatory domain.

sleep 10

ifconfig br0 192.168.1.4 netmask 255.255.255.0 up
ifconfig wlan0 192.168.1.4 netmask 255.255.255.0 up
ip route del default
ip route add default via 192.168.1.1 dev wlan0

iw reg set US
