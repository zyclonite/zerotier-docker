#!/usr/bin/env sh
set -Eeo pipefail

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

# is routing enabled?
if [ $(sysctl -n net.ipv4.ip_forward) -ne 1 ] ; then

	# no! there is no point in setting up rules or termination handler
	echo "$(date) - IPv4 forwarding not enabled - launching ZeroTier-One in non-routing mode"

	# just exec the client (this script ends here)
	exec "$@"

fi

echo "$(date) - launching ZeroTier-One in routing mode"

# the default forwarding mode is inbound (backwards compatible)
GATEWAY_MODE="${ZEROTIER_ONE_GATEWAY_MODE:-"inbound"}"

# add rules to set up NAT-routing
gatewaymode "${GATEWAY_MODE}"

# define where the ZeroTier daemon will write its output (if any)
TAIL_PIPE="/tmp/zerotier-ipc-log"
cat /dev/null >"${TAIL_PIPE}"

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
	gatewaymode disable

	# relay the termination message to the daemon
	# (the pipe listener is cleaned up automatically)
	if [ -d "/proc/${ZEROTIER_DAEMON_PID}" ] ; then
		kill -TERM ${ZEROTIER_DAEMON_PID}
		wait ${ZEROTIER_DAEMON_PID}
	fi

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
