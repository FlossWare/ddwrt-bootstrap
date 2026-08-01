#!/bin/sh

# Debian Chroot Launcher for DD-WRT
#
# Starts/stops a Debian chroot environment from USB storage.
# Services to start are defined in the chroot-services.list file.
#
# Based on https://github.com/DontBeAPadavan/chroot-debian
# 3-pass unmount from Qdebian.qpkd (qnapclub)

STORAGE_DIR="/tmp/mnt/sda1"

CHROOT_DIR=$(readlink -f ${STORAGE_DIR}/debian)

CHROOT_SERVICES_LIST=${STORAGE_DIR}/dd-wrt/etc/chroot-services.list

CHROOT_BIN=$(which chroot)

MountedDirCount="$(/bin/mount | grep $CHROOT_DIR | wc -l)"

start() {
	if [ -f /etc/hosts ]; then
		cp /etc/hosts $CHROOT_DIR/etc/hosts
	fi

	if [ -f /etc/resolve.conf ]; then
		cp /etc/resolve.conf $CHROOT_DIR/etc/resolve.conf
	fi

	echo 'Starting Debian services...'
	for dir in dev dev/pts proc sys; do
		/bin/mount -o bind /$dir $CHROOT_DIR/$dir
	done

	if [ ! -e "$CHROOT_SERVICES_LIST" ]; then
		echo 'WARNING: No Debian services defined.'
		echo "Please, define Debian services to start in $CHROOT_SERVICES_LIST file!"
		echo 'One service per line. Hint: these are script names from Debian /etc/init.d/'
	else
		for item in $(cat $CHROOT_SERVICES_LIST); do
			PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
			LC_ALL=C \
			LANGUAGE=C \
			LANG=C \
			$CHROOT_BIN $CHROOT_DIR /etc/init.d/$item start
		done
	fi
}

stop() {
	if [ -e "$CHROOT_SERVICES_LIST" ]; then
		echo 'Stopping Debian services...'
		for item in $(cat $CHROOT_SERVICES_LIST); do
			PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
			LC_ALL=C \
			LANGUAGE=C \
			LANG=C \
			$CHROOT_BIN $CHROOT_DIR /etc/init.d/$item stop
		done
	fi

	sleep 1
	for dir in dev/pts dev proc sys; do
		/bin/umount $CHROOT_DIR/$dir 2>/dev/null
		sleep 2
	done

	for dir in dev/pts dev proc sys; do
		/bin/umount -lf $CHROOT_DIR/$dir 2>/dev/null
		sleep 2
	done

	for dir in dev/pts dev proc sys; do
		/bin/umount -l $CHROOT_DIR/$dir 2>/dev/null
		sleep 2
	done
}

status() {
	if [ $MountedDirCount -gt 0 ]; then
		echo 'Debian services are running'
	else
		echo 'Debian services are stopped'
	fi
}

case "$1" in
	start)
		start
	;;
	stop)
		stop
	;;
	restart)
		stop
		sleep 5
		start
	;;
	status)
		status
	;;
	*)
		echo "Usage: $0 (start|stop|restart|status)"
		exit 1
		;;
esac
