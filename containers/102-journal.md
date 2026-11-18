# CT 102, journal

The trading journal web app. Backend (FastAPI) + frontend (SvelteKit), serving `journal.lan` / `journal.myownserv.duckdns.org`. Repo: https://github.com/spaulll/trading-journal.

## Identity and resources

| | |
|---|---|
| Hostname | `journal` |
| Proxmox ID | 102 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 2 vCPU, 2 GB RAM, 512 MB swap |
| Disk | 8 GB thin volume, 2.7 GB used (36 %) |
| Address | `10.10.10.149` (DHCP = `journal.lan`) |
| Startup | `onboot: 1`, no order |
| Type | unprivileged |
| Backup | **not** in B2 job |

Serves `journal.myownserv.duckdns.org`. The frontend is built with `ORIGIN=https://journal.myownserv.duckdns.org` and `PUBLIC_API_BASE` pointing at the same host, with the backend on loopback 8000.

Uptime 5 days 21 hours, load ~1.14, memory 147 MB of 2 GB. Disk 2.7/8 GB.

## What runs inside

| Service | What it does |
|---|---|
| `journal-backend.service` | FastAPI backend, uvicorn on 8000 |
| `journal-frontend.service` | SvelteKit frontend, node on 3000 |
| `postfix` | local mail |
| `sshd`, `cron` | SSH, cron |

Ports:

| Port | Process | Use |
|---|---|---|
| 3000/tcp | node | frontend (SvelteKit) |
| 8000/tcp | uvicorn | backend API |
| 22/tcp | sshd | SSH |
| 25/tcp | postfix | localhost only |

## App layout

`/root/trading-journal`:

- `backend/` — FastAPI app, `venv`, tests (`pytest.ini`, `tests/`), and SQLite DB `data/journal.db` (+ `-wal`/`-shm`)
- `frontend/` — SvelteKit build
- `deploy.sh`, `run.sh` — deployment scripts

The DB is SQLite, stored in the backend data dir — inside the container rootfs.

## Notable features

- **Telegram-first logging** — open, trail, and close trades with one-line messages and inline buttons. Photos sent to the bot attach to the open trade.
- **Immich screenshots** — chart screenshots upload to Immich (CT 109), auto-organized into monthly `YYYY-MM Trades` albums with SHA dedupe. The Immich API key lives in `backend/.env`, server-side only.
- **Prop-firm accounts** — challenge/funded/personal with daily-loss, max-loss, and profit-target limits; live room-left and breach status.
- **Analytics** — equity curve, drawdown, R distribution, heatmap calendars, tag performance, streaks, session profiles.
- **Guardrails** — stale-trade nudges, nightly EOD recap prompt, breach alerts.

## Unit files

`journal-backend.service` and `journal-frontend.service` are simple systemd units, both `Restart=always`. Frontend waits on backend, set `ORIGIN` and `BACKEND_URL` from env.

## Backup

CT 102 is **not** in the B2 job — a deliberate exclusion. The app, its code, and the SQLite journal DB are not backed up by the weekly job.

## Health

- Both services running.
- No significant errors observed.

## What happens if something fails

| Failure | Effect |
|---|---|
| Backend stops | API down, frontend can't load data. |
| Container lost | The journal DB and code are gone. No backup. |

## Recovery

No automated backup. The journal data (SQLite) lives only in this container. Would need a manual copy.


