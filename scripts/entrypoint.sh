#!/usr/bin/env sh
set -Eeo pipefail

if [ "${1:0:1}" = '-' ]; then
	set -- zerotier-one "$@"
fi

DEFAULT_PRIMARY_PORT=9993
DEFAULT_PORT_MAPPING_ENABLED=true
DEFAULT_ALLOW_TCP_FALLBACK_RELAY=true

#Match Networks with User Provided Networks
# Check if ZT_NETWORK_IDS is not NULL
if [[ -n "$ZT_NETWORK_IDS" ]] ; then
    #First leave networks not a part of user provided networks
    current_joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    for current_network in $current_joined_networks; do
        found_network=0
        for zt_network in $ZT_NETWORK_IDS; do
            if [[ "$current_network" = "$zt_network" ]]; then
            found_network=1
            break 1; 
            fi
        done
        if [[ $found_network -eq 0 ]]; then
        zerotier-cli leave $current_network
        fi
    done
    #Join Networks not present
    #Resetting joined Networks for optimisation
    current_joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    for zt_network in $ZT_NETWORK_IDS; do
        found_network=0
        for current_network in $current_joined_networks; do
            if [[ "$current_network" = "$zt_network" ]]; then
            found_network=1
            break 1; 
            fi
        done
        if [[ $found_network -eq 0 ]]; then
        zerotier-cli join $zt_network
        fi
    done    
fi

MANAGEMENT_NETWORKS=""
if [ ! -z "$ZT_ALLOW_MANAGEMENT_FROM" ]; then
  for NETWORK in ${ZT_ALLOW_MANAGEMENT_FROM//,/$IFS}; do
    if [ -n "$MANAGEMENT_NETWORKS" ]; then
      MANAGEMENT_NETWORKS="${MANAGEMENT_NETWORKS},"
    fi
    MANAGEMENT_NETWORKS="${MANAGEMENT_NETWORKS}\"${NETWORK}\""
  done
fi

if [ "$ZT_OVERRIDE_LOCAL_CONF" = 'true' ] || [ ! -f "/var/lib/zerotier-one/local.conf" ]; then
  echo "{
    \"settings\": {
        \"primaryPort\": ${ZT_PRIMARY_PORT:-$DEFAULT_PRIMARY_PORT},
        \"portMappingEnabled\": ${ZT_PORT_MAPPING_ENABLED:-$DEFAULT_PORT_MAPPING_ENABLED},
        \"softwareUpdate\": \"disable\",
        \"allowManagementFrom\": [${MANAGEMENT_NETWORKS}],
        \"allowTcpFallbackRelay\": ${ZT_ALLOW_TCP_FALLBACK_RELAY:-$DEFAULT_ALLOW_TCP_FALLBACK_RELAY}
    }
  }" > /var/lib/zerotier-one/local.conf
fi

exec "$@"
