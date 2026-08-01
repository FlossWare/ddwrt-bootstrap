# ddwrt-bootstrap

Bootstrap scripts for DD-WRT routers with USB storage, Entware, and optional Debian chroot.

## What it does

Provides a modular init system for DD-WRT routers that:

- Mounts USB storage using filesystem labels (stable across device reordering)
- Bind-mounts a shared root home directory across DD-WRT, Entware, and Debian chroot
- Bind-mounts a shared MOTD across all environments
- Initializes Entware (`/opt` via bind mount)
- Optionally starts a Debian chroot with declarative service management
- Manages swap on USB storage

## Prerequisites

- DD-WRT router with USB port
- USB drive with ext4 partition(s), labeled with `tune2fs -L`
- [Entware](https://github.com/Entware/Entware) installed on the USB drive

## USB drive layout

```
/tmp/mnt/sda1/
  dd-wrt/
    etc/
      init.d/
        dd-wrt.sh           # Master orchestrator (this repo)
        entware.sh           # Entware init wrapper
        debian.sh            # Debian chroot launcher
      chroot-services.list   # Services to start in Debian chroot
      motd                   # Shared MOTD file
    root/                    # Shared root home directory
    var/
      swapfile               # Swap file
  entware/                   # Entware root (bind-mounted to /opt)
  debian/                    # Debian chroot root (optional)
```

## Deployment

### 1. Prepare USB storage

Label your partitions:

```sh
tune2fs -L sda /dev/sdX1
tune2fs -L sdb /dev/sdX2  # optional second partition
```

### 2. Copy scripts to USB

```sh
# Mount USB and create directory structure
mkdir -p /tmp/mnt/sda1/dd-wrt/etc/init.d
mkdir -p /tmp/mnt/sda1/dd-wrt/root
mkdir -p /tmp/mnt/sda1/dd-wrt/var
mkdir -p /tmp/mnt/sda1/entware

cp etc/init.d/dd-wrt.sh   /tmp/mnt/sda1/dd-wrt/etc/init.d/
cp etc/init.d/entware.sh   /tmp/mnt/sda1/dd-wrt/etc/init.d/
cp etc/init.d/debian.sh    /tmp/mnt/sda1/dd-wrt/etc/init.d/
cp etc/chroot-services.list /tmp/mnt/sda1/dd-wrt/etc/

chmod +x /tmp/mnt/sda1/dd-wrt/etc/init.d/*.sh
```

### 3. Create swap (optional)

```sh
dd if=/dev/zero of=/tmp/mnt/sda1/dd-wrt/var/swapfile bs=1M count=512
mkswap /tmp/mnt/sda1/dd-wrt/var/swapfile
chmod 600 /tmp/mnt/sda1/dd-wrt/var/swapfile
```

### 4. Create MOTD

```sh
mkdir -p /tmp/mnt/sda1/dd-wrt/etc
echo "Welcome to $(hostname)" > /tmp/mnt/sda1/dd-wrt/etc/motd
```

### 5. Set nvram scripts

```sh
# USB mount handler (runs when USB is detected)
nvram set rc_usb="$(cat examples/entware-only/nvram-rc_usb.sh)"
nvram commit

# Startup script (runs at boot, before USB)
nvram set rc_startup="$(cat examples/entware-only/nvram-rc_startup.sh)"
nvram commit
```

### 6. Enable Debian chroot (optional)

If you have a Debian chroot installed on the USB drive:

1. Edit `dd-wrt.sh` and uncomment `startDebian` in the `start()` function
2. Edit `etc/chroot-services.list` to list the Debian services you want
3. Set `STORAGE_DIR` in `debian.sh` if your chroot is on a different partition

## Configuration

### dd-wrt.sh

Edit the variables at the top:

- `STORAGE_DIR` - USB mount point (default: `/tmp/mnt/sda1`)
- `LOG_FILE` - Log file path (default: `/tmp/flossware.log`)

### debian.sh

Edit the variable at the top:

- `STORAGE_DIR` - USB mount point (default: `/tmp/mnt/sda1`)

### chroot-services.list

One Debian init script name per line. See the file for available options and examples.

## Boot sequence

1. DD-WRT boots and runs `rc_startup` (static IP, regulatory domain)
2. USB storage detected, DD-WRT runs `rc_usb`
3. `rc_usb` labels partitions via `blkid`, mounts them, calls `dd-wrt.sh start`
4. `dd-wrt.sh` runs in order:
   - `startModProbe` - Load kernel modules (cifs, nfs, xfs, etc.)
   - `startMount` - Mount local/remote filesystems
   - `startBind` - Bind mount Entware to `/opt`, shared root home, shared MOTD
   - Swap on
   - `startEntware` - Run Entware's `rc.unslung`
   - `startDebian` - Start Debian chroot services (if enabled)

## Examples

- `examples/entware-only/` - Router running Entware without Debian chroot
- `examples/entware-plus-debian/` - Router running Entware with Debian chroot

## Separating framework from config

This repo provides the generic, reusable framework scripts. For managing host-specific configurations (per-router service lists, IP addresses, custom mounts), create a separate config repo organized by hostname:

```
my-ddwrt-config/
  router-a/
    chroot-services.list
    debian.sh
    nvram-rc_startup.sh
    nvram-rc_usb.sh
  router-b/
    ...
  deploy.sh
```

The framework scripts (`dd-wrt.sh`, `entware.sh`) stay identical across routers. Only `debian.sh`, `chroot-services.list`, and the nvram scripts vary per host.

## SSH access

DD-WRT runs dropbear on port 2222. Recent builds (v2025.89+) only support **ed25519** keys — RSA keys will be silently rejected. Generate an ed25519 key and add it to `/tmp/mnt/sda1/dd-wrt/root/.ssh/authorized_keys` (which is bind-mounted to `/tmp/root/.ssh/` by `dd-wrt.sh`).

The Debian chroot runs OpenSSH on port 22 and supports all key types.

## License

MIT
