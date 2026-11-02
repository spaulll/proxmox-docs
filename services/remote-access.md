# Remote access

How I reach the homelab from outside. This is a work-in-progress; a few pieces are stopped or unverified.

## Tailscale

- CT 110 (`tailscale-LXC`) at `192.168.0.5` is the main Tailscale node.
- Tailnet IP `100.64.149.36`. Offers exit-node capability but advertises no subnet routes, and uses no exit node.
- The Pi is also on the tailnet (`100.113.193.23`).
- See [containers/110-tailscale.md](../containers/110-tailscale.md).

## Cloudflare WARP

- The host has WARP installed but the tunnel is manually disconnected.
- A dedicated `warp-exit` container (CT 113) existed for that; it is **stopped** and skipped.

## Telegram proxy

- CT 118 (`tg-proxy`) was a Telegram proxy, dual-homed (`.218` on both LANs). **Stopped** and skipped.

## Public entry

- The ISP router's port forwards are **unknown** (not documented). 
- The primary *internal* entry is the reverse proxy (NPM) at `10.10.10.200`, reachable via `.myownserv.duckdns.org` only inside the LAN (rewritten by AdGuard).
- What the public DNS for `myownserv.duckdns.org` points to is not confirmed.

## Status

| Path | State |
|---|---|
| Tailscale (CT 110) | running, offers exit node, advertises no routes |
| Tailscale (Pi) | running |
| WARP (host pkg) | installed, disconnected |
| WARP exit (CT 113) | stopped, skipped |
| Telegram proxy (CT 118) | stopped, skipped |
| ISP router port-forwards | unknown |

## Open questions

- Do I need an exit node at all? WARP + stopped exit container suggest the plan changed.
- Public DNS / port-forward entry is unresolved.
- Tailscale: should CT 110 advertise subnets (to reach the whole LAN from the tailnet)?
