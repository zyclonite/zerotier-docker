#This health-check script is sponsored by PMGA TECH LLP
#!/bin/sh

#Exit Codes
# 0= Success
# 1= Failure

#Environment Variables
# CHK_ZT_SPECIFIC_NETWORKS=         <Enter Networks to check with space in between each entry; All networks entered here would be matched; CHK_ZT_MIN_ROUTES_FOR_HEALTH is ignored if this is used.>
# CHK_ZT_MIN_ROUTES_FOR_HEALTH=     <Should be a Number greater than 0>

# Check if specified Networks are all Connected
if [[ -n "${CHK_ZT_SPECIFIC_NETWORKS}" ]] ; then
    for network in $CHK_ZT_SPECIFIC_NETWORKS; do
        #If Network is OK, continue, else exit
        [[ "$(zerotier-cli get ${network} status)" = "OK" ]] || exit 1
        #echo "${CHK_ZT_SPECIFIC_NETWORKS} Connected."
    done
    exit 0
# Check for Minimum Networks
elif [[ -n "${CHK_ZT_MIN_ROUTES_FOR_HEALTH}" ]] ; then 
    # Validate the MIN value for Health Checks
    CHK_ZT_MIN_ROUTES_FOR_HEALTH=$(( ${CHK_ZT_MIN_ROUTES_FOR_HEALTH} < 1 ? 1 : ${CHK_ZT_MIN_ROUTES_FOR_HEALTH} ))
    #echo "No. Of Networks to Check: ${CHK_ZT_MIN_ROUTES_FOR_HEALTH}"
    network_count=0
    #Get List of Joined networks
    joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    for network in $joined_networks; do
        if [[ "$(zerotier-cli get ${network} status)" = "OK" ]] ; then
            network_count=$(expr $network_count + 1)
            if [[ ${network_count} -ge ${CHK_ZT_MIN_ROUTES_FOR_HEALTH} ]] ; then
                #echo "${network_count} Networks Connected. Exit Success"
                exit 0
            fi
        fi
    done
    #Exit if the above count was not reached
    exit 1
#Check if ALL Networks are connected (Default - ZeroTier)
else
    #echo "Checking All Networks"
    joined_networks=$(zerotier-cli listnetworks | awk 'NR>1 {print$3}')
    #If there are no Networks, exit Failure
    [[ -n ${joined_networks} ]] || exit 1
    for network in $joined_networks; do
        [[ "$(zerotier-cli get ${network} status)" = "OK" ]] || exit 1
        #echo "$network Connected."
    done
fi