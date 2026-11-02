# CT 100, opencode

The development container. Where I run coding agents and keep working projects — including the very environment that produced these notes.

## Identity and resources

| | |
|---|---|
| Hostname | `opencode` |
| Proxmox ID | 100 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 3 vCPU, 6 GB RAM, 512 MB swap |
| Disk | 20 GB thin volume, 9.8 GB used (53 %) |
| Address | `10.10.10.162` (DHCP) |
| Startup | `onboot: 1`, no order |
| Type | unprivileged, `nesting=1`, `keyctl=1` |
| Backup | **not** in B2 job |

This is the coding-agent host. `opencode serve` runs as a service from `/root/.opencode/bin/`, plus the browser-control MCP bridge. It nests — that's why `nesting=1` and `keyctl=1` are set; dev tooling expects them.

Load ~1.0, memory ~844 MB used of 6 GB. Disk 9.8/20 GB.

## What runs inside

| Process | What it does |
|---|---|
| `opencode serve --service` | the OpenCode agent service |
| `browser-control-mcp` | browser control MCP bridge (node) |
| `app.main:app` (uvicorn, :8010) | a small local web app (127.0.0.1) |
| `solar-dashboard/main.py` | runs a solar dashboard + a simulated inverter |
| `postfix` | mail, localhost |
| `sshd`, `cron` | SSH and scheduled work |

Ports listening:

| Port | Process | Use |
|---:|---|---|
| 3000/tcp | node (build) | something serving on all interfaces |
| 8010/tcp | uvicorn/py | local app, loopback only |
| 22/tcp | sshd | SSH |

The opencode service and node processes are the heaviest — the `opencode serve` daemon uses ~400 MB; an interactive `opencode -c` session adds another ~250 MB. That's the real memory pressure in this container.

## Projects

`/root` holds the working projects:

- `homelab-docs` — this documentation repo
- `solar-dashboard` — solar monitoring dashboard + inverter simulator
- `trading-journal` — trading journal app
- `tvOS-Launcher` — tvOS launcher project
- `go` — Go workspace
- `dns-benchmark.sh` — ad-hoc DNS benchmark script

`/mnt/nas` (host `/mnt/data/public/Downloads`) is mounted in — so the coding environment can reach the media/Downloads tree. Contents mirror the media library (movies, series, anime, YouTube…).

## Config

OpenCode config lives in `/root/.config/opencode/` (`opencode.jsonc`, `service.json`, `skills`, etc.). The agent service is set up to run as a system service. Credential-related values are not recorded here.

## Backup

CT 100 is **not** in the B2 job. This is the container holding all the working projects — the one whose loss would hurt most on the dev side. The omission is deliberate (it's in the "excluded" list), but worth noting: none of the project data here is backed up by the weekly job.

## Health

- Services running continuously since Oct 27–29.
- Load fine, memory within limits.
- `postfix` running (queue likely empty).

## What happens if something fails

| Failure | Effect |
|---|---|
| Container stopped/lost | All projects and tooling in here are gone. Nothing backs this up. |
| `opencode serve` fails | The agent service is down until restarted; projects intact. |
| `/mnt/nas` mount drops | Media tree unavailable to the container; projects unaffected. |

## Recovery

No automated backup. Rebuilding means re-cloning repos, reinstalling tooling, and recreating the agent config. There is no B2 archive for 100.


