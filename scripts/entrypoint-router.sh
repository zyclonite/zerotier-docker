#!/usr/bin/env sh
set -Eeo pipefail

echo "$(date) - launching ZeroTier-One in routing mode"
echo "command and args: $@"

if [ "${1:0:1}" = '-' ]; then
	set -- zerotier-one "$@"
fi

# useful paths
CONFIG_DIR="/var/lib/zerotier-one"
NETWORKS_DIR="${CONFIG_DIR}/networks.d"

# set up network auto-join if (a) the networks directory does not exist
# and (b) the ZEROTIER_ONE_NETWORK_IDS environment variable is non-null.
if [ ! -d "${NETWORKS_DIR}" -a -n "${ZEROTIER_ONE_NETWORK_IDS}" ] ; then
	echo "Assuming container first run."
	mkdir -p "${NETWORKS_DIR}"
	for NETWORK_ID in ${ZEROTIER_ONE_NETWORK_IDS} ; do
		echo "Configuring auto-join of network ID: ${NETWORK_ID}"
		touch "${NETWORKS_DIR}/${NETWORK_ID}.conf"
		echo "You will need to authorize this host at:"
		echo "   https://my.zerotier.com/network/${NETWORK_ID}"
	done
fi

# make sure permissions are correct
PUID="${PUID:-"999"}"
PGID="${PGID:-"994"}"
if [ "$(id -u)" = '0' -a -d "${CONFIG_DIR}" ]; then
	chown -Rc "${PUID}:${PGID}" "${CONFIG_DIR}"
fi

# use an appropriate default for a local physical interface
PHY_IFACES="${ZEROTIER_ONE_LOCAL_PHYS:-"eth0"}"

# default to iptables (maintain compatibility for existing systems)
IPTABLES_CMD=iptables
# but support override to use iptables-nft
[ "${ZEROTIER_ONE_USE_IPTABLES_NFT}" = "true" ] && IPTABLES_CMD=iptables-nft

# the wildcard for the local zerotier interface is
ZT_IFACE="zt+"

# a script to add and remove the requisite rules - $1 is either "A" or "D"
update_iptables() {

	# iterate the local interface(s) and enable NAT services
	for PHY_IFACE in ${PHY_IFACES} ; do
		${IPTABLES_CMD} -t nat -${1} POSTROUTING -o ${PHY_IFACE} -j MASQUERADE
		${IPTABLES_CMD} -${1} FORWARD -i ${PHY_IFACE} -o ${ZT_IFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
		${IPTABLES_CMD} -${1} FORWARD -i ${ZT_IFACE} -o ${PHY_IFACE} -j ACCEPT
	done

}

# add rules to set up routing
echo "Using ${IPTABLES_CMD} to enable NAT services on ${PHY_IFACES}"
update_iptables "A"

# define where the ZeroTier daemon will write its output (if any)
PIPE=$(mktemp /tmp/zerotier-ipc-XXXXXX)

# start listening and echoing anything that appears there into this process
tail -f "${PIPE}" &

# make a note of the process ID for tail
TAIL_PIPE_PID=${!}

# report
echo "tail has started with PID=${TAIL_PIPE_PID} listening to ${PIPE}"

# now start the ZeroTier daemon in detached state
nohup "$@" </dev/null >"${PIPE}" 2>&1 &

# make a note of the process ID
ZEROTIER_DAEMON_PID=${!}

# report
echo "ZeroTier daemon has PID ${ZEROTIER_DAEMON_PID}"

echo "Setting up trap"
trap 'echo "**INT" ; kill -TERM ${ZEROTIER_DAEMON_PID}' INT
trap 'echo "**TERM" ; kill -TERM ${ZEROTIER_DAEMON_PID}' TERM
trap 'echo "**HUP" ; kill -TERM ${ZEROTIER_DAEMON_PID}' HUP

trap 'echo "**EXIT-nohandler"' EXIT
trap 'echo "**ABRT-nohandler"' ABRT
trap 'echo "**QUIT-nohandler"' QUIT
trap 'echo "**TRAP-nohandler"' TRAP

echo "now waiting on ZeroTier daemon"
wait ${ZEROTIER_DAEMON_PID}
echo "the ZeroTier daemon has gone away - cleaning up"

# kill the tail listener
echo "Killing tail listener"
kill -TERM ${TAIL_PIPE_PID}

# wait for it to go away
echo "Waiting for tail listener to go away"
wait ${TAIL_PIPE_PID}

# which means we are done with the pipe
echo "removing pipe"
rm "${PIPE}"

# remove rules used to set up routing
echo "Using ${IPTABLES_CMD} to disable NAT services on ${PHY_IFACES}"
update_iptables "D"

# using the sigterm is a normal exit for us so exit with 0
echo "all done"
