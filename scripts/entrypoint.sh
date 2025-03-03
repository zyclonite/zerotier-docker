#!/usr/bin/env sh
set -Eeo pipefail

if [ "${1:0:1}" = '-' ]; then
	set -- zerotier-one "$@"
fi

DEFAULT_PRIMARY_PORT=9993
DEFAULT_PORT_MAPPING_ENABLED=true
DEFAULT_ALLOW_TCP_FALLBACK_RELAY=true
CONFIG_DIR="/var/lib/zerotier-one"
NETWORKS_DIR="${CONFIG_DIR}/networks.d"

MANAGEMENT_NETWORKS=""
if [ ! -z "$ZT_ALLOW_MANAGEMENT_FROM" ]; then
  for NETWORK in ${ZT_ALLOW_MANAGEMENT_FROM//,/$IFS}; do
    if [ -n "$MANAGEMENT_NETWORKS" ]; then
      MANAGEMENT_NETWORKS="${MANAGEMENT_NETWORKS},"
    fi
    MANAGEMENT_NETWORKS="${MANAGEMENT_NETWORKS}\"${NETWORK}\""
  done
fi

if [ "$ZT_OVERRIDE_LOCAL_CONF" = 'true' ] || [ ! -f "${CONFIG_DIR}/local.conf" ]; then
  echo "{
    \"settings\": {
        \"primaryPort\": ${ZT_PRIMARY_PORT:-$DEFAULT_PRIMARY_PORT},
        \"portMappingEnabled\": ${ZT_PORT_MAPPING_ENABLED:-$DEFAULT_PORT_MAPPING_ENABLED},
        \"softwareUpdate\": \"disable\",
        \"allowManagementFrom\": [${MANAGEMENT_NETWORKS}],
        \"allowTcpFallbackRelay\": ${ZT_ALLOW_TCP_FALLBACK_RELAY:-$DEFAULT_ALLOW_TCP_FALLBACK_RELAY}
    }
  }" > ${CONFIG_DIR}/local.conf
fi

# set up network auto-join if (a) the networks directory does not exist
# and (b) the ZEROTIER_ONE_NETWORK_IDS environment variable is non-null.
if [ ! -d "${NETWORKS_DIR}" ] ; then
	echo "$(date) - assuming container first run."
	if [ -n "${ZEROTIER_ONE_NETWORK_IDS}" ] ; then
		mkdir -p "${NETWORKS_DIR}"
		for NETWORK_ID in ${ZEROTIER_ONE_NETWORK_IDS} ; do
			echo "  Configuring auto-join of network ID: ${NETWORK_ID}"
			touch "${NETWORKS_DIR}/${NETWORK_ID}.conf"
			echo "  You will need to authorize this host at:"
			echo "     https://my.zerotier.com/network/${NETWORK_ID}"
		done
	else
		echo " ZEROTIER_ONE_NETWORK_IDS not set. You will need to join"
		echo " networks using zerotier-cli, and then approve this"
		echo " host in ZeroTier Central."
	fi
fi

# make sure permissions are always as expected (self-repair)
PUID="${PUID:-"999"}"
PGID="${PGID:-"994"}"
if [ "$(id -u)" = '0' -a -d "${CONFIG_DIR}" ]; then
	chown -Rc "${PUID}:${PGID}" "${CONFIG_DIR}"
fi

echo "$(date) - launching ZeroTier-One in client mode"

exec "$@"
