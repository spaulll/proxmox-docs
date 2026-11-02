# Service notes

These pages describe capabilities that span more than one container. The per-container pages stay in `containers/`; these explain how a service works end to end.

**Status:** all service pages written.

| Page | Covers | Main guests |
|---|---|
| [ups.md](ups.md) | ESP32/Pi UPS monitor, shutdown and wake path | Pi, ESP32, host |
| [dns.md](dns.md) | AdGuard, OpenWrt dnsmasq, upstreams, filtering | 107, 106, Pi |
| [reverse-proxy.md](reverse-proxy.md) | NPM hosts, certificates, upstreams | 101 |
| [remote-access.md](remote-access.md) | Tailscale, WARP, Telegram proxy | 110, 113, 118 |
| [media.md](media.md) | Jellyfin, aria2, Samba, GPU transcoding | 104, 103, 105, 111 |
| [photos.md](photos.md) | Immich, library, database, backup flow | 109, 108 |
| [monitoring.md](monitoring.md) | monitoring/solar dashboard state | 119 |
| [backup-restore.md](backup-restore.md) | Strategy, B2, Immich, restore drills | host, 108, 109 |

Host and backup details live in:

- [proxmox/prox-host.md](../proxmox/prox-host.md)
- [proxmox/guest-inventory.md](../proxmox/guest-inventory.md)
- [network/network-overview.md](../network/network-overview.md)
- [operations/backups.md](../operations/backups.md)
- [operations/risks-and-questions.md](../operations/risks-and-questions.md)
