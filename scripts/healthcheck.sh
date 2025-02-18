#This health-check script is sponsored by PMGA TECH LLP
#The above line is a part of license to use this code. Removal of line shall be deemed as revoking of usage rights.
#!/bin/sh

#Exit Codes
# 0= Success
# 1= Failure

#Environment Variables
# CHK_ZT_SPECIFIC_NETWORK=          <Enter 1 Specific Network for Checking; CHK_ZT_MIN_ROUTES_FOR_HEALTH is ignored if this is used.>
# CHK_ZT_MIN_ROUTES_FOR_HEALTH=     <Should be a Number greater than 0>

# Check if Specific Network is specified
if [[ -n "${CHK_ZT_SPECIFIC_NETWORK}" ]] ; then
    #If Network is OK, continue, else exit
    [[ "$(zerotier-cli get ${CHK_ZT_SPECIFIC_NETWORK} status)" = "OK" ]] || exit 1
    #echo "${CHK_ZT_SPECIFIC_NETWORK} Connected."
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
    for network in $joined_networks; do
        [[ "$(zerotier-cli get ${network} status)" = "OK" ]] || exit 1
        #echo "$network Connected."
    done
fi
