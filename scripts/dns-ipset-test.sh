#!/usr/bin/env bash
set -euo pipefail

# Smoke test: domain -> DNS (Pi-hole on 127.0.0.1) -> ipset membership.
#
# Usage:
#   sudo ./scripts/dns-ipset-test.sh youtube.com instagram.com
#
# Notes:
# - Requires root to read ipset/iptables reliably.

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0 <domain> [domain...]" >&2
  exit 1
fi

IPSET_NAME="${IPSET_NAME:-vpnlist}"
DNS_SERVER="${DNS_SERVER:-127.0.0.1}"

if [ "$#" -lt 1 ]; then
  echo "Usage: sudo $0 <domain> [domain...]" >&2
  exit 2
fi

if ! command -v dig >/dev/null 2>&1; then
  echo "ERROR: dig not found. Install: sudo apt-get install -y dnsutils" >&2
  exit 3
fi

if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
  echo "ERROR: ipset '$IPSET_NAME' not found. Run: sudo ./scripts/install.sh" >&2
  exit 4
fi

echo "DNS server: $DNS_SERVER"
echo "IPSET:      $IPSET_NAME"
echo ""

for domain in "$@"; do
  echo "=== $domain ==="
  ips="$(dig +short "@$DNS_SERVER" "$domain" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
  if [ -z "${ips:-}" ]; then
    echo "WARN: no A records via $DNS_SERVER"
    echo ""
    continue
  fi

  echo "$ips" | head -20 | while read -r ip; do
    if ipset test "$IPSET_NAME" "$ip" >/dev/null 2>&1; then
      echo "OK:   $ip  in $IPSET_NAME"
    else
      echo "MISS: $ip  not in $IPSET_NAME  (проверь, что домен есть в configs/05-vpnlist.conf и применён)"
    fi
  done
  echo ""
done

echo "=== iptables counters (vpnlist) ==="
iptables -t nat -L PREROUTING -n -v | grep -m3 "$IPSET_NAME" || true


