#!/usr/bin/env bash
set -euo pipefail

# Quick health checks.
# Usage: sudo ./scripts/quick-check.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

IPSET_NAME="${IPSET_NAME:-vpnlist}"

echo "IP: $(hostname -I | awk '{print $1}')"
echo "Default iface: $(ip route | awk '/default/ {print $5; exit}')"

echo "--- ip rule / table 100 ---"
ip rule | grep -E 'fwmark|lookup 100' || true
ip route show table 100 || true

echo "--- ipset ---"
ipset list "$IPSET_NAME" 2>/dev/null | grep -E 'Name:|Header:|Number of entries' || true

echo "--- iptables counters (vpnlist) ---"
iptables -t nat -L PREROUTING -n -v | grep -m3 "$IPSET_NAME" || true
iptables -t mangle -L PREROUTING -n -v | grep -E 'MARK|TPROXY' | head -10 || true

echo "--- containers ---"
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'pihole|v2raya' || true

