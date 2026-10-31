# Container inventory

A quick reference for everything running under `prox`. There are 16 LXC containers and no virtual
machines. Thirteen are normally running; 112, 113 and 118 are stopped.

The table is the summary. The notes below add the details I usually need when I am working on one of
them. Full pages will go into `containers/` one at a time.

| ID | Name | State | OS | vCPU | RAM | Disk | Address | Start order | Backed up |
|---:|---|---|---|---:|---:|---:|---|---:|---|
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

All containers are unprivileged. `Backed up` refers to the Sunday B2 job; `rootfs only` means the
container is in that job but its bind-mounted photo library is not.

## Notes on each container

### CT 100, opencode

This is the development container. It is where I run coding agents and keep working projects, including
the environment that produced these notes. Three cores, 6 GB RAM, 20 GB disk. It sits on the lab network
with a DHCP lease of `10.10.10.162` and has `/mnt/data/public/Downloads` mounted at `/mnt/nas`.

It has `nesting=1` and `keyctl=1`, which several development tools expect. There is no startup order and
it is not in the backup job. That is a gap worth closing at some point, because it holds project data.

### CT 101, npm

Nginx Proxy Manager, used as the reverse proxy. It is small: one core, 512 MB RAM, 4 GB disk. It gets
`10.10.10.200` from DHCP, and the tag on the container records that address even though the interface is
configured with DHCP. It starts first, along with DNS and the router.

The actual proxy hosts and certificates will be documented on its own page.

### CT 102, journal

Hostname `journal`, address `10.10.10.149`, which is also what `journal.lan` resolves to. Two cores, 2 GB
RAM, 8 GB disk. It has the container firewall flag enabled, though the Proxmox firewall as a whole is
disabled. No startup order and no backup.

### CT 103, aria2

Download client. Two cores, 1 GB RAM, 8 GB disk, and a 7 MB/s rate limit on its network interface. It uses
the static address `10.10.10.177`. The Downloads directory is mounted at `/mnt/nas`.

It starts at order 4, after the router and DNS. It is included in the weekly backup.

### CT 104, jellyfin

The media server, running Ubuntu rather than Debian like most of the others. Three cores, 6 GB RAM and
20 GB disk. It has the Intel GPU passed through: `/dev/dri/card1` and `/dev/dri/renderD128`, with explicit
group mappings for gid 44 and gid 993. The media directory is mounted at `/mnt/smb`.

It uses `10.10.10.201` and starts at order 3. It is not backed up, so its configuration and watch state
would have to be rebuilt from scratch.

### CT 105, NAS

A small Alpine container acting as a Samba server on the main LAN. One core, 512 MB RAM, 2 GB disk. It has
the static address `192.168.0.10` and the entire `/mnt/data` mounted at `/srv/samba`.

It starts at order 3 and is backed up. The backup only contains the root filesystem; the share itself is a
bind mount and is not in the archive.

### CT 106, openwrt

The router for the lab network. One core, 256 MB RAM, 4 GB disk, OpenWrt as an unmanaged container type.
It has two interfaces: `eth0` on `vmbr0` with the static address `192.168.0.150`, and `eth1` on `vmbr1` at
`10.10.10.1`.

It routes between the lab and the house LAN and provides DHCP and DNS forwarding for every `10.10.10.x`
container. If it is down, those containers lose their route to the house LAN and the internet. It starts
first and is backed up. The firewall config on CT 106 does not load, so the lab is routed rather than
NATed; the [CT 106 page](../containers/106-openwrt.md) has the details.

### CT 107, adguard

AdGuard Home, providing DNS filtering for the LAN. One core, 1 GB RAM, 4 GB disk. The container config
gives it `192.168.0.146`. The address clients use, `192.168.0.147`, is a keepalived VIP shared with the
Pi at `192.168.0.169`. CT 107 is MASTER, the Pi is BACKUP, and `adguardhome-sync` copies the AdGuard
configuration to the Pi every two hours.

It starts first and is backed up. DNS is the first dependency for almost everything else, which is why I
documented this one before the rest. The full page is [../containers/107-adguard.md](../containers/107-adguard.md).

### CT 108, zerobyte

Zerobyte, a restic-based backup service. Two cores, 6 GB RAM, 10 GB disk. It uses `10.10.10.230` from
DHCP and mounts the Immich directory at `/mnt/nas`.

It has no startup order and is not backed up. An old `vzdump-qemu-108` log from May suggests this ID used
to be a virtual machine.

### CT 109, immich

The Immich photo server. Four cores, 6 GB RAM, 20 GB disk. The photo library lives on `/mnt/data/public/immich`
and is mounted at `/mnt/nas`. The GPU devices are passed through as well, with gid 992 for `renderD128`
and gid 44 for `card1`.

It starts at order 3. The root filesystem is in the weekly backup, but the photo library is not, because
vzdump skips bind mounts. The separate Immich backup scripts on the host are supposed to cover the library,
but I still need to confirm their schedule.

### CT 110, tailscale-LXC

Tailscale node on the main LAN at `192.168.0.5`. One core, 512 MB RAM, 4 GB disk and `/dev/net/tun`
passed through. It starts at order 2 and is backed up.

I have not confirmed yet whether it advertises subnet routes, acts as an exit node, or both.

### CT 111, filebrowser

Web file browser. One core, 512 MB RAM, 8 GB disk. It gets `10.10.10.144` from DHCP and mounts the whole
data disk at `/mnt/smb`, plus a small upload staging directory.

It has no startup order and is not backed up.

### CT 112, libre-webui

Stopped. Two cores, 2 GB RAM, 12 GB disk, Debian. It was used for a LibreWebUI chat front-end. Autostart
is disabled and it is not backed up. This container is skipped at the owner's request.

### CT 113, warp-exit

Stopped. One core, 512 MB RAM, 4 GB disk, static `10.10.10.135`, with `/dev/net/tun` passed through. It
was the Cloudflare WARP exit node. Autostart is off and it is not backed up. This container is skipped at
the owner's request.

### CT 118, tg-proxy

Stopped. One core, 512 MB RAM, 4 GB disk. It is dual-homed: `10.10.10.218` on the lab network and
`192.168.0.218` on the main LAN, with TUN passed through. It was a Telegram proxy. Autostart is off and it
is not backed up. This container is skipped at the owner's request.

### CT 119, monitoring

Docker host for the monitoring stack. Two cores, 2 GB RAM, 10 GB disk, address `10.10.10.246` from DHCP.
The container tags mention Docker and community scripts.

It starts without an order and is not backed up, which is not ideal if it holds Grafana dashboards and
Prometheus configuration. I will confirm what is actually running on it in its own page.

## Mounts from the host

| Container | Host path | Path inside |
|---:|---|---|
| 100 | `/mnt/data/public/Downloads` | `/mnt/nas` |
| 103 | `/mnt/data/public/Downloads` | `/mnt/nas` |
| 104 | `/mnt/data/public/Downloads` | `/mnt/smb` |
| 105 | `/mnt/data` | `/srv/samba` |
| 108 | `/mnt/data/public/immich` | `/mnt/nas` |
| 109 | `/mnt/data/public/immich` | `/mnt/nas` |
| 111 | `/mnt/data` | `/mnt/smb` |
| 111 | `/mnt/data/public/.filebrowser-tmp` | `/usr/local/community-scripts/tmp` |

All of these are bind mounts, so none of them are included in a container dump.

## Device passthrough

CT 104 and CT 109 have the Intel GPU. CT 106, 110, 113 and 118 have `/dev/net/tun`. CT 106 has no VPN
package or process using it, so that passthrough looks left over.

One small inconsistency: `renderD128` is mapped to gid 993 in CT 104 but gid 992 in CT 109. It may be
correct on the host, but I want to check it when I do those pages.

## Resource picture

The running containers add up to 24 vCPU and about 32 GiB of RAM in limits. The host has 4 threads and
15 GiB. That is fine as long as the limits are treated as ceilings, but it is easy to oversubscribe in
practice. Jellyfin, Immich and the dev container are the ones most likely to be busy at the same time.

The stopped containers still have 20 GB of thin volumes allocated. They do not use CPU or RAM while
stopped, but they do count against the pool.

## Loose ends

- Nine containers are not in the backup job: 100, 102, 104, 108, 111, 112, 113, 118 and 119. That selection
  is deliberate.
- CT 100, 102, 108, 111 and 119 have no startup order.
- The lab network still depends on CT 106. DNS is a CT 107 + Pi keepalived pair, so it is not a single
  point of failure, although the Pi can be up to two hours behind on configuration. CT 106 routes the lab
  subnet but is not currently NATing it.
- Some static addresses sit inside the OpenWrt DHCP pool with no reservations.
- The 114–117 IDs are unused.
