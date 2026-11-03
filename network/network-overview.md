# Network overview

Two networks. The house LAN, `192.168.0.0/24`, and a private lab, `10.10.10.0/24`, behind an OpenWrt container. The Proxmox host sits on both bridges but only has an address on the house LAN. It reaches the lab via the main router and CT 106, not directly over `vmbr1`.

No VLANs, no global IPv6. OpenWrt has a ULA prefix and DHCPv6/RA configured, but no lab interface has a ULA address and there's no IPv6 default route. Clients only get link-local. OpenWrt also filters AAAA records, so they don't try IPv6 anyway.

## Layout

```text
Internet
   │
[ISP router 192.168.0.1]
   │  192.168.0.0/24 (house LAN)
   ├── prox / vmbr0 — 192.168.0.50
   │     ├── CT 105  NAS            192.168.0.10
   │     ├── CT 107  AdGuard        .146, VIP .147
   │     ├── CT 110  Tailscale      192.168.0.5
   │     └── CT 106  OpenWrt        static .150
   │            │
   │            └── vmbr1  10.10.10.0/24
   │                  ├── CT 100  opencode     10.10.10.162
   │                  ├── CT 101  npm          10.10.10.200
   │                  ├── CT 102  journal      10.10.10.149
   │                  ├── CT 103  aria2        10.10.10.177
   │                  ├── CT 104  jellyfin     10.10.10.201
   │                  ├── CT 108  zerobyte     10.10.10.230
   │                  ├── CT 109  immich       10.10.10.234
   │                  ├── CT 111  filebrowser  10.10.10.144
   │                  ├── CT 119  monitoring   10.10.10.246
   │                  └── CT 112 / 113 / 118   stopped
   ├── Raspberry Pi  192.168.0.169 (AdGuard replica, VRRP backup, UPS monitor)
   ├── ESP32 UPS monitor 192.168.0.178
   └── other house devices
```

## Bridges on the Proxmox host

| Bridge | Host address | Uplink | Used by |
|---|---|---|---|
| `vmbr0` | `192.168.0.50/24` | `eno1` | 105, 106, 107, 110, 118 |
| `vmbr1` | none | none | 100–104, 108, 109, 111, 112, 113, 118, 119 |
| `vmbr2` | none | none | nothing |

`vmbr2` has no ports and isn't referenced anywhere. Config comment says `#opnsense-lan` — from an old plan that was never finished.

Since `vmbr1` has no host address, the host doesn't reach the lab directly over that bridge. It can still reach the containers through the main router's `10.10.10.0/24` route and CT 106 (confirmed from the host and CT 101). That route is a deliberate static entry on the router, pointing at `192.168.0.150`. It manages them with `pct`; the containers reach the internet through OpenWrt.

## Addresses

### House LAN

| Address | Device | Notes |
|---|---|---|
| `192.168.0.1` | Asus AX53u | gateway, DHCP 10–200, NAT, static route `10.10.10.0/24` → `192.168.0.150`, no port forwards |
| `192.168.0.5` | CT 110 tailscale | remote access |
| `192.168.0.10` | CT 105 NAS | Samba |
| `192.168.0.50` | prox | web UI and SSH |
| `192.168.0.113` | M4-Pro | AdGuard client label, MAC `74:f2:fa:98:31:e7` |
| `192.168.0.146` | CT 107 adguard | real address, keepalived MASTER |
| `192.168.0.147` | DNS VIP | keepalived VIP, currently on CT 107 |
| `192.168.0.150` | CT 106 openwrt | static address, WAN side |
| `192.168.0.169` | Raspberry Pi | AdGuard replica, keepalived BACKUP, UPS monitor, user `pi` |
| `192.168.0.178` | ESP32 UPS monitor | OTA-enabled, MAC `c0:49:ef:69:ce:f8` |
| `192.168.0.218` | CT 118 tg-proxy | stopped |

The ISP router is an Asus RT-AX53U. DHCP hands out `192.168.0.10–.200`. No port forwards are configured. CT 106's WAN address is static.

### Lab network

OpenWrt serves DHCP from `.100` to `.249`, 12-hour lease. No static reservations in dnsmasq, even though several containers have static addresses in that range.

| Address | Container | How |
|---|---|---|
| `10.10.10.1` | CT 106 openwrt | static, gateway and DNS |
| `10.10.10.135` | CT 113 warp-exit | static, stopped |
| `10.10.10.144` | CT 111 filebrowser | DHCP |
| `10.10.10.149` | CT 102 journal | DHCP |
| `10.10.10.162` | CT 100 opencode | DHCP |
| `10.10.10.177` | CT 103 aria2 | static |
| `10.10.10.200` | CT 101 npm | DHCP |
| `10.10.10.201` | CT 104 jellyfin | static |
| `10.10.10.218` | CT 118 tg-proxy | static, stopped |
| `10.10.10.230` | CT 108 zerobyte | DHCP |
| `10.10.10.234` | CT 109 immich | DHCP |
| `10.10.10.246` | CT 119 monitoring | DHCP |

Static addresses for 103, 104, 113, 118 sit inside the DHCP pool. dnsmasq normally checks before handing one out, so conflicts are unlikely — but it's not a proper reservation.

## DNS

A floating VIP in front of two AdGuard instances:

```text
lab containers → 10.10.10.1 (OpenWrt dnsmasq)
                     │  noresolv, server=192.168.0.147
                     ▼
                192.168.0.147 (AdGuard VIP)
                     │
                     ▼
                upstream resolvers
```

`192.168.0.147` is a keepalived VIP shared by CT 107 (`192.168.0.146`) and the Pi (`192.168.0.169`). CT 107 is MASTER, priority 100; Pi is BACKUP, priority 50. Both run AdGuard Home. If CT 107 stops, the Pi takes the VIP and DNS keeps working with the last config it received.

`adguardhome-sync` copies CT 107's settings to the Pi every two hours, so the standby can be up to two hours behind. The host, NAS, and AdGuard itself use `.147`. OpenWrt forwards everything to the same address.

Limitation: keepalived checks the interface, not the AdGuard process. If AdGuard crashes inside CT 107 but the container stays up, the VIP stays on CT 107 and DNS stops. If the whole container stops, the Pi takes over.

OpenWrt's dnsmasq is authoritative for `lan`, caches 1000 entries, filters AAAA. It has a rebind exception for `myownserv.duckdns.org`. AdGuard rewrites `*.myownserv.duckdns.org` to NPM at `10.10.10.200` — the internal name for the proxy. `myownserv.duckdns.org` is LAN-only: it has no public records, is managed entirely by NPM locally, and is only reachable by LAN clients.

## Routing and NAT

The host uses `192.168.0.1` as its default gateway. Lab containers use `10.10.10.1`. CT 106 routes between the two subnets but doesn't NAT. Its `fw4` config fails to load; `nft list ruleset` is empty. The main router has a return route for `10.10.10.0/24` via `192.168.0.150`, so lab traffic keeps its `10.10.10.x` source address all the way out. Confirmed with a ping from CT 101 and a capture on `vmbr0` — source was still `10.10.10.200`.

So there's one NAT layer, on the ISP router, not two. Inbound forwarding to a lab container needs a port forward on the ISP router to the container's `10.10.10.x` address. CT 106 only forwards; it doesn't translate. The ISP router has no port forwards configured.

The firewall config is effectively open: defaults and both zones accept everything, WAN-to-LAN forwarding enabled. The custom `masq-lan-to-internal` rule is what breaks `fw4` — it jumps to a chain `fw4` doesn't create. Left alone by decision. Exact error on the CT 106 page.

## What is exposed

- Proxmox UI and SSH reachable from the house LAN.
- CT 101 (Nginx Proxy Manager) is the likely entry point for web services; proxy hosts not documented yet.
- Tailscale on CT 110 — verified as a subnet router + exit node (advertises `10.10.10.0/24`, `192.168.0.0/24`, and `0.0.0.0/0`/`::/0`), so the home IP shows as source when away.
- The Pi also runs Tailscale as an exit node — emergency fallback when `prox` is down (Pi runs on UPS power).
- WARP and the Telegram proxy are stopped (CT 113, CT 118).
- ISP router has no port forwards.

## Handy checks

```bash
# from the host
ip r
ip neigh
bridge link
ping -c1 192.168.0.1
ping -c1 192.168.0.147

# from a lab container
pct exec 100 -- ip r
pct exec 100 -- cat /etc/resolv.conf
pct exec 100 -- ping -c1 10.10.10.1
pct exec 106 -- cat /tmp/dhcp.leases
```
