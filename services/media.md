# Media

How the media library is stored and served. Movies, series, anime, and a YouTube archive on the USB data disk, served by Jellyfin.

## Library

- Lives on `/mnt/data/public/Downloads` (host data disk), ~225 GB.
- Contents (from CT 104 inspection): `movies` (54 GB), `series` (92 GB), `anime` (67 GB), `YouTube` (12 GB), plus `Books`/`documents`.
- Accessed via the `/mnt/smb` bind mount in CT 104.

## Serving

| Service | Container | Port | Role |
|---|---|---|---|
| Jellyfin | 104 | 8096 | media server + transcoding |
| aria2 | 103 | — | downloads (writes to lib) |
| Samba/NFS | 105 | 445/2049 | LAN file access to the same data |
| filebrowser | 111 | 8080 | web file management |

- Jellyfin uses the Intel GPU (`/dev/dri/card1`, `renderD128`) with the `jellyfin` user in `video`/`render` groups for QSV transcoding (ffmpeg8).
- NPM exposes `jellyfin.myownserv.duckdns.org` → `10.10.10.201:8096`.

## Notes

- **No automated backup** of the media library. It's on the USB data disk only and is treated as replaceable.
- Jellyfin config/watch state (CT 104) is not in the B2 backup; it must be rebuilt if lost.
- `aria2` downloads into `/mnt/nas` (same data path) and is in the B2 backup.


