#!/usr/bin/env bash
set -euo pipefail

# Copies repo configs into Pi-hole dnsmasq and restarts DNS.
# Usage: sudo ./scripts/apply-dnsmasq.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

PIHOLE_CONTAINER="${PIHOLE_CONTAINER:-pihole}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! docker ps --format '{{.Names}}' | grep -qx "$PIHOLE_CONTAINER"; then
  echo "ERROR: Pi-hole container '$PIHOLE_CONTAINER' not running." >&2
  echo "Hint: run from repo root: docker compose -f compose.yaml up -d" >&2
  exit 1
fi

echo "[1/3] Copy dnsmasq configs into container..."
# We overwrite by name to make updates deterministic.
docker cp "$SRC_DIR/configs/05-vpnlist.conf" "$PIHOLE_CONTAINER:/etc/dnsmasq.d/05-vpnlist.conf"

echo "[2/3] Restart Pi-hole DNS..."
if docker exec "$PIHOLE_CONTAINER" pihole restartdns >/dev/null 2>&1; then
  echo "OK: DNS restarted"
else
  echo "WARN: pihole restartdns failed, try: docker restart $PIHOLE_CONTAINER" >&2
fi

echo "[3/3] Done"

