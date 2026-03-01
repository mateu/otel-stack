#!/usr/bin/env bash
set -euo pipefail

ok(){ echo "✅ $*"; }
warn(){ echo "⚠️  $*"; }
err(){ echo "❌ $*"; }

need(){ command -v "$1" >/dev/null 2>&1 || { err "missing dependency: $1"; exit 2; }; }
need curl
need jq

echo "🔎 OpenClaw OTEL stack validation"
echo "================================="

# 1) containers
if ! command -v docker >/dev/null 2>&1; then
  err "docker not found"
  exit 2
fi

CONTAINERS=(otel-collector prometheus tempo grafana loki)
for c in "${CONTAINERS[@]}"; do
  status=$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || true)
  if [[ "$status" == "running" ]]; then ok "container $c running"; else err "container $c not running ($status)"; fi
done

# 2) endpoint health
curl -sf http://localhost:3000/api/health >/dev/null && ok "grafana api reachable" || err "grafana api unreachable"
curl -sf http://localhost:9090/-/ready >/dev/null && ok "prometheus ready" || err "prometheus not ready"
curl -sf http://localhost:3200/ready >/dev/null && ok "tempo ready" || warn "tempo not ready yet"
curl -sf http://localhost:3100/ready >/dev/null && ok "loki ready" || err "loki not ready"

# 3) prometheus targets
TARGETS=$(curl -s http://localhost:9090/api/v1/targets)
BAD=$(echo "$TARGETS" | jq '[.data.activeTargets[] | select(.health!="up")] | length')
if [[ "$BAD" == "0" ]]; then
  ok "all prometheus targets are up"
else
  warn "$BAD prometheus target(s) not up"
  echo "$TARGETS" | jq -r '.data.activeTargets[] | select(.health!="up") | "  - \(.labels.job): \(.lastError)"'
fi

# 4) traces present in tempo for openclaw service
TRACES=$(curl -s 'http://localhost:3200/api/search?tags=service.name=openclaw-gateway&limit=3' | jq '.traces | length')
if [[ "$TRACES" =~ ^[0-9]+$ ]] && (( TRACES > 0 )); then
  ok "tempo has openclaw traces ($TRACES recent)"
else
  warn "tempo has no recent openclaw traces"
fi

# 5) openclaw metrics present in prometheus
MET=$(curl -s 'http://localhost:9090/api/v1/query?query=openclaw_openclaw_message_processed_total' | jq '.data.result | length')
if [[ "$MET" =~ ^[0-9]+$ ]] && (( MET > 0 )); then
  ok "prometheus has openclaw metrics ($MET series)"
else
  err "prometheus missing openclaw metrics"
fi

# 6) grafana datasources
DS=$(curl -s http://localhost:3000/api/datasources)
for ds in Prometheus Tempo Loki; do
  if echo "$DS" | jq -e --arg n "$ds" '.[] | select(.name==$n)' >/dev/null; then
    ok "grafana datasource present: $ds"
  else
    err "grafana datasource missing: $ds"
  fi
done

echo "================================="
echo "Done."
