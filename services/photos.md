# Photos

Immich, self-hosted photo server. The photo library is the most valuable non-replaceable data on this setup.

## Stack

- CT 109 (Immich `v3.3.5`, native install, no Docker) at `10.10.10.234:2283`.
- PostgreSQL 16 (localhost), Redis (localhost), machine-learning on 3003.
- GPU passthrough present (`/dev/dri/card1`, `renderD128`).
- See [containers/109-immich.md](../containers/109-immich.md).

## Library location

- `/mnt/data/public/immich` (host) → `/mnt/nas` (CT 109), with Immich's `upload` symlinked to `/mnt/nas/upload`.
- Subdirs: `upload`, `library`, `thumbs`, `profile`, `encoded-video`, `backups`.

## Backup status

- The B2 container backup includes only the rootfs (archive 3.2 GB); the bind-mounted library is **not** included.
- The photo library and DB are backed up by **Zerobyte** (CT 108) — that's the current mechanism.
- An older Immich B2 script set at `/usr/local/bin/immich-backup/` is still present but its cron is commented out; it was superseded by Zerobyte.

## Access

- NPM exposes `immich.myownserv.duckdns.org` → `10.10.10.234:2283`.

## Open questions

- Is ML using the GPU? Passthrough present, untested.
- Restore path: container from B2, then library restored via Zerobyte.
