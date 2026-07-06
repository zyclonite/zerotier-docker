#!/usr/bin/env sh

# networks configuration directory is here (internal path)
NETWORKS_DIR="/var/lib/zerotier-one/networks.d"

# On first run, the networks directory does not exist. It is
# not created until one of the following occurs:
#
# 1. The entrypoint script responds to the presence of:
#
#       ZEROTIER_ONE_NETWORK_IDS=«networkID» {«networkID»}
#
# 2. The user mimics the action of the entrypoint script by
#    executing:
#
#       mkdir -p /var/lib/zerotier-one/networks.d
#       touch /var/lib/zerotier-one/networks.d/«networkID».conf
#
# 3. The user issues an explicit join via zerotier-cli:
#
#       zerotier-cli join «networkID»

# Does the networks directory exist?
if [ -d "${NETWORKS_DIR}" ] ; then

	# yes! Each time a network is joined (however that occurs),
	# two files are created:
	#    «networkID».conf   and   «networkID».local.conf
	# Those files are also removed on an explicit leave.
	# Accordingly, the presence of a «networkID».conf can be
	# taken as expressing the user's intention that the container
	# should be joined to that network.

	# Count the number of networks that should be joined
	EXPECTED_NETWORKS=$( \
		ls "${NETWORKS_DIR}"/*.conf \
		| grep -v "local.conf" \
		| wc -l \
	)

	# Each network which is joined, authorized and active results in
	# an entry in the host's routing table. A direct route is a
	# pinnacle indicator which will only be present if everything
	# else is working properly.
	
	# Count the number of zerotier-associated direct routes
	DIRECT_ROUTES=$( ip r | grep -c "dev zt.* scope link")

	# Irrespective of whether NETWORKS_DIR is empty or contains one
	# or more «networkID».conf files, the number of expected networks
	# should always equal the number of direct routes. Any mismatch
	# means the container is in an unexpected state and, accordingly,
	# is "unhealthy".

	# Sense any mismatch
	[ ${EXPECTED_NETWORKS} -ne ${DIRECT_ROUTES} ] && exit 1

fi

# otherwise, the container is "healthy"
exit 0

