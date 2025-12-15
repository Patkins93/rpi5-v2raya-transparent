#!/usr/bin/env bash
set -euo pipefail

# One-time install for Raspberry Pi OS.
# Usage: sudo ./scripts/install.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[1/6] Packages..."
apt-get update -y
apt-get install -y \
  ca-certificates curl git \
  ipset iptables iptables-persistent netfilter-persistent \
  dnsutils \
  docker.io docker-compose-plugin

systemctl enable --now docker >/dev/null 2>&1 || true

echo "[2/6] Start containers (Pi-hole + v2rayA)..."
cd "$ROOT_DIR"
docker compose -f compose.yaml up -d

echo "[3/6] Create ipset (big capacity)..."
ipset list vpnlist >/dev/null 2>&1 || ipset create vpnlist hash:ip family inet hashsize 262144 maxelem 1048576 2>/dev/null || true

echo "[4/6] Apply dnsmasq domain->ipset config..."
chmod +x "$ROOT_DIR/scripts"/*.sh
"$ROOT_DIR/scripts/apply-dnsmasq.sh"

echo "[5/6] Apply gateway (forwarding + NAT)..."
"$ROOT_DIR/scripts/apply-gateway.sh"

echo "[6/6] Apply transparent proxy rules (TPROXY)..."
"$ROOT_DIR/scripts/apply-tproxy.sh"

echo ""
echo "DONE."
echo ""

if [ -x "$ROOT_DIR/scripts/show-info.sh" ]; then
  "$ROOT_DIR/scripts/show-info.sh" || true
else
  echo "Next (on your router DHCP):"
  echo "- Default Gateway (Option 3): set to this Raspberry Pi IP"
  echo "- DNS (Option 6): set to this Raspberry Pi IP (DNS2 лучше пустой)"
fi


