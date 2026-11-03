# Homelab notes

Personal homelab on a single Proxmox node. One host, 16 LXC containers, a Raspberry Pi, and an ESP32 UPS monitor. The house LAN and an internal lab sit behind an OpenWrt container that routes between them. Remote access is Tailscale; external services are fronted by Nginx Proxy Manager.

Everything here was recorded by logging into each box and reading its config — not from memory. All observations are read-only. No passwords or private keys live in this repo; where a credential matters, the notes say where it lives, never what it is.

- **Last full review:** 2026-11-03
- **Status:** all container and service pages written; no outstanding questions

---

## At a glance

| | |
|---|---|
| Host | Lenovo ThinkCentre M900 Tiny (`prox`) |
| Containers | 16 LXC — 13 auto-start, 3 stopped |
| Networks | house `192.168.0.0/24`, lab `10.10.10.0/24` |
| DNS | AdGuard pair behind a keepalived VIP `192.168.0.147` |
| Remote access | Tailscale (subnet router + exit nodes) |
| Backup | 7 containers → Backblaze B2 weekly; Zerobyte covers Immich data |
| Solar dashboard | CT 119 (prod), CT 100 copy (test) |

---

## Host

| | |
|---|---|
| Model | Lenovo ThinkCentre M900 Tiny (10FM0022US) |
| CPU | Intel Core i5-6500T — 4 cores / 4 threads, 2.5 GHz base / 3.1 GHz turbo |
| RAM | 16 GB DDR4-2133 (2 × 8 GB, non-ECC) |
| NIC | `eno1`, gigabit. Wi-Fi card present but unused |
| BIOS | `FWKT5FA` (2016), Secure Boot off, no TPM 2.0 |
| OS | Proxmox VE 9.2.21, kernel 7.0.14-20-pve |
| Guests | 16 LXC containers, no VMs, no cluster, no HA |

### Disks

| Device | Drive | Size | Role |
|---|---|---|
| `/dev/sda` | Crucial CT240BX500SSD1 | 223.6 GB | boot, LVM, all container root filesystems |
| `/dev/sdb` | Matrix 512GB | 476.9 GB | `/mnt/data`, USB-attached (JMicron bridge) |
| `/dev/zram0` | — | 3.9 GB | compressed swap |

`/mnt/data` holds the media library, Immich photos, backup staging, and the private directory. It is the weakest storage point — a single USB-attached drive, no redundancy.

---

## Network

Two networks. The house LAN, `192.168.0.0/24`, carries the host, NAS, AdGuard, Pi, and Tailscale. A private lab, `10.10.10.0/24`, runs behind an OpenWrt container (CT 106). The containers live there.

```
Internet
   │
   ▼
[Asus RT-AX53U  192.168.0.1]   DHCP 10–200, no port forwards
   │  static route: 10.10.10.0/24 → 192.168.0.150
   ▼
192.168.0.0/24  — house LAN
   ├─ prox        .50     # Proxmox host
   ├─ NAS         .10     # CT 105 (Samba/NFS)
   ├─ adguard     .146    # CT 107, keepalived MASTER
   ├─ tailscale   .5      # CT 110, subnet router + exit node
   ├─ openwrt     .150    # CT 106 eth0 (WAN side)
   ├─ Pi          .169    # AdGuard backup, UPS, Tailscale exit, ntfy
   └─ ESP32       .178    # UPS sensor
        │
        ▼  vmbr1 (OpenWrt eth1)
10.10.10.0/24  — lab, routed by CT 106 (no NAT here)
   └─ CT 100–119 LXC containers
```

### Bridges

| Bridge | Host address | Uplink | Used by |
|---|---|---|
| `vmbr0` | `192.168.0.50/24` | `eno1` | 105, 106, 107, 110, 118 |
| `vmbr1` | none | none | lab containers (100–104, 108, 109, 111, 112, 113, 118, 119) |
| `vmbr2` | none | none | unused (leftover `#opnsense-lan` plan) |

The lab is routed, not NATed. The main router carries `10.10.10.0/24` back to `192.168.0.150`, so lab traffic keeps its `10.10.10.x` source address all the way out. There is one NAT layer — on the ISP router.

### Key addresses

| Address | Device | Role |
|---|---|
| `192.168.0.1` | Asus AX53u | router, DHCP 10–200, static route, no port forwards |
| `192.168.0.50` | prox | host UI/SSH |
| `192.168.0.146` / `.147` | CT 107 / VIP | AdGuard MASTER / keepalived VIP |
| `192.168.0.150` | CT 106 | OpenWrt WAN (static) |
| `192.168.0.169` | Raspberry Pi | AdGuard BACKUP, UPS, Tailscale exit |
| `192.168.0.178` | ESP32 | UPS sensor (static) |
| `10.10.10.1` | CT 106 | lab gateway, DHCP, DNS forwarder |

Full details: [network/network-overview.md](network/network-overview.md).

---

## DNS

AdGuard is the resolver for the house LAN and, through OpenWrt, the lab. Two instances share a keepalived VIP:

| Node | Real address | State | Priority |
|---|---|---|---|
| CT 107 (AdGuard) | `192.168.0.146` | MASTER | 100 |
| Raspberry Pi | `192.168.0.169` | BACKUP | 50 |

Clients use the VIP `192.168.0.147`. `adguardhome-sync` copies CT 107's config to the Pi every two hours (deliberate), so the standby can be up to two hours behind. The Pi serves a byte-identical copy of CT 107's TLS cert (`dns.prox.dpdns.org`, Let's Encrypt) — renewal happens on CT 107 and lands on the Pi. Note: keepalived checks the interface, not the AdGuard process, so a crash inside a live container won't fail over.

More: [services/dns.md](services/dns.md).

---

## LXC inventory

Snapshot taken 2026-11-03. Regenerate anytime with `bash operations/lxc-inventory-snapshot.sh` on the host.

| ID | Name | Status | OS | CPU | RAM | Disk | Boot | Bridge | IP | Mounts |
|---|---|---|---|---|---|---|---|---|---|---|
| 100 | opencode | running | debian | 3 | 6144 MB | 20G | yes | vmbr1 | dhcp | /mnt/data/public/Downloads → /mnt/nas |
| 101 | npm | running | debian | 1 | 512 MB | 4G | yes | vmbr1 | dhcp | — |
| 102 | journal | running | debian | 2 | 2048 MB | 8G | yes | vmbr1 | dhcp | — |
| 103 | aria2 | running | debian | 2 | 1024 MB | 8G | yes | vmbr1 | 10.10.10.177/24 (rate=7) | /mnt/data/public/Downloads → /mnt/nas |
| 104 | jellyfin | running | ubuntu | 3 | 6144 MB | 20G | yes | vmbr1 | 10.10.10.201/24 | /mnt/data/public/Downloads/ → /mnt/smb |
| 105 | NAS | running | alpine | 1 | 512 MB | 2G | yes | vmbr0 | 192.168.0.10/24 | /mnt/data/ → /srv/samba |
| 106 | openwrt | running | unmanaged | 1 | 256 MB | 4G | yes | vmbr0+vmbr1 | — | — |
| 107 | adguard | running | debian | 1 | 1024 MB | 4G | yes | vmbr0 | 192.168.0.146/24 | — |
| 108 | zerobyte | running | debian | 2 | 6144 MB | 10G | yes | vmbr1 | dhcp | /mnt/data/public/immich/ → /mnt/nas |
| 109 | immich | running | debian | 4 | 6144 MB | 20G | yes | vmbr1 | dhcp | /mnt/data/public/immich/ → /mnt/nas |
| 110 | tailscale | running | debian | 1 | 512 MB | 4G | yes | vmbr0 | 192.168.0.5/24 | — |
| 111 | filebrowser | running | debian | 1 | 512 MB | 8G | yes | vmbr1 | dhcp | /mnt/data/ → /mnt/smb /mnt/data/public/.filebrowser-tmp → /usr/local/community-scripts/tmp |
| 112 | libre-webui | stopped | debian | 2 | 2048 MB | 12G | no | vmbr1 | dhcp | — |
| 113 | warp-exit | stopped | debian | 1 | 512 MB | 4G | no | vmbr1 | 10.10.10.135/24 | — |
| 118 | tg-proxy | stopped | debian | 1 | 512 MB | 4G | no | vmbr0+vmbr1 | 10.10.10.218/24 192.168.0.218/24 | — |
| 119 | monitoring | running | debian | 2 | 2048 MB | 10G | yes | vmbr1 | dhcp | — |

Per-container pages: [containers/README.md](containers/README.md).

---

## Services

| Service | Summary | Page |
|---|---|---|
| DNS | AdGuard pair + OpenWrt dnsmasq, upstreams, filtering | [services/dns.md](services/dns.md) |
| Reverse proxy | NPM, 14 proxy hosts, Let's Encrypt (custom SSL on `asus.lan`) | [services/reverse-proxy.md](services/reverse-proxy.md) |
| Remote access | Tailscale subnet router + exit nodes, WARP (stopped), Telegram proxy (stopped) | [services/remote-access.md](services/remote-access.md) |
| Media | Jellyfin (GPU transcoding confirmed), aria2, Samba/NFS, filebrowser | [services/media.md](services/media.md) |
| Photos | Immich — library + DB via Zerobyte; ML runs on CPU | [services/photos.md](services/photos.md) |
| Monitoring | solar dashboard on CT 119 (prod) | [services/monitoring.md](services/monitoring.md) |
| UPS | ESP32 sensor + Pi control plane, shutdown/wake path | [services/ups.md](services/ups.md) |
| Backup & restore | B2 weekly script, Zerobyte, restore order | [services/backup-restore.md](services/backup-restore.md) |

---

## Raspberry Pi

At `192.168.0.169` (user `pi`). It is not a standby box — it is the active control plane for several things:

- **AdGuard replica** — keepalived BACKUP for the DNS VIP
- **UPS monitor** — `ups-monitor.service` (reconciler, Telegram, webhook, ntfy); reads the ESP32 and can shut down / wake `prox`
- **Tailscale** — exit node, the power-cut fallback when `prox` is down
- **`dns-redirect.service`** — 302 redirect on 8080 to whichever node holds the DNS VIP
- **ntfy** — notification fallback

Details: [pi/README.md](pi/README.md).

---

## Backup & restore

Two mechanisms:

1. **B2 weekly script** (`lxc-backup-b2.sh`, Sundays 03:00) — dumps and uploads 7 containers to Backblaze B2 (`prox-lxc-backups`, zstd, one archive each). Covered: 107 adguard, 101 npm, 106 openwrt, 105 NAS, 103 aria2, 110 tailscale, 109 immich.
2. **Zerobyte** (CT 108) — restic-based; covers the LXC backup files and the Immich photo library + database, targeting B2.

Deliberately unbacked: media (replaceable), `/mnt/data/private` (no important data), CT 100 projects, journal DB, Jellyfin config, solar DB. A test restore was performed 2026-11-03 and verified working.

More: [operations/backups.md](operations/backups.md), [services/backup-restore.md](services/backup-restore.md).

---

## Document index

| Document | What it's for |
|---|---|
| [proxmox/prox-host.md](proxmox/prox-host.md) | the host: hardware, disks, network, services, commands |
| [proxmox/guest-inventory.md](proxmox/guest-inventory.md) | quick reference for all containers, addresses, mounts |
| [network/network-overview.md](network/network-overview.md) | LAN + lab layout, routing, DNS, bridges |
| [operations/backups.md](operations/backups.md) | backup script, coverage, restore drills |
| [operations/lxc-inventory-snapshot.sh](operations/lxc-inventory-snapshot.sh) | read-only generator for the LXC inventory table |
| [containers/README.md](containers/README.md) | index + per-container pages |
| [services/README.md](services/README.md) | index + cross-cutting service pages |
| [pi/README.md](pi/README.md) | the Pi: DNS, UPS, Tailscale roles |

---

## How this repo is kept

- Every page was produced from a live, read-only inspection of the boxes. Nothing was modified on any container or the Pi.
- Credentials are never copied here. If a config holds a secret, the page says where it lives and omits the value.
- Security is kept simple on purpose — this is a single-user trusted LAN.
