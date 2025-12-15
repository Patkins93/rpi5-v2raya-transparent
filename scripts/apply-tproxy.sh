#!/usr/bin/env bash
set -euo pipefail

# Apply ipset + iptables (DNAT/MARK/TPROXY) rules.
# Usage: sudo ./scripts/apply-tproxy.sh

if [ "${EUID:-0}" -ne 0 ]; then
  echo "ERROR: run as root: sudo $0" >&2
  exit 1
fi

IPSET_NAME="${IPSET_NAME:-vpnlist}"
TPROXY_PORT="${TPROXY_PORT:-52345}"

get_candidate_ifaces() {
  (
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}'
    ip -o -4 addr show up 2>/dev/null | awk '{print $2}'
  ) | sort -u \
    | grep -vE '^(lo|docker0)$' \
    | grep -vE '^veth' \
    | grep -vE '^br-' \
    | grep -vE '^docker' \
    || true
}

ensure_ipset() {
  if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    # Big capacity to avoid "set full" when apps resolve many IPs.
    ipset create "$IPSET_NAME" hash:ip family inet hashsize 262144 maxelem 1048576 2>/dev/null || true
  fi
}

ensure_routing() {
  ip rule add fwmark 1 table 100 2>/dev/null || true
  ip route add local 0.0.0.0/0 dev lo table 100 2>/dev/null || true
}

delete_all_duplicates() {
  local table="$1"; shift
  while iptables -t "$table" -C "$@" 2>/dev/null; do
    iptables -t "$table" -D "$@" 2>/dev/null || break
  done
}

add_rule_once() {
  local table="$1"; shift
  if ! iptables -t "$table" -C "$@" 2>/dev/null; then
    iptables -t "$table" -A "$@"
  fi
}

echo "[1/4] Prepare: ipset + policy routing + sysctl..."
ensure_ipset
ensure_routing
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.all.rp_filter=0 >/dev/null 2>&1 || true
sysctl -w net.ipv4.conf.default.rp_filter=0 >/dev/null 2>&1 || true

echo "[2/4] Interface rules (DNAT + MARK) ..."
IFACES="$(get_candidate_ifaces)"
for IFACE in $IFACES; do
  delete_all_duplicates nat PREROUTING -i "$IFACE" -p tcp -m set --match-set "$IPSET_NAME" dst -j DNAT --to-destination "127.0.0.1:$TPROXY_PORT"
  delete_all_duplicates nat PREROUTING -i "$IFACE" -p udp -m set --match-set "$IPSET_NAME" dst -j DNAT --to-destination "127.0.0.1:$TPROXY_PORT"
  add_rule_once nat PREROUTING -i "$IFACE" -p tcp -m set --match-set "$IPSET_NAME" dst -j DNAT --to-destination "127.0.0.1:$TPROXY_PORT"
  add_rule_once nat PREROUTING -i "$IFACE" -p udp -m set --match-set "$IPSET_NAME" dst -j DNAT --to-destination "127.0.0.1:$TPROXY_PORT"

  delete_all_duplicates mangle PREROUTING -i "$IFACE" -p tcp ! --dport 22 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 1
  delete_all_duplicates mangle PREROUTING -i "$IFACE" -p udp -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 1
  add_rule_once mangle PREROUTING -i "$IFACE" -p tcp ! --dport 22 -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 1
  add_rule_once mangle PREROUTING -i "$IFACE" -p udp -m set --match-set "$IPSET_NAME" dst -j MARK --set-mark 1
done

echo "[3/4] Global TPROXY rules (NOT interface-bound)..."
delete_all_duplicates mangle PREROUTING -p tcp -m mark --mark 1 -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark 1
delete_all_duplicates mangle PREROUTING -p udp -m mark --mark 1 -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark 1
add_rule_once mangle PREROUTING -p tcp -m mark --mark 1 -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark 1
add_rule_once mangle PREROUTING -p udp -m mark --mark 1 -j TPROXY --on-port "$TPROXY_PORT" --tproxy-mark 1

echo "[4/4] Persist rules (iptables/ipset)..."
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
else
  mkdir -p /etc/iptables 2>/dev/null || true
  iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
fi
ipset save > /etc/ipset.conf 2>/dev/null || true

echo "OK"

