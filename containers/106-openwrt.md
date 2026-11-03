# CT 106, OpenWrt

CT 106 is the router for the lab network. The least glamorous container and the one I'd miss first if it stopped: every `10.10.10.x` guest uses it as gateway, DHCP server, and DNS forwarder. Dual-homed, one foot on `vmbr0`, one on `vmbr1`.

I had the WAN side recorded as DHCP in the inventory. That was wrong. `pct config` has no DHCP setting for `eth0`, and `/etc/config/network` is static. The address has been `192.168.0.150` all along.

## Identity and resources

| | |
|---|---|
| Hostname | `openwrt` |
| Proxmox ID | 106 |
| OS | OpenWrt 24.10.4, revision `r28959-29397011cc`, target `x86/64` |
| Kernel | `7.0.14-20-pve` (host kernel) |
| CPU / RAM / swap | 1 vCPU, 256 MB RAM, 128 MB swap |
| Disk | 4 GB thin volume, 27 MB used (1 %) |
| WAN | `eth0` on `vmbr0`, `192.168.0.150/24`, gateway `192.168.0.1`, DNS `192.168.0.147` |
| LAN | `eth1` on `vmbr1`, `10.10.10.1/24` |
| Startup | `onboot: 1`, `startup: order=1` |
| Type | `ostype: unmanaged`, unprivileged, `/dev/net/tun` passed through |
| Backup | weekly B2 job, 9 MB archive on 2026-10-25 |

OpenWrt runs as an unmanaged container, so Proxmox doesn't use its normal OS integration. `pct exec` works fine. One quirk inside: `free` shows the host's 16 GB of memory and swap because `/proc/meminfo` is the host's. The PVE limit is still enforced by the cgroup. On the host, `/sys/fs/cgroup/lxc/106/memory.max` is 268435456 bytes (256 MB); current usage ~13 MB. Root filesystem almost empty.

`/dev/net/tun` is passed through, but there's no Tailscale, WireGuard, OpenVPN, or ZeroTier package or process inside. Looks like a leftover from an earlier setup; kept as-is.

## Network

| Interface | Bridge | Address | Notes |
|---|---|---|
| `eth0` | `vmbr0` | `192.168.0.150/24` | static WAN, MAC `bc:24:11:f4:cb:85` |
| `eth1` | `vmbr1` | `10.10.10.1/24` | lab gateway, MAC `bc:24:11:f6:b7:48` |

Routes:

```text
default via 192.168.0.1 dev eth0
10.10.10.0/24 dev eth1 scope link
192.168.0.0/24 dev eth0 scope link
```

IPv4 forwarding on. IPv6 forwarding on too, but no global IPv6. OpenWrt has a ULA prefix (`fd50:b4cc:151d::/48`), but neither `eth1` nor lab clients have a ULA address. No IPv6 default route; `odhcpd` logs `No default route present, setting ra_lifetime to 0!` regularly. Noise in an IPv4-only design.

## The firewall does not load

The main surprise here. `firewall4` config exists and the init script is enabled at boot, but no nftables ruleset loads. `nft list ruleset` is empty; `ubus call service list '{"name":"firewall"}'` returns an empty object.

`fw4 check` shows why:

```text
/dev/stdin:117:33-49: Error: Could not process rule: No such file or directory
        meta l4proto tcp counter jump masquerade_to_lan comment "!fw4: masq-lan-to-internal"
                              ^^^^^^^^^^^^^^^^^
/dev/stdin:118:33-49: Error: Could not process rule: No such file or directory
        meta l4proto udp counter jump masquerade_to_lan comment "!fw4: masq-lan-to-internal"
```

The custom `masq-lan-to-internal` rule jumps to a `masquerade_to_lan` chain `fw4` never creates. The rule is a `config rule` from WAN to LAN with `target MASQUERADE`; no zone has `option masq '1'`, so the chain is missing. The check fails, so the whole ruleset never applies.

The on-disk config is also open:

- defaults: input, output, forward all `ACCEPT`
- both `lan` and `wan` zones accept everything
- forwarding enabled both `lan`→`wan` and `wan`→`lan`
- a rule allows TCP 80 from WAN to the router
- the custom masquerade rule is the only NAT rule

Net result: CT 106 does **not** NAT the lab. It's a routed subnet. The main router routes `10.10.10.0/24` back to `192.168.0.150`, so lab traffic keeps its `10.10.10.x` source all the way out. Confirmed two ways:

- from CT 101, `traceroute 1.1.1.1` goes `10.10.10.1` then `192.168.0.1`
- from `prox`, a ping to `10.10.10.200` works, and a capture on `vmbr0` shows source `10.10.10.200`, reply straight back

At capture the host even had a cached redirect sending `10.10.10.200` via `192.168.0.150`. The route is a deliberate static entry on the ISP router, pointing at `192.168.0.150` (owner-confirmed).

So one NAT layer, on the ISP router, not two. An inbound port forward to a lab container only needs a rule on the main router. CT 106 just forwards. Main router rules not documented.

Left the broken firewall rule alone. Recorded as-is, not as a hardening task.

## DHCP and DNS

`dnsmasq` is the DHCP server and DNS forwarder. Generated config:

| Setting | Value |
|---|---|
| DHCP range | `10.10.10.100` to `10.10.10.249` |
| Lease time | 12 hours |
| DHCP on WAN | disabled, `no-dhcp-interface=eth0` |
| DNS upstream | `192.168.0.147` (AdGuard VIP), `noresolv=1` |
| Local domain | `lan`, dnsmasq authoritative |
| Cache | 1000 entries |
| AAAA records | filtered, `filter_aaaa=1` |
| Rebind exception | `myownserv.duckdns.org` |
| Query logging | on, extra detail |

No static reservations in dnsmasq. Active leases at capture:

| Address | Name | MAC |
|---|---|
| `10.10.10.144` | filebrowser | `bc:24:11:45:c4:40` |
| `10.10.10.149` | journal | `bc:24:11:64:d3:81` |
| `10.10.10.162` | opencode | `bc:24:11:b9:f6:98` |
| `10.10.10.200` | npm | `bc:24:11:01:d4:82` |
| `10.10.10.230` | zerobyte | `bc:24:11:b3:0d:75` |
| `10.10.10.234` | immich | `bc:24:11:60:78:8f` |
| `10.10.10.246` | monitoring | `bc:24:11:69:3d:01` |

CT 103, 104, 113, 118 use static addresses in the same range and don't appear in the lease file. The lease file is in `/tmp`, so it's lost on restart; clients renew when they need to.

DNS works as expected. `openwrt.lan` resolves to `10.10.10.1`; `example.com` forwards to `192.168.0.147` and returns A records only. If AdGuard is down, local names still answer from lease data, but external names fail. The house LAN has its own keepalived pair, so the lab isn't the only DNS path.

`odhcpd` also runs for DHCPv6 and router advertisements on the lab, listening on UDP 547. No IPv6 default route means the `ra_lifetime` warning keeps appearing. Not doing useful work in the current setup.

## What runs inside

| Service | Port | What it does |
|---|---:|---|
| `dnsmasq` | 53/tcp, 53/udp | DNS forwarder for the lab and WAN side |
| `dnsmasq` | 67/udp | DHCP for `10.10.10.0/24` |
| `odhcpd` | 547/udp | DHCPv6 and router advertisements |
| `uhttpd` | 80/tcp, 443/tcp | LuCI web interface |
| `dropbear` | 22/tcp | SSH |
| `nlbwmon` | — | per-host bandwidth accounting |
| `rpcd` | — | ubus RPC |
| `netifd` | — | network configuration |

`uhttpd` serves LuCI on HTTP and HTTPS. `luci-ssl` installed; cert is the local one in `/etc/uhttpd.crt`. `redirect_https` off, so both ports stay open. Dropbear allows root password login on 22. Consistent with the rest of the setup.

NTP disabled in `/etc/config/system` — deliberate, since the container takes time from the host kernel. `sysntpd` init script is linked in `/etc/rc.d`, but no NTP process runs. Cron is linked too, but no `crond` process and root's crontab is empty — no scheduled jobs.

138 opkg packages. Versions: `dnsmasq 2.90-r4`, `firewall4 2024.12.18~18fc0ead-r1`, `dropbear 2024.86-r1`, `uhttpd 2025.07.06~7e64e8ba-r4`, `odhcpd-ipv6only 2025.10.02~b14cf98c-r1`, `nlbwmon 2024.02.21~c7616bcf-r1`, LuCI `25.292.66247~75e41cb`.

`nlbwmon` keeps its database under `/var/lib/nlbwmon`, inside the root filesystem — so it's in the backup.

## Data and backups

No data bind mounts. The only host mount is `/dev/net`, for the TUN device. Everything else lives in the 4 GB root filesystem: OpenWrt config in `/etc/config`, nlbwmon db in `/var/lib/nlbwmon`, LuCI cert. DHCP leases and runtime state are in `/tmp`, not persistent.

Weekly B2 job includes CT 106. Archive from 2026-10-25: 9 MB. Restoring brings back network, DHCP, DNS, firewall config, nlbwmon data. The lease table rebuilds as clients renew.

## Health and logs

At capture: up four days five hours, load 0.23/0.43/0.43, ~13 MB memory against 256 MB limit, root 1 % full.

Log dominated by dnsmasq query lines (`logqueries` on) plus 26 `odhcpd` router-advertisement warnings. Log buffer is only 128 KB, so the oldest entries roll off fast. No separate firewall error in the log; the `fw4 check` output above is the useful evidence.

`free` is misleading here — it reports the host's memory and swap, not the container's 256 MB limit. Use the PVE config or cgroup values on the host.

## What happens if something fails

| Failure | Effect |
|---|---|
| CT 106 stops | The lab loses gateway, DHCP, DNS. Same-subnet traffic still works; nothing reaches the house LAN or internet. House LAN and host otherwise unaffected. |
| `dnsmasq` stops | DNS and DHCP renewals fail. Existing leases hold until they expire; routing keeps working. |
| `odhcpd` stops | No DHCPv6 or router advertisements. No usable IPv6 anyway, so no practical impact. |
| `192.168.0.147` down | External DNS fails (dnsmasq has no other upstream). Local names from leases still resolve. |
| Main router's `10.10.10.0/24` route disappears | Lab clients keep local network, lose internet and house-LAN access. |
| `prox` stops | CT 106 stops with it. The Pi keeps the house-LAN DNS VIP, but the lab has no router. |
| Someone fixes the `fw4` rule | The firewall starts applying its open accept rules. Still no NAT — no zone has masquerading enabled. |

## Recovery and checks

The archive is small. Restore like the others, start it, check the two interfaces first.

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

After a restore, verify the static WAN address, default route, dnsmasq upstream, and whether the `fw4` error is still present. The lease table can be empty for a few minutes without meaning anything's wrong.

## Change log

| Date | Change |
|---|---|
| 2026-10-31 | First version. Corrected WAN from DHCP to static `.150`, documented routed lab and `fw4` failure. |

No files or services changed on the container. Everything from `pct config`, `cat`, `ip`, `netstat`, `ps`, `ubus`, `opkg`, `fw4 check`, `nft`, `tcpdump`, read-only log inspection.
