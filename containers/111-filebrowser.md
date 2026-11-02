# CT 111, filebrowser

Web file browser over the data disk. A simple way to browse/manage the shared files through the browser, using FileBrowser Quantum.

## Identity and resources

| | |
|---|---|
| Hostname | `filebrowser` |
| Proxmox ID | 111 |
| OS | Debian 13 (trixie) |
| CPU / RAM / swap | 1 vCPU, 512 MB RAM, 512 MB swap |
| Disk | 8 GB thin volume, 1.7 GB used (23 %) |
| Address | `10.10.10.144` (DHCP) |
| Startup | `onboot: 1`, no order |
| Type | unprivileged |
| Backup | **not** in B2 job |

Uptime 5 days 21 hours, load ~0.79, memory ~70 MB of 512 MB.

## FileBrowser Quantum

The service is `filebrowser.service` running `filebrowser -c /usr/local/community-scripts/fq-config.yaml`.

Config (`fq-config.yaml`) highlights:

- Server port 8080, source root `/mnt/smb` named "NAS"
- Indexing every 240 minutes, `denyByDefault: false`
- `neverWatchPath` excludes system/proc paths
- Auth: `noauth: false` — login required (users/passwords not shown)

## Mounts

- `/mnt/smb` → host `/mnt/data` (the whole data disk). Contains `public/`, `private/`, `lost+found`.
- `/usr/local/community-scripts/tmp` → same disk (`/mnt/data/public/.filebrowser-tmp`), a small upload staging area.

So the browser sees the full data disk as `/mnt/smb`.

## Ports

| Port | Process | Use |
|---:|---|---|
| 8080/tcp | filebrowser | web UI |
| 22/tcp | sshd | SSH |
| 25 | postfix | localhost |

## Backup

CT 111 is **not** in the B2 job. The config is small; the data is the bind-mounted `/mnt/data`.

## Health

- Service running.
- Nothing failing.

## What happens if something fails

| Failure | Effect |
|---|---|
| filebrowser stops | Web file manager down; data safe on disk. |
| Container lost | Recreate config; data unaffected (bind mount). |

## Open questions

- Login auth uses users defined where? (FileBrowser user db — not read).
- Upload staging → `/usr/local/community-scripts/tmp` — is that a deliberate upload landing zone?
