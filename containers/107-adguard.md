# CT 107, AdGuard Home

AdGuard is the DNS resolver for the house LAN and, through OpenWrt, for the lab network. I started with
this container because DNS is the first thing everything else needs.

The short version: CT 107 is at `192.168.0.146`. The address clients actually use, `192.168.0.147`, is a
keepalived VIP shared with the Raspberry Pi at `192.168.0.169`. CT 107 is the MASTER and the Pi is the
BACKUP. CT 107 also runs `adguardhome-sync`, which copies its AdGuard configuration to the Pi every two
hours. DNS is a pair, not a single container. That corrected an assumption in my earlier notes.

## Identity and resources

| | |
|---|---|
| Hostname | `adguard` |
| Proxmox ID | 107 |
| OS | Debian 13 (trixie) |
| Kernel | `7.0.14-20-pve` (the host kernel) |
| CPU / RAM / swap | 1 vCPU, 1 GB RAM, 512 MB swap |
| Disk | 4 GB thin volume, 1.5 GB used (40 %) |
| Main address | `192.168.0.146/24` |
| DNS VIP | `192.168.0.147/24` |
| Gateway | `192.168.0.1` |
| Local name | `adguard.lan` |
| Certificate name | `dns.prox.dpdns.org` |
| Startup | `onboot: 1`, `startup: order=1` |
| Tags | `adblock`, `community-script` |

The container is unprivileged, with `nesting=1` and `keyctl=1`. It was built from the community-scripts
AdGuard LXC template; the description in the PVE config is still the template HTML.

At capture it had been up for four days and five hours. Memory use was 461 MB, with a peak of 947 MB, and
5 MB of swap was in use. The 1 GB limit is not generous for AdGuard, but it has not been a problem. Load
average was 0.72 and there were no pending package updates.

`pct config` sets the container's resolver to `192.168.0.147`, so AdGuard itself resolves through the VIP.
`/etc/resolv.conf` has `search lan` and `nameserver 192.168.0.147`.

## The two addresses and the VIP

`pct config 107` only defines `192.168.0.146/24`. The `.147` address is not in the Proxmox config. It is
added to `eth0` by keepalived.

| Node | Real address | VRRP state | Priority |
|---|---|---|---|
| CT 107 | `192.168.0.146` | MASTER | 100 |
| Raspberry Pi | `192.168.0.169` | BACKUP | 50 |
| Shared VIP | `192.168.0.147` | floats | — |

The keepalived instance is `VI_1`, with `virtual_router_id 147`, a one-second advert interval, and unicast
between `.146` and `.169`. There is a 10-second startup delay. VRRP authentication is enabled; the shared
secret is in `/etc/keepalived/keepalived.conf` and is not copied here.

The Pi is not just a spare address. It runs a second AdGuard Home instance, and `adguardhome-sync` keeps
its configuration in step with CT 107. The host, the NAS and OpenWrt all use `.147` as their resolver, so
they follow the VIP to whichever node currently holds it.

One limitation matters: keepalived only tracks the interface. There is no `vrrp_script` checking AdGuard
itself. If the AdGuard process dies but the container and keepalived stay up, the VIP stays on CT 107 and
DNS stops. If the whole container stops, keepalived stops with it and the Pi takes over.

## What runs inside

| Service | What it does |
|---|---|
| `AdGuardHome.service` | DNS, filtering, DoH, DoT and the admin UI |
| `adguardhome-sync.service` | pushes configuration to the Pi |
| `keepalived.service` | owns the `.147` VIP |
| `ssh.service` | SSH on port 22 |
| `postfix.service` | local mail only, on `127.0.0.1:25` |
| `cron.service` | runs the `acme.sh` renewal job |
| `systemd-networkd.service` | container networking |

The listening ports are:

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

`nftables` is installed but the ruleset is empty, with default accept on all three chains. There is no
local packet filtering.

## AdGuard Home

The installed version is `v0.107.79`. The systemd unit runs `/opt/AdGuardHome/AdGuardHome -s run`, restarts
after 10 seconds if it fails, and writes stdout and stderr to `/var/log/AdGuardHome.out` and
`/var/log/AdGuardHome.err`.

The admin UI is on port 80 and 443. HTTPS uses a Let's Encrypt certificate for `dns.prox.dpdns.org`,
issued on 2026-10-11 and valid until 2027-01-09. `acme.sh` renews it from root's crontab every day at
14:25, and the next renewal is due on 2026-12-11. `force_https` is false, so the HTTP port stays open.
A local admin account is configured; the password hash is in `AdGuardHome.yaml` and is not reproduced
here.

The DoH endpoint is served on 443 under `/dns-query` and `/dns-query/{ClientID}`. Insecure DoH is
disabled. DoT and DoQ share port 853. Strict SNI checking is off.

### Upstreams and resolver behaviour

- Two NextDNS profiles over DoH and DoT, used in load-balance mode. The profile IDs are not recorded.
- Cloudflare DoH as the fallback.
- Bootstrap resolvers: `1.1.1.1`, `1.0.0.1`, `9.9.9.9` and `149.112.112.112`.
- DNSSEC is on, AAAA queries are disabled, and `ANY` requests are refused.
- Cache is 128 MB, with a minimum TTL of 600 seconds, a maximum of 3600, and optimistic caching (30-second
  answer TTL, 12-hour maximum age).
- Rate limit is 500 requests per second. `192.168.0.113` and `192.168.0.32` are exempt.
- EDNS Client Subnet is off. The upstream timeout is 3 seconds and the fastest-address timeout is 1 second.
- Plain DNS is enabled. Local PTR lookups go to `192.168.0.1`, which is the OpenWrt router's dnsmasq.

Disabling AAAA matches the `filter_aaaa` setting on OpenWrt. The house LAN has no usable IPv6, so clients
were only generating pointless AAAA traffic.

### Filtering

Filtering is on. Safe browsing, parental filtering and safe search are all off, and no blocked services
are configured.

Seven blocklists are enabled, all from HaGeZi:

- OPPO & Realme Tracker Blocklist
- Samsung Tracker Blocklist
- Vivo Tracker Blocklist
- Windows/Office Tracker Blocklist
- Xiaomi Tracker Blocklist
- Pro Blocklist
- Threat Intelligence Feeds

There is one allowlist, HaGeZi's Allowlist Referral. Seven other lists are installed but disabled: the
AdGuard DNS filter, AdAway Default Blocklist, OISD Blocklist Big, Steven Black's List, Phishing Army,
uBlock Badware Risks, and the AdGuard DNS Popup Hosts filter. Lists update every 24 hours. The filter
directory was 104 MB at capture.

### Rewrites and local names

These are AdGuard DNS rewrites, separate from OpenWrt's DHCP leases:

| Domain | Answer |
|---|---|
| `*.myownserv.duckdns.org` | `10.10.10.200` (Nginx Proxy Manager) |
| `asus.lan` | `10.10.10.200` |
| `dns.prox.dpdns.org` | `192.168.0.147` (the VIP) |
| `opencode.lan` | `10.10.10.162` |
| `prox.lan` | `192.168.0.50` |
| `*.githubusercontent.com` | `185.199.108.133`, `185.199.110.133`, `185.199.111.133` |
| `addons.mozilla.org` | `151.101.193.91` |

The active user rules are small: `wpad.lan` returns NXDOMAIN, and `static.okx.com` and
`content.mql5.com` are explicitly allowed. Two rules for `api.telegram.org` are commented out and are not
in effect.

### Client labels

AdGuard has names for the devices that query it most often. The labels are useful when an address shows
up in a log:

| Name | Address or MAC |
|---|---|
| M4-Pro | `192.168.0.113`, `74:f2:fa:98:31:e7` |
| Proxmox | `192.168.0.50` |
| SuiPlay | `192.168.0.190` |
| openwrt | `192.168.0.150` |
| oppo-a54 | `192.168.0.79`, `192.168.0.82`, `58:d6:97:c5:2b:eb` |
| poco-m4 | `192.168.0.63` |

Most of them use the global filtering settings. `oppo-a54` has its own client entry.

### Query log and statistics

The query log keeps 7 days and statistics keep 30 days. Both ignore `wpad.lan`,
`*.myownserv.duckdns.org` and `*.prox.dpdns.org`, so the local health checks and rewrite lookups do not
fill the log.

The data directory was 211 MB at capture: 104 MB of filters, 102 MB of query log (28 MB current plus a
74 MB rotated file), 5.1 MB of statistics, and a small sessions database.

DHCP is disabled. OpenWrt owns DHCP and is authoritative for the `lan` domain. AdGuard still uses `lan`
as its local domain name and forwards PTR queries to `192.168.0.1`.

## The replica and the sync job

`adguardhome-sync` runs as a systemd service from `/opt/adguardhome-sync`. Its configuration is at
`/opt/adguardhome-sync/adguardhome-sync.yaml`; that file contains credentials and is not reproduced here.

The job runs every two hours (`0 */2 * * *`), and also on startup. It syncs:

- DNS server configuration, access lists and rewrites
- DHCP server configuration and static leases
- general settings, theme, query log and statistics settings
- clients, blocked services and filters

It does not copy the query log history or the statistics database, so the Pi keeps its own. TLS is not an
explicit feature in the sync config either, which means the Pi's certificate has to be checked separately
when I document the Pi.

Both ends are addressed by IP over HTTPS, with certificate verification skipped. The origin is
`https://192.168.0.146`, the replica is `https://192.168.0.169`, and both report AdGuard Home `v0.107.79`.
The sync service also has a small web UI on port 8080; metrics are disabled.

The logs show a successful connection at every even hour. The last one before I wrote this was at 20:00
on 2026-10-31.

## Data and backups

The AdGuard data directory is inside the container root filesystem, so there are no bind mounts to worry
about. The weekly B2 job includes CT 107, and the archive from 2026-10-25 was 330 MB. Restoring the
container brings back the configuration, filters, query log and statistics together.

There is also an `agh-backup` directory in `/opt/AdGuardHome`, about 35 MB, containing an older binary and
config from July and August. I did not establish what creates it or whether anything uses it.

The Pi is not in the Proxmox backup job. Its AdGuard configuration is replicated, but its operating
system, SD card and certificate are not covered by the CT 107 archive.

## Health

There were no current AdGuard errors in the journal and no failed systemd units. The recurring
`systemd-networkd-wait-online` timeout appears in this container's log at various times; it has not
stopped the services from coming up.

The `AdGuardHome.err` file still contains some old Quad9 errors from April. The live configuration no
longer uses Quad9, so I did not treat those as current.

## What happens if something fails

| Failure | Effect |
|---|---|
| CT 107 stops | keepalived moves `.147` to the Pi. DNS continues with the last synced configuration. |
| AdGuard stops, container stays up | The VIP stays on CT 107 because keepalived has no service check. DNS fails until AdGuard is restarted. |
| The Pi stops | CT 107 remains MASTER. No immediate impact, but there is no standby. |
| `prox` stops | CT 107 and CT 106 both stop. The Pi takes the DNS VIP for the house LAN, but the lab network loses its router. |
| Both DNS nodes stop | DNS is down for the house LAN and the lab. |

The two-hour sync interval means a change made on CT 107 can be up to two hours behind on the Pi. That is
fine for filter updates and rewrites, but it is worth remembering after changing an upstream or a client
setting.

## Recovery notes

If CT 107 is lost, restore it from the B2 archive, start it, and let keepalived take the VIP back. The Pi
will hold DNS while the restore is in progress.

```bash
rclone lsf b2lxccrypt:prox-lxc-backups/adguard/
pct restore 107 /mnt/data/restore/adguard-107-<timestamp>.tar.zst --storage local-lvm
pct start 107
```

If the Pi is lost, CT 107 carries on as MASTER. The Pi can be rebuilt and re-synced from CT 107, but its
certificate and OS will need to be set up again.

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

- The Pi's certificate is not visible from CT 107. How is it issued and renewed? The sync config does not
  list TLS as a feature.
- Should keepalived check AdGuard itself rather than only the interface? Right now a dead AdGuard process
  would leave the VIP on the wrong node. I have not changed it.
- Is the two-hour sync interval deliberate? It is the main limit on how fresh the standby is.
- The Pi also runs the UPS monitor. The design is in [../services/ups.md](../services/ups.md); I still need
  to check the live service when I document the Pi.
- Is the `agh-backup` directory used by an update process, or is it just left over?

No files were changed on the container. All of this came from `pct config`, `cat`, `systemctl status`,
`ss`, `journalctl`, `openssl`, `acme.sh --list`, `nft list ruleset` and read-only file inspection.
