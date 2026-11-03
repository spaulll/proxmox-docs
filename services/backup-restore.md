# Backup & restore

This is the cross-cutting view of what's protected and what isn't. The operational detail lives in [operations/backups.md](../operations/backups.md); this page ties it to each service.

## What is backed up

Two mechanisms:

**B2, weekly (script):**

| Container | What it protects |
|---|---|
| CT 107 adguard | DNS config, filters, stats (330 MB) |
| CT 101 npm | reverse proxy config + SSL certs (597 MB) |
| CT 106 openwrt | router/DHCP/DNS/firewall config (9 MB) |
| CT 105 NAS | Samba/NFS config — **not** the shared data (76 MB) |
| CT 103 aria2 | download client config |
| CT 110 tailscale | tailscale state (305 MB) |
| CT 109 immich | Immich rootfs — **not** the photo library (3.2 GB) |

**Zerobyte (CT 108):** the useful data — the LXC backup files, and the Immich data (library + DB).

## Not covered

| Data | Where | Notes |
|---|---|---|
| Media library | `/mnt/data/public/Downloads` | ~225 GB, treated as replaceable |
| Private files | `/mnt/data/private` | no copy; holds no important data, intentionally unbacked |
| Dev/code projects | CT 100 | intentionally not backed up |
| Journal DB (SQLite) | CT 102 | intentionally not backed up |
| Jellyfin config | CT 104 | intentionally not backed up |
| Solar dashboard DB | CT 119 | intentionally not backed up (solar only) |
| Windows VM dump | `/mnt/data/public/backups/win10-vm.vma.zst` | 16 GB, kept deliberately (archive of an old VM) |

## The bind-mount gap

`vzdump` skips bind mounts. Container backups never include the large bind-mounted data. That data is handled by Zerobyte (Immich library/DB) or deliberately left un-backed-up (media, private, dev).

## Restore order (whole host)

1. Reinstall Proxmox, recreate `local-lvm` + `/mnt/data`.
2. Set up rclone.
3. Restore in dependency order: CT 107 (DNS) → CT 106 (router) → CT 101 (proxy) → the rest.


