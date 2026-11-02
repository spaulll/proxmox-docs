# Monitoring

State of the "monitoring" ambitions. Short version: nothing running the Prometheus/Grafana stack right now; what's actually deployed is a solar dashboard. There's also no logging/metrics aggregation across the homelab that I've found.

## What exists

| Asset | Location | State |
|---|---|---|
| Docker host | CT 119 (`10.10.10.246`) | Docker engine up, **zero containers/images** |
| Solar dashboard | CT 119 (`:8000`) and CT 100 (`:8010`) | running (uvicorn) |
| Monitoring CT tag | CT 119 | "monitoring" but nothing deployed |
| Prometheus/Grafana | — | absent |

## Solar dashboard

- Runs on CT 119 (`solar-dashboard.service`, uvicorn on 8000, behind NPM via `--forwarded-allow-ips=10.10.10.200`).
- Also a `solar-dashboard` in CT 100 (uvicorn on 8010) plus a `simulate_inverter.py` process.
- Uses SQLite `solar_data.db`.
- "Monitoring" in name only — it tracks solar, not the homelab.

## Gaps

- No node/container metrics collection (no Prometheus exporters, no sysstat on most).
- No Grafana dashboards for the homelab.
- No alerting for the infra (other than the UPS monitor + SMART).
- The `monitoring` container data is not in the B2 backup.

## Open questions

- Was there ever a Prometheus/Grafana deployment here? Docker is empty.
- Two solar-dashboard copies: which is canonical?
- Do I actually want monitoring? Not currently present.
