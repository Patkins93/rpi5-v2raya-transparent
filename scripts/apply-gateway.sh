#!/usr/bin/env bash
set -euo pipefail

# Configure Raspberry Pi as a gateway for LAN clients (forwarding + NAT).
# Usage: sudo ./scripts/apply-gateway.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

CURRENT_IFACE="${CURRENT_IFACE:-$(ip route | awk '/default/ {print $5; exit}')}"
if [ -z "${CURRENT_IFACE:-}" ]; then
  echo "ERROR: cannot detect default interface" >&2
  exit 1
fi

# Detect LAN CIDR from kernel route on that interface.
LAN_CIDR="${LAN_CIDR:-$(ip route show dev "$CURRENT_IFACE" proto kernel scope link 2>/dev/null | awk '{print $1; exit}')}"
if [ -z "${LAN_CIDR:-}" ]; then
  LAN_CIDR="192.168.0.0/24"
fi

echo "Interface: $CURRENT_IFACE"
echo "LAN CIDR:  $LAN_CIDR"

echo "[1/4] sysctl: ip_forward + rp_filter..."
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w "net.ipv4.conf.${CURRENT_IFACE}.rp_filter=0" >/dev/null 2>&1 || true

cat > /etc/sysctl.d/99-vpn-gateway.conf << EOF
net.ipv4.ip_forward=1
net.ipv4.conf.all.rp_filter=0
net.ipv4.conf.default.rp_filter=0
net.ipv4.conf.${CURRENT_IFACE}.rp_filter=0
EOF
sysctl --system >/dev/null 2>&1 || true

echo "[2/4] FORWARD rules..."
iptables -C FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 1 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -C FORWARD -i "$CURRENT_IFACE" -o "$CURRENT_IFACE" -j ACCEPT 2>/dev/null || \
  iptables -I FORWARD 2 -i "$CURRENT_IFACE" -o "$CURRENT_IFACE" -j ACCEPT

echo "[3/4] NAT (MASQUERADE) ..."
iptables -t nat -C POSTROUTING -s "$LAN_CIDR" -o "$CURRENT_IFACE" -j MASQUERADE 2>/dev/null || \
  iptables -t nat -I POSTROUTING 1 -s "$LAN_CIDR" -o "$CURRENT_IFACE" -j MASQUERADE

echo "[4/4] Persist iptables..."
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
else
  mkdir -p /etc/iptables 2>/dev/null || true
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi

echo "OK"

