# prox, the Proxmox host

`prox` is the main machine. Standalone Proxmox VE node. No cluster, no HA, no shared storage. Everything except the Pi runs on it as an LXC container. The only failover is the DNS VIP shared with the Pi, handled by keepalived on CT 107 and the Pi — not by Proxmox.

Checked over SSH on 2026-10-31. Up about four days at that point. This page records what's actually installed and configured, not what was planned.

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
| Subscription | none, `pve-no-subscription` repo |

Web UI uses the default self-signed cert (`CN=prox.lan`) from the local PVE CA, valid until 2035. No ACME.

One user, `root@pam`. A few API tokens exist for small devices and a dashboard; token values aren't recorded here. SSH accepts keys and passwords for root.

Wake-on-LAN is configured (MAC `00:23:24:c7:1f:5d`). Used before to bring the box back after a power cut.

## Hardware

Lenovo ThinkCentre M900, type `10FM0022US`, serial `MJ04QE4U`. Small desktop, one NIC, one unused Wi-Fi card.

- CPU: Intel Core i5-6500T, 4 cores / 4 threads, 2.5 GHz base, 3.1 GHz turbo
- RAM: 16 GB, two 8 GB DDR4-2133, non-ECC
- NIC: `eno1`, gigabit, link up
- Wi-Fi: `wlp1s0`, present, unconfigured
- BIOS: `FWKT5FA` (2016). Secure Boot off, no TPM 2.0

### Disks

| Device | Model | Size | Used for |
|---|---|---|
| `/dev/sda` | Crucial CT240BX500SSD1 | 223.6 GB | Proxmox boot, LVM, all container root filesystems |
| `/dev/sdb` | Matrix 512GB | 476.9 GB | `/mnt/data`, USB via JMicron bridge |
| `/dev/zram0` | zram | 3.9 GB | compressed swap |

`/dev/sda` is SATA SSD. SMART clean: 14,949 hours, 51 °C, no reallocated or pending sectors.

`/dev/sdb` is the one to watch. 16,881 hours, 40 °C, overall PASSED — but **3 current pending sectors**. `smartd` logs them every 30 minutes. The count hasn't moved, but pending sectors matter on a single USB disk with no mirror.

`lsblk` says `ROTA=1` for `sdb`, though the SMART attributes look like flash. The USB bridge is probably reporting the wrong rotational flag.

Temps at capture: CPU 54 °C, cores 51–53, `sda` 51, `sdb` 40. Nothing alarming.

No UPS daemon on the host (no NUT, no apcupsd), and no USB UPS visible. The UPS is handled outside Proxmox by the ESP32/Pi monitor ([../services/ups.md](../services/ups.md)). The host only runs the small shutdown receiver the ESP32 calls.

## Storage

Two storage entries:

```text
dir: local
        path /var/lib/vz
        content iso,vztmpl,backup

lvmthin: local-lvm
        thinpool data
        vgname pve
        content rootdir,images
```

`local` is a directory on root for ISOs, templates, dumps. `local-lvm` is the thin pool for container root filesystems. No ZFS, Ceph, NFS, SMB, or PBS.

Boot SSD layout:

```text
sda 223.6G
├─sda1   1007K  BIOS boot
├─sda2      1G  /boot/efi
└─sda3  222.6G  LVM PV (VG pve)
   ├─pve-swap     7.65G
   ├─pve-root    65.73G  ext4, /
   └─pve-data   130.53G  thin pool for containers
```

Thin pool: 66 % data, 3.4 % metadata. ~16 GB unallocated in the VG. 122 GB root filesystems provisioned across running containers, another 20 GB for the three stopped ones — overcommitted on paper. Actual usage ~86 GB.

`/mnt/data` is plain ext4 on `sdb`, not a Proxmox storage entry. Bind-mounted into several containers. Options: `noatime,nofail,errors=continue` — a missing disk won't block boot.

Space at capture:

| Mount | Size | Used | Free |
|---|---:|---:|---:|
| `/` | 65 GB | 40 GB (65 %) | 22 GB |
| `/mnt/data` | 469 GB | 305 GB (69 %) | 140 GB |
| `/boot/efi` | 1 GB | 9 MB | 1 GB |

Root is the tightest part. Most usage is `/var/lib/vz` (24 GB): 11 GB ISOs/templates, 14 GB old dumps. Journal is another 3 GB, APT cache 1.4 GB. Nothing deleted yet.

Data disk contents:

| Path | Size | Notes |
|---|---:|---|
| `/mnt/data/public/Downloads` | 224 GB | media library and downloads |
| `/mnt/data/public/immich` | 55 GB | Immich photo library |
| `/mnt/data/public/backups` | 21 GB | 5 GB B2 staging + 16 GB Windows VM dump (May) |
| `/mnt/data/private` | 6.4 GB | private, not shared with containers |
| `/mnt/data/public/syncthing` | 37 MB | Syncthing data |
| `/mnt/data/public/NVR` | 44 KB | empty |

## Network

Host is on the main LAN with two internal bridges. `vmbr0` is the real LAN. `vmbr1` is the isolated lab bridge, no host address. `vmbr2` exists, no ports, unused — comment says `#opnsense-lan`, probably left over from an earlier plan.

| Bridge | Address on host | Connected to |
|---|---|
| `vmbr0` | `192.168.0.50/24` | `eno1`, physical LAN |
| `vmbr1` | none | internal `10.10.10.0/24` |
| `vmbr2` | none | nothing |

The lab is routed by CT 106 (OpenWrt). It has one interface on `vmbr0` at `192.168.0.150`, one on `vmbr1` at `10.10.10.1`. All `10.10.10.x` containers use it as gateway, DHCP, and DNS forwarder. The host has no address on `vmbr1` but reaches the lab via the main router's route; it manages containers with `pct`.

CT 106's firewall config doesn't load and no NAT is active. The lab is a routed subnet, not a second NAT layer. Left alone. See [../containers/106-openwrt.md](../containers/106-openwrt.md).

Host DNS is `192.168.0.147`, a keepalived VIP shared by CT 107 and the Pi. CT 107 (`192.168.0.146`) is MASTER, priority 100. The Pi (`192.168.0.169`) is BACKUP, priority 50. Both run AdGuard Home; CT 107 syncs config to the Pi every two hours. The host's resolver survives CT 107 going down if the Pi is up and holds the VIP. OpenWrt forwards lab DNS to `.147` too.

Public egress IP at capture: `103.188.163.113`. No IPv6 beyond link-local, no VLANs.

No Proxmox firewall policy. `pve-firewall` runs but is disabled. The per-container `firewall=1` flags do nothing. Fine for a single-user LAN, but worth remembering when reading container configs.

Cloudflare WARP is installed on the host but disconnected. The dedicated `warp-exit` container (CT 113) is stopped. The host package looks like a leftover.

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

16 LXC containers, no VMs. Thirteen normally run. The stopped ones are 112 (`libre-webui`), 113 (`warp-exit`), 118 (`tg-proxy`) — all autostart disabled.

Running containers sum to 24 vCPU and ~32 GiB RAM against 4 threads and 15 GiB physical. Those are limits, not reservations, so it's not as bad as it looks. But Jellyfin, Immich, and the dev container all being busy at once can push the host into swap.

Startup order is set for infrastructure:

- order 1: CT 101 `npm`, 106 `openwrt`, 107 `adguard`
- order 2: CT 110 `tailscale`
- order 3: CT 104 `jellyfin`, 105 `NAS`, 109 `immich`
- order 4: CT 103 `aria2`

CT 100, 102, 108, 111, 119 have no order. They can start before DNS or the router is ready — usually harmless, but noisy logs on boot.

Full list with addresses and mounts: [guest-inventory.md](guest-inventory.md).

## Services and scheduled work

Standard stack: `pve-cluster`, `pvedaemon`, `pveproxy`, `spiceproxy`, `pve-firewall`, LXC services.

Beyond that:

- `lxc-backup-b2.sh` — root crontab, Sunday 03:00. Dumps seven containers, uploads to Backblaze B2. See [../operations/backups.md](../operations/backups.md).
- `lxc-backup-resume.service` — at boot, waits 45 s, resumes an interrupted backup if a state file exists.
- `smartd` — watches disks, mails root on problems.
- `chrony` — time. `systemd-zram-generator` creates swap. `sysstat` records CPU/I/O. `postfix` listens on localhost only, queue empty.
- `pve-daily-update.timer` — refreshes package lists daily. No unattended upgrades.
- `shutdown-webhook.service` — listens on 9999. The local receiver the ESP32 calls when the UPS monitor decides the node should go down. Separate from the Proxmox API.

No `fail2ban`. 58 pending package updates, mostly Debian security.

## Backups

No native Proxmox backup jobs. The weekly script is the only automated protection. It covers CT 107, 101, 106, 105, 103, 110, 109. The other nine aren't backed up.

`vzdump` does not include bind mounts. Media and photos under `/mnt/data` are not in any container archive, even for backed-up containers. They need their own protection. Immich scripts are cloned at `/immich-b2-backup`, but I found no host cron entry or timer for them yet.

Full picture, including restore: [../operations/backups.md](../operations/backups.md).

## Health and capacity

At capture:

- CPU load 0.24, 9.6 GB memory available, 221 MB swap used out of 11 GB
- no failed systemd units
- the only recurring log message was the `sdb` pending-sector warning
- `/` 65 % full, `/mnt/data` 69 %, thin pool 66 %

Not under pressure. The two things to watch: the USB data disk and root filesystem. Root has 22 GB free — enough for normal use, not much for new dumps. The old dumps and the 16 GB Windows image are the obvious cleanup targets if space gets tight.

## Common commands

The ones I keep looking up.

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

Network changes are applied with `ifreload -a` after editing `/etc/network/interfaces`. That briefly disrupts networking, so I don't run it unless I have to.

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
| 2026-11-02 | Rewritten in my own voice |
