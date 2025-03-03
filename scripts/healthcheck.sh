#!/usr/bin/env sh
#This health-check script is sponsored by PMGA TECH LLP

#Exit Codes
# 0= Success
# 1= Failure

#Environment Variables
# ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS=         <Enter Networks to check with space in between each entry; All networks entered here would be matched; ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH is ignored if this is used.>
# ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH=     <Should be a Number greater than 0>

# minimum routes for health defaults to 1 route
ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH=${ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH:-1}

# Check if specified Networks are all Connected
if [[ -n "${ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS}" ]] ; then

    for network in $ZEROTIER_ONE_CHK_SPECIFIC_NETWORKS; do
        [[ "$(zerotier-cli get ${network} status)" = "OK" ]] || exit 1
        interface=$(zerotier-cli get ${network} portDeviceName)
        routes=$(ip r | grep "dev ${interface}" | grep -cv "via")
        [[ ${routes} -lt 1 ]] && exit 1
    done

else # Check for Minimum Networks

    # count zerotier-associated direct routes
    routes=$(ip r | grep "dev zt" | grep -cv "via")

    # sense less than minimum
    [[ ${routes} -lt ${ZEROTIER_ONE_CHK_MIN_ROUTES_FOR_HEALTH} ]] && exit 1

fi

exit 0

