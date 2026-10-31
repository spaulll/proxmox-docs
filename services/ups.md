# UPS monitor

The UPS monitor is a separate small system that watches mains power and the WAN, and shuts down or wakes
`prox` when needed. It is not part of the Proxmox cluster. The design lives in
[github.com/spaulll/esp-ups-system](https://github.com/spaulll/esp-ups-system).

I read the repository and checked the live ESP32 state on 2026-10-31. Nothing was changed.

## Why it exists

The first version inferred a power cut from network reachability, which produced false alarms whenever the
network hiccuped. The current version measures mains directly through an optocoupler. The network is only
used for shutdown, wake and notifications.

## The pieces

| Piece | Address | Role |
|---|---|---|
| ESP32 | `192.168.0.178` | Mains sensor, countdowns, shutdown and wake authority |
| Raspberry Pi | `192.168.0.169` | Event reconciler, notifications, Telegram commands |
| Proxmox | `192.168.0.50` | The machine being protected |
| Shutdown webhook | `prox:9999` | Local service that shuts the node down |
| PVE API | `prox:8006` | Used by the Pi to verify the node is really up or down |

The ESP32 is the authority. The Pi does not make autonomous changes to it; it reconciles the event
ledger, sends notifications and passes commands through.

## Mains detection

A 5 V USB adapter is powered from the wall. Its output drives channel 1 of a PC817 optocoupler module.
The transistor side pulls GPIO 13 low when mains is present:

- adapter on, mains present: GPIO low, `mainsUp: true`
- adapter off, mains gone: GPIO high, `mainsUp: false`

The firmware uses `INPUT_PULLUP`, a 500 ms sample debounce and a 3-second stability rule. A dip shorter
than 3 seconds is logged as a blip and does not start a countdown. Channel 2 of the module is unused. The
mains side stays isolated from the ESP32 by the adapter and the optocoupler.

## Timers and thresholds

| Setting | Repo default | Live value on 2026-10-31 |
|---|---:|---:|
| Mains shutdown delay | 5 min | 10 min |
| WAN shutdown delay | 10 min | 10 min |
| Mains stable time | 3 s | 3 s |
| WAN check interval | 15 s | 15 s |
| Restore settle before WOL | 15 s | 15 s |
| Re-WOL after | 120 s, max 5 tries | 120 s, max 5 tries |
| Shutdown webhook retry | 6 tries, 10 s apart | 6 tries, 10 s apart |

The live mains delay is 600000 ms, so it has been changed from the repository's 5-minute default. The
Telegram command `/mainsdelay` can set it between 1 and 720 minutes. `/wantimeout` handles the WAN timer.

The WAN check is a TCP connection to `8.8.8.8:53` or `1.1.1.1:53`, every 15 seconds. A failed poll is not
enough on its own; the firmware needs a sustained failure before it starts the WAN countdown.

## What happens during an outage

1. The ESP32 sees mains low for 3 seconds and writes a `mains_down` event. A countdown starts.
2. If mains returns before the timer expires, the countdown is cancelled and a `mains_restored` event is
   written.
3. If the timer expires, the ESP32 calls `http://192.168.0.50:9999/shutdown`, retrying every 10 seconds
   up to six times.
4. When power returns, the ESP32 waits 15 seconds, sends Wake-on-LAN, and checks `prox` with ICMP and TCP
   port 8006 every 15 seconds. If it is still down after 120 seconds, it sends WOL again, up to five
   attempts.
5. The Pi polls `/state` and `/events?since=N` every 15 seconds. It processes each event once, sends a
   Telegram message and falls back to ntfy if Telegram fails.

The Pi keeps a sequence ledger, so a webhook that arrives twice does not produce two notifications. The
ESP32 keeps the event history in a 32-entry ring buffer and a monotonic sequence number in NVS.

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

The ESP32 is OTA-enabled. The repository's fallback OTA path uses port 3232, but I did not test OTA or
inspect the live OTA settings.

`prox` runs the shutdown receiver as `shutdown-webhook.service`
(`/usr/local/bin/shutdown-webhook.py`). I confirmed it is listening on 9999; systemd showed it running
since 2026-10-27. I did not read or record any credentials from the script.

## The Pi service

The repository installs:

| Path | Purpose |
|---|---|
| `/usr/local/bin/ups-monitor.py` | the Python control-plane process |
| `/etc/systemd/system/ups-monitor.service` | systemd unit, `Type=notify`, `WatchdogSec=90`, `Restart=always` |
| `/etc/logrotate.d/ups-monitor` | weekly rotation, 8 copies |
| `/var/lib/ups-monitor/` | sequence, Telegram offset, counters, outage history and missed-notification state |
| `/var/log/ups-monitor.log` | application log |

The service exposes the webhook receiver on 9997. Telegram commands are `/status`, `/diag`, `/on`, `/off`,
`/mainsdelay`, `/wantimeout`, `/missed` and `/history`.

The repository says the v2 phases are complete, the test suite has 78 tests and the hardware passed 20/20
controlled cuts. I have not re-run the tests or verified the live Pi service.

## Secrets

The repository is designed so that source files contain only `__PLACEHOLDER__` values. Real credentials,
WiFi details and tokens live in a git-ignored `.env`. The deploy scripts inject them into a temporary copy
under `/dev/shm`, push the self-contained result, and let the temporary copy disappear when the script
exits. The Pi does not keep an `.env`; the pushed Python file has the values embedded.

No credentials from the repository or the live system are copied into this documentation.

## Live state at capture

The ESP32 reported firmware `V7.6`, while the repository source in the checked-out revision says `V7.5`.
The live values were:

- `mainsUp: true`, `wanUp: true`
- no shutdown flags, no active countdown
- sequence `1483`
- counters: 4 mains events, 2 shutdowns, 0 blips, 0 wake failures
- uptime about 6.5 days, last mains change about 26.5 hours earlier

The Proxmox shutdown webhook was listening on 9999. I did not log into the Pi, so its live service state
is still unconfirmed.

## What still needs checking

- The live `ups-monitor.service` version, status and logs on the Pi.
- Whether the Pi's copy of the code matches the repository's current revision.
- The ESP32's network configuration, OTA settings and whether `192.168.0.178` is a static lease.
- The reason the live mains delay is 10 minutes while the repository default is 5 minutes.
- Whether the shutdown webhook script has changed since the repository snapshot.
