# Container pages

Individual container notes. One at a time, starting with what everything else depends on.

**Status:** CT 107, 106, 101, 105 are done. CT 109 (Immich) is next. No container has been modified or started.

## Order

| Container | Why |
|---|---|
| [107 adguard](107-adguard.md) | DNS for the host and lab, done |
| [106 openwrt](106-openwrt.md) | Router, DHCP, DNS forwarding for `10.10.10.0/24`, done |
| [101 npm](101-npm.md) | Reverse proxy and SSL manager, done |
| [105 NAS](105-nas.md) | Samba, NFS and the data disk, done |
| 109 immich | Photos and the separate backup flow |
| 104 jellyfin | Media and GPU passthrough |
| 100 opencode | Development environment |
| 102 journal | Journal application |
| 119 monitoring | Docker monitoring stack |
| 108 zerobyte | Restic backups |
| 111 filebrowser | Web file browser |
| 110 tailscale | Remote access |
| 112, 113, 118 | Stopped, skipped at my request |

## What goes into each page

Each container page should answer the same practical questions:

- What is it, and what does it depend on?
- What OS and resources does it have?
- How is it addressed, what ports does it listen on?
- Which services are running inside?
- Where does its data live, and is any on a bind mount?
- What's backed up, and what would have to be rebuilt?
- Are there scheduled jobs?
- What would I do if it broke?

Config files are summarised where it makes sense. Credentials are never copied into a page. If a config holds a password or key, the page says where it is and leaves the value out.

CT 112, 113, 118 are stopped and skipped. Not part of the set unless that changes later.
