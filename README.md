# Homelab notes

This is the documentation for my home setup: one Proxmox host (`prox`), the containers running on it,
and a Raspberry Pi. I wrote it by logging into each machine and reading the actual configuration, not
from memory or from an old diagram.

A few ground rules for this repo:

- No passwords, API keys, token values, private keys or other secrets. If a credential matters, the docs
  say where it lives, never what it is.
- Everything here was collected read-only. I did not change a service, a config file or a container to
  produce these notes.
- The setup is a trusted single-user LAN. Security is intentionally kept simple, so the notes record how
  things are rather than prescribing a hardening project.

Last full review: 2026-10-31.

## What is in here

| Document | What it is for |
|---|---|
| [proxmox/prox-host.md](proxmox/prox-host.md) | The Proxmox host itself: hardware, disks, network, services and the commands I use most |
| [proxmox/guest-inventory.md](proxmox/guest-inventory.md) | Quick reference for all 16 containers, including addresses and mounts |
| [network/network-overview.md](network/network-overview.md) | How the LAN and the internal lab network fit together |
| [operations/backups.md](operations/backups.md) | What gets backed up, what does not, and how to restore it |
| [operations/risks-and-questions.md](operations/risks-and-questions.md) | Loose ends, accepted trade-offs and things I still need to confirm |
| [containers/README.md](containers/README.md) | Plan and checklist for the per-container pages |
| [containers/107-adguard.md](containers/107-adguard.md) | AdGuard Home, the DNS VIP and the Pi replica |
| [containers/106-openwrt.md](containers/106-openwrt.md) | The lab router, DHCP/DNS and the firewall that does not load |
| [containers/101-npm.md](containers/101-npm.md) | Nginx Proxy Manager, its proxy hosts and SSL management |
| [pi/README.md](pi/README.md) | The Raspberry Pi, its DNS and UPS roles, and what still needs checking |
| [services/ups.md](services/ups.md) | The ESP32/Pi UPS monitor and the shutdown/wake path |
| [services/README.md](services/README.md) | Cross-cutting service docs; the UPS page is done, the rest are planned |

## The setup in one paragraph

The Proxmox host is a small Lenovo ThinkCentre with an i5-6500T, 16 GB of RAM and two disks. The boot
disk holds Proxmox and all container root filesystems. The second disk is a USB-attached 480 GB drive
mounted at `/mnt/data`, which holds media, photos and backup staging. Proxmox runs 16 LXC containers and
no virtual machines. Thirteen are normally running. The containers live on an internal `10.10.10.0/24`
network behind an OpenWrt container, while the host, the NAS, AdGuard and Tailscale sit on the main
`192.168.0.0/24` LAN. DNS is handled by AdGuard on the host LAN, with a second AdGuard on the Pi behind a
keepalived VIP. There is no Proxmox cluster or HA, and no Proxmox Backup Server; a weekly script sends
seven containers to Backblaze B2.

## The Pi

The Pi is at `192.168.0.169` and the login user is `pi`. Credentials are deliberately not kept in this
repo. CT 107 showed that the Pi runs the second AdGuard Home instance and is the keepalived backup for
the DNS VIP. It also runs the UPS monitor, which reads the ESP32 at `192.168.0.178` and can shut down or
wake `prox` when mains power or the WAN goes away. The design is in [services/ups.md](services/ups.md).
I have not inspected the Pi directly yet; that comes after the containers.

## How these pages were made

I used SSH to reach `prox` and read `/etc/pve`, `/etc/network/interfaces`, storage and container configs,
systemd units, SMART data, package state and logs. For the network details I also looked at the OpenWrt
container's DHCP leases and DNS settings. No configuration was written, no service was restarted and no
container was started or stopped.

## What comes next

1. One page per container. CT 107 (AdGuard) and CT 106 (OpenWrt) are done; CT 101 (NPM) is next.
2. The Pi, now that CT 107 has confirmed its role in DNS and the UPS repo has explained the other role.
3. Cross-cutting pages for DNS, the reverse proxy, media, photos, monitoring and remote access.
