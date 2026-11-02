# Backups and restores

Proxmox's own backup scheduler isn't used. A shell script on the host dumps selected containers, checks the archives, and uploads them to Backblaze B2 via rclone with encryption.

Last successful run: 2026-10-25, ~40 minutes. The next one is Sunday at 03:00.

## The short version

- `lxc-backup-b2.sh` runs from root's crontab every Sunday at 03:00.
- Dumps seven containers with `vzdump --mode snapshot --compress zstd`.
- Each archive is tested with `zstd -t` before upload.
- Uploads go to `b2lxccrypt:prox-lxc-backups/<container>/`.
- Only one archive per container is kept in B2. Old ones are deleted after the new upload succeeds.
- A Telegram message reports success or failure.
- If a run is interrupted, the state file lets it resume at boot or on the next cron run.

## What is covered

| Container | Archive size on 2026-10-25 |
|---|---:|
| CT 107 adguard | 330 MB |
| CT 101 npm | 597 MB |
| CT 106 openwrt | 9 MB |
| CT 105 NAS | 76 MB |
| CT 103 aria2 | 564 MB |
| CT 110 tailscale | 305 MB |
| CT 109 immich | 3.2 GB |

That's 7 of 16 containers. Not covered: 100, 102, 104, 108, 111, 112, 113, 118, 119. The selection is deliberate — infrastructure and the services that matter most for recovery. The other nine are intentionally left out. The omissions that would hurt most: CT 100 (dev work), CT 102 (journal), CT 104 (Jellyfin settings), CT 119 (monitoring dashboards). Not changing the list unless something else changes.

## What is not in the archives

`vzdump` skips bind mounts. The CT 109 log says it plainly:

```text
including mount point rootfs ('/') in backup
excluding bind mount point mp0 ('/mnt/nas') from backup (not a volume)
```

So these are outside every container backup:

| Data | Where | Protection |
|---|---|
| Media and downloads | `/mnt/data/public/Downloads` | none, but mostly replaceable |
| Immich library | `/mnt/data/public/immich` | separate Immich scripts, schedule not confirmed |
| Private files | `/mnt/data/private` | none found |
| Syncthing data | `/mnt/data/public/syncthing` | none found |
| Windows VM dump | `/mnt/data/public/backups/win10-vm.vma.zst` | local only, from May |

The private directory is the one I'd want a second copy of.

## How the script works

1. Take a lock so two runs can't overlap.
2. Create or read `/var/lib/lxc-backup/run.state`, one line per container.
3. For each container in the list:
   - skip if already marked done;
   - remove the previous local dump;
   - run `vzdump` into `/mnt/data/public/backups/lxc`;
   - test with `zstd -t`;
   - rename to `<name>-<id>-<timestamp>.tar.zst`;
   - upload to B2;
   - only after a successful upload, delete older copies for that container.
4. Clean up old hidden versions in the bucket.
5. Send a Telegram summary with sizes and duration.

The state file matters. If the host reboots mid-run, `lxc-backup-resume.service` waits 45 seconds after boot and runs the script again, retrying only pending containers.

Logs: `/var/log/lxc-backup-b2.log`. Truncated at the start of each run, so it only holds the most recent one. The staging directory keeps current archives plus a lot of old `.log` files from previous runs.

## The last run

| | |
|---|---|
| Started | 2026-10-25 18:53 |
| Finished | 2026-10-25 19:33 |
| Duration | 40 min 36 s |
| B2 before | 7.5 GB |
| B2 after | 4.9 GB |
| Result | all seven succeeded |

The bucket got smaller because old copies and hidden versions were cleaned up after uploads.

## Restoring

Restoring is a `pct restore` away, but bind mounts aren't in the archive, so a full recovery is two steps: the container, then the data.

Find the archive:

```bash
rclone lsf b2lxccrypt:prox-lxc-backups/immich/
```

Download and test:

```bash
mkdir -p /mnt/data/restore
rclone copy b2lxccrypt:prox-lxc-backups/immich/immich-109-2026-10-25_19h25.tar.zst /mnt/data/restore/
zstd -t /mnt/data/restore/immich-109-2026-10-25_19h25.tar.zst
```

Restore to a spare ID first if there's any doubt. Avoids a MAC clash too:

```bash
pct restore 209 /mnt/data/restore/immich-109-2026-10-25_19h25.tar.zst \
  --storage local-lvm --unique
```

If the test container looks right, stop the original and restore over it:

```bash
pct stop 109
pct destroy 109
pct restore 109 /mnt/data/restore/immich-109-2026-10-25_19h25.tar.zst --storage local-lvm
pct start 109
```

That's destructive. Only after the archive is checked and, ideally, a copy of the current container is kept.

Whole-host recovery order: reinstall Proxmox, recreate `local-lvm` and the `/mnt/data` mount, set up rclone, then restore CT 107 (DNS), 106 (router), 101 (proxy), and the rest. Only the seven backed-up containers can be recovered this way.

## Immich

Separate repository at `/immich-b2-backup` on the host. Scripts for the database, library, and a report:

| Script | Purpose |
|---|---|
| `immich-db-backup.sh` | database dump |
| `immich-library-backup.sh` | library upload |
| `immich-data-backup-flow.sh` | runs both |
| `immich-backup-report.sh` | status report |

README mentions weekly cron jobs, but I found no host cron entry or systemd timer for them. The schedule is probably inside CT 109, or the scripts are run by hand. Confirming when I document Immich. Until then, treating the photo library as unverified.

## Housekeeping

Old material on the disks:

- `/var/lib/vz/dump` — 14 GB of old dumps, including two CT 109 archives (5.7 GB and 6.4 GB).
- `/mnt/data/public/backups/win10-vm.vma.zst` — 16 GB Windows VM dump from May. No Windows VM on the host now.
- Backup staging — 153 old `vzdump-*.log` files, because the cleanup pattern doesn't match them.

None deleted. If the Windows VM is really gone, that file alone frees 16 GB on the data disk. The old dumps free ~13 GB on root.

## Things to decide later

- Whether to keep more than one B2 copy per container. Right now a bad source can replace the last good archive.
- Where `/mnt/data/private` should be backed up.
- Whether the Immich scripts are actually scheduled.
- Whether to do a test restore — hasn't happened yet as far as I can tell.

## Commands I use

```bash
/usr/local/bin/lxc-backup-b2.sh          # run now, or resume
tail -f /var/log/lxc-backup-b2.log
cat /var/lib/lxc-backup/run.state
rclone lsf b2lxccrypt:prox-lxc-backups/
rclone size b2lxccrypt:prox-lxc-backups/
zstd -t /mnt/data/public/backups/lxc/<archive>.tar.zst
ls -lh /mnt/data/public/backups/lxc/*.tar.zst
```
