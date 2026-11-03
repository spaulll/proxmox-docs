# CT 119, monitoring

Docker host, used for the **solar dashboard and solar monitoring** only. There is no Prometheus/Grafana stack — the "monitoring" name overstates it.

## Identity and resources

| | |
|---|---|
| Hostname | `monitoring` |
| Proxmox ID | 119 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 2 vCPU, 2 GB RAM, 512 MB swap |
| Disk | 10 GB thin volume, 2.7 GB used (29 %) |
| Address | `10.10.10.246` (DHCP) |
| Startup | `onboot: 1`, no order |
| Type | unprivileged |
| Backup | **not** in B2 job |

Uptime 5 days 21 hours, load ~0.96, memory 337 MB of 2 GB.

## What runs inside

| Service | What it does |
|---|---|
| `docker.service` | Docker engine (dockerd + containerd) |
| `solar-dashboard.service` | uvicorn app on 8000 |
| `sshd`, `cron`, `postfix` | standard |

The Docker engine is up, but `docker ps -a` and `docker images` are empty — no containers or images currently. `docker compose` finds no projects. The empty Docker is intended (reserved for future use), not just leftover.

## Solar dashboard

The active service is `solar-dashboard.service`: a uvicorn app (`/root/solar-dashboard/venv/bin/uvicorn main:app`) listening on 8000, with `--proxy-headers --forwarded-allow-ips=10.10.10.200` (i.e. behind NPM at the proxy address). CT 119 is the canonical/prod dashboard; the copy in CT 100 is test-only.

It uses a SQLite DB `solar_data.db` and has a `frontend/` dir. Source in `/root/solar-dashboard` — `main.py`, `solar.py`, `inverter.py`, `config.py`, `database.py`.

Ports:

| Port | Process | Use |
|---:|---|---|
| 8000/tcp | uvicorn | solar dashboard |
| 22/tcp | sshd | SSH |
| 25/tcp | postfix | localhost |

## Backup

CT 119 is intentionally **not** in the B2 job. Solar dashboard data is not part of the protected set.

## Health

- Docker and solar-dashboard running.
- No failures observed.
- Docker is idle (no containers).

## What happens if something fails

| Failure | Effect |
|---|---|
| Solar dashboard stops | Dashboard down until restarted; DB intact. |
| Docker fails | No containers to serve — currently no impact. |
| Container lost | Solar app + DB gone, no backup. |


