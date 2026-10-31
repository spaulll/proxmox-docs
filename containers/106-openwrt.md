# CT 106, OpenWrt

CT 106 is the router for the lab network. It is the least glamorous container and the one I would miss
first if it stopped: every `10.10.10.x` guest uses it as its gateway, DHCP server and DNS forwarder. It is
dual-homed, with one foot on `vmbr0` and the other on `vmbr1`.

I had the WAN side recorded as DHCP in the inventory. That was wrong. `pct config` has no DHCP setting for
`eth0`, and `/etc/config/network` is a static configuration. The address has been `192.168.0.150` all
along.

## Identity and resources

| | |
|---|---|
| Hostname | `openwrt` |
| Proxmox ID | 106 |
| OS | OpenWrt 24.10.4, revision `r28959-29397011cc`, target `x86/64` |
| Kernel | `7.0.14-20-pve` (the host kernel) |
| CPU / RAM / swap | 1 vCPU, 256 MB RAM, 128 MB swap |
| Disk | 4 GB thin volume, 27 MB used (1 %) |
| WAN | `eth0` on `vmbr0`, `192.168.0.150/24`, gateway `192.168.0.1`, DNS `192.168.0.147` |
| LAN | `eth1` on `vmbr1`, `10.10.10.1/24` |
| Startup | `onboot: 1`, `startup: order=1` |
| Type | `ostype: unmanaged`, unprivileged, `/dev/net/tun` passed through |
| Backup | weekly B2 job, 9 MB archive on 2026-10-25 |

OpenWrt runs as an unmanaged container, so Proxmox does not use its normal OS integration. `pct exec` works
fine. The inside of the container has one quirk: `free` shows the host's 16 GB of memory and swap, because
`/proc/meminfo` is the host's. The PVE limit is still enforced by the cgroup. On the host,
`/sys/fs/cgroup/lxc/106/memory.max` is 268435456 bytes (256 MB) and the current usage was about 13 MB.
The root filesystem is almost empty.

The container has `/dev/net/tun` passed through, but I found no Tailscale, WireGuard, OpenVPN or ZeroTier
package or process inside. It looks like a leftover from an earlier setup.

## Network

| Interface | Bridge | Address | Notes |
|---|---|---|---|
| `eth0` | `vmbr0` | `192.168.0.150/24` | static WAN, MAC `bc:24:11:f4:cb:85` |
| `eth1` | `vmbr1` | `10.10.10.1/24` | lab gateway, MAC `bc:24:11:f6:b7:48` |

The routes are simple:

```text
default via 192.168.0.1 dev eth0
10.10.10.0/24 dev eth1 scope link
192.168.0.0/24 dev eth0 scope link
```

IPv4 forwarding is on. IPv6 forwarding is also on, but there is no global IPv6. OpenWrt has a ULA prefix
configured (`fd50:b4cc:151d::/48`), but neither `eth1` nor the lab clients have a ULA address. There is no
IPv6 default route, and `odhcpd` logs `No default route present, setting ra_lifetime to 0!` on a regular
basis. It is noise in an IPv4-only design.

## The firewall does not load

This is the main surprise on this container. The `firewall4` configuration exists and the firewall init
script is enabled at boot, but no nftables ruleset is loaded. `nft list ruleset` is empty, and
`ubus call service list '{"name":"firewall"}'` returns an empty object.

`fw4 check` shows why:

```text
/dev/stdin:117:33-49: Error: Could not process rule: No such file or directory
        meta l4proto tcp counter jump masquerade_to_lan comment "!fw4: masq-lan-to-internal"
                              ^^^^^^^^^^^^^^^^^
/dev/stdin:118:33-49: Error: Could not process rule: No such file or directory
        meta l4proto udp counter jump masquerade_to_lan comment "!fw4: masq-lan-to-internal"
```

The custom `masq-lan-to-internal` rule jumps to a `masquerade_to_lan` chain that `fw4` never creates. The
rule is a `config rule` from WAN to LAN with `target MASQUERADE`; no zone has `option masq '1'`, so the
chain is missing. Because the check fails, the whole ruleset is never applied.

The configuration on disk is also open:

- defaults: input, output and forward are all `ACCEPT`
- both the `lan` and `wan` zones accept everything
- forwarding is enabled both `lan` to `wan` and `wan` to `lan`
- there is a rule allowing TCP port 80 from the WAN side to the router
- the custom masquerade rule is the only NAT rule

The practical result is that CT 106 currently does **not** NAT the lab network. It is a routed subnet.
The main router routes `10.10.10.0/24` back to `192.168.0.150`, so lab traffic keeps its `10.10.10.x`
source address all the way out. I confirmed this two ways:

- from CT 101, `traceroute 1.1.1.1` goes `10.10.10.1` then `192.168.0.1`
- from `prox`, a ping to `10.10.10.200` works, and a capture on `vmbr0` shows the request arriving with
  source `10.10.10.200` and the reply going straight back to it

At capture, the host even had a cached redirect sending `10.10.10.200` via `192.168.0.150`. I did not log
into the ISP router to see the route, but the traffic path is clear.

That means there is one NAT layer, on the ISP router, not two. An inbound port forward to a lab container
only needs a rule on the main router. CT 106 just forwards the packets. I have not documented the main
router's rules.

I left the broken firewall rule alone. It is recorded here as it is, not as a hardening task.

## DHCP and DNS

`dnsmasq` is the DHCP server and DNS forwarder. Its generated configuration has the important bits:

| Setting | Value |
|---|---|
| DHCP range | `10.10.10.100` to `10.10.10.249` |
| Lease time | 12 hours |
| DHCP on WAN | disabled with `no-dhcp-interface=eth0` |
| DNS upstream | `192.168.0.147` (AdGuard VIP), with `noresolv=1` |
| Local domain | `lan`, with dnsmasq authoritative for it |
| Cache | 1000 entries |
| AAAA records | filtered with `filter_aaaa=1` |
| Rebind exception | `myownserv.duckdns.org` |
| Query logging | on, with extra detail |

There are no static reservations in dnsmasq. The active leases at capture were:

| Address | Name | MAC |
|---|---|---|
| `10.10.10.144` | filebrowser | `bc:24:11:45:c4:40` |
| `10.10.10.149` | journal | `bc:24:11:64:d3:81` |
| `10.10.10.162` | opencode | `bc:24:11:b9:f6:98` |
| `10.10.10.200` | npm | `bc:24:11:01:d4:82` |
| `10.10.10.230` | zerobyte | `bc:24:11:b3:0d:75` |
| `10.10.10.234` | immich | `bc:24:11:60:78:8f` |
| `10.10.10.246` | monitoring | `bc:24:11:69:3d:01` |

CT 103, 104, 113 and 118 use static addresses inside the same range and do not appear in the lease file.
The lease file is in `/tmp`, so it is lost on a container restart; clients renew when they need to.

DNS works as expected. `openwrt.lan` resolves to `10.10.10.1`, and `example.com` is forwarded to
`192.168.0.147` and returns A records only. If AdGuard is down, local names can still be answered from the
lease data, but external names fail. The house LAN has its own keepalived pair, so the lab is not the only
DNS path.

`odhcpd` is also running for DHCPv6 and router advertisements on the lab. It listens on UDP 547. Because
there is no IPv6 default route, it keeps logging the `ra_lifetime` warning. It is not doing useful work in
the current setup.

## What runs inside

| Service | Port | What it does |
|---|---:|---|
| `dnsmasq` | 53/tcp, 53/udp | DNS forwarder for the lab and the WAN side |
| `dnsmasq` | 67/udp | DHCP server for `10.10.10.0/24` |
| `odhcpd` | 547/udp | DHCPv6 and router advertisements |
| `uhttpd` | 80/tcp, 443/tcp | LuCI web interface |
| `dropbear` | 22/tcp | SSH |
| `nlbwmon` | — | per-host bandwidth accounting |
| `rpcd` | — | ubus RPC |
| `netifd` | — | network configuration |

`uhttpd` serves LuCI on both HTTP and HTTPS. `luci-ssl` is installed and the certificate is the local one
in `/etc/uhttpd.crt`; `redirect_https` is off, so both ports stay open. Dropbear allows root password login
on port 22. That is consistent with the rest of the setup.

NTP is disabled in `/etc/config/system`. The `sysntpd` init script is linked in `/etc/rc.d`, but no NTP
process was running; the container takes its time from the host kernel. Cron is also linked in
`/etc/rc.d`, but I found no `crond` process and root's crontab was empty, so there are no scheduled jobs.

There are 138 opkg packages. The relevant versions are `dnsmasq 2.90-r4`, `firewall4
2024.12.18~18fc0ead-r1`, `dropbear 2024.86-r1`, `uhttpd 2025.07.06~7e64e8ba-r4`, `odhcpd-ipv6only
2025.10.02~b14cf98c-r1`, `nlbwmon 2024.02.21~c7616bcf-r1` and LuCI `25.292.66247~75e41cb`. I did not run
`opkg update`, so I cannot say how many updates are pending.

`nlbwmon` keeps its database under `/var/lib/nlbwmon`. It is inside the container root filesystem, so it
is included in the backup.

## Data and backups

There are no data bind mounts. The only host mount is `/dev/net`, which PVE passes in for the TUN device.
Everything else lives in the 4 GB root filesystem: the OpenWrt configuration in `/etc/config`, the
nlbwmon database in `/var/lib/nlbwmon`, and the LuCI certificate. The DHCP leases and runtime state are
in `/tmp` and are not persistent.

The weekly B2 job includes CT 106. The archive from 2026-10-25 was 9 MB. Restoring it brings back the
network, DHCP, DNS, firewall configuration and nlbwmon data. The lease table rebuilds itself as clients
renew.

## Health and logs

At capture the container had been up for four days and five hours. Load average was 0.23, 0.43 and 0.43.
Memory use was about 13 MB against the 256 MB limit. The root filesystem was 1 % full.

The log was dominated by dnsmasq query lines because `logqueries` is on, plus 26 occurrences of the
`odhcpd` router-advertisement warning. The log buffer is only 128 KB, so the oldest entries roll off
quickly. I did not find a separate firewall error in the log; the `fw4 check` output above is the useful
evidence.

`free` is misleading inside this container. It reports the host's memory and swap, not the container's
256 MB limit. Use the PVE config or the cgroup values on the host when checking memory.

## What happens if something fails

| Failure | Effect |
|---|---|
| CT 106 stops | The lab loses its gateway, DHCP and DNS. Same-subnet traffic still works, but nothing can reach the house LAN or internet. The house LAN and Proxmox host are otherwise unaffected. |
| `dnsmasq` stops | DNS and DHCP renewals fail. Existing leases remain until they expire, and routing keeps working. |
| `odhcpd` stops | No DHCPv6 or router advertisements. There is no usable IPv6 anyway, so the practical impact is nil. |
| `192.168.0.147` is down | External DNS fails because dnsmasq has no other upstream. Local names from leases still resolve. |
| The main router's `10.10.10.0/24` route disappears | Lab clients keep their local network but lose internet and house-LAN access. |
| `prox` stops | CT 106 stops with it. The Pi keeps the house-LAN DNS VIP, but the lab has no router. |
| Someone fixes the `fw4` rule | The firewall would start applying its open accept rules. It still would not NAT, because no zone has masquerading enabled. |

## Recovery and checks

The archive is small. Restore it the same way as the other containers, start it, and check the two
interfaces before anything else.

```bash
pct config 106
pct exec 106 -- cat /etc/config/network
pct exec 106 -- cat /etc/config/dhcp
pct exec 106 -- fw4 check
pct exec 106 -- nft list ruleset
pct exec 106 -- cat /tmp/dhcp.leases
pct exec 106 -- logread | tail -50
pct exec 106 -- opkg list-installed | wc -l

# from a lab container
pct exec 101 -- ping -c1 1.1.1.1
pct exec 101 -- nslookup openwrt.lan 10.10.10.1
```

The first things to verify after a restore are the static WAN address, the default route, the dnsmasq
upstream and whether the `fw4` error is still present. The lease table can be empty for a few minutes
without meaning anything is wrong.

## Open questions

- Was the `masq-lan-to-internal` rule ever meant to work? It looks like an old attempt to hide main-LAN
  sources when reaching the lab, and it currently prevents the whole firewall from loading.
- Is `192.168.0.150` reserved on the ISP router, or is it a static address outside the DHCP pool? I have
  not logged into the router to check.
- Is the main router's `10.10.10.0/24` route deliberate and documented? It is what makes the routed lab
  work without NAT.
- Why does CT 106 have `/dev/net/tun` passed through when no VPN package is installed?
- Is disabling NTP deliberate? The container shares the host clock, so it is not causing a problem.
- How many opkg updates are pending? I did not refresh the package lists.

## Change log

| Date | Change |
|---|---|
| 2026-10-31 | First version. Corrected the WAN from DHCP to static `.150`, documented the routed lab and the `fw4` failure. |

No files or services were changed on the container. Everything here came from `pct config`, `cat`,
`ip`, `netstat`, `ps`, `ubus`, `opkg`, `fw4 check`, `nft`, `tcpdump` and read-only log inspection.
