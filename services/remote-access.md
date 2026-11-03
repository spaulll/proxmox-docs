# Remote access

How I reach the homelab from outside. The main path is Tailscale; WARP and the Telegram proxy are stopped.

## Tailscale

- CT 110 (`tailscale-LXC`) at `192.168.0.5` is the main Tailscale node.
- Tailnet IP `100.64.149.36`. Verified as a subnet router and exit node — it advertises `10.10.10.0/24`, `192.168.0.0/24`, and `0.0.0.0/0`/`::/0`, so its exit node gives the home IP as the source when connecting from outside.
- The Pi is also on the tailnet (`100.113.193.23`) and runs as an exit node — emergency fallback when `prox` is down (Pi runs on UPS power).
- See [containers/110-tailscale.md](../containers/110-tailscale.md).

## Cloudflare WARP

- The host has WARP installed but the tunnel is manually disconnected.
- A dedicated `warp-exit` container (CT 113) is **stopped**. Its exit node is the intended path for a Cloudflare WARP VPN via Tailscale (with homelab access) when wanted.

## Telegram proxy

- CT 118 (`tg-proxy`) was a Telegram proxy, dual-homed (`.218` on both LANs). **Stopped** and skipped.

## Public entry

- The ISP router has no port forwards configured — there is no public entry.
- The primary *internal* entry is the reverse proxy (NPM) at `10.10.10.200`, reachable via `.myownserv.duckdns.org` only inside the LAN (rewritten by AdGuard). The domain is LAN-only with no public records.
- Outside access is via Tailscale, not exposed ports.

## Status

| Path | State |
|---|---|
| Tailscale (CT 110) | running; used as subnet router + exit node (home IP outside) |
| Tailscale (Pi) | running; used as exit node (power-cut fallback) |
| WARP (host pkg) | installed, disconnected |
| WARP exit (CT 113) | stopped; intended for Cloudflare WARP VPN via Tailscale |
| Telegram proxy (CT 118) | stopped, skipped |
| ISP router port-forwards | none |


