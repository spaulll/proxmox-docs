# DNS

DNS is the one thing everything on the LAN depends on. It runs as a keepalived pair of AdGuard instances, fronted by a virtual IP.

## Topology

```text
lab containers → 10.10.10.1 (OpenWrt dnsmasq)
                     │  noresolv, server=192.168.0.147
                     ▼
                192.168.0.147 (AdGuard VIP)
                     │
                     ▼
                upstream resolvers
```

Two nodes share the VIP `192.168.0.147`:

| Node | Real address | VRRP state | Priority |
|---|---|---|
| CT 107 (AdGuard) | `192.168.0.146` | MASTER | 100 |
| Raspberry Pi | `192.168.0.169` | BACKUP | 50 |

The host, the NAS, and OpenWrt all use `.147` as their resolver. If CT 107 stops, keepalived moves the VIP to the Pi and DNS keeps serving from the last synced config.

## Keepalived

- Instance `VI_1`, `virtual_router_id 147`, 1 s advert interval, unicast between `.146` and `.169`.
- 10 s startup delay. VRRP auth shared secret in `/etc/keepalived/keepalived.conf` (not copied).
- **Limitation:** keepalived checks the interface, not the AdGuard process. If AdGuard dies but the container stays up, the VIP stays on CT 107 and DNS stops. If the whole container stops, the Pi takes over.

## AdGuard config

Both nodes run AdGuard Home `v0.107.79`. Details in [containers/107-adguard.md](../containers/107-adguard.md). Highlights:

- Upstreams: two NextDNS profiles (DoH/DoT, load-balance) + Cloudflare DoH fallback.
- DNSSEC on, AAAA disabled (matches OpenWrt `filter_aaaa`), `ANY` refused.
- Filtering: 7 HaGeZi blocklists, 1 allowlist.
- Rewrites: `*.myownserv.duckdns.org` → NPM (`10.10.10.200`), `prox.lan` → `192.168.0.50`, etc.

## Sync

`adguardhome-sync` on CT 107 copies config to the Pi every two hours (`0 */2 * * *`) and at startup. It syncs DNS settings, rewrites, filters, clients, and stats settings — but **not** query log/statistics history, and **not** TLS. The two-hour interval is deliberate: it bounds how stale the standby can be. The Pi's `dns.prox.dpdns.org` cert is a byte-identical copy of CT 107's (verified 2026-11-03, same serial/fingerprint) — so it's renewed on CT 107 and copied over, since the sync doesn't carry TLS.

## OpenWrt dnsmasq

- Authoritative for `lan`, caches 1000, filters AAAA.
- Forwards to `192.168.0.147` (`noresolv=1`).
- Rebind exception for `myownserv.duckdns.org`.
- DHCP pool `.100–.249`, 12 h lease; no static reservations.

## Failure modes

| Failure | Effect |
|---|---|
| CT 107 stops | VIP → Pi. DNS continues (last synced config). |
| AdGuard crashes, container up | VIP stays on CT 107; DNS down until restart. |
| Pi stops | CT 107 stays MASTER; no standby. |
| `prox` stops | CT 107 + 106 stop; Pi holds house-LAN VIP, lab loses router. |
| Both DNS nodes down | DNS down for LAN and lab. |


