# Backup & restore

This is the cross-cutting view of what's protected and what isn't. The operational detail lives in [operations/backups.md](../operations/backups.md); this page ties it to each service.

## What is backed up (B2, weekly)

| Container | What it protects |
|---|---|
| CT 107 adguard | DNS config, filters, stats (330 MB) |
| CT 101 npm | reverse proxy config + SSL certs (597 MB) |
| CT 106 openwrt | router/DHCP/DNS/firewall config (9 MB) |
| CT 105 NAS | Samba/NFS config — **not** the shared data (76 MB) |
| CT 103 aria2 | download client config |
| CT 110 tailscale | tailscale state (305 MB) |
| CT 109 immich | Immich rootfs — **not** the photo library (3.2 GB) |

## Not in the B2 backup

| Data | Where | Notes |
|---|---|---|
| Media library | `/mnt/data/public/Downloads` | ~225 GB, treated as replaceable |
| Photo library | `/mnt/data/public/immich` | most valuable; backup scripts exist but **not scheduled** |
| Private files | `/mnt/data/private` | no copy found |
| Dev/code projects | CT 100 | not backed up |
| Journal DB (SQLite) | CT 102 | not backed up |
| Jellyfin config | CT 104 | not backed up |
| Solar dashboard DB | CT 119 | not backed up |
| Windows VM dump | `/mnt/data/public/backups/win10-vm.vma.zst` | 16 GB, local only (May) |

## The bind-mount gap

`vzdump` skips bind mounts. All large data lands on bind mounts, so container backups never include it. Data protection must be handled separately (Immich scripts intended but not scheduled; nothing for media/private).

## Restore order (whole host)

1. Reinstall Proxmox, recreate `local-lvm` + `/mnt/data`.
2. Set up rclone.
3. Restore in dependency order: CT 107 (DNS) → CT 106 (router) → CT 101 (proxy) → the rest.

## Test restore

- None has been performed yet. This is a known gap.

## Open questions

- Schedule the Immich backup (uncomment the cron line).
- Decide a fate for `/mnt/data/private` (add to some backup).
- Clean up the 16 GB Windows VM dump if unneeded.
- Do a test restore to validate the process.
