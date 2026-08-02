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

- DD-WRT router with USB port (v2025.89+ recommended for ed25519 SSH support)
- USB drive with ext4 partition(s), labeled with `tune2fs -L`
- One or both of:
  - [Entware](https://github.com/Entware/Entware) installed on the USB drive (for architectures without Debian support, e.g. MIPS)
  - A Debian chroot on the USB drive (for architectures with Debian support, e.g. ARMv7)

## Boot sequence

DD-WRT executes two special nvram variables during boot:

- `rc_startup`: Runs at system startup (before USB detection) for static IP configuration, regulatory domain settings, and other early boot tasks
- `rc_usb`: Runs when USB storage is detected to mount partitions and trigger the bootstrap framework

The framework then executes in this order:

1. `rc_startup` runs (static IP, regulatory domain)
2. USB storage detected, DD-WRT runs `rc_usb`
3. `rc_usb` identifies partitions via `blkid`, mounts them, calls `dd-wrt.sh start`
4. `dd-wrt.sh` runs in order:
   - `startModProbe` - Load kernel modules (cifs, nfs, xfs, etc.)
   - `startMount` - Mount local/remote filesystems
   - `startBind` - Bind mount shared root home, shared MOTD, and Entware to `/opt` (if present)
   - Swap on
   - `startEntware` - Run Entware's `rc.unslung` (if installed)
   - `startDebian` - Start Debian chroot services (if enabled)

## Configuration

### dd-wrt.conf

Sourced by both `dd-wrt.sh` and `debian.sh` at startup. Place in `etc/dd-wrt.conf` on the USB drive:

```sh
STORAGE_DIR="/tmp/mnt/sda1"   # USB mount point (default)
LOG_FILE="/tmp/flossware.log"  # Log file path (default)
```

If this file is absent, the defaults above are used.

### chroot-services.list

One Debian init script name per line. See the file for available options and examples.

### debian-mounts.sh (optional)

Define `start_extra_mounts()` and `stop_extra_mounts()` functions for host-specific bind mounts inside the Debian chroot. Place in `etc/debian-mounts.sh` on the USB drive. See `etc/debian-mounts.sh.example`.

```sh
start_extra_mounts() {
    mkdir -p ${CHROOT_DIR}/exports/media-01
    mount -o bind /tmp/mnt/sdb1 ${CHROOT_DIR}/exports/media-01
}

stop_extra_mounts() {
    umount ${CHROOT_DIR}/exports/media-01
}
```

If this file is absent, no extra mounts are performed.

## USB drive layout

```
/tmp/mnt/sda1/
  dd-wrt/
    etc/
      init.d/
        dd-wrt.sh           # Master orchestrator (this repo)
        entware.sh           # Entware init wrapper (optional)
        debian.sh            # Debian chroot launcher (optional)
      dd-wrt.conf            # Host-specific config (STORAGE_DIR, LOG_FILE)
      chroot-services.list   # Services to start in Debian chroot
      debian-mounts.sh       # Extra chroot mounts (optional)
      motd                   # Shared MOTD file
    root/                    # Shared root home directory
    var/
      swapfile               # Swap file
  entware/                   # Entware root (bind-mounted to /opt, optional)
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

cp etc/init.d/dd-wrt.sh    /tmp/mnt/sda1/dd-wrt/etc/init.d/

# Copy whichever you need (or both):
cp etc/init.d/entware.sh   /tmp/mnt/sda1/dd-wrt/etc/init.d/   # if using Entware
cp etc/init.d/debian.sh    /tmp/mnt/sda1/dd-wrt/etc/init.d/   # if using Debian chroot
cp etc/chroot-services.list /tmp/mnt/sda1/dd-wrt/etc/          # if using Debian chroot

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

For Entware-only routers, use the examples in `examples/entware-only/`. For routers with a Debian chroot, use `examples/entware-plus-debian/`.

```sh
# USB mount handler (runs when USB is detected)
nvram set rc_usb="$(cat examples/entware-only/nvram-rc_usb.sh)"
nvram commit

# Startup script (runs at boot, before USB)
nvram set rc_startup="$(cat examples/entware-only/nvram-rc_startup.sh)"
nvram commit
```

### 6. Enable optional components

**Entware** (for routers without Debian chroot support):

1. Install [Entware](https://github.com/Entware/Entware) on the USB drive under `entware/`
2. Ensure `entware.sh` is copied to `etc/init.d/` and `startEntware` is uncommented in `dd-wrt.sh`

**Debian chroot** (for routers with compatible CPU architecture):

1. Install a Debian chroot on the USB drive under `debian/`
2. Uncomment `startDebian` in the `start()` function of `dd-wrt.sh`
3. Edit `etc/chroot-services.list` to list the Debian services you want
4. Configure `STORAGE_DIR` in `dd-wrt.conf` if your chroot is on a different partition

## SSH access

DD-WRT runs dropbear on port 2222. Recent builds (v2025.89+) only support **ed25519** keys -- RSA keys will be silently rejected. Generate an ed25519 key with `ssh-keygen -t ed25519` and add it to `/tmp/mnt/sda1/dd-wrt/root/.ssh/authorized_keys` (which is bind-mounted to `/tmp/root/.ssh/` by `dd-wrt.sh`).

The Debian chroot runs OpenSSH on port 22 and supports all key types.

## Troubleshooting

- **USB not detected**: Verify your USB drive is properly labeled and formatted as ext4. Check `dmesg` on the router for detection issues.
- **Services not starting**: Ensure all scripts have executable permissions (`chmod +x`). Check logs in the file specified by `LOG_FILE` (default: `/tmp/flossware.log`).
- **Chroot issues**: Verify the Debian chroot is properly installed on the USB drive and that all required bind mounts (`/dev`, `/proc`, `/sys`) are available.
- **SSH key rejected**: Recent DD-WRT builds only support ed25519 keys. Generate one with `ssh-keygen -t ed25519` and deploy it to the router's `authorized_keys`.

## Examples

- `examples/entware-only/` - Router running Entware only (e.g. MIPS routers without Debian support)
- `examples/entware-plus-debian/` - Router running both Entware and Debian chroot

## Separating framework from config

This repo provides the generic, reusable framework scripts. For managing host-specific configurations (per-router service lists, IP addresses, custom mounts), create a separate config repo organized by hostname:

```
my-ddwrt-config/
  router-a/
    dd-wrt.conf              # STORAGE_DIR, LOG_FILE
    chroot-services.list     # Debian services
    nvram-rc_startup.sh      # Static IP, regulatory domain
    nvram-rc_usb.sh          # USB mount and bootstrap
  router-b/
    dd-wrt.conf
    chroot-services.list
    debian-mounts.sh         # Extra mounts (only if needed)
    nvram-rc_startup.sh
    nvram-rc_usb.sh
  deploy.sh
```

All framework scripts (`dd-wrt.sh`, `debian.sh`, `entware.sh`) stay identical across routers. Only the config files vary per host.

## License

MIT
