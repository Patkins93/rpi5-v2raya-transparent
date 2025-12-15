#!/usr/bin/env bash
set -euo pipefail

# After git pull: re-apply configs and rules.
# Usage:
#   git pull
#   sudo ./scripts/update.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

chmod +x "$ROOT_DIR/scripts"/*.sh

echo "[1/4] Restart containers (optional pull)..."
docker compose -f compose.yaml pull || true
docker compose -f compose.yaml up -d

echo "[2/4] Re-apply dnsmasq configs..."
"$ROOT_DIR/scripts/apply-dnsmasq.sh"

echo "[3/4] Re-apply gateway rules..."
"$ROOT_DIR/scripts/apply-gateway.sh"

echo "[4/4] Re-apply TProxy rules..."
"$ROOT_DIR/scripts/apply-tproxy.sh"

echo "OK"

