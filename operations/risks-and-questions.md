# Notes and trade-offs

Not a security audit. Single-user LAN, no outside users, security kept simple on purpose: no Proxmox firewall rules, root SSH with a password, self-signed certs. Noted for completeness, not as a hardening project.

The notes below are the operational things most likely to bite: disk health, backup coverage, dependencies, capacity.

## Accepted as-is

- Proxmox firewall disabled. The per-container `firewall=1` flags do nothing, but nothing crosses an untrusted boundary.
- Root can SSH in with a password. Fine on this LAN.
- Web UI uses the default self-signed cert.
- Several services use plain HTTP inside the lab.
- Cloudflare WARP is installed on the host but disconnected; the dedicated exit container is stopped.

None of these will change unless asked.

## Worth keeping an eye on

### The data disk

`/dev/sdb` is a single 480 GB USB-attached drive. It holds media, Immich photos, backup staging, and the private directory. SMART says PASSED, but it has 3 current pending sectors and `smartd` logs them every 30 minutes.

USB adds failure modes an internal disk doesn't have: cable, enclosure, power, controller resets. None of that happened while I was looking, but it's the weakest part of the storage setup.

### Backup coverage

Seven containers backed up by design. Nine intentionally excluded. Bind-mounted data is never in a container archive, and `/mnt/data/private` has no other copy.

The photo library and DB are backed up by Zerobyte (CT 108).

### DNS and the lab router

CT 107 (AdGuard) is the resolver for the host, NAS, and lab. It's not alone — the Pi at `192.168.0.169` runs a replica and holds the `.147` VIP if CT 107 stops. `adguardhome-sync` copies the config across every two hours. So DNS is a pair, though the standby can be up to two hours behind and keepalived doesn't check whether AdGuard itself is alive.

The lab router is different. CT 106 (OpenWrt) is the only router for every `10.10.10.x` container, and it runs on `prox`. If it stops, the lab loses its route to the house LAN and internet, even if Pi DNS is up.

CT 106's firewall config is enabled at boot but doesn't load. `fw4 check` fails on a custom `masq-lan-to-internal` rule that jumps to a `masquerade_to_lan` chain `fw4` never creates. The running container has no nftables rules. The lab still works because it's a routed subnet: the main router routes `10.10.10.0/24` via `192.168.0.150`, no NAT involved. Accepted for now; the rule wasn't changed.

### Disk space

Root was 65 % full, thin pool 66 % used. Not urgent. Easy wins: 14 GB of old dumps on `/`, and the 16 GB Windows VM image on `/mnt/data` if the VM is really gone.

The thin pool has 122 GB provisioned for running containers plus another 20 GB for stopped ones, against a 130.5 GB pool. Works because thin volumes only use what they need, but creating too many new containers could fill it.

### Pending updates

58 pending package updates on the host, mostly Debian security. No unattended upgrades there. Nothing applied. CT 107 itself was up to date.

### Static addresses in the DHCP pool

CT 103, 104, 113, 118 use static addresses inside OpenWrt's `.100–.249` DHCP range, no reservations. dnsmasq usually checks before leasing, so no problem yet — but a reservation would be cleaner.

### Memory overcommit

Running containers have ~32 GiB RAM limits on a 15 GiB host. Mostly fine. Jellyfin, Immich, and the dev container are the ones that can be busy together.

The UPS monitor is in [../services/ups.md](../services/ups.md). Its config and the Proxmox shutdown agent were not changed.

## What was not changed

Nothing. All commands were read-only: `cat`, `ls`, `pct list`, `pct config`, `pct exec` (reads), `smartctl`, `pveum ... list`, `systemctl status`, `rclone listremotes`, `uci show`. No files edited on `prox`, no services restarted, no containers started or stopped.
