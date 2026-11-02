# CT 109, Immich

Self-hosted photo server. This is where the photo library lives, backed by a PostgreSQL database and machine-learning for faces and search.

## Identity and resources

| | |
|---|---|
| Hostname | `immich` |
| Proxmox ID | 109 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 4 vCPU, 6 GB RAM, 512 MB swap |
| Disk | 20 GB thin volume, 7.5 GB used (41 %) |
| Address | `10.10.10.234` (DHCP, via OpenWrt) |
| Startup | `onboot: 1`, order 3 |
| Type | unprivileged, GPU passthrough |
| Backup | weekly B2 job (rootfs only) |

Immich version `3.3.5`, release build, installed natively (not Docker). The stack runs as systemd services inside a single container: `immich-api`, `immich-web`, `immich-ml`, plus PostgreSQL 16 and Redis. No Docker anywhere in here.

The photo data is a bind mount: host `/mnt/data/public/immich` appears at `/mnt/nas`, and Immich's `upload` is a symlink to `/mnt/nas/upload`.

CPU 4 cores, 6 GB RAM. At inspection: load 1.08, ~855 MB used of 6 GB. Disk 7.5/20 GB.

## What runs inside

| Service | What it does |
|---|---|
| `immich-api` | main API, listens on 2283 |
| `immich-web` | web frontend |
| `immich-ml` | machine-learning (facial recognition, CLIP search), port 3003 |
| `postgresql@16-main` | database, localhost 5432 |
| `redis-server` | cache/queue, localhost 6379 |
| `sshd` | SSH |
| `cron` | maintenance |

Ports:

| Port | Process | Use |
|---:|---|---|
| 2283/tcp | immich-api | main UI + API |
| 3003/tcp | immich-ml | machine-learning |
| 5432/tcp | postgres | localhost only |
| 6379/tcp | redis | localhost only |

Postgres and Redis bind to localhost only. The API and ML listen on all interfaces. This is the internal entry for the reverse proxy (NPM proxies `immich.myownserv.duckdns.org` → `10.10.10.234:2283`).

## Machine learning

`immich-ml` runs as `python -m gunicorn immich_ml.main:app` on port 3003, model revision `v2`. The ML cache folder is `/opt/immich/cache`. GPU passthrough is present (`/dev/dri/card1`, `renderD128`) — used for ML inference if configured. The env sets `MACHINE_LEARNING_URL=http://127.0.0.1:3003`, and the model revision is explicitly pinned to `v2`.

## Storage and data

- Root filesystem: the app, PostgreSQL data (`/var/lib/postgresql/16/main`, ~336 MB), and cache.
- Bind mount `/mnt/nas`: the actual photo library, on host `/mnt/data/public/immich`. Subdirs: `upload`, `library`, `thumbs`, `profile`, `encoded-video`, `backups`.

The bind mount is the sensitive part. `vzdump` skips it, so the weekly B2 container archive does **not** contain the photos. The photo library (and DB) are backed up by Zerobyte (CT 108), not by this container's own scripts.

## Database

PostgreSQL 16 cluster, database `immich`, user `immich`, vector extension `vectorchord`. The DB runs on localhost with the app. Connection settings come from `/opt/immich/.env` (DB_HOSTNAME=127.0.0.1). Credentials live in that `.env`; I do not reproduce them here.

## Backup

The photo library and its database are backed up by **Zerobyte** (CT 108). That's the current mechanism. An older clone of an Immich B2 backup repo still sits at `/usr/local/bin/immich-backup/` (scripts for db dump, library upload, flow, report), but its cron entry is commented out — that job was superseded by Zerobyte. The scripts remain as a historical fallback, not the active path.

## Health

- All services active and running (immich-api, immich-web, immich-ml, postgres, redis).
- Load ~1.0 at inspection, memory comfortable.
- No failed units observed.

## What happens if something fails

| Failure | Effect |
|---|---|
| `immich-api` stops | Web UI/API down. Photos and DB intact. |
| Postgres stops | Immich can't serve any data until DB returns. |
| `/mnt/nas` bind mount drops | Photos inaccessible; library appears empty. Data safe on host disk. |
| Container lost | Restore rootfs from B2 (3.2 GB archive). Photos are NOT in that archive — must restore separately. |

## Recovery

Two-step: the container/rootfs from B2, then the photo library from wherever it's backed up.

```bash
rclone lsf b2lxccrypt:prox-lxc-backups/immich/
pct restore 109 /mnt/data/restore/immich-109-<timestamp>.tar.zst --storage local-lvm
pct start 109
```

After restore, verify the bind mount, the `upload` symlink, and that postgres is up. The library itself needs its own restore.

## Open questions

- Is the ML using the GPU, or falling back to CPU? The passthrough is present.
- Does anything walk `/mnt/data/public/immich/backups`? It's inside the photo store.
- The `immich-backup-report.sh.bk` backup file in the old scripts dir — stale or needed?
