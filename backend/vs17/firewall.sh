#!/usr/bin/env bash
set -euo pipefail

ipset=/usr/sbin/ipset
iptables=/usr/sbin/iptables
for name in sl_lab_live sl_lab_next; do
  "$ipset" -exist create "$name" hash:ip,port,ip family inet timeout 5
  "$ipset" flush "$name"
done

# Build once, publish the jump last. A restart only clears the authorization set.
if ! "$iptables" -w -S SL-VS17 >/dev/null 2>&1; then
  "$iptables" -w -N SL-VS17
fi
add_rule() {
  "$iptables" -w -C SL-VS17 "$@" 2>/dev/null || "$iptables" -w -A SL-VS17 "$@"
}
for protocol in tcp udp; do
  add_rule -i wg0 -o br-sl-lab -s 10.78.0.0/16 -d 172.30.77.0/24 -p "$protocol" \
    -m conntrack --ctstate NEW,ESTABLISHED -m set --match-set sl_lab_live src,dst,dst -j ACCEPT
  add_rule -i br-sl-lab -o wg0 -s 172.30.77.0/24 -d 10.78.0.0/16 -p "$protocol" \
    -m conntrack --ctstate ESTABLISHED -m set --match-set sl_lab_live dst,src,src -j ACCEPT
done
add_rule -i wg0 -d 172.30.77.0/24 -j DROP
add_rule -o br-sl-lab -j DROP
add_rule -i br-sl-lab -o wg0 -j DROP
"$iptables" -w -C DOCKER-USER -j SL-VS17 2>/dev/null || "$iptables" -w -I DOCKER-USER 1 -j SL-VS17
