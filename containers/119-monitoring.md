# CT 119, monitoring

Docker host, tagged as the monitoring stack. In practice it's running a solar dashboard right now, not a Prometheus/Grafana stack.

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

The Docker engine is up, but `docker ps -a` and `docker images` are empty — no containers or images currently. `docker compose` finds no projects. So the "monitoring stack" tag is aspirational; nothing's actually deployed under Docker right now.

## Solar dashboard

The active service is `solar-dashboard.service`: a uvicorn app (`/root/solar-dashboard/venv/bin/uvicorn main:app`) listening on 8000, with `--proxy-headers --forwarded-allow-ips=10.10.10.200` (i.e. behind NPM at the proxy address).

It uses a SQLite DB `solar_data.db` and has a `frontend/` dir. Source in `/root/solar-dashboard` — `main.py`, `solar.py`, `inverter.py`, `config.py`, `database.py`.

Ports:

| Port | Process | Use |
|---:|---|---|
| 8000/tcp | uvicorn | solar dashboard |
| 22/tcp | sshd | SSH |
| 25/tcp | postfix | localhost |

## Backup

CT 119 is **not** in the B2 job. The solar dashboard app and its SQLite DB are not backed up.

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

## Open questions

- The tag says "monitoring" (Prometheus/Grafana), but nothing's deployed in Docker. Was the stack removed, or never set up here?
- The solar dashboard (also running inside CT 100) appears twice across containers — is one canonical?
- Not backed up despite holding a SQLite DB.
