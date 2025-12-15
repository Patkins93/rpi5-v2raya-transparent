#!/usr/bin/env bash
set -euo pipefail

# Print Raspberry Pi IP, service URLs, and router DHCP settings hint.
# Usage: ./scripts/show-info.sh

PI_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
if [ -z "${PI_IP:-}" ]; then
  PI_IP="<IP_RPI>"
fi

echo "=== Raspberry Pi / services ==="
echo "Pi IP:    $PI_IP"
echo ""
echo "Pi-hole:  http://$PI_IP/admin"
echo "v2rayA:   http://$PI_IP:2017"
echo ""
echo "=== Router DHCP (important) ==="
echo "Default Gateway (Option 3): $PI_IP"
echo "DNS (Option 6):             $PI_IP   (DNS2 лучше пустой)"
echo ""

echo "=== Local quick probes (optional) ==="
if command -v curl >/dev/null 2>&1; then
  if curl -fsS --max-time 2 "http://127.0.0.1/admin/" >/dev/null 2>&1; then
    echo "OK: Pi-hole web responds on http://127.0.0.1/admin/"
  else
    echo "WARN: Pi-hole web not responding on http://127.0.0.1/admin/ (возможен конфликт порта 80)"
  fi

  if curl -fsS --max-time 2 "http://127.0.0.1:2017/" >/dev/null 2>&1; then
    echo "OK: v2rayA web responds on http://127.0.0.1:2017/"
  else
    echo "WARN: v2rayA web not responding on http://127.0.0.1:2017/"
  fi
else
  echo "INFO: curl not found (skip HTTP probes)"
fi


