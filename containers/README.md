# Container pages

Individual container notes. One at a time, starting with what everything else depends on.

**Status:** CT 107, 106, 101, 105, 109, 104, 100, 102, 119, 108, 111, 110 are done. Stopped CTs 112, 113, 118 are skipped. No container has been modified or started.

## Pages

| Container | Why |
|---|---|
| [107 adguard](107-adguard.md) | DNS for the host and lab |
| [106 openwrt](106-openwrt.md) | Router, DHCP, DNS forwarding |
| [101 npm](101-npm.md) | Reverse proxy and SSL manager |
| [105 NAS](105-nas.md) | Samba and the data disk |
| [109 immich](109-immich.md) | Photos and the separate backup flow |
| [104 jellyfin](104-jellyfin.md) | Media and GPU passthrough |
| [100 opencode](100-opencode.md) | Development environment |
| [102 journal](102-journal.md) | Journal application (SQLite) |
| [119 monitoring](119-monitoring.md) | Docker monitoring / solar dashboard |
| [108 zerobyte](108-zerobyte.md) | Restic backups (Zerobyte) |
| [111 filebrowser](111-filebrowser.md) | Web file browser |
| [110 tailscale](110-tailscale.md) | Remote access node |
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
