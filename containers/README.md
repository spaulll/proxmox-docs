# Container pages

These are the individual container notes. I am doing them one at a time, starting with the pieces
everything else depends on.

**Status:** CT 107, CT 106 and CT 101 are done. CT 105 (NAS) is next. No container has been modified or started.

## Order

| Container | Why |
|---|---|
| [107 adguard](107-adguard.md) | DNS for the host and the lab, done |
| [106 openwrt](106-openwrt.md) | Router, DHCP and DNS forwarding for `10.10.10.0/24`, done |
| [101 npm](101-npm.md) | Reverse proxy and SSL manager, done |
| 101 npm | Reverse proxy |
| 105 NAS | Samba and the data disk |
| 109 immich | Photos and the separate backup flow |
| 104 jellyfin | Media and GPU passthrough |
| 100 opencode | Development environment |
| 102 journal | Journal application |
| 119 monitoring | Docker monitoring stack |
| 108 zerobyte | Restic backups |
| 111 filebrowser | Web file browser |
| 110 tailscale | Remote access |
| 112, 113, 118 | Stopped and skipped at the owner's request |

## What goes into each page

I want each container page to answer the same practical questions:

- What is it, and what does it depend on?
- What OS and resources does it have?
- How is it addressed, and what ports does it listen on?
- Which services or containers are running inside?
- Where does its data live, and is any of it on a bind mount?
- What is backed up, and what would have to be rebuilt?
- Are there scheduled jobs?
- What would I do if it broke?

Config files are summarised where that makes sense. Credentials are never copied into a page. If a
config contains a password or key, the page says where it is and leaves the value out.

CT 112, 113 and 118 are stopped and will be skipped. They are not part of the documentation set unless
that changes later.
