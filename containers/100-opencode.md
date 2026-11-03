# CT 100, opencode

The development container. Where coding agents run and working projects live — including the environment that produced these notes.

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

This is the coding-agent host. It nests — that's why `nesting=1` and `keyctl=1` are set; dev tooling expects them. Load ~1.0, memory ~844 MB used of 6 GB. Disk 9.8/20 GB.

## What runs inside

| Process | What it does |
|---|---|
| `opencode serve --service` | the OpenCode agent service |
| `browser-control-mcp` | browser control MCP bridge (node) |
| `app.main:app` (uvicorn, :8010) | a small local web app (127.0.0.1) |
| `postfix` | mail, localhost |
| `sshd`, `cron` | SSH and scheduled work |

Ports listening:

| Port | Process | Use |
|---|---|---|
| 3000/tcp | node (build) | a leftover dev server, no real purpose |
| 8010/tcp | uvicorn/py | local app, loopback only |
| 22/tcp | sshd | SSH |

The opencode service and node processes are the heaviest — the `opencode serve` daemon uses ~400 MB; an interactive `opencode -c` session adds another ~250 MB. That's the real memory pressure in this container.

## Config

OpenCode config lives in `/root/.config/opencode/` (`opencode.jsonc`, `service.json`, `skills`, etc.). Credential-related values are not recorded here.

## Backup

CT 100 is **not** in the B2 job. The omission is deliberate. No project data here is covered by the weekly job.

## Health

- Services running continuously since Oct 27–29.
- Load fine, memory within limits.
- `postfix` running (queue likely empty).

## What happens if something fails

| Failure | Effect |
|---|---|
| Container stopped/lost | All projects and tooling here are gone. Nothing backs this up. |
| `opencode serve` fails | The agent service is down until restarted; projects intact. |
| `/mnt/nas` mount drops | The mounted media/Downloads tree is unavailable; projects unaffected. |

## Recovery

No automated backup. Rebuilding means re-cloning repos, reinstalling tooling, and recreating the agent config. There is no B2 archive for 100.
