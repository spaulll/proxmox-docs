# Monitoring

This covers the "monitoring" container. Short version: there is no Prometheus/Grafana stack. CT 119 exists for **solar dashboard and solar monitoring** only.

## What exists

| Asset | Location | State |
|---|---|
| Solar dashboard + monitoring | CT 119 (`10.10.10.246`, `:8000`) | running (uvicorn) |
| Solar dashboard copy | CT 100 (`:8010`) | running |
| Docker host | CT 119 | Docker engine up, **zero containers/images** |
| Prometheus/Grafana | — | absent |

## Solar dashboard

- Runs on CT 119 (`solar-dashboard.service`, uvicorn on 8000, behind NPM via `--forwarded-allow-ips=10.10.10.200`).
- Also a `solar-dashboard` in CT 100 (uvicorn on 8010) plus a `simulate_inverter.py` process.
- Uses SQLite `solar_data.db`.

## Not present

- No node/container metrics collection (no Prometheus exporters, no sysstat on most).
- No Grafana dashboards for the homelab.
- No infra alerting (other than the UPS monitor + SMART).
- The CT 119 container is intentionally not in the B2 backup (solar only).


