#!/usr/bin/env sh
set -Eeo pipefail

echo "$(date) - launching ZeroTier-One in routing mode"

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

# make sure permissions are always as expected (self-repair)
PUID="${PUID:-"999"}"
PGID="${PGID:-"994"}"
if [ "$(id -u)" = '0' -a -d "${CONFIG_DIR}" ]; then
	chown -Rc "${PUID}:${PGID}" "${CONFIG_DIR}"
fi

# use an appropriate default for a local physical interface
# (using eth0 maintains backwards compatibility)
PHY_IFACES="${ZEROTIER_ONE_LOCAL_PHYS:-"eth0"}"

# default to iptables (maintains backwards compatibility)
IPTABLES_CMD=iptables
# but support an override to use iptables-nft
[ "${ZEROTIER_ONE_USE_IPTABLES_NFT}" = "true" ] && IPTABLES_CMD=iptables-nft

# the wildcard for the local zerotier interface is
ZT_IFACE="zt+"

# function to add and remove the requisite rules
# - $1 is either "A" (add) or "D" (delete)
update_iptables() {
	for PHY_IFACE in ${PHY_IFACES} ; do
		${IPTABLES_CMD} -t nat -${1} POSTROUTING -o ${PHY_IFACE} -j MASQUERADE
		${IPTABLES_CMD} -${1} FORWARD -i ${PHY_IFACE} -o ${ZT_IFACE} -m state --state RELATED,ESTABLISHED -j ACCEPT
		${IPTABLES_CMD} -${1} FORWARD -i ${ZT_IFACE} -o ${PHY_IFACE} -j ACCEPT
	done
}

# add rules to set up NAT-routing
update_iptables "A"

# define where the ZeroTier daemon will write its output (if any)
TAIL_PIPE=$(mktemp /tmp/zerotier-ipc-XXXXXX)

# start listening and echoing anything that appears there into this process
tail -f "${TAIL_PIPE}" &

# make a note of the process ID for tail
TAIL_PIPE_PID=${!}

# start the ZeroTier daemon in detached state
nohup "$@" </dev/null >"${TAIL_PIPE}" 2>&1 &

# make a note of the process ID
ZEROTIER_DAEMON_PID=${!}

# report
echo "$(date) - ZeroTier daemon is running as process ${ZEROTIER_DAEMON_PID}"

# function to handle cleanup
termination_handler() {

	echo "$(date) - terminating ZeroTier-One"

	# remove rules
	update_iptables "D"

	# relay the termination message to the daemon
	if [ -d "/proc/${ZEROTIER_DAEMON_PID}" ] ; then
		kill -TERM ${ZEROTIER_DAEMON_PID}
		wait ${ZEROTIER_DAEMON_PID}
	fi

	# tell the pipe listener to go away too
	if [ -d "/proc/${TAIL_PIPE_PID}" ] ; then
		kill -TERM ${TAIL_PIPE_PID}
		wait ${TAIL_PIPE_PID}
	fi

	# clean up the pipe file
	rm "${TAIL_PIPE}"

}

# set up termination handler (usually catches TERM)
trap termination_handler INT TERM HUP

# suspend this script while the zerotier daemon is running
wait ${ZEROTIER_DAEMON_PID}

# would not usually expect to arrive here inside a Docker container but
# it can happen if the user does a "sudo killall zerotier-one" rather
# that use Docker commands
echo "$(date) - the ZeroTier daemon has quit unexpectedly - cleaning up"

# run the termination handler
termination_handler
