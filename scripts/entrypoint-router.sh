#!/usr/bin/env sh
set -Eeo pipefail

echo "$(date) - launching ZeroTier-One in routing mode"

if [ "${1:0:1}" = '-' ]; then
	set -- zerotier-one "$@"
fi

# useful paths
CONFIG_DIR="/var/lib/zerotier-one"
NETWORKS_DIR="$CONFIG_DIR/networks.d"

# set up network auto-join if (a) the networks directory does not exist
# and (b) the ZEROTIER_ONE_NETWORK_ID environment variable is non-null.
if [ ! -d "$NETWORKS_DIR" -a -n "$ZEROTIER_ONE_NETWORK_ID" ] ; then
   echo "Assuming container first run. Configuring auto-join of network ID:"
   echo "   $ZEROTIER_ONE_NETWORK_ID"
   echo "You will need to authorize this host at:"
   echo "   https://my.zerotier.com/network/$ZEROTIER_ONE_NETWORK_ID"
   mkdir -p "$NETWORKS_DIR"
   touch "$NETWORKS_DIR/$ZEROTIER_ONE_NETWORK_ID.conf"
fi

# make sure permissions are correct
PUID="${PUID:-"999"}"
PGID="${PGID:-"994"}"
if [ "$(id -u)" = '0' -a -d "$CONFIG_DIR" ]; then
   chown -Rc "$PUID:$PGID" "$CONFIG_DIR"
fi

# use an appropriate default for a local physical interface
PHY_IFACES="${ZEROTIER_ONE_LOCAL_PHYS:-"eth0"}"

# default to iptables (maintain compatibility for existing systems)
IPTABLES_CMD=iptables
# but support override to use iptables-nft
[ "$ZEROTIER_ONE_USE_IPTABLES_NFT" = "true" ] && IPTABLES_CMD=iptables-nft

# the wildcard for the local zerotier interface is
ZT_IFACE="zt+"

# iterate the local interface(s) and enable NAT services
for PHY_IFACE in $PHY_IFACES ; do
   echo "Using $IPTABLES_CMD to enable NAT services on $PHY_IFACE"
   $IPTABLES_CMD -t nat -A POSTROUTING -o $PHY_IFACE -j MASQUERADE
   $IPTABLES_CMD -A FORWARD -i $PHY_IFACE -o $ZT_IFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
   $IPTABLES_CMD -A FORWARD -i $ZT_IFACE -o $PHY_IFACE -j ACCEPT
done

# launch zerotier-one
exec "$@"

