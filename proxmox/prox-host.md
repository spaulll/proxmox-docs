# prox, the Proxmox host

`prox` is the main machine in the homelab. It is a standalone Proxmox VE node: no Proxmox cluster, no
Proxmox HA, no shared storage. Everything else, apart from the Pi, runs on it as an LXC container. The
one bit of failover in the setup is the DNS VIP shared with the Pi, and that is handled by keepalived on
CT 107 and the Pi, not by Proxmox.

I checked the host over SSH on 2026-10-31. It had been up for about four days at that point. This page
describes what is actually installed and configured, not what was planned.

## Identity and access

| | |
|---|---|
| Hostname | `prox.lan` (node name `prox`) |
| Address | `192.168.0.50/24`, gateway `192.168.0.1` |
| Web UI | `https://192.168.0.50:8006` |
| SSH | `ssh root@prox.lan`, port 22 |
| OS | Debian 13 (trixie) |
| Proxmox | `proxmox-ve 9.2.0`, `pve-manager 9.2.21` |
| Kernel | `7.0.14-20-pve` |
| Time | `Asia/Kolkata`, NTP via chrony |
| Subscription | none, using the `pve-no-subscription` repo |

The web UI uses the default self-signed certificate (`CN=prox.lan`), issued by the local PVE CA and valid
until 2035. There is no ACME setup.

Only one Proxmox user exists, `root@pam`. A few API tokens are in use for small devices and a dashboard,
but token values are not recorded here. SSH accepts both keys and passwords for root.

The node has Wake-on-LAN configured with MAC `00:23:24:c7:1f:5d`, and the NIC has WoL enabled. I have
used that before to bring the machine back after a power cut.

## Hardware

It is a Lenovo ThinkCentre M900, machine type `10FM0022US`, serial `MJ04QE4U`. Small desktop, one NIC,
one Wi-Fi card that is not used.

- CPU: Intel Core i5-6500T, 4 cores and 4 threads, 2.5 GHz base, 3.1 GHz turbo.
- RAM: 16 GB, two 8 GB DDR4-2133 sticks, non-ECC.
- NIC: `eno1`, gigabit, link up.
- Wi-Fi: `wlp1s0`, present but left unconfigured.
- BIOS: `FWKT5FA` from 2016. Secure Boot is off and there is no TPM 2.0 support.

### Disks

| Device | Model | Size | What it is used for |
|---|---|---|---|
| `/dev/sda` | Crucial CT240BX500SSD1 | 223.6 GB | Proxmox boot, LVM, all container root filesystems |
| `/dev/sdb` | Matrix 512GB | 476.9 GB | `/mnt/data`, connected over USB through a JMicron bridge |
| `/dev/zram0` | zram | 3.9 GB | Compressed swap |

`/dev/sda` is a SATA SSD. SMART is clean: 14,949 power-on hours, 51 °C, no reallocated or pending sectors.

`/dev/sdb` is the important one to watch. It reports 16,881 hours, 40 °C and an overall PASSED status, but
it also has **3 current pending sectors**. `smartd` has been logging that every 30 minutes. The count has
not moved while I have been looking, but pending sectors are worth taking seriously, especially on a
single USB-attached disk with no mirror.

`lsblk` reports `ROTA=1` for `sdb`, although the SMART attributes (wear levelling and reallocated sector
counters) look like flash media. The USB bridge is probably reporting the wrong rotational flag.

Temperatures at capture: CPU package 54 °C, cores 51–53 °C, `sda` 51 °C, `sdb` 40 °C. Nothing alarming.

There is no UPS daemon installed on the host (no NUT or apcupsd) and no USB UPS was visible. The UPS is
handled outside Proxmox by the ESP32/Pi monitor described in [../services/ups.md](../services/ups.md).
The host only runs the small shutdown receiver that the ESP32 calls.

## Storage

Proxmox has two storage entries:

```text
dir: local
        path /var/lib/vz
        content iso,vztmpl,backup

lvmthin: local-lvm
        thinpool data
        vgname pve
        content rootdir,images
```

`local` is a directory on the root filesystem for ISOs, LXC templates and dumps. `local-lvm` is the thin
pool where container root filesystems live. There is no ZFS, Ceph, NFS, SMB or PBS storage configured.

The boot SSD is split like this:

```text
sda 223.6G
├─sda1   1007K  BIOS boot
├─sda2      1G  /boot/efi
└─sda3  222.6G  LVM physical volume (VG pve)
   ├─pve-swap     7.65G
   ├─pve-root    65.73G  ext4, mounted at /
   └─pve-data   130.53G  thin pool for containers
```

At the time of writing the thin pool was 66 % used for data and 3.4 % for metadata. The volume group had
about 16 GB unallocated. There are 122 GB of root filesystems provisioned across the running containers,
plus another 20 GB for the three stopped ones, so the pool is overcommitted on paper. Actual usage is
what matters, and that was around 86 GB.

`/mnt/data` is a plain ext4 filesystem on `sdb`, not a Proxmox storage entry. It is bind-mounted into
several containers. The mount options are `noatime,nofail,errors=continue`, so a missing disk will not
stop the host from booting.

Space at capture:

| Mount | Size | Used | Free |
|---|---:|---:|---:|
| `/` | 65 GB | 40 GB (65 %) | 22 GB |
| `/mnt/data` | 469 GB | 305 GB (69 %) | 140 GB |
| `/boot/efi` | 1 GB | 9 MB | 1 GB |

The root filesystem is the tightest part of the host. Most of the usage is `/var/lib/vz` (24 GB), of which
11 GB is ISOs and templates and 14 GB is old dumps. The systemd journal is another 3 GB, and the APT cache
is 1.4 GB. I have not deleted anything.

What is on the data disk:

| Path | Size | Notes |
|---|---:|---|
| `/mnt/data/public/Downloads` | 224 GB | Media library and downloads |
| `/mnt/data/public/immich` | 55 GB | Immich photo library |
| `/mnt/data/public/backups` | 21 GB | 5 GB of B2 staging plus a 16 GB Windows VM dump from May |
| `/mnt/data/private` | 6.4 GB | Private files, not shared with containers |
| `/mnt/data/public/syncthing` | 37 MB | Syncthing data |
| `/mnt/data/public/NVR` | 44 KB | Empty |

## Network

The host is on the main LAN and also has two internal bridges. `vmbr0` is the real LAN. `vmbr1` is an
isolated bridge for the lab network, with no IP address on the host. `vmbr2` exists but has no ports and is
not used; the comment in the config says `#opnsense-lan`, so it is probably left over from an earlier plan.

| Bridge | Address on host | Connected to |
|---|---|---|
| `vmbr0` | `192.168.0.50/24` | `eno1`, physical LAN |
| `vmbr1` | none | internal `10.10.10.0/24` lab network |
| `vmbr2` | none | nothing |

The lab network is routed by CT 106, an OpenWrt container. It has one interface on `vmbr0` with the static
address `192.168.0.150`, and one on `vmbr1` at `10.10.10.1`. All the `10.10.10.x` containers use it as
gateway, DHCP server and DNS forwarder. The host has no address on `vmbr1`, but it can still reach the lab
through the main router's route for `10.10.10.0/24`; it normally manages the containers with `pct`.

CT 106's firewall configuration does not currently load, and no NAT is active. The lab is a routed subnet,
not a second NAT layer. I left it alone; [../containers/106-openwrt.md](../containers/106-openwrt.md) has
the detail.

DNS for the host is `192.168.0.147`. That address is a keepalived VIP shared by CT 107 and the Pi. CT 107
has the real address `192.168.0.146` and is the MASTER, with priority 100. The Pi is at `192.168.0.169`
and is the BACKUP, with priority 50. Both run AdGuard Home, and CT 107 syncs its configuration to the Pi
every two hours. The host's resolver therefore survives CT 107 going down, as long as the Pi is up and has
taken the VIP. OpenWrt forwards lab DNS to `.147` as well.

The public egress IP at capture was `103.188.163.113`. There is no IPv6 beyond link-local, and no VLANs.

There is no Proxmox firewall policy configured. `pve-firewall` is running but disabled. The individual
`firewall=1` flags on some containers therefore do nothing. That is fine for the current single-user LAN,
but it is worth remembering when reading the container configs.

Cloudflare WARP is installed on the host, but the tunnel is manually disconnected. There is a separate
`warp-exit` container (CT 113) for that job, currently stopped. The host package looks like a leftover.

### `/etc/network/interfaces`

```text
auto lo
iface lo inet loopback

iface eno1 inet manual
iface wlp1s0 inet manual

auto vmbr0
iface vmbr0 inet static
        address 192.168.0.50/24
        gateway 192.168.0.1
        bridge-ports eno1
        bridge-stp off
        bridge-fd 0
#main-lan

auto vmbr1
iface vmbr1 inet manual
        bridge-ports none
        bridge-stp off
        bridge-fd 0
#openwrt

auto vmbr2
iface vmbr2 inet manual
        bridge-ports none
        bridge-stp off
        bridge-fd 0
#opnsense-lan
```

## Containers

There are 16 LXC containers and no virtual machines. Thirteen are normally running. The three stopped ones
are 112 (`libre-webui`), 113 (`warp-exit`) and 118 (`tg-proxy`), and all three have autostart disabled.

The running containers have 24 vCPU and about 32 GiB of RAM allocated in total, against 4 threads and
15 GiB of physical RAM. Those are limits rather than reservations, so it is not as bad as it looks, but a
busy moment in Jellyfin, Immich and the dev container at the same time can push the host into swap.

Startup order is set for the infrastructure pieces:

- order 1: CT 101 `npm`, CT 106 `openwrt`, CT 107 `adguard`
- order 2: CT 110 `tailscale`
- order 3: CT 104 `jellyfin`, CT 105 `NAS`, CT 109 `immich`
- order 4: CT 103 `aria2`

CT 100, 102, 108, 111 and 119 have no startup order. That means they can start before DNS or the internal
router is ready, which is usually harmless but can produce noisy logs on boot.

The full list, with addresses and mounts, is in [guest-inventory.md](guest-inventory.md).

## Services and scheduled work

The Proxmox stack itself is the usual set: `pve-cluster`, `pvedaemon`, `pveproxy`, `spiceproxy`,
`pve-firewall` and the LXC services.

Beyond that:

- `lxc-backup-b2.sh` runs from root's crontab every Sunday at 03:00. It dumps seven containers and uploads
  them to Backblaze B2. It is described in [../operations/backups.md](../operations/backups.md).
- `lxc-backup-resume.service` runs at boot, waits 45 seconds and resumes an interrupted backup if a state
  file is still present.
- `smartd` watches the disks and mails root on problems.
- `chrony` keeps time. `systemd-zram-generator` creates the compressed swap. `sysstat` records CPU and I/O
  history. `postfix` only listens on localhost, and its queue is empty.
- `pve-daily-update.timer` refreshes package lists once a day. Unattended upgrades are not configured.
- `shutdown-webhook.service` listens on port 9999. It is the local receiver the ESP32 calls when the UPS
  monitor decides the node should go down. The service is separate from the Proxmox API.

`fail2ban` is not installed. The host has 58 pending package updates at the moment, mostly Debian security
updates.

## Backups

There are no native Proxmox backup jobs. The weekly script is the only automated protection. It covers
CT 107, 101, 106, 105, 103, 110 and 109. The other nine containers are not backed up.

One important detail: `vzdump` does not include bind mounts. The media and photo directories under
`/mnt/data` are not inside any container archive, even for the containers that are backed up. They need
their own protection. The Immich scripts are cloned on the host at `/immich-b2-backup`, but I did not find
a host cron entry or timer for them yet.

The full picture, including how to restore, is in [../operations/backups.md](../operations/backups.md).

## Health and capacity

At capture:

- CPU load was 0.24, memory had 9.6 GB available, and swap usage was 221 MB out of 11 GB.
- No systemd units had failed.
- The only recurring log message was the `sdb` pending-sector warning.
- `/` was 65 % full, `/mnt/data` 69 %, the thin pool 66 %.

The host is not under pressure right now. The two things I would keep an eye on are the USB data disk and
the root filesystem. The root disk has 22 GB free, which is enough for normal operation but not much room
for new dumps. The old dumps and the 16 GB Windows VM image are the obvious things to clean up if space is
needed later.

## Common commands

I keep these here because I always end up looking them up.

```bash
ssh root@prox

pveversion -v
pct list
qm list
pvesh get /nodes/prox/status
df -hT
free -h
```

Container work:

```bash
pct status 109
pct start 109
pct shutdown 109
pct stop 109              # only if graceful shutdown hangs
pct enter 109
pct config 109
pct exec 109 -- systemctl status <service>
```

Backups:

```bash
/usr/local/bin/lxc-backup-b2.sh
tail -f /var/log/lxc-backup-b2.log
ls -lh /mnt/data/public/backups/lxc/*.tar.zst
```

Disks:

```bash
smartctl -H -A /dev/sda
smartctl -H -A -x /dev/sdb
journalctl -u smartd -n 50
```

Logs and updates:

```bash
journalctl -xe
journalctl -u pveproxy -u pvedaemon --since today
apt update
apt list --upgradable
```

Network changes are applied with `ifreload -a` after editing `/etc/network/interfaces`. That briefly
disrupts networking, so I do not run it unless I have to.

Shutdown and boot:

```bash
shutdown -h now
reboot
wakeonlan 00:23:24:c7:1f:5d
```

## Config files

### `/etc/pve/datacenter.cfg`

```text
keyboard: en-us
```

### `/etc/pve/storage.cfg`

```text
dir: local
        path /var/lib/vz
        content iso,vztmpl,backup

lvmthin: local-lvm
        thinpool data
        vgname pve
        content rootdir,images
```

### `/etc/fstab`

```text
/dev/pve/root / ext4 errors=remount-ro 0 1
UUID=333A-3A31 /boot/efi vfat defaults 0 1
/dev/pve/swap none swap sw 0 0
proc /proc proc defaults 0 0
UUID=f7877dd9-6975-4cd5-81be-7ee861897164  /mnt/data  ext4  defaults,noatime,nofail,errors=continue  0  2
```

### `/etc/sysctl.d`

```text
vm.swappiness = 10
```

### zram

```text
/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 0.25
compression-algorithm = zstd
swap-priority = 100
```

### Root crontab

```text
0 3 * * 0 /usr/local/bin/lxc-backup-b2.sh
```

### Backup resume unit

```text
/etc/systemd/system/lxc-backup-resume.service

[Unit]
Description=Resume interrupted LXC-to-B2 backup run (if any)
After=network-online.target pve-guests.service
Wants=network-online.target
ConditionPathExists=/var/lib/lxc-backup/run.state

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 45
ExecStart=/usr/local/bin/lxc-backup-b2.sh
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

## Changes to this page

| Date | Change |
|---|---|
| 2026-10-31 | First version, from a live read-only inspection |
| 2026-10-31 | Rewritten in a plainer style; shutdown receiver documented in the UPS page |
