# Notes, trade-offs and open questions

This is not a security audit. The homelab is a single-user LAN with no outside users, and security is
deliberately kept simple: no Proxmox firewall rules, root SSH with a password, self-signed certificates.
I am noting those things for completeness, not suggesting a hardening project.

The notes below are the operational things that are more likely to bite: disk health, backup coverage,
dependencies and capacity.

## Accepted as-is

- The Proxmox firewall is disabled. The per-container `firewall=1` flags do not do anything, but there is
  no traffic crossing an untrusted boundary.
- Root can log in over SSH with a password. Fine on this LAN.
- The web UI uses the default self-signed certificate.
- Several services use simple HTTP inside the lab network.
- Cloudflare WARP is installed on the host but disconnected; the dedicated exit container is stopped.

I will not change any of these unless asked.

## Worth keeping an eye on

### The data disk

`/dev/sdb` is a single 480 GB USB-attached drive. It holds the media library, the Immich photos, the
backup staging and the private directory. SMART says PASSED, but it has 3 current pending sectors and
`smartd` logs them every 30 minutes.

USB adds a few failure modes that a normal internal disk does not have: the cable, the enclosure, the
power supply and controller resets. None of that has happened while I was looking, but it is the weakest
part of the storage setup.

### Backup coverage

Seven containers are backed up by design. Nine are intentionally excluded. Bind-mounted data is never in
a container archive, and `/mnt/data/private` does not appear to have any other copy.

The Immich scripts exist but I have not confirmed that they run on a schedule. That is on the list for the
Immich page.

### DNS and the lab router

CT 107 (AdGuard) is the resolver for the host, the NAS and the lab network, but it is not alone. The Pi at
`192.168.0.169` runs a replica and holds the `.147` VIP if CT 107 stops. `adguardhome-sync` copies the
configuration across every two hours. DNS is therefore a pair, although the standby can be up to two hours
behind and keepalived does not check whether AdGuard itself is alive.

The lab router is a different story. CT 106 (OpenWrt) is the only router for every `10.10.10.x` container,
and it runs on `prox`. If it stops, the lab network loses its route to the house LAN and the internet, even
though DNS on the Pi may still be up.

CT 106's firewall configuration is enabled at boot, but it does not load. `fw4 check` fails on a custom
`masq-lan-to-internal` rule that jumps to a `masquerade_to_lan` chain which `fw4` never creates. The
running container has no nftables rules. The lab still works because it is a routed subnet: the main
router has a route for `10.10.10.0/24` via `192.168.0.150`, and no NAT is involved. That is accepted for
now; I have not changed the rule.

### Disk space

The root filesystem was 65 % full and the thin pool 66 % used when I checked. That is not urgent. The easy
wins are the 14 GB of old dumps on `/` and the 16 GB Windows VM image on `/mnt/data`, if the VM is really
gone.

The thin pool has 122 GB of root filesystems provisioned for running containers and another 20 GB for
stopped ones, against a 130.5 GB pool. It works because thin volumes only use what they need, but creating
too many new containers could fill it.

### Pending updates

The Proxmox host had 58 pending package updates, mostly Debian security updates. Unattended upgrades are
not configured there. I have not applied anything. CT 107 itself was up to date.

### Static addresses in the DHCP pool

CT 103, 104, 113 and 118 use static addresses inside OpenWrt's `.100–.249` DHCP range, with no
reservations. dnsmasq usually checks before leasing, so it has not caused a problem, but a reservation
would be cleaner.

### Memory overcommit

The running containers have about 32 GiB of RAM limits on a 15 GiB host. Most of the time that is fine.
Jellyfin, Immich and the dev container are the ones that can be busy together.

## Open questions

1. **Private data.** Is `/mnt/data/private` copied anywhere else? I did not find a backup for it.
2. **Windows dump.** Is `win10-vm.vma.zst` still needed? It is 16 GB and there is no Windows VM on the host
   now.
3. **Keepalived health.** It only checks the interface. If AdGuard dies inside CT 107 but keepalived stays
   up, the VIP does not move. I have not changed it.
4. **Pi certificate.** CT 107's sync job does not list TLS as a synced feature, so I still need to confirm
   how the Pi's `dns.prox.dpdns.org` certificate is issued.
5. **ISP route.** The main router is routing `10.10.10.0/24` to `192.168.0.150`; I inferred that from
   successful traffic but have not logged into the router to see the route. `192.168.0.150` is also a
   static address on CT 106 now, not DHCP.
6. **CT 106 TUN.** The container has `/dev/net/tun` passed through, but I found no VPN package or process
   using it. It may be left over from an earlier setup.

The UPS monitor is described in [../services/ups.md](../services/ups.md). I have not changed its
configuration or the Proxmox shutdown agent.

## What was not changed

Nothing. All commands were read-only: `cat`, `ls`, `pct list`, `pct config`, `pct exec` for reads,
`smartctl`, `pveum ... list`, `systemctl status`, `rclone listremotes` and `uci show`. No files were edited
on `prox`, no services were restarted, and no containers were started or stopped.
