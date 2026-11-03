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

- **AdvertiseRoutes** (verified 2026-11-03): `0.0.0.0/0`, `::/0`, `10.10.10.0/24`, `192.168.0.0/24`.
- **ExitNode/ExitNodeIP**: empty — this node doesn't consume another exit node, but advertising `0.0.0.0/0` + `::/0` is what makes it *offer* to be an exit node.

So the live config matches the owner's intent: this node is both a subnet router (advertising both LANs) and an exit node (home IP as source when connecting from outside). This is the main exit path. The other tailnet members are mostly offline (phone/devices/`warp-exit`) and each has its own use case; only this node and the Pi are online.

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


