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
| aria2 + AriaFlow | 103 | — | downloader + Telegram bot (organizes into lib) |
| Samba/NFS | 105 | 445/2049 | LAN file access to the same data |
| filebrowser | 111 | 8080 | web file management |

- Jellyfin uses the Intel GPU (`/dev/dri/card1`, `renderD128`) with the `jellyfin` user in `video`/`render` groups for QSV transcoding (ffmpeg8). GPU transcoding is confirmed working, not falling back to CPU.
- NPM exposes `jellyfin.myownserv.duckdns.org` → `10.10.10.201:8096`.

## Downloads

aria2 (CT 103) is driven by AriaFlow, a Telegram bot. Send it a link, a magnet, a video-page URL, or forward a file — it downloads via aria2 or yt-dlp, then organizes finished files into the library folders (`movies`, `series`, `anime`, `music`, `documents`, `Books`, `YouTube`). A local Telegram Bot API server allows forwarded files up to 2 GB. After organizing, it can trigger a Jellyfin library refresh.

Repo: https://github.com/spaulll/AriaFlow. Container details: [../containers/103-aria2.md](../containers/103-aria2.md).

## Notes

- **No automated backup** of the media library. It's on the USB data disk only and is treated as replaceable.
- Jellyfin config/watch state (CT 104) is deliberately left out of the B2 backup; it must be rebuilt if lost.
- `aria2` downloads into `/mnt/nas` (same data path) and is in the B2 backup.


