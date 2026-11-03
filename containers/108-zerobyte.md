# CT 108, zerobyte

Zerobyte is the restic-based backup automation service for the homelab. This is the active tool protecting the useful data (LXC backup files, Immich library + DB). Runs as a Bun/Node service, no Docker.

## Identity and resources

| | |
|---|---|
| Hostname | `zerobyte` |
| Proxmox ID | 108 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 2 vCPU, 6 GB RAM, 512 MB swap |
| Disk | 10 GB thin volume, 2.8 GB used (30 %) |
| Address | `10.10.10.230` (DHCP) |
| Startup | `onboot: 1`, no order |
| Type | unprivileged |
| Backup | **not** in B2 job |

Uptime 5 days 21 hours, load ~0.82, memory ~108 MB of 6 GB.

## Zerobyte

Zerobyte is a backup service built around restic, deployed here as a web service. The app lives in `/opt/zerobyte` (the repo), run by `bun` from the `.output/server/index.mjs` build.

- Service: `zerobyte.service` (systemd), `Restart=on-failure`.
- Env: `/opt/zerobyte/.env` — contains `BASE_URL`, `APP_SECRET`, database URL, restic cache/repos/volumes dirs. Values not reproduced (secret file).
- Port 4096: `bun` listen, all interfaces.
- Bind mount `/mnt/nas` → host `/mnt/data/public/immich` (the photo library). It has `upload/`, `library/`, etc.

The app manages restic repositories (`ZEROBYTE_REPOSITORIES_DIR`). The `/mnt/nas` mount is the photo library that the backups target.

## Docker note

There's a `compose.yaml` and `Dockerfile` in the repo, but **no Docker is running here** — no `docker` ps output, no containers. The service is running natively via Bun.

## Ports

| Port | Process | Use |
|---|---|---|
| 4096/tcp | bun | Zerobyte web UI/API |
| 22/tcp | sshd | SSH |
| 25 | postfix | localhost |

## What it backs up

Per the owner, Zerobyte handles the useful data:

- the LXC backup files (the B2/scheduled container backups)
- the Immich data — library and database

So the photo library and DB are protected via Zerobyte, replacing the old Immich B2 scripts (see [109-immich.md](109-immich.md)). The restic repositories target Backblaze B2 (owner-confirmed); the repository storage path is configured via `ZEROBYTE_REPOSITORIES_DIR` in the `.env` (value not reproduced).

CT 108 itself is **not** in the B2 job — it is the backup service, not a client.

## Health

- `zerobyte.service` running.
- Nothing notable failing.

## What happens if something fails

| Failure | Effect |
|---|---|
| zerobyte stops | The backup automation UI is down; restic repos unaffected. |
| Container lost | The service config is gone; backups/repos are outside (host disk). |


