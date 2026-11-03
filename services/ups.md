# UPS monitor

A separate small system that watches mains power and the WAN, and shuts down or wakes `prox` when needed. Not part of the Proxmox cluster. Design lives in [github.com/spaulll/esp-ups-system](https://github.com/spaulll/esp-ups-system).

Read the repository and checked the live ESP32 state on 2026-10-31. Nothing changed.

## Why it exists

The first version inferred a power cut from network reachability — false alarms whenever the network hiccuped. The current version measures mains directly through an optocoupler. The network is only used for shutdown, wake, and notifications.

## The pieces

| Piece | Address | Role |
|---|---|---|
| ESP32 | `192.168.0.178` | mains sensor, countdowns, shutdown and wake authority |
| Raspberry Pi | `192.168.0.169` | event reconciler, notifications, Telegram commands |
| Proxmox | `192.168.0.50` | the machine being protected |
| Shutdown webhook | `prox:9999` | local service that shuts the node down |
| PVE API | `prox:8006` | used by the Pi to verify the node is up or down |

The ESP32 is the authority. The Pi doesn't make autonomous changes to it; it reconciles the event ledger, sends notifications, and passes commands through.

## Mains detection

A 5 V USB adapter is powered from the wall. Its output drives channel 1 of a PC817 optocoupler module. The transistor side pulls GPIO 13 low when mains is present:

- adapter on, mains present: GPIO low, `mainsUp: true`
- adapter off, mains gone: GPIO high, `mainsUp: false`

Firmware uses `INPUT_PULLUP`, a 500 ms sample debounce, and a 3-second stability rule. A dip under 3 s is logged as a blip, not a countdown. Channel 2 unused. The mains side stays isolated by the adapter and optocoupler.

## Timers and thresholds

| Setting | Repo default | Live value on 2026-10-31 |
|---|---|---|
| Mains shutdown delay | 5 min | 10 min |
| WAN shutdown delay | 10 min | 10 min |
| Mains stable time | 3 s | 3 s |
| WAN check interval | 15 s | 15 s |
| Restore settle before WOL | 15 s | 15 s |
| Re-WOL after | 120 s, max 5 tries | 120 s, max 5 tries |
| Shutdown webhook retry | 6 tries, 10 s apart | 6 tries, 10 s apart |

Live mains delay is 600000 ms — changed from the 5-minute default, and deliberate (not a drift). Telegram command `/mainsdelay` sets it between 1 and 720 minutes. `/wantimeout` handles the WAN timer. The Pi's copy of the monitor code matches the repo's current revision; the shutdown webhook script is unchanged from the repo snapshot.

WAN check is a TCP connection to `8.8.8.8:53` or `1.1.1.1:53` every 15 s. One failed poll isn't enough; the firmware needs sustained failure before the WAN countdown starts.

## What happens during an outage

1. ESP32 sees mains low for 3 s, writes a `mains_down` event. Countdown starts.
2. If mains returns before the timer expires, the countdown is cancelled and a `mains_restored` event is written.
3. If the timer expires, the ESP32 calls `http://192.168.0.50:9999/shutdown`, retrying every 10 s up to six times.
4. When power returns, the ESP32 waits 15 s, sends Wake-on-LAN, and checks `prox` with ICMP and TCP 8006 every 15 s. If still down after 120 s, sends WOL again, up to five attempts.
5. The Pi polls `/state` and `/events?since=N` every 15 s. Processes each event once, sends a Telegram message, falls back to ntfy if Telegram fails.

The Pi keeps a sequence ledger, so a webhook arriving twice doesn't produce two notifications. The ESP32 keeps event history in a 32-entry ring buffer and a monotonic sequence in NVS.

## Network and ports

| From | To | Port | Purpose |
|---|---|---|---|
| Pi | ESP32 | 80/tcp | `/state`, `/events`, `/command` |
| ESP32 | Pi | 9997/tcp | `/notify` webhook, token-authenticated |
| ESP32 | `prox` | 9999/tcp | shutdown request |
| Pi | `prox` | 8006/tcp | PVE API verification |
| Pi | Telegram, ntfy | 443/tcp | notifications |
| ESP32 | `8.8.8.8`, `1.1.1.1` | 53/tcp | WAN check |
| ESP32 | broadcast | 9/udp | Wake-on-LAN |

ESP32 is OTA-enabled. The repo's fallback OTA path uses port 3232; OTA not tested, live OTA settings not inspected.

`prox` runs the shutdown receiver as `shutdown-webhook.service` (`/usr/local/bin/shutdown-webhook.py`). Confirmed listening on 9999; systemd shows it running since 2026-10-27. No credentials read or recorded from the script.

## The Pi service

The repository installs:

| Path | Purpose |
|---|---|
| `/usr/local/bin/ups-monitor.py` | the Python control-plane process |
| `/etc/systemd/system/ups-monitor.service` | systemd unit, `Type=notify`, `WatchdogSec=90`, `Restart=always` |
| `/etc/logrotate.d/ups-monitor` | weekly rotation, 8 copies |
| `/var/lib/ups-monitor/` | sequence, Telegram offset, counters, outage history, missed-notification state |
| `/var/log/ups-monitor.log` | application log |

Service exposes the webhook receiver on 9997. Telegram commands: `/status`, `/diag`, `/on`, `/off`, `/mainsdelay`, `/wantimeout`, `/missed`, `/history`.

The repo states v2 phases are complete, tests are 78, and hardware passed 20/20 controlled cuts.

## Secrets

Repo design: source files contain only `__PLACEHOLDER__` values. Real credentials, WiFi details, tokens live in a git-ignored `.env`. Deploy scripts inject them into a temporary copy under `/dev/shm`, push the self-contained result, and the temp copy disappears when the script exits. The Pi keeps no `.env`; the pushed Python file has the values embedded.

No credentials from the repo or the live system are copied here.

## Live state at capture

ESP32 reported firmware `V7.6`; repo source in the checked-out revision says `V7.5`. Live values:

- `mainsUp: true`, `wanUp: true`
- no shutdown flags, no active countdown
- sequence `1483`
- counters: 4 mains events, 2 shutdowns, 0 blips, 0 wake failures
- uptime ~6.5 days, last mains change ~26.5 h earlier

Proxmox shutdown webhook was listening on 9999.


