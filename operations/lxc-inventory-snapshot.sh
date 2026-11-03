#!/usr/bin/env bash
# Regenerate the LXC inventory table for README.md.
# Read-only: only runs `pct list` / `pct config` reads. Run on the prox host.
# Usage: bash lxc-inventory-snapshot.sh

echo "| ID | Name | Status | OS | CPU | RAM | Disk | Boot | Bridge | IP | Mounts |"
echo "|---|---|---|---|---|---|---|---|---|---|---|"

for ctid in $(pct list | awk 'NR>1 {print $1}' | sort -n); do
    CONFIG=$(pct config "$ctid")
    NAME=$(pct list | awk -v id="$ctid" '$1==id {print $3}')
    STATUS=$(pct list | awk -v id="$ctid" '$1==id {print $2}')
    OS=$(echo "$CONFIG" | grep -iE '^ostype' | awk '{print $2}')
    CPU=$(echo "$CONFIG" | grep '^cores' | awk '{print $2}')
    RAM=$(echo "$CONFIG" | grep '^memory' | awk '{print $2}' | sed 's/$/ MB/')
    DISK=$(echo "$CONFIG" | grep '^rootfs' | grep -oP 'size=\K[^,]+')
    BOOT=$(echo "$CONFIG" | grep '^onboot' | awk '{print $2}')
    [ "$BOOT" = "1" ] && BOOT="yes" || BOOT="no"
    BRIDGES=$(echo "$CONFIG" | grep '^net' | grep -oP 'bridge=\K[^,]+' | sort -u | paste -sd '+')
    IPS=$(echo "$CONFIG" | grep '^net' | grep -oP '(?:ip|ip6)=\K[^,]+' | grep -v '^$' | paste -sd ' ')
    RATE=$(echo "$CONFIG" | grep '^net' | grep -oP 'rate=\K[^,]+' | head -1)
    [ -n "$RATE" ] && IPS="${IPS} (rate=${RATE})"
    [ -z "$IPS" ] && IPS="—"
    MOUNTS=$(echo "$CONFIG" | grep '^mp' | grep -oP '([^,\s]+),mp=([^,\s]+)' | sed 's/,mp=/ → /' | paste -sd ' | ')
    [ -z "$MOUNTS" ] && MOUNTS="—"
    echo "| $ctid | $NAME | $STATUS | $OS | $CPU | $RAM | $DISK | $BOOT | $BRIDGES | $IPS | $MOUNTS |"
done
