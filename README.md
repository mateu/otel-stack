# OpenClaw OTEL Observability Stack

Complete OpenTelemetry observability stack for OpenClaw with auto-configured Grafana dashboards.

## What's Included

- **OpenTelemetry Collector** - Receives traces and metrics from OpenClaw
- **Tempo** - Distributed tracing backend (stores your AI request "journeys")
- **Prometheus** - Metrics storage (token counts, latencies, error rates)
- **Grafana** - Visualization with pre-configured datasources and dashboards

## Quick Start

```bash
# Extract the archive
unzip openclaw-otel.zip
cd openclaw-otel

# Check if ports are available (optional but recommended)
chmod +x check-ports.sh
./check-ports.sh

# Run setup (creates directories, sets permissions)
chmod +x setup.sh
./setup.sh

# Start the stack
docker compose up -d

# Watch it come up
docker compose logs -f
```

## Access Points

After starting the stack:

- **Grafana**: http://your-host:3000
  - Auto-configured with Tempo and Prometheus datasources
  - Pre-loaded "OpenClaw OTEL Overview" dashboard
  - Anonymous admin access enabled (homelab mode)

- **Prometheus**: http://your-host:9090
  - Query metrics directly
  - Useful for debugging or custom queries

- **Tempo**: http://your-host:3200
  - Trace query interface
  - Usually accessed via Grafana

## Configuring OpenClaw

Point OpenClaw to send OTEL data to:

**OTLP HTTP** (recommended):
```
http://your-host:4318
```

**OTLP gRPC**:
```
your-host:4317
```

Example environment variable:
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT="http://your-host:4318"
```

## Dashboard Overview

The pre-loaded dashboard shows:

1. **Request Rate** - OpenClaw API calls per second
2. **Latency (p95)** - 95th percentile response time
3. **Token Usage Rate** - Input/output tokens over time
4. **Error Rate** - Percentage of failed requests
5. **Service Memory** - Resource usage of OTEL components
6. **Collector Throughput** - Spans and metrics processed

## Data Retention

- **Tempo traces**: 7 days (configured in tempo.yaml)
- **Prometheus metrics**: 30 days (configured in docker-compose.yaml)
- **Grafana dashboards**: Persistent across restarts

All data is stored on your ZFS pool at `/mnt/dev/openclaw-otel/data/`

## Useful Commands

```bash
# Start everything
docker compose up -d

# Stop everything
docker compose down

# View logs
docker compose logs -f otel-collector
docker compose logs -f tempo
docker compose logs -f prometheus
docker compose logs -f grafana

# Restart a specific service
docker compose restart otel-collector

# Check resource usage
docker stats

# Wipe data and start fresh (DESTRUCTIVE)
docker compose down -v
sudo rm -rf /mnt/dev/openclaw-otel/data/*
./setup.sh
docker compose up -d
```

## Troubleshooting

### Port conflicts?

Before starting, check for port conflicts:
```bash
./check-ports.sh
```

The script checks all required ports (3000, 3200, 4317, 4318, 8888, 9090) and shows what's using them if occupied.

If you have conflicts, either:
- Stop the conflicting service
- Edit `docker-compose.yaml` to use different ports (e.g., `3001:3000` for Grafana)

### No traces appearing in Tempo?

Check collector logs:
```bash
docker compose logs otel-collector | grep -i error
```

Verify OpenClaw is sending data:
```bash
# Should see incoming connections
docker compose logs otel-collector | grep -i "otlp"
```

### Grafana not showing datasources?

The datasources auto-provision on first boot. If they're missing:

1. Check Grafana logs: `docker compose logs grafana`
2. Verify provisioning files exist in `grafana/provisioning/`
3. Restart Grafana: `docker compose restart grafana`

### High memory usage?

Adjust limits in `docker-compose.yaml`:

```yaml
deploy:
  resources:
    limits:
      memory: 512M  # Reduce this
```

### Permission errors?

Re-run the setup script with sudo:
```bash
sudo ./setup.sh
```

## File Structure

```
openclaw-otel/
├── docker-compose.yaml          # Main orchestration
├── otel-config.yaml             # Collector configuration
├── tempo.yaml                   # Tempo configuration
├── prometheus.yaml              # Prometheus scrape config
├── setup.sh                     # Setup script
├── check-ports.sh               # Pre-flight port availability check
├── README.md                    # This file
├── QUICKREF.txt                 # Quick reference card
├── .env.example                 # Environment variable template
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yaml # Auto-configure Tempo & Prometheus
│   │   └── dashboards/
│   │       └── dashboards.yaml  # Dashboard provider config
│   └── dashboards/
│       └── openclaw-overview.json # Pre-built dashboard
└── data/                        # Runtime data (created by setup.sh)
    ├── grafana/
    ├── tempo/
    └── prometheus/
```

## Customization

### Adjusting trace retention

Edit `tempo.yaml`:
```yaml
compactor:
  compaction:
    block_retention: 336h  # 14 days instead of 7
```

### Adjusting metric retention

Edit `docker-compose.yaml` prometheus command:
```yaml
- '--storage.tsdb.retention.time=60d'  # 60 days instead of 30
```

### Disable debug logging

Edit `otel-config.yaml`, remove or comment:
```yaml
exporters:
  # logging:  # Comment this out
  #   loglevel: info
```

### Adding more scrape targets

Edit `prometheus.yaml`:
```yaml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:8080']
```

## Security Notes

This configuration is optimized for **homelab use behind a firewall**:

- Anonymous Grafana admin access enabled
- No TLS/authentication on any service
- All ports exposed on 0.0.0.0

**Do NOT expose this to the internet without:**
1. Enabling authentication on all services
2. Adding TLS certificates
3. Restricting network exposure
4. Setting strong passwords

## Integration with Netdata

Since you're already running Netdata, you can point it at Prometheus:

Add to your Netdata config:
```yaml
# /etc/netdata/python.d/prometheus.conf
update_every: 15
jobs:
  openclaw_metrics:
    url: 'http://your-host:9090/api/v1/targets/metadata'
```

Now your existing Netdata dashboards can show OpenClaw metrics!

## Support

The stack is built on standard open-source components:

- OpenTelemetry Collector: https://opentelemetry.io/docs/collector/
- Tempo: https://grafana.com/docs/tempo/
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/grafana/

## Conscious Choices Made

- **Pinned versions** instead of `:latest` - reproducible, predictable
- **Persistent storage** on ZFS - your data survives restarts
- **Resource limits** - prevents runaway memory usage
- **Auto-provisioning** - zero manual Grafana clicking
- **Debug logging** - easy troubleshooting when learning

Adjust as your practice evolves. 🧘
