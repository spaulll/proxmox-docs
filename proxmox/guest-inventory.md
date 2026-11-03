# Container inventory

Quick reference for everything under `prox`. 16 LXC containers, no VMs. Thirteen normally run; 112, 113, 118 are stopped.

The table is the summary. The notes add the details I usually need when working on one. Full pages go into `containers/` one at a time.

| ID | Name | State | OS | vCPU | RAM | Disk | Address | Start order | Backed up |
|---|---|---|---|---|---|---|---|---|---|
| 100 | `opencode` | running | Debian | 3 | 6 GB | 20 GB | `10.10.10.162` (DHCP) | — | no |
| 101 | `npm` | running | Debian | 1 | 512 MB | 4 GB | `10.10.10.200` (DHCP) | 1 | yes |
| 102 | `journal` | running | Debian | 2 | 2 GB | 8 GB | `10.10.10.149` (DHCP) | — | no |
| 103 | `aria2` | running | Debian | 2 | 1 GB | 8 GB | `10.10.10.177` (static) | 4 | yes |
| 104 | `jellyfin` | running | Ubuntu | 3 | 6 GB | 20 GB | `10.10.10.201` (static) | 3 | no |
| 105 | `NAS` | running | Alpine | 1 | 512 MB | 2 GB | `192.168.0.10` (static) | 3 | yes |
| 106 | `openwrt` | running | OpenWrt | 1 | 256 MB | 4 GB | `192.168.0.150` (static), `10.10.10.1` | 1 | yes |
| 107 | `adguard` | running | Debian | 1 | 1 GB | 4 GB | `192.168.0.146`, VIP `.147` | 1 | yes |
| 108 | `zerobyte` | running | Debian | 2 | 6 GB | 10 GB | `10.10.10.230` (DHCP) | — | no |
| 109 | `immich` | running | Debian | 4 | 6 GB | 20 GB | `10.10.10.234` (DHCP) | 3 | rootfs only |
| 110 | `tailscale-LXC` | running | Debian | 1 | 512 MB | 4 GB | `192.168.0.5` (static) | 2 | yes |
| 111 | `filebrowser` | running | Debian | 1 | 512 MB | 8 GB | `10.10.10.144` (DHCP) | — | no |
| 112 | `libre-webui` | stopped | Debian | 2 | 2 GB | 12 GB | DHCP when started | off | no |
| 113 | `warp-exit` | stopped | Debian | 1 | 512 MB | 4 GB | `10.10.10.135` (static) | off | no |
| 118 | `tg-proxy` | stopped | Debian | 1 | 512 MB | 4 GB | `10.10.10.218`, `192.168.0.218` | off | no |
| 119 | `monitoring` | running | Debian | 2 | 2 GB | 10 GB | `10.10.10.246` (DHCP) | — | no |

All containers are unprivileged. `Backed up` refers to the Sunday B2 job; `rootfs only` means the container is in the job but its bind-mounted photo library is not.

## Notes on each container

### CT 100, opencode

The development container. Where I run coding agents and keep working projects — including the environment that produced these notes. Three cores, 6 GB RAM, 20 GB disk. Lab network, DHCP at `10.10.10.162`, `/mnt/data/public/Downloads` mounted at `/mnt/nas`.

`nesting=1` and `keyctl=1`, which dev tools expect. No startup order, not in the backup. That's a gap worth closing — it holds project data.

### CT 101, npm

Nginx Proxy Manager, the reverse proxy. Small: one core, 512 MB RAM, 4 GB disk. Gets `10.10.10.200` from DHCP; the container tag records that address even though the interface is DHCP. Starts first, with DNS and the router.

Proxy hosts and certificates get their own page.

### CT 102, journal

Hostname `journal`, `10.10.10.149` — also what `journal.lan` resolves to. Two cores, 2 GB RAM, 8 GB disk. Container firewall flag enabled, though the Proxmox firewall as a whole is disabled. No startup order, no backup.

### CT 103, aria2

Download client. Two cores, 1 GB RAM, 8 GB disk, 7 MB/s rate limit on the interface. Static `10.10.10.177`. Downloads mounted at `/mnt/nas`.

Starts at order 4, after router and DNS. In the weekly backup.

### CT 104, jellyfin

Media server, Ubuntu (unusual — most are Debian). Three cores, 6 GB RAM, 20 GB disk. Intel GPU passed through: `/dev/dri/card1` and `/dev/dri/renderD128`, with group mappings gid 44 and gid 993. Media mounted at `/mnt/smb`.

`10.10.10.201`, order 3. Not backed up — config and watch state would have to be rebuilt from scratch.

### CT 105, NAS

Small Alpine container acting as a Samba server on the main LAN. One core, 512 MB RAM, 2 GB disk. Static `192.168.0.10`, entire `/mnt/data` mounted at `/srv/samba`.

Order 3, backed up. But the backup only holds the root filesystem; the share is a bind mount and isn't in the archive.

### CT 106, openwrt

The lab router. One core, 256 MB RAM, 4 GB disk, unmanaged OpenWrt. Two interfaces: `eth0` on `vmbr0` (static `192.168.0.150`), `eth1` on `vmbr1` (`10.10.10.1`).

Routes between the lab and the house LAN; provides DHCP and DNS forwarding for every `10.10.10.x` container. If it's down, those containers lose their route out. Starts first, backed up. The firewall config doesn't load, so the lab is routed, not NATed. Details: [CT 106 page](../containers/106-openwrt.md).

### CT 107, adguard

AdGuard Home, DNS filtering for the LAN. One core, 1 GB RAM, 4 GB disk. Config gives it `192.168.0.146`. Clients use `192.168.0.147`, a keepalived VIP shared with the Pi (`192.168.0.169`). CT 107 is MASTER, Pi is BACKUP, `adguardhome-sync` copies config to the Pi every two hours.

Starts first, backed up. DNS is the first dependency for almost everything, which is why this was documented first. Full page: [../containers/107-adguard.md](../containers/107-adguard.md).

### CT 108, zerobyte

Zerobyte, a restic-based backup service. Two cores, 6 GB RAM, 10 GB disk. `10.10.10.230` from DHCP, Immich dir mounted at `/mnt/nas`.

No startup order, not backed up. An old `vzdump-qemu-108` log from May suggests this ID used to be a VM.

### CT 109, immich

The Immich photo server. Four cores, 6 GB RAM, 20 GB disk. Photo library on `/mnt/data/public/immich`, mounted at `/mnt/nas`. GPU passed through: gid 992 for `renderD128`, gid 44 for `card1`.

Order 3. Root filesystem is in the weekly backup, the photo library is not (vzdump skips bind mounts). The library is backed up by Zerobyte.

### CT 110, tailscale-LXC

Tailscale node on the main LAN at `192.168.0.5`. One core, 512 MB RAM, 4 GB disk, `/dev/net/tun` passed through. Order 2, backed up.

Not confirmed yet whether it advertises subnet routes, acts as an exit node, or both.

### CT 111, filebrowser

Web file browser. One core, 512 MB RAM, 8 GB disk. `10.10.10.144` from DHCP. Mounts the whole data disk at `/mnt/smb`, plus a small upload staging dir.

No startup order, not backed up.

### CT 112, libre-webui

Stopped. Two cores, 2 GB RAM, 12 GB disk, Debian. Was a LibreWebUI chat front-end. Autostart off, not backed up. Skipped at my request.

### CT 113, warp-exit

Stopped. One core, 512 MB RAM, 4 GB disk, static `10.10.10.135`, `/dev/net/tun` passed through. Was the Cloudflare WARP exit node. Autostart off, not backed up. Skipped at my request.

### CT 118, tg-proxy

Stopped. One core, 512 MB RAM, 4 GB disk. Dual-homed: `10.10.10.218` on the lab, `192.168.0.218` on the main LAN, TUN passed through. Was a Telegram proxy. Autostart off, not backed up. Skipped at my request.

### CT 119, monitoring

Docker host for the monitoring stack. Two cores, 2 GB RAM, 10 GB disk, `10.10.10.246` from DHCP. Tags mention Docker and community scripts.

No startup order, not backed up — not ideal if it holds Grafana dashboards and Prometheus config. Will confirm what's actually running when I get to its page.

## Mounts from the host

| Container | Host path | Path inside |
|---|---|---|
| 100 | `/mnt/data/public/Downloads` | `/mnt/nas` |
| 103 | `/mnt/data/public/Downloads` | `/mnt/nas` |
| 104 | `/mnt/data/public/Downloads` | `/mnt/smb` |
| 105 | `/mnt/data` | `/srv/samba` |
| 108 | `/mnt/data/public/immich` | `/mnt/nas` |
| 109 | `/mnt/data/public/immich` | `/mnt/nas` |
| 111 | `/mnt/data` | `/mnt/smb` |
| 111 | `/mnt/data/public/.filebrowser-tmp` | `/usr/local/community-scripts/tmp` |

All bind mounts. None are in a container dump.

## Device passthrough

CT 104 and 109 have the Intel GPU. CT 106, 110, 113, 118 have `/dev/net/tun`. CT 106 has no VPN package or process using it — that passthrough looks left over.

One inconsistency: `renderD128` is gid 993 in CT 104, gid 992 in CT 109.

## Resource picture

Running containers sum to 24 vCPU and ~32 GiB RAM in limits. The host has 4 threads and 15 GiB. Fine as long as limits are treated as ceilings, but easy to oversubscribe. Jellyfin, Immich, and the dev container are the ones most likely to be busy at once.

Stopped containers still hold 20 GB of thin volumes. No CPU or RAM while stopped, but they count against the pool.

## Known quirks

- Nine containers are not in the backup: 100, 102, 104, 108, 111, 112, 113, 118, 119. That selection is deliberate.
- CT 100, 102, 108, 111, 119 have no startup order.
- The lab depends on CT 106. DNS is a CT 107 + Pi keepalived pair, so it's not a single point of failure — though the Pi can be up to two hours behind on config. CT 106 routes the lab subnet but doesn't NAT it.
- Some static addresses sit inside the OpenWrt DHCP pool with no reservations.
- IDs 114–117 are unused.
