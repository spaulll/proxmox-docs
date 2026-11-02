# Reverse proxy

Nginx Proxy Manager on CT 101 fronts the internal web services. It's the entry point for the `.myownserv.duckdns.org` names.

## The proxy

- CT 101 (NPM) at `10.10.10.200`, port 80/443 (see [containers/101-npm.md](../containers/101-npm.md)).
- AdGuard rewrites `*.myownserv.duckdns.org` → `10.10.10.200`, so the internal name for the proxy is the wildcard.
- NPM also serves the admin UI on port 81 (not 443).

## Proxy hosts (partial)

15 proxy-host configs exist. The ones identified:

| Host | Upstream |
|---|---|
| `npm.myownserv.duckdns.org` | `10.10.10.200:81` (admin) |
| `jellyfin.myownserv.duckdns.org` | `10.10.10.201:8096` |
| `immich.myownserv.duckdns.org` | `10.10.10.234:2283` |
| `prox.myownserv.duckdns.org` | `192.168.0.50:8006` (Proxmox UI, HTTPS) |
| `asus.lan` | `192.168.0.1:8443` |
| `journal.myownserv.duckdns.org` | `10.10.10.149` (frontend 3000 / backend 8000) |

The remaining 10 proxy-host files are not yet identified.

## SSL

- NPM manages Let's Encrypt certs via `npm.service` (automatic renewal, hourly check).
- Cert store: `/etc/letsencrypt/live/npm-2/`; custom SSL in `/data/custom_ssl/npm-3/`.
- Certs live inside the container rootfs, so they restore with a B2 restore.

## Notes

- The `prox` upstream (Proxmox UI) is HTTPS — NPM terminates it. 
- Upstreams see the real client IP (X-Real-IP / X-Forwarded-For set).
- Admin authentication is required; credentials are not in this repo.


