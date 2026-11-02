# CT 110, tailscale-LXC

The Tailscale node for the LAN. Gives the homelab a fixed place on the tailnet.

## Identity and resources

| | |
|---|---|
| Hostname | `tailscale-LXC` |
| Proxmox ID | 110 |
| OS | Debian 12 (bookworm) |
| CPU / RAM / swap | 1 vCPU, 512 MB RAM, 512 MB swap |
| Disk | 4 GB thin volume, 1.2 GB used (33 %) |
| Address | `192.168.0.5` (static, main LAN) |
| Startup | `onboot: 1`, order 2 |
| Type | unprivileged, `/dev/net/tun` passed through |
| Backup | yes, in B2 job |

Uptime 5 days 21 hours, load ~0.73, memory ~40 MB of 512 MB.

## Tailscale

`tailscaled.service` runs; node name `tailscale-lxc` with tailnet IP `100.64.149.36` (`tailscale0` interface, mtu 1280). Logged-in account `djspaul99@`.

- **ExitNode**: false, but `ExitNodeOption: true` — this node *offers* to be an exit node, it doesn't use one.
- **AdvertiseRoutes**: empty (from prefs) — it is not advertising subnet routes.
- **AcceptRoutes/RouteAll**: false.

So: this is a Tailscale member that offers exit-node capability but isn't currently advertising subnets. The other tailnet members are mostly offline (phone/devices).

## Ports

| Port | Process | Use |
|---:|---|---|
| 41641/udp | tailscaled | WireGuard (Tailscale) |

## Backup

CT 110 is in the B2 job (archive 305 MB on 2026-10-25). The state (`/var/lib/tailscale/tailscaled.state`) is backed up.

## Health

- Service running.
- No issues observed.

## What happens if something fails

| Failure | Effect |
|---|---|
| tailscaled stops | This node drops off the tailnet until restarted. |
| Container lost | Restore from B2; re-auth may be needed (device re-added to tailnet). |

## Open questions

- It offers exit-node capability but the host also has WARP + a stopped `warp-exit` CT. Is this the intended exit path, or unused?
- Only this one node plus the Pi are online on the tailnet; some peers are stale.
