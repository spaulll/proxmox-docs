# Reverse proxy

Nginx Proxy Manager on CT 101 fronts the internal web services. It's the entry point for the `.myownserv.duckdns.org` names.

## The proxy

- CT 101 (NPM) at `10.10.10.200`, port 80/443 (see [containers/101-npm.md](../containers/101-npm.md)).
- AdGuard rewrites `*.myownserv.duckdns.org` → `10.10.10.200`, so the internal name for the proxy is the wildcard.
- NPM also serves the admin UI on port 81 (not 443).

## Proxy hosts

14 proxy-host configs exist in `/data/nginx/proxy_host/` (verified 2026-11-03, not 15):

| Host | Upstream |
|---|---|
| `npm.myownserv.duckdns.org` | `10.10.10.200:81` (admin) |
| `dns.myownserv.duckdns.org` | `192.168.0.169:8080` (Pi AdGuard) |
| `files.myownserv.duckdns.org` | `10.10.10.144:8080` (CT 111 filebrowser) |
| `asus.myownserv.duckdns.org` | `192.168.0.1:8443` (router, HTTPS) |
| `asus.lan` | `192.168.0.1:8443` (router, HTTPS) |
| `solar.myownserv.duckdns.org` | `10.10.10.246:8000` (CT 119 monitoring) |
| `zerobyte.myownserv.duckdns.org` | `10.10.10.230:4096` (CT 108) |
| `ntfy.myownserv.duckdns.org` | `192.168.0.169:2586` (Pi ntfy) |
| `journal.myownserv.duckdns.org` | `10.10.10.149:3000` (CT 102 frontend) |
| `immich.myownserv.duckdns.org` | `10.10.10.234:2283` (CT 109) |
| `jellyfin.myownserv.duckdns.org` | `10.10.10.201:8096` (CT 104) |
| `prox.myownserv.duckdns.org` | `192.168.0.50:8006` (Proxmox UI, HTTPS) |

## SSL

- NPM manages Let's Encrypt certs via `npm.service` (automatic renewal, hourly check).
- Cert store: `/etc/letsencrypt/live/npm-2/`; custom SSL in `/data/custom_ssl/npm-3/`. Verified 2026-11-03: `npm-3` is used by exactly one host — `asus.lan` (router admin); every other host uses the LE `npm-2` cert.
- Certs live inside the container rootfs, so they restore with a B2 restore.

## Notes

- The `prox` upstream (Proxmox UI) is HTTPS — NPM terminates it. 
- Upstreams see the real client IP (X-Real-IP / X-Forwarded-For set).
- Admin authentication is required; credentials are not in this repo.


