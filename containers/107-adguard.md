# CT 107, AdGuard Home

AdGuard is the DNS resolver for the house LAN and, through OpenWrt, the lab. Started here because DNS is the first thing everything else needs.

Short version: CT 107 is at `192.168.0.146`. The address clients use, `192.168.0.147`, is a keepalived VIP shared with the Pi at `192.168.0.169`. CT 107 is MASTER, Pi is BACKUP. CT 107 also runs `adguardhome-sync`, which copies its AdGuard config to the Pi every two hours. DNS is a pair, not a single container. That corrected an assumption in my earlier notes.

## Identity and resources

| | |
|---|---|
| Hostname | `adguard` |
| Proxmox ID | 107 |
| OS | Debian 13 (trixie) |
| Kernel | `7.0.14-20-pve` (host kernel) |
| CPU / RAM / swap | 1 vCPU, 1 GB RAM, 512 MB swap |
| Disk | 4 GB thin volume, 1.5 GB used (40 %) |
| Main address | `192.168.0.146/24` |
| DNS VIP | `192.168.0.147/24` |
| Gateway | `192.168.0.1` |
| Local name | `adguard.lan` |
| Certificate name | `dns.prox.dpdns.org` |
| Startup | `onboot: 1`, `startup: order=1` |
| Tags | `adblock`, `community-script` |

Unprivileged, `nesting=1`, `keyctl=1`. Built from the community-scripts AdGuard LXC template; the PVE description is still the template HTML.

At capture: up four days five hours. Memory 461 MB (peak 947 MB), 5 MB swap. The 1 GB limit isn't generous but hasn't been a problem. Load 0.72, no pending updates.

`pct config` sets the resolver to `192.168.0.147`, so AdGuard resolves through the VIP. `/etc/resolv.conf` has `search lan` and `nameserver 192.168.0.147`.

## The two addresses and the VIP

`pct config 107` only defines `192.168.0.146/24`. The `.147` address isn't in the Proxmox config. keepalived adds it to `eth0`.

| Node | Real address | VRRP state | Priority |
|---|---|---|
| CT 107 | `192.168.0.146` | MASTER | 100 |
| Raspberry Pi | `192.168.0.169` | BACKUP | 50 |
| Shared VIP | `192.168.0.147` | floats | — |

keepalived instance is `VI_1`, `virtual_router_id 147`, one-second advert interval, unicast between `.146` and `.169`. 10-second startup delay. VRRP auth enabled; shared secret in `/etc/keepalived/keepalived.conf`, not copied here.

The Pi isn't just a spare address. It runs a second AdGuard instance, and `adguardhome-sync` keeps it in step. The host, NAS, and OpenWrt all use `.147`, so they follow the VIP to whichever node holds it.

Limitation: keepalived only tracks the interface. No `vrrp_script` checks AdGuard itself. If AdGuard dies but the container and keepalived stay up, the VIP stays on CT 107 and DNS stops. If the whole container stops, keepalived stops with it and the Pi takes over.

## What runs inside

| Service | What it does |
|---|---|
| `AdGuardHome.service` | DNS, filtering, DoH, DoT, admin UI |
| `adguardhome-sync.service` | pushes config to the Pi |
| `keepalived.service` | owns the `.147` VIP |
| `ssh.service` | SSH on 22 |
| `postfix.service` | local mail only, `127.0.0.1:25` |
| `cron.service` | runs the `acme.sh` renewal job |
| `systemd-networkd.service` | container networking |

Listening ports:

| Port | Process | Use |
|---:|---|---|
| 53/tcp, 53/udp | AdGuard Home | plain DNS |
| 80/tcp | AdGuard Home | admin UI over HTTP |
| 443/tcp | AdGuard Home | admin UI and DoH |
| 853/tcp | AdGuard Home | DNS-over-TLS |
| 853/udp | AdGuard Home | DNS-over-QUIC |
| 8080/tcp | `adguardhome-sync` | sync web UI |
| 22/tcp | `sshd` | SSH |
| 25/tcp | postfix | localhost only |

`nftables` installed but ruleset empty, default accept on all chains. No local filtering.

## AdGuard Home

Version `v0.107.79`. Systemd unit runs `/opt/AdGuardHome/AdGuardHome -s run`, restarts after 10 s on failure, stdout/stderr to `/var/log/AdGuardHome.out` / `.err`.

Admin UI on 80 and 443. HTTPS uses a Let's Encrypt cert for `dns.prox.dpdns.org`, issued 2026-10-11, valid to 2027-01-09. `acme.sh` renews from root's crontab daily at 14:25; next renewal due 2026-12-11. `force_https` false, so HTTP stays open. Local admin account exists; password hash in `AdGuardHome.yaml`, not reproduced.

DoH served on 443 under `/dns-query` and `/dns-query/{ClientID}`. Insecure DoH disabled. DoT and DoQ share 853. Strict SNI off.

### Upstreams and resolver behaviour

- Two NextDNS profiles over DoH/DoT, load-balance mode. Profile IDs not recorded.
- Cloudflare DoH as fallback.
- Bootstrap resolvers: `1.1.1.1`, `1.0.0.1`, `9.9.9.9`, `149.112.112.112`.
- DNSSEC on, AAAA disabled, `ANY` refused.
- Cache 128 MB, min TTL 600 s, max 3600, optimistic caching (30 s answer TTL, 12 h max age).
- Rate limit 500 req/s. `192.168.0.113` and `192.168.0.32` exempt.
- EDNS Client Subnet off. Upstream timeout 3 s, fastest-address 1 s.
- Plain DNS enabled. Local PTR goes to `192.168.0.1` (OpenWrt dnsmasq).

Disabling AAAA matches OpenWrt's `filter_aaaa`. No usable IPv6 on the house LAN, so clients were only generating pointless AAAA traffic.

### Filtering

Filtering on. Safe browsing, parental, safe search all off. No blocked services.

Seven blocklists enabled, all HaGeZi:

- OPPO & Realme Tracker Blocklist
- Samsung Tracker Blocklist
- Vivo Tracker Blocklist
- Windows/Office Tracker Blocklist
- Xiaomi Tracker Blocklist
- Pro Blocklist
- Threat Intelligence Feeds

One allowlist: HaGeZi's Allowlist Referral. Seven lists installed but disabled: AdGuard DNS filter, AdAway Default Blocklist, OISD Blocklist Big, Steven Black's List, Phishing Army, uBlock Badware Risks, AdGuard DNS Popup Hosts. Lists update every 24 h. Filter dir was 104 MB at capture.

### Rewrites and local names

AdGuard DNS rewrites, separate from OpenWrt's DHCP leases:

| Domain | Answer |
|---|---|
| `*.myownserv.duckdns.org` | `10.10.10.200` (Nginx Proxy Manager) |
| `asus.lan` | `10.10.10.200` |
| `dns.prox.dpdns.org` | `192.168.0.147` (the VIP) |
| `opencode.lan` | `10.10.10.162` |
| `prox.lan` | `192.168.0.50` |
| `*.githubusercontent.com` | `185.199.108.133`, `185.199.110.133`, `185.199.111.133` |
| `addons.mozilla.org` | `151.101.193.91` |

Active user rules are small: `wpad.lan` returns NXDOMAIN; `static.okx.com` and `content.mql5.com` explicitly allowed. Two rules for `api.telegram.org` are commented out.

### Client labels

Names for the devices that query most often. Useful when an address shows up in a log:

| Name | Address or MAC |
|---|---|
| M4-Pro | `192.168.0.113`, `74:f2:fa:98:31:e7` |
| Proxmox | `192.168.0.50` |
| SuiPlay | `192.168.0.190` |
| openwrt | `192.168.0.150` |
| oppo-a54 | `192.168.0.79`, `192.168.0.82`, `58:d6:97:c5:2b:eb` |
| poco-m4 | `192.168.0.63` |

Most use global filtering. `oppo-a54` has its own client entry.

### Query log and statistics

Query log keeps 7 days, statistics 30. Both ignore `wpad.lan`, `*.myownserv.duckdns.org`, `*.prox.dpdns.org`, so health checks and rewrite lookups don't fill the log.

Data dir 211 MB at capture: 104 MB filters, 102 MB query log (28 MB current + 74 MB rotated), 5.1 MB statistics, small sessions db.

DHCP disabled. OpenWrt owns DHCP and is authoritative for `lan`. AdGuard still uses `lan` as its local domain and forwards PTR to `192.168.0.1`.

## The replica and the sync job

`adguardhome-sync` runs from `/opt/adguardhome-sync`. Config at `/opt/adguardhome-sync/adguardhome-sync.yaml` — contains credentials, not reproduced.

Job runs every two hours (`0 */2 * * *`) and on startup. Syncs:

- DNS server config, access lists, rewrites
- DHCP server config and static leases
- general settings, theme, query log/statistics settings
- clients, blocked services, filters

Doesn't copy query log history or statistics — the Pi keeps its own. TLS isn't an explicit feature, so the Pi's cert is checked separately when I document the Pi.

Both ends addressed by IP over HTTPS, cert verification skipped. Origin `https://192.168.0.146`, replica `https://192.168.0.169`, both report `v0.107.79`. Sync service has a small web UI on 8080; metrics disabled.

Logs show a successful connection every even hour. Last before writing: 20:00 on 2026-10-31.

## Data and backups

AdGuard data lives inside the container root filesystem — no bind mounts to worry about. Weekly B2 job includes CT 107; archive from 2026-10-25 was 330 MB. Restoring brings back config, filters, query log, statistics together.

An `agh-backup` dir in `/opt/AdGuardHome`, ~35 MB, holds an older binary and config from July/August. Didn't establish what creates it or whether anything uses it.

The Pi isn't in the Proxmox backup job. Its AdGuard config is replicated, but its OS, SD card, and certificate aren't covered by the CT 107 archive.

## Health

No current AdGuard errors in the journal, no failed units. The recurring `systemd-networkd-wait-online` timeout appears at various times; hasn't stopped services from coming up.

`AdGuardHome.err` still has old Quad9 errors from April. Live config no longer uses Quad9, so not treated as current.

## What happens if something fails

| Failure | Effect |
|---|---|
| CT 107 stops | keepalived moves `.147` to the Pi. DNS continues with last synced config. |
| AdGuard stops, container stays up | VIP stays on CT 107 (keepalived has no service check). DNS fails until AdGuard restarts. |
| The Pi stops | CT 107 stays MASTER. No immediate impact, but no standby. |
| `prox` stops | CT 107 and 106 stop. The Pi takes the DNS VIP for the house LAN, but the lab loses its router. |
| Both DNS nodes stop | DNS down for house LAN and lab. |

Two-hour sync means a change on CT 107 can be up to two hours behind on the Pi. Fine for filter updates and rewrites; worth remembering after changing an upstream or client setting.

## Recovery notes

If CT 107 is lost, restore from B2, start it, let keepalived take the VIP back. The Pi holds DNS during the restore.

```bash
rclone lsf b2lxccrypt:prox-lxc-backups/adguard/
pct restore 107 /mnt/data/restore/adguard-107-<timestamp>.tar.zst --storage local-lvm
pct start 107
```

If the Pi is lost, CT 107 carries on as MASTER. The Pi can be rebuilt and re-synced, but its cert and OS need setting up again.

Useful checks:

```bash
pct exec 107 -- systemctl status AdGuardHome keepalived adguardhome-sync
pct exec 107 -- journalctl -u AdGuardHome -u keepalived -u adguardhome-sync --since today
pct exec 107 -- ip -4 addr show eth0
dig @192.168.0.147 example.com
dig @192.168.0.147 -p 853 example.com +tls
curl -kI https://192.168.0.147/
```

## Open questions

- The Pi's cert isn't visible from CT 107. How is it issued and renewed? Sync config doesn't list TLS.
- Should keepalived check AdGuard rather than the interface? A dead AdGuard process would leave the VIP on the wrong node. Not changed.
- Is the two-hour sync interval deliberate? It's the main limit on standby freshness.
- The Pi also runs the UPS monitor. Design in [../services/ups.md](../services/ups.md); still need to check the live service when documenting the Pi.
- Is `agh-backup` used by an update process, or left over?

No files changed on the container. Everything came from `pct config`, `cat`, `systemctl status`, `ss`, `journalctl`, `openssl`, `acme.sh --list`, `nft list ruleset`, read-only file inspection.
