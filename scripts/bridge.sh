#!/usr/bin/env sh

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

echo "Waiting for network interface to be ready..."

while ! ifconfig | grep -q zt; do
    echo -n "."
    sleep 1
done

echo "Network interface is ready. Starting bridge..."

PHY_IFACE=eth0
ZT_IFACE=$(ifconfig | grep zt | awk '{print $1}')
iptables -t nat -A POSTROUTING -o $PHY_IFACE -j MASQUERADE
iptables -A FORWARD -i $PHY_IFACE -o $ZT_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $ZT_IFACE -o $PHY_IFACE -j ACCEPT

echo "Bridge started."