# Homelab notes

Working notes for the home setup. One Proxmox host (`prox`), the containers on it, and a Raspberry Pi.

What's documented comes from logging into each box and reading the config. Not from memory or an old diagram.

No passwords or private keys live here. If a credential matters, the notes say *where* it lives, never what it is. Everything was collected read-only. Security is kept simple on purpose — this is a single-user LAN.

Last full review: 2026-11-03.

## What's in here

| Document | What it's for |
|---|---|
| [proxmox/prox-host.md](proxmox/prox-host.md) | The host itself: hardware, disks, network, services, commands I use |
| [proxmox/guest-inventory.md](proxmox/guest-inventory.md) | Quick reference for all 16 containers, addresses, mounts |
| [network/network-overview.md](network/network-overview.md) | How the LAN and internal lab fit together |
| [operations/backups.md](operations/backups.md) | What's backed up, what isn't, how to restore |
| [containers/README.md](containers/README.md) | Plan and checklist for per-container pages |
| [containers/107-adguard.md](containers/107-adguard.md) | AdGuard Home, the DNS VIP, the Pi replica |
| [containers/106-openwrt.md](containers/106-openwrt.md) | The lab router, DHCP/DNS, the firewall that won't load |
| [containers/101-npm.md](containers/101-npm.md) | Nginx Proxy Manager, proxy hosts and SSL |
| [pi/README.md](pi/README.md) | The Raspberry Pi, its DNS and UPS roles, what's un-checked |
| [services/ups.md](services/ups.md) | The ESP32/Pi UPS monitor, shutdown/wake path |
| [services/README.md](services/README.md) | Cross-cutting services: DNS, reverse proxy, remote access, media, photos, monitoring, UPS, backup |

## The host

Lenovo ThinkCentre M900 (type `10FM0022US`).

- CPU: Intel Core i5-6500T — 4 cores, 4 threads, 2.5 GHz base / 3.1 GHz turbo
- RAM: 16 GB — two 8 GB DDR4-2133, non-ECC
- NIC: `eno1`, gigabit. Wi-Fi card present but unused
- BIOS `FWKT5FA` (2016). Secure Boot off, no TPM 2.0

Disks:

- `/dev/sda` — Crucial CT240BX500SSD1, 223.6 GB. Boot, LVM, all container root filesystems
- `/dev/sdb` — Matrix 512GB, 476.9 GB. `/mnt/data`, USB-attached via JMicron bridge
- `/dev/zram0` — 3.9 GB compressed swap

Runs **16 LXC containers**, no VMs. Thirteen run by default. No cluster, no HA, no Proxmox Backup Server. A weekly script ships seven containers to Backblaze B2.

## Network

Two networks. The house LAN, `192.168.0.0/24`, carries the host, NAS, AdGuard, Pi, and Tailscale. A private lab, `10.10.10.0/24`, runs behind an OpenWrt container (CT 106). The containers live there.

DNS is AdGuard on the host LAN, with a second AdGuard on the Pi behind a keepalived VIP (`192.168.0.147`). Full layout in [network/network-overview.md](network/network-overview.md).

## The Pi

At `192.168.0.169`, user `pi`. Runs the second AdGuard instance and is the keepalived backup for the DNS VIP. Also runs the UPS monitor, which reads the ESP32 at `192.168.0.178` and can shut down or wake `prox` when mains or the WAN drops. Design: [services/ups.md](services/ups.md). Inspected read-only on 2026-10-31 and re-verified 2026-11-03 (DNS cert, `ups-monitor.service`, Tailscale exit node, `dns-redirect.service`).

## Status

All container pages and cross-cutting service pages are written. See [containers/README.md](containers/README.md) and [services/README.md](services/README.md). No open questions remain outstanding.
