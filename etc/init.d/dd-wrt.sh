#!/bin/sh

# DD-WRT Bootstrap Orchestrator
#
# Master init script for DD-WRT routers with USB storage.
# Handles: kernel modules, bind mounts, swap, Entware, and optional Debian chroot.
#
# USB storage layout expected:
#   /tmp/mnt/sda1/
#     dd-wrt/          - DD-WRT overlay (root home, motd, init scripts, swap)
#     entware/         - Entware package manager root (bind-mounted to /opt)
#     debian/          - Debian chroot (optional)

# Defaults (overridden by dd-wrt.conf if present)
STORAGE_DIR="/tmp/mnt/sda1"
LOG_FILE="/tmp/flossware.log"

# Source host-specific config
CONF_FILE="${STORAGE_DIR}/dd-wrt/etc/dd-wrt.conf"
if [ -f "$CONF_FILE" ]; then
    . "$CONF_FILE"
fi

log() {
    echo "---------------------------------------" 2>&1 >> ${LOG_FILE}
    echo $@ 2>&1 >> ${LOG_FILE}
    echo "---------------------------------------" 2>&1 >> ${LOG_FILE}
    echo 2>&1 >> ${LOG_FILE}
}

startModProbe() {
    log "Running modprobe..."

    /sbin/modprobe cifs  2>&1 >> ${LOG_FILE}
    /sbin/modprobe isofs 2>&1 >> ${LOG_FILE}
    /sbin/modprobe nfsd  2>&1 >> ${LOG_FILE}
    /sbin/modprobe nfs   2>&1 >> ${LOG_FILE}
    /sbin/modprobe xfs   2>&1 >> ${LOG_FILE}
}

stopModProbe() {
    log "Stopping modprobe..."
}

startLocalMount() {
    log "Mounting local dirs..."

    #mount /dev/sda1 ${STORAGE_DIR}
}

stopLocalMount() {
    log "Unmounting local dirs..."

    #umount ${STORAGE_DIR}
}

startRemoteMount() {
     log "Mounting remote dirs..."
}

stopRemoteMount() {
     log "Unmounting remote dirs..."
}

startMount() {
    startLocalMount
    startRemoteMount
}

stopMount() {
    stopRemoteMount
    stopLocalMount
}

startSleep() {
    log "Sleeping 25s..."

    sleep 25s
}

startBind() {
    log "Binding..."

    mkdir -p ${STORAGE_DIR}/entware /opt
    mount -o bind ${STORAGE_DIR}/entware /opt

    touch ${STORAGE_DIR}/entware/etc/motd

    mount -o bind ${STORAGE_DIR}/dd-wrt/etc/motd /etc/motd
    mount -o bind ${STORAGE_DIR}/dd-wrt/etc/motd ${STORAGE_DIR}/entware/etc/motd
    mount -o bind ${STORAGE_DIR}/dd-wrt/etc/motd ${STORAGE_DIR}/debian/etc/motd

    mount -o bind ${STORAGE_DIR}/dd-wrt/root /tmp/root
    mount -o bind ${STORAGE_DIR}/dd-wrt/root ${STORAGE_DIR}/debian/root
    mount -o bind ${STORAGE_DIR}/dd-wrt/root ${STORAGE_DIR}/entware/root
}

stopBind() {
    log "Unbinding..."

    umount ${STORAGE_DIR}/entware/root
    umount ${STORAGE_DIR}/debian/root
    umount /tmp/root

    umount ${STORAGE_DIR}/debian/etc/motd
    umount ${STORAGE_DIR}/entware/etc/motd
    umount /etc/motd

    umount /opt
}

startDdwrt() {
    log "Starting DD-WRT..."
}

stopDdwrt() {
    log "Stopping DD-WRT..."
}

startEntware() {
    log "Starting Entware..."

    ${STORAGE_DIR}/dd-wrt/etc/init.d/entware.sh start 2>&1 >> ${LOG_FILE}
}

stopEntware() {
    log "Stopping Entware..."

    ${STORAGE_DIR}/dd-wrt/etc/init.d/entware.sh stop 2>&1 >> ${LOG_FILE}
}

startDebian() {
    log "Starting Debian..."

    ${STORAGE_DIR}/dd-wrt/etc/init.d/debian.sh start >> ${LOG_FILE}
}

stopDebian() {
    log "Stopping Debian..."

    ${STORAGE_DIR}/dd-wrt/etc/init.d/debian.sh stop >> ${LOG_FILE}
}

start() {
    startModProbe

    startMount

    startBind

    swapon ${STORAGE_DIR}/dd-wrt/var/swapfile
    sysctl vm.swappiness=10

    startDdwrt

    startEntware

    # Uncomment to enable Debian chroot
    #startDebian
}

stop() {
    stopDebian

    stopEntware

    stopDdwrt

    stopBind

    stopMount

    stopModProbe

    swapoff ${STORAGE_DIR}/dd-wrt/var/swapfile
}

case "$1" in
    start)
        start
        ;;

    stop)
        stop
        ;;
esac
