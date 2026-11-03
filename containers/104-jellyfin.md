# CT 104, Jellyfin

Media server. This is the front door to the Downloads/media library for the house — movies, series, anime, YouTube archives.

## Identity and resources

| | |
|---|---|
| Hostname | `jellyfin` |
| Proxmox ID | 104 |
| OS | Ubuntu 24.04.5 LTS |
| CPU / RAM / swap | 3 vCPU, 6 GB RAM, 1 GB swap |
| Disk | 20 GB thin volume, 5.7 GB used (31 %) |
| Address | `10.10.10.201` (static) |
| Startup | `onboot: 1`, order 3 |
| Type | unprivileged, GPU passthrough |
| Backup | **not** in B2 job |

Jellyfin server version `12.1` (jellyfin-server + jellyfin-web), with jellyfin-ffmpeg8 for transcoding. Runs as systemd `jellyfin.service`. ffmpeg7 is also installed but in `rc` (removed) state — only ffmpeg8 is active.

Uptime 5 days 21 hours at inspection, load 0.91, memory 395 MB used of 6 GB. Jellyfin process itself uses ~1.4 GB (peak 3.9 GB) — the 6 GB limit gives headroom for transcodes.

## Storage

- Root filesystem: app + config, 5.7/20 GB.
- Bind mount `/mnt/smb`: the media library, on host `/mnt/data/public/Downloads`. Contents:
  - `movies` — 54 GB
  - `series` — 92 GB
  - `anime` — 67 GB
  - `YouTube` — 12 GB
  - `Books` — 60 MB, `documents` — 57 MB, `downloads` — 8 KB
  - Total media on the disk ~225 GB.

Jellyfin's data dir `/var/lib/jellyfin` is 1.4 GB inside the container rootfs. The library itself is the bind mount.

## GPU transcoding

Intel GPU passed through:
- `/dev/dri/card1` (gid 44, video)
- `/dev/dri/renderD128` (gid 993, render)

The `jellyfin` user is in groups `44(video)` and `993(render)`, so it can use the GPU. ffmpeg8 is the active transcoder. QSV transcoding is confirmed working on the i5-6500T — not falling back to CPU.

## Ports

| Port | Service | Use |
|---:|---|---|
| 8096/tcp | jellyfin | web UI + API |
| 8920/tcp | jellyfin | HTTPS (if enabled) |
| 7359/udp | jellyfin | auto-discovery |

Only 8096 was listening at inspection.

## What runs inside

| Service | What it does |
|---|---|
| `jellyfin.service` | the media server |
| `sshd` | SSH |

Nothing else of note.

## Backup

CT 104 is **not** in the weekly B2 job. The container config, metadata, and watch state are not backed up. If lost, the library (bind mount) survives, but Jellyfin's config, user libraries, and watched-state must be rebuilt.

## Health

- Service active since Oct 27, no failures.
- Memory peak 3.9 GB within limits.
- No significant issues observed.

## What happens if something fails

| Failure | Effect |
|---|---|
| `jellyfin.service` stops | Media server down. Library data safe on disk. |
| `/mnt/smb` bind mount drops | Library appears empty until mount returns. |
| Container lost | Restore from a manual backup (none automated), or rebuild. Library data lives on host disk. |

## Recovery

There's no automated backup. Rebuild from scratch or restore from any manual backup. After restore, verify the bind mount and that jellyfin's user can read `/mnt/smb`.

```bash
pct start 104
pct exec 104 -- systemctl status jellyfin
pct exec 104 -- ss -tlnp | grep 8096
```


